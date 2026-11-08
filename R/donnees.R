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
# État de ce fichier (lot (c), deuxième partie, sous-partie (ii-a)) : interruptions, règle
# B dont les orphelines traitées X (D04a, D04b), règle P (D02b, D03g), vue à une date
# (visibilité non déterminée) et, en règle V, somme_parts, D01b, D02a, D03a à D03c, D03e, D03f, D03h, D05,
# D06, D10 (b) et (c), D13. L'état partiel est porté par l'objet rendu :
# chaque contrôle prévu par la spécification et non encore écrit (CONTROLES_NON_IMPLEMENTES :
# le reste de la règle V, dont D02c pour un âge et D07) figure dans controles_non_executes
# avec la cause `non_implemente` ; un sous-cas que la base ne permet pas de lire, avec la
# cause `non_lisible` (CAUSE_NON_LISIBLE). Les exclusions, hypothèses par défaut, déclarations
# requises et l'enjeu viennent avec les sous-parties suivantes : leurs éléments du bilan sont
# rendus vides, nombre_visibles et nombre_dossiers valent NA, et un constat dont le
# traitement attend une déclaration (X, H, ou un choix entre plusieurs) n'est placé dans
# aucun élément de traitement.

# --- Constantes ------------------------------------------------------------------

# Familles de calcul d'une exclusion déclarée (dictionnaire, § 1.10) et référentiels d'une
# hypothèse par défaut.
FAMILLES_CALCUL <- c("engagement", "triangle", "risque_en_cours", "regle_comptable")
REFERENTIELS <- c("comptes_sociaux", "solvabilite_2")

# Sous-éléments admis des arguments `declarations` (sous-schéma `donnees` du plan, ADR 0010,
# point 17) et `conventions` (section `conventions` du plan, M153).
RUBRIQUES_DECLARATIONS <- c("exclusions", "hypotheses", "seuils", "evaluations_gestion")
# `instant_date`, `repartition_annee` et `fractionnement` sont admises sans contrôle de valeur :
# leur domaine n'est écrit ni dans l'ADR 0010 (point 17 : noms seuls) ni dans la
# spécification ; valider_plan() le fixera en B2.
ENTREES_CONVENTIONS <- c("age", "instant_date", "repartition_annee", "fractionnement", "limite_age")

# Contrôles prévus par la spécification (§ 2.4) et non encore écrits : rendus dans
# controles_non_executes avec la cause `non_implemente` (CAUSE_NON_IMPLEMENTE), pour que le
# bilan dise lui-même qu'il est partiel. La liste se vide au fil des sous-parties (ii) et
# (iii).
# Colonne NA : contrôle qui porte sur plusieurs colonnes, ou sous-cas qui ne doit pas se
# confondre avec un contrôle écrit sur la même colonne (D02c pour un âge, D09 aux seuils).
# Priorité des causes : un contrôle non implémenté porte `non_implemente`, avant toute
# autre cause (declaration_absente pour D02c âge et D07 (c) sans `conventions`, refus d'une
# colonne lue).
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
  .ni("D02c", c("assures", "famille", "designations", "ayants_droit_sante")),
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

# Codes de défaut dont l'objet est un manquant (dictionnaire, § 9) : un manquant dans une
# colonne qui porte l'un d'eux relève de ce défaut, non de `manquant_obligatoire`.
.DEFAUTS_MANQUANT <- c("D03a", "D03b", "D03c", "D03e", "D03f", "D03g", "D03h", "D04a")

# Écart admis entre la somme des parts des bénéficiaires d'un dossier et 1 (somme_parts) :
# erreur d'arrondi d'une somme de fractions en double précision (1/3 + 1/3 + 1/3), non une
# tolérance de gestion.
.TOLERANCE_PARTS <- sqrt(.Machine$double.eps)

