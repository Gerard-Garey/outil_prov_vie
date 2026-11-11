# Tests unitaires du module `risque_en_cours` (R/risque_en_cours.R) ; spécification de B2,
# § 5.5 et § 7.3, critère (3.6), cas T1 à T7 du § 7.4 (#66). Exécuté par
# tests/test_unitaires.R : le package est installé et chargé, le harnais est sourcé, `racine`
# est défini. Bases, tables fictives et plan minimal : tests/b2_bases.R.
# Valeurs en dur : cas T1 à T7 du § 7.4 (mesure m7 de la spécification ; T3, T4 et T6 selon
# l'erratum v1.0.4 : durées exact_exact du § 2.5, 2024 bissextile, la durée de 2024-01-01 à
# 2025-01-01 valant 365/366 + 1/365), tolérance relative 1e-10 (critère 3.6).

source(file.path(racine, "tests", "b2_bases.R"))
ns <- asNamespace("provie")
motif_de <- function(expr) {
  tryCatch({ expr; "aucun" }, refus_provie = function(e) e$motif,
           error = function(e) paste("autre :", conditionMessage(e)))
}
TOL <- 1e-10
tb <- b2_tables()
cat_g <- catalogue_garanties()
P3 <- "provision_mathematique_temporaire_deces"
A1 <- D("2025-01-01")
plan_p3 <- function(arrete = A1, gestion = 0, acquisition = 0, cotisation = 0, methode = "prospective_prime_pure") {
  p <- b2_plan(tb, arrete)
  fr <- list(taux_chargement_gestion = gestion, taux_chargement_acquisition = acquisition,
             taux_chargement_cotisation = cotisation)
  p$frais$deces[[P3]]$comptes_sociaux <- fr
  p$postes$deces[[P3]]$individuel$methode <- methode
  p
}
indiv <- function(base, plan, arrete = plan$arrete, declarations = NULL) {
  ns$provisions_individuelles(b2_vue(base, arrete, declarations), plan, tb, TRUE)
}
risque <- function(base, plan, arrete = plan$arrete, declarations = NULL) {
  ns$calculer_risque_en_cours(b2_vue(base, arrete, declarations), plan, tb, cat_g, "deces", P3)
}

section("risque_en_cours : P3 individuel, cas T1 à T6 (critère 3.6)")

t1 <- indiv(b2_base_p3(), plan_p3())$contrats
verifier_egal("T1 : prime unique, taux_chargement_gestion 0 : 4 786,6205305652", t1$montant, 4786.6205305652, tolerance = TOL)
verifier_egal("T2 : T1 avec taux_chargement_gestion 0,001 : 4 882,6989619377",
              indiv(b2_base_p3(), plan_p3(gestion = 0.001))$contrats$montant, 4882.6989619377, tolerance = TOL)
t3 <- indiv(b2_base_p3("annuelle"), plan_p3(acquisition = 0.01))$contrats
verifier_egal("T3 (erratum v1.0.4) : primes annuelles, prospective_prime_pure, acquisition 0,01 : prime pure 1 937,9979846645 ; A_effet 5 626,2288966461 ; ä_effet 2,9031139047 ; P_z 2 282,4557058603 ; provision 2 593,6728916013 = T1 - P_z x 0,98 / 1,02",
              c(t3$a_effet / t3$a_double_effet, t3$a_effet, t3$a_double_effet, t3$prime, t3$montant,
                t1$montant - t3$prime * 0.98 / 1.02),
              c(1937.9979846645, 5626.2288966461, 2.9031139047, 2282.4557058603, 2593.6728916013, 2593.6728916013),
              tolerance = TOL)
t4 <- indiv(b2_base_p3("annuelle"), plan_p3())$contrats
verifier_egal("T4 (erratum v1.0.4) : acquisition 0 : 2 924,6224668679 ; rétrospective avant la prime de l'échéance A : 986,6244822033",
              c(t4$montant, t4$retro_avant_prime), c(2924.6224668679, 986.6244822033), tolerance = TOL)
