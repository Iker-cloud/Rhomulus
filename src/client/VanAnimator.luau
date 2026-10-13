-- Furgoneta de rescate (cliente). El servidor solo guarda atributos en el modelo y cada cliente la mueve aquí para que se vea fluida:
--   Llegada: de From a To (Start, Duration): avanza por la calle y frena con la nariz hacia abajo, rebota al detenerse, las ruedas giran,
--     la baliza del techo parpadea y suena el pitido (dos veces al entrar y una al parar).
--   Puertas: DoorR / DoorL (true = abierta) deslizan las puertas laterales hacia el frente (articulaciones "mov_puerta_der" / "mov_puerta_izq").
--   Salida: DepartStart (hora del servidor): el motor arranca y ruge con la furgoneta quieta, sale en marcha atrás con el pitido de
--     reversa, hace un giro de 180° derrapando y se va a toda velocidad por donde vino. Los sobrevivientes sentados van soldados a sus
--     asientos y se van con ella.
local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local VanLayout = require(ReplicatedStorage.Shared.VanLayout)

local VanAnimator = {}

local WHEEL_RADIUS = 1.08 -- studs (la rueda mide 2.16 de diámetro)
local DIVE = 0.06 -- cuánto baja la nariz al frenar (radianes)
local HORN_TIMES = { 0, 2.1 } -- segundos desde que empieza la entrada
local SETTLE_TIME = 1.8 -- segundos de rebote tras detenerse
local DOOR_SPEED = 2.6 -- qué tan rápido se abre la puerta (por segundo)

-- Salida (segundos desde DepartStart)
local REV_END = 1.6 -- el motor ruge quieto
local BACK_TIME = 2.7 -- marcha atrás
local TURN_TIME = 1.2 -- giro de 180°
local BACK_ACCEL = 7 -- studs/s² en reversa
local TURN_END_SPEED = 10 -- velocidad al terminar el giro
local AWAY_ACCEL = 14 -- studs/s² al irse de frente
local TURN_SWING = 3.5 -- cuánto se desliza de lado la cola en el giro

local vans = {} -- [Model] = estado

local function smoothstep(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function honk(state)
	local sound = state.horn:Clone()
	sound.Parent = state.model.PrimaryPart
	sound:Play()
	Debris:AddItem(sound, 4)
end

-- Sonido 3D pegado a la furgoneta (Config.Sounds.Van.<key> = { id, volumen })
local function vanSound(state, key, looped)
	local def = Config.Sounds.Van[key]
	local sound = Instance.new("Sound")
	sound.Name = key
	sound.SoundId = def[1]
	sound.Volume = def[2]
	sound.Looped = looped or false
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 30
	sound.RollOffMaxDistance = 320
	sound.Parent = state.model.PrimaryPart
	return sound
end

local function playOnce(state, key)
	local sound = vanSound(state, key, false)
	sound:Play()
	Debris:AddItem(sound, 8)
	return sound
end

local function register(model)
	if vans[model] then
		return
	end
	local from, to = model:GetAttribute("From"), model:GetAttribute("To")
	local start, duration = model:GetAttribute("Start"), model:GetAttribute("Duration")
	local primary = model.PrimaryPart
	if not (from and to and start and duration and primary and model:GetAttribute("JointCount")) then
		return
	end

	local wheels = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Name:sub(1, 6) == "rueda_" then
			table.insert(wheels, descendant)
		end
	end
	if #wheels < 4 then
		return -- aún no llegan todas las ruedas
	end

	local horn = Instance.new("Sound")
	horn.Name = "Pitido"
	horn.SoundId = Config.Sounds.VanHorn
	horn.Volume = Config.Sounds.Volume.VanHorn
	horn.RollOffMode = Enum.RollOffMode.InverseTapered
	horn.RollOffMinDistance = 40
	horn.RollOffMaxDistance = 400

	local state = {
		model = model,
		from = from,
		to = to,
		start = start,
		duration = duration,
		wheels = wheels,
		wheelAngle = 0,
		lastPosition = from.Position,
		horn = horn,
		hornsDone = 0,
		stopHorn = false,
		beacon = model:FindFirstChild("baliza_ambar"),
		doors = { R = 0, L = 0 }, -- cuánto abierta está cada puerta (0 a 1)
		departed = false,
	}
	vans[model] = state
	model.Destroying:Connect(function()
		vans[model] = nil
	end)

	-- Sonido de las puertas al abrirse o cerrarse (una sola vez aunque cambien las dos a la vez)
	local lastDoorSound = 0
	local function onDoor()
		if os.clock() - lastDoorSound > 0.4 then
			lastDoorSound = os.clock()
			playOnce(state, "Door")
		end
	end
	model:GetAttributeChangedSignal("DoorR"):Connect(onDoor)
	model:GetAttributeChangedSignal("DoorL"):Connect(onDoor)
end

-- Las piezas llegan al cliente poco a poco: reintenta hasta tener todo
local function registerWhenReady(model)
	for _ = 1, 40 do
		register(model)
		if vans[model] or not model.Parent then
			return
		end
		task.wait(0.5)
	end
end

-- Arranque de la salida (una sola vez): sonidos, humo del escape y luces de freno
local function beginDeparture(state)
	state.departed = true
	local model = state.model
	playOnce(state, "EngineStart")
	state.engine = vanSound(state, "EngineLoop", true)
	state.engine.PlaybackSpeed = 0.8
	state.engine:Play()
	state.beep = vanSound(state, "ReverseBeep", true)
	state.skidPlayed = false

	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(-1.4, 1.2, 8.1) * (model:GetAttribute("Scale") or 1)
	attachment.Parent = model.PrimaryPart
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Rate = 28
	smoke.Lifetime = NumberRange.new(0.9, 1.6)
	smoke.Speed = NumberRange.new(3, 6)
	smoke.SpreadAngle = Vector2.new(18, 18)
	smoke.EmissionDirection = Enum.NormalId.Back
	smoke.Color = ColorSequence.new(Color3.fromRGB(120, 118, 114))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 3.4) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	smoke.Parent = attachment
	state.smoke = smoke

	state.pilots = {}
	for _, name in { "piloto_izq", "piloto_der" } do
		local lamp = model:FindFirstChild(name)
		if lamp then
			lamp.Material = Enum.Material.Neon
			table.insert(state.pilots, lamp)
		end
	end
