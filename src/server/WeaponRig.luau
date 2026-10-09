-- Armas en el cuerpo de cada sobreviviente (reemplaza al antiguo Holster):
--   "HandWeapon"   el arma activa, en la mano derecha (Motor6D "WeaponGrip"; los clientes animan los brazos con IK)
--   "BackWeapon"   el arma principal a la espalda, mientras se usa la pistola
--   "PistolHolster" la pistola en la cadera, mientras se usa el arma principal
-- Publica el arma activa en el atributo "WeaponKey" del jugador y recibe hacia dónde apunta cada cliente (Aim).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WeaponModel = require(script.Parent.WeaponModel)

local DATA = {
	Pistol = require(script.Parent.ZombieData.Pistola),
	Rifle = require(script.Parent.ZombieData.RifleAsalto),
	Shotgun = require(script.Parent.ZombieData.Escopeta),
	SMG = require(script.Parent.ZombieData.Subfusil),
}
local Hold = Config.WeaponHold

local HOLSTER_SCALE = 0.8
-- Marco de LowerTorso: cadera derecha, hacia afuera de la pierna
local HIP = Vector3.new(1.25, -0.35, 0)
-- Cañón hacia abajo y miras hacia el frente (-Z): el eje X de la pistola apunta a +Y y su eje Y a -Z
local HIP_ORIENTATION = CFrame.fromMatrix(Vector3.zero, Vector3.yAxis, Vector3.new(0, 0, -1), Vector3.new(-1, 0, 0))

local BACK_SCALE = 0.75
-- Marco de UpperTorso: pegada a la espalda, en diagonal (cañón arriba a la izquierda)
local BACK = Vector3.new(0.1, 0.05, 0.62)
local BACK_ORIENTATION = CFrame.fromMatrix(Vector3.zero, Vector3.new(0.35, -0.94, 0).Unit, Vector3.new(0, 0, 1))

local MAX_AIM_PITCH = 1.4
local MIN_AIM_INTERVAL = 0.05

local WeaponRig = {}

local states = {} -- [Player] = { active, primary, shown = { character, hand, back, hip }, busy, dirty }
local lastAim = {} -- [Player] = os.clock() del último Aim aceptado

local function destroyNamed(character, name)
	local old = character:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

-- Arma de adorno soldada a una pieza del cuerpo
local function attachFixed(character, name, key, scale, part, cf)
	destroyNamed(character, name)
	local gun = WeaponModel.build(DATA[key], scale)
	gun.Name = name
	local root = gun.PrimaryPart
	gun:PivotTo(part.CFrame * cf)
	root.Anchored = false
	root.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = root
	weld.Parent = root
	gun.Parent = character
end

local function attachHand(character, hand, key)
	destroyNamed(character, "HandWeapon")
	local hold = Hold[key]
	local data = DATA[key]
	local gun = WeaponModel.build(data, hold.Scale)
	gun.Name = "HandWeapon"
	local root = gun.PrimaryPart
	local center = (data.bounds.min + data.bounds.max) / 2
	local c0 = Hold.HandGrip
	local c1 = CFrame.new((hold.Grip - center) * hold.Scale)
	gun:PivotTo(hand.CFrame * c0 * c1:Inverse())

	-- Fogonazo: una estrella de chispas en la boca del cañón, invisible hasta que el cliente la enciende al disparar.
	-- "Core" marca la boca del cañón (de ahí salen también los trazadores).
	local flash = Instance.new("Model")
	flash.Name = "MuzzleFlash"
	local muzzleCF = root.CFrame * CFrame.new((hold.Muzzle - center) * hold.Scale + Vector3.new(-0.08, 0, 0))
	local function spark(name, size, offset, shape)
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = shape or Enum.PartType.Block
		part.Size = size
		part.Color = Color3.fromRGB(255, 205, 90)
		part.Material = Enum.Material.Neon
		part.Transparency = 1
		part.Massless = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.CFrame = muzzleCF * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = flash
		return part
	end
	local core = spark("Core", Vector3.new(0.22, 0.22, 0.22), CFrame.identity, Enum.PartType.Ball)
	core.Color = Color3.fromRGB(255, 240, 180)
	-- Chispas hacia adelante (se ven de lado) y en abanico alrededor de la boca (se ven desde atrás)
	for _, angle in { 0, 28, -28 } do
		spark("Fwd", Vector3.new(0.9 - math.abs(angle) / 100, 0.07, 0.07), CFrame.Angles(0, 0, math.rad(angle)) * CFrame.new(-0.4, 0, 0))
	end
	spark("FwdSide", Vector3.new(0.7, 0.07, 0.07), CFrame.Angles(math.rad(90), 0, 0) * CFrame.new(-0.3, 0, 0))
	for i = 0, 5 do
		spark("Ring", Vector3.new(0.07, 0.4, 0.07), CFrame.Angles(math.rad(i * 60), 0, 0) * CFrame.new(0, 0.22, 0))
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 190, 90)
	light.Brightness = 3
	light.Range = 10
	light.Enabled = false
	light.Parent = core
	flash.Parent = gun

	root.Anchored = false
	root.Massless = true
	local motor = Instance.new("Motor6D")
	motor.Name = "WeaponGrip"
	motor.Part0 = hand
	motor.Part1 = root
	motor.C0 = c0
	motor.C1 = c1
	motor.Parent = root
	gun.Parent = character
