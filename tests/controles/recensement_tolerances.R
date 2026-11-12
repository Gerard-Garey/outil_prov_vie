# Recensement des verifications a tolerance (#79 ; ADR 0011, point 7) : sort la liste des appels
# de verifier_egal() a tolerance > 0 et des appels directs de all.equal(tolerance = ...) des
# fichiers R de tests/, et signale ceux dont l'argument attendu est un vecteur, une liste ou une
# colonne de grandeurs d'ordres differents.
# Critere mesurable (analyse statique, sans executer les tests) : l'argument attendu est evalue
# dans un environnement sans effet de bord (parent emptyenv() ; constantes numeriques litterales
# des affectations de premier niveau du fichier, liste blanche de fonctions pures FONCTIONS_PURES,
# D() = as.Date) ; ses feuilles numeriques finies non nulles (dates exclues,
# listes et colonnes parcourues) sont rassemblees ; l'argument est SIGNALE si elles sont au moins
# deux et que max |x| / min |x| >= 10 ; il est INDETERMINE (et liste) s'il n'est pas evaluable
# sans les donnees des tests ou sans appeler une fonction hors liste blanche : rien n'est execute.
# La tolerance d'un appel est lue : litterale, ou symbole affecte a un litteral en tete de
# fichier (TOL) ; sinon l'appel est range en "tolerance non resolue" (comptee a tolerance > 0).
# Un appel dont les arguments ne s'apparient pas sans execution (`...` transmis, argument en trop)
# est "indetermine" et liste, sa tolerance lue sur l'argument nomme `tolerance` s'il y en a un.
# Un appel est reconnu sous ses formes nue, entre accents graves ou prefixee (`base::all.equal`,
# `pkg::verifier_egal`), par l'arbre et par l'analyse du source ; un champ (`x$verifier_egal(...)`)
# n'est pas un appel. Un nom ecrit en chaine en position d'appel (`"all.equal"(...)`) que l'arbre
# compte et que l'analyse du source ne voit pas rend le recensement incoherent (echec) : il ne
# passe pas inapercu.
# Les petites valeurs (verifier_egal seulement) : pour |r| <= 1 la tolerance est absolue
# (tests/harnais.R) ; elle ne garantit l'ecart relatif EFFET_RELATIF = 1.5e-7 (plus petit effet de
# formule rencontre, ADR 0011, point 8, jugement d'expert) que pour |r| >= tolerance / EFFET_RELATIF
# (6.7e-4 a 1e-10). Au-dessus de |r| = 1 la tolerance est relative : la regle ne s'applique pas, le
# seuil est borne a 1, min(1, tolerance / EFFET_RELATIF). Un appel dont une feuille numerique finie
# non nulle est sous ce seuil (tolerance lue) est liste sous PETITES VALEURS, en plus de son
# classement (la regle vaut aussi pour un scalaire) ; la parade est tolerance = 1e-10 * |r| ou la
# comparaison de obtenu / r a 1 (valeur attendue melant des ordres de grandeur : voir tests/harnais.R).
# Les appels directs de all.equal(tolerance = ...) dans verifier() ne passent pas par
# verifier_egal() : ils sont listes a part, memes criteres.
# Sortie informative : lignes [INFO] ; [ECHEC] seulement si un fichier n'est pas analysable ou si
# le recensement des appels n'est pas coherent (statut 1). Aucune ligne [ECHEC] pour un signalement.
# Usage, depuis la racine du depot : Rscript tests/controles/recensement_tolerances.R
# Un argument facultatif designe une autre racine. Code ASCII, R de base seulement.

options(warn = 2)
.fichier_script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
.arguments <- commandArgs(trailingOnly = TRUE)
racine <- normalizePath(if (length(.arguments) >= 1L) .arguments[1L]
                        else file.path(dirname(.fichier_script), "..", ".."), mustWork = TRUE)
.n_echec <- 0L
info <- function(...) cat("[INFO] ", ..., "\n", sep = "")
echec <- function(message, chemin = NA_character_) {
  .n_echec <<- .n_echec + 1L
  cat("[ECHEC] ", if (is.na(chemin)) "" else paste0(chemin, " "), message, "\n", sep = "")
}

RAPPORT_ORDRES <- 10
EFFET_RELATIF <- 1.5e-7

# Fichiers R de tests/ (tests/reference/ exclu : jeux de donnees, pas du code de test).
fichiers <- sort(list.files(file.path(racine, "tests"), pattern = "\\.R$", recursive = TRUE, full.names = TRUE),
                 method = "radix")
fichiers <- fichiers[!startsWith(fichiers, paste0(file.path(racine, "tests", "reference"), "/"))]
rel <- function(chemin) substring(chemin, nchar(racine) + 2L)

# L'appel `e` est-il un appel a `nom` : `nom(...)`, `` `nom`(...) `` (meme symbole) ou `pkg::nom(...)`,
# `pkg:::nom(...)` ? (`x$nom(...)` : un champ, non.)
est_appel_de <- function(e, nom) {
  f <- e[[1L]]
  if (is.symbol(f)) return(identical(as.character(f), nom))
  is.call(f) && length(f) == 3L && is.symbol(f[[1L]]) && as.character(f[[1L]]) %in% c("::", ":::") &&
    is.symbol(f[[3L]]) && identical(as.character(f[[3L]]), nom)
}

