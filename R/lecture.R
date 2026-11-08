# Module `lecture` (ADR 0010, points 1 et 2) : couche mince de lecture et d'écriture des
# fichiers d'une base, hors de la chaîne du moteur (aucun module du moteur ne l'appelle).
# Format : celui du dictionnaire, § 1.2 (CSV UTF-8 sans marque d'ordre, virgule, point
# décimal, guillemets doubles, dates AAAA-MM-JJ, logiques TRUE / FALSE) et § 1.6 (le champ
# vide est le seul marqueur de manquant). Un fichier par table : <dossier>/<table>.csv.
# N'appelle que les modules `dictionnaire` et `outils`. Ne parle pas (point 12).
# Code ASCII hors commentaires (M112) : les accents des chaînes s'écrivent en \uXXXX.
# Convention de ce fichier : une fonction dont le nom commence par un point est un
# auxiliaire du module ; la concordance documentation <-> code ne recense que les autres.
#
# Types imposés à la lecture : chaque fichier est lu par utils::read.csv() en texte
# (colClasses = "character", na.strings = ""), puis chaque colonne connue du dictionnaire
# est lue dans son type par une grammaire stricte (.lire_colonne). colClasses = <type du
# dictionnaire> n'est pas employé : read.csv() y convertit en silence (mesure du
# 8 novembre 2026, R 4.3.3 : « 0x10 » lu 16 et « NA » lu manquant en numeric, « 26-01-02 »
# lu en l'an 26 et « 2026/01/02 » admis en Date, « T » et « true » admis en logical,
# « 1 » précédé d'une espace admis en integer). Une colonne entièrement vide prend ainsi
# le type déclaré, jamais logical.

# --- Lecture ---------------------------------------------------------------------

# Lit une base écrite en CSV dans `dossier` : un fichier <table>.csv par table présente,
# toutes facultatives ici : une table obligatoire absente n'est pas contrôlée ici, mais par
# le contrôle de la base entière (module `donnees`). Refus :
#   - liste_invalide : dossier introuvable ou qui n'est pas un dossier ; tout autre fichier
#     ou dossier que <table>.csv ; fichier mal formé (vide, marque d'ordre, UTF-8 invalide,
#     octet nul, fin de ligne finale absente, retour chariot isolé hors guillemets,
#     guillemet au milieu d'un champ, champs en nombre variable, en-tête illisible) ;
#   - type_incompatible, sans conversion, en nommant table, colonne et lignes de données :
#     valeur illisible dans le type déclaré ; chaîne vide entre guillemets ("") dans tout
#     type de colonne ; retour chariot dans un champ entre guillemets (.controler_guillemets) ;
#   - colonne_inconnue, colonne_absente : par controler_types(), appelé sur le résultat ;
#   - extraction_invalide : version de la table extraction, contrôlée avant toute autre
#     colonne, puis nombre de lignes.
# Tolérances admises (jugées admissibles par `actuary` : les guillemets délimitent le
# champ, ils ne portent pas le type) :
#   - toute valeur, entre guillemets ou non, quel que soit son type (entier, réel, date,
#     logique : "12" se lit 12L) ;
#   - zéros de tête pour integer et numeric (007, 007.50) ;
#   - chaîne sans guillemets, ses espaces conservées ; NA nu se lit comme la valeur "NA"
#     (le champ vide est le seul manquant) ;
#   - fins de ligne CRLF (hors des champs entre guillemets).
# Rend une liste nommée de data.frame, dans l'ordre des tables du dictionnaire, colonnes
# dans l'ordre du fichier, noms de lignes automatiques.
lire_base <- function(dossier) {
  .controler_dossier(dossier, "lire_base")
  if (!file.exists(dossier)) {
    .refus_lecture(paste0("lire_base() : dossier introuvable : ", dossier))
  }
  if (!dir.exists(dossier)) {
    .refus_lecture(paste0("lire_base() : ", dossier, " existe et n'est pas un dossier"))
  }
  dico <- dictionnaire()
  noms_tables <- dico$tables$table
  entrees <- sort(list.files(dossier, all.files = TRUE, no.. = TRUE), method = "radix")
  tables_lues <- sub("\\.csv$", "", entrees)
  inconnus <- entrees[!grepl("\\.csv$", entrees) | !(tables_lues %in% noms_tables) |
                        dir.exists(file.path(dossier, entrees))]
  if (length(inconnus) > 0L) {
    .refus_lecture(paste0("lire_base() : fichier(s) inconnu(s) du dictionnaire dans ", dossier,
                          " (un fichier <table>.csv par table, rien d'autre) : ",
                          paste(inconnus, collapse = ", ")),
                   nombre = length(inconnus), identifiants = inconnus)
  }
  base <- list()
  for (table in noms_tables[noms_tables %in% tables_lues]) {
    colonnes <- dico$colonnes[dico$colonnes$table == table, , drop = FALSE]
    base[[table]] <- .lire_table_csv(file.path(dossier, paste0(table, ".csv")), table, colonnes)
  }
  controler_types(base)
  base
}

