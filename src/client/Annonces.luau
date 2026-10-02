-- Affiche en haut de l'écran les messages envoyés par le serveur
-- (bonbon Légendaire pour le propriétaire, Mythique pour tout le serveur, nouveauté
-- du carnet, inventaire plein...). Le client ne fait qu'afficher : c'est le serveur
-- qui décide quoi annoncer. Le serveur peut indiquer un son (nom dans Theme.Sons),
-- joué doucement avec le message.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent:WaitForChild("Theme"))

local DUREE_AFFICHAGE = 4 -- secondes avant que le message s'efface
local DUREE_FONDU = 1
local MESSAGES_MAX = 4 -- au-delà, le plus ancien disparaît tout de suite

return function()
	local annonce = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Annonce")
	local telephone = UserInputService.TouchEnabled

	local ecran = Instance.new("ScreenGui")
	ecran.Name = "Annonces"
	ecran.ResetOnSpawn = false -- ne disparaît pas quand le personnage réapparaît
	ecran.DisplayOrder = 20 -- au-dessus des panneaux
	ecran.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Une colonne en haut au centre : les messages s'empilent les uns sous les autres
	local colonne = Instance.new("Frame")
	colonne.AnchorPoint = Vector2.new(0.5, 0)
	colonne.Position = UDim2.new(0.5, 0, 0, 70) -- sous le compteur d'argent
	colonne.Size = UDim2.new(if telephone then 0.9 else 0.6, 0, 0.4, 0)
	colonne.BackgroundTransparency = 1
	colonne.Parent = ecran

	local rangement = Instance.new("UIListLayout")
	rangement.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rangement.SortOrder = Enum.SortOrder.LayoutOrder
	rangement.Padding = UDim.new(0, 6)
	rangement.Parent = colonne

	local numero = 0
	annonce.OnClientEvent:Connect(function(texte, couleur, nomSon)
		numero += 1
		local message = Instance.new("TextLabel")
		message.Name = "Message"
		message.LayoutOrder = numero
		message.Size = UDim2.new(1, 0, 0, 0)
		message.AutomaticSize = Enum.AutomaticSize.Y
		message.BackgroundTransparency = 1
		message.TextWrapped = true
		message.TextSize = if telephone then 18 else 26 -- taille fixe : jamais sous 13 px
		message.Font = Theme.Police
		message.TextColor3 = if typeof(couleur) == "Color3" then couleur else Color3.new(1, 1, 1)
		message.TextStrokeTransparency = 0
		message.Text = tostring(texte)
		message.Parent = colonne

		-- Pas plus de MESSAGES_MAX à la fois
		local messages = {}
		for _, m in colonne:GetChildren() do
			if m:IsA("TextLabel") then
				table.insert(messages, m)
			end
		end
		table.sort(messages, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		for i = 1, #messages - MESSAGES_MAX do
			messages[i]:Destroy()
		end

		local son = typeof(nomSon) == "string" and Theme.Sons[nomSon]
		if son then
			local s = Instance.new("Sound")
			s.SoundId = son.Id
			s.Volume = son.Volume
			s.PlaybackSpeed = son.Vitesse
			s.Parent = ecran
			s:Play()
			s.Ended:Once(function()
				s:Destroy()
			end)
		end

		task.delay(DUREE_AFFICHAGE, function()
			if message.Parent == nil then
				return
			end
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
