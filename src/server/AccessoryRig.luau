-- Pone en el personaje los accesorios que el jugador lleva puestos (caja Barrio, shared/Accessories). El atributo `AccEquipped`
-- ("Head:CapRed,Back:PackSchool") lo publica server/PlayerProgress al cargar lo guardado. Se pegan con soldaduras ligeras (sin
-- colisión ni masa) y se renuevan al reaparecer o si el atributo cambia. Es solo aspecto: no afecta al juego.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Accessories = require(ReplicatedStorage.Shared.Accessories)

local AccessoryRig = {}

local function strip(character)
	for _, child in character:GetChildren() do
		if child:IsA("Model") and string.sub(child.Name, 1, 4) == "Acc_" then
			child:Destroy()
		end
	end
end

local function apply(player, character)
	if not character or not character.Parent then
		return
	end
	strip(character)
	-- el avatar reemplaza las piezas del cuerpo justo al aparecer: se espera a que esté completo para no soldar a piezas que se van
	for _, name in { "Head", "UpperTorso", "RightUpperArm" } do
		if not character:FindFirstChild(name) then
			return
		end
	end
	for slot, id in Accessories.decode(player:GetAttribute("AccEquipped")) do
		local model = Accessories.attach(character, id)
		if model then
			model.Name = "Acc_" .. slot
		end
	end
end

local function watch(player)
	local function onCharacter(character)
		task.spawn(function()
			local waited = 0
			local function ready()
				for _, name in { "Head", "UpperTorso", "RightUpperArm" } do
					if not character:FindFirstChild(name) then
						return false
					end
				end
				return player:HasAppearanceLoaded()
			end
			while player.Parent == Players and character.Parent and not ready() and waited < 10 do
				task.wait(0.2)
				waited += 0.2
			end
			apply(player, character)
			-- al aparecer, Roblox termina de armar el avatar después y puede llevarse lo pegado: se comprueba unos segundos
			for _ = 1, 8 do
				task.wait(0.75)
				if player.Parent ~= Players or not character.Parent then
					return
				end
				local missing = false
				for slot in Accessories.decode(player:GetAttribute("AccEquipped")) do
					if not character:FindFirstChild("Acc_" .. slot) then
						missing = true
					end
				end
				if missing then
					apply(player, character)
				end
			end
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
	player:GetAttributeChangedSignal("AccEquipped"):Connect(function()
		apply(player, player.Character)
	end)
end

function AccessoryRig.start()
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return AccessoryRig
