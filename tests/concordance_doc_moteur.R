# Concordance documentation <-> code (E3.3 ; ADR 0010, points 25 et 26). À lancer depuis
# la racine du dépôt : Rscript tests/concordance_doc_moteur.R --strict
# Lit les tableaux de fonctions par module de docs/latex/doc_outil_prov_vie.tex et les
# compare aux fonctions de premier niveau de R/<module>.R. Sans --strict, les écarts sont
# des [AVERT] et la sortie vaut 0 ; avec --strict (CI), tout écart et l'absence du
# document sont des échecs. Option --racine=<dossier> : autre racine (tests du script).
#
# Convention de lecture du document (à reprendre dans docs/latex/CONVENTIONS.md) :
#   - un tableau de fonctions est précédé d'une ligne de commentaire LaTeX
#       % concordance-fonctions : <module>
#     où <module> est un des quinze noms de l'ADR 0010, point 1 ;
#   - chaque ligne du tableau cite la fonction dans sa première cellule par \code{nom} ou
#     \code{nom()} (les \_ sont acceptés) ; le tableau finit à \end{tabular},
#     \end{longtable} ou \end{tabularx} ;
#   - les fonctions recensées sont celles de premier niveau de R/<module>.R dont le nom ne
#     commence pas par un point ; chaque export() du NAMESPACE doit figurer dans un tableau.
#
# Valeurs des constantes (issue #37). Un tableau de constantes est un tableau dont la
# première cellule d'en-tête est « Constante » ; son module est celui du dernier marqueur
# `% concordance-fonctions` rencontré plus haut dans le document. Chaque ligne cite la
# constante dans sa première cellule par \code{NOM} ; la valeur se lit dans la deuxième
# cellule et, pour un tableau à trois colonnes, dans la troisième. Quatre formes littérales
# sont comparées à la constante de R/<module>.R, les autres cellules n'étant pas lues :
#   - chaîne : deuxième cellule seulement, qui commence par \code{"texte"} ;
#   - entier : deuxième cellule seulement, qui commence par « entier \code{N} » (la
#     constante doit être de type integer) ;
#   - décompte : « <nombre> motifs | chaînes | lignes | CSV », hors des \code{}, le nombre
#     étant en lettres jusqu'à vingt ou en chiffres ; comparé à la longueur de la constante
#     (au nombre de lignes d'un data.frame) ; un nombre composé en lettres (vingt-deux) est
#     un écart, faute d'être lu ;
#   - liste de valeurs : suite de \code{valeur} séparés par « , », sans guillemets, au début
#     de la deuxième cellule ou juste après « ~: » (deuxième et troisième cellules) ;
#     comparée à la constante (vecteur atomique), dans l'ordre.
# Règle des \code{"..."} : tout \code{"..."} d'une cellule de valeur qu'aucune forme n'a
# consommé est un écart, où qu'il se trouve (« version \code{"1.3"} », « \code{"1.5"}
# (anciennement \code{"1.3"}) », une chaîne en troisième cellule, une liste écrite avec
# guillemets) ; seule la forme « chaîne » en consomme un. Une cellule sans \code{"..."} dont
# aucune forme n'est reconnue reste non lue (la constante est alors nommée « sans valeur
# littérale lue »).
# Rangées : une rangée peut tenir sur plusieurs lignes du source ; elle est lue du « & » de
# sa première ligne au « \\ » final, qui peut être suivi de « [...] » et de filets (\hline,
# \midrule, \toprule, \bottomrule). Sont des écarts une rangée sans « \\ » final avant la fin
# du tableau, et une rangée qui a plus de cellules que l'en-tête « Constante » (rangées
# fusionnées par un « \\ » manquant).
# Sont aussi des écarts : une constante citée mais absente du module ou non évaluable, une
# constante citée deux fois, un tableau avant tout marqueur de module. La valeur d'une
# constante s'obtient sans charger le package, en évaluant les affectations de premier
# niveau de R/<module>.R qui sont des fonctions ou dont le nom est en majuscules (modules
# pris dans l'ordre de MODULES).
#
# Complétude des constantes (issue #41, décision M408). Toute constante en majuscules de
# premier niveau de R/<module>.R (nom ^[A-Z][A-Z0-9_]*$, affectation <- ou = dont le membre
# de droite n'est pas une fonction ; même prédicat que celui de constantes_du_code()) doit
# figurer dans le tableau de
# constantes de son module : une constante absente est un écart nommé, et un module qui a
# des constantes mais aucun tableau de constantes en est un aussi (même traitement que
# « fonctions dans R/ mais aucun tableau »). Les constantes dont le nom commence par un
# point (.NOM, internes) ne sont pas recensées, comme les fonctions à point : elles ne sont
# pas exigées au tableau ; citées dans un tableau, elles sont un écart.
#
# Décomptes du texte courant (issue #104, décision M356 ; docs/latex/CONVENTIONS.md, § 3,
# « Décomptes du texte courant »). Une ligne de commentaire LaTeX
#     % concordance-decomptes : <portée> <grandeur>=<N> [<grandeur>=<N> ...]
# précède le paragraphe qui porte le décompte ; la portée est l'un des modules de MODULES ou
# `package` ; les grandeurs, chacune une fois au plus, sont :
#   - fonctions  : fonctions de premier niveau de R/<module>.R, hors noms à point (0 si le
#                  fichier est absent) ;
#   - exportees  : noms des export() du NAMESPACE qui sont de ces fonctions ; pour `package`,
#                  tous les export() du NAMESPACE (seule grandeur admise pour `package`) ;
#   - constantes : constantes en majuscules de premier niveau de R/<module>.R (même
#                  recensement que la complétude des tableaux de constantes).
# Chaque valeur déclarée est comparée au code. Le paragraphe qui suit le marqueur (lignes
# jusqu'à la première ligne blanche, lignes de commentaire exclues, jointes par une espace)
# est lu : tout nombre en toutes lettres de « deux » à « vingt », ou « zéro », placé devant
# « fonction(s) », « exportée(s) » ou « constante(s) » est comparé à la grandeur déclarée
# correspondante (`package` : « fonction(s) » se compare à exportees) ; « un » et « une »
# ne sont pas lus, ni un nombre devant une grandeur que le marqueur ne déclare pas. Sont des
# écarts : marqueur mal formé, portée ou grandeur inconnue, grandeur déclarée deux fois,
# `package` avec une autre grandeur qu'exportees, valeur déclarée différente du code, nombre
# en lettres différent de la valeur déclarée, marqueur sans paragraphe, portée (les quinze
# modules et `package`) sans aucun marqueur. Une ligne [OK] par marqueur concordant.
# Lecture du paragraphe : les commentaires de fin de ligne (« % ... » non précédé de « \ »)
# en sont retirés, et la ligne qui porte un « % » se joint à la suivante sans espace, comme
# en LaTeX (« dix-huit% » puis « fonctions » ne fait pas un décompte) ; le séparateur entre
# le nombre et la grandeur est une espace, une fin de ligne ou « ~ » (espace insécable) ;
# seule la première lettre du nombre peut être une majuscule (« ZÉRO » n'est pas lu, ce qui
# rend le bilan identique en locale C et en UTF-8) ; un nombre précédé d'un mot de nombre
# (« cent deux fonctions », « soixante et onze fonctions ») n'est pas lu. Limite connue : un
# nombre dans une commande (« \emph{dix-huit} fonctions ») n'est pas lu. Un marqueur dont la
# valeur dépasse six chiffres, ou écrit « %% concordance-decomptes », est mal formé.

