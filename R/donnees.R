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
# clés et refus induits (règle B, indépendante de l'arrêté) ; puis détection de D02b et
# D03g (règle P), vue, règle V et enjeu.
# État de ce fichier (lot (c), deuxième partie, commit (i)) : interruptions et règle B
# seulement. L'état partiel est porté par l'objet rendu : chaque contrôle prévu par la
# spécification et non encore écrit (CONTROLES_NON_IMPLEMENTES : D04a et D04b traités X,
# règle P, règle V dont D02c pour un âge et D07, somme_parts) figure dans
# controles_non_executes avec la cause `non_implemente`. Les exclusions, hypothèses par
# défaut, déclarations requises et l'enjeu viennent avec les commits (ii) et (iii) : leurs
# éléments du bilan sont rendus vides, et nombre_visibles et nombre_dossiers valent NA.

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
# bilan dise lui-même qu'il est partiel. La liste se vide au fil des commits (ii) et (iii).
# Colonne NA : contrôle qui porte sur plusieurs colonnes, ou sous-cas qui ne doit pas se
# confondre avec un contrôle écrit sur la même colonne (D02c pour un âge, D09 aux seuils).
# Priorité des causes : un contrôle non implémenté porte `non_implemente`, avant toute
# autre cause (declaration_absente pour D02c âge et D07 (c) sans `conventions`, refus d'une
# colonne lue).
CAUSE_NON_IMPLEMENTE <- "non_implemente"
.ni <- function(code, table, colonne = NA_character_) {
  data.frame(code = code, table = table, colonne = colonne, stringsAsFactors = FALSE)
}
CONTROLES_NON_IMPLEMENTES <- rbind(
  .ni("D01b", c("sinistres", "dossiers", "evenements", "prestations", "cotisations")),
  .ni("D02a", c("contrats", "garanties_souscrites", "affiliations", "famille", "sinistres", "evenements",
                "prestations", "cotisations", "ayants_droit_sante")),
  .ni("D02b", c("contrats", "famille", "sinistres", "dossiers", "beneficiaires", "rentes", "evenements",
                "catastrophes", "victimes")),
  .ni("D02c", c("assures", "famille", "designations", "ayants_droit_sante")),
  .ni("D03a", c("assures", "famille"), "date_naissance"),
  .ni("D03b", c("assures", "famille"), "sexe"),
  .ni("D03c", "affiliations", "salaire_reference"),
  .ni("D03d", "assures", "situation_familiale"),
  .ni("D03e", "evenements", "categorie_invalidite"),
  .ni("D03f", c("prestations", "cotisations")),
  .ni("D03g", c("contrats", "affiliations", "famille", "sinistres", "beneficiaires", "rentes", "evenements",
                "prestations", "designations", "ayants_droit_sante")),
  .ni("D03h", "garanties_souscrites", "taux_technique_tarif"),
  .ni("D04a", "prestations", c("id_dossier", "id_rente")),
  .ni("D04b", c("evenements", "evenements", "evenements", "beneficiaires", "beneficiaires", "rentes", "rentes",
                "cotisations", "victimes", "victimes", "victimes", "designations", "ayants_droit_sante",
                "ayants_droit_sante"),
      c("id_sinistre", "id_dossier", "id_rente", "id_dossier", "id_membre", "id_dossier", "id_membre",
        "id_garantie_souscrite", "id_catastrophe", "id_assure", "id_sinistre", "id_affiliation",
        "id_affiliation", "id_assure_membre")),
  .ni("D05", "evenements", "motif"),
  .ni("D06", "evenements", "justificatif"),
  .ni("D07", "evenements"),
  .ni("D08", "sinistres"),
  .ni("D09", c("parametres", "affiliations", "evenements", "prestations", "cotisations")),
  .ni("D10b", "dossiers", "id_garantie_souscrite"),
  .ni("D10c", "dossiers"),
  .ni("D10d", "evenements"),
  .ni("D10e", "beneficiaires", "qualite"),
  .ni("D10f", "evenements"),
  .ni("D11", "sinistres", "date_survenance"),
  .ni("D12", "evenements", "type_evenement"),
  .ni("D13", "sinistres", "date_instruction"),
  .ni("D14", "famille"),
  .ni("somme_parts", "beneficiaires", "part")
)

# Règle de limite d'âge de D07 (c) (M155) et conventions d'âge admises pour cet emploi
# (spécification, § 5.3 ; M154 : naissance réelle de l'enfant).
REGLES_LIMITE_AGE <- c("atteinte", "depassement")
CONVENTIONS_LIMITE_AGE <- c("revolu", "millesime")

# Codes de défaut dont l'objet est un manquant (dictionnaire, § 9) : un manquant dans une
# colonne qui porte l'un d'eux relève de ce défaut, non de `manquant_obligatoire`.
.DEFAUTS_MANQUANT <- c("D03a", "D03b", "D03c", "D03e", "D03f", "D03g", "D03h", "D04a")

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
#     "non_implemente", CONTROLES_NON_IMPLEMENTES : le bilan dit lui-même qu'il est partiel) ;
#   refus_tables : refus R, portée effective colonne ou table, origine d'un refus induit ;
#   exclusions, hypotheses_defaut, signalements, declarations_requises, enjeu : traitements
#     X, H, S et ce qu'ils attendent ;
#   vue : date d'arrêté et d'extraction ;
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

