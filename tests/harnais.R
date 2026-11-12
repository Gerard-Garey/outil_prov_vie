# Harnais de tests sans testthat (ADR 0010, point 25), sourcé par chaque batterie.
# Sortie : une ligne par vérification -- [OK], [ECHEC], [ATTENDU] (échec attendu, avec
# l'issue), [SUCCES INATTENDU] (un échec attendu qui réussit : la batterie échoue et la
# marque est alors retirée) -- puis, avec bilan(), le décompte et le statut de sortie ; les
# lignes [INFO] (informer()) sont hors décompte.
# Les batteries tournent avec options(warn = 2) : un avertissement fait échouer la
# vérification en cours.

# Le harnais refuse de tourner hors de options(warn = 2) : un avertissement non converti
# en erreur passerait inaperçu.
if (getOption("warn") < 2) {
  cat("[ECHEC] harnais : options(warn = 2) est requis avant de sourcer tests/harnais.R\n")
  quit(save = "no", status = 1L)
}

.harnais <- new.env(parent = emptyenv())
.harnais$compteurs <- c(ok = 0L, echec = 0L, attendu = 0L, inattendu = 0L)

.harnais_ligne <- function(etiquette, nom, detail = NULL) {
  cat(sprintf("[%s] %s%s\n", etiquette, nom,
              if (is.null(detail)) "" else paste0(" -- ", detail)))
}

.harnais_compter <- function(cle) {
  .harnais$compteurs[[cle]] <- .harnais$compteurs[[cle]] + 1L
}

# Évalue `expr` ; rend list(valeur = ..., erreur = NULL) ou list(valeur = NULL, erreur = e).
.harnais_evaluer <- function(expr) {
  tryCatch(list(valeur = expr, erreur = NULL),
           error = function(e) list(valeur = NULL, erreur = e))
}

.harnais_message <- function(e) {
  if (inherits(e, "refus_provie")) {
    paste0("refus ", e$motif, " : ", conditionMessage(e))
  } else {
    conditionMessage(e)
  }
}

section <- function(nom) {
  cat(sprintf("\n== %s ==\n", nom))
}

# `condition` doit valoir exactement TRUE (évaluée ici : une erreur ou un avertissement
# sous warn = 2 est un échec).
verifier <- function(nom, condition) {
  r <- .harnais_evaluer(condition)
  if (!is.null(r$erreur)) {
    .harnais_compter("echec")
    .harnais_ligne("ECHEC", nom, .harnais_message(r$erreur))
  } else if (isTRUE(r$valeur)) {
    .harnais_compter("ok")
    .harnais_ligne("OK", nom)
  } else {
    .harnais_compter("echec")
    .harnais_ligne("ECHEC", nom, "condition non vraie")
  }
  invisible(isTRUE(r$valeur) && is.null(r$erreur))
}

# tolerance = 0 : identical() ; sinon all.equal() à la tolérance relative donnée.
verifier_egal <- function(nom, obtenu, attendu, tolerance = 0) {
  r <- .harnais_evaluer({
    if (tolerance == 0) {
      if (identical(obtenu, attendu)) TRUE else paste(all.equal(obtenu, attendu), collapse = " ; ")
    } else {
      res <- all.equal(obtenu, attendu, tolerance = tolerance)
      if (isTRUE(res)) TRUE else paste(res, collapse = " ; ")
    }
  })
  if (!is.null(r$erreur)) {
    .harnais_compter("echec")
    .harnais_ligne("ECHEC", nom, .harnais_message(r$erreur))
  } else if (isTRUE(r$valeur)) {
    .harnais_compter("ok")
    .harnais_ligne("OK", nom)
  } else {
    .harnais_compter("echec")
    .harnais_ligne("ECHEC", nom, r$valeur)
  }
  invisible(isTRUE(r$valeur) && is.null(r$erreur))
}

# `expr` doit lever un refus d'appel (classe refus_provie) de motif `motif`.
verifier_refus <- function(nom, expr, motif) {
  r <- tryCatch({
    expr
    "aucun refus levé"
  }, refus_provie = function(e) {
    if (identical(e$motif, motif)) TRUE else paste0("motif ", e$motif, " au lieu de ", motif)
  }, error = function(e) paste0("autre erreur : ", conditionMessage(e)))
  if (isTRUE(r)) {
    .harnais_compter("ok")
    .harnais_ligne("OK", nom)
  } else {
    .harnais_compter("echec")
    .harnais_ligne("ECHEC", nom, r)
  }
  invisible(isTRUE(r))
}

