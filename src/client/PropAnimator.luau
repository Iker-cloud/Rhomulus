-- Abre y cierra la tapa de las cajas según el atributo Open del modelo (se anima en el cliente).
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local PropAnimator = {}

local OPEN_ANGLE = math.rad(105)
local SPEED = 7 -- qué tan rápido se abre y se cierra

local props = {} -- [Model] = { lid, angle }

local function register(model)
	if props[model] then
		return
	end
	local lid = model:FindFirstChild("tapa", true)
	if not (lid and lid:IsA("Motor6D") and model:GetAttribute("JointCount")) then
		return
	end
	props[model] = { lid = lid, angle = 0 }
	model.Destroying:Connect(function()
		props[model] = nil
	end)
end

-- Las piezas llegan al cliente poco a poco: reintenta hasta encontrar la tapa
local function registerWhenReady(model)
	for _ = 1, 20 do
		register(model)
		if props[model] or not model.Parent then
			return
		end
		task.wait(0.5)
	end
end

function PropAnimator.start()
	for _, model in CollectionService:GetTagged("PropRig") do
		task.spawn(registerWhenReady, model)
	end
	CollectionService:GetInstanceAddedSignal("PropRig"):Connect(function(model)
		task.spawn(registerWhenReady, model)
	end)

	RunService.Heartbeat:Connect(function(dt)
		for model, prop in props do
			local target = model:GetAttribute("Open") and OPEN_ANGLE or 0
			if math.abs(target - prop.angle) > 0.002 then
				prop.angle += (target - prop.angle) * math.min(1, dt * SPEED)
				-- Rotación negativa = el frente de la tapa sube (el frente del modelo es +Z en el marco de la articulación)
				prop.lid.Transform = CFrame.Angles(-prop.angle, 0, 0)
			end
		end
	end)
end

return PropAnimator
