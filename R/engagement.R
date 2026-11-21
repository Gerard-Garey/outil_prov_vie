# Module `engagement` (ADR 0005, point 5 ; ADR 0010, points 1, 6 et 14 ; spécification de B2,
# docs/specifications/b2-capital-deces-v1.md, § 5.1 à § 5.4) : famille de calcul
# « engagement » du capital décès en comptes sociaux (P1 sinistres déclarés non réglés, P2
# capitaux non réclamés), revalorisation légale (facteur_revalorisation(), seule
# implémentation) et valeur actuelle probable d'un échéancier (valeur_actuelle_probable(),
# seule fonction de valeur actuelle probable du package, appelée aussi par
# `risque_en_cours`).
# N'appelle que les modules `tables`, `garanties`, `donnees` et `outils` (graphe du point 1),
# et seulement leurs fonctions sans point. Lit la vue à l'arrêté (vue_a_date()), jamais la
# base brute. Ne parle pas (point 12). Code ASCII hors commentaires (M112).
# Convention de ce fichier : une fonction dont le nom commence par un point est un
# auxiliaire du module ; la concordance documentation <-> code ne recense que les autres.

# --- Constantes ------------------------------------------------------------------

# Colonnes des éléments rendus par une famille de calcul (ADR 0010, point 6, annoté par la
# spécification de B2, § 9, point 6 : `cle` et `type_flux` dans l'échéancier), dans cet ordre ;
# lues aussi par `risque_en_cours`.
COLONNES_CELLULES <- c("garantie", "referentiel", "poste", "famille", "provision", "segmentation", "segment",
                       "niveau", "montant", "nombre_dossiers", "methode", "statut_methode", "statut_resultat",
                       "statut_calcul", "motif_arret")
COLONNES_DOSSIERS <- c("id_dossier", "id_sinistre", "garantie", "referentiel", "poste", "etat", "date_entree_etat",
                       "montant", "methode", "statut_resultat", "hypotheses_defaut")
COLONNES_ECHEANCIERS <- c("cle", "referentiel", "poste", "date", "etat", "type_flux", "flux", "probabilite",
                          "actualisation", "valeur_actuelle")
# Statuts de résultat lus en B2, du plus fort au plus faible (le statut d'une cellule est le
# plus faible de ses dossiers ou contrats, spécification de B2, § 7.7) ; lus par
# statut_le_plus_faible() seule, que `risque_en_cours` et `calculer_provisions` appellent.
STATUTS_RESULTAT_B2 <- c("exact", "approximation_numerique", "jugement_expert")
# Types d'actualisation admis par valeur_actuelle_probable() en B2 (spécification de B2,
# § 5.2 ; la courbe entre en B6 sans changer la signature).
TYPES_ACTUALISATION <- c("aucune", "taux")
TYPES_FLUX_ECHEANCIER <- c("capital_unique", "prime_periodique", "frais")
# Postes de la famille et méthodes (spécification de B2, § 5.4) : horizon de la revalorisation.
.POSTES_ENGAGEMENT <- c("sinistres_declares_non_regles", "capitaux_non_reclames")
.HORIZONS <- c(capital_dossier = "arrete", capital_revalorise = "arrete", capital_dossier_reglement = "reglement",
               capital_revalorise_reglement = "depot")
# Dépôt à la Caisse des dépôts et consignations dix ans après la connaissance du décès
# (L132-27-2, I, vérifié en 0a) ; décès antérieur au 1er janvier 2015 : sans dépôt légal
# (horizon déclaré, duree_sans_depot_annees).
.ANNEES_DEPOT_CDC <- 10L
.DEBUT_DEPOT_LEGAL <- as.Date("2015-01-01")
.REFERENTIEL_B2 <- "comptes_sociaux"

# --- Durées et revalorisation -------------------------------------------------------

# Parts annuelles de l'intervalle (début, fin] (dates en fin de journée, spécification de B2,
# § 2.5) : pour chaque paire i et chaque année civile y qui coupe l'intervalle, j_y = min(fin ;
# 31/12/y) - max(début ; 31/12/(y - 1)) jours (> 0) et J_y (longueur de l'année y en
# `exact_exact`, 365 en `exact_365`). Seul découpage du package, lu par duree_annees() et par
# facteur_revalorisation() (le même découpage rend exact le recoupement du critère 3.13).
.parts_annuelles <- function(debut, fin, decompte) {
  a <- as.numeric(debut)
  b <- as.numeric(fin)
  vide <- list(i = integer(0), annee = integer(0), jours = numeric(0), longueur = numeric(0))
  if (length(a) == 0L) return(vide)
  ya <- as.POSIXlt(structure(a, class = "Date"))$year + 1900L
  yb <- as.POSIXlt(structure(b, class = "Date"))$year + 1900L
  n <- yb - ya + 1L
  i <- rep(seq_along(a), n)
  y <- ya[i] + sequence(n) - 1L
  # 31 décembre de y et de y - 1, sans chaîne ni as.Date (le 1er janvier de y est
  # 12 (y - 1970) mois après 1970-01-01, jour 0)
  fin_y <- ajouter_mois(0, 12L * (y + 1L - 1970L)) - 1
  debut_y <- ajouter_mois(0, 12L * (y - 1970L)) - 1
  jours <- pmin(b[i], fin_y) - pmax(a[i], debut_y)
  garde <- jours > 0
  longueur <- if (decompte == "exact_exact") fin_y - debut_y else rep(365, length(y))
  list(i = i[garde], annee = y[garde], jours = jours[garde], longueur = longueur[garde])
}

.controler_dates <- function(x, nom, fonction) {
  if (!identical(class(x), "Date") || anyNA(x)) {
    stop(paste0(fonction, "() : `", nom, "` doit \u00eatre un vecteur de Date renseign\u00e9"), call. = FALSE)
  }
  invisible(NULL)
}

.decompte <- function(conventions, fonction) {
  d <- conventions$decompte_jours
  if (!(is.character(d) && length(d) == 1L && !is.na(d) && d %in% c("exact_exact", "exact_365"))) {
    stop(paste0(fonction, "() : conventions$decompte_jours doit valoir exact_exact ou exact_365"), call. = FALSE)
  }
  d
}

# Durée en années de `debut` à `fin` (vecteurs de Date de même longueur, ou l'un de longueur
# 1) selon conventions$decompte_jours (spécification de B2, § 2.6) : `exact_exact`, somme sur
# les années civiles des j_y / J_y (.parts_annuelles()) ; `exact_365`, jours / 365. Négative si
# `fin` précède `debut`. Sans point : lue par `risque_en_cours` (fraction écoulée d'un pas) ;
# non exportée.
duree_annees <- function(debut, fin, conventions) {
  .controler_dates(debut, "debut", "duree_annees")
  .controler_dates(fin, "fin", "duree_annees")
  decompte <- .decompte(conventions, "duree_annees")
  n <- max(length(debut), length(fin))
  if (!(length(debut) %in% c(1L, n)) || !(length(fin) %in% c(1L, n))) {
    stop("duree_annees() : longueurs incompatibles", call. = FALSE)
  }
  a <- rep_len(as.numeric(debut), n)
  b <- rep_len(as.numeric(fin), n)
  signe <- ifelse(b < a, -1, 1)
  bas <- structure(pmin(a, b), class = "Date")
  haut <- structure(pmax(a, b), class = "Date")
  if (decompte == "exact_365") return(signe * (as.numeric(haut) - as.numeric(bas)) / 365)
  p <- .parts_annuelles(bas, haut, decompte)
  res <- rep(0, n)
  if (length(p$i)) {
    s <- vapply(split(p$jours / p$longueur, factor(p$i, levels = seq_len(n))), sum, 0)
    res <- unname(s)
  }
  signe * res
}

# Facteur de revalorisation légale de `debut` à `fin` (dates en fin de journée ; spécification
# de B2, § 2.5 et § 5.4), vectorisé sur les paires (début, fin] (même longueur, ou l'un de
# longueur 1 ; début au plus fin) : produit, sur les années civiles y qui coupent
# l'intervalle, de 1 + r_y j_y / J_y (`prorata` = "simple") ou (1 + r_y)^(j_y / J_y)
# ("compose"), J_y selon conventions$decompte_jours ; r_y = taux_par_annee[y] (noms : années
# sur quatre chiffres), ou `taux_futur` pour une année postérieure à la dernière année
# déclarée et à l'année de l'arrêté `arrete` ; `taux_futur` NULL : non déclaré. Une année
# manquante que taux_futur ne couvre pas est un refus plan_incomplet qui nomme l'année.
# Statut : exact sous les taux déclarés. Seule implémentation du package (reprise par
# cout_moyen_capital en B3). Sans point : non exportée ; l'argument `arrete`, absent de la
# signature du § 5.4, porte la règle « postérieure à l'arrêté » de taux_futur.
facteur_revalorisation <- function(debut, fin, taux_par_annee, prorata, conventions, arrete, taux_futur) {
  .controler_dates(debut, "debut", "facteur_revalorisation")
  .controler_dates(fin, "fin", "facteur_revalorisation")
  .controler_dates(arrete, "arrete", "facteur_revalorisation")
  decompte <- .decompte(conventions, "facteur_revalorisation")
  if (!(is.character(prorata) && length(prorata) == 1L && prorata %in% c("simple", "compose"))) {
    stop("facteur_revalorisation() : `prorata` doit valoir simple ou compose", call. = FALSE)
  }
  if (!is.double(taux_par_annee) || is.null(names(taux_par_annee)) || anyNA(taux_par_annee) ||
      !all(grepl("^[0-9]{4}$", names(taux_par_annee)))) {
    stop("facteur_revalorisation() : `taux_par_annee` doit \u00eatre un double nomm\u00e9 par ann\u00e9e", call. = FALSE)
  }
  if (!is.null(taux_futur) && !(is.double(taux_futur) && length(taux_futur) == 1L && is.finite(taux_futur))) {
    stop("facteur_revalorisation() : `taux_futur` doit \u00eatre un double fini ou NULL", call. = FALSE)
  }
  n <- max(length(debut), length(fin))
  if (!(length(debut) %in% c(1L, n)) || !(length(fin) %in% c(1L, n))) {
    stop("facteur_revalorisation() : longueurs incompatibles", call. = FALSE)
  }
  debut <- structure(rep_len(as.numeric(debut), n), class = "Date")
  fin <- structure(rep_len(as.numeric(fin), n), class = "Date")
  if (any(as.numeric(fin) < as.numeric(debut))) {
    stop("facteur_revalorisation() : `fin` ant\u00e9rieure \u00e0 `debut`", call. = FALSE)
  }
  p <- .parts_annuelles(debut, fin, decompte)
  if (length(p$i) == 0L) return(rep(1, n))
  annees <- as.integer(names(taux_par_annee))
  annee_arrete <- as.POSIXlt(arrete)$year + 1900L
  r <- unname(taux_par_annee[as.character(p$annee)])
  manque <- is.na(r)
  futur <- manque & p$annee > max(annees) & p$annee > annee_arrete
  if (!is.null(taux_futur)) r[futur] <- taux_futur
  manque <- is.na(r)
  if (any(manque)) {
    y <- min(p$annee[manque])
    refuser(paste0("plan : revalorisation$capital_deces$taux_par_annee ne couvre pas l'ann\u00e9e ", y,
                   if (y > annee_arrete && y > max(annees)) " (taux_futur non d\u00e9clar\u00e9)" else ""),
            "plan_incomplet", module = "engagement", attendu = paste0("revalorisation$capital_deces$taux_par_annee$", y))
  }
  f <- if (prorata == "simple") 1 + r * p$jours / p$longueur else (1 + r)^(p$jours / p$longueur)
  res <- rep(1, n)
  produits <- vapply(split(f, factor(p$i, levels = seq_len(n))), prod, 0)
  res[] <- unname(produits)
  res
}

