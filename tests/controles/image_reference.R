# Controle : image de la plateforme de reference (ADR 0011, point 21 ; ADR 0010, point 26,
# annote ; #67). La chaine `container:` du job "Tests (R 4.3.3)" de
# .github/workflows/ci.yml et celle du job du workflow de regeneration
# .github/workflows/regenerer-references.yml sont la meme, epinglee par digest
# (rocker/r-ver:4.3.3@sha256:<64 hexadecimaux>), et son digest est celui que CONTEXT.md
# consigne a l'entree "Plateforme de reference". La variable PROVIE_IMAGE du workflow de
# regeneration (consignee dans provenance.txt) est la meme chaine.
# Temoins negatifs integres : un digest different, une image non epinglee et deux images dans
# un fichier sont refuses par la meme fonction de lecture.
# Usage, depuis la racine du depot : Rscript tests/controles/image_reference.R
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

IMAGE <- "rocker/r-ver:4\\.3\\.3@sha256:[0-9a-f]{64}"

# Images `container:` d'un workflow (lignes) : list(images, lignes, anomalie) ; anomalie si
# aucune, plusieurs, ou une image non epinglee par digest.
images_container <- function(lignes) {
  i <- grep("^\\s*container:\\s*", lignes)
  valeurs <- trimws(sub("^\\s*container:\\s*", "", lignes[i]))
  anomalie <- if (length(i) != 1L) sprintf("%d ligne(s) container:, une attendue", length(i)) else
    if (!grepl(paste0("^", IMAGE, "$"), valeurs)) paste0("image non epinglee par digest : ", valeurs) else NA_character_
  list(images = valeurs, lignes = i, anomalie = anomalie)
}

# Digest consigne par CONTEXT.md a l'entree "Plateforme de reference" (premiere image
# epinglee qui suit le libelle).
digest_context <- function(texte) {
  debut <- regexpr("Plateforme de r\u00e9f\u00e9rence\\*\\*", texte)
  if (debut < 0L) return(NA_character_)
  suite <- substring(texte, debut)
  m <- regmatches(suite, regexpr(IMAGE, suite))
  if (length(m) == 0L) NA_character_ else m
}

lire <- function(chemin) {
  if (!file.exists(chemin)) {
    echec("fichier absent", chemin)
    return(NULL)
  }
  readLines(chemin, warn = FALSE, encoding = "UTF-8")
}

ci <- file.path(racine, ".github", "workflows", "ci.yml")
regen <- file.path(racine, ".github", "workflows", "regenerer-references.yml")
context <- file.path(racine, "CONTEXT.md")
lignes_ci <- lire(ci)
lignes_regen <- lire(regen)
lignes_context <- lire(context)
if (is.null(lignes_ci) || is.null(lignes_regen) || is.null(lignes_context)) fin()

avant <- .n_echec
a <- images_container(lignes_ci)
b <- images_container(lignes_regen)
if (!is.na(a$anomalie)) echec(paste0("ci.yml : ", a$anomalie), ci, if (length(a$lignes)) a$lignes[1L] else NA_integer_)
if (!is.na(b$anomalie)) echec(paste0("regenerer-references.yml : ", b$anomalie), regen,
                              if (length(b$lignes)) b$lignes[1L] else NA_integer_)
if (is.na(a$anomalie) && is.na(b$anomalie) && !identical(a$images, b$images)) {
  echec(paste0("container: differente de celle de ci.yml (", a$images, ")"), regen, b$lignes)
}
d <- digest_context(paste(lignes_context, collapse = "\n"))
if (is.na(d)) {
  echec("CONTEXT.md : aucune image epinglee a l'entree Plateforme de reference", context)
} else if (is.na(a$anomalie) && !identical(d, a$images)) {
  echec(paste0("ci.yml : image differente de celle de CONTEXT.md (", d, ")"), ci, a$lignes)
}
pi <- grep("^\\s*PROVIE_IMAGE:\\s*", lignes_regen)
if (length(pi) != 1L || (is.na(a$anomalie) && !identical(trimws(sub("^\\s*PROVIE_IMAGE:\\s*", "", lignes_regen[pi])), a$images))) {
  echec("PROVIE_IMAGE absente ou differente de container:", regen, if (length(pi)) pi[1L] else NA_integer_)
}
if (.n_echec == avant) ok(paste0("image de reference identique dans ci.yml, regenerer-references.yml (container:, PROVIE_IMAGE) et CONTEXT.md : ", a$images))

# Temoins negatifs : la lecture refuse un digest absent, deux images, une image non epinglee,
# et la comparaison voit un digest different.
avant <- .n_echec
autre <- sub("[0-9a-f]$", "0", a$images)
if (identical(autre, a$images)) autre <- sub("[0-9a-f]$", "1", a$images)
if (is.na(images_container(c("    container: rocker/r-ver:4.3.3"))$anomalie)) echec("temoin : image non epinglee admise")
if (is.na(images_container(c("container: x", "container: y"))$anomalie)) echec("temoin : deux lignes container: admises")
if (is.na(images_container(character(0))$anomalie)) echec("temoin : aucune ligne container: admise")
if (identical(images_container(paste("    container:", autre))$images, a$images)) echec("temoin : digest different non vu")
if (!is.na(digest_context("aucune plateforme"))) echec("temoin : CONTEXT.md sans entree lu comme un digest")
if (.n_echec == avant) ok("temoins negatifs refuses (image non epinglee, deux ou aucune ligne container:, digest different, entree absente)")
fin()
