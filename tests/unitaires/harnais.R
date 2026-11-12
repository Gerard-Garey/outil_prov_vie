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

section("harnais : verifier_egal à tolérance, valeur par valeur (#79 ; ADR 0011, point 7)")
# Témoin du défaut de all.equal() : écart relatif moyen sur les seuls éléments qui diffèrent.
r <- executer_harnais("verifier_egal('a', c(1e8 * (1 + 1e-13), 100.009), c(1e8, 100), tolerance = 1e-10)")
verifier("TEMOIN : un vecteur d'ordres différents, un élément hors tolérance (100.009 contre 100) : échec, écart cité",
         r$statut == 1L && grepl("[ECHEC] a", r$sortie, fixed = TRUE) && grepl("(valeur)[2]", r$sortie, fixed = TRUE) &&
           grepl("obtenu 100.009", r$sortie, fixed = TRUE))
r <- executer_harnais("verifier_egal('a', c(1e8 * (1 + 1e-13), 100 + 1e-9), c(1e8, 100), tolerance = 1e-10)")
verifier("le même vecteur dans la tolérance mixte (1e-13 relatif, 1e-9 sous 1e-8) : succès", r$statut == 0L)
r <- executer_harnais("verifier_egal('a', data.frame(m = c(1e8 * (1 + 1e-13), 100.009), k = c('x', 'y')),
                       data.frame(m = c(1e8, 100), k = c('x', 'y')), tolerance = 1e-10)")
verifier("TEMOIN : une colonne de data.frame d'ordres différents : échec, colonne et ligne citées",
         r$statut == 1L && grepl("m[2]", r$sortie, fixed = TRUE))
r <- executer_harnais("verifier_egal('a', data.frame(m = c(1e8 * (1 + 1e-13), 100 + 1e-9), k = c('x', 'y')),
                       data.frame(m = c(1e8, 100), k = c('x', 'y')), tolerance = 1e-10)")
verifier("une colonne de data.frame dans la tolérance : succès", r$statut == 0L)
r <- executer_harnais("verifier_egal('a', data.frame(m = 1, k = 'x'), data.frame(m = 1, k = 'y'), tolerance = 1e-10)")
verifier("TEMOIN : une colonne de texte différente : échec", r$statut == 1L && grepl("k[1]", r$sortie, fixed = TRUE))
r <- executer_harnais("verifier_egal('a', data.frame(m = 1), data.frame(n = 1), tolerance = 1e-10)")
verifier("TEMOIN : un nom de colonne différent : échec", r$statut == 1L && grepl("@names", r$sortie, fixed = TRUE))
r <- executer_harnais("verifier_egal('a', 1L, 1, tolerance = 1e-8)")
verifier("TEMOIN : integer contre double à tolérance : échec", r$statut == 1L && grepl("integer", r$sortie, fixed = TRUE))
r <- executer_harnais("verifier_egal('a', NA_real_, NaN, tolerance = 1e-8)")
verifier("TEMOIN : NA contre NaN : échec", r$statut == 1L && grepl("structure", r$sortie, fixed = TRUE))
r <- executer_harnais("verifier_egal('a', NaN, NaN, tolerance = 1e-8)")
verifier("NaN contre NaN : succès", r$statut == 0L)
r <- executer_harnais("verifier_egal('a', c(NA, 1), c(1, 1), tolerance = 1e-8)")
verifier("TEMOIN : NA contre valeur : échec", r$statut == 1L)
r <- executer_harnais("verifier_egal('a', Inf, 1e308, tolerance = 1e-8)")
verifier("TEMOIN : infini contre fini : échec", r$statut == 1L)
r <- executer_harnais("verifier_egal('a', c(Inf, -Inf), c(Inf, -Inf), tolerance = 1e-8)")
verifier("infinis de même signe : succès", r$statut == 0L)
r <- executer_harnais("verifier_egal('a', c(Inf, 1), c(-Inf, 1), tolerance = 1e-8)")
verifier("TEMOIN : infinis de signes opposés : échec", r$statut == 1L)
r <- executer_harnais("verifier_egal('a', c(1, 2), 1, tolerance = 1e-8)")
verifier("TEMOIN : longueur différente : échec", r$statut == 1L && grepl("longueur", r$sortie, fixed = TRUE))
r <- executer_harnais("verifier_egal('a', list(1, 2), list(1), tolerance = 1e-8)")
verifier("TEMOIN : liste de longueur différente : échec", r$statut == 1L && grepl("longueur", r$sortie, fixed = TRUE))
r <- executer_harnais("verifier_egal('a', c(x = 1), c(y = 1), tolerance = 1e-8)")
verifier("TEMOIN : noms différents : échec", r$statut == 1L && grepl("@names", r$sortie, fixed = TRUE))
r <- executer_harnais("verifier_egal('a', matrix(c(1, 2, 3, 4), 2), matrix(c(1, 2, 3, 4), 1), tolerance = 1e-8)")
verifier("TEMOIN : tableaux de même longueur et de dimensions différentes : l'écart @dim est cité, pas une erreur de conformité",
         r$statut == 1L && grepl("@dim", r$sortie, fixed = TRUE) && !grepl("non-conformable", r$sortie, fixed = TRUE))
