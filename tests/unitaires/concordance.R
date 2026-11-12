# Tests du script tests/concordance_doc_moteur.R sur des racines fictives (option
# --racine=) : le script tourne dans un processus Rscript distinct, on lit statut et sortie.
# `racine` est défini par la batterie.

lancer_concordance <- function(contenu_doc, r_outils = "f_un <- function() 1\n.aux <- function() 2\n.K <- 3\nk_min <- 4\n",
                               namespace = "export(f_un)\n", strict = TRUE) {
  faux <- tempfile("racine-")
  on.exit(unlink(faux, recursive = TRUE), add = TRUE)
  dir.create(file.path(faux, "R"), recursive = TRUE)
  dir.create(file.path(faux, "docs", "latex"), recursive = TRUE)
  writeLines(r_outils, file.path(faux, "R", "outils.R"))
  writeLines(namespace, file.path(faux, "NAMESPACE"))
  if (!is.null(contenu_doc)) {
    writeLines(contenu_doc, file.path(faux, "docs", "latex", "doc_outil_prov_vie.tex"))
  }
  sortie <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"),
    c(shQuote(file.path(racine, "tests", "concordance_doc_moteur.R")),
      if (strict) "--strict", paste0("--racine=", shQuote(faux))),
    stdout = TRUE, stderr = TRUE))
  statut <- attr(sortie, "status")
  list(statut = if (is.null(statut)) 0L else statut, sortie = paste(sortie, collapse = "\n"))
}

tableau <- function(module, ...) {
  c(paste0("% concordance-fonctions : ", module), "\\begin{tabular}{ll}",
    "Fonction & Rôle \\\\", paste0("\\code{", c(...), "} & texte \\code{ignoré} \\\\"),
    "\\end{tabular}")
}

section("concordance : racines fictives")
r <- lancer_concordance(NULL)
verifier("document absent, --strict : échec", r$statut == 1L && grepl("[ECHEC]", r$sortie, fixed = TRUE) &&
           grepl("absent", r$sortie, fixed = TRUE))
r <- lancer_concordance(NULL, strict = FALSE)
verifier("document absent, sans --strict : avertissement, statut 0",
         r$statut == 0L && grepl("[AVERT]", r$sortie, fixed = TRUE))
r <- lancer_concordance(tableau("outils", "f\\_un()"))
verifier("document concordant : statut 0 (fonction à point, constante à point et objet en minuscules non recensés)",
         r$statut == 0L && grepl("module outils : 1 fonction(s) concordante(s)", r$sortie, fixed = TRUE))
r <- lancer_concordance(tableau("outils", "f\\_un()"), r_outils = "f_un <- function() 1\ng <- function() 2\n")
verifier("fonction du code absente du document : échec --strict, nom cité",
         r$statut == 1L && grepl("fonctions absentes du document : g", r$sortie, fixed = TRUE))
r <- lancer_concordance(tableau("outils", "f\\_un()"), r_outils = "f_un <- function() 1\ng <- function() 2\n",
                        strict = FALSE)
verifier("même écart sans --strict : [AVERT], statut 0", r$statut == 0L &&
           grepl("[AVERT] module outils", r$sortie, fixed = TRUE))
r <- lancer_concordance(tableau("outils", "f\\_un()", "fantome()"))
verifier("fonction citée absente du code : échec", r$statut == 1L &&
           grepl("citées mais absentes du code : fantome", r$sortie, fixed = TRUE))
r <- lancer_concordance(tableau("outils", "f\\_un()", "f\\_un()"))
verifier("fonction citée deux fois : échec", r$statut == 1L && grepl("citées deux fois", r$sortie, fixed = TRUE))
r <- lancer_concordance(tableau("outils", "f\\_un"), namespace = "export(f_un)\nexport(autre)\n")
verifier("export non cité : échec", r$statut == 1L && grepl("non cités dans le document : autre", r$sortie, fixed = TRUE))
r <- lancer_concordance(tableau("moteur_inconnu", "x"))
verifier("module inconnu dans le document : échec", r$statut == 1L &&
           grepl("module inconnu", r$sortie, fixed = TRUE))
