# Tests unitaires du module `donnees` (R/donnees.R). Exécuté par tests/test_unitaires.R : le
# package est installé et chargé, le harnais est sourcé, `racine` est défini.
# Bases construites à la main : une base de référence valide (aucun constat), puis une
# altération par cas, qui déclenche un code de contrôle ou un défaut.

ns <- asNamespace("provie")
refus_de <- function(expr) tryCatch({ expr; NULL }, refus_provie = function(e) e)
motif_de <- function(expr) tryCatch({ expr; "aucun" }, refus_provie = function(e) e$motif,
                                    error = function(e) "autre")

# --- Base de référence ------------------------------------------------------------------

d <- dictionnaire()
D <- function(x) as.Date(x)
na_de <- function(type, n) switch(type, character = rep(NA_character_, n), integer = rep(NA_integer_, n),
  numeric = rep(NA_real_, n), logical = rep(NA, n), Date = as.Date(rep(NA_character_, n)))
# Table `table` de n lignes : colonnes du dictionnaire dans leur ordre, valeurs données, NA sinon.
tab <- function(table, ...) {
  v <- list(...)
  col <- d$colonnes[d$colonnes$table == table, , drop = FALSE]
  n <- if (length(v)) max(lengths(v)) else 0L
  df <- as.data.frame(lapply(seq_len(nrow(col)), function(i) {
    x <- v[[col$colonne[i]]]
    if (is.null(x)) na_de(col$type[i], n) else rep_len(x, n)
  }), stringsAsFactors = FALSE)
  names(df) <- col$colonne
  stopifnot(all(names(v) %in% col$colonne))
  df
}
base_ref <- list(
  extraction = tab("extraction", date_extraction = D("2026-12-31"), debut_historique = D("2017-01-01"),
                   type_organisme = "mutuelle", version_dictionnaire = "1.5", devise = "EUR"),
  adherents = tab("adherents", id_adherent = "AD1", secteur_activite = "S1", sante_couplee = TRUE),
  contrats = tab("contrats", id_contrat = c("CT1", "CT2"), nature_contrat = c("collectif_obligatoire", "individuel"),
                 id_adherent = c("AD1", NA), id_assure = c(NA, "AS2"), date_effet = D(c("2015-01-01", "2016-01-01")),
                 date_terme = D(c(NA, "2035-12-31")), mois_echeance = 1L, jour_echeance = 1L, preavis_mois = 2L,
                 tacite_reconduction = TRUE, gestionnaire = "interne", date_debut_gestion = D(c("2015-01-01", "2016-01-01"))),
  garanties_souscrites = tab("garanties_souscrites", id_garantie_souscrite = c("GS1", "GS2", "GS3", "GS4"),
                 id_contrat = c("CT1", "CT1", "CT1", "CT2"), code_garantie = c("deces", "incapacite", "rente_education", "deces"),
                 college = "ensemble", date_effet = D(c("2015-01-01", "2015-01-01", "2015-01-01", "2016-01-01")),
                 type_assiette = c("salaire_reference", "salaire_reference", "salaire_reference", "forfait"),
                 type_franchise = c(NA, "continue", NA, NA), regle_complement = c(NA, "forfaitaire", NA, NA),
                 option_iad = c(FALSE, NA, NA, FALSE),
                 periodicite_prestation = c(NA, "mensuelle", "trimestrielle", NA), terme_prestation = c(NA, "echu", "echu", NA),
                 periodicite_cotisation = "mensuelle", taux_technique_tarif = c(NA, NA, 0.01, 0.02),
                 prolongation_handicap = c(NA, NA, FALSE, NA),
                 clause_type_beneficiaire = c("conjoint_enfants_heritiers", NA, NA, "conjoint_enfants_heritiers")),
  parametres = tab("parametres", id_garantie_souscrite = c("GS1", "GS1", "GS2", "GS3", "GS3", "GS3", "GS4", "GS4"),
                 parametre = c("taux_capital", "age_fin_garantie", "franchise_jours", "taux_rente", "taux_rente",
                               "age_limite", "capital_forfaitaire", "age_fin_garantie"),
                 age_min = c(NA, NA, NA, 0L, 18L, NA, NA, NA), age_max = c(NA, NA, NA, 17L, 25L, NA, NA, NA),
                 valeur = c(2, 67, 90, 0.1, 0.15, 26, 50000, 70)),
  assures = tab("assures", id_assure = c("AS1", "AS2"), sexe = c("F", "M"), date_naissance = D(c("1970-05-10", "1960-01-01")),
                situation_familiale = c("marie", NA), date_situation_familiale = D(c("2015-01-05", NA))),
  affiliations = tab("affiliations", id_affiliation = "AF1", id_assure = "AS1", id_contrat = "CT1", college = "ensemble",
                     type_affiliation = "cotisant", date_debut = D("2015-01-01"), date_saisie = D("2015-01-05"),
                     salaire_reference = 30000, annee_salaire = 2024L, designation = "nominative",
                     date_designation = D("2016-01-01"), sante_organisme = TRUE, structure_cotisation_sante = "famille"),
  famille = tab("famille", id_membre = "ME1", id_assure = "AS1", lien = "enfant", sexe = "M",
                date_naissance = D("2010-03-01"), id_sinistre = "SI1", situation = "scolarise", date_saisie = D("2025-02-01")),
  sinistres = tab("sinistres", id_sinistre = c("SI1", "SI2"), id_assure = "AS1", nature_sinistre = c("deces", "arret_travail"),
                  date_survenance = D(c("2025-01-10", "2024-03-01")), date_declaration = D(c("2025-01-20", "2024-03-05")),
                  date_instruction = D(c("2025-02-01", NA)), canal_declaration = c("beneficiaire", "assure"),
                  gestionnaire = "interne", date_saisie = D(c("2025-01-21", "2024-03-06"))),
  dossiers = tab("dossiers", id_dossier = c("DO1", "DO2", "DO3"), id_sinistre = c("SI1", "SI1", "SI2"),
                 id_garantie_souscrite = c("GS1", "GS3", "GS2"), date_ouverture = D(c("2025-01-22", "2025-02-02", "2024-03-07"))),
  beneficiaires = tab("beneficiaires", id_beneficiaire = "BE1", id_dossier = "DO1", id_membre = "ME1",
                      qualite = "enfant_a_charge", part = 1, date_saisie = D("2025-02-02")),
  rentes = tab("rentes", id_rente = "RE1", id_dossier = "DO2", id_membre = "ME1", date_saisie = D("2025-02-02")),
  evenements = tab("evenements", id_evenement = paste0("EV", 1:6), id_sinistre = c("SI2", "SI2", "SI2", "SI1", "SI1", "SI1"),
                   id_dossier = c(NA, "DO3", NA, "DO1", "DO2", "DO2"), id_rente = c(NA, NA, NA, NA, "RE1", "RE1"),
                   type_evenement = c("entree_incapacite", "ouverture_service", "sortie", "fixation_capital",
                                      "ouverture_service", "fin_service"),
                   date_effet = D(c("2024-03-01", "2024-05-30", "2024-09-01", "2025-02-01", "2025-02-01", "2036-03-01")),
                   date_saisie = D(c("2024-03-06", "2024-06-01", "2024-09-03", "2025-02-02", "2025-02-03", "2025-02-03")),
                   montant = c(NA, 40, NA, 60000, 3000, NA), motif = c(NA, NA, "reprise_travail", NA, NA, "age_limite"),
                   justificatif = c(NA, NA, "certificat_medical", NA, NA, NA)),
  prestations = tab("prestations", id_prestation = c("PR1", "PR2", "PR3"), id_dossier = c("DO3", "DO1", "DO2"),
                    id_rente = c(NA, NA, "RE1"), type_prestation = c("indemnite_journaliere", "capital", "arrerage"),
                    nature_mouvement = "paiement", date_reglement = D(c("2024-07-01", "2025-03-01", "2025-04-01")),
                    debut_periode = D(c("2024-05-30", NA, "2025-01-01")), fin_periode = D(c("2024-06-30", NA, "2025-03-31")),
                    montant = c(1240, 60000, 750), date_saisie = D(c("2024-07-01", "2025-03-01", "2025-04-01"))),
  cotisations = tab("cotisations", id_cotisation = c("CO1", "CO2"), id_garantie_souscrite = "GS1",
                    nature_mouvement = c("emission", "encaissement"), debut_periode = D("2026-01-01"),
                    fin_periode = D("2026-12-31"), date_mouvement = D(c("2026-01-05", "2026-02-01")), montant = 1000),
  catastrophes = tab("catastrophes", id_catastrophe = "CA1", nature_catastrophe = "accident_collectif",
                     date_evenement = D("2026-06-01"), date_saisie = D("2026-06-02")),
  victimes = tab("victimes", id_victime = "VI1", id_catastrophe = "CA1", statut_victime = "blessee", date_saisie = D("2026-06-03")),
  evaluations_gestion = tab("evaluations_gestion", id_evaluation = "EG1", id_dossier = "DO3", montant_restant = 0,
                            date_effet = D("2024-09-01"), date_saisie = D("2024-09-05")),
  designations = tab("designations", id_designation = "DS1", id_affiliation = "AF1", rang = 1L, lien = "enfant",
                     date_naissance = D("2010-03-01"), quote_part = 1, date_saisie = D("2016-01-01")),
  ayants_droit_sante = tab("ayants_droit_sante", id_ayant_droit = "AY1", id_affiliation = "AF1", type = "enfant",
                           sexe = "M", date_naissance = D("2010-03-01"), debut_couverture = D("2015-01-01"),
                           date_saisie = D("2015-01-05"))
)
A <- as.Date("2026-12-31")
A0 <- as.Date("2025-06-30")
cb <- function(b, arrete = A, ...) controler_base(b, arrete, ...)
avec <- function(f) { b <- base_ref; f(b) }
# Lignes du bilan pour un code (et une table, une colonne) donnés.
ligne <- function(df, code, table = NULL, colonne = NULL, champ = "code") {
  i <- df[[champ]] == code
  if (!is.null(table)) i <- i & df$table == table
  if (!is.null(colonne)) i <- i & (if (is.na(colonne)) is.na(df$colonne) else df$colonne %in% colonne)
  df[i, , drop = FALSE]
}
refus <- function(r, code, table, colonne = NULL) ligne(r$refus_tables, code, table, colonne, "motif")
# Partition (ADR 0010, sixième série, (b) 3) : chaque ligne de controles est dans exactement
# un élément de traitement, ou dans declarations_requises.
# Une même clé (code, table, colonne) peut porter deux lignes de controles sous deux
# traitements (réserve m3) : chaque élément de traitement la porte alors une fois au plus, et
# le nombre de lignes de controles d'une clé égale le nombre de lignes de traitement.
partition <- function(r) {
  cle <- function(code, table, colonne) paste(code, table, colonne, sep = "|")
  c0 <- cle(r$controles$code, r$controles$table, r$controles$colonne)
  dans <- list(cle(r$refus_tables$motif, r$refus_tables$table, r$refus_tables$colonne),
               cle(r$signalements$code, r$signalements$table, r$signalements$colonne))
  !any(vapply(dans, anyDuplicated, 0L) > 0L) &&
    identical(sort(c0, method = "radix"), sort(unlist(dans), method = "radix"))
}
ni_present <- function(b) {
  ni <- ns$CONTROLES_NON_IMPLEMENTES
  ni[ni$table %in% names(b), , drop = FALSE]
}

