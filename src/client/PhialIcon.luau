-- Icono de la Phial (una jeringa dibujada con cuadros, inclinada, con el líquido del color del efecto): lo usan el panel PHIAL ROLL y la
-- ranura de la Phial guardada (client/PhialSlot).
local function box(parent, size, position, color, transparency)
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = position
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local PhialIcon = {}

-- Una jeringa dibujada con cuadros, inclinada, con el líquido del color del efecto
function PhialIcon.make(parent, color, size)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(size, size)
	holder.Rotation = -32
	holder.Parent = parent
	local function part(x, y, w, h, c, transparency)
		return box(holder, UDim2.fromScale(w, h), UDim2.fromScale(x, y), c, transparency)
	end
	local cream = Color3.fromRGB(226, 220, 206)
	part(0.18, 0.04, 0.44, 0.07, cream) -- el pulgar
	part(0.385, 0.11, 0.03, 0.16, cream) -- el vástago
	part(0.25, 0.27, 0.30, 0.05, cream) -- la aleta
	local barrel = part(0.30, 0.32, 0.20, 0.40, Color3.fromRGB(40, 44, 48), 0.25)
	local stroke = Instance.new("UIStroke")
	stroke.Color = cream
	stroke.Thickness = 2
	stroke.Parent = barrel
	part(0.315, 0.40, 0.17, 0.30, color) -- el líquido
	part(0.37, 0.72, 0.06, 0.05, cream) -- el cuello
	part(0.393, 0.77, 0.014, 0.17, Color3.fromRGB(200, 204, 210)) -- la aguja
	return holder
end

return PhialIcon
