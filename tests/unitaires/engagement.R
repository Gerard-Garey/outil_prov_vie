# Tests unitaires du module `engagement` (R/engagement.R) ; spécification de B2, § 5.1 à § 5.4
# et § 7.3, critères (3.6), (3.7), (3.9), (3.12) à (3.15), cas R1 à R7 du § 7.4 (#66).
# Exécuté par tests/test_unitaires.R : le package est installé et chargé, le harnais est
# sourcé, `racine` est défini. Bases, tables fictives et plan minimal : tests/b2_bases.R.
# Valeurs en dur : cas R1 à R7 du § 7.4 (mesure m7 de la spécification, recoupement par un
# calcul indépendant en R de base), tolérance relative 1e-10 (critère 3.6).

source(file.path(racine, "tests", "b2_bases.R"))
ns <- asNamespace("provie")
motif_de <- function(expr) {
  tryCatch({ expr; "aucun" }, refus_provie = function(e) e$motif,
           error = function(e) paste("autre :", conditionMessage(e)))
}
TOL <- 1e-10
tb <- b2_tables()
cat_g <- catalogue_garanties()
A <- D("2025-12-31")
P1 <- "sinistres_declares_non_regles"
P2 <- "capitaux_non_reclames"
eng <- function(base, plan, poste = P1, arrete = A, declarations = NULL) {
  ns$calculer_engagement(b2_vue(base, arrete, declarations), plan, tb, cat_g, "deces", poste)
}
modifier <- function(plan, chemin, valeur) { plan[[chemin]] <- valeur; plan }
p <- b2_plan(tb)
p_compose <- modifier(p, c("revalorisation", "capital_deces", "prorata"), "compose")
# P2 en capital_revalorise_reglement (taux_futur 0,024 ; décès postérieur au 1er janvier 2015 :
# horizon de dépôt légal, connaissance + 10 ans)
p_depot <- function(plan = p) {
  plan$postes$deces$capitaux_non_reclames$methode <- "capital_revalorise_reglement"
  plan$revalorisation$capital_deces$taux_futur <- 0.024
  plan$revalorisation$capital_deces$duree_sans_depot_annees <- 5L
  plan
}
p_reglement <- function(plan = p, delai = 30L) {
  plan$postes$deces$sinistres_declares_non_regles$methode <- "capital_dossier_reglement"
  plan$postes$deces$sinistres_declares_non_regles$parametres$delai_reglement_jours <- delai
  plan$revalorisation$capital_deces$taux_futur <- 0.024
  plan
}
non_reclame <- b2_base_capital(qualite = "non_identifie")

section("engagement : facteur_revalorisation(), duree_annees(), valeur_actuelle_probable()")

conv <- p$conventions
verifier_egal("facteur_revalorisation() : 183 jours de 2024 sur 366 et 365 jours de 2025 (fin de journée), simple : 1,015 x 1,024",
              ns$facteur_revalorisation(D("2024-07-01"), A, p$revalorisation$capital_deces$taux_par_annee, "simple", conv, A, NULL),
              1.015 * 1.024, tolerance = TOL)
verifier_egal("facteur_revalorisation() : composé (1,03)^(183/366) x 1,024 ; intervalle vide : 1",
              ns$facteur_revalorisation(D(c("2024-07-01", "2025-12-31")), A, p$revalorisation$capital_deces$taux_par_annee,
                                        "compose", conv, A, NULL),
              c(1.03^(183 / 366) * 1.024, 1), tolerance = TOL)
verifier_egal("facteur_revalorisation() : exact_365 : J_y = 365 (2024 : 1 + 0,03 x 183 / 365)",
              ns$facteur_revalorisation(D("2024-07-01"), D("2024-12-31"), c(`2024` = 0.03), "simple",
                                        list(decompte_jours = "exact_365"), A, NULL),
              1 + 0.03 * 183 / 365, tolerance = TOL)
verifier_egal("facteur_revalorisation() : taux_futur au-delà de la dernière année déclarée et de l'année de l'arrêté (2026 : 0,05)",
              ns$facteur_revalorisation(A, D("2026-12-31"), c(`2025` = 0.024), "simple", conv, A, 0.05), 1.05, tolerance = TOL)
verifier_egal("(3.14) facteur_revalorisation() : année antérieure ou égale à celle de l'arrêté absente de taux_par_annee : plan_incomplet (même avec taux_futur)",
              list(motif_de(ns$facteur_revalorisation(D("2024-07-01"), A, c(`2024` = 0.03), "simple", conv, A, 0.02)),
                   motif_de(ns$facteur_revalorisation(A, D("2026-06-30"), c(`2025` = 0.024), "simple", conv, A, NULL))),
              list("plan_incomplet", "plan_incomplet"))
verifier_egal("duree_annees() : exact_exact, fin de journée (2025-12-31 -> 2034-09-01 : 8 + 244/365 ans) ; exact_365 ; signe",
              c(ns$duree_annees(A, D("2034-09-01"), conv), ns$duree_annees(D("2024-01-01"), D("2025-01-01"), list(decompte_jours = "exact_365")),
                ns$duree_annees(D("2034-09-01"), A, conv)),
              c(8 + 244 / 365, 366 / 365, -(8 + 244 / 365)), tolerance = TOL)
ech_test <- data.frame(cle = c("K1", "K1", "K2"), date = D(c("2026-12-31", "2027-12-31", "2026-12-31")), etat = "deces",
                       type_flux = c("capital_unique", "frais", "capital_unique"), flux = c(100, 10, 50),
                       probabilite = c(0.5, 1, 1), stringsAsFactors = FALSE)
v_test <- ns$valeur_actuelle_probable(ech_test, list(type = "taux", taux = 0.02, origine = A), conv)
verifier_egal("valeur_actuelle_probable() : flux x probabilité x (1 + taux)^(-t), somme par clé ; sans actualisation, facteur 1",
              list(v_test$valeurs$valeur_actuelle, v_test$echeancier$actualisation,
                   ns$valeur_actuelle_probable(ech_test, list(type = "aucune"), conv)$valeurs$valeur_actuelle),
              list(c(50 / 1.02 + 10 / 1.02^2, 50 / 1.02), c(1 / 1.02, 1 / 1.02^2, 1 / 1.02), c(60, 50)), tolerance = TOL)