section("donnees : exports et base de référence")
verifier("controler_base() est exportée", "controler_base" %in% getNamespaceExports("provie"))
verifier("les auxiliaires du module ne sont pas exportés",
         !any(grepl("^\\.", getNamespaceExports("provie"))))
verifier("la base de référence est conforme à controler_types()", identical(controler_types(base_ref), base_ref))
r0 <- cb(base_ref)
verifier_egal("éléments du bilan, dans l'ordre de l'ADR 0010 (point 9 et annotations)", names(r0),
              c("controles", "controles_non_executes", "refus_tables", "exclusions", "hypotheses_defaut",
                "signalements", "declarations_requises", "enjeu", "vue", "segments", "tables_absentes"))
verifier_egal("colonnes de controles", names(r0$controles),
              c("code", "table", "colonne", "detection", "nombre", "identifiants"))
verifier_egal("colonnes de controles_non_executes", names(r0$controles_non_executes),
              c("code", "table", "colonne", "cause"))
verifier_egal("colonnes de refus_tables (portée, origine, nombre_visibles ; aucun enjeu_montant)",
              names(r0$refus_tables), c("table", "colonne", "motif", "portee", "origine", "nombre",
                                        "nombre_visibles", "identifiants", "nombre_dossiers", "postes_arretes"))
