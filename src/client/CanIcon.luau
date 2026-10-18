-- Icono de las latas: una lata gris con una franja roja (el de la moneda del juego), dibujado con cuadros. Lo usan el contador de latas y
-- el panel PHIAL ROLL.
local CanIcon = {}

local function box(parent, size, position, color)
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = position
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

-- `size` = alto de la lata en píxeles; se centra en `parent`
function CanIcon.make(parent, size)
	local width = size * 0.62
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(width, size)
	holder.Parent = parent

	local body = box(holder, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.fromRGB(214, 210, 200))
	Instance.new("UICorner", body).CornerRadius = UDim.new(0.22, 0)
	local shade = Instance.new("UIGradient")
	shade.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(176, 172, 162)),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(248, 246, 238)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 146, 138)),
	})
	shade.Parent = body
	-- Tapa de arriba y de abajo
	box(holder, UDim2.fromScale(0.86, 0.05), UDim2.fromScale(0.07, 0.07), Color3.fromRGB(120, 116, 108))
	box(holder, UDim2.fromScale(0.86, 0.05), UDim2.fromScale(0.07, 0.88), Color3.fromRGB(120, 116, 108))
	-- La franja roja
	local band = box(holder, UDim2.fromScale(1, 0.26), UDim2.fromScale(0, 0.37), Color3.fromRGB(200, 28, 30))
	local bandShade = Instance.new("UIGradient")
	bandShade.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(160, 20, 22)),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(230, 44, 44)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 18, 20)),
	})
	bandShade.Parent = band
	return holder
end

return CanIcon