.refus_lecture <- function(message, motif = "liste_invalide", ...) {
  refuser(message, motif, module = "lecture", ...)
}

.controler_dossier <- function(dossier, fonction) {
  if (!is.character(dossier) || length(dossier) != 1L || is.na(dossier) || !nzchar(dossier)) {
    .refus_lecture(paste0(fonction, "() : `dossier` doit \u00eatre un chemin (cha\u00eene unique)"))
  }
  invisible(NULL)
}

# Lit un fichier <table>.csv : contrôle des octets, des guillemets et de l'en-tête, lecture
# en texte, version de la table extraction, puis lecture typée des colonnes connues.
.lire_table_csv <- function(chemin, table, colonnes) {
  fichier <- basename(chemin)
  mal_forme <- function(raison) {
    .refus_lecture(paste0("table ", table, " : fichier ", fichier, " mal form\u00e9 (", raison, ")"),
                   table = table)
  }
  taille <- file.info(chemin)$size
  if (is.na(taille) || taille == 0) mal_forme("fichier vide")
  octets <- readBin(chemin, "raw", n = taille)
  if (length(octets) >= 3L && identical(octets[1:3], as.raw(c(0xef, 0xbb, 0xbf)))) {
    mal_forme("marque d'ordre UTF-8 en t\u00eate ; UTF-8 sans marque d'ordre attendu")
  }
  if (any(octets == as.raw(0L))) mal_forme("octet nul")
  texte <- rawToChar(octets)
  Encoding(texte) <- "UTF-8"
  if (!validUTF8(texte)) mal_forme("contenu non UTF-8")
  if (octets[length(octets)] != as.raw(0x0a)) mal_forme("fin de ligne finale absente")
  # En-tête lu à part, champs entre guillemets compris : read.csv() fait d'une première
  # colonne sans nom des noms de lignes, ou une colonne « row.names », quand l'en-tête a
  # un champ de moins que les données.
  premiere <- sub("\r$", "", substr(texte, 1L, regexpr("\n", texte, fixed = TRUE) - 1L))
  entete <- tryCatch(
    scan(text = premiere, what = "", sep = ",", quote = "\"", na.strings = character(0),
         quiet = TRUE, strip.white = FALSE, comment.char = "", allowEscapes = FALSE,
         encoding = "UTF-8"),
    error = function(e) mal_forme(paste0("en-t\u00eate illisible : ", conditionMessage(e))),
    warning = function(w) mal_forme(paste0("en-t\u00eate illisible : ", conditionMessage(w))))
  .controler_guillemets(octets, texte, table, entete, colonnes, mal_forme)
  brut <- tryCatch(
    utils::read.csv(chemin, header = TRUE, sep = ",", quote = "\"", dec = ".",
                    colClasses = "character", na.strings = "", encoding = "UTF-8",
                    check.names = FALSE, strip.white = FALSE, fill = FALSE,
                    blank.lines.skip = FALSE, comment.char = "", row.names = NULL,
                    stringsAsFactors = FALSE),
    error = function(e) mal_forme(conditionMessage(e)),
    warning = function(w) mal_forme(conditionMessage(w)))
  if (!identical(names(brut), entete)) {
    mal_forme("l'en-t\u00eate a un champ de moins que les lignes de donn\u00e9es")
  }
  if (table == "extraction") .controler_version_extraction(brut)
  for (j in seq_along(brut)) {
    i <- match(names(brut)[j], colonnes$colonne)
    if (!is.na(i)) brut[[j]] <- .lire_colonne(brut[[j]], colonnes$type[i], table, colonnes$colonne[i])
  }
  brut
}

