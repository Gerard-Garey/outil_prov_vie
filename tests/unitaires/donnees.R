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
  i <- df[[champ]] %in% code
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
# exclusions, hypotheses_defaut et declarations_requises n'ont ni table ni colonne : une
# ligne de controles qui n'est ni dans refus_tables ni dans signalements doit voir son code
# (motif) dans l'un d'eux ; une clé portée deux fois dans controles (deux traitements) l'est
# au plus une fois par élément (réserve M2 de l'audit).
partition <- function(r) {
  cle <- function(code, table, colonne) paste(code, table, colonne, sep = "|")
  c0 <- cle(r$controles$code, r$controles$table, r$controles$colonne)
  dans <- list(cle(r$refus_tables$motif, r$refus_tables$table, r$refus_tables$colonne),
               cle(r$signalements$code, r$signalements$table, r$signalements$colonne))
  places <- unlist(dans)
  motifs_attente <- unique(c(r$exclusions$motif, r$hypotheses_defaut$motif, r$declarations_requises$motif))
  n_c0 <- table(c0)
  n_pl <- table(factor(places, levels = names(n_c0)))
  code <- sub("\\|.*$", "", names(n_c0))
  reste <- as.vector(n_c0) - as.vector(n_pl)
  !any(vapply(dans, anyDuplicated, 0L) > 0L) && all(places %in% c0) &&
    all(reste == 0L | (reste == 1L & code %in% motifs_attente))
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
verifier("base de référence : aucun constat ; seuls les contrôles non implémentés et D03h non lisible sont non exécutés ; aucune table absente",
         nrow(r0$controles) == 0L && nrow(r0$refus_tables) == 0L && length(r0$tables_absentes) == 0L &&
           all(r0$controles_non_executes$cause %in% c("non_implemente", "non_lisible")) &&
           nrow(r0$controles_non_executes) == nrow(ni_present(base_ref)) + 1L)
verifier_egal("état partiel porté par l'objet : chaque contrôle non implémenté est une ligne non exécutée",
              ns$.trier(r0$controles_non_executes[r0$controles_non_executes$cause == "non_implemente",
                                                  c("code", "table", "colonne")], d),
              ns$.trier(ni_present(base_ref), d))
x <- ligne(r0$controles_non_executes, "D03h", "garanties_souscrites")
verifier_egal("D03h, garantie décès d'un contrat collectif qui porte le maintien (non lisible, D2) : non exécuté, cause non_lisible, colonne NA",
              list(x$colonne, x$cause), list(NA_character_, "non_lisible"))
# Couverture des codes de controles.csv : aucun n'est absent à la fois des contrôles écrits
# (chaînes des règles du module, plus les codes de constater_forme()) et de
# CONTROLES_NON_IMPLEMENTES.
ecrits <- unique(unlist(lapply(c(".regle_forme", ".regle_domaine", ".regle_date_programmable", ".regles_propres",
                                 ".regle_signe", ".regle_cles", ".orphelines", ".refus_induits", ".regle_prealable",
                                 ".regle_v"), function(f) {
  txt <- paste(deparse(get(f, envir = ns)), collapse = " ")
  regmatches(txt, gregexpr("\"(D[0-9]{2}[a-z]?|[a-z_]+)\"", txt))[[1L]]
})))
ecrits <- c(gsub("\"", "", ecrits), "colonne_absente", "colonne_inconnue", "type_incompatible")
verifier("couverture : chaque code de controles.csv est écrit ou déclaré non implémenté",
         all(d$controles$code %in% c(ecrits, ns$CONTROLES_NON_IMPLEMENTES$code)))
# Couverture des défauts du § 9 par (code, table) (réserves r1 et M1) : la référence est
# tirée de defauts.csv (une paire par table de la colonne `tables`), D10 par sous-cas (le CSV
# ne dit pas quelle table porte chaque sous-cas : tables du constat d'après le texte du § 9,
# ci-dessous) ; les règles écrites sont relevées en exécution, par trace() de .regle() sur la
# base de référence à l'arrêté égal à l'extraction. Une paire est couverte par une règle
# écrite de ce code qui porte son constat sur la table (`tr$table`), par une ligne de
# CONTROLES_NON_IMPLEMENTES de ce code sur la table, ou par la liste fermée LUES des tables
# que le CSV nomme parce que le défaut les lit, sans y porter de constat.
regles_tracees <- function(b, arrete) {
  .GlobalEnv$.regles_tracees <- list()
  suppressMessages(trace(".regle", where = ns, print = FALSE, tracer = quote(
    .GlobalEnv$.regles_tracees[[length(.GlobalEnv$.regles_tracees) + 1L]] <-
      data.frame(code = code, table = table, colonne = colonne,
                 lue = unique(c(table, sub("\\..*$", "", lit))), stringsAsFactors = FALSE))))
  on.exit({ suppressMessages(untrace(".regle", where = ns)); rm(".regles_tracees", envir = .GlobalEnv) })
  controler_base(b, arrete)
  unique(do.call(rbind, .GlobalEnv$.regles_tracees))
}
tr <- regles_tracees(base_ref, A)
defaut_de <- function(code) ifelse(code %in% d$defauts$code | !grepl("^D[0-9]{2}[a-z]$", code), code, sub("[a-z]$", "", code))
tr$defaut <- defaut_de(tr$code)
ni <- ns$CONTROLES_NON_IMPLEMENTES
paires <- function(code, tables) data.frame(code = code, table = tables, stringsAsFactors = FALSE)
# D10 par sous-cas (§ 9) : (a) garantie ou type de prestation incompatible, sur dossiers,
# rentes, prestations ; (b) version hors vigueur, (c) sans dossier décès, sur dossiers ;
# (d) passage_invalidite, (f) décès du conjoint, sur evenements ; (e) qualité, sur
# beneficiaires ; (h) victime d'un autre assuré, sur victimes.
SOUS_CAS_D10 <- rbind(paires("D10a", c("dossiers", "rentes", "prestations")), paires("D10b", "dossiers"),
                      paires("D10c", "dossiers"), paires("D10d", "evenements"), paires("D10e", "beneficiaires"),
                      paires("D10f", "evenements"), paires("D10h", "victimes"))
# Tables lues sans constat : D04a, « dossier sans sinistre » (dossiers lue par la règle de
# prestations.id_dossier) ; D08, rechute (constat sur le nouveau sinistre, dossiers et
# evenements lus) ; D10, garanties_souscrites et sinistres (lues par les sous-cas a, b, c) ;
# D11, hors couverture (constat sur sinistres, contrats et affiliations lus).
LUES <- rbind(paires("D04a", "dossiers"), paires("D08", c("dossiers", "evenements")),
              paires("D10", c("garanties_souscrites", "sinistres")), paires("D11", c("contrats", "affiliations")))
reference <- do.call(rbind, lapply(seq_len(nrow(d$defauts)), function(i) {
  if (d$defauts$code[i] == "D10") return(SOUS_CAS_D10)
  paires(d$defauts$code[i], ns$.eclater_champ(d$defauts$tables[i]))
}))
reference <- reference[!(paste(reference$code, reference$table) %in% paste(LUES$code, LUES$table)), , drop = FALSE]
manquantes_de <- function(tr) {
  couverte <- function(code, table) table %in% tr$table[tr$code == code] || table %in% ni$table[ni$code == code]
  m <- reference[!mapply(couverte, reference$code, reference$table), , drop = FALSE]
  paste(m$code, m$table)
}
verifier_egal("couverture (code, table) : chaque table de chaque défaut du § 9 (D10 par sous-cas) porte une règle écrite ou déclarée non implémentée",
              manquantes_de(tr), character(0))
verifier("couverture (code, table) : LUES et D10 tirés du CSV (chaque paire de LUES est une paire de defauts.csv ; les tables de D10 sont celles du CSV)",
         all(paste(LUES$code, LUES$table) %in% paste(rep(d$defauts$code, lengths(strsplit(d$defauts$tables, ";"))),
                                                     unlist(strsplit(d$defauts$tables, ";")))) &&
           setequal(c(SOUS_CAS_D10$table, LUES$table[LUES$code == "D10"]),
                    ns$.eclater_champ(d$defauts$tables[d$defauts$code == "D10"])))
verifier("couverture (code, table) : les tables lues sans constat d'un défaut écrit le sont bien par une de ses règles (D04a, D10)",
         all(c("garanties_souscrites", "sinistres") %in% tr$lue[tr$defaut == "D10"]) && "dossiers" %in% tr$lue[tr$code == "D04a"])
verifier_egal("couverture (code, table) : témoins, la suppression d'une règle écrite est vue (D02b sur catastrophes, D10b)",
              list(manquantes_de(tr[!(tr$code == "D02b" & tr$table == "catastrophes"), ]),
                   manquantes_de(tr[tr$code != "D10b", ])),
              list("D02b catastrophes", "D10b dossiers"))
verifier("règles tracées : codes connus, tables du dictionnaire", all(tr$defaut %in% c(d$defauts$code, d$controles$code)) &&
           all(tr$table %in% d$tables$table))
# Ce qui est écrit n'est plus déclaré non implémenté : aucune ligne de CONTROLES_NON_IMPLEMENTES
# ne désigne une règle écrite (code, table, colonne) ; une ligne de colonne NA sur une table où
# le code est écrit n'est admise que pour les sous-cas D02c (âge) et D09 (seuils).
cle3 <- function(x) paste(x$code, x$table, x$colonne)
verifier_egal("CONTROLES_NON_IMPLEMENTES : aucune règle écrite n'y figure", intersect(cle3(ni), cle3(tr)), character(0))
verifier_egal("CONTROLES_NON_IMPLEMENTES : colonne NA sur une table écrite seulement pour D02c (âge) et D09 (seuils)",
              unique(ni$code[is.na(ni$colonne) & paste(ni$code, ni$table) %in% paste(tr$code, tr$table)]),
              c("D02c", "D09"))
verifier("CONTROLES_NON_IMPLEMENTES : codes connus, tables et colonnes du dictionnaire, sans doublon",
         {
           all(ni$code %in% d$controles$code | sub("[a-z]$", "", ni$code) %in% d$defauts$code | ni$code %in% d$defauts$code) &&
             all(ni$table %in% d$tables$table) &&
             all(is.na(ni$colonne) | paste(ni$table, ni$colonne) %in% paste(d$colonnes$table, d$colonnes$colonne)) &&
             !anyDuplicated(ni[, c("code", "table", "colonne")])
         })
verifier("D02c (âge) et D07 : déclarés non implémentés ; D02b, D03g, D04a, D04b, somme_parts : écrits, plus déclarés",
         all(c("D02c", "D07") %in% r0$controles_non_executes$code) &&
           !any(c("D02b", "D03g", "D04a", "D04b", "somme_parts") %in% ni$code))
r <- cb(base_ref, conventions = NULL)
verifier("sans conventions : D02c (âge) et D07 portent non_implemente, qui prime sur declaration_absente",
         all(ligne(r$controles_non_executes, "D02c", "assures", NA)$cause == "non_implemente") &&
           all(ligne(r$controles_non_executes, "D07", "evenements", NA)$cause == "non_implemente"))
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
# EV1 (entree_incapacite) à une date future : D02c refuse evenements.date_effet, que D02a lit
# (règle V non exécutée, cause D02c, décision D3) ; evenements est de plus refusée par
# induction (D01a de sinistres) : aucun constat en attente de déclaration (réserve m3)
verifier("multi : D02a sur evenements non exécuté (colonne et table refusées en règle B)",
         nrow(ligne(r$controles, "D02a", "evenements")) == 0L &&
           nrow(ligne(r$controles_non_executes, "D02a", "evenements", "date_effet")) == 1L)
verifier("aucun code de portée ligne dans refus_tables ; portée effective colonne ou table seulement",
         !any(r$refus_tables$motif %in% d$controles$code[d$controles$portee == "ligne"]) &&
           all(r$refus_tables$portee %in% c("colonne", "table")))
verifier("controles_non_executes : causes parmi les codes de refus et declaration_absente",
         all(r$controles_non_executes$cause %in% c(d$controles$code, d$defauts$code, "declaration_absente",
                                                   "non_implemente", "non_lisible")))
verifier("controler_base() ne rend aucun poste arrêté (B2) ; nombre_visibles au plus nombre (à l'extraction, égal)",
         all(is.na(r$refus_tables$postes_arretes)) &&
           identical(r$refus_tables$nombre_visibles[!is.na(r$refus_tables$nombre_visibles)],
                     r$refus_tables$nombre[!is.na(r$refus_tables$nombre_visibles)]))
melange <- lapply(multi, function(t) if (nrow(t) > 1L) t[rev(seq_len(nrow(t))), rev(names(t)), drop = FALSE] else t)
verifier_egal("tri reproductible : bilan identique, lignes et colonnes des tables dans un autre ordre", cb(melange), r)
verifier_egal("tri : ordre des tables du dictionnaire, colonnes, code",
              unique(r$controles$table), d$tables$table[d$tables$table %in% r$controles$table])
r_a0 <- cb(multi, A0)
verifier_egal("invariance en A (règle B) : controles identiques à deux arrêtés", r_a0$controles, r$controles)
verifier_egal("invariance en A (règle B) : refus_tables (hors nombre_visibles et nombre_dossiers, comptes à l'arrêté) identiques",
              r_a0$refus_tables[, !(names(r$refus_tables) %in% c("nombre_visibles", "nombre_dossiers"))],
              r$refus_tables[, !(names(r$refus_tables) %in% c("nombre_visibles", "nombre_dossiers"))])
verifier_egal("vue : date d'arrêté consignée", r_a0$vue$date_arrete, A0)

section("donnees : règle P (D02b, D03g) et vue à une date (règles I, 1, M156)")
verifier_egal("vue de la base de référence : sous-éléments, aucune visibilité non déterminée",
              list(names(r0$vue), nrow(r0$vue$visibilite_non_determinee), r0$vue$provisoire),
              list(c("date_arrete", "date_extraction", "visibilite_non_determinee", "provisoire"), 0L, FALSE))
verifier_egal("colonnes de vue$visibilite_non_determinee", names(r0$vue$visibilite_non_determinee),
              c("table", "colonne", "motif", "nombre", "identifiants"))
pb <- avec(function(b) {
  b$evenements$date_saisie[2L] <- D("2024-05-01")      # saisie avant la date d'effet (ouverture_service)
  b$sinistres$date_saisie[2L] <- D("2024-03-04")       # saisie avant la déclaration
  b$beneficiaires$date_saisie <- D("2025-01-15")       # fille saisie avant son dossier (DO1 : 2025-01-22)
  b$catastrophes$date_saisie <- D("2026-05-31")        # saisie avant l'événement
  b$contrats$date_fin[2L] <- D("2026-12-31"); b$contrats$motif_fin[2L] <- "resiliation_adherent"
  b$contrats$date_saisie_fin[2L] <- D("2015-12-01")    # fin saisie avant l'effet du contrat
  b$prestations$date_saisie[1L] <- NA                  # D03g
  b$affiliations$date_fin <- D("2026-06-30"); b$affiliations$motif_fin <- "depart_entreprise"   # D03g de la fin
  b })
r <- cb(pb)
x <- ligne(r$controles, "D02b", NULL)
verifier_egal("D02b détecté sur la base entière : saisie avant l'effet, avant la déclaration, fille avant parente, fin de contrat",
              paste(x$table, x$colonne, x$identifiants),
              c("contrats date_saisie_fin CT2", "sinistres date_saisie SI2", "beneficiaires date_saisie BE1",
                "evenements date_saisie EV2", "catastrophes date_saisie CA1"))
x <- ligne(r$controles, "D03g", NULL)
verifier_egal("D03g : date de saisie manquante, date de saisie de fin manquante sous sa condition",
              paste(x$table, x$colonne, x$identifiants),
              c("affiliations date_saisie_fin AF1", "prestations date_saisie PR1"))
verifier("règle I : à l'arrêté égal à l'extraction, D02b et D03g sont des signalements, aucune visibilité non déterminée",
         all(c("D02b", "D03g") %in% r$signalements$code) && nrow(r$vue$visibilite_non_determinee) == 0L &&
           !r$vue$provisoire && partition(r))
r_a0 <- cb(pb, A0)
verifier_egal("invariance (règle P) : lignes de D02b et D03g identiques à deux arrêtés",
              ligne(r_a0$controles, c("D02b", "D03g"), NULL), ligne(r$controles, c("D02b", "D03g"), NULL))
verifier("arrêté antérieur : D02b et D03g attendent une déclaration, hors des signalements",
         !any(c("D02b", "D03g") %in% r_a0$signalements$code))
x <- r_a0$vue$visibilite_non_determinee
verifier_egal("arrêté antérieur : visibilité non déterminée par table, colonne (partie de ligne ; NA : ligne entière) et motif, filles recensées (M156, D1)",
              paste(x$table, x$colonne, x$motif, x$nombre, x$identifiants),
              c("contrats date_saisie_fin D02b 1 CT2", "affiliations date_saisie_fin D03g 1 AF1", "sinistres NA D02b 1 SI2",
                "dossiers NA parente_non_determinee 1 DO3", "beneficiaires NA D02b 1 BE1", "evenements NA D02b 1 EV2",
                "evenements NA parente_non_determinee 2 EV1;EV3", "prestations NA D03g 1 PR1", "catastrophes NA D02b 1 CA1",
                "evaluations_gestion NA parente_non_determinee 1 EG1"))
verifier("arrêté antérieur : vue$provisoire vrai", isTRUE(r_a0$vue$provisoire))
ctx_vue <- function(b, arrete) {
  ctx <- ns$.contexte(b, d, list(date_extraction = A), arrete)
  ns$.visibilite_propre(ctx); ns$.regle_prealable(ctx); ns$.construire_vue(ctx)
  ctx
}
ctx <- ctx_vue(pb, A0)
verifier("vue : une ligne de visibilité non déterminée est tenue hors de la vue, et ses filles avec elle (règle 1)",
         !ctx$retenu$sinistres[2L] && !any(ctx$retenu$evenements[1:3]) && !ctx$retenu$dossiers[3L] &&
           !ctx$retenu$prestations[1L])
verifier("vue : une partie de ligne indéterminée laisse la ligne dans la vue, partie masquée (D1, A1)",
         ctx$retenu$contrats[2L] && ctx$retenu$affiliations[1L] &&
           is.na(ns$.valeurs_vue(ctx, "contrats", "date_fin")[2L]) && is.na(ns$.valeurs_vue(ctx, "affiliations", "date_fin")[1L]))
ctx <- ctx_vue(base_ref, A0)
verifier_egal("vue de la base de référence au 2025-06-30 : lignes visibles selon le § 6",
              lapply(ctx$retenu[c("contrats", "sinistres", "dossiers", "evenements", "prestations", "cotisations",
                                  "catastrophes", "victimes", "designations")], which),
              list(contrats = 1:2, sinistres = 1:2, dossiers = 1:3, evenements = 1:6, prestations = 1:3,
                   cotisations = integer(0), catastrophes = integer(0), victimes = integer(0), designations = 1L))
ctx <- ctx_vue(base_ref, D("2024-05-15"))
verifier_egal("vue au 2024-05-15 : fille d'une parente invisible invisible ; assuré retenu s'il est référencé",
              list(which(ctx$retenu$dossiers), which(ctx$retenu$evenements), which(ctx$retenu$prestations),
                   which(ctx$retenu$beneficiaires), which(ctx$retenu$assures)),
              list(3L, 1L, integer(0), integer(0), 1:2))
b <- avec(function(b) { b$famille <- rbind(b$famille, transform(b$famille, date_saisie = D("2025-09-01"), situation = "apprenti")); b })
verifier_egal("vue : seule la dernière saisie retenue d'un membre de famille est valable",
              c(which(ctx_vue(b, A0)$retenu$famille), which(ctx_vue(b, A)$retenu$famille)), c(1L, 2L))
b <- avec(function(b) { b$contrats$date_fin[1L] <- D("2026-06-30"); b$contrats$motif_fin[1L] <- "resiliation_adherent"
                        b$contrats$date_saisie_fin[1L] <- D("2026-04-01"); b$sinistres$date_instruction[2L] <- D("2025-09-01"); b })
ctx <- ctx_vue(b, A0)
verifier_egal("vue : partie de ligne inconnue à l'arrêté (fin saisie après, instruction postérieure) manquante",
              list(ns$.valeurs_vue(ctx, "contrats", "date_fin")[1L], ns$.valeurs_vue(ctx, "sinistres", "date_instruction")[2L],
                   ns$.valeurs_vue(ctx_vue(b, D("2026-05-01")), "contrats", "date_fin")[1L]),
              list(as.Date(NA), as.Date(NA), D("2026-06-30")))
r <- cb(avec(function(b) { b$evenements$date_saisie <- as.character(b$evenements$date_saisie); b }), A0)
verifier("règle P et vue : une date de saisie mal typée empêche D02b, D03g et les règles de la vue qui la lisent",
         all(c("D02b", "D03g") %in% ligne(r$controles_non_executes, c("D02b", "D03g"), "evenements", "date_saisie")$code) &&
           all(ligne(r$controles_non_executes, c("D02b", "D03g"), "evenements")$cause == "type_incompatible"))
verifier("Q4 : une règle P non exécutée à un arrêté antérieur rend la vue provisoire ; à l'extraction, non",
         isTRUE(r$vue$provisoire) && nrow(r$vue$visibilite_non_determinee) == 0L &&
           !cb(avec(function(b) { b$evenements$date_saisie <- as.character(b$evenements$date_saisie); b }))$vue$provisoire)
verifier_egal("m6 : famille.id_membre et famille.date_saisie lues pour établir la vue de famille, à tout arrêté",
              list(ctx_vue(base_ref, A)$lit_vue$famille, all(c("famille.id_membre", "famille.date_saisie") %in%
                                                              ctx_vue(base_ref, A0)$lit_vue$famille)),
              list(c("famille.id_membre", "famille.date_saisie"), TRUE))
pc <- avec(function(b) { b$contrats$date_fin[1L] <- D("2026-03-31"); b$contrats$motif_fin[1L] <- "resiliation_adherent"
                         b$garanties_souscrites$taux_technique_tarif[3L] <- NA; b$affiliations$salaire_reference <- NA_real_; b })
r <- cb(pc, D("2026-06-30"))
verifier("D1 : date_saisie_fin manquante d'un contrat : partie recensée, le contrat et ses garanties et affiliations restent dans la vue (D03h, D03c détectés)",
         identical(paste(r$vue$visibilite_non_determinee$table, r$vue$visibilite_non_determinee$colonne),
                   "contrats date_saisie_fin") &&
           ligne(r$controles, "D03h", "garanties_souscrites")$identifiants == "GS3" &&
           ligne(r$controles, "D03c", "affiliations")$identifiants == "AF1")
r <- cb(avec(function(b) { b$assures$sexe <- c("X", NA); b }))
verifier("D3 : une colonne refusée pour une valeur (hors_domaine, portée colonne) n'est pas lue par la règle V (D03b non exécuté)",
         nrow(ligne(r$controles, "D03b", "assures")) == 0L &&
           identical(ligne(r$controles_non_executes, "D03b", "assures", "sexe")$cause, "hors_domaine"))
r <- cb(avec(function(b) { b$assures <- rbind(b$assures, transform(b$assures[1L, ], sexe = NA_character_)); b }))
verifier("A9 : une table refusée (D01a) n'est pas lue par la règle V (D03b non exécuté, cause D01a)",
         nrow(ligne(r$controles, "D03b", "assures")) == 0L &&
           identical(ligne(r$controles_non_executes, "D03b", "assures", "sexe")$cause, "D01a"))
r <- cb(avec(function(b) { b$sinistres$date_saisie[2L] <- D("2027-01-05"); b$sinistres$date_declaration[2L] <- D("2027-01-02"); b }), A0)
verifier("D3 : une date de visibilité refusée (D02c) empêche la règle P et les règles V de la table à un arrêté antérieur",
         identical(ligne(r$controles_non_executes, "D02b", "sinistres", "date_saisie")$cause, "D02c") &&
           isTRUE(r$vue$provisoire))

section("donnees : orphelines traitées X (D04a, D04b) et somme_parts (règle V)")
ob <- avec(function(b) { b$prestations$id_dossier[1L] <- "DOX"; b$prestations$id_dossier[2L] <- NA
                         b$evenements$id_sinistre[1L] <- "SIX"; b$victimes$id_catastrophe <- "CAX"; b })
r <- cb(ob)
x <- ligne(r$controles, c("D04a", "D04b"), NULL)
verifier_egal("orphelines X détectées (prestation au dossier absent ou manquant, événement, victime)",
              paste(x$code, x$table, x$colonne, x$identifiants),
              c("D04b evenements id_sinistre EV1", "D04a prestations id_dossier PR1;PR2", "D04b victimes id_catastrophe VI1"))
verifier("orphelines X : aucun refus, aucun refus induit (traitement X, attente d'une déclaration)",
         nrow(r$refus_tables) == 0L && !any(c("D04a", "D04b") %in% r$signalements$code))
verifier("orphelines X : détection sur la base entière, identique à tout arrêté (A3 ; spécification, § 2.5, critères 1 et 3)",
         identical(ligne(cb(ob, A0)$controles, c("D04a", "D04b"), NULL), x) &&
           identical(ligne(cb(ob, D("2024-05-15"))$controles, c("D04a", "D04b"), NULL), x))
sb <- avec(function(b) { b$beneficiaires <- rbind(b$beneficiaires, transform(b$beneficiaires, id_beneficiaire = "BE2", part = 0.25)); b })
r <- cb(sb)
x <- ligne(r$signalements, "somme_parts", "beneficiaires", "part")
verifier("somme_parts : parts d'un dossier de somme 1,25, toutes les lignes du dossier signalées (S)",
         nrow(x) == 1L && x$identifiants == "BE1;BE2" && x$nombre == 2L && partition(r))
r <- cb(avec(function(b) { b$beneficiaires <- rbind(b$beneficiaires, b$beneficiaires, b$beneficiaires)
                           b$beneficiaires$id_beneficiaire <- c("BE1", "BE2", "BE3"); b$beneficiaires$part <- 1 / 3; b }))
verifier("somme_parts : trois tiers en double précision ne sont pas signalés", !any(r$controles$code == "somme_parts"))
verifier_egal("somme_parts sur la vue : bénéficiaires invisibles au 2024-05-15, rien de signalé",
              nrow(ligne(cb(sb, D("2024-05-15"))$controles, "somme_parts", NULL)), 0L)
r <- cb(ob)
verifier("partition : un constat qui attend une déclaration (X) est placé dans declarations_requises (sans déclaration)",
         partition(r) && all(c("D04a", "D04b") %in% r$declarations_requises$motif))
verifier("partition (M2) : le prédicat bascule si un constat en attente n'est placé nulle part (témoin)", {
  r$declarations_requises <- r$declarations_requises[r$declarations_requises$motif != "D04a", , drop = FALSE]
  !partition(r)
})

section("donnees : règle V, manquants (D03a à D03c, D03e, D03f, D03h) et ordre des dates (D02a)")
mb <- avec(function(b) {
  b$assures$date_naissance[2L] <- NA; b$famille$sexe <- NA_character_; b$affiliations$salaire_reference <- NA_real_
  b$evenements <- rbind(b$evenements, transform(b$evenements[1L, ], id_evenement = "EV7", type_evenement = "passage_invalidite",
                                                date_effet = D("2024-06-01"), date_saisie = D("2024-06-02")))
  b$prestations$fin_periode[1L] <- NA; b$cotisations$debut_periode[2L] <- NA
  b$garanties_souscrites$taux_technique_tarif[c(3L, 4L)] <- NA; b })
r <- cb(mb)
x <- ligne(r$controles, c("D03a", "D03b", "D03c", "D03e", "D03f", "D03h"), NULL)
verifier_egal("manquants qui ont un défaut au § 9 : détectés sur la vue, un constat par table",
              paste(x$code, x$table, x$colonne, x$identifiants),
              c("D03h garanties_souscrites taux_technique_tarif GS3;GS4", "D03a assures date_naissance AS2",
                "D03c affiliations salaire_reference AF1", "D03b famille sexe ME1|2025-02-01",
                "D03e evenements categorie_invalidite EV7", "D03f prestations NA PR1", "D03f cotisations NA CO2"))
verifier("manquants : aucun refus (le manquant relève du défaut, non de manquant_obligatoire)", nrow(r$refus_tables) == 0L)
r <- cb(avec(function(b) { b$famille$date_naissance <- NA; b$famille$situation <- "a_naitre"; b }))
verifier("D03a : naissance manquante d'un enfant à naître non détectée", !any(r$controles$code == "D03a"))
r <- cb(avec(function(b) { b$garanties_souscrites$taux_technique_tarif[1L] <- NA; b }))
verifier("D03h, décès d'un contrat collectif (maintien non lisible) : pas de détection, sous-cas non exécuté (non_lisible), jamais un zéro rassurant (D2)",
         !any(r$controles$code == "D03h") &&
           identical(ligne(r$controles_non_executes, "D03h", "garanties_souscrites", NA)$cause, "non_lisible"))
r <- cb(mb, D("2024-05-15"))
x <- ligne(r$controles, c("D03a", "D03b", "D03c", "D03e", "D03f", "D03h"), NULL)
verifier_egal("manquants sur la vue au 2024-05-15 : lignes invisibles écartées (EV7, PR1, CO2, membre de 2025)",
              paste(x$code, x$table), c("D03h garanties_souscrites", "D03a assures", "D03c affiliations"))
ob <- avec(function(b) {
  b$contrats$date_debut_gestion[1L] <- D("2014-12-31"); b$garanties_souscrites$date_fin[2L] <- D("2014-06-30")
  b$affiliations$date_fin <- D("2014-12-31"); b$affiliations$motif_fin <- "depart_entreprise"; b$affiliations$date_saisie_fin <- D("2015-01-06")
  b$ayants_droit_sante$fin_couverture <- D("2014-01-01"); b$prestations$debut_periode[1L] <- D("2024-07-01")
  b$sinistres$date_declaration[1L] <- D("2025-01-05"); b$sinistres$date_instruction[1L] <- D("2025-01-03")
  b$famille$date_naissance <- D("2025-03-01"); b$assures$date_naissance[1L] <- D("2024-04-01")
  b$evenements$date_effet[1L] <- D("2024-03-02"); b })
r <- cb(ob)
x <- ligne(r$controles, "D02a", NULL)
verifier_egal("D02a : chaque sous-cas détecté sur sa colonne (date qui devrait être la plus tardive)",
              paste(x$table, x$colonne, x$identifiants),
              c("contrats date_debut_gestion CT1", "garanties_souscrites date_fin GS2", "affiliations date_fin AF1",
                "famille date_naissance ME1|2025-02-01", "sinistres date_survenance SI2", "sinistres date_declaration SI1",
                "sinistres date_instruction SI1", "evenements date_effet EV1", "prestations fin_periode PR1",
                "ayants_droit_sante fin_couverture AY1"))
verifier("D02a : traitement X ou H en attente de déclaration, hors des refus et des signalements",
         !any(r$refus_tables$motif == "D02a") && !any(r$signalements$code == "D02a"))
r <- cb(avec(function(b) { b$famille$date_naissance <- NA; b$famille$situation <- "a_naitre"; b }))
verifier("D02a : un enfant à naître n'est jamais rejeté", !any(r$controles$code == "D02a"))
r <- cb(avec(function(b) { b$evenements <- rbind(b$evenements, transform(b$evenements[4L, ], id_evenement = "EV7",
                             type_evenement = "mise_a_jour", date_effet = D("2025-01-01"), montant = NA)); b }))
verifier_egal("D02a : mise à jour datée avant la survenance", ligne(r$controles, "D02a", "evenements")$identifiants, "EV7")
b <- avec(function(b) { b$sinistres$date_instruction[1L] <- D("2025-09-01"); b$sinistres$date_declaration[1L] <- D("2025-08-01")
                        b$sinistres$date_saisie[1L] <- D("2025-01-21"); b })
verifier_egal("D02a sur la vue : un sinistre de visibilité non déterminée (D02b) est hors de la vue à un arrêté antérieur",
              ligne(cb(b, A0)$controles, "D02a", "sinistres")$colonne, character(0))

section("donnees : règle V, doublons de contenu (D01b), clôtures (D05, D06, D13), garanties (D10 b et c)")
db <- avec(function(b) {
  b$prestations <- rbind(b$prestations, transform(b$prestations[1L, ], id_prestation = "PR0", date_saisie = D("2025-09-01")))
  b$sinistres <- rbind(b$sinistres, transform(b$sinistres[2L, ], id_sinistre = "SI0", date_saisie = D("2024-03-07")))
  b$cotisations <- rbind(b$cotisations, transform(b$cotisations[1L, ], id_cotisation = "CO0"))
  b })
r <- cb(db)
x <- ligne(r$controles, "D01b", NULL)
verifier_egal("D01b : la copie saisie après l'original est comptée (à date égale, la clé départage), colonne NA ; S + X : deux lignes",
              paste(x$table, x$colonne, x$identifiants),
              rep(c("sinistres NA SI0", "prestations NA PR0", "cotisations NA CO1"), each = 2L))
verifier_egal("D01b, S + X (A5) : le signalement est placé, l'exclusion attend sa déclaration",
              paste(ligne(r$signalements, "D01b", NULL)$table), c("sinistres", "prestations", "cotisations"))
verifier_egal("D01b sur la vue : au 2025-06-30, la copie PR0 (saisie en septembre) n'est pas visible",
              unique(paste(ligne(cb(db, A0)$controles, "D01b", NULL)$table)), "sinistres")
r <- cb(avec(function(b) { b$sinistres <- rbind(b$sinistres, b$sinistres[1L, ]); b }))
verifier("D01b : un doublon d'identifiant (D01a) n'est pas une copie sous un nouvel identifiant", !any(r$controles$code == "D01b"))
r <- cb(avec(function(b) { b$evenements$motif[3L] <- NA; b$prestations <- b$prestations[-1L, ]; b$evaluations_gestion <- NULL; b }))
x <- ligne(r$controles, "D05", "evenements", "motif")
verifier("D05 : sortie au motif manquant sans prestation du sinistre, en attente de déclaration (H ou S)",
         nrow(x) == 1L && x$identifiants == "EV3" && !any(r$signalements$code == "D05") && !any(r$refus_tables$motif == "D05"))
r <- cb(avec(function(b) { b$evenements$justificatif[3L] <- NA; b$evenements$motif[6L] <- "deces_beneficiaire"
                           b$evenements$date_effet[6L] <- D("2026-03-01")
                           b$evenements <- rbind(b$evenements, transform(b$evenements[4L, ], id_evenement = "EV7",
                             type_evenement = "cloture_dossier", motif = "depot_cdc", montant = NA, date_effet = D("2025-02-10"),
                             date_saisie = D("2025-02-11")), transform(b$evenements[2L, ], id_evenement = "EV8",
                             type_evenement = "cloture_dossier", motif = "regle", montant = NA, id_dossier = "DO3"))
                           b$prestations <- b$prestations[-1L, ]; b$evaluations_gestion <- NULL; b }))
verifier_egal("D06 : sortie et fin de service sans justificatif ; clôture regle sans prestation ; depot_cdc avec capital non détecté",
              ligne(r$controles, "D06", "evenements", "justificatif")$identifiants, "EV3;EV6;EV8")
ib <- avec(function(b) { b$sinistres$date_instruction[1L] <- NA; b })
verifier_egal("D13 : sinistre décès sans instruction dont le dossier décès a une prestation capital",
              ligne(cb(ib)$controles, "D13", "sinistres", "date_instruction")$identifiants, "SI1")
verifier_egal("D13 sur la vue : au 2025-02-15, la prestation capital (réglée en mars) n'est pas visible",
              nrow(ligne(cb(ib, D("2025-02-15"))$controles, "D13", NULL)), 0L)
verifier_egal("D13 sur la vue : instruction postérieure à l'arrêté = instruction absente à l'arrêté",
              ligne(cb(avec(function(b) { b$prestations$date_reglement[2L] <- D("2025-01-30")
                                          b$prestations$date_saisie[2L] <- D("2025-01-30"); b }), D("2025-01-31"))$controles,
                    "D13", NULL)$identifiants, "SI1")
gb <- avec(function(b) { b$garanties_souscrites$date_effet[3L] <- D("2025-06-01"); b$dossiers$id_garantie_souscrite[1L] <- "GS4"; b })
r <- cb(gb)
x <- ligne(r$controles, "D10b", "dossiers", "id_garantie_souscrite")
verifier("D10 (b) : version hors vigueur à la survenance : deux lignes de même clé (S et X), le signalement placé",
         nrow(x) == 2L && all(x$identifiants == "DO2") &&
           ligne(r$signalements, "D10b", "dossiers", "id_garantie_souscrite")$identifiants == "DO2")
r <- cb(avec(function(b) { b$dossiers <- b$dossiers[-1L, ]; b$beneficiaires <- b$beneficiaires[0L, ]
                           b$evenements <- b$evenements[-4L, ]; b$prestations <- b$prestations[-2L, ]; b }))
x <- ligne(r$signalements, "D10c", "dossiers", NA)
verifier("D10 (c) : dossier de rente d'éducation sans dossier décès du sinistre, garantie décès souscrite au contrat : signalement",
         nrow(x) == 1L && x$identifiants == "DO2")
verifier("D10 (c) : rien sur la base de référence (dossier décès DO1 du même sinistre)", !any(r0$controles$code == "D10c"))
sans_do1 <- function(b) { b$dossiers <- b$dossiers[-1L, ]; b$beneficiaires <- b$beneficiaires[0L, ]
                          b$evenements <- b$evenements[-4L, ]; b$prestations <- b$prestations[-2L, ]; b }
verifier("D10 (c) (A6) : garantie décès d'un autre collège, ou d'une version hors vigueur à la survenance : pas de signalement",
         !any(cb(avec(function(b) { b <- sans_do1(b); b$garanties_souscrites$college[1L] <- "cadres"
                                    b$affiliations$college <- "cadres"; b }))$controles$code == "D10c") &&
           !any(cb(avec(function(b) { b <- sans_do1(b); b$garanties_souscrites$date_fin[1L] <- D("2020-12-31"); b }))$controles$code == "D10c"))
verifier("D10 (c) (A6) : la garantie décès doit être retenue dans la vue (version d'effet postérieur à l'arrêté : rien)",
         !any(cb(avec(function(b) { b <- sans_do1(b); b$garanties_souscrites$date_effet[1L] <- D("2025-01-01"); b }),
                 D("2024-12-31"))$controles$code == "D10c"))

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
verifier("r2 : une clé détectée par une règle et non exécutée par une autre est dans les deux éléments (détection partielle, cause gardée)",
         nrow(ligne(r$controles, "hors_domaine", "evenements", "id_dossier")) == 1L &&
           ligne(r$controles, "hors_domaine", "evenements", "id_dossier")$identifiants == "EV1" &&
           identical(ligne(r$controles_non_executes, "hors_domaine", "evenements", "id_dossier")$cause, "type_incompatible"))
r <- cb(avec(function(b) { b$dossiers$id_sinistre <- factor(b$dossiers$id_sinistre); b }))
verifier("m2 : sans détection, la règle non exécutée reste dans controles_non_executes (pas de zéro rassurant)",
         nrow(ligne(r$controles_non_executes, "hors_domaine", "evenements", "id_dossier")) == 1L &&
           nrow(ligne(r$controles, "hors_domaine", "evenements", "id_dossier")) == 0L)
r <- cb(avec(function(b) { b$dossiers$id_sinistre <- factor(b$dossiers$id_sinistre); b$prestations$montant[1L] <- -5; b }))
verifier("r2 : une seule ligne non exécutée par (code, table, colonne), la première cause gardée",
         !anyDuplicated(r$controles_non_executes[, c("code", "table", "colonne")]) &&
           identical(ligne(r$controles_non_executes, "hors_domaine", "evenements", "id_dossier")$cause, "type_incompatible"))
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

section("donnees : déclarations (sous-schéma donnees, ADR 0010, point 17) et placement des constats (§ 3)")
excl4 <- function(motif, action = "exclure") {
  data.frame(motif = motif, famille = ns$FAMILLES_CALCUL, action = action, stringsAsFactors = FALSE)
}
hyp2 <- function(motif, referentiels = ns$REFERENTIELS, valeur = "regle") {
  lapply(referentiels, function(r) list(motif = motif, referentiel = r, poste = "tous", valeur = valeur))
}
for (cas in list(
  list("exclusions, motif inconnu", list(exclusions = excl4("D99"))),
  list("exclusions, motif d'un défaut sans X (D03b)", list(exclusions = excl4("D03b"))),
  list("exclusions, sous-cas g de D10 (non attribué)", list(exclusions = excl4("D10g"))),
  list("exclusions, famille inconnue", list(exclusions = data.frame(motif = "D04a", famille = "autre", action = "exclure"))),
  list("exclusions, action inconnue", list(exclusions = data.frame(motif = "D04a", famille = "triangle", action = "garder"))),
  list("exclusions, deux lignes pour un (motif, famille)", list(exclusions = rbind(excl4("D04a"), excl4("D04a")[1L, ]))),
  list("exclusions, colonne en trop", list(exclusions = cbind(excl4("D04a"), poste = "tous"))),
  list("exclusions, valeur manquante", list(exclusions = transform(excl4("D04a"), action = NA_character_))),
  list("exclusions, liste incomplète", list(exclusions = list(list(motif = "D04a", famille = "triangle")))),
  list("exclusions, chaîne", list(exclusions = "D04a")),
  list("hypotheses, motif d'un défaut sans H (D04a)", list(hypotheses = hyp2("D04a"))),
  list("hypotheses, référentiel inconnu", list(hypotheses = hyp2("D03b", "ifrs17"))),
  list("hypotheses, deux lignes pour un (motif, referentiel, poste)", list(hypotheses = c(hyp2("D03b"), hyp2("D03b")))),
  list("seuils non nommés", list(seuils = list(1))),
  list("evaluations_gestion sans diagnostics", list(evaluations_gestion = list(autre = TRUE))),
  list("evaluations_gestion$diagnostics manquant", list(evaluations_gestion = list(diagnostics = NA))))) {
  verifier_egal(paste0("declarations, ", cas[[1L]], " : plan_invalide"),
                motif_de(cb(base_ref, declarations = cas[[2L]])), "plan_invalide")
}
verifier_egal("declarations admises : seuils nommés, evaluations_gestion$diagnostics, rubriques vides",
              motif_de(cb(base_ref, declarations = list(exclusions = list(), hypotheses = NULL, seuils = list(n = 1),
                                                        evaluations_gestion = list(diagnostics = TRUE)))), "aucun")
gX <- avec(function(b) { b$garanties_souscrites$date_effet[3L] <- D("2025-06-01"); b })   # D10b sur DO2
verifier_egal("declarations : data.frame et liste de listes donnent le même bilan (sous-cas D10b admis)",
              cb(gX, declarations = list(exclusions = excl4("D10b"))),
              cb(gX, declarations = list(exclusions = lapply(1:4, function(i) as.list(excl4("D10b")[i, ])))))
oX <- avec(function(b) { b$prestations$id_dossier[1L] <- "DOX"; b$prestations$id_dossier[2L] <- NA
                         b$evenements$id_sinistre[1L] <- "SIX"; b$victimes$id_catastrophe <- "CAX"; b })
r <- cb(oX)
verifier_egal("bilan sans déclaration (M148) : declarations = NULL et list() identiques", cb(oX, declarations = list()), r)
x <- r$declarations_requises
verifier_egal("sans déclaration : un constat X attend une exclusion par famille de calcul, aucune exclusion placée",
              list(nrow(r$exclusions), unique(x$rubrique), x$cle[x$motif == "D04a"], x$nombre_lignes[x$motif == "D04a"],
                   x$nombre_lignes[x$motif == "D04b"], unique(x$traitements_admis)),
              list(0L, "exclusions", ns$FAMILLES_CALCUL, rep(2L, 4L), rep(2L, 4L), "X"))
r <- cb(oX, declarations = list(exclusions = rbind(excl4("D04a"), excl4("D04b", "conserver")[1:2, ])))
verifier_egal("exclusions déclarées : une ligne par (motif, famille, action), lignes et dossiers comptés ; familles sans déclaration en attente",
              list(paste(r$exclusions$motif, r$exclusions$famille, r$exclusions$action, r$exclusions$nombre_lignes,
                         r$exclusions$nombre_dossiers),
                   paste(r$declarations_requises$motif, r$declarations_requises$cle)),
              list(c(paste("D04a", ns$FAMILLES_CALCUL, "exclure 2 0"), "D04b engagement conserver 2 0", "D04b triangle conserver 2 0"),
                   c("D04b risque_en_cours", "D04b regle_comptable")))
verifier("critère 7 (§ 4.6) : non_declaree seulement pour un (motif, famille) non couvert ; partition",
         setequal(unique(paste(r$enjeu$motif, r$enjeu$famille)[r$enjeu$action == "non_declaree" & r$enjeu$motif != "ensemble"]),
                  c("D04b risque_en_cours", "D04b regle_comptable")) && partition(r))
r <- cb(oX, D("2024-05-15"))
verifier_egal("orphelines X : seules les lignes de visibilité propre à l'arrêté sont traitées (au 2024-05-15 : aucune prestation, EV1 seul)",
              list(ligne(r$controles, "D04a", "prestations")$nombre, unique(ligne(r$declarations_requises, "D04a", champ = "motif")$nombre_lignes),
                   ligne(r$controles, "D04b", NULL)$nombre, unique(ligne(r$declarations_requises, "D04b", champ = "motif")$nombre_lignes)),
              list(2L, 0L, c(1L, 1L), 1L))
mX <- avec(function(b) { b$affiliations$salaire_reference <- NA_real_; b })   # D03c (X;H) sur AF1
r <- cb(mX)
verifier_egal("constat à choix (X;H) sans déclaration : chaque famille et chaque référentiel en attente, traitements admis X;H",
              paste(r$declarations_requises$rubrique, r$declarations_requises$cle, r$declarations_requises$traitements_admis),
              c(paste("exclusions", ns$FAMILLES_CALCUL, "X;H"), paste("hypotheses", ns$REFERENTIELS, "X;H")))
r <- cb(mX, declarations = list(hypotheses = hyp2("D03c")))
verifier("constat à choix couvert par l'hypothèse (deux référentiels) : hypotheses_defaut, aucune attente, aucun enjeu",
         identical(paste(r$hypotheses_defaut$motif, r$hypotheses_defaut$referentiel, r$hypotheses_defaut$nombre),
                   paste("D03c", ns$REFERENTIELS, 1L)) &&
           nrow(r$declarations_requises) == 0L && nrow(r$exclusions) == 0L && nrow(r$enjeu) == 0L && partition(r))
r <- cb(mX, declarations = list(exclusions = excl4("D03c")[1L, ], hypotheses = hyp2("D03c", "comptes_sociaux")))
verifier_egal("constat à choix partiellement déclaré : exclusion et hypothèse placées, le reste en attente",
              list(nrow(r$exclusions), nrow(r$hypotheses_defaut), paste(r$declarations_requises$cle),
                   unique(r$enjeu$action[r$enjeu$famille == "engagement"]),
                   unique(r$enjeu$action[r$enjeu$famille == "triangle"])),
              list(1L, 1L, c("triangle", "risque_en_cours", "regle_comptable", "solvabilite_2"), "exclure", "non_declaree"))
r <- cb(avec(function(b) { b$sinistres$date_instruction[1L] <- NA; b }))
verifier_egal("H;S (D13) sans déclaration : hypothèse attendue par référentiel, traitements admis H;S, pas de signalement",
              list(paste(r$declarations_requises$rubrique, r$declarations_requises$cle, r$declarations_requises$traitements_admis),
                   any(r$signalements$code == "D13")),
              list(paste("hypotheses", ns$REFERENTIELS, "H;S"), FALSE))
r_nd <- cb(pb, A0)
r <- cb(pb, A0, declarations = list(hypotheses = hyp2("D02b")))
verifier("D02b à un arrêté antérieur, hypothèse déclarée pour les deux référentiels : placée, appliquée à la vue (plus de visibilité non déterminée D02b ni de fille recensée)",
         identical(r$hypotheses_defaut$nombre, c(5L, 5L)) && !any(r$declarations_requises$motif == "D02b") &&
           identical(paste(r$vue$visibilite_non_determinee$table, r$vue$visibilite_non_determinee$motif),
                     c("affiliations D03g", "prestations D03g")) &&
           any(r_nd$vue$visibilite_non_determinee$motif == "D02b") && partition(r))
r <- cb(pb, A0, declarations = list(hypotheses = hyp2("D02b", "comptes_sociaux")))
verifier("D02b, hypothèse déclarée pour un seul référentiel : vue inchangée, l'autre référentiel attendu",
         identical(r$vue, r_nd$vue) && identical(r$declarations_requises$cle[r$declarations_requises$motif == "D02b"], "solvabilite_2"))
ctx_h <- function(b, arrete, declarations) {
  ctx <- ns$.contexte(b, d, list(date_extraction = A), arrete)
  ctx$declarations <- ns$.lire_declarations(declarations, d)
  ns$.refus_regle_b(ctx); ns$.visibilite_propre(ctx); ns$.regle_prealable(ctx); ns$.construire_vue(ctx)
  ctx
}
b <- avec(function(b) { b$evenements$date_saisie[2L] <- D("2024-05-01"); b$evenements$date_effet[2L] <- D("2024-06-15"); b })
verifier_egal("hypothèse de D02b appliquée : visibilité = max(saisie, effet) (événement saisi le 2024-05-01, effet le 2024-06-15)",
              c(ctx_h(b, D("2024-06-01"), list(hypotheses = hyp2("D02b")))$retenu$evenements[2L],
                ctx_h(b, D("2024-06-20"), list(hypotheses = hyp2("D02b")))$retenu$evenements[2L]), c(FALSE, TRUE))
r <- cb(pb, A, declarations = list(hypotheses = hyp2("D02b")))
verifier("D02b à l'extraction : signalement, l'hypothèse déclarée est sans objet (aucune ligne d'hypothèse)",
         "D02b" %in% r$signalements$code && nrow(r$hypotheses_defaut) == 0L)

section("donnees : vue provisoire, orphelines, nombre_visibles et nombre_dossiers (réserves Q, QC)")
r <- cb(avec(function(b) { b$catastrophes <- rbind(b$catastrophes, b$catastrophes); b }), A0)
verifier("règle P empêchée sur une table refusée en portée table (D01a de catastrophes) : vue non provisoire",
         !r$vue$provisoire && identical(ligne(r$controles_non_executes, "D02b", "catastrophes")$cause, "D01a"))
r <- cb(avec(function(b) { b$evenements$date_effet <- as.character(b$evenements$date_effet); b }), A0)
verifier("règle P empêchée sur une table lue par la vue (evenements.date_effet de type incompatible) : vue provisoire",
         isTRUE(r$vue$provisoire) && identical(ligne(r$controles_non_executes, "D02b", "evenements", "date_saisie")$cause,
                                               "type_incompatible"))
r <- cb(avec(function(b) { b$dossiers$id_sinistre[3L] <- "SIX"; b }))
verifier("dossier sans sinistre : aucun D04a ; D04b R de dossiers et refus induits des tables qui visent dossiers",
         !any(r$controles$code == "D04a") && identical(refus(r, "D04b", "dossiers", "id_sinistre")$identifiants, "DO3") &&
           refus(r, "D04b", "dossiers", "id_sinistre")$portee == "table" &&
           all(c("beneficiaires", "rentes", "evenements", "prestations", "evaluations_gestion") %in%
                 refus(r, "refus_induit", NULL)$table))
r <- cb(avec(function(b) { b$prestations$montant[3L] <- -750; b }), D("2025-03-15"))
x <- refus(r, "D09", "prestations", "montant")
verifier_egal("critère 5 (§ 2.5) : refus D09 d'une prestation saisie après l'arrêté : compté, nombre_visibles = 0, dossier connu compté",
              list(x$nombre, x$nombre_visibles, x$identifiants, x$nombre_dossiers), list(1L, 0L, "PR3", 1L))
b <- avec(function(b) { b$assures <- rbind(b$assures, b$assures[1L, ]); b })
verifier_egal("nombre_visibles (Q8 a) : assures visibles s'ils sont référencés par une ligne visible (CT1 en vigueur depuis 2015 ; avant : invisible)",
              c(refus(cb(b, A0), "D01a", "assures")$nombre_visibles, refus(cb(b), "D01a", "assures")$nombre_visibles,
                refus(cb(b, D("2014-06-30")), "D01a", "assures")$nombre_visibles), c(1L, 1L, 0L))
r <- cb(avec(function(b) { b$sinistres <- rbind(b$sinistres, b$sinistres[1L, ]); b }))
verifier_egal("nombre_dossiers d'un refus : dossiers rattachés distincts (D01a de SI1 : DO1, DO2 ; evenements induit : trois ; cotisations, evaluations_gestion : aucun)",
              c(refus(r, "D01a", "sinistres")$nombre_dossiers, refus(r, "refus_induit", "evenements")$nombre_dossiers,
                refus(r, "refus_induit", "evaluations_gestion")$nombre_dossiers), c(2L, 3L, 0L))

section("donnees : enjeu (§ 4, M151, M152)")
verifier("COMPOSANTES_ENJEU : liste fermée de huit composantes, dix couples (composante, unite) distincts",
         nrow(ns$COMPOSANTES_ENJEU) == 10L && length(unique(ns$COMPOSANTES_ENJEU$composante)) == 8L &&
           !anyDuplicated(ns$COMPOSANTES_ENJEU[, c("composante", "unite")]) &&
           all(ns$COMPOSANTES_ENJEU$unite %in% c("euro", "euro_par_an", "euro_par_jour")))
invariants_enjeu <- function(r) {
  e <- r$enjeu
  couple <- paste(e$composante, e$unite) %in% paste(ns$COMPOSANTES_ENJEU$composante, ns$COMPOSANTES_ENJEU$unite)
  na_ssi_cause <- identical(is.na(e$montant), !is.na(e$cause))
  m <- e[e$motif != "ensemble" & !is.na(e$montant), ]
  ens <- e[e$motif == "ensemble" & !is.na(e$montant), ]
  if (nrow(m) == 0L) return(all(couple) && na_ssi_cause && all(e$poste == "ensemble") && nrow(ens) == 0L)
  somme <- aggregate(montant ~ famille + action + garantie + composante + unite, data = m, FUN = sum)
  k <- match(paste(ens$famille, ens$action, ens$garantie, ens$composante, ens$unite),
             paste(somme$famille, somme$action, somme$garantie, somme$composante, somme$unite))
  all(couple) && na_ssi_cause && all(e$poste == "ensemble") &&
    all(is.na(k) | abs(ens$montant) <= abs(somme$montant[k]) + 1e-9)
}
r <- cb(gX, declarations = list(exclusions = excl4("D10b")))
x <- ligne(r$enjeu, "D10b", "dossiers", "id_garantie_souscrite", "motif")
x <- x[x$famille == "engagement" & x$garantie == "rente_education", ]
verifier_egal("critère 3 (§ 4.6) : dossier exclu (D10b, DO2 rente d'éducation) : paiements (PR3) et rente en vigueur (EV5 ; fin de service programmée en 2036)",
              paste(x$composante, x$unite, x$montant, x$nombre_dossiers, x$nombre_valeurs),
              c("paiements_cumules euro 750 1 1", "rente_annuelle_en_vigueur euro_par_an 3000 1 1"))
verifier_egal("exclusions : nombre de dossiers rattachés (D10b : DO2)", unique(r$exclusions$nombre_dossiers), 1L)
verifier("enjeu : action déclarée (exclure) pour chaque famille, aucune non_declaree ; invariants (§ 4.5)",
         setequal(unique(r$enjeu$action), "exclure") && setequal(unique(r$enjeu$famille), ns$FAMILLES_CALCUL) &&
           invariants_enjeu(r))
r0x <- cb(gX)
verifier("enjeu sans déclaration (M152) : action non_declaree pour chaque famille, mêmes montants qu'avec la déclaration",
         setequal(unique(r0x$enjeu$action), "non_declaree") &&
           identical(r0x$enjeu$montant, r$enjeu$montant) && invariants_enjeu(r0x))
verifier_egal("critère 2 (§ 4.6) : bilan identique avec ou sans T18 (hors tables_absentes)",
              cb(avec(function(b) { b$garanties_souscrites$date_effet[3L] <- D("2025-06-01"); b$evaluations_gestion <- NULL; b }))[-11L],
              r0x[-11L])
r <- cb(oX)
x <- ligne(r$enjeu, "D04a", "prestations", "id_dossier", "motif")
x <- x[x$famille == "engagement" & x$garantie == "ensemble", ]
orph <- !(oX$prestations$id_dossier %in% oX$dossiers$id_dossier)
verifier_egal("critère 1 (§ 4.6) : prestations écartées (D04a) égales à un recalcul indépendant par jointure",
              list(x$composante, x$montant, x$nombre_valeurs, x$nombre_dossiers),
              list("prestations_ecartees", sum(oX$prestations$montant[orph]), sum(orph), 0L))
verifier("enjeu : une prestation orpheline n'a pas de garantie (non_rattache) ; table sans enjeu (designations) : aucune rangée",
         "non_rattache" %in% ligne(r$enjeu, "D04a", "prestations", NULL, "motif")$garantie &&
           !any(cb(avec(function(b) { b$designations$id_affiliation <- "AFX"; b }))$enjeu$table %in% "designations") &&
           "D04b" %in% cb(avec(function(b) { b$designations$id_affiliation <- "AFX"; b }))$declarations_requises$motif)
d2 <- avec(function(b) { b$garanties_souscrites$date_effet[3L] <- D("2025-06-01"); b$famille$date_naissance <- D("2025-03-01"); b })
r <- cb(d2)
x <- r$enjeu[r$enjeu$famille == "engagement" & r$enjeu$garantie == "ensemble" & r$enjeu$composante == "paiements_cumules", ]
verifier_egal("critère 5 (§ 4.6) : dossier touché par D02a (famille) et D10b compté une fois dans la rangée ensemble",
              paste(x$motif, x$montant, x$nombre_dossiers), c("D02a 60750 2", "D10b 750 1", "ensemble 60750 2"))
verifier("invariants de l'enjeu sur plusieurs bilans (couples fermés, NA si et seulement si cause, ensemble au plus la somme)",
         invariants_enjeu(r) && invariants_enjeu(cb(mb)) && invariants_enjeu(cb(db)) && invariants_enjeu(cb(pb, A0)) &&
           invariants_enjeu(cb(multi)))
e1 <- avec(function(b) { b$evenements <- rbind(b$evenements, transform(b$evenements[4L, ], id_evenement = "EV7",
                                                                       date_saisie = D("2025-02-05"))); b })
x <- cb(e1)$enjeu
x <- x[x$motif == "D01b" & x$famille == "engagement" & x$garantie == "deces", ]
verifier_egal("événement exclu seul (D01b, copie d'un fixation_capital) : montant propre en euros, capital fixé et paiements du dossier",
              paste(x$composante, x$unite, x$montant), c("paiements_cumules euro 60000", "capital_fixe euro 60000",
                                                         "montant_evenement euro 60000"))
e2 <- avec(function(b) { b$evenements <- rbind(b$evenements, transform(b$evenements[2L, ], id_evenement = "EV7",
                                                                       date_saisie = D("2024-06-15"))); b })
ij <- function(arrete) {
  x <- cb(e2, arrete)$enjeu
  x <- x[x$motif == "D01b" & x$famille == "engagement" & x$garantie == "incapacite", ]
  paste(x$composante, x$unite, x$montant, x$nombre_valeurs)
}
verifier_egal("indemnité journalière : en vigueur avant la sortie (2024-08-01), éteinte après (sortie du 2024-09-01) ; montant propre en euros par jour",
              list(ij(D("2024-08-01")), ij(A)),
              list(c("paiements_cumules euro 1240 1", "ij_en_vigueur euro_par_jour 40 1", "montant_evenement euro_par_jour 40 1"),
                   c("paiements_cumules euro 1240 1", "ij_en_vigueur euro_par_jour 0 0", "montant_evenement euro_par_jour 40 1")))
x <- cb(db)$enjeu
x <- x[x$table %in% "cotisations" & x$famille == "engagement" & x$garantie == "deces", ]
verifier_egal("cotisations exclues (D01b, copie d'une émission) : émises nettes et encaissées, sans dossier",
              paste(x$composante, x$montant, x$nombre_dossiers), c("cotisations_emises_nettes 1000 0", "cotisations_encaissees 0 0"))
r <- cb(avec(function(b) { b$prestations$montant[1L] <- -5; b }))
x <- ligne(r$enjeu, "D09", "prestations", "montant", "motif")
verifier("critère 4 (§ 4.6) : une composante qui lit une colonne refusée vaut NA, cause renseignée, et figure dans controles_non_executes",
         all(is.na(x$montant)) && all(x$cause == "D09") &&
           identical(ligne(r$controles_non_executes, "prestations_ecartees", "prestations", "montant")$cause, "D09") &&
           invariants_enjeu(r))
verifier_egal("enjeu : tri reproductible (lignes et colonnes des tables dans un autre ordre)",
              cb(lapply(d2, function(t) if (nrow(t) > 1L) t[rev(seq_len(nrow(t))), rev(names(t)), drop = FALSE] else t))$enjeu,
              r <- cb(d2)$enjeu)

section("donnees : reprise de (ii-b) (décisions D4 à D7, réserves d'actuary Q2 à Q11, constats M1 à M3, m1 à m3)")
valider <- function(declarations, b = base_ref, arrete = A) motif_de(cb(b, arrete, declarations = declarations))
r <- cb(mX, declarations = list(exclusions = excl4("D03c"), hypotheses = hyp2("D03c")))
verifier("M1 : constat couvert par l'exclusion et par l'hypothèse : placé sur un seul axe (exclusions, l'exclusion l'emporte)",
         nrow(r$exclusions) == 4L && nrow(r$hypotheses_defaut) == 0L && nrow(r$declarations_requises) == 0L && partition(r))
r <- cb(mX, declarations = list(exclusions = excl4("D03c")[1L, ], hypotheses = hyp2("D03c")))
verifier("M1 : constat couvert par l'hypothèse avec une exclusion partielle : hypotheses_defaut seul, aucun enjeu",
         nrow(r$exclusions) == 0L && nrow(r$hypotheses_defaut) == 2L && nrow(r$declarations_requises) == 0L &&
           nrow(r$enjeu) == 0L && partition(r))
b13 <- avec(function(b) { b$sinistres$date_instruction[1L] <- NA; b })   # D13 (H;S) sur SI1
r <- cb(b13, declarations = list(hypotheses = hyp2("D13", valeur = "signalement")))
verifier("D4 : signalement déclaré pour les deux référentiels : signalements, ni hypothèse ni attente",
         "D13" %in% r$signalements$code && nrow(r$hypotheses_defaut) == 0L && nrow(r$declarations_requises) == 0L && partition(r))
r <- cb(b13, declarations = list(hypotheses = c(hyp2("D13", "comptes_sociaux", "signalement"), hyp2("D13", "solvabilite_2"))))
verifier("D4 : signalement pour un référentiel, hypothèse pour l'autre : signalements et hypotheses_defaut (solvabilite_2)",
         "D13" %in% r$signalements$code && identical(r$hypotheses_defaut$referentiel, "solvabilite_2") &&
           nrow(r$declarations_requises) == 0L && partition(r))
r <- cb(b13, declarations = list(hypotheses = hyp2("D13", "comptes_sociaux", "signalement")))
verifier("D4 : signalement pour un seul référentiel : l'autre attendu, constat signalé",
         "D13" %in% r$signalements$code && identical(r$declarations_requises$cle, "solvabilite_2") && partition(r))
for (cas in list(
  list("signalement d'un motif sans S (D03c)", list(hypotheses = hyp2("D03c", valeur = "signalement"))),
  list("signalement et autre ligne pour un même (motif, referentiel)",
       list(hypotheses = c(hyp2("D13", "comptes_sociaux", "signalement"),
                           list(list(motif = "D13", referentiel = "comptes_sociaux", poste = "pm", valeur = "v"))))),
  list("D10 sans sous-cas en exclusion (m1)", list(exclusions = excl4("D10"))),
  list("D10 sans sous-cas en hypothèse (m1)", list(hypotheses = hyp2("D10"))),
  list("exclusion de D03a pour la famille triangle (Q2)", list(exclusions = excl4("D03a"))),
  list("exclusion de D12 pour la famille triangle (Q2)", list(exclusions = excl4("D12")[2L, ])),
  list("D02b, valeurs différentes entre référentiels (Q4)",
       list(hypotheses = list(list(motif = "D02b", referentiel = "comptes_sociaux", poste = "tous", valeur = "max"),
                              list(motif = "D02b", referentiel = "solvabilite_2", poste = "tous", valeur = "autre")))),
  list("D02b, poste autre que tous (Q4)",
       list(hypotheses = list(list(motif = "D02b", referentiel = "comptes_sociaux", poste = "pm", valeur = "max")))),
  list("D03g, signalement déclaré (Q4)", list(hypotheses = hyp2("D03g", valeur = "signalement"))),
  list("D03g, action conserver (D5)", list(exclusions = excl4("D03g", "conserver"))),
  list("délai de D03g négatif (D5)", list(seuils = list(d03g_delai_jours = list(prestations = -1)))),
  list("délai de D03g pour une table hors D03g (D5)", list(seuils = list(d03g_delai_jours = list(cotisations = 30)))),
  list("délai de D03g non entier (D5)", list(seuils = list(d03g_delai_jours = list(prestations = 1.5)))),
  list("délai de D03g non nommé (D5)", list(seuils = list(d03g_delai_jours = list(30)))))) {
  verifier_egal(paste0("declarations, ", cas[[1L]], " : plan_invalide"), valider(cas[[2L]]), "plan_invalide")
}
verifier_egal("declarations admises : D02b même valeur pour les deux référentiels, délai de D03g nommé par table",
              valider(list(hypotheses = hyp2("D02b"), seuils = list(d03g_delai_jours = list(prestations = 30, contrats = 0)))),
              "aucun")
r <- cb(mb)
x <- ligne(r$declarations_requises, "D03a", champ = "motif")
verifier_egal("Q2 : D03a sans déclaration : exclusion attendue pour trois familles (triangle traité S, hors attente et hors enjeu)",
              list(x$cle[x$rubrique == "exclusions"], any(r$enjeu$motif == "D03a" & r$enjeu$famille == "triangle")),
              list(setdiff(ns$FAMILLES_CALCUL, "triangle"), FALSE))
r <- cb(mb, declarations = list(exclusions = excl4("D03a")[-2L, ]))
verifier("Q2 : D03a exclu pour les trois autres familles : couvert, aucune attente pour D03a",
         identical(unique(ligne(r$exclusions, "D03a", champ = "motif")$famille), setdiff(ns$FAMILLES_CALCUL, "triangle")) &&
           !any(r$declarations_requises$motif == "D03a") && partition(r))
seuils_requis <- function(r) sort(r$declarations_requises$cle[r$declarations_requises$rubrique == "seuils"])
r <- cb(pb, A0)
verifier_egal("Q6 : sans déclaration à un arrêté antérieur, le délai de D03g est attendu par table (rubrique seuils, seule ligne seuils)",
              seuils_requis(r), c("d03g_delai_jours$affiliations", "d03g_delai_jours$prestations"))
verifier("Q6 : aucune ligne seuils à l'extraction (D03g signalé) ni sur les bases sans D03g",
         all(vapply(list(cb(pb), cb(mb), cb(db), cb(multi), cb(oX), cb(mb, A0)), function(r) length(seuils_requis(r)) == 0L, NA)))
dec_h <- function(delai) list(hypotheses = c(hyp2("D02b"), hyp2("D03g")), seuils = list(d03g_delai_jours = delai))
r <- cb(pb, A0, declarations = dec_h(list(prestations = 30, affiliations = 0)))
ctx <- ctx_h(pb, A0, dec_h(list(prestations = 30, affiliations = 0)))
verifier("D5 : hypothèse de D03g déclarée avec délai : appliquée à la vue (PR1 : ouverture de DO3 le 2024-03-07 + 30 jours ; fin d'AF1 : date_fin + 0), placée, vue non provisoire",
         identical(ctx$date_g$prestations[1L], as.numeric(D("2024-04-06"))) &&
           identical(ctx$partie_h$affiliations[1L], as.numeric(D("2026-06-30"))) && isTRUE(ctx$retenu$prestations[1L]) &&
           identical(ligne(r$hypotheses_defaut, "D03g", champ = "motif")$nombre, c(2L, 2L)) &&
           nrow(r$declarations_requises) == 0L && !r$vue$provisoire && partition(r))
ctx <- ctx_h(pb, D("2024-04-01"), dec_h(list(prestations = 30, affiliations = 0)))
verifier("D5 : hypothèse de D03g : la prestation n'est pas visible avant la date retenue (2024-04-01 < 2024-04-06)",
         identical(ctx$retenu$prestations[1L], FALSE))
r <- cb(pb, A0, declarations = dec_h(list(affiliations = 0)))
verifier("D5 : hypothèse de D03g sans le délai d'une table : ses lignes restent de visibilité non déterminée, l'hypothèse n'est pas placée pour elle, délai attendu",
         identical(seuils_requis(r), "d03g_delai_jours$prestations") &&
           identical(ligne(r$hypotheses_defaut, "D03g", champ = "motif")$nombre, c(1L, 1L)) &&
           any(r$vue$visibilite_non_determinee$table == "prestations" & r$vue$visibilite_non_determinee$motif == "D03g") &&
           r$vue$provisoire && partition(r))
r <- cb(pb, A0, declarations = list(hypotheses = hyp2("D02b"), exclusions = excl4("D03g")))
ctx <- ctx_h(pb, A0, list(hypotheses = hyp2("D02b"), exclusions = excl4("D03g")))
x <- r$enjeu[r$enjeu$table %in% "prestations" & r$enjeu$motif == "D03g" & r$enjeu$garantie == "ensemble", ]
verifier("D5 : exclusion de D03g pour les quatre familles : la ligne sort de la vue, placée dans exclusions, enjeu chiffré (PR1 : 1240), aucune attente",
         identical(ctx$retenu$prestations[1L], FALSE) && nrow(ligne(r$exclusions, "D03g", champ = "motif")) == 4L &&
           identical(unique(x$action), "exclure") && identical(unique(x$montant), 1240) &&
           nrow(r$declarations_requises) == 0L && !r$vue$provisoire && partition(r))
r <- cb(pb, A0, declarations = list(hypotheses = hyp2("D02b"), exclusions = excl4("D03g")[1:3, ]))
x <- ligne(r$declarations_requises, "D03g", champ = "motif")
verifier("D5 : exclusion de D03g incomplète (trois familles) : non appliquée ni placée, la famille manquante, les référentiels et le délai attendus",
         !any(r$exclusions$motif == "D03g") && identical(unique(x$cle[x$rubrique == "exclusions"]), "regle_comptable") &&
           setequal(x$cle[x$rubrique == "hypotheses"], ns$REFERENTIELS) && length(seuils_requis(r)) == 2L &&
           r$vue$provisoire && !any(r$enjeu$motif == "D03g" & r$enjeu$action == "exclure"))
provisoire_requiert <- function(r) !(nrow(r$vue$visibilite_non_determinee) > 0L) || nrow(r$declarations_requises) > 0L
verifier("Q5 : une vue provisoire par visibilité non déterminée a toujours une déclaration requise (bases et arrêtés du lot)",
         all(vapply(list(pb, mb, db, multi, oX, gX, b13, mX), function(b) {
           all(vapply(list(A0, D("2024-05-15")), function(a) provisoire_requiert(cb(b, a)), NA))
         }, NA)) && provisoire_requiert(cb(pb, A0, declarations = list(hypotheses = hyp2("D02b")))))
b8 <- avec(function(b) { b$sinistres$date_saisie[1L] <- D("2025-07-15"); b$beneficiaires <- rbind(b$beneficiaires, b$beneficiaires); b })
verifier_egal("Q8 (a), M2 : la fille d'une ligne invisible n'est pas comptée visible, avec ou sans hypothèse de D02b (bénéficiaire de DO1, sinistre saisi après l'arrêté)",
              lapply(list(NULL, list(hypotheses = hyp2("D02b"))), function(dec) {
                x <- refus(cb(b8, A0, declarations = dec), "D01a", "beneficiaires")
                c(x$nombre_visibles, x$nombre_dossiers)
              }), list(c(0L, 0L), c(0L, 0L)))
b10 <- avec(function(b) { b$garanties_souscrites$date_effet[2L] <- D("2024-06-01")   # D10b sur DO3 (incapacite)
  b$sinistres$date_saisie[2L] <- D("2024-03-04"); b$prestations$date_saisie[1L] <- NA; b })   # D02b de SI2, D03g de PR1
r <- cb(b10, A0, declarations = list(hypotheses = hyp2("D02b")))
x <- ligne(r$enjeu, "D10b", "dossiers", champ = "motif")
x <- x[x$famille == "engagement" & x$garantie == "incapacite", ]
verifier_egal("Q8 (b) : porteur dont une prestation est de visibilité non déterminée (PR1, D03g) : montant et nombre_valeurs NA, cause visibilite_non_determinee",
              paste(x$composante, x$montant, x$nombre_valeurs, x$cause),
              c("paiements_cumules NA NA visibilite_non_determinee", "ij_en_vigueur 0 0 NA"))
verifier("Q8 (b) : la visibilité non déterminée ne va pas dans controles_non_executes ; invariants de l'enjeu",
         !any(r$controles_non_executes$cause == "visibilite_non_determinee") && invariants_enjeu(r))
r <- cb(avec(function(b) { b$garanties_souscrites$date_effet[3L] <- D("2025-06-01"); b$evenements$montant[4L] <- -60000; b }))
x <- r$enjeu[r$enjeu$motif == "D10b" & r$enjeu$famille == "engagement" & r$enjeu$garantie == "ensemble", ]
verifier_egal("Q10 : composante empêchée sans porteur (evenements.montant refusé, aucun dossier incapacite ni décès) : NA avec sa cause, dans controles_non_executes",
              list(paste(x$composante, x$montant, x$cause), ligne(r$controles_non_executes, "ij_en_vigueur", "evenements", "montant")$cause),
              list(c("paiements_cumules 750 NA", "capital_fixe NA D09", "rente_annuelle_en_vigueur NA D09", "ij_en_vigueur NA D09"), "D09"))
r <- cb(avec(function(b) { b$garanties_souscrites$date_effet[3L] <- D("2025-06-01"); b$garanties_souscrites$code_garantie[3L] <- "zzz"; b }))
x <- r$enjeu[r$enjeu$motif == "D10b" & r$enjeu$famille == "engagement", ]
verifier_egal("Q10 : garantie dont le code est refusé : non_rattache, composantes 2 à 4 NA (cause hors_domaine) ; paiements NA par le refus D10a de prestations qu'entraîne le code",
              paste(x$garantie, x$composante, x$montant, x$cause),
              c("non_rattache paiements_cumules NA D10a", "ensemble paiements_cumules NA D10a", "ensemble capital_fixe NA hors_domaine",
                "ensemble rente_annuelle_en_vigueur NA hors_domaine", "ensemble ij_en_vigueur NA hors_domaine"))
rechute <- function(nouvelle_ouverture) avec(function(b) {
  b$evenements <- rbind(b$evenements, transform(b$evenements[2L, ], id_evenement = "EV7", date_saisie = D("2024-06-15")),
                        transform(b$evenements[3L, ], id_evenement = "EV8", type_evenement = "rechute", date_effet = D("2024-10-01"),
                                  date_saisie = D("2024-10-02"), motif = NA, justificatif = NA))
  if (nouvelle_ouverture) {
    b$evenements <- rbind(b$evenements, transform(b$evenements[2L, ], id_evenement = "EV9", date_effet = D("2024-10-01"),
                                                  date_saisie = D("2024-10-03"), montant = 45))
  }
  b })
ij_de <- function(b) { x <- cb(b)$enjeu
  x <- x[x$motif == "D01b" & x$famille == "engagement" & x$garantie == "incapacite" & x$composante == "ij_en_vigueur", ]
  c(x$montant, x$nombre_valeurs) }
verifier_egal("Q11 : indemnité journalière éteinte par la sortie ; une rechute seule ne la rallume pas, une nouvelle ouverture postérieure la rallume (45 par jour)",
              list(ij_de(rechute(FALSE)), ij_de(rechute(TRUE))), list(c(0, 0L), c(45, 1L)))
r <- cb(avec(function(b) { b$sinistres <- rbind(b$sinistres, b$sinistres[1L, ]); b }))
y <- r$enjeu[r$enjeu$motif == "D01a" & r$enjeu$garantie == "ensemble", ]
verifier_egal("D7 : refus d'une clé (D01a de SI1) : le refus induit qu'il entraîne ne bloque pas son enjeu, la cascade est chiffrée",
              paste(y$composante, y$montant, y$nombre_dossiers, y$cause),
              c("paiements_cumules 60750 2 NA", "capital_fixe 60000 2 NA", "rente_annuelle_en_vigueur 3000 2 NA", "ij_en_vigueur 0 2 NA"))
r <- cb(avec(function(b) { b$sinistres <- rbind(b$sinistres, b$sinistres[1L, ]); b$affiliations$salaire_reference <- NA_real_; b }))
y <- r$enjeu[r$enjeu$motif == "D03c" & r$enjeu$famille == "engagement" & r$enjeu$garantie == "ensemble", ]
verifier("D7 : le refus induit issu d'un autre écart (D01a de sinistres) bloque l'enjeu d'une exclusion (D03c) qui lit dossiers",
         all(is.na(y$montant)) && all(y$cause == "refus_induit") && invariants_enjeu(r))
x <- cb(db)$enjeu
x <- x[x$motif == "ensemble" & x$famille == "engagement", ]
verifier_egal("M3 : rangée ensemble : un dossier rattaché par une prestation écartée n'est compté que pour prestations_ecartees, sans rangée de cotisations pour sa garantie",
              list(x$nombre_dossiers[x$garantie == "ensemble" & x$composante %in% c("paiements_cumules", "prestations_ecartees")],
                   x$composante[x$garantie == "incapacite"]),
              list(c(0L, 1L), "prestations_ecartees"))
b3 <- avec(function(b) { b$garanties_souscrites$date_effet[3L] <- D("2025-06-01")
  p <- b$prestations[rep(3L, 3L), ]; p$id_prestation <- c("PR3", "PR4", "PR5"); p$montant <- c(0.1, 0.2, 0.3)
  b$prestations <- rbind(b$prestations[1:2, ], p); b })
verifier_egal("m3 : sommes de l'enjeu indépendantes de l'ordre des lignes (0,1 + 0,2 + 0,3 en double précision)",
              cb(lapply(b3, function(t) if (nrow(t) > 1L) t[rev(seq_len(nrow(t))), , drop = FALSE] else t)), cb(b3))
