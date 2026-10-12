-- Salas del menú. Cada sala vive en MemoryStore (clave = código de 4 letras) para que se vea desde cualquier
-- servidor del Menú. Cada servidor refresca sus jugadores cada POLL segundos: eso mantiene la sala al día,
-- avisa a los clientes y, cuando el anfitrión pulsa EMPEZAR, teletransporta a los jugadores de este servidor
-- al servidor reservado de la partida, con el mapa elegido en los datos de teletransporte.
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
local MAPS = { Prueba = true, Morro = true }
local LETTERS = "ABCDEFGHJKLMNPQRSTUVWXYZ"

Players.CharacterAutoLoads = false

local rooms = MemoryStoreService:GetHashMap("Rooms")

local request = Instance.new("RemoteFunction")
request.Name = "MenuRequest"
request.Parent = ReplicatedStorage
local update = Instance.new("RemoteEvent")
update.Name = "RoomUpdate"
update.Parent = ReplicatedStorage

local roomOf = {} -- [Player] = código de la sala en la que está
local teleporting = {} -- [código] = true cuando este servidor ya mandó a su gente

-- Utilidades -------------------------------------------------------------
local function randomCode()
	local r = {}
	for i = 1, 4 do
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

-- Lo que ve el cliente (sin el código de acceso al servidor reservado)
local function view(room, code, userId)
	local names = {}
	local hostIndex, youIndex = 0, 0
	for i, m in room.members do
		names[i] = m.name
		if m.id == room.host then
			hostIndex = i
		end
		if m.id == userId then
			youIndex = i
		end
	end
	return {
		code = code,
		map = room.map,
		difficulty = room.difficulty or Difficulties.Default,
		names = names,
		hostIndex = hostIndex,
		youIndex = youIndex,
		isHost = room.host == userId,
		started = room.started,
	}
end

