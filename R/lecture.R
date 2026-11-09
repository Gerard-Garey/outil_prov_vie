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
# Lecture « fidélité ou refus » (ADR 0010, cinquième série, (c) ; M144, M150) : chaque
# fichier est lu par utils::read.csv() en texte (colClasses = "character",
# na.strings = ""), la chaîne vide entre guillemets ("") rétablie à sa place, puis chaque
# colonne connue du dictionnaire est lue dans son type par la grammaire stricte
# lire_texte_type() (module `dictionnaire`) si toutes ses valeurs s'y lisent ; sinon elle
# est rendue entière en texte exact, sans conversion. colClasses = <type du dictionnaire>
# n'est pas employé : read.csv() y convertit en silence (mesure du 8 novembre 2026,
# R 4.3.3 : « 0x10 » lu 16 et « NA » lu manquant en numeric, « 26-01-02 » lu en l'an 26 et
# « 2026/01/02 » admis en Date, « T » et « true » admis en logical, « 1 » précédé d'une
# espace admis en integer). Une colonne entièrement vide prend ainsi le type déclaré,
# jamais logical.

# --- Lecture ---------------------------------------------------------------------

# Lit une base écrite en CSV dans `dossier` : un fichier <table>.csv par table présente,
# toutes facultatives ici : une table obligatoire absente n'est pas contrôlée ici, mais par
# le contrôle de la base entière (module `donnees`).
# Ne s'interrompt (fichier_invalide) que si elle ne peut pas rendre le texte exact d'un
# fichier (M141, M144) : dossier introuvable ou qui n'est pas un dossier ; tout autre
# fichier ou dossier que <table>.csv ; fichier mal formé (vide, marque d'ordre, UTF-8
# invalide, octet nul, fin de ligne finale absente, retour chariot isolé hors guillemets,
# guillemet au milieu d'un champ ou non fermé, champs en nombre variable, première ligne vide, en-tête
# illisible, nom de colonne vide ou en double) ; retour chariot dans un champ entre
# guillemets, que read.csv() lit comme un saut de ligne (« A\r\nB » et « A\rB » sont relus
# « A\nB », mesure du 8 novembre 2026, R 4.3.3), en nommant table, colonne et lignes de
# données. Le contrôle de la structure du fichier précède toute localisation d'un champ.
# Et, pour la table extraction (refus d'appel de toute façon, ADR 0010, cinquième série,
# (a) 1 ; M150, lecture (i)) : version du dictionnaire, lue avant les autres colonnes
# (extraction_invalide, controler_version_extraction()), puis le contrôle strict de cette
# seule table par controler_types(), une fois tous les fichiers lus (une ligne exactement,
# colonnes et types).
# Hors de la table extraction, ce qui n'a pas la forme du dictionnaire est rendu sans
# refus ni conversion : colonne inconnue (rendue en texte), colonne absente, colonne dont
# une valeur au moins est illisible dans son type (rendue entière en texte exact),
# chaîne vide entre guillemets ("", rendue telle quelle ; dans une colonne d'un autre type
# que character, la colonne reste en texte). Le résultat d'un appel isolé n'est donc pas
# forcément conforme : controler_types() (porte stricte) le refuse, et le contrôle de la
# base entière (module `donnees`) l'enregistre au bilan.
# Tolérances admises (jugement de mise en œuvre : les guillemets délimitent le champ, ils
# ne portent pas le type ; aucune tolérance ne change la valeur lue d'une colonne de type
# character, et les 47 colonnes d'identifiant `id_*` du dictionnaire sont toutes de ce
# type) :
#   - toute valeur, entre guillemets ou non, quel que soit son type (entier, réel, date,
#     logique : "12" se lit 12L) ;
#   - zéros de tête pour integer et numeric (007, 007.50) ;
#   - chaîne sans guillemets, ses espaces conservées ; NA nu se lit comme la valeur "NA"
#     (le champ vide est le seul manquant) ;
#   - fins de ligne CRLF (hors des champs entre guillemets).
# Rend une liste nommée de data.frame, dans l'ordre des tables du dictionnaire, colonnes
# dans l'ordre du fichier, noms de colonnes égaux au texte de l'en-tête, noms de lignes
# automatiques.
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
  if ("extraction" %in% names(base)) controler_types(base["extraction"])
  base
}

