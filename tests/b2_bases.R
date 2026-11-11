# Bases, tables et plan des tests de la branche B2 (familles « engagement » et « risque en
# cours », #66 ; spécification de B2, docs/specifications/b2-capital-deces-v1.md, § 3.6, § 7.4
# et § 7.5). Sourcé par tests/unitaires/engagement.R et tests/unitaires/risque_en_cours.R
# (le package est chargé ; `racine` est défini). Aucune donnée réelle : bases construites à
# la main, table et série fictives déclarées.
#
# Table et série fictives (spécification de B2, § 3.6 ; mêmes valeurs que tests/unitaires/tables.R) :
#   - mortalite_fictive_b2 : table fictive, sans source ; âges 40 à 43, l_x = 100 000 ; 99 000 ;
#     97 020 ; 94 109,4 ;
#   - tme_fictive_b2 : série fictive, sans source ; 3,00 % de 2023-01 à 2024-09 ; 3,20 % en
#     2024-10 ; 3,00 % de 2024-11 à 2025-09 ; 2,40 % en 2025-10 ; 3,00 % de 2025-11 à 2025-12.

b2_ns <- asNamespace("provie")
b2_dico <- dictionnaire()
D <- function(x) as.Date(x)
b2_na <- function(type, n) switch(type, character = rep(NA_character_, n), integer = rep(NA_integer_, n),
  numeric = rep(NA_real_, n), logical = rep(NA, n), Date = as.Date(rep(NA_character_, n)))
# Table `table` de n lignes : colonnes du dictionnaire dans leur ordre, valeurs données, NA sinon.
b2_tab <- function(table, ...) {
  v <- list(...)
  col <- b2_dico$colonnes[b2_dico$colonnes$table == table, , drop = FALSE]
  stopifnot(all(names(v) %in% col$colonne))
  n <- if (length(v)) max(lengths(v)) else 0L
  df <- as.data.frame(lapply(seq_len(nrow(col)), function(i) {
    x <- v[[col$colonne[i]]]
    if (is.null(x)) b2_na(col$type[i], n) else rep_len(x, n)
  }), stringsAsFactors = FALSE)
  names(df) <- col$colonne
  df
}

b2_tables <- function() {
  mort <- b2_ns$construire_table(data.frame(age = 40:43, lx = c(100000, 99000, 97020, 94109.4)), "lx_age",
                                 "mortalite_fictive_b2", "fictive", "table fictive, sans source (tests B2)")
  mois <- sprintf("%04d-%02d", rep(2023:2025, each = 12L), rep(1:12, 3L))
  taux <- rep(3, 36L)
  taux[mois == "2024-10"] <- 3.2
  taux[mois == "2025-10"] <- 2.4
  tme <- b2_ns$construire_table(data.frame(mois = mois, taux_pourcent = taux, stringsAsFactors = FALSE),
                                "serie_tme_mensuelle", "tme_fictive_b2", "fictive", "série fictive, sans source (tests B2)")
  list(mortalite_tarif = mort, serie_tme = tme)
}

# Plan minimal de B2 (spécification de B2, § 7.5), empreintes des tables fictives.
b2_plan <- function(tables = b2_tables(), arrete = D("2025-12-31")) {
  list(
    version_plan = 1L, arrete = arrete,
    perimetre = list(garanties = "deces", referentiels = "comptes_sociaux", segmentations = list()),
    tables = list(
      mortalite_tarif = list(identifiant = "mortalite_fictive_b2", empreinte = tables$mortalite_tarif$origine$empreinte,
                             statut = "fictive", hors_axes = "refus"),
      serie_tme = list(identifiant = "tme_fictive_b2", empreinte = tables$serie_tme$origine$empreinte, statut = "fictive",
                       hors_axes = "refus", decalage_publication_mois = 1L)),
    taux = list(deces = list(provision_mathematique_temporaire_deces = list(comptes_sociaux = 0.02))),
    frais = list(deces = list(
      sinistres_declares_non_regles = list(comptes_sociaux = list(taux_chargement_psap = 0)),
      capitaux_non_reclames = list(comptes_sociaux = list(taux_chargement_psap = 0)),
      provision_mathematique_temporaire_deces = list(comptes_sociaux = list(
        taux_chargement_gestion = 0, taux_chargement_acquisition = 0, taux_chargement_cotisation = 0)))),
    revalorisation = list(capital_deces = list(taux_par_annee = c(`2024` = 0.03, `2025` = 0.024), prorata = "simple")),
    conventions = list(age = "revolu", instant_date = "fin_journee", repartition_annee = "uniforme",
                       fractionnement = "echeances_exactes", decompte_jours = "exact_exact"),
    postes = list(deces = list(
      sinistres_declares_non_regles = list(methode = "capital_dossier", parametres = list(
        taux_sans_suite = 0, probabilite_reconnaissance_iad = 1,
        structure_familiale = list(taux_conjoint = 1, nombre_enfants = 2),
        age_limite_enfant_majoration = 26L, liens_conjoint_majoration = c("conjoint", "partenaire_pacs", "concubin"))),
      capitaux_non_reclames = list(methode = "capital_revalorise", parametres = list(
        critere = "beneficiaire_non_identifie", taux_sans_suite = 0, probabilite_reconnaissance_iad = 1,
        structure_familiale = list(taux_conjoint = 1, nombre_enfants = 2),
        age_limite_enfant_majoration = 26L, liens_conjoint_majoration = c("conjoint", "partenaire_pacs", "concubin"))),
      provision_mathematique_temporaire_deces = list(
        individuel = list(methode = "prospective_prime_pure", parametres = list(pas = "an", paiement_capital = "fin_pas",
                                                                                plancher = "par_contrat")),
        collectif = list(methode = "prorata_cotisation", parametres = list())))),
    donnees = list(), restitution = list(echeanciers = "aucun", triangles = "aucun"), liens = list(), graine = 1L)
}