r <- lancer_concordance(c("\\begin{document}", "\\code{f\\_un} hors de tout tableau"))
verifier("module avec fonctions sans tableau : échec", r$statut == 1L &&
           grepl("aucun tableau", r$sortie, fixed = TRUE))
r <- lancer_concordance(c(tableau("outils", "f\\_un"), tableau("outils", "f\\_un")))
verifier("deux tableaux pour un module : échec", r$statut == 1L &&
           grepl("deux tableaux", r$sortie, fixed = TRUE))

# Valeurs des constantes (issue #37) : tableau de constantes à la suite du tableau de
# fonctions du module (le module est celui du dernier marqueur).
# En-tête à trois cellules par défaut (un tableau à deux colonnes : colonnes = 2) ; une
# rangée qui a plus de cellules que l'en-tête est un écart.
entete_constantes <- function(colonnes = 3L) {
  c("\\begin{tabular}{@{}p{5.6cm}p{9.5cm}@{}}",
    paste0("\\textcolor{financeblue}{\\textbf{Constante}} & \\textcolor{financeblue}{\\textbf{Valeur}}",
           if (colonnes == 3L) " & \\textcolor{financeblue}{\\textbf{Objet}}", " \\\\"))
}
constantes_doc <- function(...) c(entete_constantes(), paste0(c(...), " \\\\"), "\\end{tabular}")
R_CONSTANTES <- paste(c("f_un <- function() 1", ".aux <- function(x) x + 1L",
                        "K <- 3L", "NOM <- \"a_b\"", "LISTE <- c(\"x\", \"y\", \"z\")",
                        "TAB <- data.frame(a = 1:2)", "DEP <- c(NOM, \"w\")", "SANS <- list(1, 2)",
                        "PAR_FONCTION <- .aux(1L)"), collapse = "\n")
# Code d'outils réduit aux fonctions et aux constantes nommées (un tableau de constantes
# doit citer toutes les constantes du code, issue #41).
code_avec <- function(...) {
  lignes <- strsplit(R_CONSTANTES, "\n", fixed = TRUE)[[1L]]
  constantes <- grepl("^[A-Z][A-Z0-9_]* <- ", lignes)
  garde <- vapply(strsplit(lignes, " <- ", fixed = TRUE), function(x) x[1L] %in% c(...), NA)
  paste(lignes[!constantes | garde], collapse = "\n")
}
doc_constantes <- function(...) c(tableau("outils", "f\\_un"), constantes_doc(...))
verifie_constantes <- function(nom, lignes, attendu, strict = TRUE, r_outils = R_CONSTANTES) {
  r <- lancer_concordance(doc_constantes(lignes), r_outils = r_outils, strict = strict)
  verifier(nom, r$statut == (if (strict) 1L else 0L) && grepl(attendu, r$sortie, fixed = TRUE))
}

section("concordance : valeurs des constantes")
r <- lancer_concordance(doc_constantes(
  "\\code{K} & Entier \\code{3}~: objet",
  "\\code{NOM} & \\code{\"a\\_b\"} & objet",
  "\\code{LISTE} & \\code{x}, \\code{y}, \\code{z}~: trois valeurs",
  "\\code{TAB} & Tableau de deux lignes",
  "\\code{DEP} & Deux valeurs~: \\code{a\\_b}, \\code{w}",
  "\\code{SANS} & Liste sans valeur littérale",
  "\\code{PAR\\_FONCTION} & Entier \\code{2}"), r_outils = R_CONSTANTES)
verifier("constantes concordantes (chaîne, entier, décompte, liste, constante qui en lit une autre, fonction à point) : statut 0",
         r$statut == 0L && grepl("constantes du module outils : 7 citée(s), 6 valeur(s) littérale(s) concordante(s)", r$sortie, fixed = TRUE))
verifier("constante sans valeur littérale : nommée, pas d'écart",
         grepl("sans valeur littérale lue : SANS", r$sortie, fixed = TRUE))
r <- lancer_concordance(doc_constantes("\\code{K} & \\code{3}~: objet", "\\code{NOM} & Entier \\code{3} & objet"),
                        r_outils = R_CONSTANTES)
