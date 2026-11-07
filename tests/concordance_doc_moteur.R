# Concordance documentation <-> code (E3.3 ; ADR 0010, points 25 et 26). À lancer depuis
# la racine du dépôt : Rscript tests/concordance_doc_moteur.R --strict
# Lit les tableaux de fonctions par module de docs/latex/doc_outil_prov_vie.tex et les
# compare aux fonctions de premier niveau de R/<module>.R. Sans --strict, les écarts sont
# des [AVERT] et la sortie vaut 0 ; avec --strict (CI), tout écart et l'absence du
# document sont des échecs. Option --racine=<dossier> : autre racine (tests du script).
#
# Convention de lecture du document (à reprendre dans docs/latex/CONVENTIONS.md) :
#   - un tableau de fonctions est précédé d'une ligne de commentaire LaTeX
#       % concordance-fonctions : <module>
#     où <module> est un des quinze noms de l'ADR 0010, point 1 ;
#   - chaque ligne du tableau cite la fonction dans sa première cellule par \code{nom} ou
#     \code{nom()} (les \_ sont acceptés) ; le tableau finit à \end{tabular},
#     \end{longtable} ou \end{tabularx} ;
#   - les fonctions recensées sont celles de premier niveau de R/<module>.R dont le nom ne
#     commence pas par un point ; chaque export() du NAMESPACE doit figurer dans un tableau.

options(warn = 2)
args <- commandArgs(TRUE)
strict <- "--strict" %in% args
fichier <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
dossier_tests <- dirname(normalizePath(fichier, mustWork = TRUE))
source(file.path(dossier_tests, "harnais.R"))
option_racine <- sub("^--racine=", "", grep("^--racine=", args, value = TRUE))
racine <- normalizePath(if (length(option_racine) == 1L) option_racine else dirname(dossier_tests),
                        mustWork = TRUE)

MODULES <- c("outils", "dictionnaire", "lecture", "donnees", "tables", "garanties",
             "engagement", "triangle", "risque_en_cours", "regles_comptables", "projection",
             "plan", "rapport", "simulation", "calculer_provisions")

# Un écart : échec en mode strict, avertissement sinon.
ecart <- function(nom, detail) {
  if (strict) {
    verifier(paste(nom, "--", detail), FALSE)
  } else {
    cat(sprintf("[AVERT] %s -- %s\n", nom, detail))
  }
}
accord <- function(nom) verifier(nom, TRUE)

# Noms des fonctions de premier niveau d'un fichier R, hors noms commençant par un point.
fonctions_du_fichier <- function(chemin) {
  noms <- character(0)
  for (expr in parse(chemin, keep.source = FALSE)) {
    if (is.call(expr) && as.character(expr[[1L]])[1L] %in% c("<-", "=") &&
        is.name(expr[[2L]]) && is.call(expr[[3L]]) && identical(expr[[3L]][[1L]], as.name("function"))) {
      noms <- c(noms, as.character(expr[[2L]]))
    }
  }
  sort(noms[!startsWith(noms, ".")], method = "radix")
}

# Tableaux du document : liste nommée par module des fonctions citées.
lire_tableaux <- function(chemin) {
  lignes <- readLines(chemin, encoding = "UTF-8", warn = FALSE)
  tableaux <- list()
  anomalies <- character(0)
  courant <- NULL
  for (l in lignes) {
    marque <- regmatches(l, regexec("^\\s*%\\s*concordance-fonctions\\s*:\\s*(\\S+)\\s*$", l))[[1L]]
    if (length(marque) == 2L) {
      courant <- marque[2L]
      if (!(courant %in% MODULES)) {
        anomalies <- c(anomalies, paste0("module inconnu dans le document : ", courant))
      } else if (courant %in% names(tableaux)) {
        anomalies <- c(anomalies, paste0("deux tableaux pour le module ", courant))
      } else {
        tableaux[[courant]] <- character(0)
      }
    } else if (!is.null(courant)) {
      if (grepl("\\\\end\\{(tabular|longtable|tabularx)\\}", l)) {
        courant <- NULL
      } else if (courant %in% names(tableaux)) {
        premiere <- strsplit(paste0(l, "&"), "(?<!\\\\)&", perl = TRUE)[[1L]][1L]
        cite <- regmatches(premiere, gregexpr("\\\\code\\{[^}]*\\}", premiere))[[1L]]
        noms <- sub("\\(\\)$", "", gsub("\\\\_", "_", sub("^\\\\code\\{(.*)\\}$", "\\1", cite)))
        tableaux[[courant]] <- c(tableaux[[courant]], noms)
      }
    }
  }
  list(tableaux = tableaux, anomalies = anomalies)
}

exports_du_namespace <- function(chemin) {
  if (!file.exists(chemin)) return(character(0))
  noms <- character(0)
  for (expr in parse(chemin, keep.source = FALSE)) {
    if (is.call(expr) && identical(expr[[1L]], as.name("export"))) {
      noms <- c(noms, vapply(as.list(expr)[-1L], as.character, ""))
    }
  }
  noms
}

section("concordance documentation <-> code")
document <- file.path(racine, "docs", "latex", "doc_outil_prov_vie.tex")
if (!file.exists(document)) {
  ecart("document docs/latex/doc_outil_prov_vie.tex", "absent")
} else {
  accord("document docs/latex/doc_outil_prov_vie.tex présent")
  lu <- lire_tableaux(document)
  for (a in lu$anomalies) ecart("tableaux de fonctions", a)
  fichiers <- list.files(file.path(racine, "R"), pattern = "\\.[Rr]$")
  hors_liste <- setdiff(sub("\\.[Rr]$", "", fichiers), MODULES)
  for (f in hors_liste) ecart("fichier de R/", paste0(f, " n'est pas un module de l'ADR 0010"))
  cites <- character(0)
  for (module in MODULES) {
    chemin <- file.path(racine, "R", paste0(module, ".R"))
    code <- if (file.exists(chemin)) fonctions_du_fichier(chemin) else character(0)
    doc <- if (module %in% names(lu$tableaux)) sort(lu$tableaux[[module]], method = "radix") else NULL
    cites <- c(cites, doc)
    if (is.null(doc) && length(code) == 0L) next
    if (is.null(doc)) {
      ecart(paste("module", module), "fonctions dans R/ mais aucun tableau dans le document")
      next
    }
    if (anyDuplicated(doc)) {
      ecart(paste("module", module), paste("fonctions citées deux fois :",
                                           paste(unique(doc[duplicated(doc)]), collapse = ", ")))
    }
    manquantes <- setdiff(code, doc)
    en_trop <- setdiff(doc, code)
    if (length(manquantes) > 0L) {
      ecart(paste("module", module), paste("fonctions absentes du document :",
                                           paste(manquantes, collapse = ", ")))
    }
    if (length(en_trop) > 0L) {
      ecart(paste("module", module), paste("fonctions citées mais absentes du code :",
                                           paste(en_trop, collapse = ", ")))
    }
    if (length(manquantes) == 0L && length(en_trop) == 0L) {
      accord(sprintf("module %s : %d fonction(s) concordante(s)", module, length(code)))
    }
  }
  exports <- exports_du_namespace(file.path(racine, "NAMESPACE"))
  non_cites <- setdiff(exports, cites)
  if (length(non_cites) > 0L) {
    ecart("exports du NAMESPACE", paste("non cités dans le document :", paste(non_cites, collapse = ", ")))
  } else {
    accord(sprintf("exports du NAMESPACE : %d, tous cités", length(exports)))
  }
}

bilan()
