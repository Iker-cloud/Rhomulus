-- Montones de latas sueltas del mapa nuevo: se recogen con E y suman latas al equipo (una vez por partida).
-- MapBuilderBarrio los define en refs.canPiles: { { model = Model, prompt = ProximityPrompt, amount = número opcional }, ... }.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerState = require(script.Parent.PlayerState)
local Points = require(script.Parent.Points)

local CanPiles = {}

local piles = {}

function CanPiles.init(list)
	piles = list or {}
	for _, pile in piles do
		pile.parent = pile.model.Parent
		local amount = pile.amount or Config.CanPiles.Amount
		pile.prompt.ActionText = "Recoger latas"
		pile.prompt.ObjectText = `+{amount} latas`
		pile.prompt.HoldDuration = Config.CanPiles.HoldTime
		pile.prompt.Triggered:Connect(function(player)
			if not pile.model.Parent or PlayerState.get(player) ~= "Normal" then
				return
			end
			pile.prompt.Enabled = false
			pile.model.Parent = nil
			Points.add(amount, player)
			Points.feed(`{player.DisplayName} recogió {amount} latas`)
		end)
	end
end

-- Vuelven a su sitio al empezar cada partida
function CanPiles.reset()
	for _, pile in piles do
		pile.model.Parent = pile.parent
		pile.prompt.Enabled = true
	end
end

return CanPiles
