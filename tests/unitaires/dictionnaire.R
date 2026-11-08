# Tests unitaires du module `dictionnaire` (R/dictionnaire.R) et témoins du contrôle
# tests/controles/concordance_dictionnaire.R. Exécuté par tests/test_unitaires.R : le
# package est installé et chargé, le harnais est sourcé, `racine` est défini.
# Les copies altérées du dictionnaire sont écrites octet par octet (writeBin) : une écriture
# par write.table() ou writeLines() sous une locale C traduirait les caractères non ASCII.

ns <- asNamespace("provie")
lire_dictionnaire <- ns$.lire_dictionnaire
source_dico <- system.file("extdata", "dictionnaire", package = "provie")
fichiers_csv <- c("tables.csv", "colonnes.csv", "types_evenements.csv", "parametres.csv",
                  "defauts.csv", "filiation.csv", "controles.csv")

motif_de <- function(expr) {
  tryCatch({ expr; "aucun" }, refus_provie = function(e) e$motif,
           error = function(e) paste("autre :", conditionMessage(e)))
}
refus_de <- function(expr) tryCatch({ expr; NULL }, refus_provie = function(e) e)

# --- Outils de copie et d'altération ----------------------------------------------------

lire_csv_test <- function(chemin) {
  utils::read.csv(chemin, colClasses = "character", na.strings = character(0),
                  encoding = "UTF-8", check.names = FALSE, stringsAsFactors = FALSE)
}
ecrire_csv_test <- function(df, chemin) {
  champ <- function(x) paste0("\"", gsub("\"", "\"\"", x, fixed = TRUE), "\"")
  lignes <- c(paste(champ(names(df)), collapse = ","),
              apply(as.matrix(df), 1L, function(l) paste(champ(l), collapse = ",")))
  texte <- enc2utf8(paste0(paste(lignes, collapse = "\n"), "\n"))
  writeBin(charToRaw(texte), chemin)
}
octets <- function(chemin) readBin(chemin, "raw", n = file.info(chemin)$size)
# Réécrit dictionnaire.txt avec les empreintes des CSV présents.
reecrire_entete <- function(dossier, version = "1.5") {
  empreintes <- lapply(fichiers_csv, function(f) ns$empreinte(octets(file.path(dossier, f))))
  names(empreintes) <- fichiers_csv
  writeBin(ns$ecrire_liste(list(version = version, date_visa = as.Date("2026-11-08"),
                                empreintes = empreintes)),
           file.path(dossier, "dictionnaire.txt"))
}
copie_dico <- function() {
  d <- tempfile("dico-")
  dir.create(d)
  file.copy(list.files(source_dico, full.names = TRUE), d)
  d
}
# Copie dont un CSV est altéré par `f` ; l'en-tête est réécrit sauf si `entete = FALSE`.
copie_alteree <- function(fichier, f, entete = TRUE) {
  d <- copie_dico()
  ecrire_csv_test(f(lire_csv_test(file.path(d, fichier))), file.path(d, fichier))
  if (entete) reecrire_entete(d)
  d
}

# --- Exports ----------------------------------------------------------------------------

section("dictionnaire : exports")
verifier("dictionnaire() et controler_types() sont exportés",
         all(c("dictionnaire", "controler_types") %in% getNamespaceExports("provie")))
verifier("les auxiliaires du module ne sont pas exportés",
         !any(c(".lire_dictionnaire", ".controler_types_table", ".controler_extraction") %in%
                getNamespaceExports("provie")))

# --- Lecture du dictionnaire du package ---------------------------------------------------

section("dictionnaire : lecture de la forme lisible par machine")
d <- dictionnaire()
verifier_egal("champs de l'objet, dans l'ordre", names(d),
              c("version", "date_visa", "tables", "colonnes", "types_evenements", "parametres",
                "defauts", "filiation", "controles"))
verifier_egal("version 1.5", d$version, "1.5")
verifier_egal("version égale à VERSION_DICTIONNAIRE_ATTENDUE", d$version, ns$VERSION_DICTIONNAIRE_ATTENDUE)
verifier_egal("date de visa", d$date_visa, as.Date("2026-11-08"))
verifier_egal("décomptes des sept CSV", vapply(d[3:9], nrow, 0L),
              c(tables = 20L, colonnes = 171L, types_evenements = 17L, parametres = 26L,
                defauts = 25L, filiation = 109L, controles = 10L))
verifier_egal("vingt tables, dans l'ordre T1 à T20", d$tables$table,
              c("extraction", "adherents", "contrats", "garanties_souscrites", "parametres",
                "assures", "affiliations", "famille", "sinistres", "dossiers", "beneficiaires",
                "rentes", "evenements", "prestations", "cotisations", "catastrophes", "victimes",
                "evaluations_gestion", "designations", "ayants_droit_sante"))
