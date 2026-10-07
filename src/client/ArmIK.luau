-- Cinemática inversa de un brazo R15 (hombro, codo, muñeca): calcula el Transform de cada Motor6D para que la muñeca
-- llegue a donde la palma agarra el arma. Todo en el marco del mundo; el cálculo no depende de la animación normal.
local ArmIK = {}

local EPSILON = 1e-3

-- Rotación mínima que lleva el vector unitario a hacia b
local function rotationBetween(a, b)
	local dot = a:Dot(b)
	if dot > 0.99999 then
		return CFrame.identity
	end
	local axis = a:Cross(b)
	if dot < -0.99999 or axis.Magnitude < 1e-6 then
		axis = a:Cross(Vector3.xAxis)
		if axis.Magnitude < 1e-3 then
			axis = a:Cross(Vector3.yAxis)
		end
		return CFrame.fromAxisAngle(axis.Unit, math.pi)
	end
	return CFrame.fromAxisAngle(axis.Unit, math.atan2(axis.Magnitude, dot))
end

-- Mide el brazo una vez: las articulaciones son Motor6D (hombro en el torso, codo en el brazo, muñeca en el antebrazo)
function ArmIK.new(shoulder, elbow, wrist)
	local upper = elbow.C0.Position - shoulder.C1.Position -- hombro -> codo, en el marco del brazo
	local lower = wrist.C0.Position - elbow.C1.Position -- codo -> muñeca, en el marco del antebrazo
	return {
		shoulder = shoulder,
		elbow = elbow,
		wrist = wrist,
		upper = upper,
		lower = lower,
		upperLength = upper.Magnitude,
		lowerLength = lower.Magnitude,
	}
end

-- torsoCF: CFrame de UpperTorso · handCF: dónde debe quedar la mano · pole: hacia dónde apunta el codo
-- Devuelve los Transform (solo rotación) del hombro, el codo y la muñeca.
function ArmIK.solve(arm, torsoCF, handCF, pole)
	local shoulder, elbow, wrist = arm.shoulder, arm.elbow, arm.wrist
	local l1, l2 = arm.upperLength, arm.lowerLength

	local shoulderCF = torsoCF * shoulder.C0
	local origin = shoulderCF.Position
	local goal = (handCF * wrist.C1).Position
	local toGoal = goal - origin
	local distance = toGoal.Magnitude
	local direction = distance > EPSILON and toGoal / distance or Vector3.new(0, 0, -1)
	local reach = math.clamp(distance, math.abs(l1 - l2) + EPSILON, l1 + l2 - EPSILON)

	-- El codo se dobla hacia `pole` (sin la parte paralela al brazo)
	local bend = pole - direction * pole:Dot(direction)
	bend = bend.Magnitude > EPSILON and bend.Unit or Vector3.new(0, -1, 0)
	local along = (l1 * l1 - l2 * l2 + reach * reach) / (2 * reach)
	local height = math.sqrt(math.max(l1 * l1 - along * along, 0))
	local elbowPos = origin + direction * along + bend * height
	local wristPos = origin + direction * reach

	-- Brazo: gira su eje hombro->codo hacia el codo, partiendo de la pose en reposo
	local restUpper = shoulderCF.Rotation * shoulder.C1.Rotation:Inverse()
	local upperRot = rotationBetween(restUpper * arm.upper.Unit, (elbowPos - origin).Unit) * restUpper
	local shoulderT = shoulderCF.Rotation:Inverse() * upperRot * shoulder.C1.Rotation
	local upperCF = shoulderCF * shoulderT * shoulder.C1:Inverse()

	-- Antebrazo: lo mismo, del codo a la muñeca
	local elbowCF = upperCF * elbow.C0
	local restLower = elbowCF.Rotation * elbow.C1.Rotation:Inverse()
	local lowerRot = rotationBetween(restLower * arm.lower.Unit, (wristPos - elbowPos).Unit) * restLower
	local elbowT = elbowCF.Rotation:Inverse() * lowerRot * elbow.C1.Rotation
	local lowerCF = elbowCF * elbowT * elbow.C1:Inverse()

	-- Mano: conserva la orientación pedida
	local wristCF = lowerCF * wrist.C0
	local wristT = wristCF.Rotation:Inverse() * handCF.Rotation * wrist.C1.Rotation

	return shoulderT, elbowT, wristT
end

return ArmIK
