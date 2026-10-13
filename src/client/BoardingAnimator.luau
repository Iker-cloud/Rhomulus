-- Gesto de subir a la furgoneta (cliente). El servidor deja quieto (anclado) al personaje que sube y le pone los atributos BoardStart
-- (hora del servidor), BoardFrom (de dónde parte), BoardSide (+1 puerta derecha, -1 izquierda) y BoardSeat (su asiento); el
-- servidor también reproduce las animaciones de caminar y trepar. Aquí cada cliente mueve la raíz del personaje por el camino,
-- calculado solo con esos datos y la hora, así todos ven lo mismo a la vez y sin tirones:
--   1. camina hasta un punto frente a la puerta   2. se gira hacia ella   3. trepa de un salto al suelo de la caja
--   4. camina hasta su asiento   5. se vuelve hacia el centro y el servidor lo sienta (Seat:Sit).
-- Las medidas de la furgoneta están en shared/VanLayout; las fases, en VanLayout.Phases (fracciones de Config.Boarding.Duration).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local VanLayout = require(ReplicatedStorage.Shared.VanLayout)

local BoardingAnimator = {}

local HOP_HEIGHT = 1.0 -- cuánto sube de más el salto al trepar (studs)
local STAGE_DISTANCE = 2.4 -- a cuánto de la pared se pone antes de trepar

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function seatDef(name)
	for _, def in VanLayout.Seats do
		if def.name == name then
			return def
		end
	end
	return VanLayout.Seats[1]
end

-- Dirección horizontal entre dos puntos (de vuelta `fallback` si casi coinciden)
local function direction(from, to, fallback)
	local d = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	return d.Magnitude > 0.05 and d.Unit or fallback
end

local function blend(a, b, t)
	local v = a:Lerp(b, t)
	return v.Magnitude > 0.01 and v.Unit or b
end

-- Dónde está el personaje y hacia dónde mira, en el marco de la furgoneta, `t` segundos después de empezar
local function localPose(van, character, t)
	local from = character:GetAttribute("BoardFrom")
	local side = character:GetAttribute("BoardSide")
	if not (from and side) then
		return nil
	end
	local S = van:GetAttribute("Scale") or 1
	local D = Config.Boarding.Duration
	local P = VanLayout.Phases
	local p1, p2, p3, p4 = P[1] * D, P[2] * D, P[3] * D, P[4] * D

	local pivot = van:GetPivot()
	local start = pivot:PointToObjectSpace(from)
	local h = start.Y -- altura de la raíz sobre el suelo
	local W = VanLayout.HalfWidth * S
	local doorZ = VanLayout.DoorZ * S
	local floorY = VanLayout.Floor * S
	local def = seatDef(character:GetAttribute("BoardSeat"))

	local staging = Vector3.new(side * (W + STAGE_DISTANCE), h, doorZ)
	local sill = Vector3.new(side * (W + 0.3), floorY + h, doorZ)
	local entry = Vector3.new(side * (W - 1.2), floorY + h, doorZ)
	local seatSpot = Vector3.new(side * (VanLayout.SeatX - 1.1) * S, floorY + h, def.z * S)
	local towardDoor = Vector3.new(-side, 0, 0)
	local towardCenter = Vector3.new(-side, 0, 0)

	local walkIn = direction(start, staging, towardDoor)
	if t < p1 then
		local u = smooth(t / p1)
		return start:Lerp(staging, u), walkIn
	elseif t < p2 then
		return staging, blend(walkIn, towardDoor, smooth((t - p1) / (p2 - p1)))
	elseif t < p3 then
		local u = (t - p2) / (p3 - p2)
		local position = staging:Lerp(sill, smooth(u))
		position += Vector3.new(0, HOP_HEIGHT * math.sin(math.pi * u), 0)
		return position, towardDoor
	elseif t < p4 then
		local u = (t - p3) / (p4 - p3)
		-- primero hacia dentro por la puerta y luego hasta el asiento
		local position, heading
		if u < 0.3 then
			position = sill:Lerp(entry, smooth(u / 0.3))
			heading = towardDoor
		else
			local v = smooth((u - 0.3) / 0.7)
			position = entry:Lerp(seatSpot, v)
			heading = blend(towardDoor, direction(entry, seatSpot, towardCenter), math.min(1, (u - 0.3) / 0.15))
		end
		return position, heading
	end
	local u = smooth((t - p4) / math.max(0.01, D - p4))
	return seatSpot, blend(direction(entry, seatSpot, towardCenter), towardCenter, u)
end

local function update()
	local map = workspace:FindFirstChild("Map")
	local van = map and map:FindFirstChild("Van")
	if not van then
		return
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local startTime = character and character:GetAttribute("BoardStart")
		local root = startTime and character:FindFirstChild("HumanoidRootPart")
		if root then
			local t = workspace:GetServerTimeNow() - startTime
			if t >= 0 and t <= Config.Boarding.Duration + 0.5 then
				local position, heading = localPose(van, character, math.min(t, Config.Boarding.Duration))
				if position then
					root.CFrame = van:GetPivot() * CFrame.lookAt(position, position + heading)
				end
			end
		end
	end
end

function BoardingAnimator.start()
	RunService.RenderStepped:Connect(update)
end

return BoardingAnimator
