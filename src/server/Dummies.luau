-- Maniquíes de práctica: reciben daño y reaparecen al morir.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Dummies = {}

local function makePart(name, size, position, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.Color = Color3.fromRGB(150, 160, 150)
	part.Parent = parent
	return part
end

local function build(base)
	local model = Instance.new("Model")
	model.Name = "Maniquí"

	local root = makePart("HumanoidRootPart", Vector3.new(2, 2, 1), base + Vector3.new(0, 3, 0), model)
	makePart("Legs", Vector3.new(2, 2, 1), base + Vector3.new(0, 1, 0), model)
	makePart("Head", Vector3.new(1.2, 1.2, 1.2), base + Vector3.new(0, 4.6, 0), model)
	model.PrimaryPart = root

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = Config.Dummy.Health
	humanoid.Health = Config.Dummy.Health
	humanoid.DisplayName = "Maniquí"
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.Parent = model

	return model
end

local function spawnDummy(base)
	local model = build(base)
	model.Parent = workspace

	model.Humanoid.Died:Connect(function()
		task.wait(Config.Dummy.RespawnTime)
		model:Destroy()
		spawnDummy(base)
	end)
end

function Dummies.start()
	for _, position in Config.Dummy.Positions do
		spawnDummy(position)
	end
end

return Dummies