verifier_egal("tables facultatives", d$tables$table[d$tables$obligatoire != "O"],
              c("catastrophes", "victimes", "evaluations_gestion", "designations", "ayants_droit_sante"))
verifier_egal("victimes : obligatoire si catastrophes est présente",
              d$tables$obligatoire[d$tables$table == "victimes"], "F_si:catastrophes")
verifier("types des colonnes parmi les cinq de la section 1.2",
         all(d$colonnes$type %in% c("character", "integer", "numeric", "Date", "logical")))
verifier("futur_admis : TRUE, FALSE ou programmable, autre que FALSE sur des colonnes Date seulement",
         is.character(d$colonnes$futur_admis) &&
           all(d$colonnes$futur_admis %in% c("TRUE", "FALSE", "programmable")) &&
           all(d$colonnes$type[d$colonnes$futur_admis != "FALSE"] == "Date"))
verifier_egal("futur_admis programmable : evenements.date_effet seulement",
              paste(d$colonnes$table, d$colonnes$colonne, sep = ".")[d$colonnes$futur_admis == "programmable"],
              "evenements.date_effet")
verifier_egal("D01a : toutes les tables à clé primaire, parametres comprise, extraction exclue",
              d$defauts$tables[d$defauts$code == "D01a"],
              paste(d$tables$table[d$tables$cle_primaire != ""], collapse = ";"))
verifier_egal("D07 : table evenements (types d'événements cités)", d$defauts$tables[d$defauts$code == "D07"], "evenements")
verifier_egal("D09 : traitements R, X, H, S (R en gras dans la colonne Détection)",
              d$defauts$traitements[d$defauts$code == "D09"], "R;X;H;S")
verifier_egal("ordre des types d'événements entier", d$types_evenements$ordre, 1:17)
verifier("chaque référence désigne une colonne décrite (référence composite comprise)", {
  refs <- unlist(strsplit(d$colonnes$reference[d$colonnes$reference != ""], ";", fixed = TRUE))
  all(refs %in% paste(d$colonnes$table, d$colonnes$colonne, sep = "."))
})
verifier_egal("affiliations.college : clé étrangère composite (id_contrat, college) vers garanties_souscrites",
              d$colonnes$reference[d$colonnes$table == "affiliations" & d$colonnes$colonne == "college"],
              "garanties_souscrites.id_contrat;garanties_souscrites.college")
verifier_egal("une seule référence composite", sum(grepl(";", d$colonnes$reference, fixed = TRUE)), 1L)
verifier_egal("extraction.version_dictionnaire : seule modalité 1.5",
              d$colonnes$modalites[d$colonnes$table == "extraction" & d$colonnes$colonne == "version_dictionnaire"],
              "1.5")
verifier_egal("controles.csv : dix codes des contrôles de structure, dans l'ordre du texte (section 1.10)",
              d$controles$code,
              c("colonne_absente", "colonne_inconnue", "type_incompatible", "manquant_obligatoire",
                "hors_domaine", "chaine_vide", "chevauchement", "table_conditionnelle_absente",
                "refus_induit", "somme_parts"))
verifier_egal("controles.csv : portées", d$controles$portee,
              c("table", "table", rep("colonne_table", 4L), "table", "table", "table", "ligne"))
verifier_egal("controles.csv : motifs de refus d'appel, les trois motifs de forme seulement",
              d$controles$motif_refus_appel[d$controles$motif_refus_appel != ""],
              c("colonne_absente", "colonne_inconnue", "type_incompatible"))
verifier("controles.csv : codes disjoints de ceux de defauts.csv",
         length(intersect(d$controles$code, d$defauts$code)) == 0L)
verifier_egal("controles.csv : intersection avec MOTIFS_REFUS",
              intersect(d$controles$code, ns$MOTIFS_REFUS),
              c("colonne_absente", "colonne_inconnue", "type_incompatible"))
verifier("controles.csv : colonnes de texte", all(vapply(d$controles, is.character, NA)))
verifier_egal("automate : événements d'entrée",
              d$types_evenements$type_evenement[d$types_evenements$etat_depuis == "depart"],
              c("entree_incapacite", "entree_invalidite"))
verifier_egal("deux lectures : objets identiques", dictionnaire(), d)
verifier_egal("une copie fidèle du dossier se lit à l'identique", lire_dictionnaire(copie_dico()), d)

# --- Dictionnaire invalide -----------------------------------------------------------------

section("dictionnaire : refus dictionnaire_invalide")
verifier_refus("dossier absent", lire_dictionnaire(tempfile("absent-")), "dictionnaire_invalide")
verifier_refus("dossier vide de system.file() (package sans le dossier)", lire_dictionnaire(""),
               "dictionnaire_invalide")