verifier_egal("colonnes de signalements", names(r0$signalements),
              c("code", "table", "colonne", "detection", "nombre", "identifiants"))
verifier_egal("colonnes de declarations_requises", names(r0$declarations_requises),
              c("rubrique", "motif", "cle", "traitements_admis", "nombre_lignes"))
verifier_egal("colonnes de enjeu (table longue, M152)", names(r0$enjeu),
              c("table", "colonne", "motif", "famille", "action", "garantie", "poste", "composante", "unite",
                "montant", "nombre_dossiers", "nombre_valeurs", "cause"))
verifier("base de référence : aucun constat ; seuls les contrôles non implémentés sont non exécutés ; aucune table absente",
         nrow(r0$controles) == 0L && nrow(r0$refus_tables) == 0L && length(r0$tables_absentes) == 0L &&
           all(r0$controles_non_executes$cause == "non_implemente") &&
           nrow(r0$controles_non_executes) == nrow(ni_present(base_ref)))
verifier_egal("état partiel porté par l'objet : chaque contrôle non implémenté est une ligne non exécutée",
              r0$controles_non_executes[, c("code", "table", "colonne")],
              ns$.trier(ni_present(base_ref), d))
# Couverture : aucun code de controles.csv ni défaut du § 9 n'est absent à la fois des
# contrôles écrits (chaînes des règles du module, plus les codes de constater_forme()) et de
# CONTROLES_NON_IMPLEMENTES ; un sous-cas (D10a) couvre son défaut (D10).
ecrits <- unique(unlist(lapply(c(".regle_forme", ".regle_domaine", ".regle_date_programmable", ".regles_propres",
                                 ".regle_signe", ".regle_cles", ".refus_induits"), function(f) {
  txt <- paste(deparse(get(f, envir = ns)), collapse = " ")
  regmatches(txt, gregexpr("\"(D[0-9]{2}[a-z]?|[a-z_]+)\"", txt))[[1L]]
})))
ecrits <- c(gsub("\"", "", ecrits), "colonne_absente", "colonne_inconnue", "type_incompatible")
couverts <- c(ecrits, ns$CONTROLES_NON_IMPLEMENTES$code)
couvert <- function(code) code %in% couverts || any(startsWith(couverts, code) & grepl("^D[0-9]{2}[a-z]$", couverts))
verifier("couverture : chaque code de controles.csv est écrit ou déclaré non implémenté",
         all(vapply(d$controles$code, couvert, NA)))
verifier("couverture : chaque défaut du § 9 (defauts.csv) est écrit ou déclaré non implémenté",
         all(vapply(d$defauts$code, couvert, NA)))
verifier("CONTROLES_NON_IMPLEMENTES : codes connus, tables et colonnes du dictionnaire, sans doublon",
         {
           ni <- ns$CONTROLES_NON_IMPLEMENTES
           all(ni$code %in% d$controles$code | sub("[a-z]$", "", ni$code) %in% d$defauts$code | ni$code %in% d$defauts$code) &&
             all(ni$table %in% d$tables$table) &&
             all(is.na(ni$colonne) | paste(ni$table, ni$colonne) %in% paste(d$colonnes$table, d$colonnes$colonne)) &&
             !anyDuplicated(ni)
         })
verifier("D04a et D04b traités X, D02c (âge), D07, somme_parts : déclarés non implémentés",
         all(c("D04a", "D04b", "D02c", "D07", "somme_parts", "D02b", "D03g") %in% r0$controles_non_executes$code))
r <- cb(base_ref, conventions = NULL)
verifier("sans conventions : D02c (âge) et D07 portent non_implemente, qui prime sur declaration_absente",
         all(ligne(r$controles_non_executes, "D02c", "assures", NA)$cause == "non_implemente") &&
           all(ligne(r$controles_non_executes, "D07", "evenements", NA)$cause == "non_implemente"))
r <- cb(avec(function(b) { b$prestations$id_dossier[1L] <- "DOX"; b$evenements$id_sinistre[1L] <- "SIX"; b }))
verifier("orpheline traitée X (D04a, D04b) : aucun constat, mais la ligne non exécutée non_implemente le dit",
         nrow(r$controles) == 0L &&
           ligne(r$controles_non_executes, "D04a", "prestations", "id_dossier")$cause == "non_implemente" &&
           ligne(r$controles_non_executes, "D04b", "evenements", "id_sinistre")$cause == "non_implemente")
verifier_egal("vue : date d'arrêté et date d'extraction", r0$vue[c("date_arrete", "date_extraction")],
              list(date_arrete = A, date_extraction = A))
verifier("la base n'est pas modifiée (aucune correction silencieuse)", {
  b <- base_ref; b$prestations$montant[1L] <- -5; avant <- b; cb(b); identical(b, avant)
})

section("donnees : refus d'appel (M143, M147, M153)")
verifier_egal("arrete absent : plan_incomplet", motif_de(controler_base(base_ref)), "plan_incomplet")
for (cas in list(list("chaîne", "2026-12-31"), list("deux dates", as.Date(c("2026-12-31", "2026-12-30"))),
                 list("NA", as.Date(NA)), list("Date stockée en entier", structure(20818L, class = "Date")),
                 list("POSIXct", as.POSIXct("2026-12-31", tz = "UTC")))) {
  verifier_egal(paste0("arrete mal formé (", cas[[1L]], ") : plan_invalide"), motif_de(cb(base_ref, cas[[2L]])), "plan_invalide")
}
verifier_egal("arrete postérieur à l'extraction : arrete_posterieur_extraction",
              motif_de(cb(base_ref, as.Date("2027-01-01"))), "arrete_posterieur_extraction")
verifier_egal("arrete égal à l'extraction : admis", motif_de(cb(base_ref, A)), "aucun")
verifier_egal("donnees qui n'est pas une liste : liste_invalide", motif_de(cb(base_ref$contrats)), "liste_invalide")
verifier_egal("tables sans nom : liste_invalide", motif_de(cb(unname(base_ref))), "liste_invalide")
verifier_egal("table inconnue : liste_invalide", motif_de(cb(c(base_ref, list(sinistre = base_ref$sinistres)))),
              "liste_invalide")
