-- Animación de los zombies hechos con articulaciones (ZombieModel). Mueve los Motor6D en el cliente (no se replica).
-- Cada modelo tiene un perfil: "Brotado" (el común) camina arrastrando los pies; "Desbocado" (el rápido) corre
-- inclinado hacia adelante con los brazos sueltos y la boca abierta.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local ZombieAnimator = {}

-- freq: pasos por studs recorridos; el resto son amplitudes en radianes
local PROFILES = {
	Brotado = {
		freq = 0.9,
		legL = 0.55, legR = 0.45, kneeL = 0.7, kneeR = 0.5,
		armL = 0.5, armR = 0.12, elbowL = 0, elbowR = 0.08,
		lean = 0, twist = 0.12, headBob = 0.05, jaw = 0.08, jawAttack = 0.5,
		lungeArmL = 0.9, lungeArmR = 0.5,
		fall = 0.7, -- segundos que tarda en caer al morir
	},
	-- Tanque: paso lento y pesado, con los brazos enormes balanceándose
	Tanque = {
		freq = 0.5,
		legL = 0.45, legR = 0.45, kneeL = 0.55, kneeR = 0.55,
		armL = 0.35, armR = 0.35, elbowL = 0.25, elbowR = 0.25,
		lean = 0.1, twist = 0.18, headBob = 0.04, jaw = 0.1, jawAttack = 0.5,
		lungeArmL = 1.3, lungeArmR = 1.3,
		fall = 1.1,
	},
	Desbocado = {
		freq = 0.55,
		legL = 0.95, legR = 0.95, kneeL = 1.2, kneeR = 1.2,
		armL = 0.95, armR = 0.95, elbowL = 0.6, elbowR = 0.6,
		lean = 0.3, twist = 0.2, headBob = 0.1, jaw = 0.3, jawAttack = 0.6,
		lungeArmL = 1.1, lungeArmR = 1.1,
		fall = 0.55,
	},
}

local rigs = {} -- [Model] = { motors, root, profile, phase, time }

local function register(model)
	local profile = PROFILES[model:GetAttribute("Rig")]
	if rigs[model] or not profile then
		return
	end
	local motors = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			motors[descendant.Name] = descendant
		end
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	local expected = model:GetAttribute("JointCount")
	local found = 0
	for _ in motors do
		found += 1
	end
	if not root or not expected or found < expected then
		return -- aún no llegan todas las articulaciones
	end
	rigs[model] = { motors = motors, root = root, profile = profile, phase = math.random() * 6.28, time = math.random() * 10 }
	model.Destroying:Connect(function()
		rigs[model] = nil
	end)
end

local function rot(x, y, z)
	return CFrame.Angles(x or 0, y or 0, z or 0)
end

