# Tests du script tests/concordance_doc_moteur.R sur des racines fictives (option
# --racine=) : le script tourne dans un processus Rscript distinct, on lit statut et sortie.
# `racine` est défini par la batterie.

# Décomptes du texte courant (issue #104) : le contrôle exige un marqueur par portée (les
# quinze modules et `package`). Par défaut (decomptes = "auto"), lancer_concordance() ajoute
# à la fin du document fictif un marqueur concordant pour chaque portée, comptes tirés du
# code et du NAMESPACE fictifs, suivi d'un paragraphe sans décompte ; les lignes du document
# fourni gardent leur numéro. decomptes = NULL n'ajoute rien ; un vecteur de lignes remplace
# les marqueurs ajoutés.
MODULES_DOC <- c("outils", "dictionnaire", "lecture", "donnees", "tables", "garanties",
                 "engagement", "triangle", "risque_en_cours", "regles_comptables", "projection",
                 "plan", "rapport", "simulation", "calculer_provisions")
bloc_decomptes <- function(portee, grandeurs, texte = "Texte sans décompte.") {
  c("", paste("% concordance-decomptes :", portee, paste(grandeurs, collapse = " ")), texte)
}
# Blocs concordants pour les portées de `portees` (par défaut toutes), d'après le code
# fictif d'outils et les export() du NAMESPACE fictif ; les autres modules n'ont pas de fichier.
decomptes_auto <- function(r_outils, namespace, portees = c(MODULES_DOC, "package")) {
  fonctions <- character(0)
  for (e in tryCatch(parse(text = r_outils, keep.source = FALSE), error = function(e) expression())) {
    if (is.call(e) && as.character(e[[1L]])[1L] %in% c("<-", "=") && is.name(e[[2L]]) &&
        is.call(e[[3L]]) && identical(e[[3L]][[1L]], as.name("function"))) {
      fonctions <- c(fonctions, as.character(e[[2L]]))
    }
  }
  fonctions <- fonctions[!startsWith(fonctions, ".")]
  exports <- character(0)
  for (e in parse(text = namespace, keep.source = FALSE)) {
    if (is.call(e) && identical(e[[1L]], as.name("export"))) exports <- c(exports, vapply(as.list(e)[-1L], as.character, ""))
  }
  unlist(lapply(portees, function(p) {
    if (p == "package") return(bloc_decomptes(p, paste0("exportees=", length(exports))))
    if (p == "outils") return(bloc_decomptes(p, c(paste0("fonctions=", length(fonctions)),
                                                  paste0("exportees=", sum(exports %in% fonctions)))))
    bloc_decomptes(p, "fonctions=0")
  }))
}

lancer_concordance <- function(contenu_doc, r_outils = "f_un <- function() 1\n.aux <- function() 2\n.K <- 3\nk_min <- 4\n",
                               namespace = "export(f_un)\n", strict = TRUE, decomptes = "auto", locale = NULL) {
  faux <- tempfile("racine-")
  on.exit(unlink(faux, recursive = TRUE), add = TRUE)
  dir.create(file.path(faux, "R"), recursive = TRUE)
  dir.create(file.path(faux, "docs", "latex"), recursive = TRUE)
  writeLines(r_outils, file.path(faux, "R", "outils.R"))
  writeLines(namespace, file.path(faux, "NAMESPACE"))
  if (!is.null(contenu_doc)) {
    if (identical(decomptes, "auto")) decomptes <- decomptes_auto(r_outils, namespace)
    writeLines(c(contenu_doc, decomptes), file.path(faux, "docs", "latex", "doc_outil_prov_vie.tex"))
  }
  sortie <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"),
    c(shQuote(file.path(racine, "tests", "concordance_doc_moteur.R")),
      if (strict) "--strict", paste0("--racine=", shQuote(faux))),
    stdout = TRUE, stderr = TRUE, env = if (!is.null(locale)) paste0("LC_ALL=", locale)))
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

