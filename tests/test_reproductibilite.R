# Batterie de reproductibilité (CLAUDE.md, « Commandes » ; ADR 0010, point 25). À lancer
# depuis la racine du dépôt : Rscript tests/test_reproductibilite.R
# Au socle (T1) : aller-retours `identical` du sérialiseur, graine locale, état global
# restauré ; jeux versionnés de inst/extdata/jeux/ (#19), relus identiques à leur tirage. Le
# rejeu des fiches et les références de tests/reference/ s'ajoutent avec les branches qui les
# créent.

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
                list(loi_vraie_v1(nom), GRAINES_V1, DATE_EXTRACTION_V1, JEUX_V1[[nom]]$description,
                     JEUX_V1[[nom]]$declarations, DATE_VISA_V1))
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
  # session renseigne DATE_VISA_V1 et réécrit les jeux
  if (is.na(DATE_VISA_V1)) {
    attendu_echec(paste0(nom, " : date_visa renseignée"), "#19, visa du mainteneur en attente (M188)",
                  !is.na(m$date_visa))
  } else {
    verifier(paste0(nom, " : date_visa renseignée"), !is.na(m$date_visa))
  }
}

bilan()