# Motif qui empêche de lire `table.colonne`, NA si elle se lit.
.cause <- function(ctx, table, colonne) {
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
.regle <- function(ctx, code, table, colonne, lit, traitement, detection, f) {
  if (is.null(ctx$base[[table]])) return(invisible(NULL))
  lit <- unique(c(if (!is.na(colonne)) paste(table, colonne, sep = "."), lit))
  for (tc in lit) {
    morceaux <- strsplit(tc, ".", fixed = TRUE)[[1L]]
    cause <- .cause(ctx, morceaux[1L], morceaux[2L])
    if (!is.na(cause)) return(.ajouter_non_execute(ctx, code, table, colonne, cause))
  }
  lignes <- which(f())
  if (length(lignes) > 0L) .ajouter_constat(ctx, code, table, colonne, lignes, traitement, detection)
  invisible(NULL)
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
  te <- ctx$dico$types_evenements
  .regle(ctx, "D02c", "evenements", "date_effet", c("evenements.type_evenement", "evenements.motif"),
         "R", "exacte", function() {
    v <- as.numeric(.valeurs(ctx, "evenements", "date_effet"))
    type <- .valeurs(ctx, "evenements", "type_evenement")
    motif <- .valeurs(ctx, "evenements", "motif")
    prog <- te$programmable[match(type, te$type_evenement)]
    admis <- !is.na(prog) & (prog == "oui" | (startsWith(prog, "oui:") &
      mapply(function(p, m) !is.na(m) && m %in% .eclater_champ(substring(p, 5L)), prog, motif)))
    v < borne_basse | (!admis & v > extraction)
  })
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
    colonnes <- .colonnes_dico(ctx, table)
    for (i in which(nzchar(colonnes$reference))) {
      colonne <- colonnes$colonne[i]
      cibles <- strsplit(.eclater_champ(colonnes$reference[i]), ".", fixed = TRUE)
      table_cible <- cibles[[1L]][1L]
      cols_cible <- vapply(cibles, `[`, "", 2L)
      locales <- if (length(cibles) == 1L) colonne else cols_cible
      code <- if (table == "prestations") "D04a" else "D04b"
      traitement <- if (code == "D04a" || (table %in% .TABLES_D04B_X && length(cibles) == 1L)) "X" else "R"
      if (traitement == "X") next   # D04a et D04b traités X : CONTROLES_NON_IMPLEMENTES
      .regle(ctx, code, table, colonne, c(paste(table, locales, sep = "."), paste(table_cible, cols_cible, sep = ".")),
             traitement, "exacte", function() {
        local <- do.call(paste, c(lapply(locales, function(c1) .valeurs(ctx, table, c1)), sep = "\r"))
        cible <- do.call(paste, c(lapply(cols_cible, function(c1) .valeurs(ctx, table_cible, c1)), sep = "\r"))
        # une chaîne vide est chaine_vide, non une orpheline (une anomalie, un code : m1)
        present <- Reduce(`&`, lapply(locales, function(c1) {
          x <- .valeurs(ctx, table, c1)
          !is.na(x) & (!is.character(x) | x != "")
        }))
        present & !(local %in% cible)
      })
    }
  }
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

# --- Bilan ---------------------------------------------------------------------------

# Identifiants des lignes : dix premières valeurs de la clé primaire, triées (sort radix,
# indépendant de la locale), jointes par « ; » ; une clé composite s'écrit colonnes jointes
# par « | », valeurs en écriture canonique (manquant : \N, ou NA pour une date ; « | » et
# « ; » d'une valeur écrits \x7c et \x3b). Chaîne vide
# si la clé n'est pas lisible.
.identifiants <- function(ctx, table, lignes) {
  if (length(lignes) == 0L) return("")
  cle <- .eclater_champ(ctx$dico$tables$cle_primaire[ctx$dico$tables$table == table])
  if (length(cle) == 0L || any(!is.na(vapply(cle, function(c1) .cause(ctx, table, c1), "")))) return("")
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
  cle_ne <- paste(non_executes$code, non_executes$table, non_executes$colonne, sep = "\r")
  # Règle de la réserve m2 : plusieurs règles partagent un même (code, table, colonne) ;
  # si l'une a détecté (ligne de controles) et qu'une autre n'a pas pu s'exécuter, la ligne
  # de controles reste seule (son nombre est alors un minorant, jamais un zéro rassurant) ;
  # si aucune n'a détecté, la ligne non exécutée reste.
  cle_ct <- paste(controles$code, controles$table, controles$colonne, sep = "\r")
  non_executes <- non_executes[!duplicated(cle_ne) & !(cle_ne %in% cle_ct), , drop = FALSE]

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
    vue = list(date_arrete = ctx$arrete, date_extraction = ctx$date_extraction),
    segments = data.frame(id_dossier = character(0), id_sinistre = character(0), id_contrat = character(0),
                          segmentation = character(0), segment = character(0), stringsAsFactors = FALSE),
    tables_absentes = absentes
  )
}