# --- Valeur actuelle probable ------------------------------------------------------

# Seule fonction de valeur actuelle probable du package (ADR 0010, point 14 ; spécification de
# B2, § 5.2 ; une méthode, une implémentation, ADR 0005, point 3), appelée par P1, P2 et P3.
# `echeancier` : data.frame long (cle, date (Date), etat, type_flux (TYPES_FLUX_ECHEANCIER),
# flux (euros, signé : engagement de l'organisme positif, prime de l'assuré négative),
# probabilite dans [0 ; 1]) ; `actualisation` : list(type = "aucune") (valeur nominale) ou
# list(type = "taux", taux = <double>, origine = <Date>) : facteur (1 + taux)^(-t), t =
# duree_annees(origine, date) ; une ligne de date au plus l'origine est une erreur de
# programmation (l'appelant date ses flux après l'arrêté). Rend list(echeancier : l'échéancier
# complété des colonnes `actualisation` (facteur) et `valeur_actuelle` = flux x probabilite x
# facteur ; valeurs : data.frame (cle, valeur_actuelle), somme par clé dans l'ordre de première
# apparition). Statut : exact (somme finie). Sans point : appelée aussi par
# `risque_en_cours`, non exportée.
valeur_actuelle_probable <- function(echeancier, actualisation, conventions) {
  colonnes <- c("cle", "date", "etat", "type_flux", "flux", "probabilite")
  if (!is.data.frame(echeancier) || !all(colonnes %in% names(echeancier))) {
    stop(paste0("valeur_actuelle_probable() : `echeancier` doit porter les colonnes ", paste(colonnes, collapse = ", ")),
         call. = FALSE)
  }
  if (!identical(class(echeancier$date), "Date") || anyNA(echeancier$date) || !is.double(echeancier$flux) ||
      anyNA(echeancier$flux) || !is.double(echeancier$probabilite) || anyNA(echeancier$probabilite) ||
      any(echeancier$probabilite < 0 | echeancier$probabilite > 1) ||
      !all(echeancier$type_flux %in% TYPES_FLUX_ECHEANCIER)) {
    stop("valeur_actuelle_probable() : dates, flux, probabilit\u00e9s ou types de flux invalides", call. = FALSE)
  }
  if (!is.list(actualisation) || !(is.character(actualisation$type) && length(actualisation$type) == 1L &&
                                    actualisation$type %in% TYPES_ACTUALISATION)) {
    stop(paste0("valeur_actuelle_probable() : `actualisation$type` dans ", paste(TYPES_ACTUALISATION, collapse = ", ")),
         call. = FALSE)
  }
  n <- nrow(echeancier)
  facteur <- rep(1, n)
  if (actualisation$type == "taux") {
    taux <- actualisation$taux
    origine <- actualisation$origine
    if (!(is.double(taux) && length(taux) == 1L && is.finite(taux) && taux > -1)) {
      stop("valeur_actuelle_probable() : `actualisation$taux` doit \u00eatre un double fini > -1", call. = FALSE)
    }
    .controler_dates(origine, "actualisation$origine", "valeur_actuelle_probable")
    if (length(origine) != 1L) stop("valeur_actuelle_probable() : une seule origine", call. = FALSE)
    if (any(as.numeric(echeancier$date) <= as.numeric(origine))) {
      stop("erreur interne de provie : valeur_actuelle_probable() : flux dat\u00e9 au plus l'origine", call. = FALSE)
    }
    if (n > 0L) facteur <- (1 + taux)^(-duree_annees(origine, echeancier$date, conventions))
  } else if (actualisation$type != "aucune") {
    # type admis par TYPES_ACTUALISATION sans branche : jamais un facteur 1 par défaut
    stop("erreur interne de provie : valeur_actuelle_probable() : type d'actualisation ", actualisation$type,
         " sans branche de calcul", call. = FALSE)
  }
  echeancier$actualisation <- facteur
  echeancier$valeur_actuelle <- echeancier$flux * echeancier$probabilite * facteur
  cles <- unique(as.character(echeancier$cle))
  somme <- vapply(split(echeancier$valeur_actuelle, factor(as.character(echeancier$cle), levels = cles)), sum, 0)
  list(echeancier = echeancier,
       valeurs = data.frame(cle = cles, valeur_actuelle = unname(somme), stringsAsFactors = FALSE))
}

# --- Capital décès d'un dossier -----------------------------------------------------

# Paramètre `nom` de chaque garantie souscrite `gs` (identifiants), dans la vue : valeur
# unique, NA s'il manque ; `ambigu` s'il porte plusieurs valeurs distinctes (aucune n'est
# choisie) ; si `famille` (famille de calcul) est donnée, `exclu` : une ligne retenue du
# paramètre pour la garantie souscrite est exclue pour cette famille (vue$exclu[[famille]]
# $parametres ; spécification de B2, § 5.3, erratum v1.0.7 ; § 5.5, erratum v1.0.9). Sans
# point : seule lecture des paramètres d'une garantie souscrite, lue aussi par
# `risque_en_cours` (famille « risque_en_cours ») ; non exportée.
parametre_vue <- function(vue, nom, gs, famille = NULL) {
  id <- valeurs_vue(vue, "parametres", "id_garantie_souscrite")
  # une clé manquante ou vide ne s'apparie à rien, d'un côté comme de l'autre (apparier_cles(), #158)
  k <- which(valeurs_vue(vue, "parametres", "parametre") %in% nom & cle_renseignee(id))
  z <- lapply(split(valeurs_vue(vue, "parametres", "valeur")[k], as.character(id[k])), unique)
  i <- apparier_cles(gs, names(z))
  n <- lengths(z, use.names = FALSE)[i]
  valeur <- vapply(z, function(x) if (length(x) == 1L) as.numeric(x) else NA_real_, 0, USE.NAMES = FALSE)[i]
  res <- list(valeur = valeur, ambigu = !is.na(i) & n > 1L)
  if (!is.null(famille)) {
    res$exclu <- !is.na(apparier_cles(gs, id[k][vue$exclu[[famille]]$parametres[k]]))
  }
  res
}

# Valeurs (chaînes) de l'hypothèse du motif `motif` placée par la vue (vue$hypotheses ; ADR
# 0010, point 9) pour le référentiel `referentiel` et chaque ligne de `lignes` (indices) de la
# table `table`, lue par le poste `poste` : hypothèse du poste de préférence à celle de `tous`,
# puis la première placée (spécification de B2, § 5.5, D03h ; § 5.9, D03c) ; NA pour une ligne
# sans hypothèse appliquée. `colonnes` : NULL (toute hypothèse de la ligne), ou colonnes de la
# table lues par le poste : seules comptent les hypothèses dont une colonne (`colonnes` de
# l'entrée de vue$hypotheses) en fait partie (garde du point 1 de #112, M661 ; spécification
# `donnees` v1.9, § 9.4). Ne contrôle pas la forme de la valeur, contrôlée au plan par
# lire_declarations() (`donnees`, erratum v1.0.21, § 2.3, #99). Sans point : seule sélection
# d'une hypothèse par ligne, lue aussi par `risque_en_cours` (D03h) ; non exportée.
hypothese_vue <- function(vue, motif, referentiel, table, lignes, poste, colonnes = NULL) {
  h <- Filter(function(x) x$motif == motif && x$referentiel == referentiel && x$table == table &&
                x$poste %in% c(poste, "tous") && (is.null(colonnes) || any(x$colonnes %in% colonnes)), vue$hypotheses)
  res <- rep(NA_character_, length(lignes))
  postes <- vapply(h, `[[`, "", "poste")
  # priorité décroissante ; affectées de la plus faible à la plus forte, qui l'emporte
  ordre <- c(which(postes == poste), which(postes != poste))
  for (j in rev(ordre)) res[lignes %in% h[[j]]$lignes] <- h[[j]]$valeur
  res
}

# Motifs des hypothèses appliquées par la vue (spécification de B2, § 5.8, source S2 : D02b,
# D03g ; D02a, dates rejetées tenues pour inconnues, spécification `donnees` v1.9, § 9.4, #90).
.MOTIFS_HYPOTHESE_VUE <- c("D02a", "D02b", "D03g")

