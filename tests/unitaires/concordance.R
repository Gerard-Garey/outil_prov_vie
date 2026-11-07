# Tests du script tests/concordance_doc_moteur.R sur des racines fictives (option
# --racine=) : le script tourne dans un processus Rscript distinct, on lit statut et sortie.
# `racine` est défini par la batterie.

lancer_concordance <- function(contenu_doc, r_outils = "f_un <- function() 1\n.aux <- function() 2\nK <- 3\n",
                               namespace = "export(f_un)\n", strict = TRUE) {
  faux <- tempfile("racine-")
  on.exit(unlink(faux, recursive = TRUE), add = TRUE)
  dir.create(file.path(faux, "R"), recursive = TRUE)
  dir.create(file.path(faux, "docs", "latex"), recursive = TRUE)
  writeLines(r_outils, file.path(faux, "R", "outils.R"))
  writeLines(namespace, file.path(faux, "NAMESPACE"))
  if (!is.null(contenu_doc)) {
    writeLines(contenu_doc, file.path(faux, "docs", "latex", "doc_outil_prov_vie.tex"))
  }
  sortie <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"),
    c(shQuote(file.path(racine, "tests", "concordance_doc_moteur.R")),
      if (strict) "--strict", paste0("--racine=", shQuote(faux))),
    stdout = TRUE, stderr = TRUE))
  statut <- attr(sortie, "status")
  list(statut = if (is.null(statut)) 0L else statut, sortie = paste(sortie, collapse = "\n"))
}

tableau <- function(module, ...) {
  c(paste0("% concordance-fonctions : ", module), "\\begin{tabular}{ll}",
    "Fonction & Rôle \\\\", paste0("\\code{", c(...), "} & texte \\code{ignoré} \\\\"),
    "\\end{tabular}")
}

section("concordance : racines fictives")
r <- lancer_concordance(NULL)
verifier("document absent, --strict : échec", r$statut == 1L && grepl("[ECHEC]", r$sortie, fixed = TRUE) &&
           grepl("absent", r$sortie, fixed = TRUE))
r <- lancer_concordance(NULL, strict = FALSE)
verifier("document absent, sans --strict : avertissement, statut 0",
         r$statut == 0L && grepl("[AVERT]", r$sortie, fixed = TRUE))
r <- lancer_concordance(tableau("outils", "f\\_un()"))
verifier("document concordant : statut 0 (fonction à point et constante non recensées)",
         r$statut == 0L && grepl("module outils : 1 fonction(s) concordante(s)", r$sortie, fixed = TRUE))
r <- lancer_concordance(tableau("outils", "f\\_un()"), r_outils = "f_un <- function() 1\ng <- function() 2\n")
verifier("fonction du code absente du document : échec --strict, nom cité",
         r$statut == 1L && grepl("fonctions absentes du document : g", r$sortie, fixed = TRUE))
r <- lancer_concordance(tableau("outils", "f\\_un()"), r_outils = "f_un <- function() 1\ng <- function() 2\n",
                        strict = FALSE)
verifier("même écart sans --strict : [AVERT], statut 0", r$statut == 0L &&
           grepl("[AVERT] module outils", r$sortie, fixed = TRUE))
r <- lancer_concordance(tableau("outils", "f\\_un()", "fantome()"))
verifier("fonction citée absente du code : échec", r$statut == 1L &&
           grepl("citées mais absentes du code : fantome", r$sortie, fixed = TRUE))
r <- lancer_concordance(tableau("outils", "f\\_un()", "f\\_un()"))
verifier("fonction citée deux fois : échec", r$statut == 1L && grepl("citées deux fois", r$sortie, fixed = TRUE))
r <- lancer_concordance(tableau("outils", "f\\_un"), namespace = "export(f_un)\nexport(autre)\n")
verifier("export non cité : échec", r$statut == 1L && grepl("non cités dans le document : autre", r$sortie, fixed = TRUE))
r <- lancer_concordance(tableau("moteur_inconnu", "x"))
verifier("module inconnu dans le document : échec", r$statut == 1L &&
           grepl("module inconnu", r$sortie, fixed = TRUE))
r <- lancer_concordance(c("\\begin{document}", "\\code{f\\_un} hors de tout tableau"))
verifier("module avec fonctions sans tableau : échec", r$statut == 1L &&
           grepl("aucun tableau", r$sortie, fixed = TRUE))
r <- lancer_concordance(c(tableau("outils", "f\\_un"), tableau("outils", "f\\_un")))
verifier("deux tableaux pour un module : échec", r$statut == 1L &&
           grepl("deux tableaux", r$sortie, fixed = TRUE))
