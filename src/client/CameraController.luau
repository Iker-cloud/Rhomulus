-- Primera/tercera persona (tecla V). En ambas el jugador mira hacia donde apunta la cámara.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local firstPerson = false

local CameraController = {}

local function apply()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if firstPerson then
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 0.5
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		if humanoid then
			humanoid.CameraOffset = Vector3.zero
		end
	else
		local distance = Config.Camera.ThirdPersonDistance
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = distance
		player.CameraMaxZoomDistance = distance
		if humanoid then
			humanoid.CameraOffset = Config.Camera.ShoulderOffset
		end
	end
end

local function faceCamera()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root) or humanoid.Health <= 0 then
		return
	end

	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
	humanoid.AutoRotate = false

	local look = workspace.CurrentCamera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.001 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
	end
end

function CameraController.start()
	player.CharacterAdded:Connect(function()
		task.wait()
		apply()
	end)
	if player.Character then
		apply()
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.V then
			firstPerson = not firstPerson
			apply()
		end
	end)

	RunService.RenderStepped:Connect(faceCamera)
end

return CameraController
