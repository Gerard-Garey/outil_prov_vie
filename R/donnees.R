# Module `donnees` (ADR 0010, points 1, 9, 11, 14 et 17 ; annotations des cinquième à
# septième séries) : contrôle de la base entière et vue à une date, sous la spécification
# visée docs/specifications/module-donnees-v1.md (M151) et le dictionnaire 1.5.
# N'appelle que les modules `dictionnaire` et `outils` (graphe du point 1), et seulement
# leurs fonctions sans point. Ne modifie jamais une donnée : chaque anomalie est enregistrée
# au bilan avec son traitement (refus R, exclusion X, hypothèse par défaut H, signalement S).
# Ne parle pas (point 12). Code ASCII hors commentaires (M112).
# Convention de ce fichier : une fonction dont le nom commence par un point est un
# auxiliaire du module ; la concordance documentation <-> code ne recense que les autres.
#
# Ordre d'exécution (spécification, § 2.2) : interruptions (refus d'appel), forme, domaine,
# clés (orphelines D04a et D04b comprises, quel que soit leur traitement) et refus induits
# (règle B, indépendante de l'arrêté) ; puis détection de D02b et D03g (règle P), vue,
# règle V et enjeu. Les règles P et V et la vue ne lisent ni une table ni une colonne
# refusées en règle B (.refus_regle_b()).
# État de ce fichier (#18 fermée avec un report déclaré, #34 ; M181) : interruptions, règle
# B dont les orphelines traitées X (D04a, D04b), règle P (D02b, D03g), vue à une date
# (visibilité non déterminée ; hypothèse déclarée de D02b, hypothèse ou exclusion déclarée
# de D03g appliquées), en règle V
# somme_parts, D01b, D02a, D02c (âge), D03a à D03c, D03e, D03f, D03h, D05, D06, D07 (a) à (c),
# D08, D10 (b) à (f), D11 (a) à (c), D12, D13, D14 ;
# placement de chaque constat selon les déclarations (exclusions, hypotheses_defaut,
# declarations_requises), enjeu (COMPOSANTES_ENJEU), nombre_visibles et nombre_dossiers.
# L'état partiel est porté par l'objet rendu : chaque contrôle prévu par la spécification et
# reporté (CONTROLES_NON_IMPLEMENTES : report déclaré à la fermeture de #18) figure dans
# controles_non_executes avec la cause `non_implemente` ; un sous-cas que la base ne permet
# pas de lire, avec la cause `non_lisible` (CAUSE_NON_LISIBLE). Contrôles reportés : D03d (B4,
# #116) et D09 aux seuils. D09 aux seuils reste `non_implemente` (M336, #115) :
# aucun de ses seuils n'est attendu dans declarations_requises ; le seuil de D07 (b),
# d07b_mois, l'est (SEUIL_MOIS_D07B).

# --- Constantes ------------------------------------------------------------------

# Familles de calcul d'une exclusion déclarée (dictionnaire, § 1.10) et référentiels d'une
# hypothèse par défaut.
FAMILLES_CALCUL <- c("engagement", "triangle", "risque_en_cours", "regle_comptable")
REFERENTIELS <- c("comptes_sociaux", "solvabilite_2")
# Actions d'une exclusion déclarée (ADR 0010, point 17) ; `non_declaree` : enjeu d'un motif X
# sans déclaration (M152), jamais dans `exclusions` ; `refus` : enjeu d'un refus R.
ACTIONS_EXCLUSION <- c("exclure", "conserver")
# Valeur réservée d'une ligne de `hypotheses` qui déclare le signalement (S) d'un constat à
# choix pour un référentiel, symétrique de `conserver` (décision du mainteneur, D4 ; ADR
# 0010, neuvième série) : le constat va dans `signalements`.
.VALEUR_SIGNALEMENT <- "signalement"
# Seuil du délai de D03g (décision du mainteneur, D5 ; nom provisoire) : liste nommée par
# table de `seuils`, en jours, sans valeur par défaut, commune aux deux référentiels. Sans
# point : lue aussi par `plan` (ADR 0010, quatrième série, (c)).
SEUIL_DELAI_D03G <- "d03g_delai_jours"
# Bornes de vraisemblance de l'âge de D02c (spécification, § 5.4 ; ADR 0010, neuvième série) :
# deux listes nommées par emploi de `seuils`, en années entières, sans valeur par défaut ;
# table de la personne de chaque emploi. Sans point : lue aussi par `plan`.
SEUILS_AGE_D02C <- c("d02c_age_min", "d02c_age_max")
# Nombre de mois de D07 (b), extinction présumée (spécification `donnees` v1.6, § 8.2) : entier
# au moins égal à 1, sans valeur par défaut, commun aux deux référentiels. Sans point : lue aussi
# par `plan`.
SEUIL_MOIS_D07B <- "d07b_mois"
# Plafond technique de d07b_mois, limite de calcul et non jugement d'expert : ajouter_mois()
# compte les mois en entiers de R (12 x année + mois - 1 + k) ; au-delà de ce plafond, une date
# de l'année 9999 (sentinelle 9999-12-31, borne du domaine des dates) déborde (NA). Mesuré :
# ajouter_mois(as.Date("9999-12-31"), k) rend une date pour k = .MOIS_D07B_MAX, NA (débordement
# d'entier) pour k = .MOIS_D07B_MAX + 1.
.MOIS_D07B_MAX <- .Machine$integer.max - (12L * 9999L + 11L)
.EMPLOIS_D02C <- c(assures_sinistre = "assures", assures_affiliation = "assures", famille = "famille",
                   designations = "designations", ayants_droit_sante = "ayants_droit_sante")
# Âge non défini (date de référence antérieure à la naissance, spécification, § 5.2) : le
# sous-cas D02c (âge) de la table va dans controles_non_executes sous cette cause.
.CAUSE_AGE_NON_DEFINI <- "age_non_defini"
# Limite d'âge non déterminable pour une ligne candidate de D07 (c) (paramètre age_limite, ou
# age_limite_etudes d'un enfant qui y a droit, absent ou à plusieurs valeurs ; avis
# d'`actuary`, Q3 (a)) : le sous-cas de la table va dans controles_non_executes.
.CAUSE_PARAMETRE_NON_DEFINI <- "parametre_non_defini"

# Composantes de l'enjeu (spécification, § 4.3, liste fermée, M151) : huit composantes, dix
# couples (composante, unite) ; aucune agrégation ne mêle deux couples.
COMPOSANTES_ENJEU <- data.frame(
  composante = c("paiements_cumules", "capital_fixe", "rente_annuelle_en_vigueur", "ij_en_vigueur",
                 "prestations_ecartees", "cotisations_emises_nettes", "cotisations_encaissees",
                 "montant_evenement", "montant_evenement", "montant_evenement"),
  unite = c("euro", "euro", "euro_par_an", "euro_par_jour", "euro", "euro", "euro", "euro", "euro_par_an",
            "euro_par_jour"),
  definition = c(
    "somme sign\u00e9e des montants des prestations du dossier visibles \u00e0 l'arr\u00eat\u00e9",
    "montant du dernier fixation_capital connu \u00e0 l'arr\u00eat\u00e9 (dossier deces ou double_effet)",
    paste0("somme, sur les rentes du dossier, du montant du dernier ouverture_service ou modification_montant de la ",
           "rente, si, parmi ses \u00e9v\u00e9nements de service et de fin_service de date d'effet <= A connus \u00e0 A, ",
           "le dernier dans l'ordre du \u00a7 4.2 est un service ; sans valeur sinon (une r\u00e9ouverture apr\u00e8s ",
           "fin_service rallume la rente)"),
    paste0("Montant du dernier ouverture_service ou modification_montant du dossier incapacite, si, parmi ses ",
           "\u00e9v\u00e9nements de service et d'extinction (fin_service du dossier, sortie du sinistre) de date ",
           "d'effet <= A connus \u00e0 A, le dernier dans l'ordre du \u00a7 4.2 est un service ; sans valeur sinon (une ",
           "rechute suivie d'une nouvelle ouverture rallume l'indemnit\u00e9)"),
    "somme sign\u00e9e des montants des prestations refus\u00e9es ou exclues",
    "somme sign\u00e9e des montants emission, annulation et regularisation",
    "somme des montants encaissement",
    "montant d'un fixation_capital exclu seul",
    "montant d'un ouverture_service ou modification_montant d'une rente exclu seul",
    "montant d'un ouverture_service ou modification_montant d'un dossier incapacite exclu seul"),
  stringsAsFactors = FALSE)

# Sous-éléments admis des arguments `declarations` (sous-schéma `donnees` du plan, ADR 0010,
# point 17) et `conventions` (section `conventions` du plan, M153).
RUBRIQUES_DECLARATIONS <- c("exclusions", "hypotheses", "seuils", "evaluations_gestion")
# `instant_date`, `repartition_annee`, `fractionnement` et `decompte_jours` (entrée nouvelle de
# B2) sont admises sans contrôle de valeur : leur domaine est contrôlé par valider_plan()
# (spécification de B2, docs/specifications/b2-capital-deces-v1.md, § 2.6).
ENTREES_CONVENTIONS <- c("age", "instant_date", "repartition_annee", "fractionnement", "decompte_jours",
                         "limite_age")

# Contrôles prévus par la spécification (§ 2.4) et reportés (décision du mainteneur : #18 se
# ferme avec un report déclaré ; #34) : rendus dans
# controles_non_executes avec la cause `non_implemente` (CAUSE_NON_IMPLEMENTE), pour que le
# bilan dise lui-même qu'il est partiel. Écrits à la fermeture partielle de #34 (spécification
# `donnees` v1.6, § 8 ; M335) : D07 (a) et (b), D08, D10 (d) à (f), D11 (forme D11a), D12, D14 ;
# restent D03d (renvoyé à B4, #116) et D09 aux seuils (#115, M336).
# Colonne NA : contrôle qui porte sur plusieurs colonnes, ou sous-cas qui ne doit pas se
# confondre avec un contrôle écrit sur la même colonne (D09 aux seuils).
# Priorité des causes : un contrôle non implémenté porte `non_implemente`, avant toute
# autre cause (declaration_absente, refus d'une colonne lue).
CAUSE_NON_IMPLEMENTE <- "non_implemente"
# Sous-cas qu'aucune colonne de la base ne permet de lire (décision du mainteneur, D2) : non
# exécuté, cause `non_lisible`, colonne NA (sous-cas distinct de la règle écrite sur la même
# colonne). Depuis le dictionnaire 1.6, la cause n'a plus de producteur : D03h lit
# `maintien_deces` (P6), et le sous-cas du maintien de D11a le lit aussi (spécification
# `donnees` v1.9, § 9.5, #81). La constante et son rang restent dans la liste fermée des causes
# (jugement d'expert, erratum du projet de dictionnaire 1.6, § 11.3 (a) : la retirer changerait
# l'ordre des rangs sans motif de fond).
CAUSE_NON_LISIBLE <- "non_lisible"
.ni <- function(code, table, colonne = NA_character_) {
  data.frame(code = code, table = table, colonne = colonne, stringsAsFactors = FALSE)
}
# États transitoires du dictionnaire 1.6 (spécification `donnees` v1.9, § 9.8, liste fermée),
# chacun retiré par le commit qui l'écrit : T2 (D03i) et T3 (D03g sur dossiers, catastrophes et
# victimes, avec sa garde) sont levés au commit 60b de #60 ; T4 (parente_posterieure) et T5
# (D02b sur prestations) au commit de #83 ; T9 (D11b et D11c) au commit de #81. Restent les six
# rangées de e881de8.
CONTROLES_NON_IMPLEMENTES <- rbind(
  .ni("D03d", "assures", "situation_familiale"),
  .ni("D09", c("parametres", "affiliations", "evenements", "prestations", "cotisations"))
)

# Règle de limite d'âge de D07 (c) (M155) et conventions d'âge admises pour cet emploi
# (spécification, § 5.3 ; M154 : naissance réelle de l'enfant).
REGLES_LIMITE_AGE <- c("atteinte", "depassement")
CONVENTIONS_LIMITE_AGE <- c("revolu", "millesime")

# Couples (motif, famille) traités S par le dictionnaire (§ 9) : la famille ne lit pas la
# colonne (D03a : « S pour la famille triangle » ; D12 : « S pour la famille triangle, qui ne lit
# pas les états », et, pour la même raison, S pour les familles risque_en_cours et
# regle_comptable, spécification `donnees` v1.6, § 8.8). Hors du critère de couverture d'une
# exclusion (ni declarations_requises ni enjeu non déclaré) ; une exclusion déclarée sur l'un
# d'eux est refusée (plan_invalide). Liste dérivée de defauts.csv (version 1.6, P7 ;
# spécification `donnees` v1.9, § 9.6) : éléments famille:<famille> de la colonne
# `signalement`, data.frame (motif, famille) dans l'ordre du fichier ; une famille hors de
# FAMILLES_CALCUL est un dictionnaire invalide.
.exceptions_famille <- function(dico) {
  el <- lapply(dico$defauts$signalement, eclater_champ)
  n <- lengths(el)
  x <- data.frame(motif = rep(dico$defauts$code, n), element = unlist(el, use.names = FALSE), stringsAsFactors = FALSE)
  x <- x[startsWith(x$element, "famille:"), , drop = FALSE]
  familles <- substring(x$element, 9L)
  if (!all(familles %in% FAMILLES_CALCUL)) {
    refuser(paste0("dictionnaire de la base : defauts.csv, signalement : famille hors de FAMILLES_CALCUL (",
                   paste(setdiff(familles, FAMILLES_CALCUL), collapse = ", "), ")"), "dictionnaire_invalide", module = "donnees")
  }
  data.frame(motif = x$motif, famille = familles, stringsAsFactors = FALSE)
}
# Motifs de la règle P, appliqués à la construction de la vue (une seule vue pour les deux
# référentiels) : une hypothèse porte sur tous les postes, avec la même valeur pour les deux
# référentiels ; aucune n'est un signalement déclaré (S seulement à l'extraction).
.MOTIFS_REGLE_P <- c("D02b", "D03g")
# Motifs dont l'hypothèse s'applique à la vue, commune aux postes et aux deux référentiels :
# ceux de la règle P et D02a (dates rejetées tenues pour inconnues, M717) ; leur hypothèse se
# déclare pour le poste `tous`, avec la même valeur pour les deux référentiels
# (lire_declarations()). Même ensemble que .MOTIFS_HYPOTHESE_VUE de `engagement` (détection S2) :
# invariant contrôlé par un test (M722 ; spécification `donnees` v1.9, § 9.4, erratum 1.9.5, #171).
.MOTIFS_HYPOTHESE_VUE_COMMUNE <- c("D02a", .MOTIFS_REGLE_P)
# Motifs à traitement unique (dictionnaire, § 1.10 et § 9 : X et H y sont deux alternatives
# pour toute ligne) : une exclusion et une hypothèse déclarées pour un même motif de cette
# liste rendent le plan invalide, quelles qu'en soient les familles ou les référentiels
# (décision du mainteneur, D8). D03g n'y est pas (D11) : X et H se déclarent ensemble, X
# pour les lignes entières, H pour les parties de ligne (.application_d03g()).
.MOTIFS_TRAITEMENT_UNIQUE <- c("D02a", "D03a", "D03c", "D03f")
# Motifs dont le signalement (S) est un choix déclarable, alternative à H ou à X
# (dictionnaire, § 9, colonne « Signalement ») : liste dérivée de defauts.csv (version 1.6, P7 ;
# spécification `donnees` v1.9, § 9.6), codes de `signalement` = alternatif, dans l'ordre du
# fichier. La colonne distingue un S alternatif d'un S cumulatif (D02c, D10b), d'un S réservé à
# une famille (D03a, D12) et d'un S à l'extraction (D02b, D03g), que `traitements` ne distingue pas.
.motifs_signalement <- function(dico) dico$defauts$code[dico$defauts$signalement == "alternatif"]
# Traitements de chaque sous-cas lettré (D07a à D07c, D10a à D10h, D11a à D11c) : lignes de
# defauts.csv de `parent` renseigné (version 1.6, P8 ; spécification `donnees` v1.9, § 9.6),
# vecteur nommé par code, dans l'ordre du fichier. Liste dérivée du § 9.6 (remplace
# .TRAITEMENTS_SOUS_CAS_D10), lue par le test d'égalité des listes dérivées
# (tests/unitaires/donnees.R) et, dans le package, pour le seul traitement du constat de D07 (b)
# (.regle_v_extinctions()) ; .motif_admet() lit directement defauts.csv, où chaque sous-cas est
# une ligne depuis la version 1.6. `.codes_a_sous_cas()` : codes parents (D07,
# D10, D11), qui ne se déclarent que par sous-cas (réserve m1 ; spécification `donnees` v1.9,
# § 9.5 et § 9.6).
.traitements_sous_cas <- function(dico) {
  sous <- nzchar(dico$defauts$parent)
  stats::setNames(dico$defauts$traitements[sous], dico$defauts$code[sous])
}
.codes_a_sous_cas <- function(dico) unique(dico$defauts$parent[nzchar(dico$defauts$parent)])
# Motifs dont le refus porte sur une clé étrangère (lien) : cette colonne ne bloque pas
# l'enjeu de son propre écart (.causes_enjeu(), réserve Q4).
.MOTIFS_LIEN_ECART <- c("D04a", "D04b", "D10a", "D10h")
# Tables de D03g (date de saisie de la ligne, ou date_saisie_fin d'un contrat ou d'une
# affiliation) : noms admis de seuils$d03g_delai_jours. `.COLONNES_D03G` : colonne de la date de
# saisie de la ligne entière, par table ; dossiers, catastrophes et victimes depuis le
# dictionnaire 1.6 (P18 (a), M506 ; spécification `donnees` v1.9, § 9.6), dossiers par la date
# qui vaut date de saisie (`date_ouverture`).
.COLONNES_D03G <- c(affiliations = "date_saisie", famille = "date_saisie", sinistres = "date_saisie",
                    dossiers = "date_ouverture", beneficiaires = "date_saisie", rentes = "date_saisie",
                    evenements = "date_saisie", prestations = "date_saisie", catastrophes = "date_saisie",
                    victimes = "date_saisie", designations = "date_saisie", ayants_droit_sante = "date_saisie")
.TABLES_D03G <- c("contrats", names(.COLONNES_D03G))
# Colonnes de D03i, « date d'effet de visibilité manquante » (dictionnaire 1.6, P18 (b), M506 ;
# spécification `donnees` v1.9, § 9.6) : dates de visibilité (.DATES_VISIBILITE) qui sont aussi
# des valeurs lues par les postes ; X par famille à tout arrêté.
.COLONNES_D03I <- c(contrats = "date_effet", garanties_souscrites = "date_effet", prestations = "date_reglement",
                    cotisations = "date_mouvement")

# Codes de défaut dont l'objet est un manquant (dictionnaire, § 9) : un manquant dans une
# colonne qui porte l'un d'eux relève de ce défaut, non de `manquant_obligatoire`.
.DEFAUTS_MANQUANT <- c("D03a", "D03b", "D03c", "D03e", "D03f", "D03g", "D03h", "D03i", "D04a")

# Écart admis entre la somme des parts des bénéficiaires d'un dossier et 1 (somme_parts) :
# erreur d'arrondi d'une somme de fractions en double précision (1/3 + 1/3 + 1/3), non une
# tolérance de gestion.
.TOLERANCE_PARTS <- sqrt(.Machine$double.eps)
# Nombre de bénéficiaires non déterminés d'un même dossier au-delà duquel somme_parts n'énumère
# pas leurs sous-sommes (2^k), dans le seul cas que les raccourcis exacts ne tranchent pas :
# verdict inconnu pour le dossier, ligne écartée avec la cause (γ) (spécification v1.5.4,
# § 2.2 (d) ; avis d'`actuary`).
.MAX_PARTS_ND <- 20L

# Garanties de rente (dossier porteur d'une ligne de `rentes`, dictionnaire, § 3, T12) ;
# garanties d'un capital fixé (`fixation_capital`, dictionnaire, § 4).
.GARANTIES_RENTE <- c("rente_conjoint", "rente_education", "invalidite")
.GARANTIES_CAPITAL <- c("deces", "double_effet")

# Traitement d'un défaut D04b selon sa table (dictionnaire, § 9).
.TABLES_D04B_X <- c("evenements", "beneficiaires", "rentes", "cotisations", "victimes",
                    "designations", "ayants_droit_sante")

# --- Point d'entrée ----------------------------------------------------------------

# Contrôle une base (liste nommée de data.frame, une par table du dictionnaire) à la date
# d'arrêté `arrete` (Date de longueur 1, obligatoire, sans valeur par défaut, M147), sous
# les déclarations du sous-schéma `donnees` du plan (`declarations`, NULL : aucune
# déclaration fournie, M148) et la section `conventions` du plan (`conventions`, NULL :
# aucune convention fournie, M153). Ne modifie aucune donnée.
# Refus d'appel (M143 ; ADR 0010, cinquième série, (a) 1) : `arrete` absent
# (plan_incomplet) ou mal formé (plan_invalide) ; `donnees` qui n'est pas une liste nommée
# de data.frame, table inconnue (liste_invalide) ; table obligatoire absente
# (table_base_absente) ; toute anomalie de la table extraction (extraction_invalide, ou
# colonne_absente, colonne_inconnue, type_incompatible portant table = "extraction") ;
# arrêté postérieur à la date d'extraction (arrete_posterieur_extraction) ; déclaration ou
# convention mal formée, convention hors de sa liste fermée (plan_invalide).
# Toute autre anomalie est enregistrée au bilan, rendu en liste nommée, dans cet ordre :
#   controles : toute détection, une ligne par (code, table, colonne) ;
#   controles_non_executes : contrôle empêché par un refus (cause = son motif), par une
#     déclaration absente (cause = "declaration_absente"), ou pas encore écrit (cause =
#     "non_implemente", CONTROLES_NON_IMPLEMENTES : le bilan dit lui-même qu'il est partiel),
#     ou illisible dans la base (cause = "non_lisible"), ou composante de l'enjeu qui lit
#     une colonne refusée (code = composante) ; une clé présente aussi dans controles est
#     une détection partielle ;
#   refus_tables : refus R, portée effective colonne ou table, origine d'un refus induit,
#     lignes visibles à l'arrêté (règles de la vue, NA si indéterminée, .connus()) et
#     dossiers rattachés à l'arrêté par une ligne visible (.nombre_dossiers_union(), NA si
#     un rattachement est non déterminé) ;
#   exclusions (par motif, famille de calcul et action déclarée), hypotheses_defaut (par
#     motif, référentiel, poste et valeur déclarés), signalements (S, ou signalement
#     déclaré), declarations_requises (déclaration attendue par un constat : rubrique,
#     motif, famille, référentiel ou seuil, traitements admis) ; enjeu (table longue,
#     COMPOSANTES_ENJEU) ;
#   vue : date d'arrêté et d'extraction, lignes de visibilité non déterminée (table,
#     colonne : NA pour la ligne entière, sinon partie de ligne ; motif, dont
#     parente_non_determinee et le code d'un refus de valeur sur une colonne lue par la vue ;
#     origine : « table.colonne » de la valeur refusée, NA sinon ; nombre, identifiants) et
#     `provisoire` (vrai s'il y en a, ou si une règle P n'a pas pu s'exécuter sur une table
#     lue par la vue : comptes de la règle V provisoires) ;
#   segments : vide en Bd (segmentations déclarées en B2) ;
#   tables_absentes : tables facultatives absentes.
# Chaque data.frame est trié par ordre des tables du dictionnaire, puis des colonnes (NA en
# tête), puis par code (exclusions, hypotheses_defaut, declarations_requises : par motif,
# puis famille ou référentiel dans l'ordre de leur liste) ; `identifiants` porte les dix premières valeurs de la clé primaire,
# triées (sort radix), jointes par « ; » (colonnes d'une clé composite jointes par « | »).
# Le bilan est celui de la vue à l'arrêté (vue_a_date()$bilan, spécification de B2, § 4.2).
controler_base <- function(donnees, arrete, declarations = NULL, conventions = NULL) {
  if (missing(arrete)) {
    refuser("controler_base() : date d'arr\u00eat\u00e9 absente (`arrete`, obligatoire, sans valeur par d\u00e9faut)",
            "plan_incomplet", module = "donnees")
  }
  vue_a_date(donnees, arrete, declarations, conventions)$bilan
}

# Vue à l'arrêté (spécification de B2, docs/specifications/b2-capital-deces-v1.md, § 4.2 ;
# ADR 0010, point 14, annoté) : construite une seule fois par `donnees`, lue par les familles
# de calcul (etats_a_date(), valeurs_vue()), jamais la base brute. Mêmes arguments et mêmes
# refus d'appel que controler_base(), sans valeur par défaut (`declarations` et `conventions` :
# NULL pour aucune déclaration, aucune convention). Rend une liste de classe `vue_provie` :
#   bilan : la liste que rend controler_base() (controler_base() en est la lecture) ;
#   retenu : par table, lignes retenues dans la vue (logique ; .construire_vue()) ;
#   parties : par table à partie de ligne, logique de Kleene (.visibilite_a(), mode "vue") :
#     TRUE connue à l'arrêté, FALSE inconnue de façon déterminée, NA non déterminée ou
#     illisible par sa forme (#51) ;
#   exclu : par famille de calcul (FAMILLES_CALCUL) puis par table, lignes exclues par une
#     exclusion déclarée d'action `exclure` pour cette famille, cascade du dictionnaire
#     (§ 1.10 : un sinistre exclu exclut ses dossiers, rentes, bénéficiaires, événements,
#     prestations et évaluations) comprise ;
#   hypotheses : hypothèses par défaut appliquées (placement des constats H déclarés), une
#     entrée par (motif, référentiel, poste, valeur, table) avec ses lignes ;
#   ctx : environnement interne, lu par valeurs_vue() et etats_a_date() seulement.
# Sans point : appelée hors du module par les familles de calcul et l'orchestration (B2),
# non exportée.
vue_a_date <- function(donnees, arrete, declarations, conventions) {
  if (missing(arrete)) {
    refuser("vue_a_date() : date d'arr\u00eat\u00e9 absente (`arrete`, obligatoire, sans valeur par d\u00e9faut)",
            "plan_incomplet", module = "donnees")
  }
  dico <- dictionnaire()
  .controler_liste_base(donnees, dico)
  .controler_arrete(arrete)
  .controler_tables_obligatoires(donnees, dico)
  extraction <- .controler_extraction_base(donnees[["extraction"]], dico)
  if (as.numeric(arrete) > as.numeric(extraction$date_extraction)) {
    refuser(paste0("controler_base() : date d'arr\u00eat\u00e9 ", format(arrete),
                   " post\u00e9rieure \u00e0 la date d'extraction ", format(extraction$date_extraction)),
            "arrete_posterieur_extraction", module = "donnees", table = "extraction",
            colonne = "date_extraction", attendu = format(extraction$date_extraction),
            recu = format(arrete))
  }
  conventions <- .lire_conventions(conventions)
  declarations <- lire_declarations(declarations, dico)

  ctx <- .contexte(donnees, dico, extraction, arrete)
  ctx$declarations <- declarations
  ctx$conventions <- conventions
  .regle_forme(ctx)
  .regle_domaine(ctx)
  .regle_cles(ctx)
  .refus_induits(ctx)
  .refus_regle_b(ctx)
  .regle_p(ctx)
  .construire_vue(ctx)
  .regle_v(ctx)
  bilan <- .bilan(ctx)
  parties <- .visibilite_a(ctx, "vue")$parties
  exclu <- .exclu_vue(ctx)
  # D02a sous H : dates rejetées tenues pour inconnues dans la vue lue par les familles, après le
  # bilan et la visibilité, calculés sur les dates brutes (spécification `donnees` v1.9, § 9.4)
  .appliquer_d02a(ctx)
  structure(list(bilan = bilan, retenu = ctx$retenu, parties = parties, exclu = exclu,
                 hypotheses = ctx$placement$hypotheses, ctx = ctx),
            class = "vue_provie")
}

# Valeurs d'une colonne dans la vue `vue` (objet vue_a_date()) : .valeurs_vue(). Son NA veut
# dire « hors de la vue » (ligne non retenue, partie de ligne inconnue, non déterminée ou
# illisible), jamais « absente » : un lecteur qui doit distinguer lit `vue$parties`
# (spécification de B2, § 4.3). Sans point : appelée hors du module par les familles de
# calcul, non exportée.
valeurs_vue <- function(vue, table, colonne) {
  if (!inherits(vue, "vue_provie")) stop("valeurs_vue() : `vue` doit \u00eatre un objet vue_provie", call. = FALSE)
  .valeurs_vue(vue$ctx, table, colonne)
}

# Clés des lignes placées sous une hypothèse de la vue (spécification de B2, § 5.8, source S2 ;
# erratum v1.0.17, décision E17-1 du mainteneur, option (i) bornée) : valeur de la base de la
# colonne `colonne` de la table `table` pour les lignes `lignes` (indices), visibles ou non à
# l'arrêté, que valeurs_vue() masque pour une ligne non retenue. Borné : toute ligne absente des
# `lignes` des hypothèses de `vue$hypotheses` de cette table, et toute colonne qui n'est pas une
# colonne d'identifiant id_* de la clé primaire de la table ou clé étrangère (`reference`) du
# dictionnaire, de type character (aucune date, aucun montant, aucune autre composante de clé
# comme affiliations.college ; erratum v1.0.18, constats m1 et m3 de l'audit, décisions du
# mainteneur), et tout `lignes` qui n'est pas un vecteur numérique d'indices entiers, finis et
# positifs (un logique, `TRUE` par exemple, ne vaut pas indice), est une erreur interne. Seul
# rattachement d'une ligne cachée à son unité, pour un statut ; jamais lu
# pour un montant. Sans point : appelée par `engagement` (hypotheses_vue_unites()) ; non
# exportée.
cles_lignes_hypothese <- function(vue, table, lignes, colonne) {
  if (!inherits(vue, "vue_provie")) stop("cles_lignes_hypothese() : `vue` doit \u00eatre un objet vue_provie", call. = FALSE)
  dico <- vue$ctx$dico
  cd <- dico$colonnes[dico$colonnes$table == table, , drop = FALSE]
  pk <- eclater_champ(dico$tables$cle_primaire[dico$tables$table == table][1L])
  cles <- c(pk, cd$colonne[!is.na(cd$reference) & nzchar(cd$reference)])
  cles <- intersect(cles[startsWith(cles, "id_")], cd$colonne[cd$type == "character"])
  if (!(is.character(colonne) && length(colonne) == 1L && colonne %in% cles)) {
    stop(paste0("erreur interne de provie : cles_lignes_hypothese() : ", table, ".", paste(colonne, collapse = ","),
                " n'est pas une colonne d'identifiant du dictionnaire"), call. = FALSE)
  }
  if (!(is.numeric(lignes) && all(is.finite(lignes)) && all(lignes >= 1) && all(lignes == trunc(lignes)))) {
    stop(paste0("erreur interne de provie : cles_lignes_hypothese() : `lignes` de ", table,
                " n'est pas un vecteur d'indices entiers positifs"), call. = FALSE)
  }
  placees <- unlist(lapply(Filter(function(h) identical(h$table, table), vue$hypotheses), `[[`, "lignes"))
  if (!all(lignes %in% placees)) {
    stop(paste0("erreur interne de provie : cles_lignes_hypothese() : ligne de ", table,
                " non plac\u00e9e sous une hypoth\u00e8se de la vue"), call. = FALSE)
  }
  .valeurs(vue$ctx, table, colonne)[lignes]
}

# Tables de la cascade d'une exclusion (dictionnaire, § 1.10) : un sinistre exclu exclut, dans
# la même famille, ses dossiers, rentes, bénéficiaires, événements, prestations et
# évaluations ; la cascade suit les clés étrangères simples de ces tables vers les tables de
# la cascade et vers sinistres.
.TABLES_CASCADE_EXCLUSION <- c("dossiers", "rentes", "beneficiaires", "evenements", "prestations", "evaluations_gestion")

# Lignes exclues par famille de calcul (vue_a_date()$exclu) : lignes des exclusions placées
# (.placer(), action `exclure`) de la famille, puis cascade jusqu'au point fixe (une ligne
# d'une table de la cascade est exclue si la ligne qu'elle vise par une clé étrangère l'est).
.exclu_vue <- function(ctx) {
  tables <- setdiff(ctx$tables, "extraction")
  liens <- .liens_visibilite(ctx$dico)
  liens <- liens[liens$table %in% intersect(tables, .TABLES_CASCADE_EXCLUSION) &
                   liens$table_cible %in% intersect(tables, c("sinistres", .TABLES_CASCADE_EXCLUSION)), , drop = FALSE]
  res <- list()
  for (f in FAMILLES_CALCUL) {
    x <- lapply(stats::setNames(tables, tables), function(t) rep(FALSE, NROW(ctx$base[[t]])))
    for (e in ctx$placement$exclusions) {
      if (e$famille == f && e$action == "exclure" && e$table %in% tables) x[[e$table]][e$lignes] <- TRUE
    }
    repeat {
      change <- FALSE
      for (i in seq_len(nrow(liens))) {
        t <- liens$table[i]
        u <- liens$table_cible[i]
        if (!any(x[[u]])) next
        nouveau <- x[[t]] | !is.na(apparier_cles(.valeurs(ctx, t, liens$colonne[i]),
                                                .valeurs(ctx, u, liens$colonne_cible[i])[x[[u]]]))
        if (!identical(nouveau, x[[t]])) {
          x[[t]] <- nouveau
          change <- TRUE
        }
      }
      if (!change) break
    }
    res[[f]] <- x
  }
  res
}

# --- États à une date ----------------------------------------------------------------

# Garanties dont etats_a_date() reconstitue les dossiers (B2 : deces seule ; spécification de
# B2, § 4.2) ; colonnes rendues, dans cet ordre.
.GARANTIES_ETATS <- "deces"
# Types d'événement lus par l'automate du dossier (etats_a_date() ; spécification de B2, § 4.2,
# erratum v1.0.5) : les autres types sont sans effet sur l'état. Seule liste, lue aussi par
# `engagement` (état non déterminé des lignes lues par unité, .lectures_dossiers() ;
# spécification `donnees` v1.9, § 9.2, erratum 1.9.6, (i), #175).
TYPES_AUTOMATE <- c("fixation_capital", "cloture_dossier", "reouverture_dossier")
.COLONNES_ETATS <- c("id_sinistre", "id_dossier", "etat", "date_entree_etat", "categorie_invalidite",
                     "montant_en_vigueur", "etat_dossier", "date_etat_dossier", "motif_cloture", "instruit")

# États à l'arrêté des dossiers de la vue `vue` (objet vue_a_date()) dont la garantie souscrite
# a un code de `garanties` (B2 : "deces" seule ; tout autre code est une erreur de
# programmation), pour la famille de calcul `famille` (exigée, sans valeur par défaut, un code
# de FAMILLES_CALCUL ; autre valeur : erreur de programmation) (spécification de B2, § 4.2,
# erratum v1.0.5 ; ADR 0010, point 14, annoté). Une ligne par dossier retenu, dans l'ordre de
# la table dossiers, exclus pour la famille compris (l'appelant les filtre par
# vue$exclu[[famille]]$dossiers) ; colonnes .COLONNES_ETATS :
#   etat : "deces" (sinistre deces) ou "iad" (sinistre iad), NA sinon ; date_entree_etat :
#     sinistres.date_survenance ; categorie_invalidite : NA (B5) ;
#   montant_en_vigueur : montant du dernier fixation_capital du dossier retenu et non exclu
#     pour la famille (NA sans fixation) ;
#   etat_dossier ("ouvert", "capital_du", "clos"), date_etat_dossier (date d'effet de
#     l'événement qui l'a fixé, date_ouverture pour l'ouvert initial), motif_cloture (motif du
#     cloture_dossier en vigueur si clos, NA sinon) : automate du dossier deces sur les
#     événements de la vue de niveau dossier, de type de TYPES_AUTOMATE, non exclus pour la famille
#     (vue$exclu[[famille]]$evenements), de date d'effet au plus l'arrêté (comme les
#     composantes de l'enjeu et D07 (c)), dans l'ordre de .dernier_evenement() (date d'effet,
#     ordre des types du § 4, date de saisie, id_evenement) : départ ouvert ; fixation_capital
#     ouvert -> capital_du (montant mis à jour ; sur un clos, montant mis à jour, état
#     inchangé) ; cloture_dossier -> clos ; reouverture_dossier : clos -> capital_du si un montant est en vigueur (fixation retenue
#     antérieure à la réouverture), ouvert sinon, à la date d'effet de la réouverture ; les
#     autres types sont sans effet ;
#   instruit : logique de Kleene, NA si la partie sinistres.date_instruction vaut NA dans
#     `vue$parties` ou si l'instruction est tenue pour inconnue par D02a sous H (R10,
#     dates_inconnues_vue()), sinon partie ET date d'instruction présente (spécification de B2,
#     § 4.3 ; spécification `donnees` v1.9, § 9.4).
# Sans point : appelée hors du module par la famille « engagement », non exportée.
etats_a_date <- function(vue, garanties, famille) {
  if (!inherits(vue, "vue_provie")) stop("etats_a_date() : `vue` doit \u00eatre un objet vue_provie", call. = FALSE)
  if (missing(famille) || !is.character(famille) || length(famille) != 1L || is.na(famille) ||
      !(famille %in% FAMILLES_CALCUL)) {
    stop(paste0("erreur interne de provie : etats_a_date() : `famille` doit \u00eatre un code de FAMILLES_CALCUL (",
                paste(FAMILLES_CALCUL, collapse = ", "), ")"), call. = FALSE)
  }
  if (!is.character(garanties) || length(garanties) < 1L || anyNA(garanties) || !all(garanties %in% .GARANTIES_ETATS)) {
    stop(paste0("erreur interne de provie : etats_a_date() ne reconstitue que les garanties ",
                paste(.GARANTIES_ETATS, collapse = ", ")), call. = FALSE)
  }
  ctx <- vue$ctx
  vv <- function(t, c1) .valeurs_vue(ctx, t, c1)
  # clés appariées : une chaîne vide vaut clé manquante, aucun appariement (apparier_cles(), #123, #154)
  jointure <- function(x, t, cle, c1) vv(t, c1)[apparier_cles(x, vv(t, cle))]
  gs <- vv("dossiers", "id_garantie_souscrite")
  code <- jointure(gs, "garanties_souscrites", "id_garantie_souscrite", "code_garantie")
  k <- which(ctx$retenu$dossiers & code %in% garanties)
  n <- length(k)
  id_dossier <- vv("dossiers", "id_dossier")[k]
  id_sinistre <- vv("dossiers", "id_sinistre")[k]
  i_sin <- apparier_cles(id_sinistre, vv("sinistres", "id_sinistre"))
  nature <- vv("sinistres", "nature_sinistre")[i_sin]
  etat <- ifelse(nature %in% "deces", "deces", ifelse(nature %in% "iad", "iad", NA_character_))
  date_entree <- vv("sinistres", "date_survenance")[i_sin]
  ouverture <- vv("dossiers", "date_ouverture")[k]
  # automate du dossier, sur les événements retenus de niveau dossier, d'effet au plus l'arrêté
  a <- as.numeric(ctx$arrete)
  type <- vv("evenements", "type_evenement")
  effet <- as.numeric(vv("evenements", "date_effet"))
  ev <- which(type %in% TYPES_AUTOMATE & !is.na(effet) & effet <= a & !is.na(vv("evenements", "id_dossier")) &
                !vue$exclu[[famille]]$evenements)
  p <- .paires(vv("evenements", "id_dossier")[ev], id_dossier)
  etat_dossier <- rep("ouvert", n)
  date_etat <- ouverture
  montant <- rep(NA_real_, n)
  motif_cloture <- rep(NA_character_, n)
  if (nrow(p) > 0L) {
    te <- ctx$dico$types_evenements
    i <- ev[p$i]
    o <- order(p$j, effet[i], te$ordre[match(type[i], te$type_evenement)], as.numeric(vv("evenements", "date_saisie"))[i],
               vv("evenements", "id_evenement")[i], method = "radix")
    i <- i[o]
    j <- p$j[o]
    montant_ev <- vv("evenements", "montant")
    motif_ev <- vv("evenements", "motif")
    for (m in seq_along(i)) {
      e <- i[m]
      d <- j[m]
      switch(type[e],
        fixation_capital = {
          montant[d] <- montant_ev[e]
          if (etat_dossier[d] != "clos") {
            etat_dossier[d] <- "capital_du"
            date_etat[d] <- effet[e]
          }
        },
        cloture_dossier = {
          etat_dossier[d] <- "clos"
          date_etat[d] <- effet[e]
          motif_cloture[d] <- motif_ev[e]
        },
        reouverture_dossier = {
          if (etat_dossier[d] == "clos") {
            etat_dossier[d] <- if (is.na(montant[d])) "ouvert" else "capital_du"
            date_etat[d] <- effet[e]
            motif_cloture[d] <- NA_character_
          }
        },
        NULL)
    }
  }
  # instruit : la partie de ligne (Kleene) ; une date présente sous une partie connue
  partie <- vue$parties$sinistres[i_sin]
  instruction <- .valeurs(ctx, "sinistres", "date_instruction")[i_sin]
  instruit <- ifelse(is.na(partie), NA, partie & !is.na(instruction))
  # instruction tenue pour inconnue par D02a sous H (R10) : inconnue, jamais « non instruit »
  instruit[dates_inconnues_vue(vue, "sinistres", "date_instruction")[i_sin] %in% TRUE] <- NA
  res <- data.frame(id_sinistre = id_sinistre, id_dossier = id_dossier, etat = etat, date_entree_etat = date_entree,
                    categorie_invalidite = rep(NA_character_, n), montant_en_vigueur = montant,
                    etat_dossier = etat_dossier, date_etat_dossier = structure(as.numeric(date_etat), class = "Date"),
                    motif_cloture = motif_cloture, instruit = as.logical(instruit), stringsAsFactors = FALSE)
  rownames(res) <- NULL
  res[.COLONNES_ETATS]
}

# Couverture exclue d'une ligne de garanties_souscrites pour une famille (spécification de B2,
# § 5.1, § 5.3, § 5.5 et § 5.6, erratum v1.0.13 ; spécification `donnees` v1.9, § 9.3, bloc
# « Erratum 1.9.2 », (ii), #83) : vecteur logique sur toutes les lignes de la base (retenues ou
# non), vrai si la ligne est exclue pour la famille (`exclu` : vue$exclu[[famille]]) ou si sa clé
# de contrat désigne une ligne de contrats exclue pour la famille (clé manquante ou vide, d'un
# côté ou de l'autre : aucun appariement, apparier_cles(), #154, règle (i)). Seules les clés
# (id_contrat) sont lues dans la base. Seule implémentation de la règle de population : lue par
# garanties_couverture_exclue() (lignes retenues) et par dossiers_garantie_invisible() (lignes
# non retenues).
.couverture_exclue_gs <- function(ctx, exclu) {
  if (is.null(ctx$base$garanties_souscrites)) return(logical(0))
  ct_exclus <- if (is.null(ctx$base$contrats)) character(0) else
    as.character(.valeurs(ctx, "contrats", "id_contrat"))[exclu$contrats]
  exclu$garanties_souscrites | !is.na(apparier_cles(.valeurs(ctx, "garanties_souscrites", "id_contrat"), ct_exclus))
}

# Garanties souscrites dont la couverture est exclue pour la famille `famille` (code de
# FAMILLES_CALCUL) (spécification de B2, § 5.1, § 5.3, § 5.5 et § 5.6, erratum v1.0.13) :
# identifiants (id_garantie_souscrite, triés radix, jamais NA ni "") des garanties souscrites
# retenues à couverture exclue pour la famille (.couverture_exclue_gs(), seule implémentation de
# la règle de population, restreinte ici aux lignes retenues) : un dossier (P1, P2, famille
# engagement) ou un contrat (P3, famille risque_en_cours) d'une telle garantie sort de la
# population, sans arrêt ; seules les clés (id_garantie_souscrite, id_contrat) sont lues. Une
# exclusion pour une autre famille est sans effet ; le dictionnaire (§ 1.10) n'est pas étendu :
# vue$exclu des autres tables est inchangé. Sans point : appelée par les familles engagement et
# risque_en_cours et par segments_vue() ; non exportée.
garanties_couverture_exclue <- function(vue, famille) {
  if (!inherits(vue, "vue_provie")) {
    stop("garanties_couverture_exclue() : `vue` doit \u00eatre un objet vue_provie", call. = FALSE)
  }
  if (!is.character(famille) || length(famille) != 1L || is.na(famille) || !(famille %in% FAMILLES_CALCUL)) {
    stop(paste0("erreur interne de provie : garanties_couverture_exclue() : `famille` doit \u00eatre un code de ",
                "FAMILLES_CALCUL (", paste(FAMILLES_CALCUL, collapse = ", "), ")"), call. = FALSE)
  }
  ctx <- vue$ctx
  if (is.null(ctx$base$garanties_souscrites)) return(character(0))
  gs_exclue <- ctx$retenu$garanties_souscrites & .couverture_exclue_gs(ctx, vue$exclu[[famille]])
  # identifiants rendus : jamais NA ni "" (#154, Q-B4 (T1)) ; une garantie souscrite d'identifiant
  # manquant ou vide n'appartient à aucune population (règle (ii)) et ne s'apparie à rien : les
  # appelants l'écartent par cle_renseignee(), elle n'a pas à figurer dans la liste
  id_gs <- as.character(.valeurs(ctx, "garanties_souscrites", "id_garantie_souscrite"))
  sort(unique(id_gs[gs_exclue & cle_renseignee(id_gs)]), method = "radix")
}

# Dossiers de la vue `vue` (objet vue_a_date()) dont la garantie souscrite n'est pas lisible par
# les familles à l'arrêté (exception de la règle 1, dictionnaire 1.6, § 6 ; spécification
# `donnees` v1.9, § 9.3 (1) et bloc « Erratum 1.9.2 », (ii) et (vii) ; M509, option (a) ; #83) :
# identifiants (id_dossier, triés radix, jamais NA ni "") des dossiers retenus, non exclus pour
# la famille `famille` (code de FAMILLES_CALCUL ; vue$exclu[[famille]]$dossiers, cascade
# comprise), dont la clé de garantie souscrite désigne une ligne de garanties_souscrites non
# retenue dans la vue (invisible à l'arrêté, ou de visibilité non déterminée) et aucune ligne de
# garanties_souscrites à couverture exclue pour la famille (.couverture_exclue_gs(), sur toutes
# les lignes : le dossier sort alors de la population, l'exclusion déclarée portant l'enjeu) ;
# vide à l'arrêté égal à l'extraction (vue totale). La garantie non retenue n'est pas lue
# (valeurs_vue() la masque) : un poste qui lit ses colonnes n'est jamais calculé sur elle, il est
# arrêté par l'appelant (parametre_non_determine, identifiant du premier dossier). Seules les
# clés (id_garantie_souscrite, id_contrat) sont lues dans la base. Sans point : appelée par la
# famille engagement ; non exportée.
dossiers_garantie_invisible <- function(vue, famille) {
  if (!inherits(vue, "vue_provie")) {
    stop("dossiers_garantie_invisible() : `vue` doit \u00eatre un objet vue_provie", call. = FALSE)
  }
  if (!is.character(famille) || length(famille) != 1L || is.na(famille) || !(famille %in% FAMILLES_CALCUL)) {
    stop(paste0("erreur interne de provie : dossiers_garantie_invisible() : `famille` doit \u00eatre un code de ",
                "FAMILLES_CALCUL (", paste(FAMILLES_CALCUL, collapse = ", "), ")"), call. = FALSE)
  }
  ctx <- vue$ctx
  if (is.null(ctx$base$dossiers) || is.null(ctx$base$garanties_souscrites)) return(character(0))
  exclu <- vue$exclu[[famille]]
  id_gs <- .valeurs(ctx, "garanties_souscrites", "id_garantie_souscrite")
  gs_exclue <- .couverture_exclue_gs(ctx, exclu)
  gs <- .valeurs_vue(ctx, "dossiers", "id_garantie_souscrite")
  invisible_gs <- !is.na(apparier_cles(gs, id_gs)) & is.na(apparier_cles(gs, id_gs[ctx$retenu$garanties_souscrites])) &
    is.na(apparier_cles(gs, id_gs[gs_exclue]))
  id_d <- as.character(.valeurs_vue(ctx, "dossiers", "id_dossier"))
  k <- ctx$retenu$dossiers & !exclu$dossiers & invisible_gs & cle_renseignee(id_d)
  sort(unique(id_d[k]), method = "radix")
}

# Mois de la période d'une cotisation par périodicité (dictionnaire, § 9, D03f ; spécification de
# B2, § 5.5, erratum v1.0.15) : `unique` et toute autre valeur n'ont pas de période.
# Seule constante des mois par périodicité (#92 mi3, erratum v1.0.16, décision E16-3 (a)), sans
# point : lue aussi par `risque_en_cours` (échéances de prime de P3, champ (a)).
MOIS_PERIODE_COTISATION <- c(annuelle = 12L, semestrielle = 6L, trimestrielle = 3L, mensuelle = 1L)

# Période couverte d'une cotisation sous l'hypothèse D03f (règle du dictionnaire, § 9 : période
# de la périodicité de la garantie souscrite qui commence au premier jour du mois du
# mouvement ; spécification de B2, § 5.5, champ (b), erratum v1.0.15) : `date_mouvement`
# (Date) et `periodicite` (periodicite_cotisation, character), de même longueur ; début =
# premier jour du mois de date_mouvement, fin = début + p mois - 1 jour, p = 12, 6, 3, 1
# (annuelle, semestrielle, trimestrielle, mensuelle). Rend list(debut, fin) (Date) ; NA pour
# une date NA, la périodicité `unique` ou une valeur non lisible (règle non applicable). Seule
# implémentation de la règle : lue par `risque_en_cours` (P3, prorata_cotisation), et par
# toute lecture future de cotisations (PPNA). Sans point ; non exportée.
periode_cotisation_regle <- function(date_mouvement, periodicite) {
  n <- longueur_commune(length(date_mouvement), length(periodicite), "periode_cotisation_regle")
  d <- rep_len(as.numeric(date_mouvement), n)
  mois <- unname(MOIS_PERIODE_COTISATION[rep_len(as.character(periodicite), n)])
  ok <- !is.na(d) & !is.na(mois)
  debut <- rep(NA_real_, n)
  fin <- rep(NA_real_, n)
  if (any(ok)) {
    c0 <- decomposer_date(d[ok])
    debut[ok] <- composer_date(c0$annee, c0$mois, 1L)
    fin[ok] <- ajouter_mois(debut[ok], mois[ok]) - 1
  }
  list(debut = structure(debut, class = "Date"), fin = structure(fin, class = "Date"))
}

# --- Segments ----------------------------------------------------------------------

# Règles de segmentation admises en B2 (spécification de B2, § 2.2, erratum v1.0.12), parmi
# celles du schéma de la v1 (REGLES_SEGMENTATION de `plan`) : les autres (adherent,
# secteur_activite, college, gestionnaire) sont refusées par valider_plan() (plan_invalide),
# reportées après B2. Tenue ici, où segments_vue() calcule la clé de segment de chacune ; lue
# par `plan` (graphe de l'ADR 0010, point 1 : `plan` appelle `donnees`).
REGLES_SEGMENTATION_B2 <- c("contrat", "nature_contrat", "annee_survenance", "ligne_activite")

# Segments des unités de calcul de la vue `vue` (objet vue_a_date()) pour les segmentations
# déclarées `segmentations` (plan$perimetre$segmentations canonique : nom -> list(regle,
# correspondance)) et les garanties `garanties` (codes) (ADR 0010, points 9 et 17 ; spécification
# de B2, § 2.2, § 5.5 et § 7.7). Unités : chaque dossier retenu dont la garantie souscrite retenue a un
# code de `garanties` et n'est pas dans garanties_couverture_exclue(vue, "engagement")
# (id_dossier, id_sinistre, id_contrat de la garantie souscrite) ; chaque contrat retenu qui
# porte une garantie souscrite retenue de ces codes hors de garanties_couverture_exclue(vue,
# "risque_en_cours") (id_dossier et id_sinistre NA) (erratum v1.0.13 : aucune colonne d'une
# ligne exclue n'est lue pour une unité). Clé : `contrat` : id_contrat ; `nature_contrat` : contrats.nature_contrat ;
# `ligne_activite` : correspondance[code_garantie] (pour un contrat, une valeur par code
# porté, réunies par « ; » triées) ; `annee_survenance` : année de sinistres.date_survenance du
# sinistre du dossier, `hors_survenance` pour un contrat (erratum v1.0.12). Les règles sont
# celles de REGLES_SEGMENTATION_B2, contrôlées par valider_plan() à l'étape `plan` de
# calculer_provisions() : une autre règle ici est une erreur de programmation. Rend le
# data.frame `segments` du bilan (id_dossier, id_sinistre, id_contrat, segmentation, segment),
# trié par segmentation, id_contrat, id_dossier (sort radix, NA en tête) ; segment NA si la clé
# est hors de la vue. Sans point : appelée par l'orchestration, non exportée.
segments_vue <- function(vue, segmentations, garanties) {
  if (!inherits(vue, "vue_provie")) stop("segments_vue() : `vue` doit \u00eatre un objet vue_provie", call. = FALSE)
  vide <- data.frame(id_dossier = character(0), id_sinistre = character(0), id_contrat = character(0),
                     segmentation = character(0), segment = character(0), stringsAsFactors = FALSE)
  if (length(segmentations) == 0L) return(vide)
  regles <- vapply(segmentations, function(s) s$regle, "")
  if (!all(regles %in% REGLES_SEGMENTATION_B2)) {
    stop("erreur interne de provie : r\u00e8gle de segmentation hors de REGLES_SEGMENTATION_B2 (",
         paste(setdiff(regles, REGLES_SEGMENTATION_B2), collapse = ", "), ")", call. = FALSE)
  }
  ctx <- vue$ctx
  vv <- function(t, c1) .valeurs_vue(ctx, t, c1)
  # une garantie souscrite d'identifiant manquant ou vide ne porte aucune unité (#154, règle (ii)) :
  # gs_id renseigné, comparé exactement aux identifiants rendus par garanties_couverture_exclue()
  r_gs <- which(ctx$retenu$garanties_souscrites & vv("garanties_souscrites", "code_garantie") %in% garanties &
                  cle_renseignee(vv("garanties_souscrites", "id_garantie_souscrite")))
  gs_id <- as.character(vv("garanties_souscrites", "id_garantie_souscrite"))[r_gs]
  gs_contrat <- as.character(vv("garanties_souscrites", "id_contrat"))[r_gs]
  gs_code <- vv("garanties_souscrites", "code_garantie")[r_gs]
  ct_id <- as.character(vv("contrats", "id_contrat"))
  ct_nature <- vv("contrats", "nature_contrat")
  # clés appariées : une chaîne vide vaut clé manquante, aucun appariement (apparier_cles(), #123, #154)
  # unités : dossiers, puis contrats
  # couverture exclue (erratum v1.0.13) : un dossier d'une garantie souscrite exclue pour engagement
  # (unités de P1 et P2) et un contrat dont les garanties souscrites sont exclues pour
  # risque_en_cours (unités de P3) ne sont pas des unités : aucune colonne de la ligne exclue n'est lue
  exclue_eng <- !is.na(apparier_cles(gs_id, garanties_couverture_exclue(vue, "engagement")))
  exclue_rec <- !is.na(apparier_cles(gs_id, garanties_couverture_exclue(vue, "risque_en_cours")))
  k <- which(ctx$retenu$dossiers)
  i_gs <- apparier_cles(vv("dossiers", "id_garantie_souscrite")[k], gs_id)
  i_gs[!is.na(i_gs)][exclue_eng[i_gs[!is.na(i_gs)]]] <- NA_integer_
  k <- k[!is.na(i_gs)]
  i_gs <- i_gs[!is.na(i_gs)]
  contrats_u <- sort(unique(gs_contrat[!exclue_rec & !is.na(apparier_cles(gs_contrat, ct_id[ctx$retenu$contrats]))]),
                     method = "radix")
  u_dossier <- c(as.character(vv("dossiers", "id_dossier"))[k], rep(NA_character_, length(contrats_u)))
  u_sinistre <- c(as.character(vv("dossiers", "id_sinistre"))[k], rep(NA_character_, length(contrats_u)))
  u_contrat <- c(gs_contrat[i_gs], contrats_u)
  # codes de garantie par contrat : un seul appariement de gs_contrat aux contrats d'unité (rang dans
  # contrats_u, NA hors unité), puis regroupement par rang ; un contrat sans garantie retenue rend ""
  j_contrat <- apparier_cles(gs_contrat, contrats_u)
  retenue <- !exclue_rec & !is.na(j_contrat)
  codes_contrat <- vapply(split(gs_code[retenue], factor(j_contrat[retenue], levels = seq_along(contrats_u))),
                          function(g) paste(sort(unique(g), method = "radix"), collapse = ";"), "", USE.NAMES = FALSE)
  u_codes <- c(gs_code[i_gs], codes_contrat)
  si_survenance <- vv("sinistres", "date_survenance")
  u_annee <- c(as.character(as.POSIXlt(si_survenance[apparier_cles(u_sinistre[seq_along(k)],
                                                                    vv("sinistres", "id_sinistre"))])$year + 1900L),
               rep("hors_survenance", length(contrats_u)))
  lignes <- lapply(names(segmentations), function(nom) {
    s <- segmentations[[nom]]
    segment <- switch(s$regle,
      contrat = u_contrat,
      annee_survenance = u_annee,
      nature_contrat = ct_nature[apparier_cles(u_contrat, ct_id)],
      ligne_activite = vapply(u_codes, function(x) {
        paste(sort(unique(vapply(strsplit(x, ";", fixed = TRUE)[[1L]], function(g) s$correspondance[[g]], "")),
                   method = "radix"), collapse = ";")
      }, "", USE.NAMES = FALSE))
    data.frame(id_dossier = u_dossier, id_sinistre = u_sinistre, id_contrat = u_contrat,
               segmentation = rep(nom, length(u_contrat)), segment = as.character(segment), stringsAsFactors = FALSE)
  })
  res <- do.call(rbind, lignes)
  res <- res[order(res$segmentation, res$id_contrat, res$id_dossier, method = "radix", na.last = FALSE), , drop = FALSE]
  rownames(res) <- NULL
  res
}

# --- Refus d'appel -----------------------------------------------------------------

.refus_structure <- function(message, ...) {
  refuser(paste0("controler_base() : ", message), "liste_invalide", module = "donnees", ...)
}

# Structure des arguments : liste nommée de data.frame aux noms renseignés et distincts,
# tables connues du dictionnaire (les colonnes sont contrôlées par constater_forme()).
.controler_liste_base <- function(donnees, dico) {
  if (!is.list(donnees) || is.data.frame(donnees) || !is.null(attr(donnees, "dim"))) {
    .refus_structure("`donnees` doit \u00eatre une liste nomm\u00e9e de data.frame (une par table)")
  }
  noms <- names(donnees)
  if (length(donnees) > 0L && (is.null(noms) || anyNA(noms) || any(!nzchar(noms)) || anyDuplicated(noms))) {
    .refus_structure("les tables de la liste doivent avoir des noms renseign\u00e9s et distincts")
  }
  inconnues <- setdiff(noms, dico$tables$table)
  if (length(inconnues) > 0L) {
    .refus_structure(paste0("table(s) inconnue(s) du dictionnaire : ", paste(inconnues, collapse = ", ")),
                     table = inconnues[1L], nombre = length(inconnues), identifiants = inconnues)
  }
  for (table in noms) {
    x <- donnees[[table]]
    if (!is.data.frame(x)) .refus_structure(paste0("la table ", table, " n'est pas un data.frame"), table = table)
    n <- names(x)
    if (anyNA(n) || any(!nzchar(n)) || anyDuplicated(n)) {
      .refus_structure(paste0("table ", table, " : noms de colonnes renseign\u00e9s et distincts attendus"), table = table)
    }
  }
  invisible(NULL)
}

.controler_arrete <- function(arrete) {
  if (!identical(class(arrete), "Date") || length(arrete) != 1L || !is.double(arrete) ||
      !is.finite(as.numeric(arrete)) || as.numeric(arrete) != trunc(as.numeric(arrete))) {
    refuser("controler_base() : `arrete` doit \u00eatre une Date unique, renseign\u00e9e, stock\u00e9e en double",
            "plan_invalide", module = "donnees")
  }
  invisible(NULL)
}

# Tables obligatoires (tables.csv, obligatoire O ; victimes n'est obligatoire qu'avec
# catastrophes : son absence est alors un refus R de catastrophes, non un refus d'appel).
.controler_tables_obligatoires <- function(donnees, dico) {
  obligatoires <- dico$tables$table[dico$tables$obligatoire == "O"]
  absentes <- setdiff(obligatoires, names(donnees))
  if (length(absentes) > 0L) {
    refuser(paste0("controler_base() : table(s) obligatoire(s) absente(s) : ", paste(absentes, collapse = ", ")),
            "table_base_absente", module = "donnees", table = absentes[1L], nombre = length(absentes),
            identifiants = absentes)
  }
  invisible(NULL)
}

# Table extraction (refus d'appel pour toute anomalie) : version du dictionnaire, une ligne
# exactement, forme (colonnes et types, par constater_forme()), puis domaine. Rend la ligne
# en liste (date_extraction, debut_historique...).
.controler_extraction_base <- function(extraction, dico) {
  controler_version_extraction(extraction)
  refus <- function(message, ...) {
    refuser(paste0("table extraction : ", message), "extraction_invalide", module = "donnees",
            table = "extraction", ...)
  }
  if (nrow(extraction) != 1L) {
    refus(paste0("une ligne exactement attendue, ", nrow(extraction), " re\u00e7ue(s)"),
          nombre = nrow(extraction), attendu = "1", recu = as.character(nrow(extraction)))
  }
  forme <- constater_forme(extraction, "extraction", dico)
  if (nrow(forme) > 0L) {
    refuser(paste0("controler_base() : ", forme$message[1L]), forme$code[1L], module = "donnees",
            table = "extraction", colonne = forme$colonne[1L], nombre = nrow(forme),
            attendu = forme$attendu[1L], recu = forme$recu[1L])
  }
  colonnes <- dico$colonnes[dico$colonnes$table == "extraction", , drop = FALSE]
  for (i in seq_len(nrow(colonnes))) {
    colonne <- colonnes$colonne[i]
    x <- extraction[[colonne]]
    if (is.na(x)) refus(paste0("colonne ", colonne, " manquante"), colonne = colonne)
    if (colonnes$type[i] == "Date" && as.numeric(x) < as.numeric(as.Date("1901-01-01"))) {
      refus(paste0("colonne ", colonne, " ant\u00e9rieure au 1901-01-01"), colonne = colonne, recu = format(x))
    }
    modalites <- eclater_champ(colonnes$modalites[i])
    if (length(modalites) > 0L && !(x %in% modalites)) {
      refus(paste0("colonne ", colonne, " hors domaine : \u00ab ", x, " \u00bb"), colonne = colonne,
            attendu = paste(modalites, collapse = ";"), recu = x)
    }
  }
  if (extraction$debut_historique >= extraction$date_extraction) {
    refus("debut_historique doit pr\u00e9c\u00e9der date_extraction", colonne = "debut_historique",
          recu = format(extraction$debut_historique))
  }
  list(date_extraction = extraction$date_extraction, debut_historique = extraction$debut_historique)
}

# Éclate un champ « a;b » d'un CSV du dictionnaire ; sans point : appelée aussi par `plan`.
eclater_champ <- function(x) if (identical(x, "") || is.na(x)) character(0) else strsplit(x, ";", fixed = TRUE)[[1L]]

.refus_plan <- function(message) {
  refuser(paste0("controler_base() : ", message), "plan_invalide", module = "donnees")
}

# Section `conventions` du plan (M153) : NULL (aucune convention fournie) ou liste nommée
# d'entrées connues (ENTREES_CONVENTIONS) ; seules `age` et `limite_age` sont lues ici,
# chacune contrôlée contre sa liste fermée (plan_invalide). Rend la liste (vide si NULL).
.lire_conventions <- function(conventions) {
  if (is.null(conventions)) return(list())
  if (!is.list(conventions) || is.data.frame(conventions) ||
      (length(conventions) > 0L && (is.null(names(conventions)) || anyNA(names(conventions)) ||
                                    any(!nzchar(names(conventions))) || anyDuplicated(names(conventions))))) {
    .refus_plan("`conventions` doit \u00eatre une liste nomm\u00e9e (section conventions du plan)")
  }
  inconnues <- setdiff(names(conventions), ENTREES_CONVENTIONS)
  if (length(inconnues) > 0L) {
    .refus_plan(paste0("conventions : entr\u00e9e(s) inconnue(s) : ", paste(inconnues, collapse = ", ")))
  }
  chaine_dans <- function(x, liste) is.character(x) && length(x) == 1L && !is.na(x) && x %in% liste
  if (!is.null(conventions$age) && !chaine_dans(conventions$age, CONVENTIONS_AGE)) {
    .refus_plan(paste0("conventions$age hors de la liste ferm\u00e9e (", paste(CONVENTIONS_AGE, collapse = ", "), ")"))
  }
  la <- conventions$limite_age
  if (!is.null(la)) {
    if (!is.list(la) || is.data.frame(la) || !setequal(names(la), c("regle", "age")) || length(la) != 2L) {
      .refus_plan("conventions$limite_age doit porter `regle` et `age`, et eux seuls")
    }
    if (!chaine_dans(la$regle, REGLES_LIMITE_AGE)) {
      .refus_plan("conventions$limite_age$regle : atteinte ou depassement")
    }
    if (!chaine_dans(la$age, CONVENTIONS_LIMITE_AGE)) {
      .refus_plan("conventions$limite_age$age : revolu ou millesime (naissance r\u00e9elle de l'enfant)")
    }
  }
  conventions
}

# Sous-schéma `donnees` du plan (ADR 0010, point 17) : NULL (aucune déclaration fournie,
# M148) ou liste nommée de rubriques connues (RUBRIQUES_DECLARATIONS). Rend la liste, avec
# `exclusions` et `hypotheses` mises sous forme de data.frame (.table_declarations()).
# `exclusions` : motif d'un défaut admettant X (code du § 9, sous-cas lettrés compris),
# famille de FAMILLES_CALCUL, action de ACTIONS_EXCLUSION, une ligne par (motif, famille),
# hors des couples traités S (.exceptions_famille()), D03g en `exclure` seulement ;
# `hypotheses` : motif d'un défaut admettant H (ou, pour la valeur .VALEUR_SIGNALEMENT, motif
# de .motifs_signalement(), seule ligne de son (motif, referentiel)), référentiel de
# REFERENTIELS, poste (ou `tous`) et valeur en chaînes, une ligne par (motif, referentiel,
# poste), valeur de la forme de son motif (.forme_hypothese_admise(), ligne lue ou non ; seul
# contrôle de cette forme, erratum v1.0.21 de la spécification de B2, #99) ; D02a, D02b et
# D03g : poste `tous`, même valeur pour les deux référentiels, sans signalement (M717). D07, D10 et D11 se déclarent par sous-cas (traitements du sous-cas,
# .codes_a_sous_cas()). Un motif à traitement
# unique (.MOTIFS_TRAITEMENT_UNIQUE) ne se déclare pas dans les deux rubriques (D8).
# `seuils` : liste nommée ; d03g_delai_jours (liste nommée par table de D03g, jours entiers
# positifs ou nuls), d02c_age_min et d02c_age_max (listes nommées par emploi de D02c) et
# d07b_mois (nombre, entier de 1 à .MOIS_D07B_MAX) sont lus ; `evaluations_gestion` : liste réduite à `diagnostics`
# (logical), lue par les diagnostics (B2), jamais par le bilan. Sans point : appelée aussi par
# valider_plan() (`plan`), non exportée.
lire_declarations <- function(declarations, dico) {
  if (is.null(declarations)) declarations <- list()
  nommee <- function(x) {
    is.list(x) && !is.data.frame(x) &&
      (length(x) == 0L || (!is.null(names(x)) && !anyNA(names(x)) && all(nzchar(names(x))) && !anyDuplicated(names(x))))
  }
  if (!nommee(declarations)) {
    .refus_plan("`declarations` doit \u00eatre une liste nomm\u00e9e (sous-sch\u00e9ma donnees du plan)")
  }
  inconnues <- setdiff(names(declarations), RUBRIQUES_DECLARATIONS)
  if (length(inconnues) > 0L) {
    .refus_plan(paste0("declarations : rubrique(s) inconnue(s) : ", paste(inconnues, collapse = ", ")))
  }
  if (!is.null(declarations$seuils) && !nommee(declarations$seuils)) {
    .refus_plan("declarations$seuils doit \u00eatre une liste nomm\u00e9e")
  }
  eg <- declarations$evaluations_gestion
  if (!is.null(eg) && (!nommee(eg) || !identical(names(eg), "diagnostics") || !is.logical(eg$diagnostics) ||
                       length(eg$diagnostics) != 1L || is.na(eg$diagnostics))) {
    .refus_plan("declarations$evaluations_gestion doit porter `diagnostics` (TRUE ou FALSE), et lui seul")
  }
  dl <- declarations$seuils[[SEUIL_DELAI_D03G]]
  if (!is.null(dl)) {
    jours <- function(x) is.numeric(x) && length(x) == 1L && is.finite(x) && x >= 0 && x == round(x)
    if (!nommee(dl) || length(dl) == 0L || !all(names(dl) %in% .TABLES_D03G) || !all(vapply(dl, jours, NA))) {
      .refus_plan(paste0("declarations$seuils$", SEUIL_DELAI_D03G, " : liste nomm\u00e9e par table de D03g (",
                         paste(.TABLES_D03G, collapse = ", "), "), d\u00e9lai en jours (nombre entier positif ou nul)"))
    }
  }
  for (nom in SEUILS_AGE_D02C) {
    sa <- declarations$seuils[[nom]]
    if (is.null(sa)) next
    age <- function(x) is.numeric(x) && length(x) == 1L && is.finite(x) && x >= 0 && x == round(x)
    if (!nommee(sa) || length(sa) == 0L || !all(names(sa) %in% names(.EMPLOIS_D02C)) || !all(vapply(sa, age, NA))) {
      .refus_plan(paste0("declarations$seuils$", nom, " : liste nomm\u00e9e par emploi de D02c (",
                         paste(names(.EMPLOIS_D02C), collapse = ", "), "), \u00e2ge en ann\u00e9es enti\u00e8res positif ou nul"))
    }
  }
  mois <- declarations$seuils[[SEUIL_MOIS_D07B]]
  if (!is.null(mois) && !(is.numeric(mois) && is.null(dim(mois)) && length(mois) == 1L && is.finite(mois) && mois >= 1 &&
                          mois == round(mois) && mois <= .MOIS_D07B_MAX)) {
    .refus_plan(paste0("declarations$seuils$", SEUIL_MOIS_D07B, " : nombre de mois de D07 (b), entier au moins \u00e9gal \u00e0 1",
                       " et au plus ", format(.MOIS_D07B_MAX, scientific = FALSE), " (limite de calcul de ajouter_mois())"))
  }
  amin <- declarations$seuils[[SEUILS_AGE_D02C[1L]]]
  amax <- declarations$seuils[[SEUILS_AGE_D02C[2L]]]
  communs <- intersect(names(amin), names(amax))
  if (any(vapply(communs, function(e) amin[[e]] > amax[[e]], NA))) {
    .refus_plan("declarations$seuils : d02c_age_min sup\u00e9rieur \u00e0 d02c_age_max pour un emploi")
  }
  ex <- .table_declarations(declarations$exclusions, c("motif", "famille", "action"), "exclusions")
  # un motif à sous-cas se déclare par sous-cas (D07a à D07c, D10a à D10f et D10h, D11a à D11c) :
  # D07, D10 ou D11 seul est refusé (réserve m1 ; spécification `donnees` v1.9, § 9.5 et § 9.6)
  parents <- .codes_a_sous_cas(dico)
  if (!all(.motif_admet(dico, ex$motif, "X")) || any(ex$motif %in% parents) || !all(ex$famille %in% FAMILLES_CALCUL) ||
      !all(ex$action %in% ACTIONS_EXCLUSION) || anyDuplicated(ex[, c("motif", "famille")])) {
    .refus_plan(paste0("declarations$exclusions : motif d'un d\u00e9faut trait\u00e9 X (D07, D10 et D11 par sous-cas), famille (",
                       paste(FAMILLES_CALCUL, collapse = ", "), "), action (exclure, conserver), ",
                       "une ligne par (motif, famille)"))
  }
  exceptions <- .exceptions_famille(dico)
  if (any(paste(ex$motif, ex$famille) %in% paste(exceptions$motif, exceptions$famille))) {
    .refus_plan(paste0("declarations$exclusions : D03a est un signalement pour la famille triangle, D12 pour les familles ",
                       "triangle, risque_en_cours et regle_comptable (dictionnaire, \u00a7 9 ; sp\u00e9cification donnees v1.6, \u00a7 8.8)"))
  }
  if (any(ex$motif == "D03g" & ex$action != "exclure")) {
    .refus_plan("declarations$exclusions : D03g n'admet que l'action exclure (la ligne sort de la vue)")
  }
  hy <- .table_declarations(declarations$hypotheses, c("motif", "referentiel", "poste", "valeur"), "hypotheses")
  signalement <- hy$valeur == .VALEUR_SIGNALEMENT
  motifs_s <- .motifs_signalement(dico)
  if (!all(.motif_admet(dico, hy$motif, "H") | signalement) || !all(hy$motif %in% motifs_s | !signalement) ||
      any(hy$motif %in% parents) || !all(hy$referentiel %in% REFERENTIELS) ||
      anyDuplicated(hy[, c("motif", "referentiel", "poste")])) {
    .refus_plan(paste0("declarations$hypotheses : motif d'un d\u00e9faut trait\u00e9 H, ou la valeur ",
                       .VALEUR_SIGNALEMENT, " pour un motif dont S est un choix (",
                       paste(motifs_s, collapse = ", "), ") (D07, D10 et D11 par sous-cas), r\u00e9f\u00e9rentiel (",
                       paste(REFERENTIELS, collapse = ", "), "), une ligne par (motif, referentiel, poste)"))
  }
  # un signalement déclaré est la seule ligne de son (motif, referentiel)
  cle_s <- paste(hy$motif, hy$referentiel)
  if (any(cle_s[signalement] %in% cle_s[duplicated(cle_s) | duplicated(cle_s, fromLast = TRUE)])) {
    .refus_plan(paste0("declarations$hypotheses : la valeur ", .VALEUR_SIGNALEMENT,
                       " est la seule ligne de son (motif, referentiel)"))
  }
  # motifs de la vue commune (règle P et D02a : une seule vue pour les postes et les deux référentiels) :
  # poste `tous`, même valeur pour les deux référentiels, aucun signalement déclaré (réserve Q4
  # d'`actuary` ; D02a, M717 : une hypothèse déclarée pour un seul poste rendait les dates
  # inconnues pour tous les postes)
  p <- hy[hy$motif %in% .MOTIFS_HYPOTHESE_VUE_COMMUNE, , drop = FALSE]
  if (any(p$poste != "tous") || any(p$valeur == .VALEUR_SIGNALEMENT) ||
      any(vapply(split(p$valeur, p$motif), function(x) length(unique(x)) > 1L, NA))) {
    .refus_plan(paste0("declarations$hypotheses : D02a, D02b et D03g portent le poste tous, la m\u00eame valeur pour les deux ",
                       "r\u00e9f\u00e9rentiels, et ne se signalent pas (S \u00e0 l'extraction seulement)"))
  }
  # forme de la valeur de toute ligne déclarée, lue ou non, pour tout référentiel et tout poste
  # (spécification de B2, erratum v1.0.21, § 2.3, #99) : seul lieu de ce contrôle, appliqué
  # par valider_plan(), controler_base() et vue_a_date() ; un signalement admis ci-dessus a sa
  # forme
  for (i in which(!signalement)) {
    if (!.forme_hypothese_admise(hy$motif[i], hy$valeur[i])) {
      .refus_plan(paste0("declarations$hypotheses : ", hy$motif[i], " (", hy$referentiel[i], ", ", hy$poste[i],
                         ") : valeur \u00ab ", hy$valeur[i], " \u00bb, forme attendue : ",
                         .TEXTES_FORME_HYPOTHESE[[.FORMES_HYPOTHESE[[hy$motif[i]]]]]))
    }
  }
  # motif à traitement unique déclaré à la fois en exclusion et en hypothèse (D8)
  double <- intersect(intersect(ex$motif, hy$motif), .MOTIFS_TRAITEMENT_UNIQUE)
  if (length(double) > 0L) {
    .refus_plan(paste0("declarations : ", paste(double, collapse = ", "), " (traitement unique, dictionnaire, \u00a7 9) ",
                       "d\u00e9clar\u00e9 \u00e0 la fois dans exclusions et dans hypotheses"))
  }
  declarations$exclusions <- ex
  declarations$hypotheses <- hy
  declarations
}

# Forme de la `valeur` d'une ligne de `hypotheses`, par motif qui admet H (dictionnaire 1.6, § 9,
# tableau « Forme de la valeur des hypothèses H » ; spécification de B2, erratum v1.0.21, § 2.3,
# #99) : `regle`, la chaîne exacte ; `d03b`, `d03c`, `d05`, listes par clé ; `d03e`, catégorie ;
# `d03h`, `d13`, décimaux bornés. Égalité des motifs avec ceux de defauts.csv qui admettent H
# (sous-cas lettrés, sans les parents) contrôlée par tests/unitaires/plan.R. La valeur
# `signalement` est contrôlée à part (.motifs_signalement()).
.FORMES_HYPOTHESE <- c(D02a = "regle", D02b = "regle", D03a = "regle", D03b = "d03b", D03c = "d03c", D03d = "regle",
                       D03e = "d03e", D03f = "regle", D03g = "regle", D03h = "d03h", D05 = "d05", D06 = "regle",
                       D07a = "regle", D07c = "regle", D08 = "regle", D09 = "regle", D10f = "regle", D13 = "d13",
                       D14 = "regle")
# Forme attendue, nommée par le message de refus.
.TEXTES_FORME_HYPOTHESE <- c(
  regle = "la cha\u00eene regle",
  d03b = paste0("liste par cl\u00e9 <cle>=<valeur> jointe par \u00ab ; \u00bb (sans blanc ni \u00e9l\u00e9ment vide, cl\u00e9s ",
                "distinctes parmi assure, conjoint, enfant, autre ; valeur F ou M, et pour conjoint aussi oppose_assure ",
                "ou identique_assure)"),
  d03c = paste0("liste par cl\u00e9 <college>=<montant> jointe par \u00ab ; \u00bb (sans blanc ni \u00e9l\u00e9ment vide, ",
                "coll\u00e8ges distincts du domaine de college, montant de forme [0-9]+(.[0-9]+)? fini en double)"),
  d05 = paste0("liste par cl\u00e9 <cle>=<valeur> jointe par \u00ab ; \u00bb (sans blanc ni \u00e9l\u00e9ment vide), exactement ",
               "les cl\u00e9s motif (sans_suite ou refus) et decompte (compte ou non_compte)"),
  d03e = "cat1, cat2 ou cat3",
  d03h = "d\u00e9cimal -?[0-9]+(.[0-9]+)?([eE][-+]?[0-9]+)? dans [-0,05 ; 0,10]",
  d13 = "d\u00e9cimal -?[0-9]+(.[0-9]+)?([eE][-+]?[0-9]+)? dans [0 ; 1]")
# Écriture d'un décimal (D03h, D13) et d'un montant de D03c (forme stricte de M315, M757).
.FORME_DECIMAL <- "^-?[0-9]+(\\.[0-9]+)?([eE][-+]?[0-9]+)?$"
.FORME_MONTANT_D03C <- "^[0-9]+(\\.[0-9]+)?$"

# Vrai si `valeur` (chaîne renseignée, non vide) a la forme admise pour le motif `motif` (code de
# .FORMES_HYPOTHESE ; un autre code est une erreur interne). Liste par clé : éléments
# <cle>=<valeur> joints par « ; », au moins un, aucun vide (ni « ; » en tête, en fin ou doublé),
# aucun blanc de `.BLANCS`, clés distinctes, ordre libre ; la clé va jusqu'au premier « = ».
# Décimal : bornes incluses, comparées sur le double lu, sans tolérance. Collège de D03c : domaine
# de college (M656 : non vide, sans blanc, ni « ; », ni « = ») ; montant fini une fois lu en double.
.forme_hypothese_admise <- function(motif, valeur) {
  forme <- .FORMES_HYPOTHESE[motif]
  if (is.na(forme)) {
    stop("erreur interne de provie : motif ", motif, " sans forme de valeur (.FORMES_HYPOTHESE)", call. = FALSE)
  }
  liste <- function() {
    if (.contient_blanc(valeur) || startsWith(valeur, ";") || endsWith(valeur, ";")) return(NULL)
    el <- strsplit(valeur, ";", fixed = TRUE)[[1L]]
    if (length(el) == 0L || !all(nzchar(el)) || !all(grepl("=", el, fixed = TRUE))) return(NULL)
    p <- regexpr("=", el, fixed = TRUE)
    cles <- substr(el, 1L, p - 1L)
    if (anyDuplicated(cles)) return(NULL)
    list(cles = cles, valeurs = substring(el, p + 1L))
  }
  decimal <- function(min, max) {
    if (!grepl(.FORME_DECIMAL, valeur)) return(FALSE)
    x <- as.numeric(valeur)
    x >= min && x <= max
  }
  switch(forme,
    regle = identical(valeur, "regle"),
    d03e = valeur %in% c("cat1", "cat2", "cat3"),
    d03h = decimal(-0.05, 0.10),
    d13 = decimal(0, 1),
    d03b = {
      l <- liste()
      !is.null(l) && all(l$cles %in% c("assure", "conjoint", "enfant", "autre")) &&
        all(l$valeurs %in% c("F", "M") | (l$cles == "conjoint" & l$valeurs %in% c("oppose_assure", "identique_assure")))
    },
    d05 = {
      l <- liste()
      !is.null(l) && length(l$cles) == 2L && setequal(l$cles, c("motif", "decompte")) &&
        l$valeurs[l$cles == "motif"] %in% c("sans_suite", "refus") &&
        l$valeurs[l$cles == "decompte"] %in% c("compte", "non_compte")
    },
    d03c = {
      l <- liste()
      !is.null(l) && all(nzchar(l$cles)) && all(grepl(.FORME_MONTANT_D03C, l$valeurs)) &&
        all(is.finite(as.numeric(l$valeurs)))
    })
}

# Familles de calcul d'une exclusion du motif `motif` : toutes, hors les couples traités S
# (.exceptions_famille()).
.familles_x <- function(dico, motif) {
  ef <- .exceptions_famille(dico)
  setdiff(FAMILLES_CALCUL, ef$famille[ef$motif == motif])
}

# Application de D03g à la vue pour la table `table` (décisions du mainteneur, D5 et D9) :
# "X" si l'exclusion (exclure) est déclarée pour les quatre familles, pour une ligne entière
# seulement (`partie` NA) ; "H" si l'hypothèse est déclarée pour les deux référentiels et le
# délai de la table dans seuils$d03g_delai_jours ; NA sinon (déclaration incomplète :
# visibilité non déterminée). Une partie de ligne (fin d'un contrat ou d'une affiliation)
# n'est résolue que par l'hypothèse (D9). Déclarées ensemble (D11, lecture (i)), l'exclusion
# l'emporte pour toutes les lignes entières, l'hypothèse résout les parties de ligne.
.application_d03g <- function(ctx, table, partie = NA_character_) {
  ex <- ctx$declarations$exclusions
  hy <- ctx$declarations$hypotheses
  if (is.na(partie) && all(FAMILLES_CALCUL %in% ex$famille[ex$motif == "D03g"])) return("X")
  if (all(REFERENTIELS %in% hy$referentiel[hy$motif == "D03g"]) &&
      !is.null(ctx$declarations$seuils[[SEUIL_DELAI_D03G]][[table]])) return("H")
  NA_character_
}

# Motifs (codes du § 9, sous-cas lettrés compris : lignes de defauts.csv depuis la version 1.6,
# la lettre g de D10 n'étant attribuée à aucun) dont le traitement admet `t`
# (defauts.csv$traitements ; un sous-cas lit son propre traitement, .traitements_sous_cas()).
.motif_admet <- function(dico, motif, t) {
  traitements <- dico$defauts$traitements[match(motif, dico$defauts$code)]
  !is.na(traitements) & vapply(traitements, function(x) t %in% eclater_champ(x), NA, USE.NAMES = FALSE)
}

# Rubrique `exclusions` ou `hypotheses` du sous-schéma `donnees` (« liste de triplets »,
# ADR 0010, point 17) : NULL, data.frame aux colonnes `colonnes` (exactement), ou liste de
# listes nommées de ces seuls éléments ; chaque valeur est une chaîne renseignée et non
# vide. Rend un data.frame de ces colonnes, dans cet ordre (plan_invalide sinon).
.table_declarations <- function(x, colonnes, rubrique) {
  vide <- as.data.frame(stats::setNames(rep(list(character(0)), length(colonnes)), colonnes), stringsAsFactors = FALSE)
  refus <- function() {
    .refus_plan(paste0("declarations$", rubrique, " : data.frame ou liste de listes nomm\u00e9es portant ",
                       paste(colonnes, collapse = ", "), " (cha\u00eenes renseign\u00e9es), et eux seuls"))
  }
  if (is.null(x)) return(vide)
  chaine <- function(v) is.character(v) && !anyNA(v) && all(nzchar(v))
  if (is.data.frame(x)) {
    if (!setequal(names(x), colonnes) || ncol(x) != length(colonnes) || !all(vapply(x, chaine, NA))) refus()
    df <- x[, colonnes, drop = FALSE]
  } else {
    if (!is.list(x) || !is.null(attr(x, "dim"))) refus()
    ok <- vapply(x, function(e) {
      is.list(e) && !is.data.frame(e) && !is.null(names(e)) && setequal(names(e), colonnes) &&
        length(e) == length(colonnes) && all(vapply(e, function(v) chaine(v) && length(v) == 1L, NA))
    }, NA)
    if (!all(ok)) refus()
    if (length(x) == 0L) return(vide)
    df <- as.data.frame(lapply(stats::setNames(colonnes, colonnes), function(c1) vapply(x, `[[`, "", c1)),
                        stringsAsFactors = FALSE)
  }
  rownames(df) <- NULL
  df
}

# --- Contexte et enregistrement des constats -----------------------------------------

# Environnement de travail d'un appel : base, dictionnaire, colonnes inutilisables (motif
# du refus qui empêche de les lire), constats et contrôles non exécutés accumulés.
.contexte <- function(donnees, dico, extraction, arrete) {
  ctx <- new.env(parent = emptyenv())
  ctx$base <- donnees
  ctx$dico <- dico
  # ordre des codes (.ordre_codes()), calculé à sa première lecture, une fois par contrôle (#55)
  delayedAssign("ordre_codes", .ordre_codes(dico), assign.env = ctx)
  ctx$date_extraction <- extraction$date_extraction
  ctx$arrete <- arrete
  ctx$tables <- dico$tables$table[dico$tables$table %in% names(donnees)]
  ctx$inutilisable <- list()
  ctx$constats <- list()
  ctx$non_executes <- list()
  ctx$requises <- list()
  ctx
}

.colonnes_dico <- function(ctx, table) ctx$dico$colonnes[ctx$dico$colonnes$table == table, , drop = FALSE]

# Valeurs d'une colonne : celles de la table ; une colonne facultative absente vaut une
# colonne entièrement manquante de son type (dictionnaire, § 1.2) ; une table absente
# (facultative) vaut une table sans ligne.
.valeurs <- function(ctx, table, colonne) {
  df <- ctx$base[[table]]
  n <- if (is.null(df)) 0L else nrow(df)
  if (!is.null(df) && colonne %in% names(df)) return(df[[colonne]])
  type <- .colonnes_dico(ctx, table)$type[.colonnes_dico(ctx, table)$colonne == colonne]
  switch(type, character = rep(NA_character_, n), integer = rep(NA_integer_, n),
         numeric = rep(NA_real_, n), logical = rep(NA, n),
         Date = structure(rep(NA_real_, n), class = "Date"))
}

# Motif qui empêche de lire `table.colonne`, NA si elle se lit. En règle B, seuls les écarts
# de forme rendent une colonne inutilisable ; après la règle B (règles P et V, vue), tout
# refus R aussi (.refus_regle_b()) : une table refusée n'est plus lue, une colonne refusée
# non plus (spécification, § 2.2 et § 4.2). `forme_seule` : écarts de forme seulement
# (identifiants du bilan). Les refus de portée table de la table et la cause propre de la
# colonne sont en concurrence : la cause rendue est la plus petite dans l'ordre (rang,
# position) (.cause_retenue() ; spécification `donnees` v1.6, § 3.1, départage à rang égal,
# #59 ; la table n'a plus la préséance). `.causes()` rend ces causes candidates (`propre` :
# FALSE pour taire la cause propre de la colonne, .regle()), sans doublon.
.causes <- function(ctx, table, colonne, forme_seule = FALSE, propre = TRUE) {
  causes <- ctx$inutilisable[[table]]
  forme <- if (propre && !is.null(causes) && colonne %in% names(causes)) causes[[colonne]]
  if (forme_seule || is.null(ctx$refus_pv)) return(forme)
  t <- ctx$refus_pv$tables[[table]]
  c1 <- ctx$refus_pv$colonnes[[table]]
  unique(c(t, if (propre && colonne %in% names(c1)) c1[[colonne]], forme))
}
.cause <- function(ctx, table, colonne, forme_seule = FALSE) {
  .cause_retenue(.causes(ctx, table, colonne, forme_seule), ctx$dico, ctx$ordre_codes)
}

# Refus de valeur de `table.colonne` (M199 ; spécification, § 2.2) : refus R de portée
# colonne identifiés par ligne (manquant_obligatoire, hors_domaine, chaine_vide, D02c date
# hors bornes, tout refus R de portée colonne autre qu'un écart de forme), après la règle B,
# sur une table non refusée en portée table et une colonne lisible par sa forme (un défaut de
# forme garde la portée table, M178). `.refus_valeur_de()` rend la liste (code, lignes) de ces
# refus, dans l'ordre des constats, NULL sans refus de valeur ; `.lignes_refusees()` l'union
# de leurs lignes, NULL sans refus de valeur. Pendant la règle B (`refus_pv` NULL), les refus
# de valeur déjà émis (.ajouter_constat()), complets pour les colonnes des strates déjà
# évaluées (règle B à trois valeurs, .regle_domaine()) ; la règle B lit une table refusée en
# portée table comme les autres, seuls les refus de valeur y rendent une valeur inconnue
# (spécification, § 2.2, B.5).
.CODES_FORME <- c("colonne_absente", "colonne_inconnue", "type_incompatible")
# Refus de portée table induits (sans écart propre de l'enjeu, origine relue par
# .refus_regle_b()) : refus_induit (clé étrangère vers une table refusée) et vue_empechee
# (vue empêchée par un défaut de forme, dictionnaire 1.6, P12 ; spécification `donnees` v1.9,
# § 9.1 : traitement du refus_induit né d'une vue empêchée).
.CODES_INDUITS <- c("refus_induit", "vue_empechee")
.refus_valeur_de <- function(ctx, table, colonne) {
  if (is.null(ctx$refus_pv)) return(ctx$refus_valeur[[table]][[colonne]])
  if (!is.null(ctx$refus_pv$tables[[table]])) return(NULL)
  if (!is.na(.cause(ctx, table, colonne, forme_seule = TRUE))) return(NULL)
  ctx$refus_valeur[[table]][[colonne]]
}
.lignes_refusees <- function(ctx, table, colonne) {
  r <- .refus_valeur_de(ctx, table, colonne)
  if (is.null(r)) NULL else sort(unique(unlist(lapply(r, `[[`, "lignes"))))
}

# Constat ; pendant la règle B, un refus de valeur (.refus_de_valeur()) est aussi rangé dans
# `refus_valeur`, lu par les règles des strates suivantes (.refus_valeur_de()).
.ajouter_constat <- function(ctx, code, table, colonne, lignes, traitement, detection,
                             portee = NA_character_, origine = NA_character_) {
  k <- list(code = code, table = table, colonne = colonne, lignes = sort(unique(as.integer(lignes))),
            traitement = traitement, detection = detection, portee = portee, origine = origine)
  ctx$constats[[length(ctx$constats) + 1L]] <- k
  if (is.null(ctx$refus_pv) && .refus_de_valeur(ctx$dico, k)) {
    v1 <- ctx$refus_valeur[[table]]
    v1[[colonne]] <- c(v1[[colonne]], list(list(code = code, lignes = k$lignes)))
    ctx$refus_valeur[[table]] <- v1
  }
  invisible(NULL)
}

# Refus de valeur (M199) : constat R de portée effective autre que table (`ligne` depuis #72),
# hors écart de forme.
.refus_de_valeur <- function(dico, k) {
  k$traitement == "R" && !(k$code %in% .CODES_FORME) && .portee_effective(dico, k$code, k$table, k$colonne) != "table"
}

# Valeur inconnue de D03i (M701 ; spécification `donnees` v1.9, § 9.6) : pour toute règle autre
# que la détection de D03i, une cellule manquante d'une colonne de D03i (.COLONNES_D03I) est une
# valeur inconnue, par le mécanisme d'une valeur refusée (.refus_valeur_de(), .inconnu(),
# .cause() : règle B ou P partielle, règle V qui la lit comme valeur bloquée, M169 ; à un arrêté
# antérieur à l'extraction, ligne de visibilité non déterminée sous D03i, d'origine
# « table.colonne », .refus_vue()), cause D03i au rang 3, sans ligne de refus_tables (le constat
# D03i est traité X, non R). Rangée dans `refus_valeur` au début de la règle B (.regle_domaine())
# et à chaque reconstruction après la règle B (.refus_regle_b()), avant les refus des constats ;
# une colonne illisible par sa forme n'en reçoit pas (le défaut de forme l'emporte).
# `.inconnues_d03i()` : liste (table, colonne, lignes) des cellules manquantes.
.inconnues_d03i <- function(ctx) {
  res <- list()
  for (t in intersect(names(.COLONNES_D03I), names(ctx$base))) {
    c1 <- .COLONNES_D03I[[t]]
    if (!(c1 %in% names(ctx$base[[t]])) || !is.null(ctx$inutilisable[[t]][[c1]])) next
    l <- which(is.na(ctx$base[[t]][[c1]]))
    if (length(l) > 0L) res[[length(res) + 1L]] <- list(table = t, colonne = c1, lignes = l)
  }
  res
}
.ranger_inconnues_d03i <- function(valeurs, inconnues) {
  for (x in inconnues) {
    v1 <- valeurs[[x$table]]
    v1[[x$colonne]] <- c(list(list(code = "D03i", lignes = x$lignes)), v1[[x$colonne]])
    valeurs[[x$table]] <- v1
  }
  valeurs
}

.ajouter_non_execute <- function(ctx, code, table, colonne, cause, lu = NA_character_) {
  ctx$non_executes[[length(ctx$non_executes) + 1L]] <- list(code = code, table = table,
                                                            colonne = colonne, cause = cause, lu = lu)
  invisible(NULL)
}

# Exécute une règle de détection sur `table` : si une colonne lue (`lit`, chaînes
# « table.colonne », la colonne contrôlée comprise) est inutilisable, la règle va dans
# controles_non_executes avec le motif du refus ; sinon `f()` rend un vecteur logique d'une
# valeur par ligne de `table` (NA : non détecté) et les lignes vraies forment un constat.
# Une cause directe (forme ou refus d'une colonne lue) prime sur tout refus induit (règle B
# ou règle P empêchée, D12) : ce refus_induit n'est la cause que d'une règle autrement
# exécutable (avis d'`actuary`, point 4 ; M185). `colonne_ne` : colonne de la ligne non exécutée
# (NA pour un sous-cas qui ne doit pas se confondre avec la règle écrite sur la colonne,
# ADR 0010, huitième série, (b)). Rend les numéros des lignes détectées (aucun pour une
# table absente ; NULL si la règle n'est pas exécutée).
# Refus de valeur (refus R de portée colonne identifié par ligne, .lignes_refusees() ; M199,
# M200, issue #33). `vue` : colonnes lues pour établir la vue seulement (règle V) ; leur refus
# de valeur ne bloque pas la règle et n'en est pas une cause, les lignes refusées étant hors de
# la vue (visibilité non déterminée) ; une colonne aussi lue comme valeur (`lit`, colonne
# contrôlée) bloque toujours (M169), hors mode Kleene (`kleene`, ci-dessous). `partiel`
# (règle P) : `f()` rend un verdict à trois
# valeurs, une valeur refusée étant inconnue (logique de Kleene, .avant3()) ; la règle
# s'exécute sur les lignes au verdict déterminé et écarte celles au verdict inconnu (NA) ; si
# elle en écarte une, elle garde sa ligne dans controles_non_executes, cause = le plus petit,
# dans l'ordre (rang, position) (.cause_retenue()), des motifs de tous les refus de valeur qui
# touchent une ligne écartée : refus d'une colonne de la table sur une ligne écartée, refus
# d'une colonne de la parente sur une parente d'une ligne écartée (`parente` : colonne de clé
# de la fille, table et colonne de clé de la parente ; spécification, § 2.2, (b)) (détection
# partielle, nombre minorant). Toute autre cause (forme, refus de portée table) bloque la
# règle ; la cause rendue est alors la plus petite des causes des colonnes lues qui bloquent,
# hors colonnes dont le refus de valeur ne bloque pas (`vue` seule ; toute colonne lue en mode
# `partiel`) (spécification `donnees` v1.6, § 3.1, départage à rang égal, #59).
# Règle B à trois valeurs (`partiel` pendant la règle B ; spécification, § 2.2, B.1 à B.5 ;
# M217, issue #42) : même mécanisme, sur les refus de valeur des strates déjà évaluées ; une
# règle de portée colonne lit la colonne qu'elle contrôle telle quelle (auto-lecture, P4), qui
# n'est ni une colonne à valeur inconnue ni une cause. `f()` peut porter l'attribut `index`
# (.verdict3()) : par colonne lue « table.colonne », lignes de sa table jointes à chaque ligne
# de la règle, lues pour la cause d'une ligne écartée. Pendant la règle B, le répartiteur
# (.regle_domaine(), .regles_b()) choisit les règles à exécuter par `ctx$passe` (fonction de
# code, table, colonne, lit, traitement ; NULL hors de ses passes) : une règle qu'il écarte
# n'est ni exécutée ni bloquée et rend FALSE (#56, point 5).
# `kleene` (règle V en mode Kleene, .regle_vue() ; spécification `donnees`, erratum `1.9.7`,
# E-1, M808) : le refus de valeur d'aucune colonne lue ne bloque la règle, colonne contrôlée
# comprise (lue dans le mécanisme, E-1) ; `f()` rend un verdict à trois valeurs et
# .regle_vue() écarte les lignes au verdict inconnu, cause par .cause_nd() (un seul calcul de
# cause). Un défaut de forme ou un refus de portée table bloque toujours, comme ci-dessus.
# `f` NULL : causes de la règle bloquée seulement (sous-cas non exécuté faute de déclaration,
# D07b et D07c, qui reçoit aussi les causes candidates de sa branche déclarée ; spécification
# `donnees` v1.9.1, § 3.1 et § 9.6, point (3)) : bloquée, la règle émet sa ligne comme
# ci-dessus ; sinon rien n'est émis ni détecté et la règle rend integer(0).
.regle <- function(ctx, code, table, colonne, lit, traitement, detection, f, colonne_ne = colonne,
                   partiel = FALSE, vue = character(0), parente = NULL, kleene = FALSE) {
  if (!is.null(ctx$passe) && !ctx$passe(code, table, colonne, lit, traitement)) return(invisible(FALSE))
  if (is.null(ctx$base[[table]])) return(invisible(integer(0)))
  if (kleene && partiel) stop("erreur interne de provie : r\u00e8gle ", code, " : modes partiel et Kleene ensemble",
                              call. = FALSE)
  valeur <- unique(c(if (!is.na(colonne)) paste(table, colonne, sep = "."), lit))
  lit <- unique(c(valeur, vue))
  morceaux <- strsplit(lit, ".", fixed = TRUE)
  regle_b <- is.null(ctx$refus_pv)
  # lignes refusées pour leur valeur, par colonne lue dont le refus de valeur ne bloque pas ;
  # règle V en mode Kleene (.regle_vue()) : toute colonne lue, colonne contrôlée comprise
  admet <- if (kleene) {
    lit
  } else if (!partiel) {
    setdiff(vue, valeur)
  } else if (regle_b && !is.na(colonne) && .portee_effective(ctx$dico, code, table, colonne) != "table") {
    setdiff(lit, paste(table, colonne, sep = "."))
  } else {
    lit
  }
  refusees <- list()
  for (i in which(lit %in% admet)) {
    l <- .lignes_refusees(ctx, morceaux[[i]][1L], morceaux[[i]][2L])
    if (!is.null(l)) refusees[[lit[i]]] <- l
  }
  # une colonne refusée pour sa valeur n'est jamais la cause d'une règle bloquée : le défaut
  # de forme ou le refus de portée table l'emporte (spécification, § 2.2, cas limite 3)
  saute <- names(refusees)
  bloquee <- any(vapply(seq_along(lit), function(i) {
    !(lit[i] %in% names(refusees)) && !is.na(.cause(ctx, morceaux[[i]][1L], morceaux[[i]][2L]))
  }, NA))
  if (bloquee) {
    # sur une table refusée en portée table (.refus_valeur_de() y rend NULL), le refus de
    # valeur d'une colonne dont le refus de valeur ne bloque pas n'est pas une cause directe :
    # le refus de portée table, induit compris, l'emporte (spécification, § 2.2, cas limite 3,
    # et § 3.1) ; une colonne lue comme valeur garde sa cause directe (M169, M185)
    valeur_seule <- vapply(seq_along(lit), function(i) {
      t <- morceaux[[i]][1L]
      c1 <- morceaux[[i]][2L]
      lit[i] %in% admet && !is.null(ctx$refus_valeur[[t]][[c1]]) &&
        is.na(.cause(ctx, t, c1, forme_seule = TRUE))
    }, NA)
    # causes candidates de chaque colonne lue qui bloque (.causes() : refus de portée table de
    # sa table, induit compris, et cause propre de la colonne) ; la cause retenue est la plus
    # petite dans l'ordre (rang, position) (.cause_retenue()), refus_induit (rang 7) seulement
    # sans autre cause (spécification `donnees` v1.6, § 3.1, départage à rang égal, #59 ; M185).
    # `lu` : colonnes lues illisibles par leur forme, toutes (origine du refus induit d'une
    # règle P empêchée, .regle_prealable()), à défaut les colonnes qui portent la cause retenue
    candidates <- lapply(seq_along(lit), function(i) {
      if (lit[i] %in% saute) return(character(0))
      .causes(ctx, morceaux[[i]][1L], morceaux[[i]][2L], propre = !valeur_seule[i])
    })
    cause <- .cause_retenue(unlist(candidates), ctx$dico, ctx$ordre_codes)
    forme <- vapply(seq_along(lit), function(i) {
      !(lit[i] %in% saute) && !is.na(.cause(ctx, morceaux[[i]][1L], morceaux[[i]][2L], forme_seule = TRUE))
    }, NA)
    lu <- if (any(forme)) lit[forme] else lit[vapply(candidates, function(z) cause %in% z, NA)]
    .ajouter_non_execute(ctx, code, table, colonne_ne, cause, lu = sort(lu, method = "radix"))
    return(invisible(NULL))
  }
  if (is.null(f)) return(invisible(integer(0)))
  detecte <- f()
  if (partiel && (length(refusees) > 0L || regle_b)) {
    # verdict à trois valeurs (.avant3(), .manque3(), .verdict3()) : seules les lignes au verdict inconnu
    # (NA) sont écartées ; la ligne de controles_non_executes n'existe que s'il y en a une,
    # cause = le plus petit des motifs des refus de valeur qui touchent une ligne écartée :
    # refus d'une colonne de la table sur l'une d'elles, refus d'une colonne de la parente
    # (date de la parente d'une fille) sur une parente de l'une d'elles. Un verdict inconnu
    # procède toujours d'une valeur refusée d'une colonne lue (.inconnu()), ou d'une clé jointe
    # en double aux occurrences divergentes (D01a, .entree3()) : son absence est une erreur
    # interne.
    ecartees <- which(is.na(detecte))
    if (length(ecartees) > 0L) {
      # lignes de chaque table lue qui expliquent une ligne écartée : les lignes écartées
      # elles-mêmes ; pour la parente (`parente` : colonne de clé de la fille, table et colonne
      # de clé de la parente), ses lignes dont la clé est celle d'une ligne écartée (toutes les
      # versions de famille : branche défensive, la date de saisie de famille, colonne de clé,
      # n'étant jamais refusée pour sa valeur ; son refus, de portée table, bloque la règle
      # avant ce point)
      index <- attr(detecte, "index", exact = TRUE)
      touchees <- function(tc, u) {
        if (!is.null(index[[tc]])) return(unique(stats::na.omit(unlist(index[[tc]][ecartees]))))
        if (u == table) return(ecartees)
        if (is.null(parente) || u != parente[2L]) return(integer(0))
        which(!is.na(apparier_cles(.valeurs(ctx, u, parente[3L]), .valeurs(ctx, table, parente[1L])[ecartees])))
      }
      # motifs de tous les refus de valeur qui touchent une ligne écartée, sur toutes les
      # colonnes lues (`porteuses` : colonne de chacun) ; la cause est le plus petit dans
      # l'ordre (rang, position) (.cause_retenue() ; spécification `donnees` v1.6, § 2.2, B.5 et
      # (b), et § 3.1, départage à rang égal, #59 : ni l'ordre des colonnes lues ni celui des
      # constats, ni la préséance de la table) ; `lu` : colonnes qui portent la cause retenue
      motifs <- character(0)
      porteuses <- character(0)
      for (tc in names(refusees)) {
        m <- strsplit(tc, ".", fixed = TRUE)[[1L]]
        l <- touchees(tc, m[1L])
        for (r in .refus_valeur_de(ctx, m[1L], m[2L])) {
          if (length(intersect(r$lignes, l)) > 0L) {
            motifs <- c(motifs, r$code)
            porteuses <- c(porteuses, tc)
          }
        }
      }
      # clé jointe portée par k ≥ 2 lignes aux occurrences divergentes (attribut `d01a`,
      # .verdict3()) : cause candidate D01a, portée par la colonne lue (spécification `donnees`
      # v1.7, § 2.2, B.4, « Clé primaire en double », #131)
      d01a <- attr(detecte, "d01a", exact = TRUE)
      for (tc in names(d01a)) {
        if (any(d01a[[tc]][ecartees])) {
          motifs <- c(motifs, "D01a")
          porteuses <- c(porteuses, tc)
        }
      }
      if (length(motifs) == 0L) stop("erreur interne de provie : r\u00e8gle ", if (regle_b) "B" else "P",
                                     " : ligne \u00e9cart\u00e9e sans refus de valeur qui l'explique (", code, ", ", table, ")",
                                     call. = FALSE)
      cause <- .cause_retenue(motifs, ctx$dico, ctx$ordre_codes)
      .ajouter_non_execute(ctx, code, table, colonne_ne, cause,
                           lu = sort(unique(porteuses[motifs == cause]), method = "radix"))
    }
  }
  lignes <- which(detecte)
  if (length(lignes) > 0L) .ajouter_constat(ctx, code, table, colonne, lignes, traitement, detection)
  invisible(lignes)
}

# Traitement d'un code de contrôle de structure : colonne `traitement` de controles.csv
# (dictionnaire 1.6, P17 ; spécification `donnees` v1.9, § 9.6), qui remplace la règle
# provisoire d'`architect` (ADR 0010, sixième série, (a), et septième série, (d) : portée
# `ligne` -> S). Seul endroit où le traitement d'un code de contrôle est lu.
.traitement_code_controle <- function(dico, code) {
  traitement <- dico$controles$traitement[dico$controles$code == code]
  if (length(traitement) != 1L) stop("code de contr\u00f4le inconnu : ", code, call. = FALSE)
  traitement
}

# Portée effective d'un refus R (§ 1.10 du dictionnaire ; ADR 0010, sixième série, (b) 1) :
# `colonne_table` devient `table` pour une colonne de la clé primaire ou qui porte une
# référence, `colonne` sinon ; `ligne_table` (dictionnaire 1.6, #72) et tout défaut D.. de
# portée non fixée (D02c sur une date, D09 de signe) deviennent `table` pour une telle colonne,
# `ligne` sinon (refus de valeur identifié par ligne : spécification `donnees` v1.9, § 9.2 ;
# T1 levé) ; D10 (a) porte sur la table de la table fille (spécification, § 2.4) ; toute
# anomalie de evaluations_gestion refuse la table seule (dictionnaire, § 7.5). Dans `donnees`,
# `colonne` et `ligne` se lisent de même (portée autre que `table` : refus de colonne, règles B,
# P et V, vue) ; seuls l'enjeu par porteur (.refus_ligne_porteurs()) et l'arrêt des postes,
# hors de `donnees`, distinguent `ligne`.
.portee_effective <- function(dico, code, table, colonne) {
  if (table == "evaluations_gestion" || code == "D10a" || is.na(colonne)) return("table")
  portee <- dico$controles$portee[dico$controles$code == code]
  if (length(portee) == 1L && portee %in% c("table", "colonne")) return(portee)
  cle <- eclater_champ(dico$tables$cle_primaire[dico$tables$table == table])
  ref <- dico$colonnes$reference[dico$colonnes$table == table & dico$colonnes$colonne == colonne]
  if (colonne %in% cle || (length(ref) == 1L && nzchar(ref))) return("table")
  if (identical(portee, "colonne_table")) "colonne" else "ligne"
}

# --- Règle B à trois valeurs : graphe, strates, verdict -----------------------------

# Lectures de la règle B à trois valeurs (spécification, § 2.2, B.1 à B.3 ; M217, issue #42) :
# pour chaque colonne contrôlée (« table.colonne » ; « table.NA » pour un chevauchement) par
# une règle R concernée, colonnes non clés refusables pour leur valeur qu'elle lit, hors la
# colonne contrôlée (auto-lecture, P4). `colonne` : règles de portée colonne, arêtes du graphe
# de dépendance (colonne lue -> colonne contrôlée) ; `table` : règles de portée table, puits,
# évaluées après toutes les strates (les clés et les chevauchements, sites 39 à 41, à l'étape
# des clés). Graphe de référence de la spécification (§ 2.2, B.3) : l'exécution lit le graphe
# dérivé des règles enregistrées (.lectures_regle_b(), #56, point 4) ; l'acyclicité de la
# constante et son égalité au graphe dérivé, strates comprises, sont testées (critère B8).
.LECTURES_REGLE_B <- list(
  colonne = list(
    contrats.date_terme = c("contrats.nature_contrat", "garanties_souscrites.code_garantie"),
    contrats.motif_fin = "contrats.date_fin",
    contrats.date_saisie_fin = "contrats.date_fin",
    contrats.jour_echeance = "contrats.mois_echeance",
    garanties_souscrites.type_franchise = "garanties_souscrites.code_garantie",
    garanties_souscrites.regle_complement = "garanties_souscrites.code_garantie",
    garanties_souscrites.type_rente_conjoint = "garanties_souscrites.code_garantie",
    garanties_souscrites.option_iad = "garanties_souscrites.code_garantie",
    garanties_souscrites.periodicite_prestation = "garanties_souscrites.code_garantie",
    garanties_souscrites.terme_prestation = "garanties_souscrites.code_garantie",
    garanties_souscrites.conjoint_vise = "garanties_souscrites.code_garantie",
    garanties_souscrites.versement_double_effet = "garanties_souscrites.code_garantie",
    garanties_souscrites.non_remariage = "garanties_souscrites.code_garantie",
    garanties_souscrites.prolongation_handicap = "garanties_souscrites.code_garantie",
    garanties_souscrites.maintien_double_effet = "garanties_souscrites.code_garantie",
    garanties_souscrites.clause_type_beneficiaire = "garanties_souscrites.code_garantie",
    garanties_souscrites.taux_technique_tarif = c("garanties_souscrites.code_garantie", "garanties_souscrites.maintien_deces",
                                                  "contrats.nature_contrat"),
    garanties_souscrites.maintien_deces = c("garanties_souscrites.code_garantie", "contrats.nature_contrat"),
    garanties_souscrites.college = "contrats.nature_contrat",
    assures.date_situation_familiale = c("assures.situation_familiale", "assures.nombre_enfants_charge"),
    affiliations.motif_fin = "affiliations.date_fin",
    affiliations.date_saisie_fin = "affiliations.date_fin",
    affiliations.date_designation = "affiliations.designation",
    famille.date_naissance = "famille.situation",
    famille.situation = "famille.lien",
    prestations.debut_periode = "prestations.type_prestation",
    prestations.fin_periode = "prestations.type_prestation",
    prestations.montant = "prestations.nature_mouvement",
    cotisations.montant = "cotisations.nature_mouvement",
    evenements.type_evenement = c("garanties_souscrites.code_garantie", "sinistres.nature_sinistre"),
    evenements.categorie_invalidite = "evenements.type_evenement",
    evenements.montant = "evenements.type_evenement",
    evenements.source_information = "evenements.type_evenement",
    evenements.motif = "evenements.type_evenement",
    victimes.date_deces = "victimes.statut_victime",
    evenements.date_effet = c("evenements.type_evenement", "evenements.motif")),
  table = list(
    contrats.id_adherent = "contrats.nature_contrat",
    contrats.id_assure = "contrats.nature_contrat",
    parametres.parametre = "garanties_souscrites.code_garantie",
    parametres.categorie_invalidite = "garanties_souscrites.code_garantie",
    affiliations.id_contrat = "contrats.nature_contrat",
    dossiers.id_garantie_souscrite = c("garanties_souscrites.code_garantie", "sinistres.nature_sinistre"),
    rentes.id_dossier = "garanties_souscrites.code_garantie",
    rentes.id_membre = "garanties_souscrites.code_garantie",
    prestations.type_prestation = "garanties_souscrites.code_garantie",
    prestations.id_rente = "prestations.type_prestation",
    beneficiaires.id_membre = "beneficiaires.qualite",
    evenements.id_dossier = "evenements.type_evenement",
    evenements.id_rente = c("evenements.type_evenement", "garanties_souscrites.code_garantie"),
    designations.id_affiliation = "affiliations.designation",
    affiliations.college = "garanties_souscrites.college",
    garanties_souscrites.NA = c("garanties_souscrites.code_garantie", "garanties_souscrites.college",
                                "garanties_souscrites.date_effet", "garanties_souscrites.date_fin"),
    parametres.NA = "parametres.age_max"))

# Strates du graphe `lectures` (liste nommée : colonne contrôlée -> colonnes lues) : strate
# d'une colonne = longueur du plus long chemin qui y mène (0 sans arête entrante), par le tri
# topologique de Kahn ; un cycle est une erreur interne (M217 : il revient au mainteneur).
.strates_regle_b <- function(lectures) {
  vers <- rep(names(lectures), lengths(lectures))
  de <- unlist(lectures, use.names = FALSE)
  restants <- unique(c(de, vers))
  strate <- stats::setNames(rep(0L, length(restants)), restants)
  reste <- rep(TRUE, length(de))
  while (length(restants) > 0L) {
    sources <- restants[!(restants %in% vers[reste])]
    if (length(sources) == 0L) stop("erreur interne de provie : graphe de la r\u00e8gle B cyclique (",
                                    paste(restants, collapse = ", "), ")", call. = FALSE)
    for (i in which(reste & de %in% sources)) strate[[vers[i]]] <- max(strate[[vers[i]]], strate[[de[i]]] + 1L)
    reste[de %in% sources] <- FALSE
    restants <- setdiff(restants, sources)
  }
  strate
}
.STRATES_REGLE_B <- .strates_regle_b(.LECTURES_REGLE_B$colonne)
.STRATE_PUITS <- max(.STRATES_REGLE_B) + 1L

# Strate d'une règle du domaine de la règle B, pour les strates `strates` (.strates_regle_b())
# : celle de sa colonne pour une règle de portée colonne (0 hors du graphe), le puits (plus
# haute strate plus un) pour une règle de portée table (spécification, § 2.2, « Ordre
# d'exécution », étape 3). `portee` : portée effective de la règle, si elle est déjà calculée
# (.portees_registre(), #55).
.strate_regle <- function(dico, code, table, colonne, strates, portee = .portee_effective(dico, code, table, colonne)) {
  if (portee == "table") return(max(c(0L, strates)) + 1L)
  s <- strates[paste(table, colonne, sep = ".")]
  if (is.na(s)) 0L else unname(s)
}

# Strate de chaque règle du domaine (.strate_regle()), calculée une fois par clé (code, table,
# colonne) et par appel de .regle_domaine(), non à chaque passe (#55) : rend une fonction
# (code, table, colonne) -> strate, lue par le répartiteur. Les clés du registre (.regles_b())
# sont calculées d'avance avec leur portée effective (`portee`, déjà calculée pour le graphe) ;
# une clé hors du registre est calculée à sa première lecture. La mémoire est locale à
# l'appel (environnement de la fonction rendue) : rien n'est conservé dans l'espace de noms.
.table_strates <- function(dico, registre, portee, strates) {
  memoire <- new.env(hash = TRUE, parent = emptyenv())
  cle <- function(code, table, colonne) paste(code, table, colonne, sep = "\r")
  for (i in seq_along(registre)) {
    k <- registre[[i]]
    assign(cle(k$code, k$table, k$colonne), .strate_regle(dico, k$code, k$table, k$colonne, strates, portee[i]),
           envir = memoire)
  }
  function(code, table, colonne) {
    k <- cle(code, table, colonne)
    s <- memoire[[k]]
    if (is.null(s)) {
      s <- .strate_regle(dico, code, table, colonne, strates)
      assign(k, s, envir = memoire)
    }
    s
  }
}

# Registre des règles de la règle B (#56, point 4) : une entrée (code, table, colonne, lit,
# traitement) par appel de .regle() du domaine (.regles_generiques(), .regles_propres()) puis
# des clés (.regle_cles()), dans l'ordre du code, relevée sans rien exécuter (`ctx$passe`
# rend FALSE) sur une base squelette (toutes les tables et colonnes du dictionnaire, sans
# ligne) : le registre ne dépend que du dictionnaire et du code.
.regles_b <- function(dico) {
  base <- lapply(stats::setNames(dico$tables$table, dico$tables$table), function(t) {
    colonnes <- dico$colonnes$colonne[dico$colonnes$table == t]
    data.frame(stats::setNames(rep(list(logical(0)), length(colonnes)), colonnes), check.names = FALSE)
  })
  ctx <- .contexte(base, dico, list(date_extraction = as.Date(NA)), as.Date(NA))
  registre <- list()
  ctx$passe <- function(code, table, colonne, lit, traitement) {
    registre[[length(registre) + 1L]] <<- list(code = code, table = table, colonne = colonne, lit = lit,
                                               traitement = traitement)
    FALSE
  }
  .regles_generiques(ctx)
  .regles_propres(ctx)
  .regle_cles(ctx)
  registre
}

# Graphe des lectures de la règle B dérivé du registre (.regles_b() ; #56, point 4), de même
# forme que .LECTURES_REGLE_B : colonnes refusables pour leur valeur = colonnes contrôlées par
# une règle R de portée colonne ; pour chaque règle qui en lit une autre que la sienne (règle
# concernée), par portée (`colonne` : arêtes du graphe ; `table` : puits) et colonne
# contrôlée, les colonnes refusables lues, dans l'ordre du registre.
.lectures_regle_b <- function(dico, registre = .regles_b(dico), portee = .portees_registre(dico, registre)) {
  soi <- vapply(registre, function(k) paste(k$table, k$colonne, sep = "."), "")
  # portée colonne : toute portée autre que table (`colonne` ou `ligne`, #72)
  portee[portee != "table"] <- "colonne"
  refusables <- unique(soi[portee == "colonne" & vapply(registre, `[[`, "", "traitement") == "R"])
  lus <- lapply(seq_along(registre), function(i) setdiff(intersect(registre[[i]]$lit, refusables), soi[i]))
  concernee <- lengths(lus) > 0L
  par_portee <- function(p) {
    s <- unique(soi[concernee & portee == p])
    stats::setNames(lapply(s, function(tc) unique(unlist(lus[concernee & portee == p & soi == tc]))), s)
  }
  list(colonne = par_portee("colonne"), table = par_portee("table"))
}
# Portée effective (.portee_effective()) de chaque entrée du registre, calculée une fois par
# appel de .regle_domaine() pour le graphe et les strates (#55).
.portees_registre <- function(dico, registre) {
  vapply(registre, function(k) .portee_effective(dico, k$code, k$table, k$colonne), "")
}

# Ligne de `table_cible` dont la clé `cle_cible` vaut chaque valeur de `valeurs_cle` (NA : aucune).
# Clé primaire en double (D01a ; spécification `donnees` v1.7, § 2.2, B.4, « Clé primaire en
# double », #131) : la première occurrence n'est qu'un repère, jamais « la » ligne jointe ;
# l'attribut `occurrences` (liste alignée sur `valeurs_cle`, NULL où la clé est portée par au
# plus une ligne ; absent sans clé en double jointe) donne toutes les lignes de la clé, lues
# par .entree3() et .joindre3() (lecture existentielle sur les occurrences).
# Clé manquante (spécification `donnees` v1.7, § 2.2, B.4, « Clé manquante ») : elle ne
# s'apparie à aucune ligne, d'un côté comme de l'autre. Une clé "" suit la règle « Clé
# manquante », primaire ou étrangère (même section, « Chaîne vide », erratum du 15 novembre
# 2026, décision du mainteneur ; .cle_manquante(), #123) : aucune ligne jointe, pas même parmi
# des clés primaires "" en double (une chaîne vide ne reçoit que chaine_vide, jamais le code
# d'une règle qui lit la ligne jointe).
.index_jointure <- function(ctx, table_cible, cle_cible, valeurs_cle) {
  cle <- .valeurs(ctx, table_cible, cle_cible)
  i <- apparier_cles(valeurs_cle, cle)
  doubles <- which(!is.na(cle) & !.chaine_vide(cle) & (duplicated(cle) | duplicated(cle, fromLast = TRUE)))
  if (length(doubles) == 0L) return(i)
  j <- apparier_cles(valeurs_cle, cle[doubles])
  if (all(is.na(j))) return(i)
  # lignes en double regroupées par clé (repère : première ligne de la clé), dans l'ordre des lignes
  groupes <- split(doubles, match(cle[doubles], cle[doubles]))
  occurrences <- vector("list", length(valeurs_cle))
  occurrences[!is.na(j)] <- unname(groupes[as.character(j[!is.na(j)])])
  attr(i, "occurrences") <- occurrences
  i
}

# Valeur jointe de `colonne_cible` lue sur toutes les occurrences de sa clé (lecture
# existentielle, spécification `donnees` v1.7, § 2.2, B.4, « Clé primaire en double », #131) :
# `valeurs` (valeur de la ligne jointe ; NA hors jointure), `diverge` (clé portée par k ≥ 2
# lignes dont les valeurs ne concordent pas : valeur jointe inconnue, cause candidate D01a),
# `domaines` (liste alignée : valeurs distinctes des occurrences d'une ligne qui diverge, NULL
# ailleurs) et `index` (liste alignée : lignes jointes, toutes les occurrences d'une clé en
# double). `inconnu` (facultatif) : lignes de la table cible de valeur inconnue (refus de
# valeur) ; une occurrence refusée empêche la concordance et prend le domaine de sa colonne,
# rendu par `domaine()` (appelée seulement alors).
# `index` : jointure déjà calculée (.index_jointure()), `cle_cible` et `valeurs_cle` sont alors
# ignorées.
.joindre3 <- function(ctx, table_cible, cle_cible, colonne_cible, valeurs_cle, inconnu = NULL, domaine = NULL,
                      index = .index_jointure(ctx, table_cible, cle_cible, valeurs_cle)) {
  x <- .valeurs(ctx, table_cible, colonne_cible)
  occ <- attr(index, "occurrences")
  n <- length(index)
  res <- list(valeurs = x[index], diverge = rep(FALSE, n), domaines = vector("list", n), index = as.list(index))
  if (is.null(occ)) return(res)
  for (r in which(lengths(occ) > 0L)) {
    o <- occ[[r]]
    u <- if (is.null(inconnu)) rep(FALSE, length(o)) else inconnu[o]
    res$index[[r]] <- o
    if (!any(u) && length(unique(x[o])) == 1L) next   # occurrences concordantes : valeur connue
    res$diverge[r] <- TRUE
    res$domaines[[r]] <- unique(c(x[o][!u], if (any(u)) domaine()))
  }
  res
}

# Domaine d'une colonne lue (spécification, § 2.2, B.4) : modalités du dictionnaire, liste de
# types_evenements pour le type d'événement, vrai et faux pour une colonne logique, et
# l'absence pour une colonne non obligatoire. Une colonne sans domaine énuméré (date, nombre)
# reçoit le sien de la règle qui la lit (.presence_date3(), bornes de la colonne).
.domaine3 <- function(ctx, table, colonne) {
  col <- .colonnes_dico(ctx, table)
  col <- col[col$colonne == colonne, , drop = FALSE]
  d <- if (table == "evenements" && colonne == "type_evenement") {
    ctx$dico$types_evenements$type_evenement
  } else if (col$type == "logical") c(TRUE, FALSE) else eclater_champ(col$modalites)
  if (length(d) == 0L) stop("erreur interne de provie : domaine de ", table, ".", colonne, " non \u00e9num\u00e9r\u00e9",
                            call. = FALSE)
  if (col$obligatoire != "O") d <- c(d, NA)
  d
}
# Date facultative lue pour sa seule présence (sites 5, 6, 15, 16) : une date du domaine et
# l'absence.
.presence_date3 <- function(ctx) structure(c(as.numeric(ctx$date_extraction), NA_real_), class = "Date")
# Plus petite et plus grande date du domaine de `table.colonne` (D02c : à partir du
# 1901-01-01 ; au plus l'extraction sans futur admis, la veille de la sentinelle 9999-12-31
# sinon).
.plage_date3 <- function(ctx, table, colonne) {
  col <- .colonnes_dico(ctx, table)
  futur <- col$futur_admis[col$colonne == colonne] == "TRUE"
  c(as.numeric(as.Date("1901-01-01")), if (futur) as.numeric(as.Date("9999-12-30")) else as.numeric(ctx$date_extraction))
}

# Entrée d'un verdict à trois valeurs (.verdict3()) : valeurs de `tc` (« table.colonne »)
# alignées sur les lignes de la règle par `index` (ligne jointe de la table de `tc` ; NULL :
# même table ; NA : aucune ligne jointe, valeur absente connue), inconnues sur une ligne
# refusée pour sa valeur (.inconnu() ; `connue` : colonne contrôlée par une règle de portée
# colonne, lue telle quelle, P4), domaine de la colonne (.domaine3(), ou `domaine`).
# `.connue3()` : entrée connue, dérivée de colonnes de clé.
# Clé jointe portée par k ≥ 2 lignes (attribut `occurrences` de `index`, .index_jointure() ;
# spécification `donnees` v1.7, § 2.2, B.4, « Clé primaire en double », #131) : la valeur
# jointe est l'une des valeurs des occurrences ; connue si elles concordent (même valeur,
# toutes connues), inconnue sinon (`d01a` : cause candidate D01a), de domaine propre à la
# ligne (`domaines` : valeurs des occurrences, le domaine de la colonne pour une occurrence
# refusée) ; `index` porte alors toutes les occurrences (cause d'une ligne écartée).
.entree3 <- function(ctx, tc, index = NULL, domaine = NULL, connue = FALSE) {
  m <- strsplit(tc, ".", fixed = TRUE)[[1L]]
  x <- .valeurs(ctx, m[1L], m[2L])
  inconnu <- if (connue) rep(FALSE, length(x)) else .inconnu(ctx, m[1L], m[2L])
  d01a <- NULL
  domaines <- NULL
  if (!is.null(index)) {
    if (!is.null(attr(index, "occurrences"))) {
      j <- .joindre3(ctx, m[1L], NA_character_, m[2L], NULL, inconnu = inconnu,
                     domaine = function() if (is.null(domaine)) .domaine3(ctx, m[1L], m[2L]) else domaine, index = index)
      d01a <- j$diverge
      domaines <- j$domaines
    }
    x <- x[index]
    inconnu <- !is.na(index) & inconnu[index]
    if (!is.null(d01a)) {
      inconnu <- inconnu | d01a
      index <- j$index
    }
  }
  # domaine de la colonne pour les lignes inconnues sans domaine propre
  if (any(inconnu & (if (is.null(d01a)) TRUE else !d01a)) && is.null(domaine)) domaine <- .domaine3(ctx, m[1L], m[2L])
  list(tc = tc, valeurs = x, inconnu = inconnu, index = index, domaine = domaine, domaines = domaines, d01a = d01a)
}
.connue3 <- function(tc, valeurs) list(tc = tc, valeurs = valeurs, inconnu = rep(FALSE, length(valeurs)), index = NULL,
                                       domaine = NULL)
# Entrée d'une colonne `tc` jointe par la clé primaire `cle` de sa table et lue telle quelle
# (colonne de clé ou jamais refusée pour sa valeur) : connue, sauf sur une clé jointe en
# double aux occurrences divergentes (lecture existentielle, .joindre3() ; spécification
# `donnees` v1.7, § 2.2, B.4, « Clé primaire en double », #131).
.jointe3 <- function(ctx, tc, cle, valeurs_cle) {
  m <- strsplit(tc, ".", fixed = TRUE)[[1L]]
  j <- .joindre3(ctx, m[1L], cle, m[2L], valeurs_cle)
  list(tc = tc, valeurs = j$valeurs, inconnu = j$diverge, index = if (any(j$diverge)) j$index, domaine = NULL,
       domaines = j$domaines, d01a = j$diverge)
}

# --- Entrées des règles V à trois valeurs (#105, lot V ; spécification `donnees`, erratum
# `1.9.7`, E-1 ; § 2.2, B.4) ---------------------------------------------------------------
# Une valeur refusée (ou une cellule de D03i) est inconnue dans le domaine de sa colonne ; sur
# une colonne non obligatoire, une valeur refusée non vide rend l'absence possible (B.4,
# décision du mainteneur du 25 novembre 2026). Le domaine est représenté par un représentant de
# chaque région où le verdict de la règle est constant (exact quand la règle le justifie).
.obligatoire3 <- function(ctx, table, colonne) {
  col <- .colonnes_dico(ctx, table)
  identical(col$obligatoire[col$colonne == colonne], "O")
}
# Entrée « valeur manquante » de `tc` (D03, présence seule) : vrai si la valeur manque ; une
# valeur inconnue est présente sur une colonne obligatoire (domaine FALSE), présente ou absente
# sinon (domaine FALSE, TRUE) : un représentant par région (présente, absente).
.manquant3 <- function(ctx, tc) {
  m <- strsplit(tc, ".", fixed = TRUE)[[1L]]
  list(tc = tc, valeurs = is.na(.valeurs(ctx, m[1L], m[2L])), inconnu = .inconnu(ctx, m[1L], m[2L]), index = NULL,
       domaine = if (.obligatoire3(ctx, m[1L], m[2L])) FALSE else c(FALSE, TRUE))
}
# Entrée date de `tc`, en nombre (jours), alignée par `index` comme .entree3() : domaine d'une
# valeur inconnue, les bornes de la plage de la colonne (.plage_date3()) et l'absence pour une
# colonne non obligatoire (suffisant pour une comparaison monotone) ; `points_ligne` (liste
# alignée sur les lignes de la règle, NULL ou dates en nombre) : domaine propre à la ligne, bornes
# et points de rupture d'un verdict non monotone, ramenés à la plage. Valeurs brutes : une
# colonne de partie de ligne se lit avec l'entrée .partie3() (partie connue, non connue, ou non
# déterminée : jamais masquée en « absente » connue).
.date3 <- function(ctx, tc, index = NULL, points_ligne = NULL) {
  m <- strsplit(tc, ".", fixed = TRUE)[[1L]]
  plage <- .plage_date3(ctx, m[1L], m[2L])
  absent <- if (.obligatoire3(ctx, m[1L], m[2L])) NULL else NA_real_
  e <- .entree3(ctx, tc, index = index, domaine = c(plage, absent))
  e$valeurs <- as.numeric(e$valeurs)
  if (!is.null(points_ligne)) {
    if (is.null(e$domaines)) e$domaines <- vector("list", length(e$valeurs))
    for (l in which(e$inconnu & lengths(e$domaines) == 0L)) {
      pts <- points_ligne[[l]]
      pts <- pts[!is.na(pts) & pts >= plage[1L] & pts <= plage[2L]]
      e$domaines[[l]] <- unique(c(plage, pts, absent))
    }
  }
  e
}
# Entrée « partie de ligne connue à l'arrêté » de `table` (.PARTIES_LIGNE ; spécification v1.5,
# § 2.2 (d)) : vraie si la partie est connue, fausse si elle ne l'est pas de façon déterminée,
# inconnue si elle est non déterminée (inscrite sous la colonne de sa date, clé de la cause) ;
# toujours connue à l'arrêté égal à l'extraction.
.partie3 <- function(ctx, table) {
  p <- Filter(function(x) x$table == table, .PARTIES_LIGNE)[[1L]]
  n <- NROW(ctx$base[[table]])
  if (.vue_totale(ctx)) {
    connue <- rep(TRUE, n)
    nd <- rep(FALSE, n)
  } else {
    connue <- .visibilite_a(ctx, "vue")$parties[[table]] %in% TRUE
    nd <- ctx$retenu[[table]] & ctx$partie_nd[[table]]
  }
  list(tc = paste(table, p$date, sep = "."), valeurs = connue & !nd, inconnu = nd, index = NULL, domaine = c(TRUE, FALSE))
}

# Disjonction monotone de conjonctions, à trois valeurs et pertinence exacte (#105, lot V, G2a) :
# « il existe une ligne qui satisfait » lorsque les lignes candidates partagent des cellules
# inconnues (code de la garantie d'un dossier lu par toutes ses prestations, par exemple). Chaque
# terme (ligne de la règle `ligne`, `faux` : un littéral connu faux, `vars` : identifiants
# « table.colonne\rligne » de ses littéraux inconnus, chacun pouvant être vrai ou faux) ; une
# formule monotone s'évalue exactement en Kleene (ses extrêmes sont atteints par tout vrai et tout
# faux) ; dans sa forme minimale (termes absorbés retirés), chaque variable est pertinente.
# Rend, par ligne de la règle (`n` lignes), la valeur (NA : inconnue) et les identifiants
# pertinents d'une ligne inconnue.
.ou3 <- function(n, ligne, faux, vars) {
  v <- rep(FALSE, n)
  pert <- vector("list", n)
  garde <- which(!faux)
  vrai <- unique(ligne[garde[lengths(vars[garde]) == 0L]])
  v[vrai] <- TRUE
  garde <- garde[!(ligne[garde] %in% vrai)]
  for (z in split(garde, ligne[garde])) {
    l <- ligne[z[1L]]
    t <- unique(lapply(vars[z], function(x) sort(unique(x))))
    minimal <- vapply(seq_along(t), function(a) !any(vapply(seq_along(t)[-a], function(b) all(t[[b]] %in% t[[a]]) &&
                                                               length(t[[b]]) < length(t[[a]]), NA)), NA)
    v[l] <- NA
    pert[[l]] <- sort(unique(unlist(t[minimal])))
  }
  list(v = v, pert = pert)
}
# Entrée .verdict3() d'une disjonction .ou3() (nom `nom`), puis, sur le verdict, éclatement de
# ses identifiants pertinents par colonne (index_pertinent, clé « table.colonne » ou « table »)
.entree_ou3 <- function(nom, ou) list(tc = nom, valeurs = ou$v %in% TRUE, inconnu = is.na(ou$v), index = NULL,
                                       domaine = c(TRUE, FALSE))
.eclater3 <- function(r, noms, ou, lues = character(0)) {
  ip <- attr(r, "index_pertinent")
  for (k in seq_along(noms)) {
    p <- ip[[noms[k]]]
    ip[[noms[k]]] <- NULL
    if (is.null(p)) next
    for (l in which(lengths(p) > 0L)) {
      for (id in ou[[k]]$pert[[l]]) {
        m <- strsplit(id, "\r", fixed = TRUE)[[1L]]
        if (is.null(ip[[m[1L]]])) ip[[m[1L]]] <- vector("list", length(r))
        ip[[m[1L]]][l] <- list(sort(unique(c(ip[[m[1L]]][[l]], as.integer(m[2L])))))
      }
    }
  }
  attr(r, "index_pertinent") <- ip
  attr(r, "lues") <- unique(c(setdiff(attr(r, "lues"), noms), lues))
  r
}

# Pertinence exacte d'une cellule conditionnée (règle de tout noyau conditionné ; #105, lot V,
# G2a ; R-G2a-1 d'`actuary`, à titre provisoire) : la cellule c, lue par plusieurs composantes
# (atomes, références), est pertinente s'il existe une affectation des autres cellules où faire
# varier c seule change l'issue. Propagation de paires : pour deux représentants c1 et c2 de c,
# `couples(c1, c2)` rend, par composante, la matrice à deux colonnes des couples (issue sous c1,
# issue sous c2) atteints sur les mêmes valeurs de ses cellules privées (représentants : réunion
# des points de rupture relatifs à c1 et à c2 ; une composante qui ne lit pas c n'a que des
# couples égaux) ; les couples se combinent composante par composante par `combiner` (associative,
# vectorielle en son second argument ; `neutre` : issue neutre), ensembles produits. c est
# pertinente si une paire donne un couple atteignable de deux composantes différentes. Le cas
# « verdict conditionnel qui varie » en est un cas particulier ; le cas où tous les verdicts
# conditionnels sont inconnus (c XOR d, d privée) y est compris.
.pertinence_paires3 <- function(representants, couples, combiner, neutre) {
  n <- length(representants)
  if (n < 2L) return(FALSE)
  for (a in seq_len(n - 1L)) {
    for (b in (a + 1L):n) {
      ens <- matrix(c(neutre, neutre), nrow = 1L)
      for (P in couples(representants[[a]], representants[[b]])) {
        ens <- unique(do.call(rbind, lapply(seq_len(nrow(ens)), function(i) {
          cbind(combiner(ens[i, 1L], P[, 1L]), combiner(ens[i, 2L], P[, 2L]))
        })))
      }
      if (any(ens[, 1L] != ens[, 2L])) return(TRUE)
    }
  }
  FALSE
}

# Formule à trois valeurs sur un arbre, verdict et pertinence exacts (#105, lot V, G2b ; D-G2-2,
# conditionnement sur les cellules partagées ; R-G2a-1, propagation de couples le long de
# l'arbre, recommandation d'`actuary` appliquée à titre provisoire). Une ligne d'une règle est un
# arbre de nœuds (.noeud3() : `op` "et", "ou" ou "non", `enfants`) et de feuilles (.feuille3() :
# `cel`, identifiants « table.colonne\rligne » des cellules inconnues qu'elle lit, ou
# « table\rligne » pour la présence d'une ligne de visibilité non déterminée ; `dom(sigs)` :
# représentants de ses cellules inconnues non fixées, sachant les affectations `sigs` (liste de
# listes nommées de cellules fixées, chacune de une ou plusieurs valeurs : réunion des points de
# rupture relatifs à toutes ces valeurs) ; `f(a, n)` : valeur de la feuille sur `n` affectations
# `a`, liste nommée de vecteurs par cellule, NA lu comme faux). Les feuilles qui ne partagent
# aucune cellule sont indépendantes : leur combinaison par ensembles de valeurs est exacte. Une
# cellule lue par deux feuilles au moins est conditionnée : domaine statique, réunion des
# représentants rendus par ses feuilles sachant toutes les valeurs des cellules conditionnées de
# rang inférieur (`ordre` : préfixes « table.colonne » par rang ; les autres ensuite) ; le
# domaine d'une cellule de rang supérieur contient ainsi les points de rupture relatifs à chaque
# représentant des cellules qu'elle compare (leçon de G2a : représentants de la ligne de D11c).
# Verdict : vrai (faux) si toute affectation des cellules conditionnées donne l'ensemble {vrai}
# ({faux}), inconnu sinon. Pertinence d'une cellule c (verdict inconnu seulement) : il existe
# une affectation des autres cellules conditionnées et deux représentants c1, c2 de c dont les
# couples (valeur sous c1, valeur sous c2) se propagent jusqu'à la racine en un couple de deux
# valeurs différentes : couples des feuilles qui lisent c sur les mêmes valeurs de leurs autres
# cellules, couples égaux des autres feuilles, combinaison par composante (ET, OU, NON), ensembles
# produits (.pertinence_paires3() en est le cas d'un pli). Deux représentants de même signature
# (mêmes valeurs des feuilles qui lisent c, sur la même grille) sont équivalents : un seul est
# essayé. Rend `v` (TRUE, FALSE, NA) et `pert` (identifiants des cellules pertinentes).
.feuille3 <- function(cel, dom, f) list(cel = unique(cel[!is.na(cel)]), dom = dom, f = f)
.noeud3 <- function(op, enfants) list(op = op, enfants = enfants)
.constante3 <- function(v) .feuille3(character(0), function(sigs) list(), function(a, n) rep_len(v, n))
.arbre3 <- function(arbre, ordre = "sinistres.date_survenance") {
  feuilles <- list()
  numeroter <- function(x) {
    if (is.null(x$op)) {
      feuilles[[length(feuilles) + 1L]] <<- x
      return(list(k = length(feuilles)))
    }
    list(op = x$op, enfants = lapply(x$enfants, numeroter))
  }
  t <- numeroter(arbre)
  cel <- lapply(feuilles, `[[`, "cel")
  tous <- unique(unlist(cel))
  nb <- table(unlist(cel))
  partagees <- names(nb)[nb > 1L]
  lecteurs_de <- function(c1) which(vapply(cel, function(z) c1 %in% z, NA))
  # domaines statiques des cellules conditionnées, rang par rang
  rang <- vapply(partagees, function(c1) {
    tc <- strsplit(c1, "\r", fixed = TRUE)[[1L]][1L]
    r <- match(tc, ordre)
    if (is.na(r)) length(ordre) + 1L else r
  }, 0L)
  dom_p <- list()
  for (r in sort(unique(rang))) {
    groupe <- partagees[rang == r]
    fixes <- dom_p
    for (c1 in groupe) {
      d <- lapply(feuilles[lecteurs_de(c1)], function(fe) fe$dom(list(fixes))[[c1]])
      dom_p[[c1]] <- unique(do.call(c, d))
      if (length(dom_p[[c1]]) == 0L) {
        stop("erreur interne de provie : .arbre3() : cellule partag\u00e9e sans repr\u00e9sentant", call. = FALSE)
      }
    }
  }
  grille <- function(cells) {
    if (length(cells) == 0L) return(list(list()))
    g <- expand.grid(lapply(dom_p[cells], seq_along), KEEP.OUT.ATTRS = FALSE)
    lapply(seq_len(nrow(g)), function(i) stats::setNames(lapply(cells, function(c1) dom_p[[c1]][g[[c1]][i]]), cells))
  }
  # valeurs de la feuille k sous chaque affectation de `sigs` (mêmes cellules fixées), sur la
  # grille commune de ses autres cellules : matrice (grille, affectations)
  valeurs_f <- function(k, sigs) {
    fe <- feuilles[[k]]
    priv <- setdiff(fe$cel, names(sigs[[1L]]))
    doms <- if (length(priv) > 0L) fe$dom(sigs)[priv] else list()
    if (length(priv) > 0L && any(lengths(doms) == 0L)) {
      stop("erreur interne de provie : .arbre3() : feuille sans repr\u00e9sentant d'une cellule", call. = FALSE)
    }
    g <- if (length(priv) > 0L) expand.grid(lapply(doms, seq_along), KEEP.OUT.ATTRS = FALSE) else NULL
    ng <- if (is.null(g)) 1L else nrow(g)
    m <- vapply(sigs, function(s) {
      a <- lapply(s, rep_len, ng)
      for (p in priv) a[[p]] <- doms[[p]][g[[p]]]
      fe$f(a, ng) %in% TRUE
    }, logical(ng))
    matrix(m, nrow = ng)
  }
  ens <- function(x, e) {
    if (!is.null(x$k)) return(e[[x$k]])
    if (x$op == "non") return(!ens(x$enfants[[1L]], e))
    op <- if (x$op == "et") `&` else `|`
    Reduce(function(a, b) unique(as.vector(outer(a, b, op))), lapply(x$enfants, ens, e))
  }
  couples <- function(x, cp) {
    if (!is.null(x$k)) return(cp[[x$k]])
    if (x$op == "non") return(!couples(x$enfants[[1L]], cp))
    op <- if (x$op == "et") `&` else `|`
    Reduce(function(a, b) {
      i <- rep(seq_len(nrow(a)), nrow(b))
      j <- rep(seq_len(nrow(b)), each = nrow(a))
      unique(cbind(op(a[i, 1L], b[j, 1L]), op(a[i, 2L], b[j, 2L])))
    }, lapply(x$enfants, couples, cp))
  }
  vals <- logical(0)
  for (s in grille(partagees)) {
    e <- lapply(seq_along(feuilles), function(k) unique(valeurs_f(k, list(s))[, 1L]))
    vals <- unique(c(vals, ens(t, e)))
    if (length(vals) == 2L) break
  }
  v <- if (identical(vals, TRUE)) TRUE else if (identical(vals, FALSE)) FALSE else NA
  if (!is.na(v)) return(list(v = v, pert = character(0)))
  pert <- character(0)
  for (c1 in tous) {
    lecteurs <- lecteurs_de(c1)
    trouve <- FALSE
    for (s in grille(setdiff(partagees, c1))) {
      reps <- if (c1 %in% partagees) dom_p[[c1]] else feuilles[[lecteurs]]$dom(list(s))[[c1]]
      if (length(reps) < 2L) next
      sigs <- lapply(seq_along(reps), function(i) c(s, stats::setNames(list(reps[i]), c1)))
      cp <- vector("list", length(feuilles))
      for (k in setdiff(seq_along(feuilles), lecteurs)) {
        u <- unique(valeurs_f(k, list(s))[, 1L])
        cp[[k]] <- cbind(u, u)
      }
      V <- lapply(lecteurs, valeurs_f, sigs)
      signature <- vapply(seq_along(reps), function(i) paste(vapply(V, function(m) paste(as.integer(m[, i]), collapse = ""), ""),
                                                            collapse = "|"), "")
      garde <- which(!duplicated(signature))
      if (length(garde) < 2L) next
      for (a in seq_len(length(garde) - 1L)) {
        for (b in (a + 1L):length(garde)) {
          for (q in seq_along(lecteurs)) cp[[lecteurs[q]]] <- unique(cbind(V[[q]][, garde[a]], V[[q]][, garde[b]]))
          m <- couples(t, cp)
          if (any(m[, 1L] != m[, 2L])) {
            trouve <- TRUE
            break
          }
        }
        if (trouve) break
      }
      if (trouve) break
    }
    if (trouve) pert <- c(pert, c1)
  }
  list(v = v, pert = pert)
}
# Identifiants des cellules inconnues lues par les feuilles d'un arbre de .arbre3().
.cellules3 <- function(x) if (is.null(x$op)) x$cel else unique(unlist(lapply(x$enfants, .cellules3)))
# Valeurs d'une cellule dans une affectation `a` de .arbre3() (`id` NA : valeur connue `x`).
.val3 <- function(a, id, x, n) if (is.na(id)) rep_len(x, n) else a[[id]]
# Valeurs prises par la cellule `id` dans les affectations `sigs` (.arbre3()), à défaut `x`.
.fixees3 <- function(sigs, id, x) {
  if (is.na(id)) return(x)
  v <- unlist(lapply(sigs, `[[`, id), use.names = FALSE)
  if (length(v) == 0L) x else v
}
# Représentants d'une date : bornes de la plage, points `autour` (la veille, le jour, le
# lendemain), ramenés à la plage, et l'absence si `absent`.
.reps_date3 <- function(plage, absent, autour = numeric(0)) {
  pts <- c(autour - 1, autour, autour + 1)
  pts <- pts[!is.na(pts) & pts >= plage[1L] & pts <= plage[2L]]
  unique(c(plage, pts, if (absent) NA_real_))
}
# Ajoute à `ip` (index_pertinent, par « table.colonne » ou « table ») les cellules `ids` de la
# ligne `l` de la règle (`n` lignes).
.ip_cellules3 <- function(ip, l, ids, n) {
  for (id in ids) {
    m <- strsplit(id, "\r", fixed = TRUE)[[1L]]
    if (is.null(ip[[m[1L]]])) ip[[m[1L]]] <- vector("list", n)
    ip[[m[1L]]][l] <- list(sort(unique(c(ip[[m[1L]]][[l]], as.integer(m[2L])))))
  }
  ip
}

# Motif existentiel de Kleene (forme « jointure ou appartenance », spécification, § 2.2, B.4),
# noyau unique des règles B (.existe3(), site 39 de .orphelines()) et V (.existe_vue3()) :
# pour chaque valeur de `valeurs_cle`, « il existe une ligne de clé `cle` égale qui satisfait »
# vaut vrai si une ligne `vrai` (connue, qui satisfait) a cette clé ; inconnu sinon si une
# ligne `possible` (inconnue, qui peut satisfaire) l'a ; faux sinon. Une clé manquante ne
# s'apparie à aucune ligne, d'un côté comme de l'autre (spécification `donnees` v1.6, § 2.2,
# B.4, « Clé manquante », #56), une chaîne vide non plus (apparier_cles(), #123, #158). `index` :
# pour une valeur inconnue, les lignes `possible` de même clé, dans l'ordre des lignes (cause
# d'une ligne écartée) ; NULL ailleurs.
.existe_kleene <- function(valeurs_cle, cle, vrai, possible) {
  cle <- .cle_manquante(cle)
  existe <- !is.na(apparier_cles(valeurs_cle, cle[vrai]))
  lignes_p <- which(possible & !is.na(cle))
  j <- apparier_cles(valeurs_cle, cle[lignes_p])
  inconnu <- !existe & !is.na(j)
  index <- vector("list", length(valeurs_cle))
  if (any(inconnu)) {
    # lignes `possible` regroupées par clé (repère : première ligne de la clé), travail linéaire
    groupes <- split(lignes_p, match(cle[lignes_p], cle[lignes_p]))
    index[inconnu] <- unname(groupes[as.character(j[inconnu])])
  }
  list(valeurs = existe, inconnu = inconnu, index = index)
}

# Entrée « il existe une ligne de la table de `tc`, de clé `cle` égale à `valeurs_cle`, dont
# la valeur satisfait `p` » (site 4, garantie décès du contrat ; forme « jointure ou
# appartenance », spécification, § 2.2, B.4) : vraie si une ligne jointe connue satisfait, ou
# une ligne jointe de valeur inconnue que tout le domaine de la colonne fait satisfaire ;
# inconnue si aucune ne satisfait parmi les connues et qu'une ligne jointe de valeur inconnue
# le peut (domaine de la colonne) ; fausse sinon (.existe_kleene() : une clé manquante ne
# s'apparie à aucune ligne). `index` : lignes jointes de valeur inconnue.
.existe3 <- function(ctx, tc, cle, valeurs_cle, p) {
  m <- strsplit(tc, ".", fixed = TRUE)[[1L]]
  k <- .valeurs(ctx, m[1L], cle)
  x <- .valeurs(ctx, m[1L], m[2L])
  u <- .inconnu(ctx, m[1L], m[2L])
  sat <- if (any(u)) p(.domaine3(ctx, m[1L], m[2L])) %in% TRUE else FALSE
  e <- .existe_kleene(valeurs_cle, k, vrai = (!u & p(x) %in% TRUE) | (u & all(sat)), possible = u & any(sat) & !all(sat))
  c(list(tc = tc), e, list(domaine = c(TRUE, FALSE)))
}

# Verdict à trois valeurs d'une règle de la règle B (spécification, § 2.2, B.4, lecture
# existentielle) : `g` rend, pour des valeurs d'entrées alignées (liste nommée comme
# `entrees`, .entree3()), le verdict de chaque ligne (NA : non détecté). Sur une ligne qui lit
# une valeur inconnue, toutes les affectations des valeurs inconnues qu'elle lit, chacune dans
# le domaine de sa colonne, sont essayées : le verdict vaut leur verdict commun, NA (inconnu)
# s'il varie. Le travail sur ces lignes est le nombre de lignes fois le produit des domaines
# lus, non le nombre de lignes de la table. Attribut `index` : par colonne lue jointe, lignes
# de sa table jointes à chaque ligne (cause d'une ligne écartée, .regle()).
# Pertinence exacte (règle V en mode Kleene, .regle_vue() ; spécification `donnees`, § 3.1, et
# erratum `1.9.7`, E-3) : une entrée inconnue d'une ligne est pertinente si le verdict varie
# quand elle seule varie, les autres valeurs inconnues fixées (colonnes de la grille d'essai
# regroupées par les autres coordonnées) ; une ligne au verdict inconnu a toujours au moins une
# entrée pertinente (deux affectations de verdicts différents se joignent coordonnée par
# coordonnée). Attributs lus par la seule règle V en mode Kleene (la règle B lit `index` et
# `d01a`, inchangés) : `index_pertinent`, par colonne lue, lignes de sa table (la ligne
# elle-même pour une entrée de la même table) de ses seules entrées pertinentes ;
# `d01a_pertinent`, de même pour la cause candidate D01a ; `lues`, colonnes de toutes les
# entrées.
.verdict3 <- function(entrees, g) {
  valeurs <- lapply(entrees, `[[`, "valeurs")
  r <- g(valeurs) %in% TRUE
  inconnu <- do.call(cbind, lapply(entrees, `[[`, "inconnu"))
  pertinent <- matrix(FALSE, nrow = length(r), ncol = length(entrees))
  lignes <- which(rowSums(inconnu) > 0L)
  if (length(lignes) > 0L) {
    motifs <- apply(inconnu[lignes, , drop = FALSE], 1L, function(z) paste(which(z), collapse = ","))
    # domaine d'une entrée sur les lignes `l` : le sien, ou celui de leurs lignes (clé jointe en
    # double, .entree3() ; les lignes `l` ont alors le même domaine propre, `propre_cle`)
    domaine_de <- function(e, l) if (!is.null(e$domaines[[l[1L]]])) e$domaines[[l[1L]]] else e$domaine
    essayer <- function(l, s) {
      doms <- lapply(entrees[s], domaine_de, l)
      grille <- expand.grid(lapply(doms, seq_along))
      nl <- length(l)
      nc <- nrow(grille)
      essai <- lapply(valeurs, function(x) rep(x[l], times = nc))
      for (j in seq_along(s)) essai[[s[j]]] <- rep(doms[[j]][grille[[j]]], each = nl)
      verdicts <- matrix(g(essai) %in% TRUE, nrow = nl)
      vrais <- rowSums(verdicts)
      r[l] <<- ifelse(vrais == nc, TRUE, ifelse(vrais == 0L, FALSE, NA))
      variable <- vrais > 0L & vrais < nc
      if (!any(variable)) return(invisible(NULL))
      for (j in seq_along(s)) {
        # colonnes de la grille de mêmes autres coordonnées (indices de domaine, entiers)
        autres <- if (length(s) == 1L) rep(1L, nc) else do.call(paste, c(unname(as.list(grille[-j])), sep = "\r"))
        p <- rep(FALSE, nl)
        for (cols in split(seq_len(nc), autres)) {
          v <- rowSums(verdicts[, cols, drop = FALSE])
          p <- p | (v > 0L & v < length(cols))
        }
        pertinent[l[p & variable], s[j]] <<- TRUE
      }
    }
    propre <- rep(FALSE, length(r))
    for (e in entrees) if (!is.null(e$domaines)) propre <- propre | lengths(e$domaines) > 0L
    # clé injective des domaines propres d'une ligne sur les entrées `s` : chaque valeur a un
    # code auto-délimité (N : NA, M : NaN, D<hexadécimal>; : nombre ou date, L1 / L0 : logique,
    # <marque><longueur>:<octets en hexadécimal> : chaîne, longueur en octets en préfixe, marque
    # U / S / B selon l'encodage déclaré de la chaîne, unknown / UTF-8 / bytes), chaque domaine son
    # nombre de valeurs en préfixe, Z pour une entrée sans domaine propre ; deux lignes de même clé
    # ont les mêmes domaines, les lignes de même clé sont essayées ensemble (travail par domaine
    # distinct)
    code_valeurs <- function(x) {
      num <- is.numeric(x) || inherits(x, "Date")
      code <- if (num) paste0("D", sprintf("%a", as.numeric(x)), ";") else if (is.logical(x)) ifelse(x, "L1", "L0") else {
        # octets du texte, en hexadécimal : la clé ne dépend ni de la locale ni du marquage (paste0()
        # traduit une chaîne marquée latin1 sous une locale UTF-8, enc2utf8() réécrit en échappements
        # une chaîne non marquée sous une locale non UTF-8, #146) ; seules les chaînes marquées latin1
        # sont converties en UTF-8, pour que le même texte donne la même clé. La marque suit
        # l'encodage déclaré après cette conversion, sans lire la locale : R tient pour différentes
        # deux chaînes de mêmes octets d'encodage déclaré différent (`==` FALSE sous une locale non
        # UTF-8) ; même clé, mêmes octets et même marque, donc chaînes égales pour R. Une chaîne
        # ASCII est toujours unknown (même clé) ; un même texte non ASCII unknown et UTF-8 reçoit
        # deux clés : découpage plus fin, sans effet sur le verdict (domaines égaux, essais identiques)
        x <- as.character(x)
        lat <- !is.na(x) & Encoding(x) == "latin1"
        x[lat] <- enc2utf8(x[lat])
        marque <- c(unknown = "U", "UTF-8" = "S", bytes = "B")[Encoding(x)]
        octets <- vapply(x, function(z) if (is.na(z)) "" else paste(as.character(charToRaw(z)), collapse = ""), "",
                         USE.NAMES = FALSE)
        paste0(marque, nchar(octets) %/% 2L, ":", octets)
      }
      code[is.na(x)] <- "N"
      if (num) code[is.nan(as.numeric(x))] <- "M"
      paste0(length(x), "|", paste(code, collapse = ""))
    }
    propre_cle <- function(k, s) {
      paste(vapply(entrees[s], function(e) if (is.null(e$domaines[[k]])) "Z" else code_valeurs(e$domaines[[k]]), ""),
            collapse = "")
    }
    for (motif in unique(motifs)) {
      l <- lignes[motifs == motif]
      s <- as.integer(strsplit(motif, ",", fixed = TRUE)[[1L]])
      commun <- l[!propre[l]]
      if (length(commun) > 0L) essayer(commun, s)
      lp <- l[propre[l]]
      if (length(lp) > 0L) {
        for (g_l in split(lp, vapply(lp, propre_cle, "", s))) essayer(g_l, s)
      }
    }
  }
  index <- list()
  d01a <- list()
  for (e in entrees) {
    if (!is.null(e$index)) index[[e$tc]] <- if (is.null(index[[e$tc]])) e$index else Map(c, index[[e$tc]], e$index)
    if (!is.null(e$d01a)) d01a[[e$tc]] <- if (is.null(d01a[[e$tc]])) e$d01a else d01a[[e$tc]] | e$d01a
  }
  attr(r, "index") <- index
  # lignes dont une entrée lit une clé jointe en double aux occurrences divergentes (cause
  # candidate D01a d'une ligne écartée, .regle())
  if (length(d01a) > 0L) attr(r, "d01a") <- d01a
  # entrées pertinentes (règle V en mode Kleene)
  index_p <- list()
  d01a_p <- list()
  for (k in seq_along(entrees)) {
    e <- entrees[[k]]
    l <- which(pertinent[, k])
    if (length(l) == 0L) next
    lignes_e <- if (is.null(e$index)) as.list(l) else if (is.list(e$index)) e$index[l] else as.list(e$index[l])
    if (is.null(index_p[[e$tc]])) index_p[[e$tc]] <- vector("list", length(r))
    index_p[[e$tc]][l] <- Map(c, index_p[[e$tc]][l], lignes_e)
    if (!is.null(e$d01a)) {
      if (is.null(d01a_p[[e$tc]])) d01a_p[[e$tc]] <- rep(FALSE, length(r))
      d01a_p[[e$tc]][l] <- d01a_p[[e$tc]][l] | e$d01a[l]
    }
  }
  attr(r, "index_pertinent") <- index_p
  if (length(d01a_p) > 0L) attr(r, "d01a_pertinent") <- d01a_p
  attr(r, "lues") <- unique(vapply(entrees, `[[`, "", "tc"))
  # entrées et verdict, pour l'évaluation jointe de deux lignes qui partagent une inconnue
  # (.choix_pertinent3(), versions de famille, .verdict_vue())
  attr(r, "noyau3") <- list(entrees = entrees, g = g)
  r
}

# Verdict à trois valeurs d'une règle à trois issues par affectation (`issue` rend "vrai",
# "faux" ou "indefini" ; D02c, âge non défini : R-G1-2 d'`actuary`, option (a), appliquée à titre
# provisoire) : vrai si toute affectation est vraie ; faux si toutes sont fausses, ou toutes
# indéfinies (non détecté, comme la règle sur des valeurs connues ; attribut `indefini_certain`) ; inconnu (NA) dès que le
# domaine d'une ligne mêle deux issues, l'issue indéfinie comprise. Deux passages de
# .verdict3() (issue vraie, issue fausse) ; une entrée est pertinente si elle change l'issue,
# c'est-à-dire l'une des deux (réunion exacte de leurs entrées pertinentes).
.verdict3_indefini <- function(entrees, issue) {
  v_vrai <- .verdict3(entrees, function(v) issue(v) == "vrai")
  v_faux <- .verdict3(entrees, function(v) issue(v) == "faux")
  r <- as.vector(v_vrai)
  r[r %in% FALSE & is.na(as.vector(v_faux))] <- NA
  # issue indéfinie déterminée (ni vraie ni fausse sur aucune affectation) : verdict faux
  indefini_certain <- as.vector(v_vrai) %in% FALSE & as.vector(v_faux) %in% FALSE
  reunir <- function(a, b) {
    for (tc in names(b)) a[[tc]] <- if (is.null(a[[tc]])) b[[tc]] else if (is.list(b[[tc]])) Map(function(x, y) sort(unique(c(x, y))), a[[tc]], b[[tc]]) else a[[tc]] | b[[tc]]
    a
  }
  attr(r, "index") <- attr(v_vrai, "index", exact = TRUE)
  if (!is.null(attr(v_vrai, "d01a", exact = TRUE))) attr(r, "d01a") <- attr(v_vrai, "d01a", exact = TRUE)
  attr(r, "index_pertinent") <- reunir(attr(v_vrai, "index_pertinent"), attr(v_faux, "index_pertinent"))
  dp <- reunir(attr(v_vrai, "d01a_pertinent"), attr(v_faux, "d01a_pertinent"))
  if (length(dp) > 0L) attr(r, "d01a_pertinent") <- dp
  attr(r, "lues") <- attr(v_vrai, "lues")
  attr(r, "noyau3") <- list(entrees = entrees, g = function(v) issue(v) == "vrai", issue = issue)
  attr(r, "indefini_certain") <- indefini_certain
  r
}

# Choix de version pertinent (.verdict_vue(), règle V en mode Kleene) : les lignes `i` (version
# visible) et `c` (candidate non déterminée) d'un même membre de famille, évaluées ensemble sur
# les mêmes valeurs des cellules inconnues qu'elles partagent (même colonne, même ligne lue :
# survenance d'un sinistre commun, par exemple) ; le choix entre elles est pertinent si une
# affectation commune leur donne deux verdicts différents (évaluation jointe, décision du
# mainteneur du 25 novembre 2026). Domaine d'une cellule partagée : réunion des domaines des deux
# lignes. Rend NA si elles ne partagent aucune cellule inconnue (l'appelant applique alors la
# règle des lignes indépendantes, exacte dans ce cas).
.choix_pertinent3 <- function(noyau, i, c) {
  e <- noyau$entrees
  cellule <- function(x, l) {
    if (is.null(x$index)) paste0("ligne", l) else if (is.list(x$index)) paste(x$index[[l]], collapse = ",") else as.character(x$index[l])
  }
  domaine_de <- function(x, l) if (!is.null(x$domaines[[l]])) x$domaines[[l]] else x$domaine
  vars <- list()
  affectations <- list()
  for (k in seq_along(e)) {
    for (j in 1:2) {
      l <- c(i, c)[j]
      if (!e[[k]]$inconnu[l]) next
      nom <- paste(k, cellule(e[[k]], l), sep = "|")
      vars[[nom]] <- unique(c(vars[[nom]], domaine_de(e[[k]], l)))
      affectations[[length(affectations) + 1L]] <- list(k = k, j = j, nom = nom)
    }
  }
  noms <- vapply(affectations, `[[`, "", "nom")
  if (!anyDuplicated(noms)) return(NA)
  grille <- expand.grid(lapply(vars, seq_along))
  nc <- nrow(grille)
  essai <- lapply(e, function(x) rep(x$valeurs[c(i, c)], times = nc))
  for (a in affectations) {
    pos <- seq(a$j, by = 2L, length.out = nc)
    essai[[a$k]][pos] <- vars[[a$nom]][grille[[a$nom]]]
  }
  names(essai) <- names(e)
  v <- matrix(if (is.null(noyau$issue)) noyau$g(essai) %in% TRUE else noyau$issue(essai), nrow = 2L)
  any(v[1L, ] != v[2L, ])
}

# Chevauchement à trois valeurs (sites 40 et 41 ; spécification, § 2.2, B.4, forme
# « chevauchement », lecture existentielle) : `cle` partie connue du groupe, codes entiers des
# colonnes de clé (.code_groupe()) ; une clé NA (composante de clé manquante) met la ligne hors
# du contrôle : ni détectée, ni écartée, elle ne recouvre aucune ligne (#121) ; `groupe` colonnes de
# groupe lues (valeurs, inconnu, domaine : NULL pour un code opaque, qui peut valoir toute
# chaîne) ; bornes en nombre, plus petite et plus grande valeur possibles (égales pour une
# borne connue ; NA : borne absente, ligne hors du contrôle) ; `absente_possible` : une borne
# inconnue peut être absente (ligne alors hors du contrôle) ; `inconnue` : ligne qui lit une
# valeur inconnue. Une ligne i est recouverte de façon forcée par une ligne j si, pour toute
# valeur des inconnues de i, j est de même groupe et valide et la recouvre : groupe connu et
# égal (ou domaine réduit à la valeur de l'autre ; une absence n'égale que l'absence, jamais
# une chaîne, .egal_valeur()), bornes prises au pire (début au plus tard,
# fin au plus tôt, absence possible exclue), ce pire étant commun à toutes les lignes. Vrai :
# - ligne connue : recouvre une ligne connue (.chevauchements()) ou une ligne qui la recouvre
#   de façon forcée ;
# - ligne inconnue : pour chaque valeur des colonnes de groupe inconnues (produit des
#   domaines ; un code opaque inconnu peut prendre une valeur nouvelle, jamais forcée), une
#   ligne la recouvre de façon forcée (pour toute affectation, il existe une ligne qui recouvre :
#   les bornes au pire valent pour toutes les affectations).
# Inconnu sinon si une affectation la fait recouvrir une autre ligne (bornes au mieux, groupe
# possible) ; faux sinon. Travail : lignes connues en O(n log n), puis chaque ligne inconnue face
# aux lignes de même `cle`. Attribut `index` : lignes inconnues qui rendent chaque ligne inconnue.
.chevauchements3 <- function(cle, groupe, d_min, d_max, f_min, f_max, absente_possible, inconnue) {
  n <- length(cle)
  hors <- is.na(cle)
  connue <- !inconnue
  groupe_connu <- .code_groupe(c(list(cle), lapply(groupe, `[[`, "valeurs")))
  vrai <- .chevauchements(ifelse(connue & !hors, groupe_connu, NA), d_min, f_min)
  possible <- rep(FALSE, n)
  force <- rep(FALSE, n)
  index <- vector("list", n)
  valide_possible <- (d_min <= f_max) %in% TRUE
  valide_force <- !absente_possible & (d_max <= f_min) %in% TRUE
  # recouvrement forcé de bornes, et valeur forcée d'une colonne de groupe (connue, ou inconnue
  # de domaine réduit à une valeur)
  bornes_force <- function(i, j) valide_force[i] & valide_force[j] & (d_max[i] <= f_min[j]) %in% TRUE &
    (d_max[j] <= f_min[i]) %in% TRUE
  forcee <- function(gc, i) !gc$inconnu[i] | (!is.null(gc$domaine) && length(gc$domaine) == 1L)
  valeur_forcee <- function(gc, i) if (is.null(gc$domaine) || length(gc$domaine) != 1L) gc$valeurs[i] else
    ifelse(gc$inconnu[i], gc$domaine, gc$valeurs[i])
  par_cle <- split(seq_len(n), cle)
  for (j in which(inconnue & !hors)) {
    i <- setdiff(par_cle[[as.character(cle[j])]], j)
    if (length(i) == 0L) next
    meme_possible <- rep(TRUE, length(i))
    meme_force <- rep(TRUE, length(i))
    for (gc in groupe) {
      ui <- gc$inconnu[i]
      uj <- gc$inconnu[j]
      egal <- !ui & !uj & .egal_valeur(gc$valeurs[i], gc$valeurs[j])
      dans <- function(x) is.null(gc$domaine) | x %in% gc$domaine
      meme_possible <- meme_possible & (egal | (uj & (ui | dans(gc$valeurs[i]))) | (ui & !uj & dans(gc$valeurs[j])))
      meme_force <- meme_force & forcee(gc, i) & forcee(gc, j) & .egal_valeur(valeur_forcee(gc, i), valeur_forcee(gc, j))
    }
    p <- meme_possible & valide_possible[i] & valide_possible[j] & (d_min[i] <= f_max[j]) %in% TRUE &
      (d_min[j] <= f_max[i]) %in% TRUE
    f <- meme_force & bornes_force(i, j)
    force[i[f]] <- TRUE
    if (any(f)) force[j] <- TRUE
    if (any(p)) {
      possible[i[p]] <- TRUE
      possible[j] <- TRUE
      index[[j]] <- c(index[[j]], j)
      index[i[p]] <- lapply(index[i[p]], c, j)
    }
    # pour toute valeur des colonnes de groupe inconnues de j, une ligne de groupe forcé égal
    # la recouvre de façon forcée (∀ affectation ∃ ligne)
    inconnues_j <- which(vapply(groupe, function(gc) gc$inconnu[j], NA))
    if (!force[j] && length(inconnues_j) > 0L &&
        !any(vapply(groupe[inconnues_j], function(gc) is.null(gc$domaine), NA))) {
      candidats <- i[bornes_force(i, j)]
      fixes <- rep(TRUE, length(candidats))
      for (gc in groupe[-inconnues_j]) fixes <- fixes & !gc$inconnu[candidats] & .egal_valeur(gc$valeurs[candidats], gc$valeurs[j])
      for (gc in groupe[inconnues_j]) fixes <- fixes & !gc$inconnu[candidats]
      candidats <- candidats[fixes]
      if (length(candidats) > 0L) {
        # rang de chaque candidat dans la grille des domaines dédoublonnés (par match(),
        # l'absence n'égalant que l'absence) ; forcé si chaque point de la grille est atteint
        rang <- 0
        taille <- 1
        for (gc in groupe[inconnues_j]) {
          dom <- unique(gc$domaine)
          rang <- rang + (match(gc$valeurs[candidats], dom) - 1) * taille
          taille <- taille * length(dom)
        }
        if (all((seq_len(taille) - 1) %in% rang)) force[j] <- TRUE
      }
    }
  }
  r <- vrai | force
  r[!r & possible] <- NA
  attr(r, "index") <- lapply(index, unique)
  r
}

# Égalité de deux valeurs d'une colonne de groupe : une absence n'égale que l'absence, jamais
# une chaîne (« NA » littéral compris) ; vecteurs recyclés (#121).
.egal_valeur <- function(a, b) (is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & a == b) %in% TRUE

# Code entier du groupe formé par les composantes (vecteurs de même longueur) : deux lignes ont
# le même code si et seulement si chaque composante est égale, une absence n'égalant que
# l'absence (match() sur les valeurs distinctes, sans paste() : un « NA » littéral ne se confond
# pas avec l'absence) ; `cles` : indices des composantes dont l'absence met la ligne hors du
# groupe (code NA ; spécification, § 2.2, B.4, clé manquante, forme « chevauchement », #121).
.code_groupe <- function(composantes, cles = integer(0)) {
  n <- length(composantes[[1L]])
  code <- rep(1, n)
  for (x in composantes) {
    k <- match(x, unique(x))
    z <- (code - 1) * max(c(k, 1L)) + k
    code <- match(z, unique(z))
  }
  for (c1 in cles) code[is.na(composantes[[c1]])] <- NA_integer_
  code
}

# --- Règle B : forme -----------------------------------------------------------------

# Écarts de forme de chaque table présente (constater_forme(), seam de la règle de forme) :
# colonne inconnue et colonne O ou C absente refusent la table ; type incompatible refuse
# la colonne (ou la table pour une colonne de clé). Une colonne absente ou mal typée devient
# inutilisable : les contrôles qui la lisent ne sont pas exécutés.
.regle_forme <- function(ctx) {
  for (table in setdiff(ctx$tables, "extraction")) {
    forme <- constater_forme(ctx$base[[table]], table, ctx$dico)
    n <- nrow(ctx$base[[table]])
    for (i in seq_len(nrow(forme))) {
      code <- forme$code[i]
      colonne <- forme$colonne[i]
      lignes <- if (code == "type_incompatible") forme$lignes[[i]] else seq_len(n)
      .ajouter_constat(ctx, code, table, colonne, lignes, .traitement_code_controle(ctx$dico, code), "exacte")
      if (code != "colonne_inconnue") {
        causes <- ctx$inutilisable[[table]]
        causes[[colonne]] <- code
        ctx$inutilisable[[table]] <- causes
      }
    }
  }
  # victimes absente alors que catastrophes est présente : refus R de catastrophes
  if ("catastrophes" %in% ctx$tables && !("victimes" %in% ctx$tables)) {
    .ajouter_constat(ctx, "table_conditionnelle_absente", "catastrophes", NA_character_,
                     seq_len(nrow(ctx$base$catastrophes)),
                     .traitement_code_controle(ctx$dico, "table_conditionnelle_absente"), "exacte")
  }
  invisible(NULL)
}

# --- Règle B : domaine ---------------------------------------------------------------

# Contrôles génériques tirés de colonnes.csv (chaîne vide, modalités, bornes de date,
# manquant obligatoire, réel non fini) puis règles propres aux colonnes (conditions des
# colonnes C, bornes écrites dans le domaine, signes de D09). Règle B à trois valeurs
# (spécification, § 2.2, B.5 et « Ordre d'exécution », étape 3 ; M217) : une passe par strate
# du graphe dérivé des règles enregistrées (.lectures_regle_b()), de 0 à la plus haute, puis
# une passe des règles de portée table (puits) ; dans une passe, l'ordre des règles est celui
# du code. Le répartiteur choisit les règles de chaque passe (`ctx$passe`, lu par .regle() ;
# #56, point 5). Les refus de valeur d'une colonne sont complets à la fin de sa strate ; un
# seul passage, sans point fixe (graphe acyclique). Chaque règle n'est exécutée qu'à sa propre
# passe, et ce qui ne dépend pas de la passe est calculé une fois par appel (#55) : registre,
# portées et graphe une fois (.regles_b(), .portees_registre(), .lectures_regle_b()), strate de
# chaque règle une fois par clé (.table_strates()) ; les règles génériques ne parcourent, à
# chaque passe, que les colonnes contrôlées par une règle de la passe (`ctx$passe_colonne`,
# lu par .regles_generiques() ; NULL hors des passes).
.regle_domaine <- function(ctx) {
  # valeurs inconnues de D03i (M701), lues par les règles B à trois valeurs dès la strate 0
  ctx$refus_valeur <- .ranger_inconnues_d03i(ctx$refus_valeur, .inconnues_d03i(ctx))
  registre <- .regles_b(ctx$dico)
  portee <- .portees_registre(ctx$dico, registre)
  strates <- .strates_regle_b(.lectures_regle_b(ctx$dico, registre, portee)$colonne)
  strate_de <- .table_strates(ctx$dico, registre, portee, strates)
  # colonnes contrôlées par au moins une règle du registre, à chaque passe ; une colonne hors du
  # registre est parcourue à toutes les passes (le répartiteur reste seul juge, `ctx$passe`)
  soi <- vapply(registre, function(k) paste(k$table, k$colonne, sep = "."), "")
  strate_k <- vapply(registre, function(k) strate_de(k$code, k$table, k$colonne), 0L)
  on.exit({ ctx$passe <- NULL; ctx$passe_colonne <- NULL })
  for (strate in 0:(max(c(0L, strates)) + 1L)) {
    ctx$passe <- function(code, table, colonne, lit, traitement) {
      strate_de(code, table, colonne) == strate
    }
    a_parcourir <- soi[strate_k == strate]
    ctx$passe_colonne <- function(table, colonne) {
      tc <- paste(table, colonne, sep = ".")
      tc %in% a_parcourir || !(tc %in% soi)
    }
    .regles_generiques(ctx)
    .regles_propres(ctx)
  }
  invisible(NULL)
}

# Absence refusée d'une colonne : obligatoire (O) sans défaut de manquant (.DEFAUTS_MANQUANT) ;
# une absence qui est une valeur (colonne C ou F, ou O à défaut de manquant) ne l'est pas.
# `.manquant_refuse()` : les valeurs manquantes d'une colonne dont l'absence est refusée (NA, pas
# NaN : un NaN est hors domaine, règle hors_domaine). Lues par manquant_obligatoire et D01a.
.absence_refusee <- function(obligatoire, defauts) {
  obligatoire == "O" && !any(eclater_champ(defauts) %in% .DEFAUTS_MANQUANT)
}
.manquant_refuse <- function(x) is.na(x) & !is.nan(x)

.regles_generiques <- function(ctx) {
  borne_basse <- as.numeric(as.Date("1901-01-01"))
  extraction <- as.numeric(ctx$date_extraction)
  for (table in setdiff(ctx$tables, "extraction")) {
    colonnes <- .colonnes_dico(ctx, table)
    for (i in seq_len(nrow(colonnes))) {
      col <- lapply(colonnes, `[[`, i)   # ligne i du dictionnaire (liste : plus rapide qu'une ligne de data.frame, #55)
      colonne <- col$colonne
      if (!(colonne %in% names(ctx$base[[table]]))) next   # absente : F sans effet, O ou C refusée
      if (!is.null(ctx$passe_colonne) && !ctx$passe_colonne(table, colonne)) next   # aucune règle de la passe (#55)
      x <- .valeurs(ctx, table, colonne)
      tc <- paste(table, colonne, sep = ".")
      if (col$type == "character") {
        .regle(ctx, "chaine_vide", table, colonne, character(0), "R", "exacte",
               function() .chaine_vide(x))
        modalites <- eclater_champ(col$modalites)
        if (length(modalites) > 0L) {
          .regle(ctx, "hors_domaine", table, colonne, character(0), "R", "exacte",
                 function() !is.na(x) & !.chaine_vide(x) & !(x %in% modalites))
        }
      }
      if (col$type == "Date") {
        if (col$futur_admis == "programmable") {
          .regle_date_programmable(ctx, borne_basse, extraction)
        } else {
          futur <- col$futur_admis == "TRUE"
          .regle(ctx, "D02c", table, colonne, character(0), "R", "exacte", function() {
            v <- as.numeric(x)
            v < borne_basse | (!futur & v > extraction)
          })
          if (futur) {
            .regle(ctx, "hors_domaine", table, colonne, character(0), "R", "exacte",
                   function() as.numeric(x) == as.numeric(as.Date("9999-12-31")))
          }
        }
      }
      if (col$type == "numeric") {
        .regle(ctx, "hors_domaine", table, colonne, character(0), "R", "exacte",
               function() is.nan(x) | is.infinite(x))
      }
      if (.absence_refusee(col$obligatoire, col$defauts)) {
        .regle(ctx, "manquant_obligatoire", table, colonne, character(0), "R", "exacte",
               function() .manquant_refuse(x))
      }
    }
  }
  invisible(NULL)
}

# evenements.date_effet : futur admis pour un type programmable seulement (motif compris,
# types_evenements.programmable) ; sinon, au plus la date d'extraction (D02c). Règle B à trois
# valeurs (site 1, strate 3) : programmable inconnu si le type, ou le motif dont dépend la
# programmation, est refusé pour sa valeur (.programmable3()).
.regle_date_programmable <- function(ctx, borne_basse, extraction) {
  .regle(ctx, "D02c", "evenements", "date_effet", c("evenements.type_evenement", "evenements.motif"),
         "R", "exacte", function() {
    v <- as.numeric(.valeurs(ctx, "evenements", "date_effet"))
    (v < borne_basse) %in% TRUE | (!.programmable3(ctx) & (v > extraction) %in% TRUE)
  }, partiel = TRUE)
}

# Événements d'un type programmable (motif compris, types_evenements.programmable) : leur
# date d'effet peut suivre leur saisie et l'extraction (dictionnaire, § 4).
.programmable <- function(ctx) {
  te <- ctx$dico$types_evenements
  motif <- .valeurs(ctx, "evenements", "motif")
  prog <- te$programmable[match(.valeurs(ctx, "evenements", "type_evenement"), te$type_evenement)]
  par_motif <- vapply(seq_along(prog), function(i) {
    !is.na(prog[i]) && startsWith(prog[i], "oui:") && !is.na(motif[i]) &&
      motif[i] %in% eclater_champ(substring(prog[i], 5L))
  }, NA)
  !is.na(prog) & (prog == "oui" | par_motif)
}

# Lignes d'une table conditionnée par une colonne d'une autre table jointe par clé.
.joindre <- function(ctx, table_cible, cle_cible, colonne_cible, valeurs_cle) {
  .valeurs(ctx, table_cible, colonne_cible)[.index_jointure(ctx, table_cible, cle_cible, valeurs_cle)]
}

# Colonne conditionnelle : `requis` (logique par ligne, NA : libre, ni requise ni interdite),
# fonction des valeurs des entrées (`entrees()`, liste nommée d'entrées .entree3()) ;
# manquant sous la condition -> manquant_obligatoire (sauf `defaut_manquant` : le manquant
# relève alors de ce défaut, traité en règle V) ; présent hors condition -> hors_domaine.
# Verdict à trois valeurs (.verdict3() ; forme « colonne conditionnelle », spécification,
# § 2.2, B.4) ; la colonne contrôlée (`y`) est lue telle quelle par une règle de portée colonne.
# Une chaîne vide n'y est ni présente ni manquante : elle ne reçoit que chaine_vide
# (spécification `donnees` v1.7, § 2.2, B.4, « Chaîne vide », #123 ; .chaine_vide()).
.regle_condition <- function(ctx, table, colonne, lit, requis, entrees, defaut_manquant = FALSE) {
  tc <- paste(table, colonne, sep = ".")
  verdict <- function(code, test) {
    y <- .entree3(ctx, tc, connue = .portee_effective(ctx$dico, code, table, colonne) != "table")
    .verdict3(c(list(y = y), entrees()), function(x) test(requis(x), x$y))
  }
  if (!defaut_manquant) {
    .regle(ctx, "manquant_obligatoire", table, colonne, lit, "R", "exacte",
           function() verdict("manquant_obligatoire", function(r, y) r %in% TRUE & is.na(y)), partiel = TRUE)
  }
  .regle(ctx, "hors_domaine", table, colonne, lit, "R", "exacte",
         function() verdict("hors_domaine", function(r, y) r %in% FALSE & !is.na(y) & !.chaine_vide(y)), partiel = TRUE)
}

# Cellules "" d'une colonne lue telle quelle par une règle de sa propre colonne (auto-lecture) :
# elles ne reçoivent que chaine_vide, la règle ne les tient ni pour présentes ni pour manquantes
# (spécification `donnees` v1.7, § 2.2, B.4, « Chaîne vide », #123). FAUX hors du type
# character, sans conversion (une date comparée à "" serait mise en texte à chaque appel).
# Depuis le dictionnaire 1.6 (M655 ; spécification `donnees` v1.9, § 9.6), une chaîne faite
# seulement de blancs est une chaîne vide : classe fermée `.BLANCS` (U+0020, U+0009 à U+000D),
# explicite et indépendante de la locale (jamais [[:space:]]), lue octet par octet (caractères
# ASCII, qu'aucun octet d'un caractère UTF-8 multioctet ne reproduit). Une valeur qui contient un
# autre caractère est lue telle quelle, blancs compris : aucun blanc n'est retiré.
.BLANCS <- " \t\n\v\f\r"
.chaine_vide <- function(x) {
  if (is.character(x)) !is.na(x) & grepl(paste0("^[", .BLANCS, "]*$"), x, useBytes = TRUE) else logical(length(x))
}
# Valeur qui contient un blanc de `.BLANCS` (domaine du collège, M656).
.contient_blanc <- function(x) !is.na(x) & grepl(paste0("[", .BLANCS, "]"), x, useBytes = TRUE)
# Valeurs d'une clé lue pour un appariement ou une comparaison de clés : une chaîne vide y suit
# la règle de la clé manquante (NA : aucun appariement, valeur absente et connue ; spécification
# `donnees` v1.7, § 2.2, B.4, « Clé manquante » et « Chaîne vide », erratum du 15 novembre
# 2026, #123). `.cle3()` : la même règle sur une entrée à trois valeurs (.connue3(),
# .jointe3()), valeurs et domaines propres.
.cle_manquante <- function(x) {
  x[.chaine_vide(x)] <- NA
  x
}
.cle3 <- function(e) {
  e$valeurs <- .cle_manquante(e$valeurs)
  if (!is.null(e$domaines)) e$domaines <- lapply(e$domaines, function(d) if (!is.null(d)) unique(.cle_manquante(d)))
  e
}
# La même règle pour les modules lecteurs de la vue (familles engagement et risque_en_cours ;
# spécification `donnees` v1.8, § 2.2, B.4, « Sites résiduels », #154, règle (v) : auxiliaires
# sans point). cle_renseignee() : vrai si la clé n'est ni manquante ni vide ; apparier_cles() :
# position de chaque clé de `x` dans `table` (match(), première occurrence), NA pour une clé
# manquante ou vide de l'un ou l'autre côté ; une appartenance s'écrit !is.na(apparier_cles()).
cle_renseignee <- function(x) !is.na(.cle_manquante(as.character(x)))
apparier_cles <- function(x, table) {
  match(.cle_manquante(as.character(x)), .cle_manquante(as.character(table)), incomparables = NA)
}

.hors_bornes <- function(ctx, table, colonne, mini = -Inf, maxi = Inf, lit = character(0),
                         code = "hors_domaine") {
  .regle(ctx, code, table, colonne, lit, "R", "exacte", function() {
    x <- as.numeric(.valeurs(ctx, table, colonne))
    !is.na(x) & (x < mini | x > maxi)
  })
}

# Règles propres aux colonnes, transcrites des domaines du § 3 du dictionnaire. Les ordres
# de dates (D02a), les saisies (D02b, D03g) et les manquants qui ont un défaut au § 9 sont
# des défauts de la vue (règle V) ou de la règle P, hors de ces règles. Une règle qui lit une
# colonne non clé refusable pour sa valeur autre que la sienne (règle concernée, .lectures_regle_b())
# rend un verdict à trois valeurs (.verdict3(), entrées .entree3() ; `partiel`) : `e3()`
# lit une colonne dans le mécanisme, `soi()` la colonne contrôlée par une règle de portée
# colonne, telle quelle (auto-lecture, P4).
.regles_propres <- function(ctx) {
  v <- function(table, colonne) .valeurs(ctx, table, colonne)
  e3 <- function(tc, ...) .entree3(ctx, tc, ...)
  soi <- function(tc) .entree3(ctx, tc, connue = TRUE)
  te <- ctx$dico$types_evenements

  # contrats
  individuel <- function(nature) ifelse(is.na(nature), NA, nature == "individuel")
  nature3 <- function() list(nature = e3("contrats.nature_contrat"))
  .regle_condition(ctx, "contrats", "id_adherent", "contrats.nature_contrat", function(x) !individuel(x$nature), nature3)
  .regle_condition(ctx, "contrats", "id_assure", "contrats.nature_contrat", function(x) individuel(x$nature), nature3)
  .regle_condition(ctx, "contrats", "date_terme",
                   c("contrats.nature_contrat", "contrats.id_contrat", "garanties_souscrites.id_contrat",
                     "garanties_souscrites.code_garantie"), function(x) individuel(x$nature) & x$deces, function() {
    list(nature = e3("contrats.nature_contrat"),
         deces = .existe3(ctx, "garanties_souscrites.code_garantie", "id_contrat", v("contrats", "id_contrat"),
                          function(g) g %in% "deces"))
  })
  fin3 <- function(table) function() list(fin = e3(paste0(table, ".date_fin"), domaine = .presence_date3(ctx)))
  .regle_condition(ctx, "contrats", "motif_fin", "contrats.date_fin", function(x) !is.na(x$fin), fin3("contrats"))
  .regle_condition(ctx, "contrats", "date_saisie_fin", "contrats.date_fin", function(x) !is.na(x$fin), fin3("contrats"),
                   defaut_manquant = TRUE)
  .hors_bornes(ctx, "contrats", "mois_echeance", 1, 12)
  .hors_bornes(ctx, "contrats", "preavis_mois", 0, 24)
  .regle(ctx, "hors_domaine", "contrats", "jour_echeance", "contrats.mois_echeance", "R", "exacte", function() {
    # mois_echeance : de 1 à 12 (obligatoire)
    .verdict3(list(jour = soi("contrats.jour_echeance"), mois = e3("contrats.mois_echeance", domaine = 1:12)), function(x) {
      maxi <- c(31L, 29L, 31L, 30L, 31L, 30L, 31L, 31L, 30L, 31L, 30L, 31L)[match(x$mois, 1:12)]
      !is.na(x$jour) & (x$jour < 1L | x$jour > ifelse(is.na(maxi), 31L, maxi))
    })
  }, partiel = TRUE)

  # garanties_souscrites : colonnes requises par garantie, manquantes hors de ces garanties
  code3 <- function() list(code = e3("garanties_souscrites.code_garantie"))
  requises <- list(type_franchise = "incapacite", regle_complement = c("incapacite", "invalidite"),
                   type_rente_conjoint = "rente_conjoint", option_iad = "deces",
                   periodicite_prestation = c("incapacite", "invalidite", "rente_conjoint", "rente_education"),
                   terme_prestation = c("incapacite", "invalidite", "rente_conjoint", "rente_education"),
                   conjoint_vise = c("double_effet", "rente_conjoint"), versement_double_effet = "double_effet",
                   non_remariage = c("double_effet", "rente_conjoint"),
                   prolongation_handicap = c("double_effet", "rente_education"),
                   maintien_double_effet = "double_effet", clause_type_beneficiaire = "deces")
  for (colonne in names(requises)) {
    garanties <- requises[[colonne]]
    .regle_condition(ctx, "garanties_souscrites", colonne, "garanties_souscrites.code_garantie",
                     function(x) ifelse(is.na(x$code), NA, x$code %in% garanties), code3)
  }
  # maintien_deces (dictionnaire 1.6, P6 ; spécification `donnees` v1.9, § 9.6) : requise pour la
  # garantie deces d'un contrat collectif, manquante ailleurs ; nature d'un contrat non joint
  # (garantie orpheline, D04b) : libre
  lit_nature <- c("garanties_souscrites.id_contrat", "contrats.id_contrat", "contrats.nature_contrat")
  code_nature3 <- function() {
    i <- .index_jointure(ctx, "contrats", "id_contrat", v("garanties_souscrites", "id_contrat"))
    c(code3(), list(nature = e3("contrats.nature_contrat", index = i)))
  }
  collectif <- function(nature) ifelse(is.na(nature), NA, nature != "individuel")
  .regle_condition(ctx, "garanties_souscrites", "maintien_deces", c("garanties_souscrites.code_garantie", lit_nature),
                   function(x) ifelse(x$code %in% "deces", collectif(x$nature), FALSE), code_nature3)
  # taux_technique_tarif : jamais pour l'arrêt de travail ; requis ailleurs selon le § 3, T4
  # (manquant : D03h, règle V) ; sur la garantie deces d'un contrat collectif, requis si
  # maintien_deces vaut TRUE, hors condition (présent : hors_domaine) s'il vaut FALSE
  # (dictionnaire 1.6, P6 : l'admission d'un taux présent sur un décès collectif est retirée) ;
  # bornes de contrôle.
  .regle(ctx, "hors_domaine", "garanties_souscrites", "taux_technique_tarif",
         c("garanties_souscrites.code_garantie", "garanties_souscrites.maintien_deces", lit_nature), "R", "exacte", function() {
    .verdict3(c(list(taux = soi("garanties_souscrites.taux_technique_tarif"),
                     maintien = e3("garanties_souscrites.maintien_deces")), code_nature3()), function(x) {
      !is.na(x$taux) & (x$code %in% c("incapacite", "invalidite") | x$taux < -0.05 | x$taux > 0.10 |
                          (x$code %in% "deces" & collectif(x$nature) %in% TRUE & x$maintien %in% FALSE))
    })
  }, partiel = TRUE)
  .regle(ctx, "hors_domaine", "garanties_souscrites", "college",
         c("garanties_souscrites.id_contrat", "contrats.id_contrat", "contrats.nature_contrat"), "R", "exacte",
         function() {
    i <- .index_jointure(ctx, "contrats", "id_contrat", v("garanties_souscrites", "id_contrat"))
    .verdict3(list(college = soi("garanties_souscrites.college"), nature = e3("contrats.nature_contrat", index = i)),
              function(x) !is.na(x$nature) & x$nature == "individuel" & x$college != "ensemble" &
                !.chaine_vide(x$college))
  }, partiel = TRUE)
  # domaine du collège (dictionnaire 1.6, M656, amende M511 ; spécification `donnees` v1.9,
  # § 9.6) : code opaque sans blanc (.BLANCS), ni « ; », ni « = » ; un collège fait seulement de
  # blancs ne reçoit que chaine_vide (une anomalie, un code)
  .regle(ctx, "hors_domaine", "garanties_souscrites", "college", character(0), "R", "exacte", function() {
    x <- v("garanties_souscrites", "college")
    !is.na(x) & !.chaine_vide(x) & (.contient_blanc(x) | grepl("[;=]", x, useBytes = TRUE))
  })

  # parametres
  par <- ctx$dico$parametres
  lit_par <- c("parametres.id_garantie_souscrite", "parametres.parametre",
               "garanties_souscrites.id_garantie_souscrite", "garanties_souscrites.code_garantie")
  par3 <- function() {
    i <- .index_jointure(ctx, "garanties_souscrites", "id_garantie_souscrite", v("parametres", "id_garantie_souscrite"))
    list(p = e3("parametres.parametre"), code = e3("garanties_souscrites.code_garantie", index = i))
  }
  ligne_par <- function(p, g) {
    i <- match(paste(g, p), paste(par$code_garantie, par$parametre))
    j <- match(p, par$parametre[par$code_garantie == "toutes"])
    ifelse(is.na(i), ifelse(is.na(j), NA_integer_, which(par$code_garantie == "toutes")[j]), i)
  }
  .regle(ctx, "hors_domaine", "parametres", "parametre", lit_par, "R", "exacte", function() {
    .verdict3(par3(), function(x) !is.na(x$p) & !is.na(x$code) & x$p %in% par$parametre & is.na(ligne_par(x$p, x$code)))
  }, partiel = TRUE)
  .regle_condition(ctx, "parametres", "categorie_invalidite", lit_par, function(x) {
    k <- ligne_par(x$p, x$code)
    ifelse(is.na(k), NA, grepl("categorie_invalidite", par$dimension[k], fixed = TRUE))
  }, par3)
  .hors_bornes(ctx, "parametres", "age_min", 0, 120)
  .hors_bornes(ctx, "parametres", "age_max", 0, 120)
  age_min <- v("parametres", "age_min")
  .regle_condition(ctx, "parametres", "age_max", "parametres.age_min", function(x) !is.na(x$age_min),
                   function() list(age_min = e3("parametres.age_min")))
  .regle(ctx, "hors_domaine", "parametres", "age_max", "parametres.age_min", "R", "exacte", function() {
    !is.na(age_min) & !is.na(v("parametres", "age_max")) & v("parametres", "age_max") < age_min
  })
  .hors_bornes(ctx, "parametres", "valeur", mini = 0, code = "D09")
  .regle(ctx, "hors_domaine", "parametres", "valeur", "parametres.parametre", "R", "exacte", function() {
    x <- v("parametres", "valeur")
    entier <- grepl("^age_|_jours$|_mois$", v("parametres", "parametre"))
    is.finite(x) & entier & x != trunc(x)
  })

  # assures
  .hors_bornes(ctx, "assures", "nombre_enfants_charge", 0, 20)
  .regle_condition(ctx, "assures", "date_situation_familiale",
                   c("assures.situation_familiale", "assures.nombre_enfants_charge"),
                   function(x) !is.na(x$situation) | !is.na(x$enfants), function() {
    # nombre_enfants_charge (facultatif) : lu pour sa seule présence
    list(situation = e3("assures.situation_familiale"), enfants = e3("assures.nombre_enfants_charge", domaine = c(0L, NA)))
  })

  # affiliations
  .regle(ctx, "hors_domaine", "affiliations", "id_contrat", c("contrats.id_contrat", "contrats.nature_contrat"),
         "R", "exacte", function() {
    i <- .index_jointure(ctx, "contrats", "id_contrat", v("affiliations", "id_contrat"))
    .verdict3(list(nature = e3("contrats.nature_contrat", index = i)), function(x) !is.na(x$nature) & x$nature == "individuel")
  }, partiel = TRUE)
  .regle_condition(ctx, "affiliations", "motif_fin", "affiliations.date_fin", function(x) !is.na(x$fin), fin3("affiliations"))
  .regle_condition(ctx, "affiliations", "date_saisie_fin", "affiliations.date_fin", function(x) !is.na(x$fin),
                   fin3("affiliations"), defaut_manquant = TRUE)
  .hors_bornes(ctx, "affiliations", "salaire_reference", mini = 0, code = "D09")
  .regle_condition(ctx, "affiliations", "date_designation", "affiliations.designation",
                   function(x) x$designation %in% c("type", "nominative"),
                   function() list(designation = e3("affiliations.designation")))
  .regle_condition(ctx, "affiliations", "structure_cotisation_sante", "affiliations.sante_organisme",
                   function(x) x$sante %in% TRUE, function() list(sante = e3("affiliations.sante_organisme")))

  # famille
  .regle(ctx, "hors_domaine", "famille", "date_naissance", "famille.situation", "R", "exacte", function() {
    .verdict3(list(naissance = soi("famille.date_naissance"), situation = e3("famille.situation")),
              function(x) !is.na(x$naissance) & x$situation %in% "a_naitre")
  }, partiel = TRUE)
  .regle(ctx, "hors_domaine", "famille", "situation", "famille.lien", "R", "exacte", function() {
    .verdict3(list(situation = soi("famille.situation"), lien = e3("famille.lien")),
              function(x) !is.na(x$situation) & !.chaine_vide(x$situation) & !is.na(x$lien) & x$lien != "enfant")
  }, partiel = TRUE)
  .regle(ctx, "hors_domaine", "famille", "id_sinistre",
         c("famille.id_assure", "sinistres.id_sinistre", "sinistres.id_assure"), "R", "exacte", function() {
    # clés comparées : une chaîne vide vaut clé manquante (.cle3(), #123)
    .verdict3(list(assure = .cle3(.jointe3(ctx, "sinistres.id_assure", "id_sinistre", v("famille", "id_sinistre"))),
                   local = .cle3(.connue3("famille.id_assure", v("famille", "id_assure")))),
              function(x) !is.na(x$assure) & x$assure != x$local)
  }, partiel = TRUE)

  # dossiers, rentes, prestations : D10 (a), garantie ou type de prestation incompatible ;
  # garantie d'un dossier : code_garantie de sa garantie souscrite, jointe par la clé
  lit_gar_dossier <- c("dossiers.id_dossier", "dossiers.id_garantie_souscrite",
                       "garanties_souscrites.id_garantie_souscrite", "garanties_souscrites.code_garantie")
  gar3 <- function(ids_gs) {
    e3("garanties_souscrites.code_garantie", index = .index_jointure(ctx, "garanties_souscrites", "id_garantie_souscrite", ids_gs))
  }
  # garantie jointe par le dossier : sur un dossier en double dont les occurrences divergent sur
  # id_garantie_souscrite, l'une des garanties de ses occurrences (lecture existentielle,
  # spécification `donnees` v1.7, § 2.2, B.4, « Clé primaire en double », #131) : connue si
  # elles concordent sur code_garantie, inconnue sinon (cause candidate D01a), de domaine leurs
  # codes (le domaine de la colonne pour un code refusé)
  gar_dossier3 <- function(ids_dossier) {
    jd <- .joindre3(ctx, "dossiers", "id_dossier", "id_garantie_souscrite", ids_dossier)
    e <- gar3(jd$valeurs)
    l <- which(jd$diverge)
    if (length(l) == 0L) return(e)
    n <- length(ids_dossier)
    if (is.null(e$d01a)) e$d01a <- rep(FALSE, n)
    if (is.null(e$domaines)) e$domaines <- vector("list", n)
    e$index <- as.list(e$index)
    # garanties des occurrences divergentes, jointes une seule fois sur leur union (coût d'une
    # jointure, non d'une jointure par ligne)
    gs <- v("dossiers", "id_garantie_souscrite")
    ids <- lapply(l, function(r) unique(gs[jd$index[[r]]]))
    u <- unique(unlist(ids))
    eu <- gar3(u)
    index_u <- as.list(eu$index)
    qs <- split(match(unlist(ids), u), factor(rep(seq_along(ids), lengths(ids)), levels = seq_along(ids)))
    for (k in seq_along(l)) {
      r <- l[k]
      q <- qs[[k]]
      inconnu_q <- eu$inconnu[q]
      dom <- unique(unlist(lapply(q, function(z) {
        if (!eu$inconnu[z]) eu$valeurs[z] else if (!is.null(eu$domaines[[z]])) eu$domaines[[z]] else eu$domaine
      })))
      e$index[[r]] <- unique(stats::na.omit(unlist(index_u[q])))
      if (!any(inconnu_q) && length(dom) == 1L) {
        e$valeurs[r] <- dom
        e$inconnu[r] <- FALSE
        e$d01a[r] <- FALSE
        e$domaines[r] <- list(NULL)
        next
      }
      e$inconnu[r] <- TRUE
      e$d01a[r] <- TRUE
      e$domaines[[r]] <- dom
    }
    e
  }
  nature_sinistre3 <- function(ids_sinistre) {
    e3("sinistres.nature_sinistre", index = .index_jointure(ctx, "sinistres", "id_sinistre", ids_sinistre))
  }
  .regle(ctx, "D10a", "dossiers", "id_garantie_souscrite",
         c(lit_gar_dossier, "dossiers.id_sinistre", "sinistres.id_sinistre", "sinistres.nature_sinistre"),
         "R", "exacte", function() {
    .verdict3(list(g = gar3(v("dossiers", "id_garantie_souscrite")), nat = nature_sinistre3(v("dossiers", "id_sinistre"))),
              function(x) {
      compatibles <- ifelse(x$g %in% c("incapacite", "invalidite"), x$nat == "arret_travail", x$nat %in% c("deces", "iad"))
      !is.na(x$g) & !is.na(x$nat) & !compatibles
    })
  }, partiel = TRUE)
  .regle(ctx, "D10a", "rentes", "id_dossier", c("rentes.id_dossier", lit_gar_dossier), "R", "exacte", function() {
    .verdict3(list(g = gar_dossier3(v("rentes", "id_dossier"))), function(x) !is.na(x$g) & !(x$g %in% .GARANTIES_RENTE))
  }, partiel = TRUE)
  .regle_condition(ctx, "rentes", "id_membre", c("rentes.id_dossier", lit_gar_dossier), function(x) {
    ifelse(x$g %in% c("rente_conjoint", "rente_education"), TRUE, ifelse(x$g %in% "invalidite", FALSE, NA))
  }, function() list(g = gar_dossier3(v("rentes", "id_dossier"))))
  # type_prestation : contrôlé par une règle de portée table, lu dans le mécanisme (P4)
  .regle(ctx, "D10a", "prestations", "type_prestation", c("prestations.id_dossier", lit_gar_dossier),
         "R", "exacte", function() {
    .verdict3(list(type = e3("prestations.type_prestation"), g = gar_dossier3(v("prestations", "id_dossier"))), function(x) {
      attendu <- ifelse(x$g == "incapacite", "indemnite_journaliere",
                        ifelse(x$g %in% .GARANTIES_RENTE, "arrerage", "capital"))
      !is.na(x$g) & !is.na(x$type) & x$type != attendu
    })
  }, partiel = TRUE)
  type_p3 <- function() list(type = e3("prestations.type_prestation"))
  .regle_condition(ctx, "prestations", "id_rente", "prestations.type_prestation",
                   function(x) ifelse(is.na(x$type), NA, x$type == "arrerage"), type_p3)
  .regle(ctx, "hors_domaine", "prestations", "id_rente", c("rentes.id_rente", "rentes.id_dossier",
                                                           "prestations.id_dossier"), "R", "exacte", function() {
    # clés comparées : une chaîne vide vaut clé manquante (.cle3(), #123)
    .verdict3(list(d = .cle3(.jointe3(ctx, "rentes.id_dossier", "id_rente", v("prestations", "id_rente"))),
                   local = .cle3(.connue3("prestations.id_dossier", v("prestations", "id_dossier")))),
              function(x) !is.na(x$d) & !is.na(x$local) & x$d != x$local)
  }, partiel = TRUE)
  for (colonne in c("debut_periode", "fin_periode")) {
    .regle_condition(ctx, "prestations", colonne, "prestations.type_prestation",
                     function(x) ifelse(is.na(x$type), NA, x$type != "capital"), type_p3, defaut_manquant = TRUE)
  }
  .regle_signe(ctx, "prestations", "nature_mouvement",
               list(paiement = "positif", regularisation = "non_nul"))
  .regle_signe(ctx, "cotisations", "nature_mouvement",
               list(emission = "positif", annulation = "negatif", regularisation = "non_nul",
                    encaissement = "non_nul"))

  # beneficiaires
  .regle_condition(ctx, "beneficiaires", "id_membre", "beneficiaires.qualite", function(x) {
    ifelse(is.na(x$qualite), NA, x$qualite %in% c("conjoint_survivant", "enfant_a_charge"))
  }, function() list(qualite = e3("beneficiaires.qualite")))
  .regle(ctx, "hors_domaine", "beneficiaires", "part", character(0), "R", "exacte", function() {
    x <- v("beneficiaires", "part")
    is.finite(x) & (x <= 0 | x > 1)
  })

  # evenements : niveau, garanties, colonnes requises et motifs du type (types_evenements)
  type3 <- function() list(type = e3("evenements.type_evenement"))
  niveau_de <- function(type) te$niveau[match(type, te$type_evenement)]
  .regle_condition(ctx, "evenements", "id_dossier", "evenements.type_evenement", function(x) {
    niveau <- niveau_de(x$type)
    ifelse(is.na(niveau), NA, ifelse(niveau == "sinistre", FALSE, ifelse(grepl("sinistre", niveau), NA, TRUE)))
  }, type3)
  lit_ev_dossier <- c("evenements.type_evenement", "evenements.id_dossier", lit_gar_dossier)
  .regle_condition(ctx, "evenements", "id_rente", lit_ev_dossier, function(x) {
    niveau <- niveau_de(x$type)
    rente <- grepl("rente", niveau)
    ifelse(is.na(niveau), NA, ifelse(!rente, FALSE,
           ifelse(x$g %in% .GARANTIES_RENTE, TRUE, ifelse(x$g %in% "incapacite", FALSE, NA))))
  }, function() list(type = e3("evenements.type_evenement"), g = gar_dossier3(v("evenements", "id_dossier"))))
  .regle(ctx, "hors_domaine", "evenements", "id_dossier",
         c("evenements.id_sinistre", "dossiers.id_dossier", "dossiers.id_sinistre"), "R", "exacte", function() {
    # clés comparées : une chaîne vide vaut clé manquante (.cle3(), #123)
    .verdict3(list(s = .cle3(.jointe3(ctx, "dossiers.id_sinistre", "id_dossier", v("evenements", "id_dossier"))),
                   local = .cle3(.connue3("evenements.id_sinistre", v("evenements", "id_sinistre")))),
              function(x) !is.na(x$s) & x$s != x$local)
  }, partiel = TRUE)
  .regle(ctx, "hors_domaine", "evenements", "id_rente",
         c("evenements.id_dossier", "rentes.id_rente", "rentes.id_dossier"), "R", "exacte", function() {
    # clés comparées : une chaîne vide vaut clé manquante (.cle3(), #123)
    .verdict3(list(d = .cle3(.jointe3(ctx, "rentes.id_dossier", "id_rente", v("evenements", "id_rente"))),
                   local = .cle3(.connue3("evenements.id_dossier", v("evenements", "id_dossier")))),
              function(x) !is.na(x$d) & !is.na(x$local) & x$d != x$local)
  }, partiel = TRUE)
  # type compatible avec la nature du sinistre (niveau sinistre : arrêt de travail) ou avec
  # la garantie du dossier (types_evenements.garanties)
  .regle(ctx, "hors_domaine", "evenements", "type_evenement",
         c(lit_ev_dossier, "evenements.id_sinistre", "sinistres.id_sinistre", "sinistres.nature_sinistre"),
         "R", "exacte", function() {
    .verdict3(list(type = soi("evenements.type_evenement"), nat = nature_sinistre3(v("evenements", "id_sinistre")),
                   g = gar_dossier3(v("evenements", "id_dossier"))), function(x) {
      k <- match(x$type, te$type_evenement)
      niveau <- te$niveau[k]
      garanties <- te$garanties[k]
      sinistre_seul <- !is.na(niveau) & niveau == "sinistre"
      hors_nature <- sinistre_seul & !is.na(x$nat) & x$nat != "arret_travail"
      hors_garantie <- !sinistre_seul & !is.na(x$g) & !is.na(garanties) & garanties != "toutes" &
        !mapply(function(gg, liste) gg %in% eclater_champ(liste), x$g, garanties)
      hors_nature | hors_garantie
    })
  }, partiel = TRUE)
  requiert <- function(type, colonne) {
    k <- match(type, te$type_evenement)
    ifelse(is.na(k), NA, vapply(te$colonnes_requises[ifelse(is.na(k), 1L, k)],
                                function(r) colonne %in% eclater_champ(r), NA))
  }
  .regle_condition(ctx, "evenements", "categorie_invalidite", "evenements.type_evenement",
                   function(x) requiert(x$type, "categorie_invalidite"), type3, defaut_manquant = TRUE)
  .regle_condition(ctx, "evenements", "montant", "evenements.type_evenement", function(x) requiert(x$type, "montant"), type3)
  .hors_bornes(ctx, "evenements", "montant", mini = 0, code = "D09")
  .hors_bornes(ctx, "evenements", "montant_securite_sociale", mini = 0)
  .regle_condition(ctx, "evenements", "source_information", "evenements.type_evenement",
                   function(x) requiert(x$type, "source_information"), type3)
  # motif : de la liste du type ; manquant pour sortie ou cloture_dossier sans prestation sur
  # aucun dossier du sinistre (base entière) : D05, règle V ; sinon manquant_obligatoire ; un
  # motif vide ne reçoit que chaine_vide (#123)
  .regle(ctx, "hors_domaine", "evenements", "motif", "evenements.type_evenement", "R", "exacte", function() {
    .verdict3(list(motif = soi("evenements.motif"), type = e3("evenements.type_evenement")), function(x) {
      k <- match(x$type, te$type_evenement)
      !is.na(x$motif) & !.chaine_vide(x$motif) & !is.na(k) &
        !mapply(function(m, liste) m %in% eclater_champ(liste), x$motif, te$motifs[ifelse(is.na(k), 1L, k)])
    })
  }, partiel = TRUE)
  .regle(ctx, "manquant_obligatoire", "evenements", "motif",
         c("evenements.type_evenement", "evenements.id_sinistre", "prestations.id_dossier",
           "dossiers.id_dossier", "dossiers.id_sinistre"), "R", "exacte", function() {
    # sinistre d'une prestation : celui de son dossier ; sur un dossier en double aux
    # occurrences divergentes, l'un des leurs (lecture existentielle, #131) : un sinistre payé
    # par ce seul chemin l'est de façon inconnue (cause candidate D01a) ; sinistres comparés :
    # une chaîne vide vaut clé manquante (apparier_cles(), #123, #158)
    js <- .joindre3(ctx, "dossiers", "id_dossier", "id_sinistre", v("prestations", "id_dossier"))
    sinistres_payes <- unique(js$valeurs[!js$diverge])
    possibles <- unique(unlist(lapply(js$index[js$diverge], function(o) v("dossiers", "id_sinistre")[o])))
    ev_sinistre <- v("evenements", "id_sinistre")
    paye <- !is.na(apparier_cles(ev_sinistre, sinistres_payes))
    paye_inconnu <- !paye & !is.na(apparier_cles(ev_sinistre, possibles))
    .verdict3(list(motif = soi("evenements.motif"), type = e3("evenements.type_evenement"),
                   paye = list(tc = "dossiers.id_sinistre", valeurs = paye, inconnu = paye_inconnu, index = NULL,
                               domaine = c(TRUE, FALSE), d01a = paye_inconnu)),
              function(x) {
      d05 <- x$type %in% c("sortie", "cloture_dossier") & !x$paye
      is.na(x$motif) & requiert(x$type, "motif") %in% TRUE & !d05
    })
  }, partiel = TRUE)

  # victimes
  .regle_condition(ctx, "victimes", "date_deces", "victimes.statut_victime",
                   function(x) ifelse(is.na(x$statut), NA, x$statut == "decedee"),
                   function() list(statut = e3("victimes.statut_victime")))
  .regle(ctx, "D10h", "victimes", "id_sinistre", c("victimes.id_assure", "sinistres.id_sinistre", "sinistres.id_assure"),
         "R", "exacte", function() {
    # clés comparées : une chaîne vide vaut clé manquante (.cle3(), #123)
    .verdict3(list(assure = .cle3(.jointe3(ctx, "sinistres.id_assure", "id_sinistre", v("victimes", "id_sinistre"))),
                   local = .cle3(.connue3("victimes.id_assure", v("victimes", "id_assure")))),
              function(x) !is.na(x$assure) & !is.na(x$local) & x$assure != x$local)
  }, partiel = TRUE)

  # evaluations_gestion (dictionnaire, § 7.5 : incohérences, refus de la table seule)
  .hors_bornes(ctx, "evaluations_gestion", "montant_restant", mini = 0)
  .regle(ctx, "hors_domaine", "evaluations_gestion", "date_saisie", "evaluations_gestion.date_effet", "R", "exacte",
         function() v("evaluations_gestion", "date_saisie") < v("evaluations_gestion", "date_effet"))

  # designations, ayants_droit_sante
  .hors_bornes(ctx, "designations", "rang", mini = 1)
  .regle(ctx, "hors_domaine", "designations", "quote_part", character(0), "R", "exacte", function() {
    x <- v("designations", "quote_part")
    is.finite(x) & (x <= 0 | x > 1)
  })
  .regle(ctx, "hors_domaine", "designations", "id_affiliation",
         c("affiliations.id_affiliation", "affiliations.designation"), "R", "exacte", function() {
    ids <- v("designations", "id_affiliation")
    i <- .index_jointure(ctx, "affiliations", "id_affiliation", ids)
    .verdict3(list(trouve = .connue3("designations.id_affiliation", !is.na(i)),
                   designation = e3("affiliations.designation", index = i)),
              function(x) x$trouve & !(x$designation %in% "nominative"))
  }, partiel = TRUE)
  .regle(ctx, "hors_domaine", "ayants_droit_sante", "id_affiliation",
         c("affiliations.id_affiliation", "affiliations.sante_organisme"), "R", "exacte", function() {
    # une clé manquante ne s'apparie à aucune ligne (index NA ; spécification `donnees` v1.7, § 2.2, B.4, #130)
    ids <- v("ayants_droit_sante", "id_affiliation")
    .verdict3(list(trouve = .connue3("ayants_droit_sante.id_affiliation",
                                     !is.na(.index_jointure(ctx, "affiliations", "id_affiliation", ids))),
                   sante = .jointe3(ctx, "affiliations.sante_organisme", "id_affiliation", ids)),
              function(x) x$trouve & !(x$sante %in% TRUE))
  }, partiel = TRUE)
  invisible(NULL)
}

# Signe d'un montant selon la nature du mouvement : un signe contraire au domaine est le
# défaut D09 (refus R de la colonne, M145) ; un zéro là où le domaine exige un montant non
# nul (ou strictement positif) n'a pas de signe contraire : hors_domaine. Verdict à trois
# valeurs (sites 26 et 27) : la nature du mouvement est lue dans le mécanisme, le montant tel
# quel.
.regle_signe <- function(ctx, table, colonne_nature, regles) {
  lit <- paste(table, colonne_nature, sep = ".")
  attendu <- function(nature) unlist(regles, use.names = FALSE)[match(nature, names(regles))]
  entrees <- function() list(montant = .entree3(ctx, paste(table, "montant", sep = "."), connue = TRUE),
                             nature = .entree3(ctx, lit))
  .regle(ctx, "D09", table, "montant", lit, "R", "exacte", function() {
    .verdict3(entrees(), function(x) {
      a <- attendu(x$nature)
      is.finite(x$montant) & ((a %in% "positif" & x$montant < 0) | (a %in% "negatif" & x$montant > 0))
    })
  }, partiel = TRUE)
  .regle(ctx, "hors_domaine", table, "montant", lit, "R", "exacte", function() {
    .verdict3(entrees(), function(x) is.finite(x$montant) & x$montant == 0 & !is.na(attendu(x$nature)))
  }, partiel = TRUE)
}

# --- Règle B : clés ------------------------------------------------------------------

# Clé primaire en double (D01a), clés étrangères orphelines (D04a, D04b ; référence
# composite de affiliations.college), chevauchements de versions et de paliers.
.regle_cles <- function(ctx) {
  dico <- ctx$dico
  for (table in setdiff(ctx$tables, "extraction")) {
    cle <- eclater_champ(dico$tables$cle_primaire[dico$tables$table == table])
    lit <- paste(table, cle, sep = ".")
    # lignes de l'écart : les k - 1 occurrences de chaque clé qui suivent l'original dans l'ordre
    # canonique (.ordre_canonique()), et non dans l'ordre des lignes (#131) ; une ligne dont une
    # composante est vide, ou manque alors que son absence est un refus (colonne O sans défaut
    # de manquant, comme la règle manquant_obligatoire), n'entre pas dans la détection : elle
    # n'est en double d'aucune ligne et aucune ligne n'est en double d'elle (spécification
    # `donnees` v1.8, § 2.2, B.4, « Clé primaire à composante manquante (D01a) », #143) ; une
    # composante dont l'absence est une valeur (colonne C ou F, ou O à défaut de manquant : D03g
    # de famille.date_saisie) n'égale que l'absence
    col <- .colonnes_dico(ctx, table)
    refusee <- vapply(cle, function(c1) {
      k <- match(c1, col$colonne)
      .absence_refusee(col$obligatoire[k], col$defauts[k])
    }, NA)
    .regle(ctx, "D01a", table, cle[1L], lit, "R", "exacte", function() {
      o <- .ordre_canonique(ctx, table)
      x <- lapply(cle, function(c1) .valeurs(ctx, table, c1)[o])
      hors <- Reduce(`|`, Map(function(v, refusee1) .chaine_vide(v) | (refusee1 & .manquant_refuse(v)), x, refusee))
      r <- logical(length(o))
      r[o[!hors]] <- duplicated(as.data.frame(lapply(x, `[`, !hors), stringsAsFactors = FALSE))
      r
    })
  }
  .orphelines(ctx)
  # chevauchements à trois valeurs (sites 40 et 41, .chevauchements3()), sur les refus de
  # valeur des strates : groupe (contrat, garantie, collège ; le collège, code opaque, peut
  # valoir toute chaîne) et versions [date_effet, date_fin], une fin absente étant ouverte ;
  # une borne inconnue prend toute date du domaine (.plage_date3()), ou l'absence
  .regle(ctx, "chevauchement", "garanties_souscrites", NA_character_,
         paste0("garanties_souscrites.", c("id_contrat", "code_garantie", "college", "date_effet", "date_fin")),
         "R", "exacte", function() {
    v <- function(c1) .valeurs(ctx, "garanties_souscrites", c1)
    u <- function(c1) .inconnu(ctx, "garanties_souscrites", c1)
    debut <- as.numeric(v("date_effet"))
    fin <- as.numeric(v("date_fin"))
    fin <- ifelse(is.na(fin), Inf, fin)
    plage_debut <- .plage_date3(ctx, "garanties_souscrites", "date_effet")
    plage_fin <- .plage_date3(ctx, "garanties_souscrites", "date_fin")
    groupe <- list(list(valeurs = v("code_garantie"), inconnu = u("code_garantie"),
                        domaine = .domaine3(ctx, "garanties_souscrites", "code_garantie")),
                   list(valeurs = v("college"), inconnu = u("college"), domaine = NULL))
    r <- .chevauchements3(.code_groupe(list(.cle_manquante(v("id_contrat"))), cles = 1L), groupe,
                          d_min = ifelse(u("date_effet"), plage_debut[1L], debut),
                          d_max = ifelse(u("date_effet"), plage_debut[2L], debut),
                          f_min = ifelse(u("date_fin"), plage_fin[1L], fin), f_max = ifelse(u("date_fin"), Inf, fin),
                          absente_possible = rep(FALSE, length(debut)),
                          inconnue = u("code_garantie") | u("college") | u("date_effet") | u("date_fin"))
    attr(r, "index") <- stats::setNames(rep(list(attr(r, "index")), 4L),
                                        paste0("garanties_souscrites.", c("code_garantie", "college", "date_effet", "date_fin")))
    r
  }, partiel = TRUE)
  # paliers [age_min, age_max] (sans palier : [0, 120]) ; age_max inconnu (lu sous un age_min
  # présent) : de 0 à 120 (.hors_bornes(), .regles_propres()) ou absent (colonne C)
  .regle(ctx, "chevauchement", "parametres", NA_character_,
         paste0("parametres.", c("id_garantie_souscrite", "parametre", "categorie_invalidite", "age_min", "age_max")),
         "R", "exacte", function() {
    v <- function(c1) .valeurs(ctx, "parametres", c1)
    sans_palier <- is.na(v("age_min"))
    inconnu <- .inconnu(ctx, "parametres", "age_max") & !sans_palier
    debut <- ifelse(sans_palier, 0, as.numeric(v("age_min")))
    fin <- ifelse(sans_palier, 120, as.numeric(v("age_max")))
    # clé du groupe : garantie et paramètre (une absence, ou une chaîne vide, met la ligne hors du
    # contrôle, .cle_manquante(), v1.8, #143) ; l'absence de catégorie est une valeur du groupe
    # (#121), mais une catégorie vide met la ligne hors du contrôle (v1.8, #143 : apparier deux
    # chaînes vides inventerait un lien ; .cle_manquante() ne s'applique pas à la composante, il
    # confondrait la chaîne vide avec l'absence)
    categorie <- v("categorie_invalidite")
    groupe <- .code_groupe(list(.cle_manquante(v("id_garantie_souscrite")), .cle_manquante(v("parametre")), categorie),
                           cles = 1:2)
    groupe[.chaine_vide(categorie)] <- NA_integer_
    r <- .chevauchements3(groupe,
                          list(), d_min = debut, d_max = debut, f_min = ifelse(inconnu, 0, fin),
                          f_max = ifelse(inconnu, 120, fin), absente_possible = inconnu, inconnue = inconnu)
    attr(r, "index") <- list(parametres.age_max = attr(r, "index"))
    r
  }, partiel = TRUE)
  invisible(NULL)
}

# Ordre canonique des lignes de `table` (spécification `donnees` v1.7, § 2.2, B.4, « Clé
# primaire en double », lignes de l'écart D01a, #131) : date qui gouverne la visibilité
# (première de .DATES_VISIBILITE, comme la copie de D01b), puis contenu entier de la ligne,
# colonnes dans l'ordre du dictionnaire, en tri radix, valeur manquante en dernier. L'original
# d'un identifiant en double est sa première ligne dans cet ordre ; deux lignes à égalité ont
# le même contenu. Une colonne de date se trie sur sa valeur numérique, une colonne logique,
# numérique, textuelle ou facteur telle quelle (une colonne de type incompatible garde son type
# lu) ; toute autre (liste, par exemple : défaut de forme) sur le texte exact de chaque valeur
# (deparse() à 17 chiffres, NA et attributs gardés), pour que l'ordre reste total. Une colonne
# en double précision est précédée de la clé is.nan() : le tri radix place NA et NaN à égalité,
# ils sont ainsi départagés (NaN après NA).
.ordre_canonique <- function(ctx, table) {
  num <- function(x) {
    if (inherits(x, "Date")) return(as.numeric(x))
    if (!is.list(x) && (is.numeric(x) || is.character(x) || is.logical(x) || is.factor(x))) return(x)
    vapply(x, function(z) paste(deparse(z, control = c("keepNA", "keepInteger", "niceNames", "showAttributes", "digits17")),
                                collapse = "\n"), "", USE.NAMES = FALSE)
  }
  colonnes <- c(.DATES_VISIBILITE[[table]][1L], .colonnes_dico(ctx, table)$colonne)
  cles <- unlist(lapply(colonnes, function(c1) {
    x <- num(.valeurs(ctx, table, c1))
    if (is.double(x)) list(is.nan(x), x) else list(x)
  }), recursive = FALSE)
  do.call(order, c(unname(cles), list(method = "radix", na.last = TRUE)))
}

# Clés étrangères orphelines (D04a, D04b ; référence composite de affiliations.college),
# détectées en règle B sur la base entière, identiques à tout arrêté, quel que soit leur
# traitement (R ou X selon la table, dictionnaire, § 9 ; spécification, § 2.4 et § 2.5,
# critères 1 et 3) : la restriction aux lignes visibles par leur condition propre ne porte
# que sur le traitement et l'enjeu (sous-parties suivantes). Un manquant de
# prestations.id_dossier (colonne O dont le manquant relève de D04a) est une prestation
# orpheline.
.orphelines <- function(ctx) {
  for (table in setdiff(ctx$tables, "extraction")) {
    colonnes <- .colonnes_dico(ctx, table)
    for (i in which(nzchar(colonnes$reference))) {
      colonne <- colonnes$colonne[i]
      cibles <- strsplit(eclater_champ(colonnes$reference[i]), ".", fixed = TRUE)
      table_cible <- cibles[[1L]][1L]
      cols_cible <- vapply(cibles, `[`, "", 2L)
      locales <- if (length(cibles) == 1L) colonne else cols_cible
      code <- if (table == "prestations") "D04a" else "D04b"
      traitement <- if (code == "D04a" || (table %in% .TABLES_D04B_X && length(cibles) == 1L)) "X" else "R"
      lit <- c(paste(table, locales, sep = "."), paste(table_cible, cols_cible, sep = "."))
      manquant_orphelin <- table == "prestations" && colonne == "id_dossier"
      .regle(ctx, code, table, colonne, lit, traitement, "exacte", function() {
        valeurs_locales <- lapply(locales, function(c1) .valeurs(ctx, table, c1))
        valeurs_cible <- lapply(cols_cible, function(c1) .valeurs(ctx, table_cible, c1))
        inconnues <- lapply(cols_cible, function(c1) .inconnu(ctx, table_cible, c1))
        connue <- !Reduce(`|`, inconnues)
        # clé composite des colonnes `k` (toutes par défaut), manquante si l'une l'est (une clé
        # manquante ne s'apparie à aucune ligne, .existe_kleene()) ; sans colonne (`k` vide, toutes
        # les colonnes cibles inconnues), la même pour toutes les lignes (préfixe "\001" : jamais
        # une chaîne vide ni faite de blancs, que .existe_kleene() tient pour une clé manquante,
        # #123, M655 ; le séparateur "\r" est un blanc, le préfixe ne peut pas l'être)
        cle_de <- function(valeurs, k = seq_along(valeurs)) {
          x <- do.call(paste, c(list(rep("\001", length(valeurs[[1L]]))), valeurs[k], sep = "\r"))
          if (length(k) > 0L) x[Reduce(`|`, lapply(valeurs[k], is.na))] <- NA
          x
        }
        local <- cle_de(valeurs_locales)
        cible <- cle_de(valeurs_cible)
        # une chaîne vide, ou faite de blancs (M655), est chaine_vide, non une orpheline (une
        # anomalie, un code : m1)
        vide <- Reduce(`|`, lapply(valeurs_locales, .chaine_vide))
        manquant <- Reduce(`|`, lapply(valeurs_locales, is.na))
        existe <- .existe_kleene(local, cible, vrai = connue, possible = rep(FALSE, length(cible)))$valeurs
        r <- !vide & (if (manquant_orphelin) manquant | !existe else !manquant & !existe)
        # règle B à trois valeurs (site 39, référence composite de affiliations.college) : une
        # ligne cible de valeur inconnue (refus de valeur d'une colonne cible non clé) peut porter
        # la clé locale si ses colonnes connues l'égalent et que la valeur locale est du domaine
        # de chaque colonne inconnue (code opaque : toute chaîne) ; la ligne est alors inconnue
        # (.existe_kleene(), sur la clé des colonnes connues, par motif de colonnes inconnues).
        # Le masque est le verdict d'avant la boucle (`r0`) et l'index se cumule sur tous les
        # motifs : une ligne possible sous deux motifs garde les lignes cibles de chacun, toutes
        # lues pour sa cause (spécification `donnees` v1.6, § 2.2, B.5, #59)
        if (!all(connue)) {
          r0 <- r
          index <- vector("list", length(r))
          lignes <- which(!connue)
          motifs <- vapply(lignes, function(j) paste(which(vapply(inconnues, `[`, NA, j)), collapse = ","), "")
          for (motif in unique(motifs)) {
            l <- lignes[motifs == motif]
            s <- as.integer(strsplit(motif, ",", fixed = TRUE)[[1L]])
            k <- setdiff(seq_along(cols_cible), s)
            cle_l <- cle_de(valeurs_locales, k)
            for (m in s) {
              col_cible <- .colonnes_dico(ctx, table_cible)
              domaine <- eclater_champ(col_cible$modalites[col_cible$colonne == cols_cible[m]])
              if (length(domaine) > 0L) cle_l[!(valeurs_locales[[m]] %in% domaine)] <- NA
            }
            cle_l[!(r0 %in% TRUE)] <- NA
            e <- .existe_kleene(cle_l, cle_de(valeurs_cible, k), vrai = rep(FALSE, length(cible)),
                                possible = seq_along(cible) %in% l)
            if (any(e$inconnu)) {
              r[e$inconnu] <- NA
              index[e$inconnu] <- Map(c, index[e$inconnu], e$index[e$inconnu])
            }
          }
          attr(r, "index") <- stats::setNames(rep(list(index), length(cols_cible)), paste(table_cible, cols_cible, sep = "."))
        }
        r
      }, partiel = TRUE)
    }
  }
  invisible(NULL)
}

# Lignes dont l'intervalle fermé [debut, fin] en recouvre un autre de même groupe (bornes
# manquantes ou intervalle renversé (début > fin) : ligne hors du contrôle). Tri par groupe
# puis début : une ligne en recouvre une autre si la plus grande fin des lignes qui la
# précèdent dans son groupe atteint son début, ou si le début de la suivante est au plus
# sa fin ; en O(n log n), non en nombre de paires par groupe (#35).
.chevauchements <- function(groupe, debut, fin) {
  res <- rep(FALSE, length(groupe))
  ok <- which(!is.na(groupe) & !is.na(debut) & !is.na(fin) & debut <= fin)
  if (length(ok) < 2L) return(res)
  g <- match(groupe[ok], unique(groupe[ok]))
  o <- order(g, debut[ok], method = "radix")
  i <- ok[o]
  g <- g[o]
  d <- debut[i]
  f <- fin[i]
  n <- length(i)
  debut_groupe <- c(TRUE, g[-1L] != g[-n])
  fin_groupe <- c(g[-1L] != g[-n], TRUE)
  fin_max <- stats::ave(f, g, FUN = cummax)
  avant <- c(-Inf, fin_max[-n])
  apres <- c(d[-1L], Inf)
  res[i] <- (!debut_groupe & avant >= d) | (!fin_groupe & apres <= f)
  res
}

# Refus induits (dictionnaire, § 1.10) : une table dont une clé étrangère vise une table
# refusée (portée table, directement ou par induction) est refusée à son tour ; `origine`
# porte les tables visées refusées, dans l'ordre du dictionnaire, jointes par « ; ».
.refus_induits <- function(ctx) {
  dico <- ctx$dico
  refusees <- unique(unlist(lapply(ctx$constats, function(k) {
    if (k$traitement == "R" && .portee_effective(dico, k$code, k$table, k$colonne) == "table") k$table
  })))
  col <- dico$colonnes
  liens <- col[nzchar(col$reference), c("table", "reference")]
  liens$cible <- sub("\\..*$", "", liens$reference)
  origines <- list()
  repeat {
    ajout <- FALSE
    for (i in seq_len(nrow(liens))) {
      t <- liens$table[i]
      u <- liens$cible[i]
      if (t %in% ctx$tables && u %in% refusees && !(u %in% origines[[t]])) {
        origines[[t]] <- c(origines[[t]], u)
        if (!(t %in% refusees)) refusees <- c(refusees, t)
        ajout <- TRUE
      }
    }
    if (!ajout) break
  }
  for (t in intersect(dico$tables$table, names(origines))) {
    o <- dico$tables$table[dico$tables$table %in% origines[[t]]]
    .ajouter_constat(ctx, "refus_induit", t, NA_character_, seq_len(nrow(ctx$base[[t]])),
                     .traitement_code_controle(dico, "refus_induit"), "exacte",
                     origine = paste(o, collapse = ";"))
  }
  invisible(NULL)
}

# Refus R de la règle B, retenus pour les règles P et V et la vue (.cause()) : une table
# refusée (portée table : clé, D01a, D04b R, refus induit...) n'est pas lue, une colonne
# refusée (portée colonne) non plus ; `tables` (par table) et `colonnes` (par table et
# colonne) portent les motifs de tous ses refus, sans doublon, parmi lesquels .cause() retient
# le plus petit dans l'ordre (rang, position) (spécification `donnees` v1.6, § 3.1, départage à
# rang égal, #59). `refus_valeur` : refus de portée colonne hors écart de forme, avec leurs
# lignes, par table et colonne (.refus_valeur_de() ; portée ligne pour la vue, M199).
.refus_regle_b <- function(ctx) {
  tables <- list()
  colonnes <- list()
  directs <- list()
  origines <- list()
  valeurs <- list()
  for (k in ctx$constats) {
    if (k$traitement != "R") next
    if (.portee_effective(ctx$dico, k$code, k$table, k$colonne) == "table") {
      tables[[k$table]] <- unique(c(tables[[k$table]], k$code))
      if (k$code %in% .CODES_INDUITS) origines[[k$table]] <- eclater_champ(k$origine)
      else directs[[k$table]] <- rbind(directs[[k$table]], data.frame(code = k$code, colonne = k$colonne,
                                                                       stringsAsFactors = FALSE))
    } else {
      c1 <- if (is.null(colonnes[[k$table]])) list() else colonnes[[k$table]]
      c1[[k$colonne]] <- unique(c(c1[[k$colonne]], k$code))
      colonnes[[k$table]] <- c1
      # refus de valeur, identifié par ligne (hors écart de forme, .refus_valeur_de() ; même
      # contenu que celui rangé pendant la règle B par .ajouter_constat())
      if (.refus_de_valeur(ctx$dico, k)) {
        v1 <- valeurs[[k$table]]
        v1[[k$colonne]] <- c(v1[[k$colonne]], list(list(code = k$code, lignes = k$lignes)))
        valeurs[[k$table]] <- v1
      }
    }
  }
  # valeurs inconnues de D03i (M701) : refus de valeur de code D03i, motif de la colonne pour
  # .cause() (M169), sans ligne de refus_tables
  inconnues <- .inconnues_d03i(ctx)
  valeurs <- .ranger_inconnues_d03i(valeurs, inconnues)
  for (x in inconnues) {
    c1 <- if (is.null(colonnes[[x$table]])) list() else colonnes[[x$table]]
    c1[[x$colonne]] <- unique(c("D03i", c1[[x$colonne]]))
    colonnes[[x$table]] <- c1
  }
  ctx$refus_valeur <- valeurs
  # `directs` : refus de portée table autres qu'un refus induit (code, colonne), dans l'ordre
  # des constats ; `racines` : tables refusées directement dont procède le refus induit d'une
  # table (lecture de l'enjeu, D7)
  racines <- list()
  racine <- function(t, vues = character(0)) {
    if (t %in% vues) return(character(0))
    unique(unlist(lapply(origines[[t]], function(u) if (!is.null(directs[[u]])) u else racine(u, c(vues, t)))))
  }
  for (t in names(origines)) racines[[t]] <- racine(t)
  ctx$refus_pv <- list(tables = tables, colonnes = colonnes, directs = directs, racines = racines)
  invisible(NULL)
}

# Motifs qui empêchent une composante de l'enjeu de lire `table.colonne` pour l'écart `ecart`
# (décisions du mainteneur, D7 et D10, lecture d'E2.5), aucun si elle se lit : une forme
# illisible, un refus de la colonne, un autre refus direct de portée table de la table. Le
# refus qui constitue l'écart (refus de portée table) ne bloque pas son propre enjeu (D10) :
# il n'empêche que la lecture de sa propre colonne, hors D01a (doublon de clé : chiffré, une
# composante n'étant sans valeur que pour un identifiant dont les lignes en double divergent
# sur une colonne qu'elle lit, .divergences_d01a()) ; un refus induit ne l'empêche pas quand
# il procède seulement du refus de l'écart (la table de l'écart ne porte aucun autre refus
# direct) : la cascade est chiffrée. Le refus de valeur d'une colonne de visibilité
# (.DATES_VISIBILITE, lue par les composantes pour la visibilité) n'empêche pas la lecture :
# à un arrêté antérieur à l'extraction, ses lignes sont de visibilité non déterminée et chaque
# porteur qu'elles touchent est sans valeur, cause visibilite_non_determinee (M201 ;
# spécification, § 4.2) ; à l'extraction, la vue est la base entière (règle 3) et la colonne
# n'est pas lue, comme par les règles V (décision du mainteneur du 9 novembre 2026, Q2, #33).
# `valeur` : la composante lit aussi la colonne comme valeur (.LUS_VALEUR_ENJEU) ; à
# l'extraction, où la ligne refusée est lue, le refus l'empêche alors (M169). Rend l'ensemble
# des causes que la colonne rend éligibles (character(0) si elle se lit) : sa forme
# illisible, chacun de ses refus de colonne, chaque refus direct de portée table de sa table,
# le refus induit de sa table ; ces règles d'éligibilité sont seules gardées, les préséances
# d'ordre (forme d'abord, colonne avant table, premier dans l'ordre des constats) sont
# remplacées par l'ordre (rang, position) entre les causes de toutes les colonnes lues
# (.cause_colonnes() ; spécification `donnees` v1.7, § 3.1, « Cause d'une composante de
# l'enjeu », #122).
.causes_enjeu <- function(ctx, table, colonne, ecart, valeur = FALSE) {
  forme <- .causes(ctx, table, colonne, forme_seule = TRUE)
  c1 <- ctx$refus_pv$colonnes[[table]]
  visibilite <- colonne %in% .DATES_VISIBILITE[[table]] && !is.null(.lignes_refusees(ctx, table, colonne)) &&
    !(valeur && .vue_totale(ctx))
  # un refus de portée ligne n'empêche pas la composante : seul le porteur qui lit une ligne
  # refusée est sans valeur (.refus_ligne_porteurs() ; spécification `donnees` v1.9, § 9.2, #72)
  propres <- if (!is.null(c1) && colonne %in% names(c1) && !visibilite) {
    setdiff(c1[[colonne]], .codes_refus_ligne(ctx, table, colonne))
  }
  propre <- !is.null(ecart) && identical(ecart$action, "refus") && !is.na(ecart$table) &&
    .portee_effective(ctx$dico, ecart$motif, ecart$table, ecart$colonne) == "table"
  d <- ctx$refus_pv$directs[[table]]
  if (!is.null(d) && propre && identical(table, ecart$table)) {
    # la clé étrangère refusée qui constitue l'écart (D04a, D04b, D10 (a) et (h)) se lit : le
    # lien n'est pas résolu, la composante se calcule sur ce qui est connu sans la parente
    # (réserve Q4) ; toute autre colonne de l'écart reste illisible
    lien <- ecart$motif %in% .MOTIFS_LIEN_ECART &&
      any(nzchar(ctx$dico$colonnes$reference[ctx$dico$colonnes$table == table & ctx$dico$colonnes$colonne %in% colonne]))
    if (ecart$motif != "D01a" && identical(colonne, ecart$colonne) && !lien) propres <- c(propres, ecart$motif)
    d <- d[!(d$code == ecart$motif & d$colonne %in% ecart$colonne), , drop = FALSE]
  }
  causes <- unique(as.character(c(forme, propres, if (!is.null(d)) d$code)))
  r <- ctx$refus_pv$racines[[table]]
  if (is.null(r)) return(causes)
  # cascade chiffrée si elle ne procède que du refus de l'écart : la racine est la table de
  # l'écart et n'y porte aucun autre refus direct (réserve Q-b)
  if (!propre || !identical(r, ecart$table)) return(unique(c(causes, "refus_induit")))
  dr <- ctx$refus_pv$directs[[r]]
  autre <- !is.null(dr) && any(!(dr$code == ecart$motif & dr$colonne %in% ecart$colonne))
  if (autre) unique(c(causes, "refus_induit")) else causes
}

# Refus de portée ligne de `table.colonne` (.portee_effective() ; spécification `donnees` v1.9,
# § 9.2, #72) : refus de valeur rangés dans `refus_valeur`, hors valeurs inconnues de D03i
# (traitées X, elles gardent la lecture de la colonne entière, M701). `.codes_refus_ligne()` :
# leurs motifs, sans doublon.
.refus_ligne_de <- function(ctx, table, colonne) {
  Filter(function(x) x$code != "D03i", .refus_valeur_de(ctx, table, colonne))
}
.codes_refus_ligne <- function(ctx, table, colonne) {
  unique(vapply(.refus_ligne_de(ctx, table, colonne), `[[`, "", "code"))
}

# Lignes refusées de portée ligne lues par une composante de l'enjeu (spécification `donnees`
# v1.9, § 9.2, #72) : pour chaque colonne de `lus` (« table.colonne »), une rangée (tc, code,
# ligne) par ligne refusée, sous la règle d'éligibilité de .causes_enjeu() (le refus de valeur
# d'une colonne de visibilité lue pour la visibilité seule n'est pas lu ; `valeur` : colonnes
# lues aussi comme valeur, lues à l'extraction).
.refus_ligne_lus <- function(ctx, lus, valeur = character(0)) {
  res <- list()
  for (tc in unique(lus)) {
    m <- strsplit(tc, ".", fixed = TRUE)[[1L]]
    r <- .refus_ligne_de(ctx, m[1L], m[2L])
    if (length(r) == 0L) next
    if (m[2L] %in% .DATES_VISIBILITE[[m[1L]]] && !(tc %in% valeur && .vue_totale(ctx))) next
    for (x in r) res[[length(res) + 1L]] <- data.frame(tc = rep(tc, length(x$lignes)), code = rep(x$code, length(x$lignes)),
                                                        ligne = x$lignes, stringsAsFactors = FALSE)
  }
  if (length(res)) do.call(rbind, res) else data.frame(tc = character(0), code = character(0), ligne = integer(0),
                                                       stringsAsFactors = FALSE)
}

# Cause de portée ligne de chaque porteur d'une composante de l'enjeu (spécification `donnees`
# v1.9, § 9.2, #72 ; « Cause d'une composante de l'enjeu », § 3.1) : un porteur est sans valeur
# s'il lit une ligne refusée de `rf` (.refus_ligne_lus()), rattachée à lui par
# `rattacher(table, lignes)` (data.frame (ligne, porteur) : paires de rattachement par clés
# connues, y compris un rattachement possible quand il dépend d'une valeur refusée, Kleene) ;
# sa cause est la plus petite des motifs qu'il lit, dans l'ordre (rang, position), publiée sur
# la première colonne qui la porte dans l'ordre du dictionnaire (.cause_colonnes()). Rend un
# data.frame (porteur, cause, table, colonne), un porteur par ligne, trié par porteur.
.refus_ligne_porteurs <- function(ctx, rf, rattacher) {
  vide <- data.frame(porteur = integer(0), cause = character(0), table = character(0), colonne = character(0),
                     stringsAsFactors = FALSE)
  if (nrow(rf) == 0L) return(vide)
  t <- sub("\\..*$", "", rf$tc)
  paires <- list()
  for (u in unique(t)) {
    x <- rf[t == u, , drop = FALSE]
    p <- rattacher(u, unique(x$ligne))
    if (nrow(p) == 0L) next
    j <- .paires(as.character(x$ligne), as.character(p$ligne))
    if (nrow(j) > 0L) paires[[length(paires) + 1L]] <- data.frame(porteur = p$porteur[j$j], tc = x$tc[j$i], code = x$code[j$i],
                                                                  stringsAsFactors = FALSE)
  }
  if (length(paires) == 0L) return(vide)
  pp <- do.call(rbind, paires)
  res <- lapply(split(pp, pp$porteur), function(z) {
    lus <- unique(z$tc)
    cz <- .cause_colonnes(ctx, lus, lapply(lus, function(tc) unique(z$code[z$tc == tc])))
    data.frame(porteur = z$porteur[1L], cause = cz[["cause"]], table = cz[["table"]], colonne = cz[["colonne"]],
               stringsAsFactors = FALSE)
  })
  res <- do.call(rbind, res)
  res <- res[order(res$porteur, method = "radix"), , drop = FALSE]
  rownames(res) <- NULL
  res
}

# --- Règle P et vue à une date ---------------------------------------------------------

# Dates qui gouvernent la visibilité propre d'une ligne (dictionnaire, § 6) : la ligne est
# visible à l'arrêté A si chacune vaut au plus A. adherents et assures sont visibles s'ils
# sont référencés par une ligne visible ; parametres suit sa garantie souscrite (règle 1).
.DATES_VISIBILITE <- list(
  contrats = "date_effet", garanties_souscrites = "date_effet", affiliations = "date_saisie",
  famille = "date_saisie", sinistres = "date_saisie", dossiers = "date_ouverture",
  beneficiaires = "date_saisie", rentes = "date_saisie", evenements = "date_saisie",
  prestations = c("date_saisie", "date_reglement"), cotisations = "date_mouvement",
  catastrophes = "date_saisie", victimes = "date_saisie", evaluations_gestion = "date_saisie",
  designations = "date_saisie", ayants_droit_sante = "date_saisie")

# Parties de ligne connues à une date (dictionnaire, § 6) : colonnes de la partie, et date
# qui la rend connue (`NA` : la colonne de la partie date elle-même sa connaissance, V).
.PARTIES_LIGNE <- list(
  list(table = "contrats", colonnes = c("date_fin", "motif_fin", "date_saisie_fin"), date = "date_saisie_fin"),
  list(table = "affiliations", colonnes = c("date_fin", "motif_fin", "date_saisie_fin"), date = "date_saisie_fin"),
  list(table = "sinistres", colonnes = "date_instruction", date = "date_instruction"))

# Parties de ligne (.PARTIES_LIGNE) : liste de list(table, colonnes), une par partie. Une
# colonne d'une partie vaut pour toute la partie (spécification de B2, § 6.2, erratum
# v1.0.5). Sans point : lue par les familles de calcul, qui la passent à
# garanties::postes_a_arreter() (aucune arête garanties -> donnees) ; non exportée.
parties_ligne <- function() lapply(.PARTIES_LIGNE, function(p) list(table = p$table, colonnes = p$colonnes))

# Liens de la règle 1 du § 6 (une ligne fille n'est visible que si sa parente l'est) : clés
# étrangères simples de colonnes.csv, hors adherents et assures (visibles par référence).
.liens_visibilite <- function(dico) {
  col <- dico$colonnes
  l <- col[nzchar(col$reference) & !grepl(";", col$reference, fixed = TRUE), c("table", "colonne", "reference")]
  l$table_cible <- sub("\\..*$", "", l$reference)
  l$colonne_cible <- sub("^.*\\.", "", l$reference)
  l <- l[!(l$table_cible %in% c("adherents", "assures")), , drop = FALSE]
  rownames(l) <- NULL
  l
}

# Liens qui masquent une ligne fille par la règle 1 : ceux de .liens_visibilite(), hors
# l'exception du dictionnaire 1.6 (§ 6, règle 1 ; spécification `donnees` v1.9, § 9.3 (1) ; M509,
# #83) : une ligne de dossiers dont la visibilité propre tient à A (date_ouverture, sinistre
# visible) n'est pas masquée par sa garantie souscrite, visible ou non ; D10b y est évalué
# (.regle_v_garanties()) et les familles ne lisent pas la garantie invisible
# (dossiers_garantie_invisible()). Lus par l'évaluation de la visibilité (.visibilite_a()), les
# colonnes lues pour la vue (.construire_vue(), `lit_vue`), la cause (γ) (.cause_nd()),
# parente_posterieure et la visibilité des parentes de l'hypothèse de D03g (.appliquer_h_d03g(),
# M702 lu selon M705 ; spécification `donnees` v1.9, § 9.6, P18 (a), note v1.9.2) ; seule la
# cascade des exclusions (.exclu_vue()) garde tous les liens.
.liens_regle1 <- function(dico) {
  l <- .liens_visibilite(dico)
  l <- l[!(l$table == "dossiers" & l$colonne == "id_garantie_souscrite"), , drop = FALSE]
  rownames(l) <- NULL
  l
}

# Statut de la parente d'un lien `lien` (ligne de .liens_regle1()) pour chaque ligne de la table
# fille, en logique de Kleene : vrai sans parente (orpheline, clé manquante ou vide) ou si une
# ligne de même clé est visible (`statut` : statuts par table), inconnu si aucune ne l'est et
# qu'une l'est de façon non déterminée, faux sinon ; clé du lien illisible par sa forme : inconnu.
# Seule implémentation, lue par la règle 1 (.visibilite_a()) et par parente_posterieure.
.parente_regle1 <- function(ctx, lien, statut) {
  t <- lien$table
  u <- lien$table_cible
  lisible <- function(t1, c1) is.na(.cause(ctx, t1, c1, forme_seule = TRUE))
  if (!lisible(t, lien$colonne) || !lisible(u, lien$colonne_cible)) return(rep(NA, length(statut[[t]])))
  cle <- .cle_manquante(as.character(.valeurs(ctx, t, lien$colonne)))
  cible <- .cle_manquante(as.character(.valeurs(ctx, u, lien$colonne_cible)))
  vu <- statut[[u]]
  ifelse(is.na(apparier_cles(cle, cible)) | !is.na(apparier_cles(cle, cible[vu %in% TRUE])), TRUE,
         ifelse(!is.na(apparier_cles(cle, cible[is.na(vu)])), NA, FALSE))
}

.vue_totale <- function(ctx) as.numeric(ctx$arrete) == as.numeric(ctx$date_extraction)

# Règle P et visibilité propre, jusqu'au point fixe des refus qu'elle induit (décision du
# mainteneur, D12 ; M178, restreinte au défaut de forme par M199) : à un arrêté antérieur à
# l'extraction, une règle P empêchée sur une table lue par la vue (colonne lue illisible par
# sa forme, ou table refusée : .regle() ; un refus de valeur ne l'empêche pas, elle s'exécute
# alors sur les lignes lisibles) rend la visibilité de toutes ses lignes inconnue ; la table
# reçoit un refus induit de portée table (`refus_induit`,
# origine : la colonne « table.colonne » qui empêche la règle), propagé à ses filles par
# les clés étrangères comme les refus induits de la règle B (origine : la table visée).
# Les règles P sont alors rejouées sur la base des refus complétés (les constats et
# contrôles non exécutés du passage précédent sont retirés, hors les règles P empêchées,
# qui gardent leur cause) ; la vue reste provisoire (`p_refusees` : tables refusées par une
# règle P empêchée). Une colonne de visibilité de la ligne (.DATES_VISIBILITE) illisible par sa
# forme empêche de même la vue de sa table, qu'une règle P la
# lise ou non : même refus induit, d'origine « table.colonne » ; la table sort de la vue et
# aucune de ses lignes n'est inscrite dans vue$visibilite_non_determinee (spécification v1.5.2,
# § 2.2, Frontière ; .vue_empechee()).
.regle_p <- function(ctx) {
  constats <- ctx$constats
  non_executes <- ctx$non_executes
  ctx$p_refusees <- character(0)
  repeat {
    .initialiser_visibilite(ctx)
    .regle_prealable(ctx)
    .vue_empechee(ctx)
    if (length(ctx$p_empechees) == 0L) break
    empechees <- ctx$p_empechees
    ctx$constats <- constats
    # la règle P empêchée garde sa cause d'origine dans controles_non_executes (en concurrence
    # avec les autres émissions de même clé, .dedoublonner_non_executes())
    ctx$non_executes <- c(non_executes, ctx$p_entrees)
    non_executes <- ctx$non_executes
    .refus_p_empechee(ctx, empechees)
    constats <- ctx$constats
    .refus_regle_b(ctx)
  }
  invisible(NULL)
}

# Vue d'une table empêchée par un défaut de forme d'une de ses colonnes de visibilité, à un
# arrêté antérieur à l'extraction (spécification v1.5.2, § 2.2, Frontière ; M178) : la colonne
# « table.colonne » s'ajoute aux colonnes en cause de la table (`ctx$p_empechees`, lu par
# .regle_p() et .refus_p_empechee()) ; une table déjà refusée en portée table n'est pas lue par
# la vue. Une colonne lue par une règle P y figure déjà (.regle_prealable()) : sans double compte.
.vue_empechee <- function(ctx) {
  if (.vue_totale(ctx)) return(invisible(NULL))
  dates <- .DATES_VISIBILITE
  for (t in intersect(names(dates), ctx$tables)) {
    if (!is.null(ctx$refus_pv$tables[[t]])) next
    for (c1 in dates[[t]]) {
      if (!is.na(.cause(ctx, t, c1, forme_seule = TRUE))) {
        ctx$p_empechees[[t]] <- unique(c(ctx$p_empechees[[t]], paste(t, c1, sep = ".")))
      }
    }
  }
  invisible(NULL)
}

# Refus d'une règle P empêchée (D12, .regle_p()) : `empechees`, liste nommée par table des
# colonnes « table.colonne » en cause ; chaque table d'origine reçoit `vue_empechee`
# (dictionnaire 1.6, P12, M182 ; spécification `donnees` v1.9, § 9.1), d'origine ses colonnes
# puis les tables d'origine qu'elle vise (un seul refus de portée table par table) ; les tables
# qui visent une table ainsi refusée par une clé étrangère, hors tables déjà refusées en portée
# table, reçoivent `refus_induit`, d'origine la table visée (propagation).
.refus_p_empechee <- function(ctx, empechees) {
  dico <- ctx$dico
  col <- dico$colonnes
  liens <- col[nzchar(col$reference), c("table", "reference")]
  liens$cible <- sub("\\..*$", "", liens$reference)
  deja <- names(ctx$refus_pv$tables)
  origines <- empechees
  refusees <- names(empechees)
  repeat {
    ajout <- FALSE
    for (i in seq_len(nrow(liens))) {
      t <- liens$table[i]
      u <- liens$cible[i]
      if (t %in% ctx$tables && !(t %in% deja) && u %in% refusees && !(u %in% origines[[t]])) {
        origines[[t]] <- c(origines[[t]], u)
        if (!(t %in% refusees)) refusees <- c(refusees, t)
        ajout <- TRUE
      }
    }
    if (!ajout) break
  }
  for (t in intersect(dico$tables$table, names(origines))) {
    o <- origines[[t]]
    o <- c(sort(o[grepl(".", o, fixed = TRUE)], method = "radix"), dico$tables$table[dico$tables$table %in% o])
    code <- if (t %in% names(empechees)) "vue_empechee" else "refus_induit"
    .ajouter_constat(ctx, code, t, NA_character_, seq_len(nrow(ctx$base[[t]])),
                     .traitement_code_controle(dico, code), "exacte", origine = paste(o, collapse = ";"))
  }
  ctx$p_refusees <- unique(c(ctx$p_refusees, names(empechees)))
  invisible(NULL)
}

# Initialise l'état de la visibilité à l'arrêté : colonnes lues pour établir la visibilité
# propre de chaque ligne (`lit_propre` : les dates de .DATES_VISIBILITE, vide à l'arrêté égal
# à l'extraction, où tout est visible : règle 3 du § 6), lignes et parties de ligne non
# déterminées, dates d'hypothèse et exclusions de D02b et D03g, remplies par la règle P. La
# visibilité elle-même n'est évaluée qu'une fois, à trois valeurs, par .visibilite_a().
# Appelée avant la règle P.
.initialiser_visibilite <- function(ctx) {
  totale <- .vue_totale(ctx)
  ctx$lit_propre <- list()
  ctx$non_determine <- list()
  ctx$partie_nd <- list()
  ctx$date_h <- list()
  ctx$exclu_g <- list()
  for (table in setdiff(ctx$tables, "extraction")) {
    n <- nrow(ctx$base[[table]])
    dates <- .DATES_VISIBILITE[[table]]
    if (!totale) ctx$lit_propre[[table]] <- if (length(dates)) paste(table, dates, sep = ".") else character(0)
    ctx$non_determine[[table]] <- rep(FALSE, n)
    ctx$partie_nd[[table]] <- rep(FALSE, n)
    ctx$date_h[[table]] <- rep(NA_real_, n)
    ctx$exclu_g[[table]] <- rep(FALSE, n)
  }
  ctx$date_g <- list()
  ctx$partie_h <- list()
  ctx$reste_g <- list()
  ctx$parente_g <- list()
  invisible(NULL)
}

# Première date d'une ligne parente pour chaque clé de `cle` (la plus ancienne si la clé
# n'est pas unique : versions de famille), NA si la parente n'existe pas (clé manquante ou "" :
# aucune, .cle_manquante(), #123).
.date_parente <- function(cle, cle_parente, date_parente) {
  o <- order(as.numeric(date_parente), na.last = TRUE, method = "radix")
  as.numeric(date_parente)[o][apparier_cles(cle, cle_parente[o])]
}

# Logique à trois valeurs de la règle P (logique de Kleene ; spécification, § 2.2, (b) et
# (c) ; principe de M187 ; avis d'`actuary`, #33) : une valeur refusée pour sa valeur
# (.lignes_refusees()) est inconnue, sa présence comprise. Le verdict d'une règle P sur une
# ligne vaut TRUE, FALSE ou NA (inconnu) ; seule une ligne au verdict inconnu est écartée de
# la détection (.regle(), `partiel`). `.inconnu()` : lignes de `table` dont la valeur de
# `colonne` est inconnue ; `.date_connue()` : la date en nombre, NA si absente ou inconnue.
# La règle B à trois valeurs lit les mêmes accesseurs (.inconnu(), .programmable3() ;
# .entree3()), sur les refus de valeur des strates déjà évaluées (.refus_valeur_de()).
.inconnu <- function(ctx, table, colonne) seq_len(NROW(ctx$base[[table]])) %in% .lignes_refusees(ctx, table, colonne)
.date_connue <- function(ctx, table, colonne) {
  # colonne illisible par sa forme : la table est refusée en portée table et n'est pas lue
  # (défensif : .refus_vue() évalue le verdict avant de filtrer par table)
  if (!is.na(.cause(ctx, table, colonne, forme_seule = TRUE))) return(rep(NA_real_, nrow(ctx$base[[table]])))
  x <- as.numeric(.valeurs(ctx, table, colonne))
  x[.inconnu(ctx, table, colonne)] <- NA_real_
  x
}
# x < y (D02b) : FALSE si l'une des dates est connue absente ; NA si l'une est inconnue et
# l'autre présente ou inconnue (`ix`, `iy` : inconnues).
.avant3 <- function(x, ix, y, iy) {
  r <- !is.na(x) & !is.na(y) & x < y
  r[ix | iy] <- NA
  r[(ix & !iy & is.na(y)) | (iy & !ix & is.na(x))] <- FALSE
  r
}
# Valeur manquante (D03g) : NA si la valeur est inconnue.
.manque3 <- function(ctx, table, colonne) {
  r <- is.na(.valeurs(ctx, table, colonne))
  r[.inconnu(ctx, table, colonne)] <- NA
  r
}
# Type d'événement programmable (.programmable()) : NA si le type est inconnu, ou si sa
# programmation dépend du motif (`oui:<motifs>`) et que le motif est inconnu.
.programmable3 <- function(ctx) {
  te <- ctx$dico$types_evenements
  prog <- te$programmable[match(.valeurs(ctx, "evenements", "type_evenement"), te$type_evenement)]
  r <- .programmable(ctx)
  r[!is.na(prog) & startsWith(prog, "oui:") & .inconnu(ctx, "evenements", "motif")] <- NA
  r[.inconnu(ctx, "evenements", "type_evenement")] <- NA
  r
}
# Verdict de D02b sur evenements : type non programmable et saisie antérieure à la date
# d'effet (.regle_prealable(), .refus_vue()).
.d02b_evenements3 <- function(ctx) {
  !.programmable3(ctx) & .avant3(.date_connue(ctx, "evenements", "date_saisie"), .inconnu(ctx, "evenements", "date_saisie"),
                                 .date_connue(ctx, "evenements", "date_effet"), .inconnu(ctx, "evenements", "date_effet"))
}
# Verdict de D02b sur une fille saisie avant sa parente : date de la fille `x` (inconnue :
# `ix`) face à la date de sa parente (.date_parente()), inconnue si la ligne parente de même
# clé a une date inconnue (`inconnue_parente`). Seule famille a des clés de parente non
# uniques (versions), et sa date de saisie, colonne de clé, n'est jamais refusée pour sa
# valeur.
.avant_parente3 <- function(x, ix, cle, cle_parente, date_parente, inconnue_parente) {
  cle <- .cle_manquante(cle)
  .avant3(x, ix, .date_parente(cle, cle_parente, date_parente), !is.na(apparier_cles(cle, cle_parente[inconnue_parente])))
}
# Hypothèse de D02b déclarée pour chaque référentiel (la vue est commune aux deux).
.h_d02b <- function(ctx) {
  hyp <- ctx$declarations$hypotheses
  all(REFERENTIELS %in% hyp$referentiel[hyp$motif == "D02b"])
}

# Règle P (spécification, § 2.2) : D02b et D03g, détectés sur la base entière après la
# règle B. À l'arrêté égal à l'extraction, ils sont des signalements (S, règle I) ; à un
# arrêté antérieur, D02b attend son hypothèse (H) et D03g son hypothèse ou son exclusion
# (H ou X). Leurs lignes non résolues sont alors tenues hors de la vue et recensées dans
# vue$visibilite_non_determinee (colonne NA), sauf si elles sont invisibles de façon
# déterminée (M156, M216 ; .visibilite_a(), .construire_vue()) ; quand seule une partie
# de ligne est en cause (fin d'un contrat ou d'une affiliation : date_saisie_fin manquante,
# ou fin d'un contrat saisie avant son effet), la ligne reste dans la vue, la partie est
# masquée (.valeurs_vue()) et recensée sous sa colonne si elle est de visibilité non
# déterminée (décision du mainteneur, D1). Une
# règle P non exécutée à un arrêté antérieur sur une table lue par la vue (non refusée en
# portée table) rend la vue provisoire (`p_non_executee`) ; un refus de valeur sur une
# colonne lue ne l'empêche pas : elle s'exécute sur les autres lignes (M200, `regle_p`), les
# lignes refusées étant de visibilité non déterminée (.refus_vue()). Une hypothèse de D02b déclarée
# pour chaque référentiel est appliquée : la ligne entre dans la vue à sa date de visibilité
# (max de la saisie, de la date d'effet et de la visibilité de la parente). Le délai et
# l'exclusion de D03g sont appliqués quand ils sont complets (.application_d03g() ; D5) :
# l'exclusion sort la ligne entière de la vue (une partie de ligne n'admet que l'hypothèse,
# D9), l'hypothèse lui donne une date de saisie (.appliquer_h_d03g()) ; sinon la ligne
# reste de visibilité non déterminée.
.regle_prealable <- function(ctx) {
  totale <- .vue_totale(ctx)
  t_b <- if (totale) "S" else "H"
  t_g <- if (totale) "S" else "H;X"
  v <- function(table, colonne) .valeurs(ctx, table, colonne)
  # hypothèse de D02b déclarée pour chaque référentiel (la vue est commune aux deux) : date de
  # visibilité = max(date de saisie, date d'effet, visibilité de la parente), dictionnaire, § 9
  h_d02b <- .h_d02b(ctx)
  # `partie` : colonne de la partie de ligne indéterminée, NA pour la ligne entière ; `date_h` :
  # date d'effet que l'hypothèse de D02b ajoute à la visibilité propre (NULL : la règle 1 du
  # § 6 suffit, pour une fille ou pour la fin d'un contrat, visible avec son contrat)
  marquer <- function(table, motif, lignes, partie = NA_character_, date_h = NULL) {
    force(lignes)   # exécute la règle à tout arrêté
    if (totale) return(invisible(NULL))
    if (is.null(lignes)) {
      # une règle P empêchée ne rend la vue provisoire que sur une table lue par la vue
      # (une table refusée en portée table n'est pas lue : .refus_regle_b()) ; elle y induit
      # un refus de portée table (D12, .regle_p())
      if (is.null(ctx$refus_pv$tables[[table]])) {
        ctx$p_non_executee <- TRUE
        ne <- ctx$non_executes[[length(ctx$non_executes)]]
        ctx$p_empechees[[table]] <- unique(c(ctx$p_empechees[[table]], ne$lu))
        ctx$p_entrees[[length(ctx$p_entrees) + 1L]] <- ne
      }
      return(invisible(NULL))
    }
    if (length(lignes) == 0L) return(invisible(NULL))
    if (motif == "D02b" && h_d02b) {
      if (!is.null(date_h)) {
        d <- as.numeric(v(table, date_h))[lignes]
        dh <- ctx$date_h[[table]]
        dh[lignes] <- pmax(dh[lignes], d, na.rm = TRUE)
        ctx$date_h[[table]] <- dh
        ctx$lit_propre[[table]] <- unique(c(ctx$lit_propre[[table]], paste(table, date_h, sep = ".")))
      }
      return(invisible(NULL))
    }
    if (motif == "D03g") {
      application <- .application_d03g(ctx, table, partie)
      if (identical(application, "X")) {
        # exclusion déclarée pour les quatre familles : la ligne entière sort de la vue (une
        # partie de ligne n'est résolue que par l'hypothèse, D9)
        ctx$exclu_g[[table]][lignes] <- TRUE
        return(invisible(NULL))
      }
      if (identical(application, "H")) {
        ctx$h_g[[length(ctx$h_g) + 1L]] <- list(table = table, partie = partie, lignes = lignes)
        return(invisible(NULL))
      }
    }
    nd(table, partie, motif, lignes, date_h = date_h)
  }
  # lignes (ou parties) non résolues par la règle P, candidates à l'inscription : `ctx$nd_p`,
  # lu par l'évaluation unique de la visibilité (.visibilite_a()), qui n'en inscrit que les
  # lignes de statut non déterminé (.construire_vue()) ; `origine` : « table.colonne » de la
  # valeur refusée pour un motif de refus (M202), NA sinon ; `date_h` : date que compare D02b
  # sur la ligne (NULL pour une fille ou une partie de ligne)
  nd <- function(table, partie, motif, lignes, origine = NA_character_, date_h = NULL) {
    if (is.na(partie)) ctx$non_determine[[table]][lignes] <- TRUE
    ctx$nd_p[[length(ctx$nd_p) + 1L]] <- list(table = table, colonne = partie, motif = motif, lignes = lignes,
                                              origine = origine, date_h = date_h)
    invisible(NULL)
  }
  # règle P exécutée sur les lignes dont aucune valeur lue n'est refusée (M200, .regle())
  regle_p <- function(...) .regle(..., partiel = TRUE)
  ctx$nd_p <- list()
  ctx$p_non_executee <- FALSE
  ctx$p_empechees <- list()
  ctx$p_entrees <- list()
  ctx$h_g <- list()
  # verdicts à trois valeurs (.avant3()) : une valeur refusée est inconnue
  avant <- function(t1, c1, t2, c2) .avant3(.date_connue(ctx, t1, c1), .inconnu(ctx, t1, c1),
                                             .date_connue(ctx, t2, c2), .inconnu(ctx, t2, c2))

  # D02b : saisie antérieure au fait que la ligne enregistre
  marquer("evenements", "D02b", regle_p(ctx, "D02b", "evenements", "date_saisie",
    c("evenements.date_effet", "evenements.type_evenement", "evenements.motif"), t_b, "exacte",
    function() .d02b_evenements3(ctx)),
    date_h = "date_effet")
  marquer("sinistres", "D02b", regle_p(ctx, "D02b", "sinistres", "date_saisie", "sinistres.date_declaration",
    t_b, "exacte", function() avant("sinistres", "date_saisie", "sinistres", "date_declaration")),
    date_h = "date_declaration")
  marquer("catastrophes", "D02b", regle_p(ctx, "D02b", "catastrophes", "date_saisie", "catastrophes.date_evenement",
    t_b, "exacte", function() avant("catastrophes", "date_saisie", "catastrophes", "date_evenement")),
    date_h = "date_evenement")
  # fin d'un contrat saisie avant que le contrat soit visible (partie de ligne saisie avant
  # sa ligne)
  marquer("contrats", "D02b", regle_p(ctx, "D02b", "contrats", "date_saisie_fin", "contrats.date_effet",
    t_b, "exacte", function() avant("contrats", "date_saisie_fin", "contrats", "date_effet")), "date_saisie_fin")
  # D02b : ligne fille saisie avant sa parente (règle 1 du § 6)
  filles <- list(
    list("famille", "date_saisie", "id_sinistre", "sinistres", "id_sinistre", "date_saisie"),
    list("dossiers", "date_ouverture", "id_sinistre", "sinistres", "id_sinistre", "date_saisie"),
    list("beneficiaires", "date_saisie", "id_dossier", "dossiers", "id_dossier", "date_ouverture"),
    list("beneficiaires", "date_saisie", "id_membre", "famille", "id_membre", "date_saisie"),
    list("rentes", "date_saisie", "id_dossier", "dossiers", "id_dossier", "date_ouverture"),
    list("rentes", "date_saisie", "id_membre", "famille", "id_membre", "date_saisie"),
    list("evenements", "date_saisie", "id_sinistre", "sinistres", "id_sinistre", "date_saisie"),
    list("evenements", "date_saisie", "id_dossier", "dossiers", "id_dossier", "date_ouverture"),
    list("evenements", "date_saisie", "id_rente", "rentes", "id_rente", "date_saisie"),
    # prestation saisie ou réglée avant l'ouverture de son dossier ou la saisie de sa rente
    # (dictionnaire 1.6, § 9, D02b ; spécification `donnees` v1.9, § 9.3 (3), #83)
    list("prestations", "date_saisie", "id_dossier", "dossiers", "id_dossier", "date_ouverture"),
    list("prestations", "date_reglement", "id_dossier", "dossiers", "id_dossier", "date_ouverture"),
    list("prestations", "date_saisie", "id_rente", "rentes", "id_rente", "date_saisie"),
    list("prestations", "date_reglement", "id_rente", "rentes", "id_rente", "date_saisie"),
    list("victimes", "date_saisie", "id_catastrophe", "catastrophes", "id_catastrophe", "date_saisie"),
    list("victimes", "date_saisie", "id_sinistre", "sinistres", "id_sinistre", "date_saisie"))
  for (f in filles) {
    if (!(f[[4L]] %in% ctx$tables)) next
    marquer(f[[1L]], "D02b", regle_p(ctx, "D02b", f[[1L]], f[[2L]],
      c(paste(f[[1L]], f[[3L]], sep = "."), paste(f[[4L]], c(f[[5L]], f[[6L]]), sep = ".")), t_b, "exacte",
      function() .avant_parente3(.date_connue(ctx, f[[1L]], f[[2L]]), .inconnu(ctx, f[[1L]], f[[2L]]), v(f[[1L]], f[[3L]]),
                                 v(f[[4L]], f[[5L]]), .date_connue(ctx, f[[4L]], f[[6L]]), .inconnu(ctx, f[[4L]], f[[6L]])),
      parente = c(f[[3L]], f[[4L]], f[[5L]])))
  }
  # D03g : date de saisie manquante, ou date qui vaut date de saisie (dossiers.date_ouverture ;
  # dossiers, catastrophes et victimes depuis le dictionnaire 1.6, P18 (a)) ; fin d'un contrat
  # ou d'une affiliation : sous sa condition
  for (table in names(.COLONNES_D03G)) {
    colonne <- .COLONNES_D03G[[table]]
    marquer(table, "D03g", regle_p(ctx, "D03g", table, colonne, character(0), t_g, "exacte",
                                  function() .manque3(ctx, table, colonne)))
  }
  # partie de ligne : l'hypothèse seule la résout (D9) ; traitement H à un arrêté antérieur
  for (table in c("contrats", "affiliations")) {
    marquer(table, "D03g", regle_p(ctx, "D03g", table, "date_saisie_fin", paste0(table, ".date_fin"), t_b, "exacte",
      function() .manque3(ctx, table, "date_saisie_fin") & !.manque3(ctx, table, "date_fin")), "date_saisie_fin")
  }
  # D03i : date d'effet de visibilité manquante (dictionnaire 1.6, P18 (b) ; spécification
  # `donnees` v1.9, § 9.6 ; S-3 (a), M686), détection exacte sur la base entière, traitement X
  # par famille à tout arrêté (.placer()). À un arrêté antérieur à l'extraction, la date de
  # visibilité de la ligne est inconnue : la ligne, de visibilité non déterminée (règle 3 du § 6),
  # est recensée dans vue$visibilite_non_determinee sous le motif D03i, d'origine
  # « table.colonne » (.construire_vue() n'inscrit que les lignes de statut non déterminé) ; la
  # cause (γ) d'une ligne de règle V qu'elle fait écarter est D03i (.cause_nd(), rang 3). À
  # l'arrêté égal à l'extraction, la ligne est visible, sa date inconnue des postes.
  # La détection lit le manquant comme manquant (M701) : seuls les autres refus de valeur de la
  # colonne rendent le verdict inconnu ; la ligne non déterminée sous D03i est inscrite par le
  # mécanisme du refus de valeur (.inconnues_d03i(), .refus_vue()).
  manque_d03i <- function(table, colonne) {
    r <- is.na(.valeurs(ctx, table, colonne))
    autres <- Filter(function(x) x$code != "D03i", .refus_valeur_de(ctx, table, colonne))
    r[unlist(lapply(autres, `[[`, "lignes"))] <- NA
    r
  }
  for (table in names(.COLONNES_D03I)) {
    colonne <- .COLONNES_D03I[[table]]
    regle_p(ctx, "D03i", table, colonne, character(0), "X", "exacte", function() manque_d03i(table, colonne))
  }
  .appliquer_h_d03g(ctx, nd)
  invisible(NULL)
}

# Hypothèse déclarée de D03g appliquée à la vue (décision du mainteneur, D5 ; jugement
# d'expert) : la date de saisie manquante (.COLONNES_D03G) est remplacée par max(date d'effet +
# délai, visibilité de la parente), la date d'effet étant celle que compare D02b
# (.EFFET_D03G : evenements, date_effet ; sinistres, date_declaration ; catastrophes,
# date_evenement, P18 (a) ; table fille : visibilité de la parente, d'où visibilité de la
# parente + délai ; dossiers et victimes : visibilité du sinistre, ou de la catastrophe, + délai,
# bornée par la visibilité des parentes, .PARENTE_EFFET_D03G, M702) ; délai de seuils$d03g_delai_jours pour la table. Fin
# d'un contrat ou d'une affiliation (partie de ligne) : connue à date_fin + délai (erratum
# de D5, D9). Visibilité d'une parente : max des dates de .DATES_VISIBILITE de la
# ligne et de ses ascendantes (règle 1, liens de .liens_regle1() : la garantie souscrite d'un
# dossier n'en fait pas partie, M705 ; spécification `donnees` v1.9, § 9.6, P18 (a), note
# v1.9.2), NA si l'une est inconnue ; versions de famille : la
# plus ancienne. Une date qui ne se calcule pas laisse la ligne de visibilité non
# déterminée (`nd`, motif D03g ; `ctx$reste_g` : ces lignes, par table, hors de l'hypothèse
# placée et attendues en exclusion, réserve Q5), sauf si seule sa parente est non
# déterminée (motif parente_non_determinee, sans exigence propre, réserve Q2 (b)). Rend
# `ctx$date_g` (date de saisie retenue, par table) et `ctx$partie_h` (date de connaissance
# de la fin retenue).
# Parente dont la visibilité tient lieu de date d'effet de l'hypothèse (M702 ; spécification
# `donnees` v1.9, § 9.6, P18 (a), « dossier : son sinistre ; victime : sa catastrophe ») : la
# date de saisie retenue est
# max(visibilité de cette parente + délai, visibilité des parentes selon la règle 1), au lieu de
# max(visibilité des parentes) + délai pour les autres filles. Pour un dossier, le sinistre est
# la seule parente de la règle 1 (M705) : date retenue = visibilité du sinistre + délai.
.PARENTE_EFFET_D03G <- list(dossiers = "sinistres", victimes = "catastrophes")
.appliquer_h_d03g <- function(ctx, nd) {
  if (length(ctx$h_g) == 0L) return(invisible(NULL))
  # liens de la règle 1 (M705) : la garantie souscrite d'un dossier n'est pas une parente
  liens <- .liens_regle1(ctx$dico)
  liens <- liens[liens$table %in% ctx$tables & liens$table_cible %in% ctx$tables, , drop = FALSE]
  lisible <- function(t, c1) is.na(.cause(ctx, t, c1, forme_seule = TRUE))
  # une valeur refusée n'est pas lue (M199) : inconnue
  lire <- function(t, c1) .date_connue(ctx, t, c1)
  delai <- ctx$declarations$seuils[[SEUIL_DELAI_D03G]]
  tables <- setdiff(ctx$tables, "extraction")
  # date de saisie retenue (NA hors hypothèse) ; dates propres de visibilité de chaque ligne
  for (t in tables) ctx$date_g[[t]] <- rep(NA_real_, nrow(ctx$base[[t]]))
  propre_date <- function(t) {
    x <- rep(-Inf, nrow(ctx$base[[t]]))
    for (c1 in .DATES_VISIBILITE[[t]]) {
      d <- lire(t, c1)
      if (isTRUE(.COLONNES_D03G[t] == c1)) d <- ifelse(is.na(ctx$date_g[[t]]), d, ctx$date_g[[t]])
      x <- pmax(x, d)
    }
    dh <- ctx$date_h[[t]]
    if (!is.null(dh)) x <- pmax(x, ifelse(is.na(dh), -Inf, dh))
    x
  }
  # visibilité de la parente de chaque ligne (max sur les liens, ou sur les liens vers les tables
  # `cibles` ; -Inf sans parente)
  date_parente <- function(vd, t, cibles = NULL) {
    x <- rep(-Inf, nrow(ctx$base[[t]]))
    for (i in which(liens$table == t & (is.null(cibles) | liens$table_cible %in% cibles))) {
      u <- liens$table_cible[i]
      if (!lisible(t, liens$colonne[i]) || !lisible(u, liens$colonne_cible[i])) return(rep(NA_real_, length(x)))
      cle <- .cle_manquante(.valeurs(ctx, t, liens$colonne[i]))
      p <- .date_parente(cle, .valeurs(ctx, u, liens$colonne_cible[i]), vd[[u]])
      orpheline <- is.na(apparier_cles(cle, .valeurs(ctx, u, liens$colonne_cible[i])))
      x <- pmax(x, ifelse(orpheline, -Inf, p))
    }
    x
  }
  effet <- .EFFET_D03G
  for (iteration in seq_len(length(tables) + 1L)) {
    vd <- lapply(stats::setNames(tables, tables), propre_date)
    repeat {
      avant <- vd
      for (t in tables) vd[[t]] <- pmax(propre_date(t), date_parente(vd, t))
      if (identical(avant, vd)) break
    }
    change <- FALSE
    for (h in ctx$h_g) {
      if (!is.na(h$partie)) next
      t <- h$table
      parente <- date_parente(vd, t)[h$lignes]
      g <- if (!is.null(effet[[t]])) pmax(lire(t, effet[[t]])[h$lignes] + delai[[t]], parente)
           else if (!is.null(.PARENTE_EFFET_D03G[[t]])) pmax(date_parente(vd, t, .PARENTE_EFFET_D03G[[t]])[h$lignes] + delai[[t]],
                                                            parente)
           else parente + delai[[t]]
      g[!is.finite(g)] <- NA_real_
      ancien <- ctx$date_g[[t]][h$lignes]
      if (!identical(ancien, g)) { ctx$date_g[[t]][h$lignes] <- g; change <- TRUE }
    }
    if (!change) break
  }
  ctx$partie_h <- list()
  for (h in ctx$h_g) {
    t <- h$table
    if (is.na(h$partie)) {
      g <- ctx$date_g[[t]][h$lignes]
      # ligne dont la date ne se calcule qu'à cause de sa parente, de visibilité non
      # déterminée (date propre lisible, parente existante) : aucune exigence propre, elle
      # suit sa parente (parente_non_determinee, réserve Q2 (b))
      propre_manque <- if (!is.null(effet[[t]])) is.na(lire(t, effet[[t]])[h$lignes]) else rep(FALSE, length(g))
      par_parente <- is.na(g) & is.na(date_parente(vd, t)[h$lignes]) & !propre_manque
      if (any(par_parente)) {
        nd(t, NA_character_, "parente_non_determinee", h$lignes[par_parente])
        ctx$parente_g[[t]] <- sort(unique(c(ctx$parente_g[[t]], h$lignes[par_parente])))
      }
      reste <- h$lignes[is.na(g) & !par_parente]
      # date d'effet refusée pour sa valeur : la ligne reste non déterminée sous le motif du
      # refus (spécification, § 2.2, cas limite 2), toujours attendue en exclusion
      if (!is.null(effet[[t]])) {
        for (r in .refus_valeur_de(ctx, t, effet[[t]])) {
          l <- intersect(reste, r$lignes)
          if (length(l) > 0L) nd(t, NA_character_, r$code, l, paste(t, effet[[t]], sep = "."))
        }
        refus_e <- reste %in% .lignes_refusees(ctx, t, effet[[t]])
        if (any(refus_e)) ctx$reste_g[[t]] <- sort(unique(c(ctx$reste_g[[t]], reste[refus_e])))
        reste <- reste[!refus_e]
      }
      ctx$lit_propre[[t]] <- unique(c(ctx$lit_propre[[t]], unlist(lapply(effet[t], function(e) paste(t, e, sep = ".")))))
    } else {
      if (is.null(ctx$partie_h[[t]])) ctx$partie_h[[t]] <- rep(NA_real_, nrow(ctx$base[[t]]))
      g <- lire(t, "date_fin")[h$lignes] + delai[[t]]
      ctx$partie_h[[t]][h$lignes] <- g
      reste <- h$lignes[is.na(g)]
    }
    if (length(reste) > 0L) {
      nd(t, h$partie, "D03g", reste)
      # ligne entière dont la date ne se calcule pas : seule l'exclusion la résout (réserve Q5)
      if (is.na(h$partie)) ctx$reste_g[[t]] <- sort(unique(c(ctx$reste_g[[t]], reste)))
    }
  }
  invisible(NULL)
}

# Vue à l'arrêté (dictionnaire, § 6 ; spécification v1.5, § 2.2 (c)) : lignes retenues pour la
# règle V (`retenu`) = lignes de statut visible de l'évaluation unique (.visibilite_a(), mode
# "vue") ; dans famille, les seules versions valables déterminées (un membre à version valable
# non déterminée est sans version désignée) ; une table refusée en portée table n'a aucune
# ligne dans la vue à un arrêté antérieur à l'extraction (écart (i)). À l'arrêté égal à
# l'extraction, la vue est la base entière (règle 3), famille réduite à ses lignes valables.
# Inscription dans vue$visibilite_non_determinee (`ctx$lignes_nd`), à un arrêté antérieur, des
# seules lignes de statut non déterminé : une ligne, ou une partie, invisible de façon
# déterminée n'est jamais inscrite (M216 ; M167 et M171 rouvertes). Une ligne entière l'est sous
# son motif : D02b, D03g, code du refus et son origine (règle P, `ctx$nd_p` ; refus de valeur
# d'une colonne lue par la vue, .refus_vue(), pour une ligne que ses autres conditions ne
# rendent pas invisible, M199, M202 ; ligne de D03g non résolue dont la date d'effet de
# l'hypothèse est refusée : sous D03g et sous le refus, v1.5.1), ou `parente_non_determinee`
# pour une ligne visible par elle-même dont seule la parente est non déterminée (décision du
# mainteneur, D1) ; une partie
# non déterminée d'une ligne visible l'est sous sa colonne, et masquée (`ctx$partie_nd`,
# .valeurs_vue()). Une version de famille candidate, visible, n'est pas inscrite. `lit_vue` :
# colonnes lues pour établir la vue d'une table (visibilité de la table et de ses ascendantes,
# clés des liens ; famille : id_membre et date_saisie, à tout arrêté).
.construire_vue <- function(ctx) {
  totale <- .vue_totale(ctx)
  liens <- .liens_regle1(ctx$dico)
  liens <- liens[liens$table %in% ctx$tables & liens$table_cible %in% ctx$tables, , drop = FALSE]
  tables <- setdiff(ctx$tables, "extraction")
  ev <- .visibilite_a(ctx, "vue")
  statut <- ev$statut
  retenu <- lapply(stats::setNames(tables, tables), function(t) statut[[t]] %in% TRUE)
  # famille.date_saisie est une colonne de clé (id_membre, date_saisie) : son refus est de
  # portée table (dict. § 1.10), jamais un refus de valeur
  if ("famille" %in% tables && is.na(.cause(ctx, "famille", "date_saisie")) &&
      is.na(.cause(ctx, "famille", "id_membre"))) {
    retenu$famille <- ev$valable %in% TRUE
  }
  refusee <- function(t) !totale && !is.null(ctx$refus_pv$tables[[t]])
  for (t in tables) if (refusee(t)) retenu[[t]] <- rep(FALSE, length(retenu[[t]]))
  ctx$retenu <- retenu
  ctx$lignes_nd <- list()
  for (t in tables) ctx$partie_nd[[t]] <- rep(FALSE, length(retenu[[t]]))
  inscrire <- function(k, lignes) {
    if (length(lignes) == 0L || refusee(k$table)) return(invisible(NULL))
    if (!is.na(k$colonne)) ctx$partie_nd[[k$table]][lignes] <- TRUE
    ctx$lignes_nd[[length(ctx$lignes_nd) + 1L]] <- list(table = k$table, colonne = k$colonne, motif = k$motif,
                                                        lignes = lignes, origine = k$origine)
    invisible(NULL)
  }
  # partie non déterminée d'une ligne visible
  partie_nd <- function(k) k$lignes[statut[[k$table]][k$lignes] %in% TRUE & is.na(ev$parties[[k$table]][k$lignes])]
  if (!totale) {
    for (k in ctx$nd_p) {
      inscrire(k, if (is.na(k$colonne)) k$lignes[is.na(statut[[k$table]][k$lignes])] else partie_nd(k))
      # ligne de D03g non résolue (sans déclaration complète) dont la date d'effet de
      # l'hypothèse est refusée pour sa valeur : cette date peut la rendre invisible (point
      # P1), elle est inscrite aussi sous le refus (lecture existentielle, cas limite (1) ;
      # v1.5.1, décision du mainteneur, Q1 de #43)
      effet <- .EFFET_D03G[[k$table]]
      if (!is.na(k$colonne) || k$motif != "D03g" || is.null(effet)) next
      for (r in .refus_valeur_de(ctx, k$table, effet)) {
        l <- intersect(k$lignes, r$lignes)
        inscrire(list(table = k$table, colonne = NA_character_, motif = r$code, origine = paste(k$table, effet, sep = ".")),
                 l[is.na(statut[[k$table]][l])])
      }
    }
    # ligne entière refusée sur une colonne lue par la vue, de statut non déterminé (NA de
    # .visibilite_a() : aucune autre condition ne la rend invisible), hors lignes déjà non
    # résolues par la règle P
    for (k in ev$refus) {
      if (!is.na(k$colonne)) next
      l <- k$lignes
      inscrire(k, l[!ctx$non_determine[[k$table]][l] & is.na(statut[[k$table]][l])])
    }
    for (t in tables) {
      inscrire(list(table = t, colonne = NA_character_, motif = "parente_non_determinee", origine = NA_character_),
               which(ev$propre[[t]] %in% TRUE & is.na(statut[[t]])))
    }
    for (k in ev$refus) if (!is.na(k$colonne)) inscrire(k, partie_nd(k))
  }
  # colonnes lues pour établir la vue de chaque table : sa visibilité et celle de ses
  # ascendantes par les liens, et les clés de ces liens
  ctx$lit_vue <- list()
  for (t in names(retenu)) {
    lus <- if (t == "famille") c("famille.id_membre", "famille.date_saisie") else character(0)
    if (!totale) {
      asc <- t
      cles <- character(0)
      repeat {
        l <- liens[liens$table %in% asc, , drop = FALSE]
        cles <- unique(c(cles, paste(l$table, l$colonne, sep = "."), paste(l$table_cible, l$colonne_cible, sep = ".")))
        nouvelles <- setdiff(l$table_cible, asc)
        if (length(nouvelles) == 0L) break
        asc <- c(asc, nouvelles)
      }
      lus <- c(lus, unlist(ctx$lit_propre[asc]), cles)
    }
    ctx$lit_vue[[t]] <- unique(lus)
  }
  invisible(NULL)
}

# Colonnes lues par la vue, hors clés (M199 ; spécification, § 2.2, frontière) : colonnes de
# visibilité de la ligne entière (.DATES_VISIBILITE) et colonnes que lit D02b, hors clés
# (`.COLONNES_D02B`) ; pour une partie de ligne (.PARTIES_LIGNE), sa date et la date de fin
# que lit D03g (`.COLONNES_PARTIE_D03G`). Les colonnes de la parente que lit une règle P sont
# des colonnes de visibilité de la parente : leur refus passe à la fille par la règle 1.
.COLONNES_D02B <- list(evenements = c("date_effet", "type_evenement", "motif"), sinistres = "date_declaration",
                       catastrophes = "date_evenement")
.COLONNES_PARTIE_D03G <- list(contrats = "date_fin", affiliations = "date_fin")

# Refus de valeur sur une colonne lue par la vue, à un arrêté antérieur à l'extraction
# (.construire_vue()) : une entrée par refus (table, colonne : NA pour la ligne entière, sinon
# colonne de la partie de ligne ; motif : code du refus ; origine : « table.colonne » ;
# lignes), dans l'ordre des tables du dictionnaire, des colonnes lues et des constats. Une
# ligne n'y entre que si la valeur refusée peut changer sa visibilité à l'arrêté
# (spécification, § 2.2, (c) ; visa d'`actuary`, Q5, #33) :
# - date de visibilité (.DATES_VISIBILITE), date de saisie de la partie de ligne,
#   sinistres.date_declaration, catastrophes.date_evenement : toute ligne refusée ;
# - evenements.type_evenement, motif, date_effet (lues par D02b) : ligne dont le verdict de
#   D02b est inconnu (logique de Kleene, .d02b_evenements3() ; une ligne au verdict
#   déterminé est détectée ou non par la règle P elle-même) ; sous l'hypothèse de D02b
#   déclarée, en plus, effet postérieur à l'arrêté ou inconnu (la visibilité est max(saisie,
#   effet)) ; motif : en plus, type inconnu ou programmable selon le motif (`oui:<motifs>`) ;
# - date_fin de contrats et d'affiliations (lue par D03g sur la partie de ligne) : ligne dont
#   la date de saisie de la fin manque ou est inconnue (sinon la fin est connue à cette date).
# Logique à trois valeurs (principe de M187) : la ligne qu'une autre date lisible rend
# invisible l'est de façon déterminée (.construire_vue()).
.refus_vue <- function(ctx) {
  a <- as.numeric(ctx$arrete)
  res <- list()
  ajouter <- function(table, colonne, colonne_lue, lignes_admises = NULL) {
    for (r in .refus_valeur_de(ctx, table, colonne_lue)) {
      l <- if (is.null(lignes_admises)) r$lignes else intersect(r$lignes, lignes_admises)
      if (length(l) > 0L) res[[length(res) + 1L]] <<- list(table = table, colonne = colonne, motif = r$code,
                                                           lignes = l, origine = paste(table, colonne_lue, sep = "."))
    }
  }
  admises <- list()
  if ("evenements" %in% ctx$tables) {
    # verdict de D02b inconnu (.d02b_evenements3()) ; sous l'hypothèse de D02b déclarée, la
    # visibilité est max(saisie, effet) : elle n'en dépend que si l'effet est postérieur à
    # l'arrêté ou inconnu
    effet <- .date_connue(ctx, "evenements", "date_effet")
    # sur les lignes refusées retenues, le verdict n'est jamais vrai : is.na() y équivaut à
    # !(... %in% FALSE)
    inconnu <- is.na(.d02b_evenements3(ctx))
    if (.h_d02b(ctx)) inconnu <- inconnu & (is.na(effet) | effet > a)
    # le motif ne joue que si le type est inconnu ou programmable selon le motif (`oui:<motifs>`)
    te <- ctx$dico$types_evenements
    prog <- te$programmable[match(.valeurs(ctx, "evenements", "type_evenement"), te$type_evenement)]
    motif_joue <- .inconnu(ctx, "evenements", "type_evenement") | (!is.na(prog) & startsWith(prog, "oui:"))
    admises$evenements <- list(type_evenement = which(inconnu), motif = which(inconnu & motif_joue),
                               date_effet = which(inconnu))
  }
  for (t in setdiff(ctx$tables, "extraction")) {
    for (c1 in unique(c(.DATES_VISIBILITE[[t]], .COLONNES_D02B[[t]]))) {
      ajouter(t, NA_character_, c1, if (c1 %in% .DATES_VISIBILITE[[t]]) NULL else admises[[t]][[c1]])
    }
    for (p in .PARTIES_LIGNE) {
      if (p$table != t) next
      ajouter(t, p$date, p$date)
      # date_fin refusée : verdict de D03g inconnu si la date de saisie de la fin manque ou
      # est elle-même inconnue (.manque3())
      for (c1 in .COLONNES_PARTIE_D03G[[t]]) ajouter(t, p$date, c1, which(!(.manque3(ctx, t, p$date) %in% FALSE)))
    }
  }
  res
}

# Valeurs d'une colonne dans la vue : manquantes pour une ligne non retenue et, à un arrêté
# antérieur à l'extraction, pour une partie de ligne qui n'est pas connue à l'arrêté de façon
# déterminée : partie lue sur l'évaluation unique de la visibilité (`parties` de
# .visibilite_a(), mode "vue" ; M216), jamais recalculée ici, et date de partie jamais
# convertie (#54, spécification de B2, § 4.3) : fin d'un contrat ou d'une affiliation saisie
# après, ou de saisie non déterminée ; instruction postérieure ; partie dont une colonne lue
# par la vue est refusée pour sa valeur ; date de partie illisible par sa forme (#51). Le NA
# rendu veut dire « hors de la vue », non « absente » ; une jointure sur ces valeurs ne voit
# donc que la vue. La table extraction (une ligne, contrôlée par les refus d'appel) n'a pas de
# vue : elle est lue telle quelle.
.valeurs_vue <- function(ctx, table, colonne) {
  x <- .valeurs(ctx, table, colonne)
  if (table == "extraction") return(x)
  # D02a sous H (.appliquer_d02a(), après le bilan) : date rejetée tenue pour inconnue, ou
  # substituée par la règle écrite de R13
  d <- ctx$d02a[[table]][[colonne]]
  if (!is.null(d)) {
    x[d$masque] <- NA
    if (!is.null(d$valeur)) x[d$masque] <- d$valeur[d$masque]
  }
  masque <- !ctx$retenu[[table]]
  if (!.vue_totale(ctx)) {
    for (p in .PARTIES_LIGNE) {
      if (p$table == table && colonne %in% p$colonnes) {
        masque <- masque | !(.visibilite_a(ctx, "vue")$parties[[table]] %in% TRUE)
      }
    }
  }
  x[masque] <- NA
  x
}

# Règle de la règle V : comme .regle(), sur les seules lignes retenues par la vue ; une
# table refusée, ou une colonne illisible par sa forme lue pour établir la vue, empêche la
# règle (cause : son motif). `vue` : colonnes d'autres tables lues pour établir leur vue,
# qui s'ajoutent à celles de la table (`lit_vue`) : un refus de valeur sur l'une d'elles ne
# bloque pas la règle, ses lignes étant hors de la vue (M200 ; .regle()).
# Verdict à trois valeurs (spécification v1.5, § 2.2 (d) ; M218, lecture (ii), précision P2) :
# la population est la vue (lignes retenues ; famille : versions valables déterminées, et
# dernière version visible d'un membre à version valable non déterminée, .verdict_vue()) ; une
# ligne non déterminée en est exclue, sans ligne de controles_non_executes pour son propre
# verdict. `f()` rend un vecteur logique ; s'il porte l'attribut `index` (.verdict3(),
# .existe_vue3()), une valeur NA est un verdict inconnu : la ligne est écartée de la détection
# (nombre minorant) et la règle garde une ligne dans controles_non_executes, cause (γ)
# (.cause_nd()). Sans cet attribut, NA vaut « non détecté » (inchangé). `f` NULL : causes de
# la règle bloquée seulement (.regle()).
# `mode` (#105, lot V ; spécification `donnees`, erratum `1.9.7`, E-1, E-3 et E-4, M808) :
# "bloquee" (défaut, M169) : une colonne lue comme valeur et refusée pour sa valeur bloque la
# règle, cause = motif du refus ; "kleene" : la règle s'exécute en logique de Kleene (lecture
# existentielle) sur le noyau à trois valeurs (.entree3(), .verdict3(), .k3()) : `f()` lit la
# valeur refusée comme inconnue et rend l'attribut `index` (son absence est une erreur interne) ;
# une ligne de la population au verdict inconnu est écartée (nombre minorant) ; la ligne qui
# porte la valeur refusée reste dans la population. Cause : les seuls éléments pertinents de la
# ligne écartée (attribut `index_pertinent` de .verdict3(), pertinence exacte, exigé : son
# absence est une erreur interne), valeur refusée qu'elle porte comprise (motif du refus, rang
# 3), départagés avec les causes (γ) en un seul calcul (.cause_nd(), § 3.1), D01a compris
# (`d01a_pertinent`). Garde : chaque colonne lue comme valeur et refusée pour sa valeur doit être
# une entrée du verdict (attribut `lues` ou clé de `index`) ; sinon (valeur refusée lue brute),
# erreur interne. Un défaut de forme ou un refus de portée table bloque dans les deux modes
# (.regle()). Écart connu au § 3.1 : en mode "bloquee", la cause (γ) lit `index`, plus large que
# les seuls éléments pertinents ; la pertinence exacte n'est lue qu'en mode Kleene ; l'écart
# disparaît avec l'argument `mode` en fin de lot. Le mode est choisi
# règle par règle à l'appel ; le recensement des règles V et de leur mode est testé
# (tests/unitaires/donnees.R, registre des règles V).
.regle_vue <- function(ctx, code, table, colonne, lit, traitement, detection, f, colonne_ne = colonne,
                       vue = character(0), mode = "bloquee") {
  if (!identical(mode, "bloquee") && !identical(mode, "kleene")) {
    stop("erreur interne de provie : r\u00e8gle V ", code, " (", table, ") : mode inconnu", call. = FALSE)
  }
  kleene <- identical(mode, "kleene")
  if (is.null(ctx$base[[table]])) return(invisible(integer(0)))
  cle <- paste(table, eclater_champ(ctx$dico$tables$cle_primaire[ctx$dico$tables$table == table])[1L], sep = ".")
  # à l'arrêté égal à l'extraction, aucune ligne n'est non déterminée (spécification, § 2.2,
  # (g)) : les colonnes lues pour la vue (famille : version valable) sont lues comme valeurs en
  # mode "bloquee" seulement (M169) ; en mode Kleene, elles ne sont pas lues par le verdict
  # (§ 2.2 (g), E-1) : leur refus de valeur ne bloque pas (.regle(), `kleene`) et n'est pas une
  # entrée obligée du verdict (garde)
  totale <- .vue_totale(ctx)
  ecart <- NULL
  lit_valeur <- if (totale) c(lit, vue, cle, ctx$lit_vue[[table]]) else c(lit, cle)
  # mode Kleene : colonnes lues comme valeur (colonne contrôlée, `lit`, clé ; aux deux arrêtés,
  # sans les colonnes de vue) et refusées pour leur valeur sur une ligne au moins
  # (.lignes_refusees() : refus de valeur et cellules manquantes de D03i), entrées obligées du
  # verdict (garde). Limites connues : la garde est par colonne, non par lecture ; une colonne
  # entrée du verdict et lue aussi brute dans `f()` n'est pas vue, ni une lecture brute passée
  # par .connue3(), ni les lectures internes d'un noyau dont l'attribut `lues` est statique
  # (.age_assure3(), .verdict_d11c(), .eclater3()) : la conversion d'une règle (G1 à G3)
  # interdit toute lecture brute d'une colonne refusable dans `f()` en mode Kleene.
  refusees_lues <- character(0)
  if (kleene) {
    lus <- unique(c(if (!is.na(colonne)) paste(table, colonne, sep = "."), lit, cle))
    refusees_lues <- lus[vapply(strsplit(lus, ".", fixed = TRUE), function(m) !is.null(.lignes_refusees(ctx, m[1L], m[2L])),
                                NA)]
  }
  res <- .regle(ctx, code, table, colonne, lit_valeur, traitement, detection, if (!is.null(f)) function() {
    r <- .verdict_vue(ctx, table, f)
    index <- attr(r, "index", exact = TRUE)
    d01a <- NULL
    if (kleene) {
      # pertinence exacte exigée (.verdict3() ; un autre noyau la fournira à sa conversion) ;
      # `index` (lu par le mode bloquee) peut manquer
      ip <- attr(r, "index_pertinent", exact = TRUE)
      if (is.null(ip)) {
        stop("erreur interne de provie : r\u00e8gle V ", code, " (", table, ") en mode Kleene sans ",
             "verdict \u00e0 trois valeurs de pertinence exacte", call. = FALSE)
      }
      hors <- setdiff(refusees_lues, c(names(index), names(ip), attr(r, "lues")))
      if (length(hors) > 0L) stop("erreur interne de provie : r\u00e8gle V ", code, " (", table, ") en mode Kleene : ",
                                  "valeur refus\u00e9e lue hors du verdict \u00e0 trois valeurs (",
                                  paste(hors, collapse = ", "), ")", call. = FALSE)
      index <- ip
      d01a <- attr(r, "d01a_pertinent")
    }
    x <- ifelse(attr(r, "population"), r, FALSE)
    if (!is.null(index)) {
      ecart <<- list(lignes = which(is.na(x)), index = index, d01a = d01a)
    }
    x %in% TRUE
  }, colonne_ne, vue = if (totale) character(0) else c(vue, ctx$lit_vue[[table]]), kleene = kleene)
  if (!is.null(res) && length(ecart$lignes) > 0L) {
    .ajouter_non_execute(ctx, code, table, colonne_ne, .cause_nd(ctx, ecart$index, ecart$lignes, code, table, ecart$d01a))
  }
  invisible(res)
}

# Verdict de `f()` sur la population de la règle V de `table` (attribut `population`) : les
# lignes retenues par la vue ; pour famille, aussi la dernière version visible d'un membre à
# version valable non déterminée, dont le verdict est celui de chaque candidate
# (.visibilite_a(), `candidate`) : `f()` est évaluée avec les candidates dans la vue (verdict
# propre à la ligne : D03a, D03b, D02a et D02c sur famille), et la version visible prend le
# verdict commun de ses candidates, inconnu (NA) s'il varie, éléments non déterminés : les
# candidates non déterminées de verdict différent (spécification v1.5, § 2.2 (c) 6 et (d) ;
# M216, M218).
.verdict_vue <- function(ctx, table, f) {
  population <- ctx$retenu[[table]]
  ev <- if (table == "famille" && !.vue_totale(ctx)) .visibilite_a(ctx, "vue") else NULL
  if (is.null(ev$candidate) || !any(ev$candidate)) {
    r <- f()
    attr(r, "population") <- population
    return(r)
  }
  retenu <- ctx$retenu$famille
  on.exit(ctx$retenu$famille <- retenu)
  ctx$retenu$famille <- retenu | ev$candidate
  r0 <- f()
  ctx$retenu$famille <- retenu
  visible <- which(ev$candidate & ev$statut$famille %in% TRUE)
  nd <- which(ev$candidate & is.na(ev$statut$famille))
  index0 <- attr(r0, "index", exact = TRUE)
  # entrées pertinentes (.verdict3(), règle V en mode Kleene) : celles d'une candidate c ne
  # comptent pour la version visible que si le verdict de c est inconnu (is.na(r0[c])), leur
  # pertinence sur c étant celle que .verdict3() a établie. Choix de version (candidate non
  # déterminée c, clé « famille ») : pertinent si une affectation des inconnues donne à i et à c
  # deux verdicts différents ; sans inconnue partagée, si leurs verdicts ne sont pas déterminés et
  # égaux ; avec une inconnue partagée (survenance d'un sinistre commun), par évaluation jointe
  # sur les mêmes valeurs des cellules partagées (.choix_pertinent3() ; décision du mainteneur du
  # 25 novembre 2026, #105, lot V, G1). Le verdict de i reste celui des lignes séparées (exact)
  ip0 <- attr(r0, "index_pertinent")
  noyau <- attr(r0, "noyau3")
  dp0 <- attr(r0, "d01a_pertinent")
  r <- as.vector(r0)
  r[ev$candidate] <- FALSE
  index <- if (is.null(index0)) list() else lapply(index0, function(z) { z[ev$candidate] <- list(NULL); z })
  index$famille <- if (is.null(index$famille)) vector("list", length(r)) else index$famille
  ip <- if (is.null(ip0)) NULL else lapply(ip0, function(z) { z[ev$candidate] <- list(NULL); z })
  dp <- if (is.null(dp0)) NULL else lapply(dp0, function(z) { z[ev$candidate] <- FALSE; z })
  if (!is.null(ip0)) ip$famille <- if (is.null(ip$famille)) vector("list", length(r)) else ip$famille
  # candidates non déterminées de chaque membre (un regroupement, travail linéaire)
  nd_membre <- split(nd, ev$membre[nd])[ev$membre[visible]]
  for (k in seq_along(visible)) {
    i <- visible[k]
    autres <- nd_membre[[k]]
    v <- r0[c(i, autres)]
    differe <- autres[!(r0[autres] %in% r0[i])]
    r[i] <- if (all(v %in% TRUE)) TRUE else if (all(v %in% FALSE)) FALSE else NA
    if (is.na(r[i])) {
      # éléments rendus par `f()` sous la clé « famille » : réunis aux candidates, non écrasés
      # (#56, point 3) ; affectation par `[i] <- list()`, qui garde l'élément même NULL (`[[i]]
      # <- NULL` le supprimerait et décalerait les lignes suivantes)
      for (tc in names(index0)) index[[tc]][i] <- list(unique(unlist(index0[[tc]][c(i, autres)])))
      index$famille[i] <- list(unique(c(if (is.na(r0[i])) autres else differe,
                                        if ("famille" %in% names(index0)) index$famille[[i]])))
      if (!is.null(ip0)) {
        inconnues <- c(i, autres[is.na(r0[autres])])
        for (tc in setdiff(names(ip0), "famille")) ip[[tc]][i] <- list(unique(unlist(ip0[[tc]][inconnues])))
        choix <- autres[vapply(autres, function(c1) {
          joint <- if (is.null(noyau)) NA else .choix_pertinent3(noyau, i, c1)
          if (is.na(joint)) is.na(r0[i]) || !(r0[c1] %in% r0[i]) else joint
        }, NA)]
        ip$famille[i] <- list(unique(c(choix, unlist(ip0$famille[inconnues]))))
        for (tc in names(dp0)) dp[[tc]][i] <- any(dp0[[tc]][inconnues])
      }
    }
  }
  population[visible] <- TRUE
  attr(r, "index") <- index
  if (!is.null(ip0)) attr(r, "index_pertinent") <- ip
  if (!is.null(dp0)) attr(r, "d01a_pertinent") <- dp
  if (!is.null(attr(r0, "lues"))) attr(r, "lues") <- attr(r0, "lues")
  attr(r, "population") <- population
  r
}

# Lignes de `table` de statut non déterminé dans la vue (évaluation unique, .visibilite_a()),
# hors table refusée en portée table (aucune ligne dans la vue, écart (i)) ; aucune à l'arrêté
# égal à l'extraction (spécification, § 2.2 (g)). Famille : versions de statut non déterminé
# (les candidates d'un membre à version valable non déterminée relèvent de .verdict_vue()).
.nd_vue <- function(ctx, table) {
  n <- NROW(ctx$base[[table]])
  if (.vue_totale(ctx) || !is.null(ctx$refus_pv$tables[[table]])) return(rep(FALSE, n))
  is.na(.visibilite_a(ctx, "vue")$statut[[table]])
}

# Entrée à trois valeurs (.verdict3()) « il existe une ligne de `table` dans la vue, de clé
# `cle` égale à `valeurs_cle`, qui satisfait `p` (vecteur logique sur les lignes de `table`,
# valeurs brutes) » (forme « absence » des règles V, spécification v1.5, § 2.2 (d)) : vraie si
# une ligne retenue satisfait ; inconnue si aucune ne satisfait parmi les retenues et qu'une
# ligne non déterminée (.nd_vue()) satisfait ; fausse sinon (.existe_kleene() : une clé
# manquante ne s'apparie à aucune ligne). `index` : lignes non déterminées qui rendent l'entrée
# inconnue (cause, .cause_nd()).
.existe_vue3 <- function(ctx, table, valeurs_cle, cle, p) {
  p <- p %in% TRUE
  e <- .existe_kleene(valeurs_cle, cle, vrai = ctx$retenu[[table]] & p, possible = .nd_vue(ctx, table) & p)
  c(list(tc = table), e, list(domaine = c(TRUE, FALSE)))
}

# Cause (γ) d'une règle V qui écarte les lignes `lignes` (spécification v1.5, § 3.1 ; M218) :
# éléments non déterminés dont l'état peut changer le verdict (`index` : par « table » ou
# « table.colonne » de partie de ligne, lignes de la table pour chaque ligne de la règle).
# Cause d'un élément : le motif du refus pour une ligne ou une partie non déterminée par un
# refus de valeur ; declaration_absente pour D02b ou D03g ; pour parente_non_determinee, la
# cause de l'ascendante la plus proche non déterminée par elle-même (récursivement, par les
# liens de la règle 1). Entre plusieurs éléments, la plus petite de leurs causes dans l'ordre
# (rang, position) (.cause_retenue() : cause directe, rang 3, avant declaration_absente, rang
# 6 ; à rang égal, ordre des codes du dictionnaire), indépendante de l'ordre de
# vue$visibilite_non_determinee (spécification `donnees` v1.6, § 3.1, départage à rang égal,
# #59). Ligne retenue de valeur refusée (index « table.colonne » d'une colonne qui n'est pas une
# partie de ligne, ou ligne sans inscription : date d'effet d'un événement retenu,
# .arret_en_cours3() ; audit de la reprise de #81, #72 ; ligne qui porte la valeur refusée
# qu'elle lit, en mode Kleene, .regle_vue()) : le motif du refus de valeur de la colonne
# (.refus_valeur_de()). Une ligne écartée sans élément qui l'explique est une erreur
# interne.
.cause_nd <- function(ctx, index, lignes, code, table, d01a = NULL) {
  liens <- .liens_regle1(ctx$dico)
  liens <- liens[liens$table %in% ctx$tables & liens$table_cible %in% ctx$tables, , drop = FALSE]
  statut <- .visibilite_a(ctx, "vue")$statut
  causes <- character(0)
  retenir <- function(k) {
    causes <<- c(causes, if (k$motif %in% .MOTIFS_REGLE_P) "declaration_absente" else k$motif)
  }
  # inscriptions de `t` (colonne `colonne`) qui portent l'une des lignes `l` : les causes des
  # inscriptions propres sont retenues ; rend les lignes de `l` inscrites par elles-mêmes
  # (`propre`) et celles inscrites seulement sous parente_non_determinee (`parente`)
  inscriptions <- function(t, colonne, l) {
    propre <- integer(0)
    parente <- integer(0)
    for (k in ctx$lignes_nd) {
      if (k$table != t || !identical(k$colonne, colonne)) next
      x <- intersect(k$lignes, l)
      if (length(x) == 0L) next
      if (k$motif == "parente_non_determinee") parente <- c(parente, x) else { retenir(k); propre <- c(propre, x) }
    }
    list(propre = unique(propre), parente = setdiff(parente, propre))
  }
  # ascendante non déterminée la plus proche qui l'est par elle-même, niveau par niveau, pour
  # chaque ligne de `t` inscrite sous parente_non_determinee
  ascendantes <- function(t, l) {
    niveau <- stats::setNames(list(l), t)
    while (length(unlist(niveau)) > 0L) {
      suivant <- list()
      trouve <- FALSE
      for (t1 in names(niveau)) {
        for (i in which(liens$table == t1)) {
          u <- liens$table_cible[i]
          cles <- .valeurs(ctx, t1, liens$colonne[i])[niveau[[t1]]]
          p <- which(!is.na(apparier_cles(.valeurs(ctx, u, liens$colonne_cible[i]), cles)) & is.na(statut[[u]]))
          if (length(p) == 0L) next
          x <- inscriptions(u, NA_character_, p)
          if (length(x$propre) > 0L) trouve <- TRUE
          suivant[[u]] <- unique(c(suivant[[u]], x$parente))
        }
      }
      if (trouve) break
      niveau <- suivant
    }
  }
  for (tc in names(index)) {
    l <- sort(unique(unlist(index[[tc]][lignes])))
    if (length(l) == 0L) next
    m <- strsplit(tc, ".", fixed = TRUE)[[1L]]
    x <- inscriptions(m[1L], if (length(m) > 1L) m[2L] else NA_character_, l)
    for (r in x$parente) ascendantes(m[1L], r)
    # lignes sans inscription d'une colonne : valeur refusée d'une ligne retenue
    if (length(m) > 1L) {
      seules <- setdiff(l, c(x$propre, x$parente))
      for (k in .refus_valeur_de(ctx, m[1L], m[2L])) if (length(intersect(k$lignes, seules)) > 0L) causes <- c(causes, k$code)
    }
  }
  # clé jointe en double aux occurrences divergentes, entrée pertinente d'une ligne écartée
  # (`d01a` : attribut `d01a_pertinent` de .verdict3(), règle V en mode Kleene seulement) : cause
  # candidate D01a (erratum `1.9.7`, E-3). Chemin non atteint aujourd'hui : une clé en double est
  # un refus D01a de portée table, qui bloque la règle avant (#169)
  for (tc in names(d01a)) if (any(d01a[[tc]][lignes])) causes <- c(causes, "D01a")
  if (length(causes) == 0L) stop("erreur interne de provie : r\u00e8gle V : ligne \u00e9cart\u00e9e sans \u00e9l\u00e9ment non ",
                                 "d\u00e9termin\u00e9 qui l'explique (", code, ", ", table, ")", call. = FALSE)
  .cause_retenue(causes, ctx$dico, ctx$ordre_codes)
}

# Visibilité non déterminée (M156, D1) : une ligne par (table, colonne, motif, origine) ;
# colonne NA pour la ligne entière, sinon colonne de la partie de ligne ; origine :
# « table.colonne » de la valeur refusée pour un motif de refus, NA sinon (M202 ; ADR 0010,
# quatorzième série, (b)) ; ordre du dictionnaire (tables, colonnes, NA en tête), puis du
# motif, puis de l'origine (NA en dernier).
.visibilite_non_determinee <- function(ctx) {
  nd <- ctx$lignes_nd
  df <- data.frame(table = vapply(nd, `[[`, "", "table"), colonne = vapply(nd, function(k) k$colonne, ""),
                   motif = vapply(nd, `[[`, "", "motif"), origine = vapply(nd, function(k) k$origine, ""),
                   nombre = integer(length(nd)), identifiants = character(length(nd)), stringsAsFactors = FALSE)
  if (nrow(df) == 0L) return(df)
  cles <- paste(df$table, df$colonne, df$motif, df$origine, sep = "\r")
  groupes <- split(seq_along(nd), factor(cles, levels = unique(cles)))
  df <- df[vapply(groupes, `[`, 0L, 1L), , drop = FALSE]
  lignes <- lapply(groupes, function(g) sort(unique(unlist(lapply(nd[g], `[[`, "lignes")))))
  df$nombre <- vapply(lignes, length, 0L, USE.NAMES = FALSE)
  df$identifiants <- vapply(seq_along(lignes), function(i) .identifiants(ctx, df$table[i], lignes[[i]]), "")
  # tri par origine d'abord, que le tri stable (radix) de .trier() garde à table, colonne et
  # motif égaux
  df <- df[order(df$origine, na.last = TRUE, method = "radix"), , drop = FALSE]
  .trier(df, ctx$dico, "motif")
}

# --- Règle V ---------------------------------------------------------------------------

# Défauts traités X, H ou S, hors D02b et D03g, détectés sur la vue à l'arrêté (spécification,
# § 2.2). Le traitement d'un constat est la liste des traitements admis par le § 9 pour le
# sous-cas (« X;H »...) quand le choix revient à une déclaration ; R et S sont placés par
# .bilan(), les autres par .placer().
.regle_v <- function(ctx) {
  # somme des parts des bénéficiaires d'un dossier différente de 1 (§ 3, T11) : signalement.
  # Règle V en mode Kleene (#105, lot V, G1) : noyau propre (.somme_parts3())
  .regle_vue(ctx, "somme_parts", "beneficiaires", "part", "beneficiaires.id_dossier",
             .traitement_code_controle(ctx$dico, "somme_parts"), "exacte", function() .somme_parts3(ctx), mode = "kleene")
  .regle_v_parente_posterieure(ctx)
  .regle_v_manquants(ctx)
  .regle_v_ordre_dates(ctx)
  .regle_v_doublons(ctx)
  .regle_v_clotures(ctx)
  .regle_v_garanties(ctx)
  .regle_v_ages(ctx)
  .regle_v_limite_age(ctx)
  .regle_v_extinctions(ctx)
  .regle_v_rechutes(ctx)
  .regle_v_qualites(ctx)
  .regle_v_deces_conjoint(ctx)
  .regle_v_couverture(ctx)
  .regle_v_suites(ctx)
  .regle_v_double_effet(ctx)
  invisible(NULL)
}

# somme_parts à trois valeurs (spécification v1.5, § 2.2 (d) ; #105, lot V, G1 ; spécification
# `donnees`, erratum `1.9.7`, E-1). V : somme des parts connues des bénéficiaires visibles du
# dossier ; m : nombre de parts visibles refusées pour leur valeur, chacune inconnue dans ]0 ; 1]
# (part positive, au plus 1) ; [a, b] : tolérance autour de 1. Avec m ≥ 1, la somme parcourt
# ]V ; V + m], qui rencontre [a, b] dès que V < b (V + m ≥ 1 > a) : vrai si V ≥ b, inconnu sinon ;
# chaque part refusée d'une ligne au verdict inconnu est pertinente. Bénéficiaire non déterminé
# de part refusée : présent ou non, de part dans ]0 ; 1] : sans part visible refusée, vrai si
# V > b, inconnu sinon. Sinon, règle des bénéficiaires non déterminés (v1.5.4), inchangée :
# verdict inconnu si une sous-somme de leurs parts, ajoutée à V, tombe à moins de la tolérance de
# 1 alors qu'une autre n'y tombe pas ; les parts étant positives (]0 ; 1]), les sommes vont de V
# à V plus celle de tous, et une sous-somme qui dépasse b n'y revient pas. Éléments d'une ligne
# au verdict inconnu : bénéficiaires non déterminés du dossier (clé beneficiaires) et parts
# refusées du dossier (clé beneficiaires.part).
.somme_parts3 <- function(ctx) {
  part <- .valeurs_vue(ctx, "beneficiaires", "part")
  dossier <- as.character(.valeurs_vue(ctx, "beneficiaires", "id_dossier"))
  inconnu <- .inconnu(ctx, "beneficiaires", "part")
  n <- length(part)
  sortie <- function(r, index, ip) {
    attr(r, "index") <- index
    attr(r, "index_pertinent") <- ip
    attr(r, "lues") <- "beneficiaires.part"
    r
  }
  ok <- !is.na(dossier)
  if (!any(ok)) return(sortie(rep(FALSE, n), list(beneficiaires = vector("list", n)), list()))
  connue <- ok & !inconnu
  somme <- if (any(connue)) rowsum(part[connue], dossier[connue]) else matrix(numeric(0), 0L, 1L)
  s <- somme[match(dossier, rownames(somme)), 1L]
  s[ok & is.na(s)] <- 0
  r <- !is.na(s) & abs(s - 1) > .TOLERANCE_PARTS
  bas <- 1 - .TOLERANCE_PARTS
  haut <- 1 + .TOLERANCE_PARTS
  brut <- as.character(.valeurs(ctx, "beneficiaires", "id_dossier"))
  nd <- which(.nd_vue(ctx, "beneficiaires") & !is.na(brut))
  refusees <- which(ok & inconnu)
  nd_inconnu <- nd[inconnu[nd]]
  index <- vector("list", n)
  ip_b <- vector("list", n)
  ip_p <- vector("list", n)
  # parts refusées pour leur valeur : verdict par la règle ci-dessus
  dossiers_inconnus <- unique(c(dossier[refusees], brut[nd_inconnu]))
  for (k in dossiers_inconnus) {
    l <- which(ok & dossier %in% k)
    if (length(l) == 0L) next
    v <- s[l[1L]]
    avec_m <- k %in% dossier[refusees]
    vrai <- if (avec_m) v >= haut else v > haut
    if (vrai) {
      r[l] <- TRUE
      next
    }
    r[l] <- NA
    lignes_nd <- nd[brut[nd] %in% k]
    for (i in l) {
      index[[i]] <- lignes_nd
      ip_b[[i]] <- lignes_nd
      ip_p[[i]] <- c(refusees[dossier[refusees] %in% k], nd_inconnu[brut[nd_inconnu] %in% k])
    }
  }
  # bénéficiaires non déterminés (v1.5.4), dossiers sans part inconnue
  l <- which(!is.na(s) & dossier %in% brut[nd] & !(dossier %in% dossiers_inconnus))
  if (length(l) > 0L) {
    parts_nd <- split(.valeurs(ctx, "beneficiaires", "part")[nd], brut[nd])[dossier[l]]
    lignes_nd <- split(nd, brut[nd])[dossier[l]]
    # raccourcis exacts en O(k) (V : somme des visibles ; T : des non déterminées ; [a, b] :
    # tolérance autour de 1) : vrai si V > b ou V + T < a ; faux si V et V + T dans [a, b] ;
    # inconnu si leurs verdicts diffèrent, ou si V < a, V + T > b et chaque part non
    # déterminée vaut au plus b - a (les sommes partielles franchissent [a, b] par pas d'au plus
    # b - a) ; cas résiduel : énumération des sous-sommes, au plus .MAX_PARTS_ND parts, inconnu
    # au-delà (avis d'`actuary`)
    for (k in seq_along(l)) {
      i <- l[k]
      p <- parts_nd[[k]]
      v <- s[i]
      vt <- v + sum(p)
      if (v > haut || vt < bas) next
      dans_v <- v >= bas && v <= haut
      dans_vt <- vt >= bas && vt <= haut
      if (dans_v && dans_vt) next
      inc_k <- dans_v != dans_vt || all(p <= haut - bas) || length(p) > .MAX_PARTS_ND
      if (!inc_k) {
        sommes <- v
        for (x in p) sommes <- unique(c(sommes, (sommes + x)[sommes + x <= haut]))
        inc_k <- any(sommes >= bas & sommes <= haut)
      }
      if (inc_k) {
        r[i] <- NA
        index[[i]] <- lignes_nd[[k]]
        ip_b[[i]] <- lignes_nd[[k]]
      }
    }
  }
  ip <- list(beneficiaires = ip_b)
  if (any(lengths(ip_p) > 0L)) ip$beneficiaires.part <- ip_p
  sortie(r, list(beneficiaires = index), ip)
}

# parente_posterieure (dictionnaire 1.6, § 1.10 et § 6, règle 1 ; spécification `donnees` v1.9,
# § 9.3 (2) ; #83 ; M685 : parametres exclu) : ligne de affiliations, garanties_souscrites ou
# cotisations visible par sa propre date de visibilité (statut propre de .visibilite_a()), masquée
# par la règle 1 parce qu'une ascendante est invisible. Leurs ascendantes (contrats ;
# garanties_souscrites et, par elle, contrats) n'ont pour visibilité que leur date d'effet
# (.DATES_VISIBILITE ; ni D02b ni D03g sur la ligne entière) : leur invisibilité déterminée vient
# toujours d'une date d'effet postérieure à l'arrêté. Détection exacte sur la table entière (la
# ligne reste masquée : sans effet sur la vue), traitement S (controles.csv), colonne NA. À
# l'arrêté égal à l'extraction, la vue est totale : la règle ne produit rien (ni constat, ni ligne
# de controles_non_executes). Verdict à trois valeurs (Kleene) : propre ET NON parente
# (.parente_regle1(), conjonction sur les liens de .liens_regle1()) ; les colonnes de visibilité
# sont lues comme colonnes de la vue (`lit_vue` : leur refus de valeur ne bloque pas la règle,
# M200). Une ligne au verdict inconnu est écartée (détection partielle, nombre minorant) et la
# règle garde une ligne dans controles_non_executes, de cause (γ) la plus petite dans l'ordre
# (rang, position) (.cause_retenue()) parmi : pour une ligne de statut non déterminé, celle de
# .cause_nd() sur la ligne (inscription propre, ou ascendante non déterminée) et sur ses parentes
# non déterminées ; pour une ligne invisible de façon déterminée (parente invisible) de
# visibilité propre non déterminée, le motif qui la rend non déterminée (règle P : D02b ou D03g,
# declaration_absente ; refus de valeur ou D03i d'une colonne de visibilité : son code). Une
# ligne écartée sans cause est une erreur interne.
.TABLES_PARENTE_POSTERIEURE <- c("affiliations", "garanties_souscrites", "cotisations")
.regle_v_parente_posterieure <- function(ctx) {
  if (.vue_totale(ctx)) return(invisible(NULL))
  code <- "parente_posterieure"
  ev <- .visibilite_a(ctx, "vue")
  liens <- .liens_regle1(ctx$dico)
  liens <- liens[liens$table %in% ctx$tables & liens$table_cible %in% ctx$tables, , drop = FALSE]
  for (t in intersect(.TABLES_PARENTE_POSTERIEURE, ctx$tables)) {
    l_t <- liens[liens$table == t, , drop = FALSE]
    n <- nrow(ctx$base[[t]])
    cle <- paste(t, eclater_champ(ctx$dico$tables$cle_primaire[ctx$dico$tables$table == t])[1L], sep = ".")
    lit <- unique(c(cle, paste(l_t$table, l_t$colonne, sep = "."), paste(l_t$table_cible, l_t$colonne_cible, sep = ".")))
    verdict <- NULL
    res <- .regle(ctx, code, t, NA_character_, lit, .traitement_code_controle(ctx$dico, code), "exacte", function() {
      parente <- rep(TRUE, n)
      for (i in seq_len(nrow(l_t))) parente <- parente & .parente_regle1(ctx, l_t[i, , drop = FALSE], ev$statut)
      verdict <<- ev$propre[[t]] & !parente
      verdict %in% TRUE
    }, vue = ctx$lit_vue[[t]])
    ecartees <- which(is.na(verdict))
    if (is.null(res) || length(ecartees) == 0L) next
    statut_t <- ev$statut[[t]]
    nd_l <- ecartees[is.na(statut_t[ecartees])]
    causes <- character(0)
    if (length(nd_l) > 0L) {
      # la ligne et ses parentes non déterminées de même clé (inscrites dans lignes_nd)
      index <- list()
      index[[t]] <- vector("list", n)
      index[[t]][nd_l] <- as.list(nd_l)
      for (i in seq_len(nrow(l_t))) {
        u <- l_t$table_cible[i]
        cible <- .cle_manquante(as.character(.valeurs(ctx, u, l_t$colonne_cible[i])))
        p_nd <- which(is.na(ev$statut[[u]]) & !is.na(cible))
        if (length(p_nd) == 0L) next
        par_cle <- split(p_nd, cible[p_nd])
        cle_f <- .cle_manquante(as.character(.valeurs(ctx, t, l_t$colonne[i])))[nd_l]
        if (is.null(index[[u]])) index[[u]] <- vector("list", n)
        index[[u]][nd_l] <- unname(lapply(cle_f, function(k) if (is.na(k)) NULL else par_cle[[k]]))
      }
      causes <- c(causes, .cause_nd(ctx, index, nd_l, code, t))
    }
    fx <- setdiff(ecartees, nd_l)
    if (length(fx) > 0L) {
      propres <- character(0)
      couvertes <- integer(0)
      for (k in c(ctx$nd_p, ev$refus)) {
        if (k$table != t || !is.na(k$colonne) || k$motif == "parente_non_determinee" || !any(fx %in% k$lignes)) next
        propres <- c(propres, if (k$motif %in% .MOTIFS_REGLE_P) "declaration_absente" else k$motif)
        couvertes <- c(couvertes, intersect(fx, k$lignes))
      }
      causes <- c(causes, propres)
      if (!all(fx %in% couvertes)) {
        stop("erreur interne de provie : parente_posterieure : ligne \u00e9cart\u00e9e sans cause (", t, ")", call. = FALSE)
      }
    }
    .ajouter_non_execute(ctx, code, t, NA_character_, .cause_retenue(causes, ctx$dico, ctx$ordre_codes))
  }
  invisible(NULL)
}

# Manquants qui ont un défaut au § 9 (D03a, D03b, D03c, D03e, D03f, D03h), sur la vue.
# D03d (situation de famille requise par un poste) dépend des postes du plan : B2.
# Règles V en mode Kleene (#105, lot V, G1 ; spécification `donnees`, erratum `1.9.7`, E-1) :
# verdicts par .verdict3() ; une valeur manquante se lit par .manquant3() (présence seule : une
# valeur refusée d'une colonne obligatoire est présente, verdict déterminé ; d'une colonne
# facultative, présente ou absente) ; une modalité refusée prend le domaine de sa colonne
# (.entree3(), .domaine3()) ; la population de famille passe par .verdict_vue().
.regle_v_manquants <- function(ctx) {
  e3 <- function(tc, ...) .entree3(ctx, tc, ...)
  # D03a : date de naissance manquante (famille : hors enfant à naître) ; X ou H pour les
  # familles qui lisent la colonne, S pour la famille triangle (.exceptions_famille()) : deux
  # constats de même clé, le signalement écrit dès la détection, comme D01b (réserve Q2)
  for (t in c("S", "X;H")) {
    .regle_vue(ctx, "D03a", "assures", "date_naissance", character(0), t, "exacte",
               function() .verdict3(list(manque = .manquant3(ctx, "assures.date_naissance")), function(x) x$manque),
               mode = "kleene")
    .regle_vue(ctx, "D03a", "famille", "date_naissance", "famille.situation", t, "exacte", function() {
      .verdict3(list(manque = .manquant3(ctx, "famille.date_naissance"), situation = e3("famille.situation")),
                function(x) x$manque & !(x$situation %in% "a_naitre"))
    }, mode = "kleene")
  }
  # D03b : sexe manquant
  for (table in c("assures", "famille")) {
    .regle_vue(ctx, "D03b", table, "sexe", character(0), "H", "exacte",
               function() .verdict3(list(manque = .manquant3(ctx, paste0(table, ".sexe"))), function(x) x$manque),
               mode = "kleene")
  }
  # D03c : salaire de référence manquant (présence seule : aucun domaine numérique à énumérer)
  .regle_vue(ctx, "D03c", "affiliations", "salaire_reference", character(0), "X;H", "exacte",
             function() .verdict3(list(manque = .manquant3(ctx, "affiliations.salaire_reference")), function(x) x$manque),
             mode = "kleene")
  # D03e : catégorie d'invalidité manquante pour un type qui l'exige (§ 4)
  te <- ctx$dico$types_evenements
  .regle_vue(ctx, "D03e", "evenements", "categorie_invalidite", "evenements.type_evenement", "H", "exacte", function() {
    .verdict3(list(type = e3("evenements.type_evenement"), manque = .manquant3(ctx, "evenements.categorie_invalidite")),
              function(x) {
      k <- match(x$type, te$type_evenement)
      exige <- !is.na(k) & grepl("(^|;)categorie_invalidite(;|$)", te$colonnes_requises[ifelse(is.na(k), 1L, k)])
      exige & x$manque
    })
  }, mode = "kleene")
  # D03f : période couverte manquante (prestations : indemnités journalières et arrérages)
  .regle_vue(ctx, "D03f", "prestations", NA_character_,
             paste0("prestations.", c("type_prestation", "debut_periode", "fin_periode")), "X;H", "exacte", function() {
    .verdict3(list(type = e3("prestations.type_prestation"), debut = .manquant3(ctx, "prestations.debut_periode"),
                   fin = .manquant3(ctx, "prestations.fin_periode")),
              function(x) x$type %in% .TYPES_PERIODE_D03F & (x$debut | x$fin))
  }, mode = "kleene")
  .regle_vue(ctx, "D03f", "cotisations", NA_character_, paste0("cotisations.", c("debut_periode", "fin_periode")),
             "X;H", "exacte", function() {
    .verdict3(list(debut = .manquant3(ctx, "cotisations.debut_periode"), fin = .manquant3(ctx, "cotisations.fin_periode")),
              function(x) x$debut | x$fin)
  }, mode = "kleene")
  # D03h : taux du tarif manquant là où il est requis (§ 3, T4) : décès d'un contrat
  # individuel, décès d'un contrat collectif dont maintien_deces vaut TRUE (dictionnaire 1.6,
  # P6 ; spécification `donnees` v1.9, § 9.6 : le sous-cas non_lisible est retiré), rente de
  # conjoint, rente d'éducation, double effet. Nature du contrat lue sur toutes les occurrences
  # de sa clé (lecture existentielle de .joindre3(), M663, par .entree3()) : inconnue si elles
  # divergent (cause candidate D01a) ou si la nature est refusée pour sa valeur.
  .regle_vue(ctx, "D03h", "garanties_souscrites", "taux_technique_tarif",
             c("garanties_souscrites.code_garantie", "garanties_souscrites.maintien_deces", "garanties_souscrites.id_contrat",
               "contrats.id_contrat", "contrats.nature_contrat"), "H", "exacte", function() {
    ix <- .index_jointure(ctx, "contrats", "id_contrat", .valeurs(ctx, "garanties_souscrites", "id_contrat"))
    .verdict3(list(code = e3("garanties_souscrites.code_garantie"), maintien = e3("garanties_souscrites.maintien_deces"),
                   manque = .manquant3(ctx, "garanties_souscrites.taux_technique_tarif"),
                   nature = e3("contrats.nature_contrat", index = ix)),
              function(x) {
      deces <- x$code %in% "deces"
      requis <- x$code %in% c("rente_conjoint", "rente_education", "double_effet") | (deces & x$nature %in% "individuel") |
        (deces & !is.na(x$nature) & x$nature != "individuel" & x$maintien %in% TRUE)
      requis & x$manque
    })
  }, mode = "kleene")
  invisible(NULL)
}

# D02a sous H (annexe B du dictionnaire 1.6 ; spécification `donnees` v1.9, § 9.4 ; M510,
# M661, M662, #90) : dates de la table tenues pour inconnues dans la vue, par table et par
# colonne du constat (relations R1 à R13) ; « les deux » dates de la relation, sauf règle
# écrite (R8 : la survenance, la naissance de l'assuré étant portée par .inconnues_d02a() ; R11
# : la seule naissance du membre ; R12 et R13 : la seule date de l'événement).
.DATES_D02A <- list(
  contrats = list(date_fin = c("date_effet", "date_fin"), date_terme = c("date_effet", "date_terme"),
                  date_debut_gestion = c("date_effet", "date_debut_gestion")),
  garanties_souscrites = list(date_fin = c("date_effet", "date_fin")),
  affiliations = list(date_fin = c("date_debut", "date_fin")),
  ayants_droit_sante = list(fin_couverture = c("debut_couverture", "fin_couverture")),
  prestations = list(fin_periode = c("debut_periode", "fin_periode")),
  cotisations = list(fin_periode = c("debut_periode", "fin_periode")),
  sinistres = list(date_survenance = "date_survenance", date_declaration = c("date_survenance", "date_declaration"),
                   date_instruction = c("date_declaration", "date_instruction")),
  famille = list(date_naissance = "date_naissance"),
  evenements = list(date_effet = "date_effet"))
# Types de prestations dont la période manquante relève de D03f (.regle_v_manquants()) : seules
# leurs périodes rejetées (R7) enchaînent D03f ; une autre prestation garde la lecture de Kleene.
.TYPES_PERIODE_D03F <- c("indemnite_journaliere", "arrerage")

# Dates tenues pour inconnues et défauts de manquant enchaînés du constat D02a `k` placé en H
# (.placer()) : `inconnues`, liste de list(table, colonnes, lignes) ; `enchaines`, constats à
# placer comme ceux du défaut qui s'enchaîne (annexe B : D03a pour la naissance de l'assuré, R8,
# et pour celle du membre, R11 ; D03f pour les deux bornes de la période, R7, sur une ligne que
# D03f viserait), sur les seules lignes rejetées, traitement X;H de ce défaut.
.inconnues_d02a <- function(ctx, k) {
  colonnes <- .DATES_D02A[[k$table]][[k$colonne]]
  if (is.null(colonnes)) {
    stop(paste0("erreur interne de provie : .inconnues_d02a() : relation de D02a sans dates (", k$table, ".", k$colonne,
                ")"), call. = FALSE)
  }
  inconnues <- list(list(table = k$table, colonnes = colonnes, lignes = k$lignes))
  enchaines <- list()
  enchainer <- function(code, table, colonne, lignes) {
    if (length(lignes) == 0L) return(invisible(NULL))
    enchaines[[length(enchaines) + 1L]] <<- list(code = code, table = table, colonne = colonne, detection = "exacte",
                                                 traitement = "X;H", lignes = lignes)
  }
  if (k$table == "sinistres" && k$colonne == "date_survenance" && !is.null(ctx$base$assures)) {
    # R8 : naissance de l'assuré inconnue dans toutes ses lectures (fait de la personne à source unique)
    as <- which(!is.na(apparier_cles(.valeurs(ctx, "assures", "id_assure"), .valeurs(ctx, "sinistres", "id_assure")[k$lignes])))
    if (length(as)) inconnues[[2L]] <- list(table = "assures", colonnes = "date_naissance", lignes = as)
    enchainer("D03a", "assures", "date_naissance", as)
  }
  if (k$table == "famille") enchainer("D03a", "famille", "date_naissance", k$lignes)
  if (k$table == "cotisations") enchainer("D03f", "cotisations", NA_character_, k$lignes)
  if (k$table == "prestations") {
    enchainer("D03f", "prestations", NA_character_,
              k$lignes[.valeurs(ctx, "prestations", "type_prestation")[k$lignes] %in% .TYPES_PERIODE_D03F])
  }
  list(inconnues = inconnues, enchaines = enchaines)
}

# Application de D02a sous H à la vue, après le bilan (les règles V et l'enjeu lisent les dates
# brutes ; la visibilité, calculée sur les dates brutes, n'est pas modifiée) : ctx$d02a[[table]]
# [[colonne]] = list(masque, valeur) ; `masque` : lignes dont la date est tenue pour inconnue
# (placement$inconnues) ; `valeur` : date substituée par la règle écrite de R13 (mise à jour
# hors de [survenance, extraction] : dernière information valide précédente, c'est-à-dire la
# date d'effet de la mise_a_jour retenue, de date d'effet non rejetée, de date de saisie
# renseignée strictement antérieure à la sienne, la plus récemment saisie (départage : effet le
# plus tardif), prise pour une mise à jour de niveau dossier parmi celles du même dossier et
# celles de niveau sinistre (sans id_dossier) du même sinistre, pour une mise à jour de niveau
# sinistre parmi celles de niveau sinistre du même sinistre (dictionnaire 1.6, § 4 : « la date
# de dernière information d'un dossier se reconstitue de ces dates » ; une demande_mise_a_jour
# ou un autre type n'en est pas une) ; à défaut l'instruction, à défaut la survenance, lues dans
# la vue), NA sinon. Les exclusions par famille ne sont pas lues. .valeurs_vue() les lit ;
# dates_inconnues_vue() rend les lignes restées inconnues.
.appliquer_d02a <- function(ctx) {
  res <- list()
  for (e in ctx$placement$inconnues) {
    for (c1 in e$colonnes) {
      m <- res[[e$table]][[c1]]$masque
      if (is.null(m)) m <- rep(FALSE, NROW(ctx$base[[e$table]]))
      m[e$lignes] <- TRUE
      res[[e$table]][[c1]] <- list(masque = m, valeur = NULL)
    }
  }
  ctx$d02a <- res
  m <- res$evenements$date_effet$masque
  if (is.null(m)) return(invisible(NULL))
  vv <- function(t, c1) .valeurs_vue(ctx, t, c1)
  type <- vv("evenements", "type_evenement")
  maj <- which(m & type %in% "mise_a_jour")
  valeur <- rep(NA_real_, length(m))
  if (length(maj)) {
    sin <- as.character(vv("evenements", "id_sinistre"))
    dos <- as.character(vv("evenements", "id_dossier"))
    saisie <- as.numeric(vv("evenements", "date_saisie"))
    effet <- as.numeric(vv("evenements", "date_effet"))   # rejetées : NA (masque appliqué) ; non retenues : NA
    valide <- which(type %in% "mise_a_jour" & !is.na(effet) & !is.na(saisie) & cle_renseignee(sin))
    for (i in maj) {
      j <- integer(0)
      if (!is.na(saisie[i]) && cle_renseignee(sin[i])) {
        j <- valide[!is.na(apparier_cles(sin[valide], sin[i])) & saisie[valide] < saisie[i]]
        niveau_sinistre <- !cle_renseignee(dos[j])
        j <- j[niveau_sinistre | (cle_renseignee(dos[i]) & !is.na(apparier_cles(dos[j], dos[i])))]
      }
      if (length(j)) {
        j <- j[order(-saisie[j], -effet[j], method = "radix")][1L]
        valeur[i] <- effet[j]
      }
    }
    reste <- maj[is.na(valeur[maj])]
    if (length(reste)) {
      i_sin <- apparier_cles(sin[reste], vv("sinistres", "id_sinistre"))
      instruction <- as.numeric(vv("sinistres", "date_instruction"))[i_sin]
      survenance <- as.numeric(vv("sinistres", "date_survenance"))[i_sin]
      valeur[reste] <- ifelse(is.na(instruction), survenance, instruction)
    }
  }
  ctx$d02a$evenements$date_effet$valeur <- structure(valeur, class = "Date")
  invisible(NULL)
}

# Lignes de la table `table` (toutes les lignes de la base, retenues ou non) dont la date
# `colonne` est tenue pour inconnue dans la vue `vue` (objet vue_a_date()) par D02a sous H
# (annexe B du dictionnaire 1.6 ; spécification `donnees` v1.9, § 9.4, #90), hors date
# substituée par la règle écrite de R13 : valeurs_vue() y rend NA, qui ne vaut ni fin ouverte,
# ni fait non survenu, ni instruction pendante. Seule lecture de ce statut par les familles de
# calcul (lecture de Kleene : une condition connue décide si elle le peut, sinon le poste est
# arrêté) ; tout FALSE sans D02a placé en H. Sans point : appelée par les familles engagement et
# risque_en_cours ; non exportée.
dates_inconnues_vue <- function(vue, table, colonne) {
  if (!inherits(vue, "vue_provie")) stop("dates_inconnues_vue() : `vue` doit \u00eatre un objet vue_provie", call. = FALSE)
  ctx <- vue$ctx
  d <- ctx$d02a[[table]][[colonne]]
  if (is.null(d)) return(rep(FALSE, NROW(ctx$base[[table]])))
  if (is.null(d$valeur)) d$masque else d$masque & is.na(d$valeur)
}

# Lignes de la table `table` (toutes les lignes de la base, retenues ou non) dont la visibilité
# entière est non déterminée à l'arrêté dans la vue `vue` (objet vue_a_date()) : lignes des
# inscriptions de `ctx$lignes_nd` de cette table et de colonne NA, quel que soit le motif
# (parente_non_determinee compris) ; même source que vue$visibilite_non_determinee
# (.visibilite_non_determinee(), qui en publie les identifiants, dix au plus), sans tronquer.
# Rend un statut, jamais une valeur (E17-1) ; tout FALSE à une vue totale (aucune inscription).
# Lue par `engagement` pour postes_arretes d'une ligne de portée ligne refusée hors de la vue
# (spécification `donnees` v1.9, § 9.2, erratum 1.9.6, (iii) ; #175). Sans point : appelée par
# la famille engagement ; non exportée.
lignes_visibilite_nd_vue <- function(vue, table) {
  if (!inherits(vue, "vue_provie")) {
    stop("lignes_visibilite_nd_vue() : `vue` doit \u00eatre un objet vue_provie", call. = FALSE)
  }
  ctx <- vue$ctx
  res <- rep(FALSE, NROW(ctx$base[[table]]))
  for (k in ctx$lignes_nd) if (identical(k$table, table) && is.na(k$colonne)) res[k$lignes] <- TRUE
  res
}

# Lignes de `table` dont la valeur de `colonne` est refusée par un refus de portée ligne
# (refus R de valeur identifié par ligne sur une colonne non clé, .portee_effective() ;
# spécification `donnees` v1.9, § 9.2, #72), de motif `motif` (NULL : tout motif) : vecteur
# logique sur les lignes de la table, tout FALSE sans tel refus (une valeur inconnue de D03i,
# traitée X, n'en est pas un). La valeur y reste lisible par valeurs_vue() (elle n'est pas
# corrigée) : un lecteur qui la lit pour une de ses unités arrête son poste (règle d'arrêt
# par unité, erratum du projet de dictionnaire 1.6, § 11.5) ; ce sont aussi les lignes de la
# ligne de refus_tables de même table, colonne et motif. Sans point : appelée par les familles
# engagement et risque_en_cours ; non exportée.
lignes_refus_ligne_vue <- function(vue, table, colonne, motif = NULL) {
  if (!inherits(vue, "vue_provie")) stop("lignes_refus_ligne_vue() : `vue` doit \u00eatre un objet vue_provie", call. = FALSE)
  ctx <- vue$ctx
  res <- rep(FALSE, NROW(ctx$base[[table]]))
  for (k in ctx$constats) {
    if (k$traitement != "R" || k$table != table || !identical(k$colonne, colonne) || (!is.null(motif) && k$code != motif)) next
    if (.portee_effective(ctx$dico, k$code, k$table, k$colonne) == "ligne") res[k$lignes] <- TRUE
  }
  res
}

# Table `table` refusée en portée table dans la vue `vue` (objet vue_a_date()), quelle qu'en
# soit la cause (clé, domaine, D04b, refus induit...) : même source que le masquage de la vue
# (`ctx$refus_pv$tables`, .refus_regle_b(), lu par .construire_vue()), et que les lignes de
# vue$bilan$refus_tables de portée `table` de cette table. Rend un statut (TRUE, FALSE) ; à
# une vue totale, la table n'est pas masquée, mais elle reste refusée. Lue par `engagement`
# (.voie_capital() : table `parametres` illisible, voie non déterminée et reconstitution
# possible ; spécification `donnees` v1.9, erratum 1.9.4, (iii) (e) ; #175). Sans point :
# appelée par la famille engagement ; non exportée.
table_refusee_vue <- function(vue, table) {
  if (!inherits(vue, "vue_provie")) stop("table_refusee_vue() : `vue` doit \u00eatre un objet vue_provie", call. = FALSE)
  !is.null(vue$ctx$refus_pv$tables[[table]])
}

# D02a : ordre des dates violé (dictionnaire, § 9), sur la vue ; la colonne du constat est
# la date qui devrait être la plus tardive. Un enfant à naître n'est jamais rejeté.
# Règles V en mode Kleene (#105, lot V, G1 ; spécification `donnees`, erratum `1.9.7`, E-1) :
# verdicts par .verdict3() sur des entrées date (.date3()). Comparaison monotone (x > y) : les
# bornes de la plage de chaque date inconnue (et l'absence d'une date facultative) suffisent,
# même avec deux dates inconnues ; comparaison non monotone (evenements : égalité et intervalle) :
# domaine propre à la ligne, avec les points de rupture (survenance, effet, extraction, et leurs
# voisins d'un jour).
.regle_v_ordre_dates <- function(ctx) {
  vv <- function(table, colonne) .valeurs_vue(ctx, table, colonne)
  apres <- function(x, y) !is.na(x) & !is.na(y) & x > y
  d3 <- function(tc, ...) .date3(ctx, tc, ...)
  jointure <- function(table, cle, valeurs_cle) .index_jointure(ctx, table, cle, valeurs_cle)
  # x > y sur deux dates de la table ; y colonne d'une partie de ligne (sinistres.date_instruction) :
  # lue avec la partie (.partie3()) : connue, comparée ; non connue à l'arrêté, absente ; non
  # déterminée (par exemple, instruction refusée pour sa valeur à un arrêté antérieur), inconnue
  ordre <- function(table, x, y) function() {
    partie <- Filter(function(p) p$table == table && y %in% p$colonnes, .PARTIES_LIGNE)
    e <- list(x = d3(paste(table, x, sep = ".")), y = d3(paste(table, y, sep = ".")))
    if (length(partie) == 0L) return(.verdict3(e, function(v) apres(v$x, v$y)))
    e$connue <- .partie3(ctx, table)
    .verdict3(e, function(v) apres(v$x, ifelse(v$connue, v$y, NA_real_)))
  }
  t <- "X;H"
  # date_debut > date_fin : contrats, versions de garanties, affiliations, ayants droit
  # santé ; termes et début de gestion d'un contrat avant son effet
  # fin d'un contrat ou d'une affiliation, partie de ligne (spécification v1.5, § 2.2 (d)) :
  # partie connue, comparaison ; non connue à l'arrêté (déterminé), faux ; non déterminée,
  # entrée inconnue (.partie3(), inscrite sous la colonne de la date de la partie)
  fin_partie <- function(table, debut) function() {
    .verdict3(list(debut = d3(paste(table, debut, sep = ".")), fin = d3(paste(table, "date_fin", sep = ".")),
                   connue = .partie3(ctx, table)),
              function(v) apres(v$debut, ifelse(v$connue, v$fin, NA_real_)))
  }
  .regle_vue(ctx, "D02a", "contrats", "date_fin", "contrats.date_effet", t, "exacte", fin_partie("contrats", "date_effet"),
             mode = "kleene")
  .regle_vue(ctx, "D02a", "contrats", "date_terme", "contrats.date_effet", t, "exacte",
             ordre("contrats", "date_effet", "date_terme"), mode = "kleene")
  .regle_vue(ctx, "D02a", "contrats", "date_debut_gestion", "contrats.date_effet", t, "exacte",
             ordre("contrats", "date_effet", "date_debut_gestion"), mode = "kleene")
  .regle_vue(ctx, "D02a", "garanties_souscrites", "date_fin", "garanties_souscrites.date_effet", t, "exacte",
             ordre("garanties_souscrites", "date_effet", "date_fin"), mode = "kleene")
  .regle_vue(ctx, "D02a", "affiliations", "date_fin", "affiliations.date_debut", t, "exacte",
             fin_partie("affiliations", "date_debut"), mode = "kleene")
  .regle_vue(ctx, "D02a", "ayants_droit_sante", "fin_couverture", "ayants_droit_sante.debut_couverture", t, "exacte",
             ordre("ayants_droit_sante", "debut_couverture", "fin_couverture"), mode = "kleene")
  # debut_periode > fin_periode
  for (table in c("prestations", "cotisations")) {
    .regle_vue(ctx, "D02a", table, "fin_periode", paste0(table, ".debut_periode"), t, "exacte",
               ordre(table, "debut_periode", "fin_periode"), mode = "kleene")
  }
  # sinistres : naissance de l'assuré après la survenance ; survenance > déclaration >
  # instruction (instruction connue à l'arrêté : partie de ligne lue sur la vue)
  .regle_vue(ctx, "D02a", "sinistres", "date_survenance",
             c("sinistres.id_assure", "assures.id_assure", "assures.date_naissance"), t, "exacte", function() {
    ix <- jointure("assures", "id_assure", vv("sinistres", "id_assure"))
    .verdict3(list(naissance = d3("assures.date_naissance", index = ix), survenance = d3("sinistres.date_survenance")),
              function(v) apres(v$naissance, v$survenance))
  }, mode = "kleene")
  .regle_vue(ctx, "D02a", "sinistres", "date_declaration", "sinistres.date_survenance", t, "exacte",
             ordre("sinistres", "date_survenance", "date_declaration"), mode = "kleene")
  .regle_vue(ctx, "D02a", "sinistres", "date_instruction", "sinistres.date_declaration", t, "exacte",
             ordre("sinistres", "date_declaration", "date_instruction"), mode = "kleene")
  # famille : naissance après la survenance du sinistre rattaché, hors enfant (R11 de l'annexe
  # B du dictionnaire 1.6, M662 : un enfant né après la survenance, déclaré à naître puis né ou
  # saisi directement comme né, n'est pas rejeté, quel que soit le délai ; un enfant à naître
  # n'est jamais rejeté ; spécification `donnees` v1.9, § 9.4, #90)
  .regle_vue(ctx, "D02a", "famille", "date_naissance",
             c("famille.situation", "famille.lien", "famille.id_sinistre", "sinistres.id_sinistre",
               "sinistres.date_survenance"), t,
             "exacte", function() {
    ix <- jointure("sinistres", "id_sinistre", vv("famille", "id_sinistre"))
    .verdict3(list(naissance = d3("famille.date_naissance"), survenance = d3("sinistres.date_survenance", index = ix),
                   situation = .entree3(ctx, "famille.situation"), lien = .entree3(ctx, "famille.lien")),
              function(v) apres(v$naissance, v$survenance) & !(v$situation %in% "a_naitre") & !(v$lien %in% "enfant"))
  }, mode = "kleene")
  # evenements : premier état d'un sinistre (entrée en incapacité ou en invalidité) à une
  # autre date que la survenance ; mise à jour hors de [survenance, extraction]. Verdict non
  # monotone : domaine propre à la ligne (points de rupture)
  .regle_vue(ctx, "D02a", "evenements", "date_effet",
             c("evenements.type_evenement", "evenements.id_sinistre", "sinistres.id_sinistre", "sinistres.date_survenance"),
             t, "exacte", function() {
    ix <- jointure("sinistres", "id_sinistre", vv("evenements", "id_sinistre"))
    extraction <- as.numeric(ctx$date_extraction)
    effet0 <- d3("evenements.date_effet")
    surv0 <- d3("sinistres.date_survenance", index = ix)
    plage_e <- .plage_date3(ctx, "evenements", "date_effet")
    plage_s <- .plage_date3(ctx, "sinistres", "date_survenance")
    voisins <- function(x) c(x - 1, x, x + 1)
    n <- length(effet0$valeurs)
    pts_e <- lapply(seq_len(n), function(l) {
      c(if (surv0$inconnu[l]) voisins(plage_s) else voisins(surv0$valeurs[l]), voisins(extraction))
    })
    pts_s <- lapply(seq_len(n), function(l) if (effet0$inconnu[l]) voisins(c(plage_e, extraction)) else voisins(effet0$valeurs[l]))
    .verdict3(list(type = .entree3(ctx, "evenements.type_evenement"),
                   effet = d3("evenements.date_effet", points_ligne = pts_e),
                   survenance = d3("sinistres.date_survenance", index = ix, points_ligne = pts_s)),
              function(v) {
      premier <- v$type %in% c("entree_incapacite", "entree_invalidite") & !is.na(v$effet) & !is.na(v$survenance) &
        v$effet != v$survenance
      maj <- v$type %in% "mise_a_jour" & !is.na(v$effet) & !is.na(v$survenance) &
        (v$effet < v$survenance | v$effet > extraction)
      premier | maj
    })
  }, mode = "kleene")
  invisible(NULL)
}


# D01b : doublon de contenu (identifiants distincts, mêmes valeurs des colonnes du § 9), sur
# la vue ; traitement S + X (« signalé dans tous les cas », § 9) : deux constats de même clé
# (code, table, colonne), un par traitement, comme D10 (b). La copie est la ligne saisie après l'original (date qui gouverne la visibilité,
# puis clé primaire en tri radix) : seules les copies sont comptées, comme pour D01a ; la clé
# primaire lue est la première colonne de la clé (identifiant de la ligne).
.CONTENUS_D01B <- list(
  sinistres = c("id_assure", "nature_sinistre", "date_survenance"),
  dossiers = c("id_sinistre", "id_garantie_souscrite"),
  evenements = c("id_sinistre", "id_dossier", "id_rente", "type_evenement", "date_effet"),
  prestations = c("id_dossier", "id_rente", "type_prestation", "nature_mouvement", "date_reglement", "debut_periode",
                  "fin_periode", "montant"),
  cotisations = c("id_garantie_souscrite", "nature_mouvement", "debut_periode", "fin_periode", "montant"))

.regle_v_doublons <- function(ctx) {
  for (table in names(.CONTENUS_D01B)) {
    colonnes <- .CONTENUS_D01B[[table]]
    date <- .DATES_VISIBILITE[[table]][1L]
    cle <- eclater_champ(ctx$dico$tables$cle_primaire[ctx$dico$tables$table == table])[1L]
    copies <- function() .copies3(ctx, table, colonnes, date, cle, copies_brut())
    copies_brut <- function() {
      retenu <- ctx$retenu[[table]]
      o <- order(as.numeric(.valeurs(ctx, table, date)), .valeurs(ctx, table, cle), method = "radix", na.last = TRUE)
      o <- o[retenu[o]]
      contenu <- as.data.frame(lapply(colonnes, function(c1) .valeurs(ctx, table, c1)[o]), stringsAsFactors = FALSE)
      # une ligne de même clé que la précédente est un doublon d'identifiant (D01a), non une
      # copie sous un nouvel identifiant ; deux clés manquantes y sont égales (duplicated()),
      # alors que `precedes` ci-dessous, entrée existentielle, suit la règle de la clé manquante
      # (spécification `donnees` v1.6, § 2.2, B.4) : écart inatteignable, une clé primaire
      # manquante ou en double refusant la table en portée table, sans règle V (#56)
      meme_cle <- duplicated(data.frame(contenu, .cle = .valeurs(ctx, table, cle)[o], stringsAsFactors = FALSE))
      copie <- rep(FALSE, length(retenu))
      copie[o[duplicated(contenu) & !meme_cle]] <- TRUE
      # lignes non déterminées (spécification v1.5, § 2.2 (d)) : une ligne qu'aucune ligne visible
      # ne précède est de verdict inconnu si une ligne non déterminée de même contenu peut la
      # précéder (ordre connu antérieur, ou date de visibilité absente ou inconnue : placée en
      # tête) ; toutes dans la vue ainsi placées, chaque ligne a ses prédécesseurs possibles
      nd <- .nd_vue(ctx, table)
      if (!any(nd)) return(copie)
      date_o <- as.numeric(.valeurs(ctx, table, date))
      date_o[nd & (is.na(date_o) | .inconnu(ctx, table, date))] <- -Inf
      o2 <- order(date_o, .valeurs(ctx, table, cle), method = "radix", na.last = TRUE)
      o2 <- o2[retenu[o2] | nd[o2]]
      # contenu en clé exacte (nombres et dates en hexadécimal, sans arrondi)
      exacte <- function(x) ifelse(is.na(x), "\001", if (is.numeric(x) || inherits(x, "Date")) sprintf("%a", as.numeric(x))
                                   else paste0("=", x))
      groupe <- do.call(paste, c(lapply(colonnes, function(c1) exacte(.valeurs(ctx, table, c1)[o2])), sep = "\r"))
      groupe <- match(groupe, groupe)
      possible <- rep(FALSE, length(retenu))
      possible[o2[duplicated(groupe)]] <- TRUE
      l <- which(retenu & !copie & possible)
      if (length(l) == 0L) return(copie)
      # lignes non déterminées de chaque groupe de contenu, dans l'ordre o2 (un passage) ; une
      # ligne écartée ne lit que celles de son groupe qui la précèdent (travail linéaire), hors
      # celles de même clé (un doublon d'identifiant, D01a, non une copie, comme `meme_cle`) ;
      # une ligne que seule précède une ligne retenue de même clé n'en a aucune : elle reste
      # non détectée (#56, point 2)
      rang <- match(seq_along(retenu), o2)
      pos_nd <- which(nd[o2])
      nd_groupe <- split(pos_nd, groupe[pos_nd])
      cles <- .valeurs(ctx, table, cle)
      precedes <- Map(function(q, r, i) {
        p <- o2[q[q < r]]
        p[is.na(cles[p]) | is.na(cles[i]) | cles[p] != cles[i]]
      }, nd_groupe[match(groupe[rang[l]], as.integer(names(nd_groupe)))], rang[l], l)
      garde <- lengths(precedes) > 0L
      if (!any(garde)) return(copie)
      l <- l[garde]
      index <- vector("list", length(retenu))
      index[l] <- precedes[garde]
      copie[l] <- NA
      attr(copie, "index") <- stats::setNames(list(index), table)
      copie
    }
    for (t in c("S", "X")) {
      .regle_vue(ctx, "D01b", table, NA_character_, paste(table, c(colonnes, date, cle), sep = "."), t, "exacte", copies,
                 mode = "kleene")
    }
  }
  invisible(NULL)
}

# D01b à trois valeurs (#105, lot V, G1 ; spécification `donnees`, erratum `1.9.7`, E-1) :
# `r` est le verdict sur les valeurs brutes (copies_brut de .regle_v_doublons(), lignes non
# déterminées comprises), gardé pour toute ligne qu'aucune valeur inconnue ne touche. Une
# cellule de contenu ou de date de visibilité refusée pour sa valeur (ou de D03i) est inconnue,
# de domaine fini : les valeurs des lignes candidates pour la colonne et une valeur neuve
# (l'absence aussi pour une colonne facultative) ; une date inconnue précède ou suit toute
# autre (bornes de sa plage). La ligne l est une copie s'il existe une ligne retenue p, d'autre
# clé, qui la précède et lui est égale sur le contenu : conjonction de conditions sur des
# cellules distinctes (Kleene exact), puis disjonction sur les p, exacte car une affectation
# (valeurs neuves, dates aux bornes) rend toutes les paires fausses à la fois. Lignes
# recalculées : celles qui portent une inconnue et celles compatibles avec une ligne (retenue
# ou non déterminée) qui en porte une. Sans paire possible, la règle des lignes non
# déterminées (v1.5, § 2.2 (d)) s'applique avec l'égalité à trois valeurs. Entrées pertinentes
# (index_pertinent) : cellules inconnues des paires inconnues (colonne de la cellule), lignes non
# déterminées qui peuvent précéder (clé de la table) ; `lues` : contenu et date.
.copies3 <- function(ctx, table, colonnes, date, cle, r) {
  index <- attr(r, "index", exact = TRUE)
  ip <- if (is.null(index)) list() else index
  cols <- c(colonnes, date)
  tcs <- paste(table, cols, sep = ".")
  sortie <- function(r, ip) {
    attr(r, "index_pertinent") <- ip
    attr(r, "lues") <- tcs
    r
  }
  n <- length(ctx$retenu[[table]])
  if (n == 0L) return(sortie(r, ip))
  inc <- vapply(cols, function(c1) .inconnu(ctx, table, c1), logical(n))
  if (n == 1L) inc <- matrix(inc, nrow = 1L)
  retenu <- ctx$retenu[[table]]
  nd <- .nd_vue(ctx, table)
  porteuses <- which((retenu | nd) & rowSums(inc) > 0L)
  if (length(porteuses) == 0L) return(sortie(r, ip))
  exacte <- function(x) ifelse(is.na(x), "\001", if (is.numeric(x) || inherits(x, "Date")) sprintf("%a", as.numeric(x))
                               else paste0("=", x))
  code <- vapply(cols, function(c1) exacte(.valeurs(ctx, table, c1)), character(n))
  if (n == 1L) code <- matrix(code, nrow = 1L)
  obligatoire <- vapply(cols, function(c1) .obligatoire3(ctx, table, c1), NA)
  cles <- .valeurs(ctx, table, cle)
  rang <- match(seq_len(n), order(as.numeric(.valeurs(ctx, table, date)), cles, method = "radix", na.last = TRUE))
  date_nd <- is.na(as.numeric(.valeurs(ctx, table, date))) | inc[, length(cols)]
  # égalité de contenu à trois valeurs entre la ligne l et les lignes `p` (matrice : une ligne par p)
  egalite <- function(p, l) {
    k <- seq_along(colonnes)
    eq <- matrix(NA, length(p), length(k))
    for (j in k) {
      connues <- !inc[p, j] & !inc[l, j]
      eq[connues, j] <- code[p[connues], j] == code[l, j]
      # une inconnue d'une colonne obligatoire n'est jamais absente
      if (obligatoire[j]) {
        eq[inc[p, j] & !inc[l, j] & code[l, j] == "\001", j] <- FALSE
        eq[!inc[p, j] & inc[l, j] & code[p, j] == "\001", j] <- FALSE
      }
    }
    eq
  }
  compatibles <- function(l, candidats) {
    candidats <- candidats[candidats != l & (is.na(cles[candidats]) | is.na(cles[l]) | cles[candidats] != cles[l])]
    if (length(candidats) == 0L) return(candidats)
    eq <- egalite(candidats, l)
    candidats[!apply(eq, 1L, function(z) any(z %in% FALSE))]
  }
  touchees <- which(retenu & rowSums(inc) > 0L)
  for (u in porteuses) touchees <- c(touchees, compatibles(u, which(retenu)))
  touchees <- sort(unique(touchees))
  if (is.null(index)) index <- list()
  if (is.null(index[[table]])) index[[table]] <- vector("list", n)
  if (is.null(ip[[table]])) ip[[table]] <- vector("list", n)
  ajouter <- function(ip, tc, l, lignes) {
    if (is.null(ip[[tc]])) ip[[tc]] <- vector("list", n)
    ip[[tc]][l] <- list(sort(unique(c(ip[[tc]][[l]], lignes))))
    ip
  }
  for (l in touchees) {
    ip[[table]][l] <- list(NULL)
    index[[table]][l] <- list(NULL)
    for (tc in tcs) if (!is.null(ip[[tc]])) ip[[tc]][l] <- list(NULL)
    p <- compatibles(l, which(retenu))
    verdict <- FALSE
    if (length(p) > 0L) {
      eq <- egalite(p, l)
      pre <- ifelse(inc[p, length(cols)] | inc[l, length(cols)], NA, rang[p] < rang[l])
      paire <- ifelse(pre %in% FALSE, FALSE, ifelse(rowSums(is.na(eq)) == 0L & pre %in% TRUE, TRUE, NA))
      if (any(paire %in% TRUE)) verdict <- TRUE else if (any(is.na(paire))) {
        verdict <- NA
        for (q in which(is.na(paire))) {
          for (j in which(is.na(eq[q, ]))) ip <- ajouter(ip, tcs[j], l, c(p[q], l)[c(inc[p[q], j], inc[l, j])])
          if (is.na(pre[q])) ip <- ajouter(ip, tcs[length(cols)], l, c(p[q], l)[c(inc[p[q], length(cols)], inc[l, length(cols)])])
        }
      }
    }
    if (!isTRUE(verdict)) {
      # lignes non déterminées de même contenu possible, qui peuvent précéder l
      q <- compatibles(l, which(nd))
      if (length(q) > 0L) q <- q[date_nd[q] | inc[l, length(cols)] | rang[q] < rang[l]]
      if (length(q) > 0L) {
        verdict <- NA
        ip[[table]][l] <- list(q)
        index[[table]][l] <- list(q)
        eq <- egalite(q, l)
        for (j in seq_along(colonnes)) {
          a <- which(is.na(eq[, j]))
          if (length(a) > 0L) ip <- ajouter(ip, tcs[j], l, c(q[a][inc[q[a], j]], if (inc[l, j]) l))
        }
      }
    }
    r[l] <- verdict
  }
  attr(r, "index") <- index
  sortie(r, ip)
}

# Clôtures et instruction : D05, D06, D13 (dictionnaire, § 9), sur la vue.
.regle_v_clotures <- function(ctx) {
  vv <- function(table, colonne) .valeurs_vue(ctx, table, colonne)
  type <- function() vv("evenements", "type_evenement")
  motif <- function() vv("evenements", "motif")
  # D05 : sortie ou clôture au motif manquant, sans prestation sur aucun dossier du
  # sinistre ; D05 sur la vue, sauf les lignes déjà refusées par manquant_obligatoire en
  # règle B (motif manquant avec une prestation du sinistre dans la base entière) : la vue
  # étant incluse dans la base, l'absence de prestation se lit sur la base entière ; « payé »
  # a une seule définition, celle de la règle B (clé du sinistre connue et appariée ; une chaîne
  # vide vaut clé manquante, apparier_cles(), #123, #158)
  .regle_vue(ctx, "D05", "evenements", "motif",
             c("evenements.type_evenement", "evenements.id_sinistre", "prestations.id_dossier", "dossiers.id_dossier",
               "dossiers.id_sinistre"), "H;S", "exacte", function() {
    # règle V en mode Kleene (#105, lot V, G1) : type et motif à trois valeurs (.entree3() ; un
    # motif refusé non vide peut être absent, colonne facultative)
    payes <- unique(.joindre(ctx, "dossiers", "id_dossier", "id_sinistre", .valeurs(ctx, "prestations", "id_dossier")))
    paye <- !is.na(apparier_cles(vv("evenements", "id_sinistre"), payes))
    .verdict3(list(type = .entree3(ctx, "evenements.type_evenement"), motif = .entree3(ctx, "evenements.motif"),
                   paye = .connue3("evenements.id_sinistre", paye)),
              function(x) x$type %in% c("sortie", "cloture_dossier") & is.na(x$motif) & !x$paye)
  }, mode = "kleene")
  # D06 : clôture sans justificatif ; clôture `regle` sans prestation du dossier, ou
  # `depot_cdc` sans prestation `capital` (prestations visibles à l'arrêté). Règle V en mode
  # Kleene (#105, lot V, G2a) : type, motif et justificatif de l'événement à trois valeurs ;
  # « il existe une prestation du dossier » et « il existe une prestation capital du dossier »
  # par .ou3() : prestation retenue (vraie), non déterminée (présente ou non, clé prestations),
  # type refusé (capital ou non, clé prestations.type_prestation)
  .regle_vue(ctx, "D06", "evenements", "justificatif",
             c("evenements.type_evenement", "evenements.motif", "evenements.id_dossier", "prestations.id_dossier",
               "prestations.type_prestation"), "H;S", "exacte", function() {
    dossier <- vv("evenements", "id_dossier")
    n <- length(dossier)
    retenu <- ctx$retenu$prestations
    nd <- .nd_vue(ctx, "prestations")
    brut <- .valeurs(ctx, "prestations", "id_dossier")
    type_p <- .valeurs(ctx, "prestations", "type_prestation")
    type_u <- .inconnu(ctx, "prestations", "type_prestation")
    # prestations candidates de chaque événement, comme la règle bloquée : sans prestation non
    # déterminée, retenues de même clé (une clé "" s'apparie à "", #164) ; avec, retenues et non
    # déterminées par la règle de la clé manquante (.existe_kleene(), #123, #158)
    avec_nd <- any(nd)
    cle_p <- if (avec_nd) .cle_manquante(as.character(brut)) else as.character(brut)
    cle_ev <- if (avec_nd) .cle_manquante(as.character(dossier)) else as.character(dossier)
    # paires (événement, prestation candidate) ; la clé "" garde son appariement sans prestation
    # non déterminée (valeur témoin hors de toute clé)
    if (!avec_nd) {
      cle_p[cle_p %in% ""] <- "\001"
      cle_ev[cle_ev %in% ""] <- "\001"
    }
    cle_p[!(retenu | nd)] <- NA
    pr <- .paires(cle_ev, cle_p)
    k <- pr$j
    v_nd <- ifelse(nd[k], paste("prestations", k, sep = "\r"), NA_character_)
    v_ty <- ifelse(type_u[k], paste("prestations.type_prestation", k, sep = "\r"), NA_character_)
    sans_na <- function(x) x[!is.na(x)]
    tout <- .ou3(n, pr$i, rep(FALSE, length(k)), lapply(seq_along(k), function(z) sans_na(v_nd[z])))
    cap <- .ou3(n, pr$i, !type_u[k] & !(type_p[k] %in% "capital"), lapply(seq_along(k), function(z) sans_na(c(v_nd[z], v_ty[z]))))
    r <- .verdict3(list(type = .entree3(ctx, "evenements.type_evenement"), motif = .entree3(ctx, "evenements.motif"),
                        manque = .manquant3(ctx, "evenements.justificatif"), tout = .entree_ou3("tout", tout),
                        cap = .entree_ou3("cap", cap)), function(x) {
      sj <- x$manque & ((x$type %in% "sortie" & x$motif %in% c("reprise_travail", "deces")) |
                          (x$type %in% "fin_service" & x$motif %in% "deces_beneficiaire"))
      clot <- x$type %in% "cloture_dossier"
      sj | (clot & x$motif %in% "regle" & !x$tout) | (clot & x$motif %in% "depot_cdc" & !x$cap)
    })
    .eclater3(r, c("tout", "cap"), list(tout, cap), c("prestations.id_dossier", "prestations.type_prestation"))
  }, vue = ctx$lit_vue$prestations, mode = "kleene")
  # D13 : instruction absente (à l'arrêté) d'un sinistre décès dont le dossier `deces` a une
  # prestation `capital` visible. Règle V en mode Kleene (#105, lot V, G2a) : nature et
  # instruction (partie de ligne, .partie3()) à trois valeurs ; « il existe une prestation capital
  # d'un dossier deces du sinistre » par .ou3() : type de la prestation (clé
  # prestations.type_prestation), code de la garantie du dossier, partagé par ses prestations (clé
  # garanties_souscrites.code_garantie), prestation non déterminée (clé prestations)
  .regle_vue(ctx, "D13", "sinistres", "date_instruction",
             c("sinistres.nature_sinistre", "sinistres.id_sinistre", "dossiers.id_dossier", "dossiers.id_sinistre",
               "dossiers.id_garantie_souscrite", "garanties_souscrites.id_garantie_souscrite",
               "garanties_souscrites.code_garantie", "prestations.id_dossier", "prestations.type_prestation"),
             "H;S", "exacte", function() {
    n <- NROW(ctx$base$sinistres)
    retenu <- ctx$retenu$prestations
    nd <- .nd_vue(ctx, "prestations")
    brut <- .valeurs(ctx, "prestations", "id_dossier")
    type_p <- .valeurs(ctx, "prestations", "type_prestation")
    type_u <- .inconnu(ctx, "prestations", "type_prestation")
    gs <- .joindre(ctx, "dossiers", "id_dossier", "id_garantie_souscrite", brut)
    ig <- .index_jointure(ctx, "garanties_souscrites", "id_garantie_souscrite", gs)
    code <- .valeurs(ctx, "garanties_souscrites", "code_garantie")[ig]
    code_u <- !is.na(ig) & .inconnu(ctx, "garanties_souscrites", "code_garantie")[ig]
    sin <- apparier_cles(.joindre(ctx, "dossiers", "id_dossier", "id_sinistre", brut), .valeurs(ctx, "sinistres", "id_sinistre"))
    k <- which((retenu | nd) & !is.na(sin))
    ou <- .ou3(n, sin[k], (!type_u[k] & !(type_p[k] %in% "capital")) | (!code_u[k] & !(code[k] %in% "deces")),
               lapply(k, function(z) c(if (nd[z]) paste("prestations", z, sep = "\r"),
                                       if (type_u[z]) paste("prestations.type_prestation", z, sep = "\r"),
                                       if (code_u[z]) paste("garanties_souscrites.code_garantie", ig[z], sep = "\r"))))
    r <- .verdict3(list(nature = .entree3(ctx, "sinistres.nature_sinistre"), instruction = .date3(ctx, "sinistres.date_instruction"),
                        connue = .partie3(ctx, "sinistres"), paye = .entree_ou3("paye", ou)), function(x) {
      x$nature %in% "deces" & (!x$connue | is.na(x$instruction)) & x$paye
    })
    .eclater3(r, "paye", list(ou), c("prestations.id_dossier", "prestations.type_prestation", "garanties_souscrites.code_garantie"))
  }, vue = ctx$lit_vue$prestations, mode = "kleene")
  invisible(NULL)
}

# Incohérences entre garanties D10 (b) et (c) (dictionnaire, § 9), sur la vue.
.regle_v_garanties <- function(ctx) {
  vv <- function(table, colonne) .valeurs_vue(ctx, table, colonne)
  lit_gs <- c("dossiers.id_garantie_souscrite", "garanties_souscrites.id_garantie_souscrite")
  # D10 (b) : version de garantie hors vigueur à la survenance ; traitement S + X : deux
  # constats de même clé (code, table, colonne), un par traitement (réserve m3). Évalué aussi sur
  # un dossier de la vue dont la garantie souscrite est invisible à l'arrêté (exception de la
  # règle 1, .liens_regle1() ; dictionnaire 1.6, § 6 et § 9 ; spécification `donnees` v1.9,
  # § 9.3 (1), #83) : la garantie est lue à sa valeur extraite, sur toutes les occurrences de sa
  # clé (.jointe3(), lecture existentielle de .joindre3(), M663) : dates inconnues si elles
  # divergent (cause candidate D01a). Chemin non atteignable aujourd'hui : une clé de
  # garanties_souscrites en double est un refus D01a (R) de portée table, qui bloque la règle
  # avant la lecture (C83-5) ; .jointe3() y rend alors les mêmes valeurs que .joindre(), d'où
  # aucun test qui les distingue. Cause de la ligne écartée dans le chemin V : #169.
  # Règle V en mode Kleene (#105, lot V, G2a) : survenance, effet et fin à trois valeurs
  # (.date3()) ; « hors vigueur » est monotone en l'effet et en la fin (bornes de leur plage, et
  # l'absence de la fin), à deux côtés en la survenance : domaine propre à la ligne, points de
  # rupture (effet et fin, ou les bornes de leur plage, la veille et le lendemain)
  hors_vigueur <- function() {
    gs <- vv("dossiers", "id_garantie_souscrite")
    ix_g <- .index_jointure(ctx, "garanties_souscrites", "id_garantie_souscrite", gs)
    ix_s <- .index_jointure(ctx, "sinistres", "id_sinistre", vv("dossiers", "id_sinistre"))
    effet0 <- .date3(ctx, "garanties_souscrites.date_effet", index = ix_g)
    fin0 <- .date3(ctx, "garanties_souscrites.date_fin", index = ix_g)
    voisins <- function(x) c(x - 1, x, x + 1)
    plage_e <- .plage_date3(ctx, "garanties_souscrites", "date_effet")
    plage_f <- .plage_date3(ctx, "garanties_souscrites", "date_fin")
    pts <- lapply(seq_along(gs), function(l) {
      c(voisins(if (effet0$inconnu[l]) plage_e else effet0$valeurs[l]), voisins(if (fin0$inconnu[l]) plage_f else fin0$valeurs[l]))
    })
    .verdict3(list(survenance = .date3(ctx, "sinistres.date_survenance", index = ix_s, points_ligne = pts), effet = effet0,
                   fin = fin0), function(x) {
      s1 <- as.numeric(x$survenance)
      e <- as.numeric(x$effet)
      f <- as.numeric(x$fin)
      !is.na(s1) & !is.na(e) & (s1 < e | (!is.na(f) & s1 > f))
    })
  }
  lit_b <- c(lit_gs, "garanties_souscrites.date_effet", "garanties_souscrites.date_fin", "dossiers.id_sinistre",
             "sinistres.id_sinistre", "sinistres.date_survenance")
  for (t in c("S", "X")) .regle_vue(ctx, "D10b", "dossiers", "id_garantie_souscrite", lit_b, t, "exacte", hors_vigueur,
                                    mode = "kleene")
  # D10 (c) : dossier de rente ou de double effet sans dossier `deces` du même sinistre (dans
  # la vue) alors que la garantie décès est souscrite : garantie `deces` du même contrat et
  # du même collège que la garantie du dossier, dans une version en vigueur à la survenance
  # et retenue dans la vue
  # Règle V en mode Kleene (#105, lot V, G2b, M810) : arbre par dossier (.arbre3()), « vise » (code
  # de la garantie du dossier) ET « décès souscrit » (.garantie_en_vigueur3() à trois valeurs :
  # versions de même contrat et collège que la garantie du dossier, survenance) ET NON « dossier
  # `deces` du même sinistre dans la vue » (dossiers retenus ou non déterminés, code de leur
  # garantie) ; la cellule de code de la garantie du dossier, lue par « vise » et comme version
  # candidate de « décès souscrit », est conditionnée, comme la survenance et toute cellule lue par
  # deux feuilles (D-G2-2) ; pertinence exacte (.arbre3()).
  lit_c10 <- c(lit_gs, "dossiers.id_sinistre", "sinistres.id_sinistre", "sinistres.date_survenance",
               paste0("garanties_souscrites.", c("code_garantie", "id_contrat", "college", "date_effet", "date_fin")))
  .regle_vue(ctx, "D10c", "dossiers", NA_character_, lit_c10, "S", "exacte", function() {
    .verdict_d10c(ctx, lit_c10)
  }, vue = ctx$lit_vue$garanties_souscrites, mode = "kleene")
  # D10 (d) : passage_invalidite dont le sinistre n'a, pour aucun (contrat, collège) de ses
  # dossiers de la vue, de version de garantie invalidite en vigueur à la survenance
  # (.garantie_en_vigueur3()) ; sinistre sans dossier dans la vue : contrats qui couvrent la
  # survenance (.couverture3()), dont une version invalidite est en vigueur à la survenance, de
  # même (id_contrat, college) que l'affiliation qui couvre, de même contrat (tout collège) pour
  # un contrat individuel (réserve R1 d'actuary, jugement d'expert : même clé que le cas avec
  # dossier, clé étrangère composite de affiliations.college) ; aucun contrat : détecté
  # (spécification `donnees` v1.6, § 8.4). Traitement S, constat sur evenements, colonne NA.
  # Verdict à trois valeurs : dossier, version, affiliation ou contrat de visibilité non
  # déterminée qui peut changer la couverture. Les colonnes de la
  # couverture ne sont lues que si un passage de la vue (retenu ou non déterminé) n'a aucun
  # dossier retenu (clés illisibles : lues).
  lit_d <- c("evenements.type_evenement", "evenements.id_sinistre", "sinistres.id_sinistre", "sinistres.date_survenance",
             "dossiers.id_sinistre", lit_gs,
             paste0("garanties_souscrites.", c("code_garantie", "id_contrat", "college", "date_effet", "date_fin")))
  lit_c <- c("sinistres.id_assure", paste0("affiliations.", c("id_assure", "id_contrat", "college", "date_debut", "date_fin")),
             paste0("contrats.", c("id_contrat", "nature_contrat", "id_assure", "date_effet", "date_fin", "date_terme")))
  lit_c <- lit_c[sub("\\..*$", "", lit_c) %in% names(ctx$base)]
  cles_d <- c("evenements.type_evenement", "evenements.id_sinistre", "dossiers.id_sinistre")
  # type refusé : passage possible ; clé illisible par une cause de forme ou de portée table
  # seulement (#105, lot V, G2b)
  sans_dossier <- !is.null(.cause_hors_valeur(ctx, cles_d)) || {
    passage <- (.valeurs(ctx, "evenements", "type_evenement") %in% "passage_invalidite" | .inconnu(ctx, "evenements", "type_evenement")) &
      (ctx$retenu$evenements | .nd_vue(ctx, "evenements"))
    any(passage & is.na(apparier_cles(.valeurs(ctx, "evenements", "id_sinistre"), vv("dossiers", "id_sinistre"))))
  }
  # Règle V en mode Kleene (#105, lot V, G2b, M810) : arbre par passage (.verdict_d10d())
  lit_dd <- c(lit_d, if (sans_dossier) lit_c)
  .regle_vue(ctx, "D10d", "evenements", NA_character_, lit_dd, "S", "exacte", function() .verdict_d10d(ctx, lit_dd),
             vue = c(ctx$lit_vue$dossiers, ctx$lit_vue$garanties_souscrites, if (sans_dossier) c(ctx$lit_vue$affiliations, ctx$lit_vue$contrats)),
             mode = "kleene")
  invisible(NULL)
}

# Versions de garanties_souscrites (retenues ou de visibilité non déterminée) qui lisent une cellule
# inconnue ou sont non déterminées (#105, lot V, G2b) : code, collège, dates d'effet et de fin,
# conjoint_vise, prolongation_handicap, valeur refusée d'un de leurs paramètres ; `contrats` : leurs
# contrats (clés renseignées). Délimite le chemin rapide (lecture brute) des règles D10 (c), D10 (d)
# et D14 : un élément dont aucune version candidate n'en est relève de la lecture brute.
.inconnues_versions3 <- function(ctx) {
  t <- "garanties_souscrites"
  u <- function(c1) if (c1 %in% names(ctx$base[[t]])) .inconnu(ctx, t, c1) else rep(FALSE, NROW(ctx$base[[t]]))
  nd <- .nd_vue(ctx, t)
  inc <- (ctx$retenu[[t]] | nd) & (nd | u("code_garantie") | u("college") | u("date_effet") | u("date_fin") |
                                     u("conjoint_vise") | u("prolongation_handicap"))
  if (!is.null(ctx$base$parametres)) {
    k <- which(.inconnu(ctx, "parametres", "valeur"))
    gs_id <- as.character(.valeurs(ctx, t, "id_garantie_souscrite"))
    inc <- inc | (!is.na(apparier_cles(gs_id, .valeurs(ctx, "parametres", "id_garantie_souscrite")[k])))
  }
  contrats <- unique(.cle_manquante(as.character(.valeurs(ctx, t, "id_contrat")))[inc])
  list(lignes = inc, contrats = contrats[!is.na(contrats)])
}

# Verdict à trois valeurs de D10 (c) (.regle_v_garanties() ; #105, lot V, G2b) : lecture brute de
# la règle du mode bloquee (.gev_brut()) sur les dossiers qui ne lisent aucune cellule inconnue ni
# ligne de visibilité non déterminée (code, survenance et collège de leur garantie, versions de leur
# contrat, .inconnues_versions3(), dossiers du même sinistre) ; un arbre évalué par .arbre3() sur
# les autres dossiers retenus dont la garantie peut viser une rente ou un double effet. Rend le
# vecteur logique (NA : inconnu) et ses attributs `index_pertinent` et `lues` (colonnes lues,
# statiques : garde de .regle_vue()). `forcer` (contrôle des tests) : chemin rapide désactivé, tout
# dossier par .arbre3() ; hors des lignes complexes, une lecture brute indéterminée est une erreur
# interne (garde du chemin rapide ; de même pour D10 (d) et D14).
.verdict_d10c <- function(ctx, lues, forcer = FALSE) {
  t <- "garanties_souscrites"
  n <- NROW(ctx$base$dossiers)
  ig <- .index_jointure(ctx, t, "id_garantie_souscrite", .valeurs(ctx, "dossiers", "id_garantie_souscrite"))
  ks <- .index_jointure(ctx, "sinistres", "id_sinistre", .valeurs(ctx, "dossiers", "id_sinistre"))
  cel <- function(table, c1, l) ifelse(!is.na(l) & .inconnu(ctx, table, c1)[ifelse(is.na(l), 1L, l)],
                                      paste0(table, ".", c1, "\r", l), NA_character_)
  code_v <- .valeurs(ctx, t, "code_garantie")
  code_g <- code_v[ig]
  code_id <- cel(t, "code_garantie", ig)
  surv <- as.numeric(.valeurs(ctx, "sinistres", "date_survenance"))[ks]
  surv_id <- cel("sinistres", "date_survenance", ks)
  college_id <- cel(t, "college", ig)
  dom_code <- .domaine3(ctx, t, "code_garantie")
  rentes <- c("rente_conjoint", "rente_education", "double_effet")
  vise <- !is.na(code_id) | code_g %in% rentes
  # chemin rapide (lecture brute, exacte) : dossiers qui ne lisent aucune cellule inconnue ni ligne
  # de visibilité non déterminée ; les autres dossiers de la vue relèvent de .arbre3()
  vv <- function(table, colonne) .valeurs_vue(ctx, table, colonne)
  joindre_gs <- function(colonne, gs) .joindre(ctx, t, "id_garantie_souscrite", colonne, gs)
  gs_v <- vv("dossiers", "id_garantie_souscrite")
  code_b <- joindre_gs("code_garantie", gs_v)
  sinistre <- vv("dossiers", "id_sinistre")
  avec_deces <- sinistre[code_b %in% "deces"]
  vise_b <- code_b %in% rentes
  sous_b <- .gev_brut(ctx, "deces", list(contrat = joindre_gs("id_contrat", gs_v), college = joindre_gs("college", gs_v)),
                      as.numeric(.joindre(ctx, "sinistres", "id_sinistre", "date_survenance", sinistre)), vise_b, TRUE)
  r <- vise_b & sous_b$valeurs & !(sinistre %in% avec_deces[!is.na(avec_deces)])
  inc_v <- .inconnues_versions3(ctx)
  nd_d <- .nd_vue(ctx, "dossiers")
  dans <- ctx$retenu$dossiers | nd_d
  sin_k <- .cle_manquante(as.character(.valeurs(ctx, "dossiers", "id_sinistre")))
  sin_inc <- unique(sin_k[dans & (nd_d | !is.na(code_id))])
  complexe <- ctx$retenu$dossiers & vise &
    (forcer | !is.na(code_id) | !is.na(surv_id) | !is.na(college_id) |
       .cle_manquante(as.character(.valeurs(ctx, t, "id_contrat")[ig])) %in% inc_v$contrats |
       (!is.na(sin_k) & sin_k %in% sin_inc[!is.na(sin_inc)]))
  # garde du chemin rapide : hors des lignes complexes, la lecture brute est déterminée
  if (any(ctx$retenu$dossiers & !complexe & lengths(sous_b$index) > 0L)) {
    stop("erreur interne de provie : D10c : lecture brute ind\u00e9termin\u00e9e hors du chemin \u00e0 trois valeurs", call. = FALSE)
  }
  r[complexe] <- FALSE
  g <- .garantie_en_vigueur3(ctx, "deces", list(contrat = .valeurs(ctx, t, "id_contrat")[ig], college = .valeurs(ctx, t, "college")[ig]),
                             surv, complexe, inconnues = list(survenance = surv_id, college = college_id))
  feuille_code <- function(l, codes) {
    c_id <- code_id[l]
    .feuille3(c_id, function(sigs) stats::setNames(list(dom_code), c_id), function(a, n) .val3(a, c_id, code_g[l], n) %in% codes)
  }
  ip <- list()
  for (l in which(complexe)) {
    autres <- which(dans & !is.na(sin_k) & sin_k %in% sin_k[l])
    deces <- lapply(autres, function(d) {
      fc <- feuille_code(d, "deces")
      if (!nd_d[d] || ctx$retenu$dossiers[d]) return(fc)
      p_id <- paste0("dossiers\r", d)
      .noeud3("et", list(.feuille3(p_id, function(sigs) stats::setNames(list(c(TRUE, FALSE)), p_id), function(a, n) a[[p_id]]), fc))
    })
    arbre <- .noeud3("et", list(feuille_code(l, rentes), g$arbres[[l]],
                                .noeud3("non", list(if (length(deces) > 0L) .noeud3("ou", deces) else .constante3(FALSE)))))
    x <- .arbre3(arbre)
    r[l] <- x$v
    if (is.na(x$v)) ip <- .ip_cellules3(ip, l, x$pert, n)
  }
  attr(r, "index_pertinent") <- ip
  attr(r, "lues") <- lues
  r
}

# Lecture brute de D10 (d) (règle du mode bloquee, inchangée ; .gev_brut()) : chemin rapide de la
# règle V en mode Kleene, exact sur les événements qui ne lisent aucune cellule inconnue ni ligne de
# visibilité non déterminée (#105, lot V, G2b).
.verdict_d10d_brut <- function(ctx) {
  vv <- function(table, colonne) .valeurs_vue(ctx, table, colonne)
  joindre_gs <- function(colonne, gs) .joindre(ctx, "garanties_souscrites", "id_garantie_souscrite", colonne, gs)
  ne <- nrow(ctx$base$evenements)
  pa <- vv("evenements", "type_evenement") %in% "passage_invalidite"
  sinistre <- as.character(.valeurs(ctx, "evenements", "id_sinistre"))
  survenance <- as.numeric(.joindre(ctx, "sinistres", "id_sinistre", "date_survenance", sinistre))
  gs <- .valeurs(ctx, "dossiers", "id_garantie_souscrite")
  cle_d <- list(contrat = joindre_gs("id_contrat", gs), college = joindre_gs("college", gs))
  # paires (passage, dossier de son sinistre), dossiers retenus ou non déterminés
  p <- .paires(ifelse(pa, sinistre, NA), .valeurs(ctx, "dossiers", "id_sinistre"))
  ret <- ctx$retenu$dossiers[p$j]
  p <- p[ret | .nd_vue(ctx, "dossiers")[p$j], , drop = FALSE]
  ret <- ctx$retenu$dossiers[p$j]
  inv <- .k3_entree(.gev_brut(ctx, "invalidite", lapply(cle_d, `[`, p$j), survenance[p$i], rep(TRUE, nrow(p)), TRUE))
  couvert <- .k3_par(p$i[ret], .k3_sous(inv, ret), ne, "un")
  avec <- tabulate(p$i[ret], ne) > 0L
  sans <- which(pa & !avec)
  if (length(sans) > 0L) {
    cv <- .couverture3(ctx, .joindre(ctx, "sinistres", "id_sinistre", "id_assure", sinistre[sans]), survenance[sans])
    # affiliation : clé (id_contrat, college) ; contrat individuel : contrat seul
    aff <- cv$affiliation
    s_cv <- survenance[sans][cv$i]
    g <- .gev_brut(ctx, "invalidite", list(contrat = cv$contrat, college = cv$college), s_cv, aff, TRUE)
    g_c <- .gev_brut(ctx, "invalidite", list(contrat = cv$contrat), s_cv, !aff, FALSE)
    g$valeurs[!aff] <- g_c$valeurs[!aff]
    g$index[!aff] <- g_c$index[!aff]
    g$inconnu <- lengths(g$index) > 0L
    atome <- .k3_entree(g)
    # couverture incertaine : l'atome est faux si la garantie l'est, inconnu sinon
    inc <- which(!cv$certain & !(atome$v %in% FALSE))
    atome$v[!cv$certain] <- ifelse(atome$v[!cv$certain] %in% FALSE, FALSE, NA)
    for (k in inc) {
      if (is.null(atome$index[[cv$tc[k]]])) atome$index[[cv$tc[k]]] <- vector("list", nrow(cv))
      atome$index[[cv$tc[k]]][k] <- list(cv$ligne[k])
    }
    cc <- .k3_par(cv$i, atome, length(sans), "un")
    couvert$v[sans] <- cc$v
    for (tc in names(cc$index)) {
      if (is.null(couvert$index[[tc]])) couvert$index[[tc]] <- vector("list", ne)
      couvert$index[[tc]][sans] <- cc$index[[tc]]
    }
  }
  # dossier non déterminé : il peut fournir la couverture (avec un dossier retenu), ou en tenir
  # lieu (sans dossier retenu, la couverture par contrat ne vaut que s'il n'est pas visible)
  pn <- which(!ret)
  for (k in split(pn, p$i[pn])) {
    i <- p$i[k[1L]]
    x <- inv$v[k]
    reste <- if (avec[i]) couvert$v[i] %in% TRUE || all(x %in% FALSE) else {
      vals <- c(couvert$v[i], x)
      all(vals %in% TRUE) || all(vals %in% FALSE)
    }
    if (reste) next
    couvert$v[i] <- NA
    if (is.null(couvert$index$dossiers)) couvert$index$dossiers <- vector("list", ne)
    couvert$index$dossiers[i] <- list(p$j[k])
    g <- inv$index$garanties_souscrites[k[is.na(x)]]
    if (length(unlist(g)) > 0L) {
      if (is.null(couvert$index$garanties_souscrites)) couvert$index$garanties_souscrites <- vector("list", ne)
      couvert$index$garanties_souscrites[i] <- list(unique(c(couvert$index$garanties_souscrites[[i]], unlist(g))))
    }
  }
  .k3_resultat(.k3_op(`&`, .k3(pa), .k3(!couvert$v, couvert$index)))
}

# Verdict à trois valeurs de D10 (d) (.regle_v_garanties() ; #105, lot V, G2b) : lecture brute
# (.verdict_d10d_brut()) sur les événements qui ne lisent aucune cellule inconnue ni ligne de
# visibilité non déterminée ; un arbre par autre événement retenu qui peut être un
# passage_invalidite (type refusé : domaine), évalué par .arbre3() : passage ET NON « couvert ». « Couvert » : OU, sur les dossiers du sinistre dans la
# vue (retenus ; non déterminés : présence), de « présent ET version invalidite en vigueur à la
# survenance de même (contrat, collège) que la garantie du dossier » (.garantie_en_vigueur3() à
# trois valeurs) ; sans dossier retenu, aussi « aucun dossier non déterminé présent ET un contrat
# couvre la survenance (.couverture3() à trois valeurs) dont une version invalidite est en vigueur,
# de même (id_contrat, college) que l'affiliation, de même contrat pour un contrat individuel »
# (même lecture que le mode bloquee : un dossier non déterminé fournit la couverture, ou en tient
# lieu). La survenance, les présences et toute cellule lue par deux feuilles sont conditionnées
# (D-G2-2). Rend le vecteur logique et ses attributs `index_pertinent` et `lues` (statiques).
# `forcer` : comme .verdict_d10c().
.verdict_d10d <- function(ctx, lues, forcer = FALSE) {
  t <- "garanties_souscrites"
  ne <- NROW(ctx$base$evenements)
  type <- .valeurs(ctx, "evenements", "type_evenement")
  type_u <- .inconnu(ctx, "evenements", "type_evenement")
  pa <- ctx$retenu$evenements & (type_u | type %in% "passage_invalidite")
  ks <- .index_jointure(ctx, "sinistres", "id_sinistre", .valeurs(ctx, "evenements", "id_sinistre"))
  surv <- as.numeric(.valeurs(ctx, "sinistres", "date_survenance"))[ks]
  surv_id <- ifelse(!is.na(ks) & .inconnu(ctx, "sinistres", "date_survenance")[ifelse(is.na(ks), 1L, ks)],
                    paste0("sinistres.date_survenance\r", ks), NA_character_)
  sin_e <- .cle_manquante(as.character(.valeurs(ctx, "evenements", "id_sinistre")))
  sin_d <- .cle_manquante(as.character(.valeurs(ctx, "dossiers", "id_sinistre")))
  nd_d <- .nd_vue(ctx, "dossiers") & !ctx$retenu$dossiers
  dans <- ctx$retenu$dossiers | nd_d
  # chemin rapide (lecture brute, exacte) : passages qui ne lisent aucune cellule inconnue ni ligne de
  # visibilité non déterminée (dossiers du sinistre, leurs versions, contrats qui couvrent sans
  # dossier retenu et leurs versions) ; les autres relèvent de .arbre3()
  r_brut <- as.vector(.verdict_d10d_brut(ctx))
  r <- r_brut %in% TRUE
  inc_v <- .inconnues_versions3(ctx)
  igd <- .index_jointure(ctx, t, "id_garantie_souscrite", .valeurs(ctx, "dossiers", "id_garantie_souscrite"))
  d_inc <- dans & (nd_d | (!is.na(igd) & .inconnu(ctx, t, "college")[ifelse(is.na(igd), 1L, igd)]) |
                     .cle_manquante(as.character(.valeurs(ctx, t, "id_contrat")[igd])) %in% inc_v$contrats)
  sin_inc <- unique(sin_d[d_inc])
  sin_ret <- unique(sin_d[ctx$retenu$dossiers])
  assures_inc <- character(0)
  for (tc in intersect(c("affiliations", "contrats"), names(ctx$base))) {
    u <- function(c1) if (c1 %in% names(ctx$base[[tc]])) .inconnu(ctx, tc, c1) else rep(FALSE, NROW(ctx$base[[tc]]))
    nd_c <- .nd_vue(ctx, tc)
    partie <- if (.vue_totale(ctx)) NULL else .visibilite_a(ctx, "vue")$parties[[tc]]
    x <- (ctx$retenu[[tc]] | nd_c) & (nd_c | u("date_debut") | u("date_effet") | u("date_fin") | u("date_terme") |
                                        u("nature_contrat") | u("college") | (if (is.null(partie)) FALSE else is.na(partie)) |
                                        .cle_manquante(as.character(.valeurs(ctx, tc, "id_contrat"))) %in% inc_v$contrats)
    assures_inc <- c(assures_inc, .cle_manquante(as.character(.valeurs(ctx, tc, "id_assure")))[x])
  }
  assure_e <- if (is.null(ctx$base$sinistres$id_assure)) rep(NA_character_, ne) else
    .cle_manquante(as.character(.valeurs(ctx, "sinistres", "id_assure")[ks]))
  complexe <- pa & (forcer | type_u | !is.na(surv_id) | (!is.na(sin_e) & sin_e %in% sin_inc[!is.na(sin_inc)]) |
                      (!(sin_e %in% sin_ret[!is.na(sin_ret)]) & !is.na(assure_e) & assure_e %in% assures_inc[!is.na(assures_inc)]))
  if (any(ctx$retenu$evenements & !complexe & is.na(r_brut))) {
    stop("erreur interne de provie : D10d : lecture brute ind\u00e9termin\u00e9e hors du chemin \u00e0 trois valeurs", call. = FALSE)
  }
  r[complexe] <- FALSE
  pa <- complexe
  # paires (passage, dossier du sinistre dans la vue) et leurs versions invalidite
  p <- .paires(ifelse(pa, sin_e, NA), ifelse(dans, sin_d, NA))
  ig <- .index_jointure(ctx, t, "id_garantie_souscrite", .valeurs(ctx, "dossiers", "id_garantie_souscrite"))[p$j]
  col_id <- ifelse(!is.na(ig) & .inconnu(ctx, t, "college")[ifelse(is.na(ig), 1L, ig)], paste0(t, ".college\r", ig), NA_character_)
  inv <- .garantie_en_vigueur3(ctx, "invalidite", list(contrat = .valeurs(ctx, t, "id_contrat")[ig], college = .valeurs(ctx, t, "college")[ig]),
                               surv[p$i], inconnues = list(survenance = surv_id[p$i], college = col_id))
  par_e <- split(seq_len(nrow(p)), factor(p$i, levels = seq_len(ne)))
  # couverture par contrat des passages sans dossier retenu
  sans <- which(pa & !vapply(par_e, function(k) any(ctx$retenu$dossiers[p$j[k]]), NA))
  cv_e <- vector("list", ne)
  if (length(sans) > 0L && !is.null(ctx$base$sinistres$id_assure)) {
    assure <- .valeurs(ctx, "sinistres", "id_assure")[ks[sans]]
    cv <- .couverture3(ctx, assure, surv[sans], inconnues = list(date = surv_id[sans]))
    if (nrow(cv) > 0L) {
      s_cv <- surv[sans][cv$i]
      sid_cv <- surv_id[sans][cv$i]
      aff <- cv$affiliation
      g <- .garantie_en_vigueur3(ctx, "invalidite", list(contrat = cv$contrat, college = cv$college), s_cv, aff,
                                 inconnues = list(survenance = sid_cv, college = cv$college_id))
      g_c <- .garantie_en_vigueur3(ctx, "invalidite", list(contrat = cv$contrat), s_cv, !aff, college = FALSE,
                                   inconnues = list(survenance = sid_cv, college = rep(NA_character_, nrow(cv))))
      fe <- attr(cv, "feuilles")
      for (k in seq_len(nrow(cv))) {
        e <- sans[cv$i[k]]
        cv_e[[e]] <- c(cv_e[[e]], list(.noeud3("et", list(fe[[k]], if (aff[k]) g$arbres[[k]] else g_c$arbres[[k]]))))
      }
    }
  }
  presence <- function(d) {
    p_id <- paste0("dossiers\r", d)
    .feuille3(p_id, function(sigs) stats::setNames(list(c(TRUE, FALSE)), p_id), function(a, n) a[[p_id]])
  }
  dom_type <- .domaine3(ctx, "evenements", "type_evenement")
  ip <- list()
  for (e in which(pa)) {
    k <- par_e[[e]]
    termes <- lapply(k, function(q) if (nd_d[p$j[q]]) .noeud3("et", list(presence(p$j[q]), inv$arbres[[q]])) else inv$arbres[[q]])
    if (e %in% sans) {
      absents <- lapply(k, function(q) .noeud3("non", list(presence(p$j[q]))))
      contrats <- if (length(cv_e[[e]]) > 0L) .noeud3("ou", cv_e[[e]]) else .constante3(FALSE)
      termes <- c(termes, list(.noeud3("et", c(absents, list(contrats)))))
    }
    t_id <- if (type_u[e]) paste0("evenements.type_evenement\r", e) else NA_character_
    f_pa <- .feuille3(t_id, function(sigs) stats::setNames(list(dom_type), t_id),
                      function(a, n) .val3(a, t_id, type[e], n) %in% "passage_invalidite")
    x <- .arbre3(.noeud3("et", list(f_pa, .noeud3("non", list(if (length(termes) > 0L) .noeud3("ou", termes) else .constante3(FALSE))))))
    r[e] <- x$v
    if (is.na(x$v)) ip <- .ip_cellules3(ip, e, x$pert, ne)
  }
  attr(r, "index_pertinent") <- ip
  attr(r, "lues") <- lues
  r
}

# Garantie souscrite de code `code` en vigueur à la survenance (spécification `donnees` v1.6,
# § 8.0 bis, point 4 ; règle de « décès souscrit » de D10 (c), seule implémentation, lue par
# D10 (c), D10 (d) et D14) : pour chaque élément, il existe une version de garanties_souscrites de
# code `code`, de même (id_contrat, college) que `cle` (liste de deux vecteurs de la longueur de
# `survenance` : `contrat` et `college` ; `college` faux : `contrat` seul, tout collège), dont
# [date_effet ; date_fin] contient `survenance` (nombre ; manquante : faux). Vrai si une version
# retenue dans la vue (code de la vue) le satisfait ; inconnu sinon, sur les éléments de `lignes`,
# si une version de visibilité non déterminée (.nd_vue()) le satisfait (index : ces versions) ;
# faux sinon. Appariement par clé avant le test des dates (m7). Clé sans paste() (spécification
# `donnees` v1.8, #153 ; M613) : une composante manquante ou vide (.cle_manquante()) met l'élément
# ou la version hors de tout appariement, elle ne s'apparie ni à une autre composante manquante,
# ni au « NA » littéral. Un collège refusé de garanties_souscrites n'est pas lu (état inatteignable
# tant que M169 tient : la règle V qui lit le collège est alors bloquée avant) : erreur interne,
# aucun verdict rendu ; la lecture existentielle de la v1.8 est codée avec #105. Une composante de
# `cle` absente ou de longueur différente de `survenance` : erreur interne (aucun recyclage). Rend une entrée
# de .verdict3(), et, par élément, `versions` : lignes des versions retenues qui le satisfont,
# `versions_nd` : lignes des versions non déterminées qui le satisfont, sur les éléments de
# `lignes`, que l'élément soit vrai ou non (lues par D14 : conjoint visé et limite d'âge de la
# version).
# `inconnues` (#105, lot V, G2b, M810 ; spécification `donnees`, erratum `1.9.7`, E-1, E-7, E-9 ;
# source extensible, #211) : NULL (défaut) : lecture ci-dessus, inchangée (appelants en mode
# bloquee : .maintien_d11(), D11a et D11b) ; sinon liste alignée sur les éléments
# (`survenance` : identifiant .arbre3() de la cellule de survenance inconnue, NA si connue ;
# `college` : de même pour le collège de l'élément) : lecture existentielle à trois valeurs, rendue
# en arbres (.versions3()) ; la garde du collège ne vaut plus que pour une cause de forme ou de
# portée table (M626).
.garantie_en_vigueur3 <- function(ctx, code, cle, survenance, lignes = rep(TRUE, length(survenance)), college = TRUE,
                                  inconnues = NULL) {
  if (length(cle$contrat) != length(survenance) ||
      (college && (is.null(cle$college) || length(cle$college) != length(survenance)))) {
    stop("erreur interne de provie : .garantie_en_vigueur3() : cl\u00e9 (contrat", if (college) ", coll\u00e8ge",
         ") de longueur diff\u00e9rente de celle de la survenance (aucun recyclage)", call. = FALSE)
  }
  if (!is.null(inconnues)) {
    if (college && !is.null(.cause_lecture(ctx, "garanties_souscrites.college")) &&
        is.null(.lignes_refusees(ctx, "garanties_souscrites", "college"))) {
      stop("erreur interne de provie : .garantie_en_vigueur3() lit garanties_souscrites.college, colonne illisible ",
           "(cause de forme ou de port\u00e9e table : la r\u00e8gle V qui la lit est bloqu\u00e9e avant, M626)", call. = FALSE)
    }
    return(.versions3(ctx, code, cle, survenance, lignes, college, inconnues))
  }
  if (college && !is.null(.cause_lecture(ctx, "garanties_souscrites.college"))) {
    stop("erreur interne de provie : .garantie_en_vigueur3() lit garanties_souscrites.college, colonne refus\u00e9e ",
         "(la r\u00e8gle V qui la lit est bloqu\u00e9e avant, M169 ; lecture existentielle : #105)", call. = FALSE)
  }
  .gev_brut(ctx, code, cle, survenance, lignes, college)
}
# Corps de la lecture brute de .garantie_en_vigueur3() (sans garde du collège) : lu tel quel par
# les règles V en mode Kleene sur les seuls éléments qui ne lisent aucune cellule inconnue ni
# ligne de visibilité non déterminée (chemin rapide de D10 (c), D10 (d) et D14, exact sur ces
# éléments ; #105, lot V, G2b).
.gev_brut <- function(ctx, code, cle, survenance, lignes, college) {
  v <- function(c1) .valeurs(ctx, "garanties_souscrites", c1)
  # code entier du groupe (contrat[, collège]) des versions puis des éléments ; NA : composante
  # manquante ou vide, hors de tout appariement
  composantes <- list(c(as.character(v("id_contrat")), as.character(cle$contrat)))
  if (college) composantes <- c(composantes, list(c(as.character(v("college")), as.character(cle$college))))
  groupe <- .code_groupe(lapply(composantes, .cle_manquante), cles = seq_along(composantes))
  ng <- length(v("id_contrat"))
  groupe_v <- groupe[seq_len(ng)]
  groupe_e <- groupe[ng + seq_along(survenance)]
  versions <- which(.valeurs_vue(ctx, "garanties_souscrites", "code_garantie") %in% code)
  cle_v <- groupe_v[versions]
  effet <- as.numeric(v("date_effet"))[versions]
  fin <- as.numeric(v("date_fin"))[versions]
  par_cle <- split(seq_along(cle_v), factor(cle_v, levels = unique(cle_v)))
  trouvees <- lapply(seq_along(survenance), function(i) {
    j <- if (is.na(groupe_e[i])) NULL else par_cle[[as.character(groupe_e[i])]]
    if (is.na(survenance[i]) || length(j) == 0L) return(integer(0))
    versions[j[!is.na(effet[j]) & effet[j] <= survenance[i] & (is.na(fin[j]) | fin[j] >= survenance[i])]]
  })
  valeurs <- lengths(trouvees) > 0L
  nd <- .nd_vue(ctx, "garanties_souscrites")
  index <- vector("list", length(survenance))
  trouvees_nd <- vector("list", length(survenance))
  if (any(nd)) {
    versions_nd <- which(nd & v("code_garantie") %in% code)
    effet_nd <- as.numeric(v("date_effet"))[versions_nd]
    fin_nd <- as.numeric(v("date_fin"))[versions_nd]
    # paires (élément, version non déterminée) de même clé (.paires() : coût proportionnel au
    # nombre de paires), puis test des dates sur les seules paires
    el <- which(lignes & !is.na(survenance))
    p <- .paires(groupe_e[el], groupe_v[versions_nd])
    e <- el[p$i]
    s <- survenance[e]
    garde <- !is.na(effet_nd[p$j]) & effet_nd[p$j] <= s & (is.na(fin_nd[p$j]) | fin_nd[p$j] >= s)
    e <- e[garde]
    j <- versions_nd[p$j[garde]]
    par_element <- split(j, factor(e, levels = unique(e)))
    i <- as.integer(names(par_element))
    trouvees_nd[i] <- par_element
    sans_valeur <- !valeurs[i]
    index[i[sans_valeur]] <- par_element[sans_valeur]
  }
  list(tc = "garanties_souscrites", valeurs = valeurs, inconnu = lengths(index) > 0L, index = index, domaine = c(TRUE, FALSE),
       versions = trouvees, versions_nd = trouvees_nd)
}

# Garantie de code `code` en vigueur à la survenance, à trois valeurs, en arbres de .arbre3()
# (.garantie_en_vigueur3() avec `inconnues` ; #105, lot V, G2b, M810 ; E-7, E-9) : pour chaque
# élément des `lignes`, OU des feuilles de ses versions candidates (retenues ou de visibilité non
# déterminée, de même contrat, dont le code peut valoir `code` et le collège égaler celui de
# l'élément ; un collège refusé est un code opaque qui peut valoir tout collège présent ou une
# valeur neuve, M626), constante fausse sans candidate ni survenance. Feuille d'une version j :
# présente (cellule « garanties_souscrites\rj » si non déterminée), de code `code`, de même
# collège, effet au plus la survenance et fin absente ou au moins la survenance ; inconnues : code,
# collège, date d'effet (refusée, ou cellule de D03i : inconnue dans la plage, défaut latent (ii)
# corrigé), date de fin (et l'absence), survenance et collège de l'élément (`inconnues`) ; plus
# aucune lecture brute d'une valeur refusée (défaut latent (i) corrigé). Représentants : dates aux
# points de rupture relatifs aux dates comparées (ou aux bornes de leur plage), code dans son
# domaine, collège opaque (valeur comparée, deux valeurs neuves, l'absence sur une colonne
# facultative). Rend `arbres`, `candidates` (lignes des versions par élément) et `feuille(i, j)`.
.versions3 <- function(ctx, code, cle, survenance, lignes, college, inconnues) {
  t <- "garanties_souscrites"
  v <- function(c1) .valeurs(ctx, t, c1)
  ne <- length(survenance)
  presente <- ctx$retenu[[t]] | .nd_vue(ctx, t)
  nd <- .nd_vue(ctx, t)
  id <- function(c1, j) ifelse(.inconnu(ctx, t, c1)[j], paste0(t, ".", c1, "\r", j), NA_character_)
  code_v <- v("code_garantie")
  code_u <- .inconnu(ctx, t, "code_garantie")
  contrat_v <- .cle_manquante(as.character(v("id_contrat")))
  contrat_e <- .cle_manquante(as.character(cle$contrat))
  college_v <- as.character(v("college"))
  college_u <- if (college) .inconnu(ctx, t, "college") else rep(FALSE, length(college_v))
  college_k <- .cle_manquante(college_v)
  college_e <- if (college) as.character(cle$college) else rep(NA_character_, ne)
  college_ek <- .cle_manquante(college_e)
  effet <- as.numeric(v("date_effet"))
  fin <- as.numeric(v("date_fin"))
  plage_s <- .plage_date3(ctx, "sinistres", "date_survenance")
  abs_s <- !.obligatoire3(ctx, "sinistres", "date_survenance")
  plage_e <- .plage_date3(ctx, t, "date_effet")
  abs_e <- !.obligatoire3(ctx, t, "date_effet")
  plage_f <- .plage_date3(ctx, t, "date_fin")
  abs_f <- !.obligatoire3(ctx, t, "date_fin")
  dom_code <- .domaine3(ctx, t, "code_garantie")
  abs_c <- !.obligatoire3(ctx, t, "college")
  feuille <- function(i, j) {
    s_id <- inconnues$survenance[i]
    ce_id <- if (college) inconnues$college[i] else NA_character_
    c_id <- id("code_garantie", j)
    cj_id <- if (college) id("college", j) else NA_character_
    e_id <- id("date_effet", j)
    f_id <- id("date_fin", j)
    p_id <- if (nd[j]) paste0(t, "\r", j) else NA_character_
    neuf <- c("\r1", "\r2", if (abs_c) NA_character_)
    dom <- function(sigs) {
      date_de <- function(x_id, x, plage) if (is.na(x_id)) x else { y <- .fixees3(sigs, x_id, numeric(0)); if (length(y)) y else plage }
      sv <- date_de(s_id, survenance[i], plage_s)
      d <- list()
      if (!is.na(s_id)) d[[s_id]] <- .reps_date3(plage_s, abs_s, c(date_de(e_id, effet[j], plage_e), date_de(f_id, fin[j], plage_f)))
      if (!is.na(e_id)) d[[e_id]] <- .reps_date3(plage_e, abs_e, sv)
      if (!is.na(f_id)) d[[f_id]] <- .reps_date3(plage_f, abs_f, sv)
      if (!is.na(c_id)) d[[c_id]] <- dom_code
      if (!is.na(cj_id)) d[[cj_id]] <- unique(c(if (is.na(ce_id)) college_e[i] else .fixees3(sigs, ce_id, character(0)), neuf))
      if (!is.na(ce_id)) d[[ce_id]] <- unique(c(if (is.na(cj_id)) college_v[j], neuf))
      if (!is.na(p_id)) d[[p_id]] <- c(TRUE, FALSE)
      d
    }
    f <- function(a, n) {
      s <- .val3(a, s_id, survenance[i], n)
      e <- .val3(a, e_id, effet[j], n)
      fi <- .val3(a, f_id, fin[j], n)
      r <- .val3(a, c_id, code_v[j], n) %in% code & !is.na(s) & !is.na(e) & e <= s & (is.na(fi) | fi >= s)
      if (college) {
        cj <- .val3(a, cj_id, college_v[j], n)
        ce <- .val3(a, ce_id, college_e[i], n)
        r <- r & .egal_cle3(cj, cj_id) & .egal_cle3(ce, ce_id) & cj == ce
      }
      if (!is.na(p_id)) r <- r & a[[p_id]]
      r %in% TRUE
    }
    .feuille3(c(s_id, ce_id, c_id, cj_id, e_id, f_id, p_id), dom, f)
  }
  candidates <- vector("list", ne)
  arbres <- vector("list", ne)
  for (i in seq_len(ne)) {
    arbres[[i]] <- .constante3(FALSE)
    if (!lignes[i] || is.na(contrat_e[i])) next
    if (is.na(inconnues$survenance[i]) && is.na(survenance[i])) next
    if (college && is.na(inconnues$college[i]) && is.na(college_ek[i])) next
    j <- which(presente & !is.na(contrat_v) & contrat_v == contrat_e[i] & (code_u | code_v %in% code))
    if (college) j <- j[college_u[j] | !is.na(inconnues$college[i]) | (!is.na(college_k[j]) & college_k[j] == college_ek[i])]
    candidates[[i]] <- j
    if (length(j) > 0L) arbres[[i]] <- .noeud3("ou", lapply(j, function(x) feuille(i, x)))
  }
  list(arbres = arbres, candidates = candidates, feuille = feuille)
}
# Clé opaque d'une affectation (.versions3()) : une valeur connue manquante ou vide
# (.cle_manquante()) ne s'apparie pas ; une valeur inconnue (`id` non NA) est un représentant.
.egal_cle3 <- function(x, id) if (is.na(id)) !is.na(.cle_manquante(x)) else !is.na(x)

# Couverture d'une date par un contrat (spécification `donnees` v1.6, § 8.0 bis, point 5) :
# pour chaque élément (assuré `assure`, date `date`), contrats qui couvrent la date :
# affiliation de l'assuré dont [date_debut ; date_fin connue à l'arrêté] contient la date ;
# contrat individuel de l'assuré, [date_effet ; min(date_fin connue à l'arrêté, date_terme)]
# (bornes incluses ; fin inconnue à l'arrêté : ouverte ; le collège n'y entre pas, une
# affiliation de portabilité couvre comme toute autre). Rend des paires (`i` : élément,
# `contrat`, `affiliation` : ligne d'affiliations (sinon contrat individuel), `college` :
# affiliations.college de la ligne (NA pour un contrat individuel), `certain` : ligne retenue
# qui couvre quelle que soit sa partie de fin ; sinon couverture possible, `tc` et `ligne` :
# élément non déterminé, ligne entière (« table ») ou partie de fin (« table.colonne » de son
# inscription, .cause_nd())). Seule implémentation,
# lue par D10 (d), D11a et D11b. `college` (facultatif, aligné sur les éléments ; spécification
# `donnees` v1.9, § 9.5, D11b) : seules les affiliations de ce collège couvrent, aucun contrat
# individuel (hors champ du collège) ; un collège manquant ou vide (.cle_manquante()) ne
# s'apparie à aucune affiliation.
# `inconnues` (#105, lot V, G2b ; E-1, E-9) : NULL (défaut) : lecture ci-dessus, inchangée
# (appelants en mode bloquee : D11a, D11b) ; sinon liste (`date` : identifiant .arbre3() de la
# cellule de date inconnue de chaque élément, NA si connue) : couverture à trois valeurs, rendue
# en feuilles (.couverture_arbres3()), sans `college`.
.couverture3 <- function(ctx, assure, date, college = NULL, inconnues = NULL) {
  assure <- as.character(assure)
  date <- as.numeric(date)
  if (!is.null(college) && length(college) != length(assure)) {
    stop("erreur interne de provie : .couverture3() : coll\u00e8ge de longueur diff\u00e9rente de celle des \u00e9l\u00e9ments ",
         "(aucun recyclage)", call. = FALSE)
  }
  if (!is.null(inconnues)) {
    if (!is.null(college)) {
      stop("erreur interne de provie : .couverture3() : coll\u00e8ge et inconnues ensemble (lecture \u00e0 trois valeurs ",
           "sans coll\u00e8ge, #105, G2c)", call. = FALSE)
    }
    return(.couverture_arbres3(ctx, assure, date, inconnues))
  }
  res <- list(data.frame(i = integer(0), contrat = character(0), affiliation = logical(0), college = character(0),
                         certain = logical(0), tc = character(0), ligne = integer(0), stringsAsFactors = FALSE))
  for (t in intersect(c("affiliations", if (is.null(college)) "contrats"), names(ctx$base))) {
    v <- function(c1) .valeurs(ctx, t, c1)
    n <- nrow(ctx$base[[t]])
    if (t == "affiliations") {
      debut <- as.numeric(v("date_debut"))
      terme <- rep(NA_real_, n)
      admis <- rep(TRUE, n)
    } else {
      debut <- as.numeric(v("date_effet"))
      terme <- as.numeric(v("date_terme"))
      admis <- v("nature_contrat") %in% "individuel"
    }
    fin <- as.numeric(v("date_fin"))
    partie <- if (.vue_totale(ctx)) NULL else .visibilite_a(ctx, "vue")$parties[[t]]
    if (is.null(partie)) partie <- rep(TRUE, n)
    retenu <- ctx$retenu[[t]]
    nd <- .nd_vue(ctx, t)
    p <- .paires(assure, ifelse((retenu | nd) & admis, as.character(v("id_assure")), NA))
    if (!is.null(college)) {
      # même collège (clé renseignée des deux côtés, .cle_manquante())
      k_e <- .cle_manquante(as.character(college))[p$i]
      k_a <- .cle_manquante(as.character(v("college")))[p$j]
      p <- p[!is.na(k_e) & !is.na(k_a) & k_e == k_a, , drop = FALSE]
    }
    d <- date[p$i]
    l <- p$j
    dans <- !is.na(d) & !is.na(debut[l]) & debut[l] <= d & (is.na(terme[l]) | d <= terme[l])
    fin_ok <- is.na(fin[l]) | d <= fin[l]
    certain <- retenu[l] & dans & (fin_ok | partie[l] %in% FALSE)
    par_partie <- retenu[l] & dans & !fin_ok & is.na(partie[l])
    par_ligne <- nd[l] & dans & (fin_ok | !(partie[l] %in% TRUE))
    garde <- certain | par_partie | par_ligne
    tc <- ifelse(par_ligne, t, NA_character_)
    tc[which(par_partie)] <- vapply(l[par_partie], function(x) .colonne_partie(ctx, t, x), "")
    college_l <- if (t == "affiliations") as.character(v("college"))[l[garde]] else rep(NA_character_, sum(garde))
    res[[t]] <- data.frame(i = p$i[garde], contrat = as.character(v("id_contrat"))[l[garde]],
                           affiliation = rep(t == "affiliations", sum(garde)), college = college_l,
                           certain = certain[garde], tc = tc[garde], ligne = l[garde], stringsAsFactors = FALSE)
  }
  res <- do.call(rbind, unname(res))
  rownames(res) <- NULL
  res
}

# Couverture à trois valeurs en feuilles de .arbre3() (.couverture3() avec `inconnues` ; #105, lot
# V, G2b ; spécification `donnees` v1.6, § 8.0 bis, point 5 ; E-1, E-9) : pour chaque élément et
# chaque ligne candidate (affiliation, ou contrat individuel, retenue ou non déterminée, de même
# assuré ; nature refusée : contrat possible), une feuille « la ligne couvre la date » : présente
# (cellule « table\rligne » si non déterminée), début au plus la date, terme absent ou au moins la
# date, et fin absente ou au moins la date ou partie de fin non connue à l'arrêté (partie non
# déterminée d'une ligne retenue : cellule de sa date d'inscription, .colonne_partie() ; d'une ligne
# non déterminée : cellule « table\rligne\rp » rattachée à la ligne, lecture du mode bloquee) ;
# inconnues : début (refusé, ou contrats.date_effet de D03i), fin, terme, nature, date de l'élément
# (à deux côtés : représentants aux points de rupture de chaque borne). Rend un data.frame
# (`i`, `contrat`, `affiliation`, `college`, `college_id` : cellule du collège refusé de
# l'affiliation) et, en attribut `feuilles`, la feuille de chaque rangée.
.couverture_arbres3 <- function(ctx, assure, date, inconnues) {
  res <- list(data.frame(i = integer(0), contrat = character(0), affiliation = logical(0), college = character(0),
                         college_id = character(0), stringsAsFactors = FALSE))
  feuilles <- list()
  plage_d <- .plage_date3(ctx, "sinistres", "date_survenance")
  abs_d <- !.obligatoire3(ctx, "sinistres", "date_survenance")
  # une fonction par table : les feuilles gardent les valeurs de leur table (environnement propre)
  par_table <- function(t) {
    v <- function(c1) .valeurs(ctx, t, c1)
    n <- nrow(ctx$base[[t]])
    aff <- t == "affiliations"
    c_debut <- if (aff) "date_debut" else "date_effet"
    cel <- function(c1, l) if (.inconnu(ctx, t, c1)[l]) paste0(t, ".", c1, "\r", l) else NA_character_
    debut <- as.numeric(v(c_debut))
    fin <- as.numeric(v("date_fin"))
    terme <- if (aff) rep(NA_real_, n) else as.numeric(v("date_terme"))
    nature_u <- if (aff) rep(FALSE, n) else .inconnu(ctx, t, "nature_contrat")
    admis <- if (aff) rep(TRUE, n) else v("nature_contrat") %in% "individuel" | nature_u
    partie <- if (.vue_totale(ctx)) NULL else .visibilite_a(ctx, "vue")$parties[[t]]
    if (is.null(partie)) partie <- rep(TRUE, n)
    retenu <- ctx$retenu[[t]]
    nd <- .nd_vue(ctx, t) & !retenu
    plages <- list(debut = .plage_date3(ctx, t, c_debut), fin = .plage_date3(ctx, t, "date_fin"),
                   terme = if (!aff) .plage_date3(ctx, t, "date_terme"))
    absents <- list(debut = !.obligatoire3(ctx, t, c_debut), fin = !.obligatoire3(ctx, t, "date_fin"),
                    terme = !aff && !.obligatoire3(ctx, t, "date_terme"))
    dom_nature <- if (!aff) .domaine3(ctx, t, "nature_contrat")
    p <- .paires(assure, ifelse((retenu | nd) & admis, as.character(v("id_assure")), NA))
    if (nrow(p) == 0L) return(NULL)
    feuille <- function(i, l) {
      d_id <- inconnues$date[i]
      ids <- list(debut = cel(c_debut, l), fin = cel("date_fin", l), terme = if (!aff) cel("date_terme", l) else NA_character_)
      n_id <- if (!aff) cel("nature_contrat", l) else NA_character_
      p_id <- if (nd[l]) paste0(t, "\r", l) else NA_character_
      pa_id <- if (is.na(partie[l])) {
        if (nd[l]) paste0(t, "\r", l, "\rp") else paste0(.colonne_partie(ctx, t, l), "\r", l)
      } else NA_character_
      connues <- list(debut = debut[l], fin = fin[l], terme = terme[l])
      dom <- function(sigs) {
        de <- function(k) if (is.na(ids[[k]])) connues[[k]] else { y <- .fixees3(sigs, ids[[k]], numeric(0)); if (length(y)) y else plages[[k]] }
        dv <- if (is.na(d_id)) date[i] else { y <- .fixees3(sigs, d_id, numeric(0)); if (length(y)) y else plage_d }
        out <- list()
        if (!is.na(d_id)) out[[d_id]] <- .reps_date3(plage_d, abs_d, c(de("debut"), de("fin"), de("terme")))
        for (k in names(ids)) if (!is.na(ids[[k]])) out[[ids[[k]]]] <- .reps_date3(plages[[k]], absents[[k]], dv)
        if (!is.na(n_id)) out[[n_id]] <- dom_nature
        if (!is.na(p_id)) out[[p_id]] <- c(TRUE, FALSE)
        if (!is.na(pa_id)) out[[pa_id]] <- c(TRUE, FALSE)
        out
      }
      f <- function(a, n1) {
        d <- .val3(a, d_id, date[i], n1)
        de <- .val3(a, ids$debut, debut[l], n1)
        fi <- .val3(a, ids$fin, fin[l], n1)
        te <- .val3(a, ids$terme, terme[l], n1)
        pa <- if (is.na(pa_id)) rep_len(partie[l] %in% TRUE, n1) else a[[pa_id]]
        r <- !is.na(d) & !is.na(de) & de <= d & (is.na(te) | d <= te) & (is.na(fi) | d <= fi | !pa)
        if (!aff) r <- r & .val3(a, n_id, v("nature_contrat")[l], n1) %in% "individuel"
        if (!is.na(p_id)) r <- r & a[[p_id]]
        r %in% TRUE
      }
      .feuille3(c(d_id, ids$debut, ids$fin, ids$terme, n_id, p_id, pa_id), dom, f)
    }
    college_id <- if (aff) ifelse(.inconnu(ctx, t, "college")[p$j], paste0(t, ".college\r", p$j), NA_character_) else
      rep(NA_character_, nrow(p))
    list(df = data.frame(i = p$i, contrat = as.character(v("id_contrat"))[p$j], affiliation = rep(aff, nrow(p)),
                         college = if (aff) as.character(v("college"))[p$j] else rep(NA_character_, nrow(p)),
                         college_id = college_id, stringsAsFactors = FALSE),
         feuilles = lapply(seq_len(nrow(p)), function(k) feuille(p$i[k], p$j[k])))
  }
  for (t in intersect(c("affiliations", "contrats"), names(ctx$base))) {
    x <- par_table(t)
    if (is.null(x)) next
    res[[t]] <- x$df
    feuilles <- c(feuilles, x$feuilles)
  }
  res <- do.call(rbind, unname(res))
  rownames(res) <- NULL
  attr(res, "feuilles") <- feuilles
  res
}

# « table.colonne » de l'inscription de la partie de fin non déterminée de la ligne `x` de
# `t` (.cause_nd()) ; à défaut, date_saisie_fin. Lu par .couverture3() et D11c.
.colonne_partie <- function(ctx, t, x) {
  for (k in ctx$lignes_nd) if (k$table == t && !is.na(k$colonne) && x %in% k$lignes) return(paste(t, k$colonne, sep = "."))
  paste(t, "date_saisie_fin", sep = ".")
}

# Paires `k` (indices ou logique) d'un verdict à trois valeurs (.k3()) : valeurs et index.
.k3_sous <- function(x, k) .k3(x$v[k], lapply(x$index, `[`, k))

# Déclaration attendue hors placement d'un constat (conventions, seuils qui conditionnent une
# détection) : `nombre_lignes` NA (ADR 0010, neuvième série).
.requerir <- function(ctx, rubrique, motif, cle, traitements_admis = NA_character_) {
  ctx$requises[[length(ctx$requises) + 1L]] <- list(rubrique = rubrique, motif = motif, cle = cle,
                                                    traitements_admis = traitements_admis, table = NA_character_,
                                                    lignes = NULL)
  invisible(NULL)
}

# D02c, âge invraisemblable (dictionnaire, § 9 ; spécification, § 5.4), sur la vue : âge de la
# personne à la date de référence de chaque emploi, sous conventions$age (calculer_age()),
# hors des bornes [d02c_age_min, d02c_age_max] de l'emploi ; traitement S + X, deux constats
# de même clé (code, table, date_naissance), un par traitement. Sans convention ou sans
# l'une des bornes d'un emploi : non exécuté (colonne NA, sous-cas distinct de D02c sur la
# date, ADR 0010, huitième série, (b)), cause declaration_absente, et déclaration requise
# (rubrique conventions, cle age ; rubrique seuils, cle <seuil>$<emploi>). Une date de
# référence antérieure à la naissance (âge non défini, § 5.2) met le sous-cas de la table dans
# controles_non_executes (.CAUSE_AGE_NON_DEFINI). Emplois : assuré au sinistre (survenance) ;
# assuré à l'affiliation (date_debut ; contrat individuel : date_effet) ; membre de la
# famille, ligne valable hors a_naitre (survenance du sinistre d'instruction, sans sinistre :
# date_saisie) ; désigné, ayant droit (date_saisie de la ligne).
.regle_v_ages <- function(ctx) {
  conv <- ctx$conventions$age
  seuils <- ctx$declarations$seuils
  present <- function(t) !is.null(ctx$base[[t]])
  # colonnes lues par emploi (les verdicts : .age_assure3(), .age_invraisemblable3())
  emplois <- list(
    assures_sinistre = list(lit = c("assures.id_assure", "sinistres.id_sinistre", "sinistres.id_assure",
                                    "sinistres.date_survenance"), vue = ctx$lit_vue$sinistres),
    assures_affiliation = list(lit = c("assures.id_assure", "affiliations.id_assure", "affiliations.date_debut",
                                       "contrats.id_assure", "contrats.date_effet", "contrats.nature_contrat"),
                               vue = c(ctx$lit_vue$affiliations, ctx$lit_vue$contrats)),
    famille = list(lit = c("famille.situation", "famille.id_sinistre", "famille.date_saisie", "sinistres.id_sinistre",
                           "sinistres.date_survenance")),
    designations = list(lit = "designations.date_saisie"),
    ayants_droit_sante = list(lit = "ayants_droit_sante.date_saisie"))
  sans_convention <- FALSE
  for (emploi in names(emplois)) {
    t <- .EMPLOIS_D02C[[emploi]]
    if (!present(t)) next
    manque <- is.null(conv)
    sans_convention <- sans_convention || manque
    for (nom in SEUILS_AGE_D02C) {
      if (is.null(seuils[[nom]][[emploi]])) {
        .requerir(ctx, "seuils", "D02c", paste0(nom, "$", emploi))
        manque <- TRUE
      }
    }
    if (manque) {
      .ajouter_non_execute(ctx, "D02c", t, NA_character_, "declaration_absente")
      next
    }
    e <- emplois[[emploi]]
    mini <- seuils[[SEUILS_AGE_D02C[1L]]][[emploi]]
    maxi <- seuils[[SEUILS_AGE_D02C[2L]]][[emploi]]
    # règle V en mode Kleene (#105, lot V, G1 ; assures : G2a)
    if (t == "assures") {
      fa <- .age_assure3(ctx, emploi, conv, mini, maxi)
      for (traitement in c("S", "X")) {
        .regle_vue(ctx, "D02c", t, "date_naissance", e$lit, traitement, "exacte", fa, colonne_ne = NA_character_,
                   vue = e$vue, mode = "kleene")
      }
    } else {
      f3 <- .age_invraisemblable3(ctx, t, conv, mini, maxi)
      for (traitement in c("S", "X")) {
        .regle_vue(ctx, "D02c", t, "date_naissance", e$lit, traitement, "exacte", f3, colonne_ne = NA_character_,
                   vue = e$vue, mode = "kleene")
      }
    }
  }
  if (sans_convention) .requerir(ctx, "conventions", "D02c", "age", paste(CONVENTIONS_AGE, collapse = ";"))
  invisible(NULL)
}

# D02c à trois valeurs pour un assuré (#105, lot V, G2a ; spécification `donnees`, erratum
# `1.9.7`, E-1 ; D-G2-2, exact par conditionnement, à titre provisoire) : emploi assures_sinistre
# (références : survenance de chaque sinistre de l'assuré) ou assures_affiliation (date de début
# de chaque affiliation, date d'effet de chaque contrat individuel de l'assuré). Références
# visibles (retenues) et non déterminées (présentes ou non, clé de leur table ; leur âge non
# défini n'est pas lu, comme la règle bloquée) ; contrat de nature refusée : référence possible
# (clé contrats.nature_contrat). Issue d'une référence : vrai (âge hors de [mini, maxi]), faux,
# indéfini (âge non défini) ; d'un assuré : vrai si une référence l'est, sinon indéfini si une
# l'est, sinon faux. La naissance, lue par toutes les références, est conditionnée : chacune de
# ses valeurs représentatives (bornes de la plage et points de rupture de chaque référence
# possible, .points_age3()) ; les références, indépendantes sachant la naissance, se combinent
# exactement (ensembles d'issues). Verdict : vrai si toute issue est vraie, faux si toutes
# fausses ou toutes indéfinies (attribut indefini_certain), inconnu sinon. Pertinence : la
# naissance par propagation de paires (.pertinence_paires3()) ; une cellule d'une référence si, pour une
# valeur de la naissance, elle change l'issue de sa référence d'une façon que les autres
# références possibles laissent voir. Sous-cas âge non défini : une référence visible certaine
# d'issue indéfinie quelle que soit la naissance (comme la règle bloquée sur valeurs connues).
# Assurés sans valeur inconnue ni référence non déterminée : calcul direct, identique à la règle
# bloquée.
.age_assure3 <- function(ctx, emploi, conv, mini, maxi) function() {
  v <- function(t, c1) .valeurs(ctx, t, c1)
  n <- NROW(ctx$base$assures)
  ordre_issue <- c("faux", "indefini", "vrai")
  issue <- function(nai, ref) {
    a <- calculer_age(structure(as.numeric(nai), class = "Date"), structure(as.numeric(ref), class = "Date"), conv)
    ifelse(!is.na(nai) & !is.na(ref) & is.na(a), "indefini", ifelse(!is.na(a) & (a < mini | a > maxi), "vrai", "faux"))
  }
  # références : table, ligne, assuré, date, date inconnue, présence (TRUE certaine, NA possible)
  refs <- list()
  ajouter <- function(t, col, presence_nature = NULL) {
    if (is.null(ctx$base[[t]])) return(invisible(NULL))
    m <- nrow(ctx$base[[t]])
    retenu <- ctx$retenu[[t]]
    nd <- .nd_vue(ctx, t)
    p <- apparier_cles(v(t, "id_assure"), v("assures", "id_assure"))
    presence <- rep(TRUE, m)
    cle_presence <- rep(NA_character_, m)
    if (!is.null(presence_nature)) {
      nat_u <- .inconnu(ctx, t, "nature_contrat")
      ind <- v(t, "nature_contrat") %in% "individuel"
      presence[!ind] <- FALSE
      presence[nat_u] <- NA
      cle_presence[nat_u] <- paste(t, "nature_contrat", sep = ".")
    }
    garde <- (retenu | nd) & !is.na(p) & !(presence %in% FALSE)
    if (!any(garde)) return(invisible(NULL))
    refs[[length(refs) + 1L]] <<- data.frame(table = t, colonne = col, ligne = which(garde), p = p[garde],
                                             date = as.numeric(v(t, col))[garde], date_u = .inconnu(ctx, t, col)[garde],
                                             nd = nd[garde] & !retenu[garde], presence_u = is.na(presence[garde]),
                                             cle_presence = cle_presence[garde], stringsAsFactors = FALSE)
  }
  if (emploi == "assures_sinistre") ajouter("sinistres", "date_survenance") else {
    ajouter("affiliations", "date_debut")
    ajouter("contrats", "date_effet", presence_nature = TRUE)
  }
  refs <- if (length(refs) > 0L) do.call(rbind, refs) else data.frame(p = integer(0))
  naissance <- as.numeric(v("assures", "date_naissance"))
  nai_u <- .inconnu(ctx, "assures", "date_naissance")
  r <- rep(FALSE, n)
  indefini_certain <- rep(FALSE, n)
  ip <- list()
  ajouter_ip <- function(tc, l, lignes) {
    if (is.null(ip[[tc]])) ip[[tc]] <<- vector("list", n)
    ip[[tc]][l] <<- list(sort(unique(c(ip[[tc]][[l]], lignes))))
  }
  certain_ndef <- FALSE
  plage_n <- .plage_date3(ctx, "assures", "date_naissance")
  plages <- list()
  for (z in unique(paste(refs$table, refs$colonne))) {
    m <- strsplit(z, " ", fixed = TRUE)[[1L]]
    plages[[z]] <- .plage_date3(ctx, m[1L], m[2L])
  }
  retenu_a <- ctx$retenu$assures
  # assurés sans inconnue ni référence non déterminée : calcul direct (vectoriel)
  complexe <- nai_u[refs$p] | refs$date_u | refs$nd | refs$presence_u
  lignes_c <- unique(refs$p[complexe])
  s1 <- which(!(refs$p %in% lignes_c))
  if (length(s1) > 0L) {
    o <- issue(naissance[refs$p[s1]], refs$date[s1])
    r[unique(refs$p[s1][o == "vrai"])] <- TRUE
    ndef <- unique(refs$p[s1][o == "indefini"])
    indefini_certain[ndef[!r[ndef]]] <- TRUE
    if (any(retenu_a[ndef])) certain_ndef <- TRUE
  }
  for (z in split(which(refs$p %in% lignes_c), refs$p[refs$p %in% lignes_c])) {
    l <- refs$p[z[1L]]
    x <- refs[z, , drop = FALSE]
    pl <- lapply(paste(x$table, x$colonne), function(k) plages[[k]])
    # valeurs représentatives de la naissance (conditionnement)
    n_dom <- if (nai_u[l]) {
      pts <- unlist(lapply(seq_len(nrow(x)), function(k) .points_age3(conv, mini, maxi, plage_n, if (x$date_u[k]) pl[[k]] else x$date[k])))
      unique(c(plage_n, pts[!is.na(pts) & pts >= plage_n[1L] & pts <= plage_n[2L]]))
    } else naissance[l]
    # issues d'une référence k sachant la naissance nv : ensemble, et cellules pertinentes
    ref_issues <- function(k, nv) {
      d_dom <- if (x$date_u[k]) {
        pts <- .points_age3(conv, mini, maxi, pl[[k]], nv, ref = TRUE)
        unique(c(pl[[k]], pts[!is.na(pts) & pts >= pl[[k]][1L] & pts <= pl[[k]][2L]]))
      } else x$date[k]
      o <- issue(rep(nv, length(d_dom)), d_dom)
      if (x$nd[k]) o[o == "indefini"] <- "faux"
      present <- unique(o)
      absent <- x$nd[k] || x$presence_u[k]
      list(issues = unique(c(present, if (absent) "faux")), present = present, date = length(present) > 1L,
           presence = absent && any(present != "faux"))
    }
    combine <- function(sets) {
      possible <- character(0)
      if (any(vapply(sets, function(s1) "vrai" %in% s1, NA))) possible <- "vrai"
      if (all(vapply(sets, function(s1) "faux" %in% s1, NA))) possible <- c(possible, "faux")
      if (all(vapply(sets, function(s1) any(c("faux", "indefini") %in% s1), NA)) &&
          any(vapply(sets, function(s1) "indefini" %in% s1, NA))) possible <- c(possible, "indefini")
      possible
    }
    par_n <- lapply(n_dom, function(nv) lapply(seq_len(nrow(x)), ref_issues, nv))
    ens <- lapply(par_n, function(e) combine(lapply(e, `[[`, "issues")))
    tout <- unique(unlist(ens))
    r[l] <- if (identical(tout, "vrai")) TRUE else if (all(tout == "faux") || identical(tout, "indefini")) FALSE else NA
    indefini_certain[l] <- identical(tout, "indefini")
    # sous-cas âge non défini : référence visible certaine, indéfinie pour toute naissance
    for (k in seq_len(nrow(x))) {
      if (retenu_a[l] && !x$nd[k] && !x$presence_u[k] && all(vapply(par_n, function(e) identical(e[[k]]$issues, "indefini"), NA))) {
        certain_ndef <- TRUE
      }
    }
    if (!is.na(r[l])) next
    # naissance (cellule conditionnée) : propagation de paires (.pertinence_paires3()), couples de
    # chaque référence sur les mêmes valeurs de sa date (points de rupture relatifs aux deux
    # naissances) et de sa présence
    if (nai_u[l]) {
      couples_ref <- function(n1, n2) lapply(seq_len(nrow(x)), function(k) {
        d_dom <- if (x$date_u[k]) {
          pts <- c(.points_age3(conv, mini, maxi, pl[[k]], n1, ref = TRUE), .points_age3(conv, mini, maxi, pl[[k]], n2, ref = TRUE))
          unique(c(pl[[k]], pts[!is.na(pts) & pts >= pl[[k]][1L] & pts <= pl[[k]][2L]]))
        } else x$date[k]
        o1 <- issue(rep(n1, length(d_dom)), d_dom)
        o2 <- issue(rep(n2, length(d_dom)), d_dom)
        if (x$nd[k]) { o1[o1 == "indefini"] <- "faux"; o2[o2 == "indefini"] <- "faux" }
        m <- cbind(o1, o2)
        if (x$nd[k] || x$presence_u[k]) m <- rbind(m, c("faux", "faux"))
        unique(m)
      })
      maximum <- function(a, b) ordre_issue[pmax(match(a, ordre_issue), match(b, ordre_issue))]
      if (.pertinence_paires3(as.list(n_dom), couples_ref, maximum, "faux")) ajouter_ip("assures.date_naissance", l, l)
    }
    for (e in par_n) {
      for (k in seq_len(nrow(x))) {
        # issues des autres références : la cellule de k est visible si deux issues de k
        # diffèrent après combinaison avec une issue possible des autres
        autres <- combine(lapply(e[-k], `[[`, "issues"))
        if (length(autres) == 0L) autres <- "faux"
        # deux issues de k distinguables : une issue y des autres pour laquelle max(o1, y) et
        # max(o2, y) diffèrent
        distingue <- function(s1) any(vapply(autres, function(y) {
          length(unique(vapply(s1, function(o) ordre_issue[max(match(c(o, y), ordre_issue))], ""))) > 1L
        }, NA))
        if (e[[k]]$date && distingue(e[[k]]$present)) {
          ajouter_ip(paste(x$table[k], x$colonne[k], sep = "."), l, x$ligne[k])
        }
        if (e[[k]]$presence && distingue(c("faux", setdiff(e[[k]]$issues, "faux")))) {
          ajouter_ip(if (x$nd[k]) x$table[k] else x$cle_presence[k], l, x$ligne[k])
        }
      }
    }
  }
  if (certain_ndef) .ajouter_non_execute(ctx, "D02c", "assures", NA_character_, .CAUSE_AGE_NON_DEFINI)
  attr(r, "index") <- ip
  attr(r, "index_pertinent") <- ip
  attr(r, "indefini_certain") <- indefini_certain
  # colonnes lues, statiques par emploi (garde de .regle_vue() : une table sans référence retenue
  # ni non déterminée est lue tout de même)
  attr(r, "lues") <- c("assures.date_naissance", if (emploi == "assures_sinistre") "sinistres.date_survenance" else
                         c("affiliations.date_debut", "contrats.date_effet", "contrats.nature_contrat"))
  r
}

# D02c à trois valeurs (#105, lot V, G1 ; spécification `donnees`, erratum `1.9.7`, E-1) pour
# les emplois de famille, designations et ayants_droit_sante : âge (calculer_age(), convention
# `conv`) de la date de naissance à la date de référence (famille : survenance du sinistre
# rattaché, sans sinistre la date de saisie ; sinon la date de saisie), hors de [mini, maxi] ;
# membre à naître hors du contrôle ; âge non défini (référence avant la naissance) : non
# détecté, et sous-cas âge non défini (.CAUSE_AGE_NON_DEFINI) lu sur les seules valeurs connues,
# comme la règle bloquée. Verdict non monotone en la naissance (intervalle d'âge) : domaine
# propre à la ligne (.points_age3()), bornes des plages et dates où l'âge franchit mini et maxi
# ou devient non défini, pour chaque référence possible (connue, ou bornes de sa plage) ; même
# construction pour une référence inconnue. L'âge étant monotone en chaque date, un
# représentant par région suffit (exact) ; deux dates inconnues : exact par l'argument du bord
# (issues atteintes sur le rectangle des plages = issues de ses quatre bords), vérifié par
# énumération (constat). Âge non défini : troisième issue, verdict inconnu dès qu'il se mêle à
# une autre issue (.verdict3_indefini() ; R-G1-2 d'`actuary`, option (a), à titre provisoire) ;
# aucune ligne âge non défini n'est émise pour une ligne qui lit une valeur inconnue.
.age_invraisemblable3 <- function(ctx, t, conv, mini, maxi) function() {
  vv <- function(t1, c1) .valeurs_vue(ctx, t1, c1)
  famille <- t == "famille"
  n <- NROW(ctx$base[[t]])
  naissance0 <- .date3(ctx, paste0(t, ".date_naissance"))
  saisie0 <- .date3(ctx, paste0(t, ".date_saisie"))
  plage_n <- .plage_date3(ctx, t, "date_naissance")
  plage_saisie <- .plage_date3(ctx, t, "date_saisie")
  sinistre <- if (famille) vv("famille", "id_sinistre") else rep(NA_character_, n)
  if (famille) {
    ix <- .index_jointure(ctx, "sinistres", "id_sinistre", sinistre)
    surv0 <- .date3(ctx, "sinistres.date_survenance", index = ix)
    plage_s <- .plage_date3(ctx, "sinistres", "date_survenance")
  }
  # références possibles et naissances possibles de chaque ligne (points de rupture)
  ref_inconnue <- function(l) if (famille && !is.na(sinistre[l])) surv0$inconnu[l] else saisie0$inconnu[l]
  refs <- function(l) {
    if (famille && !is.na(sinistre[l])) {
      if (surv0$inconnu[l]) plage_s else surv0$valeurs[l]
    } else if (saisie0$inconnu[l]) plage_saisie else saisie0$valeurs[l]
  }
  naissances <- function(l) if (naissance0$inconnu[l]) plage_n else naissance0$valeurs[l]
  pts_n <- lapply(seq_len(n), function(l) if (naissance0$inconnu[l]) .points_age3(conv, mini, maxi, plage_n, refs(l)))
  pts_r <- function(plage) lapply(seq_len(n), function(l) if (ref_inconnue(l)) .points_age3(conv, mini, maxi, plage, naissances(l), ref = TRUE))
  entrees <- list(naissance = .date3(ctx, paste0(t, ".date_naissance"), points_ligne = pts_n),
                  saisie = .date3(ctx, paste0(t, ".date_saisie"), points_ligne = pts_r(plage_saisie)),
                  sinistre = .connue3("famille.id_sinistre", sinistre))
  if (famille) {
    entrees$survenance <- .date3(ctx, "sinistres.date_survenance", index = ix, points_ligne = pts_r(plage_s))
    entrees$situation <- .entree3(ctx, "famille.situation")
  }
  # trois issues par affectation (R-G1-2 d'`actuary`, option (a), appliquée à titre provisoire) :
  # âge hors bornes (vrai), dans les bornes ou hors du contrôle (faux), âge non défini (naissance
  # et référence présentes, naissance postérieure à la référence)
  r <- .verdict3_indefini(entrees, function(v) {
    ref <- if (famille) ifelse(is.na(v$sinistre), v$saisie, v$survenance) else v$saisie
    age <- calculer_age(structure(as.numeric(v$naissance), class = "Date"), structure(as.numeric(ref), class = "Date"), conv)
    valide <- if (famille) !(v$situation %in% "a_naitre") else rep(TRUE, length(age))
    ifelse(valide & !is.na(v$naissance) & !is.na(ref) & is.na(age), "indefini",
           ifelse(valide & !is.na(age) & (age < mini | age > maxi), "vrai", "faux"))
  })
  # sous-cas âge non défini (§ 5.2 ; Q-a d'`actuary`, à titre provisoire) : une ligne de la
  # population (retenue ; un membre à naître est hors du contrôle, issue fausse) d'issue
  # indéfinie déterminée (attribut indefini_certain : ligne connue d'âge non défini, ou toutes
  # les affectations indéfinies), une seule définition. Ce second cas n'est pas atteint par une
  # base : une date connue est dans sa plage (naissance à partir du 1901-01-01, référence au plus
  # l'extraction), et la borne basse de la naissance, ou la borne haute de la référence, donne un
  # âge défini (comme le chemin D01a, #169)
  if (any(ctx$retenu[[t]] & attr(r, "indefini_certain"))) .ajouter_non_execute(ctx, "D02c", t, NA_character_, .CAUSE_AGE_NON_DEFINI)
  r
}
# Points de rupture de « âge hors de [mini, maxi] » (calculer_age(), convention `conv`) : pour
# une naissance inconnue (plage `plage`) et chaque référence de `autres`, les naissances où
# l'âge franchit mini et maxi (dernière naissance du côté le plus âgé, et le lendemain), et la
# référence (au-delà, âge non défini) ; `ref` : pour une référence inconnue et chaque naissance de
# `autres`, les références où l'âge franchit mini et maxi (veille et jour), et la naissance (âge
# non défini avant). L'âge est monotone en chaque date (recherche dichotomique, en jours).
.points_age3 <- function(conv, mini, maxi, plage, autres, ref = FALSE) {
  en_date <- function(x) structure(as.numeric(x), class = "Date")
  pts <- numeric(0)
  for (a in autres[!is.na(autres)]) {
    age <- function(x) {
      if (ref) calculer_age(en_date(a), en_date(x), conv) else calculer_age(en_date(x), en_date(a), conv)
    }
    for (seuil in list(function(z) !is.na(z) & z >= mini, function(z) !is.na(z) & z > maxi)) {
      # naissance : seuil vrai pour les petites dates ; référence : pour les grandes
      bas <- plage[1L]
      haut <- plage[2L]
      vrai_bas <- seuil(age(bas))
      vrai_haut <- seuil(age(haut))
      if (vrai_bas == vrai_haut) next
      while (haut - bas > 1) {
        milieu <- floor((bas + haut) / 2)
        if (seuil(age(milieu)) == vrai_bas) bas <- milieu else haut <- milieu
      }
      pts <- c(pts, bas, haut)
    }
    pts <- c(pts, a - 1, a, a + 1)
  }
  pts
}

# D07 (c), fin de charge non enregistrée (dictionnaire, § 9 ; spécification, §§ 5.3 et 5.4),
# sur la vue : rente d'éducation non éteinte, en service ou suspendue (rentes ; statut de
# service commun, .statut_service(), spécification `donnees` v1.6, § 8.0 bis, point 3), ou
# dossier double_effet non clos
# (dossiers ; ni clos ni de second décès retenu) dont chaque enfant à charge a atteint sa
# limite d'âge à l'arrêté : âge (conventions$limite_age$age, naissance réelle) au moins égal à
# age_limite (age_limite_etudes pour un enfant scolarise ou apprenti, si le paramètre existe),
# plus 1 sous la règle `depassement` ;
# extinction équivalente à date_atteinte_age(naissance, limite, convention) <= A. Enfant à
# charge : ligne valable de famille, lien enfant, non décédé à l'arrêté ; celui de la rente
# (rentes.id_membre), ceux de l'assuré du sinistre pour le double effet. Un enfant handicape
# sous prolongation_handicap, ou de naissance manquante (D03a), n'est jamais éteint ; une
# limite non déterminable (paramètre absent ou à valeurs distinctes) non plus, et la table va
# dans controles_non_executes (.CAUSE_PARAMETRE_NON_DEFINI) si la limite peut décider de la
# détection (dossiers : aucun autre enfant non éteint de façon déterminée ; rentes : un seul
# enfant, toujours). Traitement
# H ou S. Sans conventions$limite_age : non exécuté (cause declaration_absente) et
# déclaration requise (rubrique conventions, cles limite_age$regle et limite_age$age), s'il
# existe au moins une ligne candidate (.candidats_d07c()) ; sans ligne candidate, exécuté à
# vide, sans exigence (spécification de B2, docs/specifications/b2-capital-deces-v1.md,
# § 6.3, niveau 1 : une déclaration qui ne peut changer aucune ligne du bilan ne bloque pas).
# Constat sur la table qui porte la charge (rentes, dossiers), colonne NA, code D07c (lettrage
# du dictionnaire 1.6, M660 ; une clé par sous-cas, spécification `donnees` v1.9, § 9.6). Sans
# déclaration, chaque table non exécutée reçoit aussi les causes candidates de la règle bloquée
# de la branche déclarée (mêmes colonnes lues, `lit` et `vue_commun`, définies une fois ;
# .regle_vue() sans `f`) : une cause directe (rang 3) l'emporte sur declaration_absente (rang
# 6), qui reste dans declarations_requises (spécification `donnees` v1.9.1, § 9.6, point (3)).
.regle_v_limite_age <- function(ctx) {
  tables <- intersect(c("rentes", "dossiers"), names(ctx$base))
  la <- ctx$conventions$limite_age
  # colonnes lues par la règle, par table (une seule définition pour les deux branches)
  ev_lus <- paste0("evenements.", c("id_evenement", "type_evenement", "date_effet", "date_saisie"))
  lit_commun <- c("dossiers.id_dossier", "dossiers.id_garantie_souscrite", "garanties_souscrites.id_garantie_souscrite",
                  "garanties_souscrites.code_garantie", "garanties_souscrites.prolongation_handicap",
                  "parametres.id_garantie_souscrite", "parametres.parametre", "parametres.valeur", "famille.id_membre",
                  "famille.lien", "famille.date_naissance", "famille.situation", "famille.date_deces", ev_lus)
  lit <- list(rentes = c("rentes.id_rente", "rentes.id_dossier", "rentes.id_membre", "evenements.id_rente", lit_commun),
              dossiers = c("dossiers.id_sinistre", "sinistres.id_sinistre", "sinistres.id_assure", "famille.id_assure",
                           "evenements.id_dossier", lit_commun))
  # colonnes lues pour établir la vue de famille, parametres et evenements (.regle_vue())
  vue_commun <- c(ctx$lit_vue$famille, ctx$lit_vue$parametres, ctx$lit_vue$evenements)
  if (is.null(la)) {
    if (!.candidats_d07c(ctx)) return(invisible(NULL))
    for (t in tables) {
      .ajouter_non_execute(ctx, "D07c", t, NA_character_, "declaration_absente")
      .regle_vue(ctx, "D07c", t, NA_character_, lit[[t]], "H;S", "exacte", NULL, vue = vue_commun)
    }
    if (length(tables) > 0L) {
      .requerir(ctx, "conventions", "D07c", "limite_age$regle", paste(REGLES_LIMITE_AGE, collapse = ";"))
      .requerir(ctx, "conventions", "D07c", "limite_age$age", paste(CONVENTIONS_LIMITE_AGE, collapse = ";"))
    }
    return(invisible(NULL))
  }
  v <- function(t, c1) .valeurs(ctx, t, c1)
  vv <- function(t, c1) .valeurs_vue(ctx, t, c1)
  a <- as.numeric(ctx$arrete)
  gs_de <- function(dossier) .joindre(ctx, "dossiers", "id_dossier", "id_garantie_souscrite", dossier)
  code_de <- function(gs) .joindre(ctx, "garanties_souscrites", "id_garantie_souscrite", "code_garantie", gs)
  # Les colonnes ne sont lues (et converties) que dans les fonctions passées à .regle_vue(),
  # après le contrôle des causes des colonnes lues (aucune conversion d'une colonne refusée).
  # enfant éteint à l'arrêté (paires enfant de famille, garantie souscrite) : .enfant_eteint(),
  # seule implémentation, lue aussi par D14 (à la survenance)
  eteint <- function(m, gs, val = vv) .enfant_eteint(ctx, la, m, gs, rep(ctx$arrete, length(m)), val)
  # limite non déterminable pour une ligne candidate : la table va dans controles_non_executes
  # (colonne NA, cause parametre_non_defini) ; les autres lignes restent contrôlées
  noter <- function(t, e) {
    if (any(e$non_defini)) .ajouter_non_execute(ctx, "D07c", t, NA_character_, .CAUSE_PARAMETRE_NON_DEFINI)
    e$eteint
  }
  # enfant à charge : ligne valable dans la vue, lien enfant, non décédé à l'arrêté (`val` = v :
  # sur toute version, valeurs brutes)
  a_charge <- function(val = vv) {
    deces <- as.numeric(val("famille", "date_deces"))
    !is.na(val("famille", "id_membre")) & val("famille", "lien") %in% "enfant" & (is.na(deces) | deces > a)
  }
  # verdict à trois valeurs (spécification v1.5, § 2.2 (d) ; M218) : événements non déterminés de
  # type `types`, d'effet au plus l'arrêté ou inconnu (seuls ils peuvent être retenus)
  ev_nd <- function(types) {
    effet <- .date_connue(ctx, "evenements", "date_effet")
    which(.nd_vue(ctx, "evenements") & v("evenements", "type_evenement") %in% types & !((effet > a) %in% TRUE))
  }
  # versions de famille dont l'état est en jeu : candidates d'un membre à version valable non
  # déterminée (.visibilite_a()), et versions non déterminées d'un membre sans version visible
  vis_f <- if ("famille" %in% names(ctx$base)) .visibilite_a(ctx, "vue") else NULL
  fam_nd <- function() .famille_en_jeu(ctx)
  # verdict de la vue `r` gardé tel quel sans élément en jeu (`en_jeu` faux) ; sinon,
  # conjonction à trois valeurs (.verdict3()) de ses entrées
  garder <- function(r, en_jeu, entrees, g) if (en_jeu) .verdict3(entrees, g) else r
  # événements de la vue de date d'effet au plus l'arrêté
  evenements_retenus <- function() {
    type <- vv("evenements", "type_evenement")
    effet <- as.numeric(vv("evenements", "date_effet"))
    list(type = type, retenu = !is.na(type) & !is.na(effet) & effet <= a)
  }
  .regle_vue(ctx, "D07c", "rentes", NA_character_, lit$rentes, "H;S", "exacte", function() {
    nr <- nrow(ctx$base$rentes)
    # rente non éteinte à l'arrêté (en service ou suspendue) : statut de service commun à D07 (a),
    # (b) et (c) (.statut_service(), spécification `donnees` v1.6, § 8.0 bis, point 3)
    st <- .statut_service(ctx, "rentes")
    en_service <- st$classe %in% .NON_ETEINT
    gs <- gs_de(v("rentes", "id_dossier"))
    # clés appariées : une clé manquante ou vide ne s'apparie à rien (apparier_cles(), #158)
    m <- apparier_cles(v("rentes", "id_membre"), vv("famille", "id_membre"))
    education <- code_de(gs) %in% "rente_education"
    ok <- education & en_service & !is.na(m)
    ok[ok] <- a_charge()[m[ok]]
    if (any(ok)) ok[ok] <- noter("rentes", eteint(m[ok], gs[ok]))
    # « non éteinte » inconnu si un événement non déterminé qui peut suivre le dernier retenu dans
    # l'ordre du § 4.2 est d'une autre classe (.service3())
    s3 <- .service3(ctx, st, .NON_ETEINT)
    # enfant : version valable dans la vue, ou chaque candidate d'un membre à version valable non
    # déterminée ; inconnu si elles diffèrent
    enfant <- !is.na(m)
    enfant[enfant] <- a_charge()[m[enfant]]
    if (any(enfant)) enfant[enfant] <- eteint(m[enfant], gs[enfant])$eteint
    index_e <- vector("list", nr)
    cand <- if (is.null(vis_f$candidate)) integer(0) else which(vis_f$candidate)
    sans_m <- which(is.na(m) & !is.na(apparier_cles(v("rentes", "id_membre"), vis_f$membre[cand])))
    cand_m <- split(cand, vis_f$membre[cand])[as.character(v("rentes", "id_membre"))[sans_m]]
    for (k in seq_along(sans_m)) {
      i <- sans_m[k]
      cm <- cand_m[[k]]
      x <- a_charge(v)[cm]
      x[x] <- eteint(cm[x], rep(gs[i], sum(x)), v)$eteint
      visible <- vis_f$statut$famille[cm] %in% TRUE
      enfant[i] <- x[visible][1L]
      if (length(unique(x)) > 1L) index_e[[i]] <- cm[!visible & x != enfant[i]]
    }
    e3 <- list(tc = "famille", valeurs = enfant, inconnu = lengths(index_e) > 0L, index = index_e, domaine = c(TRUE, FALSE))
    garder(ok, st$nd > 0L || length(cand) > 0L, list(education = .connue3("education", education), s = s3, e = e3),
           function(x) x$education & x$s & x$e)
  }, vue = vue_commun)
  # double effet : un dossier clos, ou dont le second décès est retenu à l'arrêté (le droit
  # au capital s'y fixe, avis d'`actuary`, Q3 (b)), n'est pas candidat
  .regle_vue(ctx, "D07c", "dossiers", NA_character_, lit$dossiers, "H;S", "exacte", function() {
    nd <- nrow(ctx$base$dossiers)
    ev <- evenements_retenus()
    gs <- v("dossiers", "id_garantie_souscrite")
    fin <- ev$retenu & ev$type %in% c("cloture_dossier", "second_deces")
    clos <- !is.na(apparier_cles(v("dossiers", "id_dossier"), v("evenements", "id_dossier")[fin]))
    double_effet <- code_de(gs) %in% "double_effet"
    candidat <- double_effet & !clos
    base <- function() {
      if (!any(candidat)) return(rep(FALSE, nd))
      assure <- .joindre(ctx, "sinistres", "id_sinistre", "id_assure", v("dossiers", "id_sinistre"))
      assure[!candidat] <- NA
      enfants <- which(a_charge())
      p <- .paires(assure, vv("famille", "id_assure")[enfants])
      if (nrow(p) == 0L) return(rep(FALSE, nd))
      x <- eteint(enfants[p$j], gs[p$i])
      nb <- tabulate(p$i, nd)
      nb_eteints <- tabulate(p$i[x$eteint], nd)
      # la limite non déterminable n'est notée que si elle peut décider de la détection : aucun
      # enfant du dossier non éteint de façon déterminée (avis d'`actuary`) ; un tel enfant
      # (limite déterminée non atteinte, handicapé sous prolongation, naissance manquante)
      # écarte le dossier quel que soit l'enfant ambigu
      bloque <- tabulate(p$i[!x$eteint & !x$non_defini], nd) > 0L
      noter("dossiers", list(eteint = x$eteint, non_defini = x$non_defini & !bloque[p$i]))
      candidat & nb > 0L & nb_eteints == nb
    }
    r <- base()
    # « candidat » inconnu si une clôture ou un second décès non déterminé (effet au plus
    # l'arrêté ou inconnu) existe
    kn <- ev_nd(c("cloture_dossier", "second_deces"))
    pc <- rep(FALSE, NROW(ctx$base$evenements))
    pc[kn] <- TRUE
    clos3 <- .existe_vue3(ctx, "evenements", v("dossiers", "id_dossier"), v("evenements", "id_dossier"), fin | pc)
    # « chaque enfant à charge éteint » (au moins un) : par membre de l'assuré, catégories
    # possibles (hors charge, éteint, non éteint) de sa version valable, de chaque candidate, ou
    # de chaque version non déterminée d'un membre sans version visible (hors charge compris) ;
    # vrai possible si chaque membre peut être hors charge ou éteint et l'un éteint ; faux
    # possible si l'un peut être non éteint, ou tous hors charge
    enjeu_f <- fam_nd()
    index_e <- vector("list", nd)
    e_val <- r
    if (any(enjeu_f)) {
      assure <- .joindre(ctx, "sinistres", "id_sinistre", "id_assure", v("dossiers", "id_sinistre"))
      assure[!(double_effet & !(clos3$valeurs))] <- NA
      lignes_f <- which(ctx$retenu$famille | enjeu_f)
      p <- .paires(assure, v("famille", "id_assure")[lignes_f])
      if (nrow(p) > 0L) {
        j <- lignes_f[p$j]
        charge <- a_charge(v)[j]
        cat_f <- ifelse(!charge, "hors", "non_eteint")
        if (any(charge)) cat_f[charge][eteint(j[charge], gs[p$i][charge], v)$eteint] <- "eteint"
        sans_visible <- enjeu_f[j] & !vis_f$candidate[j]
        membre <- paste(p$i, vis_f$membre[j], sep = "\r")
        possibles <- split(c(cat_f, rep("hors", sum(sans_visible))), c(membre, membre[sans_visible]))
        de_i <- as.integer(sub("\r.*$", "", names(possibles)))
        peut <- function(cat) vapply(possibles, function(z) cat %in% z, NA)
        peut_ok <- peut("hors") | peut("eteint")
        vrai <- tapply(peut_ok, de_i, all) & tapply(peut("eteint"), de_i, any)
        faux <- tapply(peut("non_eteint"), de_i, any) | tapply(peut("hors"), de_i, all)
        i_vrai <- as.integer(names(vrai))
        e_val[i_vrai] <- vrai & !faux
        # incertitude : un membre a plusieurs catégories possibles, ce que seule une version non
        # déterminée en jeu permet (candidate, ou version d'un membre sans version visible)
        incertain <- i_vrai[vrai & faux]
        nd_j <- enjeu_f[j] & !(vis_f$statut$famille[j] %in% TRUE) & p$i %in% incertain
        index_e[incertain] <- lapply(split(j[nd_j], factor(p$i[nd_j], levels = incertain)), function(z) sort(unique(z)))
      }
    }
    e3 <- list(tc = "famille", valeurs = e_val, inconnu = lengths(index_e) > 0L, index = index_e, domaine = c(TRUE, FALSE))
    garder(r, length(kn) > 0L || any(enjeu_f), list(de = .connue3("de", double_effet), clos = clos3, e = e3),
           function(x) x$de & !x$clos & x$e)
  }, vue = vue_commun)
  invisible(NULL)
}

# Existence d'au moins une ligne candidate de D07 (c) (spécification de B2, § 6.3, niveau 1) :
# une ligne de rentes, dans la vue (retenue ou de visibilité non déterminée, .nd_vue()), dont
# le dossier relève d'une garantie souscrite rente_education, ou une ligne de dossiers, dans la
# vue, de garantie souscrite double_effet (jointure sur les valeurs brutes, comme D07 (c)). Si
# une colonne de la jointure ne se lit pas (refus de forme, de valeur ou de portée table,
# .cause()), chaque ligne de la table compte comme candidate (sens prudent : la déclaration
# est demandée). Rend TRUE ou FALSE.
.candidats_d07c <- function(ctx) {
  code_lus <- c("garanties_souscrites.id_garantie_souscrite", "garanties_souscrites.code_garantie")
  candidats <- function(table, lus, code, gs_de) {
    n <- NROW(ctx$base[[table]])
    if (n == 0L) return(FALSE)
    if (!is.null(.cause_lecture(ctx, c(lus, code_lus)))) return(TRUE)
    dans_vue <- ctx$retenu[[table]] | .nd_vue(ctx, table)
    gs <- gs_de()
    any(dans_vue & .joindre(ctx, "garanties_souscrites", "id_garantie_souscrite", "code_garantie", gs) %in% code)
  }
  gs_rentes <- function() {
    dossier <- .valeurs(ctx, "rentes", "id_dossier")
    .joindre(ctx, "dossiers", "id_dossier", "id_garantie_souscrite", dossier)
  }
  candidats("rentes", c("rentes.id_dossier", "dossiers.id_dossier", "dossiers.id_garantie_souscrite"),
            "rente_education", gs_rentes) ||
    candidats("dossiers", "dossiers.id_garantie_souscrite", "double_effet",
              function() .valeurs(ctx, "dossiers", "id_garantie_souscrite"))
}

# Paramètre `nom` de la garantie souscrite `gs` (valeurs de garanties_souscrites.id_garantie_souscrite),
# dans la vue : `valeur` (NA s'il manque ou prend plusieurs valeurs) et `ambigu` (plusieurs
# valeurs) ; une passe par paramètre (split()), gardée dans le contexte pour l'appel. Lue par
# .enfant_eteint() (D07 (c), D14).
.parametre_garantie <- function(ctx, nom, gs) {
  cle <- paste0("parametre_garantie_", nom)
  pr <- ctx[[cle]]
  if (is.null(pr)) {
    v <- function(c1) .valeurs(ctx, "parametres", c1)
    k <- which(.valeurs_vue(ctx, "parametres", "parametre") %in% nom & cle_renseignee(v("id_garantie_souscrite")))
    z <- lapply(split(v("valeur")[k], as.character(v("id_garantie_souscrite")[k])), unique)
    pr <- list(u = names(z), n = lengths(z, use.names = FALSE),
               valeur = vapply(z, function(x) if (length(x) == 1L) x else NA_real_, 0, USE.NAMES = FALSE))
    assign(cle, pr, envir = ctx)
  }
  i <- apparier_cles(gs, pr$u)
  list(valeur = pr$valeur[i], ambigu = !is.na(i) & pr$n[i] > 1L)
}

# Enfant éteint à la date `date` (Date, une par élément) sous la règle de limite d'âge `la`
# (conventions$limite_age), seule implémentation, lue par D07 (c) (à l'arrêté) et D14 (à la
# survenance, spécification `donnees` v1.6, § 8.9) : pour chaque paire (ligne de famille `m`,
# garantie souscrite `gs`), `eteint`, et `non_defini` (limite non déterminable pour un enfant dont
# elle décide : âge connu, hors prolongation pour handicap ; paramètre absent ou à plusieurs
# valeurs, avis d'`actuary`, Q3 (a)). Prolongation pour études : enfant scolarise ou apprenti
# (décision du mainteneur, jugement d'expert : l'apprentissage vaut poursuite d'études, comme
# pour la rente d'éducation du recensement des méthodes) ; sans age_limite_etudes, age_limite.
# `val` : lecture des colonnes de famille (valeurs de la vue, ou brutes pour une version non
# déterminée). `sous` (lu par D14) : enfant sous sa limite de façon déterminée (prolongation pour
# handicap, ou âge connu et limite déterminée non atteinte).
.enfant_eteint <- function(ctx, la, m, gs, date, val) {
  situation <- val("famille", "situation")[m]
  etudes_ok <- situation %in% c("scolarise", "apprenti")
  l1 <- .parametre_garantie(ctx, "age_limite", gs)
  l2 <- .parametre_garantie(ctx, "age_limite_etudes", gs)
  limite <- ifelse(etudes_ok & !is.na(l2$valeur), l2$valeur, l1$valeur)
  limite[etudes_ok & l2$ambigu] <- NA_real_
  limite <- limite + (la$regle == "depassement")
  age <- calculer_age(val("famille", "date_naissance")[m], date, la$age)
  handicap <- .joindre(ctx, "garanties_souscrites", "id_garantie_souscrite", "prolongation_handicap", gs) %in% TRUE &
    situation %in% "handicape"
  decide <- !is.na(age) & !handicap
  list(eteint = decide & !is.na(limite) & age >= limite, non_defini = decide & is.na(limite),
       sous = handicap | (decide & !is.na(limite) & age < limite))
}

# Versions de famille dont l'état est en jeu dans la vue (vecteur logique sur les lignes de
# famille) : candidates d'un membre à version valable non déterminée (.visibilite_a()), et
# versions non déterminées d'un membre sans version visible. Lue par D07 (c) et D14.
.famille_en_jeu <- function(ctx) {
  vis <- if ("famille" %in% names(ctx$base)) .visibilite_a(ctx, "vue") else NULL
  if (is.null(vis$membre)) return(rep(FALSE, NROW(ctx$base$famille)))
  st <- vis$statut$famille
  sans_visible <- !(vis$membre %in% vis$membre[st %in% TRUE])
  vis$candidate | (.nd_vue(ctx, "famille") & sans_visible)
}

# --- Contrôles écrits à la fermeture partielle de #34 (spécification `donnees` v1.6, § 8) ------

# Statut de service à l'arrêté (spécification `donnees` v1.6.2, § 8.0 bis, point 3) : classe du
# dernier événement retenu d'une rente ou d'un dossier incapacite, parmi service
# (.TYPES_SERVICE), suspension et extinction (fin_service ; pour un dossier incapacite, sortie de
# son sinistre et cloture_dossier du dossier, quel qu'en soit le motif) ; « non ouvert » sans
# événement. reouverture_dossier, comme rechute, ne porte pas de classe : seul un événement de
# service postérieur rend au dossier la classe service (jugement d'expert visé le 13 novembre
# 2026 : un dossier clos ne sert plus de prestation). Une rente dont le dossier est clos sans
# fin_service garde la classe de ses propres événements. D07 (a) et (c) et D10 (f) visent « non
# éteint » (.NON_ETEINT), D07 (b) « service ».
.TYPES_SERVICE <- c("ouverture_service", "modification_montant", "reprise_service")
.NON_ETEINT <- c("service", "suspension")
.classe_service <- function(type) {
  ifelse(type %in% .TYPES_SERVICE, "service",
         ifelse(type %in% "suspension", "suspension",
                ifelse(type %in% c("fin_service", "sortie", "cloture_dossier"), "extinction", NA_character_)))
}

# Événements non déterminés `e` (lignes de evenements) qui peuvent suivre, dans l'ordre du § 4.2
# (date d'effet, ordre du type, date de saisie, identifiant), l'événement retenu `d` de même
# rang (NA : aucun événement retenu, tout événement suit) ; une valeur absente ou inconnue
# (.date_connue()) peut suivre. Rend un vecteur logique de la longueur de `e`.
.peut_suivre <- function(ctx, e, d) {
  if (length(e) == 0L) return(logical(0))
  te <- ctx$dico$types_evenements
  cle_tri <- function(c1, x) if (c1 == "type_evenement") te$ordre[match(x, te$type_evenement)] else x
  suit <- is.na(d)
  egal <- !suit
  for (c1 in c("date_effet", "type_evenement", "date_saisie", "id_evenement")) {
    x <- .valeurs(ctx, "evenements", c1)
    if (c1 %in% c("date_effet", "date_saisie")) x <- .date_connue(ctx, "evenements", c1)
    xe <- cle_tri(c1, x[e])
    xd <- cle_tri(c1, x[ifelse(is.na(d), 1L, d)])
    plus <- if (is.character(xe)) mapply(function(y, z) order(c(z, y), method = "radix")[1L] == 1L && y != z, xe, xd)
            else xe > xd
    suit <- suit | (egal & (is.na(xe) | plus %in% TRUE))
    egal <- egal & !is.na(xe) & !is.na(xd) & xe == xd
  }
  suit
}

# Statut de service à l'arrêté de chaque ligne de `table` (rentes, ou dossiers ; spécification
# `donnees` v1.6, § 8.0 bis, point 3), seule implémentation, lue par D07 (a), (b) et (c) (et
# D10 (f)) : `classe` (« service », « suspension », « extinction », « non_ouvert »), classe du
# dernier événement retenu dans la vue de date d'effet au plus l'arrêté, dans l'ordre de
# .dernier_evenement() ; événements de la rente (evenements.id_rente), ou du dossier
# (evenements.id_dossier, cloture_dossier comprise) et sortie de son sinistre
# (evenements.id_sinistre ; seul un dossier incapacite en est l'objet, la garantie est lue par
# l'appelant). `dernier` : ligne de cet
# événement ; `suivants` : par ligne, événements non déterminés de la vue (.nd_vue()) de ces types,
# d'effet au plus l'arrêté ou inconnu, qui peuvent le suivre (.peut_suivre()) ; `nd` : nombre
# d'événements non déterminés de ces types. Lit les colonnes de clé et evenements.id_evenement,
# type_evenement, date_effet, date_saisie : appelée dans les fonctions passées à .regle_vue(),
# après le contrôle des colonnes lues. Calculé une fois par appel et par table.
.statut_service <- function(ctx, table) {
  nom <- paste0("service_", table)
  if (!is.null(ctx[[nom]])) return(ctx[[nom]])
  a <- as.numeric(ctx$arrete)
  n <- NROW(ctx$base[[table]])
  ev <- function(c1) .valeurs(ctx, "evenements", c1)
  type <- ev("type_evenement")
  types_unite <- c(.TYPES_SERVICE, "suspension", "fin_service")
  porteurs <- function(k) {
    if (table == "rentes") {
      k <- k[type[k] %in% types_unite]
      p <- .paires(ev("id_rente")[k], .valeurs(ctx, "rentes", "id_rente"))
      return(data.frame(i = k[p$i], j = p$j))
    }
    ks <- k[type[k] %in% c(types_unite, "cloture_dossier")]
    kx <- k[type[k] %in% "sortie"]
    q1 <- .paires(ev("id_dossier")[ks], .valeurs(ctx, "dossiers", "id_dossier"))
    q2 <- .paires(ev("id_sinistre")[kx], .valeurs(ctx, "dossiers", "id_sinistre"))
    rbind(data.frame(i = ks[q1$i], j = q1$j), data.frame(i = kx[q2$i], j = q2$j))
  }
  type_v <- .valeurs_vue(ctx, "evenements", "type_evenement")
  effet_v <- as.numeric(.valeurs_vue(ctx, "evenements", "date_effet"))
  dernier <- .dernier_evenement(ctx, porteurs(which(!is.na(type_v) & !is.na(effet_v) & effet_v <= a)), n)
  classe <- ifelse(is.na(dernier), "non_ouvert", .classe_service(type[dernier]))
  effet <- .date_connue(ctx, "evenements", "date_effet")
  pn <- porteurs(which(.nd_vue(ctx, "evenements") & !((effet > a) %in% TRUE)))
  nb_nd <- nrow(pn)
  pn <- pn[.peut_suivre(ctx, pn$i, dernier[pn$j]), , drop = FALSE]
  res <- list(classe = classe, dernier = dernier, suivants = unname(split(pn$i, factor(pn$j, levels = seq_len(n)))),
              nd = nb_nd)
  assign(nom, res, envir = ctx)
  res
}

# Entrée de .verdict3() « la classe du statut de service (.statut_service(), `st`) est dans
# `classes` » : inconnue si un événement non déterminé qui peut suivre le dernier retenu est
# d'une classe de verdict différent (index : ces événements).
.service3 <- function(ctx, st, classes) {
  type <- .valeurs(ctx, "evenements", "type_evenement")
  valeurs <- st$classe %in% classes
  index <- vector("list", length(valeurs))
  for (j in which(lengths(st$suivants) > 0L)) {
    e <- st$suivants[[j]]
    e <- e[(.classe_service(type[e]) %in% classes) != valeurs[j]]
    if (length(e) > 0L) index[[j]] <- e
  }
  list(tc = "evenements", valeurs = valeurs, inconnu = lengths(index) > 0L, index = index, domaine = c(TRUE, FALSE))
}

# Verdicts à trois valeurs des contrôles de #34 (spécification v1.5, § 2.2 (d) ; M218), en
# logique de Kleene : `v` (logique, NA : inconnu) et `index` (liste nommée par « table » d'une
# liste, par élément, des lignes non déterminées qui rendent l'élément inconnu ; forme de
# l'attribut `index` lu par .regle_vue() et .cause_nd()). `.k3_entree()` : depuis une entrée de
# .verdict3() (.existe_vue3(), .service3()) ; `.k3_op()` : conjonction ou disjonction terme à
# terme (`&`, `|`), index d'un élément inconnu réuni sur ses opérandes inconnus ; `.k3_par()` :
# quantification par élément sur des paires (`i` : élément, de 1 à `n` ; atomes `x`, `.k3`
# aligné sur les paires), « un » (vrai si un atome est vrai, faux si tous sont faux ou sans
# paire) ou « tous » (vrai si tous sont vrais, faux si tous sont faux, inconnu sinon ; sans paire :
# `vide`) ; `nd` : par paire, lignes non déterminées dont dépend l'existence de l'atome (versions
# d'un membre, .versions_membre()), ajoutées à l'index d'un élément inconnu sous « famille » ;
# `.k3_resultat()` : vecteur logique rendu à .regle_vue(), attribut `index` s'il est inconnu.
.k3 <- function(v, index = list()) list(v = v, index = index)
.k3_entree <- function(e) .k3(ifelse(e$inconnu, NA, e$valeurs), stats::setNames(list(e$index), e$tc))
.k3_op <- function(op, ...) {
  xs <- list(...)
  v <- Reduce(op, lapply(xs, `[[`, "v"))
  index <- list()
  inc <- which(is.na(v))
  for (x in xs) {
    l <- inc[is.na(x$v[inc])]
    if (length(l) == 0L) next
    for (tc in names(x$index)) {
      if (is.null(index[[tc]])) index[[tc]] <- vector("list", length(v))
      index[[tc]][l] <- Map(c, index[[tc]][l], x$index[[tc]][l])
    }
  }
  .k3(v, index)
}
.k3_par <- function(i, x, n, quant, vide = FALSE, nd = NULL) {
  vrai <- tabulate(i[x$v %in% TRUE], n)
  faux <- tabulate(i[x$v %in% FALSE], n)
  total <- tabulate(i, n)
  v <- if (quant == "un") ifelse(vrai > 0L, TRUE, ifelse(faux == total, FALSE, NA))
       else ifelse(total == 0L, vide, ifelse(vrai == total, TRUE, ifelse(faux == total, FALSE, NA)))
  index <- list()
  inc <- is.na(v)
  for (tc in names(x$index)) {
    q <- which(is.na(x$v) & inc[i])
    if (length(q) == 0L) next
    index[[tc]] <- vector("list", n)
    for (k in split(q, i[q])) index[[tc]][i[k[1L]]] <- list(unique(unlist(x$index[[tc]][k])))
  }
  if (!is.null(nd)) {
    q <- which(inc[i] & !is.na(nd))
    if (length(q) > 0L) {
      if (is.null(index$famille)) index$famille <- vector("list", n)
      for (k in split(q, i[q])) index$famille[i[k[1L]]] <- list(unique(c(index$famille[[i[k[1L]]]], nd[k])))
    }
  }
  .k3(v, index)
}
.k3_resultat <- function(x) {
  r <- x$v
  if (anyNA(r)) attr(r, "index") <- x$index
  r
}

# Versions possibles de la version valable de chaque membre `ids` (valeurs de famille.id_membre)
# dans la vue (spécification v1.5, § 2.2 (c) 6 et (d)) : la version retenue si elle existe
# (déterminée) ; sinon les candidates d'un membre à version valable non déterminée
# (.visibilite_a()) ; sinon les versions non déterminées d'un membre sans version visible, et
# l'absence du membre. Rend des paires (`i` : élément de `ids` ; `j` : ligne de famille, NA pour
# l'absence) et `nd` (ligne de visibilité non déterminée de la paire, NA sinon) ; un élément de
# clé manquante n'a que l'absence.
.versions_membre <- function(ctx, ids) {
  ids <- as.character(ids)
  membre <- as.character(.valeurs(ctx, "famille", "id_membre"))
  retenu <- ctx$retenu$famille
  vis <- if (.vue_totale(ctx)) NULL else .visibilite_a(ctx, "vue")
  candidate <- if (is.null(vis$candidate)) rep(FALSE, length(membre)) else vis$candidate
  nd <- .nd_vue(ctx, "famille")
  p1 <- .paires(ids, ifelse(retenu, membre, NA))
  p2 <- .paires(ids, ifelse(candidate, membre, NA))
  p2 <- p2[!(p2$i %in% p1$i), , drop = FALSE]
  sans <- !(seq_along(ids) %in% c(p1$i, p2$i))
  p3 <- .paires(ifelse(sans, ids, NA), ifelse(nd & !candidate, membre, NA))
  absent <- which(sans)
  p <- data.frame(i = c(p1$i, p2$i, p3$i, absent), j = c(p1$j, p2$j, p3$j, rep(NA_integer_, length(absent))))
  p <- p[order(p$i, p$j, method = "radix", na.last = TRUE), , drop = FALSE]
  p$nd <- ifelse(!is.na(p$j) & nd[ifelse(is.na(p$j), 1L, p$j)], p$j, NA_integer_)
  rownames(p) <- NULL
  p
}

# D07 (a) et (b), extinction non enregistrée (dictionnaire, § 9, sous-cas deces_connu_ailleurs ;
# spécification `donnees` v1.6, §§ 8.1 et 8.2), sur la vue, constat sur rentes ou dossiers,
# colonne NA, codes D07a et D07b (lettrage du dictionnaire 1.6, M660 ; une clé par sous-cas,
# spécification `donnees` v1.9, § 9.6). Unités : rentes (toute garantie) et dossiers incapacite,
# statut de service à l'arrêté (.statut_service()).
# (a) unité non éteinte (service ou suspension) dont le bénéficiaire a un décès connu de date au
# plus l'arrêté : (i) sinistre deces visible de l'assuré bénéficiaire (assuré du sinistre du
# dossier pour un dossier incapacite ou une rente d'invalidité ; famille.id_assure_membre du
# membre rentes.id_membre pour une autre rente) ; (ii) second_deces d'un dossier double_effet
# dont le sinistre a pour membre rattaché (famille.id_sinistre) le membre de la rente, de lien
# conjoint, partenaire_pacs ou concubin, hors rente de conjoint du même sinistre (configuration
# de D10 (f), comptée sous D10 (f) seul, M335) ; (iii) fin_service de motif deces_beneficiaire
# d'une autre rente du même membre. Traitement H ou S, détection exacte (code D07a).
# (b) unité en service dont le dernier paiement visible (prestations de nature paiement, date de
# règlement au plus l'arrêté ; rente : prestations.id_rente ; dossier : prestations.id_dossier,
# hors arrerage), à défaut le premier ouverture_service, date de référence, vérifie
# ajouter_mois(référence, d07b_mois) < arrêté. Traitement X ou S (lu dans defauts.csv,
# .traitements_sous_cas()), détection présomptive (code D07b). Sans seuils$d07b_mois : non
# exécuté (cause declaration_absente, plus les causes candidates de la règle bloquée de la
# branche déclarée, mêmes colonnes lues : spécification `donnees` v1.9.1, § 9.6, point (3)) et
# déclaration requise (rubrique seuils, clé d07b_mois), s'il existe une unité en service, retenue
# ou de visibilité non déterminée (colonne de statut illisible : prudent, l'unité compte) ;
# exécuté à vide sinon (spécification de B2, § 6.3, niveau 1).
# Verdicts à trois valeurs (.k3_op()) : statut de service (.service3()), décès par existence dans
# la vue (.existe_vue3()), version valable d'un membre (.versions_membre()), référence de (b)
# entre la plus petite et la plus grande date possibles (prestations et ouvertures non
# déterminées).
.regle_v_extinctions <- function(ctx) {
  v <- function(t, c1) .valeurs(ctx, t, c1)
  a <- as.numeric(ctx$arrete)
  code_dossier <- function(dossier) {
    .joindre(ctx, "garanties_souscrites", "id_garantie_souscrite", "code_garantie",
             .joindre(ctx, "dossiers", "id_dossier", "id_garantie_souscrite", dossier))
  }
  ev_lus <- paste0("evenements.", c("id_evenement", "type_evenement", "date_effet", "date_saisie"))
  code_lus <- c("dossiers.id_dossier", "dossiers.id_garantie_souscrite", "garanties_souscrites.id_garantie_souscrite",
                "garanties_souscrites.code_garantie")
  statut_lus <- list(rentes = c("rentes.id_rente", "rentes.id_dossier", "evenements.id_rente", ev_lus, code_lus),
                     dossiers = c("dossiers.id_sinistre", "evenements.id_dossier", "evenements.id_sinistre", ev_lus, code_lus))
  vue_ev <- ctx$lit_vue$evenements
  # unités de la table : toute rente ; dossier incapacite
  unite <- function(t) if (t == "rentes") rep(TRUE, nrow(ctx$base$rentes)) else code_dossier(v("dossiers", "id_dossier")) %in% "incapacite"
  # décès de l'assuré `assure` (sinistre deces de survenance au plus l'arrêté), dans la vue
  deces_assure <- function(assure) {
    .k3_entree(.existe_vue3(ctx, "sinistres", assure, v("sinistres", "id_assure"),
                            v("sinistres", "nature_sinistre") %in% "deces" & as.numeric(v("sinistres", "date_survenance")) <= a))
  }
  lit_i <- c("sinistres.id_sinistre", "sinistres.id_assure", "sinistres.nature_sinistre", "sinistres.date_survenance")
  conjoints <- c("conjoint", "partenaire_pacs", "concubin")

  # (a), rentes
  .regle_vue(ctx, "D07a", "rentes", NA_character_,
             c(statut_lus$rentes, "rentes.id_membre", "dossiers.id_sinistre", lit_i, "famille.id_membre", "famille.id_assure_membre",
               "famille.lien", "famille.id_sinistre", "evenements.id_dossier", "evenements.motif"),
             "H;S", "exacte", function() {
    nr <- nrow(ctx$base$rentes)
    ne <- .k3_entree(.service3(ctx, .statut_service(ctx, "rentes"), .NON_ETEINT))
    dossier <- v("rentes", "id_dossier")
    code <- code_dossier(dossier)
    sinistre <- as.character(.joindre(ctx, "dossiers", "id_dossier", "id_sinistre", dossier))
    membre <- as.character(v("rentes", "id_membre"))
    # (i) rente d'invalidité : l'assuré du sinistre
    invalidite <- code %in% "invalidite"
    d_inv <- deces_assure(ifelse(invalidite, as.character(.joindre(ctx, "sinistres", "id_sinistre", "id_assure", sinistre)), NA))
    d_inv$v <- d_inv$v & invalidite
    # (i) et (ii) par la version valable du membre (rente autre que d'invalidité)
    p <- .versions_membre(ctx, ifelse(invalidite, NA, membre))
    j <- p$j
    f_assure <- as.character(v("famille", "id_assure_membre"))[j]
    f_sinistre <- as.character(v("famille", "id_sinistre"))[j]
    a_i <- deces_assure(f_assure)
    # second_deces d'un dossier double_effet, d'effet au plus l'arrêté, rattaché au sinistre
    type <- v("evenements", "type_evenement")
    ev_dossier <- v("evenements", "id_dossier")
    sd <- type %in% "second_deces" & as.numeric(v("evenements", "date_effet")) <= a & code_dossier(ev_dossier) %in% "double_effet"
    a_ii <- .k3_entree(.existe_vue3(ctx, "evenements", f_sinistre,
                                    as.character(.joindre(ctx, "dossiers", "id_dossier", "id_sinistre", ev_dossier)), sd))
    conj <- v("famille", "lien")[j] %in% conjoints & !(code[p$i] %in% "rente_conjoint" & (f_sinistre == sinistre[p$i]) %in% TRUE)
    a_ii$v <- a_ii$v & conj
    atome <- .k3_op(`|`, a_i, a_ii)
    atome$v <- atome$v & !is.na(j)
    d_m <- .k3_par(p$i, atome, nr, "tous", nd = p$nd)
    # (iii) fin_service deces_beneficiaire d'une autre rente du même membre
    fs <- type %in% "fin_service" & v("evenements", "motif") %in% "deces_beneficiaire"
    rente_e <- as.character(v("evenements", "id_rente"))
    membre_e <- as.character(.joindre(ctx, "rentes", "id_rente", "id_membre", rente_e))
    effet <- .date_connue(ctx, "evenements", "date_effet")
    possible <- .nd_vue(ctx, "evenements") & fs & !((effet > a) %in% TRUE)
    autre <- function(q) q[rente_e[q$j] != as.character(v("rentes", "id_rente"))[q$i], , drop = FALSE]
    q1 <- autre(.paires(membre, ifelse(ctx$retenu$evenements & fs & as.numeric(v("evenements", "date_effet")) <= a, membre_e, NA)))
    q2 <- autre(.paires(membre, ifelse(possible, membre_e, NA)))
    d_iii <- .k3(seq_len(nr) %in% q1$i)
    inc <- setdiff(unique(q2$i), q1$i)
    if (length(inc) > 0L) {
      d_iii$v[inc] <- NA
      d_iii$index$evenements <- vector("list", nr)
      d_iii$index$evenements[inc] <- unname(split(q2$j, q2$i)[as.character(inc)])
    }
    .k3_resultat(.k3_op(`&`, ne, .k3_op(`|`, d_inv, d_m, d_iii)))
  }, vue = c(vue_ev, ctx$lit_vue$famille, ctx$lit_vue$sinistres))
  # (a), dossiers incapacite : (i) seul
  .regle_vue(ctx, "D07a", "dossiers", NA_character_, c(statut_lus$dossiers, lit_i), "H;S", "exacte", function() {
    ne <- .k3_entree(.service3(ctx, .statut_service(ctx, "dossiers"), .NON_ETEINT))
    assure <- as.character(.joindre(ctx, "sinistres", "id_sinistre", "id_assure", v("dossiers", "id_sinistre")))
    .k3_resultat(.k3_op(`&`, .k3(unite("dossiers")), ne, deces_assure(assure)))
  }, vue = c(vue_ev, ctx$lit_vue$sinistres))

  # (b) ; colonnes lues par la règle, par table, et colonnes lues pour la vue (une seule
  # définition pour les deux branches) ; traitement lu dans le dictionnaire (defauts.csv, X;S)
  mois <- ctx$declarations$seuils[[SEUIL_MOIS_D07B]]
  tables <- intersect(c("rentes", "dossiers"), names(ctx$base))
  lit_p <- list(rentes = paste0("prestations.", c("id_rente", "nature_mouvement", "date_reglement")),
                dossiers = paste0("prestations.", c("id_dossier", "type_prestation", "nature_mouvement", "date_reglement")))
  lit_b <- list(rentes = c(statut_lus$rentes, lit_p$rentes), dossiers = c(statut_lus$dossiers, lit_p$dossiers))
  vue_b <- c(vue_ev, ctx$lit_vue$prestations)
  traitement_b <- .traitements_sous_cas(ctx$dico)[["D07b"]]
  if (is.null(mois)) {
    # unité en service, retenue ou de visibilité non déterminée (prudent : colonne illisible)
    en_service <- function(t) {
      if (NROW(ctx$base[[t]]) == 0L) return(FALSE)
      if (!is.null(.cause_lecture(ctx, statut_lus[[t]]))) return(TRUE)
      st <- .statut_service(ctx, t)
      s3 <- .service3(ctx, st, "service")
      any((ctx$retenu[[t]] | .nd_vue(ctx, t)) & unite(t) & (s3$valeurs | s3$inconnu))
    }
    avec <- tables[vapply(tables, en_service, NA)]
    # causes candidates de la règle bloquée de la branche déclarée (.regle_vue() sans `f` ;
    # spécification `donnees` v1.9.1, § 9.6, point (3))
    for (t in avec) {
      .ajouter_non_execute(ctx, "D07b", t, NA_character_, "declaration_absente")
      .regle_vue(ctx, "D07b", t, NA_character_, lit_b[[t]], traitement_b, "presomptive", NULL, vue = vue_b)
    }
    if (length(avec) > 0L) .requerir(ctx, "seuils", "D07b", SEUIL_MOIS_D07B)
    return(invisible(NULL))
  }
  for (t in tables) {
    cle <- if (t == "rentes") "id_rente" else "id_dossier"
    .regle_vue(ctx, "D07b", t, NA_character_, lit_b[[t]], traitement_b, "presomptive", function() {
      n <- nrow(ctx$base[[t]])
      sv <- .k3_entree(.service3(ctx, .statut_service(ctx, t), "service"))
      id <- as.character(v(t, cle))
      # paiements de l'unité de règlement au plus l'arrêté : retenus, ou non déterminés (date
      # inconnue : possible)
      reglement <- .date_connue(ctx, "prestations", "date_reglement")
      paiement <- v("prestations", "nature_mouvement") %in% "paiement" &
        (t == "rentes" | !(v("prestations", "type_prestation") %in% "arrerage"))
      cle_p <- as.character(v("prestations", cle))
      pr <- .paires(id, ifelse(ctx$retenu$prestations & paiement & as.numeric(v("prestations", "date_reglement")) <= a, cle_p, NA))
      pn <- .paires(id, ifelse(.nd_vue(ctx, "prestations") & paiement & !((reglement > a) %in% TRUE), cle_p, NA))
      # ouvertures de service de l'unité, d'effet au plus l'arrêté : retenues, ou non déterminées
      type <- v("evenements", "type_evenement")
      effet <- .date_connue(ctx, "evenements", "date_effet")
      cle_e <- as.character(v("evenements", cle))
      ouv <- type %in% "ouverture_service"
      er <- .paires(id, ifelse(ctx$retenu$evenements & ouv & as.numeric(v("evenements", "date_effet")) <= a, cle_e, NA))
      en <- .paires(id, ifelse(.nd_vue(ctx, "evenements") & ouv & !((effet > a) %in% TRUE), cle_e, NA))
      maxi <- function(x, i) { r <- rep(NA_real_, n); if (length(i)) { m <- tapply(x, i, max); r[as.integer(names(m))] <- m }; r }
      mini <- function(x, i) { r <- rep(NA_real_, n); if (length(i)) { m <- tapply(x, i, min); r[as.integer(names(m))] <- m }; r }
      dernier_paiement <- maxi(as.numeric(v("prestations", "date_reglement"))[pr$j], pr$i)
      premiere_ouverture <- mini(as.numeric(v("evenements", "date_effet"))[er$j], er$i)
      reference <- ifelse(is.na(dernier_paiement), premiere_ouverture, dernier_paiement)
      detecte <- function(d) {
        x <- !is.na(d)
        x[x] <- as.numeric(ajouter_mois(d[x], mois)) < a
        x
      }
      r <- detecte(reference)
      # éléments non déterminés dont la date (inconnue : les deux verdicts) peut changer le
      # verdict (la détection décroît avec la référence) : un paiement plus récent que le dernier
      # paiement retenu, ou tout paiement sans paiement retenu ; sans paiement retenu, une
      # ouverture plus ancienne que la première ouverture retenue
      differe <- function(d, i) is.na(d) | detecte(d) != r[i]
      dp <- as.numeric(reglement)[pn$j]
      de <- as.numeric(effet)[en$j]
      cp <- differe(dp, pn$i) & (is.na(dernier_paiement[pn$i]) | is.na(dp) | dp > dernier_paiement[pn$i])
      ce <- differe(de, en$i) & is.na(dernier_paiement[en$i]) &
        (is.na(de) | is.na(premiere_ouverture[en$i]) | de < premiere_ouverture[en$i])
      ref3 <- .k3(r)
      inc <- sort(unique(c(pn$i[cp], en$i[ce])))
      if (length(inc) > 0L) {
        ref3$v[inc] <- NA
        if (any(cp)) {
          g <- split(pn$j[cp], pn$i[cp])
          ref3$index$prestations <- vector("list", n)
          ref3$index$prestations[as.integer(names(g))] <- unname(g)
        }
        if (any(ce)) {
          g <- split(en$j[ce], en$i[ce])
          ref3$index$evenements <- vector("list", n)
          ref3$index$evenements[as.integer(names(g))] <- unname(g)
        }
      }
      .k3_resultat(.k3_op(`&`, .k3(unite(t)), sv, ref3))
    }, vue = vue_b)
  }
  invisible(NULL)
}

# D08, rechute enregistrée comme nouveau sinistre (dictionnaire, § 9 ; spécification `donnees`
# v1.6, § 8.3), sur la vue, constat sur sinistres (le nouveau sinistre S2), colonne NA :
# sinistre arret_travail S2 et sortie de motif reprise_travail d'un autre sinistre
# arret_travail S1 du même assuré, avec 0 <= survenance de S2 - effet de la sortie < délai (en
# jours, « de moins de », strict). Délai : paramètre delai_rechute_jours de la garantie
# incapacite des dossiers de S1 dans la vue (version du dossier ; parametres dans la vue,
# comme D07 (c)) ; absent, ou à plusieurs valeurs, pour une paire candidate (écart positif ou
# nul) d'un S2 non détecté par une autre paire : la valeur peut décider, la table va dans
# controles_non_executes (.CAUSE_PARAMETRE_NON_DEFINI). Traitement H ou S, détection
# présomptive. Verdict à trois valeurs : sortie non déterminée (effet au plus l'arrêté ou
# inconnu) qui peut former une paire détectée (index : ces sorties).
.regle_v_rechutes <- function(ctx) {
  v <- function(t, c1) .valeurs(ctx, t, c1)
  vv <- function(t, c1) .valeurs_vue(ctx, t, c1)
  a <- as.numeric(ctx$arrete)
  .regle_vue(ctx, "D08", "sinistres", NA_character_,
             c("sinistres.id_sinistre", "sinistres.id_assure", "sinistres.nature_sinistre", "sinistres.date_survenance",
               paste0("evenements.", c("id_evenement", "id_sinistre", "type_evenement", "motif", "date_effet")),
               "dossiers.id_sinistre", "dossiers.id_garantie_souscrite", "garanties_souscrites.id_garantie_souscrite",
               "garanties_souscrites.code_garantie", "parametres.id_garantie_souscrite", "parametres.parametre",
               "parametres.valeur"),
             "H;S", "presomptive", function() {
    ns <- nrow(ctx$base$sinistres)
    id_s <- as.character(v("sinistres", "id_sinistre"))
    arret <- v("sinistres", "nature_sinistre") %in% "arret_travail"
    assure <- as.character(v("sinistres", "id_assure"))
    survenance <- as.numeric(v("sinistres", "date_survenance"))
    # délai de chaque sinistre S1 : valeurs distinctes du paramètre sur les garanties incapacite
    # de ses dossiers retenus
    gs <- v("dossiers", "id_garantie_souscrite")
    incap <- ctx$retenu$dossiers & .joindre(ctx, "garanties_souscrites", "id_garantie_souscrite", "code_garantie", gs) %in%
      "incapacite"
    q <- .paires(id_s, ifelse(incap, as.character(v("dossiers", "id_sinistre")), NA))
    k <- which(vv("parametres", "parametre") %in% "delai_rechute_jours")
    w <- .paires(as.character(gs)[q$j], as.character(v("parametres", "id_garantie_souscrite"))[k])
    valeurs <- split(v("parametres", "valeur")[k][w$j], factor(q$i[w$i], levels = seq_len(ns)))
    valeurs <- lapply(valeurs, unique)
    delai <- vapply(valeurs, function(x) if (length(x) == 1L) x else NA_real_, 0, USE.NAMES = FALSE)
    # sorties reprise_travail d'un sinistre arret_travail (S1), retenues ou non déterminées
    type <- v("evenements", "type_evenement")
    i1 <- apparier_cles(v("evenements", "id_sinistre"), id_s)
    sortie <- type %in% "sortie" & v("evenements", "motif") %in% "reprise_travail" & !is.na(i1) &
      arret[ifelse(is.na(i1), 1L, i1)]
    effet <- .date_connue(ctx, "evenements", "date_effet")
    # S2 : sinistre arret_travail retenu dans la vue (une ligne non déterminée n'a pas de verdict
    # propre, ni de ligne parametre_non_defini, .regle_vue())
    paires_de <- function(lignes) {
      p <- .paires(ifelse(arret & ctx$retenu$sinistres, assure, NA), ifelse(lignes, assure[i1], NA))
      p[id_s[p$i] != id_s[i1[p$j]], , drop = FALSE]
    }
    p <- paires_de(sortie & ctx$retenu$evenements)
    ecart <- survenance[p$i] - as.numeric(effet)[p$j]
    candidate <- ecart >= 0
    dl <- delai[i1[p$j]]
    r <- seq_len(ns) %in% p$i[candidate & !is.na(dl) & ecart < dl]
    if (any(candidate & is.na(dl) & !r[p$i])) .ajouter_non_execute(ctx, "D08", "sinistres", NA_character_, .CAUSE_PARAMETRE_NON_DEFINI)
    pn <- paires_de(sortie & .nd_vue(ctx, "evenements") & !((effet > a) %in% TRUE))
    ecart_n <- survenance[pn$i] - as.numeric(effet)[pn$j]
    dl_n <- delai[i1[pn$j]]
    possible <- !r[pn$i] & (is.na(ecart_n) | (ecart_n >= 0 & (is.na(dl_n) | ecart_n < dl_n)))
    if (!any(possible)) return(r)
    r3 <- .k3(r, list(evenements = vector("list", ns)))
    r3$v[unique(pn$i[possible])] <- NA
    g <- split(pn$j[possible], pn$i[possible])
    r3$index$evenements[as.integer(names(g))] <- unname(g)
    .k3_resultat(r3)
  }, vue = c(ctx$lit_vue$evenements, ctx$lit_vue$dossiers, ctx$lit_vue$parametres))
  invisible(NULL)
}

# D10 (e), qualité du bénéficiaire incompatible avec la garantie (dictionnaire, § 9 ;
# spécification `donnees` v1.6, § 8.5), sur la vue : ligne de beneficiaires dont la qualite n'est
# pas compatible avec le code de la garantie souscrite de son dossier, selon la matrice
# .QUALITES_COMPATIBLES (jugement d'expert visé le 13 novembre 2026 ; incapacite et invalidite :
# aucune qualité, l'assuré est le bénéficiaire). Jointure sur les valeurs brutes (lignes parentes
# ou référencées : clé non exposée, § 8.0 bis, point 2) ; garantie inconnue (lien non résolu) :
# non détecté. Traitement X par famille, constat sur beneficiaires, colonne qualite.
.QUALITES_COMPATIBLES <- list(
  deces = c("conjoint_survivant", "enfant_a_charge", "designe", "heritiers", "non_identifie"),
  double_effet = c("enfant_a_charge", "non_identifie"),
  rente_conjoint = "conjoint_survivant",
  rente_education = "enfant_a_charge",
  incapacite = character(0),
  invalidite = character(0))
.regle_v_qualites <- function(ctx) {
  .regle_vue(ctx, "D10e", "beneficiaires", "qualite",
             c("beneficiaires.id_dossier", "dossiers.id_dossier", "dossiers.id_garantie_souscrite",
               "garanties_souscrites.id_garantie_souscrite", "garanties_souscrites.code_garantie"), "X", "exacte", function() {
    # règle V en mode Kleene (#105, lot V, G1) : qualité et code de la garantie jointe à trois
    # valeurs (.entree3(), domaine de leur colonne)
    gs <- .joindre(ctx, "dossiers", "id_dossier", "id_garantie_souscrite", .valeurs_vue(ctx, "beneficiaires", "id_dossier"))
    ix <- .index_jointure(ctx, "garanties_souscrites", "id_garantie_souscrite", gs)
    codes <- names(.QUALITES_COMPATIBLES)
    compatibles <- paste(rep(codes, lengths(.QUALITES_COMPATIBLES)), unlist(.QUALITES_COMPATIBLES, use.names = FALSE))
    .verdict3(list(qualite = .entree3(ctx, "beneficiaires.qualite"),
                   code = .entree3(ctx, "garanties_souscrites.code_garantie", index = ix)), function(x) {
      code <- as.character(x$code)
      !is.na(x$qualite) & code %in% codes & !(paste(code, x$qualite) %in% compatibles)
    })
  }, mode = "kleene")
  invisible(NULL)
}

# D10 (f), décès du conjoint saisi sur un dossier et pas sur l'autre (dictionnaire, § 9 ;
# spécification `donnees` v1.6, § 8.6), sur la vue, constat sur evenements, colonne NA. Pour un
# sinistre qui a un dossier double_effet et une rente d'un dossier rente_conjoint (même sinistre :
# égalité, terme à terme, du sinistre du dossier double_effet et du sinistre du dossier de la
# rente ; sinistre inconnu : configuration non retenue, définition de l'exception de D07 (a),
# M335) : (1) second_deces retenu, d'effet au plus l'arrêté, du dossier double_effet, et rente de
# conjoint non éteinte à l'arrêté (statut de service commun, .statut_service()) ; identifiant :
# le second_deces ; (2) fin_service de motif deces_beneficiaire retenu, d'effet au plus l'arrêté,
# de la rente de conjoint, sans second_deces d'effet au plus l'arrêté dans la vue sur un dossier
# double_effet du sinistre, celui-ci ayant un dossier double_effet dans la vue ; identifiant :
# le fin_service. Traitement H ou S, détection exacte. Verdict à trois valeurs : statut de service
# (.service3()), rente, dossier ou second_deces de visibilité non déterminée.
.regle_v_deces_conjoint <- function(ctx) {
  v <- function(t, c1) .valeurs(ctx, t, c1)
  a <- as.numeric(ctx$arrete)
  lit <- c(paste0("evenements.", c("id_evenement", "type_evenement", "date_effet", "date_saisie", "id_dossier", "id_rente",
                                   "motif")),
           "dossiers.id_dossier", "dossiers.id_sinistre", "dossiers.id_garantie_souscrite",
           "garanties_souscrites.id_garantie_souscrite", "garanties_souscrites.code_garantie", "rentes.id_rente",
           "rentes.id_dossier")
  .regle_vue(ctx, "D10f", "evenements", NA_character_, lit, "H;S", "exacte", function() {
    ne <- nrow(ctx$base$evenements)
    code_dossier <- function(dossier) {
      .joindre(ctx, "garanties_souscrites", "id_garantie_souscrite", "code_garantie",
               .joindre(ctx, "dossiers", "id_dossier", "id_garantie_souscrite", dossier))
    }
    sinistre_de <- function(dossier) as.character(.joindre(ctx, "dossiers", "id_dossier", "id_sinistre", dossier))
    type <- v("evenements", "type_evenement")
    effet <- .date_connue(ctx, "evenements", "date_effet")
    ev_dossier <- v("evenements", "id_dossier")
    sin_e <- sinistre_de(ev_dossier)
    sd <- type %in% "second_deces" & code_dossier(ev_dossier) %in% "double_effet" & !is.na(sin_e)
    r_dossier <- v("rentes", "id_dossier")
    sin_r <- sinistre_de(r_dossier)
    rc <- code_dossier(r_dossier) %in% "rente_conjoint" & !is.na(sin_r)
    # (1) paires (second_deces, rente de conjoint du même sinistre), rentes retenues ou non
    # déterminées ; une rente non déterminée qui peut être non éteinte rend l'atome inconnu
    p <- .paires(ifelse(ctx$retenu$evenements & sd & as.numeric(effet) <= a, sin_e, NA),
                 ifelse(rc & (ctx$retenu$rentes | .nd_vue(ctx, "rentes")), sin_r, NA))
    atome <- .k3_sous(.k3_entree(.service3(ctx, .statut_service(ctx, "rentes"), .NON_ETEINT)), p$j)
    nd_r <- which(!ctx$retenu$rentes[p$j] & !(atome$v %in% FALSE))
    if (length(nd_r) > 0L) {
      atome$v[nd_r] <- NA
      atome$index$rentes <- vector("list", nrow(p))
      atome$index$rentes[nd_r] <- as.list(p$j[nd_r])
    }
    sens1 <- .k3_par(p$i, atome, ne, "un")
    # (2) fin_service deces_beneficiaire d'une rente de conjoint
    # clés appariées : une clé manquante ou vide ne s'apparie à rien (apparier_cles(), #158)
    k <- apparier_cles(v("evenements", "id_rente"), v("rentes", "id_rente"))
    fs <- ctx$retenu$evenements & type %in% "fin_service" & v("evenements", "motif") %in% "deces_beneficiaire" &
      as.numeric(effet) <= a & !is.na(k)
    fs <- fs & rc[ifelse(is.na(k), 1L, k)]
    sin2 <- ifelse(fs, sin_r[k], NA_character_)
    de3 <- .k3_entree(.existe_vue3(ctx, "dossiers", sin2, v("dossiers", "id_sinistre"),
                                   code_dossier(v("dossiers", "id_dossier")) %in% "double_effet"))
    sd3 <- .k3_entree(.existe_vue3(ctx, "evenements", sin2, sin_e, sd & !((effet > a) %in% TRUE)))
    sens2 <- .k3_op(`&`, .k3(fs), de3, .k3(!sd3$v, sd3$index))
    .k3_resultat(.k3_op(`|`, sens1, sens2))
  }, vue = c(ctx$lit_vue$evenements, ctx$lit_vue$rentes, ctx$lit_vue$dossiers))
  invisible(NULL)
}

# Index d'un verdict à trois valeurs (.k3()) : ajoute, pour l'élément `k`, les lignes `lignes`
# de l'élément non déterminé « tc » (`n` : nombre d'éléments).
.k3_index <- function(x, tc, k, lignes, n) {
  if (is.null(x$index[[tc]])) x$index[[tc]] <- vector("list", n)
  x$index[[tc]][k] <- list(unique(c(x$index[[tc]][[k]], lignes)))
  x
}

# D11, sinistre hors période de couverture (dictionnaire 1.6, § 9, sous-cas (a) à (c) ;
# spécification `donnees` v1.9, § 9.5, #81 ; M508, M657 à M659, M663, M669 à M671), sur la vue,
# traitement S + X pour chaque sous-cas (deux constats de même clé, comme D10 (b)), détection
# exacte, hors portabilité (une affiliation de portabilité couvre comme toute autre).
# - D11a (constat sur sinistres, colonne date_survenance ; règle de la spécification `donnees`
#   v1.6, § 8.7, renommée à 60a, M675) : sinistre dont la survenance n'est couverte par aucun
#   contrat (couverture d'une date par un contrat, .couverture3()) : avec des dossiers dans la
#   vue, pour au moins un dossier, le contrat de la garantie du dossier ne couvre pas la
#   survenance (contrat lu sur toutes les occurrences de la clé de la garantie, .jointe3(),
#   C-5 de #164 ; manquant ou vide : aucun appariement, détecté, #157, M628) ; sans dossier dans
#   la vue, aucun contrat ne la couvre ; hors sous-cas du maintien de la garantie décès
#   (.maintien_d11() : un sinistre deces qui en relève n'est pas détecté, sans ligne
#   non_lisible). Le cœur (non-couverture) ne lit ni evenements, ni sinistres.nature_sinistre, ni
#   maintien_deces : seul le sous-cas les lit (.LIT_MAINTIEN_D11) ; l'une de ces colonnes
#   illisible, le sous-cas n'est lu que pour sa partie lisible (lecture grossière gardée, Q-22,
#   M659 ; lecture fine : #105) : un sinistre au sous-cas inconnu est écarté (non détecté ; s'il
#   est aussi de couverture inconnue, il garde son verdict inconnu et sa cause γ), les autres
#   détections du cœur restent, et (D11a, sinistres, NA) entre dans controles_non_executes, cause
#   = cause directe des colonnes illisibles du sous-cas, la plus petite dans l'ordre (rang,
#   position) (.cause_retenue(), comme M169 ; décision du mainteneur du 13/11/2026), s'il existe
#   un sinistre retenu écarté. evenements n'est lu que pour un contrat en cause à maintien_deces
#   TRUE ou inconnu (portée réduite de la lecture grossière, M659).
# - D11b (constat sur dossiers, colonne id_garantie_souscrite) : dossier posé sur une garantie
#   de couple (id_contrat, college), contrat non individuel, dont aucune affiliation de l'assuré
#   à ce contrat dans ce collège ne couvre la survenance (.couverture3(), argument `college`),
#   alors qu'une affiliation au même contrat dans un autre collège la couvre, le sous-cas du
#   maintien restreint aux affiliations du collège du dossier n'étant pas vrai ; disjoint de D11a.
#   Contrat individuel lu sur les lignes retenues de contrats (vue, § 8.0 bis, point 1) ; une
#   ligne non déterminée de nature individuel rend le verdict inconnu (cause γ). Le sous-cas y
#   suit la lecture grossière de D11a (décision du mainteneur du 19/11/2026) : ses colonnes
#   illisibles ne bloquent pas D11b, un dossier au sous-cas inconnu est écarté et (D11b,
#   dossiers, NA) prend la cause directe.
# - D11c (constat sur affiliations, colonne college) : deux affiliations retenues d'un même
#   assuré au même contrat, dans deux collèges distincts, dont les périodes de couverture se
#   chevauchent (bornes incluses ; fin connue à l'arrêté, fin inconnue à l'arrêté ouverte) ; une
#   composante de clé (assuré, contrat, collège) manquante ou vide met la ligne hors du contrôle
#   (forme « chevauchement », #121, M396).
# Verdicts à trois valeurs (cause γ) : couverture possible (.couverture3()), dossier, version
# de garantie, événement, sinistre arret_travail ou affiliation non déterminés, partie de fin
# non déterminée ; clé de garantie souscrite en double aux occurrences divergentes : verdict de
# chaque valeur, inconnu s'ils diffèrent (index sur les occurrences, cause candidate D01a ;
# chemin non atteignable tant que le refus D01a de portée table bloque la règle, #169).
.regle_v_couverture <- function(ctx) {
  lit_c <- c(paste0("affiliations.", c("id_assure", "id_contrat", "college", "date_debut", "date_fin")),
             paste0("contrats.", c("id_contrat", "nature_contrat", "id_assure", "date_effet", "date_fin", "date_terme")))
  lit_c <- lit_c[sub("\\..*$", "", lit_c) %in% names(ctx$base)]
  lit <- c("sinistres.id_sinistre", "sinistres.id_assure", "dossiers.id_sinistre", "dossiers.id_garantie_souscrite",
           "garanties_souscrites.id_garantie_souscrite", "garanties_souscrites.id_contrat", lit_c)
  vue <- c(ctx$lit_vue$dossiers, ctx$lit_vue$affiliations, ctx$lit_vue$contrats)
  memo <- function(calcul) {
    verdict <- NULL
    function() {
      if (is.null(verdict)) verdict <<- calcul(ctx)
      verdict
    }
  }
  f <- memo(.verdict_d11)
  for (t in c("S", "X")) .regle_vue(ctx, "D11a", "sinistres", "date_survenance", lit, t, "exacte", f, vue = vue)
  lit_b <- unique(c(lit, "sinistres.date_survenance", "garanties_souscrites.college"))
  vue_b <- c(vue, ctx$lit_vue$sinistres)
  fb <- memo(.verdict_d11b)
  for (t in c("S", "X")) .regle_vue(ctx, "D11b", "dossiers", "id_garantie_souscrite", lit_b, t, "exacte", fb, vue = vue_b)
  lit_cc <- paste0("affiliations.", c("id_assure", "id_contrat", "college", "date_debut", "date_fin"))
  fc <- memo(.verdict_d11c)
  for (t in c("S", "X")) {
    .regle_vue(ctx, "D11c", "affiliations", "college", lit_cc, t, "exacte", fc, vue = ctx$lit_vue$affiliations, mode = "kleene")
  }
  invisible(NULL)
}

# Colonnes lues par le sous-cas du maintien de la garantie décès (.maintien_d11()) : nature du
# sinistre ; maintien_deces et colonnes de la garantie souscrite en vigueur à la survenance de
# l'arrêt (.garantie_en_vigueur3()) ; sorties et rechutes de l'arrêt et leur ordre
# (.arret_en_cours3(), .dernier_evenement()).
.LIT_MAINTIEN_D11 <- c("sinistres.nature_sinistre",
                       paste0("garanties_souscrites.", c("maintien_deces", "code_garantie", "college", "date_effet", "date_fin")),
                       paste0("evenements.", c("id_sinistre", "type_evenement", "date_effet", "date_saisie", "id_evenement")))

# Verdict de D11a sur les lignes de sinistres (.regle_v_couverture()) : vecteur logique, attribut
# `index` s'il est inconnu.
.verdict_d11 <- function(ctx) {
  v <- function(t, c1) .valeurs(ctx, t, c1)
  ns <- nrow(ctx$base$sinistres)
  id_s <- as.character(v("sinistres", "id_sinistre"))
  assure <- as.character(v("sinistres", "id_assure"))
  surv <- as.numeric(v("sinistres", "date_survenance"))
  nd_d <- .nd_vue(ctx, "dossiers")
  # dossiers du sinistre (retenus ou non déterminés) et contrat de leur garantie
  p <- .paires(id_s, ifelse(ctx$retenu$dossiers | nd_d, as.character(v("dossiers", "id_sinistre")), NA))
  ret <- ctx$retenu$dossiers[p$j]
  # contrat lu sur toutes les occurrences de la clé de la garantie (.jointe3(), lecture
  # existentielle de .joindre3() ; C-5 de #164, M650, M663), clé vide lue comme manquante
  # (.cle3(), #152) : "" et NA donnent le même verdict ; occurrences divergentes : contrat
  # inconnu, de domaine les valeurs des occurrences
  jc <- .cle3(.jointe3(ctx, "garanties_souscrites.id_contrat", "id_garantie_souscrite",
                       v("dossiers", "id_garantie_souscrite")[p$j]))
  contrat_d <- as.character(jc$valeurs)
  diverge <- jc$inconnu
  # couverture de la survenance : certaine, ou possible (index : ligne ou partie non déterminée)
  cv <- .couverture3(ctx, assure, surv)
  contrat_cv <- .cle_manquante(as.character(cv$contrat))
  # paire (sinistre, contrat) : code entier composante par composante (.code_groupe(), sans paste() :
  # un contrat « NA » littéral ne se confond pas avec un contrat manquant) ; le contrat de la
  # couverture est lu comme celui du dossier (.cle_manquante(), #152)
  k <- .code_groupe(list(c(cv$i, p$i), c(contrat_cv, contrat_d)))
  kc <- k[seq_along(cv$i)]
  # atome « le contrat ne couvre pas la survenance », par paire (sinistre, dossier)
  kd <- k[length(cv$i) + seq_along(p$i)]
  # contrat du dossier manquant : aucun appariement, la survenance n'est couverte par aucun contrat (#157)
  nc <- .k3(ifelse(is.na(contrat_d), TRUE, ifelse(kd %in% kc[cv$certain], FALSE, ifelse(kd %in% kc[!cv$certain], NA, TRUE))))
  for (m in which(is.na(nc$v) & !diverge)) {
    q <- which(kc == kd[m] & !cv$certain)
    for (z in q) nc <- .k3_index(nc, cv$tc[z], m, cv$ligne[z], nrow(p))
  }
  # occurrences divergentes : l'atome s'évalue pour chaque valeur du domaine (un contrat manquant
  # ne couvre pas) ; connu si les valeurs concordent, inconnu sinon (index : les occurrences de
  # garanties_souscrites, et la couverture possible d'une valeur)
  for (m in which(diverge)) {
    vals <- jc$domaines[[m]]
    atomes <- lapply(vals, function(cx) {
      if (is.na(cx)) return(list(v = TRUE, q = integer(0)))
      q <- which(cv$i == p$i[m] & !is.na(apparier_cles(contrat_cv, cx)))
      if (any(cv$certain[q])) list(v = FALSE, q = integer(0)) else if (length(q) > 0L) list(v = NA, q = q)
      else list(v = TRUE, q = integer(0))
    })
    vs <- vapply(atomes, `[[`, NA, "v")
    nc$v[m] <- if (all(vs %in% TRUE)) TRUE else if (all(vs %in% FALSE)) FALSE else NA
    if (is.na(nc$v[m])) {
      if (length(unique(vs)) > 1L) nc <- .k3_index(nc, "garanties_souscrites", m, jc$index[[m]], nrow(p))
      for (z in unlist(lapply(atomes, `[[`, "q"))) nc <- .k3_index(nc, cv$tc[z], m, cv$ligne[z], nrow(p))
    }
  }
  r <- .k3_par(p$i[ret], .k3_sous(nc, ret), ns, "un")
  avec <- tabulate(p$i[ret], ns) > 0L
  # sans dossier retenu : aucun contrat ne couvre (certain : faux ; possible seulement : inconnu)
  sans <- which(!avec)
  if (length(sans) > 0L) {
    certain <- seq_len(ns) %in% cv$i[cv$certain]
    possible <- seq_len(ns) %in% cv$i[!cv$certain]
    r$v[sans] <- ifelse(certain[sans], FALSE, ifelse(possible[sans], NA, TRUE))
    for (i in sans[is.na(r$v[sans])]) {
      q <- which(cv$i == i & !cv$certain)
      for (z in q) r <- .k3_index(r, cv$tc[z], i, cv$ligne[z], ns)
    }
  }
  # dossier non déterminé : il peut ajouter un dossier non couvert (avec un dossier retenu), ou
  # tenir lieu de la couverture par tout contrat (sans dossier retenu) ; verdict inconnu si les
  # verdicts possibles diffèrent (comme D10 (d))
  pn <- which(!ret)
  for (k in split(pn, p$i[pn])) {
    i <- p$i[k[1L]]
    x <- nc$v[k]
    reste <- if (avec[i]) r$v[i] %in% TRUE || all(x %in% FALSE) else {
      vals <- c(r$v[i], x)
      all(vals %in% TRUE) || all(vals %in% FALSE)
    }
    if (reste) next
    r$v[i] <- NA
    r <- .k3_index(r, "dossiers", i, p$j[k], ns)
    for (tc in names(nc$index)) r <- .k3_index(r, tc, i, unlist(nc$index[[tc]][k]), ns)
  }
  # contrats en cause du sous-cas du maintien : contrats (toutes les valeurs renseignées du
  # domaine d'un contrat inconnu) d'un dossier retenu non couvert (vrai ou inconnu) ; sans
  # dossier retenu, tout contrat (NULL)
  en_cause <- rep(list(character(0)), ns)
  for (m in which(ret & !(nc$v %in% FALSE))) {
    en_cause[[p$i[m]]] <- unique(c(en_cause[[p$i[m]]], if (diverge[m]) jc$domaines[[m]] else contrat_d[m]))
  }
  en_cause[!avec] <- list(NULL)
  # sous-cas du maintien de la garantie décès : sinistres deces non couverts (vrai ou inconnu)
  lire <- .lecture_maintien_d11(ctx)
  actif <- function() v("sinistres", "nature_sinistre") %in% "deces" & !(r$v %in% FALSE)
  if (lire$n && lire$m && lire$e) {
    m3 <- .maintien_d11(ctx, seq_len(ns), actif(), en_cause)
    return(.k3_resultat(.k3_op(`&`, r, .k3(!m3$v, m3$index))))
  }
  # partie lisible du sous-cas ; nature illisible : tout sinistre non couvert. Sous-cas inconnu :
  # écarté (vrai -> faux ; inconnu : garde l'index de la couverture) ; aucun sous-cas n'y est
  # vrai (la partie illisible le rend inconnu)
  inconnu <- if (lire$n) {
    is.na(.maintien_d11(ctx, seq_len(ns), actif(), en_cause, lire_maintien = lire$m, lire_evenements = lire$e)$v)
  } else {
    !(r$v %in% FALSE)
  }
  res <- .k3_resultat(r)
  res[inconnu & res %in% TRUE] <- FALSE
  if (any(ctx$retenu$sinistres & inconnu)) .ecarter_maintien_d11(ctx, "D11a", "sinistres")
  res
}

# Lecture grossière du sous-cas du maintien (Q-22, M659 ; D11a, et D11b par décision du
# mainteneur du 19/11/2026) : parties lisibles du sous-cas, colonnes de .LIT_MAINTIEN_D11 lues
# comme .regle() (lues comme valeurs : toute cause ; colonnes de la vue de evenements : cause
# autre qu'un refus de valeur, toute cause à l'extraction) : `n` (nature du sinistre), `m`
# (maintien_deces et garantie en vigueur), `e` (evenements).
.lecture_maintien_d11 <- function(ctx) {
  lit_m <- .LIT_MAINTIEN_D11
  illisible_vue_ev <- any(vapply(setdiff(ctx$lit_vue$evenements, lit_m), function(tc) {
    m <- strsplit(tc, ".", fixed = TRUE)[[1L]]
    (.vue_totale(ctx) || is.null(.lignes_refusees(ctx, m[1L], m[2L]))) && !is.na(.cause(ctx, m[1L], m[2L]))
  }, NA))
  lisible <- function(prefixe) is.null(.cause_lecture(ctx, grep(paste0("^", prefixe, "\\."), lit_m, value = TRUE)))
  list(n = is.na(.cause(ctx, "sinistres", "nature_sinistre")), m = lisible("garanties_souscrites"),
       e = lisible("evenements") && !illisible_vue_ev)
}
# Ligne (`code`, `table`, NA) de controles_non_executes d'une ligne écartée au sous-cas du
# maintien illisible : cause directe des colonnes illisibles du sous-cas (comme
# .lecture_maintien_d11()), départagée (§ 3.1, .cause_retenue(), comme M169).
.ecarter_maintien_d11 <- function(ctx, code, table) {
  lit_m <- .LIT_MAINTIEN_D11
  tc_m <- c(lit_m, setdiff(ctx$lit_vue$evenements, lit_m))
  candidates <- lapply(tc_m, function(tc) {
    m <- strsplit(tc, ".", fixed = TRUE)[[1L]]
    vue_seule <- !(tc %in% lit_m) && !.vue_totale(ctx) && !is.null(.lignes_refusees(ctx, m[1L], m[2L]))
    if (vue_seule) character(0) else .causes(ctx, m[1L], m[2L])
  })
  cause <- .cause_retenue(unlist(candidates), ctx$dico, ctx$ordre_codes)
  lu <- tc_m[vapply(candidates, function(z) cause %in% z, NA)]
  .ajouter_non_execute(ctx, code, table, NA_character_, cause, lu = sort(lu, method = "radix"))
}

# Sous-cas du maintien de la garantie décès de D11 (spécification `donnees` v1.9, § 9.5 ; M657,
# M658 ; interprétations déclarées M669 et M670, jugements d'expert : le terme de la période
# d'incapacité ou d'invalidité est lu comme la fin de l'arrêt (.arret_en_cours3()), la fin d'une
# affiliation comme la résiliation ou le non-renouvellement du contrat ; limite connue C1, #166),
# seule implémentation, lue par D11a et D11b : pour chaque élément (ligne `sin` de sinistres),
# verdict à trois valeurs (.k3()) « l'assuré du sinistre a un sinistre arret_travail, retenu ou
# non déterminé, survenu pendant une affiliation retenue de fin connue à l'arrêté et antérieure
# au décès, à un contrat en cause (`en_cause` : liste par élément de contrats, NULL : tout
# contrat ; clé manquante ou vide : aucun appariement, apparier_cles(), #152) et, si `college`
# est renseigné pour l'élément, dans ce collège ; la garantie deces de ce contrat, au collège de
# l'affiliation, porte maintien_deces TRUE dans sa version en vigueur à la survenance de l'arrêt
# (.garantie_en_vigueur3()) ; l'arrêt est en cours à la fin de l'affiliation et au décès (avant
# le décès : événements d'effet strictement antérieur, .arret_en_cours3()) ».
# Contrat individuel : hors sous-cas (affiliations seules). maintien_deces FALSE, ou pas de
# garantie deces à ce collège : la paire est hors sous-cas, sans lecture de evenements ; version
# non déterminée qui le porterait : inconnu (index : ces versions). `actif` : éléments évalués
# (les autres : faux ; l'appelant y met les sinistres deces). `lire_maintien`, `lire_evenements`
# FAUX (colonnes illisibles, lecture grossière, Q-22, M659) : la partie non lue rend la paire
# inconnue, sans index (l'appelant écarte avec la cause directe).
.maintien_d11 <- function(ctx, sin, actif, en_cause = NULL, college = NULL, lire_maintien = TRUE, lire_evenements = TRUE) {
  v <- function(t, c1) .valeurs(ctx, t, c1)
  n <- length(sin)
  m3 <- .k3(rep(FALSE, n))
  el <- which(actif)
  if (length(el) == 0L) return(m3)
  assure <- as.character(v("sinistres", "id_assure"))
  surv <- as.numeric(v("sinistres", "date_survenance"))
  # affiliations retenues de fin connue (partie de fin visible)
  na <- nrow(ctx$base$affiliations)
  partie <- if (.vue_totale(ctx)) NULL else .visibilite_a(ctx, "vue")$parties$affiliations
  if (is.null(partie)) partie <- rep(TRUE, na)
  debut <- as.numeric(v("affiliations", "date_debut"))
  fin <- ifelse(partie %in% TRUE, as.numeric(v("affiliations", "date_fin")), NA_real_)
  contrat <- .cle_manquante(as.character(v("affiliations", "id_contrat")))
  college_a <- .cle_manquante(as.character(v("affiliations", "college")))
  aff <- which(ctx$retenu$affiliations & !is.na(debut) & !is.na(fin))
  # paires (élément, affiliation) : même assuré, fin antérieure au décès, contrat en cause, collège
  p <- .paires(assure[sin[el]], as.character(v("affiliations", "id_assure"))[aff])
  e <- el[p$i]
  a <- aff[p$j]
  garde <- !is.na(surv[sin[e]]) & fin[a] < surv[sin[e]]
  if (!is.null(en_cause)) {
    garde <- garde & vapply(seq_along(e), function(z) {
      x <- en_cause[[e[z]]]
      is.null(x) || !is.na(apparier_cles(contrat[a[z]], x))
    }, NA)
  }
  if (!is.null(college)) {
    k_e <- .cle_manquante(as.character(college))[e]
    garde <- garde & (is.na(k_e) | (!is.na(college_a[a]) & college_a[a] == k_e) %in% TRUE)
  }
  e <- e[garde]
  a <- a[garde]
  if (length(e) == 0L) return(m3)
  # sinistres arret_travail de l'assuré (retenus ou non déterminés), survenus pendant l'affiliation
  arret <- which(v("sinistres", "nature_sinistre") %in% "arret_travail" & (ctx$retenu$sinistres | .nd_vue(ctx, "sinistres")) &
                   !is.na(surv))
  q <- .paires(assure[sin[e]], assure[arret])
  e <- e[q$i]
  a <- a[q$i]
  s <- arret[q$j]
  garde <- surv[s] >= debut[a] & surv[s] <= fin[a]
  e <- e[garde]
  a <- a[garde]
  s <- s[garde]
  nt <- length(e)
  if (nt == 0L) return(m3)
  # maintien_deces de la garantie deces de (contrat, collège) de l'affiliation, en vigueur à la
  # survenance de l'arrêt : vrai si une version retenue le porte ; inconnu sinon si une version
  # non déterminée peut le porter ; faux sinon (dont : aucune garantie deces à ce collège)
  if (lire_maintien) {
    g <- .garantie_en_vigueur3(ctx, "deces", list(contrat = v("affiliations", "id_contrat")[a],
                                                   college = v("affiliations", "college")[a]), surv[s])
    maintien <- v("garanties_souscrites", "maintien_deces")
    vrai <- vapply(g$versions, function(j) any(maintien[j] %in% TRUE), NA)
    possible <- lapply(g$versions_nd, function(j) j[!(maintien[j] %in% FALSE)])
    mt <- .k3(ifelse(vrai, TRUE, ifelse(lengths(possible) > 0L, NA, FALSE)))
    for (z in which(is.na(mt$v))) mt <- .k3_index(mt, "garanties_souscrites", z, possible[[z]], nt)
  } else {
    mt <- .k3(rep(NA, nt))
  }
  # paires hors sous-cas (maintien_deces faux) : evenements n'est pas lu pour elles
  garde <- !(mt$v %in% FALSE)
  if (!any(garde)) return(m3)
  mt <- .k3_sous(mt, garde)
  e <- e[garde]
  a <- a[garde]
  s <- s[garde]
  nt <- length(e)
  sr <- .k3(ifelse(ctx$retenu$sinistres[s], TRUE, NA))
  for (z in which(is.na(sr$v))) sr <- .k3_index(sr, "sinistres", z, s[z], nt)
  if (lire_evenements) {
    ec_fin <- .arret_en_cours3(ctx, s, fin[a])
    ec_deces <- .arret_en_cours3(ctx, s, surv[sin[e]], strict = TRUE)
  } else {
    ec_fin <- .k3(rep(NA, nt))
    ec_deces <- ec_fin
  }
  .k3_par(e, .k3_op(`&`, mt, sr, ec_fin, ec_deces), n, "un")
}

# Arrêt en cours à la date t (spécification `donnees` v1.9, § 9.5 ; M658, #128, point 1) : pour
# chaque élément (ligne `s` de sinistres, date `t`), le dernier événement retenu du sinistre de
# type sortie ou rechute, de date d'effet au plus t (`strict` : strictement antérieure à t ; au
# décès, décision du mainteneur du 19/11/2026, option (a) : une sortie datée du décès, motif
# deces compris, ne met pas fin à l'arrêt avant le décès), dans l'ordre du § 4.2
# (.dernier_evenement()), n'est pas une sortie ; sans tel événement, l'arrêt est en cours (une
# sortie, quel que soit son motif, met fin à l'arrêt ; le passage_invalidite ne le rompt pas,
# M669). Inconnu si un événement de ces types non déterminé, ou retenu de date d'effet inconnue
# (refus de valeur de portée ligne, décision du mainteneur du 19/11/2026), de date d'effet dans
# la borne ou inconnue, qui peut suivre le dernier retenu (.peut_suivre()), est d'un verdict
# différent (index : ces événements, sous « evenements » pour un événement non déterminé, sous
# « evenements.date_effet » pour un événement retenu de date d'effet refusée, dont .cause_nd()
# retient le motif du refus ; audit de la reprise de #81, #72). Rend un .k3() aligné sur les
# éléments.
.arret_en_cours3 <- function(ctx, s, t, strict = FALSE) {
  n <- length(s)
  res <- .k3(rep(TRUE, n))
  if (n == 0L) return(res)
  type <- .valeurs(ctx, "evenements", "type_evenement")
  effet <- .date_connue(ctx, "evenements", "date_effet")
  inconnue <- .inconnu(ctx, "evenements", "date_effet")
  fr <- which(type %in% c("sortie", "rechute"))
  p <- .paires(.valeurs(ctx, "sinistres", "id_sinistre")[s], .valeurs(ctx, "evenements", "id_sinistre")[fr])
  ev <- fr[p$j]
  dans <- function(x) if (strict) x < t[p$i] else x <= t[p$i]
  q <- ctx$retenu$evenements[ev] & !is.na(effet[ev]) & dans(effet[ev])
  dernier <- .dernier_evenement(ctx, data.frame(i = ev[q], j = p$i[q]), n)
  res$v <- is.na(dernier) | type[dernier] %in% "rechute"
  possible <- .nd_vue(ctx, "evenements")[ev] | (ctx$retenu$evenements[ev] & inconnue[ev])
  k <- which(possible & !(dans(effet[ev]) %in% FALSE))
  k <- k[.peut_suivre(ctx, ev[k], dernier[p$i[k]])]
  k <- k[(type[ev[k]] %in% "rechute") != res$v[p$i[k]]]
  nd_ev <- .nd_vue(ctx, "evenements")
  for (z in split(k, p$i[k])) {
    i <- p$i[z[1L]]
    res$v[i] <- NA
    e <- ev[z]
    if (any(nd_ev[e])) res <- .k3_index(res, "evenements", i, e[nd_ev[e]], n)
    if (any(!nd_ev[e])) res <- .k3_index(res, "evenements.date_effet", i, e[!nd_ev[e]], n)
  }
  res
}

# « Il existe une couverture » à trois valeurs, par élément (1 à `n`), sur des lignes de
# .couverture3() : vrai si l'une est certaine ; inconnu sinon si l'une est possible (index :
# ligne ou partie non déterminée) ; faux sinon. Lu par D11b.
.existe_couverture3 <- function(cv, n) {
  x <- .k3(rep(FALSE, n))
  if (nrow(cv) == 0L) return(x)
  x$v[unique(cv$i[cv$certain])] <- TRUE
  for (z in which(!cv$certain & !(x$v[cv$i] %in% TRUE))) {
    x$v[cv$i[z]] <- NA
    x <- .k3_index(x, cv$tc[z], cv$i[z], cv$ligne[z], n)
  }
  x
}

# Verdict de D11b sur les lignes de dossiers (.regle_v_couverture()) : vecteur logique, attribut
# `index` s'il est inconnu. Contrat et collège de la garantie lus sur toutes les occurrences de sa
# clé (C-5 de #164, même règle que le contrat de D11a) : verdict de chaque occurrence, connu s'ils
# concordent, inconnu sinon (index : les occurrences de garanties_souscrites).
.verdict_d11b <- function(ctx) {
  v <- function(t, c1) .valeurs(ctx, t, c1)
  nd <- nrow(ctx$base$dossiers)
  s <- apparier_cles(v("dossiers", "id_sinistre"), v("sinistres", "id_sinistre"))
  assure <- as.character(v("sinistres", "id_assure"))
  surv <- as.numeric(v("sinistres", "date_survenance"))
  lire <- .lecture_maintien_d11(ctx)
  deces <- if (lire$n) v("sinistres", "nature_sinistre") %in% "deces"
  # occurrences de la garantie du dossier (une seule hors clé en double ; NA : aucune ligne)
  idx <- .index_jointure(ctx, "garanties_souscrites", "id_garantie_souscrite", v("dossiers", "id_garantie_souscrite"))
  occ <- attr(idx, "occurrences")
  o <- lapply(seq_len(nd), function(d) if (!is.null(occ) && length(occ[[d]]) > 0L) occ[[d]] else idx[d])
  cd <- data.frame(d = rep(seq_len(nd), lengths(o)), o = unlist(o))
  contrat <- .cle_manquante(as.character(v("garanties_souscrites", "id_contrat")))[cd$o]
  college <- .cle_manquante(as.character(v("garanties_souscrites", "college")))[cd$o]
  # contrat individuel (hors champ) lu sur les lignes retenues de contrats (vue, § 8.0 bis,
  # point 1) ; ligne non déterminée de nature individuel : verdict inconnu (cause γ)
  ind <- v("contrats", "nature_contrat") %in% "individuel"
  id_c <- .cle_manquante(as.character(v("contrats", "id_contrat")))
  individuel <- id_c[ind & ctx$retenu$contrats]
  ind_nd <- which(ind & .nd_vue(ctx, "contrats"))
  # garantie de couple (contrat, collège) renseigné, contrat non individuel
  champ <- which(!is.na(contrat) & !is.na(college) & !is.na(s[cd$d]) & is.na(apparier_cles(contrat, individuel)))
  atome <- .k3(rep(FALSE, nrow(cd)))
  ecarte <- rep(FALSE, nrow(cd))
  if (length(champ) > 0L) {
    se <- s[cd$d[champ]]
    ne <- length(champ)
    meme_contrat <- function(cv) cv[!is.na(.cle_manquante(as.character(cv$contrat))) &
                                      .cle_manquante(as.character(cv$contrat)) == contrat[champ][cv$i], , drop = FALSE]
    # aucune affiliation à ce contrat dans ce collège ne couvre la survenance
    dans_college <- .existe_couverture3(meme_contrat(.couverture3(ctx, assure[se], surv[se], college = college[champ])), ne)
    # une affiliation au même contrat dans un autre collège la couvre
    cv <- meme_contrat(.couverture3(ctx, assure[se], surv[se]))
    k_cv <- .cle_manquante(as.character(cv$college))
    autre <- .existe_couverture3(cv[cv$affiliation & !is.na(k_cv) & k_cv != college[champ][cv$i], , drop = FALSE], ne)
    x <- .k3_op(`&`, .k3(!dans_college$v, dans_college$index), autre)
    # sous-cas du maintien restreint aux affiliations du collège du dossier, au contrat du dossier ;
    # lecture grossière (comme D11a) : une partie illisible rend le sous-cas inconnu, le dossier
    # est écarté (vrai -> faux), la cause directe est écrite ci-dessous
    if (lire$n && lire$m && lire$e) {
      m3 <- .maintien_d11(ctx, se, deces[se], en_cause = as.list(contrat[champ]), college = college[champ])
      x <- .k3_op(`&`, x, .k3(!m3$v, m3$index))
    } else {
      inconnu <- if (lire$n) {
        is.na(.maintien_d11(ctx, se, deces[se], en_cause = as.list(contrat[champ]), college = college[champ],
                            lire_maintien = lire$m, lire_evenements = lire$e)$v)
      } else rep(TRUE, ne)
      ecarte[champ] <- inconnu & !(x$v %in% FALSE)
      x$v[ecarte[champ] & x$v %in% TRUE] <- FALSE
    }
    # contrat individuel peut-être, par une ligne non déterminée : vrai -> inconnu
    if (length(ind_nd) > 0L) {
      for (z in which(x$v %in% TRUE | is.na(x$v))) {
        l <- ind_nd[!is.na(apparier_cles(id_c[ind_nd], contrat[champ][z]))]
        if (length(l) == 0L) next
        x$v[z] <- NA
        x <- .k3_index(x, "contrats", z, l, ne)
      }
    }
    atome$v[champ] <- x$v
    for (tc in names(x$index)) {
      atome$index[[tc]] <- vector("list", nrow(cd))
      atome$index[[tc]][champ] <- x$index[[tc]]
    }
  }
  if (any(ecarte & ctx$retenu$dossiers[cd$d])) .ecarter_maintien_d11(ctx, "D11b", "dossiers")
  # par dossier : verdict de chaque occurrence ; connu s'ils concordent
  r <- .k3_par(cd$d, atome, nd, "un")
  for (d in unique(cd$d[duplicated(cd$d)])) {
    z <- which(cd$d == d)
    vs <- atome$v[z]
    r$v[d] <- if (all(vs %in% TRUE)) TRUE else if (all(vs %in% FALSE)) FALSE else NA
    if (!is.na(r$v[d])) next
    if (length(unique(vs)) > 1L) r <- .k3_index(r, "garanties_souscrites", d, cd$o[z], nd)
    for (tc in names(atome$index)) r <- .k3_index(r, tc, d, unlist(atome$index[[tc]][z[is.na(vs)]]), nd)
  }
  .k3_resultat(r)
}

# Verdict de D11c sur les lignes d'affiliations (.regle_v_couverture()) : vecteur logique, attribut
# `index` s'il est inconnu. Période de couverture : [date_debut ; date_fin connue à l'arrêté]
# (fin absente ou inconnue à l'arrêté : ouverte) ; partie de fin non déterminée : fin connue ou
# ouverte ; une ligne non déterminée peut exister.
.verdict_d11c <- function(ctx) {
  v <- function(c1) .valeurs(ctx, "affiliations", c1)
  n <- nrow(ctx$base$affiliations)
  r <- .k3(rep(FALSE, n))
  assure <- .cle_manquante(as.character(v("id_assure")))
  contrat <- .cle_manquante(as.character(v("id_contrat")))
  college <- .cle_manquante(as.character(v("college")))
  debut <- as.numeric(v("date_debut"))
  fin <- as.numeric(v("date_fin"))
  partie <- if (.vue_totale(ctx)) NULL else .visibilite_a(ctx, "vue")$parties$affiliations
  if (is.null(partie)) partie <- rep(TRUE, n)
  retenu <- ctx$retenu$affiliations
  nd <- .nd_vue(ctx, "affiliations")
  # fin au plus tôt (connue à l'arrêté, ou partie non déterminée) et au plus tard (ouverte si
  # elle n'est pas connue à l'arrêté de façon certaine)
  f_min <- ifelse(is.na(fin) | partie %in% FALSE, Inf, fin)
  f_max <- ifelse(is.na(fin) | !(partie %in% TRUE), Inf, fin)
  # groupe (assuré, contrat) ; composante de clé manquante ou vide, collège manquant ou vide,
  # début absent : hors du contrôle
  dans <- (retenu | nd) & !is.na(college) & !is.na(debut)
  groupe <- .code_groupe(list(assure, contrat), cles = 1:2)
  groupe[!dans] <- NA
  p <- .paires(groupe, groupe)
  p <- p[p$i != p$j & college[p$i] != college[p$j], , drop = FALSE]
  i <- p$i
  j <- p$j
  certain <- retenu[i] & retenu[j] & debut[i] <= f_min[j] & debut[j] <= f_min[i]
  possible <- !certain & debut[i] <= f_max[j] & debut[j] <= f_max[i]
  r$v[unique(i[certain])] <- TRUE
  for (z in which(possible & !(r$v[i] %in% TRUE))) {
    r$v[i[z]] <- NA
    for (y in c(i[z], j[z])) {
      if (nd[y]) r <- .k3_index(r, "affiliations", i[z], y, n)
      else if (is.na(partie[y])) r <- .k3_index(r, .colonne_partie(ctx, "affiliations", y), i[z], y, n)
    }
  }
  res <- .k3_resultat(r)
  # règle V en mode Kleene (#105, lot V, G2a ; D-G2-2, exact par conditionnement, à titre
  # provisoire) : collège (code opaque), début et fin refusés pour leur valeur. Lignes touchées
  # (une inconnue sur la ligne ou sur une affiliation de son groupe) recalculées par
  # .d11c_ligne3() ; les autres gardent le verdict ci-dessus (index pertinent : son index)
  inc <- list(college = .inconnu(ctx, "affiliations", "college"), debut = .inconnu(ctx, "affiliations", "date_debut"),
              fin = .inconnu(ctx, "affiliations", "date_fin"))
  ip <- attr(res, "index", exact = TRUE)
  if (is.null(ip)) ip <- list()
  lues <- paste0("affiliations.", c("college", "date_debut", "date_fin"))
  porteuses <- which((inc$college | inc$debut | inc$fin) & (retenu | nd))
  if (length(porteuses) > 0L) {
    dans3 <- (retenu | nd) & (!is.na(college) | inc$college) & (!is.na(debut) | inc$debut)
    groupe3 <- .code_groupe(list(assure, contrat), cles = 1:2)
    groupe3[!dans3] <- NA
    touchees <- which(retenu & !is.na(groupe3) & groupe3 %in% groupe3[porteuses])
    plage_d <- .plage_date3(ctx, "affiliations", "date_debut")
    plage_f <- .plage_date3(ctx, "affiliations", "date_fin")
    for (l in touchees) {
      for (tc in names(ip)) ip[[tc]][l] <- list(NULL)
      J <- setdiff(which(groupe3 %in% groupe3[l]), l)
      x <- .d11c_ligne3(ctx, l, J, college, debut, fin, partie, retenu, nd, inc, plage_d, plage_f)
      res[l] <- x$v
      for (k in seq_along(x$pert)) {
        tc <- x$pert[[k]][1L]
        if (is.null(ip[[tc]])) ip[[tc]] <- vector("list", n)
        ip[[tc]][l] <- list(sort(unique(c(ip[[tc]][[l]], as.integer(x$pert[[k]][2L])))))
      }
    }
  }
  attr(res, "index") <- ip
  attr(res, "index_pertinent") <- ip
  attr(res, "lues") <- lues
  res
}

# Le collège d'une affiliation n'est jamais refusé pour sa valeur (une valeur hors domaine est
# un refus D04b, une chaîne vide un refus chaine_vide, tous deux de portée table, qui bloquent la
# règle) : le chemin du collège inconnu n'est pas atteint par une base (comme le chemin D01a,
# #169) ; il est vérifié par appel direct (oracle de simulation).
# D11c pour la ligne `l` d'affiliations et ses affiliations candidates `J` (même assuré, même
# contrat ; #105, lot V, G2a ; D-G2-2) : la ligne est détectée s'il existe j, présent, de collège
# différent, dont la période chevauche la sienne (début de l'une au plus la fin de l'autre ; fin
# absente ou non connue à l'arrêté : ouverte). Les cellules inconnues de la ligne (collège : les
# collèges connus du groupe et une valeur neuve ; début : bornes de sa plage ; partie de fin non
# déterminée : connue ou non ; fin : bornes de sa plage et absence) sont conditionnées ; sachant
# elles, les paires sont indépendantes, chacune conjonction d'atomes sur des cellules distinctes
# (présence d'une ligne non déterminée, collège de j, fin de j et sa partie, début de j) : Kleene
# exact. Verdict : constant sur les affectations conditionnées, sinon NA. Pertinence : une cellule
# conditionnée par propagation de paires (.pertinence_paires3()) ; une cellule de j si elle est
# pertinente dans une évaluation conditionnelle (atome inconnu de sa paire, paire inconnue, aucune
# paire vraie). Rend v et pert (couples « clé », ligne).
.d11c_ligne3 <- function(ctx, l, J, college, debut, fin, partie, retenu, nd, inc, plage_d, plage_f) {
  neuf <- "\001neuf"
  fin_val <- function(c1, f1) if (!isTRUE(c1)) Inf else if (is.na(f1)) Inf else f1
  rupture <- function(plage, pts) unique(c(plage, pts[is.finite(pts) & pts >= plage[1L] & pts <= plage[2L]]))
  fins_j <- unlist(lapply(J, function(j) if (inc$fin[j]) plage_f else fin[j]))
  debuts_j <- unlist(lapply(J, function(j) if (inc$debut[j]) plage_d else debut[j]))
  dom_l <- list(
    # collège inconnu : collèges connus du groupe, une valeur neuve, et une seconde si un collège
    # du groupe est inconnu (le collège de j peut alors égaler l'une sans égaler l'autre)
    college = if (inc$college[l]) unique(c(college[J][!inc$college[J] & !is.na(college[J])], neuf,
                                           if (any(inc$college[J])) paste0(neuf, "2"))) else college[l],
    # début et fin inconnus : bornes de leur plage et points de rupture relatifs aux cellules qui
    # les comparent (fin de chaque j, connue ou bornes de sa plage, et le lendemain ; début de
    # chaque j, connu ou bornes de sa plage, et la veille) : la pertinence des cellules de j se
    # lit sur ces représentants (audit de G2a)
    debut = if (inc$debut[l]) rupture(plage_d, c(fins_j, fins_j + 1)) else debut[l],
    connue = if (is.na(partie[l])) c(TRUE, FALSE) else partie[l] %in% TRUE,
    fin = if (inc$fin[l]) c(rupture(plage_f, c(debuts_j, debuts_j - 1)), NA) else fin[l])
  cle_l <- c(college = "affiliations.college", debut = "affiliations.date_debut",
             connue = .colonne_partie(ctx, "affiliations", l), fin = "affiliations.date_fin")
  grille <- expand.grid(lapply(dom_l, seq_along), KEEP.OUT.ATTRS = FALSE)
  # paire (l, j) sachant l'affectation a : valeur et cellules de j pertinentes
  paire <- function(a, j) {
    ci <- dom_l$college[a$college]; di <- dom_l$debut[a$debut]
    fi <- fin_val(dom_l$connue[a$connue], dom_l$fin[a$fin])
    atomes <- list()
    # présence de j
    atomes$present <- list(v = if (retenu[j]) TRUE else NA, cle = if (!retenu[j]) list(c("affiliations", j)))
    # collège différent
    atomes$college <- if (inc$college[j]) list(v = NA, cle = list(c("affiliations.college", j))) else
      list(v = !identical(ci, college[j]) && !is.na(college[j]), cle = list())
    # début de l (connu sachant a) au plus la fin de j
    cj <- if (is.na(partie[j])) c(TRUE, FALSE) else partie[j] %in% TRUE
    fj <- if (inc$fin[j]) c(plage_f, NA) else fin[j]
    g <- expand.grid(c = seq_along(cj), f = seq_along(fj))
    ov <- vapply(seq_len(nrow(g)), function(z) di <= fin_val(cj[g$c[z]], fj[g$f[z]]), NA)
    cle1 <- list()
    if (length(unique(ov)) > 1L) {
      if (length(cj) > 1L && any(tapply(ov, g$f, function(z) length(unique(z)) > 1L))) cle1 <- c(cle1, list(c(.colonne_partie(ctx, "affiliations", j), j)))
      if (length(fj) > 1L && any(tapply(ov, g$c, function(z) length(unique(z)) > 1L))) cle1 <- c(cle1, list(c("affiliations.date_fin", j)))
    }
    atomes$ov1 <- list(v = if (all(ov)) TRUE else if (!any(ov)) FALSE else NA, cle = cle1)
    # début de j au plus la fin de l (sachant a)
    dj <- if (inc$debut[j]) plage_d else debut[j]
    ov2 <- dj <= fi
    atomes$ov2 <- list(v = if (all(ov2)) TRUE else if (!any(ov2)) FALSE else NA,
                       cle = if (length(unique(ov2)) > 1L) list(c("affiliations.date_debut", j)) else list())
    vs <- vapply(atomes, `[[`, NA, "v")
    if (any(vs %in% FALSE)) return(list(v = FALSE, cle = list()))
    if (all(vs %in% TRUE)) return(list(v = TRUE, cle = list()))
    list(v = NA, cle = unlist(lapply(atomes[is.na(vs)], `[[`, "cle"), recursive = FALSE))
  }
  ligne_a <- lapply(seq_len(nrow(grille)), function(z) {
    a <- grille[z, , drop = FALSE]
    if (is.na(dom_l$college[a$college]) || is.na(dom_l$debut[a$debut])) return(list(v = FALSE, cle = list()))
    ps <- lapply(J, function(j) paire(a, j))
    pv <- vapply(ps, `[[`, NA, "v")
    if (any(pv %in% TRUE)) return(list(v = TRUE, cle = list()))
    if (!any(is.na(pv))) return(list(v = FALSE, cle = list()))
    list(v = NA, cle = unlist(lapply(ps[is.na(pv)], `[[`, "cle"), recursive = FALSE))
  })
  va <- vapply(ligne_a, `[[`, NA, "v")
  v <- if (all(va %in% TRUE)) TRUE else if (all(va %in% FALSE)) FALSE else NA
  pert <- list()
  if (is.na(v)) {
    # cellules de la ligne (conditionnées) : propagation de paires (.pertinence_paires3()), pour
    # chaque affectation des autres cellules de la ligne ; couples de chaque paire (l, j) sur les
    # mêmes valeurs des cellules de j (points de rupture relatifs aux deux affectations)
    couples_j <- function(a1, a2) lapply(J, function(j) {
      cote <- lapply(list(a1, a2), function(a) list(ci = dom_l$college[a$college], di = dom_l$debut[a$debut],
                                                     fi = fin_val(dom_l$connue[a$connue], dom_l$fin[a$fin])))
      dans_plage <- function(z, pl) z[is.finite(z) & z >= pl[1L] & z <= pl[2L]]
      di <- vapply(cote, `[[`, 0, "di"); fi <- vapply(cote, `[[`, 0, "fi")
      reps <- list(e = if (retenu[j]) TRUE else c(TRUE, FALSE),
                   c = if (inc$college[j]) unique(c(college[J][!inc$college[J] & !is.na(college[J])],
                                                    vapply(cote, `[[`, "", "ci"), paste0(neuf, j))) else college[j],
                   p = if (is.na(partie[j])) c(TRUE, FALSE) else partie[j] %in% TRUE,
                   f = if (inc$fin[j]) c(unique(c(plage_f, dans_plage(c(di, di - 1), plage_f))), NA) else fin[j],
                   d = if (inc$debut[j]) unique(c(plage_d, dans_plage(c(fi, fi + 1), plage_d))) else debut[j])
      g <- expand.grid(reps, stringsAsFactors = FALSE, KEEP.OUT.ATTRS = FALSE)
      v <- lapply(cote, function(cs) {
        fj <- ifelse(g$p & !is.na(g$f), g$f, Inf)
        g$e & !is.na(g$c) & g$c != cs$ci & cs$di <= fj & g$d <= cs$fi
      })
      unique(cbind(v[[1L]], v[[2L]]))
    })
    for (nom in names(dom_l)) {
      if (length(dom_l[[nom]]) < 2L) next
      autres <- setdiff(names(dom_l), nom)
      ga <- expand.grid(lapply(dom_l[autres], seq_along), KEEP.OUT.ATTRS = FALSE)
      pertinente <- any(vapply(seq_len(nrow(ga)), function(z) {
        .pertinence_paires3(as.list(seq_along(dom_l[[nom]])), function(i1, i2) {
          a1 <- ga[z, , drop = FALSE]; a1[[nom]] <- i1
          a2 <- ga[z, , drop = FALSE]; a2[[nom]] <- i2
          couples_j(a1, a2)
        }, `|`, FALSE)
      }, NA))
      if (pertinente) pert <- c(pert, list(c(cle_l[[nom]], l)))
    }
    pert <- c(pert, unlist(lapply(ligne_a[is.na(va)], `[[`, "cle"), recursive = FALSE))
  }
  list(v = v, pert = unique(pert))
}

# D12, suite d'états impossible (dictionnaire, § 4 et § 9 ; spécification `donnees` v1.6,
# § 8.8), sur la vue, constat sur evenements, colonne type_evenement, détection exacte : pour
# chaque sinistre arret_travail, événements de niveau sinistre de l'automate (types de
# types_evenements.csv qui ont un état de départ) retenus dans la vue, toutes dates d'effet, dans
# l'ordre de la date d'effet, de l'ordre du type (§ 4), puis de l'identifiant ; identifiant : le
# premier événement à partir duquel l'automate échoue (.pas_d12()), un par sinistre. Traitement
# X par sinistre pour engagement (l'exclusion porte sur le sinistre, .placer()) et S pour triangle,
# risque_en_cours et regle_comptable (.exceptions_famille()) : deux constats de même clé (comme
# D03a). Verdict à trois valeurs sans plafond (#129 ; erratum `1.9.7`, E-5 ; M813) : propagation,
# en un passage dans l'ordre, de l'ensemble des configurations de l'automate (.propager_d12()),
# exact hors date d'effet inconnue ; approximation sûre sous une date refusée (M813) ; voir
# .verdict_d12().
.regle_v_suites <- function(ctx) {
  lit <- c(paste0("evenements.", c("id_evenement", "id_sinistre", "type_evenement", "date_effet", "motif")),
           "sinistres.id_sinistre", "sinistres.nature_sinistre")
  verdict <- NULL
  f <- function() {
    if (is.null(verdict)) verdict <<- .verdict_d12(ctx)
    verdict
  }
  for (t in c("S", "X")) .regle_vue(ctx, "D12", "evenements", "type_evenement", lit, t, "exacte", f,
                                     vue = ctx$lit_vue$sinistres)
  invisible(NULL)
}

# Pas de l'automate du § 4 du dictionnaire (types_evenements.csv, colonnes etat_depuis et
# etat_vers, lues à la lettre) : depuis l'état `etat` (état antérieur à la dernière sortie :
# `ante`), événement de type `type` et de motif `motif` ; NULL si l'état n'admet pas le type
# (échec), sinon c(état, état antérieur) après l'événement. États : depart, incapacite,
# invalidite, et « état:motif » après une sortie (clos:reprise_travail, clos:fin_droits…,
# eteint:deces, retraite:retraite) ; une sortie de motif absent ou hors de la liste mène à un
# état qu'aucun type n'admet (K1 : une sortie sans motif connu n'est pas une sortie
# reprise_travail) ; rechute (etat_vers « anterieur ») rend l'état antérieur à la dernière
# sortie. Le délai de rechute n'est pas lu (le texte de l'automate ne le cite pas).
.pas_d12 <- function(te, etat, ante, type, motif) {
  i <- match(type, te$type_evenement)
  if (!(etat %in% eclater_champ(te$etat_depuis[i]))) return(NULL)
  vers <- te$etat_vers[i]
  if (vers == "anterieur") return(c(ante, ante))
  if (!grepl(":", vers, fixed = TRUE)) return(c(vers, ante))
  suivant <- "inconnu"
  for (bloc in eclater_champ(vers)) {
    cible <- sub(":.*$", "", bloc)
    if (!is.na(motif) && motif %in% strsplit(sub("^[^:]*:", "", bloc), ",", fixed = TRUE)[[1L]]) {
      suivant <- paste0(cible, ":", motif)
    }
  }
  c(suivant, etat)
}

# Propagation de l'automate (#129 ; critère C129-5, M813) : `pas`, une position par élément,
# liste des transitions possibles à cette position (`type`, `motif`, `ligne` : ligne de
# evenements ; `type` NA : « sauter ») et nombre de passages (`repete`, arrêt au point fixe) ; ou
# groupe (`etapes`, .propager_groupe_d12()) : événements de même date d'effet dont l'ordre dépend
# d'un type inconnu. L'ensemble des configurations (état, état antérieur) sans échec, parti de
# (`etat`, `ante`), est propagé en un passage dans l'ordre ; une transition qui échoue ajoute sa
# ligne aux premiers échecs possibles. Rend `echecs` (lignes de premier échec possibles), `fin`
# (TRUE si une suite possible va au bout sans échec), et les configurations d'arrivée (`etat`,
# `ante`). Le nombre de configurations est borné par le carré du nombre d'états : coût linéaire
# en le nombre de positions, au plus m² par intervalle sous m événements de date inconnue (m + 1
# transitions et plus par type et motif inconnus, au plus m passages) ; groupe : voir
# .propager_groupe_d12().
.propager_d12 <- function(te, pas, etat = "depart", ante = NA_character_) {
  echecs <- integer(0)
  for (p in pas) {
    if (!is.null(p$etapes)) {
      o <- .propager_groupe_d12(te, p, etat, ante)
      echecs <- union(echecs, o$echecs)
      etat <- o$etat
      ante <- o$ante
    } else {
      for (passage in seq_len(p$repete)) {
        e2 <- character(0)
        a2 <- character(0)
        avant <- length(echecs)
        for (c1 in seq_along(etat)) {
          for (t in seq_along(p$type)) {
            if (is.na(p$type[t])) {
              e2 <- c(e2, etat[c1])
              a2 <- c(a2, ante[c1])
              next
            }
            s <- .pas_d12(te, etat[c1], ante[c1], p$type[t], p$motif[t])
            if (is.null(s)) {
              echecs <- union(echecs, p$ligne[t])
            } else {
              e2 <- c(e2, s[1L])
              a2 <- c(a2, s[2L])
            }
          }
        }
        garde <- !duplicated(paste(e2, a2, sep = "\r"))
        stable <- sum(garde) == length(etat) && length(echecs) == avant
        etat <- e2[garde]
        ante <- a2[garde]
        if (stable || length(etat) == 0L) break
      }
    }
    if (length(etat) == 0L) break
  }
  list(echecs = echecs, fin = length(etat) > 0L, etat = etat, ante = ante)
}

# Groupe d'événements de même date d'effet dont l'un au moins a un type inconnu (#129, décision du
# mainteneur du 25/11/2026, option (a)) : `etapes`, parcourues type par type dans l'ordre des
# types de l'automate (§ 4), et dans chaque type par identifiant croissant : les événements de ce
# type connu (`bit` 0 ; facultatif s'il est non déterminé) et les `j` événements de type inconnu
# (`bit` : leur rang), chacun facultatif à ce type s'il n'est pas déjà placé. La configuration
# porte l'ensemble des événements de type inconnu déjà placés (`masque`, chaîne de j « 0 » ou
# « 1 ») ; ceux qui ne sont pas placés à la fin du groupe sont hors automate. Chaque choix de type
# (« hors automate » compris) est un seul chemin, dans l'ordre (type, identifiant) : exact.
# `intervalle` (date d'effet inconnue, .verdict_d12()) : appliqué au début du groupe, après chaque
# position d'un événement de type connu et après chaque événement de type inconnu placé (mêmes
# intervalles que ceux d'une suite de positions). Coût : (nombre d'étapes, au plus 6 x taille du
# groupe) x (configurations x 2^j) en opérations vectorielles, transitions de .pas_d12() et
# intervalles mis en cache par (état, état antérieur).
.propager_groupe_d12 <- function(te, p, etat, ante) {
  echecs <- integer(0)
  masque <- rep(strrep("0", p$j), length(etat))
  cache_pas <- list()
  cache_int <- list()
  unique3 <- function(e, a, m) {
    garde <- !duplicated(paste(e, a, m, sep = "\r"))
    list(etat = e[garde], ante = a[garde], masque = m[garde])
  }
  intervalle <- function(e, a, m) {
    if (is.null(p$intervalle) || length(e) == 0L) return(unique3(e, a, m))
    cle <- paste(e, a, sep = "\r")
    e2 <- character(0)
    a2 <- character(0)
    m2 <- character(0)
    for (q in which(!duplicated(cle))) {
      if (is.null(cache_int[[cle[q]]])) cache_int[[cle[q]]] <<- .propager_d12(te, list(p$intervalle), e[q], a[q])
      o <- cache_int[[cle[q]]]
      echecs <<- union(echecs, o$echecs)
      sel <- m[cle == cle[q]]
      e2 <- c(e2, rep(o$etat, times = length(sel)))
      a2 <- c(a2, rep(o$ante, times = length(sel)))
      m2 <- c(m2, rep(sel, each = length(o$etat)))
    }
    unique3(e2, a2, m2)
  }
  x <- intervalle(etat, ante, masque)
  for (s in p$etapes) {
    if (length(x$etat) == 0L) break
    libre <- if (s$bit > 0L) substr(x$masque, s$bit, s$bit) == "0" else rep(TRUE, length(x$etat))
    saute <- if (s$facultatif) rep(TRUE, length(x$etat)) else !libre
    z <- which(libre)
    mz <- x$masque[z]
    if (s$bit > 0L) substr(mz, s$bit, s$bit) <- "1"
    cle <- paste(x$etat[z], x$ante[z], sep = "\r")
    e2 <- character(0)
    a2 <- character(0)
    m2 <- character(0)
    for (t in seq_along(s$type)) {
      for (q in which(!duplicated(cle))) {
        k <- paste(cle[q], s$type[t], s$motif[t], sep = "\r")
        if (is.null(cache_pas[[k]])) cache_pas[[k]] <- list(.pas_d12(te, x$etat[z[q]], x$ante[z[q]], s$type[t], s$motif[t]))
        s1 <- cache_pas[[k]][[1L]]
        if (is.null(s1)) {
          echecs <- union(echecs, s$ligne[t])
          next
        }
        sel <- cle == cle[q]
        e2 <- c(e2, rep(s1[1L], sum(sel)))
        a2 <- c(a2, rep(s1[2L], sum(sel)))
        m2 <- c(m2, mz[sel])
      }
    }
    if (s$bit > 0L) {
      pris <- intervalle(e2, a2, m2)
      x <- unique3(c(x$etat[saute], pris$etat), c(x$ante[saute], pris$ante), c(x$masque[saute], pris$masque))
    } else {
      x <- intervalle(c(x$etat[saute], e2), c(x$ante[saute], a2), c(x$masque[saute], m2))
    }
  }
  garde <- !duplicated(paste(x$etat, x$ante, sep = "\r"))
  list(echecs = echecs, etat = x$etat[garde], ante = x$ante[garde])
}

# Verdict de D12 sur les lignes de evenements (.regle_v_suites()) : pour chaque sinistre, la suite
# de ses événements de l'automate retenus et non déterminés est propagée (.propager_d12()) ; un
# événement retenu est vrai s'il est le premier échec de toute suite possible, faux s'il ne l'est
# d'aucune, inconnu sinon (index : événements non déterminés du sinistre, sous « evenements » ;
# événements retenus de date d'effet, de type ou de motif inconnus, sous « evenements.date_effet »,
# « evenements.type_evenement » et « evenements.motif », dont .cause_nd() retient le motif du
# refus ; chaque clé n'existe que si elle a une ligne). Valeur inconnue : refus de valeur
# (.inconnu()), jamais la valeur brute. Transitions par position (C129-5) : un événement retenu,
# la sienne ; un événement non déterminé, facultatif (« sauter » en plus) ; motif inconnu : une
# transition par motif du domaine de son type (types_evenements.csv, colonne motifs) ; type
# inconnu : une transition par type de l'automate, et « sauter » (hors automate) : l'événement
# appartient à la population s'il peut être de l'automate (lecture existentielle). Exact (identique
# à l'énumération des sous-ensembles et des valeurs du domaine) hors date d'effet inconnue : des
# événements de même date d'effet dont l'un a un type inconnu forment un groupe, parcouru type par
# type puis par identifiant, avec l'ensemble des événements de type inconnu déjà placés
# (.propager_groupe_d12() ; « hors automate » : non placé). Élagage exact : les
# événements non déterminés placés, dans l'ordre, après le dernier retenu sont sans effet (sans
# date d'effet ni type inconnus dans le sinistre). Date d'effet inconnue (refus de valeur,
# .inconnu() ; jamais clé de tri ; une date absente non refusée reste une clé, triée en dernier
# par order()) : l'événement est facultatif à chaque intervalle de la suite des dates connues,
# entre les événements d'un groupe compris (une position par intervalle, transitions « sauter » ou
# l'un de ces événements, autant de passages qu'il y en a) : approximation sûre, inconnu au lieu
# de déterminé, jamais l'inverse (M813).
.verdict_d12 <- function(ctx) {
  v <- function(t, c1) .valeurs(ctx, t, c1)
  te <- ctx$dico$types_evenements
  n <- nrow(ctx$base$evenements)
  type <- v("evenements", "type_evenement")
  sin <- .cle_manquante(as.character(v("evenements", "id_sinistre")))
  k <- apparier_cles(sin, v("sinistres", "id_sinistre"))
  arret <- !is.na(k) & v("sinistres", "nature_sinistre")[ifelse(is.na(k), 1L, k)] %in% "arret_travail"
  auto <- te$type_evenement[!is.na(te$etat_depuis) & nzchar(te$etat_depuis)]
  type_inc <- .inconnu(ctx, "evenements", "type_evenement")
  motif_inc <- .inconnu(ctx, "evenements", "motif")
  etat <- arret & (type %in% auto | type_inc)
  ret <- which(ctx$retenu$evenements & etat)
  est_nd <- .nd_vue(ctx, "evenements") & etat
  nd <- which(est_nd)
  effet <- .date_connue(ctx, "evenements", "date_effet")
  inconnue <- .inconnu(ctx, "evenements", "date_effet")
  rang_type <- te$ordre[match(type, te$type_evenement)]
  id <- as.character(v("evenements", "id_evenement"))
  motif <- v("evenements", "motif")
  ordonner <- function(l) l[order(effet[l], rang_type[l], id[l], method = "radix")]
  # motifs possibles de la ligne `l` sous le type `t`
  motifs_de <- function(l, t) {
    if (!motif_inc[l]) return(motif[l])
    m <- eclater_champ(te$motifs[match(t, te$type_evenement)])
    if (length(m) == 0L) NA_character_ else m
  }
  # transitions des lignes `l` (types possibles : `types`, liste par ligne ; NA : « sauter »)
  position <- function(l, saute, repete = 1L, types = lapply(l, function(x) if (type_inc[x]) c(auto, NA) else type[x])) {
    ty <- if (saute) NA_character_ else character(0)
    mo <- ty
    li <- if (saute) NA_integer_ else integer(0)
    for (z in seq_along(l)) {
      for (t in types[[z]]) {
        m <- if (is.na(t)) NA_character_ else motifs_de(l[z], t)
        ty <- c(ty, rep(t, length(m)))
        mo <- c(mo, m)
        li <- c(li, rep(l[z], length(m)))
      }
    }
    list(type = ty, motif = mo, ligne = li, repete = repete)
  }
  # groupe d'une date d'effet à type inconnu (.propager_groupe_d12()) : type par type dans l'ordre
  # de l'automate, puis par identifiant ; un événement de type inconnu est une étape de chaque type
  types_ordre <- auto[order(te$ordre[match(auto, te$type_evenement)], method = "radix")]
  groupe_inconnu <- function(g) {
    u <- g[type_inc[g]]
    etapes <- list()
    for (t in types_ordre) {
      l <- g[type_inc[g] | type[g] %in% t]
      for (x in l[order(id[l], method = "radix")]) {
        e <- position(x, FALSE, types = list(t))
        e$bit <- if (type_inc[x]) match(x, u) else 0L
        e$facultatif <- type_inc[x] || est_nd[x]
        etapes[[length(etapes) + 1L]] <- e
      }
    }
    list(etapes = etapes, j = length(u), intervalle = NULL)
  }
  r <- rep(FALSE, n)
  index <- list(evenements = vector("list", n), evenements.date_effet = vector("list", n),
                evenements.type_evenement = vector("list", n), evenements.motif = vector("list", n))
  # motif lu : type inconnu, ou type dont le domaine des motifs n'est pas vide
  sortie_possible <- type_inc | type %in% te$type_evenement[nzchar(te$motifs) & !is.na(te$motifs)]
  groupes_n <- split(nd, sin[nd])
  for (lr in split(ret, sin[ret])) {
    ln <- groupes_n[[sin[lr[1L]]]]
    ld <- lr[inconnue[lr]]
    lc <- lr[!inconnue[lr]]
    if (length(ln) > 0L && length(ld) == 0L && !any(type_inc[c(lr, ln)])) {
      # élagage exact : un événement non déterminé de date connue placé, dans l'ordre, après le
      # dernier retenu ne change ni l'état qui précède un retenu, ni le rang du premier échec
      # parmi les retenus
      lnc <- ln[!inconnue[ln]]
      tous <- c(lc, lnc)
      rang <- match(tous, ordonner(tous))
      garde <- rep(TRUE, length(ln))
      garde[!inconnue[ln]] <- rang[-seq_along(lc)] < max(rang[seq_along(lc)])
      ln <- ln[garde]
    }
    connus <- ordonner(c(lc, ln[!inconnue[ln]]))
    # groupes de même date d'effet (date absente non refusée : un groupe), dans l'ordre
    e_c <- effet[connus]
    meme <- vapply(seq_len(max(length(connus) - 1L, 0L)), function(z) identical(e_c[z + 1L], e_c[z]), NA)
    groupe <- cumsum(c(TRUE, !meme))[seq_along(connus)]
    pas <- unlist(unname(lapply(split(connus, groupe), function(g) {
      if (length(g) > 1L && any(type_inc[g])) list(groupe_inconnu(g)) else lapply(g, function(l) position(l, est_nd[l]))
    })), recursive = FALSE)
    u <- c(ld, ln[inconnue[ln]])
    if (length(u) > 0L) {
      intervalle <- position(u, TRUE, length(u))
      entre <- function(a) c(list(intervalle), unlist(lapply(a, function(p) list(p, intervalle)), recursive = FALSE))
      # intervalles aussi entre les événements d'un groupe (même date d'effet)
      pas <- lapply(pas, function(p) {
        if (!is.null(p$etapes)) p$intervalle <- intervalle
        p
      })
      pas <- entre(pas)
    }
    o <- .propager_d12(te, pas)
    certain <- !o$fin && length(o$echecs) == 1L
    r[lr] <- ifelse(!(lr %in% o$echecs), FALSE, if (certain) TRUE else NA)
    inc <- lr[is.na(r[lr])]
    if (length(inc) == 0L) next
    elements <- list(evenements = ln, evenements.date_effet = ld, evenements.type_evenement = lr[type_inc[lr]],
                     evenements.motif = lr[motif_inc[lr] & sortie_possible[lr]])
    for (tc in names(elements)) if (length(elements[[tc]]) > 0L) index[[tc]][inc] <- list(elements[[tc]])
  }
  if (anyNA(r)) {
    garde <- names(index) == "evenements" | !vapply(index, function(x) all(vapply(x, is.null, NA)), NA)
    attr(r, "index") <- index[garde]
  }
  r
}

# D14, dossier double effet non ouvert (dictionnaire, § 9 ; spécification `donnees` v1.6, § 8.9),
# sur la vue, constat sur sinistres, colonne NA, traitement H ou S, détection exacte : sinistre
# deces instruit à l'arrêté (date_instruction connue à l'arrêté) tel que (a) une version de la
# garantie double_effet est en vigueur à la survenance pour le (id_contrat, college) d'un dossier
# deces du sinistre (.garantie_en_vigueur3()) ; (b) la famille rattachée au sinistre
# (famille.id_sinistre, versions valables à l'arrêté) compte, pour cette version, un conjoint de
# lien couvert par conjoint_vise (.LIENS_CONJOINT_VISE) non décédé avant la survenance, et un
# enfant à naître ou à charge sous sa limite à la survenance (.enfant_eteint(), règle
# conventions$limite_age, comme D07 (c)), non décédé avant la survenance (enfant né après la
# survenance : à naître, décision du mainteneur du 13/11/2026) ; (c) aucun dossier
# double_effet du sinistre dans la vue. Limite d'âge non déterminable pour un enfant dont elle
# décide : (D14, sinistres, NA) dans controles_non_executes (.CAUSE_PARAMETRE_NON_DEFINI). Enfant
# né sans date de naissance (D03a) : compté possible (décision du mainteneur du 13 novembre
# 2026) ; s'il décide (verdicts différents selon qu'il compte ou non comme sous sa limite), le
# sinistre est écarté de D14 et (D14, sinistres, NA) entre dans controles_non_executes
# (.CAUSE_AGE_NON_DEFINI). Sans conventions$limite_age : ligne candidate, sinistre de la vue
# (retenu ou de visibilité non déterminée) dont le verdict diffère selon que chaque enfant né
# compte comme sous sa limite ou qu'aucun ne compte (réserve R1 d'`actuary`) ; s'il en existe
# une, non exécuté (cause declaration_absente) et déclarations requises de D07 (c) (rubrique
# conventions, clés limite_age$regle et limite_age$age, motif D14) ; sinon D14 s'exécute sans
# convention, aucun enfant né ne comptant (enfants à naître seuls). Aucune candidate sans
# version double_effet dans la vue (retenue ou de visibilité non déterminée) ; colonne
# illisible : prudent, candidate (code de la garantie illisible, ou version double_effet dans la
# vue et autre colonne lue illisible) ; une colonne lue illisible y ajoute sa cause directe
# (.regle_vue(), sans détection), qui l'emporte au départage (rang 3 avant declaration_absente,
# rang 6 ; spécification, § 3.1). Verdict à trois valeurs : dossiers, versions et membres de la
# famille (.famille_en_jeu()) de visibilité non déterminée.
.LIENS_CONJOINT_VISE <- list(marie = "conjoint", marie_pacs = c("conjoint", "partenaire_pacs"),
                             marie_pacs_concubin = c("conjoint", "partenaire_pacs", "concubin"))
.regle_v_double_effet <- function(ctx) {
  la <- ctx$conventions$limite_age
  lit <- c("sinistres.id_sinistre", "sinistres.nature_sinistre", "sinistres.date_survenance", "sinistres.date_instruction",
           "dossiers.id_sinistre", "dossiers.id_garantie_souscrite",
           paste0("garanties_souscrites.", c("id_garantie_souscrite", "code_garantie", "id_contrat", "college", "date_effet",
                                             "date_fin", "conjoint_vise", "prolongation_handicap")),
           "parametres.id_garantie_souscrite", "parametres.parametre", "parametres.valeur",
           paste0("famille.", c("id_sinistre", "lien", "date_naissance", "situation", "date_deces")))
  vue <- c(ctx$lit_vue$dossiers, ctx$lit_vue$garanties_souscrites, ctx$lit_vue$parametres, ctx$lit_vue$famille)
  # Règle V en mode Kleene (#105, lot V, G2b, M810) : verdicts à trois valeurs .verdict_d14_3() ;
  # « illisible » et « sans dossier double_effet » ne lisent que les causes de forme ou de portée
  # table (E-11 ; une valeur refusée est lue de façon existentielle dans les deux verdicts comparés)
  resultat <- function(x) {
    r <- x$v
    ip <- list()
    for (i in which(is.na(r))) ip <- .ip_cellules3(ip, i, x$pert[[i]], length(r))
    attr(r, "index_pertinent") <- ip
    attr(r, "lues") <- lit
    r
  }
  if (is.null(la)) {
    if (NROW(ctx$base$sinistres) == 0L) return(invisible(NULL))
    cles_de <- c("garanties_souscrites.id_garantie_souscrite", "garanties_souscrites.code_garantie")
    sans_de <- is.null(.cause_hors_valeur(ctx, cles_de)) &&
      !any((ctx$retenu$garanties_souscrites | .nd_vue(ctx, "garanties_souscrites")) &
             (.valeurs(ctx, "garanties_souscrites", "code_garantie") %in% "double_effet" |
                .inconnu(ctx, "garanties_souscrites", "code_garantie")))
    if (sans_de) return(invisible(NULL))
    illisible <- !is.null(.cause_hors_valeur(ctx, lit))
    candidat <- illisible || {
      x1 <- .verdict_d14_k(ctx, NULL, TRUE)$v
      x0 <- .verdict_d14_k(ctx, NULL, FALSE)$v
      any((ctx$retenu$sinistres | .nd_vue(ctx, "sinistres")) & !.egal3(x1, x0))
    }
    if (!candidat) {
      .regle_vue(ctx, "D14", "sinistres", NA_character_, lit, "H;S", "exacte", function() {
        resultat(.verdict_d14_k(ctx, NULL, FALSE))
      }, vue = vue, mode = "kleene")
      return(invisible(NULL))
    }
    if (illisible) {
      .regle_vue(ctx, "D14", "sinistres", NA_character_, lit, "H;S", "exacte", function() {
        stop("erreur interne de provie : D14 ex\u00e9cut\u00e9 sans conventions$limite_age", call. = FALSE)
      }, vue = vue, mode = "kleene")
    }
    .ajouter_non_execute(ctx, "D14", "sinistres", NA_character_, "declaration_absente")
    .requerir(ctx, "conventions", "D14", "limite_age$regle", paste(REGLES_LIMITE_AGE, collapse = ";"))
    .requerir(ctx, "conventions", "D14", "limite_age$age", paste(CONVENTIONS_LIMITE_AGE, collapse = ";"))
    return(invisible(NULL))
  }
  .regle_vue(ctx, "D14", "sinistres", NA_character_, lit, "H;S", "exacte", function() {
    x1 <- .verdict_d14_k(ctx, la, TRUE)
    x0 <- .verdict_d14_k(ctx, la, FALSE)
    # verdict commun (disjonction de Kleene, cellules pertinentes réunies sur les verdicts
    # inconnus) ; enfant sans date de naissance qui décide : sinistre écarté du constat, sous-cas âge
    # non défini (Q1 d'`actuary` : sémantique de la règle bloquée)
    x <- list(v = ifelse(x1$v %in% TRUE | x0$v %in% TRUE, TRUE, ifelse(is.na(x1$v) | is.na(x0$v), NA, FALSE)),
              pert = Map(function(p1, p0, v1, v0) unique(c(if (is.na(v1)) p1, if (is.na(v0)) p0)), x1$pert, x0$pert, x1$v, x0$v))
    age <- ctx$retenu$sinistres & !.egal3(x1$v, x0$v)
    if (any(age)) {
      x$v[age] <- FALSE
      .ajouter_non_execute(ctx, "D14", "sinistres", NA_character_, .CAUSE_AGE_NON_DEFINI)
    }
    if (x1$non_defini || x0$non_defini) .ajouter_non_execute(ctx, "D14", "sinistres", NA_character_, .CAUSE_PARAMETRE_NON_DEFINI)
    resultat(x)
  }, vue = vue, mode = "kleene")
  invisible(NULL)
}

# Verdict de D14 sur les lignes de sinistres (.regle_v_double_effet()) : verdict à trois valeurs
# (.k3()) et `non_defini` (limite non déterminable qui peut décider, sur un sinistre retenu). `la`
# NULL : limite non lue, chaque enfant né (lien enfant, hors a_naitre) compte comme sous sa limite
# (`ne` TRUE) ou aucun (`ne` FALSE) ; `la` lue : `ne` est la valeur donnée à un enfant né sans date
# de naissance (hors prolongation pour handicap), dont l'âge n'est pas défini. Lecture brute,
# chemin rapide de la règle V en mode Kleene (#105, lot V, G2b) : exacte sur les sinistres qui ne
# lisent aucune cellule inconnue ni ligne de visibilité non déterminée (`simples`, qui borne aussi
# `non_defini`) ; les autres relèvent de .verdict_d14_3().
.verdict_d14 <- function(ctx, la, ne, simples = rep(TRUE, NROW(ctx$base$sinistres))) {
  v <- function(t, c1) .valeurs(ctx, t, c1)
  a <- as.numeric(ctx$arrete)
  ns <- nrow(ctx$base$sinistres)
  id_s <- as.character(v("sinistres", "id_sinistre"))
  surv_d <- v("sinistres", "date_survenance")
  surv <- as.numeric(surv_d)
  instruit <- as.numeric(v("sinistres", "date_instruction")) <= a
  base_ok <- v("sinistres", "nature_sinistre") %in% "deces" & !is.na(surv) & instruit %in% TRUE
  joindre_gs <- function(c1, gs) .joindre(ctx, "garanties_souscrites", "id_garantie_souscrite", c1, gs)
  gs_d <- v("dossiers", "id_garantie_souscrite")
  code_d <- joindre_gs("code_garantie", gs_d)
  # (c) dossier double_effet du sinistre dans la vue
  de3 <- .k3_entree(.existe_vue3(ctx, "dossiers", id_s, v("dossiers", "id_sinistre"), code_d %in% "double_effet"))
  # (a) paires (sinistre, dossier deces retenu ou non déterminé), versions double_effet en vigueur
  nd_d <- .nd_vue(ctx, "dossiers")
  p <- .paires(ifelse(base_ok, id_s, NA),
               ifelse((ctx$retenu$dossiers | nd_d) & code_d %in% "deces", as.character(v("dossiers", "id_sinistre")), NA))
  cle_d <- list(contrat = joindre_gs("id_contrat", gs_d)[p$j], college = joindre_gs("college", gs_d)[p$j])
  g <- .gev_brut(ctx, "double_effet", cle_d, surv[p$i], rep(TRUE, nrow(p)), TRUE)
  nv <- lengths(g$versions)
  nn <- lengths(g$versions_nd)
  tri <- data.frame(q = c(rep(seq_len(nrow(p)), nv), rep(seq_len(nrow(p)), nn)),
                    w = c(unlist(g$versions), unlist(g$versions_nd)), w_nd = rep(c(FALSE, TRUE), c(sum(nv), sum(nn))))
  tri$i <- p$i[tri$q]
  tri$d_nd <- !ctx$retenu$dossiers[p$j[tri$q]]
  nt <- nrow(tri)
  # (b) membres de la famille rattachée au sinistre : versions retenues ou en jeu
  fam_r <- ctx$retenu$famille
  fam_j <- .famille_en_jeu(ctx)
  fl <- .paires(id_s[tri$i], ifelse(fam_r | fam_j, as.character(v("famille", "id_sinistre")), NA))
  l <- fl$j
  t_l <- fl$i
  s_l <- surv[tri$i[t_l]]
  vivant <- is.na(v("famille", "date_deces")[l]) | as.numeric(v("famille", "date_deces")[l]) >= s_l
  lien <- v("famille", "lien")[l]
  vise <- .LIENS_CONJOINT_VISE[as.character(joindre_gs("conjoint_vise", as.character(v("garanties_souscrites",
                                                                                         "id_garantie_souscrite"))[tri$w[t_l]]))]
  conj <- vivant & vapply(seq_along(lien), function(k) lien[k] %in% vise[[k]], NA)
  enfant <- vivant & lien %in% "enfant"
  # enfant posthume (né après la survenance) : à naître à la survenance, quelle que soit sa
  # situation, sans borne de délai (décision du mainteneur du 13/11/2026 ; D07 (c) inchangé)
  posthume <- (as.numeric(v("famille", "date_naissance")[l]) > s_l) %in% TRUE
  a_naitre <- enfant & (v("famille", "situation")[l] %in% "a_naitre" | posthume)
  ne_l <- enfant & !a_naitre
  enf <- as.logical(a_naitre)
  non_defini <- rep(FALSE, length(l))
  if (is.null(la)) {
    enf[ne_l] <- ne
  } else if (any(ne_l)) {
    gs_w <- as.character(v("garanties_souscrites", "id_garantie_souscrite"))[tri$w[t_l[ne_l]]]
    x <- .enfant_eteint(ctx, la, l[ne_l], gs_w, structure(s_l[ne_l], class = "Date"), v)
    # enfant sans date de naissance (D03a), hors prolongation pour handicap : `ne`
    sans_date <- is.na(v("famille", "date_naissance")[l[ne_l]]) & !x$sous
    enf[ne_l] <- x$sous | (sans_date & ne)
    non_defini[ne_l] <- x$non_defini
  }
  sur <- fam_r[l]
  # existence par triplet (sinistre, dossier, version) : vraie par une version retenue du membre,
  # inconnue par une version en jeu (index : ces versions), fausse sinon
  existe <- function(x) {
    vrai <- tabulate(t_l[sur & x %in% TRUE], nt) > 0L
    possible <- tabulate(t_l[is.na(x) | (!sur & x %in% TRUE)], nt) > 0L
    r <- .k3(ifelse(vrai, TRUE, ifelse(possible, NA, FALSE)))
    q <- which(!sur & x %in% TRUE & !vrai[t_l])
    if (length(q) > 0L) {
      r$index$famille <- vector("list", nt)
      for (z in split(q, t_l[q])) r$index$famille[t_l[z[1L]]] <- list(unique(l[z]))
    }
    r
  }
  atome <- .k3_op(`&`, existe(conj), existe(enf))
  # version ou dossier non déterminés : un atome vrai devient inconnu
  nd_t <- which((tri$w_nd | tri$d_nd) & atome$v %in% TRUE)
  atome$v[nd_t] <- NA
  for (z in nd_t) {
    if (tri$w_nd[z]) atome <- .k3_index(atome, "garanties_souscrites", z, tri$w[z], nt)
    if (tri$d_nd[z]) atome <- .k3_index(atome, "dossiers", z, p$j[tri$q[z]], nt)
  }
  r <- .k3_op(`&`, .k3(base_ok), .k3_par(tri$i, atome, ns, "un"), .k3(!de3$v, de3$index))
  # limite non déterminable qui peut décider : sinistre retenu non détecté, sans dossier
  # double_effet visible, triplet au conjoint possible et sans enfant sous sa limite déterminé
  peut <- ctx$retenu$sinistres[tri$i] & simples[tri$i] & !(r$v[tri$i] %in% TRUE) & !(de3$v[tri$i] %in% TRUE) &
    !(existe(conj)$v %in% FALSE) & !(existe(enf)$v %in% TRUE)
  r$non_defini <- any(peut[t_l] & non_defini)
  r
}

# Verdict à trois valeurs de D14 (#105, lot V, G2b, M810 ; spécification `donnees` v1.6, § 8.9 ;
# erratum `1.9.7`, E-1, E-7, E-9, E-11 ; D-G2-2) : même formule que la règle bloquée, en arbre par
# sinistre retenu qui peut être un décès instruit (.arbre3()) : nature `deces`, survenance,
# instruction au plus l'arrêté ET OU, sur les triplets (sinistre, dossier `deces` du sinistre dans
# la vue, version double_effet en vigueur à la survenance de même contrat et collège que la
# garantie du dossier, .garantie_en_vigueur3() à trois valeurs), de « dossier présent, de code
# `deces` ET version ET conjoint visé vivant à la survenance ET enfant compté » ET NON « dossier
# double_effet du sinistre dans la vue ». Conjoint visé : membre de la famille du sinistre (version
# retenue, ou en jeu : présence, .famille_en_jeu()), non décédé avant la survenance, de lien dans les
# qualités de conjoint_vise de la version. Enfant compté : lien enfant, vivant, à naître ou posthume
# (naissance après la survenance), ou né et, sous `la`, sous sa limite d'âge à la survenance
# (handicap sous prolongation_handicap, ou âge calculer_age() sous age_limite, age_limite_etudes
# pour un enfant scolarise ou apprenti, plus 1 sous `depassement` ; paramètre de la vue, valeur
# refusée : cellule inconnue, plusieurs valeurs : limite non déterminable), sans `la` : `ne` ; un
# enfant sans date de naissance (D03a, hors handicap) compte comme `ne` (Q1 d'`actuary` : sémantique
# de la règle bloquée gardée ; la comparaison des deux valeurs de `ne` reste à l'appelant).
# Inconnues : nature, survenance, instruction, présences et codes des dossiers, cellules des
# versions (.versions3()), conjoint_vise et prolongation_handicap de la version, valeurs de ses
# paramètres, présence, lien, naissance, situation et décès des membres. Représentants : dates aux
# points de rupture relatifs aux dates comparées (survenance : bornes de la version, décès,
# naissance, anniversaires où l'âge atteint la limite, .points_age3()), limite inconnue aux âges
# atteignables et leur successeur. Rend, par sinistre, `v` (NA : inconnu), `pert` (identifiants
# pertinents d'un sinistre inconnu), `cellules` (le sinistre lit une cellule inconnue) et
# `non_defini` : limite non déterminable qui peut décider, sur un sinistre retenu ou de visibilité
# non déterminée (même formule que la règle bloquée, lue de façon existentielle, approximation par
# excès : E-12 (d) de la spécification `donnees`, § 9.2).
.verdict_d14_3 <- function(ctx, la, ne, complexes = rep(TRUE, NROW(ctx$base$sinistres))) {
  v <- function(t, c1) .valeurs(ctx, t, c1)
  gs <- "garanties_souscrites"
  a0 <- as.numeric(ctx$arrete)
  ns <- NROW(ctx$base$sinistres)
  cel <- function(t, c1, l) {
    u <- .inconnu(ctx, t, c1)
    ifelse(!is.na(l) & u[ifelse(is.na(l), 1L, l)], paste0(t, ".", c1, "\r", l), NA_character_)
  }
  pres_f <- function(p_id) .feuille3(p_id, function(sigs) stats::setNames(list(c(TRUE, FALSE)), p_id), function(a, n) a[[p_id]])
  feuille_enum <- function(id, x, dom, test) .feuille3(id, function(sigs) stats::setNames(list(dom), id),
                                                        function(a, n) test(.val3(a, id, x, n)))
  plage <- function(t, c1) .plage_date3(ctx, t, c1)
  sl <- seq_len(ns)
  nature <- v("sinistres", "nature_sinistre")
  nat_id <- cel("sinistres", "nature_sinistre", sl)
  surv <- as.numeric(v("sinistres", "date_survenance"))
  s_id <- cel("sinistres", "date_survenance", sl)
  instr <- as.numeric(v("sinistres", "date_instruction"))
  in_id <- cel("sinistres", "date_instruction", sl)
  plage_s <- plage("sinistres", "date_survenance")
  abs_s <- !.obligatoire3(ctx, "sinistres", "date_survenance")
  base_possible <- complexes & (ctx$retenu$sinistres | .nd_vue(ctx, "sinistres")) & (!is.na(nat_id) | nature %in% "deces") & (!is.na(s_id) | !is.na(surv)) &
    (!is.na(in_id) | (instr <= a0) %in% TRUE)
  id_s <- .cle_manquante(as.character(v("sinistres", "id_sinistre")))
  # dossiers du sinistre dans la vue, code de leur garantie
  nd_d <- .nd_vue(ctx, "dossiers") & !ctx$retenu$dossiers
  dans_d <- ctx$retenu$dossiers | nd_d
  sin_d <- .cle_manquante(as.character(v("dossiers", "id_sinistre")))
  ig <- .index_jointure(ctx, gs, "id_garantie_souscrite", v("dossiers", "id_garantie_souscrite"))
  code_d <- v(gs, "code_garantie")[ig]
  code_d_id <- cel(gs, "code_garantie", ig)
  dom_code <- .domaine3(ctx, gs, "code_garantie")
  terme_dossier <- function(d, code) {
    fc <- feuille_enum(code_d_id[d], code_d[d], dom_code, function(x) x %in% code)
    if (nd_d[d]) .noeud3("et", list(pres_f(paste0("dossiers\r", d)), fc)) else fc
  }
  p <- .paires(ifelse(base_possible, id_s, NA), ifelse(dans_d & (!is.na(code_d_id) | code_d %in% "deces"), sin_d, NA))
  igp <- ig[p$j]
  g <- .garantie_en_vigueur3(ctx, "double_effet", list(contrat = v(gs, "id_contrat")[igp], college = v(gs, "college")[igp]),
                             surv[p$i], inconnues = list(survenance = s_id[p$i], college = cel(gs, "college", igp)))
  # membres de la famille du sinistre : versions retenues ou en jeu
  fam_r <- ctx$retenu$famille
  fam_j <- .famille_en_jeu(ctx)
  sin_f <- .cle_manquante(as.character(v("famille", "id_sinistre")))
  nf <- NROW(ctx$base$famille)
  lf <- seq_len(nf)
  lien <- v("famille", "lien")
  lien_id <- cel("famille", "lien", lf)
  naiss <- as.numeric(v("famille", "date_naissance"))
  naiss_id <- cel("famille", "date_naissance", lf)
  sit <- v("famille", "situation")
  sit_id <- cel("famille", "situation", lf)
  dd <- as.numeric(v("famille", "date_deces"))
  dd_id <- cel("famille", "date_deces", lf)
  plage_n <- plage("famille", "date_naissance")
  abs_n <- !.obligatoire3(ctx, "famille", "date_naissance")
  plage_dd <- plage("famille", "date_deces")
  dom_lien <- .domaine3(ctx, "famille", "lien")
  dom_sit <- .domaine3(ctx, "famille", "situation")
  # version : conjoint visé, prolongation, paramètres de limite (lignes retenues de la vue)
  gs_id <- as.character(v(gs, "id_garantie_souscrite"))
  cv <- v(gs, "conjoint_vise")
  ph <- v(gs, "prolongation_handicap")
  dom_cv <- .domaine3(ctx, gs, "conjoint_vise")
  dom_ph <- .domaine3(ctx, gs, "prolongation_handicap")
  nom_par <- .valeurs_vue(ctx, "parametres", "parametre")
  gs_par <- .valeurs(ctx, "parametres", "id_garantie_souscrite")
  val_par <- as.numeric(.valeurs(ctx, "parametres", "valeur"))
  par_u <- .inconnu(ctx, "parametres", "valeur")
  lignes_par <- function(w, nom) which(nom_par %in% nom & cle_renseignee(gs_par) & gs_par %in% gs_id[w])
  dep <- if (!is.null(la) && la$regle == "depassement") 1 else 0
  en_date <- function(x) structure(as.numeric(x), class = "Date")
  age_de <- function(b, s) calculer_age(en_date(b), en_date(s), la$age)
  # valeur d'un paramètre sur n affectations : unique valeur (NA sinon), plusieurs valeurs
  valeur_par <- function(a, ks, n) {
    if (length(ks) == 0L) return(list(val = rep(NA_real_, n), ambigu = rep(FALSE, n)))
    m <- vapply(ks, function(k) .val3(a, if (par_u[k]) paste0("parametres.valeur\r", k) else NA_character_, val_par[k], n), numeric(n))
    m <- matrix(m, nrow = n)
    egal <- rowSums(m == m[, 1L]) == ncol(m)
    egal[is.na(egal)] <- FALSE
    list(val = ifelse(egal, m[, 1L], NA_real_), ambigu = !egal)
  }
  enfant_feuille <- function(i, l, w) {
    ids <- c(s = s_id[i], p = if (!fam_r[l]) paste0("famille\r", l) else NA_character_, lien = lien_id[l], n = naiss_id[l],
             sit = sit_id[l], dd = dd_id[l], ph = cel(gs, "prolongation_handicap", w))
    # paramètres de limite lus sous `la` seulement (sans convention, l'enfant né compte comme `ne`)
    k1 <- if (is.null(la)) integer(0) else lignes_par(w, "age_limite")
    k2 <- if (is.null(la)) integer(0) else lignes_par(w, "age_limite_etudes")
    kp <- c(k1, k2)
    ids_par <- ifelse(par_u[kp], paste0("parametres.valeur\r", kp), NA_character_)
    limites_connues <- function() unique(c(val_par[kp][!par_u[kp]])) + dep
    dom <- function(sigs) {
      fx <- function(k, x, pl) if (is.na(ids[[k]])) x else { y <- .fixees3(sigs, ids[[k]], numeric(0)); if (length(y)) y else pl }
      sv <- fx("s", surv[i], plage_s)
      nv <- fx("n", naiss[l], plage_n)
      lims <- limites_connues()
      lims_inc <- unlist(lapply(ids_par[!is.na(ids_par)], function(z) .fixees3(sigs, z, numeric(0))), use.names = FALSE)
      if (any(!is.na(ids_par)) && length(lims_inc) == 0L) lims_inc <- NULL
      lims <- unique(c(lims, lims_inc + dep))
      out <- list()
      if (!is.na(ids[["s"]])) {
        pts <- c(nv, fx("dd", dd[l], plage_dd))
        if (!is.null(la)) for (L in lims[!is.na(lims)]) pts <- c(pts, .points_age3(la$age, L, L, plage_s, nv, ref = TRUE))
        out[[ids[["s"]]]] <- .reps_date3(plage_s, abs_s, pts)
      }
      if (!is.na(ids[["n"]])) {
        pts <- sv
        if (!is.null(la)) for (L in lims[!is.na(lims)]) pts <- c(pts, .points_age3(la$age, L, L, plage_n, sv))
        out[[ids[["n"]]]] <- .reps_date3(plage_n, abs_n, pts)
      }
      if (!is.na(ids[["dd"]])) out[[ids[["dd"]]]] <- .reps_date3(plage_dd, TRUE, sv)
      if (!is.na(ids[["p"]])) out[[ids[["p"]]]] <- c(TRUE, FALSE)
      if (!is.na(ids[["lien"]])) out[[ids[["lien"]]]] <- dom_lien
      if (!is.na(ids[["sit"]])) out[[ids[["sit"]]]] <- dom_sit
      if (!is.na(ids[["ph"]])) out[[ids[["ph"]]]] <- dom_ph
      # limite inconnue : âges atteignables (bornes des dates possibles), leur successeur
      if (any(!is.na(ids_par)) && !is.null(la)) {
        ages <- age_de(rep(range(nv), each = 2L), rep(range(sv), 2L))
        ages <- ages[!is.na(ages)]
        r <- if (length(ages) > 0L) seq(min(ages), max(ages) + 1L) else 0
        reps <- unique(c(val_par[kp][!par_u[kp]], r - dep))
        for (z in ids_par[!is.na(ids_par)]) out[[z]] <- reps
      }
      out
    }
    f <- function(a, n) {
      s <- .val3(a, ids[["s"]], surv[i], n)
      b <- .val3(a, ids[["n"]], naiss[l], n)
      st <- .val3(a, ids[["sit"]], sit[l], n)
      d1 <- .val3(a, ids[["dd"]], dd[l], n)
      vivant <- is.na(d1) | d1 >= s
      r <- vivant & .val3(a, ids[["lien"]], lien[l], n) %in% "enfant"
      a_naitre <- st %in% "a_naitre" | (b > s) %in% TRUE
      compte <- if (is.null(la)) rep_len(ne, n) else {
        handicap <- .val3(a, ids[["ph"]], ph[w], n) %in% TRUE & st %in% "handicape"
        l1 <- valeur_par(a, k1, n)
        l2 <- valeur_par(a, k2, n)
        etudes <- st %in% c("scolarise", "apprenti")
        limite <- ifelse(etudes & !is.na(l2$val), l2$val, l1$val)
        limite[etudes & l2$ambigu] <- NA_real_
        limite <- limite + dep
        age <- age_de(b, s)
        sous <- handicap | (!is.na(age) & !handicap & !is.na(limite) & age < limite)
        sous | (is.na(b) & !sous & ne)
      }
      r <- r & (a_naitre | compte)
      if (!is.na(ids[["p"]])) r <- r & a[[ids[["p"]]]]
      r %in% TRUE
    }
    .feuille3(c(ids, ids_par), dom, f)
  }
  conjoint_feuille <- function(i, l, w) {
    ids <- c(s = s_id[i], p = if (!fam_r[l]) paste0("famille\r", l) else NA_character_, lien = lien_id[l], dd = dd_id[l],
             cv = cel(gs, "conjoint_vise", w))
    dom <- function(sigs) {
      out <- list()
      if (!is.na(ids[["s"]])) {
        ddv <- if (is.na(ids[["dd"]])) dd[l] else { y <- .fixees3(sigs, ids[["dd"]], numeric(0)); if (length(y)) y else plage_dd }
        out[[ids[["s"]]]] <- .reps_date3(plage_s, abs_s, ddv)
      }
      if (!is.na(ids[["dd"]])) {
        sv <- if (is.na(ids[["s"]])) surv[i] else { y <- .fixees3(sigs, ids[["s"]], numeric(0)); if (length(y)) y else plage_s }
        out[[ids[["dd"]]]] <- .reps_date3(plage_dd, TRUE, sv)
      }
      if (!is.na(ids[["p"]])) out[[ids[["p"]]]] <- c(TRUE, FALSE)
      if (!is.na(ids[["lien"]])) out[[ids[["lien"]]]] <- dom_lien
      if (!is.na(ids[["cv"]])) out[[ids[["cv"]]]] <- dom_cv
      out
    }
    f <- function(a, n) {
      s <- .val3(a, ids[["s"]], surv[i], n)
      d1 <- .val3(a, ids[["dd"]], dd[l], n)
      li <- .val3(a, ids[["lien"]], lien[l], n)
      vise <- .LIENS_CONJOINT_VISE[as.character(.val3(a, ids[["cv"]], cv[w], n))]
      r <- (is.na(d1) | d1 >= s) & vapply(seq_len(n), function(k) li[k] %in% vise[[k]], NA)
      if (!is.na(ids[["p"]])) r <- r & a[[ids[["p"]]]]
      r %in% TRUE
    }
    .feuille3(ids, dom, f)
  }
  base_feuille <- function(i) {
    ids <- c(nat = nat_id[i], s = s_id[i], ins = in_id[i])
    dom <- function(sigs) {
      out <- list()
      if (!is.na(ids[["nat"]])) out[[ids[["nat"]]]] <- .domaine3(ctx, "sinistres", "nature_sinistre")
      if (!is.na(ids[["s"]])) out[[ids[["s"]]]] <- .reps_date3(plage_s, abs_s)
      if (!is.na(ids[["ins"]])) out[[ids[["ins"]]]] <- .reps_date3(plage("sinistres", "date_instruction"),
                                                                    !.obligatoire3(ctx, "sinistres", "date_instruction"), a0)
      out
    }
    f <- function(a, n) {
      .val3(a, ids[["nat"]], nature[i], n) %in% "deces" & !is.na(.val3(a, ids[["s"]], surv[i], n)) &
        (.val3(a, ids[["ins"]], instr[i], n) <= a0) %in% TRUE
    }
    .feuille3(ids, dom, f)
  }
  par_i <- split(seq_len(nrow(p)), factor(p$i, levels = sl))
  res_v <- rep(FALSE, ns)
  pert <- vector("list", ns)
  cellules <- rep(FALSE, ns)
  non_defini <- FALSE
  for (i in which(base_possible)) {
    membres <- which((fam_r | fam_j) & !is.na(sin_f) & sin_f %in% id_s[i])
    triplets <- list()
    sous_arbres <- list()
    for (q in par_i[[i]]) {
      d <- p$j[q]
      for (w in g$candidates[[q]]) {
        conj <- if (length(membres) > 0L) .noeud3("ou", lapply(membres, function(l) conjoint_feuille(i, l, w))) else .constante3(FALSE)
        enf <- if (length(membres) > 0L) .noeud3("ou", lapply(membres, function(l) enfant_feuille(i, l, w))) else .constante3(FALSE)
        triplets[[length(triplets) + 1L]] <- .noeud3("et", list(terme_dossier(d, "deces"), g$feuille(q, w), conj, enf))
        sous_arbres[[length(sous_arbres) + 1L]] <- list(conj = conj, enf = enf, w = w,
                                                        dv = .noeud3("et", list(terme_dossier(d, "deces"), g$feuille(q, w))))
      }
    }
    autres <- which(dans_d & !is.na(sin_d) & sin_d %in% id_s[i])
    de3 <- if (length(autres) > 0L) .noeud3("ou", lapply(autres, terme_dossier, "double_effet")) else .constante3(FALSE)
    arbre <- .noeud3("et", list(base_feuille(i), if (length(triplets) > 0L) .noeud3("ou", triplets) else .constante3(FALSE),
                                .noeud3("non", list(de3))))
    ordre <- c("sinistres.date_survenance", "parametres.valeur")
    x <- .arbre3(arbre, ordre)
    res_v[i] <- x$v
    pert[[i]] <- x$pert
    tous <- .cellules3(arbre)
    cellules[i] <- length(tous) > 0L
    # limite non déterminable qui peut décider (même formule que la règle bloquée, lue de façon
    # existentielle : #105, lot V, G2b, réserve Q5 d'`actuary`, E-12 (d)) : sinistre retenu ou de
    # visibilité non déterminée, non détecté de façon certaine, sans dossier double_effet certain,
    # dossier deces et version possiblement en vigueur, triplet au conjoint possible et sans enfant
    # compté certain, et un membre qui peut être un enfant né (lien possible, pas certainement à
    # naître ni posthume, pas certainement décédé avant la survenance, naissance non manquante) dont
    # le handicap n'est pas certain et dont la limite peut être non déterminable (paramètre absent,
    # ou à plusieurs valeurs possibles)
    if (!is.null(la) && (ctx$retenu$sinistres[i] || .nd_vue(ctx, "sinistres")[i]) && !(x$v %in% TRUE) &&
        !(.arbre3(de3, ordre)$v %in% TRUE)) {
      for (z in sous_arbres) {
        if (non_defini) break
        # dossier deces et version possiblement en vigueur à la survenance (E-12 (d))
        if (.arbre3(z$dv, ordre)$v %in% FALSE) next
        if (.arbre3(z$conj, ordre)$v %in% FALSE || .arbre3(z$enf, ordre)$v %in% TRUE) next
        w <- z$w
        for (l in membres) {
          s_connue <- is.na(s_id[i])
          if (is.na(lien_id[l]) && !(lien[l] %in% "enfant")) next
          if (is.na(sit_id[l]) && sit[l] %in% "a_naitre") next
          if (is.na(naiss_id[l]) && is.na(naiss[l])) next
          if (s_connue && is.na(naiss_id[l]) && naiss[l] > surv[i]) next
          if (s_connue && is.na(dd_id[l]) && !is.na(dd[l]) && dd[l] < surv[i]) next
          sits <- if (is.na(sit_id[l])) sit[l] else dom_sit
          ph_w <- if (is.na(cel(gs, "prolongation_handicap", w))) ph[w] else NA
          if (ph_w %in% TRUE && identical(unique(sits %in% "handicape"), TRUE)) next
          if (any(vapply(sits, function(st) .limite_nd_possible3(lignes_par(w, "age_limite"), lignes_par(w, "age_limite_etudes"),
                                                                 val_par, par_u, st), NA))) {
            non_defini <- TRUE
            break
          }
        }
      }
    }
  }
  list(v = res_v, pert = pert, cellules = cellules, non_defini = non_defini)
}

# Limite d'âge possiblement non déterminable (.verdict_d14_3(), `parametre_non_defini` lu de façon
# existentielle) pour une situation `st` : lignes `k1` (age_limite) et `k2` (age_limite_etudes) de
# parametres, valeurs `val`, inconnues `u` (valeur refusée : définie mais inconnue). Un paramètre
# est possiblement non déterminé s'il est absent ou s'il peut prendre plusieurs valeurs (deux lignes
# au moins, dont une inconnue ou de valeurs distinctes) ; même règle que .enfant_eteint().
.limite_nd_possible3 <- function(k1, k2, val, u, st) {
  ambigu <- function(k) length(k) >= 2L && (any(u[k]) || length(unique(val[k])) > 1L)
  nd <- function(k) length(k) == 0L || ambigu(k)
  if (st %in% c("scolarise", "apprenti")) ambigu(k2) || (nd(k2) && nd(k1)) else nd(k1)
}

# Verdict de D14 en mode Kleene (#105, lot V, G2b) : lecture brute (.verdict_d14()) sur les
# sinistres qui ne lisent aucune cellule inconnue ni ligne de visibilité non déterminée (nature,
# survenance, instruction ; dossiers du sinistre dans la vue, code et collège de leur garantie,
# versions de leur contrat, .inconnues_versions3() ; membres de la famille du sinistre, retenus ou en
# jeu) ; .verdict_d14_3() sur les autres. Rend `v`, `pert` et `non_defini` (réunion des deux).
# `forcer` : comme .verdict_d10c().
.verdict_d14_k <- function(ctx, la, ne, forcer = FALSE) {
  gs <- "garanties_souscrites"
  ns <- NROW(ctx$base$sinistres)
  u <- function(t, c1) .inconnu(ctx, t, c1)
  inc_v <- .inconnues_versions3(ctx)
  nd_d <- .nd_vue(ctx, "dossiers")
  ig <- .index_jointure(ctx, gs, "id_garantie_souscrite", .valeurs(ctx, "dossiers", "id_garantie_souscrite"))
  ig1 <- ifelse(is.na(ig), 1L, ig)
  d_inc <- (ctx$retenu$dossiers | nd_d) &
    (nd_d | (!is.na(ig) & (u(gs, "code_garantie")[ig1] | u(gs, "college")[ig1])) |
       .cle_manquante(as.character(.valeurs(ctx, gs, "id_contrat")[ig])) %in% inc_v$contrats)
  sin_inc <- .cle_manquante(as.character(.valeurs(ctx, "dossiers", "id_sinistre")))[d_inc]
  fam <- ctx$retenu$famille | .famille_en_jeu(ctx)
  f_inc <- fam & (!ctx$retenu$famille | u("famille", "lien") | u("famille", "date_naissance") | u("famille", "situation") |
                    u("famille", "date_deces"))
  sin_inc <- c(sin_inc, .cle_manquante(as.character(.valeurs(ctx, "famille", "id_sinistre")))[f_inc])
  id_s <- .cle_manquante(as.character(.valeurs(ctx, "sinistres", "id_sinistre")))
  complexes <- forcer | u("sinistres", "nature_sinistre") | u("sinistres", "date_survenance") | u("sinistres", "date_instruction") |
    (!is.na(id_s) & id_s %in% sin_inc[!is.na(sin_inc)])
  complexes <- rep_len(complexes, ns)
  b <- .verdict_d14(ctx, la, ne, !complexes)
  # garde du chemin rapide : hors des lignes complexes, la lecture brute est déterminée
  if (any((ctx$retenu$sinistres | .nd_vue(ctx, "sinistres")) & !complexes & is.na(b$v))) {
    stop("erreur interne de provie : D14 : lecture brute ind\u00e9termin\u00e9e hors du chemin \u00e0 trois valeurs", call. = FALSE)
  }
  x <- .verdict_d14_3(ctx, la, ne, complexes)
  v <- b$v
  v[complexes] <- x$v[complexes]
  list(v = v, pert = x$pert, non_defini = b$non_defini || x$non_defini)
}

# Égalité terme à terme de deux verdicts à trois valeurs (NA égal à NA).
.egal3 <- function(x, y) (is.na(x) & is.na(y)) | (x %in% TRUE & y %in% TRUE) | (x %in% FALSE & y %in% FALSE)

# --- Placement des constats et enjeu -----------------------------------------------------

# Visibilité d'une ligne à l'arrêté, pour les comptes du bilan (nombre_visibles d'un refus,
# lignes traitées X d'une orpheline, nombre_dossiers, enjeu ; réserves Q8 (a) d'`actuary` et
# M2 de l'audit), en trois valeurs : TRUE si la ligne est visible, FALSE si elle est invisible
# de façon déterminée, NA si sa visibilité n'est pas déterminée. Lue sur l'évaluation unique
# de la visibilité (.visibilite_a(), spécification v1.5, § 2.2 (c) et § 4.2), celle de la vue :
# mode "comptes" (écart (ii) : une ligne que l'exclusion déclarée de D03g sort de la vue a la
# visibilité de l'hypothèse avec un délai nul), ou `d03g` (écart (iii) : variante lue par
# l'enjeu des écarts de D03g seulement, réserve Q8). Seule la version valable de famille est
# comptée (une version remplacée, ou plus ancienne que la version valable déterminée, est
# invisible ; une candidate d'un membre à version valable non déterminée est non déterminée),
# y compris à l'arrêté égal à l'extraction, où tout le reste est visible (règle 3 du § 6 ;
# point P5).
.connus <- function(ctx, table, d03g = FALSE) {
  df <- ctx$base[[table]]
  n <- if (is.null(df)) 0L else nrow(df)
  if (.vue_totale(ctx) && table != "famille") return(rep(TRUE, n))
  ev <- .visibilite_a(ctx, if (d03g) "d03g" else "comptes")
  x <- if (table == "famille") ev$valable else ev$statut[[table]]
  if (is.null(x)) rep(NA, n) else x
}

# Évaluation unique de la visibilité à l'arrêté (spécification v1.5, § 2.2 (c) ; M216 ; M167 et
# M171 rouvertes ; principe de M187), en logique de Kleene : chaque ligne, et chaque partie de
# ligne, est visible (TRUE), invisible de façon déterminée (FALSE : invisible sous tout
# traitement admis et pour toute valeur d'une valeur refusée) ou non déterminée (NA). Appelée
# par .construire_vue() (mode "vue") et par .connus() (modes "comptes" et "d03g"), une fois par
# appel de controler_base() et par mode. Statut propre (avant la règle 1), conjonction de :
# - dates de .DATES_VISIBILITE : connue au plus l'arrêté, vrai ; connue après, faux ;
#   refusée pour sa valeur (.date_connue(), M199, M201), manquante dans une colonne de D03i
#   (valeur inconnue, .inconnues_d03i(), M701 : ligne inscrite sous D03i, d'origine
#   « table.colonne »), ou illisible par sa forme, inconnu ;
# - D02b (date que compare D02b, `date_h` de .regle_prealable()) : sous l'hypothèse déclarée,
#   cette date au plus l'arrêté ; sans hypothèse, faux si elle est connue après l'arrêté,
#   inconnu sinon (aucune pour une fille, qui suit sa parente) ; ligne refusée sur une
#   colonne lue par D02b dont la valeur peut changer le statut (.refus_vue()) : inconnu ;
# - D03g, ligne entière : sous l'exclusion déclarée, faux (mode "vue") ; sous l'hypothèse,
#   date de saisie retenue (`ctx$date_g`) ; non résolue (sans déclaration complète, ou date
#   non calculable : `ctx$nd_p`, `reste_g`, `parente_g`), date de saisie inconnue, et faux si
#   la date d'effet de l'hypothèse (.EFFET_D03G) est connue après l'arrêté (délai positif ou
#   nul ; point P1) ;
# puis règle 1 jusqu'au point fixe (fille : statut propre ET statut de sa parente ; une
# orpheline garde son statut propre ; parente famille : « le membre est visible », visible si
# une version l'est, non déterminé si aucune ne l'est et qu'une l'est de façon non déterminée) ;
# version valable de famille (`valable` : dernière saisie visible du membre, déterminée si
# aucune version non déterminée n'a une saisie plus récente ou inconnue, sinon candidates en
# NA ; une version plus ancienne que la valable est non valable) ; adherents et assures :
# visibles s'ils sont référencés par une ligne visible (famille : version valable), non
# déterminés s'ils ne le sont que par des lignes non déterminées. Partie de ligne (`parties`) :
# connue à sa date (`ctx$partie_h` sous l'hypothèse de D03g) ; non résolue par la règle P,
# masquée de façon déterminée si `date_fin` (D03g) ou `date_saisie_fin` (D02b) est connue
# après l'arrêté, non déterminée sinon ; refusée pour sa valeur (.refus_vue()), non
# déterminée ; et toujours ET le statut de sa ligne. Écarts déclarés entre la vue et les
# comptes : (i) table refusée en portée table (.construire_vue()) ; (ii) mode "comptes" : une
# ligne que l'exclusion déclarée de D03g sort de la vue a la visibilité de l'hypothèse avec un
# délai nul (la date que compare D02b, .EFFET_D03G : evenements.date_effet,
# sinistres.date_declaration ou catastrophes.date_evenement, tient lieu de date de saisie ;
# aucune pour une fille, que borne sa parente ; D5, réserve Q4) ;
# (iii) mode "d03g" : même règle pour les lignes entières de D03g non résolues et celles qui
# suivent leur parente (réserve Q8). À l'arrêté égal à l'extraction, tout est visible (règle 3),
# hors des versions de famille remplacées. `refus` : entrées de .refus_vue(), relues par
# .construire_vue().
.EFFET_D03G <- list(evenements = "date_effet", sinistres = "date_declaration", catastrophes = "date_evenement")
.visibilite_a <- function(ctx, mode = "vue") {
  nom <- paste0("visibilite_", mode)
  if (!is.null(ctx[[nom]])) return(ctx[[nom]])
  totale <- .vue_totale(ctx)
  a <- as.numeric(ctx$arrete)
  lisible <- function(t, c1) is.na(.cause(ctx, t, c1, forme_seule = TRUE))
  tables <- setdiff(ctx$tables, "extraction")
  n_de <- function(t) nrow(ctx$base[[t]])
  # lignes entières de D03g non résolues, par table
  ouvertes <- list()
  for (t in tables) ouvertes[[t]] <- unique(c(ctx$reste_g[[t]], ctx$parente_g[[t]]))
  for (k in ctx$nd_p) {
    if (is.na(k$colonne) && k$motif == "D03g") ouvertes[[k$table]] <- unique(c(ouvertes[[k$table]], k$lignes))
  }
  # sans exclusion déclarée de D03g, les comptes lisent la vue (écart (ii) sans objet)
  if (mode == "comptes" && !any(unlist(ctx$exclu_g))) {
    res <- .visibilite_a(ctx, "vue")
    assign(nom, res, envir = ctx)
    return(res)
  }
  refus <- if (totale) list() else .refus_vue(ctx)
  propre <- list()
  for (t in tables) {
    n <- n_de(t)
    v <- rep(TRUE, n)
    if (totale) { propre[[t]] <- v; next }
    exclues <- which(ctx$exclu_g[[t]] %in% TRUE)
    delai0 <- switch(mode, vue = integer(0), comptes = exclues, d03g = sort(unique(c(exclues, ouvertes[[t]]))))
    ouv <- setdiff(ouvertes[[t]], delai0)
    effet <- .EFFET_D03G[[t]]
    for (c1 in .DATES_VISIBILITE[[t]]) {
      d <- .date_connue(ctx, t, c1)
      if (isTRUE(.COLONNES_D03G[t] == c1)) {
        g <- ctx$date_g[[t]]
        if (!is.null(g)) d <- ifelse(is.na(g), d, g)
        if (length(delai0)) d[delai0] <- if (is.null(effet)) -Inf else .date_connue(ctx, t, effet)[delai0]
      }
      # une date absente est celle d'une ligne de D03g (date de saisie, traitée ci-dessus), ou
      # une valeur obligatoire refusée comme manquante, inconnue (refus de valeur, ou table
      # refusée en portée table, où .refus_valeur_de() ne la rend pas), ou manquante dans une
      # colonne de D03i (valeur inconnue, M701) : NA
      v <- v & d <= a
    }
    if (mode == "vue") v[exclues] <- FALSE
    # D03g non résolue : la date d'effet de l'hypothèse connue après l'arrêté la rend invisible
    if (length(ouv) && !is.null(effet)) {
      de <- .date_connue(ctx, t, effet)[ouv]
      v[ouv[!is.na(de) & de > a]] <- FALSE
    }
    # D02b sous l'hypothèse déclarée : date que compare D02b au plus l'arrêté
    dh <- ctx$date_h[[t]]
    if (!is.null(dh)) v <- v & (is.na(dh) | dh <= a)
    propre[[t]] <- v
  }
  if (!totale) {
    for (k in ctx$nd_p) {
      # D02b sans hypothèse : inconnu, faux si la date que compare D02b est connue après l'arrêté
      if (k$motif != "D02b" || !is.na(k$colonne)) next
      x <- rep(NA, length(k$lignes))
      if (!is.null(k$date_h)) {
        dc <- .date_connue(ctx, k$table, k$date_h)[k$lignes]
        x[!is.na(dc) & dc > a] <- FALSE
      }
      propre[[k$table]][k$lignes] <- propre[[k$table]][k$lignes] & x
    }
    # refus de valeur d'une colonne lue par la vue, qui peut changer le statut de la ligne
    for (k in refus) if (is.na(k$colonne)) propre[[k$table]][k$lignes] <- propre[[k$table]][k$lignes] & NA
  }
  statut <- propre
  if (!totale) {
    # règle 1, jusqu'au point fixe ; une clé de lien illisible par sa forme : non déterminée ;
    # exception de la garantie souscrite d'un dossier (.liens_regle1(), #83)
    liens <- .liens_regle1(ctx$dico)
    liens <- liens[liens$table %in% tables & liens$table_cible %in% tables, , drop = FALSE]
    repeat {
      change <- FALSE
      for (i in seq_len(nrow(liens))) {
        t <- liens$table[i]
        parente <- .parente_regle1(ctx, liens[i, , drop = FALSE], statut)
        nouveau <- statut[[t]] & parente
        if (!identical(nouveau, statut[[t]])) {
          statut[[t]] <- nouveau
          change <- TRUE
        }
      }
      if (!change) break
    }
  }
  # famille : la version valable d'un membre est sa dernière saisie visible (réserve Q9) ; une
  # version plus récente, ou de saisie inconnue, de visibilité non déterminée la rend non
  # déterminée (candidates : la dernière visible et ces versions)
  valable <- NULL
  candidate <- NULL
  membre <- NULL
  if ("famille" %in% tables) {
    valable <- statut$famille
    if (lisible("famille", "id_membre")) {
      membre <- .cle_manquante(as.character(.valeurs(ctx, "famille", "id_membre")))
      membre[is.na(membre)] <- paste0("\r", which(is.na(membre)))   # un manquant ("" compris) : un membre à part
      saisie <- if (lisible("famille", "date_saisie")) as.numeric(.valeurs(ctx, "famille", "date_saisie")) else
        rep(NA_real_, length(membre))
      g <- ctx$date_g$famille
      if (!is.null(g)) saisie <- ifelse(is.na(g), saisie, g)
      max_de <- function(z) if (all(is.na(z))) NA_real_ else max(z, na.rm = TRUE)
      x <- valable
      derniere <- stats::ave(ifelse(x %in% TRUE, saisie, NA_real_), membre, FUN = max_de)
      recente_nd <- stats::ave(ifelse(is.na(x), ifelse(is.na(saisie), Inf, saisie), NA_real_), membre, FUN = max_de)
      x[x %in% TRUE & !is.na(derniere) & (is.na(saisie) | saisie < derniere)] <- FALSE
      x[x %in% TRUE & !is.na(recente_nd) & (is.na(saisie) | recente_nd > saisie)] <- NA
      # candidates d'un membre à version valable non déterminée (règle V, .regle_vue()) : la
      # dernière version visible, et chaque version non déterminée plus récente ou de saisie
      # inconnue
      candidate_visible <- valable %in% TRUE & is.na(x)
      a_candidate <- stats::ave(as.numeric(candidate_visible), membre, FUN = max) > 0
      candidate <- candidate_visible | (is.na(valable) & a_candidate & (is.na(saisie) | saisie > derniere))
      valable <- x
    }
  }
  # adherents et assures : visibles s'ils sont référencés par une ligne visible
  references <- list(adherents = list(c("contrats", "id_adherent")),
                     assures = list(c("contrats", "id_assure"), c("affiliations", "id_assure"), c("famille", "id_assure"),
                                    c("famille", "id_assure_membre"), c("sinistres", "id_assure"),
                                    c("victimes", "id_assure"), c("ayants_droit_sante", "id_assure_membre")))
  for (t in intersect(names(references), tables)) {
    if (totale) next
    cle_t <- eclater_champ(ctx$dico$tables$cle_primaire[ctx$dico$tables$table == t])[1L]
    if (!lisible(t, cle_t)) { statut[[t]] <- rep(NA, n_de(t)); next }
    cle <- .cle_manquante(as.character(.valeurs(ctx, t, cle_t)))
    vrai <- character(0)
    indet <- character(0)
    for (r in references[[t]]) {
      if (!(r[1L] %in% tables)) next
      if (!lisible(r[1L], r[2L])) { indet <- c(indet, cle); next }
      x <- .cle_manquante(as.character(.valeurs(ctx, r[1L], r[2L])))
      s <- if (r[1L] == "famille") valable else statut[[r[1L]]]
      vrai <- c(vrai, x[s %in% TRUE])
      indet <- c(indet, x[is.na(s)])
    }
    statut[[t]] <- ifelse(!is.na(apparier_cles(cle, vrai)), TRUE, ifelse(!is.na(apparier_cles(cle, indet)), NA, FALSE))
    propre[[t]] <- statut[[t]]
  }
  # parties de ligne ; une date de partie illisible par sa forme (valeur écrite que l'outil ne
  # sait pas lire, champ non vide) est inconnue, NA dans les deux modes, sans conversion ; un
  # champ vide garde sa valeur (#51 ; spécification de B2, § 4.3 : « illisible » vaut
  # « inconnu », non « absente »)
  parties <- list()
  for (p in .PARTIES_LIGNE) {
    t <- p$table
    if (!(t %in% tables)) next
    illisible <- if (lisible(t, p$date)) rep(FALSE, n_de(t)) else !is.na(.valeurs(ctx, t, p$date))
    if (totale) {
      x <- rep(TRUE, n_de(t))
      x[illisible] <- NA
      parties[[t]] <- x
      next
    }
    d <- if (lisible(t, p$date)) as.numeric(.valeurs(ctx, t, p$date)) else rep(NA_real_, n_de(t))
    dh <- ctx$partie_h[[t]]
    if (!is.null(dh) && p$date == "date_saisie_fin") d <- ifelse(is.na(dh), d, dh)
    x <- !is.na(d) & d <= a
    for (k in ctx$nd_p) {
      if (k$table != t || !identical(k$colonne, p$date)) next
      y <- rep(NA, length(k$lignes))
      dc <- .date_connue(ctx, t, if (k$motif == "D03g") "date_fin" else p$date)[k$lignes]
      y[!is.na(dc) & dc > a] <- FALSE
      x[k$lignes] <- y
    }
    for (k in refus) if (k$table == t && identical(k$colonne, p$date)) x[k$lignes] <- NA
    x[illisible] <- NA
    parties[[t]] <- x & statut[[t]]
  }
  res <- list(statut = statut, propre = propre, valable = valable, candidate = candidate, membre = membre,
              parties = parties, refus = refus)
  assign(nom, res, envir = ctx)
  res
}

# Cause qui empêche de lire l'une des colonnes `lus` (« table.colonne ») : c(table, colonne,
# cause), ou NULL ; `forme_seule` : écarts de forme seulement (.causes()). Cause et colonne
# suivent .cause_colonnes() : elles ne dépendent pas de l'ordre de `lus` (spécification
# `donnees` v1.7, § 3.1, « Cause d'une composante de l'enjeu », #122).
.cause_lecture <- function(ctx, lus, forme_seule = FALSE) {
  lus <- unique(lus)
  .cause_colonnes(ctx, lus, lapply(lus, function(tc) {
    m <- strsplit(tc, ".", fixed = TRUE)[[1L]]
    .causes(ctx, m[1L], m[2L], forme_seule)
  }))
}

# Cause d'une lecture qui rend une colonne illisible pour une règle V en mode Kleene : cause de
# forme ou de portée table seulement (.cause_lecture() sur les colonnes sans refus de valeur ; une
# colonne refusée pour sa valeur, lue de façon existentielle, n'a ni défaut de forme ni refus de
# portée table, .refus_valeur_de() ; #105, lot V, G2b ; erratum `1.9.7`, E-11).
.cause_hors_valeur <- function(ctx, lus) {
  lus <- unique(lus)
  garde <- vapply(strsplit(lus, ".", fixed = TRUE), function(m) is.null(.lignes_refusees(ctx, m[1L], m[2L])), NA)
  .cause_lecture(ctx, lus[garde])
}

# Cause d'une lecture de plusieurs colonnes (spécification `donnees` v1.7, § 3.1, « Cause
# d'une composante de l'enjeu », #122) : `candidates`, liste des causes candidates de chaque
# colonne de `lus` (« table.colonne », sans doublon) ; cause retenue : la plus petite de leur
# union dans l'ordre (rang, position) (.cause_retenue()) ; table et colonne publiées : celles
# de la colonne qui la porte, la première dans l'ordre du dictionnaire (.ordre_dictionnaire())
# si plusieurs la portent. Rend c(table, colonne, cause), NULL sans cause. Minimum sous un
# ordre total, puis premier dans un ordre total : indépendant de l'ordre de `lus`.
.cause_colonnes <- function(ctx, lus, candidates) {
  candidates <- lapply(candidates, function(x) x[!is.na(x)])
  if (length(unlist(candidates)) == 0L) return(NULL)
  cause <- .cause_retenue(unlist(candidates), ctx$dico, ctx$ordre_codes)
  porte <- lus[vapply(candidates, function(x) cause %in% x, NA)]
  tc <- porte[.ordre_dictionnaire(ctx$dico, porte)[1L]]
  m <- strsplit(tc, ".", fixed = TRUE)[[1L]]
  c(table = m[1L], colonne = m[2L], cause = cause)
}

# Ordre du dictionnaire de colonnes « table.colonne » : tables de tables.csv, puis colonnes de
# colonnes.csv (permutation, comme order()) ; une colonne absente du dictionnaire après les
# colonnes de sa table, une table absente après toutes les autres ; départage final par le nom.
.ordre_dictionnaire <- function(dico, lus) {
  t <- sub("\\..*$", "", lus)
  order(match(t, dico$tables$table), match(paste(t, sub("^[^.]*\\.", "", lus)), paste(dico$colonnes$table, dico$colonnes$colonne)),
        lus, method = "radix")
}

# Paires (i, j) telles que x[i] == y[j], valeurs manquantes exclues (jointure un à plusieurs),
# une chaîne vide comme une valeur manquante (.cle_manquante(), #123), triées par i puis j ;
# composition de deux relations (i -> k, k -> j). Par correspondance (match) sur les clés
# distinctes de y : coût proportionnel au nombre de paires rendues.
.paires <- function(x, y) {
  x <- .cle_manquante(as.character(x))
  y <- .cle_manquante(as.character(y))
  i <- which(!is.na(x))
  j <- which(!is.na(y))
  if (length(i) == 0L || length(j) == 0L) return(data.frame(i = integer(0), j = integer(0)))
  cles <- unique(y[j])
  g <- match(y[j], cles)
  j <- j[order(g, j, method = "radix")]
  nb <- tabulate(g, length(cles))
  debut <- cumsum(c(1L, nb))[seq_along(cles)]
  m <- match(x[i], cles)
  i <- i[!is.na(m)]
  m <- m[!is.na(m)]
  n <- nb[m]
  data.frame(i = rep(i, n), j = j[rep(debut[m], n) + sequence(n) - 1L])
}
.composer <- function(p, q) {
  m <- .paires(p$j, q$i)
  data.frame(i = p$i[m$i], j = q$j[m$j])
}

# Rattachement des lignes d'une table aux dossiers (spécification, § 4.4), par chemins de clés
# (colonne locale, table visée, colonne visée) : rend `paires` (data.frame ligne, dossier :
# numéros de ligne de la table et de dossiers, sans doublon, triés ; sur : TRUE, NA pour une
# paire de rattachement non déterminé, garantie souscrite en double d'une affiliation, #131)
# et `cause` (colonne de clé
# illisible par sa forme : c(table, colonne, cause), sinon NULL ; plus petite cause de forme
# des colonnes des chemins, colonne publiée la première qui la porte dans l'ordre du
# dictionnaire, .cause_lecture() ; spécification `donnees` v1.7, § 3.1, #122). evenements :
# par id_dossier, sinon par le sinistre ; affiliations : dossiers des sinistres de l'assuré sous le même
# contrat (pas de cascade) ; cotisations, evaluations_gestion, designations,
# ayants_droit_sante : aucun dossier. Calculé une fois par table, pour toutes ses lignes.
.CHEMINS_RATTACHEMENT <- list(
  adherents = list(list(c("id_adherent", "contrats", "id_adherent"), c("id_contrat", "garanties_souscrites", "id_contrat"),
                        c("id_garantie_souscrite", "dossiers", "id_garantie_souscrite"))),
  contrats = list(list(c("id_contrat", "garanties_souscrites", "id_contrat"),
                       c("id_garantie_souscrite", "dossiers", "id_garantie_souscrite"))),
  garanties_souscrites = list(list(c("id_garantie_souscrite", "dossiers", "id_garantie_souscrite"))),
  parametres = list(list(c("id_garantie_souscrite", "dossiers", "id_garantie_souscrite"))),
  assures = list(list(c("id_assure", "sinistres", "id_assure"), c("id_sinistre", "dossiers", "id_sinistre"))),
  affiliations = list(list(c("id_assure", "sinistres", "id_assure"), c("id_sinistre", "dossiers", "id_sinistre"))),
  famille = list(list(c("id_sinistre", "dossiers", "id_sinistre")),
                 list(c("id_membre", "beneficiaires", "id_membre"), c("id_dossier", "dossiers", "id_dossier")),
                 list(c("id_membre", "rentes", "id_membre"), c("id_dossier", "dossiers", "id_dossier"))),
  sinistres = list(list(c("id_sinistre", "dossiers", "id_sinistre"))),
  beneficiaires = list(list(c("id_dossier", "dossiers", "id_dossier"))),
  rentes = list(list(c("id_dossier", "dossiers", "id_dossier"))),
  evenements = list(list(c("id_dossier", "dossiers", "id_dossier")), list(c("id_sinistre", "dossiers", "id_sinistre"))),
  prestations = list(list(c("id_dossier", "dossiers", "id_dossier"))),
  catastrophes = list(list(c("id_catastrophe", "victimes", "id_catastrophe"), c("id_sinistre", "dossiers", "id_sinistre"))),
  victimes = list(list(c("id_sinistre", "dossiers", "id_sinistre"))))

.rattacher <- function(ctx, table) {
  if (!is.null(ctx$rattachements[[table]])) return(ctx$rattachements[[table]])
  vide <- data.frame(ligne = integer(0), dossier = integer(0), sur = logical(0))
  chemins <- .CHEMINS_RATTACHEMENT[[table]]
  n <- nrow(ctx$base[[table]])
  res <- list(paires = vide, cause = NULL)
  if (table == "dossiers") {
    res$paires <- data.frame(ligne = seq_len(n), dossier = seq_len(n), sur = rep(TRUE, n))
  } else if (!is.null(chemins) && !is.null(ctx$base$dossiers)) {
    lus <- unlist(lapply(chemins, function(ch) {
      courante <- table
      unlist(lapply(ch, function(h) { tc <- c(paste(courante, h[1L], sep = "."), paste(h[2L], h[3L], sep = "."))
                                      courante <<- h[2L]; tc }))
    }))
    if (table == "affiliations") {
      lus <- c(lus, "affiliations.id_contrat", "dossiers.id_garantie_souscrite",
               "garanties_souscrites.id_garantie_souscrite", "garanties_souscrites.id_contrat")
    }
    res$cause <- .cause_lecture(ctx, unique(lus), forme_seule = TRUE)
    if (is.null(res$cause)) {
      paires <- lapply(seq_along(chemins), function(k) {
        depart <- seq_len(n)
        # evenements : le chemin par le sinistre ne sert qu'aux événements sans dossier
        if (table == "evenements" && k == 2L) depart <- which(is.na(.cle_manquante(.valeurs(ctx, "evenements", "id_dossier"))))
        p <- data.frame(i = depart, j = depart)
        courante <- table
        for (h in chemins[[k]]) {
          # clés des seules lignes atteintes (pas de jointure de toute la table)
          x <- .valeurs(ctx, courante, h[1L])
          x[!(seq_along(x) %in% p$j)] <- NA
          p <- .composer(p, .paires(x, .valeurs(ctx, h[2L], h[3L])))
          courante <- h[2L]
        }
        p
      })
      p <- do.call(rbind, paires)
      p$sur <- rep(TRUE, nrow(p))
      if (table == "affiliations" && nrow(p) > 0L) {
        # contrat de la garantie souscrite du dossier : lecture existentielle sur les occurrences
        # d'une garantie souscrite en double (spécification `donnees` v1.7, § 2.2, B.4, #131) :
        # paire gardée si chaque occurrence porte le contrat de l'affiliation, exclue si aucune,
        # sinon rattachement non déterminé (`sur` NA) ; une seule jointure (.joindre3())
        jc <- .joindre3(ctx, "garanties_souscrites", "id_garantie_souscrite", "id_contrat",
                        .valeurs(ctx, "dossiers", "id_garantie_souscrite")[p$j])
        ctr <- .cle_manquante(.valeurs(ctx, "garanties_souscrites", "id_contrat"))
        ca <- .cle_manquante(.valeurs(ctx, "affiliations", "id_contrat"))[p$i]
        egal <- vapply(seq_len(nrow(p)), function(r) {
          o <- jc$index[[r]]
          e <- !is.na(o) & !is.na(ctr[o]) & !is.na(ca[r]) & ctr[o] == ca[r]
          if (all(e)) TRUE else if (!any(e)) FALSE else NA
        }, NA)
        p <- p[!(egal %in% FALSE), , drop = FALSE]
        p$sur <- egal[!(egal %in% FALSE)]
      }
      p <- unique(data.frame(ligne = p$i, dossier = p$j, sur = p$sur))
      p <- p[order(p$ligne, p$dossier, method = "radix"), , drop = FALSE]
      rownames(p) <- NULL
      res$paires <- p
    }
  }
  ctx$rattachements[[table]] <- res
  res
}

# Dernier événement connu à l'arrêté pour chaque porteur (spécification, § 4.2 ; ADR 0010,
# sixième série, (c) 4) : `paires` (i : événement, j : porteur) déjà restreintes aux
# événements retenus ; ordre de départage : date d'effet, ordre des types du § 4, date de
# saisie, id_evenement en tri radix. Rend, pour chacun des `n` porteurs, le numéro de ligne
# de l'événement retenu (NA sans événement). Seule implémentation, que réemploiera
# etats_a_date() (B2).
.dernier_evenement <- function(ctx, paires, n) {
  res <- rep(NA_integer_, n)
  if (nrow(paires) == 0L) return(res)
  ev <- function(c1) .valeurs(ctx, "evenements", c1)[paires$i]
  te <- ctx$dico$types_evenements
  o <- order(paires$j, as.numeric(ev("date_effet")), te$ordre[match(ev("type_evenement"), te$type_evenement)],
             as.numeric(ev("date_saisie")), ev("id_evenement"), method = "radix")
  p <- paires[o, , drop = FALSE]
  dernier <- !duplicated(p$j, fromLast = TRUE)
  res[p$j[dernier]] <- p$i[dernier]
  res
}

# Rattachement à un dossier d'une ligne refusée de portée ligne lue par la composante
# `composante` (1 à 4) de l'enjeu (spécification `donnees` v1.9, § 9.2, #72) : lignes que la
# composante lit pour le dossier, par les clés de .composantes_dossiers() (prestations et
# rentes du dossier, connues à l'arrêté ; événements du dossier, ou du sinistre pour une sortie
# de l'indemnité journalière, ou des rentes du dossier ; garantie souscrite du dossier pour les
# composantes qui lisent la garantie), un événement comptant s'il peut entrer dans la valeur :
# type de la composante et date d'effet au plus l'arrêté, ou l'un d'eux refusé (inconnu,
# lecture de Kleene). Rend la fonction rattacher(table, lignes) de .refus_ligne_porteurs().
.rattacher_composante <- function(ctx, composante, d03g = FALSE) {
  v <- function(t, c1) .valeurs(ctx, t, c1)
  a <- as.numeric(ctx$arrete)
  service <- c("ouverture_service", "modification_montant")
  vers <- function(l, cle, cle_dossier) {
    p <- .paires(cle, v("dossiers", cle_dossier))
    data.frame(ligne = l[p$i], porteur = p$j)
  }
  function(table, lignes) {
    if (table == "dossiers") return(data.frame(ligne = lignes, porteur = lignes))
    if (table == "garanties_souscrites") {
      p <- .paires(v("dossiers", "id_garantie_souscrite"), v("garanties_souscrites", "id_garantie_souscrite")[lignes])
      return(data.frame(ligne = lignes[p$j], porteur = p$i))
    }
    l <- lignes[.connus(ctx, table, d03g)[lignes] %in% TRUE]
    if (table %in% c("prestations", "rentes")) return(vers(l, v(table, "id_dossier")[l], "id_dossier"))
    if (table != "evenements") return(data.frame(ligne = integer(0), porteur = integer(0)))
    type <- v("evenements", "type_evenement")
    effet <- as.numeric(v("evenements", "date_effet"))
    type_i <- .inconnu(ctx, "evenements", "type_evenement")
    l <- l[(!is.na(effet[l]) & effet[l] <= a) | .inconnu(ctx, "evenements", "date_effet")[l]]
    de_type <- function(x) l[type[l] %in% x | type_i[l]]
    if (composante == "capital_fixe") {
      lk <- de_type("fixation_capital")
      return(vers(lk, v("evenements", "id_dossier")[lk], "id_dossier"))
    }
    if (composante == "ij_en_vigueur") {
      lk <- de_type(c(service, "fin_service"))
      lx <- de_type("sortie")
      return(unique(rbind(vers(lk, v("evenements", "id_dossier")[lk], "id_dossier"),
                          vers(lx, v("evenements", "id_sinistre")[lx], "id_sinistre"))))
    }
    if (composante == "rente_annuelle_en_vigueur") {
      lk <- de_type(c(service, "fin_service"))
      kr <- .connus(ctx, "rentes", d03g) %in% TRUE
      q <- .paires(v("evenements", "id_rente")[lk], v("rentes", "id_rente"))
      q <- q[kr[q$j], , drop = FALSE]
      pr <- .paires(v("rentes", "id_dossier")[q$j], v("dossiers", "id_dossier"))
      return(unique(data.frame(ligne = lk[q$i[pr$i]], porteur = pr$j)))
    }
    data.frame(ligne = integer(0), porteur = integer(0))
  }
}

# Composantes 1 à 4 de chaque dossier à l'arrêté (spécification, § 4.3) : `garantie`
# (code_garantie, ou non_rattache), `valeurs` (liste nommée par
# composante d'un vecteur par dossier, NA : aucune valeur ; une composante sans objet pour la
# garantie du dossier n'a pas de valeur), `indetermine` (par composante, dossier dont une
# ligne qui entre dans la valeur a une visibilité non déterminée : la valeur n'est pas connue
# à l'arrêté, réserve Q8 (b)), `lus` (colonnes lues par composante ; la cause qui l'empêche
# dépend de l'écart, .causes_enjeu()) et `forme` (colonne lue illisible par sa forme,
# .cause_lecture() : la valeur n'est pas calculée). Les montants sont pris tels quels (aucune
# correction, dictionnaire, § 1.10) ; sommes en ordre trié des montants, indépendantes de l'ordre des
# lignes (réserve m3). Calculé une fois par appel.
.composantes_dossiers <- function(ctx, d03g = FALSE) {
  nom <- if (d03g) "composantes_g" else "composantes"
  if (!is.null(ctx[[nom]])) return(ctx[[nom]])
  v <- function(t, c1) .valeurs(ctx, t, c1)
  nd <- nrow(ctx$base$dossiers)
  a <- as.numeric(ctx$arrete)
  lus_g <- c("dossiers.id_garantie_souscrite", "garanties_souscrites.id_garantie_souscrite",
             "garanties_souscrites.code_garantie")
  # garantie souscrite en double aux occurrences divergentes sur code_garantie : lien non
  # déterminé, non_rattache (lecture existentielle, spécification `donnees` v1.7, § 2.2, B.4,
  # « Clé primaire en double », #131 ; même lecture que la garantie d'un lien non résolu, § 4.4)
  garantie <- if (is.null(.cause_lecture(ctx, lus_g, forme_seule = TRUE))) {
    j <- .joindre3(ctx, "garanties_souscrites", "id_garantie_souscrite", "code_garantie", v("dossiers", "id_garantie_souscrite"))
    ifelse(j$diverge, NA_character_, j$valeurs)
  } else rep(NA_character_, nd)
  garantie[is.na(garantie)] <- "non_rattache"
  commun <- c("dossiers.id_dossier", "dossiers.date_ouverture")
  ev_commun <- paste0("evenements.", c("id_evenement", "type_evenement", "date_effet", "date_saisie", "montant"))
  # paiements_cumules ne dépend pas de la garantie ; les composantes 2 à 4 la lisent (réserve
  # Q10 : une garantie dont le code est refusé les rend NA)
  lus <- list(
    paiements_cumules = c(commun, paste0("prestations.", c("id_dossier", "montant", "date_saisie", "date_reglement"))),
    capital_fixe = c(commun, lus_g, ev_commun, "evenements.id_dossier"),
    rente_annuelle_en_vigueur = c(commun, lus_g, ev_commun, "evenements.id_rente", "rentes.id_rente", "rentes.id_dossier",
                                  "rentes.date_saisie"),
    ij_en_vigueur = c(commun, lus_g, ev_commun, "evenements.id_dossier", "evenements.id_sinistre", "dossiers.id_sinistre"))
  # valeurs brutes des composantes 2 à 4, sans la garantie (lien de la garantie non résolu,
  # réserve Q5 d'`actuary`) : événements propres du dossier ; l'indemnité journalière ne lit
  # que les services de niveau dossier (id_rente manquant)
  lus_brut <- lapply(lus, function(l) setdiff(l, lus_g))
  lus_brut$ij_en_vigueur <- c(lus_brut$ij_en_vigueur, "evenements.id_rente")
  forme <- lapply(lus, function(l) .cause_lecture(ctx, l, forme_seule = TRUE))
  forme_brut <- lapply(lus_brut, function(l) .cause_lecture(ctx, l, forme_seule = TRUE))
  valeurs <- lapply(lus, function(l) rep(NA_real_, nd))
  brutes <- valeurs
  indetermine <- lapply(lus, function(l) rep(FALSE, nd))
  # somme par dossier, en ordre trié des montants (indépendante de l'ordre des lignes)
  somme_par <- function(montant, j) {
    o <- order(j, montant, method = "radix")
    s <- rowsum(montant[o], j[o], reorder = TRUE)
    x <- rep(NA_real_, nd)
    x[as.integer(rownames(s))] <- s[, 1L]
    x
  }
  # paires (ligne, dossier) d'une somme par dossier, un identifiant (clé primaire) compté une
  # fois par dossier : les lignes en double d'un identifiant (D01a) qui concordent ne
  # comptent qu'une fois (D10, réserve M1) ; celles qui divergent rendent la composante sans
  # valeur (.divergences_d01a()) ; un identifiant manquant n'est pas regroupé
  distinctes <- function(table, l, p) {
    cle <- eclater_champ(ctx$dico$tables$cle_primaire[ctx$dico$tables$table == table])
    vc <- lapply(cle, function(c1) .cle_manquante(as.character(.valeurs(ctx, table, c1))[l][p$i]))
    # code du groupe sans paste() (#153) : un identifiant manquant ou vide a le code NA, il n'est
    # pas regroupé, et un « NA » littéral reste distinct de lui
    id <- .code_groupe(c(vc, list(p$j)), cles = seq_along(vc))
    p[is.na(id) | !duplicated(id), , drop = FALSE]
  }
  dossiers_de <- function(cle, cle_dossier) unique(.paires(cle, v("dossiers", cle_dossier))$j)
  if (is.null(forme$paiements_cumules)) {
    cp <- .connus(ctx, "prestations", d03g)
    k <- which(cp %in% TRUE)
    p <- distinctes("prestations", k, .paires(v("prestations", "id_dossier")[k], v("dossiers", "id_dossier")))
    if (nrow(p) > 0L) valeurs$paiements_cumules <- somme_par(v("prestations", "montant")[k][p$i], p$j)
    indetermine$paiements_cumules[dossiers_de(v("prestations", "id_dossier")[is.na(cp)], "id_dossier")] <- TRUE
  }
  # composante k calculable, rattachée (`forme`) ou brute (`forme_brut`) : les deux lectures
  # ont leurs gardes propres (l'indemnité brute lit evenements.id_rente, la rattachée la
  # garantie ; un défaut de forme de l'une n'empêche pas l'autre)
  calculable <- function(k) is.null(forme[[k]]) || is.null(forme_brut[[k]])
  # événements de date d'effet au plus l'arrêté : connus (`retenu_ev`) ou de visibilité non
  # déterminée (`indet_ev`) ; lus seulement si une composante 2 à 4 peut l'être
  if (calculable("capital_fixe") || calculable("rente_annuelle_en_vigueur") || calculable("ij_en_vigueur")) {
    type <- v("evenements", "type_evenement")
    effet <- as.numeric(v("evenements", "date_effet"))
    ce <- .connus(ctx, "evenements", d03g)
    dans_a <- !is.na(effet) & effet <= a
    retenu_ev <- ce %in% TRUE & dans_a
    indet_ev <- is.na(ce) & (dans_a | is.na(effet))
    montant_ev <- v("evenements", "montant")
  }
  service <- c("ouverture_service", "modification_montant")
  if (calculable("capital_fixe")) {
    k <- which(retenu_ev & type %in% "fixation_capital")
    p <- .paires(v("evenements", "id_dossier")[k], v("dossiers", "id_dossier"))
    dernier <- .dernier_evenement(ctx, data.frame(i = k[p$i], j = p$j), nd)
    brutes$capital_fixe <- montant_ev[dernier]
    valeurs$capital_fixe <- ifelse(garantie %in% .GARANTIES_CAPITAL, montant_ev[dernier], NA_real_)
    indetermine$capital_fixe[dossiers_de(v("evenements", "id_dossier")[indet_ev & type %in% "fixation_capital"],
                                         "id_dossier")] <- TRUE
  }
  if (calculable("rente_annuelle_en_vigueur")) {
    nr <- nrow(ctx$base$rentes)
    cr <- .connus(ctx, "rentes", d03g)
    kr <- cr %in% TRUE
    id_rente <- v("rentes", "id_rente")
    # dernier événement de service ou de fin_service de la rente dans l'ordre du § 4.2 : en
    # service au montant du dernier service, éteinte sinon (une réouverture après fin_service
    # rallume la rente ; même règle que l'indemnité journalière, réserve Q13)
    k <- which(retenu_ev & type %in% c(service, "fin_service"))
    p <- .paires(v("evenements", "id_rente")[k], id_rente)
    p <- p[kr[p$j], , drop = FALSE]
    dernier <- .dernier_evenement(ctx, data.frame(i = k[p$i], j = p$j), nr)
    par_rente <- ifelse(kr & !is.na(dernier) & type[dernier] %in% service, montant_ev[dernier], NA_real_)
    q <- .paires(v("rentes", "id_dossier"), v("dossiers", "id_dossier"))
    q <- distinctes("rentes", seq_len(nr), q)
    # rente de visibilité non déterminée, ou événement de service ou de fin non déterminé
    ki <- which(indet_ev & type %in% c(service, "fin_service"))
    rente_indet <- is.na(cr) | seq_len(nr) %in% .paires(v("evenements", "id_rente")[ki], id_rente)$j
    indetermine$rente_annuelle_en_vigueur[unique(q$j[rente_indet[q$i]])] <- TRUE
    q <- q[!is.na(par_rente[q$i]), , drop = FALSE]
    if (nrow(q) > 0L) {
      brutes$rente_annuelle_en_vigueur <- somme_par(par_rente[q$i], q$j)
      valeurs$rente_annuelle_en_vigueur <- ifelse(garantie %in% .GARANTIES_RENTE, brutes$rente_annuelle_en_vigueur, NA_real_)
    }
  }
  if (calculable("ij_en_vigueur")) {
    # dernier événement de service ou d'extinction (fin_service du dossier, sortie du
    # sinistre) dans l'ordre du § 4.2 : l'indemnité est éteinte si c'est une extinction, en
    # vigueur au montant du dernier service sinon (une rechute suivie d'une nouvelle
    # ouverture la rallume ; réserve Q11)
    ks <- which(retenu_ev & type %in% c(service, "fin_service"))
    kx <- which(retenu_ev & type %in% "sortie")
    q1 <- .paires(v("evenements", "id_dossier")[ks], v("dossiers", "id_dossier"))
    q2 <- .paires(v("evenements", "id_sinistre")[kx], v("dossiers", "id_sinistre"))
    p <- rbind(data.frame(i = ks[q1$i], j = q1$j), data.frame(i = kx[q2$i], j = q2$j))
    dernier <- .dernier_evenement(ctx, p, nd)
    en_service <- !is.na(dernier) & type[dernier] %in% service
    if (is.null(forme$ij_en_vigueur)) {
      valeurs$ij_en_vigueur <- ifelse(garantie %in% "incapacite" & en_service, montant_ev[dernier], NA_real_)
    }
    if (is.null(forme_brut$ij_en_vigueur)) {
      sans_rente <- is.na(.cle_manquante(v("evenements", "id_rente")))   # "" : manquant (#123)
      pb <- p[sans_rente[p$i], , drop = FALSE]
      dernier_b <- .dernier_evenement(ctx, pb, nd)
      brutes$ij_en_vigueur <- ifelse(!is.na(dernier_b) & type[dernier_b] %in% service, montant_ev[dernier_b], NA_real_)
    }
    ki <- which(indet_ev & type %in% c(service, "fin_service"))
    kj <- which(indet_ev & type %in% "sortie")
    indetermine$ij_en_vigueur[c(dossiers_de(v("evenements", "id_dossier")[ki], "id_dossier"),
                                dossiers_de(v("evenements", "id_sinistre")[kj], "id_sinistre"))] <- TRUE
  }
  for (k in names(forme)) if (!is.null(forme[[k]])) valeurs[[k]] <- rep(NA_real_, nd)
  brutes$paiements_cumules <- valeurs$paiements_cumules
  for (k in names(forme_brut)) if (!is.null(forme_brut[[k]])) brutes[[k]] <- rep(NA_real_, nd)
  assign(nom, list(garantie = garantie, valeurs = valeurs, brutes = brutes,
                   indetermine = indetermine, lus = lus, lus_brut = lus_brut, lus_g = lus_g), envir = ctx)
  ctx[[nom]]
}

# Placement des constats selon leur traitement et les déclarations (spécification, § 3 ; ADR
# 0010, sixième série, (b) 3 et 4 ; décisions du mainteneur D4 et D5). R et S sont placés par
# .bilan(). Un constat à choix a deux axes : X par famille de calcul (.familles_x() : hors des
# couples traités S, .exceptions_famille()) et H ou S par référentiel (S : valeur
# .VALEUR_SIGNALEMENT de `hypotheses`, pour un constat qui admet S). Il est couvert si
# l'exclusion est déclarée pour chaque famille, ou H ou S pour chaque référentiel ; couvert,
# il n'est placé que sur un axe (réserve M1 ; un motif à traitement unique n'est jamais
# déclaré sur les deux, D8 ; ailleurs l'exclusion l'emporte, dont D03g, D11) : `exclusions`
# par famille, ou `hypotheses_defaut` par référentiel en H et `signalements` (une fois) si
# un référentiel est en S. Non couvert, chaque déclaration est placée et chaque famille et
# chaque référentiel sans déclaration va dans `declarations_requises` (traitements admis :
# ceux du constat). Chaque hypothèse placée porte ses colonnes (`colonnes` ; garde du point 1
# de #112, M661) : colonne du constat pour D02b et D03g, dates tenues pour inconnues de la
# table pour D02a (.DATES_D02A). D02a placé en H (annexe B du dictionnaire 1.6 ; spécification
# `donnees` v1.9, § 9.4, #90) : les dates rejetées vont dans `inconnues` (list(table, colonnes,
# lignes) ; R8 : aussi la naissance de l'assuré, dans toutes ses lignes de `assures`), lues par
# .appliquer_d02a() après le bilan ; le défaut de manquant qui s'enchaîne (D03a pour R8 et R11,
# D03f pour R7 sur une ligne qu'il viserait, .inconnues_d02a()) est placé pour ces lignes
# comme pour une ligne de ce défaut (exclusion, hypothèse ou déclaration requise, sans forme
# nouvelle : M688), sans compter dans sa détection ni dans ses signalements.
# Motifs de la règle P (D02b, D03g), appliqués à la vue : une déclaration
# n'est placée que si elle est appliquée (D02b : hypothèse pour les deux référentiels ;
# D03g : .application_d03g()), et le délai de D03g manquant va dans `declarations_requises`
# (rubrique `seuils`, clé d03g_delai_jours$<table>) tant que l'exclusion ne couvre pas le
# constat ; une partie de ligne de D03g n'admet que l'hypothèse (D9) ; sous l'hypothèse de
# D03g, une ligne dont la date ne se calcule pas par elle-même reste hors de
# hypotheses_defaut et attend l'exclusion (X, Q5), une ligne dont seule la parente est non
# déterminée n'attend rien en propre (parente_non_determinee, Q2 (b)). Une orpheline traitée
# X (D04a, D04b) ne compte que ses lignes dont la visibilité tient à l'arrêté
# (spécification, § 2.4 ; indéterminée : comptée). Rend les lignes brutes (avec table et
# lignes), `signales` (constats placés en S par déclaration) et les écarts de l'enjeu : refus
# R (hors refus induit, sans enjeu propre) et exclusions, déclarées ou non (`non_declaree`).
.placer <- function(ctx, constats) {
  ex <- ctx$declarations$exclusions
  hy <- ctx$declarations$hypotheses
  if (is.null(ex)) ex <- .table_declarations(NULL, c("motif", "famille", "action"), "exclusions")
  if (is.null(hy)) hy <- .table_declarations(NULL, c("motif", "referentiel", "poste", "valeur"), "hypotheses")
  ecarts <- list()
  exclusions <- list()
  hypotheses <- list()
  requises <- list()
  inconnues <- list()
  signales <- rep(FALSE, length(constats))
  ajouter <- function(liste, x) { liste[[length(liste) + 1L]] <- x; liste }
  # constats à placer : ceux du bilan, puis les défauts de manquant enchaînés à D02a sous H
  # (ajoutés en fin de file ; jamais signalés)
  a_placer <- constats
  n <- 0L
  while (n < length(a_placer)) {
    n <- n + 1L
    k <- a_placer[[n]]
    t <- eclater_champ(k$traitement)
    base_ecart <- list(table = k$table, colonne = k$colonne, motif = k$code)
    if (identical(t, "R")) {
      if (!(k$code %in% .CODES_INDUITS)) {
        ecarts <- ajouter(ecarts, c(base_ecart, list(famille = "ensemble", action = "refus", lignes = k$lignes)))
      }
      next
    }
    if (identical(t, "S")) next
    lignes <- k$lignes
    if (k$code %in% c("D04a", "D04b")) lignes <- lignes[!(.connus(ctx, k$table)[lignes] %in% FALSE)]
    familles <- if ("X" %in% t) .familles_x(ctx$dico, k$code) else character(0)
    e_k <- ex[ex$motif == k$code & ex$famille %in% familles, , drop = FALSE]
    h_k <- hy[hy$motif == k$code, , drop = FALSE]
    s_k <- if ("S" %in% t) h_k[h_k$valeur == .VALEUR_SIGNALEMENT, , drop = FALSE] else h_k[0L, ]
    h_k <- if ("H" %in% t) h_k[h_k$valeur != .VALEUR_SIGNALEMENT, , drop = FALSE] else h_k[0L, ]
    axe_r <- "H" %in% t || "S" %in% t
    regle_p <- k$code %in% .MOTIFS_REGLE_P
    if (k$code == "D03g") {
      application <- .application_d03g(ctx, k$table, if (identical(k$colonne, "date_saisie_fin")) k$colonne else NA_character_)
      x_ok <- identical(application, "X")
      r_ok <- identical(application, "H")
    } else {
      x_ok <- length(familles) > 0L && all(familles %in% e_k$famille)
      r_ok <- axe_r && all(REFERENTIELS %in% c(h_k$referentiel, s_k$referentiel))
    }
    familles_declarees <- e_k$famille
    referentiels_declares <- c(h_k$referentiel, s_k$referentiel)
    # D12 : l'exclusion porte sur le sinistre de l'événement, avec la cascade du dictionnaire,
    # § 1.10 (spécification `donnees` v1.6, § 8.8 : X par sinistre) ; l'écart de l'enjeu reste sur
    # l'événement (événement de niveau sinistre : dossiers du sinistre, § 4.4)
    table_x <- k$table
    lignes_x <- lignes
    if (k$code == "D12") {
      table_x <- "sinistres"
      lignes_x <- which(!is.na(apparier_cles(.valeurs(ctx, "sinistres", "id_sinistre"),
                                             .valeurs(ctx, "evenements", "id_sinistre")[lignes])))
    }
    # une déclaration de la règle P qui n'est pas appliquée à la vue n'est pas placée ; un
    # constat couvert n'est placé que sur un axe (un motif à traitement unique n'est jamais
    # déclaré sur les deux, D8 ; ailleurs, l'exclusion l'emporte, dont D03g, D11)
    if (regle_p && !x_ok) e_k <- e_k[0L, ]
    if (regle_p && !r_ok) { h_k <- h_k[0L, ]; s_k <- s_k[0L, ] }
    if (x_ok) { h_k <- h_k[0L, ]; s_k <- s_k[0L, ] }
    if (r_ok && !x_ok) e_k <- e_k[0L, ]
    for (f in familles) {
      action <- e_k$action[e_k$famille == f]
      if (length(action) == 1L) {
        exclusions <- ajouter(exclusions, list(motif = k$code, famille = f, action = action, table = table_x, lignes = lignes_x))
        ecarts <- ajouter(ecarts, c(base_ecart, list(famille = f, action = action, lignes = lignes)))
      } else if (!x_ok && !r_ok) {
        if (!(f %in% familles_declarees)) {
          requises <- ajouter(requises, list(rubrique = "exclusions", motif = k$code, cle = f,
                                             traitements_admis = k$traitement, table = k$table, lignes = lignes))
        }
        ecarts <- ajouter(ecarts, c(base_ecart, list(famille = f, action = "non_declaree", lignes = lignes)))
      }
    }
    # hypothèse de D03g appliquée : les lignes dont la date ne se calcule pas restent de
    # visibilité non déterminée, hors de l'hypothèse placée ; celles qui ne se calculent pas
    # par elles-mêmes attendent l'exclusion (Q5), non celles qui suivent leur parente (Q2 (b))
    lignes_h <- lignes
    if (k$code == "D03g" && r_ok && !identical(k$colonne, "date_saisie_fin")) {
      reste <- intersect(lignes, ctx$reste_g[[k$table]])
      lignes_h <- setdiff(lignes, c(reste, ctx$parente_g[[k$table]]))
      for (f in familles) {
        if (length(reste) > 0L) {
          requises <- ajouter(requises, list(rubrique = "exclusions", motif = k$code, cle = f, traitements_admis = "X",
                                             table = k$table, lignes = reste))
        }
      }
      if (length(lignes_h) == 0L) h_k <- h_k[0L, ]
    }
    colonnes_h <- if (k$code == "D02a") .DATES_D02A[[k$table]][[k$colonne]] else k$colonne
    for (i in seq_len(nrow(h_k))) {
      hypotheses <- ajouter(hypotheses, list(motif = k$code, referentiel = h_k$referentiel[i], poste = h_k$poste[i],
                                             valeur = h_k$valeur[i], table = k$table, lignes = lignes_h,
                                             colonnes = colonnes_h))
    }
    if (k$code == "D02a" && nrow(h_k) > 0L) {
      d02a <- .inconnues_d02a(ctx, k)
      inconnues <- c(inconnues, d02a$inconnues)
      a_placer <- c(a_placer, d02a$enchaines)
    }
    if (nrow(s_k) > 0L && n <= length(constats)) signales[n] <- TRUE
    if (axe_r && !x_ok && !r_ok) {
      for (r in setdiff(REFERENTIELS, referentiels_declares)) {
        requises <- ajouter(requises, list(rubrique = "hypotheses", motif = k$code, cle = r, traitements_admis = k$traitement,
                                           table = k$table, lignes = lignes))
      }
    }
    # délai de D03g : lu par l'application de l'hypothèse, tant que l'exclusion ne couvre pas
    if (k$code == "D03g" && !x_ok && is.null(ctx$declarations$seuils[[SEUIL_DELAI_D03G]][[k$table]])) {
      requises <- ajouter(requises, list(rubrique = "seuils", motif = k$code, cle = paste0(SEUIL_DELAI_D03G, "$", k$table),
                                         traitements_admis = NA_character_, table = k$table, lignes = lignes))
    }
  }
  list(exclusions = exclusions, hypotheses = hypotheses, requises = requises, ecarts = ecarts, signales = signales,
       inconnues = inconnues)
}

# Agrège des lignes brutes de placement par les colonnes `cles` : une ligne par clé, avec le
# nombre de lignes distinctes (table, ligne) et, si `dossiers`, le nombre de dossiers
# rattachés à l'arrêté (.nombre_dossiers_union() ; variante `d03g` pour le motif D03g).
.agreger_placement <- function(ctx, brut, cles, nom_nombre, dossiers = FALSE) {
  colonnes <- stats::setNames(rep(list(character(0)), length(cles)), cles)
  if (length(brut) == 0L) {
    df <- as.data.frame(colonnes, stringsAsFactors = FALSE)
    df[[nom_nombre]] <- integer(0)
    if (dossiers) df$nombre_dossiers <- integer(0)
    return(df)
  }
  cle <- vapply(brut, function(x) paste(unlist(x[cles]), collapse = "\r"), "")
  groupes <- split(brut, factor(cle, levels = unique(cle)))
  df <- as.data.frame(lapply(stats::setNames(cles, cles), function(c1) vapply(groupes, function(g) g[[1L]][[c1]], "",
                                                                                USE.NAMES = FALSE)),
                      stringsAsFactors = FALSE)
  # lignes NULL : déclaration attendue hors constat (.requerir()), nombre NA
  df[[nom_nombre]] <- vapply(groupes, function(g) {
    if (all(vapply(g, function(x) is.null(x$lignes), NA))) return(NA_integer_)
    length(unique(unlist(lapply(g, function(x) if (length(x$lignes)) paste(x$table, x$lignes)))))
  }, 0L, USE.NAMES = FALSE)
  if (dossiers) {
    df$nombre_dossiers <- vapply(groupes, function(g) {
      parts <- lapply(g, function(x) list(table = x$table, lignes = x$lignes, d03g = identical(x$motif, "D03g")))
      .nombre_dossiers_union(ctx, parts)
    }, 0L, USE.NAMES = FALSE)
  }
  df
}

# Disjonction de Kleene par clé : pour chaque élément, TRUE si une valeur de sa clé est vraie,
# sinon NA si l'une est inconnue, sinon FALSE (même longueur que `cle`).
.ou_kleene <- function(cle, x) ifelse(cle %in% cle[x %in% TRUE], TRUE, ifelse(cle %in% cle[is.na(x)], NA, FALSE))

# Statut de rattachement à l'arrêté des dossiers que .rattacher() rattache aux lignes `lignes`
# de `table` (spécification v1.5, § 4.4 ; M219, lecture (ii)), seule implémentation, lue par
# les comptes de dossiers (.nombre_dossiers_union()) et par les montants des composantes 1 à
# 4 (.enjeu_elementaire()) : s(d) = statut(d) ET (OU, sur les lignes rattachées à d, de leur
# statut), en logique de Kleene, sur l'évaluation unique de la visibilité (.connus() ; variante
# `d03g` pour un écart de D03g, pour la ligne comme pour le dossier ; pour dossiers, la ligne
# est le dossier). Rend data.frame(dossier, statut), un dossier par ligne, trié : TRUE
# rattaché à l'arrêté, FALSE non rattaché, NA rattachement non déterminé. Le rattachement
# illisible par sa forme (r$cause) est traité par l'appelant.
.statut_rattachement <- function(ctx, table, lignes, d03g = FALSE) {
  p <- .rattacher(ctx, table)$paires
  p <- p[p$ligne %in% lignes, , drop = FALSE]
  # paire de rattachement non déterminé (`sur` NA, .rattacher()) : ET de Kleene avec la visibilité
  ou <- .ou_kleene(p$dossier, .connus(ctx, table, d03g)[p$ligne] & p$sur)
  garde <- !duplicated(p$dossier)
  d <- p$dossier[garde]
  o <- order(d, method = "radix")
  d <- d[o]
  data.frame(dossier = d, statut = .connus(ctx, "dossiers", d03g)[d] & ou[garde][o])
}

# Dossiers distincts rattachés à l'arrêté pour plusieurs (table, lignes, d03g)
# (.statut_rattachement() ; spécification v1.5, § 4.4) : disjonction de Kleene des statuts
# d'un dossier entre les parties ; NA si l'un des rattachements est illisible par sa forme ou
# si un dossier est de rattachement non déterminé ; 0 sans dossier rattaché.
.nombre_dossiers_union <- function(ctx, parts) {
  s <- list()
  for (x in parts) {
    if (!is.null(.rattacher(ctx, x$table)$cause)) return(NA_integer_)
    s[[length(s) + 1L]] <- .statut_rattachement(ctx, x$table, x$lignes, isTRUE(x$d03g))
  }
  s <- do.call(rbind, s)
  if (is.null(s) || nrow(s) == 0L) return(0L)
  u <- .ou_kleene(s$dossier, s$statut)[!duplicated(s$dossier)]
  if (anyNA(u)) NA_integer_ else sum(u)
}

# Niveau élémentaire de l'enjeu (spécification, § 4.5, point 1 ; ADR 0010, sixième série,
# (c) 1) : seule fonction qui l'établit, interne à `donnees` (réemployée en B2 pour
# l'agrégation par poste). Pour chaque écart (.placer()), rend `elements` (une ligne par
# porteur et composante : `porteur` (dossiers ou table de la ligne), `indice` (NA : élément
# sans porteur, qui porte la cause d'une composante empêchée dans toute rangée où elle
# figure, réserve Q10), `garantie`, `connu`, `composante`, `unite`, `valeur` (NA : aucune
# valeur), `cause` (motif d'un refus ou forme illisible, .causes_enjeu() ; ou
# `visibilite_non_determinee` pour un porteur dont la visibilité, ou celle d'une ligne qui
# entre dans sa valeur, n'est pas déterminée, réserve Q8 (b) ; `D01a` pour un porteur
# touché par un identifiant de l'écart D01a dont les doubles divergent sur une colonne lue,
# D10), `cause_table`, `cause_colonne`), `dossiers` (dossiers rattachés à l'arrêté ou de
# rattachement non déterminé, .statut_rattachement() : `dossier`, `garantie`, `connu` (statut
# de rattachement : TRUE ou NA), `famille` : famille de composantes pour laquelle le dossier
# est compté), `familles_cause` (familles dont le rattachement est illisible) et `familles`
# (dossier, evenement, prestation, cotisation : composantes que la table de l'écart porte,
# § 4.4). Un écart de D03g lit la visibilité de ses lignes par la variante `d03g` de
# .connus() (réserves Q4, Q8).
.TABLES_DOSSIER <- c("adherents", "contrats", "garanties_souscrites", "parametres", "assures", "affiliations",
                     "famille", "sinistres", "dossiers", "beneficiaires", "rentes", "evenements", "catastrophes",
                     "victimes")
# Famille de composantes de chaque couple de COMPOSANTES_ENJEU (§ 4.4) ; cause d'un porteur
# de visibilité non déterminée.
.FAMILLE_COUPLE <- c(rep("dossier", 4L), "prestation", "cotisation", "cotisation", rep("evenement", 3L))
.CAUSE_VISIBILITE <- "visibilite_non_determinee"
# Colonne de visibilité que les composantes 2 à 4 lisent aussi comme valeur : départage des
# derniers événements par la date de saisie (spécification, § 4.2, point 3 ; .causes_enjeu() ;
# paiements_cumules ne la lit pas).
.LUS_VALEUR_ENJEU <- "evenements.date_saisie"
# Colonnes lues par la composante portée par une ligne de evenements (montant_evenement),
# prestations (prestations_ecartees) ou cotisations (composantes 6 et 7).
.LUS_LIGNE_ENJEU <- list(evenements = c("montant", "type_evenement", "date_saisie", "id_rente", "id_dossier"),
                         prestations = c("montant", "date_saisie", "date_reglement", "id_dossier"),
                         cotisations = c("montant", "nature_mouvement", "date_mouvement", "id_garantie_souscrite"))
.enjeu_elementaire <- function(ctx, ecart) {
  v <- function(t, c1) .valeurs(ctx, t, c1)
  table <- ecart$table
  lignes <- ecart$lignes
  # écart de D03g : visibilité de ses lignes bornée par la date que compare D02b (réserves Q4
  # et Q8, .connus())
  d03g <- identical(ecart$motif, "D03g")
  elements <- list()
  ajouter <- function(porteur, indice, garantie, connu, composante, unite, valeur, cause = NA_character_,
                      cause_table = NA_character_, cause_colonne = NA_character_) {
    n <- length(indice)
    if (n == 0L) return(invisible(NULL))
    elements[[length(elements) + 1L]] <<- data.frame(
      porteur = rep(porteur, n), indice = indice, garantie = garantie, connu = connu,
      composante = rep(composante, n), unite = rep(unite, n), valeur = valeur, cause = rep_len(cause, n),
      cause_table = rep_len(cause_table, n), cause_colonne = rep_len(cause_colonne, n), stringsAsFactors = FALSE)
  }
  # composante empêchée : un élément sans porteur porte la cause
  empecher <- function(porteur, composante, unite, cz) {
    ajouter(porteur, NA_integer_, "non_rattache", NA, composante, unite, NA_real_, cz[["cause"]], cz[["table"]],
            cz[["colonne"]])
  }
  # cause qui empêche la composante : la plus petite, dans l'ordre (rang, position), des
  # causes éligibles de toutes les colonnes lues (.causes_enjeu()) ; table et colonne publiées :
  # la première colonne qui la porte dans l'ordre du dictionnaire (.cause_colonnes() ; une
  # cause directe d'une colonne prime sur le refus induit d'une autre, M185 : rang 3 contre 7 ;
  # spécification `donnees` v1.7, § 3.1, « Cause d'une composante de l'enjeu », #122)
  cause_de <- function(lus, valeur = character(0)) {
    lus <- unique(lus)
    .cause_colonnes(ctx, lus, lapply(lus, function(tc) {
      m <- strsplit(tc, ".", fixed = TRUE)[[1L]]
      .causes_enjeu(ctx, m[1L], m[2L], ecart, tc %in% valeur)
    }))
  }
  familles <- character(0)
  familles_cause <- character(0)
  dossiers <- data.frame(dossier = integer(0), garantie = character(0), connu = logical(0), famille = character(0),
                         stringsAsFactors = FALSE)
  cause_rattachement <- NULL
  lien_g <- FALSE
  # dossiers dont le code de garantie est refusé de portée ligne (#72) : garantie inconnue
  g_refus <- integer(0)
  if (table %in% c(.TABLES_DOSSIER, "prestations")) {
    r <- .rattacher(ctx, table)
    cause_rattachement <- r$cause
    tags <- if (table == "prestations") "prestation" else c("dossier", if (table == "evenements") "evenement")
    if (!is.null(r$cause)) familles_cause <- tags
    if (is.null(r$cause) && !is.null(ctx$base$dossiers)) {
      cd <- .composantes_dossiers(ctx, d03g)
      # statut de rattachement à l'arrêté (§ 4.4, M219) : un dossier non rattaché n'entre pas
      # dans l'écart ; de rattachement non déterminé, il est un porteur de visibilité non
      # déterminée (connu NA)
      st <- .statut_rattachement(ctx, table, lignes, d03g)
      st <- st[!(st$statut %in% FALSE), , drop = FALSE]
      d <- st$dossier
      # garantie lue sur la clé étrangère refusée de l'écart (D10 (a), D04b) : lien non résolu,
      # dossier non rattaché (réserve Q4)
      lien_g <- identical(ecart$action, "refus") && ecart$motif %in% .MOTIFS_LIEN_ECART &&
        paste(ecart$table, ecart$colonne, sep = ".") %in% cd$lus_g
      garantie <- if (is.null(cause_de(cd$lus_g)) && !lien_g) cd$garantie[d] else rep("non_rattache", length(d))
      # code de garantie refusé de portée ligne (spécification `donnees` v1.9, § 9.2, #72) : la
      # garantie du dossier est inconnue, non_rattache ; ses composantes 2 à 4 sont sans valeur
      if (!lien_g) {
        g_refus <- .refus_ligne_porteurs(ctx, .refus_ligne_lus(ctx, cd$lus_g),
                                         .rattacher_composante(ctx, "garantie", d03g))$porteur
        garantie[d %in% g_refus] <- "non_rattache"
      }
      # écart D01a de dossiers : un dossier dont les doubles divergent sur une colonne de dossiers
      # que lit sa garantie (id_garantie_souscrite) est non_rattache, et non la garantie de
      # l'occurrence retenue (spécification `donnees` v1.7, § 2.2, B.4, lignes de l'écart D01a, #131)
      if (table == "dossiers" && identical(ecart$action, "refus") && identical(ecart$motif, "D01a")) {
        for (c1 in sub("^dossiers\\.", "", cd$lus_g[startsWith(cd$lus_g, "dossiers.")])) {
          garantie[d %in% .divergences_d01a(ctx, "dossiers", lignes, c1)] <- "non_rattache"
        }
      }
      dossiers <- do.call(rbind, lapply(tags, function(f) {
        data.frame(dossier = d, garantie = garantie, connu = st$statut, famille = rep(f, length(d)), stringsAsFactors = FALSE)
      }))
    }
  }
  if (table %in% .TABLES_DOSSIER) {
    familles <- "dossier"
    if (!is.null(cause_rattachement)) {
      for (k in 1:4) empecher("dossiers", COMPOSANTES_ENJEU$composante[k], COMPOSANTES_ENJEU$unite[k], cause_rattachement)
    } else if (!is.null(ctx$base$dossiers)) {
      cd <- .composantes_dossiers(ctx, d03g)
      dd <- dossiers[dossiers$famille == "dossier", , drop = FALSE]
      applicable <- list(paiements_cumules = rep(TRUE, nrow(dd)),
                         capital_fixe = dd$garantie %in% .GARANTIES_CAPITAL,
                         rente_annuelle_en_vigueur = dd$garantie %in% .GARANTIES_RENTE,
                         ij_en_vigueur = dd$garantie %in% "incapacite")
      # lien de la garantie non résolu (réserve Q5 d'`actuary`) : les composantes 2 à 4 sont
      # applicables à chaque dossier et prennent les valeurs brutes de ses événements, qui ne
      # demandent pas la garantie (aucune valeur sans événement du type)
      valeurs_k <- cd$valeurs
      lus_k <- cd$lus
      if (lien_g) {
        applicable <- lapply(applicable, function(a) rep(TRUE, length(a)))
        valeurs_k <- cd$brutes
        lus_k <- cd$lus_brut
      }
      for (k in 1:4) {
        composante <- COMPOSANTES_ENJEU$composante[k]
        cz <- cause_de(lus_k[[composante]], .LUS_VALEUR_ENJEU)
        if (!is.null(cz)) {
          empecher("dossiers", composante, COMPOSANTES_ENJEU$unite[k], cz)
          next
        }
        # dossier qui lit une ligne refusée de portée ligne : sans valeur, cause le motif du refus
        # (#72) ; une garantie inconnue par son code refusé peut porter les composantes 2 à 4
        s <- applicable[[composante]]
        if (k > 1L) s <- s | dd$dossier %in% g_refus
        i <- dd$dossier[s]
        indet <- is.na(dd$connu[s]) | cd$indetermine[[composante]][i]
        rl <- .refus_ligne_porteurs(ctx, .refus_ligne_lus(ctx, lus_k[[composante]], .LUS_VALEUR_ENJEU),
                                    .rattacher_composante(ctx, composante, d03g))
        j <- match(i, rl$porteur)
        r <- !is.na(j)
        valeur <- valeurs_k[[composante]][i]
        valeur[r] <- NA_real_
        ajouter("dossiers", i, dd$garantie[s], dd$connu[s], composante, COMPOSANTES_ENJEU$unite[k], valeur,
                ifelse(r, rl$cause[j], ifelse(indet, .CAUSE_VISIBILITE, NA_character_)),
                ifelse(r, rl$table[j], ifelse(indet, "dossiers", NA_character_)), rl$colonne[j])
      }
    }
  }
  lus_gd <- c("dossiers.id_dossier", "dossiers.id_garantie_souscrite", "garanties_souscrites.id_garantie_souscrite",
              "garanties_souscrites.code_garantie")
  cause_gd <- cause_de(lus_gd)
  # garanties souscrites de code refusé de portée ligne (#72) : garantie inconnue, non_rattache
  gs_refus <- .valeurs(ctx, "garanties_souscrites", "id_garantie_souscrite")[
    .refus_ligne_lus(ctx, "garanties_souscrites.code_garantie")$ligne]
  garantie_dossier <- function(id) {
    if (!is.null(cause_gd) || !is.null(.cause_lecture(ctx, lus_gd, forme_seule = TRUE))) return(rep("non_rattache", length(id)))
    gs <- .joindre(ctx, "dossiers", "id_dossier", "id_garantie_souscrite", id)
    g <- .joindre(ctx, "garanties_souscrites", "id_garantie_souscrite", "code_garantie", gs)
    g[!is.na(apparier_cles(gs, gs_refus))] <- NA
    ifelse(is.na(g), "non_rattache", g)
  }
  # porteur ligne (evenements, prestations, cotisations) qui lit une valeur refusée de portée
  # ligne de sa propre ligne : sans valeur, cause le motif du refus (#72)
  refus_ligne <- function(t) .refus_ligne_porteurs(ctx, .refus_ligne_lus(ctx, paste(t, .LUS_LIGNE_ENJEU[[t]], sep = ".")),
                                                   function(u, l) data.frame(ligne = l, porteur = l))
  connus <- .connus(ctx, table, d03g)
  vus <- lignes[connus[lignes] %in% TRUE]
  indet <- lignes[is.na(connus[lignes])]
  if (table == "evenements") {
    familles <- c(familles, "evenement")
    cause <- cause_de(paste0("evenements.", .LUS_LIGNE_ENJEU$evenements))
    if (!is.null(cause)) {
      for (k in 8:10) empecher("evenements", "montant_evenement", COMPOSANTES_ENJEU$unite[k], cause)
    } else {
      # unité de l'événement, lue sur l'événement seul (dictionnaire, :490 et :606 ; réserve
      # Q11) : euro (fixation_capital), euro_par_an (service d'une rente : id_rente renseigné),
      # euro_par_jour (service d'un dossier incapacite : id_rente manquant) ; la garantie ne sert
      # qu'à la rangée par garantie (non_rattache si elle est illisible ou refusée)
      unite_de <- function(l) {
        type <- v("evenements", "type_evenement")[l]
        g <- garantie_dossier(v("evenements", "id_dossier")[l])
        unite <- ifelse(type %in% "fixation_capital", "euro",
                 ifelse(type %in% c("ouverture_service", "modification_montant"),
                        ifelse(!is.na(.cle_manquante(v("evenements", "id_rente")[l])), "euro_par_an", "euro_par_jour"),
                        NA_character_))
        list(g = g, unite = unite)
      }
      x <- unite_de(vus)
      montant <- v("evenements", "montant")[vus]
      rl <- refus_ligne("evenements")
      # ligne refusée de portée ligne (#72) : sans valeur dans son unité ; de type refusé, son
      # unité est inconnue : sans valeur dans chacune
      type_i <- .inconnu(ctx, "evenements", "type_evenement")
      jv <- match(vus, rl$porteur)
      s <- !is.na(x$unite) & !is.na(montant) & is.na(jv)
      y <- unite_de(indet)
      ji <- match(indet, rl$porteur)
      si <- !is.na(y$unite) & !is.na(v("evenements", "montant")[indet]) & is.na(ji)
      for (k in 8:10) {
        u <- COMPOSANTES_ENJEU$unite[k]
        su <- s & x$unite == u
        ajouter("evenements", vus[su], x$g[su], rep(TRUE, sum(su)), "montant_evenement", u, montant[su])
        sr <- !is.na(jv) & ((x$unite == u) %in% TRUE | type_i[vus])
        ajouter("evenements", vus[sr], x$g[sr], rep(TRUE, sum(sr)), "montant_evenement", u, rep(NA_real_, sum(sr)),
                rl$cause[jv[sr]], rl$table[jv[sr]], rl$colonne[jv[sr]])
        si_u <- si & y$unite == u
        ajouter("evenements", indet[si_u], y$g[si_u], rep(NA, sum(si_u)), "montant_evenement", u, rep(NA_real_, sum(si_u)),
                .CAUSE_VISIBILITE, "evenements")
        sr <- !is.na(ji) & ((y$unite == u) %in% TRUE | type_i[indet])
        ajouter("evenements", indet[sr], y$g[sr], rep(NA, sum(sr)), "montant_evenement", u, rep(NA_real_, sum(sr)),
                rl$cause[ji[sr]], rl$table[ji[sr]], rl$colonne[ji[sr]])
      }
    }
  }
  if (table == "prestations") {
    familles <- "prestation"
    cause <- cause_de(paste0("prestations.", .LUS_LIGNE_ENJEU$prestations))
    if (!is.null(cause)) {
      empecher("prestations", "prestations_ecartees", "euro", cause)
    } else {
      rl <- refus_ligne("prestations")
      jv <- match(vus, rl$porteur)
      montant <- v("prestations", "montant")[vus]
      montant[!is.na(jv)] <- NA_real_
      ajouter("prestations", vus, garantie_dossier(v("prestations", "id_dossier")[vus]), rep(TRUE, length(vus)),
              "prestations_ecartees", "euro", montant, rl$cause[jv], rl$table[jv], rl$colonne[jv])
      ji <- match(indet, rl$porteur)
      ajouter("prestations", indet, garantie_dossier(v("prestations", "id_dossier")[indet]), rep(NA, length(indet)),
              "prestations_ecartees", "euro", rep(NA_real_, length(indet)),
              ifelse(is.na(ji), .CAUSE_VISIBILITE, rl$cause[ji]), ifelse(is.na(ji), "prestations", rl$table[ji]), rl$colonne[ji])
    }
  }
  if (table == "cotisations") {
    familles <- "cotisation"
    cause <- cause_de(paste0("cotisations.", .LUS_LIGNE_ENJEU$cotisations))
    lus_gc <- c("garanties_souscrites.id_garantie_souscrite", "garanties_souscrites.code_garantie")
    garantie_cotisation <- function(l) {
      if (!is.null(cause_de(lus_gc)) || !is.null(.cause_lecture(ctx, lus_gc, forme_seule = TRUE))) {
        return(rep("non_rattache", length(l)))
      }
      gs <- v("cotisations", "id_garantie_souscrite")[l]
      g <- .joindre(ctx, "garanties_souscrites", "id_garantie_souscrite", "code_garantie", gs)
      g[!is.na(apparier_cles(gs, gs_refus))] <- NA
      ifelse(is.na(g), "non_rattache", g)
    }
    rl <- if (is.null(cause)) refus_ligne("cotisations")
    # nature refusée de portée ligne (#72) : composante inconnue, sans valeur dans chacune
    nature_i <- .inconnu(ctx, "cotisations", "nature_mouvement")
    for (k in 6:7) {
      composante <- COMPOSANTES_ENJEU$composante[k]
      if (!is.null(cause)) {
        empecher("cotisations", composante, "euro", cause)
        next
      }
      natures <- if (k == 6L) c("emission", "annulation", "regularisation") else "encaissement"
      s <- vus[v("cotisations", "nature_mouvement")[vus] %in% natures | (nature_i[vus] & vus %in% rl$porteur)]
      js <- match(s, rl$porteur)
      montant <- v("cotisations", "montant")[s]
      montant[!is.na(js)] <- NA_real_
      ajouter("cotisations", s, garantie_cotisation(s), rep(TRUE, length(s)), composante, "euro", montant,
              rl$cause[js], rl$table[js], rl$colonne[js])
      si <- indet[v("cotisations", "nature_mouvement")[indet] %in% natures | (nature_i[indet] & indet %in% rl$porteur)]
      ji <- match(si, rl$porteur)
      ajouter("cotisations", si, garantie_cotisation(si), rep(NA, length(si)), composante, "euro", rep(NA_real_, length(si)),
              ifelse(is.na(ji), .CAUSE_VISIBILITE, rl$cause[ji]), ifelse(is.na(ji), "cotisations", rl$table[ji]), rl$colonne[ji])
    }
  }
  el <- if (length(elements)) do.call(rbind, elements) else NULL
  # D01a de l'écart (D10) : un porteur est sans valeur, cause D01a, pour une composante dont
  # une colonne lue diverge entre les lignes en double d'un identifiant qui le touche ; un
  # dossier ainsi touché porte la cause aussi pour une composante qu'il ne porte pas (sa
  # garantie, lue sur une colonne divergente, n'est pas déterminée) ; colonnes parcourues dans
  # l'ordre du dictionnaire : la colonne d'un élément est la première colonne divergente dans cet
  # ordre, quel que soit l'ordre de `lus` (spécification `donnees` v1.7, § 3.1, #122)
  if (identical(ecart$action, "refus") && identical(ecart$motif, "D01a") && length(familles) > 0L) {
    marquer <- function(porteur, composante, unite, lus, touches_de) {
      lus <- unique(lus[startsWith(lus, paste0(table, "."))])
      lus_t <- sub("^[^.]*\\.", "", lus[.ordre_dictionnaire(ctx$dico, lus)])
      sans_porteur <- FALSE
      for (c1 in lus_t) {
        rangs <- .divergences_d01a(ctx, table, lignes, c1)
        if (length(rangs) == 0L) next
        touches <- touches_de(rangs)
        sel <- if (is.null(el)) logical(0) else el$porteur == porteur & el$composante == composante & el$unite == unite &
          el$indice %in% touches & is.na(el$cause)
        if (any(sel)) {
          el$cause[sel] <<- "D01a"
          el$cause_table[sel] <<- table
          el$cause_colonne[sel] <<- c1
        }
        porte <- if (is.null(el)) integer(0) else el$indice[el$porteur == porteur & el$composante == composante & el$unite == unite]
        manque <- setdiff(touches, porte)
        if (porteur == "dossiers" && length(manque) > 0L) {
          dd <- dossiers[dossiers$famille == "dossier", , drop = FALSE]
          el <<- rbind(el, data.frame(porteur = porteur, indice = manque, garantie = dd$garantie[match(manque, dd$dossier)],
                                      connu = dd$connu[match(manque, dd$dossier)], composante = composante, unite = unite,
                                      valeur = NA_real_, cause = "D01a", cause_table = table, cause_colonne = c1,
                                      stringsAsFactors = FALSE))
        }
        # ligne de l'écart sans élément pour ce couple alors qu'une colonne qui le classe
        # diverge (type, rente, nature, montant d'un événement) : couple empêché pour toute
        # garantie, par un seul élément sans porteur, de la première de ces colonnes dans l'ordre
        # du dictionnaire (spécification `donnees` v1.7, § 3.1, #122 ; alternative A2, une ligne
        # par colonne, écartée)
        manque <- intersect(manque, lignes[!(connus[lignes] %in% FALSE)])
        if (porteur != "dossiers" && !sans_porteur && length(manque) > 0L && c1 %in% .CLASSE_D01A[[porteur]]) {
          sans_porteur <- TRUE
          el <<- rbind(el, data.frame(porteur = porteur, indice = NA_integer_, garantie = "non_rattache", connu = NA,
                                      composante = composante, unite = unite, valeur = NA_real_, cause = "D01a",
                                      cause_table = table, cause_colonne = c1, stringsAsFactors = FALSE))
        }
      }
    }
    if ("dossier" %in% familles && is.null(cause_rattachement) && !is.null(ctx$base$dossiers)) {
      cd <- .composantes_dossiers(ctx, d03g)
      paires <- .rattacher(ctx, table)$paires
      touches_d <- function(rangs) intersect(paires$dossier[paires$ligne %in% rangs], dossiers$dossier[dossiers$famille == "dossier"])
      for (k in 1:4) marquer("dossiers", COMPOSANTES_ENJEU$composante[k], COMPOSANTES_ENJEU$unite[k],
                             cd$lus[[COMPOSANTES_ENJEU$composante[k]]], touches_d)
    }
    if (table %in% names(.LUS_LIGNE_ENJEU)) {
      famille_t <- c(prestations = "prestation", cotisations = "cotisation", evenements = "evenement")[[table]]
      for (k in which(.FAMILLE_COUPLE == famille_t)) {
        marquer(table, COMPOSANTES_ENJEU$composante[k], COMPOSANTES_ENJEU$unite[k], paste(table, .LUS_LIGNE_ENJEU[[table]], sep = "."),
                function(rangs) rangs)
      }
    }
  }
  list(elements = el, dossiers = dossiers, familles_cause = familles_cause, familles = familles)
}

# Colonnes qui rangent une ligne de evenements, prestations ou cotisations dans un couple
# (composante, unite) (.enjeu_elementaire(), D01a de l'écart).
.CLASSE_D01A <- list(evenements = c("type_evenement", "id_rente", "montant"), prestations = character(0),
                     cotisations = "nature_mouvement")

# Lignes de `table` dont l'identifiant (clé primaire), doublé par les lignes `lignes` d'un
# écart D01a, porte des valeurs différentes de `colonne` entre ses lignes en double (D10) ;
# integer(0) si toutes concordent (doublons à l'identique : chiffrés). Identifiants regroupés
# à l'égalité exacte de chaque colonne de clé, comme D01a (.code_groupe(), sans paste() : un
# « NA » littéral ne se confond pas avec l'absence, #121) ; une ligne de composante vide ou
# manquante par refus n'est pas de l'écart D01a (#143) : l'écart ne la donne jamais dans `lignes`.
.divergences_d01a <- function(ctx, table, lignes, colonne) {
  cle <- eclater_champ(ctx$dico$tables$cle_primaire[ctx$dico$tables$table == table])
  if (colonne %in% cle) return(integer(0))
  k <- .code_groupe(lapply(cle, function(c1) .valeurs(ctx, table, c1)))
  grp <- which(k %in% k[lignes])
  if (length(grp) == 0L) return(integer(0))
  x <- .valeurs(ctx, table, colonne)[grp]
  diverge <- tapply(seq_along(grp), k[grp], function(i) length(unique(x[i])) > 1L)
  grp[k[grp] %in% as.integer(names(diverge)[diverge])]
}

# Rangées de l'enjeu d'un groupe d'éléments (spécification, § 4.5) : une ligne par garantie
# présente et pour la garantie `ensemble`, et par couple (composante, unite) que portent les
# familles de composantes du groupe (pour une garantie, celles qui y ont un dossier ou une
# ligne) ; montant sommé sur les porteurs distincts connus qui ont une valeur (en ordre trié,
# indépendant de l'ordre des lignes ; jamais arrondi), NA si une cause empêche la composante
# (la plus petite cause de refus des éléments dans l'ordre (rang, position), .cause_retenue(),
# indépendante de l'ordre des éléments et des écarts, spécification `donnees` v1.7, § 3.1,
# #122 ; sinon la visibilité non déterminée) ; nombre_dossiers :
# dossiers distincts comptés pour la famille de composantes du couple (réserve M3 : un dossier
# rattaché par une prestation écartée n'est compté que pour prestations_ecartees), NA si le
# rattachement est illisible ou un dossier de rattachement non déterminé (§ 4.4) ;
# nombre_valeurs : porteurs qui portent une valeur. Un élément sans porteur (indice NA) empêche
# la composante pour toute garantie. Groupe de plusieurs écarts (rangée motif = ensemble) : le
# statut de rattachement d'un dossier y est la disjonction de Kleene de ses statuts dans les
# écarts (§ 4.4, M219) ; un dossier rattaché par un écart n'est plus porteur de visibilité non
# déterminée par le rattachement non déterminé d'un autre (ses éléments de connu NA et de
# cause visibilite_non_determinee tombent ; une autre cause, D01a par exemple, demeure).
.rangees_enjeu <- function(elements, dossiers, familles_cause, familles, dico, ordre = .ordre_codes(dico)) {
  dossiers$connu <- .ou_kleene(paste(dossiers$dossier, dossiers$famille), dossiers$connu)
  dossiers <- dossiers[!duplicated(dossiers[, c("dossier", "famille")]), , drop = FALSE]
  if (!is.null(elements)) {
    rattache <- dossiers$dossier[dossiers$famille == "dossier" & dossiers$connu %in% TRUE]
    elements <- elements[!(elements$porteur == "dossiers" & !is.na(elements$indice) & is.na(elements$connu) &
                             elements$cause %in% .CAUSE_VISIBILITE & elements$indice %in% rattache), , drop = FALSE]
    elements <- elements[!duplicated(elements[, c("porteur", "indice", "composante", "unite", "cause")]), , drop = FALSE]
  }
  famille_el <- if (is.null(elements)) character(0) else
    .FAMILLE_COUPLE[match(paste(elements$composante, elements$unite), paste(COMPOSANTES_ENJEU$composante, COMPOSANTES_ENJEU$unite))]
  porte <- if (is.null(elements)) logical(0) else !is.na(elements$indice)
  garanties <- sort(unique(c(dossiers$garantie, if (!is.null(elements)) elements$garantie[porte])), method = "radix")
  lignes <- list()
  for (g in c(garanties, "ensemble")) {
    couples <- integer(0)
    for (f in intersect(c("dossier", "prestation", "cotisation", "evenement"), familles)) {
      present <- g == "ensemble" || any(dossiers$famille == f & dossiers$garantie == g) ||
        any(porte & famille_el == f & elements$garantie == g)
      if (!present) next
      if (f == "dossier") {
        # composantes 2 à 4 : garanties où elles s'appliquent, et non_rattache quand elle en porte
        # un élément calculé (lien de garantie non résolu, réserve Q5 ; un élément sans valeur
        # d'un doublon divergent, cause D01a, n'ouvre pas de rangée)
        porte_k <- function(k) {
          g == "non_rattache" && any(porte & elements$composante == COMPOSANTES_ENJEU$composante[k] &
                                       elements$garantie == g & (is.na(elements$cause) | elements$cause == .CAUSE_VISIBILITE))
        }
        couples <- c(couples, 1L, if (g %in% c(.GARANTIES_CAPITAL, "ensemble") || porte_k(2L)) 2L,
                     if (g %in% c(.GARANTIES_RENTE, "ensemble") || porte_k(3L)) 3L,
                     if (g %in% c("incapacite", "ensemble") || porte_k(4L)) 4L)
      }
      if (f == "prestation") couples <- c(couples, 5L)
      if (f == "cotisation") couples <- c(couples, 6L, 7L)
      if (f == "evenement") {
        presentes <- if (is.null(elements)) character(0) else
          unique(elements$unite[porte & elements$composante == "montant_evenement" & elements$garantie == g])
        couples <- c(couples, which(COMPOSANTES_ENJEU$composante == "montant_evenement" &
                                      (g == "ensemble" | COMPOSANTES_ENJEU$unite %in% presentes)))
      }
    }
    for (k in sort(unique(couples))) {
      f <- .FAMILLE_COUPLE[k]
      composante <- COMPOSANTES_ENJEU$composante[k]
      unite <- COMPOSANTES_ENJEU$unite[k]
      dg <- dossiers[dossiers$famille == f & (g == "ensemble" | dossiers$garantie == g), , drop = FALSE]
      nombre_dossiers <- if (f %in% familles_cause || anyNA(dg$connu)) NA_integer_ else sum(dg$connu)
      e <- if (is.null(elements)) elements else
        elements[elements$composante == composante & elements$unite == unite &
                   (g == "ensemble" | elements$garantie == g | is.na(elements$indice)), , drop = FALSE]
      causes <- if (is.null(e)) character(0) else e$cause[!is.na(e$cause)]
      if (length(causes) > 0L) {
        montant <- NA_real_
        nombre_valeurs <- NA_integer_
        refus <- causes[causes != .CAUSE_VISIBILITE]
        cause <- if (length(refus)) .cause_retenue(refus, dico, ordre) else .CAUSE_VISIBILITE
      } else {
        avec <- if (is.null(e)) logical(0) else e$connu %in% TRUE & !is.na(e$valeur)
        montant <- if (is.null(e)) 0 else sum(sort(e$valeur[avec], method = "radix"))
        nombre_valeurs <- sum(avec)
        cause <- NA_character_
      }
      lignes[[length(lignes) + 1L]] <- data.frame(garantie = g, composante = composante, unite = unite, montant = montant,
                                                  nombre_dossiers = nombre_dossiers, nombre_valeurs = nombre_valeurs,
                                                  cause = cause, stringsAsFactors = FALSE)
    }
  }
  do.call(rbind, lignes)
}

# Table `enjeu` (spécification, §§ 4.4 et 4.5 ; ADR 0010, sixième série, (c) 1, M152) : rangées
# par (table, colonne, motif, famille, action) et garantie, puis rangée `motif = ensemble` par
# (famille, action), sur les dossiers et lignes distincts (table et colonne NA) ; aucune
# rangée pour une table sans enjeu (evaluations_gestion, designations, ayants_droit_sante).
# Rend aussi les composantes empêchées par un refus ou une forme illisible (`non_executes` :
# code = composante, table et colonne de la colonne en cause, cause), qui vont dans
# controles_non_executes (§ 4.6, critère 4 ; une visibilité non déterminée n'y va pas : elle
# est recensée dans vue$visibilite_non_determinee).
.enjeu <- function(ctx, ecarts, dico) {
  colonnes_vides <- data.frame(table = character(0), colonne = character(0), motif = character(0), famille = character(0),
                               action = character(0), garantie = character(0), poste = character(0),
                               composante = character(0), unite = character(0), montant = numeric(0),
                               nombre_dossiers = integer(0), nombre_valeurs = integer(0), cause = character(0),
                               stringsAsFactors = FALSE)
  rangs <- list()
  groupes <- list()
  empeches <- list()
  for (e in ecarts) {
    el <- .enjeu_elementaire(ctx, e)
    if (length(el$familles) == 0L) next
    r <- .rangees_enjeu(el$elements, el$dossiers, el$familles_cause, el$familles, dico, ctx$ordre_codes)
    rangs[[length(rangs) + 1L]] <- data.frame(table = e$table, colonne = e$colonne, motif = e$motif, famille = e$famille,
                                              action = e$action, r[, "garantie", drop = FALSE], poste = "ensemble",
                                              r[, c("composante", "unite", "montant", "nombre_dossiers", "nombre_valeurs",
                                                    "cause")], stringsAsFactors = FALSE)
    cle <- paste(e$famille, e$action, sep = "\r")
    g <- groupes[[cle]]
    groupes[[cle]] <- list(famille = e$famille, action = e$action,
                           elements = rbind(g$elements, el$elements), dossiers = rbind(g$dossiers, el$dossiers),
                           familles_cause = union(g$familles_cause, el$familles_cause),
                           familles = union(g$familles, el$familles))
    if (!is.null(el$elements)) {
      x <- el$elements[!is.na(el$elements$cause) & el$elements$cause != .CAUSE_VISIBILITE, , drop = FALSE]
      if (nrow(x) > 0L) empeches[[length(empeches) + 1L]] <- data.frame(code = x$composante, table = x$cause_table,
                                                                        colonne = x$cause_colonne, cause = x$cause,
                                                                        stringsAsFactors = FALSE)
    }
  }
  for (g in groupes) {
    r <- .rangees_enjeu(g$elements, g$dossiers, g$familles_cause, g$familles, dico, ctx$ordre_codes)
    rangs[[length(rangs) + 1L]] <- data.frame(table = NA_character_, colonne = NA_character_, motif = "ensemble",
                                              famille = g$famille, action = g$action, r[, "garantie", drop = FALSE],
                                              poste = "ensemble",
                                              r[, c("composante", "unite", "montant", "nombre_dossiers", "nombre_valeurs",
                                                    "cause")], stringsAsFactors = FALSE)
  }
  enjeu <- if (length(rangs)) do.call(rbind, rangs) else colonnes_vides
  if (nrow(enjeu) > 0L) {
    rang_table <- match(enjeu$table, dico$tables$table)
    rang_colonne <- ifelse(is.na(enjeu$colonne), 0L, match(paste(enjeu$table, enjeu$colonne),
                                                         paste(dico$colonnes$table, dico$colonnes$colonne)))
    rang_couple <- match(paste(enjeu$composante, enjeu$unite), paste(COMPOSANTES_ENJEU$composante, COMPOSANTES_ENJEU$unite))
    o <- order(is.na(rang_table), rang_table, rang_colonne, enjeu$motif, match(enjeu$famille, c(FAMILLES_CALCUL, "ensemble")),
               enjeu$action, enjeu$garantie == "ensemble", enjeu$garantie, rang_couple, method = "radix")
    enjeu <- enjeu[o, , drop = FALSE]
    rownames(enjeu) <- NULL
  }
  non_executes <- if (length(empeches)) unique(do.call(rbind, empeches)) else
    data.frame(code = character(0), table = character(0), colonne = character(0), cause = character(0), stringsAsFactors = FALSE)
  list(enjeu = enjeu, non_executes = non_executes)
}

# --- Bilan ---------------------------------------------------------------------------

# Identifiants des lignes : dix premières valeurs de la clé primaire, triées (sort radix,
# indépendant de la locale), jointes par « ; » ; une clé composite s'écrit colonnes jointes
# par « | », valeurs en écriture canonique (manquant : \N, ou NA pour une date ; « | » et
# « ; » d'une valeur écrits \x7c et \x3b). Chaîne vide
# si la clé n'est pas lisible.
.identifiants <- function(ctx, table, lignes) {
  if (length(lignes) == 0L) return("")
  cle <- eclater_champ(ctx$dico$tables$cle_primaire[ctx$dico$tables$table == table])
  if (length(cle) == 0L || any(!is.na(vapply(cle, function(c1) .cause(ctx, table, c1, forme_seule = TRUE), "")))) return("")
  valeurs <- lapply(cle, function(c1) .valeurs(ctx, table, c1)[lignes])
  ordre <- do.call(order, c(valeurs, list(method = "radix", na.last = TRUE)))
  # écriture canonique (barre oblique inverse déjà échappée), puis séparateurs échappés en
  # \xNN : « | » en \x7c, « ; » en \x3b ; aucune ambiguïté entre valeurs et séparateurs
  textes <- lapply(valeurs, function(x) {
    gsub(";", "\\x3b", gsub("|", "\\x7c", ecrire_valeurs(x[ordre], "texte"), fixed = TRUE), fixed = TRUE)
  })
  ids <- unique(do.call(paste, c(textes, sep = "|")))
  paste(utils::head(ids, 10L), collapse = ";")
}

# Ordre de tri du bilan : tables du dictionnaire, puis colonnes du dictionnaire (NA en tête,
# colonne inconnue après les colonnes connues), puis code.
.ordre_bilan <- function(dico, table, colonne, code) {
  rang_table <- match(table, dico$tables$table)
  rang_colonne <- ifelse(is.na(colonne), 0L,
                         match(paste(table, colonne), paste(dico$colonnes$table, dico$colonnes$colonne)))
  rang_colonne[is.na(rang_colonne)] <- .Machine$integer.max
  order(rang_table, rang_colonne, ifelse(is.na(colonne), "", colonne), code, method = "radix")
}

.trier <- function(df, dico, code = "code") {
  if (nrow(df) == 0L) return(df)
  df <- df[.ordre_bilan(dico, df$table, df$colonne, df[[code]]), , drop = FALSE]
  rownames(df) <- NULL
  df
}

# Tri d'un élément du bilan sans table ni colonne (exclusions, hypothèses par défaut,
# déclarations requises) par les clés `rangs`, en tri radix.
.trier_par <- function(df, rangs) {
  if (nrow(df) == 0L) return(df)
  df <- df[do.call(order, c(rangs, list(method = "radix"))), , drop = FALSE]
  rownames(df) <- NULL
  df
}

# Constats fusionnés par (code, table, colonne) : union des lignes.
.fusionner_constats <- function(ctx) {
  # clé : (code, table, colonne, traitement) ; un même code sur une même colonne sous deux
  # traitements (D02c date en R et âge en S, D09 signe en R et seuils en S ou X) reste deux
  # lignes (réserve m3)
  cles <- vapply(ctx$constats, function(k) paste(k$code, k$table, k$colonne, k$traitement, sep = "\r"), "")
  lapply(split(ctx$constats, factor(cles, levels = unique(cles))), function(ks) {
    k <- ks[[1L]]
    k$lignes <- sort(unique(unlist(lapply(ks, `[[`, "lignes"))))
    k
  })
}

# Rangs de la priorité des causes de controles_non_executes (spécification, § 3.1 ; M185,
# M194, M195) : rang 3 pour toute cause directe (.RANG_CAUSE_DIRECTE, motif du refus d'une
# colonne lue). À tenir à jour : toute nouvelle cause qui n'est pas un motif de refus (code de
# controles.csv ou de defauts.csv, sous-cas lettrés compris depuis le dictionnaire 1.6)
# reçoit un rang ici, sinon .dedoublonner_non_executes() s'arrête (test d'exhaustivité,
# tests/unitaires/donnees.R). visibilite_non_determinee n'a pas de rang : elle n'est jamais
# une cause de controles_non_executes (spécification, § 4.2).
.RANG_CAUSE_DIRECTE <- 3L
# vue_empechee partage le rang 7 de refus_induit (M684, S-1 (a) ; spécification `donnees` v1.9,
# § 9.1) : candidat d'une règle bloquée seulement sans cause d'un autre rang ; départage par la
# position dans .ordre_codes(), refus_induit d'abord (.cle_causes() : rang 7 sans position 0).
.RANG_INDUIT <- 7L
.RANGS_CAUSES <- c(stats::setNames(1:2, c(CAUSE_NON_IMPLEMENTE, CAUSE_NON_LISIBLE)),
                   stats::setNames(4:7, c(.CAUSE_AGE_NON_DEFINI, .CAUSE_PARAMETRE_NON_DEFINI,
                                          "declaration_absente", "refus_induit")),
                   stats::setNames(.RANG_INDUIT, "vue_empechee"))

# Ordre déclaré des causes à rang égal (spécification `donnees` v1.6, § 3.1, départage à rang
# égal, #59 ; M335) : codes du dictionnaire, lignes de controles.csv puis lignes de
# defauts.csv dans l'ordre des fichiers ; depuis le dictionnaire 1.6, les sous-cas lettrés
# (D07a à D07c, D10a à D10h, D11a à D11c) sont des lignes de defauts.csv, placées après leur
# code parent (spécification `donnees` v1.9, § 9.6), et vue_empechee suit refus_induit dans
# controles.csv (§ 9.1). Dérivé des fichiers lus par dictionnaire() : aucune liste tenue à la
# main. Seul endroit où l'ordre est écrit.
.ordre_codes <- function(dico) c(dico$controles$code, dico$defauts$code)

# Clé de départage (rang, position) de chaque cause de `causes` (spécification, § 3.1 ; M185,
# M194, M195 ; #59) : rang de .RANGS_CAUSES, cherché d'abord (refus_induit et vue_empechee sont
# aussi des codes de controles.csv), sinon rang 3 pour une cause directe (motif de refus : code
# de .ordre_codes()) ; position dans .ordre_codes() pour une cause directe et pour le rang 7, qui
# a deux valeurs (refus_induit, vue_empechee : M684), 0 pour les autres rangs, qui n'ont chacun
# qu'une valeur. Une cause ni rangée ni motif de refus est une erreur
# interne : elle ne se range pas en silence. `.cause_retenue()` : la plus petite des causes
# candidates dans cet ordre lexicographique, NA sans cause ; elle ne dépend pas de l'ordre des
# candidates (minimum sous un ordre total). `ordre` : .ordre_codes(dico), calculé une fois par
# contrôle (`ctx$ordre_codes`, .contexte()) et transmis par les appelants du contrôle (#55).
.cle_causes <- function(causes, dico, ordre = .ordre_codes(dico)) {
  rang <- unname(.RANGS_CAUSES[causes])
  position <- match(causes, ordre)
  directe <- is.na(rang) & !is.na(position)
  rang[directe] <- .RANG_CAUSE_DIRECTE
  if (anyNA(rang)) stop("erreur interne de provie : cause de contr\u00f4le non ex\u00e9cut\u00e9 inconnue : ",
                        paste(unique(causes[is.na(rang)]), collapse = ", "), call. = FALSE)
  # le rang 7 a deux valeurs (refus_induit, vue_empechee) : elles gardent leur position
  position[!directe & rang != .RANG_INDUIT] <- 0L
  list(rang = rang, position = position)
}
.cause_retenue <- function(causes, dico, ordre = .ordre_codes(dico)) {
  causes <- unique(causes[!is.na(causes)])
  if (length(causes) == 0L) return(NA_character_)
  if (length(causes) == 1L) return(causes)
  k <- .cle_causes(causes, dico, ordre)
  causes[order(k$rang, k$position, method = "radix")[1L]]
}

# Une ligne par clé (code, table, colonne) de `non_executes` (colonnes code, table, colonne,
# cause), à la plus petite cause dans l'ordre (rang, position) (.cle_causes() : rang de
# .RANGS_CAUSES, rang 3 pour une cause directe ; à rang égal, ordre des codes du dictionnaire,
# .ordre_codes() ; spécification `donnees` v1.6, § 3.1, #59), dans l'ordre du bilan (.trier()).
# Le résultat ne dépend pas de l'ordre des lignes de `non_executes` (ordre d'émission). Une
# cause ni rangée ni motif de refus est une erreur interne.
.dedoublonner_non_executes <- function(non_executes, dico, ordre = .ordre_codes(dico)) {
  k <- .cle_causes(non_executes$cause, dico, ordre)
  cle <- paste(non_executes$code, non_executes$table, non_executes$colonne, sep = "\r")
  o <- order(cle, k$rang, k$position, method = "radix")
  .trier(non_executes[o[!duplicated(cle[o])], , drop = FALSE], dico)
}
.bilan <- function(ctx) {
  dico <- ctx$dico
  constats <- .fusionner_constats(ctx)
  ch <- function(f) vapply(constats, f, "", USE.NAMES = FALSE)
  nb <- function(f) vapply(constats, f, 0L, USE.NAMES = FALSE)
  ids <- ch(function(k) .identifiants(ctx, k$table, k$lignes))
  controles <- data.frame(code = ch(function(k) k$code), table = ch(function(k) k$table),
                          colonne = ch(function(k) k$colonne), detection = ch(function(k) k$detection),
                          nombre = nb(function(k) length(k$lignes)), identifiants = ids,
                          stringsAsFactors = FALSE)
  traitement <- ch(function(k) k$traitement)

  # placement des constats qui attendent une déclaration, et enjeu (après la vue)
  ordre <- order(traitement, method = "radix")   # départage reproductible de deux traitements d'une même clé
  constats <- constats[ordre]
  placement <- .placer(ctx, constats)
  ctx$placement <- placement
  enjeu <- .enjeu(ctx, placement$ecarts, dico)

  ne <- ctx$non_executes
  non_executes <- data.frame(code = vapply(ne, `[[`, "", "code"), table = vapply(ne, `[[`, "", "table"),
                             colonne = vapply(ne, function(k) k$colonne, ""), cause = vapply(ne, `[[`, "", "cause"),
                             stringsAsFactors = FALSE)
  ni <- CONTROLES_NON_IMPLEMENTES[CONTROLES_NON_IMPLEMENTES$table %in% ctx$tables, , drop = FALSE]
  # composantes de l'enjeu qui lisent une colonne refusée ou illisible (spécification, § 4.6,
  # critère 4) : code = composante, table et colonne lues, cause = motif du refus
  non_executes <- rbind(data.frame(ni, cause = rep(CAUSE_NON_IMPLEMENTE, nrow(ni)), stringsAsFactors = FALSE),
                        non_executes, enjeu$non_executes)
  # une ligne par (code, table, colonne), cause de plus petit rang dans l'ordre de priorité
  # (M185, M194, M195 ; .dedoublonner_non_executes()) ; une règle empêchée reste toujours
  # ici, même si une autre règle de même clé a détecté : la clé présente aussi dans controles
  # est une détection partielle, dont le nombre est un minorant (ADR 0010, huitième série, (e))
  non_executes <- .dedoublonner_non_executes(non_executes, dico, ctx$ordre_codes)

  controles <- controles[ordre, , drop = FALSE]
  traitement <- traitement[ordre]
  origine <- ch(function(k) k$origine)   # constats déjà dans l'ordre `ordre`
  r <- traitement == "R"
  refus <- data.frame(table = controles$table[r], colonne = controles$colonne[r], motif = controles$code[r],
                      portee = vapply(which(r), function(i) .portee_effective(dico, controles$code[i],
                                                                              controles$table[i], controles$colonne[i]), ""),
                      origine = origine[r], nombre = controles$nombre[r],
                      nombre_visibles = vapply(constats[r], function(k) {
                        vis <- .connus(ctx, k$table)[k$lignes]
                        if (anyNA(vis)) NA_integer_ else sum(vis)
                      }, 0L, USE.NAMES = FALSE),
                      identifiants = controles$identifiants[r],
                      nombre_dossiers = vapply(constats[r], function(k) {
                        .nombre_dossiers_union(ctx, list(list(table = k$table, lignes = k$lignes, d03g = identical(k$code, "D03g"))))
                      }, 0L, USE.NAMES = FALSE),
                      postes_arretes = rep(NA_character_, sum(r)),
                      stringsAsFactors = FALSE)
  # signalements : constats traités S, et constats à choix dont le signalement est déclaré
  # pour un référentiel (D4)
  s <- traitement == "S" | placement$signales
  signalements <- data.frame(code = controles$code[s], table = controles$table[s], colonne = controles$colonne[s],
                             detection = controles$detection[s], nombre = controles$nombre[s],
                             identifiants = controles$identifiants[s], stringsAsFactors = FALSE)
  exclusions <- .agreger_placement(ctx, placement$exclusions, c("motif", "famille", "action"), "nombre_lignes",
                                   dossiers = TRUE)
  hypotheses <- .agreger_placement(ctx, placement$hypotheses, c("motif", "referentiel", "poste", "valeur"), "nombre")
  requises <- .agreger_placement(ctx, c(placement$requises, ctx$requises), c("rubrique", "motif", "cle", "traitements_admis"),
                                 "nombre_lignes")
  nd <- .visibilite_non_determinee(ctx)
  absentes <- dico$tables$table[dico$tables$obligatoire != "O" & !(dico$tables$table %in% names(ctx$base))]
  if ("catastrophes" %in% names(ctx$base)) absentes <- setdiff(absentes, "victimes")
  list(
    controles = .trier(controles, dico),
    controles_non_executes = .trier(non_executes, dico),
    refus_tables = .trier(refus, dico, "motif"),
    exclusions = .trier_par(exclusions, list(exclusions$motif, match(exclusions$famille, FAMILLES_CALCUL),
                                             exclusions$action)),
    hypotheses_defaut = .trier_par(hypotheses, list(hypotheses$motif, match(hypotheses$referentiel, REFERENTIELS),
                                                    hypotheses$poste, hypotheses$valeur)),
    signalements = .trier(signalements, dico),
    declarations_requises = .trier_par(requises, list(match(requises$rubrique, c(RUBRIQUES_DECLARATIONS, "conventions")),
                                                      requises$motif, match(requises$cle, c(FAMILLES_CALCUL, REFERENTIELS)),
                                                      requises$cle, requises$traitements_admis)),
    enjeu = enjeu$enjeu,
    vue = list(date_arrete = ctx$arrete, date_extraction = ctx$date_extraction,
               visibilite_non_determinee = nd, provisoire = nrow(nd) > 0L || isTRUE(ctx$p_non_executee) ||
                 length(ctx$p_refusees) > 0L),
    segments = data.frame(id_dossier = character(0), id_sinistre = character(0), id_contrat = character(0),
                          segmentation = character(0), segment = character(0), stringsAsFactors = FALSE),
    tables_absentes = absentes
  )
}
