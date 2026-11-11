# Tests unitaires du module `garanties` (R/garanties.R ; spécification de B2, § 4.1 et § 7.1,
# critère (1.1)). Exécuté par tests/test_unitaires.R : le package est installé et chargé, le
# harnais est sourcé, `racine` est défini.
# Les copies altérées du catalogue sont écrites octet par octet (writeBin) : une écriture par
# writeLines() sous une locale C traduirait les caractères non ASCII.

ns <- asNamespace("provie")
lire_catalogue <- ns$.lire_catalogue
source_catalogue <- system.file("extdata", "garanties", package = "provie")
fichiers_catalogue <- c("garanties.csv", "etats.csv", "transitions.csv", "flux.csv", "usages_tables.csv",
                        "postes.csv", "liens.csv", "lectures.csv")
motif_de <- function(expr) {
  tryCatch({ expr; "aucun" }, refus_provie = function(e) e$motif,
           error = function(e) paste("autre :", conditionMessage(e)))
}
refus_de <- function(expr) tryCatch({ expr; NULL }, refus_provie = function(e) e)
octets <- function(chemin) readBin(chemin, "raw", n = file.info(chemin)$size)

# Copie du catalogue du package dans un dossier temporaire, puis remplacement littéral de
# `de` par `vers` dans `fichier` (une occurrence au moins).
copie_alteree <- function(fichier, de, vers) {
  dossier <- tempfile("catalogue-")
  dir.create(dossier)
  file.copy(file.path(source_catalogue, fichiers_catalogue), dossier)
  chemin <- file.path(dossier, fichier)
  texte <- rawToChar(octets(chemin))
  Encoding(texte) <- "UTF-8"
  stopifnot(grepl(de, texte, fixed = TRUE))
  writeBin(charToRaw(enc2utf8(sub(de, vers, texte, fixed = TRUE))), chemin)
  dossier
}
d <- dictionnaire()

section("garanties : catalogue de B2 (critère 1.1)")

verifier("catalogue_garanties() est exportée", "catalogue_garanties" %in% getNamespaceExports("provie"))
k <- catalogue_garanties()
verifier_egal("huit data.frame, dans l'ordre de COLONNES_CATALOGUE",
              names(k), c("garanties", "etats", "transitions", "flux", "usages_tables", "postes", "liens", "lectures"))
verifier_egal("fichiers du catalogue sous inst/extdata/garanties/ : exactement ceux de COLONNES_CATALOGUE",
              sort(list.files(source_catalogue), method = "radix"),
              sort(names(ns$COLONNES_CATALOGUE), method = "radix"))
verifier("colonnes de chaque fichier : celles de COLONNES_CATALOGUE",
         all(vapply(seq_along(k), function(i) identical(names(k[[i]]), ns$COLONNES_CATALOGUE[[i]]), NA)))
verifier_egal("B2 : la seule garantie deces", k$garanties$code_garantie, "deces")
verifier_egal("B2 : trois postes de deces, dans l'ordre du catalogue", k$postes$poste,
              c("sinistres_declares_non_regles", "capitaux_non_reclames", "provision_mathematique_temporaire_deces"))
verifier_egal("états lus en B2 : actif, deces, iad", k$etats$etat, c("actif", "deces", "iad"))
verifier_egal("absorbant et meilleure_estimation lus en logical",
              list(k$etats$absorbant, k$postes$meilleure_estimation), list(c(FALSE, TRUE, TRUE), c(TRUE, TRUE, FALSE)))
verifier_egal("liens.csv : en-tête seul en B2", nrow(k$liens), 0L)
verifier_egal("lectures.csv : 55, 56 et 32 colonnes lues par P1, P2 et P3",
              as.integer(table(factor(k$lectures$poste, levels = k$postes$poste))), c(55L, 56L, 32L))
verifier("lectures.csv : P2 lit les colonnes de P1 et sinistres.canal_declaration",
         identical(setdiff(paste(k$lectures$table, k$lectures$colonne)[k$lectures$poste == "capitaux_non_reclames"],
                           paste(k$lectures$table, k$lectures$colonne)[k$lectures$poste == "sinistres_declares_non_regles"]),
                   "sinistres canal_declaration") &&
           all(paste(k$lectures$table, k$lectures$colonne)[k$lectures$poste == "sinistres_declares_non_regles"] %in%
                 paste(k$lectures$table, k$lectures$colonne)[k$lectures$poste == "capitaux_non_reclames"]))
