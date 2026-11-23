# Controle : tableau avant / apres de references de non-regression a travers un renommage des
# donnees des couples (#60, commit 60a ; plan de 0c, point (7) ; ADR 0011, points 10 et 22) :
# version du dictionnaire ou du simulateur qui renomme les jeux et la base construite, chaque
# couple changeant de chemin <donnees>/<plan>/<arrete> sans changer de definition. Sert au visa
# de la regeneration qui suit (arbre commite contre candidat du run) ; resservira a chaque
# version du dictionnaire ou du simulateur. Principe 7 de CLAUDE.md : un controle mecanique est
# un script.
# Une seule implementation du comparateur : comparer_feuilles() de tests/harnais.R ; cles
# d'alignement, feuilles exclues de la fiche, tolerance et visa requis lus dans
# tests/references.R (CLES_PROVISIONS, CLES_DOSSIERS, EXCLUSIONS_FICHE, EPS_REFERENCE,
# visa_requis : definitions evaluees seules, sans sourcer le reste du fichier, qui demande le
# package installe). Les fichiers sont relus par lire_liste() du module outils (R/outils.R,
# source dans un environnement : le module n'appelle aucun autre module), sans installer provie.
# Pour chaque correspondance, compare <avant>/resultat.txt et <avant>/fiche.txt a ceux de
# <apres>, comme comparer_couple() (resultat : provisions et dossiers alignes sur leurs cles ;
# fiche hors EXCLUSIONS_FICHE) ; une ligne par ecart (chemin, cle, reference, obtenu, ecart,
# nature, visa requis), puis le decompte des ecarts sous provisions/ et de ceux qui demandent le
# visa du mainteneur.
# Limites connues (#140 ; chacune mesuree sur une copie de tests/reference/) :
#   - seuls resultat.txt et fiche.txt d'un couple sont lus : un fichier ajoute dans le dossier
#     du couple (extra.txt, rapport.html) passe ; un dossier est un couple si et seulement s'il
#     porte un resultat.txt : un dossier de fiche.txt seule, des deux cotes, n'est ni compare
#     ni signale (un couple de moins au total) ; un resultat.txt sans fiche.txt arrete le
#     script sur une erreur R ("cannot open file", statut 1), sans ligne [ECHEC], apres les
#     couples deja imprimes ;
#   - les dossiers dont le nom commence par un point ne sont pas parcourus : les couples sous
#     .v1-modeste-06/, des deux cotes, ne sont ni compares ni signales (deux couples de moins au
#     total) ;
#   - un ecart sous la tolerance EPS_REFERENCE x max(1, |reference|) n'est pas liste (+1e-11
#     sur un montant nul : 0 ecart ; +1e-9 : 1 ecart) ;
#   - le statut ne dit rien des ecarts : un ecart de valeur donne la ligne [OK] de tableau et
#     le statut 0 ; le visa se lit dans le tableau ;
#   - un arbre absent (normalizePath), ou un seul argument qui n'est pas une racine du depot
#     (tests/harnais.R absent), arrete le script sur une erreur R, statut 1, sans ligne [ECHEC] ;
#   - la cle d'alignement s'ecrit avec "|" entre ses composantes : une ligne du tableau se
#     coupe en plus de sept colonnes sur "|".
# Usage, depuis la racine du depot :
#   Rscript tests/controles/references_renommees.R <arbre avant> <arbre apres> <avant>=<apres>...
# Une correspondance designe deux couples (<donnees>/<plan>/<arrete>), ou deux noms de donnees
# (v1-modeste-01=v1-modeste-04 : chaque couple de l'arbre avant sous ce nom, au meme plan et au
# meme arrete dans l'arbre apres). Chaque couple de l'un et l'autre arbre doit etre couvert
# (correspondance, ou meme chemin des deux cotes) : sinon [ECHEC]. Un ecart n'est pas un echec :
# le tableau est la sortie. Avec un seul argument (la racine, comme le lance
# tests/test_unitaires.R) ou aucun, le script execute ses temoins integres sur l'arbre commite
# tests/reference/ (copie renommee egale ; valeur alteree vue ; couple sans correspondance vu).
# Sortie : lignes [OK] / [ECHEC] / [INFO] et tableau ; statut 1 au moindre [ECHEC].
# Code ASCII (caracteres non ASCII en \uXXXX), R de base seulement.

options(warn = 2)
.fichier_script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
.arguments <- commandArgs(trailingOnly = TRUE)
racine <- normalizePath(if (length(.arguments) == 1L) .arguments[1L]
                        else file.path(dirname(.fichier_script), "..", ".."), mustWork = TRUE)
.n_echec <- 0L
ecrire <- function(texte) writeLines(enc2utf8(texte), useBytes = TRUE)
ok <- function(message) ecrire(paste0("[OK] ", message))
info <- function(message) ecrire(paste0("[INFO] ", message))
echec <- function(message) {
  .n_echec <<- .n_echec + 1L
  ecrire(paste0("[ECHEC] ", message))
}

