-- Íconos dibujados con cuadros (no hay imágenes): calavera, cinta de peligro y hexágono con estrella.
local Icons = {}

local BONE = Color3.fromRGB(235, 228, 210)
local DARK = Color3.fromRGB(16, 16, 18)

local function rect(parent, size, position, color, rotation, anchor)
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = anchor or Vector2.zero
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Rotation = rotation or 0
	frame.Parent = parent
	return frame
end

-- Calavera con dos huesos cruzados, centrada en `parent`. k = tamaño (1 = el que cabe en un círculo de 32 px).
function Icons.skull(parent, k)
	k = k or 1
	for _, angle in { 35, -35 } do
		local bone = rect(parent, UDim2.fromOffset(20 * k, 3 * k), UDim2.new(0.5, -10 * k, 0.5, 5 * k), BONE, angle)
		bone.ZIndex = 2
		Instance.new("UICorner", bone).CornerRadius = UDim.new(1, 0)
	end
	local skull = rect(parent, UDim2.fromOffset(13 * k, 11 * k), UDim2.new(0.5, -6.5 * k, 0.5, -10 * k), BONE)
	skull.ZIndex = 3
	Instance.new("UICorner", skull).CornerRadius = UDim.new(0.45, 0)
	local jaw = rect(parent, UDim2.fromOffset(8 * k, 5 * k), UDim2.new(0.5, -4 * k, 0.5, -1 * k), BONE)
	jaw.ZIndex = 3
	for _, x in { -4.5, 1.5 } do
		local eye = rect(parent, UDim2.fromOffset(3 * k, 4 * k), UDim2.new(0.5, x * k, 0.5, -7 * k), DARK)
		eye.ZIndex = 4
		Instance.new("UICorner", eye).CornerRadius = UDim.new(0.4, 0)
	end
end

-- Cinta de franjas diagonales (máx. 20 puntos por degradado: 9 franjas)
function Icons.tape(parent, size, position, colorA, colorB)
	local tape = rect(parent, size, position, colorA)
	local stripes = {}
	local count = 9
	for i = 0, count - 1 do
		local color = i % 2 == 0 and colorA or colorB
		table.insert(stripes, ColorSequenceKeypoint.new(i / count, color))
		table.insert(stripes, ColorSequenceKeypoint.new(i == count - 1 and 1 or (i + 1) / count - 0.0001, color))
	end
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(stripes)
	gradient.Rotation = 20
	gradient.Parent = tape
	return tape
end

-- Hexágono (contorno) con una estrella de ocho puntas, centrado en `parent`. radius en píxeles.
function Icons.hexStar(parent, radius, color)
	local vertices = {}
	for k = 0, 5 do
		local angle = math.rad(-90 + 60 * k)
		table.insert(vertices, Vector2.new(math.cos(angle) * radius, math.sin(angle) * radius))
	end
	for k = 1, 6 do
		local a = vertices[k]
		local b = vertices[k % 6 + 1]
		local mid = (a + b) / 2
		local segment = rect(
			parent,
			UDim2.fromOffset(radius + 3, 3),
			UDim2.new(0.5, mid.X, 0.5, mid.Y),
			color,
			math.deg(math.atan2(b.Y - a.Y, b.X - a.X)),
			Vector2.new(0.5, 0.5)
		)
		segment.ZIndex = 2
	end
	local size = radius * 0.62
	for _, rotation in { 0, 45 } do
		local square = rect(parent, UDim2.fromOffset(size, size), UDim2.fromScale(0.5, 0.5), color, rotation, Vector2.new(0.5, 0.5))
		square.ZIndex = 3
	end
end

return Icons
