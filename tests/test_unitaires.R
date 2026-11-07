# Batterie unitaire (CLAUDE.md, « Commandes » ; ADR 0010, point 25). À lancer depuis la
# racine du dépôt : Rscript tests/test_unitaires.R
# Installe le package dans une bibliothèque temporaire, le charge par library(provie),
# puis exécute tests/unitaires/*.R (un fichier par module) dans ce processus.

options(warn = 2)
fichier <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
racine <- normalizePath(file.path(dirname(fichier), ".."), mustWork = TRUE)
source(file.path(racine, "tests", "harnais.R"))

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