r <- executer_harnais("verifier_egal('a', matrix(c(1, 2, 3, 4), 2), matrix(c(1, 2, 3, 4), 2), tolerance = 1e-8)")
verifier("tableaux identiques : succès", r$statut == 0L)
r <- executer_harnais("verifier_egal('a', c(x = 1), 1, tolerance = 1e-8)")
verifier("TEMOIN : noms contre aucun nom : échec", r$statut == 1L)
r <- executer_harnais("verifier_egal('a', list(TRUE, 0.02, as.Date('2025-02-01'), 'x', c(1, 2 + 1e-12)),
                       list(TRUE, 0.02 + 1e-12, as.Date('2025-02-01'), 'x', c(1, 2)), tolerance = 1e-10)")
verifier("liste anonyme mêlant logique, réel, date, texte et vecteur dans la tolérance : succès", r$statut == 0L)
r <- executer_harnais("verifier_egal('a', list(1, list(b = 2.1)), list(1, list(b = 2)), tolerance = 1e-10)")
verifier("TEMOIN : écart dans une liste imbriquée : échec, chemin cité", r$statut == 1L && grepl("2/b", r$sortie, fixed = TRUE))
r <- executer_harnais("verifier_egal('a', as.Date('2025-01-02'), as.Date('2025-01-01'), tolerance = 1e-10)")
verifier("TEMOIN : dates différentes d'un jour : échec (les dates ne se comparent pas à la tolérance)", r$statut == 1L)
r <- executer_harnais("verifier_egal('a', as.Date('2025-01-01'), 20089, tolerance = 1e-10)")
verifier("TEMOIN : Date contre double : échec", r$statut == 1L)
r <- executer_harnais("verifier_egal('a', factor('a'), factor('b'), tolerance = 1e-10)")
verifier("TEMOIN : facteurs de niveaux différents : échec", r$statut == 1L && grepl("@levels", r$sortie, fixed = TRUE))
r <- executer_harnais("verifier_egal('a', NULL, 1, tolerance = 1e-10)")
verifier("TEMOIN : NULL contre valeur : échec", r$statut == 1L)
r <- executer_harnais("verifier_egal('a', 5e-11, 0, tolerance = 1e-10)")
verifier("sous 1 en valeur, la tolérance est absolue : 5e-11 contre 0 : succès", r$statut == 0L)
r <- executer_harnais("verifier_egal('a', 2e-10, 0, tolerance = 1e-10)")
verifier("TEMOIN : 2e-10 contre 0 à 1e-10 : échec", r$statut == 1L)
r <- executer_harnais("verifier_egal('a', 1e8 + 0.02, 1e8, tolerance = 1e-10)")
verifier("TEMOIN : au-dessus de 1, la tolérance est relative : 1e8 + 0.02 contre 1e8 à 1e-10 (seuil 1e-2) : échec",
         r$statut == 1L)
r <- executer_harnais("verifier_egal('a', (1:10) + 0, 2 * ((1:10) + 0), tolerance = 1e-10)")
verifier("message d'échec : nombre d'écarts et cinq premiers seulement",
         r$statut == 1L && grepl("10 ", r$sortie, fixed = TRUE) && grepl("cart(s)", r$sortie, fixed = TRUE) &&
           grepl("[5]", r$sortie, fixed = TRUE) && !grepl("[6]", r$sortie, fixed = TRUE) &&
           grepl("...", r$sortie, fixed = TRUE))
