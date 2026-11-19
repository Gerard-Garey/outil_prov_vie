# Tests unitaires du module `calculer_provisions` (R/calculer_provisions.R) et de segments_vue()
# (module `donnees`) : point d'entrée, table ETAPES, objet resultat_provie et ses invariants (a)
# à (f) (ADR 0010, points 4 à 7), total arrêté (spécification de B2, § 6.1), refus d'appel et
# arrêt de poste distingués (point 11), declarations_requises vide (refus declaration_manquante),
# enjeu par poste, fiche et empreintes, rejeu (rejouer_fiche()) (#67 ; spécification de B2,
# § 7.7).
# Exécuté par tests/test_unitaires.R : le package est installé et chargé, le harnais est
# sourcé, `racine` est défini. Bases, plans et couples : tests/b2_bases.R et tests/references.R.

source(file.path(racine, "tests", "references.R"))
ns <- asNamespace("provie")
motif_de <- function(expr) {
  tryCatch({ expr; "aucun" }, refus_provie = function(e) e$motif,
           error = function(e) paste("autre :", conditionMessage(e)))
}
EPS <- 1e-10
egal_mixte <- function(x, r) is.numeric(x) && length(x) == length(r) && all(abs(x - r) <= EPS * pmax(1, abs(r)))
tb <- b2_tables()
tid <- par_identifiant(tb)
A1 <- D("2025-12-31")
base <- b2_base_construite_deces_02()
p_c1 <- b2_plan_reference("recommandees", A1, tb)
r_c1 <- calculer_provisions(base, p_c1, tid)
couple <- function(nom) {
  i <- match(nom, COUPLES_REFERENCE$couple)
  e <- entrees_couple(i)
  list(e = e, r = calculer_couple(e))
}
j3 <- couple("J3")
v1 <- couple("V1")
CLES <- c("garantie", "referentiel", "poste", "segmentation", "segment")

section("calculer_provisions : signature, exports, table ETAPES (ADR 0010, points 4 et 5)")
verifier_egal("signature à quatre arguments : calculer_provisions(donnees, plan, tables = list(), provenance = NULL)",
              formals(calculer_provisions), as.pairlist(alist(donnees = , plan = , tables = list(), provenance = NULL)))
verifier_egal("rejouer_fiche(donnees, fiche, tables = list())",
              formals(rejouer_fiche), as.pairlist(alist(donnees = , fiche = , tables = list())))
verifier("calculer_provisions et rejouer_fiche exportées ; representation_resultat interne",
         all(c("calculer_provisions", "rejouer_fiche") %in% getNamespaceExports("provie")) &&
           !("representation_resultat" %in% getNamespaceExports("provie")))
verifier_egal("ETAPES : quatre colonnes (etape, module, fonction, condition), étapes du § 7.7 dans l'ordre",
              list(names(ns$ETAPES), ns$ETAPES$etape),
              list(c("etape", "module", "fonction", "condition"),
                   c("plan", "tables", "vue", "declarations", "arrets", "engagement", "risque_en_cours", "segments", "agregats",
                     "enjeu", "fiche", "empreinte_resultat", "empreinte_code")))
corps <- paste(deparse(body(calculer_provisions)), collapse = "\n")
positions <- vapply(ns$ETAPES$fonction, function(f) regexpr(paste0(f, "("), corps, fixed = TRUE)[[1L]], 0L)
verifier("calculer_provisions() appelle chaque fonction de ETAPES, dans l'ordre de la table (séquence explicite)",
         all(positions > 0L) && !is.unsorted(positions, strictly = TRUE))
verifier("chaque fonction de ETAPES est définie dans le module qu'elle nomme",
         all(vapply(seq_len(nrow(ns$ETAPES)), function(i) {
           f <- ns$ETAPES$fonction[i]
           fichier <- file.path(racine, "R", paste0(ns$ETAPES$module[i], ".R"))
           any(grepl(paste0("^", gsub(".", "\\.", f, fixed = TRUE), " <- function"), readLines(fichier, warn = FALSE)))
         }, NA)))

section("objet resultat_provie : champs, classe, invariants (ADR 0010, points 6 et 7)")
verifier_egal("classe resultat_provie, huit champs dans l'ordre du point 6 ; triangles et passage NULL en B2",
              list(class(r_c1), names(r_c1), is.null(r_c1$triangles), is.null(r_c1$passage), class(r_c1$fiche)),
              list("resultat_provie", c("provisions", "dossiers", "echeanciers", "triangles", "passage", "indicateurs", "donnees",
                                        "fiche"), TRUE, TRUE, "fiche_calcul"))
verifier_egal("colonnes de provisions, dossiers, échéanciers et indicateurs (formes du point 6, annoté)",
              list(names(r_c1$provisions), names(r_c1$dossiers), names(r_c1$echeanciers), names(r_c1$indicateurs)),
              list(ns$COLONNES_CELLULES, ns$COLONNES_DOSSIERS, ns$COLONNES_ECHEANCIERS, ns$COLONNES_INDICATEURS))
invariants <- function(r) {
  p <- r$provisions
  d <- r$dossiers
  ag <- p[p$niveau == "agregat", ]
  a <- all(vapply(seq_len(nrow(ag)), function(i) {
    if (ag$statut_calcul[i] == "arrete") return(TRUE)
    c1 <- p[p$niveau == "calcul" & p$garantie == ag$garantie[i] & p$referentiel == ag$referentiel[i] &
              p$segmentation == ag$segmentation[i] & p$segment == ag$segment[i], ]
    egal_mixte(ag$montant[i], sum(c1$montant))
  }, NA)) && all(vapply(which(p$famille %in% "engagement" & p$segmentation == "ensemble" & p$statut_calcul == "calcule"), function(i) {
    egal_mixte(sum(d$montant[d$garantie == p$garantie[i] & d$referentiel == p$referentiel[i] & d$poste == p$poste[i]]), p$montant[i])
  }, NA))
  b <- all(is.na(p$montant[p$statut_calcul == "arrete"])) && all(nzchar(p$motif_arret[p$statut_calcul == "arrete"])) &&
    !anyNA(p$motif_arret[p$statut_calcul == "arrete"]) && all(is.na(p$motif_arret[p$statut_calcul == "calcule"]))
  pr <- r$fiche$parametres_retenus$postes
  cle_pr <- paste(pr$garantie, pr$referentiel, pr$poste)
  c_ <- all(paste(p$garantie, p$referentiel, p$poste) %in% cle_pr) && all(paste(d$garantie, d$referentiel, d$poste) %in% cle_pr)
  d_ <- !is.unsorted(do.call(order, c(unname(as.list(p[CLES])), list(method = "radix")))) &&
    !is.unsorted(do.call(order, c(unname(as.list(d[c("garantie", "referentiel", "poste", "id_dossier")])), list(method = "radix"))))
  feuilles <- function(x) if (is.list(x)) unlist(lapply(x, feuilles), recursive = FALSE) else list(x)
  e <- !any(vapply(c(feuilles(unclass(r)[setdiff(names(r), "fiche")]), feuilles(unclass(r$fiche))),
                   function(x) inherits(x, "POSIXt"), NA))
  totaux <- p[p$poste == "total", ]
  f <- all(totaux$niveau == "agregat") && nrow(unique(p[c("garantie", "referentiel")])) ==
    nrow(totaux[totaux$segmentation == "ensemble", ])
  c(a = a, b = b, c = c_, d = d_, e = e, f = f)
}
for (x in list(list("C1", r_c1), list("J3", j3$r), list("V1", v1$r))) {
  inv <- invariants(x[[2L]])
  verifier(paste0(x[[1L]], " : invariants (a) à (f) de l'ADR 0010, point 7 (", paste(names(inv)[!inv], collapse = ", "), ")"), all(inv))
}
verifier("V1 : total deces = P1 + P2 + P3 (mesures m24 : 541 440,13 + 552 375,52 + 559 589,67), calculé, statut approximation_numerique",
         local({
           p <- v1$r$provisions
           t <- p[p$poste == "total" & p$segmentation == "ensemble", ]
           t$statut_calcul == "calcule" && abs(t$montant - (541440.13 + 552375.52 + 559589.67)) < 0.02 &&
             t$statut_resultat == "approximation_numerique"
         }))

section("total arrêté et arrêt de poste (spécification de B2, § 6.1 et § 6.2 ; ADR 0010, point 11)")
p3 <- j3$r$provisions
# #72 (spécification `donnees` v1.9, § 9.2 ; erratum du projet de dictionnaire 1.6, § 2 et
# § 11.5) : le refus D09 de PR00010 (indemnité journalière du dossier DO0014, garantie
# incapacite) a la portée ligne ; aucune unité de P1 ni de P2 ne lit la ligne : P1, P2 et le
# total sont calculés, à 0 exact (avant #72 : arrêtés D09, total poste_arrete:...)
verifier_egal("J3 (v1-modeste-05) : P1, P2 et P3 calculés (0), total calculé (0) ; la ligne refusée PR00010 n'est lue par aucune unité (#72)",
              lapply(c("sinistres_declares_non_regles", "capitaux_non_reclames", "provision_mathematique_temporaire_deces", "total"),
                     function(po) as.list(p3[p3$poste == po, c("montant", "nombre_dossiers", "statut_calcul", "motif_arret")])),
              rep(list(list(montant = 0, nombre_dossiers = 0L, statut_calcul = "calcule", motif_arret = NA_character_)), 4L))
verifier_egal("J3 : la ligne de refus_tables (prestations.montant, D09) est de portée ligne et n'arrête aucun poste : postes_arretes NA (#72 ; avant : P1 et P2)",
              as.list(j3$r$donnees$refus_tables[, c("table", "colonne", "motif", "portee", "identifiants", "postes_arretes")]),
              list(table = "prestations", colonne = "montant", motif = "D09", portee = "ligne", identifiants = "PR00010",
                   postes_arretes = NA_character_))
# Arrêt né d'une famille : P1 sur un capital à reconstituer sans affiliation (affiliation_non_determinee).
# Sans affiliation, la survenance n'est couverte par aucun contrat : D11 (S + X, spécification
# `donnees` v1.6, § 8.7) demande l'exclusion par famille, déclarée `conserver` (la ligne reste lue).
sans_af <- b2_base_capital(capital = NA)
sans_af$affiliations <- sans_af$affiliations[0, ]
p_af <- p_c1
p_af$donnees$exclusions <- lapply(ns$FAMILLES_CALCUL, function(f) list(motif = "D11a", famille = f, action = "conserver"))
r_af <- calculer_provisions(sans_af, p_af, tid)
pa <- r_af$provisions
pr_af <- r_af$fiche$parametres_retenus$postes
verifier_egal("arrêt né d'une famille : cellule P1 arrêtée (affiliation_non_determinee), total arrêté, aucune cellule de segment ; premier dossier en cause (DO1) dans fiche$parametres_retenus$postes$parametres",
              list(pa$motif_arret[pa$poste == "sinistres_declares_non_regles"], pa$motif_arret[pa$poste == "total"],
                   unique(pa$segmentation), ns$lire_liste(charToRaw(pr_af$parametres[pr_af$poste == "sinistres_declares_non_regles"]))$identifiant_arret,
                   ns$lire_liste(charToRaw(pr_af$parametres[pr_af$poste == "capitaux_non_reclames"]))$identifiant_arret),
              list("affiliation_non_determinee", "poste_arrete:sinistres_declares_non_regles", "ensemble", "DO1", NULL))
b_ar <- base
b_ar$garanties_souscrites$taux_technique_tarif[2L] <- -1   # hors domaine : refus de valeur sur une colonne lue par P3 seul
r_ar <- calculer_provisions(b_ar, p_c1, tid)
pr <- r_ar$provisions
verifier_egal("refus de valeur sur une colonne lue par P3 seul : P3 arrêté (ensemble et segments de P1 et P2), totaux arrêtés, P1 et P2 calculés",
              list(pr$statut_calcul[pr$poste == "provision_mathematique_temporaire_deces"],
                   pr$segment[pr$poste == "provision_mathematique_temporaire_deces"],
                   unique(pr$statut_calcul[pr$poste == "total"]), unique(pr$motif_arret[pr$poste == "total"]),
                   unique(pr$statut_calcul[pr$poste %in% c("sinistres_declares_non_regles", "capitaux_non_reclames")])),
              list(rep("arrete", 2L), c("ensemble", "collectif_obligatoire"), "arrete",
                   "poste_arrete:provision_mathematique_temporaire_deces", "calcule"))

section("refus d'appel (ADR 0010, point 11 (a)) : aucun objet rendu")
verifier_egal("plan invalide, table absente, empreinte discordante, données qui ne sont pas une liste de data.frame, arrêté postérieur à l'extraction",
              list(motif_de(calculer_provisions(base, within(p_c1, graine <- 1.5), tid)),
                   motif_de(calculer_provisions(base, p_c1, tid["tme_fictive_b2"])),
                   motif_de(calculer_provisions(base, within(p_c1, tables$serie_tme$empreinte <- strrep("0", 32L)), tid)),
                   motif_de(calculer_provisions(list(1), p_c1, tid)),
                   motif_de(calculer_provisions(base, within(p_c1, arrete <- D("2026-06-30")), tid))),
              list("plan_invalide", "table_absente", "empreinte_discordante", "liste_invalide", "arrete_posterieur_extraction"))
verifier_egal("declaration_manquante : plan sans les seuils D02c que le bilan demande (six declarations_requises, m8)",
              motif_de(calculer_provisions(base, within(p_c1, donnees <- list()), tid)), "declaration_manquante")
verifier_egal("segmentation de règle retirée de B2 (adherent, erratum v1.0.12) : plan_invalide dès valider_plan() (étape plan), le même refus que calculer_provisions() ; ligne_activite, contrat et annee_survenance restituées",
              list(motif_de(valider_plan(within(p_c1, perimetre$segmentations <- list(a = list(regle = "adherent"))))),
                   motif_de(calculer_provisions(base, within(p_c1, perimetre$segmentations <- list(a = list(regle = "adherent"))), tid)),
                   tryCatch(calculer_provisions(base, within(p_c1, perimetre$segmentations <- list(a = list(regle = "adherent"))), tid),
                            refus_provie = function(e) e$module),
                   motif_de(calculer_provisions(base, within(p_c1, perimetre$segmentations <- list(
                     l = list(regle = "ligne_activite", correspondance = list(deces = "ldec")), c = list(regle = "contrat"),
                     s = list(regle = "annee_survenance"))), tid))),
              list("plan_invalide", "plan_invalide", "plan", "aucun"))
verifier("declarations_requises vide et aucune action non_declaree dans le bilan du résultat (C1, J3, V1)",
         all(vapply(list(r_c1, j3$r, v1$r), function(r) {
           nrow(r$donnees$declarations_requises) == 0L && !any(r$donnees$enjeu$action %in% "non_declaree")
         }, NA)))

section("segments (segments_vue(), module donnees) et cellules par segment")
s <- r_c1$donnees$segments
verifier_egal("C1 : segments nature_contrat : cinq dossiers (CTC1) et trois contrats",
              list(names(s), s$id_contrat, s$id_dossier, s$segment),
              list(c("id_dossier", "id_sinistre", "id_contrat", "segmentation", "segment"),
                   c("CTC1", rep("CTC1", 5L), "CTI1", "CTI3"), c(NA, "DOR1", "DOR3", "DOR4", "DOR5A", "DOR5B", NA, NA),
                   c(rep("collectif_obligatoire", 6L), "individuel", "individuel")))
r_seg <- calculer_provisions(base, within(p_c1, perimetre$segmentations <- list(
  ct = list(regle = "contrat"), la = list(regle = "ligne_activite", correspondance = list(deces = "ldec")))), tid)
q <- r_seg$provisions
verifier("segmentations contrat et ligne_activite : total par contrat = somme des postes du contrat ; ligne d'activité unique = total ensemble",
         egal_mixte(q$montant[q$poste == "total" & q$segmentation == "ct" & q$segment == "CTI1"], 3046.4321195552) &&
           egal_mixte(q$montant[q$poste == "total" & q$segmentation == "la"], q$montant[q$poste == "total" & q$segmentation == "ensemble"]) &&
           egal_mixte(sum(q$montant[q$poste == "total" & q$segmentation == "ct"]),
                      q$montant[q$poste == "total" & q$segmentation == "ensemble"]))
