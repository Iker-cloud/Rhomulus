-- Latas del equipo (antes "puntos"): una sola bolsa compartida. El total se publica en Workspace.Points para la UI.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Points = {}

local total = 0

local function publish()
	workspace:SetAttribute("Points", total)
end

-- Cuánto ha sumado cada jugador al total en esta partida (atributo "LatasEarned" del jugador, lo muestra ContribHud)
function Points.reset()
	total = 0
	publish()
	for _, player in Players:GetPlayers() do
		player:SetAttribute("LatasEarned", 0)
	end
end

-- `contributor` (opcional): el jugador al que se le cuenta lo que suma
function Points.add(amount, contributor)
	total += amount
	publish()
	if contributor and contributor.Parent then
		contributor:SetAttribute("LatasEarned", (contributor:GetAttribute("LatasEarned") or 0) + amount)
	end
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
