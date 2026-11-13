-- Lluvia (cliente): cuando el servidor publica Workspace.Weather = "Rain" (server/Atmosphere.forMap, según el mapa), caen gotas
-- de una rejilla de hojas alrededor de la cámara. Cada hoja solo llueve si no tiene nada encima (techo, muro, pasarela), así que
-- dentro del terminal no llueve pero se ve llover fuera por las puertas. El sonido baja y se apaga bajo techo, y de vez en cuando
-- cae un rayo (destello y trueno). Todo es local; los valores están en Config.Weather.Rain y la cantidad de gotas depende de la
-- calidad gráfica (client/Performance).
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local Performance = require(script.Parent.Performance)

local R = Config.Weather.Rain
local S = Config.Sounds.Weather

local Rain = {}

local function isRaining()
	return workspace:GetAttribute("Weather") == "Rain" and workspace:GetAttribute("Stage") ~= "Vote"
end

function Rain.start()
	local holder = Instance.new("Folder")
	holder.Name = "Lluvia"
	holder.Parent = workspace

	local half = (R.Grid - 1) / 2
	local sheets = {}
	for gx = -half, half do
		for gz = -half, half do
			local part = Instance.new("Part")
			part.Name = "HojaLluvia"
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Transparency = 1
			part.Size = Vector3.new(R.Sheet, 0.2, R.Sheet)
			part.Parent = holder
			local emitter = Instance.new("ParticleEmitter")
			emitter.Texture = "rbxasset://textures/particles/smoke_main.dds" -- una mancha suave: aplastada queda como un trazo
			emitter.EmissionDirection = Enum.NormalId.Bottom
			emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
			emitter.Speed = NumberRange.new(R.Speed[1], R.Speed[2])
			emitter.Lifetime = NumberRange.new(R.Life[1], R.Life[2])
			emitter.Acceleration = R.Wind
			emitter.SpreadAngle = Vector2.new(3, 3)
			emitter.Size = NumberSequence.new(R.Size)
			emitter.Squash = NumberSequence.new(-3) -- fino y largo en el sentido de la caída
			emitter.Color = ColorSequence.new(R.Color)
			emitter.Transparency = NumberSequence.new(R.Transparency)
			emitter.LightEmission = 0.6
			emitter.LightInfluence = 0.3
			emitter.Rate = 0
			emitter.Parent = part
			table.insert(sheets, { part = part, emitter = emitter, gx = gx, gz = gz, open = false })
		end
	end

	local loop = Instance.new("Sound")
	loop.Name = "Lluvia"
	loop.SoundId = S.Rain
	loop.Looped = true
	loop.Volume = 0
	loop.Parent = SoundService
	local muffle = Instance.new("EqualizerSoundEffect") -- bajo techo se oye apagada
	muffle.HighGain = 0
	muffle.MidGain = 0
	muffle.LowGain = 0
	muffle.Parent = loop

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include

	-- ¿Hay algo del mapa por encima de esta altura en (x, z)? El rayo baja desde muy arriba: así también cuentan los muros.
	local function covered(x, z, height)
		local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -400 + height, 0), params)
		return hit ~= nil
	end

	local centerOpen = false
	local flashUntil, flashBase = 0, nil
	local checkAt, nextThunder = 0, os.clock() + R.Thunder.MinInterval
	local inset = R.Sheet / 2 - 1

	RunService.Heartbeat:Connect(function(dt)
		local raining = isRaining()
		local camera = workspace.CurrentCamera
		local map = workspace:FindFirstChild("Map")
		local now = os.clock()
		if raining and not loop.IsPlaying then
			loop:Play()
		end
		if raining and camera and map then
			local focus = camera.CFrame.Position
			-- Las hojas siguen a la cámara en una rejilla fija (así una hoja no cambia de sitio a cada paso)
			local cx = math.floor(focus.X / R.Sheet + 0.5) * R.Sheet
			local cz = math.floor(focus.Z / R.Sheet + 0.5) * R.Sheet
			local check = now >= checkAt
			local head = focus.Y + 0.5 -- cuenta como techo lo que quede por encima de la cámara
			if check then
				checkAt = now + 0.3
				params.FilterDescendantsInstances = { map }
				centerOpen = not covered(focus.X, focus.Z, head)
			end
			local rate = R.Rate[Performance.level()] or R.Rate[#R.Rate]
			for _, sheet in sheets do
				local x, z = cx + sheet.gx * R.Sheet, cz + sheet.gz * R.Sheet
				sheet.part.Position = Vector3.new(x, focus.Y + R.Height, z)
				if check then -- llueve solo si el centro y las cuatro esquinas de la hoja están al descubierto
					sheet.open = not (covered(x, z, head) or covered(x - inset, z - inset, head) or covered(x + inset, z - inset, head) or covered(x - inset, z + inset, head) or covered(x + inset, z + inset, head))
				end
				sheet.emitter.Rate = sheet.open and rate or 0
			end
		else
			for _, sheet in sheets do
				sheet.emitter.Rate = 0
			end
		end

		-- Sonido: fuerte al aire libre, apagado bajo techo
		local target = raining and (centerOpen and R.Volume.Outside or R.Volume.Inside) or 0
		local blend = math.min(1, dt * 2.5)
		loop.Volume += (target - loop.Volume) * blend
		muffle.HighGain += ((centerOpen and 0 or -22) - muffle.HighGain) * blend
		muffle.MidGain += ((centerOpen and 0 or -6) - muffle.MidGain) * blend
		if not raining and loop.IsPlaying and loop.Volume < 0.01 then
			loop:Stop()
		end

		-- Rayo: dos destellos cortos y el trueno un poco después
		if raining and now >= nextThunder then
			nextThunder = now + R.Thunder.MinInterval + math.random() * (R.Thunder.MaxInterval - R.Thunder.MinInterval)
			flashBase = flashBase or Lighting.ExposureCompensation
			flashUntil = now + 0.34
			task.delay(0.6 + math.random() * 1.8, function()
				local thunder = Instance.new("Sound")
				thunder.SoundId = S.Thunder[math.random(#S.Thunder)]
				thunder.Volume = R.Thunder.Volume * (centerOpen and 1 or 0.6)
				thunder.PlaybackSpeed = 0.8 + math.random() * 0.3
				thunder.Parent = SoundService
				thunder:Play()
				thunder.Ended:Once(function()
					thunder:Destroy()
				end)
				task.delay(20, function()
					thunder:Destroy()
				end)
			end)
		end
		if flashBase then
			local left = flashUntil - now
			if left <= 0 then
				Lighting.ExposureCompensation = flashBase
				flashBase = nil
			else
				local on = left > 0.24 or (left < 0.14 and left > 0.06) -- destello, pausa, destello
				Lighting.ExposureCompensation = flashBase + (on and R.Thunder.Flash or 0)
			end
		end
	end)
end

return Rain
