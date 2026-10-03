-- Script principal du joueur : démarre chaque partie de l'interface.
-- Chaque partie est un module rangé à côté de ce script ; le style commun
-- (police, couleurs, boutons) est dans le module Theme, les icônes 3D dans Icones.

-- task.spawn : chaque partie démarre de son côté, sans attendre les autres
task.spawn(require(script:WaitForChild("Annonces")))
task.spawn(require(script:WaitForChild("Argent")))
task.spawn(require(script:WaitForChild("Inventaire")).demarrer)
task.spawn(require(script:WaitForChild("Carnet")).demarrer)
task.spawn(require(script:WaitForChild("Sorciere")).demarrer)
task.spawn(require(script:WaitForChild("Tutoriel")))
task.spawn(require(script:WaitForChild("PanneauDebug"))) -- seulement dans Studio, en mode debug
