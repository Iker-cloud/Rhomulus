-- Garrafas de gas (mapa nuevo): el generador de la plaza está sin gasolina. En el mercado hay Config.Gas.Count garrafas
-- (en puestos al azar cada partida); se cargan con E como a un compañero caído (atributo Carrying: lento y solo pistola),
-- se sueltan con G y se entregan acercándose al generador. Cada entrega trae una pequeña horda.
-- GameState espera a que estén todas antes de dejar encender el generador. MapBuilderBarrio las define en refs.gas.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Director = require(script.Parent.Director)
local PlayerState = require(script.Parent.PlayerState)
local RateLimit = require(script.Parent.RateLimit)
local Points = require(script.Parent.Points)

local GasCans = {}

local G = Config.Gas
local data -- refs.gas: { cans = { { model, body, prompt } }, spots, marketPos, deliverPos, depositSpots, hordePoints }
local active = false
local delivered = 0
local globalsConnected = false -- init se llama en cada mapa nuevo: los eventos globales se conectan una sola vez

local function getRoot(player)
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

local function setCarrier(player, carrying)
	player:SetAttribute("Carrying", carrying and "garrafa" or nil)
	player:SetAttribute("CarryingItem", carrying and "una garrafa" or nil)
	PlayerState.refreshSpeed(player)
end

-- Anclada en el suelo o suelta para ir soldada al jugador
local function setLoose(can, loose)
	for _, part in can.model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = not loose
			part.Massless = loose
		end
	end
end

local function unweld(can)
	if can.weld then
		can.weld:Destroy()
		can.weld = nil
	end
end

-- De pie en el suelo (la base en y = 0)
local function place(can, position)
	can.model:PivotTo(CFrame.new(position.X, 1.75, position.Z))
end

local function canCarriedBy(player)
	for _, can in data and data.cans or {} do
		if can.carrier == player then
			return can
		end
	end
end

local function drop(player)
	local can = canCarriedBy(player)
	if not can then
		return
	end
	local root = getRoot(player)
	unweld(can)
	setLoose(can, false)
	can.carrier = nil
	can.state = "ground"
	if root then
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		place(can, root.Position + (look.Magnitude > 0 and look.Unit or Vector3.zero) * 3)
	end
	can.prompt.Enabled = active
	setCarrier(player, false)
end

local function pickup(player, can)
	local root = getRoot(player)
	if not active or can.state ~= "ground" or not root or PlayerState.get(player) ~= "Normal" or player:GetAttribute("Carrying") then
		return
	end
	can.state = "carried"
	can.carrier = player
	can.prompt.Enabled = false
	setLoose(can, true)
	-- Tumbada sobre el hombro izquierdo, a lo largo (la cámara va sobre el derecho y así no tapa la mira)
	can.body.CFrame = root.CFrame * CFrame.new(-1.1, 1.6, 0.3) * CFrame.Angles(0, math.rad(90), 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = can.body
	weld.Parent = can.body
	can.weld = weld
	setCarrier(player, true)
end

local function deliver(can)
	local player = can.carrier
	unweld(can)
	setLoose(can, false)
	can.carrier = nil
	can.state = "delivered"
	delivered += 1
	place(can, data.depositSpots[delivered] or data.deliverPos)
	setCarrier(player, false)
	Points.add(G.DeliverPoints, player)
	Points.feed(`{player.DisplayName} llevó una garrafa al generador ({delivered}/{G.Count})`)
	if delivered < G.Count then
		task.spawn(Director.spawnAmbush, G.DeliveryHorde, data.hordePoints)
	end
end

-- Elige lugares al azar separados al menos MinSeparation (prueba varias mezclas antes de aceptar alguno cerca)
local function pickSpots()
	local needed = #data.cans
	local pool = table.clone(data.spots)
	local best = {}
	for _ = 1, 30 do
		for i = #pool, 2, -1 do
			local j = math.random(i)
			pool[i], pool[j] = pool[j], pool[i]
		end
		local chosen = {}
		for _, spot in pool do
			local farEnough = true
			for _, other in chosen do
				if (spot - other).Magnitude < G.MinSeparation then
					farEnough = false
				end
			end
			if farEnough then
				table.insert(chosen, spot)
			end
		end
		if #chosen > #best then
			best = chosen
		end
		if #best >= needed then
			break
		end
	end
	for _, spot in pool do -- si no hay forma de separarlas todas, se completan aunque estén cerca
		if #best >= needed then
			break
		end
		if not table.find(best, spot) then
			table.insert(best, spot)
		end
	end
	return best
end

function GasCans.init(gas)
	data = gas
	active = false
	delivered = 0
	if not data then
		return
	end
	for _, can in data.cans do
		can.state = "ground"
		can.prompt.ActionText = "Cargar garrafa"
		can.prompt.HoldDuration = G.HoldTime
		can.prompt.Triggered:Connect(function(player)
			pickup(player, can)
		end)
	end

	if globalsConnected then
		return
	end
	globalsConnected = true
	Remotes.Drop.OnServerEvent:Connect(RateLimit.wrap("DropGas", 0.3, drop))
	PlayerState.Changed.Event:Connect(function(player, state)
		if state ~= "Normal" then
			drop(player)
		end
	end)
	local function watch(player)
		player.CharacterRemoving:Connect(function()
			drop(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(drop)

	-- Entrega: quien llega con una garrafa cerca del generador la deja ahí
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if not data or not active or elapsed < 0.25 then
			return
		end
		elapsed = 0
		for _, can in data.cans do
			local root = can.carrier and getRoot(can.carrier)
			if root and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(data.deliverPos.X, 0, data.deliverPos.Z)).Magnitude <= G.DeliverRadius then
				deliver(can)
			end
		end
	end)
end

-- Al empezar cada partida: garrafas repartidas al azar por el mercado, sin poder cargarlas hasta GasCans.activate
function GasCans.reset()
	active = false
	delivered = 0
	if not data then
		return
	end
	local spots = pickSpots()
	for i, can in data.cans do
		if can.carrier then
			setCarrier(can.carrier, false)
		end
		unweld(can)
		setLoose(can, false)
		can.carrier = nil
		can.state = "ground"
		can.prompt.Enabled = false
		place(can, spots[i])
	end
end

function GasCans.activate()
	active = true
	for _, can in data.cans do
		can.prompt.Enabled = can.state == "ground"
	end
end

function GasCans.delivered()
	return delivered
end

function GasCans.anyCarried()
	for _, can in data and data.cans or {} do
		if can.state == "carried" then
			return true
		end
	end
	return false
end

return GasCans
