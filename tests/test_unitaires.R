# Batterie unitaire (CLAUDE.md, « Commandes » ; ADR 0010, point 25). À lancer depuis la
# racine du dépôt : Rscript tests/test_unitaires.R
# Exécute d'abord les scripts de contrôle de tests/controles/*.R (chacun dans un Rscript
# séparé : statut lu, et tout [ECHEC] de sa sortie fait échouer la batterie ; ADR 0010,
# points 25 et 26), puis installe le package dans une bibliothèque temporaire, le charge par
# library(provie) et exécute tests/unitaires/*.R (un fichier par module) dans ce processus.

options(warn = 2)
fichier <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
racine <- normalizePath(file.path(dirname(fichier), ".."), mustWork = TRUE)
source(file.path(racine, "tests", "harnais.R"))

section("contrôles du dépôt (tests/controles)")
controles <- sort(list.files(file.path(racine, "tests", "controles"), pattern = "\\.R$",
                             full.names = TRUE), method = "radix")
for (controle in controles) {
  sortie <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
                                     c(shQuote(controle), shQuote(racine)),
                                     stdout = TRUE, stderr = TRUE))
  statut <- attr(sortie, "status")
  statut <- if (is.null(statut)) 0L else statut
  cat(paste0("    ", sortie), sep = "\n")
  verifier(paste("contrôle", file.path("tests", "controles", basename(controle))),
           statut == 0L && !any(grepl("^\\[ECHEC\\]", sortie)))
}

section("tests unitaires (tests/unitaires)")
installer_provie(racine)

scripts <- sort(list.files(file.path(racine, "tests", "unitaires"), pattern = "\\.R$",
                           full.names = TRUE), method = "radix")
for (script in scripts) {
  verifier(paste("exécution de", file.path("tests", "unitaires", basename(script))), {
    source(script, local = new.env(parent = globalenv()))
    TRUE
  })
}

bilan()
