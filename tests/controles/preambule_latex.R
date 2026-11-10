# Controle : preambule recopie de la charte LaTeX (issue #8 ; ADR 0003 annote ; ADR 0010,
# point 26 ; #27). Pour chaque document .tex ou .TEX suivi du depot (git ls-files si la racine
# examinee est la racine d'un depot git, sinon toute l'arborescence hors .git/ et
# .claude/worktrees/ ; recherche recursive, pas seulement docs/latex/) autre que la charte
# (docs/latex/charte_graphique.tex) et qui porte un \documentclass (un fichier sans
# \documentclass est un fragment inclus par un autre document : ignore) : le texte de la ligne
# 1 a la ligne qui precede \begin{document}, ou chaque bloc "% >>> A ADAPTER : <objet>" ...
# "% <<< A ADAPTER" (A accentue dans les fichiers) est remplace par une ligne-repere
# "%%BLOC:<objet>", est identique a celui de la charte traite de meme (espaces de fin de ligne
# et lignes vides finales ignores). Les reperes gardent la place des blocs : un bloc en trop,
# absent ou deplace fait differer les deux textes. Un bloc dont l'objet n'existe pas dans la
# charte, une suite de blocs differente de celle de la charte, un bloc non ferme sont des
# [ECHEC].
# Modele : docu_actu, outils/controles/preambule.R (reecrit, sans dependance).
# Usage, depuis la racine du depot : Rscript tests/controles/preambule_latex.R
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
ok <- function(message, chemin = NA_character_) {
  cat("[OK] ", if (is.na(chemin)) "" else paste0(rel(chemin), " "), message, "\n", sep = "")
}
echec <- function(message, chemin = NA_character_, ligne = NA_integer_) {
  .n_echec <<- .n_echec + 1L
  position <- if (is.na(chemin)) "" else paste0(rel(chemin), if (is.na(ligne)) "" else paste0(":", ligne), " ")
  cat("[ECHEC] ", position, message, "\n", sep = "")
}
fin <- function() quit(save = "no", status = if (.n_echec > 0L) 1L else 0L)

# Texte affichable en ASCII (un octet non ASCII devient <xx>), quelle que soit la locale.
ascii <- function(x) iconv(x, "UTF-8", "ASCII", sub = "byte")

# Sous la locale C, paste0() rend une chaine non marquee et sub() perd la marque UTF-8 : sans
# Encoding<-, startsWith() ne reconnait plus les lignes de bloc (mesure sous LC_ALL=C).
A_ACCENTUE <- "\u00c0"
OUVRE <- paste0("% >>> ", A_ACCENTUE, " ADAPTER")
FERME <- paste0("% <<< ", A_ACCENTUE, " ADAPTER")
Encoding(OUVRE) <- "UTF-8"
Encoding(FERME) <- "UTF-8"
DEBUT_DOCUMENT <- "\\begin{document}"

lire_lignes <- function(chemin) {
  x <- readLines(chemin, encoding = "UTF-8", warn = FALSE)
  sub("\r$", "", x)
}

# Ligne sans son commentaire (un % non precede d'une barre inverse ouvre un commentaire).
sans_commentaire <- function(x) sub("(^|[^\\\\])%.*$", "\\1", x)

# Preambule d'un document, chaque bloc reduit a sa ligne-repere :
# list(lignes, numeros (lignes d'origine), objets, ouvertures, erreur, ligne).
traiter <- function(chemin) {
  brut <- lire_lignes(chemin)
  if (!any(grepl("\\documentclass", sans_commentaire(brut), fixed = TRUE))) return(list(fragment = TRUE))
  debut <- grep(DEBUT_DOCUMENT, sans_commentaire(brut), fixed = TRUE)[1L]
  if (is.na(debut)) return(list(erreur = "\\begin{document} introuvable", ligne = NA_integer_))
  p <- sub("[ \t]+$", "", brut[seq_len(debut - 1L)])
  Encoding(p) <- "UTF-8"  # sub() perd la marque sous la locale C (voir plus haut)
  garder <- rep(TRUE, length(p))
  objets <- character(0)
  ouvertures <- integer(0)
  dedans <- FALSE
  ouverture <- NA_integer_
  for (k in seq_along(p)) {
    est_ouverture <- startsWith(p[k], OUVRE)
    est_fermeture <- startsWith(p[k], FERME)
    if (est_ouverture) {
      if (dedans) {
        return(list(erreur = sprintf("bloc A ADAPTER ouvert ligne %d non ferme avant la ligne %d", ouverture, k),
                    ligne = k))
      }
      dedans <- TRUE
      ouverture <- k
      objets <- c(objets, trimws(sub("^[[:space:]]*:?", "", substring(p[k], nchar(OUVRE) + 1L))))
      ouvertures <- c(ouvertures, k)
      Encoding(objets) <- "UTF-8"
      p[k] <- paste0("%%BLOC:", objets[length(objets)])
      Encoding(p) <- "UTF-8"
    } else if (dedans) {
      garder[k] <- FALSE
    }
    if (est_fermeture) {
      if (!dedans) return(list(erreur = "fin de bloc A ADAPTER sans ouverture", ligne = k))
      dedans <- FALSE
    }
  }
  if (dedans) {
    return(list(erreur = sprintf("bloc A ADAPTER ouvert ligne %d non ferme", ouverture), ligne = ouverture))
  }
  k <- which(garder)
  while (length(k) > 0L && p[k[length(k)]] == "") k <- k[-length(k)]
  list(lignes = p[k], numeros = k, objets = objets, ouvertures = ouvertures, erreur = NULL)
}

