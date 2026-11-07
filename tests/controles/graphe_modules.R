# Controle : graphe des modules du package provie (ADR 0010, point 1 ; point 26 ; issue
# #12). Sur chaque fichier de R/ (parse avec srcref, getParseData : numeros de ligne) :
#   1. les fichiers de R/ sont exactement parmi les quinze modules de l'ADR 0010, point 1
#      (un fichier hors liste est refuse ; un module absent n'est pas une erreur : un
#      fichier n'existe qu'a partir de la branche qui lui donne un contenu) ;
#   2. chaque module n'appelle (fonction ou constante de premier niveau d'un autre
#      fichier) que les modules de la colonne "Peut appeler" du tableau, ecrit en dur
#      ci-dessous ; une autre arete est un [ECHEC] ;
#   3. aucun appel dynamique : do.call() sauf sur un nom de fonction de base nu ou une
#      fonction litterale (ex. do.call(rbind, liste)), match.fun, get, get0, mget, eval,
#      evalq, eval.parent, parse, str2lang, str2expression, source, sys.source,
#      getFromNamespace, getExportedValue, asNamespace, getNamespace, environment (acces
#      a un espace de noms ou a un environnement par son nom), provie:: et provie::: ;
#   4. un nom de premier niveau n'est defini que dans un seul fichier ;
#   5. temoins negatifs integres : simulation appele par un module du moteur, triangle
#      vers engagement, lecture appele par un module du moteur, rapport vers
#      calculer_provisions doivent etre refuses par la table ; et la table en dur est coherente (quinze modules, sans cycle).
# Les noms utilises comme champ (`x$nom`) ne sont pas des appels ; une variable locale
# (affectation, argument de fonction, variable de for) qui porte le nom d'une definition
# d'un autre module n'est pas comptee, mais un appel de fonction l'est toujours.
# Usage, depuis la racine du depot : Rscript tests/controles/graphe_modules.R
# Un argument facultatif designe une autre racine (copie du depot, pour les temoins).
# Sortie : lignes [OK] / [ECHEC] fichier:ligne ; statut 1 au moindre [ECHEC].
# Code ASCII, R de base seulement.

options(warn = 2)
.fichier_script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
.arguments <- commandArgs(trailingOnly = TRUE)
racine <- normalizePath(if (length(.arguments) >= 1L) .arguments[1L]
                        else file.path(dirname(.fichier_script), "..", ".."), mustWork = TRUE)
.n_echec <- 0L
rel <- function(chemin) if (startsWith(chemin, paste0(racine, "/"))) substring(chemin, nchar(racine) + 2L) else chemin
ok <- function(message) cat("[OK] ", message, "\n", sep = "")
echec <- function(message, chemin = NA_character_, ligne = NA_integer_) {
  .n_echec <<- .n_echec + 1L
  position <- if (is.na(chemin)) "" else paste0(rel(chemin), if (is.na(ligne)) "" else paste0(":", ligne), " ")
  cat("[ECHEC] ", position, message, "\n", sep = "")
}
fin <- function() quit(save = "no", status = if (.n_echec > 0L) 1L else 0L)

# --- Le graphe de l'ADR 0010, point 1 (colonne "Peut appeler"), en dur -----------------
TOUS_LES_MODULES_AMONT <- c("outils", "dictionnaire", "donnees", "tables", "garanties",
                            "engagement", "triangle", "risque_en_cours", "regles_comptables",
                            "projection", "plan")
AUTORISE <- list(
  outils             = character(0),
  dictionnaire       = c("outils"),
  lecture            = c("dictionnaire", "outils"),
  donnees            = c("dictionnaire", "outils"),
  tables             = c("outils"),
  garanties          = c("dictionnaire", "outils"),
  engagement         = c("tables", "garanties", "donnees", "outils"),
  triangle           = c("garanties", "donnees", "outils"),
  risque_en_cours    = c("engagement", "tables", "garanties", "donnees", "outils"),
  regles_comptables  = c("garanties", "tables", "donnees", "outils"),
  projection         = c("engagement", "tables", "garanties", "donnees", "outils"),
  plan               = c("tables", "garanties", "dictionnaire", "donnees", "outils"),
  rapport            = TOUS_LES_MODULES_AMONT,
  simulation         = c("dictionnaire", "garanties", "tables", "outils"),
  calculer_provisions = c(TOUS_LES_MODULES_AMONT, "rapport")
)
MODULES <- names(AUTORISE)