verifier_egal("table qui n'est pas un data.frame : liste_invalide",
              motif_de(cb(avec(function(b) { b$adherents <- as.list(b$adherents); b }))), "liste_invalide")
verifier_egal("noms de colonnes en double : liste_invalide",
              motif_de(cb(avec(function(b) { names(b$adherents)[2L] <- "id_adherent"; b }))), "liste_invalide")
e <- refus_de(cb(avec(function(b) { b$dossiers <- NULL; b })))
verifier("table obligatoire absente : table_base_absente, table nommée",
         !is.null(e) && e$motif == "table_base_absente" && e$table == "dossiers")
verifier_egal("extraction absente : table_base_absente", motif_de(cb(avec(function(b) { b$extraction <- NULL; b }))),
              "table_base_absente")
alt_ext <- function(f) cb(avec(function(b) { b$extraction <- f(b$extraction); b }))
verifier_egal("extraction d'une autre version : extraction_invalide",
              motif_de(alt_ext(function(x) { x$version_dictionnaire <- "1.4"; x })), "extraction_invalide")
verifier_egal("extraction de deux lignes : extraction_invalide", motif_de(alt_ext(function(x) rbind(x, x))),
              "extraction_invalide")
verifier_egal("extraction, colonne inconnue : colonne_inconnue", motif_de(alt_ext(function(x) { x$autre <- 1; x })),
              "colonne_inconnue")
verifier_egal("extraction, colonne absente : colonne_absente", motif_de(alt_ext(function(x) { x$devise <- NULL; x })),
              "colonne_absente")
verifier_egal("extraction, type incompatible : type_incompatible",
              motif_de(alt_ext(function(x) { x$date_extraction <- "2026-12-31"; x })), "type_incompatible")
verifier_egal("extraction, devise hors domaine : extraction_invalide",
              motif_de(alt_ext(function(x) { x$devise <- "USD"; x })), "extraction_invalide")
verifier_egal("extraction, date manquante : extraction_invalide",
              motif_de(alt_ext(function(x) { x$debut_historique <- as.Date(NA); x })), "extraction_invalide")
verifier_egal("extraction, début d'historique après l'extraction : extraction_invalide",
              motif_de(alt_ext(function(x) { x$debut_historique <- as.Date("2027-01-01"); x })), "extraction_invalide")
for (cas in list(list("age hors liste", list(age = "exact")), list("entrée inconnue", list(ages = "revolu")),
                 list("limite_age sans age", list(limite_age = list(regle = "atteinte"))),
                 list("limite_age$regle hors liste", list(limite_age = list(regle = "avant", age = "revolu"))),
                 list("limite_age$age naissance_31_decembre (M154)",
                      list(limite_age = list(regle = "atteinte", age = "naissance_31_decembre"))),
                 list("limite_age$age plus_proche", list(limite_age = list(regle = "depassement", age = "plus_proche"))),
                 list("non nommée", list("revolu")), list("chaîne", "revolu"))) {
  verifier_egal(paste0("conventions : ", cas[[1L]], " : plan_invalide"),
                motif_de(cb(base_ref, conventions = cas[[2L]])), "plan_invalide")
}
for (convention in c("revolu", "millesime", "plus_proche", "naissance_31_decembre")) {
  verifier_egal(paste0("conventions$age = ", convention, " : admise"),
                motif_de(cb(base_ref, conventions = list(age = convention))), "aucun")
}
verifier_egal("conventions$limite_age (depassement, millesime) : admise",
              motif_de(cb(base_ref, conventions = list(limite_age = list(regle = "depassement", age = "millesime")))),
              "aucun")
verifier_egal("declarations, rubrique inconnue : plan_invalide",
              motif_de(cb(base_ref, declarations = list(exclusion = list()))), "plan_invalide")

section("donnees : règle B, forme (constater_forme(), M143)")
r <- cb(avec(function(b) { b$adherents$autre <- 1; b }))
x <- refus(r, "colonne_inconnue", "adherents", "autre")
verifier("colonne inconnue : refus de la table (portée table, colonne d'origine nommée), toutes les lignes",
         nrow(x) == 1L && x$portee == "table" && x$nombre == 1L && x$identifiants == "AD1")
verifier("colonne inconnue d'adherents : refus induit de contrats, origine adherents",
         nrow(refus(r, "refus_induit", "contrats", NA)) == 1L && refus(r, "refus_induit", "contrats", NA)$origine == "adherents")
r <- cb(avec(function(b) { b$contrats$gestionnaire <- NULL; b }))
verifier("colonne O absente : colonne_absente, portée table",
         nrow(refus(r, "colonne_absente", "contrats", "gestionnaire")) == 1L &&
           refus(r, "colonne_absente", "contrats", "gestionnaire")$portee == "table")
verifier_egal("colonne F absente : sans effet", nrow(cb(avec(function(b) { b$contrats$date_fin <- NULL; b }))$controles), 0L)
r <- cb(avec(function(b) { b$sinistres$date_survenance <- as.character(b$sinistres$date_survenance); b }))
x <- refus(r, "type_incompatible", "sinistres", "date_survenance")
verifier("type incompatible sur une colonne ordinaire : portée colonne, aucun refus induit",
         nrow(x) == 1L && x$portee == "colonne" && x$nombre == 2L && !any(r$refus_tables$motif == "refus_induit"))
nx <- r$controles_non_executes[r$controles_non_executes$table == "sinistres", ]
verifier("contrôles d'une colonne refusée pour son type : non exécutés, cause type_incompatible (D02c, manquant)",
         all(c("D02c", "manquant_obligatoire") %in%
               nx$code[nx$colonne %in% "date_survenance" & nx$cause == "type_incompatible"]) &&
           all(nx$cause %in% c("type_incompatible", "non_implemente")))
verifier("un contrôle non exécuté n'est pas dans controles",
         !any(r$controles$code == "D02c" & r$controles$table == "sinistres"))
r <- cb(avec(function(b) { b$sinistres$id_sinistre <- factor(b$sinistres$id_sinistre); b }))
verifier("type incompatible sur une clé primaire : portée table et refus induits (dossiers, evenements, famille, victimes)",
         refus(r, "type_incompatible", "sinistres", "id_sinistre")$portee == "table" &&
           all(c("famille", "dossiers", "evenements", "victimes") %in% refus(r, "refus_induit", NULL)$table))