options(warn = 2)
args <- commandArgs(TRUE)
strict <- "--strict" %in% args
fichier <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
dossier_tests <- dirname(normalizePath(fichier, mustWork = TRUE))
source(file.path(dossier_tests, "harnais.R"))
option_racine <- sub("^--racine=", "", grep("^--racine=", args, value = TRUE))
racine <- normalizePath(if (length(option_racine) == 1L) option_racine else dirname(dossier_tests),
                        mustWork = TRUE)

MODULES <- c("outils", "dictionnaire", "lecture", "donnees", "tables", "garanties",
             "engagement", "triangle", "risque_en_cours", "regles_comptables", "projection",
             "plan", "rapport", "simulation", "calculer_provisions")

# Un écart : échec en mode strict, avertissement sinon.
ecart <- function(nom, detail) {
  if (strict) {
    verifier(paste(nom, "--", detail), FALSE)
  } else {
    cat(sprintf("[AVERT] %s -- %s\n", nom, detail))
  }
}
accord <- function(nom) verifier(nom, TRUE)

# Noms des fonctions de premier niveau d'un fichier R, hors noms commençant par un point.
fonctions_du_fichier <- function(chemin) {
  noms <- character(0)
  for (expr in parse(chemin, keep.source = FALSE)) {
    if (is.call(expr) && as.character(expr[[1L]])[1L] %in% c("<-", "=") &&
        is.name(expr[[2L]]) && is.call(expr[[3L]]) && identical(expr[[3L]][[1L]], as.name("function"))) {
      noms <- c(noms, as.character(expr[[2L]]))
    }
  }
  sort(noms[!startsWith(noms, ".")], method = "radix")
}

