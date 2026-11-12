# Controle : graphe des modules du package provie (ADR 0010, point 1 ; point 26 ; issue
# #12). Sur chaque fichier de R/ (parse avec srcref, getParseData : numeros de ligne) :
#   1. les fichiers de R/ sont exactement parmi les quinze modules de l'ADR 0010, point 1
#      (un fichier hors liste est refuse ; un module absent n'est pas une erreur : un
#      fichier n'existe qu'a partir de la branche qui lui donne un contenu) ;
#   2. chaque module n'appelle (fonction ou constante de premier niveau d'un autre
#      fichier) que les modules de la colonne "Peut appeler" du tableau, ecrit en dur
#      ci-dessous ; une autre arete est un [ECHEC] ;
#   3. aucun appel dynamique : do.call() sauf sur un nom de fonction de base nu ou une
#      fonction litterale (ex. do.call(rbind, liste)), match.fun, get, get0, mget, eval,
#      evalq, eval.parent, parse, str2lang, str2expression, source, sys.source,
#      getFromNamespace, getExportedValue, asNamespace, getNamespace, loadNamespace,
#      requireNamespace, attachNamespace, as.environment (acces a un espace de noms ou a un
#      environnement par son nom), environment (sous ses trois formes, M236 : e <-
#      environment(), environment(f) <- e, environment(f) ; interdite meme sans argument,
#      decision du mainteneur du 10 novembre 2026), introspection de pile et d'environnement
#      (M403, M411 et M412, dans l'esprit de M236 : parent.frame, sys.function, parent.env,
#      topenv, sys.call, sys.frame, sys.frames, sys.calls, sys.parent, sys.on.exit,
#      match.call, globalenv), provie:: et provie::: ; assign() au premier niveau d'un
#      fichier (definition invisible du graphe ; admis dans une fonction). Deux exceptions
#      d'introspection sont declarees en dur (EXCEPTIONS_INTROSPECTION, M409 et M412) :
#      topenv() dans la fonction empreinte_code() du module rapport (empreinte du code,
#      ADR 0007, point 9) et globalenv() dans la fonction avec_graine() du module outils
#      (graine locale et retablissement de .Random.seed, ADR 0010, point 21) ; chacune
#      porte sur ce module et cette fonction, non sur tout le fichier, et elle est perimee
#      (ECHEC, a retirer) si l'emploi disparait, le fichier du module etant present ;
#   4. un nom de premier niveau n'est defini que dans un seul fichier (par <-, =, ->, ->>) ;
#   5. temoins negatifs integres : simulation appele par un module du moteur, triangle
#      vers engagement, lecture appele par un module du moteur, rapport vers
#      calculer_provisions doivent etre refuses par la table ; et la table en dur est coherente (quinze modules, sans cycle) ;
#   6. un identifiant a point (auxiliaire du module, ADR 0010, annotation de la quatrieme
#      serie, (c)) defini au premier niveau d'un fichier n'est employe (appel ou symbole,
#      memes regles de portee qu'en 2) que dans ce fichier : « une fonction appelee hors de
#      son module ne porte pas de point » (issue #74, M405) ; un nom ecrit en chaine, qui
#      egale exactement un tel identifiant d'un autre fichier (vapply(x, ".aux", 1) :
#      match.fun), vaut son emploi (m1 ; pas pour les noms sans point, voir plus bas).
#      Exceptions declarees en dur (EXCEPTIONS_POINT, chacune renvoyee a l'issue #102) : un
#      emploi non declare est un [ECHEC] fichier:ligne ; une exception declaree dont le fichier appelant et le fichier
#      de definition sont presents et qui ne se produit plus est aussi un [ECHEC] (a retirer
#      de la liste), comme un succes inattendu.
# Limite documentee (m1) : une chaine qui egale un nom de fonction sans point d'un autre
# module n'est pas comptee comme arete de la regle 2 (sur R/, des noms de colonnes comme
# "probabilite" ou "empreinte" valent des noms de fonctions : fausses aretes) ;
# `vapply(x, "calculer_x", 1)` vers un module non permis passe donc.
# Limite documentee (appels dynamiques, regle 3) : seul l'appel est vu ; une reference sans
# appel a une fonction interdite (`g <- parent.frame; g()`, `lapply(1, sys.call)`,
# `do.call(parent.frame, list())` : do.call accepte tout nom de fonction de base nu) passe,
# comme pour eval et get.
# Les noms utilises comme champ (`x$nom`) ne sont pas des appels ; un appel ecrit entre
# accents graves ou entre guillemets (`f`(x), "f"(x)) vaut l'appel de f. Portee (M236,
# decision du mainteneur du 10 novembre 2026) : ne compte pas comme reference la seule cible
# d'une affectation (le symbole a gauche de <- ou =, a droite de ->) ; toute autre occurrence
# (argument de fonction repris dans le corps, variable de for, lecture avant ou apres une
# affectation locale, portee soeur) est comptee. Limite documentee (cote sur) : un nom local
# homonyme d'une definition d'un autre module (variable locale lue, fonction locale appelee,
# argument formel repris) produit une fausse arete, a lever en renommant le nom local.
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

# Emplois d'un identifiant a point hors de son fichier : exceptions declarees (point 6 ;
# issue #102 : a renommer sans point dans leur module, puis a retirer d'ici).
EXCEPTIONS_POINT <- data.frame(
  appelant = c("donnees", "donnees", "donnees", "calculer_provisions"),
  identifiant = c(".longueur_commune", ".composantes_date", ".jour_de", ".controler_rejeu"),
  defini_dans = c("outils", "outils", "outils", "plan"),
  renvoi = "#102", stringsAsFactors = FALSE)

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
                       "sys.on.exit", "match.call", "globalenv")

