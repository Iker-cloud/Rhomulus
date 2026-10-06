-- Construye objetos fijos con tapa (caja de munición, caja misteriosa) a partir de un módulo de ZombieData.
-- Una pieza invisible del tamaño del cuerpo ("Hitbox") hace de colisión, de ancla y de lugar para el prompt y la placa.
-- La tapa es una articulación (Motor6D "tapa"); el cliente la abre o la cierra según el atributo Open del modelo (PropAnimator).
local CollectionService = game:GetService("CollectionService")

local PropModel = {}

local function newPart(name, size, cframe)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- `position` es el punto del suelo y `yaw` el giro en radianes (el frente del modelo mira hacia -Z).
-- Devuelve (modelo, hitbox).
function PropModel.build(data, position, yaw)
	local origin = CFrame.new(position) * CFrame.Angles(0, yaw or 0, 0)
	local model = Instance.new("Model")
	model.Name = data.rig

	-- Hitbox: el cuerpo completo, invisible, con colisión
	local size = data.bounds.max - data.bounds.min
	local center = (data.bounds.max + data.bounds.min) / 2
	local hitbox = newPart("Hitbox", size, origin * CFrame.new(center))
	hitbox.Transparency = 1
	hitbox.Anchored = true
	hitbox.CanCollide = true
	hitbox.Massless = false
	hitbox.Parent = model
	model.PrimaryPart = hitbox

	local anchors = { [data.root.name] = hitbox }
	for _, joint in data.joints do
		local anchor = newPart("J_" .. joint.name, Vector3.new(0.3, 0.3, 0.3), origin * joint.cf)
		anchor.Transparency = 1
		anchor.CanQuery = false
		anchor.Parent = model
		anchors[joint.name] = anchor
	end

	for _, piece in data.parts do
		local part = newPart(piece.name, piece.size, origin * piece.cf)
		part.Color = piece.color
		part.Material = piece.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
		if piece.shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		elseif piece.shape == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		end

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = anchors[piece.group]
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end

	for _, joint in data.joints do
		local parentAnchor = anchors[joint.parent]
		local childAnchor = anchors[joint.name]
		local motor = Instance.new("Motor6D")
		motor.Name = joint.name
		motor.Part0 = parentAnchor
		motor.Part1 = childAnchor
		motor.C0 = parentAnchor.CFrame:Inverse() * childAnchor.CFrame
		motor.C1 = CFrame.identity
		motor.Parent = childAnchor
	end

	model:SetAttribute("JointCount", #data.joints)
	model:SetAttribute("Rig", data.rig)
	for _, joint in data.joints do
		if joint.name == "tapa" then
			model:SetAttribute("Open", false)
			CollectionService:AddTag(model, "PropRig") -- el cliente abre y cierra la tapa
			break
		end
	end
	return model, hitbox
end

return PropModel