# Codes des hypothèses appliquées par la vue (source S2 du § 5.8, erratum v1.0.17, #87 ;
# décisions E16-4, E17-1 et E17-3) aux lignes lues pour chacune des `n` unités d'un poste de la
# famille `famille` : `lectures`, liste d'éléments de lecture_unites(). Une ligne compte si elle
# figure parmi les lignes d'une hypothèse d'un motif de .MOTIFS_HYPOTHESE_VUE placée pour
# `referentiel` et le poste `poste` ou `tous` (hypothese_vue(), seule sélection), qu'elle l'ait
# rendue visible ou invisible (provenance, non effet), si elle n'est pas exclue pour la famille
# (vue$exclu[[famille]] : une ligne exclue n'est pas lue) et si elle est admise par la lecture ;
# elle est rattachée à une unité par ses clés, lues par cles_lignes_hypothese() (`donnees`),
# seul accès aux clés d'une ligne cachée ; une clé qui ne rattache la ligne à aucune unité ne
# produit rien. Rend un character de longueur `n` : codes de l'unité joints par
# joindre_codes(), "" sans hypothèse. Sans point : seule détection de S2, lue aussi par
# `risque_en_cours` (P3) ; non exportée.
hypotheses_vue_unites <- function(vue, referentiel, poste, famille, n, lectures) {
  unite <- integer(0)
  code <- character(0)
  for (l in lectures) {
    nt <- length(valeurs_vue(vue, l$table, l$colonnes[1L]))
    exclu <- vue$exclu[[famille]][[l$table]]
    if (is.null(exclu)) exclu <- rep(FALSE, nt)
    par_cle <- split(seq_along(l$cles), l$cles)
    for (m in .MOTIFS_HYPOTHESE_VUE) {
      placees <- which(!is.na(hypothese_vue(vue, m, referentiel, l$table, seq_len(nt), poste, l$lues)))
      placees <- placees[!exclu[placees] & (if (is.null(l$admises)) TRUE else l$admises[placees])]
      if (length(placees) == 0L || length(l$cles) == 0L) next
      k <- lapply(l$colonnes, function(c1) as.character(cles_lignes_hypothese(vue, l$table, placees, c1)))
      # une composante manquante ou vide ne rattache rien (cle_renseignee(), #158) : la clé composée
      # est jointe après ce filtre, la jointure par « \r » rendant une composante vide non détectable
      connue <- Reduce(`&`, lapply(k, cle_renseignee))
      cle <- do.call(paste, c(k, sep = "\r"))[connue]
      j <- unlist(par_cle[cle], use.names = FALSE)
      unite <- c(unite, l$unite[j])
      code <- c(code, rep(m, length(j)))
    }
  }
  par_unite <- split(code, factor(unite, levels = seq_len(n)))
  joindre_codes(vapply(par_unite, paste, "", collapse = ";", USE.NAMES = FALSE))
}

# Unités d'un poste qui lisent une ligne refusée de portée ligne (règle d'arrêt par unité,
# condition (2) : spécification `donnees` v1.9, § 9.2 ; erratum du projet de dictionnaire 1.6,
# § 2 et § 11.5, #72) : `lectures` (éléments de lecture_unites() : lignes lues par unité du § 5.8
# de la spécification de B2), `table`, `refusees` (logique sur les lignes de `table`,
# lignes_refus_ligne_vue() de `donnees`). Une ligne refusée compte si elle est retenue à
# l'arrêté (une ligne hors de la vue n'est pas lue par le calcul ; ses clés ne sont pas
# lisibles, valeurs_vue()), non exclue pour la famille `famille` et admise par la lecture ; elle
# est rattachée à une unité par ses clés (une clé manquante ou vide ne rattache rien,
# cle_renseignee(), #158). Rend un logique de longueur `n`. Sans point : seule détection de la
# condition (2), lue aussi par `risque_en_cours` (P3) ; non exportée.
refus_ligne_unites <- function(vue, famille, n, lectures, table, refusees) {
  res <- rep(FALSE, n)
  exclu <- vue$exclu[[famille]][[table]]
  if (is.null(exclu)) exclu <- rep(FALSE, length(refusees))
  for (l in lectures) {
    if (l$table != table || length(l$cles) == 0L) next
    k <- which(refusees & vue$retenu[[table]] & !exclu & (if (is.null(l$admises)) TRUE else l$admises))
    if (length(k) == 0L) next
    cles <- lapply(l$colonnes, function(c1) as.character(valeurs_vue(vue, table, c1)[k]))
    connue <- Reduce(`&`, lapply(cles, cle_renseignee))
    cle <- do.call(paste, c(cles, sep = "\r"))[connue]
    res[l$unite[!is.na(apparier_cles(l$cles, cle))]] <- TRUE
  }
  res
}

# Arrêt d'un poste par les lignes de portée ligne de refus_tables (règle d'arrêt par unité ;
# spécification `donnees` v1.9, § 9.2 ; erratum du projet de dictionnaire 1.6, § 11.5, #72) :
# `pa` (postes_a_arreter() : refus_tables et candidats, condition (1) : le poste lit la colonne),
# `cle` (« garantie/poste »), `famille`, `n` unités d'identifiants `ids`, `lectures` (lignes lues
# par unité, lecture_unites()) ; `listees` : tables pour lesquelles la famille établit les lignes
# lues par unité ; `evaluees` : celles qu'établissent les `lectures` de cet appel (les autres
# tables listées sont évaluées par un autre appel). Une ligne candidate arrête le poste si une de
# ses lignes refusées est lue pour une unité (refus_ligne_unites()) ; sur une table hors de
# `listees`, le rattachement à une unité n'est pas établi : elle l'arrête (`repli`), sans
# identifiant. Rend list(lignes : indices dans refus_tables des lignes qui arrêtent le poste,
# dans l'ordre du bilan ; motif : motif de la première, NA sans arrêt ; identifiant : plus petit
# identifiant des unités en cause pour cette ligne (tri radix : indépendant de l'ordre des lignes
# de la base), NA sans arrêt ou sans rattachement établi). Sans point : seule
# implémentation de l'arrêt par unité, lue aussi par `risque_en_cours` (P3) ; non exportée.
arret_refus_ligne <- function(vue, pa, cle, famille, n, lectures, ids, listees, evaluees = listees, repli = TRUE) {
  rt <- pa$refus_tables
  lignes <- integer(0)
  identifiant <- character(0)
  for (i in seq_len(nrow(rt))) {
    if (!(cle %in% pa$candidats[[i]])) next
    t <- rt$table[i]
    if (!(t %in% listees)) {
      if (repli) {
        lignes <- c(lignes, i)
        identifiant <- c(identifiant, NA_character_)
      }
      next
    }
    if (!(t %in% evaluees)) next
    u <- refus_ligne_unites(vue, famille, n, lectures, t, lignes_refus_ligne_vue(vue, t, rt$colonne[i], rt$motif[i]))
    if (any(u)) {
      lignes <- c(lignes, i)
      identifiant <- c(identifiant, sort(as.character(ids[u]), method = "radix")[1L])
    }
  }
  list(lignes = lignes, motif = if (length(lignes)) rt$motif[lignes[1L]] else NA_character_,
       identifiant = if (length(lignes)) identifiant[1L] else NA_character_)
}

# Codes d'hypothèse d'unités (§ 5.3 et § 5.8) : chaque argument est un character de même
# longueur (une valeur par unité, codes joints par « ; », "" sans code), sources S1 et S2
# réunies (« ou ») ; rend, par unité, les codes uniques, triés (method = "radix"), joints par
# « ; », "" sans code. Sans point : seule réunion des codes d'une unité, lue par
# calculer_engagement() (hypotheses_defaut, statut, unité à montant nul) et par
# `risque_en_cours` (statut des contrats de P3) ; non exportée.
joindre_codes <- function(...) {
  x <- list(...)
  n <- length(x[[1L]])
  if (any(lengths(x) != n)) stop("erreur interne de provie : joindre_codes() : longueurs incompatibles", call. = FALSE)
  vapply(seq_len(n), function(i) {
    k <- unlist(strsplit(vapply(x, function(v) as.character(v[i]), ""), ";", fixed = TRUE), use.names = FALSE)
    paste(sort(unique(k[nzchar(k)]), method = "radix"), collapse = ";")
  }, "")
}

# Lecture d'une table pour la détection S2 (§ 5.8) : `table`, `colonnes` (une colonne de clé du
# dictionnaire, ou deux pour une clé composée), `cles` (clé lue, colonnes jointes par un retour
# chariot, une par couple), `unite` (indice de l'unité de chaque couple ; par défaut, une clé
# par unité), `garde` (couples retenus : l'unité lit la table), `admises` (NULL, ou logique sur
# les lignes de la table : lignes que le poste peut lire), `lues` (NULL : la ligne entière ; ou
# colonnes lues : seules comptent les hypothèses qui portent sur l'une d'elles, hypothese_vue(),
# garde du point 1 de #112). Une clé manquante ou vide ne rattache
# rien (cle_renseignee(), #158) ; pour une clé composée, l'appelant donne NA dès qu'une composante
# est manquante ou vide (la clé jointe par « \r » n'est jamais vide). Rend un élément de
# `lectures` de hypotheses_vue_unites(). Sans point : lue aussi par `risque_en_cours` (P3) ; non
# exportée.
lecture_unites <- function(table, colonnes, cles, unite = seq_along(cles), garde = TRUE, admises = NULL, lues = NULL) {
  g <- rep_len(garde, length(cles)) & cle_renseignee(cles)
  list(table = table, colonnes = colonnes, cles = as.character(cles[g]), unite = unite[g], admises = admises, lues = lues)
}

# Lignes lues pour chaque dossier de `etats` (source S2 du § 5.8, liste des lignes lues de P1
# et P2), visibles ou non à A : la ligne de dossiers du dossier, celle de sinistres de son
# sinistre, les lignes d'evenements du sinistre ou du dossier, de prestations et de
# beneficiaires du dossier, la ligne de contrats du contrat de sa garantie souscrite ; si le
# capital est reconstitué (`reconstitue`), les lignes d'affiliations de clé (assuré du
# sinistre, contrat) et, si le dossier est instruit, les lignes de famille du sinistre. Clés
# des unités lues dans la vue (le dossier est une ligne de etats_a_date()). Rend la liste
# `lectures` de hypotheses_vue_unites().
.lectures_dossiers <- function(vue, etats, reconstitue) {
  vv <- function(t, c1) as.character(valeurs_vue(vue, t, c1))
  d <- etats$id_dossier
  s <- as.character(etats$id_sinistre)
  # clés appariées : une clé manquante ou vide ne s'apparie à rien (apparier_cles(), #158) ; clé
  # d'affiliation composée seulement si l'assuré et le contrat sont renseignés
  gs <- vv("dossiers", "id_garantie_souscrite")[apparier_cles(d, vv("dossiers", "id_dossier"))]
  contrat <- vv("garanties_souscrites", "id_contrat")[apparier_cles(gs, vv("garanties_souscrites", "id_garantie_souscrite"))]
  assure <- vv("sinistres", "id_assure")[apparier_cles(s, vv("sinistres", "id_sinistre"))]
  cle_af <- rep(NA_character_, length(d))
  ok_af <- cle_renseignee(assure) & cle_renseignee(contrat)
  cle_af[ok_af] <- paste(assure[ok_af], contrat[ok_af], sep = "\r")
  list(lecture_unites("dossiers", "id_dossier", d),
       lecture_unites("sinistres", "id_sinistre", s),
       lecture_unites("evenements", "id_sinistre", s),
       lecture_unites("evenements", "id_dossier", d),
       lecture_unites("prestations", "id_dossier", d),
       lecture_unites("beneficiaires", "id_dossier", d),
       lecture_unites("contrats", "id_contrat", contrat),
       lecture_unites("affiliations", c("id_assure", "id_contrat"), cle_af, garde = reconstitue),
       lecture_unites("famille", "id_sinistre", s, garde = reconstitue & etats$instruit %in% TRUE))
}

