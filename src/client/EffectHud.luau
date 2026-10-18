-- Efecto de la jeringa activa (server/Pharmacy): una placa sobre la jeringa de vida con el nombre del efecto, lo que hace y los segundos que
-- quedan. En el bajón sale en gris con lo que penaliza. Lee los atributos del jugador FxId, FxPhase y FxEnd.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local UiFit = require(script.Parent.UiFit)

local player = Players.LocalPlayer
local P = Config.Pharmacy

local OSWALD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local OSWALD_LIGHT = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Regular)
local CRASH = Color3.fromRGB(150, 146, 140)
local DARK = Color3.fromRGB(14, 13, 13)

local EffectHud = {}

local function label(parent, size, position, textSize, font, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.FontFace = font
	l.TextSize = textSize
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Text = ""
	l.Parent = parent
	return l
end

function EffectHud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "EffectHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	local root = Instance.new("Frame")
	root.AnchorPoint = Vector2.new(0, 1)
	root.Position = UDim2.new(0, 20, 1, -190) -- sobre los avisos del equipo, que salen justo encima de la jeringa de vida
	root.Size = UDim2.fromOffset(300, 58)
	root.BackgroundColor3 = DARK
	root.BackgroundTransparency = 0.15
	root.BorderSizePixel = 0
	root.Visible = false
	root.Parent = gui
	UiFit.scale(root)

	local stripe = Instance.new("Frame")
	stripe.Size = UDim2.new(0, 6, 1, 0)
	stripe.BorderSizePixel = 0
	stripe.Parent = root
	local name = label(root, UDim2.new(1, -90, 0, 26), UDim2.fromOffset(16, 4), 24, OSWALD)
	local desc = label(root, UDim2.new(1, -90, 0, 18), UDim2.fromOffset(16, 28), 15, OSWALD_LIGHT)
	desc.TextColor3 = Color3.fromRGB(215, 210, 204)
	local seconds = label(root, UDim2.fromOffset(70, 40), UDim2.new(1, -76, 0, 4), 34, OSWALD, Enum.TextXAlignment.Right)
	local back = Instance.new("Frame")
	back.Position = UDim2.new(0, 16, 1, -9)
	back.Size = UDim2.new(1, -24, 0, 4)
	back.BackgroundColor3 = Color3.fromRGB(45, 42, 40)
	back.BorderSizePixel = 0
	back.Parent = root
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = back

	-- Phial de Visión: los zombies se resaltan a través de las paredes (Roblox dibuja como mucho unos 31 resaltados a la vez)
	task.spawn(function()
		local zombies = workspace:WaitForChild("Zombies")
		while true do
			task.wait(0.4)
			local on = player:GetAttribute("FxVision") == true
			local count = 0
			for _, zombie in zombies:GetChildren() do
				local mark = zombie:FindFirstChild("VisionMark")
				local alive = zombie:GetAttribute("DeadAt") == nil
				if on and alive and count < 28 then
					count += 1
					if not mark then
						mark = Instance.new("Highlight")
						mark.Name = "VisionMark"
						mark.FillColor = Color3.fromRGB(190, 120, 255)
						mark.FillTransparency = 0.6
						mark.OutlineColor = Color3.fromRGB(225, 190, 255)
						mark.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
						mark.Parent = zombie
					end
				elseif mark then
					mark:Destroy()
				end
			end
		end
	end)

	RunService.RenderStepped:Connect(function()
		local id = player:GetAttribute("FxId")
		local def = id and P.Effects[id]
		if not def then
			root.Visible = false
			return
		end
		local crash = player:GetAttribute("FxPhase") == "crash"
		local total = crash and P.CrashDuration or P.Duration
		local left = math.max(0, (player:GetAttribute("FxEnd") or 0) - workspace:GetServerTimeNow())
		local color = crash and CRASH or def.Color
		root.Visible = true
		stripe.BackgroundColor3 = color
		fill.BackgroundColor3 = color
		name.Text = crash and "BAJÓN" or def.Upper
		name.TextColor3 = color
		desc.Text = crash and def.CrashDesc or def.Desc
		seconds.Text = `{math.ceil(left)}`
		fill.Size = UDim2.fromScale(math.clamp(left / total, 0, 1), 1)
	end)
end

return EffectHud
