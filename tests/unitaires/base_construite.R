# Tests de la base construite `construite-deces-01` et de ses plans de référence (spécification
# de B2, docs/specifications/b2-capital-deces-v1.md, § 7.8, critères R.1 à R.4 ; ADR 0011,
# points 11 à 13 ; #67) sur les familles de calcul, avant calculer_provisions(). R.5 et R.7
# (calculer_provisions()) sont dans tests/unitaires/calculer_provisions.R ; R.6 (couverture des
# méthodes) est une section de la batterie de reproductibilité (ADR 0011, point 15).
# Exécuté par tests/test_unitaires.R : le package est installé et chargé, le harnais est
# sourcé, `racine` est défini. Base, plans et comparateur : tests/b2_bases.R et
# tests/references.R.
# Valeurs en dur : § 7.8.3 et § 7.8.4 (mesures m8 à m10 de la spécification), comparées élément
# par élément à la tolérance mixte |x - r| <= 1e-10 x max(1, |r|) par verifier(), jamais par
# verifier_egal(tolerance) (ADR 0011, r3) ; seconde voie en R de base, sans fonction de provie :
# formules fermées de la dernière colonne du § 7.8.3.

source(file.path(racine, "tests", "references.R"))
ns <- asNamespace("provie")
EPS <- 1e-10
egal_mixte <- function(x, r) {
  is.numeric(x) && length(x) == length(r) && !anyNA(x) && all(abs(x - r) <= EPS * pmax(1, abs(r)))
}
tb <- b2_tables()
tid <- par_identifiant(tb)
cat_g <- catalogue_garanties()
P1 <- "sinistres_declares_non_regles"
P2 <- "capitaux_non_reclames"
P3 <- "provision_mathematique_temporaire_deces"
A1 <- D("2025-12-31")
A0 <- D("2025-01-01")
base <- b2_base_construite_deces_01()
COUPLES_C <- list(C1 = list(plan = "recommandees", arrete = A1), C2 = list(plan = "recommandees", arrete = A0),
                  C3 = list(plan = "alternatives", arrete = A1), C4 = list(plan = "alternatives", arrete = A0))
plan_c <- function(k) b2_plan_reference(COUPLES_C[[k]]$plan, COUPLES_C[[k]]$arrete, tb)
vue_c <- function(b, p) b2_vue(b, p$arrete, p$donnees, p$conventions)

section("base construite construite-deces-01 : composition (R.1, § 7.8.1)")
verifier("quinze tables du dictionnaire 1.5, colonnes dans l'ordre du dictionnaire",
         identical(names(base), names(b2_base_capital())) &&
           all(vapply(names(base), function(t) identical(names(base[[t]]), b2_dico$colonnes$colonne[b2_dico$colonnes$table == t]), NA)))
cas <- c("R1", "R3", "R4", "R5A", "R5B")
verifier_egal("lignes par table et identifiants (§ 7.8.1)",
              list(base$extraction$date_extraction, base$adherents$id_adherent, base$contrats$id_contrat,
                   base$contrats$nature_contrat, base$garanties_souscrites$id_garantie_souscrite,
                   base$garanties_souscrites$periodicite_cotisation, base$garanties_souscrites$taux_technique_tarif,
                   paste(base$parametres$id_garantie_souscrite, base$parametres$parametre, base$parametres$valeur),
                   base$assures$id_assure, base$assures$date_naissance, base$affiliations$id_affiliation,
                   base$affiliations$salaire_reference, base$famille$id_membre, base$famille$lien, base$famille$date_naissance,
                   base$sinistres$id_sinistre, base$sinistres$date_instruction, base$dossiers$id_dossier,
                   base$beneficiaires$qualite, base$beneficiaires$id_membre, base$evenements$id_dossier,
                   base$evenements$montant, base$prestations$id_prestation, base$prestations$montant,
                   base$cotisations$id_cotisation, base$cotisations$debut_periode, base$cotisations$fin_periode,
                   base$cotisations$date_mouvement, base$cotisations$montant, nrow(base$rentes)),
              list(D("2026-03-31"), "ADC1", c("CTC1", "CTI1", "CTI3"), c("collectif_obligatoire", "individuel", "individuel"),
                   c("GSC1", "GSI1", "GSI3"), c("annuelle", "unique", "annuelle"), c(NA, 0.02, 0.02),
                   c("GSC1 taux_capital 2", "GSC1 age_fin_garantie 67", "GSC1 majoration_conjoint 0.5",
                     "GSC1 majoration_enfant 0.25", "GSI1 capital_forfaitaire 1e+05", "GSI1 age_fin_garantie 70",
                     "GSI3 capital_forfaitaire 1e+05", "GSI3 age_fin_garantie 70", "GSI3 prime_periodique 2300"),
                   c(paste0("AS", cas), "ASI1", "ASI3"), D(c(rep("1980-01-01", 5L), "1984-01-01", "1984-01-01")),
                   paste0("AF", cas), rep(30000, 5L), paste0("ME", rep(cas, each = 3L), 1:3),
                   rep(c("conjoint", "enfant", "enfant"), 5L), D(rep(c("1982-05-01", "2014-01-01", "1997-01-01"), 5L)),
                   paste0("SI", cas), D(c(rep("2024-09-10", 4L), NA)), paste0("DO", cas),
                   c("conjoint_survivant", "conjoint_survivant", "non_identifie", "conjoint_survivant", "conjoint_survivant"),
                   c("MER11", "MER31", NA, "MER5A1", "MER5B1"), c("DOR1", "DOR3", "DOR4"), rep(100000, 3L), "PRR3", 40000,
                   c("COC1", "COC2"), D(c("2025-07-01", "2024-07-01")), D(c("2026-06-30", "2025-06-30")),
                   D(c("2025-07-01", "2024-07-01")), c(1200, 1200), 0L))
