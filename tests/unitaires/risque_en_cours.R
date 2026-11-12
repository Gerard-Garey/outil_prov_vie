# Tests unitaires du module `risque_en_cours` (R/risque_en_cours.R) ; spécification de B2,
# § 5.5 et § 7.3, critères (3.6), (3.16) et (3.18), cas T1 à T7 du § 7.4 (#66). Exécuté par
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

verifier_egal("témoin rétrospectif : NA pour une prime unique (CTI1 de la base construite à l'arrêté 2025-01-01, avant : -1 010,1010101010), à l'effet comme après ; contrat à primes périodiques (CTI3) : recoupement de Norberg inchangé ; provisions inchangées (#80)",
              { bc <- b2_base_construite_deces_01()
                r <- ns$provisions_individuelles(b2_vue(bc, A1), plan_p3(), tb, TRUE)$contrats
                u <- r[r$id_contrat == "CTI1", ]; pe <- r[r$id_contrat == "CTI3", ]
                bu <- b2_base_p3(); effet_u <- ns$provisions_individuelles(b2_vue(bu, D("2024-01-01")), plan_p3(D("2024-01-01")), tb, TRUE)$contrats
                list(u$nature_primes, u$retro_avant_prime, u$retro_apres_prime, effet_u$retro_avant_prime, effet_u$retro_apres_prime,
                     pe$nature_primes, pe$retro_avant_prime, pe$retro_apres_prime, u$montant, pe$montant) },
              list("unique", NA_real_, NA_real_, NA_real_, NA_real_,
                   "periodique", 986.6244822033, 2924.6224668679, 4786.6205305652, 2924.6224668679), tolerance = TOL)

section("risque_en_cours : paramètre de P3 exclu pour risque_en_cours (erratum v1.0.9, critère (3.16), § 5.5), #78")

# Exclusion posée sur la vue (vue$exclu[[famille]]$parametres, D09 présomptif n'étant pas
# implémenté), lignes de `parametres` désignées par (garantie souscrite, paramètre). Valeurs
# recalculées par un chemin indépendant : T1 à l'arrêté 2025-01-01, q_41 = 0,02, q_42 = 0,03,
# 100 000 x (0,02 / 1,02 + 0,98 x 0,03 / 1,02^2) ; à l'arrêté 2025-12-31 (s = 364/365,
# répartition uniforme), même formule que l'arrêté en cours d'année ci-dessus ; T7 : 1 200 x
# 0,90 x 181 / 365.
excl_p3 <- function(base, plan, exclusions = list(), famille = "risque_en_cours") {
  v <- b2_vue(base, plan$arrete)
  for (x in exclusions) {
    v$exclu[[famille]]$parametres[which(v$retenu$parametres & base$parametres$id_garantie_souscrite == x[1L] &
                                          base$parametres$parametre == x[2L])] <- TRUE
  }
  r <- ns$calculer_risque_en_cours(v, plan, tb, cat_g, "deces", P3)
  list(r$cellules$montant, r$cellules$nombre_dossiers, r$cellules$statut_resultat, r$cellules$motif_arret,
       attr(r$cellules, "identifiant_arret"))
}
arret_p3 <- function(id = "CT2") list(NA_real_, NA_integer_, NA_character_, "parametre_non_determine", id)
calcule_p3 <- function(montant, statut = "exact") list(montant, 0L, statut, NA_character_, NULL)
v_t1 <- 100000 * (0.02 / 1.02 + 0.98 * 0.03 / 1.02^2)
GS2_CF <- c("GS2", "capital_forfaitaire")
GS2_AF <- c("GS2", "age_fin_garantie")
GS2_PP <- c("GS2", "prime_periodique")
p_dec <- plan_p3(cotisation = 0.05, methode = "prospective_prime_declaree")
verifier_egal("(3.16) arrêt parametre_non_determine (CT2) : (a) T1, capital_forfaitaire exclu ; (b) T1, age_fin_garantie exclu ; (c) T3, capital_forfaitaire exclu ; (d) T5 (prospective_prime_declaree), prime_periodique exclu",
              list(excl_p3(b2_base_p3(), plan_p3(), list(GS2_CF)), excl_p3(b2_base_p3(), plan_p3(), list(GS2_AF)),
                   excl_p3(b2_base_p3("annuelle"), plan_p3(acquisition = 0.01), list(GS2_CF)),
                   excl_p3(b2_base_p3("annuelle", prime = 2300), p_dec, list(GS2_PP))),
              rep(list(arret_p3()), 4L))