verifier("tableau à trois colonnes, liste en tête de la deuxième cellule : lue et concordante (K) ; entier pour une chaîne : écart (NOM)",
         r$statut == 1L && grepl("constante NOM", r$sortie, fixed = TRUE) && !grepl("constante K ", r$sortie, fixed = TRUE))
r <- lancer_concordance(doc_constantes("\\code{K} & Valeur libre & Objet seul", "\\code{SANS} & Texte libre & \\code{3}~: objet"),
                        r_outils = code_avec("K", "SANS"))
verifier("tableau à trois colonnes, aucune forme lue : statut 0, constantes nommées « sans valeur littérale lue »",
         r$statut == 0L && grepl("sans valeur littérale lue : K, SANS", r$sortie, fixed = TRUE))
verifie_constantes("chaîne différente : échec, constante, ligne et valeurs citées", "\\code{NOM} & \\code{\"a\"} & objet",
                   "constante NOM (module outils) -- ligne 8 : chaîne du document", TRUE)
verifie_constantes("entier différent : échec", "\\code{K} & Entier \\code{4}~: objet", "entier du document « 4 », code 3L")
verifie_constantes("entier écrit pour une constante réelle : échec (type)", "\\code{K} & Entier \\code{3}~: objet",
                   "entier du document", r_outils = sub("K <- 3L", "K <- 3", R_CONSTANTES, fixed = TRUE))
verifie_constantes("liste dans un autre ordre : échec", "\\code{LISTE} & \\code{y}, \\code{x}, \\code{z}~: objet",
                   "liste du document « y, x, z »")
verifie_constantes("liste d'une valeur de moins : échec", "\\code{LISTE} & \\code{x}, \\code{y}~: objet",
                   "liste du document « x, y »")
verifie_constantes("décompte faux d'un vecteur : échec", "\\code{LISTE} & quatre chaînes", "décompte du document « quatre chaînes »")
verifie_constantes("décompte faux des lignes d'un data.frame : échec", "\\code{TAB} & Tableau, trois lignes",
                   "décompte du document « trois lignes », code data.frame de 2 ligne(s)")
verifie_constantes("décompte en chiffres faux : échec", "\\code{LISTE} & 4 lignes", "décompte du document")
verifie_constantes("nombre composé en lettres : écart, non lu", "\\code{LISTE} & vingt-deux lignes",
                   "décompte en lettres non lu : vingt-deux lignes")
verifie_constantes("constante citée absente du module : échec", "\\code{FANTOME} & Entier \\code{1}",
                   "constante FANTOME (module outils) -- ligne 8 : absente de R/outils.R")
verifie_constantes("constante non évaluable sans le package : échec", "\\code{NOM} & \\code{\"a\\_b\"}",
                   "non évaluable sans le package", r_outils = paste(R_CONSTANTES, "NOM <- stop(\"x\")", sep = "\n"))
verifie_constantes("constante citée deux fois : échec", c("\\code{K} & Entier \\code{3}", "\\code{K} & Entier \\code{3}"),
                   "citée deux fois dans le tableau")
r <- lancer_concordance(c("\\begin{document}", constantes_doc("\\code{K} & Entier \\code{3}"), tableau("outils", "f\\_un")),
                        r_outils = R_CONSTANTES)
verifier("tableau de constantes avant tout marqueur de module : échec", r$statut == 1L &&
           grepl("avant tout marqueur de module", r$sortie, fixed = TRUE))
verifie_constantes("ligne dont la première cellule n'est pas \\code{NOM} : échec", "Texte & Entier \\code{3}",
                   "première cellule sans \\code{NOM} seul")
verifie_constantes("même écart sans --strict : [AVERT], statut 0", "\\code{K} & Entier \\code{4}",
                   "[AVERT] constante K", strict = FALSE)

# Rangée sur plusieurs lignes du source : lue en entier jusqu'au « \\\\ » final.
verifie_constantes("rangée sur deux lignes du source, décompte faux dans la seconde : échec, ligne de début citée",
                   "\\code{TAB} & Tableau de trois\nlignes", "constante TAB (module outils) -- ligne 8 : décompte du document « trois lignes »")
