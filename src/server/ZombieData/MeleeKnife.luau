-- GENERADO desde assets/cuchillo.glb con tools/glb_to_lua.py (no editar a mano): piezas, colores y articulaciones.
-- Unidades en studs, con los pies en y = 0 y el frente hacia -Z. Cada pieza va soldada a su grupo; los grupos
-- se unen con Motor6D en las articulaciones (cadera, rodilla, hombro, codo, cuello, mandíbula).
return {
	rig = "MeleeKnife",
	scale = 1.0,
	minY = 0.000,
	maxY = 1.504,
	bounds = { min = Vector3.new(-0.130, 0.000, -0.038), max = Vector3.new(0.130, 1.504, 0.038) },
	root = { name = "cuchillo", cf = CFrame.new(0, 0, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1) },
	joints = {
	},
	parts = {
		{ name = "pomo", group = "cuchillo", shape = "Block", size = Vector3.new(0.1, 0.06, 0.075), cf = CFrame.new(0, 0.03, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1), color = Color3.fromRGB(58, 59, 62) },
		{ name = "mango", group = "cuchillo", shape = "Block", size = Vector3.new(0.092, 0.5, 0.063), cf = CFrame.new(0, 0.31, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1), color = Color3.fromRGB(26, 26, 26) },
		{ name = "anillo_1", group = "cuchillo", shape = "Block", size = Vector3.new(0.104, 0.071, 0.016), cf = CFrame.new(0, 0.17, 0, -1, 0, 0, 0, 0, -1, 0, -1, -0), color = Color3.fromRGB(26, 26, 26) },
		{ name = "anillo_2", group = "cuchillo", shape = "Block", size = Vector3.new(0.104, 0.071, 0.016), cf = CFrame.new(0, 0.27, 0, -1, 0, 0, 0, 0, -1, 0, -1, -0), color = Color3.fromRGB(26, 26, 26) },
		{ name = "anillo_3", group = "cuchillo", shape = "Block", size = Vector3.new(0.104, 0.071, 0.016), cf = CFrame.new(0, 0.37, 0, -1, 0, 0, 0, 0, -1, 0, -1, -0), color = Color3.fromRGB(26, 26, 26) },
		{ name = "anillo_4", group = "cuchillo", shape = "Block", size = Vector3.new(0.104, 0.071, 0.016), cf = CFrame.new(0, 0.47, 0, -1, 0, 0, 0, 0, -1, 0, -1, -0), color = Color3.fromRGB(26, 26, 26) },
		{ name = "guarda", group = "cuchillo", shape = "Block", size = Vector3.new(0.26, 0.035, 0.07), cf = CFrame.new(0, 0.578, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1), color = Color3.fromRGB(58, 59, 62) },
		{ name = "hoja", group = "cuchillo", shape = "Block", size = Vector3.new(0.161, 0.913, 0.034), cf = CFrame.new(-0.005, 1.047, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1), color = Color3.fromRGB(196, 200, 205) },
		{ name = "lomo_dientes", group = "cuchillo", shape = "Block", size = Vector3.new(0.012, 0.22, 0.022), cf = CFrame.new(0.071, 0.82, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1), color = Color3.fromRGB(58, 59, 62) },
		{ name = "hoja_sangre_1", group = "cuchillo", shape = "Block", size = Vector3.new(0.08, 0.18, 0.008), cf = CFrame.new(-0.03, 1.25, -0.0185, -1, 0, 0, 0, 1, 0, 0, 0, -1), color = Color3.fromRGB(90, 7, 7) },
		{ name = "hoja_sangre_2", group = "cuchillo", shape = "Block", size = Vector3.new(0.05, 0.08, 0.008), cf = CFrame.new(0, 1.12, -0.0185, 0.1288, 0.9917, 0, 0.9917, -0.1288, 0, 0, 0, -1), color = Color3.fromRGB(90, 7, 7) },
		{ name = "hoja_sangre_3", group = "cuchillo", shape = "Block", size = Vector3.new(0.036, 0.06, 0.008), cf = CFrame.new(-0.05, 1.02, -0.0185, -0.9211, 0.3894, 0, 0.3894, 0.9211, 0, 0, 0, -1), color = Color3.fromRGB(90, 7, 7) },
		{ name = "hoja_sangre_4", group = "cuchillo", shape = "Block", size = Vector3.new(0.04, 0.07, 0.008), cf = CFrame.new(0.02, 1.33, -0.0185, 0.5048, 0.8632, 0, 0.8632, -0.5048, 0, 0, 0, -1), color = Color3.fromRGB(90, 7, 7) },
	},
}
