-- El arma cuerpo a cuerpo en la mano. Cada skin es un modelo 3D de ZombieData (Melee<Id>, hecho con bloques desde un .glb); si falta, sale
-- un bloque de color con las medidas de la skin (Cosmetics.MeleeSkins).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local WeaponModel = require(script.Parent.WeaponModel)
local ZombieData = script.Parent.ZombieData

local MeleeModel = {}

-- Donde la mano sostiene cada modelo: altura del agarre (y, con la base del modelo en 0) y giro extra sobre el eje del arma (rad).
-- En el modelo la cabeza/filo va hacia +Y.
local GRIPS = {
	Knife = { y = 0.31, spin = 0 },
	Pan = { y = 0.3, spin = 0 },
	Bat = { y = 0.48, spin = 0 },
	Machete = { y = 0.3, spin = 0 },
	Axe = { y = 0.38, spin = 0 },
	Chainsaw = { y = 0.18, spin = 0 },
}

-- Devuelve el modelo de la skin y la altura del agarre respecto a su pieza raíz.
function MeleeModel.build(skinId)
	local skin = Cosmetics.melee(skinId) or Cosmetics.melee(Cosmetics.DefaultMelee)
	local module = ZombieData:FindFirstChild("Melee" .. skin.Id)
	local grip = GRIPS[skin.Id]
	if module and grip then
		local data = require(module)
		local model = WeaponModel.build(data, 1)
		model.Name = "MeleeWeapon"
		local centerY = (data.bounds.min.Y + data.bounds.max.Y) / 2
		return model, grip.y - centerY, grip.spin
	end
	local model = Instance.new("Model")
	model.Name = "MeleeWeapon"
	local blade = Instance.new("Part")
	blade.Name = "Root"
	blade.Size = Vector3.new(skin.Size.X, skin.Size.Z, skin.Size.Y) -- largo a lo largo de Y, como los modelos
	blade.Color = skin.Color
	blade.Material = Enum.Material.Metal
	blade.CanCollide = false
	blade.CanQuery = false
	blade.CanTouch = false
	blade.Massless = true
	blade.Parent = model
	model.PrimaryPart = blade
	return model, -skin.Size.Z / 2 + 0.45, 0
end

-- Pone el arma en la mano derecha y esconde el arma de fuego activa. Devuelve una función que lo deshace (o nil si no hay mano).
function MeleeModel.hold(player, skinId)
	local character = player.Character
	local hand = character and character:FindFirstChild("RightHand")
	if not hand then
		return nil
	end
	local model, gripOffset, spin = MeleeModel.build(skinId)
	local root = model.PrimaryPart
	model:SetAttribute("SkinId", skinId) -- client/MeleeFx pinta la estela según la skin
	-- la mano apunta a las puntas de los dedos por -Y: la cabeza del arma sale por ahí, con el agarre en la palma
	local palm = CFrame.new(0, -0.2, 0) * CFrame.Angles(math.pi, spin, 0)
	model:PivotTo(hand.CFrame * palm * CFrame.new(0, -gripOffset, 0))
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
		end
	end
	local motor = Instance.new("Motor6D")
	motor.Name = "MeleeGrip"
	motor.Part0 = hand
	motor.Part1 = root
	motor.C0 = palm
	motor.C1 = CFrame.new(0, gripOffset, 0)
	motor.Parent = root
	model.Parent = character

	local hidden = {}
	local weapon = character:FindFirstChild("HandWeapon")
	if weapon then
		for _, p in weapon:GetDescendants() do
			if p:IsA("BasePart") and p.Transparency < 1 and not p:FindFirstAncestor("MuzzleFlash") then
				hidden[p] = p.Transparency
				p.Transparency = 1
			end
		end
	end

	return function()
		model:Destroy()
		for p, transparency in hidden do
			if p.Parent then
				p.Transparency = transparency
			end
		end
	end
end

return MeleeModel