r <- lancer_concordance(doc_constantes("\\code{TAB} & Tableau de deux\nlignes"), r_outils = code_avec("TAB"))
verifier("même rangée sur deux lignes, décompte juste : statut 0, valeur lue", r$statut == 0L &&
           grepl("1 citée(s), 1 valeur(s) littérale(s) concordante(s)", r$sortie, fixed = TRUE))
r <- lancer_concordance(c(tableau("outils", "f\\_un"), "\\begin{tabular}{ll}",
                          "\\textbf{Constante} & \\textbf{Valeur} \\\\", "\\code{K} & Entier \\code{3}", "\\end{tabular}"),
                        r_outils = R_CONSTANTES)
verifier("rangée sans \\\\ final avant la fin du tableau : échec, ligne citée", r$statut == 1L &&
           grepl("ligne 8 : rangée sans \\\\ final avant la fin du tableau", r$sortie, fixed = TRUE))

# Convention : toute cellule lue qui contient un \code{"..."} sans forme reconnue est un écart.
verifie_constantes("version \\code{\"...\"} dans la deuxième cellule, sans forme reconnue : échec",
                   "\\code{NOM} & version \\code{\"a\\_b\"}", "ligne 8 : la cellule 2 contient 1 \\code{\"...\"} non lu(s)")
verifie_constantes("\\code{\"...\"} dans la troisième cellule : échec", "\\code{NOM} & \\code{\"a\\_b\"} & version \\code{\"1.3\"}",
                   "ligne 8 : la cellule 3 contient 1 \\code{\"...\"} non lu(s)")
verifie_constantes("même écart sans --strict : [AVERT], statut 0", "\\code{NOM} & version \\code{\"a\\_b\"}",
                   "[AVERT] constante NOM", strict = FALSE)
r <- lancer_concordance(doc_constantes("\\code{NOM} & \\code{\"a\\_b\"}", "\\code{SANS} & version \\code{x}"),
                        r_outils = code_avec("NOM", "SANS"))
verifier("chaîne reconnue seule, ou \\code{} sans guillemets dans une cellule sans forme : pas d'écart, cellule non lue nommée",
         r$statut == 0L && grepl("sans valeur littérale lue : SANS", r$sortie, fixed = TRUE))

# Règle étendue : tout \code{"..."} qu'aucune forme n'a consommé est un écart, où qu'il soit.
verifie_constantes("chaîne suivie d'un second \\code{\"...\"} (a1) : échec",
                   "\\code{NOM} & \\code{\"a\\_b\"} (anciennement \\code{\"1.3\"})",
                   "ligne 8 : la cellule 2 contient 1 \\code{\"...\"} non lu(s)")
verifie_constantes("décompte juste puis \\code{\"...\"} (a2) : échec", "\\code{LISTE} & trois chaînes, version \\code{\"1.3\"}",
                   "ligne 8 : la cellule 2 contient 1 \\code{\"...\"} non lu(s)")
verifie_constantes("liste après « ~: » puis \\code{\"...\"} en troisième cellule (a3) : échec",
                   "\\code{LISTE} & Liste & objet~: \\code{x}, \\code{y}, \\code{z} ; version \\code{\"1.3\"}",
                   "ligne 8 : la cellule 3 contient 1 \\code{\"...\"} non lu(s)")
verifie_constantes("même cas a3 sans --strict : [AVERT], statut 0",
                   "\\code{LISTE} & Liste & objet~: \\code{x}, \\code{y}, \\code{z} ; version \\code{\"1.3\"}",
                   "[AVERT] constante LISTE", strict = FALSE)
verifie_constantes("liste écrite avec guillemets : échec, message explicite",
                   "\\code{LISTE} & \\code{\"x\"}, \\code{\"y\"}, \\code{\"z\"}~: valeurs",
                   "liste de valeurs écrite avec guillemets")
