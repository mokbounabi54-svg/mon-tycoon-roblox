-- Machines à bonbons d'une usine : une fois achetées, elles font tomber des
-- bonbons à intervalle régulier. Chaque bonbon qui touche le Collecteur de
-- l'usine ajoute sa valeur au stock du collecteur.
--
-- Pour qu'un objet acheté devienne une machine, mets-lui :
--   - un attribut "ValeurBonbon" (nombre) : l'argent que rapporte chaque bonbon
--   - un attribut "Intervalle" (nombre, optionnel) : secondes entre deux bonbons
--   - si c'est un Model : une Part nommée "Sortie" à l'endroit d'où tombent
--     les bonbons. Si c'est une simple Part, les bonbons tombent sous elle.

local Debris = game:GetService("Debris")

local INTERVALLE_PAR_DEFAUT = 2 -- secondes
local DUREE_DE_VIE_BONBON = 15 -- un bonbon tombé à côté disparaît au bout de ce temps

local COULEURS_BONBONS = {
	Color3.fromRGB(255, 105, 180), -- rose
	Color3.fromRGB(255, 220, 60), -- jaune
	Color3.fromRGB(120, 220, 255), -- bleu
	Color3.fromRGB(140, 255, 120), -- vert
}

local function creerBonbon(usine, position, valeur)
	local bonbon = Instance.new("Part")
	bonbon.Name = "Bonbon"
	bonbon.Shape = Enum.PartType.Ball
	bonbon.Size = Vector3.new(1, 1, 1)
	bonbon.Material = Enum.Material.SmoothPlastic
	bonbon.Color = COULEURS_BONBONS[math.random(#COULEURS_BONBONS)]
	bonbon.Position = position
	bonbon:SetAttribute("Valeur", valeur) -- lu par le collecteur
	bonbon.Parent = usine -- rangé dans l'usine : détruit avec elle si le joueur part

	Debris:AddItem(bonbon, DUREE_DE_VIE_BONBON)
end

local function demarrerMachine(usine, machine)
	local valeur = machine:GetAttribute("ValeurBonbon")
	if typeof(valeur) ~= "number" then
		return -- pas une machine (un mur, une déco...) : rien à faire
	end

	local sortie = machine:FindFirstChild("Sortie", true)
	if sortie == nil and machine:IsA("BasePart") then
		sortie = machine
	end
	if sortie == nil then
		warn("La machine '" .. machine.Name .. "' n'a pas de Part nommée 'Sortie' : elle ne produira rien")
		return
	end

	local intervalle = machine:GetAttribute("Intervalle") or INTERVALLE_PAR_DEFAUT

	-- task.spawn lance la boucle à côté, sans bloquer le reste du script.
	-- Elle s'arrête quand la machine est détruite (avec l'usine).
	task.spawn(function()
		while machine.Parent ~= nil do
			-- Le bonbon apparaît juste sous la sortie
			local position = sortie.Position - Vector3.new(0, sortie.Size.Y / 2 + 1, 0)
			creerBonbon(usine, position, valeur)
			task.wait(intervalle)
		end
	end)
end

-- Surveille les achats de l'usine "usine"
return function(usine)
	local dossierAchats = usine:WaitForChild("Achats")

	-- Le module des boutons remet l'objet dans le dossier Achats au moment de l'achat
	dossierAchats.ChildAdded:Connect(function(machine)
		demarrerMachine(usine, machine)
	end)
end