# Salaire de référence par défaut sous l'hypothèse D03c (spécification de B2, § 5.9 ; décision
# E16-1 du mainteneur, option B) : `valeur` déclarée, de forme `<college>=<montant>` joints
# par « ; », et `college` de l'affiliation. La forme de la valeur (collège du domaine de
# college, montant décimal à point, positif ou nul, fini ; collèges distincts) est contrôlée au
# plan par lire_declarations() (`donnees`, erratum v1.0.21, § 2.3, #99), seul lieu de ce
# contrôle ; ici, une valeur vide, un élément sans « = », un montant qui n'est pas un nombre fini
# ou deux collèges égaux sont une erreur interne (le reste de la forme n'est pas revérifié). Rend
# le montant ; collège absent de la liste (contenu qui dépend des données) : NA si `refus` est
# faux, sinon refus plan_incomplet (le lecteur ne refuse qu'une fois les arrêts du poste connus).
.salaire_d03c <- function(valeur, college, poste, refus) {
  morceaux <- strsplit(valeur, ";", fixed = TRUE)[[1L]]
  cles <- sub("=.*$", "", morceaux)
  montants <- suppressWarnings(as.numeric(sub("^[^=]*=", "", morceaux)))
  if (length(morceaux) == 0L || !all(grepl("=", morceaux, fixed = TRUE)) || !all(is.finite(montants)) ||
      anyDuplicated(cles)) {
    stop("erreur interne de provie : hypoth\u00e8se D03c de valeur \u00ab ", valeur,
         " \u00bb, hors de la forme contr\u00f4l\u00e9e au plan (lire_declarations())", call. = FALSE)
  }
  i <- match(college, cles)
  if (is.na(i)) {
    if (!refus) return(NA_real_)
    refuser(paste0("plan : hypoth\u00e8se D03c (comptes_sociaux, ", poste, ") : valeur \u00ab ", valeur,
                   " \u00bb sans salaire pour le coll\u00e8ge ", college), "plan_incomplet", module = "engagement",
            attendu = paste0(college, "=<montant>"), recu = valeur)
  }
  montants[i]
}

# Capital reconstitué des dossiers `ouvert` (spécification de B2, § 5.3) : `etats` (lignes de
# etats_a_date()) ; `parametres` : paramètres du poste (plan). capital_forfaitaire s'il est
# présent ; sinon assiette (salaire_reference de l'affiliation retenue de l'assuré du sinistre
# sous le contrat et au collège de la garantie, erratum v1.0.10, dont [date_debut ; date_fin]
# contient la survenance) x
# taux_capital + majorations (affiliations exclues pour la famille « engagement »,
# vue$exclu$engagement$affiliations, hors du choix : une affiliation exclue ne couvre rien) :
# instruit, famille retenue rattachée au sinistre (un conjoint
# vivant à la survenance, de lien déclaré, ouvre majoration_conjoint ; chaque enfant vivant à la
# survenance d'âge inférieur à age_limite_enfant_majoration, ou a_naitre, ou handicape, ouvre
# majoration_enfant) ; non instruit, structure_familiale du plan (espérance, jugement
# d'expert) ; une majoration absente vaut 0. Salaire manquant d'une affiliation dont la ligne
# porte une hypothèse D03c placée (comptes_sociaux, poste `poste` ou `tous`) : salaire déclaré
# pour son collège (§ 5.9, option B ; collège absent de la liste : refus plan_incomplet levé
# seulement si aucun dossier n'arrête le poste, comme D03h au § 5.5 ; forme de la valeur
# contrôlée au plan, erratum v1.0.21). Rend data.frame (capital, structure,
# arret, d03c, reconstitue) : `structure` vrai si la structure familiale du plan entre dans le
# montant ; `d03c` vrai si le salaire déclaré sous D03c entre dans le montant (source S1, § 5.8) ;
# `reconstitue` vrai si le capital est reconstitué (sans capital_forfaitaire : affiliations, et
# famille si instruit, lues ; lignes lues de la source S2, § 5.8) ;
# `arret` : motif d'arrêt du poste né du dossier (affiliation_non_determinee : aucune ou
# plusieurs affiliations de ce collège couvrent la survenance, ou collège inconnu de la
# garantie ou d'une affiliation de l'assuré au contrat couvrant la survenance ; parametre_non_determine : taux_capital et
# capital_forfaitaire absents, ou paramètre lu à plusieurs valeurs ou dont une ligne retenue
# est exclue pour engagement, erratum v1.0.7 ; assiette_non_determinee, arrêt réel et non une
# garde (erratum v1.0.21) : salaire de l'affiliation manquant sans hypothèse D03c du poste ou
# de `tous` appliquée à la ligne ; famille_non_determinee :
# dossier instruit dont une ligne de famille rattachée au sinistre est exclue pour engagement,
# ou dont un enfant vivant a un âge inconnu sans situation a_naitre ou handicape, erratum
# v1.0.6), NA sinon.
.reconstituer_capital <- function(vue, etats, parametres, conventions, poste) {
  n <- nrow(etats)
  res <- data.frame(capital = rep(NA_real_, n), structure = rep(FALSE, n), arret = rep(NA_character_, n),
                    d03c = rep(FALSE, n), reconstitue = rep(FALSE, n), stringsAsFactors = FALSE)
  if (n == 0L) return(res)
  vv <- function(t, c1) valeurs_vue(vue, t, c1)
  # clés appariées : une clé manquante ou vide ne s'apparie à rien (apparier_cles(), #158)
  i_dos <- apparier_cles(etats$id_dossier, vv("dossiers", "id_dossier"))
  gs <- vv("dossiers", "id_garantie_souscrite")[i_dos]
  i_sin <- apparier_cles(etats$id_sinistre, vv("sinistres", "id_sinistre"))
  assure <- vv("sinistres", "id_assure")[i_sin]
  survenance <- as.numeric(etats$date_entree_etat)
  contrat <- vv("garanties_souscrites", "id_contrat")[apparier_cles(gs, vv("garanties_souscrites", "id_garantie_souscrite"))]
  forfait <- parametre_vue(vue, "capital_forfaitaire", gs, "engagement")
  taux <- parametre_vue(vue, "taux_capital", gs, "engagement")
  mc <- parametre_vue(vue, "majoration_conjoint", gs, "engagement")
  me <- parametre_vue(vue, "majoration_enfant", gs, "engagement")
  # paramètre lu non déterminé : plusieurs valeurs, ou ligne retenue exclue pour engagement
  # (erratum v1.0.7 : une valeur exclue ne vaut jamais 0 et n'est jamais lue comme absente)
  indetermine <- forfait$ambigu | taux$ambigu | mc$ambigu | me$ambigu |
    forfait$exclu | taux$exclu | mc$exclu | me$exclu
  avec_forfait <- !is.na(forfait$valeur) & !indetermine
  res$capital[avec_forfait] <- forfait$valeur[avec_forfait]
  res$arret[indetermine | (is.na(forfait$valeur) & is.na(taux$valeur))] <- "parametre_non_determine"
  a_calculer <- which(is.na(res$arret) & !avec_forfait)
  res$reconstitue[a_calculer] <- TRUE
  if (length(a_calculer) == 0L) return(res)
  # assiette : affiliation retenue, non exclue pour la famille, de l'assuré sous le contrat et
  # au collège de la garantie souscrite du dossier, couvrant la survenance (erratum v1.0.10) ;
  # jointure par clé (assuré, contrat), sans produit croisé, puis filtre sur le collège.
  # Lecture de Kleene : un collège inconnu de la garantie souscrite, ou d'une affiliation de
  # l'assuré au contrat couvrant la survenance, rend l'affiliation non déterminée.
  college <- vv("garanties_souscrites", "college")[apparier_cles(gs, vv("garanties_souscrites", "id_garantie_souscrite"))]
  af_assure <- as.character(vv("affiliations", "id_assure"))
  af_contrat <- as.character(vv("affiliations", "id_contrat"))
  af_college <- as.character(vv("affiliations", "college"))
  af_debut <- as.numeric(vv("affiliations", "date_debut"))
  af_fin <- as.numeric(vv("affiliations", "date_fin"))
  # dates tenues pour inconnues par D02a sous H (R5 ; dates_inconnues_vue(), spécification
  # `donnees` v1.9, § 9.4, #90) : couverture de la survenance inconnue, jamais une fin ouverte
  af_inconnue <- dates_inconnues_vue(vue, "affiliations", "date_debut") | dates_inconnues_vue(vue, "affiliations", "date_fin")
  af_fin[is.na(af_fin)] <- Inf
  salaire <- vv("affiliations", "salaire_reference")
  # clé (assuré, contrat) composée seulement si ses deux composantes sont renseignées (#158)
  af_ok <- which(cle_renseignee(af_assure) & cle_renseignee(af_contrat) & (!is.na(af_debut) | af_inconnue) &
                   !vue$exclu$engagement$affiliations)
  par_cle <- split(af_ok, paste(af_assure[af_ok], af_contrat[af_ok], sep = "\r"))
  cle_dossier <- rep(NA_character_, length(a_calculer))
  ok_cle <- cle_renseignee(assure[a_calculer]) & cle_renseignee(contrat[a_calculer])
  cle_dossier[ok_cle] <- paste(as.character(assure[a_calculer][ok_cle]), as.character(contrat[a_calculer][ok_cle]), sep = "\r")
  cand <- par_cle[cle_dossier]
  cand[vapply(cand, is.null, NA)] <- list(integer(0))
  ii <- rep(seq_along(a_calculer), lengths(cand))
  kk <- unlist(cand, use.names = FALSE)
  couvre <- af_debut[kk] <= survenance[a_calculer][ii] & af_fin[kk] >= survenance[a_calculer][ii]
  # affiliation de dates inconnues (Kleene) : peut couvrir la survenance ; de collège égal ou
  # inconnu, elle rend l'affiliation non déterminée
  couvre_inconnu <- af_inconnue[kk] & (is.na(af_college[kk]) | (af_college[kk] == as.character(college[a_calculer][ii])) %in% TRUE)
  couvre[af_inconnue[kk]] <- FALSE
  college_inconnu <- is.na(college[a_calculer]) |
    tabulate(ii[couvre & is.na(af_college[kk])], nbins = length(a_calculer)) > 0L |
    tabulate(ii[couvre_inconnu], nbins = length(a_calculer)) > 0L
  couvre <- couvre & (af_college[kk] == as.character(college[a_calculer][ii])) %in% TRUE
  nb <- tabulate(ii[couvre], nbins = length(a_calculer))
  k1 <- rep(NA_integer_, length(a_calculer))
  k1[ii[couvre]] <- kk[couvre]
  assiette <- rep(NA_real_, n)
  res$arret[a_calculer[nb != 1L | college_inconnu]] <- "affiliation_non_determinee"
  un <- nb == 1L & !college_inconnu
  sal <- salaire[k1[un]]
  # salaire manquant : hypothèse D03c de la ligne de l'affiliation (§ 5.9), valeur lue ici sans
  # refus (collège absent : NA), refus différé à la fin, une fois les arrêts connus ; sans
  # hypothèse lue, arrêt assiette_non_determinee (arrêt réel, non une garde : aucune hypothèse
  # D03c, ou hypothèse d'un autre poste seulement)
  manque <- which(is.na(sal))
  h_d03c <- hypothese_vue(vue, "D03c", .REFERENTIEL_B2, "affiliations", k1[un][manque], poste)
  lue <- !is.na(h_d03c)
  d03c <- list(i = a_calculer[un][manque][lue], valeur = h_d03c[lue], college = af_college[k1[un][manque][lue]])
  res$arret[a_calculer[un][manque][!lue]] <- "assiette_non_determinee"
  res$d03c[d03c$i] <- TRUE
  assiette[a_calculer[un]] <- sal
  assiette[d03c$i] <- vapply(seq_along(d03c$i), function(j) .salaire_d03c(d03c$valeur[j], d03c$college[j], poste, FALSE),
                             0)
  a_calculer <- a_calculer[is.na(res$arret[a_calculer])]
  if (length(a_calculer) == 0L) return(res)
  mc0 <- ifelse(is.na(mc$valeur), 0, mc$valeur)
  me0 <- ifelse(is.na(me$valeur), 0, me$valeur)
  base <- assiette * taux$valeur
  instruit <- etats$instruit
  # instruction tenue pour inconnue par D02a sous H (R10 ; etats_a_date() rend NA) : structure du
  # plan ou famille réelle, non déterminé ; arrêt parametre_non_determine
  instr_inconnue <- dates_inconnues_vue(vue, "sinistres", "date_instruction")[i_sin] %in% TRUE
  res$arret[a_calculer[is.na(instruit[a_calculer]) & instr_inconnue[a_calculer]]] <- "parametre_non_determine"
  a_calculer <- a_calculer[is.na(res$arret[a_calculer])]
  if (length(a_calculer) == 0L) return(res)
  if (anyNA(instruit[a_calculer])) {
    i <- a_calculer[is.na(instruit[a_calculer])][1L]
    stop("erreur interne de provie : dossier \u00e0 reconstituer dont l'instruction est inconnue (", etats$id_dossier[i],
         ") : le poste aurait d\u00fb \u00eatre arr\u00eat\u00e9 (sp\u00e9cification de B2, \u00a7 4.3)", call. = FALSE)
  }
  # non instruit : structure familiale du plan (espérance, jugement d'expert)
  ni <- a_calculer[!instruit[a_calculer]]
  if (length(ni)) {
    sf <- parametres$structure_familiale
    res$capital[ni] <- base[ni] + assiette[ni] * (mc0[ni] * sf$taux_conjoint + me0[ni] * sf$nombre_enfants)
    res$structure[ni] <- TRUE
  }
  # instruit : famille retenue rattachée au sinistre, jointure par id_sinistre ; lecture de
  # Kleene (erratum v1.0.6) : une ligne exclue pour engagement est inconnue (lien et âge), un
  # enfant vivant d'âge inconnu sans situation a_naitre ou handicape a une majoration inconnue ;
  # dans les deux cas, arrêt famille_non_determinee (jamais compté pour zéro). La date de
  # naissance d'un conjoint n'est pas lue ; date_deces manquante : vivant.
  ins <- a_calculer[instruit[a_calculer]]
  if (length(ins)) {
    f_sin <- as.character(vv("famille", "id_sinistre"))
    f_ok <- which(!is.na(f_sin))
    par_sin <- split(f_ok, f_sin[f_ok])
    cf <- par_sin[as.character(etats$id_sinistre[ins])]
    cf[vapply(cf, is.null, NA)] <- list(integer(0))
    jj <- rep(seq_along(ins), lengths(cf))
    k <- unlist(cf, use.names = FALSE)
    exclue <- vue$exclu$engagement$famille[k]
    surv <- survenance[ins][jj]
    f_deces <- as.numeric(vv("famille", "date_deces"))[k]
    lien <- vv("famille", "lien")[k]
    vivant <- is.na(f_deces) | f_deces > surv
    conjoint <- tabulate(jj[!exclue & vivant & lien %in% parametres$liens_conjoint_majoration], nbins = length(ins)) > 0L
    enf <- !exclue & vivant & lien %in% "enfant"
    age <- calculer_age(vv("famille", "date_naissance")[k][enf], etats$date_entree_etat[ins][jj[enf]], conventions$age)
    compte <- (age < parametres$age_limite_enfant_majoration) |
      vv("famille", "situation")[k][enf] %in% c("a_naitre", "handicape")
    inconnu <- tabulate(c(jj[exclue], jj[enf][is.na(compte)]), nbins = length(ins)) > 0L
    enfants <- tabulate(jj[enf][compte %in% TRUE], nbins = length(ins))
    connu <- !inconnu
    res$capital[ins[connu]] <- base[ins[connu]] + assiette[ins[connu]] * (mc0[ins[connu]] * conjoint[connu] +
                                                                           me0[ins[connu]] * enfants[connu])
    res$arret[ins[inconnu]] <- "famille_non_determinee"
  }
  # collège de l'affiliation absent de la valeur de D03c pour un dossier qui la lit : refus
  # plan_incomplet, levé seulement si aucun dossier n'arrête le poste (§ 5.9 ; ordre de D03h,
  # § 5.5)
  if (all(is.na(res$arret))) for (j in seq_along(d03c$i)) .salaire_d03c(d03c$valeur[j], d03c$college[j], poste, TRUE)
  res
}