verifier_refus("dossier NA", lire_dictionnaire(NA_character_), "dictionnaire_invalide")
x <- copie_dico(); unlink(file.path(x, "dictionnaire.txt"))
verifier_refus("dictionnaire.txt absent", lire_dictionnaire(x), "dictionnaire_invalide")
x <- copie_dico(); writeBin(charToRaw("version 1.3\n"), file.path(x, "dictionnaire.txt"))
verifier_refus("dictionnaire.txt illisible par lire_liste()", lire_dictionnaire(x), "dictionnaire_invalide")
x <- copie_dico(); reecrire_entete(x, version = "1.4")
e <- refus_de(lire_dictionnaire(x))
verifier("version 1.4 dans dictionnaire.txt : refus, attendu 1.5, reçu 1.4",
         !is.null(e) && e$motif == "dictionnaire_invalide" && identical(e$attendu, "1.5") &&
           identical(e$recu, "1.4"))
x <- copie_dico(); unlink(file.path(x, "controles.csv"))
verifier_refus("controles.csv absent", lire_dictionnaire(x), "dictionnaire_invalide")
x <- copie_dico()
writeBin(ns$ecrire_liste(list(version = "1.5", date_visa = as.Date("2026-11-08"),
                              empreintes = lapply(stats::setNames(fichiers_csv[1:6], fichiers_csv[1:6]),
                                                  function(f) ns$empreinte(octets(file.path(x, f)))))),
         file.path(x, "dictionnaire.txt"))
verifier_refus("dictionnaire.txt sans l'empreinte de controles.csv (forme de la version 1.4)",
               lire_dictionnaire(x), "dictionnaire_invalide")
x <- copie_dico(); unlink(file.path(x, "parametres.csv"))
verifier_refus("CSV absent", lire_dictionnaire(x), "dictionnaire_invalide")
x <- copie_alteree("colonnes.csv", function(df) { df$domaine[1L] <- "autre"; df }, entete = FALSE)
verifier_refus("CSV modifié sans mise à jour de l'empreinte", lire_dictionnaire(x), "dictionnaire_invalide")
x <- copie_alteree("colonnes.csv", function(df) { df$type[df$colonne == "sexe"][1L] <- "factor"; df })
verifier_refus("type hors des cinq (factor)", lire_dictionnaire(x), "dictionnaire_invalide")
x <- copie_alteree("colonnes.csv", function(df) { df$reference[df$reference != ""][1L] <- "adherents.inconnue"; df })
verifier_refus("référence vers une colonne inconnue", lire_dictionnaire(x), "dictionnaire_invalide")
avec_reference_college <- function(ref) {
  copie_alteree("colonnes.csv", function(df) {
    df$reference[df$table == "affiliations" & df$colonne == "college"] <- ref
    df
  })
}
motif_reference <- function(ref) {
  e <- refus_de(lire_dictionnaire(avec_reference_college(ref)))
  if (is.null(e)) "aucun" else paste(e$motif, conditionMessage(e))
}
verifier("référence composite vers deux tables : refus",
         grepl("^dictionnaire_invalide .*composite vers plusieurs tables",
               motif_reference("garanties_souscrites.id_contrat;contrats.id_contrat")))
verifier("référence composite dont une colonne locale manque (code_garantie absente d'affiliations) : refus",
         grepl("^dictionnaire_invalide .*colonne locale manque",
               motif_reference("garanties_souscrites.code_garantie;garanties_souscrites.college")))
verifier("référence composite qui vise une colonne inconnue : refus",
         grepl("^dictionnaire_invalide .*colonne inconnue",
               motif_reference("garanties_souscrites.id_contrat;garanties_souscrites.inconnue")))
verifier("référence composite qui cite deux fois une colonne : refus",
         grepl("^dictionnaire_invalide .*cite deux fois une colonne",
               motif_reference("garanties_souscrites.college;garanties_souscrites.college")))
for (ref in c("garanties_souscrites.id_contrat;", ";garanties_souscrites.college",
              "garanties_souscrites.id_contrat;;garanties_souscrites.college")) {
  verifier(paste0("référence mal formée « ", ref, " » : refus"),
           startsWith(motif_reference(ref), "dictionnaire_invalide"))
}
verifier("référence composite dont le n-uplet ne contient pas la colonne de la ligne (college) : refus",
         grepl("^dictionnaire_invalide .*ne contient pas la colonne de la ligne",
               motif_reference("garanties_souscrites.id_contrat;garanties_souscrites.date_fin")))
verifier("référence composite vers la table qui la porte (affiliations) : refus",
         grepl("^dictionnaire_invalide .*vers la table qui la porte",
               motif_reference("affiliations.id_contrat;affiliations.college")))
