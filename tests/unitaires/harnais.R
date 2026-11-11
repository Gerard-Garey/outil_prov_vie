# Tests du harnais lui-même (tests/harnais.R) : chaque cas s'exécute dans un processus
# Rscript distinct, dont on lit la sortie et le statut. Le cas du succès inattendu est le
# témoin qui prouve qu'un « échec attendu » qui réussit fait échouer la batterie.
# `racine` est défini par la batterie.

executer_harnais <- function(code) {
  script <- tempfile(fileext = ".R")
  on.exit(unlink(script), add = TRUE)
  writeLines(c("options(warn = 2)",
               sprintf("source('%s')", file.path(racine, "tests", "harnais.R")),
               "refus <- function(motif) stop(structure(class = c('refus_provie', 'error', 'condition'),",
               "  list(message = 'm', call = NULL, motif = motif)))",
               code, "bilan()"), script)
  sortie <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"), shQuote(script),
                                     stdout = TRUE, stderr = TRUE))
  statut <- attr(sortie, "status")
  list(statut = if (is.null(statut)) 0L else statut, sortie = paste(sortie, collapse = "\n"))
}

section("harnais : statuts et décomptes")
r <- executer_harnais("verifier('a', TRUE)")
verifier("un succès : statut 0 et décompte", r$statut == 0L && grepl("[OK] a", r$sortie, fixed = TRUE) &&
           grepl("1 OK, 0 ECHEC, 0 ATTENDU, 0 SUCCES INATTENDU", r$sortie, fixed = TRUE))
r <- executer_harnais("verifier('a', FALSE)")
verifier("un échec : statut 1", r$statut == 1L && grepl("[ECHEC] a", r$sortie, fixed = TRUE))
r <- executer_harnais("verifier('a', stop('boum'))")
verifier("une erreur dans la condition est un échec, pas un arrêt",
         r$statut == 1L && grepl("[ECHEC] a -- boum", r$sortie, fixed = TRUE) &&
           grepl("1 ECHEC", r$sortie, fixed = TRUE))
r <- executer_harnais("verifier('a', as.numeric('x') > 0)")
verifier("un avertissement sous warn = 2 est un échec",
         r$statut == 1L && grepl("[ECHEC] a", r$sortie, fixed = TRUE))
r <- executer_harnais("verifier('a', c(TRUE, TRUE))")
verifier("seul TRUE exactement réussit", r$statut == 1L)

section("harnais : verifier_egal")
r <- executer_harnais("verifier_egal('a', c(x = 1), c(x = 1))")
verifier("égalité stricte", r$statut == 0L)
r <- executer_harnais("verifier_egal('a', 1, 1 + 1e-10)")
verifier("tolérance nulle : identical", r$statut == 1L)
r <- executer_harnais("verifier_egal('a', 1, 1 + 1e-10, tolerance = 1e-8)")
verifier("tolérance relative", r$statut == 0L)
r <- executer_harnais("verifier_egal('a', 1L, 1)")
verifier("tolérance nulle : le type compte", r$statut == 1L)

section("harnais : verifier_refus")
r <- executer_harnais("verifier_refus('a', refus('plan_invalide'), 'plan_invalide')")
verifier("bon motif", r$statut == 0L && grepl("[OK] a", r$sortie, fixed = TRUE))
r <- executer_harnais("verifier_refus('a', refus('plan_incomplet'), 'plan_invalide')")
verifier("mauvais motif", r$statut == 1L && grepl("plan_incomplet au lieu de plan_invalide", r$sortie, fixed = TRUE))
r <- executer_harnais("verifier_refus('a', 1, 'plan_invalide')")
verifier("aucun refus", r$statut == 1L && grepl("aucun refus", r$sortie, fixed = TRUE))
r <- executer_harnais("verifier_refus('a', stop('autre'), 'plan_invalide')")
verifier("autre erreur", r$statut == 1L && grepl("autre erreur : autre", r$sortie, fixed = TRUE))

