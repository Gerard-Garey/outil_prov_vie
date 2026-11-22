# Témoins de la voie `git ls-files` des scripts de contrôle (#186 ; CLAUDE.md, « Workflows »,
# principe 7), rejoués dans le job « Contrôles du dépôt » de la CI, dont le runner a git : le job
# « Tests (R 4.3.3) » tourne dans une image sans git, où la batterie unitaire les SAUTE (ligne
# [INFO] par témoin). Le présent lanceur exige git : sans lui, aucun témoin ne tourne, c'est un [ECHEC].
# Usage, depuis la racine du dépôt : Rscript tests/temoins_voie_git.R
# Sortie : lignes [OK] / [ECHEC] / [INFO] du harnais, puis le bilan (statut 1 au moindre échec).
# R de base seulement.

options(warn = 2)
fichier <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
racine <- normalizePath(file.path(dirname(fichier), ".."), mustWork = TRUE)
source(file.path(racine, "tests", "harnais.R"))

if (verifier("git est présent dans le PATH (sans lui, les témoins seraient sautés)", nzchar(Sys.which("git")))) {
  env <- new.env(parent = globalenv())
  source(file.path(racine, "tests", "unitaires", "voie_git.R"), local = env)
  verifier("aucun témoin de la voie git sauté", length(env$.sautes) == 0L)
}
bilan()
