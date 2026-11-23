# Controle : aucun caractere de controle dans les fichiers texte versionnes (issue #182 ;
# ADR 0010, point 26). Origine : un agent a ecrit un saut de page (U+000C) a la place de \f
# dans une macro LaTeX ; aucun controle mecanique ne le voyait (CLAUDE.md, "Workflows",
# principe 7 : tout controle mecanique est un script).
# Pour chaque fichier suivi du depot (git ls-files si la racine examinee est la racine d'un
# depot git, sinon toute l'arborescence hors .git/ et .claude/worktrees/), lu en octets : tout
# octet de 0x00 a 0x08, 0x0b, 0x0c et 0x0e a 0x1f est un [ECHEC] fichier:ligne, avec le point de
# code (U+00xx) et la colonne en octets. Admis : la tabulation (0x09), le saut de ligne (0x0a)
# et le retour chariot (0x0d, fin de ligne CRLF). Un octet nul est refuse comme les autres
# (un fichier texte n'en porte pas). Les lignes se comptent aux sauts de ligne 0x0a.
# Fichiers binaires : exclus par EXTENSIONS_BINAIRES ci-dessous, la seule justification etant
# celle-ci (leurs octets de controle sont leur contenu, non une faute de frappe) ; chaque
# exclusion presente dans le depot est signalee par une ligne [INFO]. Aucun fichier texte n'est
# exclu : le present script et ses temoins (tests/unitaires/controles.R) fabriquent leurs
# octets de controle (as.raw, "\f" ecrit avec sa barre inverse), jamais en clair.
# LIMITES (#182) :
#   - le controle porte sur les octets 0x00 a 0x1f ; il ne voit ni DEL (0x7f), ni les
#     caracteres de controle C1 (U+0080 a U+009F, octets C2 80 a C2 9F en UTF-8), ni les
#     caracteres invisibles ou de direction (U+200B, U+202E, U+2028...), ni un encodage
#     invalide ;
#   - le retour chariot (0x0d) est admis partout, y compris isole (hors CRLF) ;
#   - une extension binaire (liste ci-dessous) n'est pas examinee, quel que soit le contenu du
#     fichier qui la porte : un fichier texte renomme .pdf passerait ; un binaire d'une autre
#     extension serait refuse (il faut alors l'ajouter a la liste, avec sa raison) ;
#   - en dehors d'un depot git (copie de travail), les fichiers non suivis sont examines
#     aussi ; sous git, un fichier non suivi (ajoute avant "git add") ne l'est pas, le
#     controle du job "Controles du depot" portant sur ce qui sera versionne ;
#   - un lien symbolique n'est pas examine (sa cible peut etre hors du depot) : une ligne [INFO]
#     le signale ; en arborescence, list.files() parcourt pourtant un dossier lie : les fichiers
#     reels de ce dossier sont examines sous le chemin du lien (sous git, le lien de dossier est
#     un fichier suivi, ecarte) ; un fichier suivi mais absent de l'arbre de travail est signale
#     de meme ;
#   - la voie suivie est annoncee par une ligne [INFO] voie : ... ; si git est present mais ne
#     rend pas la liste (depot illisible), le controle bascule sur l'arborescence, ligne [INFO]
#     a l'appui, sans refus.
# Usage, depuis la racine du depot : Rscript tests/controles/caracteres_controle.R
# Un argument facultatif designe une autre racine (copie du depot, pour les temoins).
# Sortie : lignes [OK] / [INFO] / [ECHEC] fichier:ligne ; statut 1 au moindre [ECHEC].
# Code ASCII, R de base seulement.

options(warn = 2)
.fichier_script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
.arguments <- commandArgs(trailingOnly = TRUE)
racine <- normalizePath(if (length(.arguments) >= 1L) .arguments[1L]
                        else file.path(dirname(.fichier_script), "..", ".."), mustWork = TRUE)