# Capital, solde et montant des dossiers `etats` (lignes de etats_a_date() de la population
# d'un poste de P1 ou P2) sous la méthode `methode` (spécification de B2, § 5.3 et § 5.4 ; une
# seule fonction pour les quatre méthodes, `switch` à branches explicites sur l'horizon) :
# capital (montant_en_vigueur d'un capital_du ; capital reconstitué d'un ouvert), facteur
# d'issue (ouvert de sinistre deces : 1 - taux_sans_suite ; ouvert de sinistre iad :
# probabilite_reconnaissance_iad ; capital_du : 1), solde revalorisé à l'arrêté = capital x
# F(survenance, A) - somme des prestations capital retenues du dossier x F(règlement, A),
# montant = solde x F(A, horizon) (horizon : A pour `arrete` ; A + delai_reglement_jours pour
# `reglement` ; pour `depot`, connaissance du décès + 10 ans, ou A + duree_sans_depot_annees
# ans pour un décès antérieur au 1er janvier 2015 (anniversaires ; un 29 février donne le
# 1er mars) ; F = 1 si l'horizon est au plus l'arrêté), date du flux (horizon, au plus tôt
# A + 1), statut du dossier. `prestations` : lignes de la vue non exclues (indices) ; `poste` :
# poste du calcul (hypothèse D03c du poste ou de `tous`, § 5.9). Rend un data.frame, une ligne
# par dossier (`d03c` : salaire déclaré sous D03c lu, source S1 du § 5.8 ; `reconstitue` :
# capital reconstitué, affiliations et famille lues, lignes lues de la source S2).
capital_deces_dossier <- function(vue, plan, etats, methode, parametres, prestations, poste) {
  horizon <- .HORIZONS[[methode]]
  a <- vue$bilan$vue$date_arrete
  rv <- .revalorisation_plan(plan)
  conventions <- plan$conventions
  n <- nrow(etats)
  rec <- .reconstituer_capital(vue, etats[etats$etat_dossier == "ouvert", , drop = FALSE], parametres, conventions,
                               poste)
  capital <- etats$montant_en_vigueur
  structure_f <- rep(FALSE, n)
  arret <- rep(NA_character_, n)
  ouvert <- etats$etat_dossier == "ouvert"
  capital[ouvert] <- rec$capital
  structure_f[ouvert] <- rec$structure
  arret[ouvert] <- rec$arret
  d03c <- rep(FALSE, n)
  d03c[ouvert] <- rec$d03c
  reconstitue <- rep(FALSE, n)
  reconstitue[ouvert] <- rec$reconstitue
  issue <- rep(1, n)
  issue[ouvert & etats$etat %in% "deces"] <- 1 - parametres$taux_sans_suite
  issue[ouvert & etats$etat %in% "iad"] <- parametres$probabilite_reconnaissance_iad
  res <- data.frame(id_dossier = etats$id_dossier, capital = capital, issue = issue, structure = structure_f,
                    d03c = d03c, reconstitue = reconstitue, arret = arret, solde = rep(NA_real_, n),
                    montant = rep(NA_real_, n),
                    date_flux = structure(rep(as.numeric(a) + 1, n), class = "Date"),
                    horizon = structure(rep(as.numeric(a), n), class = "Date"), horizon_echu = rep(FALSE, n),
                    stringsAsFactors = FALSE)
  ok <- which(is.na(arret))
  if (length(ok) == 0L) return(res)
  taux_futur <- rv$taux_futur
  f <- function(debut, fin) facteur_revalorisation(debut, fin, rv$taux_par_annee, rv$prorata, conventions, a, taux_futur)
  solde <- capital[ok] * f(etats$date_entree_etat[ok], a)
  # prestations capital retenues du dossier (paiements et régularisations, signées)
  ptype <- valeurs_vue(vue, "prestations", "type_prestation")[prestations]
  k <- prestations[ptype %in% "capital"]
  if (length(k)) {
    pm <- valeurs_vue(vue, "prestations", "montant")[k]
    pr <- valeurs_vue(vue, "prestations", "date_reglement")[k]
    j <- apparier_cles(valeurs_vue(vue, "prestations", "id_dossier")[k], etats$id_dossier[ok])
    garde <- !is.na(j)
    if (any(garde)) {
      paye <- pm[garde] * f(pr[garde], a)
      s <- vapply(split(paye, factor(j[garde], levels = seq_along(ok))), sum, 0)
      solde <- solde - unname(s)
    }
  }
  res$solde[ok] <- solde
  fin_h <- switch(horizon,
    arrete = rep(as.numeric(a), length(ok)),
    reglement = rep(as.numeric(a) + parametres$delai_reglement_jours, length(ok)),
    depot = {
      decl <- valeurs_vue(vue, "sinistres", "date_declaration")[apparier_cles(etats$id_sinistre[ok],
                                                                              valeurs_vue(vue, "sinistres", "id_sinistre"))]
      legal <- as.numeric(etats$date_entree_etat[ok]) >= as.numeric(.DEBUT_DEPOT_LEGAL)
      h <- as.numeric(date_atteinte_age(rep(a, length(ok)), rv$duree_sans_depot_annees, "revolu"))
      h[legal] <- as.numeric(date_atteinte_age(decl[legal], .ANNEES_DEPOT_CDC, "revolu"))
      h
    })
  echu <- fin_h <= as.numeric(a)
  fin_h[echu] <- as.numeric(a)
  res$montant[ok] <- solde * f(rep(a, length(ok)), structure(fin_h, class = "Date"))
  res$date_flux[ok] <- structure(pmax(fin_h, as.numeric(a) + 1), class = "Date")
  res$horizon[ok] <- structure(fin_h, class = "Date")
  res$horizon_echu[ok] <- echu & horizon == "depot"
  res
}

