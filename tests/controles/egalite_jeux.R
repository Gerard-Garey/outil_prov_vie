# Controle : egalite de deux jeux versionnes (ou de deux bases ecrites par ecrire_base()) a
# travers un changement de version du dictionnaire ou du simulateur (#60, commit 60a ; erratum
# du projet de dictionnaire 1.6, section 11.10 ; plan de 0c, point (7), M674, M677, M678). Principe 7
# de CLAUDE.md : un controle mecanique est un script.
# Compare un dossier ancien et un dossier nouveau, fichier par fichier et cellule par cellule,
# en texte (aucune lecture par provie : les anciens jeux sont d'une version du dictionnaire que
# le moteur ne lit plus). Exceptions fermees, toute autre difference est un [ECHEC] :
#   - colonne garanties_souscrites.maintien_deces de base/garanties_souscrites.csv (ou
#     garanties_souscrites.csv) : ajoutee dans le nouveau, absente de l'ancien ; les autres
#     colonnes, dans le meme ordre, et toutes leurs cellules sont identiques ; ses valeurs sont
#     decomptees en ligne [INFO] ;
#   - cellule extraction.version_dictionnaire (fichier extraction.csv), seule cellule de ce
#     fichier admise a differer ;
#   - manifeste.txt : champs nom, version_dictionnaire, version_provie, version_simulateur et
#     date_visa ; champ description admis a differer seulement s'il est egal a l'ancien apres
#     substitution des noms des jeux selon M678 (v1-modeste-01 -> 04, 02 -> 05, 03 -> 06 ;
#     decision du mainteneur, Q1 option (b) restreinte), toute autre difference de description
#     etant un [ECHEC] ; tout autre champ identique, dans le meme ordre ;
#   - empreintes.md5 : lignes des seuls fichiers admis a differer (manifeste.txt,
#     extraction.csv, garanties_souscrites.csv), meme ordre et memes noms de fichiers ;
#   - tout autre fichier (loi_vraie.txt, declarations.txt, verite/*.csv, autres tables de base/)
#     identique a l'octet ; meme ensemble de fichiers des deux cotes.
# Un champ CSV est lu tel qu'ecrit (guillemets compris) : "" et une cellule vide restent
# distincts. Une ligne CSV a guillemets non refermes (champ sur plusieurs lignes) n'est pas
# prise en charge : [ECHEC] (cote sur).
# Usage, depuis la racine du depot :
#   Rscript tests/controles/egalite_jeux.R <ancien> <nouveau> [<ancien> <nouveau> ...]
# (anciens jeux : git archive a5e8970 inst/extdata/jeux | tar -x -C <dossier>). Avec un seul
# argument (la racine, comme le lance tests/test_unitaires.R) ou aucun, le script execute ses
# temoins integres (jeux synthetiques ecrits dans un dossier temporaire) : un couple conforme
# passe, chaque ecart hors exceptions est vu.
# Sortie : lignes [OK] / [ECHEC] / [INFO] ; statut 1 au moindre [ECHEC].
# Code ASCII (caracteres non ASCII en \uXXXX), R de base seulement.

options(warn = 2)
.arguments <- commandArgs(trailingOnly = TRUE)
.n_echec <- 0L
ecrire <- function(texte) writeLines(enc2utf8(texte), useBytes = TRUE)
ok <- function(message) ecrire(paste0("[OK] ", message))
info <- function(message) ecrire(paste0("[INFO] ", message))
echec <- function(message) {
  .n_echec <<- .n_echec + 1L
  ecrire(paste0("[ECHEC] ", message))
}