# Défaut connu : `expr` doit échouer (valeur non vraie ou erreur), l'issue est citée. Si
# elle réussit, c'est un SUCCES INATTENDU, compté comme un échec de la batterie.
attendu_echec <- function(nom, issue, expr) {
  r <- .harnais_evaluer(expr)
  if (is.null(r$erreur) && isTRUE(r$valeur)) {
    .harnais_compter("inattendu")
    .harnais_ligne("SUCCES INATTENDU", nom, paste0("retirer la marque d'échec attendu (", issue, ")"))
  } else {
    .harnais_compter("attendu")
    .harnais_ligne("ATTENDU", nom, issue)
  }
  invisible(NULL)
}

# Ligne d'information hors décompte (ADR 0011, point 23) : [INFO], ni OK ni ECHEC ; mesure
# consignée sans devenir un critère (portabilité de l'empreinte du résultat).
informer <- function(nom, detail = NULL) {
  .harnais_ligne("INFO", nom, detail)
  invisible(NULL)
}

# Travail de f(...), mesure de complexité sans horloge (une durée dépend de la charge de la
# machine ; #35, #45) : somme des tailles des arguments (longueur, ou lignes x colonnes
# d'un data.frame) des appels, dans f, aux opérations de base de `ops` et aux fonctions de
# `sous`. Les opérations et les fonctions s'enveloppent dans une copie de f, dont
# l'environnement est un environnement fils de celui de f : seuls les appels écrits dans f,
# dans les copies de `sous` et dans les fonctions qu'ils définissent sont comptés. `sous`
# nomme des fonctions cherchées depuis l'environnement de f (ex. fonctions_de(ns)) ; elles
# sont appelées par la copie, à l'identique, après évaluation de leurs arguments. `&&`,
# paresseux, ne s'enveloppe pas. Choix de `ops` : une affectation `x[i] <- v` dans une boucle
# est faite en place (R base) ; ne compter `[<-` que si le coût recherché est celui de sa
# copie. Un appel avec un argument vide (`x[i, ]`) n'est pas enveloppable.
travail_de <- function(f, ..., ops = character(0), sous = character(0)) {
  travail <- 0
  taille <- function(x) if (is.data.frame(x)) nrow(x) * length(x) else length(x)
  compter <- function(a) travail <<- travail + sum(vapply(a, taille, 0))
  env <- new.env(parent = environment(f))
  for (nom in ops) {
    local({
      g <- get(nom, envir = baseenv())
      assign(nom, function(...) { compter(list(...)); g(...) }, envir = env)
    })
  }
  for (nom in sous) {
    local({
      g <- get(nom, envir = environment(f), mode = "function")
      environment(g) <- env
      assign(nom, function(...) { compter(list(...)); g(...) }, envir = env)
    })
  }
  environment(f) <- env
  f(...)
  travail
}

# Noms des fonctions (hors primitives) définies directement dans l'espace de noms `ns`.
fonctions_de <- function(ns) {
  noms <- ls(ns, all.names = TRUE)
  noms[vapply(noms, function(n) {
    g <- get(n, envir = ns)
    is.function(g) && !is.primitive(g) && identical(environment(g), ns)
  }, NA)]
}

# Décompte final ; quitte avec le statut 1 s'il y a un ECHEC ou un SUCCES INATTENDU.
bilan <- function() {
  k <- .harnais$compteurs
  cat(sprintf("\nBilan : %d OK, %d ECHEC, %d ATTENDU, %d SUCCES INATTENDU\n",
              k[["ok"]], k[["echec"]], k[["attendu"]], k[["inattendu"]]))
  if (k[["echec"]] + k[["inattendu"]] > 0L) quit(save = "no", status = 1L)
  invisible(k)
}

# Installe le package de la racine dans une bibliothèque temporaire, la place en tête de
# .libPaths() puis charge provie ; en cas d'échec de l'installation, arrête la batterie
# avec la sortie de R CMD INSTALL.
installer_provie <- function(racine) {
  bibliotheque <- file.path(tempdir(), "bibliotheque-provie")
  dir.create(bibliotheque, showWarnings = FALSE, recursive = TRUE)
  # sous options(warn = 2), le statut non nul de system2() deviendrait une erreur : le
  # statut est lu dans l'attribut de la sortie
  sortie <- suppressWarnings(system2(file.path(R.home("bin"), "R"),
                                     c("CMD", "INSTALL", "--no-docs", "--no-multiarch",
                                       paste0("--library=", shQuote(bibliotheque)),
                                       shQuote(racine)),
                                     stdout = TRUE, stderr = TRUE))
  statut <- attr(sortie, "status")
  if (!is.null(statut) && statut != 0L) {
    cat(sortie, sep = "\n")
    cat("[ECHEC] installation du package provie\n")
    quit(save = "no", status = 1L)
  }
  .libPaths(c(bibliotheque, .libPaths()))
  library(provie)
  invisible(bibliotheque)
}
