-- Ambiente de terror (servidor): noche con luna y niebla, linterna en la cabeza de cada jugador y faroles.
-- Los faroles son piezas con la etiqueta "NightLamp" (las ponen los constructores de mapa); aquí se les da la luz y se
-- decide cuáles parpadean (atributo Flicker) o están rotos (Broken). El cliente los anima (client/NightLights) y apaga
-- los que tienen el atributo BlackoutUntil (Atmosphere.blackout). Todo se apaga con Config.Atmosphere.Enabled = false.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Difficulty = require(script.Parent.Difficulty)

local Atmosphere = {}

local A = Config.Atmosphere

local function lampPart(parent, name, size, position, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material
	part.Parent = parent
	return part
end

-- Foco de farol con la etiqueta NightLamp (lo enciende Atmosphere.decorate)
function Atmosphere.bulb(parent, position)
	local bulb = lampPart(parent, "Foco", Vector3.new(1.2, 0.5, 0.8), position, A.Lamps.Color, Enum.Material.Neon)
	CollectionService:AddTag(bulb, "NightLamp")
	return bulb
end

-- Da luz a los faroles del mapa y elige cuáles parpadean o están rotos. `map` son las referencias del constructor.
function Atmosphere.decorate(map)
	if not A.Enabled then
		return
	end
	local rng = Random.new(Config.Game.Seed)
	local blackout = Difficulty.get().Flags.Blackout == true
	for _, bulb in CollectionService:GetTagged("NightLamp") do
		if not bulb:FindFirstChildWhichIsA("Light") then
			local light = Instance.new("SpotLight")
			light.Name = "Luz"
			light.Face = Enum.NormalId.Bottom
			light.Angle = 120
			light.Color = A.Lamps.Color
			light.Brightness = A.Lamps.Brightness
			light.Range = A.Lamps.Range
			light.Shadows = false -- muchas luces con sombra bajan los FPS en celular
			light.Parent = bulb
		end
		if blackout then
			bulb:SetAttribute("Broken", true) -- mutador "Apagón total": ningún farol enciende
			bulb:SetAttribute("Flicker", false)
		elseif bulb:GetAttribute("Flicker") == nil then
			local roll = rng:NextNumber()
			bulb:SetAttribute("Broken", roll < A.Lamps.BrokenChance)
			bulb:SetAttribute("Flicker", roll >= A.Lamps.BrokenChance and roll < A.Lamps.BrokenChance + A.Lamps.FlickerChance)
		end
	end
end

-- Apagón: los faroles cercanos chispean y se apagan unos segundos (el cliente pone las chispas y el sonido)
function Atmosphere.blackout(position)
	if not A.Enabled then
		return
	end
	local untilTime = workspace:GetServerTimeNow() + A.Blackout.Duration
	for _, bulb in CollectionService:GetTagged("NightLamp") do
		if (bulb.Position - position).Magnitude <= A.Blackout.Radius then
			bulb:SetAttribute("BlackoutUntil", untilTime)
		end
	end
end

-- Linterna en la cabeza: un cono de luz hacia delante (el cliente la inclina con la cámara en su propio personaje)
local function addFlashlight(player, character)
	local deadline = os.clock() + 10
	while (character.Parent == nil or not player:HasAppearanceLoaded()) and os.clock() < deadline do
		task.wait()
	end
	local head = character:FindFirstChild("Head")
	if not head or player.Character ~= character or head:FindFirstChild("Linterna") then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "Linterna"
	attachment.CFrame = CFrame.new(0, 0, -0.6) * CFrame.Angles(math.rad(-8), 0, 0)
	attachment.Parent = head
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Brightness = A.Flashlight.Brightness
	light.Range = A.Flashlight.Range
	light.Angle = A.Flashlight.Angle
	light.Color = A.Flashlight.Color
	light.Shadows = A.Flashlight.Shadows
	light.Parent = attachment
end

local function applyLighting()
	for key, value in A.Lighting do
		Lighting[key] = value
	end
	local fog = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	fog.Density = A.Fog.Density
	fog.Haze = A.Fog.Haze
	fog.Glare = A.Fog.Glare
	fog.Color = A.Fog.Color
	fog.Decay = A.Fog.Decay
	fog.Parent = Lighting
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if rays then
		rays.Enabled = false
	end
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "Noche"
	grade.Brightness = A.ColorGrade.Brightness
	grade.Contrast = A.ColorGrade.Contrast
	grade.Saturation = A.ColorGrade.Saturation
	grade.TintColor = A.ColorGrade.Tint
	grade.Parent = Lighting
end

function Atmosphere.start()
	if not A.Enabled then
		return
	end
	applyLighting()
	local function watch(player)
		player.CharacterAdded:Connect(function(character)
			addFlashlight(player, character)
		end)
		if player.Character then
			task.spawn(addFlashlight, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return Atmosphere
