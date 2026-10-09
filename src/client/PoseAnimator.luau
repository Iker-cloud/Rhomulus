-- Poses de los sobrevivientes, para todos los jugadores (cada cliente anima a los demás):
--   caído    -> tumbado boca abajo; si se mueve, se arrastra con los brazos
--   cargado  -> colgando flojo sobre el hombro de quien lo carga
--   reviviendo (atributo "Reviving" del personaje) -> arrodillado, con los brazos hacia el compañero
-- Se escribe el Transform de los Motor6D del R15 en PreSimulation, encima de la animación normal (en PreRender
-- o Heartbeat la animación lo vuelve a sobrescribir).
-- En el marco de cada articulación (frente = -Z): una rotación positiva en X manda hacia adelante lo que cuelga
-- (brazos, piernas) y hacia atrás lo que apunta hacia arriba (torso, cabeza).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PoseAnimator = {}

local BLEND_SPEED = 7 -- qué tan rápido entra y sale cada pose
local PI = math.pi

-- Caído
local DOWN_DROP = 1.5 -- cuánto baja el cuerpo hasta quedar sobre el suelo (medido con el R15 normal: torso a 0.5 del suelo)
local CRAWL_RATE = 1.6 -- fase de arrastre por cada stud/s de velocidad
-- Revivir
local KNEEL_DROP = 0.8

-- Con el cuerpo tumbado, el torso y la cabeza chocarían con el suelo y empujarían al personaje hacia arriba
local BODY_PARTS = { "Head", "UpperTorso", "LowerTorso" }

local rigs = {} -- [Character] = { player, joints, weights, phase, time }

local function setBodyCollision(character, on)
	for _, name in BODY_PARTS do
		local part = character:FindFirstChild(name)
		if part then
			part.CanCollide = on
		end
	end
end

local function joint(character, partName, jointName)
	local part = character:FindFirstChild(partName)
	return part and part:FindFirstChild(jointName)
end

local function buildRig(player, character)
	local joints = {
		root = joint(character, "LowerTorso", "Root"),
		waist = joint(character, "UpperTorso", "Waist"),
		neck = joint(character, "Head", "Neck"),
		shoulderL = joint(character, "LeftUpperArm", "LeftShoulder"),
		shoulderR = joint(character, "RightUpperArm", "RightShoulder"),
		elbowL = joint(character, "LeftLowerArm", "LeftElbow"),
		elbowR = joint(character, "RightLowerArm", "RightElbow"),
		hipL = joint(character, "LeftUpperLeg", "LeftHip"),
		hipR = joint(character, "RightUpperLeg", "RightHip"),
		kneeL = joint(character, "LeftLowerLeg", "LeftKnee"),
		kneeR = joint(character, "RightLowerLeg", "RightKnee"),
	}
	-- Ojo: un campo nil no existe en la tabla, así que hay que comprobar cada nombre (con un for sobre `joints` nunca se ve)
	for _, name in { "root", "waist", "neck", "shoulderL", "shoulderR", "elbowL", "elbowR", "hipL", "hipR", "kneeL", "kneeR" } do
		if not joints[name] then
			return nil -- no es un R15 completo (todavía)
		end
	end
	return { player = player, character = character, joints = joints, down = 0, limp = 0, kneel = 0, last = {}, touched = false, phase = 0, time = math.random() * 10 }
end

-- Cada pose es una tabla { [articulación] = CFrame } que se mezcla con la animación normal según su peso
local function downedPose(rig, speed)
	local p, t = rig.phase, rig.time
	local moving = math.clamp(speed / 3, 0, 1)
	local swing = math.sin(p) * moving
	local breathe = math.sin(t * 1.8) * (1 - moving)
	local reach = PI - 0.2 -- brazos estirados por delante de la cabeza, apoyados en el suelo
	local liftR, liftL = math.max(0, swing), math.max(0, -swing) -- el brazo que avanza se levanta y se vuelve a apoyar
	return {
		root = CFrame.new(0, -DOWN_DROP, 0) * CFrame.Angles(-PI / 2, 0, 0),
		waist = CFrame.Angles(0.12 + breathe * 0.02, 0, 0),
		neck = CFrame.Angles(0.75 + breathe * 0.04, math.sin(p * 0.5) * 0.12 * moving, 0),
		shoulderR = CFrame.Angles(reach + liftR * 0.5 + breathe * 0.03, 0, 0.22),
		shoulderL = CFrame.Angles(reach + liftL * 0.5 + breathe * 0.03, 0, -0.22),
		elbowR = CFrame.Angles(0.1 + liftR * 0.4, 0, 0),
		elbowL = CFrame.Angles(0.1 + liftL * 0.4, 0, 0),
		hipR = CFrame.Angles(-0.14 - swing * 0.25, 0, 0.1),
		hipL = CFrame.Angles(-0.14 + swing * 0.25, 0, -0.1),
		kneeR = CFrame.Angles(-0.25 - math.max(0, swing) * 0.5, 0, 0),
		kneeL = CFrame.Angles(-0.25 - math.max(0, -swing) * 0.5, 0, 0),
	}
end