verifie_constantes("deux \\code{\"...\"} non lus : nombre cité", "\\code{NOM} & texte \\code{\"a\"} et \\code{\"b\"}",
                   "contient 2 \\code{\"...\"} non lu(s)")

# Fin de rangée et nombre de cellules.
doc_brut <- function(lignes, colonnes = 3L) c(tableau("outils", "f\\_un"), entete_constantes(colonnes), lignes, "\\end{tabular}")
r <- lancer_concordance(doc_brut(c("\\code{K} & Entier \\code{3} & objet", "\\code{NOM} & \\code{\"a\\_b\"} \\\\")),
                        r_outils = R_CONSTANTES)
verifier("première de deux rangées sans \\\\ final : rangées fusionnées, écart avec ligne et nombre de cellules", r$statut == 1L &&
           grepl("ligne 8 : rangée fusionnée ou \\\\ manquant (4 cellules, l'en-tête en a 3)", r$sortie, fixed = TRUE))
r <- lancer_concordance(doc_brut(c("\\code{K} & Entier \\code{3}", "\\code{NOM} & \\code{\"a\\_b\"} \\\\"), 2L),
                        r_outils = R_CONSTANTES)
verifier("rangée fusionnée dans un tableau à deux colonnes : écart", r$statut == 1L &&
           grepl("ligne 8 : rangée fusionnée ou \\\\ manquant (3 cellules, l'en-tête en a 2)", r$sortie, fixed = TRUE))
r <- lancer_concordance(doc_brut(c("\\code{K} & Entier \\code{3} & objet \\\\", "\\code{NOM} & \\code{\"a\\_b\"} & x & y \\\\")),
                        r_outils = R_CONSTANTES)
verifier("rangée de quatre cellules sous un en-tête de trois : écart, la rangée précédente reste lue", r$statut == 1L &&
           grepl("ligne 9 : rangée fusionnée ou \\\\ manquant (4 cellules, l'en-tête en a 3)", r$sortie, fixed = TRUE))
r <- lancer_concordance(doc_brut(c("\\code{K} & Entier \\code{3} \\\\ \\hline", "\\code{NOM} & \\code{\"a\\_b\"} \\\\[2pt]",
                                   "\\code{LISTE} & trois chaînes \\\\[1ex] \\midrule", "\\midrule")),
                        r_outils = code_avec("K", "NOM", "LISTE"))
verifier("\\\\ suivi de \\hline, de [...] ou de \\midrule en fin de ligne : rangées lues", r$statut == 0L &&
           grepl("3 citée(s), 3 valeur(s) littérale(s) concordante(s)", r$sortie, fixed = TRUE))
r <- lancer_concordance(doc_brut(c("\\code{K} & Entier \\code{4} \\\\ \\hline")), r_outils = R_CONSTANTES)
verifier("rangée finie par \\\\ \\hline : valeur comparée (entier faux : échec)", r$statut == 1L &&
           grepl("entier du document « 4 »", r$sortie, fixed = TRUE))

# Complétude (issue #41, décision M408) : le tableau cite toutes les constantes en majuscules
# de premier niveau du module ; les noms à point, les fonctions et les objets en minuscules
# ne sont pas recensés.
complet <- c("\\code{K} & Entier \\code{3}", "\\code{NOM} & \\code{\"a\\_b\"}", "\\code{LISTE} & trois chaînes")
r <- lancer_concordance(doc_constantes(complet), r_outils = code_avec("K", "NOM", "LISTE"))
verifier("tableau complet : statut 0, aucune constante absente", r$statut == 0L &&
           !grepl("constantes absentes", r$sortie, fixed = TRUE) &&
           grepl("constantes du module outils : 3 citée(s)", r$sortie, fixed = TRUE))
r <- lancer_concordance(doc_constantes(complet), r_outils = paste(code_avec("K", "NOM", "LISTE"), "NOUVELLE <- 1L", sep = "\n"))
verifier("constante ajoutée au code, absente du tableau : échec --strict, constante nommée", r$statut == 1L &&
           grepl("module outils -- constantes absentes du document : NOUVELLE", r$sortie, fixed = TRUE))
