# Témoins versionnés des scripts de contrôle de tests/controles/ (#27 ; ADR 0010, points 25
# et 26). Exécuté par tests/test_unitaires.R : le harnais est sourcé, `racine` est défini.
# Chaque cas construit une copie temporaire minimale du dépôt (seuls les fichiers que lit le
# script), y dépose le fichier témoin, lance le script du dépôt (Rscript <script> <copie>) et
# vérifie le statut (1 pour un témoin positif, avec la ligne [ECHEC] fichier:ligne attendue ;
# 0 pour un cas licite ou une limite documentée) : les contrôles ne sont pas seulement
# exécutés sur le dépôt, ils sont éprouvés.
# Ce fichier est lui-même balayé par absence_java.R : les noms interdits y sont fabriqués
# (paste0("r", "Java")), jamais écrits en clair, et les exclusions du script ne sont pas élargies
# pour lui (N2e). Les chaînes non ASCII sont marquées par \u (locale C : octets écrits tels quels).

.script_controle <- function(nom) file.path(racine, "tests", "controles", paste0(nom, ".R"))

# Écrit `lignes` dans `chemin` (dossiers créés), en octets, fin de ligne \n.
.deposer <- function(chemin, lignes) {
  dir.create(dirname(chemin), recursive = TRUE, showWarnings = FALSE)
  writeBin(charToRaw(paste0(paste(lignes, collapse = "\n"), "\n")), chemin)
}

# Lance `nom` sur une copie qui contient `fichiers` (liste nommée chemin relatif -> lignes) ;
# rend list(statut, sortie).
.essai <- function(nom, fichiers) {
  copie <- tempfile("temoin-")
  dir.create(copie)
  on.exit(unlink(copie, recursive = TRUE), add = TRUE)
  for (chemin in names(fichiers)) .deposer(file.path(copie, chemin), fichiers[[chemin]])
  sortie <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
                                     c(shQuote(.script_controle(nom)), shQuote(copie)),
                                     stdout = TRUE, stderr = TRUE))
  statut <- attr(sortie, "status")
  list(statut = if (is.null(statut)) 0L else statut, sortie = sortie)
}

# Le contrôle échoue (statut 1) avec une ligne [ECHEC] <fichier>:<ligne> (et, si `motif`, un
# message qui le contient) ; `ligne` NA : [ECHEC] <fichier> sans numéro de ligne.
.echoue_en <- function(r, fichier, ligne = NA_integer_, motif = "") {
  position <- if (is.na(ligne)) paste0(fichier, " ") else paste0(fichier, ":", ligne, " ")
  r$statut == 1L && any(startsWith(r$sortie, paste0("[ECHEC] ", position)) &
                          grepl(motif, r$sortie, fixed = TRUE))
}
# Le contrôle passe : statut 0, aucune ligne [ECHEC].
.passe <- function(r) r$statut == 0L && !any(startsWith(r$sortie, "[ECHEC]"))

# Noms interdits, fabriqués (voir l'en-tête).
RJ <- paste0("r", "Java")
XL <- paste0("xl", "sx")
RW <- paste0("RW", "eka")
XC <- paste0("XLCon", "nect")
JDK <- paste0("default-", "jdk")
OJ <- paste0("open", "jdk-17-jdk")
JH <- paste0("JAVA", "_HOME")
CL <- paste0("Chain", "Ladder")
JI <- paste0(".ji", "nit")
JC <- paste0(".j", "call")

# --- liste_blanche_description.R (N1) ------------------------------------------------------
DESC <- c("Package: temoin", "Version: 0.0.1", "Title: Temoin", "Description: Temoin.",
          "License: file LICENSE", "Imports: stats")
cas_ns <- function(lignes) .essai("liste_blanche_description", list(DESCRIPTION = DESC, NAMESPACE = lignes))
cas_desc <- function(ajout) .essai("liste_blanche_description",
                                    list(DESCRIPTION = c(DESC, ajout), NAMESPACE = "import(stats)"))

section("contrôles : liste_blanche_description.R (N1)")
r <- cas_ns(paste0("importFrom(", CL, ", MackChainLadder)"))
verifier("témoin positif bis : import(<hors liste>) sans nom d'argument, NAMESPACE:1 (non-régression C2)", {
  r <- cas_ns(paste0("import(", CL, ")"))
  .echoue_en(r, "NAMESPACE", 1L, CL)
})
verifier("témoin positif : importFrom d'un package hors liste, NAMESPACE:1",
         .echoue_en(r, "NAMESPACE", 1L, CL))
r <- cas_ns(c("import(stats)", paste0("importFrom(stats, \"%#%\"); importFrom(", CL, ", MackChainLadder)")))
verifier("N1a : un # dans une chaîne de NAMESPACE ne masque pas la suite, NAMESPACE:2",
         .echoue_en(r, "NAMESPACE", 2L, CL))
r <- cas_ns(c("importFrom(stats, \"%#%\")", paste0("import(utils)  # ", CL)))
verifier("N1a, cas licite : # dans une chaîne, nom de package en commentaire", .passe(r))
r <- cas_ns(paste0("import(stats, except = c(sd), ", CL, ")"))
verifier("import() : tous les arguments, hors except, NAMESPACE:1", .echoue_en(r, "NAMESPACE", 1L, CL))
r <- cas_ns(c("import(stats,", "       utils)", "importClassesFrom(methods, A)"))
verifier("import() sur plusieurs lignes, packages de la liste : licite", .passe(r))
r <- cas_ns(paste0("if (FALSE) importFrom(", CL, ", x)"))
verifier("C2 : un import sous `if (FALSE)` est vu (aucune evaluation du NAMESPACE), NAMESPACE:1",
         .echoue_en(r, "NAMESPACE", 1L, CL))
r <- cas_ns(paste0("if (getRversion() < \"1.0.0\") importFrom(", CL, ", x) else import(stats)"))
verifier("C2 : branche fausse d'un if ... else, NAMESPACE:1", .echoue_en(r, "NAMESPACE", 1L, CL))
r <- cas_ns(c("if (TRUE) {", "  import(stats)", paste0("} else import(", CL, ")")))
verifier("C2 : branche else d'un if sur plusieurs lignes, NAMESPACE:1 (ligne de l'expression de premier niveau)",
         .echoue_en(r, "NAMESPACE", 1L, CL))
r <- cas_ns(c("if (TRUE) import(stats)", "stop(\"non execute\")"))
verifier("C2, cas licite : le NAMESPACE n'est pas execute (stop() inoffensif)", .passe(r))
r <- cas_ns(c("import(stats)", "importMethodsFrom(m3, show)"))
verifier("importMethodsFrom d'un package hors liste, NAMESPACE:2", .echoue_en(r, "NAMESPACE", 2L, "`m3`"))
r <- cas_desc(paste0("Enhances: ", CL))
verifier("N1b : champ Enhances hors liste, DESCRIPTION:7", .echoue_en(r, "DESCRIPTION", 7L, "Enhances"))
r <- cas_desc("Enhances: stats")
verifier("N1b, cas licite : Enhances sur la liste", .passe(r))
r <- cas_desc(paste0("Remotes: cran/", CL))
verifier("N1b : champ Remotes refusé, DESCRIPTION:7", .echoue_en(r, "DESCRIPTION", 7L, "Remotes"))
r <- cas_desc("Additional_repositories: https://exemple.invalid")
verifier("N1b : champ Additional_repositories refusé, DESCRIPTION:7",
         .echoue_en(r, "DESCRIPTION", 7L, "Additional_repositories"))

# --- absence_java.R (N2) ---------------------------------------------------------------------
cas_java <- function(fichiers) .essai("absence_java", c(list(DESCRIPTION = DESC), fichiers))

section("contrôles : absence_java.R (N2)")
r <- cas_java(list("tests/t_java.R" = paste0("library(", RJ, ")")))
verifier("témoin positif : chargement d'un package à Java, tests/t_java.R:1",
         .echoue_en(r, "tests/t_java.R", 1L, RJ))
r <- cas_java(list(
  "renv.lock" = paste0("{\"Packages\": {\"", RJ, "\": {\"Package\": \"", RJ, "\"}}}"),
  ".Rprofile" = paste0("library(", RJ, ")"),
  "inst/scripts/x.R" = paste0("library(", RJ, ")"),
  ".claude/hooks/h.sh" = paste0("apt-get install -y ", JDK),
  "Dockerfile" = c("FROM rocker/r-ver:4.3.3", paste0("RUN apt-get install -y ", JDK))))
verifier("N2a : renv.lock (extension .lock) balayé", .echoue_en(r, "renv.lock", 1L, RJ))
verifier("N2a : .Rprofile (nom sans extension) balayé", .echoue_en(r, ".Rprofile", 1L, RJ))
verifier("N2a : inst/scripts/x.R balayé", .echoue_en(r, "inst/scripts/x.R", 1L, RJ))
verifier("N2a : .claude/hooks/h.sh balayé", .echoue_en(r, ".claude/hooks/h.sh", 1L, JDK))
verifier("N2a : Dockerfile balayé, Dockerfile:2", .echoue_en(r, "Dockerfile", 2L, JDK))
r <- cas_java(list(".github/workflows/j.yml" = c(
  "jobs:", "  a:", "    steps:", "      - uses: r-lib/actions/setup-r-dependencies@v2", "        with:",
  "          extra-packages: |", paste0("            any::", XL), paste0("            any::", RW))))
verifier("N2b : liste YAML sur plusieurs lignes (any::p), j.yml:7", .echoue_en(r, ".github/workflows/j.yml", 7L, XL))
verifier("N2b : liste YAML sur plusieurs lignes (any::p), j.yml:8", .echoue_en(r, ".github/workflows/j.yml", 8L, RW))
r <- cas_java(list(".github/workflows/j.yml" = c(
  "jobs:", paste0("  pkgs: cran::", XL), paste0("  autre: github::depot/", RW))))
