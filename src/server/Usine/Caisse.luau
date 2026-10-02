-- La caisse d'une usine : les points de vente y déposent l'argent des bonbons
-- vendus. L'argent en attente est rangé dans l'attribut "Stock" de la Part Caisse.
-- Seul le propriétaire de l'usine peut marcher dessus pour récupérer l'argent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Format"))

local function ajouterPanneau(caisse)
	local panneau = Instance.new("BillboardGui")
	panneau.Size = UDim2.fromScale(8, 2)
	panneau.StudsOffset = Vector3.new(0, 3.5, 0)
	panneau.MaxDistance = 100
	panneau.Parent = caisse

	local texte = Instance.new("TextLabel")
	texte.Size = UDim2.fromScale(1, 1)
	texte.BackgroundTransparency = 1
	texte.TextScaled = true
	texte.Font = Enum.Font.FredokaOne
	texte.TextColor3 = Color3.fromRGB(255, 255, 255)
	texte.TextStrokeTransparency = 0
	texte.Parent = panneau

	return texte
end

-- Démarre la caisse de l'usine "usine", qui appartient à "proprietaire"
return function(usine, proprietaire)
	local caisse = usine:WaitForChild("Caisse")
	caisse:SetAttribute("Stock", 0)

	local texte = ajouterPanneau(caisse)
	local function mettreAJourPanneau()
		texte.Text = "💰 " .. Format.nombre(caisse:GetAttribute("Stock")) .. " $"
	end
	mettreAJourPanneau()

	-- Le panneau se met à jour tout seul à chaque vente
	caisse:GetAttributeChangedSignal("Stock"):Connect(mettreAJourPanneau)

	caisse.Touched:Connect(function(objetQuiTouche)
		-- objetQuiTouche est une partie du corps (ex : un pied) ; son parent est le personnage
		local joueur = Players:GetPlayerFromCharacter(objetQuiTouche.Parent)
		local stock = caisse:GetAttribute("Stock")
		if joueur ~= proprietaire or stock == 0 then
			return -- personne, un autre joueur, ou rien à récupérer
		end

		local leaderstats = joueur:FindFirstChild("leaderstats")
		local argent = leaderstats and leaderstats:FindFirstChild("Argent")
		if argent == nil then
			return
		end

		argent.Value += stock
		caisse:SetAttribute("Stock", 0)
	end)
end