.n_echec <- 0L
rel <- function(chemin) if (startsWith(chemin, paste0(racine, "/"))) substring(chemin, nchar(racine) + 2L) else chemin
ok <- function(message) cat("[OK] ", message, "\n", sep = "")
info <- function(message) cat("[INFO] ", message, "\n", sep = "")
echec <- function(message, chemin = NA_character_, ligne = NA_integer_) {
  .n_echec <<- .n_echec + 1L
  position <- if (is.na(chemin)) "" else paste0(rel(chemin), if (is.na(ligne)) "" else paste0(":", ligne), " ")
  cat("[ECHEC] ", position, message, "\n", sep = "")
}
fin <- function() quit(save = "no", status = if (.n_echec > 0L) 1L else 0L)

# --- Listes --------------------------------------------------------------------------

# Extensions de fichiers binaires, exclues de l'examen : images, documents compiles, classeurs,
# archives, donnees serialisees de R, polices. La liste comprend les cinq extensions que
# .gitattributes declare binary (pdf, xlsx, png, jpg, rds) ; les autres sont des formats
# binaires usuels qu'un depot de documentation ou de donnees peut recevoir.
EXTENSIONS_BINAIRES <- c("pdf", "png", "jpg", "jpeg", "gif", "ico", "xlsx", "xls", "rds",
                         "rda", "rdata", "zip", "gz", "tgz", "bz2", "xz", "7z",
                         "woff", "woff2", "ttf", "otf")
# Octets de controle refuses : 0x00-0x08, 0x0b, 0x0c, 0x0e-0x1f (admis : 0x09, 0x0a, 0x0d).
est_controle <- function(octets) {
  v <- as.integer(octets)
  v < 32L & !(v %in% c(9L, 10L, 13L))
}
MAX_LIGNES_PAR_FICHIER <- 20L

# --- Fichiers suivis -------------------------------------------------------------------

DOSSIERS_EXCLUS <- c(".git/", ".claude/worktrees/")
# Noms suivis par git, exacts : `git ls-files -z` (sortie lue en octets, decoupee sur \0). Sans -z,
# git met entre guillemets, avec echappements, les noms qui portent un guillemet, une tabulation,
# une barre inverse ou un saut de ligne ; file.exists() les ecartait ensuite sans message (#186).
# Rend NULL si git echoue ou si la sortie est tronquee (pas de \0 final).
noms_git <- function() {
  sortie <- tempfile("ls-files-")
  on.exit(unlink(sortie), add = TRUE)
  statut <- suppressWarnings(system2("git", c("-C", shQuote(racine), "ls-files", "-z"),
                                     stdout = sortie, stderr = FALSE))
  if (!identical(statut, 0L)) return(NULL)
  b <- readBin(sortie, "raw", n = file.size(sortie))
  if (!length(b)) return(character(0))
  fin <- which(b == as.raw(0L))
  if (!length(fin) || fin[length(fin)] != length(b)) return(NULL)
  debut <- c(1L, fin[-length(fin)] + 1L)
  vapply(seq_along(fin), function(i) rawToChar(b[debut[i]:(fin[i] - 1L)]), "")
}
# Voie suivie, annoncee par une ligne [INFO] : l'echec silencieux de git rev-parse (depot dont le
# proprietaire differe, par exemple) bascule sur l'arborescence ; le journal le dit.
VOIE <- "arborescence (git absent du PATH)"
# Fichiers suivis : git ls-files si `racine` est la racine d'un depot git, sinon l'arborescence.
fichiers_suivis <- function() {
  if (nzchar(Sys.which("git"))) {
    VOIE <<- "arborescence (racine hors d'un depot git, ou depot illisible par git)"
    haut <- suppressWarnings(system2("git", c("-C", shQuote(racine), "rev-parse", "--show-toplevel"),
                                     stdout = TRUE, stderr = FALSE))
    if (is.null(attr(haut, "status")) && length(haut) == 1L && normalizePath(haut) == racine) {
      liste <- noms_git()
      if (!is.null(liste)) {
        VOIE <<- "git ls-files"
        return(file.path(racine, liste))
      }
    }
  }
  tout <- list.files(racine, recursive = TRUE, all.files = TRUE, include.dirs = FALSE)
  exclu <- Reduce(`|`, lapply(DOSSIERS_EXCLUS, function(d) startsWith(tout, d)),
                  logical(length(tout)))
  file.path(racine, tout[!exclu])
}
fichiers <- fichiers_suivis()
info(paste0("voie : ", VOIE))
# Un lien symbolique n'est pas suivi : readBin() lirait sa cible, qui peut se trouver hors du
# depot (un lien vers un binaire donnerait des [ECHEC] a tort, un lien vers un dossier serait
# ignore sans message) ; chaque lien ecarte est signale.
cible_lien <- Sys.readlink(fichiers)     # "" : pas un lien ; NA : erreur (fichier absent)
lien <- !is.na(cible_lien) & nzchar(cible_lien)
for (f in vapply(fichiers[lien], rel, character(1), USE.NAMES = FALSE)) info(paste0(f, " : lien symbolique, cible non examinee"))
fichiers <- fichiers[!lien]
# Un fichier suivi mais absent de l'arbre de travail (supprime avant "git add") n'est pas lu ; chacun est signale.
absent <- !file.exists(fichiers)
for (f in vapply(fichiers[absent], rel, character(1), USE.NAMES = FALSE)) info(paste0(f, " : suivi mais absent de l'arbre de travail, non lu"))
fichiers <- fichiers[!absent & !dir.exists(fichiers)]
relatifs <- vapply(fichiers, rel, character(1), USE.NAMES = FALSE)
extension <- tolower(sub(".*\\.", "", basename(fichiers)))
extension[!grepl("\\.", basename(fichiers))] <- ""
binaire <- extension %in% EXTENSIONS_BINAIRES
for (f in relatifs[binaire]) info(paste0(f, " : binaire (extension exclue), non examine"))