verifier("clé étrangère vers une clé mal typée : D04b non exécuté, cause type_incompatible",
         nrow(ligne(r$controles_non_executes, "D04b", "dossiers", "id_sinistre")) == 1L &&
           ligne(r$controles_non_executes, "D04b", "dossiers", "id_sinistre")$cause == "type_incompatible")
r <- cb(avec(function(b) { b$prestations$date_reglement <- structure(as.integer(b$prestations$date_reglement), class = "Date"); b }))
verifier("Date stockée en entier : type_incompatible", nrow(refus(r, "type_incompatible", "prestations", "date_reglement")) == 1L)
r <- cb(avec(function(b) { b$evaluations_gestion$montant_restant <- "0"; b }))
verifier("anomalie de T18 seule : bilan complet, refus de la table seule, aucun refus induit (dictionnaire, § 7.5)",
         nrow(r$refus_tables) == 1L && r$refus_tables$table == "evaluations_gestion" && r$refus_tables$portee == "table")
r <- cb(avec(function(b) { b$cotisations$montant <- as.character(b$cotisations$montant)
                           b$parametres$valeur <- as.integer(b$parametres$valeur); b }))
verifier("deux tables mal typées : toutes deux au bilan",
         all(c("parametres", "cotisations") %in% refus(r, "type_incompatible", NULL)$table))
r <- cb(avec(function(b) { b$victimes <- NULL; b }))
x <- refus(r, "table_conditionnelle_absente", "catastrophes", NA)
verifier("victimes absente, catastrophes présente : refus R de catastrophes, colonne NA ; victimes hors de tables_absentes",
         nrow(x) == 1L && x$portee == "table" && x$nombre == 1L && !("victimes" %in% r$tables_absentes))
r <- cb(avec(function(b) { b[c("catastrophes", "victimes", "evaluations_gestion", "designations", "ayants_droit_sante")] <- NULL; b }))
verifier_egal("tables facultatives absentes : tables_absentes, aucun refus", r$tables_absentes,
              c("catastrophes", "victimes", "evaluations_gestion", "designations", "ayants_droit_sante"))
verifier("tables facultatives absentes : aucun constat", nrow(r$controles) == 0L)

section("donnees : règle B, domaine")
r <- cb(avec(function(b) { b$assures$sexe[2L] <- ""; b$adherents$id_adherent <- ""; b$contrats$id_adherent[1L] <- ""; b }))
verifier("chaîne vide dans une colonne character : chaine_vide, portée colonne, pas hors_domaine",
         refus(r, "chaine_vide", "assures", "sexe")$portee == "colonne" && nrow(refus(r, "hors_domaine", "assures", "sexe")) == 0L)
verifier("chaîne vide dans une clé : portée table", refus(r, "chaine_vide", "adherents", "id_adherent")$portee == "table")
r <- cb(avec(function(b) { b$contrats$id_adherent[1L] <- ""; b }))
verifier("chaîne vide seule dans une clé étrangère : chaine_vide seul, pas D04b (réserve m1)",
         nrow(refus(r, "chaine_vide", "contrats", "id_adherent")) == 1L && nrow(refus(r, "D04b", "contrats")) == 0L &&
           !any(r$controles$code == "D04b"))
r <- cb(avec(function(b) { b$sinistres$canal_declaration[1L] <- "courriel"; b$contrats$gestionnaire[2L] <- NA; b }))
verifier("modalité hors liste : hors_domaine, portée colonne",
         refus(r, "hors_domaine", "sinistres", "canal_declaration")$identifiants == "SI1")
verifier("manquant dans une colonne O sans défaut au § 9 : manquant_obligatoire",
         refus(r, "manquant_obligatoire", "contrats", "gestionnaire")$identifiants == "CT2")
r <- cb(avec(function(b) { b$assures$sexe[1L] <- NA; b$assures$date_naissance[1L] <- NA; b$affiliations$salaire_reference <- NA
                           b$sinistres$date_saisie[1L] <- NA; b }))
verifier("manquant qui a un défaut au § 9 (D03a, D03b, D03c, D03g) : pas manquant_obligatoire",
         !any(r$controles$code == "manquant_obligatoire"))
r <- cb(avec(function(b) { b$adherents$id_adherent <- NA_character_; b }))
verifier("manquant dans une clé primaire : manquant_obligatoire, portée table",
         refus(r, "manquant_obligatoire", "adherents", "id_adherent")$portee == "table")
r <- cb(avec(function(b) { b$prestations$montant[2L] <- NaN; b$cotisations$montant[1L] <- Inf; b }))
verifier("réel non fini (NaN, Inf) : hors_domaine, NaN n'est pas un manquant",
         nrow(refus(r, "hors_domaine", "prestations", "montant")) == 1L && nrow(refus(r, "hors_domaine", "cotisations", "montant")) == 1L &&
           !any(r$controles$code == "manquant_obligatoire"))
r <- cb(avec(function(b) { b$contrats$id_adherent[2L] <- "AD1"; b$contrats$motif_fin[1L] <- "terme"; b }))
verifier("colonne C présente hors condition : hors_domaine (portée table pour une clé étrangère)",
         refus(r, "hors_domaine", "contrats", "id_adherent")$portee == "table" &&
           nrow(refus(r, "hors_domaine", "contrats", "motif_fin")) == 1L)
r <- cb(avec(function(b) { b$contrats$date_fin[1L] <- as.Date("2026-06-30"); b }))
verifier("colonne C manquante sous sa condition : manquant_obligatoire (motif_fin) ; date_saisie_fin manquante : D03g, pas un refus",
         nrow(refus(r, "manquant_obligatoire", "contrats", "motif_fin")) == 1L &&
           nrow(ligne(r$controles, "manquant_obligatoire", "contrats", "date_saisie_fin")) == 0L)
r <- cb(avec(function(b) { b$garanties_souscrites$type_franchise[1L] <- "continue"; b$garanties_souscrites$option_iad[1L] <- NA
                           b$garanties_souscrites$taux_technique_tarif[2L] <- 0.01; b$garanties_souscrites$taux_technique_tarif[3L] <- 0.2; b }))
verifier("garanties_souscrites : colonne d'une autre garantie, colonne requise manquante, taux hors bornes",
         nrow(refus(r, "hors_domaine", "garanties_souscrites", "type_franchise")) == 1L &&
           nrow(refus(r, "manquant_obligatoire", "garanties_souscrites", "option_iad")) == 1L &&
           refus(r, "hors_domaine", "garanties_souscrites", "taux_technique_tarif")$nombre == 2L)
