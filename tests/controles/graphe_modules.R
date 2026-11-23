# Controle : graphe des modules du package provie (ADR 0010, point 1 ; point 26 ; issue
# #12). Sur chaque fichier de R/ (parse avec srcref, getParseData : numeros de ligne) :
#   1. les fichiers de R/ sont exactement parmi les quinze modules de l'ADR 0010, point 1
#      (un fichier hors liste est refuse ; un module absent n'est pas une erreur : un
#      fichier n'existe qu'a partir de la branche qui lui donne un contenu) ;
#   2. chaque module n'appelle (fonction ou constante de premier niveau d'un autre
#      fichier) que les modules de la colonne "Peut appeler" du tableau, ecrit en dur
#      ci-dessous ; une autre arete est un [ECHEC] ;
#   3. aucun appel dynamique : do.call() sauf sur un nom de fonction de base nu ou une
#      fonction litterale (ex. do.call(rbind, liste)) ; un nom de la liste ci-dessous n'est
#      pas admis comme nom nu de do.call (#109), match.fun, get, get0, mget, eval,
#      evalq, eval.parent, parse, str2lang, str2expression, source, sys.source,
#      getFromNamespace, getExportedValue, asNamespace, getNamespace, loadNamespace,
#      requireNamespace, attachNamespace, as.environment (acces a un espace de noms ou a un
#      environnement par son nom), dynGet et .GlobalEnv (#137), environment (sous ses
#      trois formes, M236 : e <- environment(), environment(f) <- e, environment(f) ;
#      interdite meme sans argument, decision du mainteneur du 10 novembre 2026) et sa forme
#      appel `environment<-`(f, e), avec ou sans base:: (#137), `parent.env<-`(e, x) sous forme
#      d'appel, de meme (#178 ; la forme parent.env(e) <- x l'etait deja par parent.env),
#      introspection de pile et d'environnement
#      (M403, M411 et M412, dans l'esprit de M236 : parent.frame, sys.function, parent.env,
#      topenv, sys.call, sys.frame, sys.frames, sys.calls, sys.parent, sys.on.exit,
#      match.call, globalenv), provie:: et provie::: ; assign() au premier niveau d'un
#      fichier (definition invisible du graphe ; admis dans une fonction). Deux exceptions
#      d'introspection sont declarees en dur (EXCEPTIONS_INTROSPECTION, M409 et M412) :
#      topenv() dans la fonction empreinte_code() du module rapport (empreinte du code,
#      ADR 0007, point 9) et globalenv() dans la fonction avec_graine() du module outils
#      (graine locale et retablissement de .Random.seed, ADR 0010, point 21) ; chacune
#      porte sur ce module et cette fonction, non sur tout le fichier, et elle est perimee
#      (ECHEC, a retirer) si l'emploi disparait, le fichier du module etant present ; elle est
#      refusee (ECHEC sur la ligne de l'emploi) si son nom est aussi, dans la meme fonction de
#      premier niveau, la cible d'une affectation locale (`globalenv <- f ; globalenv()`, #137 ;
#      un champ `x$globalenv <- 1` n'en est pas une, #178), un argument formel
#      (`function(graine, expr, globalenv)`), une variable de for (`for (globalenv in l)`) ou le
#      nom en chaine d'un assign() ou delayedAssign() (`assign("globalenv", f)`) (#178 ; un appel de champ
#      `x$assign("globalenv", f)` n'est pas un assign()), ou si cette fonction contient un assign()
#      ou delayedAssign() a nom calcule, une cible de remplacement (`body(globalenv) <- f`), ou si
#      assign / delayedAssign est employe sans appel dans R/ (#184, M768) : l'exception couvre
#      l'appel de la fonction de base, non celui d'une variable locale ;
#      Ces noms sont interdits aussi sans appel (#109) : toute reference (symbole hors
#      position d'appel, ex. `g <- parent.frame`, `lapply(1, sys.call)`, `do.call(get, l)`,
#      `base::get`) est un [ECHEC] au meme titre que l'appel, sauf champ (`x$get`), nom
#      d'argument (`list(get = 1)`) et cible seule d'une affectation (`get <- 1`) ; une
#      exception declaree couvre les appels et les references de son nom dans sa fonction,
#      et la forme do.call(<nom>, ...) (nom nu, `what =` compris) ;
#      limite documentee (cote sur) : un nom local ou un argument formel homonyme, lu
#      (`function(get) get`, `for (get in x) get`), est signale comme une reference : le
#      renommer ;
#   4. un nom de premier niveau n'est defini que dans un seul fichier (par <-, =, ->, ->>) ;
#   5. temoins negatifs integres : simulation appele par un module du moteur, triangle
#      vers engagement, lecture appele par un module du moteur, rapport vers
#      calculer_provisions doivent etre refuses par la table ; et la table en dur est coherente (quinze modules, sans cycle) ;
#   6. un identifiant a point (auxiliaire du module, ADR 0010, annotation de la quatrieme
#      serie, (c)) defini au premier niveau d'un fichier n'est employe (appel ou symbole,
#      memes regles de portee qu'en 2) que dans ce fichier : "une fonction appelee hors de
#      son module ne porte pas de point" (issue #74, M405) ; un nom ecrit en chaine, qui
#      egale exactement un tel identifiant d'un autre fichier (vapply(x, ".aux", 1) :
#      match.fun), vaut son emploi (m1 ; pas pour les noms sans point, voir plus bas).
#      Exceptions declarees en dur (EXCEPTIONS_POINT, chacune avec le renvoi a son issue ;
#      vide depuis #102) : un emploi non declare est un [ECHEC] fichier:ligne ; une
#      exception declaree dont le fichier appelant et le fichier de definition sont presents
#      et qui ne se produit plus est aussi un [ECHEC] (a retirer de la liste), comme un
#      succes inattendu.
# Limite documentee (m1) : une chaine qui egale un nom de fonction sans point d'un autre
# module n'est pas comptee comme arete de la regle 2 (sur R/, des noms de colonnes comme
# "probabilite" ou "empreinte" valent des noms de fonctions : fausses aretes) ;
# `vapply(x, "calculer_x", 1)` vers un module non permis passe donc.
# Noms interdits ecrits en chaine (#184, m3) : un nom de la liste ci-dessus ecrit en chaine a la
# place de l'argument-fonction d'une des quinze fonctions de base qui le passent par match.fun
# (FONCTIONS_ORDRE_SUPERIEUR : lapply(1, "sys.call"), Map(f = 'get', x), raw string comprise) est une
# reference refusee, et couverte comme les autres par une exception declaree ; les chaines ailleurs
# (noms de colonnes : lapply(x, "[[", "source"), x[["environment"]]) ne le sont pas. do.call avec une
# chaine est deja refuse (nom nu requis).
# Les noms utilises comme champ (`x$nom`) ne sont pas des appels ; un appel ecrit entre
# accents graves ou entre guillemets (`f`(x), "f"(x)) vaut l'appel de f. Portee (M236,
# decision du mainteneur du 10 novembre 2026) : ne compte pas comme reference la seule cible
# d'une affectation (le symbole a gauche de <- ou =, a droite de ->) ; toute autre occurrence
# (argument de fonction repris dans le corps, variable de for, lecture avant ou apres une
# affectation locale, portee soeur) est comptee. Limite documentee (cote sur) : un nom local
# homonyme d'une definition d'un autre module (variable locale lue, fonction locale appelee,
# argument formel repris) produit une fausse arete, a lever en renommant le nom local.
# Limites connues (chacune mesuree sur une racine fictive, statut 0) :
#   - (#201) noms interdits en chaine : seuls les appels de FONCTIONS_ORDRE_SUPERIEUR, a leur
#     argument-fonction, sans appariement partiel, sont vus ; ne le sont pas un nom passe par une
#     variable (`n <- "eval"; lapply(x, n)`), dans c() ou list(), a une autre fonction d'ordre
#     superieur (`integrate("get", 0, 1)`), ni sous un nom d'argument partiel (`FU = "eval"`) ;
#     ni, mesure par la revue finale de Bo5 : une chaine entre parentheses ou accolades
#     (`lapply(x, ("get"))`), un appel de .mapply (absent de la liste) ; derriere un tube `|>`,
#     le premier argument insere n'est pas compte, d'ou un faux negatif (`x |> lapply("get")`)
#     et un refus a tort (`x |> lapply("[[", "source")`) ; R/ n'a aucun `|>` ;
#   - (#201) regle stricte (M746) : une cible de remplacement dont le premier argument est nomme
#     (`attr(x = globalenv, "k") <- 1`) n'est pas vue (mesure par la revue finale de Bo5) ;
#   - exception d'introspection : un assign() a nom calcule dans une autre fonction du fichier que
#     celle de l'exception (`poser <- function(n, v) assign(n, v)`, appelee par avec_graine : cet
#     appel est une reference interne au module) et une liaison par un environnement de donnees,
#     `with(list(globalenv = f), globalenv())`, `local(globalenv(), envir = list2env(...))`
#     (mesures) ou within (meme mecanisme, non mesure), ne sont pas vus (#194).
# Levees par #184 (regle stricte, M746 ; aucun signalement nouveau sur R/, mesure) : dans la fonction
# d'une exception declaree, un assign() ou delayedAssign() a nom calcule, en chaine brute ou avec
# echappement, une cible de remplacement (`body(globalenv) <- f`, `formals(body(globalenv)) <- NULL`),
# et, dans tout R/ (M768), assign ou delayedAssign employe sans appel (`(assign)("globalenv", f)`,
# `do.call(assign, ...)`, alias `g <- assign`, y compris au premier niveau du fichier) rendent
# l'exception inapplicable.
# Usage, depuis la racine du depot : Rscript tests/controles/graphe_modules.R
# Un argument facultatif designe une autre racine (copie du depot, pour les temoins).
# Sortie : lignes [OK] / [ECHEC] fichier:ligne ; statut 1 au moindre [ECHEC].
# Code ASCII, R de base seulement.