for (k in c("C1", "C2")) {
  p <- plan_c(k)
  bl <- vue_c(base, p)$bilan
  verifier(paste0("(R.1) ", k, " (", format(p$arrete), ") : refus_tables, declarations_requises, visibilités non déterminées, ",
                  "exclusions, hypothèses par défaut et signalements vides"),
           nrow(bl$refus_tables) == 0L && nrow(bl$declarations_requises) == 0L && nrow(bl$vue$visibilite_non_determinee) == 0L &&
             nrow(bl$exclusions) == 0L && nrow(bl$hypotheses_defaut) == 0L && nrow(bl$signalements) == 0L)
}

section("plans de référence de la base construite (R.2, § 7.8.2)")
for (k in names(COUPLES_C)) {
  p <- plan_c(k)
  o <- ecrire_plan(p)
  verifier(paste0("(R.2) ", k, " : plan valide, aller-retour lire_plan(ecrire_plan()) identique au plan canonique, octet pour octet"),
           inherits(valider_plan(p), "plan_calcul") && identical(lire_plan(o), canoniser_plan(p)) &&
             identical(ecrire_plan(lire_plan(o)), o))
}
verifier("(R.2) les deux plans ne diffèrent que par les méthodes et les entrées des seules méthodes alternatives",
         local({
           a <- plan_c("C1"); b <- plan_c("C3")
           a$postes <- b$postes <- NULL
           b$revalorisation$capital_deces$taux_futur <- NULL
           b$revalorisation$capital_deces$duree_sans_depot_annees <- NULL
           identical(a, b)
         }))

section("recoupement par dossier et par contrat sur les familles (R.3, § 7.8.3)")
# Seconde voie, en R de base (dernière colonne du § 7.8.3).
F2 <- 1.015 * (1 + 0.024 / 365)
g <- 1 + 0.024 * 30 / 365
s <- 364 / 365
p1 <- 0.98 / (1 - 0.02 * s)
d1 <- 1 - p1
v1 <- 1.02^(-1 / 365)
v2 <- 1.02^(-(1 + 1 / 365))
q42 <- 0.03
Pz <- 2282.4557058603
base3 <- 100000 * (d1 * v1 + p1 * q42 * v2)
R1 <- 103936
R3 <- 103936 - 40000 * (1 + 0.024 * 305 / 365)
R4 <- 103936 * 1.024^8 * (1 + 0.024 * 244 / 365)
T2 <- 4882.6989619377
T3 <- 2593.6728916013
T5 <- 2687.3068050750
formules <- list(
  DOR1 = c(R1 * 1.01, 101000 * F2, R1 * g * 1.01, 101000 * F2 * g),
  DOR3 = c(R3 * 1.01, 101000 * F2, R3 * 1.01 * g, 101000 * F2 * g),
  DOR5A = c(83325 * 1.03936, 83325 * F2, 83325 * 1.03936 * g, 83325 * F2 * g),
  DOR5B = c(78780 * 1.03936, 78780 * F2, 78780 * 1.03936 * g, 78780 * F2 * g),
  DOR4 = c(R1, 100000 * F2, R4, 100000 * F2 * (1 + 0.024 * 364 / 365) * 1.024^8 * (1 + 0.024 * 244 / 365)),
  CTI1 = c(base3 + 100 * p1 * v1, T2, base3 + 100 * p1 * v1, T2),
  CTI3 = c(base3 - Pz * p1 * v1, T3, base3 - 2185 * p1 * v1, T5),
  CTC1 = c(1200 * 0.95 * 181 / 365, 1200 * 0.95 * 180 / 365, 1200 * 0.95 * 181 / 365, 1200 * 0.95 * 180 / 365))