COLONNE_AJOUTEE <- c(fichier = "garanties_souscrites.csv", colonne = "maintien_deces")
CELLULE_VERSION <- c(fichier = "extraction.csv", colonne = "version_dictionnaire")
CHAMPS_MANIFESTE <- c("nom", "version_dictionnaire", "version_provie", "version_simulateur", "date_visa")
# Exception fermee du champ description : noms des jeux substitues selon M678 (Q1 (b) restreinte).
CHAMP_DESCRIPTION <- "description"
NOMS_M678 <- c("v1-modeste-01" = "v1-modeste-04", "v1-modeste-02" = "v1-modeste-05", "v1-modeste-03" = "v1-modeste-06")
# Substitution des noms de NOMS_M678 dans `x` (nom entier : non suivi d'un chiffre) ; les noms
# d'arrivee ne sont pas des noms de depart, l'ordre des substitutions est indifferent.
substituer_m678 <- function(x) {
  for (n in names(NOMS_M678)) x <- gsub(paste0(n, "(?![0-9])"), NOMS_M678[[n]], x, perl = TRUE)
  x
}
FICHIERS_ADMIS <- c("manifeste.txt", COLONNE_AJOUTEE[["fichier"]], CELLULE_VERSION[["fichier"]])

# Champs bruts d'une ligne CSV (virgule, guillemets doubles, "" dans un champ entre guillemets) ;
# NULL si les guillemets ne se referment pas sur la ligne.
champs_csv <- function(ligne) {
  if (sum(utf8ToInt(ligne) == 34L) %% 2L != 0L) return(NULL)
  m <- gregexpr('("([^"]|"")*"|[^,"]*)(,|$)', ligne, perl = TRUE)[[1L]]
  x <- regmatches(ligne, list(m))[[1L]]
  x <- sub(",$", "", x)
  # une virgule finale ouvre un dernier champ vide, sans correspondance propre
  if (endsWith(ligne, ",")) x <- c(x, "")
  # cote sur : les champs rejoints redonnent la ligne, sinon elle n'est pas prise en charge
  # (guillemet dans un champ sans guillemets, par exemple)
  if (!identical(paste(x, collapse = ","), ligne)) return(NULL)
  x
}

lire_lignes <- function(chemin) {
  octets <- readBin(chemin, "raw", n = file.info(chemin)$size)
  texte <- rawToChar(octets)
  Encoding(texte) <- "UTF-8"
  l <- strsplit(texte, "\n", fixed = TRUE)[[1L]]
  l
}

# Compare deux CSV cellule par cellule ; `ajoutee` : nom d'une colonne admise dans le nouveau
# seulement ; `cellule` : nom d'une colonne dont les cellules peuvent differer. Rend les messages
# d'echec (vecteur) ; attribut `info`.
comparer_csv <- function(a, b, nom, ajoutee = NA_character_, cellule = NA_character_) {
  la <- lire_lignes(a)
  lb <- lire_lignes(b)
  messages <- character(0)
  if (length(la) != length(lb)) return(sprintf("%s : %d lignes contre %d", nom, length(la), length(lb)))
  ta <- lapply(la, champs_csv)
  tb <- lapply(lb, champs_csv)
  multi <- which(vapply(ta, is.null, NA) | vapply(tb, is.null, NA))
  if (length(multi)) return(sprintf("%s:%d : guillemets non refermes sur la ligne (non pris en charge)", nom, multi[1L]))
  entete_a <- ta[[1L]]
  entete_b <- tb[[1L]]
  garder_b <- seq_along(entete_b)
  info <- NULL
  if (!is.na(ajoutee)) {
    j <- which(entete_b == ajoutee)
    if (length(j) != 1L || ajoutee %in% entete_a) {
      return(sprintf("%s : colonne %s attendue dans le nouveau seulement, une fois", nom, ajoutee))
    }
    garder_b <- garder_b[-j]
    valeurs <- vapply(tb[-1L], function(z) if (length(z) >= j) z[j] else "<absente>", "")
    t <- table(factor(valeurs, levels = unique(valeurs)))
    info <- sprintf("%s : colonne %s ajoutee, %d lignes : %s", nom, ajoutee, length(valeurs),
                    paste(sprintf("%s = %d", ifelse(names(t) == "", "<vide>", names(t)), as.integer(t)), collapse = ", "))
  }
  if (!identical(entete_a, entete_b[garder_b])) {
    return(c(messages, sprintf("%s:1 : en-tetes differents hors colonne ajoutee", nom)))
  }
  libre <- if (is.na(cellule)) integer(0) else which(entete_a == cellule)
  n_cellules <- 0L
  for (i in seq_along(ta)[-1L]) {
    x <- ta[[i]]
    y <- tb[[i]]
    if (length(y) != length(entete_b) || length(x) != length(entete_a)) {
      messages <- c(messages, sprintf("%s:%d : nombre de champs different de l'en-tete", nom, i))
      next
    }
    y <- y[garder_b]
    d <- which(x != y)
    d <- setdiff(d, libre)
    n_cellules <- n_cellules + length(x)
    for (k in utils::head(d, 5L)) {
      messages <- c(messages, sprintf("%s:%d, colonne %s : %s contre %s", nom, i, entete_a[k], x[k], y[k]))
    }
  }
  attr(messages, "info") <- c(info, sprintf("%s : %d cellules comparees, %d lignes de donnees", nom, n_cellules, length(ta) - 1L))
  messages
}

