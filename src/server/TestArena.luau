-- TEMPORAL (fase 3): obstáculos y un zombie que reaparece, para probar la IA. Se quita al tener el mapa real.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Zombies = require(script.Parent.Zombies)

local TestArena = {}

local function wall(position, size)
	local part = Instance.new("Part")
	part.Name = "TestWall"
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = Color3.fromRGB(80, 80, 85)
	part.Parent = workspace
end

local function spawnLoop()
	while true do
		local zombie = Zombies.spawn("Common", Config.TestArena.ZombieSpawn)
		zombie.Humanoid.Died:Wait()
		task.wait(Config.TestArena.RespawnTime)
	end
end

function TestArena.start()
	for _, w in Config.TestArena.Walls do
		wall(w.Position, w.Size)
	end
	task.spawn(spawnLoop)
end

return TestArena