# --- Point d'appel de la famille -----------------------------------------------------

# Cellule d'un poste (ADR 0010, point 6) : segmentation et segment `ensemble`, niveau `calcul`.
.cellule <- function(garantie, poste, famille, provision, montant, nombre, methode, statut_methode, statut_resultat,
                     motif_arret) {
  res <- data.frame(garantie = garantie, referentiel = .REFERENTIEL_B2, poste = poste, famille = famille,
                    provision = provision, segmentation = "ensemble", segment = "ensemble", niveau = "calcul",
                    montant = as.double(montant), nombre_dossiers = as.integer(nombre), methode = methode,
                    statut_methode = statut_methode, statut_resultat = statut_resultat,
                    statut_calcul = if (is.na(motif_arret)) "calcule" else "arrete", motif_arret = motif_arret,
                    stringsAsFactors = FALSE)
  res[COLONNES_CELLULES]
}

# Statut le plus faible d'un ensemble de statuts (STATUTS_RESULTAT_B2) ; `exact` sans élément.
# Sans point : lue aussi par `risque_en_cours` ; non exportée.
statut_le_plus_faible <- function(statuts) {
  if (length(statuts) == 0L) return("exact")
  STATUTS_RESULTAT_B2[max(match(statuts, STATUTS_RESULTAT_B2))]
}

.dossiers_vides <- function() {
  data.frame(id_dossier = character(0), id_sinistre = character(0), garantie = character(0), referentiel = character(0),
             poste = character(0), etat = character(0), date_entree_etat = structure(numeric(0), class = "Date"),
             montant = numeric(0), methode = character(0), statut_resultat = character(0),
             hypotheses_defaut = character(0), stringsAsFactors = FALSE)
}

.echeancier_vide <- function() {
  data.frame(cle = character(0), referentiel = character(0), poste = character(0),
             date = structure(numeric(0), class = "Date"), etat = character(0), type_flux = character(0),
             flux = numeric(0), probabilite = numeric(0), actualisation = numeric(0), valeur_actuelle = numeric(0),
             stringsAsFactors = FALSE)
}

.indicateurs_vides <- function() {
  data.frame(regle = character(0), poste = character(0), garantie = character(0), valeur_regle = numeric(0),
             valeur_retenue = numeric(0), depassement = logical(0), detail = character(0), stringsAsFactors = FALSE)
}

# Statut d'une méthode dans le catalogue (spécification de B2, § 4.1) : la première méthode du
# champ est la recommandée, les suivantes alternatives. Sans point : lue aussi par
# `risque_en_cours`, non exportée.
statut_methode_catalogue <- function(catalogue, garantie, poste, champ, methode) {
  ligne <- catalogue$postes[catalogue$postes$code_garantie == garantie & catalogue$postes$poste == poste, , drop = FALSE]
  m <- methodes_poste(ligne$methodes, poste, "methodes")
  m <- m$methode[m$champ == champ]
  if (!(methode %in% m)) stop("erreur interne de provie : m\u00e9thode ", methode, " hors du catalogue du poste ", poste,
                              call. = FALSE)
  if (identical(methode, m[1L])) "recommandee" else "alternative"
}

# Ligne d'indicateur de plan mixte (spécification de B2, § 5.4) : une méthode `arrete` sur l'un
# de P1 et P2 et une méthode « règlement » sur l'autre ; aucune ligne pour un plan homogène.
.indicateur_mixte <- function(plan, garantie) {
  m1 <- plan$postes[[garantie]]$sinistres_declares_non_regles$methode
  m2 <- plan$postes[[garantie]]$capitaux_non_reclames$methode
  if (is.null(m1) || is.null(m2) || (.HORIZONS[[m1]] == "arrete") == (.HORIZONS[[m2]] == "arrete")) {
    return(.indicateurs_vides())
  }
  data.frame(regle = "methode_revalorisation_mixte", poste = "ensemble", garantie = garantie, valeur_regle = NA_real_,
             valeur_retenue = NA_real_, depassement = TRUE,
             detail = paste0("sinistres_declares_non_regles=", m1, ";capitaux_non_reclames=", m2), stringsAsFactors = FALSE)
}

