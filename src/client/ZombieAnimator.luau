-- Animación de los zombies hechos con articulaciones (ZombieModel). Mueve los Motor6D en el cliente (no se replica).
-- Cada modelo tiene un perfil: "Brotado" (el común) camina arrastrando los pies; "Desbocado" (el rápido) corre
-- inclinado hacia adelante con los brazos sueltos y la boca abierta.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local ZombieAnimator = {}

-- freq: pasos por studs recorridos; el resto son amplitudes en radianes
local PROFILES = {
	Brotado = {
		freq = 0.9,
		legL = 0.55, legR = 0.45, kneeL = 0.7, kneeR = 0.5,
		armL = 0.5, armR = 0.12, elbowL = 0, elbowR = 0.08,
		lean = 0, twist = 0.12, headBob = 0.05, jaw = 0.08, jawAttack = 0.5,
		lungeArmL = 0.9, lungeArmR = 0.5,
	},
	-- Tanque: paso lento y pesado, con los brazos enormes balanceándose
	Tanque = {
		freq = 0.5,
		legL = 0.45, legR = 0.45, kneeL = 0.55, kneeR = 0.55,
		armL = 0.35, armR = 0.35, elbowL = 0.25, elbowR = 0.25,
		lean = 0.1, twist = 0.18, headBob = 0.04, jaw = 0.1, jawAttack = 0.5,
		lungeArmL = 1.3, lungeArmR = 1.3,
	},
	Desbocado = {
		freq = 0.55,
		legL = 0.95, legR = 0.95, kneeL = 1.2, kneeR = 1.2,
		armL = 0.95, armR = 0.95, elbowL = 0.6, elbowR = 0.6,
		lean = 0.3, twist = 0.2, headBob = 0.1, jaw = 0.3, jawAttack = 0.6,
		lungeArmL = 1.1, lungeArmR = 1.1,
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
				animate(model, rig, dt)
			end
		end
	end)
end

return ZombieAnimator