local function animate(model, rig, dt)
	local pr = rig.profile
	local velocity = rig.root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local moving = math.clamp(speed / 6, 0, 1)

	rig.time += dt
	rig.phase += dt * speed * pr.freq
	local t, p = rig.time, rig.phase

	-- Ataque: una embestida corta (el servidor guarda la hora del golpe en el atributo "Attack")
	local attackStart = model:GetAttribute("Attack")
	local lunge = 0
	if attackStart then
		local elapsed = workspace:GetServerTimeNow() - attackStart
		if elapsed >= 0 and elapsed < 0.4 then
			lunge = math.sin(elapsed / 0.4 * math.pi)
		end
	end

	local swing = math.sin(p) * moving
	local bendL = math.max(0, math.sin(p + 1.2)) * moving
	local bendR = math.max(0, math.sin(p + 1.2 + math.pi)) * moving
	local idle = math.sin(t * 1.6) * (1 - moving)

	local m = rig.motors
	-- En el marco de cada articulación el frente del modelo es +Z: una rotación positiva en X manda hacia adelante lo que
	-- está arriba (torso, cabeza, mandíbula) y hacia atrás lo que cuelga (piernas, pies, brazos)
	if m.pierna_izq then m.pierna_izq.Transform = rot(swing * pr.legL) end
	if m.pierna_der then m.pierna_der.Transform = rot(-swing * pr.legR) end
	if m.rodilla_izq then m.rodilla_izq.Transform = rot(bendL * pr.kneeL) end
	if m.rodilla_der then m.rodilla_der.Transform = rot(bendR * pr.kneeR) end

	if m.torso then
		m.torso.Transform = rot(idle * 0.03 + lunge * 0.35 + pr.lean * moving, swing * pr.twist, swing * 0.05)
	end
	if m.cabeza then
		m.cabeza.Transform = rot(math.sin(p * 2) * pr.headBob * moving + idle * 0.04 - lunge * 0.2 - pr.lean * 0.5 * moving, -swing * 0.1, math.sin(t * 0.9) * 0.05)
	end
	if m.mandibula then
		-- cuelga y tiembla; se abre del todo al atacar
		m.mandibula.Transform = rot(pr.jaw + math.sin(t * 5) * 0.05 + lunge * pr.jawAttack)
	end

	if m.brazo_izq then m.brazo_izq.Transform = rot(-swing * pr.armL - lunge * pr.lungeArmL + idle * 0.03) end
	if m.brazo_der then m.brazo_der.Transform = rot(swing * pr.armR - lunge * pr.lungeArmR, 0, idle * 0.03) end
	-- codos: se doblan al bombear los brazos
	if m.antebrazo_izq then m.antebrazo_izq.Transform = rot(-pr.elbowL * (0.5 + 0.5 * math.sin(p + 1)) * moving) end
	if m.antebrazo_der then m.antebrazo_der.Transform = rot(-pr.elbowR * (0.5 + 0.5 * math.sin(p + 1 + math.pi)) * moving) end
	if m.mano_izq then m.mano_izq.Transform = rot(math.sin(t * 3) * 0.06) end
	if m.mano_der then m.mano_der.Transform = rot(math.sin(t * 2) * 0.05) end

	-- Trepando a un autobús (el servidor publica ClimbStart / ClimbEnd): brazos arriba que se alternan, piernas pisando la
	-- pared y el cuerpo inclinado hacia ella; al final se impulsa sobre el borde
	local climbStart, climbEnd = model:GetAttribute("ClimbStart"), model:GetAttribute("ClimbEnd")
	if climbStart and climbEnd then
		local now = workspace:GetServerTimeNow()
		if now >= climbStart and now <= climbEnd then
			local u = (now - climbStart) / (climbEnd - climbStart)
			local c = (now - climbStart) * 5.2 -- ritmo de la trepada
			local pull = u > 0.8 and math.sin((u - 0.8) / 0.2 * math.pi) or 0 -- el impulso final sobre el borde
			local step = math.sin(c)
			if m.torso then m.torso.Transform = rot(0.22 + 0.06 * step + pull * 0.25, step * 0.08, 0) end
			if m.cabeza then m.cabeza.Transform = rot(-0.3 + math.sin(c * 2) * 0.04, 0, 0) end
			if m.brazo_izq then m.brazo_izq.Transform = rot(-2.45 + step * 0.55 - pull * 0.4) end
			if m.brazo_der then m.brazo_der.Transform = rot(-2.45 - step * 0.55 - pull * 0.4) end
			if m.antebrazo_izq then m.antebrazo_izq.Transform = rot(-0.5 - math.max(0, step) * 0.6) end
			if m.antebrazo_der then m.antebrazo_der.Transform = rot(-0.5 - math.max(0, -step) * 0.6) end
			if m.pierna_izq then m.pierna_izq.Transform = rot(-1.0 * math.max(0, step)) end
			if m.pierna_der then m.pierna_der.Transform = rot(-1.0 * math.max(0, -step)) end
			if m.rodilla_izq then m.rodilla_izq.Transform = rot(1.0 * math.max(0, step)) end
			if m.rodilla_der then m.rodilla_der.Transform = rot(1.0 * math.max(0, -step)) end
			if m.mandibula then m.mandibula.Transform = rot(pr.jaw + 0.25) end
		end
	end
end

