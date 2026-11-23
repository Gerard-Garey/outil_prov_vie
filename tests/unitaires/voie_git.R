# Témoins de la voie `git ls-files` des scripts de contrôle de tests/controles/ (#186 ; ADR 0010,
# points 25 et 26) : seuls les fichiers suivis sont examinés, sous leur nom exact (git ls-files -z),
# les liens symboliques sont écartés, la voie suivie est annoncée.
# Deux lanceurs : tests/test_unitaires.R (le job « Tests (R 4.3.3) », dont l'image n'a pas git :
# chaque témoin de la voie git est alors SAUTÉ, et le saut est écrit au journal, une ligne [INFO]
# par témoin et un compteur) et tests/temoins_voie_git.R (le job « Contrôles du dépôt », qui a git
# et exige que tous les témoins tournent). Les témoins qui n'ont pas besoin de git (arborescence)
# tournent partout. Le harnais est sourcé et `racine` est défini par le lanceur.
# Ce fichier est lui-même balayé par absence_java.R : le nom interdit y est fabriqué
# (paste0("r", "Java")), jamais écrit en clair (N2e).

.script_controle <- function(nom) file.path(racine, "tests", "controles", paste0(nom, ".R"))

# Écrit `lignes` dans `chemin` (dossiers créés), en octets, fin de ligne \n ; un vecteur `raw` est écrit tel quel.
.deposer <- function(chemin, lignes) {
  dir.create(dirname(chemin), recursive = TRUE, showWarnings = FALSE)
  if (is.raw(lignes)) return(writeBin(lignes, chemin))
  writeBin(charToRaw(paste0(paste(lignes, collapse = "\n"), "\n")), chemin)
}
.echoue_en <- function(r, fichier, ligne = NA_integer_, motif = "") {
  position <- if (is.na(ligne)) paste0(fichier, " ") else paste0(fichier, ":", ligne, " ")
  r$statut == 1L && any(startsWith(r$sortie, paste0("[ECHEC] ", position)) & grepl(motif, r$sortie, fixed = TRUE))
}
.passe <- function(r) r$statut == 0L && !any(startsWith(r$sortie, "[ECHEC]"))
octets <- function(...) as.raw(c(...))
txt <- function(...) charToRaw(paste0(..., collapse = ""))
# Nom de fichier fabriqué octet par octet (locale C ou UTF-8 : les octets passent tels quels).
.nom_octets <- function(...) rawToChar(as.raw(c(...)))

RJ <- paste0("r", "Java")
DESC <- c("Package: temoin", "Version: 0.0.1", "Title: Temoin", "Description: Temoin.",
          "License: file LICENSE", "Imports: stats")
ARTICLE <- c("\\documentclass{article}", "\\begin{document}", "x", "\\end{document}")
GUILLEMET <- "a\"b"          # nom avec guillemet : git le met entre guillemets sans -z
TABULATION <- "tab\tc"       # nom avec tabulation
BARRE <- "bar\\re"           # nom avec barre inverse
ACCENTS <- .nom_octets(0xc3, 0xa9, 0xc3, 0xa0, 0xc3, 0xbc)   # e aigu, a grave, u trema, en UTF-8

# Lance le contrôle `script` sur une copie temporaire qui contient `suivis`, `non_suivis` (fichiers :
# liste nommée chemin relatif -> lignes ou octets) et `liens` (liste nommée chemin relatif -> cible).
# Avec `git`, la copie est initialisée par git init et les suivis et les liens sont ajoutés par git add ;
# `env` : variables d'environnement du contrôle ("NOM=valeur"). Rend list(statut, sortie).
.essai_copie <- function(script, suivis = list(), non_suivis = list(), liens = list(), git = TRUE,
                         env = character(0)) {
  copie <- tempfile("temoin-git-")
  dir.create(copie)
  on.exit(unlink(copie, recursive = TRUE), add = TRUE)
  for (chemin in names(suivis)) .deposer(file.path(copie, chemin), suivis[[chemin]])
  for (chemin in names(non_suivis)) .deposer(file.path(copie, chemin), non_suivis[[chemin]])
  for (chemin in names(liens)) {
    dir.create(dirname(file.path(copie, chemin)), recursive = TRUE, showWarnings = FALSE)
    if (!file.symlink(liens[[chemin]], file.path(copie, chemin))) stop("lien symbolique non cree : ", chemin)
  }
  if (git) {
    commande <- function(...) {
      sortie <- suppressWarnings(system2("git", c("-C", shQuote(copie), ...), stdout = TRUE, stderr = TRUE))
      if (!is.null(attr(sortie, "status"))) stop("git ", paste(c(...), collapse = " "), " a echoue : ", paste(sortie, collapse = " "))
      sortie
    }
    commande("init", "-q")
    commande("add", "--", shQuote(c(names(suivis), names(liens))))
  }
  sortie <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
                                     c(shQuote(.script_controle(script)), shQuote(copie)),
                                     stdout = TRUE, stderr = TRUE, env = env))
  statut <- attr(sortie, "status")
  list(statut = if (is.null(statut)) 0L else statut, sortie = sortie)
}

