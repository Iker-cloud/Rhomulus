-- Indicador de las mutaciones de la ronda: unas fichas pequeñas en el borde izquierdo de la pantalla (arriba, donde no estorban) con la
-- insignia de la mutación, su nombre, su rareza y el XP extra que da. Salen deslizándose al empezar la partida y se quedan todo el rato;
-- al pasar el cursor (o tocar) se despliega lo que hace. La legendaria late. Lee Workspace.Mutators (los ids, ver server/Difficulty).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Mutators = require(ReplicatedStorage.Shared.Mutators)
local UiFit = require(script.Parent.UiFit)
local Paper = require(script.Parent.PaperStyle)

local player = Players.LocalPlayer

local OSWALD = Paper.Head
local OSWALD_LIGHT = Paper.Typewriter
local BG = Paper.Paper
local CREAM = Paper.Ink -- texto principal (tinta)
local GRAY = Paper.Soft

local MutatorHud = {}

local function monogram(id)
	local upper = Mutators[id].Upper
	local ok, text = pcall(function()
		return utf8.char(utf8.codepoint(upper, 1, 2))
	end)
	return ok and text or string.sub(upper, 1, 2)
end

local function label(parent, text, size, position, textSize, color, font)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.FontFace = font or OSWALD
	l.TextSize = textSize
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.Parent = parent
	return l
end

function MutatorHud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MutatorHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 11
	gui.Parent = player:WaitForChild("PlayerGui")

	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(14, 104)
	list.Size = UDim2.fromOffset(244, 200)
	list.Parent = gui
	UiFit.scale(list)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local title = label(list, "", UDim2.fromOffset(240, 18), UDim2.fromOffset(0, 0), 14, GRAY, OSWALD_LIGHT)
	title.LayoutOrder = 0
	title.Visible = false

	local chips = {}
	local pulses = {} -- bordes que laten (la legendaria)

	local function clear()
		for _, chip in chips do
			chip:Destroy()
		end
		table.clear(chips)
		table.clear(pulses)
	end

	local function makeChip(id, index)
		local def = Mutators[id]
		local rarity = Mutators.Rarities[def.Rarity]
		local bonus = math.floor(def.Bonus * 100 + 0.5)

		-- El contenedor lo coloca el UIListLayout; la ficha (un botón) se mueve libre dentro para entrar deslizándose y, al pasar el cursor
		-- o tocar, desplegar la descripción
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.LayoutOrder = index
		holder.Size = UDim2.fromOffset(228, 56)
		holder.Parent = list
		local chip = Instance.new("TextButton")
		chip.AutoButtonColor = false
		chip.Text = ""
		chip.Size = UDim2.fromOffset(228, 56)
		chip.BackgroundColor3 = BG
		chip.BackgroundTransparency = 0
		chip.BorderSizePixel = 0
		chip.ClipsDescendants = true
		chip.Parent = holder
		Instance.new("UICorner", chip).CornerRadius = UDim.new(0, 8)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Paper.onPaper(rarity.Color)
		stroke.Thickness = 2
		stroke.Transparency = 0.15
		stroke.Parent = chip
		if def.Rarity == "Legendary" or def.Rarity == "Epic" then
			table.insert(pulses, { stroke = stroke, speed = def.Rarity == "Legendary" and 3 or 1.6 })
		end

		local badge = Instance.new("Frame")
		badge.Position = UDim2.fromOffset(8, 9)
		badge.Size = UDim2.fromOffset(38, 38)
		badge.BackgroundColor3 = def.Color
		badge.BackgroundTransparency = def.Icon and 1 or 0
		badge.BorderSizePixel = 0
		badge.Parent = chip
		Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 7)
		local letters = label(badge, monogram(id), UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), 22, Paper.Ink)
		if def.Icon then
			letters.Visible = false
			local image = Instance.new("ImageLabel")
			image.BackgroundTransparency = 1
			image.Size = UDim2.fromScale(1, 1)
			image.Image = def.Icon
			image.ScaleType = Enum.ScaleType.Fit
			image.Parent = badge
		end
		letters.TextXAlignment = Enum.TextXAlignment.Center

		local name = label(chip, def.Upper, UDim2.fromOffset(170, 26), UDim2.fromOffset(56, 6), 21, CREAM)
		name.TextScaled = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 21
		limit.Parent = name
		local rarityLabel = label(chip, `{rarity.Text}  ·  {bonus > 0 and `+{bonus} % XP` or "NO BONUS"}`, UDim2.fromOffset(170, 16), UDim2.fromOffset(56, 33), 12, Paper.onPaper(rarity.Color), OSWALD_LIGHT)
		local description = label(chip, def.Description, UDim2.fromOffset(212, 52), UDim2.fromOffset(8, 62), 12, Paper.Soft, OSWALD_LIGHT)
		description.TextWrapped = true
		description.TextYAlignment = Enum.TextYAlignment.Top

		local function expand(open)
			local size = UDim2.fromOffset(228, open and 124 or 56)
			TweenService:Create(chip, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Size = size }):Play()
			TweenService:Create(holder, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Size = size }):Play()
		end
		chip.MouseEnter:Connect(function()
			expand(true)
		end)
		chip.MouseLeave:Connect(function()
			expand(false)
		end)
		local open = false
		chip.Activated:Connect(function() -- en celular se toca
			open = not open
			expand(open)
		end)

		-- Entra deslizándose desde el borde
		chip.Position = UDim2.fromOffset(-260, 0)
		return holder, chip
	end

	local function refresh()
		local stage = workspace:GetAttribute("Stage")
		local ids = Mutators.parse(workspace:GetAttribute("Mutators"))
		clear()
		local playing = stage ~= nil and stage ~= "Vote" and stage ~= "Result"
		title.Visible = playing and #ids > 0
		if not (playing and #ids > 0) then
			return
		end
		title.Text = #ids == 1 and "ROUND MUTATION" or "ROUND MUTATIONS"
		for index, id in ids do
			local holder, chip = makeChip(id, index)
			table.insert(chips, holder)
			task.delay((index - 1) * 0.15, function()
				if chip.Parent then
					TweenService:Create(chip, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(0, 0) }):Play()
				end
			end)
		end
	end
	workspace:GetAttributeChangedSignal("Stage"):Connect(refresh)
	workspace:GetAttributeChangedSignal("Mutators"):Connect(refresh)
	refresh()

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for _, pulse in pulses do
			pulse.stroke.Transparency = 0.1 + 0.45 * (0.5 + 0.5 * math.sin(now * pulse.speed))
		end
		-- No estorba al caer o ser espectador
		local state = player:GetAttribute("State")
		list.Visible = state == "Normal" or state == nil
	end)
end

return MutatorHud