r <- cb(avec(function(b) { b$garanties_souscrites$taux_technique_tarif[3L] <- NA; b }))
verifier("taux du tarif manquant là où il est requis : D03h (règle V), pas un refus", nrow(r$refus_tables) == 0L)
r <- cb(avec(function(b) { b$parametres$parametre[3L] <- "taux_capital"; b$parametres$age_max[4L] <- NA
                           b$parametres$categorie_invalidite[1L] <- "cat1"; b$parametres$valeur[2L] <- 67.5; b }))
verifier("parametres : paramètre d'une autre garantie, age_max manquant, catégorie hors dimension, âge non entier",
         nrow(refus(r, "hors_domaine", "parametres", "parametre")) == 1L &&
           nrow(refus(r, "manquant_obligatoire", "parametres", "age_max")) == 1L &&
           nrow(refus(r, "hors_domaine", "parametres", "categorie_invalidite")) == 1L &&
           nrow(refus(r, "hors_domaine", "parametres", "valeur")) == 1L)
r <- cb(avec(function(b) { b$contrats$mois_echeance[1L] <- 13L; b$contrats$mois_echeance[2L] <- 2L
                           b$contrats$jour_echeance[2L] <- 30L; b$assures$nombre_enfants_charge[2L] <- 3L; b }))
verifier("bornes écrites dans le domaine (mois, jour valide avec le mois) ; condition (date_situation_familiale)",
         nrow(refus(r, "hors_domaine", "contrats", "mois_echeance")) == 1L &&
           refus(r, "hors_domaine", "contrats", "jour_echeance")$identifiants == "CT2" &&
           nrow(refus(r, "manquant_obligatoire", "assures", "date_situation_familiale")) == 1L)
r <- cb(avec(function(b) { b$famille$situation <- "a_naitre"; b$evenements$montant[1L] <- 10; b$evenements$motif[2L] <- "age_limite"
                           b$evenements$motif[3L] <- "fin_etudes"; b$prestations$debut_periode[2L] <- as.Date("2025-01-01"); b }))
verifier("naissance renseignée d'un enfant à naître ; montant hors type ; motif hors du type ; période d'un capital",
         nrow(refus(r, "hors_domaine", "famille", "date_naissance")) == 1L &&
           nrow(refus(r, "hors_domaine", "evenements", "montant")) == 1L &&
           refus(r, "hors_domaine", "evenements", "motif")$identifiants == "EV2;EV3" &&
           nrow(refus(r, "hors_domaine", "prestations", "debut_periode")) == 1L)
r <- cb(avec(function(b) { b$evenements$motif[6L] <- NA; b }))
verifier("motif manquant d'un fin_service : manquant_obligatoire", nrow(refus(r, "manquant_obligatoire", "evenements", "motif")) == 1L)
r <- cb(avec(function(b) { b$evenements$motif[3L] <- NA; b }))
verifier("motif manquant d'une sortie, prestation sur un dossier du sinistre : manquant_obligatoire",
         nrow(refus(r, "manquant_obligatoire", "evenements", "motif")) == 1L)
r <- cb(avec(function(b) { b$evenements$motif[3L] <- NA; b$prestations <- b$prestations[-1L, ]; b$evaluations_gestion <- NULL; b }))
verifier("motif manquant d'une sortie sans prestation du sinistre : D05 (règle V), pas un refus",
         nrow(refus(r, "manquant_obligatoire", "evenements", "motif")) == 0L)
r <- cb(avec(function(b) { b$evenements$id_dossier[1L] <- "DO3"; b$evenements$id_rente[2L] <- "RE1"; b$evenements$id_dossier[4L] <- NA
                           b$evenements$type_evenement[5L] <- "fixation_capital"; b }))
verifier("evenements : dossier d'un événement de niveau sinistre ; rente d'un dossier incapacité ; dossier requis ; type d'une autre garantie",
         nrow(refus(r, "hors_domaine", "evenements", "id_dossier")) == 1L &&
           nrow(refus(r, "hors_domaine", "evenements", "id_rente")) == 1L &&
           nrow(refus(r, "manquant_obligatoire", "evenements", "id_dossier")) == 1L &&
           refus(r, "hors_domaine", "evenements", "type_evenement")$identifiants == "EV5")

section("donnees : règle B, D02c (date hors domaine) et D09 (signe)")
r <- cb(avec(function(b) { b$assures$date_naissance[1L] <- as.Date("1900-01-01"); b$cotisations$date_mouvement[1L] <- as.Date("2027-01-01")
                           b$contrats$date_fin[1L] <- as.Date("2030-12-31"); b$contrats$motif_fin[1L] <- "terme"
                           b$contrats$date_saisie_fin[1L] <- as.Date("2026-10-01"); b }))
verifier("date antérieure à 1901 et date future hors futur admis : D02c, portée colonne ; futur admis accepté",
         refus(r, "D02c", "assures", "date_naissance")$portee == "colonne" &&
           nrow(refus(r, "D02c", "cotisations", "date_mouvement")) == 1L && nrow(refus(r, "D02c", "contrats")) == 0L)
r <- cb(avec(function(b) { b$contrats$date_fin[1L] <- as.Date("9999-12-31"); b$contrats$motif_fin[1L] <- "terme"
                           b$contrats$date_saisie_fin[1L] <- as.Date("2026-10-01"); b }))
verifier("sentinelle 9999-12-31 dans une colonne future admise : hors_domaine",
         nrow(refus(r, "hors_domaine", "contrats", "date_fin")) == 1L)
r <- cb(avec(function(b) { b$evenements$date_effet[5L] <- as.Date("2027-02-01"); b$evenements$motif[6L] <- "deces_beneficiaire"; b }))
verifier("date d'effet future : D02c pour un type non programmable et pour un motif non programmable",
         refus(r, "D02c", "evenements", "date_effet")$identifiants == "EV5;EV6")
r <- cb(avec(function(b) { b$famille$date_saisie <- as.Date("2027-01-01"); b }))
verifier("D02c sur une colonne de la clé primaire (famille.date_saisie) : portée table",
         refus(r, "D02c", "famille", "date_saisie")$portee == "table")