section("contrôles : voie git ls-files (#186)")
# --- Témoins qui n'ont pas besoin de git : voie « arborescence » ------------------------------------
# Un lien symbolique est écarté, avec une ligne [INFO] ; sa cible (ici un fichier à octet de contrôle,
# hors de la copie) n'est pas lue. Avant #186, readBin() lisait la cible : [ECHEC] à tort.
cible <- tempfile("cible-lien-")
.deposer(cible, c(txt("a\n"), octets(12L), txt("\n")))
r <- .essai_copie("caracteres_controle", suivis = list("docs/s.md" = "propre"),
                  liens = list("docs/lien.md" = cible), git = FALSE)
verifier("#186 : arborescence : un lien symbolique vers un fichier à octet de contrôle est écarté, [INFO] docs/lien.md, statut 0",
         .passe(r) && any(startsWith(r$sortie, "[INFO] docs/lien.md : lien symbolique")) &&
           any(grepl("^\\[OK\\] 1 fichier", r$sortie)))
unlink(cible)
verifier("#186 : arborescence : la voie suivie est annoncée, ligne [INFO] voie : arborescence",
         any(startsWith(r$sortie, "[INFO] voie : arborescence")))

# --- Témoins de la voie git ----------------------------------------------------------------------------
git_disponible <- nzchar(Sys.which("git"))
.sautes <- character(0)
# Un témoin de la voie git : évalué (verifier) si git est présent, sinon SAUTÉ et compté ; `condition`
# est évaluée paresseusement, le montage de la copie (git init) n'a donc pas lieu sans git.
temoin_git <- function(nom, condition) {
  if (git_disponible) verifier(nom, condition) else .sautes <<- c(.sautes, nom)
  invisible(NULL)
}

# C5 : voie `git ls-files` (la racine examinée est la racine d'un dépôt git) : seuls les fichiers
# suivis sont balayés. Copie temporaire initialisée par git init et git add. `r` est remis à NULL :
# le second témoin lit la copie du premier et ne doit pas passer sur la sortie d'un témoin antérieur
# si le montage du premier échoue (constat mineur de l'audit de #186).
r <- NULL
temoin_git("C5 : fichier suivi interdit refuse (git ls-files), t_java.R:1", {
  r <- .essai_copie("absence_java", list(DESCRIPTION = DESC, "tests/t_java.R" = paste0("library(", RJ, ")")),
                    list("tests/u_java.R" = paste0("library(", RJ, ")")))
  .echoue_en(r, "tests/t_java.R", 1L, RJ)
})
temoin_git("C5 : fichier non suivi ignore (git ls-files), pas de ligne pour u_java.R",
           !is.null(r) && !any(grepl("u_java.R", r$sortie, fixed = TRUE)))
temoin_git("C5 : seul un fichier non suivi interdit : le controle passe (preuve de la voie git)", {
  r <- .essai_copie("absence_java", list(DESCRIPTION = DESC), list("tests/u_java.R" = paste0("library(", RJ, ")")))
  .passe(r)
})
temoin_git("#182 : voie git : un fichier suivi qui porte U+000C est refusé, s.md:2 ; le fichier non suivi n'est pas cité", {
  r <- .essai_copie("caracteres_controle", list("docs/s.md" = c(txt("a\n"), octets(12L), txt("\n"))),
                    list("docs/n.md" = c(octets(12L), txt("\n"))))
  .echoue_en(r, "docs/s.md", 2L, "U+000C") && !any(grepl("n.md", r$sortie, fixed = TRUE))
})
temoin_git("#182 : voie git : seul un fichier non suivi porte U+000C, le contrôle passe (preuve de la voie git)", {
  r <- .essai_copie("caracteres_controle", list("docs/s.md" = "propre"), list("docs/n.md" = c(octets(12L), txt("\n"))))
  .passe(r) && any(grepl("^\\[OK\\] 1 fichier", r$sortie))
})

# #186 : noms cités par git sans -z (guillemet, tabulation, barre inverse) ou non ASCII : les fichiers
# suivis sont examinés sous leur nom exact. Avant #186, l'absence d'[ECHEC] pour les trois premiers
# était silencieuse (statut 0, « 1 fichier(s) texte examine(s) »).
suivis <- stats::setNames(rep(list(c(txt("a\n"), octets(12L), txt("\n"))), 4L),
                          paste0("docs/", c(GUILLEMET, TABULATION, BARRE, ACCENTS), ".md"))
