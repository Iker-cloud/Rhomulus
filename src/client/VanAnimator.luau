-- Entrada de la furgoneta de rescate. El servidor solo guarda de dónde a dónde (atributos From y To), cuándo empezó
-- (Start) y cuánto dura (Duration); cada cliente la mueve aquí para que se vea fluida:
--   avanza por la calle y frena con la nariz hacia abajo, rebota al detenerse, las ruedas giran,
--   la baliza del techo parpadea y suena el pitido (dos veces al entrar y una al parar).
local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local VanAnimator = {}

local WHEEL_RADIUS = 1.08 -- studs (la rueda mide 2.16 de diámetro)
local DIVE = 0.06 -- cuánto baja la nariz al frenar (radianes)
local HORN_TIMES = { 0, 2.1 } -- segundos desde que empieza la entrada
local SETTLE_TIME = 1.8 -- segundos de rebote tras detenerse

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
	}
	vans[model] = state
	model.Destroying:Connect(function()
		vans[model] = nil
	end)
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

local function update(state, dt)
	local model = state.model
	local elapsed = workspace:GetServerTimeNow() - state.start
	local t = math.clamp(elapsed / state.duration, 0, 1)

	-- Pitidos al entrar
	while state.hornsDone < #HORN_TIMES and elapsed >= HORN_TIMES[state.hornsDone + 1] do
		state.hornsDone += 1
		honk(state)
	end

	-- Posición: entra rápido y frena (cuadrática de salida)
	local eased = 1 - (1 - t) ^ 2
	local cf = state.from:Lerp(state.to, eased)
	local distance = (state.to.Position - state.from.Position).Magnitude
	local speed = distance / state.duration * 2 * (1 - t) -- studs/s
	local speedNorm = math.clamp(speed / 30, 0, 1)

	local pitch, roll, lift = 0, 0, 0
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
			model:PivotTo(state.to)
			state.settled = true
		end
	end

	if not state.settled then
		model:PivotTo(cf * CFrame.new(0, lift, 0) * CFrame.Angles(pitch, 0, roll))
	end

	-- Ruedas: giran según lo que avanza (rotación negativa en X = rodar hacia el frente, que mira a -Z)
	local moved = (state.lastPosition - cf.Position).Magnitude
	state.lastPosition = cf.Position
	state.wheelAngle += moved / WHEEL_RADIUS
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
	-- Precarga el pitido para que suene a tiempo la primera vez
	local preload = Instance.new("Sound")
	preload.SoundId = Config.Sounds.VanHorn
	task.spawn(function()
		ContentProvider:PreloadAsync({ preload })
		preload:Destroy()
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
