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
	local total, coins, frame, title, boxes = 0, 0, nil, nil, 0
	local skins, melee = nil, nil
	local readOk, value = pcall(function()
		return store:GetAsync("p_" .. player.UserId)
	end)
	if readOk and typeof(value) == "table" and typeof(value.xp) == "number" then
		total = value.xp
		coins = typeof(value.rhoms) == "number" and value.rhoms or 0
		boxes = typeof(value.crates) == "number" and value.crates or 0
		frame, title = value.frame, value.title
		skins, melee = value.skins, value.melee
	end
	if player.Parent == Players then
		publish(player, total, coins, frame, title)
		publishSkins(player, ownedList(skins), melee)
		player:SetAttribute("Crates", boxes)
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

-- ("openCrate"): abre una caja Arsenal (una que ya tiene o, si no, la compra con Rhoms) y sortea la skin. -> true, id, Rhoms devueltos
-- (0 si es nueva) | false y el motivo. El servidor decide todo; el cliente solo anima el resultado.
local sessionPity = {} -- [Player] = { sinceEpic, sinceLegendary } cuando no hay guardado
local function openCrate(player)
	local crate = Cosmetics.Crates.Arsenal
	local result, refund, reason = nil, 0, nil
	local useBox = (player:GetAttribute("Crates") or 0) > 0
	local pityNow
	local function draw(pity)
		local skin = Cosmetics.rollCrate("Arsenal", pity, math.random(), math.random())
		pity.sinceEpic = (skin.Rarity == "Epic" or skin.Rarity == "Legendary") and 0 or (pity.sinceEpic or 0) + 1
		pity.sinceLegendary = skin.Rarity == "Legendary" and 0 or (pity.sinceLegendary or 0) + 1
		return skin
	end
	if store then
		local okSave = pcall(function()
			store:UpdateAsync("p_" .. player.UserId, function(old)
				old = typeof(old) == "table" and old or {}
				old.skins = typeof(old.skins) == "table" and old.skins or {}
				old.pity = typeof(old.pity) == "table" and old.pity or {}
				reason = nil
				if (old.crates or 0) > 0 then
					old.crates -= 1
					useBox = true
				elseif (old.rhoms or 0) >= crate.Price then
					old.rhoms -= crate.Price
					useBox = false
				else
					reason = "Not enough Rhoms"
					return nil
				end
				local skin = draw(old.pity)
				result = skin
				if old.skins[skin.Id] or skin.Id == Cosmetics.DefaultMelee then
					refund = crate.Refund[skin.Rarity] or 0
					old.rhoms = (old.rhoms or 0) + refund
				else
					refund = 0
					old.skins[skin.Id] = true
				end
				pityNow = old.pity
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
		if useBox then
			-- se gasta la caja
		elseif (player:GetAttribute("Rhoms") or 0) >= crate.Price then
			useBox = false
		else
			return false, "Not enough Rhoms"
		end
		sessionPity[player] = sessionPity[player] or {}
		result = draw(sessionPity[player])
		if Cosmetics.ownsMelee(ownedOf(player), result.Id) then
			refund = crate.Refund[result.Rarity] or 0
		end
	end
	-- Atributos del jugador (lo que ve el menú)
	if useBox then
		player:SetAttribute("Crates", math.max(0, (player:GetAttribute("Crates") or 0) - 1))
	else
		player:SetAttribute("Rhoms", (player:GetAttribute("Rhoms") or 0) - crate.Price)
	end
	if refund > 0 then
		player:SetAttribute("Rhoms", (player:GetAttribute("Rhoms") or 0) + refund)
	else
		local owned = ownedOf(player)
		table.insert(owned, result.Id)
		player:SetAttribute("MeleeOwned", table.concat(owned, ","))
	end
	return true, result.Id, refund
end

-- ("equip", "frame" | "title", id) -> true, o false y el motivo
profile.OnServerInvoke = function(player, action, kind, id)
	if os.clock() - (lastEquip[player] or 0) < 0.5 then
		return false, "Slow down, try again"
	end
	if action == "openCrate" then
		lastEquip[player] = os.clock()
		return openCrate(player)
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
