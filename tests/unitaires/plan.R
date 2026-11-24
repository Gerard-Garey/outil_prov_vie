# Tests unitaires du module `plan` (R/plan.R ; spécification de B2, § 2 et § 7.1, critères
# (1.2) à (1.9)). Exécuté par tests/test_unitaires.R : le package est installé et chargé, le
# harnais est sourcé, `racine` est défini.

ns <- asNamespace("provie")
refus_de <- function(expr) tryCatch({ expr; NULL }, refus_provie = function(e) e)
# Refus de motif `motif` dont le message nomme `chemin`.
verifier_chemin <- function(nom, expr, motif, chemin) {
  r <- refus_de(expr)
  verifier(nom, !is.null(r) && identical(r$motif, motif) && grepl(chemin, conditionMessage(r), fixed = TRUE) &&
             identical(r$attendu, chemin))
}

# Plan minimal de B2 (spécification de B2, § 7.5) ; empreintes de forme valide (aucune table
# n'est lue par le module plan). Les valeurs familiales sont des valeurs de test.
plan_min <- function() list(
  version_plan = 1L, arrete = as.Date("2025-12-31"),
  perimetre = list(garanties = "deces", referentiels = "comptes_sociaux", segmentations = list()),
  tables = list(
    mortalite_tarif = list(identifiant = "mortalite_fictive_b2", empreinte = strrep("a", 32), statut = "fictive",
                           hors_axes = "refus"),
    serie_tme = list(identifiant = "tme_fictive_b2", empreinte = strrep("b", 32), statut = "fictive", hors_axes = "refus",
                     decalage_publication_mois = 1L)),
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
      individuel = list(methode = "prospective_prime_pure",
                        parametres = list(pas = "an", paiement_capital = "fin_pas", plancher = "par_contrat")),
      collectif = list(methode = "prorata_cotisation", parametres = list())))),
  donnees = list(), restitution = list(echeanciers = "aucun", triangles = "aucun"), liens = list(), graine = 1L)

# Altère le plan minimal : `f` reçoit le plan et le rend modifié.
alt <- function(f) f(plan_min())
P1 <- c("postes", "deces", "sinistres_declares_non_regles")
P2 <- c("postes", "deces", "capitaux_non_reclames")
P3 <- c("postes", "deces", "provision_mathematique_temporaire_deces")
sans <- function(p, chemin) { p[[chemin]] <- NULL; p }
avec <- function(p, chemin, valeur) { p[[chemin]] <- valeur; p }

section("plan : plan minimal de B2 (critère 1.2)")

v <- valider_plan(plan_min())
verifier("valider_plan() rend le plan, classe plan_calcul", inherits(v, "plan_calcul") &&
           identical(unclass(v), plan_min()))
verifier("valider_plan() d'un plan déjà de classe plan_calcul : inchangé", identical(valider_plan(v), v))
cp <- canoniser_plan(plan_min())
verifier_egal("plan canonique : sections dans l'ordre du point 17", names(cp), ns$SECTIONS_PLAN)
verifier_egal("plan canonique : vecteurs-ensembles triés",
              cp$postes$deces$sinistres_declares_non_regles$parametres$liens_conjoint_majoration,
              c("concubin", "conjoint", "partenaire_pacs"))
verifier_egal("plan canonique : taux_par_annee en liste nommée triée par année",
              cp$revalorisation$capital_deces$taux_par_annee, list(`2024` = 0.03, `2025` = 0.024))
verifier_egal("plan canonique : postes (clés libres) triés", names(cp$postes$deces),
              sort(names(plan_min()$postes$deces), method = "radix"))
verifier_egal("plan canonique : champs de P3 dans l'ordre du catalogue", names(cp$postes$deces$provision_mathematique_temporaire_deces),
              c("individuel", "collectif"))
verifier("plan canonique : canoniser_plan() idempotent", identical(canoniser_plan(cp), cp))
verifier("taux technique taux_tarif admis",
         inherits(valider_plan(avec(plan_min(), c("taux", "deces", "provision_mathematique_temporaire_deces",
                                                  "comptes_sociaux"), "taux_tarif")), "plan_calcul"))
verifier("prospective_prime_declaree admise", inherits(valider_plan(avec(plan_min(), c(P3, "individuel", "methode"),
                                                                         "prospective_prime_declaree")), "plan_calcul"))
verifier("segmentations des quatre règles admises en B2 (contrat, nature_contrat, ligne_activite avec correspondance couvrant le périmètre, annee_survenance) : admises (critère 1.4, erratum v1.0.12)",
         inherits(valider_plan(avec(plan_min(), c("perimetre", "segmentations"),
                                    list(lob = list(regle = "ligne_activite", correspondance = list(deces = "32")),
                                         par_contrat = list(regle = "contrat"), nc = list(regle = "nature_contrat"),
                                         an = list(regle = "annee_survenance")))), "plan_calcul") &&
           identical(ns$REGLES_SEGMENTATION_B2, c("contrat", "nature_contrat", "annee_survenance", "ligne_activite")))
verifier("restitution des échéanciers par identifiants admise",
         inherits(valider_plan(avec(plan_min(), c("restitution", "echeanciers"), c("DO2", "DO1"))), "plan_calcul"))
# Entrées connues du schéma mais non lues par le périmètre : admises et canonisées (§ 2.3).
p <- plan_min()
p$conventions$limite_age <- list(age = "revolu", regle = "depassement")
p[[c(P1, "parametres", "delai_reglement_jours")]] <- 30
p$revalorisation$capital_deces$taux_futur <- 0.02
p$revalorisation$capital_deces$duree_sans_depot_annees <- 10
p[[c(P2, "parametres", "mois_sans_evenement")]] <- 12L
cpn <- canoniser_plan(p)
verifier("entrées connues non lues (limite_age, delai_reglement_jours, taux_futur, duree_sans_depot_annees, mois_sans_evenement) : admises",
         inherits(valider_plan(p), "plan_calcul"))
verifier("entrées connues non lues : canonisées (ordre du schéma, double entier en integer)",
         identical(names(cpn$conventions$limite_age), c("regle", "age")) &&
           identical(cpn[[c(P1, "parametres", "delai_reglement_jours")]], 30L) &&
           identical(names(cpn$revalorisation$capital_deces), c("taux_par_annee", "prorata", "taux_futur", "duree_sans_depot_annees")) &&
           identical(names(cpn[[c(P2, "parametres")]])[1:2], c("critere", "mois_sans_evenement")))

section("plan : plan_incomplet, le message nomme le chemin (critère 1.3)")

incomplet <- function(nom, p, chemin) verifier_chemin(nom, valider_plan(p), "plan_incomplet", chemin)
for (s in ns$SECTIONS_PLAN) incomplet(paste("section absente :", s), sans(plan_min(), s), s)
for (e in c("age", "instant_date", "repartition_annee", "fractionnement", "decompte_jours")) {
  incomplet(paste0("conventions$", e), sans(plan_min(), c("conventions", e)), paste0("conventions$", e))
}
incomplet("perimetre$segmentations", sans(plan_min(), c("perimetre", "segmentations")), "perimetre$segmentations")
incomplet("revalorisation$capital_deces (P1 et P2 au périmètre)", sans(plan_min(), c("revalorisation", "capital_deces")),
          "revalorisation$capital_deces")
incomplet("revalorisation$capital_deces$prorata", sans(plan_min(), c("revalorisation", "capital_deces", "prorata")),
          "revalorisation$capital_deces$prorata")
incomplet("revalorisation$capital_deces$taux_par_annee",
          sans(plan_min(), c("revalorisation", "capital_deces", "taux_par_annee")), "revalorisation$capital_deces$taux_par_annee")
incomplet("tables$serie_tme (deces en comptes sociaux)", sans(plan_min(), c("tables", "serie_tme")), "tables$serie_tme")
incomplet("tables$serie_tme$decalage_publication_mois",
          sans(plan_min(), c("tables", "serie_tme", "decalage_publication_mois")), "tables$serie_tme$decalage_publication_mois")