-- Colgando sobre el hombro de quien lo carga (el cuerpo ya lo acuesta el servidor): brazos y piernas sueltos
local function limpPose(rig)
	local t = rig.time
	local sway = math.sin(t * 1.7) * 0.1
	return {
		neck = CFrame.Angles(-0.45 + sway, 0.1, 0),
		shoulderR = CFrame.Angles(0.35 + sway, 0, 0.15),
		shoulderL = CFrame.Angles(0.25 - sway, 0, -0.15),
		elbowR = CFrame.Angles(0.2, 0, 0),
		elbowL = CFrame.Angles(0.2, 0, 0),
		hipR = CFrame.Angles(-0.1 + sway * 0.5, 0, 0.05),
		hipL = CFrame.Angles(0.05 - sway * 0.5, 0, -0.05),
		kneeR = CFrame.Angles(-0.2, 0, 0),
		kneeL = CFrame.Angles(-0.15, 0, 0),
	}
end

-- Arrodillado sobre una pierna, inclinado hacia el caído y apretándole el pecho
local function kneelPose(rig)
	local push = math.sin(rig.time * 7) * 0.12
	return {
		root = CFrame.new(0, -KNEEL_DROP, 0),
		waist = CFrame.Angles(-0.45, 0, 0),
		neck = CFrame.Angles(0.3, 0, 0),
		shoulderR = CFrame.Angles(0.85 + push, 0, 0.1),
		shoulderL = CFrame.Angles(0.85 - push, 0, -0.1),
		elbowR = CFrame.Angles(0.15, 0, 0),
		elbowL = CFrame.Angles(0.15, 0, 0),
		hipL = CFrame.Angles(1.35, 0, 0),
		kneeL = CFrame.Angles(-1.4, 0, 0),
		hipR = CFrame.Angles(0.05, 0, 0),
		kneeR = CFrame.Angles(-1.57, 0, 0),
	}
end

local function target(rig, name, base, poses)
	local result = base
	for _, entry in poses do
		local cf = entry.pose[name]
		if cf and entry.weight > 0.001 then
			result = result:Lerp(cf, math.min(entry.weight, 1))
		end
	end
	return result
end

local function update(rig, dt)
	local character, player = rig.character, rig.player
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not (root and humanoid) or humanoid.Health <= 0 then
		return
	end
	-- Si el avatar cambió las piezas después de crear el rig, busca las articulaciones nuevas
	if not rig.joints.root:IsDescendantOf(character) then
		local fresh = buildRig(player, character)
		if fresh then
			rig.joints = fresh.joints
			rig.last = {}
		end
		return
	end

	local carried = character:GetAttribute("Carried") == true
	local downed = player:GetAttribute("State") == "Downed" and not carried
	local reviving = character:GetAttribute("Reviving")
	local kneeling = reviving ~= nil and workspace:GetServerTimeNow() < reviving and player:GetAttribute("State") ~= "Downed"

	local step = math.min(1, dt * BLEND_SPEED)
	rig.down += ((downed and 1 or 0) - rig.down) * step
	rig.limp += ((carried and 1 or 0) - rig.limp) * step
	rig.kneel += ((kneeling and 1 or 0) - rig.kneel) * step
	if rig.down < 0.01 and rig.limp < 0.01 and rig.kneel < 0.01 then
		-- Pose terminada: lo que la animación normal no vuelve a escribir (la raíz) se deja en su sitio
		if rig.touched then
			rig.touched = false
			setBodyCollision(character, true)
			for name, motor in rig.joints do
				if motor.Transform == rig.last[name] then
					motor.Transform = CFrame.identity
				end
			end
		end
		return
	end

	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	rig.time += dt
	rig.phase += dt * speed * CRAWL_RATE

	local poses = {}
	if rig.down > 0.01 then
		table.insert(poses, { pose = downedPose(rig, speed), weight = rig.down })
	end
	if rig.limp > 0.01 then
		table.insert(poses, { pose = limpPose(rig), weight = rig.limp })
	end
	if rig.kneel > 0.01 then
		table.insert(poses, { pose = kneelPose(rig), weight = rig.kneel })
	end

	rig.touched = true
	setBodyCollision(character, false)
	for name, motor in rig.joints do
		-- Si la animación normal no cambió la articulación desde la última vez, parte de la pose neutra
		local base = motor.Transform
		if base == rig.last[name] then
			base = CFrame.identity
		end
		local result = target(rig, name, base, poses)
		rig.last[name] = result
		motor.Transform = result
	end
end

local function track(player, character)
	if rigs[character] then
		return
	end
	-- Las piezas llegan poco a poco (el avatar tarda en cargar): reintenta hasta tener todas las articulaciones
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
				-- Se conecta ahora (con el animador del personaje ya creado) para ejecutarse después de la animación normal:
				-- un manejador conectado antes se ejecuta antes y la animación le borra la pose
				local connection = RunService.PreSimulation:Connect(function(dt)
					local ok, err = pcall(update, rig, dt)
					if not ok and not rig.warned then
						rig.warned = true
						warn("PoseAnimator:", err)
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

function PoseAnimator.start()
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
end

return PoseAnimator
