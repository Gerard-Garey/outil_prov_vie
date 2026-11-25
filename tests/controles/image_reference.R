# Controle : image de la plateforme de reference (ADR 0011, point 21 ; ADR 0010, point 26,
# annote ; #67). La chaine `container:` du job "Tests (R 4.3.3)" de
# .github/workflows/ci.yml et celle du job du workflow de regeneration
# .github/workflows/regenerer-references.yml sont la meme, epinglee par digest
# (rocker/r-ver:4.3.3@sha256:<64 hexadecimaux>), et son digest est celui que CONTEXT.md
# consigne a l'entree "Plateforme de reference". La variable PROVIE_IMAGE du workflow de
# regeneration (consignee dans provenance.txt) est la meme chaine.
# Temoins negatifs integres : un digest different, une image non epinglee, deux images dans
# un fichier, une ligne container: rattachee a un autre job, un job sans ligne container: et un
# digest lu hors de l'entree de CONTEXT.md sont refuses par les memes fonctions de lecture.
# Lecture (#196) : les fichiers sont lus ligne a ligne, sans lecteur YAML, mais chaque ligne
# container: est rattachee a son job par son indentation et la cle de job qui la precede (cle
# de job : cle de plus petite indentation sous `jobs:` ; la ligne est une cle du job si elle a
# l'indentation de la premiere ligne du job) ; les jobs attendus sont exiges : "tests" et
# "invariance" dans ci.yml, "candidat" dans regenerer-references.yml, une ligne container: chacun,
# aucune dans un autre job. Le digest de CONTEXT.md est lu dans l'entree "Plateforme de
# reference" seule, bornee par la marque de gras suivante (`**`), une ligne vide ou la ligne
# d'une autre entree (`- `, `#`).
# Limites connues (#140 ; chacune mesuree sur un cas construit) :
#   - `image:` d'un service (`image: postgres:latest`) n'est pas lue ; une cle de job entre
#     guillemets, ou un job dont la cle change de nom, n'est pas reconnu (le job attendu est
#     alors absent : [ECHEC], du cote sur) ;
#   - seule la forme `container: <image>` sur une ligne est reconnue : une valeur entre
#     guillemets, un commentaire en fin de ligne ou la forme mapping (`container:` puis
#     `image:`) sont refuses a tort, comme "image non epinglee" ;
#   - un digest n'est controle que par sa forme (64 hexadecimaux) et par l'accord des fichiers :
#     qu'il designe l'image qui a produit les references n'est pas verifie (64 `a` partout
#     passent) ;
#   - une marque de gras dans l'entree de CONTEXT.md avant le digest coupe l'entree : le digest
#     n'est alors pas trouve ([ECHEC], du cote sur).
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

JOBS_CI <- c("tests", "invariance")
JOBS_REGEN <- "candidat"
IMAGE <- "rocker/r-ver:4\\.3\\.3@sha256:[0-9a-f]{64}"

# Jobs d'un workflow (lignes) : list(noms, lignes, job) ; `noms` les cles de job sous `jobs:`,
# `lignes` leur numero de ligne, `job` pour chaque ligne le job dont elle est une cle directe
# (NA hors d'un job, ou plus profonde que les cles du job).
structure_jobs <- function(lignes) {
  utile <- grepl("[^[:space:]]", lignes) & !grepl("^\\s*#", lignes)
  ind <- ifelse(utile, nchar(sub("^( *).*$", "\\1", lignes)), NA_integer_)
  job <- rep(NA_character_, length(lignes))
  noms <- character(0)
  lig <- integer(0)
  enfant <- integer(0)
  j0 <- which(utile & ind == 0L & grepl("^jobs:\\s*(#.*)?$", lignes))
  if (length(j0) > 0L) {
    ind_job <- NA_integer_
    courant <- NA_character_
    for (k in seq_along(lignes)[-seq_len(j0[1L])]) {
      if (!utile[k]) next
      if (ind[k] == 0L) break
      if (is.na(ind_job)) ind_job <- ind[k]
      if (ind[k] == ind_job) {
        m <- regmatches(lignes[k], regexec("^ *([A-Za-z0-9_-]+):\\s*(#.*)?$", lignes[k]))[[1L]]
        courant <- if (length(m)) m[2L] else NA_character_
        if (!is.na(courant)) {
          noms <- c(noms, courant)
          lig <- c(lig, k)
          enfant <- c(enfant, NA_integer_)
        }
      } else if (ind[k] > ind_job && !is.na(courant)) {
        if (is.na(enfant[length(enfant)])) enfant[length(enfant)] <- ind[k]
        if (ind[k] == enfant[length(enfant)]) job[k] <- courant
      }
    }
  }
  list(noms = noms, lignes = lig, job = job)
}