verifier("T4 : recoupement exact prospective = rétrospective (Norberg) : prime de l'échéance A comprise, écart relatif < 1e-10 ; témoin jamais restitué (montant = prospective)",
         abs(t4$retro_apres_prime - t4$montant) < 1e-10 * t4$montant &&
           abs(t4$retro_apres_prime - t4$retro_avant_prime - t4$prime) < 1e-9 &&
           isTRUE(all.equal(risque(b2_base_p3("annuelle"), plan_p3())$cellules$montant, t4$montant, tolerance = 0)))
verifier_egal("T5 : prospective_prime_declaree, prime_periodique 2 300, taux_chargement_cotisation 0,05 : 2 687,3068050750",
              indiv(b2_base_p3("annuelle", prime = 2300), plan_p3(cotisation = 0.05, methode = "prospective_prime_declaree"))$contrats$montant,
              2687.3068050750, tolerance = TOL)
t6 <- indiv(b2_base_p3("annuelle"), plan_p3(D("2024-01-01"), acquisition = 0.03))$contrats
verifier_egal("T6 : T3 avec acquisition 0,03, arrêté à la date d'effet (prime de l'effet passée) : valeur avant plancher négative, provision 0 (plancher par contrat)",
              list(t6$valeur < 0, t6$montant), list(TRUE, 0))
verifier_egal("T6 (erratum v1.0.4) : valeur avant plancher -28,6288517481", t6$valeur, -28.6288517481, tolerance = TOL)

# arrêté entre deux anniversaires (fraction s de l'année d'assurance, répartition uniforme ou
# force constante ; spécification de B2, § 5.5), calcul indépendant
A_mi <- D("2025-07-01")
s <- 181 / 365
t_1 <- 184 / 365
attendu_mi <- function(p_s) {
  p1 <- 0.98
  d1 <- 1 - p1 / p_s
  100000 * (d1 * 1.02^(-t_1) + (p1 / p_s) * 0.03 * 1.02^(-(t_1 + 1)))
}
verifier_egal("arrêté en cours d'année (2025-07-01, s = 181/365) : décès jusqu'à l'anniversaire 1 - p(1)/p(s), uniforme p(s) = 1 - s q ; force constante p(s) = (1 - q)^s",
              c(indiv(b2_base_p3(), plan_p3(A_mi))$contrats$montant,
                indiv(b2_base_p3(), local({ p <- plan_p3(A_mi); p$conventions$repartition_annee <- "force_constante"; p }))$contrats$montant),
              c(attendu_mi(1 - s * 0.02), attendu_mi(0.98^s)), tolerance = TOL)
p_mois <- plan_p3()
p_mois$postes$deces[[P3]]$individuel$parametres$pas <- "mois"
e_mois <- indiv(b2_base_p3(), p_mois)$echeancier
verifier_egal("pas mensuel : douze pas dans l'année d'assurance 2025, probabilités de décès sommées à q_41 = 0,02 (uniforme) ; flux au terme du pas",
              list(sum(as.numeric(format(e_mois$date, "%Y")) == 2025 | e_mois$date == D("2026-01-01")) >= 12L,
                   sum(e_mois$probabilite[e_mois$date <= D("2026-01-01")]), e_mois$date[1L]),
              list(TRUE, 0.02, D("2025-02-01")), tolerance = TOL)
p_milieu <- plan_p3()
p_milieu$postes$deces[[P3]]$individuel$parametres$paiement_capital <- "milieu_pas"
verifier_egal("paiement_capital milieu_pas : début du pas + partie entière de la moitié des jours (2025-01-01 + 182 ; 2026-01-01 + 182)",
              indiv(b2_base_p3(), p_milieu)$echeancier$date, D(c("2025-07-02", "2026-07-02")))

section("risque_en_cours : P3 collectif (T7), cellule, indicateurs, hypothèse D03h, arrêts")

A7 <- D("2025-12-31")
t7 <- ns$provisions_collectives(b2_vue(b2_base_p3(cotisation = data.frame(debut = D("2025-07-01"), fin = D("2026-06-30"),
                                                                          montant = 1200)), A7),
                                plan_p3(A7, cotisation = 0.10))
