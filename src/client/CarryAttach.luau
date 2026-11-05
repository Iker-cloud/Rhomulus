-- Pega el cuerpo del compañero caído a quien lo carga (server/Revive). El servidor lo ancla y lo mueve en cada cuadro, pero llega con
-- retraso; aquí cada cliente lo coloca sobre los hombros de quien lo carga justo antes de dibujar, con la posición que ve de él en ese
-- momento (la suya, si es quien carga), así no se queda atrás ni tiembla. El servidor marca los cuerpos cargados con la etiqueta
-- "CarriedBody" y el atributo CarriedBy (nombre de quien carga).
-- Animación: al cargarlo el cuerpo se levanta del suelo en arco hasta los hombros (Config.Revive.CarryLift) y, mientras se camina, se
-- balancea con el paso (sube y baja, se mece y la cabeza cuelga hacia atrás); al soltarlo el servidor lo deja donde cae.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local CarryAttach = {}

local states = setmetatable({}, { __mode = "k" }) -- [cuerpo] = { from, t0, speed, phase }

local function ease(a)
	return a * a * (3 - 2 * a) -- smoothstep
end

function CarryAttach.start()
	local settings = Config.Revive.CarryLift
	RunService:BindToRenderStep("CarryAttach", Enum.RenderPriority.Last.Value, function(dt)
		local now = os.clock()
		for _, body in CollectionService:GetTagged("CarriedBody") do
			local carrierName = body:GetAttribute("CarriedBy")
			local carrier = carrierName and workspace:FindFirstChild(carrierName)
			local carrierRoot = carrier and carrier:FindFirstChild("HumanoidRootPart")
			local bodyRoot = body:FindFirstChild("HumanoidRootPart")
			if carrierRoot and bodyRoot then
				local state = states[body]
				if not state then
					state = { from = body:GetPivot(), t0 = now, speed = 0, phase = 0 }
					states[body] = state
				end

				-- Velocidad horizontal de quien carga, suavizada, para el balanceo
				local velocity = carrierRoot.AssemblyLinearVelocity
				local flat = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
				local blend = 1 - math.exp(-dt * 8)
				state.speed += (math.min(flat / 16, 1) - state.speed) * blend
				state.phase += dt * (4 + 6 * state.speed) -- el paso va más rápido al correr

				local sway = state.speed
				local bob = math.abs(math.sin(state.phase)) * settings.Bob * sway
				local roll = math.sin(state.phase) * math.rad(settings.Roll) * sway
				local pitch = math.rad(settings.Hang) * sway + math.sin(state.phase * 2) * math.rad(settings.Pitch) * sway
				local target = carrierRoot.CFrame * CFrame.new(0, bob, 0) * Config.Revive.CarryOffset * CFrame.Angles(pitch, 0, roll)

				local a = math.clamp((now - state.t0) / settings.Time, 0, 1)
				if a < 1 then
					-- Subida: del lugar donde cayó a los hombros, con un arco hacia arriba
					local k = ease(a)
					local arc = CFrame.new(0, math.sin(a * math.pi) * settings.Arc, 0)
					body:PivotTo(arc * state.from:Lerp(target, k))
				else
					body:PivotTo(target)
				end
			end
		end
	end)

	-- Al soltarlo se olvida el estado, para que la próxima carga vuelva a empezar con la subida
	CollectionService:GetInstanceRemovedSignal("CarriedBody"):Connect(function(body)
		states[body] = nil
	end)
end

return CarryAttach
