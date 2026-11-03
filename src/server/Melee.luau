-- Golpe cuerpo a cuerpo (tecla X o botón MELEE). Todas las skins (Cosmetics.MeleeSkins) hacen lo mismo: el daño, el alcance y el ritmo
-- salen de Config.Melee; la skin solo cambia el arma que se ve, el gesto de los brazos y el tono del sonido.
-- El servidor decide todo: el cliente solo manda hacia dónde mira. El golpe cae a mitad del gesto (Config.Melee.HitAt) y alcanza a los
-- zombies que estén delante dentro del cono, sin atravesar paredes. Fuego amigo desactivado (solo zombies).
-- Atributos que publica: del jugador `Swinging` (mientras dura el gesto; Weapons no dispara) y del personaje ItemReady / ItemId /
-- ItemStart / ItemEnd con el nombre del gesto (client/ItemPoses), así todos los clientes ven el mismo movimiento.
-- `MeleeSkin` (la skin equipada) la pone server/PlayerProgress al cargar lo guardado.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Items = require(script.Parent.Items)
local MeleeModel = require(script.Parent.MeleeModel)
local PlayerState = require(script.Parent.PlayerState)
local Points = require(script.Parent.Points)
local RateLimit = require(script.Parent.RateLimit)
local Stats = require(script.Parent.Stats)

local M = Config.Melee
local FX = Config.Sounds.Fx

local Melee = {}

local lastSwing = {} -- [Player] = os.clock() del último golpe aceptado

-- Sonido 3D de Config.Sounds.Fx.<key> sobre `parent`, con el tono de la skin
local function playAt(parent, key, skin, volumeScale, pitchScale)
	local def = FX[key]
	if not def or not parent then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = def[1]
	sound.Volume = def[2] * skin.Volume * (volumeScale or 1)
	sound.PlaybackSpeed = (def[3] or 1) * skin.Pitch * (pitchScale or 1)
	sound.RollOffMaxDistance = 70
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 3)
end

local function skinOf(player)
	return Cosmetics.melee(player:GetAttribute("MeleeSkin")) or Cosmetics.melee(Cosmetics.DefaultMelee)
end

-- Zombies que alcanza el golpe: delante (dentro del cono), a tiro y sin pared en medio. Los más cercanos primero.
local function targets(character, origin, direction)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.001 then
		return {}
	end
	flat = flat.Unit
	local minDot = math.cos(math.rad(M.Arc / 2))

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignored = { workspace.Zombies }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignored, other.Character)
		end
	end
	params.FilterDescendantsInstances = ignored

	local found = {}
	for _, model in workspace.Zombies:GetChildren() do
		local root = model:FindFirstChild("HumanoidRootPart")
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local delta = root.Position - origin
			local flatDelta = Vector3.new(delta.X, 0, delta.Z)
			local distance = flatDelta.Magnitude
			-- un poco más de alcance: el zombie tiene cuerpo, y en pantalla va algo por detrás del servidor
			if distance <= M.Range + 1.5 and math.abs(delta.Y) <= 6 then
				local inCone = distance < 1.5 or flatDelta.Unit:Dot(flat) >= minDot
				if inCone and not workspace:Raycast(origin, delta, params) then
					table.insert(found, { model = model, humanoid = humanoid, root = root, distance = distance })
				end
			end
		end
	end
	table.sort(found, function(a, b)
		return a.distance < b.distance
	end)
	return found
end

local function strike(player, character, origin, direction, skin)
	local damage = M.Damage * (player:GetAttribute("FxDamage") or 1) -- jeringa Furia (server/Pharmacy)
	local count = 0
	for _, z in targets(character, origin, direction) do
		if count >= M.MaxTargets then
			break
		end
		count += 1
		z.humanoid:TakeDamage(damage)
		playAt(z.root, "ZombieHit", skin, 1.2)
		if z.humanoid.Health <= 0 and z.model.Parent == workspace.Zombies then
			Stats.add(player, "Kills")
			Points.add(Config.Points.Kill[z.model:GetAttribute("Kind")] or 0, player)
		end
	end
end

local function onMelee(player, direction)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root) or humanoid.Health <= 0 then
		return
	end
	if typeof(direction) ~= "Vector3" or direction.X ~= direction.X or direction.Z ~= direction.Z or direction.Magnitude < 0.001 then
		return
	end
	-- Solo con el equipo en orden: de pie, sin cargar a nadie y sin otro gesto en curso (objeto en la mano, curarse, inyectarse)
	if PlayerState.get(player) ~= "Normal" or player:GetAttribute("Carrying") ~= nil then
		return
	end
	if player:GetAttribute("ItemReady") or player:GetAttribute("HealingEnd") or player:GetAttribute("Injecting") or player:GetAttribute("Swinging") then
		return
	end
	local now = os.clock()
	if now - (lastSwing[player] or 0) < M.Cooldown * 0.9 then
		return
	end
	lastSwing[player] = now

	local skin = skinOf(player)
	local restore = MeleeModel.hold(player, skin.Id)
	player:SetAttribute("Swinging", true)
	character:SetAttribute("ItemReady", skin.Style)
	Items.announce(character, skin.Style, M.Duration)
	playAt(root, "Select", skin, 1, 1.6) -- el silbido del golpe (provisional: el mismo sonido de interfaz, agudo)

	task.delay(M.Duration * M.HitAt, function()
		if character.Parent and humanoid.Health > 0 and PlayerState.get(player) == "Normal" then
			strike(player, character, root.Position, direction, skin)
		end
	end)
	task.delay(M.Duration + 0.05, function()
		if restore then
			restore()
		end
		if character.Parent then
			character:SetAttribute("ItemReady", nil)
		end
		player:SetAttribute("Swinging", nil)
	end)
end

function Melee.start()
	Remotes.Melee.OnServerEvent:Connect(RateLimit.wrap("Melee", 0.2, onMelee))
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
	end)
end

return Melee