-- Cambia la sala de forma atómica. fn recibe la sala y devuelve (ok, motivo). Devuelve la sala final o nil, motivo.
local function change(code, fn)
	local reason
	local ok, result = pcall(function()
		return rooms:UpdateAsync(code, function(room)
			if not room then
				reason = "No existe una sala con ese código"
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

local function push(player, room, code)
	if room then
		update:FireClient(player, view(room, code, player.UserId))
	else
		update:FireClient(player, nil)
	end
end

local function leave(player)
	local code = roomOf[player]
	roomOf[player] = nil
	if not code then
		return
	end
	change(code, function(room)
		local i = indexOf(room, player.UserId)
		if i then
			table.remove(room.members, i)
			if room.host == player.UserId and room.members[1] then
				room.host = room.members[1].id
			end
		end
		return true
	end)
end

-- Acciones ---------------------------------------------------------------
local actions = {}

function actions.create(player, map)
	if roomOf[player] then
		leave(player)
	end
	if not MAPS[map] then
		map = "Morro"
	end
	-- En Studio no se puede reservar servidor ni teletransportar: se usa un código falso para probar las salas
	local ok, access = true, "studio"
	if not RunService:IsStudio() then
		ok, access = pcall(function()
			return TeleportService:ReserveServer(Places.Game)
		end)
	end
	if not ok then
		warn("[Rooms] ReserveServer falló:", access)
		return { error = "No se pudo crear la partida. Intenta de nuevo" }
	end
	for _ = 1, 8 do
		local code = randomCode()
		local made = false
		local okSet = pcall(function()
			rooms:UpdateAsync(code, function(old)
				if old then
					prune(old)
					if #old.members > 0 then
						return nil -- ocupado: probar otro código
					end
				end
				made = true
				return { host = player.UserId, map = map, difficulty = Difficulties.Default, access = access, started = false, members = { member(player) } }
			end, ROOM_TTL)
		end)
		if okSet and made then
			roomOf[player] = code
			local room = rooms:GetAsync(code)
			return { room = view(room, code, player.UserId) }
		end
	end
	return { error = "No se pudo crear la partida. Intenta de nuevo" }
end

function actions.join(player, code)
	if type(code) ~= "string" then
		return { error = "Código no válido" }
	end
	code = string.upper(code)
	if not string.match(code, "^%a%a%a%a$") then
		return { error = "Código no válido" }
	end
	if roomOf[player] == code then
		return { error = "Ya estás en esa sala" }
	end
	if roomOf[player] then
		leave(player)
	end
	local room, reason = change(code, function(r)
		if r.started then
			return false, "Esa partida ya empezó"
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
		return { error = reason }
	end
	roomOf[player] = code
	return { room = view(room, code, player.UserId) }
end

function actions.leave(player)
	leave(player)
	return {}
end

function actions.setMap(player, map)
	local code = roomOf[player]
	if not code or not MAPS[map] then
		return { error = "Mapa no válido" }
	end
	local room, reason = change(code, function(r)
		if r.host ~= player.UserId then
			return false, "Solo el anfitrión elige el mapa"
		end
		r.map = map
		return true
	end)
	if not room then
		return { error = reason }
	end
	return { room = view(room, code, player.UserId) }
end

function actions.setDifficulty(player, id)
	local code = roomOf[player]
	if not code or not Difficulties.isValid(id) then
		return { error = "Dificultad no válida" }
	end
	local room, reason = change(code, function(r)
		if r.host ~= player.UserId then
			return false, "Solo el anfitrión elige la dificultad"
		end
		r.difficulty = id
		return true
	end)
	if not room then
		return { error = reason }
	end
	return { room = view(room, code, player.UserId) }
end

function actions.start(player)
	local code = roomOf[player]
	if not code then
		return { error = "No estás en una sala" }
	end
	local room, reason = change(code, function(r)
		if r.host ~= player.UserId then
			return false, "Solo el anfitrión puede empezar"
		end
		r.started = true
		return true
	end)
	if not room then
		return { error = reason }
	end
	return { room = view(room, code, player.UserId) }
end

function actions.play(player)
	-- Partida pública: cualquier servidor de la partida; ahí se vota el mapa
	if roomOf[player] then
		leave(player)
	end
	if RunService:IsStudio() then
		return { error = "El teletransporte solo funciona publicado" }
	end
	local ok, err = pcall(function()
		local options = Instance.new("TeleportOptions")
		options:SetTeleportData({ private = false })
		TeleportService:TeleportAsync(Places.Game, { player }, options)
	end)
	if not ok then
		warn("[Rooms] Teletransporte público falló:", err)
		return { error = "No se pudo entrar a la partida. Intenta de nuevo" }
	end
	return {}
end

request.OnServerInvoke = function(player, action, arg)
	local fn = actions[action]
	if not fn then
		return { error = "Acción no válida" }
	end
	local ok, result = pcall(fn, player, arg)
	if not ok then
		warn("[Rooms]", action, result)
		return { error = "Algo salió mal. Intenta de nuevo" }
	end
	return result
end

-- Refresco: mantiene las salas al día y lanza la partida ----------------------
local function localMembers(code)
	local list = {}
	for player, c in roomOf do
		if c == code then
			table.insert(list, player)
		end
	end
	return list
end

local function launch(code, room)
	if teleporting[code] then
		return
	end
	teleporting[code] = true
	if RunService:IsStudio() then
		print("[Rooms] (Studio) Aquí se teletransportaría a la sala", code, "con el mapa", room.map)
		return
	end
	local list = localMembers(code)
	local ok, err = pcall(function()
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = room.access
		options:SetTeleportData({ private = true, map = room.map, difficulty = room.difficulty or Difficulties.Default, code = code })
		TeleportService:TeleportAsync(Places.Game, list, options)
	end)
	if not ok then
		warn("[Rooms] Teletransporte privado falló:", err)
		teleporting[code] = nil
	end
end

task.spawn(function()
	while true do
		task.wait(POLL)
		local codes = {}
		for _, code in roomOf do
			codes[code] = true
		end
		for code in codes do
			local room = change(code, function(r)
				for _, player in localMembers(code) do
					local i = indexOf(r, player.UserId)
					if i then
						r.members[i].t = os.time()
					end
				end
				return true
			end)
			local list = localMembers(code)
			if not room then
				-- la sala desapareció
				for _, player in list do
					roomOf[player] = nil
					push(player, nil)
				end
			else
				for _, player in list do
					if indexOf(room, player.UserId) then
						push(player, room, code)
					else
						roomOf[player] = nil
						push(player, nil)
					end
				end
				if room.started then
					launch(code, room)
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	leave(player)
end)
