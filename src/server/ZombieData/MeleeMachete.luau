-- GENERADO desde assets/machete.glb con tools/glb_to_lua.py (no editar a mano): piezas, colores y articulaciones.
-- Unidades en studs, con los pies en y = 0 y el frente hacia -Z. Cada pieza va soldada a su grupo; los grupos
-- se unen con Motor6D en las articulaciones (cadera, rodilla, hombro, codo, cuello, mandíbula).
return {
	rig = "MeleeMachete",
	scale = 1.0,
	minY = -0.000,
	maxY = 2.206,
	bounds = { min = Vector3.new(-0.166, -0.000, -0.039), max = Vector3.new(0.105, 2.206, 0.039) },
	root = { name = "machete", cf = CFrame.new(0, 0, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1) },
	joints = {
	},
	parts = {
		{ name = "espiga", group = "machete", shape = "Block", size = Vector3.new(0.104, 0.62, 0.026), cf = CFrame.new(0, 0.31, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1), color = Color3.fromRGB(58, 59, 62) },
		{ name = "cacha_1", group = "machete", shape = "Block", size = Vector3.new(0.096, 0.56, 0.024), cf = CFrame.new(0, 0.3, -0.025, -1, 0, 0, 0, 1, 0, 0, 0, -1), color = Color3.fromRGB(138, 90, 46) },
		{ name = "cacha_2", group = "machete", shape = "Block", size = Vector3.new(0.096, 0.56, 0.024), cf = CFrame.new(0, 0.3, 0.025, -1, 0, 0, 0, 1, 0, 0, 0, -1), color = Color3.fromRGB(138, 90, 46) },
		{ name = "remache_1", group = "machete", shape = "Cylinder", size = Vector3.new(0.078, 0.028, 0.028), cf = CFrame.new(0, 0.12, 0, 0, 1, 0, 0, 0, -1, -1, 0, -0), color = Color3.fromRGB(196, 200, 205) },
		{ name = "remache_2", group = "machete", shape = "Cylinder", size = Vector3.new(0.078, 0.028, 0.028), cf = CFrame.new(0, 0.3, 0, 0, 1, 0, 0, 0, -1, -1, 0, -0), color = Color3.fromRGB(196, 200, 205) },
		{ name = "remache_3", group = "machete", shape = "Cylinder", size = Vector3.new(0.078, 0.028, 0.028), cf = CFrame.new(0, 0.48, 0, 0, 1, 0, 0, 0, -1, -1, 0, -0), color = Color3.fromRGB(196, 200, 205) },
		{ name = "hoja", group = "machete", shape = "Block", size = Vector3.new(0.271, 1.611, 0.028), cf = CFrame.new(-0.0308, 1.4008, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1), color = Color3.fromRGB(196, 200, 205) },
		{ name = "recazo", group = "machete", shape = "Block", size = Vector3.new(0.21, 0.05, 0.032), cf = CFrame.new(0, 0.62, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1), color = Color3.fromRGB(58, 59, 62) },
		{ name = "hoja_sangre_1", group = "machete", shape = "Block", size = Vector3.new(0.12, 0.28, 0.008), cf = CFrame.new(-0.06, 1.75, -0.0145, -1, 0, 0, 0, 1, 0, 0, 0, -1), color = Color3.fromRGB(90, 7, 7) },
		{ name = "hoja_sangre_2", group = "machete", shape = "Block", size = Vector3.new(0.06, 0.1, 0.008), cf = CFrame.new(-0.1, 1.5, -0.0145, 0.1288, 0.9917, 0, 0.9917, -0.1288, 0, 0, 0, -1), color = Color3.fromRGB(90, 7, 7) },
		{ name = "hoja_sangre_3", group = "machete", shape = "Block", size = Vector3.new(0.08, 0.12, 0.008), cf = CFrame.new(-0.02, 1.95, -0.0145, -0.9211, 0.3894, 0, 0.3894, 0.9211, 0, 0, 0, -1), color = Color3.fromRGB(90, 7, 7) },
		{ name = "hoja_sangre_4", group = "machete", shape = "Block", size = Vector3.new(0.04, 0.06, 0.008), cf = CFrame.new(-0.12, 1.3, -0.0145, 0.5048, 0.8632, 0, 0.8632, -0.5048, 0, 0, 0, -1), color = Color3.fromRGB(90, 7, 7) },
	},
}
