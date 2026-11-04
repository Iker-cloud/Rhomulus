-- Objetos en la mano (cliente). Se saca un objeto con su tecla (3 a 7, Config.Items.<id>.Key; la misma tecla, o 1 / 2 / Q, lo guarda):
--   granada, molotov, bengala: se mantiene el clic para cargar la fuerza (aparece el arco de la trayectoria y una barra) y al soltarlo se
--     lanza; el clic derecho cancela la carga.
--   vendas: un clic y se venda. Botiquín: un clic y cura al compañero que se mira (o a uno mismo).
-- El servidor decide todo (server/Items, server/Medkits): aquí solo se detectan las teclas, se dibuja el arco y se muestra la ayuda.
-- El arco usa la misma física que el lanzamiento real: velocidad = dirección * (ThrowMin..ThrowSpeed según la fuerza) + Loft hacia arriba.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MedkitHud = require(script.Parent.MedkitHud)
local Controls = require(script.Parent.Controls)

local player = Players.LocalPlayer
local I = Config.Items
local GOLD = Color3.fromRGB(246, 196, 70)
local DARK = Color3.fromRGB(14, 13, 13)
local OSWALD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)

local DOTS = 36
local STEP = 0.045 -- segundos de cada tramo del arco
local HINTS = {
	Grenade = "HOLD CLICK to charge power · RELEASE to throw · RIGHT CLICK cancels",
	Molotov = "HOLD CLICK to charge power · RELEASE to throw · RIGHT CLICK cancels",
	Flare = "HOLD CLICK to charge the shot · RELEASE to fire the flare · RIGHT CLICK cancels",
	Bandage = "CLICK to bandage yourself (+%d health)",
	Medkit = "CLICK to heal yourself, or the teammate you're looking at",
}
-- En celular el botón de disparo hace de clic
local TOUCH_HINTS = {
	Grenade = "HOLD the button to charge power · RELEASE to throw",
	Molotov = "HOLD the button to charge power · RELEASE to throw",
	Flare = "HOLD the button to charge the shot · RELEASE to fire",
	Bandage = "TAP the button to bandage yourself (+%d health)",
	Medkit = "TAP the button to heal yourself or the teammate you're looking at",
}

local ItemUse = {}

local charging = false
local localChargeStart = 0
local preview = nil -- { folder, dots, ring }
local ui = nil

local function character()
	return player.Character
end

local function aimDirection()
	local camera = workspace.CurrentCamera
	local size = camera.ViewportSize
	return camera:ViewportPointToRay(size.X / 2, size.Y / 2).Direction
end

local function count(id)
	return player:GetAttribute("Item_" .. id) or 0
end

-- Saca o guarda el objeto `id` (Inventory lo llama con la tecla o al tocar la ranura)
function ItemUse.toggle(id)
	if player:GetAttribute("UiOpen") then
		return
	end
	if player:GetAttribute("ItemReady") == id then
		Remotes.ReadyItem:FireServer(nil)
	elseif count(id) > 0 then
		Remotes.ReadyItem:FireServer(id)
	end
end

local function buildPreview()
	local folder = Instance.new("Folder")
	folder.Name = "ThrowPreview"
	folder.Parent = workspace.CurrentCamera
	local dots = {}
	for i = 1, DOTS do
		local dot = Instance.new("Part")
		dot.Shape = Enum.PartType.Ball
		dot.Size = Vector3.one * 0.32
		dot.Anchored = true
		dot.CanCollide = false
		dot.CanQuery = false
		dot.CanTouch = false
		dot.CastShadow = false
		dot.Material = Enum.Material.Neon
		dot.Color = Color3.new(1, 1, 1)
		dot.Transparency = 1
		dot.Parent = folder
		dots[i] = dot
	end
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.12, 4, 4)
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Transparency = 1
	ring.Parent = folder
	return { folder = folder, dots = dots, ring = ring }
end

local function hidePreview()
	if not preview then
		return
	end
	for _, dot in preview.dots do
		dot.Transparency = 1
	end
	preview.ring.Transparency = 1
