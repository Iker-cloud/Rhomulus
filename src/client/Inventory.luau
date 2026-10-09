-- Barra de inventario (abajo a la derecha): 7 ranuras con número de tecla. 1 = arma principal, 2 = pistola, 3 a 7 = objetos
-- (Config.Items.Order). La ranura del arma activa va en amarillo. Los objetos muestran cuántos quedan en la esquina y se
-- usan con su tecla (o tocando la ranura en celular). La munición NO va aquí: queda junto a la mira (AmmoHud).
-- El botiquín lo usa MedkitHud (tecla 4); lanzables y vendas, esta barra con Remotes.UseItem.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(246, 196, 70)
local DARK = Color3.fromRGB(20, 20, 22)
local OSWALD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local SLOT = 64
local GAP = 6

local Inventory = {}

local function box(parent, size, position, color, rotation, anchor)
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = position
	f.AnchorPoint = anchor or Vector2.zero
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Rotation = rotation or 0
	f.Parent = parent
	return f
end

local function round(f, radius)
	Instance.new("UICorner", f).CornerRadius = radius or UDim.new(1, 0)
end

local function text(parent, str, size, position, textSize, color, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.FontFace = OSWALD
	l.TextSize = textSize
	l.TextColor3 = color
	l.Text = str
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	l.Parent = parent
	return l
end

-- Iconos dibujados con rectángulos (mismo estilo que el resto de la interfaz); `p` es un contenedor de 40 × 32
local ICONS = {}
function ICONS.Pistol(p)
	box(p, UDim2.fromOffset(22, 7), UDim2.fromOffset(9, 8), Color3.fromRGB(190, 186, 180))
	box(p, UDim2.fromOffset(7, 13), UDim2.fromOffset(10, 14), Color3.fromRGB(160, 156, 150), 12)
end
function ICONS.Rifle(p)
	box(p, UDim2.fromOffset(30, 6), UDim2.fromOffset(6, 10), Color3.fromRGB(235, 232, 225))
	box(p, UDim2.fromOffset(8, 5), UDim2.fromOffset(0, 11), Color3.fromRGB(235, 232, 225))
	box(p, UDim2.fromOffset(6, 12), UDim2.fromOffset(14, 16), Color3.fromRGB(200, 196, 190), 10)
	box(p, UDim2.fromOffset(5, 8), UDim2.fromOffset(24, 15), Color3.fromRGB(200, 196, 190))
end
function ICONS.Grenade(p)
	round(box(p, UDim2.fromOffset(22, 22), UDim2.fromOffset(9, 9), Color3.fromRGB(96, 116, 58)))
	box(p, UDim2.fromOffset(8, 5), UDim2.fromOffset(16, 4), Color3.fromRGB(150, 150, 146))
	box(p, UDim2.fromOffset(2, 5), UDim2.fromOffset(25, 1), Color3.fromRGB(200, 200, 196))
end
function ICONS.Medkit(p)
	box(p, UDim2.fromOffset(26, 22), UDim2.fromOffset(7, 8), Color3.fromRGB(240, 238, 232))
	box(p, UDim2.fromOffset(14, 4), UDim2.fromOffset(13, 14), Color3.fromRGB(214, 56, 48))
	box(p, UDim2.fromOffset(4, 14), UDim2.fromOffset(18, 9), Color3.fromRGB(214, 56, 48))
	box(p, UDim2.fromOffset(10, 4), UDim2.fromOffset(15, 4), Color3.fromRGB(170, 168, 162))
end
function ICONS.Molotov(p)
	box(p, UDim2.fromOffset(14, 16), UDim2.fromOffset(13, 14), Color3.fromRGB(150, 98, 44))
	box(p, UDim2.fromOffset(6, 7), UDim2.fromOffset(17, 8), Color3.fromRGB(150, 98, 44))
	box(p, UDim2.fromOffset(8, 9), UDim2.fromOffset(16, 0), Color3.fromRGB(255, 142, 40), 20)
	box(p, UDim2.fromOffset(4, 5), UDim2.fromOffset(18, 3), Color3.fromRGB(255, 220, 90), 20)
end
function ICONS.Bandage(p)
	box(p, UDim2.fromOffset(28, 12), UDim2.fromOffset(6, 10), Color3.fromRGB(236, 224, 196), -20)
	box(p, UDim2.fromOffset(8, 12), UDim2.fromOffset(16, 10), Color3.fromRGB(214, 56, 48), -20)
end
function ICONS.Flare(p)
	box(p, UDim2.fromOffset(8, 22), UDim2.fromOffset(16, 9), Color3.fromRGB(226, 60, 48), 20)
	box(p, UDim2.fromOffset(6, 6), UDim2.fromOffset(21, 4), Color3.fromRGB(255, 190, 80))
	box(p, UDim2.fromOffset(3, 3), UDim2.fromOffset(15, 2), Color3.fromRGB(255, 240, 160))
end

local function buildSlot(parent, index, id, label)
	local slot = Instance.new("TextButton")
	slot.Name = "Slot" .. index
	slot.AutoButtonColor = false
	slot.Text = ""
	slot.Size = UDim2.fromOffset(SLOT, SLOT)
	slot.Position = UDim2.fromOffset((index - 1) * (SLOT + GAP), 0)
	slot.BackgroundColor3 = DARK
	slot.BackgroundTransparency = 0.12
	slot.BorderSizePixel = 0
	slot.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(60, 60, 64)
	stroke.Thickness = 2
	stroke.Parent = slot

	local number = text(slot, tostring(index), UDim2.fromOffset(18, 16), UDim2.fromOffset(5, 2), 15, Color3.fromRGB(150, 146, 140), Enum.TextXAlignment.Left)
	local count = text(slot, "", UDim2.fromOffset(28, 18), UDim2.new(1, -33, 0, 1), 18, Color3.new(1, 1, 1), Enum.TextXAlignment.Right)
	local icon = Instance.new("Frame")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(40, 32)
	icon.Position = UDim2.new(0.5, -20, 0, 14)
	icon.Parent = slot
	local name = text(slot, label, UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 1, -16), 12, Color3.fromRGB(215, 210, 200))
	return { frame = slot, stroke = stroke, number = number, count = count, icon = icon, name = name, id = id }
