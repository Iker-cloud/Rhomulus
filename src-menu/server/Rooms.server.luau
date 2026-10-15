-- Salas del menú. Cada sala vive en MemoryStore (clave = identificador interno de 5 letras) para que se vea desde cualquier
-- servidor del Menú. Hay dos tipos:
--   · PÚBLICA: aparece en la lista y se entra con un toque, sin código.
--   · PRIVADA: aparece en la lista con candado y se entra escribiendo su código de 4 letras (el juego lo genera).
-- La lista de salas (índice "RoomIndex") la mantienen los servidores que tienen jugadores en cada sala: cada POLL segundos refrescan
-- su entrada, que caduca sola si nadie la refresca. Las salas que ya empezaron salen de la lista.
-- Cuando el anfitrión pulsa EMPEZAR, cada servidor teletransporta a sus jugadores al servidor reservado de la partida, con el mapa y la
-- dificultad de la sala en los datos de teletransporte (la partida se salta la votación).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MemoryStoreService = game:GetService("MemoryStoreService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local Places = require(ReplicatedStorage.Shared.Places)
local Difficulties = require(ReplicatedStorage.Shared.Difficulties)

local MAX_PLAYERS = 4
local POLL = 2 -- segundos entre refrescos
local STALE = 12 -- un jugador que no se refresca en este tiempo se da por ido
local ROOM_TTL = 3600
local INDEX_TTL = 10 -- una entrada de la lista caduca si ningún servidor la refresca en este tiempo
local LIST_CACHE = 2 -- la lista se lee de MemoryStore como mucho cada tantos segundos por servidor
local MAX_LIST = 40
local MAPS = { Prueba = true, Morro = true }
local LETTERS = "ABCDEFGHJKLMNPQRSTUVWXYZ"

Players.CharacterAutoLoads = false

-- Almacén ----------------------------------------------------------------
-- MemoryStore solo funciona con el juego publicado. En Studio sin publicar se usa un almacén en memoria con la misma interfaz, para poder
-- probar las salas (y la lista) sin publicar.
local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function fakeHashMap()
	local data = {}
	local map = {}
	function map:GetAsync(key)
		return deepCopy(data[key])
	end
	function map:UpdateAsync(key, fn)
		local new = fn(deepCopy(data[key]))
		if new ~= nil then
			data[key] = deepCopy(new)
		end
		return deepCopy(new)
	end
	return map
end

local function fakeSortedMap()
	local data = {} -- [clave] = { value, expires }
	local map = {}
	function map:SetAsync(key, value, ttl)
		data[key] = { value = deepCopy(value), expires = os.clock() + (ttl or 3600) }
		return true
	end
	function map:RemoveAsync(key)
		data[key] = nil
	end
	function map:GetRangeAsync(_direction, count)
		local keys = {}
		for key, item in data do
			if item.expires < os.clock() then
				data[key] = nil
			else
				table.insert(keys, key)
			end
		end
		table.sort(keys)
		local list = {}
		for i = 1, math.min(count, #keys) do
			list[i] = { key = keys[i], value = deepCopy(data[keys[i]].value) }
		end
		return list
	end
	return map
end

local okRooms, rooms = pcall(function()
	return MemoryStoreService:GetHashMap("Rooms")
end)
local okIndex, index = pcall(function()
	return MemoryStoreService:GetSortedMap("RoomIndex")
end)
local usingFakeStore = false
if not (okRooms and okIndex) then
	if not RunService:IsStudio() then
		error(okRooms and index or rooms) -- publicado y sin MemoryStore: no hay salas
	end
	usingFakeStore = true
	rooms = fakeHashMap()
	index = fakeSortedMap()
	warn("[Rooms] (Studio) MemoryStore no disponible: se usa un almacén en memoria")
end

local request = Instance.new("RemoteFunction")
request.Name = "MenuRequest"
request.Parent = ReplicatedStorage
local update = Instance.new("RemoteEvent")
update.Name = "RoomUpdate"
update.Parent = ReplicatedStorage

local roomOf = {} -- [Player] = identificador de la sala en la que está
local teleporting = {} -- [identificador] = true cuando este servidor ya mandó a su gente

-- Utilidades -------------------------------------------------------------
local function randomCode(length)
	local r = {}
	for i = 1, length do
		local k = math.random(1, #LETTERS)
		r[i] = LETTERS:sub(k, k)
	end
	return table.concat(r)
end

local function prune(room)
	local now = os.time()
	local kept = {}
	for _, m in room.members do
		if now - m.t <= STALE then
			table.insert(kept, m)
		end
	end
	room.members = kept
	-- si el anfitrión se fue, la sala pasa al siguiente
	local hostPresent = false
	for _, m in kept do
		if m.id == room.host then
			hostPresent = true
		end
	end
	if not hostPresent and kept[1] then
		room.host = kept[1].id
	end
end

local function indexOf(room, userId)
	for i, m in room.members do
		if m.id == userId then
			return i
		end
	end
end

-- "Sala de <anfitrión>" (sale del nombre del anfitrión actual)
local function roomName(room)
	for _, m in room.members do
		if m.id == room.host then
			return "Sala de " .. m.name
		end
	end
	return "Sala"
end

-- Lo que ve un miembro de la sala (el código solo existe en las privadas y no incluye el acceso al servidor reservado)
local function view(room, id, userId)
	local names, ids = {}, {}
	local hostIndex, youIndex = 0, 0
	for i, m in room.members do
		names[i] = m.name
		ids[i] = m.id
		if m.id == room.host then
			hostIndex = i
		end
		if m.id == userId then
			youIndex = i
		end
	end
	return {
		id = id,
		name = roomName(room),
		public = room.public,
		code = (not room.public) and room.pass or nil,
		map = room.map,
		difficulty = room.difficulty or Difficulties.Default,
		names = names,
		ids = ids, -- para dibujar el avatar de cada jugador
		hostIndex = hostIndex,
		youIndex = youIndex,
		isHost = room.host == userId,
		started = room.started,
	}
end

-- Lo que ve cualquiera en la lista de salas (sin código de acceso)
local function summary(room, id)
	local ids = {}
	for i, m in room.members do
		ids[i] = m.id
	end
	return {
		ids = ids,
		id = id,
		name = roomName(room),
		public = room.public,
		map = room.map,
		difficulty = room.difficulty or Difficulties.Default,
		count = #room.members,
		max = MAX_PLAYERS,
	}
end

-- Mantiene la entrada de la sala en la lista (o la quita si ya empezó o quedó vacía)
local function publishIndex(id, room)
	pcall(function()
		if room and not room.started and #room.members > 0 then
			index:SetAsync(id, summary(room, id), INDEX_TTL)
		else
			index:RemoveAsync(id)
		end
	end)
end

-- Cambia la sala de forma atómica. fn recibe la sala y devuelve (ok, motivo). Devuelve la sala final o nil, motivo.
local function change(id, fn)
	local reason
	local ok, result = pcall(function()
		return rooms:UpdateAsync(id, function(room)
			if not room then
				reason = "Esa sala ya no existe"
				return nil
			end
			prune(room)
			local good, why = fn(room)
			if good == false then
				reason = why
				return nil
			end
			if #room.members == 0 then
				return nil -- sin jugadores: se deja que expire
			end
			return room
		end, ROOM_TTL)
	end)
	if not ok then
		warn("[Rooms] MemoryStore falló:", result)
		return nil, "No se pudo conectar. Intenta de nuevo"
	end
	if result == nil and not reason then
		reason = "La sala ya no existe"
	end
	return result, reason
end

local function member(player)
	return { id = player.UserId, name = player.DisplayName ~= "" and player.DisplayName or player.Name, t = os.time() }
end

local function push(player, room, id)
	if room then
		update:FireClient(player, view(room, id, player.UserId))
	else
		update:FireClient(player, nil)
	end
end

local function leave(player)
	local id = roomOf[player]
	roomOf[player] = nil
	if not id then
		return
	end
	local room = change(id, function(r)
		local i = indexOf(r, player.UserId)
		if i then
			table.remove(r.members, i)
			if r.host == player.UserId and r.members[1] then
				r.host = r.members[1].id
			end
		end
		return true
	end)
	-- Si la sala se quedó sin nadie desaparece de la lista enseguida
	if not room or #room.members == 0 then
		publishIndex(id, nil)
	else
		publishIndex(id, room)
	end
end

-- Acciones ---------------------------------------------------------------
local actions = {}

-- Crea una sala. opciones = { map, difficulty, public }
function actions.create(player, options)
	if type(options) ~= "table" then
		options = {}
	end
	if roomOf[player] then
		leave(player)
	end
	local map = MAPS[options.map] and options.map or "Morro"
	local difficulty = Difficulties.isValid(options.difficulty) and options.difficulty or Difficulties.Default
	local isPublic = options.public ~= false
	-- En Studio no se puede reservar servidor ni teletransportar: se usa un código falso para probar las salas
	local ok, access = true, "studio"
	if not RunService:IsStudio() then
		ok, access = pcall(function()
			return TeleportService:ReserveServer(Places.Game)
		end)
	end
	if not ok then
		warn("[Rooms] ReserveServer falló:", access)
		return { error = "No se pudo crear la sala. Intenta de nuevo" }
	end
	for _ = 1, 8 do
		local id = randomCode(5)
		local made = false
		local okSet = pcall(function()
			rooms:UpdateAsync(id, function(old)
				if old then
					prune(old)
					if #old.members > 0 then
						return nil -- ocupado: probar otro identificador
					end
				end
				made = true
				return {
					host = player.UserId,
					map = map,
					difficulty = difficulty,
					public = isPublic,
					pass = (not isPublic) and randomCode(4) or nil,
					access = access,
					started = false,
					members = { member(player) },
				}
			end, ROOM_TTL)
		end)
		if okSet and made then
			roomOf[player] = id
			local room = rooms:GetAsync(id)
			publishIndex(id, room)
			return { room = view(room, id, player.UserId) }
		end
	end
	return { error = "No se pudo crear la sala. Intenta de nuevo" }
end

-- Lista de salas abiertas (de todos los servidores del menú), con una caché corta para no gastar cuota de MemoryStore
local listCache, listTime = {}, -math.huge

function actions.list()
	if os.clock() - listTime >= LIST_CACHE then
		local ok, items = pcall(function()
			return index:GetRangeAsync(Enum.SortDirection.Ascending, MAX_LIST)
		end)
		if ok and items then
			local list = {}
			for _, item in items do
				local value = item.value
				if type(value) == "table" and value.count and value.count > 0 then
					table.insert(list, value)
				end
			end
			-- primero las que tienen más gente y sitio
			table.sort(list, function(a, b)
				local aFull, bFull = a.count >= a.max, b.count >= b.max
				if aFull ~= bFull then
					return not aFull
				end
				if a.count ~= b.count then
					return a.count > b.count
				end
				return a.id < b.id
			end)
			listCache, listTime = list, os.clock()
		end
	end
	return { rooms = listCache }
end

-- Entra a una sala de la lista. En las privadas hay que dar el código.
function actions.join(player, id, pass)
	if type(id) ~= "string" or not string.match(id, "^%a%a%a%a%a$") then
		return { error = "Sala no válida" }
	end
	id = string.upper(id)
	if roomOf[player] == id then
		return { error = "Ya estás en esa sala" }
	end
	if roomOf[player] then
		leave(player)
	end
	local wrongCode = false
	local room, reason = change(id, function(r)
		if r.started then
			return false, "Esa partida ya empezó"
		end
		if not r.public then
			local typed = type(pass) == "string" and string.upper(pass) or ""
			if typed ~= r.pass then
				wrongCode = true
				return false, "Código incorrecto"
			end
		end
		if indexOf(r, player.UserId) then
			return true
		end
		if #r.members >= MAX_PLAYERS then
			return false, "La sala está llena"
		end
		table.insert(r.members, member(player))
		return true
	end)
	if not room then
		return { error = reason, wrongCode = wrongCode }
	end
	roomOf[player] = id
	publishIndex(id, room)
	return { room = view(room, id, player.UserId) }
end

function actions.leave(player)
	leave(player)
	return {}
end

-- Cambios del anfitrión sobre su sala
local function hostChange(player, fn)
	local id = roomOf[player]
	if not id then
		return { error = "No estás en una sala" }
	end
	local room, reason = change(id, function(r)
		if r.host ~= player.UserId then
			return false, "Solo el anfitrión puede hacer eso"
		end
		if r.started then
			return false, "La partida ya empezó"
		end
		return fn(r)
	end)
	if not room then
		return { error = reason }
	end
	publishIndex(id, room)
	return { room = view(room, id, player.UserId) }
end

function actions.setMap(player, map)
	if not MAPS[map] then
		return { error = "Mapa no válido" }
	end
	return hostChange(player, function(r)
		r.map = map
		return true
	end)
end

function actions.setDifficulty(player, difficulty)
	if not Difficulties.isValid(difficulty) then
		return { error = "Dificultad no válida" }
	end
	return hostChange(player, function(r)
		r.difficulty = difficulty
		return true
	end)
end

-- Pública <-> privada. Al pasar a privada se genera un código nuevo.
function actions.setPublic(player, isPublic)
	isPublic = isPublic ~= false
	return hostChange(player, function(r)
		if r.public ~= isPublic then
			r.public = isPublic
			r.pass = (not isPublic) and randomCode(4) or nil
		end
		return true
	end)
end

function actions.start(player)
	local id = roomOf[player]
	if not id then
		return { error = "No estás en una sala" }
	end
	local room, reason = change(id, function(r)
		if r.host ~= player.UserId then
			return false, "Solo el anfitrión puede empezar"
		end
		r.started = true
		return true
	end)
	if not room then
		return { error = reason }
	end
	publishIndex(id, room) -- ya empezó: sale de la lista
	return { room = view(room, id, player.UserId) }
end

-- Límite de frecuencia: cada acción de la sala (usan MemoryStore, que tiene cuota) como mucho cada 0,4 s por jugador
-- (la lista, que se pide sola cada pocos segundos, puede ir cada 1 s)
local MIN_INTERVAL = { list = 1 }
local lastCall = setmetatable({}, { __mode = "k" }) -- [Player] = { [acción] = os.clock() }

request.OnServerInvoke = function(player, action, ...)
	local fn = actions[action]
	if not fn then
		return { error = "Acción no válida" }
	end
	local record = lastCall[player]
	if not record then
		record = {}
		lastCall[player] = record
	end
	local now = os.clock()
	if record[action] and now - record[action] < (MIN_INTERVAL[action] or 0.4) then
		return { error = "Más despacio, inténtalo de nuevo" }
	end
	record[action] = now
	local ok, result = pcall(fn, player, ...)
	if not ok then
		warn("[Rooms]", action, result)
		return { error = "Algo salió mal. Intenta de nuevo" }
	end
	return result
end

-- Refresco: mantiene las salas al día y lanza la partida ----------------------
local function localMembers(id)
	local list = {}
	for player, c in roomOf do
		if c == id then
			table.insert(list, player)
		end
	end
	return list
end

local function launch(id, room)
	if teleporting[id] then
		return
	end
	teleporting[id] = true
	if RunService:IsStudio() then
		print("[Rooms] (Studio) Aquí se teletransportaría a la sala", id, "con el mapa", room.map, "y la dificultad", room.difficulty)
		return
	end
	local list = localMembers(id)
	local ok, err = pcall(function()
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = room.access
		options:SetTeleportData({ private = true, map = room.map, difficulty = room.difficulty or Difficulties.Default, public = room.public })
		TeleportService:TeleportAsync(Places.Game, list, options)
	end)
	if not ok then
		warn("[Rooms] Teletransporte de la sala falló:", err)
		teleporting[id] = nil
	end
end

task.spawn(function()
	while true do
		task.wait(POLL)
		local ids = {}
		for _, id in roomOf do
			ids[id] = true
		end
		for id in ids do
			local room = change(id, function(r)
				for _, player in localMembers(id) do
					local i = indexOf(r, player.UserId)
					if i then
						r.members[i].t = os.time()
					end
				end
				return true
			end)
			local list = localMembers(id)
			if not room then
				-- la sala desapareció
				publishIndex(id, nil)
				for _, player in list do
					roomOf[player] = nil
					push(player, nil)
				end
			else
				publishIndex(id, room)
				for _, player in list do
					if indexOf(room, player.UserId) then
						push(player, room, id)
					else
						roomOf[player] = nil
						push(player, nil)
					end
				end
				if room.started then
					launch(id, room)
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	leave(player)
end)

-- (para probar en Studio) Salas de ejemplo en la lista cuando se usa el almacén en memoria
if usingFakeStore then
	local function fake(id, name, map, difficulty, ids, public)
		pcall(function()
			index:SetAsync(id, { id = id, name = name, public = public, map = map, difficulty = difficulty, ids = ids, count = #ids, max = MAX_PLAYERS }, 3600)
		end)
	end
	-- (ids de cuentas públicas de Roblox, solo para ver los avatares en las pruebas)
	fake("DEMOA", "Sala de Isaac", "Morro", "Tension", { 156, 261 }, true)
	fake("DEMOB", "Sala de Lucía", "Prueba", "Crisis", { 1 }, false)
	fake("DEMOC", "Sala de Mateo", "Morro", "Calma", { 156, 261, 1, 2 }, true)
end