# Décomptes du texte courant (issue #104, décision M356) : le document fictif a pour code
# d'outils f_un (une fonction, exportée) et .aux (à point, non recensée), aucune constante ;
# les autres modules n'ont pas de fichier (fonctions=0).
section("concordance : décomptes du texte courant")
doc_decomptes <- function(portee, grandeurs, texte, sauf = portee) {
  c(tableau("outils", "f\\_un"), decomptes_auto(
    "f_un <- function() 1\n.aux <- function() 2\n", "export(f_un)\n",
    setdiff(c(MODULES_DOC, "package"), sauf)), bloc_decomptes(portee, grandeurs, texte))
}
decompte <- function(portee, grandeurs, texte, sauf = portee, ...) {
  lancer_concordance(doc_decomptes(portee, grandeurs, texte, sauf), decomptes = NULL, ...)
}

r <- lancer_concordance(tableau("outils", "f\\_un"))
verifier("marqueurs concordants pour les seize portées : statut 0, une ligne [OK] par marqueur",
         r$statut == 0L && lengths(regmatches(r$sortie, gregexpr("[OK] décomptes (ligne", r$sortie, fixed = TRUE))) == 16L)
r <- decompte("outils", c("fonctions=1", "exportees=1"), "Ses fonctions sont exportées.")
verifier("marqueur et prose sans nombre en lettres : statut 0, ligne [OK] du marqueur",
         r$statut == 0L && grepl("[OK] décomptes (ligne", r$sortie, fixed = TRUE) &&
           grepl("outils : fonctions=1 exportees=1 concordant(s) avec le code, 0 nombre(s) en lettres lu(s)", r$sortie, fixed = TRUE))

# Marqueur faussé d'une unité.
r <- decompte("outils", "fonctions=2", "Texte sans décompte.")
verifier("marqueur faussé d'une unité : échec --strict, grandeur, marqueur et code cités", r$statut == 1L &&
           grepl("outils -- fonctions : marqueur 2, code 1", r$sortie, fixed = TRUE))
r <- decompte("outils", "exportees=0", "Texte sans décompte.")
verifier("exportees faussé : échec", r$statut == 1L && grepl("exportees : marqueur 0, code 1", r$sortie, fixed = TRUE))
r <- decompte("outils", "constantes=1", "Texte sans décompte.")
verifier("constantes faussé : échec", r$statut == 1L && grepl("constantes : marqueur 1, code 0", r$sortie, fixed = TRUE))
r <- decompte("outils", "fonctions=2", "Texte sans décompte.", strict = FALSE)
verifier("même écart sans --strict : [AVERT], statut 0", r$statut == 0L &&
           grepl("[AVERT] décomptes (ligne", r$sortie, fixed = TRUE))
r <- decompte("package", "exportees=2", "Texte sans décompte.")
verifier("package : exportees faussé : échec", r$statut == 1L &&
           grepl("package -- exportees : marqueur 2, code 1", r$sortie, fixed = TRUE))
r <- decompte("garanties", "fonctions=1", "Texte sans décompte.")
verifier("module sans fichier R : fonctions=1 faussé (code 0) : échec", r$statut == 1L &&
           grepl("garanties -- fonctions : marqueur 1, code 0", r$sortie, fixed = TRUE))

# Prose faussée d'une unité.
r <- decompte("outils", "fonctions=1", "Ses deux fonctions sont exportées.")
verifier("prose fausse (deux fonctions, marqueur 1) : échec, texte cité", r$statut == 1L &&
           grepl("texte « deux fonctions » = 2, marqueur fonctions=1", r$sortie, fixed = TRUE))
r <- decompte("outils", "exportees=1", "Les deux exportées sont listées.")
verifier("prose fausse sur exportées : échec", r$statut == 1L &&
           grepl("texte « deux exportées » = 2, marqueur exportees=1", r$sortie, fixed = TRUE))
r <- decompte("outils", "constantes=0", "Le module a Zéro constantes ; il a aussi une constante.")
verifier("« Zéro constantes » (majuscule, accent) lu et concordant, « une constante » non lu : statut 0, un nombre lu",
         r$statut == 0L && grepl("constantes=0 concordant(s) avec le code, 1 nombre(s) en lettres lu(s)", r$sortie, fixed = TRUE))
r <- decompte("outils", "constantes=1", "Le module a zéro constantes.")
verifier("« zéro constantes » avec marqueur à 1 : échec", r$statut == 1L &&
           grepl("= 0, marqueur constantes=1", r$sortie, fixed = TRUE))
r <- decompte("outils", "fonctions=1", "Ses dix-neuf fonctions.")
verifier("nombre composé de la table (dix-neuf) : lu, écart", r$statut == 1L &&
           grepl("texte « dix-neuf fonctions » = 19, marqueur fonctions=1", r$sortie, fixed = TRUE))