incomplet("tables$mortalite_tarif avec prospective_prime_pure", sans(plan_min(), c("tables", "mortalite_tarif")),
          "tables$mortalite_tarif")
incomplet("tables$mortalite_tarif avec prospective_prime_declaree",
          sans(avec(plan_min(), c(P3, "individuel", "methode"), "prospective_prime_declaree"), c("tables", "mortalite_tarif")),
          "tables$mortalite_tarif")
incomplet("tables$mortalite_tarif$empreinte (obligatoire en B2)", sans(plan_min(), c("tables", "mortalite_tarif", "empreinte")),
          "tables$mortalite_tarif$empreinte")
incomplet("taux de P3 avec une méthode prospective", avec(plan_min(), "taux", list()), "taux$deces")
incomplet("taux de P3, référentiel comptes_sociaux",
          avec(plan_min(), c("taux", "deces", "provision_mathematique_temporaire_deces"), list()),
          "taux$deces$provision_mathematique_temporaire_deces$comptes_sociaux")
for (m in c("capital_dossier_reglement", "capital_revalorise_reglement")) {
  poste <- if (m == "capital_dossier_reglement") P1 else P2
  p <- avec(plan_min(), c(poste, "methode"), m)
  if (m == "capital_dossier_reglement") p[[c(P1, "parametres", "delai_reglement_jours")]] <- 30L
  if (m == "capital_revalorise_reglement") p$revalorisation$capital_deces$duree_sans_depot_annees <- 10L
  incomplet(paste("revalorisation$capital_deces$taux_futur avec", m), p, "revalorisation$capital_deces$taux_futur")
}
p <- avec(plan_min(), c(P2, "methode"), "capital_revalorise_reglement")
p$revalorisation$capital_deces$taux_futur <- 0.02
incomplet("duree_sans_depot_annees avec capital_revalorise_reglement", p, "revalorisation$capital_deces$duree_sans_depot_annees")
p <- avec(plan_min(), c(P1, "methode"), "capital_dossier_reglement")
p$revalorisation$capital_deces$taux_futur <- 0.02
incomplet("delai_reglement_jours avec capital_dossier_reglement", p,
          "postes$deces$sinistres_declares_non_regles$parametres$delai_reglement_jours")
incomplet("poste du catalogue non déclaré", sans(plan_min(), P2), "postes$deces$capitaux_non_reclames")
incomplet("postes$deces (garantie du périmètre)", avec(plan_min(), "postes", list()), "postes$deces")
incomplet("critère de P2", sans(plan_min(), c(P2, "parametres", "critere")),
          "postes$deces$capitaux_non_reclames$parametres$critere")
incomplet("mois_sans_evenement avec le critère sans_evenement",
          avec(plan_min(), c(P2, "parametres", "critere"), c("sans_evenement", "beneficiaire_non_identifie")),
          "postes$deces$capitaux_non_reclames$parametres$mois_sans_evenement")
for (e in c("taux_sans_suite", "probabilite_reconnaissance_iad", "structure_familiale", "age_limite_enfant_majoration",
            "liens_conjoint_majoration")) {
  for (poste in list(P1, P2)) {
    incomplet(paste0(poste[3L], " : ", e), sans(plan_min(), c(poste, "parametres", e)),
              paste(c(poste, "parametres", e), collapse = "$"))
  }
}
incomplet("structure_familiale$nombre_enfants", sans(plan_min(), c(P1, "parametres", "structure_familiale", "nombre_enfants")),
          "postes$deces$sinistres_declares_non_regles$parametres$structure_familiale$nombre_enfants")
for (e in c("pas", "paiement_capital", "plancher")) {
  incomplet(paste("P3 individuel :", e), sans(plan_min(), c(P3, "individuel", "parametres", e)),
            paste(c(P3, "individuel", "parametres", e), collapse = "$"))
}
incomplet("méthode de P3 collectif", sans(plan_min(), c(P3, "collectif", "methode")),
          "postes$deces$provision_mathematique_temporaire_deces$collectif$methode")
incomplet("champ collectif de P3", sans(plan_min(), c(P3, "collectif")), "postes$deces$provision_mathematique_temporaire_deces$collectif")
for (poste in c("sinistres_declares_non_regles", "capitaux_non_reclames")) {
  incomplet(paste("frais : taux_chargement_psap de", poste),
            sans(plan_min(), c("frais", "deces", poste, "comptes_sociaux", "taux_chargement_psap")),
            paste0("frais$deces$", poste, "$comptes_sociaux$taux_chargement_psap"))
}
FP3 <- c("frais", "deces", "provision_mathematique_temporaire_deces", "comptes_sociaux")
incomplet("taux_chargement_gestion avec prospective_prime_declaree",
          sans(avec(plan_min(), c(P3, "individuel", "methode"), "prospective_prime_declaree"), c(FP3, "taux_chargement_gestion")),
          paste(c(FP3, "taux_chargement_gestion"), collapse = "$"))
for (e in c("taux_chargement_gestion", "taux_chargement_acquisition", "taux_chargement_cotisation")) {
  incomplet(paste("frais de P3 :", e), sans(plan_min(), c(FP3, e)), paste(c(FP3, e), collapse = "$"))
}
verifier("prospective_prime_declaree : taux_chargement_acquisition non exigé",
         inherits(valider_plan(sans(avec(plan_min(), c(P3, "individuel", "methode"), "prospective_prime_declaree"),
                                    c(FP3, "taux_chargement_acquisition"))), "plan_calcul"))
incomplet("correspondance d'une segmentation ligne_activite",
          avec(plan_min(), c("perimetre", "segmentations"), list(lob = list(regle = "ligne_activite"))),
          "perimetre$segmentations$lob$correspondance")
incomplet("restitution$triangles", sans(plan_min(), c("restitution", "triangles")), "restitution$triangles")

section("plan : plan_invalide (critère 1.4)")

invalide <- function(nom, p, chemin = NULL) {
  if (is.null(chemin)) verifier_refus(nom, valider_plan(p), "plan_invalide")
  else verifier_chemin(nom, valider_plan(p), "plan_invalide", chemin)
}
# Règles de segmentation retirées de B2 (§ 2.2, critère 1.4, erratum v1.0.12) : un témoin par règle ;
# le message nomme la règle et le chemin.
for (regle in c("adherent", "secteur_activite", "college", "gestionnaire")) {
  r <- refus_de(valider_plan(avec(plan_min(), c("perimetre", "segmentations"), list(s1 = list(regle = regle)))))
  verifier(paste0("segmentation de règle ", regle, " : plan_invalide dès valider_plan(), « règle de segmentation reportée après B2 », règle et chemin nommés"),
           !is.null(r) && r$motif == "plan_invalide" &&
             grepl("r\u00e8gle de segmentation report\u00e9e apr\u00e8s B2", conditionMessage(r), fixed = TRUE) &&
             grepl(paste0("(", regle, " ;"), conditionMessage(r), fixed = TRUE) &&
             identical(r$attendu, "perimetre$segmentations$s1$regle"))
}
r <- refus_de(valider_plan(avec(plan_min(), c("perimetre", "referentiels"), c("comptes_sociaux", "solvabilite_2"))))
verifier("solvabilite_2 au périmètre : plan_invalide, aucune méthode de meilleure estimation avant B6",
         !is.null(r) && r$motif == "plan_invalide" && grepl("avant B6", conditionMessage(r), fixed = TRUE))
r <- refus_de(valider_plan(avec(plan_min(), c(P3, "individuel", "methode"), "retrospective")))
verifier("méthode témoin (retrospective) déclarée : plan_invalide, méthode témoin, non option",
         !is.null(r) && r$motif == "plan_invalide" &&
           grepl("m\u00e9thode t\u00e9moin, non option", conditionMessage(r), fixed = TRUE))
