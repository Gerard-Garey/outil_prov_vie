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
r2 <- .essai("graphe_modules", list("R/outils.R" = "ecrire_dans <- function(e) assign(\"a\", 1, envir = e)"))
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

# --- frontiere_calcul_affichage.R (N4, M236) ----------------------------------------------------
cas_frontiere <- function(lignes) .essai("frontiere_calcul_affichage", list("R/engagement.R" = lignes))

section("contrôles : frontiere_calcul_affichage.R (N4, M236)")
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
# N4b : faux négatif connu (issue ouverte à part) : la variable locale masque la référence.
r <- cas_frontiere(c("f_e <- function(x) {", "  lapply(x, print)", "  print <- 1", "  x", "}"))
verifier("N4b, limite documentée : `lapply(x, print)` masqué par `print <- 1` (faux négatif connu), le contrôle passe",
         .passe(r))
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