end

-- Puntos del arco del lanzamiento y dónde choca (nil si no choca en el tiempo simulado)
local function simulate(id, power, direction)
	local char = character()
	local head = char and char:FindFirstChild("Head")
	if not head then
		return nil
	end
	local cfg = I[id]
	local speed = cfg.ThrowMin + (cfg.ThrowSpeed - cfg.ThrowMin) * power
	local position = head.Position + direction * 2.5
	local velocity = direction * speed + Vector3.new(0, I.Loft, 0)
	local gravity = Vector3.new(0, -workspace.Gravity, 0)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignored = { char, workspace.CurrentCamera }
	for _, name in { "Projectiles", "Flares" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(ignored, folder)
		end
	end
	params.FilterDescendantsInstances = ignored

	local points = { position }
	local hit = nil
	for _ = 1, DOTS - 1 do
		local nextPosition = position + velocity * STEP + 0.5 * gravity * STEP * STEP
		local result = workspace:Raycast(position, nextPosition - position, params)
		if result then
			hit = result
			table.insert(points, result.Position)
			break
		end
		table.insert(points, nextPosition)
		velocity += gravity * STEP
		position = nextPosition
	end
	return points, hit
end

local function drawPreview(id, power)
	preview = preview or buildPreview()
	local points, hit = simulate(id, power, aimDirection())
	if not points then
		hidePreview()
		return
	end
	local cfg = I[id]
	local count_ = #points
	for i, dot in preview.dots do
		if i <= count_ and i > 1 then
			dot.Position = points[i]
			dot.Color = Color3.new(1, 1, 1):Lerp(cfg.Color, power * 0.8)
			dot.Size = Vector3.one * (0.3 + 0.08 * math.sin(os.clock() * 8 - i * 0.7))
			dot.Transparency = 0.15 + 0.6 * (i / DOTS)
		else
			dot.Transparency = 1
		end
	end
	local ring = preview.ring
	if hit then
		local radius = id == "Flare" and 3 or cfg.Radius -- el radio de la explosión o del fuego
		ring.Size = Vector3.new(0.12, radius * 2, radius * 2)
		-- el cilindro mira por X: se gira para que el disco quede sobre la superficie
		local normal = hit.Normal
		ring.CFrame = CFrame.lookAt(hit.Position + normal * 0.08, hit.Position + normal) * CFrame.Angles(0, math.pi / 2, 0)
		ring.Color = cfg.Color
		ring.Transparency = 0.82 - 0.15 * math.sin(os.clock() * 6)
	else
		ring.Transparency = 1
	end
end

local function pill(parent, size, position)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0)
	f.Size = size
	f.Position = position
	f.BackgroundColor3 = DARK
	f.BackgroundTransparency = 0.25
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function buildUi()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ItemUse"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 4
	gui.Parent = player:WaitForChild("PlayerGui")

	local hint = pill(gui, UDim2.fromOffset(560, 28), UDim2.new(0.5, 0, 1, -122))
	hint.Visible = false
	local hintText = Instance.new("TextLabel")
	hintText.BackgroundTransparency = 1
	hintText.Size = UDim2.fromScale(1, 1)
	hintText.FontFace = OSWALD
	hintText.TextSize = 16
	hintText.TextColor3 = Color3.fromRGB(235, 230, 220)
	hintText.Parent = hint

	local bar = pill(gui, UDim2.fromOffset(190, 24), UDim2.new(0.5, 0, 0.5, 64))
	bar.Visible = false
	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(6, 15)
	back.Size = UDim2.new(1, -12, 0, 5)
	back.BackgroundColor3 = Color3.fromRGB(62, 58, 56)
	back.BorderSizePixel = 0
	back.Parent = bar
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = GOLD
	fill.BorderSizePixel = 0
	fill.Parent = back
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(8, 0)
	title.Size = UDim2.new(1, -16, 0, 15)
	title.FontFace = OSWALD
	title.TextSize = 13
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = "POWER"
	title.Parent = bar
	return { hint = hint, hintText = hintText, bar = bar, fill = fill, title = title }