.refus_lecture <- function(message, motif = "fichier_invalide", ...) {
  refuser(message, motif, module = "lecture", ...)
}

.controler_dossier <- function(dossier, fonction) {
  if (!is.character(dossier) || length(dossier) != 1L || is.na(dossier) || !nzchar(dossier)) {
    .refus_lecture(paste0(fonction, "() : `dossier` doit \u00eatre un chemin (cha\u00eene unique)"))
  }
  invisible(NULL)
}

# Lit un fichier <table>.csv : contrôle des octets, de l'en-tête et des guillemets, lecture
# en texte et contrôle de sa structure, puis seulement les refus localisés (retour chariot
# dans un champ entre guillemets), le rétablissement des chaînes vides, la version de la
# table extraction et la lecture typée des colonnes connues.
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
  # un champ de moins que les données, et retire les espaces autour des noms (mesure du
  # 8 novembre 2026, R 4.3.3) ; les noms rendus sont ceux-ci, texte exact de l'en-tête.
  .guillemet_non_ferme(octets, texte, mal_forme)
  premiere <- sub("\r$", "", substr(texte, 1L, regexpr("\n", texte, fixed = TRUE) - 1L))
  if (!nzchar(premiere)) mal_forme("premi\u00e8re ligne vide ; l'en-t\u00eate est attendu en premi\u00e8re ligne")
  entete <- tryCatch(
    scan(text = premiere, what = "", sep = ",", quote = "\"", na.strings = character(0),
         quiet = TRUE, strip.white = FALSE, comment.char = "", allowEscapes = FALSE,
         encoding = "UTF-8"),
    error = function(e) mal_forme(paste0("en-t\u00eate illisible : ", conditionMessage(e))),
    warning = function(w) mal_forme(paste0("en-t\u00eate illisible : ", conditionMessage(w))))
  champs <- .champs_entre_guillemets(octets, texte, mal_forme)
  brut <- tryCatch(
    utils::read.csv(chemin, header = TRUE, sep = ",", quote = "\"", dec = ".",
                    colClasses = "character", na.strings = "", encoding = "UTF-8",
                    check.names = FALSE, strip.white = FALSE, fill = FALSE,
                    blank.lines.skip = FALSE, comment.char = "", row.names = NULL,
                    stringsAsFactors = FALSE),
    error = function(e) mal_forme(conditionMessage(e)),
    warning = function(w) mal_forme(conditionMessage(w)))
  if (length(brut) != length(entete)) {
    mal_forme("l'en-t\u00eate a un champ de moins que les lignes de donn\u00e9es")
  }
  # Assertion (réserve m-c de l'audit de la première partie) : aucun cas connu où read.csv()
  # lit un autre nombre de lignes que de fins de ligne hors guillemets une fois la structure
  # du fichier contrôlée ; la localisation des champs qui suit en dépend. Un écart serait
  # une erreur de programmation, non un fichier mal formé.
  if (!is.na(champs$lignes) && nrow(brut) != champs$lignes) {
    stop(paste0("lire_base() : assertion : ", nrow(brut), " ligne(s) lues pour ", champs$lignes,
                " fin(s) de ligne hors guillemets (aucun cas connu)"), call. = FALSE)
  }
  vides <- which(!nzchar(entete))
  if (length(vides) > 0L) mal_forme(paste0("en-t\u00eate : nom de colonne vide (champ ", vides[1L], ")"))
  doubles <- unique(entete[duplicated(entete)])
  if (length(doubles) > 0L) {
    mal_forme(paste0("en-t\u00eate : nom(s) de colonne en double : ", paste(doubles, collapse = ", ")))
  }
  names(brut) <- entete
  if (length(champs$retours) > 0L) {
    ou <- champs$situer(champs$retours)
    if (ou$ligne[1L] == 0L) {
      mal_forme("en-t\u00eate : retour chariot (octet 0x0d) dans un champ entre guillemets")
    }
    cles <- !duplicated(paste(ou$ligne, ou$champ))
    lignes <- ou$ligne[cles]
    colonne <- entete[ou$champ[1L]]
    .refus_lecture(paste0("table ", table, ", colonne ", colonne, ", ligne de donn\u00e9es ", lignes[1L],
                          " : retour chariot (octet 0x0d) dans un champ entre guillemets, que",
                          " read.csv() lirait comme un saut de ligne : la lecture ne rendrait pas le",
                          " texte exact du fichier ; ", length(lignes), " champ(s) dans le fichier"),
                   table = table, colonne = colonne, nombre = length(lignes),
                   identifiants = as.character(lignes), recu = "\\r")
  }
  if (length(champs$vides) > 0L) {
    ou <- champs$situer(champs$vides)   # "" dans l'en-tête : nom de colonne vide, refusé plus haut
    # Une affectation par colonne, non par champ : `[[<-.data.frame` recopie la colonne à
    # chaque appel (temps quadratique au nombre de champs "", revue finale, M3).
    lignes_vides <- split(ou$ligne, ou$champ)
    for (j in names(lignes_vides)) {
      texte <- brut[[as.integer(j)]]
      texte[lignes_vides[[j]]] <- ""
      brut[[as.integer(j)]] <- texte
    }
  }
  if (table == "extraction") controler_version_extraction(brut)
  for (j in seq_along(brut)) {
    i <- match(names(brut)[j], colonnes$colonne)
    if (is.na(i)) next
    lu <- lire_texte_type(brut[[j]], colonnes$type[i])
    if (!is.null(lu$valeurs)) brut[[j]] <- lu$valeurs
  }
  brut
}

