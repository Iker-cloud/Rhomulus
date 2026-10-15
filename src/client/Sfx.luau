-- Sonidos de juego del cliente (combate, equipo, mundo e interfaz). Los definidos en Config.Sounds.Fx se piden por nombre con
-- Sfx.play (2D) o Sfx.play3D (desde una posición). Lo que pasa en la partida se escucha aquí mismo a partir de los atributos y
-- avisos que ya llegan al cliente: no hace falta que el servidor mande nada nuevo.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local FX = Config.Sounds.Fx
local player = Players.LocalPlayer

local Sfx = {}

local lastPlayed = {} -- [clave] = os.clock(): evita que un mismo sonido se apile
local function throttled(key, gap)
	local now = os.clock()
	if now - (lastPlayed[key] or -math.huge) < gap then
		return true
	end
	lastPlayed[key] = now
	return false
end

-- Una definición puede ser { id, volumen, tono } o una lista de ellas (suena una al azar)
local function pick(key)
	local def = FX[key]
	if not def then
		return nil
	end
	if type(def[1]) == "table" then
		return def[math.random(#def)]
	end
	return def
end

local function make(def, parent)
	local sound = Instance.new("Sound")
	sound.SoundId = def[1]
	sound.Volume = def[2]
	sound.PlaybackSpeed = def[3] or 1
	sound.Parent = parent
	return sound
end

local function start(sound, def)
	sound:Play()
	if def.clip then
		task.delay(def.clip, function()
			if sound.Parent then
				sound:Stop()
			end
		end)
	end
	Debris:AddItem(sound, (def.clip or 8) + 1)
end

-- Suena en la cabeza del jugador. Si el sonido es una lista (Victory, Defeat), suenan todos a la vez.
function Sfx.play(key, gap)
	if gap and throttled(key, gap) then
		return
	end
	local def = FX[key]
	if not def then
		return
	end
	if type(def[1]) == "table" and (key == "Victory" or key == "Defeat") then
		for _, one in def do
			start(make(one, SoundService), one)
		end
		return
	end
	def = pick(key)
	start(make(def, SoundService), def)
end

-- Suena desde un punto del mundo (se oye de dónde viene)
function Sfx.play3D(key, position, gap)
	local def = pick(key)
	if not def or (gap and throttled(key .. tostring(position // 12), gap)) then
		return
	end
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Position = position
	local sound = make(def, part)
	sound.RollOffMinDistance = 12
	sound.RollOffMaxDistance = 160
	part.Parent = workspace
	start(sound, def)
	Debris:AddItem(part, (def.clip or 8) + 1)
end

-- Zombies: golpe al herirlos, rugido del Tanque al aparecer y caída al morir (3D) --------------------------------------------------
local function watchZombie(model)
	local root = model:WaitForChild("HumanoidRootPart", 5)
	local humanoid = model:WaitForChild("Humanoid", 5)
	if not (root and humanoid) then
		return
	end
	local tank = model:GetAttribute("Kind") == "Tank"
	if tank then
		Sfx.play3D("TankRoar", root.Position)
	end

	local health = humanoid.Health
	humanoid.HealthChanged:Connect(function(value)
		if value < health and value > 0 then
			Sfx.play3D("ZombieHit", root.Position, 0.08)
		end
		health = value
	end)

	local dead = false
	local function died()
		if dead or not model:GetAttribute("DeadAt") then
			return
		end
		dead = true
		Sfx.play3D(tank and "TankDeath" or "ZombieDeath", root.Position)
	end
	model:GetAttributeChangedSignal("DeadAt"):Connect(died)
	died()
end

-- El jugador: golpes recibidos, caída, levantarse y cargar o soltar ------------------------------------------------------------------
local function watchPlayer()
	local lastState = player:GetAttribute("State") or "Normal"
	player:GetAttributeChangedSignal("State"):Connect(function()
		local state = player:GetAttribute("State") or "Normal"
		if state == "Downed" and lastState ~= "Downed" then
			Sfx.play("Down")
		elseif state == "Normal" and lastState == "Downed" then
			Sfx.play("Revived")
		end
		lastState = state
	end)

	local carrying = player:GetAttribute("Carrying") ~= nil
	player:GetAttributeChangedSignal("Carrying"):Connect(function()
		local now = player:GetAttribute("Carrying") ~= nil
		if now and not carrying then
			Sfx.play("Carry")
		elseif carrying and not now then
			Sfx.play("Drop")
		end
		carrying = now
	end)

	local function watchCharacter(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid then
			return
		end
		local health = humanoid.Health
		humanoid.HealthChanged:Connect(function(value)
			-- Solo cuenta un golpe de verdad: curarse o caer (la vida baja a 1) no suena como golpe
			if value < health and value > 1 and (player:GetAttribute("State") or "Normal") == "Normal" then
				Sfx.play("Hurt", 0.35)
			end
			health = value
		end)
	end
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
end

-- La partida: latas, generador, radio, cuenta atrás de la furgoneta y final ----------------------------------------------------------
local function watchWorld()
	local points = workspace:GetAttribute("Points") or 0
	workspace:GetAttributeChangedSignal("Points"):Connect(function()
		local value = workspace:GetAttribute("Points") or 0
		if value > points then
			Sfx.play("Coin", 0.1)
		elseif value < points then
			Sfx.play("Buy", 0.1)
		end
		points = value
	end)

	-- Tone es la orden de la radio que se está mostrando: "Warning" = el generador acaba de arrancar, "Hold" = se llamó a la radio
	local tone = workspace:GetAttribute("Tone")
	workspace:GetAttributeChangedSignal("Tone"):Connect(function()
		local now = workspace:GetAttribute("Tone")
		if now ~= tone then
			if now == "Warning" then
				Sfx.play("Generator")
			elseif now == "Hold" then
				Sfx.play("Radio")
			end
		end
		tone = now
	end)

	-- Cuenta atrás: suena una vez cuando faltan los últimos segundos para la furgoneta
	local counted = nil -- hora de llegada para la que ya sonó
	task.spawn(function()
		while true do
			local arrival = workspace:GetAttribute("ExtractionEnd")
			if arrival and arrival ~= counted then
				local remaining = arrival - workspace:GetServerTimeNow()
				if remaining > 0 and remaining <= 3.8 then
					counted = arrival
					Sfx.play("Countdown")
				end
			end
			task.wait(0.2)
		end
	end)

	Remotes.Results.OnClientEvent:Connect(function(won)
		Sfx.play(won and "Victory" or "Defeat")
	end)

	-- Prueba de acción al revivir: ("result", acertó)
	Remotes.SkillCheck.OnClientEvent:Connect(function(kind, ok)
		if kind == "result" then
			Sfx.play(ok and "SkillOk" or "SkillFail")
		end
	end)
end

function Sfx.start()
	watchPlayer()
	watchWorld()
	local zombies = workspace:WaitForChild("Zombies")
	zombies.ChildAdded:Connect(watchZombie)
	for _, zombie in zombies:GetChildren() do
		task.spawn(watchZombie, zombie)
	end
end

return Sfx