options(warn = 2)
.fichier_script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
.arguments <- commandArgs(trailingOnly = TRUE)
racine <- normalizePath(if (length(.arguments) >= 1L) .arguments[1L]
                        else file.path(dirname(.fichier_script), "..", ".."), mustWork = TRUE)
.n_echec <- 0L
rel <- function(chemin) if (startsWith(chemin, paste0(racine, "/"))) substring(chemin, nchar(racine) + 2L) else chemin
ok <- function(message) cat("[OK] ", message, "\n", sep = "")
echec <- function(message, chemin = NA_character_, ligne = NA_integer_) {
  .n_echec <<- .n_echec + 1L
  position <- if (is.na(chemin)) "" else paste0(rel(chemin), if (is.na(ligne)) "" else paste0(":", ligne), " ")
  cat("[ECHEC] ", position, message, "\n", sep = "")
}
fin <- function() quit(save = "no", status = if (.n_echec > 0L) 1L else 0L)

# --- Le graphe de l'ADR 0010, point 1 (colonne "Peut appeler"), en dur -----------------
# Arete lecture -> tables : annotation appelee par la specification de B2, sections 3.3 et 9
# (lire_table() construit la table_provie par tables::construire_table() ; hors de la chaine
# du moteur, aucun module du moteur n'appelant lecture).
TOUS_LES_MODULES_AMONT <- c("outils", "dictionnaire", "donnees", "tables", "garanties",
                            "engagement", "triangle", "risque_en_cours", "regles_comptables",
                            "projection", "plan")