verifier("N2b : cran::p refusé partout, j.yml:2", .echoue_en(r, ".github/workflows/j.yml", 2L, XL))
verifier("N2b : github::depot/p refusé partout, j.yml:3", .echoue_en(r, ".github/workflows/j.yml", 3L, RW))
r <- cas_java(list(".github/workflows/j.yml" = c(
  "jobs:", "  a:", "    steps:", "      - uses: x", "        with:", "          extra-packages: |",
  "            cli", "            jsonlite", "          autre: valeur")))
verifier("N2b, cas licite : liste YAML de packages sans Java", .passe(r))
r <- cas_java(list("tests/t_java.R" = c(
  paste0("library(package = ", XL, ")"),
  paste0("requireNamespace(package = \"", RW, "\")"),
  "library(", paste0("  ", XC), ")",
  paste0("pak::pak(\"", XL, "\")"),
  paste0("BiocManager::install(\"", RW, "\")"),
  paste0("x <- \"any::", XL, "\""),
  paste0("install.packages(c(\"cli\",", "\n  \"", RW, "\"))"))))
verifier("N2c : library(package = p), t_java.R:1", .echoue_en(r, "tests/t_java.R", 1L, XL))
verifier("N2c : requireNamespace(package = \"p\"), t_java.R:2", .echoue_en(r, "tests/t_java.R", 2L, RW))
verifier("N2c : library( sur plusieurs lignes, t_java.R:3", .echoue_en(r, "tests/t_java.R", 3L, XC))
verifier("N2c : pak::pak(\"p\"), t_java.R:6", .echoue_en(r, "tests/t_java.R", 6L, XL))
verifier("N2c : BiocManager::install(\"p\"), t_java.R:7", .echoue_en(r, "tests/t_java.R", 7L, RW))
verifier("N2c : chaîne \"any::p\" dans du code R, t_java.R:8", .echoue_en(r, "tests/t_java.R", 8L, XL))
verifier("N2c : install.packages(c(...)) sur plusieurs lignes, t_java.R:9", .echoue_en(r, "tests/t_java.R", 9L, RW))
r <- cas_java(list("tests/t.R" = c("f <- function() {", paste0("  ", JI, "()"),
                                   paste0("  ", JC, "(\"x\", \"V\", \"m\")"),
                                   paste0("  `", JI, "`()"), "}")))
verifier("C1 : appel du demarrage de la JVM dans un fichier R, tests/t.R:2", .echoue_en(r, "tests/t.R", 2L, "jinit"))
verifier("C1 : appel d'une methode Java dans un fichier R, tests/t.R:3", .echoue_en(r, "tests/t.R", 3L, "jcall"))
verifier("C1 : meme nom entre accents graves, tests/t.R:4", .echoue_en(r, "tests/t.R", 4L, "jinit"))
r <- cas_java(list("tests/t_diese.R" = paste0("x <- \"#\"; library(", RJ, ")"),
                   ".github/workflows/k.yml" = c("jobs:", "  a:", "    steps:",
                                                 paste0("      - run: echo \"#\" && sudo apt-get install -y ", OJ))))
verifier("N2d : # dans une chaîne R ne masque pas la suite, t_diese.R:1", .echoue_en(r, "tests/t_diese.R", 1L, RJ))
verifier("N2d : # dans une chaîne YAML/shell ne masque pas la suite, k.yml:4",
         .echoue_en(r, ".github/workflows/k.yml", 4L, "jdk"))
r <- cas_java(list(
  "tests/ok.R" = c("library(openxlsx)  # lecture des feuilles xlsx", paste0("x <- 1  # library(", RJ, ")")),
  ".github/workflows/ok.yml" = c("jobs:", paste0("  a: echo ok  # ", OJ)),
  "scripts/ok.sh" = c(paste0("# ", JDK), paste0("echo ok > /dev/null  # ", JH))))
verifier("N2d, cas licites : commentaires R, YAML et shell, library(openxlsx)", .passe(r))
r <- cas_java(list("tests/t_temoin.R" = c(
  paste0("writeLines(\"library(", RJ, ")\", f)"), paste0("m <- \"", JH, " n est pas requis\""))))
verifier("N2e : un test qui écrit un nom interdit en clair reste refusé (exclusions non élargies), t_temoin.R:1",
         .echoue_en(r, "tests/t_temoin.R", 1L, RJ))
r <- cas_java(list("tests/t_temoin.R" = c(
  "writeLines(paste0(\"library(r\", \"Java)\"), f)", "m <- paste0(\"JAVA\", \"_HOME\")")))
verifier("N2e : le même test avec les noms fabriqués par paste0() passe", .passe(r))

# C5 : voie `git ls-files` (la racine examinee est la racine d'un depot git) : seuls les fichiers
# suivis sont balayes. Copie temporaire initialisee par git init et git add.
if (nzchar(Sys.which("git"))) {
  .essai_git <- function(suivis, non_suivis) {
    copie <- tempfile("temoin-git-")
    dir.create(copie)
    on.exit(unlink(copie, recursive = TRUE), add = TRUE)
    for (chemin in c(names(suivis), names(non_suivis))) {
      .deposer(file.path(copie, chemin), c(suivis, non_suivis)[[chemin]])
    }
    git <- function(...) suppressWarnings(system2("git", c("-C", shQuote(copie), ...), stdout = TRUE, stderr = TRUE))
    git("init", "-q")
    git("add", names(suivis))
    sortie <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
                                       c(shQuote(.script_controle("absence_java")), shQuote(copie)),
                                       stdout = TRUE, stderr = TRUE))
    statut <- attr(sortie, "status")
    list(statut = if (is.null(statut)) 0L else statut, sortie = sortie)
  }
  r <- .essai_git(list(DESCRIPTION = DESC, "tests/t_java.R" = paste0("library(", RJ, ")")),
                  list("tests/u_java.R" = paste0("library(", RJ, ")")))
  verifier("C5 : fichier suivi interdit refuse (git ls-files), t_java.R:1", .echoue_en(r, "tests/t_java.R", 1L, RJ))
  verifier("C5 : fichier non suivi ignore (git ls-files), pas de ligne pour u_java.R",
           !any(grepl("u_java.R", r$sortie, fixed = TRUE)))
  r <- .essai_git(list(DESCRIPTION = DESC), list("tests/u_java.R" = paste0("library(", RJ, ")")))
  verifier("C5 : seul un fichier non suivi interdit : le controle passe (preuve de la voie git)", .passe(r))
}

# --- graphe_modules.R (N3, N6, M236) --------------------------------------------------------
AMONT <- list("R/simulation.R" = "simuler_base <- function(x) x", "R/lecture.R" = "lire_base <- function(d) d")
cas_graphe <- function(engagement, ...) .essai("graphe_modules", c(AMONT, list("R/engagement.R" = engagement), list(...)))
ARETE <- "arete hors du graphe"
# Un outils.R fictif tient l'exception globalenv() de avec_graine() (M412) : sans elle, elle serait
# périmée (échec) dès que outils.R est présent.
AVEC_GRAINE <- "avec_graine <- function(graine, expr) globalenv()"

section("contrôles : graphe_modules.R (N3, N6, M236)")
r <- cas_graphe("calcul_e <- function(x) simuler_base(x)")
verifier("témoin positif : engagement -> simulation, engagement.R:1", .echoue_en(r, "R/engagement.R", 1L, ARETE))
r <- cas_graphe("calcul_e <- function(x) `simuler_base`(x)")
verifier("N3a : appel entre accents graves, engagement.R:1", .echoue_en(r, "R/engagement.R", 1L, ARETE))
r <- cas_graphe("calcul_e <- function(x) \"simuler_base\"(x)")
verifier("N3a : appel par une chaîne, engagement.R:1", .echoue_en(r, "R/engagement.R", 1L, ARETE))
r <- cas_graphe("calcul_e <- function(x) { y <- x; y }")
verifier("N3a, cas licite : aucune référence à un autre module", .passe(r))
r2 <- .essai("graphe_modules", list("R/simulation.R" = c("simuler_base <- function(x) x", "(function(x) x) -> fonction_droite"),
                                    "R/engagement.R" = "calcul_e <- function(x) fonction_droite(x)"))
verifier("N3b : définition par -> reconnue (nom défini dans simulation), engagement.R:1",
         .echoue_en(r2, "R/engagement.R", 1L, "fonction_droite"))
r2 <- .essai("graphe_modules", list("R/simulation.R" = c("simuler_base <- function(x) x",
                                                         "assign(\"fonction_assign\", function(x) x)"),
                                    "R/engagement.R" = "calcul_e <- function(x) fonction_assign(x)"))
verifier("N3b : assign() au premier niveau refusé, simulation.R:2", .echoue_en(r2, "R/simulation.R", 2L, "assign()"))
r2 <- .essai("graphe_modules", list("R/outils.R" = c("ecrire_dans <- function(e) assign(\"a\", 1, envir = e)", AVEC_GRAINE)))
verifier("N3b, cas licite : assign() dans une fonction", .passe(r2))
r <- cas_graphe(c("calcul_e <- function(x) {",
                  "  a <- loadNamespace(\"x\")", "  b <- requireNamespace(\"x\")",
                  "  c <- attachNamespace(\"x\")", "  d <- as.environment(\"x\")", "  x", "}"))
verifier("N3c : loadNamespace, engagement.R:2", .echoue_en(r, "R/engagement.R", 2L, "loadNamespace()"))
verifier("N3c : requireNamespace, engagement.R:3", .echoue_en(r, "R/engagement.R", 3L, "requireNamespace()"))
verifier("N3c : attachNamespace, engagement.R:4", .echoue_en(r, "R/engagement.R", 4L, "attachNamespace()"))
verifier("N3c : as.environment, engagement.R:5", .echoue_en(r, "R/engagement.R", 5L, "as.environment()"))
r <- cas_graphe(c("calcul_e <- function(x) {", "  e <- environment()", "  f <- function() 1",
                  "  environment(f) <- e", "  environment(f)", "}"))
