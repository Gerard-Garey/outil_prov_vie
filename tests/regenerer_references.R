# Production d'un candidat de références de non-régression (ADR 0011, points 16 à 20 et 22).
# Lancé par le workflow de régénération (.github/workflows/regenerer-references.yml) seul, sur la
# plateforme de référence : Rscript tests/regenerer_references.R <dossier de sortie>
# Garde-fous (point 17) : refuse de tourner hors de GitHub Actions (GITHUB_ACTIONS = "true" et
# PROVIE_REGENERATION = "1", posées par le workflow) ; n'écrit jamais sous tests/reference/ ;
# pour chaque couple de COUPLES_REFERENCE (tests/references.R), calcule deux fois et refuse
# d'écrire si les deux résultats ne sont pas identical (empreinte comprise) ou si l'appel se
# termine par un refus ; rejoue la fiche écrite puis relue et refuse si le rejeu diffère.
# Écrit l'arbre entier dans le dossier de sortie : <données>/<plan>/<arrêté>/resultat.txt et
# fiche.txt, provenance.txt, empreintes.md5 ; et, à côté de l'arbre (sous-dossier `rapport`,
# hors de l'arbre à placer sous tests/reference/) : resume.md (totaux par garantie et par
# référentiel, tableau avant / après contre l'arbre commité, empreinte de l'arbre, plateforme)
# et message_commit.txt (squelette du message du commit de référence, point 20).
# Ce refus est une barrière contre l'erreur, pas contre la fraude : la règle « aucune
# régénération sur un poste » reste celle de CLAUDE.md.

options(warn = 2)
fichier <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
racine <- normalizePath(file.path(dirname(fichier), ".."), mustWork = TRUE)
arguments <- commandArgs(TRUE)
arreter <- function(message) {
  cat("[ECHEC] regenerer_references.R : ", message, "\n", sep = "")
  quit(save = "no", status = 1L)
}
if (!identical(Sys.getenv("GITHUB_ACTIONS"), "true") || !identical(Sys.getenv("PROVIE_REGENERATION"), "1")) {
  arreter("hors du workflow de r\u00e9g\u00e9n\u00e9ration (GITHUB_ACTIONS et PROVIE_REGENERATION absents) : aucune r\u00e9g\u00e9n\u00e9ration sur un poste")
}
if (length(arguments) != 1L) arreter("un argument attendu : le dossier de sortie")
sortie <- normalizePath(arguments[1L], mustWork = FALSE)
if (startsWith(paste0(sortie, "/"), paste0(file.path(racine, "tests", "reference"), "/"))) {
  arreter("le dossier de sortie ne peut pas \u00eatre sous tests/reference/")
}
if (dir.exists(sortie) && length(list.files(sortie, all.files = TRUE, no.. = TRUE)) > 0L) arreter("dossier de sortie non vide")
arbre <- file.path(sortie, "arbre")
rapport <- file.path(sortie, "rapport")
dir.create(arbre, recursive = TRUE)
dir.create(rapport, recursive = TRUE)

source(file.path(racine, "tests", "harnais.R"))
installer_provie(racine)
source(file.path(racine, "tests", "references.R"))
ns <- asNamespace("provie")

resultats <- list()
ecarts <- list()
for (i in seq_len(nrow(COUPLES_REFERENCE))) {
  chemin <- chemin_couple(i)
  e <- entrees_couple(i)
  r1 <- tryCatch(calculer_couple(e), refus_provie = function(x) arreter(paste0(chemin, " : refus ", x$motif, " : ",
                                                                                conditionMessage(x))))
  r2 <- calculer_couple(e)
  if (!identical(r1, r2)) arreter(paste0(chemin, " : deux calculs non identiques (E4.6)"))
  rj <- rejouer_fiche(e$base, lire_fiche(ecrire_fiche(r1$fiche)), e$tables)
  if (!identical(rj$resultat, r1)) arreter(paste0(chemin, " : le rejeu de la fiche diff\u00e8re du calcul"))
  resultats[[chemin]] <- r1
  # avant / après contre l'arbre commité
  fr <- file.path(DOSSIER_REFERENCES, chemin, "resultat.txt")
  ff <- file.path(DOSSIER_REFERENCES, chemin, "fiche.txt")
  ecarts[chemin] <- list(if (file.exists(fr) && file.exists(ff)) comparer_couple(r1, lire_fichier(fr), lire_fichier(ff)) else NULL)
}

plateforme <- ns$decrire_plateforme()
provenance <- list(version_references = VERSION_REFERENCES, commit = Sys.getenv("GITHUB_SHA"),
                   run = Sys.getenv("GITHUB_RUN_ID"), tentative = Sys.getenv("GITHUB_RUN_ATTEMPT"),
                   image = Sys.getenv("PROVIE_IMAGE"), plateforme = plateforme, couples = names(resultats))
empreinte_arbre <- ecrire_arbre_references(resultats, arbre, provenance)

# résumé du run et squelette du message du commit de référence (tests/references.R)
lignes <- resume_candidat(resultats, ecarts, provenance, empreinte_arbre)
writeLines(enc2utf8(lignes), file.path(rapport, "resume.md"), useBytes = TRUE)
commites <- if (dir.exists(DOSSIER_REFERENCES)) {
  unique(dirname(list.files(DOSSIER_REFERENCES, pattern = "^resultat\\.txt$", recursive = TRUE)))
} else character(0)
url_run <- paste0(Sys.getenv("GITHUB_SERVER_URL"), "/", Sys.getenv("GITHUB_REPOSITORY"), "/actions/runs/", provenance$run)
writeLines(enc2utf8(message_commit_candidat(resultats, ecarts, provenance, empreinte_arbre, commites, url_run)),
           file.path(rapport, "message_commit.txt"), useBytes = TRUE)
cat(lignes, sep = "\n")
cat("\n[OK] candidat \u00e9crit dans ", arbre, "\n", sep = "")
