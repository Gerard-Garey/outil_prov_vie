# Controle : liste blanche des dependances de DESCRIPTION (ADR 0004, point 3 ; ADR 0010,
# point 26 ; issue #12). Les champs Depends, Imports, LinkingTo et Suggests de DESCRIPTION
# ne citent que des packages de priorite `base` (et R lui-meme, dans Depends) ; les
# directives import(), importFrom(), importClassesFrom() et importMethodsFrom() de NAMESPACE (tous les arguments de import(), sur plusieurs lignes) de meme.
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
CHAMPS <- c("Depends", "Imports", "LinkingTo", "Suggests")

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
dcf <- read.dcf(description, fields = CHAMPS)
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

# --- NAMESPACE : import(), importFrom(), importClassesFrom(), importMethodsFrom() -------------
# Directives lues sur le texte sans commentaires (une directive peut couvrir plusieurs
# lignes). import() : tous ses arguments sont des packages (hors `except = ...`) ; les autres
# directives : leur premier argument.
arguments_de <- function(texte, debut) {
  # `debut` = position de la parenthese ouvrante ; rend les arguments de premier niveau.
  caracteres <- strsplit(texte, "")[[1L]]
  profondeur <- 0L
  courant <- character(0)
  arguments <- character(0)
  for (k in debut:length(caracteres)) {
    c1 <- caracteres[k]
    if (c1 == "(") {
      profondeur <- profondeur + 1L
      if (profondeur == 1L) next
    } else if (c1 == ")") {
      profondeur <- profondeur - 1L
      if (profondeur == 0L) {
        arguments <- c(arguments, paste(courant, collapse = ""))
        break
      }
    } else if (c1 == "," && profondeur == 1L) {
      arguments <- c(arguments, paste(courant, collapse = ""))
      courant <- character(0)
      next
    }
    courant <- c(courant, c1)
  }
  trimws(arguments)
}
namespace <- file.path(racine, "NAMESPACE")
if (file.exists(namespace)) {
  lignes_namespace <- sub("#.*$", "", readLines(namespace, warn = FALSE))
  texte <- paste(lignes_namespace, collapse = "\n")
  debuts_de_ligne <- cumsum(c(1L, nchar(lignes_namespace) + 1L))
  avant <- .n_echec
  directives <- gregexpr("(^|[^A-Za-z0-9._])(import|importFrom|importClassesFrom|importMethodsFrom)[ \t\n]*\\(", texte)[[1L]]
  if (directives[1L] > 0L) {
    for (d in seq_along(directives)) {
      position <- directives[d]
      longueur <- attr(directives, "match.length")[d]
      nom_directive <- gsub("[^A-Za-z]", "", substring(texte, position, position + longueur - 1L))
      ligne <- findInterval(position + 1L, debuts_de_ligne)
      arguments <- arguments_de(texte, position + longueur - 1L)
      if (nom_directive != "import") {
        arguments <- arguments[1L]
      } else {
        arguments <- arguments[!grepl("^except[ \t]*=", arguments)]
      }
      for (nom in gsub("[\"' \t\n]", "", arguments)) {
        if (nzchar(nom) && !(nom %in% LISTE_BLANCHE)) {
          echec(sprintf("NAMESPACE : %s() du package `%s`, hors liste blanche (ADR 0004, point 3)",
                        nom_directive, nom), namespace, ligne)
        }
      }
    }
  }
  if (.n_echec == avant) ok("NAMESPACE : aucun import hors liste blanche")
}

fin()
