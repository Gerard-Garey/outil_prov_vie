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
# Les zeros attendus (verifier_egal seulement ; #111) : un zero attendu compare a tolerance > 0 est admis
# a |x| <= tolerance (tests/harnais.R) : il se compare a part, a tolerance nulle s'il est exact par
# construction, sinon a tolerance absolue declaree. Un appel a tolerance > 0 (ou non resolue) dont
# l'argument attendu contient un zero reel (un zero entier, 0L, est exact par son type) est liste sous
# ZEROS ATTENDUS A TOLERANCE > 0 : feuille numerique nulle de la valeur evaluee, ou, si l'argument n'est
# pas evaluable sans les donnees des tests, constante litterale 0 de l'expression (une expression non
# evaluable peut en cacher d'autres : le critere est syntaxique, il n'est pas exhaustif). Dans un appel
# non evaluable, les arguments qui ne sont pas des valeurs ne comptent pas : indices de `[` et `[[`,
# times, length.out et each de rep(), digits de round() et signif(), longueur de character(0) ; numeric(n)
# et double(n) avec n litteral > 0 comptent n zeros. Pour un appel dont les arguments ne s'apparient pas,
# l'attendu est lu par position (3e argument sans nom) ou sous son nom.
# Un zero obtenu par compensation (ecart de passage, total moins la somme de ses parties), que le
# harnais compare a tolerance absolue declaree, reste a tolerance, dans son propre appel : la ligne qui
# precede l'appel porte la marque `# zero_compense : <motif>`, et l'appel est compte a part (ZERO DE
# COMPENSATION DECLARE), hors de la rubrique des zeros a corriger ; un appel marque qui contient plus
# d'un zero reel est liste a part (A PLUSIEURS ZEROS), et une marque sur un appel sans zero, ou sans
# appel de verifier_egal() a la ligne suivante, sous MARQUES ORPHELINES. Ces rubriques sont informatives.
# Les appels directs de all.equal(tolerance = ...) dans verifier() ne passent pas par
# verifier_egal() : ils sont listes a part, memes criteres.
# Sortie informative : lignes [INFO] ; [ECHEC] seulement si un fichier n'est pas analysable ou si
# le recensement des appels n'est pas coherent (statut 1). Aucune ligne [ECHEC] pour un signalement.
# Limites connues (reserves d'audit non corrigees, suivies par la question Q-32 / Q-33 de la
# feuille de route ; chacune mesuree sur une racine fictive) :
#   - r1 : un commentaire `# zero_compense` en fin de ligne (`x <- 1  # zero_compense : m`) est
#     pris pour une marque : l'appel de la ligne suivante est range sous ZERO DE COMPENSATION
#     DECLARE ;
#   - r2 : rep(0, k), avec k non evaluable, ne compte qu'un zero (c(0, 0) en compte deux) : un
#     appel marque qui porte rep(0, k) n'est pas liste sous A PLUSIEURS ZEROS ;
#   - r3 : pour un appel dont les arguments ne s'apparient pas (argument en trop, `...`),
#     `attendu` est lu par position, comme 3e argument sans nom : si des arguments nommes
#     (`nom =`, `obtenu =`) sont en tete, il manque, et ses zeros ne sont pas comptes ;
#   - le motif d'une marque n'est pas controle : `# zero_compense` sans motif compte comme une
#     marque.
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

# Zeros d'une valeur evaluee : feuilles reelles (double) finies nulles (dates exclues, listes et colonnes
# parcourues) ; un zero entier (0L) est exact par son type, il n'est pas compte.
zeros_feuilles <- function(x) {
  if (is.null(x) || inherits(x, "Date")) return(0L)
  if (is.list(x)) return(sum(unlist(lapply(x, zeros_feuilles), use.names = FALSE)))
  if (is.double(x)) return(sum(is.finite(x) & x == 0))
  0L
}

