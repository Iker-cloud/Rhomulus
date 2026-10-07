-- Marcador rojo en la mira (y un sonido) cuando un disparo le da a la cabeza de un zombie.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SoundController = require(script.Parent.SoundController)

local RED = Color3.fromRGB(255, 60, 50)
local SHOW_TIME = 0.3

local CritMarker = {}

function CritMarker.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CritMarker"
	gui.IgnoreGuiInset = true -- el centro es el centro real de la pantalla, donde está la mira
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local marker = Instance.new("Frame")
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Position = UDim2.fromScale(0.5, 0.5)
	marker.Size = UDim2.fromOffset(34, 34)
	marker.BackgroundTransparency = 1
	marker.Visible = false
	marker.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = marker

	-- Cuatro rayitas en diagonal, separadas del centro
	local ticks = {}
	for i = 1, 4 do
		local tick = Instance.new("Frame")
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.Size = UDim2.fromOffset(10, 3)
		tick.BackgroundColor3 = RED
		tick.BorderSizePixel = 0
		local angle = math.rad(45 + (i - 1) * 90)
		tick.Position = UDim2.new(0.5, math.cos(angle) * 12, 0.5, math.sin(angle) * 12)
		tick.Rotation = math.deg(angle)
		tick.Parent = marker
		ticks[i] = tick
	end

	local token = 0
	Remotes.Crit.OnClientEvent:Connect(function(killed)
		token += 1
		local mine = token
		marker.Visible = true
		scale.Scale = killed and 1.5 or 1.2
		for _, tick in ticks do
			tick.BackgroundTransparency = 0
		end
		TweenService:Create(scale, TweenInfo.new(SHOW_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		for _, tick in ticks do
			TweenService:Create(tick, TweenInfo.new(SHOW_TIME, Enum.EasingStyle.Linear), { BackgroundTransparency = 1 }):Play()
		end
		task.delay(SHOW_TIME, function()
			if token == mine then
				marker.Visible = false
			end
		end)
		local S = Config.Sounds
		SoundController.play2D(S.Headshot, S.Volume.Headshot, S.HeadshotPitch)
	end)
end

return CritMarker
