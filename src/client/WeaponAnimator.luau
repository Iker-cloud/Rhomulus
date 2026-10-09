-- Brazos y arma de todos los sobrevivientes (cada cliente anima a los demás):
--   reposo   -> arma baja, inclinada hacia el suelo
--   apuntar  -> arma arriba, siguiendo hacia dónde mira (clic derecho, o 1.5 s después de disparar)
--   retroceso -> el arma patea hacia atrás y sube el cañón; el jugador local además siente una sacudida de cámara
--   recarga  -> cargador (pistola, rifle, subfusil) o cartucho a cartucho (escopeta), durante lo que dura la recarga
-- La mano derecha agarra el arma (soldada por el servidor, ver server/WeaponRig) y la izquierda se apoya o recarga.
-- Los brazos se resuelven con ArmIK en PreSimulation, encima de la animación normal; el efecto de la cámara es solo visual:
-- el disparo sale de la cámara sin el retroceso (WeaponAnimator.cameraCFrame).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ArmIK = require(script.Parent.ArmIK)

local Hold = Config.WeaponHold
local localPlayer = Players.LocalPlayer

local BLEND_SPEED = 10 -- qué tan rápido entran y salen los brazos
local KICK_DECAY = 18 -- el retroceso del arma se recupera a esta velocidad
local KICK_MAX = 1.6 -- retroceso acumulado máximo (ráfagas)
local CAMERA_DECAY = 12
local CAMERA_MAX = math.rad(4)
local DRAW_TIME = 0.35 -- segundos que tarda en subir el arma al cambiar
local FLASH_TIME = 0.05
local AIM_SEND_INTERVAL = 0.1
local AIM_SEND_DELTA = 0.04

-- Ejes del arma (X hacia atrás, Y arriba, Z a la izquierda) dentro del marco de apuntado (X derecha, Y arriba, Z atrás)
local GUN_FROM_AIM = CFrame.fromMatrix(Vector3.zero, Vector3.zAxis, Vector3.yAxis, -Vector3.xAxis)
local RIGHT_POLE = Vector3.new(0.6, -1, 0.3)
local LEFT_POLE = Vector3.new(-0.6, -1, 0.3)

local WeaponAnimator = {}

local rigs = {} -- [Character] = rig
local flashTokens = setmetatable({}, { __mode = "k" })
local cameraKick = 0 -- radianes de sacudida de cámara pendientes
local cameraOffset = CFrame.identity -- el que se aplicó a la cámara en el último cuadro

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Sube de 0 a 1 en los primeros `edge` de la recarga, se mantiene y baja en los últimos `edge`
local function bump(t, edge)
	return smooth(math.min(t / edge, (1 - t) / edge))
end

local function joint(character, partName, jointName)
	local part = character:FindFirstChild(partName)
	return part and part:FindFirstChild(jointName)
end

local function buildRig(player, character)
	local motors = {
		shoulderR = joint(character, "RightUpperArm", "RightShoulder"),
		elbowR = joint(character, "RightLowerArm", "RightElbow"),
		wristR = joint(character, "RightHand", "RightWrist"),
		shoulderL = joint(character, "LeftUpperArm", "LeftShoulder"),
		elbowL = joint(character, "LeftLowerArm", "LeftElbow"),
		wristL = joint(character, "LeftHand", "LeftWrist"),
	}
	for _, name in { "shoulderR", "elbowR", "wristR", "shoulderL", "elbowL", "wristL" } do
		if not motors[name] then
			return nil -- no es un R15 completo (todavía): un campo nil no existe en la tabla, hay que comprobar cada nombre
		end
	end
	if not (character:FindFirstChild("UpperTorso") and character:FindFirstChild("HumanoidRootPart")) then
		return nil
	end
	return {
		player = player,
		character = character,
		motors = motors,
		armR = ArmIK.new(motors.shoulderR, motors.elbowR, motors.wristR),
		armL = ArmIK.new(motors.shoulderL, motors.elbowL, motors.wristL),
		weight = 0, -- brazo derecho (agarra el arma)
		leftWeight = 0, -- brazo izquierdo
		raise = 0, -- 0 = arma baja, 1 = apuntando
		pitch = 0, -- hacia dónde mira, suavizado
		kick = 0,
		lastShot = -100,
		dip = 0, -- baja el arma al sacar otra
		key = nil,
		last = {},
		anim = {},
		touched = false,
	}