# Base du capital décès (cas R1 à R7 du § 7.4) : contrat collectif CT1, garantie deces GS1
# (taux_capital 2, majorations 0,5 et 0,25), assuré AS1 affilié (salaire 30 000), décès SI1
# le 2024-07-01, connu le 2024-09-01, dossier DO1 ; `capital` : montant du fixation_capital
# (NA : dossier ouvert, sans fixation) ; `instruction` : date d'instruction (NA : non
# instruit) ; `paiements` : data.frame (date, montant) de prestations capital ; `qualite` :
# qualité du bénéficiaire BE1 ; extraction au 2026-03-31.
b2_base_capital <- function(capital = 100000, instruction = D("2024-09-10"), paiements = NULL,
                            qualite = "conjoint_survivant", extraction = D("2026-03-31")) {
  ev <- if (is.na(capital)) b2_tab("evenements") else
    b2_tab("evenements", id_evenement = "EV1", id_sinistre = "SI1", id_dossier = "DO1", type_evenement = "fixation_capital",
           date_effet = D("2024-09-15"), date_saisie = D("2024-09-16"), montant = capital)
  pr <- if (is.null(paiements)) b2_tab("prestations") else
    b2_tab("prestations", id_prestation = paste0("PR", seq_len(nrow(paiements))), id_dossier = "DO1",
           type_prestation = "capital", nature_mouvement = "paiement", date_reglement = paiements$date,
           montant = paiements$montant, date_saisie = paiements$date)
  list(
    extraction = b2_tab("extraction", date_extraction = extraction, debut_historique = D("2017-01-01"),
                        type_organisme = "societe_assurance", version_dictionnaire = "1.5", devise = "EUR"),
    adherents = b2_tab("adherents", id_adherent = "AD1"),
    contrats = b2_tab("contrats", id_contrat = "CT1", nature_contrat = "collectif_obligatoire", id_adherent = "AD1",
                      date_effet = D("2020-01-01"), mois_echeance = 1L, jour_echeance = 1L, preavis_mois = 2L,
                      tacite_reconduction = TRUE, gestionnaire = "interne", date_debut_gestion = D("2020-01-01")),
    garanties_souscrites = b2_tab("garanties_souscrites", id_garantie_souscrite = "GS1", id_contrat = "CT1",
                                  code_garantie = "deces", college = "ensemble", date_effet = D("2020-01-01"),
                                  type_assiette = "salaire_reference", option_iad = FALSE, periodicite_cotisation = "annuelle",
                                  clause_type_beneficiaire = "conjoint_enfants_heritiers"),
    parametres = b2_tab("parametres", id_garantie_souscrite = "GS1",
                        parametre = c("taux_capital", "age_fin_garantie", "majoration_conjoint", "majoration_enfant"),
                        valeur = c(2, 67, 0.5, 0.25)),
    assures = b2_tab("assures", id_assure = "AS1", sexe = "M", date_naissance = D("1980-01-01")),
    affiliations = b2_tab("affiliations", id_affiliation = "AF1", id_assure = "AS1", id_contrat = "CT1", college = "ensemble",
                          type_affiliation = "cotisant", date_debut = D("2020-01-01"), date_saisie = D("2020-01-05"),
                          salaire_reference = 30000),
    famille = b2_tab("famille", id_membre = c("ME1", "ME2", "ME3"), id_assure = "AS1", lien = c("conjoint", "enfant", "enfant"),
                     sexe = c("F", "M", "F"), date_naissance = D(c("1982-05-01", "2014-01-01", "1997-01-01")),
                     id_sinistre = "SI1", date_saisie = D("2024-09-10")),
    sinistres = b2_tab("sinistres", id_sinistre = "SI1", id_assure = "AS1", nature_sinistre = "deces",
                       date_survenance = D("2024-07-01"), date_declaration = D("2024-09-01"), date_instruction = instruction,
                       canal_declaration = "beneficiaire", gestionnaire = "interne", date_saisie = D("2024-09-02")),
    dossiers = b2_tab("dossiers", id_dossier = "DO1", id_sinistre = "SI1", id_garantie_souscrite = "GS1",
                      date_ouverture = D("2024-09-03")),
    beneficiaires = b2_tab("beneficiaires", id_beneficiaire = "BE1", id_dossier = "DO1",
                           id_membre = if (qualite == "conjoint_survivant") "ME1" else NA_character_, qualite = qualite, part = 1,
                           date_saisie = D("2024-09-10")),
    rentes = b2_tab("rentes"),
    evenements = ev,
    prestations = pr,
    cotisations = b2_tab("cotisations"))
}