# Tableaux du document : liste nommée par module des fonctions citées.
lire_tableaux <- function(chemin) {
  lignes <- readLines(chemin, encoding = "UTF-8", warn = FALSE)
  tableaux <- list()
  anomalies <- character(0)
  courant <- NULL
  for (l in lignes) {
    marque <- regmatches(l, regexec("^\\s*%\\s*concordance-fonctions\\s*:\\s*(\\S+)\\s*$", l))[[1L]]
    if (length(marque) == 2L) {
      courant <- marque[2L]
      if (!(courant %in% MODULES)) {
        anomalies <- c(anomalies, paste0("module inconnu dans le document : ", courant))
      } else if (courant %in% names(tableaux)) {
        anomalies <- c(anomalies, paste0("deux tableaux pour le module ", courant))
      } else {
        tableaux[[courant]] <- character(0)
      }
    } else if (!is.null(courant)) {
      if (grepl("\\\\end\\{(tabular|longtable|tabularx)\\}", l)) {
        courant <- NULL
      } else if (courant %in% names(tableaux)) {
        premiere <- strsplit(paste0(l, "&"), "(?<!\\\\)&", perl = TRUE)[[1L]][1L]
        cite <- regmatches(premiere, gregexpr("\\\\code\\{[^}]*\\}", premiere))[[1L]]
        noms <- sub("\\(\\)$", "", gsub("\\\\_", "_", sub("^\\\\code\\{(.*)\\}$", "\\1", cite)))
        tableaux[[courant]] <- c(tableaux[[courant]], noms)
      }
    }
  }
  list(tableaux = tableaux, anomalies = anomalies)
}

exports_du_namespace <- function(chemin) {
  if (!file.exists(chemin)) return(character(0))
  noms <- character(0)
  for (expr in parse(chemin, keep.source = FALSE)) {
    if (is.call(expr) && identical(expr[[1L]], as.name("export"))) {
      noms <- c(noms, vapply(as.list(expr)[-1L], as.character, ""))
    }
  }
  noms
}

# --- Valeurs des constantes (issue #37) ---------------------------------------------------

NOMBRES <- c(zero = 0L, un = 1L, une = 1L, deux = 2L, trois = 3L, quatre = 4L, cinq = 5L,
             six = 6L, sept = 7L, huit = 8L, neuf = 9L, dix = 10L, onze = 11L, douze = 12L,
             treize = 13L, quatorze = 14L, quinze = 15L, seize = 16L, "dix-sept" = 17L,
             "dix-huit" = 18L, "dix-neuf" = 19L, vingt = 20L)
MOTS_NOMBRES <- c(names(NOMBRES), "trente", "quarante", "cinquante", "soixante", "cent",
                  "vingts", "cents", "et")
MOTIF_DECOMPTE <- paste0("(?<![[:alpha:]-])([[:alpha:]]+(?:-[[:alpha:]]+)*|[0-9]+) ",
                         "(motifs|cha[^ ]{1,2}nes|lignes|CSV)(?![[:alpha:]])")
MOTIF_SUITE_CODE <- "^\\\\code\\{[^{}\"]*\\}(?:, \\\\code\\{[^{}\"]*\\})*"

# Prédicat partagé par constantes_du_code() et constantes_majuscules_du_fichier() : une
# expression de premier niveau est une affectation « NOM <- valeur » ou « NOM = valeur » à un
# nom (« 3L -> NOM » est déjà normalisé en « NOM <- 3L » par le parseur ; « NOM <<- v » et
# « NOM := v » n'en sont pas). Rend list(nom, droite), ou NULL.
affectation_de_premier_niveau <- function(expr) {
  if (is.call(expr) && as.character(expr[[1L]])[1L] %in% c("<-", "=") && is.name(expr[[2L]])) {
    list(nom = as.character(expr[[2L]]), droite = expr[[3L]])
  }
}
est_fonction <- function(x) is.call(x) && identical(x[[1L]], as.name("function"))
NOM_CONSTANTE <- "^[A-Z][A-Z0-9_]*$"

# Affectations de premier niveau évaluables : fonctions (toutes) et constantes (nom en
# majuscules), évaluées sans le package, modules dans l'ordre de MODULES. Rend, par nom de
# constante, list(module, valeur, erreur).
constantes_du_code <- function(racine) {
  env <- new.env(parent = baseenv())
  constantes <- list()
  for (module in MODULES) {
    chemin <- file.path(racine, "R", paste0(module, ".R"))
    if (!file.exists(chemin)) next
    for (expr in parse(chemin, keep.source = FALSE)) {
      aff <- affectation_de_premier_niveau(expr)
      if (is.null(aff)) next
      nom <- aff$nom
      if (est_fonction(aff$droite)) {
        assign(nom, eval(aff$droite, env), envir = env)
      } else if (grepl(NOM_CONSTANTE, nom)) {
        r <- tryCatch(list(valeur = eval(aff$droite, env), erreur = NA_character_),
                      error = function(e) list(valeur = NULL, erreur = conditionMessage(e)))
        if (is.na(r$erreur)) assign(nom, r$valeur, envir = env)
        constantes[[nom]] <- list(module = module, valeur = r$valeur, erreur = r$erreur)
      }
    }
  }
  constantes
}