r <- cb(avec(function(b) { b$prestations$montant[1L] <- -5; b$cotisations$montant[1L] <- -1000; b$cotisations$montant[2L] <- 0
                           b$affiliations$salaire_reference <- -1; b$parametres$valeur[1L] <- -2; b$evenements$montant[2L] <- -40; b }))
verifier("signe contraire au domaine : D09, portée colonne (M145), sur les cinq colonnes du § 9",
         all(c("prestations", "cotisations", "affiliations", "parametres", "evenements") %in% refus(r, "D09", NULL)$table) &&
           all(refus(r, "D09", NULL)$portee == "colonne"))
verifier("zéro là où le domaine exige un montant non nul : hors_domaine, pas D09",
         refus(r, "hors_domaine", "cotisations", "montant")$identifiants == "CO2" && refus(r, "D09", "cotisations")$identifiants == "CO1")

section("donnees : règle B, clés (D01a, D04, D10 (a) et (h), chevauchement), refus induits")
r <- cb(avec(function(b) { b$sinistres <- rbind(b$sinistres, b$sinistres[1L, ]); b }))
x <- refus(r, "D01a", "sinistres")
verifier("doublon de clé primaire : D01a, portée table, une ligne en trop comptée, identifiant", nrow(x) == 1L &&
           x$portee == "table" && x$nombre == 1L && x$identifiants == "SI1" && x$colonne == "id_sinistre")
x <- refus(r, "refus_induit", NULL)
verifier_egal("refus induits de proche en proche, dans l'ordre du dictionnaire", x$table,
              c("famille", "dossiers", "beneficiaires", "rentes", "evenements", "prestations", "victimes", "evaluations_gestion"))
verifier_egal("origine d'un refus induit : tables visées refusées, ordre du dictionnaire",
              x$origine[x$table == "evenements"], "sinistres;dossiers;rentes")
verifier("refus induit : colonne NA, toutes les lignes", all(is.na(x$colonne)) && x$nombre[x$table == "evenements"] == 6L)
r <- cb(avec(function(b) { b$famille <- rbind(b$famille, b$famille); b$parametres <- rbind(b$parametres, b$parametres[1L, ]); b }))
verifier("clé composite : doublon détecté, un manquant comptant comme une valeur (parametres)",
         refus(r, "D01a", "famille")$identifiants == "ME1|2025-02-01" &&
           refus(r, "D01a", "parametres")$identifiants == "GS1|taux_capital|\\N|NA")
r <- cb(avec(function(b) { b$famille$id_assure <- "AS9"; b }))
verifier("clé étrangère orpheline d'une table R (famille) : D04b, portée table ; refus induits de beneficiaires et rentes",
         refus(r, "D04b", "famille", "id_assure")$portee == "table" &&
           all(c("beneficiaires", "rentes") %in% refus(r, "refus_induit", NULL)$table))
r <- cb(avec(function(b) { b$affiliations$college <- "cadres"; b }))
verifier("référence composite : collège qui n'existe pas sous le contrat : D04b de affiliations",
         nrow(refus(r, "D04b", "affiliations", "college")) == 1L)
r <- cb(avec(function(b) { b$garanties_souscrites <- rbind(b$garanties_souscrites, transform(b$garanties_souscrites[2L, ],
                  id_garantie_souscrite = "GS5", college = "cadres")); b$affiliations$college <- "cadres"; b$affiliations$id_contrat <- "CT1"; b }))
verifier("référence composite satisfaite : collège existant sous le même contrat, aucun D04b",
         nrow(refus(r, "D04b", "affiliations")) == 0L)
r <- cb(avec(function(b) { b$dossiers$id_garantie_souscrite[3L] <- "GS1"; b$rentes$id_dossier <- "DO1"
                           b$prestations$type_prestation[2L] <- "arrerage"; b$prestations$id_rente[2L] <- "RE1"; b }))
verifier("D10 (a) : garantie incompatible avec la nature, rente d'un dossier non rente, type de prestation : portée table",
         nrow(refus(r, "D10a", "dossiers")) == 1L && nrow(refus(r, "D10a", "rentes")) == 1L &&
           nrow(refus(r, "D10a", "prestations")) >= 1L && all(refus(r, "D10a", NULL)$portee == "table"))
r <- cb(avec(function(b) { b$victimes$id_assure <- "AS2"; b$victimes$id_sinistre <- "SI1"; b }))
verifier("D10 (h) : victime dont le sinistre est d'un autre assuré : refus R de victimes",
         refus(r, "D10h", "victimes", "id_sinistre")$portee == "table")
r <- cb(avec(function(b) { b$garanties_souscrites <- rbind(b$garanties_souscrites, transform(b$garanties_souscrites[1L, ],
                  id_garantie_souscrite = "GS6", date_effet = as.Date("2020-01-01"))); b }))
verifier("versions d'une même garantie et d'un même collège qui se chevauchent : chevauchement, colonne NA, portée table",
         refus(r, "chevauchement", "garanties_souscrites", NA)$identifiants == "GS1;GS6")
r <- cb(avec(function(b) { b$garanties_souscrites <- rbind(b$garanties_souscrites, transform(b$garanties_souscrites[1L, ],
                  id_garantie_souscrite = "GS6", date_effet = as.Date("2020-01-01")))
                  b$garanties_souscrites$date_fin[1L] <- as.Date("2019-12-31"); b }))
verifier("versions successives sans recouvrement : aucun chevauchement", nrow(refus(r, "chevauchement", NULL)) == 0L)
r <- cb(avec(function(b) { b$parametres$age_min[5L] <- 17L; b }))
verifier("paliers d'un même paramètre qui se chevauchent : chevauchement de parametres", refus(r, "chevauchement", "parametres")$nombre == 2L)

section("donnees : traitement des codes de contrôle, portée effective, partition, tri, invariance")
verifier("règle provisoire : un code de portée ligne est un signalement (S), tout autre un refus (R)",
         all(vapply(d$controles$code, function(k) ns$.traitement_code_controle(d, k), "") ==
               ifelse(d$controles$portee == "ligne", "S", "R")))
verifier("aucun code de portée ligne ne porte de motif de refus d'appel",
         all(d$controles$motif_refus_appel[d$controles$portee == "ligne"] == ""))