AUTORISE <- list(
  outils             = character(0),
  dictionnaire       = c("outils"),
  lecture            = c("dictionnaire", "outils", "tables"),
  donnees            = c("dictionnaire", "outils"),
  tables             = c("outils"),
  garanties          = c("dictionnaire", "outils"),
  engagement         = c("tables", "garanties", "donnees", "outils"),
  triangle           = c("garanties", "donnees", "outils"),
  risque_en_cours    = c("engagement", "tables", "garanties", "donnees", "outils"),
  regles_comptables  = c("garanties", "tables", "donnees", "outils"),
  projection         = c("engagement", "tables", "garanties", "donnees", "outils"),
  plan               = c("tables", "garanties", "dictionnaire", "donnees", "outils"),
  rapport            = TOUS_LES_MODULES_AMONT,
  simulation         = c("dictionnaire", "garanties", "tables", "outils"),
  calculer_provisions = c(TOUS_LES_MODULES_AMONT, "rapport")
)
MODULES <- names(AUTORISE)

arete_permise <- function(de, vers) de == vers || vers %in% AUTORISE[[de]]

# Emplois d'un identifiant a point hors de son fichier : exceptions declarees (point 6),
# chacune avec son renvoi a une issue. Vide depuis #102 (les quatre auxiliaires qu'elle
# declarait sont renommes sans point dans leur module) ; le mecanisme reste, une exception
# nouvelle s'ajoutant ici avec son renvoi.
EXCEPTIONS_POINT <- data.frame(
  appelant = character(0), identifiant = character(0), defini_dans = character(0),
  renvoi = character(0), stringsAsFactors = FALSE)

# Emplois d'introspection admis (M409) : un appel de APPELS_DYNAMIQUES dans une fonction
# precise d'un module precis (pas toute ligne du fichier). Declaree en dur ; perimee (echec)
# quand l'emploi disparait, le fichier etant present.
EXCEPTIONS_INTROSPECTION <- data.frame(
  module = c("rapport", "outils"), fonction = c("empreinte_code", "avec_graine"),
  appel = c("topenv", "globalenv"),
  motif = c("empreinte du code, ADR 0007, point 9",
            "graine locale et retablissement de .Random.seed, ADR 0010, point 21"),
  stringsAsFactors = FALSE)

# Dependances dynamiques interdites (appel de fonction par son nom, evaluation de texte).
APPELS_DYNAMIQUES <- c("match.fun", "get", "get0", "mget", "eval", "evalq", "eval.parent",
                       "parse", "str2lang", "str2expression", "source", "sys.source",
                       "getFromNamespace", "getExportedValue", "asNamespace", "getNamespace",
                       "loadNamespace", "requireNamespace", "attachNamespace", "as.environment",
                       "environment", "parent.frame", "sys.function", "parent.env", "topenv",
                       "sys.call", "sys.frame", "sys.frames", "sys.calls", "sys.parent",
                       "sys.on.exit", "match.call", "globalenv", "dynGet", ".GlobalEnv", "environment<-",
                       "parent.env<-")

# Fonctions de base qui passent un de leurs arguments par match.fun() (mesure : parmi les
# fonctions de base, stats et utils dont le corps contient match.fun, ce sont les quinze de base a
# argument-fonction ; stats::integrate, aggregate, dendrapply et d'autres n'y sont pas) :
# nom -> argument-fonction. Une chaine a cette position est un nom de fonction passe en texte (#184, m3).
FONCTIONS_ORDRE_SUPERIEUR <- c(lapply = "FUN", sapply = "FUN", vapply = "FUN", mapply = "FUN", Map = "f",
                               Reduce = "f", Filter = "f", Find = "f", Position = "f", Negate = "f",
                               outer = "FUN", apply = "FUN", tapply = "FUN", eapply = "FUN", sweep = "FUN")
# assign() et delayedAssign() lient un nom dans l'environnement courant (premier argument `x`).
FONCTIONS_ASSIGN <- c("assign", "delayedAssign")