end

-- Cuánto se inclina el arma de lado y cuánto sube el cañón durante la recarga (t de 0 a 1)
local function reloadTilt(hold, t)
	if hold.Reload == "Shell" then
		return 1.0 * bump(t, 0.15), 0.35 * bump(t, 0.15)
	end
	return 0.55 * bump(t, 0.15), 0.1 * bump(t, 0.15)
end

-- Dónde está la mano izquierda durante la recarga: `fore` = apoyada, `mag` = cargador o puerto, `belt` = cinturón
local function reloadHand(hold, t, fore, mag, belt)
	if hold.Reload == "Shell" then
		-- Cartucho a cartucho: del cinturón al puerto de carga, varias veces
		if t < 0.12 then
			return fore:Lerp(belt, smooth(t / 0.12))
		elseif t > 0.88 then
			return belt:Lerp(fore, smooth((t - 0.88) / 0.12))
		end
		local phase = ((t - 0.12) / 0.76 * hold.ShellLoops) % 1
		local toPort = phase < 0.5 and smooth(phase / 0.5) or 1 - smooth((phase - 0.5) / 0.5)
		return belt:Lerp(mag, toPort)
	end
	-- Cargador: ir al cargador, sacarlo hacia el cinturón, meter el nuevo y volver
	if t < 0.15 then
		return fore:Lerp(mag, smooth(t / 0.15))
	elseif t < 0.4 then
		return mag:Lerp(belt, smooth((t - 0.15) / 0.25))
	elseif t < 0.7 then
		return belt:Lerp(mag, smooth((t - 0.4) / 0.3))
	elseif t < 0.85 then
		return mag
	end
	return mag:Lerp(fore, smooth((t - 0.85) / 0.15))
end

-- Escribe el Transform de una articulación mezclado con la animación normal según `weight`.
-- La animación normal también escribe estos Transform (y a veces repite el mismo valor), así que se recuerda la última
-- pose que puso ella (rig.anim): si el valor actual no es el que escribimos nosotros, es de la animación.
local function writeJoint(rig, name, transform, weight)
	local motor = rig.motors[name]
	local current = motor.Transform
	if current ~= rig.last[name] then
		rig.anim[name] = current
	end
	if weight <= 0.001 then
		-- Sin peso: manda la animación normal (si veníamos escribiendo, se le devuelve su pose)
		if rig.last[name] ~= nil then
			rig.last[name] = nil
			motor.Transform = rig.anim[name] or CFrame.identity
		end
		return
	end
	local result = weight >= 0.999 and transform or (rig.anim[name] or CFrame.identity):Lerp(transform, weight)
	rig.last[name] = result
	motor.Transform = result
end

local function release(rig)
	if not rig.touched then
		return
	end
	rig.touched = false
	for name, motor in rig.motors do
		if motor.Transform == rig.last[name] then
			motor.Transform = rig.anim[name] or CFrame.identity
		end
		rig.last[name] = nil
	end
end