end

local function aimDirection()
	local camera = workspace.CurrentCamera
	local size = camera.ViewportSize
	return camera:ViewportPointToRay(size.X / 2, size.Y / 2).Direction
end

local function useItem(id)
	if id == "Medkit" then
		return -- lo gestiona MedkitHud (elige al compañero al que se mira)
	end
	if (player:GetAttribute("Item_" .. id) or 0) > 0 then
		Remotes.UseItem:FireServer(id, aimDirection())
	end
end

function Inventory.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Inventory"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	local total = 2 + #Config.Items.Order
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(1, 1)
	bar.Position = UDim2.new(1, -20, 1, -20)
	bar.Size = UDim2.fromOffset(total * SLOT + (total - 1) * GAP, SLOT)
	bar.BackgroundTransparency = 1
	bar.Parent = gui

	local slots = {}
	slots[1] = buildSlot(bar, 1, "Primary", "—")
	slots[2] = buildSlot(bar, 2, "Pistol", "PISTOLA")
	for i, id in Config.Items.Order do
		local cfg = Config.Items[id]
		local slot = buildSlot(bar, i + 2, id, string.upper(cfg.Name))
		ICONS[id](slot.icon)
		slots[i + 2] = slot
	end
	ICONS.Pistol(slots[2].icon)

	-- Se pulsa una ranura en celular; en PC, la tecla
	slots[1].frame.Activated:Connect(function()
		Remotes.Switch:FireServer("primary")
	end)
	slots[2].frame.Activated:Connect(function()
		Remotes.Switch:FireServer("pistol")
	end)
	for i = 3, #slots do
		local id = slots[i].id
		slots[i].frame.Activated:Connect(function()
			if id == "Medkit" then
				if (player:GetAttribute("Item_Medkit") or 0) > 0 then
					Remotes.UseMedkit:FireServer(nil)
				end
			else
				useItem(id)
			end
		end)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or player:GetAttribute("UiOpen") then
			return
		end
		for _, id in Config.Items.Order do
			if id ~= "Medkit" and input.KeyCode == Config.Items[id].Key then
				useItem(id)
			end
		end
	end)

	local drawnPrimary = nil
	RunService.RenderStepped:Connect(function()
		local weaponKey = player:GetAttribute("WeaponKey")
		local primaryKey = player:GetAttribute("PrimaryKey")
		if primaryKey ~= drawnPrimary then
			drawnPrimary = primaryKey
			slots[1].icon:ClearAllChildren()
			if primaryKey then
				ICONS.Rifle(slots[1].icon)
			end
			local weapon = primaryKey and Config.Weapons[primaryKey]
			slots[1].name.Text = weapon and string.upper(weapon.Name) or "—"
			slots[1].frame.BackgroundTransparency = primaryKey and 0.12 or 0.45
		end
		local primaryActive = weaponKey ~= nil and weaponKey ~= "Pistol"
		for i = 1, 2 do
			local active = (i == 1) == primaryActive
			slots[i].stroke.Color = active and GOLD or Color3.fromRGB(60, 60, 64)
			slots[i].number.TextColor3 = active and GOLD or Color3.fromRGB(150, 146, 140)
		end
		for i = 3, #slots do
			local n = player:GetAttribute("Item_" .. slots[i].id) or 0
			slots[i].count.Text = n > 0 and tostring(n) or "0"
			slots[i].count.TextColor3 = n > 0 and Color3.new(1, 1, 1) or Color3.fromRGB(120, 116, 112)
			slots[i].frame.BackgroundTransparency = n > 0 and 0.12 or 0.5
			slots[i].icon.Visible = n > 0
		end
	end)
end

return Inventory
