-- Idiomas: el texto del juego está escrito en INGLÉS (idioma por defecto). Quien tiene Roblox en español lo ve traducido: `Lang.tr(texto)`
-- busca el texto en inglés en el diccionario de shared/LangEs (pares { inglés, español }) y devuelve el español; si no está, deja el texto.
-- Los textos con partes que cambian (nombres, cantidades) se escriben en el diccionario con huecos {1}, {2}…: "{1} revived {2}".
-- El servidor manda siempre inglés; cada cliente lo traduce al mostrarlo (`Lang.watch` revisa las etiquetas de la interfaz y los globos de texto).
-- No se traducen los nombres propios del mapa (Rhomulus, Morro Esperanza…), que ya están en español en el código.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Lang = {}

local override -- "en" o "es" (para pruebas y para un selector de idioma)
local spanish -- caché de isSpanish
local exact -- [texto en inglés en minúsculas] = español
local patterns -- { { pattern, template, literalLength } }
local cache = {}
local cacheSize = 0

local UPPER = { ["á"] = "Á", ["é"] = "É", ["í"] = "Í", ["ó"] = "Ó", ["ú"] = "Ú", ["ñ"] = "Ñ", ["ü"] = "Ü" }

-- Mayúsculas con acentos (string.upper no toca las letras con acento)
function Lang.upper(text)
	text = string.upper(text)
	return (string.gsub(text, "[\195][\161\169\173\179\186\177\188]", function(pair)
		return UPPER[pair] or pair
	end))
end

function Lang.setLanguage(code)
	override = code
	spanish = nil
	cache = {}
	cacheSize = 0
end

function Lang.isSpanish()
	if spanish == nil then
		if override then
			spanish = override == "es"
		else
			local player = RunService:IsClient() and Players.LocalPlayer
			local id = player and player.LocaleId or ""
			spanish = string.sub(string.lower(id), 1, 2) == "es"
		end
	end
	return spanish
end

local function escapeLiteral(text)
	-- minúsculas y mayúsculas por igual: cada letra pasa a [xX]; lo demás se escapa
	return (string.gsub(text, ".", function(c)
		if string.find(c, "%a") then
			return "[" .. string.lower(c) .. string.upper(c) .. "]"
		elseif string.find(c, "[%^%$%(%)%%%.%[%]%*%+%-%?]") then
			return "%" .. c
		end
		return c
	end))
end

local function load()
	exact, patterns = {}, {}
	local ok, pairsList = pcall(function()
		return require(script.Parent.LangEs)
	end)
	if not ok then
		return
	end
	for _, pair in pairsList do
		local en, es = pair[1], pair[2]
		if string.find(en, "{%d+}") then
			local pieces, literalLength, last = {}, 0, 1
			for start, index, stop in string.gmatch(en, "()%{(%d+)%}()") do
				local literal = string.sub(en, last, start - 1)
				literalLength += #literal
				table.insert(pieces, escapeLiteral(literal))
				table.insert(pieces, "(.-)")
				last = stop
			end
			local tail = string.sub(en, last)
			literalLength += #tail
			table.insert(pieces, escapeLiteral(tail))
			table.insert(patterns, { "^" .. table.concat(pieces) .. "$", es, literalLength })
		else
			exact[string.lower(en)] = es
		end
	end
	table.sort(patterns, function(a, b)
		return a[3] > b[3]
	end)
end

local function allCaps(text)
	return string.find(text, "%u") ~= nil and string.find(text, "%l") == nil
end

local function translate(text, depth)
	local key = string.lower(text)
	local found = exact[key]
	if found then
		if allCaps(text) then
			return Lang.upper(found)
		elseif not string.find(text, "%u") then
			return string.lower(found) -- el texto venía en minúsculas ("granada" dentro de una frase)
		end
		return found
	end
	if depth > 2 then
		return text
	end
	for _, entry in patterns do
		local captures = { string.match(text, entry[1]) }
		if #captures > 0 then
			local result = string.gsub(entry[2], "{(%d+)}", function(index)
				local piece = captures[tonumber(index)]
				if piece == nil then
					return ""
				end
				return translate(piece, depth + 1)
			end)
			return allCaps(text) and Lang.upper(result) or result
		end
	end
	return text
end

-- Traduce un texto del juego al idioma del jugador (inglés: el mismo texto)
function Lang.tr(text)
	if type(text) ~= "string" or text == "" or not Lang.isSpanish() then
		return text
	end
	if not string.find(text, "%a") then
		return text -- solo números o signos
	end
	if not exact then
		load()
	end
	local cached = cache[text]
	if cached then
		return cached
	end
	local result = translate(text, 0)
	if cacheSize > 3000 then
		cache, cacheSize = {}, 0
	end
	cache[text] = result
	cacheSize += 1
	return result
end

-- Etiquetas de interfaz: traduce el texto actual y cada cambio futuro (solo para quien juega en español)
local watched = setmetatable({}, { __mode = "k" })

local function watchLabel(label)
	if watched[label] then
		return
	end
	watched[label] = true
	local busy = false
	local function apply()
		if busy then
			return
		end
		local current = label.Text
		local translated = Lang.tr(current)
		if translated ~= current then
			busy = true
			label.Text = translated
			busy = false
		end
	end
	apply()
	label:GetPropertyChangedSignal("Text"):Connect(apply)
end

local function watchTree(root)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
			watchLabel(descendant)
		end
	end
	root.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
			watchLabel(descendant)
		end
	end)
end

-- Traduce toda la interfaz del jugador (`PlayerGui`) y los globos de texto del mundo (BillboardGui en Workspace)
function Lang.watch()
	if not Lang.isSpanish() then
		return
	end
	local player = Players.LocalPlayer
	task.spawn(function()
		watchTree(player:WaitForChild("PlayerGui"))
	end)
	-- Globos y carteles del mundo (BillboardGui y SurfaceGui, como los de la sala de votación)
	-- Un cartel con el atributo NoTranslate en su SurfaceGui se queda como está (los rótulos del aeropuerto van solo en inglés)
	local function worldLabel(descendant)
		if not descendant:IsA("TextLabel") then
			return
		end
		local surface = descendant:FindFirstAncestorOfClass("SurfaceGui")
		if surface and surface:GetAttribute("NoTranslate") then
			return
		end
		if surface or descendant:FindFirstAncestorOfClass("BillboardGui") then
			watchLabel(descendant)
		end
	end
	workspace.DescendantAdded:Connect(worldLabel)
	for _, descendant in workspace:GetDescendants() do
		worldLabel(descendant)
	end
end

return Lang
