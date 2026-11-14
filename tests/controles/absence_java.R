# Controle : aucune dependance a Java, directe ou indirecte (ADR 0004, point 6 ; ADR 0010,
# point 26 ; issue #12 ; #27). Trois verifications :
#   1. DESCRIPTION : aucun package connu pour dependre de Java dans Depends, Imports,
#      LinkingTo, Suggests, ni dans leur fermeture recursive parmi les packages installes
#      (nom de la liste ci-dessous, ou SystemRequirements qui cite Java, JDK ou JRE) ;
#      un package declare mais non installe est signale [AVERT] (fermeture non verifiable).
#   2. Tous les fichiers suivis du depot (git ls-files si la racine examinee est la racine d'un
#      depot git, sinon toute l'arborescence hors .git/ et .claude/worktrees/) dont l'extension
#      est R, r, Rmd, yml, yaml, sh, json, toml, lock ou js, ou dont le nom est NAMESPACE,
#      Dockerfile*, Makefile, .Rprofile, Rprofile.site, .Renviron, Renviron.site, Brewfile ou
#      Aptfile : aucun chargement d'un package de la liste (library(p), require(p),
#      requireNamespace("p"), loadNamespace("p"), `p::`, import(p), p dans packages /
#      extra-packages / needs, y compris en liste YAML sur plusieurs lignes, `any::p`,
#      `cran::p`, `github::.../p`, "p" en argument d'une installation), aucune installation ni
#      activation d'un environnement Java (setup-java, openjdk, default-jdk, default-jre,
#      JAVA_HOME, .jinit, .jcall). Un package a nom courant (xlsx) n'est refuse que dans ces
#      contextes : "library(openxlsx)  # lecture des feuilles xlsx" passe.
#      Fichiers R (.R, .r, NAMESPACE, .Rprofile) : analyses par getParseData() (commentaires
#      exclus par leurs jetons, un `#` dans une chaine ne masque rien ; premier argument,
#      positionnel ou nomme `package`, de library, require, requireNamespace, loadNamespace,
#      attachNamespace, tous les arguments de import ; tous les arguments des installations
#      install.packages, install_*, p_load, pkg_install, needs, pak, install, y compris sur
#      plusieurs lignes). Les autres fichiers : par ligne ; un `#` n'y ouvre un commentaire
#      (YAML, shell, Dockerfile, Makefile) que s'il commence un mot hors guillemets ; JSON,
#      lock et js : aucun commentaire retire (cote sur).
#      Exclusions, la seule justification etant celle-ci : le present script
#      (tests/controles/absence_java.R de la racine examinee), qui porte la liste ;
#      tests/controles/paquets_java_motifs.sh (#120, M360), fichier de motifs de noms de paquets
#      systeme qu'il INTERDIT (noms de JDK ecrits en clair : le balayage le prendrait pour
#      une installation d'environnement Java) ; son script, paquets_java.sh, reste balaye
#      (il ne cite aucun nom Java) ; .git/ et
#      .claude/worktrees/ (copies de travail, hors du depot suivi). Les temoins versionnes de
#      tests/unitaires/controles.R ne sont PAS exclus : ils fabriquent les noms interdits
#      (paste0("r", "Java")) et n'ecrivent jamais un nom interdit en clair ; ne pas elargir
#      les exclusions pour eux. La documentation (docs/) n'est balayee que par ses fichiers
#      de code (aucune extension de prose n'est dans la liste).
# PERIMETRE ET LIMITE (#120, #95 point 5) : le script controle les FICHIERS du depot, jamais
# les paquets SYSTEME (apt, dpkg) : un paquet Java installe par la CI ou par un hook passe ici
# sans bruit. Ce controle-la est celui de tests/controles/paquets_java.sh (difference des
# paquets installes avant / apres, par nom de paquet), appele par le job "Documents LaTeX"
# de .github/workflows/ci.yml et par .claude/hooks/installer_latex.sh ; il n'est pas lance
# par les batteries (ses temoins le sont : tests/unitaires/controles.R). Limite commune aux
# deux : un controle par nom ; un paquet Java d'un autre nom passe au travers.
# La liste est un jugement de mise en oeuvre (packages CRAN a Java notoirement requis) ; un
# ajout se fait ici, avec sa raison.
# Usage, depuis la racine du depot : Rscript tests/controles/absence_java.R
# Un argument facultatif designe une autre racine (copie du depot, pour les temoins).
# Sortie : lignes [OK] / [AVERT] / [ECHEC] fichier:ligne ; statut 1 au moindre [ECHEC].
# Code ASCII, R de base seulement.

