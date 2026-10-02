-- Icônes 3D de bonbons (ViewportFrame) pour toutes les interfaces : inventaire,
-- carnet, sorcière. L'icône montre le modèle « Moule » du type (cœur, pastille,
-- étoile), aux couleurs de la rareté, comme dans l'usine.
--
-- Une seule caméra est partagée par toutes les icônes : chaque icône a sa propre
-- copie du bonbon, posée au même endroit (l'origine), donc la même vue convient.
-- Pour rester léger, on ne met un bonbon 3D que dans les icônes visibles
-- (Icones.remplir(vue, true/false)).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Reglages = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Reglages"))

local COULEUR_SILHOUETTE = Color3.fromHex("D5C9E6") -- bonbon pas encore découvert (carnet)
local COULEUR_RATE = Color3.fromHex("9C8F86") -- « Bonbon raté » de la sorcière

local infosRarete = {}
for _, infos in Reglages.Raretes do
	infosRarete[infos.Nom] = infos
end

local Icones = {}

Icones.camera = Instance.new("Camera")
Icones.camera.FieldOfView = 30
Icones.camera.CFrame = CFrame.lookAt(Vector3.new(0, 1.9, -2.7), Vector3.new(0, -0.2, 0))

-- Une copie du bonbon à mettre dans une icône.
-- silhouette = true : tout en gris clair (bonbon pas encore découvert)
function Icones.copierBonbon(typeBonbon, nomRarete, silhouette)
	local dossier = ReplicatedStorage:FindFirstChild("ModelesBonbons")
	local dossierType = dossier and dossier:FindFirstChild(typeBonbon)
	local source = dossierType and dossierType:FindFirstChild("Moule")

	local modele
	if source then
		modele = source:Clone()
	else
		-- Pas de modèle pour ce type (ou « Bonbon raté ») : une boule de sa couleur
		modele = Instance.new("Model")
		local boule = Instance.new("Part")
		boule.Shape = Enum.PartType.Ball
		boule.Size = Vector3.one
		boule.Material = Enum.Material.SmoothPlastic
		local infosType = Reglages.Types[typeBonbon]
		boule.Color = if infosType then infosType.Couleur else COULEUR_RATE
		boule:SetAttribute("Teinte", infosType ~= nil) -- un bonbon raté garde sa couleur
		boule.Parent = modele
	end

	local infos = infosRarete[nomRarete]
	local matiere = infos and infos.Matiere and Enum.Material[infos.Matiere]
	for _, piece in modele:GetDescendants() do
		if piece:IsA("BasePart") then
			if silhouette then
				piece.Color = COULEUR_SILHOUETTE
				piece.Material = Enum.Material.SmoothPlastic
			elseif piece:GetAttribute("Teinte") then
				-- Couleur et matière de la rareté, seulement sur les pièces Teinte
				if infos and infos.Couleur then
					piece.Color = infos.Couleur
				end
				if matiere then
					piece.Material = matiere
				end
			end
		end
	end
	modele:PivotTo(CFrame.new())
	return modele
end

-- Crée une icône vide (le bonbon 3D est ajouté par Icones.remplir)
function Icones.creer(parent, typeBonbon, nomRarete, taille, position, silhouette)
	local vue = Instance.new("ViewportFrame")
	vue.Name = "Icone"
	vue.BackgroundTransparency = 1
	vue.Size = UDim2.fromOffset(taille, taille)
	vue.Position = position or UDim2.new()
	vue.CurrentCamera = Icones.camera
	vue.Ambient = Color3.fromRGB(190, 180, 200)
	vue.LightColor = Color3.new(1, 1, 1)
	vue.LightDirection = Vector3.new(-0.5, -1, 0.6)
	vue:SetAttribute("Type", typeBonbon)
	vue:SetAttribute("Rarete", nomRarete)
	vue:SetAttribute("Silhouette", silhouette == true)
	vue.Parent = parent
	return vue
end

-- Met (visible = true) ou retire (false) le bonbon 3D d'une icône
function Icones.remplir(vue, visible)
	local dejaRemplie = vue:FindFirstChildOfClass("Model") ~= nil
	if visible and not dejaRemplie then
		Icones.copierBonbon(vue:GetAttribute("Type"), vue:GetAttribute("Rarete"), vue:GetAttribute("Silhouette")).Parent = vue
	elseif not visible and dejaRemplie then
		vue:FindFirstChildOfClass("Model"):Destroy()
	end
end

return Icones