# Appels (langage) a `nom` dans l'ordre du source.
appels_de <- function(x, nom) {
  trouves <- list()
  visite <- function(e) {
    if (is.call(e)) {
      if (est_appel_de(e, nom)) trouves[[length(trouves) + 1L]] <<- e
      for (i in seq_along(e)) if (!identical(e[[i]], quote(expr = ))) visite(e[[i]])
    } else if (is.expression(e) || is.list(e)) {
      for (i in seq_along(e)) if (!identical(e[[i]], quote(expr = ))) visite(e[[i]])
    }
  }
  visite(x)
  trouves
}

# Feuilles numeriques finies non nulles d'une valeur evaluee (dates exclues).
feuilles <- function(x) {
  if (is.null(x) || inherits(x, "Date")) return(numeric(0))
  if (is.list(x)) return(unlist(lapply(x, feuilles), use.names = FALSE))
  if (is.numeric(x)) { v <- abs(as.numeric(x)); return(v[is.finite(v) & v > 0]) }
  numeric(0)
}

# Evaluation sans effet de bord : l'environnement a pour parent emptyenv() et ne contient que les
# constantes du fichier et une liste blanche de fonctions pures ; tout autre appel (file.create,
# quit, une fonction de test...) ou toute variable est introuvable, l'evaluation echoue et
# l'argument est "indetermine" : rien d'autre n'est execute.
FONCTIONS_PURES <- c("c", "list", "data.frame", "(", "+", "-", "*", "/", "^", ":", "rep", "seq", "exp", "log",
                     "sqrt", "abs", "as.numeric", "as.integer", "as.Date")
evaluer <- function(expr, constantes) {
  env <- list2env(constantes, parent = emptyenv())
  for (f in FONCTIONS_PURES) assign(f, get(f, envir = baseenv(), mode = "function"), envir = env)
  assign("D", as.Date, envir = env)
  tryCatch(list(valeur = eval(expr, env), ok = TRUE), error = function(e) list(valeur = NULL, ok = FALSE))
}

# Seuil des petites valeurs : au-dessus de |r| = 1 la tolerance du harnais est relative, la regle
# ne s'applique pas.
seuil_petites <- function(tol) min(1, tol / EFFET_RELATIF)

# Classe l'argument attendu : "scalaire", "homogene", "signale" (ordres differents),
# "indetermine" (expression non evaluable sans les donnees ni appel hors liste blanche) ;
# `petites` : une feuille numerique finie non nulle est sous min(1, tolerance / EFFET_RELATIF) (`tol`
# lue, NA pour un appel sans tolerance resolue ou all.equal : sans objet) ; `min_abs` : la plus
# petite |feuille| non nulle evaluee (NA si aucune).
classer <- function(expr, constantes, tol = NA_real_) {
  r <- evaluer(expr, constantes)
  if (!r$ok) return(list(classe = "indetermine", detail = "", petites = FALSE, min_abs = NA_real_))
  f <- feuilles(r$valeur)
  petit <- if (length(f) > 0L) min(f) else NA_real_
  petites <- length(f) > 0L && !is.na(tol) && tol > 0 && petit < seuil_petites(tol)
  if (length(f) < 2L) return(list(classe = "scalaire", detail = "", petites = petites, min_abs = petit))
  rapport <- max(f) / min(f)
  list(classe = if (rapport >= RAPPORT_ORDRES) "signale" else "homogene",
       detail = sprintf("%d feuilles, max/min = %.3g", length(f), rapport), petites = petites, min_abs = petit)
}

resoudre_tolerance <- function(expr, constantes) {
  if (is.numeric(expr)) return(expr)
  if (is.symbol(expr) && !is.null(constantes[[as.character(expr)]])) return(constantes[[as.character(expr)]])
  NA_real_
}

lignes_de <- function(chemin, jeton) {
  d <- getParseData(parse(chemin, keep.source = TRUE))
  if (is.null(d)) return(integer(0))
  # jetons terminaux dans l'ordre du source ; un champ (`x$nom(...)`) n'est pas un appel
  t <- d[d$terminal & d$token != "COMMENT", ]
  t <- t[order(t$line1, t$col1), ]
  precedent <- c(NA_character_, t$token[-nrow(t)])
  garde <- t$token == "SYMBOL_FUNCTION_CALL" & gsub("`", "", t$text, fixed = TRUE) == jeton &
    !(precedent %in% c("'$'", "'@'"))
  t$line1[garde]
}