invalide("méthode témoin sur un autre poste", avec(plan_min(), c(P1, "methode"), "retrospective"),
         "postes$deces$sinistres_declares_non_regles$methode")
invalide("méthode hors des options du catalogue", avec(plan_min(), c(P1, "methode"), "capital_revalorise"),
         "postes$deces$sinistres_declares_non_regles$methode")
invalide("doublon dans perimetre$garanties", avec(plan_min(), c("perimetre", "garanties"), c("deces", "deces")),
         "perimetre$garanties")
invalide("garantie hors du catalogue de B2", avec(plan_min(), c("perimetre", "garanties"), "incapacite"), "perimetre$garanties")
invalide("entrée inconnue au premier niveau", avec(plan_min(), "options", list()), "options")
# série TME : hors_axes `refus` seul (§ 2.2, § 3.5, erratum v1.0.15) ; témoin : derniere_valeur
# reste admise pour une autre table (mortalite_tarif).
invalide("tables$serie_tme$hors_axes = derniere_valeur (aucune valeur supposée hors de la série)",
         avec(plan_min(), c("tables", "serie_tme", "hors_axes"), "derniere_valeur"), "tables$serie_tme$hors_axes")
verifier("tables$mortalite_tarif$hors_axes = derniere_valeur : admise (témoin) ; tables$serie_tme$hors_axes = refus : admise",
         inherits(valider_plan(avec(plan_min(), c("tables", "mortalite_tarif", "hors_axes"), "derniere_valeur")), "plan_calcul") &&
           inherits(valider_plan(plan_min()), "plan_calcul"))
invalide("entrée inconnue dans les paramètres d'un poste", avec(plan_min(), c(P1, "parametres", "taux_sans_suite_bis"), 0),
         "postes$deces$sinistres_declares_non_regles$parametres$taux_sans_suite_bis")
invalide("entrée inconnue : taux d'un poste hors du schéma de B2",
         avec(plan_min(), c("taux", "deces", "sinistres_declares_non_regles"), list(comptes_sociaux = 0.01)),
         "taux$deces$sinistres_declares_non_regles")
invalide("entrée inconnue : decalage_publication_mois sur mortalite_tarif",
         avec(plan_min(), c("tables", "mortalite_tarif", "decalage_publication_mois"), 1L),
         "tables$mortalite_tarif$decalage_publication_mois")
invalide("usage de table inconnu", avec(plan_min(), c("tables", "incidence_iad"), plan_min()$tables$mortalite_tarif),
         "tables$incidence_iad")
invalide("instant_date = debut_journee", avec(plan_min(), c("conventions", "instant_date"), "debut_journee"),
         "conventions$instant_date")
invalide("triangles = tous", avec(plan_min(), c("restitution", "triangles"), "tous"), "restitution$triangles")
invalide("graine double non entier", avec(plan_min(), "graine", 7.5), "graine")
invalide("graine NA", avec(plan_min(), "graine", NA_integer_), "graine")
invalide("taux hors bornes (0,25)", avec(plan_min(), c("taux", "deces", "provision_mathematique_temporaire_deces", "comptes_sociaux"), 0.25),
         "taux$deces$provision_mathematique_temporaire_deces$comptes_sociaux")
invalide("taux hors bornes (-0,06)", avec(plan_min(), c("taux", "deces", "provision_mathematique_temporaire_deces", "comptes_sociaux"), -0.06),
         "taux$deces$provision_mathematique_temporaire_deces$comptes_sociaux")
invalide("taux : chaîne autre que taux_tarif",
         avec(plan_min(), c("taux", "deces", "provision_mathematique_temporaire_deces", "comptes_sociaux"), "taux_moyen"),
         "taux$deces$provision_mathematique_temporaire_deces$comptes_sociaux")
invalide("taux de revalorisation hors bornes", avec(plan_min(), c("revalorisation", "capital_deces", "taux_par_annee"),
                                                    c(`2024` = 0.3)), "revalorisation$capital_deces$taux_par_annee$2024")
invalide("taux_par_annee : année mal formée", avec(plan_min(), c("revalorisation", "capital_deces", "taux_par_annee"),
                                                    c(`24` = 0.03)), "revalorisation$capital_deces$taux_par_annee")
invalide("taux_par_annee non nommé", avec(plan_min(), c("revalorisation", "capital_deces", "taux_par_annee"), 0.03),
         "revalorisation$capital_deces$taux_par_annee")
invalide("integer là où un double est attendu (aucune conversion)", avec(plan_min(), c(P1, "parametres", "taux_sans_suite"), 0L),
         "postes$deces$sinistres_declares_non_regles$parametres$taux_sans_suite")
invalide("probabilité hors de [0 ; 1]", avec(plan_min(), c(P1, "parametres", "probabilite_reconnaissance_iad"), 1.5),
         "postes$deces$sinistres_declares_non_regles$parametres$probabilite_reconnaissance_iad")
invalide("taux_chargement_cotisation = 1 (domaine [0 ; 1[)", avec(plan_min(), c(FP3, "taux_chargement_cotisation"), 1),
         "frais$deces$provision_mathematique_temporaire_deces$comptes_sociaux$taux_chargement_cotisation")
invalide("age_limite_enfant_majoration hors de 0 à 30", avec(plan_min(), c(P1, "parametres", "age_limite_enfant_majoration"), 31L),
         "postes$deces$sinistres_declares_non_regles$parametres$age_limite_enfant_majoration")
invalide("doublon dans liens_conjoint_majoration (jamais retiré en silence)",
         avec(plan_min(), c(P1, "parametres", "liens_conjoint_majoration"), c("conjoint", "conjoint")),
         "postes$deces$sinistres_declares_non_regles$parametres$liens_conjoint_majoration")
invalide("critère hors liste", avec(plan_min(), c(P2, "parametres", "critere"), "anciennete"),
         "postes$deces$capitaux_non_reclames$parametres$critere")
invalide("paramètre de prorata_cotisation", avec(plan_min(), c(P3, "collectif", "parametres"), list(pas = "an")),
         "postes$deces$provision_mathematique_temporaire_deces$collectif$parametres$pas")
invalide("empreinte en majuscules", avec(plan_min(), c("tables", "serie_tme", "empreinte"), strrep("A", 32)),
         "tables$serie_tme$empreinte")
invalide("statut de table hors liste", avec(plan_min(), c("tables", "serie_tme", "statut"), "officielle"), "tables$serie_tme$statut")
invalide("decalage_publication_mois hors de 1 à 2", avec(plan_min(), c("tables", "serie_tme", "decalage_publication_mois"), 3L),
         "tables$serie_tme$decalage_publication_mois")
invalide("version_plan 2", avec(plan_min(), "version_plan", 2L), "version_plan")
invalide("arrete en chaîne", avec(plan_min(), "arrete", "2025-12-31"), "arrete")
invalide("segmentation nommée ensemble", avec(plan_min(), c("perimetre", "segmentations"), list(ensemble = list(regle = "contrat"))),
         "perimetre$segmentations$ensemble")
invalide("correspondance sur une règle autre que ligne_activite",
         avec(plan_min(), c("perimetre", "segmentations"), list(s = list(regle = "contrat", correspondance = list(deces = "32")))),
         "perimetre$segmentations$s$correspondance")
invalide("échéanciers : tous mêlé à un identifiant", avec(plan_min(), c("restitution", "echeanciers"), c("tous", "DO1")),
         "restitution$echeanciers")
invalide("liens non vide en B2", avec(plan_min(), "liens", list(l1 = list(garantie = "deces"))), "liens$l1")
invalide("valeur NULL", { p <- plan_min(); p["graine"] <- list(NULL); p }, "graine")
invalide("seuil inconnu du sous-schéma donnees", avec(plan_min(), "donnees", list(seuils = list(d99 = list(a = 1)))),
         "donnees$seuils$d99")
invalide("seuil au-delà des entiers de R (3e9) : refusé, jamais NA",
         avec(plan_min(), "donnees", list(seuils = list(d03g_delai_jours = list(contrats = 3e9)))),
         "donnees$seuils$d03g_delai_jours$contrats")
