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

section("garanties : postes_a_arreter() (M239 ; spécification de B2, § 6.2, critère 3.8, #66)")

# Bilans construits (seules les colonnes lues par postes_a_arreter() comptent) et bilan de
# v1-modeste-02 aux deux arrêtés.
cat_g <- catalogue_garanties()
postes_b2 <- list(deces = list(capitaux_non_reclames = list(), provision_mathematique_temporaire_deces = list(),
                               sinistres_declares_non_regles = list()))
bilan_de <- function(rt, nd = NULL) {
  n <- length(rt[[1L]])
  rt <- data.frame(table = rt[[1L]], colonne = rt[[2L]], motif = rt[[3L]], portee = rt[[4L]], origine = rep(NA_character_, n),
                   nombre = rep(1L, n), nombre_visibles = rep(1L, n), identifiants = rep("X", n), nombre_dossiers = rep(1L, n),
                   postes_arretes = rep(NA_character_, n), stringsAsFactors = FALSE)
  if (is.null(nd)) nd <- list(character(0), character(0), character(0), character(0))
  nd <- data.frame(table = nd[[1L]], colonne = nd[[2L]], motif = nd[[3L]], origine = nd[[4L]],
                   nombre = rep(1L, length(nd[[1L]])), identifiants = rep("X", length(nd[[1L]])), stringsAsFactors = FALSE)
  list(refus_tables = rt, vue = list(visibilite_non_determinee = nd))
}
arrets <- function(b) ns$postes_a_arreter(cat_g, b, postes_b2, ns$parties_ligne())
verifier_egal("règle (i) : refus de portée table sur cotisations (refus induit compris) : P3 seul arrêté ; sur prestations : P1 et P2",
              list(arrets(bilan_de(list("cotisations", NA_character_, "refus_induit", "table")))$postes$motif_arret,
                   arrets(bilan_de(list("prestations", "id_dossier", "type_incompatible", "table")))$postes$motif_arret),
              list(c(NA, "refus_induit", NA), c("type_incompatible", NA, "type_incompatible")))
verifier_egal("règle (ii) : refus de portée colonne sur (sinistres, date_instruction) : P1 et P2 ; sur (sinistres, cause), colonne que nul ne lit : aucun poste, postes_arretes NA ; motif de la première ligne du bilan",
              list(arrets(bilan_de(list("sinistres", "date_instruction", "type_incompatible", "colonne")))$postes$motif_arret,
                   arrets(bilan_de(list("sinistres", "cause", "hors_domaine", "colonne")))$refus_tables$postes_arretes,
                   arrets(bilan_de(list(c("contrats", "garanties_souscrites"), c("date_terme", "taux_technique_tarif"),
                                        c("manquant_obligatoire", "hors_domaine"), c("colonne", "colonne"))))$postes$motif_arret),
              list(c("type_incompatible", NA, "type_incompatible"), NA_character_, c(NA, "manquant_obligatoire", NA)))
nd_iii <- bilan_de(list("sinistres", "date_declaration", "D02c", "colonne"),
                   list(c("sinistres", "sinistres", "dossiers"), c(NA, "date_instruction", NA),
                        c("D02c", "D02c", "parente_non_determinee"), c("sinistres.date_declaration", "sinistres.date_instruction", NA)))
a_iii <- arrets(nd_iii)
verifier_egal("règle (iii) : ligne entière de sinistres non déterminée (D02c) : postes qui lisent sinistres ou une descendante (P1, P2, P3) ; partie de ligne : lecteurs de la colonne ; parente_non_determinee n'arrête rien ; postes_arretes sur la ligne de même table, colonne de l'origine et motif",
              list(a_iii$postes$motif_arret, a_iii$refus_tables$postes_arretes,
                   arrets(bilan_de(list(character(0), character(0), character(0), character(0)),
                                   list("dossiers", NA_character_, "parente_non_determinee", NA_character_)))$postes$motif_arret,
                   arrets(bilan_de(list(character(0), character(0), character(0), character(0)),
                                   list("evenements", NA_character_, "D02b", NA_character_)))$postes$motif_arret),
              list(rep("D02c", 3L),
                   "deces/capitaux_non_reclames;deces/provision_mathematique_temporaire_deces;deces/sinistres_declares_non_regles",
                   rep(NA_character_, 3L), rep(NA_character_, 3L)))
