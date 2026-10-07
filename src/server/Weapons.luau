-- Autoridad de armas: valida cada disparo, hace el raycast y aplica el daño.
-- Cada jugador tiene la pistola (siempre) y, si la saca de la caja, un arma principal.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerState = require(script.Parent.PlayerState)
local Points = require(script.Parent.Points)
local Stats = require(script.Parent.Stats)
local WeaponRig = require(script.Parent.WeaponRig)

local states = {} -- [Player] = { pistol, primary, current, reloading, lastShot, token }

local Weapons = {}

local function newSlot(name)
	local cfg = Config.Weapons[name]
	return {
		name = name,
		ammo = cfg.MagSize,
		reserve = cfg.InfiniteReserve and math.huge or cfg.ReserveStart,
	}
end

local function newState(player)
	return { player = player, pistol = newSlot("Pistol"), primary = nil, current = "pistol", reloading = false, lastShot = 0, token = 0 }
end

-- Caído o cargando a alguien: solo se puede usar la pistola
local function activeSlot(player, state)
	local restricted = PlayerState.get(player) ~= "Normal" or player:GetAttribute("Carrying") ~= nil
	if state.current == "primary" and state.primary and not restricted then
		return state.primary
	end
	return state.pistol
end

local function isValidVector(v)
	return typeof(v) == "Vector3" and v.X == v.X and v.Y == v.Y and v.Z == v.Z
end

local function sendAmmo(player)
	local state = states[player]
	if not state then
		return
	end
	local slot = activeSlot(player, state)
	local cfg = Config.Weapons[slot.name]
	local reserve = slot.reserve == math.huge and -1 or slot.reserve -- -1 = infinita
	Remotes.AmmoUpdate:FireClient(player, slot.ammo, reserve, cfg.MagSize, state.reloading, cfg.Name)
	WeaponRig.set(player, slot.name, state.primary and state.primary.name or nil)
end

-- Los demás clientes animan la recarga con estos tiempos (hora del servidor)
local function setReloadAttributes(player, duration)
	local now = duration and workspace:GetServerTimeNow() or nil
	player:SetAttribute("ReloadStart", now)
	player:SetAttribute("ReloadEnd", now and now + duration or nil)
end

local function cancelReload(state)
	state.reloading = false
	state.token += 1 -- invalida cualquier recarga en curso
	setReloadAttributes(state.player, nil)
end

local function startReload(player)
	local state = states[player]
	if not state or state.reloading then
		return
	end
	local slot = activeSlot(player, state)
	local cfg = Config.Weapons[slot.name]
	if slot.ammo >= cfg.MagSize or slot.reserve <= 0 then
		return
	end

	state.reloading = true
	state.token += 1
	local token = state.token
	setReloadAttributes(player, cfg.ReloadTime)
	sendAmmo(player)

	task.delay(cfg.ReloadTime, function()
		if states[player] ~= state or state.token ~= token then
			return
		end
		local taken = math.min(cfg.MagSize - slot.ammo, slot.reserve)
		slot.ammo += taken
		if slot.reserve ~= math.huge then
			slot.reserve -= taken
		end
		state.reloading = false
		setReloadAttributes(player, nil)
		sendAmmo(player)
	end)
end

-- Dirección del perdigón dentro de un cono de `degrees` grados
local function spread(direction, degrees)
	if degrees <= 0 then
		return direction
	end
	local cf = CFrame.lookAt(Vector3.zero, direction)
		* CFrame.Angles(0, 0, math.random() * math.pi * 2)
		* CFrame.Angles(math.random() * math.rad(degrees), 0, 0)
	return cf.LookVector
end

-- ¿El rayo pasa por la cabeza del zombie? (la caja invisible del zombie tapa la cabeza, así que se mide la cercanía)
local function isHeadshot(model, origin, direction, hitDistance)
	local head
	for _, name in Config.Headshot.PartNames do
		head = model:FindFirstChild(name)
		if head then
			break
		end
	end
	if not (head and head:IsA("BasePart")) then
		return false
	end
	local along = math.clamp((head.Position - origin):Dot(direction), 0, hitDistance + Config.Headshot.Depth)
	local radius = head.Size.Magnitude * Config.Headshot.RadiusScale
	return (head.Position - (origin + direction * along)).Magnitude <= radius
end