verifier_refus("sous-schéma donnees : rubrique inconnue (refus de lire_declarations())",
               valider_plan(avec(plan_min(), "donnees", list(regles = list()))), "plan_invalide")
verifier_refus("plan qui n'est pas une liste", valider_plan("plan"), "plan_invalide")
verifier_refus("plan d'une autre classe", valider_plan(structure(plan_min(), class = "autre")), "plan_invalide")
# Lien du catalogue entre deux garanties du périmètre, non déclaré (catalogue altéré).
k <- catalogue_garanties()
k$liens <- data.frame(garantie = "deces", garantie_liee = "deces", lien = "double_effet", stringsAsFactors = FALSE)
verifier_refus("lien du catalogue entre deux garanties du périmètre non déclaré : lien_non_declare",
               ns$.canoniser(plan_min(), k, dictionnaire()), "lien_non_declare")

section("plan : canonisation (critère 1.5)")

o <- ecrire_plan(plan_min())
p <- plan_min()
p <- p[rev(names(p))]                                    # sections permutées
p$graine <- 1                                            # double entier
p$postes$deces <- p$postes$deces[rev(names(p$postes$deces))]
p$tables <- p$tables[rev(names(p$tables))]
p$tables$serie_tme <- p$tables$serie_tme[rev(names(p$tables$serie_tme))]
p$conventions <- p$conventions[rev(names(p$conventions))]
p$revalorisation$capital_deces$taux_par_annee <- list(`2025` = 0.024, `2024` = 0.03)
p$postes$deces$sinistres_declares_non_regles$parametres$liens_conjoint_majoration <- c("partenaire_pacs", "concubin", "conjoint")
p$postes$deces$sinistres_declares_non_regles$parametres$age_limite_enfant_majoration <- 26
verifier_egal("deux plans de même sens (sections, clés libres et ensembles permutés, 1 contre 1L) : mêmes octets",
              ecrire_plan(p), o)
q <- plan_min(); q$graine <- 7
r <- plan_min(); r$graine <- 7L
verifier_egal("graine = 7 contre 7L : mêmes octets", ecrire_plan(q), ecrire_plan(r))
verifier("graine canonisée en integer", identical(canoniser_plan(q)$graine, 7L))
ex <- data.frame(motif = c("D04b", "D01b"), famille = c("triangle", "engagement"), action = c("exclure", "conserver"),
                 stringsAsFactors = FALSE)
p1 <- avec(plan_min(), "donnees", list(exclusions = ex, seuils = list(d03g_delai_jours = list(sinistres = 5, contrats = 30),
                                                                     d02c_age_min = list(famille = 0, assures_sinistre = 16))))
p2 <- avec(plan_min(), "donnees", list(
  seuils = list(d02c_age_min = list(assures_sinistre = 16L, famille = 0L), d03g_delai_jours = list(contrats = 30L, sinistres = 5L)),
  exclusions = list(list(motif = "D01b", famille = "engagement", action = "conserver"),
                    list(action = "exclure", motif = "D04b", famille = "triangle"))))
verifier_egal("sous-schéma donnees : data.frame et liste de listes, ordres permutés : mêmes octets",
              ecrire_plan(p1), ecrire_plan(p2))
verifier_egal("sous-schéma donnees canonique : lignes triées, noms 1, 2 ; seuils triés, entiers",
              canoniser_plan(p1)$donnees,
              list(exclusions = list(`1` = list(motif = "D01b", famille = "engagement", action = "conserver"),
                                     `2` = list(motif = "D04b", famille = "triangle", action = "exclure")),
                   seuils = list(d02c_age_min = list(assures_sinistre = 16L, famille = 0L),
                                 d03g_delai_jours = list(contrats = 30L, sinistres = 5L))))
verifier_egal("restitution$echeanciers : ensemble trié (radix), mêmes octets quel que soit l'ordre",
              ecrire_plan(avec(plan_min(), c("restitution", "echeanciers"), c("DO2", "DO10", "DO1"))),
              ecrire_plan(avec(plan_min(), c("restitution", "echeanciers"), c("DO1", "DO10", "DO2"))))
verifier_egal("restitution$echeanciers canonique", canoniser_plan(avec(plan_min(), c("restitution", "echeanciers"),
                                                                       c("DO2", "DO10", "DO1")))$restitution$echeanciers,
              c("DO1", "DO10", "DO2"))
pf <- plan_min(); pf$frais$deces <- pf$frais$deces[c(3L, 1L, 2L)]
verifier_egal("frais : postes permutés, mêmes octets", ecrire_plan(pf), o)
verifier_egal("frais : postes triés comme dans postes", names(canoniser_plan(pf)$frais$deces), names(cp$postes$deces))
oq <- ecrire_plan(avec(pf, c("restitution", "echeanciers"), c("DO2", "DO1")))
verifier("aller-retour avec échéanciers et frais permutés", identical(ecrire_plan(lire_plan(oq)), oq) &&
           identical(lire_plan(oq), canoniser_plan(avec(pf, c("restitution", "echeanciers"), c("DO2", "DO1")))))
verifier("deux plans de sens différent : octets différents",
         !identical(ecrire_plan(avec(plan_min(), "graine", 2L)), o))

section("plan : aller-retour du plan (critère 1.6)")

verifier("identical(lire_plan(ecrire_plan(p)), canoniser_plan(valider_plan(p)))",
         identical(lire_plan(ecrire_plan(plan_min())), canoniser_plan(valider_plan(plan_min()))))
verifier("identical(ecrire_plan(lire_plan(o)), o)", identical(ecrire_plan(lire_plan(o)), o))
verifier("lire_plan() rend la classe plan_calcul", inherits(lire_plan(o), "plan_calcul"))
o2 <- ecrire_plan(p1)
verifier("aller-retour avec un sous-schéma donnees non vide", identical(lire_plan(o2), canoniser_plan(p1)) &&
           identical(ecrire_plan(lire_plan(o2)), o2))
verifier("plan relu : accepté par valider_plan()", inherits(valider_plan(lire_plan(o)), "plan_calcul"))
verifier("lire_plan() ne valide pas : un plan incomplet écrit à la main se relit",
         inherits(lire_plan(ns$ecrire_liste(list(version_plan = 1L))), "plan_calcul"))
verifier_refus("lire_plan() : texte non canonique refusé", lire_plan(charToRaw("provie-liste 1\ngraine\tdouble\t1.50\n")),
               "liste_invalide")

section("plan : fiche de calcul, aller-retour (critère 1.6) et VERSION_FICHE (critère 1.7)")

j <- lire_jeu(file.path(racine, "inst", "extdata", "jeux", "v1-modeste-04"))
base <- j$base
bilan <- controler_base(base, as.Date("2025-12-31"), j$declarations$declarations, j$declarations$conventions)
vide_chr <- function(colonnes) as.data.frame(stats::setNames(rep(list(character(0)), length(colonnes)), colonnes),
                                             stringsAsFactors = FALSE)
# Paramètres retenus vides de forme fixe ; les colonnes des cinq derniers sont des formes de
# test (fixées en (4)) : bilan de controler_base() et champ indicateurs (ADR 0010, point 6).
pr <- list(
  postes = vide_chr(ns$COLONNES_POSTES_RETENUS), tables = vide_chr(ns$COLONNES_TABLES_RETENUES),
  hypotheses_defaut = bilan$hypotheses_defaut, exclusions = bilan$exclusions,
  plafonds = data.frame(regle = character(0), poste = character(0), garantie = character(0), valeur_regle = numeric(0),
                        valeur_retenue = numeric(0), depassement = logical(0), detail = character(0), stringsAsFactors = FALSE),
  colonnes_ecrasees = vide_chr(c("table", "colonne")),
  tables_absentes = data.frame(table = bilan$tables_absentes, stringsAsFactors = FALSE))
