-- El Atrapador: un zombie frágil que se mantiene a media distancia, apunta con un láser rojo, dispara la lengua y, si acierta, arrastra a
-- su víctima hasta sus manos y la muerde. Mientras está agarrada, la víctima puede disparar, moverse flojo y forcejear (Remotes.Struggle);
-- la lengua también se corta a tiros (Weapons llama a Grabber.hitTongue).
--
-- El servidor decide todo y publica el estado en atributos del zombie (los dibuja client/GrabberFx y lo anima client/ZombieAnimator):
--   TongueState  "aim" (apunta) | "shot" (la lengua vuela) | "hold" (agarrada) | "retract" (se recoge)
--   TongueT0     hora del servidor en que empezó ese estado; TongueDur su duración (aim y shot)
--   TongueAim    donde termina la lengua si va en el aire; TongueTarget  UserId de la víctima
--   Stunned      true mientras está aturdido (le cortaron la lengua o la víctima se soltó)
-- y en la víctima: GrabbedId (el GrabId del zombie) y GrabProgress (0 a 1 de lo que lleva forcejeado); lo mueve client/Grabbed.
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Difficulty = require(script.Parent.Difficulty)
local PlayerState = require(script.Parent.PlayerState)

local G = Config.Grabber
local Grabber = {}

local grabs = {} -- [Player] = { model, id, progress, since, ended, hitbox, tongueHp }
local nextId = 0

local function now()
	return workspace:GetServerTimeNow()
end

-- Donde nace la lengua (el servidor no ve las animaciones: se toma la pose base)
local function mouthPosition(model)
	local mouth = model:FindFirstChild("boca") or model:FindFirstChild("Head")
	return mouth and mouth.Position or model:GetPivot().Position
end

