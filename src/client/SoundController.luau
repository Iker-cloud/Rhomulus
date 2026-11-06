-- Sonido del cliente: disparos y recargas, gruñidos 3D de zombies y música dinámica por estado.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local S = Config.Sounds

local SoundController = {}

function SoundController.play2D(soundId, volume, pitch)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 6)
end

-- Suena desde una posición del mundo (se oye de dónde viene)
local function play3D(soundId, position, volume, pitch)
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
	sound.PlaybackSpeed = pitch or 1
	sound.RollOffMinDistance = 15
	sound.RollOffMaxDistance = 200
	sound.Parent = part

	part.Parent = workspace
	sound:Play()
	Debris:AddItem(part, 6)
end

-- Cada zombie gruñe de vez en cuando desde su cuerpo
local function watchZombie(model)
	local root = model:WaitForChild("HumanoidRootPart", 5)
	local humanoid = model:WaitForChild("Humanoid", 5)
	if not (root and humanoid) then
		return
	end
	local kind = model:GetAttribute("Kind")
	local fast = kind == "Fast"
	local tank = kind == "Tank"

	task.spawn(function()
		task.wait(math.random() * 3)
		while humanoid.Health > 0 and model.Parent do
			local sound = Instance.new("Sound")
			sound.SoundId = S.ZombieGrowls[math.random(#S.ZombieGrowls)]
			sound.Volume = S.Volume.Zombie
			sound.PlaybackSpeed = fast and 1.25 or (tank and 0.6 or (0.9 + math.random() * 0.2))
			sound.RollOffMinDistance = 8
			sound.RollOffMaxDistance = 80
			sound.Parent = root
			sound:Play()
			Debris:AddItem(sound, 6)
			task.wait(4 + math.random() * 5)
		end
	end)
end

-- Música: una pista por estado, con fundido entre ellas
local function startMusic()
	local tracks = {}
	for name, soundId in S.Music do
		local sound = Instance.new("Sound")
		sound.Name = "Music" .. name
		sound.SoundId = soundId
		sound.Looped = true
		sound.Volume = 0
		sound.Parent = SoundService
		sound:Play()
		tracks[name] = sound
	end

	local current = "Calm"
	local lastHorde = -math.huge

	local function nearbyZombies()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local folder = workspace:FindFirstChild("Zombies")
		if not (root and folder) then
			return 0
		end
		local count = 0
		for _, zombie in folder:GetChildren() do
			local zRoot = zombie:FindFirstChild("HumanoidRootPart")
			if zRoot and (zRoot.Position - root.Position).Magnitude <= S.HordeNearDistance then
				count += 1
			end
		end
		return count
	end

	task.spawn(function()
		while true do
			local stage = workspace:GetAttribute("Stage")
			if stage == "Lobby" or stage == "Vote" or stage == "SafeRoom" or stage == "WaveBreak" or stage == "Result" or stage == nil then
				current = "Calm"
			elseif stage == "Extraction" and workspace:GetAttribute("ExtractionEnd") then
				current = "Extraction"
			else
				if nearbyZombies() >= S.HordeNearCount then
					lastHorde = os.clock()
				end
				current = (os.clock() - lastHorde < S.HordeMusicHold) and "Horde" or "Tension"
			end
			task.wait(0.5)
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		for name, sound in tracks do
			local target = name == current and S.MusicVolume or 0
			sound.Volume += (target - sound.Volume) * math.min(1, dt * 1.2)
		end
	end)
end

function SoundController.start()
	startMusic()

	Remotes.Shot.OnClientEvent:Connect(function(shooter, from, _endPoints, weaponKey)
		local soundId = S.Shot[weaponKey]
		if not soundId then
			return
		end
		if shooter == player then
			SoundController.play2D(soundId, S.Volume.Shot, S.ShotPitch[weaponKey])
		else
			play3D(soundId, from, S.Volume.Shot, S.ShotPitch[weaponKey])
		end
	end)

	local wasReloading = false
	Remotes.AmmoUpdate.OnClientEvent:Connect(function(_ammo, _reserve, _magSize, reloading, weaponName)
		if reloading and not wasReloading then
			local soundId = weaponName == Config.Weapons.Shotgun.Name and S.ReloadShotgun or S.Reload
			SoundController.play2D(soundId, S.Volume.Reload)
		end
		wasReloading = reloading
	end)

	local zombies = workspace:WaitForChild("Zombies")
	zombies.ChildAdded:Connect(watchZombie)
	for _, zombie in zombies:GetChildren() do
		task.spawn(watchZombie, zombie)
	end
end

return SoundController