end

-- Posición de la furgoneta en la salida: desplazamiento (x lateral, z hacia atrás) respecto a donde paró, giro, balanceo,
-- cabeceo y velocidad con signo a lo largo de la dirección que mira (negativa en marcha atrás)
local function departurePose(t)
	if t < REV_END then
		local rumble = math.sin(t * 46) * 0.004 * (0.4 + t / REV_END)
		return 0, 0, 0, 0, rumble, 0
	end
	local t1 = t - REV_END
	local backSpeed = BACK_ACCEL * BACK_TIME
	local backDistance = 0.5 * BACK_ACCEL * BACK_TIME ^ 2
	if t1 < BACK_TIME then
		return 0, 0.5 * BACK_ACCEL * t1 ^ 2, 0, 0, -0.025 * smoothstep(t1 * 2), -BACK_ACCEL * t1
	end
	local t2 = t1 - BACK_TIME
	if t2 < TURN_TIME then
		local u = t2 / TURN_TIME
		local speed = backSpeed + (TURN_END_SPEED - backSpeed) * u
		local z = backDistance + backSpeed * t2 + (TURN_END_SPEED - backSpeed) * t2 ^ 2 / (2 * TURN_TIME)
		local sway = math.sin(math.pi * u)
		-- Mientras gira ya no va "hacia atrás": a mitad del giro la velocidad con signo cruza cero
		return -TURN_SWING * sway, z, math.pi * smoothstep(u), 0.08 * sway, -0.02 * (1 - u), (u - 0.5) * 2 * speed
	end
	local t3 = t2 - TURN_TIME
	local turnDistance = backDistance + backSpeed * TURN_TIME + (TURN_END_SPEED - backSpeed) * TURN_TIME / 2
	local z = turnDistance + TURN_END_SPEED * t3 + 0.5 * AWAY_ACCEL * t3 ^ 2
	return 0, z, math.pi, 0, 0.035 * math.exp(-1.2 * t3), TURN_END_SPEED + AWAY_ACCEL * t3
end

local function updateDoors(state, dt)
	local model = state.model
	if not (state.motorR and state.motorL) then
		state.motorR = state.motorR or model:FindFirstChild("mov_puerta_der", true)
		state.motorL = state.motorL or model:FindFirstChild("mov_puerta_izq", true)
	end
	local scale = model:GetAttribute("Scale") or 1
	local targets = { R = model:GetAttribute("DoorR") and 1 or 0, L = model:GetAttribute("DoorL") and 1 or 0 }
	for side, motor in { R = state.motorR, L = state.motorL } do
		local current = state.doors[side]
		current += math.clamp(targets[side] - current, -dt * DOOR_SPEED, dt * DOOR_SPEED)
		state.doors[side] = current
		motor.Transform = CFrame.new(0, 0, -VanLayout.DoorSlide * scale * smoothstep(current))
	end
end