# Constantes en majuscules de premier niveau d'un fichier R (issue #41) : les affectations
# que constantes_du_code() évalue comme constantes, par le même prédicat (ensemble identique
# par construction). Les noms à point (.NOM) en sont exclus.
constantes_majuscules_du_fichier <- function(chemin) {
  noms <- character(0)
  for (expr in parse(chemin, keep.source = FALSE)) {
    aff <- affectation_de_premier_niveau(expr)
    if (!is.null(aff) && !est_fonction(aff$droite) && grepl(NOM_CONSTANTE, aff$nom)) noms <- c(noms, aff$nom)
  }
  unique(noms)
}

# Fin de rangée : « \\ », suivi au plus d'un « [...] » puis de filets (\hline, \midrule...).
FIN_RANGEE <- "\\\\\\\\(\\[[^]]*\\])?(\\s*\\\\(hline|midrule|toprule|bottomrule))*\\s*$"
cellules_ligne <- function(l) {
  l <- sub(paste0("\\s*", FIN_RANGEE), "", l)
  trimws(strsplit(paste0(l, "&"), "(?<!\\\\)&", perl = TRUE)[[1L]])
}
a_cellules <- function(l) grepl("(?<!\\\\)&", l, perl = TRUE)
sans_echappement <- function(x) gsub("-{}-", "--", gsub("\\_", "_", x, fixed = TRUE), fixed = TRUE)

# Tableaux de constantes du document : lignes (nom, module, cellules 2 et 3, ligne du
# source) et anomalies de lecture.
lire_constantes <- function(chemin) {
  # Octets du source sans marque d'encodage, comme les chaînes que rend parse() : la
  # comparaison à la constante du code et l'affichage valent quelle que soit la locale.
  lignes <- readLines(chemin, warn = FALSE)
  rangees <- list()
  anomalies <- character(0)
  module <- NA_character_
  dedans <- FALSE
  # Une rangée peut tenir sur plusieurs lignes du source : on réunit les lignes depuis
  # celle qui porte la première « & » jusqu'à celle qui finit par « \\ ».
  tampon <- ""
  debut <- NA_integer_
  ncol <- NA_integer_  # nombre de cellules de l'en-tête « Constante » du tableau courant
  sans_fin <- function(texte) {
    if (nzchar(tampon)) {
      anomalies <<- c(anomalies, sprintf("ligne %d : rangée sans \\\\ final %s", debut, texte))
    }
    tampon <<- ""
  }
  for (i in seq_along(lignes)) {
    l <- lignes[i]
    marque <- regmatches(l, regexec("^\\s*%\\s*concordance-fonctions\\s*:\\s*(\\S+)\\s*$", l))[[1L]]
    if (length(marque) == 2L) {
      sans_fin("avant un nouveau marqueur de module")
      module <- marque[2L]
      dedans <- FALSE
    } else if (dedans) {
      if (grepl("\\\\end\\{(tabular|longtable|tabularx)\\}", l)) {
        sans_fin("avant la fin du tableau")
        dedans <- FALSE
      } else if (!grepl("^\\s*%", l) && (nzchar(tampon) || a_cellules(l))) {
        if (!nzchar(tampon)) debut <- i
        tampon <- if (nzchar(tampon)) paste(tampon, l) else l
        if (grepl(FIN_RANGEE, l)) {
          cel <- cellules_ligne(tampon)
          nom <- regmatches(cel[1L], regexec("^\\\\code\\{([^{}]*)\\}$", cel[1L]))[[1L]]
          if (length(cel) > ncol) {
            anomalies <- c(anomalies, sprintf(
              "ligne %d : rangée fusionnée ou \\\\ manquant (%d cellules, l'en-tête en a %d)", debut, length(cel), ncol))
          } else if (length(nom) != 2L) {
            anomalies <- c(anomalies, sprintf("ligne %d : première cellule sans \\code{NOM} seul", debut))
          } else {
            rangees[[length(rangees) + 1L]] <- list(nom = sans_echappement(nom[2L]), module = module,
                                                    c2 = cel[2L], c3 = if (length(cel) >= 3L) cel[3L] else "",
                                                    ligne = debut)
          }
          tampon <- ""
        }
      }
    } else if (a_cellules(l) && grepl("\\\\textbf\\{Constante\\}", cellules_ligne(l)[1L])) {
      dedans <- TRUE
      ncol <- length(cellules_ligne(l))
      if (is.na(module)) {
        anomalies <- c(anomalies, sprintf("ligne %d : tableau de constantes avant tout marqueur de module", i))
      }
    }
  }
  sans_fin("avant la fin du document")
  list(rangees = rangees, anomalies = anomalies)
}

abrege <- function(x) {
  if (is.data.frame(x)) return(sprintf("data.frame de %d ligne(s)", nrow(x)))
  t <- paste(deparse(x, width.cutoff = 500L), collapse = " ")
  if (nchar(t) > 70L) paste0(substr(t, 1L, 67L), "...") else t
}

