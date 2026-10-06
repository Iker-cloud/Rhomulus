-- Latas del equipo (antes "puntos"): una sola bolsa compartida. El total se publica en Workspace.Points para la UI.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Points = {}

local total = 0

local function publish()
	workspace:SetAttribute("Points", total)
end

function Points.reset()
	total = 0
	publish()
end

function Points.add(amount)
	total += amount
	publish()
end

-- Devuelve false (sin cobrar) si no alcanzan
function Points.spend(amount)
	if total < amount then
		return false
	end
	total -= amount
	publish()
	return true
end

-- Aviso en pantalla para todos ("Iker abrió la caja")
function Points.feed(text)
	Remotes.Feed:FireAllClients(text)
end

publish()

return Points
