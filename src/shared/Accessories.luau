-- Accesorios del superviviente (caja Barrio): gorras, gafas, mochilas y parches. Son solo cosméticos. Cada uno es una lista de piezas
-- nativas (sin mallas subidas) dibujadas alrededor del origen de su ranura:
--   Head     origen en el centro de la cabeza (arriba = +Y)               -> se pega a Head
--   Face     origen en el centro de la cabeza, la cara mira a -Z           -> se pega a Head
--   Back     origen en el centro de UpperTorso, la espalda es +Z          -> se pega a UpperTorso
--   Shoulder origen en el centro del brazo derecho, el exterior es +X     -> se pega a RightUpperArm
-- Los ids se guardan en el DataStore: no cambiarlos. Rarity: Common, Rare, Epic o Legendary (Cosmetics.Rarities).
-- Una pieza es { forma, tamaño, posición, color, material, giro en grados (opcional), transparencia (opcional) }.
local Accessories = {}

local V = Vector3.new
local C = Color3.fromRGB
local PLASTIC, METAL, NEON, FABRIC = Enum.Material.SmoothPlastic, Enum.Material.Metal, Enum.Material.Neon, Enum.Material.Fabric

local function block(size, pos, color, material, rot, transparency)
	return { "Block", size, pos, color, material or PLASTIC, rot, transparency }
end
local function ball(size, pos, color, material, rot, transparency)
	return { "Ball", size, pos, color, material or PLASTIC, rot, transparency }
end
-- el cilindro de Roblox va a lo largo de X: `size` = (largo, diámetro, diámetro)
local function cyl(size, pos, color, material, rot, transparency)
	return { "Cylinder", size, pos, color, material or PLASTIC, rot, transparency }
end

-- Ranura -> pieza del personaje (R15) a la que se pega
Accessories.Hosts = { Head = "Head", Face = "Head", Back = "UpperTorso", Shoulder = "RightUpperArm" }
Accessories.Slots = { "Head", "Face", "Back", "Shoulder" }
Accessories.SlotNames = { Head = "HEAD", Face = "FACE", Back = "PACK", Shoulder = "SHOULDER" }