# annee_survenance (§ 2.2 et § 5.5, erratum v1.0.12) : P1 et P2, année de survenance du sinistre
# du dossier ; P3, segment hors_survenance.
r_an <- calculer_provisions(base, within(p_c1, perimetre$segmentations <- list(an = list(regle = "annee_survenance"))), tid)
q_an <- r_an$provisions[r_an$provisions$segmentation == "an", ]
q_en <- r_an$provisions[r_an$provisions$segmentation == "ensemble", ]
verifier_egal("annee_survenance (C1) : P1 et P2 au segment 2024 (survenances 2024-07-01), P3 au segment hors_survenance ; montants, dossiers et statuts des cellules ensemble ; totaux 2024 = P1 + P2, hors_survenance = P3",
              list(paste(q_an$poste, q_an$segment), q_an$montant[q_an$poste != "total"], q_an$nombre_dossiers,
                   q_an$statut_resultat, q_an$montant[q_an$poste == "total"]),
              list(c("capitaux_non_reclames 2024", "provision_mathematique_temporaire_deces hors_survenance",
                     "sinistres_declares_non_regles 2024", "total 2024", "total hors_survenance"),
                   q_en$montant[match(c("capitaux_non_reclames", "provision_mathematique_temporaire_deces",
                                        "sinistres_declares_non_regles"), q_en$poste)],
                   c(1L, 0L, 4L, 5L, 0L), c("exact", "approximation_numerique", "jugement_expert", "jugement_expert",
                                            "approximation_numerique"),
                   c(sum(sort(q_en$montant[q_en$poste %in% c("capitaux_non_reclames", "sinistres_declares_non_regles")])),
                     q_en$montant[q_en$poste == "provision_mathematique_temporaire_deces"])))
b_an <- base
b_an$sinistres$date_survenance[b_an$sinistres$id_sinistre == "SIR1"] <- D("2023-12-31")
s_an <- ns$segments_vue(b2_vue(b_an, A1, p_c1$donnees, p_c1$conventions), list(an = list(regle = "annee_survenance")), "deces")
verifier_egal("segments_vue(), annee_survenance : année civile de sinistres.date_survenance (SIR1 au 2023-12-31 : 2023), hors_survenance pour chaque contrat",
              list(s_an$id_dossier, s_an$segment),
              list(c(NA, "DOR1", "DOR3", "DOR4", "DOR5A", "DOR5B", NA, NA),
                   c("hors_survenance", "2023", "2024", "2024", "2024", "2024", "hors_survenance", "hors_survenance")))
verifier("segments_vue() : une règle hors de REGLES_SEGMENTATION_B2 (plan non validé) est une erreur interne, non un refus",
         grepl("^autre : erreur interne de provie", motif_de(ns$segments_vue(b2_vue(base, A1, p_c1$donnees, p_c1$conventions),
                                                                             list(a = list(regle = "adherent")), "deces"))))
verifier("jeux sans segmentation : segments vides, cellules ensemble seules",
         nrow(v1$r$donnees$segments) == 0L && all(v1$r$provisions$segmentation == "ensemble"))

section("enjeu par poste (spécification donnees, § 4.5, point 3)")
en <- j3$r$donnees$enjeu
copies <- en[en$poste != "ensemble", ]
verifier_egal("J3 : copies par poste de l'enjeu : D01b de cotisations, famille risque_en_cours, garantie deces -> P3 (lit cotisations)",
              local({ u <- unique(copies[c("table", "motif", "famille", "garantie", "poste")]); rownames(u) <- NULL; u }),
              data.frame(table = "cotisations", motif = "D01b", famille = "risque_en_cours", garantie = "deces",
                         poste = "provision_mathematique_temporaire_deces", stringsAsFactors = FALSE))
verifier("J3 : enjeu du bilan de la vue retrouvé en retirant les copies par poste (rangées, ordre, valeurs)",
         local({
           vue <- ns$vue_a_date(j3$e$base, j3$e$plan$arrete, j3$e$plan$donnees, j3$e$plan$conventions)
           x <- en[en$poste == "ensemble", ]
           rownames(x) <- NULL
           identical(x, vue$bilan$enjeu)
         }))

# Rangée de refus (§ 6.4, point 7) : copiée vers les postes de postes_arretes de la même garantie,
# jointure par (table, colonne, motif) ; motif_fin est une colonne de la partie de ligne de fin
# des affiliations (§ 4.3) : un poste qui lit cette partie la lit (condition (1)), bien que
# lectures.csv ne nomme pas affiliations.motif_fin. Portée ligne (#72 ; erratum du projet de
# dictionnaire 1.6, § 11.5) : seuls les postes dont une unité lit la ligne refusée sont arrêtés.
# AFR5A est l'affiliation lue pour le capital reconstitué du dossier DOR5A, de P1 : P1 arrêté
# (hors_domaine, DOR5A), postes_arretes = P1, rangées deces de la table copiées vers P1 seul ;
# témoin AFR1 (dossier DOR1, de capital fixé : affiliation non lue) : aucun arrêt, postes_arretes
# NA, aucune copie (avant #72 : P1 et P2 arrêtés dans les deux cas, copies vers P1 puis P2)
mf <- function(id) {
  b <- base
  b$affiliations$motif_fin[b$affiliations$id_affiliation == id] <- "zzz"   # hors domaine : refus de portée ligne
  calculer_provisions(b, p_c1, tid)
}
r_mf <- mf("AFR5A")
en_mf <- r_mf$donnees$enjeu
co_mf <- en_mf[en_mf$poste != "ensemble", ]
pr_mf <- r_mf$provisions[r_mf$provisions$segmentation == "ensemble" & r_mf$provisions$poste != "total", ]
r_mf1 <- mf("AFR1")
verifier_egal("refus de portée ligne sur affiliations.motif_fin de AFR5A (capital reconstitué de DOR5A, P1) : P1 arrêté (hors_domaine, DOR5A), P2 et P3 calculés ; postes_arretes = P1 ; chaque rangée deces de la table copiée vers P1 seul ; témoin AFR1 (capital fixé) : aucun arrêt, postes_arretes NA, aucune copie",
              list(r_mf$donnees$refus_tables$portee, r_mf$donnees$refus_tables$postes_arretes,
                   any(catalogue_garanties()$lectures$table == "affiliations" & catalogue_garanties()$lectures$colonne %in% "motif_fin"),
                   pr_mf$motif_arret, pr_mf$statut_calcul,
                   local({ pr <- r_mf$fiche$parametres_retenus$postes
                           ns$lire_liste(charToRaw(pr$parametres[pr$poste == "sinistres_declares_non_regles"]))$identifiant_arret }),
                   local({ u <- unique(co_mf[c("table", "colonne", "motif", "garantie")]); rownames(u) <- NULL; u }),
                   unique(co_mf$poste),
                   nrow(co_mf) == sum(en_mf$poste == "ensemble" & en_mf$garantie == "deces" & en_mf$table %in% "affiliations"),
                   r_mf1$donnees$refus_tables$postes_arretes, unique(r_mf1$provisions$statut_calcul),
                   sum(r_mf1$donnees$enjeu$poste != "ensemble" & r_mf1$donnees$enjeu$table %in% "affiliations")),
              list("ligne", "deces/sinistres_declares_non_regles", FALSE,
                   c(NA, NA, "hors_domaine"), c("calcule", "calcule", "arrete"), "DOR5A",
                   data.frame(table = "affiliations", colonne = "motif_fin", motif = "hors_domaine", garantie = "deces",
                              stringsAsFactors = FALSE),
                   "sinistres_declares_non_regles", TRUE, NA_character_, "calcule", 0L))
verifier("J3 : la rangée de refus D09 (prestations.montant d'une indemnité journalière, garantie hors du plan) n'est copiée vers aucun poste du décès (depuis #72, postes_arretes NA)",
         !any(copies$motif == "D09") && any(en$motif == "D09" & en$action == "refus"))

section("fiche de calcul, empreintes, graine (ADR 0010, points 10, 21 et 22)")
f <- r_c1$fiche
verifier_egal("fiche : plan canonique, représentation, graine et générateur consignés, empreintes des tables reçues",
              list(f$plan, f$empreintes$representation, f$graine, f$empreintes$tables),
              list(canoniser_plan(p_c1), "provie-resultat-1", list(valeur = 1L, generateur = c("Mersenne-Twister", "Inversion", "Rejection")),
                   list(mortalite_fictive_b2 = tb$mortalite_tarif$origine$empreinte, tme_fictive_b2 = tb$serie_tme$origine$empreinte)))
verifier("empreinte du résultat = MD5 de ecrire_liste(representation_resultat()) (octets de resultat.txt) ; empreinte du code : 32 hexadécimaux",
         identical(f$empreintes$resultat, ns$empreinte(ecrire_liste_resultat(r_c1))) && grepl("^[0-9a-f]{32}$", f$empreintes$code))
verifier_egal("fiche$parametres_retenus$postes : trois postes et le total ; usages des tables ; texte des paramètres relu par lire_liste()",
              list(f$parametres_retenus$postes$poste, f$parametres_retenus$postes$usages_tables,
                   ns$lire_liste(charToRaw(f$parametres_retenus$postes$parametres[4L]))),
              list(c("sinistres_declares_non_regles", "capitaux_non_reclames", "provision_mathematique_temporaire_deces", "total"),
                   c("tme_fictive_b2", "tme_fictive_b2", "mortalite_fictive_b2;tme_fictive_b2", ""),
                   list(postes = c("sinistres_declares_non_regles", "capitaux_non_reclames", "provision_mathematique_temporaire_deces"))))
verifier("fiche relue : ecrire_fiche() / lire_fiche() aller-retour octet pour octet",
         identical(ecrire_fiche(lire_fiche(ecrire_fiche(f))), ecrire_fiche(f)))
prov <- list(base = list(contrats.csv = strrep("a", 32L)))
verifier_egal("provenance reprise dans fiche$empreintes$fichiers, et sans effet sur les provisions",
              list(calculer_provisions(base, p_c1, tid, prov)$fiche$empreintes$fichiers,
                   identical(calculer_provisions(base, p_c1, tid, prov)$provisions, r_c1$provisions)),
              list(prov, TRUE))
verifier("deux appels identiques (identical, empreintes comprises) ; état du générateur de l'appelant inchangé",
         local({
           set.seed(11L)
           etat <- .Random.seed
           r2 <- calculer_provisions(base, p_c1, tid)
           identical(r2, r_c1) && identical(.Random.seed, etat)
         }))

# Empreinte du code indépendante de la locale (§ 6.4, point 8) : deux processus R distincts,
# LC_ALL=C et LC_ALL=C.UTF-8, sur le package installé par la batterie.
empreinte_sous <- function(locale) {
  expr <- paste0(".libPaths(c(", deparse(dirname(find.package("provie"))), ", .libPaths())); ",
                 "cat(Sys.getlocale('LC_CTYPE'), provie:::empreinte_code(), sep = '|')")
  sortie <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", "-e", shQuote(expr)),
                                     stdout = TRUE, stderr = FALSE, env = paste0("LC_ALL=", locale)))
  strsplit(utils::tail(sortie, 1L), "|", fixed = TRUE)[[1L]]
}
e_c <- empreinte_sous("C")
e_u <- empreinte_sous("C.UTF-8")
verifier("empreinte du code : identique sous LC_ALL=C et LC_ALL=C.UTF-8 (deux processus R), et égale à celle de la fiche ; la seconde locale est bien UTF-8",
         length(e_c) == 2L && length(e_u) == 2L && e_c[1L] == "C" && grepl("utf-?8", e_u[1L], ignore.case = TRUE) &&
           identical(e_c[2L], e_u[2L]) && identical(e_c[2L], f$empreintes$code))

section("restitution des échéanciers (plan$restitution$echeanciers)")
verifier_egal("tous : 16 lignes (8 P1, 2 P2, 6 P3) ; aucun : NULL ; identifiants : lignes de ces clés seules",
              list(nrow(r_c1$echeanciers), table(r_c1$echeanciers$poste)[["sinistres_declares_non_regles"]],
                   is.null(calculer_provisions(base, within(p_c1, restitution$echeanciers <- "aucun"), tid)$echeanciers),
                   unique(calculer_provisions(base, within(p_c1, restitution$echeanciers <- c("CTI1", "DOR4")), tid)$echeanciers$cle)),
              list(16L, 8L, TRUE, c("DOR4", "CTI1")))

section("rejeu d'une fiche (rejouer_fiche(), ADR 0007, point 6)")
rj <- rejouer_fiche(base, r_c1$fiche, tid)
verifier_egal("rejeu de la fiche du calcul : même objet, aucun signalement de version",
              list(identical(rj$resultat, r_c1), nrow(rj$signalements)), list(TRUE, 0L))
verifier("rejeu de la fiche écrite puis relue (lire_fiche(ecrire_fiche())) : même objet",
         identical(rejouer_fiche(base, lire_fiche(ecrire_fiche(r_c1$fiche)), tid)$resultat, r_c1))
r_prov <- calculer_provisions(base, p_c1, tid, prov)
rj_prov <- rejouer_fiche(base, lire_fiche(ecrire_fiche(r_prov$fiche)), tid)$resultat
verifier("rejeu d'une fiche à provenance non NULL, écrite puis relue : même objet (provenance reprise de fiche$empreintes$fichiers)",
         identical(rj_prov, r_prov) && identical(rj_prov$fiche$empreintes$fichiers, prov))
f_v <- r_c1$fiche
f_v$versions$fiche <- 2L
f_p <- r_c1$fiche
f_p$versions$provie <- "0.0.1"
b_m <- base
b_m$prestations$montant <- 40001
verifier_egal("rejeu : version de fiche différente (version_discordante) ; base modifiée (empreinte_discordante) ; table non reçue (table_absente) ; version de provie différente signalée sans refus",
              list(motif_de(rejouer_fiche(base, f_v, tid)), motif_de(rejouer_fiche(b_m, r_c1$fiche, tid)),
                   motif_de(rejouer_fiche(base, r_c1$fiche, tid["tme_fictive_b2"])),
                   rejouer_fiche(base, f_p, tid)$signalements$grandeur),
              list("version_discordante", "empreinte_discordante", "table_absente", "provie"))

section("méthodes print et format (décomptes seuls)")
verifier("format.resultat_provie() : quatre lignes de décomptes ; print() rend l'objet, invisible",
         length(format(r_c1)) == 4L && local({ sortie <- utils::capture.output(v <- withVisible(print(r_c1)))
                                               identical(v$visible, FALSE) && identical(v$value, r_c1) &&
                                                 length(sortie) == 4L }) &&
           grepl("10 cellule\\(s\\), dont 0", format(r_c1)[2L]))

# --- Base construite construite-deces-02 : critères R.5 et R.7 (spécification de B2, § 7.8.4 et
# § 7.8.6), et unités de P3 (élément `contrats` de calculer_risque_en_cours()). Valeurs en dur du
# § 7.8.4, comparées élément par élément à la tolérance mixte (ADR 0011, r3).
P1 <- "sinistres_declares_non_regles"
P2 <- "capitaux_non_reclames"
P3 <- "provision_mathematique_temporaire_deces"
A0 <- D("2025-01-01")
COUPLES_C <- list(C1 = list(plan = "recommandees", arrete = A1), C2 = list(plan = "recommandees", arrete = A0),
                  C3 = list(plan = "alternatives", arrete = A1), C4 = list(plan = "alternatives", arrete = A0))
plan_c <- function(k) b2_plan_reference(COUPLES_C[[k]]$plan, COUPLES_C[[k]]$arrete, tb)

section("unités de P3 : élément contrats de calculer_risque_en_cours() (restitution par segment)")
for (k in names(COUPLES_C)) {
  p <- plan_c(k)
  v <- b2_vue(base, p$arrete, p$donnees, p$conventions)
  ct <- ns$calculer_risque_en_cours(v, p, tb, catalogue_garanties(), "deces", P3)$contrats
  ind <- ns$provisions_individuelles(v, p, tb, FALSE)$contrats
  col <- ns$provisions_collectives(v, p)
  verifier_egal(paste0(k, " : contrats (id_contrat, champ, statut) ; montants = provisions_individuelles() (après plancher) et provisions_collectives()"),
                list(ct$id_contrat, ct$champ, ct$statut_resultat, ct$montant),
                list(c("CTC1", "CTI1", "CTI3"), c("collectif", "individuel", "individuel"),
                     c("approximation_numerique", "exact", "exact"), c(col$montant, ind$montant)))
}