verifier_egal("valeur_actuelle_probable() : un flux daté de l'origine est une erreur de programmation",
              tryCatch({ ns$valeur_actuelle_probable(transform(ech_test, date = A), list(type = "taux", taux = 0.02, origine = A), conv)
                         "aucune" }, error = function(e) grepl("erreur interne", conditionMessage(e))), TRUE)

# (3.7) une seule définition de valeur_actuelle_probable() et de facteur_revalorisation() dans R/
definitions <- function(nom) {
  n <- 0L
  for (f in list.files(file.path(racine, "R"), pattern = "\\.R$", full.names = TRUE)) {
    for (e in parse(f, keep.source = FALSE)) {
      if (is.call(e) && as.character(e[[1L]])[1L] %in% c("<-", "=") && identical(e[[2L]], as.name(nom))) n <- n + 1L
    }
  }
  n
}
verifier_egal("(3.7) une seule définition de valeur_actuelle_probable(), de facteur_revalorisation() et du découpage annuel dans R/",
              c(definitions("valeur_actuelle_probable"), definitions("facteur_revalorisation"), definitions(".parts_annuelles")),
              c(1L, 1L, 1L))

section("engagement : P1 et P2, cas R1 à R7 (critère 3.6), recoupement (3.13), plan mixte (3.12)")

r1 <- eng(b2_base_capital(), p)
verifier_egal("R1 : capital fixé 100 000, capital_dossier, simple : 103 936 (facteur 1,03936)", r1$cellules$montant, 103936,
              tolerance = TOL)
verifier_egal("R1 : cellule, dossier et échéancier aux formes de l'ADR 0010, point 6 (annoté) ; statut exact ; flux daté du lendemain de l'arrêté",
              list(names(r1$cellules), names(r1$dossiers), names(r1$echeanciers), r1$cellules$statut_calcul,
                   r1$cellules$statut_methode, r1$dossiers$statut_resultat, r1$dossiers$id_dossier, r1$dossiers$hypotheses_defaut,
                   unique(r1$echeanciers$date), r1$echeanciers$type_flux, r1$cellules$nombre_dossiers, r1$cellules$provision),
              list(ns$COLONNES_CELLULES, ns$COLONNES_DOSSIERS, ns$COLONNES_ECHEANCIERS, "calcule", "recommandee", "exact", "DO1", "",
                   D("2026-01-01"), c("capital_unique", "frais"), 1L, "psap_vie"))
verifier_egal("R2 : idem, prorata compose : 103 924,6496265443", eng(b2_base_capital(), p_compose)$cellules$montant,
              103924.6496265443, tolerance = TOL)
verifier_egal("R3 : paiement partiel de 40 000 le 2025-03-01 (305 jours de revalorisation) : 63 133,8082191781",
              eng(b2_base_capital(paiements = data.frame(date = D("2025-03-01"), montant = 40000)), p)$cellules$montant,
              63133.8082191781, tolerance = TOL)
r4 <- eng(non_reclame, p_depot(), P2)
verifier_egal("R4 : P2 (bénéficiaire non identifié), capital_revalorise_reglement, taux_futur 0,024, H = 2034-09-01 : 127 666,8365965362 ; écart à R1 : 23 730,8365965363 ; jugement_expert ; flux daté de H",
              list(r4$cellules$montant, r4$cellules$montant - r1$cellules$montant, r4$dossiers$statut_resultat,
                   unique(r4$echeanciers$date), r4$cellules$statut_methode),
              list(127666.8365965362, 23730.8365965363, "jugement_expert", D("2034-09-01"), "alternative"), tolerance = TOL)
verifier_egal("R4b : R4 avec taux_par_annee 2026 = 0,03 (N+1 déclarée) : 128 414,8844672191",
              eng(non_reclame, modifier(p_depot(), c("revalorisation", "capital_deces", "taux_par_annee"),
                                        c(`2024` = 0.03, `2025` = 0.024, `2026` = 0.03)), P2)$cellules$montant,
              128414.8844672191, tolerance = TOL)
r6 <- eng(b2_base_capital(), modifier(p_reglement(), c("revalorisation", "capital_deces", "taux_par_annee"),
                                      c(`2024` = 0.03, `2025` = 0.024, `2026` = 0.024)))
verifier_egal("R6 : R1 en capital_dossier_reglement, délai 30 jours, taux 2026 = 0,024 : 104 141,0244383562 ; flux daté de A + 30",
              list(r6$cellules$montant, unique(r6$echeanciers$date), r6$dossiers$statut_resultat),
              list(104141.0244383562, D("2026-01-30"), "jugement_expert"), tolerance = TOL)
r7 <- eng(non_reclame, p_depot(p_compose), P2)
e7 <- r7$echeanciers
v7 <- ns$valeur_actuelle_probable(e7[, c("cle", "date", "etat", "type_flux", "flux", "probabilite")],
                                  list(type = "taux", taux = 0.024, origine = A), p$conventions)
r2 <- eng(b2_base_capital(), p_compose)
verifier_egal("R7 : R2 en capital_revalorise_reglement (compose, sans année postérieure à 2025) : 127 644,9602960881 ; durée de A à H : 8,668493150684931 ans",
              list(r7$cellules$montant, ns$duree_annees(A, D("2034-09-01"), p$conventions)),
              list(127644.9602960881, 8.668493150684931), tolerance = TOL)
verifier("(3.13) recoupement exact (I1) : R7 actualisé de A à H au taux taux_futur par valeur_actuelle_probable() redonne R2 (écart < 1e-9 en valeur absolue)",
         abs(v7$valeurs$valeur_actuelle - r2$cellules$montant) < 1e-9 &&
           abs(v7$valeurs$valeur_actuelle - 103924.6496265443) < 1e-9)
