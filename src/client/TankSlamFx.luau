-- Efectos del golpe al suelo del Tanque (server/Zombies.slam): el círculo rojo que se llena mientras levanta los brazos, la onda
-- expansiva, el polvo, el sonido, la sacudida de cámara y el empujón al propio personaje si queda dentro del radio y en el suelo.
-- Todo sale de los atributos del zombie: SlamT0 / SlamDur / SlamPos (aviso) y SlamHit (golpe). El cuerpo lo anima ZombieAnimator.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sfx = require(script.Parent.Sfx)

local player = Players.LocalPlayer

local TankSlamFx = {}

local RED = Color3.fromRGB(230, 40, 36)
local shake = 0

local function disc(radius, color, transparency, position)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Shape = Enum.PartType.Cylinder
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = transparency
	part.Size = Vector3.new(0.2, radius * 2, radius * 2)
	part.CFrame = CFrame.new(position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	part.Parent = workspace
	return part
end

local function setRadius(part, radius, position)
	part.Size = Vector3.new(0.2, radius * 2, radius * 2)
	part.CFrame = CFrame.new(position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2)
end

-- Aviso: círculo tenue del tamaño de la onda y un disco rojo que crece hasta llenarlo cuando cae el golpe
local function windup(model)
	local S = Config.Zombie.Tank.Slam
	local center = model:GetAttribute("SlamPos")
	local t0 = model:GetAttribute("SlamT0")
	local dur = model:GetAttribute("SlamDur") or S.Windup
	if not center or not t0 then
		return
	end
	local outer = disc(S.Radius, RED, 0.82, center)
	local inner = disc(0.5, RED, 0.45, center)
	Sfx.play3D("TankRoar", center)
	task.spawn(function()
		while model.Parent and model:GetAttribute("SlamT0") == t0 do
			local u = math.clamp((workspace:GetServerTimeNow() - t0) / dur, 0, 1)
			setRadius(inner, math.max(0.5, S.Radius * u), center)
			inner.Transparency = 0.55 - 0.25 * u + math.sin(os.clock() * 24) * 0.05
			outer.Transparency = 0.82 - 0.15 * u
			if u >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
		outer:Destroy()
		inner:Destroy()
	end)
end

-- Golpe: onda que se expande, polvo, sonido, sacudida y empujón
local function impact(model)
	local S = Config.Zombie.Tank.Slam
	local center = model:GetAttribute("SlamPos")
	if not center then
		return
	end
	Sfx.play3D("TankSlam", center)

	local wave = disc(2, Color3.fromRGB(255, 210, 180), 0.2, center)
	local startTime = os.clock()
	task.spawn(function()
		while wave.Parent do
			local u = (os.clock() - startTime) / 0.45
			if u >= 1 then
				break
			end
			setRadius(wave, 2 + (S.Radius * 1.08 - 2) * (1 - (1 - u) ^ 2), center)
			wave.Transparency = 0.2 + 0.8 * u
			RunService.Heartbeat:Wait()
		end
		wave:Destroy()
	end)

	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = center + Vector3.new(0, 1, 0)
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(150, 135, 115))
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) })
	dust.Lifetime = NumberRange.new(0.8, 1.4)
	dust.Speed = NumberRange.new(S.Radius * 1.4, S.Radius * 2.2)
	dust.SpreadAngle = Vector2.new(180, 5)
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Rate = 0
	dust.Enabled = false
	dust.Parent = anchor
	anchor.Parent = workspace
	dust:Emit(40)
	game:GetService("Debris"):AddItem(anchor, 2)

	-- Cámara y empujón al propio personaje
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	local offset = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
	local distance = offset.Magnitude
	local reach = S.Radius * 2.2
	if distance < reach then
		shake = math.max(shake, S.Shake * (1 - distance / reach))
	end
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	if distance <= S.Radius and grounded and humanoid.Health > 0 and (player:GetAttribute("State") or "Normal") == "Normal" and not player:GetAttribute("Carrying") and not player:GetAttribute("Boarded") then
		local direction = distance > 0.5 and offset.Unit or Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		root.AssemblyLinearVelocity = direction * S.Knock + Vector3.new(0, S.Lift, 0)
	end
end

local function watch(model)
	if model:GetAttribute("Kind") ~= "Tank" then
		return
	end
	local lastHit = model:GetAttribute("SlamHit")
	model:GetAttributeChangedSignal("SlamT0"):Connect(function()
		if model:GetAttribute("SlamT0") then
			windup(model)
		end
	end)
	model:GetAttributeChangedSignal("SlamHit"):Connect(function()
		local hit = model:GetAttribute("SlamHit")
		if hit and hit ~= lastHit then
			lastHit = hit
			impact(model)
		end
	end)
end

function TankSlamFx.start()
	local folder = workspace:WaitForChild("Zombies")
	local function add(model)
		if model:GetAttribute("Kind") then
			watch(model)
		else
			task.defer(function()
				if model.Parent then
					watch(model)
				end
			end)
		end
	end
	folder.ChildAdded:Connect(add)
	for _, model in folder:GetChildren() do
		add(model)
	end
	-- La sacudida se aplica después de que la cámara del juego haya puesto la suya
	RunService:BindToRenderStep("TankSlamShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if shake <= 0.01 then
			shake = 0
			return
		end
		local camera = workspace.CurrentCamera
		if camera then
			camera.CFrame *= CFrame.Angles((math.random() - 0.5) * 0.05 * shake, (math.random() - 0.5) * 0.05 * shake, (math.random() - 0.5) * 0.03 * shake)
		end
		shake = math.max(0, shake - dt * 1.8)
	end)
end

return TankSlamFx
