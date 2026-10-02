-- Boutons d'achat d'une usine.
--
-- Dans le modèle d'usine (ServerStorage/ModeleUsine) :
--   Boutons : un dossier qui contient les boutons (des Parts). Chaque bouton a :
--               - un attribut "Prix" (nombre) : obligatoire
--               - un attribut "Titre" (texte) : le nom affiché sur le panneau (optionnel)
--               - un attribut "Description" (texte) : 3e ligne du panneau, ex : "Valeur ×2" (optionnel)
--               - un attribut "Requiert" (texte) : le nom de l'achat à faire avant.
--                 Le bouton reste caché tant que cet achat n'est pas fait (optionnel)
--   Achats  : un dossier qui contient les objets à acheter, déjà placés
--             à leur position finale. Chaque objet porte EXACTEMENT
--             le même nom que son bouton.
--
-- Quand l'usine est créée, les objets à acheter sont cachés. Quand le
-- propriétaire marche sur un bouton et a assez d'argent, on lui retire le prix,
-- l'objet apparaît dans SON usine et le bouton disparaît.
-- Les autres joueurs ne peuvent pas utiliser ses boutons.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Format"))

local COULEUR_PAS_ASSEZ = Color3.fromRGB(255, 80, 80) -- clignotement si pas assez d'argent

local function ajouterPanneau(bouton, prix)
	local titre = bouton:GetAttribute("Titre") or bouton.Name
	local lignes = titre .. "\n" .. Format.nombre(prix) .. " $"

	local description = bouton:GetAttribute("Description")
	if typeof(description) == "string" then
		lignes ..= "\n" .. description
	end

	local panneau = Instance.new("BillboardGui")
	panneau.Size = UDim2.fromScale(7, 3)
	panneau.StudsOffset = Vector3.new(0, 3.5, 0)
	panneau.MaxDistance = 60
	panneau.Parent = bouton

	local texte = Instance.new("TextLabel")
	texte.Size = UDim2.fromScale(1, 1)
	texte.BackgroundTransparency = 1
	texte.TextScaled = true
	texte.Font = Enum.Font.FredokaOne
	texte.TextColor3 = Color3.fromRGB(255, 255, 255)
	texte.TextStrokeTransparency = 0
	texte.Text = lignes
	texte.Parent = panneau
end

-- Prépare les boutons de l'usine "usine", qui appartient à "proprietaire".
-- "achatsDejaFaits" est la liste des noms d'objets déjà achetés (venant de la
-- sauvegarde) : ils sont posés tout de suite, sans payer.
return function(usine, proprietaire, achatsDejaFaits)
	local dossierBoutons = usine:WaitForChild("Boutons")
	local dossierAchats = usine:WaitForChild("Achats")

	-- On retire les objets pas encore achetés de l'usine. On les garde
	-- dans cette liste (rangés par nom) pour les remettre au moment de l'achat.
	local objetsCaches = {}
	for _, objet in dossierAchats:GetChildren() do
		objetsCaches[objet.Name] = objet
		objet.Parent = nil -- l'objet garde sa position pour plus tard
	end

	local function estAchete(nom)
		return dossierAchats:FindFirstChild(nom) ~= nil
	end

	-- Le bouton fonctionne : panneau + achat quand le propriétaire marche dessus
	local function activerBouton(bouton, prix, objet)
		ajouterPanneau(bouton, prix)

		local couleurNormale = bouton.Color
		local achete = false
		local enAttente = false -- évite que le bouton clignote en boucle

		bouton.Touched:Connect(function(objetQuiTouche)
			if achete or enAttente then
				return
			end

			local joueur = Players:GetPlayerFromCharacter(objetQuiTouche.Parent)
			if joueur ~= proprietaire then
				return -- seul le propriétaire de l'usine peut acheter
			end

			local leaderstats = joueur:FindFirstChild("leaderstats")
			local argent = leaderstats and leaderstats:FindFirstChild("Argent")
			if argent == nil then
				return
			end

			if argent.Value < prix then
				-- Pas assez d'argent : le bouton devient rouge une seconde
				enAttente = true
				bouton.Color = COULEUR_PAS_ASSEZ
				task.wait(1)
				bouton.Color = couleurNormale
				enAttente = false
				return
			end

			achete = true
			argent.Value -= prix
			objet.Parent = dossierAchats
			bouton:Destroy()
		end)
	end

	-- 1re étape : on vérifie chaque bouton, et on repose tout de suite les
	-- objets déjà achetés (sauvegarde). On garde les autres boutons pour la suite.
	local boutonsRestants = {}
	for _, bouton in dossierBoutons:GetChildren() do
		if not bouton:IsA("BasePart") then
			continue
		end

		local prix = bouton:GetAttribute("Prix")
		if typeof(prix) ~= "number" then
			warn("Le bouton '" .. bouton.Name .. "' n'a pas d'attribut Prix (nombre) : ignoré")
			continue
		end

		local objet = objetsCaches[bouton.Name]
		if objet == nil then
			warn("Aucun objet nommé '" .. bouton.Name .. "' dans le dossier Achats : bouton ignoré")
			continue
		end

		if table.find(achatsDejaFaits, bouton.Name) then
			-- Déjà acheté lors d'une partie précédente : on pose l'objet directement
			objet.Parent = dossierAchats
			bouton:Destroy()
		else
			table.insert(boutonsRestants, { bouton = bouton, prix = prix, objet = objet })
		end
	end

	-- 2e étape : on active les boutons restants. Ceux dont l'achat requis
	-- n'est pas encore fait sont cachés, et réapparaissent au bon moment.
	for _, infos in boutonsRestants do
		local bouton = infos.bouton
		activerBouton(bouton, infos.prix, infos.objet)

		local requis = bouton:GetAttribute("Requiert")
		if typeof(requis) == "string" and not estAchete(requis) then
			bouton.Parent = nil -- caché pour l'instant

			local connexion
			connexion = dossierAchats.ChildAdded:Connect(function(objetAchete)
				if objetAchete.Name == requis then
					connexion:Disconnect()
					bouton.Parent = dossierBoutons -- le bouton apparaît
				end
			end)
		end
	end
end