verifier_egal("(3.16) (e) base de T5 sous prospective_prime_pure, prime_periodique exclu (non lu) : 2 593,6728916013 (T3) exact ; (f) T1 avec prime_periodique 2 300 sous prospective_prime_declaree : sans exclusion 4 786,6205305652 exact, prime_periodique exclu : arrêt (CT2, quelle que soit la périodicité) ; (g) capital_forfaitaire exclu pour engagement, puis pour triangle : 4 786,6205305652 exact",
              list(excl_p3(b2_base_p3("annuelle", prime = 2300), plan_p3(acquisition = 0.01), list(GS2_PP)),
                   excl_p3(b2_base_p3(prime = 2300), p_dec), excl_p3(b2_base_p3(prime = 2300), p_dec, list(GS2_PP)),
                   excl_p3(b2_base_p3(), plan_p3(), list(GS2_CF), "engagement"),
                   excl_p3(b2_base_p3(), plan_p3(), list(GS2_CF), "triangle")),
              list(calcule_p3(2593.6728916013), calcule_p3(v_t1), arret_p3(), calcule_p3(v_t1), calcule_p3(v_t1)),
              tolerance = TOL)
t1_40 <- local({ b <- b2_base_p3(); b$parametres$valeur[b$parametres$parametre == "age_fin_garantie" &
                                                         b$parametres$id_garantie_souscrite == "GS2"] <- 40; b })
verifier_egal("(3.16) (h) age_fin_garantie 40 (atteint le 2024-01-01) : sans exclusion, hors de la population, 0 exact ; exclu : arrêt CT2 (Kleene, et non 0) ; (i) arrêté 2027-01-01 (terme), age_fin_garantie exclu : 0 exact (fin de couverture par date_terme)",
              list(excl_p3(t1_40, plan_p3()), excl_p3(t1_40, plan_p3(), list(GS2_AF)),
                   excl_p3(b2_base_p3(extraction = D("2027-06-30")), plan_p3(D("2027-01-01")), list(GS2_AF))),
              list(calcule_p3(0), arret_p3(), calcule_p3(0)))
base_j <- b2_base_p3(cotisation = data.frame(debut = D("2025-07-01"), fin = D("2026-06-30"), montant = 1200))
p_j <- plan_p3(D("2025-12-31"), cotisation = 0.10)
s_j <- 364 / 365
p_sj <- 1 - s_j * 0.02
v_j <- 100000 * ((1 - 0.98 / p_sj) * 1.02^(-1 / 365) + (0.98 / p_sj) * 0.03 * 1.02^(-(1 / 365 + 1))) + 1200 * 0.9 * 181 / 365
verifier_egal("(3.16) (j) T1 et cotisation T7, arrêté 2025-12-31 : taux_capital et age_fin_garantie de GS3 (collectif) exclus : 3 482,0047792826 approximation_numerique, comme sans exclusion ; capital_forfaitaire de GS2 exclu : arrêt CT2 (cellule unique du poste)",
              list(excl_p3(base_j, p_j), excl_p3(base_j, p_j, list(c("GS3", "taux_capital"), c("GS3", "age_fin_garantie"))),
                   excl_p3(base_j, p_j, list(GS2_CF))),
              list(calcule_p3(v_j, "approximation_numerique"), calcule_p3(v_j, "approximation_numerique"), arret_p3()),
              tolerance = TOL)
deux_ind <- local({ b <- b2_base_p3()
  b$contrats <- b$contrats[c(1L, 1L, 2L), ]
  b$contrats$id_contrat[2L] <- "CT4"
  b$contrats$id_assure[2L] <- "AS4"
  b$garanties_souscrites <- b$garanties_souscrites[c(1L, 1L, 2L), ]
  b$garanties_souscrites$id_garantie_souscrite[2L] <- "GS4"
  b$garanties_souscrites$id_contrat[2L] <- "CT4"
  b$parametres <- rbind(b$parametres[1:2, ], transform(b$parametres[1:2, ], id_garantie_souscrite = "GS4"), b$parametres[3:4, ])
  b$assures <- rbind(b$assures, transform(b$assures, id_assure = "AS4"))
  b })
verifier_egal("(3.16) (k) deux contrats individuels identiques (CT2 / GS2, CT4 / GS4) : sans exclusion 9 573,2410611304 (2 x T1) exact ; capital_forfaitaire de GS4 exclu : arrêt CT4 ; de GS2 et GS4 : arrêt CT2 (premier contrat)",
              list(excl_p3(deux_ind, plan_p3()), excl_p3(deux_ind, plan_p3(), list(c("GS4", "capital_forfaitaire"))),
                   excl_p3(deux_ind, plan_p3(), list(GS2_CF, c("GS4", "capital_forfaitaire")))),
              list(calcule_p3(2 * v_t1), arret_p3("CT4"), arret_p3()), tolerance = TOL)