end

local function stopCharging(send)
	if charging and send then
		Remotes.ChargeItem:FireServer(false)
	end
	charging = false
end

-- Clic principal con un objeto en la mano (clic del ratón o botón de disparo del celular). Devuelve si había objeto.
function ItemUse.press()
	local id = player:GetAttribute("ItemReady")
	if not id or player:GetAttribute("UiOpen") then
		return false
	end
	local char = character()
	if char and char:GetAttribute("ItemId") then
		return true -- todavía hace el gesto del anterior
	end
	if I[id].Throwable then
		charging = true
		localChargeStart = workspace:GetServerTimeNow()
		Remotes.ChargeItem:FireServer(true)
	elseif id == "Bandage" then
		Remotes.UseItem:FireServer("Bandage")
	elseif id == "Medkit" then
		Remotes.UseMedkit:FireServer(MedkitHud.pickTarget())
	end
	return true
end

-- Se suelta el clic: lanza lo que se estaba cargando
function ItemUse.release()
	if charging then
		charging = false
		local id = player:GetAttribute("ItemReady")
		if id then
			Remotes.UseItem:FireServer(id, aimDirection())
		end
	end
end

-- Cancela la carga (clic derecho o botón de cancelar)
function ItemUse.cancel()
	if charging then
		stopCharging(true)
	end
end

function ItemUse.isCharging()
	return charging
end

function ItemUse.start()
	ui = buildUi()

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or player:GetAttribute("UiOpen") then
			return
		end
		local id = player:GetAttribute("ItemReady")
		if input.UserInputType == Enum.UserInputType.MouseButton1 and id then
			ItemUse.press()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 and charging then
			ItemUse.cancel()
		else
			-- La tecla de cada objeto lo saca o lo guarda
			for _, itemId in I.Order do
				if input.KeyCode == I[itemId].Key then
					ItemUse.toggle(itemId)
				end
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			ItemUse.release()
		end
	end)

	RunService.RenderStepped:Connect(function()
		local id = player:GetAttribute("ItemReady")
		if not id then
			charging = false
		end
		local char = character()
		local busy = char and char:GetAttribute("ItemId") ~= nil
		if charging and busy then
			charging = false
		end

		-- Arco y barra de fuerza mientras se carga
		if charging and id then
			local start = (char and char:GetAttribute("ItemCharge")) or localChargeStart
			local power = math.clamp((workspace:GetServerTimeNow() - start) / I.Charge.Time, 0, 1)
			drawPreview(id, power)
			ui.bar.Visible = true
			ui.fill.Size = UDim2.fromScale(power, 1)
			ui.fill.BackgroundColor3 = GOLD:Lerp(Color3.fromRGB(226, 66, 54), power)
			ui.title.Text = power >= 1 and "POWER · MAX" or "POWER"
		else
			ui.bar.Visible = false
			hidePreview()
		end

		-- Ayuda del objeto en la mano
		local healing = player:GetAttribute("HealingEnd") ~= nil
		if id and HINTS[id] and not busy and not healing then
			local text = (Controls.isTouch() and TOUCH_HINTS or HINTS)[id]
			if id == "Bandage" then
				text = string.format(text, I.Bandage.Heal)
			end
			ui.hintText.Text = Controls.isTouch() and text or (text .. `  ·  [{I[id].KeyLabel}] put away`)
			-- en celular el cartel es más estrecho (a los lados están los botones) y sube sobre el inventario
			local touch = Controls.isTouch()
			ui.hint.Position = touch and UDim2.new(0.5, 0, 1, -158) or UDim2.new(0.5, 0, 1, -122)
			ui.hint.Size = touch and UDim2.new(0.42, 0, 0, 40) or UDim2.fromOffset(560, 28)
			ui.hintText.TextSize = touch and 13 or 16
			ui.hintText.TextWrapped = touch
			ui.hint.Visible = not charging
		else
			ui.hint.Visible = false
		end
	end)
end

return ItemUse