# Images `container:` d'un workflow (lignes) : list(images, lignes, jobs, anomalie, ligne).
# `jobs` : les cles des jobs qui doivent porter chacun une ligne container: et eux seuls (#196 ;
# ci.yml : "tests" et "invariance", c'est-a-dire "Tests (R 4.3.3)" et "Invariance du bilan",
# meme chaine ; regenerer-references.yml : "candidat"). Anomalie, par ordre de priorite : ligne
# container: hors d'un job ou plus profonde que les cles de job ; ligne dans un job non attendu ;
# job attendu absent, sans ligne container: ou avec plusieurs ; image non epinglee par digest ;
# images differentes entre les lignes. `ligne` : la ligne fautive (la cle du job pour un job
# sans ligne container:, la deuxieme ligne d'un job qui en a plusieurs, la premiere ligne non
# epinglee, ou la premiere qui differe de la premiere image) ; NA sans anomalie ou sans ligne.
images_container <- function(lignes, jobs) {
  i <- grep("^\\s*container:\\s*", lignes)
  valeurs <- trimws(sub("^\\s*container:\\s*", "", lignes[i]))
  epinglee <- grepl(paste0("^", IMAGE, "$"), valeurs)
  st <- structure_jobs(lignes)
  job_i <- st$job[i]
  anomalie <- NA_character_
  ligne <- NA_integer_
  signaler <- function(message, l) if (is.na(anomalie)) {
    anomalie <<- message
    ligne <<- l
  }
  if (any(is.na(job_i))) signaler("ligne container: hors d'un job identifie (cle de job, indentation)", i[which(is.na(job_i))[1L]])
  inattendu <- !is.na(job_i) & !(job_i %in% jobs)
  if (any(inattendu)) signaler(paste0("ligne container: dans le job ", job_i[which(inattendu)[1L]], ", non attendu (attendus : ", paste(jobs, collapse = ", "), ")"), i[which(inattendu)[1L]])
  for (j in jobs) {
    n <- sum(job_i %in% j)
    if (!(j %in% st$noms)) signaler(paste0("job attendu ", j, " absent"), NA_integer_)
    else if (n == 0L) signaler(paste0("job ", j, " sans ligne container:, une attendue"), st$lignes[match(j, st$noms)])
    else if (n > 1L) signaler(paste0("job ", j, " : ", n, " lignes container:, une attendue"), i[which(job_i %in% j)[2L]])
  }
  if (!all(epinglee)) signaler(paste0("image non epinglee par digest : ", paste(valeurs[!epinglee], collapse = ", ")), i[which(!epinglee)[1L]])
  if (length(unique(valeurs)) > 1L) signaler(paste0("images differentes entre les lignes container: : ", paste(unique(valeurs), collapse = ", ")), i[which(valeurs != valeurs[1L])[1L]])
  list(images = unique(valeurs), lignes = i, jobs = job_i, anomalie = anomalie, ligne = ligne)
}

