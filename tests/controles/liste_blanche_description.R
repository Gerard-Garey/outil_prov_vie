# Controle : liste blanche des dependances de DESCRIPTION (ADR 0004, point 3 ; ADR 0010,
# point 26 ; issue #12 ; #27). Les champs Depends, Imports, LinkingTo, Suggests et Enhances
# de DESCRIPTION ne citent que des packages de priorite `base` (et R lui-meme, dans Depends) ;
# les champs Remotes et Additional_repositories sont refuses (un package hors CRAN ou hors
# liste n'entre pas par un depot declare) ; les directives import(), importFrom(),
# importClassesFrom() et importMethodsFrom() de NAMESPACE de meme. NAMESPACE est lu par
# parse() avec srcref, sans evaluation, les deux branches de chaque `if` etant visitees (le
# texte d'une chaine contenant `#` ne masque rien ; tous les arguments de import(), sur
# plusieurs lignes, hors `except = ...`).
# Usage, depuis la racine du depot : Rscript tests/controles/liste_blanche_description.R
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

# --- Liste blanche : packages de priorite base (ADR 0004, point 3) -------------------
LISTE_BLANCHE <- c("base", "compiler", "datasets", "graphics", "grDevices", "grid",
                   "methods", "parallel", "splines", "stats", "stats4", "tcltk", "tools",
                   "utils")
CHAMPS <- c("Depends", "Imports", "LinkingTo", "Suggests", "Enhances")
CHAMPS_REFUSES <- c("Remotes", "Additional_repositories")

# Noms de packages d'un champ DESCRIPTION (versions retirees) ; "R" exclu.
noms_paquets <- function(valeur) {
  if (is.na(valeur)) return(character(0))
  morceaux <- trimws(strsplit(valeur, ",", fixed = TRUE)[[1L]])
  noms <- trimws(sub("\\(.*$", "", morceaux))
  noms[nzchar(noms) & noms != "R"]
}

# Premiere ligne de `lignes` qui contient le mot `nom` (sinon `defaut`).
ligne_du_mot <- function(lignes, nom, defaut = NA_integer_) {
  i <- grep(paste0("(^|[^A-Za-z0-9.])", gsub(".", "\\.", nom, fixed = TRUE), "($|[^A-Za-z0-9.])"), lignes)
  if (length(i) > 0L) i[1L] else defaut
}

description <- file.path(racine, "DESCRIPTION")
if (!file.exists(description)) {
  echec("DESCRIPTION absent", description)
  fin()
}
lignes_description <- readLines(description, warn = FALSE)
dcf <- read.dcf(description, fields = c(CHAMPS, CHAMPS_REFUSES))
for (champ in CHAMPS) {
  noms <- noms_paquets(dcf[1L, champ])
  hors <- setdiff(noms, LISTE_BLANCHE)
  for (nom in hors) {
    echec(sprintf("%s : le package `%s` n'est pas sur la liste blanche (ADR 0004, point 3)", champ, nom),
          description, ligne_du_mot(lignes_description, nom))
  }
  if (length(hors) == 0L) {
    ok(sprintf("DESCRIPTION, %s : %s", champ, if (length(noms) == 0L) "vide" else paste(noms, collapse = ", ")))
  }
}

for (champ in CHAMPS_REFUSES) {
  if (!is.na(dcf[1L, champ])) {
    echec(sprintf("%s : champ refuse (un package ne peut entrer que par la liste blanche, ADR 0004, point 3)", champ),
          description, ligne_du_mot(lignes_description, champ))
  }
}

# --- NAMESPACE : import(), importFrom(), importClassesFrom(), importMethodsFrom() -------------
# NAMESPACE est lu par parse() avec srcref, SANS evaluation (aucun code du depot n'est execute ;
# parseNamespaceFile() evalue les `if` et ne garderait que la branche vraie) : parcours recursif
# des expressions, les deux branches de chaque `if` etant visitees. import() : tous ses
# arguments sauf `except` ; les autres directives : leur premier argument. Un `#` dans une
# chaine ne masque rien ; la ligne rendue est celle de l'expression de premier niveau.
DIRECTIVES_NAMESPACE <- c("import", "importFrom", "importClassesFrom", "importMethodsFrom")
namespace <- file.path(racine, "NAMESPACE")
if (file.exists(namespace)) {
  avant <- .n_echec
  expressions <- tryCatch(parse(file = namespace, keep.source = TRUE, encoding = "UTF-8"),
                          error = function(e) conditionMessage(e))
  if (is.character(expressions)) {
    echec(paste0("NAMESPACE non analysable : ", gsub("[^ -~]", "?", expressions)), namespace)
  } else {
    nom_de <- function(x) if (is.name(x)) as.character(x) else if (is.character(x) && length(x) == 1L) x else NA_character_
    importes <- character(0)   # packages importes
    lignes_importes <- integer(0)
    visiter <- function(e, ligne) {
      if (!is.call(e)) return(invisible(NULL))
      tete <- nom_de(e[[1L]])
      if (!is.na(tete) && tete %in% DIRECTIVES_NAMESPACE) {
        arguments <- as.list(e)[-1L]
        if (tete == "import") {
          noms_arguments <- if (is.null(names(arguments))) rep("", length(arguments)) else names(arguments)
          arguments <- arguments[noms_arguments != "except"]
        } else {
          arguments <- arguments[seq_len(min(1L, length(arguments)))]
        }
        for (a in arguments) {
          nom <- nom_de(a)
          if (!is.na(nom)) {
            importes <<- c(importes, nom)
            lignes_importes <<- c(lignes_importes, ligne)
          }
        }
      } else {
        for (k in seq_along(e)) visiter(e[[k]], ligne)
      }
      invisible(NULL)
    }
    for (e in seq_along(expressions)) visiter(expressions[[e]], attr(expressions, "srcref")[[e]][1L])
    for (k in which(!(importes %in% LISTE_BLANCHE) & !duplicated(importes))) {
      echec(sprintf("NAMESPACE : import du package `%s`, hors liste blanche (ADR 0004, point 3)", importes[k]),
            namespace, lignes_importes[k])
    }
  }
  if (.n_echec == avant) ok("NAMESPACE : aucun import hors liste blanche")
}

fin()
