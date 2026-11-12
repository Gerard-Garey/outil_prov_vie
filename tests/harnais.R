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

# tolerance = 0 : identical() ; sinon comparaison valeur par valeur au comparateur de
# l'ADR 0011, point 7 (comparer_objets, #79) : réels finis à la tolérance mixte
# |x - r| <= tolerance x max(1, |r|), toute différence de structure (type, longueur, NA contre
# NaN, infini contre fini, noms et autres attributs) en échec. Le message liste les premiers écarts.
# Pour |r| <= 1, la tolérance est absolue (|x - r| <= tolerance) : elle ne garantit un écart relatif
# de 1,5e-7 (plus petit effet de formule rencontré, ADR 0011, point 8) que pour |r| >= tolerance /
# 1,5e-7 (6,7e-4 à 1e-10). Consignes à l'appelant, le harnais ne les applique pas : pour garder un écart
# relatif de 1e-10 sur une valeur attendue scalaire ou homogène sous le seuil, passer
# tolerance = 1e-10 * |r| (le plus petit |r| non nul si elle a plusieurs valeurs) ; une valeur attendue
# nulle se compare à part, à tolérance nulle (avec tolerance > 0, un zéro attendu admet l'écart absolu
# tolerance x max(1, 0), il n'est pas comparé exactement) ; pour une valeur attendue qui mêle des ordres
# de grandeur (petites et grandes valeurs), tolerance = 1e-10 * min|r| rendrait la comparaison des
# grandes quasi exacte (r = c(1e-8, 1000) : un ulp sur 1000 échoue) : scinder l'appel par ordre de
# grandeur, ou comparer obtenu / r à 1 (avis d'actuary sur #79, jugement
# d'expert). La tolérance est un réel fini positif ou nul (NA, NaN, Inf et négatif sont refusés).
verifier_egal <- function(nom, obtenu, attendu, tolerance = 0) {
  r <- .harnais_evaluer({
    if (!is.numeric(tolerance) || length(tolerance) != 1L || !is.finite(tolerance) || tolerance < 0) {
      stop("tolerance : un réel fini positif ou nul est requis")
    }
    if (tolerance == 0) {
      if (identical(obtenu, attendu)) TRUE else paste(all.equal(obtenu, attendu), collapse = " ; ")
    } else {
      e <- comparer_objets(obtenu, attendu, tolerance)
      if (nrow(e) == 0L) TRUE else .harnais_ecarts(e)
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

# Texte d'échec de verifier_egal : les cinq premiers écarts (chemin, référence, obtenu, écart).
.harnais_ecarts <- function(e, n = 5L) {
  k <- seq_len(min(n, nrow(e)))
  ligne <- sprintf("%s%s : référence %s, obtenu %s%s [%s]",
                   ifelse(e$chemin == "", "(valeur)", e$chemin),
                   ifelse(is.na(e$cle) | e$cle == "", "", paste0("[", e$cle, "]")),
                   e$reference, e$obtenu,
                   ifelse(is.na(e$ecart), "", paste0(", écart ", e$ecart)), e$nature)[k]
  paste0(nrow(e), " écart(s) : ", paste(ligne, collapse = " ; "), if (nrow(e) > n) " ; ..." else "")
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

# --- Comparateur (ADR 0011, points 7 à 10) ; déplacé de tests/references.R (#79) -----------------
# Les fonctions de tests/references.R (comparer_couple, visa_requis) l'emploient ; verifier_egal()
# à tolérance s'y adosse (comparer_objets, plus bas) : une seule implémentation de la comparaison
# valeur par valeur.

.type_feuille <- function(x) {
  if (is.null(x)) return("null")
  if (inherits(x, "Date")) return("date")
  if (is.list(x)) return(if (length(x) == 0L) "liste" else "noeud")
  typeof(x)
}

.ecart_ligne <- function(chemin, cle, reference, obtenu, ecart, nature) {
  data.frame(chemin = chemin, cle = cle, reference = reference, obtenu = obtenu, ecart = ecart, nature = nature,
             stringsAsFactors = FALSE)
}

.texte <- function(x) {
  if (is.null(x)) return("NULL")
  if (inherits(x, "Date")) return(ifelse(is.na(x), "NA", format(x)))
  if (is.double(x)) return(ifelse(is.na(x) & !is.nan(x), "NA", sprintf("%.17g", x)))
  ifelse(is.na(x), "NA", as.character(x))
}

# Compare deux vecteurs atomiques de même type et de même longueur, élément par élément :
# égalité exacte (logical, integer, character, date) ; réels finis à la tolérance mixte ; NA,
# NaN, infinis : égalité de nature exacte (différence de structure sinon). `tolerance` : tolérance
# mixte |x - r| <= tolerance x max(1, |r|).
.comparer_valeurs <- function(chemin, obtenu, reference, cles, tolerance = EPS_REFERENCE) {
  if (is.double(reference) && !inherits(reference, "Date")) {
    x <- unclass(obtenu)
    r <- unclass(reference)
    nature_x <- ifelse(is.nan(x), "NaN", ifelse(is.na(x), "NA", ifelse(is.infinite(x), ifelse(x > 0, "Inf", "-Inf"), "fini")))
    nature_r <- ifelse(is.nan(r), "NaN", ifelse(is.na(r), "NA", ifelse(is.infinite(r), ifelse(r > 0, "Inf", "-Inf"), "fini")))
    structure_ <- nature_x != nature_r
    finis <- nature_x == "fini" & nature_r == "fini"
    hors <- rep(FALSE, length(x))
    hors[finis] <- abs(x[finis] - r[finis]) > tolerance * pmax(1, abs(r[finis]))
    k <- which(structure_ | hors)
    if (length(k) == 0L) return(NULL)
    return(.ecart_ligne(rep(chemin, length(k)), cles[k], .texte(r[k]), .texte(x[k]),
                        ifelse(finis[k], sprintf("%.17g", x[k] - r[k]), NA_character_),
                        ifelse(structure_[k], "structure", "valeur")))
  }
  diff <- !((is.na(obtenu) & is.na(reference)) | (!is.na(obtenu) & !is.na(reference) & obtenu == reference))
  k <- which(diff)
  if (length(k) == 0L) return(NULL)
  .ecart_ligne(rep(chemin, length(k)), cles[k], .texte(reference[k]), .texte(obtenu[k]), NA_character_,
               ifelse(is.na(obtenu[k]) | is.na(reference[k]), "structure", "valeur"))
}

# Lignes d'un data.frame représenté (liste de colonnes) alignées sur leurs clés : rend les
# écarts des lignes retirées ou ajoutées (nommées par leur clé) et des colonnes des lignes
# communes.
.comparer_table <- function(chemin, obtenu, reference, cles, tolerance = EPS_REFERENCE) {
  ecarts <- list()
  if (!identical(names(obtenu), names(reference))) {
    return(.ecart_ligne(chemin, NA_character_, paste(names(reference), collapse = ","),
                        paste(names(obtenu), collapse = ","), NA_character_, "structure"))
  }
  cle_de <- function(l) do.call(paste, c(lapply(cles, function(k) .texte(l[[k]])), sep = "|"))
  ko <- cle_de(obtenu)
  kr <- cle_de(reference)
  for (k in setdiff(kr, ko)) ecarts[[length(ecarts) + 1L]] <- .ecart_ligne(chemin, k, "ligne", "absente", NA_character_, "ligne_retiree")
  for (k in setdiff(ko, kr)) ecarts[[length(ecarts) + 1L]] <- .ecart_ligne(chemin, k, "absente", "ligne", NA_character_, "ligne_ajoutee")
  communes <- intersect(kr, ko)
  io <- match(communes, ko)
  ir <- match(communes, kr)
  for (n in names(reference)) {
    vo <- obtenu[[n]]
    vr <- reference[[n]]
    if (!identical(.type_feuille(vo), .type_feuille(vr))) {
      ecarts[[length(ecarts) + 1L]] <- .ecart_ligne(paste0(chemin, "/", n), NA_character_, .type_feuille(vr),
                                                    .type_feuille(vo), NA_character_, "structure")
      next
    }
    ecarts[[length(ecarts) + 1L]] <- .comparer_valeurs(paste0(chemin, "/", n), vo[io], vr[ir], communes, tolerance)
  }
  do.call(rbind, ecarts)
}

# Compare deux listes relues par lire_liste() (ADR 0011, point 7) : rend un data.frame d'écarts
# (chemin, cle, reference, obtenu, ecart, nature : structure, valeur, ligne_ajoutee,
# ligne_retiree), zéro ligne si tout concorde. `exclusions` : chemins (relatifs à la racine
# comparée) non comparés, sous-arbre compris ; `tables` : chemins des data.frame représentés à
# aligner sur des clés (liste nommée chemin -> colonnes de clé) ; `tolerance` : tolérance mixte des
# réels finis (défaut EPS_REFERENCE, défini par tests/references.R ; #79).
comparer_feuilles <- function(obtenu, reference, chemin = "", exclusions = character(0), tables = list(),
                              tolerance = EPS_REFERENCE) {
  vide <- .ecart_ligne(character(0), character(0), character(0), character(0), character(0), character(0))
  .comparer <- function(o, r, ch) {
    rel <- sub("^/", "", ch)
    if (rel %in% exclusions) return(NULL)
    if (rel %in% names(tables) && is.list(o) && is.list(r) && length(r) > 0L && length(o) > 0L) {
      return(.comparer_table(rel, o, r, tables[[rel]], tolerance))
    }
    to <- .type_feuille(o)
    tr <- .type_feuille(r)
    if (to != tr) return(.ecart_ligne(rel, NA_character_, tr, to, NA_character_, "structure"))
    if (tr == "noeud") {
      noms <- union(names(r), names(o))
      res <- lapply(noms, function(n) {
        sous <- paste0(ch, "/", n)
        if (sub("^/", "", sous) %in% exclusions) return(NULL)
        if (!(n %in% names(o))) return(.ecart_ligne(sub("^/", "", sous), NA_character_, "feuille", "absente", NA_character_, "structure"))
        if (!(n %in% names(r))) return(.ecart_ligne(sub("^/", "", sous), NA_character_, "absente", "feuille", NA_character_, "structure"))
        .comparer(o[[n]], r[[n]], sous)
      })
      return(do.call(rbind, res))
    }
    if (tr %in% c("null", "liste")) return(NULL)
    if (length(o) != length(r)) {
      return(.ecart_ligne(rel, NA_character_, paste("longueur", length(r)), paste("longueur", length(o)), NA_character_,
                          "structure"))
    }
    .comparer_valeurs(rel, o, r, as.character(seq_along(r)), tolerance)
  }
  res <- .comparer(obtenu, reference, chemin)
  if (is.null(res)) vide else { rownames(res) <- NULL; res }
}

# Compare deux objets quelconques valeur par valeur, à la tolérance mixte `tolerance` (#79) :
# rend, comme comparer_feuilles(), un data.frame d'écarts (zéro ligne si tout concorde). Les
# listes (dont les data.frame, par colonnes) se parcourent par position, nommées ou non ; les
# attributs (noms, classe, niveaux, dimensions...) se comparent exactement ; une différence de
# type (integer contre double, Date contre double), de longueur, de nature (NA, NaN, infini,
# fini) ou d'attribut est toujours un écart de structure ; il en va de même du `typeof` d'une
# feuille atomique (une Date stockée en entier contre une Date stockée en réel). Seuls les réels
# finis se comparent à la tolérance ; les autres feuilles (logical, integer, character) et toute
# classe temporelle (Date, POSIXct, POSIXlt, difftime) à l'égalité exacte.
comparer_objets <- function(obtenu, attendu, tolerance) {
  ecarts <- list()
  ajouter <- function(e) if (!is.null(e) && nrow(e) > 0L) ecarts[[length(ecarts) + 1L]] <<- e
  # Description d'une valeur dans le message d'échec : les `n` premiers éléments d'un vecteur, puis
  # leur nombre (un attribut de 1e5 éléments, row.names ou names, n'est pas sérialisé en entier).
  descr <- function(x, n = 10L) {
    if (is.atomic(x) && !is.null(x)) {
      debut <- paste(.texte(x[seq_len(min(n, length(x)))]), collapse = ",")
      if (length(x) > n) sprintf("%s,… (%d valeurs)", debut, length(x)) else debut
    } else {
      paste(class(x), collapse = "/")
    }
  }
  temporel <- function(x) inherits(x, c("Date", "POSIXct", "POSIXlt", "difftime"))
  attributs <- function(o, r, ch) {
    ao <- attributes(o)
    ar <- attributes(r)
    for (n in sort(as.character(union(names(ao), names(ar))), method = "radix")) {
      if (!identical(ao[[n]], ar[[n]])) {
        ajouter(.ecart_ligne(paste0(ch, "@", n), NA_character_, descr(ar[[n]]), descr(ao[[n]]), NA_character_, "structure"))
      }
    }
  }
  parcourir <- function(o, r, ch, tol = tolerance) {
    to <- .type_feuille(o)
    tr <- .type_feuille(r)
    if (to != tr) return(ajouter(.ecart_ligne(ch, NA_character_, tr, to, NA_character_, "structure")))
    if (tr == "null") return(invisible(NULL))
    if (temporel(o) || temporel(r)) tol <- 0
    if (is.atomic(r) && typeof(o) != typeof(r)) {
      return(ajouter(.ecart_ligne(ch, NA_character_, typeof(r), typeof(o), NA_character_, "structure")))
    }
    attributs(o, r, ch)
    # POSIXlt : [[ rend un POSIXlt (récursion sans fin) ; on parcourt ses composantes brutes
    if (inherits(r, "POSIXlt")) { o <- unclass(o); r <- unclass(r) }
    if (is.list(r)) {
      if (length(o) != length(r)) {
        return(ajouter(.ecart_ligne(ch, NA_character_, paste("longueur", length(r)), paste("longueur", length(o)),
                                    NA_character_, "structure")))
      }
      noms <- names(r)
      for (i in seq_along(r)) {
        nom_i <- if (is.null(noms) || is.na(noms[i]) || noms[i] == "") as.character(i) else noms[i]
        parcourir(o[[i]], r[[i]], if (ch == "") nom_i else paste0(ch, "/", nom_i), tol)
      }
      return(invisible(NULL))
    }
    if (!is.atomic(r)) {
      if (!identical(o, r)) ajouter(.ecart_ligne(ch, NA_character_, descr(r), descr(o), NA_character_, "structure"))
      return(invisible(NULL))
    }
    if (length(o) != length(r)) {
      return(ajouter(.ecart_ligne(ch, NA_character_, paste("longueur", length(r)), paste("longueur", length(o)),
                                  NA_character_, "structure")))
    }
    if (!inherits(r, "Date")) { o <- unclass(o); r <- unclass(r) }
    for (a in c("names", "dim", "dimnames")) { attr(o, a) <- NULL; attr(r, a) <- NULL }
    ajouter(.comparer_valeurs(ch, o, r, as.character(seq_along(r)), tol))
  }
  parcourir(obtenu, attendu, "")
  if (length(ecarts) == 0L) {
    return(.ecart_ligne(character(0), character(0), character(0), character(0), character(0), character(0)))
  }
  res <- do.call(rbind, ecarts)
  rownames(res) <- NULL
  res
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
