-- Los maniquíes tambalean al recibir un tiro: el cuerpo se echa hacia atrás, la cabeza cabecea y los brazos se sacuden,
-- con un resorte que los devuelve a su sitio. Se anima en el cliente (no se replica).
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local DummyAnimator = {}

local STIFFNESS = 90 -- qué tan fuerte regresa a su sitio
local DAMPING = 5 -- qué tanto se frena

local dummies = {} -- [Model] = { motors, spring = { cuerpo, cabeza, brazoIzq, brazoDer } }

local function newSpring()
	return { angle = 0, speed = 0 }
end

local function register(model)
	if dummies[model] then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local expected = model:GetAttribute("JointCount")
	local motors = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			motors[descendant.Name] = descendant
		end
	end
	local found = 0
	for _ in motors do
		found += 1
	end
	if not humanoid or not expected or found < expected then
		return -- aún no llegan todas las piezas
	end

	local dummy = {
		motors = motors,
		body = newSpring(),
		head = newSpring(),
		armL = newSpring(),
		armR = newSpring(),
		lastHealth = humanoid.Health,
	}
	dummies[model] = dummy

	humanoid.HealthChanged:Connect(function(health)
		if health < dummy.lastHealth then
			-- En el marco de la articulación el frente es +Z: rotación negativa = el cuerpo se echa hacia atrás
			local push = math.clamp((dummy.lastHealth - health) / 20, 0.5, 2)
			dummy.body.speed -= 2.2 * push
			dummy.head.speed -= 3.5 * push
			dummy.armL.speed += 4 * push * (math.random() < 0.5 and 1 or -1)
			dummy.armR.speed += 4 * push * (math.random() < 0.5 and 1 or -1)
		end
		dummy.lastHealth = health
	end)
	model.Destroying:Connect(function()
		dummies[model] = nil
	end)
end

local function step(spring, dt)
	spring.speed += (-STIFFNESS * spring.angle - DAMPING * spring.speed) * dt
	spring.angle += spring.speed * dt
end

local function registerWhenReady(model)
	for _ = 1, 20 do
		register(model)
		if dummies[model] or not model.Parent then
			return
		end
		task.wait(0.5)
	end
end

function DummyAnimator.start()
	for _, model in CollectionService:GetTagged("DummyRig") do
		task.spawn(registerWhenReady, model)
	end
	CollectionService:GetInstanceAddedSignal("DummyRig"):Connect(function(model)
		task.spawn(registerWhenReady, model)
	end)

	RunService.Heartbeat:Connect(function(dt)
		dt = math.min(dt, 1 / 30)
		for _, dummy in dummies do
			step(dummy.body, dt)
			step(dummy.head, dt)
			step(dummy.armL, dt)
			step(dummy.armR, dt)
			local m = dummy.motors
			if m.cuerpo then m.cuerpo.Transform = CFrame.Angles(dummy.body.angle, 0, dummy.body.angle * 0.25) end
			if m.cabeza then m.cabeza.Transform = CFrame.Angles(dummy.head.angle, 0, -dummy.head.angle * 0.3) end
			if m.brazo_izq then m.brazo_izq.Transform = CFrame.Angles(dummy.armL.angle, 0, 0) end
			if m.brazo_der then m.brazo_der.Transform = CFrame.Angles(dummy.armR.angle, 0, 0) end
		end
	end)
end

return DummyAnimator