local function onFire(player, origin, direction)
	local state = states[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head")
	if not (state and humanoid and head) or humanoid.Health <= 0 then
		return
	end
	if not (isValidVector(origin) and isValidVector(direction)) or direction.Magnitude < 0.001 then
		return
	end

	-- Anti-trampa: el origen debe estar cerca del jugador y se respeta la cadencia
	if (origin - head.Position).Magnitude > Config.MaxShotOriginDistance then
		return
	end
	local slot = activeSlot(player, state)
	local cfg = Config.Weapons[slot.name]
	local now = os.clock()
	if now - state.lastShot < cfg.FireCooldown * 0.8 or state.reloading then
		return
	end
	if slot.ammo <= 0 then
		startReload(player)
		return
	end

	state.lastShot = now
	slot.ammo -= 1
	sendAmmo(player)

	-- El rayo atraviesa a todos los jugadores (un compañero en la línea de fuego no debe bloquear la bala)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignored = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignored, other.Character)
		end
	end
	params.FilterDescendantsInstances = ignored

	-- Segunda búsqueda, solo contra zombies y con una esfera: si el rayo fino pasa rozando a uno, cuenta como acierto
	-- siempre que no haya una pared en medio
	local zombieParams = RaycastParams.new()
	zombieParams.FilterType = Enum.RaycastFilterType.Include
	zombieParams.FilterDescendantsInstances = { workspace.Zombies }

	local unit = direction.Unit
	local hits = {} -- [Humanoid] = { model, damage }
	local endPoints = {}

	for _ = 1, cfg.Pellets do
		local dir = spread(unit, cfg.Spread)
		local result = workspace:Raycast(origin, dir * cfg.Range, params)
		if not (result and result.Instance:IsDescendantOf(workspace.Zombies)) then
			local limit = result and (result.Position - origin).Magnitude or cfg.Range
			local near = workspace:Spherecast(origin, Config.HitTolerance, dir * limit, zombieParams)
			if near then
				result = near
			end
		end
		table.insert(endPoints, result and result.Position or origin + dir * cfg.Range)

		if result then
			local model = result.Instance:FindFirstAncestorWhichIsA("Model")
			local target = model and model:FindFirstChildOfClass("Humanoid")
			-- Fuego amigo desactivado: no se daña a otros jugadores
			if target and target.Health > 0 and not Players:GetPlayerFromCharacter(model) then
				local hit = hits[target]
				if not hit then
					hit = { model = model, damage = 0, crit = false }
					hits[target] = hit
				end
				local crit = isHeadshot(model, origin, dir, (result.Position - origin).Magnitude)
				hit.damage += crit and cfg.Damage * Config.Headshot.Multiplier or cfg.Damage
				hit.crit = hit.crit or crit
			end
		end
	end

	for target, hit in hits do
		target:TakeDamage(hit.damage)
		if hit.crit then
			Remotes.Crit:FireClient(player, target.Health <= 0)
		end
		if target.Health <= 0 and hit.model.Parent == workspace.Zombies then
			Stats.add(player, "Kills")
			Points.add(Config.Points.Kill[hit.model:GetAttribute("Kind")] or 0, player)
		end
	end

	Remotes.Shot:FireAllClients(player, head.Position, endPoints, slot.name)

	if slot.ammo <= 0 then
		startReload(player)
	end
end

local function onSwitch(player, slotName)
	local state = states[player]
	if not state or (slotName ~= "primary" and slotName ~= "pistol") then
		return
	end
	if slotName == "primary" and not state.primary then
		return
	end
	state.current = slotName
	cancelReload(state)
	sendAmmo(player)
end

-- Da un arma principal (de la caja). Reemplaza la anterior y la equipa.
function Weapons.givePrimary(player, name)
	local state = states[player]
	if not state then
		return
	end
	state.primary = newSlot(name)
	state.current = "primary"
	cancelReload(state)
	sendAmmo(player)
end

-- nil si puede comprar munición; si no, el motivo
function Weapons.ammoDenied(player)
	local state = states[player]
	if not state or not state.primary then
		return "Necesitas un arma principal"
	end
	if state.primary.reserve >= Config.Weapons[state.primary.name].MaxReserve then
		return "Ya tienes toda la munición"
	end
	return nil
end

function Weapons.refillReserve(player)
	local state = states[player]
	if state and state.primary then
		state.primary.reserve = Config.Weapons[state.primary.name].MaxReserve
		sendAmmo(player)
	end
end

-- Recarga gratis del punto seguro
function Weapons.refillAll()
	for player, state in states do
		state.pistol.ammo = Config.Weapons.Pistol.MagSize
		if state.primary then
			local cfg = Config.Weapons[state.primary.name]
			state.primary.ammo = cfg.MagSize
			state.primary.reserve = cfg.MaxReserve
		end
		cancelReload(state)
		sendAmmo(player)
	end
end

-- Nueva partida: se pierden las armas principales
function Weapons.resetAll()
	for player, state in states do
		state.primary = nil
		state.current = "pistol"
		state.pistol = newSlot("Pistol")
		cancelReload(state)
		sendAmmo(player)
	end
end

function Weapons.start()
	local function setup(player)
		local state = newState(player)
		states[player] = state

		player.CharacterAdded:Connect(function()
			state.pistol.ammo = Config.Weapons.Pistol.MagSize
			if state.primary then
				state.primary.ammo = Config.Weapons[state.primary.name].MagSize
			end
			cancelReload(state)
			sendAmmo(player)
		end)
		-- Al caer o cargar a alguien cambia el arma activa (solo pistola)
		player:GetAttributeChangedSignal("Carrying"):Connect(function()
			cancelReload(state)
			sendAmmo(player)
		end)
	end

	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	PlayerState.Changed.Event:Connect(function(player)
		local state = states[player]
		if state then
			cancelReload(state)
			sendAmmo(player)
		end
	end)

	Remotes.Fire.OnServerEvent:Connect(onFire)
	Remotes.Reload.OnServerEvent:Connect(startReload)
	Remotes.Switch.OnServerEvent:Connect(onSwitch)
	Remotes.Sync.OnServerEvent:Connect(sendAmmo)
end

return Weapons
