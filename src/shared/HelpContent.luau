-- Textos de la ayuda "Cómo jugar": los usan el menú (src-menu/client/Menu.client) y la partida (client/HelpPanel), así que
-- se editan aquí una sola vez. Las dificultades no están aquí: salen de shared/Difficulties.
local Content = {
	Tabs = { "OBJECTIVE", "CONTROLS", "TIPS", "DIFFICULTIES" },

	Headline = "SURVIVE\nWITH YOUR TEAM",
	Objective = {
		"Cross Morro Esperanza at night to the stadium, call in the radio and hold out until the van arrives.",
		"It only takes one of you boarding to win. If everyone goes down, you lose. No one gets left behind.",
	},

	Steps = {
		{ "VOTE AND GET READY", "Vote on the difficulty, practice, then press Y to start." },
		{ "CROSS THE BARRIO", "Three sections, three routes each and two safe rooms." },
		{ "OPEN UP THE IGLESIA", "Bring the gas cans to the generator in the plaza." },
		{ "REACH THE STADIUM", "Cross the terminal to Refugio Remo." },
		{ "CALL THE RADIO", "Hold off the horde until the van arrives." },
	},

	-- Tres columnas de teclas: { título, { { tecla, qué hace }, ... } }
	Controls = {
		{ "COMBAT", {
			{ "CLICK", "SHOOT" }, { "RIGHT CLICK", "AIM" }, { "R", "RELOAD" },
			{ "1 · 2 · Q", "SWITCH WEAPON" }, { "SHIFT", "SPRINT" }, { "V", "SWITCH CAMERA" },
		} },
		{ "TEAM", {
			{ "E", "INTERACT" }, { "F", "CARRY TEAMMATE" }, { "G", "DROP" },
			{ "SPACE", "REVIVE CHECK" }, { "H", "SELF-REVIVE" }, { "Y", "READY IN LOBBY" },
		} },
		{ "ITEMS", {
			{ "3", "GRENADE" }, { "4", "MEDKIT" }, { "5", "MOLOTOV" },
			{ "6", "BANDAGES" }, { "7", "FLARE" }, { "X", "MELEE STRIKE" },
		} },
	},
	ControlsNote = "H only works when playing solo (once per zone). K opens this help in-game.",
	ControlsSide = "BEST WITH KEYBOARD AND MOUSE",

	Tips = {
		{ "STICK TOGETHER", "A lone player goes down fast. Move together and watch each other's backs." },
		{ "REVIVE FAST", "Hold E next to a downed teammate and hit SPACE on the check. They last about 30 s before dying." },
		{ "CANS BELONG TO THE TEAM", "You earn them by killing and spend them on the weapon box, ammo and supplies." },
		{ "USE THE SAFE ROOMS", "The tienda and the iglesia heal, restock and give you a breather before moving on." },
		{ "HOLD THE CHOKEPOINTS", "In the open the horde surrounds you. Use doors and corners." },
		{ "THROW FLARES", "They draw zombies for 15 s. Use them to buy time." },
		{ "WATCH OUT FOR THE TANK", "It has 1500 health on Tension. Aim for the head and use grenades and molotovs." },
		{ "THE ROOF ISN'T SAFE", "Zombies climb onto buses in 4 or 5 seconds." },
	},

	-- Tarjeta de bienvenida de la primera vez en el lobby (client/HelpPanel)
	Welcome = {
		Title = "WELCOME TO RHOMULUS",
		Lines = {
			"Cross the barrio with your team to the stadium and hold out until the van arrives.",
			"Aim with right click and shoot with click. R reloads and Shift sprints.",
			"E revives, opens and buys. F carries a downed teammate. 3 to 7 use items.",
			"When everyone is ready, press Y.",
		},
	},
}

-- Versión para pantallas táctiles: reemplaza solo lo que habla de teclas y ratón
Content.Touch = {
	Steps = table.clone(Content.Steps),
	Tips = table.clone(Content.Tips),
	Controls = {
		{ "COMBAT", {
			{ "FIRE", "SHOOT" }, { "AIM", "ZOOM IN" }, { "RELOAD", "RELOAD" },
			{ "SPRINT", "TOGGLE SPRINT" }, { "DRAG", "LOOK AROUND" }, { "VIEW", "SWITCH CAMERA" },
		} },
		{ "TEAM", {
			{ "E", "INTERACT" }, { "F", "CARRY TEAMMATE" }, { "DROP", "DROP THE CARRIED" },
			{ "TAP", "REVIVE CHECK" }, { "GET UP", "SELF-REVIVE" }, { "READY", "READY IN LOBBY" },
		} },
		{ "ITEMS", {
			{ "BAR", "TAP AN ITEM" }, { "FIRE", "USE OR THROW IT" }, { "CANCEL", "CANCEL THE THROW" },
			{ "MELEE", "MELEE STRIKE" }, { "SETTINGS", "SENSITIVITY" }, { "PANEL", "TAP TO VOTE" },
		} },
	},
	ControlsNote = "GET UP only appears when playing solo (once per zone). The E and F buttons appear when something is nearby.",
	ControlsSide = "BUILT FOR TOUCH SCREENS",
	Welcome = {
		Title = "WELCOME TO RHOMULUS",
		Lines = {
			"Cross the barrio with your team to the stadium and hold out until the van arrives.",
			"Drag your finger to look around. FIRE shoots, AIM zooms in and RELOAD reloads.",
			"The E button revives, opens and buys; F carries a downed teammate. Tap an item on the bar to draw it.",
			"When everyone is ready, tap READY.",
		},
	},
}
Content.Touch.Steps[1] = { "VOTE AND GET READY", "Vote on the difficulty, practice, then tap READY to start." }
Content.Touch.Tips[2] = { "REVIVE FAST", "Hold the E button next to a downed teammate and tap the button on the check. They last about 30 s before dying." }

-- Los textos que corresponden al dispositivo: HelpContent.get(true) en celular, HelpContent.get(false) en PC
function Content.get(touch)
	if not touch then
		return Content
	end
	local merged = table.clone(Content)
	for key, value in Content.Touch do
		merged[key] = value
	end
	return merged
end

return Content
