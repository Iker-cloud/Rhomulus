-- Pega el cuerpo del compañero caído a quien lo carga (server/Revive). El servidor lo ancla y lo mueve en cada cuadro, pero llega con
-- retraso; aquí cada cliente lo coloca sobre los hombros de quien lo carga justo antes de dibujar, con la posición que ve de él en ese
-- momento (la suya, si es quien carga), así no se queda atrás ni tiembla. El servidor marca los cuerpos cargados con la etiqueta
-- "CarriedBody" y el atributo CarriedBy (nombre de quien carga).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local CarryAttach = {}

function CarryAttach.start()
	RunService:BindToRenderStep("CarryAttach", Enum.RenderPriority.Last.Value, function()
		for _, body in CollectionService:GetTagged("CarriedBody") do
			local carrierName = body:GetAttribute("CarriedBy")
			local carrier = carrierName and workspace:FindFirstChild(carrierName)
			local carrierRoot = carrier and carrier:FindFirstChild("HumanoidRootPart")
			local bodyRoot = body:FindFirstChild("HumanoidRootPart")
			if carrierRoot and bodyRoot then
				body:PivotTo(carrierRoot.CFrame * Config.Revive.CarryOffset) -- el pivote del personaje es su HumanoidRootPart
			end
		end
	end)
end

return CarryAttach
