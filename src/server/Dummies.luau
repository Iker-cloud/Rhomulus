-- Maniquíes de práctica del lobby (modelo de maniqui-encadenado.glb): reciben daño y reaparecen al morir.
-- Son objetos fijos con un Humanoid para que las armas puedan dañarlos; el cliente los hace tambalear al recibir un tiro
-- (DummyAnimator) y les dibuja la barra de vida (EnemyBars).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PropModel = require(script.Parent.PropModel)
local Data = require(script.Parent.ZombieData.Maniqui)

local Dummies = {}

local folder = Instance.new("Folder")
folder.Name = "Dummies"
folder.Parent = workspace

local function spawnDummy(position)
	-- De frente a los jugadores (el lobby los espera mirando hacia -Z, los maniquíes miran hacia +Z)
	local model, root = PropModel.build(Data, position, math.pi)
	model.Name = "Maniquí"
	root.Name = "HumanoidRootPart"

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = Config.Dummy.Health
	humanoid.Health = Config.Dummy.Health
	humanoid.DisplayName = "Maniquí"
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.Parent = model

	CollectionService:AddTag(model, "DummyRig")
	model.Parent = folder

	humanoid.Died:Connect(function()
		task.wait(Config.Dummy.RespawnTime)
		model:Destroy()
		spawnDummy(position)
	end)
end

function Dummies.start()
	for _, position in Config.Dummy.Positions do
		spawnDummy(position)
	end
end

return Dummies
