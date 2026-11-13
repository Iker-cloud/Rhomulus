-- Cosas del mapa que se mueven (cliente, solo se ve; el servidor no las mueve). Cada pieza lleva una etiqueta y sus atributos:
--   Spin       gira sobre su eje Y: Speed (grados por segundo). Radar de la torre, ventiladores.
--   Shuttle    va y vuelve entre A y B (Vector3) a Speed studs por segundo. La maleta que sigue en la cinta.
--   Drift      papel que se lleva el viento: avanza Length studs en Dir a Speed, dando tumbos, y vuelve a empezar. Phase (0..1).
--   Swing      se balancea: Amplitude (grados) y Period (s) alrededor de su eje X; al llegar al tope golpea (sonido). Persianas.
--   SparkCable echa chispas cada pocos segundos (su ParticleEmitter con Rate 0) con chispazo.
--   FlightBoard pantalla de vuelos: de vez en cuando parpadea y cambia el estado de una línea (TextLabel "Status").
-- Solo se animan las cercanas a la cámara (Range) para no gastar en celular.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local MapMotion = {}

local RANGE = 170
local STATUSES = { "CANCELLED", "CANCELLED", "DELAYED", "LAST CALL", "GATE CLOSED", "------", "BOARDING", "NO CONTACT" }

local items = {} -- [pieza] = { kind, base, phase, ... }

local KINDS = { "Spin", "Shuttle", "Drift", "Swing", "SparkCable", "FlightBoard" }

local function playAt(part, soundId, volume, pitch)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.PlaybackSpeed = pitch
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = 90
	sound.Parent = part
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

local function register(part, kind)
	if items[part] then
		return
	end
	items[part] = {
		kind = kind,
		base = part:IsA("BasePart") and part.CFrame or nil,
		phase = part:GetAttribute("Phase") or math.random(),
		next = os.clock() + 2 + math.random() * 6,
		side = 1,
	}
end

local function update(dt)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local focus = camera.CFrame.Position
	local now = os.clock()
	for part, data in items do
		if not part.Parent then
			items[part] = nil
			continue
		end
		local position = data.base and data.base.Position or (part:IsA("BasePart") and part.Position or focus)
		if (position - focus).Magnitude > RANGE then
			continue
		end
		local kind = data.kind
		if kind == "Spin" then
			local speed = math.rad(part:GetAttribute("Speed") or 60)
			part.CFrame = data.base * CFrame.Angles(0, (now * speed) % (math.pi * 2), 0)
		elseif kind == "Shuttle" then
			local a, b = part:GetAttribute("A"), part:GetAttribute("B")
			local length = (b - a).Magnitude
			local t = (now * (part:GetAttribute("Speed") or 3) / length) % 2
			local alpha = t < 1 and t or 2 - t
			part.CFrame = CFrame.new(a:Lerp(b, alpha)) * (data.base - data.base.Position)
		elseif kind == "Drift" then
			local dir = part:GetAttribute("Dir")
			local length = part:GetAttribute("Length") or 50
			local t = ((now * (part:GetAttribute("Speed") or 8) / length) + data.phase) % 1
			local lift = math.abs(math.sin(t * math.pi * 6)) * 2.2 * math.sin(t * math.pi)
			local spin = now * 4 + data.phase * 10
			part.CFrame = CFrame.new(data.base.Position + dir * (t * length) + Vector3.new(0, lift, 0)) * CFrame.Angles(math.sin(spin) * 1.2, spin, math.cos(spin * 0.7))
		elseif kind == "Swing" then
			local amplitude = math.rad(part:GetAttribute("Amplitude") or 20)
			local period = part:GetAttribute("Period") or 2.4
			local s = math.sin((now / period + data.phase) * math.pi * 2)
			part.CFrame = data.base * CFrame.Angles(s * amplitude, 0, 0)
			local side = s > 0.97 and 1 or (s < -0.97 and -1 or 0)
			if side ~= 0 and side ~= data.side then
				data.side = side
				if side == 1 then
					playAt(part, Config.Sounds.Night.Noises[1], 0.25, 0.7 + math.random() * 0.2)
				end
			end
		elseif kind == "SparkCable" then
			if now >= data.next then
				data.next = now + 2 + math.random() * 5
				local emitter = part:FindFirstChildOfClass("ParticleEmitter")
				if emitter then
					emitter:Emit(math.random(10, 26))
				end
				playAt(part, Config.Sounds.Night.Spark, 0.35, 0.9 + math.random() * 0.4)
			end
		elseif kind == "FlightBoard" then
			local gui = part:FindFirstChildOfClass("SurfaceGui")
			if gui and now >= data.next then
				-- Parpadeo corto y, a veces, una línea cambia de estado
				data.next = now + 1.5 + math.random() * 5
				data.blinkUntil = now + 0.08 + math.random() * 0.25
				if math.random() < 0.6 then
					local labels = {}
					for _, child in gui:GetChildren() do
						if child.Name == "Status" then
							table.insert(labels, child)
						end
					end
					if #labels > 0 then
						local label = labels[math.random(#labels)]
						label.Text = STATUSES[math.random(#STATUSES)]
					end
				end
			end
			if gui then
				gui.Enabled = not (data.blinkUntil and now < data.blinkUntil and (now * 30) % 2 < 1)
			end
		end
	end
end

function MapMotion.start()
	for _, kind in KINDS do
		CollectionService:GetInstanceAddedSignal(kind):Connect(function(part)
			register(part, kind)
		end)
		CollectionService:GetInstanceRemovedSignal(kind):Connect(function(part)
			items[part] = nil
		end)
		for _, part in CollectionService:GetTagged(kind) do
			register(part, kind)
		end
	end
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 1 / 30 then
			update(elapsed)
			elapsed = 0
		end
	end)
end

return MapMotion
