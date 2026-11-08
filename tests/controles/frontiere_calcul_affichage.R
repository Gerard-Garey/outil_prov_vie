# Controle : frontiere calcul / affichage du package (ADR 0010, points 12, 21 et 26 ;
# M112 ; issue #12). Sur chaque fichier de R/ (parse avec srcref, getParseData : numeros de
# ligne ; commentaires et chaines exclus des recherches de noms) :
#   1. aucun element de Shiny : input$, reactive*, observe*, isolate, render*, shiny:: ;
#   2. aucun set.seed(), RNGkind(), RNGversion() (appeles ou simplement references :
#      `s <- set.seed`), aucun symbole .Random.seed ni chaine ".Random.seed" hors de
#      R/outils.R (la seule voie vers l'alea est outils::avec_graine, point 21) ;
#   3. le moteur ne parle pas (point 12, etendu par decision du mainteneur du 7 novembre
#      2026) : aucun warning(), message(), cat(), print(), writeLines(), writeChar(),
#      packageStartupMessage(), Sys.time(), Sys.Date(), date() (appeles ou references,
#      hors variables locales et champs), hors du corps des fonctions de premier niveau
#      nommees print.* et format.* ;
#   4. code ASCII (M112) : aucun octet non ASCII dans les jetons de code (chaines,
#      noms) ; les commentaires en sont exempts (regle de T1 : "Code ASCII hors
#      commentaires", en-tete de R/outils.R) ; mettre COMMENTAIRES_ASCII a TRUE pour les
#      inclure ;
#   5. si app/ existe (absent en B1 : toleree) : aucun provie::: et aucun appel de calcul
#      de la liste CALCULS_APP (heuristique : sum, mean... ; le calcul est dans le
#      package, `app/` formate et trace des quantites du resultat).
# Usage, depuis la racine du depot : Rscript tests/controles/frontiere_calcul_affichage.R
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

COMMENTAIRES_ASCII <- FALSE
APPELS_SHINY <- "^(reactive|reactiveVal|reactiveValues|reactiveValuesToList|observe|observeEvent|isolate|render([A-Z_.].*)?)$"
APPELS_ALEA <- c("set.seed", "RNGkind", "RNGversion")
APPELS_BAVARDS <- c("warning", "message", "cat", "print", "Sys.time", "Sys.Date", "date",
                    "writeLines", "writeChar", "packageStartupMessage")
CALCULS_APP <- c("sum", "mean", "median", "var", "sd", "cumsum", "cumprod", "prod",
                 "quantile", "weighted.mean", "aggregate", "tapply", "rowsum", "rowSums",
                 "colSums", "rowMeans", "colMeans", "lm", "glm", "optim", "optimize",
                 "uniroot", "integrate", "set.seed")

