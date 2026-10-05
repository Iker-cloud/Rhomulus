-- Único canal cliente-servidor. El servidor los crea; el cliente los espera.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"Fire", -- cliente -> servidor: (origin, direction)
	"Reload", -- cliente -> servidor
	"Sync", -- cliente -> servidor: pide el estado de munición
	"AmmoUpdate", -- servidor -> cliente: (ammo, magSize, reloading)
	"Shot", -- servidor -> todos: (shooter, from, to) para dibujar el trazador
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
