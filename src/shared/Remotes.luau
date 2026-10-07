-- Único canal cliente-servidor. El servidor los crea; el cliente los espera.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"Fire", -- cliente -> servidor: (origin, direction)
	"Reload", -- cliente -> servidor
	"Sync", -- cliente -> servidor: pide el estado de munición
	"AmmoUpdate", -- servidor -> cliente: (ammo, magSize, reloading)
	"SelfRevive", -- cliente -> servidor: levantarse solo (solo con 1 jugador)
	"Switch", -- cliente -> servidor: "primary" o "pistol"
	"Feed", -- servidor -> cliente(s): (texto) aviso en pantalla
	"Ready", -- cliente -> servidor: listo en el lobby
	"Results", -- servidor -> todos: (won, stats) al terminar la partida
	"Drop", -- cliente -> servidor: soltar al compañero que se carga
	"Shot", -- servidor -> todos: (shooter, from, endPoints, weaponKey) trazadores y sonido
	"Sprint", -- cliente -> servidor: (bool) quiere correr
	"Crit", -- servidor -> cliente: (killed) el disparo le dio a la cabeza de un zombie
	"Aim", -- cliente -> servidor: (pitch, aiming) hacia dónde mira, para que los demás vean el arma
}

local folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local Remotes = {}
for _, name in NAMES do
	Remotes[name] = folder:WaitForChild(name)
end
return Remotes
