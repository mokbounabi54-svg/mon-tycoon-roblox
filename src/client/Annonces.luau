-- Affiche en haut de l'écran les messages envoyés par le serveur
-- (bonbon Légendaire pour le propriétaire, Mythique pour tout le serveur...).
-- Le client ne fait qu'afficher : c'est le serveur qui décide quoi annoncer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DUREE_AFFICHAGE = 4 -- secondes avant que le message s'efface
local DUREE_FONDU = 1

return function()
	local annonce = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Annonce")

	local ecran = Instance.new("ScreenGui")
	ecran.Name = "Annonces"
	ecran.ResetOnSpawn = false -- ne disparaît pas quand le personnage réapparaît
	ecran.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Une colonne en haut au centre : les messages s'empilent les uns sous les autres
	local colonne = Instance.new("Frame")
	colonne.AnchorPoint = Vector2.new(0.5, 0)
	colonne.Position = UDim2.new(0.5, 0, 0, 70) -- sous le compteur d'argent
	colonne.Size = UDim2.new(0.6, 0, 0.4, 0)
	colonne.BackgroundTransparency = 1
	colonne.Parent = ecran

	local rangement = Instance.new("UIListLayout")
	rangement.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rangement.Padding = UDim.new(0, 6)
	rangement.Parent = colonne

	annonce.OnClientEvent:Connect(function(texte, couleur)
		local message = Instance.new("TextLabel")
		message.Size = UDim2.new(1, 0, 0, 40)
		message.BackgroundTransparency = 1
		message.TextScaled = true
		message.Font = Enum.Font.FredokaOne
		message.TextColor3 = if typeof(couleur) == "Color3" then couleur else Color3.new(1, 1, 1)
		message.TextStrokeTransparency = 0
		message.Text = tostring(texte)
		message.Parent = colonne

		task.delay(DUREE_AFFICHAGE, function()
			local fondu = TweenService:Create(message, TweenInfo.new(DUREE_FONDU), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			})
			fondu:Play()
			fondu.Completed:Wait()
			message:Destroy()
		end)
	end)
end