# Lignes d'un fichier provie-liste (manifeste.txt) : en-tete, puis cle<TAB>type<TAB>valeur.
comparer_manifeste <- function(a, b, nom) {
  la <- lire_lignes(a)
  lb <- lire_lignes(b)
  cle <- function(l) sub("\t.*$", "", l)
  ga <- la[!(cle(la) %in% CHAMPS_MANIFESTE)]
  gb <- lb[!(cle(lb) %in% CHAMPS_MANIFESTE)]
  # description de l'ancien comparee apres substitution des noms selon M678 (seule transformation
  # admise ; toute autre difference reste visible ci-dessous)
  d <- cle(ga) == CHAMP_DESCRIPTION
  substituee <- any(d) && !identical(ga[d], substituer_m678(ga[d]))
  ga[d] <- substituer_m678(ga[d])
  m <- character(0)
  if (!identical(cle(la), cle(lb))) m <- c(m, sprintf("%s : champs differents ou dans un autre ordre", nom))
  if (!identical(ga, gb)) {
    i <- which(ga[seq_len(min(length(ga), length(gb)))] != gb[seq_len(min(length(ga), length(gb)))])[1L]
    m <- c(m, sprintf("%s : champ hors exceptions different (%s)", nom, if (is.na(i)) "longueur" else cle(ga[i])))
  }
  attr(m, "info") <- c(sprintf("%s : champs differents (exceptions) : %s", nom,
                               paste(cle(la)[cle(la) %in% CHAMPS_MANIFESTE & !(la %in% lb)], collapse = ", ")),
                       if (substituee) sprintf("%s : description de l'ancien comparee apres substitution des noms (M678) : %s", nom,
                                               paste(unique(regmatches(la[cle(la) == CHAMP_DESCRIPTION],
                                                                       gregexpr("v1-modeste-0[123](?![0-9])", la[cle(la) == CHAMP_DESCRIPTION],
                                                                                perl = TRUE))[[1L]]), collapse = ", ")))
  m
}

comparer_md5 <- function(a, b, nom) {
  la <- lire_lignes(a)
  lb <- lire_lignes(b)
  fichier <- function(l) substring(l, 35L)
  m <- character(0)
  if (!identical(fichier(la), fichier(lb))) return(sprintf("%s : fichiers listes differents", nom))
  libres <- basename(fichier(la)) %in% FICHIERS_ADMIS
  d <- which(la != lb & !libres)
  for (k in d) m <- c(m, sprintf("%s:%d : empreinte de %s differente", nom, k, fichier(la)[k]))
  attr(m, "info") <- sprintf("%s : %d lignes, differentes : %s", nom, length(la),
                             paste(fichier(la)[la != lb], collapse = ", "))
  m
}