r <- decompte("outils", "fonctions=1", "Ses vingt-deux fonctions.")
verifier("nombre composé au-delà de vingt : non lu, statut 0", r$statut == 0L &&
           grepl("fonctions=1 concordant(s) avec le code, 0 nombre(s) en lettres lu(s)", r$sortie, fixed = TRUE))
r <- decompte("package", "exportees=1", "Le package exporte deux fonctions.")
verifier("package : « deux fonctions » se compare à exportees : écart", r$statut == 1L &&
           grepl("package -- texte « deux fonctions » = 2, marqueur exportees=1", r$sortie, fixed = TRUE))
r <- decompte("package", "exportees=1", "Le package exporte une fonction ; son unique fonction.")
verifier("package : « une fonction » non lu, statut 0, marqueur concordant", r$statut == 0L &&
           grepl("package : exportees=1 concordant(s) avec le code, 0 nombre(s) en lettres lu(s)", r$sortie, fixed = TRUE))
r <- decompte("outils", "fonctions=1", "Une configuration est une donnée, jamais une fonction.")
verifier("« une fonction » non lu (article) : statut 0, aucun nombre lu", r$statut == 0L &&
           grepl("fonctions=1 concordant(s) avec le code, 0 nombre(s) en lettres lu(s)", r$sortie, fixed = TRUE))
r <- decompte("outils", "fonctions=1", "Il y a un fonction.\nUn constante.")
verifier("« un fonction » non lu non plus : statut 0, marqueur concordant", r$statut == 0L &&
           grepl("outils : fonctions=1 concordant(s) avec le code, 0 nombre(s) en lettres lu(s)", r$sortie, fixed = TRUE))
r <- decompte("outils", "fonctions=1", "Ses deux\nfonctions sont exportées.")
verifier("nombre en lettres en fin de ligne du source, grandeur au début de la suivante : lu, écart", r$statut == 1L &&
           grepl("texte « deux fonctions » = 2, marqueur fonctions=1", r$sortie, fixed = TRUE))

# Grandeur non déclarée : ignorée.
r <- decompte("outils", "fonctions=1", "Les deux constantes et les trois exportées ne sont pas déclarées.")
verifier("nombre devant une grandeur non déclarée : ignoré, statut 0, aucun nombre lu", r$statut == 0L &&
           grepl("fonctions=1 concordant(s) avec le code, 0 nombre(s) en lettres lu(s)", r$sortie, fixed = TRUE))
r <- decompte("outils", "fonctions=1", "Les sept fonctionnalités et les huit constantes d'ordre.")
verifier("suite de lettres qui prolonge « fonction » : non lue ; grandeur non déclarée : ignorée ; statut 0", r$statut == 0L &&
           grepl("0 nombre(s) en lettres lu(s)", r$sortie, fixed = TRUE))
r <- decompte("outils", "fonctions=1", "Les quelques fonctions ; les fonctionnalités ; des constantes.")
verifier("mot hors de la table des nombres : ignoré, statut 0, marqueur concordant", r$statut == 0L &&
           grepl("outils : fonctions=1 concordant(s) avec le code, 0 nombre(s) en lettres lu(s)", r$sortie, fixed = TRUE))

# Paragraphe : jusqu'à la première ligne blanche, lignes de commentaire exclues.
r <- lancer_concordance(c(tableau("outils", "f\\_un"), decomptes_auto(
  "f_un <- function() 1\n", "export(f_un)\n", setdiff(c(MODULES_DOC, "package"), "outils")),
  "", "% concordance-decomptes : outils fonctions=1", "Une fonction.", "", "Trois fonctions, hors du paragraphe."),
  decomptes = NULL)
verifier("le paragraphe s'arrête à la première ligne blanche : le nombre qui suit n'est pas lu", r$statut == 0L &&
           grepl("outils : fonctions=1 concordant(s) avec le code, 0 nombre(s) en lettres lu(s)", r$sortie, fixed = TRUE))
r <- lancer_concordance(c(tableau("outils", "f\\_un"), decomptes_auto(
  "f_un <- function() 1\n", "export(f_un)\n", setdiff(c(MODULES_DOC, "package"), "outils")),
  "", "% concordance-decomptes : outils fonctions=1", "% trois fonctions en commentaire", "Une fonction", "  % cinq fonctions",
  "est exportée."), decomptes = NULL)