# Une ligne de tableau de constantes face à la valeur `v` : rend `verifs` (liste de
# list(forme, doc, ok)), `lecture` (formes reconnues mais non lues) et `inconnues` (un
# message par cellule lue, deuxième ou troisième, où des \code{"..."} restent non consommés).
comparer_ligne <- function(v, c2, c3) {
  verifs <- list()
  ajouter <- function(forme, doc, ok) verifs[[length(verifs) + 1L]] <<- list(forme = forme, doc = doc, ok = isTRUE(ok))
  lecture <- character(0)
  chaine_lue <- 0L  # nombre de \code{"..."} que la forme « chaîne » consomme (au plus un, en c2)
  m <- regmatches(c2, regexec("^\\\\code\\{\"([^\"]*)\"\\}", c2))[[1L]]
  if (length(m) == 2L) {
    doc <- sans_echappement(m[2L])
    ajouter("chaîne", abrege(doc), is.character(v) && length(v) == 1L && identical(v, doc))
    chaine_lue <- 1L
  }
  m <- regmatches(c2, regexec("^[Ee]ntier \\\\code\\{([0-9]+)\\}", c2))[[1L]]
  if (length(m) == 2L) {
    ajouter("entier", m[2L], is.integer(v) && length(v) == 1L && identical(v, as.integer(m[2L])))
  }
  cellules <- c(c2, c3)
  for (k in 1:2) {
    texte <- gsub("\\\\code\\{[^{}]*\\}", "X", cellules[k])
    for (trouve in regmatches(texte, gregexpr(MOTIF_DECOMPTE, texte, perl = TRUE))[[1L]]) {
      mot <- tolower(sub(" [^ ]+$", "", trouve))
      n <- if (grepl("^[0-9]+$", mot)) as.integer(mot) else unname(NOMBRES[mot])
      if (is.na(n)) {
        if (grepl("-", mot, fixed = TRUE) && all(strsplit(mot, "-", fixed = TRUE)[[1L]] %in% MOTS_NOMBRES)) {
          lecture <- c(lecture, sprintf("décompte en lettres non lu : %s", trouve))
        }
        next
      }
      ajouter("décompte", trouve, (if (is.data.frame(v)) nrow(v) else length(v)) == n)
    }
  }
  # Listes de valeurs : début de la deuxième cellule, et segment qui suit chaque « ~: ».
  decouper <- function(x) trimws(strsplit(paste0(x, "~:"), "~:", fixed = TRUE)[[1L]])
  for (k in 1:2) {
    segments <- if (k == 1L) decouper(c2) else decouper(c3)[-1L]
    for (seg in segments) {
      suite <- regmatches(seg, regexpr(MOTIF_SUITE_CODE, seg, perl = TRUE))
      if (length(suite) == 1L) {
        jetons <- regmatches(suite, gregexpr("\\\\code\\{[^{}\"]*\\}", suite))[[1L]]
        valeurs <- sans_echappement(sub("^\\\\code\\{(.*)\\}$", "\\1", jetons))
        ajouter("liste", paste(valeurs, collapse = ", "),
                is.atomic(v) && is.null(dim(v)) && identical(as.character(v), valeurs))
      }
    }
  }
  # Tout \code{"..."} qu'aucune forme n'a consommé est un écart : seule la forme « chaîne »
  # en consomme un (les valeurs d'une liste s'écrivent sans guillemets).
  inconnues <- character(0)
  for (k in 1:2) {
    restants <- lengths(regmatches(cellules[k], gregexpr("\\code{\"", cellules[k], fixed = TRUE))) -
      (if (k == 1L) chaine_lue else 0L)
    if (restants > 0L) {
      liste_guillemets <- grepl("(^|~:)\\s*\\\\code\\{\"[^{}]*\"\\}, \\\\code\\{\"", cellules[k])
      inconnues <- c(inconnues, sprintf(
        "la cellule %d contient %d \\code{\"...\"} non lu(s)%s", k + 1L, restants,
        if (liste_guillemets) " (liste de valeurs écrite avec guillemets : écrire les valeurs sans guillemets)" else
          " (aucune forme reconnue ne le consomme)"))
    }
  }
  list(verifs = verifs, lecture = lecture, inconnues = inconnues)
}

# --- Décomptes du texte courant (issue #104) ------------------------------------------------

