-- Lee lo guardado del jugador (lo reparte y guarda la partida, server/PlayerProgress) y lo deja en sus atributos para que el menú lo
-- muestre: ProgXP (XP total), ProgLevel, Rhoms (la moneda permanente), FrameId y TitleId (marco y título del perfil que lleva puestos).
-- Lo único que escribe es lo que el jugador elige o compra (`ProfileRequest`): el marco y el título ("equip", solo si su nivel ya los
-- desbloquea) y las armas cuerpo a cuerpo ("buySkin" gasta Rhoms con UpdateAsync, que es atómico; "equipSkin" lleva una que ya tiene).
-- Atributos de las armas: MeleeOwned ("Knife,Pan") y MeleeSkin (la equipada). Cajas: Crates (sin abrir); "openCrate" gasta una caja
-- (o Rhoms) y sortea una skin con Cosmetics.rollCrate; si ya la tenía devuelve Rhoms.
-- Sin guardado (Studio sin publicar) no pone nada de lo guardado, pero elegir sigue funcionando mientras dura la sesión.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progress = require(ReplicatedStorage.Shared.Progress)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Accessories = require(ReplicatedStorage.Shared.Accessories)
local Missions = require(ReplicatedStorage.Shared.Missions)

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
			if skins[skin.Id] == true and skin.Id ~= Cosmetics.DefaultMelee then
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
	local total, coins, frame, title, boxes, boxesB = 0, 0, nil, nil, 0, 0
	local acc, accEq = nil, nil
	local skins, melee = nil, nil
	local daily, streakData = nil, nil
	local readOk, value = pcall(function()
		return store:GetAsync("p_" .. player.UserId)
	end)
	if readOk and typeof(value) == "table" and typeof(value.xp) == "number" then
		total = value.xp
		coins = typeof(value.rhoms) == "number" and value.rhoms or 0
		boxes = typeof(value.crates) == "number" and value.crates or 0
		boxesB = typeof(value.crates_b) == "number" and value.crates_b or 0
		acc, accEq = value.acc, value.accEq
		frame, title = value.frame, value.title
		skins, melee = value.skins, value.melee
		daily, streakData = value.daily, value.streak
	end
	if player.Parent == Players then
		publish(player, total, coins, frame, title)
		publishSkins(player, ownedList(skins), melee)
		-- Misiones diarias (el menú calcula cuáles son con Missions.pick y las dibuja)
		local today = Missions.today()
		local state = Missions.normalize(daily, today)
		player:SetAttribute("MissionDay", today)
		player:SetAttribute("MissionProg", table.concat(state.prog, ","))
		player:SetAttribute("MissionDone", (state.done[1] and "1" or "0") .. "," .. (state.done[2] and "1" or "0") .. "," .. (state.done[3] and "1" or "0"))
		player:SetAttribute("MissionStreak", Missions.streakCount(streakData, today))
		player:SetAttribute("Crates", boxes)
		player:SetAttribute("CratesBarrio", boxesB)
		local list = {}
		if typeof(acc) == "table" then
			for _, item in Accessories.Items do
				if acc[item.Id] == true then
					table.insert(list, item.Id)
				end
			end
		end
		player:SetAttribute("AccOwned", table.concat(list, ","))
		local worn = {}
		if typeof(accEq) == "table" then
			for slot, id in accEq do
				if typeof(id) == "string" and table.find(list, id) then
					worn[slot] = id
				end
			end
		end
		player:SetAttribute("AccEquipped", Accessories.encode(worn))
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

-- ("openCrate", "Arsenal" | "Barrio"): abre una caja (una que ya tiene o, si no, la compra con Rhoms) y sortea lo que sale: una skin de
-- cuerpo a cuerpo (Arsenal) o un accesorio (Barrio). -> true, id, Rhoms devueltos (0 si es nuevo) | false y el motivo. El servidor
-- decide todo; el cliente solo anima el resultado.
local CRATE_KINDS = {
	Arsenal = { boxField = "crates", boxAttr = "Crates", ownedField = "skins", pityField = "pity" },
	Barrio = { boxField = "crates_b", boxAttr = "CratesBarrio", ownedField = "acc", pityField = "pity_b" },
}
local sessionPity = {} -- [Player] = { [tipo] = { sinceEpic, sinceLegendary } } cuando no hay guardado

local function ownedAccessories(player)
	local text = player:GetAttribute("AccOwned")
	return type(text) == "string" and string.split(text, ",") or {}
end