# Base de P3 (cas T1 à T7 du § 7.4) : contrat individuel CT2 (effet 2024-01-01, terme
# 2027-01-01), garantie deces GS2 (capital_forfaitaire 100 000, age_fin_garantie 70,
# taux_technique_tarif 0,02 ; `periodicite` "unique" ou "annuelle" ; `prime` : prime_periodique),
# assuré AS2 né le 1984-01-01 ; contrat collectif CT3, garantie deces GS3, cotisation CO1
# (`cotisation` : data.frame (debut, fin, montant, et mouvement : date du mouvement, le début
# de période à défaut), NULL : aucune) ; extraction au 2026-03-31.
b2_base_p3 <- function(periodicite = "unique", prime = NA_real_, tarif = 0.02, cotisation = NULL,
                       extraction = D("2026-03-31")) {
  par <- data.frame(parametre = c("capital_forfaitaire", "age_fin_garantie"), valeur = c(100000, 70))
  if (!is.na(prime)) par <- rbind(par, data.frame(parametre = "prime_periodique", valeur = prime))
  co <- if (is.null(cotisation)) b2_tab("cotisations") else
    b2_tab("cotisations", id_cotisation = paste0("CO", seq_len(nrow(cotisation))), id_garantie_souscrite = "GS3",
           nature_mouvement = "emission", debut_periode = cotisation$debut, fin_periode = cotisation$fin,
           date_mouvement = if (is.null(cotisation$mouvement)) cotisation$debut else cotisation$mouvement,
           montant = cotisation$montant)
  list(
    extraction = b2_tab("extraction", date_extraction = extraction, debut_historique = D("2017-01-01"),
                        type_organisme = "societe_assurance", version_dictionnaire = "1.5", devise = "EUR"),
    adherents = b2_tab("adherents", id_adherent = "AD3"),
    contrats = b2_tab("contrats", id_contrat = c("CT2", "CT3"), nature_contrat = c("individuel", "collectif_obligatoire"),
                      id_adherent = c(NA, "AD3"), id_assure = c("AS2", NA), date_effet = D(c("2024-01-01", "2020-01-01")),
                      date_terme = D(c("2027-01-01", NA)), mois_echeance = 1L, jour_echeance = 1L, preavis_mois = 2L,
                      tacite_reconduction = c(FALSE, TRUE), gestionnaire = "interne",
                      date_debut_gestion = D(c("2024-01-01", "2020-01-01"))),
    garanties_souscrites = b2_tab("garanties_souscrites", id_garantie_souscrite = c("GS2", "GS3"), id_contrat = c("CT2", "CT3"),
                                  code_garantie = "deces", college = "ensemble", date_effet = D(c("2024-01-01", "2020-01-01")),
                                  type_assiette = c("forfait", "salaire_reference"), option_iad = FALSE,
                                  periodicite_cotisation = c(periodicite, "annuelle"), taux_technique_tarif = as.numeric(c(tarif, NA)),
                                  clause_type_beneficiaire = "conjoint_enfants_heritiers"),
    parametres = b2_tab("parametres", id_garantie_souscrite = c(rep("GS2", nrow(par)), "GS3", "GS3"),
                        parametre = c(par$parametre, "taux_capital", "age_fin_garantie"), valeur = c(par$valeur, 2, 67)),
    assures = b2_tab("assures", id_assure = "AS2", sexe = "M", date_naissance = D("1984-01-01")),
    affiliations = b2_tab("affiliations"),
    famille = b2_tab("famille"),
    sinistres = b2_tab("sinistres"),
    dossiers = b2_tab("dossiers"),
    beneficiaires = b2_tab("beneficiaires"),
    rentes = b2_tab("rentes"),
    evenements = b2_tab("evenements"),
    prestations = b2_tab("prestations"),
    cotisations = co)
}

# Vue à l'arrêté d'une base de test (vue_a_date(), conventions du plan).
b2_vue <- function(base, arrete, declarations = NULL, conventions = list(age = "revolu")) {
  b2_ns$vue_a_date(base, arrete, declarations, conventions)
}
