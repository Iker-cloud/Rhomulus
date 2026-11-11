-- Medidas de Remo One, el avión de rescate de Last Call, que comparten el servidor (server/PlaneBuilder pone la escalerilla, la
-- puerta y los asientos; server/Boarding sienta a quien sube) y el cliente (client/BoardingAnimator lleva al sobreviviente por la
-- escalerilla; client/PlaneAnimator mueve el avión, la puerta y la escalerilla). Mismo papel que shared/VanLayout para la furgoneta.
-- Todo en studs del modelo (ZombieData/RemoOne, ya a escala 3). Ejes del modelo: el morro mira hacia -Z, -X es el lado izquierdo
-- (el de la puerta delantera), el suelo es y = 0.
local PlaneLayout = {}

PlaneLayout.DoorX = -5.76 -- la piel del fuselaje a la altura de la puerta delantera izquierda
PlaneLayout.DoorY = 7.58 -- el umbral de la puerta (por donde se entra)
PlaneLayout.DoorZ = -38.84 -- centro de la puerta a lo largo del fuselaje
PlaneLayout.DoorSlide = 3.2 -- cuánto se corre la puerta hacia el morro al abrirse
PlaneLayout.StairRun = 13 -- cuánto se aleja del fuselaje el pie de la escalerilla
PlaneLayout.StairWidth = 4.4
PlaneLayout.StairSteps = 10
PlaneLayout.Floor = 7.6 -- suelo de la cabina
PlaneLayout.SitHeight = 1.49 -- cuánto por encima de la cara de arriba del asiento queda la raíz del personaje sentado
-- Fases del gesto de subir (fracciones de Config.Boarding.Duration): llegar al pie de la escalerilla, girarse, subirla, entrar hasta
-- el asiento. La última fracción hasta 1 es sentarse.
PlaneLayout.Phases = { 0.2, 0.26, 0.74, 0.93 }
PlaneLayout.WalkUp = true -- se sube caminando (sin la animación de trepar de la furgoneta)
PlaneLayout.BoardText = "Board Remo One"
PlaneLayout.FullText = "No free seats on Remo One"
-- Un asiento por jugador (hasta 4), dentro del fuselaje: side = lado de la puerta por la que se entra (siempre la izquierda)
PlaneLayout.Seats = {
	{ name = "Asiento1", side = -1, x = -2.6, z = -31 },
	{ name = "Asiento2", side = -1, x = 2.6, z = -31 },
	{ name = "Asiento3", side = -1, x = -2.6, z = -25 },
	{ name = "Asiento4", side = -1, x = 2.6, z = -25 },
}

return PlaneLayout