recensement <- list()
total_egal <- 0L
for (chemin in fichiers) {
  exprs <- tryCatch(parse(chemin, keep.source = TRUE), error = function(e) NULL)
  if (is.null(exprs)) {
    echec("non analysable", rel(chemin))
    next
  }
  # constantes numeriques litterales des affectations de premier niveau
  constantes <- list()
  for (e in exprs) {
    if (is.call(e) && identical(e[[1L]], as.name("<-")) && is.symbol(e[[2L]]) && is.numeric(e[[3L]])) {
      constantes[[as.character(e[[2L]])]] <- e[[3L]]
    }
  }
  for (jeton in c("verifier_egal", "all.equal")) {
    appels <- appels_de(exprs, jeton)
    lignes <- lignes_de(chemin, jeton)
    if (length(appels) != length(lignes)) {
      echec(sprintf("recensement incoherent pour %s : %d appels dans l'arbre, %d dans l'analyse du source", jeton,
                    length(appels), length(lignes)), rel(chemin))
      next
    }
    if (jeton == "verifier_egal") total_egal <- total_egal + length(appels)
    for (i in seq_along(appels)) {
      a <- appels[[i]]
      signature <- if (jeton == "verifier_egal") function(nom, obtenu, attendu, tolerance = 0) NULL
                   else function(target, current, ..., tolerance = 1.5e-8) NULL
      # Les arguments ne s'apparient pas toujours sans execution (`...` transmis, argument en
      # trop : match.call() echoue) : l'appel est alors indetermine, la tolerance etant lue sur
      # l'argument nomme `tolerance` s'il y en a un.
      m <- tryCatch(match.call(signature, a, envir = emptyenv()), error = function(e) NULL)
      if (is.null(m)) {
        tol <- if (is.null(a[["tolerance"]])) NA_real_ else resoudre_tolerance(a[["tolerance"]], constantes)
        if (!is.na(tol) && tol == 0) next
        cl <- list(classe = "indetermine", detail = "arguments non appariables", petites = FALSE, min_abs = NA_real_)
      } else {
        if (is.null(m$tolerance)) next
        tol <- resoudre_tolerance(m$tolerance, constantes)
        if (!is.na(tol) && tol == 0) next
        cl <- classer(if (jeton == "verifier_egal") m$attendu else m$current, constantes,
                      if (jeton == "verifier_egal") tol else NA_real_)
      }
      recensement[[length(recensement) + 1L]] <- data.frame(
        fichier = rel(chemin), ligne = lignes[i], appel = jeton,
        tolerance = if (is.na(tol)) "non resolue" else format(tol), classe = cl$classe, detail = cl$detail,
        petites = cl$petites, min_abs = cl$min_abs, stringsAsFactors = FALSE)
    }
  }
}
res <- if (length(recensement) > 0L) do.call(rbind, recensement) else NULL

info(sprintf("fichiers analyses : %d ; appels de verifier_egal() : %d", length(fichiers), total_egal))
if (is.null(res)) {
  info("aucun appel a tolerance > 0")
} else {
  egal <- res[res$appel == "verifier_egal", ]
  direct <- res[res$appel == "all.equal", ]
  info(sprintf("verifier_egal() a tolerance > 0 : %d appels (tolerance non resolue : %d)", nrow(egal),
               sum(egal$tolerance == "non resolue")))
  par_fichier <- table(egal$fichier)
  for (f in names(par_fichier)) info(sprintf("  %s : %d", f, par_fichier[[f]]))
  info("classement de l'argument attendu : ", paste(sprintf("%s = %d", names(table(egal$classe)), table(egal$classe)),
                                                    collapse = ", "))
  petites <- egal[egal$petites, ]
  info(sprintf("PETITES VALEURS (feuille numerique finie non nulle de |r| < min(1, tolerance / %g) : pour |r| <= 1 la tolerance est absolue, l'ecart relatif garanti depasse %g) : %d appels",
               EFFET_RELATIF, EFFET_RELATIF, nrow(petites)))
  for (i in seq_len(nrow(petites))) {
    info(sprintf("  %s:%d tolerance %s, plus petit |r| non nul = %.3g (seuil %.3g)", petites$fichier[i], petites$ligne[i],
                 petites$tolerance[i], petites$min_abs[i], seuil_petites(as.numeric(petites$tolerance[i]))))
  }
  if (any(!is.na(egal$min_abs))) {
    info(sprintf("plus petit |r| non nul parmi les valeurs attendues evaluees : %.3g", min(egal$min_abs, na.rm = TRUE)))
  }
  for (cl in c("signale", "indetermine")) {
    k <- egal[egal$classe == cl, ]
    info(sprintf("%s (%s) : %d appels", toupper(cl),
                 if (cl == "signale") "feuilles numeriques d'ordres differents, max/min >= 10"
                 else "non evaluable sans les donnees des tests, a controler", nrow(k)))
    for (i in seq_len(nrow(k))) info(sprintf("  %s:%d tolerance %s %s", k$fichier[i], k$ligne[i], k$tolerance[i], k$detail[i]))
  }
  info(sprintf("all.equal(tolerance = ...) direct (hors verifier_egal) : %d appels", nrow(direct)))
  for (i in seq_len(nrow(direct))) {
    info(sprintf("  %s:%d tolerance %s, attendu : %s %s", direct$fichier[i], direct$ligne[i], direct$tolerance[i],
                 direct$classe[i], direct$detail[i]))
  }
}
quit(save = "no", status = if (.n_echec > 0L) 1L else 0L)