local function update(state, dt)
	local model = state.model
	local now = workspace:GetServerTimeNow()
	local elapsed = now - state.start
	local departStart = model:GetAttribute("DepartStart")
	local departing = departStart ~= nil and now >= departStart

	updateDoors(state, dt)

	local cf, speedSigned = nil, 0
	local pitch, roll, lift = 0, 0, 0

	if departing then
		if not state.departed then
			beginDeparture(state)
		end
		local t = now - departStart
		local x, z, yaw, rollExtra, pitchExtra, speed = departurePose(t)
		cf = state.to * CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
		pitch, roll = pitchExtra, rollExtra
		lift = t < REV_END and math.sin(os.clock() * 31) * 0.035 or 0
		speedSigned = speed

		-- Sonidos y luces según la fase
		local reversing = t >= REV_END and t < REV_END + BACK_TIME + 0.6
		if state.beep then
			if reversing and not state.beep.IsPlaying then
				state.beep:Play()
			elseif not reversing and state.beep.IsPlaying then
				state.beep:Stop()
			end
		end
		if t >= REV_END + BACK_TIME and not state.skidPlayed then
			state.skidPlayed = true
			playOnce(state, "Skid")
		end
		if state.engine then
			state.engine.PlaybackSpeed = math.clamp(0.8 + math.abs(speedSigned) * 0.022 + (t < REV_END and math.sin(t * 9) * 0.08 + t * 0.1 or 0), 0.7, 2.4)
		end
		if state.smoke then
			state.smoke.Rate = t < REV_END + BACK_TIME + TURN_TIME and 30 or 10
		end
		for _, lamp in state.pilots or {} do
			lamp.Color = reversing and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(255, 40, 30)
		end
	else
		local t = math.clamp(elapsed / state.duration, 0, 1)

		-- Pitidos al entrar
		while state.hornsDone < #HORN_TIMES and elapsed >= HORN_TIMES[state.hornsDone + 1] do
			state.hornsDone += 1
			honk(state)
		end

		-- Posición: entra rápido y frena (cuadrática de salida)
		local eased = 1 - (1 - t) ^ 2
		cf = state.from:Lerp(state.to, eased)
		local distance = (state.to.Position - state.from.Position).Magnitude
		local speed = distance / state.duration * 2 * (1 - t) -- studs/s
		local speedNorm = math.clamp(speed / 30, 0, 1)

		if t < 1 then
			-- Al acelerar sube un poco la nariz; al acercarse al final la baja (frenada)
			pitch = 0.025 * (1 - smoothstep(t * 6)) - DIVE * smoothstep((t - 0.4) / 0.6)
			roll = math.sin(os.clock() * 2.6) * 0.012 * speedNorm
			lift = math.sin(os.clock() * 17) * 0.05 * speedNorm
		else
			-- Detenida: la suspensión rebota y se asienta
			local settle = elapsed - state.duration
			if state.stopHorn == false then
				state.stopHorn = true
				honk(state)
			end
			local decay = math.exp(-3.4 * settle)
			pitch = -DIVE * decay * math.cos(9 * settle)
			roll = 0.01 * decay * math.sin(7 * settle)
			if settle > SETTLE_TIME then
				state.settled = true
			end
		end
	end

	if departing or not state.settled then
		model:PivotTo(cf * CFrame.new(0, lift, 0) * CFrame.Angles(pitch, 0, roll))
	elseif state.settled and not state.parked then
		state.parked = true
		model:PivotTo(state.to)
	end

	-- Ruedas: giran según lo que avanza (rotación negativa en X = rodar hacia el frente, que mira a -Z). Con signo: en reversa giran al revés.
	local delta = cf.Position - state.lastPosition
	state.lastPosition = cf.Position
	local forward = cf.LookVector
	state.wheelAngle += delta:Dot(forward) / (WHEEL_RADIUS * (model:GetAttribute("Scale") or 1))
	local spin = CFrame.Angles(-state.wheelAngle, 0, 0)
	for _, wheel in state.wheels do
		wheel.Transform = spin
	end

	-- Baliza ámbar parpadeando
	if state.beacon then
		local on = math.floor(os.clock() * 4) % 2 == 0
		state.beacon.Transparency = on and 0 or 0.65
	end
end

function VanAnimator.start()
	-- Precarga los sonidos para que suenen a tiempo la primera vez
	local preload = { Config.Sounds.VanHorn }
	for _, def in Config.Sounds.Van do
		table.insert(preload, def[1])
	end
	task.spawn(function()
		local sounds = {}
		for _, id in preload do
			local sound = Instance.new("Sound")
			sound.SoundId = id
			table.insert(sounds, sound)
		end
		ContentProvider:PreloadAsync(sounds)
		for _, sound in sounds do
			sound:Destroy()
		end
	end)

	for _, model in CollectionService:GetTagged("VanRig") do
		task.spawn(registerWhenReady, model)
	end
	CollectionService:GetInstanceAddedSignal("VanRig"):Connect(function(model)
		task.spawn(registerWhenReady, model)
	end)

	RunService.PreSimulation:Connect(function(dt)
		for _, state in vans do
			update(state, dt)
		end
	end)
end

return VanAnimator