verifier_egal("portée effective : colonne_table résolue (colonne ordinaire, clé primaire, référence), D10a, T18",
              c(ns$.portee_effective(d, "hors_domaine", "sinistres", "canal_declaration"),
                ns$.portee_effective(d, "hors_domaine", "sinistres", "id_sinistre"),
                ns$.portee_effective(d, "hors_domaine", "dossiers", "id_sinistre"),
                ns$.portee_effective(d, "D09", "prestations", "montant"),
                ns$.portee_effective(d, "D10a", "prestations", "type_prestation"),
                ns$.portee_effective(d, "hors_domaine", "evaluations_gestion", "montant_restant"),
                ns$.portee_effective(d, "colonne_absente", "contrats", "gestionnaire")),
              c("colonne", "table", "table", "colonne", "table", "table", "table"))
multi <- avec(function(b) {
  b$sinistres <- rbind(b$sinistres, b$sinistres[1L, ]); b$assures$sexe[2L] <- ""; b$prestations$montant[1L] <- -5
  b$contrats$date_effet <- as.character(b$contrats$date_effet); b$affiliations$college <- "autre"
  b$parametres$age_min[5L] <- 17L; b$evenements$date_effet[1L] <- as.Date("2027-05-01"); b$victimes <- NULL; b })
r <- cb(multi)
verifier("partition : chaque ligne de controles est dans exactement un élément de traitement", partition(r))
verifier("aucun code de portée ligne dans refus_tables ; portée effective colonne ou table seulement",
         !any(r$refus_tables$motif %in% d$controles$code[d$controles$portee == "ligne"]) &&
           all(r$refus_tables$portee %in% c("colonne", "table")))
verifier("controles_non_executes : causes parmi les codes de refus et declaration_absente",
         all(r$controles_non_executes$cause %in% c(d$controles$code, d$defauts$code, "declaration_absente",
                                                   "non_implemente")))
verifier("controler_base() ne rend aucun poste arrêté (B2) ni nombre de visibles en règle B seule (NA)",
         all(is.na(r$refus_tables$postes_arretes)))
melange <- lapply(multi, function(t) if (nrow(t) > 1L) t[rev(seq_len(nrow(t))), rev(names(t)), drop = FALSE] else t)
verifier_egal("tri reproductible : bilan identique, lignes et colonnes des tables dans un autre ordre", cb(melange), r)
verifier_egal("tri : ordre des tables du dictionnaire, colonnes, code",
              unique(r$controles$table), d$tables$table[d$tables$table %in% r$controles$table])
r_a0 <- cb(multi, A0)
verifier_egal("invariance en A (règle B) : controles identiques à deux arrêtés", r_a0$controles, r$controles)
verifier_egal("invariance en A (règle B) : refus_tables (hors nombre_visibles) identiques",
              r_a0$refus_tables[, names(r$refus_tables) != "nombre_visibles"],
              r$refus_tables[, names(r$refus_tables) != "nombre_visibles"])
verifier_egal("vue : date d'arrêté consignée", r_a0$vue$date_arrete, A0)

section("donnees : même bilan par lire_base() d'un CSV et par le data.frame (M144, M150)")
b <- avec(function(b) { b$sinistres$canal_declaration[1L] <- "courriel"; b$prestations$montant[1L] <- -5; b })
dossier <- tempfile("base-")
ecrire_base(b, dossier)
verifier_egal("bilan identique par le CSV et par le data.frame", cb(lire_base(dossier)), cb(b))
texte <- readLines(file.path(dossier, "assures.csv"), encoding = "UTF-8")
texte[3L] <- sub("^\"AS2\",\"M\"", "\"AS2\",\"\"", texte[3L])
writeLines(texte, file.path(dossier, "assures.csv"))
r <- cb(lire_base(dossier))
verifier("\"\" d'un CSV dans une colonne character : chaine_vide au bilan, sans interruption",
         refus(r, "chaine_vide", "assures", "sexe")$identifiants == "AS2")

section("donnees : reprise de l'audit (m2, m3, identifiants)")
r <- cb(avec(function(b) { b$dossiers$id_sinistre <- factor(b$dossiers$id_sinistre); b$evenements$id_dossier[1L] <- "DO3"; b }))
verifier("m2 : une clé détectée par une règle et non exécutée par une autre n'est que dans controles",
         nrow(ligne(r$controles, "hors_domaine", "evenements", "id_dossier")) == 1L &&
           nrow(ligne(r$controles_non_executes, "hors_domaine", "evenements", "id_dossier")) == 0L)
r <- cb(avec(function(b) { b$dossiers$id_sinistre <- factor(b$dossiers$id_sinistre); b }))
verifier("m2 : sans détection, la règle non exécutée reste dans controles_non_executes (pas de zéro rassurant)",
         nrow(ligne(r$controles_non_executes, "hors_domaine", "evenements", "id_dossier")) == 1L &&
           nrow(ligne(r$controles, "hors_domaine", "evenements", "id_dossier")) == 0L)
r <- cb(avec(function(b) { b$dossiers$id_sinistre <- factor(b$dossiers$id_sinistre); b$prestations$montant[1L] <- -5; b }))
verifier("m2 : aucune clé à la fois dans controles et dans controles_non_executes",
         !any(paste(r$controles$code, r$controles$table, r$controles$colonne) %in%
                paste(r$controles_non_executes$code, r$controles_non_executes$table, r$controles_non_executes$colonne)))
b <- base_ref; b$assures$date_naissance[2L] <- as.Date("1900-06-01")
ctx <- ns$.contexte(b, d, list(date_extraction = A), A)
ns$.ajouter_constat(ctx, "D02c", "assures", "date_naissance", 2L, "R", "exacte")
ns$.ajouter_constat(ctx, "D02c", "assures", "date_naissance", 1L, "S", "exacte")
r <- ns$.bilan(ctx)
verifier("m3 : même code et même colonne sous deux traitements : deux lignes, un refus R et un signalement S",
         nrow(ligne(r$controles, "D02c", "assures", "date_naissance")) == 2L &&
           refus(r, "D02c", "assures", "date_naissance")$identifiants == "AS2" &&
           ligne(r$signalements, "D02c", "assures", "date_naissance")$identifiants == "AS1" && partition(r))
r <- cb(avec(function(b) { b$famille$id_membre <- "ME|1;x\\y"; b$famille <- rbind(b$famille, b$famille); b }))
verifier_egal("identifiants composites : « | », « ; » et « \\ » d'une valeur échappés",
              refus(r, "D01a", "famille")$identifiants, "ME\\x7c1\\x3bx\\\\y|2025-02-01")