p5 <- modifier(p, c("frais", "deces", P1, "comptes_sociaux", "taux_chargement_psap"), 0.01)
p5$postes$deces$sinistres_declares_non_regles$parametres$structure_familiale <- list(taux_conjoint = 0.6, nombre_enfants = 1.2)
r5a <- eng(b2_base_capital(capital = NA), p5)
r5b <- eng(b2_base_capital(capital = NA, instruction = D(NA)), p5)
verifier_egal("R5 (a) : capital non fixé, instruit, conjoint vivant et enfants de 10 et 27 ans : capital 82 500, provision avant revalorisation 83 325 (frais 1 %), facteur de R1 ; statut exact",
              list(r5a$cellules$montant, r5a$cellules$montant / 1.03936, r5a$dossiers$statut_resultat,
                   r5a$echeanciers$flux[r5a$echeanciers$type_flux == "capital_unique"] / 1.03936),
              list(83325 * 1.03936, 83325, "exact", 82500), tolerance = TOL)
verifier_egal("R5 (b) : non instruit, structure_familiale (0,6 ; 1,2) : capital 78 000, provision avant revalorisation 78 780 ; statut jugement_expert",
              list(r5b$cellules$montant, r5b$cellules$montant / 1.03936, r5b$dossiers$statut_resultat, r5b$cellules$statut_resultat),
              list(78780 * 1.03936, 78780, "jugement_expert", "jugement_expert"), tolerance = TOL)
verifier_egal("facteur d'issue : dossier ouvert de sinistre deces, taux_sans_suite 0,1 : probabilité 0,9, jugement_expert",
              { r <- eng(b2_base_capital(capital = NA), modifier(p, c("postes", "deces", P1, "parametres", "taux_sans_suite"), 0.1))
                list(unique(r$echeanciers$probabilite), r$cellules$montant, r$dossiers$statut_resultat) },
              list(0.9, 0.9 * (60000 + 15000 + 7500) * 1.03936, "jugement_expert"), tolerance = TOL)

# partition P1 / P2 et population
verifier_egal("partition : le dossier de P2 (bénéficiaire non identifié) n'est pas dans P1 ; sans critère rempli, P2 vide (montant 0, aucun dossier)",
              list(eng(non_reclame, p)$cellules$montant, eng(non_reclame, p)$cellules$nombre_dossiers,
                   eng(b2_base_capital(), p, P2)$cellules$montant, nrow(eng(b2_base_capital(), p, P2)$dossiers)),
              list(0, 0L, 0, 0L))
p_sans_ev <- p
p_sans_ev$postes$deces$capitaux_non_reclames$parametres$critere <- "sans_evenement"
p_sans_ev$postes$deces$capitaux_non_reclames$parametres$mois_sans_evenement <- 12L
p_sans_ev_court <- p_sans_ev
p_sans_ev_court$postes$deces$capitaux_non_reclames$parametres$mois_sans_evenement <- 18L
verifier_egal("critère sans_evenement : aucun événement ni ouverture depuis 12 mois (dernier événement le 2024-09-15) : P2 ; 18 mois (seuil 2024-06-30) : P1",
              list(eng(b2_base_capital(), p_sans_ev, P2)$cellules$montant, eng(b2_base_capital(), p_sans_ev_court, P2)$cellules$montant),
              list(103936, 0), tolerance = TOL)
verifier_egal("solde nul (capital entièrement payé le 2024-10-01) : aucun dossier, provision nulle",
              { r2 <- eng(b2_base_capital(paiements = data.frame(date = D("2025-12-31"), montant = 103936)), p)
                list(nrow(r2$dossiers), r2$cellules$montant) },
              list(0L, 0))
clos <- b2_base_capital()
clos$evenements <- rbind(clos$evenements, b2_tab("evenements", id_evenement = "EV2", id_sinistre = "SI1", id_dossier = "DO1",
                                                 type_evenement = "cloture_dossier", date_effet = D("2025-03-01"),
                                                 date_saisie = D("2025-03-02"), motif = "regle"))
verifier_egal("dossier clos à l'arrêté : hors de P1 et de P2",
              list(eng(clos, p)$cellules$montant, eng(clos, p, P2)$cellules$montant), list(0, 0))

# indicateurs
verifier_egal("indicateurs R132_3_1 : une ligne par année de taux_par_annee employée (2024, 2025 ; 2026 en N+1 sous R6)",
              list(r1$indicateurs$detail, r6$indicateurs$detail[r6$indicateurs$regle == "R132_3_1"], names(r1$indicateurs)),
              list(c("annee=2024;minimum;serie_incomplete", "annee=2025;minimum"),
                   c("annee=2024;minimum;serie_incomplete", "annee=2025;minimum", "annee=2026;minimum"),
                   c("regle", "poste", "garantie", "valeur_regle", "valeur_retenue", "depassement", "detail")))
verifier_egal("(3.12) plan mixte (capital_dossier sur P1, capital_revalorise_reglement sur P2, et l'inverse) : calcul effectué, une ligne methode_revalorisation_mixte (appel de P1) ; plan homogène : aucune",
              list({ r <- eng(b2_base_capital(), p_depot()); c(r$cellules$statut_calcul, r$indicateurs$detail[r$indicateurs$regle == "methode_revalorisation_mixte"]) },
                   { r <- eng(b2_base_capital(), p_reglement()); r$indicateurs$detail[r$indicateurs$regle == "methode_revalorisation_mixte"] },
                   sum(r1$indicateurs$regle == "methode_revalorisation_mixte"),
                   sum(eng(non_reclame, p_depot(p_reglement()), P2)$indicateurs$regle == "methode_revalorisation_mixte"),
                   eng(non_reclame, p_depot(), P2)$indicateurs$regle),
              list(c("calcule", "sinistres_declares_non_regles=capital_dossier;capitaux_non_reclames=capital_revalorise_reglement"),
                   "sinistres_declares_non_regles=capital_dossier_reglement;capitaux_non_reclames=capital_revalorise",
                   0L, 0L, c("R132_3_1", "R132_3_1")))