# Point d'appel d'un poste de la famille « engagement » par l'orchestration (spécification de
# B2, § 5.1, § 5.3 et § 5.4) : `vue` (vue_a_date()), `plan` (validé et canonique), `tables`
# (tables résolues par usage, dont serie_tme pour les indicateurs R132_3_1), `catalogue`
# (catalogue_garanties()), `garantie` ("deces"), `poste` (sinistres_declares_non_regles ou
# capitaux_non_reclames). Rend list(cellules, dossiers, echeanciers, indicateurs) aux formes
# de l'ADR 0010, point 6 (COLONNES_CELLULES, COLONNES_DOSSIERS, COLONNES_ECHEANCIERS,
# COLONNES_INDICATEURS de `tables`). Poste arrêté (postes_a_arreter() sur le bilan de la vue ;
# ligne de portée ligne de refus_tables dont une ligne refusée est lue pour une unité de la
# population, arret_refus_ligne(), #72 : motif du refus, plus petit dossier en cause (tri radix), lignes en
# cause dans l'attribut `refus_ligne` de la cellule ; motifs nés de la famille :
# affiliation_non_determinee, parametre_non_determine, assiette_non_determinee,
# famille_non_determinee) : cellule `arrete`, montant et nombre de dossiers NA, aucun dossier ni
# échéancier ; le dossier en cause retenu est l'attribut `identifiant_arret` de la cellule.
# Population (§ 5.3, § 5.4) : dossiers de etats_a_date(vue, "deces", "engagement") non exclus pour la
# famille engagement, de garantie souscrite hors de garanties_couverture_exclue(vue,
# "engagement") (erratum v1.0.13) ; P2 = ceux qui remplissent le critère du plan (réunion), P1 =
# les autres, partition faite avant le filtre des dossiers clos ; un dossier clos n'est pas
# calculé, sauf si une ligne d'evenements du dossier (lecture par id_dossier seule : un événement
# d'un autre dossier du sinistre ne décide pas, erratum v1.0.19, réserve R7) porte une hypothèse
# de la vue (S2 ; visible de type cloture_dossier ou reouverture_dossier, ou invisible) : unité
# restituée à 0, jugement_expert, deux lignes d'échéancier de flux 0 (§ 5.8, errata v1.0.17 et v1.0.18, E18-1) ; un dossier de solde au
# plus nul n'entre pas dans `dossiers`, sauf sous D03c (S1) ou si une ligne de prestations du
# dossier porte S2 (unité à montant nul, § 5.8, E16-5 : montant 0). Indicateurs : une
# ligne R132_3_1 par année de taux_par_annee employée ; la ligne methode_revalorisation_mixte
# (émise par l'appel de P1) ; une ligne depot_cdc_echu par dossier de P2 dont l'horizon de
# dépôt est échu à l'arrêté sous capital_revalorise_reglement (F = 1, aucune correction).
calculer_engagement <- function(vue, plan, tables, catalogue, garantie, poste) {
  if (!identical(garantie, "deces") || !(poste %in% .POSTES_ENGAGEMENT)) {
    stop("erreur interne de provie : calculer_engagement() ne calcule que P1 et P2 de la garantie deces", call. = FALSE)
  }
  if (!inherits(vue, "vue_provie")) stop("calculer_engagement() : `vue` doit \u00eatre un objet vue_provie", call. = FALSE)
  declaration <- plan$postes[[garantie]][[poste]]
  methode <- declaration$methode
  parametres <- declaration$parametres
  statut_methode <- statut_methode_catalogue(catalogue, garantie, poste, "", methode)
  ligne_cat <- catalogue$postes[catalogue$postes$code_garantie == garantie & catalogue$postes$poste == poste, , drop = FALSE]
  frais <- plan$frais[[garantie]][[poste]][[.REFERENTIEL_B2]]$taux_chargement_psap
  indicateurs <- if (poste == "sinistres_declares_non_regles") .indicateur_mixte(plan, garantie) else .indicateurs_vides()
  # `refus_ligne` : lignes de portée ligne de refus_tables qui arrêtent le poste (attribut de
  # la cellule, lu par calculer_provisions() pour postes_arretes, #72)
  arreter <- function(motif, identifiant, refus_ligne = integer(0)) {
    cel <- .cellule(garantie, poste, ligne_cat$famille, ligne_cat$provision_comptes_sociaux, NA_real_, NA_integer_,
                    methode, statut_methode, NA_character_, motif)
    attr(cel, "identifiant_arret") <- identifiant
    if (length(refus_ligne)) attr(cel, "refus_ligne") <- refus_ligne
    list(cellules = cel, dossiers = .dossiers_vides(), echeanciers = .echeancier_vide(), indicateurs = indicateurs)
  }
  # arrêt de poste lu sur le bilan (M239)
  pa_tout <- postes_a_arreter(catalogue, vue$bilan, plan$postes, parties_ligne())
  pa <- pa_tout$postes
  motif_bilan <- pa$motif_arret[pa$garantie == garantie & pa$poste == poste]
  if (length(motif_bilan) == 1L && !is.na(motif_bilan)) return(arreter(motif_bilan, NA_character_))
  # dossier de la population dont la garantie souscrite n'est pas retenue à l'arrêté (exception
  # de la règle 1 : garantie d'effet postérieur à l'arrêté, D10b, ou de contrat d'effet postérieur,
  # D11a, ou de visibilité non déterminée ; dossier non exclu pour engagement, ni à couverture
  # exclue ; spécification `donnees` v1.9, § 9.3 (1) et bloc « Erratum 1.9.2 », (i) et (vii),
  # M509, #83) : le poste lit les colonnes de la garantie, jamais lues sur une version non
  # retenue : arrêt parametre_non_determine, premier dossier en cause
  # (dossiers_garantie_invisible(), seule implémentation)
  invisibles <- dossiers_garantie_invisible(vue, "engagement")
  if (length(invisibles)) return(arreter("parametre_non_determine", invisibles[1L]))

  a <- vue$bilan$vue$date_arrete
  etats <- etats_a_date(vue, garantie, "engagement")
  # ligne de dossiers de l'état : un identifiant de dossier manquant ou vide ne s'apparie à rien
  # (apparier_cles(), #154, règle (iii)) ; un tel état est inatteignable par une base (refus de
  # portée table de dossiers, postes arrêtés avant etats_a_date(), M239) : erreur interne,
  # jamais un retrait silencieux de la population (décision du mainteneur du 16 novembre 2026)
  i_dos <- apparier_cles(etats$id_dossier, valeurs_vue(vue, "dossiers", "id_dossier"))
  if (anyNA(i_dos)) {
    stop("erreur interne de provie : calculer_engagement() : dossier de l'\u00e9tat sans identifiant (manquant ou vide), ",
         "aucune ligne de dossiers appari\u00e9e", call. = FALSE)
  }
  exclu <- vue$exclu$engagement
  # couverture exclue (erratum v1.0.13) : dossier d'une garantie souscrite, ou d'un contrat, exclu
  # pour engagement hors de la population (garanties_couverture_exclue(), seule implémentation ;
  # identifiants rendus jamais NA ni "", appariement par apparier_cles(), #154)
  couverture_exclue <- !is.na(apparier_cles(valeurs_vue(vue, "dossiers", "id_garantie_souscrite")[i_dos],
                                            garanties_couverture_exclue(vue, "engagement")))
  # population avant le filtre des dossiers clos (§ 5.8, erratum v1.0.17 : un dossier clos sous
  # une hypothèse de la vue est une unité restituée à 0, au poste de la partition du § 5.4)
  garde <- !exclu$dossiers[i_dos] & !couverture_exclue
  etats <- etats[garde, , drop = FALSE]
  # partition P1 / P2 selon le critère de P2 (réunion des critères déclarés) ; une valeur
  # refusée de portée ligne (lignes_refus_ligne_vue(), #72) y est inconnue (Kleene)
  refusee <- function(t, c1) lignes_refus_ligne_vue(vue, t, c1)
  p2 <- plan$postes[[garantie]]$capitaux_non_reclames$parametres
  non_reclame <- rep(FALSE, nrow(etats))
  if ("beneficiaire_non_identifie" %in% p2$critere) {
    b <- which(vue$retenu$beneficiaires & !exclu$beneficiaires)
    b_dos <- valeurs_vue(vue, "beneficiaires", "id_dossier")[b]
    q_inc <- refusee("beneficiaires", "qualite")[b]
    ni <- b_dos[!q_inc & valeurs_vue(vue, "beneficiaires", "qualite")[b] %in% "non_identifie"]
    crit <- !is.na(apparier_cles(etats$id_dossier, ni))
    crit[!crit & !is.na(apparier_cles(etats$id_dossier, b_dos[q_inc]))] <- NA
    non_reclame <- non_reclame | crit
  }
  if ("sans_evenement" %in% p2$critere) {
    seuil <- ajouter_mois(a, -as.integer(p2$mois_sans_evenement))
    e <- which(vue$retenu$evenements & !exclu$evenements)
    effet_inc <- dates_inconnues_vue(vue, "evenements", "date_effet")[e] | refusee("evenements", "date_effet")[e]
    recent <- as.numeric(valeurs_vue(vue, "evenements", "date_effet")[e]) > seuil
    actifs <- valeurs_vue(vue, "evenements", "id_dossier")[e][recent %in% TRUE & !effet_inc]
    # événement de date tenue pour inconnue par D02a sous H (R12, R13 sans valeur substituée) ou
    # refusée de portée ligne : peut être récent ; le critère est inconnu pour un dossier sans
    # événement récent connu
    inconnus <- valeurs_vue(vue, "evenements", "id_dossier")[e][effet_inc]
    i_ouv <- apparier_cles(etats$id_dossier, valeurs_vue(vue, "dossiers", "id_dossier"))
    ouverture <- as.numeric(valeurs_vue(vue, "dossiers", "date_ouverture"))[i_ouv]
    ancien <- (ouverture <= seuil) %in% TRUE
    ancien[refusee("dossiers", "date_ouverture")[i_ouv]] <- NA
    sans_ev <- is.na(apparier_cles(etats$id_dossier, actifs)) & ancien
    sans_ev[sans_ev %in% TRUE & !is.na(apparier_cles(etats$id_dossier, inconnus))] <- NA
    non_reclame <- non_reclame | sans_ev
  }
  # arrêt par les lignes de portée ligne de refus_tables (#72 ; arret_refus_ligne(), condition
  # (2)), avant toute lecture des valeurs des unités : unités de la population du poste avant le
  # filtre des dossiers clos, dont celles de partition non déterminée (Kleene : elles sont
  # unités possibles de P1 et de P2) ; lignes lues du § 5.8 hors capital reconstitué (affiliations
  # et famille, lues après le calcul du capital)
  cle_poste <- paste(garantie, poste, sep = "/")
  dans_poste <- !((if (poste == "capitaux_non_reclames") non_reclame else !non_reclame) %in% FALSE)
  unites <- etats[dans_poste, , drop = FALSE]
  lect_unites <- .lectures_dossiers(vue, unites, rep(FALSE, nrow(unites)))
  listees <- unique(vapply(lect_unites, `[[`, "", "table"))
  differees <- c("affiliations", "famille")
  ar <- arret_refus_ligne(vue, pa_tout, cle_poste, "engagement", nrow(unites), lect_unites, unites$id_dossier, listees,
                          setdiff(listees, differees))
  if (length(ar$lignes)) return(arreter(ar$motif, ar$identifiant, ar$lignes))
  # partition non déterminée (Kleene : un critère connu vrai décide) : P1 et P2 arrêtés
  if (anyNA(non_reclame)) return(arreter("parametre_non_determine", etats$id_dossier[is.na(non_reclame)][1L]))
  etats <- etats[if (poste == "capitaux_non_reclames") non_reclame else !non_reclame, , drop = FALSE]
  # dossiers clos du poste : hors du calcul ; restitués à 0 sous une hypothèse de la vue (S2)
  clos <- etats[etats$etat_dossier %in% "clos", , drop = FALSE]
  etats <- etats[!(etats$etat_dossier %in% "clos"), , drop = FALSE]
  # dates du sinistre tenues pour inconnues par D02a sous H (dates_inconnues_vue(), `donnees` ;
  # spécification `donnees` v1.9, § 9.4, #90) : la survenance (R8, R9) est lue par toute méthode
  # (revalorisation, reconstitution) ; la déclaration (R9, R10), par l'horizon de dépôt d'un
  # décès de 2015 ou après. Arrêt parametre_non_determine, premier dossier en cause
  i_s <- apparier_cles(etats$id_sinistre, valeurs_vue(vue, "sinistres", "id_sinistre"))
  date_inconnue <- dates_inconnues_vue(vue, "sinistres", "date_survenance")[i_s] %in% TRUE |
    (.HORIZONS[[methode]] == "depot" & dates_inconnues_vue(vue, "sinistres", "date_declaration")[i_s] %in% TRUE &
       (as.numeric(etats$date_entree_etat) >= as.numeric(.DEBUT_DEPOT_LEGAL)) %in% TRUE)
  if (any(date_inconnue)) return(arreter("parametre_non_determine", etats$id_dossier[date_inconnue][1L]))
  # couverture de taux_par_annee : chaque année de la survenance la plus ancienne à l'arrêté
  rv <- .revalorisation_plan(plan)
  if (nrow(etats) > 0L) {
    annee_a <- as.POSIXlt(a)$year + 1900L
    debut <- as.POSIXlt(etats$date_entree_etat)$year + 1900L
    for (y in seq.int(min(debut), annee_a)) {
      if (!(as.character(y) %in% names(rv$taux_par_annee))) {
        premier <- etats$id_dossier[debut <= y][1L]
        refuser(paste0("plan : revalorisation$capital_deces$taux_par_annee ne couvre pas l'ann\u00e9e ", y,
                       " (premier dossier : ", premier, ")"), "plan_incomplet", module = "engagement",
                attendu = paste0("revalorisation$capital_deces$taux_par_annee$", y), identifiants = premier)
      }
    }
  }
  prestations <- which(vue$retenu$prestations & !exclu$prestations)
  calc <- capital_deces_dossier(vue, plan, etats, methode, parametres, prestations, poste)
  # arrêt par une ligne refusée de portée ligne lue pour un capital reconstitué (affiliations, et
  # famille si le dossier est instruit, § 5.8 ; #72), avant les arrêts nés du calcul
  ar <- arret_refus_ligne(vue, pa_tout, cle_poste, "engagement", nrow(etats),
                          Filter(function(l) l$table %in% differees, .lectures_dossiers(vue, etats, calc$reconstitue)),
                          etats$id_dossier, listees, differees, repli = FALSE)
  if (length(ar$lignes)) return(arreter(ar$motif, ar$identifiant, ar$lignes))
  arret <- which(!is.na(calc$arret))
  if (length(arret)) return(arreter(calc$arret[arret[1L]], calc$id_dossier[arret[1L]]))
  # invariant (spécification de B2, § 4.3) : aucun dossier valorisé à instruction inconnue par sa
  # partie de ligne ; une instruction tenue pour inconnue par D02a sous H (R10) n'est lue que pour
  # un capital reconstitué, arrêté plus haut (.reconstituer_capital())
  nd_instr <- is.na(etats$instruit) & !(dates_inconnues_vue(vue, "sinistres", "date_instruction")[i_s] %in% TRUE)
  if (any(nd_instr)) {
    stop("erreur interne de provie : dossier valoris\u00e9 \u00e0 instruction inconnue (", etats$id_dossier[nd_instr][1L],
         ")", call. = FALSE)
  }
  # codes des sources S1 (D03c) et S2 (hypothèses de la vue, hypotheses_vue_unites()) du
  # dossier, réunis (§ 5.8, #87) : statut et hypotheses_defaut de toute unité restituée ; un
  # dossier clos n'a pas de capital reconstitué
  n_u <- nrow(etats) + nrow(clos)
  lectures <- .lectures_dossiers(vue, rbind(etats, clos), c(calc$reconstitue, rep(FALSE, nrow(clos))))
  s2_de <- function(tables) {
    hypotheses_vue_unites(vue, .REFERENTIEL_B2, poste, "engagement", n_u,
                          Filter(function(l) l$table %in% tables, lectures))
  }
  s2 <- s2_de(unique(vapply(lectures, `[[`, "", "table")))
  codes <- joindre_codes(c("", "D03c")[1L + calc$d03c], s2[seq_len(nrow(etats))])
  # unité sortie du calcul restituée à 0 seulement si une ligne qui décide du filtre de sortie
  # porte S2 (errata v1.0.18 et v1.0.19, constat M1, réserves R1, R3, R7 ; décision E18-1) :
  # dossier clos, une ligne d'evenements du dossier visible de type cloture_dossier ou
  # reouverture_dossier, ou invisible quel que soit son type ; solde au plus nul, une ligne de
  # prestations du dossier (ou le salaire déclaré sous D03c, S1, E16-5)
  i_clos <- nrow(etats) + seq_len(nrow(clos))
  ev_decide <- !vue$retenu$evenements |
    valeurs_vue(vue, "evenements", "type_evenement") %in% c("cloture_dossier", "reouverture_dossier")
  # lecture par id_dossier seule : un événement d'un autre dossier du sinistre ne décide pas de
  # la clôture (erratum v1.0.19, réserve R7) ; la lecture par id_sinistre reste celle du statut
  lect_ev <- lapply(Filter(function(l) l$table == "evenements" && identical(l$colonnes, "id_dossier"), lectures),
                    function(l) { l$admises <- ev_decide; l })
  garde_clos <- nzchar(hypotheses_vue_unites(vue, .REFERENTIEL_B2, poste, "engagement", n_u, lect_ev)[i_clos])
  codes_clos <- s2[i_clos][garde_clos]
  clos <- clos[garde_clos, , drop = FALSE]
  sous_h <- nzchar(codes)
  sortie_h <- calc$d03c | nzchar(s2_de("prestations")[seq_len(nrow(etats))])
  valorise <- which(calc$solde > 0 | (sortie_h & !is.na(calc$solde)))
  nc <- nrow(clos)
  et <- etats[valorise, , drop = FALSE]
  cc <- calc[valorise, , drop = FALSE]
  cc$montant <- pmax(cc$montant, 0)
  nv <- length(valorise)
  # dossier clos restitué : les deux lignes de capital_dossier, de flux 0, probabilité 1, au
  # lendemain de l'arrêté (§ 5.3 ; erratum v1.0.18, réserve R2)
  ech <- data.frame(cle = rep(c(cc$id_dossier, clos$id_dossier), each = 2L),
                    date = structure(c(rep(as.numeric(cc$date_flux), each = 2L), rep(as.numeric(a) + 1, 2L * nc)),
                                     class = "Date"),
                    etat = rep(c(et$etat, clos$etat), each = 2L),
                    type_flux = rep(c("capital_unique", "frais"), nv + nc),
                    flux = c(as.vector(rbind(cc$montant, frais * cc$montant)), rep(0, 2L * nc)),
                    probabilite = c(rep(cc$issue, each = 2L), rep(1, 2L * nc)), stringsAsFactors = FALSE)
  vap <- valeur_actuelle_probable(ech, list(type = "aucune"), plan$conventions)
  montant <- vap$valeurs$valeur_actuelle[apparier_cles(cc$id_dossier, vap$valeurs$cle)]
  reglement <- .HORIZONS[[methode]] != "arrete"
  # jugement_expert : méthode « règlement », structure familiale du plan, facteur d'issue, ou
  # valeur des sources S1 (salaire déclaré sous D03c, § 5.9) et S2 (hypothèse de la vue, #87)
  # du § 5.8 ; codes dans hypotheses_defaut (§ 5.3)
  statut <- ifelse(reglement | cc$structure | cc$issue < 1 | sous_h[valorise], "jugement_expert", "exact")
  dossiers <- data.frame(id_dossier = cc$id_dossier, id_sinistre = et$id_sinistre, garantie = rep(garantie, nv),
                         referentiel = rep(.REFERENTIEL_B2, nv), poste = rep(poste, nv), etat = et$etat,
                         date_entree_etat = et$date_entree_etat, montant = if (nv) montant else numeric(0),
                         methode = rep(methode, nv), statut_resultat = statut,
                         hypotheses_defaut = codes[valorise],
                         stringsAsFactors = FALSE)
  # dossiers clos sous une hypothèse de la vue (S2) : unités restituées à 0, jugement_expert
  # (aucun capital calculé ; § 5.8, errata v1.0.17 et v1.0.18, E17-2, E18-1)
  dossiers <- rbind(dossiers, data.frame(id_dossier = clos$id_dossier, id_sinistre = clos$id_sinistre,
                                         garantie = rep(garantie, nc), referentiel = rep(.REFERENTIEL_B2, nc),
                                         poste = rep(poste, nc), etat = clos$etat,
                                         date_entree_etat = clos$date_entree_etat,
                                         montant = rep(0, nc), methode = rep(methode, nc),
                                         statut_resultat = rep("jugement_expert", nc), hypotheses_defaut = codes_clos,
                                         stringsAsFactors = FALSE))
  dossiers <- dossiers[order(dossiers$id_dossier, method = "radix"), COLONNES_DOSSIERS, drop = FALSE]
  rownames(dossiers) <- NULL
  e <- vap$echeancier
  echeanciers <- data.frame(cle = e$cle, referentiel = rep(.REFERENTIEL_B2, nrow(e)), poste = rep(poste, nrow(e)),
                            date = e$date, etat = e$etat, type_flux = e$type_flux, flux = e$flux,
                            probabilite = e$probabilite, actualisation = e$actualisation,
                            valeur_actuelle = e$valeur_actuelle, stringsAsFactors = FALSE)[COLONNES_ECHEANCIERS]
  # indicateurs R132_3_1 : années de taux_par_annee employées par les facteurs du poste
  annees <- .annees_employees(etats, calc, prestations, vue, a, rv$taux_par_annee)
  if (length(annees)) {
    st <- plan$tables$serie_tme
    indicateurs <- rbind(indicateurs,
                         indicateur_r132_3_1(tables$serie_tme, annees, st$decalage_publication_mois,
                                             unname(rv$taux_par_annee[as.character(annees)]), poste, garantie,
                                             valeurs_vue(vue, "extraction", "type_organisme")))
  }
  echus <- calc$id_dossier[calc$horizon_echu & calc$solde > 0]
  if (length(echus)) {
    indicateurs <- rbind(indicateurs, data.frame(regle = "depot_cdc_echu", poste = poste, garantie = garantie,
                                                 valeur_regle = NA_real_, valeur_retenue = NA_real_, depassement = TRUE,
                                                 detail = paste0("id_dossier=", echus, ";facteur_horizon=1"),
                                                 stringsAsFactors = FALSE))
  }
  rownames(indicateurs) <- NULL
  total <- if (nv) sum(sort(montant)) else 0
  cel <- .cellule(garantie, poste, ligne_cat$famille, ligne_cat$provision_comptes_sociaux, total, nv + nc, methode,
                  statut_methode, statut_le_plus_faible(c(statut, rep("jugement_expert", nc))), NA_character_)
  list(cellules = cel, dossiers = dossiers, echeanciers = echeanciers, indicateurs = indicateurs)
}