local function canBeGrabbed(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return humanoid ~= nil and root ~= nil and humanoid.Health > 0 and PlayerState.get(player) == "Normal"
		and not player:GetAttribute("Boarded") and not player:GetAttribute("Boarding") and not grabs[player]
end

function Grabber.isGrabbed(player)
	return grabs[player] ~= nil
end

-- Suelta a la víctima. `why`: "struggle" (se soltó), "cut" (le cortaron la lengua), "snap" (no llegó a tiempo), "timeout",
-- "down" (cayó o murió) o "dead" (murió el zombie). El hilo del zombie lo nota y decide el aturdimiento y la espera.
local function release(player, why)
	local grab = grabs[player]
	if not grab then
		return
	end
	grabs[player] = nil
	grab.ended = why
	if grab.hitbox then
		grab.hitbox:Destroy()
		grab.hitbox = nil
	end
	player:SetAttribute("GrabbedId", nil)
	player:SetAttribute("GrabProgress", nil)
	if why == "struggle" then
		Remotes.Feed:FireClient(player, "You broke free!")
	elseif why == "cut" then
		Remotes.Feed:FireClient(player, "Tongue cut!")
	end
end

-- Un disparo dio en la lengua: se corta con poco daño (lo llama server/Weapons). Devuelve true si la lengua era de un atrapador.
function Grabber.hitTongue(model, damage)
	for player, grab in grabs do
		if grab.model == model then
			grab.tongueHp -= damage
			if grab.tongueHp <= 0 then
				release(player, "cut")
			end
			return true
		end
	end
	return false
end

-- Murió el zombie (o lo borraron): su víctima queda libre
function Grabber.onDeath(model)
	for player, grab in grabs do
		if grab.model == model then
			release(player, "dead")
		end
	end
	model:SetAttribute("TongueState", nil)
	model:SetAttribute("TongueTarget", nil)
end

-- Forcejeo: cada pulsación acerca a la víctima a soltarse
local function onStruggle(player)
	local grab = grabs[player]
	if not grab then
		return
	end
	local t = os.clock()
	if t - (grab.lastPress or 0) < 1 / G.StruggleMaxRate then
		return
	end
	grab.lastPress = t
	grab.progress += 1
	player:SetAttribute("GrabProgress", math.min(1, grab.progress / G.StruggleNeeded))
	if grab.progress >= G.StruggleNeeded then
		release(player, "struggle")
	end
end

function Grabber.start()
	Remotes.Struggle.OnServerEvent:Connect(onStruggle)
	-- Si la víctima cae, muere, sube a la furgoneta o se va, la lengua se suelta
	PlayerState.Changed.Event:Connect(function(player, state)
		if state ~= "Normal" then
			release(player, "down")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		release(player, "down")
	end)
	local function watch(player)
		player.CharacterRemoving:Connect(function()
			release(player, "down")
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
end

-- Comportamiento --------------------------------------------------------------------------------------------------------------------

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function faceToward(root, point, alpha)
	local target = CFrame.lookAt(root.Position, Vector3.new(point.X, root.Position.Y, point.Z))
	root.CFrame = alpha and root.CFrame:Lerp(target, alpha) or target
end

-- Dispara la lengua a `target`: apunta (láser), la lanza y, si acierta, agarra y mantiene hasta que se suelte.
-- Devuelve el motivo del final: "miss", "lost" (la víctima ya no se puede agarrar), "dead" o el motivo de `release`.
local function fire(model, humanoid, root, target, ctx)
	local victim = target.player
	local victimRoot = target.root
	humanoid:MoveTo(root.Position)

	-- 1) Apunta: el láser sigue a la víctima y el zombie la mira; si se esconde, se cancela
	model:SetAttribute("TongueTarget", victim.UserId)
	model:SetAttribute("TongueDur", G.Aim)
	model:SetAttribute("TongueT0", now())
	model:SetAttribute("TongueState", "aim")
	local t0 = os.clock()
	while os.clock() - t0 < G.Aim do
		if humanoid.Health <= 0 or not root.Parent then
			return "dead"
		end
		if not canBeGrabbed(victim) or not victimRoot.Parent then
			model:SetAttribute("TongueState", nil)
			return "lost"
		end
		faceToward(root, victimRoot.Position, 0.3)
		task.wait(0.05)
	end

	-- 2) Dispara hacia donde está ahora (si no hay línea de vista o se alejó demasiado, no sale)
	local mouth = mouthPosition(model)
	local aimPoint = victimRoot.Position
	local distance = (aimPoint - mouth).Magnitude
	if distance > G.Range + 10 or not ctx.lineClear(mouth, aimPoint) then
		model:SetAttribute("TongueState", nil)
		return "miss"
	end
	local travel = distance / G.TongueSpeed
	model:SetAttribute("TongueAim", aimPoint)
	model:SetAttribute("TongueDur", travel)
	model:SetAttribute("TongueT0", now())
	model:SetAttribute("TongueState", "shot")
	task.wait(travel)

	-- 3) Acierta si la víctima sigue cerca del punto y nada se interpuso
	if humanoid.Health <= 0 or not root.Parent then
		return "dead"
	end
	local close = canBeGrabbed(victim) and victimRoot.Parent ~= nil and (flat(victimRoot.Position) - flat(aimPoint)).Magnitude <= G.HitRadius
	if not (close and ctx.lineClear(mouthPosition(model), victimRoot.Position)) then
		model:SetAttribute("TongueState", "retract")
		model:SetAttribute("TongueT0", now())
		model:SetAttribute("TongueTarget", nil)
		task.delay(0.4, function()
			if model.Parent and model:GetAttribute("TongueState") == "retract" then
				model:SetAttribute("TongueState", nil)
			end
		end)
		return "miss"
	end

	-- 4) Agarrada: la lengua queda tensa (con una caja que las balas pueden cortar) y el cliente de la víctima la arrastra
	local grab = { model = model, id = model:GetAttribute("GrabId"), progress = 0, since = os.clock(), tongueHp = G.TongueHealth, lastBite = 0 }
	grabs[victim] = grab
	victim:SetAttribute("GrabbedId", grab.id)
	victim:SetAttribute("GrabProgress", 0)
	local hitbox = Instance.new("Part")
	hitbox.Name = "TongueHitbox"
	hitbox.Transparency = 1
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.CanQuery = true
	hitbox.Size = Vector3.new(1.1, 1.1, 4)
	hitbox.Parent = model
	grab.hitbox = hitbox
	model:SetAttribute("TongueState", "hold")
	model:SetAttribute("TongueT0", now())
	Remotes.Feed:FireAllClients(`The Grabber caught {victim.DisplayName}! Shoot the tongue!`)

	local last = os.clock()
	while not grab.ended and humanoid.Health > 0 and root.Parent do
		local t = os.clock()
		local dt = t - last
		last = t
		if not victimRoot.Parent then
			release(victim, "down")
			break
		end
		-- la caja de la lengua va de la boca a la víctima
		local from = mouthPosition(model)
		local to = victimRoot.Position
		if grab.hitbox then
			grab.hitbox.Size = Vector3.new(1.1, 1.1, math.max(1, (to - from).Magnitude))
			grab.hitbox.CFrame = CFrame.lookAt((from + to) / 2, to)
		end
		faceToward(root, to, 0.2)
		humanoid:MoveTo(root.Position)

		grab.progress = math.max(0, grab.progress - G.StruggleDecay * dt)
		victim:SetAttribute("GrabProgress", math.min(1, grab.progress / G.StruggleNeeded))

		if (flat(to) - flat(root.Position)).Magnitude <= G.HoldRange then
			-- en sus manos: la muerde
			if t - grab.lastBite >= G.HoldInterval then
				grab.lastBite = t
				model:SetAttribute("Attack", now())
				PlayerState.damage(victim, G.HoldDamage * Difficulty.get().Damage)
			end
		elseif t - grab.since > G.MaxPull then
			release(victim, "snap") -- no logró llegar: la lengua se rompe
		end
		if t - grab.since > G.MaxHold then
			release(victim, "timeout")
		end
		RunService.Heartbeat:Wait()
	end
	local why = grab.ended or "dead"
	release(victim, why) -- por si salió el bucle sin soltar (murió el zombie)
	model:SetAttribute("TongueTarget", nil)
	model:SetAttribute("TongueState", "retract")
	model:SetAttribute("TongueT0", now())
	task.delay(0.4, function()
		if model.Parent and model:GetAttribute("TongueState") == "retract" then
			model:SetAttribute("TongueState", nil)
		end
	end)
	return why