# --- Analyse d'un fichier --------------------------------------------------------------
# Rend list(defs, jetons, assign_haut) : defs = noms definis au premier niveau ; jetons =
# data.frame des symboles (appels, noms, packages) avec ligne, token, texte (sans accents
# graves ni guillemets), def (definition de premier niveau qui les contient), prec / suiv
# (jeton voisin), local (cible d'une affectation, hors champ), liaison (argument formel, variable
# de for ou cible de remplacement `f(sym) <- v`, #178, #184), assigne (appel a assign() ou
# delayedAssign() : nom litteral de la cible, "" si calcule, NA hors de ces appels), ref_assign
# (assign ou delayedAssign reference hors position d'appel, #184), chaine_fn (chaine en position
# de fonction d'une fonction d'ordre superieur, #184), statique (do.call : premier argument
# acceptable), cible (do.call : nom nu du premier argument, NA sinon) ; assign_haut = lignes
# des appels a assign() au premier niveau.
analyser <- function(chemin) {
  exprs <- parse(file = chemin, keep.source = TRUE, encoding = "UTF-8")
  vide <- list(defs = character(0), assign_haut = integer(0), jetons = data.frame(
    ligne = integer(0), token = character(0), texte = character(0), def = character(0),
    prec = character(0), suiv = character(0), local = logical(0), liaison = logical(0),
    assigne = character(0), ref_assign = logical(0), chaine_fn = logical(0), statique = logical(0),
    cible = character(0), stringsAsFactors = FALSE))
  pd <- getParseData(exprs)
  if (is.null(pd)) return(vide)
  pd <- pd[pd$token != "COMMENT", ]
  pd <- pd[order(pd$line1, pd$col1, -pd$line2, -pd$col2), ]
  enfants <- split(seq_len(nrow(pd)), pd$parent)
  lignes_de <- function(id) enfants[[as.character(id)]]
  jetons_affectation <- c("LEFT_ASSIGN", "EQ_ASSIGN", "RIGHT_ASSIGN")
  # Definition de premier niveau : expr = expr(SYMBOL) <- ... , ou ... -> expr(SYMBOL).
  cible_affectation <- function(i) {
    k <- lignes_de(pd$id[i])
    if (length(k) >= 3L && pd$token[k[2L]] %in% jetons_affectation) {
      cote <- if (pd$token[k[2L]] == "RIGHT_ASSIGN") k[length(k)] else k[1L]
      if (pd$token[cote] == "expr") {
        s <- lignes_de(pd$id[cote])
        if (length(s) == 1L && pd$token[s] %in% c("SYMBOL", "STR_CONST")) return(gsub("[\"'`]", "", pd$text[s]))
      }
    }
    NA_character_
  }
  # Appel a assign() ou delayedAssign() qui est une expression de premier niveau (`assign(...)`,
  # `base::assign(...)` ; delayedAssign au meme titre, constat mineur de l'audit de #184).
  appel_assign <- function(i) {
    k <- lignes_de(pd$id[i])
    if (length(k) >= 3L && pd$token[k[1L]] == "expr" && pd$token[k[2L]] == "'('") {
      f <- lignes_de(pd$id[k[1L]])
      dernier <- f[length(f)]
      return(pd$token[dernier] %in% c("SYMBOL_FUNCTION_CALL", "STR_CONST") &&
               gsub("[\"'`]", "", pd$text[dernier]) %in% FONCTIONS_ASSIGN)
    }
    FALSE
  }
  # Definition de premier niveau de chaque noeud.
  haut <- pd$id
  repeat {
    p <- pd$parent[match(haut, pd$id)]
    monte <- p > 0L
    if (!any(monte)) break
    haut[monte] <- p[monte]
  }
  tops <- which(pd$parent == 0L)
  nom_def <- rep(NA_character_, nrow(pd))
  defs <- character(0)
  assign_haut <- integer(0)
  for (i in tops) {
    n <- cible_affectation(i)
    if (!is.na(n)) {
      defs <- c(defs, n)
      nom_def[haut == pd$id[i]] <- n
    }
    if (appel_assign(i)) assign_haut <- c(assign_haut, pd$line1[i])
  }
  # Arguments d'un appel (enfants de l'expr d'appel) : les ids de l'expression de chaque argument,
  # nomme (`x = ...`) ou non, dans l'ordre ; le nom, NA si positionnel.
  arguments_appel <- function(appel) {
    args <- appel[-(1:2)]
    args <- args[pd$token[args] != "')'"]
    if (length(args) == 0L) return(list())
    groupe <- cumsum(c(TRUE, pd$token[args][-length(args)] == "','"))
    res <- list()
    for (g in unique(groupe)) {
      ids <- args[groupe == g & pd$token[args] != "','"]
      if (length(ids) == 0L) next
      # Nom d'argument : SYMBOL_SUB, ou chaine suivie de EQ_SUB (`"x" = 1`) ; accents graves et
      # guillemets retires (`x` = 1, "x" = 1 valent x = 1).
      nomme <- pd$token[ids[1L]] == "SYMBOL_SUB" ||
        (pd$token[ids[1L]] == "STR_CONST" && length(ids) >= 2L && pd$token[ids[2L]] == "EQ_SUB")
      res[[length(res) + 1L]] <- list(nom = if (nomme) gsub("[\"'`]", "", pd$text[ids[1L]]) else NA_character_,
                                      expr = if (nomme) ids[3L] else ids[1L])
    }
    res
  }
  # Valeur d'une constante chaine (raw string r"(...)", echappements) : parse() d'un litteral, sans
  # evaluation ; "" si le jeton n'en est pas une (#184).
  valeur_chaine <- function(texte) {
    v <- tryCatch(parse(text = texte, keep.source = FALSE)[[1L]], error = function(e) NULL, warning = function(w) NULL)
    if (is.character(v) && length(v) == 1L && !is.na(v)) v else ""
  }
  # Jetons terminaux, dans l'ordre du source. Une chaine en position d'appel ("f"(x), : son
  # expression est suivie de `(`) est un appel ; les accents graves et guillemets sont retires.
  term <- which(pd$terminal)
  appel_chaine <- rep(FALSE, length(term))
  parent_de <- match(pd$parent, pd$id)
  for (r in which(pd$token[term] == "STR_CONST")) {
    e <- parent_de[term[r]]
    g <- parent_de[e]
    if (!is.na(g)) {
      k <- lignes_de(pd$id[g])
      m <- match(e, k)
      appel_chaine[r] <- !is.na(m) && m < length(k) && pd$token[k[m + 1L]] == "'('"
    }
  }
  token_eff <- ifelse(appel_chaine, "SYMBOL_FUNCTION_CALL", pd$token[term])
  texte_eff <- ifelse(token_eff %in% c("SYMBOL_FUNCTION_CALL", "SYMBOL", "SYMBOL_PACKAGE", "SYMBOL_FORMALS"),
                      gsub("[\"'`]", "", pd$text[term]), pd$text[term])
  precedent <- c(NA_character_, pd$token[term][-length(term)])
  suivant <- c(pd$token[term][-1L], NA_character_)
  # Chaines (m1) : une chaine qui n'est ni en position d'appel ni un nom d'argument (`"nom" = `)
  # est gardee, sans ses guillemets, pour y reconnaitre un nom de fonction passe en texte
  # (vapply(x, ".aux", 1) : match.fun).
  nom_argument <- c(pd$token[term][-1L], NA_character_) %in% "EQ_SUB"
  chaine_simple <- token_eff == "STR_CONST" & !nom_argument & grepl("^([\"']).*\\1$", pd$text[term])
  texte_eff[chaine_simple] <- substring(pd$text[term][chaine_simple], 2L, nchar(pd$text[term][chaine_simple]) - 1L)
  # Valeur decodee d'une chaine avec echappement ou d'une chaine brute (constat mineur de l'audit de
  # #184) : `"glob\x61lenv" <- f` et `r"(globalenv)" <- f` lient le nom `globalenv` comme cible
  # d'affectation locale. valeur_chaine() rend "" pour une chaine qui n'en est pas une : texte garde.
  chaine_codee <- token_eff == "STR_CONST" & !nom_argument & (grepl("\\", pd$text[term], fixed = TRUE) | !chaine_simple)
  if (any(chaine_codee)) {
    v <- vapply(pd$text[term][chaine_codee], valeur_chaine, character(1), USE.NAMES = FALSE)
    texte_eff[chaine_codee] <- ifelse(nzchar(v), v, texte_eff[chaine_codee])
  }
  # Chaine en position de fonction (#184, m3) : valeur d'argument d'un appel direct d'une fonction de
  # FONCTIONS_ORDRE_SUPERIEUR, a la place de son argument-fonction (`lapply(1, "sys.call")`,
  # `Map(f = "dynGet", x)`) ; l'appariement des arguments suit R (nom exact, puis rang parmi les arguments
  # sans nom avant `...`), sans appariement partiel. La chaine est gardee avec sa valeur decodee.
  chaine_fn <- rep(FALSE, length(term))
  for (r in which(pd$token[term] == "STR_CONST")) {
    e <- parent_de[term[r]]
    if (is.na(e) || pd$token[e] != "expr" || length(lignes_de(pd$id[e])) != 1L) next
    g <- parent_de[e]
    if (is.na(g)) next
    k <- lignes_de(pd$id[g])
    if (length(k) < 3L || pd$token[k[1L]] != "expr" || pd$token[k[2L]] != "'('") next
    f <- lignes_de(pd$id[k[1L]])
    dernier <- f[length(f)]
    if (pd$token[dernier] != "SYMBOL_FUNCTION_CALL" || !(pd$text[dernier] %in% names(FONCTIONS_ORDRE_SUPERIEUR))) next
    # Un appel de champ (`x$lapply(1, "get")`, `x@lapply(...)`) n'est pas un appel de la fonction de base
    # (meme regle que pour assign, #178 ; constat mineur de l'audit de #184).
    if (length(f) >= 2L && pd$token[f[length(f) - 1L]] %in% c("'$'", "'@'")) next
    formels <- names(formals(get(pd$text[dernier], envir = baseenv(), mode = "function")))
    cible_f <- FONCTIONS_ORDRE_SUPERIEUR[[pd$text[dernier]]]
    args <- arguments_appel(k)
    noms <- vapply(args, function(a) a$nom, character(1))
    libres <- setdiff(formels, noms[!is.na(noms)])
    libres <- libres[seq_len(match("...", libres, nomatch = length(libres) + 1L) - 1L)]
    sans_nom <- which(is.na(noms))
    rang <- match(cible_f, libres)
    designe <- if (cible_f %in% noms) which(noms %in% cible_f)[1L]
               else if (!is.na(rang) && rang <= length(sans_nom)) sans_nom[rang] else NA_integer_
    if (!is.na(designe) && identical(args[[designe]]$expr, e)) {
      v <- valeur_chaine(pd$text[term[r]])
      if (v %in% APPELS_DYNAMIQUES) {
        chaine_fn[r] <- TRUE
        texte_eff[r] <- v
      }
    }
  }
  interessants <- token_eff %in% c("SYMBOL_FUNCTION_CALL", "SYMBOL", "SYMBOL_PACKAGE", "SYMBOL_FORMALS") | chaine_simple | chaine_codee | chaine_fn
  idx <- term[interessants]
  # Cible seule : un symbole est local s'il est la cible d'une affectation (M236).
  est_cible <- function(t) {
    e <- parent_de[t]
    g <- parent_de[e]
    if (is.na(g)) return(FALSE)
    k <- lignes_de(pd$id[g])
    length(k) >= 3L && pd$token[k[2L]] %in% jetons_affectation &&
      (if (pd$token[k[2L]] == "RIGHT_ASSIGN") k[length(k)] else k[1L]) == e
  }
  # Variable de for : symbole fils direct de forcond (#178) ; avec les arguments formels
  # (SYMBOL_FORMALS), elle lie le nom dans la fonction (liaison).
  est_variable_for <- function(t) {
    e <- parent_de[t]
    !is.na(e) && pd$token[e] == "forcond"
  }
  # Cible de remplacement (#184) : `f(sym) <- v`, `f(g(sym), y) <- v`, `sym[i] <- v` lient `sym` dans la
  # fonction (`body(globalenv) <- v` cree un `globalenv` local qui masque celui de base) ; le symbole est
  # le premier argument d'un appel ou l'objet d'un `[`, `[[`, `$`, `@`, a tout niveau d'imbrication.
  est_cible_remplacement <- function(t) {
    e <- parent_de[t]
    repeat {
      g <- parent_de[e]
      if (is.na(e) || is.na(g)) return(FALSE)
      k <- lignes_de(pd$id[g])
      if (length(k) >= 3L && pd$token[k[2L]] %in% jetons_affectation) {
        return((if (pd$token[k[2L]] == "RIGHT_ASSIGN") k[length(k)] else k[1L]) == e && e != parent_de[t])
      }
      if (length(k) >= 4L && pd$token[k[2L]] == "'('" && k[3L] == e && pd$token[k[1L]] == "expr") {
        e <- g
      } else if (length(k) >= 3L && pd$token[k[2L]] %in% c("'['", "LBB", "'$'", "'@'") && k[1L] == e) {
        e <- g
      } else {
        return(FALSE)
      }
    }
  }
  # Un champ (`x$nom <- 1`) n'est pas la cible d'une affectation du nom (#178). La branche '@' est
  # par symetrie : le nom apres `@` porte le jeton SLOT, non retenu comme symbole (mesure : sans
  # elle, `x@globalenv <- 2` ne declenche pas le faux positif).
  champ_avant <- precedent[interessants] %in% c("'$'", "'@'")
  jetons <- data.frame(
    ligne = pd$line1[idx], token = token_eff[interessants], texte = texte_eff[interessants],
    def = nom_def[idx], prec = precedent[interessants], suiv = suivant[interessants],
    local = token_eff[interessants] %in% c("SYMBOL", "STR_CONST") & vapply(idx, est_cible, logical(1)) & !champ_avant,
    liaison = token_eff[interessants] == "SYMBOL_FORMALS" |
      (token_eff[interessants] == "SYMBOL" & vapply(idx, est_variable_for, logical(1))) |
      (token_eff[interessants] == "SYMBOL" & vapply(idx, est_cible_remplacement, logical(1)) & !champ_avant),
    assigne = NA_character_, ref_assign = FALSE, chaine_fn = chaine_fn[interessants],
    statique = NA, cible = NA_character_, stringsAsFactors = FALSE)
  # assign et delayedAssign references hors position d'appel (#184) : `(assign)("globalenv", f)`,
  # `do.call(assign, list(...))`, `g <- assign` ; ni champ, ni cible seule d'une affectation.
  jetons$ref_assign <- jetons$token == "SYMBOL" & jetons$texte %in% FONCTIONS_ASSIGN & !champ_avant & !jetons$local
  # assign() et delayedAssign() : nom en chaine de la cible (argument x, ou premier argument positionnel ;
  # raw string comprise) ; "" si le nom est calcule, ce qui rend l'exception inapplicable (regle stricte,
  # #184, M746). Un appel de champ (`x$assign(...)`, `x@assign(...)`) n'est pas un appel de base.
  for (r in which(jetons$token == "SYMBOL_FUNCTION_CALL" & jetons$texte %in% FONCTIONS_ASSIGN &
                    !(jetons$prec %in% c("'$'", "'@'")))) {
    i <- idx[r]
    nom_fonction <- match(pd$parent[i], pd$id)
    args <- arguments_appel(lignes_de(pd$parent[nom_fonction]))
    noms <- vapply(args, function(a) a$nom, character(1))
    choix <- if (any(noms %in% "x")) which(noms %in% "x")[1L] else which(is.na(noms))[1L]
    nom_cible <- ""
    if (!is.na(choix) && !is.na(args[[choix]]$expr) && pd$token[args[[choix]]$expr] == "expr") {
      k <- lignes_de(pd$id[args[[choix]]$expr])
      if (length(k) == 1L && pd$token[k] == "STR_CONST") nom_cible <- valeur_chaine(pd$text[k])
    }
    jetons$assigne[r] <- nom_cible
  }
  # do.call : premier argument (what) = nom nu d'une fonction de base, ou fonction litterale.
  for (r in which(jetons$token == "SYMBOL_FUNCTION_CALL" & jetons$texte == "do.call")) {
    i <- idx[r]
    nom_fonction <- match(pd$parent[i], pd$id)               # expr du nom de fonction
    args <- arguments_appel(lignes_de(pd$parent[nom_fonction]))
    noms <- vapply(args, function(a) a$nom, character(1))
    # what = (accents graves et chaine compris, #184) sinon premier argument sans nom
    choix <- if (any(noms %in% "what")) which(noms %in% "what")[1L] else which(is.na(noms))[1L]
    premier <- if (is.na(choix)) NA_integer_ else args[[choix]]$expr
    statique <- FALSE
    cible <- NA_character_
    if (!is.na(premier) && pd$token[premier] == "expr") {
      k <- lignes_de(pd$id[premier])
      if (length(k) == 1L && pd$token[k] == "SYMBOL") {
        nom_nu <- gsub("`", "", pd$text[k])
        cible <- nom_nu
        statique <- !(nom_nu %in% APPELS_DYNAMIQUES) &&
          exists(nom_nu, envir = baseenv(), mode = "function", inherits = FALSE)
      } else if (length(k) >= 1L && pd$token[k[1L]] == "FUNCTION") {
        statique <- TRUE
      }
    }
    jetons$statique[r] <- statique
    jetons$cible[r] <- cible
  }
  list(defs = unique(defs), jetons = jetons, assign_haut = assign_haut)
}