for (variante in list(character(0), "LC_ALL=C")) {
  temoin_git(paste0("#186 : voie git : noms suivis à guillemet, tabulation, barre inverse et accents, tous examinés et refusés (U+000C)",
                    if (length(variante)) paste0(", sous ", variante) else ""), {
    r <- .essai_copie("caracteres_controle", suivis, env = variante)
    all(vapply(names(suivis), function(n) .echoue_en(r, n, 2L, "U+000C"), NA)) &&
      any(grepl("^\\[INFO\\] voie : git ls-files$", r$sortie))
  })
}
temoin_git("#186 : voie git : absence_java.R balaie un fichier suivi à guillemet ou à tabulation dans le nom, a\"b.R:1 et tab\\tc.R:1", {
  r <- .essai_copie("absence_java", stats::setNames(
    list(DESC, paste0("library(", RJ, ")"), paste0("library(", RJ, ")")),
    c("DESCRIPTION", paste0("tests/", GUILLEMET, ".R"), paste0("tests/", TABULATION, ".R"))))
  .echoue_en(r, paste0("tests/", GUILLEMET, ".R"), 1L, RJ) && .echoue_en(r, paste0("tests/", TABULATION, ".R"), 1L, RJ)
})
temoin_git("#186 : voie git : preambule_latex.R examine un .tex suivi à guillemet dans le nom, a\"b.tex:1", {
  charte <- readLines(file.path(racine, "docs", "latex", "charte_graphique.tex"), encoding = "UTF-8", warn = FALSE)
  r <- .essai_copie("preambule_latex", stats::setNames(list(charte, ARTICLE),
                                                      c("docs/latex/charte_graphique.tex", paste0("docs/latex/", GUILLEMET, ".tex"))))
  .echoue_en(r, paste0("docs/latex/", GUILLEMET, ".tex"), 1L)
})
# Voie annoncée : git présent mais dépôt illisible (GIT_DIR invalide : rev-parse échoue) : le contrôle
# bascule sur l'arborescence, et la ligne [INFO] le dit (le fichier non suivi est alors examiné).
temoin_git("#186 : voie annoncée : git présent mais illisible (GIT_DIR invalide) : [INFO] voie : arborescence, fichier non suivi examiné", {
  r <- .essai_copie("caracteres_controle", list("docs/s.md" = "propre"), list("docs/n.md" = c(octets(12L), txt("\n"))),
                    env = "GIT_DIR=/nonexistent/depot")
  .echoue_en(r, "docs/n.md", 1L, "U+000C") && any(startsWith(r$sortie, "[INFO] voie : arborescence"))
})
# Un lien suivi n'est pas lu, même s'il pointe hors du dépôt vers un fichier à octets de contrôle ;
# un lien suivi vers un dossier est signalé (avant #186, il était ignoré sans message).
temoin_git("#186 : voie git : un lien suivi vers un dossier est signalé par [INFO], statut 0, rien n'est lu dans le dossier", {
  r <- .essai_copie("caracteres_controle", list("docs/s.md" = "propre"), liens = list("docs/dossier" = tempdir()))
  .passe(r) && any(startsWith(r$sortie, "[INFO] docs/dossier : lien symbolique")) && any(grepl("^\\[OK\\] 1 fichier", r$sortie))
})
temoin_git("#186 : voie git : un lien suivi vers un fichier à octet de contrôle est écarté, [INFO] lien, statut 0", local({
  cible <- tempfile("cible-lien-")
  on.exit(unlink(cible), add = TRUE)
  .deposer(cible, c(txt("a\n"), octets(12L), txt("\n")))
  r <- .essai_copie("caracteres_controle", list("docs/s.md" = "propre"), liens = list("lien" = cible))
  .passe(r) && any(startsWith(r$sortie, "[INFO] lien : lien symbolique")) && any(grepl("^\\[OK\\] 1 fichier", r$sortie))
}))
# Un fichier suivi supprimé de l'arbre de travail avant git add n'est pas lu, et le journal le dit.
temoin_git("#186 : voie git : un fichier suivi mais absent de l'arbre est signalé par [INFO], pas ignoré sans message", local({
  copie <- tempfile("temoin-absent-")
  dir.create(copie)
  on.exit(unlink(copie, recursive = TRUE), add = TRUE)
  .deposer(file.path(copie, "docs", "a.md"), "propre")
  .deposer(file.path(copie, "docs", "b.md"), "propre")
  git <- function(...) suppressWarnings(system2("git", c("-C", shQuote(copie), ...), stdout = TRUE, stderr = TRUE))
  git("init", "-q")
  git("add", "--", "docs")
  unlink(file.path(copie, "docs", "b.md"))
  sortie <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
                                     c(shQuote(.script_controle("caracteres_controle")), shQuote(copie)),
                                     stdout = TRUE, stderr = TRUE))
  is.null(attr(sortie, "status")) && any(startsWith(sortie, "[INFO] docs/b.md : suivi mais absent")) &&
    any(grepl("^\\[OK\\] 1 fichier", sortie))
}))

# Bilan des sauts : chaque témoin sauté est nommé au journal, puis un compteur. Sans cela, l'écart
# entre le local (avec git) et la CI (sans git) n'était visible qu'à la différence des décomptes (#186).
for (nom in .sautes) informer(paste0("SAUTE : ", nom), "git absent du PATH")
if (length(.sautes)) {
  informer(paste0("SAUTE : ", length(.sautes), " témoin(s) de la voie git"),
           "git absent du PATH ; rejoués par tests/temoins_voie_git.R dans le job « Contrôles du dépôt »")
}
