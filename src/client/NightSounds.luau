-- Sonido de noche (cliente): ambiente de fondo (viento, sirenas lejanas, zumbido), ruidos sueltos cerca del jugador
-- (metal, cristal, caídas, gruñidos, perros lejos) y un latido que sube con zombies cerca o poca vida.
-- Fuera (zonas y extracción) suena todo; en el lobby, el punto seguro y los resultados solo queda el viento, bajo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local A = Config.Atmosphere
local N = Config.Sounds.Night

local NightSounds = {}

local OUTSIDE = { Zone1 = true, Zone2 = true, Zone3 = true, Extraction = true, Wave = true, WaveBreak = true }

local function isOutside()
	return OUTSIDE[workspace:GetAttribute("Stage")] == true
end

local function loop(soundId)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	sound:Play()
	return sound
end

-- Sonido suelto en un punto del mundo (se oye de dónde viene)
local function playAt(soundId, position, volume, pitch)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Position = position
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.PlaybackSpeed = pitch
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = 120
	sound.Parent = part
	part.Parent = workspace
	sound:Play()
	sound.Ended:Once(function()
		part:Destroy()
	end)
	task.delay(15, function()
		if part.Parent then
			part:Destroy()
		end
	end)
end

local function getRoot()
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

-- Cada cierto tiempo, un ruido en un lugar al azar alrededor del jugador
local function noiseLoop()
	local cfg = A.Noises
	while true do
		task.wait(cfg.MinInterval + math.random() * (cfg.MaxInterval - cfg.MinInterval))
		local root = getRoot()
		if root and isOutside() then
			local angle = math.random() * math.pi * 2
			local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local roll = math.random()
			if roll < 0.15 then
				-- Perros ladrando lejos (en otros mapas, lo que diga FarByMap: en el aeropuerto, motores)
				local mapId = workspace:GetAttribute("MapId")
				local far = N.FarByMap[Config.MapTheme[mapId] or mapId] or N.Dogs
				playAt(far, root.Position + direction * 90, A.Volume.Dogs, 0.9 + math.random() * 0.2)
			else
				local distance = cfg.MinDistance + math.random() * (cfg.MaxDistance - cfg.MinDistance)
				local list = roll < 0.45 and Config.Sounds.ZombieGrowls or N.Noises
				local pitch = list == Config.Sounds.ZombieGrowls and 0.75 + math.random() * 0.15 or 0.85 + math.random() * 0.3
				playAt(list[math.random(#list)], root.Position + direction * distance + Vector3.new(0, 2, 0), A.Volume.Noise, pitch)
			end
		end
	end
end

-- Intensidad del latido (0 a 1): zombie vivo más cercano o poca vida
local function heartIntensity()
	local root = getRoot()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or not isOutside() then
		return 0
	end
	local intensity = 0
	if player:GetAttribute("State") == "Downed" then
		intensity = 1
	elseif humanoid.Health < A.Heartbeat.LowHealth then
		intensity = 1 - humanoid.Health / A.Heartbeat.LowHealth
	end
	local zombies = workspace:FindFirstChild("Zombies")
	if zombies then
		for _, zombie in zombies:GetChildren() do
			local zombieHumanoid = zombie:FindFirstChildOfClass("Humanoid")
			if zombieHumanoid and zombieHumanoid.Health > 0 then
				local distance = (zombie:GetPivot().Position - root.Position).Magnitude
				intensity = math.max(intensity, math.clamp(1 - (distance - 6) / (A.Heartbeat.ZombieDistance - 6), 0, 1))
			end
		end
	end
	return intensity
end

function NightSounds.start()
	if not A.Enabled then
		return
	end
	local wind = loop(N.Wind)
	local sirens = loop(N.Sirens)
	local drone = loop(N.Drone)
	local heart = loop(N.Heartbeat)

	-- Sonido por zona: bucles que suben al entrar en su zona y campanas cada cierto tiempo. Cada mapa tiene sus zonas
	-- (Morro Esperanza: N.Zones; los demás: N.ZonesByMap) y se crean la primera vez que se juega ese mapa.
	local zonesByMap = {} -- [id de mapa] = { { zone, level, sound } }
	local function zoneList(mapId)
		return mapId == "Morro" and N.Zones or N.ZonesByMap[mapId]
	end
	local function insideZone(zone)
		local root = getRoot()
		if not root then
			return false
		end
		local p, b = root.Position, zone.box
		return p.X >= b[1] and p.X <= b[2] and p.Z >= b[3] and p.Z <= b[4]
	end

	local function buildZones(mapId)
		local zones = {}
		zonesByMap[mapId] = zones
		for _, zone in zoneList(mapId) do
			local entry = { zone = zone, level = 0 }
			if zone.loop then
				entry.sound = loop(zone.loop)
			end
			table.insert(zones, entry)
			if zone.bell then
				task.spawn(function()
					while true do
						local interval = zone.bellInterval
						task.wait(interval[1] + math.random() * (interval[2] - interval[1]))
						if workspace:GetAttribute("MapId") == mapId and insideZone(zone) then
							playAt(zone.bell, zone.bellPos or Vector3.new(36, 42, 155), zone.bellVolume, 0.85 + math.random() * 0.1)
						end
					end
				end)
			end
		end
	end
	local heartLevel = 0
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.1 then
			return
		end
		local step = elapsed
		elapsed = 0
		local outside = isOutside()
		-- Las capas de fondo entran y salen despacio (unos 2 s)
		local blend = math.min(1, step * 0.5)
		wind.Volume += ((outside and A.Volume.Wind or A.Volume.Wind * 0.35) - wind.Volume) * blend
		sirens.Volume += ((outside and A.Volume.Sirens or 0) - sirens.Volume) * blend
		drone.Volume += ((outside and A.Volume.Drone or 0) - drone.Volume) * blend
		local mapId = workspace:GetAttribute("MapId")
		if mapId and not zonesByMap[mapId] and zoneList(mapId) then
			buildZones(mapId)
		end
		for id, zones in zonesByMap do
			for _, entry in zones do
				if entry.sound then
					entry.level += (((id == mapId and insideZone(entry.zone)) and 1 or 0) - entry.level) * blend
					entry.sound.Volume = entry.level * entry.zone.volume
				end
			end
		end
		-- El latido sube rápido y baja despacio
		local target = heartIntensity()
		heartLevel += (target - heartLevel) * math.min(1, step * (target > heartLevel and 4 or 0.8))
		heart.Volume = heartLevel * A.Volume.Heartbeat
		heart.PlaybackSpeed = 0.9 + heartLevel * 0.5
	end)

	task.spawn(noiseLoop)
end

return NightSounds