# Champs entre guillemets d'un fichier, contrôlés sur les octets avant read.csv(), qui les
# lirait autrement sans le dire (mesures du 8 novembre 2026, R 4.3.3) :
#   - "ab"cd est lu abcd : un champ entre guillemets doit commencer un champ et le finir
#     (précédé d'une virgule ou d'une fin de ligne, suivi d'une virgule ou d'une fin de
#     ligne) ; dans un CSV bien formé, la recherche de gauche à droite ne trouve que ces
#     champs-là (refus liste_invalide, fichier mal formé) ;
#   - "" (chaîne vide entre guillemets, motif de longueur 2) est lu NA par na.strings = "",
#     quel que soit le type ; """" (un guillemet) et "a""b" restent admis ;
#   - un octet 0x0d dans un champ entre guillemets est lu comme une fin de ligne : "A\r\nB"
#     et "A\nB" seraient tous deux relus "A\nB" (faux doublon d'identifiants), dans un
#     fichier LF comme dans un fichier CRLF.
# Ces deux derniers cas sont refusés par type_incompatible, en nommant la table, la colonne
# et la ligne de données : la valeur du champ ne se lit pas sans conversion, comme une
# valeur illisible dans son type (.lire_colonne) ; liste_invalide reste aux fichiers mal
# formés. Hors guillemets, un 0x0d qui n'est pas suivi de 0x0a (fin de ligne CRLF) est un
# fichier mal formé.
.controler_guillemets <- function(octets, texte, table, entete, colonnes, mal_forme) {
  n <- length(octets)
  guillemets <- gregexpr("\"(?:[^\"]++|\"\")*+\"", texte, perl = TRUE, useBytes = TRUE)[[1L]]
  debut <- if (guillemets[1L] == -1L) integer(0) else as.integer(guillemets)
  fin <- debut + attr(guillemets, "match.length")[seq_along(debut)] - 1L
  avant <- octets[pmax(debut - 1L, 1L)]
  apres <- octets[pmin(fin + 1L, n)]
  if (any(debut > 1L & !(avant %in% as.raw(c(0x2c, 0x0a)))) ||
      any(fin == n | !(apres %in% as.raw(c(0x2c, 0x0a, 0x0d))))) {
    mal_forme("guillemet au milieu d'un champ")
  }
  retours <- which(octets == as.raw(0x0d))
  vides <- debut[fin - debut == 1L]
  if (length(retours) == 0L && length(vides) == 0L) return(invisible(NULL))
  # octets à l'intérieur d'un champ entre guillemets (guillemets compris)
  bornes <- integer(n + 1L)
  bornes[debut] <- 1L
  bornes[fin + 1L] <- bornes[fin + 1L] - 1L
  dedans <- cumsum(bornes)[seq_len(n)] > 0L
  fins_ligne <- which(octets == as.raw(0x0a) & !dedans)
  virgules <- which(octets == as.raw(0x2c) & !dedans)
  # ligne (0 : en-tête) et rang du champ de chaque position
  situer <- function(p) {
    ligne <- findInterval(p, fins_ligne)
    depart <- ifelse(ligne == 0L, 1L, fins_ligne[pmax(ligne, 1L)] + 1L)
    list(ligne = ligne, champ = findInterval(p, virgules) - findInterval(depart - 1L, virgules) + 1L)
  }
  refus_champ <- function(positions, raison, recu) {
    ou <- situer(positions)
    if (ou$ligne[1L] == 0L) mal_forme(paste0("en-t\u00eate : ", raison))
    colonne <- if (ou$champ[1L] <= length(entete)) entete[ou$champ[1L]] else NA_character_
    type <- colonnes$type[match(colonne, colonnes$colonne)]
    refuser(paste0("table ", table, ", colonne ", colonne, ", ligne de donn\u00e9es ", ou$ligne[1L],
                   " : ", raison, " ; ", length(positions), " champ(s) dans le fichier, aucune conversion"),
            "type_incompatible", module = "lecture", table = table, colonne = colonne,
            nombre = length(positions), identifiants = as.character(ou$ligne),
            attendu = if (is.na(type)) NA_character_ else type, recu = recu)
  }
  if (length(vides) > 0L) {
    refus_champ(vides, paste0("cha\u00eene vide entre guillemets (\"\") ; le champ vide est le seul",
                              " marqueur de manquant (dictionnaire, \u00a7 1.6)"), "\"\"")
  }
  retours_dedans <- retours[dedans[retours]]
  if (length(retours_dedans) > 0L) {
    refus_champ(retours_dedans, paste0("retour chariot (octet 0x0d) dans un champ entre guillemets,",
                                       " que read.csv() lirait comme un saut de ligne"), "\\r")
  }
  retours <- retours[!dedans[retours]]
  if (any(retours == n | octets[pmin(retours + 1L, n)] != as.raw(0x0a))) {
    mal_forme("retour chariot isol\u00e9 hors guillemets")
  }
  invisible(NULL)
}

