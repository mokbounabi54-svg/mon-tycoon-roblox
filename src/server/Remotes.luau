-- Les RemoteEvents : des « canaux » pour envoyer des messages entre le serveur
-- et l'écran des joueurs. Ils sont rangés dans ReplicatedStorage/Remotes pour
-- que les deux côtés les trouvent.
--
-- Côté serveur : Remotes.obtenir("Annonce") crée le canal s'il n'existe pas encore.
-- Côté joueur  : ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Annonce").
--
-- Rappel : tout ce qu'un joueur envoie par un RemoteEvent peut être truqué.
-- Le serveur doit toujours vérifier une demande avant d'y obéir.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local dossier = ReplicatedStorage:FindFirstChild("Remotes")
if dossier == nil then
	dossier = Instance.new("Folder")
	dossier.Name = "Remotes"
	dossier.Parent = ReplicatedStorage
end

local Remotes = {}

function Remotes.obtenir(nom)
	local remote = dossier:FindFirstChild(nom)
	if remote == nil then
		remote = Instance.new("RemoteEvent")
		remote.Name = nom
		remote.Parent = dossier
	end
	return remote
end

return Remotes