verifier_egal("référence simple (garanties_souscrites.college) : forme admise par le module, l'écart au texte relève de la concordance",
              motif_reference("garanties_souscrites.college"), "aucun")
x <- copie_alteree("colonnes.csv", function(df) { df$defauts[df$defauts == "D01a"][1L] <- "D99"; df })
verifier_refus("code de défaut inconnu", lire_dictionnaire(x), "dictionnaire_invalide")
x <- copie_alteree("colonnes.csv", function(df) { df$colonne_saisie[df$saisie == "P"][1L] <- "date_effet"; df })
verifier_refus("colonne_saisie qui n'est pas une date de saisie", lire_dictionnaire(x), "dictionnaire_invalide")
x <- copie_alteree("colonnes.csv", function(df) { df$futur_admis[1L] <- "oui"; df })
verifier_refus("futur_admis hors de TRUE, FALSE, programmable", lire_dictionnaire(x), "dictionnaire_invalide")
x <- copie_alteree("colonnes.csv", function(df) { df$futur_admis[df$table == "contrats" & df$colonne == "date_fin"] <- "programmable"; df })
verifier_refus("futur_admis programmable hors de la table evenements", lire_dictionnaire(x), "dictionnaire_invalide")
x <- copie_alteree("colonnes.csv", function(df) { df$futur_admis[df$colonne == "id_contrat"][1L] <- "TRUE"; df })
verifier_refus("futur_admis TRUE sur une colonne non Date", lire_dictionnaire(x), "dictionnaire_invalide")
x <- copie_alteree("tables.csv", function(df) { df$en_trop <- ""; df })
verifier_refus("colonne en trop dans un CSV", lire_dictionnaire(x), "dictionnaire_invalide")
x <- copie_alteree("types_evenements.csv", function(df) { df$colonnes_requises[2L] <- "inconnue"; df })
verifier_refus("colonne requise d'un événement inconnue", lire_dictionnaire(x), "dictionnaire_invalide")
x <- copie_alteree("tables.csv", function(df) { df$cle_primaire[2L] <- "id_inconnu"; df })
verifier_refus("colonne de clé primaire inconnue", lire_dictionnaire(x), "dictionnaire_invalide")

section("dictionnaire : refus dictionnaire_invalide, controles.csv")
motif_controles <- function(f) {
  e <- refus_de(lire_dictionnaire(copie_alteree("controles.csv", f)))
  if (is.null(e)) "aucun" else paste(e$motif, conditionMessage(e))
}
verifier("colonne manquante (portee) : refus",
         grepl("^dictionnaire_invalide .*colonnes de controles\\.csv",
               motif_controles(function(df) { df$portee <- NULL; df })))
verifier("colonne manquante (motif_refus_appel) : refus",
         grepl("^dictionnaire_invalide .*colonnes de controles\\.csv",
               motif_controles(function(df) { df$motif_refus_appel <- NULL; df })))
verifier("portée hors liste (colonne, table, colonne_table, ligne) : refus",
         grepl("^dictionnaire_invalide .*controles\\.csv, ligne 3 : port",
               motif_controles(function(df) { df$portee[2L] <- "base"; df })))
verifier("portée vide : refus",
         startsWith(motif_controles(function(df) { df$portee[10L] <- ""; df }), "dictionnaire_invalide"))
verifier("code en double : refus",
         grepl("^dictionnaire_invalide .*controles\\.csv : codes distincts",
               motif_controles(function(df) { df$code[5L] <- df$code[4L]; df })))
verifier("code de la forme d'un défaut (D09) : refus",
         grepl("^dictionnaire_invalide .*controles\\.csv : codes distincts",
               motif_controles(function(df) { df$code[4L] <- "D09"; df })))
verifier("motif de refus d'appel hors de MOTIFS_REFUS : refus",
         grepl("^dictionnaire_invalide .*hors de MOTIFS_REFUS : fichier_invalide",
               motif_controles(function(df) { df$motif_refus_appel[4L] <- "fichier_invalide"; df })))
verifier("détection hors de exacte, presomptive : refus",
         startsWith(motif_controles(function(df) { df$detection[1L] <- "probable"; df }), "dictionnaire_invalide"))
verifier("objet vide : refus",
         startsWith(motif_controles(function(df) { df$objet[1L] <- ""; df }), "dictionnaire_invalide"))
verifier_egal("portée colonne (admise, non employée par le texte 1.5) : admise",
              motif_controles(function(df) { df$portee[3L] <- "colonne"; df }), "aucun")

# --- controler_types ------------------------------------------------------------------------