# Compare deux dossiers ; rend list(echecs, infos).
comparer_dossiers <- function(ancien, nouveau) {
  fa <- sort(list.files(ancien, recursive = TRUE), method = "radix")
  fb <- sort(list.files(nouveau, recursive = TRUE), method = "radix")
  echecs <- character(0)
  infos <- character(0)
  if (!identical(fa, fb)) {
    echecs <- c(echecs, sprintf("fichiers differents : seulement dans l'ancien (%s), seulement dans le nouveau (%s)",
                                paste(setdiff(fa, fb), collapse = ", "), paste(setdiff(fb, fa), collapse = ", ")))
  }
  for (f in intersect(fa, fb)) {
    a <- file.path(ancien, f)
    b <- file.path(nouveau, f)
    r <- if (basename(f) == "manifeste.txt") {
      comparer_manifeste(a, b, f)
    } else if (basename(f) == "empreintes.md5") {
      comparer_md5(a, b, f)
    } else if (basename(f) == COLONNE_AJOUTEE[["fichier"]]) {
      comparer_csv(a, b, f, ajoutee = COLONNE_AJOUTEE[["colonne"]])
    } else if (basename(f) == CELLULE_VERSION[["fichier"]]) {
      comparer_csv(a, b, f, cellule = CELLULE_VERSION[["colonne"]])
    } else {
      oa <- readBin(a, "raw", n = file.info(a)$size)
      ob <- readBin(b, "raw", n = file.info(b)$size)
      if (identical(oa, ob)) character(0) else sprintf("%s : octets differents", f)
    }
    echecs <- c(echecs, as.vector(r))
    infos <- c(infos, attr(r, "info"))
  }
  list(echecs = echecs, infos = infos, fichiers = length(intersect(fa, fb)))
}

rapporter <- function(ancien, nouveau, etiquette = paste(ancien, "->", nouveau)) {
  r <- comparer_dossiers(ancien, nouveau)
  for (i in r$infos) info(paste0(etiquette, " : ", i))
  for (e in r$echecs) echec(paste0(etiquette, " : ", e))
  if (length(r$echecs) == 0L) ok(sprintf("%s : %d fichiers egaux hors exceptions fermees", etiquette, r$fichiers))
  invisible(r)
}

# --- Temoins integres --------------------------------------------------------------------

