-- Revivir (mantener E), cargar al caído en hombros (mantener F, soltar con G) y frases en globo.
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerState = require(script.Parent.PlayerState)
local Points = require(script.Parent.Points)

local Revive = {}

local carrying = {} -- [carrier] = target
local carriedBy = {} -- [target] = carrier
local welds = {} -- [target] = WeldConstraint

pcall(function()
	PhysicsService:RegisterCollisionGroup("Carried")
end)
PhysicsService:CollisionGroupSetCollidable("Carried", "Default", false)

local function say(character, text)
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild("Bubble")
	if old then
		old:Destroy()
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "Bubble"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(260, 40)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 80

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamMedium
	label.TextScaled = true
	label.Text = text
	label.Parent = gui
	Instance.new("UICorner", label).CornerRadius = UDim.new(0, 8)

	gui.Parent = head
	Debris:AddItem(gui, Config.Revive.BubbleTime)
end

local function randomOf(list)
	return list[math.random(#list)]
end

local function getRoot(player)
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

local function updatePrompts(player)
	local root = getRoot(player)
	if not root then
		return
	end
	local enabled = PlayerState.get(player) == "Downed" and not carriedBy[player]
	for _, name in { "RevivePrompt", "CarryPrompt" } do
		local prompt = root:FindFirstChild(name)
		if prompt then
			prompt.Enabled = enabled
		end
	end
end

local function setCollisionGroup(character, group)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = group
		end
	end
end

local function drop(carrier)
	local target = carrying[carrier]
	if not target then
		return
	end
	carrying[carrier] = nil
	carriedBy[target] = nil

	if welds[target] then
		welds[target]:Destroy()
		welds[target] = nil
	end

	carrier:SetAttribute("Carrying", nil)
	PlayerState.refreshSpeed(carrier)

	local character = target.Character
	if character then
		character:SetAttribute("Carried", nil)
		setCollisionGroup(character, "Default")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.PlatformStand = false
		end
		local carrierRoot = getRoot(carrier)
		if carrierRoot then
			character:PivotTo(CFrame.new(carrierRoot.Position + carrierRoot.CFrame.LookVector * 4))
		end
	end
	updatePrompts(target)
end

local function carry(carrier, target)
	local carrierRoot, targetRoot = getRoot(carrier), getRoot(target)
	local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	if not (carrierRoot and targetRoot and humanoid) then
		return
	end

	carrying[carrier] = target
	carriedBy[target] = carrier
	Points.add(Config.Points.Carry, carrier)
	carrier:SetAttribute("Carrying", target.Name)
	PlayerState.refreshSpeed(carrier)

	target.Character:SetAttribute("Carried", true) -- el cliente deja de girar al personaje
	setCollisionGroup(target.Character, "Carried")
	humanoid.PlatformStand = true

	-- Acostado sobre los hombros de quien carga
	targetRoot.CFrame = carrierRoot.CFrame * CFrame.new(0.5, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = carrierRoot
	weld.Part1 = targetRoot
	weld.Parent = targetRoot
	welds[target] = weld

	updatePrompts(target)
end

local function canHelp(helper, target)
	if helper == target or PlayerState.get(helper) ~= "Normal" or carrying[helper] or helper:GetAttribute("Carrying") then
		return false
	end
	if PlayerState.get(target) ~= "Downed" or carriedBy[target] then
		return false
	end
	local helperRoot, targetRoot = getRoot(helper), getRoot(target)
	return helperRoot ~= nil
		and targetRoot ~= nil
		and (helperRoot.Position - targetRoot.Position).Magnitude <= Config.Revive.MaxDistance
end

local function makePrompt(root, name, action, key, holdTime, offset)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = action
	prompt.KeyboardKeyCode = key
	prompt.HoldDuration = holdTime
	prompt.MaxActivationDistance = Config.Revive.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.UIOffset = offset
	prompt.Style = Enum.ProximityPromptStyle.Custom -- la interfaz la dibuja PromptUi.luau
	prompt.Enabled = false
	prompt.Parent = root
	return prompt
end

local function onCharacter(player, character)
	local root = character:WaitForChild("HumanoidRootPart")

	local revivePrompt = makePrompt(root, "RevivePrompt", "Revivir", Enum.KeyCode.E, Config.Revive.HoldTime, Vector2.zero)
	local carryPrompt = makePrompt(root, "CarryPrompt", "Cargar", Enum.KeyCode.F, Config.Revive.CarryHoldTime, Vector2.new(0, 70))

	revivePrompt.ObjectText = player.DisplayName

	-- Mientras mantiene E, quien revive lleva este atributo (hora en que terminaría); el cliente lo usa para arrodillarlo
	local function setReviving(helper, on)
		if helper.Character then
			helper.Character:SetAttribute("Reviving", on and workspace:GetServerTimeNow() + Config.Revive.HoldTime + 0.5 or nil)
		end
	end

	revivePrompt.PromptButtonHoldEnded:Connect(function(helper)
		setReviving(helper, false)
	end)

	revivePrompt.PromptButtonHoldBegan:Connect(function(helper)
		if not canHelp(helper, player) then
			return
		end
		setReviving(helper, true)
		say(helper.Character, randomOf(Config.Revive.ReviverPhrases))
		task.delay(Config.Revive.ReplyDelay, function()
			if PlayerState.get(player) == "Downed" then
				say(player.Character, randomOf(Config.Revive.DownedPhrases))
			end
		end)
	end)

	revivePrompt.Triggered:Connect(function(helper)
		setReviving(helper, false)
		if canHelp(helper, player) then
			PlayerState.revive(player, helper)
		end
	end)

	carryPrompt.Triggered:Connect(function(helper)
		if canHelp(helper, player) then
			carry(helper, player)
		end
	end)

	updatePrompts(player)
end

function Revive.start()
	local function setup(player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end

	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		drop(player)
		if carriedBy[player] then
			drop(carriedBy[player])
		end
	end)

	PlayerState.Changed.Event:Connect(function(player, state)
		if carrying[player] and state ~= "Normal" then
			drop(player)
		end
		if carriedBy[player] and state ~= "Downed" then
			drop(carriedBy[player])
		end
		updatePrompts(player)
	end)

	Remotes.Drop.OnServerEvent:Connect(drop)
end

return Revive