# --- 1. Fichiers de R/ -------------------------------------------------------------------
dossier_r <- file.path(racine, "R")
if (!dir.exists(dossier_r)) {
  echec("dossier R/ absent", dossier_r)
  fin()
}
fichiers <- sort(list.files(dossier_r, recursive = TRUE, all.files = TRUE), method = "radix")
avant <- .n_echec
for (f in fichiers) {
  if (!(f %in% paste0(MODULES, ".R"))) {
    echec(sprintf("fichier hors des quinze modules de l'ADR 0010, point 1 (attendu : <module>.R, module parmi %s)",
                  paste(MODULES, collapse = ", ")), file.path(dossier_r, f))
  }
}
if (.n_echec == avant) ok(sprintf("R/ : %d fichier(s), tous parmi les quinze modules", length(fichiers)))
fichiers <- fichiers[fichiers %in% paste0(MODULES, ".R")]

# --- Analyse -----------------------------------------------------------------------------
analyses <- list()
for (f in fichiers) {
  chemin <- file.path(dossier_r, f)
  r <- tryCatch(analyser(chemin), error = function(e) conditionMessage(e))
  if (is.character(r)) {
    echec(paste0("fichier non analysable : ", gsub("[^ -~]", "?", r)), chemin)
  } else {
    analyses[[sub("\\.R$", "", f)]] <- r
  }
}