# Champs entre guillemets d'un fichier, contrôlés sur les octets avant read.csv(), qui les
# lirait autrement sans le dire (mesures du 8 novembre 2026, R 4.3.3) :
#   - "ab"cd est lu abcd : un champ entre guillemets doit commencer un champ et le finir
#     (précédé d'une virgule ou d'une fin de ligne, suivi d'une virgule ou d'une fin de
#     ligne) ; dans un CSV bien formé, la recherche de gauche à droite ne trouve que ces
#     champs-là (fichier mal formé) ;
#   - hors guillemets, un octet 0x0d qui n'est pas suivi de 0x0a (fin de ligne CRLF) est un
#     fichier mal formé.
# Rend, pour la suite de .lire_table_csv(), une fois la structure du fichier contrôlée par
# read.csv() : `lignes`, nombre de fins de ligne hors guillemets après l'en-tête (lignes de
# données), qui doit égaler le nombre de lignes lues avant toute localisation d'un champ
# (NA, et `situer` NULL, quand le fichier n'a ni octet 0x0d ni chaîne vide entre
# guillemets : rien n'est alors à localiser, et le repérage des octets entre guillemets,
# proportionnel à la taille du fichier, est évité) ; `vides`, positions des chaînes vides entre guillemets ("", que
# na.strings = "" lit NA quel que soit le type ; """" et "a""b" n'en sont pas) ;
# `retours`, positions des octets 0x0d dans un champ entre guillemets (read.csv() les lit
# comme une fin de ligne : "A\r\nB" et "A\nB" seraient tous deux relus "A\nB", faux
# doublon d'identifiants, dans un fichier LF comme CRLF) ; `situer`, fonction qui rend la
# ligne (0 : en-tête ; 1 : première ligne de données) et le rang du champ de positions.
.champs_entre_guillemets <- function(octets, texte, mal_forme) {
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
  if (length(retours) == 0L && length(vides) == 0L) {
    return(list(lignes = NA_integer_, vides = integer(0), retours = integer(0), situer = NULL))
  }
  # octets à l'intérieur d'un champ entre guillemets (guillemets compris)
  bornes <- integer(n + 1L)
  bornes[debut] <- 1L
  bornes[fin + 1L] <- bornes[fin + 1L] - 1L
  dedans <- cumsum(bornes)[seq_len(n)] > 0L
  hors <- retours[!dedans[retours]]
  if (any(hors == n | octets[pmin(hors + 1L, n)] != as.raw(0x0a))) {
    mal_forme("retour chariot isol\u00e9 hors guillemets")
  }
  fins_ligne <- which(octets == as.raw(0x0a) & !dedans)
  virgules <- which(octets == as.raw(0x2c) & !dedans)
  situer <- function(p) {
    ligne <- findInterval(p, fins_ligne)
    depart <- ifelse(ligne == 0L, 1L, fins_ligne[pmax(ligne, 1L)] + 1L)
    list(ligne = ligne, champ = findInterval(p, virgules) - findInterval(depart - 1L, virgules) + 1L)
  }
  list(lignes = length(fins_ligne) - 1L, vides = vides, retours = retours[dedans[retours]],
       situer = situer)
}