PORTEES_DECOMPTES <- c(MODULES, "package")
GRANDEURS_DECOMPTES <- c("fonctions", "exportees", "constantes")
# « zéro » s'écrit avec un accent ; « un » et « une » sont exclus de la table (articles
# avant tout).
# Les noms sont marqués UTF-8, comme les mots lus dans le document, pour que la recherche
# aboutisse quelle que soit la locale (« zéro » est introuvable sinon en locale C).
NOMBRES_DECOMPTES <- c(NOMBRES[!(names(NOMBRES) %in% c("un", "une"))], "zéro" = 0L)
Encoding(names(NOMBRES_DECOMPTES)) <- "UTF-8"
MARQUEUR_DECOMPTES <- "^\\s*%\\s*concordance-decomptes\\s*:\\s*(\\S+)((\\s+[a-z]+=[0-9]{1,6})+)\\s*$"
# Comme MOTIF_DECOMPTE ; (*UCP) pour que [[:alpha:]] lise « zéro » en entier (sans lui, PCRE
# ne voit que l'ASCII et lit « ro »), sur un texte lu comme UTF-8.
MOTIF_DECOMPTE_TEXTE <- paste0("(*UCP)(?<![[:alpha:]-])([[:alpha:]]+(?:-[[:alpha:]]+)*)[\\s~]+",
                               "(fonctions?|export\\S{1,2}es?|constantes?)(?![[:alpha:]])")

# Seule la première lettre d'un nombre peut être une majuscule (« Deux », « Zéro ») : on ne
# met en minuscule que cette lettre, si elle est ASCII, et rien d'autre. tolower() de tout le
# mot dépendrait de la locale (« ZÉRO » devient « zéro » en UTF-8, pas en locale C).
minuscule_initiale <- function(mot) {
  if (grepl("^[A-Z]", mot)) paste0(tolower(substr(mot, 1L, 1L)), substring(mot, 2L)) else mot
}

# Marqueurs de décomptes du document : liste de list(ligne, portee, valide, decl, paragraphe)
# (decl : entiers nommés par grandeur) et anomalies de lecture (marqueur mal formé, portée ou
# grandeur inconnue, grandeur répétée, `package` avec une autre grandeur qu'exportees, sans
# paragraphe).
lire_decomptes <- function(chemin) {
  lignes <- readLines(chemin, encoding = "UTF-8", warn = FALSE)
  marqueurs <- list()
  anomalies <- character(0)
  for (i in grep("^\\s*%+\\s*concordance-decomptes", lignes)) {
    m <- regmatches(lignes[i], regexec(MARQUEUR_DECOMPTES, lignes[i]))[[1L]]
    if (length(m) != 4L) {
      anomalies <- c(anomalies, sprintf("ligne %d : marqueur mal formé (attendu : %% concordance-decomptes : <portée> <grandeur>=<N> ...)", i))
      next
    }
    portee <- m[2L]
    jetons <- strsplit(trimws(m[3L]), "\\s+")[[1L]]
    grandeurs <- sub("=.*$", "", jetons)
    valeurs <- as.integer(sub("^.*=", "", jetons))
    ok <- TRUE
    if (!(portee %in% PORTEES_DECOMPTES)) {
      anomalies <- c(anomalies, sprintf("ligne %d : portée inconnue : %s", i, portee))
      ok <- FALSE
    }
    for (g in setdiff(unique(grandeurs), GRANDEURS_DECOMPTES)) {
      anomalies <- c(anomalies, sprintf("ligne %d : grandeur inconnue : %s", i, g))
      ok <- FALSE
    }
    for (g in unique(grandeurs[duplicated(grandeurs)])) {
      anomalies <- c(anomalies, sprintf("ligne %d : grandeur déclarée deux fois : %s", i, g))
      ok <- FALSE
    }
    if (identical(portee, "package") && any(grandeurs != "exportees")) {
      anomalies <- c(anomalies, sprintf("ligne %d : la portée package n'admet que exportees", i))
      ok <- FALSE
    }
    # Paragraphe : jusqu'à la première ligne blanche, lignes de commentaire exclues.
    j <- i + 1L
    paragraphe <- character(0)
    apres_commentaire <- FALSE  # la ligne précédente finit par un commentaire : jonction sans espace
    while (j <= length(lignes) && nzchar(trimws(lignes[j]))) {
      if (!grepl("^\\s*%", lignes[j])) {
        # Commentaire de fin de ligne retiré ; comme en LaTeX, la fin de ligne commentée
        # n'est pas une espace et les blancs qui débutent la ligne suivante sont ignorés.
        texte <- sub("(?<!\\\\)%.*$", "", lignes[j], perl = TRUE)
        if (apres_commentaire) texte <- sub("^\\s+", "", texte)
        paragraphe <- c(paragraphe, if (length(paragraphe) && !apres_commentaire) paste0(" ", texte) else texte)
        apres_commentaire <- texte != lignes[j]
      }
      j <- j + 1L
    }
    if (length(paragraphe) == 0L) {
      anomalies <- c(anomalies, sprintf("ligne %d : marqueur sans paragraphe qui le suive", i))
      ok <- FALSE
    }
    # Une portée valide compte pour la complétude même si le marqueur a une autre anomalie
    # (déjà signalée) ; le marqueur n'est comparé au code que s'il est bien formé.
    marqueurs[[length(marqueurs) + 1L]] <- list(
      ligne = i, portee = portee, valide = ok,
      decl = if (ok) stats::setNames(valeurs, grandeurs) else integer(0),
      paragraphe = paste(paragraphe, collapse = ""))
  }
  list(marqueurs = marqueurs, anomalies = anomalies)
}

