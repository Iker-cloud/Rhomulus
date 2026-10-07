-- Arma como objeto 3D (pistola, rifle de asalto, escopeta), construida con bloques a partir de un módulo de ZombieData.
-- Las piezas van soldadas a una pieza raíz invisible que está en el centro del arma, así el modelo gira sobre su centro.
-- El cañón apunta hacia -X y la empuñadura hacia abajo (-Y) en el marco del modelo.
local WeaponModel = {}

-- `scale` agranda o reduce todo el modelo (1 = tamaño natural para un personaje de 5 studs)
function WeaponModel.build(data, scale)
	scale = scale or 1
	local model = Instance.new("Model")
	model.Name = data.rig

	local center = (data.bounds.min + data.bounds.max) / 2 * scale
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.CFrame = CFrame.new(center)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Parent = model
	model.PrimaryPart = root

	for _, piece in data.parts do
		local part = Instance.new("Part")
		part.Name = piece.name
		part.Size = piece.size * scale
		local rotation = piece.cf - piece.cf.Position
		part.CFrame = CFrame.new(piece.cf.Position * scale) * rotation
		part.Color = piece.color
		part.Material = piece.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
		part.Anchored = false
		part.Massless = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false -- las balas no chocan con el arma de adorno
		part.CastShadow = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if piece.shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		elseif piece.shape == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		end

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end

	return model
end

return WeaponModel