verifier("M236 : e <- environment() refusé, engagement.R:2", .echoue_en(r, "R/engagement.R", 2L, "environment()"))
verifier("M236 : environment(f) <- e refusé, engagement.R:4", .echoue_en(r, "R/engagement.R", 4L, "environment()"))
verifier("M236 : environment(f) refusé, engagement.R:5", .echoue_en(r, "R/engagement.R", 5L, "environment()"))
# N6 : « cible seule » (M236). Les deux premiers cas documentent la limite (fausse arête,
# côté sûr) ; les deux suivants éprouvent la correction.
r <- cas_graphe(c("calcul_e <- function(x) {", "  lire_base <- function(d) d", "  lire_base(x)", "}"))
verifier("N6a, limite documentée : fonction locale homonyme d'un autre module, fausse arête (côté sûr), engagement.R:3",
         .echoue_en(r, "R/engagement.R", 3L, ARETE))
r <- cas_graphe("calcul_e <- function(x, lire_base) lapply(x, lire_base)")
verifier("N6d, limite documentée : argument formel homonyme repris, fausse arête (côté sûr), engagement.R:1",
         .echoue_en(r, "R/engagement.R", 1L, ARETE))
r <- cas_graphe(c("calcul_e <- function(x) {", "  g <- simuler_base", "  simuler_base <- 1", "  g", "}"))
verifier("N6b : lecture avant l'affectation locale, comptée, engagement.R:2", .echoue_en(r, "R/engagement.R", 2L, ARETE))
r <- cas_graphe(c("calcul_e <- function(x) {", "  a <- function() simuler_base",
                  "  b <- function() { simuler_base <- 2 ; simuler_base }", "  a()", "}"))
verifier("N6c : portée sœur (a lit, b affecte), la lecture de a est comptée, engagement.R:2",
         .echoue_en(r, "R/engagement.R", 2L, ARETE))

# Identifiants à point employés hors de leur fichier (#74, M405 ; exceptions renvoyées à #102).
# lecture -> dictionnaire est une arête permise : seule la règle du point est en cause.
section("contrôles : graphe_modules.R, identifiants à point (#74, M405)")
r <- .essai("graphe_modules", list("R/dictionnaire.R" = ".aux_d <- function(x) x",
                                   "R/lecture.R" = "lire_e <- function(x) .aux_d(x)"))
verifier("#74 : appel d'un auxiliaire à point d'un autre module, non déclaré, lecture.R:1",
         .echoue_en(r, "R/lecture.R", 1L, ".aux_d"))
r <- .essai("graphe_modules", list("R/dictionnaire.R" = ".CONST_D <- 1",
                                   "R/lecture.R" = c("lire_e <- function(x) {", "  x + .CONST_D", "}")))
verifier("#74 : symbole (constante) à point d'un autre module, non déclaré, lecture.R:2",
         .echoue_en(r, "R/lecture.R", 2L, ".CONST_D"))
r <- .essai("graphe_modules", list("R/dictionnaire.R" = c(".aux_d <- function(x) x", "dico_f <- function(x) .aux_d(x)"),
                                   "R/lecture.R" = "lire_e <- function(x) dico_f(x)"))
verifier("#74, cas licite : identifiant à point employé dans son propre fichier, appelé hors module sans point", .passe(r))
# Exceptions déclarées (EXCEPTIONS_POINT, renvoi #102) : tenues, elles passent ; absentes, elles échouent.
r <- .essai("graphe_modules", list(
  "R/outils.R" = c(".longueur_commune <- function(n) n", ".composantes_date <- function(j) j", ".jour_de <- function(j) j", AVEC_GRAINE),
  "R/donnees.R" = c("donnees_f <- function(x) {", "  .longueur_commune(x)", "  .composantes_date(x)", "  .jour_de(x)", "}")))
verifier("#74, cas licite : emplois déclarés en exception (#102), le contrôle passe", .passe(r))
r <- .essai("graphe_modules", list(
  "R/outils.R" = c(".longueur_commune <- function(n) n", ".composantes_date <- function(j) j", ".jour_de <- function(j) j", AVEC_GRAINE),
  "R/donnees.R" = c("donnees_f <- function(x) {", "  .longueur_commune(x)", "  .jour_de(x)", "}")))
verifier("#74 : exception déclarée qui ne se produit plus (.composantes_date), donnees.R sans ligne", {
  .echoue_en(r, "R/donnees.R", NA_integer_, ".composantes_date") &&
    !any(grepl("[ECHEC] R/donnees.R:", r$sortie, fixed = TRUE))
})
r <- .essai("graphe_modules", list(
  "R/outils.R" = c(".longueur_commune <- function(n) n", ".composantes_date <- function(j) j", ".jour_de <- function(j) j", AVEC_GRAINE),
  "R/donnees.R" = c("donnees_f <- function(x) {", "  .longueur_commune(x)", "  .composantes_date(x)", "  .jour_de(x)", "  .autre(x)", "}"),
  "R/dictionnaire.R" = ".autre <- function(x) x"))
verifier("#74 : un emploi non déclaré à côté d'exceptions tenues, donnees.R:5", .echoue_en(r, "R/donnees.R", 5L, ".autre"))
r <- .essai("graphe_modules", list("R/outils.R" = c(".longueur_commune <- function(n) n", AVEC_GRAINE),
                                   "R/donnees.R" = "donnees_f <- function(x) x"))
verifier("#74 : exception déclarée dont l'identifiant n'est plus employé (donnees.R n'appelle rien), donnees.R sans ligne",
         .echoue_en(r, "R/donnees.R", NA_integer_, ".longueur_commune"))
verifier("#74 : le dépôt réel passe (aucun emploi hors de son fichier hors des exceptions déclarées)", {
  sortie <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
                                     c(shQuote(.script_controle("graphe_modules")), shQuote(racine)),
                                     stdout = TRUE, stderr = TRUE))
  statut <- attr(sortie, "status")
  (is.null(statut) || statut == 0L) && any(startsWith(sortie, "[OK] identifiants a point")) &&
    !any(startsWith(sortie, "[ECHEC]"))
})

# M403 : introspection de pile et d'environnement, dans l'esprit de M236 (issue #62).
section("contrôles : graphe_modules.R, introspection de pile (#62, M403)")
r <- cas_graphe(c("calcul_e <- function(x) {", "  a <- parent.frame()", "  b <- sys.function()",
                  "  c <- parent.env(a)", "  d <- topenv()", "  e <- sys.call()", "  x", "}"))
verifier("M403 : parent.frame, engagement.R:2", .echoue_en(r, "R/engagement.R", 2L, "parent.frame()"))
verifier("M403 : sys.function, engagement.R:3", .echoue_en(r, "R/engagement.R", 3L, "sys.function()"))
verifier("M403 : parent.env, engagement.R:4", .echoue_en(r, "R/engagement.R", 4L, "parent.env()"))
verifier("M403 : topenv, engagement.R:5", .echoue_en(r, "R/engagement.R", 5L, "topenv()"))
verifier("M403 : sys.call, engagement.R:6", .echoue_en(r, "R/engagement.R", 6L, "sys.call()"))
r <- cas_graphe(c("calcul_e <- function(x) {", "  y <- x$topenv", "  z <- list(sys.call = 1, parent.frame = 2)",
                  "  parent_frame <- 1", "  y", "}"))
verifier("M403, cas licite : champs, noms d'arguments et noms voisins qui ressemblent aux appels interdits", .passe(r))
r <- cas_graphe(c("calcul_e <- function(x) {", "  a <- sys.frame(0)", "  b <- sys.frames()", "  c <- sys.calls()",
                  "  d <- sys.parent()", "  sys.on.exit()", "  e <- match.call()", "  x", "}"))
verifier("M411 : sys.frame, engagement.R:2", .echoue_en(r, "R/engagement.R", 2L, "sys.frame()"))
verifier("M411 : sys.frames, engagement.R:3", .echoue_en(r, "R/engagement.R", 3L, "sys.frames()"))
verifier("M411 : sys.calls, engagement.R:4", .echoue_en(r, "R/engagement.R", 4L, "sys.calls()"))
verifier("M411 : sys.parent, engagement.R:5", .echoue_en(r, "R/engagement.R", 5L, "sys.parent()"))
verifier("M411 : sys.on.exit, engagement.R:6", .echoue_en(r, "R/engagement.R", 6L, "sys.on.exit()"))
verifier("M411 : match.call, engagement.R:7", .echoue_en(r, "R/engagement.R", 7L, "match.call()"))

# M1 de l'audit : un fichier dont le dernier jeton est une chaîne ne fait pas planter le script.
for (cas in list(list("VERSION_X <- \"1.0\"", "fichier réduit à une affectation de chaîne"),
                 list("f <- function(x) x$\"a\"", "champ par une chaîne en fin de fichier"),
                 list(c("SEP <- \";\"  # fin", "# commentaire"), "chaîne suivie d'un commentaire"))) {
  r <- .essai("graphe_modules", list("R/dictionnaire.R" = cas[[1L]]))
  verifier(paste0("m1 (audit) : dernier jeton une chaîne, ", cas[[2L]], " : le contrôle passe"),
           .passe(r) && !any(grepl("missing value", r$sortie, fixed = TRUE)))
}
r <- .essai("graphe_modules", list("R/dictionnaire.R" = c(".aux <- function(x) x"), "R/lecture.R" = "lire_e <- function(x) vapply(x, \".aux\", 1)"))
verifier("m1 (audit) : un nom passé en chaîne en dernier jeton du fichier reste vu, lecture.R:1", .echoue_en(r, "R/lecture.R", 1L, ".aux"))

