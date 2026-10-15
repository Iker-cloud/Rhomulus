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
	"UseMedkit", -- cliente -> servidor: (jugador o nil) usar el botiquín en un compañero o en uno mismo
	"UseItem", -- cliente -> servidor: (id, dirección) usar el objeto que se tiene en la mano: lanza (con la carga) o venda
	"ReadyItem", -- cliente -> servidor: (id o nil) saca o guarda un objeto del inventario (se queda en la mano hasta usarlo)
	"ChargeItem", -- cliente -> servidor: (bool) empieza o cancela la carga del lanzamiento (granada, molotov, bengala)
	"Buy", -- cliente -> servidor: (id) comprar en una estación ("Ammo" o un objeto de Config.Items)
	"OpenShop", -- servidor -> cliente: (posición de la estación) abre la tienda
	"HelpSeen", -- cliente -> servidor: cerró la tarjeta de bienvenida del lobby (se guarda para no volver a mostrarla)
	"VoteDifficulty", -- cliente -> servidor: (id) vota la dificultad en la sala de votación
	"GroundReady", -- cliente -> servidor: ya tiene suelo cargado bajo los pies (suelta al personaje recién aparecido)
	"SkillCheck", -- servidor -> cliente: ("start", id, horaInicio, periodo, zonaInicio, zonaTamaño) | ("result", acertó) | ("cancel")
	"SaveSettings", -- cliente -> servidor: (sensibilidad, modo de calidad) guarda los ajustes del jugador
	"SkillCheckPress", -- cliente -> servidor: (id, horaDelServidor) pulsó Espacio durante la prueba
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
