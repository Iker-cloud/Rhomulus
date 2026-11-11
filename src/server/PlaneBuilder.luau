-- Remo One, el avión de rescate de Last Call: modelo avion-pasajeros.glb (ZombieData/RemoOne) con la escalerilla, la puerta
-- delantera izquierda en su articulación, los asientos de dentro y las luces. Es la variante de VanBuilder + VanInterior para el
-- avión; las medidas están en shared/PlaneLayout. El fuselaje va cerrado: quien sube queda dentro y su cámara pasa a seguir el
-- avión desde fuera (client/PlaneAnimator, que también lo trae aterrizando, mueve puerta y escalerilla y lo hace despegar).
-- El avión no es sólido (como la furgoneta): se sube manteniendo E al pie de la escalerilla (server/Boarding).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlaneLayout = require(ReplicatedStorage.Shared.PlaneLayout)
local PropModel = require(script.Parent.PropModel)
local RemoOne = require(script.Parent.ZombieData.RemoOne)

local PlaneBuilder = {}

local STEEL = Color3.fromRGB(150, 156, 164)
local DARK = Color3.fromRGB(26, 28, 32)
local WARM = Color3.fromRGB(255, 226, 170)

-- `stop` = CFrame del punto del suelo donde queda parado (el morro mira hacia su LookVector). El modelo nace ahí: el servidor no lo
-- mueve; cada cliente lo trae desde lejos y lo aterriza con los atributos To / Start / Duration que pone GameState.
function PlaneBuilder.make(stop)
	local _, yaw = stop:ToOrientation()
	local origin = CFrame.new(stop.Position) * CFrame.Angles(0, yaw, 0)
	local model, hitbox = PropModel.build(RemoOne, stop.Position, yaw)
	model.Name = "RemoOne"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- siempre en el cliente, aunque llegue desde muy lejos
	hitbox.CanCollide = false
	hitbox.CanQuery = false
	hitbox.Anchored = true
	hitbox.PivotOffset = hitbox.CFrame:Inverse() * origin -- el pivote es el punto del suelo, con el morro hacia adelante

	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part ~= hitbox then
			part.CanQuery = false -- las balas y la vista de los zombies lo atraviesan
			if string.find(part.Name, "Window_", 1, true) == 1 then
				part.Material = Enum.Material.Neon -- cabina encendida
				part.Color = WARM
			end
		end
	end

	local function at(x, y, z)
		return origin * CFrame.new(x, y, z)
	end
	-- Tras mover una pieza ya soldada: la soldadura vuelve a medir dónde quedó
	local function reweld(part)
		local weld = part:FindFirstChildOfClass("WeldConstraint")
		if weld then
			weld.Enabled = false
			weld.Enabled = true
		end
	end

	-- El morro del modelo llega como una caja (el conversor no sabe hacer conos): se cambia por un tramo de cilindro rematado en una
	-- esfera, y las ventanas de la cabina se asientan sobre esa esfera
	local nose = model:FindFirstChild("Fuselage_Nose")
	local body = model:FindFirstChild("Fuselage_Main")
	if nose and body then
		local diameter = body.Size.Y
		local local0 = origin:ToObjectSpace(nose.CFrame).Position
		local frontEdge = local0.Z + nose.Size.Z / 2 -- donde termina el fuselaje (z del modelo)
		local length = nose.Size.Z - diameter / 2
		nose.Shape = Enum.PartType.Cylinder
		nose.Size = Vector3.new(length, diameter, diameter)
		nose.CFrame = at(0, local0.Y, frontEdge - length / 2) * CFrame.Angles(0, math.pi / 2, 0)
		local tipCenter = at(0, local0.Y, frontEdge - length)
		local tip = nose:Clone()
		tip.Name = "Fuselage_NoseTip"
		tip.Shape = Enum.PartType.Ball
		tip.Size = Vector3.new(diameter, diameter, diameter)
		tip.CFrame = tipCenter
		tip.Parent = model
		reweld(nose)
		reweld(tip)
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") and string.find(part.Name, "Cockpit_Window", 1, true) then
				local direction = (part.Position - tipCenter.Position).Unit
				local spot = tipCenter.Position + direction * (diameter / 2 + 0.03)
				part.Size = Vector3.new(math.max(part.Size.X, part.Size.Z), part.Size.Y, 0.15)
				part.CFrame = CFrame.lookAt(spot, spot + direction)
				reweld(part)
			end
		end
	end
	local function piece(name, size, cframe, color, material, weldTo)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = cframe
		part.Color = color
		part.Material = material or Enum.Material.Metal
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = weldTo or hitbox
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
		return part
	end
	-- Ancla con articulación: lo que cuelga de ella lo mueve el cliente con Motor6D.Transform
	local function joint(name, cframe)
		local anchor = piece("J_" .. name, Vector3.new(0.3, 0.3, 0.3), cframe, DARK)
		anchor.Transparency = 1
		anchor:FindFirstChildOfClass("WeldConstraint"):Destroy()
		local motor = Instance.new("Motor6D")
		motor.Name = "mov_" .. name
		motor.Part0 = hitbox
		motor.Part1 = anchor
		motor.C0 = hitbox.CFrame:Inverse() * anchor.CFrame
		motor.C1 = CFrame.identity
		motor.Parent = anchor
		return anchor
	end

	local L = PlaneLayout
	-- Puerta delantera izquierda: cuelga de su articulación (se corre hacia el morro) y deja ver el hueco oscuro de la cabina
	local doorAnchor = joint("puerta_avion", at(L.DoorX, L.DoorY + 2.8, L.DoorZ))
	local door = model:FindFirstChild("Door_Front_Left")
	if door then
		door:FindFirstChildOfClass("WeldConstraint").Part0 = doorAnchor
		piece("PuertaHueco", Vector3.new(0.2, door.Size.Y, door.Size.X), at(L.DoorX + 0.14, door.Position.Y - stop.Position.Y, L.DoorZ), DARK, Enum.Material.SmoothPlastic)
	end

	-- Escalerilla: baja del umbral de la puerta hacia fuera (-X). Cuelga de una articulación en el umbral; el cliente la despliega.
	local stairAnchor = joint("escalerilla", at(L.DoorX - 0.5, L.DoorY, L.DoorZ))
	local stepRun, stepRise = L.StairRun / L.StairSteps, L.DoorY / L.StairSteps
	for i = 1, L.StairSteps do
		piece("Peldano", Vector3.new(stepRun + 0.15, 0.35, L.StairWidth), at(L.DoorX - 0.5 - (i - 0.5) * stepRun, L.DoorY - (i - 0.5) * stepRise, L.DoorZ), STEEL, Enum.Material.DiamondPlate, stairAnchor)
	end
	local slope = math.sqrt(L.StairRun ^ 2 + L.DoorY ^ 2)
	local angle = math.atan2(L.DoorY, L.StairRun)
	for _, side in { -1, 1 } do
		-- Larguero y pasamanos de cada lado, inclinados como la escalerilla
		local middle = at(L.DoorX - 0.5 - L.StairRun / 2, L.DoorY / 2, L.DoorZ + side * (L.StairWidth / 2 + 0.1))
		piece("EscalerillaLarguero", Vector3.new(slope, 0.5, 0.2), middle * CFrame.Angles(0, 0, angle) * CFrame.new(0, -0.3, 0), STEEL, Enum.Material.Metal, stairAnchor)
		piece("EscalerillaPasamanos", Vector3.new(slope, 0.18, 0.18), middle * CFrame.Angles(0, 0, angle) * CFrame.new(0, 3, 0), STEEL, Enum.Material.Metal, stairAnchor)
	end
	-- Al pie de la escalerilla: el prompt de subida (server/Boarding lo busca por este nombre: "la puerta izquierda")
	local foot = piece("J_puerta_izq", Vector3.new(0.3, 0.3, 0.3), at(L.DoorX - 0.5 - L.StairRun, 3, L.DoorZ), DARK)
	foot.Transparency = 1

	-- Asientos dentro del fuselaje (no se ven: el fuselaje va cerrado), mirando hacia el morro
	for _, def in L.Seats do
		local seat = piece(def.name, Vector3.new(1.6, 0.35, 1.4), at(def.x, L.Floor + 1.2, def.z), DARK, Enum.Material.Fabric)
		seat.Transparency = 1
	end

	-- Luces: navegación en las puntas de las alas (roja a la izquierda, verde a la derecha), baliza roja arriba y faro de aterrizaje
	local halfSpan = RemoOne.bounds.max.X - 0.8
	piece("luz_nav_izq", Vector3.new(0.9, 0.5, 0.9), at(-halfSpan, 10.4, 3), Color3.fromRGB(255, 50, 40), Enum.Material.Neon)
	piece("luz_nav_der", Vector3.new(0.9, 0.5, 0.9), at(halfSpan, 10.4, 3), Color3.fromRGB(60, 255, 90), Enum.Material.Neon)
	local beacon = piece("baliza_avion", Vector3.new(1, 0.6, 1), at(0, 16.2, -4), Color3.fromRGB(255, 50, 40), Enum.Material.Neon)
	local beaconLight = Instance.new("PointLight")
	beaconLight.Color = Color3.fromRGB(255, 60, 50)
	beaconLight.Brightness = 1.2
	beaconLight.Range = 22
	beaconLight.Parent = beacon
	local landing = piece("faro_aterrizaje", Vector3.new(1.2, 0.8, 0.4), at(0, 4.6, -46), WARM, Enum.Material.Neon)
	local beam = Instance.new("SpotLight")
	beam.Face = Enum.NormalId.Front -- el frente de la pieza mira hacia el morro (-Z)
	beam.Color = WARM
	beam.Brightness = 4
	beam.Range = 60
	beam.Angle = 70
	beam.Parent = landing

	model:SetAttribute("Rescue", "Plane")
	model:SetAttribute("DoorL", false)
	CollectionService:AddTag(model, "PlaneRig")
	return model
end

return PlaneBuilder