# M409 : exception d'introspection déclarée en dur (topenv() dans empreinte_code() du module rapport).
section("contrôles : graphe_modules.R, exception d'introspection (#62, M409)")
EMPREINTE <- c("empreinte_code <- function() {", "  objets <- eapply(topenv(), function(x) x)", "  objets", "}")
r <- .essai("graphe_modules", list("R/rapport.R" = EMPREINTE))
verifier("M409 : topenv() dans empreinte_code() de rapport.R, exception déclarée : le contrôle passe",
         .passe(r) && any(grepl("M409, M412 : 2 declaree(s), 1 constatee(s)", r$sortie, fixed = TRUE)))
r <- .essai("graphe_modules", list("R/rapport.R" = c(EMPREINTE, "autre_f <- function() topenv()")))
verifier("M409 : topenv() dans une autre fonction de rapport.R échoue, rapport.R:5", .echoue_en(r, "R/rapport.R", 5L, "topenv()"))
verifier("M409 : l'exception ne couvre que la ligne de empreinte_code (rapport.R:2 sans ECHEC)",
         !any(startsWith(r$sortie, "[ECHEC] R/rapport.R:2 ")))
r <- .essai("graphe_modules", list("R/rapport.R" = c(EMPREINTE, "topenv_haut <- topenv()")))
verifier("M409 : topenv() au premier niveau de rapport.R échoue, rapport.R:5", .echoue_en(r, "R/rapport.R", 5L, "topenv()"))
r <- cas_graphe("calcul_e <- function(x) topenv()")
verifier("M409 : topenv() dans un autre module échoue, engagement.R:1", .echoue_en(r, "R/engagement.R", 1L, "topenv()"))
r <- .essai("graphe_modules", list("R/rapport.R" = c("empreinte_code <- function() {", "  parent.frame()", "}")))
verifier("M409 : l'exception est propre à topenv, parent.frame() dans empreinte_code échoue, rapport.R:2 ; et l'exception périmée aussi",
         .echoue_en(r, "R/rapport.R", 2L, "parent.frame()") && .echoue_en(r, "R/rapport.R", NA_integer_, "exception declaree"))
r <- .essai("graphe_modules", list("R/rapport.R" = c("empreinte_code <- function() {", "  1", "}")))
verifier("M409 : exception périmée (empreinte_code n'appelle plus topenv), rapport.R sans numéro de ligne",
         .echoue_en(r, "R/rapport.R", NA_integer_, "exception declaree") &&
           !any(grepl("[ECHEC] R/rapport.R:", r$sortie, fixed = TRUE)))
r <- .essai("graphe_modules", list("R/rapport.R" = c(EMPREINTE, "empreinte_code2 <- function() 1")))
verifier("M409 : sans outils.R dans la racine, l'exception globalenv n'est pas contrôlée (fichier absent), le contrôle passe", .passe(r))
r <- cas_graphe("calcul_e <- function(x) x")
verifier("M409 : sans rapport.R dans la racine, l'exception n'est pas contrôlée (fichier absent)", .passe(r))

# M412 : globalenv() interdit, exception déclarée pour avec_graine() du module outils.
section("contrôles : graphe_modules.R, globalenv (#62, M412)")
GRAINE <- c("avec_graine <- function(graine, expr) {", "  global <- globalenv()", "  global", "}")
r <- .essai("graphe_modules", list("R/outils.R" = GRAINE))
verifier("M412 : globalenv() dans avec_graine() de outils.R, exception déclarée : le contrôle passe",
         .passe(r) && any(grepl("M409, M412 : 2 declaree(s), 1 constatee(s)", r$sortie, fixed = TRUE)))
r <- .essai("graphe_modules", list("R/outils.R" = c(GRAINE, "autre_f <- function() globalenv()")))
verifier("M412 : globalenv() dans une autre fonction de outils.R échoue, outils.R:5", .echoue_en(r, "R/outils.R", 5L, "globalenv()"))
verifier("M412 : l'exception ne couvre que avec_graine (outils.R:2 sans ECHEC)", !any(startsWith(r$sortie, "[ECHEC] R/outils.R:2 ")))
r <- .essai("graphe_modules", list("R/outils.R" = c(GRAINE, "haut <- globalenv()")))
verifier("M412 : globalenv() au premier niveau de outils.R échoue, outils.R:5", .echoue_en(r, "R/outils.R", 5L, "globalenv()"))
r <- cas_graphe("calcul_e <- function(x) globalenv()")
verifier("M412 : globalenv() dans un autre module échoue, engagement.R:1", .echoue_en(r, "R/engagement.R", 1L, "globalenv()"))
r <- .essai("graphe_modules", list("R/rapport.R" = c("empreinte_code <- function() {", "  globalenv()", "  topenv()", "}")))
verifier("M412 : globalenv() dans empreinte_code (exception de topenv) échoue, rapport.R:2",
         .echoue_en(r, "R/rapport.R", 2L, "globalenv()") && !any(startsWith(r$sortie, "[ECHEC] R/rapport.R:3 ")))
r <- .essai("graphe_modules", list("R/outils.R" = c("avec_graine <- function(graine, expr) {", "  topenv()", "}")))
verifier("M412 : topenv() dans avec_graine échoue (chaque exception a son appel), outils.R:2, et l'exception périmée aussi",
         .echoue_en(r, "R/outils.R", 2L, "topenv()") && .echoue_en(r, "R/outils.R", NA_integer_, "exception declaree"))
r <- .essai("graphe_modules", list("R/outils.R" = c("avec_graine <- function(graine, expr) {", "  graine", "}")))
verifier("M412 : exception périmée (avec_graine n'appelle plus globalenv), outils.R sans numéro de ligne",
         .echoue_en(r, "R/outils.R", NA_integer_, "exception declaree") && !any(grepl("[ECHEC] R/outils.R:", r$sortie, fixed = TRUE)))

# m1 : un nom d'auxiliaire à point passé en chaîne (match.fun) est un emploi (issue #74, audit).
section("contrôles : graphe_modules.R, noms passés en chaîne (#74, m1)")
cas_chaine <- function(lecture) .essai("graphe_modules", list("R/dictionnaire.R" = c(".aux <- function(x) x", "dico_f <- function(x) x"),
                                                              "R/lecture.R" = lecture))
r <- cas_chaine("lire_e <- function(x) vapply(x, \".aux\", 1)")
verifier("m1 : vapply(x, \".aux\", 1) vers un auxiliaire à point d'un autre module, lecture.R:1",
         .echoue_en(r, "R/lecture.R", 1L, ".aux"))
r <- cas_chaine(c("lire_e <- function(x) {", "  a <- Reduce(\".aux\", x)", "  b <- Map('.aux', x)", "  a", "}"))
verifier("m1 : Reduce(\".aux\", x), lecture.R:2", .echoue_en(r, "R/lecture.R", 2L, ".aux"))
verifier("m1 : Map('.aux', x) (guillemets simples), lecture.R:3", .echoue_en(r, "R/lecture.R", 3L, ".aux"))
r <- cas_chaine(c("lire_e <- function(x) {", "  y <- list(\".aux\" = 1)", "  z <- x$\".aux\"", "  \".aux\" <- 3",
                  "  w <- \"aux\"", "  v <- \".aux.\"", "  y", "}"))
verifier("m1, cas licites : nom d'argument, champ, cible d'affectation, chaînes voisines (aux, .aux.)", .passe(r))
r <- cas_chaine("lire_e <- function(x) vapply(x, \"dico_f\", 1)")
verifier("m1, limite documentée : un nom de fonction sans point passé en chaîne n'est pas compté (noms de colonnes), le contrôle passe",
         .passe(r))
r <- .essai("graphe_modules", list("R/outils.R" = c(".longueur_commune <- function(n) n", ".composantes_date <- function(j) j", ".jour_de <- function(j) j", AVEC_GRAINE),
                                   "R/donnees.R" = c("donnees_f <- function(x) {", "  .longueur_commune(x)", "  .composantes_date(x)", "  .jour_de(x)", "}")))
verifier("m2 : exceptions déclarées 4, constatées 3 (racine fictive sans plan.R)",
         .passe(r) && any(grepl("4 exception(s) declaree(s), 3 constatee(s)", r$sortie, fixed = TRUE)))
r <- .essai("graphe_modules", list("R/dictionnaire.R" = "dico_f <- function(x) x"))
verifier("m2 : exceptions déclarées 4, constatées 0 (et non « hors des 0 exception(s) déclarée(s) »)",
         .passe(r) && any(grepl("4 exception(s) declaree(s), 0 constatee(s)", r$sortie, fixed = TRUE)) &&
           !any(grepl("hors des 0 exception", r$sortie, fixed = TRUE)))

# --- frontiere_calcul_affichage.R (N4, M236) ----------------------------------------------------
cas_frontiere <- function(lignes) .essai("frontiere_calcul_affichage", list("R/engagement.R" = lignes))

section("contrôles : frontiere_calcul_affichage.R (N4, M236, M400 à M402)")
r <- cas_frontiere(c("f_e <- function(x) {", "  cat(\"x\")", "  set.seed(1)", "  x", "}"))
verifier("témoin positif : cat(), engagement.R:2", .echoue_en(r, "R/engagement.R", 2L, "cat()"))
verifier("témoin positif : set.seed(), engagement.R:3", .echoue_en(r, "R/engagement.R", 3L, "set.seed"))
r <- cas_frontiere(c("f_e <- function(x) {", "  `cat`(\"x\")", "  `set.seed`(1)", "  s <- `.Random.seed`",
                     "  `RNGkind`(\"Mersenne-Twister\")", "  \"cat\"(\"x\")", "  x", "}"))
