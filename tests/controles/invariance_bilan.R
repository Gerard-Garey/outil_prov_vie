# Controle : invariance du bilan de controler_base() sous inversion et permutation des lignes
# (#149 ; critere C131-1 de la specification `donnees` v1.7 : le bilan est identical() sous
# inversion et sous permutation des lignes de chaque table, pour CHAQUE appel de
# tests/unitaires/donnees.R). Principe 7 de CLAUDE.md : un controle mecanique est un script.
#
# Deroulement :
#   1. le package est installe (installer_provie) et charge ; la fonction controler_base() de
#      l'espace de noms de provie est remplacee, le temps de la collecte, par un enregistreur
#      qui garde les arguments de chaque appel et son issue (bilan, ou condition de refus), puis
#      appelle la fonction d'origine ; tests/unitaires/donnees.R est execute (sortie jetee : la
#      batterie unitaire est celle qui le juge) ; l'espace de noms est ensuite retabli ;
#   2. chaque appel est rejoue sur ses tables inversees (rev des lignes), puis sur ses tables
#      permutees (une permutation par table, sample.int sous la graine GRAINE + numero d'appel,
#      par outils::avec_graine : generateur fixe, graine locale explicite, etat du generateur
#      global retabli) ; les noms de lignes sont remis a leur valeur automatique ;
#   3. l'issue rejouee doit etre identical() a l'issue d'origine (un refus se compare par sa
#      classe, son message et ses champs, hors appel) ; echec au premier ecart de chaque passe,
#      avec le numero d'appel, les tailles des tables et la premiere composante differente.
# Duree (collecte, chaque passe), nombre d'appels, graine et version de R sont consignes en
# lignes [INFO]. Duree de l'ordre d'un quart d'heure (collecte, puis deux passes) : ce controle
# n'entre ni dans les batteries de CLAUDE.md ni dans circuit-technique.js (M603) ; il tourne
# dans son propre job de .github/workflows/ci.yml.
#
# Garde : tests/test_unitaires.R lance chaque tests/controles/*.R avec la racine en argument.
# Sans l'option --complet, ce script ne fait donc rien (une ligne [INFO], statut 0).
# Usage : Rscript tests/controles/invariance_bilan.R --complet [racine]
# Verification du controle lui-meme : lancer sur une copie du depot dont .cause_retenue() est
# rendue dependante de l'ordre des candidates (voir le compte rendu de #149) : echec attendu.

options(warn = 2)
GRAINE <- 20261115L

args <- commandArgs(TRUE)
complet <- "--complet" %in% args
positionnels <- args[!startsWith(args, "--")]
if (!complet) {
  cat("[INFO] invariance_bilan.R : controle long (hors batteries), lancer avec --complet\n")
  quit(save = "no", status = 0L)
}
if (length(positionnels)) {
  racine <- normalizePath(positionnels[1L], mustWork = TRUE)
} else {
  fichier <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  racine <- normalizePath(file.path(dirname(fichier), "..", ".."), mustWork = TRUE)
}
source(file.path(racine, "tests", "harnais.R"))

informer(sprintf("racine : %s ; %s ; graine locale : %d (graine + numero d'appel), generateur de avec_graine",
                 racine, R.version.string, GRAINE))
installer_provie(racine)
ns <- asNamespace("provie")
avec_graine <- get("avec_graine", envir = ns)

# --- 1. Collecte ------------------------------------------------------------------------

# Issue d'un appel : le bilan, ou, pour un refus, ses composantes hors appel (comparables).
issue_valeur <- function(valeur) list(bilan = valeur)
issue_erreur <- function(e) {
  list(refus = list(classe = class(e), message = conditionMessage(e),
                    champs = unclass(e)[setdiff(names(e), c("call", "message"))]))
}
issue <- function(expr) tryCatch(issue_valeur(expr), error = issue_erreur)

# L'enregistreur garde le corps de controler_base() et y ajoute, en tete, l'enregistrement des
# arguments et, a la sortie, celui de l'issue (returnValue() ; un refus est vu par un
# gestionnaire d'appel, qui ne l'intercepte pas : il remonte aux tests comme avant). Il n'a
# aucune variable libre hors base et espace de noms : plusieurs tests de donnees.R recopient les
# fonctions du package dans un autre environnement (copie_ns()), ou ils remplacent des fonctions
# internes par des espions ; seuls les appels de la fonction de l'espace de noms lui-meme
# (environment(sys.function()) identique a ns) sont enregistres, car le rejeu appelle la
# fonction d'origine. Un appel sans `arrete` (refus plan_incomplet) n'est pas enregistre.
origine <- get("controler_base", envir = ns)
noms_args <- names(formals(origine))
collecte <- new.env(parent = emptyenv())
collecte$appels <- list()
collecte$derniere <- NULL
sentinelle <- structure(list(), class = "sans_valeur")
collecte$ouvrir <- function(args) {
  collecte$appels[[length(collecte$appels) + 1L]] <- list(args = args, issue = NULL)
  collecte$derniere <- NULL
  length(collecte$appels)
}
collecte$noter <- function(e) collecte$derniere <- e
collecte$clore <- function(rang, valeur) {
  r <- if (identical(valeur, sentinelle)) issue_erreur(collecte$derniere) else issue_valeur(valeur)
  collecte$appels[[rang]]$issue <- r
  invisible(NULL)
}
enregistreur <- origine
body(enregistreur) <- bquote({
  .rang <- NULL
  if (!missing(arrete) && identical(environment(sys.function()), .(ns))) {
    .rang <- .(collecte$ouvrir)(list(donnees = donnees, arrete = arrete,
                                     declarations = declarations, conventions = conventions))
    on.exit(.(collecte$clore)(.rang, returnValue(.(sentinelle))))
  }
  withCallingHandlers(.(body(origine)), error = .(collecte$noter))
})
stopifnot(identical(noms_args, c("donnees", "arrete", "declarations", "conventions")))