options(warn = 2)
.fichier_script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
.arguments <- commandArgs(trailingOnly = TRUE)
racine <- normalizePath(if (length(.arguments) >= 1L) .arguments[1L]
                        else file.path(dirname(.fichier_script), "..", ".."), mustWork = TRUE)
.n_echec <- 0L
rel <- function(chemin) if (startsWith(chemin, paste0(racine, "/"))) substring(chemin, nchar(racine) + 2L) else chemin
ok <- function(message) cat("[OK] ", message, "\n", sep = "")
avert <- function(message) cat("[AVERT] ", message, "\n", sep = "")
echec <- function(message, chemin = NA_character_, ligne = NA_integer_) {
  .n_echec <<- .n_echec + 1L
  position <- if (is.na(chemin)) "" else paste0(rel(chemin), if (is.na(ligne)) "" else paste0(":", ligne), " ")
  cat("[ECHEC] ", position, message, "\n", sep = "")
}
fin <- function() quit(save = "no", status = if (.n_echec > 0L) 1L else 0L)

# --- Listes --------------------------------------------------------------------------

# Packages dont le nom designe sans ambiguite une dependance a Java : toute occurrence
# comme mot est un echec.
PAQUETS_JAVA_SANS_AMBIGUITE <- c("rJava", "xlsxjars", "XLConnectJars", "RWekajars",
                                 "tabulizerjars", "rcdklibs", "JavaGD")
# Packages a Java dont le nom est aussi un mot courant (xlsx est aussi une extension) :
# echec seulement dans un contexte de chargement ou d'installation (voir charge() plus bas).
PAQUETS_JAVA_EN_CONTEXTE <- c("xlsx", "XLConnect", "RWeka", "RJDBC", "tabulizer", "mailR",
                              "openNLP", "rcdk", "h2o", "J4R", "jdx")
PAQUETS_JAVA <- c(PAQUETS_JAVA_SANS_AMBIGUITE, PAQUETS_JAVA_EN_CONTEXTE)
# Environnement Java lui-meme.
MOTIFS_ENVIRONNEMENT_JAVA <- c("setup-java", "openjdk", "default-jdk", "default-jre",
                               "JAVA_HOME", "\\.jinit\\(", "\\.jcall\\(", "javareconf")

# --- 1. DESCRIPTION et fermeture recursive ---------------------------------------------
description <- file.path(racine, "DESCRIPTION")
if (!file.exists(description)) {
  echec("DESCRIPTION absent", description)
  fin()
}
dcf <- read.dcf(description, fields = c("Depends", "Imports", "LinkingTo", "Suggests",
                                        "SystemRequirements"))
declares <- unique(unlist(lapply(c("Depends", "Imports", "LinkingTo", "Suggests"), function(champ) {
  if (is.na(dcf[1L, champ])) return(character(0))
  noms <- trimws(sub("\\(.*$", "", strsplit(dcf[1L, champ], ",", fixed = TRUE)[[1L]]))
  noms[nzchar(noms) & noms != "R"]
})))
if (!is.na(dcf[1L, "SystemRequirements"]) &&
    grepl("\\b(Java|JDK|JRE)\\b", dcf[1L, "SystemRequirements"])) {
  echec("SystemRequirements cite Java", description)
}
installes <- installed.packages(fields = "SystemRequirements")
exigence_java <- function(nom) {
  exigence <- installes[nom, "SystemRequirements"]
  !is.na(exigence) && grepl("\\b(Java|JDK|JRE)\\b", exigence)
}
lignes_description <- readLines(description, warn = FALSE)
ligne_du_nom <- function(nom) {
  i <- grep(paste0("(^|[^A-Za-z0-9._])", gsub(".", "\\.", nom, fixed = TRUE), "($|[^A-Za-z0-9._])"),
            lignes_description)
  if (length(i) > 0L) i[1L] else NA_integer_
}
avant <- .n_echec
for (nom in declares) {
  if (nom %in% PAQUETS_JAVA) {
    echec(sprintf("`%s` depend de Java", nom), description, ligne_du_nom(nom))
  }
  if (!(nom %in% rownames(installes))) {
    avert(sprintf("DESCRIPTION : `%s` n'est pas installe, fermeture recursive non verifiable ici", nom))
    next
  }
  fermeture <- c(nom, tools::package_dependencies(nom, db = installes, recursive = TRUE,
                                                  which = c("Depends", "Imports", "LinkingTo"))[[1L]])
  fermeture <- setdiff(fermeture[!is.na(fermeture)], nom)
  for (p in fermeture) {
    if (p %in% PAQUETS_JAVA) {
      echec(sprintf("`%s` depend de Java (via `%s`)", nom, p), description, ligne_du_nom(nom))
    } else if (p %in% rownames(installes) && exigence_java(p)) {
      echec(sprintf("`%s` depend de Java (SystemRequirements de `%s`)", nom, p), description, ligne_du_nom(nom))
    }
  }
  if (exigence_java(nom)) {
    echec(sprintf("`%s` depend de Java (SystemRequirements)", nom), description, ligne_du_nom(nom))
  }
}
if (.n_echec == avant) {
  ok(sprintf("DESCRIPTION : aucune dependance a Java (%d package(s) declare(s), fermeture recursive des packages installes)",
             length(declares)))
}