Accessories.Items = {
	-- Cabeza -------------------------------------------------------------------------------------------------------------------------
	{ Id = "CapRed", Name = "Red Cap", Slot = "Head", Rarity = "Common", Parts = {
		ball(V(1.32, 1.0, 1.32), V(0, 0.42, 0), C(190, 30, 36), FABRIC),
		block(V(1.0, 0.08, 0.6), V(0, 0.26, -0.78), C(150, 22, 28), FABRIC),
	} },
	{ Id = "BeanieGray", Name = "Gray Beanie", Slot = "Head", Rarity = "Common", Parts = {
		ball(V(1.3, 1.1, 1.3), V(0, 0.4, 0), C(120, 122, 128), FABRIC),
		block(V(1.3, 0.22, 1.3), V(0, 0.2, 0), C(86, 88, 94), FABRIC),
		ball(V(0.3, 0.3, 0.3), V(0, 0.98, 0), C(200, 200, 204), FABRIC),
	} },
	{ Id = "BandanaYellow", Name = "Yellow Headband", Slot = "Head", Rarity = "Common", Parts = {
		block(V(1.28, 0.24, 1.28), V(0, 0.4, 0), C(236, 188, 52), FABRIC),
		block(V(0.34, 0.26, 0.16), V(0, 0.4, 0.68), C(236, 188, 52), FABRIC),
		block(V(0.14, 0.5, 0.06), V(-0.12, 0.1, 0.74), C(236, 188, 52), FABRIC, V(0, 0, 14)),
		block(V(0.14, 0.5, 0.06), V(0.12, 0.1, 0.74), C(236, 188, 52), FABRIC, V(0, 0, -14)),
	} },
	{ Id = "HardHat", Name = "Hard Hat", Slot = "Head", Rarity = "Rare", Parts = {
		ball(V(1.34, 1.0, 1.34), V(0, 0.45, 0), C(248, 176, 24), PLASTIC),
		block(V(1.5, 0.07, 1.5), V(0, 0.2, 0), C(232, 160, 18), PLASTIC),
		block(V(0.16, 0.12, 1.1), V(0, 0.93, 0), C(232, 160, 18), PLASTIC),
	} },
	{ Id = "BikerHelmet", Name = "Biker Helmet", Slot = "Head", Rarity = "Epic", Parts = {
		ball(V(1.38, 1.2, 1.38), V(0, 0.28, 0), C(26, 26, 30), METAL),
		block(V(1.0, 0.32, 0.12), V(0, 0.2, -0.64), C(30, 40, 52), PLASTIC, nil, 0.25),
		block(V(0.14, 0.05, 1.2), V(0, 0.88, 0), C(200, 30, 36), PLASTIC),
	} },
	{ Id = "Crown", Name = "Chief's Crown", Slot = "Head", Rarity = "Legendary", Parts = {
		block(V(1.24, 0.34, 1.24), V(0, 0.72, 0), C(255, 200, 60), METAL),
		block(V(0.22, 0.36, 0.22), V(-0.5, 1.0, -0.5), C(255, 200, 60), METAL),
		block(V(0.22, 0.36, 0.22), V(0.5, 1.0, -0.5), C(255, 200, 60), METAL),
		block(V(0.22, 0.36, 0.22), V(-0.5, 1.0, 0.5), C(255, 200, 60), METAL),
		block(V(0.22, 0.36, 0.22), V(0.5, 1.0, 0.5), C(255, 200, 60), METAL),
		block(V(0.26, 0.5, 0.26), V(0, 1.06, -0.5), C(255, 200, 60), METAL),
		ball(V(0.2, 0.2, 0.2), V(0, 0.74, -0.64), C(220, 30, 40), NEON),
	} },

	-- Cara ---------------------------------------------------------------------------------------------------------------------------
	{ Id = "ShadesBlack", Name = "Black Shades", Slot = "Face", Rarity = "Common", Parts = {
		block(V(0.46, 0.28, 0.06), V(-0.3, 0.12, -0.62), C(16, 16, 20), PLASTIC),
		block(V(0.46, 0.28, 0.06), V(0.3, 0.12, -0.62), C(16, 16, 20), PLASTIC),
		block(V(0.22, 0.06, 0.06), V(0, 0.18, -0.62), C(16, 16, 20), PLASTIC),
		block(V(0.06, 0.06, 0.7), V(-0.56, 0.18, -0.28), C(16, 16, 20), PLASTIC),
		block(V(0.06, 0.06, 0.7), V(0.56, 0.18, -0.28), C(16, 16, 20), PLASTIC),
	} },
	{ Id = "AviatorGold", Name = "Gold Aviators", Slot = "Face", Rarity = "Rare", Parts = {
		ball(V(0.46, 0.42, 0.08), V(-0.3, 0.1, -0.63), C(120, 84, 24), METAL, nil, 0.1),
		ball(V(0.46, 0.42, 0.08), V(0.3, 0.1, -0.63), C(120, 84, 24), METAL, nil, 0.1),
		block(V(0.18, 0.05, 0.05), V(0, 0.2, -0.63), C(255, 200, 70), METAL),
		block(V(0.05, 0.05, 0.7), V(-0.56, 0.2, -0.28), C(255, 200, 70), METAL),
		block(V(0.05, 0.05, 0.7), V(0.56, 0.2, -0.28), C(255, 200, 70), METAL),
	} },
	{ Id = "MaskBandana", Name = "Red Face Wrap", Slot = "Face", Rarity = "Rare", Parts = {
		block(V(1.28, 0.55, 0.12), V(0, -0.28, -0.6), C(176, 28, 34), FABRIC),
		block(V(1.28, 0.55, 0.12), V(0, -0.28, 0.6), C(176, 28, 34), FABRIC),
		block(V(0.1, 0.55, 1.2), V(-0.64, -0.28, 0), C(176, 28, 34), FABRIC),
		block(V(0.1, 0.55, 1.2), V(0.64, -0.28, 0), C(176, 28, 34), FABRIC),
	} },
	{ Id = "GasMask", Name = "Gas Mask", Slot = "Face", Rarity = "Epic", Parts = {
		block(V(1.0, 0.7, 0.16), V(0, -0.02, -0.62), C(30, 32, 34), PLASTIC),
		ball(V(0.42, 0.42, 0.1), V(-0.28, 0.1, -0.7), C(20, 40, 36), PLASTIC, nil, 0.2),
		ball(V(0.42, 0.42, 0.1), V(0.28, 0.1, -0.7), C(20, 40, 36), PLASTIC, nil, 0.2),
		cyl(V(0.4, 0.42, 0.42), V(0, -0.2, -0.82), C(86, 90, 82), METAL, V(0, 90, 0)),
		cyl(V(0.05, 0.5, 0.5), V(0, -0.2, -1.04), C(44, 46, 44), METAL, V(0, 90, 0)),
	} },
	{ Id = "SkullMask", Name = "Skull Mask", Slot = "Face", Rarity = "Legendary", Parts = {
		block(V(1.1, 0.9, 0.14), V(0, 0.02, -0.64), C(232, 226, 208), PLASTIC),
		block(V(0.3, 0.3, 0.16), V(-0.27, 0.16, -0.64), C(18, 14, 14), PLASTIC),
		block(V(0.3, 0.3, 0.16), V(0.27, 0.16, -0.64), C(18, 14, 14), PLASTIC),
		ball(V(0.14, 0.14, 0.16), V(-0.27, 0.16, -0.7), C(255, 40, 30), NEON),
		ball(V(0.14, 0.14, 0.16), V(0.27, 0.16, -0.7), C(255, 40, 30), NEON),
		block(V(0.9, 0.06, 0.16), V(0, -0.3, -0.66), C(18, 14, 14), PLASTIC),
		block(V(0.08, 0.2, 0.16), V(-0.2, -0.3, -0.66), C(18, 14, 14), PLASTIC),
		block(V(0.08, 0.2, 0.16), V(0.2, -0.3, -0.66), C(18, 14, 14), PLASTIC),
	} },

	-- Espalda ------------------------------------------------------------------------------------------------------------------------
	{ Id = "PackSchool", Name = "School Backpack", Slot = "Back", Rarity = "Common", Parts = {
		block(V(1.4, 1.5, 0.6), V(0, 0.05, 0.8), C(46, 120, 74), FABRIC),
		block(V(1.0, 0.5, 0.2), V(0, -0.3, 1.18), C(34, 92, 56), FABRIC),
		block(V(0.12, 1.4, 0.1), V(-0.45, 0.05, 0.5), C(30, 30, 34), FABRIC),
		block(V(0.12, 1.4, 0.1), V(0.45, 0.05, 0.5), C(30, 30, 34), FABRIC),
	} },
	{ Id = "PackMilitary", Name = "Field Pack", Slot = "Back", Rarity = "Rare", Parts = {
		block(V(1.5, 1.7, 0.75), V(0, 0.1, 0.85), C(86, 96, 62), FABRIC),
		block(V(1.1, 0.6, 0.25), V(0, -0.35, 1.3), C(70, 80, 50), FABRIC),
		cyl(V(1.6, 0.45, 0.45), V(0, 1.1, 0.9), C(150, 126, 84), FABRIC),
		block(V(0.12, 1.5, 0.1), V(-0.5, 0.1, 0.5), C(40, 40, 38), FABRIC),
		block(V(0.12, 1.5, 0.1), V(0.5, 0.1, 0.5), C(40, 40, 38), FABRIC),
	} },
	{ Id = "PackRadio", Name = "Radio Pack", Slot = "Back", Rarity = "Epic", Parts = {
		block(V(1.2, 1.3, 0.55), V(0, 0, 0.78), C(44, 48, 50), METAL),
		block(V(0.8, 0.3, 0.12), V(0, 0.2, 1.1), C(20, 22, 24), PLASTIC),
		ball(V(0.14, 0.14, 0.12), V(-0.25, -0.2, 1.1), C(255, 60, 40), NEON),
		ball(V(0.14, 0.14, 0.12), V(0.25, -0.2, 1.1), C(60, 255, 120), NEON),
		cyl(V(2.0, 0.07, 0.07), V(0.45, 1.65, 0.8), C(150, 154, 160), METAL, V(0, 0, 90)),
		ball(V(0.16, 0.16, 0.16), V(0.45, 2.66, 0.8), C(255, 50, 40), NEON),
	} },
	{ Id = "WingsRust", Name = "Rusted Wings", Slot = "Back", Rarity = "Legendary", Parts = (function()
		local parts = { block(V(0.5, 0.9, 0.3), V(0, 0.2, 0.6), C(60, 54, 52), METAL) }
		for side = -1, 1, 2 do
			for i = 1, 4 do
				local len = 2.4 - (i - 1) * 0.35
				table.insert(parts, block(V(0.16, len, 0.34), V(side * (0.7 + i * 0.35), 0.6 + len / 2 - 0.9 - (i - 1) * 0.12, 0.9), i % 2 == 0 and C(150, 70, 30) or C(66, 62, 66), METAL, V(0, 0, side * (-18 - i * 8))))
			end
		end
		return parts
	end)() },

	-- Hombro -------------------------------------------------------------------------------------------------------------------------
	{ Id = "PatchCross", Name = "Medic Patch", Slot = "Shoulder", Rarity = "Common", Parts = {
		block(V(0.08, 0.55, 0.55), V(0.54, 0.2, 0), C(238, 238, 234), FABRIC),
		block(V(0.1, 0.4, 0.12), V(0.55, 0.2, 0), C(200, 30, 36), FABRIC),
		block(V(0.1, 0.12, 0.4), V(0.55, 0.2, 0), C(200, 30, 36), FABRIC),
	} },
	{ Id = "PatchSkull", Name = "Skull Patch", Slot = "Shoulder", Rarity = "Rare", Parts = {
		block(V(0.08, 0.6, 0.6), V(0.54, 0.2, 0), C(20, 20, 22), FABRIC),
		block(V(0.1, 0.3, 0.32), V(0.55, 0.26, 0), C(232, 226, 208), FABRIC),
		block(V(0.12, 0.1, 0.08), V(0.56, 0.3, -0.07), C(20, 20, 22), FABRIC),
		block(V(0.12, 0.1, 0.08), V(0.56, 0.3, 0.07), C(20, 20, 22), FABRIC),
		block(V(0.1, 0.06, 0.28), V(0.55, 0.06, 0), C(232, 226, 208), FABRIC),
	} },
	{ Id = "Epaulette", Name = "Officer Epaulette", Slot = "Shoulder", Rarity = "Epic", Parts = {
		block(V(1.2, 0.16, 1.1), V(0.1, 0.62, 0), C(30, 40, 84), FABRIC),
		block(V(1.2, 0.06, 0.12), V(0.1, 0.72, -0.5), C(255, 200, 60), METAL),
		block(V(1.2, 0.06, 0.12), V(0.1, 0.72, 0.5), C(255, 200, 60), METAL),
		block(V(0.12, 0.22, 1.1), V(0.7, 0.54, 0), C(255, 200, 60), METAL),
	} },
	{ Id = "ShoulderLamp", Name = "Shoulder Lamp", Slot = "Shoulder", Rarity = "Legendary", Parts = {
		block(V(0.4, 0.44, 0.5), V(0.5, 0.72, 0), C(44, 46, 50), METAL),
		cyl(V(0.12, 0.38, 0.38), V(0.5, 0.72, -0.31), C(255, 240, 180), NEON, V(0, 90, 0)),
		block(V(0.1, 0.1, 0.5), V(0.5, 0.54, 0), C(30, 30, 34), METAL),
	} },
}