section("calculer_provisions() sur la base construite (R.5, § 7.8.4)")
ATTENDU_784 <- list(
  c(P1, "ensemble", "ensemble", 337225.9591013698, 369590.8752679452, 337891.1719521999, 370319.9312410764),
  c(P1, "nature_contrat", "collectif_obligatoire", 337225.9591013698, 369590.8752679452, 337891.1719521999, 370319.9312410764),
  c(P2, "ensemble", "ensemble", 103936.0000000000, 101506.6739726027, 127666.8365965362, 127667.0328043410),
  c(P2, "nature_contrat", "collectif_obligatoire", 103936.0000000000, 101506.6739726027, 127666.8365965362, 127667.0328043410),
  c(P3, "ensemble", "ensemble", 4275.9860504871, 8038.5636343610, 4373.4310207322, 8132.1975478346),
  c(P3, "nature_contrat", "individuel", 3710.6709819939, 7476.3718535391, 3808.1159522391, 7570.0057670127),
  c(P3, "nature_contrat", "collectif_obligatoire", 565.3150684932, 562.1917808219, 565.3150684932, 562.1917808219),
  c("total", "ensemble", "ensemble", 445437.9451518568, 479136.1128749090, 469931.4395694683, 506119.1615932522),
  c("total", "nature_contrat", "individuel", 3710.6709819939, 7476.3718535391, 3808.1159522391, 7570.0057670127),
  c("total", "nature_contrat", "collectif_obligatoire", 441727.2741698629, 471659.7410213699, 466123.3236172292,
    498549.1558262394))
resultats_c <- lapply(names(COUPLES_C), function(k) calculer_provisions(base, plan_c(k), tid))
names(resultats_c) <- names(COUPLES_C)
for (j in seq_along(COUPLES_C)) {
  k <- names(COUPLES_C)[j]
  pr <- resultats_c[[k]]$provisions
  cle <- paste(pr$poste, pr$segmentation, pr$segment)
  att <- vapply(ATTENDU_784, function(a) as.numeric(a[3L + j]), 0)
  cles_att <- vapply(ATTENDU_784, function(a) paste(a[1:3], collapse = " "), "")
  verifier(paste0("(R.5) ", k, " : dix cellules du § 7.8.4, et aucune autre, à 1e-10 (mixte)"),
           setequal(cle, cles_att) && length(cle) == 10L && egal_mixte(pr$montant[match(cles_att, cle)], att))
  alt <- k %in% c("C3", "C4")
  sm <- if (alt) "alternative" else "recommandee"
  # « Détail des cellules » du § 7.8.4 (erratum v1.0.12) : une ligne par cellule de ATTENDU_784,
  # (nombre_dossiers, statut_methode, statut_resultat)
  detail <- list(list(4L, sm, "jugement_expert"), list(4L, sm, "jugement_expert"),
                 list(1L, sm, if (alt) "jugement_expert" else "exact"), list(1L, sm, if (alt) "jugement_expert" else "exact"),
                 list(0L, sm, "approximation_numerique"), list(0L, sm, "exact"), list(0L, "recommandee", "approximation_numerique"),
                 list(5L, NA_character_, "jugement_expert"), list(0L, NA_character_, "exact"),
                 list(5L, NA_character_, "jugement_expert"))
  verifier_egal(paste0("(R.5) ", k, " : nombre de dossiers, statut de méthode et statut de résultat des dix cellules, segments et totaux compris (§ 7.8.4, détail des cellules)"),
                lapply(match(cles_att, cle), function(i) list(pr$nombre_dossiers[i], pr$statut_methode[i], pr$statut_resultat[i])),
                detail)
  x <- pr[pr$poste == P3 & pr$segment == "individuel", ]
  verifier_egal(paste0("(R.5) ", k, " : P3 segment individuel : méthode du seul champ individuel, statut exact"),
                list(x$methode, x$statut_resultat),
                list(paste0("individuel:", if (alt) "prospective_prime_declaree" else "prospective_prime_pure"), "exact"))
  # invariant (a) de l'ADR 0010, point 7 : cellule agregat = somme des cellules calcul de même segmentation et segment
  ag <- pr[pr$niveau == "agregat", ]
  verifier(paste0("(R.5) ", k, " : invariant (a) : chaque total = somme des cellules calcul de son segment ; dossiers = cellules ",
                  "ensemble de P1 et de P2"),
           all(vapply(seq_len(nrow(ag)), function(i) {
             c1 <- pr[pr$niveau == "calcul" & pr$segmentation == ag$segmentation[i] & pr$segment == ag$segment[i], ]
             egal_mixte(ag$montant[i], sum(c1$montant))
           }, NA)) &&
             all(vapply(c(P1, P2), function(po) {
               egal_mixte(sum(resultats_c[[k]]$dossiers$montant[resultats_c[[k]]$dossiers$poste == po]),
                          pr$montant[pr$poste == po & pr$segmentation == "ensemble"])
             }, NA)))
}

section("empreintes de la base dans la fiche (R.7, ADR 0011, point 13)")
modifiee <- base
modifiee$cotisations$montant[1L] <- 1201
fiche_mod <- calculer_provisions(modifiee, plan_c("C1"), tid)$fiche
ec <- comparer_feuilles(liste_fiche(fiche_mod), liste_fiche(resultats_c$C1$fiche), exclusions = EXCLUSIONS_FICHE)
verifier("(R.7) une modification de la base (montant de COC1) fait échouer la comparaison de l'empreinte de la table cotisations",
         "empreintes/donnees/cotisations" %in% ec$chemin && !any(grepl("^empreintes/donnees/(contrats|dossiers)", ec$chemin)))
verifier("(R.7) témoin : la base inchangée ne donne aucun écart de fiche",
         nrow(comparer_feuilles(liste_fiche(calculer_provisions(base, plan_c("C1"), tid)$fiche), liste_fiche(resultats_c$C1$fiche),
                                exclusions = EXCLUSIONS_FICHE)) == 0L)

section("restitution par segment : hypothèse D03h d'un contrat individuel (risque_en_cours, statut jugement_expert)")
b_h <- base
b_h$garanties_souscrites$taux_technique_tarif[b_h$garanties_souscrites$id_garantie_souscrite == "GSI1"] <- NA_real_
p_h <- p_c1
p_h$donnees$hypotheses <- c(p_h$donnees$hypotheses,
                            list(list(motif = "D03h", referentiel = "comptes_sociaux", poste = "tous", valeur = "0"),
                                 list(motif = "D03h", referentiel = "solvabilite_2", poste = "tous", valeur = "0")))
r_h <- calculer_provisions(b_h, p_h, tid)
q_h <- r_h$provisions
cel_h <- function(po, sg) q_h[q_h$poste == po & q_h$segment == sg, c("statut_calcul", "statut_resultat")]
verifier_egal("CTI1 sans taux du tarif, D03h déclarée : P3 et total du segment individuel jugement_expert (contrat sous hypothèse), segment collectif_obligatoire de P3 inchangé (approximation_numerique), P3 ensemble jugement_expert",
              lapply(list(c(P3, "individuel"), c("total", "individuel"), c(P3, "collectif_obligatoire"), c(P3, "ensemble")),
                     function(x) { y <- cel_h(x[1L], x[2L]); rownames(y) <- NULL; as.list(y) }),
              list(list(statut_calcul = "calcule", statut_resultat = "jugement_expert"),
                   list(statut_calcul = "calcule", statut_resultat = "jugement_expert"),
                   list(statut_calcul = "calcule", statut_resultat = "approximation_numerique"),
                   list(statut_calcul = "calcule", statut_resultat = "jugement_expert")))

section("scénarios adverses : unités valorisées et segments (contrat exclu, garantie souscrite exclue)")
# Aucun de ces cas ne finit en stop() « segment indéterminé » de .segment_unites() : chacun rend
# un objet resultat_provie (exclusion déclarée au bilan, ou poste calculé) ou un refus classé.
excl_x <- function(motifs, famille) {
  do.call(rbind, lapply(motifs, function(m) data.frame(motif = m, famille = ns$FAMILLES_CALCUL,
                                                       action = ifelse(ns$FAMILLES_CALCUL == famille, "exclure", "conserver"),
                                                       stringsAsFactors = FALSE)))
}
segs_x <- list(nc = list(regle = "nature_contrat"), ct = list(regle = "contrat"), an = list(regle = "annee_survenance"),
               la = list(regle = "ligne_activite", correspondance = list(deces = "ldec")))
b_ct <- base   # CTC1 : date de fin antérieure à l'effet (D02a sur contrats), fin saisie avant l'arrêté
b_ct$contrats$date_fin[1L] <- D("2019-06-01")
b_ct$contrats$date_saisie_fin[1L] <- D("2025-06-02")
b_ct$contrats$motif_fin[1L] <- "resiliation_adherent"
b_gs <- base   # GSC1 : date de fin antérieure à l'effet (D02a sur garanties_souscrites ; D10b induit)
b_gs$garanties_souscrites$date_fin[1L] <- D("2019-06-01")
scenarios <- list(
  list("contrat CTC1 exclu pour engagement (D02a, exclure)", b_ct, excl_x("D02a", "engagement")),
  list("contrat CTC1 exclu pour risque_en_cours (D02a, exclure)", b_ct, excl_x("D02a", "risque_en_cours")),
  list("garantie souscrite GSC1 exclue pour engagement (D02a, D10b, exclure)", b_gs, excl_x(c("D02a", "D10b"), "engagement")),
  list("garantie souscrite GSC1 exclue pour risque_en_cours (D02a, D10b, exclure)", b_gs,
       excl_x(c("D02a", "D10b"), "risque_en_cours")))
for (sc in scenarios) {
  p_x <- within(p_c1, perimetre$segmentations <- segs_x)
  if (!is.null(sc[[3L]])) p_x$donnees$exclusions <- sc[[3L]]
  issue <- tryCatch(calculer_provisions(sc[[2L]], p_x, tid), refus_provie = function(e) e, error = function(e) e)
  verifier(paste0("scénario adverse : ", sc[[1L]], " : resultat_provie ou refus classé, jamais une erreur interne (",
                  if (inherits(issue, "error")) conditionMessage(issue) else class(issue)[1L], ")"),
           inherits(issue, "resultat_provie") || inherits(issue, "refus_provie"))
}

section("population sous couverture exclue (critère (4.1), § 5.3, § 5.5, § 5.6, erratum v1.0.13)")
# Valeurs en dur de (a), (b) et (c) : § 7.7, critère (4.1) ; (a) et (c) constatées à la reprise
# (P1 = P2 = 0) ; (b) : valeurs de la reprise de #67 (P3 sans CTC1).
seg_nc_ct <- list(nc = list(regle = "nature_contrat"), ct = list(regle = "contrat"))
calc_x <- function(b, ex) {
  p_x <- within(p_c1, perimetre$segmentations <- seg_nc_ct)
  p_x$donnees$exclusions <- ex
  calculer_provisions(b, p_x, tid)
}
cel_x <- function(r, po, sg = "ensemble") {
  x <- r$provisions[r$provisions$poste == po & r$provisions$segment == sg, c("montant", "nombre_dossiers", "statut_resultat")]
  rownames(x) <- NULL
  x
}
copies_x <- function(r) {
  e <- r$donnees$enjeu
  e <- e[e$poste != "ensemble" & e$table %in% c("contrats", "garanties_souscrites"), c("table", "motif", "famille", "action", "poste")]
  e <- unique(e)
  rownames(e) <- NULL
  e
}
r_a <- calc_x(b_ct, excl_x("D02a", "engagement"))
verifier_egal("(4.1) (a) CTC1 exclu pour engagement (D02a) : P1 = P2 = 0 (ensemble, 0 dossier, exact) ; aucune cellule de P1 ni de P2 dans les segments ; P3 inchangé (4 275,9861, avec CTC1) ; aucune ligne de dossiers ; exclusions D02a engagement exclure, 1 ligne, 5 dossiers",
              list(cel_x(r_a, P1), cel_x(r_a, P2),
                   sum(r_a$provisions$poste %in% c(P1, P2) & r_a$provisions$segmentation != "ensemble"),
                   egal_mixte(cel_x(r_a, P3)$montant, 4275.9860504871), nrow(r_a$dossiers),
                   as.list(r_a$donnees$exclusions[r_a$donnees$exclusions$action == "exclure",
                                                  c("motif", "famille", "nombre_lignes", "nombre_dossiers")])),
              list(data.frame(montant = 0, nombre_dossiers = 0L, statut_resultat = "exact", stringsAsFactors = FALSE),
                   data.frame(montant = 0, nombre_dossiers = 0L, statut_resultat = "exact", stringsAsFactors = FALSE),
                   0L, TRUE, 0L, list(motif = "D02a", famille = "engagement", nombre_lignes = 1L, nombre_dossiers = 5L)))
verifier_egal("(4.1) (a) segments : aucune ligne de dossier (aucune colonne de la ligne de contrats exclue n'est lue pour une unité de P1 ou P2) ; enjeu : rangée contrats D02a engagement exclure copiée vers P1 et P2, risque_en_cours conserver vers P3 seul",
              list(sum(!is.na(r_a$donnees$segments$id_dossier)), copies_x(r_a)),
              list(0L, data.frame(table = "contrats", motif = "D02a", famille = c("engagement", "engagement", "risque_en_cours"),
                                  action = c("exclure", "exclure", "conserver"), poste = c(P1, P2, P3), stringsAsFactors = FALSE)))
r_b <- calc_x(b_ct, excl_x("D02a", "risque_en_cours"))
verifier("(4.1) (b) CTC1 exclu pour risque_en_cours : P3 = 3 710,6710 (sans CTC1) ; P1 337 225,9591013698 et P2 103 936 inchangés",
         egal_mixte(c(cel_x(r_b, P3)$montant, cel_x(r_b, P1)$montant, cel_x(r_b, P2)$montant),
                    c(3710.6709819939, 337225.9591013698, 103936)))
verifier_egal("(4.1) (b) enjeu : rangée contrats D02a risque_en_cours exclure copiée vers P3 seul ; engagement conserver vers aucun poste (P1 et P2 ne lisent pas contrats.date_fin)",
              copies_x(r_b),
              data.frame(table = "contrats", motif = "D02a", famille = "risque_en_cours", action = "exclure", poste = P3,
                         stringsAsFactors = FALSE))
r_c <- calc_x(b_gs, rbind(excl_x("D02a", "engagement"), excl_x("D10b", "aucune")))
verifier_egal("(4.1) (c) GSC1 exclue pour engagement (D02a), D10b conserver partout : P1 = P2 = 0 (par la garantie souscrite exclue ; lignes de dossiers gardées sous D10b) ; P3 inchangé",
              list(cel_x(r_c, P1)$montant, cel_x(r_c, P2)$montant, egal_mixte(cel_x(r_c, P3)$montant, 4275.9860504871),
                   unique(r_c$donnees$exclusions$action[r_c$donnees$exclusions$motif == "D10b"])),
              list(0, 0, TRUE, "conserver"))
verifier("(4.1) (d) une seule implémentation : garanties_couverture_exclue() définie une fois, dans R/donnees.R ; appelée par calculer_engagement() et, pour P3, une seule fois, dans .gs_deces_p3() (seule sélection des garanties souscrites deces de P3, audit de #72, m1), elle-même appelée par provisions_individuelles(), provisions_collectives() et calculer_risque_en_cours()",
         local({
           defs <- unlist(lapply(list.files(file.path(racine, "R"), pattern = "\\.R$", full.names = TRUE), function(f) {
             l <- readLines(f, warn = FALSE)
             if (any(grepl("^garanties_couverture_exclue <- function", l))) basename(f) else NULL
           }))
           appels <- function(f, g) {
             x <- gregexpr(paste0(g, "("), paste(deparse(f), collapse = "\n"), fixed = TRUE)[[1L]]
             sum(x > 0L)
           }
           p3 <- c("provisions_individuelles", "provisions_collectives", "calculer_risque_en_cours")
           identical(defs, "donnees.R") && appels(ns$calculer_engagement, "garanties_couverture_exclue") >= 1L &&
             appels(ns$.gs_deces_p3, "garanties_couverture_exclue") == 1L &&
             all(vapply(p3, function(f) appels(ns[[f]], ".gs_deces_p3") == 1L &&
                          appels(ns[[f]], "garanties_couverture_exclue") == 0L, NA))
         }))
decl_a <- p_c1$donnees
decl_a$exclusions <- excl_x("D02a", "engagement")
verifier_egal("(4.1) (d) garanties_couverture_exclue() : GSC1 sous (a) pour engagement, rien pour risque_en_cours ; GSC1 sous (c) ; rien sans exclusion",
              list(ns$garanties_couverture_exclue(b2_vue(b_ct, A1, decl_a,
                                                         p_c1$conventions), "engagement"),
                   ns$garanties_couverture_exclue(b2_vue(b_ct, A1, decl_a,
                                                         p_c1$conventions), "risque_en_cours"),
                   ns$garanties_couverture_exclue(b2_vue(base, A1, p_c1$donnees, p_c1$conventions), "engagement")),
              list("GSC1", character(0), character(0)))