# --- 4. Definitions uniques ------------------------------------------------------------------
module_de <- character(0)
avant <- .n_echec
for (m in names(analyses)) {
  for (nom in analyses[[m]]$defs) {
    if (nom %in% names(module_de) && module_de[[nom]] != m) {
      echec(sprintf("`%s` est defini dans deux modules (`%s` et `%s`)", nom, module_de[[nom]], m),
            file.path(dossier_r, paste0(m, ".R")))
    } else {
      module_de[[nom]] <- m
    }
  }
}
if (.n_echec == avant) ok(sprintf("%d nom(s) de premier niveau, chacun defini dans un seul module", length(module_de)))

# --- 2 et 3. Aretes et appels dynamiques ----------------------------------------------------
avant <- .n_echec
n_aretes <- 0L
introspections_vues <- integer(0)
# assign / delayedAssign employe sans appel n'importe ou dans R/ (alias, do.call, `(assign)(...)`) rend
# les exceptions inapplicables (#184, M768 : un alias defini dans un autre module, appele depuis une
# fonction d'exception, echappait a la portee au fichier).
assign_sans_appel <- any(vapply(analyses, function(a) any(a$jetons$ref_assign), logical(1)))
emplois_point <- data.frame(appelant = character(0), identifiant = character(0),
                            defini_dans = character(0), ligne = integer(0), stringsAsFactors = FALSE)
