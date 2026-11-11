# Batterie de reproductibilité (CLAUDE.md, « Commandes » ; ADR 0010, point 25). À lancer
# depuis la racine du dépôt : Rscript tests/test_reproductibilite.R
# Au socle (T1) : aller-retours `identical` du sérialiseur, graine locale, état global
# restauré ; jeux versionnés de inst/extdata/jeux/ (#19), relus identiques à leur tirage.
# Depuis B2 (#67 ; ADR 0011, point 23) : pour chaque couple de COUPLES_REFERENCE
# (tests/references.R), (i) deux calculs identiques, (ii) rejeu de la fiche, (iii) comparaison à
# la référence de tests/reference/ ; puis (iv) arbre des références, (v) plateforme de chaque
# fiche.txt, (vi) couverture des méthodes. Un couple `a_produire` rend (iii) en [ATTENDU]
# (ADR 0011, point 25 ; M259).

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

section("jeux versionnés : rejeu de leurs fichiers, provenance, empreintes (#19 ; ADR 0010, points 19 et 20, onzième série)")
source(file.path(racine, "tests", "jeux_v1.R"))
# Comparaison d'identité (onzième série, (c)) : tout le jeu sous identical, sauf
# manifeste$version_provie (version qui a produit le jeu), contrôlée à part : au plus la
# version installée.
sans_version <- function(jeu, version) { jeu$manifeste$version_provie <- version; jeu }
for (nom in names(JEUX_V1)) {
  versionne <- file.path(racine, "inst", "extdata", "jeux", nom)
  if (!verifier(paste0(nom, " : jeu versionné présent sous inst/extdata/jeux/"), dir.exists(versionne))) next
  relu <- lire_jeu(versionne)   # contrôle aussi chaque empreinte de empreintes.md5
  m <- relu$manifeste
  verifier(paste0(nom, " : version_provie du jeu au plus égale à la version installée"),
           package_version(m$version_provie) <= utils::packageVersion("provie"))
  # (i) rejeu des seuls fichiers versionnés
  rejoue <- simuler_base(relu$loi_vraie, m$graines, m$date_extraction, nom = m$nom, description = m$description,
                         declarations = relu$declarations, date_visa = m$date_visa)
  dossier <- tempfile(paste0(nom, "-"))
  verifier_egal(paste0(nom, " : lire_jeu(ecrire_jeu(simuler_base(<fichiers du jeu>))) identique au jeu versionné"),
                sans_version(lire_jeu(ecrire_jeu(rejoue, dossier)), m$version_provie), relu)
  # (ii) concordance avec le script de provenance tests/jeux_v1.R
  verifier_egal(paste0(nom, " : entrées versionnées = définitions de tests/jeux_v1.R (loi vraie, graines, ",
                       "extraction, description, déclarations, visa)"),
                list(relu$loi_vraie, m$graines, m$date_extraction, m$description, relu$declarations, m$date_visa),
                list(loi_vraie_v1(nom), graines_v1(nom), DATE_EXTRACTION_V1, JEUX_V1[[nom]]$description,
                     JEUX_V1[[nom]]$declarations, date_visa_v1(nom)))
  verifier_egal(paste0(nom, " : simuler_jeu_v1() identique au jeu versionné (hors version_provie)"),
                sans_version(simuler_jeu_v1(nom), m$version_provie), relu)
  # octets (réserve m5) : à version égale, empreintes.md5 entier ; sinon, toutes ses lignes hors
  # celle de manifeste.txt (seul fichier qui porte version_provie)
  md5_regenere <- readLines(file.path(dossier, "empreintes.md5"))
  md5_versionne <- readLines(file.path(versionne, "empreintes.md5"))
  if (identical(m$version_provie, as.character(utils::packageVersion("provie")))) {
    verifier_egal(paste0(nom, " : mêmes octets que les fichiers versionnés (empreintes.md5 entier)"),
                  readBin(file.path(dossier, "empreintes.md5"), "raw", n = 1e6),
                  readBin(file.path(versionne, "empreintes.md5"), "raw", n = 1e6))
  }
  hors_manifeste <- function(l) l[substring(l, 35L) != "manifeste.txt"]
  verifier_egal(paste0(nom, " : mêmes octets que les fichiers versionnés, hors manifeste.txt (empreintes.md5)"),
                hors_manifeste(md5_regenere), hors_manifeste(md5_versionne))
  if (nzchar(Sys.which("md5sum"))) {
    verifier(paste0(nom, " : md5sum -c empreintes.md5 (depuis le dossier du jeu)"), local({
      ancien <- setwd(versionne)
      on.exit(setwd(ancien))
      is.null(attr(suppressWarnings(system2("md5sum", c("-c", "--quiet", "empreintes.md5"), stdout = TRUE,
                                            stderr = TRUE)), "status"))
    }))
  }
  # date de visa renseignée (onzième série, (d) ; M188) : le contrôle bascule de lui-même quand la
  # session renseigne la date de visa du jeu (DATE_VISA_V1, DATE_VISA_V1_03) et réécrit le jeu
  if (is.na(date_visa_v1(nom))) {
    attendu_echec(paste0(nom, " : date_visa renseignée"),
                  paste0(if (identical(nom, "v1-modeste-03")) "#69" else "#19", ", visa du mainteneur en attente (M188)"),
                  !is.na(m$date_visa))
  } else {
    verifier(paste0(nom, " : date_visa renseignée"), !is.na(m$date_visa))
  }
}