vide_de <- function(type) {
  switch(type, character = character(0), integer = integer(0), numeric = numeric(0),
         logical = logical(0), Date = as.Date(character(0)))
}
# Base conforme : toutes les tables, toutes les colonnes, vides sauf extraction (une ligne).
base <- lapply(d$tables$table, function(t) {
  col <- d$colonnes[d$colonnes$table == t, ]
  df <- as.data.frame(lapply(col$type, vide_de), stringsAsFactors = FALSE)
  names(df) <- col$colonne
  df
})
names(base) <- d$tables$table
base$extraction <- data.frame(date_extraction = as.Date("2026-12-31"),
                              debut_historique = as.Date("2017-01-01"),
                              type_organisme = "mutuelle", version_dictionnaire = "1.5",
                              devise = "EUR", stringsAsFactors = FALSE)
avec <- function(table, colonne, valeur) {
  b <- base
  b[[table]][[colonne]] <- valeur
  b
}

section("controler_types : bases conformes")
verifier("base complète conforme : rendue inchangée", identical(controler_types(base), base))
verifier("le résultat est invisible", identical(withVisible(controler_types(base))$visible, FALSE))
verifier("liste vide : rien à contrôler", identical(controler_types(list()), list()))
verifier("une table seule (feuille) est contrôlée sans les autres",
         identical(controler_types(base["contrats"]), base["contrats"]))
b <- base; b$adherents$secteur_activite <- NULL
verifier("colonne facultative absente : admise", identical(controler_types(b), b))
b <- base; b$catastrophes <- NULL; b$victimes <- NULL
verifier("tables facultatives absentes : admises", identical(controler_types(b), b))
b <- base; b$contrats <- base$contrats[, rev(names(base$contrats))]
verifier("ordre des colonnes libre", identical(controler_types(b), b))

section("controler_types : type incompatible, sans conversion")
b <- avec("assures", "date_naissance", character(0))
e <- refus_de(controler_types(b))
verifier("Date reçue en character : type_incompatible, table, colonne, attendu, reçu",
         !is.null(e) && e$motif == "type_incompatible" && e$table == "assures" &&
           e$colonne == "date_naissance" && e$attendu == "Date" && e$recu == "character")
verifier("la base refusée n'est pas modifiée", identical(b$assures$date_naissance, character(0)))
verifier_refus("numeric reçu en integer", controler_types(avec("parametres", "valeur", integer(0))),
               "type_incompatible")
verifier_refus("integer reçu en numeric", controler_types(avec("contrats", "mois_echeance", numeric(0))),
               "type_incompatible")
verifier_refus("character reçu en factor", controler_types(avec("contrats", "id_contrat", factor(character(0)))),
               "type_incompatible")
verifier_refus("logical reçu en character", controler_types(avec("contrats", "tacite_reconduction", character(0))),
               "type_incompatible")
verifier_refus("Date reçue en POSIXct", controler_types(avec("contrats", "date_effet", as.POSIXct(character(0), tz = "UTC"))),
               "type_incompatible")
verifier_refus("Date reçue en logical (colonne vide d'un tableur)",
               controler_types(avec("contrats", "date_fin", logical(0))), "type_incompatible")
e <- refus_de(controler_types(avec("contrats", "date_effet", structure(integer(0), class = "Date"))))
verifier("Date stockée en integer : type_incompatible, reçu « Date (integer) »",
         !is.null(e) && e$motif == "type_incompatible" && e$recu == "Date (integer)")
verifier("Date stockée en integer : le message dit pourquoi (typeof, empreintes) et comment corriger",
         !is.null(e) && grepl("typeof integer", conditionMessage(e), fixed = TRUE) &&
           grepl("typeof double", conditionMessage(e), fixed = TRUE) &&
           grepl("empreintes", conditionMessage(e), fixed = TRUE) &&
           grepl("as.Date(as.numeric(x))", conditionMessage(e), fixed = TRUE))
verifier("la correction proposée rend une Date conforme",
         identical(controler_types(avec("contrats", "date_effet", as.Date(as.numeric(structure(integer(0), class = "Date"))))),
                   avec("contrats", "date_effet", as.Date(as.numeric(structure(integer(0), class = "Date"))))))
verifier_refus("numeric marqué AsIs", controler_types(avec("parametres", "valeur", I(numeric(0)))),
               "type_incompatible")
b <- base; b$extraction$devise <- 1
verifier_refus("character reçu en numeric (table extraction)", controler_types(b), "type_incompatible")

section("controler_types : colonnes inconnues ou absentes")
e <- refus_de(controler_types(avec("contrats", "inconnue", character(0))))
verifier("colonne inconnue : colonne_inconnue, colonne nommée",
         !is.null(e) && e$motif == "colonne_inconnue" && e$table == "contrats" && e$colonne == "inconnue")
b <- base; b$contrats$id_contrat <- NULL
e <- refus_de(controler_types(b))
verifier("colonne obligatoire absente : colonne_absente",
         !is.null(e) && e$motif == "colonne_absente" && e$colonne == "id_contrat")