verifier("lignes de commentaire du paragraphe exclues, lignes jointes : statut 0, aucun nombre lu", r$statut == 0L &&
           grepl("outils : fonctions=1 concordant(s) avec le code, 0 nombre(s) en lettres lu(s)", r$sortie, fixed = TRUE))
r <- lancer_concordance(c(tableau("outils", "f\\_un"), decomptes_auto(
  "f_un <- function() 1\n", "export(f_un)\n", setdiff(c(MODULES_DOC, "package"), "outils")),
  "", "% concordance-decomptes : outils fonctions=1", "Ses deux fonctions", "", "x"), decomptes = NULL)
verifier("nombre dans le paragraphe, faux : échec", r$statut == 1L)

# Marqueur mal formé, portée ou grandeur inconnue, répétée.
r <- decompte("outils", "fonctions=un", "Texte sans décompte.", sauf = character(0))
verifier("marqueur mal formé (valeur non numérique) : échec, ligne citée", r$statut == 1L &&
           grepl("marqueur mal formé", r$sortie, fixed = TRUE))
r <- decompte("inconnu", "fonctions=1", "Texte sans décompte.", sauf = character(0))
verifier("portée inconnue : échec, portée citée", r$statut == 1L &&
           grepl("portée inconnue : inconnu", r$sortie, fixed = TRUE))
r <- decompte("outils", "fonctionnalites=1", "Texte sans décompte.", sauf = character(0))
verifier("grandeur inconnue : échec", r$statut == 1L && grepl("grandeur inconnue : fonctionnalites", r$sortie, fixed = TRUE))
r <- decompte("package", "fonctions=1", "Texte sans décompte.", sauf = character(0))
verifier("package fonctions=... : refusé", r$statut == 1L &&
           grepl("la portée package n'admet que exportees", r$sortie, fixed = TRUE))
r <- decompte("package", c("exportees=1", "constantes=0"), "Texte sans décompte.", sauf = character(0))
verifier("package exportees=... constantes=... : refusé", r$statut == 1L &&
           grepl("la portée package n'admet que exportees", r$sortie, fixed = TRUE))
r <- decompte("outils", c("fonctions=1", "fonctions=1"), "Texte sans décompte.", sauf = character(0))
verifier("grandeur déclarée deux fois : échec, grandeur citée", r$statut == 1L &&
           grepl("grandeur déclarée deux fois : fonctions", r$sortie, fixed = TRUE))
r <- decompte("outils", "fonctions=1", "Texte sans décompte.", sauf = character(0))
verifier("marqueur supplémentaire concordant (--strict) : statut 0, une ligne [OK] par marqueur (seize + un)", r$statut == 0L &&
           lengths(regmatches(r$sortie, gregexpr("[OK] décomptes (ligne", r$sortie, fixed = TRUE))) == 17L)

# Complétude : une portée sans marqueur est un écart.
r <- lancer_concordance(c(tableau("outils", "f\\_un"), decomptes_auto(
  "f_un <- function() 1\n", "export(f_un)\n", setdiff(c(MODULES_DOC, "package"), "dictionnaire"))), decomptes = NULL)
verifier("module sans marqueur : échec --strict, portée citée", r$statut == 1L &&
           grepl("portée dictionnaire -- aucun marqueur", r$sortie, fixed = TRUE) &&
           !grepl("portée outils -- aucun marqueur", r$sortie, fixed = TRUE))
r <- lancer_concordance(c(tableau("outils", "f\\_un"), decomptes_auto(
  "f_un <- function() 1\n", "export(f_un)\n", setdiff(c(MODULES_DOC, "package"), "package"))), decomptes = NULL)
verifier("portée package sans marqueur : échec", r$statut == 1L && grepl("portée package -- aucun marqueur", r$sortie, fixed = TRUE))
r <- lancer_concordance(tableau("outils", "f\\_un"), decomptes = NULL)
verifier("document sans aucun marqueur : seize portées sans marqueur", r$statut == 1L &&
           lengths(regmatches(r$sortie, gregexpr("aucun marqueur", r$sortie, fixed = TRUE))) == 16L)
