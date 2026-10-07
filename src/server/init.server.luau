-- Sin bloqueo de ratón (Shift lock): Shift es para correr y la cámara ya apunta sola (ver también default.project.json)
game:GetService("StarterPlayer").EnableMouseLockOption = false

local Weapons = require(script.Weapons)
local Dummies = require(script.Dummies)
local PlayerState = require(script.PlayerState)
local Revive = require(script.Revive)
local WeaponRig = require(script.WeaponRig)
local Director = require(script.Director)
local GameState = require(script.GameState)

Weapons.start()
Dummies.start()
PlayerState.start()
Revive.start()
WeaponRig.start()
Director.start()
GameState.start()
