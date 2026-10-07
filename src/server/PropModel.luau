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

-- Copia del módulo de datos con todo multiplicado por `k` (posiciones y tamaños)
local function scaleCFrame(cf, k)
	return CFrame.new(cf.Position * k) * (cf - cf.Position)
end

local function scaleData(data, k)
	local copy = table.clone(data)
	copy.bounds = { min = data.bounds.min * k, max = data.bounds.max * k }
	copy.root = table.clone(data.root)
	copy.root.cf = scaleCFrame(data.root.cf, k)
	copy.joints = {}
	for i, joint in data.joints do
		local j = table.clone(joint)
		j.cf = scaleCFrame(joint.cf, k)
		copy.joints[i] = j
	end
	copy.parts = {}
	for i, piece in data.parts do
		local p = table.clone(piece)
		p.size = piece.size * k
		p.cf = scaleCFrame(piece.cf, k)
		copy.parts[i] = p
	end
	return copy
end

-- Piezas que giran con la rueda: "rueda_<id>", "llanta_<id>" y "buje_<id>" comparten articulación "rueda_<id>"
local WHEEL_PREFIXES = { "rueda_", "llanta_", "buje_" }

local function wheelId(pieceName)
	for _, prefix in WHEEL_PREFIXES do
		if pieceName:sub(1, #prefix) == prefix then
			return pieceName:sub(#prefix + 1)
		end
	end
end

-- `position` es el punto del suelo y `yaw` el giro en radianes (el frente del modelo mira hacia -Z).
-- `options.scale`: tamaño relativo (1 = el del modelo). Con `options.wheels = true`, cada rueda del modelo (piezas "rueda_*", "llanta_*", "buje_*") queda en su propia
-- articulación para que el cliente la haga girar. Devuelve (modelo, hitbox).
function PropModel.build(data, position, yaw, options)
	local scale = options and options.scale or 1 -- options.scale agranda todo el modelo
	if scale ~= 1 then
		data = scaleData(data, scale)
	end
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

	local extraJoints = 0
	if options and options.wheels then
		for _, piece in data.parts do
			if piece.name:sub(1, 6) == "rueda_" then
				local anchor = newPart("J_" .. piece.name, Vector3.new(0.3, 0.3, 0.3), origin * CFrame.new(piece.cf.Position))
				anchor.Transparency = 1
				anchor.CanQuery = false
				anchor.Parent = model
				anchors[piece.name] = anchor
				extraJoints += 1
			end
		end
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
		local id = options and options.wheels and wheelId(piece.name)
		weld.Part0 = id and anchors["rueda_" .. id] or anchors[piece.group]
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

	-- Ruedas: articulación "rueda_<id>" del cuerpo a su ancla, con el eje de giro en X (lateral)
	for name, anchor in anchors do
		if name:sub(1, 6) == "rueda_" then
			local motor = Instance.new("Motor6D")
			motor.Name = name
			motor.Part0 = hitbox
			motor.Part1 = anchor
			motor.C0 = hitbox.CFrame:Inverse() * anchor.CFrame
			motor.C1 = CFrame.identity
			motor.Parent = anchor
		end
	end

	model:SetAttribute("JointCount", #data.joints + extraJoints)
	model:SetAttribute("Rig", data.rig)
	model:SetAttribute("Scale", scale)
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
