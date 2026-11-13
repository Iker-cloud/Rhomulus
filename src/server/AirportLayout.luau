-- Trazado de Last Call (aeropuerto de Rhomulus) en una cuadrícula: cada letra es una celda de 10 × 10 studs.
-- server/MapBuilderAirport la lee y levanta pisos, muros, techos y puntos de aparición; los muebles, puertas, tiendas y eventos
-- se colocan aparte, por coordenadas. Diseño: docs/mapa-2-aeropuerto.md.
--
-- Columnas = X (la 0 empieza en x = -140), filas = Z (la 0 empieza en z = -450; el mapa avanza hacia +Z).
-- Tres bandas: SERVICE (amarilla, columnas 1 a 8, túneles interiores) · CONCOURSE (roja, columnas 10 a 17, el terminal) ·
-- APRON (azul, columnas 19 a 26, exterior). Las columnas 9 y 18 son los muros que las separan (con pasos entre rutas).
--
--   #  muro del edificio (20 de alto)          .  piso interior (lleva techo)      ,  piso exterior (asfalto, sin techo)
--   s  piso interior + punto de aparición      x  piso exterior + punto de aparición
--   B  bulto exterior de 9 de alto (cobertura)  F  valla del perímetro              (espacio) nada
--   J  muro con un paso alto: el hueco de un finger (puente de embarque) a la altura de las pasarelas
--
-- Filas: 0 a 4 lobby (Lost & Found) · 5 a 26 sector 1 (Arrivals) · 27 a 30 Sky Lounge · 31 a 57 sector 2 (Departures) ·
-- 58 a 61 Fire Station · 62 a 77 sector 3 (Gates & Hangars) · 78 a 85 la plataforma de la extracción (la pista queda más al norte).
local AirportLayout = {}

AirportLayout.CELL = 10
AirportLayout.X0 = -140
AirportLayout.Z0 = -450