# Valeurs en dur du § 7.8.3 (colonnes C1 à C4).
attendus <- list(
  DOR1 = c(104975.3600000000, 102521.7407123288, 105182.4346827397, 102723.9753789394),
  DOR3 = c(63765.1463013698, 102521.7407123288, 63890.9296036630, 102723.9753789394),
  DOR5A = c(86604.6720000000, 84580.4360876712, 86775.5086132602, 84747.2796876250),
  DOR5B = c(81880.7808000000, 79966.9577556164, 82042.2990525370, 80124.7007955727),
  DOR4 = c(103936.0000000000, 101506.6739726027, 127666.8365965362, 127667.0328043410),
  CTI1 = c(3046.4321195552, 4882.6989619377, 3046.4321195552, 4882.6989619377),
  CTI3 = c(664.2388624387, 2593.6728916013, 761.6838326839, 2687.3068050750),
  CTC1 = c(565.3150684932, 562.1917808219, 565.3150684932, 562.1917808219))
# Les valeurs du § 7.8.3 sont écrites à dix décimales : la seconde voie les recoupe à 5e-11 près.
verifier("(R.3) seconde voie en R de base : formules fermées du § 7.8.3 = valeurs en dur (à l'arrondi de la dixième décimale)",
         all(vapply(names(attendus), function(n) all(abs(formules[[n]] - attendus[[n]]) <= 5e-11 + EPS * pmax(1, abs(attendus[[n]]))), NA)))
familles <- lapply(names(COUPLES_C), function(k) {
  p <- plan_c(k)
  v <- vue_c(base, p)
  list(P1 = ns$calculer_engagement(v, p, tb, cat_g, "deces", P1), P2 = ns$calculer_engagement(v, p, tb, cat_g, "deces", P2),
       P3 = ns$calculer_risque_en_cours(v, p, tb, cat_g, "deces", P3),
       ind = ns$provisions_individuelles(v, p, tb, FALSE)$contrats, col = ns$provisions_collectives(v, p))
})
names(familles) <- names(COUPLES_C)
# Montant d'un dossier (dossiers de P1 et P2) ou d'un contrat (P3 : provisions_individuelles(),
# montant après plancher ; provisions_collectives()).
montant_unite <- function(f, id) {
  d <- rbind(f$P1$dossiers, f$P2$dossiers)
  if (id %in% d$id_dossier) return(d$montant[d$id_dossier == id])
  if (id %in% f$ind$id_contrat) return(f$ind$montant[f$ind$id_contrat == id])
  f$col$montant[f$col$id_contrat == id]
}
for (j in seq_along(COUPLES_C)) {
  k <- names(COUPLES_C)[j]
  f <- familles[[k]]
  obtenus <- vapply(names(attendus), function(n) montant_unite(f, n), 0)
  verifier(paste0("(R.3) ", k, " : montant de chaque dossier (P1, P2) et de chaque contrat (P3) = § 7.8.3, à 1e-10 (mixte)"),
           egal_mixte(unname(obtenus), vapply(attendus, function(a) a[j], 0, USE.NAMES = FALSE)))
  alt <- k %in% c("C3", "C4")
  verifier_egal(paste0("(R.3) ", k, " : statuts des dossiers et des contrats"),
                list(f$P1$dossiers$id_dossier, f$P1$dossiers$statut_resultat, f$P2$dossiers$statut_resultat,
                     f$ind$id_contrat, f$ind$hypothese_d03h, f$col$id_contrat, f$P3$cellules$statut_resultat),
                list(c("DOR1", "DOR3", "DOR5A", "DOR5B"),
                     if (alt) rep("jugement_expert", 4L) else c("exact", "exact", "exact", "jugement_expert"),
                     if (alt) "jugement_expert" else "exact", c("CTI1", "CTI3"), c(FALSE, FALSE), "CTC1",
                     "approximation_numerique"))
  dates <- switch(k, C1 = c("2026-01-01", "2026-01-01"), C2 = c("2025-01-02", "2025-01-02"),
                  C3 = c("2026-01-30", "2034-09-01"), C4 = c("2025-01-31", "2034-09-01"))
  verifier_egal(paste0("(R.3) ", k, " : dates des flux de P1 et de P2 ; lignes d'échéancier 8 (P1), 2 (P2), 6 (P3)"),
                list(unique(f$P1$echeanciers$date), unique(f$P2$echeanciers$date), nrow(f$P1$echeanciers),
                     nrow(f$P2$echeanciers), nrow(f$P3$echeanciers)),
                list(D(dates[1L]), D(dates[2L]), 8L, 2L, 6L))
  ind <- rbind(f$P1$indicateurs, f$P2$indicateurs)
  verifier_egal(paste0("(R.3) ", k, " : indicateurs : deux R132_3_1 par poste de P1 et P2 (2024 serie_incomplete, 2025), six pour P3, ",
                       "aucun methode_revalorisation_mixte ni depot_cdc_echu"),
                list(table(ind$regle, ind$poste)[["R132_3_1", P1]], table(ind$regle, ind$poste)[["R132_3_1", P2]],
                     sum(grepl("annee=2024", ind$detail) & grepl("serie_incomplete", ind$detail)), nrow(f$P3$indicateurs),
                     sum(ind$regle %in% c("methode_revalorisation_mixte", "depot_cdc_echu"))),
                list(2L, 2L, 2L, 6L, 0L))
}