# (f1) P3 individuel au niveau de la fonction (champ (a)) : ligne CTI1 de contrats, puis de
# garanties_souscrites, exclue pour risque_en_cours dans la vue ; témoin : la même exclusion
# pour engagement est sans effet sur P3.
v_ind <- b2_vue(base, A1, p_c1$donnees, p_c1$conventions)
ind_x <- function(v) {
  x <- ns$provisions_individuelles(v, p_c1, tb, FALSE)$contrats
  list(x$id_contrat, x$montant)
}
ligne_cti1 <- function(v, t) which(as.character(ns$valeurs_vue(v, t, "id_contrat")) == "CTI1")
verifier("(4.1) (f1) provisions_individuelles() : sans exclusion CTI1 3 046,432119555 et CTI3 664,238862439 ; CTI1 exclu pour risque_en_cours (contrats, puis garanties_souscrites) : CTI3 seul ; même exclusion pour engagement : les deux contrats",
         local({
           ok <- function(r, ids, m) identical(r[[1L]], ids) && egal_mixte(r[[2L]], m)
           res <- ok(ind_x(v_ind), c("CTI1", "CTI3"), c(3046.432119555168, 664.23886243874))
           for (t in c("contrats", "garanties_souscrites")) {
             v_r <- v_ind
             v_r$exclu$risque_en_cours[[t]][ligne_cti1(v_ind, t)] <- TRUE
             v_e <- v_ind
             v_e$exclu$engagement[[t]][ligne_cti1(v_ind, t)] <- TRUE
             res <- res && ok(ind_x(v_r), "CTI3", 664.23886243874) &&
               ok(ind_x(v_e), c("CTI1", "CTI3"), c(3046.432119555168, 664.23886243874))
           }
           res
         }))
# (f2) De bout en bout : D02a sur contrats.date_debut_gestion de CTI1 (2023-01-01, avant l'effet ;
# colonne lue par aucun poste de B2), exclu pour risque_en_cours : seule l'exclusion de la ligne
# sort CTI1 de P3 ; témoin : exclu pour engagement, P3 et total inchangés (§ 7.7, (4.1) (f2),
# erratum v1.0.14 ; valeurs d'actuary, remesurées).
b_dg <- base
b_dg$contrats$date_debut_gestion[b_dg$contrats$id_contrat == "CTI1"] <- D("2023-01-01")
r_dg <- calc_x(b_dg, excl_x("D02a", "risque_en_cours"))
r_dg_e <- calc_x(b_dg, excl_x("D02a", "engagement"))
verifier("(4.1) (f2) D02a sur date_debut_gestion de CTI1, exclu pour risque_en_cours : P3 = 1 229,553930931891, total 442 391,513032301678, aucune cellule de P3 au segment CTI1 ; exclu pour engagement : P3 4 275,986050487058, total 445 437,9451518568",
         egal_mixte(c(cel_x(r_dg, P3)$montant, cel_x(r_dg, "total")$montant, cel_x(r_dg_e, P3)$montant,
                      cel_x(r_dg_e, "total")$montant),
                    c(1229.553930931891, 442391.513032301678, 4275.986050487058, 445437.9451518568)) &&
           nrow(cel_x(r_dg, P3, "CTI1")) == 0L &&
           identical(r_dg$donnees$exclusions$nombre_lignes[r_dg$donnees$exclusions$action == "exclure"], 1L))
attendu_echec("(4.1) (f3) sous (f2), exclusion pour risque_en_cours : au moins une rangée d'enjeu de garantie deces copiée vers P3 (mesure de la provision retirée)",
              "#84",
              any(r_dg$donnees$enjeu$garantie == "deces" & r_dg$donnees$enjeu$poste == P3))
verifier("(4.1) (e) témoins : sans exclusion, les cellules de la base construite (C1) sont celles du § 7.8.4 (ensemble)",
         egal_mixte(vapply(c(P1, P2, P3, "total"), function(po) cel_x(r_c1, po)$montant, 0),
                    c(337225.9591013698, 103936, 4275.9860504871, 445437.9451518568)))

section("clé manquante ou vide dans la population de couverture exclue (#154 ; spécification donnees v1.8, § 2.2, B.4, « Sites résiduels »)")
# Appels internes sur la vue de la base construite à A1, mutée (ctx$base, vue$exclu) : aucun site
# n'est atteint par une base à l'arrêté A1 (sonde de #154 : la clé défectueuse refuse sa table en
# portée table, les postes sont arrêtés avant l'appel). Chaque état est mesuré pour "" et pour le
# témoin NA (C123-8), contre le témoin à clés renseignées (règles (i) à (iii) de #154, Q-B4 (T1)).
v154 <- function(f, cle) {   # f : mutation, rend la vue (vue$exclu est une copie, ctx un environnement)
  f(b2_vue(base, A1, p_c1$donnees, p_c1$conventions), cle)
}
ligne154 <- function(v, t, col, id) which(as.character(ns$valeurs_vue(v, t, col)) == id)
cles154 <- list(vide = "", manquante = NA_character_)
gce154 <- ns$garanties_couverture_exclue
# (i) contrat exclu : CTI1 exclu pour risque_en_cours ; GSI3 rattachée au contrat de clé `cle`
mut_ct <- function(v, cle) {
  if (!is.null(cle)) v$ctx$base$contrats$id_contrat[ligne154(v, "contrats", "id_contrat", "CTI1")] <- cle
  v$exclu$risque_en_cours$contrats[2L] <- TRUE
  if (!is.null(cle)) v$ctx$base$garanties_souscrites$id_contrat[3L] <- cle
  v
}
# (ii) identifiants rendus : GSI1 et GSI3 d'identifiant `cle`, GSI1 seule exclue (deux familles)
mut_id <- function(v, cle) {
  if (!is.null(cle)) v$ctx$base$garanties_souscrites$id_garantie_souscrite[c(2L, 3L)] <- cle
  v$exclu$engagement$garanties_souscrites[2L] <- TRUE
  v$exclu$risque_en_cours$garanties_souscrites[2L] <- TRUE
  v
}
for (k in names(cles154)) {
  cle <- cles154[[k]]
  verifier_egal(paste0("#154 garanties_couverture_exclue(), contrat exclu de clé ", k, " : GSI3, de contrat de clé ", k,
                       ", n'est pas exclue (aucun appariement) ; témoin renseigné : GSI1"),
                list(gce154(v154(mut_ct, cle), "risque_en_cours"), gce154(v154(mut_ct, NULL), "risque_en_cours")),
                list(character(0), "GSI1"))
  verifier_egal(paste0("#154 garanties_couverture_exclue(), GSI1 exclue d'identifiant ", k,
                       " : aucun identifiant NA ni \"\" rendu, aucune erreur ; témoin renseigné : GSI1"),
                list(gce154(v154(mut_id, cle), "engagement"), gce154(v154(mut_id, cle), "risque_en_cours"),
                     gce154(v154(mut_id, NULL), "engagement")),
                list(character(0), character(0), "GSI1"))
}
# même état atteint par une base, à l'arrêté égal à l'extraction (vue totale) : GSC1 d'identifiant
# manquant ou vide (table refusée en portée table), contrat CTC1 exclu pour risque_en_cours (D02a) ;
# témoin renseigné : GSC1 rendue
b154 <- base
b154$contrats$date_fin[1L] <- D("2019-06-01")
b154$contrats$date_saisie_fin[1L] <- D("2025-06-02")
b154$contrats$motif_fin[1L] <- "resiliation_adherent"
d154 <- p_c1$donnees
d154$exclusions <- do.call(rbind, lapply("D02a", function(m) data.frame(
  motif = m, famille = ns$FAMILLES_CALCUL, action = ifelse(ns$FAMILLES_CALCUL == "risque_en_cours", "exclure", "conserver"),
  stringsAsFactors = FALSE)))
AX154 <- D("2026-03-31")
for (k in names(cles154)) {
  b <- b154
  b$garanties_souscrites$id_garantie_souscrite[1L] <- cles154[[k]]
  verifier_egal(paste0("#154 base, arrêté à l'extraction : GSC1 d'identifiant ", k, ", CTC1 exclu (D02a, risque_en_cours) : ",
                       "aucun identifiant rendu ; témoin renseigné : GSC1"),
                list(gce154(b2_vue(b, AX154, d154, p_c1$conventions), "risque_en_cours"),
                     gce154(b2_vue(b154, AX154, d154, p_c1$conventions), "risque_en_cours")),
                list(character(0), "GSC1"))
}
# segments_vue() (exclue_eng, exclue_rec ; règle (ii)) : une garantie souscrite d'identifiant
# manquant ou vide ne porte aucune unité contrat, exclue ou non
unites154 <- function(v) {
  s <- ns$segments_vue(v, list(ct = list(regle = "contrat")), "deces")
  sort(unique(s$id_contrat[is.na(s$id_dossier)]), method = "radix")
}
mut_seg <- function(v, cle) {
  if (!is.null(cle)) v$ctx$base$garanties_souscrites$id_garantie_souscrite[2L] <- cle
  v
}
for (k in names(cles154)) {
  cle <- cles154[[k]]
  verifier_egal(paste0("#154 segments_vue() : GSI1 d'identifiant ", k, " : CTI1 n'est pas une unité ; GSI1 et GSI3 d'identifiant ", k,
                       ", GSI1 exclue : ni CTI1 ni CTI3 ; témoins renseignés : CTC1, CTI1, CTI3 et CTC1, CTI3"),
                list(unites154(v154(mut_seg, cle)), unites154(v154(mut_id, cle)),
                     unites154(v154(mut_seg, NULL)), unites154(v154(mut_id, NULL))),
                list(c("CTC1", "CTI3"), "CTC1", c("CTC1", "CTI1", "CTI3"), c("CTC1", "CTI3")))
}
# segments_vue(), codes de garantie d'un contrat (ligne_activite ; #158, site 4) : le code d'une
# garantie souscrite d'id_contrat manquant ou vide n'est jamais attribué à un contrat (comparaison
# par apparier_cles(), non par ==, qui laissait un NA au vecteur des codes) ; résultat identique
# avant et après. GSI1.id_contrat de clé `cle` : CTI1 n'est plus une unité, les autres gardent
# leur ligne d'activité
mut_seg_ct <- function(v, cle) {
  if (!is.null(cle)) v$ctx$base$garanties_souscrites$id_contrat[2L] <- cle
  v
}
la154 <- function(cle) {
  s <- ns$segments_vue(v154(mut_seg_ct, cle), list(la = list(regle = "ligne_activite", correspondance = list(deces = "ldec"))),
                       "deces")
  s <- s[is.na(s$id_dossier), , drop = FALSE]
  list(s$id_contrat, s$segment)
}
for (k in names(cles154)) {
  verifier_egal(paste0("#158 segments_vue(), ligne_activite : GSI1.id_contrat de clé ", k, " : unités contrat CTC1 et CTI3, ligne ldec ; ",
                       "témoin renseigné : CTC1, CTI1, CTI3"),
                list(la154(cles154[[k]]), la154(NULL)),
                list(list(c("CTC1", "CTI3"), c("ldec", "ldec")), list(c("CTC1", "CTI1", "CTI3"), rep("ldec", 3L))))
}
# engagement : contrat de la garantie souscrite des dossiers (couverture_exclue) et ligne du
# dossier de l'état (i_dos)
cat154 <- catalogue_garanties()
p1_154 <- function(v) {
  x <- ns$calculer_engagement(v, p_c1, tb, cat154, "deces", "sinistres_declares_non_regles")$cellules
  x <- x[x$segment == "ensemble", ]
  list(montant = x$montant, nombre_dossiers = x$nombre_dossiers, motif_arret = x$motif_arret)
}
mut_eng_ct <- function(v, cle) {
  if (!is.null(cle)) {
    v$ctx$base$contrats$id_contrat[1L] <- cle
    v$ctx$base$garanties_souscrites$id_contrat[1L] <- cle
  }
  v$exclu$engagement$contrats[1L] <- TRUE
  v
}
# DOR1 et DOR3 de clé `cle`, DOR3 seul exclu pour engagement
mut_eng_dos <- function(v, cle) {
  if (!is.null(cle)) v$ctx$base$dossiers$id_dossier[c(1L, 2L)] <- cle
  v$exclu$engagement$dossiers[2L] <- TRUE
  v
}
for (k in names(cles154)) {
  cle <- cles154[[k]]
  verifier_egal(paste0("#154 calculer_engagement() : CTC1 exclu pour engagement, CTC1 et GSC1.id_contrat de clé ", k,
                       " : GSC1 n'est rattachée à aucun contrat, ni exclue par lui (ses dossiers restent dans la population, ",
                       "affiliation non déterminée) ; témoin renseigné : P1 = 0, 0 dossier"),
                list(p1_154(v154(mut_eng_ct, cle)), p1_154(v154(mut_eng_ct, NULL))),
                list(list(montant = NA_real_, nombre_dossiers = NA_integer_, motif_arret = "affiliation_non_determinee"),
                     list(montant = 0, nombre_dossiers = 0L, motif_arret = NA_character_)))
  verifier(paste0("#154 calculer_engagement() : DOR1 et DOR3 d'identifiant ", k, ", DOR3 seul exclu (appel interne, état ",
                  "inatteignable par une base) : erreur interne, jamais un retrait silencieux de la population ; ",
                  "témoin renseigné : aucune erreur"),
           local({
             m <- tryCatch({ p1_154(v154(mut_eng_dos, cle)); "aucune erreur" }, error = function(e) conditionMessage(e))
             t <- tryCatch({ p1_154(v154(mut_eng_dos, NULL)); "aucune erreur" }, error = function(e) conditionMessage(e))
             startsWith(m, "erreur interne de provie : calculer_engagement() : dossier") && identical(t, "aucune erreur")
           }))
  # sonde par une base : un identifiant de dossier manquant ou vide refuse dossiers en portée
  # table ; P1 et P2 sont arrêtés avant etats_a_date() (M239), sans erreur
  b_dos <- base
  b_dos$dossiers$id_dossier[1L] <- cle
  p_dos <- p_c1   # déclarations exigées par le bilan de cette base (D07, limite d'âge, D04a, D04b)
  p_dos$revalorisation$capital_deces$taux_par_annee <- c(`2024` = 0.03, `2025` = 0.024, `2026` = 0.024)
  p_dos$donnees$seuils$d07b_mois <- 6L
  p_dos$donnees$conventions <- NULL
  p_dos$conventions$limite_age <- list(regle = "atteinte", age = "revolu")
  p_dos$donnees$exclusions <- do.call(rbind, lapply(c("D04a", "D04b"), function(m) data.frame(
    motif = m, famille = ns$FAMILLES_CALCUL, action = "conserver", stringsAsFactors = FALSE)))
  verifier_egal(paste0("#154 calculer_provisions(), base : DOR1 d'identifiant ", k, " : P1 et P2 arrêtés, aucune erreur"),
                local({
                  r <- tryCatch(calculer_provisions(b_dos, p_dos, tid), error = function(e) e)
                  if (inherits(r, "error")) conditionMessage(r) else {
                    x <- r$provisions[r$provisions$segment == "ensemble" & r$provisions$poste %in% c(P1, P2), ]
                    unique(x$statut_calcul)
                  }
                }),
                "arrete")
}
# P3 individuel : garantie souscrite → contrat, contrat → assuré, assuré → sinistre
ind154 <- function(v) {
  x <- ns$provisions_individuelles(v, p_c1, tb, FALSE)
  list(id_contrat = x$contrats$id_contrat, arret = x$arret, identifiant = x$identifiant)
}
mut_ind_gs <- function(v, cle) {   # CTI1 et GSI3.id_contrat de clé `cle`, aucune exclusion
  if (!is.null(cle)) {
    v$ctx$base$contrats$id_contrat[2L] <- cle
    v$ctx$base$garanties_souscrites$id_contrat[3L] <- cle
  }
  v
}
mut_ind_as <- function(v, cle) {   # CTI1.id_assure et la ligne ASI3 de assures de clé `cle`
  if (!is.null(cle)) {
    v$ctx$base$contrats$id_assure[2L] <- cle
    v$ctx$base$assures$id_assure[ligne154(v, "assures", "id_assure", "ASI3")] <- cle
  }
  v
}
mut_ind_si <- function(v, cle) {   # CTI1.id_assure et SIR1.id_assure (décès survenu avant A1) de clé `cle`
  v$ctx$base$contrats$id_assure[2L] <- if (is.null(cle)) "ASI1" else cle
  v$ctx$base$sinistres$id_assure[1L] <- if (is.null(cle)) "ASI1" else cle
  v
}
for (k in names(cles154)) {
  cle <- cles154[[k]]
  verifier_egal(paste0("#154 provisions_individuelles() : GSI1 d'identifiant ", k, " hors de la population (CTI3 seul) ; ",
                       "GSI1 et GSI3 d'identifiant ", k, ", GSI1 exclue : aucun contrat ; témoin renseigné : CTI1, CTI3"),
                list(ind154(v154(mut_seg, cle)), ind154(v154(mut_id, cle)), ind154(v154(mut_seg, NULL))),
                list(list(id_contrat = "CTI3", arret = NA_character_, identifiant = NA_character_),
                     list(id_contrat = NULL, arret = NA_character_, identifiant = NA_character_),
                     list(id_contrat = c("CTI1", "CTI3"), arret = NA_character_, identifiant = NA_character_)))
  verifier_egal(paste0("#154 provisions_individuelles() : CTI1 et GSI3.id_contrat de clé ", k, " : aucune garantie appariée à un ",
                       "contrat (aucun contrat) ; témoin renseigné : CTI1, CTI3"),
                list(ind154(v154(mut_ind_gs, cle)), ind154(v154(mut_ind_gs, NULL))),
                list(list(id_contrat = NULL, arret = NA_character_, identifiant = NA_character_),
                     list(id_contrat = c("CTI1", "CTI3"), arret = NA_character_, identifiant = NA_character_)))
  verifier_egal(paste0("#154 provisions_individuelles() : CTI1.id_assure et ASI3 de clé ", k, " : assuré de CTI1 non apparié, ",
                       "naissance inconnue, poste arrêté (parametre_non_determine, CTI1)"),
                ind154(v154(mut_ind_as, cle)),
                list(id_contrat = NULL, arret = "parametre_non_determine", identifiant = "CTI1"))
  verifier_egal(paste0("#154 provisions_individuelles() : CTI1.id_assure et SIR1.id_assure de clé ", k, " : le décès n'est pas ",
                       "apparié à l'assuré (assuré non apparié, poste arrêté sur CTI1) ; témoin renseigné ASI1 : CTI1 sort, CTI3 seul"),
                list(ind154(v154(mut_ind_si, cle)), ind154(v154(mut_ind_si, NULL))),
                list(list(id_contrat = NULL, arret = "parametre_non_determine", identifiant = "CTI1"),
                     list(id_contrat = "CTI3", arret = NA_character_, identifiant = NA_character_)))
}
# P3 collectif : contrat ↔ garantie souscrite, cotisation → garantie souscrite
col154 <- function(v) {
  x <- ns$provisions_collectives(v, p_c1)
  list(id_contrat = x$id_contrat, arret = attr(x, "arret"))
}
mut_col_ct <- function(v, cle) {   # CTC1 et GSC1.id_contrat de clé `cle`
  if (!is.null(cle)) {
    v$ctx$base$contrats$id_contrat[1L] <- cle
    v$ctx$base$garanties_souscrites$id_contrat[1L] <- cle
  }
  v
}
mut_col_gs <- function(v, cle) {   # GSC1 et ses cotisations COC1, COC2 de clé `cle`
  if (!is.null(cle)) {
    v$ctx$base$garanties_souscrites$id_garantie_souscrite[1L] <- cle
    v$ctx$base$cotisations$id_garantie_souscrite[] <- cle
  }
  v
}
for (k in names(cles154)) {
  cle <- cles154[[k]]
  verifier_egal(paste0("#154 provisions_collectives() : CTC1 et GSC1.id_contrat de clé ", k, " : aucun contrat du champ ; ",
                       "GSC1 et ses cotisations de clé ", k, " : aucun contrat du champ ; témoin renseigné : CTC1"),
                list(col154(v154(mut_col_ct, cle)), col154(v154(mut_col_gs, cle)), col154(v154(mut_col_ct, NULL))),
                list(list(id_contrat = character(0), arret = NA_character_), list(id_contrat = character(0), arret = NA_character_),
                     list(id_contrat = "CTC1", arret = NA_character_)))
}

