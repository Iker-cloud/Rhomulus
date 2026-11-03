-- GENERADO desde assets/hacha.glb con tools/glb_to_lua.py (no editar a mano): piezas, colores y articulaciones.
-- Unidades en studs, con los pies en y = 0 y el frente hacia -Z. Cada pieza va soldada a su grupo; los grupos
-- se unen con Motor6D en las articulaciones (cadera, rodilla, hombro, codo, cuello, mandíbula).
return {
	rig = "MeleeAxe",
	scale = 1.0,
	minY = -0.002,
	maxY = 2.411,
	bounds = { min = Vector3.new(-0.497, -0.002, -0.065), max = Vector3.new(0.534, 2.411, 0.065) },
	root = { name = "hacha", cf = CFrame.new(0, 0, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1) },
	joints = {
		{ name = "cabeza", parent = "hacha", cf = CFrame.new(0, 2.17, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1) },
	},
	parts = {
		{ name = "mango", group = "hacha", shape = "Block", size = Vector3.new(0.1, 2.28, 0.072), cf = CFrame.new(0, 1.17, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1), color = Color3.fromRGB(138, 90, 46) },
		{ name = "pomo", group = "hacha", shape = "Cylinder", size = Vector3.new(0.13, 0.104, 0.104), cf = CFrame.new(0, 0.05, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1), color = Color3.fromRGB(138, 90, 46) },
		{ name = "agarre", group = "hacha", shape = "Block", size = Vector3.new(0.106, 0.5, 0.079), cf = CFrame.new(0, 0.38, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1), color = Color3.fromRGB(26, 26, 26) },
		{ name = "ojo", group = "cabeza", shape = "Block", size = Vector3.new(0.16, 0.27, 0.13), cf = CFrame.new(0, 2.17, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1), color = Color3.fromRGB(179, 20, 27) },
		{ name = "hoja", group = "cabeza", shape = "Block", size = Vector3.new(0.433, 0.557, 0.106), cf = CFrame.new(-0.27, 2.1198, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1), color = Color3.fromRGB(179, 20, 27) },
		{ name = "filo", group = "cabeza", shape = "Block", size = Vector3.new(0.102, 0.584, 0.064), cf = CFrame.new(-0.4459, 2.1189, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1), color = Color3.fromRGB(196, 200, 205) },
		{ name = "pico", group = "cabeza", shape = "Block", size = Vector3.new(0.455, 0.214, 0.086), cf = CFrame.new(0.2814, 2.17, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1), color = Color3.fromRGB(179, 20, 27) },
		{ name = "punta_pico", group = "cabeza", shape = "Cylinder", size = Vector3.new(0.09, 0.06, 0.06), cf = CFrame.new(0.49, 2.125, 0, 0.9689, -0.2474, 0, -0.2474, -0.9689, 0, 0, 0, -1), color = Color3.fromRGB(196, 200, 205) },
		{ name = "hoja_sangre_1", group = "cabeza", shape = "Block", size = Vector3.new(0.1, 0.24, 0.008), cf = CFrame.new(-0.4, 2.07, -0.054, -1, 0, 0, 0, 1, 0, 0, 0, -1), color = Color3.fromRGB(90, 7, 7) },
		{ name = "hoja_sangre_2", group = "cabeza", shape = "Block", size = Vector3.new(0.06, 0.08, 0.008), cf = CFrame.new(-0.33, 2.25, -0.054, 0.1288, 0.9917, 0, 0.9917, -0.1288, 0, 0, 0, -1), color = Color3.fromRGB(90, 7, 7) },
		{ name = "hoja_sangre_3", group = "cabeza", shape = "Block", size = Vector3.new(0.05, 0.06, 0.008), cf = CFrame.new(-0.28, 1.97, -0.054, -0.9211, 0.3894, 0, 0.3894, 0.9211, 0, 0, 0, -1), color = Color3.fromRGB(90, 7, 7) },
		{ name = "cuna", group = "hacha", shape = "Block", size = Vector3.new(0.04, 0.03, 0.11), cf = CFrame.new(0, 2.312, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1), color = Color3.fromRGB(58, 59, 62) },
	},
}