table_recue <- function(e) list(identifiant = "x", origine = list(empreinte = e))
tables <- list(tme_fictive_b2 = table_recue(strrep("b", 32)), mortalite_fictive_b2 = table_recue(strrep("a", 32)))
provenance <- list(base = list(contrats.csv = strrep("c", 32)))
fiche <- ns$construire_fiche(plan_min(), base, pr, tables, provenance)
verifier("fiche : classe fiche_calcul, champs dans l'ordre de l'ADR 0007, point 3",
         inherits(fiche, "fiche_calcul") && identical(names(fiche), ns$CHAMPS_FICHE))
verifier_egal("fiche : VERSION_FICHE = 1", fiche$versions$fiche, 1L)
verifier("fiche : plan canonique de classe plan_calcul", identical(fiche$plan, canoniser_plan(plan_min())))
verifier_egal("fiche : une empreinte par table de la base, dans l'ordre du dictionnaire",
              names(fiche$empreintes$donnees), dictionnaire()$tables$table[dictionnaire()$tables$table %in% names(base)])
verifier("fiche : empreintes MD5", all(grepl("^[0-9a-f]{32}$", unlist(fiche$empreintes$donnees))))
verifier_egal("fiche : empreintes des tables reçues, triées par identifiant", fiche$empreintes$tables,
              list(mortalite_fictive_b2 = strrep("a", 32), tme_fictive_b2 = strrep("b", 32)))
verifier("fiche : provenance reprise ; résultat et code non remplis (issue 4) ; représentation canonique",
         identical(fiche$empreintes$fichiers, provenance) && is.na(fiche$empreintes$resultat) && is.na(fiche$empreintes$code) &&
           identical(fiche$empreintes$representation, "provie-resultat-1"))
verifier("fiche : versions de R, de provie, du dictionnaire",
         identical(fiche$versions$r, paste(R.version$major, R.version$minor, sep = ".")) &&
           identical(fiche$versions$provie, as.character(utils::packageVersion("provie"))) &&
           identical(fiche$versions$dictionnaire, "1.6"))
verifier_egal("fiche : graine et générateur", fiche$graine,
              list(valeur = 1L, generateur = c("Mersenne-Twister", "Inversion", "Rejection")))
verifier_egal("générateur consigné = celui que fixe avec_graine()", ns$avec_graine(1L, RNGkind()), ns$.GENERATEUR_GRAINE)
verifier("fiche : plateforme = decrire_plateforme()", identical(fiche$plateforme, ns$decrire_plateforme()))
of <- ecrire_fiche(fiche)
verifier("identical(lire_fiche(ecrire_fiche(f)), f)", identical(lire_fiche(of), fiche))
verifier("identical(ecrire_fiche(lire_fiche(o)), o)", identical(ecrire_fiche(lire_fiche(of)), of))
fiche_np <- ns$construire_fiche(plan_min(), base, pr)
verifier("fiche sans tables ni provenance : aller-retour", identical(lire_fiche(ecrire_fiche(fiche_np)), fiche_np) &&
           is.null(fiche_np$empreintes$fichiers) && identical(fiche_np$empreintes$tables, list()))
pr_plein <- pr
pr_plein$postes <- data.frame(garantie = "deces", referentiel = "comptes_sociaux", poste = "capitaux_non_reclames",
                              famille = "engagement", methode = "capital_revalorise", statut_methode = "recommandee",
                              parametres = "x", usages_tables = "", stringsAsFactors = FALSE)
pr_plein$plafonds <- data.frame(regle = "R132_3_1", poste = "capitaux_non_reclames", garantie = "deces", valeur_regle = 0.024,
                                valeur_retenue = NA_real_, depassement = NA, detail = "annee=2025;minimum",
                                stringsAsFactors = FALSE)
fiche_pleine <- ns$construire_fiche(plan_min(), base, pr_plein, tables)
verifier("fiche à paramètres retenus non vides : aller-retour octet pour octet",
         identical(lire_fiche(ecrire_fiche(fiche_pleine)), fiche_pleine) &&
           identical(ecrire_fiche(lire_fiche(ecrire_fiche(fiche_pleine))), ecrire_fiche(fiche_pleine)))
verifier("deux constructions de la fiche : mêmes octets", identical(ecrire_fiche(ns$construire_fiche(plan_min(), base, pr, tables,
                                                                                                    provenance)), of))
verifier_refus("paramètres retenus incomplets : refus", ns$construire_fiche(plan_min(), base, pr[-1L]), "liste_invalide")
pr_mal <- pr; pr_mal$postes$poste <- NULL
verifier_refus("colonnes de parametres_retenus$postes autres que celles du point 10 : refus",
               ns$construire_fiche(plan_min(), base, pr_mal), "liste_invalide")
verifier_refus("construire_fiche() d'un plan invalide : refus du plan", ns$construire_fiche(avec(plan_min(), "graine", 1.5), base, pr),
               "plan_invalide")
verifier_refus("ecrire_fiche() d'un objet qui n'est pas une fiche", ecrire_fiche(unclass(fiche)), "liste_invalide")
verifier_refus("lire_fiche() d'un plan", lire_fiche(o), "liste_invalide")
melange <- base[rev(names(base))]
melange$contrats <- melange$contrats[rev(seq_len(nrow(melange$contrats))), , drop = FALSE]
verifier("empreintes des données : indépendantes de l'ordre des tables et des lignes (tri par clé primaire)",
         identical(ns$.empreintes_base(melange, dictionnaire()), fiche$empreintes$donnees))

section("plan : contrôles du rejeu (critère 1.7)")

verifier_egal("rejeu sur les mêmes données et tables : aucun signalement",
              nrow(ns$controler_rejeu(fiche, base, tables)$signalements), 0L)
f2 <- fiche; f2$versions$fiche <- 2L
verifier_refus("version de fiche différente : version_discordante", ns$controler_rejeu(f2, base, tables), "version_discordante")
b2 <- base
# assures précède contrats dans l'ordre alphabétique, contrats (T3) précède assures (T6) dans
# celui du dictionnaire : le test départage les deux ordres.
b2$assures$date_naissance[1L] <- b2$assures$date_naissance[1L] + 1
b2$contrats$date_effet[1L] <- b2$contrats$date_effet[1L] + 1
r <- refus_de(ns$controler_rejeu(fiche, b2, tables))
verifier("tables contrats et assures modifiées : empreinte_discordante sur contrats, première dans l'ordre du dictionnaire (non alphabétique)",
         !is.null(r) && r$motif == "empreinte_discordante" && identical(r$table, "contrats"))
r <- refus_de(ns$controler_rejeu(f2, b2, tables))
verifier("ordre des refus : la version de la fiche avant les empreintes", !is.null(r) && r$motif == "version_discordante")
b3 <- base; b3$cotisations <- NULL
r <- refus_de(ns$controler_rejeu(fiche, b3, tables))
verifier("table de la base absente des données : empreinte_discordante", !is.null(r) && r$motif == "empreinte_discordante" &&
           identical(r$table, "cotisations"))
f3 <- fiche; f3$versions$r <- "4.3.2"; f3$versions$provie <- "0.3.0"
s <- ns$controler_rejeu(f3, base, tables)$signalements
verifier_egal("versions de R et de provie différentes : signalées, sans refus", s,
              data.frame(grandeur = c("r", "provie"), fiche = c("4.3.2", "0.3.0"),
                         courant = c(fiche$versions$r, fiche$versions$provie), stringsAsFactors = FALSE))
verifier_refus("table de la fiche non reçue : table_absente", ns$controler_rejeu(fiche, base, tables["tme_fictive_b2"]),
               "table_absente")
t2 <- tables; t2$tme_fictive_b2 <- table_recue(strrep("d", 32))
r <- refus_de(ns$controler_rejeu(fiche, base, t2))
verifier("empreinte d'une table reçue différente : empreinte_discordante", !is.null(r) && r$motif == "empreinte_discordante" &&
           identical(r$usage, "tme_fictive_b2"))
