-- Medidas de la furgoneta de rescate que comparten el servidor (server/VanInterior construye la caja por dentro y los asientos) y el
-- cliente (client/BoardingAnimator mueve al sobreviviente hasta su asiento; client/VanAnimator desliza las puertas). Todo en las
-- unidades del modelo (ZombieData/Furgoneta); hay que multiplicarlo por el atributo "Scale" de la furgoneta (Config.Game.VanScale).
-- Ejes del modelo: el frente mira hacia -Z, X+ es el lado derecho (puerta "der"), el suelo del modelo es y = 0.
local VanLayout = {}

VanLayout.HalfWidth = 2.64 -- la pared de la caja trasera está en x = ±HalfWidth
VanLayout.Floor = 2.388 -- altura del suelo de la caja
VanLayout.DoorZ = -0.6 -- centro de la puerta lateral (corredera)
VanLayout.DoorY = 4.68 -- centro de la puerta en altura
VanLayout.DoorSlide = 2.2 -- cuánto se desliza hacia el frente al abrirse
VanLayout.SeatX = 1.95 -- centro de los bancos (x = ±SeatX)
VanLayout.BenchHeight = 0.9 -- altura del banco sobre el suelo
-- Fases del gesto de subir (fracciones de Config.Boarding.Duration): llegar a la puerta, girarse, trepar al suelo de la caja, caminar
-- hasta el asiento. La última fracción hasta 1 es el giro para sentarse.
VanLayout.Phases = { 0.27, 0.33, 0.58, 0.88 }
-- Un asiento por jugador (hasta 4): side = lado de la puerta por la que se entra a ellos, z = posición a lo largo de la caja
VanLayout.Seats = {
	{ name = "Asiento1", side = 1, z = 2.2 },
	{ name = "Asiento2", side = -1, z = 2.2 },
	{ name = "Asiento3", side = 1, z = 4.9 },
	{ name = "Asiento4", side = -1, z = 4.9 },
}

return VanLayout