for (m in names(analyses)) {
  chemin <- file.path(dossier_r, paste0(m, ".R"))
  j <- analyses[[m]]$jetons
  vus <- character(0)
  for (l in analyses[[m]]$assign_haut) {
    echec("assign() au premier niveau : definition invisible du graphe (ADR 0010, point 1) ; admis dans une fonction",
          chemin, l)
  }
  for (r in seq_len(nrow(j))) {
    texte <- j$texte[r]
    champ <- !is.na(j$prec[r]) && j$prec[r] %in% c("'$'", "'@'")
    if (j$token[r] == "SYMBOL_PACKAGE" && texte == "provie") {
      echec("provie:: et provie::: sont interdits dans R/ (ADR 0010, point 26)", chemin, j$ligne[r])
    }
    # Appel ou reference (#109 : symbole hors position d'appel, cible seule d'une affectation
    # exclue, M236) a un nom de APPELS_DYNAMIQUES ; l'exception declaree couvre les deux.
    appel_dyn <- j$token[r] == "SYMBOL_FUNCTION_CALL" && !champ
    # (la variable de for ou l'argument formel, liaison, d'un nom couvert par une exception
    # declaree dans cette fonction n'est pas une reference : sans cela
    # `for (globalenv in l) globalenv()` donne deux echecs sur la meme ligne ; ailleurs, une
    # liaison a un nom de APPELS_DYNAMIQUES reste une reference refusee, `for (get in l) 1`)
    couverte <- any(EXCEPTIONS_INTROSPECTION$module == m & EXCEPTIONS_INTROSPECTION$appel == texte &
      EXCEPTIONS_INTROSPECTION$fonction %in% j$def[r])
    reference_dyn <- j$token[r] == "SYMBOL" && !champ && !j$local[r] && !(j$liaison[r] && couverte)
    # nom interdit ecrit en chaine a la place de l'argument-fonction d'une fonction d'ordre superieur
    # (#184, m3) : une reference, couverte comme les autres par l'exception declaree.
    chaine_dyn <- j$token[r] == "STR_CONST" && isTRUE(j$chaine_fn[r])
    if ((appel_dyn || reference_dyn || chaine_dyn) && texte %in% APPELS_DYNAMIQUES) {
      declaree <- EXCEPTIONS_INTROSPECTION$module == m & EXCEPTIONS_INTROSPECTION$appel == texte &
        EXCEPTIONS_INTROSPECTION$fonction %in% j$def[r]
      if (any(declaree)) {
        introspections_vues <- c(introspections_vues, which(declaree))
        # #137 : le nom est aussi la cible d'une affectation locale de la meme fonction de
        # premier niveau (`globalenv <- f`) : l'appel ou la reference peut viser la variable.
        # #178 : ou un argument formel, une variable de for, ou un nom assigne par assign().
        # #184 (regle stricte, M746) : ou une cible de remplacement (`body(globalenv) <- f`), un assign()
        # ou delayedAssign() a nom calcule ou en chaine brute (le nom lu est "" ou decode) dans la fonction,
        # ou assign / delayedAssign reference sans appel dans R/ (alias, do.call, `(assign)(...)` ; M768).
        meme_def <- !is.na(j$def) & j$def == j$def[r]
        if (any(meme_def & j$texte == texte & ((j$local & j$token %in% c("SYMBOL", "STR_CONST")) | j$liaison)) ||
            any(meme_def & !is.na(j$assigne) & (j$assigne == texte | j$assigne == "")) ||
            assign_sans_appel) {
          echec(sprintf("exception declaree inapplicable : `%s` est aussi la cible d'une affectation locale, d'un remplacement, un argument formel, une variable de for ou un nom assigne par assign() ou delayedAssign() (nom calcule compris) dans `%s`, ou assign / delayedAssign est employe sans appel dans R/ (#137, #178, #184) ; renommer le nom local",
                        texte, j$def[r]), chemin, j$ligne[r])
        }
      } else if (appel_dyn) {
        echec(sprintf("appel dynamique interdit : %s()", texte), chemin, j$ligne[r])
      } else if (chaine_dyn) {
        echec(sprintf("reference dynamique interdite : \"%s\" ecrit en chaine a la place de la fonction d'une fonction d'ordre superieur (#184, m3)", texte),
              chemin, j$ligne[r])
      } else {
        echec(sprintf("reference dynamique interdite : %s sans appel (#109)", texte), chemin, j$ligne[r])
      }
    } else if (appel_dyn && texte == "do.call" && !isTRUE(j$statique[r]) &&
               !(!is.na(j$cible[r]) && any(EXCEPTIONS_INTROSPECTION$module == m &
                                            EXCEPTIONS_INTROSPECTION$appel == j$cible[r] &
                                            EXCEPTIONS_INTROSPECTION$fonction %in% j$def[r]))) {
      # (une exception declaree pour le nom nu de do.call, dans sa fonction, couvre aussi la forme do.call)
      echec("appel dynamique interdit : do.call() autrement que sur un nom de fonction de base nu (hors fonctions interdites) ou une fonction litterale",
            chemin, j$ligne[r])
    }
    # m1 : un nom d'auxiliaire a point passe en texte (vapply(x, ".aux", 1) : match.fun) est un
    # emploi, comme l'appel ; pas pour les autres noms (sur R/, des chaines comme "probabilite"
    # ou "empreinte", noms de colonnes, valent des noms de fonctions d'autres modules : fausses
    # aretes), ni pour un champ (`x$".aux"`) ni pour une cible d'affectation.
    if (j$token[r] == "STR_CONST" && !champ && !j$local[r] && startsWith(texte, ".") &&
        texte %in% names(module_de) && module_de[[texte]] != m) {
      emplois_point[nrow(emplois_point) + 1L, ] <- list(m, texte, module_de[[texte]], j$ligne[r])
    }
    if (j$token[r] %in% c("SYMBOL_FUNCTION_CALL", "SYMBOL") && !champ && !j$local[r] &&
        texte %in% names(module_de) && module_de[[texte]] != m) {
      vers <- module_de[[texte]]
      n_aretes <- n_aretes + 1L
      if (startsWith(texte, ".")) {
        emplois_point[nrow(emplois_point) + 1L, ] <- list(m, texte, vers, j$ligne[r])
      }
      cle <- paste(j$ligne[r], texte)
      if (!arete_permise(m, vers) && !(cle %in% vus)) {
        vus <- c(vus, cle)
        echec(sprintf("module `%s` appelle `%s` (symbole `%s`) : arete hors du graphe de l'ADR 0010, point 1", m, vers, texte),
              chemin, j$ligne[r])
      }
    }
  }
}
for (k in seq_len(nrow(EXCEPTIONS_INTROSPECTION))) {
  e <- EXCEPTIONS_INTROSPECTION[k, ]
  if (e$module %in% names(analyses) && !(k %in% introspections_vues)) {
    echec(sprintf("exception declaree (%s) qui ne se produit plus : `%s()` n'est plus ni appele ni reference dans `%s` (module `%s`) ; la retirer de EXCEPTIONS_INTROSPECTION",
                  e$motif, e$appel, e$fonction, e$module), file.path(dossier_r, paste0(e$module, ".R")))
  }
}
if (.n_echec == avant) {
  ok(sprintf("graphe respecte (%d reference(s) entre modules), aucun appel dynamique hors des exceptions d'introspection declarees (M409, M412 : %d declaree(s), %d constatee(s))",
             n_aretes, nrow(EXCEPTIONS_INTROSPECTION), length(unique(introspections_vues))))
}

