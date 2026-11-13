# Tests unitaires du module `engagement` (R/engagement.R) ; spécification de B2, § 5.1 à § 5.4
# et § 7.3, critères (3.6), (3.7), (3.9), (3.12) à (3.15) et (3.17), cas R1 à R7 du § 7.4 (#66).
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
verifier_egal("valeur_actuelle_probable() : actualisation$type hors de TYPES_ACTUALISATION (courbe), de longueur 2, NA, facteur ou absent : erreur",
              vapply(list(list(type = "courbe"), list(type = c("aucune", "taux")), list(type = NA_character_),
                          list(type = factor("aucune")), list()),
                     function(a) tryCatch({ ns$valeur_actuelle_probable(ech_test, a, conv); FALSE },
                                          error = function(e) grepl("actualisation\\$type", conditionMessage(e))), NA),
              rep(TRUE, 5L))
# type admis par TYPES_ACTUALISATION sans branche de calcul (courbe ajoutée à la constante dans
# ce processus, puis rétablie) : erreur interne, jamais un facteur 1
types_act <- get("TYPES_ACTUALISATION", envir = ns)
unlockBinding("TYPES_ACTUALISATION", ns); assign("TYPES_ACTUALISATION", c(types_act, "courbe"), envir = ns)
err_courbe <- tryCatch({ ns$valeur_actuelle_probable(ech_test, list(type = "courbe"), conv); "aucune" },
                       error = function(e) conditionMessage(e))
assign("TYPES_ACTUALISATION", types_act, envir = ns); lockBinding("TYPES_ACTUALISATION", ns)
verifier("valeur_actuelle_probable() : type admis par TYPES_ACTUALISATION sans branche (courbe) : erreur interne ; constante rétablie",
         startsWith(err_courbe, "erreur interne de provie") && grepl("courbe", err_courbe) &&
           identical(get("TYPES_ACTUALISATION", envir = ns), c("aucune", "taux")))

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
# R3b (erratum v1.0.11) : capital payé en totalité au nominal le 2025-03-01, clôture regle
# d'effet 2025-03-01 saisie après l'arrêté (2026-01-05) : solde = revalorisation non payée,
# revalorisée jusqu'à l'arrêté, 103 936 - 100 000 x (1 + 0,024 x 305 / 365) = 140 928 / 73 ;
# témoin : clôture saisie le 2025-03-05, dossier clos, P1 nul, aucun dossier
base_r3b <- function(saisie_cloture) {
  b <- b2_base_capital(paiements = data.frame(date = D("2025-03-01"), montant = 100000))
  b$evenements <- rbind(b$evenements, b2_tab("evenements", id_evenement = "EV2", id_sinistre = "SI1", id_dossier = "DO1",
                                             type_evenement = "cloture_dossier", date_effet = D("2025-03-01"),
                                             date_saisie = saisie_cloture, motif = "regle"))
  b
}
r3b <- eng(base_r3b(D("2026-01-05")), p)
etat_r3b <- ns$etats_a_date(b2_vue(base_r3b(D("2026-01-05")), A), "deces", "engagement")
verifier_egal("R3b : payé au nominal, clôture saisie après l'arrêté : 1 930,5205479452054 (140 928 / 73), DO1, exact, capital_du",
              list(r3b$cellules$montant, r3b$dossiers$id_dossier, r3b$dossiers$statut_resultat,
                   etat_r3b$etat_dossier[etat_r3b$id_dossier == "DO1"]),
              list(1930.5205479452054, "DO1", "exact", "capital_du"), tolerance = TOL)