temoins <- function() {
  base <- tempfile("egalite-jeux-")
  ecrire_fichier <- function(dossier, f, lignes) {
    dir.create(dirname(file.path(dossier, f)), recursive = TRUE, showWarnings = FALSE)
    con <- file(file.path(dossier, f), "wb")
    on.exit(close(con))
    writeBin(charToRaw(paste0(paste(lignes, collapse = "\n"), "\n")), con)
  }
  jeu <- function(dossier, nouveau, alterer = NULL) {
    f <- list(
      "manifeste.txt" = c("provie-liste 1", paste0("nom\tcharacter\t", if (nouveau) "v1-x-02" else "v1-x-01"),
                          paste0("version_dictionnaire\tcharacter\t", if (nouveau) "1.6" else "1.5"),
                          "graines/population\tinteger\t1", paste0("date_visa\tdate\t", if (nouveau) "NA" else "2026-11-09"),
                          paste0("description\tcharacter\tm\u00eame jeu que ", if (nouveau) "v1-modeste-04" else "v1-modeste-01",
                                 " ; graines de ", if (nouveau) "v1-modeste-05" else "v1-modeste-02", ", nom v1-modeste-010 gard\u00e9")),
      "loi_vraie.txt" = c("provie-liste 1", "version\tinteger\t1"),
      "declarations.txt" = c("provie-liste 1"),
      "base/extraction.csv" = c("date_extraction,version_dictionnaire,devise",
                                paste0("2025-12-31,\"", if (nouveau) "1.6" else "1.5", "\",\"EUR\"")),
      "base/garanties_souscrites.csv" = if (nouveau) c("id,code,taux,maintien_deces,clause", "\"G1\",\"deces\",,FALSE,\"a, b\"",
                                                       "\"G2\",\"deces\",0.02,,\"\"") else
        c("id,code,taux,clause", "\"G1\",\"deces\",,\"a, b\"", "\"G2\",\"deces\",0.02,\"\""),
      "verite/flux_futurs.csv" = c("id,montant", "\"F1\",1.5"))
    if (!is.null(alterer)) f <- alterer(f)
    for (n in names(f)) ecrire_fichier(dossier, n, f[[n]])
    md5 <- vapply(sort(names(f), method = "radix"), function(n) {
      paste0(unname(tools::md5sum(file.path(dossier, n))), "  ", n)
    }, "")
    ecrire_fichier(dossier, "empreintes.md5", md5)
    dossier
  }
  ancien <- jeu(file.path(base, "ancien"), FALSE)
  passe <- function(nom, alterer, attendu_echec) {
    nouveau <- jeu(file.path(base, nom), TRUE, alterer)
    r <- comparer_dossiers(ancien, nouveau)
    vu <- length(r$echecs) > 0L
    if (vu == attendu_echec) {
      ok(sprintf("temoin %s : %s", nom, if (attendu_echec) paste0("ecart vu (", r$echecs[1L], ")") else "egal hors exceptions"))
    } else {
      echec(sprintf("temoin %s : %s", nom, if (attendu_echec) "ecart non vu" else paste(r$echecs, collapse = " ; ")))
    }
  }
  passe("conforme", NULL, FALSE)
  passe("cellule", function(f) { f$`verite/flux_futurs.csv`[2L] <- "\"F1\",1.6"; f }, TRUE)
  passe("cellule_garanties", function(f) { f$`base/garanties_souscrites.csv`[3L] <- "\"G2\",\"deces\",0.03,,\"\""; f }, TRUE)
  passe("chaine_vide_contre_manquant", function(f) { f$`base/garanties_souscrites.csv`[3L] <- "\"G2\",\"deces\",0.02,,"; f }, TRUE)
  passe("autre_colonne_ajoutee", function(f) {
    f$`base/garanties_souscrites.csv` <- c("id,code,taux,autre,clause", "\"G1\",\"deces\",,FALSE,\"a, b\"", "\"G2\",\"deces\",0.02,,\"\"")
    f
  }, TRUE)
  passe("extraction_autre_cellule", function(f) { f$`base/extraction.csv`[2L] <- "2025-12-30,\"1.6\",\"EUR\""; f }, TRUE)
  passe("manifeste_graine", function(f) { f$`manifeste.txt`[4L] <- "graines/population\tinteger\t2"; f }, TRUE)
  # description : une autre difference que la substitution M678 est vue (mot ajoute ; nom substitue
  # hors M678 ; nom de depart garde ; nom a chiffre suivant substitue)
  desc <- function(texte) function(f) { f$`manifeste.txt`[6L] <- paste0("description\tcharacter\t", texte); f }
  passe("description_mot_ajoute", desc("m\u00eame jeu que v1-modeste-04 ; graines de v1-modeste-05, nom v1-modeste-010 gard\u00e9 (ajout)"), TRUE)
  passe("description_hors_m678", desc("m\u00eame jeu que v1-modeste-05 ; graines de v1-modeste-05, nom v1-modeste-010 gard\u00e9"), TRUE)
  passe("description_non_substituee", desc("m\u00eame jeu que v1-modeste-01 ; graines de v1-modeste-05, nom v1-modeste-010 gard\u00e9"), TRUE)
  passe("description_prefixe", desc("m\u00eame jeu que v1-modeste-04 ; graines de v1-modeste-05, nom v1-modeste-040 gard\u00e9"), TRUE)
  passe("loi_vraie", function(f) { f$`loi_vraie.txt`[2L] <- "version\tinteger\t2"; f }, TRUE)
  passe("fichier_en_plus", function(f) { f$`verite/autre.csv` <- "x"; f }, TRUE)
  passe("ligne_en_moins", function(f) { f$`verite/flux_futurs.csv` <- f$`verite/flux_futurs.csv`[1L]; f }, TRUE)
  unlink(base, recursive = TRUE)
}

if (length(.arguments) >= 2L) {
  if (length(.arguments) %% 2L != 0L) {
    echec("arguments : couples <ancien> <nouveau> attendus")
  } else {
    for (k in seq(1L, length(.arguments), by = 2L)) {
      a <- normalizePath(.arguments[k], mustWork = FALSE)
      b <- normalizePath(.arguments[k + 1L], mustWork = FALSE)
      if (!dir.exists(a) || !dir.exists(b)) {
        echec(sprintf("dossier absent : %s ou %s", .arguments[k], .arguments[k + 1L]))
        next
      }
      rapporter(a, b, paste(basename(a), "->", basename(b)))
    }
  }
} else {
  temoins()
}
quit(save = "no", status = if (.n_echec > 0L) 1L else 0L)