section("références de non-régression : couples de référence (ADR 0011, points 6 à 10, 23 et 25 ; #67)")
source(file.path(racine, "tests", "references.R"))
# Plateforme de référence (ADR 0011, point 23 (v) ; CONTEXT.md, « Plateforme de référence »,
# mesure r6 de l'ADR 0011) : champs connus en dur ; blas et lapack (chemins des bibliothèques
# de l'image) comparés à ceux de provenance.txt, écrit par le même run.
PLATEFORME_REFERENCE <- list(r = "R version 4.3.3 (2024-02-29)", plateforme = "x86_64-pc-linux-gnu", boutisme = "little",
                             lapack_version = "3.10.0")
provenance <- NULL
if (file.exists(file.path(DOSSIER_REFERENCES, "provenance.txt"))) {
  provenance <- tryCatch(outils$lire_liste(lire_fichier(file.path(DOSSIER_REFERENCES, "provenance.txt"))),
                         error = function(e) NULL)
}
resultats <- list()
for (i in seq_len(nrow(COUPLES_REFERENCE))) {
  cr <- COUPLES_REFERENCE[i, ]
  nom <- paste0(cr$couple, " (", chemin_couple(i), ")")
  verifier(paste0(nom, " : état déclaré connu"), cr$etat %in% ETATS_COUPLE)
  e <- entrees_couple(i)
  r1 <- calculer_couple(e)
  resultats[[cr$couple]] <- r1
  verifier(paste0(nom, " : (i) deux appels de calculer_provisions() identiques (identical, empreintes comprises)"),
           identical(calculer_couple(e), r1))
  rj <- rejouer_fiche(e$base, lire_fiche(ecrire_fiche(r1$fiche)), e$tables)
  verifier(paste0(nom, " : (ii) rejeu de la fiche du calcul (écrite puis relue) : même objet, aucun signalement"),
           identical(rj$resultat, r1) && nrow(rj$signalements) == 0L)
  dossier <- file.path(DOSSIER_REFERENCES, chemin_couple(i))
  fr <- file.path(dossier, "resultat.txt")
  ff <- file.path(dossier, "fiche.txt")
  if (cr$etat == "a_produire") {
    attendu_echec(paste0(nom, " : (iii) référence présente sous tests/reference/ et égale au calcul (points 6 à 9)"),
                  paste0(cr$issue, ", couple déclaré a_produire : première référence produite par la CI après visa (ADR 0011, ",
                         "points 18 (b) et 25)"),
                  file.exists(fr) && file.exists(ff) && nrow(comparer_couple(r1, lire_fichier(fr), lire_fichier(ff))) == 0L)
    next
  }
  if (!verifier(paste0(nom, " : référence présente (resultat.txt, fiche.txt)"), file.exists(fr) && file.exists(ff))) next
  ec <- comparer_couple(r1, lire_fichier(fr), lire_fichier(ff))
  if (nrow(ec) > 0L) {
    cat("    tableau avant / après (indicatif hors plateforme de référence ; ADR 0011, point 10) :\n")
    print(utils::head(ec, 50L), right = FALSE)
  }
  verifier(paste0(nom, " : (iii) comparaison à la référence : aucun écart (structure exacte, réels à 1e-10 mixte)"), nrow(ec) == 0L)
  rf <- rejouer_fiche(e$base, lire_fiche(lire_fichier(ff)), e$tables)
  verifier(paste0(nom, " : (ii) rejeu de fiche.txt : égal à la référence (écarts de version signalés sans refus)"),
           nrow(comparer_couple(rf$resultat, lire_fichier(fr), lire_fichier(ff))) == 0L)
  fiche_ref <- outils$lire_liste(lire_fichier(ff))
  informer(paste0(nom, " : empreinte du résultat recalculée ", if (identical(fiche_ref$empreintes$resultat, r1$fiche$empreintes$resultat))
    "égale" else "différente", " à celle de fiche.txt (mesure de portabilité, hors décompte)"))
  pl <- fiche_ref$plateforme
  verifier(paste0(nom, " : (v) plateforme de fiche.txt = plateforme de référence (r, plateforme, boutisme, blas, lapack, lapack_version)"),
           all(vapply(names(PLATEFORME_REFERENCE), function(n) identical(pl[[n]], PLATEFORME_REFERENCE[[n]]), NA)) &&
             !is.null(provenance) && identical(pl$blas, provenance$plateforme$blas) && identical(pl$lapack, provenance$plateforme$lapack))
}