# Digest consigne par CONTEXT.md a l'entree "Plateforme de reference" (premiere image
# epinglee de l'entree) : l'entree s'etend du libelle jusqu'a la marque de gras suivante, la
# ligne vide suivante ou la ligne d'une autre entree (`- `, `#`) (#196).
digest_context <- function(texte) {
  debut <- regexpr("Plateforme de r\u00e9f\u00e9rence\\*\\*", texte)
  if (debut < 0L) return(NA_character_)
  suite <- substring(texte, debut + attr(debut, "match.length"))
  borne <- regexpr("\\*\\*|\n[ \t]*\n|\n[-#]", suite)
  entree <- if (borne > 0L) substring(suite, 1L, borne - 1L) else suite
  m <- regmatches(entree, regexpr(IMAGE, entree))
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
a <- images_container(lignes_ci, JOBS_CI)
b <- images_container(lignes_regen, JOBS_REGEN)
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
# Fichier minimal : un job par cle, une ligne container: par image donnee (NA : aucune).
wf <- function(jobs) {
  unlist(lapply(names(jobs), function(j) c(paste0("  ", j, ":"), "    runs-on: x", if (!is.na(jobs[[j]])) ligne_t(jobs[[j]]), "    steps:")), use.names = FALSE)
}
wf_ci <- function(...) c("jobs:", wf(list(...)))
J <- c("tests", "invariance")
if (is.na(images_container(ligne_t("rocker/r-ver:4.3.3"), "tests")$anomalie)) echec("temoin : image non epinglee admise")
if (is.na(images_container(c("jobs:", "  tests:", "    container: x", "    container: y"), "tests")$anomalie)) echec("temoin : deux lignes container: admises")
if (is.na(images_container(character(0), "tests")$anomalie)) echec("temoin : aucune ligne container: admise")
if (identical(images_container(c("jobs:", "  tests:", ligne_t(autre)), "tests")$images, img_t)) echec("temoin : digest different non vu")
if (is.na(images_container(c("jobs:", "  tests:", ligne_t(img_t), "    steps:", "  invariance:", ligne_t(img_t)), "tests")$anomalie)) echec("temoin : job non attendu admis")
if (!is.na(images_container(wf_ci(tests = img_t, invariance = img_t), J)$anomalie)) echec("temoin : deux jobs attendus, meme image, refuses")
if (is.na(images_container(wf_ci(tests = img_t, invariance = autre), J)$anomalie)) echec("temoin : deux images differentes admises")
# La ligne citee est la ligne fautive : premiere non epinglee, ou premiere qui differe.
if (!identical(images_container(c("jobs:", "  tests:", ligne_t(img_t), "  invariance:", "    container: rocker/r-ver:4.3.3"), J)$ligne, 5L)) echec("temoin : ligne fautive (non epinglee) mal citee")
if (!identical(images_container(c("jobs:", "  tests:", ligne_t(img_t), "  invariance:", ligne_t(autre)), J)$ligne, 5L)) echec("temoin : ligne fautive (digest different) mal citee")
if (!is.na(images_container(wf_ci(tests = img_t, invariance = img_t), J)$ligne)) echec("temoin : ligne citee sans anomalie")
# #196 : rattachement de la ligne container: a son job.
# (a) le container: du job "tests" deplace vers un job non attendu ("controles")
tmp <- images_container(c("jobs:", "  controles:", ligne_t(img_t), "  tests:", "    steps:", "  invariance:", ligne_t(img_t)), J)
if (is.na(tmp$anomalie) || !identical(tmp$ligne, 3L)) echec("temoin : container: du job tests deplace vers un autre job admis ou mal cite")
# (b) l'une des deux lignes container: de ci.yml supprimee
tmp <- images_container(c("jobs:", "  tests:", "    steps:", "  invariance:", ligne_t(img_t)), J)
if (is.na(tmp$anomalie) || !identical(tmp$ligne, 2L)) echec("temoin : job tests sans ligne container: admis ou mal cite")
tmp <- images_container(c("jobs:", "  tests:", ligne_t(img_t)), J)
if (is.na(tmp$anomalie)) echec("temoin : job invariance absent admis")
# (c) deux lignes container: dans un meme job
tmp <- images_container(c("jobs:", "  tests:", ligne_t(img_t), ligne_t(img_t), "  invariance:", ligne_t(img_t)), J)
if (is.na(tmp$anomalie) || !identical(tmp$ligne, 4L)) echec("temoin : deux lignes container: dans un job admises ou mal citees")
# (d) container: plus profond que les cles du job, ou hors de `jobs:`
tmp <- images_container(c("jobs:", "  tests:", "    steps:", "      container: x", ligne_t(img_t)), "tests")
if (is.na(tmp$anomalie) || !identical(tmp$ligne, 4L)) echec("temoin : container: plus profond que les cles du job admis ou mal cite")
tmp <- images_container(c("container: x", "jobs:", "  tests:", ligne_t(img_t)), "tests")
if (is.na(tmp$anomalie) || !identical(tmp$ligne, 1L)) echec("temoin : container: hors de jobs: admis ou mal cite")
# Une cle de job commentee ou une ligne de commentaire ne rattache rien.
tmp <- images_container(c("jobs:", "  tests:", "    # container: x", ligne_t(img_t)), "tests")
if (!is.na(tmp$anomalie)) echec("temoin : commentaire entre la cle du job et container: refuse")
if (!is.na(digest_context("aucune plateforme"))) echec("temoin : CONTEXT.md sans entree lu comme un digest")
# #196 : digest lu dans l'entree seule.
if (!identical(digest_context(paste0("- **Plateforme de r\u00e9f\u00e9rence** : `", img_t, "`\n- **Autre** : x")), img_t)) echec("temoin : digest de l'entree non lu")
if (!is.na(digest_context(paste0("- **Plateforme de r\u00e9f\u00e9rence** : sans image\n- **Autre** : `", autre, "`")))) echec("temoin : digest d'une autre entree (ligne suivante) lu")
if (!is.na(digest_context(paste0("- **Plateforme de r\u00e9f\u00e9rence** : sans image **Autre** : `", autre, "`")))) echec("temoin : digest apres une marque de gras, meme ligne, lu")
if (!is.na(digest_context(paste0("- **Plateforme de r\u00e9f\u00e9rence** : sans image\n\nsuite `", autre, "`")))) echec("temoin : digest apres une ligne vide lu")
if (.n_echec == avant) ok("temoins negatifs refuses (image non epinglee, ligne container: hors de son job, job attendu sans ligne ou avec deux, digest different, digest hors de l'entree de CONTEXT.md)")
fin()