r <- executer_harnais("verifier_egal('a', 1, 1, tolerance = NA_real_)")
verifier("TEMOIN : tolérance NA : échec, pas de succès silencieux", r$statut == 1L)
r <- executer_harnais("verifier_egal('a', 1, 1, tolerance = -1)")
verifier("TEMOIN : tolérance négative : échec", r$statut == 1L)
r <- executer_harnais("verifier_egal('a', c(1, 2), c(1, 2), tolerance = 1e-10)")
verifier("vecteurs identiques à tolérance : succès", r$statut == 0L)

section("harnais : tolérance non finie, petites valeurs, types et classes temporelles, message tronqué (revue de #79)")
r <- executer_harnais("verifier_egal('a', 1, 1e300, tolerance = Inf)")
verifier("TEMOIN : tolérance Inf : échec (refus de la tolérance, pas de succès silencieux)",
         r$statut == 1L && grepl("[ECHEC] a -- tolerance", r$sortie, fixed = TRUE))
r <- executer_harnais("verifier_egal('a', 1, 1, tolerance = NaN)")
verifier("TEMOIN : tolérance NaN : échec", r$statut == 1L && grepl("[ECHEC] a -- tolerance", r$sortie, fixed = TRUE))
r <- executer_harnais("verifier_egal('a', 1, 1, tolerance = 1L)")
verifier("une tolérance entière finie reste admise", r$statut == 0L)
# Sous |r| <= 1 la tolérance est absolue : la parade est tolerance = 1e-10 * |r| (écart relatif 1e-10).
r <- executer_harnais("verifier_egal('a', 1e-5 * (1 + 1e-3), 1e-5, tolerance = 1e-10 * 1e-5)")
verifier("TEMOIN : r = 1e-5, écart relatif 1e-3, tolerance = 1e-10 * |r| : échec", r$statut == 1L)
r <- executer_harnais("verifier_egal('a', 1e-5 * (1 + 1e-3), 1e-5, tolerance = 1e-10 / 1e-5)")
verifier("TEMOIN : la parade inversée (tolerance = 1e-10 / |r| = 1e-5, absolue) laisse passer le même écart relatif de 1e-3",
         r$statut == 0L)
r <- executer_harnais("verifier_egal('a', 1e-5 * (1 + 1e-12), 1e-5, tolerance = 1e-10 * 1e-5)")
verifier("r = 1e-5, écart relatif 1e-12, tolerance = 1e-10 * |r| : succès", r$statut == 0L)
r <- executer_harnais("verifier_egal('a', structure(20089L, class = 'Date'), as.Date('2025-01-01'), tolerance = 1e-10)")
verifier("TEMOIN : Date stockée en entier contre Date stockée en réel à tolérance : échec, typeof cité",
         r$statut == 1L && grepl("double, obtenu integer", r$sortie, fixed = TRUE))
