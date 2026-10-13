-- Interior de la furgoneta de rescate. El modelo de origen (ZombieData/Furgoneta) trae la caja trasera como un bloque macizo; aquí se
-- vacía: se quita el bloque, se levantan las paredes con la abertura de la puerta lateral y las ventanas, se pone suelo, luz y
-- bancos con un Seat por jugador (los sobrevivientes se sientan ahí al subir; ver server/Boarding). Las dos puertas laterales
-- quedan colgadas de una articulación ("mov_puerta_der" / "mov_puerta_izq") para que el cliente las deslice (client/VanAnimator).
-- Medidas en shared/VanLayout. Todo se suelda al Hitbox del modelo.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VanLayout = require(ReplicatedStorage.Shared.VanLayout)

local VanInterior = {}

local BODY = Color3.fromRGB(200, 197, 188)
local INNER = Color3.fromRGB(86, 84, 80)
local FLOOR = Color3.fromRGB(58, 56, 54)
local SEAT = Color3.fromRGB(150, 56, 40)
local BENCH = Color3.fromRGB(70, 68, 66)

-- Piezas que cuelgan de cada puerta lateral (la puerta, su ventana, las rejas y la manilla)
local function doorPartNames(side)
	local tag = side > 0 and "der" or "izq"
	return { "puerta_lateral_" .. tag, "ventana_puerta_" .. tag, "reja_puerta_" .. tag .. "_0", "reja_puerta_" .. tag .. "_1", "reja_puerta_" .. tag .. "_2", "manilla_" .. tag }
end

-- `origin` = CFrame del punto del suelo donde se construyó el modelo; `scale` = Config.Game.VanScale
function VanInterior.build(model, hitbox, origin, scale)
	local S = scale
	local function at(x, y, z)
		return origin * CFrame.new(x * S, y * S, z * S)
	end

	local function block(name, size, cframe, color, material, transparency)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size * S
		part.CFrame = cframe
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.Transparency = transparency or 0
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Massless = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hitbox
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
		return part
	end

	-- La caja maciza se quita y se reemplaza por paredes, suelo y techo interior
	local solid = model:FindFirstChild("caja_trasera")
	if solid then
		solid:Destroy()
	end
	local W, T = VanLayout.HalfWidth, 0.12
	local top, bottom = 7.2, 1.68
	local function wall(label, z0, z1, y0, y1)
		for _, side in { 1, -1 } do
			block(
				`Pared_{label}_{side > 0 and "der" or "izq"}`,
				Vector3.new(T, y1 - y0, z1 - z0),
				at(side * (W - T / 2), (y0 + y1) / 2, (z0 + z1) / 2),
				BODY
			)
		end
	end
	wall("frente_puerta", -1.92, -1.62, bottom, top) -- tira junto a la cabina
	wall("umbral", -1.62, 0.42, bottom, 2.28) -- bajo la puerta lateral
	wall("medio", 0.42, 1.92, bottom, top)
	wall("bajo_ventana", 1.92, 4.8, bottom, 4.92)
	wall("sobre_ventana", 1.92, 4.8, 6.12, top)
	wall("fondo", 4.8, 7.68, bottom, top)
	block("Pared_cabina", Vector3.new(W * 2 - T * 2, top - VanLayout.Floor, T), at(0, (top + VanLayout.Floor) / 2, -1.86), BODY)
	block("Suelo", Vector3.new(W * 2 - T * 2, 0.06, 9.4), at(0, VanLayout.Floor + 0.01, 2.88), FLOOR)
	block("TechoInterior", Vector3.new(W * 2 - T * 2, 0.06, 9.4), at(0, top - 0.05, 2.88), INNER)

	-- Las ventanas de la caja pasan a ser cristal: desde fuera se ve a los que van sentados
	for _, name in { "ventana_caja_der", "ventana_caja_izq" } do
		local glass = model:FindFirstChild(name)
		if glass then
			glass.Color = Color3.fromRGB(120, 150, 165)
			glass.Material = Enum.Material.Glass
			glass.Transparency = 0.55
		end
	end

	-- Luz cálida del techo para que se vean por dentro
	local lamp = block("LuzInterior", Vector3.new(0.6, 0.1, 0.6), at(0, top - 0.12, 2.9), Color3.fromRGB(255, 232, 190), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 205, 140)
	light.Brightness = 1.6
	light.Range = 15 * S
	light.Parent = lamp

	-- Bancos y asientos (un Seat por jugador, mirando al centro de la caja)
	for _, side in { 1, -1 } do
		block(
			"Banco_" .. (side > 0 and "der" or "izq"),
			Vector3.new(1.3, VanLayout.BenchHeight - 0.35, 6.4),
			at(side * VanLayout.SeatX, VanLayout.Floor + (VanLayout.BenchHeight - 0.35) / 2, 3.55),
			BENCH
		)
	end
	for _, def in VanLayout.Seats do
		local position = at(def.side * VanLayout.SeatX, VanLayout.Floor + VanLayout.BenchHeight - 0.175, def.z)
		local seat = Instance.new("Seat")
		seat.Name = def.name
		seat.Size = Vector3.new(1.5, 0.35, 1.1) * S -- ancho a lo largo de la caja, fondo hacia el centro (el frente del asiento es -Z)
		seat.CFrame = CFrame.lookAt(position.Position, position.Position + Vector3.new(-def.side, 0, 0))
		seat.Color = SEAT
		seat.Material = Enum.Material.Fabric
		seat.CanCollide = false
		seat.CanQuery = false
		seat.CanTouch = false
		seat.CastShadow = false
		seat.Massless = true
		seat.TopSurface = Enum.SurfaceType.Smooth
		seat.BottomSurface = Enum.SurfaceType.Smooth
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hitbox
		weld.Part1 = seat
		weld.Parent = seat
		seat.Parent = model
	end

	-- Puertas laterales: cada una cuelga de su anclaje (con una articulación que anima el cliente) y lleva el prompt de subida
	for _, side in { 1, -1 } do
		local tag = side > 0 and "der" or "izq"
		local anchor = Instance.new("Part")
		anchor.Name = "J_puerta_" .. tag
		anchor.Size = Vector3.new(0.3, 0.3, 0.3)
		anchor.CFrame = at(side * (W + 0.05), VanLayout.DoorY, VanLayout.DoorZ)
		anchor.Transparency = 1
		anchor.CanCollide = false
		anchor.CanTouch = false
		anchor.CanQuery = false
		anchor.Massless = true
		anchor.Parent = model
		local motor = Instance.new("Motor6D")
		motor.Name = "mov_puerta_" .. tag
		motor.Part0 = hitbox
		motor.Part1 = anchor
		motor.C0 = hitbox.CFrame:Inverse() * anchor.CFrame
		motor.C1 = CFrame.identity
		motor.Parent = anchor
		for _, name in doorPartNames(side) do
			local piece = model:FindFirstChild(name)
			local weld = piece and piece:FindFirstChildOfClass("WeldConstraint")
			if weld then
				weld.Part0 = anchor
			end
		end
	end
end

return VanInterior
