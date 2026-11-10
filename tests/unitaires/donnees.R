# Tests unitaires du module `donnees` (R/donnees.R). Exécuté par tests/test_unitaires.R : le
# package est installé et chargé, le harnais est sourcé, `racine` est défini.
# Bases construites à la main : une base de référence valide (aucun constat), puis une
# altération par cas, qui déclenche un code de contrôle ou un défaut.

ns <- asNamespace("provie")
# Causes de controles_non_executes rendues par tous les appels de controler_base() du fichier,
# relues par le test d'exhaustivité de .RANGS_CAUSES (M185, #36, fin du fichier).
causes_vues <- character(0)
controler_base <- function(...) {
  r <- provie::controler_base(...)
  causes_vues <<- union(causes_vues, r$controles_non_executes$cause)
  r
}
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
# cb() : bilan sans les déclarations attendues hors constat (rubrique conventions, seuils qui
# conditionnent D02c : nombre_lignes NA), présentes dans tout bilan qui n'a pas ces
# déclarations ; elles sont testées à part, sur controler_base() (section D02c et D07 (c)).
sans_requises_hors_constat <- function(r) {
  dr <- r$declarations_requises[!is.na(r$declarations_requises$nombre_lignes), , drop = FALSE]
  rownames(dr) <- NULL
  r$declarations_requises <- dr
  r
}
cb <- function(b, arrete = A, ...) sans_requises_hors_constat(controler_base(b, arrete, ...))
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
# sans conventions ni seuils : D02c (âge, quatre tables) et D07 (c) (rentes, dossiers) non
# exécutés, cause declaration_absente
verifier("base de référence : aucun constat ; seuls les contrôles non implémentés, D03h non lisible et D02c (âge) et D07 (c) sans déclaration sont non exécutés ; aucune table absente",
         nrow(r0$controles) == 0L && nrow(r0$refus_tables) == 0L && length(r0$tables_absentes) == 0L &&
           all(r0$controles_non_executes$cause %in% c("non_implemente", "non_lisible", "declaration_absente")) &&
           sum(r0$controles_non_executes$cause == "declaration_absente") == 6L &&
           nrow(r0$controles_non_executes) == nrow(ni_present(base_ref)) + 1L + 6L)
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
ecrits <- unique(unlist(lapply(c(".regle_forme", ".regles_generiques", ".regle_date_programmable", ".regles_propres",
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
# le code est écrit n'est admise que pour le sous-cas D09 (seuils).
cle3 <- function(x) paste(x$code, x$table, x$colonne)
verifier_egal("CONTROLES_NON_IMPLEMENTES : aucune règle écrite n'y figure", intersect(cle3(ni), cle3(tr)), character(0))
verifier_egal("CONTROLES_NON_IMPLEMENTES : colonne NA sur une table écrite seulement pour D09 (seuils)",
              unique(ni$code[is.na(ni$colonne) & paste(ni$code, ni$table) %in% paste(tr$code, tr$table)]),
              "D09")
verifier("CONTROLES_NON_IMPLEMENTES : codes connus, tables et colonnes du dictionnaire, sans doublon",
         {
           all(ni$code %in% d$controles$code | sub("[a-z]$", "", ni$code) %in% d$defauts$code | ni$code %in% d$defauts$code) &&
             all(ni$table %in% d$tables$table) &&
             all(is.na(ni$colonne) | paste(ni$table, ni$colonne) %in% paste(d$colonnes$table, d$colonnes$colonne)) &&
             !anyDuplicated(ni[, c("code", "table", "colonne")])
         })
verifier("D02c (âge) : écrit, plus déclaré ; D02b, D03g, D04a, D04b, somme_parts : écrits, plus déclarés",
         !any(c("D02c", "D02b", "D03g", "D04a", "D04b", "somme_parts") %in% ni$code))
# Report déclaré à la fermeture de #18 (décision du mainteneur ; #34, #18) :
# CONTROLES_NON_IMPLEMENTES ne contient que les contrôles reportés, liste figée : D03d, D07 (a)
# et (b) (evenements, colonne NA), D08, D09 aux seuils, D10 (d) à (f), D11, D12, D14.
verifier_egal("CONTROLES_NON_IMPLEMENTES : seuls les contrôles reportés (#34, #18)",
              cle3(ni), c("D03d assures situation_familiale", "D07 evenements NA", "D08 sinistres NA",
                          "D09 parametres NA", "D09 affiliations NA", "D09 evenements NA", "D09 prestations NA",
                          "D09 cotisations NA", "D10d evenements NA", "D10e beneficiaires qualite", "D10f evenements NA",
                          "D11 sinistres date_survenance", "D12 evenements type_evenement", "D14 famille NA"))
r <- controler_base(base_ref, A, conventions = NULL)
verifier_egal("sans conventions : D02c (âge) et D07 (c) non exécutés, cause declaration_absente, colonne NA ; D07 (a) et (b) restent non_implemente",
              list(ligne(r$controles_non_executes, "D02c", NULL, NA)$table, unique(ligne(r$controles_non_executes, "D02c", NULL)$cause),
                   c(ligne(r$controles_non_executes, "D07", "rentes", NA)$cause, ligne(r$controles_non_executes, "D07", "dossiers", NA)$cause),
                   ligne(r$controles_non_executes, "D07", "evenements", NA)$cause),
              list(c("assures", "famille", "designations", "ayants_droit_sante"), "declaration_absente",
                   rep("declaration_absente", 2L), "non_implemente"))
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
# Revue finale, M1 : mois_echeance sans aucune valeur dans 1:12 (vecteur logique NA) ; le
# maximum du jour se lit par match(), une valeur par ligne : ni ligne fantôme (n = 1, diviseur
# de 12) ni avertissement de recyclage (n = 5, erreur sous warn = 2).
for (n in c(1L, 5L)) {
  r <- cb(avec(function(b) {
    b$contrats <- b$contrats[rep_len(1L, n), , drop = FALSE]
    b$contrats$id_contrat <- paste0("CT", c(1L, seq_len(n - 1L) + 2L))
    rownames(b$contrats) <- NULL
    b$contrats$mois_echeance <- NA_integer_
    b$contrats$jour_echeance[1L] <- 0L
    b
  }))
  x <- refus(r, "hors_domaine", "contrats", "jour_echeance")
  verifier(paste0("jour_echeance hors domaine, mois_echeance tous manquants, ", n, " contrat(s) : une ligne, CT1"),
           nrow(x) == 1L && x$nombre == 1L && x$identifiants == "CT1")
}
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
# #35 : .chevauchements, comparée à une énumération des paires sur des intervalles tirés
# (groupes, bornes manquantes, fin infinie, intervalles renversés, bornes égales : intervalle
# fermé) ; puis complexité, mesurée sans horloge (une durée dépend de la charge de la
# machine) : (1) travail de .chevauchements, somme des longueurs des arguments de ses appels
# aux opérations vectorielles de base (comparaisons, indexation, which, match, order...),
# de 2 000 à 8 000 groupes de 3 intervalles : rapport 4 si linéaire, 16 pour la boucle par
# groupe de 5c53ad4 (mesuré : 4,00 et 15,9) ; borne 6 ; (2) controler_base, sur 200 puis
# 800 garanties de 3 paramètres chacune (chacune sous un collège propre : un groupe par
# garantie), appelle .chevauchements le même nombre de fois, une fois par table sur toutes
# ses lignes (aucune boucle par garantie autour du contrôle).
chev_paires <- function(groupe, debut, fin) {
  n <- length(groupe)
  ok <- !is.na(groupe) & !is.na(debut) & !is.na(fin) & debut <= fin
  vapply(seq_len(n), function(a) ok[a] && any(ok & groupe %in% groupe[a] & seq_len(n) != a & debut <= fin[a] & debut[a] <= fin), TRUE)
}
set.seed(35)
ecarts_chev <- vapply(1:300, function(k) {
  n <- sample(0:25, 1L)
  g <- sample(c("a", "b", "c", NA), n, TRUE)
  d <- sample(c(0:10, NA, Inf, -Inf), n, TRUE)
  f <- ifelse(runif(n) < 0.3, Inf, d + sample(c(-3:8, NA), n, TRUE))
  !identical(ns$.chevauchements(g, d, f), chev_paires(g, d, f))
}, TRUE)
verifier("chevauchements : identique à l'énumération des paires sur 300 tirages (groupes, manquants, fin infinie, renversés)", !any(ecarts_chev))
# travail de .chevauchements : travail_de() de tests/harnais.R, aux opérations vectorielles
# de base que la fonction appelle
OPS_CHEV <- c("which", "match", "unique", "order", "rep", "c", "seq_along", "seq_len", "==", "!=", "<=", ">=",
              "<", ">", "&", "|", "!", "is.na", "[", "[<-", "length")
groupes_chev <- function(n) list(groupe = rep(sprintf("G%06d", seq_len(n)), each = 3L), debut = rep(c(0, 5, 20), n),
                                 fin = rep(c(10, 15, 30), n))
travail_chev <- vapply(c(2000L, 8000L), function(n) do.call(travail_de, c(list(ns$.chevauchements), groupes_chev(n), list(ops = OPS_CHEV))), 0)
verifier("performance : travail de .chevauchements de 2 000 à 8 000 groupes de 3 intervalles multiplié par moins de 6 (linéaire : 4 ; boucle par groupe : 16 ; #35)",
         travail_chev[2L] / travail_chev[1L] < 6)
perf_garanties <- function(n) {
  b <- base_ref
  gs <- b$garanties_souscrites[rep(3L, n), ]
  gs$id_garantie_souscrite <- sprintf("GX%06d", seq_len(n)); gs$college <- sprintf("C%06d", seq_len(n))
  pa <- b$parametres[rep(4:6, n), ]
  pa$id_garantie_souscrite <- rep(gs$id_garantie_souscrite, each = 3L)
  b$garanties_souscrites <- rbind(b$garanties_souscrites, gs); b$parametres <- rbind(b$parametres, pa)
  b
}
# longueurs des appels de .chevauchements par controler_base (trace(), comme regles_tracees())
appels_chev <- function(b) {
  .GlobalEnv$.appels_chev <- integer(0)
  suppressMessages(trace(".chevauchements", where = ns, print = FALSE, tracer = quote(
    .GlobalEnv$.appels_chev <- c(.GlobalEnv$.appels_chev, length(groupe)))))
  on.exit({ suppressMessages(untrace(".chevauchements", where = ns)); rm(".appels_chev", envir = .GlobalEnv) })
  cb(b)
  .GlobalEnv$.appels_chev
}
verifier_egal("performance : controler_base appelle .chevauchements une fois par table (garanties_souscrites, parametres) sur toutes ses lignes, à 200 comme à 800 garanties (#35)",
              lapply(c(200L, 800L), function(n) appels_chev(perf_garanties(n))),
              list(c(4L + 200L, 8L + 3L * 200L), c(4L + 800L, 8L + 3L * 800L)))

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
# à A0, la règle P empêchée sur contrats (date_effet de type incompatible) ajoute ses refus
# induits (D12 : contrats, et par les clés étrangères garanties_souscrites, cotisations) ;
# la règle B est inchangée. Exception propre aux bases à défaut de forme (M178 maintenue pour
# ce cas, M199) : un refus de valeur n'induit aucun refus (invariance testée sans exception,
# section #33)
sans_d12 <- function(x, champ) {
  x <- x[!(x[[champ]] == "refus_induit" & x$table %in% c("contrats", "garanties_souscrites", "cotisations")), , drop = FALSE]
  rownames(x) <- NULL
  x
}
verifier_egal("invariance en A (règle B) : controles identiques à deux arrêtés, hors les refus induits d'une règle P empêchée (D12, à A0 seulement)",
              list(sans_d12(r_a0$controles, "code"), any(r$controles$code == "refus_induit" & r$controles$table == "contrats")),
              list(r$controles, FALSE))
verifier_egal("invariance en A (règle B) : refus_tables (hors nombre_visibles et nombre_dossiers, comptes à l'arrêté, et hors D12) identiques",
              sans_d12(r_a0$refus_tables, "motif")[, !(names(r$refus_tables) %in% c("nombre_visibles", "nombre_dossiers"))],
              r$refus_tables[, !(names(r$refus_tables) %in% c("nombre_visibles", "nombre_dossiers"))])
verifier_egal("vue : date d'arrêté consignée", r_a0$vue$date_arrete, A0)

section("donnees : règle P (D02b, D03g) et vue à une date (règles I, 1, M156)")
verifier_egal("vue de la base de référence : sous-éléments, aucune visibilité non déterminée",
              list(names(r0$vue), nrow(r0$vue$visibilite_non_determinee), r0$vue$provisoire),
              list(c("date_arrete", "date_extraction", "visibilite_non_determinee", "provisoire"), 0L, FALSE))
verifier_egal("colonnes de vue$visibilite_non_determinee (origine : M202, #33)", names(r0$vue$visibilite_non_determinee),
              c("table", "colonne", "motif", "origine", "nombre", "identifiants"))
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
# v1.5 (#43, M216) : la fin d'AF1 (date_fin 2026-06-30 > A0, D03g sans hypothèse) est masquée de
# façon déterminée, et CA1 (saisie 2026-05-31 > A0, D02b sans hypothèse) invisible de façon
# déterminée : ni l'une ni l'autre n'est inscrite
verifier_egal("arrêté antérieur : visibilité non déterminée par table, colonne (partie de ligne ; NA : ligne entière) et motif, filles recensées (M156, D1) ; ligne ou partie invisible de façon déterminée non inscrite (v1.5, #43)",
              paste(x$table, x$colonne, x$motif, x$nombre, x$identifiants),
              c("contrats date_saisie_fin D02b 1 CT2", "sinistres NA D02b 1 SI2",
                "dossiers NA parente_non_determinee 1 DO3", "beneficiaires NA D02b 1 BE1", "evenements NA D02b 1 EV2",
                "evenements NA parente_non_determinee 2 EV1;EV3", "prestations NA D03g 1 PR1",
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
verifier("D3 : une date de visibilité refusée (D02c, SI2) rend la ligne de visibilité non déterminée à un arrêté antérieur ; la règle P s'exécute sur les autres lignes (détection partielle, cause D02c) ; les règles V de sinistres qui lisent date_saisie ou date_declaration comme valeur restent bloquées, cause D02c (D01b, D02a ; M169) (#33, M199, M200)",
         identical(ligne(r$controles_non_executes, "D02b", "sinistres", "date_saisie")$cause, "D02c") &&
           identical(ligne(r$controles_non_executes, c("D01b", "D02a"), "sinistres")$cause, rep("D02c", 3L)) &&
           isTRUE(r$vue$provisoire))
verifier_egal("D3, ordre (ADR 0010, quatorzième série, (b)) : les deux lignes D02c de SI2 dans visibilite_non_determinee, triées par origine (sinistres.date_declaration, puis sinistres.date_saisie)",
              r$vue$visibilite_non_determinee$origine[r$vue$visibilite_non_determinee$motif == "D02c"],
              c("sinistres.date_declaration", "sinistres.date_saisie"))
r <- cb(avec(function(b) { b$sinistres$date_saisie[2L] <- D("2027-01-05"); b$sinistres$date_declaration[2L] <- D("2027-01-02")
                           b$sinistres$date_instruction[1L] <- NA; b }), A0)
verifier_egal("D3 : une règle V de sinistres qui ne lit ces colonnes que pour la vue s'exécute sur SI1 (D13 détecté sur SI1, aucune ligne D13 dans controles_non_executes ; #33, M200)",
              list(ligne(r$controles, "D13", "sinistres")$identifiants, nrow(ligne(r$controles_non_executes, "D13", "sinistres"))),
              list("SI1", 0L))

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
verifier_egal("manquants qui ont un défaut au § 9 : détectés sur la vue, un constat par table (D03a : deux, X;H et S pour la famille triangle)",
              paste(x$code, x$table, x$colonne, x$identifiants),
              c("D03h garanties_souscrites taux_technique_tarif GS3;GS4", "D03a assures date_naissance AS2",
                "D03a assures date_naissance AS2", "D03c affiliations salaire_reference AF1", "D03b famille sexe ME1|2025-02-01",
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
              paste(x$code, x$table), c("D03h garanties_souscrites", "D03a assures", "D03a assures", "D03c affiliations"))
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
r <- cb(mX, declarations = list(exclusions = excl4("D03c")[1L, ]))
verifier_egal("constat à choix partiellement déclaré : exclusion placée, le reste en attente (une hypothèse avec l'exclusion : plan_invalide, D8)",
              list(nrow(r$exclusions), nrow(r$hypotheses_defaut), paste(r$declarations_requises$cle),
                   unique(r$enjeu$action[r$enjeu$famille == "engagement"]),
                   unique(r$enjeu$action[r$enjeu$famille == "triangle"])),
              list(1L, 0L, c("triangle", "risque_en_cours", "regle_comptable", "comptes_sociaux", "solvabilite_2"), "exclure",
                   "non_declaree"))
r <- cb(mX, declarations = list(hypotheses = hyp2("D03c", "comptes_sociaux")))
verifier_egal("constat à choix partiellement déclaré : hypothèse placée pour un référentiel, le reste en attente",
              list(nrow(r$exclusions), paste(r$hypotheses_defaut$referentiel), paste(r$declarations_requises$cle)),
              list(0L, "comptes_sociaux", c(ns$FAMILLES_CALCUL, "solvabilite_2")))
r <- cb(avec(function(b) { b$sinistres$date_instruction[1L] <- NA; b }))
verifier_egal("H;S (D13) sans déclaration : hypothèse attendue par référentiel, traitements admis H;S, pas de signalement",
              list(paste(r$declarations_requises$rubrique, r$declarations_requises$cle, r$declarations_requises$traitements_admis),
                   any(r$signalements$code == "D13")),
              list(paste("hypotheses", ns$REFERENTIELS, "H;S"), FALSE))
r_nd <- cb(pb, A0)
r <- cb(pb, A0, declarations = list(hypotheses = hyp2("D02b")))
verifier("D02b à un arrêté antérieur, hypothèse déclarée pour les deux référentiels : placée, appliquée à la vue (plus de visibilité non déterminée D02b ni de fille recensée)",
         identical(r$hypotheses_defaut$nombre, c(5L, 5L)) && !any(r$declarations_requises$motif == "D02b") &&
           identical(paste(r$vue$visibilite_non_determinee$table, r$vue$visibilite_non_determinee$motif), "prestations D03g") &&
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
verifier_egal("D8 : motif à traitement unique (D03c) déclaré en exclusion et en hypothèse : plan_invalide, quelles qu'en soient les familles (quatre, triangle seule) ou les référentiels",
              c(valider(list(exclusions = excl4("D03c"), hypotheses = hyp2("D03c")), mX),
                valider(list(exclusions = excl4("D03c")[2L, ], hypotheses = hyp2("D03c", "comptes_sociaux")), mX)),
              c("plan_invalide", "plan_invalide"))
verifier_egal("D8 : chacun des quatre motifs de la liste (D02a, D03a, D03c, D03f) déclaré dans les deux rubriques : plan_invalide (contrôle statique, sans constat) ; D03g n'y est plus (D11)",
              list(vapply(ns$.MOTIFS_TRAITEMENT_UNIQUE, function(m) {
                     valider(list(exclusions = excl4(m)[1L, ], hypotheses = hyp2(m)))
                   }, ""), valider(list(exclusions = excl4("D03g")[1L, ], hypotheses = hyp2("D03g")))),
              list(stats::setNames(rep("plan_invalide", 4L), c("D02a", "D03a", "D03c", "D03f")), "aucun"))
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
verifier("D5, D9 : exclusion de D03g pour les quatre familles : la ligne entière sort de la vue, placée dans exclusions, enjeu chiffré (PR1 : 1240) ; la fin d'AF1 (partie de ligne) attend l'hypothèse et son délai ; masquée de façon déterminée (date_fin 2026-06-30 > A0), elle n'est pas inscrite et la vue n'est pas provisoire (v1.5, #43)",
         identical(ctx$retenu$prestations[1L], FALSE) && nrow(ligne(r$exclusions, "D03g", champ = "motif")) == 4L &&
           identical(unique(x$action), "exclure") && identical(unique(x$montant), 1240) &&
           identical(paste(r$declarations_requises$rubrique, r$declarations_requises$cle, r$declarations_requises$traitements_admis),
                     c("hypotheses comptes_sociaux H", "hypotheses solvabilite_2 H", "seuils d03g_delai_jours$affiliations NA")) &&
           nrow(r$vue$visibilite_non_determinee) == 0L && !r$vue$provisoire && partition(r))
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
# règle B à trois valeurs (#42, M217) : le code refusé de GS3 est inconnu ; D10 (a) sur
# prestations.type_prestation (PR3, arrérage de la rente de GS3) est écarté de la détection,
# prestations n'est plus refusée en portée table et son paiement (750) est lu (avant #42 :
# paiements NA, cause D10a)
verifier_egal("Q10 : garantie dont le code est refusé : non_rattache, composantes 2 à 4 NA (cause hors_domaine) ; paiements chiffrés (750), D10 (a) de prestations écarté par la règle B à trois valeurs (#42)",
              paste(x$garantie, x$composante, x$montant, x$cause),
              c("non_rattache paiements_cumules 750 NA", "ensemble paiements_cumules 750 NA", "ensemble capital_fixe NA hors_domaine",
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

section("donnees : reprise de (ii-c) (décisions D8 à D10, réserves d'actuary Q2 à Q13, constats c1 à c3)")
for (cas in list(
  list("signalement de D03a (S pour la famille triangle seulement)", list(hypotheses = hyp2("D03a", valeur = "signalement"))),
  list("signalement de D11 (S cumulatif)", list(hypotheses = hyp2("D11", valeur = "signalement"))),
  list("signalement de D12 (S pour la famille triangle seulement)", list(hypotheses = hyp2("D12", valeur = "signalement"))),
  list("signalement de D02c (S cumulatif)", list(hypotheses = hyp2("D02c", valeur = "signalement"))),
  list("signalement de D09", list(hypotheses = hyp2("D09", valeur = "signalement"))),
  list("signalement de D10b (S automatique, c3)", list(hypotheses = hyp2("D10b", valeur = "signalement"))),
  list("hypothèse de D10b (S + X, c3)", list(hypotheses = hyp2("D10b"))),
  list("hypothèse de D10e (X, c3)", list(hypotheses = hyp2("D10e"))),
  list("exclusion de D10c (S, c3)", list(exclusions = excl4("D10c"))),
  list("exclusion de D10f (H ou S, c3)", list(exclusions = excl4("D10f"))),
  list("exclusion de D10a (R, c3)", list(exclusions = excl4("D10a"))))) {
  verifier_egal(paste0("declarations, ", cas[[1L]], " : plan_invalide"), valider(cas[[2L]]), "plan_invalide")
}
verifier_egal("declarations admises : signalement des motifs de la liste explicite (D05, D06, D07, D08, D10f, D13, D14), hypothèse de D10f, exclusion de D10b et D10e",
              c(vapply(ns$.MOTIFS_SIGNALEMENT, function(m) valider(list(hypotheses = hyp2(m, valeur = "signalement"))), ""),
                valider(list(hypotheses = hyp2("D10f"), exclusions = rbind(excl4("D10b"), excl4("D10e"))))),
              c(stats::setNames(rep("aucun", 7L), ns$.MOTIFS_SIGNALEMENT), "aucun"))
r <- cb(mb)
verifier("Q2 : D03a écrit dans signalements dès sa détection (part S de la famille triangle), sans déclaration ; attente pour X ou H (traitements admis X;H)",
         nrow(ligne(r$signalements, "D03a", "assures", "date_naissance")) == 1L &&
           identical(unique(ligne(r$declarations_requises, "D03a", champ = "motif")$traitements_admis), "X;H") && partition(r))
r <- cb(mb, declarations = list(hypotheses = hyp2("D03a")))
verifier("Q2 : D03a couvert par l'hypothèse : hypotheses_defaut et signalements (deux constats de même clé), aucune attente pour D03a",
         nrow(ligne(r$hypotheses_defaut, "D03a", champ = "motif")) == 2L && nrow(ligne(r$signalements, "D03a")) == 1L &&
           !any(r$declarations_requises$motif == "D03a") && partition(r))
c9 <- avec(function(b) { b$contrats$date_fin[1L] <- D("2026-06-30"); b$contrats$motif_fin[1L] <- "resiliation_adherent"; b })
# même partie, de date_fin au plus A0 : de visibilité non déterminée sans hypothèse (v1.5, #43)
c9b <- avec(function(b) { b$contrats$date_fin[1L] <- D("2025-03-01"); b$contrats$motif_fin[1L] <- "resiliation_adherent"; b })
r <- cb(c9, A0, declarations = list(exclusions = excl4("D03g")))
verifier_egal("D9 : fin de CT1 sans date de saisie (partie de ligne), exclusion de D03g déclarée : la partie n'est pas exclue (la ligne reste dans la vue), elle attend l'hypothèse et son délai ; date_fin 2026-06-30 > A0 : partie masquée de façon déterminée, non inscrite, vue non provisoire (v1.5, #43)",
              list(nrow(r$exclusions), nrow(r$enjeu),
                   paste(r$declarations_requises$rubrique, r$declarations_requises$cle, r$declarations_requises$traitements_admis),
                   paste(r$vue$visibilite_non_determinee$table, r$vue$visibilite_non_determinee$colonne), r$vue$provisoire,
                   isTRUE(ctx_h(c9, A0, list(exclusions = excl4("D03g")))$retenu$contrats[1L])),
              list(0L, 0L, c("hypotheses comptes_sociaux H", "hypotheses solvabilite_2 H", "seuils d03g_delai_jours$contrats NA"),
                   character(0), FALSE, TRUE))
r <- cb(c9b, A0, declarations = list(exclusions = excl4("D03g")))
verifier_egal("D9 : même partie, date_fin 2025-03-01 au plus A0 : de visibilité non déterminée, inscrite sous sa colonne, vue provisoire (v1.5, #43, V9)",
              list(paste(r$vue$visibilite_non_determinee$table, r$vue$visibilite_non_determinee$colonne), r$vue$provisoire),
              list("contrats date_saisie_fin", TRUE))
r <- cb(c9, A0, declarations = list(hypotheses = hyp2("D03g"), seuils = list(d03g_delai_jours = list(contrats = 10))))
verifier("D9 : la même partie sous l'hypothèse de D03g et son délai : connue à date_fin + délai, placée, vue non provisoire",
         identical(r$hypotheses_defaut$nombre, c(1L, 1L)) && nrow(r$declarations_requises) == 0L && !r$vue$provisoire &&
           identical(ctx_h(c9, A0, list(hypotheses = hyp2("D03g"), seuils = list(d03g_delai_jours = list(contrats = 10))))$partie_h$contrats[1L],
                     as.numeric(D("2026-07-10"))))
e4 <- avec(function(b) { b$evenements$date_saisie[4L] <- NA; b })   # EV4 fixation_capital, effet 2025-02-01
montant_ev4 <- function(r) { x <- r$enjeu
  x <- x[x$table %in% "evenements" & x$motif == "D03g" & x$famille == "engagement" & x$garantie == "ensemble" &
           x$composante == "montant_evenement" & x$unite == "euro", ]
  c(x$montant, x$nombre_valeurs) }
verifier_egal("Q4 : ligne exclue de D03g (EV4, effet 2025-02-01) : visible pour l'enjeu à sa date d'effet, non avant (A1 = 2025-01-25 : 0 ; A0 : 60000)",
              list(montant_ev4(cb(e4, D("2025-01-25"), declarations = list(exclusions = excl4("D03g")))),
                   montant_ev4(cb(e4, A0, declarations = list(exclusions = excl4("D03g"))))),
              list(c(0, 0L), c(60000, 1L)))
verifier_egal("Q8 : enjeu non déclaré d'un écart de D03g calculé pour montrer l'exposition avant le choix (même règle de visibilité : EV4 à A1 et à A0 ; PR1 à A0 et au 2024-06-15)",
              list(montant_ev4(cb(e4, D("2025-01-25"))), montant_ev4(cb(e4, A0)),
                   lapply(list(A0, D("2024-06-15")), function(a) {
                     x <- cb(avec(function(b) { b$prestations$date_saisie[1L] <- NA; b }), a)$enjeu
                     x <- x[x$motif == "D03g" & x$famille == "engagement" & x$garantie == "ensemble", ]
                     paste(x$action, x$montant, x$nombre_valeurs, x$cause)
                   })),
              list(c(0, 0L), c(60000, 1L), list("non_declaree 1240 1 NA", "non_declaree 0 0 NA")))
o5 <- avec(function(b) { b$prestations$id_dossier[1L] <- "DOX"; b$prestations$date_saisie[1:2] <- NA; b })
dec5 <- list(hypotheses = hyp2("D03g"), exclusions = excl4("D04a", "conserver"), seuils = list(d03g_delai_jours = list(prestations = 0)))
r <- cb(o5, A0, declarations = dec5)
verifier_egal("Q5 : hypothèse de D03g dont la date ne se calcule pas (PR1 orpheline sans date propre) : hors de hypotheses_defaut (PR2 seule), ligne non déterminée, exclusion attendue (X) pour chaque famille",
              list(r$hypotheses_defaut$nombre, paste(r$vue$visibilite_non_determinee$table, r$vue$visibilite_non_determinee$identifiants),
                   paste(r$declarations_requises$rubrique, r$declarations_requises$cle, r$declarations_requises$traitements_admis,
                         r$declarations_requises$nombre_lignes), r$vue$provisoire),
              list(c(1L, 1L), "prestations PR1", paste("exclusions", ns$FAMILLES_CALCUL, "X", 1L), TRUE))
provisoire_garanti <- function(r) !isTRUE(r$vue$provisoire) || nrow(r$declarations_requises) > 0L || nrow(r$refus_tables) > 0L
verifier("c1, Q5 : toute vue provisoire porte une déclaration requise ou un refus R (visibilité non déterminée, hypothèse non calculable, règle P empêchée : evenements.date_effet et sinistres.date_declaration de type incompatible ; dossiers.date_ouverture manquante : ligne de visibilité non déterminée, #33)",
         provisoire_requiert(r) && r$vue$provisoire && nrow(r$declarations_requises) > 0L &&
           all(vapply(list(cb(o5, A0, declarations = dec5),
                           cb(avec(function(b) { b$evenements$date_effet <- as.character(b$evenements$date_effet); b }), A0),
                           cb(avec(function(b) { b$sinistres$date_declaration <- as.character(b$sinistres$date_declaration); b }), A0),
                           cb(avec(function(b) { b$dossiers$date_ouverture[1L] <- NA; b }), A0),
                           cb(pb, A0), cb(pb, D("2024-05-15")), cb(c9b, A0, declarations = list(exclusions = excl4("D03g")))),
                      function(r) isTRUE(r$vue$provisoire) && provisoire_garanti(r), NA)))
f9 <- avec(function(b) { f2 <- b$famille; f2$date_saisie <- D("2025-03-01"); b$famille$lien <- "zzz"; b$famille <- rbind(b$famille, f2); b })
verifier_egal("Q9 : nombre_visibles de famille : seule la version valable à l'arrêté compte (ME1 hors domaine le 2025-02-01, remplacée le 2025-03-01 : 0 à A0, 1 au 2025-02-15)",
              c(refus(cb(f9, A0), "hors_domaine", "famille", "lien")$nombre_visibles,
                refus(cb(f9, D("2025-02-15")), "hors_domaine", "famille", "lien")$nombre_visibles), c(0L, 1L))
u11 <- avec(function(b) { b$garanties_souscrites$code_garantie <- 1:4
  b$evenements <- rbind(b$evenements, transform(b$evenements[5L, ], id_evenement = "EV7", date_saisie = D("2025-02-15")),
                        transform(b$evenements[2L, ], id_evenement = "EV8", date_saisie = D("2024-06-15"))); b })
x <- cb(u11)$enjeu
x <- x[x$table %in% "evenements" & x$motif == "D01b" & x$famille == "engagement" & x$garantie == "ensemble" &
         x$composante == "montant_evenement", ]
verifier_egal("Q11 : unité d'un événement de service lue sur id_rente, sans la garantie (code_garantie illisible) : euro_par_an 3000 (EV7, rente), euro_par_jour 40 (EV8, dossier incapacite)",
              paste(x$unite, x$montant, x$nombre_valeurs, x$cause), c("euro 0 0 NA", "euro_par_an 3000 1 NA", "euro_par_jour 40 1 NA"))
g13 <- avec(function(b) { b$garanties_souscrites$date_effet[3L] <- D("2025-06-01")   # D10b sur DO2
  b$evenements <- rbind(b$evenements,
    transform(b$evenements[6L, ], id_evenement = "EV7", date_effet = D("2025-06-01"), date_saisie = D("2025-06-02")),
    transform(b$evenements[5L, ], id_evenement = "EV8", date_effet = D("2025-09-01"), date_saisie = D("2025-09-02"), montant = 3500))
  b })
rente13 <- function(a) { x <- cb(g13, a)$enjeu
  x <- x[x$motif == "D10b" & x$famille == "engagement" & x$garantie == "rente_education" & x$composante == "rente_annuelle_en_vigueur", ]
  c(x$montant, x$nombre_valeurs) }
verifier_egal("Q13 : rente éteinte par fin_service (2025-06-01), rallumée par une nouvelle ouverture postérieure (2025-09-01, 3500 par an)",
              list(rente13(D("2025-07-01")), rente13(A)), list(c(0, 0L), c(3500, 1L)))
verifier("Q12, Q13 : définitions des composantes 3 et 4 : règle d'ordre du § 4.2 (réouverture et rechute)",
         grepl("dernier dans l'ordre", ns$COMPOSANTES_ENJEU$definition[3L], fixed = TRUE) &&
           grepl("rechute suivie d'une nouvelle ouverture", ns$COMPOSANTES_ENJEU$definition[4L], fixed = TRUE))
d01a <- function(t, i, f = identity) {
  x <- cb(avec(function(b) { b[[t]] <- rbind(b[[t]], f(b[[t]][i, ])); b }))$enjeu
  x <- x[x$motif == "D01a" & x$table %in% t & x$garantie == "ensemble", ]
  paste(x$composante, x$unite, x$montant, x$cause)
}
verifier_egal("D10 : le doublon de clé qui constitue l'écart ne bloque pas son enjeu (dossiers, evenements, prestations, cotisations, rentes dupliqués à l'identique : chiffrés ; la rente RE1 doublée comptée une fois, M1)",
              list(d01a("dossiers", 1L), d01a("evenements", 4L), d01a("prestations", 1L), d01a("cotisations", 1L),
                   d01a("rentes", 1L)),
              list(c("paiements_cumules euro 60000 NA", "capital_fixe euro 60000 NA", "rente_annuelle_en_vigueur euro_par_an 0 NA",
                     "ij_en_vigueur euro_par_jour 0 NA"),
                   c("paiements_cumules euro 60000 NA", "capital_fixe euro 60000 NA", "rente_annuelle_en_vigueur euro_par_an 0 NA",
                     "ij_en_vigueur euro_par_jour 0 NA", "montant_evenement euro 60000 NA", "montant_evenement euro_par_an 0 NA",
                     "montant_evenement euro_par_jour 0 NA"),
                   "prestations_ecartees euro 1240 NA",
                   c("cotisations_emises_nettes euro 1000 NA", "cotisations_encaissees euro 0 NA"),
                   c("paiements_cumules euro 750 NA", "capital_fixe euro 0 NA", "rente_annuelle_en_vigueur euro_par_an 3000 NA",
                     "ij_en_vigueur euro_par_jour 0 NA")))
verifier_egal("D10 : doublons qui divergent sur une colonne lue : la composante est sans valeur, cause D01a (garantie de DO1 divergente : composantes 2 à 4 ; montant de PR1 divergent : prestations_ecartees), les autres chiffrées",
              list(d01a("dossiers", 1L, function(x) transform(x, id_garantie_souscrite = "GS4")),
                   d01a("prestations", 1L, function(x) transform(x, montant = 1300))),
              list(c("paiements_cumules euro 60000 NA", "capital_fixe euro NA D01a", "rente_annuelle_en_vigueur euro_par_an NA D01a",
                     "ij_en_vigueur euro_par_jour NA D01a"),
                   "prestations_ecartees euro NA D01a"))
r <- cb(avec(function(b) { b$prestations <- rbind(b$prestations, b$prestations[1L, ]); b$affiliations$salaire_reference <- NA_real_; b }))
y <- r$enjeu[r$enjeu$motif == "D03c" & r$enjeu$famille == "engagement" & r$enjeu$garantie == "ensemble", ]
verifier("D10 : un autre refus direct (D01a de prestations) bloque toujours l'enjeu d'un autre écart (D03c) qui lit la table",
         identical(y$cause[y$composante == "paiements_cumules"], "D01a") && invariants_enjeu(r))

section("donnees : seconde reprise de (ii-c) (décisions D11 et D12, constat M1, réserves Q4, Q-b, Q2 (b), performance)")
# D11 : X et H de D03g déclarés ensemble : X pour toutes les lignes entières, H pour les parties de ligne
dec11 <- list(hypotheses = hyp2("D03g"), exclusions = rbind(excl4("D04a", "conserver"), excl4("D03g")),
              seuils = list(d03g_delai_jours = list(prestations = 0)))
r <- cb(o5, A0, declarations = dec11)
verifier_egal("D11 : X et H de D03g ensemble (PR1 orpheline sans date propre, PR2) : les deux lignes entières exclues, aucune hypothèse placée, aucune attente, vue non provisoire",
              list(ligne(r$exclusions, "D03g", champ = "motif")$nombre_lignes, nrow(r$hypotheses_defaut), nrow(r$declarations_requises),
                   r$vue$provisoire, partition(r)),
              list(rep(2L, 4L), 0L, 0L, FALSE, TRUE))
c11 <- avec(function(b) { b$contrats$date_fin[1L] <- D("2026-06-30"); b$contrats$motif_fin[1L] <- "resiliation_adherent"
                          b$prestations$date_saisie[2L] <- NA; b })
r <- cb(c11, A0, declarations = list(hypotheses = hyp2("D03g"), exclusions = excl4("D03g"),
                                     seuils = list(d03g_delai_jours = list(contrats = 10))))
r2 <- cb(c11, A0, declarations = list(hypotheses = hyp2("D03g"), exclusions = excl4("D03g")))
verifier_egal("D11 : X et H ensemble, ligne entière (PR2) et partie de ligne (fin de CT1) : la ligne exclue, la partie sous l'hypothèse ; sans délai pour contrats, la partie attend son délai (date_fin 2026-06-30 > A0 : masquée de façon déterminée, non inscrite, v1.5, #43)",
              list(ligne(r$exclusions, "D03g", champ = "motif")$nombre_lignes, r$hypotheses_defaut$nombre, nrow(r$declarations_requises),
                   r$vue$provisoire, paste(r2$declarations_requises$rubrique, r2$declarations_requises$cle),
                   paste(r2$vue$visibilite_non_determinee$table, r2$vue$visibilite_non_determinee$colonne)),
              list(rep(1L, 4L), c(1L, 1L), 0L, FALSE, "seuils d03g_delai_jours$contrats", character(0)))
# Q2 (b) : ME1 orpheline sans date propre (non calculable par elle-même), BE1 sa fille sans date de saisie
q2 <- avec(function(b) { b$famille$id_sinistre <- NA_character_; b$famille$date_saisie <- as.Date(NA)
                         b$beneficiaires$date_saisie <- as.Date(NA); b })
r <- cb(q2, A0, declarations = list(hypotheses = hyp2("D03g"), seuils = list(d03g_delai_jours = list(famille = 0, beneficiaires = 0))))
nd <- r$vue$visibilite_non_determinee
verifier_egal("Q2 (b) : sous l'hypothèse de D03g, la fille non calculable à cause de sa parente (BE1) n'attend aucune exclusion propre : parente_non_determinee ; seule ME1 attend X",
              list(unique(r$declarations_requises$nombre_lignes), unique(r$declarations_requises$traitements_admis),
                   nd$motif[nd$table == "famille"], nd$motif[nd$table == "beneficiaires"], nrow(r$hypotheses_defaut)),
              list(1L, "X", "D03g", "parente_non_determinee", 0L))
r <- cb(q2, A0, declarations = list(hypotheses = hyp2("D03g"), exclusions = excl4("D03g"),
                                    seuils = list(d03g_delai_jours = list(famille = 0, beneficiaires = 0))))
verifier("Q2 (b) : l'exclusion de D03g déclarée avec l'hypothèse (D11) résout la parente et sa fille",
         nrow(r$declarations_requises) == 0L && !r$vue$provisoire && nrow(r$vue$visibilite_non_determinee) == 0L)
# Q4 : la clé étrangère refusée qui constitue l'écart ne bloque pas son enjeu
r <- cb(avec(function(b) { b$dossiers$id_sinistre[3L] <- "SIX"; b$evenements$id_sinistre[2L] <- "SIX"; b }))
x <- r$enjeu[r$enjeu$motif == "D04b" & r$enjeu$table %in% "dossiers" & r$enjeu$garantie == "ensemble", ]
verifier_egal("Q4 : D04b sur dossiers.id_sinistre d'un dossier incapacite en service (DO3) : ij_en_vigueur chiffré (40 par jour), sans cause ; le lien n'est pas résolu",
              paste(x$composante, x$montant, x$cause),
              c("paiements_cumules 1240 NA", "capital_fixe 0 NA", "rente_annuelle_en_vigueur 0 NA", "ij_en_vigueur 40 NA"))
r <- cb(avec(function(b) { b$dossiers$id_sinistre[3L] <- "SIX"; b }))
x <- r$enjeu[r$enjeu$motif == "D04b" & r$enjeu$table %in% "dossiers" & r$enjeu$garantie == "ensemble", ]
verifier_egal("Q4 : le refus d'une autre colonne lue (evenements.id_dossier hors domaine) bloque toujours",
              x$cause[x$composante == "ij_en_vigueur"], "hors_domaine")
# Q-b : la cascade d'un écart D01a n'est pas chiffrée quand la table de l'écart porte un autre refus direct
r <- cb(avec(function(b) { b$sinistres <- rbind(b$sinistres, b$sinistres[1L, ]); b$sinistres$id_assure[2L] <- NA; b }))
x <- r$enjeu[r$enjeu$motif == "D01a" & r$enjeu$famille == "ensemble" & r$enjeu$garantie == "ensemble", ]
verifier_egal("Q-b : D01a de sinistres et manquant_obligatoire de sinistres.id_assure : l'autre refus direct bloque la cascade (composantes 1 à 4 sans valeur)",
              paste(x$composante, x$montant, x$cause),
              paste(ns$COMPOSANTES_ENJEU$composante[1:4], NA, "refus_induit"))
# D12 (M178, maintenue pour le défaut de forme par M199) : règle P empêchée par un défaut de
# forme à un arrêté antérieur sur une table lue par la vue : refus induit de portée table. Un
# refus de valeur (d12$dossiers : dossiers.date_ouverture manquante) n'en induit aucun : la
# ligne est de visibilité non déterminée (#33, section suivante)
d12 <- list(evenements = avec(function(b) { b$evenements$date_effet <- as.character(b$evenements$date_effet); b }),
            sinistres = avec(function(b) { b$sinistres$date_declaration <- as.character(b$sinistres$date_declaration); b }),
            dossiers = avec(function(b) { b$dossiers$date_ouverture[1L] <- NA; b }))
origine_d12 <- function(r, t) refus(r, "refus_induit", t)$origine
verifier_egal("D12 : défaut de forme : refus induit de portée table, origine la colonne qui empêche la règle P (evenements.date_effet, sinistres.date_declaration), propagé aux filles ; refus de valeur (dossiers.date_ouverture manquante) : aucun refus induit (#33, M199)",
              list(origine_d12(cb(d12$evenements, A0), "evenements"), origine_d12(cb(d12$sinistres, A0), "sinistres"),
                   origine_d12(cb(d12$sinistres, A0), "dossiers"), refus(cb(d12$sinistres, A0), "refus_induit", "sinistres")$portee,
                   any(cb(d12$dossiers, A0)$refus_tables$motif == "refus_induit")),
              list("evenements.date_effet", "sinistres.date_declaration", "sinistres", "table", FALSE))
verifier("D12 : à l'arrêté égal à l'extraction (vue totale), aucun refus induit ; la règle P empêchée garde sa cause d'origine",
         all(vapply(d12, function(b) !any(cb(b)$refus_tables$motif == "refus_induit"), NA)) &&
           identical(ligne(cb(d12$evenements, A0)$controles_non_executes, "D02b", "evenements", "date_saisie")$cause,
                     "type_incompatible"))
# invariant de la vue provisoire (spécification v1.3, § 3.2 ; #33) : provisoire si et seulement
# si visibilite_non_determinee n'est pas vide ou une règle P a été empêchée par un défaut de
# forme (refus induit de portée table d'origine « table.colonne ») ; chaque ligne de
# visibilite_non_determinee a sa justification : D02b ou D03g, une ligne de
# declarations_requises du motif (origine NA) ; motif de refus, la ligne de refus_tables de
# même table, colonne (celle de l'origine) et motif ; parente_non_determinee, une parente
# (lien de la règle 1) de visibilité non déterminée (origine NA)
liens_vue <- ns$.liens_visibilite(d)
invariant_vue <- function(r) {
  nd <- r$vue$visibilite_non_determinee
  rt <- r$refus_tables
  p_forme <- rt$motif == "refus_induit" & grepl(".", rt$origine, fixed = TRUE)
  justifiee <- vapply(seq_len(nrow(nd)), function(i) {
    m <- nd$motif[i]
    if (m %in% c("D02b", "D03g")) return(is.na(nd$origine[i]) && any(r$declarations_requises$motif == m))
    if (m == "parente_non_determinee") {
      return(is.na(nd$origine[i]) && any(liens_vue$table_cible[liens_vue$table == nd$table[i]] %in% nd$table))
    }
    o <- strsplit(nd$origine[i], ".", fixed = TRUE)[[1L]]
    !is.na(nd$origine[i]) && o[1L] == nd$table[i] && nrow(ligne(rt, m, o[1L], o[2L], "motif")) == 1L
  }, NA)
  identical(r$vue$provisoire, nrow(nd) > 0L || any(p_forme)) && all(rt$portee[p_forme] == "table") && all(justifiee)
}
cas_d12 <- list(cb(d12$evenements, A0), cb(d12$sinistres, A0), cb(d12$dossiers, A0), cb(multi, A0),
                cb(d12$sinistres, D("2024-05-15")), cb(o5, A0, declarations = dec5), cb(q2, A0, declarations =
                  list(hypotheses = hyp2("D03g"), seuils = list(d03g_delai_jours = list(famille = 0, beneficiaires = 0)))),
                cb(pb, A0), cb(c9b, A0, declarations = list(exclusions = excl4("D03g"))))
verifier("D12, #33 : toute vue provisoire l'est par une visibilité non déterminée justifiée ou par une règle P empêchée par un défaut de forme (invariant réécrit, spécification v1.3, § 3.2)",
         all(vapply(cas_d12, function(r) isTRUE(r$vue$provisoire) && invariant_vue(r), NA)))

section("donnees : refus de valeur sur une colonne lue par la vue, portée ligne (#33, M199 à M204)")
# Un refus de valeur identifié par ligne (manquant_obligatoire, hors_domaine, chaine_vide, D02c)
# sur une colonne lue par la vue (colonne de visibilité, ou lue par une règle P) fait passer la
# ligne, à un arrêté antérieur à l'extraction, en visibilité non déterminée (motif : code du
# refus ; origine : « table.colonne »), sans refus induit (spécification v1.3, § 2.2).
v33 <- list(
  date_ouverture = d12$dossiers,                                                                        # DO1
  gs_effet = avec(function(b) { b$garanties_souscrites$date_effet[1L] <- NA; b }),                      # GS1
  ev_type = avec(function(b) { b$evenements$type_evenement[1L] <- "zzz"                                 # EV1
                               b$evenements$date_saisie[2L] <- D("2024-05-01"); b }),                   # D02b sur EV2
  ev_motif = avec(function(b) { b$evenements$motif[3L] <- ""; b }),                                     # EV3, chaine_vide
  si_saisie = avec(function(b) { b$sinistres$date_saisie[2L] <- D("2027-01-05"); b }),                  # SI2, D02c
  ct_fin = avec(function(b) { b$contrats$date_fin[1L] <- D("9999-12-31")                                # CT1, partie
                              b$contrats$motif_fin[1L] <- "resiliation_adherent"; b }),
  pr_reglement = avec(function(b) { b$prestations$date_reglement[2L] <- NA; b }),                       # PR2
  co_mouvement = avec(function(b) { b$cotisations$date_mouvement[1L] <- NA; b }),                       # CO1
  si_instruction = avec(function(b) { b$sinistres$date_instruction[1L] <- D("2027-03-01"); b }))        # SI1, partie
r33 <- lapply(v33, cb, arrete = A0)
nd_de <- function(r) with(r$vue$visibilite_non_determinee, paste(table, colonne, motif, origine, nombre, identifiants))
# contexte complet jusqu'à la vue (règle B, refus, règle P, vue), sans déclaration
ctx_complet <- function(b, arrete, declarations = NULL) {
  ctx <- ns$.contexte(b, d, list(date_extraction = A), arrete)
  ctx$declarations <- ns$.lire_declarations(declarations, d)
  ctx$conventions <- ns$.lire_conventions(NULL)
  for (f in c(".regle_forme", ".regle_domaine", ".regle_cles", ".refus_induits", ".refus_regle_b", ".regle_p",
              ".construire_vue")) ns[[f]](ctx)
  ctx
}
r <- r33$date_ouverture
verifier_egal("#33, critère 1 : dossiers.date_ouverture[1] manquante, à A0 : seule la ligne manquant_obligatoire (portée colonne) dans refus_tables ; DO1 non déterminée (origine dossiers.date_ouverture), ses filles sous parente_non_determinee ; DO2 et DO3 retenus ; vue provisoire ; declarations_requises de la base sans défaut",
              list(paste(r$refus_tables$table, r$refus_tables$colonne, r$refus_tables$motif, r$refus_tables$portee), nd_de(r),
                   which(ctx_complet(v33$date_ouverture, A0)$retenu$dossiers), r$vue$provisoire,
                   identical(r$declarations_requises, cb(base_ref, A0)$declarations_requises)),
              list("dossiers date_ouverture manquant_obligatoire colonne",
                   c("dossiers NA manquant_obligatoire dossiers.date_ouverture 1 DO1",
                     "beneficiaires NA parente_non_determinee NA 1 BE1", "evenements NA parente_non_determinee NA 1 EV4",
                     "prestations NA parente_non_determinee NA 1 PR2"), 2:3, TRUE, TRUE))
r <- r33$gs_effet
verifier_egal("#33, critère 2 et D-2 : garanties_souscrites.date_effet[1] manquante (colonne de visibilité que ne lit aucune règle P), à A0 : GS1 non déterminée, avec ses parametres et ses dossiers (et leurs filles) ; GS2 à GS4 retenues ; vue provisoire",
              list(nd_de(r), which(ctx_complet(v33$gs_effet, A0)$retenu$garanties_souscrites), r$vue$provisoire),
              list(c("garanties_souscrites NA manquant_obligatoire garanties_souscrites.date_effet 1 GS1",
                     "parametres NA parente_non_determinee NA 2 GS1|age_fin_garantie|\\N|NA;GS1|taux_capital|\\N|NA",
                     "dossiers NA parente_non_determinee NA 1 DO1", "beneficiaires NA parente_non_determinee NA 1 BE1",
                     "evenements NA parente_non_determinee NA 1 EV4", "prestations NA parente_non_determinee NA 1 PR2"),
                   2:4, TRUE))
r <- r33$ev_type
verifier_egal("#33, critère 3 (Q5, logique de Kleene) : evenements.type_evenement[1] hors domaine (colonne lue par D02b), à A0 : EV1, saisi après sa date d'effet, a un verdict de D02b déterminé (faux) quel que soit son type : évalué, visible, hors de visibilite_non_determinee ; D02b détecté sur EV2 ; aucune ligne écartée, donc aucune ligne D02b dans controles_non_executes (M200)",
              list(nd_de(r), ctx_complet(v33$ev_type, A0)$retenu$evenements[1L], ligne(r$controles, "D02b", "evenements")$identifiants,
                   nrow(ligne(r$controles_non_executes, "D02b", "evenements"))),
              list("evenements NA D02b NA 1 EV2", TRUE, "EV2", 0L))
r <- r33$ct_fin
ctx <- ctx_complet(v33$ct_fin, A0)
verifier_egal("#33, critère 3, partie de ligne : contrats.date_fin[1] hors domaine (9999-12-31, lue par D03g), à A0 : seule la partie est masquée et recensée sous la colonne date_saisie_fin ; CT1 reste dans la vue ; D03g gardé dans controles_non_executes, cause hors_domaine",
              list(nd_de(r), ctx$retenu$contrats[1L], ns$.valeurs_vue(ctx, "contrats", "date_fin")[1L],
                   ligne(r$controles_non_executes, "D03g", "contrats", "date_saisie_fin")$cause, r$vue$provisoire),
              list("contrats date_saisie_fin hors_domaine contrats.date_fin 1 CT1", TRUE, as.Date(NA), "hors_domaine", TRUE))
r <- r33$ev_motif
verifier_egal("#33, Q5 (logique de Kleene) : evenements.motif[3] chaîne vide (EV3, sortie, saisi après sa date d'effet), à A0 : verdict de D02b déterminé (faux) : visible (nombre_visibles 1 sous chaine_vide et hors_domaine), aucune ligne non déterminée, aucune ligne D02b dans controles_non_executes, vue non provisoire",
              list(paste(r$refus_tables$motif, r$refus_tables$nombre_visibles), nrow(r$vue$visibilite_non_determinee),
                   nrow(ligne(r$controles_non_executes, "D02b", "evenements")), r$vue$provisoire),
              list(c("chaine_vide 1", "hors_domaine 1"), 0L, 0L, FALSE))
# type ou motif refusé qui peut changer la visibilité (Q5) : EV1 et EV2 de type hors domaine,
# saisis avant leur date d'effet (EV1 : 2025-09-01, postérieure à A0 ; EV2 : 2024-05-30,
# antérieure) ; EV3 (sortie, programmable selon le motif) à motif vide, saisi avant sa date
# d'effet (2025-09-01)
ev_vise <- avec(function(b) {
  b$evenements$type_evenement[1L] <- "zzz"; b$evenements$date_effet[1L] <- D("2025-09-01")
  b$evenements$type_evenement[2L] <- "zzz"; b$evenements$date_saisie[2L] <- D("2024-05-01")
  b$evenements$motif[3L] <- ""; b$evenements$date_effet[3L] <- D("2025-09-01"); b })
r33$ev_vise <- cb(ev_vise, A0)
verifier_egal("#33, quatre motifs de refus de valeur (manquant_obligatoire, hors_domaine, chaine_vide, D02c) sur une colonne lue par la vue, à A0 : la ligne (ou la partie) seule non déterminée, sous le code et son origine, aucun refus induit (critère 2 de #33 ; chaine_vide et hors_domaine sur une colonne de texte lue par D02b, aucune colonne de date n'admettant de chaîne : type ou motif refusé d'une ligne saisie avant sa date d'effet, Q5 ; EV3 figure sous chaque couple (motif, origine), cas limite 1)",
              lapply(r33[c("date_ouverture", "ct_fin", "ev_vise", "si_saisie")], function(r) {
                x <- r$vue$visibilite_non_determinee
                list(any(r$refus_tables$motif == "refus_induit"), paste(x$motif, x$origine, x$identifiants)[!is.na(x$origine)])
              }),
              list(date_ouverture = list(FALSE, "manquant_obligatoire dossiers.date_ouverture DO1"),
                   ct_fin = list(FALSE, "hors_domaine contrats.date_fin CT1"),
                   ev_vise = list(FALSE, c("chaine_vide evenements.motif EV3", "hors_domaine evenements.motif EV3",
                                           "hors_domaine evenements.type_evenement EV1;EV2")),
                   si_saisie = list(FALSE, "D02c sinistres.date_saisie SI2")))
r <- cb(ev_vise, A0, declarations = list(hypotheses = hyp2("D02b")))
verifier_egal("#33, Q5, sous l'hypothèse de D02b déclarée (visibilité = max(saisie, effet)) : le type ou le motif refusé ne change la visibilité que si la date d'effet est postérieure à A0 : EV1 et EV3 non déterminés, EV2 (effet antérieur à A0) visible",
              list(nd_de(r), ctx_complet(ev_vise, A0)$retenu$evenements[2L]),
              list(c("evenements NA chaine_vide evenements.motif 1 EV3", "evenements NA hors_domaine evenements.motif 1 EV3",
                     "evenements NA hors_domaine evenements.type_evenement 1 EV1"), FALSE))
r <- cb(avec(function(b) { b$evenements$date_effet[c(2L, 6L)] <- D("1900-01-01"); b }), A0)
verifier_egal("#33, Q5 : evenements.date_effet refusée (D02c, EV2 et EV6) : D02b ne vise pas un type programmable (EV6, fin_service age_limite : verdict déterminé), la valeur refusée ne change pas sa visibilité ; EV2 (ouverture_service, verdict inconnu) non déterminé et écarté de D02b (ligne partielle, cause D02c) ; EV6 seul refusé : aucune ligne écartée",
              list(refus(r, "D02c", "evenements", "date_effet")$identifiants, nd_de(r),
                   ligne(r$controles_non_executes, "D02b", "evenements", "date_saisie")$cause,
                   nrow(ligne(cb(avec(function(b) { b$evenements$date_effet[6L] <- D("1900-01-01"); b }), A0)$controles_non_executes,
                              "D02b", "evenements"))),
              list("EV2;EV6", "evenements NA D02c evenements.date_effet 1 EV2", "D02c", 0L))
verifier_egal("#33, Q5, partie de ligne : contrats.date_fin[1] hors domaine et date_saisie_fin lisible (2024-11-15, antérieure à A0 ; 2026-01-01, postérieure) : la fin est connue (ou inconnue) à sa date de saisie, date_fin ne la détermine pas : aucune ligne non déterminée, vue non provisoire",
              lapply(D(c("2024-11-15", "2026-01-01")), function(s) {
                r <- cb(avec(function(b) { b$contrats$date_fin[1L] <- D("9999-12-31"); b$contrats$motif_fin[1L] <- "resiliation_adherent"
                                           b$contrats$date_saisie_fin[1L] <- s; b }), A0)
                list(refus(r, "hors_domaine", "contrats", "date_fin")$identifiants, nrow(r$vue$visibilite_non_determinee), r$vue$provisoire,
                     nrow(ligne(r$controles_non_executes, "D03g", "contrats")))
              }),
              list(list("CT1", 0L, FALSE, 0L), list("CT1", 0L, FALSE, 0L)))
verifier_egal("#33, D-2 : colonnes de visibilité que ne lit aucune règle P (prestations.date_reglement, cotisations.date_mouvement ; sinistres.date_instruction, partie de ligne) : ligne non déterminée, ou partie seule, aucun refus induit",
              lapply(r33[c("pr_reglement", "co_mouvement", "si_instruction")],
                     function(r) list(nd_de(r), any(r$refus_tables$motif == "refus_induit"))),
              list(pr_reglement = list("prestations NA manquant_obligatoire prestations.date_reglement 1 PR2", FALSE),
                   co_mouvement = list("cotisations NA manquant_obligatoire cotisations.date_mouvement 1 CO1", FALSE),
                   si_instruction = list("sinistres date_instruction D02c sinistres.date_instruction 1 SI1", FALSE)))
r <- cb(avec(function(b) { b$prestations$date_saisie[2L] <- D("2025-08-01"); b$prestations$date_reglement[2L] <- NA; b }), A0)
verifier_egal("#33, logique à trois valeurs : prestation saisie après A0 (date lisible) à date_reglement manquante : invisible, hors de visibilite_non_determinee ; vue non provisoire",
              list(refus(r, "manquant_obligatoire", "prestations")$nombre_visibles, nrow(r$vue$visibilite_non_determinee),
                   r$vue$provisoire),
              list(0L, 0L, FALSE))
r <- cb(avec(function(b) { b$dossiers$id_sinistre[3L] <- NA; b }), A0)
verifier_egal("#33, clé exclue : dossiers.id_sinistre manquante (clé étrangère) : refus de portée table et refus induits de la règle B inchangés, aucune ligne de visibilité non déterminée",
              list(refus(r, "manquant_obligatoire", "dossiers")$portee, origine_d12(r, "beneficiaires"),
                   nrow(r$vue$visibilite_non_determinee)),
              list("table", "dossiers", 0L))
verifier_egal("#33, M169 : une règle V qui lit la colonne refusée comme valeur reste bloquée, cause = motif (D01b lit dossiers.date_ouverture ; D10b et D10c lisent garanties_souscrites.date_effet) ; une règle V qui ne la lit que pour la vue s'exécute (D10c, D10b sous dossiers.date_ouverture manquante)",
              list(ligne(r33$date_ouverture$controles_non_executes, "D01b", "dossiers")$cause,
                   ligne(r33$gs_effet$controles_non_executes, c("D10b", "D10c"), "dossiers")$cause,
                   nrow(ligne(r33$date_ouverture$controles_non_executes, c("D10b", "D10c"), "dossiers"))),
              list("manquant_obligatoire", c("manquant_obligatoire", "manquant_obligatoire"), 0L))
r <- cb(avec(function(b) { b$dossiers$date_ouverture[1L] <- NA; b$sinistres$canal_declaration[1L] <- "zzz"; b }), A0)
x <- r$enjeu[r$enjeu$motif == "hors_domaine" & r$enjeu$famille == "ensemble" & r$enjeu$composante == "paiements_cumules", ]
verifier_egal("#33, M201 : enjeu d'un écart du sinistre SI1 (canal hors domaine) : le porteur DO1, de visibilité non déterminée, sans valeur, cause visibilite_non_determinee ; DO2 chiffré (750) ; aucune composante empêchée par dossiers.date_ouverture",
              list(paste(x$garantie, x$montant, x$cause),
                   nrow(ligne(r$controles_non_executes, ns$COMPOSANTES_ENJEU$composante, "dossiers"))),
              list(c("deces NA visibilite_non_determinee", "rente_education 750 NA", "ensemble NA visibilite_non_determinee"), 0L))
verifier("#33, écart assumé (M203) : aucune déclaration requise ne naît d'un refus de valeur (exclusion déclarée reportée au dictionnaire 1.6, point P18)",
         !any(unlist(lapply(r33, function(r) r$declarations_requises$motif)) %in%
                c("manquant_obligatoire", "hors_domaine", "chaine_vide", "D02c")))
verifier("#33, invariant de la vue provisoire (spécification v1.3, § 3.2) sur les bases à refus de valeur, à A0 (vue provisoire, sauf ev_motif : Q5) et à l'extraction (vue totale, aucune ligne non déterminée)",
         all(vapply(r33, invariant_vue, NA)) &&
           identical(names(r33)[!vapply(r33, function(r) r$vue$provisoire, NA)], "ev_motif") &&
           all(vapply(v33, function(b) { r <- cb(b); !r$vue$provisoire && invariant_vue(r) }, NA)))
# cas limite 2 : EV4 sans date de saisie (D03g) et de date d'effet refusée (D02c, 2027-02-01)
g33 <- avec(function(b) { b$evenements$date_saisie[4L] <- NA; b$evenements$date_effet[4L] <- D("2027-02-01"); b })
rh <- cb(g33, A0, declarations = list(hypotheses = hyp2("D03g"), seuils = list(d03g_delai_jours = list(evenements = 0))))
rx <- cb(g33, A0, declarations = list(exclusions = excl4("D03g")))
verifier_egal("#33, cas limite 2 : refus de valeur (D02c sur evenements.date_effet) et D03g sur EV4 : sous H de D03g, la ligne reste non déterminée sous le motif du refus et attend l'exclusion (X) ; sous X, elle sort de la vue et le refus reste dans refus_tables",
              list(nd_de(rh), paste(rh$declarations_requises$rubrique, rh$declarations_requises$traitements_admis),
                   nrow(rx$vue$visibilite_non_determinee), refus(rx, "D02c", "evenements", "date_effet")$identifiants,
                   invariant_vue(rh), invariant_vue(rx)),
              list("evenements NA D02c evenements.date_effet 1 EV4", rep("exclusions X", 4L), 0L, "EV4", TRUE, TRUE))
# logique de Kleene de la règle P (avis d'`actuary`, #33) : un verdict déterminé malgré une
# valeur refusée est évalué normalement
m6 <- avec(function(b) { b$evenements$motif[2L] <- "zzz"; b$evenements$date_saisie[2L] <- D("2024-05-01")
                         b$evenements$date_effet[2L] <- D("2025-09-01"); b })
r <- cb(m6, A0); rh <- cb(m6, A0, declarations = list(hypotheses = hyp2("D02b")))
verifier_egal("#33, Kleene : motif hors domaine d'un type non programmable (EV2, ouverture_service) saisi avant sa date d'effet (2025-09-01) : D02b vrai quel que soit le motif, EV2 détecté ; sans hypothèse, hypothèse requise, aucune ligne partielle, et invisible de façon déterminée (effet postérieur à A0 : v1.5, #43), non inscrit (nombre_visibles 0) ; sous H, invisible (nombre_visibles 0)",
              list(ligne(r$controles, "D02b", "evenements")$identifiants, nd_de(r), unique(r$declarations_requises$motif),
                   nrow(ligne(r$controles_non_executes, "D02b", "evenements")), refus(r, "hors_domaine", "evenements", "motif")$nombre_visibles,
                   ligne(rh$controles, "D02b", "evenements")$identifiants,
                   nrow(rh$vue$visibilite_non_determinee), refus(rh, "hors_domaine", "evenements", "motif")$nombre_visibles),
              list("EV2", character(0), "D02b", 0L, 0L, "EV2", 0L, 0L))
r <- cb(avec(function(b) { b$evenements$motif[2L] <- "zzz"; b$evenements$date_saisie[2L] <- D("2027-01-05"); b }), A0)
verifier_egal("#33, Kleene : motif hors domaine d'un type non programmable et date de saisie refusée (EV2) : verdict inconnu par la saisie seule, la ligne figure sous l'origine evenements.date_saisie, pas sous evenements.motif (le motif ne joue que pour un type inconnu ou oui:<motifs>)",
              nd_de(r)[grepl("EV2", nd_de(r))], "evenements NA D02c evenements.date_saisie 1 EV2")
r <- cb(avec(function(b) { b$evenements$type_evenement[3L] <- "zzz"; b$evenements$motif[3L] <- "zzz"
                           b$evenements$date_saisie[3L] <- D("2024-08-01"); b }), A0)
verifier_egal("#33, lecture existentielle de (c) : type et motif refusés sur EV3, saisi avant son effet : le type pourrait être oui:<motifs>, la ligne figure sous chaque origine (cas limite 1)",
              nd_de(r), c("evenements NA hors_domaine evenements.motif 1 EV3", "evenements NA hors_domaine evenements.type_evenement 1 EV3"))
r <- cb(avec(function(b) { b$evenements$type_evenement[1L] <- "zzz"; b$evenements$date_saisie[1L] <- D("2027-02-01"); b }), A0)
verifier_egal("#33, D2 : type refusé et date de saisie refusée (D02c) sur EV1 : la saisie pourrait précéder l'effet, la ligne figure sous les deux origines",
              nd_de(r), c("evenements NA D02c evenements.date_saisie 1 EV1", "evenements NA hors_domaine evenements.type_evenement 1 EV1"))
r <- cb(avec(function(b) { b$evenements$type_evenement[1L] <- "zzz"; b$evenements$date_effet[1L] <- b$evenements$date_saisie[1L]; b }), A0)
verifier_egal("#33, bord : type refusé, saisie égale à la date d'effet (D02b exige une saisie strictement antérieure) : verdict faux, EV1 visible, aucune ligne non déterminée ni partielle",
              list(nrow(r$vue$visibilite_non_determinee), nrow(ligne(r$controles_non_executes, "D02b", "evenements"))), list(0L, 0L))
b5 <- avec(function(b) { b$evenements$type_evenement[1L] <- "zzz"; b$evenements$date_effet[1L] <- A0; b$evenements$date_saisie[1L] <- A0 - 30; b })
verifier_egal("#33, bord sous H de D02b : type refusé, saisie antérieure à un effet égal à A0 : visible dans tous les cas (max(saisie, effet) = A0), non déterminé sans H",
              list(nrow(cb(b5, A0, declarations = list(hypotheses = hyp2("D02b")))$vue$visibilite_non_determinee), nd_de(cb(b5, A0))),
              list(0L, "evenements NA hors_domaine evenements.type_evenement 1 EV1"))
verifier_egal("#33, hypothèse de D02b déclarée pour un seul référentiel : non appliquée (la vue est commune) ; EV2 de ev_vise (effet antérieur à A0) reste non déterminé",
              nd_de(cb(ev_vise, A0, declarations = list(hypotheses = hyp2("D02b", ns$REFERENTIELS[1L]))))[3L],
              "evenements NA hors_domaine evenements.type_evenement 2 EV1;EV2")
r <- cb(avec(function(b) { b$contrats$date_fin[1L] <- D("9999-12-31"); b$contrats$motif_fin[1L] <- "resiliation_adherent"
                           b$contrats$date_saisie_fin[1L] <- D("2027-03-01"); b }), A0)
verifier_egal("#33, lecture existentielle de (c) : date_fin et date_saisie_fin de CT1 toutes deux refusées : la partie figure sous chaque origine",
              nd_de(r), c("contrats date_saisie_fin D02c contrats.date_saisie_fin 1 CT1",
                          "contrats date_saisie_fin hors_domaine contrats.date_fin 1 CT1"))
r <- cb(avec(function(b) { b$sinistres$date_saisie[2L] <- NA; b$sinistres$date_declaration[2L] <- D("2027-01-02"); b }), A0)
verifier_egal("#33, Kleene : SI2 sans date de saisie (connue absente, D03g) et de date de déclaration refusée (D02c) : D02b (saisie avant la déclaration) est faux quelle que soit la déclaration ; aucune ligne D02b de sinistres dans controles_non_executes ; D03g détecté sur SI2",
              list(nrow(ligne(r$controles_non_executes, "D02b", "sinistres")), ligne(r$controles, "D03g", "sinistres")$identifiants),
              list(0L, "SI2"))
r <- cb(avec(function(b) { b$evenements$date_saisie[6L] <- D("2027-02-01"); b$evenements$type_evenement[2L] <- "zzz"
                           b$evenements$date_saisie[2L] <- D("2024-05-01"); b }), A0)
verifier_egal("#33, Kleene, cause de la ligne partielle : EV6 (programmable) de date de saisie refusée a un verdict de D02b déterminé (faux) et n'est pas écarté ; EV2, de type refusé et saisi avant son effet, l'est : cause hors_domaine (evenements.type_evenement), non D02c (colonne lue plus tôt, qui n'explique aucune ligne écartée)",
              ligne(r$controles_non_executes, "D02b", "evenements", "date_saisie")$cause, "hors_domaine")
# test par substitution (critère d'`actuary`, #33) : la valeur refusée d'une colonne lue par
# une règle P est remplacée par des valeurs admises contrastées ; si le statut de la ligne (ou
# de la partie) à A0 diffère entre les substitutions, elle doit être non déterminée sous un
# refus ; s'il est le même, hors refus restant, elle doit avoir ce statut
statut33 <- function(b, table, i, partie, declarations) {
  r <- cb(b, A0, declarations = declarations)
  id <- b[[table]][[1L]][i]
  nd <- r$vue$visibilite_non_determinee
  sel <- nd$table == table & (if (partie) nd$colonne %in% "date_saisie_fin" else is.na(nd$colonne)) &
    vapply(strsplit(nd$identifiants, ";", fixed = TRUE), function(z) id %in% z, NA)
  if (any(sel)) return(if (any(!is.na(nd$origine[sel]))) "nd_refus" else paste("nd", paste(sort(nd$motif[sel]), collapse = ",")))
  ctx <- ctx_complet(b, A0, declarations)
  if (!partie) return(if (ctx$retenu[[table]][i]) "visible" else "invisible")
  dh <- ctx$partie_h[[table]]
  sf <- as.numeric(b[[table]]$date_saisie_fin[i])
  if (!is.null(dh) && !is.na(dh[i])) sf <- dh[i]
  if (!is.na(sf) && sf <= as.numeric(A0)) "connue" else "inconnue"
}
# chaque cas : base, table, ligne, substitutions (valeurs admises de la ligne, colonne
# refusée comprise ; un type programmable selon le motif reçoit un motif qui le rend
# programmable), partie de ligne
sub_type <- list(list(type_evenement = "entree_incapacite"), list(type_evenement = "sortie", motif = "retraite"))
sub_type2 <- list(list(type_evenement = "ouverture_service"), list(type_evenement = "modification_montant"))
sub_motif <- list(list(motif = "reprise_travail"), list(motif = "retraite"))
sub_date <- function(col, x) lapply(D(x), function(z) stats::setNames(list(z), col))
effets <- avec(function(b) { b$evenements$date_effet[c(2L, 6L)] <- D("1900-01-01"); b })
ct_saisie <- function(s) avec(function(b) { b$contrats$date_fin[1L] <- D("9999-12-31"); b$contrats$motif_fin[1L] <- "resiliation_adherent"
                                            b$contrats$date_saisie_fin[1L] <- D(s); b })
# ouverture_service n'admet aucun motif (m6 : seule l'absence est admise) ; m6b : même cas sur
# suspension, type non programmable aux motifs justificatif_manquant et autre
m6b <- avec(function(b) { b$evenements$type_evenement[2L] <- "suspension"; b$evenements$motif[2L] <- "zzz"
                          b$evenements$montant[2L] <- NA; b$evenements$date_saisie[2L] <- D("2024-05-01")
                          b$evenements$date_effet[2L] <- D("2025-09-01"); b })
cas_sub <- list(
  list(v33$ev_type, "evenements", 1L, sub_type),
  list(v33$ev_motif, "evenements", 3L, sub_motif),
  list(ev_vise, "evenements", 1L, sub_type),
  list(ev_vise, "evenements", 2L, sub_type2),
  list(ev_vise, "evenements", 3L, sub_motif),
  list(m6, "evenements", 2L, list(list(motif = NA_character_))),
  list(m6b, "evenements", 2L, list(list(motif = "justificatif_manquant"), list(motif = "autre"), list(motif = NA_character_))),
  list(effets, "evenements", 2L, sub_date("date_effet", c("2024-05-01", "2025-09-01"))),
  list(effets, "evenements", 6L, sub_date("date_effet", c("2024-05-01", "2025-09-01"))),
  list(v33$date_ouverture, "dossiers", 1L, sub_date("date_ouverture", c("2025-01-22", "2025-08-01"))),
  list(v33$si_saisie, "sinistres", 2L, sub_date("date_saisie", c("2024-03-06", "2025-08-01"))),
  list(v33$ct_fin, "contrats", 1L, c(sub_date("date_fin", c("2024-01-01", "2030-12-31")),
                                     list(list(date_fin = D(NA), motif_fin = NA_character_))), TRUE),
  list(ct_saisie("2024-11-15"), "contrats", 1L, sub_date("date_fin", c("2024-01-01", "2030-12-31")), TRUE),
  list(ct_saisie("2026-01-01"), "contrats", 1L, sub_date("date_fin", c("2024-01-01", "2030-12-31")), TRUE))
substitution_ok <- function(k, declarations = NULL) {
  partie <- length(k) > 4L && k[[5L]]
  s <- vapply(k[[4L]], function(v) {
    b <- k[[1L]]
    for (c1 in names(v)) b[[k[[2L]]]][[c1]][k[[3L]]] <- v[[c1]]
    statut33(b, k[[2L]], k[[3L]], partie, declarations)
  }, "")
  o <- statut33(k[[1L]], k[[2L]], k[[3L]], partie, declarations)
  if (length(unique(s)) > 1L || all(s == "nd_refus")) o == "nd_refus" else o == s[1L]
}
verifier("#33, test par substitution, sans déclaration et sous l'hypothèse de D02b : une ligne (ou une partie) à valeur refusée lue par une règle P est non déterminée si et seulement si la valeur peut changer son statut à A0 (type, motif, date d'effet, date d'ouverture, date de saisie, date de fin)",
         all(vapply(cas_sub, substitution_ok, NA)) &&
           all(vapply(cas_sub, substitution_ok, NA, declarations = list(hypotheses = hyp2("D02b")))))
# R1 d'`actuary` : date de déclaration et date d'événement refusées (D02c), lues par D02b, sous
# les trois plans de D03g (sans déclaration, hypothèse, exclusion)
plans_d03g <- list(sans = NULL, h = list(hypotheses = hyp2("D03g"), seuils = list(d03g_delai_jours = list(sinistres = 0))),
                   x = list(exclusions = excl4("D03g")))
si_decl <- function(s) avec(function(b) { b$sinistres$date_declaration[2L] <- D("2027-01-02"); b$sinistres$date_saisie[2L] <- D(s); b })
ca_evt <- function(s) avec(function(b) { b$catastrophes$date_evenement[1L] <- D("2027-01-01"); b$catastrophes$date_saisie[1L] <- D(s); b })
verifier_egal("#33, R1 (b) : sinistres.date_declaration refusée sur SI2 sans date de saisie : sans déclaration, non déterminé sous D03g et sous D02c sinistres.date_declaration (date d'effet de l'hypothèse, P1 ; v1.5.1, #43) ; sous H de D03g, non déterminé sous D02c sinistres.date_declaration, quatre exclusions X requises ; sous X, aucune ligne non déterminée",
              lapply(plans_d03g, function(p) {
                r <- cb(si_decl(NA), A0, declarations = p)
                list(nd_de(r)[startsWith(nd_de(r), "sinistres")],
                     sum(r$declarations_requises$rubrique == "exclusions" & r$declarations_requises$traitements_admis == "X"))
              }),
              list(sans = list(c("sinistres NA D02c sinistres.date_declaration 1 SI2", "sinistres NA D03g NA 1 SI2"), 0L),
                   h = list("sinistres NA D02c sinistres.date_declaration 1 SI2", 4L), x = list(character(0), 0L)))
verifier_egal("#33, R1 (c) : catastrophes.date_evenement refusée sur CA1 : non déterminé si la saisie est antérieure à A0 (2025-01-01), invisible sinon (2026-06-02)",
              lapply(c("2025-01-01", "2026-06-02"), function(s) nd_de(cb(ca_evt(s), A0))),
              list("catastrophes NA D02c catastrophes.date_evenement 1 CA1", character(0)))
# table de vérité de .avant3() (constat 1 de l'audit) : x de {1 ; 3 ; absente connue ;
# inconnue}, y de {2 ; 0 ; absente connue ; inconnue}
x3 <- expand.grid(i = 1:4, j = 1:4)
verifier_egal(".avant3 : table de vérité à trois valeurs (16 cas) ; une date inconnue face à une date absente connue donne FALSE",
              matrix(ns$.avant3(c(1, 3, NA, NA)[x3$i], (1:4 == 4L)[x3$i], c(2, 0, NA, NA)[x3$j], (1:4 == 4L)[x3$j]), 4L),
              matrix(c(TRUE, FALSE, FALSE, NA,   FALSE, FALSE, FALSE, NA,   FALSE, FALSE, FALSE, FALSE,   NA, NA, FALSE, NA), 4L))
cas_sub_d03g <- list(
  list(si_decl("2024-03-06"), "sinistres", 2L, sub_date("date_declaration", c("2024-03-05", "2025-08-01"))),
  list(si_decl(NA), "sinistres", 2L, sub_date("date_declaration", c("2024-03-05", "2025-08-01"))),
  list(ca_evt("2025-01-01"), "catastrophes", 1L, sub_date("date_evenement", c("2024-12-01", "2025-03-01"))),
  list(ca_evt("2026-06-02"), "catastrophes", 1L, sub_date("date_evenement", c("2024-12-01", "2025-03-01"))))
# v1.5.1 (#43, Q1, décision du mainteneur) : sans déclaration, la date de déclaration de SI2
# sans date de saisie est la date d'effet de l'hypothèse de D03g, qui peut rendre la ligne
# invisible (2025-08-01 > A0, point P1) : la ligne est inscrite sous D03g et sous le refus
verifier("#33, R1 (b) et (c), test par substitution sous les trois plans de D03g : date de déclaration de SI2 refusée (saisie antérieure à A0, puis absente) et date d'événement de CA1 refusée (saisie antérieure, puis postérieure à A0)",
         all(vapply(plans_d03g, function(p) all(vapply(cas_sub_d03g, substitution_ok, NA, declarations = p)), NA)))
# cas limite 3 : défaut de forme (evenements.motif numérique) et refus de valeur (EV1 de type
# hors domaine) dans la même table : la portée table l'emporte, la colonne refusée pour sa
# valeur n'est ni la cause ni l'origine (audit, C1)
r <- cb(avec(function(b) { b$evenements$type_evenement[1L] <- "zzz"; b$evenements$motif <- as.numeric(seq_len(6L)); b }), A0)
verifier_egal("#33, cas limite 3 : défaut de forme et refus de valeur dans evenements, à A0 : refus induit de portée table d'origine evenements.motif ; D02b dans controles_non_executes, cause type_incompatible ; aucune ligne non déterminée sous hors_domaine",
              list(refus(r, "refus_induit", "evenements")$origine, refus(r, "refus_induit", "evenements")$portee,
                   ligne(r$controles_non_executes, "D02b", "evenements", "date_saisie")$cause,
                   any(r$vue$visibilite_non_determinee$motif == "hors_domaine"), r$vue$provisoire),
              list("evenements.motif", "table", "type_incompatible", FALSE, TRUE))
# règle P partielle (audit, C2) : une fille qui vise une parente de date refusée pour sa
# valeur a un verdict inconnu et est écartée de la détection, une fille d'une parente lisible
# ne l'est pas
r_a <- cb(avec(function(b) { b$sinistres$date_saisie[1L] <- D("2027-01-05"); b$dossiers$date_ouverture[3L] <- D("2024-03-05"); b }), A0)
r_c <- cb(avec(function(b) { b$evenements$type_evenement[2L] <- "zzz"; b$evenements$date_saisie[2L] <- D("2024-05-01")
                             b$evenements$date_saisie[3L] <- D("2024-08-01"); b }), A0)
verifier_egal("#33, M200, règle P partielle : D02b de dossiers, SI1 de date de saisie refusée (D02c) : DO1 et DO2 (fille de SI1) écartés, DO3 (fille de SI2, ouvert avant la saisie de SI2) détecté, ligne dans controles_non_executes, cause D02c ; D02b de evenements, EV2 de type refusé saisi avant son effet écarté, EV3 détecté, cause hors_domaine",
              list(ligne(r_a$controles, "D02b", "dossiers")$identifiants,
                   ligne(r_a$controles_non_executes, "D02b", "dossiers", "date_ouverture")$cause,
                   ligne(r_c$controles, "D02b", "evenements")$identifiants,
                   ligne(r_c$controles_non_executes, "D02b", "evenements", "date_saisie")$cause),
              list("DO3", "D02c", "EV3", "hors_domaine"))
# cause de la ligne partielle (spécification, § 2.2, (b) ; revue finale, #33) : le premier
# refus de valeur qui touche une ligne écartée, non le premier code de la colonne. (a)
# dossiers.date_ouverture : DO1 hors bornes (D02c, premier constat de la colonne) sous SI1
# sans date de saisie (connue absente : verdict faux), DO3 manquante (manquant_obligatoire)
# sous SI2 saisi : seul DO3 est écarté ; (b) evenements.motif : EV3 (sortie, saisi après son
# effet : verdict faux) vide et hors domaine, EV1 (sortie, saisi avant son effet) hors
# domaine : seul EV1 est écarté ; (c) date de la parente : DO1 hors bornes (D02c), DO2
# manquante ; RE1, fille de DO2, est écartée de D02b sur rentes, sous manquant_obligatoire
r_a <- cb(avec(function(b) { b$sinistres$date_saisie[1L] <- NA; b$dossiers$date_ouverture[1L] <- D("1900-01-01")
                             b$dossiers$date_ouverture[3L] <- NA; b }), A0)
r_b <- cb(avec(function(b) { b$evenements$motif[3L] <- ""; b$evenements$type_evenement[1L] <- "sortie"
                             b$evenements$motif[1L] <- "zzz"; b$evenements$date_effet[1L] <- D("2024-03-10"); b }), A0)
r_c <- cb(avec(function(b) { b$dossiers$date_ouverture[1L] <- D("1900-01-01"); b$dossiers$date_ouverture[2L] <- NA; b }), A0)
verifier_egal("#33, cause de la ligne partielle : premier refus de valeur qui touche une ligne écartée (D02b de dossiers : manquant_obligatoire de DO3, non D02c de DO1 au verdict faux ; D02b de evenements : hors_domaine de EV1, non chaine_vide de EV3 au verdict faux ; D02b de rentes, par la parente : manquant_obligatoire de DO2, parente de RE1, non D02c de DO1)",
              list(paste(r_a$refus_tables$motif[r_a$refus_tables$table == "dossiers"], collapse = ";"),
                   ligne(r_a$controles_non_executes, "D02b", "dossiers", "date_ouverture")$cause,
                   ligne(r_b$controles_non_executes, "D02b", "evenements", "date_saisie")$cause,
                   paste(r_c$refus_tables$motif[r_c$refus_tables$table == "dossiers"], collapse = ";"),
                   ligne(r_c$controles_non_executes, "D02b", "rentes", "date_saisie")$cause),
              list("D02c;manquant_obligatoire", "manquant_obligatoire", "hors_domaine", "D02c;manquant_obligatoire",
                   "manquant_obligatoire"))
# date de visibilité refusée pour sa valeur et enjeu de D03g (spécification, § 4.2 ; M199,
# M201) : PR1 sans date de saisie (D03g), date de règlement après l'extraction (D02c) ; la
# valeur refusée n'est pas lue : visibilité non déterminée pour l'enjeu, prestations_ecartees
# sans valeur, cause visibilite_non_determinee (avant : 0, la date refusée lue la rendant
# invisible à A0) ; date de règlement admise (2025-01-05) : 1240 ; le refus D02c a
# nombre_visibles NA (ligne de visibilité non déterminée ; § 4.4, Q7) et nombre_dossiers 1
# (dossier rattaché DO3, connu à A0 : .nombre_dossiers_union())
enjeu_pr1 <- function(dr) {
  r <- cb(avec(function(b) { b$prestations$date_saisie[1L] <- NA; b$prestations$date_reglement[1L] <- D(dr); b }), A0)
  e <- r$enjeu[r$enjeu$table %in% "prestations" & r$enjeu$motif == "D03g", , drop = FALSE]
  list(unique(e$montant), unique(e$nombre_valeurs), unique(e$cause), r)
}
e_refuse <- enjeu_pr1("2027-01-05")
k_refuse <- refus(e_refuse[[4L]], "D02c", "prestations", "date_reglement")
verifier_egal("#33, M199 : date de règlement refusée (D02c) d'une prestation de D03g, à A0 : enjeu sans valeur, cause visibilite_non_determinee, refus D02c à nombre_visibles NA et nombre_dossiers 1 ; admise : 1240",
              list(e_refuse[1:3], k_refuse$nombre_visibles, k_refuse$nombre_dossiers, enjeu_pr1("2025-01-05")[1:3]),
              list(list(NA_real_, NA_integer_, "visibilite_non_determinee"), NA_integer_, 1L,
                   list(1240, 1L, NA_character_)))
# cas limite 3 étendu (spécification, § 2.2, cas limite (3), et § 3.1) : sur une table refusée
# en portée table, le refus de valeur d'une colonne lue seulement par la règle P ou pour la
# vue n'est pas une cause ; le refus de portée table l'est (refus induit compris) ; une règle
# qui lit la colonne comme valeur garde la cause directe (M169, M185). sinistres.date_declaration
# en texte (défaut de forme, refus induit à A0 propagé à dossiers et à ses filles) et
# dossiers.date_ouverture[1] manquante ; puis dossiers refusée par D01a
q1_33 <- avec(function(b) { b$sinistres$date_declaration <- as.character(b$sinistres$date_declaration)
                            b$dossiers$date_ouverture[1L] <- NA; b })
d01_33 <- avec(function(b) { b$dossiers <- rbind(b$dossiers, transform(b$dossiers[2L, ], id_garantie_souscrite = "GS1"))
                             b$dossiers$date_ouverture[1L] <- NA; b })
causes_d02b <- function(r) {
  ne <- r$controles_non_executes
  ne <- ne[ne$code == "D02b" & ne$table %in% c("dossiers", "beneficiaires", "rentes", "evenements"), , drop = FALSE]
  paste(ne$table, ne$cause)
}
verifier_egal("#33, cas limite 3 étendu : D02b de dossiers, beneficiaires, rentes, evenements à A0 : refus_induit (table refusée par propagation), non manquant_obligatoire ; à l'extraction : manquant_obligatoire (détection partielle) ; dossiers refusée par D01a : D01a aux deux arrêtés",
              list(causes_d02b(cb(q1_33, A0)), causes_d02b(cb(q1_33)), causes_d02b(cb(d01_33, A0)), causes_d02b(cb(d01_33))),
              list(c("dossiers refus_induit", "beneficiaires refus_induit", "rentes refus_induit", "evenements refus_induit"),
                   c("dossiers manquant_obligatoire", "beneficiaires manquant_obligatoire", "evenements manquant_obligatoire"),
                   c("dossiers D01a", "beneficiaires D01a", "rentes D01a", "evenements D01a"),
                   c("dossiers D01a", "beneficiaires D01a", "rentes D01a", "evenements D01a")))
# règle écrite sur dossiers à A0 (aucune règle V ne lit dossiers.date_ouverture comme valeur :
# .regle() appelée directement) : colonne lue comme valeur, cause directe ; lue pour la vue
# seulement (dans la table ou dans la parente), refus de portée table
ctx <- ctx_complet(q1_33, A0)
ns$.regle(ctx, "essai", "dossiers", "date_ouverture", character(0), "S", "exacte", function() rep(FALSE, 3L))
ns$.regle(ctx, "essai", "dossiers", "id_garantie_souscrite", character(0), "S", "exacte", function() rep(FALSE, 3L),
          vue = "dossiers.date_ouverture")
ns$.regle(ctx, "essai", "beneficiaires", "part", character(0), "S", "exacte", function() FALSE, vue = "dossiers.date_ouverture")
verifier_egal("#33, cas limite 3 étendu, règle V sur une table refusée par propagation (dossiers, à A0) : dossiers.date_ouverture lue comme valeur : manquant_obligatoire (M169) ; lue pour la vue seulement : refus_induit",
              vapply(tail(ctx$non_executes, 3L), `[[`, "", "cause"), c("manquant_obligatoire", "refus_induit", "refus_induit"))
# garde de .regle() en mode partiel : un verdict inconnu (NA) sans refus de valeur qui
# l'explique est une erreur interne (une valeur refusée, D02c de SI1, rend la règle partielle ;
# le verdict NA rendu sur DO3, fille de SI2, n'en procède pas)
ctx <- ctx_complet(avec(function(b) { b$sinistres$date_saisie[1L] <- D("2027-01-05"); b }), A0)
garde <- tryCatch({
  ns$.regle(ctx, "essai", "dossiers", "date_ouverture", c("dossiers.id_sinistre", "sinistres.id_sinistre", "sinistres.date_saisie"),
            "S", "exacte", function() c(FALSE, FALSE, NA), partiel = TRUE, parente = c("id_sinistre", "sinistres", "id_sinistre"))
  "aucune erreur"
}, error = function(e) conditionMessage(e))
verifier("#33, garde de la règle P partielle : verdict inconnu sans refus de valeur qui l'explique : erreur interne de provie",
         startsWith(garde, "erreur interne de provie : ") && grepl("sans refus de valeur", garde, fixed = TRUE))
# logique à trois valeurs par la parente (audit, M4) : DO3, de date d'ouverture manquante, a
# pour parente SI2, saisi après A0 : invisible de façon déterminée
r <- cb(avec(function(b) { b$sinistres$date_saisie[2L] <- D("2025-08-01"); b$dossiers$date_ouverture[3L] <- NA; b }), A0)
verifier_egal("#33, logique à trois valeurs par la parente : dossiers.date_ouverture[3] manquante, SI2 saisi après A0 : DO3 invisible de façon déterminée, hors de visibilite_non_determinee (nombre_visibles 0)",
              list(any(r$vue$visibilite_non_determinee$table == "dossiers"),
                   refus(r, "manquant_obligatoire", "dossiers", "date_ouverture")$nombre_visibles),
              list(FALSE, 0L))
r <- cb(avec(function(b) { b$prestations$date_saisie[2L] <- NA; b$prestations$date_reglement[2L] <- NA; b }), A0,
        declarations = list(hypotheses = hyp2("D03g"), seuils = list(d03g_delai_jours = list(prestations = 0))))
verifier_egal("#33, cas limite 2, autre date de visibilité : PR2 sans date de saisie (D03g) et de date de règlement manquante, sous H de D03g : la date de saisie retenue ne détermine pas la visibilité, PR2 non déterminée sous le refus (audit, M18)",
              nd_de(r), "prestations NA manquant_obligatoire prestations.date_reglement 1 PR2")
verifier_egal("#33, M201 : SI2 de date de saisie refusée (D02c), à A0 : visibilité non déterminée pour les comptes du bilan (nombre_visibles NA), quelle que soit la valeur refusée, qui n'est pas lue (audit, M6)",
              refus(r33$si_saisie, "D02c", "sinistres", "date_saisie")$nombre_visibles, NA_integer_)
# décision du mainteneur du 9 novembre 2026 (Q2) : à l'extraction, la vue est la base entière
# et une composante qui ne lit une colonne que pour la visibilité n'est plus empêchée par son
# refus ; une composante qui la lit comme valeur le reste (M169)
r <- cb(avec(function(b) { b$dossiers$date_ouverture[1L] <- NA; b$sinistres$canal_declaration[1L] <- "zzz"; b }))
x <- r$enjeu[r$enjeu$motif == "hors_domaine" & r$enjeu$famille == "ensemble" & r$enjeu$garantie == "ensemble", ]
verifier_egal("#33, Q2 : dossiers.date_ouverture[1] manquante, enjeu d'un écart de SI1 à l'extraction : les quatre composantes chiffrées (DO1 compris : 60750, 60000, 3000, 0), aucune empêchée",
              list(paste(x$composante, x$montant, x$cause), nrow(ligne(r$controles_non_executes, ns$COMPOSANTES_ENJEU$composante, "dossiers"))),
              list(paste(ns$COMPOSANTES_ENJEU$composante[1:4], c(60750, 60000, 3000, 0), NA), 0L))
r <- cb(avec(function(b) { b$evenements$date_saisie[4L] <- D("2027-02-01"); b$sinistres$canal_declaration[1L] <- "zzz"; b }))
verifier_egal("#33, Q2 et M169 : evenements.date_saisie[4] refusée (D02c), à l'extraction : les composantes 2 à 4, qui la lisent comme valeur (départage des derniers événements, spécification, § 4.2), restent empêchées, cause D02c ; paiements_cumules chiffré",
              list(ligne(r$controles_non_executes, ns$COMPOSANTES_ENJEU$composante[1:4], "evenements", "date_saisie")$cause,
                   r$enjeu$montant[r$enjeu$motif == "hors_domaine" & r$enjeu$garantie == "ensemble" & r$enjeu$composante == "paiements_cumules"]),
              list(rep("D02c", 3L), 60750))
# codes détectés par la règle V (sur la vue à l'arrêté : hors du critère d'invariance) ; D10c
# sous dossiers.date_ouverture manquante est détecté à A0 sur DO2, DO1 étant hors de la vue :
# détection provisoire (faux positif probable : DO1, dossier décès du même sinistre, n'est que
# non déterminé ; issue #40)
codes_v <- c("somme_parts", "D01b", "D02a", "D03a", "D03b", "D03c", "D03e", "D03f", "D03h", "D05", "D06", "D07",
             "D10b", "D10c", "D13")
sans_v <- function(x) { x <- x[!(x$code %in% codes_v), , drop = FALSE]; rownames(x) <- NULL; x }
sans_comptes <- function(x) x[, !(names(x) %in% c("nombre_visibles", "nombre_dossiers")), drop = FALSE]
verifier("#33, invariance en A (spécification, § 2.5, critère 1) : bases à refus de valeur, controles des règles B et P et refus_tables (hors nombre_visibles et nombre_dossiers) identiques à l'extraction et à A0, sans exception",
         all(vapply(names(v33), function(n) {
           ra <- cb(v33[[n]]); r0 <- r33[[n]]
           identical(sans_v(ra$controles), sans_v(r0$controles)) &&
             identical(sans_comptes(ra$refus_tables), sans_comptes(r0$refus_tables))
         }, NA)) && identical(ligne(r33$date_ouverture$controles, "D10c", "dossiers")$identifiants, "DO2"))
# performance : rattachement des événements par le sinistre restreint aux événements sans dossier (linéaire)
perf <- function(nd) {
  b <- base_ref
  dz <- b$dossiers[rep(1L, nd), ]; dz$id_dossier <- sprintf("DX%06d", seq_len(nd)); b$dossiers <- rbind(b$dossiers, dz)
  ez <- b$evenements[rep(4L, nd), ]; ez$id_evenement <- sprintf("EX%06d", seq_len(nd)); ez$id_dossier <- dz$id_dossier
  b$evenements <- rbind(b$evenements, ez, ez[1L, ])   # D01a sur evenements : l'enjeu rattache les événements
  b
}
verifier_egal("performance : paires de clés (.paires, .composer) sans jointure par merge, triées par i puis j, doublons de clé compris",
              list(ns$.paires(c("a", NA, "b", "a"), c("b", "a", "a", NA)),
                   ns$.composer(data.frame(i = 1:2, j = c(2L, 1L)), data.frame(i = c(1L, 2L, 2L), j = c(10L, 20L, 30L)))),
              list(data.frame(i = c(1L, 1L, 3L, 4L, 4L), j = c(2L, 3L, 1L, 2L, 3L)), data.frame(i = c(1L, 1L, 2L), j = c(20L, 30L, 10L))))
# croissance plutôt que durée, et travail plutôt qu'horloge (une durée dépend de la charge de
# la machine ; réserve m-a de l'audit, #45) : travail de controler_base (travail_de() de
# tests/harnais.R : somme des tailles des arguments des opérations vectorielles de base,
# comptées dans controler_base et dans toutes les fonctions du package qu'elle appelle),
# rapport du travail à 2 000 et 500 dossiers : environ 3,5 (linéaire, frais fixes compris ;
# 4 sans eux) ; 12 si le rattachement par le sinistre n'est pas restreint aux événements sans
# dossier (rattachement d'avant (ii-c), paires de chaque événement avec tous les dossiers du
# sinistre ; mesuré). Borne 6 : seule une croissance quadratique la franchit.
OPS_CB <- c("which", "match", "unique", "order", "rep", "c", "rbind", "==", "!=", "<=", ">=", "<", ">", "&", "|", "!",
            "is.na", "[[")
travail_cb <- function(b, ...) travail_de(ns$controler_base, b, A, ..., ops = OPS_CB, sous = fonctions_de(ns))
verifier("performance : travail de controler_base de 500 à 2 000 dossiers d'un même sinistre (écart D01a sur evenements) multiplié par moins de 6 (rattachement linéaire ; quadratique : 12)",
         travail_cb(perf(2000L)) / travail_cb(perf(500L)) < 6)

section("donnees : règle B à trois valeurs, par strates (#42, M217 ; spécification v1.5, § 2.2, B.1 à B.5 ; § 2.5, critères B1 à B8)")
# B8 (i) : acyclicité de la constante interne .LECTURES_REGLE_B (tri topologique de Kahn
# complet, .strates_regle_b()) et strates du § 2.2, B.3 (résultat exact à 26c23c9)
lec <- ns$.LECTURES_REGLE_B
st <- ns$.STRATES_REGLE_B
strate_de <- function(k) sort(names(st)[st == k], method = "radix")
site8 <- paste0("garanties_souscrites.", c("type_franchise", "regle_complement", "type_rente_conjoint", "option_iad",
                                           "periodicite_prestation", "terme_prestation", "conjoint_vise",
                                           "versement_double_effet", "non_remariage", "prolongation_handicap",
                                           "maintien_double_effet", "clause_type_beneficiaire"))
verifier_egal("B8 (i) : graphe de la règle B acyclique (tri topologique complet) : 39 arêtes, 49 nœuds ; strates 1 à 3 du § 2.2, B.3 ; puits 4",
              list(sum(lengths(lec$colonne)), length(st), strate_de(1L), strate_de(2L), strate_de(3L), ns$.STRATE_PUITS),
              list(39L, 49L,
                   sort(c("affiliations.date_designation", "affiliations.date_saisie_fin", "affiliations.motif_fin",
                          "assures.date_situation_familiale", "contrats.date_saisie_fin", "contrats.date_terme",
                          "contrats.jour_echeance", "contrats.motif_fin", "cotisations.montant", "evenements.type_evenement",
                          "famille.situation", site8, "garanties_souscrites.college", "garanties_souscrites.taux_technique_tarif",
                          "prestations.debut_periode", "prestations.fin_periode", "prestations.montant", "victimes.date_deces"),
                        method = "radix"),
                   sort(c("evenements.categorie_invalidite", "evenements.montant", "evenements.motif",
                          "evenements.source_information", "famille.date_naissance"), method = "radix"),
                   "evenements.date_effet", 4L))
cycle <- tryCatch({ ns$.strates_regle_b(list(a = "b", b = "c", c = "a")); "aucune erreur" }, error = function(e) conditionMessage(e))
verifier("B8 (i) : un cycle est une erreur interne de provie (aucun point fixe)",
         startsWith(cycle, "erreur interne de provie : graphe de la ") && grepl("gle B cyclique (b, c, a)", cycle, fixed = TRUE))
# B8 (ii) : couverture de la constante, recoupée avec les appels de .regle() de la règle B sur
# la base de référence (toutes tables et colonnes), sur le modèle du recensement (B.2) : pour
# chaque appel exécuté (une fois, dans la passe de sa strate), les colonnes non clés refusables
# pour leur valeur de `lit` (colonnes contrôlées par une règle R de portée colonne), hors la
# colonne contrôlée, sont exactement celles de la constante, par portée et colonne contrôlée
.GlobalEnv$.appels_b <- list()
suppressMessages(trace(".regle", where = ns, print = FALSE, tracer = quote(
  if (is.null(ctx$refus_pv) && (is.null(ctx$strate) || .strate_regle(ctx$dico, code, table, colonne) == ctx$strate))
    .GlobalEnv$.appels_b[[length(.GlobalEnv$.appels_b) + 1L]] <- list(code = code, table = table, colonne = colonne,
                                                                      lit = lit, traitement = traitement))))
invisible(controler_base(base_ref, A))
suppressMessages(untrace(".regle", where = ns))
appels_b <- .GlobalEnv$.appels_b
rm(".appels_b", envir = .GlobalEnv)
portee_b <- vapply(appels_b, function(k) ns$.portee_effective(d, k$code, k$table, k$colonne), "")
soi_b <- vapply(appels_b, function(k) paste(k$table, k$colonne, sep = "."), "")
refusables <- unique(soi_b[portee_b == "colonne" & vapply(appels_b, `[[`, "", "traitement") == "R"])
lus_b <- lapply(seq_along(appels_b), function(i) setdiff(intersect(appels_b[[i]]$lit, refusables), soi_b[i]))
concernee <- lengths(lus_b) > 0L
recensees <- function(p) {
  s <- unique(soi_b[concernee & portee_b == p])
  x <- lapply(s, function(tc) sort(unique(unlist(lus_b[concernee & portee_b == p & soi_b == tc])), method = "radix"))
  stats::setNames(x, s)[sort(s, method = "radix")]
}
constante <- function(p) lapply(lec[[p]], sort, method = "radix")[sort(names(lec[[p]]), method = "radix")]
verifier_egal("B8 (ii) : couverture : colonnes refusables lues par chaque règle concernée = constante .LECTURES_REGLE_B (portée colonne et portée table) ; 440 appels de .regle() en règle B, 108 colonnes refusables, 83 règles concernées (58 de portée colonne, 25 de portée table), toutes R (B.2)",
              list(recensees("colonne"), recensees("table"), length(appels_b), length(refusables), sum(concernee),
                   sum(concernee & portee_b == "colonne"), sum(concernee & portee_b == "table"),
                   unique(vapply(appels_b[concernee], `[[`, "", "traitement"))),
              list(constante("colonne"), constante("table"), 440L, 108L, 83L, 58L, 25L, "R"))
cles_b <- unique(paste(vapply(appels_b[concernee], `[[`, "", "code"), soi_b[concernee], sep = "|"))
lignes_b <- function(r) {
  x <- r$controles_non_executes
  x <- x[paste(x$code, paste(x$table, x$colonne, sep = "."), sep = "|") %in% cles_b, c("code", "table", "colonne", "cause")]
  rownames(x) <- NULL
  x
}
# lignes partielles de la règle B attendues (critères B1 à B7) : (code, table, colonne, cause)
partielles <- function(...) {
  x <- do.call(rbind, lapply(list(...), function(k) data.frame(code = k[1L], table = k[2L], colonne = k[3L], cause = k[4L],
                                                               stringsAsFactors = FALSE)))
  x <- ns$.trier(x, d)
  rownames(x) <- NULL
  x
}
refus_de_b <- function(r) paste(r$refus_tables$table, r$refus_tables$colonne, r$refus_tables$motif, r$refus_tables$portee,
                                r$refus_tables$identifiants)
cas42 <- list(
  B1 = avec(function(b) { b$evenements$type_evenement[6L] <- "zzz"; b }),
  B2 = avec(function(b) { b$evenements$type_evenement[5L] <- "fixation_capital"; b }),
  B3 = avec(function(b) { b$garanties_souscrites$code_garantie[2L] <- "zzz"; b }),
  B4 = avec(function(b) { b$contrats$nature_contrat[2L] <- "zzz"; b }),
  B5 = avec(function(b) { b$evenements$date_effet[3L] <- D("2027-03-01"); b }),
  B6 = avec(function(b) { b$evenements$motif[6L] <- "zzz"; b }),
  B7 = avec(function(b) { b$beneficiaires$qualite[1L] <- "zzz"; b }))
r42 <- lapply(cas42, cb, arrete = A)
r42_a0 <- lapply(cas42, cb, arrete = A0)
hd <- "hors_domaine"
b1_lignes <- partielles(c("D02c", "evenements", "date_effet", hd), c(hd, "evenements", "id_dossier", hd),
                        c(hd, "evenements", "id_rente", hd), c(hd, "evenements", "motif", hd),
                        c("manquant_obligatoire", "evenements", "montant", hd),
                        c("manquant_obligatoire", "evenements", "source_information", hd))
verifier_egal("B1 : EV6 de type zzz, à A0 et à A : plus de D02c induit, seul hors_domaine sur type_evenement ; six lignes partielles de la règle B, cause hors_domaine",
              list(refus_de_b(r42$B1), refus_de_b(r42_a0$B1), lignes_b(r42$B1), lignes_b(r42_a0$B1)),
              list("evenements type_evenement hors_domaine colonne EV6", "evenements type_evenement hors_domaine colonne EV6",
                   b1_lignes, b1_lignes))
x <- r42_a0$B1$vue$visibilite_non_determinee
verifier_egal("B1 : à A0, une seule rangée non déterminée (hors_domaine, origine evenements.type_evenement) ; causes de D02a (règle bloquée) et de D02b (règle P partielle) : hors_domaine",
              list(paste(x$table, x$motif, x$origine, x$identifiants),
                   ligne(r42_a0$B1$controles_non_executes, "D02a", "evenements", "date_effet")$cause,
                   ligne(r42_a0$B1$controles_non_executes, "D02b", "evenements", "date_saisie")$cause),
              list("evenements hors_domaine evenements.type_evenement EV6", hd, hd))
verifier_egal("B2 : EV5 de type fixation_capital (incompatible avec la rente d'éducation) : le type reste refusé (auto-lecture), plus de refus de id_rente ni de portée table de evenements ; cinq lignes partielles, cause hors_domaine",
              list(refus_de_b(r42$B2), lignes_b(r42$B2)),
              list("evenements type_evenement hors_domaine colonne EV5",
                   partielles(c(hd, "evenements", "id_dossier", hd), c(hd, "evenements", "id_rente", hd),
                              c(hd, "evenements", "montant", hd), c("manquant_obligatoire", "evenements", "motif", hd),
                              c("manquant_obligatoire", "evenements", "source_information", hd))))
x <- lignes_b(r42$B3)
attendues_b3 <- partielles(c("chevauchement", "garanties_souscrites", NA, hd), c("D10a", "dossiers", "id_garantie_souscrite", hd),
                           c("D10a", "prestations", "type_prestation", hd), c(hd, "parametres", "parametre", hd),
                           c(hd, "evenements", "type_evenement", hd), c("manquant_obligatoire", "evenements", "id_rente", hd),
                           c(hd, "garanties_souscrites", "type_franchise", hd), c(hd, "garanties_souscrites", "regle_complement", hd),
                           c(hd, "garanties_souscrites", "periodicite_prestation", hd),
                           c(hd, "garanties_souscrites", "terme_prestation", hd))
manquants_b3 <- x$colonne[x$code == "manquant_obligatoire" & x$table == "garanties_souscrites"]
verifier_egal("B3 : GS2 de code zzz : une seule rangée de refus (code_garantie), sans refus induit ; lignes partielles, cause hors_domaine, dont D10a (dossiers, prestations), chevauchement, parametres.parametre, les quatre colonnes conditionnelles présentes de GS2, type_evenement et id_rente de evenements, et huit manquant_obligatoire du site 8",
              list(refus_de_b(r42$B3), all(x$cause == hd), do.call(paste, attendues_b3) %in% do.call(paste, x),
                   sort(manquants_b3, method = "radix")),
              list("garanties_souscrites code_garantie hors_domaine colonne GS2", TRUE, rep(TRUE, nrow(attendues_b3)),
                   sort(c("type_rente_conjoint", "option_iad", "conjoint_vise", "versement_double_effet", "non_remariage",
                          "prolongation_handicap", "maintien_double_effet", "clause_type_beneficiaire"), method = "radix")))
verifier_egal("B4 : CT2 de nature zzz : une seule rangée (nature_contrat) ; lignes partielles manquant_obligatoire sur id_adherent, hors_domaine sur id_assure et date_terme, cause hors_domaine",
              list(refus_de_b(r42$B4), lignes_b(r42$B4)),
              list("contrats nature_contrat hors_domaine colonne CT2",
                   partielles(c("manquant_obligatoire", "contrats", "id_adherent", hd), c(hd, "contrats", "id_assure", hd),
                              c(hd, "contrats", "date_terme", hd))))
verifier_egal("B5 : EV3 de type sortie (non programmable), effet 2027-03-01 après l'extraction : D02c sur date_effet, inchangé ; aucune ligne partielle de la règle B",
              list(refus_de_b(r42$B5), nrow(lignes_b(r42$B5))), list("evenements date_effet D02c colonne EV3", 0L))
verifier_egal("B6 : EV6 de motif zzz (chaîne jusqu'à la strate 3) : hors_domaine sur motif seul ; ligne partielle (D02c, evenements, date_effet), cause hors_domaine",
              list(refus_de_b(r42$B6), lignes_b(r42$B6)),
              list("evenements motif hors_domaine colonne EV6", partielles(c("D02c", "evenements", "date_effet", hd))))
verifier_egal("B7 : BE1 de qualité zzz, à A0 : qualite seule refusée (plus de refus de portée table sur id_membre) ; ligne partielle (hors_domaine, beneficiaires, id_membre), cause hors_domaine",
              list(refus_de_b(r42_a0$B7), lignes_b(r42_a0$B7)),
              list("beneficiaires qualite hors_domaine colonne BE1", partielles(c(hd, "beneficiaires", "id_membre", hd))))
# critère 1 (v1.5) : les lignes de controles_non_executes nées de la règle B sont invariantes en A
verifier("critère 1 (v1.5) : lignes partielles de la règle B identiques à A0 et à A (B1 à B7)",
         all(vapply(names(cas42), function(n) identical(lignes_b(r42[[n]]), lignes_b(r42_a0[[n]])), NA)))
# garde de .regle() en règle B : un verdict inconnu sans refus de valeur qui l'explique est
# une erreur interne (spécification, § 2.2, B.5)
ctx <- ns$.contexte(base_ref, d, list(date_extraction = A), A)
garde_b <- tryCatch({
  ns$.regle(ctx, "essai", "dossiers", "date_ouverture", character(0), "R", "exacte", function() c(FALSE, NA, FALSE),
            partiel = TRUE)
  "aucune erreur"
}, error = function(e) conditionMessage(e))
verifier("#42, garde de la règle B à trois valeurs : verdict inconnu sans refus de valeur qui l'explique : erreur interne de provie",
         startsWith(garde_b, "erreur interne de provie : ") && grepl("gle B : ligne", garde_b, fixed = TRUE) &&
           grepl("sans refus de valeur", garde_b, fixed = TRUE))

# Critère 6 (a) (vérification, non preuve) : pour chaque règle qui lit une valeur refusée, la
# valeur est remplacée par chaque valeur du domaine de sa colonne (et l'absence pour une colonne
# non obligatoire ; pour une date ou un nombre, des valeurs contrastées autour des bornes lues),
# les autres valeurs gardant leur état de la base (refus de valeur de la règle B) : la ligne est
# écartée si et seulement si le verdict varie, sinon elle a le verdict commun. Les règles de
# portée colonne de la colonne substituée sont exclues (auto-lecture). Règle B seule, sur une
# copie de l'espace de noms dont .regle() consigne les verdicts et dont .refus_valeur_de() rend,
# pour les essais, l'état de la base hors la cellule substituée, lue comme connue.
copie_ns <- function() {
  env <- new.env(parent = ns)
  for (nom in fonctions_de(ns)) {
    g <- get(nom, envir = ns)
    environment(g) <- env
    assign(nom, g, envir = env)
  }
  env
}
verdicts_b <- function(b, etat = NULL, cellule = NULL) {
  env <- copie_ns()
  journal <- new.env()
  journal$l <- list()
  regle0 <- env$.regle
  env$.regle <- function(ctx, code, table, colonne, lit, traitement, detection, f, ...) {
    regle0(ctx, code, table, colonne, lit, traitement, detection, function() {
      r <- f()
      journal$l[[length(journal$l) + 1L]] <- list(cle = paste(code, table, colonne, sep = "|"), soi = paste(table, colonne, sep = "."),
                                                  lit = lit, portee = ns$.portee_effective(d, code, table, colonne),
                                                  r = as.logical(r))
      r
    }, ...)
  }
  if (!is.null(etat)) {
    rvd0 <- env$.refus_valeur_de
    env$.refus_valeur_de <- function(ctx, table, colonne) {
      if (!is.null(ctx$refus_pv)) return(rvd0(ctx, table, colonne))
      r <- etat[[table]][[colonne]]
      if (table == cellule$table && colonne == cellule$colonne) {
        r <- Filter(function(x) length(x$lignes) > 0L, lapply(r, function(x) { x$lignes <- setdiff(x$lignes, cellule$ligne); x }))
      }
      if (length(r)) r else NULL
    }
  }
  ctx <- env$.contexte(b, d, list(date_extraction = A), A)
  env$.regle_forme(ctx)
  env$.regle_domaine(ctx)
  env$.regle_cles(ctx)
  list(journal = journal$l, etat = ctx$refus_valeur)
}
# un cas : base, cellule refusée (table, colonne, ligne), domaine substitué (NULL : .domaine3())
substitution <- function(b, table, colonne, ligne, domaine = NULL) {
  tc <- paste(table, colonne, sep = ".")
  if (is.null(domaine)) domaine <- ns$.domaine3(list(dico = d), table, colonne)
  base <- verdicts_b(b)
  essais <- lapply(seq_along(domaine), function(k) {
    bk <- b
    bk[[table]][[colonne]][ligne] <- domaine[k]
    verdicts_b(bk, base$etat, list(table = table, colonne = colonne, ligne = ligne))$journal
  })
  lit_cellule <- vapply(base$journal, function(j) tc %in% c(j$soi, j$lit) && !(j$portee == "colonne" && j$soi == tc), NA)
  alignes <- all(vapply(essais, function(e) identical(vapply(e, `[[`, "", "cle"), vapply(base$journal, `[[`, "", "cle")), NA))
  ecarts <- character(0)
  ecartees <- 0L
  for (i in which(lit_cellule)) {
    m <- do.call(cbind, lapply(essais, function(e) e[[i]]$r))
    attendu <- ifelse(apply(is.na(m), 1L, any), NA, ifelse(apply(m, 1L, all), TRUE, ifelse(apply(!m, 1L, all), FALSE, NA)))
    if (!identical(base$journal[[i]]$r, attendu)) ecarts <- c(ecarts, base$journal[[i]]$cle)
    ecartees <- ecartees + sum(is.na(base$journal[[i]]$r))
  }
  list(colonne = tc, alignes = alignes, regles = sum(lit_cellule), ecarts = ecarts, ecartees = ecartees, base = base$journal)
}
dates <- function(...) as.Date(c(...))
gs5 <- function(b) {   # version décès close de CT1, antérieure à GS1
  x <- b$garanties_souscrites[1L, ]
  x$id_garantie_souscrite <- "GS5"; x$date_effet <- D("2010-01-01"); x$date_fin <- D("2014-12-31")
  b$garanties_souscrites <- rbind(b$garanties_souscrites, x)
  b
}
site4_na <- avec(function(b) {
  b$contrats$id_contrat[2L] <- NA; b$garanties_souscrites$id_contrat[4L] <- NA; b$garanties_souscrites$code_garantie[4L] <- "zzz"
  b
})
six_codes <- avec(function(b) {
  b$garanties_souscrites$date_effet[3L] <- D("2025-06-01"); b$garanties_souscrites$code_garantie[3L] <- "zzz"
  for (k in 1:4) {
    x <- b$garanties_souscrites[1L, ]
    x$id_garantie_souscrite <- paste0("GSX", k)
    x$code_garantie <- c("rente_conjoint", "rente_education", "double_effet", "invalidite")[k]
    b$garanties_souscrites <- rbind(b$garanties_souscrites, x)
  }
  b
})
corpus <- list(
  list(cas42$B1, "evenements", "type_evenement", 6L),                                         # strate 1, puis 2 et 3
  list(cas42$B2, "evenements", "type_evenement", 5L),                                         # refus relationnel (site 31)
  list(cas42$B6, "evenements", "motif", 6L),                                                  # chaîne jusqu'à la strate 3
  list(cas42$B3, "garanties_souscrites", "code_garantie", 2L),                                # strate 0 lue en strate 1
  list(avec(function(b) { b$contrats$nature_contrat[2L] <- "zzz"; b$garanties_souscrites$college[4L] <- "C1"; b }),
       "contrats", "nature_contrat", 2L),                                                     # jointure (garanties_souscrites.college)
  list(avec(function(b) { b$contrats$date_fin[1L] <- D("1900-01-01"); b }), "contrats", "date_fin", 1L,
       dates(NA, "1901-01-01", "2020-01-01", "2026-12-31", "2030-01-01")),
  list(avec(function(b) { b$contrats$mois_echeance[1L] <- 13L; b$contrats$jour_echeance[1L] <- 31L; b }),
       "contrats", "mois_echeance", 1L, 1:12),
  list(avec(function(b) { b$assures$situation_familiale[2L] <- "zzz"; b }), "assures", "situation_familiale", 2L),
  list(avec(function(b) { b$assures$nombre_enfants_charge[2L] <- 25L; b }), "assures", "nombre_enfants_charge", 2L, c(NA, 0:20)),
  list(avec(function(b) { b$affiliations$date_fin[1L] <- D("1900-01-01"); b }), "affiliations", "date_fin", 1L,
       dates(NA, "1901-01-01", "2020-01-01", "2026-12-31", "2030-01-01")),
  list(avec(function(b) { b$affiliations$designation[1L] <- "zzz"; b }), "affiliations", "designation", 1L),
  list(avec(function(b) { b$famille$situation[1L] <- "zzz"; b }), "famille", "situation", 1L),
  list(avec(function(b) { b$famille$lien[1L] <- "zzz"; b }), "famille", "lien", 1L),
  list(avec(function(b) { b$sinistres$nature_sinistre[2L] <- "zzz"; b }), "sinistres", "nature_sinistre", 2L),
  list(avec(function(b) { b$prestations$type_prestation[1L] <- "zzz"; b }), "prestations", "type_prestation", 1L),
  list(avec(function(b) { b$prestations$nature_mouvement[1L] <- "zzz"; b$prestations$montant[1L] <- -10; b }),
       "prestations", "nature_mouvement", 1L),
  list(avec(function(b) { b$cotisations$nature_mouvement[1L] <- "zzz"; b }), "cotisations", "nature_mouvement", 1L),
  list(cas42$B7, "beneficiaires", "qualite", 1L),
  list(avec(function(b) { b$victimes$statut_victime[1L] <- "zzz"; b }), "victimes", "statut_victime", 1L),
  list(avec(function(b) { b$garanties_souscrites$college[2L] <- ""; b$affiliations$college[1L] <- "C2"; b }),
       "garanties_souscrites", "college", 2L, c("ensemble", "C2", "C3")),
  list(avec(function(b) { b <- gs5(b); b$garanties_souscrites$date_effet[1L] <- D("1900-01-01"); b }),
       "garanties_souscrites", "date_effet", 1L, dates("1901-01-01", "2014-12-31", "2015-01-01", "2026-12-31")),
  list(avec(function(b) { b <- gs5(b); b$garanties_souscrites$date_fin[5L] <- D("9999-12-31"); b }),
       "garanties_souscrites", "date_fin", 5L, dates(NA, "1901-01-01", "2009-12-31", "2014-12-31", "2015-01-01", "9999-12-30")),
  list(avec(function(b) { b$parametres$age_max[4L] <- 130L; b }), "parametres", "age_max", 4L, c(NA, 0L, 17L, 18L, 25L, 120L)),
  # site 4 : seule garantie (GS4) d'un contrat individuel (CT2) de code refusé ; puis clés NA
  # (une clé NA s'apparie à une clé NA, .existe3())
  list(avec(function(b) { b$garanties_souscrites$code_garantie[4L] <- "zzz"; b$contrats$date_terme[2L] <- D(NA); b }),
       "garanties_souscrites", "code_garantie", 4L),
  list(site4_na, "garanties_souscrites", "code_garantie", 4L),
  # chevauchement, lecture exacte (réserve R1 d'actuary) : GS3 de code refusé, ouverte au
  # 2025-06-01, face aux six codes ouverts sur CT1 et le même collège : vraie pour toute valeur
  list(six_codes, "garanties_souscrites", "code_garantie", 3L))
battue <- lapply(corpus, function(k) substitution(k[[1L]], k[[2L]], k[[3L]], k[[4L]], if (length(k) > 4L) k[[5L]]))
colonnes_lues <- unique(unlist(lapply(c(lec$colonne, lec$table), identity)))
verifier_egal("critère 6 (a) : corpus de substitution couvrant les 22 colonnes lues du tableau du § 2.2 ; essais alignés sur la base (mêmes règles, même ordre) ; chaque cas compare au moins une règle et écarte au moins une ligne",
              list(sort(unique(vapply(battue, `[[`, "", "colonne")), method = "radix"), sort(colonnes_lues, method = "radix"),
                   all(vapply(battue, `[[`, NA, "alignes")), vapply(battue, `[[`, 0L, "regles") > 0L,
                   vapply(battue, `[[`, 0L, "ecartees") > 0L),
              list(sort(colonnes_lues, method = "radix"), sort(colonnes_lues, method = "radix"), TRUE, rep(TRUE, length(corpus)),
                   rep(TRUE, length(corpus))))
verifier_egal("critère 6 (a) : sur chaque règle qui lit la valeur refusée, verdict de la règle B à trois valeurs = verdict de substitution (écartée ssi le verdict varie, sinon verdict commun)",
              lapply(battue, `[[`, "ecarts"), rep(list(character(0)), length(corpus)))
chev <- Filter(function(j) j$cle == "chevauchement|garanties_souscrites|NA", battue[[4L]]$base)[[1L]]$r
verifier_egal("B3 : chevauchement de garanties_souscrites : GS1, GS2, GS3 écartées (GS2 peut appartenir au groupe de GS1 ou de GS3), GS4 non détectée",
              chev, c(NA, NA, NA, FALSE))
r <- tryCatch(cb(site4_na), error = function(e) conditionMessage(e))
verifier_egal("site 4, clés NA (contrats.id_contrat de CT2 et garanties_souscrites.id_contrat de GS4, code de GS4 refusé) : pas d'erreur interne ; date_terme de CT2 écartée, cause hors_domaine",
              if (is.character(r)) r else ligne(r$controles_non_executes, "hors_domaine", "contrats", "date_terme")$cause, hd)
r <- cb(six_codes)
verifier_egal("chevauchement, lecture exacte (pour toute affectation, il existe une ligne qui recouvre) : GS3 de code refusé, recouverte quel que soit son code par une version ouverte de CT1 et du même collège : détectée (refus de portée table) ; les autres versions de CT1 écartées",
              list(refus(r, "chevauchement", "garanties_souscrites")$identifiants,
                   ligne(r$controles_non_executes, "chevauchement", "garanties_souscrites", NA)$cause),
              list("GS3", hd))
# .chevauchements3() : ligne inconnue face à deux lignes connues qui couvrent tout le domaine
# (vraie) ; clé NA groupée comme par .chevauchements() (paste)
g3 <- function(v, u, dom) list(list(valeurs = v, inconnu = u, domaine = dom),
                               list(valeurs = rep("ensemble", length(v)), inconnu = rep(FALSE, length(v)), domaine = NULL))
verifier_egal(".chevauchements3() : A et B connues [2000, 2010], ligne de code inconnu (domaine A, B) [2005, 2006] : NA NA TRUE ; deux lignes de clé NA (connue deces, inconnue de domaine deces, incapacite) : NA NA, comme sous une clé renseignée",
              list(as.vector(ns$.chevauchements3(rep("CT1", 3), g3(c("A", "B", "zzz"), c(FALSE, FALSE, TRUE), c("A", "B")),
                                                  c(2000, 2000, 2005), c(2000, 2000, 2005), c(2010, 2010, 2006), c(2010, 2010, 2006),
                                                  rep(FALSE, 3), c(FALSE, FALSE, TRUE))),
                   as.vector(ns$.chevauchements3(c(NA, NA), g3(c("deces", "zzz"), c(FALSE, TRUE), c("deces", "incapacite")),
                                                  c(2000, 2005), c(2000, 2005), c(2010, 2006), c(2010, 2006), rep(FALSE, 2),
                                                  c(FALSE, TRUE)))),
              list(c(NA, NA, TRUE), c(NA, NA)))

section("donnees : visibilité à trois valeurs, évaluée une seule fois pour la vue et les comptes (#43, M216, M222 ; spécification v1.5, § 2.2 (c), § 3.2, § 4.2 ; § 2.5, critères V1 à V14)")
# bases des critères V1 à V12 (sorties « après » de la v1.5, § 2.5)
mf43 <- "resiliation_adherent"
v43 <- list(
  V1 = avec(function(b) { b$prestations$date_saisie[1L] <- NA; b$prestations$date_reglement[1L] <- D("2026-12-01"); b }),
  V2 = avec(function(b) { b$prestations$date_saisie[1L] <- NA; b$prestations$date_reglement[1L] <- D("2025-01-15"); b }),
  V3 = avec(function(b) { b$rentes$date_saisie[1L] <- NA; b }),
  V4 = avec(function(b) { b$evenements$date_saisie[3L] <- D("2026-01-01"); b$evenements$date_effet[3L] <- D("2026-02-01"); b }),
  V5 = avec(function(b) { b$evenements$date_saisie[3L] <- NA; b$evenements$date_effet[3L] <- D("2025-09-01"); b }),
  V6 = avec(function(b) { b$sinistres$date_saisie[2L] <- NA; b$sinistres$date_declaration[2L] <- D("2025-09-01"); b }),
  V7 = avec(function(b) { b$sinistres$date_saisie[2L] <- NA; b }),
  V8 = avec(function(b) { b$contrats$date_fin[2L] <- D("2026-06-30"); b$contrats$motif_fin[2L] <- mf43; b }),
  V9 = avec(function(b) { b$contrats$date_fin[2L] <- D("2025-03-01"); b$contrats$motif_fin[2L] <- mf43; b }),
  V10 = avec(function(b) { b$contrats$date_effet[2L] <- D("2025-12-01"); b$contrats$date_debut_gestion[2L] <- D("2025-12-01")
                           b$contrats$date_fin[2L] <- D("2026-06-30"); b$contrats$motif_fin[2L] <- mf43
                           b$garanties_souscrites$date_effet[4L] <- D("2025-12-01"); b }),
  V11 = avec(function(b) { f <- rbind(b$famille, b$famille); f$date_naissance[1L] <- NA; f$date_saisie[2L] <- NA
                           b$famille <- f; b }),
  V12 = avec(function(b) { f <- rbind(b$famille, b$famille); f$date_saisie[2L] <- D("2025-03-01"); f$sexe[1L] <- "zzz"
                           b$famille <- f; b }))
a43 <- c(V3 = "2024-12-31")
arrete43 <- function(nom) if (nom %in% names(a43)) D(a43[[nom]]) else A0
r43 <- lapply(stats::setNames(names(v43), names(v43)), function(nom) cb(v43[[nom]], arrete43(nom)))
requises43 <- function(r) with(r$declarations_requises, paste(rubrique, motif, cle, traitements_admis, nombre_lignes))
attendu_d03g <- function(table) c(paste("exclusions D03g", ns$FAMILLES_CALCUL, "H;X 1"), paste("hypotheses D03g", ns$REFERENTIELS, "H;X 1"),
                                  paste0("seuils D03g d03g_delai_jours$", table, " NA 1"))
r <- r43$V1
verifier_egal("V1 (#43) : PR1 sans date de saisie, réglée le 2026-12-01 > A0, sans déclaration : invisible de façon déterminée, non inscrite, vue non provisoire ; D03g détecté, sept déclarations requises (nombre_lignes 1) ; .connus() FALSE",
              list(nd_de(r), r$vue$provisoire, ligne(r$controles, "D03g")$identifiants, requises43(r),
                   ns$.connus(ctx_complet(v43$V1, A0), "prestations")[1L]),
              list(character(0), FALSE, "PR1", attendu_d03g("prestations"), FALSE))
verifier_egal("V2 (#43) : même base, réglée le 2025-01-15 au plus A0 : non déterminée sous D03g, inchangé",
              list(nd_de(r43$V2), r43$V2$vue$provisoire), list("prestations NA D03g NA 1 PR1", TRUE))
verifier_egal("V3 (#43) : RE1 sans date de saisie au 2024-12-31, parente DO2 ouverte le 2025-02-02 (invisible) : invisible, non inscrite ; exigences inchangées",
              list(nd_de(r43$V3), r43$V3$vue$provisoire, requises43(r43$V3)), list(character(0), FALSE, attendu_d03g("rentes")))
verifier_egal("V4 (#43) : EV3 saisi le 2026-01-01 > A0, effet 2026-02-01, D02b sans hypothèse : invisible, non inscrit ; controles (D02b, EV3) et deux hypothèses H requises (nombre_lignes 1) inchangés",
              list(nd_de(r43$V4), r43$V4$vue$provisoire, paste(ligne(r43$V4$controles, "D02b")$table, ligne(r43$V4$controles, "D02b")$identifiants),
                   requises43(r43$V4)),
              list(character(0), FALSE, "evenements EV3", paste("hypotheses D02b", ns$REFERENTIELS, "H 1")))
verifier_egal("V5 (#43, point P1) : EV3 sans date de saisie, effet 2025-09-01 > A0, sans déclaration : invisible (date d'effet de l'hypothèse de D03g), non inscrit ; exigences inchangées",
              list(nd_de(r43$V5), r43$V5$vue$provisoire, requises43(r43$V5)), list(character(0), FALSE, attendu_d03g("evenements")))
verifier_egal("V6 (#43, M167 rouverte) : SI2 sans date de saisie, déclaré le 2025-09-01 > A0 : aucune rangée (filles d'une parente invisible non inscrites), vue non provisoire ; exigences inchangées",
              list(nd_de(r43$V6), r43$V6$vue$provisoire, requises43(r43$V6)), list(character(0), FALSE, attendu_d03g("sinistres")))
verifier_egal("V7 (#43) : SI2 sans date de saisie, déclaré le 2024-03-05 au plus A0 : cinq rangées (SI2 sous D03g, ses filles sous parente_non_determinee), inchangé",
              nd_de(r43$V7), c("sinistres NA D03g NA 1 SI2", "dossiers NA parente_non_determinee NA 1 DO3",
                               "evenements NA parente_non_determinee NA 3 EV1;EV2;EV3", "prestations NA parente_non_determinee NA 1 PR1",
                               "evaluations_gestion NA parente_non_determinee NA 1 EG1"))
attendu_partie <- c(paste("hypotheses D03g", ns$REFERENTIELS, "H 1"), "seuils D03g d03g_delai_jours$contrats NA 1")
verifier_egal("V8 (#43) : fin de CT2 le 2026-06-30 > A0, date_saisie_fin manquante : partie masquée de façon déterminée, non inscrite, vue non provisoire ; deux hypothèses H et un seuil inchangés ; partie masquée dans la vue",
              list(nd_de(r43$V8), r43$V8$vue$provisoire, requises43(r43$V8),
                   ns$.valeurs_vue(ctx_complet(v43$V8, A0), "contrats", "date_fin")[2L]),
              list(character(0), FALSE, attendu_partie, D(NA)))
verifier_egal("V9 (#43) : même partie, fin le 2025-03-01 au plus A0 : rangée (contrats, date_saisie_fin, D03g) inchangée",
              list(nd_de(r43$V9), requises43(r43$V9)), list("contrats date_saisie_fin D03g NA 1 CT2", attendu_partie))
verifier_egal("V10 (#43) : CT2 d'effet 2025-12-01 > A0, même partie : ligne invisible, partie non inscrite",
              list(nd_de(r43$V10), r43$V10$vue$provisoire, ctx_complet(v43$V10, A0)$retenu$contrats), list(character(0), FALSE, c(TRUE, FALSE)))
ctx11 <- ctx_complet(v43$V11, A0)
verifier_egal("V11 (#43) : ME1 en deux versions (v1 saisie le 2025-02-01, v2 sans date de saisie, D03g) : version valable non déterminée, aucune version désignée dans la vue ; .connus() NA pour les candidates ; v2 inscrite sous D03g, v1 non inscrite ; filles du membre visible (règle 1 : « le membre est visible »)",
              list(ctx11$retenu$famille, ns$.connus(ctx11, "famille"), nd_de(r43$V11), ns$.connus(ctx11, "rentes"),
                   ns$.connus(ctx11, "beneficiaires"), ctx11$retenu$rentes),
              list(c(FALSE, FALSE), c(NA, NA), "famille NA D03g NA 1 ME1|NA", TRUE, TRUE, TRUE))
verifier_egal("V12 (#43, point P5) : refus du sexe d'une version remplacée de ME1 : nombre_visibles 0 à l'extraction comme à A0 ; .connus() de la version remplacée FALSE à l'extraction",
              list(refus(cb(v43$V12, A), "hors_domaine", "famille", "sexe")$nombre_visibles, refus(r43$V12, "hors_domaine", "famille", "sexe")$nombre_visibles,
                   ns$.connus(ctx_complet(v43$V12, A), "famille")),
              list(0L, 0L, c(FALSE, TRUE)))
# W3 (#40) : candidates d'un membre à version valable non déterminée sans version désignée
# dans la vue (V11) : la règle V D03a ne voit plus v1 ; le verdict à trois valeurs sur chaque
# candidate (§ 2.2 (d), M218) et sa ligne de controles_non_executes viennent avec #40
attendu_echec("W3 (#40) : base V11 à A0 : D03a sur famille.date_naissance non exécuté, cause declaration_absente (verdict inconnu sur les candidates)",
              "#40", identical(ligne(r43$V11$controles_non_executes, "D03a", "famille", "date_naissance")$cause, "declaration_absente"))
# v1.5.1 (#43, Q1) : ligne de D03g sans déclaration dont la date d'effet de l'hypothèse est
# refusée (D02c, postérieure à l'extraction) : non déterminée sous D03g et sous le refus
q1e <- avec(function(b) { b$evenements$date_saisie[3L] <- NA; b$evenements$date_effet[3L] <- D("2027-03-01"); b })
q1s <- avec(function(b) { b$sinistres$date_saisie[2L] <- NA; b$sinistres$date_declaration[2L] <- NA; b })
verifier_egal("Q1 (#43, v1.5.1) : D03g sans déclaration, date d'effet refusée (evenements.date_effet D02c ; sinistres.date_declaration manquante) : inscrite sous D03g et sous le refus, nombre_visibles NA, exigences et vue provisoire inchangées",
              list(nd_de(cb(q1e, A0))[grepl("EV3", nd_de(cb(q1e, A0)))], refus(cb(q1e, A0), "D02c", "evenements", "date_effet")$nombre_visibles,
                   nd_de(cb(q1s, A0))[startsWith(nd_de(cb(q1s, A0)), "sinistres")],
                   requises43(cb(q1s, A0)), cb(q1s, A0)$vue$provisoire),
              list(c("evenements NA D02c evenements.date_effet 1 EV3", "evenements NA D03g NA 1 EV3"), NA_integer_,
                   c("sinistres NA D03g NA 1 SI2", "sinistres NA manquant_obligatoire sinistres.date_declaration 1 SI2"),
                   attendu_d03g("sinistres"), TRUE))
# V13 : concordance ligne à ligne de la vue et des comptes, sur toute table non refusée en
# portée table (aucune exclusion de D03g déclarée dans le corpus) : ligne retenue ⟺ statut
# visible ; statut non déterminé ⟺ ligne inscrite, ou version candidate de famille, ou ligne
# d'adherents ou d'assures citée seulement par des lignes non déterminées ; partie masquée
# d'une ligne retenue ⟺ partie non connue à A ou non déterminée ; partie non déterminée ⟺
# partie inscrite
concordance43 <- function(b, arrete, declarations = NULL) {
  ctx <- ctx_complet(b, arrete, declarations)
  ev <- ns$.visibilite_a(ctx, "vue")
  inscrites <- function(t, colonne) {
    l <- integer(0)
    for (k in ctx$lignes_nd) if (k$table == t && identical(k$colonne, colonne)) l <- c(l, k$lignes)
    seq_along(ctx$retenu[[t]]) %in% l
  }
  all(vapply(setdiff(ctx$tables, "extraction"), function(t) {
    if (!is.null(ctx$refus_pv$tables[[t]])) return(TRUE)
    con <- ns$.connus(ctx, t)
    nd <- inscrites(t, NA_character_)
    autre <- if (t == "famille") ev$statut$famille %in% TRUE & is.na(ev$valable) else
      if (t %in% c("adherents", "assures")) is.na(con) else rep(FALSE, length(con))
    ok <- identical(ctx$retenu[[t]], con %in% TRUE) && identical(is.na(con), nd | autre) && !any(nd & autre)
    for (p in ns$.PARTIES_LIGNE) {
      if (p$table != t) next
      brut <- !is.na(ns$.valeurs(ctx, t, p$colonnes[1L]))
      masque <- is.na(ns$.valeurs_vue(ctx, t, p$colonnes[1L])) & brut & ctx$retenu[[t]]
      vus <- ctx$retenu[[t]] & brut
      ok <- ok && identical(masque[vus], !(ev$parties[[t]][vus] %in% TRUE)) &&
        identical(is.na(ev$parties[[t]])[ctx$retenu[[t]]], inscrites(t, p$date)[ctx$retenu[[t]]])
    }
    ok
  }, NA))
}
corpus43 <- c(lapply(names(v43), function(nom) list(v43[[nom]], arrete43(nom))),
              list(list(pb, A0), list(pb, D("2024-05-15")), list(pb, A0, list(hypotheses = hyp2("D02b"))), list(b8, A0),
                   list(c9b, A0), list(q2, A0, list(hypotheses = hyp2("D03g"), seuils = list(d03g_delai_jours = list(famille = 0, beneficiaires = 0)))),
                   list(o5, A0, dec5), list(m6, A0), list(m6, A0, list(hypotheses = hyp2("D02b"))), list(multi, A0)),
              lapply(v33, function(b) list(b, A0)), lapply(d12, function(b) list(b, A0)))
verifier("V13 (#43) : concordance ligne à ligne de la vue et des comptes (statut visible, non déterminé, partie masquée ou non déterminée), sur les bases des critères V1 à V12, de la règle P, de #33 et de D12",
         all(vapply(corpus43, function(k) concordance43(k[[1L]], k[[2L]], if (length(k) > 2L) k[[3L]]), NA)))
# V14 : batterie (b) du critère 6 : chaque ligne (ou partie) de D02b ou de D03g détectée sans
# déclaration est rejouée sous chaque traitement admis (hypothèse de D02b, avec l'hypothèse
# de D03g à délai nul, l'hypothèse de D03g à délai qui dépasse A − date d'effet, ou
# l'exclusion de D03g et l'hypothèse à délai nul pour les parties de ligne) ; elle est
# invisible de façon déterminée si et seulement si elle n'est visible sous aucun d'eux, non
# déterminée sinon
tables_d03g43 <- c("affiliations", "famille", "sinistres", "beneficiaires", "rentes", "evenements", "prestations", "designations",
                   "ayants_droit_sante", "contrats")
delais43 <- function(x) list(d03g_delai_jours = stats::setNames(as.list(rep(x, length(tables_d03g43))), tables_d03g43))
plans43 <- list(h0 = list(hypotheses = c(hyp2("D02b"), hyp2("D03g")), seuils = delais43(0)),
                hmax = list(hypotheses = c(hyp2("D02b"), hyp2("D03g")), seuils = delais43(100000)),
                x = list(hypotheses = c(hyp2("D02b"), hyp2("D03g")), exclusions = excl4("D03g"), seuils = delais43(0)))
statut43 <- function(ctx, t, i, partie) {
  inscrite <- any(vapply(ctx$lignes_nd, function(k) k$table == t && identical(k$colonne, partie) && i %in% k$lignes, NA))
  if (inscrite) return("nd")
  if (is.na(partie)) return(if (ctx$retenu[[t]][i]) "visible" else "invisible")
  if (isTRUE(ns$.visibilite_a(ctx, "vue")$parties[[t]][i])) "visible" else "invisible"
}
batterie_b43 <- function(b, arrete) {
  ctx0 <- ctx_complet(b, arrete)
  ctxs <- lapply(plans43, function(p) ctx_complet(b, arrete, p))
  k <- Filter(function(k) k$code %in% c("D02b", "D03g"), ctx0$constats)
  all(unlist(lapply(k, function(k) vapply(k$lignes, function(i) {
    partie <- if (identical(k$colonne, "date_saisie_fin")) "date_saisie_fin" else NA_character_
    s0 <- statut43(ctx0, k$table, i, partie)
    s <- vapply(ctxs, statut43, "", k$table, i, partie)
    !any(s == "nd") && s0 == (if (any(s == "visible")) "nd" else "invisible")
  }, NA))))
}
verifier("V14 (#43, critère 6 (b)) : batterie de substitution de la visibilité : invisible de façon déterminée si et seulement si visible sous aucun traitement admis, non déterminée sinon (bases V1 à V10, règle P à A0 et au 2024-05-15, sinistre saisi après A0)",
         all(vapply(list(list(v43$V1, A0), list(v43$V2, A0), list(v43$V3, D("2024-12-31")), list(v43$V4, A0), list(v43$V5, A0),
                         list(v43$V6, A0), list(v43$V7, A0), list(v43$V8, A0), list(v43$V9, A0), list(v43$V10, A0), list(pb, A0),
                         list(pb, D("2024-05-15")), list(b8, A0)), function(k) batterie_b43(k[[1L]], k[[2L]]), NA)))

section("donnees : D02c (âge), D07 (c), causes directes (D12), enjeu sous lien de garantie non résolu")
emplois <- names(ns$.EMPLOIS_D02C)
seuils_age <- function(mini, maxi, sauf = character(0)) {
  e <- setdiff(emplois, sauf)
  list(d02c_age_min = as.list(stats::setNames(rep(mini, length(e)), e)), d02c_age_max = as.list(stats::setNames(rep(maxi, length(e)), e)))
}
conv_age <- list(age = "revolu", limite_age = list(regle = "atteinte", age = "revolu"))
requises_hc <- function(r) {
  x <- r$declarations_requises[is.na(r$declarations_requises$nombre_lignes), , drop = FALSE]
  paste(x$rubrique, x$motif, x$cle, x$traitements_admis)
}
r <- controler_base(base_ref, A)
verifier_egal("sans déclaration : seuils de D02c attendus par emploi (cle <seuil>$<emploi>, traitements_admis et nombre_lignes NA), conventions age et limite_age attendues",
              requises_hc(r), c(paste("seuils D02c", sort(c(paste0("d02c_age_max$", emplois), paste0("d02c_age_min$", emplois)),
                                                          method = "radix"), "NA"),
                                "conventions D02c age revolu;millesime;plus_proche;naissance_31_decembre",
                                "conventions D07 limite_age$age revolu;millesime", "conventions D07 limite_age$regle atteinte;depassement"))
# une ligne seuils de D02c existe si et seulement si le contrôle qui la lit est écrit, sa table
# présente, et le seuil absent
b_sans <- base_ref; b_sans$designations <- NULL
verifier_egal("D02c : une ligne seuils existe ssi le seuil est absent (table présente) ; aucune avec tous les seuils ; aucune pour une table absente",
              list(requises_hc(controler_base(base_ref, A, declarations = list(seuils = seuils_age(0, 120)), conventions = conv_age)),
                   requises_hc(controler_base(base_ref, A, declarations = list(seuils = seuils_age(0, 120, "famille")), conventions = conv_age)),
                   grep("designations", requises_hc(controler_base(b_sans, A)), value = TRUE)),
              list(character(0), c("seuils D02c d02c_age_max$famille NA", "seuils D02c d02c_age_min$famille NA"), character(0)))
r <- controler_base(base_ref, A, declarations = list(seuils = seuils_age(0, 120, "famille")), conventions = conv_age)
verifier_egal("D02c : emploi sans seuil non exécuté (colonne NA, declaration_absente), les autres exécutés",
              as.list(ligne(r$controles_non_executes, "D02c", NULL)[, c("table", "colonne", "cause")]),
              list(table = "famille", colonne = NA_character_, cause = "declaration_absente"))
r <- controler_base(base_ref, A, declarations = list(seuils = seuils_age(18, 60)), conventions = conv_age)
verifier_egal("D02c : âge hors bornes (18-60) en S + X sur date_naissance : ME1 (14 ans à la survenance de SI1), DS1, AY1 (à la saisie) ; AS1 (54 ans) non",
              list(paste(ligne(r$controles, "D02c")$table, ligne(r$controles, "D02c")$identifiants),
                   ligne(r$signalements, "D02c")$table, unique(ligne(r$controles, "D02c")$colonne),
                   r$declarations_requises$cle[r$declarations_requises$motif == "D02c"]),
              list(rep(c("famille ME1|2025-02-01", "designations DS1", "ayants_droit_sante AY1"), each = 2L),
                   c("famille", "designations", "ayants_droit_sante"), "date_naissance", ns$FAMILLES_CALCUL))
verifier_egal("D02c : la convention d'âge est lue (borne max 54 ; AS1 né le 1970-05-10, sinistre SI1 du 2025-01-10 : 54 ans revolu, 55 millesime ; AS2, contrat individuel CT2 : 56 ans)",
              list(ligne(controler_base(base_ref, A, declarations = list(seuils = seuils_age(18, 54)),
                                        conventions = list(age = "revolu"))$controles, "D02c", "assures")$identifiants,
                   ligne(controler_base(base_ref, A, declarations = list(seuils = seuils_age(18, 54)),
                                        conventions = list(age = "millesime"))$controles, "D02c", "assures")$identifiants),
              list(c("AS2", "AS2"), c("AS1;AS2", "AS1;AS2")))
b <- avec(function(b) { b$designations$date_saisie <- D("2009-01-01"); b })
r <- controler_base(b, A, declarations = list(seuils = seuils_age(0, 120)), conventions = conv_age)
verifier_egal("D02c : date de référence antérieure à la naissance (DS1 saisie avant sa naissance) : âge non défini, non exécuté (age_non_defini)",
              ligne(r$controles_non_executes, "D02c", "designations")$cause, "age_non_defini")
for (cas in list(list("seuil négatif", list(d02c_age_min = list(famille = -1))),
                 list("seuil non entier", list(d02c_age_max = list(famille = 60.5))),
                 list("emploi inconnu", list(d02c_age_min = list(assures = 18))),
                 list("min > max", list(d02c_age_min = list(famille = 70), d02c_age_max = list(famille = 60))))) {
  verifier_egal(paste("D02c : seuils mal formés :", cas[[1L]], ": plan_invalide"),
                motif_de(controler_base(base_ref, A, declarations = list(seuils = cas[[2L]]))), "plan_invalide")
}
# D07 (c)
cv <- function(regle, age = "revolu") list(limite_age = list(regle = regle, age = age))
d07 <- function(r) { x <- ligne(r$controles, "D07"); paste(x$table, x$identifiants) }
nais <- function(dn) avec(function(b) { b$famille$date_naissance <- D(dn); b })
verifier_egal("D07 (c) : rente d'éducation RE1 (age_limite 26, arrêté 2026-12-31) : atteinte (26 ans révolus) détectée, dépassement non ; 25 ans : rien",
              list(d07(cb(nais("2000-03-01"), conventions = cv("atteinte"))), d07(cb(nais("2000-03-01"), conventions = cv("depassement"))),
                   d07(cb(nais("2001-01-01"), conventions = cv("atteinte", "millesime"))), d07(cb(nais("2000-12-31"), conventions = cv("atteinte", "millesime"))),
                   d07(cb(nais("1999-03-01"), conventions = cv("depassement")))),
              list("rentes RE1", character(0), character(0), "rentes RE1", "rentes RE1"))
de <- function(dn, ph = FALSE, sit = "scolarise", clos = FALSE, limites = c(age_limite = 26), second = NULL) avec(function(b) {
  b$famille$date_naissance <- D(dn); b$famille$situation <- sit
  g <- b$garanties_souscrites[1L, ]; g$id_garantie_souscrite <- "GS5"; g$code_garantie <- "double_effet"; g$option_iad <- NA
  g$clause_type_beneficiaire <- NA; g$conjoint_vise <- "marie"; g$versement_double_effet <- "global"; g$non_remariage <- FALSE
  g$maintien_double_effet <- FALSE; g$prolongation_handicap <- ph
  b$garanties_souscrites <- rbind(b$garanties_souscrites, g)
  b$parametres <- rbind(b$parametres, tab("parametres", id_garantie_souscrite = "GS5",
                                          parametre = c("taux_capital", names(limites), "taux_revalorisation"),
                                          valeur = c(1, unname(limites), 0)))
  b$dossiers <- rbind(b$dossiers, tab("dossiers", id_dossier = "DO4", id_sinistre = "SI1", id_garantie_souscrite = "GS5",
                                      date_ouverture = D("2025-02-02")))
  if (clos) b$evenements <- rbind(b$evenements, transform(b$evenements[4L, ], id_evenement = "EV9", id_dossier = "DO4",
                                                          type_evenement = "cloture_dossier", montant = NA, motif = "regle"))
  # second décès du conjoint (date d'effet `second`, saisi quatre jours après)
  if (!is.null(second)) b$evenements <- rbind(b$evenements, transform(b$evenements[4L, ], id_evenement = "EV8", id_dossier = "DO4",
                                                                      type_evenement = "second_deces", montant = NA,
                                                                      date_effet = D(second), date_saisie = D(second) + 4,
                                                                      source_information = "courrier"))
  b })
r <- cb(de("1999-03-01"), conventions = cv("atteinte"))
verifier_egal("D07 (c) : double effet DO4 non clos, enfant à charge de 27 ans : détecté (dossiers, colonne NA), hypothèse attendue par référentiel (H;S) ; base sans refus",
              list(d07(r), unique(ligne(r$controles, "D07")$colonne), nrow(r$refus_tables),
                   r$declarations_requises$traitements_admis[r$declarations_requises$motif == "D07"]),
              list(c("dossiers DO4", "rentes RE1"), NA_character_, 0L, c("H;S", "H;S")))
verifier_egal("D07 (c) : non détecté si l'enfant est jeune, si le dossier est clos, ou handicapé sous prolongation_handicap ; détecté handicapé sans prolongation",
              list(d07(cb(de("2010-03-01"), conventions = cv("atteinte"))), d07(cb(de("1999-03-01", clos = TRUE), conventions = cv("atteinte"))),
                   d07(cb(de("1999-03-01", TRUE, "handicape"), conventions = cv("atteinte"))),
                   d07(cb(de("1999-03-01", FALSE, "handicape"), conventions = cv("atteinte")))),
              list(character(0), "rentes RE1", "rentes RE1", c("dossiers DO4", "rentes RE1")))
hy_d07 <- list(hypotheses = list(list(motif = "D07", referentiel = "comptes_sociaux", poste = "tous", valeur = "extinction"),
                                 list(motif = "D07", referentiel = "solvabilite_2", poste = "tous", valeur = "signalement")))
r <- cb(de("1999-03-01"), conventions = cv("atteinte"), declarations = hy_d07)
verifier_egal("D07 (c) : hypothèse (comptes sociaux) et signalement (Solvabilité II) déclarés : placés, aucune attente",
              list(r$hypotheses_defaut$nombre[r$hypotheses_defaut$motif == "D07"], ligne(r$signalements, "D07")$table,
                   sum(r$declarations_requises$motif == "D07")),
              list(2L, c("dossiers", "rentes"), 0L))
# avis d'actuary, Q3 (b) : le droit au capital se fixe au second décès
verifier_egal("D07 (c) : double effet DO4 dont le second décès (effet 2026-01-01) est retenu à l'arrêté : non détecté ; à un arrêté antérieur (2025-06-30, 26 ans révolus) : détecté",
              list(d07(cb(de("1999-03-01", second = "2026-01-01"), conventions = cv("atteinte"))),
                   "dossiers DO4" %in% d07(cb(de("1999-03-01", second = "2026-01-01"), A0, conventions = cv("atteinte")))),
              list("rentes RE1", TRUE))
# décision du mainteneur : la prolongation pour études vaut pour un enfant scolarise ou
# apprenti (jugement d'expert)
etudes <- c(age_limite = 26, age_limite_etudes = 28)
verifier_egal("D07 (c) : enfant de 27 ans scolarise ou apprenti, age_limite_etudes 28 : non éteint (DO4 non détecté) ; situation autre : éteint à age_limite 26",
              list(d07(cb(de("1999-03-01", sit = "scolarise", limites = etudes), conventions = cv("atteinte"))),
                   d07(cb(de("1999-03-01", sit = "apprenti", limites = etudes), conventions = cv("atteinte"))),
                   d07(cb(de("1999-03-01", sit = "autre", limites = etudes), conventions = cv("atteinte")))),
              list("rentes RE1", "rentes RE1", c("dossiers DO4", "rentes RE1")))
# avis d'actuary, Q3 (a) : limite non déterminable pour une ligne candidate
nd_d07 <- function(r) { x <- ligne(r$controles_non_executes, "D07", NULL); paste(x$table, x$colonne, x$cause)[x$table != "evenements"] }
sans_limite_re1 <- avec(function(b) { b$parametres <- b$parametres[!(b$parametres$parametre %in% "age_limite"), ]; b })
deux_limites_re1 <- avec(function(b) {
  b$parametres <- rbind(b$parametres[!(b$parametres$parametre %in% "age_limite"), ],
                        tab("parametres", id_garantie_souscrite = "GS3", parametre = "age_limite", age_min = c(0L, 18L),
                            age_max = c(17L, 120L), valeur = c(25, 26)))
  b })
deux_etudes_do4 <- local({
  b <- de("1999-03-01", sit = "apprenti", limites = etudes)
  b$parametres <- rbind(b$parametres[!(b$parametres$parametre %in% "age_limite_etudes"), ],
                        tab("parametres", id_garantie_souscrite = "GS5", parametre = "age_limite_etudes", age_min = c(0L, 18L),
                            age_max = c(17L, 120L), valeur = c(28, 30)))
  b })
verifier_egal("D07 (c) : age_limite absent (RE1), à deux valeurs par palier (RE1), absent (DO4), age_limite_etudes à deux valeurs pour un apprenti (DO4) : non exécuté (colonne NA, parametre_non_defini), aucune détection sur la ligne",
              list(nd_d07(cb(nais("1990-03-01"), conventions = cv("atteinte"))),
                   nd_d07(cb(sans_limite_re1, conventions = cv("atteinte"))), d07(cb(sans_limite_re1, conventions = cv("atteinte"))),
                   nd_d07(cb(deux_limites_re1, conventions = cv("atteinte"))),
                   nd_d07(cb(de("1999-03-01", limites = c(age_limite_conjoint = 65)), conventions = cv("atteinte"))),
                   nd_d07(cb(deux_etudes_do4, conventions = cv("atteinte")))),
              list(character(0), "rentes NA parametre_non_defini", character(0), "rentes NA parametre_non_defini",
                   "dossiers NA parametre_non_defini", "dossiers NA parametre_non_defini"))
# avis d'actuary après l'audit de (iii) : sur un dossier double_effet à plusieurs enfants, la
# limite non déterminable n'est notée que si elle peut décider de la détection. DO4 : ME1
# (situation autre, age_limite 26 déterminée) et ME2 (apprenti de 27 ans, age_limite_etudes à
# deux valeurs) ; ME1 de 16 ans, non éteint de façon déterminée, écarte le dossier quel que soit
# ME2 ; ME1 de 27 ans, éteint, laisse la détection suspendue à ME2
deux_enfants_do4 <- function(dn1) {
  b <- deux_etudes_do4
  b$famille <- rbind(transform(b$famille, date_naissance = D(dn1), situation = "autre"),
                     transform(b$famille, id_membre = "ME2", date_naissance = D("1999-03-01"), situation = "apprenti"))
  b
}
r_jeune <- cb(deux_enfants_do4("2010-03-01"), conventions = cv("atteinte"))
r_eteint <- cb(deux_enfants_do4("1999-03-01"), conventions = cv("atteinte"))
verifier_egal("D07 (c) : DO4 à deux enfants, ME1 jeune (limite déterminée non atteinte) et ME2 au paramètre ambigu : aucune ligne parametre_non_defini, aucune détection ; ME1 éteint et ME2 ambigu : ligne maintenue (dossiers, colonne NA), aucune détection de DO4",
              list(nd_d07(r_jeune), d07(r_jeune), nd_d07(r_eteint), d07(r_eteint)),
              list(character(0), character(0), "dossiers NA parametre_non_defini", "rentes RE1"))
# avis d'actuary (réserve m1 de l'audit) : un enfant jamais éteint (handicapé sous
# prolongation_handicap, ou de naissance manquante, D03a) écarte lui aussi le dossier quel que
# soit l'enfant ambigu ; témoin : ME1 handicapé sans prolongation, éteint à 27 ans
b1 <- deux_enfants_do4("1999-03-01"); b1$famille$situation[b1$famille$id_membre != "ME2"] <- "handicape"
b1$garanties_souscrites$prolongation_handicap[b1$garanties_souscrites$id_garantie_souscrite == "GS5"] <- TRUE
b1b <- b1; b1b$garanties_souscrites$prolongation_handicap[b1b$garanties_souscrites$id_garantie_souscrite == "GS5"] <- FALSE
b2 <- deux_enfants_do4("1999-03-01"); b2$famille$date_naissance[b2$famille$id_membre != "ME2"] <- NA
r_b2 <- cb(b2, conventions = cv("atteinte"))
verifier_egal("D07 (c) : DO4, ME1 handicapé sous prolongation_handicap et ME2 ambigu : aucune ligne parametre_non_defini ; sans prolongation (témoin) : ligne maintenue ; ME1 de naissance manquante (D03a émis) et ME2 ambigu : aucune ligne",
              list(nd_d07(cb(b1, conventions = cv("atteinte"))), nd_d07(cb(b1b, conventions = cv("atteinte"))), nd_d07(r_b2),
                   unique(paste(ligne(r_b2$controles, "D03a")$table, ligne(r_b2$controles, "D03a")$colonne,
                                ligne(r_b2$controles, "D03a")$identifiants))),
              list(character(0), "dossiers NA parametre_non_defini", character(0), "famille date_naissance ME1|2025-02-01"))
# constat M2 de l'audit : aucune conversion d'une colonne refusée avant le contrôle des causes
# (la batterie tourne sous options(warn = 2))
op <- options(warn = 2)
m2 <- lapply(list(avec(function(b) { b$famille$date_deces <- rep("abc", nrow(b$famille)); b }),
                  avec(function(b) { b$evenements$date_effet <- rep("abc", nrow(b$evenements)); b })), function(b)
  tryCatch(nd_d07(cb(b, conventions = cv("atteinte"))), error = function(e) conditionMessage(e)))
options(op)
verifier_egal("D07 (c) sous options(warn = 2), famille.date_deces ou evenements.date_effet en chaîne : sans avertissement, non exécuté (type_incompatible) sur dossiers et rentes",
              m2, rep(list(c("dossiers NA type_incompatible", "rentes NA type_incompatible")), 2L))
# constat m1 de l'audit : croissance avec D02c et D07 (c) exécutés (seuils et conventions
# déclarés) : n dossiers double effet non clos de l'assuré de ME1 (n paires enfant, dossier)
# et n conjoints en famille (D02c) ; travail de controler_base à 4 000 et 1 000 dossiers (même
# mesure et même borne que le test de croissance précédent ; environ 3,7 si linéaire, 8,6 si
# calculer_age accumule ses résultats élément par élément ; mesuré). Les garanties y sont peu
# nombreuses : la croissance en nombre de garanties portant un paramètre (constat M3) est
# testée à la section règle B (#35 ; .chevauchements, hors de D07 (c), y était quadratique).
perf_decl <- function(n) {
  b <- de("1999-03-01")
  dz <- b$dossiers[rep(nrow(b$dossiers), n), ]; dz$id_dossier <- sprintf("DX%06d", seq_len(n)); b$dossiers <- rbind(b$dossiers, dz)
  fz <- b$famille[rep(1L, n), ]; fz$id_membre <- sprintf("MX%06d", seq_len(n)); fz$lien <- "conjoint"; fz$situation <- NA
  b$famille <- rbind(b$famille, fz)
  b
}
travail_decl <- function(n) {
  travail_cb(perf_decl(n), declarations = list(seuils = seuils_age(0, 120)), conventions = conv_age)
}
r <- cb(perf_decl(20L), declarations = list(seuils = seuils_age(0, 120)), conventions = conv_age)
verifier("performance : D02c et D07 (c) exécutés (aucun non exécuté hors evenements) ; travail de 1 000 à 4 000 dossiers double effet et conjoints multiplié par moins de 6",
         nrow(ligne(r$controles_non_executes, c("D02c", "D07"), NULL)) == 1L && ligne(r$controles, "D07", "dossiers")$nombre == 21L &&
           travail_decl(4000L) / travail_decl(1000L) < 6)
verifier("D07 (c) : convention de limite d'âge hors liste : plan_invalide (M164)",
         all(c(motif_de(cb(base_ref, conventions = cv("atteinte", "plus_proche"))),
               motif_de(cb(base_ref, conventions = cv("atteinte", "naissance_31_decembre"))),
               motif_de(cb(base_ref, conventions = cv("au_terme")))) == "plan_invalide"))
# point 4 d'actuary : cause directe prioritaire sur le refus induit d'une règle P empêchée (D12)
r <- cb(multi, A0)
verifier_egal("D12 : une règle V empêchée par une cause directe (contrats.date_effet type_incompatible) et par le refus induit D12 de sa table garde la cause directe ; D03g (rejouée) garde refus_induit",
              list(ligne(r$controles_non_executes, "D02a", "contrats", "date_terme")$cause,
                   ligne(r$controles_non_executes, "D03f", "cotisations", NA)$cause,
                   ligne(r$controles_non_executes, "D03g", "contrats", "date_saisie_fin")$cause,
                   refus(r, "refus_induit", "contrats")$origine),
              list("type_incompatible", "type_incompatible", "refus_induit", "contrats.date_effet"))
# M185 : la cause directe prime sur tout refus induit, celui de la règle B compris
# (clé étrangère visant une table refusée) ; ordre : non_implemente, cause directe, refus_induit
r <- cb(avec(function(b) { b$adherents$autre <- 1; b$contrats$date_terme <- as.character(b$contrats$date_terme); b }))
verifier_egal("M185, règle B : contrats refusée par refus_induit (adherents refusée) et contrats.date_terme refusée pour son type : D02a garde la cause directe ; D02a sur date_fin (refus induit seul) garde refus_induit",
              list(refus(r, "refus_induit", "contrats")$origine,
                   ligne(r$controles_non_executes, "D02a", "contrats", "date_terme")$cause,
                   ligne(r$controles_non_executes, "D02a", "contrats", "date_fin")$cause),
              list("adherents", "type_incompatible", "refus_induit"))
r <- cb(avec(function(b) { b$sinistres$autre <- 1; b }))
verifier_egal("M185, règle B, deux règles de même clé : D02b sur evenements.date_saisie, empêchée par le refus induit de evenements (date d'effet) et par le refus direct de sinistres (lien de la fille), garde la cause directe",
              list(refus(r, "refus_induit", "evenements")$origine,
                   ligne(r$controles_non_executes, "D02b", "evenements", "date_saisie")$cause),
              list("sinistres;dossiers;rentes", "colonne_inconnue"))
r <- cb(avec(function(b) { b$adherents$autre <- 1; b$evenements$date_saisie <- as.character(b$evenements$date_saisie); b }))
x <- r$enjeu[r$enjeu$composante == "montant_evenement", ]
verifier_egal("M185, enjeu : montant_evenement lit evenements.montant (refus induit) puis evenements.date_saisie (type incompatible) : la composante porte la cause directe",
              list(unique(x$cause), with(ligne(r$controles_non_executes, "montant_evenement", "evenements"), paste(colonne, cause))),
              list("type_incompatible", "date_saisie type_incompatible"))
# #38 : un refus induit de portée table né d'une règle P empêchée (D12, M178) se combine à
# d'autres refus. Défaut de forme : sinistres.date_declaration en texte (type_incompatible),
# lue par la règle P de la vue à A0 (2025-06-30, antérieur à l'extraction) ; les tables qui
# en dépendent portent un refus_induit d'origine sinistres.date_declaration, puis de proche
# en proche. D02c sur assures lit sinistres (emploi assures_sinistre : des lignes refus_induit
# d'abord) puis affiliations (emploi assures_affiliation : une autre cause pour la même clé
# (D02c, assures, NA)). (a) cette autre cause est declaration_absente (seuil
# assures_affiliation absent) ; (b) elle est age_non_defini (AS1 née après le début de son
# affiliation, seuils complets). Ordre des causes décidé en M194 et M195 (age_non_defini au
# rang 4, declaration_absente au rang 6, refus_induit au rang 7) : la cause visée est celle
# de l'autre emploi, rendue à A0 comme à l'extraction (#36 ; avant #36, la première cause
# émise, refus_induit). Le refus_induit naît d'un défaut de forme, non d'une valeur
# manquante : le cas reste valable après #33.
form_d12 <- avec(function(b) { b$sinistres$date_declaration <- as.character(b$sinistres$date_declaration); b })
form_d12_age <- avec(function(b) { b$sinistres$date_declaration <- as.character(b$sinistres$date_declaration)
                                   b$assures$date_naissance[1L] <- D("2016-06-01"); b })
seuils_sans_affiliation <- seuils_age(0, 120)
seuils_sans_affiliation$d02c_age_max$assures_affiliation <- NULL
refus_induits_d12 <- function(r) {
  x <- r$refus_tables[r$refus_tables$motif == "refus_induit", ]
  paste0(x$table, "<-", x$origine)
}
induits_attendus <- c("famille<-sinistres", "sinistres<-sinistres.date_declaration", "dossiers<-sinistres",
                      "beneficiaires<-famille;dossiers", "rentes<-famille;dossiers", "evenements<-sinistres;dossiers;rentes",
                      "prestations<-dossiers;rentes", "victimes<-sinistres", "evaluations_gestion<-dossiers")
r_a <- cb(form_d12, A0, declarations = list(seuils = seuils_sans_affiliation), conventions = conv_age)
verifier_egal("#38 (a) : refus induit D12 (sinistres.date_declaration en texte, A0) croisé avec D02c sur assures, seuil assures_affiliation absent : sinistres.date_declaration type_incompatible, refus induits de proche en proche ; à l'extraction, la ligne (D02c, assures, NA) porte declaration_absente",
              list(ligne(r_a$controles_non_executes, "D02c", "sinistres", "date_declaration")$cause,
                   refus_induits_d12(r_a),
                   ligne(cb(form_d12, A, declarations = list(seuils = seuils_sans_affiliation), conventions = conv_age)$controles_non_executes,
                         "D02c", "assures", NA)$cause),
              list("type_incompatible", induits_attendus, "declaration_absente"))
verifier_egal("#36, X1 (#38 (a)) : à A0, une seule ligne (D02c, assures, NA), qui porte declaration_absente (rang 6) et non refus_induit (rang 7, M195)",
              ligne(r_a$controles_non_executes, "D02c", "assures", NA)$cause, "declaration_absente")
r_b <- cb(form_d12_age, A0, declarations = list(seuils = seuils_age(0, 120)), conventions = conv_age)
verifier_egal("#38 (b) : refus induit D12 (sinistres.date_declaration en texte, A0) croisé avec age_non_defini (AS1 née le 2016-06-01, après le début de son affiliation, seuils complets) : sinistres.date_declaration type_incompatible, refus induits de proche en proche ; à l'extraction, la ligne (D02c, assures, NA) porte age_non_defini",
              list(ligne(r_b$controles_non_executes, "D02c", "sinistres", "date_declaration")$cause,
                   refus_induits_d12(r_b),
                   ligne(cb(form_d12_age, A, declarations = list(seuils = seuils_age(0, 120)), conventions = conv_age)$controles_non_executes,
                         "D02c", "assures", NA)$cause),
              list("type_incompatible", induits_attendus, "age_non_defini"))
verifier_egal("#36, X2 (#38 (b)) : à A0, une seule ligne (D02c, assures, NA), qui porte age_non_defini (rang 4) et non refus_induit (rang 7, M195)",
              ligne(r_b$controles_non_executes, "D02c", "assures", NA)$cause, "age_non_defini")
# #36, X3 : une cause directe (affiliations.date_debut manquante, manquant_obligatoire, lue par
# l'emploi assures_affiliation) prime sur declaration_absente (seuil d02c_age_max de l'emploi
# assures_sinistre absent), émise avant elle pour la même clé (D02c, assures, NA) ; avant #36,
# la première émise, declaration_absente (mesuré)
seuils_sans_sinistre <- seuils_age(0, 120)
seuils_sans_sinistre$d02c_age_max$assures_sinistre <- NULL
r <- cb(avec(function(b) { b$affiliations$date_debut[1L] <- NA; b }), A,
        declarations = list(seuils = seuils_sans_sinistre), conventions = conv_age)
verifier_egal("#36, X3 : affiliations.date_debut manquante (manquant_obligatoire, rang 3) et seuil assures_sinistre absent (declaration_absente, rang 6) : une seule ligne (D02c, assures, NA), qui porte manquant_obligatoire",
              list(refus(r, "manquant_obligatoire", "affiliations")$colonne,
                   ligne(r$controles_non_executes, "D02c", "assures", NA)$cause),
              list("date_debut", "manquant_obligatoire"))
# #36 : ordre des sept rangs (M195) sur .dedoublonner_non_executes(), une clé émise deux fois
# (spécification, § 3.1). Un représentant par rang (rang 3 : type_incompatible, cause directe) ;
# pour chacune des 21 paires de rangs, dans les deux ordres d'émission, la cause de plus petit
# rang est retenue.
causes_rangs <- c("non_implemente", "non_lisible", "type_incompatible", "age_non_defini",
                  "parametre_non_defini", "declaration_absente", "refus_induit")
ne_de <- function(causes) data.frame(code = "D02c", table = "assures", colonne = NA_character_, cause = causes,
                                     stringsAsFactors = FALSE)
dedoublonner <- function(causes) ns$.dedoublonner_non_executes(ne_de(causes), d)
paires <- utils::combn(7L, 2L)
retenues <- unlist(lapply(seq_len(ncol(paires)), function(k) {
  i <- paires[1L, k]; j <- paires[2L, k]
  c(dedoublonner(causes_rangs[c(i, j)])$cause, dedoublonner(causes_rangs[c(j, i)])$cause)
}))
verifier_egal("#36 : 21 paires des sept rangs, dans les deux ordres d'émission (42 cas) : une ligne, la cause de plus petit rang",
              retenues, causes_rangs[rep(paires[1L, ], each = 2L)])
verifier_egal("#36 : deux causes directes (rang 3), la première émise l'emporte, dans les deux ordres ; sous-cas lettré (D10a) direct",
              list(dedoublonner(c("type_incompatible", "manquant_obligatoire"))$cause,
                   dedoublonner(c("manquant_obligatoire", "type_incompatible"))$cause,
                   dedoublonner(c("D10a", "type_incompatible"))$cause,
                   dedoublonner(c("declaration_absente", "D10a"))$cause),
              list("type_incompatible", "manquant_obligatoire", "D10a", "D10a"))
x <- ns$.dedoublonner_non_executes(rbind(ne_de("refus_induit"),
                                         data.frame(code = "D02a", table = "contrats", colonne = "date_fin",
                                                    cause = c("declaration_absente", "refus_induit"), stringsAsFactors = FALSE)), d)
verifier_egal("#36 : refus_induit seul sur sa clé retenu ; deux clés, une ligne chacune, dans l'ordre de première émission",
              list(dedoublonner("refus_induit")$cause, paste(x$code, x$colonne, x$cause), rownames(x)),
              list("refus_induit", c("D02c NA refus_induit", "D02a date_fin declaration_absente"), c("1", "2")))
verifier_egal("#36 : une cause ni rangée ni motif de refus (inconnue, visibilite_non_determinee, lettre sur un code lettré D01ab ou D03hz, sous-cas non déclaré D05z) est une erreur interne ; D10a accepté",
              vapply(list(c("refus_induit", "cause_inconnue"), "visibilite_non_determinee", "D01ab", "D03hz", "D05z", "D10a"),
                     function(cz) tryCatch({ dedoublonner(cz); "aucune" }, error = function(e)
                       if (startsWith(conditionMessage(e), "erreur interne de provie : ")) "erreur interne" else "autre"), ""),
              c(rep("erreur interne", 5L), "aucune"))
# point 5 d'actuary : D10 (a) sur dossiers.id_garantie_souscrite, garantie non rattachée
q5 <- avec(function(b) { b$evenements <- b$evenements[-c(1L, 3L), ]; b$sinistres$nature_sinistre[2L] <- "deces"; b })
r <- cb(q5)
x <- r$enjeu[r$enjeu$motif == "D10a" & r$enjeu$composante == "ij_en_vigueur", ]
verifier_egal("D10 (a) sur dossiers.id_garantie_souscrite d'un dossier incapacite en service (DO3, 40 par jour) : ij_en_vigueur chiffré, rangée non_rattache, sans cause",
              list(x$garantie, x$montant, x$nombre_valeurs, x$cause),
              list(c("non_rattache", "ensemble"), c(40, 40), c(1L, 1L), rep(NA_character_, 2L)))
x <- r$enjeu[r$enjeu$motif == "D10a" & r$enjeu$garantie == "non_rattache", ]
verifier_egal("D10 (a), garantie non rattachée : capital et rente sans événement du type, aucune valeur et sans cause ; paiements inchangés",
              list(x$composante, x$montant, x$cause),
              list(ns$COMPOSANTES_ENJEU$composante[1:4], c(1240, 0, 0, 40), rep(NA_character_, 4L)))
# constat M1 de l'audit : un défaut de forme de evenements.id_rente (lu par la seule valeur
# brute de l'indemnité journalière) laisse la valeur rattachée chiffrée
r <- cb(avec(function(b) { b$evenements <- b$evenements[-3L, ]; b$evenements$id_rente <- rep(1, nrow(b$evenements)); b }))
x <- r$enjeu[r$enjeu$motif == "type_incompatible" & r$enjeu$composante == "ij_en_vigueur" & r$enjeu$famille == "ensemble", ]
verifier_egal("enjeu : evenements.id_rente de type incompatible (refus de colonne) : ij_en_vigueur rattaché (DO3, 40 par jour) chiffré, sans cause",
              list(refus(r, "type_incompatible", "evenements")$colonne, x$garantie, x$montant, x$nombre_valeurs, x$cause),
              list("id_rente", c("incapacite", "ensemble"), c(40, 40), c(1L, 1L), rep(NA_character_, 2L)))
# disjonction (ADR 0010, neuvième série, (c)) : les noms des composantes d'enjeu, codes des
# lignes de composantes dans controles_non_executes, ne recoupent aucun code de contrôle ni de défaut
verifier_egal("disjonction : composantes d'enjeu et codes de controles.csv et defauts.csv",
              intersect(unique(ns$COMPOSANTES_ENJEU$composante), c(d$controles$code, d$defauts$code)), character(0))
# M185, #36 : toute cause de controles_non_executes rangée (.RANGS_CAUSES) ou motif de refus
# (cause directe : code de controles.csv ou de defauts.csv, ou sous-cas lettré déclaré de
# .TRAITEMENTS_SOUS_CAS_D10 : D10a, D10h), le rang cherché d'abord (refus_induit
# est aussi un code de controles.csv), sur l'ensemble des appels de controler_base() du
# fichier, qui couvrent les cinq causes non directes émises par le moteur ; les rangs sont
# ceux de M195 (refus_induit au rang 7, cause directe au rang 3)
rangee <- causes_vues %in% names(ns$.RANGS_CAUSES)
motif_refus <- !rangee & causes_vues %in% c(d$controles$code, d$defauts$code, names(ns$.TRAITEMENTS_SOUS_CAS_D10))
verifier_egal("M185, #36 : causes de controles_non_executes toutes rangées ou motifs de refus (appels du fichier, cinq causes non directes couvertes) ; rangs 1 à 7 de M195",
              list(causes_vues[!rangee & !motif_refus],
                   setdiff(c("non_implemente", "declaration_absente", "non_lisible", "age_non_defini", "parametre_non_defini"),
                           causes_vues),
                   ns$.RANGS_CAUSES, ns$.RANG_CAUSE_DIRECTE),
              list(character(0), character(0),
                   c(non_implemente = 1L, non_lisible = 2L, age_non_defini = 4L, parametre_non_defini = 5L,
                     declaration_absente = 6L, refus_induit = 7L), 3L))
verifier("#36 : visibilite_non_determinee jamais cause de controles_non_executes (appels du fichier)",
         !("visibilite_non_determinee" %in% causes_vues))
