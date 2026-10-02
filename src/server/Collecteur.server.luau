-- Le collecteur accumule de l'argent tout seul, petit à petit.
-- Quand un joueur marche dessus, il récupère tout l'argent accumulé.

local Players = game:GetService("Players")

local ARGENT_PAR_TICK = 5 -- argent ajouté à chaque tick
local SECONDES_PAR_TICK = 1 -- durée entre deux ticks

-- Attend qu'une Part nommée "Collecteur" existe dans Workspace
local collecteur = workspace:WaitForChild("Collecteur")

local stock = 0 -- argent en attente dans le collecteur

-- Petit panneau flottant au-dessus du collecteur pour voir le stock
local panneau = Instance.new("BillboardGui")
panneau.Size = UDim2.fromScale(4, 1.5)
panneau.StudsOffset = Vector3.new(0, 3, 0)
panneau.AlwaysOnTop = true
panneau.Parent = collecteur

local texte = Instance.new("TextLabel")
texte.Size = UDim2.fromScale(1, 1)
texte.BackgroundTransparency = 1
texte.TextScaled = true
texte.Font = Enum.Font.FredokaOne
texte.TextColor3 = Color3.fromRGB(255, 255, 255)
texte.TextStrokeTransparency = 0
texte.Parent = panneau

local function mettreAJourPanneau()
	texte.Text = "🍬 " .. stock .. " $"
end

mettreAJourPanneau()

-- Quand quelque chose touche le collecteur
collecteur.Touched:Connect(function(objetQuiTouche)
	-- objetQuiTouche est une partie du corps (ex : un pied) ; son parent est le personnage
	local joueur = Players:GetPlayerFromCharacter(objetQuiTouche.Parent)
	if joueur == nil or stock == 0 then
		return
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

-- Boucle infinie : toutes les X secondes, le collecteur produit de l'argent
while true do
	task.wait(SECONDES_PAR_TICK)
	stock += ARGENT_PAR_TICK
	mettreAJourPanneau()
end