# Nombre de constantes litterales 0 (reelles) d'une expression (a defaut de pouvoir l'evaluer) ; un 0 qui
# n'est pas une valeur n'est pas compte : arguments de longueur ou d'indice (voir l'en-tete). rep(0, k) compte
# pour une constante. Les appels de FONCTIONS_SANS_ZERO (entiers, caracteres, logiques) ne portent aucun zero reel.
FONCTIONS_SANS_ZERO <- c("character", "integer", "logical", "seq_len")
FONCTIONS_PREMIER_ARGUMENT <- c("[", "[[", "rep", "rep_len", "round", "signif")
zeros_litteraux <- function(e) {
  if (is.double(e)) return(sum(is.finite(e) & e == 0))
  if (is.call(e) && is.symbol(e[[1L]])) {
    f <- as.character(e[[1L]])
    a <- as.list(e)[-1L]
    if (f %in% FONCTIONS_SANS_ZERO) return(0L)
    if (f %in% FONCTIONS_PREMIER_ARGUMENT) {
      # seul l'objet (premier argument sans nom, ou `x`) porte des valeurs ; les autres sont des longueurs ou des indices
      if (length(a) == 0L) return(0L)
      nm <- if (is.null(names(a))) rep("", length(a)) else names(a)
      k <- which(nm == "x")
      if (length(k) == 0L) k <- which(nm == "")[1L]
      if (is.na(k[1L]) || identical(a[[k[1L]]], quote(expr = ))) return(0L)
      return(zeros_litteraux(a[[k[1L]]]))
    }
    if (f %in% c("numeric", "double", "vector")) {
      # n zeros reels pour une longueur litterale n > 0 (vector : mode numeric ou double seulement)
      m <- tryCatch(match.call(if (f == "vector") function(mode, length) NULL else function(length) NULL, e, envir = emptyenv()),
                    error = function(err) NULL)
      if (is.null(m)) return(0L)
      if (f == "vector" && !(is.character(m$mode) && m$mode %in% c("numeric", "double"))) return(0L)
      n <- m$length
      return(if (is.numeric(n) && length(n) == 1L && is.finite(n) && n > 0) as.integer(n) else 0L)
    }
  }
  if (is.call(e) || is.expression(e)) {
    return(sum(vapply(seq_along(e), function(i) if (identical(e[[i]], quote(expr = ))) 0L else zeros_litteraux(e[[i]]),
                      integer(1L))))
  }
  0L
}

# Nombre de zeros d'une expression attendue : valeur evaluee si elle l'est, sinon constantes litterales.
compter_zeros <- function(expr, constantes) {
  r <- evaluer(expr, constantes)
  if (r$ok) zeros_feuilles(r$valeur) else zeros_litteraux(expr)
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
  if (!r$ok) {
    n <- if (is.na(tol) || tol > 0) zeros_litteraux(expr) else 0L
    return(list(classe = "indetermine", detail = "", petites = FALSE, min_abs = NA_real_, zeros = n > 0L, n_zeros = n))
  }
  n <- if (is.na(tol) || tol > 0) zeros_feuilles(r$valeur) else 0L
  f <- feuilles(r$valeur)
  petit <- if (length(f) > 0L) min(f) else NA_real_
  petites <- length(f) > 0L && !is.na(tol) && tol > 0 && petit < seuil_petites(tol)
  if (length(f) < 2L) return(list(classe = "scalaire", detail = "", petites = petites, min_abs = petit, zeros = n > 0L,
                                                  n_zeros = n))
  rapport <- max(f) / min(f)
  list(classe = if (rapport >= RAPPORT_ORDRES) "signale" else "homogene",
       detail = sprintf("%d feuilles, max/min = %.3g", length(f), rapport), petites = petites, min_abs = petit, zeros = n > 0L,
       n_zeros = n)
}

