-- Zombies: modelo con articulaciones (ZombieModel) + IA que persigue al jugador más cercano con PathfindingService y lo golpea.
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Difficulty = require(script.Parent.Difficulty)
local Grabber = require(script.Parent.Grabber)
local PlayerState = require(script.Parent.PlayerState)
local ZombieModel = require(script.Parent.ZombieModel)

local Zombies = {}

-- Los zombies pasan por las puertas del estadio en Survival (MapBuilderBarrio las cierra a los jugadores con el grupo "GateWall")
for _, name in { "Zombie", "GateWall" } do
	pcall(function()
		PhysicsService:RegisterCollisionGroup(name)
	end)
end
PhysicsService:CollisionGroupSetCollidable("Zombie", "GateWall", false)

-- Modelo de cada tipo (se generan con tools/glb_to_lua.py desde assets/*.glb)
local MODELS = {
	Common = require(script.Parent.ZombieData.Brotado),
	Fast = require(script.Parent.ZombieData.Desbocado),
	Tank = require(script.Parent.ZombieData.Tanque),
	Grabber = require(script.Parent.ZombieData.Atrapador),
}

local folder = Instance.new("Folder")
folder.Name = "Zombies"
folder.Parent = workspace

local function nearestTarget(fromPosition)
	local best, bestDistance
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		-- Los caídos no son objetivo: los zombies van por los que siguen de pie
		if humanoid and root and humanoid.Health > 0 and PlayerState.get(player) == "Normal" and not player:GetAttribute("Boarded") and not player:GetAttribute("Boarding") then
			local distance = (root.Position - fromPosition).Magnitude
			-- Jeringa Sigilo: los zombies lejanos no la notan
			local stealth = player:GetAttribute("FxStealth")
			if stealth and distance > stealth then
				continue
			end
			if not bestDistance or distance < bestDistance then
				best, bestDistance = { player = player, root = root, character = character }, distance
			end
		end
	end
	return best, bestDistance
end

-- Survival: pasa a un zombie atascado a uno de los puntos de entrada que no esté a la vista de nadie (el más lejano de los jugadores)
local function relocate(model, root)
	local points = workspace:FindFirstChild("SpawnPoints") and workspace.SpawnPoints:FindFirstChild("Survival")
	if not points then
		return
	end
	local best, bestDistance
	for _, point in points:GetChildren() do
		local nearest = math.huge
		for _, player in Players:GetPlayers() do
			local playerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if playerRoot then
				nearest = math.min(nearest, (playerRoot.Position - point.Position).Magnitude)
			end
		end
		if nearest >= Config.Survival.MinSpawnDistance and (not bestDistance or nearest > bestDistance) then
			best, bestDistance = point, nearest
		end
	end
	if best then
		model:PivotTo(CFrame.new(best.Position + Vector3.new(0, 3, 0)))
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

-- Ruidos recientes (mutador "Ruidoso"): { Position, Range, Expires }
local noises = {}

-- Un ruido que atrae a los zombies cercanos unos segundos
function Zombies.noise(position, range, duration)
	local now = os.clock()
	for i = #noises, 1, -1 do
		if noises[i].Expires < now then
			table.remove(noises, i)
		end
	end
	if #noises < 12 then
		table.insert(noises, { Position = position, Range = range, Expires = now + duration })
	end
end

-- La bengala o el ruido más cercano dentro de su alcance (las bengalas las pone server/Items en workspace.Flares)
local function findLure(position)
	local best, bestDistance = nil, Config.Items.Flare.LureRange
	local flares = workspace:FindFirstChild("Flares")
	if flares then
		for _, flare in flares:GetChildren() do
			local distance = (flare.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = flare, distance
			end
		end
	end
	local now = os.clock()
	for _, noise in noises do
		local distance = (noise.Position - position).Magnitude
		if noise.Expires >= now and distance < noise.Range and distance < bestDistance then
			best, bestDistance = noise, distance
		end
	end
	return best
end

-- Mutador "Explosivos": algunos zombies explotan un instante después de morir y hieren a quien esté cerca
local function explode(model, root)
	local position = root.Position
	local E = Config.Zombie.Explosive
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 70, 30)
	highlight.OutlineColor = Color3.fromRGB(255, 190, 80)
	highlight.FillTransparency = 0.25
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	task.wait(E.Fuse)
	local blast = Instance.new("Explosion")
	blast.Position = position
	blast.BlastRadius = E.Radius
	blast.BlastPressure = 0
	blast.DestroyJointRadiusPercent = 0
	blast.ExplosionType = Enum.ExplosionType.NoCraters
	blast.Parent = workspace
	for _, player in Players:GetPlayers() do
		local playerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if playerRoot and (playerRoot.Position - position).Magnitude <= E.Radius then
			PlayerState.damage(player, E.Damage * Difficulty.get().Damage)
		end
	end
	highlight:Destroy()
end

-- El autobús sobre cuyo techo está `position` (nil si no está sobre ninguno)
local function busUnder(position)
	for _, bus in CollectionService:GetTagged("ClimbableBus") do
		local rel = bus.CFrame:PointToObjectSpace(position)
		local half = bus.Size / 2
		if math.abs(rel.X) <= half.X + 0.5 and math.abs(rel.Z) <= half.Z + 0.5 and rel.Y >= half.Y - 0.5 and rel.Y <= half.Y + 8 then
			return bus
		end
	end
	return nil
end

-- Distancia en el plano entre un punto y el rectángulo del autobús
local function distanceToBus(bus, position)
	local rel = bus.CFrame:PointToObjectSpace(position)
	local half = bus.Size / 2
	local dx = math.max(math.abs(rel.X) - half.X, 0)
	local dz = math.max(math.abs(rel.Z) - half.Z, 0)
	return math.sqrt(dx * dx + dz * dz)
end

local function smoothstep(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Trepa al techo de un autobús: se acerca al costado más cercano, se ancla y sube pegado a la pared (4 a 5 s), pasa el borde y
-- sigue a pie por el techo. El cliente anima la trepada con los atributos ClimbStart / ClimbEnd (client/ZombieAnimator).
-- Devuelve true si llegó arriba. `stillWanted()` dice si sigue habiendo alguien sobre el autobús.
local function climbBus(model, humanoid, root, bus, stillWanted)
	local half = bus.Size / 2
	local rel = bus.CFrame:PointToObjectSpace(root.Position)

	-- Lado por el que sube: el más cercano al zombie (outward = hacia afuera de la pared, en el marco del autobús)
	local outward
	if math.abs(rel.X) / half.X >= math.abs(rel.Z) / half.Z then
		outward = Vector3.new(rel.X >= 0 and 1 or -1, 0, 0)
	else
		outward = Vector3.new(0, 0, rel.Z >= 0 and 1 or -1)
	end
	local lateral
	if outward.X ~= 0 then
		lateral = Vector3.new(0, 0, math.clamp(rel.Z, -half.Z + 1.5, half.Z - 1.5))
	else
		lateral = Vector3.new(math.clamp(rel.X, -half.X + 1.5, half.X - 1.5), 0, 0)
	end
	local wallDistance = outward.X ~= 0 and half.X or half.Z
	local function toWorld(distanceOut, y)
		return bus.CFrame:PointToWorldSpace(outward * (wallDistance + distanceOut) + lateral + Vector3.new(0, y, 0))
	end

	-- 1) acercarse al pie de la pared (hasta 3 s)
	local standPoint = toWorld(1.3, 0)
	standPoint = Vector3.new(standPoint.X, root.Position.Y, standPoint.Z)
	local approachEnd = os.clock() + 3
	while humanoid.Health > 0 and os.clock() < approachEnd and stillWanted() do
		if (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(standPoint.X, 0, standPoint.Z)).Magnitude <= 1.6 then
			break
		end
		humanoid:MoveTo(standPoint)
		task.wait(0.1)
	end
	if humanoid.Health <= 0 or not stillWanted() then
		return false
	end

	-- 2) trepar: anclado, mirando a la pared, subiendo por ella y pasando el borde
	local climb = Config.Zombie.Climb
	local duration = climb.MinTime + math.random() * (climb.MaxTime - climb.MinTime)
	local rootHeight = humanoid.HipHeight + root.Size.Y / 2
	local startPosition = root.Position
	local wallTop = toWorld(0.9, half.Y)
	wallTop = Vector3.new(wallTop.X, wallTop.Y + rootHeight - 1.1, wallTop.Z) -- agarrado al borde, con medio cuerpo por debajo
	local roofPoint = toWorld(-1.8, half.Y)
	roofPoint = Vector3.new(roofPoint.X, roofPoint.Y + rootHeight, roofPoint.Z)
	local facing = -bus.CFrame:VectorToWorldSpace(outward)
	local sideways = bus.CFrame:VectorToWorldSpace(lateral.Magnitude > 0 and Vector3.new(outward.Z ~= 0 and 1 or 0, 0, outward.X ~= 0 and 1 or 0) or Vector3.xAxis)

	local started = workspace:GetServerTimeNow()
	model:SetAttribute("ClimbStart", started)
	model:SetAttribute("ClimbEnd", started + duration)
	root.Anchored = true
	local t0 = os.clock()
	local reached = false
	while true do
		if humanoid.Health <= 0 or not root.Parent then
			break
		end
		local u = (os.clock() - t0) / duration
		if u >= 1 then
			reached = true
			break
		end
		local position
		if u < 0.8 then
			-- Sube por la pared con un vaivén de lado a lado (un pie y otro)
			position = startPosition:Lerp(wallTop, smoothstep(u / 0.8)) + sideways * math.sin(u * 22) * 0.18
		else
			-- Pasa el borde: se impulsa hacia arriba y cae sobre el techo
			local v = (u - 0.8) / 0.2
			position = wallTop:Lerp(roofPoint, smoothstep(v)) + Vector3.new(0, math.sin(v * math.pi) * 0.9, 0)
		end
		root.CFrame = CFrame.lookAt(position, position + facing)
		task.wait()
	end
	model:SetAttribute("ClimbStart", nil)
	model:SetAttribute("ClimbEnd", nil)
	if reached and humanoid.Health > 0 then
		root.CFrame = CFrame.lookAt(roofPoint, roofPoint + facing)
		root.AssemblyLinearVelocity = Vector3.zero
		root.Anchored = false
	end
	return reached
end

-- Golpe al suelo del Tanque: se queda quieto con los brazos arriba (el cliente dibuja el círculo rojo y anima el cuerpo con SlamT0 /
-- SlamDur / SlamPos), golpea (SlamHit) y la onda hiere a todos los que estén dentro del radio y sin estar en el aire.
-- El empujón lo aplica cada cliente a su propio personaje (client/TankSlamFx).
local function slam(model, humanoid, root, stats)
	local S = Config.Zombie.Tank.Slam
	local walkSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = 0
	humanoid:MoveTo(root.Position)

	local groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Exclude
	groundParams.FilterDescendantsInstances = { folder }
	local ground = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), groundParams)
	local center = ground and ground.Position or (root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))

	model:SetAttribute("SlamPos", center)
	model:SetAttribute("SlamDur", S.Windup)
	model:SetAttribute("SlamT0", workspace:GetServerTimeNow())

	local function finish()
		model:SetAttribute("SlamT0", nil)
		if humanoid.Health > 0 then
			humanoid.WalkSpeed = walkSpeed
		end
	end

	local windupEnd = os.clock() + S.Windup
	while os.clock() < windupEnd do
		if humanoid.Health <= 0 or not root.Parent then
			finish()
			return
		end
		task.wait(0.05)
	end

	model:SetAttribute("SlamHit", workspace:GetServerTimeNow())
	local sightParams = RaycastParams.new()
	sightParams.FilterType = Enum.RaycastFilterType.Exclude
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local playerHumanoid = character and character:FindFirstChildOfClass("Humanoid")
		local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
		if playerHumanoid and playerRoot and playerHumanoid.Health > 0 then
			local flat = Vector3.new(playerRoot.Position.X - center.X, 0, playerRoot.Position.Z - center.Z).Magnitude
			local airborne = playerHumanoid.FloorMaterial == Enum.Material.Air and playerRoot.Position.Y - center.Y > S.Airborne
			if flat <= S.Radius and not airborne then
				sightParams.FilterDescendantsInstances = { folder, character }
				local blocked = workspace:Raycast(center + Vector3.new(0, 2, 0), playerRoot.Position - (center + Vector3.new(0, 2, 0)), sightParams)
				if not blocked then
					PlayerState.damage(player, stats.Damage * S.DamageMult)
				end
			end
		end
	end

	task.wait(S.Recover)
	finish()
end

local function think(humanoid, root, stats)
	local path = PathfindingService:CreatePath({
		AgentRadius = stats.AgentRadius or 1.5,
		AgentHeight = 5.5,
		AgentCanJump = true,
	})
	local sightParams = RaycastParams.new()
	sightParams.FilterType = Enum.RaycastFilterType.Exclude

	local lastAttack = 0
	local slamConfig = root.Parent:GetAttribute("Kind") == "Tank" and Config.Zombie.Tank.Slam or nil
	local nextSlam = os.clock() + (slamConfig and slamConfig.FirstCooldown or 0)
	-- Desfase aleatorio para que 25 zombies no calculen ruta en el mismo frame
	local lastPath = os.clock() - math.random() * Config.Zombie.RepathInterval

	local stuckFrom, stuckSince = root.Position, os.clock()
	local patrolGoal, nextPatrol = stats.Home, 0
	while humanoid.Health > 0 and root.Parent do
		local target, distance = nearestTarget(root.Position)
		-- De guardia (stats.Home): solo persigue a quien entra en su zona; si no hay nadie, patrulla alrededor de su puesto
		if stats.Home and not (target and (target.root.Position - stats.Home).Magnitude <= stats.LeashRadius) then
			if os.clock() >= nextPatrol then
				nextPatrol = os.clock() + 3 + math.random() * 3
				local angle = math.random() * math.pi * 2
				patrolGoal = stats.Home + Vector3.new(math.cos(angle), 0, math.sin(angle)) * math.random() * (stats.PatrolRadius or 10)
			end
			humanoid:MoveTo(patrolGoal)
			task.wait(Config.Zombie.ThinkInterval)
			continue
		end
		-- Survival: si lleva varios segundos sin avanzar y no está pegando (atascado entre edificios), reaparece en otro punto de entrada
		if target and distance > stats.AttackRange + 3 and workspace:GetAttribute("MapId") == "Survival" then
			local now = os.clock()
			if (root.Position - stuckFrom).Magnitude > Config.Zombie.Stuck.Distance then
				stuckFrom = root.Position
				stuckSince = now
			elseif now - stuckSince >= Config.Zombie.Stuck.Time then
				stuckSince = now
				relocate(root.Parent, root)
			end
		else
			stuckFrom = root.Position
			stuckSince = os.clock()
		end
		-- Una bengala encendida atrae a los zombies que no tienen a nadie al alcance de un golpe
		local lure = findLure(root.Position)
		if lure and not (target and distance <= stats.AttackRange) then
			humanoid:MoveTo(lure.Position)
			task.wait(Config.Zombie.ThinkInterval)
			continue
		end
		-- Si el jugador está sobre un autobús, los zombies cercanos que no estén ya en el techo trepan a él
		if target and Config.Zombie.Climb.Kinds[root.Parent:GetAttribute("Kind")] then
			local bus = busUnder(target.root.Position)
			if bus and not busUnder(root.Position) and distanceToBus(bus, root.Position) <= Config.Zombie.Climb.Range then
				climbBus(root.Parent, humanoid, root, bus, function()
					return target.root.Parent ~= nil and busUnder(target.root.Position) == bus
				end)
				continue
			end
		end
		if target then
			local now = os.clock()

			if slamConfig and distance <= slamConfig.TriggerRange and now >= nextSlam then
				slam(root.Parent, humanoid, root, stats)
				nextSlam = os.clock() + slamConfig.Cooldown
				continue
			end
			if distance <= stats.AttackRange then
				humanoid:MoveTo(root.Position) -- se detiene para golpear
				if now - lastAttack >= stats.AttackCooldown then
					lastAttack = now
					root.Parent:SetAttribute("Attack", workspace:GetServerTimeNow()) -- el cliente anima la embestida
					PlayerState.damage(target.player, stats.Damage)
				end
			elseif now - lastPath >= Config.Zombie.RepathInterval then
				lastPath = now

				-- Con línea de vista libre no hace falta calcular ruta (más barato)
				sightParams.FilterDescendantsInstances = { folder, target.character }
				local blocked = workspace:Raycast(root.Position, target.root.Position - root.Position, sightParams)
				if not blocked then
					humanoid:MoveTo(target.root.Position)
				else
					local ok = pcall(path.ComputeAsync, path, root.Position, target.root.Position)
					local waypoints = ok and path.Status == Enum.PathStatus.Success and path:GetWaypoints()
					if waypoints and #waypoints >= 2 then
						local waypoint = waypoints[2]
						if waypoint.Action == Enum.PathWaypointAction.Jump then
							humanoid.Jump = true
						end
						humanoid:MoveTo(waypoint.Position)
					else
						humanoid:MoveTo(target.root.Position) -- sin ruta: acercarse en línea recta
					end
				end
			end
		end
		task.wait(Config.Zombie.ThinkInterval)
	end
end

-- Zombies vivos ahora mismo (lo usa el director para respetar el límite); con `kind` cuenta solo ese tipo
function Zombies.getAlive(kind)
	local count = 0
	for _, model in folder:GetChildren() do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and (not kind or model:GetAttribute("Kind") == kind) then
			count += 1
		end
	end
	return count
end

-- Borra todos los zombies (cambio de zona, fin de partida)
function Zombies.clear()
	folder:ClearAllChildren()
end

-- Crea un zombie del tipo dado ("Common", "Fast", "Tank" o "Grabber") en la posición (a nivel del suelo). Devuelve el modelo.
-- Se anima en el cliente (ZombieAnimator), así que aquí solo se construye y se le da la IA.
-- `overrides` (opcional) cambia estadísticas de este zombie: vida, velocidad, daño, nombre... y, con Home + LeashRadius, lo deja de
-- guardia en una zona (los tripulantes del Crew Call).
function Zombies.spawn(kind, position, overrides)
	local stats = Difficulty.zombieStats(kind) -- vida, velocidad y daño según la dificultad
	for key, value in overrides or {} do
		stats[key] = value
	end
	local model, humanoid, root = ZombieModel.build(MODELS[kind], stats, position)
	model:SetAttribute("Kind", kind)
	model.Parent = folder
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Zombie"
		end
	end
	root:SetNetworkOwner(nil) -- el servidor simula la física del zombie

	humanoid.Died:Once(function()
		if kind == "Grabber" then
			Grabber.onDeath(model)
		end
		if Difficulty.get().Flags.Explosive and kind ~= "Tank" and math.random() < Config.Zombie.Explosive.Chance then
			task.spawn(explode, model, root)
		end
		-- Se queda quieto y deja de recibir balas; el cliente anima la caída, el espasmo y el desvanecimiento
		root.Anchored = true
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanQuery = false
			end
		end
		model:SetAttribute("DeadAt", workspace:GetServerTimeNow())
		task.wait(Config.Zombie.CorpseTime)
		model:Destroy()
	end)

	if kind == "Grabber" then
		task.spawn(Grabber.think, model, humanoid, root, stats, { nearestTarget = nearestTarget, folder = folder })
	else
		task.spawn(think, humanoid, root, stats)
	end
	return model
end

return Zombies