verifier("N4a : cat entre accents graves, engagement.R:2", .echoue_en(r, "R/engagement.R", 2L, "cat()"))
verifier("N4a : set.seed entre accents graves, engagement.R:3", .echoue_en(r, "R/engagement.R", 3L, "set.seed"))
verifier("N4a : .Random.seed entre accents graves, engagement.R:4", .echoue_en(r, "R/engagement.R", 4L, ".Random.seed"))
verifier("N4a : RNGkind entre accents graves, engagement.R:5", .echoue_en(r, "R/engagement.R", 5L, "RNGkind"))
verifier("N4a : cat par une chaîne en position d'appel, engagement.R:6", .echoue_en(r, "R/engagement.R", 6L, "cat()"))
# N4b, M400 : variable locale = argument formel ou affectée avant la référence (ordre du source).
r <- cas_frontiere("f_e <- function(x) { lapply(x, print); print <- 1; h <- set.seed; set.seed <- 2; x }")
verifier("M400 : témoin de l'issue #62 (une ligne), engagement.R:1 : `lapply(x, print)` puis `print <- 1` refusé",
         .echoue_en(r, "R/engagement.R", 1L, "print (reference sans appel)"))
verifier("M400 : témoin de l'issue #62, `h <- set.seed` puis `set.seed <- 2` refusé, engagement.R:1",
         .echoue_en(r, "R/engagement.R", 1L, "set.seed"))
r <- cas_frontiere(c("f_e <- function(x) {", "  lapply(x, print)", "  print <- 1", "  h <- set.seed", "  set.seed <- 2", "  x", "}"))
verifier("M400 : lecture avant l'affectation, engagement.R:2 (print) et :4 (set.seed)",
         .echoue_en(r, "R/engagement.R", 2L, "print") && .echoue_en(r, "R/engagement.R", 4L, "set.seed"))
verifier("M400 : la cible d'une affectation dans une fonction n'est pas une référence (aucun [ECHEC] aux lignes 3 et 5)",
         !any(startsWith(r$sortie, "[ECHEC] R/engagement.R:3 ")) && !any(startsWith(r$sortie, "[ECHEC] R/engagement.R:5 ")))
r <- cas_frontiere(c("f_e <- function(x) {", "  print <- print", "  x", "}"))
verifier("M400 : `print <- print`, la lecture à droite précède l'affectation, engagement.R:2",
         .echoue_en(r, "R/engagement.R", 2L, "print (reference sans appel)"))
r <- cas_frontiere(c("f_e <- function(x) {", "  g <- function(print) print", "  lapply(x, print)", "}"))
verifier("M400 : l'argument formel d'une fonction sœur ne masque pas, engagement.R:3", .echoue_en(r, "R/engagement.R", 3L, "print"))
r <- cas_frontiere(c("f_e <- function(x) {", "  g <- function() { print <- 1 }", "  lapply(x, print)", "}"))
verifier("M400 : l'affectation dans une fonction fille ne masque pas, engagement.R:3", .echoue_en(r, "R/engagement.R", 3L, "print"))
r <- cas_frontiere(c("f_e <- function(x) {", "  for (i in lapply(x, cat)) i", "  cat <- 1", "  x", "}"))
verifier("M400 : lecture dans la clause d'un for avant l'affectation, engagement.R:2", .echoue_en(r, "R/engagement.R", 2L, "cat"))
r <- cas_frontiere(c("f_e <- function(message, x) {", "  m <- message", "  lapply(x, message)", "  m", "}"))
verifier("M400, cas licite : argument formel homonyme d'une fonction interdite (message)", .passe(r))
r <- cas_frontiere(c("f_e <- function(x) {", "  date <- 1", "  y <- date", "  cat <- function(z) z", "  lapply(x, cat)", "  y", "}"))
verifier("M400, cas licite : variable affectée avant la référence (date, cat)", .passe(r))
r <- cas_frontiere(c("f_e <- function(cat) {", "  g <- function(y) {", "    h <- function() lapply(y, cat)", "    h()", "  }", "  g(1)", "}"))
verifier("M400, cas licite : argument formel d'une fonction englobante, repris dans une fonction fille", .passe(r))
r <- cas_frontiere(c("f_e <- function(x) {", "  g <- \\(cat) cat", "  for (print in x) print", "  lapply(x, print)", "  g(x)", "}"))
verifier("M400, cas licite : fonction anonyme \\(cat) et variable de for", .passe(r))

# Audit de #62 (m1, m2) : local() ouvre une portée ; limites de l'ordre du source.
r <- cas_frontiere(c("f_e <- function(x) {", "  local({ print <- 1 })", "  lapply(x, print)", "}"))
verifier("audit m1 : l'affectation dans local({...}) ne masque pas la lecture qui suit, engagement.R:3", .echoue_en(r, "R/engagement.R", 3L, "print"))
r <- cas_frontiere(c("f_e <- function(x) {", "  local(print <- 1)", "  lapply(x, print)", "}"))
verifier("audit m1 : idem local(print <- 1) (l'affectation est l'argument), engagement.R:3", .echoue_en(r, "R/engagement.R", 3L, "print"))
r <- cas_frontiere(c("f_e <- function(x) {", "  local({ cat <- 1 }, envir = e)", "  lapply(x, cat)", "}"))
verifier("audit m1 : idem avec envir = ..., engagement.R:3", .echoue_en(r, "R/engagement.R", 3L, "cat"))
r <- cas_frontiere(c("f_e <- function(x) {", "  local({ print <- 1; lapply(x, print) })", "  local(expr = { cat <- 1; cat }, envir = new.env())", "}"))
verifier("audit m1, cas licite : la lecture dans la portée de local() après l'affectation", .passe(r))
r <- cas_frontiere(c("f_e <- function(x) {", "  if (x) print <- 1", "  lapply(x, print)", "}"))
verifier("audit m1, limite documentée : affectation conditionnelle, la lecture qui suit est masquée (ordre du source, M400), le contrôle passe",
         .passe(r))
r <- cas_frontiere(c("f_e <- function(x) {", "  for (i in 1:2) { lapply(x, print); print <- 1 }", "  while (x) { lapply(x, cat); cat <- 1 }", "}"))
verifier("audit m2 : lecture en tête de boucle, affectation en queue : refusée (for, engagement.R:2 ; while, :3)",
         .echoue_en(r, "R/engagement.R", 2L, "print") && .echoue_en(r, "R/engagement.R", 3L, "cat"))

# N4c, M401 : sorties console non listées (issue #62).
r <- cas_frontiere(c("f_e <- function(x, f) {", "  str(x)", "  show(x)", "  sink(\"a\")", "  print.default(x)", "  print.foo(x)",
                     "  write(x, \"\")", "  write(x, file = \"\")", "  write(x, stdout())", "  write(file = stderr(), x)",
                     "  write.table(x)", "  write.csv(x, \"\")", "  write.csv(x, file = stdout())", "  lapply(x, write)",
                     "  base::print.default(x)", "  \"str\"(x)", "  x", "}"))
verifier("M401 : str(), engagement.R:2", .echoue_en(r, "R/engagement.R", 2L, "str()"))
verifier("M401 : show(), engagement.R:3", .echoue_en(r, "R/engagement.R", 3L, "show()"))
verifier("M401 : sink(), engagement.R:4", .echoue_en(r, "R/engagement.R", 4L, "sink()"))
verifier("M401 : print.default(), engagement.R:5", .echoue_en(r, "R/engagement.R", 5L, "print.default()"))
verifier("M401 : appel direct d'une méthode print.*, engagement.R:6", .echoue_en(r, "R/engagement.R", 6L, "print.foo()"))
verifier("M401 : write(x, \"\") (file en deuxième position), engagement.R:7", .echoue_en(r, "R/engagement.R", 7L, "write() vers la console"))
verifier("M401 : write(x, file = \"\"), engagement.R:8", .echoue_en(r, "R/engagement.R", 8L, "write() vers la console"))
verifier("M401 : write(x, stdout()), engagement.R:9", .echoue_en(r, "R/engagement.R", 9L, "write() vers la console"))
verifier("M401 : write(file = stderr(), x), engagement.R:10", .echoue_en(r, "R/engagement.R", 10L, "write() vers la console"))
verifier("M401 : write.table(x) (défaut file = \"\" : la console), engagement.R:11", .echoue_en(r, "R/engagement.R", 11L, "write.table() vers la console"))
verifier("M401 : write.csv(x, \"\"), engagement.R:12", .echoue_en(r, "R/engagement.R", 12L, "write.csv() vers la console"))
verifier("M401 : write.csv(x, file = stdout()), engagement.R:13", .echoue_en(r, "R/engagement.R", 13L, "write.csv() vers la console"))
verifier("M401 : référence sans appel à write, engagement.R:14", .echoue_en(r, "R/engagement.R", 14L, "write (reference sans appel)"))
verifier("M401 : base::print.default(), engagement.R:15", .echoue_en(r, "R/engagement.R", 15L, "print.default()"))
verifier("M401 : str par une chaîne en position d'appel, engagement.R:16", .echoue_en(r, "R/engagement.R", 16L, "str()"))
r <- cas_frontiere(c("f_e <- function(x, f) {", "  write(x, \"a.txt\")", "  write(x)", "  write(x, f)", "  write(x, \"a.txt\", \"\")",
                     "  write.csv(x, f)", "  write.table(x, file = \"a.csv\")", "  write.table(x, ...)", "  format.foo(x)",
                     "  y <- x$str", "  show <- 1", "  show", "  x", "}"))
verifier("M401, cas licites : write vers un fichier ou une variable (défaut file = \"data\"), write.* vers un fichier, ... : indécidable, format.foo(x), champ x$str, variable show",
         .passe(r))