verifier_egal("capital_revalorise_reglement : décès antérieur au 1er janvier 2015, horizon A + duree_sans_depot_annees (5 ans : 2030-12-31) ; horizon de dépôt échu à l'arrêté (décès le 2015-01-01, connu le 2015-01-02 : H = 2025-01-02) : facteur 1, flux au lendemain de l'arrêté, ligne depot_cdc_echu",
              { b <- non_reclame; b$sinistres$date_survenance <- D("2014-06-01")
                b$sinistres$date_declaration <- D("2014-07-01")
                pp <- modifier(p_depot(), c("revalorisation", "capital_deces", "taux_par_annee"),
                               stats::setNames(rep(0.01, 12L), 2014:2025))
                r <- eng(b, pp, P2)
                b2 <- non_reclame; b2$sinistres$date_declaration <- D("2015-01-02"); b2$sinistres$date_survenance <- D("2015-01-01")
                pp2 <- modifier(p_depot(), c("revalorisation", "capital_deces", "taux_par_annee"),
                                stats::setNames(rep(0.01, 11L), 2015:2025))
                r2 <- eng(b2, pp2, P2)
                list(unique(r$echeanciers$date), r$indicateurs$regle, unique(r2$echeanciers$date),
                     r2$indicateurs$detail[r2$indicateurs$regle == "depot_cdc_echu"], r2$cellules$montant) },
              list(D("2030-12-31"), rep("R132_3_1", 12L), D("2026-01-01"), "id_dossier=DO1;facteur_horizon=1",
                   100000 * (1 + 0.01 * 364 / 365) * 1.01^10), tolerance = TOL)

section("engagement : arrêts de poste, invariant (3.9), refus (3.14)")

verifier_egal("affiliation_non_determinee : capital non fixé sans affiliation qui couvre la survenance : poste arrêté, premier dossier en cause",
              { b <- b2_base_capital(capital = NA); b$affiliations$date_debut <- D("2024-08-01")
                r <- eng(b, p); list(r$cellules$statut_calcul, r$cellules$motif_arret, is.na(r$cellules$montant),
                                     attr(r$cellules, "identifiant_arret"), nrow(r$dossiers)) },
              list("arrete", "affiliation_non_determinee", TRUE, "DO1", 0L))
verifier_egal("arrêt lu sur le bilan : prestations.montant refusé (portée colonne) : P1 et P2 arrêtés du motif du refus",
              { b <- b2_base_capital(paiements = data.frame(date = D("2025-03-01"), montant = 40000))
                b$prestations$montant <- NA_real_
                list(eng(b, p)$cellules$motif_arret, eng(b, p, P2)$cellules$motif_arret) },
              list("manquant_obligatoire", "manquant_obligatoire"))
# (3.9) invariant : aucun dossier valorisé n'a instruit = NA ; une instruction illisible par sa
# forme (partie NA) arrête P1 et P2 (refus de portée colonne de sinistres.date_instruction)
illisible <- b2_base_capital(capital = NA)
illisible$sinistres$date_instruction <- "2024/09/10"
verifier_egal("(3.9) instruction illisible par sa forme : instruit = NA, P1 arrêté (type_incompatible) ; sur les cas R1 à R5, aucun dossier valorisé à instruction inconnue",
              list(ns$etats_a_date(b2_vue(illisible, A), "deces", "engagement")$instruit, eng(illisible, p5)$cellules$motif_arret,
                   all(vapply(list(b2_base_capital(), b2_base_capital(capital = NA), b2_base_capital(capital = NA, instruction = D(NA))),
                              function(b) { v <- b2_vue(b, A); r <- ns$calculer_engagement(v, p5, tb, cat_g, "deces", P1)
                                            e <- ns$etats_a_date(v, "deces", "engagement")
                                            !anyNA(e$instruit[e$id_dossier %in% r$dossiers$id_dossier]) }, NA))),
              list(NA, "type_incompatible", TRUE))
verifier_egal("(3.14) refus : année de l'arrêté absente de taux_par_annee (plan_incomplet, nomme l'année et le premier dossier) ; méthode « règlement » sans taux_futur ; capital_dossier_reglement sans delai_reglement_jours ; capital_revalorise_reglement sans duree_sans_depot_annees (valider_plan)",
              list(tryCatch({ eng(b2_base_capital(), modifier(p, c("revalorisation", "capital_deces", "taux_par_annee"), c(`2024` = 0.03)))
                              "aucun" }, refus_provie = function(e) c(e$motif, grepl("2025", e$message) && grepl("DO1", e$message))),
                   motif_de(valider_plan(modifier(p_reglement(), c("revalorisation", "capital_deces", "taux_futur"), NULL))),
                   motif_de(valider_plan(modifier(p_reglement(), c("postes", "deces", P1, "parametres", "delai_reglement_jours"), NULL))),
                   motif_de(valider_plan(modifier(p_depot(), c("revalorisation", "capital_deces", "duree_sans_depot_annees"), NULL)))),
              list(c("plan_incomplet", "TRUE"), "plan_incomplet", "plan_incomplet", "plan_incomplet"))
verifier_egal("calculer_engagement() : poste hors de la famille ou autre garantie : erreur de programmation",
              tryCatch({ ns$calculer_engagement(b2_vue(b2_base_capital(), A), p, tb, cat_g, "deces",
                                                "provision_mathematique_temporaire_deces"); "aucune" },
                       error = function(e) grepl("erreur interne", conditionMessage(e))), TRUE)
verifier("plan minimal de B2 valide (§ 7.5)", inherits(valider_plan(p), "plan_calcul"))

section("engagement : partie de ligne (erratum v1.0.5, § 6.2), réouverture (Q-a), exclusions, cas limites")