# --- Examen -----------------------------------------------------------------------------

# Rend un data.frame (ligne, colonne, code) des octets de controle de `chemin`, dans l'ordre.
octets_de_controle <- function(chemin) {
  b <- readBin(chemin, "raw", n = file.size(chemin))
  position <- which(est_controle(b))
  if (!length(position)) return(NULL)
  nl <- which(b == as.raw(10L))                  # positions des sauts de ligne
  ligne <- 1L + findInterval(position, nl)       # sauts de ligne qui precedent l'octet, plus un
  debut <- c(0L, nl)[ligne]                      # position du saut de ligne qui ouvre la ligne (0 : debut)
  data.frame(ligne = ligne, colonne = position - debut, code = as.integer(b[position]))
}

examines <- 0L
for (i in which(!binaire)) {
  examines <- examines + 1L
  atteintes <- octets_de_controle(fichiers[i])
  if (is.null(atteintes)) next
  for (l in head(unique(atteintes$ligne), MAX_LIGNES_PAR_FICHIER)) {
    sur_la_ligne <- atteintes[atteintes$ligne == l, ]
    echec(paste0("caractere de controle ",
                 paste0("U+", sprintf("%04X", sur_la_ligne$code), " (colonne ", sur_la_ligne$colonne, ")",
                        collapse = ", ")),
          fichiers[i], l)
  }
  autres <- length(unique(atteintes$ligne)) - MAX_LIGNES_PAR_FICHIER
  if (autres > 0L) echec(paste0("... et ", autres, " autre(s) ligne(s) atteinte(s)"), fichiers[i])
}

if (examines == 0L) {
  echec("aucun fichier a examiner (liste vide : un controle qui ne lit rien ne prouve rien)")
} else if (.n_echec == 0L) {
  ok(paste0(examines, " fichier(s) texte examine(s), aucun caractere de controle (0x00-0x08, 0x0b, 0x0c, 0x0e-0x1f)"))
}
fin()