# Lit une colonne de texte (NA : champ vide) dans le type du dictionnaire, ou refuse
# (type_incompatible) en nommant la première valeur illisible et ses numéros de ligne de
# données (dix au plus).
.lire_colonne <- function(x, type, table, colonne) {
  presents <- !is.na(x)
  refus <- function(illisibles, precision = "") {
    lignes <- which(illisibles)
    refuser(paste0("table ", table, ", colonne ", colonne, " : ", length(lignes),
                   " valeur(s) illisible(s) dans le type ", type, precision,
                   ", premi\u00e8re \u00ab ", x[lignes[1L]], " \u00bb (ligne de donn\u00e9es ",
                   lignes[1L], ") ; aucune conversion"),
            "type_incompatible", module = "lecture", table = table, colonne = colonne,
            nombre = length(lignes), identifiants = as.character(lignes),
            attendu = type, recu = x[lignes[1L]])
  }
  if (type == "character") {
    return(x)
  }
  if (type == "logical") {
    illisibles <- presents & !(x %in% c("TRUE", "FALSE"))
    if (any(illisibles)) refus(illisibles, " (TRUE ou FALSE)")
    return(x == "TRUE")
  }
  if (type == "integer") {
    illisibles <- presents & !grepl("^-?[0-9]+$", x)
    if (any(illisibles)) refus(illisibles, " (entier d\u00e9cimal sans point ni exposant)")
    valeurs <- as.numeric(x)
    illisibles <- presents & abs(valeurs) > .Machine$integer.max
    if (any(illisibles)) refus(illisibles, " (hors des bornes des entiers de R)")
    return(as.integer(valeurs))
  }
  if (type == "numeric") {
    illisibles <- presents & !grepl("^-?[0-9]+(\\.[0-9]+)?([eE][-+]?[0-9]+)?$", x)
    if (any(illisibles)) refus(illisibles, " (nombre d\u00e9cimal \u00e0 point, exposant facultatif)")
    valeurs <- as.numeric(x)
    # un dépassement rendrait Inf, un soupassement 0 : aucun des deux n'est la valeur écrite
    illisibles <- presents & (!is.finite(valeurs) |
                                (valeurs == 0 & grepl("[1-9]", sub("[eE].*$", "", x))))
    if (any(illisibles)) refus(illisibles, " (hors de l'\u00e9tendue des r\u00e9els double pr\u00e9cision)")
    return(valeurs)
  }
  if (type == "Date") {
    illisibles <- presents & !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", x)
    if (any(illisibles)) refus(illisibles, " (AAAA-MM-JJ)")
    valeurs <- as.Date(x, format = "%Y-%m-%d")
    illisibles <- presents & is.na(valeurs)
    if (any(illisibles)) refus(illisibles, " (date inexistante)")
    return(valeurs)
  }
  refuser(paste0("table ", table, ", colonne ", colonne, " : type ", type, " inconnu"),
          "type_incompatible", module = "lecture", table = table, colonne = colonne)
}

# --- Écriture --------------------------------------------------------------------

# Écrit une base (liste nommée de data.frame, contrôlée par controler_types()) en CSV
# dans `dossier`, un fichier <table>.csv par table, dans le format que lit lire_base() :
# en-tête des noms de colonnes, chaînes entre guillemets doubles (guillemet intérieur
# doublé), manquant écrit en champ vide, entiers en décimal, réels à 15 chiffres
# significatifs, ou 16, ou 17 (le premier qui se relit à l'identique), dates AAAA-MM-JJ,
# logiques TRUE / FALSE, fins de ligne \n. `dossier` est créé s'il n'existe pas (son
# parent doit exister) ; s'il existe, il doit être vide (un fichier ancien serait relu
# avec la base). Refuse (liste_invalide), avant toute écriture, ce que le CSV ne
# relirait pas à l'identique : chaîne vide "" (le champ vide est le seul manquant, § 1.6),
# chaîne qui contient un retour chariot, réel non fini (Inf, -Inf, NaN), chaîne non UTF-8
# ou d'encodage inconnu hors locale UTF-8, date hors de quatre chiffres d'année. Les noms
# de lignes ne sont pas écrits. Rend `dossier`, invisible : lire_base(ecrire_base(x, d))
# rend `x` à l'identique quand `x` liste ses tables dans l'ordre du dictionnaire et porte
# des noms de lignes automatiques.
ecrire_base <- function(donnees, dossier) {
  .controler_dossier(dossier, "ecrire_base")
  controler_types(donnees)
  dico <- dictionnaire()
  tables <- dico$tables$table[dico$tables$table %in% names(donnees)]
  contenus <- lapply(tables, function(table) .texte_table_csv(donnees[[table]], table))
  if (file.exists(dossier)) {
    if (!dir.exists(dossier)) {
      .refus_lecture(paste0("ecrire_base() : ", dossier, " existe et n'est pas un dossier"))
    }
    if (length(list.files(dossier, all.files = TRUE, no.. = TRUE)) > 0L) {
      .refus_lecture(paste0("ecrire_base() : le dossier ", dossier,
                            " n'est pas vide ; un fichier ancien serait relu avec la base"))
    }
  } else if (!dir.create(dossier, showWarnings = FALSE)) {
    .refus_lecture(paste0("ecrire_base() : dossier ", dossier, " impossible \u00e0 cr\u00e9er"))
  }
  for (k in seq_along(tables)) {
    writeBin(contenus[[k]], file.path(dossier, paste0(tables[k], ".csv")))
  }
  invisible(dossier)
}