verifier_egal("règle (iii) : partie de ligne seule (sinistres.date_instruction, refus de valeur) : P1 et P2, non P3",
              arrets(bilan_de(list("sinistres", "date_instruction", "D02c", "colonne"),
                              list("sinistres", "date_instruction", "D02c", "sinistres.date_instruction")))$postes$motif_arret,
              c("D02c", NA, "D02c"))
j2 <- lire_jeu(file.path(racine, "inst", "extdata", "jeux", "v1-modeste-02"))
verifier_egal("(3.8) v1-modeste-02 aux deux arrêtés : refus D09 sur prestations.montant (portée colonne) : P1 et P2 arrêtés (D09), P3 non ; postes_arretes de la ligne",
              lapply(as.Date(c("2024-12-31", "2025-12-31")), function(a) {
                x <- arrets(controler_base(j2$base, a, j2$declarations$declarations, j2$declarations$conventions))
                list(x$postes$motif_arret, x$refus_tables$postes_arretes)
              }),
              rep(list(list(c("D09", NA, "D09"), "deces/capitaux_non_reclames;deces/sinistres_declares_non_regles")), 2L))
verifier_egal("postes_a_arreter() : bilan sans refus : aucun poste arrêté ; colonnes du bilan inchangées hors postes_arretes",
              { b <- bilan_de(list(character(0), character(0), character(0), character(0)))
                x <- arrets(b); list(x$postes$motif_arret, names(x$refus_tables), nrow(x$refus_tables)) },
              list(rep(NA_character_, 3L), names(bilan_de(list("a", "b", "c", "colonne"))$refus_tables), 0L))
verifier_egal("règle (iii), ligne entière non déterminée sur une table que nul ne lit (adherents) : postes qui lisent une descendante (contrats : P1, P2, P3) ; sous-cas D10a et D10h (traités R) sur dossiers : P1 et P2",
              list(arrets(bilan_de(list(character(0), character(0), character(0), character(0)),
                                   list("adherents", NA_character_, "manquant_obligatoire", NA_character_)))$postes$motif_arret,
                   arrets(bilan_de(list(character(0), character(0), character(0), character(0)),
                                   list("dossiers", NA_character_, "D10a", NA_character_)))$postes$motif_arret,
                   arrets(bilan_de(list(character(0), character(0), character(0), character(0)),
                                   list("dossiers", NA_character_, "D10h", NA_character_)))$postes$motif_arret),
              list(rep("manquant_obligatoire", 3L), c("D10a", NA, "D10a"), c("D10h", NA, "D10h")))
verifier_egal("partie de ligne (erratum v1.0.5) : une colonne de la partie vaut pour toute la partie ; (ii) refus de portée colonne sur affiliations.date_saisie_fin (que nul ne lit) : lecteurs de date_fin (P1, P2) ; (iii) partie non déterminée (affiliations.motif_fin) : idem ; contrats.date_saisie_fin : P3 ; colonne hors partie (affiliations.salaire_reference) : ses seuls lecteurs",
              list(arrets(bilan_de(list("affiliations", "date_saisie_fin", "D02c", "colonne")))$postes$motif_arret,
                   arrets(bilan_de(list(character(0), character(0), character(0), character(0)),
                                   list("affiliations", "motif_fin", "D02c", "affiliations.motif_fin")))$postes$motif_arret,
                   arrets(bilan_de(list("contrats", "date_saisie_fin", "D02c", "colonne")))$postes$motif_arret,
                   arrets(bilan_de(list("affiliations", "salaire_reference", "D09", "colonne")))$postes$motif_arret),
              list(c("D02c", NA, "D02c"), c("D02c", NA, "D02c"), c(NA, "D02c", NA), c("D09", NA, "D09")))