end

local function apply(player, state)
	local character = player.Character
	if not character then
		return
	end
	-- CharacterAdded se dispara antes de que el personaje entre al workspace, y al cargar el avatar Roblox reemplaza
	-- todas las piezas del cuerpo: hay que esperar y buscarlas después, o la soldadura quedaría en una pieza destruida
	local deadline = os.clock() + 10
	while (character.Parent == nil or not player:HasAppearanceLoaded()) and os.clock() < deadline do
		task.wait()
	end
	local hand = character:FindFirstChild("RightHand")
	local upper = character:FindFirstChild("UpperTorso")
	local lower = character:FindFirstChild("LowerTorso")
	if not (hand and upper and lower) or character.Parent == nil or player.Character ~= character then
		return
	end

	local shown = state.shown
	if shown.character ~= character then
		shown = { character = character }
		state.shown = shown
	end

	local active = state.active or "Pistol"
	local primary = state.primary
	local wantBack = active == "Pistol" and primary or nil
	local wantHip = active ~= "Pistol" and "Pistol" or nil

	if shown.hand ~= active then
		attachHand(character, hand, active)
		shown.hand = active
	end
	if shown.back ~= wantBack then
		destroyNamed(character, "BackWeapon")
		if wantBack then
			attachFixed(character, "BackWeapon", wantBack, BACK_SCALE, upper, CFrame.new(BACK) * BACK_ORIENTATION)
		end
		shown.back = wantBack
	end
	if shown.hip ~= wantHip then
		destroyNamed(character, "PistolHolster")
		if wantHip then
			attachFixed(character, "PistolHolster", "Pistol", HOLSTER_SCALE, lower, CFrame.new(HIP) * HIP_ORIENTATION)
		end
		shown.hip = wantHip
	end
end

local function refresh(player)
	local state = states[player]
	if not state then
		return
	end
	if state.busy then
		state.dirty = true
		return
	end
	state.busy = true
	task.spawn(function()
		repeat
			state.dirty = false
			local ok, err = pcall(apply, player, state)
			if not ok then
				warn("WeaponRig:", err)
			end
		until not state.dirty
		state.busy = false
	end)
end

local function stateOf(player)
	local state = states[player]
	if not state then
		state = { active = "Pistol", primary = nil, shown = {}, busy = false, dirty = false }
		states[player] = state
	end
	return state
end

-- Lo llama Weapons cada vez que cambia el arma activa o la principal (claves de Config.Weapons)
function WeaponRig.set(player, active, primary)
	local state = stateOf(player)
	player:SetAttribute("WeaponKey", active)
	player:SetAttribute("PrimaryKey", primary)
	if state.active ~= active or state.primary ~= primary then
		state.active = active
		state.primary = primary
		refresh(player)
	end
end

function WeaponRig.start()
	local function setup(player)
		stateOf(player)
		player.CharacterAdded:Connect(function()
			refresh(player)
		end)
		if player.Character then
			refresh(player)
		end
	end
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		lastAim[player] = nil
	end)

	Remotes.Aim.OnServerEvent:Connect(function(player, pitch, aiming)
		if typeof(pitch) ~= "number" or pitch ~= pitch then
			return
		end
		local character = player.Character
		local now = os.clock()
		if not character or now - (lastAim[player] or 0) < MIN_AIM_INTERVAL then
			return
		end
		lastAim[player] = now
		character:SetAttribute("AimPitch", math.clamp(pitch, -MAX_AIM_PITCH, MAX_AIM_PITCH))
		character:SetAttribute("Aiming", aiming == true)
	end)
end

return WeaponRig