# comparer_feuilles() et ses auxiliaires (le harnais tient ses propres compteurs, non lus ici)
source(file.path(racine, "tests", "harnais.R"))
# lire_liste() et ecrire_liste() du module outils
.outils <- new.env(parent = baseenv())
sys.source(file.path(racine, "R", "outils.R"), envir = .outils)
# definitions de tests/references.R lues par le comparateur, et elles seules
local({
  noms <- c("CLES_PROVISIONS", "CLES_DOSSIERS", "EXCLUSIONS_FICHE", "EPS_REFERENCE", "visa_requis")
  for (e in parse(file.path(racine, "tests", "references.R"), keep.source = FALSE)) {
    if (is.call(e) && identical(e[[1L]], as.name("<-")) && is.name(e[[2L]]) && as.character(e[[2L]]) %in% noms) {
      eval(e, envir = globalenv())
    }
  }
  manquants <- noms[!vapply(noms, exists, NA, envir = globalenv(), inherits = FALSE)]
  if (length(manquants)) {
    ecrire(paste0("[ECHEC] tests/references.R : definitions absentes : ", paste(manquants, collapse = ", ")))
    quit(save = "no", status = 1L)
  }
})

lire <- function(chemin) .outils$lire_liste(readBin(chemin, "raw", n = file.info(chemin)$size))
couples_de <- function(arbre) {
  f <- list.files(arbre, pattern = "^resultat\\.txt$", recursive = TRUE)
  sort(dirname(f), method = "radix")
}

# Ecarts d'un couple (avant, apres) : comme comparer_couple() de tests/references.R, sur deux
# arbres ecrits.
comparer_deux <- function(av, ap) {
  e1 <- comparer_feuilles(lire(file.path(ap, "resultat.txt")), lire(file.path(av, "resultat.txt")),
                          tables = list(provisions = CLES_PROVISIONS, dossiers = CLES_DOSSIERS))
  e2 <- comparer_feuilles(lire(file.path(ap, "fiche.txt")), lire(file.path(av, "fiche.txt")), exclusions = EXCLUSIONS_FICHE)
  if (nrow(e2) > 0L) e2$chemin <- paste0("fiche/", e2$chemin)
  e <- rbind(e1, e2)
  e$visa <- visa_requis(e)
  e
}

# Correspondances : data.frame (avant, apres) de chemins de couples ; NULL et [ECHEC] si une
# correspondance est mal formee ou si un couple n'est pas couvert (`signaler` FALSE : NULL seul,
# pour les temoins).
correspondances <- function(arbre_av, arbre_ap, specs, signaler = TRUE) {
  signal <- function(message) if (signaler) echec(message)
  ca <- couples_de(arbre_av)
  cp <- couples_de(arbre_ap)
  av <- character(0)
  ap <- character(0)
  for (s in specs) {
    m <- strsplit(s, "=", fixed = TRUE)[[1L]]
    if (length(m) != 2L || !all(nzchar(m))) { signal(paste0("correspondance mal formee : ", s)); return(NULL) }
    if (grepl("/", m[1L], fixed = TRUE)) {
      av <- c(av, m[1L])
      ap <- c(ap, m[2L])
    } else {
      sous <- ca[startsWith(ca, paste0(m[1L], "/"))]
      if (length(sous) == 0L) { signal(paste0("aucun couple de l'arbre avant sous ", m[1L])); return(NULL) }
      av <- c(av, sous)
      ap <- c(ap, paste0(m[2L], substring(sous, nchar(m[1L]) + 1L)))
    }
  }
  # couples de meme chemin des deux cotes, non nommes : compares tels quels
  memes <- setdiff(intersect(ca, cp), c(av, ap))
  av <- c(av, memes)
  ap <- c(ap, memes)
  manque_av <- setdiff(ca, av)
  manque_ap <- setdiff(cp, ap)
  absents <- c(setdiff(av, ca), setdiff(ap, cp))
  if (length(manque_av) || length(manque_ap) || length(absents) || anyDuplicated(av) || anyDuplicated(ap)) {
    signal(sprintf("correspondance non bijective : avant sans couple apres (%s), apres sans couple avant (%s), chemins absents (%s)",
                  paste(manque_av, collapse = ", "), paste(manque_ap, collapse = ", "), paste(absents, collapse = ", ")))
    return(NULL)
  }
  data.frame(avant = av, apres = ap, stringsAsFactors = FALSE)
}

