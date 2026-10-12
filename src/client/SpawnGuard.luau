-- Al aparecer (o ser rescatado) el servidor deja el personaje quieto con el atributo "AwaitGround". Aquí se comprueba
-- que ESTE cliente ya tiene suelo bajo los pies (con StreamingEnabled puede tardar) y se avisa para que lo suelte.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local SpawnGuard = {}

function SpawnGuard.start()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true -- la decoración sin colisión no cuenta como suelo
	local sent = false

	RunService.Heartbeat:Connect(function()
		local character = player.Character
		if not character or not character:GetAttribute("AwaitGround") then
			sent = false
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if sent or not root then
			return
		end
		params.FilterDescendantsInstances = { character }
		if workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params) then
			sent = true
			Remotes.GroundReady:FireServer()
		end
	end)
end

return SpawnGuard
