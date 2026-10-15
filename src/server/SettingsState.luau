-- Ajustes del jugador que se guardan entre partidas: sensibilidad y calidad gráfica. Se guardan por jugador con DataStore.
-- Atributos del jugador que lee client/SettingsSave: SettingsReady (ya se consultó el guardado), SettingSens (número o nil)
-- y SettingMode ("auto", "1", "2"… o nil). Si el guardado no está disponible se trabaja sin recordar nada.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimit = require(script.Parent.RateLimit)

local SettingsState = {}

local KEY_PREFIX = "settings_"
local pending = {} -- [player] = { sens, mode } último valor recibido que aún no se guardó

local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("RhomulusPlayerFlags")
	end)
	if ok then
		store = result
	end
end

local function publish(player, data)
	if player.Parent ~= Players then
		return
	end
	player:SetAttribute("SettingSens", data and data.sens or nil)
	player:SetAttribute("SettingMode", data and data.mode or nil)
	player:SetAttribute("SettingsReady", true)
end

local function load(player)
	local data
	if store then
		local ok, value = pcall(function()
			return store:GetAsync(KEY_PREFIX .. player.UserId)
		end)
		if ok and typeof(value) == "table" then
			data = value
		end
	end
	publish(player, data)
end

local function save(player, data)
	if not store then
		return
	end
	pcall(function()
		store:SetAsync(KEY_PREFIX .. player.UserId, data)
	end)
end

-- Valida lo que manda el cliente: nunca se confía en él
local function clean(sens, mode)
	local T = Config.Touch
	if typeof(sens) ~= "number" or sens ~= sens then
		return nil
	end
	sens = math.clamp(math.round(sens * 100) / 100, T.SensitivityMin, T.SensitivityMax)
	local levels = #Config.Performance.Levels
	local n = tonumber(mode)
	if mode ~= "auto" and not (n and n >= 1 and n <= levels and n % 1 == 0) then
		return nil
	end
	return { sens = sens, mode = tostring(mode) }
end

function SettingsState.start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(load, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	Remotes.SaveSettings.OnServerEvent:Connect(function(player, sens, mode)
		if not RateLimit.check(player, "SaveSettings", 2) then
			return
		end
		local data = clean(sens, mode)
		if data then
			pending[player] = data
			task.spawn(function()
				save(player, data)
				if pending[player] == data then
					pending[player] = nil
				end
			end)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local data = pending[player]
		pending[player] = nil
		if data then
			save(player, data)
		end
	end)
end

return SettingsState