section("période couverte manquante d'une cotisation de P3 (critère (4.5), § 5.5, § 5.6, § 6.2, erratum v1.0.15)")
# Base construite, plan recommandees à A = 2025-12-31 ; D03f déclaré pour risque_en_cours (les
# trois autres familles en conserver), ou en hypothèse H (deux référentiels, poste tous) ; sans
# segmentation, puis avec nature_contrat et contrat. Valeurs en dur : § 7.7, critère (4.5).
hyp_x <- function(m) lapply(ns$REFERENTIELS, function(r) list(motif = m, referentiel = r, poste = "tous", valeur = "regle"))
plan_45 <- function(seg, ex = NULL, h = NULL) {
  q <- p_c1
  q$perimetre$segmentations <- seg
  if (!is.null(ex)) q$donnees$exclusions <- ex
  if (!is.null(h)) q$donnees$hypotheses <- h
  q
}
segs_45 <- list(sans = list(), avec = list(nc = list(regle = "nature_contrat"), ct = list(regle = "contrat")))
b_cf <- base   # fin_periode de COC1 manquante
b_cf$cotisations$fin_periode[b_cf$cotisations$id_cotisation == "COC1"] <- as.Date(NA)
b_cf2 <- base  # debut_periode de COC1 manquante, mouvement au 2025-08-20
b_cf2$cotisations$debut_periode[b_cf2$cotisations$id_cotisation == "COC1"] <- as.Date(NA)
b_cf2$cotisations$date_mouvement[b_cf2$cotisations$id_cotisation == "COC1"] <- D("2025-08-20")
b_un <- b_cf   # périodicité unique : règle H non applicable
b_un$garanties_souscrites$periodicite_cotisation[b_un$garanties_souscrites$id_garantie_souscrite == "GSC1"] <- "unique"
b_k <- base    # témoin de Kleene : debut_periode de COC2 manquante, fin 2025-06-30 au plus A
b_k$cotisations$debut_periode[b_k$cotisations$id_cotisation == "COC2"] <- as.Date(NA)
id_arret <- function(r) {
  pr <- r$fiche$parametres_retenus$postes
  ns$lire_liste(charToRaw(pr$parametres[pr$poste == P3]))$identifiant_arret
}
for (nom_s in names(segs_45)) {
  sg <- segs_45[[nom_s]]
  et <- paste0(" (", nom_s, " segmentation)")
  r_45a <- calculer_provisions(b_cf, plan_45(sg, ex = excl_x("D03f", "risque_en_cours")), tid)
  verifier(paste0("(4.5) (a) b_cf, D03f exclure : P3 3 710,670981993908, total 444 872,630083363678 ; exclusions D03f risque_en_cours exclure, 1 ligne", et),
           egal_mixte(c(cel_x(r_45a, P3)$montant, cel_x(r_45a, "total")$montant), c(3710.670981993908, 444872.630083363678)) &&
             identical(r_45a$donnees$exclusions$nombre_lignes[r_45a$donnees$exclusions$motif == "D03f" &
                                                                r_45a$donnees$exclusions$action == "exclure"], 1L))
  r_45b <- motif_de(r_45b_r <- calculer_provisions(b_cf, plan_45(sg, ex = excl_x("D03f", "aucune")), tid))
  q_b <- r_45b_r$provisions
  verifier_egal(paste0("(4.5) (b) b_cf, D03f conserver : P3 arrêté (parametre_non_determine, CTC1), total arrêté ; P1 et P2 inchangés ; P3 arrêté dans chaque segment restitué", et),
                list(r_45b, unique(q_b$motif_arret[q_b$poste == P3]), unique(q_b$statut_calcul[q_b$poste == P3]),
                     unique(q_b$motif_arret[q_b$poste == "total"]), id_arret(r_45b_r),
                     egal_mixte(c(cel_x(r_45b_r, P1)$montant, cel_x(r_45b_r, P2)$montant), c(337225.959101369779, 103936))),
                list("aucun", "parametre_non_determine", "arrete", "poste_arrete:provision_mathematique_temporaire_deces", "CTC1",
                     TRUE))
  r_45c <- calculer_provisions(b_cf, plan_45(sg, h = hyp_x("D03f")), tid)
  verifier(paste0("(4.5) (c) b_cf, D03f H (période 2025-07-01 au 2026-06-30) : P3 4 275,986050487058, total 445 437,945151856809, P3 jugement_expert ; hypotheses_defaut D03f, 1 ligne par référentiel", et),
           egal_mixte(c(cel_x(r_45c, P3)$montant, cel_x(r_45c, "total")$montant), c(4275.986050487058, 445437.945151856809)) &&
             identical(cel_x(r_45c, P3)$statut_resultat, "jugement_expert") &&
             identical(r_45c$donnees$hypotheses_defaut$nombre[r_45c$donnees$hypotheses_defaut$motif == "D03f"], c(1L, 1L)))
  r_45d_x <- calculer_provisions(b_cf2, plan_45(sg, ex = excl_x("D03f", "risque_en_cours")), tid)
  r_45d <- calculer_provisions(b_cf2, plan_45(sg, h = hyp_x("D03f")), tid)
  verifier(paste0("(4.5) (d) b_cf2 : D03f exclure : P3 3 710,670981993908 ; D03f H (période 2025-08-01 au 2026-07-31, fin_periode présente non lue) : P3 4 372,8079682953, total 445 534,7670696651, CTC1 662,1369863014", et),
           egal_mixte(c(cel_x(r_45d_x, P3)$montant, cel_x(r_45d, P3)$montant, cel_x(r_45d, "total")$montant),
                      c(3710.670981993908, 4372.8079682953, 445534.7670696651)) &&
             egal_mixte(cel_x(r_45d, P3)$montant - 3710.670981993908, 1200 * 0.95 * 212 / 365))
  r_45e <- calculer_provisions(b_un, plan_45(sg, h = hyp_x("D03f")), tid)
  verifier_egal(paste0("(4.5) (e) périodicité unique, D03f H : P3 arrêté, parametre_non_determine, CTC1", et),
                list(cel_x(r_45e, P3)$montant, unique(r_45e$provisions$motif_arret[r_45e$provisions$poste == P3]), id_arret(r_45e)),
                list(NA_real_, "parametre_non_determine", "CTC1"))
  r_45f <- calculer_provisions(b_k, plan_45(sg, ex = excl_x("D03f", "aucune")), tid)
  verifier(paste0("(4.5) (f) témoin de Kleene : debut_periode de COC2 manquante, fin 2025-06-30 au plus A, D03f conserver : P3 4 275,986050487058, calculé", et),
           egal_mixte(cel_x(r_45f, P3)$montant, 4275.986050487058) &&
             all(r_45f$provisions$statut_calcul[r_45f$provisions$poste == P3] == "calcule"))
}
v_g <- b2_vue(base, A1, p_c1$donnees, p_c1$conventions)
v_g$ctx$base$cotisations$montant[v_g$ctx$base$cotisations$id_cotisation == "COC1"] <- NA_real_
verifier("(4.5) (g) provisions_collectives() : une cotisation de montant NA dans la vue est une erreur interne explicite, jamais un montant amputé",
         startsWith(motif_de(ns$provisions_collectives(v_g, p_c1)), "autre : erreur interne de provie"))
verifier_egal("(4.5) periode_cotisation_regle() : premier jour du mois du mouvement, p = 12, 6, 3, 1 mois ; unique, valeur illisible ou mouvement manquant : NA",
              lapply(ns$periode_cotisation_regle(D(c("2025-08-20", "2025-01-31", "2024-02-29", "2025-12-05", "2025-08-20", "2025-08-20", NA)),
                                                 c("annuelle", "semestrielle", "trimestrielle", "mensuelle", "unique", "bimestrielle",
                                                   "annuelle")), format),
              list(debut = c("2025-08-01", "2025-01-01", "2024-02-01", "2025-12-01", NA, NA, NA),
                   fin = c("2026-07-31", "2025-06-30", "2024-04-30", "2025-12-31", NA, NA, NA)))
# (h) C90-1 (#90 ; spécification `donnees` v1.9, § 9.4 ; T7 levé) : D02a sous H, relation R9 :
# survenance et déclaration de SIR4 tenues pour inconnues dans la vue ; P2 lit la survenance
# (revalorisation) : arrêt parametre_non_determine, DOR4 ; P1 inchangé (aucun dossier de SIR4).
b_h90 <- base
b_h90$sinistres$date_declaration[3L] <- D("2024-06-01")
p_alt <- b2_plan_reference("alternatives", A1, tb)
p_h90 <- p_alt
p_h90$donnees$hypotheses <- c(p_h90$donnees$hypotheses, hyp_x("D02a"))
p_c90 <- p_alt
p_c90$donnees$exclusions <- rbind(p_c90$donnees$exclusions, excl_x("D02a", "aucune"))
verifier("(4.5) (h) témoin : D02a sur sinistres.date_declaration (SIR4 au 2024-06-01), plan alternatives, D02a conserver : P2 126 906,734629181941",
         egal_mixte(cel_x(calculer_provisions(b_h90, p_c90, tid), P2)$montant, 126906.734629181941))
# erreur interne gardée (tryCatch) : une date inconnue lue comme une date échoue à l'assertion
r_h90 <- tryCatch(calculer_provisions(b_h90, p_h90, tid), error = identity)
verifier("(4.5) (h) C90-1 : D02a sous H (R9, SIR4) : le calcul aboutit (arrêt du poste, jamais une erreur interne)",
         !inherits(r_h90, "error"))
id_arret_poste <- function(r, po) {
  pr <- r$fiche$parametres_retenus$postes
  ns$lire_liste(charToRaw(pr$parametres[pr$poste == po]))$identifiant_arret
}
verifier_egal("(4.5) (h) C90-1 : D02a sous H (R9, SIR4) : P2 arrêté (parametre_non_determine, DOR4), total arrêté ; P1 égal à sa valeur sous conserver ; hypotheses_defaut D02a, 1 ligne par référentiel",
              list(cel_x(r_h90, P2)$montant, unique(r_h90$provisions$motif_arret[r_h90$provisions$poste == P2]), id_arret_poste(r_h90, P2),
                   unique(r_h90$provisions$statut_calcul[r_h90$provisions$poste == "total"]),
                   cel_x(r_h90, P1)$montant == cel_x(calculer_provisions(b_h90, p_c90, tid), P1)$montant,
                   r_h90$donnees$hypotheses_defaut$nombre[r_h90$donnees$hypotheses_defaut$motif == "D02a"]),
              list(NA_real_, "parametre_non_determine", "DOR4", "arrete", TRUE, c(1L, 1L)))