# Argument attendu d'un appel de verifier_egal() dont les arguments ne s'apparient pas : sous son nom, ou
# 3e argument sans nom si aucun `...` ne le precede (NULL sinon).
attendu_par_position <- function(a) {
  if (!is.null(a[["attendu"]])) return(a[["attendu"]])
  args <- as.list(a)[-1L]
  nm <- if (is.null(names(args))) rep("", length(args)) else names(args)
  sans_nom <- args[nm == ""]
  if (length(sans_nom) < 3L || any(vapply(sans_nom[1:3], function(x) identical(x, quote(...)), logical(1L)))) return(NULL)
  sans_nom[[3L]]
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
marques <- list()
appels_egal <- list()
total_egal <- 0L
for (chemin in fichiers) {
  exprs <- tryCatch(parse(chemin, keep.source = TRUE), error = function(e) NULL)
  if (is.null(exprs)) {
    echec("non analysable", rel(chemin))
    next
  }
  # marques `# zero_compense` : lignes des commentaires qui la portent
  d <- getParseData(exprs)
  marques_fichier <- if (is.null(d)) integer(0) else
    d$line1[d$token == "COMMENT" & grepl("^#[[:space:]]*zero_compense([[:space:]]|:|$)", d$text)]
  marques[[length(marques) + 1L]] <- data.frame(fichier = rep(rel(chemin), length(marques_fichier)), ligne = marques_fichier,
                                                stringsAsFactors = FALSE)
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
    if (jeton == "verifier_egal") {
      total_egal <- total_egal + length(appels)
      appels_egal[[length(appels_egal) + 1L]] <- data.frame(fichier = rep(rel(chemin), length(lignes)), ligne = lignes,
                                                            stringsAsFactors = FALSE)
    }
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
        att <- if (jeton == "verifier_egal") attendu_par_position(a) else NULL
        n <- if (!is.null(att) && (is.na(tol) || tol > 0)) compter_zeros(att, constantes) else 0L
        cl <- list(classe = "indetermine", detail = "arguments non appariables", petites = FALSE, min_abs = NA_real_,
                   zeros = n > 0L, n_zeros = n)
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
        petites = cl$petites, min_abs = cl$min_abs, zeros = cl$zeros, n_zeros = cl$n_zeros,
        compense = (lignes[i] - 1L) %in% marques_fichier, stringsAsFactors = FALSE)
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
  zeros <- egal[egal$zeros & !egal$compense, ]
  info(sprintf("ZEROS ATTENDUS A TOLERANCE > 0 (valeur attendue qui contient un zero, evalue ou litteral : a comparer a part, a tolerance nulle si le zero est exact par construction, sinon a tolerance absolue declaree ; tests/harnais.R) : %d appels",
               nrow(zeros)))
  for (i in seq_len(nrow(zeros))) info(sprintf("  %s:%d tolerance %s", zeros$fichier[i], zeros$ligne[i], zeros$tolerance[i]))
  declares <- egal[egal$zeros & egal$compense, ]
  info(sprintf("ZERO DE COMPENSATION DECLARE (marque `# zero_compense` sur la ligne qui precede l'appel ; tolerance absolue declaree) : %d appels",
               nrow(declares)))
  for (i in seq_len(nrow(declares))) info(sprintf("  %s:%d tolerance %s", declares$fichier[i], declares$ligne[i], declares$tolerance[i]))
  multi <- declares[declares$n_zeros > 1L, ]
  info(sprintf("ZERO DE COMPENSATION DECLARE A PLUSIEURS ZEROS (un appel marque ne porte que le zero de compensation, les autres zeros se comparent a part) : %d appels",
               nrow(multi)))
  for (i in seq_len(nrow(multi))) info(sprintf("  %s:%d tolerance %s, %d zeros", multi$fichier[i], multi$ligne[i], multi$tolerance[i], multi$n_zeros[i]))
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
# Marques `# zero_compense` orphelines : la ligne suivante n'est pas un appel de verifier_egal() qui porte un zero.
# (data.frame vide type en tete : sans fichier analyse, rbind(list()) vaudrait NULL)
vide <- data.frame(fichier = character(0), ligne = integer(0), stringsAsFactors = FALSE)
marques <- do.call(rbind, c(list(vide), marques))
portent <- if (is.null(res)) character(0) else {
  k <- res[res$appel == "verifier_egal" & res$zeros, ]
  paste(k$fichier, k$ligne)
}
appels_egal <- do.call(rbind, c(list(vide), appels_egal))
orphelines <- marques[!(paste(marques$fichier, marques$ligne + 1L) %in% portent), ]
info(sprintf("MARQUES zero_compense ORPHELINES (la ligne suivante n'est pas un appel de verifier_egal() qui porte un zero) : %d marques",
             nrow(orphelines)))
for (i in seq_len(nrow(orphelines))) {
  suivant <- paste(orphelines$fichier[i], orphelines$ligne[i] + 1L) %in% paste(appels_egal$fichier, appels_egal$ligne)
  info(sprintf("  %s:%d %s", orphelines$fichier[i], orphelines$ligne[i],
               if (suivant) "appel sans zero reel a tolerance > 0 (ou a tolerance 0)" else "aucun appel de verifier_egal() a la ligne suivante"))
}
quit(save = "no", status = if (.n_echec > 0L) 1L else 0L)
