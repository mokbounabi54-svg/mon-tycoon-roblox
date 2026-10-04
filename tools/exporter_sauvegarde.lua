-- EXPORTER MA SAUVEGARDE (LECTURE SEULE)
--
-- Version lisible et commentée. Si la barre de commande refuse plusieurs lignes, utilise
-- tools/exporter_sauvegarde_une_ligne.lua (même chose, en une seule ligne, sans commentaires).
--
-- À quoi ça sert : garder une copie texte de ta vraie sauvegarde (DataStore "Joueurs_v2")
-- AVANT ta première partie normale avec le mode hybride (elle passera alors en version 6).
--
-- Comment l'utiliser :
--   1. Dans Studio, en mode ÉDITION (pas en partie) : Accueil → Paramètres du jeu → Sécurité →
--      « Activer l'accès de Studio aux services API » doit être coché.
--   2. Affichage → Barre de commande. Copie TOUT ce fichier, colle-le dans la barre, appuie sur Entrée.
--   3. La sortie affiche ta sauvegarde en texte (format JSON) entre deux lignes « ===== ».
--      Copie ce texte dans un fichier (par exemple docs/sauvegarde_avant_v6.txt, hors de Git si
--      tu préfères) et garde-le.
--
-- Ce script ne fait QUE lire : GetAsync et ListVersionsAsync. Il n'écrit, ne modifie et ne
-- supprime rien. Il ne lit que TA case (ton UserId).

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local StudioService = game:GetService("StudioService")

local NOM_DATASTORE = "Joueurs_v2"
local userId = StudioService:GetUserId() -- le compte connecté à Studio (toi)
-- Si la ligne ci-dessus donne 0, remplace-la par ton UserId, par exemple : local userId = 123456789
local cle = "joueur_" .. userId

local store = DataStoreService:GetDataStore(NOM_DATASTORE)

-- 1. La sauvegarde actuelle (UseCache = false : la vraie valeur, pas une copie en cache)
local options = Instance.new("DataStoreGetOptions")
options.UseCache = false
local ok, donnees, infos = pcall(function()
	return store:GetAsync(cle, options)
end)
if not ok then
	warn("Lecture impossible : " .. tostring(donnees))
	return
end
if donnees == nil then
	warn("Aucune sauvegarde trouvée pour la clé " .. cle .. " dans " .. NOM_DATASTORE)
	return
end

local texte = HttpService:JSONEncode(donnees)
print("===== DÉBUT DE LA SAUVEGARDE " .. NOM_DATASTORE .. " / " .. cle .. " =====")
if infos then
	print("Version Roblox : " .. tostring(infos.Version) .. " ; modifiée le " .. DateTime.fromUnixTimestampMillis(infos.UpdatedTime):FormatLocalTime("LLL", "fr-fr"))
end
-- La sortie de Studio coupe les lignes très longues : on affiche le texte par morceaux
local TAILLE_MORCEAU = 1500
for debut = 1, #texte, TAILLE_MORCEAU do
	print(string.sub(texte, debut, debut + TAILLE_MORCEAU - 1))
end
print("===== FIN DE LA SAUVEGARDE (" .. #texte .. " caractères ; recolle les morceaux sans espace) =====")

-- 2. Les anciennes versions gardées par Roblox (environ 30 jours), pour information
local okVersions, pages = pcall(function()
	return store:ListVersionsAsync(cle, Enum.SortDirection.Descending, nil, nil, 10)
end)
if okVersions then
	print("10 dernières versions gardées par Roblox (la plus récente en premier) :")
	for _, version in pages:GetCurrentPage() do
		print("  " .. version.Version .. "  " .. DateTime.fromUnixTimestampMillis(version.CreatedTime):FormatLocalTime("LLL", "fr-fr"))
	end
else
	warn("Liste des versions impossible : " .. tostring(pages))
end
