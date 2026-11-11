-- Remo One, el avión de rescate de Last Call (cliente). Como con la furgoneta (client/VanAnimator), el servidor solo guarda
-- atributos en el modelo (server/PlaneBuilder, GameState.extraction) y cada cliente lo mueve aquí para que se vea fluido:
--   Llegada: To (donde queda parado), Start y Duration: viene desde lejos por detrás, baja, toca la pista y frena hasta To.
--   Puerta y escalerilla: DoorL (true = abierta): la puerta se corre hacia el morro y la escalerilla baja.
--   Salida: DepartStart (hora del servidor): los motores suben, corre por la pista, levanta el morro y se va.
-- El fuselaje va cerrado: los sobrevivientes sentados (atributo VanSeat del personaje, lo pone server/Boarding) se llevan pegados
-- a su asiento y se esconden, y la cámara de quien ya subió pasa a mirar el avión desde fuera.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local PlaneLayout = require(ReplicatedStorage.Shared.PlaneLayout)

local PlaneAnimator = {}

local P = Config.Plane
local player = Players.LocalPlayer
local planes = {} -- [Model] = estado
local cameraOn = false -- la cámara exterior está puesta

local function smoothstep(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function planeSound(state, key, looped)
	local def = Config.Sounds.Plane[key]
	local sound = Instance.new("Sound")
	sound.Name = key
	sound.SoundId = def[1]
	sound.Volume = def[2]
	sound.PlaybackSpeed = def[3] or 1
	sound.Looped = looped or false
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 60
	sound.RollOffMaxDistance = 900
	sound.Parent = state.model.PrimaryPart
	return sound
end

local function playOnce(state, key)
	local sound = planeSound(state, key, false)
	sound:Play()
	Debris:AddItem(sound, 10)
end

local function register(model)
	if planes[model] then
		return
	end
	local to, start, duration = model:GetAttribute("To"), model:GetAttribute("Start"), model:GetAttribute("Duration")
	local primary = model.PrimaryPart
	local stair = model:FindFirstChild("mov_escalerilla", true)
	local door = model:FindFirstChild("mov_puerta_avion", true)
	if not (to and start and duration and primary and stair and door and model:FindFirstChild("baliza_avion")) then
		return -- las piezas llegan poco a poco
	end
	local stairParts = {}
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and (part.Name == "Peldano" or part.Name == "EscalerillaLarguero" or part.Name == "EscalerillaPasamanos") then
			table.insert(stairParts, part)
		end
	end
	local state = {
		model = model,
		to = to,
		start = start,
		duration = duration,
		stair = stair,
		door = door,
		stairParts = stairParts,
		open = 0, -- cuánto abiertas están la puerta y la escalerilla (0 a 1)
		touched = false,
		parked = false,
		departed = false,
		cf = to,
	}
	planes[model] = state
	state.engine = planeSound(state, "Engine", true)
	state.engine:Play()
	model:GetAttributeChangedSignal("DoorL"):Connect(function()
		playOnce(state, "Door")
	end)
	model.Destroying:Connect(function()
		planes[model] = nil
	end)
end

local function registerWhenReady(model)
	for _ = 1, 40 do
		register(model)
		if planes[model] or not model.Parent then
			return
		end
		task.wait(0.5)
	end
end

-- Llegada: `t` de 0 a 1. Devuelve el CFrame y la velocidad (0 a 1) para el sonido.
local function arrivalPose(state, t)
	local remaining = P.Approach * (1 - t) ^ 2 -- frena de forma continua hasta pararse
	local touch = P.Touchdown
	local air = math.clamp(1 - t / touch, 0, 1)
	local altitude = P.Height * air ^ 2 -- la senda se aplana al tocar la pista
	local pitch = math.rad(5) * math.sqrt(air)
	if t >= touch then
		-- En la pista: el morro baja, rebota un poco y se asienta
		local since = (t - touch) * state.duration
		pitch = math.rad(2.2) * math.exp(-1.6 * since) * math.cos(4.5 * since)
	end
	return state.to * CFrame.new(0, altitude, remaining) * CFrame.Angles(pitch, 0, 0), 1 - t
end

-- Salida: `t` segundos desde DepartStart
local function departurePose(state, t)
	local T = P.Takeoff
	if t < T.Spool then
		return state.to * CFrame.new(0, math.sin(t * 40) * 0.03 * (t / T.Spool), 0), 0.2 + 0.5 * t / T.Spool
	end
	local run = t - T.Spool
	local distance = 0.5 * T.Accel * run ^ 2
	local rotateAt = T.RotateSpeed / T.Accel -- segundos de carrera hasta levantar el morro
	local lift = math.max(0, run - rotateAt)
	local pitch = math.rad(T.Pitch) * smoothstep(lift / 1.6)
	local altitude = 0.5 * T.ClimbAccel * math.max(0, lift - 0.5) ^ 2
	return state.to * CFrame.new(0, altitude, -distance) * CFrame.Angles(pitch, 0, 0), 1
end

local function updateDoor(state, dt)
	local target = state.model:GetAttribute("DoorL") and 1 or 0
	if state.open == target then
		return
	end
	state.open += math.clamp(target - state.open, -dt / P.StairTime, dt / P.StairTime)
	local u = smoothstep(state.open)
	-- La puerta se corre hacia el morro (-Z del modelo) y un poco hacia fuera
	state.door.Transform = CFrame.new(-0.35 * math.min(1, u * 4), 0, -PlaneLayout.DoorSlide * u)
	-- La escalerilla sale de debajo de la puerta: se desliza por su propia pendiente y aparece
	local back = (1 - u) * 6
	local slope = math.sqrt(PlaneLayout.StairRun ^ 2 + PlaneLayout.DoorY ^ 2)
	state.stair.Transform = CFrame.new(back * PlaneLayout.StairRun / slope, back * PlaneLayout.DoorY / slope, 0)
	for _, part in state.stairParts do
		part.Transparency = 1 - math.clamp(u * 2.2, 0, 1)
	end
end

local function update(state, dt)
	local model = state.model
	local now = workspace:GetServerTimeNow()
	local departStart = model:GetAttribute("DepartStart")
	updateDoor(state, dt)

	local speed = 0
	if departStart and now >= departStart then
		if not state.departed then
			state.departed = true
			playOnce(state, "Spool")
		end
		state.cf, speed = departurePose(state, now - departStart)
		model:PivotTo(state.cf)
	elseif not state.parked then
		local t = math.clamp((now - state.start) / state.duration, 0, 1)
		state.cf, speed = arrivalPose(state, t)
		if t >= P.Touchdown and not state.touched then
			state.touched = true
			playOnce(state, "Touchdown")
		end
		if t >= 1 then
			state.parked = true
			state.cf = state.to
		end
		model:PivotTo(state.cf)
	end
	-- La escalerilla recogida no se ve (también antes de abrirse por primera vez)
	if state.open == 0 and not state.stairHidden then
		state.stairHidden = true
		for _, part in state.stairParts do
			part.Transparency = 1
		end
	elseif state.open > 0 then
		state.stairHidden = false
	end

	if state.engine then
		state.engine.PlaybackSpeed = 0.55 + 0.75 * speed
		state.engine.Volume = Config.Sounds.Plane.Engine[2] * (0.35 + 0.65 * speed)
	end
	-- Baliza roja y luces de las alas parpadeando
	local blink = math.floor(os.clock() * 2.5) % 2 == 0
	local beacon = model:FindFirstChild("baliza_avion")
	if beacon then
		beacon.Transparency = blink and 0 or 0.8
		local light = beacon:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = blink
		end
	end
end

-- Quién va sentado en este avión (personaje, raíz y asiento)
local function passengers(state)
	local list = {}
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local seatName = character and character:GetAttribute("VanSeat")
		local root = seatName and character:FindFirstChild("HumanoidRootPart")
		local seat = seatName and state.model:FindFirstChild(seatName)
		if root and seat then
			table.insert(list, { player = other, character = character, root = root, seat = seat })
		end
	end
	return list
end

-- Cámara exterior de quien ya subió: mira el avión desde su lado izquierdo; al despegar se queda en su sitio y lo ve irse
local function exteriorCamera(state)
	local camera = workspace.CurrentCamera
	if not cameraOn then
		cameraOn = true
		camera.CameraType = Enum.CameraType.Scriptable
	end
	local departStart = state.model:GetAttribute("DepartStart")
	local leaving = departStart and workspace:GetServerTimeNow() >= departStart + P.Takeoff.Spool
	if not leaving or not state.cameraSpot then
		state.cameraSpot = (state.cf * CFrame.new(P.Camera.Offset)).Position
	end
	local target = (state.cf * CFrame.new(P.Camera.LookAt)).Position
	camera.CFrame = CFrame.lookAt(state.cameraSpot, target)
end

local function restoreCamera()
	if cameraOn then
		cameraOn = false
		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Custom
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

-- Después de mover el avión y antes de dibujar: los pasajeros van pegados a su asiento y escondidos dentro del fuselaje
local function afterMove()
	local seated = false
	for _, state in planes do
		for _, entry in passengers(state) do
			entry.root.CFrame = entry.seat.CFrame * CFrame.new(0, entry.seat.Size.Y / 2 + PlaneLayout.SitHeight, 0)
			entry.root.AssemblyLinearVelocity = Vector3.zero
			for _, part in entry.character:GetDescendants() do
				if part:IsA("BasePart") or part:IsA("Decal") then
					part.LocalTransparencyModifier = 1
				end
			end
			if entry.player == player then
				seated = true
				exteriorCamera(state)
			end
		end
	end
	if not seated then
		restoreCamera()
	end
end

function PlaneAnimator.start()
	for _, model in CollectionService:GetTagged("PlaneRig") do
		task.spawn(registerWhenReady, model)
	end
	CollectionService:GetInstanceAddedSignal("PlaneRig"):Connect(function(model)
		task.spawn(registerWhenReady, model)
	end)
	RunService.PreSimulation:Connect(function(dt)
		for _, state in planes do
			update(state, dt)
		end
	end)
	RunService:BindToRenderStep("PlanePassengers", Enum.RenderPriority.Camera.Value + 1, afterMove)
end

return PlaneAnimator
