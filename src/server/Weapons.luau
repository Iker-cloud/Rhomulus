-- Autoridad de armas: valida cada disparo, hace el raycast y aplica el daño.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local WEAPON = Config.Weapons.Pistol

local states = {} -- [Player] = { ammo, reloading, lastShot, token }

local Weapons = {}

local function isValidVector(v)
	return typeof(v) == "Vector3" and v.X == v.X and v.Y == v.Y and v.Z == v.Z
end

local function sendAmmo(player)
	local state = states[player]
	if state then
		Remotes.AmmoUpdate:FireClient(player, state.ammo, WEAPON.MagSize, state.reloading)
	end
end

local function resetState(player)
	local state = states[player]
	state.ammo = WEAPON.MagSize
	state.reloading = false
	state.token += 1 -- cancela cualquier recarga en curso
	sendAmmo(player)
end

local function startReload(player)
	local state = states[player]
	if not state or state.reloading or state.ammo >= WEAPON.MagSize then
		return
	end
	state.reloading = true
	state.token += 1
	local token = state.token
	sendAmmo(player)

	task.delay(WEAPON.ReloadTime, function()
		if states[player] ~= state or state.token ~= token then
			return
		end
		state.ammo = WEAPON.MagSize
		state.reloading = false
		sendAmmo(player)
	end)
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
	local now = os.clock()
	if now - state.lastShot < WEAPON.FireCooldown * 0.9 then
		return
	end
	if state.reloading then
		return
	end
	if state.ammo <= 0 then
		startReload(player)
		return
	end

	state.lastShot = now
	state.ammo -= 1
	sendAmmo(player)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local unit = direction.Unit
	local result = workspace:Raycast(origin, unit * WEAPON.Range, params)
	local endPos = result and result.Position or origin + unit * WEAPON.Range

	if result then
		local model = result.Instance:FindFirstAncestorWhichIsA("Model")
		local target = model and model:FindFirstChildOfClass("Humanoid")
		-- Fuego amigo desactivado: no se daña a otros jugadores
		if target and target.Health > 0 and not Players:GetPlayerFromCharacter(model) then
			target:TakeDamage(WEAPON.Damage)
		end
	end

	Remotes.Shot:FireAllClients(player, head.Position, endPos)

	if state.ammo <= 0 then
		startReload(player)
	end
end

function Weapons.start()
	local function setup(player)
		states[player] = { ammo = WEAPON.MagSize, reloading = false, lastShot = 0, token = 0 }
		player.CharacterAdded:Connect(function()
			resetState(player)
		end)
	end

	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	Remotes.Fire.OnServerEvent:Connect(onFire)
	Remotes.Reload.OnServerEvent:Connect(startReload)
	Remotes.Sync.OnServerEvent:Connect(sendAmmo)
end

return Weapons
