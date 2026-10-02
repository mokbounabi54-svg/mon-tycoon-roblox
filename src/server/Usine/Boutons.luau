-- Boutons d'achat d'une usine.
--
-- Dans le modèle d'usine (ServerStorage/ModeleUsine) :
--   Boutons : un dossier qui contient les boutons (des Parts).
--             Chaque bouton a un attribut "Prix" (nombre).
--   Achats  : un dossier qui contient les objets à acheter, déjà placés
--             à leur position finale. Chaque objet porte EXACTEMENT
--             le même nom que son bouton.
--
-- Quand l'usine est créée, les objets à acheter sont cachés. Quand le
-- propriétaire marche sur un bouton et a assez d'argent, on lui retire le prix,
-- l'objet apparaît dans SON usine et le bouton disparaît.
-- Les autres joueurs ne peuvent pas utiliser ses boutons.

local Players = game:GetService("Players")

local COULEUR_PAS_ASSEZ = Color3.fromRGB(255, 80, 80) -- clignotement si pas assez d'argent

local function ajouterPanneau(bouton, prix)
	local panneau = Instance.new("BillboardGui")
	panneau.Size = UDim2.fromScale(6, 2)
	panneau.StudsOffset = Vector3.new(0, 3, 0)
	panneau.MaxDistance = 60
	panneau.Parent = bouton

	local texte = Instance.new("TextLabel")
	texte.Size = UDim2.fromScale(1, 1)
	texte.BackgroundTransparency = 1
	texte.TextScaled = true
	texte.Font = Enum.Font.FredokaOne
	texte.TextColor3 = Color3.fromRGB(255, 255, 255)
	texte.TextStrokeTransparency = 0
	texte.Text = bouton.Name .. "\n" .. prix .. " $"
	texte.Parent = panneau
end

-- Prépare les boutons de l'usine "usine", qui appartient à "proprietaire"
return function(usine, proprietaire)
	local dossierBoutons = usine:WaitForChild("Boutons")
	local dossierAchats = usine:WaitForChild("Achats")

	-- On retire les objets pas encore achetés de l'usine. On les garde
	-- dans cette liste (rangés par nom) pour les remettre au moment de l'achat.
	local objetsCaches = {}
	for _, objet in dossierAchats:GetChildren() do
		objetsCaches[objet.Name] = objet
		objet.Parent = nil -- l'objet garde sa position pour plus tard
	end

	local function preparerBouton(bouton)
		if not bouton:IsA("BasePart") then
			return
		end

		local prix = bouton:GetAttribute("Prix")
		if typeof(prix) ~= "number" then
			warn("Le bouton '" .. bouton.Name .. "' n'a pas d'attribut Prix (nombre) : ignoré")
			return
		end

		local objet = objetsCaches[bouton.Name]
		if objet == nil then
			warn("Aucun objet nommé '" .. bouton.Name .. "' dans le dossier Achats : bouton ignoré")
			return
		end

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

	for _, bouton in dossierBoutons:GetChildren() do
		preparerBouton(bouton)
	end
end