r <- executer_harnais("verifier_egal('a', structure(20089L, class = 'Date'), as.Date('2025-01-01'))")
verifier("même cas à tolérance nulle : échec (identical), cohérent avec la tolérance > 0", r$statut == 1L)
r <- executer_harnais("verifier_egal('a', as.Date('2025-01-01'), as.Date('2025-01-01'), tolerance = 1e-10)")
verifier("deux Date en réel identiques : succès", r$statut == 0L)
r <- executer_harnais("t0 <- as.POSIXct('2025-01-01 00:00:00', tz = 'UTC')
  verifier_egal('a', t0 + 1000, t0, tolerance = 1e-6)")
verifier("TEMOIN : POSIXct à 1000 s d'écart, tolérance 1e-6 (tolérance relative sur 1.7e9 : 1.7e3) : échec", r$statut == 1L)
r <- executer_harnais("t0 <- as.POSIXct('2025-01-01 00:00:00', tz = 'UTC')
  verifier_egal('a', t0 + 1e-5, t0, tolerance = 1e-6)")
verifier("TEMOIN : POSIXct à 1e-5 s d'écart, sous la tolérance relative : échec (comparaison exacte)", r$statut == 1L)
r <- executer_harnais("t0 <- as.POSIXct('2025-01-01 00:00:00', tz = 'UTC')
  verifier_egal('a', list(t0, 1 + 1e-12), list(t0, 1), tolerance = 1e-10)")
verifier("POSIXct identiques dans une liste, réel voisin dans la tolérance : succès (la tolérance reste pour les réels)",
         r$statut == 0L)
r <- executer_harnais("verifier_egal('a', as.difftime(1000 + 1e-5, units = 'secs'), as.difftime(1000, units = 'secs'), tolerance = 1e-6)")
verifier("TEMOIN : difftime à 1e-5 de l'écart, sous la tolérance relative : échec (comparaison exacte)", r$statut == 1L)
r <- executer_harnais("verifier_egal('a', as.difftime(1000, units = 'secs'), as.difftime(1000, units = 'secs'), tolerance = 1e-6)")
verifier("difftime identiques : succès", r$statut == 0L)
r <- executer_harnais("verifier_egal('a', as.POSIXlt('2025-01-01 00:00:00.5', tz = 'UTC'), as.POSIXlt('2025-01-01 00:00:00.5000001', tz = 'UTC'), tolerance = 1e-3)")
verifier("TEMOIN : POSIXlt à 1e-7 s d'écart : échec, composante citée (comparaison exacte, pas de récursion sans fin)",
         r$statut == 1L && grepl("sec", r$sortie, fixed = TRUE))
r <- executer_harnais("verifier_egal('a', as.POSIXlt('2025-01-01', tz = 'UTC'), as.POSIXlt('2025-01-01', tz = 'UTC'), tolerance = 1e-3)")
verifier("POSIXlt identiques : succès", r$statut == 0L)
r <- executer_harnais("verifier_egal('a', setNames(1:100000, paste0('a', 1:100000)), setNames(1:100000, paste0('b', 1:100000)), tolerance = 1e-8)")
verifier("TEMOIN : écart d'attribut sur un vecteur de 1e5 éléments : message tronqué aux dix premiers, nombre de valeurs cité",
         r$statut == 1L && grepl("@names", r$sortie, fixed = TRUE) && grepl("(100000 valeurs)", r$sortie, fixed = TRUE) &&
           grepl("b10,", r$sortie, fixed = TRUE) && !grepl("b11,", r$sortie, fixed = TRUE) && nchar(r$sortie) < 1000)
r <- executer_harnais("verifier_egal('a', data.frame(x = 1:20), data.frame(x = 1:20, row.names = paste0('r', 1:20)), tolerance = 1e-8)")
verifier("TEMOIN : row.names différents d'un data.frame de 20 lignes : échec tronqué (20 valeurs)",
         r$statut == 1L && grepl("@row.names", r$sortie, fixed = TRUE) && grepl("(20 valeurs)", r$sortie, fixed = TRUE))
r <- executer_harnais("verifier_egal('a', c(x = 1, y = 2), c(x = 1, z = 2), tolerance = 1e-8)")
verifier("attribut de dix éléments ou moins : cité en entier, sans « valeurs »",
         r$statut == 1L && grepl("x,z, obtenu x,y", r$sortie, fixed = TRUE) && !grepl("valeurs)", r$sortie, fixed = TRUE))

section("harnais : comparateur déplacé de tests/references.R (#79)")
e <- comparer_feuilles(list(a = 1 + 5e-11, b = c(1, 2)), list(a = 1, b = c(1, 2)), tolerance = 1e-10)
verifier("comparer_feuilles : tolérance explicite, 5e-11 sous 1e-10 : aucun écart", nrow(e) == 0L)
e <- comparer_feuilles(list(a = 1 + 5e-11, b = c(1, 2)), list(a = 1, b = c(1, 2)), tolerance = 1e-12)
verifier("comparer_feuilles : tolérance explicite, 5e-11 hors 1e-12 : un écart de valeur à la feuille a",
         nrow(e) == 1L && e$chemin == "a" && e$nature == "valeur")
r <- executer_harnais("EPS_REFERENCE <- 1e-10
  verifier('sans argument, 5e-11 sous EPS_REFERENCE', nrow(comparer_feuilles(list(a = 1 + 5e-11), list(a = 1))) == 0L)
  verifier('sans argument, 5e-10 hors EPS_REFERENCE', nrow(comparer_feuilles(list(a = 1 + 5e-10), list(a = 1))) == 1L)")
verifier("comparer_feuilles : sans argument, tolérance EPS_REFERENCE (comportement antérieur, défini par references.R)",
         r$statut == 0L && grepl("2 OK, 0 ECHEC", r$sortie, fixed = TRUE))

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