r <- refus_de(ns$controler_rejeu(fiche, b2, t2))
verifier("ordre des refus : les données avant les tables", !is.null(r) && identical(r$table, "contrats"))
verifier("fiche relue : mêmes contrôles", nrow(ns$controler_rejeu(lire_fiche(of), base, tables)$signalements) == 0L)

section("plan : sous-schéma donnees inchangé (critère 1.8)")

for (nom in c("v1-modeste-04", "v1-modeste-07")) {
  jj <- lire_jeu(file.path(racine, "inst", "extdata", "jeux", nom))
  p <- plan_min()
  p$donnees <- jj$declarations$declarations
  p$conventions <- c(jj$declarations$conventions, list(instant_date = "fin_journee", repartition_annee = "uniforme",
                                                       fractionnement = "echeances_exactes", decompte_jours = "exact_exact"))
  verifier(paste0(nom, " : declarations.txt dans plan$donnees et plan$conventions : valider_plan() l'accepte"),
           inherits(valider_plan(p), "plan_calcul"))
  cpj <- canoniser_plan(p)
  for (a in c("2024-12-31", "2025-12-31")) {
    a <- as.Date(a)
    verifier(paste0(nom, " au ", format(a), " : controler_base() rend le même bilan avec le plan canonique (identical)"),
             identical(controler_base(jj$base, a, cpj$donnees, cpj$conventions),
                       controler_base(jj$base, a, jj$declarations$declarations, jj$declarations$conventions)))
  }
}

section("plan : forme de la valeur des hypothèses H (critère (4.11), #99 ; spécification de B2, erratum v1.0.21, § 2.3)")

# Toute ligne de `hypotheses`, placée ou non, pour tout référentiel et tout poste, a la forme de
# son motif (dictionnaire 1.6, § 9) ; contrôle unique, lire_declarations() (`donnees`), donc
# valider_plan(), controler_base() et vue_a_date() refusent plan_invalide. Base v1-modeste-04
# (aucun constat : aucune ligne n'est placée sous l'hypothèse) et v1-modeste-07 (D03b et D03c
# placées) ; une ligne déclarée pour un seul référentiel (comptes_sociaux, puis solvabilite_2) ;
# poste `tous` (D02a et D02b : seul poste admis), sinon P1. Avant #99 : acceptées (m34), sauf le
# signalement d'un motif non alternatif (règle existante). Ici, une hypothèse est placée sur une
# ligne, non lue par un poste ; le cas d'une valeur lue par un poste est testé ailleurs : (4.9)
# dans tests/unitaires/engagement.R (D03c), (4.6) (k) et (l) dans
# tests/unitaires/calculer_provisions.R (D03f), D03h dans tests/unitaires/risque_en_cours.R.
j7 <- lire_jeu(file.path(racine, "inst", "extdata", "jeux", "v1-modeste-07"))
hyp1 <- function(motif, valeur, referentiel) {
  list(list(motif = motif, referentiel = referentiel, poste = if (motif %in% c("D02a", "D02b")) "tous" else
    "sinistres_declares_non_regles", valeur = valeur))
}
refus_hypothese <- function(motif, valeur, referentiel) {
  h <- hyp1(motif, valeur, referentiel)
  p <- plan_min()
  p$donnees <- list(hypotheses = h)
  m <- function(expr) tryCatch({ expr; "aucun" }, refus_provie = function(e) e$motif)
  c(valider_plan = m(valider_plan(p)),
    controler_base = m(controler_base(base, as.Date("2025-12-31"), list(hypotheses = h))),
    controler_base_07 = m(controler_base(j7$base, as.Date("2025-12-31"), list(hypotheses = h))),
    vue_a_date = m(ns$vue_a_date(j7$base, as.Date("2025-12-31"), list(hypotheses = h), NULL)))
}
d03c_309 <- paste0("ensemble=", strrep("9", 309L))
formes_refusees <- list(
  c("regle mal écrite (D02a)", "D02a", "Regle"), c("regle mal écrite, blanc final (D06)", "D06", "regle "),
  c("D03f autre que regle", "D03f", "n_importe"), c("signalement sur un motif non alternatif (D03c)", "D03c", "signalement"),
  c("liste par clé, clé inconnue (D03b)", "D03b", "pere=M"), c("liste par clé, clé en double (D03b)", "D03b", "assure=M;assure=F"),
  c("liste par clé, élément vide (D03b)", "D03b", "assure=M;;enfant=F"), c("liste par clé, « ; » final (D03b)", "D03b", "assure=M;"),
  c("liste par clé, blanc (D03b)", "D03b", "assure=M; enfant=F"), c("D03b, valeur hors domaine", "D03b", "enfant=oppose_assure"),
  c("D05 sans decompte", "D05", "motif=refus"), c("D05, clé en trop", "D05", "motif=refus;decompte=compte;autre=x"),
  c("décimal mal écrit (D03h, virgule)", "D03h", "0,01"), c("décimal mal écrit (D03h, zero)", "D03h", "zero"),
  c("D03h à -0,0501", "D03h", "-0.0501"), c("D03h à 0,1001", "D03h", "0.1001"), c("D13 à 1,01", "D13", "1.01"),
  c("D03e hors catégorie", "D03e", "cat4"), c("D03c, montant négatif", "D03c", "ensemble=-1"),
  c("D03c, montant à exposant", "D03c", "ensemble=3e4"), c("D03c, 309 « 9 » (non fini en double)", "D03c", d03c_309),
  c("D03c, collège avec U+0020", "D03c", "cad res=40000"), c("D03c, collège avec « = »", "D03c", "a=b=40000"),
  c("D03c, collège vide", "D03c", "=40000"), c("D03c, collège répété", "D03c", "ensemble=1;ensemble=2"),
  # valeurs de m34 (acceptées avant #99) ; D03c n_importe déclarée pour solvabilite_2 seulement :
  # tour du référentiel solvabilite_2 de la boucle ci-dessous
  c("D02b autre que regle (m34)", "D02b", "visibilite_max_saisie_effet_parente"),
  c("D03b, texte libre (m34)", "D03b", "sexe_par_defaut_du_poste"), c("D03h à 0,5 (m34)", "D03h", "0.5"),
  c("D03h à -0,2 (m34)", "D03h", "-0.2"), c("D03c, texte libre (m34)", "D03c", "n_importe"))
for (f in formes_refusees) {
  for (r in ns$REFERENTIELS) {
    verifier_egal(paste0("(4.11) ", f[[1L]], ", valeur « ", substr(f[[3L]], 1L, 40L), " », déclarée pour ", r,
                         " : plan_invalide par valider_plan(), controler_base() (ligne non placée, puis jeu v1-modeste-07) et vue_a_date()"),
                  refus_hypothese(f[[2L]], f[[3L]], r),
                  c(valider_plan = "plan_invalide", controler_base = "plan_invalide", controler_base_07 = "plan_invalide",
                    vue_a_date = "plan_invalide"))
  }
}
r <- refus_de(valider_plan(avec(plan_min(), "donnees", list(hypotheses = hyp1("D03c", "ensemble=3e4", "solvabilite_2")))))
verifier("(4.11) le message nomme le motif, le référentiel, le poste, la valeur et la forme attendue",
         !is.null(r) && all(vapply(c("D03c", "solvabilite_2", "sinistres_declares_non_regles", "ensemble=3e4",
                                     "<college>=<montant>"), grepl, NA, conditionMessage(r), fixed = TRUE)))