# Guillemet non fermé : un guillemet qui n'appartient à aucun champ entre guillemets bien
# formé ("...", guillemet intérieur doublé) est refusé avant toute lecture par read.csv(),
# dont le message citerait le chemin d'un fichier temporaire (« incomplete final line found
# by readTableHeader on '<chemin>' », relevé de l'audit) ; le refus nomme la ligne du
# premier guillemet sans fermeture (en-tête, ou rang de la ligne de données, les fins de
# ligne à l'intérieur d'un champ entre guillemets n'étant pas comptées).
.guillemet_non_ferme <- function(octets, texte, mal_forme) {
  positions <- which(octets == as.raw(0x22))
  if (length(positions) == 0L) return(invisible(NULL))
  guillemets <- gregexpr("\"(?:[^\"]++|\"\")*+\"", texte, perl = TRUE, useBytes = TRUE)[[1L]]
  debut <- if (guillemets[1L] == -1L) integer(0) else as.integer(guillemets)
  fin <- debut + attr(guillemets, "match.length")[seq_along(debut)] - 1L
  rang <- findInterval(positions, debut)
  isoles <- positions[rang == 0L | positions > fin[pmax(rang, 1L)]]
  if (length(isoles) == 0L) return(invisible(NULL))
  fins_ligne <- which(octets == as.raw(0x0a))
  r <- findInterval(fins_ligne, debut)
  fins_ligne <- fins_ligne[r == 0L | fins_ligne > fin[pmax(r, 1L)]]
  ligne <- findInterval(isoles[1L], fins_ligne)
  mal_forme(paste0("guillemet non ferm\u00e9, ",
                   if (ligne == 0L) "en-t\u00eate" else paste0("ligne de donn\u00e9es ", ligne)))
}

# --- Écriture --------------------------------------------------------------------

# Écrit une base (liste nommée de data.frame, contrôlée par controler_types()) en CSV
# dans `dossier`, un fichier <table>.csv par table, dans le format que lit lire_base() :
# en-tête des noms de colonnes, chaînes entre guillemets doubles (guillemet intérieur
# doublé), manquant écrit en champ vide, entiers en décimal, réels à 15 chiffres
# significatifs, ou 16, ou 17 (le premier qui se relit à l'identique), dates AAAA-MM-JJ,
# logiques TRUE / FALSE, fins de ligne \n. `dossier` est créé s'il n'existe pas (son
# parent doit exister) ; s'il existe, il doit être vide (un fichier ancien serait relu
# avec la base ; sinon, refus fichier_invalide, comme un chemin qui n'est pas une chaîne
# unique ou un dossier impossible à créer). Refuse (liste_invalide), avant toute écriture :
# la chaîne vide "" (hors domaine, code chaine_vide, dictionnaire, § 1.6 : une base écrite
# est conforme ; asymétrie avec la lecture, qui la rend telle quelle, M142), et ce que le
# CSV ne relirait pas à l'identique : chaîne qui contient un retour chariot, réel non fini
# (Inf, -Inf, NaN), chaîne non UTF-8 ou d'encodage inconnu hors locale UTF-8, date hors de
# quatre chiffres d'année. Les noms
# de lignes ne sont pas écrits. Rend `dossier`, invisible : lire_base(ecrire_base(x, d))
# rend `x` à l'identique quand `x` liste ses tables dans l'ordre du dictionnaire et porte
# des noms de lignes automatiques.
ecrire_base <- function(donnees, dossier) {
  .controler_dossier(dossier, "ecrire_base")
  contenus <- .contenus_base(donnees)
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
  for (f in names(contenus)) writeBin(contenus[[f]], file.path(dossier, f))
  invisible(dossier)
}

