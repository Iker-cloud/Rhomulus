-- Pistola enfundada: cada sobreviviente lleva el modelo de la pistola a un lado de la cadera (derecha), fijo, sin animación.
-- (Cómo la sostiene en la mano se hará después.)
local Players = game:GetService("Players")

local WeaponModel = require(script.Parent.WeaponModel)
local Pistola = require(script.Parent.ZombieData.Pistola)

local Holster = {}

local SCALE = 0.8 -- un poco más pequeña que el tamaño natural, para que no estorbe
-- Posición en el marco de LowerTorso: cadera derecha, hacia afuera de la pierna
local HIP = Vector3.new(1.25, -0.35, 0)
-- Cañón hacia abajo y miras hacia el frente (-Z): el eje X de la pistola apunta a +Y y su eje Y a -Z
local ORIENTATION = CFrame.fromMatrix(Vector3.zero, Vector3.yAxis, Vector3.new(0, 0, -1), Vector3.new(-1, 0, 0))

local function attach(character)
	local torso = character:WaitForChild("LowerTorso", 10)
	if not torso then
		return
	end
	local old = character:FindFirstChild("PistolHolster")
	if old then
		old:Destroy()
	end

	local gun = WeaponModel.build(Pistola, SCALE)
	gun.Name = "PistolHolster"
	local root = gun.PrimaryPart
	gun:PivotTo(torso.CFrame * CFrame.new(HIP) * ORIENTATION)
	root.Anchored = false
	root.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = root
	weld.Parent = root
	gun.Parent = character
end

function Holster.start()
	local function setup(player)
		player.CharacterAdded:Connect(function(character)
			task.spawn(attach, character)
		end)
		if player.Character then
			task.spawn(attach, player.Character)
		end
	end
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
end

return Holster