b <- base; b$contrats$id_adherent <- NULL
verifier_refus("colonne conditionnelle absente : colonne_absente", controler_types(b), "colonne_absente")

section("controler_types : liste invalide")
verifier_refus("data.frame seul", controler_types(base$contrats), "liste_invalide")
verifier_refus("vecteur", controler_types("contrats"), "liste_invalide")
verifier_refus("liste sans noms", controler_types(unname(base["contrats"])), "liste_invalide")
verifier_refus("noms dupliqués", controler_types(list(contrats = base$contrats, contrats = base$contrats)),
               "liste_invalide")
verifier_refus("table inconnue du dictionnaire", controler_types(list(contrat = base$contrats)), "liste_invalide")
verifier_refus("élément qui n'est pas un data.frame", controler_types(list(contrats = list())), "liste_invalide")
b <- base; names(b$adherents)[2L] <- "id_adherent"
verifier_refus("noms de colonnes dupliqués", controler_types(b), "liste_invalide")

section("controler_types : table extraction")
e <- refus_de(controler_types(avec("extraction", "version_dictionnaire", "1.2")))
verifier("version 1.2 : extraction_invalide, attendu 1.5, reçu 1.2",
         !is.null(e) && e$motif == "extraction_invalide" && e$colonne == "version_dictionnaire" &&
           identical(e$attendu, "1.5") && identical(e$recu, "1.2"))
e <- refus_de(controler_types(avec("extraction", "version_dictionnaire", "1.4")))
verifier("version 1.4, version précédente : extraction_invalide, reçu 1.4",
         !is.null(e) && e$motif == "extraction_invalide" && identical(e$recu, "1.4"))
for (v in c("1.0", "1.1", "1.2", "1.3", "1.4", "1.50", " 1.5", "")) {
  verifier_refus(paste0("version « ", v, " » refusée"),
                 controler_types(avec("extraction", "version_dictionnaire", v)), "extraction_invalide")
}
verifier_refus("version manquante", controler_types(avec("extraction", "version_dictionnaire", NA_character_)),
               "extraction_invalide")
b <- base; b$extraction <- rbind(base$extraction, base$extraction)
verifier_refus("deux lignes", controler_types(b), "extraction_invalide")
b <- base; b$extraction <- base$extraction[0L, ]
verifier_refus("aucune ligne", controler_types(b), "extraction_invalide")
b <- avec("extraction", "version_dictionnaire", "1.2"); b$contrats$id_contrat <- integer(0)
b <- avec("extraction", "version_dictionnaire", "1.2"); b$extraction$colonne_de_la_1_2 <- "x"
verifier_egal("version lue avant les autres colonnes d'extraction : extraction_invalide, pas colonne_inconnue",
              motif_de(controler_types(b)), "extraction_invalide")
b <- avec("extraction", "version_dictionnaire", "1.2"); b$extraction$devise <- NULL
verifier_egal("version lue avant les colonnes absentes d'extraction", motif_de(controler_types(b)), "extraction_invalide")
b <- base; b$extraction$version_dictionnaire <- 1.5
verifier_egal("version de type numeric : type_incompatible (non lue)", motif_de(controler_types(b)), "type_incompatible")
b <- base; b$extraction <- rbind(base$extraction, base$extraction); b$extraction$version_dictionnaire[2L] <- "1.2"
verifier_egal("deux lignes dont une d'une autre version : extraction_invalide sur la version",
              refus_de(controler_types(b))$colonne, "version_dictionnaire")
verifier_egal("version contrôlée avant les autres tables (extraction est T1)",
              motif_de(controler_types(b)), "extraction_invalide")

# --- Témoins du contrôle de concordance --------------------------------------------------

section("contrôle concordance_dictionnaire.R : témoins")
racine_copie <- function() {
  r <- tempfile("racine-")
  dir.create(file.path(r, "docs", "specifications"), recursive = TRUE)
  dir.create(file.path(r, "R"))
  dir.create(file.path(r, "inst", "extdata", "dictionnaire"), recursive = TRUE)
  file.copy(file.path(racine, "docs", "specifications", "dictionnaire-base-v1.md"),
            file.path(r, "docs", "specifications"))
  file.copy(file.path(racine, "R", "outils.R"), file.path(r, "R"))
  file.copy(list.files(source_dico, full.names = TRUE), file.path(r, "inst", "extdata", "dictionnaire"))
  r
}
lancer_controle <- function(r) {
  sortie <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
                                     c(shQuote(file.path(racine, "tests", "controles", "concordance_dictionnaire.R")),
                                       shQuote(r)), stdout = TRUE, stderr = TRUE))
  statut <- attr(sortie, "status")
  list(statut = if (is.null(statut)) 0L else statut, sortie = sortie)
}
echoue_sur <- function(res, motif) res$statut == 1L && any(grepl(motif, res$sortie[grepl("^\\[ECHEC\\]", res$sortie)]))
dico_de <- function(r) file.path(r, "inst", "extdata", "dictionnaire")
alterer <- function(r, fichier, f, entete = TRUE) {
  ecrire_csv_test(f(lire_csv_test(file.path(dico_de(r), fichier))), file.path(dico_de(r), fichier))
  if (entete) reecrire_entete(dico_de(r))
}

