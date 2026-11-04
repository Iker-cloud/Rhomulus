-- Estilo "expediente" compartido por los paneles del HUD: papel crema, tinta oscura, rojo tinta, máquina de escribir y títulos
-- Sarpanch (el mismo de client/HelpPanel). Los colores de dificultad se oscurecen con onPaper para leerse sobre el papel.
local PaperStyle = {}

PaperStyle.Ink = Color3.fromRGB(36, 30, 24)
PaperStyle.Soft = Color3.fromRGB(104, 92, 76) -- tinta suave
PaperStyle.Paper = Color3.fromRGB(228, 214, 178)
PaperStyle.PaperDark = Color3.fromRGB(212, 194, 156)
PaperStyle.Red = Color3.fromRGB(176, 48, 44)
PaperStyle.Green = Color3.fromRGB(58, 108, 62)
PaperStyle.Hilite = Color3.fromRGB(246, 196, 70)

PaperStyle.Typewriter = Font.fromEnum(Enum.Font.SpecialElite)
PaperStyle.Head = (function()
	local ok, font = pcall(function()
		return Font.new("rbxasset://fonts/families/Sarpanch.json", Enum.FontWeight.ExtraBold)
	end)
	return ok and font or Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
end)()

function PaperStyle.onPaper(color)
	return color:Lerp(PaperStyle.Ink, 0.42)
end

-- Pone al marco el aspecto de papel: color, degradado suave y borde de tinta
function PaperStyle.paper(frame, strokeThickness)
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	if frame:IsA("GuiLabel") then
		frame.BackgroundColor3 = PaperStyle.Paper -- un degradado teñiría también el texto
	else
		frame.BackgroundColor3 = Color3.new(1, 1, 1)
		local shade = Instance.new("UIGradient")
		shade.Color = ColorSequence.new(Color3.fromRGB(238, 226, 194), PaperStyle.PaperDark)
		shade.Rotation = 70
		shade.Parent = frame
	end
	local stroke = Instance.new("UIStroke")
	stroke.Color = PaperStyle.Ink
	stroke.Thickness = strokeThickness or 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border -- en una etiqueta, el borde del marco y no el contorno de las letras
	stroke.Parent = frame
	return stroke
end

return PaperStyle
