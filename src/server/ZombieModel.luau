-- Construye un zombie con bloques nativos a partir de un módulo de ZombieData (generado desde un .glb).
-- Cada grupo (pierna, rodilla, torso, cabeza, mandíbula, brazos) es un ancla invisible con sus piezas soldadas,
-- y los anclas se unen con Motor6D en las articulaciones. El cliente los mueve (ZombieAnimator.luau).
local CollectionService = game:GetService("CollectionService")

local ZombieModel = {}

-- Con stats.ModelDetail = "light" se omiten estos detalles pequeños (menos piezas por zombie)
local LIGHT_SKIP = {
	"diente_", "dedo_", "jiron_", "espina_", "hueso_", "esternon", "grieta_",
	"una_", "vertebra_", "tendon_", "cuero_", "vena_",
}

local function skippedInLight(name)
	for _, prefix in LIGHT_SKIP do
		if name:sub(1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local function newPart(name, size, cframe)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- Devuelve (modelo, humanoide, raíz). `position` es el punto del suelo donde aparece.
function ZombieModel.build(data, stats, position)
	local model = Instance.new("Model")
	model.Name = "Zombie"

	-- Cadera: altura media de las dos piernas
	local hipY = 0
	local legCount = 0
	for _, joint in data.joints do
		if joint.name == "pierna_izq" or joint.name == "pierna_der" then
			hipY += joint.cf.Y
			legCount += 1
		end
	end
	hipY /= legCount

	local root = newPart("HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(0, hipY, 0))
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	root.Parent = model
	model.PrimaryPart = root

	-- Anclas de cada grupo
	local anchors = { [data.root.name] = root }
	for _, joint in data.joints do
		local anchor = newPart("J_" .. joint.name, Vector3.new(0.3, 0.3, 0.3), joint.cf)
		anchor.Transparency = 1
		anchor.CanQuery = false
		anchor.Parent = model
		anchors[joint.name] = anchor
	end

	-- Piezas soldadas a su ancla
	local light = stats.ModelDetail == "light"
	for _, piece in data.parts do
		if light and skippedInLight(piece.name) then
			continue
		end
		local part = newPart(piece.name == "craneo" and "Head" or piece.name, piece.size, piece.cf)
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

	-- Caja invisible que cubre torso, cabeza y piernas: el cuerpo son bloques sueltos con huecos y sin esta caja
	-- las balas se cuelan entre ellos (los brazos siguen siendo piezas reales)
	local low, high
	for _, piece in data.parts do
		local group = piece.group
		if group:sub(1, 6) ~= "brazo_" and group:sub(1, 10) ~= "antebrazo_" then
			local center, half = piece.cf.Position, piece.size / 2
			low = low and low:Min(center - half) or center - half
			high = high and high:Max(center + half) or center + half
		end
	end
	if low and high then
		local size = high - low
		local hitbox = newPart("Hitbox", Vector3.new(math.max(size.X, 2), size.Y, math.max(size.Z, 1.5)), CFrame.new((low + high) / 2))
		hitbox.Transparency = 1
		hitbox.CanQuery = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = hitbox
		weld.Parent = hitbox
		hitbox.Parent = model
	end

	-- Articulaciones: arrancan en la pose del modelo y se doblan con Transform
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

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = hipY - 1 -- la raíz mide 2 de alto: así los pies quedan en el suelo
	humanoid.MaxHealth = stats.Health
	humanoid.Health = stats.Health
	humanoid.WalkSpeed = stats.Speed
	humanoid.DisplayName = stats.DisplayName or "Zombie"
	-- El nombre y la barra de vida los dibuja el cliente (EnemyBars.luau)
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false -- el cadáver conserva las articulaciones: el cliente anima la caída (ZombieAnimator)
	humanoid.Parent = model

	model:SetAttribute("JointCount", #data.joints) -- el cliente espera a tenerlas todas antes de animar
	model:SetAttribute("Rig", data.rig) -- el cliente elige la animación según este nombre
	CollectionService:AddTag(model, "ZombieRig")

	model:PivotTo(CFrame.new(position + Vector3.new(0, hipY, 0)))
	return model, humanoid, root
end

return ZombieModel
