# Controle : aucune dependance a Java, directe ou indirecte (ADR 0004, point 6 ; ADR 0010,
# point 26 ; issue #12). Trois verifications :
#   1. DESCRIPTION : aucun package connu pour dependre de Java dans Depends, Imports,
#      LinkingTo, Suggests, ni dans leur fermeture recursive parmi les packages installes
#      (nom de la liste ci-dessous, ou SystemRequirements qui cite Java, JDK ou JRE) ;
#      un package declare mais non installe est signale [AVERT] (fermeture non verifiable).
#   2. NAMESPACE, R/, app/, tests/ et .github/ (commentaires `#` ignores) : aucun
#      chargement d'un package de la liste (library(p), require(p), requireNamespace("p"),
#      loadNamespace("p"), "p" en argument d'une installation, `p::`, import(p), p dans
#      packages / extra-packages / needs), aucune installation ni activation d'un
#      environnement Java (setup-java, openjdk, default-jdk, default-jre, JAVA_HOME, .jinit,
#      .jcall). Un package a nom courant (xlsx) n'est refuse que dans ces contextes :
#      "library(openxlsx)  # lecture des feuilles xlsx" passe.
#   3. Le present script (tests/controles/absence_java.R de la racine examinee) est exclu du
#      balayage, il porte la liste.
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
# DESCRIPTION est traitee plus haut (declarations) ; le present script est exclu par son chemin
# relatif a la racine examinee (et non par celui du script qui tourne : sur une copie du
# depot, la copie du script serait sinon balayee).
fichiers <- file.path(racine, "NAMESPACE")
for (dossier in c("R", "app", "tests", ".github")) {
  chemin <- file.path(racine, dossier)
  if (dir.exists(chemin)) {
    fichiers <- c(fichiers, list.files(chemin, pattern = "\\.(R|r|Rmd|yml|yaml|sh|json|toml)$",
                                       recursive = TRUE, full.names = TRUE, all.files = TRUE))
  }
}
fichiers <- fichiers[file.exists(fichiers)]
fichiers <- fichiers[vapply(fichiers, rel, character(1)) != "tests/controles/absence_java.R"]

B <- "(^|[^A-Za-z0-9._])"
E <- "($|[^A-Za-z0-9._])"
CHARGEUR <- "(library|require|requireNamespace|loadNamespace|attachNamespace|import|importFrom)"
INSTALLATEUR <- "(install\\.packages|install_version|install_cran|p_load|pkg_install|renv::install|needs)"
LISTE_YAML <- "(extra-packages|packages|needs)[ \t]*[:=]"
# Contexte de chargement ou d'installation de `p` sur une ligne sans commentaire.
charge <- function(p, ligne) {
  grepl(paste0(CHARGEUR, "[ \t]*\\([ \t]*[\"']?", p, "[\"']?[ \t]*[,)]"), ligne) ||
    grepl(paste0(B, p, ":::?"), ligne) ||
    (grepl(INSTALLATEUR, ligne) && grepl(paste0("[\"']", p, "[\"']"), ligne)) ||
    (grepl(LISTE_YAML, ligne) && grepl(paste0(B, p, E), ligne))
}

avant <- .n_echec
for (f in sort(unique(fichiers), method = "radix")) {
  lignes <- readLines(f, warn = FALSE, encoding = "UTF-8")
  lignes <- iconv(lignes, "UTF-8", "ASCII", sub = "?")  # seuls les noms ASCII comptent
  lignes <- sub("#.*$", "", lignes)                     # commentaires R, shell, YAML ignores
  for (i in seq_along(lignes)) {
    ligne <- lignes[i]
    for (p in PAQUETS_JAVA_SANS_AMBIGUITE) {
      if (grepl(paste0(B, p, E), ligne)) echec(sprintf("package dependant de Java : `%s`", p), f, i)
    }
    for (p in PAQUETS_JAVA_EN_CONTEXTE) {
      if (charge(p, ligne)) echec(sprintf("package dependant de Java : `%s`", p), f, i)
    }
    for (motif in MOTIFS_ENVIRONNEMENT_JAVA) {
      if (grepl(motif, ligne, ignore.case = TRUE)) {
        echec(sprintf("environnement Java (motif `%s`)", gsub("\\", "", motif, fixed = TRUE)), f, i)
      }
    }
  }
}
if (.n_echec == avant) ok(sprintf("%d fichier(s) balaye(s) : aucun package ni environnement Java", length(fichiers)))

fin()