local byId = {}
for _, item in Accessories.Items do
	byId[item.Id] = item
end

function Accessories.get(id)
	return byId[id]
end

-- Las que puede dar la caja Barrio (todas), opcionalmente de una rareza
function Accessories.pool(rarity)
	local list = {}
	for _, item in Accessories.Items do
		if not rarity or item.Rarity == rarity then
			table.insert(list, item)
		end
	end
	return list
end

-- Modelo del accesorio alrededor del origen (ancladas, para verlo suelto en un ViewportFrame). `unanchored` = true lo deja listo
-- para pegarse a un personaje.
function Accessories.build(id, unanchored)
	local item = byId[id]
	if not item then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Acc_" .. item.Slot
	model:SetAttribute("AccessoryId", id)
	for index, spec in item.Parts do
		-- (no table.unpack: las piezas sin giro dejan un hueco nil en la lista)
		local shape, size, pos, color, material, rot, transparency = spec[1], spec[2], spec[3], spec[4], spec[5], spec[6], spec[7]
		local part = Instance.new("Part")
		part.Name = "P" .. index
		part.Shape = Enum.PartType[shape]
		part.Size = size
		part.Color = color
		part.Material = material
		part.Transparency = transparency or 0
		part.Anchored = not unanchored
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Massless = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		local rotation = rot and CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z)) or CFrame.identity
		part.CFrame = CFrame.new(pos) * rotation
		part.Parent = model
	end
	model.WorldPivot = CFrame.identity
	return model