suite <- function(objets) {
  if (length(objets) == 0L) "aucun" else paste0("\"", paste(ascii(objets), collapse = "\", \""), "\"")
}

dossier_latex <- file.path(racine, "docs", "latex")
charte <- file.path(dossier_latex, "charte_graphique.tex")
if (!file.exists(charte)) {
  echec("charte absente (docs/latex/charte_graphique.tex)", charte)
  fin()
}
ref <- traiter(charte)
if (!is.null(ref$erreur)) {
  echec(ref$erreur, charte, ref$ligne)
  fin()
}
# Fichiers .tex suivis : git ls-files si `racine` est la racine d'un depot git, sinon l'arborescence.
fichiers_suivis <- function() {
  if (nzchar(Sys.which("git"))) {
    haut <- suppressWarnings(system2("git", c("-C", shQuote(racine), "rev-parse", "--show-toplevel"),
                                     stdout = TRUE, stderr = FALSE))
    if (is.null(attr(haut, "status")) && length(haut) == 1L && normalizePath(haut) == racine) {
      liste <- suppressWarnings(system2("git", c("-C", shQuote(racine), "-c", "core.quotepath=off", "ls-files"),
                                        stdout = TRUE, stderr = FALSE))
      if (is.null(attr(liste, "status"))) return(file.path(racine, liste))
    }
  }
  tout <- list.files(racine, recursive = TRUE, all.files = TRUE, include.dirs = FALSE)
  file.path(racine, tout[!startsWith(tout, ".git/") & !startsWith(tout, ".claude/worktrees/")])
}
documents <- fichiers_suivis()
documents <- documents[grepl("\\.tex$", documents, ignore.case = TRUE) & file.exists(documents)]
documents <- sort(documents[normalizePath(documents) != normalizePath(charte)], method = "radix")
if (length(documents) == 0L) {
  ok("aucun document a comparer a la charte")
  fin()
}

for (f in documents) {
  t <- traiter(f)
  if (isTRUE(t$fragment)) next
  if (!is.null(t$erreur)) {
    echec(t$erreur, f, t$ligne)
    next
  }
  avant <- .n_echec
  inconnus <- which(!(t$objets %in% ref$objets))
  for (b in inconnus) {
    echec(sprintf("bloc A ADAPTER \"%s\" absent de la charte (seuls les blocs de la charte sont modifiables)",
                  ascii(t$objets[b])), f, t$ouvertures[b])
  }
  if (length(inconnus) == 0L && !identical(t$objets, ref$objets)) {
    echec(sprintf("suite des blocs A ADAPTER : %s ; charte : %s (bloc en trop, absent ou deplace)",
                  suite(t$objets), suite(ref$objets)), f,
          if (length(t$ouvertures) > 0L) t$ouvertures[1L] else NA_integer_)
  }
  if (!identical(t$lignes, ref$lignes)) {
    n <- min(length(t$lignes), length(ref$lignes))
    i <- which(t$lignes[seq_len(n)] != ref$lignes[seq_len(n)])[1L]
    if (is.na(i)) i <- n + 1L
    ligne <- max(1L, if (i <= length(t$numeros)) t$numeros[i] else length(t$numeros))
    echec("preambule different de celui de la charte (hors blocs A ADAPTER)", f, ligne)
    cat(sprintf("    1re difference (ligne %d du preambule compare) :\n", i))
    cat("    charte : ", if (i <= length(ref$lignes)) ascii(ref$lignes[i]) else "(fin du preambule)", "\n", sep = "")
    cat("    ", basename(f), " : ", if (i <= length(t$lignes)) ascii(t$lignes[i]) else "(fin du preambule)", "\n", sep = "")
    cat(sprintf("    (%d lignes comparees dans la charte, %d dans le document)\n", length(ref$lignes), length(t$lignes)))
  }
  if (.n_echec == avant) {
    ok(sprintf("preambule identique a la charte (%d bloc(s) A ADAPTER)", length(t$objets)), f)
  }
}

fin()
