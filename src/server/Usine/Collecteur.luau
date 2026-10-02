-- Le collecteur d'une usine accumule de l'argent tout seul, petit à petit,
-- et reçoit la valeur des bonbons qui tombent dessus.
-- Seul le propriétaire de l'usine peut marcher dessus pour récupérer l'argent.

local Players = game:GetService("Players")

local ARGENT_PAR_TICK = 5 -- argent ajouté à chaque tick
local SECONDES_PAR_TICK = 1 -- durée entre deux ticks

local function ajouterPanneau(collecteur)
	local panneau = Instance.new("BillboardGui")
	panneau.Size = UDim2.fromScale(4, 1.5)
	panneau.StudsOffset = Vector3.new(0, 3, 0)
	panneau.MaxDistance = 80
	panneau.Parent = collecteur

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

-- Démarre le collecteur de l'usine "usine", qui appartient à "proprietaire"
return function(usine, proprietaire)
	local collecteur = usine:WaitForChild("Collecteur")
	local texte = ajouterPanneau(collecteur)

	local stock = 0 -- argent en attente dans le collecteur

	local function mettreAJourPanneau()
		texte.Text = "🍬 " .. stock .. " $"
	end

	mettreAJourPanneau()

	collecteur.Touched:Connect(function(objetQuiTouche)
		-- Un bonbon tombé d'une machine : on ajoute sa valeur au stock et on le détruit
		local valeurBonbon = objetQuiTouche:GetAttribute("Valeur")
		if objetQuiTouche.Name == "Bonbon" and typeof(valeurBonbon) == "number" then
			objetQuiTouche:SetAttribute("Valeur", nil) -- pour ne pas le compter deux fois
			objetQuiTouche:Destroy()
			stock += valeurBonbon
			mettreAJourPanneau()
			return
		end

		-- objetQuiTouche est une partie du corps (ex : un pied) ; son parent est le personnage
		local joueur = Players:GetPlayerFromCharacter(objetQuiTouche.Parent)
		if joueur ~= proprietaire or stock == 0 then
			return -- personne, un autre joueur, ou rien à récupérer
		end

		local leaderstats = joueur:FindFirstChild("leaderstats")
		local argent = leaderstats and leaderstats:FindFirstChild("Argent")
		if argent == nil then
			return
		end

		argent.Value += stock
		stock = 0
		mettreAJourPanneau()
	end)

	-- task.spawn lance la boucle à côté, sans bloquer le reste du script.
	-- Elle s'arrête quand l'usine est détruite (le joueur est parti).
	task.spawn(function()
		while usine.Parent ~= nil do
			task.wait(SECONDES_PAR_TICK)
			stock += ARGENT_PAR_TICK
			mettreAJourPanneau()
		end
	end)
end
