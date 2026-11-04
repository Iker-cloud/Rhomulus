-- GENERADO desde assets/sarten.glb con tools/glb_to_lua.py (no editar a mano): piezas, colores y articulaciones.
-- Unidades en studs, con los pies en y = 0 y el frente hacia -Z. Cada pieza va soldada a su grupo; los grupos
-- se unen con Motor6D en las articulaciones (cadera, rodilla, hombro, codo, cuello, mandíbula).
return {
	rig = "MeleePan",
	scale = 1.0,
	minY = -0.010,
	maxY = 1.900,
	bounds = { min = Vector3.new(-0.555, -0.010, -0.155), max = Vector3.new(0.555, 1.900, 0.007) },
	root = { name = "sarten", cf = CFrame.new(0, 0, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1) },
	joints = {
	},
	parts = {
		{ name = "sarten", group = "sarten", shape = "Cylinder", size = Vector3.new(0.155, 1.11, 1.11), cf = CFrame.new(0, 1.345, -0.0775, 0, 1, 0, 0, 0, -1, -1, 0, -0), color = Color3.fromRGB(58, 59, 62) },
		{ name = "fondo_interior", group = "sarten", shape = "Cylinder", size = Vector3.new(0, 0.92, 0.92), cf = CFrame.new(0, 1.345, -0.026, 0, 0, -1, 0, 1, 0, 1, 0, 0), color = Color3.fromRGB(26, 26, 26) },
		{ name = "soporte", group = "sarten", shape = "Block", size = Vector3.new(0.1, 0.12, 0.03), cf = CFrame.new(0, 0.83, -0.1, -1, 0, 0, 0, 1, 0, 0, 0, -1), color = Color3.fromRGB(196, 200, 205) },
		{ name = "remache_1", group = "sarten", shape = "Cylinder", size = Vector3.new(0.012, 0.024, 0.024), cf = CFrame.new(0.03, 0.86, -0.12, 0, 1, 0, 0, 0, -1, -1, 0, -0), color = Color3.fromRGB(196, 200, 205) },
		{ name = "remache_2", group = "sarten", shape = "Cylinder", size = Vector3.new(0.012, 0.024, 0.024), cf = CFrame.new(-0.03, 0.86, -0.12, 0, 1, 0, 0, 0, -1, -1, 0, -0), color = Color3.fromRGB(196, 200, 205) },
		{ name = "vastago", group = "sarten", shape = "Cylinder", size = Vector3.new(0.3, 0.064, 0.064), cf = CFrame.new(0, 0.68, -0.1, 0, 1, 0, 1, 0, 0, 0, 0, -1), color = Color3.fromRGB(196, 200, 205) },
		{ name = "mango", group = "sarten", shape = "Block", size = Vector3.new(0.096, 0.56, 0.072), cf = CFrame.new(0, 0.3, -0.1, -1, 0, 0, 0, 1, 0, 0, 0, -1), color = Color3.fromRGB(26, 26, 26) },
		{ name = "aro_colgar", group = "sarten", shape = "Cylinder", size = Vector3.new(0.019, 0.09, 0.09), cf = CFrame.new(0, 0.035, -0.1, 1, 0, -0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(196, 200, 205) },
		{ name = "base_sangre_1", group = "sarten", shape = "Block", size = Vector3.new(0.32, 0.24, 0.008), cf = CFrame.new(-0.12, 1.25, 0.003, -1, 0, 0, 0, 1, 0, 0, 0, -1), color = Color3.fromRGB(90, 7, 7) },
		{ name = "base_sangre_2", group = "sarten", shape = "Block", size = Vector3.new(0.12, 0.1, 0.008), cf = CFrame.new(0.15, 1.45, 0.003, 0.1288, 0.9917, 0, 0.9917, -0.1288, 0, 0, 0, -1), color = Color3.fromRGB(90, 7, 7) },
		{ name = "base_sangre_3", group = "sarten", shape = "Block", size = Vector3.new(0.08, 0.07, 0.008), cf = CFrame.new(-0.25, 1.5, 0.003, -0.9211, 0.3894, 0, 0.3894, 0.9211, 0, 0, 0, -1), color = Color3.fromRGB(90, 7, 7) },
		{ name = "base_sangre_4", group = "sarten", shape = "Block", size = Vector3.new(0.1, 0.08, 0.008), cf = CFrame.new(0.05, 1.1, 0.003, 0.5048, 0.8632, 0, 0.8632, -0.5048, 0, 0, 0, -1), color = Color3.fromRGB(90, 7, 7) },
	},
}
