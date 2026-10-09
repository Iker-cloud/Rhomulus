-- Luces de noche (cliente): faroles que parpadean (atributo Flicker), rotos (Broken) y apagones con chispazo
-- (BlackoutUntil, lo pone server/Atmosphere). La linterna propia se inclina con la cámara para alumbrar donde se apunta.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local A = Config.Atmosphere
local DARK = Color3.fromRGB(45, 40, 35) -- foco apagado
local CULL_DISTANCE = 110 -- los faroles más lejos que esto no gastan luz (en celular cada luz cuesta)

local NightLights = {}

local lamps = {} -- [foco] = { light, base, color, on, burst, nextToggle, sparks }

local function setOn(bulb, data, on)
	if data.on == on then
		return
	end
	data.on = on
	data.light.Enabled = on and not data.far
	bulb.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
	bulb.Color = on and data.color or DARK
end

-- Chispas y chispazo al empezar un apagón
local function spark(bulb, data)
	if not data.sparks then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Rate = 0
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 240, 180), Color3.fromRGB(255, 150, 40))
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new(0.25, 0)
		emitter.Speed = NumberRange.new(12, 25)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Lifetime = NumberRange.new(0.3, 0.7)
		emitter.Acceleration = Vector3.new(0, -60, 0)
		emitter.Parent = bulb
		data.sparks = emitter
	end
	data.sparks:Emit(30)
	local sound = Instance.new("Sound")
	sound.SoundId = Config.Sounds.Night.Spark
	sound.Volume = A.Volume.Spark
	sound.PlaybackSpeed = 0.9 + math.random() * 0.3
	sound.RollOffMaxDistance = 90
	sound.Parent = bulb
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	-- Destello antes de morir
	data.light.Brightness = data.base * 3
	task.delay(0.08, function()
		data.light.Brightness = data.base
	end)
end

local function register(bulb)
	local light = bulb:FindFirstChildWhichIsA("Light") or bulb:WaitForChild("Luz", 10)
	if not light or lamps[bulb] then
		return
	end
	local data = { light = light, base = light.Brightness, color = bulb.Color, on = true, burst = 0, nextToggle = 0 }
	lamps[bulb] = data
	bulb:GetAttributeChangedSignal("BlackoutUntil"):Connect(function()
		if (bulb:GetAttribute("BlackoutUntil") or 0) > workspace:GetServerTimeNow() then
			spark(bulb, data)
		end
	end)
end

local function update()
	local now = workspace:GetServerTimeNow()
	local clock = os.clock()
	local cameraPosition = workspace.CurrentCamera.CFrame.Position
	for bulb, data in lamps do
		local far = (bulb.Position - cameraPosition).Magnitude > CULL_DISTANCE
		if far ~= data.far then
			data.far = far
			data.light.Enabled = data.on and not far
		end
		if bulb:GetAttribute("Broken") or (bulb:GetAttribute("BlackoutUntil") or 0) > now then
			setOn(bulb, data, false)
		elseif bulb:GetAttribute("Flicker") then
			-- Encendido estable unos segundos y luego una ráfaga de parpadeos rápidos
			if clock >= data.nextToggle then
				if data.burst > 0 then
					data.burst -= 1
					setOn(bulb, data, not data.on)
					data.nextToggle = clock + 0.04 + math.random() * 0.1
				else
					setOn(bulb, data, true)
					data.burst = math.random(3, 8) * 2
					data.nextToggle = clock + 1 + math.random() * 3.5
				end
			end
		else
			setOn(bulb, data, true)
		end
	end
end

-- La linterna propia apunta a donde mira la cámara (los demás la ven a la altura de la cabeza)
local function aimFlashlight()
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local attachment = head and head:FindFirstChild("Linterna")
	if attachment then
		local look = workspace.CurrentCamera.CFrame.LookVector
		local pitch = math.asin(math.clamp(look.Y, -1, 1))
		attachment.CFrame = CFrame.new(0, 0, -0.6) * CFrame.Angles(pitch, 0, 0)
	end
end

function NightLights.start()
	if not A.Enabled then
		return
	end
	CollectionService:GetInstanceAddedSignal("NightLamp"):Connect(function(bulb)
		task.spawn(register, bulb)
	end)
	CollectionService:GetInstanceRemovedSignal("NightLamp"):Connect(function(bulb)
		lamps[bulb] = nil
	end)
	for _, bulb in CollectionService:GetTagged("NightLamp") do
		task.spawn(register, bulb)
	end

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 1 / 30 then
			elapsed = 0
			update()
		end
	end)
	RunService.RenderStepped:Connect(aimFlashlight)
end

return NightLights
