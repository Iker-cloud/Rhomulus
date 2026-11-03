-- En primera persona los accesorios de la cabeza y la cara del propio jugador taparían la vista (la visera de la gorra, las gafas):
-- se vuelven invisibles solo para él cuando la cámara está pegada a la cabeza. Los demás jugadores los siguen viendo.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local AccessoryFx = {}

local hidden = false

local function setHidden(character, value)
	for _, name in { "Acc_Head", "Acc_Face" } do
		local model = character:FindFirstChild(name)
		if model then
			for _, part in model:GetChildren() do
				if part:IsA("BasePart") then
					part.LocalTransparencyModifier = value and 1 or 0
				end
			end
		end
	end
end

function AccessoryFx.start()
	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		local camera = workspace.CurrentCamera
		if not (head and camera) then
			return
		end
		local close = (camera.CFrame.Position - head.Position).Magnitude < 1.6
		-- se aplica siempre mientras esté cerca (los accesorios pueden aparecer después de cambiar de vista)
		if close or hidden then
			setHidden(character, close)
			hidden = close
		end
	end)
end

return AccessoryFx