section("période inversée ou nulle, cas limites et valeur de D03f d'une cotisation de P3 (critère (4.6), § 5.5, erratum v1.0.16, #92)")
# Base construite (copies : b2_base_construite_deces_02() n'est pas modifiée), plan recommandees
# à A = 2025-12-31 ; D02a déclaré conserver pour les quatre familles, plus D03f quand le cas le
# dit ; sans segmentation, puis avec nature_contrat et contrat. Valeurs en dur : § 7.7, critère
# (4.6) ; « avant » mesuré à 88b47f3 (m25).
cot_x <- function(id, ...) {   # copie de la base, colonnes de la cotisation `id` modifiées
  b <- base
  m <- list(...)
  for (n in names(m)) b$cotisations[[n]][b$cotisations$id_cotisation == id] <- m[[n]]
  b
}
d02a_c <- excl_x("D02a", "aucune")
b_46a <- cot_x("COC1", debut_periode = D("2026-03-31"), fin_periode = D("2026-03-30"))
b_46b <- cot_x("COC1", debut_periode = D("2026-03-31"), fin_periode = D("2026-01-05"))
b_46d <- cot_x("COC1", debut_periode = D("2026-03-31"), fin_periode = D("2025-06-30"))
b_46e <- cot_x("COC1", fin_periode = as.Date(NA), date_mouvement = D("2024-11-15"))
b_46f <- cot_x("COC1", debut_periode = as.Date(NA))
b_46g <- cot_x("COC1", fin_periode = A1)
b_46i <- cot_x("COC2", debut_periode = as.Date(NA), date_mouvement = D("2025-03-01"))
hyp_v <- function(m, v) lapply(ns$REFERENTIELS, function(r) list(motif = m, referentiel = r, poste = "tous", valeur = v))
arret_46 <- function(r) {
  q <- r$provisions
  list(unique(q$motif_arret[q$poste == P3]), unique(q$statut_calcul[q$poste == P3]),
       unique(q$motif_arret[q$poste == "total"]), id_arret(r))
}
arret_attendu <- list("parametre_non_determine", "arrete", "poste_arrete:provision_mathematique_temporaire_deces", "CTC1")
for (nom_s in names(segs_45)) {
  sg <- segs_45[[nom_s]]
  et <- paste0(" (", nom_s, " segmentation)")
  r_46a <- calculer_provisions(b_46a, plan_45(sg, ex = d02a_c), tid)
  verifier_egal(paste0("(4.6) (a) COC1 du 2026-03-31 au 2026-03-30 (longueur nulle), D02a conserver : P3 arrêté (parametre_non_determine, CTC1), total arrêté ; P1 337 225,959101369779 et P2 103 936 inchangés", et),
                c(arret_46(r_46a), egal_mixte(c(cel_x(r_46a, P1)$montant, cel_x(r_46a, P2)$montant), c(337225.959101369779, 103936))),
                c(arret_attendu, TRUE))
  r_46b <- calculer_provisions(b_46b, plan_45(sg, ex = d02a_c), tid)
  verifier_egal(paste0("(4.6) (b) COC1 du 2026-03-31 au 2026-01-05 (inversée), D02a conserver : même arrêt (avant : 4 850,670981993908)", et),
                arret_46(r_46b), arret_attendu)
  # (c) sous D02a H, les deux bornes sont tenues pour inconnues et D03f s'enchaîne (#90, R7 ; M688) :
  # sans D03f déclaré, refus declaration_manquante ; D03f conserver, même arrêt ; D03f H, règle du
  # dictionnaire (période 2025-07-01 au 2026-06-30, comme (4.5) (c)) ; D03f exclure, COC1 hors du calcul
  r_46c <- calculer_provisions(b_46b, plan_45(sg, ex = excl_x("D03f", "aucune"), h = hyp_x("D02a")), tid)
  verifier_egal(paste0("(4.6) (c) cas (b) sous D02a H (deux référentiels, poste tous), D03f conserver : même arrêt ; sans D03f déclaré : refus declaration_manquante", et),
                c(arret_46(r_46c), motif_de(calculer_provisions(b_46b, plan_45(sg, h = hyp_x("D02a")), tid))),
                c(arret_attendu, "declaration_manquante"))
  r_46c_h <- calculer_provisions(b_46b, plan_45(sg, h = c(hyp_x("D02a"), hyp_x("D03f"))), tid)
  r_46c_x <- calculer_provisions(b_46b, plan_45(sg, ex = excl_x("D03f", "risque_en_cours"), h = hyp_x("D02a")), tid)
  verifier(paste0("(4.6) (c) cas (b) sous D02a H : D03f H, P3 4 275,986050487058 jugement_expert, hypotheses_defaut D03f 1 ligne par référentiel ; D03f exclure pour risque_en_cours, P3 3 710,670981993908, exclusion D03f d'une ligne", et),
           egal_mixte(c(cel_x(r_46c_h, P3)$montant, cel_x(r_46c_x, P3)$montant), c(4275.986050487058, 3710.670981993908)) &&
             identical(cel_x(r_46c_h, P3)$statut_resultat, "jugement_expert") &&
             identical(r_46c_h$donnees$hypotheses_defaut$nombre[r_46c_h$donnees$hypotheses_defaut$motif == "D03f"], c(1L, 1L)) &&
             identical(r_46c_x$donnees$exclusions$nombre_lignes[r_46c_x$donnees$exclusions$motif == "D03f" &
                                                                  r_46c_x$donnees$exclusions$action == "exclure"], 1L))
  r_46d <- calculer_provisions(b_46d, plan_45(sg, ex = d02a_c), tid)
  verifier(paste0("(4.6) (d) COC1 du 2026-03-31 au 2025-06-30 (inversée, fin au plus A) : P3 3 710,670981993908 exact, aucune unité CTC1", et),
           egal_mixte(cel_x(r_46d, P3)$montant, 3710.670981993908) && identical(cel_x(r_46d, P3)$statut_resultat, "exact") &&
             nrow(cel_x(r_46d, P3, "CTC1")) == 0L)
  r_46e <- calculer_provisions(b_46e, plan_45(sg, ex = d02a_c, h = hyp_x("D03f")), tid)
  verifier(paste0("(4.6) (e) mi1 : fin_periode de COC1 manquante, mouvement 2024-11-15, D03f H (période échue) : P3 3 710,670981993908 jugement_expert, total 444 872,630083363678", et),
           egal_mixte(c(cel_x(r_46e, P3)$montant, cel_x(r_46e, "total")$montant), c(3710.670981993908, 444872.630083363678)) &&
             identical(cel_x(r_46e, P3)$statut_resultat, "jugement_expert"))
  if (nom_s == "avec") {
    verifier_egal("(4.6) (e) mi1 : CTC1 unité de montant nul : cellule de P3 du segment CTC1, montant 0, jugement_expert",
                  as.list(cel_x(r_46e, P3, "CTC1")[c("montant", "statut_resultat")]),
                  list(montant = 0, statut_resultat = "jugement_expert"))
  }
  r_46f <- calculer_provisions(b_46f, plan_45(sg, ex = rbind(d02a_c, excl_x("D03f", "aucune"))), tid)
  verifier_egal(paste0("(4.6) (f) mi2 : debut_periode de COC1 manquante, fin 2026-06-30 > A, D03f conserver : arrêt parametre_non_determine, CTC1", et),
                arret_46(r_46f), arret_attendu)
  r_46g <- calculer_provisions(b_46g, plan_45(sg, ex = d02a_c), tid)
  verifier(paste0("(4.6) (g) mi2 : fin_periode de COC1 = A (2025-12-31), sans défaut : P3 3 710,670981993908 exact (cotisation échue)", et),
           egal_mixte(cel_x(r_46g, P3)$montant, 3710.670981993908) && identical(cel_x(r_46g, P3)$statut_resultat, "exact"))
  verifier_egal(paste0("(4.6) (h) Q1 : cas (e) avec la valeur n_importe : refus plan_invalide", et),
                motif_de(calculer_provisions(b_46e, plan_45(sg, ex = d02a_c, h = hyp_v("D03f", "n_importe")), tid)),
                "plan_invalide")
  r_46i <- calculer_provisions(b_46i, plan_45(sg, ex = d02a_c, h = hyp_x("D03f")), tid)
  verifier(paste0("(4.6) (i) Q2 (E16-2 (ii)) : debut_periode de COC2 manquante, fin 2025-06-30, mouvement 2025-03-01, D03f H : P3 4 275,986050487058 approximation_numerique (hypothèse non lue)", et),
           egal_mixte(cel_x(r_46i, P3)$montant, 4275.986050487058) &&
             identical(cel_x(r_46i, P3)$statut_resultat, "approximation_numerique"))
  # (k) Q-a : périodicité unique (règle non applicable), valeur invalide sous D03f H : arrêt, non refus
  verifier_egal(paste0("(4.6) (k) Q-a : COC1 de périodicité unique, fin_periode manquante, D03f H avec la valeur n_importe : arrêt parametre_non_determine, CTC1 (non refus)", et),
                arret_46(calculer_provisions(b_un, plan_45(sg, ex = d02a_c, h = hyp_v("D03f", "n_importe")), tid)), arret_attendu)
  # (l) Q-b : deux déclarations D03f (tous, puis P3), le poste P3 l'emportant sur tous
  r_46l <- calculer_provisions(b_46e, plan_45(sg, ex = d02a_c, h = c(hyp_v("D03f", "n_importe"),
                                                                     list(list(motif = "D03f", referentiel = "comptes_sociaux", poste = P3, valeur = "regle")))), tid)
  verifier(paste0("(4.6) (l) Q-b : D03f tous invalide (n_importe), D03f P3 regle (comptes sociaux) : pas de refus, P3 3 710,670981993908 jugement_expert, total 444 872,630083363678", et),
           egal_mixte(c(cel_x(r_46l, P3)$montant, cel_x(r_46l, "total")$montant), c(3710.670981993908, 444872.630083363678)) &&
             identical(cel_x(r_46l, P3)$statut_resultat, "jugement_expert"))
  verifier_egal(paste0("(4.6) (l) Q-b : D03f tous regle, D03f P3 invalide (n_importe, comptes sociaux) : refus plan_invalide", et),
                motif_de(calculer_provisions(b_46e, plan_45(sg, ex = d02a_c, h = c(hyp_v("D03f", "regle"),
                                                                                 list(list(motif = "D03f", referentiel = "comptes_sociaux", poste = P3, valeur = "n_importe")))), tid)),
                "plan_invalide")
}
verifier("(4.6) (j) une seule constante des mois par périodicité dans R/ : MOIS_PERIODE_COTISATION, sans point, module donnees (E16-3 (a)) ; .MOIS_PERIODICITE supprimée",
         local({
           # toute définition de premier niveau dont la valeur (celle de l'espace de noms) a pour noms
           # les périodicités de MOIS_PERIODE_COTISATION, quels que soient son nom et l'ordre des noms
           per <- names(ns$MOIS_PERIODE_COTISATION)
           defs <- unlist(lapply(list.files(file.path(racine, "R"), pattern = "\\.R$", full.names = TRUE), function(f) {
             noms <- character()
             for (e in parse(f, keep.source = FALSE, encoding = "UTF-8")) {
               if (is.call(e) && (identical(e[[1L]], as.name("<-")) || identical(e[[1L]], as.name("="))) && is.name(e[[2L]])) {
                 v <- get0(as.character(e[[2L]]), envir = ns, inherits = FALSE)
                 if ((is.atomic(v) || is.list(v)) && setequal(names(v), per)) noms <- c(noms, as.character(e[[2L]]))
               }
             }
             if (length(noms)) paste0(basename(f), ":", unique(noms)) else NULL
           }))
           identical(defs, "donnees.R:MOIS_PERIODE_COTISATION") &&
             identical(ns$MOIS_PERIODE_COTISATION, c(annuelle = 12L, semestrielle = 6L, trimestrielle = 3L, mensuelle = 1L)) &&
             !exists(".MOIS_PERIODICITE", envir = ns, inherits = FALSE) && !exists(".MOIS_PERIODE_COTISATION", envir = ns, inherits = FALSE)
         }))

section("D02a sous H : dates tenues pour inconnues lues par les familles (#90 ; spécification donnees v1.9, § 9.4)")
# Base construite, plan recommandees à A = 2025-12-31 ; D02a déclaré en H (deux référentiels, poste
# tous), témoin sous D02a conserver. Lecture de Kleene : un poste qui lit une date tenue pour
# inconnue est arrêté, sauf si une condition connue décide ; jamais lu comme une date absente.
d02a_h <- function(p, h = TRUE) {
  if (h) p$donnees$hypotheses <- c(p$donnees$hypotheses, hyp_x("D02a"))
  else p$donnees$exclusions <- rbind(p$donnees$exclusions, excl_x("D02a", "aucune"))
  p
}
# erreur interne gardée (tryCatch) : un poste qui lirait une date inconnue comme une date échoue
# à l'assertion qui attend son arrêt, jamais par l'arrêt du fichier
calc_90 <- function(b, h, p = p_c1) tryCatch(calculer_provisions(b, d02a_h(p, h), tid), error = identity)
arret_90 <- function(r, po) list(unique(r$provisions$motif_arret[r$provisions$poste == po]), id_arret_poste(r, po))
b90 <- list(
  # R10 : instruction de SIR5A antérieure à sa déclaration ; DOR5A ouvert, capital reconstitué
  r10 = { b <- base; b$sinistres$date_instruction[b$sinistres$id_sinistre == "SIR5A"] <- D("2024-08-01"); b },
  # R5 : AFR5A de fin antérieure à son début ; AFR5A2, même assuré, même contrat, couvre la survenance
  r5 = { b <- base; a2 <- b$affiliations[b$affiliations$id_affiliation == "AFR5A", ]; a2$id_affiliation <- "AFR5A2"
         a2$date_debut <- D("2024-01-01"); b$affiliations <- rbind(b$affiliations, a2)
         i <- b$affiliations$id_affiliation == "AFR5A"; b$affiliations$date_fin[i] <- D("2019-06-01")
         b$affiliations$date_saisie_fin[i] <- D("2020-02-01"); b$affiliations$motif_fin[i] <- "depart_entreprise"; b },
  # R2 : terme de CTI1 antérieur à son effet
  r2 = { b <- base; b$contrats$date_terme[b$contrats$id_contrat == "CTI1"] <- D("2023-12-31"); b },
  # R9 : sinistre deces SIRI3 de l'assuré ASI3 (CTI3), déclaré avant sa survenance (2025-06-01)
  r9 = { b <- base; s <- b$sinistres[1L, ]; s$id_sinistre <- "SIRI3"; s$id_assure <- "ASI3"; s$date_survenance <- D("2025-06-01")
         s$date_declaration <- D("2025-05-01"); s$date_instruction <- as.Date(NA); s$date_saisie <- D("2025-05-02")
         b$sinistres <- rbind(b$sinistres, s); b })
r90 <- lapply(b90, function(b) list(h = calc_90(b, TRUE), c = calc_90(b, FALSE)))
verifier("#90, R10, R5, R2, R9 sous H et sous conserver : chaque calcul aboutit (arrêt ou montant, jamais une erreur interne)",
         !any(vapply(unlist(r90, recursive = FALSE), inherits, logical(1L), "error")))
verifier_egal("#90, R10 sous H : instruction de SIR5A inconnue (jamais « non instruit ») : P1 arrêté (parametre_non_determine, DOR5A) ; sous conserver, P1 337 225,959101369779 calculé",
              list(arret_90(r90$r10$h, P1), egal_mixte(cel_x(r90$r10$c, P1)$montant, 337225.959101369779)),
              list(list("parametre_non_determine", "DOR5A"), TRUE))
verifier_egal("#90, R5 sous H : dates de AFR5A inconnues, AFR5A peut couvrir la survenance : P1 arrêté (affiliation_non_determinee, DOR5A) ; sous conserver, AFR5A2 seule couvre, P1 337 225,959101369779 calculé",
              list(arret_90(r90$r5$h, P1), egal_mixte(cel_x(r90$r5$c, P1)$montant, 337225.959101369779)),
              list(list("affiliation_non_determinee", "DOR5A"), TRUE))
verifier_egal("#90, R2 sous H : effet et terme de CTI1 inconnus : P3 arrêté (parametre_non_determine, CTI1) ; sous conserver, CTI1 hors de la population (terme au plus A), P3 1 229,553930931891",
              list(arret_90(r90$r2$h, P3), egal_mixte(cel_x(r90$r2$c, P3)$montant, 1229.553930931891)),
              list(list("parametre_non_determine", "CTI1"), TRUE))
verifier_egal("#90, R9 sous H : survenance de SIRI3 inconnue, sinistre de l'assuré de CTI3 peut-être survenu au plus A : P3 arrêté (parametre_non_determine, CTI3) ; sous conserver, CTI3 sort par le sinistre",
              list(arret_90(r90$r9$h, P3), unique(r90$r9$c$provisions$statut_calcul[r90$r9$c$provisions$poste == P3])),
              list(list("parametre_non_determine", "CTI3"), "calcule"))
# R13 : mise à jour EVX de DOR4 datée avant la survenance, saisie le 2025-04-01 ; dernière information
# valide précédente : EVY (mise à jour de SIR4, sans dossier, effet 2025-03-01, saisie 2025-03-02) ;
# critère sans_evenement (12 mois, seuil 2024-12-31) : sous H, DOR4 a un événement récent (date
# substituée), il passe de P2 à P1 ; sous conserver (date brute 2024-06-01), il reste en P2
ev_90 <- function(b, id, dossier, effet, saisie) {
  e <- b$evenements[b$evenements$id_evenement == "EVR4", ]
  e$id_evenement <- id; e$id_dossier <- dossier; e$type_evenement <- "mise_a_jour"; e$montant <- NA_real_
  e$date_effet <- D(effet); e$date_saisie <- D(saisie)
  b$evenements <- rbind(b$evenements, e)
  b
}
b_r13 <- ev_90(ev_90(base, "EVY", NA_character_, "2025-03-01", "2025-03-02"), "EVX", "DOR4", "2024-06-01", "2025-04-01")
p_se <- p_c1
p_se$postes$deces$capitaux_non_reclames$parametres$critere <- "sans_evenement"
p_se$postes$deces$capitaux_non_reclames$parametres$mois_sans_evenement <- 12L
r_r13 <- list(h = calc_90(b_r13, TRUE, p_se), c = calc_90(b_r13, FALSE, p_se))
v_r13 <- ns$vue_a_date(b_r13, A1, d02a_h(p_se, TRUE)$donnees, p_se$conventions)
verifier_egal("#90, R13 sous H : date de EVX substituée par la règle écrite (2025-03-01, EVY), non tenue pour inconnue ; DOR4 en P1 (hypothèse D02a) ; sous conserver, DOR4 en P2",
              list(format(ns$valeurs_vue(v_r13, "evenements", "date_effet")[v_r13$ctx$base$evenements$id_evenement == "EVX"]),
                   any(ns$dates_inconnues_vue(v_r13, "evenements", "date_effet")),
                   unlist(r_r13$h$dossiers[r_r13$h$dossiers$id_dossier == "DOR4", c("poste", "hypotheses_defaut")]),
                   r_r13$c$dossiers$poste[r_r13$c$dossiers$id_dossier == "DOR4"]),
              list("2025-03-01", FALSE, c(poste = P1, hypotheses_defaut = "D02a"), P2))
