-- Textos de la ayuda "Cómo jugar": los usan el menú (src-menu/client/Menu.client) y la partida (client/HelpPanel), así que
-- se editan aquí una sola vez. Las dificultades no están aquí: salen de shared/Difficulties.
return {
	Tabs = { "OBJETIVO", "CONTROLES", "CONSEJOS", "DIFICULTADES" },

	Headline = "SOBREVIVE\nJUNTO A TU EQUIPO",
	Objective = {
		"Cruza de noche el barrio Morro Esperanza hasta el estadio, llama a la radio y aguanta hasta que llegue la furgoneta.",
		"Basta con que uno suba para ganar. Si todos caen, se pierde. Nadie se queda atrás.",
	},

	Steps = {
		{ "VOTEN Y PREPÁRENSE", "Voten mapa y dificultad; practiquen y pulsen Y para empezar." },
		{ "CRUCEN EL BARRIO", "Tres tramos, tres rutas cada uno y dos puntos seguros." },
		{ "ABRAN LA IGLESIA", "Lleven las garrafas al generador de la plaza." },
		{ "LLEGUEN AL ESTADIO", "Crucen la terminal hasta el Refugio Remo." },
		{ "LLAMEN A LA RADIO", "Aguanten la horda hasta que llegue la furgoneta." },
	},

	-- Tres columnas de teclas: { título, { { tecla, qué hace }, ... } }
	Controls = {
		{ "COMBATE", {
			{ "CLIC", "DISPARAR" }, { "CLIC DER.", "APUNTAR" }, { "R", "RECARGAR" },
			{ "1 · 2 · Q", "CAMBIAR ARMA" }, { "SHIFT", "CORRER" }, { "V", "CAMBIAR CÁMARA" },
		} },
		{ "EQUIPO", {
			{ "E", "INTERACTUAR" }, { "F", "CARGAR AL CAÍDO" }, { "G", "SOLTAR" },
			{ "ESPACIO", "ACIERTA AL REVIVIR" }, { "H", "LEVANTARSE SOLO" }, { "Y", "LISTO EN EL LOBBY" },
		} },
		{ "OBJETOS", {
			{ "3", "GRANADA" }, { "4", "BOTIQUÍN" }, { "5", "MOLOTOV" },
			{ "6", "VENDAS" }, { "7", "BENGALA" }, { "1 – 4", "VOTAR DIFICULTAD" },
		} },
	},
	ControlsNote = "H solo se usa jugando solo (una vez por zona). K abre esta ayuda en la partida.",
	ControlsSide = "MEJOR CON TECLADO Y RATÓN",

	Tips = {
		{ "NO SE SEPAREN", "Un jugador solo cae rápido. Avancen juntos y cúbranse las espaldas." },
		{ "REVIVAN RÁPIDO", "Mantén E junto al caído y acierta con ESPACIO. Aguanta unos 30 s antes de morir." },
		{ "LAS LATAS SON DE TODOS", "Se ganan matando y se gastan en la caja de armas, la munición y los suministros." },
		{ "USEN LOS PUNTOS SEGUROS", "La tienda y la iglesia curan, recargan y dan un respiro antes de seguir." },
		{ "AGUANTEN EN LOS PASILLOS", "En campo abierto la horda los rodea. Usen puertas y esquinas." },
		{ "LANCEN BENGALAS", "Atraen a los zombies durante 15 s. Úsenlas para ganar tiempo." },
		{ "CUIDADO CON EL TANQUE", "Aguanta 600 de vida. Apunten a la cabeza y usen granadas y molotovs." },
		{ "EL TECHO NO ES SEGURO", "Los zombies trepan a los autobuses en 4 o 5 segundos." },
	},

	-- Tarjeta de bienvenida de la primera vez en el lobby (client/HelpPanel)
	Welcome = {
		Title = "BIENVENIDO A RHOMULUS",
		Lines = {
			"Cruza el barrio con tu equipo hasta el estadio y aguanta hasta que llegue la furgoneta.",
			"Apunta con el clic derecho y dispara con el clic. R recarga y Shift corre.",
			"E revive, abre y compra. F carga a un caído. 3 a 7 usan objetos.",
			"Cuando todos estén listos, pulsen Y.",
		},
	},
}