# --- 2. Balayage des fichiers ------------------------------------------------------------
# DESCRIPTION est traitee plus haut (declarations) ; le present script et paquets_java_motifs.sh sont exclus par leur chemin
# relatif a la racine examinee (et non par celui du script qui tourne : sur une copie du
# depot, la copie du script serait sinon balayee).
EXCLUS <- c("tests/controles/absence_java.R", "tests/controles/paquets_java_motifs.sh")
DOSSIERS_EXCLUS <- c(".git/", ".claude/worktrees/")
EXTENSIONS <- "\\.(R|Rmd|yml|yaml|sh|json|toml|lock|js|dockerfile)$"
NOMS <- "^(NAMESPACE|Dockerfile(\\..*)?|Makefile|\\.Rprofile|Rprofile\\.site|\\.Renviron|Renviron\\.site|Brewfile|Aptfile)$"
NOMS_R <- "^(NAMESPACE|\\.Rprofile|Rprofile\\.site)$"
SANS_COMMENTAIRE <- "\\.(json|lock|js)$"  # aucun commentaire retire
# Fichiers suivis : git ls-files si `racine` est la racine d'un depot git, sinon l'arborescence.
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
fichiers <- fichiers_suivis()
fichiers <- fichiers[file.exists(fichiers)]
fichiers <- fichiers[grepl(EXTENSIONS, fichiers, ignore.case = TRUE) | grepl(NOMS, basename(fichiers))]
fichiers <- fichiers[!(vapply(fichiers, rel, character(1)) %in% EXCLUS) &
                       !Reduce(`|`, lapply(DOSSIERS_EXCLUS, function(d) startsWith(vapply(fichiers, rel, character(1)), d)))]

B <- "(^|[^A-Za-z0-9._])"
E <- "($|[^A-Za-z0-9._])"
CHARGEUR <- "(library|require|requireNamespace|loadNamespace|attachNamespace|import|importFrom)"
FONCTIONS_CHARGEMENT <- c("library", "require", "requireNamespace", "loadNamespace", "attachNamespace")
FONCTIONS_INSTALLATION <- c("install.packages", "install_version", "install_cran", "install_github",
                            "install_url", "p_load", "pkg_install", "needs", "pak", "install")
INSTALLATEUR <- paste0(B, "(", paste(gsub(".", "\\.", FONCTIONS_INSTALLATION, fixed = TRUE), collapse = "|"),
                       ")($|[^A-Za-z0-9_])")
LISTE_YAML <- "(extra-packages|packages|needs)[ \t]*[:=]"
PREFIXE_DEPOT <- "[A-Za-z]+::([^ \t,;\"']*/)?"   # any::p, cran::p, github::depot/p
# Contexte de chargement ou d'installation de `p` dans des lignes (ou des chaines) : vecteur.
charge <- function(p, lignes) {
  grepl(paste0(CHARGEUR, "[ \t]*\\([ \t]*(package[ \t]*=[ \t]*)?[\"']?", p, "[\"']?[ \t]*[,)]"), lignes) |
    grepl(paste0(B, p, ":::?"), lignes) |
    grepl(paste0(PREFIXE_DEPOT, p, E), lignes) |
    (grepl(INSTALLATEUR, lignes) & grepl(paste0("[\"']", p, "[\"']"), lignes)) |
    (grepl(LISTE_YAML, lignes) & grepl(paste0(B, p, E), lignes))
}
mot <- function(p) paste0(B, p, E)

