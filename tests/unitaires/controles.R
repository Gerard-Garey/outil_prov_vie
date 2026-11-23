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
# Un vecteur `raw` est écrit tel quel (octets de contrôle, que charToRaw() ne sait pas rendre pour 0x00).
.deposer <- function(chemin, lignes) {
  dir.create(dirname(chemin), recursive = TRUE, showWarnings = FALSE)
  if (is.raw(lignes)) return(writeBin(lignes, chemin))
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

# C5 (voie `git ls-files` d'absence_java.R) : témoins dans tests/unitaires/voie_git.R (#186).
# Aucun fichier R analysé (tests/ sans fichier R) : rbind d'une liste vide vaudrait NULL (revue finale de Bo2, C-1).
r <- .essai("recensement_tolerances", list("tests/vide.txt" = "aucun fichier R"))
verifier("recensement : une racine sans fichier R donne le statut 0, sans [ECHEC] ni ligne [INFO] vide, et la rubrique « 0 marques »",
         .passe(r) && any(grepl("fichiers analyses : 0 ", r$sortie, fixed = TRUE)) &&
           any(grepl("ORPHELINES .* : 0 marques$", r$sortie)) && !any(r$sortie == "[INFO] "))

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

# Identifiants à point employés hors de leur fichier (#74, M405 ; quatre exceptions renvoyées à #102, retirées).
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
# Exceptions déclarées (EXCEPTIONS_POINT, vide depuis #102). Les quatre auxiliaires que la liste
# déclarait, rendus à un module voisin sous leur ancien nom, sont de nouveau refusés ; le
# mécanisme des exceptions s'éprouve sur une copie du script dont la liste est remplie.
OUTILS_POINT <- c(".longueur_commune <- function(n) n", ".composantes_date <- function(j) j", ".jour_de <- function(j) j", AVEC_GRAINE)
r <- .essai("graphe_modules", list(
  "R/outils.R" = OUTILS_POINT,
  "R/donnees.R" = c("donnees_f <- function(x) {", "  .longueur_commune(x)", "  .composantes_date(x)", "  .jour_de(x)", "}")))
verifier("#102 : les anciennes exceptions ne sont plus déclarées, donnees.R:2, 3 et 4 refusés", {
  .echoue_en(r, "R/donnees.R", 2L, ".longueur_commune") && .echoue_en(r, "R/donnees.R", 3L, ".composantes_date") &&
    .echoue_en(r, "R/donnees.R", 4L, ".jour_de")
})
# Copie du script de contrôle dont EXCEPTIONS_POINT est remplie (insertion avant la
# déclaration suivante) ; lancée sur la copie temporaire de `fichiers`.
.essai_exceptions <- function(fichiers, declaration) {
  lignes <- readLines(.script_controle("graphe_modules"), warn = FALSE)
  k <- grep("^EXCEPTIONS_INTROSPECTION <- data.frame\\(", lignes)
  if (length(k) != 1L) return(list(statut = NA_integer_, sortie = "marque d'insertion introuvable"))
  script <- tempfile("graphe_exceptions-", fileext = ".R")
  on.exit(unlink(script), add = TRUE)
  writeLines(append(lignes, declaration, after = k - 1L), script)
  copie <- tempfile("temoin-")
  dir.create(copie)
  on.exit(unlink(copie, recursive = TRUE), add = TRUE)
  for (chemin in names(fichiers)) .deposer(file.path(copie, chemin), fichiers[[chemin]])
  sortie <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"), c(shQuote(script), shQuote(copie)),
                                     stdout = TRUE, stderr = TRUE))
  statut <- attr(sortie, "status")
  list(statut = if (is.null(statut)) 0L else statut, sortie = sortie)
}
DECLARATION_FICTIVE <- paste0("EXCEPTIONS_POINT <- data.frame(appelant = rep(\"donnees\", 3L), ",
                              "identifiant = c(\".longueur_commune\", \".composantes_date\", \".jour_de\"), ",
                              "defini_dans = rep(\"outils\", 3L), renvoi = \"#fictif\", stringsAsFactors = FALSE)")
r <- .essai_exceptions(list(
  "R/outils.R" = OUTILS_POINT,
  "R/donnees.R" = c("donnees_f <- function(x) {", "  .longueur_commune(x)", "  .composantes_date(x)", "  .jour_de(x)", "}")),
  DECLARATION_FICTIVE)
verifier("#74, cas licite : emplois déclarés en exception, le contrôle passe (3 déclarées, 3 constatées)",
         .passe(r) && any(grepl("3 exception(s) declaree(s), 3 constatee(s)", r$sortie, fixed = TRUE)))
r <- .essai_exceptions(list(
  "R/outils.R" = OUTILS_POINT,
  "R/donnees.R" = c("donnees_f <- function(x) {", "  .longueur_commune(x)", "  .jour_de(x)", "}")),
  DECLARATION_FICTIVE)
verifier("#74 : exception déclarée qui ne se produit plus (.composantes_date), donnees.R sans ligne", {
  .echoue_en(r, "R/donnees.R", NA_integer_, ".composantes_date") &&
    !any(grepl("[ECHEC] R/donnees.R:", r$sortie, fixed = TRUE))
})
r <- .essai_exceptions(list(
  "R/outils.R" = OUTILS_POINT,
  "R/donnees.R" = c("donnees_f <- function(x) {", "  .longueur_commune(x)", "  .composantes_date(x)", "  .jour_de(x)", "  .autre(x)", "}"),
  "R/dictionnaire.R" = ".autre <- function(x) x"),
  DECLARATION_FICTIVE)