# Jetons d'un fichier : data.frame ligne, token, texte, def (fonction de premier niveau
# qui le contient, NA hors definition), prec / suiv (jeton terminal voisin), non_ascii, local
# (symbole qui est une variable locale ou un argument de sa definition).
jetons_du_fichier <- function(chemin) {
  exprs <- parse(file = chemin, keep.source = TRUE, encoding = "UTF-8")
  pd <- getParseData(exprs)
  if (is.null(pd)) return(NULL)
  pd <- pd[order(pd$line1, pd$col1, -pd$line2, -pd$col2), ]
  hors_commentaire <- pd[pd$token != "COMMENT", ]
  haut <- hors_commentaire$id
  repeat {
    p <- hors_commentaire$parent[match(haut, hors_commentaire$id)]
    monte <- p > 0L
    if (!any(monte)) break
    haut[monte] <- p[monte]
  }
  hc <- hors_commentaire
  enfants <- split(seq_len(nrow(hc)), hc$parent)
  # Nom assigne par l'expression i (`nom <- ...`), NA sinon.
  cible_de <- function(i) {
    fils <- enfants[[as.character(hc$id[i])]]
    if (length(fils) >= 3L && hc$token[fils[1L]] == "expr" &&
        hc$token[fils[2L]] %in% c("LEFT_ASSIGN", "EQ_ASSIGN")) {
      cible <- enfants[[as.character(hc$id[fils[1L]])]]
      if (length(cible) == 1L && hc$token[cible] %in% c("SYMBOL", "STR_CONST")) {
        return(gsub("[\"'`]", "", hc$text[cible]))
      }
    }
    NA_character_
  }
  nom_def <- rep(NA_character_, nrow(hc))
  for (i in which(hc$parent == 0L)) {
    n <- cible_de(i)
    if (!is.na(n)) nom_def[haut == hc$id[i]] <- n
  }
  # Variables locales d'une definition : cibles d'affectation hors premier niveau, arguments
  # formels, variables de for ("<definition>\t<nom>").
  locaux <- character(0)
  for (i in which(hc$token %in% c("expr", "expr_or_assign_or_help", "equal_assign") & hc$parent != 0L)) {
    n <- cible_de(i)
    if (!is.na(n)) locaux <- c(locaux, paste(nom_def[i], n, sep = "\t"))
  }
  for (i in which(hc$token == "SYMBOL_FORMALS")) locaux <- c(locaux, paste(nom_def[i], hc$text[i], sep = "\t"))
  for (k in enfants) {
    for (m in seq_len(length(k) - 1L)) {
      if (hc$token[k[m]] == "SYMBOL" && hc$token[k[m + 1L]] == "IN") {
        locaux <- c(locaux, paste(nom_def[k[m]], hc$text[k[m]], sep = "\t"))
      }
    }
  }
  terminaux <- which(hors_commentaire$terminal)
  non_ascii_texte <- function(t) any(as.integer(charToRaw(enc2utf8(t))) > 127L)
  res <- data.frame(
    ligne = hors_commentaire$line1[terminaux], token = hors_commentaire$token[terminaux],
    texte = hors_commentaire$text[terminaux], def = nom_def[terminaux],
    prec = c(NA_character_, hors_commentaire$token[terminaux][-length(terminaux)]),
    suiv = c(hors_commentaire$token[terminaux][-1L], NA_character_),
    non_ascii = vapply(hors_commentaire$text[terminaux], non_ascii_texte, logical(1), USE.NAMES = FALSE),
    local = hc$token[terminaux] == "SYMBOL" & paste(nom_def[terminaux], hc$text[terminaux], sep = "\t") %in% locaux,
    stringsAsFactors = FALSE)
  if (COMMENTAIRES_ASCII) {
    com <- pd[pd$token == "COMMENT", ]
    if (nrow(com) > 0L) {
      res <- rbind(res, data.frame(
        ligne = com$line1, token = "COMMENT", texte = com$text, def = NA_character_,
        prec = NA_character_, suiv = NA_character_,
        non_ascii = vapply(com$text, non_ascii_texte, logical(1), USE.NAMES = FALSE), local = FALSE,
        stringsAsFactors = FALSE))
    }
  }
  res
}

# --- R/ ------------------------------------------------------------------------------------
dossier_r <- file.path(racine, "R")
if (!dir.exists(dossier_r)) {
  echec("dossier R/ absent", dossier_r)
  fin()
}
fichiers <- sort(list.files(dossier_r, pattern = "\\.R$", recursive = TRUE, full.names = TRUE,
                            all.files = TRUE), method = "radix")