r <- racine_copie()
verifier("copie fidèle : contrôle vert", lancer_controle(r)$statut == 0L)
r <- racine_copie(); alterer(r, "colonnes.csv", function(df) { df$domaine[3L] <- paste(df$domaine[3L], "x"); df })
verifier("domaine du CSV modifié : ECHEC sur colonnes.csv", echoue_sur(lancer_controle(r), "colonnes\\.csv:4 "))
r <- racine_copie()
md <- file.path(r, "docs", "specifications", "dictionnaire-base-v1.md")
texte <- readLines(md, encoding = "UTF-8", warn = FALSE)
i <- grep("^\\| `devise` \\| character \\|", texte)
texte[i] <- sub("`EUR`", "`EUR`, `CHF`", texte[i], fixed = TRUE)
writeBin(charToRaw(paste0(paste(texte, collapse = "\n"), "\n")), md)
verifier("texte modifié sans nouvelle transcription : ECHEC", echoue_sur(lancer_controle(r), "colonnes\\.csv"))
r <- racine_copie()
alterer(r, "colonnes.csv", function(df) {
  i <- df$colonne == "type_organisme"
  df$modalites[i] <- "societe_assurance;institution_prevoyance"
  df
})
verifier("modalité oubliée (mutuelle) : ECHEC", echoue_sur(lancer_controle(r), "mutuelle"))
temoin <- function(nom, fichier, f, motif) {
  r <- racine_copie()
  alterer(r, fichier, f)
  verifier(paste0(nom, " : ECHEC"), echoue_sur(lancer_controle(r), motif))
}
vider <- function(colonne) function(df) { df$modalites[df$colonne == colonne] <- ""; df }
temoin("modalités vidées (affiliations.type_affiliation)", "colonnes.csv", vider("type_affiliation"), "modalites")
temoin("modalités vidées (prestations.type_prestation)", "colonnes.csv", vider("type_prestation"), "modalites")
temoin("modalités vidées (extraction.version_dictionnaire)", "colonnes.csv", vider("version_dictionnaire"), "modalites")
temoin("modalités permutées (contrats.motif_fin)", "colonnes.csv", function(df) {
  i <- df$table == "contrats" & df$colonne == "motif_fin"
  df$modalites[i] <- paste(rev(strsplit(df$modalites[i], ";", fixed = TRUE)[[1L]]), collapse = ";")
  df
}, "modalites")
temoin("modalité oubliée qui a un autre sens (type_assiette sans salaire_reference)", "colonnes.csv",
       function(df) { df$modalites[df$colonne == "type_assiette"] <- "forfait;capital_deces"; df }, "modalites")
temoin("motif retiré (cloture_dossier sans autre)", "types_evenements.csv", function(df) {
  df$motifs[df$type_evenement == "cloture_dossier"] <- "regle;sans_suite;refus;prescription;depot_cdc;extinction"
  df
}, "motifs")
temoin("unité vidée (prestations.montant)", "colonnes.csv", function(df) {
  df$unite[df$table == "prestations" & df$colonne == "montant"] <- ""
  df
}, "unite")
temoin("unité remplacée par une sous-chaîne du domaine (preavis_mois -> avis)", "colonnes.csv", function(df) {
  df$unite[df$colonne == "preavis_mois"] <- "avis"
  df
}, "unite")
temoin("table v1 d'une colonne renommée remplacée par une autre table admise (option_rente_education)",
       "filiation.csv", function(df) { df$table_v1[df$colonne_de == "option_rente_education"] <- "contrats"; df }, "table_v1")
temoin("etat_depuis permuté (sortie)", "types_evenements.csv", function(df) {
  df$etat_depuis[df$type_evenement == "sortie"] <- "invalidite;incapacite"
  df
}, "etat_depuis")
temoin("futur_admis de evenements.date_effet remis à FALSE", "colonnes.csv", function(df) {
  df$futur_admis[df$table == "evenements" & df$colonne == "date_effet"] <- "FALSE"
  df
}, "futur_admis")
temoin("sous-paramètres permutés (D07)", "defauts.csv", function(df) {
  df$sous_parametres[df$code == "D07"] <- "fin_de_charge;deces_connu_ailleurs"
  df
}, "ordre")
temoin("sous-paramètre ajouté qui porte le nom d'une table (D04b : evenements, réserve R1, M138)", "defauts.csv",
       function(df) { df$sous_parametres[df$code == "D04b"] <- "evenements"; df }, "D04b : .*nom d'une table")