# Section revalorisation$capital_deces du plan, `taux_par_annee` lu en double nommé par année :
# le plan canonique (canoniser_plan(), fiche de calcul, rejeu) le porte en liste nommée de
# doubles triée par année (ecrire_liste() n'écrit pas un vecteur portant des noms), un plan
# seulement validé en double nommé ; les deux formes donnent le même vecteur (#67).
.revalorisation_plan <- function(plan) {
  rv <- plan$revalorisation$capital_deces
  t <- rv$taux_par_annee
  if (is.list(t)) {
    rv$taux_par_annee <- stats::setNames(vapply(t, function(x) x, 0, USE.NAMES = FALSE), names(t))
  }
  rv
}

# Années de taux_par_annee employées par les facteurs de revalorisation du poste : années
# civiles qui coupent (survenance, A], (règlement, A] des prestations capital des dossiers et
# (A, horizon] des méthodes « règlement », restreintes aux années déclarées ; triées.
.annees_employees <- function(etats, calc, prestations, vue, a, taux_par_annee) {
  if (nrow(etats) == 0L) return(integer(0))
  debuts <- c(as.numeric(etats$date_entree_etat))
  fins <- rep(as.numeric(a), nrow(etats))
  k <- prestations[valeurs_vue(vue, "prestations", "type_prestation")[prestations] %in% "capital" &
                     !is.na(apparier_cles(valeurs_vue(vue, "prestations", "id_dossier")[prestations], etats$id_dossier))]
  if (length(k)) {
    debuts <- c(debuts, as.numeric(valeurs_vue(vue, "prestations", "date_reglement")[k]))
    fins <- c(fins, rep(as.numeric(a), length(k)))
  }
  h <- as.numeric(calc$horizon)
  apres <- !is.na(calc$montant) & h > as.numeric(a)
  debuts <- c(debuts, rep(as.numeric(a), sum(apres)))
  fins <- c(fins, h[apres])
  # une année n'est employée que si l'intervalle y a au moins un jour (fin de journée)
  p <- .parts_annuelles(structure(debuts, class = "Date"), structure(fins, class = "Date"), "exact_exact")
  ans <- intersect(sort(unique(p$annee)), as.integer(names(taux_par_annee)))
  as.integer(ans)
}