avant <- .n_echec
for (chemin in fichiers) {
  j <- tryCatch(jetons_du_fichier(chemin), error = function(e) conditionMessage(e))
  if (is.character(j)) {
    echec(paste0("fichier non analysable : ", gsub("[^ -~]", "?", j)), chemin)
    next
  }
  if (is.null(j)) next
  est_outils <- basename(chemin) == "outils.R"
  for (r in seq_len(nrow(j))) {
    texte <- j$texte[r]
    champ <- !is.na(j$prec[r]) && j$prec[r] %in% c("'$'", "'@'")
    appel <- j$token[r] == "SYMBOL_FUNCTION_CALL" && !champ
    if (j$token[r] == "SYMBOL" && texte == "input" && identical(j$suiv[r], "'$'")) {
      echec("Shiny dans le package : input$ (ADR 0010, point 26)", chemin, j$ligne[r])
    }
    if (appel && grepl(APPELS_SHINY, texte)) {
      echec(sprintf("Shiny dans le package : %s() (ADR 0010, point 26)", texte), chemin, j$ligne[r])
    }
    if (j$token[r] == "SYMBOL_PACKAGE" && texte == "shiny") {
      echec("Shiny dans le package : shiny:: (ADR 0010, point 26)", chemin, j$ligne[r])
    }
    # Symboles non appeles (alias `s <- set.seed`, `lapply(x, print)`) : comptes comme des
    # appels, sauf variables locales ou arguments de leur definition, et champs `x$nom`.
    nu <- j$token[r] == "SYMBOL" && !champ && !j$local[r]
    if (!est_outils && ((appel && texte %in% APPELS_ALEA) || (nu && texte %in% APPELS_ALEA) ||
                        (j$token[r] == "SYMBOL" && !champ && texte == ".Random.seed") ||
                        (j$token[r] == "STR_CONST" && gsub("[\"']", "", texte) == ".Random.seed"))) {
      echec(sprintf("alea hors de R/outils.R : %s (ADR 0010, point 21 : seule voie, outils::avec_graine)",
                    gsub("[\"']", "", texte)), chemin, j$ligne[r])
    }
    if ((appel || nu) && texte %in% APPELS_BAVARDS) {
      methode <- !is.na(j$def[r]) && grepl("^(print|format)\\.", j$def[r])
      if (!methode) {
        echec(sprintf("le moteur ne parle pas : %s%s hors d'une methode print.* ou format.* (ADR 0010, point 12)",
                      texte, if (appel) "()" else " (reference sans appel)"), chemin, j$ligne[r])
      }
    }
    if (j$non_ascii[r]) {
      echec(sprintf("caractere non ASCII dans le code (jeton %s) : ecrire \\uXXXX (M112)", j$token[r]),
            chemin, j$ligne[r])
    }
  }
}
if (.n_echec == avant) {
  ok(sprintf("R/ : %d fichier(s) sans Shiny, sans alea hors outils, sans sortie console ni date du systeme, code ASCII",
             length(fichiers)))
}

# --- app/ (facultatif) -------------------------------------------------------------------------
dossier_app <- file.path(racine, "app")
if (!dir.exists(dossier_app)) {
  ok("app/ absent : frontiere de l'application non verifiee (toleree avant la branche de l'application)")
} else {
  fichiers_app <- sort(list.files(dossier_app, pattern = "\\.R$", recursive = TRUE,
                                  full.names = TRUE, all.files = TRUE), method = "radix")
  avant <- .n_echec
  for (chemin in fichiers_app) {
    j <- tryCatch(jetons_du_fichier(chemin), error = function(e) conditionMessage(e))
    if (is.character(j)) {
      echec(paste0("fichier non analysable : ", gsub("[^ -~]", "?", j)), chemin)
      next
    }
    if (is.null(j)) next
    for (r in seq_len(nrow(j))) {
      champ <- !is.na(j$prec[r]) && j$prec[r] %in% c("'$'", "'@'")
      if (j$token[r] == "SYMBOL_PACKAGE" && j$texte[r] == "provie" && identical(j$suiv[r], "NS_GET_INT")) {
        echec("provie::: dans l'application : seules les fonctions exportees sont appelables", chemin, j$ligne[r])
      }
      if (j$token[r] == "SYMBOL_FUNCTION_CALL" && !champ && j$texte[r] %in% CALCULS_APP) {
        echec(sprintf("calcul dans l'application : %s() ; le calcul est dans le package, l'application formate", j$texte[r]),
              chemin, j$ligne[r])
      }
    }
  }
  if (.n_echec == avant) ok(sprintf("app/ : %d fichier(s) sans provie::: ni appel de calcul", length(fichiers_app)))
}

fin()
