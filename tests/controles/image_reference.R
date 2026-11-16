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

# Images `container:` d'un workflow (lignes) : list(images, lignes, anomalie, ligne) ; anomalie
# si aucune, plusieurs (une seule attendue ; `plusieurs = TRUE` : plusieurs admises si elles sont
# la meme chaine, cas de ci.yml depuis #149 : jobs "Tests (R 4.3.3)" et "Invariance du
# bilan"), ou une image non epinglee par digest ; `ligne` est la ligne fautive (premiere ligne
# non epinglee, ou premiere ligne qui differe de la premiere image ; la premiere ligne
# container: pour un compte inattendu ; NA sans anomalie ou sans ligne).
images_container <- function(lignes, plusieurs = FALSE) {
  i <- grep("^\\s*container:\\s*", lignes)
  valeurs <- trimws(sub("^\\s*container:\\s*", "", lignes[i]))
  epinglee <- grepl(paste0("^", IMAGE, "$"), valeurs)
  anomalie <- if (length(i) == 0L || (!plusieurs && length(i) != 1L)) sprintf("%d ligne(s) container:, une attendue", length(i)) else
    if (!all(epinglee)) paste0("image non epinglee par digest : ", paste(valeurs[!epinglee], collapse = ", ")) else
    if (length(unique(valeurs)) != 1L) paste0("images differentes entre les lignes container: : ", paste(unique(valeurs), collapse = ", ")) else NA_character_
  ligne <- if (is.na(anomalie) || length(i) == 0L) NA_integer_ else
    if (!plusieurs && length(i) != 1L) i[1L] else
    if (!all(epinglee)) i[which(!epinglee)[1L]] else
    if (length(unique(valeurs)) != 1L) i[which(valeurs != valeurs[1L])[1L]] else i[1L]
  list(images = unique(valeurs), lignes = i, anomalie = anomalie, ligne = ligne)
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
a <- images_container(lignes_ci, plusieurs = TRUE)
b <- images_container(lignes_regen)
if (!is.na(a$anomalie)) echec(paste0("ci.yml : ", a$anomalie), ci, a$ligne)
if (!is.na(b$anomalie)) echec(paste0("regenerer-references.yml : ", b$anomalie), regen, b$ligne)
if (is.na(a$anomalie) && is.na(b$anomalie) && !identical(a$images, b$images)) {
  echec(paste0("container: differente de celle de ci.yml (", a$images, ")"), regen, b$lignes[1L])
}
d <- digest_context(paste(lignes_context, collapse = "\n"))
if (is.na(d)) {
  echec("CONTEXT.md : aucune image epinglee a l'entree Plateforme de reference", context)
} else if (is.na(a$anomalie) && !identical(d, a$images)) {
  echec(paste0("ci.yml : image differente de celle de CONTEXT.md (", d, ")"), ci, a$lignes[1L])
}
pi <- grep("^\\s*PROVIE_IMAGE:\\s*", lignes_regen)
if (length(pi) != 1L || (is.na(a$anomalie) && !identical(trimws(sub("^\\s*PROVIE_IMAGE:\\s*", "", lignes_regen[pi])), a$images))) {
  echec("PROVIE_IMAGE absente ou differente de container:", regen, if (length(pi)) pi[1L] else NA_integer_)
}
if (.n_echec == avant) ok(paste0("image de reference identique dans ci.yml, regenerer-references.yml (container:, PROVIE_IMAGE) et CONTEXT.md : ", a$images))

# Temoins negatifs : la lecture refuse un digest absent, deux images, une image non epinglee,
# et la comparaison voit un digest different.
avant <- .n_echec
# Les temoins reposent sur des constantes independantes de l'image lue, pour qu'un ci.yml
# fautif ne produise pas d'[ECHEC] parasite de temoin.
img_t <- paste0("rocker/r-ver:4.3.3@sha256:", strrep("a", 64L))
autre <- paste0("rocker/r-ver:4.3.3@sha256:", strrep("b", 64L))
ligne_t <- function(image) paste("    container:", image)
if (is.na(images_container(c("    container: rocker/r-ver:4.3.3"))$anomalie)) echec("temoin : image non epinglee admise")
if (is.na(images_container(c("container: x", "container: y"))$anomalie)) echec("temoin : deux lignes container: admises")
if (is.na(images_container(character(0))$anomalie)) echec("temoin : aucune ligne container: admise")
if (identical(images_container(ligne_t(autre))$images, img_t)) echec("temoin : digest different non vu")
if (is.na(images_container(rep(ligne_t(img_t), 2L))$anomalie)) echec("temoin : deux lignes container: admises sans plusieurs")
if (!is.na(images_container(rep(ligne_t(img_t), 2L), plusieurs = TRUE)$anomalie)) echec("temoin : deux lignes identiques refusees avec plusieurs")
if (is.na(images_container(ligne_t(c(img_t, autre)), plusieurs = TRUE)$anomalie)) echec("temoin : deux images differentes admises avec plusieurs")
# La ligne citee est la ligne fautive : premiere non epinglee, ou premiere qui differe.
if (!identical(images_container(c("a", ligne_t(img_t), "b", "    container: rocker/r-ver:4.3.3", ligne_t(img_t)), plusieurs = TRUE)$ligne, 4L)) echec("temoin : ligne fautive (non epinglee) mal citee")
if (!identical(images_container(c(ligne_t(img_t), "x", ligne_t(img_t), ligne_t(autre), ligne_t(autre)), plusieurs = TRUE)$ligne, 4L)) echec("temoin : ligne fautive (digest different) mal citee")
if (!is.na(images_container(rep(ligne_t(img_t), 2L), plusieurs = TRUE)$ligne)) echec("temoin : ligne citee sans anomalie")
if (!identical(images_container(c(ligne_t(img_t), "x", "    container: rocker/r-ver:4.3.3"))$ligne, 1L)) echec("temoin : ligne citee pour un compte inattendu (premiere ligne container:)")
if (!is.na(digest_context("aucune plateforme"))) echec("temoin : CONTEXT.md sans entree lu comme un digest")
if (.n_echec == avant) ok("temoins negatifs refuses (image non epinglee, deux ou aucune ligne container:, digest different, entree absente)")
fin()