t0 <- Sys.time()
unlockBinding("controler_base", ns)
assign("controler_base", enregistreur, envir = ns)
restaure <- function() {
  assign("controler_base", origine, envir = ns)
  lockBinding("controler_base", ns)
}
sortie_tests <- tryCatch({
  capture.output(source(file.path(racine, "tests", "unitaires", "donnees.R"),
                        local = new.env(parent = globalenv())))
}, finally = restaure())
# Un echec ou un succes inattendu (marque d'echec attendu devenue caduque) de la collecte est lu
# avant la remise a zero, qui l'effacerait.
n_echecs_tests <- .harnais$compteurs[["echec"]] + .harnais$compteurs[["inattendu"]]
.harnais$compteurs[] <- 0L
appels <- collecte$appels
informer(sprintf("collecte : %d appels de controler_base() dans tests/unitaires/donnees.R, %.0f s",
                 length(appels), as.numeric(difftime(Sys.time(), t0, units = "secs"))))
verifier("collecte : donnees.R s'execute sans verification en echec ni succes inattendu (la batterie le juge aussi)",
         n_echecs_tests == 0L)
verifier("collecte : au moins un appel enregistre", length(appels) > 0L)
verifier("collecte : toute issue est renseignee", all(vapply(appels, function(a) !is.null(a$issue), NA)))

# Etat du generateur global avant le rejeu (les tests de la collecte peuvent l'avoir touche) :
# le rejeu, qui tire ses permutations par avec_graine(), ne doit pas le faire bouger.
avait_graine <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
etat_initial <- if (avait_graine) get(".Random.seed", envir = globalenv()) else NULL

# --- 2. Rejeu ---------------------------------------------------------------------------

transformer <- function(donnees, mode, graine) {
  ordre <- function(n) if (mode == "inversion") rev(seq_len(n)) else sample.int(n)
  avec_graine(graine, {
    for (nom in names(donnees)) {
      x <- donnees[[nom]]
      if (!is.data.frame(x)) next
      x <- x[ordre(nrow(x)), , drop = FALSE]
      rownames(x) <- NULL
      donnees[[nom]] <- x
    }
    donnees
  })
}

premier_ecart <- function(a, b) {
  if (!is.null(a$refus) || !is.null(b$refus)) return("refus ou bilan different")
  for (nom in union(names(a$bilan), names(b$bilan))) {
    if (!identical(a$bilan[[nom]], b$bilan[[nom]])) return(paste0("composante `", nom, "` du bilan"))
  }
  "structure du bilan"
}

passe <- function(mode) {
  t1 <- Sys.time()
  echec <- NULL
  for (i in seq_along(appels)) {
    a <- appels[[i]]
    args <- a$args
    args$donnees <- transformer(args$donnees, mode, GRAINE + i)
    r <- issue(do.call(origine, args))
    if (!identical(r, a$issue)) {
      tailles <- vapply(a$args$donnees, function(x) if (is.data.frame(x)) nrow(x) else NA_integer_, 1L)
      echec <- sprintf("appel %d (%s) : %s ; lignes par table : %s", i, mode,
                       premier_ecart(a$issue, r),
                       paste(names(tailles), tailles, sep = "=", collapse = " "))
      break
    }
  }
  informer(sprintf("passe %s : %d appels rejoues, %.0f s", mode,
                   if (is.null(echec)) length(appels) else i,
                   as.numeric(difftime(Sys.time(), t1, units = "secs"))))
  verifier(sprintf("invariance du bilan sous %s des lignes, %d appels%s", mode, length(appels),
                   if (is.null(echec)) "" else paste0(" -- ", echec)), is.null(echec))
}
passe("inversion")
passe("permutation")

verifier("etat du generateur global retabli",
         identical(exists(".Random.seed", envir = globalenv(), inherits = FALSE), avait_graine) &&
           identical(if (avait_graine) get(".Random.seed", envir = globalenv()) else NULL, etat_initial))
informer(sprintf("duree totale : %.0f s", as.numeric(difftime(Sys.time(), t0, units = "secs"))))
bilan()