r <- lancer_concordance(c(tableau("outils", "f\\_un"), decomptes_auto(
  "f_un <- function() 1\n", "export(f_un)\n", setdiff(c(MODULES_DOC, "package"), "dictionnaire"))), decomptes = NULL, strict = FALSE)
verifier("même écart sans --strict : [AVERT], statut 0", r$statut == 0L && grepl("[AVERT] portée dictionnaire", r$sortie, fixed = TRUE))

# Marqueur sans paragraphe.
r <- lancer_concordance(c(tableau("outils", "f\\_un"), decomptes_auto(
  "f_un <- function() 1\n", "export(f_un)\n", setdiff(c(MODULES_DOC, "package"), "outils")),
  "", "% concordance-decomptes : outils fonctions=1", "", "Texte après la ligne blanche : deux fonctions."), decomptes = NULL)
verifier("marqueur suivi d'une ligne blanche : sans paragraphe, échec", r$statut == 1L &&
           grepl("marqueur sans paragraphe qui le suive", r$sortie, fixed = TRUE))
r <- lancer_concordance(c(tableau("outils", "f\\_un"), decomptes_auto(
  "f_un <- function() 1\n", "export(f_un)\n", setdiff(c(MODULES_DOC, "package"), "outils")),
  "", "% concordance-decomptes : outils fonctions=1"), decomptes = NULL)
verifier("marqueur en fin de document : sans paragraphe, échec", r$statut == 1L &&
           grepl("marqueur sans paragraphe qui le suive", r$sortie, fixed = TRUE))
r <- lancer_concordance(c(tableau("outils", "f\\_un"), decomptes_auto(
  "f_un <- function() 1\n", "export(f_un)\n", setdiff(c(MODULES_DOC, "package"), "outils")),
  "", "% concordance-decomptes : outils fonctions=1", "% seulement un commentaire", ""), decomptes = NULL)
verifier("marqueur suivi de commentaires seulement : sans paragraphe, échec", r$statut == 1L &&
           grepl("marqueur sans paragraphe qui le suive", r$sortie, fixed = TRUE))

# Reprise de l'audit léger de #104 (C1 à C5).
# C1 : valeur de plus de six chiffres = marqueur mal formé (pas d'avertissement converti en arrêt).
r <- decompte("outils", "exportees=99999999999", "Texte sans décompte.", sauf = character(0))
verifier("valeur déclarée de plus de six chiffres : marqueur mal formé, le script va jusqu'au bilan", r$statut == 1L &&
           grepl("marqueur mal formé", r$sortie, fixed = TRUE) && grepl("Bilan :", r$sortie, fixed = TRUE))
r <- decompte("outils", "fonctions=000001", "Texte sans décompte.")
verifier("valeur de six chiffres (000001) : lue, concordante", r$statut == 0L)
# C2 : bilan identique en locale C et en UTF-8 ; seule la première lettre peut être majuscule.
sans_nombre <- "Le module a ZÉRO constantes, DEUX fonctions et ZEROS constantes."
r_c <- decompte("outils", c("fonctions=1", "constantes=1"), sans_nombre, locale = "C")
r_u <- decompte("outils", c("fonctions=1", "constantes=1"), sans_nombre, locale = "C.UTF-8")
verifier("nombre tout en capitales (ZÉRO, DEUX) : non lu, identique en locale C et C.UTF-8", r_c$statut == 1L &&
           identical(r_c$sortie, r_u$sortie) && grepl("constantes : marqueur 1, code 0", r_c$sortie, fixed = TRUE) &&
           !grepl("texte «", r_c$sortie, fixed = TRUE))
vrai <- "Le module a Zéro constantes et Deux fonctions d'âge."
r_c <- decompte("outils", c("fonctions=2", "constantes=0"), vrai, locale = "C")
r_u <- decompte("outils", c("fonctions=2", "constantes=0"), vrai, locale = "C.UTF-8")
verifier("« Zéro constantes » lu en majuscule initiale, identique en C et C.UTF-8, « Deux fonctions » lu et faux (marqueur 2, code 1)",
         identical(r_c$sortie, r_u$sortie) && grepl("fonctions : marqueur 2, code 1", r_c$sortie, fixed = TRUE) &&
           !grepl("texte «", r_c$sortie, fixed = TRUE))