end

-- El hilo del Atrapador (lo lanza Zombies.spawn). ctx = { nearestTarget(position), folder } de server/Zombies.
function Grabber.think(model, humanoid, root, stats, ctx)
	nextId += 1
	model:SetAttribute("GrabId", nextId)

	local path = PathfindingService:CreatePath({ AgentRadius = stats.AgentRadius or 1.8, AgentHeight = 5.5, AgentCanJump = true })
	local sight = RaycastParams.new()
	sight.FilterType = Enum.RaycastFilterType.Exclude

	-- Línea de vista libre entre dos puntos (los jugadores y los zombies no la tapan)
	function ctx.lineClear(from, to)
		local ignore = { ctx.folder }
		for _, player in Players:GetPlayers() do
			if player.Character then
				table.insert(ignore, player.Character)
			end
		end
		sight.FilterDescendantsInstances = ignore
		return workspace:Raycast(from, to - from, sight) == nil
	end

	local every = Difficulty.get().GrabberEvery
	local readyAt = os.clock() + G.FirstCooldown * every
	local lastAttack = 0
	local lastPath = os.clock() - math.random() * Config.Zombie.RepathInterval

	local function stun(seconds)
		model:SetAttribute("Stunned", true)
		humanoid:MoveTo(root.Position)
		local until_ = os.clock() + seconds
		while os.clock() < until_ and humanoid.Health > 0 and root.Parent do
			task.wait(0.1)
		end
		model:SetAttribute("Stunned", nil)
	end

	local function approach(target)
		local t = os.clock()
		if t - lastPath < Config.Zombie.RepathInterval then
			return
		end
		lastPath = t
		if ctx.lineClear(root.Position + Vector3.new(0, 1, 0), target.root.Position) then
			humanoid:MoveTo(target.root.Position)
			return
		end
		local ok = pcall(path.ComputeAsync, path, root.Position, target.root.Position)
		local waypoints = ok and path.Status == Enum.PathStatus.Success and path:GetWaypoints()
		if waypoints and #waypoints >= 2 then
			if waypoints[2].Action == Enum.PathWaypointAction.Jump then
				humanoid.Jump = true
			end
			humanoid:MoveTo(waypoints[2].Position)
		else
			humanoid:MoveTo(target.root.Position)
		end
	end

	while humanoid.Health > 0 and root.Parent do
		local target, distance = ctx.nearestTarget(root.Position)
		if target then
			local t = os.clock()
			local mouth = mouthPosition(model)
			local sees = distance <= G.Range and ctx.lineClear(mouth, target.root.Position)
			if distance <= stats.AttackRange then
				-- le cayeron encima: golpea
				humanoid:MoveTo(root.Position)
				if t - lastAttack >= stats.AttackCooldown then
					lastAttack = t
					model:SetAttribute("Attack", now())
					PlayerState.damage(target.player, stats.Damage)
				end
			elseif sees and t >= readyAt and canBeGrabbed(target.player) then
				local why = fire(model, humanoid, root, target, ctx)
				if humanoid.Health <= 0 or not root.Parent then
					break
				end
				if why == "cut" then
					stun(G.StunCut)
					readyAt = os.clock() + G.Cooldown * every
				elseif why == "struggle" then
					stun(G.StunBreak)
					readyAt = os.clock() + G.Cooldown * every
				elseif why == "miss" or why == "lost" then
					readyAt = os.clock() + G.MissCooldown * every
				else
					readyAt = os.clock() + G.Cooldown * every * 0.6
				end
			elseif distance < G.MinRange and t < readyAt then
				-- evita acercarse: retrocede mientras espera
				local away = flat(root.Position - target.root.Position)
				away = away.Magnitude > 0.1 and away.Unit or Vector3.xAxis
				humanoid:MoveTo(root.Position + away * 14)
			elseif not sees or distance > G.Range * 0.8 then
				approach(target)
			else
				-- a buena distancia y esperando: lo vigila sin moverse
				humanoid:MoveTo(root.Position)
				faceToward(root, target.root.Position, 0.15)
			end
		end
		task.wait(Config.Zombie.ThinkInterval)
	end
end

return Grabber