local function update(rig, dt)
	local character, player = rig.character, rig.player
	local root = character:FindFirstChild("HumanoidRootPart")
	local torso = character:FindFirstChild("UpperTorso")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not (root and torso and humanoid) or humanoid.Health <= 0 then
		return
	end

	-- Caído, cargado o reviviendo: lo anima PoseAnimator
	local carried = character:GetAttribute("Carried") == true
	local downed = player:GetAttribute("State") == "Downed" and not carried
	local reviving = character:GetAttribute("Reviving")
	local kneeling = reviving ~= nil and workspace:GetServerTimeNow() < reviving and player:GetAttribute("State") ~= "Downed"
	local key = player:GetAttribute("WeaponKey")
	local hold = key ~= nil and Hold[key] or nil
	local active = hold ~= nil and not (carried or downed or kneeling)

	local step = math.min(1, dt * BLEND_SPEED)
	if not active then
		rig.weight = 0
		rig.leftWeight = 0
		release(rig)
		return
	end

	if rig.key ~= key then
		rig.key = key
		rig.dip = 1
		rig.kick = 0
	end
	rig.dip = math.max(0, rig.dip - dt / DRAW_TIME)
	rig.kick = rig.kick * math.exp(-KICK_DECAY * dt)

	-- Hacia dónde mira y si apunta
	local isLocal = player == localPlayer
	local pitchTarget, aiming
	if isLocal then
		local look = (workspace.CurrentCamera.CFrame * cameraOffset:Inverse()).LookVector
		pitchTarget = math.asin(math.clamp(look.Y, -1, 1))
		aiming = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
	else
		pitchTarget = character:GetAttribute("AimPitch") or 0
		aiming = character:GetAttribute("Aiming") == true
	end
	rig.pitch += (pitchTarget - rig.pitch) * math.min(1, dt * 14)

	-- Recarga: progreso de 0 a 1 según la hora del servidor
	local reloadT
	local reloadStart, reloadEnd = player:GetAttribute("ReloadStart"), player:GetAttribute("ReloadEnd")
	if reloadStart and reloadEnd and reloadEnd > reloadStart then
		local now = workspace:GetServerTimeNow()
		if now < reloadEnd then
			reloadT = math.clamp((now - reloadStart) / (reloadEnd - reloadStart), 0, 1)
		end
	end

	local raiseTarget = (aiming or os.clock() - rig.lastShot < Hold.RaiseTime) and 1 or 0
	if reloadT then
		raiseTarget = math.max(raiseTarget, 0.55)
	end
	rig.raise += (raiseTarget - rig.raise) * math.min(1, dt * Hold.RaiseSpeed)
	local raise = rig.raise

	local leftTarget = (hold.TwoHanded or (hold.Support ~= false and raise > 0.5) or reloadT) and 1 or 0
	rig.weight += (1 - rig.weight) * step
	rig.leftWeight += (leftTarget - rig.leftWeight) * step

	-- Marco de apuntado: origen en el pecho, girado hacia donde mira el personaje
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = flat.Magnitude > 0.001 and flat.Unit or Vector3.new(0, 0, -1)
	local yaw = CFrame.lookAt(Vector3.zero, flat)
	local anchor = torso.Position + Vector3.new(0, 0.6, 0)

	local cantRoll, extraPitch = 0, 0
	if reloadT then
		cantRoll, extraPitch = reloadTilt(hold, reloadT)
	end

	local lowPitch = (hold.LowPitch or Hold.LowPitch) + 0.25 * math.clamp(rig.pitch, -0.5, 0.5)
	local pitch = lowPitch + (rig.pitch - lowPitch) * raise + hold.Rise * rig.kick + extraPitch - 0.8 * rig.dip
	local frame = CFrame.new(anchor) * yaw * CFrame.Angles(0, -(hold.Convergence or Hold.Convergence) * raise, 0) * CFrame.Angles(pitch, 0, 0)
	local gunRot = frame.Rotation * GUN_FROM_AIM * CFrame.Angles(cantRoll, 0, 0)
	local gripAim = hold.LowGrip:Lerp(hold.HighGrip, raise)
	local gripWorld = frame * gripAim + gunRot * Vector3.new(hold.Kick * rig.kick, 0, 0)

	local handR = CFrame.new(gripWorld) * gunRot * Hold.HandGrip:Inverse()
	local scale = hold.Scale
	local foreWorld = gripWorld + gunRot * ((hold.Fore - hold.Grip) * scale)
	local leftPosition = foreWorld
	if reloadT then
		local magWorld = gripWorld + gunRot * ((hold.Mag - hold.Grip) * scale)
		local beltWorld = anchor + yaw * Hold.Belt
		leftPosition = reloadHand(hold, reloadT, foreWorld, magWorld, beltWorld)
	end
	local handL = CFrame.new(leftPosition) * gunRot * Hold.HandGrip:Inverse()

	local torsoCF = torso.CFrame
	local shoulderR, elbowR, wristR = ArmIK.solve(rig.armR, torsoCF, handR, yaw * RIGHT_POLE)
	local shoulderL, elbowL, wristL = ArmIK.solve(rig.armL, torsoCF, handL, yaw * LEFT_POLE)

	rig.touched = true
	writeJoint(rig, "shoulderR", shoulderR, rig.weight)
	writeJoint(rig, "elbowR", elbowR, rig.weight)
	writeJoint(rig, "wristR", wristR, rig.weight)
	writeJoint(rig, "shoulderL", shoulderL, rig.leftWeight)
	writeJoint(rig, "elbowL", elbowL, rig.leftWeight)
	writeJoint(rig, "wristL", wristL, rig.leftWeight)
end