section("harnais : attendu_echec")
r <- executer_harnais("attendu_echec('a', '#99', FALSE)")
verifier("échec attendu qui échoue : statut 0, ligne [ATTENDU] avec l'issue",
         r$statut == 0L && grepl("[ATTENDU] a -- #99", r$sortie, fixed = TRUE) &&
           grepl("1 ATTENDU", r$sortie, fixed = TRUE))
r <- executer_harnais("attendu_echec('a', '#99', stop('boum'))")
verifier("échec attendu par une erreur : statut 0", r$statut == 0L &&
           grepl("[ATTENDU] a", r$sortie, fixed = TRUE))
r <- executer_harnais("attendu_echec('a', '#99', TRUE)")
verifier("TEMOIN : un échec attendu qui réussit fait échouer la batterie (statut 1, ligne SUCCES INATTENDU)",
         r$statut == 1L && grepl("[SUCCES INATTENDU] a", r$sortie, fixed = TRUE) &&
           grepl("1 SUCCES INATTENDU", r$sortie, fixed = TRUE))
r <- executer_harnais("verifier('b', TRUE); attendu_echec('a', '#99', FALSE)")
verifier("mélange sans échec : statut 0", r$statut == 0L &&
           grepl("1 OK, 0 ECHEC, 1 ATTENDU, 0 SUCCES INATTENDU", r$sortie, fixed = TRUE))

section("harnais : exige options(warn = 2)")
script_sans_warn <- tempfile(fileext = ".R")
writeLines(c(sprintf("source('%s')", file.path(racine, "tests", "harnais.R")),
             "verifier('a', TRUE)", "bilan()"), script_sans_warn)
sortie <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"), shQuote(script_sans_warn),
                                   stdout = TRUE, stderr = TRUE))
statut <- attr(sortie, "status")
unlink(script_sans_warn)
verifier("TEMOIN : sans options(warn = 2), le harnais s'arrête avec le statut 1 avant toute vérification",
         !is.null(statut) && statut == 1L && any(grepl("options(warn = 2) est requis", sortie, fixed = TRUE)) &&
           !any(grepl("[OK] a", sortie, fixed = TRUE)))
script_warn1 <- tempfile(fileext = ".R")
writeLines(c("options(warn = 1)", sprintf("source('%s')", file.path(racine, "tests", "harnais.R")),
             "bilan()"), script_warn1)
sortie <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"), shQuote(script_warn1),
                                   stdout = TRUE, stderr = TRUE))
unlink(script_warn1)
verifier("warn = 1 est aussi refusé", !is.null(attr(sortie, "status")) && attr(sortie, "status") == 1L)

section("harnais : installer_provie")
paquet_faux <- tempfile("paquet-faux")
dir.create(file.path(paquet_faux, "R"), recursive = TRUE)
writeLines(c("Package: provie", "Version: 0.0.1", "Title: faux", "Description: faux.",
             "License: file LICENSE", "Encoding: UTF-8"), file.path(paquet_faux, "DESCRIPTION"))
writeLines("", file.path(paquet_faux, "NAMESPACE"))
writeLines("f <- function( {", file.path(paquet_faux, "R", "x.R"))
r <- executer_harnais(sprintf("installer_provie('%s')", paquet_faux))
unlink(paquet_faux, recursive = TRUE)
verifier("TEMOIN : un package qui ne s'installe pas : sortie de R CMD INSTALL, [ECHEC] et statut 1 sous warn = 2",
         r$statut == 1L && grepl("ERROR: unable to collate and parse R files", r$sortie, fixed = TRUE) &&
           grepl("[ECHEC] installation du package provie", r$sortie, fixed = TRUE))

section("harnais : informer (ADR 0011, point 23)")
r <- executer_harnais("informer('mesure', 'detail'); verifier('a', TRUE)")
verifier("informer() : ligne [INFO] hors décompte, statut inchangé",
         r$statut == 0L && grepl("[INFO] mesure -- detail", r$sortie, fixed = TRUE) &&
           grepl("1 OK, 0 ECHEC, 0 ATTENDU, 0 SUCCES INATTENDU", r$sortie, fixed = TRUE))