# Garanties de rente (dossier porteur d'une ligne de `rentes`, dictionnaire, § 3, T12).
.GARANTIES_RENTE <- c("rente_conjoint", "rente_education", "invalidite")

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
#     ou illisible dans la base (cause = "non_lisible") ; une clé présente aussi dans
#     controles est une détection partielle ;
#   refus_tables : refus R, portée effective colonne ou table, origine d'un refus induit ;
#   exclusions, hypotheses_defaut, signalements, declarations_requises, enjeu : traitements
#     X, H, S et ce qu'ils attendent ;
#   vue : date d'arrêté et d'extraction, lignes de visibilité non déterminée (table,
#     colonne : NA pour la ligne entière, sinon partie de ligne ; motif, dont
#     parente_non_determinee ; nombre, identifiants) et `provisoire` (vrai s'il y en a, ou si
#     une règle P n'a pas pu s'exécuter : comptes de la règle V provisoires) ;
#   segments : vide en Bd (segmentations déclarées en B2) ;
#   tables_absentes : tables facultatives absentes.
# Chaque data.frame est trié par ordre des tables du dictionnaire, puis des colonnes (NA en
# tête), puis par code ; `identifiants` porte les dix premières valeurs de la clé primaire,
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
  declarations <- .lire_declarations(declarations)

  ctx <- .contexte(donnees, dico, extraction, arrete)
  .regle_forme(ctx)
  .regle_domaine(ctx)
  .regle_cles(ctx)
  .refus_induits(ctx)
  .refus_regle_b(ctx)
  .visibilite_propre(ctx)
  .regle_prealable(ctx)
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
# M148) ou liste nommée de rubriques connues (RUBRIQUES_DECLARATIONS). Rend la liste.
.lire_declarations <- function(declarations) {
  if (is.null(declarations)) return(list())
  if (!is.list(declarations) || is.data.frame(declarations) ||
      (length(declarations) > 0L && (is.null(names(declarations)) || anyNA(names(declarations)) ||
                                     any(!nzchar(names(declarations))) || anyDuplicated(names(declarations))))) {
    .refus_plan("`declarations` doit \u00eatre une liste nomm\u00e9e (sous-sch\u00e9ma donnees du plan)")
  }
  inconnues <- setdiff(names(declarations), RUBRIQUES_DECLARATIONS)
  if (length(inconnues) > 0L) {
    .refus_plan(paste0("declarations : rubrique(s) inconnue(s) : ", paste(inconnues, collapse = ", ")))
  }
  declarations
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
# (identifiants du bilan).
.cause <- function(ctx, table, colonne, forme_seule = FALSE) {
  if (!forme_seule && !is.null(ctx$refus_pv)) {
    t <- ctx$refus_pv$tables[[table]]
    if (!is.null(t)) return(t)
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

.ajouter_non_execute <- function(ctx, code, table, colonne, cause) {
  ctx$non_executes[[length(ctx$non_executes) + 1L]] <- list(code = code, table = table,
                                                            colonne = colonne, cause = cause)
  invisible(NULL)
}

# Exécute une règle de détection sur `table` : si une colonne lue (`lit`, chaînes
# « table.colonne », la colonne contrôlée comprise) est inutilisable, la règle va dans
# controles_non_executes avec le motif du refus ; sinon `f()` rend un vecteur logique d'une
# valeur par ligne de `table` (NA : non détecté) et les lignes vraies forment un constat.
# Rend les numéros des lignes détectées (aucun pour une table absente ; NULL si la règle
# n'est pas exécutée).
.regle <- function(ctx, code, table, colonne, lit, traitement, detection, f) {
  if (is.null(ctx$base[[table]])) return(invisible(integer(0)))
  lit <- unique(c(if (!is.na(colonne)) paste(table, colonne, sep = "."), lit))
  for (tc in lit) {
    morceaux <- strsplit(tc, ".", fixed = TRUE)[[1L]]
    cause <- .cause(ctx, morceaux[1L], morceaux[2L])
    if (!is.na(cause)) {
      .ajouter_non_execute(ctx, code, table, colonne, cause)
      return(invisible(NULL))
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
    maxi <- c(31L, 29L, 31L, 30L, 31L, 30L, 31L, 31L, 30L, 31L, 30L, 31L)[ifelse(mois %in% 1:12, mois, NA)]
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
# manquantes : ligne hors du contrôle).
.chevauchements <- function(groupe, debut, fin) {
  res <- rep(FALSE, length(groupe))
  ok <- which(!is.na(groupe) & !is.na(debut) & !is.na(fin))
  for (g in unique(groupe[ok])) {
    i <- ok[groupe[ok] == g]
    if (length(i) < 2L) next
    for (a in seq_along(i)) for (b in seq_along(i)) {
      if (a != b && debut[i[a]] <= fin[i[b]] && debut[i[b]] <= fin[i[a]] &&
          debut[i[a]] <= fin[i[a]] && debut[i[b]] <= fin[i[b]]) res[i[a]] <- TRUE
    }
  }
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
  for (k in ctx$constats) {
    if (k$traitement != "R") next
    if (.portee_effective(ctx$dico, k$code, k$table, k$colonne) == "table") {
      if (is.null(tables[[k$table]])) tables[[k$table]] <- k$code
    } else {
      c1 <- colonnes[[k$table]]
      if (is.null(c1[[k$colonne]])) c1[[k$colonne]] <- k$code
      colonnes[[k$table]] <- c1
    }
  }
  ctx$refus_pv <- list(tables = tables, colonnes = colonnes)
  invisible(NULL)
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
  }
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
# règle P non exécutée à un arrêté antérieur rend la vue provisoire (`p_non_executee`). Les
# déclarations du sous-schéma `donnees` ne sont pas encore lues (sous-partie suivante) :
# aucune hypothèse de D02b ni délai de D03g n'est appliqué.
.regle_prealable <- function(ctx) {
  totale <- .vue_totale(ctx)
  t_b <- if (totale) "S" else "H"
  t_g <- if (totale) "S" else "H;X"
  v <- function(table, colonne) .valeurs(ctx, table, colonne)
  # `partie` : colonne de la partie de ligne indéterminée, NA pour la ligne entière
  marquer <- function(table, motif, lignes, partie = NA_character_) {
    force(lignes)   # exécute la règle à tout arrêté
    if (totale) return(invisible(NULL))
    if (is.null(lignes)) {
      ctx$p_non_executee <- TRUE
      return(invisible(NULL))
    }
    if (length(lignes) == 0L) return(invisible(NULL))
    if (is.na(partie)) ctx$non_determine[[table]][lignes] <- TRUE else ctx$partie_nd[[table]][lignes] <- TRUE
    ctx$lignes_nd[[length(ctx$lignes_nd) + 1L]] <- list(table = table, colonne = partie, motif = motif, lignes = lignes)
    invisible(NULL)
  }
  ctx$lignes_nd <- list()
  ctx$p_non_executee <- FALSE
  avant <- function(x, y) { x <- as.numeric(x); y <- as.numeric(y); !is.na(x) & !is.na(y) & x < y }

  # D02b : saisie antérieure au fait que la ligne enregistre
  marquer("evenements", "D02b", .regle(ctx, "D02b", "evenements", "date_saisie",
    c("evenements.date_effet", "evenements.type_evenement", "evenements.motif"), t_b, "exacte",
    function() avant(v("evenements", "date_saisie"), v("evenements", "date_effet")) & !.programmable(ctx)))
  marquer("sinistres", "D02b", .regle(ctx, "D02b", "sinistres", "date_saisie", "sinistres.date_declaration",
    t_b, "exacte", function() avant(v("sinistres", "date_saisie"), v("sinistres", "date_declaration"))))
  marquer("catastrophes", "D02b", .regle(ctx, "D02b", "catastrophes", "date_saisie", "catastrophes.date_evenement",
    t_b, "exacte", function() avant(v("catastrophes", "date_saisie"), v("catastrophes", "date_evenement"))))
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
  for (table in c("contrats", "affiliations")) {
    marquer(table, "D03g", .regle(ctx, "D03g", table, "date_saisie_fin", paste0(table, ".date_fin"), t_g, "exacte",
      function() is.na(v(table, "date_saisie_fin")) & !is.na(v(table, "date_fin"))), "date_saisie_fin")
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
.regle_vue <- function(ctx, code, table, colonne, lit, traitement, detection, f) {
  if (is.null(ctx$base[[table]])) return(invisible(integer(0)))
  cle <- paste(table, .eclater_champ(ctx$dico$tables$cle_primaire[ctx$dico$tables$table == table])[1L], sep = ".")
  .regle(ctx, code, table, colonne, c(lit, cle, ctx$lit_vue[[table]]), traitement, detection, function() {
    r <- f()
    !is.na(r) & r & ctx$retenu[[table]]
  })
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
# sous-cas (« X;H »...) quand le choix revient à une déclaration ; seuls R et S sont placés au
# bilan dans cette sous-partie (exclusions, hypothèses et déclarations requises : sous-partie
# suivante).
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
  invisible(NULL)
}

# Manquants qui ont un défaut au § 9 (D03a, D03b, D03c, D03e, D03f, D03h), sur la vue.
# D03d (situation de famille requise par un poste) dépend des postes du plan : B2.
.regle_v_manquants <- function(ctx) {
  vv <- function(table, colonne) .valeurs_vue(ctx, table, colonne)
  # D03a : date de naissance manquante (famille : hors enfant à naître)
  .regle_vue(ctx, "D03a", "assures", "date_naissance", character(0), "X;H;S", "exacte",
             function() is.na(vv("assures", "date_naissance")))
  .regle_vue(ctx, "D03a", "famille", "date_naissance", "famille.situation", "X;H;S", "exacte",
             function() is.na(vv("famille", "date_naissance")) & !(vv("famille", "situation") %in% "a_naitre"))
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
    souscrite <- vapply(seq_along(gs), function(i) {
      !is.na(survenance[i]) &&
        any(cle_deces == cle_dossier[i] & !is.na(effet) & effet <= survenance[i] & (is.na(fin) | fin >= survenance[i]))
    }, NA)
    code %in% c("rente_conjoint", "rente_education", "double_effet") & souscrite &
      !(sinistre %in% avec_deces[!is.na(avec_deces)])
  })
  invisible(NULL)
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

  ne <- ctx$non_executes
  non_executes <- data.frame(code = vapply(ne, `[[`, "", "code"), table = vapply(ne, `[[`, "", "table"),
                             colonne = vapply(ne, function(k) k$colonne, ""), cause = vapply(ne, `[[`, "", "cause"),
                             stringsAsFactors = FALSE)
  ni <- CONTROLES_NON_IMPLEMENTES[CONTROLES_NON_IMPLEMENTES$table %in% ctx$tables, , drop = FALSE]
  non_executes <- rbind(data.frame(ni, cause = rep(CAUSE_NON_IMPLEMENTE, nrow(ni)), stringsAsFactors = FALSE),
                        non_executes)
  # une ligne par (code, table, colonne), première cause dans l'ordre de priorité ; une
  # règle empêchée reste toujours ici, même si une autre règle de même clé a détecté : la
  # clé présente aussi dans controles est une détection partielle, dont le nombre est un
  # minorant (ADR 0010, huitième série, (e))
  cle_ne <- paste(non_executes$code, non_executes$table, non_executes$colonne, sep = "\r")
  non_executes <- non_executes[!duplicated(cle_ne), , drop = FALSE]

  ordre <- order(traitement, method = "radix")   # départage reproductible de deux traitements d'une même clé
  controles <- controles[ordre, , drop = FALSE]
  traitement <- traitement[ordre]
  origine <- ch(function(k) k$origine)[ordre]
  r <- traitement == "R"
  refus <- data.frame(table = controles$table[r], colonne = controles$colonne[r], motif = controles$code[r],
                      portee = vapply(which(r), function(i) .portee_effective(dico, controles$code[i],
                                                                              controles$table[i], controles$colonne[i]), ""),
                      origine = origine[r], nombre = controles$nombre[r],
                      nombre_visibles = rep(NA_integer_, sum(r)), identifiants = controles$identifiants[r],
                      nombre_dossiers = rep(NA_integer_, sum(r)), postes_arretes = rep(NA_character_, sum(r)),
                      stringsAsFactors = FALSE)
  s <- traitement == "S"
  signalements <- data.frame(code = controles$code[s], table = controles$table[s], colonne = controles$colonne[s],
                             detection = controles$detection[s], nombre = controles$nombre[s],
                             identifiants = controles$identifiants[s], stringsAsFactors = FALSE)
  nd <- .visibilite_non_determinee(ctx)
  absentes <- dico$tables$table[dico$tables$obligatoire != "O" & !(dico$tables$table %in% names(ctx$base))]
  if ("catastrophes" %in% names(ctx$base)) absentes <- setdiff(absentes, "victimes")
  list(
    controles = .trier(controles, dico),
    controles_non_executes = .trier(non_executes, dico),
    refus_tables = .trier(refus, dico, "motif"),
    exclusions = data.frame(motif = character(0), famille = character(0), action = character(0),
                            nombre_lignes = integer(0), nombre_dossiers = integer(0), stringsAsFactors = FALSE),
    hypotheses_defaut = data.frame(motif = character(0), referentiel = character(0), poste = character(0),
                                   valeur = character(0), nombre = integer(0), stringsAsFactors = FALSE),
    signalements = .trier(signalements, dico),
    declarations_requises = data.frame(rubrique = character(0), motif = character(0), cle = character(0),
                                       traitements_admis = character(0), nombre_lignes = integer(0),
                                       stringsAsFactors = FALSE),
    enjeu = data.frame(table = character(0), colonne = character(0), motif = character(0), famille = character(0),
                       action = character(0), garantie = character(0), poste = character(0),
                       composante = character(0), unite = character(0), montant = numeric(0),
                       nombre_dossiers = integer(0), nombre_valeurs = integer(0), cause = character(0),
                       stringsAsFactors = FALSE),
    vue = list(date_arrete = ctx$arrete, date_extraction = ctx$date_extraction,
               visibilite_non_determinee = nd, provisoire = nrow(nd) > 0L || isTRUE(ctx$p_non_executee)),
    segments = data.frame(id_dossier = character(0), id_sinistre = character(0), id_contrat = character(0),
                          segmentation = character(0), segment = character(0), stringsAsFactors = FALSE),
    tables_absentes = absentes
  )
}
