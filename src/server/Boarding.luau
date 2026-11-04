-- Subir a la furgoneta de rescate. Cuando la furgoneta llega (GameState.extraction) se abren las dos puertas laterales y cada una
-- tiene un prompt: manteniendo E, el sobreviviente sube con su animación (client/BoardingAnimator mueve al personaje; aquí se
-- ponen las animaciones de caminar, trepar y sentarse) y se sienta en un asiento. Si lleva a un compañero caído en hombros (F), sube
-- con él: el caído se levanta ya dentro. Quien sube queda a salvo (atributo "Boarded": los zombies lo ignoran) y cuenta para la victoria.
-- El atributo "Boarding" marca a quien está haciendo el gesto. Atributos del personaje durante el gesto: BoardStart (hora del
-- servidor), BoardFrom (posición de partida), BoardSide (+1 puerta derecha, -1 izquierda), BoardSeat (nombre del asiento).
-- La furgoneta arranca con Boarding.depart (client/VanAnimator hace el cierre de puertas, la marcha atrás y la huida).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local VanLayout = require(ReplicatedStorage.Shared.VanLayout)
local Items = require(script.Parent.Items)
local PlayerState = require(script.Parent.PlayerState)
local Revive = require(script.Parent.Revive)

local Boarding = {}

local B = Config.Boarding
local A = Config.Animations.Boarding

local van = nil
local isOpen = false
local prompts = {}
local seatsTaken = {} -- [nombre del asiento] = jugador
local pending = 0 -- gestos de subida en curso

local function getRoot(player)
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(player)
	return player.Character and player.Character:FindFirstChildOfClass("Humanoid")
end

local function freeSeatCount()
	local n = 0
	for _, def in VanLayout.Seats do
		if not seatsTaken[def.name] then
			n += 1
		end
	end
	return n
end

-- Reserva un asiento libre, de preferencia del lado de la puerta por la que se entra
local function takeSeat(side, player)
	for _, sameSide in { true, false } do
		for _, def in VanLayout.Seats do
			if not seatsTaken[def.name] and (def.side == side) == sameSide then
				seatsTaken[def.name] = player
				return def
			end
		end
	end
	return nil
end

local function loadTrack(humanoid, id, priority, looped)
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local track = animator:LoadAnimation(animation)
	track.Priority = priority
	track.Looped = looped
	return track
end

-- Animaciones del gesto de subir (las del servidor se replican a todos): caminar a la puerta, trepar, caminar dentro
local function playBoardingTracks(humanoid)
	local D = B.Duration
	local P = VanLayout.Phases
	local walk = loadTrack(humanoid, A.Walk, Enum.AnimationPriority.Action, true)
	local climb = loadTrack(humanoid, A.Climb, Enum.AnimationPriority.Action, true)
	local function at(fraction, fn)
		task.delay(D * fraction, function()
			if humanoid.Parent then
				fn()
			end
		end)
	end
	if walk then
		walk:Play(0.15)
		at(P[1], function()
			walk:Stop(0.15)
		end)
		at(P[3], function()
			walk:Play(0.15)
		end)
		at(1, function()
			walk:Stop(0.2)
		end)
	end
	if climb then
		at(P[2], function()
			climb:Play(0.15)
		end)
		at(P[3], function()
			climb:Stop(0.15)
		end)
	end
end

-- Termina el gesto: sienta al personaje en su asiento y lo deja a salvo
local function seatPlayer(player, def)
	local character = player.Character
	local humanoid = getHumanoid(player)
	local root = getRoot(player)
	local seat = van and van:FindFirstChild(def.name)
	player:SetAttribute("Boarding", nil)
	if not (character and humanoid and root and seat) or humanoid.Health <= 0 then
		seatsTaken[def.name] = nil
		return
	end
	for _, key in { "BoardStart", "BoardFrom", "BoardSide", "BoardSeat" } do
		character:SetAttribute(key, nil)
	end
	-- Se sienta a mano: anclado sobre el asiento y con la animación de sentado. No se usa Seat:Sit porque suelda el personaje a la
	-- furgoneta y, al irse ella (la mueve cada cliente), la cámara se quedaba atrás. Cada cliente lleva al pasajero pegado a su asiento
	-- (client/VanAnimator.followPassengers, con el atributo VanSeat).
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	character:SetAttribute("VanSeat", seat.Name)
	root.Anchored = true
	root.CFrame = seat.CFrame * CFrame.new(0, seat.Size.Y / 2 + VanLayout.SitHeight, 0)
	player:SetAttribute("Boarded", true)

	local sit = loadTrack(humanoid, A.Sit, Enum.AnimationPriority.Action, true)
	if sit then
		sit:Play(0.2)
	end