# --- Analyse d'un fichier --------------------------------------------------------------
# Rend list(defs, jetons, assign_haut) : defs = noms definis au premier niveau ; jetons =
# data.frame des symboles (appels, noms, packages) avec ligne, token, texte (sans accents
# graves ni guillemets), def (definition de premier niveau qui les contient), prec / suiv
# (jeton voisin), local (cible d'une affectation), statique (do.call : premier argument
# acceptable) ; assign_haut = lignes des appels a assign() au premier niveau.
analyser <- function(chemin) {
  exprs <- parse(file = chemin, keep.source = TRUE, encoding = "UTF-8")
  vide <- list(defs = character(0), assign_haut = integer(0), jetons = data.frame(
    ligne = integer(0), token = character(0), texte = character(0), def = character(0),
    prec = character(0), suiv = character(0), local = logical(0), statique = logical(0),
    stringsAsFactors = FALSE))
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
  # Appel a assign() qui est une expression de premier niveau (`assign(...)`, `base::assign(...)`).
  appel_assign <- function(i) {
    k <- lignes_de(pd$id[i])
    if (length(k) >= 3L && pd$token[k[1L]] == "expr" && pd$token[k[2L]] == "'('") {
      f <- lignes_de(pd$id[k[1L]])
      dernier <- f[length(f)]
      return(pd$token[dernier] %in% c("SYMBOL_FUNCTION_CALL", "STR_CONST") &&
               gsub("[\"'`]", "", pd$text[dernier]) == "assign")
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
  texte_eff <- ifelse(token_eff %in% c("SYMBOL_FUNCTION_CALL", "SYMBOL", "SYMBOL_PACKAGE"),
                      gsub("[\"'`]", "", pd$text[term]), pd$text[term])
  precedent <- c(NA_character_, pd$token[term][-length(term)])
  suivant <- c(pd$token[term][-1L], NA_character_)
  # Chaines (m1) : une chaine qui n'est ni en position d'appel ni un nom d'argument (`"nom" = `)
  # est gardee, sans ses guillemets, pour y reconnaitre un nom de fonction passe en texte
  # (vapply(x, ".aux", 1) : match.fun).
  nom_argument <- c(pd$token[term][-1L], NA_character_) %in% "EQ_SUB"
  chaine_simple <- token_eff == "STR_CONST" & !nom_argument & grepl("^([\"']).*\\1$", pd$text[term])
  texte_eff[chaine_simple] <- substring(pd$text[term][chaine_simple], 2L, nchar(pd$text[term][chaine_simple]) - 1L)
  interessants <- token_eff %in% c("SYMBOL_FUNCTION_CALL", "SYMBOL", "SYMBOL_PACKAGE") | chaine_simple
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
  jetons <- data.frame(
    ligne = pd$line1[idx], token = token_eff[interessants], texte = texte_eff[interessants],
    def = nom_def[idx], prec = precedent[interessants], suiv = suivant[interessants],
    local = token_eff[interessants] %in% c("SYMBOL", "STR_CONST") & vapply(idx, est_cible, logical(1)),
    statique = NA, stringsAsFactors = FALSE)
  # do.call : premier argument (what) = nom nu d'une fonction de base, ou fonction litterale.
  for (r in which(jetons$token == "SYMBOL_FUNCTION_CALL" & jetons$texte == "do.call")) {
    i <- idx[r]
    nom_fonction <- match(pd$parent[i], pd$id)               # expr du nom de fonction
    appel <- lignes_de(pd$parent[nom_fonction])              # enfants de l'expr d'appel
    args <- appel[-(1:2)]
    premier <- args[1L]
    if (!is.na(premier) && pd$token[premier] == "SYMBOL_SUB" && pd$text[premier] == "what") premier <- args[3L]
    statique <- FALSE
    if (!is.na(premier) && pd$token[premier] == "expr") {
      k <- lignes_de(pd$id[premier])
      if (length(k) == 1L && pd$token[k] == "SYMBOL") {
        statique <- exists(gsub("`", "", pd$text[k]), envir = baseenv(), mode = "function", inherits = FALSE)
      } else if (length(k) >= 1L && pd$token[k[1L]] == "FUNCTION") {
        statique <- TRUE
      }
    }
    jetons$statique[r] <- statique
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
    if (j$token[r] == "SYMBOL_FUNCTION_CALL" && !champ) {
      if (texte %in% APPELS_DYNAMIQUES) {
        declaree <- EXCEPTIONS_INTROSPECTION$module == m & EXCEPTIONS_INTROSPECTION$appel == texte &
          EXCEPTIONS_INTROSPECTION$fonction %in% j$def[r]
        if (any(declaree)) {
          introspections_vues <- c(introspections_vues, which(declaree))
        } else {
          echec(sprintf("appel dynamique interdit : %s()", texte), chemin, j$ligne[r])
        }
      } else if (texte == "do.call" && !isTRUE(j$statique[r])) {
        echec("appel dynamique interdit : do.call() autrement que sur un nom de fonction de base nu ou une fonction litterale",
              chemin, j$ligne[r])
      }
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
    echec(sprintf("exception declaree (%s) qui ne se produit plus : `%s()` n'est plus appele dans `%s` (module `%s`) ; la retirer de EXCEPTIONS_INTROSPECTION",
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
  ok(sprintf("identifiants a point : aucun emploi hors de son fichier hors des exceptions declarees (#102) : %d exception(s) declaree(s), %d constatee(s)",
             length(declare), sum(declare %in% cle_emploi)))
}

fin()
