-- Efectos visuales del arma cuerpo a cuerpo: una estela que sigue al filo durante el golpe y, en la motosierra, la vibración de
-- todo el arma. El modelo (MeleeWeapon) lo pone server/MeleeModel solo mientras dura el gesto, así que basta mirar cuándo aparece
-- en un personaje. Valen para todos los jugadores (cada cliente dibuja el golpe de los demás).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MeleeFx = {}

local TRAIL_COLOR = {
	Knife = Color3.fromRGB(220, 230, 240),
	Pan = Color3.fromRGB(190, 190, 200),
	Bat = Color3.fromRGB(235, 200, 150),
	Machete = Color3.fromRGB(200, 225, 240),
	Axe = Color3.fromRGB(255, 120, 100),
	Chainsaw = Color3.fromRGB(255, 190, 90),
}

local function setup(character, model)
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not root then
		return
	end
	local skinId = model:GetAttribute("SkinId")
	-- el largo del arma en el eje Y del modelo (el filo va hacia +Y)
	local cf, size = model:GetBoundingBox()
	local topLocal = root.CFrame:ToObjectSpace(cf * CFrame.new(0, size.Y / 2, 0))
	local midLocal = root.CFrame:ToObjectSpace(cf * CFrame.new(0, size.Y * 0.1, 0))
	local a0 = Instance.new("Attachment")
	a0.CFrame = topLocal
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.CFrame = midLocal
	a1.Parent = root

	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(TRAIL_COLOR[skinId or ""] or Color3.fromRGB(230, 230, 235))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = 0.22
	trail.MinLength = 0.05
	trail.LightEmission = 0.6
	trail.FaceCamera = true
	trail.Parent = root

	if skinId == "Chainsaw" then
		-- vibración: sacude el agarre un poco en cada cuadro mientras dura el golpe
		local grip = root:FindFirstChild("MeleeGrip")
		if grip and grip:IsA("Motor6D") then
			local base = grip.C1
			local conn
			conn = RunService.RenderStepped:Connect(function()
				if not model.Parent then
					conn:Disconnect()
					return
				end
				local t = os.clock()
				grip.C1 = base * CFrame.new(math.sin(t * 190) * 0.025, math.sin(t * 230) * 0.03, math.sin(t * 170) * 0.025)
					* CFrame.Angles(math.sin(t * 210) * 0.03, 0, math.sin(t * 180) * 0.03)
			end)
		end
	end
end

local function watch(character)
	character.ChildAdded:Connect(function(child)
		if child.Name == "MeleeWeapon" then
			task.defer(setup, character, child)
		end
	end)
	local existing = character:FindFirstChild("MeleeWeapon")
	if existing then
		task.defer(setup, character, existing)
	end
end

function MeleeFx.start()
	local function onPlayer(player)
		if player.Character then
			watch(player.Character)
		end
		player.CharacterAdded:Connect(watch)
	end
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
end

return MeleeFx
