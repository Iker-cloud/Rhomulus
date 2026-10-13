-- Mira: punto central y un aro que muestra la dispersión del arma (la base más el bloom al disparar seguido; ver Config.Weapons.Bloom
-- y server/Weapons). La munición está en AmmoHud y la vida en HealthHud.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer

local Hud = {}

function Hud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	local crosshair = Instance.new("Frame")
	crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.Position = UDim2.fromScale(0.5, 0.5)
	crosshair.Size = UDim2.fromOffset(6, 6)
	crosshair.BackgroundColor3 = Color3.new(1, 1, 1)
	crosshair.BorderSizePixel = 0
	crosshair.Parent = gui
	Instance.new("UICorner", crosshair).CornerRadius = UDim.new(1, 0)

	-- Aro de dispersión
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromOffset(0, 0)
	ring.BackgroundTransparency = 1
	ring.Visible = false
	ring.Parent = gui
	Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.35
	stroke.Parent = ring

	local shown = 0 -- radio dibujado (suaviza los cambios)
	RunService.RenderStepped:Connect(function(dt)
		local cfg = Config.Weapons[player:GetAttribute("WeaponKey") or "Pistol"]
		local total = 0
		if cfg then
			total = cfg.Spread
			local bloom = cfg.Bloom
			local value, since = player:GetAttribute("BloomValue"), player:GetAttribute("BloomTime")
			if bloom and value and since then
				total += math.max(0, value - bloom.Recover * (workspace:GetServerTimeNow() - since))
			end
		end
		-- grados -> píxeles: el rayo se abre `total` grados desde el centro de la pantalla
		local camera = workspace.CurrentCamera
		local pixelsPerRadian = camera.ViewportSize.Y / 2 / math.tan(math.rad(camera.FieldOfView) / 2)
		local target = math.tan(math.rad(total)) * pixelsPerRadian
		shown += (target - shown) * math.min(1, dt * 18)
		local visible = shown > 4
		ring.Visible = visible
		if visible then
			ring.Size = UDim2.fromOffset(shown * 2, shown * 2)
		end
	end)
end

return Hud