AirportLayout.ROWS = {
	"###################FFFFFFFFF", -- 0
	"#####....#........#,,,,,,,,F", -- 1  muelle de carga | lobby | acera de llegadas
	"#####..............,,,,,,,,F", -- 2  (puertas del lobby hacia Service y Apron)
	"#####....#........#,,,,,,,,F", -- 3
	"######.###........#,,,,,,,,F", -- 4
	"######.######..####,,,,,,,,F", -- 5  puerta principal del lobby
	"###s...###........#,,,,,,,,F", -- 6  recogida de equipaje
	"######.##s........#,,,,,,,,F", -- 7
	"######.###........#,,,BB,,,F", -- 8
	"##......##.........,,,BB,,,F", -- 9
	"##................#,,,,,,,,F", -- 10
	"##......##........#,,,,,,,,F", -- 11
	"###.######........#,,,,,,,xF", -- 12
	"###.########..##..#,,,,,,,,F", -- 13 aduana
	"###..s####........#,,,,,,,,F", -- 14 salón de llegadas
	"###.###...........#,,,BB,,,F", -- 15 Tienda 1 (Newsstand) en las columnas 7 a 9
	"###.###...........#,,,BB,,,F", -- 16
	"##.....###........#,,,,,,,,F", -- 17
	"##................#,,,,,,,,F", -- 18
	"##.....###........#,,,,,,,,F", -- 19
	"#####.####.........,,,,,,,,F", -- 20
	"##s...####........#,,,,,,,,F", -- 21
	"#####.###s........#,,,,,,,xF", -- 22
	"#####.####........#,,,,,,,,F", -- 23
	"#####.####........#,,,,,,,,F", -- 24
	"#####..............,,,,,,,,F", -- 25 las tres rutas se juntan
	"#############..#############", -- 26 entrada del Sky Lounge
	"###########......###########", -- 27 Sky Lounge
	"###########......###########", -- 28
	"#######..............#######", -- 29 (salidas laterales hacia Service y Apron)
	"#######.###......###.#######", -- 30
	"#######.#####..#####.#######", -- 31 salida del Sky Lounge
	"##......##........#,,,,,,,,F", -- 32 check-in
	"##......##........#,,,,,,,,F", -- 33
	"##......##.........,,,,,,,,F", -- 34
	"####.#####........#,,,BB,,,F", -- 35
	"####.####s........#,,,BB,,xF", -- 36
	"####....s#........#,,,,,,,,F", -- 37
	"####.#####........#,,,,,,,,F", -- 38
	"#.......##........#,,,,,,,,F", -- 39 sala de la cinta de equipaje
	"#.................#,,,,,,,,F", -- 40
	"#.......##........#,,,BB,,,F", -- 41
	"#.......##.........,,,BB,,,F", -- 42
	"#.......##........#,,,,,,,,F", -- 43
	"###.######........#,,,,,,,,F", -- 44
	"###.#######..##..##,,,,,,,xF", -- 45
	"###..s####........#,,,,,,,,F", -- 46 zona de comida
	"###.######........####,,,,,F", -- 47
	"###.######...........#,,,,,F", -- 48 Tienda 2 (Duty Free) en las columnas 18 a 20
	"###.######...........#,,,,,F", -- 49
	"##......##........####,,,,,F", -- 50
	"##................#,,,,,,,,F", -- 51
	"##......##........#,,,,,,,,F", -- 52
	"######.##s........#,,,,,,,,F", -- 53
	"######.###........#,,,,,,,,F", -- 54
	"######.............,,,,,,,,F", -- 55 control de seguridad: las tres rutas se juntan
	"######.............,,,,,,,,F", -- 56
	"#############..#############", -- 57 la puerta del control (Crew Call)
	"###########......###########", -- 58 Fire Station
	"###########......###########", -- 59
	"#######..............#######", -- 60
	"#######.###......###.#######", -- 61
	"#######.#####..#####.#######", -- 62 salida de la Fire Station
	"#######.####....###,,,,,,,,F", -- 63 pasillo de las puertas de embarque | plataforma
	"####.....###....s##,,,,,,,,F", -- 64 hangar (columnas 4 a 8)
	"#s.......#......###,,,,,,,,F", -- 65
	"####............###,,,,,,,,F", -- 66
	"####.....###....###,,,BB,,,F", -- 67
	"####.....###......J,,,BB,,xF", -- 68 (J: el finger de la puerta A2)
	"####.....###.......,,,,,,,,F", -- 69
	"#........###....###,,,,,,,,F", -- 70 Tienda 3 (Ground Crew Workshop) en las columnas 1 a 3
	"#........###....###,,,,,,,,F", -- 71
	"####.....##s....###,,,,,,,,F", -- 72
	"####.....#......###,,,BB,,,F", -- 73
	"#s..............###,,,BB,,,F", -- 74
	"####.....###......J,,,,,,,,F", -- 75 (J: el finger de la puerta A4)
	"####.....###.......,,,,,,,xF", -- 76
	"#####...####....###,,,,,,,,F", -- 77
	"F,,,,,,,,,,,,,,,,,,,,,,,,,,F", -- 78 plataforma de la extracción
	"F,,,,,,,,,,,,,,,,,,,,,,,,,,F", -- 79
	"F,###,,,,,,,,,,,,,,,,,,,,,xF", -- 80 base de la torre de control (columnas 2 a 4)
	"F,###,,,,,,,,,,,,,,,,,,,,,,F", -- 81
	"F,###,,,,,,,,,,,,,,,,,,,,,,F", -- 82
	"Fx,,,,,,,,,,,,,,,,,,,,,,,,,F", -- 83
	"F,,,,,,,,,,,,,,,,,,,,,,,,,,F", -- 84
	"F,,,,,,,,,,,,,,,,,,,,,,,,,xF", -- 85
}

-- Filas (desde, hasta) de cada zona: los puntos de aparición de esas filas van a Workspace/SpawnPoints/<zona>
AirportLayout.ZONES = {
	Zone1 = { 1, 25 },
	Zone2 = { 32, 56 },
	Zone3 = { 63, 77 },
	Extraction = { 78, 85 },
}

-- Puertas: { fila, columna desde, columna hasta }. GameState las abre y las cierra.
AirportLayout.DOORS = {
	lobby = { 5, 13, 14 },
	lobbyWest = { 2, 9, 9 },
	lobbyEast = { 2, 18, 18 },
	loungeEntry = { 26, 13, 14 },
	loungeExit = { 31, 13, 14 },
	loungeWest = { 29, 10, 10 },
	loungeEast = { 29, 17, 17 },
	security = { 57, 13, 14 },
	stationExit = { 62, 13, 14 },
	stationWest = { 60, 10, 10 },
	stationEast = { 60, 17, 17 },
}

-- Esquina de una celda: x de la columna y z de la fila (borde menor)
function AirportLayout.x(col)
	return AirportLayout.X0 + col * AirportLayout.CELL
end

function AirportLayout.z(row)
	return AirportLayout.Z0 + row * AirportLayout.CELL
end

-- Centro de una celda (o de un rango de celdas) a ras de suelo
function AirportLayout.center(row, col, row2, col2)
	row2, col2 = row2 or row, col2 or col
	return Vector3.new((AirportLayout.x(col) + AirportLayout.x(col2 + 1)) / 2, 0, (AirportLayout.z(row) + AirportLayout.z(row2 + 1)) / 2)
end

return AirportLayout