temoin("sous-paramètre ajouté qui porte le nom d'une modalité (D03a : concubin)", "defauts.csv",
       function(df) { df$sous_parametres[df$code == "D03a"] <- "part_non_au_hasard;concubin"; df },
       "D03a : .*nom d'une table ou d'une modalit")
temoin("référence composite de affiliations.college restée à la forme de la version 1.3", "colonnes.csv",
       function(df) {
         df$reference[df$table == "affiliations" & df$colonne == "college"] <- "garanties_souscrites.college"
         df
       }, "colonnes\\.csv:62 .*champ `reference`")
r <- racine_copie(); alterer(r, "parametres.csv", function(df) { df$unite[1L] <- "x"; df }, entete = FALSE)
verifier("CSV modifié sans mise à jour de l'empreinte : ECHEC", echoue_sur(lancer_controle(r), "empreinte de parametres\\.csv"))
r <- racine_copie()
alterer(r, "types_evenements.csv", function(df) { df$etat_vers[df$type_evenement == "passage_invalidite"] <- "clos"; df })
verifier("automate altéré (etat_vers de passage_invalidite) : ECHEC", echoue_sur(lancer_controle(r), "etat_vers"))
r <- racine_copie()
alterer(r, "defauts.csv", function(df) { df$sous_parametres[df$code == "D09"] <- "facteur;capital_incoherent"; df })
verifier("sous-paramètre oublié (part_signe_inverse) : ECHEC", echoue_sur(lancer_controle(r), "part_signe_inverse"))
r <- racine_copie()
outils_r <- file.path(r, "R", "outils.R")
writeBin(charToRaw(sub("VERSION_DICTIONNAIRE_ATTENDUE <- \"1.5\"", "VERSION_DICTIONNAIRE_ATTENDUE <- \"1.6\"",
                       rawToChar(octets(outils_r)), fixed = TRUE, useBytes = TRUE)), outils_r)
verifier("constante du moteur différente de la version du texte : ECHEC", echoue_sur(lancer_controle(r), "version"))

section("contrôle concordance_dictionnaire.R : témoins de controles.csv")
temoin("code retiré (somme_parts)", "controles.csv", function(df) df[df$code != "somme_parts", ],
       "controles\\.csv : 9 lignes, 10 dans le texte")
temoin("portée changée (chevauchement : table -> colonne_table)", "controles.csv", function(df) {
  df$portee[df$code == "chevauchement"] <- "colonne_table"
  df
}, "controles\\.csv:8 .*champ `portee`")
temoin("code dupliqué (hors_domaine à la place de chaine_vide)", "controles.csv", function(df) {
  df$code[df$code == "chaine_vide"] <- "hors_domaine"
  df
}, "controles\\.csv : code en double : hors_domaine")
temoin("code commun avec un défaut (D09)", "controles.csv", function(df) {
  df$code[df$code == "somme_parts"] <- "D09"
  df
}, "controles\\.csv : codes communs avec defauts\\.csv : D09")
temoin("motif de refus d'appel retiré (type_incompatible)", "controles.csv", function(df) {
  df$motif_refus_appel[df$code == "type_incompatible"] <- ""
  df
}, "controles\\.csv:4 .*champ `motif_refus_appel`")
r <- racine_copie()
outils_r <- file.path(r, "R", "outils.R")
writeBin(charToRaw(sub("\"type_incompatible\", ", "", rawToChar(octets(outils_r)), fixed = TRUE, useBytes = TRUE)), outils_r)
verifier("MOTIFS_REFUS sans type_incompatible : ECHEC sur l'intersection",
         echoue_sur(lancer_controle(r), "intersection avec MOTIFS_REFUS : colonne_absente, colonne_inconnue ;"))
r <- racine_copie(); unlink(file.path(dico_de(r), "controles.csv"))
verifier("controles.csv absent : ECHEC sur la liste des fichiers", echoue_sur(lancer_controle(r), "fichiers : "))
r <- racine_copie()
md <- file.path(r, "docs", "specifications", "dictionnaire-base-v1.md")
texte <- readLines(md, encoding = "UTF-8", warn = FALSE)
i <- grep("^\\| `somme_parts` \\|", texte)
texte[i] <- sub("| ligne |", "| colonne |", texte[i], fixed = TRUE)
writeBin(charToRaw(enc2utf8(paste0(paste(texte, collapse = "\n"), "\n"))), md)
verifier("portée changée dans le texte sans nouvelle transcription : ECHEC",
         echoue_sur(lancer_controle(r), "controles\\.csv:11 .*champ `portee`"))
