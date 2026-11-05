-- Primera/tercera persona (tecla V). En ambas el jugador mira hacia donde apunta la cámara.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Controls = require(script.Parent.Controls)

local player = Players.LocalPlayer
local firstPerson = false
local aiming = false

local CameraController = {}

local function apply()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if firstPerson then
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 0.5
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		if humanoid then
			humanoid.CameraOffset = Vector3.zero
		end
	else
		local distance = Config.Camera.ThirdPersonDistance
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = distance
		player.CameraMaxZoomDistance = distance
		if humanoid then
			humanoid.CameraOffset = Config.Camera.ShoulderOffset
		end
	end
end

local function faceCamera()
	-- Menú de Roblox abierto (Esc): el cursor es suyo, no se vuelve a bloquear al centro cada cuadro
	if GuiService.MenuIsOpen then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		return
	end
	-- En la pantalla de resultados el cursor queda libre para poder pulsar "Volver al menú"
	if workspace:GetAttribute("Stage") == "Result" then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root) or humanoid.Health <= 0 then
		-- Sin personaje vivo el cursor no debe quedar bloqueado en el centro
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		return
	end
	-- Alt izquierdo: suelta el cursor un momento (por si una pantalla no lo libera)
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		return
	end
	-- Si lo están cargando, el cuerpo va soldado al que carga: no se gira
	if character:GetAttribute("Carried") then
		return
	end

	if player:GetAttribute("UiOpen") then -- tienda abierta: ratón libre y el cuerpo no gira
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		return
	end
	-- En modo táctil el ratón (si lo hay) queda libre para pulsar los botones
	local touch = Controls.isTouch()
	UserInputService.MouseBehavior = touch and Enum.MouseBehavior.Default or Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = touch
	humanoid.AutoRotate = false

	local look = workspace.CurrentCamera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.001 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
	end
end

-- Sensibilidad del ratón: la que eligió el jugador (AJUSTES), más baja al apuntar
local function applyMouseSensitivity()
	UserInputService.MouseDeltaSensitivity = Controls.getSensitivity() * (aiming and Config.Camera.AimSensitivity or 1)
end

local function setAiming(on)
	aiming = on
	applyMouseSensitivity()
end

-- Botón de apuntar del celular
function CameraController.setAiming(on)
	setAiming(on)
end

function CameraController.isAiming()
	return aiming
end

-- Alterna primera y tercera persona (tecla V o botón del celular)
function CameraController.toggleView()
	firstPerson = not firstPerson
	apply()
end

-- Zoom suave entre FOV normal y FOV de mira
local function updateZoom(dt)
	local camera = workspace.CurrentCamera
	local target = aiming and Config.Camera.AimFov or Config.Camera.NormalFov
	local alpha = 1 - math.exp(-Config.Camera.AimSpeed * dt)
	camera.FieldOfView += (target - camera.FieldOfView) * alpha
end

function CameraController.start()
	player.CharacterAdded:Connect(function()
		task.wait()
		apply()
	end)
	if player.Character then
		apply()
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.V then
			CameraController.toggleView()
		end
	end)

	UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			setAiming(true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			setAiming(false)
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		setAiming(false)
	end)
	Controls.sensitivityChanged:Connect(applyMouseSensitivity)

	RunService.RenderStepped:Connect(function(dt)
		faceCamera()
		updateZoom(dt)
	end)
end

return CameraController