formes_admises <- list(
  c("D03h à -0,05 (borne)", "D03h", "-0.05"), c("D03h à 0,10 (borne)", "D03h", "0.10"), c("D03h 1e-2", "D03h", "1e-2"),
  c("D13 à 1", "D13", "1"), c("D03c ensemble=0", "D03c", "ensemble=0"), c("D03c, deux collèges", "D03c", "cadres=50000;ensemble=40000.5"),
  c("D03c, 308 « 9 » (fini)", "D03c", paste0("ensemble=", strrep("9", 308L))), c("D03b à une clé", "D03b", "assure=M"),
  c("D03b de v1-modeste-07", "D03b", "assure=M;autre=F;conjoint=oppose_assure;enfant=F"),
  c("D05, clés dans un autre ordre", "D05", "decompte=compte;motif=refus"), c("D03e", "D03e", "cat2"), c("D03f", "D03f", "regle"),
  c("signalement d'un motif alternatif (D13)", "D13", "signalement"))
for (f in formes_admises) {
  for (r in ns$REFERENTIELS) {
    verifier_egal(paste0("(4.11) contre-témoin, ", f[[1L]], ", déclaré pour ", r, " : admis par les trois fonctions"),
                  refus_hypothese(f[[2L]], f[[3L]], r),
                  c(valider_plan = "aucun", controler_base = "aucun", controler_base_07 = "aucun", vue_a_date = "aucun"))
  }
}
verifier("(4.11) .FORMES_HYPOTHESE : exactement les motifs de defauts.csv qui admettent H, sous-cas lettrés sans leurs parents",
         { dd <- dictionnaire()$defauts
           h <- dd$code[vapply(dd$traitements, function(x) "H" %in% strsplit(x, ";", fixed = TRUE)[[1L]], NA)]
           setequal(names(ns$.FORMES_HYPOTHESE), setdiff(h, dd$parent[nzchar(dd$parent)])) &&
             all(ns$.FORMES_HYPOTHESE %in% names(ns$.TEXTES_FORME_HYPOTHESE)) })
# la valeur est canonisée telle que déclarée (erratum v1.0.21, § 2.8) : ni réordonnée ni réécrite
verifier_egal("(4.11) canonisation : valeur d'une liste par clé et écriture d'un décimal gardées telles que déclarées",
              { p <- plan_min()
                p$donnees <- list(hypotheses = c(hyp1("D03b", "enfant=F;assure=M", "comptes_sociaux"),
                                                 hyp1("D03h", "1e-2", "comptes_sociaux")))
                unname(vapply(canoniser_plan(p)$donnees$hypotheses, `[[`, "", "valeur")) },
              c("enfant=F;assure=M", "1e-2"))

section("plan : poste d'une hypothèse (C192-1 à C192-5, #192 ; spécification de B2, erratum v1.0.24, § 2.3)")

# Le poste d'une ligne de `hypotheses` est `tous`, ou un poste du catalogue qui lit au moins une
# table du motif (defauts.csv, colonne `tables`, croisée avec lectures.csv) ; sinon plan_invalide
# par valider_plan(), donc calculer_provisions(), jamais par controler_base() ni vue_a_date().
# Avant (mesuré sur a3219d4) : valider_plan() accepte C192-1 et C192-2, et calculer_provisions()
# refuse C192-1 au calcul (declaration_manquante, affiliations, salaire_reference, AF1). Les
# contre-témoins (C192-3, C192-5) passent avant comme après.
source(file.path(racine, "tests", "references.R"), local = TRUE)
hyp192 <- function(motif, valeur, poste) {
  lapply(ns$REFERENTIELS, function(r) list(motif = motif, referentiel = r, poste = poste, valeur = valeur))
}
tb192 <- b2_tables()
plan192 <- function(h) {
  p <- b2_plan(tb192, D("2025-12-31"))
  p$donnees <- list(hypotheses = h, seuils = list(
    d02c_age_min = list(assures_sinistre = 16, assures_affiliation = 16, famille = 0),
    d02c_age_max = list(assures_sinistre = 75, assures_affiliation = 70, famille = 110)))
  p
}
# base de 4.9 (engagement) : capital non fixé, salaire de référence de AF1 manquant (D03c lue par P1)
b192 <- b2_base_capital(capital = NA)
b192$affiliations$salaire_reference <- NA_real_
msg192 <- function(motif, poste, tables, admis) {
  paste0("plan : donnees$hypotheses : ", motif, " (comptes_sociaux, ", poste,
         ") : poste inconnu du catalogue ou qui ne lit aucune table du motif (", tables, ") ; postes admis : ", admis)
}
admis_p1p2 <- "tous, sinistres_declares_non_regles, capitaux_non_reclames"
typo192 <- hyp192("D03c", "ensemble=30000", "sinistres_declares_non_regle")
d03c_p3 <- hyp192("D03c", "ensemble=30000", "provision_mathematique_temporaire_deces")
# échoue sur a3219d4 : valider_plan() accepte, calculer_provisions() refuse declaration_manquante
r <- refus_de(valider_plan(plan192(typo192)))
verifier_egal("C192-1 D03c déclarée pour un poste mal orthographié (sinistres_declares_non_regle) : plan_invalide par valider_plan(), message nommant motif, référentiel, poste et postes admis",
              if (is.null(r)) NULL else list(r$motif, r$attendu, conditionMessage(r)),
              list("plan_invalide", "donnees$hypotheses",
                   msg192("D03c", "sinistres_declares_non_regle", "affiliations", admis_p1p2)))
r <- refus_de(calculer_provisions(b192, plan192(typo192), par_identifiant(tb192)))
verifier_egal("C192-1 calculer_provisions() refuse le même plan plan_invalide avant tout calcul (avant : declaration_manquante, affiliations, salaire_reference, AF1)",
              if (is.null(r)) NULL else list(r$motif, conditionMessage(r)),
              list("plan_invalide", msg192("D03c", "sinistres_declares_non_regle", "affiliations", admis_p1p2)))
# échoue sur a3219d4 : valider_plan() accepte
r <- refus_de(valider_plan(plan192(d03c_p3)))
verifier_egal("C192-2 D03c déclarée pour P3 (qui ne lit pas affiliations) : plan_invalide par valider_plan()",
              if (is.null(r)) NULL else list(r$motif, conditionMessage(r)),
              list("plan_invalide", msg192("D03c", "provision_mathematique_temporaire_deces", "affiliations", admis_p1p2)))
# échoue sur a3219d4 : D05 pour P3 acceptée
r <- refus_de(valider_plan(plan192(hyp192("D05", "motif=sans_suite;decompte=compte", "provision_mathematique_temporaire_deces"))))
verifier_egal("C192-3 D05 déclarée pour P3 (qui ne lit pas evenements) : plan_invalide",
              if (is.null(r)) NULL else list(r$motif, conditionMessage(r)),
              list("plan_invalide", msg192("D05", "provision_mathematique_temporaire_deces", "evenements", admis_p1p2)))
# échoue sur a3219d4 : signalement d'un motif alternatif pour un poste inconnu accepté ; la règle
# vaut pour toute ligne de `hypotheses`, signalement compris
r <- refus_de(valider_plan(plan192(list(list(motif = "D13", referentiel = "comptes_sociaux", poste = "xx",
                                              valeur = "signalement")))))
verifier_egal("C192-3 signalement de D13 déclaré pour un poste inconnu (xx) : plan_invalide, les trois postes de B2 admis",
              if (is.null(r)) NULL else list(r$motif, conditionMessage(r)),
              list("plan_invalide", msg192("D13", "xx", "sinistres", paste0(admis_p1p2, ", provision_mathematique_temporaire_deces"))))