section("risque_en_cours : assuré et sinistres exclus pour risque_en_cours (erratum v1.0.10, critère (3.18), § 5.5), #82")

# Exclusions posées sur la vue (vue$exclu[[famille]]$assures, vue$exclu[[famille]]$sinistres),
# base de P3 (contrat T1 CT2 / GS2, assuré AS2), arrêté 2025-01-01 sauf mention ; sinistre
# ajouté SI2 de AS2, survenu le 2024-07-01, déclaré le 2024-09-01, saisi le 2024-09-02. Lecture
# de Kleene stricte (Q-82, tranchée le 11/11/2026) : une ligne exclue est inconnue (date de
# naissance ; nature et date du sinistre), le contrat ne sort de la population que par une
# condition connue. Valeur T1 recalculée (v_t1, ci-dessus).
avec_si2 <- function(base, nature = "deces", copie = FALSE) {
  s <- b2_tab("sinistres", id_sinistre = "SI2", id_assure = "AS2", nature_sinistre = nature, date_survenance = D("2024-07-01"),
              date_declaration = D("2024-09-01"), canal_declaration = "beneficiaire", gestionnaire = "interne",
              date_saisie = D("2024-09-02"))
  if (copie) s <- rbind(s, transform(s, id_sinistre = "SI2B", date_saisie = D("2024-09-03")))
  base$sinistres <- s
  base
}
excl_ligne <- function(base, plan = plan_p3(), table = NULL, lignes = integer(0), famille = "risque_en_cours") {
  v <- b2_vue(base, plan$arrete)
  if (!is.null(table)) v$exclu[[famille]][[table]][lignes] <- TRUE
  r <- ns$calculer_risque_en_cours(v, plan, tb, cat_g, "deces", P3)
  list(r$cellules$montant, r$cellules$nombre_dossiers, r$cellules$statut_resultat, r$cellules$motif_arret,
       attr(r$cellules, "identifiant_arret"))
}
p_27 <- plan_p3(D("2027-01-01"))
b_27 <- b2_base_p3(extraction = D("2027-06-30"))
verifier_egal("(3.18) assures : (a) AS2 exclu pour risque_en_cours : arrêt parametre_non_determine (CT2) ; (b) exclu pour engagement : 4 786,6205305652 exact ; (c) arrêté 2027-01-01, AS2 exclu : 0 exact (fin de couverture par date_terme)",
              list(excl_ligne(b2_base_p3(), table = "assures", lignes = 1L),
                   excl_ligne(b2_base_p3(), table = "assures", lignes = 1L, famille = "engagement"),
                   excl_ligne(b_27, p_27, "assures", 1L)),
              list(arret_p3(), calcule_p3(v_t1), calcule_p3(0)), tolerance = TOL)
verifier_egal("(3.18) sinistres : (d) SI2 deces retenu : 0 exact (témoin) ; (e) SI2 deces exclu pour risque_en_cours : arrêt (CT2) ; (f) exclu pour engagement : 0 exact ; (g) SI2 et copie SI2B, SI2B seul exclu : 0 exact (sinistre connu) ; (h) arrêté 2027-01-01, SI2 exclu : 0 exact",
              list(excl_ligne(avec_si2(b2_base_p3())), excl_ligne(avec_si2(b2_base_p3()), table = "sinistres", lignes = 1L),
                   excl_ligne(avec_si2(b2_base_p3()), table = "sinistres", lignes = 1L, famille = "engagement"),
                   excl_ligne(avec_si2(b2_base_p3(), copie = TRUE), table = "sinistres", lignes = 2L),
                   excl_ligne(avec_si2(b_27), p_27, "sinistres", 1L)),
              list(calcule_p3(0), arret_p3(), calcule_p3(0), calcule_p3(0), calcule_p3(0)))
verifier_egal("(3.18) (i) SI2 arret_travail retenu : 4 786,6205305652 exact ; exclu pour risque_en_cours : arrêt (CT2, nature inconnue)",
              list(excl_ligne(avec_si2(b2_base_p3(), "arret_travail")),
                   excl_ligne(avec_si2(b2_base_p3(), "arret_travail"), table = "sinistres", lignes = 1L)),
              list(calcule_p3(v_t1), arret_p3()), tolerance = TOL)
