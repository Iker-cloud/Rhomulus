-- TEMPORAL: obstáculos para probar la IA y el director. Se quita al tener el mapa real.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local TestArena = {}

function TestArena.start()
	for _, w in Config.TestArena.Walls do
		local part = Instance.new("Part")
		part.Name = "TestWall"
		part.Anchored = true
		part.Size = w.Size
		part.Position = w.Position
		part.Color = Color3.fromRGB(80, 80, 85)
		part.Parent = workspace
	end
end

return TestArena
