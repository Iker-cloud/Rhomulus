-- Composición de las oleadas del modo Survival (puro cálculo, sin tocar el mundo): GameState.survival le pide cada oleada
-- y la va soltando con el Director. Los valores de balance están en Config.Survival.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Difficulties = require(ReplicatedStorage.Shared.Difficulties)

local SurvivalWaves = {}

-- Los especiales (Tanque, Atrapador) se reducen con pocos jugadores
local SPECIAL_SCALE = { 0.5, 0.75, 1, 1 }

local function ramp(rule, wave)
	return math.min(rule.Max, rule.Start + rule.PerWave * (wave - 1))
end

-- Qué trae la oleada `wave` para `players` jugadores. Devuelve
-- { wave, boss, total, kinds (en orden de aparición), cap (máximo de vivos), health, speed, damage, tanks, grabbers }
function SurvivalWaves.compose(wave, players)
	local S = Config.Survival
	local count = math.clamp(players, 1, 4)
	local total = math.max(3, math.floor((S.BaseCount + S.PerWave * (wave - 1)) * S.PlayersScale[count] + 0.5))

	local boss = wave % S.BossEvery == 0
	local tanks, grabbers = 0, 0
	if wave >= S.TankFrom then
		if boss then
			tanks = math.ceil(wave / 10) -- 5: 1, 10: 1, 15: 2, 20: 2, 25: 3…
		elseif wave >= S.TankFrom + 8 and wave % S.BossEvery == 3 then
			tanks = 1
		end
	end
	if wave >= S.GrabberFrom then
		if boss then
			grabbers = 1 + (wave - S.GrabberFrom) // 10 -- 10: 1, 20: 2, 30: 3…
		elseif wave >= S.GrabberFrom + 2 and wave % S.BossEvery == 2 then
			grabbers = 1
		end
	end
	if tanks > 0 then
		tanks = math.max(1, math.floor(tanks * SPECIAL_SCALE[count] + 0.5))
	end
	if grabbers > 0 then
		grabbers = math.max(1, math.floor(grabbers * SPECIAL_SCALE[count] + 0.5))
	end

	-- Comunes y rápidos (los especiales ocupan parte del total)
	local commons = math.max(0, total - tanks - grabbers)
	local fastChance = ramp(S.Fast, wave)
	local kinds = {}
	for _ = 1, commons do
		table.insert(kinds, math.random() < fastChance and "Fast" or "Common")
	end
	-- Los especiales salen repartidos entre el 30 % y el 80 % de la oleada
	local specials = {}
	for _ = 1, tanks do
		table.insert(specials, "Tank")
	end
	for _ = 1, grabbers do
		table.insert(specials, "Grabber")
	end
	for index, kind in specials do
		local at = math.floor(#kinds * (0.3 + 0.5 * (index - 1) / math.max(1, #specials))) + 1
		table.insert(kinds, at, kind)
	end

	return {
		wave = wave,
		boss = boss,
		total = #kinds,
		kinds = kinds,
		cap = math.min(Difficulties.MaxAliveCap, S.AliveCap[count] + math.floor(S.CapPerWave * (wave - 1))),
		health = ramp(S.Health, wave),
		speed = ramp(S.Speed, wave),
		damage = ramp(S.Damage, wave),
		tanks = tanks,
		grabbers = grabbers,
	}
end

return SurvivalWaves