end

-- Empieza a subir `player` por la puerta de `side`
local function board(player, side)
	local root, humanoid = getRoot(player), getHumanoid(player)
	local character = player.Character
	if not (character and root and humanoid) then
		return
	end
	local carried = Revive.carriedBy(player)
	local need = carried and 2 or 1
	if freeSeatCount() < need then
		Remotes.Feed:FireClient(player, "No free seats in the van")
		return
	end
	local def = takeSeat(side, player)
	local carriedDef = carried and takeSeat(side, carried) or nil

	pending += 1
	player:SetAttribute("Boarding", true)
	if carried then
		carried:SetAttribute("Boarding", true)
	end
	Items.unequip(player, true) -- guarda lo que lleve en la mano

	root.Anchored = true -- quieto en el servidor: cada cliente lo mueve con su animación (BoardingAnimator)
	character:SetAttribute("BoardFrom", root.Position)
	character:SetAttribute("BoardSide", side)
	character:SetAttribute("BoardSeat", def.name)
	character:SetAttribute("BoardStart", workspace:GetServerTimeNow())
	playBoardingTracks(humanoid)

	task.delay(B.Duration, function()
		if carried and Revive.carriedBy(player) == carried then
			Revive.drop(player)
		end
		seatPlayer(player, def)
		if carried and carriedDef then
			-- El caído sube con quien lo carga y se levanta ya dentro
			if PlayerState.get(carried) == "Downed" then
				PlayerState.revive(carried, player)
			end
			seatPlayer(carried, carriedDef)
		end
		pending -= 1
	end)
end

-- Abre las puertas y activa los prompts (la furgoneta ya llegó)
function Boarding.open(vanModel)
	van = vanModel
	isOpen = true
	seatsTaken = {}
	prompts = {}
	for _, side in { 1, -1 } do
		local tag = side > 0 and "der" or "izq"
		local anchor = vanModel:FindFirstChild("J_puerta_" .. tag)
		if anchor then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "BoardPrompt"
			prompt.ActionText = "Board the van"
			prompt.ObjectText = "Rescue"
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = B.HoldTime
			prompt.MaxActivationDistance = B.PromptDistance
			prompt.RequiresLineOfSight = false
			prompt.Style = Enum.ProximityPromptStyle.Custom -- la interfaz la dibuja PromptUi.luau
			prompt.Parent = anchor
			prompt.Triggered:Connect(function(player)
				if not isOpen or van ~= vanModel or player:GetAttribute("Boarded") or player:GetAttribute("Boarding") then
					return
				end
				local root = getRoot(player)
				if PlayerState.get(player) ~= "Normal" or not root or (root.Position - anchor.Position).Magnitude > B.MaxDistance then
					return
				end
				board(player, side)
			end)
			table.insert(prompts, prompt)
		end
	end
	vanModel:SetAttribute("DoorR", true)
	vanModel:SetAttribute("DoorL", true)
end

-- Cuántos jugadores han subido o están subiendo
function Boarding.count()
	local n = 0
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Boarded") or player:GetAttribute("Boarding") then
			n += 1
		end
	end
	return n
end

-- ¿Ya subieron (o están subiendo) todos los de la lista?
function Boarding.allBoarded(list)
	if #list == 0 then
		return false
	end
	for _, player in list do
		if not (player:GetAttribute("Boarded") or player:GetAttribute("Boarding")) then
			return false
		end
	end
	return true
end

-- Cierra el abordaje: ya no se puede subir y se espera a que terminen los gestos en curso
function Boarding.close()
	isOpen = false
	for _, prompt in prompts do
		prompt.Enabled = false
	end
	local deadline = os.clock() + B.Duration + 2
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end

-- Cierra las puertas y la furgoneta arranca (client/VanAnimator)
function Boarding.depart()
	if not van then
		return
	end
	van:SetAttribute("DoorR", false)
	van:SetAttribute("DoorL", false)
	van:SetAttribute("DepartStart", workspace:GetServerTimeNow() + B.DepartDelay)
end

-- Al volver al lobby: nadie queda marcado como subido
function Boarding.reset()
	isOpen = false
	van = nil
	prompts = {}
	seatsTaken = {}
	pending = 0
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Boarded", nil)
		player:SetAttribute("Boarding", nil)
	end
end

return Boarding