# Octets du CSV d'une table.
.texte_table_csv <- function(donnee, table) {
  champs <- lapply(names(donnee), function(colonne) .champs_colonne(donnee[[colonne]], table, colonne))
  lignes <- if (length(champs) == 0L) character(0) else do.call(paste, c(champs, sep = ","))
  texte <- paste0(paste(c(paste(names(donnee), collapse = ","), lignes), collapse = "\n"), "\n")
  charToRaw(texte)
}

# Champs CSV d'une colonne, de type déjà contrôlé ; NA s'écrit en champ vide.
.champs_colonne <- function(x, table, colonne) {
  ou <- paste0("table ", table, ", colonne ", colonne)
  refus <- function(raison, n) {
    .refus_lecture(paste0("ecrire_base() : ", ou, " : ", raison), table = table, colonne = colonne,
                   nombre = n)
  }
  # paste0("\"", character(0), "\"") rendrait "\"\"" : une table sans ligne en aurait une
  if (length(x) == 0L) return(character(0))
  manquants <- is.na(x) & !is.nan(x)   # NaN n'est pas un manquant : il est refusé plus bas
  # les refus des auxiliaires d'`outils` (date non entière ou hors de quatre chiffres
  # d'année, encodage) sont relevés au nom de `lecture`, avec la table et la colonne
  relever <- function(expr) {
    tryCatch(expr, refus_provie = function(e) {
      .refus_lecture(paste0("ecrire_base() : ", ou, " : ", conditionMessage(e)), motif = e$motif,
                     table = table, colonne = colonne)
    })
  }
  if (inherits(x, "Date")) {
    champs <- relever(ecrire_valeurs(x, "texte"))
  } else if (is.character(x)) {
    x <- relever(.vers_utf8(x, "valeur"))
    vides <- !manquants & x == ""
    if (any(vides)) {
      refus(paste0("cha\u00eene vide \"\" ; le champ vide est le seul marqueur de manquant en CSV",
                   " (dictionnaire, \u00a7 1.6), elle serait relue NA"), sum(vides))
    }
    retours <- !manquants & grepl("\r", x, fixed = TRUE)
    if (any(retours)) refus("cha\u00eene contenant un retour chariot, que la lecture CSV ne rend pas", sum(retours))
    champs <- paste0("\"", gsub("\"", "\"\"", x, fixed = TRUE), "\"")
  } else if (is.logical(x)) {
    champs <- c("FALSE", "TRUE")[x + 1L]
  } else if (is.integer(x)) {
    champs <- sprintf("%d", x)
  } else {
    non_finis <- !manquants & !is.finite(x)
    if (any(non_finis)) refus("r\u00e9el non fini (Inf, -Inf ou NaN), sans \u00e9criture CSV", sum(non_finis))
    champs <- .reels_csv(x)
  }
  champs[manquants] <- ""
  champs
}

# Réels finis au plus court parmi 15, 16 et 17 chiffres significatifs qui se relit à
# l'identique (17 suffit toujours) ; -0 s'écrit 0.
.reels_csv <- function(x) {
  x[which(x == 0)] <- 0
  champs <- sprintf("%.15g", x)
  presents <- which(!is.na(x))
  for (chiffres in c(16L, 17L)) {
    a_reprendre <- presents[as.numeric(champs[presents]) != x[presents]]
    champs[a_reprendre] <- sprintf(paste0("%.", chiffres, "g"), x[a_reprendre])
  }
  champs
}