-- Muerte: el servidor ancla al zombie y marca "DeadAt". Aquí cae de espaldas girando sobre los pies, rebota, tiene un
-- espasmo corto con un soplo de polvo, y al final se hunde y se desvanece (el servidor lo borra en CorpseTime).
local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function deathAnimate(model, rig)
	local deadAt = model:GetAttribute("DeadAt")
	local t = workspace:GetServerTimeNow() - deadAt
	local pr = rig.profile
	local root = rig.root

	if not rig.death then
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local base = root.CFrame
		local parts = {}
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.Transparency < 1 then
				table.insert(parts, descendant)
			end
		end
		rig.death = {
			base = base,
			feet = base.Position - Vector3.new(0, (humanoid and humanoid.HipHeight or 2) + root.Size.Y / 2, 0),
			parts = parts,
			roll = (math.random() - 0.5) * 0.5,
			puffed = false,
		}
	end
	local d = rig.death

	local fallTime = pr.fall or 0.7
	local k = math.clamp(t / fallTime, 0, 1)
	local angle = k * k * (math.pi / 2) -- cae cada vez más rápido
	local bounce = 0
	if t > fallTime and t < fallTime + 0.25 then
		bounce = math.sin((t - fallTime) / 0.25 * math.pi) * 0.3
	end
	local fade = math.clamp((t - (Config.Zombie.CorpseTime - Config.Zombie.DeathFade)) / Config.Zombie.DeathFade, 0, 1)

	-- Giro sobre los pies hacia atrás (sobre el eje derecho del cuerpo), un poco ladeado, apoyado sobre el suelo
	local pivot = CFrame.new(d.feet)
	local cf = pivot * CFrame.fromAxisAngle(d.base.RightVector, angle) * pivot:Inverse() * d.base
	cf = CFrame.new(cf.Position) * CFrame.fromAxisAngle(d.base.LookVector, d.roll * k) * (cf - cf.Position)
	root.CFrame = cf + Vector3.new(0, 0.9 * k * k + bounce - fade * 0.9, 0)

	-- Pose: brazos arriba, piernas dobladas, cabeza hacia atrás, boca abierta, y un espasmo que se apaga
	local s = smooth(t / (fallTime * 1.1))
	local spasm = t > fallTime and math.max(0, 1 - (t - fallTime) / 0.9) or 0
	local twitch = math.sin(t * 27) * spasm
	local m = rig.motors
	if m.torso then m.torso.Transform = rot(-0.15 * s + twitch * 0.08) end
	if m.cabeza then m.cabeza.Transform = rot(-0.4 * s + twitch * 0.12, 0, 0.2 * s) end
	if m.mandibula then m.mandibula.Transform = rot(0.9 * s + twitch * 0.1) end
	if m.brazo_izq then m.brazo_izq.Transform = rot(-2.1 * s + twitch * 0.25, 0, 0.5 * s) end
	if m.brazo_der then m.brazo_der.Transform = rot(-1.4 * s - twitch * 0.25, 0, -0.45 * s) end
	if m.antebrazo_izq then m.antebrazo_izq.Transform = rot(-0.7 * s) end
	if m.antebrazo_der then m.antebrazo_der.Transform = rot(-0.5 * s) end
	if m.mano_izq then m.mano_izq.Transform = rot(0.4 * s + twitch * 0.3) end
	if m.mano_der then m.mano_der.Transform = rot(-0.3 * s - twitch * 0.3) end
	if m.pierna_izq then m.pierna_izq.Transform = rot(0.35 * s + twitch * 0.15) end
	if m.pierna_der then m.pierna_der.Transform = rot(-0.25 * s - twitch * 0.15) end
	if m.rodilla_izq then m.rodilla_izq.Transform = rot(0.6 * s) end
	if m.rodilla_der then m.rodilla_der.Transform = rot(0.4 * s) end

	-- Soplo de polvo al tocar el suelo
	if t >= fallTime and not d.puffed then
		d.puffed = true
		local puff = Instance.new("Part")
		puff.Anchored = true
		puff.CanCollide = false
		puff.CanQuery = false
		puff.Transparency = 1
		puff.Size = Vector3.one
		puff.Position = d.feet + d.base.LookVector * -2.5 + Vector3.new(0, 0.5, 0)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Rate = 0
		emitter.Lifetime = NumberRange.new(0.5, 0.9)
		emitter.Speed = NumberRange.new(3, 7)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Color = ColorSequence.new(Color3.fromRGB(150, 140, 120))
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3) })
		emitter.Parent = puff
		puff.Parent = workspace
		emitter:Emit(14)
		Debris:AddItem(puff, 2)
	end

	-- Desvanecimiento final
	if fade > 0 then
		for _, part in d.parts do
			part.LocalTransparencyModifier = fade
		end
	end
end

-- Las piezas llegan al cliente poco a poco: reintenta hasta tener todas las articulaciones
local function registerWhenReady(model)
	for _ = 1, 20 do
		register(model)
		if rigs[model] or not model.Parent then
			return
		end
		task.wait(0.5)
	end
end

function ZombieAnimator.start()
	for _, model in CollectionService:GetTagged("ZombieRig") do
		task.spawn(registerWhenReady, model)
	end
	CollectionService:GetInstanceAddedSignal("ZombieRig"):Connect(function(model)
		task.spawn(registerWhenReady, model)
	end)

	RunService.Heartbeat:Connect(function(dt)
		local camera = workspace.CurrentCamera
		for model, rig in rigs do
			-- lejos de la cámara no vale la pena animar
			if (rig.root.Position - camera.CFrame.Position).Magnitude < 200 then
				if model:GetAttribute("DeadAt") then
					deathAnimate(model, rig)
				else
					animate(model, rig, dt)
				end
			end
		end
	end)
end

return ZombieAnimator
