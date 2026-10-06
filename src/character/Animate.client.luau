-- Animación de los sobrevivientes. Al llamarse "Animate" reemplaza al script por defecto de Roblox.
-- Usa el paquete de animaciones de Config.Animations.Survivor (tensas, como si los persiguieran).
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")
local anims = Config.Animations.Survivor

local function load(id, priority, looped)
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	ContentProvider:PreloadAsync({ animation })
	local track = animator:LoadAnimation(animation)
	track.Priority = priority
	track.Looped = looped
	return track
end

local idle = load(anims.Idle, Enum.AnimationPriority.Idle, true)
local walk = load(anims.Walk, Enum.AnimationPriority.Movement, true)
local run = load(anims.Run, Enum.AnimationPriority.Movement, true)
local jump = load(anims.Jump, Enum.AnimationPriority.Action, false)
local fall = load(anims.Fall, Enum.AnimationPriority.Action, true)

local moveTracks = { walk, run }
local current = nil

local function play(track, speed)
	if current ~= track then
		if current then
			current:Stop(0.15)
		end
		current = track
		track:Play(0.15)
	end
	if speed then
		track:AdjustSpeed(speed)
	end
end

-- Quieto, caminar (agachado, lento: caído o cargando) o correr
humanoid.Running:Connect(function(speed)
	if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
		return
	end
	if speed < 0.5 then
		play(idle)
	elseif speed > Config.Animations.RunSpeed then
		play(run, math.clamp(speed / 16, 0.6, 1.4))
	else
		play(walk, math.clamp(speed / 8, 0.6, 1.4))
	end
end)

humanoid.StateChanged:Connect(function(_, state)
	if state == Enum.HumanoidStateType.Jumping then
		play(jump)
	elseif state == Enum.HumanoidStateType.Freefall then
		play(fall)
	elseif state == Enum.HumanoidStateType.Landed then
		play(idle)
	end
end)

humanoid.Died:Connect(function()
	for _, track in animator:GetPlayingAnimationTracks() do
		track:Stop(0.2)
	end
end)

play(idle)