# --- 5. Table en dur et temoins negatifs integres ---------------------------------------------
avant <- .n_echec
if (length(MODULES) != 15L || anyDuplicated(MODULES) > 0L || !all(unlist(AUTORISE) %in% MODULES)) {
  echec("table AUTORISE incoherente : quinze modules distincts attendus, cibles incluses")
}
acyclique <- function() {
  etat <- setNames(rep(0L, length(MODULES)), MODULES)
  visiter <- function(m) {
    if (etat[[m]] == 1L) return(FALSE)
    if (etat[[m]] == 2L) return(TRUE)
    etat[[m]] <<- 1L
    res <- all(vapply(AUTORISE[[m]], visiter, logical(1)))
    etat[[m]] <<- 2L
    res
  }
  all(vapply(MODULES, visiter, logical(1)))
}
if (!acyclique()) echec("table AUTORISE : le graphe contient un cycle")
moteur <- setdiff(MODULES, c("lecture", "simulation"))
for (m in moteur) {
  if (arete_permise(m, "simulation")) echec(sprintf("temoin negatif : `%s` -> `simulation` serait admis", m))
  if (arete_permise(m, "lecture")) echec(sprintf("temoin negatif : `%s` -> `lecture` serait admis", m))
}
if (arete_permise("triangle", "engagement")) echec("temoin negatif : `triangle` -> `engagement` serait admis")
if (arete_permise("rapport", "calculer_provisions")) echec("temoin negatif : `rapport` -> `calculer_provisions` serait admis")
if (arete_permise("outils", "dictionnaire")) echec("temoin negatif : `outils` -> `dictionnaire` serait admis")
if (!arete_permise("simulation", "dictionnaire") || !arete_permise("calculer_provisions", "rapport")) {
  echec("table AUTORISE : arete attendue absente (simulation -> dictionnaire, calculer_provisions -> rapport)")
}
if (.n_echec == avant) ok("table en dur coherente (quinze modules, sans cycle) ; temoins negatifs refuses : moteur -> simulation, moteur -> lecture, triangle -> engagement, rapport -> calculer_provisions")

# --- 6. Identifiants a point employes hors de leur fichier (#74, M405) -----------------------
avant <- .n_echec
declare <- paste(EXCEPTIONS_POINT$appelant, EXCEPTIONS_POINT$identifiant, EXCEPTIONS_POINT$defini_dans)
cle_emploi <- paste(emplois_point$appelant, emplois_point$identifiant, emplois_point$defini_dans)
vus_point <- character(0)
for (r in seq_len(nrow(emplois_point))) {
  cle_ligne <- paste(cle_emploi[r], emplois_point$ligne[r])
  if (!(cle_emploi[r] %in% declare) && !(cle_ligne %in% vus_point)) {
    vus_point <- c(vus_point, cle_ligne)
    echec(sprintf("`%s` : auxiliaire a point de `%s` employe hors de son module (ADR 0010, annotation de la quatrieme serie, (c)) ; le renommer sans point dans son module, ou, a defaut, le declarer dans EXCEPTIONS_POINT avec son renvoi a une issue",
                  emplois_point$identifiant[r], emplois_point$defini_dans[r]),
          file.path(dossier_r, paste0(emplois_point$appelant[r], ".R")), emplois_point$ligne[r])
  }
}
for (k in seq_len(nrow(EXCEPTIONS_POINT))) {
  e <- EXCEPTIONS_POINT[k, ]
  if (all(c(e$appelant, e$defini_dans) %in% names(analyses)) && !(declare[k] %in% cle_emploi)) {
    echec(sprintf("exception declaree (%s) qui ne se produit plus : `%s` n'est plus employe par `%s` depuis `%s` ; la retirer de EXCEPTIONS_POINT",
                  e$renvoi, e$identifiant, e$appelant, e$defini_dans),
          file.path(dossier_r, paste0(e$appelant, ".R")))
  }
}
if (.n_echec == avant) {
  ok(sprintf("identifiants a point : aucun emploi hors de son fichier hors des exceptions declarees : %d exception(s) declaree(s), %d constatee(s)",
             length(declare), sum(declare %in% cle_emploi)))
}

fin()