arete_permise <- function(de, vers) de == vers || vers %in% AUTORISE[[de]]

# Dependances dynamiques interdites (appel de fonction par son nom, evaluation de texte).
APPELS_DYNAMIQUES <- c("match.fun", "get", "get0", "mget", "eval", "evalq", "eval.parent",
                       "parse", "str2lang", "str2expression", "source", "sys.source",
                       "getFromNamespace", "getExportedValue", "asNamespace", "getNamespace",
                       "environment")

# --- Analyse d'un fichier --------------------------------------------------------------
# Rend list(defs, jetons) : defs = noms definis au premier niveau ; jetons = data.frame
# des symboles (appels, noms, packages) avec ligne, token, texte, def (definition de
# premier niveau qui les contient), prec / suiv (jeton voisin), local (variable locale),
# statique (do.call : premier argument acceptable).
analyser <- function(chemin) {
  exprs <- parse(file = chemin, keep.source = TRUE, encoding = "UTF-8")
  vide <- list(defs = character(0), jetons = data.frame(
    ligne = integer(0), token = character(0), texte = character(0), def = character(0),
    prec = character(0), suiv = character(0), local = logical(0), statique = logical(0),
    stringsAsFactors = FALSE))
  pd <- getParseData(exprs)
  if (is.null(pd)) return(vide)
  pd <- pd[pd$token != "COMMENT", ]
  pd <- pd[order(pd$line1, pd$col1, -pd$line2, -pd$col2), ]
  enfants <- split(seq_len(nrow(pd)), pd$parent)
  lignes_de <- function(id) enfants[[as.character(id)]]
  # Definition de premier niveau (ou variable locale) : expr = expr(SYMBOL) <- ...
  cible_affectation <- function(i) {
    k <- lignes_de(pd$id[i])
    if (length(k) >= 3L && pd$token[k[1L]] == "expr" && pd$token[k[2L]] %in% c("LEFT_ASSIGN", "EQ_ASSIGN")) {
      s <- lignes_de(pd$id[k[1L]])
      if (length(s) == 1L && pd$token[s] %in% c("SYMBOL", "STR_CONST")) return(gsub("[\"'`]", "", pd$text[s]))
    }
    NA_character_
  }
  # Definition de premier niveau de chaque noeud.
  haut <- pd$id
  repeat {
    p <- pd$parent[match(haut, pd$id)]
    monte <- p > 0L
    if (!any(monte)) break
    haut[monte] <- p[monte]
  }
  tops <- which(pd$parent == 0L)
  nom_def <- rep(NA_character_, nrow(pd))
  defs <- character(0)
  for (i in tops) {
    n <- cible_affectation(i)
    if (!is.na(n)) {
      defs <- c(defs, n)
      nom_def[haut == pd$id[i]] <- n
    }
  }
  # Variables locales : cibles d'affectation hors premier niveau, arguments formels, for.
  locaux <- character(0)       # "<def>\t<nom>"
  for (i in which(pd$token %in% c("expr", "expr_or_assign_or_help", "equal_assign") & pd$parent != 0L)) {
    n <- cible_affectation(i)
    if (!is.na(n)) locaux <- c(locaux, paste(nom_def[match(haut[i], pd$id)], n, sep = "\t"))
  }
  for (i in which(pd$token == "SYMBOL_FORMALS")) {
    locaux <- c(locaux, paste(nom_def[i], pd$text[i], sep = "\t"))
  }
  for (k in enfants) {
    for (j in seq_len(length(k) - 1L)) {
      if (pd$token[k[j]] == "SYMBOL" && pd$token[k[j + 1L]] == "IN") {
        locaux <- c(locaux, paste(nom_def[k[j]], pd$text[k[j]], sep = "\t"))
      }
    }
  }
  # Jetons terminaux, dans l'ordre du source.
  term <- which(pd$terminal)
  precedent <- c(NA_character_, pd$token[term][-length(term)])
  suivant <- c(pd$token[term][-1L], NA_character_)
  interessants <- pd$token[term] %in% c("SYMBOL_FUNCTION_CALL", "SYMBOL", "SYMBOL_PACKAGE")
  idx <- term[interessants]
  jetons <- data.frame(
    ligne = pd$line1[idx], token = pd$token[idx], texte = pd$text[idx], def = nom_def[idx],
    prec = precedent[interessants], suiv = suivant[interessants],
    local = paste(nom_def[idx], pd$text[idx], sep = "\t") %in% locaux & pd$token[idx] == "SYMBOL",
    statique = NA, stringsAsFactors = FALSE)
  # do.call : premier argument (what) = nom nu d'une fonction de base, ou fonction litterale.
  for (r in which(jetons$token == "SYMBOL_FUNCTION_CALL" & jetons$texte == "do.call")) {
    i <- idx[r]
    nom_fonction <- match(pd$parent[i], pd$id)               # expr du nom de fonction
    appel <- lignes_de(pd$parent[nom_fonction])              # enfants de l'expr d'appel
    args <- appel[-(1:2)]
    premier <- args[1L]
    if (!is.na(premier) && pd$token[premier] == "SYMBOL_SUB" && pd$text[premier] == "what") premier <- args[3L]
    statique <- FALSE
    if (!is.na(premier) && pd$token[premier] == "expr") {
      k <- lignes_de(pd$id[premier])
      if (length(k) == 1L && pd$token[k] == "SYMBOL") {
        statique <- exists(pd$text[k], envir = baseenv(), mode = "function", inherits = FALSE)
      } else if (length(k) >= 1L && pd$token[k[1L]] == "FUNCTION") {
        statique <- TRUE
      }
    }
    jetons$statique[r] <- statique
  }
  list(defs = unique(defs), jetons = jetons)
}

