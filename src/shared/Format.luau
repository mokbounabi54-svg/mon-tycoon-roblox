-- Petites fonctions pour afficher joliment les nombres.
-- Rangé dans ReplicatedStorage : les scripts serveur ET client peuvent s'en servir.

local Format = {}

-- Écrit un nombre avec des espaces entre les milliers : 250000 -> "250 000"
function Format.nombre(nombre)
	local texte = tostring(math.floor(nombre))
	return (texte:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", ""):gsub("^%- ", "-"))
end

return Format