section("cellules ensemble des familles (R.3, § 7.8.4)")
CELLULES <- list(  # P1, P2, P3 ensemble (C1 à C4)
  P1 = c(337225.9591013698, 369590.8752679452, 337891.1719521999, 370319.9312410764),
  P2 = c(103936.0000000000, 101506.6739726027, 127666.8365965362, 127667.0328043410),
  P3 = c(4275.9860504871, 8038.5636343610, 4373.4310207322, 8132.1975478346))
for (j in seq_along(COUPLES_C)) {
  k <- names(COUPLES_C)[j]
  f <- familles[[k]]
  verifier(paste0("(R.3) ", k, " : cellules ensemble de P1, P2 et P3 = § 7.8.4 ; nombre de dossiers 4, 1, 0"),
           egal_mixte(c(f$P1$cellules$montant, f$P2$cellules$montant, f$P3$cellules$montant),
                      c(CELLULES$P1[j], CELLULES$P2[j], CELLULES$P3[j])) &&
             identical(c(f$P1$cellules$nombre_dossiers, f$P2$cellules$nombre_dossiers, f$P3$cellules$nombre_dossiers),
                       c(4L, 1L, 0L)))
  verifier(paste0("(R.3) ", k, " : cellules ensemble = sommes des valeurs du § 7.8.3"),
           egal_mixte(c(f$P1$cellules$montant, f$P2$cellules$montant, f$P3$cellules$montant),
                      c(sum(vapply(c("DOR1", "DOR3", "DOR5A", "DOR5B"), function(n) attendus[[n]][j], 0)), attendus$DOR4[j],
                        sum(vapply(c("CTI1", "CTI3", "CTC1"), function(n) attendus[[n]][j], 0)))))
}

section("non-interférence (R.4, § 7.8.1) : chaque unité vaut sa base isolée")
isolees <- list(DOR1 = list(b2_base_capital(), "DO1", P1),
                DOR3 = list(b2_base_capital(paiements = data.frame(date = D("2025-03-01"), montant = 40000)), "DO1", P1),
                DOR4 = list(b2_base_capital(qualite = "non_identifie"), "DO1", P2),
                DOR5A = list(b2_base_capital(capital = NA), "DO1", P1),
                DOR5B = list(b2_base_capital(capital = NA, instruction = D(NA)), "DO1", P1),
                CTI1 = list(b2_base_p3(), "CT2", P3), CTI3 = list(b2_base_p3("annuelle", 2300), "CT2", P3),
                CTC1 = list(b2_base_p3(cotisation = data.frame(debut = D(c("2025-07-01", "2024-07-01")),
                                                               fin = D(c("2026-06-30", "2025-06-30")), montant = 1200,
                                                               mouvement = D(c("2025-07-01", "2024-07-01")))), "CT3", P3))
for (k in names(COUPLES_C)) {
  p <- plan_c(k)
  f <- familles[[k]]
  ok <- vapply(names(isolees), function(n) {
    x <- isolees[[n]]
    v <- vue_c(x[[1L]], p)
    seul <- if (x[[3L]] == P3) rbind(ns$provisions_individuelles(v, p, tb, FALSE)$contrats[c("id_contrat", "montant")],
                                     ns$provisions_collectives(v, p)) else
      ns$calculer_engagement(v, p, tb, cat_g, "deces", x[[3L]])$dossiers
    m <- if (x[[3L]] == P3) seul$montant[seul$id_contrat == x[[2L]]] else seul$montant[seul$id_dossier == x[[2L]]]
    egal_mixte(m, montant_unite(f, n))
  }, NA)
  verifier(paste0("(R.4) ", k, " : dossiers et contrats de la base construite = bases isolées (", paste(names(isolees), collapse = ", "),
                  ")"), all(ok))
}
