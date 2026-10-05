-- Detecta clic (disparar) y R (recargar). El servidor decide si el tiro da.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Shooting = {}

local function drawTracer(_shooter, from, to)
	local length = (to - from).Magnitude
	local tracer = Instance.new("Part")
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanQuery = false
	tracer.CanTouch = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = Color3.fromRGB(255, 220, 120)
	tracer.Size = Vector3.new(0.1, 0.1, length)
	tracer.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
	tracer.Parent = workspace
	Debris:AddItem(tracer, 0.06)
end

function Shooting.start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- El disparo sale del centro de la pantalla
			local camera = workspace.CurrentCamera
			local size = camera.ViewportSize
			local ray = camera:ViewportPointToRay(size.X / 2, size.Y / 2)
			Remotes.Fire:FireServer(ray.Origin, ray.Direction)
		elseif input.KeyCode == Enum.KeyCode.R then
			Remotes.Reload:FireServer()
		end
	end)

	Remotes.Shot.OnClientEvent:Connect(drawTracer)
end

return Shooting