r3b_t <- eng(base_r3b(D("2025-03-05")), p)
verifier_egal("R3b, témoin : clôture saisie le 2025-03-05 : P1 nul, aucun dossier",
              list(r3b_t$cellules$montant, nrow(r3b_t$dossiers)), list(0, 0L))
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
# elle ne couvre rien, affiliation_non_determinee ; sans exclusion ni hypothèse :
# assiette_non_determinee (garde ; lecture de D03c sous H : critère (4.9), #75)
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
  travail_de(ns$.reconstituer_capital, v, e, p$postes$deces[[P1]]$parametres, p$conventions, P1, ops = OPS_REC,
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
# sinistre ; affiliations AF1 (ensemble) et AF2 (cadres, mêmes dates et salaire 30 000 ;
# erratum v1.0.10, critère (3.17) : le collège de la garantie entre dans la clé de
# l'affiliation) ; sans exclusion, 85 747,20 et 116 928 (112 500 x 1,03936) ; taux_capital de
# l'une exclu pour engagement : arrêt sur son dossier, capital reconstitué de l'autre inchangé
# (82 500 ; 112 500).
deux_gs_sans_af2 <- local({ b <- r5a
  b$garanties_souscrites <- b$garanties_souscrites[c(1L, 1L), ]
  b$garanties_souscrites$id_garantie_souscrite <- c("GS1", "GS2")
  b$garanties_souscrites$college[2L] <- "cadres"
  b$parametres <- rbind(b$parametres, transform(b$parametres, id_garantie_souscrite = "GS2", valeur = c(3, 67, 0.5, 0.25)))
  b$dossiers <- rbind(b$dossiers, transform(b$dossiers, id_dossier = "DO2", id_garantie_souscrite = "GS2"))
  b$beneficiaires <- rbind(b$beneficiaires, transform(b$beneficiaires, id_beneficiaire = "BE2", id_dossier = "DO2"))
  b })
deux_gs <- local({ b <- deux_gs_sans_af2
  b$affiliations <- rbind(b$affiliations, transform(b$affiliations, id_affiliation = "AF2", college = "cadres"))
  b })
excl_gs <- function(gs) {
  v <- b2_vue(deux_gs, A)
  v$exclu$engagement$parametres[which(v$retenu$parametres & deux_gs$parametres$parametre == "taux_capital" &
                                        deux_gs$parametres$id_garantie_souscrite %in% gs)] <- TRUE
  e <- ns$etats_a_date(v, "deces", "engagement")
  e <- e[e$etat_dossier == "ouvert", , drop = FALSE]
  rc <- ns$.reconstituer_capital(v, e, pB$postes$deces[[P1]]$parametres, pB$conventions, P1)
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
verifier_egal("(3.17) base deux_gs sans AF2 : DO2 (GS2, collège cadres) sans affiliation de son collège : arrêt affiliation_non_determinee (DO2)",
              cel(eng(deux_gs_sans_af2, pB)), list(NA_real_, NA_integer_, NA_character_, "affiliation_non_determinee", "DO2"))

section("engagement : collège de l'affiliation (erratum v1.0.10, critère (3.17), § 5.3, § 6.2), #66")

# Base R5 (a) dont la garantie souscrite est dédoublée en GSN (non_cadres, taux_capital 2) et
# GSC (cadres, taux_capital 3), mêmes autres paramètres, au même contrat CT1 ; affiliations de
# AS1 à CT1 (2020-01-01, sans fin) aux collèges et salaires indiqués ; DO1 sur la garantie
# indiquée. Valeurs recalculées : facteur 1,015 x 1,024 = 1,03936 (2024 : 183/366 de 3 % ;
# 2025 : 2,4 %) ; instruit, conjoint ME1 et enfant ME2 (10 ans) : taux + 0,5 + 0,25 ; GSC :
# 3,75 ; GSN : 2,75. (b) 30 000 x 3,75 x 1,03936 = 116 928 ; (c) 50 000 x 3,75 x 1,03936 =
# 194 880 ; (d) 30 000 x 2,75 x 1,03936 = 85 747,20.
base_college <- function(gs_dossier, college, salaire, qualite = "conjoint_survivant") {
  b <- b2_base_capital(capital = NA, qualite = qualite)
  g <- b$garanties_souscrites[c(1L, 1L), ]
  g$id_garantie_souscrite <- c("GSN", "GSC")
  g$college <- c("non_cadres", "cadres")
  b$garanties_souscrites <- g
  b$parametres <- b2_tab("parametres", id_garantie_souscrite = rep(c("GSN", "GSC"), each = 4L),
                         parametre = rep(c("taux_capital", "age_fin_garantie", "majoration_conjoint", "majoration_enfant"), 2L),
                         valeur = c(2, 67, 0.5, 0.25, 3, 67, 0.5, 0.25))
  b$affiliations <- b2_tab("affiliations", id_affiliation = paste0("AF", seq_along(college)), id_assure = "AS1",
                           id_contrat = "CT1", college = college, type_affiliation = "cotisant", date_debut = D("2020-01-01"),
                           date_saisie = D("2020-01-05"), salaire_reference = salaire)
  b$dossiers$id_garantie_souscrite <- gs_dossier
  b
}
arret_af <- list(NA_real_, NA_integer_, NA_character_, "affiliation_non_determinee", "DO1")
fac <- 1.015 * 1.024
col_c <- base_college("GSC", c("non_cadres", "cadres"), c(30000, 50000))
verifier_egal("(3.17) (a) DO1 sur GSC, affiliation non_cadres seule : arrêt affiliation_non_determinee (DO1) ; (b) affiliation cadres : 116 928 exact ; (c) non_cadres (30 000) et cadres (50 000) : 194 880 exact ; (d) DO1 sur GSN, mêmes affiliations : 85 747,20 exact",
              list(cel(eng(base_college("GSC", "non_cadres", 30000), pB)), cel(eng(base_college("GSC", "cadres", 30000), pB)),
                   cel(eng(col_c, pB)), cel(eng(base_college("GSN", c("non_cadres", "cadres"), c(30000, 50000)), pB))),
              list(arret_af, calcule(30000 * 3.75 * fac, "exact"), calcule(50000 * 3.75 * fac, "exact"),
                   calcule(30000 * 2.75 * fac, "exact")), tolerance = TOL)
verifier_egal("(3.17) (e) cas (c), affiliation cadres exclue pour engagement : arrêt (la non_cadres n'est jamais prise à sa place) ; (f) deux affiliations cadres couvrant la survenance : arrêt",
              list({ v <- b2_vue(col_c, A); v$exclu$engagement$affiliations[2L] <- TRUE
                     cel(ns$calculer_engagement(v, pB, tb, cat_g, "deces", P1)) },
                   cel(eng(base_college("GSC", c("non_cadres", "cadres", "cadres"), c(30000, 50000, 50000)), pB))),
              list(arret_af, arret_af))
col_b <- base_college("GSC", "cadres", 30000)
verifier_egal("(3.17) (g) college de GSC à NA : refus de colonne (garanties_souscrites, college) qui arrête P1 et P2 (règle (ii), motif de la ligne) ; college de l'affiliation à NA : P1 arrêté type_incompatible (témoin)",
              { b <- col_b; b$garanties_souscrites$college[2L] <- NA
                v <- b2_vue(b, A)
                rt <- ns$postes_a_arreter(cat_g, v$bilan, p$postes, ns$parties_ligne())$refus_tables
                l <- rt[rt$table == "garanties_souscrites" & rt$colonne %in% "college", , drop = FALSE]
                bp <- b; bp$beneficiaires$qualite <- "non_identifie"; bp$beneficiaires$id_membre <- NA_character_
                b2 <- col_b; b2$affiliations$college <- NA   # NA logique : type de colonne incompatible
                list(l$portee, l$motif, l$postes_arretes, cel(eng(b, pB)), cel(eng(bp, p, P2)), eng(b2, pB)$cellules$motif_arret) },
              list("colonne", "manquant_obligatoire", "deces/capitaux_non_reclames;deces/sinistres_declares_non_regles",
                   list(NA_real_, NA_integer_, NA_character_, "manquant_obligatoire", NA_character_),
                   list(NA_real_, NA_integer_, NA_character_, "manquant_obligatoire", NA_character_), "type_incompatible"))
verifier_egal("(3.17) (h) P2 (beneficiaire_non_identifie) : cas (a) arrêt affiliation_non_determinee (DO1) ; cas (c) 194 880 exact",
              list(cel(eng(base_college("GSC", "non_cadres", 30000, "non_identifie"), p, P2)),
                   cel(eng(base_college("GSC", c("non_cadres", "cadres"), c(30000, 50000), "non_identifie"), p, P2))),
              list(arret_af, calcule(50000 * 3.75 * fac, "exact")), tolerance = TOL)
# Lecture de Kleene (§ 5.3) : un collège inconnu non refusé, de la garantie souscrite du dossier
# ou d'une affiliation de l'assuré au contrat couvrant la survenance, arrête le poste. Un NA
# dans la base est refusé (cas (g)) : le collège inconnu est posé dans la base de la vue, après
# les contrôles.
kleene_college <- function(b, table, ligne) {
  v <- b2_vue(b, A)
  v$ctx$base[[table]]$college[ligne] <- NA_character_
  cel(ns$calculer_engagement(v, pB, tb, cat_g, "deces", P1))
}
verifier_egal("(3.17) Kleene : collège inconnu non refusé de GSC (garantie du dossier) : arrêt ; de l'affiliation non_cadres couvrant la survenance, cas (c) : arrêt (et non 194 880) ; de GSN (autre garantie du contrat) : 194 880 exact ; affiliation non_cadres de collège inconnu terminée avant la survenance : 194 880 exact",
              list(kleene_college(col_c, "garanties_souscrites", 2L), kleene_college(col_c, "affiliations", 1L),
                   kleene_college(col_c, "garanties_souscrites", 1L),
                   kleene_college(local({ b <- col_c; b$affiliations$date_fin[1L] <- D("2023-12-31")
                                          b$affiliations$motif_fin[1L] <- "autre"; b$affiliations$date_saisie_fin[1L] <- D("2024-01-05")
                                          b }), "affiliations", 1L)),
              list(arret_af, arret_af, calcule(50000 * 3.75 * fac, "exact"), calcule(50000 * 3.75 * fac, "exact")),
              tolerance = TOL)
verifier_egal("(3.17) témoin : R5 (a), collège ensemble partout : 85 747,20 exact",
              cel(eng(r5a, pB)), calcule(85747.2, "exact"), tolerance = TOL)

# Plan canonique (#67) : canoniser_plan() porte revalorisation$capital_deces$taux_par_annee en
# liste nommée de doubles (forme de la fiche de calcul et du rejeu) ; les familles le lisent
# comme le double nommé d'un plan seulement validé. Avant la correction, calculer_engagement()
# d'un dossier valorisé sur le plan canonique s'arrêtait sur l'erreur de facteur_revalorisation()
# « taux_par_annee doit être un double nommé par année ». Bases R1, R3, R5 (a), R4 (P2) et P3
# (T1, T3), plans minimal et « règlement » (taux_futur, delai_reglement_jours) : résultats
# identiques (identical) avec le plan validé et avec le plan canonique.
verifier("plan canonique : taux_par_annee en liste nommée triée par année",
         is.list(canoniser_plan(p)$revalorisation$capital_deces$taux_par_annee))
meme_resultat <- function(base, plan, arrete = A) {
  cp <- canoniser_plan(plan)
  v <- b2_vue(base, arrete)
  all(vapply(c(P1, P2), function(po) identical(ns$calculer_engagement(v, plan, tb, cat_g, "deces", po),
                                               ns$calculer_engagement(v, cp, tb, cat_g, "deces", po)), NA)) &&
    identical(ns$calculer_risque_en_cours(v, plan, tb, cat_g, "deces", "provision_mathematique_temporaire_deces"),
              ns$calculer_risque_en_cours(v, cp, tb, cat_g, "deces", "provision_mathematique_temporaire_deces"))
}
verifier("plan canonique (#67) : P1, P2 et P3 identiques au plan validé (R1, R3, R5 (a), R4 en P2 ; plans minimal et règlement)",
         meme_resultat(b2_base_capital(), p) &&
           meme_resultat(b2_base_capital(paiements = data.frame(date = D("2025-03-01"), montant = 40000)), p) &&
           meme_resultat(b2_base_capital(capital = NA), p) && meme_resultat(non_reclame, p_depot()) &&
           meme_resultat(b2_base_capital(), p_reglement()))
verifier_egal("plan canonique (#67) : R1 sur le plan canonique, 103 936 (cas R1)",
              eng(b2_base_capital(), canoniser_plan(p))$cellules$montant, 103936, tolerance = TOL)
verifier("plan canonique (#67) : P3 (T1, T3) identique au plan validé",
         meme_resultat(b2_base_p3(), b2_plan(tb, D("2025-01-01")), D("2025-01-01")) &&
           meme_resultat(b2_base_p3("annuelle", 2300), b2_plan(tb, D("2025-01-01")), D("2025-01-01")))

section("engagement : lecture de D03c sous H par P1 et P2 (critère (4.9), § 5.9, décision E16-1, option B), #75")

# Base R5 (a) au salaire manquant (AF1), plan de (4.7) sans D03g : b2_plan() dont `donnees` est
# celui du plan `recommandees` de la base construite (seuils de D02c), plus la déclaration de
# D03c ; de bout en bout, par calculer_provisions(). Valeurs en dur : § 7.7, critère (4.9)
# (avant : arrêt assiette_non_determinee, m28). DO1 instruit : conjoint ME1 et enfant ME2
# (10 ans), majorations 0,5 et 0,25 ; facteur de R1 1,015 x 1,024 = 1,03936.
tid <- stats::setNames(unname(tb), vapply(tb, function(t) t$identifiant, ""))
p49 <- modifier(p, "donnees", list(seuils = list(
  d02c_age_min = list(assures_sinistre = 16, assures_affiliation = 16, famille = 0),
  d02c_age_max = list(assures_sinistre = 75, assures_affiliation = 70, famille = 110))))
hyp_d <- function(motif, valeur, poste = "tous") {
  lapply(ns$REFERENTIELS, function(r) list(motif = motif, referentiel = r, poste = poste, valeur = valeur))
}
plan_49 <- function(hypotheses = list(), exclusions = NULL) {
  q <- p49
  q$donnees$hypotheses <- hypotheses
  if (!is.null(exclusions)) q$donnees$exclusions <- exclusions
  q
}
b_49 <- b2_base_capital(capital = NA)
b_49$affiliations$salaire_reference <- NA_real_
do1_49 <- function(r) {
  d <- r$dossiers[r$dossiers$poste == P1, , drop = FALSE]
  list(d$id_dossier, d$montant, d$statut_resultat, d$hypotheses_defaut)
}
p1_49 <- function(r) {
  q <- r$provisions[r$provisions$poste == P1 & r$provisions$segmentation == "ensemble", , drop = FALSE]
  list(q$montant, q$statut_resultat, q$statut_calcul, q$motif_arret)
}
verifier_egal("(4.9) D03c H, valeur ensemble=30000 : DO1 85 747,20, jugement_expert, D03c (= (30 000 x 2 + 30 000 x (0,5 + 0,25)) x 1,015 x 1,024 ; avant : arrêt assiette_non_determinee) ; cellule de P1 jugement_expert",
              { r <- calculer_provisions(b_49, plan_49(hyp_d("D03c", "ensemble=30000")), tid)
                c(do1_49(r), p1_49(r)[1:3]) },
              list("DO1", (30000 * 2 + 30000 * (0.5 + 0.25)) * 1.015 * 1.024, "jugement_expert", "D03c",
                   85747.2, "jugement_expert", "calcule"), tolerance = TOL)
verifier_egal("(4.9) D03c H, valeur ensemble=40000 : DO1 114 329,60 (= 40 000 x 2,75 x 1,03936), jugement_expert, D03c",
              do1_49(calculer_provisions(b_49, plan_49(hyp_d("D03c", "ensemble=40000")), tid)),
              list("DO1", 114329.6, "jugement_expert", "D03c"), tolerance = TOL)
verifier_egal("(4.9) D03c H, valeur salaire_par_defaut_du_college : refus plan_invalide ; cadres=40000 : refus plan_incomplet",
              list(motif_de(calculer_provisions(b_49, plan_49(hyp_d("D03c", "salaire_par_defaut_du_college")), tid)),
                   motif_de(calculer_provisions(b_49, plan_49(hyp_d("D03c", "cadres=40000")), tid))),
              list("plan_invalide", "plan_incomplet"))
verifier_egal("(4.9) D03c H déclarée pour le seul poste capitaux_non_reclames : P1 arrêté assiette_non_determinee (garde)",
              p1_49(calculer_provisions(b_49, plan_49(hyp_d("D03c", "ensemble=30000", P2)), tid)),
              list(NA_real_, NA_character_, "arrete", "assiette_non_determinee"))
verifier_egal("(4.9) D03c X pour engagement (conserver ailleurs) : P1 arrêté affiliation_non_determinee (inchangé)",
              p1_49(calculer_provisions(b_49, plan_49(exclusions = excl_fam("D03c", "engagement")$exclusions), tid)),
              list(NA_real_, NA_character_, "arrete", "affiliation_non_determinee"))
# témoin D03a (IP6) : salaire renseigné, date de naissance de l'enfant ME2 (né le 2014-01-01)
# manquante, D03a déclarée en H : valeur non lue, arrêt famille_non_determinee (inchangé)
b_49a <- b2_base_capital(capital = NA)
b_49a$famille$date_naissance[b_49a$famille$id_membre == "ME2"] <- as.Date(NA)
verifier_egal("(4.9) témoin D03a : R5 (a), date de naissance de ME2 (né le 2014-01-01) manquante, D03a H : P1 arrêté famille_non_determinee (D03a non lue sous H, IP6)",
              p1_49(calculer_provisions(b_49a, plan_49(hyp_d("D03a", "age_par_defaut_du_segment")), tid)),
              list(NA_real_, NA_character_, "arrete", "famille_non_determinee"))
# cas de la règle hors des valeurs du critère : P2 lit D03c comme P1 ; hypothèse du poste de
# préférence à celle de `tous` (comme D03h) ; refus levé seulement si aucun dossier n'arrête
# le poste (§ 5.9 : après les règles d'arrêt) ; valeur de forme invalide.
b_49n <- b2_base_capital(capital = NA, qualite = "non_identifie")
b_49n$affiliations$salaire_reference <- NA_real_
verifier_egal("(4.9) P2 (bénéficiaire non identifié) : D03c H ensemble=30000, DO1 jugement_expert, D03c, 85 747,20 (frais nuls)",
              { r <- calculer_provisions(b_49n, plan_49(hyp_d("D03c", "ensemble=30000")), tid)
                d <- r$dossiers[r$dossiers$poste == P2, , drop = FALSE]
                list(d$id_dossier, d$montant, d$statut_resultat, d$hypotheses_defaut) },
              list("DO1", 85747.2, "jugement_expert", "D03c"), tolerance = TOL)
verifier_egal("(4.9) préférence : D03c du poste P1 (ensemble=40000) et de tous (ensemble=30000) : P1 lit celle du poste, 114 329,60 ; P2 (non identifié) celle de tous, 85 747,20",
              { h <- c(hyp_d("D03c", "ensemble=30000"), list(list(motif = "D03c", referentiel = "comptes_sociaux", poste = P1,
                                                                   valeur = "ensemble=40000")))
                c(do1_49(calculer_provisions(b_49, plan_49(h), tid))[[2L]],
                  calculer_provisions(b_49n, plan_49(h), tid)$dossiers$montant) },
              c(114329.6, 85747.2), tolerance = TOL)
b_49f <- b_49
b_49f$famille$date_naissance[b_49f$famille$id_membre == "ME2"] <- as.Date(NA)
verifier_egal("(4.9) valeur invalide et dossier arrêté (ME2 d'âge inconnu, D03a conserver) : arrêt famille_non_determinee, sans refus ; formes refusées (plan_invalide) : ensemble=30000; ; ensemble = 30000 ; ensemble=3e4 ; ensemble=30000;ensemble=40000 ; ensemble=-1",
              list(p1_49(calculer_provisions(b_49f, plan_49(hyp_d("D03c", "n_importe"), excl_fam("D03a", character(0), F3)$exclusions),
                                             tid))[[4L]],
                   vapply(c("ensemble=30000;", "ensemble = 30000", "ensemble=3e4", "ensemble=30000;ensemble=40000", "ensemble=-1"),
                          function(v) motif_de(calculer_provisions(b_49, plan_49(hyp_d("D03c", v)), tid)), "",
                          USE.NAMES = FALSE)),
              list("famille_non_determinee", rep("plan_invalide", 5L)))
# montant de forme valide mais hors de la plage des doubles (400 « 9 », non fini) : valeur mal
# formée, refus plan_invalide après les arrêts du poste (comme les formes ci-dessus), jamais
# l'erreur brute de valeur_actuelle_probable()
d03c_inf <- paste0("ensemble=", strrep("9", 400L))
verifier_egal("(4.9) montant hors de la plage des doubles (ensemble= suivi de 400 « 9 ») : refus plan_invalide ; liste cadres=50000;ensemble=<400 « 9 »> : refus plan_invalide ; dossier arrêté (ME2 d'âge inconnu) : arrêt famille_non_determinee, sans refus ; entrée valide ensemble=30000 inchangée : DO1 85 747,20",
              list(motif_de(calculer_provisions(b_49, plan_49(hyp_d("D03c", d03c_inf)), tid)),
                   motif_de(calculer_provisions(b_49, plan_49(hyp_d("D03c", paste0("cadres=50000;", d03c_inf))), tid)),
                   p1_49(calculer_provisions(b_49f, plan_49(hyp_d("D03c", d03c_inf), excl_fam("D03a", character(0), F3)$exclusions),
                                             tid))[[4L]],
                   do1_49(calculer_provisions(b_49, plan_49(hyp_d("D03c", "ensemble=30000")), tid))[[2L]]),
              list("plan_invalide", "plan_invalide", "famille_non_determinee", 85747.2), tolerance = TOL)
verifier_egal("(4.9) liste à deux collèges cadres=50000;ensemble=40000 : collège ensemble lu, 114 329,60 ; montant décimal ensemble=30000.50",
              c(do1_49(calculer_provisions(b_49, plan_49(hyp_d("D03c", "cadres=50000;ensemble=40000")), tid))[[2L]],
                do1_49(calculer_provisions(b_49, plan_49(hyp_d("D03c", "ensemble=30000.50")), tid))[[2L]]),
              c(114329.6, 30000.5 * 2.75 * 1.03936), tolerance = TOL)
# unité à montant nul (§ 5.8, décision E16-5, option (a)) : un dossier lu sous D03c reste
# restitué, montant 0, jugement_expert, D03c, et compte dans nombre_dossiers ; témoin : même
# solde négatif sans hypothèse (salaire renseigné), aucun dossier (règle du § 5.3 inchangée)
paye_49 <- data.frame(date = D("2025-03-01"), montant = 100000)
b_49p <- b2_base_capital(capital = NA, paiements = paye_49)
b_49p$affiliations$salaire_reference <- NA_real_
p1_n <- function(r) {
  q <- r$provisions[r$provisions$poste == P1 & r$provisions$segmentation == "ensemble", , drop = FALSE]
  list(q$montant, q$nombre_dossiers, q$statut_resultat)
}
verifier_egal("(4.9) unité à montant nul : D03c ensemble=0 : DO1 0, jugement_expert, D03c, P1 0 sur 1 dossier jugement_expert ; paiement de 100 000 et D03c ensemble=30000 (solde négatif) : DO1 0, jugement_expert, D03c ; témoin, salaire renseigné, même paiement : aucun dossier, P1 0 sur 0 exact",
              { r0 <- calculer_provisions(b_49, plan_49(hyp_d("D03c", "ensemble=0")), tid)
                rp <- calculer_provisions(b_49p, plan_49(hyp_d("D03c", "ensemble=30000")), tid)
                rt <- calculer_provisions(b2_base_capital(capital = NA, paiements = paye_49), plan_49(), tid)
                list(do1_49(r0), p1_n(r0), do1_49(rp), p1_n(rp), nrow(rt$dossiers), p1_n(rt)) },
              list(list("DO1", 0, "jugement_expert", "D03c"), list(0, 1L, "jugement_expert"),
                   list("DO1", 0, "jugement_expert", "D03c"), list(0, 1L, "jugement_expert"), 0L, list(0, 0L, "exact")))
# vue$hypotheses : deux lecteurs exactement (erratum v1.0.17, décision E17-1) : hypothese_vue(),
# seule sélection d'une hypothèse par ligne, et cles_lignes_hypothese() (`donnees`), qui borne
# ses lectures aux lignes placées
verifier("hypothese_vue() : seule sélection d'une hypothèse par ligne, définie une fois, dans R/engagement.R, appelée par .reconstituer_capital() (D03c), .hypothese_d03h() (D03h), provisions_collectives() (D03f) et hypotheses_vue_unites() (S2) ; vue$hypotheses lue dans le code de R/ par hypothese_vue() et cles_lignes_hypothese() seules",
         { src <- unlist(lapply(list.files(file.path(racine, "R"), "\\.R$", full.names = TRUE), readLines, encoding = "UTF-8"))
           sum(grepl("^hypothese_vue <- function", src)) == 1L &&
             any(grepl("^hypothese_vue <- function", readLines(file.path(racine, "R", "engagement.R"), encoding = "UTF-8"))) &&
             "hypothese_vue" %in% all.names(body(ns$.reconstituer_capital)) &&
             "hypothese_vue" %in% all.names(body(ns$.hypothese_d03h)) &&
             "hypothese_vue" %in% all.names(body(ns$provisions_collectives)) &&
             "hypothese_vue" %in% all.names(body(ns$hypotheses_vue_unites)) &&
             !any(grepl("x\\$motif == \"D03[fh]\"", src)) &&
             sum(grepl("vue\\$hypotheses", sub("#.*$", "", src))) == 2L &&
             any(grepl("vue\\$hypotheses", sub("#.*$", "", deparse(ns$hypothese_vue)))) &&
             any(grepl("vue\\$hypotheses", sub("#.*$", "", deparse(ns$cles_lignes_hypothese)))) })

section("engagement : statut sous une hypothèse de la vue, D02b et D03g (critère (4.7), § 5.8, source S2), #87")

# Plan de (4.7) : b2_plan() dont `donnees` est celui du plan `recommandees` de la base construite
# (seuils de D02c, p49), plus D03g en H (deux référentiels, poste tous, date_effet_plus_delai) et
# les délais de seuils$d03g_delai_jours. Valeurs en dur : § 7.7, critère (4.7) ; (e) à (l)
# recalculées par un chemin indépendant du code (b87/temoins.R, visa d'actuary). R1 : facteur
# 1,015 x 1,024 = 1,03936 ; R3 : paiement de 40 000 le 2025-03-01 ; R3b : 140 928 / 73.
plan_87 <- function(delais = list(), hypotheses = hyp_d("D03g", "date_effet_plus_delai"), exclusions = NULL) {
  q <- p49
  if (length(delais)) q$donnees$seuils$d03g_delai_jours <- delais
  q$donnees$hypotheses <- hypotheses
  if (!is.null(exclusions)) q$donnees$exclusions <- exclusions
  q
}
dos_87 <- function(r, poste = P1) {
  d <- r$dossiers[r$dossiers$poste == poste, , drop = FALSE]
  list(d$id_dossier, d$etat, d$montant, d$statut_resultat, d$hypotheses_defaut)
}
cel_87 <- function(r, poste = P1) {
  q <- r$provisions[r$provisions$poste == poste & r$provisions$segmentation == "ensemble", , drop = FALSE]
  list(q$montant, q$nombre_dossiers, q$statut_resultat)
}
etat_87 <- function(base, plan) {
  cp <- ns$canoniser_plan(plan)
  e <- ns$etats_a_date(ns$vue_a_date(base, cp$arrete, cp$donnees, cp$conventions), "deces", "engagement")
  e$etat_dossier[e$id_dossier == "DO1"]
}
b_87 <- b2_base_capital()
b_87$evenements$date_saisie <- as.Date(NA)
verifier_egal("(4.7) (a) R1, date_saisie de EV1 manquante, D03g H, délai 0 : DO1 capital_du, 103 936, jugement_expert, D03g (avant : exact, vide)",
              { q <- plan_87(list(evenements = 0)); c(dos_87(calculer_provisions(b_87, q, tid)), etat_87(b_87, q)) },
              list("DO1", "deces", 103936, "jugement_expert", "D03g", "capital_du"), tolerance = TOL)
verifier_egal("(4.7) (b) délai 500 (visibilité 2026-01-28 > A) : DO1 ouvert, capital reconstitué 82 500, 85 747,20, jugement_expert, D03g (ligne invisible rattachée par cles_lignes_hypothese() ; avant : exact)",
              { q <- plan_87(list(evenements = 500)); c(dos_87(calculer_provisions(b_87, q, tid)), etat_87(b_87, q)) },
              list("DO1", "deces", 82500 * 1.03936, "jugement_expert", "D03g", "ouvert"), tolerance = TOL)
verifier_egal("(4.7) (c) témoin : date_saisie de EV1 renseignée (2024-09-16), même plan : 103 936 exact, vide",
              dos_87(calculer_provisions(b2_base_capital(), plan_87(list(evenements = 0)), tid)),
              list("DO1", "deces", 103936, "exact", ""), tolerance = TOL)
b_87d <- b2_base_capital(paiements = data.frame(date = D("2025-03-01"), montant = 40000))
b_87d$prestations$date_saisie <- as.Date(NA)
verifier_egal("(4.7) (d) provenance sans effet : R3, date_saisie de la prestation manquante, délai 0 puis 400 : 63 133,8082191781 dans les deux cas, jugement_expert, D03g (avant : exact, vide)",
              list(dos_87(calculer_provisions(b_87d, plan_87(list(prestations = 0)), tid)),
                   dos_87(calculer_provisions(b_87d, plan_87(list(prestations = 400)), tid))),
              rep(list(list("DO1", "deces", 63133.8082191781, "jugement_expert", "D03g")), 2L), tolerance = TOL)
# (e) R3b (capital payé au nominal le 2025-03-01) dont la clôture regle EV2 (effet 2025-03-01)
# a sa date_saisie manquante (D03g) : délai 0, clôture visible à A, dossier clos restitué à 0 ;
# délai 400 (visibilité 2026-04-05 > A), dossier non clos : 140 928 / 73
b_87e <- function(qualite = "conjoint_survivant") {
  b <- b2_base_capital(paiements = data.frame(date = D("2025-03-01"), montant = 100000), qualite = qualite)
  b$evenements <- rbind(b$evenements, b2_tab("evenements", id_evenement = "EV2", id_sinistre = "SI1", id_dossier = "DO1",
                                             type_evenement = "cloture_dossier", date_effet = D("2025-03-01"),
                                             date_saisie = as.Date(NA), motif = "regle"))
  b
}
verifier_egal("(4.7) (e) dossier clos par une clôture rendue visible par D03g (délai 0) : DO1 restitué à 0, jugement_expert, D03g, compté dans nombre_dossiers de P1 (partition du § 5.4) ; P2 sans dossier ; contre-témoin, délai 400 : DO1 capital_du, 1 930,5205479452054 (140 928 / 73), jugement_expert, D03g",
              { r0 <- calculer_provisions(b_87e(), plan_87(list(evenements = 0)), tid)
                r4 <- calculer_provisions(b_87e(), plan_87(list(evenements = 400)), tid)
                list(dos_87(r0), cel_87(r0), cel_87(r0, P2), etat_87(b_87e(), plan_87(list(evenements = 0))),
                     dos_87(r4), cel_87(r4), etat_87(b_87e(), plan_87(list(evenements = 400)))) },
              list(list("DO1", "deces", 0, "jugement_expert", "D03g"), list(0, 1L, "jugement_expert"), list(0, 0L, "exact"), "clos",
                   list("DO1", "deces", 140928 / 73, "jugement_expert", "D03g"), list(140928 / 73, 1L, "jugement_expert"),
                   "capital_du"), tolerance = TOL)
verifier_egal("(4.7) (e) partition : même dossier clos, bénéficiaire non identifié (critère de P2) : restitué à 0 dans P2, jugement_expert, D03g, compté dans nombre_dossiers de P2 ; P1 sans dossier",
              { r <- calculer_provisions(b_87e("non_identifie"), plan_87(list(evenements = 0)), tid)
                list(dos_87(r, P2), cel_87(r, P2), cel_87(r)) },
              list(list("DO1", "deces", 0, "jugement_expert", "D03g"), list(0, 1L, "jugement_expert"), list(0, 0L, "exact")))
# (h) EV2, doublon de contenu de EV1 (D01b), date_saisie manquante (D03g H) ; D01b exclu pour
# engagement : EV2 non lue (§ 5.3), DO1 exact, vide ; D01b conserver : jugement_expert, D03g ;
# témoin sans D03g (date_saisie de EV2 renseignée), D01b exclu : exact, vide
b_87h <- function(saisie) {
  b <- b2_base_capital()
  b$evenements <- rbind(b$evenements, b2_tab("evenements", id_evenement = "EV2", id_sinistre = "SI1", id_dossier = "DO1",
                                             type_evenement = "fixation_capital", date_effet = D("2024-09-15"),
                                             date_saisie = saisie, montant = 100000))
  b
}
verifier_egal("(4.7) (h) ligne d'evenements sous D03g H exclue pour engagement par D01b : non lue, DO1 103 936 exact, vide, comme le témoin sans D03g ; D01b conserver : jugement_expert, D03g",
              list(dos_87(calculer_provisions(b_87h(as.Date(NA)), plan_87(list(evenements = 0),
                                                                        exclusions = excl_fam("D01b", "engagement")$exclusions), tid)),
                   dos_87(calculer_provisions(b_87h(D("2025-01-12")), plan_87(hypotheses = list(),
                                                                            exclusions = excl_fam("D01b", "engagement")$exclusions), tid)),
                   dos_87(calculer_provisions(b_87h(as.Date(NA)), plan_87(list(evenements = 0),
                                                                        exclusions = excl_fam("D01b", character(0))$exclusions), tid))),
              list(list("DO1", "deces", 103936, "exact", ""), list("DO1", "deces", 103936, "exact", ""),
                   list("DO1", "deces", 103936, "jugement_expert", "D03g")), tolerance = TOL)
# (i) sinistre SI1 à date_saisie manquante (D03g), délai 500 (visibilité 2026-01-14 > A) : SI1 et
# ses dossiers invisibles (règle 1), aucune unité (E17-2) ; bilan : une ligne D03g placée par
# référentiel ; témoin, délai 0 : DO1 103 936, jugement_expert, D03g
b_87i <- b2_base_capital()
b_87i$sinistres$date_saisie <- as.Date(NA)
verifier_egal("(4.7) (i) sinistre rendu invisible par D03g (délai 500) : aucune ligne de dossiers, P1 0 sur 0 dossier exact, hypotheses_defaut du bilan : D03g, 1 ligne par référentiel ; témoin délai 0 : DO1 103 936 jugement_expert D03g",
              { r <- calculer_provisions(b_87i, plan_87(list(sinistres = 500)), tid)
                h <- r$donnees$hypotheses_defaut
                list(nrow(r$dossiers), cel_87(r), h$motif, h$referentiel, h$nombre,
                     dos_87(calculer_provisions(b_87i, plan_87(list(sinistres = 0)), tid))) },
              list(0L, list(0, 0L, "exact"), c("D03g", "D03g"), c("comptes_sociaux", "solvabilite_2"), c(1L, 1L),
                   list("DO1", "deces", 103936, "jugement_expert", "D03g")), tolerance = TOL)
# (j) arrêté égal à l'extraction (2026-03-31), taux 2026 de 0,02 (couverture de l'année) :
# D03g est un signalement, aucune hypothèse placée ; 103 936 x (1 + 0,02 x 90 / 365)
verifier_egal("(4.7) (j) arrêté égal à l'extraction, même base et même plan que (a) : aucune hypothèse dans vue$hypotheses, DO1 exact, vide, 104 448,5610958904 (= 103 936 x (1 + 0,02 x 90 / 365))",
              { q <- plan_87(list(evenements = 0))
                q$arrete <- D("2026-03-31")
                q$revalorisation$capital_deces$taux_par_annee <- c(`2024` = 0.03, `2025` = 0.024, `2026` = 0.02)
                cp <- ns$canoniser_plan(q)
                list(length(ns$vue_a_date(b_87, cp$arrete, cp$donnees, cp$conventions)$hypotheses),
                     dos_87(calculer_provisions(b_87, q, tid))) },
              list(0L, list("DO1", "deces", 103936 * (1 + 0.02 * 90 / 365), "exact", "")), tolerance = TOL)
# (k) R5 (a) au salaire manquant (D03c H, ensemble=30000) et un événement EV1 du dossier
# (demande_mise_a_jour, effet 2025-01-10) à date_saisie manquante (D03g H, délai 0)
b_87k <- b_49
b_87k$evenements <- b2_tab("evenements", id_evenement = "EV1", id_sinistre = "SI1", id_dossier = "DO1",
                           type_evenement = "demande_mise_a_jour", date_effet = D("2025-01-10"), date_saisie = as.Date(NA))
verifier_egal("(4.7) (k) D03c (S1) et D03g (S2) sur le même dossier : DO1 85 747,20, jugement_expert, hypotheses_defaut D03c;D03g",
              dos_87(calculer_provisions(b_87k, plan_87(list(evenements = 0),
                                                        c(hyp_d("D03g", "date_effet_plus_delai"), hyp_d("D03c", "ensemble=30000"))), tid)),
              list("DO1", "deces", 85747.2, "jugement_expert", "D03c;D03g"), tolerance = TOL)
# (l) accesseur de donnees : clé de la base d'une ligne placée, même invisible ; refus (erreur
# interne) d'une ligne non placée et d'une colonne qui n'est pas une clé du dictionnaire
v_87 <- local({ cp <- ns$canoniser_plan(plan_87(list(evenements = 500))); ns$vue_a_date(b_87, cp$arrete, cp$donnees, cp$conventions) })
verifier_egal("(4.7) (l) cles_lignes_hypothese() : EV1 invisible (délai 500) : valeurs_vue() NA, accesseur SI1 et DO1 ; ligne de evenements non placée (2) : erreur interne ; colonne montant (non clé) : erreur interne ; ligne de dossiers non placée : erreur interne",
              list(ns$valeurs_vue(v_87, "evenements", "id_sinistre"),
                   ns$cles_lignes_hypothese(v_87, "evenements", 1L, "id_sinistre"),
                   ns$cles_lignes_hypothese(v_87, "evenements", 1L, "id_dossier"),
                   grepl("erreur interne", motif_de(ns$cles_lignes_hypothese(v_87, "evenements", 2L, "id_sinistre"))),
                   grepl("erreur interne", motif_de(ns$cles_lignes_hypothese(v_87, "evenements", 1L, "montant"))),
                   grepl("erreur interne", motif_de(ns$cles_lignes_hypothese(v_87, "dossiers", 1L, "id_dossier")))),
              list(NA_character_, "SI1", "DO1", TRUE, TRUE, TRUE))
# `lignes` : vecteur numérique d'indices entiers, finis et positifs ; un logique (TRUE rend
# toutes les lignes), une chaîne, un indice fractionnaire, manquant, infini ou négatif est une
# erreur interne, même pour une ligne placée (ici EV1, ligne 1)
verifier_egal("(4.7) (l) cles_lignes_hypothese() : `lignes` d'un autre type ou hors indices entiers positifs (TRUE, \"1\", 1.5, NA, Inf, -1, 0) : erreur interne ; EV1 en double (1) ou en entier (1L) : SI1",
              list(vapply(list(TRUE, "1", 1.5, NA_integer_, Inf, -1, 0),
                          function(l) grepl("erreur interne", motif_de(ns$cles_lignes_hypothese(v_87, "evenements", l, "id_sinistre"))),
                          NA),
                   ns$cles_lignes_hypothese(v_87, "evenements", 1, "id_sinistre"),
                   ns$cles_lignes_hypothese(v_87, "evenements", 1L, "id_sinistre")),
              list(rep(TRUE, 7L), "SI1", "SI1"))
verifier("(4.7) une seule détection de S2 : hypotheses_vue_unites() définie une fois, dans R/engagement.R, appelée par calculer_engagement(), provisions_individuelles() et provisions_collectives() ; cles_lignes_hypothese() définie une fois, dans R/donnees.R, appelée par hypotheses_vue_unites() seule",
         { src <- unlist(lapply(list.files(file.path(racine, "R"), "\\.R$", full.names = TRUE), readLines, encoding = "UTF-8"))
           sum(grepl("^hypotheses_vue_unites <- function", src)) == 1L &&
             any(grepl("^hypotheses_vue_unites <- function", readLines(file.path(racine, "R", "engagement.R"), encoding = "UTF-8"))) &&
             sum(grepl("^cles_lignes_hypothese <- function", src)) == 1L &&
             any(grepl("^cles_lignes_hypothese <- function", readLines(file.path(racine, "R", "donnees.R"), encoding = "UTF-8"))) &&
             "hypotheses_vue_unites" %in% all.names(body(ns$calculer_engagement)) &&
             "hypotheses_vue_unites" %in% all.names(body(ns$provisions_individuelles)) &&
             "hypotheses_vue_unites" %in% all.names(body(ns$provisions_collectives)) &&
             identical(Filter(function(n) is.function(ns[[n]]) && "cles_lignes_hypothese" %in% all.names(body(ns[[n]])),
                              sort(ls(ns, all.names = TRUE), method = "radix")), "hypotheses_vue_unites") })
# Erratum v1.0.18 (constat M1 de l'audit, réserves R1 et R2 d'actuary, décision E18-1) : une
# unité sortie du calcul n'est restituée que si une ligne qui décide du filtre de sortie porte
# S2 ; l'unité restituée garde les deux lignes d'échéancier de capital_dossier, de flux 0
# (restitution des échéanciers `tous`).
tous_87 <- function(q) { q$restitution$echeanciers <- "tous"; q }
ech_87 <- function(r, cle = "DO1") {
  e <- r$echeanciers[r$echeanciers$cle == cle, , drop = FALSE]
  list(e$type_flux, e$flux, e$valeur_actuelle, e$date, e$probabilite, e$etat)
}
verifier_egal("(4.7) (e) R2 : dossier clos restitué (délai 0) : deux lignes d'échéancier capital_unique et frais, flux 0, valeur actuelle 0, datées de A + 1 (2026-01-01), probabilité 1, état deces",
              ech_87(calculer_provisions(b_87e(), tous_87(plan_87(list(evenements = 0))), tid)),
              list(c("capital_unique", "frais"), c(0, 0), c(0, 0), D(rep("2026-01-01", 2L)), c(1, 1), c("deces", "deces")))
# (m) R3b, clôture EV2 saisie le 2025-03-05 (au plus A), seule la prestation (paiement nominal
# du 2025-03-01) à date_saisie manquante sous D03g : la clôture ne doit rien à l'hypothèse
b_87m <- b2_base_capital(paiements = data.frame(date = D("2025-03-01"), montant = 100000))
b_87m$evenements <- rbind(b_87m$evenements, b2_tab("evenements", id_evenement = "EV2", id_sinistre = "SI1", id_dossier = "DO1",
                                                   type_evenement = "cloture_dossier", date_effet = D("2025-03-01"),
                                                   date_saisie = D("2025-03-05"), motif = "regle"))
b_87m$prestations$date_saisie <- as.Date(NA)
verifier_egal("(4.7) (m) contre-témoin : dossier clos par une clôture saisie, seule une prestation sous D03g (délai 0 puis 400) : pas d'unité, P1 0 sur 0 dossier exact (avant : DO1 restitué à 0, jugement_expert)",
              lapply(c(0, 400), function(d) { r <- calculer_provisions(b_87m, plan_87(list(prestations = d)), tid)
                                              list(nrow(r$dossiers), cel_87(r)) }),
              rep(list(list(0L, list(0, 0L, "exact"))), 2L))
# (o) même base, prestation saisie ; réouverture EV3 (effet 2025-06-01) à date_saisie manquante
# sous D03g : délai 400 (visibilité 2026-07-06 > A), réouverture invisible, dossier resté clos,
# restitué à 0 (E18-1) ; délai 0, réouverture visible : capital_du, 140 928 / 73
b_87o <- b2_base_capital(paiements = data.frame(date = D("2025-03-01"), montant = 100000))
b_87o$evenements <- rbind(b_87o$evenements, b2_tab("evenements", id_evenement = c("EV2", "EV3"), id_sinistre = "SI1",
                                                   id_dossier = "DO1", type_evenement = c("cloture_dossier", "reouverture_dossier"),
                                                   date_effet = D(c("2025-03-01", "2025-06-01")),
                                                   date_saisie = c(D("2025-03-05"), NA), motif = c("regle", NA)))
verifier_egal("(4.7) (o) réouverture placée sous D03g et rendue invisible (délai 400) : dossier clos restitué à 0, jugement_expert, D03g, deux lignes d'échéancier de flux 0 ; délai 0 (réouverture visible) : capital_du, 1 930,5205479452054 (140 928 / 73), jugement_expert, D03g",
              { q4 <- tous_87(plan_87(list(evenements = 400)))
                r4 <- calculer_provisions(b_87o, q4, tid)
                q0 <- plan_87(list(evenements = 0))
                r0 <- calculer_provisions(b_87o, q0, tid)
                list(etat_87(b_87o, q4), dos_87(r4), cel_87(r4), ech_87(r4), etat_87(b_87o, q0), dos_87(r0)) },
              list("clos", list("DO1", "deces", 0, "jugement_expert", "D03g"), list(0, 1L, "jugement_expert"),
                   list(c("capital_unique", "frais"), c(0, 0), c(0, 0), D(rep("2026-01-01", 2L)), c(1, 1), c("deces", "deces")),
                   "capital_du", list("DO1", "deces", 140928 / 73, "jugement_expert", "D03g")), tolerance = TOL)
# m1 de l'audit (décision du mainteneur : restreindre) : l'accesseur n'admet que des colonnes
# d'identifiant ; famille (clé primaire id_membre;date_saisie), ligne ME1 placée sous D03g
b_87f <- b2_base_capital()
b_87f$famille$date_saisie[1L] <- as.Date(NA)
v_87f <- local({ cp <- ns$canoniser_plan(plan_87(list(famille = 0))); ns$vue_a_date(b_87f, cp$arrete, cp$donnees, cp$conventions) })
verifier_egal("(4.7) (l) accesseur restreint aux colonnes d'identifiant : famille ligne 1 placée, id_membre ME1, id_sinistre SI1 ; date_saisie (de la clé primaire) : erreur interne ; date_naissance : erreur interne",
              list(ns$cles_lignes_hypothese(v_87f, "famille", 1L, "id_membre"),
                   ns$cles_lignes_hypothese(v_87f, "famille", 1L, "id_sinistre"),
                   grepl("erreur interne.*colonne d'identifiant", motif_de(ns$cles_lignes_hypothese(v_87f, "famille", 1L, "date_saisie"))),
                   grepl("erreur interne.*colonne d'identifiant", motif_de(ns$cles_lignes_hypothese(v_87f, "famille", 1L, "date_naissance")))),
              list("ME1", "SI1", TRUE, TRUE))
# (p) contre-témoin (erratum v1.0.18, réserve R3) : clôture EV2 saisie ; seul un événement
# demande_mise_a_jour EV3 (effet 2025-06-01) à date_saisie manquante sous D03g, rendu visible
# (délai 0) : un type visible autre que cloture_dossier ou reouverture_dossier ne décide pas
b_87p <- b_87o
b_87p$evenements$type_evenement[b_87p$evenements$id_evenement == "EV3"] <- "demande_mise_a_jour"
verifier_egal("(4.7) (p) contre-témoin : dossier clos par une clôture saisie, seul un demande_mise_a_jour visible sous D03g : pas d'unité, P1 0 sur 0 dossier exact (avant : DO1 restitué à 0, jugement_expert)",
              { r <- calculer_provisions(b_87p, plan_87(list(evenements = 0)), tid); list(nrow(r$dossiers), cel_87(r)) },
              list(0L, list(0, 0L, "exact")))
verifier_egal("(4.7) (l) m3 : affiliations.college (composante de clé étrangère, hors id_*) : erreur interne ; id_assure admis par la borne de colonne (ligne non placée : erreur de ligne)",
              list(grepl("erreur interne.*colonne d'identifiant", motif_de(ns$cles_lignes_hypothese(v_87, "affiliations", 1L, "college"))),
                   grepl("non plac", motif_de(ns$cles_lignes_hypothese(v_87, "affiliations", 1L, "id_assure")))),
              list(TRUE, TRUE))
# (u) erratum v1.0.19 (réserve R7) : sinistre SI1 à deux dossiers ; DO1 clos par une clôture
# saisie, DO2 clos par une clôture sous D03g rendue visible (délai 0) ; la clôture de DO2 ne
# décide pas de celle de DO1 (lecture par id_dossier) ; D01b (doublon de contenu) en conserver
b_87u <- b2_base_capital()
b_87u$dossiers <- rbind(b_87u$dossiers, transform(b_87u$dossiers, id_dossier = "DO2"))
b_87u$beneficiaires <- rbind(b_87u$beneficiaires, transform(b_87u$beneficiaires, id_beneficiaire = "BE1b", id_dossier = "DO2"))
b_87u$evenements <- rbind(b_87u$evenements, transform(b_87u$evenements, id_evenement = "EV1b", id_dossier = "DO2"),
                          b2_tab("evenements", id_evenement = c("EV2", "EV3"), id_sinistre = "SI1", id_dossier = c("DO1", "DO2"),
                                 type_evenement = "cloture_dossier", date_effet = D("2025-03-01"),
                                 date_saisie = c(D("2025-03-05"), NA), motif = "sans_suite"))
verifier_egal("(4.7) (u) sinistre à deux dossiers, DO1 clos par une clôture saisie, DO2 par une clôture sous D03g visible : DO1 sans unité, DO2 restitué à 0, jugement_expert, D03g ; P1 0 sur 1 dossier jugement_expert (avant : DO1 et DO2 restitués)",
              { r <- calculer_provisions(b_87u, plan_87(list(evenements = 0), exclusions = excl_fam("D01b", character(0))$exclusions), tid)
                d <- r$dossiers
                list(d$id_dossier, d$montant, d$statut_resultat, d$hypotheses_defaut, cel_87(r)) },
              list("DO2", 0, "jugement_expert", "D03g", list(0, 1L, "jugement_expert")))
