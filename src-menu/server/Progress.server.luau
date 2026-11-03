-- Lee lo guardado del jugador (lo reparte y guarda la partida, server/PlayerProgress) y lo deja en sus atributos para que el menú lo
-- muestre: ProgXP (XP total), ProgLevel, Rhoms (la moneda permanente), FrameId y TitleId (marco y título del perfil que lleva puestos).
-- Lo único que escribe es el marco y el título que el jugador elige (`ProfileRequest "equip"`), y solo si su nivel ya los desbloquea.
-- Sin guardado (Studio sin publicar) no pone nada de lo guardado, pero elegir sigue funcionando mientras dura la sesión.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progress = require(ReplicatedStorage.Shared.Progress)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)

local profile = Instance.new("RemoteFunction")
profile.Name = "ProfileRequest"
profile.Parent = ReplicatedStorage

local ok, store = pcall(function()
	return DataStoreService:GetDataStore("RhomulusProgress")
end)
if not ok then
	store = nil
end

local function publish(player, total, coins, frame, title)
	local level = (Progress.fromTotal(total))
	player:SetAttribute("ProgXP", total)
	player:SetAttribute("ProgLevel", level)
	player:SetAttribute("Rhoms", coins)
	player:SetAttribute("FrameId", Cosmetics.valid("frame", frame, level))
	player:SetAttribute("TitleId", Cosmetics.valid("title", title, level))
end

local function load(player)
	if not store then
		return
	end
	local total, coins, frame, title = 0, 0, nil, nil
	local readOk, value = pcall(function()
		return store:GetAsync("p_" .. player.UserId)
	end)
	if readOk and typeof(value) == "table" and typeof(value.xp) == "number" then
		total = value.xp
		coins = typeof(value.rhoms) == "number" and value.rhoms or 0
		frame, title = value.frame, value.title
	end
	if player.Parent == Players then
		publish(player, total, coins, frame, title)
	end
end

local lastEquip = {} -- [Player] = os.clock() de la última vez, para que no se pida en bucle

-- ("equip", "frame" | "title", id) -> true, o false y el motivo
profile.OnServerInvoke = function(player, action, kind, id)
	if action ~= "equip" or (kind ~= "frame" and kind ~= "title") or typeof(id) ~= "string" then
		return false, "Invalid request"
	end
	if os.clock() - (lastEquip[player] or 0) < 0.5 then
		return false, "Slow down, try again"
	end
	lastEquip[player] = os.clock()
	local level = player:GetAttribute("ProgLevel") or 1
	if not Cosmetics.unlocked(kind, id, level) then
		return false, "Locked: reach a higher level"
	end
	player:SetAttribute(kind == "frame" and "FrameId" or "TitleId", id)
	if store then
		local field = kind == "frame" and "frame" or "title"
		local saved = pcall(function()
			store:UpdateAsync("p_" .. player.UserId, function(old)
				old = typeof(old) == "table" and old or {}
				old[field] = id
				return old
			end)
		end)
		if not saved then
			return false, "Couldn't save. Try again"
		end
	end
	return true
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(load, player)
end)
for _, player in Players:GetPlayers() do
	task.spawn(load, player)
end
Players.PlayerRemoving:Connect(function(player)
	lastEquip[player] = nil
end)