# Valeurs du code pour une portée : entiers nommés (package : exportees seulement).
decomptes_du_code <- function(racine, portee, exports) {
  if (identical(portee, "package")) return(c(exportees = length(exports)))
  chemin <- file.path(racine, "R", paste0(portee, ".R"))
  fonctions <- if (file.exists(chemin)) fonctions_du_fichier(chemin) else character(0)
  constantes <- if (file.exists(chemin)) constantes_majuscules_du_fichier(chemin) else character(0)
  c(fonctions = length(fonctions), exportees = sum(exports %in% fonctions),
    constantes = length(constantes))
}

section("concordance documentation <-> code")
document <- file.path(racine, "docs", "latex", "doc_outil_prov_vie.tex")
if (!file.exists(document)) {
  ecart("document docs/latex/doc_outil_prov_vie.tex", "absent")
} else {
  accord("document docs/latex/doc_outil_prov_vie.tex présent")
  lu <- lire_tableaux(document)
  for (a in lu$anomalies) ecart("tableaux de fonctions", a)
  fichiers <- list.files(file.path(racine, "R"), pattern = "\\.[Rr]$")
  hors_liste <- setdiff(sub("\\.[Rr]$", "", fichiers), MODULES)
  for (f in hors_liste) ecart("fichier de R/", paste0(f, " n'est pas un module de l'ADR 0010"))
  cites <- character(0)
  for (module in MODULES) {
    chemin <- file.path(racine, "R", paste0(module, ".R"))
    code <- if (file.exists(chemin)) fonctions_du_fichier(chemin) else character(0)
    doc <- if (module %in% names(lu$tableaux)) sort(lu$tableaux[[module]], method = "radix") else NULL
    cites <- c(cites, doc)
    if (is.null(doc) && length(code) == 0L) next
    if (is.null(doc)) {
      ecart(paste("module", module), "fonctions dans R/ mais aucun tableau dans le document")
      next
    }
    if (anyDuplicated(doc)) {
      ecart(paste("module", module), paste("fonctions citées deux fois :",
                                           paste(unique(doc[duplicated(doc)]), collapse = ", ")))
    }
    manquantes <- setdiff(code, doc)
    en_trop <- setdiff(doc, code)
    if (length(manquantes) > 0L) {
      ecart(paste("module", module), paste("fonctions absentes du document :",
                                           paste(manquantes, collapse = ", ")))
    }
    if (length(en_trop) > 0L) {
      ecart(paste("module", module), paste("fonctions citées mais absentes du code :",
                                           paste(en_trop, collapse = ", ")))
    }
    if (length(manquantes) == 0L && length(en_trop) == 0L) {
      accord(sprintf("module %s : %d fonction(s) concordante(s)", module, length(code)))
    }
  }
  exports <- exports_du_namespace(file.path(racine, "NAMESPACE"))
  non_cites <- setdiff(exports, cites)
  if (length(non_cites) > 0L) {
    ecart("exports du NAMESPACE", paste("non cités dans le document :", paste(non_cites, collapse = ", ")))
  } else {
    accord(sprintf("exports du NAMESPACE : %d, tous cités", length(exports)))
  }

  # Valeurs des constantes (issue #37).
  cl <- lire_constantes(document)
  for (a in cl$anomalies) ecart("tableaux de constantes", a)
  code_constantes <- constantes_du_code(racine)
  modules_cl <- unique(vapply(cl$rangees, function(r) if (is.na(r$module)) "" else r$module, ""))
  for (module in modules_cl[modules_cl != ""]) {
    rangees <- Filter(function(r) identical(r$module, module), cl$rangees)
    echecs <- 0L
    signaler <- function(nom, detail) {
      echecs <<- echecs + 1L
      ecart(paste0("constante ", nom, " (module ", module, ")"), detail)
    }
    noms <- vapply(rangees, function(r) r$nom, "")
    for (nom in unique(noms[duplicated(noms)])) signaler(nom, "citée deux fois dans le tableau")
    chemin_module <- file.path(racine, "R", paste0(module, ".R"))
    absentes <- if (file.exists(chemin_module)) setdiff(constantes_majuscules_du_fichier(chemin_module), noms) else character(0)
    if (length(absentes) > 0L) {
      echecs <- echecs + 1L
      ecart(paste("module", module), paste("constantes absentes du document :", paste(absentes, collapse = ", ")))
    }
    comparees <- 0L
    sans_litteral <- character(0)
    for (r in rangees) {
      c <- code_constantes[[r$nom]]
      if (is.null(c) || !identical(c$module, module)) {
        signaler(r$nom, sprintf("ligne %d : absente de R/%s.R (constante en majuscules attendue)", r$ligne, module))
        next
      }
      if (!is.na(c$erreur)) {
        signaler(r$nom, sprintf("ligne %d : non évaluable sans le package (%s)", r$ligne, c$erreur))
        next
      }
      cmp <- comparer_ligne(c$valeur, r$c2, r$c3)
      for (msg in cmp$lecture) signaler(r$nom, sprintf("ligne %d : %s", r$ligne, msg))
      for (msg in cmp$inconnues) signaler(r$nom, sprintf("ligne %d : %s", r$ligne, msg))
      if (length(cmp$verifs) == 0L) sans_litteral <- c(sans_litteral, r$nom)
      for (v in cmp$verifs) {
        comparees <- comparees + 1L
        if (!v$ok) {
          signaler(r$nom, sprintf("ligne %d : %s du document « %s », code %s", r$ligne, v$forme, v$doc,
                                  abrege(c$valeur)))
        }
      }
    }
    if (echecs == 0L) {
      accord(sprintf("constantes du module %s : %d citée(s), %d valeur(s) littérale(s) concordante(s)%s",
                     module, length(rangees), comparees,
                     if (length(sans_litteral)) paste0(" ; sans valeur littérale lue : ", paste(sans_litteral, collapse = ", ")) else ""))
    }
  }
  # Module qui a des constantes mais aucun tableau de constantes (issue #41).
  for (module in setdiff(MODULES, modules_cl)) {
    chemin_module <- file.path(racine, "R", paste0(module, ".R"))
    if (!file.exists(chemin_module)) next
    sans_tableau <- constantes_majuscules_du_fichier(chemin_module)
    if (length(sans_tableau) > 0L) {
      ecart(paste("module", module), paste("constantes dans R/ mais aucun tableau de constantes dans le document :",
                                           paste(sans_tableau, collapse = ", ")))
    }
  }

  # Décomptes du texte courant (issue #104).
  dc <- lire_decomptes(document)
  for (a in dc$anomalies) ecart("décomptes du texte courant", a)
  for (mq in dc$marqueurs) {
    if (!mq$valide) next
    etiquette <- sprintf("décomptes (ligne %d) %s", mq$ligne, mq$portee)
    code <- decomptes_du_code(racine, mq$portee, exports)
    echecs <- 0L
    for (g in names(mq$decl)) {
      if (mq$decl[[g]] != code[[g]]) {
        echecs <- echecs + 1L
        ecart(etiquette, sprintf("%s : marqueur %d, code %d", g, mq$decl[[g]], code[[g]]))
      }
    }
    lus <- 0L
    pos <- gregexpr(MOTIF_DECOMPTE_TEXTE, mq$paragraphe, perl = TRUE)[[1L]]
    for (k in seq_along(pos)[pos > 0L]) {
      trouve <- substr(mq$paragraphe, pos[k], pos[k] + attr(pos, "match.length")[k] - 1L)
      mots <- strsplit(trouve, "[[:space:]~]+")[[1L]]
      mot <- minuscule_initiale(mots[1L])
      # Mot qui précède le nombre : un nombre précédé d'un mot de nombre (« cent deux »,
      # « soixante et onze ») est un nombre composé, non lu.
      avant <- strsplit(sub("[[:space:]~]+$", "", substr(mq$paragraphe, 1L, pos[k] - 1L)), "[[:space:]~]+")[[1L]]
      precedent <- if (length(avant)) minuscule_initiale(avant[length(avant)]) else ""
      # Octets sans marque d'encodage pour l'affichage (comme dans lire_constantes) : sans
      # cela, « exportées » s'imprime « export<U+00E9>es » hors d'une locale UTF-8.
      Encoding(trouve) <- "unknown"
      if (!(mot %in% names(NOMBRES_DECOMPTES))) next
      if (all(strsplit(precedent, "-", fixed = TRUE)[[1L]] %in% MOTS_NOMBRES) && nzchar(precedent)) next
      g <- if (startsWith(mots[2L], "fonction")) {
        if (identical(mq$portee, "package")) "exportees" else "fonctions"
      } else if (startsWith(mots[2L], "export")) "exportees" else "constantes"
      if (!(g %in% names(mq$decl))) next
      lus <- lus + 1L
      n <- unname(NOMBRES_DECOMPTES[mot])
      if (n != mq$decl[[g]]) {
        echecs <- echecs + 1L
        ecart(etiquette, sprintf("texte « %s » = %d, marqueur %s=%d", trouve, n, g, mq$decl[[g]]))
      }
    }
    if (echecs == 0L) {
      accord(sprintf("%s : %s concordant(s) avec le code, %d nombre(s) en lettres lu(s)", etiquette,
                     paste0(names(mq$decl), "=", mq$decl, collapse = " "), lus))
    }
  }
  presentes <- vapply(dc$marqueurs, function(mq) mq$portee, "")
  for (portee in setdiff(PORTEES_DECOMPTES, presentes)) {
    ecart(paste("portée", portee), "aucun marqueur % concordance-decomptes dans le document")
  }
}

bilan()
