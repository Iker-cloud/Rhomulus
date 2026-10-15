-- Furgoneta de rescate: modelo furgoneta-de-rescate.glb con las ruedas en articulaciones propias; el cliente la anima al llegar (VanAnimator).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PropModel = require(script.Parent.PropModel)
local Furgoneta = require(script.Parent.ZombieData.Furgoneta)
local VanInterior = require(script.Parent.VanInterior)

local VanBuilder = {}

-- La van llega desde el fondo de la calle (se crea solo al llamar el rescate). Es el modelo de furgoneta-de-rescate.glb
-- con las ruedas en articulaciones propias; el cliente la anima al llegar (VanAnimator).
function VanBuilder.makeVan(position)
	local model, hitbox = PropModel.build(Furgoneta, position, 0, { wheels = true, scale = Config.Game.VanScale })
	model.Name = "Van"
	hitbox.CanCollide = false -- el cuerpo no es sólido: se sube por la puerta lateral con E (server/Boarding)
	hitbox.Anchored = true
	VanInterior.build(model, hitbox, CFrame.new(position), Config.Game.VanScale) -- caja hueca, asientos y puertas que se deslizan
	hitbox.PivotOffset = hitbox.CFrame:Inverse() * CFrame.new(position) -- el pivote del modelo es el punto del suelo (así PivotTo lo coloca donde se pide)

	-- Faros delanteros: luz sobre la calle
	for _, name in { "faro_izq", "faro_der" } do
		local lamp = model:FindFirstChild(name)
		if lamp then
			local light = Instance.new("SpotLight")
			light.Face = Enum.NormalId.Back -- el frente del modelo mira hacia -Z; el foco sale hacia ese lado
			light.Brightness = 3
			light.Range = 45
			light.Angle = 60
			light.Parent = lamp
		end
	end

	CollectionService:AddTag(model, "VanRig")
	return model
end

return VanBuilder