r <- cas_frontiere(c("print.fiche <- function(x, ...) {", "  print.default(x)", "  write(x, \"\")", "  str(x)", "  sink(NULL)",
                     "  print.foo(x)", "  write.table(x)", "  write.dcf(x)", "  write.csv2(x)", "  invisible(x)", "}"))
verifier("M401, cas licite : une méthode print.* reste exemptée des sorties console", .passe(r))

# Audit de #62 (m3, m4) : correspondance partielle des noms d'arguments, stdout() préfixé.
r <- cas_frontiere(c("f_e <- function(x) {", "  write(x, f = \"\")", "  write(x, fi = \"\")", "  write(x, a = TRUE, \"\")",
                     "  write.dcf(x, fi = \"\")", "  write(x, base::stdout())", "  write(x, base:::stderr())",
                     "  write(file = base::stdout(), x)", "  x", "}"))
verifier("audit m3 : write(x, f = \"\") (correspondance partielle), engagement.R:2", .echoue_en(r, "R/engagement.R", 2L, "write() vers la console"))
verifier("audit m3 : write(x, fi = \"\"), engagement.R:3", .echoue_en(r, "R/engagement.R", 3L, "write() vers la console"))
verifier("audit m3 : write(x, a = TRUE, \"\") (append partiel, file en position), engagement.R:4", .echoue_en(r, "R/engagement.R", 4L, "write() vers la console"))
verifier("audit m3 : write.dcf(x, fi = \"\"), engagement.R:5", .echoue_en(r, "R/engagement.R", 5L, "write.dcf() vers la console"))
verifier("audit m4 : write(x, base::stdout()), engagement.R:6", .echoue_en(r, "R/engagement.R", 6L, "write() vers la console"))
verifier("audit m4 : write(x, base:::stderr()), engagement.R:7", .echoue_en(r, "R/engagement.R", 7L, "write() vers la console"))
verifier("audit m4 : write(file = base::stdout(), x), engagement.R:8", .echoue_en(r, "R/engagement.R", 8L, "write() vers la console"))
r <- cas_frontiere(c("f_e <- function(x) {", "  write.dcf(x, f = \"a\")", "  write.dcf(x, fi = \"a\")", "  write(x, foo::stdout())",
                     "  write(x, a = TRUE, \"a.txt\")", "  x", "}"))
verifier("audit m3, cas licite : write.dcf(x, f = \"a\") écrit dans un fichier ; stdout() d'un autre package ; append partiel avec un fichier",
         .passe(r))

# M411 : write.csv2 et write.dcf (défaut file = "" : la console).
r <- cas_frontiere(c("f_e <- function(x, f) {", "  write.csv2(x)", "  write.csv2(x, \"\")", "  write.csv2(x, file = stdout())",
                     "  write.dcf(x)", "  write.dcf(x, file = \"\")", "  write.dcf(x, stderr())", "  lapply(x, write.dcf)", "  x", "}"))
verifier("M411 : write.csv2(x) (défaut : la console), engagement.R:2", .echoue_en(r, "R/engagement.R", 2L, "write.csv2() vers la console"))
verifier("M411 : write.csv2(x, \"\"), engagement.R:3", .echoue_en(r, "R/engagement.R", 3L, "write.csv2() vers la console"))
verifier("M411 : write.csv2(x, file = stdout()), engagement.R:4", .echoue_en(r, "R/engagement.R", 4L, "write.csv2() vers la console"))
verifier("M411 : write.dcf(x) (défaut file = \"\"), engagement.R:5", .echoue_en(r, "R/engagement.R", 5L, "write.dcf() vers la console"))
verifier("M411 : write.dcf(x, file = \"\"), engagement.R:6", .echoue_en(r, "R/engagement.R", 6L, "write.dcf() vers la console"))
verifier("M411 : write.dcf(x, stderr()), engagement.R:7", .echoue_en(r, "R/engagement.R", 7L, "write.dcf() vers la console"))
verifier("M411 : référence sans appel à write.dcf, engagement.R:8", .echoue_en(r, "R/engagement.R", 8L, "write.dcf (reference sans appel)"))
r <- cas_frontiere(c("f_e <- function(x, f) {", "  write.csv2(x, f)", "  write.csv2(x, file = \"a.csv\")", "  write.dcf(x, \"a.dcf\")",
                     "  write.dcf(x, file = f)", "  x", "}"))
verifier("M411, cas licite : write.csv2 et write.dcf vers un fichier ou une variable", .passe(r))

# Revue de #62 : arguments vides dans le calcul de `file`, champ homonyme d'une écriture, affectation
# hors de toute fonction mais pas au premier niveau.
r <- cas_frontiere(c("f_e <- function(x) {", "  write.table(x, , \"a\")", "  write.table(x, , )", "  write.csv(x, file = )",
                     "  write.csv2(x, , FALSE)", "  write.dcf(x, , \"a\")", "  x", "}"))
verifier("revue #62 : write.table(x, , \"a\") (file vide, \"a\" est append : la console), engagement.R:2",
         .echoue_en(r, "R/engagement.R", 2L, "write.table() vers la console"))
verifier("revue #62 : write.table(x, , ) (deux arguments vides), engagement.R:3", .echoue_en(r, "R/engagement.R", 3L, "write.table() vers la console"))
verifier("revue #62 : write.csv(x, file = ) (file nommé et vide), engagement.R:4", .echoue_en(r, "R/engagement.R", 4L, "write.csv() vers la console"))
verifier("revue #62 : write.csv2(x, , FALSE), engagement.R:5", .echoue_en(r, "R/engagement.R", 5L, "write.csv2() vers la console"))
verifier("revue #62 : write.dcf(x, , \"a\"), engagement.R:6", .echoue_en(r, "R/engagement.R", 6L, "write.dcf() vers la console"))
r <- cas_frontiere(c("f_e <- function(x, f) {", "  write(x, , \"a\")", "  write(x, file = , 1)", "  write.table(x, \"a.csv\", )",
                     "  write.table(x, f, , )", "  write.csv(x, , , f)", "  x", "}"))
verifier("revue #62, cas licites : write(x, , \"a\") (défaut file = \"data\"), file en position malgré un argument vide final ou intermédiaire",
         !any(startsWith(r$sortie, "[ECHEC] R/engagement.R:2 ")) && !any(startsWith(r$sortie, "[ECHEC] R/engagement.R:3 ")) &&
           !any(startsWith(r$sortie, "[ECHEC] R/engagement.R:4 ")) && !any(startsWith(r$sortie, "[ECHEC] R/engagement.R:5 ")))
verifier("revue #62 : write.csv(x, , , f) : file vide, console (f est le troisième argument, append), engagement.R:6",
         .echoue_en(r, "R/engagement.R", 6L, "write.csv() vers la console"))
r <- cas_frontiere(c("f_e <- function(x) {", "  x$write.table(x)", "  x$write(x)", "  x@write.csv(x)", "  x$write.dcf(x, \"\")",
                     "  x$print.foo(x)", "  x", "}"))
verifier("revue #62 : x$write.table(x) et les autres champs homonymes d'une écriture : licites, appel de champ comme pour les autres noms",
         .passe(r))
r <- cas_frontiere(c("if (FALSE) { print <- NULL }", "g_e <- function(x) lapply(x, print)", "print <- 1",
                     "h_e <- function(x) lapply(x, print)"))
verifier("revue #62 : `if (FALSE) { print <- NULL }` au niveau du fichier ne masque rien : la cible (engagement.R:1) et les lectures (:2, :4) sont comptées",
         .echoue_en(r, "R/engagement.R", 1L, "print") && .echoue_en(r, "R/engagement.R", 2L, "print") &&
           .echoue_en(r, "R/engagement.R", 4L, "print"))
verifier("revue #62 : `print <- 1` au premier niveau est compté comme avant (engagement.R:3)", .echoue_en(r, "R/engagement.R", 3L, "print"))
r <- cas_frontiere(c("for (cat in 1:2) 1", "g_e <- function(x) lapply(x, cat)"))
verifier("revue #62 : variable de for au niveau du fichier : comptée, ne masque pas la lecture qui suit (engagement.R:1 et :2)",
         .echoue_en(r, "R/engagement.R", 1L, "cat") && .echoue_en(r, "R/engagement.R", 2L, "cat"))
r <- cas_frontiere(c("g_e <- function(x) {", "  if (x) { print <- 1 }", "  for (cat in 1:2) cat", "  lapply(x, print)", "  lapply(x, cat)", "}"))
verifier("revue #62, cas licite : une affectation ou une variable de for dans une fonction masque toujours (portée de la fonction)", .passe(r))

# N4e, M402 et M410 : l'horloge est interdite dans une méthode format.* comme dans print.*.
r <- cas_frontiere(c("print.fiche <- function(x, ...) {", "  cat(\"x\")", "  a <- Sys.time()", "  b <- Sys.Date()", "  c <- date()",
                     "  d <- Sys.time", "  invisible(x)", "}"))
verifier("M410 : Sys.time() dans print.*, engagement.R:3", .echoue_en(r, "R/engagement.R", 3L, "Sys.time()"))
verifier("M410 : Sys.Date() dans print.*, engagement.R:4", .echoue_en(r, "R/engagement.R", 4L, "Sys.Date()"))
verifier("M410 : date() dans print.*, engagement.R:5", .echoue_en(r, "R/engagement.R", 5L, "date()"))
verifier("M410 : référence sans appel à Sys.time dans print.*, engagement.R:6", .echoue_en(r, "R/engagement.R", 6L, "Sys.time (reference sans appel)"))
verifier("M410 : la sortie console cat() reste admise dans print.* (aucun ECHEC à la ligne 2)",
         !any(startsWith(r$sortie, "[ECHEC] R/engagement.R:2 ")))