# Constat 2 de l'audit léger : affiliation AF1 terminée le 2024-03-31 (avant la survenance) ;
# fin saisie après l'extraction (D02c, motif R) : la partie de fin est inconnue, date_fin
# masquée ; une colonne de la partie vaut pour toute la partie (§ 6.2 (ii) et (iii)) : P1 et
# P2 arrêtés (D02c), postes_arretes porté par la ligne (affiliations, date_saisie_fin, D02c)
af_fin <- function(saisie_fin) {
  b <- b2_base_capital(capital = NA)
  b$affiliations <- b2_tab("affiliations", id_affiliation = "AF1", id_assure = "AS1", id_contrat = "CT1", college = "ensemble",
                           type_affiliation = "cotisant", date_debut = D("2020-01-01"), date_fin = D("2024-03-31"),
                           motif_fin = "autre", date_saisie_fin = D(saisie_fin), date_saisie = D("2020-01-05"),
                           salaire_reference = 30000)
  b
}
v_d02c <- b2_vue(af_fin("2027-01-01"), A)
pa_d02c <- ns$postes_a_arreter(cat_g, v_d02c$bilan, p$postes, ns$parties_ligne())$refus_tables
verifier_egal("partie de ligne : date_saisie_fin d'affiliation refusée (D02c) : P1 et P2 arrêtés (D02c), postes_arretes sur la ligne affiliations date_saisie_fin D02c ; témoin (fin saisie le 2024-04-10) : affiliation_non_determinee, inchangé",
              list(ns$calculer_engagement(v_d02c, p, tb, cat_g, "deces", P1)$cellules$motif_arret,
                   ns$calculer_engagement(v_d02c, p, tb, cat_g, "deces", P2)$cellules$motif_arret,
                   pa_d02c$postes_arretes[pa_d02c$table == "affiliations" & pa_d02c$colonne %in% "date_saisie_fin" &
                                            pa_d02c$motif == "D02c"],
                   eng(af_fin("2024-04-10"), p)$cellules$motif_arret),
              list("D02c", "D02c", "deces/capitaux_non_reclames;deces/sinistres_declares_non_regles", "affiliation_non_determinee"))
# Q-a (erratum v1.0.5, § 4.2) : ouvert -> clos -> fixation 100 000 -> réouverture : capital_du
b_qa <- b2_base_capital(capital = NA)
b_qa$evenements <- b2_tab("evenements", id_evenement = c("EV1", "EV2", "EV3"), id_sinistre = "SI1", id_dossier = "DO1",
                          type_evenement = c("cloture_dossier", "fixation_capital", "reouverture_dossier"),
                          date_effet = D(c("2024-10-01", "2024-11-01", "2024-12-01")),
                          date_saisie = D(c("2024-10-01", "2024-11-01", "2024-12-01")),
                          montant = c(NA, 100000, NA), motif = c("sans_suite", NA, NA))
verifier_egal("Q-a : ouvert -> clos -> fixation 100 000 -> réouverture : capital_du, 100 000, à la date de la réouverture ; P1 = 103 936 (R1)",
              { e <- ns$etats_a_date(b2_vue(b_qa, A), "deces", "engagement")
                list(e$etat_dossier, e$montant_en_vigueur, e$date_etat_dossier, eng(b_qa, p)$cellules$montant) },
              list("capital_du", 100000, D("2024-12-01"), 103936), tolerance = TOL)
# affiliation exclue pour la famille engagement (D03c, salaire manquant, exclusion déclarée) :
# elle ne couvre rien, affiliation_non_determinee ; sans exclusion : assiette_non_determinee
# (lecture de D03c par P1 et P2 : question ouverte, #75)
b_d03c <- b2_base_capital(capital = NA)
b_d03c$affiliations$salaire_reference <- NA_real_
excl_d03c <- list(exclusions = data.frame(motif = "D03c", famille = ns$FAMILLES_CALCUL,
                                          action = ifelse(ns$FAMILLES_CALCUL == "engagement", "exclure", "conserver"),
                                          stringsAsFactors = FALSE))
verifier_egal("affiliation exclue pour engagement (D03c, exclure) : affiliation_non_determinee ; non exclue (D03c, conserver partout) : assiette_non_determinee",
              list(eng(b_d03c, p, declarations = excl_d03c)$cellules$motif_arret,
                   eng(b_d03c, p, declarations = list(exclusions = transform(excl_d03c$exclusions, action = "conserver")))$cellules$motif_arret),
              list("affiliation_non_determinee", "assiette_non_determinee"))
# cas limites (mutants survivants de l'audit léger)
verifier_egal("majoration enfant : enfant de 26 ans exactement à la survenance (né le 1998-07-01), limite 26 : non compté (âge < limite) ; conjoint décédé le jour de la survenance : non compté (vivant : décès postérieur)",
              { b <- b2_base_capital(capital = NA); b$famille$date_naissance[3L] <- D("1998-07-01")
                b2 <- b2_base_capital(capital = NA); b2$famille$date_deces[1L] <- D("2024-07-01")
                c(eng(b, p)$echeanciers$flux[1L], eng(b2, p)$echeanciers$flux[1L]) / 1.03936 },
              c(60000 + 15000 + 7500, 60000 + 7500), tolerance = TOL)
verifier_egal("critère sans_evenement : événement daté du seuil (A - 12 mois = 2024-12-31) : non récent (date d'effet postérieure au seuil exigée), P2 ; dossier ouvert après le seuil (18 mois : 2024-06-30) sans événement : l'ouverture compte comme événement, hors de P2",
              { b <- b2_base_capital()
                b$evenements <- rbind(b$evenements, b2_tab("evenements", id_evenement = "EV2", id_sinistre = "SI1", id_dossier = "DO1",
                                                           type_evenement = "demande_mise_a_jour", date_effet = D("2024-12-31"),
                                                           date_saisie = D("2024-12-31")))
                c(eng(b, p_sans_ev, P2)$cellules$montant, eng(b2_base_capital(capital = NA), p_sans_ev_court, P2)$cellules$montant) },
              c(103936, 0), tolerance = TOL)
