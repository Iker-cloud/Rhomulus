-- Interfaz en pantallas pequeñas (celular en horizontal): casi todo el HUD usa tamaños fijos en píxeles, pensados para PC.
--   · UiFit.scale(objeto) encoge una pieza del HUD según la altura de la pantalla (1 con 520 o más, hasta 0.6 en las muy bajas).
--   · UiFit.fitPanel(panel, ancho, alto) achica un panel centrado hasta que cabe entero.
--   · UiFit.start() pone las zonas seguras (muescas y esquinas redondeadas) a los ScreenGui del HUD.
-- No se usa un UIScale en el ScreenGui entero: los fondos a pantalla completa quedarían más pequeños que la pantalla.
local Players = game:GetService("Players")

local UiFit = {}

local FULL_HEIGHT = 520 -- a partir de esta altura el HUD va a tamaño normal
local MIN_SCALE = 0.6

-- ScreenGui del HUD que respetan la zona segura. Las ventanas y fondos a pantalla completa (ayuda, tienda, resultados,
-- espectador) se quedan fuera: ahí el borde sí debe cubrirse.
local SAFE = {
	AmmoHud = true,
	HealthHud = true,
	LatasHud = true,
	ContribHud = true,
	TeamHud = true,
	GameHud = true,
	RadioHud = true,
	Inventory = true,
	MedkitHud = true,
	ItemUse = true,
	DifficultyVote = true,
	MutatorHud = true,
	PhialSlot = true,
}

local function camera()
	return workspace.CurrentCamera
end

function UiFit.factor()
	return math.clamp(camera().ViewportSize.Y / FULL_HEIGHT, MIN_SCALE, 1)
end

-- Encoge `object` (y todo lo que lleva dentro) con la altura de la pantalla; devuelve el UIScale
function UiFit.scale(object)
	local scale = Instance.new("UIScale")
	scale.Name = "UiFit"
	scale.Scale = UiFit.factor()
	scale.Parent = object
	camera():GetPropertyChangedSignal("ViewportSize"):Connect(function()
		scale.Scale = UiFit.factor()
	end)
	return scale
end

-- Un panel centrado de ancho × alto fijo se achica solo lo justo para caber en la pantalla
function UiFit.fitPanel(panel, width, height)
	local scale = Instance.new("UIScale")
	scale.Name = "UiFit"
	local function update()
		local viewport = camera().ViewportSize
		scale.Scale = math.clamp(math.min(viewport.Y * 0.94 / height, viewport.X * 0.96 / width), 0.4, 1)
	end
	update()
	scale.Parent = panel
	camera():GetPropertyChangedSignal("ViewportSize"):Connect(update)
	return scale
end

-- ¿Es una pantalla baja? (los paneles muy grandes cambian a una versión compacta)
function UiFit.isShort()
	return camera().ViewportSize.Y < 480
end

function UiFit.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local function setup(gui)
		if gui:IsA("ScreenGui") and SAFE[gui.Name] then
			gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
		end
	end
	for _, gui in playerGui:GetChildren() do
		setup(gui)
	end
	playerGui.ChildAdded:Connect(setup)
end

return UiFit
