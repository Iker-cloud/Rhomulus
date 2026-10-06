-- Placas inclinadas (paralelogramos) hechas con franjas, y utilidades de texto para la señalética.
local TextService = game:GetService("TextService")

local Slant = {}

Slant.FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)

local STRIPS = 10

-- string.upper no cambia las letras con tilde: las pasamos a mano
local ACCENTS = { ["á"] = "Á", ["é"] = "É", ["í"] = "Í", ["ó"] = "Ó", ["ú"] = "Ú", ["ñ"] = "Ñ", ["ü"] = "Ü" }
function Slant.upper(text)
	local result = string.upper(text)
	for lower, upper in ACCENTS do
		result = result:gsub(lower, upper)
	end
	return result
end

-- Ancho en píxeles del texto (con un cálculo aproximado si aún no se puede medir)
function Slant.textWidth(text, size)
	local ok, bounds = pcall(function()
		local params = Instance.new("GetTextBoundsParams")
		params.Text = text
		params.Font = Slant.FONT
		params.Size = size
		params.Width = 1000
		return TextService:GetTextBoundsAsync(params)
	end)
	if ok then
		return bounds.X
	end
	return #text * size * 0.62
end

-- Dibuja (o redibuja) el paralelogramo dentro de `holder`. El borde superior se desplaza `slant` px a la derecha.
function Slant.fill(holder, width, height, slant, color)
	for _, child in holder:GetChildren() do
		if child:GetAttribute("SlantStrip") then
			child:Destroy()
		end
	end
	holder.Size = UDim2.fromOffset(width, height)

	local stripHeight = height / STRIPS
	for i = 0, STRIPS - 1 do
		local strip = Instance.new("Frame")
		strip:SetAttribute("SlantStrip", true)
		strip.Size = UDim2.fromOffset(width - slant, stripHeight + 1)
		strip.Position = UDim2.fromOffset(slant * (1 - i / (STRIPS - 1)), i * stripHeight)
		strip.BackgroundColor3 = color
		strip.BorderSizePixel = 0
		strip.Parent = holder
	end
end

return Slant