# C90-5 (garde du point 1 de #112, M661) : CTI1 rejeté par R2 (terme) sous H : la partie de fin du
# contrat n'est pas touchée (decide_fin) ; rejeté par R1 (fin saisie le 2024-02-01) : touchée ; la
# ligne entière porte D02a dans les deux cas
fin_ct <- Filter(function(q) q$table == "contrats", ns$parties_ligne())[[1L]]$colonnes
b_r1 <- base
i_r1 <- b_r1$contrats$id_contrat == "CTI1"
b_r1$contrats$date_fin[i_r1] <- D("2023-12-01")
b_r1$contrats$date_saisie_fin[i_r1] <- D("2024-02-01")
b_r1$contrats$motif_fin[i_r1] <- "resiliation_adherent"
s2_ct <- function(b, lues) {
  v <- ns$vue_a_date(b, A1, d02a_h(p_c1, TRUE)$donnees, p_c1$conventions)
  ns$hypotheses_vue_unites(v, "comptes_sociaux", P3, "risque_en_cours", 1L, list(ns$lecture_unites("contrats", "id_contrat", "CTI1",
                                                                                                    lues = lues)))
}
verifier_egal("C90-5 : D02a sous H sur CTI1 : R2, partie de fin non touchée (\"\"), ligne entière D02a ; R1, partie de fin touchée (D02a)",
              list(s2_ct(b90$r2, fin_ct), s2_ct(b90$r2, NULL), s2_ct(b_r1, fin_ct)), list("", "D02a", "D02a"))
# C90-5 de bout en bout (site decide_fin de calculer_risque_en_cours()) : CTI1 rejeté par R2
# (terme au 2023-12-31) sous H, date_fin connue au 2025-06-01, saisie le 2025-06-05 : la partie
# de fin n'est pas touchée, la sortie par la fin est établie sans hypothèse ; P3 1 229,553930931891
# (CTI1 hors du calcul, comme au cas (4.1) (f2)), approximation_numerique, aucune unité CTI1
b_c905 <- b90$r2
i_c905 <- b_c905$contrats$id_contrat == "CTI1"
b_c905$contrats$date_fin[i_c905] <- D("2025-06-01")
b_c905$contrats$date_saisie_fin[i_c905] <- D("2025-06-05")
b_c905$contrats$motif_fin[i_c905] <- "resiliation_adherent"
r_c905 <- calc_90(b_c905, TRUE)
verifier_egal("C90-5 de bout en bout : CTI1 rejeté par R2 sous H, date_fin 2025-06-01 connue (saisie 2025-06-05) : P3 1 229,553930931891, approximation_numerique ; aucune unité CTI1 dans les échéanciers",
              list(egal_mixte(cel_x(r_c905, P3)$montant, 1229.553930931891), cel_x(r_c905, P3)$statut_resultat,
                   sum(r_c905$echeanciers$cle %in% "CTI1")),
              list(TRUE, "approximation_numerique", 0L))
# Garde par colonnes de la sortie par un sinistre (#90, point 1 de #112 étendu) : sinistre SIRI3
# deces de ASI3 (CTI3), survenance 2025-06-01 connue, instruction au 2025-06-05 antérieure à la
# déclaration du 2025-06-10 (R10) : D02a sous H porte sur la déclaration et l'instruction, non
# lues pour établir la sortie ; P3 identique au cas D02a conserver, approximation_numerique, sans
# unité CTI3 (avant : 3 611,747 en jugement_expert, CTI3 unité nulle)
b_sir <- base
s_sir <- b_sir$sinistres[1L, ]
s_sir$id_sinistre <- "SIRI3"; s_sir$id_assure <- "ASI3"; s_sir$date_survenance <- D("2025-06-01")
s_sir$date_declaration <- D("2025-06-10"); s_sir$date_instruction <- D("2025-06-05"); s_sir$date_saisie <- D("2025-06-11")
b_sir$sinistres <- rbind(b_sir$sinistres, s_sir)
r_sir <- list(h = calc_90(b_sir, TRUE), c = calc_90(b_sir, FALSE))
verifier_egal("#90, sortie par un sinistre : SIRI3 rejeté par R10 sous H (survenance connue) : CTI3 sorti sans hypothèse ; P3 identique à D02a conserver, approximation_numerique ; aucune unité CTI3 dans les échéanciers ; D02a placé sur SIRI3",
              list(identical(cel_x(r_sir$h, P3), cel_x(r_sir$c, P3)), cel_x(r_sir$h, P3)$statut_resultat,
                   sum(r_sir$h$echeanciers$cle %in% "CTI3"),
                   r_sir$h$donnees$controles$identifiants[r_sir$h$donnees$controles$code == "D02a"]),
              list(TRUE, "approximation_numerique", 0L, "SIRI3"))
# voie de sortie observée (s_place) : SIRI3 comme ci-dessus et SIRI4 deces de ASI3 (survenance
# 2025-07-01) sans date de saisie, sous D03g (délai 0, visible) : SIRI3, dont D02a ne porte sur
# aucune colonne lue, établit la sortie sans hypothèse ; CTI3 non restitué, P3 identique au cas
# D02a conserver (sans la garde sur s_place : CTI3 restitué à 0, jugement_expert)
b_sir2 <- b_sir
s_sir2 <- s_sir
s_sir2$id_sinistre <- "SIRI4"; s_sir2$date_survenance <- D("2025-07-01"); s_sir2$date_declaration <- D("2025-07-10")
s_sir2$date_instruction <- D("2025-07-20"); s_sir2$date_saisie <- as.Date(NA)
b_sir2$sinistres <- rbind(b_sir2$sinistres, s_sir2)
p_sir2 <- p_c1
p_sir2$donnees$hypotheses <- c(p_sir2$donnees$hypotheses, hyp_x("D03g"))
p_sir2$donnees$seuils$d03g_delai_jours <- list(sinistres = 0)
r_sir2 <- list(h = calc_90(b_sir2, TRUE, p_sir2), c = calc_90(b_sir2, FALSE, p_sir2))
verifier_egal("#90, sortie observée : SIRI3 (R10 sous H) et SIRI4 sous D03g, visible : CTI3 sorti par SIRI3 sans hypothèse ; P3 identique à D02a conserver ; aucune unité CTI3 dans les échéanciers",
              list(identical(cel_x(r_sir2$h, P3), cel_x(r_sir2$c, P3)), sum(r_sir2$h$echeanciers$cle %in% "CTI3")),
              list(TRUE, 0L))
# R13, candidats de la dernière information valide précédente (dictionnaire 1.6, § 4 : « la date
# de dernière information d'un dossier se reconstitue de ces dates ») : contre-témoin, EVX de
# DOR4 (effet 2024-06-01, saisie 2025-04-01) ; EVW, mise à jour antérieure de DOR4B, autre
# dossier de SIR4 (garantie GSC2, collège cadres), et EVD, demande_mise_a_jour antérieure de
# DOR4, ne sont pas candidates : repli sur l'instruction de SIR4 (2024-09-10) ; témoin : EVW
# rattachée à DOR4 est candidate (2025-03-01)
b_ct13 <- base
g_ct13 <- b_ct13$garanties_souscrites[b_ct13$garanties_souscrites$id_garantie_souscrite == "GSC1", ]
g_ct13$id_garantie_souscrite <- "GSC2"; g_ct13$college <- "cadres"
b_ct13$garanties_souscrites <- rbind(b_ct13$garanties_souscrites, g_ct13)
d_ct13 <- b_ct13$dossiers[b_ct13$dossiers$id_dossier == "DOR4", ]
d_ct13$id_dossier <- "DOR4B"; d_ct13$id_garantie_souscrite <- "GSC2"
b_ct13$dossiers <- rbind(b_ct13$dossiers, d_ct13)
b_ct13 <- ev_90(ev_90(b_ct13, "EVW", "DOR4B", "2025-03-01", "2025-03-02"), "EVD", "DOR4", "2025-03-10", "2025-03-11")
b_ct13$evenements$type_evenement[b_ct13$evenements$id_evenement == "EVD"] <- "demande_mise_a_jour"
b_ct13 <- ev_90(b_ct13, "EVX", "DOR4", "2024-06-01", "2025-04-01")
b_te13 <- ev_90(ev_90(base, "EVW", "DOR4", "2025-03-01", "2025-03-02"), "EVX", "DOR4", "2024-06-01", "2025-04-01")
effet_evx <- function(b) {
  v <- ns$vue_a_date(b, A1, d02a_h(p_c1, TRUE)$donnees, p_c1$conventions)
  e <- v$ctx$base$evenements$id_evenement == "EVX"
  list(format(ns$valeurs_vue(v, "evenements", "date_effet")[e]), ns$dates_inconnues_vue(v, "evenements", "date_effet")[e])
}
verifier_egal("#90, R13 contre-témoin : mise à jour d'un autre dossier du sinistre et demande_mise_a_jour du même dossier non candidates : EVX substituée par l'instruction de SIR4 (2024-09-10) ; témoin, mise à jour du même dossier : 2025-03-01",
              list(effet_evx(b_ct13), effet_evx(b_te13)), list(list("2024-09-10", FALSE), list("2025-03-01", FALSE)))
# R13, mise à jour de niveau sinistre (erratum 1.9.3, point (i), spécification `donnees` v1.9,
# § 9.4) : EVX sans dossier (effet 2024-06-01, saisie 2025-04-01), rejetée par R13 sous H ; EVW,
# mise à jour antérieure de DOR4 (effet 2025-03-01, saisie 2025-03-02), n'est pas candidate pour
# une mise à jour de niveau sinistre (seules les mises à jour de niveau sinistre le sont) : repli
# sur l'instruction de SIR4 (2024-09-10), non la date de EVW
b_si13 <- ev_90(ev_90(base, "EVW", "DOR4", "2025-03-01", "2025-03-02"), "EVX", NA_character_, "2024-06-01", "2025-04-01")
verifier_egal("#90, R13, mise à jour EVX de niveau sinistre rejetée sous H, mise à jour EVW de DOR4 saisie avant elle : EVX substituée par l'instruction de SIR4 (2024-09-10), non par EVW (2025-03-01)",
              effet_evx(b_si13), list("2024-09-10", FALSE))
# R13 sans valeur substituée, dossier clos (garde de Kleene du critère sans_evenement de P2) :
# SIR4 déclaré avant sa survenance (R9 : survenance et déclaration inconnues), instruction
# manquante ; DOR4 clos le 2024-12-01 (sans_suite) ; EVX de DOR4 (effet 2024-05-01, avant la
# survenance brute, saisie 2025-02-01) sans candidate : date restée inconnue, peut-être récente ;
# DOR4 sans événement récent connu, ouvert avant le seuil (2024-12-31) : partition non
# déterminée, P1 et P2 arrêtés (parametre_non_determine, DOR4), jamais DOR4 clos en P2 à 0
b_k13 <- base
i_k13 <- b_k13$sinistres$id_sinistre == "SIR4"
b_k13$sinistres$date_declaration[i_k13] <- D("2024-06-01")
b_k13$sinistres$date_instruction[i_k13] <- as.Date(NA)
b_k13 <- ev_90(b_k13, "EVC", "DOR4", "2024-12-01", "2024-12-02")
b_k13$evenements$type_evenement[b_k13$evenements$id_evenement == "EVC"] <- "cloture_dossier"
b_k13$evenements$motif[b_k13$evenements$id_evenement == "EVC"] <- "sans_suite"
b_k13 <- ev_90(b_k13, "EVX", "DOR4", "2024-05-01", "2025-02-01")
r_k13 <- calc_90(b_k13, TRUE, p_se)
verifier_egal("#90, R13 sans valeur substituée, DOR4 clos, critère sans_evenement : EVX inconnue ; P1 et P2 arrêtés (parametre_non_determine, DOR4) ; P3 calculé",
              list(effet_evx(b_k13)[[2L]], arret_90(r_k13, P1), arret_90(r_k13, P2), unique(r_k13$provisions$statut_calcul[r_k13$provisions$poste == P3])),
              list(TRUE, list("parametre_non_determine", "DOR4"), list("parametre_non_determine", "DOR4"), "calcule"))
# Garde du point 1 de #112 (M661) : les hypothèses de la vue D02b et D03g placées sur contrats
# portent la seule colonne date_saisie_fin (partie de fin du contrat) ; CTI1 : date_fin
# 2025-06-01 sans date de saisie (D03g) ; CTI3 : date_fin 2025-06-01 saisie le 2023-06-01, avant
# l'effet (D02b) ; D02b et D03g en H, délai D03g de contrats 0
b_g112 <- base
for (k in c("CTI1", "CTI3")) {
  i_g <- b_g112$contrats$id_contrat == k
  b_g112$contrats$date_fin[i_g] <- D("2025-06-01")
  b_g112$contrats$motif_fin[i_g] <- "resiliation_adherent"
  b_g112$contrats$date_saisie_fin[i_g] <- if (k == "CTI1") as.Date(NA) else D("2023-06-01")
}
d_g112 <- p_c1$donnees
d_g112$hypotheses <- c(d_g112$hypotheses, hyp_x("D02b"), hyp_x("D03g"))
d_g112$seuils$d03g_delai_jours <- list(contrats = 0)
h_g112 <- Filter(function(h) identical(h$table, "contrats") && h$motif %in% c("D02b", "D03g"),
                 ns$vue_a_date(b_g112, A1, d_g112, p_c1$conventions)$hypotheses)
verifier_egal("garde du point 1 de #112 : hypothèses de la vue D02b et D03g sur contrats (deux référentiels chacune) : colonnes = date_saisie_fin",
              list(sort(vapply(h_g112, `[[`, "", "motif"), method = "radix"), unique(lapply(h_g112, `[[`, "colonnes"))),
              list(c("D02b", "D02b", "D03g", "D03g"), list("date_saisie_fin")))

section("extrapolation de mortalite_tarif sous derniere_valeur : statut et trace (critère (4.8), § 5.8, S3, #91)")
# Cas T8 du § 7.4 de bout en bout : base de P3 (b2_base_p3()) avec date_terme de CT2 au
# 2028-01-01, A = 2025-01-01, plan b2_plan() complété de la section donnees du plan
# recommandees de la base construite ; valeurs mesurées le 12/11/2026 (avant #91 : P3
# 7 473,9357625788 exact, trois lignes d'indicateurs).
A_t8 <- D("2025-01-01")
b_t8 <- b2_base_p3()
b_t8$contrats$date_terme[1L] <- D("2028-01-01")
plan_t8 <- function(hors) {
  p <- b2_plan(tb, A_t8)
  p$donnees <- b2_plan_reference("recommandees", A_t8, tb)$donnees
  p$tables$mortalite_tarif$hors_axes <- hors
  p
}
cel_t8 <- function(r) r$provisions[r$provisions$poste == "provision_mathematique_temporaire_deces" &
                                     r$provisions$segmentation == "ensemble", , drop = FALSE]
r_t8 <- calculer_provisions(b_t8, plan_t8("derniere_valeur"), tid)
verifier_egal("(4.8) T8 (b) de bout en bout : P3 7 473,9357625788, jugement_expert (avant : exact) ; indicateurs tarif_vie, A132_1, A132_1, puis la ligne hors_axes_derniere_valeur (valeur_retenue 1, depassement TRUE, valeurs=43)",
              list(cel_t8(r_t8)$montant, cel_t8(r_t8)$statut_resultat, r_t8$indicateurs$regle,
                   r_t8$indicateurs$valeur_retenue[4L], r_t8$indicateurs$depassement[4L], r_t8$indicateurs$detail[4L]),
              list(7473.9357625788, "jugement_expert", c("tarif_vie", "A132_1", "A132_1", "hors_axes_derniere_valeur"), 1, TRUE,
                   "usage=mortalite_tarif;identifiant=mortalite_fictive_b2;id_contrat=CT2;axe=age;valeurs=43"), tolerance = EPS)
verifier_egal("(4.8) T8 (a) de bout en bout, hors_axes = refus : P3 arrêté (hors_axes), aucune ligne hors_axes_derniere_valeur ; (c) témoin T1 sous derniere_valeur : 4 786,6205305652 exact, aucune ligne",
              { r_a <- calculer_provisions(b_t8, plan_t8("refus"), tid)
                r_c <- calculer_provisions(b2_base_p3(), plan_t8("derniere_valeur"), tid)
                list(cel_t8(r_a)$statut_calcul, cel_t8(r_a)$motif_arret, sum(r_a$indicateurs$regle == "hors_axes_derniere_valeur"),
                     cel_t8(r_c)$montant, cel_t8(r_c)$statut_resultat, sum(r_c$indicateurs$regle == "hors_axes_derniere_valeur")) },
              list("arrete", "hors_axes", 0L, 4786.6205305652, "exact", 0L), tolerance = EPS)