# Commentaire d'une ligne de shell, YAML ou Dockerfile : un `#` ouvre un commentaire s'il
# commence un mot, hors guillemets.
sans_commentaire_mot <- function(ligne) {
  if (!grepl("#", ligne, fixed = TRUE)) return(ligne)
  car <- strsplit(ligne, "")[[1L]]
  guillemet <- ""
  saut <- FALSE
  for (k in seq_along(car)) {
    if (saut) { saut <- FALSE; next }
    if (nzchar(guillemet)) {
      if (car[k] == "\\" && guillemet == "\"") saut <- TRUE else if (car[k] == guillemet) guillemet <- ""
    } else if (car[k] %in% c("\"", "'")) {
      guillemet <- car[k]
    } else if (car[k] == "#" && (k == 1L || car[k - 1L] %in% c(" ", "\t"))) {
      return(substr(ligne, 1L, k - 1L))
    }
  }
  ligne
}

# Blocs YAML indentes qui suivent une cle packages: / extra-packages: / needs: (liste sur
# plusieurs lignes) : vecteur logique des lignes du bloc.
bloc_yaml <- function(lignes) {
  dans <- rep(FALSE, length(lignes))
  vide <- !nzchar(trimws(lignes))
  indentation <- nchar(sub("[^ ].*$", "", lignes))
  for (k in which(grepl(paste0("^[ ]*(-[ ]+)?", LISTE_YAML), lignes))) {
    cle <- regexpr("(extra-packages|packages|needs)", lignes[k]) - 1L
    j <- k + 1L
    while (j <= length(lignes) && (vide[j] || indentation[j] > min(cle, indentation[k] + 1L))) {
      dans[j] <- !vide[j]
      j <- j + 1L
    }
  }
  dans
}

# Appels de chargement et d'installation d'un fichier R, d'apres les donnees d'analyse `pd`
# (sans commentaires) : data.frame ligne, fonction, noms (arguments pertinents, un par element).
appels_r <- function(pd) {
  enfants <- split(seq_len(nrow(pd)), pd$parent)
  fils <- function(i) enfants[[as.character(pd$id[i])]]
  descendants <- function(i) {
    sortie <- integer(0)
    pile <- fils(i)
    while (length(pile) > 0L) {
      k <- pile[1L]
      pile <- pile[-1L]
      sortie <- c(sortie, k)
      pile <- c(pile, fils(k))
    }
    sortie
  }
  nom_de <- function(k) {  # symbole ou chaine d'une expression reduite a un jeton
    d <- fils(k)
    if (length(d) == 1L && pd$token[d] %in% c("SYMBOL", "STR_CONST")) gsub("[\"'`]", "", pd$text[d]) else NA_character_
  }
  lignes <- integer(0)
  fonctions <- character(0)
  noms <- list()
  for (i in which(pd$token == "SYMBOL_FUNCTION_CALL")) {
    fonction <- gsub("`", "", pd$text[i])
    if (!(fonction %in% c(FONCTIONS_CHARGEMENT, "import", "importFrom", FONCTIONS_INSTALLATION))) next
    nom_appel <- match(pd$parent[i], pd$id)
    appel <- match(pd$parent[nom_appel], pd$id)
    if (is.na(appel)) next
    k <- fils(appel)
    k <- k[-(1:2)]                                       # apres le nom de fonction et `(`
    k <- k[pd$token[k] != "')'"]
    positionnels <- integer(0)
    nommes <- character(0)
    j <- 1L
    while (j <= length(k)) {
      if (pd$token[k[j]] == "SYMBOL_SUB") {
        nommes[pd$text[k[j]]] <- NA_character_
        valeur <- k[j + 2L]
        if (!is.na(valeur)) nommes[pd$text[k[j]]] <- as.character(valeur)
        j <- j + 3L
      } else if (pd$token[k[j]] == "expr") {
        positionnels <- c(positionnels, k[j])
        j <- j + 1L
      } else {
        j <- j + 1L
      }
    }
    if (fonction %in% FONCTIONS_CHARGEMENT || fonction == "importFrom") {
      premier <- if ("package" %in% names(nommes)) as.integer(nommes[["package"]]) else positionnels[1L]
      cibles <- if (is.na(premier)) character(0) else nom_de(premier)
    } else if (fonction == "import") {
      cibles <- vapply(positionnels, nom_de, character(1))
    } else {
      cibles <- character(0)
      for (d in descendants(appel)) {
        if (pd$token[d] %in% c("SYMBOL", "STR_CONST")) cibles <- c(cibles, gsub("[\"'`]", "", pd$text[d]))
      }
    }
    lignes <- c(lignes, pd$line1[i])
    fonctions <- c(fonctions, fonction)
    noms[[length(noms) + 1L]] <- cibles[!is.na(cibles)]
  }
  list(lignes = lignes, fonctions = fonctions, noms = noms)
}