verifier("lectures.csv : chaque colonne citée existe au dictionnaire",
         all(paste(k$lectures$table, k$lectures$colonne) %in% paste(d$colonnes$table, d$colonnes$colonne)))
verifier_egal("méthodes de P3 : champs individuel et collectif, première méthode du champ recommandée",
              ns$methodes_poste(k$postes$methodes[3L], "p3", "methodes"),
              data.frame(champ = c("individuel", "individuel", "collectif"),
                         methode = c("prospective_prime_pure", "prospective_prime_declaree", "prorata_cotisation"),
                         stringsAsFactors = FALSE))
verifier_egal("témoin de P3 : individuel:retrospective",
              ns$methodes_poste(k$postes$temoins[3L], "p3", "temoins"),
              data.frame(champ = "individuel", methode = "retrospective", stringsAsFactors = FALSE))
verifier_egal("deux lectures : catalogue identique", catalogue_garanties(), k)

section("garanties : refus catalogue_invalide (critère 1.1)")

verifier_egal("code de garantie inconnu du dictionnaire",
              motif_de(lire_catalogue(copie_alteree("garanties.csv", "deces,deces,v1", "vie,deces,v1"), d)),
              "catalogue_invalide")
verifier_egal("type de flux hors liste",
              motif_de(lire_catalogue(copie_alteree("flux.csv", "deces,frais,frais,actif,",
                                                    "deces,frais,rente_periodique,actif,"), d)),
              "catalogue_invalide")
verifier_egal("méthode d'un champ inconnu (champ hors liste)",
              motif_de(lire_catalogue(copie_alteree("postes.csv", "collectif:prorata_cotisation",
                                                    "groupe:prorata_cotisation"), d)),
              "catalogue_invalide")
verifier_egal("méthode inconnue (non implémentée : jamais au catalogue)",
              motif_de(lire_catalogue(copie_alteree("postes.csv", "capital_dossier;capital_dossier_reglement",
                                                    "capital_dossier;chain_ladder_paiements"), d)),
              "catalogue_invalide")
r <- refus_de(lire_catalogue(copie_alteree("lectures.csv", "sinistres,canal_declaration", "sinistres,canal_inconnu"), d))
verifier("lectures.csv qui cite une colonne absente du dictionnaire : refus nommant la colonne",
         !is.null(r) && r$motif == "catalogue_invalide" && identical(r$identifiants, "sinistres.canal_inconnu"))
verifier_egal("en-tête altéré",
              motif_de(lire_catalogue(copie_alteree("etats.csv", "etat,individu", "etat,personne"), d)),
              "catalogue_invalide")
verifier_egal("état payeur absent de etats.csv",
              motif_de(lire_catalogue(copie_alteree("flux.csv", "capital_unique,iad,", "capital_unique,invalide,"), d)),
              "catalogue_invalide")
verifier_egal("paramètre de flux inconnu du dictionnaire pour la garantie",
              motif_de(lire_catalogue(copie_alteree("flux.csv", "majoration_enfant;age_fin_garantie",
                                                    "majoration_enfant;taux_rente"), d)),
              "catalogue_invalide")
verifier_egal("usage réservé serie_tme au catalogue",
              motif_de(lire_catalogue(copie_alteree("usages_tables.csv", "deces,mortalite_tarif,", "deces,serie_tme,"), d)),
              "catalogue_invalide")
verifier_egal("méthode à la fois option et témoin",
              motif_de(lire_catalogue(copie_alteree("postes.csv", ",individuel:retrospective",
                                                    ",individuel:prospective_prime_pure"), d)),
              "catalogue_invalide")
verifier_egal("absorbant ni TRUE ni FALSE",
              motif_de(lire_catalogue(copie_alteree("etats.csv", "actif,assure,FALSE", "actif,assure,faux"), d)),
              "catalogue_invalide")
verifier_egal("lien hors liste",
              motif_de(lire_catalogue(copie_alteree("liens.csv", "garantie,garantie_liee,lien\n",
                                                    "garantie,garantie_liee,lien\ndeces,deces,cousinage\n"), d)),
              "catalogue_invalide")
absent <- tempfile("catalogue-")
dir.create(absent)
file.copy(file.path(source_catalogue, setdiff(fichiers_catalogue, "lectures.csv")), absent)
verifier_egal("fichier absent (lectures.csv)", motif_de(lire_catalogue(absent, d)), "catalogue_invalide")
verifier_egal("dossier introuvable", motif_de(lire_catalogue(file.path(tempdir(), "absent-catalogue"), d)),
              "catalogue_invalide")
