-- Calidad gráfica del cliente y panel de diagnóstico. Los niveles (Config.Performance.Levels) bajan lo que más pesa en celular:
-- alcance de los faroles, sombra de la linterna y sombras globales. En AUTO el celular empieza en el nivel de Config.Performance.TouchDefault
-- y baja solo si los FPS se mantienen bajos. El diagnóstico (AJUSTES → RENDIMIENTO) muestra FPS, memoria y piezas para medir en un celular
-- real sin la consola de desarrollador.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local Config = require(ReplicatedStorage.Shared.Config)
local Controls = require(script.Parent.Controls)

local P = Config.Performance
local player = Players.LocalPlayer

local Performance = {}

local auto = true -- AUTO o un nivel fijo
local level = Controls.isTouch() and P.TouchDefault or P.PcDefault
local changed = Instance.new("BindableEvent")
Performance.changed = changed.Event

function Performance.level()
	return level
end

function Performance.isAuto()
	return auto
end

function Performance.levelName()
	return (auto and "AUTO · " or "") .. P.Levels[level].Name
end

-- Alcance de los faroles (client/NightLights)
function Performance.lampDistance()
	return P.Levels[level].LampDistance
end

local function apply()
	local L = P.Levels[level]
	Lighting.GlobalShadows = L.GlobalShadows
	changed:Fire(level)
end

-- Modo del jugador: "auto" o un número de nivel
function Performance.setMode(mode)
	if mode == "auto" then
		auto = true
		level = Controls.isTouch() and P.TouchDefault or P.PcDefault
	else
		auto = false
		level = math.clamp(mode, 1, #P.Levels)
	end
	apply()
end

-- AUTO → ALTA → MEDIA → BAJA → AUTO
function Performance.cycleMode(direction)
	local current = auto and 0 or level
	local count = #P.Levels + 1
	Performance.setMode(((current + direction) % count) == 0 and "auto" or (current + direction) % count)
end

-- Diagnóstico -----------------------------------------------------------------------------------------------------------------

local overlay = nil
local overlayShown = false

function Performance.setOverlay(on)
	overlayShown = on
	if overlay then
		overlay.Enabled = on
	end
end

function Performance.isOverlayShown()
	return overlayShown
end

local function buildOverlay()
	local gui = Instance.new("ScreenGui")
	gui.Name = "PerfOverlay"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.DisplayOrder = 90
	gui.Enabled = overlayShown
	gui.Parent = player:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Position = UDim2.fromOffset(10, 8)
	label.Size = UDim2.fromOffset(330, 54)
	label.BackgroundColor3 = Color3.new(0, 0, 0)
	label.BackgroundTransparency = 0.45
	label.BorderSizePixel = 0
	label.Font = Enum.Font.Code
	label.TextSize = 13
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Parent = gui
	return gui, label
end

function Performance.start()
	local gui, label
	gui, label = buildOverlay()
	overlay = gui
	apply()

	-- Linterna sin sombra en los niveles bajos (cada 1 s, por si el personaje reaparece)
	task.spawn(function()
		while true do
			task.wait(1)
			local character = player.Character
			local head = character and character:FindFirstChild("Head")
			local attachment = head and head:FindFirstChild("Linterna")
			local light = attachment and attachment:FindFirstChildWhichIsA("SpotLight")
			if light then
				light.Shadows = P.Levels[level].FlashlightShadows
			end
		end
	end)

	-- FPS: promedio cada 0.5 s, mínimo de los últimos 5 s y bajada automática
	local frames, accumulated = 0, 0
	local fps = 60
	local history = {} -- fps por medio segundo
	local lowFor = 0
	local cooldown = 0
	RunService.RenderStepped:Connect(function(dt)
		frames += 1
		accumulated += dt
		if accumulated < 0.5 then
			return
		end
		fps = frames / accumulated
		frames, accumulated = 0, 0
		table.insert(history, fps)
		if #history > 10 then
			table.remove(history, 1)
		end

		-- bajada automática (solo con la pantalla en juego y en AUTO)
		cooldown = math.max(0, cooldown - 0.5)
		if auto and cooldown == 0 and level < #P.Levels and (workspace:GetAttribute("Stage") or "Lobby") ~= "Vote" then
			if fps < P.AutoDegrade.FpsBelow then
				lowFor += 0.5
				if lowFor >= P.AutoDegrade.Seconds then
					level += 1
					lowFor = 0
					cooldown = P.AutoDegrade.Cooldown
					apply()
				end
			else
				lowFor = 0
			end
		end

		if overlayShown then
			local minimum = math.huge
			for _, value in history do
				minimum = math.min(minimum, value)
			end
			local memory = Stats:GetTotalMemoryUsageMb()
			local instances = 0
			pcall(function()
				instances = Stats.InstanceCount
			end)
			label.Text = string.format(
				"FPS %d (mín %d)  ·  %s\nMemoria %d MB  ·  Instancias %d",
				fps,
				minimum,
				Performance.levelName(),
				memory,
				instances
			)
		end
	end)
end

return Performance