verifier_egal("facteur d'issue : dossier ouvert de sinistre iad, probabilite_reconnaissance_iad 0,5 : probabilité 0,5, jugement_expert",
              { b <- b2_base_capital(capital = NA); b$sinistres$nature_sinistre <- "iad"; b$garanties_souscrites$option_iad <- TRUE
                r <- eng(b, modifier(p, c("postes", "deces", P1, "parametres", "probabilite_reconnaissance_iad"), 0.5))
                list(unique(r$echeanciers$probabilite), r$dossiers$statut_resultat, r$cellules$statut_calcul) },
              list(0.5, "jugement_expert", "calcule"))

# performance (sans horloge) : travail de .reconstituer_capital, n dossiers ouverts chacun son
# assuré et son affiliation, plus 4n affiliations d'autres assurés de fin saisie non
# déterminée (D03g, ligne de visibilité non déterminée) ; de 500 à 2 000 dossiers : linéaire,
# environ 4 ; produit dossiers x affiliations (boucle par dossier) : 16. Borne 8.
base_perf <- function(n) {
  b <- b2_base_capital(capital = NA)
  ids <- sprintf("%05d", seq_len(n))
  idm <- sprintf("X%05d", seq_len(4L * n))
  b$assures <- b2_tab("assures", id_assure = c(paste0("AS", ids), paste0("AS", idm)), sexe = "M", date_naissance = D("1980-01-01"))
  b$affiliations <- b2_tab("affiliations", id_affiliation = c(paste0("AF", ids), paste0("AF", idm)),
                           id_assure = c(paste0("AS", ids), paste0("AS", idm)), id_contrat = "CT1", college = "ensemble",
                           type_affiliation = "cotisant", date_debut = D("2020-01-01"),
                           date_fin = D(c(rep(NA, n), rep("2023-12-31", 4L * n))), motif_fin = c(rep(NA, n), rep("autre", 4L * n)),
                           date_saisie = D("2020-01-05"), salaire_reference = 30000)
  b$sinistres <- b2_tab("sinistres", id_sinistre = paste0("SI", ids), id_assure = paste0("AS", ids), nature_sinistre = "deces",
                        date_survenance = D("2024-07-01"), date_declaration = D("2024-09-01"), date_instruction = D("2024-09-10"),
                        canal_declaration = "beneficiaire", gestionnaire = "interne", date_saisie = D("2024-09-02"))
  b$dossiers <- b2_tab("dossiers", id_dossier = paste0("DO", ids), id_sinistre = paste0("SI", ids), id_garantie_souscrite = "GS1",
                       date_ouverture = D("2024-09-03"))
  b$famille <- b2_tab("famille", id_membre = paste0("ME", ids), id_assure = paste0("AS", ids), lien = "conjoint", sexe = "F",
                      date_naissance = D("1982-05-01"), id_sinistre = paste0("SI", ids), date_saisie = D("2024-09-10"))
  b$beneficiaires <- b2_tab("beneficiaires", id_beneficiaire = paste0("BE", ids), id_dossier = paste0("DO", ids),
                            id_membre = paste0("ME", ids), qualite = "conjoint_survivant", part = 1, date_saisie = D("2024-09-10"))
  b$evenements <- b2_tab("evenements")
  b
}
OPS_REC <- c("which", "match", "split", "unique", "order", "rep", "c", "==", "!=", "<=", ">=", "<", ">", "&", "|", "!",
             "is.na", "%in%", "paste", "tabulate", "unlist", "vapply", "lapply")
travail_rec <- function(n) {
  v <- b2_vue(base_perf(n), A)
  e <- ns$etats_a_date(v, "deces", "engagement")
  travail_de(ns$.reconstituer_capital, v, e, p$postes$deces[[P1]]$parametres, p$conventions, ops = OPS_REC,
             sous = fonctions_de(ns))
}
nd_perf <- nrow(b2_vue(base_perf(500L), A)$bilan$vue$visibilite_non_determinee)
verifier("performance : travail de .reconstituer_capital de 500 à 2 000 dossiers ouverts (avec 4n affiliations de fin non déterminée, D03g) multiplié par moins de 8 (jointure : 4 ; boucle par dossier : 16)",
         nd_perf >= 1L && travail_rec(2000L) / travail_rec(500L) < 8)

section("engagement : famille d'âge inconnu ou exclue (erratum v1.0.6, § 5.3, § 6.2), bornes des affiliations, #76")

# Base R5 (a) : capital non fixé, instruit, conjoint ME1 vivant, enfants ME2 (10 ans) et ME3
# (27 ans), frais nuls ; capital 82 500 x 1,03936 = 85 747,20 ; non instruit, structure
# familiale (0,6 ; 1,2) : 78 000 x 1,03936 = 81 070,08.
pB <- modifier(p, c("postes", "deces", P1, "parametres", "structure_familiale"), list(taux_conjoint = 0.6, nombre_enfants = 1.2))
F3 <- c("engagement", "risque_en_cours", "regle_comptable")   # D03a : signalement pour triangle (dictionnaire, § 9)
excl_fam <- function(motif, exclure, familles = ns$FAMILLES_CALCUL) {
  list(exclusions = data.frame(motif = motif, famille = familles, action = ifelse(familles %in% exclure, "exclure", "conserver"),
                               stringsAsFactors = FALSE))
}
cel <- function(r) list(r$cellules$montant, r$cellules$nombre_dossiers, r$cellules$statut_resultat, r$cellules$motif_arret,
                        attr(r$cellules, "identifiant_arret"))