local function track(player, character)
	if rigs[character] then
		return
	end
	-- Las piezas llegan poco a poco: reintenta hasta tener todas las articulaciones
	task.spawn(function()
		-- Roblox reemplaza las piezas del avatar justo después de CharacterAdded: con las articulaciones viejas la pose
		-- se escribía en piezas que ya no existen (pasaba con 1 jugador, que reaparece al empezar la partida)
		local deadline = os.clock() + 15
		while character.Parent and not player:HasAppearanceLoaded() and os.clock() < deadline do
			task.wait(0.2)
		end
		while character.Parent do
			local rig = buildRig(player, character)
			if rig then
				rigs[character] = rig
				-- Se conecta con el animador ya creado, para ejecutarse después de la animación normal
				local connection = RunService.PreSimulation:Connect(function(dt)
					local ok, err = pcall(update, rig, dt)
					if not ok and not rig.warned then
						rig.warned = true
						warn("WeaponAnimator:", err)
					end
				end)
				character.Destroying:Connect(function()
					connection:Disconnect()
					rigs[character] = nil
				end)
				return
			end
			task.wait(0.5)
		end
	end)
end

local function watchPlayer(player)
	if player.Character then
		track(player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		track(player, character)
	end)
end

-- Boca del cañón del arma de un jugador (nil si todavía no llegó el modelo)
function WeaponAnimator.muzzlePosition(character)
	local model = character and character:FindFirstChild("HandWeapon")
	local flash = model and model:FindFirstChild("MuzzleFlash")
	local core = flash and flash:FindFirstChild("Core")
	return core and core.Position
end

-- Enciende el fogonazo del arma de quien dispara
local function flash(character)
	local model = character and character:FindFirstChild("HandWeapon")
	local group = model and model:FindFirstChild("MuzzleFlash")
	if not group then
		return
	end
	local light = group:FindFirstChildWhichIsA("PointLight", true)
	for _, part in group:GetChildren() do
		if part:IsA("BasePart") then
			part.Transparency = 0.05
		end
	end
	if light then
		light.Enabled = true
	end
	local token = (flashTokens[group] or 0) + 1
	flashTokens[group] = token
	task.delay(FLASH_TIME, function()
		if flashTokens[group] == token then
			for _, part in group:GetChildren() do
				if part:IsA("BasePart") then
					part.Transparency = 1
				end
			end
			if light then
				light.Enabled = false
			end
		end
	end)
end

-- Cámara del jugador sin la sacudida del retroceso (de aquí sale el disparo)
function WeaponAnimator.cameraCFrame()
	return workspace.CurrentCamera.CFrame * cameraOffset:Inverse()
end

function WeaponAnimator.start()
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	Remotes.Shot.OnClientEvent:Connect(function(shooter, _from, _endPoints, weaponKey)
		local character = shooter and shooter.Character
		local rig = character and rigs[character]
		if rig then
			rig.lastShot = os.clock()
			rig.kick = math.min(rig.kick + 1, KICK_MAX)
		end
		flash(character)
		local hold = Hold[weaponKey]
		if shooter == localPlayer and hold then
			cameraKick = math.min(cameraKick + math.rad(hold.Camera), CAMERA_MAX)
		end
	end)

	-- Sacudida de cámara: un desplazamiento visual que se aplica después de la cámara normal y no se acumula
	RunService:BindToRenderStep("WeaponRecoilCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		cameraKick *= math.exp(-CAMERA_DECAY * dt)
		if cameraKick < 1e-4 then
			cameraKick = 0
			cameraOffset = CFrame.identity
			return
		end
		cameraOffset = CFrame.Angles(cameraKick, 0, 0)
		local camera = workspace.CurrentCamera
		camera.CFrame = camera.CFrame * cameraOffset
	end)

	-- Los demás ven hacia dónde apunto: se manda cuando cambia
	local lastPitch, lastAiming, lastSend = 0, false, 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastSend < AIM_SEND_INTERVAL then
			return
		end
		local pitch = math.asin(math.clamp(WeaponAnimator.cameraCFrame().LookVector.Y, -1, 1))
		local aiming = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
		if math.abs(pitch - lastPitch) > AIM_SEND_DELTA or aiming ~= lastAiming then
			lastPitch, lastAiming, lastSend = pitch, aiming, now
			Remotes.Aim:FireServer(pitch, aiming)
		end
	end)
end

return WeaponAnimator