verifier_egal("T7 : prorata_cotisation, émission 1 200 du 2025-07-01 au 2026-06-30, chargement 0,10, arrêté 2025-12-31 : 535,5616438356 (181 jours sur 365)",
              list(t7$id_contrat, t7$montant), list("CT3", 535.5616438356), tolerance = TOL)
verifier_egal("prorata_cotisation : période entièrement postérieure à l'arrêté (2026-02-01 au 2026-12-31) : part 1 (jours postérieurs bornés à la période) ; période échue : rien",
              ns$provisions_collectives(b2_vue(b2_base_p3(cotisation = data.frame(debut = D(c("2026-02-01", "2025-01-01")),
                                                                                  fin = D(c("2026-12-31", "2025-12-31")),
                                                                                  montant = c(1000, 500),
                                                                                  mouvement = D("2025-12-15"))), A7),
                                        plan_p3(A7))$montant,
              1000, tolerance = TOL)
r3 <- risque(b2_base_p3("annuelle", cotisation = data.frame(debut = D("2024-07-01"), fin = D("2025-06-30"), montant = 1200)),
             plan_p3(acquisition = 0.01))
verifier_egal("cellule P3 : champs individuel et collectif réunis, méthode « individuel:...;collectif:... », statut le plus faible (approximation_numerique du collectif), aucun dossier",
              list(names(r3$cellules), r3$cellules$methode, r3$cellules$statut_resultat, r3$cellules$statut_methode,
                   r3$cellules$montant, nrow(r3$dossiers), r3$cellules$provision, unique(r3$echeanciers$cle)),
              list(ns$COLONNES_CELLULES, "individuel:prospective_prime_pure;collectif:prorata_cotisation", "approximation_numerique",
                   "recommandee", t3$montant + 1200 * 180 / 365, 0L, "provision_mathematique_vie", "CT2"), tolerance = TOL)
verifier_egal("indicateurs P3 : tarif_vie (taux retenu 0,02 = taux du tarif : pas de dépassement), A132_1 à la date d'effet de la version de garantie et à l'arrêté (approximation_arrete), primes périodiques (X5 : référence 0,018, TRUE)",
              list(r3$indicateurs$regle, r3$indicateurs$depassement, r3$indicateurs$valeur_regle[2L],
                   grepl("approximation_arrete", r3$indicateurs$detail), grepl("date=2024-01-01", r3$indicateurs$detail[2L])),
              list(c("tarif_vie", "A132_1", "A132_1"), c(FALSE, TRUE, TRUE), 0.018, c(FALSE, FALSE, TRUE), TRUE), tolerance = TOL)
# D03h : taux du tarif manquant ; hypothèse déclarée (0 %) appliquée à la prime pure, à tarif_vie
d03h <- list(hypotheses = list(list(motif = "D03h", referentiel = "comptes_sociaux", poste = "tous", valeur = "0"),
                               list(motif = "D03h", referentiel = "solvabilite_2", poste = "tous", valeur = "0.01")))
r_h <- risque(b2_base_p3(tarif = NA), plan_p3(), declarations = d03h)
c_h <- indiv(b2_base_p3(tarif = NA), plan_p3(), declarations = d03h)$contrats
verifier_egal("D03h : taux du tarif manquant, hypothèse 0 % (comptes_sociaux) : taux du tarif 0, statut jugement_expert, tarif_vie en dépassement (0,02 > 0), mention hypothese_D03h",
              list(c_h$taux_tarif, c_h$hypothese_d03h, r_h$cellules$statut_resultat, r_h$indicateurs$depassement[1L],
                   r_h$indicateurs$detail[1L]),
              list(0, TRUE, "jugement_expert", TRUE, "id_contrat=CT2;hypothese_D03h"))