arret_fam <- list(NA_real_, NA_integer_, NA_character_, "famille_non_determinee", "DO1")
calcule <- function(montant, statut) list(montant, 1L, statut, NA_character_, NULL)
me2_sans_date <- local({ b <- b2_base_capital(capital = NA); b$famille$date_naissance[2L] <- NA; b })
# ME2 exclu pour engagement avec une date connue : D02a (né le 2024-08-01, après la survenance)
me2_d02a <- local({ b <- b2_base_capital(capital = NA); b$famille$date_naissance[2L] <- D("2024-08-01"); b })
verifier_egal("famille_non_determinee (arrêt, DO1) : (1) ME2 sans date, D03a conserver ; (2) D03a exclure ; (3) ME2 exclu pour engagement (D02a, exclure), date connue ; (4) sans déclaration de D03a (D03a dans declarations_requises) ; (11) ME3 (27 ans) seul d'âge inconnu",
              list(cel(eng(me2_sans_date, pB, declarations = excl_fam("D03a", character(0), F3))),
                   cel(eng(me2_sans_date, pB, declarations = excl_fam("D03a", "engagement", F3))),
                   cel(eng(me2_d02a, pB, declarations = excl_fam("D02a", "engagement"))),
                   cel(eng(me2_sans_date, pB)),
                   "D03a" %in% b2_vue(me2_sans_date, A)$bilan$declarations_requises$motif,
                   cel(eng(local({ b <- b2_base_capital(capital = NA); b$famille$date_naissance[3L] <- NA; b }), pB,
                           declarations = excl_fam("D03a", character(0), F3)))),
              list(arret_fam, arret_fam, arret_fam, arret_fam, TRUE, arret_fam))
verifier_egal("famille connue : (5) ME2 sans date, handicape ; (6) ME2 a_naitre sans date ; (7) conjoint sans date de naissance (non lue) : 85 747,20 exact ; (8) non instruit, même famille incomplète : 81 070,08 jugement_expert ; (9) capital fixé (R1), ME2 sans date : 103 936 exact",
              list(cel(eng(local({ b <- me2_sans_date; b$famille$situation[2L] <- "handicape"; b }), pB,
                           declarations = excl_fam("D03a", character(0), F3))),
                   cel(eng(local({ b <- me2_sans_date; b$famille$situation[2L] <- "a_naitre"; b }), pB,
                           declarations = excl_fam("D03a", character(0), F3))),
                   cel(eng(local({ b <- b2_base_capital(capital = NA); b$famille$date_naissance[1L] <- NA; b }), pB,
                           declarations = excl_fam("D03a", character(0), F3))),
                   cel(eng(local({ b <- me2_sans_date; b$sinistres$date_instruction <- D(NA); b }), pB,
                           declarations = excl_fam("D03a", character(0), F3))),
                   cel(eng(local({ b <- b2_base_capital(); b$famille$date_naissance[2L] <- NA; b }), pB,
                           declarations = excl_fam("D03a", character(0), F3)))),
              list(calcule(85747.2, "exact"), calcule(85747.2, "exact"), calcule(85747.2, "exact"),
                   calcule(81070.08, "jugement_expert"), calcule(103936, "exact")), tolerance = TOL)
verifier_egal("(10) exclusion de ME2 pour triangle seulement (vue$exclu$triangle$famille) : sans effet sur P1, 85 747,20 ; la même pour engagement : arrêt famille_non_determinee",
              lapply(c("triangle", "engagement"), function(f) {
                v <- b2_vue(b2_base_capital(capital = NA), A)
                v$exclu[[f]]$famille[2L] <- TRUE
                cel(ns$calculer_engagement(v, pB, tb, cat_g, "deces", P1))
              }),
              list(calcule(85747.2, "exact"), arret_fam), tolerance = TOL)
# bornes des affiliations (§ 5.3, bornes incluses, dates en fin de journée)
af_borne <- function(fin) {
  b <- b2_base_capital(capital = NA)
  b$affiliations$date_fin <- D(fin)
  b$affiliations$motif_fin <- "autre"
  b$affiliations$date_saisie_fin <- D("2024-07-05")
  b
}
deux_af <- local({
  b <- b2_base_capital(capital = NA)
  b$affiliations <- b2_tab("affiliations", id_affiliation = c("AF1", "AF2"), id_assure = "AS1", id_contrat = "CT1",
                           college = "ensemble", type_affiliation = "cotisant", date_debut = D(c("2020-01-01", "2024-01-01")),
                           date_saisie = D(c("2020-01-05", "2024-01-05")), salaire_reference = c(30000, 40000))
  b
})
af_debut_deces <- local({ b <- b2_base_capital(capital = NA); b$affiliations$date_debut <- D("2024-07-01")
                           b$affiliations$date_saisie <- D("2024-07-01"); b })
verifier_egal("affiliation : fin le jour du décès (2024-07-01, borne incluse) : 85 747,20 exact ; fin la veille : affiliation_non_determinee ; début le jour du décès (borne incluse) : 85 747,20 ; deux affiliations retenues couvrant la survenance : affiliation_non_determinee (DO1)",
              list(cel(eng(af_borne("2024-07-01"), pB)), eng(af_borne("2024-06-30"), pB)$cellules$motif_arret,
                   cel(eng(af_debut_deces, pB)), cel(eng(deux_af, pB))),
              list(calcule(85747.2, "exact"), "affiliation_non_determinee", calcule(85747.2, "exact"),
                   list(NA_real_, NA_integer_, NA_character_, "affiliation_non_determinee", "DO1")), tolerance = TOL)
# (3.15) #76, erratum v1.0.7 (§ 5.3, § 6.2) : un paramètre lu (capital_forfaitaire,
# taux_capital, majoration_conjoint, majoration_enfant) dont une ligne retenue est exclue pour
# engagement n'est pas déterminé : arrêt parametre_non_determine, jamais 0 ni absent. D09 aux
# seuils (présomptif) n'est pas implémenté (CONTROLES_NON_IMPLEMENTES) : l'exclusion est posée
# sur la vue, lignes de `parametres` de b2_base_capital() : 1 taux_capital, 2 age_fin_garantie,
# 3 majoration_conjoint, 4 majoration_enfant (5 capital_forfaitaire, base `forfait`).
excl_par <- function(b, lignes, famille = "engagement", plan = pB, poste = P1) {
  v <- b2_vue(b, A)
  v$exclu[[famille]]$parametres[which(v$retenu$parametres)[lignes]] <- TRUE
  cel(ns$calculer_engagement(v, plan, tb, cat_g, "deces", poste))
}
arret_par <- list(NA_real_, NA_integer_, NA_character_, "parametre_non_determine", "DO1")
r5a <- b2_base_capital(capital = NA)
forfait <- local({ b <- r5a
  b$parametres <- b2_tab("parametres", id_garantie_souscrite = "GS1",
                         parametre = c("taux_capital", "age_fin_garantie", "majoration_conjoint", "majoration_enfant",
                                       "capital_forfaitaire"), valeur = c(2, 67, 0.5, 0.25, 50000))
  b })