local function openCrate(player, kind)
	local cfg = CRATE_KINDS[kind]
	local crate = Cosmetics.Crates[kind]
	if not cfg then
		return false, "Invalid request"
	end
	local result, refund, reason = nil, 0, nil
	local useBox = (player:GetAttribute(cfg.boxAttr) or 0) > 0
	local function draw(pity)
		local item = Cosmetics.rollCrate(kind, pity, math.random(), math.random())
		pity.sinceEpic = (item.Rarity == "Epic" or item.Rarity == "Legendary") and 0 or (pity.sinceEpic or 0) + 1
		pity.sinceLegendary = item.Rarity == "Legendary" and 0 or (pity.sinceLegendary or 0) + 1
		return item
	end
	local function isOwnedLocal(id)
		if kind == "Arsenal" then
			return Cosmetics.ownsMelee(ownedOf(player), id)
		end
		return table.find(ownedAccessories(player), id) ~= nil
	end
	if store then
		local okSave = pcall(function()
			store:UpdateAsync("p_" .. player.UserId, function(old)
				old = typeof(old) == "table" and old or {}
				old[cfg.ownedField] = typeof(old[cfg.ownedField]) == "table" and old[cfg.ownedField] or {}
				old[cfg.pityField] = typeof(old[cfg.pityField]) == "table" and old[cfg.pityField] or {}
				reason = nil
				if (old[cfg.boxField] or 0) > 0 then
					old[cfg.boxField] -= 1
					useBox = true
				elseif (old.rhoms or 0) >= crate.Price then
					old.rhoms -= crate.Price
					useBox = false
				else
					reason = "Not enough Rhoms"
					return nil
				end
				local item = draw(old[cfg.pityField])
				result = item
				if old[cfg.ownedField][item.Id] or item.Id == Cosmetics.DefaultMelee then
					refund = crate.Refund[item.Rarity] or 0
					old.rhoms = (old.rhoms or 0) + refund
				else
					refund = 0
					old[cfg.ownedField][item.Id] = true
				end
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
		-- sin guardado (Studio sin publicar): solo dura la sesión
		if not useBox and (player:GetAttribute("Rhoms") or 0) < crate.Price then
			return false, "Not enough Rhoms"
		end
		sessionPity[player] = sessionPity[player] or {}
		sessionPity[player][kind] = sessionPity[player][kind] or {}
		result = draw(sessionPity[player][kind])
		if isOwnedLocal(result.Id) then
			refund = crate.Refund[result.Rarity] or 0
		end
	end
	-- Atributos del jugador (lo que ve el menú)
	if useBox then
		player:SetAttribute(cfg.boxAttr, math.max(0, (player:GetAttribute(cfg.boxAttr) or 0) - 1))
	else
		player:SetAttribute("Rhoms", (player:GetAttribute("Rhoms") or 0) - crate.Price)
	end
	if refund > 0 then
		player:SetAttribute("Rhoms", (player:GetAttribute("Rhoms") or 0) + refund)
	elseif kind == "Arsenal" then
		local owned = ownedOf(player)
		table.insert(owned, result.Id)
		player:SetAttribute("MeleeOwned", table.concat(owned, ","))
	else
		local owned = ownedAccessories(player)
		table.insert(owned, result.Id)
		player:SetAttribute("AccOwned", table.concat(owned, ","))
	end
	return true, result.Id, refund
end

-- ("equipAcc", ranura, id): se pone un accesorio que ya tiene en su ranura; con id vacío se lo quita. -> true | false y el motivo
local function equipAccessory(player, slot, id)
	if typeof(slot) ~= "string" or not table.find(Accessories.Slots, slot) then
		return false, "Invalid request"
	end
	local worn = Accessories.decode(player:GetAttribute("AccEquipped"))
	if id == nil or id == "" then
		worn[slot] = nil
		id = nil
	else
		local item = Accessories.get(id)
		if typeof(id) ~= "string" or not item or item.Slot ~= slot or not table.find(ownedAccessories(player), id) then
			return false, "You don't own this one"
		end
		worn[slot] = id
	end
	player:SetAttribute("AccEquipped", Accessories.encode(worn))
	if store then
		local okSave = pcall(function()
			store:UpdateAsync("p_" .. player.UserId, function(old)
				old = typeof(old) == "table" and old or {}
				old.accEq = typeof(old.accEq) == "table" and old.accEq or {}
				old.accEq[slot] = id
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
	if action == "openCrate" then
		lastEquip[player] = os.clock()
		return openCrate(player, kind or "Arsenal") -- aquí `kind` trae el tipo de caja
	end
	if action == "equipAcc" then
		lastEquip[player] = os.clock()
		return equipAccessory(player, kind, id) -- aquí `kind` trae la ranura
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
	sessionPity[player] = nil
end)
