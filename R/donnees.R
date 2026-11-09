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
# somme_parts, D01b, D02a, D02c (âge), D03a à D03c, D03e, D03f, D03h, D05, D06, D07 (c), D10 (b)
# et (c), D13 ;
# placement de chaque constat selon les déclarations (exclusions, hypotheses_defaut,
# declarations_requises), enjeu (COMPOSANTES_ENJEU), nombre_visibles et nombre_dossiers.
# L'état partiel est porté par l'objet rendu : chaque contrôle prévu par la spécification et
# reporté (CONTROLES_NON_IMPLEMENTES : report déclaré à la fermeture de #18) figure dans
# controles_non_executes avec la cause `non_implemente` ; un sous-cas que la base ne permet
# pas de lire, avec la cause `non_lisible` (CAUSE_NON_LISIBLE). Contrôles reportés : D03d,
# D07 (a) et (b), D08, D09, D10d à D10f, D11, D12 et D14. D09 aux seuils et D07 (b) restent
# `non_implemente` (décision du mainteneur, D6) : aucun de leurs seuils n'est attendu dans
# declarations_requises.

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
# table de `seuils`, en jours, sans valeur par défaut, commune aux deux référentiels.
.SEUIL_DELAI_D03G <- "d03g_delai_jours"
# Bornes de vraisemblance de l'âge de D02c (spécification, § 5.4 ; ADR 0010, neuvième série) :
# deux listes nommées par emploi de `seuils`, en années entières, sans valeur par défaut ;
# table de la personne de chaque emploi.
.SEUILS_AGE_D02C <- c("d02c_age_min", "d02c_age_max")
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
# `instant_date`, `repartition_annee` et `fractionnement` sont admises sans contrôle de valeur :
# leur domaine n'est écrit ni dans l'ADR 0010 (point 17 : noms seuls) ni dans la
# spécification ; valider_plan() le fixera en B2.
ENTREES_CONVENTIONS <- c("age", "instant_date", "repartition_annee", "fractionnement", "limite_age")

# Contrôles prévus par la spécification (§ 2.4) et reportés (décision du mainteneur : #18 se
# ferme avec un report déclaré ; #34) : rendus dans
# controles_non_executes avec la cause `non_implemente` (CAUSE_NON_IMPLEMENTE), pour que le
# bilan dise lui-même qu'il est partiel. D07 sur evenements : sous-cas (a) et (b).
# Colonne NA : contrôle qui porte sur plusieurs colonnes, ou sous-cas qui ne doit pas se
# confondre avec un contrôle écrit sur la même colonne (D09 aux seuils).
# Priorité des causes : un contrôle non implémenté porte `non_implemente`, avant toute
# autre cause (declaration_absente, refus d'une colonne lue).
CAUSE_NON_IMPLEMENTE <- "non_implemente"
# Sous-cas qu'aucune colonne de la base ne permet de lire (décision du mainteneur, D2 :
# D03h pour la garantie décès d'un contrat collectif qui porte le maintien de la garantie
# décès, colonne prévue au dictionnaire 1.6) : non exécuté, cause `non_lisible`, colonne NA
# (sous-cas distinct de la règle écrite sur la même colonne).
CAUSE_NON_LISIBLE <- "non_lisible"
.ni <- function(code, table, colonne = NA_character_) {
  data.frame(code = code, table = table, colonne = colonne, stringsAsFactors = FALSE)
}
CONTROLES_NON_IMPLEMENTES <- rbind(
  .ni("D03d", "assures", "situation_familiale"),
  .ni("D07", "evenements"),
  .ni("D08", "sinistres"),
  .ni("D09", c("parametres", "affiliations", "evenements", "prestations", "cotisations")),
  .ni("D10d", "evenements"),
  .ni("D10e", "beneficiaires", "qualite"),
  .ni("D10f", "evenements"),
  .ni("D11", "sinistres", "date_survenance"),
  .ni("D12", "evenements", "type_evenement"),
  .ni("D14", "famille")
)

# Règle de limite d'âge de D07 (c) (M155) et conventions d'âge admises pour cet emploi
# (spécification, § 5.3 ; M154 : naissance réelle de l'enfant).
REGLES_LIMITE_AGE <- c("atteinte", "depassement")
CONVENTIONS_LIMITE_AGE <- c("revolu", "millesime")

# Couples (motif, famille) traités S par le dictionnaire (§ 9) : la famille ne lit pas la
# colonne (D03a : « S pour la famille triangle », dict. :743 ; D12 : « S pour la famille
# triangle, qui ne lit pas les états », dict. :761). Hors du critère de couverture d'une
# exclusion (ni declarations_requises ni enjeu non déclaré) ; une exclusion déclarée sur l'un
# d'eux est refusée (plan_invalide).
.EXCEPTIONS_FAMILLE <- data.frame(motif = c("D03a", "D12"), famille = c("triangle", "triangle"),
                                  stringsAsFactors = FALSE)
# Motifs de la règle P, appliqués à la construction de la vue (une seule vue pour les deux
# référentiels) : une hypothèse porte sur tous les postes, avec la même valeur pour les deux
# référentiels ; aucune n'est un signalement déclaré (S seulement à l'extraction).
.MOTIFS_REGLE_P <- c("D02b", "D03g")
# Motifs à traitement unique (dictionnaire, § 1.10 et § 9 : X et H y sont deux alternatives
# pour toute ligne) : une exclusion et une hypothèse déclarées pour un même motif de cette
# liste rendent le plan invalide, quelles qu'en soient les familles ou les référentiels
# (décision du mainteneur, D8). D03g n'y est pas (D11) : X et H se déclarent ensemble, X
# pour les lignes entières, H pour les parties de ligne (.application_d03g()).
.MOTIFS_TRAITEMENT_UNIQUE <- c("D02a", "D03a", "D03c", "D03f")
# Motifs dont le signalement (S) est un choix déclarable, alternative à H ou à X
# (dictionnaire, § 9 ; D07 : sous-cas (a) et (c)) : liste explicite (réserve d'`actuary`),
# non dérivée de defauts.csv$traitements, qui ne distingue pas un S alternatif (« H;S ») d'un
# S cumulatif (« S + X », D02c, D10 (b)) ni d'un S réservé à une famille (D03a, D12).
.MOTIFS_SIGNALEMENT <- c("D05", "D06", "D07", "D08", "D10f", "D13", "D14")
# Traitements de chaque sous-cas de D10 (dictionnaire, § 9) : (a) et (h) R ; (b) S + X (S
# automatique) ; (c) et (d) S ; (e) X ; (f) H ou S. Lus à la place de la liste de D10 pour
# admettre une déclaration (réserve c3 de l'audit).
.TRAITEMENTS_SOUS_CAS_D10 <- c(D10a = "R", D10b = "S;X", D10c = "S", D10d = "S", D10e = "X", D10f = "H;S",
                               D10h = "R")
# Motifs dont le refus porte sur une clé étrangère (lien) : cette colonne ne bloque pas
# l'enjeu de son propre écart (.cause_enjeu(), réserve Q4).
.MOTIFS_LIEN_ECART <- c("D04a", "D04b", "D10a", "D10h")
# Tables de D03g (date_saisie, ou date_saisie_fin d'un contrat ou d'une affiliation) : noms
# admis de seuils$d03g_delai_jours.
.TABLES_D03G <- c("contrats", "affiliations", "famille", "sinistres", "beneficiaires", "rentes", "evenements",
                  "prestations", "designations", "ayants_droit_sante")

# Codes de défaut dont l'objet est un manquant (dictionnaire, § 9) : un manquant dans une
# colonne qui porte l'un d'eux relève de ce défaut, non de `manquant_obligatoire`.
.DEFAUTS_MANQUANT <- c("D03a", "D03b", "D03c", "D03e", "D03f", "D03g", "D03h", "D04a")