# contre-témoins (acceptés avant comme après) : tous ; D03c pour P2 (engagement.R, D03c lue par
# P2) ; D03h et D03f pour P1 (tables lues, colonnes non lues : R2, spécification de B2, § 6.2) ;
# D03f, D03a et D03d pour P3
for (cas in list(c("D03c", "ensemble=30000", "tous"), c("D03c", "ensemble=30000", "capitaux_non_reclames"),
                 c("D03h", "0", "sinistres_declares_non_regles"), c("D03f", "regle", "sinistres_declares_non_regles"),
                 c("D03f", "regle", "provision_mathematique_temporaire_deces"),
                 c("D03a", "regle", "provision_mathematique_temporaire_deces"),
                 c("D03d", "regle", "provision_mathematique_temporaire_deces"))) {
  verifier(paste0("C192-3 contre-témoin : ", cas[[1L]], " déclarée pour ", cas[[3L]], " : admise par valider_plan()"),
           is.null(refus_de(valider_plan(plan192(hyp192(cas[[1L]], cas[[2L]], cas[[3L]]))))))
}
verifier_egal("C192-3 contre-témoin : D03c pour tous, calculer_provisions() rend la PSAP de b192 (85 747,2, calcule)",
              { pr <- calculer_provisions(b192, plan192(hyp192("D03c", "ensemble=30000", "tous")), par_identifiant(tb192))$provisions
                pr <- pr[pr$segmentation == "ensemble" & pr$poste == "sinistres_declares_non_regles", ]
                list(pr$montant, pr$statut_calcul) },
              list(85747.199999999983, "calcule"))
# échoue sur a3219d4 : valider_plan() accepte ; controler_base() et vue_a_date() acceptent avant
# comme après (sans plan, le poste n'est lu par aucun calcul)
ctrl192 <- function(h) {
  m <- function(expr) tryCatch({ expr; "aucun" }, refus_provie = function(e) e$motif)
  d <- list(hypotheses = h)
  c(valider_plan = m(valider_plan(plan192(h))),
    controler_base = m(controler_base(b192, D("2025-12-31"), d, list(age = "revolu"))),
    vue_a_date = m(ns$vue_a_date(b192, D("2025-12-31"), d, list(age = "revolu"))))
}
for (cas in list(list("C192-1", typo192), list("C192-2", d03c_p3))) {
  verifier_egal(paste0("C192-4 ", cas[[1L]], " : plan_invalide par valider_plan() seul ; controler_base() et vue_a_date() l'acceptent"),
                ctrl192(cas[[2L]]),
                c(valider_plan = "plan_invalide", controler_base = "aucun", vue_a_date = "aucun"))
}
# contre-témoin (passe avant comme après) : le contrôle suit lire_declarations(), qui garde son
# premier refus (forme de la valeur, #99) pour une ligne mal formée déclarée pour un poste refusé
r <- refus_de(valider_plan(plan192(hyp192("D03c", "ensemble=3e4", "sinistres_declares_non_regle"))))
verifier("C192-5 forme et poste fautifs : le refus est celui de lire_declarations() (forme de la valeur), pas celui du poste",
         !is.null(r) && identical(r$motif, "plan_invalide") && identical(r$attendu, "donnees") &&
           all(vapply(c("D03c (comptes_sociaux, sinistres_declares_non_regle)", "ensemble=3e4", "forme attendue"),
                      grepl, NA, conditionMessage(r), fixed = TRUE)) &&
           !grepl("postes admis", conditionMessage(r), fixed = TRUE))
verifier_chemin("C192-5 seuil inconnu et poste fautif : le refus est celui du seuil inconnu (donnees$seuils$zz)",
                valider_plan({ p <- plan192(typo192); p$donnees$seuils$zz <- 1; p }), "plan_invalide", "donnees$seuils$zz")
# contre-témoin (passe avant comme après ; constat M1 de l'audit léger) : un seuil au-delà des
# entiers de R (.seuils_canoniques()) garde son refus devant un poste fautif
verifier_chemin("C192-5 seuil au-delà des entiers de R et poste fautif : le refus est celui du seuil (donnees$seuils$d02c_age_max$famille)",
                valider_plan({ p <- plan192(typo192); p$donnees$seuils$d02c_age_max$famille <- 1e10; p }),
                "plan_invalide", "donnees$seuils$d02c_age_max$famille")
# échoue sur a3219d4 (avis d'actuary) : D03d (table assures) déclarée pour P1, qui ne lit pas assures
r <- refus_de(valider_plan(plan192(hyp192("D03d", "regle", "sinistres_declares_non_regles"))))
verifier_egal("C192-3 D03d déclarée pour P1 (qui ne lit pas assures) : plan_invalide, seul P3 admis",
              if (is.null(r)) NULL else list(r$motif, conditionMessage(r)),
              list("plan_invalide", msg192("D03d", "sinistres_declares_non_regles", "assures",
                                           "tous, provision_mathematique_temporaire_deces")))
# échoue sur a3219d4 (.v_postes_hypotheses() absente ; constat M2 de l'audit léger) : catalogue
# fictif à deux garanties, poste `pt` d'une garantie fictive `arret` (hors du périmètre de tout
# plan de B2) qui lit affiliations : admis pour D03c (affiliations), refusé pour D05 (evenements)
cat192 <- catalogue_garanties()
cat192$postes <- rbind(cat192$postes, transform(cat192$postes[1L, ], code_garantie = "arret", poste = "pt"))
cat192$lectures <- rbind(cat192$lectures, data.frame(code_garantie = "arret", poste = "pt", table = "affiliations",
                                                     colonne = "salaire_reference", stringsAsFactors = FALSE))
hy192 <- function(motif, valeur) data.frame(motif = motif, referentiel = "comptes_sociaux", poste = "pt", valeur = valeur,
                                            stringsAsFactors = FALSE)
verifier_egal("C192-3 catalogue à deux garanties : D03c déclarée pour le poste pt d'une autre garantie, qui lit affiliations : admise",
              tryCatch({ ns$.v_postes_hypotheses(hy192("D03c", "ensemble=1"), dictionnaire(), cat192, "donnees$hypotheses"); "admise" },
                       refus_provie = function(e) e$motif, error = function(e) conditionMessage(e)),
              "admise")
r <- tryCatch({ ns$.v_postes_hypotheses(hy192("D05", "motif=refus;decompte=compte"), dictionnaire(), cat192, "donnees$hypotheses"); NULL },
              refus_provie = function(e) list(e$motif, conditionMessage(e)), error = function(e) conditionMessage(e))
verifier_egal("C192-3 catalogue à deux garanties : D05 déclarée pour le poste pt, qui ne lit pas evenements : plan_invalide",
              r,
              list("plan_invalide", msg192("D05", "pt", "evenements", admis_p1p2)))

section("plan : exports (critère 1.9)")

exports <- getNamespaceExports("provie")
verifier("exports du § 2.9 : valider_plan, canoniser_plan, ecrire_plan, lire_plan, ecrire_fiche, lire_fiche, catalogue_garanties",
         all(c("valider_plan", "canoniser_plan", "ecrire_plan", "lire_plan", "ecrire_fiche", "lire_fiche",
               "catalogue_garanties") %in% exports))
verifier("construire_fiche() et controler_rejeu() ne sont pas exportés ; rejouer_fiche() l'est, avec calculer_provisions() (issue 4, #67)",
         !any(c("construire_fiche", "controler_rejeu") %in% exports) && "rejouer_fiche" %in% exports)
verifier("méthodes print et format de plan_calcul et fiche_calcul enregistrées",
         all(vapply(list(c("format", "plan_calcul"), c("print", "plan_calcul"), c("format", "fiche_calcul"),
                         c("print", "fiche_calcul")),
                    function(m) !is.null(utils::getS3method(m[1L], m[2L], optional = TRUE)), NA)))
sortie <- utils::capture.output(res <- print(cp))
verifier("print(plan) : décomptes, rend le plan invisible", identical(res, cp) && identical(sortie, utils::capture.output(cat(format(cp), sep = "\n"))) &&
           identical(format(cp)[1L], "plan de calcul (version 1, arr\u00eat\u00e9 2025-12-31)"))
sortie <- utils::capture.output(res <- print(fiche))
verifier("print(fiche) : décomptes, rend la fiche invisible", identical(res, fiche) && identical(sortie, utils::capture.output(cat(format(fiche), sep = "\n"))) &&
           startsWith(format(fiche)[1L], "fiche de calcul (version 1) : R "))
verifier("format(plan relu non validé) : sans erreur", is.character(format(lire_plan(ns$ecrire_liste(list(graine = 1L))))))
