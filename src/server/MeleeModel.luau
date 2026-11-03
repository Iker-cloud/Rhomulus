-- El arma cuerpo a cuerpo en la mano. De MOMENTO es un bloque de color por skin (Cosmetics.MeleeSkins: Color y Size): cuando existan los
-- modelos 3D de cada arma se arman aquí (`build`) y el resto del juego no cambia.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)

local MeleeModel = {}

-- El modelo de la skin. Su PrimaryPart es el agarre (la mano lo sostiene por ahí); el filo/cabeza sale por +Z.
function MeleeModel.build(skinId)
	local skin = Cosmetics.melee(skinId) or Cosmetics.melee(Cosmetics.DefaultMelee)
	local model = Instance.new("Model")
	model.Name = "MeleeWeapon"
	local blade = Instance.new("Part")
	blade.Name = "Blade"
	blade.Size = skin.Size
	blade.Color = skin.Color
	blade.Material = Enum.Material.Metal
	blade.CanCollide = false
	blade.CanQuery = false
	blade.CanTouch = false
	blade.Massless = true
	blade.Parent = model
	model.PrimaryPart = blade
	return model
end

-- Pone el arma en la mano derecha y esconde el arma de fuego activa. Devuelve una función que lo deshace (o nil si no hay mano).
function MeleeModel.hold(player, skinId)
	local character = player.Character
	local hand = character and character:FindFirstChild("RightHand")
	if not hand then
		return nil
	end
	local model = MeleeModel.build(skinId)
	local blade = model.PrimaryPart
	-- la mano apunta a las puntas de los dedos por -Y: el arma sale por ahí, con el agarre dentro de la palma
	local c0 = CFrame.new(0, -0.35 - blade.Size.Z / 2 + 0.45, 0) * CFrame.Angles(math.rad(90), 0, 0)
	model:PivotTo(hand.CFrame * c0)
	local motor = Instance.new("Motor6D")
	motor.Name = "MeleeGrip"
	motor.Part0 = hand
	motor.Part1 = blade
	motor.C0 = c0
	motor.Parent = blade
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