# Tableau avant / apres ; rend la liste des ecarts par couple (invisible).
tableau <- function(arbre_av, arbre_ap, specs, imprimer = TRUE) {
  co <- correspondances(arbre_av, arbre_ap, specs, signaler = imprimer)
  if (is.null(co)) return(invisible(NULL))
  res <- list()
  for (i in seq_len(nrow(co))) {
    ec <- comparer_deux(file.path(arbre_av, co$avant[i]), file.path(arbre_ap, co$apres[i]))
    res[[paste(co$avant[i], "->", co$apres[i])]] <- ec
    if (!imprimer) next
    prov <- startsWith(ec$chemin, "provisions")
    info(sprintf("%s -> %s : %d ecarts, dont %d sous provisions/, %d au visa du mainteneur", co$avant[i], co$apres[i],
                 nrow(ec), sum(prov), sum(ec$visa == "mainteneur")))
    if (nrow(ec) > 0L) {
      ecrire(sprintf("| %s | %s | %s | %s | %s | %s | %s |", ec$chemin, ec$cle, ec$reference, ec$obtenu, ec$ecart, ec$nature,
                     ec$visa))
    }
  }
  if (imprimer) {
    tous <- do.call(rbind, res)
    info(sprintf("total : %d couples, %d ecarts, dont %d sous provisions/, %d au visa du mainteneur", nrow(co),
                 if (is.null(tous)) 0L else nrow(tous), if (is.null(tous)) 0L else sum(startsWith(tous$chemin, "provisions")),
                 if (is.null(tous)) 0L else sum(tous$visa == "mainteneur")))
    ok(sprintf("tableau avant / apres de %d couples", nrow(co)))
  }
  invisible(res)
}

# --- Temoins integres --------------------------------------------------------------------

temoins <- function() {
  arbre <- file.path(racine, "tests", "reference")
  ca <- couples_de(arbre)
  if (length(ca) == 0L) {
    info("tests/reference/ sans couple : temoins non executes")
    return(invisible(NULL))
  }
  c1 <- ca[1L]
  donnees <- sub("/.*$", "", c1)
  copie <- tempfile("references-renommees-")
  # arbre apres : tous les couples, ceux de `donnees` sous un nom renomme
  for (c2 in ca) {
    dest <- if (startsWith(c2, paste0(donnees, "/"))) paste0(donnees, "-renomme", substring(c2, nchar(donnees) + 1L)) else c2
    dir.create(file.path(copie, dest), recursive = TRUE)
    file.copy(file.path(arbre, c2, c("resultat.txt", "fiche.txt")), file.path(copie, dest))
  }
  spec <- paste0(donnees, "=", donnees, "-renomme")
  r <- tableau(arbre, copie, spec, imprimer = FALSE)
  if (!is.null(r) && all(vapply(r, nrow, 0L) == 0L)) ok(sprintf("temoin : copie renommee (%s) egale, %d couples", spec, length(r))) else
    echec("temoin : copie renommee non egale")
  # valeur alteree : premier montant de provision non manquant du premier couple renomme
  cible <- file.path(copie, paste0(donnees, "-renomme", substring(c1, nchar(donnees) + 1L)), "resultat.txt")
  x <- lire(cible)
  k <- which(!is.na(x$provisions$montant))[1L]
  x$provisions$montant[k] <- x$provisions$montant[k] * (1 + 1e-6) + 1
  con <- file(cible, "wb")
  writeBin(.outils$ecrire_liste(x), con)
  close(con)
  r <- tableau(arbre, copie, spec, imprimer = FALSE)
  ec <- if (is.null(r)) NULL else do.call(rbind, r)
  if (!is.null(ec) && any(startsWith(ec$chemin, "provisions") & ec$nature != "structure")) {
    ok(sprintf("temoin : montant altere vu (%s, visa %s)", ec$cle[1L], ec$visa[1L]))
  } else {
    echec("temoin : montant altere non vu")
  }
  # couple sans correspondance : arbre apres renomme, correspondance vers un nom absent
  r <- tableau(arbre, copie, paste0(donnees, "=", donnees, "-absent"), imprimer = FALSE)
  if (is.null(r)) ok("temoin : correspondance qui ne couvre pas les couples vue (non bijective)") else
    echec("temoin : correspondance qui ne couvre pas les couples non vue")
  unlink(copie, recursive = TRUE)
}

if (length(.arguments) >= 3L) {
  arbre_av <- normalizePath(.arguments[1L], mustWork = TRUE)
  arbre_ap <- normalizePath(.arguments[2L], mustWork = TRUE)
  info(sprintf("avant : %s ; apres : %s ; correspondances : %s", arbre_av, arbre_ap, paste(.arguments[-(1:2)], collapse = " ")))
  tableau(arbre_av, arbre_ap, .arguments[-(1:2)])
} else if (length(.arguments) == 2L) {
  echec("arguments : <arbre avant> <arbre apres> <avant>=<apres>... attendus")
} else {
  temoins()
}
quit(save = "no", status = if (.n_echec > 0L) 1L else 0L)