end

-- Pega el accesorio al personaje (R15). Devuelve el modelo, o nil si falta la pieza o el id no existe.
function Accessories.attach(character, id)
	local item = byId[id]
	local host = item and character:FindFirstChild(Accessories.Hosts[item.Slot])
	if not host then
		return nil
	end
	local model = Accessories.build(id, true)
	model:PivotTo(host.CFrame)
	for _, part in model:GetChildren() do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = host
		weld.Part1 = part
		weld.Parent = part
	end
	model.Parent = character
	return model
end

-- "Head:CapRed,Back:PackSchool" <-> { Head = "CapRed", Back = "PackSchool" }
function Accessories.encode(equipped)
	local list = {}
	for _, slot in Accessories.Slots do
		local id = equipped and equipped[slot]
		if id and byId[id] and byId[id].Slot == slot then
			table.insert(list, slot .. ":" .. id)
		end
	end
	return table.concat(list, ",")
end

function Accessories.decode(text)
	local out = {}
	if type(text) ~= "string" then
		return out
	end
	for pair in string.gmatch(text, "[^,]+") do
		local slot, id = string.match(pair, "^(%a+):(%w+)$")
		if slot and id and byId[id] and byId[id].Slot == slot then
			out[slot] = id
		end
	end
	return out
end

return Accessories
