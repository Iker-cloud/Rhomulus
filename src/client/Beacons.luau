-- Balizas (cliente): luces que parpadean a ritmo fijo, como las de una pista o las de obstáculo de una torre. Son piezas con la
-- etiqueta "Beacon" que ponen los constructores de mapa, con los atributos Period (segundos del ciclo), Phase (0 a 1: dos
-- balizas con fases 0 y 0,5 se alternan) y Duty (fracción del ciclo encendida). Van con el reloj del servidor, así todos las ven
-- igual. Encendida: neón con su color y su luz (si tiene); apagada: plástico oscuro y sin luz.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Beacons = {}

local DARK = Color3.fromRGB(40, 38, 36)
local beacons = {} -- [pieza] = { color, light, on }

local function register(part)
	if beacons[part] then
		return
	end
	beacons[part] = { color = part.Color, light = part:FindFirstChildWhichIsA("Light"), on = true }
end

local function update()
	local now = workspace:GetServerTimeNow()
	for part, data in beacons do
		local period = part:GetAttribute("Period") or 1.2
		local phase = part:GetAttribute("Phase") or 0
		local duty = part:GetAttribute("Duty") or 0.5
		local on = ((now / period + phase) % 1) < duty
		if on ~= data.on then
			data.on = on
			part.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
			part.Color = on and data.color or DARK
			if data.light then
				data.light.Enabled = on
			end
		end
	end
end

function Beacons.start()
	CollectionService:GetInstanceAddedSignal("Beacon"):Connect(register)
	CollectionService:GetInstanceRemovedSignal("Beacon"):Connect(function(part)
		beacons[part] = nil
	end)
	for _, part in CollectionService:GetTagged("Beacon") do
		register(part)
	end
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 1 / 15 then
			elapsed = 0
			update()
		end
	end)
end

return Beacons
