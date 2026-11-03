-- Lee lo guardado del jugador (lo reparte y guarda la partida, server/PlayerProgress) y lo deja en sus atributos para que el menú lo
-- muestre: ProgXP (XP total), ProgLevel, Rhoms (la moneda permanente), FrameId y TitleId (marco y título del perfil que lleva puestos).
-- Lo único que escribe es lo que el jugador elige o compra (`ProfileRequest`): el marco y el título ("equip", solo si su nivel ya los
-- desbloquea) y las armas cuerpo a cuerpo ("buySkin" gasta Rhoms con UpdateAsync, que es atómico; "equipSkin" lleva una que ya tiene).
-- Atributos de las armas: MeleeOwned ("Knife,Pan") y MeleeSkin (la equipada).
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

-- Lista de ids de skins que hay en lo guardado (`skins` = { [id] = true })
local function ownedList(skins)
	local list = {}
	if typeof(skins) == "table" then
		for _, skin in Cosmetics.MeleeSkins do
			if skins[skin.Id] == true and skin.Price > 0 then
				table.insert(list, skin.Id)
			end
		end
	end
	return list
end

local function publishSkins(player, owned, equipped)
	player:SetAttribute("MeleeOwned", table.concat(owned, ","))
	player:SetAttribute("MeleeSkin", Cosmetics.validMelee(owned, equipped))
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
	local skins, melee = nil, nil
	local readOk, value = pcall(function()
		return store:GetAsync("p_" .. player.UserId)
	end)
	if readOk and typeof(value) == "table" and typeof(value.xp) == "number" then
		total = value.xp
		coins = typeof(value.rhoms) == "number" and value.rhoms or 0
		frame, title = value.frame, value.title
		skins, melee = value.skins, value.melee
	end
	if player.Parent == Players then
		publish(player, total, coins, frame, title)
		publishSkins(player, ownedList(skins), melee)
	end
end

local lastEquip = {} -- [Player] = os.clock() de la última vez, para que no se pida en bucle

local function ownedOf(player)
	local text = player:GetAttribute("MeleeOwned")
	return type(text) == "string" and string.split(text, ",") or {}
end

-- ("buySkin", id): compra el arma con Rhoms y se la pone. -> true, o false y el motivo
local function buySkin(player, id)
	local skin = Cosmetics.melee(id)
	if not skin or skin.Price <= 0 then
		return false, "Invalid request"
	end
	if Cosmetics.ownsMelee(ownedOf(player), id) then
		return false, "You already own this one"
	end
	local reason = nil
	if store then
		local okSave = pcall(function()
			store:UpdateAsync("p_" .. player.UserId, function(old)
				old = typeof(old) == "table" and old or {}
				old.skins = typeof(old.skins) == "table" and old.skins or {}
				if old.skins[id] then
					reason = "You already own this one"
					return nil
				end
				if (old.rhoms or 0) < skin.Price then
					reason = "Not enough Rhoms"
					return nil
				end
				old.rhoms = (old.rhoms or 0) - skin.Price
				old.skins[id] = true
				old.melee = id
				reason = nil
				return old
			end)
		end)
		if not okSave then
			return false, "Couldn't save. Try again"
		end
		if reason then
			return false, reason
		end
	else
		-- sin guardado (Studio sin publicar): se compra solo en esta sesión
		if (player:GetAttribute("Rhoms") or 0) < skin.Price then
			return false, "Not enough Rhoms"
		end
	end
	local owned = ownedOf(player)
	table.insert(owned, id)
	player:SetAttribute("Rhoms", (player:GetAttribute("Rhoms") or 0) - skin.Price)
	publishSkins(player, owned, id)
	return true
end

-- ("equipSkin", id): lleva una que ya tiene (el cuchillo siempre se tiene)
local function equipSkin(player, id)
	if typeof(id) ~= "string" or not Cosmetics.ownsMelee(ownedOf(player), id) then
		return false, "You don't own this one"
	end
	player:SetAttribute("MeleeSkin", id)
	if store then
		local okSave = pcall(function()
			store:UpdateAsync("p_" .. player.UserId, function(old)
				old = typeof(old) == "table" and old or {}
				old.melee = id
				return old
			end)
		end)
		if not okSave then
			return false, "Couldn't save. Try again"
		end
	end
	return true
end

-- ("equip", "frame" | "title", id) -> true, o false y el motivo
profile.OnServerInvoke = function(player, action, kind, id)
	if os.clock() - (lastEquip[player] or 0) < 0.5 then
		return false, "Slow down, try again"
	end
	if action == "buySkin" or action == "equipSkin" then
		lastEquip[player] = os.clock()
		local handler = action == "buySkin" and buySkin or equipSkin
		return handler(player, kind) -- aquí `kind` trae el id de la skin
	end
	if action ~= "equip" or (kind ~= "frame" and kind ~= "title") or typeof(id) ~= "string" then
		return false, "Invalid request"
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