r <- lancer_concordance(doc_constantes(complet), r_outils = paste(code_avec("K", "NOM", "LISTE"), "N2 = 1L", "N3 <- 2L", sep = "\n"))
verifier("deux constantes absentes (affectations = et <-) : toutes nommées", r$statut == 1L &&
           grepl("constantes absentes du document : N2, N3", r$sortie, fixed = TRUE))
r <- lancer_concordance(doc_constantes(complet), r_outils = paste(code_avec("K", "NOM", "LISTE"), "3L -> DROITE", sep = "\n"))
verifier("constante affectée par -> absente du tableau : échec, nommée", r$statut == 1L &&
           grepl("constantes absentes du document : DROITE", r$sortie, fixed = TRUE))
r <- lancer_concordance(doc_constantes(complet), r_outils = paste(code_avec("K", "NOM", "LISTE"), "`APOSTROPHE` <- 1L", sep = "\n"))
verifier("constante au nom entre accents graves absente du tableau : échec, nommée", r$statut == 1L &&
           grepl("constantes absentes du document : APOSTROPHE", r$sortie, fixed = TRUE))
r <- lancer_concordance(doc_constantes(complet), r_outils = paste(code_avec("K", "NOM", "LISTE"), "GLOBALE <<- 1L", "AUTRE := 1", sep = "\n"))
verifier("<<- et := ne sont pas des affectations de constante (comme pour constantes_du_code) : non exigées, statut 0",
         r$statut == 0L && !grepl("constantes absentes", r$sortie, fixed = TRUE))
r <- lancer_concordance(doc_constantes(c(complet, "\\code{DROITE} & Entier \\code{3}")),
                        r_outils = paste(code_avec("K", "NOM", "LISTE"), "3L -> DROITE", sep = "\n"))
verifier("constante affectée par -> et citée : valeur lue, statut 0", r$statut == 0L &&
           grepl("4 citée(s), 4 valeur(s) littérale(s) concordante(s)", r$sortie, fixed = TRUE))
r <- lancer_concordance(doc_constantes(complet), r_outils = paste(code_avec("K", "NOM", "LISTE"), "NOUVELLE <- 1L", sep = "\n"),
                        strict = FALSE)
verifier("même écart sans --strict : [AVERT], statut 0", r$statut == 0L &&
           grepl("[AVERT] module outils -- constantes absentes du document : NOUVELLE", r$sortie, fixed = TRUE))
r <- lancer_concordance(c(tableau("outils", "f\\_un", "FONC", "LAMB"), constantes_doc(complet)), r_outils = paste(
  code_avec("K", "NOM", "LISTE"), ".INTERNE <- 1L", "FONC <- function() 1", "LAMB <- \\(x) x", "mini <- 2L",
  "if (TRUE) { DANS_BLOC <- 1L }", "sapply(1, function(i) { DANS_FONCTION <- i })", sep = "\n"))
verifier("constante à point, fonction ou lambda en majuscules, objet en minuscules, affectation hors premier niveau : non exigés, statut 0",
         r$statut == 0L && !grepl("constantes absentes", r$sortie, fixed = TRUE))
r <- lancer_concordance(tableau("outils", "f\\_un"), r_outils = "f_un <- function() 1\nK <- 3L\nL <- 4L\n")
verifier("module qui a des constantes mais aucun tableau de constantes : échec, constantes nommées", r$statut == 1L &&
           grepl("module outils -- constantes dans R/ mais aucun tableau de constantes dans le document : K, L", r$sortie, fixed = TRUE))
r <- lancer_concordance(tableau("outils", "f\\_un"), r_outils = "f_un <- function() 1\nK <- 3L\n", strict = FALSE)
verifier("même écart sans --strict : [AVERT], statut 0", r$statut == 0L &&
           grepl("[AVERT] module outils -- constantes dans R/ mais aucun tableau", r$sortie, fixed = TRUE))
r <- lancer_concordance(tableau("outils", "f\\_un"), r_outils = "f_un <- function() 1\n.INTERNE <- 3L\n")
verifier("module sans constante en majuscules et sans tableau : statut 0", r$statut == 0L)