# --- 1. Fichiers de R/ -------------------------------------------------------------------
dossier_r <- file.path(racine, "R")
if (!dir.exists(dossier_r)) {
  echec("dossier R/ absent", dossier_r)
  fin()
}
fichiers <- sort(list.files(dossier_r, recursive = TRUE, all.files = TRUE), method = "radix")
avant <- .n_echec
for (f in fichiers) {
  if (!(f %in% paste0(MODULES, ".R"))) {
    echec(sprintf("fichier hors des quinze modules de l'ADR 0010, point 1 (attendu : <module>.R, module parmi %s)",
                  paste(MODULES, collapse = ", ")), file.path(dossier_r, f))
  }
}
if (.n_echec == avant) ok(sprintf("R/ : %d fichier(s), tous parmi les quinze modules", length(fichiers)))
fichiers <- fichiers[fichiers %in% paste0(MODULES, ".R")]

# --- Analyse -----------------------------------------------------------------------------
analyses <- list()
for (f in fichiers) {
  chemin <- file.path(dossier_r, f)
  r <- tryCatch(analyser(chemin), error = function(e) conditionMessage(e))
  if (is.character(r)) {
    echec(paste0("fichier non analysable : ", gsub("[^ -~]", "?", r)), chemin)
  } else {
    analyses[[sub("\\.R$", "", f)]] <- r
  }
}

# --- 4. Definitions uniques ------------------------------------------------------------------
module_de <- character(0)
avant <- .n_echec
for (m in names(analyses)) {
  for (nom in analyses[[m]]$defs) {
    if (nom %in% names(module_de) && module_de[[nom]] != m) {
      echec(sprintf("`%s` est defini dans deux modules (`%s` et `%s`)", nom, module_de[[nom]], m),
            file.path(dossier_r, paste0(m, ".R")))
    } else {
      module_de[[nom]] <- m
    }
  }
}
if (.n_echec == avant) ok(sprintf("%d nom(s) de premier niveau, chacun defini dans un seul module", length(module_de)))

