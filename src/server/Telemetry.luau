-- Datos de juego para balancear: eventos personalizados de Roblox (AnalyticsService) que se ven en Creator Hub → Analytics →
-- Custom events. Cada evento lleva en los campos: 1 = etapa o resultado, 2 = dificultad, 3 = número de jugadores.
--   stage          (valor 1)       cada jugador, al entrar a cada etapa de la partida: sirve de embudo (¿en cuál se pierde la gente?)
--   player_downed  (valor 1)       un jugador cae; campo 1 = etapa
--   player_died    (valor 1)       un jugador muere (se desangró o murió); campo 1 = etapa
--   survival_wave  (oleada)        modo Survival: empieza cada oleada
--   round_end      (segundos)      fin de partida; campo 1 = "win" o "loss"; el valor es lo que duró desde que salieron del lobby
-- Si AnalyticsService falla (Studio sin publicar, por ejemplo) no pasa nada: todo va dentro de pcall.
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")

local Difficulty = require(script.Parent.Difficulty)

local Telemetry = {}

local roundStart = nil
local lastStage = nil -- GameState repite la etapa al cambiar solo el mensaje: se cuenta una sola vez

local function log(player, name, value, field1)
	pcall(function()
		AnalyticsService:LogCustomEvent(player, name, value, {
			[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = field1,
			[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = Difficulty.id(),
			[Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = tostring(#Players:GetPlayers()),
		})
	end)
end

-- Cada cambio de etapa (GameState.setStage)
function Telemetry.stage(name)
	if name == lastStage then
		return
	end
	lastStage = name
	if name == "Zone1" or (name == "WaveBreak" and roundStart == nil) then
		roundStart = os.clock()
	end
	for _, player in Players:GetPlayers() do
		log(player, "stage", 1, name)
	end
end

-- Los mutadores que salieron en la ronda (campo 1 = ids separados por comas, o "ninguno")
function Telemetry.mutators(ids)
	local text = #ids > 0 and table.concat(ids, ",") or "ninguno"
	for _, player in Players:GetPlayers() do
		log(player, "round_mutators", 1, text)
	end
end

-- Survival: cada oleada que empieza (valor = número de oleada; campo 1 = "wave")
function Telemetry.wave(wave, players)
	for _, player in Players:GetPlayers() do
		log(player, "survival_wave", wave, "wave")
	end
end

function Telemetry.downed(player)
	log(player, "player_downed", 1, tostring(workspace:GetAttribute("Stage")))
end

function Telemetry.died(player)
	log(player, "player_died", 1, tostring(workspace:GetAttribute("Stage")))
end

function Telemetry.result(won)
	local seconds = roundStart and math.floor(os.clock() - roundStart) or 0
	roundStart = nil
	for _, player in Players:GetPlayers() do
		log(player, "round_end", seconds, won and "win" or "loss")
	end
end

return Telemetry
