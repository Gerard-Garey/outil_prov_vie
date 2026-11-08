# Batterie de reproductibilité (CLAUDE.md, « Commandes » ; ADR 0010, point 25). À lancer
# depuis la racine du dépôt : Rscript tests/test_reproductibilite.R
# Au socle (T1) : aller-retours `identical` du sérialiseur, graine locale, état global
# restauré. Le rejeu des fiches, les jeux versionnés et les références de tests/reference/
# s'ajoutent avec les branches qui les créent.

options(warn = 2)
fichier <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
racine <- normalizePath(file.path(dirname(fichier), ".."), mustWork = TRUE)
source(file.path(racine, "tests", "harnais.R"))

installer_provie(racine)
outils <- asNamespace("provie")

e_aigu <- intToUtf8(233L)
liste <- list(
  entier = c(1:3, NA), reel = c(0.1, 1/3, 1e-300, 1e22, .Machine$double.xmax, NA, NaN, Inf, -Inf),
  logique = c(TRUE, NA, FALSE), texte = c(e_aigu, "a\tb\nc\\d", NA, "", intToUtf8(c(171L, 8364L))),
  date = as.Date(c("2026-11-07", NA)), vide = character(0), liste_vide = list(), rien = NULL,
  noeud = list(a = 1.5, b = list(c = "x", d = list(e = TRUE))),
  plateforme = outils$decrire_plateforme())

section("sérialiseur : aller-retours")
octets <- outils$ecrire_liste(liste)
verifier_egal("lire_liste(ecrire_liste(x)) identique à x", outils$lire_liste(octets), liste)
verifier_egal("ecrire_liste(lire_liste(octets)) redonne les mêmes octets",
              outils$ecrire_liste(outils$lire_liste(octets)), octets)
verifier_egal("deux écritures de la même liste : mêmes octets", outils$ecrire_liste(liste), octets)
verifier_egal("empreinte des octets stable",
              outils$empreinte(octets), outils$empreinte(outils$ecrire_liste(liste)))
reels <- outils$avec_graine(1L, c(runif(1000, -1e6, 1e6), 10^runif(1000, -300, 300), 1/(1:1000)))
verifier_egal("3000 réels : aller-retour %.17g exact au bit près",
              outils$lire_liste(outils$ecrire_liste(list(x = reels)))$x, reels)
verifier_egal("valeurs écrites en octets : stables",
              outils$ecrire_valeurs(reels, "octets"), outils$ecrire_valeurs(reels, "octets"))

section("graine locale : mêmes tirages, état global restauré")
verifier_egal("deux appels de avec_graine(42) : tirages identiques",
              outils$avec_graine(42L, c(runif(5), rnorm(5), sample(100, 5))),
              outils$avec_graine(42L, c(runif(5), rnorm(5), sample(100, 5))))
verifier_egal("tirage de référence sous la graine 42 (Mersenne-Twister, Inversion, Rejection)",
              outils$avec_graine(42L, runif(3)),
              c(0.914806043496355, 0.937075413297862, 0.286139534786344), tolerance = 1e-14)
set.seed(2026)
etat <- .Random.seed
genres <- RNGkind()
invisible(outils$avec_graine(7L, runif(100)))
verifier("avec_graine restaure .Random.seed", identical(.Random.seed, etat))
verifier_egal("avec_graine restaure les genres du générateur", RNGkind(), genres)
suite <- runif(3)
set.seed(2026)
verifier_egal("la suite du flux de l'appelant est inchangée", suite, runif(3))
set.seed(2026)
etat <- .Random.seed
invisible(try(outils$avec_graine(7L, { runif(2); stop("boum") }), silent = TRUE))
verifier("état restauré même après une erreur", identical(.Random.seed, etat))

bilan()