# Écart admis entre la somme des parts des bénéficiaires d'un dossier et 1 (somme_parts) :
# erreur d'arrondi d'une somme de fractions en double précision (1/3 + 1/3 + 1/3), non une
# tolérance de gestion.
.TOLERANCE_PARTS <- sqrt(.Machine$double.eps)

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
#     dossiers rattachés visibles ;
#   exclusions (par motif, famille de calcul et action déclarée), hypotheses_defaut (par
#     motif, référentiel, poste et valeur déclarés), signalements (S, ou signalement
#     déclaré), declarations_requises (déclaration attendue par un constat : rubrique,
#     motif, famille, référentiel ou seuil, traitements admis) ; enjeu (table longue,
#     COMPOSANTES_ENJEU) ;
#   vue : date d'arrêté et d'extraction, lignes de visibilité non déterminée (table,
#     colonne : NA pour la ligne entière, sinon partie de ligne ; motif, dont
#     parente_non_determinee ; nombre, identifiants) et `provisoire` (vrai s'il y en a, ou si
#     une règle P n'a pas pu s'exécuter sur une table lue par la vue : comptes de la règle
#     V provisoires) ;
#   segments : vide en Bd (segmentations déclarées en B2) ;
#   tables_absentes : tables facultatives absentes.
# Chaque data.frame est trié par ordre des tables du dictionnaire, puis des colonnes (NA en
# tête), puis par code (exclusions, hypotheses_defaut, declarations_requises : par motif,
# puis famille ou référentiel dans l'ordre de leur liste) ; `identifiants` porte les dix premières valeurs de la clé primaire,
# triées (sort radix), jointes par « ; » (colonnes d'une clé composite jointes par « | »).
controler_base <- function(donnees, arrete, declarations = NULL, conventions = NULL) {
  if (missing(arrete)) {
    refuser("controler_base() : date d'arr\u00eat\u00e9 absente (`arrete`, obligatoire, sans valeur par d\u00e9faut)",
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
  declarations <- .lire_declarations(declarations, dico)

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
  .bilan(ctx)
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
    modalites <- .eclater_champ(colonnes$modalites[i])
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

.eclater_champ <- function(x) if (identical(x, "") || is.na(x)) character(0) else strsplit(x, ";", fixed = TRUE)[[1L]]

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
# `exclusions` : motif d'un défaut admettant X (code du § 9, ou sous-cas D10a à D10h),
# famille de FAMILLES_CALCUL, action de ACTIONS_EXCLUSION, une ligne par (motif, famille),
# hors des couples traités S (.EXCEPTIONS_FAMILLE), D03g en `exclure` seulement ;
# `hypotheses` : motif d'un défaut admettant H (ou, pour la valeur .VALEUR_SIGNALEMENT, motif
# de .MOTIFS_SIGNALEMENT, seule ligne de son (motif, referentiel)), référentiel de
# REFERENTIELS, poste (ou `tous`) et valeur en chaînes, une ligne par (motif, referentiel,
# poste) ; D02b et D03g : poste `tous`, même valeur pour les deux référentiels, sans
# signalement. D10 se déclare par sous-cas (traitements du sous-cas). Un motif à traitement
# unique (.MOTIFS_TRAITEMENT_UNIQUE) ne se déclare pas dans les deux rubriques (D8).
# `seuils` : liste nommée ; seul d03g_delai_jours est lu (liste nommée par table de D03g,
# jours entiers positifs ou nuls) ; `evaluations_gestion` : liste réduite à `diagnostics`
# (logical), lue par les diagnostics (B2), jamais par le bilan.
.lire_declarations <- function(declarations, dico) {
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
  dl <- declarations$seuils[[.SEUIL_DELAI_D03G]]
  if (!is.null(dl)) {
    jours <- function(x) is.numeric(x) && length(x) == 1L && is.finite(x) && x >= 0 && x == round(x)
    if (!nommee(dl) || length(dl) == 0L || !all(names(dl) %in% .TABLES_D03G) || !all(vapply(dl, jours, NA))) {
      .refus_plan(paste0("declarations$seuils$", .SEUIL_DELAI_D03G, " : liste nomm\u00e9e par table de D03g (",
                         paste(.TABLES_D03G, collapse = ", "), "), d\u00e9lai en jours (nombre entier positif ou nul)"))
    }
  }
  for (nom in .SEUILS_AGE_D02C) {
    sa <- declarations$seuils[[nom]]
    if (is.null(sa)) next
    age <- function(x) is.numeric(x) && length(x) == 1L && is.finite(x) && x >= 0 && x == round(x)
    if (!nommee(sa) || length(sa) == 0L || !all(names(sa) %in% names(.EMPLOIS_D02C)) || !all(vapply(sa, age, NA))) {
      .refus_plan(paste0("declarations$seuils$", nom, " : liste nomm\u00e9e par emploi de D02c (",
                         paste(names(.EMPLOIS_D02C), collapse = ", "), "), \u00e2ge en ann\u00e9es enti\u00e8res positif ou nul"))
    }
  }
  amin <- declarations$seuils[[.SEUILS_AGE_D02C[1L]]]
  amax <- declarations$seuils[[.SEUILS_AGE_D02C[2L]]]
  communs <- intersect(names(amin), names(amax))
  if (any(vapply(communs, function(e) amin[[e]] > amax[[e]], NA))) {
    .refus_plan("declarations$seuils : d02c_age_min sup\u00e9rieur \u00e0 d02c_age_max pour un emploi")
  }
  ex <- .table_declarations(declarations$exclusions, c("motif", "famille", "action"), "exclusions")
  # un motif D10 se déclare par sous-cas (D10a à D10h) : D10 seul est refusé (réserve m1)
  if (!all(.motif_admet(dico, ex$motif, "X")) || any(ex$motif == "D10") || !all(ex$famille %in% FAMILLES_CALCUL) ||
      !all(ex$action %in% ACTIONS_EXCLUSION) || anyDuplicated(ex[, c("motif", "famille")])) {
    .refus_plan(paste0("declarations$exclusions : motif d'un d\u00e9faut trait\u00e9 X (D10 par sous-cas), famille (",
                       paste(FAMILLES_CALCUL, collapse = ", "), "), action (exclure, conserver), ",
                       "une ligne par (motif, famille)"))
  }
  if (any(paste(ex$motif, ex$famille) %in% paste(.EXCEPTIONS_FAMILLE$motif, .EXCEPTIONS_FAMILLE$famille))) {
    .refus_plan("declarations$exclusions : D03a et D12 sont des signalements pour la famille triangle (dictionnaire, \u00a7 9)")
  }
  if (any(ex$motif == "D03g" & ex$action != "exclure")) {
    .refus_plan("declarations$exclusions : D03g n'admet que l'action exclure (la ligne sort de la vue)")
  }
  hy <- .table_declarations(declarations$hypotheses, c("motif", "referentiel", "poste", "valeur"), "hypotheses")
  signalement <- hy$valeur == .VALEUR_SIGNALEMENT
  if (!all(.motif_admet(dico, hy$motif, "H") | signalement) || !all(hy$motif %in% .MOTIFS_SIGNALEMENT | !signalement) ||
      any(hy$motif == "D10") || !all(hy$referentiel %in% REFERENTIELS) ||
      anyDuplicated(hy[, c("motif", "referentiel", "poste")])) {
    .refus_plan(paste0("declarations$hypotheses : motif d'un d\u00e9faut trait\u00e9 H, ou la valeur ",
                       .VALEUR_SIGNALEMENT, " pour un motif dont S est un choix (",
                       paste(.MOTIFS_SIGNALEMENT, collapse = ", "), ") (D10 par sous-cas), r\u00e9f\u00e9rentiel (",
                       paste(REFERENTIELS, collapse = ", "), "), une ligne par (motif, referentiel, poste)"))
  }
  # un signalement déclaré est la seule ligne de son (motif, referentiel)
  cle_s <- paste(hy$motif, hy$referentiel)
  if (any(cle_s[signalement] %in% cle_s[duplicated(cle_s) | duplicated(cle_s, fromLast = TRUE)])) {
    .refus_plan(paste0("declarations$hypotheses : la valeur ", .VALEUR_SIGNALEMENT,
                       " est la seule ligne de son (motif, referentiel)"))
  }
  # motifs de la règle P (vue commune aux deux référentiels) : poste `tous`, même valeur pour
  # les deux référentiels, aucun signalement déclaré (réserve Q4 d'`actuary`)
  p <- hy[hy$motif %in% .MOTIFS_REGLE_P, , drop = FALSE]
  if (any(p$poste != "tous") || any(p$valeur == .VALEUR_SIGNALEMENT) ||
      any(vapply(split(p$valeur, p$motif), function(x) length(unique(x)) > 1L, NA))) {
    .refus_plan(paste0("declarations$hypotheses : D02b et D03g portent le poste tous, la m\u00eame valeur pour les deux ",
                       "r\u00e9f\u00e9rentiels, et ne se signalent pas (S \u00e0 l'extraction seulement)"))
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

# Familles de calcul d'une exclusion du motif `motif` : toutes, hors les couples traités S
# (.EXCEPTIONS_FAMILLE).
.familles_x <- function(motif) setdiff(FAMILLES_CALCUL, .EXCEPTIONS_FAMILLE$famille[.EXCEPTIONS_FAMILLE$motif == motif])

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
      !is.null(ctx$declarations$seuils[[.SEUIL_DELAI_D03G]][[table]])) return("H")
  NA_character_
}

# Motifs (codes du § 9, ou sous-cas D10a à D10h, la lettre g n'étant attribuée à aucun) dont
# le traitement admet `t` (defauts.csv$traitements ; un sous-cas de D10 lit son propre
# traitement, .TRAITEMENTS_SOUS_CAS_D10).
.motif_admet <- function(dico, motif, t) {
  sous_cas <- motif %in% names(.TRAITEMENTS_SOUS_CAS_D10)
  traitements <- ifelse(sous_cas, .TRAITEMENTS_SOUS_CAS_D10[motif], dico$defauts$traitements[match(motif, dico$defauts$code)])
  connu <- motif %in% dico$defauts$code | sous_cas
  connu & !is.na(traitements) & vapply(traitements, function(x) t %in% .eclater_champ(x), NA, USE.NAMES = FALSE)
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
# (identifiants du bilan). `directe` : un refus induit (règle B, clé étrangère visant une
# table refusée ; règle P empêchée, D12 : un refus de portée table de code `refus_induit`)
# ne masque pas la cause propre de la colonne (refus ou forme), rendue seule (NA sans elle) ;
# priorité des causes, M185.
.cause <- function(ctx, table, colonne, forme_seule = FALSE, directe = FALSE) {
  if (!forme_seule && !is.null(ctx$refus_pv)) {
    t <- ctx$refus_pv$tables[[table]]
    if (!is.null(t) && !(directe && t == "refus_induit")) return(t)
    c1 <- ctx$refus_pv$colonnes[[table]]
    if (!is.null(c1) && colonne %in% names(c1)) return(c1[[colonne]])
  }
  causes <- ctx$inutilisable[[table]]
  if (is.null(causes) || !(colonne %in% names(causes))) NA_character_ else causes[[colonne]]
}

.ajouter_constat <- function(ctx, code, table, colonne, lignes, traitement, detection,
                             portee = NA_character_, origine = NA_character_) {
  ctx$constats[[length(ctx$constats) + 1L]] <- list(
    code = code, table = table, colonne = colonne, lignes = sort(unique(as.integer(lignes))),
    traitement = traitement, detection = detection, portee = portee, origine = origine)
  invisible(NULL)
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
.regle <- function(ctx, code, table, colonne, lit, traitement, detection, f, colonne_ne = colonne) {
  if (is.null(ctx$base[[table]])) return(invisible(integer(0)))
  lit <- unique(c(if (!is.na(colonne)) paste(table, colonne, sep = "."), lit))
  for (directe in c(TRUE, FALSE)) {
    for (tc in lit) {
      morceaux <- strsplit(tc, ".", fixed = TRUE)[[1L]]
      cause <- .cause(ctx, morceaux[1L], morceaux[2L], directe = directe)
      if (!is.na(cause)) {
        .ajouter_non_execute(ctx, code, table, colonne_ne, cause, lu = tc)
        return(invisible(NULL))
      }
    }
  }
  lignes <- which(f())
  if (length(lignes) > 0L) .ajouter_constat(ctx, code, table, colonne, lignes, traitement, detection)
  invisible(lignes)
}

# Traitement d'un code de contrôle de structure (règle provisoire d'`architect`, ADR 0010,
# sixième série, (a), et septième série, (d)) : un code de portée `ligne` est un
# signalement (S), tout autre code un refus (R). Seul endroit où la règle est écrite.
.traitement_code_controle <- function(dico, code) {
  portee <- dico$controles$portee[dico$controles$code == code]
  if (length(portee) != 1L) stop("code de contr\u00f4le inconnu : ", code, call. = FALSE)
  if (portee == "ligne") "S" else "R"
}

# Portée effective d'un refus R (§ 1.10 du dictionnaire ; ADR 0010, sixième série, (b) 1) :
# `colonne_table` (et tout défaut D.. de portée non fixée) devient `table` pour une colonne
# de la clé primaire ou qui porte une référence, `colonne` sinon ; D10 (a) porte sur la
# table de la table fille (spécification, § 2.4) ; toute anomalie de evaluations_gestion
# refuse la table seule (dictionnaire, § 7.5).
.portee_effective <- function(dico, code, table, colonne) {
  if (table == "evaluations_gestion" || code == "D10a" || is.na(colonne)) return("table")
  portee <- dico$controles$portee[dico$controles$code == code]
  if (length(portee) == 1L && portee %in% c("table", "colonne")) return(portee)
  cle <- .eclater_champ(dico$tables$cle_primaire[dico$tables$table == table])
  ref <- dico$colonnes$reference[dico$colonnes$table == table & dico$colonnes$colonne == colonne]
  if (colonne %in% cle || (length(ref) == 1L && nzchar(ref))) "table" else "colonne"
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
# colonnes C, bornes écrites dans le domaine, signes de D09).
.regle_domaine <- function(ctx) {
  borne_basse <- as.numeric(as.Date("1901-01-01"))
  extraction <- as.numeric(ctx$date_extraction)
  for (table in setdiff(ctx$tables, "extraction")) {
    colonnes <- .colonnes_dico(ctx, table)
    for (i in seq_len(nrow(colonnes))) {
      col <- colonnes[i, ]
      colonne <- col$colonne
      if (!(colonne %in% names(ctx$base[[table]]))) next   # absente : F sans effet, O ou C refusée
      x <- .valeurs(ctx, table, colonne)
      tc <- paste(table, colonne, sep = ".")
      if (col$type == "character") {
        .regle(ctx, "chaine_vide", table, colonne, character(0), "R", "exacte",
               function() !is.na(x) & x == "")
        modalites <- .eclater_champ(col$modalites)
        if (length(modalites) > 0L) {
          .regle(ctx, "hors_domaine", table, colonne, character(0), "R", "exacte",
                 function() !is.na(x) & x != "" & !(x %in% modalites))
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
      if (col$obligatoire == "O" && !any(.eclater_champ(col$defauts) %in% .DEFAUTS_MANQUANT)) {
        .regle(ctx, "manquant_obligatoire", table, colonne, character(0), "R", "exacte",
               function() is.na(x) & !is.nan(x))
      }
    }
  }
  .regles_propres(ctx)
  invisible(NULL)
}

# evenements.date_effet : futur admis pour un type programmable seulement (motif compris,
# types_evenements.programmable) ; sinon, au plus la date d'extraction (D02c).
.regle_date_programmable <- function(ctx, borne_basse, extraction) {
  .regle(ctx, "D02c", "evenements", "date_effet", c("evenements.type_evenement", "evenements.motif"),
         "R", "exacte", function() {
    v <- as.numeric(.valeurs(ctx, "evenements", "date_effet"))
    v < borne_basse | (!.programmable(ctx) & v > extraction)
  })
}

# Événements d'un type programmable (motif compris, types_evenements.programmable) : leur
# date d'effet peut suivre leur saisie et l'extraction (dictionnaire, § 4).
.programmable <- function(ctx) {
  te <- ctx$dico$types_evenements
  motif <- .valeurs(ctx, "evenements", "motif")
  prog <- te$programmable[match(.valeurs(ctx, "evenements", "type_evenement"), te$type_evenement)]
  par_motif <- vapply(seq_along(prog), function(i) {
    !is.na(prog[i]) && startsWith(prog[i], "oui:") && !is.na(motif[i]) &&
      motif[i] %in% .eclater_champ(substring(prog[i], 5L))
  }, NA)
  !is.na(prog) & (prog == "oui" | par_motif)
}

# Lignes d'une table conditionnée par une colonne d'une autre table jointe par clé.
.joindre <- function(ctx, table_cible, cle_cible, colonne_cible, valeurs_cle) {
  cible <- .valeurs(ctx, table_cible, cle_cible)
  .valeurs(ctx, table_cible, colonne_cible)[match(valeurs_cle, cible, incomparables = NA)]
}

# Colonne conditionnelle : `requis` (logique par ligne, NA : condition indéterminée) ;
# manquant sous la condition -> manquant_obligatoire (sauf `defaut_manquant` : le manquant
# relève alors de ce défaut, traité en règle V) ; présent hors condition -> hors_domaine.
.regle_condition <- function(ctx, table, colonne, lit, requis, defaut_manquant = FALSE) {
  x <- .valeurs(ctx, table, colonne)
  if (!defaut_manquant) {
    .regle(ctx, "manquant_obligatoire", table, colonne, lit, "R", "exacte",
           function() { r <- requis(); !is.na(r) & r & is.na(x) })
  }
  .regle(ctx, "hors_domaine", table, colonne, lit, "R", "exacte",
         function() { r <- requis(); !is.na(r) & !r & !is.na(x) })
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
# des défauts de la vue (règle V) ou de la règle P, hors de ces règles.
.regles_propres <- function(ctx) {
  v <- function(table, colonne) .valeurs(ctx, table, colonne)
  te <- ctx$dico$types_evenements

  # contrats
  nature <- v("contrats", "nature_contrat")
  individuel <- ifelse(is.na(nature), NA, nature == "individuel")
  .regle_condition(ctx, "contrats", "id_adherent", "contrats.nature_contrat", function() !individuel)
  .regle_condition(ctx, "contrats", "id_assure", "contrats.nature_contrat", function() individuel)
  .regle_condition(ctx, "contrats", "date_terme",
                   c("contrats.nature_contrat", "contrats.id_contrat", "garanties_souscrites.id_contrat",
                     "garanties_souscrites.code_garantie"), function() {
    deces <- unique(v("garanties_souscrites", "id_contrat")[v("garanties_souscrites", "code_garantie") %in% "deces"])
    individuel & v("contrats", "id_contrat") %in% deces
  })
  date_fin <- v("contrats", "date_fin")
  .regle_condition(ctx, "contrats", "motif_fin", "contrats.date_fin", function() !is.na(date_fin))
  .regle_condition(ctx, "contrats", "date_saisie_fin", "contrats.date_fin", function() !is.na(date_fin),
                   defaut_manquant = TRUE)
  .hors_bornes(ctx, "contrats", "mois_echeance", 1, 12)
  .hors_bornes(ctx, "contrats", "preavis_mois", 0, 24)
  .regle(ctx, "hors_domaine", "contrats", "jour_echeance", "contrats.mois_echeance", "R", "exacte", function() {
    jour <- v("contrats", "jour_echeance")
    mois <- v("contrats", "mois_echeance")
    maxi <- c(31L, 29L, 31L, 30L, 31L, 30L, 31L, 31L, 30L, 31L, 30L, 31L)[match(mois, 1:12)]
    !is.na(jour) & (jour < 1L | jour > ifelse(is.na(maxi), 31L, maxi))
  })

  # garanties_souscrites : colonnes requises par garantie, manquantes hors de ces garanties
  code_gs <- v("garanties_souscrites", "code_garantie")
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
                     function() ifelse(is.na(code_gs), NA, code_gs %in% garanties))
  }
  # taux_technique_tarif : jamais pour l'arrêt de travail ; requis ailleurs selon le § 3, T4
  # (manquant : D03h, règle V ; le maintien de la garantie décès n'est pas lisible dans la
  # base, la présence sur un décès collectif est donc admise) ; bornes de contrôle.
  .regle(ctx, "hors_domaine", "garanties_souscrites", "taux_technique_tarif",
         "garanties_souscrites.code_garantie", "R", "exacte", function() {
    x <- v("garanties_souscrites", "taux_technique_tarif")
    !is.na(x) & (code_gs %in% c("incapacite", "invalidite") | x < -0.05 | x > 0.10)
  })
  .regle(ctx, "hors_domaine", "garanties_souscrites", "college",
         c("garanties_souscrites.id_contrat", "contrats.id_contrat", "contrats.nature_contrat"), "R", "exacte",
         function() {
    nat <- .joindre(ctx, "contrats", "id_contrat", "nature_contrat", v("garanties_souscrites", "id_contrat"))
    !is.na(nat) & nat == "individuel" & v("garanties_souscrites", "college") != "ensemble"
  })

  # parametres
  par <- ctx$dico$parametres
  lit_par <- c("parametres.id_garantie_souscrite", "parametres.parametre",
               "garanties_souscrites.id_garantie_souscrite", "garanties_souscrites.code_garantie")
  code_par <- function() .joindre(ctx, "garanties_souscrites", "id_garantie_souscrite", "code_garantie",
                                  v("parametres", "id_garantie_souscrite"))
  ligne_par <- function() {
    p <- v("parametres", "parametre")
    g <- code_par()
    i <- match(paste(g, p), paste(par$code_garantie, par$parametre))
    j <- match(p, par$parametre[par$code_garantie == "toutes"])
    ifelse(is.na(i), ifelse(is.na(j), NA_integer_, which(par$code_garantie == "toutes")[j]), i)
  }
  .regle(ctx, "hors_domaine", "parametres", "parametre", lit_par, "R", "exacte", function() {
    p <- v("parametres", "parametre")
    !is.na(p) & !is.na(code_par()) & p %in% par$parametre & is.na(ligne_par())
  })
  .regle_condition(ctx, "parametres", "categorie_invalidite", lit_par, function() {
    k <- ligne_par()
    ifelse(is.na(k), NA, grepl("categorie_invalidite", par$dimension[k], fixed = TRUE))
  })
  .hors_bornes(ctx, "parametres", "age_min", 0, 120)
  .hors_bornes(ctx, "parametres", "age_max", 0, 120)
  age_min <- v("parametres", "age_min")
  .regle_condition(ctx, "parametres", "age_max", "parametres.age_min", function() !is.na(age_min))
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
                   c("assures.situation_familiale", "assures.nombre_enfants_charge"), function() {
    !is.na(v("assures", "situation_familiale")) | !is.na(v("assures", "nombre_enfants_charge"))
  })

  # affiliations
  .regle(ctx, "hors_domaine", "affiliations", "id_contrat", c("contrats.id_contrat", "contrats.nature_contrat"),
         "R", "exacte", function() {
    nat <- .joindre(ctx, "contrats", "id_contrat", "nature_contrat", v("affiliations", "id_contrat"))
    !is.na(nat) & nat == "individuel"
  })
  date_fin_af <- v("affiliations", "date_fin")
  .regle_condition(ctx, "affiliations", "motif_fin", "affiliations.date_fin", function() !is.na(date_fin_af))
  .regle_condition(ctx, "affiliations", "date_saisie_fin", "affiliations.date_fin",
                   function() !is.na(date_fin_af), defaut_manquant = TRUE)
  .hors_bornes(ctx, "affiliations", "salaire_reference", mini = 0, code = "D09")
  .regle_condition(ctx, "affiliations", "date_designation", "affiliations.designation",
                   function() v("affiliations", "designation") %in% c("type", "nominative"))
  .regle_condition(ctx, "affiliations", "structure_cotisation_sante", "affiliations.sante_organisme",
                   function() v("affiliations", "sante_organisme") %in% TRUE)

  # famille
  situation <- v("famille", "situation")
  .regle(ctx, "hors_domaine", "famille", "date_naissance", "famille.situation", "R", "exacte",
         function() !is.na(v("famille", "date_naissance")) & situation %in% "a_naitre")
  .regle(ctx, "hors_domaine", "famille", "situation", "famille.lien", "R", "exacte",
         function() !is.na(situation) & !is.na(v("famille", "lien")) & v("famille", "lien") != "enfant")
  .regle(ctx, "hors_domaine", "famille", "id_sinistre",
         c("famille.id_assure", "sinistres.id_sinistre", "sinistres.id_assure"), "R", "exacte", function() {
    assure <- .joindre(ctx, "sinistres", "id_sinistre", "id_assure", v("famille", "id_sinistre"))
    !is.na(assure) & assure != v("famille", "id_assure")
  })

  # dossiers, rentes, prestations : D10 (a), garantie ou type de prestation incompatible
  lit_gar_dossier <- c("dossiers.id_dossier", "dossiers.id_garantie_souscrite",
                       "garanties_souscrites.id_garantie_souscrite", "garanties_souscrites.code_garantie")
  garantie_du_dossier <- function(id) {
    gs <- .joindre(ctx, "dossiers", "id_dossier", "id_garantie_souscrite", id)
    .joindre(ctx, "garanties_souscrites", "id_garantie_souscrite", "code_garantie", gs)
  }
  .regle(ctx, "D10a", "dossiers", "id_garantie_souscrite",
         c(lit_gar_dossier, "dossiers.id_sinistre", "sinistres.id_sinistre", "sinistres.nature_sinistre"),
         "R", "exacte", function() {
    g <- .joindre(ctx, "garanties_souscrites", "id_garantie_souscrite", "code_garantie",
                  v("dossiers", "id_garantie_souscrite"))
    nat <- .joindre(ctx, "sinistres", "id_sinistre", "nature_sinistre", v("dossiers", "id_sinistre"))
    compatibles <- ifelse(g %in% c("incapacite", "invalidite"), nat == "arret_travail", nat %in% c("deces", "iad"))
    !is.na(g) & !is.na(nat) & !compatibles
  })
  .regle(ctx, "D10a", "rentes", "id_dossier", c("rentes.id_dossier", lit_gar_dossier), "R", "exacte", function() {
    g <- garantie_du_dossier(v("rentes", "id_dossier"))
    !is.na(g) & !(g %in% .GARANTIES_RENTE)
  })
  .regle_condition(ctx, "rentes", "id_membre", c("rentes.id_dossier", lit_gar_dossier), function() {
    g <- garantie_du_dossier(v("rentes", "id_dossier"))
    ifelse(g %in% c("rente_conjoint", "rente_education"), TRUE, ifelse(g %in% "invalidite", FALSE, NA))
  })
  type_p <- v("prestations", "type_prestation")
  .regle(ctx, "D10a", "prestations", "type_prestation", c("prestations.id_dossier", lit_gar_dossier),
         "R", "exacte", function() {
    g <- garantie_du_dossier(v("prestations", "id_dossier"))
    attendu <- ifelse(g == "incapacite", "indemnite_journaliere",
                      ifelse(g %in% .GARANTIES_RENTE, "arrerage", "capital"))
    !is.na(g) & !is.na(type_p) & type_p != attendu
  })
  .regle_condition(ctx, "prestations", "id_rente", "prestations.type_prestation",
                   function() ifelse(is.na(type_p), NA, type_p == "arrerage"))
  .regle(ctx, "hors_domaine", "prestations", "id_rente", c("rentes.id_rente", "rentes.id_dossier",
                                                           "prestations.id_dossier"), "R", "exacte", function() {
    d <- .joindre(ctx, "rentes", "id_rente", "id_dossier", v("prestations", "id_rente"))
    !is.na(d) & !is.na(v("prestations", "id_dossier")) & d != v("prestations", "id_dossier")
  })
  for (colonne in c("debut_periode", "fin_periode")) {
    .regle_condition(ctx, "prestations", colonne, "prestations.type_prestation",
                     function() ifelse(is.na(type_p), NA, type_p != "capital"), defaut_manquant = TRUE)
  }
  .regle_signe(ctx, "prestations", "nature_mouvement",
               list(paiement = "positif", regularisation = "non_nul"))
  .regle_signe(ctx, "cotisations", "nature_mouvement",
               list(emission = "positif", annulation = "negatif", regularisation = "non_nul",
                    encaissement = "non_nul"))

  # beneficiaires
  qualite <- v("beneficiaires", "qualite")
  .regle_condition(ctx, "beneficiaires", "id_membre", "beneficiaires.qualite",
                   function() ifelse(is.na(qualite), NA, qualite %in% c("conjoint_survivant", "enfant_a_charge")))
  .regle(ctx, "hors_domaine", "beneficiaires", "part", character(0), "R", "exacte", function() {
    x <- v("beneficiaires", "part")
    is.finite(x) & (x <= 0 | x > 1)
  })

  # evenements
  type_e <- v("evenements", "type_evenement")
  k <- match(type_e, te$type_evenement)
  niveau <- te$niveau[k]
  .regle_condition(ctx, "evenements", "id_dossier", "evenements.type_evenement", function() {
    ifelse(is.na(niveau), NA, ifelse(niveau == "sinistre", FALSE, ifelse(grepl("sinistre", niveau), NA, TRUE)))
  })
  lit_ev_dossier <- c("evenements.type_evenement", "evenements.id_dossier", lit_gar_dossier)
  .regle_condition(ctx, "evenements", "id_rente", lit_ev_dossier, function() {
    g <- garantie_du_dossier(v("evenements", "id_dossier"))
    rente <- grepl("rente", niveau)
    ifelse(is.na(niveau), NA, ifelse(!rente, FALSE,
           ifelse(g %in% .GARANTIES_RENTE, TRUE, ifelse(g %in% "incapacite", FALSE, NA))))
  })
  .regle(ctx, "hors_domaine", "evenements", "id_dossier",
         c("evenements.id_sinistre", "dossiers.id_dossier", "dossiers.id_sinistre"), "R", "exacte", function() {
    s <- .joindre(ctx, "dossiers", "id_dossier", "id_sinistre", v("evenements", "id_dossier"))
    !is.na(s) & s != v("evenements", "id_sinistre")
  })
  .regle(ctx, "hors_domaine", "evenements", "id_rente",
         c("evenements.id_dossier", "rentes.id_rente", "rentes.id_dossier"), "R", "exacte", function() {
    d <- .joindre(ctx, "rentes", "id_rente", "id_dossier", v("evenements", "id_rente"))
    !is.na(d) & !is.na(v("evenements", "id_dossier")) & d != v("evenements", "id_dossier")
  })
  # type compatible avec la nature du sinistre (niveau sinistre : arrêt de travail) ou avec
  # la garantie du dossier (types_evenements.garanties)
  .regle(ctx, "hors_domaine", "evenements", "type_evenement",
         c(lit_ev_dossier, "evenements.id_sinistre", "sinistres.id_sinistre", "sinistres.nature_sinistre"),
         "R", "exacte", function() {
    nat <- .joindre(ctx, "sinistres", "id_sinistre", "nature_sinistre", v("evenements", "id_sinistre"))
    g <- garantie_du_dossier(v("evenements", "id_dossier"))
    garanties <- te$garanties[k]
    sinistre_seul <- !is.na(niveau) & niveau == "sinistre"
    hors_nature <- sinistre_seul & !is.na(nat) & nat != "arret_travail"
    hors_garantie <- !sinistre_seul & !is.na(g) & !is.na(garanties) & garanties != "toutes" &
      !mapply(function(gg, liste) gg %in% .eclater_champ(liste), g, garanties)
    hors_nature | hors_garantie
  })
  requiert <- function(colonne) {
    ifelse(is.na(k), NA, vapply(te$colonnes_requises[ifelse(is.na(k), 1L, k)],
                                function(r) colonne %in% .eclater_champ(r), NA))
  }
  .regle_condition(ctx, "evenements", "categorie_invalidite", "evenements.type_evenement",
                   function() requiert("categorie_invalidite"), defaut_manquant = TRUE)
  .regle_condition(ctx, "evenements", "montant", "evenements.type_evenement", function() requiert("montant"))
  .hors_bornes(ctx, "evenements", "montant", mini = 0, code = "D09")
  .hors_bornes(ctx, "evenements", "montant_securite_sociale", mini = 0)
  .regle_condition(ctx, "evenements", "source_information", "evenements.type_evenement",
                   function() requiert("source_information"))
  # motif : de la liste du type ; manquant pour sortie ou cloture_dossier sans prestation sur
  # aucun dossier du sinistre (base entière) : D05, règle V ; sinon manquant_obligatoire
  motif <- v("evenements", "motif")
  .regle(ctx, "hors_domaine", "evenements", "motif", "evenements.type_evenement", "R", "exacte", function() {
    !is.na(motif) & !is.na(k) & !mapply(function(m, liste) m %in% .eclater_champ(liste), motif, te$motifs[ifelse(is.na(k), 1L, k)])
  })
  .regle(ctx, "manquant_obligatoire", "evenements", "motif",
         c("evenements.type_evenement", "evenements.id_sinistre", "prestations.id_dossier",
           "dossiers.id_dossier", "dossiers.id_sinistre"), "R", "exacte", function() {
    sinistres_payes <- unique(.joindre(ctx, "dossiers", "id_dossier", "id_sinistre", v("prestations", "id_dossier")))
    d05 <- type_e %in% c("sortie", "cloture_dossier") & !(v("evenements", "id_sinistre") %in% sinistres_payes)
    is.na(motif) & requiert("motif") %in% TRUE & !d05
  })

  # victimes
  .regle_condition(ctx, "victimes", "date_deces", "victimes.statut_victime",
                   function() ifelse(is.na(v("victimes", "statut_victime")), NA, v("victimes", "statut_victime") == "decedee"))
  .regle(ctx, "D10h", "victimes", "id_sinistre", c("victimes.id_assure", "sinistres.id_sinistre", "sinistres.id_assure"),
         "R", "exacte", function() {
    assure <- .joindre(ctx, "sinistres", "id_sinistre", "id_assure", v("victimes", "id_sinistre"))
    !is.na(assure) & !is.na(v("victimes", "id_assure")) & assure != v("victimes", "id_assure")
  })

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
    d <- .joindre(ctx, "affiliations", "id_affiliation", "designation", v("designations", "id_affiliation"))
    v("designations", "id_affiliation") %in% v("affiliations", "id_affiliation") & !(d %in% "nominative")
  })
  .regle(ctx, "hors_domaine", "ayants_droit_sante", "id_affiliation",
         c("affiliations.id_affiliation", "affiliations.sante_organisme"), "R", "exacte", function() {
    s <- .joindre(ctx, "affiliations", "id_affiliation", "sante_organisme", v("ayants_droit_sante", "id_affiliation"))
    v("ayants_droit_sante", "id_affiliation") %in% v("affiliations", "id_affiliation") & !(s %in% TRUE)
  })
  invisible(NULL)
}

# Signe d'un montant selon la nature du mouvement : un signe contraire au domaine est le
# défaut D09 (refus R de la colonne, M145) ; un zéro là où le domaine exige un montant non
# nul (ou strictement positif) n'a pas de signe contraire : hors_domaine.
.regle_signe <- function(ctx, table, colonne_nature, regles) {
  nature <- .valeurs(ctx, table, colonne_nature)
  lit <- paste(table, colonne_nature, sep = ".")
  attendu <- vapply(nature, function(n) if (!is.na(n) && n %in% names(regles)) regles[[n]] else NA_character_, "",
                    USE.NAMES = FALSE)
  .regle(ctx, "D09", table, "montant", lit, "R", "exacte", function() {
    x <- .valeurs(ctx, table, "montant")
    is.finite(x) & ((attendu %in% "positif" & x < 0) | (attendu %in% "negatif" & x > 0))
  })
  .regle(ctx, "hors_domaine", table, "montant", lit, "R", "exacte", function() {
    x <- .valeurs(ctx, table, "montant")
    is.finite(x) & x == 0 & !is.na(attendu)
  })
}

# --- Règle B : clés ------------------------------------------------------------------

# Clé primaire en double (D01a), clés étrangères orphelines (D04a, D04b ; référence
# composite de affiliations.college), chevauchements de versions et de paliers.
.regle_cles <- function(ctx) {
  dico <- ctx$dico
  for (table in setdiff(ctx$tables, "extraction")) {
    cle <- .eclater_champ(dico$tables$cle_primaire[dico$tables$table == table])
    lit <- paste(table, cle, sep = ".")
    .regle(ctx, "D01a", table, cle[1L], lit, "R", "exacte", function() {
      duplicated(as.data.frame(lapply(cle, function(c1) .valeurs(ctx, table, c1)), stringsAsFactors = FALSE))
    })
  }
  .orphelines(ctx)
  .regle(ctx, "chevauchement", "garanties_souscrites", NA_character_,
         paste0("garanties_souscrites.", c("id_contrat", "code_garantie", "college", "date_effet", "date_fin")),
         "R", "exacte", function() {
    v <- function(c1) .valeurs(ctx, "garanties_souscrites", c1)
    fin <- as.numeric(v("date_fin"))
    .chevauchements(paste(v("id_contrat"), v("code_garantie"), v("college"), sep = "\r"),
                    as.numeric(v("date_effet")), ifelse(is.na(fin), Inf, fin))
  })
  .regle(ctx, "chevauchement", "parametres", NA_character_,
         paste0("parametres.", c("id_garantie_souscrite", "parametre", "categorie_invalidite", "age_min", "age_max")),
         "R", "exacte", function() {
    v <- function(c1) .valeurs(ctx, "parametres", c1)
    sans_palier <- is.na(v("age_min"))
    .chevauchements(paste(v("id_garantie_souscrite"), v("parametre"), v("categorie_invalidite"), sep = "\r"),
                    ifelse(sans_palier, 0, as.numeric(v("age_min"))),
                    ifelse(sans_palier, 120, as.numeric(v("age_max"))))
  })
  invisible(NULL)
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
      cibles <- strsplit(.eclater_champ(colonnes$reference[i]), ".", fixed = TRUE)
      table_cible <- cibles[[1L]][1L]
      cols_cible <- vapply(cibles, `[`, "", 2L)
      locales <- if (length(cibles) == 1L) colonne else cols_cible
      code <- if (table == "prestations") "D04a" else "D04b"
      traitement <- if (code == "D04a" || (table %in% .TABLES_D04B_X && length(cibles) == 1L)) "X" else "R"
      lit <- c(paste(table, locales, sep = "."), paste(table_cible, cols_cible, sep = "."))
      manquant_orphelin <- table == "prestations" && colonne == "id_dossier"
      .regle(ctx, code, table, colonne, lit, traitement, "exacte", function() {
        local <- do.call(paste, c(lapply(locales, function(c1) .valeurs(ctx, table, c1)), sep = "\r"))
        cible <- do.call(paste, c(lapply(cols_cible, function(c1) .valeurs(ctx, table_cible, c1)), sep = "\r"))
        # une chaîne vide est chaine_vide, non une orpheline (une anomalie, un code : m1)
        vide <- Reduce(`|`, lapply(locales, function(c1) {
          x <- .valeurs(ctx, table, c1)
          !is.na(x) & is.character(x) & x == ""
        }))
        manquant <- Reduce(`|`, lapply(locales, function(c1) is.na(.valeurs(ctx, table, c1))))
        !vide & (if (manquant_orphelin) manquant | !(local %in% cible) else !manquant & !(local %in% cible))
      })
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
# refusée (portée colonne) non plus ; la cause est le motif du premier refus, dans l'ordre
# des constats.
.refus_regle_b <- function(ctx) {
  tables <- list()
  colonnes <- list()
  directs <- list()
  origines <- list()
  for (k in ctx$constats) {
    if (k$traitement != "R") next
    if (.portee_effective(ctx$dico, k$code, k$table, k$colonne) == "table") {
      if (is.null(tables[[k$table]])) tables[[k$table]] <- k$code
      if (k$code == "refus_induit") origines[[k$table]] <- .eclater_champ(k$origine)
      else directs[[k$table]] <- rbind(directs[[k$table]], data.frame(code = k$code, colonne = k$colonne,
                                                                       stringsAsFactors = FALSE))
    } else {
      c1 <- colonnes[[k$table]]
      if (is.null(c1[[k$colonne]])) c1[[k$colonne]] <- k$code
      colonnes[[k$table]] <- c1
    }
  }
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

# Motif qui empêche une composante de l'enjeu de lire `table.colonne` pour l'écart `ecart`
# (décisions du mainteneur, D7 et D10, lecture d'E2.5), NA si elle se lit : une forme
# illisible, un refus de la colonne, un autre refus direct de portée table de la table. Le
# refus qui constitue l'écart (refus de portée table) ne bloque pas son propre enjeu (D10) :
# il n'empêche que la lecture de sa propre colonne, hors D01a (doublon de clé : chiffré, une
# composante n'étant sans valeur que pour un identifiant dont les lignes en double divergent
# sur une colonne qu'elle lit, .divergences_d01a()) ; un refus induit ne l'empêche pas quand
# il procède seulement du refus de l'écart (la table de l'écart ne porte aucun autre refus
# direct) : la cascade est chiffrée.
.cause_enjeu <- function(ctx, table, colonne, ecart) {
  forme <- .cause(ctx, table, colonne, forme_seule = TRUE)
  if (!is.na(forme)) return(forme)
  c1 <- ctx$refus_pv$colonnes[[table]]
  if (!is.null(c1) && colonne %in% names(c1)) return(c1[[colonne]])
  propre <- !is.null(ecart) && identical(ecart$action, "refus") && !is.na(ecart$table) &&
    .portee_effective(ctx$dico, ecart$motif, ecart$table, ecart$colonne) == "table"
  d <- ctx$refus_pv$directs[[table]]
  if (!is.null(d) && propre && identical(table, ecart$table)) {
    # la clé étrangère refusée qui constitue l'écart (D04a, D04b, D10 (a) et (h)) se lit : le
    # lien n'est pas résolu, la composante se calcule sur ce qui est connu sans la parente
    # (réserve Q4) ; toute autre colonne de l'écart reste illisible
    lien <- ecart$motif %in% .MOTIFS_LIEN_ECART &&
      any(nzchar(ctx$dico$colonnes$reference[ctx$dico$colonnes$table == table & ctx$dico$colonnes$colonne %in% colonne]))
    if (ecart$motif != "D01a" && identical(colonne, ecart$colonne) && !lien) return(ecart$motif)
    d <- d[!(d$code == ecart$motif & d$colonne %in% ecart$colonne), , drop = FALSE]
  }
  if (!is.null(d) && nrow(d) > 0L) return(d$code[1L])
  r <- ctx$refus_pv$racines[[table]]
  if (is.null(r)) return(NA_character_)
  # cascade chiffrée si elle ne procède que du refus de l'écart : la racine est la table de
  # l'écart et n'y porte aucun autre refus direct (réserve Q-b)
  if (!propre || !identical(r, ecart$table)) return("refus_induit")
  dr <- ctx$refus_pv$directs[[r]]
  autre <- !is.null(dr) && any(!(dr$code == ecart$motif & dr$colonne %in% ecart$colonne))
  if (autre) "refus_induit" else NA_character_
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

.vue_totale <- function(ctx) as.numeric(ctx$arrete) == as.numeric(ctx$date_extraction)

# Règle P et visibilité propre, jusqu'au point fixe des refus qu'elle induit (décision du
# mainteneur, D12) : à un arrêté antérieur à l'extraction, une règle P empêchée sur une table
# lue par la vue (colonne lue refusée ou illisible : .regle()) rend la visibilité de toutes
# ses lignes inconnue ; la table reçoit un refus induit de portée table (`refus_induit`,
# origine : la colonne « table.colonne » qui empêche la règle), propagé à ses filles par
# les clés étrangères comme les refus induits de la règle B (origine : la table visée).
# Les règles P sont alors rejouées sur la base des refus complétés (les constats et
# contrôles non exécutés du passage précédent sont retirés, hors les règles P empêchées,
# qui gardent leur cause) ; la vue reste provisoire (`p_refusees` : tables refusées par une
# règle P empêchée).
.regle_p <- function(ctx) {
  constats <- ctx$constats
  non_executes <- ctx$non_executes
  ctx$p_refusees <- character(0)
  repeat {
    .visibilite_propre(ctx)
    .regle_prealable(ctx)
    if (length(ctx$p_empechees) == 0L) break
    empechees <- ctx$p_empechees
    ctx$constats <- constats
    # la règle P empêchée garde sa cause d'origine dans controles_non_executes (premier
    # contrôle non exécuté de même clé retenu par .bilan())
    ctx$non_executes <- c(non_executes, ctx$p_entrees)
    non_executes <- ctx$non_executes
    .refus_p_empechee(ctx, empechees)
    constats <- ctx$constats
    .refus_regle_b(ctx)
  }
  invisible(NULL)
}

# Refus induits d'une règle P empêchée (D12, .regle_p()) : `empechees`, liste nommée par
# table des colonnes « table.colonne » en cause ; propagation aux tables qui visent une
# table ainsi refusée par une clé étrangère, hors tables déjà refusées en portée table.
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
    .ajouter_constat(ctx, "refus_induit", t, NA_character_, seq_len(nrow(ctx$base[[t]])),
                     .traitement_code_controle(dico, "refus_induit"), "exacte", origine = paste(o, collapse = ";"))
  }
  ctx$p_refusees <- unique(c(ctx$p_refusees, names(empechees)))
  invisible(NULL)
}

# Visibilité propre de chaque ligne à l'arrêté (sans la règle 1), et colonnes lues pour
# l'établir (`lit_propre`, vide à l'arrêté égal à l'extraction, où tout est visible :
# règle 3 du § 6). Appelée avant la règle P.
.visibilite_propre <- function(ctx) {
  totale <- .vue_totale(ctx)
  a <- as.numeric(ctx$arrete)
  ctx$propre <- list()
  ctx$lit_propre <- list()
  ctx$non_determine <- list()
  ctx$partie_nd <- list()
  ctx$date_h <- list()
  ctx$exclu_g <- list()
  for (table in setdiff(ctx$tables, "extraction")) {
    n <- nrow(ctx$base[[table]])
    vis <- rep(TRUE, n)
    dates <- .DATES_VISIBILITE[[table]]
    if (!totale) {
      for (colonne in dates) {
        x <- if (is.na(.cause(ctx, table, colonne))) as.numeric(.valeurs(ctx, table, colonne)) else rep(NA_real_, n)
        vis <- vis & !is.na(x) & x <= a
      }
      ctx$lit_propre[[table]] <- if (length(dates)) paste(table, dates, sep = ".") else character(0)
    }
    ctx$propre[[table]] <- vis
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
# n'est pas unique : versions de famille), NA si la parente n'existe pas.
.date_parente <- function(cle, cle_parente, date_parente) {
  o <- order(as.numeric(date_parente), na.last = TRUE, method = "radix")
  as.numeric(date_parente)[o][match(cle, cle_parente[o], incomparables = NA)]
}

# Règle P (spécification, § 2.2) : D02b et D03g, détectés sur la base entière après la
# règle B. À l'arrêté égal à l'extraction, ils sont des signalements (S, règle I) ; à un
# arrêté antérieur, D02b attend son hypothèse (H) et D03g son hypothèse ou son exclusion
# (H ou X). Leurs lignes sont alors de visibilité non déterminée (M156) : tenues hors de la
# vue et recensées dans vue$visibilite_non_determinee (colonne NA) ; quand seule une partie
# de ligne est en cause (fin d'un contrat ou d'une affiliation : date_saisie_fin manquante,
# ou fin d'un contrat saisie avant son effet), la ligne reste dans la vue, la partie est
# masquée (.valeurs_vue()) et recensée sous sa colonne (décision du mainteneur, D1). Une
# règle P non exécutée à un arrêté antérieur sur une table lue par la vue (non refusée en
# portée table) rend la vue provisoire (`p_non_executee`). Une hypothèse de D02b déclarée
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
  hyp <- ctx$declarations$hypotheses
  h_d02b <- all(REFERENTIELS %in% hyp$referentiel[hyp$motif == "D02b"])
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
        ctx$propre[[table]][lignes] <- ctx$propre[[table]][lignes] & !is.na(d) & d <= as.numeric(ctx$arrete)
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
        ctx$propre[[table]][lignes] <- FALSE
        return(invisible(NULL))
      }
      if (identical(application, "H")) {
        ctx$h_g[[length(ctx$h_g) + 1L]] <- list(table = table, partie = partie, lignes = lignes)
        return(invisible(NULL))
      }
    }
    nd(table, partie, motif, lignes)
  }
  nd <- function(table, partie, motif, lignes) {
    if (is.na(partie)) ctx$non_determine[[table]][lignes] <- TRUE else ctx$partie_nd[[table]][lignes] <- TRUE
    ctx$lignes_nd[[length(ctx$lignes_nd) + 1L]] <- list(table = table, colonne = partie, motif = motif, lignes = lignes)
    invisible(NULL)
  }
  ctx$lignes_nd <- list()
  ctx$p_non_executee <- FALSE
  ctx$p_empechees <- list()
  ctx$p_entrees <- list()
  ctx$h_g <- list()
  avant <- function(x, y) { x <- as.numeric(x); y <- as.numeric(y); !is.na(x) & !is.na(y) & x < y }

  # D02b : saisie antérieure au fait que la ligne enregistre
  marquer("evenements", "D02b", .regle(ctx, "D02b", "evenements", "date_saisie",
    c("evenements.date_effet", "evenements.type_evenement", "evenements.motif"), t_b, "exacte",
    function() avant(v("evenements", "date_saisie"), v("evenements", "date_effet")) & !.programmable(ctx)),
    date_h = "date_effet")
  marquer("sinistres", "D02b", .regle(ctx, "D02b", "sinistres", "date_saisie", "sinistres.date_declaration",
    t_b, "exacte", function() avant(v("sinistres", "date_saisie"), v("sinistres", "date_declaration"))),
    date_h = "date_declaration")
  marquer("catastrophes", "D02b", .regle(ctx, "D02b", "catastrophes", "date_saisie", "catastrophes.date_evenement",
    t_b, "exacte", function() avant(v("catastrophes", "date_saisie"), v("catastrophes", "date_evenement"))),
    date_h = "date_evenement")
  # fin d'un contrat saisie avant que le contrat soit visible (partie de ligne saisie avant
  # sa ligne)
  marquer("contrats", "D02b", .regle(ctx, "D02b", "contrats", "date_saisie_fin", "contrats.date_effet",
    t_b, "exacte", function() avant(v("contrats", "date_saisie_fin"), v("contrats", "date_effet"))), "date_saisie_fin")
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
    list("victimes", "date_saisie", "id_catastrophe", "catastrophes", "id_catastrophe", "date_saisie"),
    list("victimes", "date_saisie", "id_sinistre", "sinistres", "id_sinistre", "date_saisie"))
  for (f in filles) {
    if (!(f[[4L]] %in% ctx$tables)) next
    marquer(f[[1L]], "D02b", .regle(ctx, "D02b", f[[1L]], f[[2L]],
      c(paste(f[[1L]], f[[3L]], sep = "."), paste(f[[4L]], c(f[[5L]], f[[6L]]), sep = ".")), t_b, "exacte",
      function() avant(v(f[[1L]], f[[2L]]), .date_parente(v(f[[1L]], f[[3L]]), v(f[[4L]], f[[5L]]), v(f[[4L]], f[[6L]])))))
  }
  # D03g : date de saisie manquante (fin d'un contrat ou d'une affiliation : sous sa condition)
  for (table in c("affiliations", "famille", "sinistres", "beneficiaires", "rentes", "evenements", "prestations",
                  "designations", "ayants_droit_sante")) {
    marquer(table, "D03g", .regle(ctx, "D03g", table, "date_saisie", character(0), t_g, "exacte",
                                  function() is.na(v(table, "date_saisie"))))
  }
  # partie de ligne : l'hypothèse seule la résout (D9) ; traitement H à un arrêté antérieur
  for (table in c("contrats", "affiliations")) {
    marquer(table, "D03g", .regle(ctx, "D03g", table, "date_saisie_fin", paste0(table, ".date_fin"), t_b, "exacte",
      function() is.na(v(table, "date_saisie_fin")) & !is.na(v(table, "date_fin"))), "date_saisie_fin")
  }
  .appliquer_h_d03g(ctx, nd)
  invisible(NULL)
}

# Hypothèse déclarée de D03g appliquée à la vue (décision du mainteneur, D5 ; jugement
# d'expert) : la date de saisie manquante est remplacée par max(date d'effet + délai,
# visibilité de la parente), la date d'effet étant celle que compare D02b (evenements :
# date_effet ; sinistres : date_declaration ; table fille : visibilité de la parente, d'où
# visibilité de la parente + délai) ; délai de seuils$d03g_delai_jours pour la table. Fin
# d'un contrat ou d'une affiliation (partie de ligne) : connue à date_fin + délai (erratum
# de D5, D9). Visibilité d'une parente : max des dates de .DATES_VISIBILITE de la
# ligne et de ses ascendantes (règle 1), NA si l'une est inconnue ; versions de famille : la
# plus ancienne. Une date qui ne se calcule pas laisse la ligne de visibilité non
# déterminée (`nd`, motif D03g ; `ctx$reste_g` : ces lignes, par table, hors de l'hypothèse
# placée et attendues en exclusion, réserve Q5), sauf si seule sa parente est non
# déterminée (motif parente_non_determinee, sans exigence propre, réserve Q2 (b)). Rend
# `ctx$date_g` (date de saisie retenue, par table) et `ctx$partie_h` (date de connaissance
# de la fin retenue).
.appliquer_h_d03g <- function(ctx, nd) {
  if (length(ctx$h_g) == 0L) return(invisible(NULL))
  a <- as.numeric(ctx$arrete)
  liens <- .liens_visibilite(ctx$dico)
  liens <- liens[liens$table %in% ctx$tables & liens$table_cible %in% ctx$tables, , drop = FALSE]
  lisible <- function(t, c1) is.na(.cause(ctx, t, c1, forme_seule = TRUE))
  lire <- function(t, c1) if (lisible(t, c1)) as.numeric(.valeurs(ctx, t, c1)) else rep(NA_real_, nrow(ctx$base[[t]]))
  delai <- ctx$declarations$seuils[[.SEUIL_DELAI_D03G]]
  tables <- setdiff(ctx$tables, "extraction")
  # date de saisie retenue (NA hors hypothèse) ; dates propres de visibilité de chaque ligne
  for (t in tables) ctx$date_g[[t]] <- rep(NA_real_, nrow(ctx$base[[t]]))
  propre_date <- function(t) {
    x <- rep(-Inf, nrow(ctx$base[[t]]))
    for (c1 in .DATES_VISIBILITE[[t]]) {
      d <- lire(t, c1)
      if (c1 == "date_saisie") d <- ifelse(is.na(ctx$date_g[[t]]), d, ctx$date_g[[t]])
      x <- pmax(x, d)
    }
    dh <- ctx$date_h[[t]]
    if (!is.null(dh)) x <- pmax(x, ifelse(is.na(dh), -Inf, dh))
    x
  }
  # visibilité de la parente de chaque ligne (max sur les liens ; -Inf sans parente)
  date_parente <- function(vd, t) {
    x <- rep(-Inf, nrow(ctx$base[[t]]))
    for (i in which(liens$table == t)) {
      u <- liens$table_cible[i]
      if (!lisible(t, liens$colonne[i]) || !lisible(u, liens$colonne_cible[i])) return(rep(NA_real_, length(x)))
      cle <- .valeurs(ctx, t, liens$colonne[i])
      p <- .date_parente(cle, .valeurs(ctx, u, liens$colonne_cible[i]), vd[[u]])
      orpheline <- is.na(cle) | !(cle %in% .valeurs(ctx, u, liens$colonne_cible[i]))
      x <- pmax(x, ifelse(orpheline, -Inf, p))
    }
    x
  }
  effet <- list(evenements = "date_effet", sinistres = "date_declaration")
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
      ok <- h$lignes[!is.na(g)]
      # visibilité propre recalculée avec la date de saisie retenue
      vis <- rep(TRUE, length(ok))
      for (c1 in .DATES_VISIBILITE[[t]]) {
        d <- if (c1 == "date_saisie") ctx$date_g[[t]][ok] else lire(t, c1)[ok]
        vis <- vis & !is.na(d) & d <= a
      }
      ctx$propre[[t]][ok] <- vis
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

# Vue à l'arrêté (dictionnaire, § 6 ; spécification, § 2.2) : lignes retenues pour la règle
# V (`retenu`) = visibilité propre, hors lignes de visibilité non déterminée, puis règle 1
# (une fille n'est retenue que si sa parente existante l'est ; une orpheline garde sa
# condition propre : la vue n'écarte aucune ligne faute de parente) ; dans famille, seule la
# dernière saisie retenue de chaque membre est valable ; adherents et assures sont retenus
# s'ils sont référencés par une ligne retenue. À l'arrêté égal à l'extraction, la vue est
# la base entière (règle 3), famille réduite à ses lignes valables. Les filles écartées par
# la règle 1 d'une ligne de visibilité non déterminée sont recensées sous le motif
# `parente_non_determinee` (décision du mainteneur, D1). `lit_vue` : colonnes lues pour
# établir la vue d'une table (visibilité de la table et de ses ascendantes, clés des liens ;
# famille : id_membre et date_saisie, à tout arrêté).
.construire_vue <- function(ctx) {
  totale <- .vue_totale(ctx)
  liens <- .liens_visibilite(ctx$dico)
  liens <- liens[liens$table %in% ctx$tables & liens$table_cible %in% ctx$tables, , drop = FALSE]
  tables <- setdiff(ctx$tables, "extraction")
  depart <- lapply(tables, function(t) ctx$propre[[t]] & !ctx$non_determine[[t]])
  names(depart) <- tables
  retenu <- .propager_vue(ctx, liens, depart, totale)
  if (!totale) {
    # lignes que la règle 1 n'écarte qu'à cause d'une parente de visibilité non déterminée
    sans_nd <- .propager_vue(ctx, liens, depart, totale, ctx$non_determine)
    for (t in tables) {
      lignes <- which(sans_nd[[t]] & !retenu[[t]])
      if (length(lignes) > 0L) {
        ctx$lignes_nd[[length(ctx$lignes_nd) + 1L]] <- list(table = t, colonne = NA_character_,
                                                            motif = "parente_non_determinee", lignes = lignes)
      }
    }
  }
  if ("famille" %in% ctx$tables && is.na(.cause(ctx, "famille", "date_saisie")) &&
      is.na(.cause(ctx, "famille", "id_membre"))) {
    membre <- as.character(.valeurs(ctx, "famille", "id_membre"))
    membre[is.na(membre)] <- paste0("\r", which(is.na(membre)))   # un manquant : un membre à part
    r <- retenu$famille
    saisie <- ifelse(r, as.numeric(.valeurs(ctx, "famille", "date_saisie")), NA_real_)
    derniere <- stats::ave(saisie, membre, FUN = function(z) if (all(is.na(z))) NA_real_ else max(z, na.rm = TRUE))
    retenu$famille <- r & (is.na(derniere) | (!is.na(saisie) & saisie == derniere))
  }
  references <- list(adherents = list(c("contrats", "id_adherent")),
                     assures = list(c("contrats", "id_assure"), c("affiliations", "id_assure"), c("famille", "id_assure"),
                                    c("famille", "id_assure_membre"), c("sinistres", "id_assure"),
                                    c("victimes", "id_assure"), c("ayants_droit_sante", "id_assure_membre")))
  for (t in intersect(names(references), ctx$tables)) {
    if (totale) next
    cle <- .valeurs(ctx, t, .eclater_champ(ctx$dico$tables$cle_primaire[ctx$dico$tables$table == t])[1L])
    cites <- unlist(lapply(references[[t]], function(r) {
      if (r[1L] %in% ctx$tables) .valeurs(ctx, r[1L], r[2L])[retenu[[r[1L]]]]
    }))
    retenu[[t]] <- retenu[[t]] & cle %in% cites[!is.na(cites)]
  }
  ctx$retenu <- retenu
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

# Règle 1 du § 6, jusqu'au point fixe : une fille n'est retenue que si sa parente existante
# l'est. `visibles_en_plus` : lignes tenues pour visibles comme parentes sans être retenues
# elles-mêmes (lignes de visibilité non déterminée, pour recenser leurs filles).
.propager_vue <- function(ctx, liens, retenu, totale, visibles_en_plus = NULL) {
  parentes <- function(u) if (is.null(visibles_en_plus)) retenu[[u]] else retenu[[u]] | visibles_en_plus[[u]]
  repeat {
    change <- FALSE
    for (i in seq_len(nrow(liens))) {
      t <- liens$table[i]
      u <- liens$table_cible[i]
      if (is.na(.cause(ctx, t, liens$colonne[i])) && is.na(.cause(ctx, u, liens$colonne_cible[i]))) {
        cle <- .valeurs(ctx, t, liens$colonne[i])
        cible <- .valeurs(ctx, u, liens$colonne_cible[i])
        parente <- is.na(cle) | !(cle %in% cible) | cle %in% cible[parentes(u)]
      } else {
        parente <- rep(totale, length(retenu[[t]]))
      }
      nouveau <- retenu[[t]] & parente
      if (!identical(nouveau, retenu[[t]])) {
        retenu[[t]] <- nouveau
        change <- TRUE
      }
    }
    if (!change) break
  }
  retenu
}

# Valeurs d'une colonne dans la vue : manquantes pour une ligne non retenue et pour une
# partie de ligne inconnue à l'arrêté (fin d'un contrat ou d'une affiliation saisie après,
# ou de saisie non déterminée ; instruction postérieure) ; une jointure sur ces valeurs ne
# voit donc que la vue.
.valeurs_vue <- function(ctx, table, colonne) {
  x <- .valeurs(ctx, table, colonne)
  masque <- !ctx$retenu[[table]]
  if (!.vue_totale(ctx)) {
    a <- as.numeric(ctx$arrete)
    for (p in .PARTIES_LIGNE) {
      if (p$table == table && colonne %in% p$colonnes) {
        d <- as.numeric(.valeurs(ctx, table, p$date))
        # fin connue à la date que retient l'hypothèse déclarée de D03g
        dh <- ctx$partie_h[[table]]
        if (!is.null(dh) && p$date == "date_saisie_fin") d <- ifelse(is.na(dh), d, dh)
        masque <- masque | is.na(d) | d > a | (p$date == "date_saisie_fin" & ctx$partie_nd[[table]])
      }
    }
  }
  x[masque] <- NA
  x
}

# Règle de la règle V : comme .regle(), sur les seules lignes retenues par la vue ; une
# table refusée, ou une colonne inutilisable lue pour établir la vue, empêche la règle
# (cause : son motif).
.regle_vue <- function(ctx, code, table, colonne, lit, traitement, detection, f, colonne_ne = colonne) {
  if (is.null(ctx$base[[table]])) return(invisible(integer(0)))
  cle <- paste(table, .eclater_champ(ctx$dico$tables$cle_primaire[ctx$dico$tables$table == table])[1L], sep = ".")
  .regle(ctx, code, table, colonne, c(lit, cle, ctx$lit_vue[[table]]), traitement, detection, function() {
    r <- f()
    !is.na(r) & r & ctx$retenu[[table]]
  }, colonne_ne)
}

# Visibilité non déterminée (M156, D1) : une ligne par (table, colonne, motif) ; colonne NA
# pour la ligne entière, sinon colonne de la partie de ligne ; ordre du dictionnaire (tables,
# colonnes, NA en tête), puis du motif.
.visibilite_non_determinee <- function(ctx) {
  nd <- ctx$lignes_nd
  df <- data.frame(table = vapply(nd, `[[`, "", "table"), colonne = vapply(nd, function(k) k$colonne, ""),
                   motif = vapply(nd, `[[`, "", "motif"), nombre = integer(length(nd)),
                   identifiants = character(length(nd)), stringsAsFactors = FALSE)
  if (nrow(df) == 0L) return(df)
  cles <- paste(df$table, df$colonne, df$motif, sep = "\r")
  groupes <- split(seq_along(nd), factor(cles, levels = unique(cles)))
  df <- df[vapply(groupes, `[`, 0L, 1L), , drop = FALSE]
  lignes <- lapply(groupes, function(g) sort(unique(unlist(lapply(nd[g], `[[`, "lignes")))))
  df$nombre <- vapply(lignes, length, 0L, USE.NAMES = FALSE)
  df$identifiants <- vapply(seq_along(lignes), function(i) .identifiants(ctx, df$table[i], lignes[[i]]), "")
  .trier(df, ctx$dico, "motif")
}

# --- Règle V ---------------------------------------------------------------------------

# Défauts traités X, H ou S, hors D02b et D03g, détectés sur la vue à l'arrêté (spécification,
# § 2.2). Le traitement d'un constat est la liste des traitements admis par le § 9 pour le
# sous-cas (« X;H »...) quand le choix revient à une déclaration ; R et S sont placés par
# .bilan(), les autres par .placer().
.regle_v <- function(ctx) {
  # somme des parts des bénéficiaires d'un dossier différente de 1 (§ 3, T11) : signalement
  .regle_vue(ctx, "somme_parts", "beneficiaires", "part", "beneficiaires.id_dossier",
             .traitement_code_controle(ctx$dico, "somme_parts"), "exacte", function() {
    part <- .valeurs_vue(ctx, "beneficiaires", "part")
    dossier <- as.character(.valeurs_vue(ctx, "beneficiaires", "id_dossier"))
    ok <- !is.na(dossier)
    if (!any(ok)) return(rep(FALSE, length(part)))
    somme <- rowsum(part[ok], dossier[ok])
    s <- somme[match(dossier, rownames(somme)), 1L]
    !is.na(s) & abs(s - 1) > .TOLERANCE_PARTS
  })
  .regle_v_manquants(ctx)
  .regle_v_ordre_dates(ctx)
  .regle_v_doublons(ctx)
  .regle_v_clotures(ctx)
  .regle_v_garanties(ctx)
  .regle_v_ages(ctx)
  .regle_v_limite_age(ctx)
  invisible(NULL)
}

# Manquants qui ont un défaut au § 9 (D03a, D03b, D03c, D03e, D03f, D03h), sur la vue.
# D03d (situation de famille requise par un poste) dépend des postes du plan : B2.
.regle_v_manquants <- function(ctx) {
  vv <- function(table, colonne) .valeurs_vue(ctx, table, colonne)
  # D03a : date de naissance manquante (famille : hors enfant à naître) ; X ou H pour les
  # familles qui lisent la colonne, S pour la famille triangle (.EXCEPTIONS_FAMILLE) : deux
  # constats de même clé, le signalement écrit dès la détection, comme D01b (réserve Q2)
  for (t in c("S", "X;H")) {
    .regle_vue(ctx, "D03a", "assures", "date_naissance", character(0), t, "exacte",
               function() is.na(vv("assures", "date_naissance")))
    .regle_vue(ctx, "D03a", "famille", "date_naissance", "famille.situation", t, "exacte",
               function() is.na(vv("famille", "date_naissance")) & !(vv("famille", "situation") %in% "a_naitre"))
  }
  # D03b : sexe manquant
  for (table in c("assures", "famille")) {
    .regle_vue(ctx, "D03b", table, "sexe", character(0), "H", "exacte", function() is.na(vv(table, "sexe")))
  }
  # D03c : salaire de référence manquant
  .regle_vue(ctx, "D03c", "affiliations", "salaire_reference", character(0), "X;H", "exacte",
             function() is.na(vv("affiliations", "salaire_reference")))
  # D03e : catégorie d'invalidité manquante pour un type qui l'exige (§ 4)
  te <- ctx$dico$types_evenements
  .regle_vue(ctx, "D03e", "evenements", "categorie_invalidite", "evenements.type_evenement", "H", "exacte", function() {
    k <- match(vv("evenements", "type_evenement"), te$type_evenement)
    exige <- !is.na(k) & grepl("(^|;)categorie_invalidite(;|$)", te$colonnes_requises[ifelse(is.na(k), 1L, k)])
    exige & is.na(vv("evenements", "categorie_invalidite"))
  })
  # D03f : période couverte manquante (prestations : indemnités journalières et arrérages)
  .regle_vue(ctx, "D03f", "prestations", NA_character_,
             paste0("prestations.", c("type_prestation", "debut_periode", "fin_periode")), "X;H", "exacte", function() {
    type <- vv("prestations", "type_prestation")
    type %in% c("indemnite_journaliere", "arrerage") &
      (is.na(vv("prestations", "debut_periode")) | is.na(vv("prestations", "fin_periode")))
  })
  .regle_vue(ctx, "D03f", "cotisations", NA_character_, paste0("cotisations.", c("debut_periode", "fin_periode")),
             "X;H", "exacte", function() {
    is.na(vv("cotisations", "debut_periode")) | is.na(vv("cotisations", "fin_periode"))
  })
  # D03h : taux du tarif manquant là où il est requis (§ 3, T4) : décès d'un contrat
  # individuel, rente de conjoint, rente d'éducation, double effet. Le maintien de la
  # garantie décès d'un contrat collectif n'est pas lisible dans la base : sous-cas non
  # exécuté, cause non_lisible (D2).
  if (!is.null(ctx$base$garanties_souscrites)) {
    .ajouter_non_execute(ctx, "D03h", "garanties_souscrites", NA_character_, CAUSE_NON_LISIBLE)
  }
  .regle_vue(ctx, "D03h", "garanties_souscrites", "taux_technique_tarif",
             c("garanties_souscrites.code_garantie", "garanties_souscrites.id_contrat", "contrats.id_contrat",
               "contrats.nature_contrat"), "H", "exacte", function() {
    code <- vv("garanties_souscrites", "code_garantie")
    nature <- .joindre(ctx, "contrats", "id_contrat", "nature_contrat", vv("garanties_souscrites", "id_contrat"))
    requis <- code %in% c("rente_conjoint", "rente_education", "double_effet") | (code %in% "deces" & nature %in% "individuel")
    requis & is.na(vv("garanties_souscrites", "taux_technique_tarif"))
  })
  invisible(NULL)
}

# D02a : ordre des dates violé (dictionnaire, § 9), sur la vue ; la colonne du constat est
# la date qui devrait être la plus tardive. Un enfant à naître n'est jamais rejeté.
.regle_v_ordre_dates <- function(ctx) {
  vv <- function(table, colonne) as.numeric(.valeurs_vue(ctx, table, colonne))
  apres <- function(x, y) !is.na(x) & !is.na(y) & x > y
  t <- "X;H"
  # date_debut > date_fin : contrats, versions de garanties, affiliations, ayants droit
  # santé ; termes et début de gestion d'un contrat avant son effet
  .regle_vue(ctx, "D02a", "contrats", "date_fin", "contrats.date_effet", t, "exacte",
             function() apres(vv("contrats", "date_effet"), vv("contrats", "date_fin")))
  .regle_vue(ctx, "D02a", "contrats", "date_terme", "contrats.date_effet", t, "exacte",
             function() apres(vv("contrats", "date_effet"), vv("contrats", "date_terme")))
  .regle_vue(ctx, "D02a", "contrats", "date_debut_gestion", "contrats.date_effet", t, "exacte",
             function() apres(vv("contrats", "date_effet"), vv("contrats", "date_debut_gestion")))
  .regle_vue(ctx, "D02a", "garanties_souscrites", "date_fin", "garanties_souscrites.date_effet", t, "exacte",
             function() apres(vv("garanties_souscrites", "date_effet"), vv("garanties_souscrites", "date_fin")))
  .regle_vue(ctx, "D02a", "affiliations", "date_fin", "affiliations.date_debut", t, "exacte",
             function() apres(vv("affiliations", "date_debut"), vv("affiliations", "date_fin")))
  .regle_vue(ctx, "D02a", "ayants_droit_sante", "fin_couverture", "ayants_droit_sante.debut_couverture", t, "exacte",
             function() apres(vv("ayants_droit_sante", "debut_couverture"), vv("ayants_droit_sante", "fin_couverture")))
  # debut_periode > fin_periode
  for (table in c("prestations", "cotisations")) {
    .regle_vue(ctx, "D02a", table, "fin_periode", paste0(table, ".debut_periode"), t, "exacte",
               function() apres(vv(table, "debut_periode"), vv(table, "fin_periode")))
  }
  # sinistres : naissance de l'assuré après la survenance ; survenance > déclaration >
  # instruction (instruction connue à l'arrêté)
  .regle_vue(ctx, "D02a", "sinistres", "date_survenance",
             c("sinistres.id_assure", "assures.id_assure", "assures.date_naissance"), t, "exacte", function() {
    naissance <- .joindre(ctx, "assures", "id_assure", "date_naissance", .valeurs_vue(ctx, "sinistres", "id_assure"))
    apres(as.numeric(naissance), vv("sinistres", "date_survenance"))
  })
  .regle_vue(ctx, "D02a", "sinistres", "date_declaration", "sinistres.date_survenance", t, "exacte",
             function() apres(vv("sinistres", "date_survenance"), vv("sinistres", "date_declaration")))
  .regle_vue(ctx, "D02a", "sinistres", "date_instruction", "sinistres.date_declaration", t, "exacte",
             function() apres(vv("sinistres", "date_declaration"), vv("sinistres", "date_instruction")))
  # famille : naissance après la survenance du sinistre rattaché (hors enfant à naître)
  .regle_vue(ctx, "D02a", "famille", "date_naissance",
             c("famille.situation", "famille.id_sinistre", "sinistres.id_sinistre", "sinistres.date_survenance"), t,
             "exacte", function() {
    survenance <- .joindre(ctx, "sinistres", "id_sinistre", "date_survenance", .valeurs_vue(ctx, "famille", "id_sinistre"))
    apres(vv("famille", "date_naissance"), as.numeric(survenance)) &
      !(.valeurs_vue(ctx, "famille", "situation") %in% "a_naitre")
  })
  # evenements : premier état d'un sinistre (entrée en incapacité ou en invalidité) à une
  # autre date que la survenance ; mise à jour hors de [survenance, extraction]
  .regle_vue(ctx, "D02a", "evenements", "date_effet",
             c("evenements.type_evenement", "evenements.id_sinistre", "sinistres.id_sinistre", "sinistres.date_survenance"),
             t, "exacte", function() {
    type <- .valeurs_vue(ctx, "evenements", "type_evenement")
    effet <- vv("evenements", "date_effet")
    survenance <- as.numeric(.joindre(ctx, "sinistres", "id_sinistre", "date_survenance",
                                      .valeurs_vue(ctx, "evenements", "id_sinistre")))
    premier <- type %in% c("entree_incapacite", "entree_invalidite") & !is.na(effet) & !is.na(survenance) &
      effet != survenance
    maj <- type %in% "mise_a_jour" & !is.na(effet) & !is.na(survenance) &
      (effet < survenance | effet > as.numeric(ctx$date_extraction))
    premier | maj
  })
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
    cle <- .eclater_champ(ctx$dico$tables$cle_primaire[ctx$dico$tables$table == table])[1L]
    copies <- function() {
      retenu <- ctx$retenu[[table]]
      o <- order(as.numeric(.valeurs(ctx, table, date)), .valeurs(ctx, table, cle), method = "radix", na.last = TRUE)
      o <- o[retenu[o]]
      contenu <- as.data.frame(lapply(colonnes, function(c1) .valeurs(ctx, table, c1)[o]), stringsAsFactors = FALSE)
      # une ligne de même clé que la précédente est un doublon d'identifiant (D01a), non une
      # copie sous un nouvel identifiant
      meme_cle <- duplicated(data.frame(contenu, .cle = .valeurs(ctx, table, cle)[o], stringsAsFactors = FALSE))
      copie <- rep(FALSE, length(retenu))
      copie[o[duplicated(contenu) & !meme_cle]] <- TRUE
      copie
    }
    for (t in c("S", "X")) {
      .regle_vue(ctx, "D01b", table, NA_character_, paste(table, c(colonnes, date, cle), sep = "."), t, "exacte", copies)
    }
  }
  invisible(NULL)
}

# Clôtures et instruction : D05, D06, D13 (dictionnaire, § 9), sur la vue.
.regle_v_clotures <- function(ctx) {
  vv <- function(table, colonne) .valeurs_vue(ctx, table, colonne)
  type <- function() vv("evenements", "type_evenement")
  motif <- function() vv("evenements", "motif")
  # D05 : sortie ou clôture au motif manquant, sans prestation sur aucun dossier du
  # sinistre ; D05 sur la vue, sauf les lignes déjà refusées par manquant_obligatoire en
  # règle B (motif manquant avec une prestation du sinistre dans la base entière) : la vue
  # étant incluse dans la base, l'absence de prestation se lit sur la base entière
  .regle_vue(ctx, "D05", "evenements", "motif",
             c("evenements.type_evenement", "evenements.id_sinistre", "prestations.id_dossier", "dossiers.id_dossier",
               "dossiers.id_sinistre"), "H;S", "exacte", function() {
    payes <- unique(.joindre(ctx, "dossiers", "id_dossier", "id_sinistre", .valeurs(ctx, "prestations", "id_dossier")))
    type() %in% c("sortie", "cloture_dossier") & is.na(motif()) & !(vv("evenements", "id_sinistre") %in% payes)
  })
  # D06 : clôture sans justificatif ; clôture `regle` sans prestation du dossier, ou
  # `depot_cdc` sans prestation `capital` (prestations visibles à l'arrêté)
  .regle_vue(ctx, "D06", "evenements", "justificatif",
             c("evenements.type_evenement", "evenements.motif", "evenements.id_dossier", "prestations.id_dossier",
               "prestations.type_prestation", ctx$lit_vue$prestations), "H;S", "exacte", function() {
    sans_justificatif <- is.na(vv("evenements", "justificatif")) &
      ((type() %in% "sortie" & motif() %in% c("reprise_travail", "deces")) |
         (type() %in% "fin_service" & motif() %in% "deces_beneficiaire"))
    dossier <- vv("evenements", "id_dossier")
    payes <- vv("prestations", "id_dossier")
    capital <- payes[vv("prestations", "type_prestation") %in% "capital"]
    cloture <- type() %in% "cloture_dossier" &
      ((motif() %in% "regle" & !(dossier %in% payes[!is.na(payes)])) |
         (motif() %in% "depot_cdc" & !(dossier %in% capital[!is.na(capital)])))
    sans_justificatif | cloture
  })
  # D13 : instruction absente (à l'arrêté) d'un sinistre décès dont le dossier `deces` a une
  # prestation `capital` visible
  .regle_vue(ctx, "D13", "sinistres", "date_instruction",
             c("sinistres.nature_sinistre", "sinistres.id_sinistre", "dossiers.id_dossier", "dossiers.id_sinistre",
               "dossiers.id_garantie_souscrite", "garanties_souscrites.id_garantie_souscrite",
               "garanties_souscrites.code_garantie", "prestations.id_dossier", "prestations.type_prestation",
               ctx$lit_vue$prestations), "H;S", "exacte", function() {
    p_dossier <- vv("prestations", "id_dossier")[vv("prestations", "type_prestation") %in% "capital"]
    gs <- .joindre(ctx, "dossiers", "id_dossier", "id_garantie_souscrite", p_dossier)
    code <- .joindre(ctx, "garanties_souscrites", "id_garantie_souscrite", "code_garantie", gs)
    sinistres <- .joindre(ctx, "dossiers", "id_dossier", "id_sinistre", p_dossier[code %in% "deces"])
    vv("sinistres", "nature_sinistre") %in% "deces" & is.na(vv("sinistres", "date_instruction")) &
      .valeurs(ctx, "sinistres", "id_sinistre") %in% sinistres[!is.na(sinistres)]
  })
  invisible(NULL)
}

# Incohérences entre garanties D10 (b) et (c) (dictionnaire, § 9), sur la vue.
.regle_v_garanties <- function(ctx) {
  vv <- function(table, colonne) .valeurs_vue(ctx, table, colonne)
  lit_gs <- c("dossiers.id_garantie_souscrite", "garanties_souscrites.id_garantie_souscrite")
  # D10 (b) : version de garantie hors vigueur à la survenance ; traitement S + X : deux
  # constats de même clé (code, table, colonne), un par traitement (réserve m3)
  hors_vigueur <- function() {
    gs <- vv("dossiers", "id_garantie_souscrite")
    survenance <- as.numeric(.joindre(ctx, "sinistres", "id_sinistre", "date_survenance", vv("dossiers", "id_sinistre")))
    effet <- as.numeric(.joindre(ctx, "garanties_souscrites", "id_garantie_souscrite", "date_effet", gs))
    fin <- as.numeric(.joindre(ctx, "garanties_souscrites", "id_garantie_souscrite", "date_fin", gs))
    !is.na(survenance) & !is.na(effet) & (survenance < effet | (!is.na(fin) & survenance > fin))
  }
  lit_b <- c(lit_gs, "garanties_souscrites.date_effet", "garanties_souscrites.date_fin", "dossiers.id_sinistre",
             "sinistres.id_sinistre", "sinistres.date_survenance")
  for (t in c("S", "X")) .regle_vue(ctx, "D10b", "dossiers", "id_garantie_souscrite", lit_b, t, "exacte", hors_vigueur)
  # D10 (c) : dossier de rente ou de double effet sans dossier `deces` du même sinistre (dans
  # la vue) alors que la garantie décès est souscrite : garantie `deces` du même contrat et
  # du même collège que la garantie du dossier, dans une version en vigueur à la survenance
  # et retenue dans la vue
  .regle_vue(ctx, "D10c", "dossiers", NA_character_,
             c(lit_gs, "dossiers.id_sinistre", "sinistres.id_sinistre", "sinistres.date_survenance",
               paste0("garanties_souscrites.", c("code_garantie", "id_contrat", "college", "date_effet", "date_fin")),
               ctx$lit_vue$garanties_souscrites), "S", "exacte", function() {
    joindre_gs <- function(colonne, gs) .joindre(ctx, "garanties_souscrites", "id_garantie_souscrite", colonne, gs)
    gs <- vv("dossiers", "id_garantie_souscrite")
    code <- joindre_gs("code_garantie", gs)
    sinistre <- vv("dossiers", "id_sinistre")
    survenance <- as.numeric(.joindre(ctx, "sinistres", "id_sinistre", "date_survenance", sinistre))
    cle_dossier <- paste(joindre_gs("id_contrat", gs), joindre_gs("college", gs), sep = "\r")
    avec_deces <- sinistre[code %in% "deces"]
    # versions décès retenues dans la vue
    deces <- which(vv("garanties_souscrites", "code_garantie") %in% "deces")
    cle_deces <- paste(.valeurs(ctx, "garanties_souscrites", "id_contrat")[deces],
                       .valeurs(ctx, "garanties_souscrites", "college")[deces], sep = "\r")
    effet <- as.numeric(.valeurs(ctx, "garanties_souscrites", "date_effet"))[deces]
    fin <- as.numeric(.valeurs(ctx, "garanties_souscrites", "date_fin"))[deces]
    # appariement par clé (contrat, collège) avant le test des dates (m7) : chaque dossier ne
    # parcourt que les versions décès de sa clé
    par_cle <- split(seq_along(cle_deces), factor(cle_deces, levels = unique(cle_deces)))
    souscrite <- vapply(seq_along(gs), function(i) {
      j <- par_cle[[cle_dossier[i]]]
      !is.na(survenance[i]) && length(j) > 0L &&
        any(!is.na(effet[j]) & effet[j] <= survenance[i] & (is.na(fin[j]) | fin[j] >= survenance[i]))
    }, NA)
    code %in% c("rente_conjoint", "rente_education", "double_effet") & souscrite &
      !(sinistre %in% avec_deces[!is.na(avec_deces)])
  })
  invisible(NULL)
}

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
  v <- function(t, c1) .valeurs(ctx, t, c1)
  vv <- function(t, c1) .valeurs_vue(ctx, t, c1)
  present <- function(t) !is.null(ctx$base[[t]])
  # personne (ligne de la table de l'emploi) et date de référence, sur les lignes de la vue
  assure_de <- function(t) match(as.character(vv(t, "id_assure")), as.character(v("assures", "id_assure")), incomparables = NA)
  propre <- function(t) function() list(p = seq_len(nrow(ctx$base[[t]])), date = vv(t, "date_saisie"))
  emplois <- list(
    assures_sinistre = list(lit = c("assures.id_assure", "sinistres.id_sinistre", "sinistres.id_assure",
                                    "sinistres.date_survenance", ctx$lit_vue$sinistres),
                            ref = function() list(p = assure_de("sinistres"), date = vv("sinistres", "date_survenance"))),
    assures_affiliation = list(lit = c("assures.id_assure", "affiliations.id_assure", "affiliations.date_debut",
                                       "contrats.id_assure", "contrats.date_effet", "contrats.nature_contrat",
                                       ctx$lit_vue$affiliations, ctx$lit_vue$contrats),
                               ref = function() {
                                 ind <- vv("contrats", "nature_contrat") %in% "individuel"
                                 list(p = c(assure_de("affiliations"), assure_de("contrats")[ind]),
                                      date = c(vv("affiliations", "date_debut"), vv("contrats", "date_effet")[ind]))
                               }),
    famille = list(lit = c("famille.situation", "famille.id_sinistre", "famille.date_saisie", "sinistres.id_sinistre",
                           "sinistres.date_survenance"),
                   ref = function() {
                     sinistre <- vv("famille", "id_sinistre")
                     survenance <- .joindre(ctx, "sinistres", "id_sinistre", "date_survenance", sinistre)
                     date <- ifelse(is.na(sinistre), as.numeric(vv("famille", "date_saisie")), as.numeric(survenance))
                     p <- seq_along(sinistre)
                     p[vv("famille", "situation") %in% "a_naitre"] <- NA_integer_
                     list(p = p, date = structure(date, class = "Date"))
                   }),
    designations = list(lit = "designations.date_saisie", ref = propre("designations")),
    ayants_droit_sante = list(lit = "ayants_droit_sante.date_saisie", ref = propre("ayants_droit_sante")))
  sans_convention <- FALSE
  for (emploi in names(emplois)) {
    t <- .EMPLOIS_D02C[[emploi]]
    if (!present(t)) next
    manque <- is.null(conv)
    sans_convention <- sans_convention || manque
    for (nom in .SEUILS_AGE_D02C) {
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
    mini <- seuils[[.SEUILS_AGE_D02C[1L]]][[emploi]]
    maxi <- seuils[[.SEUILS_AGE_D02C[2L]]][[emploi]]
    invraisemblable <- function() {
      r <- e$ref()
      naissance <- vv(t, "date_naissance")[r$p]
      age <- calculer_age(naissance, r$date, conv)
      if (any(!is.na(naissance) & !is.na(r$date) & is.na(age))) {
        .ajouter_non_execute(ctx, "D02c", t, NA_character_, .CAUSE_AGE_NON_DEFINI)
      }
      seq_len(nrow(ctx$base[[t]])) %in% r$p[!is.na(age) & (age < mini | age > maxi)]
    }
    for (traitement in c("S", "X")) {
      .regle_vue(ctx, "D02c", t, "date_naissance", e$lit, traitement, "exacte", invraisemblable, colonne_ne = NA_character_)
    }
  }
  if (sans_convention) .requerir(ctx, "conventions", "D02c", "age", paste(CONVENTIONS_AGE, collapse = ";"))
  invisible(NULL)
}

# D07 (c), fin de charge non enregistrée (dictionnaire, § 9 ; spécification, §§ 5.3 et 5.4),
# sur la vue : rente d'éducation en service (rentes) ou dossier double_effet non clos
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
# déclaration requise (rubrique conventions, cles limite_age$regle et limite_age$age).
# Constat sur la table qui porte la charge (rentes, dossiers), colonne NA ; D07 (a) et (b),
# sur evenements, restent déclarés non implémentés (report).
.regle_v_limite_age <- function(ctx) {
  tables <- intersect(c("rentes", "dossiers"), names(ctx$base))
  la <- ctx$conventions$limite_age
  if (is.null(la)) {
    for (t in tables) .ajouter_non_execute(ctx, "D07", t, NA_character_, "declaration_absente")
    if (length(tables) > 0L) {
      .requerir(ctx, "conventions", "D07", "limite_age$regle", paste(REGLES_LIMITE_AGE, collapse = ";"))
      .requerir(ctx, "conventions", "D07", "limite_age$age", paste(CONVENTIONS_LIMITE_AGE, collapse = ";"))
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
  # paramètre de la garantie souscrite, dans la vue : `valeur` (NA s'il manque ou prend
  # plusieurs valeurs) et `ambigu` (plusieurs valeurs) ; une passe par paramètre (split()),
  # gardée pour la seconde règle
  cache <- list()
  parametre <- function(nom, gs) {
    if (is.null(cache[[nom]])) {
      k <- which(vv("parametres", "parametre") %in% nom & !is.na(v("parametres", "id_garantie_souscrite")))
      z <- lapply(split(v("parametres", "valeur")[k], as.character(v("parametres", "id_garantie_souscrite")[k])), unique)
      cache[[nom]] <<- list(u = names(z), n = lengths(z, use.names = FALSE),
                            valeur = vapply(z, function(x) if (length(x) == 1L) x else NA_real_, 0, USE.NAMES = FALSE))
    }
    pr <- cache[[nom]]
    i <- match(as.character(gs), pr$u)
    list(valeur = pr$valeur[i], ambigu = !is.na(i) & pr$n[i] > 1L)
  }
  # enfant éteint à l'arrêté (paires enfant de famille, garantie souscrite) : `eteint`, et
  # `non_defini` (limite non déterminable pour un enfant dont elle décide : âge connu, hors
  # prolongation pour handicap ; paramètre absent ou à plusieurs valeurs, avis d'`actuary`,
  # Q3 (a)). Prolongation pour études : enfant scolarise ou apprenti (décision du mainteneur,
  # jugement d'expert : l'apprentissage vaut poursuite d'études, comme pour la rente
  # d'éducation du recensement des méthodes) ; sans age_limite_etudes, age_limite.
  eteint <- function(m, gs) {
    situation <- vv("famille", "situation")[m]
    etudes_ok <- situation %in% c("scolarise", "apprenti")
    l1 <- parametre("age_limite", gs)
    l2 <- parametre("age_limite_etudes", gs)
    limite <- ifelse(etudes_ok & !is.na(l2$valeur), l2$valeur, l1$valeur)
    limite[etudes_ok & l2$ambigu] <- NA_real_
    limite <- limite + (la$regle == "depassement")
    age <- calculer_age(vv("famille", "date_naissance")[m], rep(ctx$arrete, length(m)), la$age)
    handicap <- .joindre(ctx, "garanties_souscrites", "id_garantie_souscrite", "prolongation_handicap", gs) %in% TRUE &
      situation %in% "handicape"
    decide <- !is.na(age) & !handicap
    list(eteint = decide & !is.na(limite) & age >= limite, non_defini = decide & is.na(limite))
  }
  # limite non déterminable pour une ligne candidate : la table va dans controles_non_executes
  # (colonne NA, cause parametre_non_defini) ; les autres lignes restent contrôlées
  noter <- function(t, e) {
    if (any(e$non_defini)) .ajouter_non_execute(ctx, "D07", t, NA_character_, .CAUSE_PARAMETRE_NON_DEFINI)
    e$eteint
  }
  # enfant à charge : ligne valable dans la vue, lien enfant, non décédé à l'arrêté
  a_charge <- function() {
    deces <- as.numeric(vv("famille", "date_deces"))
    !is.na(vv("famille", "id_membre")) & vv("famille", "lien") %in% "enfant" & (is.na(deces) | deces > a)
  }
  # événements de la vue de date d'effet au plus l'arrêté
  evenements_retenus <- function() {
    type <- vv("evenements", "type_evenement")
    effet <- as.numeric(vv("evenements", "date_effet"))
    list(type = type, retenu = !is.na(type) & !is.na(effet) & effet <= a)
  }
  ev_lus <- paste0("evenements.", c("id_evenement", "type_evenement", "date_effet", "date_saisie"))
  lit_commun <- c("dossiers.id_dossier", "dossiers.id_garantie_souscrite", "garanties_souscrites.id_garantie_souscrite",
                  "garanties_souscrites.code_garantie", "garanties_souscrites.prolongation_handicap",
                  "parametres.id_garantie_souscrite", "parametres.parametre", "parametres.valeur", "famille.id_membre",
                  "famille.lien", "famille.date_naissance", "famille.situation", "famille.date_deces", ev_lus,
                  ctx$lit_vue$famille, ctx$lit_vue$parametres, ctx$lit_vue$evenements)
  service <- c("ouverture_service", "modification_montant")
  .regle_vue(ctx, "D07", "rentes", NA_character_, c("rentes.id_rente", "rentes.id_dossier", "rentes.id_membre",
                                                    "evenements.id_rente", lit_commun), "H;S", "exacte", function() {
    nr <- nrow(ctx$base$rentes)
    ev <- evenements_retenus()
    k <- which(ev$retenu & ev$type %in% c(service, "fin_service"))
    p <- .paires(v("evenements", "id_rente")[k], v("rentes", "id_rente"))
    dernier <- .dernier_evenement(ctx, data.frame(i = k[p$i], j = p$j), nr)
    en_service <- !is.na(dernier) & ev$type[dernier] %in% service
    gs <- gs_de(v("rentes", "id_dossier"))
    m <- match(as.character(v("rentes", "id_membre")), as.character(vv("famille", "id_membre")), incomparables = NA)
    ok <- code_de(gs) %in% "rente_education" & en_service & !is.na(m)
    ok[ok] <- a_charge()[m[ok]]
    if (any(ok)) ok[ok] <- noter("rentes", eteint(m[ok], gs[ok]))
    ok
  })
  # double effet : un dossier clos, ou dont le second décès est retenu à l'arrêté (le droit
  # au capital s'y fixe, avis d'`actuary`, Q3 (b)), n'est pas candidat
  .regle_vue(ctx, "D07", "dossiers", NA_character_, c("dossiers.id_sinistre", "sinistres.id_sinistre",
                                                      "sinistres.id_assure", "famille.id_assure", "evenements.id_dossier",
                                                      lit_commun), "H;S", "exacte", function() {
    nd <- nrow(ctx$base$dossiers)
    ev <- evenements_retenus()
    gs <- v("dossiers", "id_garantie_souscrite")
    fin <- ev$retenu & ev$type %in% c("cloture_dossier", "second_deces")
    clos <- v("dossiers", "id_dossier") %in% v("evenements", "id_dossier")[fin]
    candidat <- code_de(gs) %in% "double_effet" & !clos
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
  })
  invisible(NULL)
}

# --- Placement des constats et enjeu -----------------------------------------------------

# Visibilité d'une ligne dans la vue à l'arrêté, pour les comptes du bilan (nombre_visibles
# d'un refus, lignes traitées X d'une orpheline, nombre_dossiers, enjeu ; réserves Q8 (a)
# d'`actuary` et M2 de l'audit), en trois valeurs : TRUE si la ligne est visible, FALSE si
# elle ne l'est pas, NA si sa visibilité n'est pas déterminée. Mêmes règles que la vue
# (.construire_vue()) : dates de .DATES_VISIBILITE (date d'effet qu'ajoute l'hypothèse
# déclarée de D02b, date de saisie que retient l'hypothèse déclarée de D03g), lignes de
# visibilité non déterminée, puis règle 1 du § 6 (une fille d'une ligne invisible est
# invisible, d'une ligne non déterminée non déterminée ; une orpheline garde sa condition
# propre ; versions de famille : visible si l'une l'est) ; adherents et assures visibles
# s'ils sont référencés par une ligne visible. Deux écarts à la vue, pour compter sans
# corriger : les refus R ne l'empêchent pas (spécification, § 2.3, point 2 : une ligne
# refusée invisible à l'arrêté), seule une colonne illisible par sa forme rend la visibilité
# non déterminée ; une ligne que l'exclusion déclarée de D03g sort de la vue a pour
# visibilité celle que lui donnerait l'hypothèse avec un délai nul : la date que compare D02b
# (evenements.date_effet, sinistres.date_declaration ; aucune pour une fille, que borne la
# visibilité de sa parente) tient lieu de date de saisie, borne basse de sa connaissance
# (son enjeu est chiffré sans regard en avant, D5 ; réserve Q4). `d03g` : variante qui
# applique la même règle aux lignes entières de D03g de visibilité non déterminée (et à
# leurs filles), lue par l'enjeu des écarts de D03g seulement (réserve Q8). Seule la version
# valable de famille à l'arrêté est comptée (dernière saisie visible de chaque membre,
# réserve Q9 ; non déterminée si une version plus récente l'est). À l'arrêté égal à
# l'extraction, tout est visible (règle 3 du § 6). Calculé une fois par appel et par variante.
.connus <- function(ctx, table, d03g = FALSE) {
  df <- ctx$base[[table]]
  n <- if (is.null(df)) 0L else nrow(df)
  if (.vue_totale(ctx)) return(rep(TRUE, n))
  nom <- if (d03g) "vue_comptes_g" else "vue_comptes"
  if (is.null(ctx[[nom]])) assign(nom, .vue_comptes(ctx, d03g), envir = ctx)
  x <- ctx[[nom]][[table]]
  if (is.null(x)) rep(NA, n) else x
}
.EFFET_D03G <- list(evenements = "date_effet", sinistres = "date_declaration")
.vue_comptes <- function(ctx, d03g = FALSE) {
  a <- as.numeric(ctx$arrete)
  lisible <- function(t, c1) is.na(.cause(ctx, t, c1, forme_seule = TRUE))
  tables <- setdiff(ctx$tables, "extraction")
  vis <- list()
  for (t in tables) {
    n <- nrow(ctx$base[[t]])
    v <- rep(TRUE, n)
    # lignes entières de D03g sans date de saisie : exclues (D5), ou non déterminées (variante)
    g_lignes <- ctx$exclu_g[[t]]
    if (is.null(g_lignes)) g_lignes <- rep(FALSE, n)
    if (d03g) {
      for (k in ctx$lignes_nd) if (k$table == t && is.na(k$colonne) && k$motif == "D03g") g_lignes[k$lignes] <- TRUE
      g_lignes[ctx$parente_g[[t]]] <- TRUE   # lignes de D03g qui suivent leur parente (Q2 (b))
    }
    for (c1 in .DATES_VISIBILITE[[t]]) {
      d <- if (lisible(t, c1)) as.numeric(.valeurs(ctx, t, c1)) else rep(NA_real_, n)
      if (c1 == "date_saisie") {
        g <- ctx$date_g[[t]]
        if (!is.null(g)) d <- ifelse(is.na(g), d, g)
        if (any(g_lignes)) {
          e <- .EFFET_D03G[[t]]
          d[g_lignes] <- if (is.null(e)) -Inf else if (lisible(t, e)) as.numeric(.valeurs(ctx, t, e))[g_lignes] else NA_real_
        }
      }
      v <- v & d <= a
    }
    dh <- ctx$date_h[[t]]
    if (!is.null(dh)) v <- v & (is.na(dh) | dh <= a)
    vis[[t]] <- v
  }
  # lignes de visibilité non déterminée (ligne entière) ; variante : hors D03g et hors filles
  # recensées (la règle 1 ci-dessous propage les autres causes)
  for (k in ctx$lignes_nd) {
    if (d03g && k$motif %in% c("D03g", "parente_non_determinee")) next
    if (is.na(k$colonne) && !is.null(vis[[k$table]])) {
      x <- vis[[k$table]]
      x[k$lignes[x[k$lignes] %in% TRUE]] <- NA
      vis[[k$table]] <- x
    }
  }
  # famille : seule la dernière saisie visible de chaque membre est valable (réserve Q9) ;
  # une version plus récente de visibilité non déterminée rend la validité non déterminée
  valables <- function(x) x
  if ("famille" %in% tables && lisible("famille", "id_membre")) {
    membre <- as.character(.valeurs(ctx, "famille", "id_membre"))
    membre[is.na(membre)] <- paste0("\r", which(is.na(membre)))   # un manquant : un membre à part
    saisie <- if (lisible("famille", "date_saisie")) as.numeric(.valeurs(ctx, "famille", "date_saisie")) else
      rep(NA_real_, length(membre))
    g <- ctx$date_g$famille
    if (!is.null(g)) saisie <- ifelse(is.na(g), saisie, g)
    max_de <- function(z) if (all(is.na(z))) NA_real_ else max(z, na.rm = TRUE)
    valables <- function(x) {
      derniere <- stats::ave(ifelse(x %in% TRUE, saisie, NA_real_), membre, FUN = max_de)
      recente_nd <- stats::ave(ifelse(is.na(x), ifelse(is.na(saisie), Inf, saisie), NA_real_), membre, FUN = max_de)
      x[x %in% TRUE & !is.na(derniere) & (is.na(saisie) | saisie < derniere)] <- FALSE
      x[x %in% TRUE & !is.na(recente_nd) & (is.na(saisie) | recente_nd > saisie)] <- NA
      x
    }
  }
  # règle 1, jusqu'au point fixe ; une clé de lien illisible par sa forme : non déterminée ;
  # la version valable de famille est retenue une fois famille établie, puis la règle 1 est
  # reprise pour ses filles
  liens <- .liens_visibilite(ctx$dico)
  liens <- liens[liens$table %in% tables & liens$table_cible %in% tables, , drop = FALSE]
  regle_1 <- function(vis) repeat {
    change <- FALSE
    for (i in seq_len(nrow(liens))) {
      t <- liens$table[i]
      u <- liens$table_cible[i]
      if (lisible(t, liens$colonne[i]) && lisible(u, liens$colonne_cible[i])) {
        cle <- as.character(.valeurs(ctx, t, liens$colonne[i]))
        cible <- as.character(.valeurs(ctx, u, liens$colonne_cible[i]))
        vu <- vis[[u]]
        vrai <- cible[vu %in% TRUE]
        indet <- cible[is.na(vu)]
        parente <- ifelse(is.na(cle) | !(cle %in% cible) | cle %in% vrai, TRUE, ifelse(cle %in% indet, NA, FALSE))
      } else {
        parente <- rep(NA, length(vis[[t]]))
      }
      nouveau <- vis[[t]] & parente
      if (!identical(nouveau, vis[[t]])) {
        vis[[t]] <- nouveau
        change <- TRUE
      }
    }
    if (!change) return(vis)
  }
  vis <- regle_1(vis)
  if ("famille" %in% tables) {
    vis$famille <- valables(vis$famille)
    vis <- regle_1(vis)
  }
  # adherents et assures : visibles s'ils sont référencés par une ligne visible
  references <- list(adherents = list(c("contrats", "id_adherent")),
                     assures = list(c("contrats", "id_assure"), c("affiliations", "id_assure"), c("famille", "id_assure"),
                                    c("famille", "id_assure_membre"), c("sinistres", "id_assure"),
                                    c("victimes", "id_assure"), c("ayants_droit_sante", "id_assure_membre")))
  for (t in intersect(names(references), tables)) {
    cle_t <- .eclater_champ(ctx$dico$tables$cle_primaire[ctx$dico$tables$table == t])[1L]
    if (!lisible(t, cle_t)) { vis[[t]] <- rep(NA, nrow(ctx$base[[t]])); next }
    cle <- as.character(.valeurs(ctx, t, cle_t))
    vrai <- character(0)
    indet <- character(0)
    for (r in references[[t]]) {
      if (!(r[1L] %in% tables)) next
      if (!lisible(r[1L], r[2L])) { indet <- c(indet, cle); next }
      x <- as.character(.valeurs(ctx, r[1L], r[2L]))
      vrai <- c(vrai, x[vis[[r[1L]]] %in% TRUE])
      indet <- c(indet, x[is.na(vis[[r[1L]]])])
    }
    vis[[t]] <- ifelse(cle %in% vrai[!is.na(vrai)], TRUE, ifelse(cle %in% indet[!is.na(indet)], NA, FALSE))
  }
  vis
}

# Première cause qui empêche de lire l'une des colonnes `lus` (« table.colonne ») :
# c(table, colonne, cause), ou NULL ; `forme_seule` : écarts de forme seulement (.cause()).
.cause_lecture <- function(ctx, lus, forme_seule = FALSE) {
  for (tc in lus) {
    m <- strsplit(tc, ".", fixed = TRUE)[[1L]]
    cause <- .cause(ctx, m[1L], m[2L], forme_seule)
    if (!is.na(cause)) return(c(table = m[1L], colonne = m[2L], cause = cause))
  }
  NULL
}

# Paires (i, j) telles que x[i] == y[j], valeurs manquantes exclues (jointure un à plusieurs),
# triées par i puis j ; composition de deux relations (i -> k, k -> j). Par correspondance
# (match) sur les clés distinctes de y : coût proportionnel au nombre de paires rendues.
.paires <- function(x, y) {
  x <- as.character(x)
  y <- as.character(y)
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
# numéros de ligne de la table et de dossiers, sans doublon, triés) et `cause` (colonne de clé
# illisible par sa forme : c(table, colonne, cause), sinon NULL). evenements : par id_dossier,
# sinon par le sinistre ; affiliations : dossiers des sinistres de l'assuré sous le même
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
  vide <- data.frame(ligne = integer(0), dossier = integer(0))
  chemins <- .CHEMINS_RATTACHEMENT[[table]]
  n <- nrow(ctx$base[[table]])
  res <- list(paires = vide, cause = NULL)
  if (table == "dossiers") {
    res$paires <- data.frame(ligne = seq_len(n), dossier = seq_len(n))
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
        if (table == "evenements" && k == 2L) depart <- which(is.na(.valeurs(ctx, "evenements", "id_dossier")))
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
      if (table == "affiliations" && nrow(p) > 0L) {
        contrat <- .joindre(ctx, "garanties_souscrites", "id_garantie_souscrite", "id_contrat",
                            .valeurs(ctx, "dossiers", "id_garantie_souscrite")[p$j])
        p <- p[!is.na(contrat) & contrat == .valeurs(ctx, "affiliations", "id_contrat")[p$i], , drop = FALSE]
      }
      p <- unique(data.frame(ligne = p$i, dossier = p$j))
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

# Composantes 1 à 4 de chaque dossier à l'arrêté (spécification, § 4.3) : `garantie`
# (code_garantie, ou non_rattache), `connu` (.connus()), `valeurs` (liste nommée par
# composante d'un vecteur par dossier, NA : aucune valeur ; une composante sans objet pour la
# garantie du dossier n'a pas de valeur), `indetermine` (par composante, dossier dont une
# ligne qui entre dans la valeur a une visibilité non déterminée : la valeur n'est pas connue
# à l'arrêté, réserve Q8 (b)), `lus` (colonnes lues par composante ; la cause qui l'empêche
# dépend de l'écart, .cause_enjeu()) et `forme` (première colonne lue illisible par sa forme :
# la valeur n'est pas calculée). Les montants sont pris tels quels (aucune correction,
# dictionnaire, § 1.10) ; sommes en ordre trié des montants, indépendantes de l'ordre des
# lignes (réserve m3). Calculé une fois par appel.
.composantes_dossiers <- function(ctx, d03g = FALSE) {
  nom <- if (d03g) "composantes_g" else "composantes"
  if (!is.null(ctx[[nom]])) return(ctx[[nom]])
  v <- function(t, c1) .valeurs(ctx, t, c1)
  nd <- nrow(ctx$base$dossiers)
  a <- as.numeric(ctx$arrete)
  lus_g <- c("dossiers.id_garantie_souscrite", "garanties_souscrites.id_garantie_souscrite",
             "garanties_souscrites.code_garantie")
  garantie <- if (is.null(.cause_lecture(ctx, lus_g, forme_seule = TRUE))) {
    .joindre(ctx, "garanties_souscrites", "id_garantie_souscrite", "code_garantie", v("dossiers", "id_garantie_souscrite"))
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
    cle <- .eclater_champ(ctx$dico$tables$cle_primaire[ctx$dico$tables$table == table])
    vc <- lapply(cle, function(c1) as.character(.valeurs(ctx, table, c1))[l][p$i])
    id <- do.call(paste, c(vc, list(p$j), sep = "\r"))
    manque <- Reduce(`|`, lapply(vc, is.na))
    p[manque | !duplicated(id), , drop = FALSE]
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
      sans_rente <- is.na(v("evenements", "id_rente"))
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
  assign(nom, list(garantie = garantie, connu = .connus(ctx, "dossiers", d03g), valeurs = valeurs, brutes = brutes,
                   indetermine = indetermine, lus = lus, lus_brut = lus_brut, lus_g = lus_g), envir = ctx)
  ctx[[nom]]
}

# Placement des constats selon leur traitement et les déclarations (spécification, § 3 ; ADR
# 0010, sixième série, (b) 3 et 4 ; décisions du mainteneur D4 et D5). R et S sont placés par
# .bilan(). Un constat à choix a deux axes : X par famille de calcul (.familles_x() : hors des
# couples traités S, .EXCEPTIONS_FAMILLE) et H ou S par référentiel (S : valeur
# .VALEUR_SIGNALEMENT de `hypotheses`, pour un constat qui admet S). Il est couvert si
# l'exclusion est déclarée pour chaque famille, ou H ou S pour chaque référentiel ; couvert,
# il n'est placé que sur un axe (réserve M1 ; un motif à traitement unique n'est jamais
# déclaré sur les deux, D8 ; ailleurs l'exclusion l'emporte, dont D03g, D11) : `exclusions`
# par famille, ou `hypotheses_defaut` par référentiel en H et `signalements` (une fois) si
# un référentiel est en S. Non couvert, chaque déclaration est placée et chaque famille et
# chaque référentiel sans déclaration va dans `declarations_requises` (traitements admis :
# ceux du constat). Motifs de la règle P (D02b, D03g), appliqués à la vue : une déclaration
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
  signales <- rep(FALSE, length(constats))
  ajouter <- function(liste, x) { liste[[length(liste) + 1L]] <- x; liste }
  for (n in seq_along(constats)) {
    k <- constats[[n]]
    t <- .eclater_champ(k$traitement)
    base_ecart <- list(table = k$table, colonne = k$colonne, motif = k$code)
    if (identical(t, "R")) {
      if (k$code != "refus_induit") {
        ecarts <- ajouter(ecarts, c(base_ecart, list(famille = "ensemble", action = "refus", lignes = k$lignes)))
      }
      next
    }
    if (identical(t, "S")) next
    lignes <- k$lignes
    if (k$code %in% c("D04a", "D04b")) lignes <- lignes[!(.connus(ctx, k$table)[lignes] %in% FALSE)]
    familles <- if ("X" %in% t) .familles_x(k$code) else character(0)
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
        exclusions <- ajouter(exclusions, list(motif = k$code, famille = f, action = action, table = k$table, lignes = lignes))
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
    if (k$code == "D03g" && r_ok && identical(k$colonne, "date_saisie")) {
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
    for (i in seq_len(nrow(h_k))) {
      hypotheses <- ajouter(hypotheses, list(motif = k$code, referentiel = h_k$referentiel[i], poste = h_k$poste[i],
                                             valeur = h_k$valeur[i], table = k$table, lignes = lignes_h))
    }
    if (nrow(s_k) > 0L) signales[n] <- TRUE
    if (axe_r && !x_ok && !r_ok) {
      for (r in setdiff(REFERENTIELS, referentiels_declares)) {
        requises <- ajouter(requises, list(rubrique = "hypotheses", motif = k$code, cle = r, traitements_admis = k$traitement,
                                           table = k$table, lignes = lignes))
      }
    }
    # délai de D03g : lu par l'application de l'hypothèse, tant que l'exclusion ne couvre pas
    if (k$code == "D03g" && !x_ok && is.null(ctx$declarations$seuils[[.SEUIL_DELAI_D03G]][[k$table]])) {
      requises <- ajouter(requises, list(rubrique = "seuils", motif = k$code, cle = paste0(.SEUIL_DELAI_D03G, "$", k$table),
                                         traitements_admis = NA_character_, table = k$table, lignes = lignes))
    }
  }
  list(exclusions = exclusions, hypotheses = hypotheses, requises = requises, ecarts = ecarts, signales = signales)
}

# Agrège des lignes brutes de placement par les colonnes `cles` : une ligne par clé, avec le
# nombre de lignes distinctes (table, ligne) et, si `dossiers`, le nombre de dossiers
# rattachés connus (.nombre_dossiers_union()).
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
      parts <- lapply(g, function(x) list(table = x$table, lignes = x$lignes))
      .nombre_dossiers_union(ctx, parts)
    }, 0L, USE.NAMES = FALSE)
  }
  df
}

# Dossiers distincts rattachés connus à l'arrêté pour plusieurs (table, lignes), NA si l'un
# des rattachements est illisible ou la visibilité d'un dossier rattaché indéterminée.
.nombre_dossiers_union <- function(ctx, parts) {
  d <- integer(0)
  for (x in parts) {
    r <- .rattacher(ctx, x$table)
    if (!is.null(r$cause)) return(NA_integer_)
    d <- c(d, r$paires$dossier[r$paires$ligne %in% x$lignes])
  }
  connu <- .connus(ctx, "dossiers")[unique(d)]
  if (anyNA(connu)) NA_integer_ else sum(connu)
}

# Niveau élémentaire de l'enjeu (spécification, § 4.5, point 1 ; ADR 0010, sixième série,
# (c) 1) : seule fonction qui l'établit, interne à `donnees` (réemployée en B2 pour
# l'agrégation par poste). Pour chaque écart (.placer()), rend `elements` (une ligne par
# porteur et composante : `porteur` (dossiers ou table de la ligne), `indice` (NA : élément
# sans porteur, qui porte la cause d'une composante empêchée dans toute rangée où elle
# figure, réserve Q10), `garantie`, `connu`, `composante`, `unite`, `valeur` (NA : aucune
# valeur), `cause` (motif d'un refus ou forme illisible, .cause_enjeu() ; ou
# `visibilite_non_determinee` pour un porteur dont la visibilité, ou celle d'une ligne qui
# entre dans sa valeur, n'est pas déterminée, réserve Q8 (b) ; `D01a` pour un porteur
# touché par un identifiant de l'écart D01a dont les doubles divergent sur une colonne lue,
# D10), `cause_table`, `cause_colonne`), `dossiers` (dossiers rattachés : `dossier`,
# `garantie`, `connu`, `famille` : famille de composantes pour laquelle le dossier est
# compté), `familles_cause` (familles dont le rattachement est illisible) et `familles`
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
  # première colonne lue empêchée ; une cause directe (forme, refus) d'une colonne prime sur
  # le refus induit d'une autre (priorité des causes, M185)
  cause_de <- function(lus) {
    induite <- NULL
    for (tc in lus) {
      m <- strsplit(tc, ".", fixed = TRUE)[[1L]]
      cz <- .cause_enjeu(ctx, m[1L], m[2L], ecart)
      if (is.na(cz)) next
      if (cz != "refus_induit") return(c(table = m[1L], colonne = m[2L], cause = cz))
      if (is.null(induite)) induite <- c(table = m[1L], colonne = m[2L], cause = cz)
    }
    induite
  }
  familles <- character(0)
  familles_cause <- character(0)
  dossiers <- data.frame(dossier = integer(0), garantie = character(0), connu = logical(0), famille = character(0),
                         stringsAsFactors = FALSE)
  cause_rattachement <- NULL
  lien_g <- FALSE
  if (table %in% c(.TABLES_DOSSIER, "prestations")) {
    r <- .rattacher(ctx, table)
    cause_rattachement <- r$cause
    tags <- if (table == "prestations") "prestation" else c("dossier", if (table == "evenements") "evenement")
    if (!is.null(r$cause)) familles_cause <- tags
    if (is.null(r$cause) && !is.null(ctx$base$dossiers)) {
      cd <- .composantes_dossiers(ctx, d03g)
      d <- sort(unique(r$paires$dossier[r$paires$ligne %in% lignes]))
      d <- d[!(cd$connu[d] %in% FALSE)]   # dossiers invisibles à l'arrêté : non rattachés
      # garantie lue sur la clé étrangère refusée de l'écart (D10 (a), D04b) : lien non résolu,
      # dossier non rattaché (réserve Q4)
      lien_g <- identical(ecart$action, "refus") && ecart$motif %in% .MOTIFS_LIEN_ECART &&
        paste(ecart$table, ecart$colonne, sep = ".") %in% cd$lus_g
      garantie <- if (is.null(cause_de(cd$lus_g)) && !lien_g) cd$garantie[d] else rep("non_rattache", length(d))
      dossiers <- do.call(rbind, lapply(tags, function(f) {
        data.frame(dossier = d, garantie = garantie, connu = cd$connu[d], famille = rep(f, length(d)), stringsAsFactors = FALSE)
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
        cz <- cause_de(lus_k[[composante]])
        if (!is.null(cz)) {
          empecher("dossiers", composante, COMPOSANTES_ENJEU$unite[k], cz)
          next
        }
        s <- applicable[[composante]]
        i <- dd$dossier[s]
        indet <- is.na(dd$connu[s]) | cd$indetermine[[composante]][i]
        ajouter("dossiers", i, dd$garantie[s], dd$connu[s], composante, COMPOSANTES_ENJEU$unite[k], valeurs_k[[composante]][i],
                ifelse(indet, .CAUSE_VISIBILITE, NA_character_), ifelse(indet, "dossiers", NA_character_))
      }
    }
  }
  lus_gd <- c("dossiers.id_dossier", "dossiers.id_garantie_souscrite", "garanties_souscrites.id_garantie_souscrite",
              "garanties_souscrites.code_garantie")
  cause_gd <- cause_de(lus_gd)
  garantie_dossier <- function(id) {
    if (!is.null(cause_gd) || !is.null(.cause_lecture(ctx, lus_gd, forme_seule = TRUE))) return(rep("non_rattache", length(id)))
    g <- .joindre(ctx, "garanties_souscrites", "id_garantie_souscrite", "code_garantie",
                  .joindre(ctx, "dossiers", "id_dossier", "id_garantie_souscrite", id))
    ifelse(is.na(g), "non_rattache", g)
  }
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
                        ifelse(!is.na(v("evenements", "id_rente")[l]), "euro_par_an", "euro_par_jour"), NA_character_))
        list(g = g, unite = unite)
      }
      x <- unite_de(vus)
      montant <- v("evenements", "montant")[vus]
      s <- !is.na(x$unite) & !is.na(montant)
      y <- unite_de(indet)
      si <- !is.na(y$unite) & !is.na(v("evenements", "montant")[indet])
      for (k in 8:10) {
        u <- COMPOSANTES_ENJEU$unite[k]
        su <- s & x$unite == u
        ajouter("evenements", vus[su], x$g[su], rep(TRUE, sum(su)), "montant_evenement", u, montant[su])
        si_u <- si & y$unite == u
        ajouter("evenements", indet[si_u], y$g[si_u], rep(NA, sum(si_u)), "montant_evenement", u, rep(NA_real_, sum(si_u)),
                .CAUSE_VISIBILITE, "evenements")
      }
    }
  }
  if (table == "prestations") {
    familles <- "prestation"
    cause <- cause_de(paste0("prestations.", .LUS_LIGNE_ENJEU$prestations))
    if (!is.null(cause)) {
      empecher("prestations", "prestations_ecartees", "euro", cause)
    } else {
      ajouter("prestations", vus, garantie_dossier(v("prestations", "id_dossier")[vus]), rep(TRUE, length(vus)),
              "prestations_ecartees", "euro", v("prestations", "montant")[vus])
      ajouter("prestations", indet, garantie_dossier(v("prestations", "id_dossier")[indet]), rep(NA, length(indet)),
              "prestations_ecartees", "euro", rep(NA_real_, length(indet)), .CAUSE_VISIBILITE, "prestations")
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
      g <- .joindre(ctx, "garanties_souscrites", "id_garantie_souscrite", "code_garantie", v("cotisations", "id_garantie_souscrite")[l])
      ifelse(is.na(g), "non_rattache", g)
    }
    for (k in 6:7) {
      composante <- COMPOSANTES_ENJEU$composante[k]
      if (!is.null(cause)) {
        empecher("cotisations", composante, "euro", cause)
        next
      }
      natures <- if (k == 6L) c("emission", "annulation", "regularisation") else "encaissement"
      s <- vus[v("cotisations", "nature_mouvement")[vus] %in% natures]
      ajouter("cotisations", s, garantie_cotisation(s), rep(TRUE, length(s)), composante, "euro", v("cotisations", "montant")[s])
      si <- indet[v("cotisations", "nature_mouvement")[indet] %in% natures]
      ajouter("cotisations", si, garantie_cotisation(si), rep(NA, length(si)), composante, "euro", rep(NA_real_, length(si)),
              .CAUSE_VISIBILITE, "cotisations")
    }
  }
  el <- if (length(elements)) do.call(rbind, elements) else NULL
  # D01a de l'écart (D10) : un porteur est sans valeur, cause D01a, pour une composante dont
  # une colonne lue diverge entre les lignes en double d'un identifiant qui le touche ; un
  # dossier ainsi touché porte la cause aussi pour une composante qu'il ne porte pas (sa
  # garantie, lue sur une colonne divergente, n'est pas déterminée)
  if (identical(ecart$action, "refus") && identical(ecart$motif, "D01a") && length(familles) > 0L) {
    marquer <- function(porteur, composante, unite, lus, touches_de) {
      lus_t <- sub("^[^.]*\\.", "", lus[startsWith(lus, paste0(table, "."))])
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
        # garantie
        manque <- intersect(manque, lignes[!(connus[lignes] %in% FALSE)])
        if (porteur != "dossiers" && length(manque) > 0L && c1 %in% .CLASSE_D01A[[porteur]]) {
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
# integer(0) si toutes concordent (doublons à l'identique : chiffrés).
.divergences_d01a <- function(ctx, table, lignes, colonne) {
  cle <- .eclater_champ(ctx$dico$tables$cle_primaire[ctx$dico$tables$table == table])
  if (colonne %in% cle) return(integer(0))
  k <- do.call(paste, c(lapply(cle, function(c1) as.character(.valeurs(ctx, table, c1))), sep = "\r"))
  grp <- which(k %in% k[lignes])
  if (length(grp) == 0L) return(integer(0))
  x <- .valeurs(ctx, table, colonne)[grp]
  diverge <- tapply(seq_along(grp), k[grp], function(i) length(unique(x[i])) > 1L)
  grp[k[grp] %in% names(diverge)[diverge]]
}

# Rangées de l'enjeu d'un groupe d'éléments (spécification, § 4.5) : une ligne par garantie
# présente et pour la garantie `ensemble`, et par couple (composante, unite) que portent les
# familles de composantes du groupe (pour une garantie, celles qui y ont un dossier ou une
# ligne) ; montant sommé sur les porteurs distincts connus qui ont une valeur (en ordre trié,
# indépendant de l'ordre des lignes ; jamais arrondi), NA si une cause empêche la composante
# (la première cause de refus, sinon la visibilité non déterminée) ; nombre_dossiers :
# dossiers distincts comptés pour la famille de composantes du couple (réserve M3 : un dossier
# rattaché par une prestation écartée n'est compté que pour prestations_ecartees), NA si le
# rattachement est illisible ou la visibilité d'un dossier indéterminée ; nombre_valeurs :
# porteurs qui portent une valeur. Un élément sans porteur (indice NA) empêche la composante
# pour toute garantie.
.rangees_enjeu <- function(elements, dossiers, familles_cause, familles) {
  if (!is.null(elements)) elements <- elements[!duplicated(elements[, c("porteur", "indice", "composante", "unite", "cause")]), ,
                                               drop = FALSE]
  dossiers <- dossiers[!duplicated(dossiers[, c("dossier", "famille")]), , drop = FALSE]
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
        cause <- if (length(refus)) refus[1L] else .CAUSE_VISIBILITE
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
    r <- .rangees_enjeu(el$elements, el$dossiers, el$familles_cause, el$familles)
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
    r <- .rangees_enjeu(g$elements, g$dossiers, g$familles_cause, g$familles)
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
  cle <- .eclater_champ(ctx$dico$tables$cle_primaire[ctx$dico$tables$table == table])
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

# Causes de controles_non_executes qui ne sont ni une cause directe (forme ou refus d'une
# colonne lue) ni un refus induit (priorité des causes, M185, .bilan()). À tenir à jour :
# toute nouvelle cause qui n'est pas un motif de refus (code de controles.csv ou de
# defauts.csv, ou sous-cas lettré d'un code de defauts.csv) s'ajoute ici, sinon .bilan() la
# prendrait pour une cause directe (test d'exhaustivité, tests/unitaires/donnees.R).
.CAUSES_NON_DIRECTES <- c(CAUSE_NON_IMPLEMENTE, "declaration_absente", CAUSE_NON_LISIBLE, .CAUSE_AGE_NON_DEFINI,
                          .CAUSE_PARAMETRE_NON_DEFINI, .CAUSE_VISIBILITE)
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
  # une ligne par (code, table, colonne), première cause dans l'ordre de priorité ; une
  # règle empêchée reste toujours ici, même si une autre règle de même clé a détecté : la
  # clé présente aussi dans controles est une détection partielle, dont le nombre est un
  # minorant (ADR 0010, huitième série, (e))
  # Une cause directe (forme, refus) prime sur un refus_induit de même clé (M185) : une clé
  # dont la première cause est refus_induit prend la première cause directe qui la suit ; la
  # place des autres causes (non_implemente, declaration_absente...) est inchangée.
  cle_ne <- paste(non_executes$code, non_executes$table, non_executes$colonne, sep = "\r")
  directe <- !(non_executes$cause %in% c("refus_induit", .CAUSES_NON_DIRECTES))
  premiere <- match(cle_ne, cle_ne)
  induite <- non_executes$cause[premiere] == "refus_induit"
  cle_d <- cle_ne[directe]
  remplace <- match(cle_ne, cle_d)
  i <- which(!duplicated(cle_ne) & induite & !is.na(remplace))
  non_executes$cause[i] <- non_executes$cause[directe][remplace[i]]
  non_executes <- non_executes[!duplicated(cle_ne), , drop = FALSE]

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
                        .nombre_dossiers_union(ctx, list(list(table = k$table, lignes = k$lignes)))
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