r <- cas_frontiere(c("print.fiche <- function(x, ...) {", "  print.default(x)", "  str(x)", "  invisible(x)", "}"))
verifier("M410, cas licite : print.* sans horloge, avec ses sorties console", .passe(r))
r <- cas_frontiere("format.fiche_essai <- function(x, ...) paste(x, Sys.time())")
verifier("M402 : témoin de l'issue #62, Sys.time() dans format.*, engagement.R:1", .echoue_en(r, "R/engagement.R", 1L, "Sys.time()"))
r <- cas_frontiere(c("format.fiche_essai <- function(x, ...) {", "  a <- Sys.Date()", "  b <- date()", "  c <- Sys.time", "  paste(x, a, b)", "}"))
verifier("M402 : Sys.Date(), engagement.R:2", .echoue_en(r, "R/engagement.R", 2L, "Sys.Date()"))
verifier("M402 : date(), engagement.R:3", .echoue_en(r, "R/engagement.R", 3L, "date()"))
verifier("M402 : référence sans appel à Sys.time, engagement.R:4", .echoue_en(r, "R/engagement.R", 4L, "Sys.time (reference sans appel)"))
r <- cas_frontiere(c("format.fiche_essai <- function(x, ...) {", "  cat(\"x\")", "  print(x)", "  paste(x, format(x))", "}"))
verifier("M402, cas licite : format.* qui écrit sans lire l'horloge (exemption des sorties console conservée)", .passe(r))
r <- cas_frontiere(c("f_e <- function(x) {", "  a <- Sys.time()", "  x", "}"))
verifier("M402 : l'horloge hors d'une méthode reste refusée, engagement.R:2", .echoue_en(r, "R/engagement.R", 2L, "Sys.time()"))
r <- cas_frontiere(c("format.fiche_essai <- function(x, ...) {", "  Sys.time <- function() 1", "  paste(x, Sys.time())", "}"))
verifier("M402 : l'appel d'une fonction locale homonyme de l'horloge reste refusé (les appels ne sont pas masqués), engagement.R:3",
         .echoue_en(r, "R/engagement.R", 3L, "Sys.time()"))
r <- cas_frontiere(c("f_e <- function(input, x) {", "  a <- eventReactive(x, x)",
                     "  b <- input[[\"choix\"]]", "  req(x)", "  s <- session$userData", "  o <- output$sortie",
                     "  updateSelectInput(session, \"id\")", "  showNotification(\"m\")", "  bindEvent(x)",
                     "  reactivePoll(1, session)", "  validate(need(x, \"m\"))", "  x", "}"))
verifier("N4d : eventReactive, engagement.R:2", .echoue_en(r, "R/engagement.R", 2L, "eventReactive()"))
verifier("N4d : input[[, engagement.R:3", .echoue_en(r, "R/engagement.R", 3L, "input[["))
verifier("N4d : req, engagement.R:4", .echoue_en(r, "R/engagement.R", 4L, "req()"))
verifier("N4d : session$, engagement.R:5", .echoue_en(r, "R/engagement.R", 5L, "session$"))
verifier("N4d : output$, engagement.R:6", .echoue_en(r, "R/engagement.R", 6L, "output$"))
verifier("N4d : update*, engagement.R:7", .echoue_en(r, "R/engagement.R", 7L, "updateSelectInput()"))
verifier("N4d : showNotification, engagement.R:8", .echoue_en(r, "R/engagement.R", 8L, "showNotification()"))
verifier("N4d : bindEvent, engagement.R:9", .echoue_en(r, "R/engagement.R", 9L, "bindEvent()"))
verifier("N4d : reactivePoll, engagement.R:10", .echoue_en(r, "R/engagement.R", 10L, "reactivePoll()"))
verifier("N4d : validate et need, engagement.R:11", .echoue_en(r, "R/engagement.R", 11L, "validate()") &&
           .echoue_en(r, "R/engagement.R", 11L, "need()"))
r <- cas_frontiere(c("f_e <- function(x) {", "  y <- x$input", "  z <- list(update = 1, required = 2)", "  y", "}"))
verifier("N4d, cas licite : champs et noms qui ressemblent à Shiny", .passe(r))
r <- cas_frontiere(c("f_e <- function(x) {", "  output <- list()", "  output$provision <- x", "  output", "}"))
verifier("C3 : output local (affecte) et son champ : licite", .passe(r))
r <- cas_frontiere(c("f_e <- function(x, session) {", "  y <- session$userData", "  x", "}"))
verifier("C3 : session argument formel de la definition : licite", .passe(r))
r <- cas_frontiere(c("f_e <- function(x) {", "  output$provision <- x", "  x", "}"))
verifier("C3 : output$ non local reste refuse, engagement.R:2", .echoue_en(r, "R/engagement.R", 2L, "output$"))
# M236 : commentaires accentués admis ; une chaîne ou un nom accentué reste refusé (M112).
r <- cas_frontiere(c("# Commentaire accentu\u00e9 : d\u00e9c\u00e8s", "#' @param x montant (\u20ac)",
                     "f_e <- function(x) {", "  y <- x  # fin de ligne accentu\u00e9e", "  y", "}"))
verifier("M236 : commentaires accentués admis, le contrôle passe", .passe(r))
r <- cas_frontiere(c("f_e <- function(x) {", "  m <- \"d\u00e9c\u00e8s\"", "  x", "}"))
verifier("M236 : chaîne \"décès\" refusée, engagement.R:2", .echoue_en(r, "R/engagement.R", 2L, "M112"))
r <- cas_frontiere(c("f_e <- function(x) {", "  x", "}", "\u00e9t\u00e9 <- 1"))
verifier("M236 : nom accentué refusé (non ASCII dans le code ou fichier non analysable, avec renvoi à M112)",
         r$statut == 1L && any(startsWith(r$sortie, "[ECHEC] R/engagement.R")) &&
           any(grepl("M112", r$sortie, fixed = TRUE)))

# --- preambule_latex.R (N5) ---------------------------------------------------------------------
charte <- readLines(file.path(racine, "docs", "latex", "charte_graphique.tex"), encoding = "UTF-8", warn = FALSE)
cas_latex <- function(...) .essai("preambule_latex", c(list("docs/latex/charte_graphique.tex" = charte), list(...)))
ARTICLE <- c("\\documentclass{article}", "\\begin{document}", "x", "\\end{document}")

section("contrôles : preambule_latex.R (N5)")
r <- cas_latex("docs/latex/doc.tex" = charte)
verifier("cas licite : un document dont le préambule est celui de la charte", .passe(r))
r <- cas_latex("docs/latex/doc.tex" = append(charte, "\\usepackage{xcolor}", after = 16L))
verifier("témoin positif : une ligne en trop dans le préambule, doc.tex:17", .echoue_en(r, "docs/latex/doc.tex", 17L))
r <- cas_latex("docs/latex/annexes/annexe.tex" = ARTICLE, "docs/notes/note.tex" = ARTICLE)
verifier("N5a : sous-dossier de docs/latex/, annexe.tex:1", .echoue_en(r, "docs/latex/annexes/annexe.tex", 1L))
verifier("N5a : hors de docs/latex/, note.tex:1", .echoue_en(r, "docs/notes/note.tex", 1L))
r <- cas_latex("docs/latex/autre.TEX" = ARTICLE)
verifier("N5a : extension en majuscules, autre.TEX:1", .echoue_en(r, "docs/latex/autre.TEX", 1L))
r <- cas_latex("docs/latex/partie_outils.tex" = c("\\section{Module outils}", "Texte."))
verifier("N5b : un fragment sans \\documentclass est ignoré", .passe(r))
r <- cas_latex("docs/latex/doc.tex" = c("\\newcommand{\\debut}{\\begin{document}}", charte))
verifier("N5c : \\begin{document} dans une macro avant \\documentclass : ligne >= 1, doc.tex:1",
         .echoue_en(r, "docs/latex/doc.tex", 1L))

# --- recensement_tolerances.R (#79) ---------------------------------------------------------------
cas_recensement <- function(lignes) .essai("recensement_tolerances", list("tests/unitaires/temoin.R" = lignes))

section("contrôles : recensement_tolerances.R (#79)")
r <- cas_recensement(c("TOL <- 1e-10",
                       "verifier_egal(\"a\", c(1e8, 100), c(1e8, 100), tolerance = TOL)",
                       "verifier_egal(\"b\", 1, 1)",
                       "verifier_egal(\"c\", 1, 1, tolerance = 0)",
                       "verifier_egal(\"d\", c(1, 2), c(1, 2), 1e-8)",
                       "verifier_egal(\"e\", x, list(a = z), tolerance = 1e-8)",
                       "verifier(\"f\", isTRUE(all.equal(x, c(1, 100), tolerance = 1e-9)))"))
verifier("recensement : statut 0 (sortie informative, aucun [ECHEC])", .passe(r))
verifier("recensement : trois appels de verifier_egal() à tolérance > 0 (symbole, positionnelle, littérale), ni sans tolérance ni à 0",
         any(grepl("a tolerance > 0 : 3 appels", r$sortie, fixed = TRUE)))
verifier("recensement : l'appel d'ordres différents est signalé à sa ligne (temoin.R:2, tolérance 1e-10, max/min = 1e+06)",
         any(grepl("tests/unitaires/temoin.R:2 tolerance 1e-10 2 feuilles, max/min = 1e+06", r$sortie, fixed = TRUE)))
verifier("recensement : un composite non évaluable est indéterminé (temoin.R:6)",
         any(grepl("tests/unitaires/temoin.R:6 tolerance 1e-08", r$sortie, fixed = TRUE)))
verifier("recensement : l'appel direct de all.equal(tolerance = ...) est listé à part (temoin.R:7)",
         any(grepl("tests/unitaires/temoin.R:7 tolerance 1e-09", r$sortie, fixed = TRUE)))