section("références de non-régression : arbre tests/reference/ (ADR 0011, points 2, 5 et 23 (iv))")
produits <- COUPLES_REFERENCE$etat == "produit"
chemins <- vapply(seq_len(nrow(COUPLES_REFERENCE)), chemin_couple, "")
if (!dir.exists(DOSSIER_REFERENCES) && !any(produits)) {
  attendu_echec("arbre tests/reference/ présent : répertoires et couples en bijection, empreintes.md5 exact, provenance.txt bien formé",
                "#67, tous les couples a_produire : arbre écrit par le premier commit de référence (ADR 0011, point 25)",
                dir.exists(DOSSIER_REFERENCES))
} else {
  ca <- controler_arbre(DOSSIER_REFERENCES, chemins, produits)
  verifier("répertoires de tests/reference/ et couples déclarés en bijection (aucun répertoire sans couple ; chaque couple produit a le sien)",
           ca[["bijection"]])
  verifier("empreintes.md5 : une ligne par fichier de l'arbre (sauf lui-même), MD5 exacts (format de md5sum -c)", ca[["md5"]])
  verifier("provenance.txt bien formé (version_references, commit, run, tentative, image, plateforme, couples)", ca[["provenance"]])
}

section("références de non-régression : couverture des méthodes (ADR 0011, point 15 ; spécification de B2, § 7.8.5, R.6)")
couverture <- couverture_methodes(resultats)
for (k in seq_len(nrow(couverture))) {
  verifier(paste0("méthode ", couverture$methode[k], " (", couverture$garantie[k], ", ", couverture$poste[k],
                  ") : au moins un couple la calcule, cellule calcul non nulle", if (nzchar(couverture$couples[k]))
                    paste0(" (", couverture$couples[k], ")") else ""), nzchar(couverture$couples[k]))
}
verifier("couverture : les sept méthodes du capital décès (M258)", nrow(couverture) == 7L)

bilan()
