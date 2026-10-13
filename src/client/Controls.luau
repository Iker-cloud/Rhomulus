-- Estado de entrada compartido entre PC y celular: modo táctil, apuntar/disparar virtuales y la sensibilidad del jugador.
-- Los módulos que antes leían el ratón directamente (Sprint, WeaponAnimator) preguntan aquí; client/TouchControls pone los botones.
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Controls = {}

Controls.aim = false -- botón de apuntar del celular (se alterna al tocarlo)
Controls.firing = false -- botón de disparo del celular mantenido

local touchMode = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local sensitivity = 1
local touchChanged = Instance.new("BindableEvent")
local sensitivityChanged = Instance.new("BindableEvent")

Controls.touchChanged = touchChanged.Event
Controls.sensitivityChanged = sensitivityChanged.Event

-- ¿Se juega con pantalla táctil ahora mismo? Un dispositivo híbrido cambia según lo último que el jugador tocó.
function Controls.isTouch()
	return touchMode
end

local function setTouchMode(value)
	if touchMode ~= value then
		touchMode = value
		touchChanged:Fire(value)
	end
end

UserInputService.LastInputTypeChanged:Connect(function(inputType)
	if inputType == Enum.UserInputType.Touch then
		if UserInputService.TouchEnabled then
			setTouchMode(true)
		end
	elseif inputType == Enum.UserInputType.Keyboard or inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.MouseMovement then
		setTouchMode(false)
	end
end)

-- ¿Está apuntando? (clic derecho o botón de apuntar)
function Controls.isAiming()
	return Controls.aim or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
end

-- ¿Está disparando? (clic izquierdo o botón de disparo)
function Controls.isFiring()
	return Controls.firing or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
end

function Controls.getSensitivity()
	return sensitivity
end

function Controls.setSensitivity(value)
	local T = Config.Touch
	value = math.clamp(math.round(value * 100) / 100, T.SensitivityMin, T.SensitivityMax)
	if value ~= sensitivity then
		sensitivity = value
		sensitivityChanged:Fire(value)
	end
end

return Controls
