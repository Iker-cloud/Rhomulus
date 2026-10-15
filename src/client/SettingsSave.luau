-- Recuerda los ajustes del jugador entre partidas (sensibilidad y calidad gráfica): al entrar los aplica con lo que guardó
-- server/SettingsState y, al cambiarlos en AJUSTES, se los manda al servidor (con una pausa para no mandar cada toque).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Controls = require(script.Parent.Controls)
local Performance = require(script.Parent.Performance)

local SettingsSave = {}

local SEND_DELAY = 1.5 -- segundos sin cambios antes de guardar
local player = Players.LocalPlayer

local function currentMode()
	return Performance.isAuto() and "auto" or tostring(Performance.level())
end

function SettingsSave.start()
	task.spawn(function()
		local deadline = os.clock() + 15
		while not player:GetAttribute("SettingsReady") and os.clock() < deadline do
			task.wait(0.25)
		end

		local sens = player:GetAttribute("SettingSens")
		local mode = player:GetAttribute("SettingMode")
		if typeof(sens) == "number" then
			Controls.setSensitivity(sens)
		end
		if mode == "auto" then
			Performance.setMode("auto")
		elseif tonumber(mode) then
			Performance.setMode(tonumber(mode))
		end

		-- Desde aquí, cada cambio se guarda
		local version = 0
		local lastSens, lastMode = Controls.getSensitivity(), currentMode()
		local function queue()
			local newMode = currentMode()
			if Controls.getSensitivity() == lastSens and newMode == lastMode then
				return
			end
			lastSens, lastMode = Controls.getSensitivity(), newMode
			version += 1
			local mine = version
			task.delay(SEND_DELAY, function()
				if mine == version then
					Remotes.SaveSettings:FireServer(lastSens, lastMode)
				end
			end)
		end
		Controls.sensitivityChanged:Connect(queue)
		Performance.changed:Connect(queue)
	end)
end

return SettingsSave