r_c <- decompte("outils", "constantes=1", "Le module a zéro constantes ; exportées.", locale = "C")
r_u <- decompte("outils", "constantes=1", "Le module a zéro constantes ; exportées.", locale = "C.UTF-8")
verifier("écart sur « zéro constantes » affiché sans « <U+ » en locale C, identique en C.UTF-8", r_c$statut == 1L &&
           identical(r_c$sortie, r_u$sortie) && grepl("texte « zéro constantes » = 0", r_c$sortie, fixed = TRUE))
# C3 : ~ est une espace insécable ; une commande autour du nombre reste une limite non lue.
r <- decompte("outils", "fonctions=1", "Ses dix-huit~fonctions.")
verifier("dix-huit~fonctions : lu, écart", r$statut == 1L &&
           grepl("texte « dix-huit~fonctions » = 18, marqueur fonctions=1", r$sortie, fixed = TRUE))
r <- decompte("outils", "fonctions=1", "Ses \\emph{dix-huit} fonctions.")
verifier("\\emph{dix-huit} fonctions : limite connue, non lu, statut 0", r$statut == 0L &&
           grepl("fonctions=1 concordant(s) avec le code, 0 nombre(s) en lettres lu(s)", r$sortie, fixed = TRUE))
# C4 : commentaires de fin de ligne ; marqueur à plusieurs « % ».
r <- decompte("outils", "fonctions=1", "Une fonction % trois fonctions en commentaire\nest exportée.")
verifier("commentaire de fin de ligne : non lu, statut 0, aucun nombre lu", r$statut == 0L &&
           grepl("fonctions=1 concordant(s) avec le code, 0 nombre(s) en lettres lu(s)", r$sortie, fixed = TRUE))
r <- decompte("outils", "fonctions=1", "Ses dix-huit%\nfonctions sont exportées.")
verifier("dix-huit% puis fonctions à la ligne : pas d'espace en LaTeX, non lu, statut 0", r$statut == 0L &&
           grepl("fonctions=1 concordant(s) avec le code, 0 nombre(s) en lettres lu(s)", r$sortie, fixed = TRUE))
r <- decompte("outils", "fonctions=1", "Ses dix-huit%\n   fonctions sont exportées.")
verifier("dix-huit% puis blancs puis fonctions : blancs de début de ligne ignorés, non lu", r$statut == 0L &&
           grepl("0 nombre(s) en lettres lu(s)", r$sortie, fixed = TRUE))
r <- decompte("outils", "fonctions=1", "Ses dix-huit\nfonctions sont 100\\% exportées.")
verifier("fin de ligne sans commentaire : espace, lu ; \\% n'est pas un commentaire", r$statut == 1L &&
           grepl("texte « dix-huit fonctions » = 18, marqueur fonctions=1", r$sortie, fixed = TRUE))
r2 <- lancer_concordance(c(tableau("outils", "f\\_un"), decomptes_auto(
  "f_un <- function() 1\n", "export(f_un)\n", setdiff(c(MODULES_DOC, "package"), "outils")),
  "", "%% concordance-decomptes : outils fonctions=1", "Texte sans décompte."), decomptes = NULL)
verifier("marqueur %% concordance-decomptes : mal formé, échec", r2$statut == 1L && grepl("marqueur mal formé", r2$sortie, fixed = TRUE))
# C5 : un nombre précédé d'un mot de nombre est un composé, non lu.
r <- decompte("outils", "fonctions=1", "Ses cent deux fonctions ; soixante et onze fonctions ; trente deux fonctions.")
verifier("cent deux, soixante et onze, trente deux fonctions : composés non lus, statut 0", r$statut == 0L &&
           grepl("fonctions=1 concordant(s) avec le code, 0 nombre(s) en lettres lu(s)", r$sortie, fixed = TRUE))
r <- decompte("outils", "fonctions=1", "Sur les six, deux fonctions sont exportées.")
verifier("nombre précédé d'un nombre mais séparé par une virgule : lu, écart", r$statut == 1L &&
           grepl("texte « deux fonctions » = 2, marqueur fonctions=1", r$sortie, fixed = TRUE))
r <- decompte("outils", "fonctions=1", "Deux de ses six fonctions.")
verifier("« Deux de ses six fonctions » : six précédé de « ses », lu, écart", r$statut == 1L &&
           grepl("texte « six fonctions » = 6, marqueur fonctions=1", r$sortie, fixed = TRUE))