# Aucun argument n'est execute hors liste blanche (environnement de parent emptyenv()).
effet <- tempfile("effet-")
r <- cas_recensement(c(sprintf("verifier_egal(\"a\", x, {file.create(\"%s\"); c(1, 100)}, tolerance = 1e-8)", effet),
                       sprintf("verifier_egal(\"b\", x, c(file.create(\"%s\"), 1), tolerance = 1e-8)", effet)))
verifier("recensement : un argument à effet de bord n'est pas exécuté (fichier non créé), il est indéterminé (temoin.R:1 et :2)",
         .passe(r) && !file.exists(effet) && any(grepl("tests/unitaires/temoin.R:1 tolerance 1e-08", r$sortie, fixed = TRUE)) &&
           any(grepl("tests/unitaires/temoin.R:2 tolerance 1e-08", r$sortie, fixed = TRUE)))
unlink(effet)
r <- cas_recensement(c("verifier_egal(\"a\", x, quit(status = 0), tolerance = 1e-8)",
                       "verifier_egal(\"b\", x, c(1e8, 100), tolerance = 1e-8)"))
verifier("recensement : un quit() dans un argument n'interrompt pas le recensement, qui va à son terme (temoin.R:2 signalé, appels all.equal listés)",
         .passe(r) && any(grepl("tests/unitaires/temoin.R:1 tolerance 1e-08", r$sortie, fixed = TRUE)) &&
           any(grepl("tests/unitaires/temoin.R:2 tolerance 1e-08 2 feuilles", r$sortie, fixed = TRUE)) &&
           any(grepl("all.equal(tolerance = ...) direct", r$sortie, fixed = TRUE)))
r <- cas_recensement(c("verifier_egal(\"a\", x, calcule(1, \"exact\"), tolerance = 1e-8)"))
verifier("recensement : un appel de fonction hors liste blanche est indéterminé et listé (temoin.R:1)",
         .passe(r) && any(grepl("INDETERMINE (non evaluable sans les donnees des tests, a controler) : 1 appels", r$sortie, fixed = TRUE)) &&
           any(grepl("tests/unitaires/temoin.R:1 tolerance 1e-08", r$sortie, fixed = TRUE)))
r <- cas_recensement(c("f <- function( {"))
verifier("recensement : un fichier non analysable est un échec, temoin.R", .echoue_en(r, "tests/unitaires/temoin.R"))

# Revue de #79 : appels préfixés ou entre accents graves, arguments non appariables, petites valeurs.
r <- cas_recensement(c("base::all.equal(x, c(1, 100), tolerance = 1e-9)",
                       "`verifier_egal`(\"a\", x, c(1e8, 100), tolerance = 1e-8)",
                       "base:::all.equal(x, c(1, 100), tolerance = 1e-7)",
                       "x$verifier_egal(\"b\", 1, 1, tolerance = 1e-8)"))
verifier("recensement : `base::all.equal(...)` et `verifier_egal`(...) sont reconnus des deux côtés : statut 0, pas de « recensement incoherent »",
         .passe(r) && !any(grepl("incoherent", r$sortie, fixed = TRUE)))
verifier("recensement : l'appel entre accents graves est recensé (temoin.R:2, ordres différents) ; le champ x$verifier_egal(...) n'est pas un appel (un seul appel de verifier_egal)",
         any(grepl("a tolerance > 0 : 1 appels", r$sortie, fixed = TRUE)) &&
           any(grepl("tests/unitaires/temoin.R:2 tolerance 1e-08 2 feuilles, max/min = 1e+06", r$sortie, fixed = TRUE)) &&
           any(grepl("appels de verifier_egal() : 1", r$sortie, fixed = TRUE)))
verifier("recensement : base::all.equal et base:::all.equal sont listés avec leur ligne (temoin.R:1 et :3)",
         any(grepl("direct (hors verifier_egal) : 2 appels", r$sortie, fixed = TRUE)) &&
           any(grepl("tests/unitaires/temoin.R:1 tolerance 1e-09", r$sortie, fixed = TRUE)) &&
           any(grepl("tests/unitaires/temoin.R:3 tolerance 1e-07", r$sortie, fixed = TRUE)))
r <- cas_recensement("\"all.equal\"(x, 1, tolerance = 1e-9)")
verifier("TEMOIN : un appel que l'arbre compte et que l'analyse du source ne voit pas (nom écrit en chaîne) : « recensement incoherent », échec, statut 1",
         .echoue_en(r, "tests/unitaires/temoin.R", NA_integer_, "recensement incoherent pour all.equal : 1 appels dans l'arbre, 0 dans l'analyse du source"))
r <- cas_recensement(c("f <- function(...) verifier_egal(\"a\", ..., tolerance = 1e-8)",
                       "verifier_egal(\"b\", x, c(1e8, 100), tolerance = 1e-8)",
                       "verifier_egal(1, 2, 3, 4, 5, tolerance = 1e-8)",
                       "g <- function(...) all.equal(x, ..., tolerance = 1e-9)",
                       "h <- function(...) verifier_egal(\"c\", ..., tolerance = 0)"))
verifier("recensement : `...` transmis ou argument en trop : le script ne plante pas, le recensement va à son terme (statut 0, aucun [ECHEC])",
         .passe(r) && any(grepl("appels de verifier_egal() : 4", r$sortie, fixed = TRUE)) &&
           any(grepl("all.equal(tolerance = ...) direct (hors verifier_egal) : 1 appels", r$sortie, fixed = TRUE)))
verifier("recensement : ces appels sont indéterminés et listés avec leur tolérance lue (temoin.R:1 et :3), le troisième appel est signalé (temoin.R:2) ; tolerance = 0 non recensé",
         any(grepl("INDETERMINE (non evaluable sans les donnees des tests, a controler) : 2 appels", r$sortie, fixed = TRUE)) &&
           any(grepl("tests/unitaires/temoin.R:1 tolerance 1e-08 arguments non appariables", r$sortie, fixed = TRUE)) &&
           any(grepl("tests/unitaires/temoin.R:3 tolerance 1e-08 arguments non appariables", r$sortie, fixed = TRUE)) &&
           any(grepl("tests/unitaires/temoin.R:2 tolerance 1e-08 2 feuilles", r$sortie, fixed = TRUE)) &&
           !any(grepl("temoin.R:5 ", r$sortie, fixed = TRUE)))
r <- cas_recensement(c("verifier_egal(\"p\", x, c(1e-5, 2e-5), tolerance = 1e-10)",
                       "verifier_egal(\"q\", x, 1e-5, tolerance = 1e-10)",
                       "verifier_egal(\"r\", x, 6e-4, tolerance = 1e-10)",
                       "verifier_egal(\"s\", x, 7e-4, tolerance = 1e-10)",
                       "verifier_egal(\"t\", x, c(0, 1), tolerance = 1e-10)",
                       "verifier_egal(\"u\", x, 0.05, tolerance = 1e-8)",
                       "verifier_egal(\"v\", x, c(1, 0.5), tolerance = 1e-10)",
                       "verifier(\"w\", isTRUE(all.equal(x, c(1e-5, 2e-5), tolerance = 1e-9)))"))
verifier("recensement : une valeur attendue de petites valeurs (|r| non nul < tolérance / 1.5e-7) est listée sous PETITES VALEURS, sans [ECHEC] (informatif) : quatre appels",
         .passe(r) && any(grepl("^\\[INFO\\] PETITES VALEURS .* : 4 appels$", r$sortie)))
verifier("recensement : PETITES VALEURS : temoin.R:1 (vecteur, 1e-05), :2 (scalaire), :3 (6e-04 sous le seuil 6.67e-04 de 1e-10), :6 (0.05 sous le seuil 0.0667 de 1e-8)",
         any(grepl("temoin.R:1 tolerance 1e-10, plus petit |r| non nul = 1e-05", r$sortie, fixed = TRUE)) &&
           any(grepl("temoin.R:2 tolerance 1e-10, plus petit |r| non nul = 1e-05", r$sortie, fixed = TRUE)) &&
           any(grepl("temoin.R:3 tolerance 1e-10, plus petit |r| non nul = 0.0006", r$sortie, fixed = TRUE)) &&
           any(grepl("temoin.R:6 tolerance 1e-08, plus petit |r| non nul = 0.05", r$sortie, fixed = TRUE)))
verifier("recensement : hors PETITES VALEURS : 7e-4 (au-dessus du seuil), une valeur nulle, des valeurs de l'ordre de 1, et all.equal (tolérance relative)",
         !any(grepl("temoin.R:[4578] tolerance [^ ]*, plus petit", r$sortie)))
verifier("recensement : la classe d'ordres n'est pas modifiée (le vecteur 1e-5, 2e-5 reste homogène : p et v sont homogènes, les cinq autres scalaires)",
         any(grepl("classement de l'argument attendu : .*homogene = 2, .*scalaire = 5", r$sortie)))
r <- cas_recensement(c("verifier_egal(\"a\", x, 2, tolerance = 1e-6)",
                       "verifier_egal(\"b\", x, 10, tolerance = 1e-6)",
                       "verifier_egal(\"c\", x, 0.5, tolerance = 1e-6)",
                       "verifier_egal(\"d\", x, 0.5, tolerance = 1e-10)"))
verifier("recensement : le seuil des petites valeurs est borné à 1, min(1, tolérance / 1.5e-7) : à tolérance 1e-6, 2 et 10 ne sont pas signalés (tolérance relative), 0.5 l'est (seuil 1) ; à 1e-10, 0.5 n'est pas signalé (inchangé)",
         .passe(r) && any(grepl("^\\[INFO\\] PETITES VALEURS .* : 1 appels$", r$sortie)) &&
           any(grepl("temoin.R:3 tolerance 1e-06, plus petit |r| non nul = 0.5 (seuil 1)", r$sortie, fixed = TRUE)) &&
           !any(grepl("temoin.R:[124] tolerance [^ ]*, plus petit", r$sortie)))