# Octets des fichiers <table>.csv d'une base, tables dans l'ordre du dictionnaire, après
# controler_types() et les refus de .champs_colonne() : tous les refus d'ecrire_base() avant
# la moindre écriture (employée aussi par ecrire_jeu(), revue finale, m4).
.contenus_base <- function(donnees) {
  controler_types(donnees)
  dico <- dictionnaire()
  tables <- dico$tables$table[dico$tables$table %in% names(donnees)]
  contenus <- lapply(tables, function(table) .texte_table_csv(donnees[[table]], table))
  names(contenus) <- sprintf("%s.csv", tables)   # paste0() rendrait ".csv" sans table
  contenus
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
    .refus_lecture(paste0("ecrire_base() : ", ou, " : ", raison), motif = "liste_invalide",
                   table = table, colonne = colonne, nombre = n)
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
      refus(paste0("cha\u00eene vide \"\" : hors domaine (code chaine_vide, dictionnaire, \u00a7 1.6 :",
                   " le champ vide est le seul marqueur de manquant) ; une base \u00e9crite est conforme"),
            sum(vides))
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

# --- Jeux simulés ------------------------------------------------------------------

# Fichiers d'un jeu versionné hors de base/ et de verite/ (ADR 0010, point 20) ;
# declarations.txt est facultatif (déclarations et conventions de controler_base() qui
# conviennent au jeu, versionnées avec lui).
.FICHIERS_JEU <- c("loi_vraie.txt", "manifeste.txt", "empreintes.md5")
.FICHIER_DECLARATIONS <- "declarations.txt"
.CHAMPS_JEU <- c("base", "loi_vraie", "verite", "manifeste")

# Écrit un jeu simulé (objet `jeu_simule` de simuler_base()) dans `dossier` (créé s'il
# n'existe pas, son parent devant exister ; vide s'il existe), selon la disposition du point
# 20 de l'ADR 0010 : base/<table>.csv (ecrire_base()), loi_vraie.txt et manifeste.txt
# (ecrire_liste()), verite/<nom>.csv (même format CSV que la base ; types des colonnes portés
# par manifeste$colonnes_verite), declarations.txt (ecrire_liste(), si le jeu porte des
# déclarations), puis empreintes.md5 : une ligne « <md5>  <chemin relatif> » par fichier, triés
# (tri radix), au format de `md5sum -c` lancé depuis `dossier`. Refuse, avant toute écriture
# (création du dossier comprise) : un objet qui n'a pas la forme d'un jeu simulé, ou que
# lire_jeu() ne relirait pas identique -- classe autre que jeu_simule seule, attribut du jeu,
# de base ou de verite hors names (et class pour le jeu), tables de la base hors de l'ordre du
# dictionnaire, manifeste$volumetrie différente des nombres de lignes de la base, champ
# declarations NULL, table (base ou verite) à noms de lignes non automatiques ou à attribut de
# table ou de colonne que le CSV ne conserve pas (jeu_invalide ; le message nomme l'élément, et
# la colonne) ; les refus d'ecrire_base() et d'ecrire_liste() (qui refuse tout attribut de
# loi_vraie, manifeste et declarations), pour une table de vérité au nom d'ecrire_jeu() et de
# verite/<nom>. Rend `dossier`, invisible.
ecrire_jeu <- function(jeu, dossier) {
  .controler_dossier(dossier, "ecrire_jeu")
  .controler_jeu(jeu)
  octets <- list(loi_vraie.txt = ecrire_liste(jeu$loi_vraie), manifeste.txt = ecrire_liste(jeu$manifeste))
  if (!is.null(jeu$declarations)) octets[[.FICHIER_DECLARATIONS]] <- ecrire_liste(jeu$declarations)
  # refus d'écriture d'une table de vérité (chaîne vide, retour chariot, réel non fini...) relevé
  # au nom d'ecrire_jeu() et de verite/<nom> (réserve m2 de l'audit)
  verite <- lapply(names(jeu$verite), function(nom) {
    tryCatch(.texte_table_csv(jeu$verite[[nom]], nom), refus_provie = function(e) {
      .refus_lecture(paste0("ecrire_jeu() : verite/", nom, " : ", sub("^ecrire_base\\(\\) : ", "", conditionMessage(e))),
                     motif = e$motif, table = nom, colonne = e$colonne, nombre = e$nombre)
    })
  })
  base <- .contenus_base(jeu$base)
  .controler_relecture_jeu(jeu)
  if (file.exists(dossier)) {
    if (!dir.exists(dossier)) .refus_lecture(paste0("ecrire_jeu() : ", dossier, " existe et n'est pas un dossier"))
    if (length(list.files(dossier, all.files = TRUE, no.. = TRUE)) > 0L) {
      .refus_lecture(paste0("ecrire_jeu() : le dossier ", dossier, " n'est pas vide"))
    }
  } else if (!dir.create(dossier, showWarnings = FALSE)) {
    .refus_lecture(paste0("ecrire_jeu() : dossier ", dossier, " impossible \u00e0 cr\u00e9er"))
  }
  dir.create(file.path(dossier, "base"))
  for (f in names(base)) writeBin(base[[f]], file.path(dossier, "base", f))
  dir.create(file.path(dossier, "verite"))
  for (k in seq_along(verite)) writeBin(verite[[k]], file.path(dossier, "verite", paste0(names(jeu$verite)[k], ".csv")))
  for (f in names(octets)) writeBin(octets[[f]], file.path(dossier, f))
  fichiers <- sort(c(names(octets), file.path("base", list.files(file.path(dossier, "base"))),
                     file.path("verite", list.files(file.path(dossier, "verite")))), method = "radix")
  md5 <- vapply(fichiers, function(f) empreinte(.octets_fichier(file.path(dossier, f))), "", USE.NAMES = FALSE)
  writeBin(charToRaw(paste0(paste0(md5, "  ", fichiers, "\n"), collapse = "")), file.path(dossier, "empreintes.md5"))
  invisible(dossier)
}

# Relit un jeu écrit par ecrire_jeu() ; rend l'objet `jeu_simule` : lire_jeu(ecrire_jeu(j, d))
# est identical à j. Contrôle d'abord la disposition (fichiers et dossiers attendus, rien
# d'autre : fichier_invalide) et les empreintes de empreintes.md5 (une ligne par fichier,
# chacun présent une fois ; empreinte_discordante au premier fichier dont le MD5 diffère),
# puis lit base/ par lire_base() (tables et nombres de lignes égaux à manifeste$volumetrie,
# sinon fichier_invalide), les listes par lire_liste() et verite/ selon les types de
# manifeste$colonnes_verite (fichier_invalide si une colonne manque, est en trop ou ne se lit
# pas dans son type).
lire_jeu <- function(dossier) {
  .controler_dossier(dossier, "lire_jeu")
  if (!dir.exists(dossier)) .refus_lecture(paste0("lire_jeu() : dossier introuvable : ", dossier))
  entrees <- sort(list.files(dossier, all.files = TRUE, no.. = TRUE), method = "radix")
  attendus <- c("base", "verite", .FICHIERS_JEU)
  if (!all(attendus %in% entrees) || !all(entrees %in% c(attendus, .FICHIER_DECLARATIONS)) ||
      !dir.exists(file.path(dossier, "base")) || !dir.exists(file.path(dossier, "verite"))) {
    .refus_lecture(paste0("lire_jeu() : disposition d'un jeu attendue dans ", dossier,
                          " (base/, verite/, loi_vraie.txt, manifeste.txt, empreintes.md5, declarations.txt facultatif)"))
  }
  fichiers <- sort(c(intersect(entrees, c("loi_vraie.txt", "manifeste.txt", .FICHIER_DECLARATIONS)),
                     file.path("base", list.files(file.path(dossier, "base"), all.files = TRUE, no.. = TRUE)),
                     file.path("verite", list.files(file.path(dossier, "verite"), all.files = TRUE, no.. = TRUE))),
                   method = "radix")
  lignes <- strsplit(rawToChar(.octets_fichier(file.path(dossier, "empreintes.md5"))), "\n", fixed = TRUE)[[1L]]
  forme <- grepl("^[0-9a-f]{32}  [^ ].*$", lignes)
  noms <- substring(lignes, 35L)
  if (!all(forme) || anyDuplicated(noms) || !setequal(noms, fichiers)) {
    .refus_lecture(paste0("lire_jeu() : empreintes.md5 mal form\u00e9 ou qui ne liste pas exactement les fichiers du jeu"))
  }
  for (k in seq_along(lignes)) {
    attendu <- substr(lignes[k], 1L, 32L)
    recu <- empreinte(.octets_fichier(file.path(dossier, noms[k])))
    if (!identical(recu, attendu)) {
      refuser(paste0("lire_jeu() : empreinte discordante du fichier ", noms[k]), "empreinte_discordante",
              module = "lecture", attendu = attendu, recu = recu)
    }
  }
  base <- lire_base(file.path(dossier, "base"))
  loi_vraie <- lire_liste(.octets_fichier(file.path(dossier, "loi_vraie.txt")))
  manifeste <- lire_liste(.octets_fichier(file.path(dossier, "manifeste.txt")))
  # tables de base/ et leurs nombres de lignes : ceux de manifeste$volumetrie (réserve m1 de
  # l'audit : un jeu privé d'une table, aux empreintes recalculées, est refusé)
  # forme contrôlée avant toute comparaison, sans coercition (réserve m3 : aucun avertissement,
  # refus propre sous options(warn = 2))
  vol <- manifeste$volumetrie
  if (!is.list(vol) || !all(vapply(vol, function(x) is.integer(x) && length(x) == 1L && !is.na(x), NA)) ||
      !identical(names(vol), names(base)) || !identical(unname(vol), unname(lapply(base, nrow)))) {
    .refus_lecture(paste0("lire_jeu() : les tables de base/ ou leurs nombres de lignes diff\u00e8rent de ",
                          "manifeste$volumetrie"))
  }
  types <- manifeste$colonnes_verite
  # fichiers cachés compris, comme dans base/ (revue finale, m3)
  dans_verite <- list.files(file.path(dossier, "verite"), all.files = TRUE, no.. = TRUE)
  presents <- sub("\\.csv$", "", dans_verite)
  if (!is.list(types) || is.null(names(types)) || !setequal(names(types), presents) ||
      !all(grepl("^[a-z0-9_]+\\.csv$", dans_verite))) {
    .refus_lecture("lire_jeu() : manifeste$colonnes_verite ne d\u00e9crit pas exactement les fichiers de verite/")
  }
  verite <- lapply(names(types), function(nom) {
    colonnes <- data.frame(colonne = names(types[[nom]]), type = unlist(types[[nom]], use.names = FALSE),
                           stringsAsFactors = FALSE)
    df <- .lire_table_csv(file.path(dossier, "verite", paste0(nom, ".csv")), nom, colonnes)
    ok <- identical(names(df), colonnes$colonne) &&
      all(vapply(seq_along(df), function(j) .type_conforme(df[[j]], colonnes$type[j]), NA))
    if (!ok) {
      .refus_lecture(paste0("lire_jeu() : verite/", nom, ".csv : colonnes ou types diff\u00e9rents de manifeste$colonnes_verite"))
    }
    df
  })
  names(verite) <- names(types)
  jeu <- list(base = base, loi_vraie = loi_vraie, verite = verite, manifeste = manifeste)
  if (.FICHIER_DECLARATIONS %in% entrees) {
    jeu$declarations <- lire_liste(.octets_fichier(file.path(dossier, .FICHIER_DECLARATIONS)))
  }
  structure(jeu, class = "jeu_simule")
}

.octets_fichier <- function(chemin) readBin(chemin, "raw", n = file.info(chemin)$size)

# Forme d'un jeu simulé (ADR 0010, point 19) : classe jeu_simule, champs base, loi_vraie,
# verite, manifeste dans cet ordre, puis declarations facultatif ; verite : liste nommée de
# data.frame ; manifeste$colonnes_verite qui décrit exactement les colonnes de verite.
.controler_jeu <- function(jeu) {
  refus <- function(raison) .refus_lecture(paste0("ecrire_jeu() : ", raison), motif = "jeu_invalide")
  if (!identical(class(jeu), "jeu_simule") || !is.list(jeu)) refus("objet de classe jeu_simule seule attendu")
  # lire_jeu() rend un jeu qui ne porte que names et class, des listes base et verite qui ne
  # portent que names (audit, m1)
  if (!setequal(names(attributes(jeu)), c("names", "class"))) refus("attribut du jeu autre que names et class")
  for (champ in c("base", "verite")) {
    if (length(setdiff(names(attributes(jeu[[champ]])), "names")) > 0L) {
      refus(paste0("attribut de la liste ", champ, " autre que names (lire_jeu() ne le relit pas)"))
    }
  }
  noms <- names(jeu)
  if (!(identical(noms, .CHAMPS_JEU) || identical(noms, c(.CHAMPS_JEU, "declarations")))) {
    refus("champs base, loi_vraie, verite, manifeste (et declarations) attendus, dans cet ordre")
  }
  # un champ declarations NULL ne s'écrit pas : la relecture rendrait un jeu sans ce champ
  if ("declarations" %in% noms && is.null(jeu$declarations)) refus("champ declarations NULL (l'omettre)")
  v <- jeu$verite
  if (!is.list(v) || is.data.frame(v) || is.null(names(v)) || anyNA(names(v)) || anyDuplicated(names(v)) ||
      !all(grepl("^[a-z0-9_]+$", names(v))) || !all(vapply(v, is.data.frame, NA))) {
    refus("verite doit \u00eatre une liste nomm\u00e9e de data.frame (noms en minuscules ASCII)")
  }
  types <- jeu$manifeste$colonnes_verite
  decrit <- is.list(types) && identical(names(types), names(v)) &&
    all(vapply(names(v), function(nom) {
      t <- types[[nom]]
      is.list(t) && identical(names(t), names(v[[nom]])) &&
        all(vapply(seq_along(t), function(j) .chaine_type(t[[j]]) && .type_conforme(v[[nom]][[j]], t[[j]]), NA))
    }, NA))
  if (!decrit) refus("manifeste$colonnes_verite doit d\u00e9crire exactement les colonnes et les types de verite")
  invisible(NULL)
}

# Conditions de relecture identique (revue finale, m5) : lire_base() rend les tables dans
# l'ordre du dictionnaire, lire_jeu() compare manifeste$volumetrie aux nombres de lignes relus,
# et une table relue ne porte ni noms de lignes ni attribut que le CSV ne conserve pas (n2).
# Appelée après .contenus_base() (base de types contrôlés).
.controler_relecture_jeu <- function(jeu) {
  refus <- function(raison) .refus_lecture(paste0("ecrire_jeu() : ", raison), motif = "jeu_invalide")
  dico <- dictionnaire()
  noms <- names(jeu$base)
  if (!identical(noms, dico$tables$table[dico$tables$table %in% noms])) {
    refus("tables de la base hors de l'ordre du dictionnaire (lire_jeu() les relirait dans cet ordre)")
  }
  if (!identical(jeu$manifeste$volumetrie, lapply(jeu$base, nrow))) {
    refus("manifeste$volumetrie diff\u00e8re des nombres de lignes de la base (liste nomm\u00e9e d'entiers, ordre des tables)")
  }
  for (nom in names(jeu$base)) .controler_forme_table(jeu$base[[nom]], paste0("base/", nom), refus)
  for (nom in names(jeu$verite)) .controler_forme_table(jeu$verite[[nom]], paste0("verite/", nom), refus)
  invisible(NULL)
}

# Une table relue d'un CSV a des noms de lignes automatiques (1..n), les seuls attributs d'un
# data.frame (names, class, row.names) et des colonnes sans attribut, hors la classe Date des
# dates ; toute autre table est refusée, au nom de la table (et de la colonne).
.controler_forme_table <- function(t, nom, refus) {
  if (!identical(class(t), "data.frame") || !setequal(names(attributes(t)), c("names", "class", "row.names"))) {
    refus(paste0("table ", nom, " : attribut de table autre que names, class et row.names (non relu par lire_jeu())"))
  }
  if (!identical(attr(t, "row.names"), seq_len(nrow(t)))) {
    refus(paste0("table ", nom, " : noms de lignes non automatiques (lire_jeu() relit les noms 1..n)"))
  }
  for (colonne in names(t)) {
    attrs <- attributes(t[[colonne]])
    if (!(is.null(attrs) || (inherits(t[[colonne]], "Date") && identical(attrs, list(class = "Date"))))) {
      refus(paste0("table ", nom, ", colonne ", colonne, " : attribut de colonne que le CSV ne conserve pas (lire_jeu() ne le relit pas)"))
    }
  }
}

.chaine_type <- function(x) is.character(x) && length(x) == 1L && !is.na(x) && x %in% TYPES_DICTIONNAIRE