verifier("(4.8) une seule implémentation : la chaîne hors_axes_derniere_valeur n'apparaît qu'une fois dans le code de R/ (hors commentaires), dans indicateur_hors_axes(), définie une fois, dans R/tables.R, et appelée par provisions_individuelles()",
         local({
           fichiers <- list.files(file.path(racine, "R"), pattern = "\\.R$", full.names = TRUE)
           chaines <- unlist(lapply(fichiers, function(f) {
             d <- utils::getParseData(parse(f, keep.source = TRUE, encoding = "UTF-8"))
             s <- d$text[d$token == "STR_CONST"]
             rep(basename(f), sum(s %in% c("\"hors_axes_derniere_valeur\"", "'hors_axes_derniere_valeur'")))
           }))
           defs <- unlist(lapply(fichiers, function(f) {
             if (any(grepl("^indicateur_hors_axes <- function", readLines(f, warn = FALSE)))) basename(f) else NULL
           }))
           dans <- function(f, x) grepl(x, paste(deparse(f), collapse = "\n"), fixed = TRUE)
           identical(chaines, "tables.R") && identical(defs, "tables.R") &&
             dans(ns$indicateur_hors_axes, "\"hors_axes_derniere_valeur\"") &&
             dans(ns$provisions_individuelles, "indicateur_hors_axes(")
         }))

section("#83 : D10b à l'arrêté, exception de la règle 1 (critère (4.4), § 5.3 ; spécification `donnees` v1.9, § 9.3, C83-1 et C83-2)")
b_ge <- base   # GSC1 : effet postérieur à l'arrêté, invisible à A ; ses dossiers restent dans la vue (exception de la règle 1)
b_ge$garanties_souscrites$date_effet[1L] <- D("2026-03-01")
# C83-1 : l'échec attendu de #83 (T6, § 9.8) passe, marque retirée
verifier("C83-1, (4.4) GSC1 d'effet au 2026-03-01, A = 2025-12-31, sans déclaration : D10b signalé et exigé (declarations_requises), refus declaration_manquante",
         local({
           v <- b2_vue(b_ge, A1, p_c1$donnees, p_c1$conventions)
           any(v$bilan$signalements$code == "D10b") && any(v$bilan$declarations_requises$motif == "D10b") &&
             identical(motif_de(calculer_provisions(b_ge, p_c1, tid)), "declaration_manquante")
         }))
# C83-2 : sous conserver, P1 et P2 (qui lisent les colonnes de la garantie) arrêtés
# parametre_non_determine, premier dossier en cause DOR1, jamais calculés sur la version invisible
# (avant #83 : P1 = P2 = 0, dossiers sortis de la vue en silence) ; P3 inchangé ; sous exclure
# pour engagement, dossiers exclus (P1 = P2 = 0), enjeu de D10b sur les cinq dossiers
plan_d10b <- function(actions, a = A1, base_plan = p_c1) {
  p <- base_plan
  p$arrete <- a
  p$donnees$exclusions <- c(p$donnees$exclusions, lapply(seq_along(actions), function(i) {
    list(motif = names(actions)[i], famille = ns$FAMILLES_CALCUL[(i - 1L) %% 4L + 1L], action = actions[[i]])
  }))
  p
}
d10b <- function(...) stats::setNames(list(...), rep("D10b", length(list(...))))
cel_83 <- function(r) {
  x <- r$provisions[r$provisions$segmentation == "ensemble", , drop = FALSE]
  pr <- r$fiche$parametres_retenus$postes
  ida <- vapply(x$poste, function(po) {
    if (po == "total") return("-")
    i <- ns$lire_liste(charToRaw(pr$parametres[pr$poste == po]))$identifiant_arret
    if (is.null(i)) "-" else i
  }, "", USE.NAMES = FALSE)
  paste(x$poste, x$statut_calcul, x$motif_arret, ida)
}
r_83c <- calculer_provisions(b_ge, plan_d10b(d10b("conserver", "conserver", "conserver", "conserver")), tid)
r_83x <- calculer_provisions(b_ge, plan_d10b(d10b("exclure", "conserver", "conserver", "conserver")), tid)
verifier_egal("C83-2, conserver : P1 et P2 arrêtés parametre_non_determine (identifiant DOR1), total arrêté ; P3 calculé, 3 710,67098199391 (inchangé)",
              list(cel_83(r_83c), r_83c$provisions$montant[r_83c$provisions$poste == P3 & r_83c$provisions$segmentation == "ensemble"]),
              list(c("capitaux_non_reclames arrete parametre_non_determine DOR1",
                     paste("provision_mathematique_temporaire_deces calcule NA -"),
                     "sinistres_declares_non_regles arrete parametre_non_determine DOR1",
                     "total arrete poste_arrete:capitaux_non_reclames;sinistres_declares_non_regles -"), 3710.67098199391),
              tolerance = EPS)
verifier_egal("C83-2, exclure pour engagement : P1 = P2 = 0 calculés, aucun dossier ; exclusion D10b (engagement, exclure) de cinq lignes et cinq dossiers ; enjeu D10b de engagement non nul sur les cinq dossiers (capital_fixe 300 000, ensemble)",
              { pv <- r_83x$provisions[r_83x$provisions$segmentation == "ensemble", ]
                ex <- r_83x$donnees$exclusions
                en <- r_83x$donnees$enjeu
                en <- en[en$motif == "D10b" & en$famille == "engagement" & en$poste == "ensemble" & en$garantie == "ensemble" &
                           en$composante == "capital_fixe", ]
                list(pv$montant[pv$poste %in% c("sinistres_declares_non_regles", "capitaux_non_reclames")],
                     pv$statut_calcul[pv$poste %in% c("sinistres_declares_non_regles", "capitaux_non_reclames")], nrow(r_83x$dossiers),
                     with(ex[ex$motif == "D10b" & ex$famille == "engagement", ], paste(action, nombre_lignes, nombre_dossiers)),
                     en$montant, en$nombre_dossiers) },
              list(c(0, 0), c("calcule", "calcule"), 0L, "exclure 5 5", 3e5, 5L), tolerance = 0)
# C83-12 (spécification `donnees` v1.9, § 4.2, note v1.9.2, et § 9.3, bloc « Erratum 1.9.2 »,
# (iv)) : axe garantie de l'enjeu d'un dossier dont la garantie souscrite n'est pas retenue, lu
# sur la version extraite (GSC1, deces) : rangée deces de l'enjeu D10b (engagement, ensemble)
verifier_egal("C83-12, exclure pour engagement : enjeu D10b de engagement, rangée deces (poste ensemble) : paiements_cumules 40 000, capital_fixe 300 000, cinq dossiers, cause NA",
              { en <- r_83x$donnees$enjeu
                en <- en[en$motif == "D10b" & en$famille == "engagement" & en$poste == "ensemble" & en$garantie == "deces" &
                           en$composante %in% c("paiements_cumules", "capital_fixe"), ]
                list(en$composante, en$montant, en$nombre_dossiers, en$cause) },
              list(c("paiements_cumules", "capital_fixe"), c(4e4, 3e5), c(5L, 5L), c(NA_character_, NA_character_)), tolerance = 0)
detecte_d10b <- function(b, a) {
  v <- b2_vue(b, a, p_c1$donnees, p_c1$conventions)
  s <- v$bilan$signalements[v$bilan$signalements$code == "D10b", ]
  nrow(s) == 1L && s$identifiants == "DOR1;DOR3;DOR4;DOR5A;DOR5B" &&
    setequal(v$bilan$declarations_requises$cle[v$bilan$declarations_requises$motif == "D10b"], ns$FAMILLES_CALCUL)
}
b_ge2 <- base
b_ge2$garanties_souscrites$date_effet[1L] <- D("2025-01-01")
verifier("(4.4) témoins : D10b détecté (signalement, 5 dossiers DOR1;DOR3;DOR4;DOR5A;DOR5B ; exclusion exigée pour chaque famille) pour GSC1 d'effet au 2026-03-01 à A = 2026-03-31, et d'effet au 2025-01-01 à A = 2025-12-31",
         detecte_d10b(b_ge, D("2026-03-31")) && detecte_d10b(b_ge2, A1))
# Aucun poste calculé sur une garantie invisible ou inconnue sans arrêt ni signalement, aucune
# erreur interne (§ 9.3 (1) et (2)) : CTC1 d'effet au 2026-03-01 (GSC1, d'effet au 2020-01-01,
# masquée par son contrat ; D10b non détecté) ; D11a (sinistres hors couverture) déclaré : sous
# conserver, P1 et P2 arrêtés parametre_non_determine (DOR1 ; avant #83 : 0, en silence),
# parente_posterieure sur garanties_souscrites, affiliations et cotisations ; sous exclure de D11a
# pour engagement, sinistres exclus (cascade aux dossiers), P1 = P2 = 0
b_ct <- base
b_ct$contrats$date_effet[b_ct$contrats$id_contrat == "CTC1"] <- D("2026-03-01")
d11a <- function(...) stats::setNames(list(...), rep("D11a", length(list(...))))
r_ct <- lapply(list(conserver = d11a("conserver", "conserver", "conserver", "conserver"),
                    exclure = d11a("exclure", "conserver", "conserver", "conserver")),
               function(x) calculer_provisions(b_ct, plan_d10b(x), tid))
verifier_egal("#83, contrat d'effet postérieur à A : sous conserver (D11a), P1 et P2 arrêtés parametre_non_determine (DOR1), parente_posterieure sur GSC1, AFR1;AFR3;AFR4;AFR5A;AFR5B et COC1;COC2 ; sous exclure (D11a, engagement), P1 et P2 calculés",
              list(cel_83(r_ct$conserver)[c(1L, 3L)],
                   with(r_ct$conserver$donnees$controles[r_ct$conserver$donnees$controles$code == "parente_posterieure", ], paste(table, identifiants)),
                   cel_83(r_ct$exclure)[c(1L, 3L)], motif_de(calculer_provisions(b_ct, p_c1, tid))),
              list(c("capitaux_non_reclames arrete parametre_non_determine DOR1", "sinistres_declares_non_regles arrete parametre_non_determine DOR1"),
                   c("garanties_souscrites GSC1", "affiliations AFR1;AFR3;AFR4;AFR5A;AFR5B", "cotisations COC1;COC2"),
                   c("capitaux_non_reclames calcule NA -", "sinistres_declares_non_regles calcule NA -"), "declaration_manquante"))
# Garantie de date d'effet manquante (D03i, inconnue) : ses dossiers restent dans la vue
# (exception) ; sous conserver de D03i, arrêt D03i (M703, M704) ; sous exclure de D03i pour
# engagement, la garantie exclue sort ses dossiers de la population (couverture exclue étendue
# aux lignes non retenues, dossiers_garantie_invisible()) : P1 = P2 = 0, comme avant #83
b_gi <- base
b_gi$garanties_souscrites$date_effet[1L] <- as.Date(NA)
d03i <- function(...) stats::setNames(list(...), rep("D03i", length(list(...))))
r_gi_x <- calculer_provisions(b_gi, plan_d10b(d03i("exclure", "conserver", "conserver", "conserver")), tid)
# C83-8 : enjeu des composantes 1 et 2 de D03i (engagement, ensemble) NA, cause
# visibilite_non_determinee (garantie de visibilité non déterminée : rattachement non déterminé)
verifier_egal("C83-8, #83, GSC1 d'effet manquant (D03i) à A : sous conserver, P1 et P2 arrêtés D03i ; sous exclure pour engagement, P1 et P2 calculés (0), sans arrêt parametre_non_determine ; enjeu D03i (engagement, ensemble, ensemble) de paiements_cumules et capital_fixe NA, cause visibilite_non_determinee",
              list(cel_83(calculer_provisions(b_gi, plan_d10b(d03i("conserver", "conserver", "conserver", "conserver")), tid))[c(1L, 3L)],
                   cel_83(r_gi_x)[c(1L, 3L)],
                   { en <- r_gi_x$donnees$enjeu
                     en <- en[en$motif == "D03i" & en$famille == "engagement" & en$poste == "ensemble" & en$garantie == "ensemble" &
                                en$composante %in% c("paiements_cumules", "capital_fixe"), ]
                     list(en$composante, en$montant, en$cause) }),
              list(c("capitaux_non_reclames arrete D03i -", "sinistres_declares_non_regles arrete D03i -"),
                   c("capitaux_non_reclames calcule NA -", "sinistres_declares_non_regles calcule NA -"),
                   list(c("paiements_cumules", "capital_fixe"), c(NA_real_, NA_real_),
                        c("visibilite_non_determinee", "visibilite_non_determinee"))))
# À l'arrêté égal à l'extraction (vue totale) : GSC1 visible, D10b détecté, aucun
# parente_posterieure ; sous conserver, P1 et P2 calculés sur la version extraite ; sous exclure,
# 0 ; sans déclaration, declaration_manquante (taux de revalorisation 2026 ajouté au plan)
p_ext <- p_c1
p_ext$revalorisation$capital_deces$taux_par_annee[["2026"]] <- p_ext$revalorisation$capital_deces$taux_par_annee[["2025"]]
E_ge <- D("2026-03-31")
r_ext <- lapply(list(conserver = d10b("conserver", "conserver", "conserver", "conserver"),
                     exclure = d10b("exclure", "exclure", "exclure", "exclure")),
                function(x) calculer_provisions(b_ge, plan_d10b(x, E_ge, p_ext), tid))
verifier_egal("#83, A = extraction : aucun parente_posterieure ; conserver : P1 et P2 calculés (339 221,59765386011 et 104 551,07331506848) ; exclure : 0 ; sans déclaration : declaration_manquante",
              list(vapply(r_ext, function(r) sum(r$donnees$controles$code == "parente_posterieure"), 0L),
                   r_ext$conserver$provisions$montant[r_ext$conserver$provisions$segmentation == "ensemble" &
                                                        r_ext$conserver$provisions$poste %in% c("sinistres_declares_non_regles", "capitaux_non_reclames")],
                   r_ext$exclure$provisions$montant[r_ext$exclure$provisions$segmentation == "ensemble" &
                                                      r_ext$exclure$provisions$poste %in% c("sinistres_declares_non_regles", "capitaux_non_reclames")],
                   motif_de(calculer_provisions(b_ge, plan_d10b(list(), E_ge, p_ext), tid))),
              list(c(conserver = 0L, exclure = 0L), c(104551.07331506848, 339221.59765386011), c(0, 0), "declaration_manquante"),
              tolerance = EPS)

section("somme des montants (.somme_montants(), garde interne)")
verifier("(.somme_montants) un montant NA est une erreur interne ; sans NA, somme ordonnée (2 + 1 = 3)",
         startsWith(motif_de(ns$.somme_montants(c(1, NA))), "autre : erreur interne de provie") &&
           identical(ns$.somme_montants(c(2, 1)), 3))

section("empreinte du code : constantes, fonctions, environnements exclus, en-tête (critères (4.2) et (4.3))")
e0 <- ns$empreinte_code()
modifier_ns <- function(nom, valeur) {
  unlockBinding(nom, ns)
  assign(nom, valeur, envir = ns)
  lockBinding(nom, ns)
}
plafond <- get(".PLAFOND_A132_1_AUTRE", envir = ns)
modifier_ns(".PLAFOND_A132_1_AUTRE", 0.99)
e_const <- ns$empreinte_code()
modifier_ns(".PLAFOND_A132_1_AUTRE", plafond)
e_const_retablie <- ns$empreinte_code()
f_orig <- get(".somme_montants", envir = ns)
f_mod <- f_orig
body(f_mod) <- quote(sum(x))
modifier_ns(".somme_montants", f_mod)
e_fct <- ns$empreinte_code()
modifier_ns(".somme_montants", f_orig)
e_fct_retablie <- ns$empreinte_code()
verifier("(4.2) une constante modifiée (.PLAFOND_A132_1_AUTRE = 0,99) change l'empreinte, rétablie elle redonne l'initiale ; même critère pour le corps d'une fonction (.somme_montants)",
         e_const != e0 && identical(e_const_retablie, e0) && e_fct != e0 && identical(e_fct_retablie, e0))
verifier("(4.2) .__NAMESPACE__. et .__S3MethodsTable__. hors de la liste sérialisée (.HORS_EMPREINTE_CODE) ; seuls environnements de l'espace de noms",
         identical(ns$.HORS_EMPREINTE_CODE, c(".__NAMESPACE__.", ".__S3MethodsTable__.")) &&
           setequal(Filter(function(n) is.environment(get(n, envir = ns)), ls(ns, all.names = TRUE)), ns$.HORS_EMPREINTE_CODE))
verifier("(4.3) octets 7 à 10 de serialize(version = 2L) : 00, majeur, mineur, correctif de la version de R",
         identical(serialize(list(), NULL, version = 2L)[7:10],
                   as.raw(c(0L, as.integer(R.version$major), as.integer(strsplit(R.version$minor, ".", fixed = TRUE)[[1L]])))))
