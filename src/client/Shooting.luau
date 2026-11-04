-- Detecta clic (disparar, mantener si el arma es automática), R (recargar), 1/2/Q (cambiar de arma) y X (golpe cuerpo a cuerpo).
-- El servidor decide si el tiro da y cuánto daño hace.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Players = game:GetService("Players")
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SoundController = require(script.Parent.SoundController)
local WeaponAnimator = require(script.Parent.WeaponAnimator)

local TRACER_LENGTH = 3 -- studs que mide el destello
local TRACER_WIDTH = 0.05
local TRACER_SPEED = 600 -- studs por segundo

local Shooting = {}

local weaponName = "Pistol" -- nombre del arma activa (lo manda el servidor)
local firing = false
local lastShot = 0
local slot = "pistol"
local ammo, reloading = 1, false -- último estado que mandó el servidor

local function activeConfig()
	for _, cfg in Config.Weapons do
		if cfg.Name == weaponName then
			return cfg
		end
	end
	return Config.Weapons.Pistol
end

-- Trazador: un destello corto que viaja desde la boca del cañón hasta donde pegó la bala
local function drawTracers(shooter, from, endPoints)
	local origin = WeaponAnimator.muzzlePosition(shooter and shooter.Character) or from
	for _, to in endPoints do
		local length = (to - origin).Magnitude
		if length > 1 then
			local dash = math.min(TRACER_LENGTH, length)
			local direction = (to - origin).Unit
			local tracer = Instance.new("Part")
			tracer.Anchored = true
			tracer.CanCollide = false
			tracer.CanQuery = false
			tracer.CanTouch = false
			tracer.CastShadow = false
			tracer.Material = Enum.Material.Neon
			tracer.Color = Color3.fromRGB(255, 225, 140)
			tracer.Size = Vector3.new(TRACER_WIDTH, TRACER_WIDTH, dash)
			-- el centro del destello recorre el trayecto, sin salirse por delante del impacto
			local startCF = CFrame.lookAt(origin + direction * (dash / 2), to)
			local endCF = CFrame.lookAt(to - direction * (dash / 2), to)
			tracer.CFrame = startCF
			tracer.Parent = workspace
			local travel = math.clamp(length / TRACER_SPEED, 0.03, 0.2)
			local tween = TweenService:Create(tracer, TweenInfo.new(travel, Enum.EasingStyle.Linear), { CFrame = endCF })
			tween:Play()
			Debris:AddItem(tracer, travel + 0.02)
		end
	end
end

-- Con un objeto en la mano (client/ItemUse) el clic y R no son del arma
local function itemInHand()
	return Players.LocalPlayer:GetAttribute("ItemReady") ~= nil
end

local function fire()
	lastShot = os.clock()
	if ammo <= 0 and not reloading then
		SoundController.play2D(Config.Sounds.DryFire, Config.Sounds.Volume.DryFire)
	end
	-- El disparo sale del centro de la pantalla
	local camera = workspace.CurrentCamera
	local size = camera.ViewportSize
	local ray = camera:ViewportPointToRay(size.X / 2, size.Y / 2)
	-- La sacudida de cámara del retroceso es solo visual: se apunta con la cámara sin ella
	Remotes.Fire:FireServer(ray.Origin, WeaponAnimator.cameraCFrame().LookVector)
end

local function switchTo(newSlot)
	slot = newSlot
	Remotes.Switch:FireServer(newSlot)
end

-- ¿Está recargando? (Sprint cancela la carrera mientras tanto)
function Shooting.isReloading()
	return reloading
end

-- Acciones que comparten el ratón y los botones del celular (client/TouchControls)
function Shooting.setFiring(on)
	if not on then
		firing = false
	elseif not itemInHand() then
		firing = true
		fire()
	end
end

function Shooting.reload()
	if not itemInHand() then
		Remotes.Reload:FireServer()
	end
end

-- Golpe cuerpo a cuerpo (tecla X y botón MELEE): el servidor decide si cabe y a quién alcanza
function Shooting.melee()
	if not itemInHand() then
		Remotes.Melee:FireServer(WeaponAnimator.cameraCFrame().LookVector)
	end
end

function Shooting.switchTo(newSlot)
	switchTo(newSlot)
end

function Shooting.start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if itemInHand() then
				return
			end
			firing = true
			fire()
		elseif input.KeyCode == Enum.KeyCode.R then
			if not itemInHand() then
				Remotes.Reload:FireServer()
			end
		elseif input.KeyCode == Enum.KeyCode.X then
			Shooting.melee()
		elseif input.KeyCode == Enum.KeyCode.One then
			switchTo("primary")
		elseif input.KeyCode == Enum.KeyCode.Two then
			switchTo("pistol")
		elseif input.KeyCode == Enum.KeyCode.Q then
			switchTo(slot == "pistol" and "primary" or "pistol")
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			Shooting.setFiring(false)
		end
	end)

	-- Armas automáticas: seguir disparando mientras se mantiene el clic
	RunService.Heartbeat:Connect(function()
		if firing then
			local cfg = activeConfig()
			if cfg.Auto and os.clock() - lastShot >= cfg.FireCooldown then
				fire()
			end
		end
	end)

	Remotes.AmmoUpdate.OnClientEvent:Connect(function(newAmmo, _reserve, _magSize, isReloading, name)
		ammo, reloading = newAmmo, isReloading
		weaponName = name
	end)
	Remotes.Shot.OnClientEvent:Connect(drawTracers)
end

return Shooting