# --- 2 et 3. Aretes et appels dynamiques ----------------------------------------------------
avant <- .n_echec
n_aretes <- 0L
for (m in names(analyses)) {
  chemin <- file.path(dossier_r, paste0(m, ".R"))
  j <- analyses[[m]]$jetons
  vus <- character(0)
  for (r in seq_len(nrow(j))) {
    texte <- j$texte[r]
    champ <- !is.na(j$prec[r]) && j$prec[r] %in% c("'$'", "'@'")
    if (j$token[r] == "SYMBOL_PACKAGE" && texte == "provie") {
      echec("provie:: et provie::: sont interdits dans R/ (ADR 0010, point 26)", chemin, j$ligne[r])
    }
    if (j$token[r] == "SYMBOL_FUNCTION_CALL" && !champ) {
      if (texte %in% APPELS_DYNAMIQUES) {
        echec(sprintf("appel dynamique interdit : %s()", texte), chemin, j$ligne[r])
      } else if (texte == "do.call" && !isTRUE(j$statique[r])) {
        echec("appel dynamique interdit : do.call() autrement que sur un nom de fonction de base nu ou une fonction litterale",
              chemin, j$ligne[r])
      }
    }
    if (j$token[r] %in% c("SYMBOL_FUNCTION_CALL", "SYMBOL") && !champ && !j$local[r] &&
        texte %in% names(module_de) && module_de[[texte]] != m) {
      vers <- module_de[[texte]]
      n_aretes <- n_aretes + 1L
      cle <- paste(j$ligne[r], texte)
      if (!arete_permise(m, vers) && !(cle %in% vus)) {
        vus <- c(vus, cle)
        echec(sprintf("module `%s` appelle `%s` (symbole `%s`) : arete hors du graphe de l'ADR 0010, point 1", m, vers, texte),
              chemin, j$ligne[r])
      }
    }
  }
}
if (.n_echec == avant) ok(sprintf("graphe respecte (%d reference(s) entre modules), aucun appel dynamique", n_aretes))

# --- 5. Table en dur et temoins negatifs integres ---------------------------------------------
avant <- .n_echec
if (length(MODULES) != 15L || anyDuplicated(MODULES) > 0L || !all(unlist(AUTORISE) %in% MODULES)) {
  echec("table AUTORISE incoherente : quinze modules distincts attendus, cibles incluses")
}
acyclique <- function() {
  etat <- setNames(rep(0L, length(MODULES)), MODULES)
  visiter <- function(m) {
    if (etat[[m]] == 1L) return(FALSE)
    if (etat[[m]] == 2L) return(TRUE)
    etat[[m]] <<- 1L
    res <- all(vapply(AUTORISE[[m]], visiter, logical(1)))
    etat[[m]] <<- 2L
    res
  }
  all(vapply(MODULES, visiter, logical(1)))
}
if (!acyclique()) echec("table AUTORISE : le graphe contient un cycle")
moteur <- setdiff(MODULES, c("lecture", "simulation"))
for (m in moteur) {
  if (arete_permise(m, "simulation")) echec(sprintf("temoin negatif : `%s` -> `simulation` serait admis", m))
  if (arete_permise(m, "lecture")) echec(sprintf("temoin negatif : `%s` -> `lecture` serait admis", m))
}
if (arete_permise("triangle", "engagement")) echec("temoin negatif : `triangle` -> `engagement` serait admis")
if (arete_permise("rapport", "calculer_provisions")) echec("temoin negatif : `rapport` -> `calculer_provisions` serait admis")
if (arete_permise("outils", "dictionnaire")) echec("temoin negatif : `outils` -> `dictionnaire` serait admis")
if (!arete_permise("simulation", "dictionnaire") || !arete_permise("calculer_provisions", "rapport")) {
  echec("table AUTORISE : arete attendue absente (simulation -> dictionnaire, calculer_provisions -> rapport)")
}
if (.n_echec == avant) ok("table en dur coherente (quinze modules, sans cycle) ; temoins negatifs refuses : moteur -> simulation, moteur -> lecture, triangle -> engagement, rapport -> calculer_provisions")

fin()