verifier_egal("(3.15) ligne de parametres exclue pour engagement : (a) taux_capital, (b) majoration_conjoint, (c) majoration_enfant : arrêt parametre_non_determine (DO1) ; (d) taux_capital exclu pour triangle seulement : 85 747,20 exact ; (e) age_fin_garantie exclu : 85 747,20 exact ; (f) capital fixé (R1), taux_capital exclu : 103 936 exact",
              list(excl_par(r5a, 1L), excl_par(r5a, 3L), excl_par(r5a, 4L), excl_par(r5a, 1L, "triangle"), excl_par(r5a, 2L),
                   excl_par(b2_base_capital(), 1L)),
              list(arret_par, arret_par, arret_par, calcule(85747.2, "exact"), calcule(85747.2, "exact"),
                   calcule(103936, "exact")), tolerance = TOL)
verifier_egal("(3.15) arrêt parametre_non_determine (DO1) : (g) non instruit, majoration_enfant exclue ; (h) sans conjoint (ME1 décédé avant la survenance), majoration_conjoint exclue ; (i) capital_forfaitaire (50 000) exclu (pas de repli sur assiette x taux) ; (j) forfait présent, taux_capital exclu ; (k) P2 (beneficiaire_non_identifie), taux_capital exclu",
              list(excl_par(local({ b <- r5a; b$sinistres$date_instruction <- D(NA); b }), 4L),
                   excl_par(local({ b <- r5a; b$famille$date_deces <- D(c("2020-01-01", NA, NA)); b }), 3L),
                   excl_par(forfait, 5L), excl_par(forfait, 1L),
                   excl_par(b2_base_capital(capital = NA, qualite = "non_identifie"), 1L, plan = p, poste = P2)),
              rep(list(arret_par), 5L))
verifier_egal("(3.15) témoins sans exclusion : (g) non instruit 81 070,08 jugement_expert ; (h) sans conjoint 70 156,80 exact ; (i) et (j) forfait 51 968 exact ; (k) P2 85 747,20 exact",
              list(excl_par(local({ b <- r5a; b$sinistres$date_instruction <- D(NA); b }), integer(0)),
                   excl_par(local({ b <- r5a; b$famille$date_deces <- D(c("2020-01-01", NA, NA)); b }), integer(0)),
                   excl_par(forfait, integer(0)),
                   excl_par(b2_base_capital(capital = NA, qualite = "non_identifie"), integer(0), plan = p, poste = P2)),
              list(calcule(81070.08, "jugement_expert"), calcule(70156.8, "exact"), calcule(51968, "exact"),
                   calcule(85747.2, "exact")), tolerance = TOL)
# (3.15) portée : l'exclusion ne vaut que pour la garantie souscrite de sa ligne. Deux
# garanties (GS1 taux 2, GS2 taux 3, collège cadres), dossiers DO1 (GS1) et DO2 (GS2) du même
# sinistre ; sans exclusion, 85 747,20 et 116 928 (112 500 x 1,03936) ; taux_capital de l'une
# exclu pour engagement : arrêt sur son dossier, capital reconstitué de l'autre inchangé
# (82 500 ; 112 500).
deux_gs <- local({ b <- r5a
  b$garanties_souscrites <- b$garanties_souscrites[c(1L, 1L), ]
  b$garanties_souscrites$id_garantie_souscrite <- c("GS1", "GS2")
  b$garanties_souscrites$college[2L] <- "cadres"
  b$parametres <- rbind(b$parametres, transform(b$parametres, id_garantie_souscrite = "GS2", valeur = c(3, 67, 0.5, 0.25)))
  b$dossiers <- rbind(b$dossiers, transform(b$dossiers, id_dossier = "DO2", id_garantie_souscrite = "GS2"))
  b$beneficiaires <- rbind(b$beneficiaires, transform(b$beneficiaires, id_beneficiaire = "BE2", id_dossier = "DO2"))
  b })
excl_gs <- function(gs) {
  v <- b2_vue(deux_gs, A)
  v$exclu$engagement$parametres[which(v$retenu$parametres & deux_gs$parametres$parametre == "taux_capital" &
                                        deux_gs$parametres$id_garantie_souscrite %in% gs)] <- TRUE
  e <- ns$etats_a_date(v, "deces", "engagement")
  e <- e[e$etat_dossier == "ouvert", , drop = FALSE]
  rc <- ns$.reconstituer_capital(v, e, pB$postes$deces[[P1]]$parametres, pB$conventions)
  r <- ns$calculer_engagement(v, pB, tb, cat_g, "deces", P1)
  list(r$cellules$motif_arret, attr(r$cellules, "identifiant_arret"), rc$capital[match(c("DO1", "DO2"), e$id_dossier)],
       rc$arret[match(c("DO1", "DO2"), e$id_dossier)])
}
verifier_egal("(3.15) portée par garantie souscrite : sans exclusion, DO1 85 747,20 et DO2 116 928 exact ; taux_capital de GS2 exclu : arrêt DO2, capital de DO1 82 500 ; taux_capital de GS1 exclu : arrêt DO1, capital de DO2 112 500",
              list(eng(deux_gs, pB)$dossiers[c("id_dossier", "montant", "statut_resultat")], excl_gs("GS2"), excl_gs("GS1")),
              list(data.frame(id_dossier = c("DO1", "DO2"), montant = c(85747.2, 116928), statut_resultat = "exact",
                              stringsAsFactors = FALSE),
                   list("parametre_non_determine", "DO2", c(82500, NA), c(NA, "parametre_non_determine")),
                   list("parametre_non_determine", "DO1", c(NA, 112500), c("parametre_non_determine", NA))), tolerance = TOL)