verifier("#74 : un emploi non déclaré à côté d'exceptions tenues, donnees.R:5", .echoue_en(r, "R/donnees.R", 5L, ".autre"))
r <- .essai_exceptions(list("R/outils.R" = OUTILS_POINT, "R/donnees.R" = "donnees_f <- function(x) x"), DECLARATION_FICTIVE)
verifier("#74 : exceptions déclarées dont les identifiants ne sont plus employés (donnees.R n'appelle rien), donnees.R sans ligne",
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

# #109 : do.call sur un nom de fonction interdite, et références sans appel aux noms de
# APPELS_DYNAMIQUES (jusque-là seul l'appel était vu).
section("contrôles : graphe_modules.R, do.call et références sans appel (#109)")
r <- cas_graphe(c("calcul_e <- function(x) {", "  a <- do.call(parent.frame, list())", "  b <- do.call(get, list(\"x\"))",
                  "  c <- do.call(what = sys.call, args = list())", "  x", "}"))
verifier("#109 : do.call(parent.frame, list()), engagement.R:2 (règle do.call)",
         .echoue_en(r, "R/engagement.R", 2L, "do.call()"))
verifier("#109 : do.call(get, list(\"x\")), engagement.R:3 (règle do.call)", .echoue_en(r, "R/engagement.R", 3L, "do.call()"))
verifier("#109 : do.call(what = sys.call, ...), engagement.R:4 (règle do.call)", .echoue_en(r, "R/engagement.R", 4L, "do.call()"))
verifier("#109 : do.call(parent.frame, ...) est aussi une référence sans appel, engagement.R:2",
         .echoue_en(r, "R/engagement.R", 2L, "parent.frame sans appel"))
r <- cas_graphe(c("calcul_e <- function(x) {", "  g <- parent.frame", "  g()", "}"))
verifier("#109 : g <- parent.frame ; g(), référence sans appel, engagement.R:2",
         .echoue_en(r, "R/engagement.R", 2L, "parent.frame sans appel"))
r <- cas_graphe("calcul_e <- function(x) lapply(1, sys.call)")
verifier("#109 : lapply(1, sys.call), engagement.R:1", .echoue_en(r, "R/engagement.R", 1L, "sys.call sans appel"))
r <- cas_graphe(c("calcul_e <- function(x) {", "  f <- base::get", "  g <- lapply(x, eval)", "  h <- Map(globalenv, x)", "  x", "}"))
verifier("#109 : base::get (symbole après ::), engagement.R:2", .echoue_en(r, "R/engagement.R", 2L, "get sans appel"))
verifier("#109 : lapply(x, eval), engagement.R:3", .echoue_en(r, "R/engagement.R", 3L, "eval sans appel"))
verifier("#109 : Map(globalenv, x), engagement.R:4", .echoue_en(r, "R/engagement.R", 4L, "globalenv sans appel"))
r <- cas_graphe(c("calcul_e <- function(x) {", "  a <- do.call(rbind, list(x, x))", "  b <- do.call(function(u) u, list(x))",
                  "  c <- do.call(what = cbind, args = list(x))", "  a", "}"))
verifier("#109, cas licite : do.call sur un nom de fonction de base nu hors liste interdite, ou une fonction littérale", .passe(r))
r <- cas_graphe(c("calcul_e <- function(x, get) {", "  y <- x$get", "  z <- list(get = 1, eval = 2)", "  x$eval <- 3",
                  "  parse <- 1", "  y", "}"))
verifier("#109, cas licite : champ, nom d'argument, argument formel, cible seule d'une affectation (get, eval, parse)", .passe(r))
r <- .essai("graphe_modules", list("R/rapport.R" = c("empreinte_code <- function() {", "  f <- topenv", "  f()", "}")))
verifier("#109 : topenv référencé sans appel dans empreinte_code, exception déclarée (appels et références) : le contrôle passe",
         .passe(r) && any(grepl("M409, M412 : 2 declaree(s), 1 constatee(s)", r$sortie, fixed = TRUE)))
r <- cas_graphe("calcul_e <- function(get) get")
verifier("#109, limite documentée (côté sûr) : argument formel homonyme lu (function(get) get), signalé comme référence, engagement.R:1",
         .echoue_en(r, "R/engagement.R", 1L, "get sans appel"))
r <- .essai("graphe_modules", list("R/rapport.R" = c("empreinte_code <- function() {", "  1", "}")))
verifier("#109 : exception périmée, le message dit « ni appele ni reference » (rapport.R sans numéro de ligne)",
         .echoue_en(r, "R/rapport.R", NA_integer_, "n'est plus ni appele ni reference"))
r <- .essai("graphe_modules", list("R/rapport.R" = c("empreinte_code <- function() {", "  topenv()", "}", "autre_f <- function() lapply(1, topenv)")))
verifier("#109 : topenv référencé sans appel dans une autre fonction de rapport.R échoue, rapport.R:4",
         .echoue_en(r, "R/rapport.R", 4L, "topenv sans appel") && !any(startsWith(r$sortie, "[ECHEC] R/rapport.R:2 ")))
r <- .essai("graphe_modules", list("R/rapport.R" = c("empreinte_code <- function() {", "  lapply(1, parent.frame)", "}")))
verifier("#109 : l'exception de topenv ne couvre pas parent.frame référencé dans empreinte_code, rapport.R:2",
         .echoue_en(r, "R/rapport.R", 2L, "parent.frame sans appel"))

# Revue finale de Bo2 : l'exception déclarée pour un nom couvre aussi la forme do.call de ce nom.
r <- .essai("graphe_modules", list("R/outils.R" = "avec_graine <- function(graine, expr) do.call(globalenv, list())"))
verifier("exception globalenv déclarée : do.call(globalenv, list()) dans avec_graine() de outils.R passe (statut 0, exception constatée)",
         .passe(r) && any(grepl("M409, M412 : 2 declaree(s), 1 constatee(s)", r$sortie, fixed = TRUE)))
r <- .essai("graphe_modules", list("R/outils.R" = c(AVEC_GRAINE, "autre_f <- function() do.call(globalenv, list())")))
verifier("le même do.call(globalenv, ...) hors de l'exception (autre fonction de outils.R) échoue encore, outils.R:2 (règle do.call)",
         .echoue_en(r, "R/outils.R", 2L, "do.call()"))
r <- .essai("graphe_modules", list("R/outils.R" = "avec_graine <- function(graine, expr) { globalenv(); do.call(get, list()) }"))
verifier("l'exception de globalenv ne couvre pas do.call(get, ...), même dans avec_graine(), outils.R:1",
         .echoue_en(r, "R/outils.R", 1L, "do.call()"))

# #137 : dynGet, .GlobalEnv, forme appel d'environment<-, homonyme local d'une exception
# (m3 de #109 ; m-1 de l'audit de ac01c58).
section("contrôles : graphe_modules.R, dynGet, .GlobalEnv, environment<- et homonyme d'une exception (#137)")
r <- cas_graphe(c("calcul_e <- function(x) {", "  a <- dynGet(\"a\")", "  x", "}"))
verifier("#137 : dynGet(\"a\"), engagement.R:2", .echoue_en(r, "R/engagement.R", 2L, "dynGet()"))
r <- cas_graphe(c("calcul_e <- function(x) {", "  a <- .GlobalEnv", "  x", "}"))
verifier("#137 : .GlobalEnv, engagement.R:2", .echoue_en(r, "R/engagement.R", 2L, ".GlobalEnv sans appel"))
r <- cas_graphe(c("calcul_e <- function(x) {", "  a <- base::.GlobalEnv", "  x", "}"))
verifier("#137 : base::.GlobalEnv, engagement.R:2", .echoue_en(r, "R/engagement.R", 2L, ".GlobalEnv sans appel"))
r <- cas_graphe(c("calcul_e <- function(x) {", "  f <- function() 1", "  `environment<-`(f, x)", "  f", "}"))
verifier("#137 : `environment<-`(f, e) (forme appel), engagement.R:3", .echoue_en(r, "R/engagement.R", 3L, "environment<-()"))
r <- cas_graphe(c("calcul_e <- function(x) {", "  f <- function() 1", "  base::`environment<-`(f, x)", "  f", "}"))
verifier("#137 : base::`environment<-`(f, e) (forme appel), engagement.R:3", .echoue_en(r, "R/engagement.R", 3L, "environment<-()"))
r <- cas_graphe(c("calcul_e <- function(x) {", "  f <- function() 1", "  \"environment<-\"(f, x)", "  f", "}"))
verifier("#137 : \"environment<-\"(f, e) (appel par une chaîne), engagement.R:3", .echoue_en(r, "R/engagement.R", 3L, "environment<-()"))
r <- cas_graphe(c("calcul_e <- function(x) {", "  g <- `environment<-`", "  x", "}"))
verifier("#137 : `environment<-` référencé sans appel, engagement.R:2", .echoue_en(r, "R/engagement.R", 2L, "environment<- sans appel"))
r <- cas_graphe(c("calcul_e <- function(x) {", "  e <- new.env()", "  `parent.env<-`(e, x)", "  e", "}"))
verifier("#178 : `parent.env<-`(e, x) (forme appel), engagement.R:3", .echoue_en(r, "R/engagement.R", 3L, "parent.env<-()"))
r <- cas_graphe(c("calcul_e <- function(x) {", "  e <- new.env()", "  base::`parent.env<-`(e, x)", "  e", "}"))
verifier("#178 : base::`parent.env<-`(e, x) (forme appel), engagement.R:3", .echoue_en(r, "R/engagement.R", 3L, "parent.env<-()"))
r <- cas_graphe(c("calcul_e <- function(x) {", "  e <- new.env()", "  \"parent.env<-\"(e, x)", "  e", "}"))
verifier("#178 : \"parent.env<-\"(e, x) (appel par une chaîne), engagement.R:3", .echoue_en(r, "R/engagement.R", 3L, "parent.env<-()"))
r <- cas_graphe(c("calcul_e <- function(x) {", "  g <- `parent.env<-`", "  x", "}"))
verifier("#178 : `parent.env<-` référencé sans appel, engagement.R:2", .echoue_en(r, "R/engagement.R", 2L, "parent.env<- sans appel"))
r <- cas_graphe(c("calcul_e <- function(x) {", "  e <- new.env()", "  parent.env(e) <- x", "  e", "}"))
verifier("#178 : parent.env(e) <- x (forme remplacement, déjà refusée par parent.env), engagement.R:3",
         .echoue_en(r, "R/engagement.R", 3L, "parent.env()"))
r <- cas_graphe(c("calcul_e <- function(x) {", "  y <- x$dynGet", "  z <- list(dynGet = 1, .GlobalEnv = 2)", "  dyn_get <- 1", "  y", "}"))
verifier("#137, cas licite : dynGet et .GlobalEnv en champ ou en nom d'argument, nom voisin", .passe(r))
r <- .essai("graphe_modules", list("R/outils.R" = c("avec_graine <- function(graine, expr, f) {", "  globalenv <- f",
                                                    "  do.call(globalenv, list())", "}")))
verifier("#137 : homonyme local de l'exception, globalenv <- f ; do.call(globalenv, list()) dans avec_graine(), outils.R:3",
         .echoue_en(r, "R/outils.R", 3L, "exception declaree inapplicable"))
r <- .essai("graphe_modules", list("R/outils.R" = c("avec_graine <- function(graine, expr, f) {", "  globalenv <- f",
                                                    "  globalenv()", "}")))
verifier("#137 : homonyme local de l'exception, globalenv <- f ; globalenv() dans avec_graine(), outils.R:3",
         .echoue_en(r, "R/outils.R", 3L, "exception declaree inapplicable"))
r <- .essai("graphe_modules", list("R/outils.R" = c("avec_graine <- function(graine, expr, f) {", "  globalenv()", "  f -> globalenv", "}")))
verifier("#137 : homonyme local de l'exception par ->, affecté après l'appel, outils.R:2",
         .echoue_en(r, "R/outils.R", 2L, "exception declaree inapplicable"))
r <- .essai("graphe_modules", list("R/rapport.R" = c("empreinte_code <- function() {", "  topenv <- function() 1", "  topenv()", "}")))
verifier("#137 : homonyme local de l'exception de topenv() dans empreinte_code(), rapport.R:3",
         .echoue_en(r, "R/rapport.R", 3L, "exception declaree inapplicable"))
r <- .essai("graphe_modules", list("R/outils.R" = c("avec_graine <- function(graine, expr) {", "  global <- globalenv()", "  topenv <- 1", "  global", "}")))
verifier("#137 : une variable locale de nom différent de l'exception (topenv) ne rend pas inapplicable celle de globalenv : le contrôle passe",
         .passe(r))
r <- .essai("graphe_modules", list("R/outils.R" = c("avec_graine <- function(graine, expr, f) {", "  global <- globalenv()", "  global", "}",
                                                    "autre_f <- function(f) { globalenv <- f ; f }")))
verifier("#137 : l'homonyme local d'une autre fonction de outils.R ne rend pas inapplicable l'exception d'avec_graine() : le contrôle passe",
         .passe(r))
r <- .essai("graphe_modules", list("R/outils.R" = "avec_graine <- function(graine, expr, globalenv) globalenv()"))
verifier("#178 : argument formel homonyme de l'exception, function(graine, expr, globalenv) globalenv(), outils.R:1",
         .echoue_en(r, "R/outils.R", 1L, "exception declaree inapplicable"))
r <- .essai("graphe_modules", list("R/outils.R" = "avec_graine <- \\(graine, expr, globalenv) globalenv()"))
verifier("#178 : argument formel homonyme de l'exception, fonction anonyme \\(graine, expr, globalenv), outils.R:1",
         .echoue_en(r, "R/outils.R", 1L, "exception declaree inapplicable"))
r <- .essai("graphe_modules", list("R/outils.R" = c("avec_graine <- function(graine, expr, f) {", "  for (globalenv in list(f)) globalenv()", "}")))
verifier("#178 : variable de for homonyme de l'exception, for (globalenv in list(f)) globalenv(), outils.R:2",
         .echoue_en(r, "R/outils.R", 2L, "exception declaree inapplicable"))
verifier("#178 : variable de for homonyme avec appel : une seule ligne [ECHEC] (la variable de for n'est pas une référence)",
         sum(startsWith(r$sortie, "[ECHEC]")) == 1L)
r <- .essai("graphe_modules", list("R/outils.R" = c("avec_graine <- function(graine, expr, l) {", "  for (globalenv in l) 1", "}")))
verifier("#178 : variable de for homonyme sans appel : exception périmée (la liaison n'est pas un emploi), une seule ligne, outils.R",
         .echoue_en(r, "R/outils.R", NA_integer_, "ne se produit plus") && sum(startsWith(r$sortie, "[ECHEC]")) == 1L)
r <- .essai("graphe_modules", list("R/outils.R" = c("avec_graine <- function(graine, expr) globalenv()",
                                                    "h <- function(l) { for (get in l) 1; 2 }")))
verifier("#178 : une variable de for qui porte un nom interdit hors exception reste une référence refusée, for (get in l) 1, outils.R:2",
         .echoue_en(r, "R/outils.R", 2L, "get sans appel"))
r <- .essai("graphe_modules", list("R/outils.R" = c("avec_graine <- function(graine, expr, x) {", "  x$assign(\"globalenv\", 1)",
                                                    "  globalenv()", "}")))
verifier("#178 : un appel de champ x$assign(\"globalenv\", 1) n'est pas un assign() de base : l'exception d'avec_graine() reste applicable",
         .passe(r))
r <- .essai("graphe_modules", list("R/rapport.R" = c("empreinte_code <- function(topenv) {", "  topenv()", "}")))
verifier("#178 : argument formel homonyme de l'exception de topenv() dans empreinte_code(), rapport.R:2",
         .echoue_en(r, "R/rapport.R", 2L, "exception declaree inapplicable"))
r <- .essai("graphe_modules", list("R/outils.R" = c("avec_graine <- function(graine, expr) {", "  assign(\"globalenv\", function() 1)",
                                                    "  globalenv()", "}")))
verifier("#178 : assign(\"globalenv\", ...) dans avec_graine() puis globalenv(), outils.R:3",
         .echoue_en(r, "R/outils.R", 3L, "exception declaree inapplicable"))
r <- .essai("graphe_modules", list("R/outils.R" = "avec_graine <- function(graine, expr) { assign(\"globalenv\", function() 1); globalenv() }"))
verifier("#178 : le cas de l'issue, sur une seule ligne, outils.R:1",
         .echoue_en(r, "R/outils.R", 1L, "exception declaree inapplicable"))
r <- .essai("graphe_modules", list("R/outils.R" = c("avec_graine <- function(graine, expr) {", "  assign(`x` = 'globalenv', value = function() 1)",
                                                    "  globalenv()", "}")))
verifier("#178 : assign(`x` = 'globalenv', ...) (nom d'argument entre accents graves) dans avec_graine(), outils.R:3",
         .echoue_en(r, "R/outils.R", 3L, "exception declaree inapplicable"))
r <- .essai("graphe_modules", list("R/outils.R" = c("avec_graine <- function(graine, expr) {", "  assign(\"x\" = 'globalenv', value = function() 1)",
                                                    "  globalenv()", "}")))
verifier("#178 : assign(\"x\" = 'globalenv', ...) (nom d'argument en chaîne) dans avec_graine(), outils.R:3",
         .echoue_en(r, "R/outils.R", 3L, "exception declaree inapplicable"))
r <- .essai("graphe_modules", list("R/outils.R" = c("avec_graine <- function(graine, expr) {", "  base::assign(x = \"globalenv\", value = 1)",
                                                    "  globalenv()", "}")))
verifier("#178 : base::assign(x = \"globalenv\", ...) (argument nommé) dans avec_graine(), outils.R:3",
         .echoue_en(r, "R/outils.R", 3L, "exception declaree inapplicable"))
r <- .essai("graphe_modules", list("R/outils.R" = c("avec_graine <- function(graine, expr) {", "  assign(\"autre\", 1)",
                                                    "  assign(\".Random.seed\", 1, envir = globalenv())", "}")))
verifier("#178 : assign() d'un autre nom dans avec_graine() ne rend pas l'exception inapplicable : le contrôle passe", .passe(r))
r <- .essai("graphe_modules", list("R/outils.R" = c("avec_graine <- function(graine, expr) {", "  globalenv()", "}",
                                                    "autre_f <- function(globalenv) {", "  assign(\"globalenv\", 1)", "  1", "}")))
verifier("#178 : formel et assign() homonymes dans une autre fonction de outils.R ne rendent pas inapplicable l'exception d'avec_graine() : le contrôle passe",
         .passe(r))
r <- .essai("graphe_modules", list("R/outils.R" = c("avec_graine <- function(graine, expr) {", "  x <- list()", "  x$globalenv <- 1",
                                                    "  globalenv()", "}")))
verifier("#178 : faux positif levé, l'affectation d'un champ (x$globalenv <- 1) n'est pas un homonyme local : le contrôle passe",
         .passe(r))
r <- .essai("graphe_modules", list("R/outils.R" = "avec_graine <- function(graine, expr) { x <- list(); x$globalenv <- 1; globalenv() }"))
verifier("#178 : le cas de l'issue (faux positif), sur une seule ligne : le contrôle passe", .passe(r))
r <- .essai("graphe_modules", list("R/outils.R" = c("avec_graine <- function(graine, expr, nom) {", "  assign(nom, function() 1)", "  globalenv()", "}")))
verifier("#178 puis #184 : assign() sur un nom calculé (assign(nom, f)) n'est plus une limite, l'exception est inapplicable, outils.R:3 (limite levée, règle stricte de M746)",
         .echoue_en(r, "R/outils.R", 3L, "exception declaree inapplicable"))

# #184 (M746) : règle stricte pour assign() à nom calculé et formes voisines, cible de remplacement,
# noms interdits écrits en chaîne, do.call(`what` = ...). Les témoins positifs ont le statut 0 sur le
# script de b15886e ; les cas licites et les limites sont mesurés sur la règle de #184.
section("contrôles : graphe_modules.R, assign() à nom calculé, remplacement, chaînes, what (#184)")
# avec_graine() fictive : l'exception globalenv() (M412) s'y applique ; `...` est inséré avant `globalenv()`.
AG184 <- function(...) c("avec_graine <- function(graine, expr, nom = 1, f = NULL) {", c(...), "  globalenv()", "}")
INAPPLICABLE <- "exception declaree inapplicable"
cas_ag <- function(...) .essai("graphe_modules", list("R/outils.R" = AG184(...)))
r <- cas_ag("  assign(nom, function() 1)")
verifier("#184 : assign(nom, f) (nom calculé) avant globalenv() dans avec_graine(), outils.R:3 (règle stricte)",
         .echoue_en(r, "R/outils.R", 3L, INAPPLICABLE))
r <- cas_ag("  assign(r\"(globalenv)\", function() 1)")
verifier("#184 : assign(r\"(globalenv)\", f) (chaîne brute), outils.R:3", .echoue_en(r, "R/outils.R", 3L, INAPPLICABLE))
r <- cas_ag("  assign(\"glob\\x61lenv\", function() 1)")
verifier("#184 : assign(\"glob\\x61lenv\", f) (échappement dans la chaîne), outils.R:3", .echoue_en(r, "R/outils.R", 3L, INAPPLICABLE))
r <- cas_ag("  assign(`globalenv`, function() 1)")
verifier("#184 : assign(`globalenv`, f) (nom en symbole, donc calculé), outils.R:3", .echoue_en(r, "R/outils.R", 3L, INAPPLICABLE))
r <- cas_ag("  do.call(assign, list('globalenv', function() 1))")
verifier("#184 : do.call(assign, list('globalenv', f)) (assign référencé sans appel), outils.R:3", .echoue_en(r, "R/outils.R", 3L, INAPPLICABLE))
r <- cas_ag("  delayedAssign('globalenv', function() 1)")
verifier("#184 : delayedAssign('globalenv', f), outils.R:3", .echoue_en(r, "R/outils.R", 3L, INAPPLICABLE))
r <- cas_ag("  delayedAssign(nom, function() 1)")
verifier("#184 : delayedAssign(nom, f) (nom calculé), outils.R:3", .echoue_en(r, "R/outils.R", 3L, INAPPLICABLE))
r <- cas_ag("  (assign)(\"globalenv\", function() 1)")
verifier("#184 : (assign)(\"globalenv\", f) (assign en symbole), outils.R:3", .echoue_en(r, "R/outils.R", 3L, INAPPLICABLE))
r <- cas_ag(c("  g <- assign", "  g(\"globalenv\", function() 1)"))
verifier("#184 : alias g <- assign ; g(\"globalenv\", f), outils.R:4", .echoue_en(r, "R/outils.R", 4L, INAPPLICABLE))
r <- .essai("graphe_modules", list("R/outils.R" = c("poser <- assign", AG184("  poser(\"globalenv\", function() 1)"))))
verifier("#184 : alias de assign défini au premier niveau du fichier, outils.R:4", .echoue_en(r, "R/outils.R", 4L, INAPPLICABLE))
r <- cas_ag(c("  assign(\"autre\", 1)", "  delayedAssign('autre2', 2)", "  assign(\".Random.seed\", 3, envir = globalenv())"))
verifier("#184, cas licite : assign() et delayedAssign() d'un nom littéral autre que l'exception : le contrôle passe", .passe(r))
r <- cas_ag("  x <- list(assign = 1, delayedAssign = 2) ; x$assign ; x$delayedAssign")
verifier("#184, cas licite : assign en champ ou en nom d'argument n'est pas une référence : le contrôle passe", .passe(r))
r <- cas_ag("  body(globalenv) <- quote(new.env())")
verifier("#184 : body(globalenv) <- v (cible de remplacement, masque globalenv), globalenv() inapplicable, outils.R:3",
         .echoue_en(r, "R/outils.R", 3L, INAPPLICABLE))
r <- cas_ag("  formals(body(globalenv)) <- NULL")
verifier("#184 : formals(body(globalenv)) <- NULL (remplacement imbriqué), outils.R:3", .echoue_en(r, "R/outils.R", 3L, INAPPLICABLE))
r <- cas_ag(c("  x <- list()", "  x[globalenv()] <- 1", "  x[[1L]] <- globalenv()", "  x$globalenv[1L] <- 1", "  body(f) -> y"))
verifier("#184, cas licite : globalenv en indice, en valeur, en champ ou à droite de -> n'est pas une cible de remplacement : le contrôle passe",
         .passe(r))
r <- cas_graphe("calcul_e <- function(x) { body(get) <- x ; x }")
verifier("#184 : hors exception, body(get) <- x reste une référence refusée, engagement.R:1", .echoue_en(r, "R/engagement.R", 1L, "get sans appel"))
r <- cas_graphe("calcul_e <- function(x) lapply(1, \"sys.call\")")
verifier("#184 (m3) : lapply(1, \"sys.call\"), engagement.R:1", .echoue_en(r, "R/engagement.R", 1L, "\"sys.call\" ecrit en chaine"))
r <- cas_graphe(c("calcul_e <- function(x) {", "  a <- vapply(x, \"dynGet\", 1)", "  b <- Map(f = 'get', x)", "  c <- sapply(x, FUN = \"eval\")",
                  "  d <- lapply(FUN = \"parse\", x)", "  e <- lapply(x, r\"(source)\")", "  x", "}"))
verifier("#184 (m3) : vapply(x, \"dynGet\", 1), engagement.R:2", .echoue_en(r, "R/engagement.R", 2L, "\"dynGet\" ecrit en chaine"))
verifier("#184 (m3) : Map(f = 'get', x) (argument nommé, guillemets simples), engagement.R:3", .echoue_en(r, "R/engagement.R", 3L, "\"get\" ecrit en chaine"))
verifier("#184 (m3) : sapply(x, FUN = \"eval\"), engagement.R:4", .echoue_en(r, "R/engagement.R", 4L, "\"eval\" ecrit en chaine"))
verifier("#184 (m3) : lapply(FUN = \"parse\", x) (argument-fonction nommé en tête), engagement.R:5", .echoue_en(r, "R/engagement.R", 5L, "\"parse\" ecrit en chaine"))
verifier("#184 (m3) : lapply(x, r\"(source)\") (chaîne brute), engagement.R:6", .echoue_en(r, "R/engagement.R", 6L, "\"source\" ecrit en chaine"))
r <- cas_graphe(c("calcul_e <- function(x) {", "  a <- lapply(x, \"[[\", \"source\")", "  b <- x[[\"environment\"]]", "  c <- sapply(x, \"[\", \"get\")",
                  "  d <- lapply(FUN = \"[[\", x, \"parse\")", "  e <- mapply(\"+\", 1, 2)", "  f <- x[, \"eval\"]", "  names(x) == \"source\"", "}"))
verifier("#184 (m3), cas licite : noms de colonnes en chaîne (lapply(x, \"[[\", \"source\"), x[[\"environment\"]], sapply(x, \"[\", \"get\")) : le contrôle passe",
         .passe(r))
r <- .essai("graphe_modules", list("R/outils.R" = c("avec_graine <- function(graine, expr) {", "  lapply(1, \"globalenv\")", "}")))
verifier("#184 (m3) : l'exception de globalenv couvre aussi la chaîne \"globalenv\" en position de fonction dans avec_graine() : le contrôle passe, exception constatée",
         .passe(r) && any(grepl("M409, M412 : 2 declaree(s), 1 constatee(s)", r$sortie, fixed = TRUE)))
r <- cas_graphe("calcul_e <- function(l) do.call(`what` = rbind, l)")
verifier("#184 : do.call(`what` = rbind, l) (nom d'argument entre accents graves) n'est plus refusé à tort : le contrôle passe", .passe(r))
r <- cas_graphe("calcul_e <- function(l) do.call(\"what\" = rbind, l)")
verifier("#184 : do.call(\"what\" = rbind, l) (nom d'argument en chaîne) n'est plus refusé à tort : le contrôle passe", .passe(r))
r <- cas_graphe("calcul_e <- function(l) do.call(args = l, rbind)")
verifier("#184 : do.call(args = l, rbind) (what en second, positionnel) n'est plus refusé à tort : le contrôle passe", .passe(r))
r <- cas_graphe("calcul_e <- function(l) do.call(`what` = get, list())")
verifier("#184 : do.call(`what` = get, list()) reste refusé (règle do.call), engagement.R:1", .echoue_en(r, "R/engagement.R", 1L, "do.call()"))
r <- .essai("graphe_modules", list("R/outils.R" = "avec_graine <- function(graine, expr) do.call(`what` = globalenv, list())"))
verifier("#184 : do.call(`what` = globalenv, list()) dans avec_graine() : exception déclarée, le contrôle passe", .passe(r))
# Limites documentées (mesurées sur la règle de #184, statut 0).
r <- cas_graphe("calcul_e <- function(x) { n <- \"eval\"; lapply(x, n) }")
verifier("#184, limite documentée : un nom interdit passé par une variable (n <- \"eval\" ; lapply(x, n)) n'est pas vu, le contrôle passe", .passe(r))
r <- cas_graphe("calcul_e <- function(x) lapply(x, c(\"eval\"))")
verifier("#184, limite documentée : un nom interdit dans c() ou list() à la place de la fonction n'est pas vu, le contrôle passe", .passe(r))
r <- cas_graphe("calcul_e <- function(x) integrate(\"get\", 0, 1)")
verifier("#184, limite documentée : une fonction d'ordre supérieur hors FONCTIONS_ORDRE_SUPERIEUR (integrate) n'est pas vue, le contrôle passe", .passe(r))
r <- cas_graphe("calcul_e <- function(x) lapply(x, FU = \"eval\")")
verifier("#184, limite documentée : un nom d'argument partiel (FU = \"eval\") n'est pas apparié, le contrôle passe", .passe(r))
r <- .essai("graphe_modules", list("R/outils.R" = c("poser <- function(n, v) assign(n, v)", AG184("  poser(\"globalenv\", function() 1)"))))
verifier("#184, limite documentée : un assign() à nom calculé dans une autre fonction du fichier (poser(\"globalenv\", f)) n'est pas vu, le contrôle passe",
         .passe(r))
r <- cas_ag("  with(list(globalenv = function() 1), globalenv())")
verifier("#184, limite documentée : with(list(globalenv = f), globalenv()) n'est pas vu, le contrôle passe", .passe(r))
# Constats mineurs de l'audit de #184, corrigés par la session (chacun au statut 0, ou refusé à tort, sur
# le script issu du workflow ; mesure citée dans le commit).
r <- cas_ag("  \"glob\\x61lenv\" <- function() 1")
verifier("#184 (audit, m1) : \"glob\\x61lenv\" <- f (cible en chaîne avec échappement) masque globalenv, outils.R:3",
         .echoue_en(r, "R/outils.R", 3L, INAPPLICABLE))
r <- cas_ag("  r\"(globalenv)\" <- function() 1")
verifier("#184 (audit, m1) : r\"(globalenv)\" <- f (cible en chaîne brute) masque globalenv, outils.R:3",
         .echoue_en(r, "R/outils.R", 3L, INAPPLICABLE))
r <- .essai("graphe_modules", list("R/outils.R" = c("delayedAssign(\"zz\", 1)", "avec_graine <- function(graine, expr) globalenv()")))
verifier("#184 (audit, m2) : delayedAssign() au premier niveau refusé comme assign(), outils.R:1",
         .echoue_en(r, "R/outils.R", 1L, "assign() au premier niveau"))
r <- cas_graphe(c("calcul_e <- function(x) {", "  a <- x$lapply(1, \"get\")", "  b <- x@lapply(1, \"eval\")", "  x", "}"))
verifier("#184 (audit, m3), cas licite : x$lapply(1, \"get\") et x@lapply(1, \"eval\") (appels de champ) ne sont pas refusés : le contrôle passe",
         .passe(r))
# M768 : assign employé sans appel n'importe où dans R/ rend les exceptions inapplicables (alias défini
# dans un autre module : statut 0 sur la portée au fichier, mesure d'actuary).
r <- .essai("graphe_modules", list("R/donnees.R" = "alias_assign <- function(...) assign(...) ; alias_bis <- assign",
                                   "R/outils.R" = "avec_graine <- function(graine, expr) globalenv()"))
verifier("#184 (M768) : alias de assign défini dans un autre module (donnees.R), exception de outils.R inapplicable, outils.R:1",
         .echoue_en(r, "R/outils.R", 1L, INAPPLICABLE))

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
r <- .essai_exceptions(list("R/outils.R" = OUTILS_POINT,
                            "R/donnees.R" = c("donnees_f <- function(x) {", "  .longueur_commune(x)", "  .composantes_date(x)", "  .jour_de(x)", "}")),
                       DECLARATION_FICTIVE)
verifier("m2 : exceptions déclarées 3, constatées 3 (racine fictive sans plan.R)",
         .passe(r) && any(grepl("3 exception(s) declaree(s), 3 constatee(s)", r$sortie, fixed = TRUE)))
r <- .essai("graphe_modules", list("R/dictionnaire.R" = "dico_f <- function(x) x"))
verifier("m2 : exceptions déclarées 0, constatées 0 (et non « hors des 0 exception(s) déclarée(s) »)",
         .passe(r) && any(grepl("0 exception(s) declaree(s), 0 constatee(s)", r$sortie, fixed = TRUE)) &&
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

# #111 : zéros attendus à tolérance > 0 (consigne de tests/harnais.R : un zéro se compare à part).
r <- cas_recensement(c("TOL <- 1e-10",
                       "verifier_egal(\"a\", x, 0, tolerance = TOL)",
                       "verifier_egal(\"b\", x, c(1, 0), tolerance = 1e-8)",
                       "verifier_egal(\"c\", x, list(f(y), 0), tolerance = 1e-8)",
                       "verifier_egal(\"d\", x, 0, tolerance = 0)",
                       "verifier_egal(\"e\", x, 0L, tolerance = 1e-8)",
                       "verifier_egal(\"f\", x, list(f(y), character(0), z[0]), tolerance = 1e-8)",
                       "verifier_egal(\"g\", x, c(1, 2), tolerance = 1e-8)",
                       "# zero_compense : ecart de passage, termes de l'ordre de 7 474",
                       "verifier_egal(\"h\", x - y, 0, tolerance = 1e-8)",
                       "# zero_compense : marque non contigue a l'appel",
                       "z <- 1",
                       "verifier_egal(\"i\", x - y, 0, tolerance = 1e-8)"))
zeros <- grep("^\\[INFO\\] ZEROS ATTENDUS A TOLERANCE > 0 ", r$sortie)
comp <- grep("^\\[INFO\\] ZERO DE COMPENSATION DECLARE \\(", r$sortie)
verifier("recensement : un zéro attendu à tolérance > 0 est listé sous ZEROS ATTENDUS A TOLERANCE > 0 : quatre appels (a : scalaire 0, b : feuille nulle évaluée, c : 0 littéral d'une expression non évaluable, i : marque non contiguë), sans [ECHEC] (informatif)",
         .passe(r) && length(zeros) == 1L && grepl(" : 4 appels$", r$sortie[zeros]))
verifier("recensement : ZEROS ATTENDUS : temoin.R:2, :3, :4 et :13 (tolérance lue, symbole ou littérale)",
         length(zeros) == 1L && length(comp) == 1L &&
           identical(r$sortie[(zeros + 1L):(comp - 1L)],
                     c("[INFO]   tests/unitaires/temoin.R:2 tolerance 1e-10", "[INFO]   tests/unitaires/temoin.R:3 tolerance 1e-08",
                       "[INFO]   tests/unitaires/temoin.R:4 tolerance 1e-08", "[INFO]   tests/unitaires/temoin.R:13 tolerance 1e-08")))
verifier("recensement : hors de la rubrique : tolérance 0 (d), zéro entier 0L (e), 0 de character(0) et d'indice z[0] (f), aucun zéro (g)",
         length(zeros) == 1L && length(comp) == 1L &&
           !any(grepl("temoin.R:[5678] ", r$sortie[(zeros + 1L):(comp - 1L)])))
verifier("recensement : un zéro de compensation marqué `# zero_compense` sur la ligne qui précède l'appel est compté à part (temoin.R:10), hors de la rubrique",
         length(comp) == 1L && grepl(" : 1 appels$", r$sortie[comp]) &&
           identical(r$sortie[comp + 1L], "[INFO]   tests/unitaires/temoin.R:10 tolerance 1e-08"))

# #111, reprise : zéros littéraux d'une expression non évaluable (arguments de longueur ou d'indice exclus),
# tolérance non résolue, arguments non appariables, appels marqués à plusieurs zéros, marques orphelines.
r <- cas_recensement(c("verifier_egal(\"a\", x, list(f(y), rep(0, 2L)), tolerance = 1e-8)",
                       "verifier_egal(\"b\", x, list(f(y), numeric(2L)), tolerance = 1e-8)",
                       "verifier_egal(\"c\", x, list(f(y), c(1, 2)[2L]), tolerance = 1e-8)",
                       "verifier_egal(\"d\", x, list(f(y), round(1.5, 0)), tolerance = 1e-8)",
                       "verifier_egal(\"e\", x, list(f(y), rep(1, 0)), tolerance = 1e-8)",
                       "verifier_egal(\"f\", x, list(f(y), double(1L)), tolerance = 1e-8)",
                       "verifier_egal(\"g\", x, list(f(y), numeric(0)), tolerance = 1e-8)",
                       "verifier_egal(\"h\", x, list(f(y), character(0)), tolerance = 1e-8)",
                       "verifier_egal(\"i\", x, list(f(y), x[0], x[[0]]), tolerance = 1e-8)",
                       "verifier_egal(\"j\", x, list(f(y), 0), tolerance = TOLINCONNUE)",
                       "verifier_egal(\"k\", x, list(f(y), 0), tolerance = 1e-8, extra = 1)",
                       "verifier_egal(\"l\", x, list(f(y), 0), 1e-8, 2)",
                       "f2 <- function(...) verifier_egal(\"m\", ..., tolerance = 1e-8)",
                       "verifier_egal(\"n\", x, attendu = list(f(y), 0), tolerance = 1e-8, extra = 1)"))
zeros <- grep("^\\[INFO\\] ZEROS ATTENDUS A TOLERANCE > 0 ", r$sortie)
comp <- grep("^\\[INFO\\] ZERO DE COMPENSATION DECLARE \\(", r$sortie)
verifier("recensement : zéros littéraux d'un appel non évaluable : rep(0, 2L), numeric(2L) et double(1L) comptent (temoin.R:1, :2, :6)",
         .passe(r) && length(zeros) == 1L && length(comp) == 1L &&
           all(c("[INFO]   tests/unitaires/temoin.R:1 tolerance 1e-08", "[INFO]   tests/unitaires/temoin.R:2 tolerance 1e-08",
                 "[INFO]   tests/unitaires/temoin.R:6 tolerance 1e-08") %in% r$sortie[(zeros + 1L):(comp - 1L)]))
verifier("recensement : ne comptent pas : indice de `[` et `[[` (c, i), digits de round (d), times de rep (e), numeric(0) (g), character(0) (h)",
         length(zeros) == 1L && length(comp) == 1L &&
           !any(grepl("temoin.R:[345789] ", r$sortie[(zeros + 1L):(comp - 1L)])))
verifier("recensement : tolérance non résolue (j), arguments non appariables lus par position (k : argument en trop ; l : cinq arguments, tolérance positionnelle 1e-8 lue, #179) ou sous le nom attendu (n) : listés ; `...` sans attendu (m) : non",
         length(zeros) == 1L && length(comp) == 1L &&
           all(c("[INFO]   tests/unitaires/temoin.R:10 tolerance non resolue", "[INFO]   tests/unitaires/temoin.R:11 tolerance 1e-08",
                 "[INFO]   tests/unitaires/temoin.R:12 tolerance 1e-08", "[INFO]   tests/unitaires/temoin.R:14 tolerance 1e-08") %in%
                 r$sortie[(zeros + 1L):(comp - 1L)]) &&
           !any(grepl("temoin.R:13 ", r$sortie[(zeros + 1L):(comp - 1L)])) && grepl(" : 7 appels$", r$sortie[zeros]))
r <- cas_recensement(c("# zero_compense : deux zeros dans l'appel",
                       "verifier_egal(\"a\", x - y, list(f(y), 0, 0), tolerance = 1e-8)",
                       "# zero_compense : un zero",
                       "verifier_egal(\"b\", x - y, 0, tolerance = 1e-8)",
                       "# zero_compense : appel sans zero",
                       "verifier_egal(\"c\", x, 1, tolerance = 1e-8)",
                       "# zero_compense : pas d'appel",
                       "x <- 1",
                       "# zero_compense : appel a tolerance nulle",
                       "verifier_egal(\"d\", x, 0)",
                       "# zero_compense : fin de fichier"))
multi <- grep("^\\[INFO\\] ZERO DE COMPENSATION DECLARE A PLUSIEURS ZEROS ", r$sortie)
orph <- grep("^\\[INFO\\] MARQUES zero_compense ORPHELINES ", r$sortie)
verifier("recensement : deux appels marqués à zéro (temoin.R:2 et :4, rubrique « déclaré »), dont un à plusieurs zéros listé à part (temoin.R:2, 2 zéros)",
         .passe(r) && any(grepl("^\\[INFO\\] ZERO DE COMPENSATION DECLARE \\(.* : 2 appels$", r$sortie)) && length(multi) == 1L &&
           grepl(" : 1 appels$", r$sortie[multi]) && identical(r$sortie[multi + 1L], "[INFO]   tests/unitaires/temoin.R:2 tolerance 1e-08, 2 zeros"))
verifier("recensement : marques orphelines : appel sans zéro (temoin.R:5), pas d'appel (:7), appel à tolérance nulle (:9), fin de fichier (:11) ; les marques des lignes 1 et 3 ne le sont pas",
         length(orph) == 1L && grepl(" : 4 marques$", r$sortie[orph]) &&
           identical(r$sortie[(orph + 1L):(orph + 4L)],
                     c("[INFO]   tests/unitaires/temoin.R:5 appel sans zero reel a tolerance > 0 (ou a tolerance 0)",
                       "[INFO]   tests/unitaires/temoin.R:7 aucun appel de verifier_egal() a la ligne suivante",
                       "[INFO]   tests/unitaires/temoin.R:9 appel sans zero reel a tolerance > 0 (ou a tolerance 0)",
                       "[INFO]   tests/unitaires/temoin.R:11 aucun appel de verifier_egal() a la ligne suivante")))
r <- cas_recensement(c("# zero_compense : sans aucun appel a tolerance > 0 dans le fichier", "x <- 1"))
verifier("recensement : une marque orpheline est listée même sans appel à tolérance > 0 dans le dépôt (temoin.R:1), statut 0",
         .passe(r) && any(grepl("aucun appel a tolerance > 0", r$sortie, fixed = TRUE)) &&
           any(grepl(" : 1 marques$", r$sortie)) &&
           any(grepl("temoin.R:1 aucun appel de verifier_egal() a la ligne suivante", r$sortie, fixed = TRUE)))

# #136 (M725) : marque seule sur sa ligne (r1), rep(0, k) non évaluable (r2), attendu apparié comme R (r3),
# motif de la marque exigé. Chaque témoin échoue sur le script d'avant #136.
# r1 : un commentaire en fin de ligne n'est pas une marque ; une marque indentée, seule sur sa ligne, en est une.
r <- cas_recensement(c("x <- 1  # zero_compense : motif en fin de ligne",
                       "verifier_egal(\"a\", x - y, 0, tolerance = 1e-8)",
                       "  # zero_compense : marque indentee",
                       "verifier_egal(\"b\", x - y, 0, tolerance = 1e-8)",
                       "verifier_egal(\"c\", x - y, c(1, 2),  # zero_compense : motif dans un appel sur plusieurs lignes",
                       "               tolerance = 1e-8)"))
verifier("#136 r1 : un commentaire `# zero_compense` en fin de ligne n'est pas une marque : l'appel suivant (temoin.R:2) reste sous ZEROS ATTENDUS, un seul appel déclaré (temoin.R:4, marque indentée), aucune marque orpheline, statut 0",
         .passe(r) && any(grepl("^\\[INFO\\] ZEROS ATTENDUS A TOLERANCE > 0 .* : 1 appels$", r$sortie)) &&
           any(grepl("^\\[INFO\\] ZERO DE COMPENSATION DECLARE \\(.* : 1 appels$", r$sortie)) &&
           any(grepl("temoin.R:2 tolerance 1e-08", r$sortie, fixed = TRUE)) &&
           any(grepl("temoin.R:4 tolerance 1e-08", r$sortie, fixed = TRUE)) &&
           any(grepl("^\\[INFO\\] MARQUES zero_compense ORPHELINES .* : 0 marques$", r$sortie)))
# r2 : rep(0, k) / rep_len(0, k) non évaluables comptent plusieurs zéros ; k littéral multiplie ; k = 0 : aucun zéro.
r <- cas_recensement(c("# zero_compense : motif",
                       "verifier_egal(\"a\", x - y, list(f(y), rep(0, k)), tolerance = 1e-8)",
                       "# zero_compense : motif",
                       "verifier_egal(\"b\", x - y, list(f(y), rep_len(0, k)), tolerance = 1e-8)",
                       "# zero_compense : motif",
                       "verifier_egal(\"c\", x - y, list(f(y), rep(0, 3L)), tolerance = 1e-8)",
                       "# zero_compense : motif",
                       "verifier_egal(\"d\", x - y, list(f(y), 0), tolerance = 1e-8)",
                       "# zero_compense : motif",
                       "verifier_egal(\"e\", x - y, list(f(y), rep(0, 0L), 0), tolerance = 1e-8)"))
multi <- grep("^\\[INFO\\] ZERO DE COMPENSATION DECLARE A PLUSIEURS ZEROS ", r$sortie)
verifier("#136 r2 : un rep(0, k) ou rep_len(0, k) non évaluable sous marque est listé sous A PLUSIEURS ZEROS (temoin.R:2 et :4, 2 zéros), rep(0, 3L) compte 3 (:6) ; un zéro seul (:8) et rep(0, 0L) + 0 (:10) ne sont pas listés",
         .passe(r) && length(multi) == 1L && grepl(" : 3 appels$", r$sortie[multi]) &&
           identical(r$sortie[(multi + 1L):(multi + 3L)],
                     c("[INFO]   tests/unitaires/temoin.R:2 tolerance 1e-08, 2 zeros", "[INFO]   tests/unitaires/temoin.R:4 tolerance 1e-08, 2 zeros",
                       "[INFO]   tests/unitaires/temoin.R:6 tolerance 1e-08, 3 zeros")))
# r2 (reprise) : le facteur de répétition lit les constantes du fichier : rep(0, N) avec N <- 1 compte 1 zéro, N <- 3 en compte 3.
r <- cas_recensement(c("N <- 1",
                       "M <- 3",
                       "# zero_compense : motif",
                       "verifier_egal(\"a\", x - y, list(f(y), rep(0, N)), tolerance = 1e-8)",
                       "# zero_compense : motif",
                       "verifier_egal(\"b\", x - y, list(f(y), rep(0, M)), tolerance = 1e-8)"))
multi <- grep("^\\[INFO\\] ZERO DE COMPENSATION DECLARE A PLUSIEURS ZEROS ", r$sortie)
verifier("#136 r2 (reprise) : rep(0, N) avec la constante N <- 1 compte un zéro (temoin.R:4, non listé sous A PLUSIEURS ZEROS) ; avec M <- 3 il en compte 3 (:6, seul appel listé)",
         .passe(r) && length(multi) == 1L && grepl(" : 1 appels$", r$sortie[multi]) &&
           identical(r$sortie[multi + 1L], "[INFO]   tests/unitaires/temoin.R:6 tolerance 1e-08, 3 zeros"))
# Débordement de l'entier R (#136, constat de la revue finale) : sous options(warn = 2), as.integer() d'un double
# hors de portée, ou la somme d'entiers qui déborde, arrêtait le script. Un facteur hors de l'entier R donne
# « plusieurs » (2 zéros) ; un produit ou une somme qui déborde est plafonné à .Machine$integer.max (2147483647).
r <- cas_recensement(c("# zero_compense : motif",
                       "verifier_egal(\"a\", x - y, list(f(y), rep(0, 3e9)), tolerance = 1e-8)",
                       "# zero_compense : motif",
                       "verifier_egal(\"b\", x - y, list(f(y), rep(0, times = 50000, each = 50000)), tolerance = 1e-8)",
                       "# zero_compense : motif",
                       "verifier_egal(\"c\", x - y, list(f(y), rep_len(0, 3e9)), tolerance = 1e-8)",
                       "# zero_compense : motif",
                       "verifier_egal(\"d\", x - y, list(f(y), numeric(3e9)), tolerance = 1e-8)",
                       "# zero_compense : motif",
                       "verifier_egal(\"e\", x - y, list(f(y), numeric(2e9), numeric(2e9)), tolerance = 1e-8)"))
multi <- grep("^\\[INFO\\] ZERO DE COMPENSATION DECLARE A PLUSIEURS ZEROS ", r$sortie)
verifier("#136 débordement : rep(0, 3e9) (temoin.R:2) et rep_len(0, 3e9) (:6) comptent 2 zéros, rep(0, times = 50000, each = 50000) (:4), numeric(3e9) (:8) et deux numeric(2e9) (:10) sont plafonnés à 2147483647 zéros ; aucun arrêt, statut 0",
         .passe(r) && length(multi) == 1L && grepl(" : 5 appels$", r$sortie[multi]) &&
           identical(r$sortie[(multi + 1L):(multi + 5L)],
                     c("[INFO]   tests/unitaires/temoin.R:2 tolerance 1e-08, 2 zeros", "[INFO]   tests/unitaires/temoin.R:4 tolerance 1e-08, 2147483647 zeros",
                       "[INFO]   tests/unitaires/temoin.R:6 tolerance 1e-08, 2 zeros", "[INFO]   tests/unitaires/temoin.R:8 tolerance 1e-08, 2147483647 zeros",
                       "[INFO]   tests/unitaires/temoin.R:10 tolerance 1e-08, 2147483647 zeros")))
# r3 : attendu apparié par R (arguments nommés écartés avant les autres) pour un appel avec argument en trop.
r <- cas_recensement(c("verifier_egal(nom = \"a\", obtenu = x, c(0, 1), extra, tolerance = 1e-8)",
                       "verifier_egal(nom = \"b\", obtenu = x, c(1, 2), extra, tolerance = 1e-8)",
                       "verifier_egal(obtenu = x, \"c\", c(0, 1), extra, tolerance = 1e-8)",
                       "verifier_egal(\"d\", x, c(0, 1), ..., tolerance = 1e-8)",
                       "verifier_egal(\"e\", ..., c(0, 1), tolerance = 1e-8)",
                       "verifier_egal(\"f\", x, c(0, 1), extra, tolerance = 1e-8)"))
zeros <- grep("^\\[INFO\\] ZEROS ATTENDUS A TOLERANCE > 0 ", r$sortie)
comp <- grep("^\\[INFO\\] ZERO DE COMPENSATION DECLARE \\(", r$sortie)
verifier("#136 r3 : l'attendu d'un appel non appariable est lu comme R l'apparie : zéros comptés pour temoin.R:1 (nom et obtenu nommés en tête), :3 (obtenu nommé seul), :4 (`...` après l'attendu), :6 (positionnel, argument en trop) ; pas de zéro en :2 ; `...` avant l'attendu (:5) : attendu inconnu, non compté",
         .passe(r) && length(zeros) == 1L && length(comp) == 1L && grepl(" : 4 appels$", r$sortie[zeros]) &&
           identical(r$sortie[(zeros + 1L):(comp - 1L)],
                     c("[INFO]   tests/unitaires/temoin.R:1 tolerance 1e-08", "[INFO]   tests/unitaires/temoin.R:3 tolerance 1e-08",
                       "[INFO]   tests/unitaires/temoin.R:4 tolerance 1e-08", "[INFO]   tests/unitaires/temoin.R:6 tolerance 1e-08")))
# Motif exigé : une marque sans motif est un [ECHEC] à sa ligne et ne compte pas comme une marque.
r <- cas_recensement(c("# zero_compense",
                       "verifier_egal(\"a\", x - y, 0, tolerance = 1e-8)",
                       "# zero_compense :",
                       "verifier_egal(\"b\", x - y, 0, tolerance = 1e-8)",
                       "# zero_compense :    ",
                       "verifier_egal(\"c\", x - y, 0, tolerance = 1e-8)",
                       "# zero_compense motif sans deux-points",
                       "verifier_egal(\"d\", x - y, 0, tolerance = 1e-8)"))
verifier("TEMOIN #136 : une marque `# zero_compense` sans motif (nue, deux-points seuls, motif d'espaces, sans deux-points) est un échec, statut 1, à sa ligne (temoin.R:1, :3, :5, :7)",
         .echoue_en(r, "tests/unitaires/temoin.R", 1L, "sans motif") && .echoue_en(r, "tests/unitaires/temoin.R", 3L, "sans motif") &&
           .echoue_en(r, "tests/unitaires/temoin.R", 5L, "sans motif") && .echoue_en(r, "tests/unitaires/temoin.R", 7L, "sans motif") &&
           sum(startsWith(r$sortie, "[ECHEC] ")) == 4L)
verifier("#136 : une marque sans motif ne déclare rien : les quatre appels restent sous ZEROS ATTENDUS, aucun déclaré",
         any(grepl("^\\[INFO\\] ZEROS ATTENDUS A TOLERANCE > 0 .* : 4 appels$", r$sortie)) &&
           any(grepl("^\\[INFO\\] ZERO DE COMPENSATION DECLARE \\(.* : 0 appels$", r$sortie)))
r <- cas_recensement(c("x <- 1  # zero_compense", "# zero_compense : motif",
                       "verifier_egal(\"a\", x - y, 0, tolerance = 1e-8)"))
verifier("#136 : un commentaire `# zero_compense` sans motif en fin de ligne n'est pas une marque : pas d'échec ; la marque avec motif de la ligne 2 compte, statut 0",
         .passe(r) && any(grepl("^\\[INFO\\] ZERO DE COMPENSATION DECLARE \\(.* : 1 appels$", r$sortie)))

# #179 : constante lue à sa dernière affectation de premier niveau qui PRÉCÈDE l'appel, numeric(k) et double(k)
# à k non littéral, rep_len(0, k), tolérance positionnelle d'un appel non appariable. Chaque témoin échoue sur
# le script d'avant #179, sauf deux témoins de non-régression qui y passent aussi : la lecture de rep_len (fixée
# par un témoin de comportement, l'en-tête faux étant gardé par un témoin de l'en-tête) et les formes
# d'affectation `=`, `->` et `;` (aucun [ECHEC] après la refonte de la lecture des affectations).
# (1) Constante redéfinie : la valeur est celle de la dernière affectation avant l'appel (ligne, puis colonne).
r <- cas_recensement(c("N <- 3",
                       "# zero_compense : motif",
                       "verifier_egal(\"a\", x - y, list(f(y), rep(0, N)), tolerance = 1e-8)",
                       "N <- 1"))
multi <- grep("^\\[INFO\\] ZERO DE COMPENSATION DECLARE A PLUSIEURS ZEROS ", r$sortie)
verifier("#179 (1) : N <- 3 avant l'appel, N <- 1 après : rep(0, N) compte 3 zéros (temoin.R:3, listé sous A PLUSIEURS ZEROS)",
         .passe(r) && length(multi) == 1L && grepl(" : 1 appels$", r$sortie[multi]) &&
           identical(r$sortie[multi + 1L], "[INFO]   tests/unitaires/temoin.R:3 tolerance 1e-08, 3 zeros"))
r <- cas_recensement(c("N <- 1",
                       "# zero_compense : motif",
                       "verifier_egal(\"a\", x - y, list(f(y), rep(0, N)), tolerance = 1e-8)",
                       "N <- 3"))
multi <- grep("^\\[INFO\\] ZERO DE COMPENSATION DECLARE A PLUSIEURS ZEROS ", r$sortie)
verifier("#179 (1) : N <- 1 avant l'appel, N <- 3 après : rep(0, N) compte 1 zéro (temoin.R:3, non listé sous A PLUSIEURS ZEROS)",
         .passe(r) && length(multi) == 1L && grepl(" : 0 appels$", r$sortie[multi]))
r <- cas_recensement(c("N <- 3",
                       "N <- g(N)",
                       "# zero_compense : motif",
                       "verifier_egal(\"a\", x - y, list(f(y), rep(0, N)), tolerance = 1e-8)"))
multi <- grep("^\\[INFO\\] ZERO DE COMPENSATION DECLARE A PLUSIEURS ZEROS ", r$sortie)
verifier("#179 (1) : N <- 3 puis N <- g(N) (affectation non littérale) avant l'appel : N est inconnue, rep(0, N) compte plusieurs zéros, soit 2 (temoin.R:4), non 3",
         .passe(r) && length(multi) == 1L && identical(r$sortie[multi + 1L], "[INFO]   tests/unitaires/temoin.R:4 tolerance 1e-08, 2 zeros"))
r <- cas_recensement(c("N <- 1",
                       "# zero_compense : motif",
                       "verifier_egal(\"a\", x - y, list(f(y), rep(0, N)), tolerance = 1e-8); N <- 3",
                       "N <- 2",
                       "# zero_compense : motif",
                       "verifier_egal(\"b\", x - y, list(f(y), rep(0, N)), tolerance = 1e-8)"))
multi <- grep("^\\[INFO\\] ZERO DE COMPENSATION DECLARE A PLUSIEURS ZEROS ", r$sortie)
verifier("#179 (1) : sur une même ligne, l'affectation qui suit l'appel (temoin.R:3, N <- 3 après le `;`) ne compte pas : 1 zéro, non listé ; N <- 2 de la ligne 4, qui précède l'appel de la ligne 6, compte : 2 zéros, listé",
         .passe(r) && length(multi) == 1L && grepl(" : 1 appels$", r$sortie[multi]) &&
           identical(r$sortie[multi + 1L], "[INFO]   tests/unitaires/temoin.R:6 tolerance 1e-08, 2 zeros"))
r <- cas_recensement(c("TOL <- 1e-8",
                       "verifier_egal(\"a\", x, list(f(y), 0), tolerance = TOL)",
                       "TOL <- 0",
                       "verifier_egal(\"b\", x, list(f(y), 0), tolerance = TOL)",
                       "TOL <- 1e-6",
                       "verifier_egal(\"c\", x, list(f(y), 0), tolerance = TOL)"))
verifier("#179 (1) : la tolérance symbolique est lue à sa dernière affectation qui précède l'appel : 1e-8 (temoin.R:2), 0 (:4, non recensé), 1e-6 (:6)",
         .passe(r) && any(grepl("a tolerance > 0 : 2 appels", r$sortie, fixed = TRUE)) &&
           any(grepl("tests/unitaires/temoin.R:2 tolerance 1e-08", r$sortie, fixed = TRUE)) &&
           any(grepl("tests/unitaires/temoin.R:6 tolerance 1e-06", r$sortie, fixed = TRUE)) &&
           !any(grepl("temoin.R:4 ", r$sortie, fixed = TRUE)))
r <- cas_recensement(c("O = 4; P <- 1",
                       "3 -> M",
                       "# zero_compense : motif",
                       "verifier_egal(\"a\", x - y, list(f(y), rep(0, M)), tolerance = 1e-8)",
                       "# zero_compense : motif",
                       "verifier_egal(\"b\", x - y, list(f(y), rep(0, O)), tolerance = 1e-8)"))
multi <- grep("^\\[INFO\\] ZERO DE COMPENSATION DECLARE A PLUSIEURS ZEROS ", r$sortie)
verifier("#179 (1) : affectations de premier niveau en `=` (non lue : O est inconnue, 2 zéros, temoin.R:6), en `->` (`3 -> M` lue : 3 zéros, :4) et après un `;` : statut 0, aucun [ECHEC]",
         .passe(r) && length(multi) == 1L && grepl(" : 2 appels$", r$sortie[multi]) &&
           identical(r$sortie[(multi + 1L):(multi + 2L)],
                     c("[INFO]   tests/unitaires/temoin.R:4 tolerance 1e-08, 3 zeros", "[INFO]   tests/unitaires/temoin.R:6 tolerance 1e-08, 2 zeros")))
# (2) numeric(k), double(k), vector("numeric", k) à k non littéral : plusieurs zéros (au moins 2), comme rep(0, k) ;
# k constante du fichier : lue.
r <- cas_recensement(c("N <- 1",
                       "M <- 3",
                       "# zero_compense : motif",
                       "verifier_egal(\"a\", x - y, list(f(y), numeric(k)), tolerance = 1e-8)",
                       "# zero_compense : motif",
                       "verifier_egal(\"b\", x - y, list(f(y), double(k)), tolerance = 1e-8)",
                       "# zero_compense : motif",
                       "verifier_egal(\"c\", x - y, list(f(y), vector(\"numeric\", k)), tolerance = 1e-8)",
                       "# zero_compense : motif",
                       "verifier_egal(\"d\", x - y, list(f(y), rep(0, k)), tolerance = 1e-8)",
                       "# zero_compense : motif",
                       "verifier_egal(\"e\", x - y, list(f(y), numeric(N)), tolerance = 1e-8)",
                       "# zero_compense : motif",
                       "verifier_egal(\"f\", x - y, list(f(y), numeric(M)), tolerance = 1e-8)",
                       "# zero_compense : motif",
                       "verifier_egal(\"g\", x - y, list(f(y), numeric(2)), tolerance = 1e-8)",
                       "# zero_compense : motif",
                       "verifier_egal(\"h\", x - y, list(f(y), numeric(0)), tolerance = 1e-8)",
                       "# zero_compense : motif",
                       "verifier_egal(\"i\", x - y, list(f(y), vector(\"character\", k)), tolerance = 1e-8)"))
multi <- grep("^\\[INFO\\] ZERO DE COMPENSATION DECLARE A PLUSIEURS ZEROS ", r$sortie)
verifier("#179 (2) : numeric(k) (temoin.R:4), double(k) (:6), vector(\"numeric\", k) (:8) comptent 2 zéros comme rep(0, k) (:10) ; numeric(N) avec N <- 1 en compte 1 (:12, non listé), avec M <- 3 en compte 3 (:14) ; numeric(2) en compte 2 (:16) ; numeric(0) (:18) et vector(\"character\", k) (:20) aucun",
         .passe(r) && length(multi) == 1L && grepl(" : 6 appels$", r$sortie[multi]) &&
           identical(r$sortie[(multi + 1L):(multi + 6L)],
                     c("[INFO]   tests/unitaires/temoin.R:4 tolerance 1e-08, 2 zeros", "[INFO]   tests/unitaires/temoin.R:6 tolerance 1e-08, 2 zeros",
                       "[INFO]   tests/unitaires/temoin.R:8 tolerance 1e-08, 2 zeros", "[INFO]   tests/unitaires/temoin.R:10 tolerance 1e-08, 2 zeros",
                       "[INFO]   tests/unitaires/temoin.R:14 tolerance 1e-08, 3 zeros", "[INFO]   tests/unitaires/temoin.R:16 tolerance 1e-08, 2 zeros")))
r <- cas_recensement(c("verifier_egal(\"a\", x, list(f(y), numeric(k)), tolerance = 1e-8)",
                       "verifier_egal(\"b\", x, list(f(y), double(k)), tolerance = 1e-8)",
                       "verifier_egal(\"c\", x, list(f(y), numeric(k)), tolerance = 0)"))
zeros <- grep("^\\[INFO\\] ZEROS ATTENDUS A TOLERANCE > 0 ", r$sortie)
verifier("#179 (2) : sans marque, numeric(k) et double(k) à tolérance > 0 sont listés sous ZEROS ATTENDUS (temoin.R:1 et :2), non à tolérance 0 (:3)",
         .passe(r) && length(zeros) == 1L && grepl(" : 2 appels$", r$sortie[zeros]) &&
           identical(r$sortie[(zeros + 1L):(zeros + 2L)],
                     c("[INFO]   tests/unitaires/temoin.R:1 tolerance 1e-08", "[INFO]   tests/unitaires/temoin.R:2 tolerance 1e-08")))
# rep_len(0, k) : length.out est la longueur du résultat, non un multiplicateur : rep_len(0, 3) compte 2 zéros
# (« plusieurs »), alors que rep(0, 3) en compte 3 ; l'en-tête du script le dit (#179, commentaire du 20/11/2026).
r <- cas_recensement(c("# zero_compense : motif",
                       "verifier_egal(\"a\", x - y, list(f(y), rep_len(0, 3)), tolerance = 1e-8)",
                       "# zero_compense : motif",
                       "verifier_egal(\"b\", x - y, list(f(y), rep(0, 3)), tolerance = 1e-8)",
                       "# zero_compense : motif",
                       "verifier_egal(\"c\", x - y, list(f(y), rep_len(0, 1)), tolerance = 1e-8)",
                       "# zero_compense : motif",
                       "verifier_egal(\"d\", x - y, list(f(y), rep_len(0, 0)), tolerance = 1e-8)"))
multi <- grep("^\\[INFO\\] ZERO DE COMPENSATION DECLARE A PLUSIEURS ZEROS ", r$sortie)
verifier("#179 rep_len : rep_len(0, 3) compte 2 zéros (temoin.R:2), rep(0, 3) en compte 3 (:4) ; rep_len(0, 1) et rep_len(0, 0) ne sont pas listés (:6, :8)",
         .passe(r) && length(multi) == 1L && grepl(" : 2 appels$", r$sortie[multi]) &&
           identical(r$sortie[(multi + 1L):(multi + 2L)],
                     c("[INFO]   tests/unitaires/temoin.R:2 tolerance 1e-08, 2 zeros", "[INFO]   tests/unitaires/temoin.R:4 tolerance 1e-08, 3 zeros")))
entete <- readLines(.script_controle("recensement_tolerances"), n = 80L)
entete <- entete[startsWith(entete, "#")]
verifier("#179 rep_len : l'en-tête du script dit que rep_len(0, 3) compte 2 zéros et ne dit plus que rep_len(0, k) compte k zéros",
         any(grepl("rep_len(0, 3) compte 2 zeros", entete, fixed = TRUE)) && !any(grepl("rep_len(0, k) compte k", entete, fixed = TRUE)) &&
           !any(grepl("rep(0, k) ou rep_len(0, k) compte", entete, fixed = TRUE)))
# Tolérance positionnelle d'un appel non appariable : lue par le même appariement que l'attendu.
r <- cas_recensement(c("TOL <- 1e-8",
                       "verifier_egal(\"a\", x, list(f(y), 0), 0, 2)",
                       "verifier_egal(\"b\", x, list(f(y), 0), 1e-8, 2)",
                       "verifier_egal(\"c\", x, list(f(y), 0), TOL, 2)",
                       "verifier_egal(nom = \"d\", obtenu = x, list(f(y), 0), 0, extra)",
                       "verifier_egal(\"e\", x, list(f(y), 0), tolerance = 0, 2)",
                       "verifier_egal(\"f\", x, list(f(y), 0), ..., 1e-8)",
                       "verifier_egal(\"g\", x, list(f(y), 0), 0, ...)",
                       "verifier_egal(\"h\", x, list(f(y), 0), 2e-8, tolerance = 1e-8)"))
zeros <- grep("^\\[INFO\\] ZEROS ATTENDUS A TOLERANCE > 0 ", r$sortie)
comp <- grep("^\\[INFO\\] ZERO DE COMPENSATION DECLARE \\(", r$sortie)
verifier("#179 tolérance positionnelle : lue par l'appariement : 0 (temoin.R:2, :5, :8, argument en trop ou `...` transmise) et tolerance = 0 nommée (:6) ne sont pas listés ; 1e-8 (:3), TOL (:4) le sont avec leur tolérance lue ; une `...` avant la tolérance (:7) la rend non résolue ; tolérance nommée et positionnelle (:9) : la nommée, 1e-8",
         .passe(r) && length(zeros) == 1L && length(comp) == 1L && grepl(" : 4 appels$", r$sortie[zeros]) &&
           identical(r$sortie[(zeros + 1L):(comp - 1L)],
                     c("[INFO]   tests/unitaires/temoin.R:3 tolerance 1e-08", "[INFO]   tests/unitaires/temoin.R:4 tolerance 1e-08",
                       "[INFO]   tests/unitaires/temoin.R:7 tolerance non resolue", "[INFO]   tests/unitaires/temoin.R:9 tolerance 1e-08")))

# --- paquets_java.sh (#120 ; #95, point 5) --------------------------------------------------
# Script bash : appelé par bash (system2), les listes avant / après sont des fichiers texte. Les
# noms de paquets Java interdits par absence_java.R sont fabriqués comme ailleurs dans ce fichier
# (absence_java.R le balaie). Le fichier de motifs, tests/controles/paquets_java_motifs.txt, n'est
# plus une exclusion nominative d'absence_java.R depuis #180 : son extension .txt est hors du
# balayage ; paquets_java.sh reste balayé.
section("contrôles : paquets_java.sh, paquets système installés (#120)")
r <- cas_java(list("tests/controles/paquets_java_motifs.txt" = c(paste0("^", JDK))))
verifier("#180 : tests/controles/paquets_java_motifs.txt, hors balayage par son extension : un nom de JDK en clair passe", .passe(r))
# L'ancien nom (en .sh) est composé : le dépôt ne le cite plus en clair.
ancien <- paste0("tests/controles/paquets_java_motifs", ".sh")
r <- cas_java(setNames(list(c(paste0("^", JDK))), ancien))
verifier("#180 : l'ancien nom du fichier de motifs (en .sh) n'est plus exclu : un nom de JDK en clair y est refusé, :1",
         .echoue_en(r, ancien, 1L, JDK))
r <- cas_java(list("tests/controles/paquets_java.sh" = c(paste0("MOTIFS=('^", JDK, "')"))))
verifier("#120 : le script paquets_java.sh reste balayé : un nom de JDK en clair y est refusé, :1",
         .echoue_en(r, "tests/controles/paquets_java.sh", 1L, JDK))
r <- cas_java(list("tests/controles/autre.sh" = c(paste0("MOTIFS=('^", JDK, "')"))))
verifier("#120 : le même contenu dans un autre script reste refusé, autre.sh:1", .echoue_en(r, "tests/controles/autre.sh", 1L, JDK))
if (nzchar(Sys.which("bash"))) {
  JRE <- paste0("default-", "jre")
  .script_paquets <- file.path(racine, "tests", "controles", "paquets_java.sh")
  # Lance le script avec `args` (et `env`) ; rend list(statut, sortie). Un échec de lancement
  # donne une ligne [ECHEC] et non une erreur R.
  .lancer_paquets <- function(args, env = character(0)) {
    tryCatch({
      sortie <- suppressWarnings(system2("bash", c(shQuote(.script_paquets), args), stdout = TRUE, stderr = TRUE, env = env))
      statut <- attr(sortie, "status")
      list(statut = if (is.null(statut)) 0L else statut, sortie = sortie)
    }, error = function(e) list(statut = NA_integer_, sortie = paste0("[ECHEC] lancement impossible : ", conditionMessage(e))))
  }
  .essai_paquets <- function(avant, apres, env = character(0)) {
    d <- tempfile("paquets-")
    dir.create(d)
    on.exit(unlink(d, recursive = TRUE), add = TRUE)
    writeLines(avant, file.path(d, "avant.txt"))
    writeLines(apres, file.path(d, "apres.txt"))
    .lancer_paquets(c(shQuote(file.path(d, "avant.txt")), shQuote(file.path(d, "apres.txt"))), env)
  }
  # `paquet` : nom attendu dans la ligne [ECHEC], sans suffixe :arch ni \r.
  .refuse <- function(r, paquet) isTRUE(r$statut == 1L) && any(startsWith(r$sortie, paste0("[ECHEC] ", paquet, " : ")))
  AVANT <- c("bash", "libc6", paste0(OJ, "-headless"))
  for (p in c("libpdfbox-java", JRE, JDK, OJ, "java-common", "libreoffice-java-common", "libx-jni",
              "temurin-17-jdk", "zulu17-jdk", "gcj-12-jdk",
              "openjfx", "openjd", "openjf-x", "jarwrapper", "jarwrapper-extra")) {
    r <- .essai_paquets(AVANT, c(AVANT, "tex-gyre", p))
    verifier(paste0("paquets_java.sh : paquet installé refusé, ", p), .refuse(r, p))
  }
  r <- .essai_paquets(AVANT, c(AVANT, "tex-gyre", "libpdfbox-java:amd64"))
  verifier("paquets_java.sh : suffixe :arch retiré avant la comparaison (libpdfbox-java:amd64 refusé)", .refuse(r, "libpdfbox-java"))
  r <- .essai_paquets(AVANT, c(AVANT, "tex-gyre", "libpdfbox-java\r"))
  verifier("paquets_java.sh : \\r final retiré avant la comparaison (libpdfbox-java\\r refusé)", .refuse(r, "libpdfbox-java"))
  r <- .essai_paquets(c(AVANT, "tex-gyre:amd64"), c(AVANT, "tex-gyre"))
  verifier("paquets_java.sh : un même paquet avec et sans :arch n'est pas une installation, 0 paquet",
           .passe(r) && any(grepl("^\\[OK\\] 0 paquet", r$sortie)))
  r <- .essai_paquets(AVANT, c(AVANT, "tex-gyre", "openjade", "nodejs", "libjavascriptcoregtk-4.1-0"))
  verifier("paquets_java.sh : openjade (et nodejs, libjavascriptcore...) acceptés, statut 0, 4 paquets installés",
           .passe(r) && any(grepl("^\\[OK\\] 4 paquet", r$sortie)))
  r <- .essai_paquets(AVANT, AVANT)
  verifier("paquets_java.sh : un paquet Java déjà présent avant (image du runner) n'est pas refusé (différence), 0 paquet",
           .passe(r) && any(grepl("^\\[OK\\] 0 paquet", r$sortie)))
  r <- .essai_paquets(AVANT, c(AVANT, "tex-gyre", JRE, "libpdfbox-java"))
  verifier("paquets_java.sh : deux paquets Java installés, deux lignes [ECHEC]",
           sum(startsWith(r$sortie, "[ECHEC] ")) == 2L && r$statut == 1L)
  r <- .essai_paquets(AVANT, c(AVANT, "libpdfbox-java"), env = "GITHUB_ACTIONS=true")
  verifier("paquets_java.sh : sous GITHUB_ACTIONS=true, annotation ::error:: en plus de [ECHEC]",
           .refuse(r, "libpdfbox-java") && any(startsWith(r$sortie, "::error::")))
  # env ajoute des variables sans en retirer : la CI pose GITHUB_ACTIONS=true, d'où "false" explicite.
  r <- .essai_paquets(AVANT, c(AVANT, "libpdfbox-java"), env = "GITHUB_ACTIONS=false")
  verifier("paquets_java.sh : hors GitHub Actions, aucune annotation ::error::", .refuse(r, "libpdfbox-java") && !any(startsWith(r$sortie, "::error::")))
  # Limite écrite (en-tête du script) : un contrôle par nom ; un paquet Java d'un autre nom passe.
  r <- .essai_paquets(AVANT, c(AVANT, "libnom-opaque-1"))
  verifier("paquets_java.sh, limite documentée : un paquet d'un autre nom passe au travers", .passe(r))
  # Liste APRES vide : refusée (statut 2), jamais « [OK] 0 paquet ».
  r <- .essai_paquets(AVANT, character(0))
  verifier("paquets_java.sh : liste APRES vide, statut 2 et aucun [OK]", identical(r$statut, 2L) && !any(startsWith(r$sortie, "[OK]")))
  r <- .lancer_paquets(character(0))
  verifier("paquets_java.sh : sans argument, usage et statut 2", identical(r$statut, 2L))
  # Fichier de motifs lu sans être exécuté (#139, Q-33) : copie du script et d'un fichier de motifs
  # de contenu `motifs` dans un dossier temporaire ; rend list(statut, sortie, marque) où `marque`
  # dit si la commande `touch` placée dans le fichier de motifs a été exécutée. `commande` : nom
  # d'une commande factice, déposée dans le dossier (en tête du PATH), qui crée `marque` si elle
  # est exécutée : pour une commande d'un seul mot, que `touch` ne sait pas rendre observable.
  .essai_motifs <- function(motifs, apres = c(AVANT, "tex-gyre", "libpdfbox-java"), commande = NULL) {
    d <- tempfile("motifs-")
    dir.create(d)
    on.exit(unlink(d, recursive = TRUE), add = TRUE)
    env <- character(0)
    if (!is.null(commande)) {
      .deposer(file.path(d, commande), c("#!/bin/sh", paste0("touch '", file.path(d, "marque"), "'")))
      Sys.chmod(file.path(d, commande), "0755")
      env <- paste0("PATH=", shQuote(paste0(d, ":", Sys.getenv("PATH"))))
    }
    file.copy(.script_paquets, file.path(d, "paquets_java.sh"))
    writeLines(sub("@MARQUE@", file.path(d, "marque"), motifs, fixed = TRUE), file.path(d, "paquets_java_motifs.txt"), sep = "\n")
    writeLines(AVANT, file.path(d, "avant.txt"))
    writeLines(apres, file.path(d, "apres.txt"))
    r <- tryCatch({
      sortie <- suppressWarnings(system2("bash", c(shQuote(file.path(d, "paquets_java.sh")), shQuote(file.path(d, "avant.txt")),
                                                  shQuote(file.path(d, "apres.txt"))), stdout = TRUE, stderr = TRUE, env = env))
      statut <- attr(sortie, "status")
      list(statut = if (is.null(statut)) 0L else statut, sortie = sortie)
    }, error = function(e) list(statut = NA_integer_, sortie = paste0("[ECHEC] lancement impossible : ", conditionMessage(e))))
    r$marque <- file.exists(file.path(d, "marque"))
    r
  }
  r <- .essai_motifs(c("touch @MARQUE@", "-java$"))
  verifier("#139 : une commande dans le fichier de motifs n'est pas exécutée (touch sans effet) et fait échouer, statut 2, ligne 1",
           !r$marque && identical(r$statut, 2L) && any(grepl("ligne 1 :", r$sortie, fixed = TRUE)))
  r <- .essai_motifs(c("-java$", "x=1; touch @MARQUE@"))
  verifier("#139 : commande après un motif valide, ligne 2 refusée, rien d'exécuté, statut 2",
           !r$marque && identical(r$statut, 2L) && any(grepl("ligne 2 :", r$sortie, fixed = TRUE)))
  r <- .essai_motifs(c("MOTIFS=(", "  '-java$'", ")"))
  verifier("#139 : ancien format MOTIFS=(...) refusé, statut 2", identical(r$statut, 2L))
  r <- .essai_motifs(c("$(touch@{IFS}@MARQUE@)"))
  verifier("#139 : substitution de commande dans une ligne : refusée sans exécution, statut 2", !r$marque && identical(r$statut, 2L))
  r <- .essai_motifs(c("-java$", "^(abc"))
  verifier("#139 : ERE invalide, ligne 2, statut 2", identical(r$statut, 2L) && any(grepl("ligne 2 :", r$sortie, fixed = TRUE)))
  r <- .essai_motifs(c("# seulement un commentaire", ""))
  verifier("#139 : fichier sans aucun motif refusé, statut 2 (le contrôle n'est pas neutralisé)",
           identical(r$statut, 2L) && any(grepl("aucun motif", r$sortie, fixed = TRUE)))
  r <- .essai_motifs(c("# commentaire", "", "   # commentaire indenté", "-java$\r", "^zulu"))
  verifier("#139 : commentaires, lignes vides et \\r final admis, motif appliqué (libpdfbox-java refusé, statut 1)",
           .refuse(r, "libpdfbox-java") && !r$marque)
  r <- .essai_motifs(c("# commentaire", "^zulu"), apres = c(AVANT, "libpdfbox-java"))
  verifier("#139 : seuls les motifs du fichier s'appliquent (un seul motif, libpdfbox-java accepté), statut 0", .passe(r))
  # Commande d'un seul mot (en-tête du script, #180) : elle a la forme d'un motif, elle est lue comme
  # un motif et jamais exécutée ; la commande factice, sur le PATH, laisserait `marque` si elle l'était.
  r <- .essai_motifs(c("essaimarque"), apres = c(AVANT, "essaimarque-x"), commande = "essaimarque")
  verifier("#180 : commande d'un seul mot dans le fichier de motifs, lue comme motif et jamais exécutée : essaimarque-x refusé, statut 1, aucune marque",
           .refuse(r, "essaimarque-x") && !r$marque)
  # Fichier de motifs absent : seul l'ancien nom (en .sh, composé : le dépôt ne le cite plus en clair)
  # est déposé à côté de la copie du script, il n'est pas lu.
  d_ancien <- tempfile("ancien-")
  dir.create(d_ancien)
  file.copy(.script_paquets, file.path(d_ancien, "paquets_java.sh"))
  writeLines("-java$", file.path(d_ancien, paste0("paquets_java_motifs", ".sh")))
  writeLines(AVANT, file.path(d_ancien, "avant.txt"))
  writeLines(c(AVANT, "libpdfbox-java"), file.path(d_ancien, "apres.txt"))
  r <- tryCatch({
    sortie <- suppressWarnings(system2("bash", c(shQuote(file.path(d_ancien, "paquets_java.sh")), shQuote(file.path(d_ancien, "avant.txt")),
                                                shQuote(file.path(d_ancien, "apres.txt"))), stdout = TRUE, stderr = TRUE))
    statut <- attr(sortie, "status")
    list(statut = if (is.null(statut)) 0L else statut, sortie = sortie)
  }, error = function(e) list(statut = NA_integer_, sortie = paste0("[ECHEC] lancement impossible : ", conditionMessage(e))))
  unlink(d_ancien, recursive = TRUE)
  verifier("#180 : fichier de motifs absent (seul l'ancien nom en .sh présent, non lu), statut 2 et « fichier de motifs illisible »",
           identical(r$statut, 2L) && any(grepl("fichier de motifs illisible", r$sortie, fixed = TRUE)))
  # --lister avec un dpkg-query factice : en échec (statut non nul, aucune liste) ou muet (statut 2).
  d_faux <- tempfile("faux-dpkg-")
  dir.create(d_faux)
  env_faux <- paste0("PATH=", d_faux, ":", Sys.getenv("PATH"))
  .deposer(file.path(d_faux, "dpkg-query"), c("#!/bin/sh", "exit 1"))
  Sys.chmod(file.path(d_faux, "dpkg-query"), "0755")
  r <- .lancer_paquets("--lister", env_faux)
  verifier("paquets_java.sh --lister : dpkg-query en échec, statut non nul (pas de liste vide à statut 0)",
           !is.na(r$statut) && r$statut != 0L && !any(grepl("^[a-z]", r$sortie)))
  .deposer(file.path(d_faux, "dpkg-query"), c("#!/bin/sh", "exit 0"))
  r <- .lancer_paquets("--lister", env_faux)
  verifier("paquets_java.sh --lister : dpkg-query muet, liste vide refusée, statut 2", identical(r$statut, 2L))
  .deposer(file.path(d_faux, "dpkg-query"), c("#!/bin/sh", "echo 'ii  bash'", "echo 'rc  ancien'", "echo 'ii  libc6'"))
  r <- .lancer_paquets("--lister", env_faux)
  verifier("paquets_java.sh --lister : seuls les paquets à l'état ii, triés, statut 0",
           identical(r$statut, 0L) && identical(r$sortie, c("bash", "libc6")))
  unlink(d_faux, recursive = TRUE)
} else {
  cat("  (bash absent : témoins de paquets_java.sh non joués)\n")
}

# --- couloir.sh (#94 ; ADR 0012, points 5, 6 et 23) -----------------------------------------
# Script bash, sans git dans ces cas : ses témoins (mode --temoins : listes construites, dont le
# témoin négatif d'un fichier hors couloir) et la lecture de fiches données par --fiche. Le
# contrôle du diff réel (git diff origin/main...HEAD) tourne dans le job « Contrôles du dépôt »
# de la CI, après --temoins, comme commit_reference.sh. Les motifs de sortie sont ASCII (« .+ »
# pour les lettres et guillemets accentués) : aucun littéral non ASCII dans les motifs.
section("contrôles : couloir.sh, couloirs des branches parallèles (#94)")
if (nzchar(Sys.which("bash"))) {
  .script_couloir <- file.path(racine, "tests", "controles", "couloir.sh")
  .lancer_couloir <- function(args) {
    tryCatch({
      sortie <- suppressWarnings(system2("bash", c(shQuote(.script_couloir), args), stdout = TRUE, stderr = TRUE))
      statut <- attr(sortie, "status")
      list(statut = if (is.null(statut)) 0L else statut, sortie = sortie)
    }, error = function(e) list(statut = NA_integer_, sortie = paste0("[ECHEC] lancement impossible : ", conditionMessage(e))))
  }
  .essai_couloir <- function(fiche) {
    f <- tempfile("fiche-", fileext = ".md")
    on.exit(unlink(f), add = TRUE)
    .deposer(f, fiche)
    .lancer_couloir(c("--branche=br/a", paste0("--fiche=", shQuote(f))))
  }
  r <- .lancer_couloir("--temoins")
  verifier("couloir.sh --temoins : tous les témoins conformes, statut 0",
           identical(r$statut, 0L) && any(grepl("^\\[OK\\] t.+moins : [0-9]+ cas", r$sortie)) && !any(startsWith(r$sortie, "[ECHEC]")))
  r <- .essai_couloir(c("```couloir br/a", "+ R/a.R", "bidon", "```"))
  verifier("couloir.sh : une ligne de forme inconnue est un [ECHEC] fiche:3, statut 1",
           identical(r$statut, 1L) && any(grepl("^\\[ECHEC\\] .*\\.md:3 : ligne de forme inconnue", r$sortie)))
  r <- .essai_couloir(c("```couloir br/a", "+ R/a.R", "```", "```couloir br/a", "+ R/b.R", "```"))
  verifier("couloir.sh : deux blocs pour la même branche, [ECHEC], statut 1",
           identical(r$statut, 1L) && any(grepl(": 2 blocs .+ couloir br/a .+ \\(lignes 1 4\\)", r$sortie)))
  r <- .essai_couloir(c("```text", "+ R/a.R", "```"))
  verifier("couloir.sh : un bloc sous une autre chaîne d'information n'est pas un couloir, [INFO], statut 0",
           .passe(r) && any(startsWith(r$sortie, "[INFO]")))
  r <- .essai_couloir(c("```Couloir br/a", "+ R/a.R", "```"))
  verifier("couloir.sh : une coquille de casse dans la chaîne d'information est un [ECHEC] mal formée, statut 1 (#135)",
           identical(r$statut, 1L) && any(grepl("^\\[ECHEC\\] .*\\.md:1 : cha.+ne d'information .+ mal form", r$sortie)))
  r <- .essai_couloir(c("~~~couloir br/a", "+ R/a.R", "~~~"))
  verifier("couloir.sh : un bloc ouvert par « ~~~couloir » est un [ECHEC] mal formée, statut 1 (#135)",
           identical(r$statut, 1L) && any(grepl("^\\[ECHEC\\] .*\\.md:1 : cha.+ne d'information .+ mal form", r$sortie)))
  r <- .lancer_couloir(c("--branche=sans/bloc", paste0("--fiche=", shQuote(file.path(racine, "docs", "feuille-de-route.md")))))
  verifier("couloir.sh : la feuille de route du dépôt se lit sans erreur de forme ; branche sans bloc : [INFO], statut 0",
           .passe(r) && any(startsWith(r$sortie, "[INFO]")))
  r <- .lancer_couloir("--inconnue")
  verifier("couloir.sh : option inconnue, usage et statut 2", identical(r$statut, 2L))
} else {
  cat("  (bash absent : témoins de couloir.sh non joués)\n")
}

# --- invariance_bilan.R (#149 ; M603) ---------------------------------------------------------
# Contrôle long, hors des batteries : tests/test_unitaires.R le lance avec la seule racine en
# argument, où il ne fait rien (une ligne [INFO], statut 0). Son passage complet (--complet) et son
# échec sur une régression injectée se mesurent par son job de CI et à la main (compte rendu de #149).
r <- .essai("invariance_bilan", list())
verifier("#149 : invariance_bilan.R sans --complet : [INFO], aucun calcul, statut 0",
         .passe(r) && length(r$sortie) == 1L && startsWith(r$sortie, "[INFO] invariance_bilan.R"))

# --- image_reference.R (#67 ; #149) -----------------------------------------------------------
# Copie minimale : ci.yml (deux jobs à conteneur, depuis #149), regenerer-references.yml et
# CONTEXT.md. Le rapport [ECHEC] cite la ligne fautive (et non la première ligne container:).
IMG_A <- paste0("rocker/r-ver:4.3.3@sha256:", strrep("a", 64L))
IMG_B <- paste0("rocker/r-ver:4.3.3@sha256:", strrep("b", 64L))
cas_image <- function(ci = c(IMG_A, IMG_A), context = IMG_A) {
  .essai("image_reference", list(
    ".github/workflows/ci.yml" = c("jobs:", "  a:", paste("    container:", ci[1L]), "  b:",
                                   paste("    container:", ci[2L])),
    ".github/workflows/regenerer-references.yml" = c("jobs:", "  r:", paste("    container:", IMG_A),
                                                      "    env:", paste("      PROVIE_IMAGE:", IMG_A)),
    "CONTEXT.md" = paste0("**Plateforme de référence** : `", context, "`")))
}
r <- cas_image()
verifier("#149 : image_reference.R : même image partout (deux conteneurs dans ci.yml), statut 0",
         .passe(r))
r <- cas_image(context = IMG_B)
verifier("#149 : image_reference.R : CONTEXT.md d'un autre digest que ci.yml (deux lignes container:), [ECHEC] ci.yml:3, pas d'erreur R",
         .echoue_en(r, ".github/workflows/ci.yml", 3L, "image differente de celle de CONTEXT.md") &&
           !any(grepl("Error", r$sortie, fixed = TRUE)))
r <- cas_image(ci = c(IMG_A, IMG_B))
verifier("#149 : image_reference.R : deuxième conteneur de ci.yml d'un autre digest, [ECHEC] à sa ligne (5)",
         .echoue_en(r, ".github/workflows/ci.yml", 5L, "images differentes entre les lignes container:"))
r <- cas_image(ci = c(IMG_A, "rocker/r-ver:4.3.3"))
verifier("#149 : image_reference.R : deuxième conteneur de ci.yml non épinglé, [ECHEC] à sa ligne (5)",
         .echoue_en(r, ".github/workflows/ci.yml", 5L, "image non epinglee par digest"))
verifier("#149 : image_reference.R : un ci.yml fautif ne produit aucun [ECHEC] parasite de témoin",
         !any(grepl("[ECHEC] temoin", r$sortie, fixed = TRUE)))

# --- caracteres_controle.R (#182) -------------------------------------------------------------
# Aucun octet de contrôle en clair dans ce fichier (le script le balaie) : "\f" est écrit avec sa
# barre inverse, les autres octets sont fabriqués par as.raw(). Admis : tabulation, fin de ligne
# (LF, CRLF). Binaires exclus par extension (liste motivée de l'en-tête du script).
CC <- "caracteres_controle"
octets <- function(...) as.raw(c(...))
txt <- function(...) charToRaw(paste0(..., collapse = ""))
cas_cc <- function(fichiers) .essai(CC, fichiers)

section("contrôles : caracteres_controle.R (#182)")
r <- cas_cc(list("docs/latex/a.tex" = c("\\section{A}", "texte", "avant\fsp apres", "fin")))
verifier("#182 : un saut de page (U+000C) dans un .tex est refusé, a.tex:3 avec U+000C et sa colonne (6)",
         .echoue_en(r, "docs/latex/a.tex", 3L, "U+000C (colonne 6)"))
for (code in c(0L, 1L, 7L, 8L, 11L, 12L, 14L, 27L, 31L)) {
  r <- cas_cc(list("R/x.R" = c(octets(utf8ToInt("a"), code), txt("\n"))))
  verifier(paste0("#182 : l'octet de contrôle ", sprintf("U+%04X", code), " est refusé, x.R:1"),
           .echoue_en(r, "R/x.R", 1L, sprintf("U+%04X", code)))
}
r <- cas_cc(list("README.md" = c(txt("a\tb\n"), txt("ligne crlf\r\n"), txt("\tfin\n"))))
verifier("#182 : tabulation, saut de ligne et CRLF sont admis (statut 0)", .passe(r))
r <- cas_cc(list("README.md" = c(txt("a\r\n"), txt("b\r\n"), octets(utf8ToInt("c"), 12L), txt("\r\n"))))
verifier("#182 : un fichier en CRLF : la ligne de l'octet de contrôle est comptée aux sauts de ligne (3)",
         .echoue_en(r, "README.md", 3L, "U+000C (colonne 2)"))
r <- cas_cc(list("docs/note.md" = c(octets(12L, 12L, 27L), txt("\nsuite\n"))))
verifier("#182 : plusieurs octets sur une même ligne : une seule ligne [ECHEC], tous cités",
         .echoue_en(r, "docs/note.md", 1L, "U+000C (colonne 1), U+000C (colonne 2), U+001B (colonne 3)") &&
           sum(startsWith(r$sortie, "[ECHEC]")) == 1L)
r <- cas_cc(list("LICENSE" = c(txt("texte\n"), octets(12L), txt("\n"))))
verifier("#182 : un fichier sans extension est examiné, LICENSE:2", .echoue_en(r, "LICENSE", 2L, "U+000C"))
r <- cas_cc(list(".claude/agents/z.md" = c(txt("a\n"), octets(12L))))
verifier("#182 : un fichier caché sous .claude/ est examiné, dernier octet sans saut de ligne, z.md:2",
         .echoue_en(r, ".claude/agents/z.md", 2L, "U+000C"))
r <- cas_cc(list("docs/ok.md" = "texte propre", "docs/a.PDF" = octets(37L, 80L, 0L, 12L, 1L, 255L),
                 "inst/b.png" = octets(137L, 80L, 78L, 71L, 0L, 12L), "inst/c.rds" = octets(0L, 1L, 2L)))
verifier("#182 : PDF, PNG et RDS (octets de contrôle propres au format) sont exclus : statut 0, une ligne [INFO] chacun",
         .passe(r) && sum(startsWith(r$sortie, "[INFO]") & grepl("binaire", r$sortie, fixed = TRUE)) == 3L &&
           any(startsWith(r$sortie, "[INFO] docs/a.PDF ")))
r <- cas_cc(list("docs/ok.md" = "texte propre", "docs/a.txt" = octets(37L, 80L, 0L, 12L, 1L, 255L)))
verifier("#182 : les mêmes octets dans un .txt sont refusés (l'exclusion est par extension, pas par contenu)",
         .echoue_en(r, "docs/a.txt", 1L, "U+0000"))
r <- cas_cc(list("docs/a.pdf" = octets(37L, 80L, 12L)))
verifier("#182 : une racine dont tous les fichiers sont binaires n'examine rien : [ECHEC] (liste vide)",
         r$statut == 1L && any(startsWith(r$sortie, "[ECHEC] aucun fichier a examiner")))
r <- cas_cc(list("a.md" = "propre", "docs/b.md" = "propre aussi"))
verifier("#182 : fichiers propres : statut 0, une ligne [OK] qui compte 2 fichiers",
         .passe(r) && any(grepl("^\\[OK\\] 2 fichier", r$sortie)))
r <- cas_cc(list("docs/long.md" = c(rep(c(octets(12L), txt("\n")), 25L))))
verifier("#182 : au plus 20 lignes citées par fichier, puis une ligne de reste (5 autres)",
         .echoue_en(r, "docs/long.md", 20L, "U+000C") && !any(startsWith(r$sortie, "[ECHEC] docs/long.md:21 ")) &&
           any(grepl("5 autre(s) ligne(s)", r$sortie, fixed = TRUE)))
# Temoin de passage a l'echelle : un binaire d'extension non listee d'environ 1 Mo (octets
# tires sous une graine locale, generateur fixe, etat global restaure). Avant la correction
# (recherche du debut de ligne par octet fautif : quadratique), 300 ko demandaient 58 s et 1 Mo
# plus de dix minutes ; apres, moins d'une seconde. Seuil large (60 s) : il ne vise qu'a
# separer le lineaire du quadratique, sans dependre de la machine.
.octets_aleatoires <- function(n, graine) {
  existait <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  ancien <- if (existait) get(".Random.seed", envir = globalenv())
  on.exit(if (existait) assign(".Random.seed", ancien, envir = globalenv())
          else rm(".Random.seed", envir = globalenv()), add = TRUE)
  set.seed(graine, kind = "Mersenne-Twister", normal.kind = "Inversion",
           sample.kind = "Rejection")
  as.raw(sample.int(256L, n, replace = TRUE) - 1L)
}
duree <- system.time(r <- cas_cc(list("docs/x.dat" = .octets_aleatoires(1e6L, 182L))))[["elapsed"]]
verifier("#182 : un binaire non liste de 1 Mo est refuse, x.dat:1 et reste de lignes, en moins de 60 s",
         .echoue_en(r, "docs/x.dat", 1L, "U+") && any(grepl("autre(s) ligne(s) atteinte(s)", r$sortie, fixed = TRUE)) &&
           sum(startsWith(r$sortie, "[ECHEC] docs/x.dat:")) == 20L && duree < 60)

# Voie `git ls-files` de caracteres_controle.R : témoins dans tests/unitaires/voie_git.R (#186).
section("contrôles : sans git, les témoins de la voie git sont sautés visiblement (#186)")
# Sans git (l'image rocker/r-ver du job « Tests (R 4.3.3) »), voie_git.R saute ses témoins de la voie
# git ; avant #186, le saut ne laissait aucune trace au journal. Un processus fils sourcé avec
# Sys.which() masquée (git introuvable) en rend le journal.
.sans_git <- local({
  script <- tempfile(fileext = ".R")
  on.exit(unlink(script), add = TRUE)
  writeLines(c("options(warn = 2)", paste0("racine <- ", deparse(racine)),
               paste0("source(", deparse(file.path(racine, "tests", "harnais.R")), ")"),
               "Sys.which <- function(names) stats::setNames(character(length(names)), names)",
               paste0("source(", deparse(file.path(racine, "tests", "unitaires", "voie_git.R")), ")"),
               "bilan()"), script)
  sortie <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"), shQuote(script), stdout = TRUE, stderr = TRUE))
  statut <- attr(sortie, "status")
  list(statut = if (is.null(statut)) 0L else statut, sortie = sortie)
})
.noms_sautes <- grep("^\\[INFO\\] SAUTE : [^0-9]", .sans_git$sortie, value = TRUE)
verifier("#186 : sans git : statut 0, aucun [ECHEC], et chaque témoin de la voie git est nommé au journal par une ligne [INFO] SAUTE",
         .sans_git$statut == 0L && !any(startsWith(.sans_git$sortie, "[ECHEC]")) && length(.noms_sautes) >= 10L &&
           any(grepl("C5 : fichier suivi interdit", .noms_sautes, fixed = TRUE)) &&
           !any(grepl("^\\[OK\\] C5 : fichier suivi interdit", .sans_git$sortie)))
verifier("#186 : sans git : une ligne [INFO] compteur donne le nombre de témoins sautés, égal au nombre de lignes nommées",
         any(.sans_git$sortie == paste0("[INFO] SAUTE : ", length(.noms_sautes), " témoin(s) de la voie git -- ",
                                        "git absent du PATH ; rejoués par tests/temoins_voie_git.R dans le job « Contrôles du dépôt »")))
verifier("#186 : sans git : les témoins qui n'ont pas besoin de git tournent (lien symbolique en arborescence)",
         any(startsWith(.sans_git$sortie, "[OK] #186 : arborescence : un lien symbolique")))