verifier_egal("D03h : sans hypothèse déclarée, declaration_manquante ; valeur non décimale, plan_invalide",
              list(motif_de(risque(b2_base_p3(tarif = NA), plan_p3())),
                   motif_de(risque(b2_base_p3(tarif = NA), plan_p3(),
                                   declarations = list(hypotheses = lapply(d03h$hypotheses, function(h) { h$valeur <- "zero"; h }))))),
              list("declaration_manquante", "plan_invalide"))
verifier_egal("arrêt hors_axes (hors_axes = refus) : assuré de 45 ans à l'effet (table 40 à 42) : poste arrêté, contrat en cause ; derniere_valeur : calculé",
              { b <- b2_base_p3(); b$assures$date_naissance <- D("1979-01-01")
                r <- risque(b, plan_p3())
                p_dv <- plan_p3(); p_dv$tables$mortalite_tarif$hors_axes <- "derniere_valeur"
                list(r$cellules$statut_calcul, r$cellules$motif_arret, attr(r$cellules, "identifiant_arret"),
                     risque(b, p_dv)$cellules$statut_calcul) },
              list("arrete", "hors_axes", "CT2", "calcule"))
verifier_egal("population : contrat dont l'assuré a un sinistre deces survenu au plus l'arrêté : hors de P3 ; couverture échue (arrêté au terme) : hors de P3",
              { b <- b2_base_p3()
                b$sinistres <- b2_tab("sinistres", id_sinistre = "SI9", id_assure = "AS2", nature_sinistre = "deces",
                                      date_survenance = D("2024-12-01"), date_declaration = D("2024-12-05"),
                                      canal_declaration = "beneficiaire", gestionnaire = "interne", date_saisie = D("2024-12-06"))
                list(is.null(indiv(b, plan_p3())$contrats), is.null(indiv(b2_base_p3(extraction = D("2027-06-30")), plan_p3(D("2027-01-01")))$contrats)) },
              list(TRUE, TRUE))
verifier_egal("calculer_risque_en_cours() : autre poste : erreur de programmation",
              tryCatch({ ns$calculer_risque_en_cours(b2_vue(b2_base_p3(), A1), plan_p3(), tb, cat_g, "deces",
                                                     "capitaux_non_reclames"); "aucune" },
                       error = function(e) grepl("erreur interne", conditionMessage(e))), TRUE)

section("risque_en_cours : partie de ligne de contrats (erratum v1.0.5, § 6.2), témoin à la demande")

verifier_egal("partie de ligne : date_saisie_fin du contrat CT2 refusée (D02c, fin saisie après l'extraction) : P3 arrêté (D02c), postes_arretes sur la ligne contrats date_saisie_fin D02c",
              { b <- b2_base_p3(); b$contrats$date_fin[1L] <- D("2024-06-30"); b$contrats$motif_fin[1L] <- "resiliation_adherent"
                b$contrats$date_saisie_fin[1L] <- D("2027-01-01")
                v <- b2_vue(b, A1)
                rt <- ns$postes_a_arreter(cat_g, v$bilan, plan_p3()$postes, ns$parties_ligne())$refus_tables
                list(ns$calculer_risque_en_cours(v, plan_p3(), tb, cat_g, "deces", P3)$cellules$motif_arret,
                     rt$postes_arretes[rt$table == "contrats" & rt$colonne %in% "date_saisie_fin" & rt$motif == "D02c"]) },
              list("D02c", "deces/provision_mathematique_temporaire_deces"))
verifier_egal("témoin rétrospectif calculé seulement à la demande (temoin = FALSE : NA, provision inchangée) ; temoin hors TRUE/FALSE : erreur de programmation",
              { t4f <- ns$provisions_individuelles(b2_vue(b2_base_p3("annuelle"), A1), plan_p3(), tb, FALSE)$contrats
                list(t4f$retro_avant_prime, t4f$retro_apres_prime, t4f$montant,
                     tryCatch({ ns$provisions_individuelles(b2_vue(b2_base_p3(), A1), plan_p3(), tb, NA); "aucune" },
                              error = function(e) grepl("erreur interne", conditionMessage(e)))) },
              list(NA_real_, NA_real_, 2924.6224668679, TRUE), tolerance = TOL)