# Unites de texte d'un fichier : list(texte, ligne, chaine, appels, yaml). Un fichier R
# est analyse par ses jetons ; en cas d'echec de l'analyse (ou pour un autre fichier), par
# ses lignes.
ascii <- function(x) iconv(enc2utf8(x), "UTF-8", "ASCII", sub = "?")  # seuls les noms ASCII comptent
unites <- function(f) {
  nom <- basename(f)
  if (grepl("\\.R$", nom) || grepl(NOMS_R, nom)) {
    pd <- tryCatch({
      exprs <- parse(file = f, keep.source = TRUE, encoding = "UTF-8")
      getParseData(exprs)
    }, error = function(e) NULL)
    if (!is.null(pd)) {
      pd <- pd[pd$token != "COMMENT", ]
      terminaux <- pd[pd$terminal, ]
      terminaux <- terminaux[order(terminaux$line1, terminaux$col1), ]
      return(list(texte = ascii(terminaux$text), ligne = terminaux$line1,
                  chaine = terminaux$token == "STR_CONST", jeton = terminaux$token,
                  appels = appels_r(pd), yaml = NULL))
    }
  }
  lignes <- ascii(readLines(f, warn = FALSE, encoding = "UTF-8"))
  if (!grepl(SANS_COMMENTAIRE, nom)) lignes <- vapply(lignes, sans_commentaire_mot, character(1), USE.NAMES = FALSE)
  list(texte = lignes, ligne = seq_along(lignes), chaine = rep(TRUE, length(lignes)),
       jeton = rep(NA_character_, length(lignes)), appels = NULL,
       yaml = if (grepl("\\.ya?ml$", nom)) bloc_yaml(lignes) else NULL)
}

vus <- character(0)
signaler <- function(message, f, ligne) {
  cle <- paste(f, ligne, message)
  if (!(cle %in% vus)) {
    vus <<- c(vus, cle)
    echec(message, f, ligne)
  }
}

avant <- .n_echec
for (f in sort(unique(fichiers), method = "radix")) {
  u <- unites(f)
  # Noms sans ambiguite : toute occurrence comme mot.
  for (p in PAQUETS_JAVA_SANS_AMBIGUITE) {
    for (i in which(grepl(mot(p), u$texte))) signaler(sprintf("package dependant de Java : `%s`", p), f, u$ligne[i])
  }
  # Noms ambigus : contexte de chargement ou d'installation.
  for (p in PAQUETS_JAVA_EN_CONTEXTE) {
    chaines <- which(u$chaine)
    for (i in chaines[charge(p, u$texte[chaines])]) signaler(sprintf("package dependant de Java : `%s`", p), f, u$ligne[i])
    if (!is.null(u$yaml)) {
      for (i in which(u$yaml & grepl(mot(p), u$texte))) signaler(sprintf("package dependant de Java : `%s`", p), f, u$ligne[i])
    }
    if (!is.null(u$appels)) {
      for (i in which(u$jeton == "SYMBOL_PACKAGE" & u$texte == p)) {
        signaler(sprintf("package dependant de Java : `%s`", p), f, u$ligne[i])
      }
      for (a in seq_along(u$appels$lignes)) {
        if (p %in% u$appels$noms[[a]]) signaler(sprintf("package dependant de Java : `%s`", p), f, u$appels$lignes[a])
      }
    }
  }
  # Environnement Java.
  for (motif in MOTIFS_ENVIRONNEMENT_JAVA) {
    for (i in which(grepl(motif, u$texte, ignore.case = TRUE))) {
      signaler(sprintf("environnement Java (motif `%s`)", gsub("\\", "", motif, fixed = TRUE)), f, u$ligne[i])
    }
  }
  # Fichiers R : `.jinit(` et `.jcall(` sont deux jetons (nom, parenthese) : le nom suffit.
  if (!is.null(u$appels)) {
    for (nom in c(".jinit", ".jcall")) {
      for (i in which(u$jeton %in% c("SYMBOL_FUNCTION_CALL", "SYMBOL") & gsub("`", "", u$texte, fixed = TRUE) == nom)) {
        signaler(sprintf("environnement Java (motif `%s`)", nom), f, u$ligne[i])
      }
    }
  }
}
if (.n_echec == avant) ok(sprintf("%d fichier(s) balaye(s) : aucun package ni environnement Java", length(fichiers)))

fin()
