-- Detecta clic (disparar, mantener si el arma es automática), R (recargar) y 1/2/Q (cambiar de arma).
-- El servidor decide si el tiro da y cuánto daño hace.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Shooting = {}

local weaponName = "Pistola" -- nombre del arma activa (lo manda el servidor)
local firing = false
local lastShot = 0
local slot = "pistol"

local function activeConfig()
	for _, cfg in Config.Weapons do
		if cfg.Name == weaponName then
			return cfg
		end
	end
	return Config.Weapons.Pistol
end

local function drawTracers(_shooter, from, endPoints)
	for _, to in endPoints do
		local length = (to - from).Magnitude
		local tracer = Instance.new("Part")
		tracer.Anchored = true
		tracer.CanCollide = false
		tracer.CanQuery = false
		tracer.CanTouch = false
		tracer.Material = Enum.Material.Neon
		tracer.Color = Color3.fromRGB(255, 220, 120)
		tracer.Size = Vector3.new(0.1, 0.1, length)
		tracer.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
		tracer.Parent = workspace
		Debris:AddItem(tracer, 0.06)
	end
end

local function fire()
	lastShot = os.clock()
	-- El disparo sale del centro de la pantalla
	local camera = workspace.CurrentCamera
	local size = camera.ViewportSize
	local ray = camera:ViewportPointToRay(size.X / 2, size.Y / 2)
	Remotes.Fire:FireServer(ray.Origin, ray.Direction)
end

local function switchTo(newSlot)
	slot = newSlot
	Remotes.Switch:FireServer(newSlot)
end

function Shooting.start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			firing = true
			fire()
		elseif input.KeyCode == Enum.KeyCode.R then
			Remotes.Reload:FireServer()
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
			firing = false
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

	Remotes.AmmoUpdate.OnClientEvent:Connect(function(_ammo, _reserve, _magSize, _reloading, name)
		weaponName = name
	end)
	Remotes.Shot.OnClientEvent:Connect(drawTracers)
end

return Shooting
