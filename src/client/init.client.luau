-- Script principal du joueur : démarre chaque partie de l'interface.
-- Chaque partie est un module rangé à côté de ce script ; le style commun
-- (police, couleurs, boutons) est dans le module Theme.

-- task.spawn : chaque partie démarre de son côté, sans attendre les autres
task.spawn(require(script:WaitForChild("Annonces")))
task.spawn(require(script:WaitForChild("Argent")))
task.spawn(require(script:WaitForChild("Inventaire")).demarrer)
