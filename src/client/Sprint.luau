-- Correr: mantener Shift. Se corre solo si no se apunta, no se dispara y no se recarga (al hacerlo vuelve a caminar y,
-- si sigue el Shift, retoma la carrera al terminar). El servidor decide la velocidad (PlayerState) y solo vale en estado Normal.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shooting = require(script.Parent.Shooting)
local Controls = require(script.Parent.Controls)

local player = Players.LocalPlayer

local Sprint = {}

local held = false
local sent = false

local function wanted()
	if not held or Shooting.isReloading() then
		return false
	end
	if Controls.isFiring() or Controls.isAiming() then
		return false
	end
	return (player:GetAttribute("State") or "Normal") == "Normal" and player:GetAttribute("Carrying") == nil
end

-- El botón de correr del celular se alterna
function Sprint.setHeld(on)
	held = on
end

function Sprint.isHeld()
	return held
end

local function isShift(input)
	return input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift
end

function Sprint.start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if isShift(input) and not processed then
			held = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if isShift(input) then
			held = false
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		held = false
	end)

	RunService.Heartbeat:Connect(function()
		local want = wanted()
		if want ~= sent then
			sent = want
			Remotes.Sprint:FireServer(want)
		end
	end)
end

return Sprint
