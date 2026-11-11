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
# plus faible de ses dossiers ou contrats, spécification de B2, § 7.7) ; lus aussi par
# `risque_en_cours`.
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
  if (!is.list(actualisation) || !(identical(actualisation$type, "aucune") || identical(actualisation$type, "taux"))) {
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
# $parametres ; spécification de B2, § 5.3, erratum v1.0.7). Sans point : seule lecture des
# paramètres d'une garantie souscrite, lue aussi par `risque_en_cours` (sans `famille`) ; non
# exportée.
parametre_vue <- function(vue, nom, gs, famille = NULL) {
  id <- valeurs_vue(vue, "parametres", "id_garantie_souscrite")
  k <- which(valeurs_vue(vue, "parametres", "parametre") %in% nom & !is.na(id))
  z <- lapply(split(valeurs_vue(vue, "parametres", "valeur")[k], as.character(id[k])), unique)
  i <- match(as.character(gs), names(z))
  n <- lengths(z, use.names = FALSE)[i]
  valeur <- vapply(z, function(x) if (length(x) == 1L) as.numeric(x) else NA_real_, 0, USE.NAMES = FALSE)[i]
  res <- list(valeur = valeur, ambigu = !is.na(i) & n > 1L)
  if (!is.null(famille)) {
    res$exclu <- as.character(gs) %in% as.character(id[k][vue$exclu[[famille]]$parametres[k]])
  }
  res
}

# Capital reconstitué des dossiers `ouvert` (spécification de B2, § 5.3) : `etats` (lignes de
# etats_a_date()) ; `parametres` : paramètres du poste (plan). capital_forfaitaire s'il est
# présent ; sinon assiette (salaire_reference de l'affiliation retenue de l'assuré du sinistre
# sous le contrat de la garantie, dont [date_debut ; date_fin] contient la survenance) x
# taux_capital + majorations (affiliations exclues pour la famille « engagement »,
# vue$exclu$engagement$affiliations, hors du choix : une affiliation exclue ne couvre rien) :
# instruit, famille retenue rattachée au sinistre (un conjoint
# vivant à la survenance, de lien déclaré, ouvre majoration_conjoint ; chaque enfant vivant à la
# survenance d'âge inférieur à age_limite_enfant_majoration, ou a_naitre, ou handicape, ouvre
# majoration_enfant) ; non instruit, structure_familiale du plan (espérance, jugement
# d'expert) ; une majoration absente vaut 0. Rend data.frame (capital, structure, arret,
# identifiant) : `structure` vrai si la structure familiale du plan entre dans le montant ;
# `arret` : motif d'arrêt du poste né du dossier (affiliation_non_determinee : aucune ou
# plusieurs affiliations couvrent la survenance ; parametre_non_determine : taux_capital et
# capital_forfaitaire absents, ou paramètre lu à plusieurs valeurs ou dont une ligne retenue
# est exclue pour engagement, erratum v1.0.7 ; assiette_non_determinee :
# salaire de l'affiliation manquant ; famille_non_determinee : dossier instruit dont une ligne
# de famille rattachée au sinistre est exclue pour engagement, ou dont un enfant vivant a un
# âge inconnu sans situation a_naitre ou handicape, erratum v1.0.6), NA sinon.
.reconstituer_capital <- function(vue, etats, parametres, conventions) {
  n <- nrow(etats)
  res <- data.frame(capital = rep(NA_real_, n), structure = rep(FALSE, n), arret = rep(NA_character_, n),
                    stringsAsFactors = FALSE)
  if (n == 0L) return(res)
  vv <- function(t, c1) valeurs_vue(vue, t, c1)
  i_dos <- match(etats$id_dossier, vv("dossiers", "id_dossier"), incomparables = NA)
  gs <- vv("dossiers", "id_garantie_souscrite")[i_dos]
  i_sin <- match(etats$id_sinistre, vv("sinistres", "id_sinistre"), incomparables = NA)
  assure <- vv("sinistres", "id_assure")[i_sin]
  survenance <- as.numeric(etats$date_entree_etat)
  contrat <- vv("garanties_souscrites", "id_contrat")[match(gs, vv("garanties_souscrites", "id_garantie_souscrite"),
                                                            incomparables = NA)]
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
  if (length(a_calculer) == 0L) return(res)
  # assiette : affiliation retenue, non exclue pour la famille, de l'assuré sous le contrat,
  # couvrant la survenance ; jointure par clé (assuré, contrat), sans produit croisé
  af_assure <- as.character(vv("affiliations", "id_assure"))
  af_contrat <- as.character(vv("affiliations", "id_contrat"))
  af_debut <- as.numeric(vv("affiliations", "date_debut"))
  af_fin <- as.numeric(vv("affiliations", "date_fin"))
  af_fin[is.na(af_fin)] <- Inf
  salaire <- vv("affiliations", "salaire_reference")
  af_ok <- which(!is.na(af_assure) & !is.na(af_contrat) & !is.na(af_debut) & !vue$exclu$engagement$affiliations)
  par_cle <- split(af_ok, paste(af_assure[af_ok], af_contrat[af_ok], sep = "\r"))
  cand <- par_cle[paste(as.character(assure[a_calculer]), as.character(contrat[a_calculer]), sep = "\r")]
  cand[vapply(cand, is.null, NA) | is.na(assure[a_calculer]) | is.na(contrat[a_calculer])] <- list(integer(0))
  ii <- rep(seq_along(a_calculer), lengths(cand))
  kk <- unlist(cand, use.names = FALSE)
  couvre <- af_debut[kk] <= survenance[a_calculer][ii] & af_fin[kk] >= survenance[a_calculer][ii]
  nb <- tabulate(ii[couvre], nbins = length(a_calculer))
  k1 <- rep(NA_integer_, length(a_calculer))
  k1[ii[couvre]] <- kk[couvre]
  assiette <- rep(NA_real_, n)
  res$arret[a_calculer[nb != 1L]] <- "affiliation_non_determinee"
  un <- nb == 1L
  sal <- salaire[k1[un]]
  res$arret[a_calculer[un][is.na(sal)]] <- "assiette_non_determinee"
  assiette[a_calculer[un]] <- sal
  a_calculer <- a_calculer[is.na(res$arret[a_calculer])]
  if (length(a_calculer) == 0L) return(res)
  mc0 <- ifelse(is.na(mc$valeur), 0, mc$valeur)
  me0 <- ifelse(is.na(me$valeur), 0, me$valeur)
  base <- assiette * taux$valeur
  instruit <- etats$instruit
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
# A + 1), statut du dossier. `prestations` : lignes de la vue non exclues (indices). Rend un
# data.frame, une ligne par dossier.
capital_deces_dossier <- function(vue, plan, etats, methode, parametres, prestations) {
  horizon <- .HORIZONS[[methode]]
  a <- vue$bilan$vue$date_arrete
  rv <- plan$revalorisation$capital_deces
  conventions <- plan$conventions
  n <- nrow(etats)
  rec <- .reconstituer_capital(vue, etats[etats$etat_dossier == "ouvert", , drop = FALSE], parametres, conventions)
  capital <- etats$montant_en_vigueur
  structure_f <- rep(FALSE, n)
  arret <- rep(NA_character_, n)
  ouvert <- etats$etat_dossier == "ouvert"
  capital[ouvert] <- rec$capital
  structure_f[ouvert] <- rec$structure
  arret[ouvert] <- rec$arret
  issue <- rep(1, n)
  issue[ouvert & etats$etat %in% "deces"] <- 1 - parametres$taux_sans_suite
  issue[ouvert & etats$etat %in% "iad"] <- parametres$probabilite_reconnaissance_iad
  res <- data.frame(id_dossier = etats$id_dossier, capital = capital, issue = issue, structure = structure_f,
                    arret = arret, solde = rep(NA_real_, n), montant = rep(NA_real_, n),
                    date_flux = structure(rep(as.numeric(a) + 1, n), class = "Date"),
                    horizon = structure(rep(as.numeric(a), n), class = "Date"), horizon_echu = rep(FALSE, n),
                    stringsAsFactors = FALSE)
  ok <- which(is.na(arret))
  if (length(ok) == 0L) return(res)
  taux_futur <- rv$taux_futur
  f <- function(debut, fin) facteur_revalorisation(debut, fin, rv$taux_par_annee, rv$prorata, conventions, a, taux_futur)
  solde <- capital[ok] * f(etats$date_entree_etat[ok], a)
  # prestations capital retenues du dossier (paiements et régularisations, signées)
  pid <- valeurs_vue(vue, "prestations", "id_dossier")[prestations]
  ptype <- valeurs_vue(vue, "prestations", "type_prestation")[prestations]
  k <- prestations[ptype %in% "capital"]
  if (length(k)) {
    pm <- valeurs_vue(vue, "prestations", "montant")[k]
    pr <- valeurs_vue(vue, "prestations", "date_reglement")[k]
    j <- match(as.character(valeurs_vue(vue, "prestations", "id_dossier")[k]), etats$id_dossier[ok])
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
      decl <- valeurs_vue(vue, "sinistres", "date_declaration")[match(etats$id_sinistre[ok],
                                                                      valeurs_vue(vue, "sinistres", "id_sinistre"),
                                                                      incomparables = NA)]
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
# motifs nés de la famille : affiliation_non_determinee, parametre_non_determine,
# assiette_non_determinee, famille_non_determinee) : cellule `arrete`, montant et nombre de
# dossiers NA, aucun dossier ni échéancier ; le premier dossier en cause est l'attribut `identifiant_arret` de la cellule.
# Population (§ 5.3, § 5.4) : dossiers de etats_a_date(vue, "deces", "engagement") non exclus pour la
# famille engagement, non clos ; P2 = ceux qui remplissent le critère du plan (réunion), P1 =
# les autres ; un dossier de solde au plus nul n'entre pas dans `dossiers`. Indicateurs : une
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
  arreter <- function(motif, identifiant) {
    cel <- .cellule(garantie, poste, ligne_cat$famille, ligne_cat$provision_comptes_sociaux, NA_real_, NA_integer_,
                    methode, statut_methode, NA_character_, motif)
    attr(cel, "identifiant_arret") <- identifiant
    list(cellules = cel, dossiers = .dossiers_vides(), echeanciers = .echeancier_vide(), indicateurs = indicateurs)
  }
  # arrêt de poste lu sur le bilan (M239)
  pa <- postes_a_arreter(catalogue, vue$bilan, plan$postes, parties_ligne())$postes
  motif_bilan <- pa$motif_arret[pa$garantie == garantie & pa$poste == poste]
  if (length(motif_bilan) == 1L && !is.na(motif_bilan)) return(arreter(motif_bilan, NA_character_))

  a <- vue$bilan$vue$date_arrete
  etats <- etats_a_date(vue, garantie, "engagement")
  i_dos <- match(etats$id_dossier, valeurs_vue(vue, "dossiers", "id_dossier"), incomparables = NA)
  exclu <- vue$exclu$engagement
  garde <- !exclu$dossiers[i_dos] & etats$etat_dossier != "clos"
  etats <- etats[garde, , drop = FALSE]
  # partition P1 / P2 selon le critère de P2 (réunion des critères déclarés)
  p2 <- plan$postes[[garantie]]$capitaux_non_reclames$parametres
  non_reclame <- rep(FALSE, nrow(etats))
  if ("beneficiaire_non_identifie" %in% p2$critere) {
    b <- which(vue$retenu$beneficiaires & !exclu$beneficiaires)
    ni <- valeurs_vue(vue, "beneficiaires", "id_dossier")[b][valeurs_vue(vue, "beneficiaires", "qualite")[b] %in% "non_identifie"]
    non_reclame <- non_reclame | etats$id_dossier %in% as.character(ni)
  }
  if ("sans_evenement" %in% p2$critere) {
    seuil <- ajouter_mois(a, -as.integer(p2$mois_sans_evenement))
    e <- which(vue$retenu$evenements & !exclu$evenements)
    recent <- as.numeric(valeurs_vue(vue, "evenements", "date_effet")[e]) > seuil
    actifs <- as.character(valeurs_vue(vue, "evenements", "id_dossier")[e][recent %in% TRUE])
    ouverture <- as.numeric(valeurs_vue(vue, "dossiers", "date_ouverture"))[match(etats$id_dossier,
                                                                                    valeurs_vue(vue, "dossiers", "id_dossier"))]
    non_reclame <- non_reclame | (!(etats$id_dossier %in% actifs) & (ouverture <= seuil) %in% TRUE)
  }
  etats <- etats[if (poste == "capitaux_non_reclames") non_reclame else !non_reclame, , drop = FALSE]
  # couverture de taux_par_annee : chaque année de la survenance la plus ancienne à l'arrêté
  rv <- plan$revalorisation$capital_deces
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
  calc <- capital_deces_dossier(vue, plan, etats, methode, parametres, prestations)
  arret <- which(!is.na(calc$arret))
  if (length(arret)) return(arreter(calc$arret[arret[1L]], calc$id_dossier[arret[1L]]))
  # invariant (spécification de B2, § 4.3) : aucun dossier valorisé à instruction inconnue
  if (anyNA(etats$instruit)) {
    stop("erreur interne de provie : dossier valoris\u00e9 \u00e0 instruction inconnue (", etats$id_dossier[is.na(etats$instruit)][1L],
         ")", call. = FALSE)
  }
  valorise <- which(calc$solde > 0)
  et <- etats[valorise, , drop = FALSE]
  cc <- calc[valorise, , drop = FALSE]
  nv <- length(valorise)
  ech <- data.frame(cle = rep(cc$id_dossier, each = 2L), date = rep(cc$date_flux, each = 2L), etat = rep(et$etat, each = 2L),
                    type_flux = rep(c("capital_unique", "frais"), nv),
                    flux = as.vector(rbind(cc$montant, frais * cc$montant)), probabilite = rep(cc$issue, each = 2L),
                    stringsAsFactors = FALSE)
  vap <- valeur_actuelle_probable(ech, list(type = "aucune"), plan$conventions)
  montant <- vap$valeurs$valeur_actuelle[match(cc$id_dossier, vap$valeurs$cle)]
  reglement <- .HORIZONS[[methode]] != "arrete"
  statut <- ifelse(reglement | cc$structure | cc$issue < 1, "jugement_expert", "exact")
  dossiers <- data.frame(id_dossier = cc$id_dossier, id_sinistre = et$id_sinistre, garantie = rep(garantie, nv),
                         referentiel = rep(.REFERENTIEL_B2, nv), poste = rep(poste, nv), etat = et$etat,
                         date_entree_etat = et$date_entree_etat, montant = if (nv) montant else numeric(0),
                         methode = rep(methode, nv), statut_resultat = statut, hypotheses_defaut = rep("", nv),
                         stringsAsFactors = FALSE)
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
  cel <- .cellule(garantie, poste, ligne_cat$famille, ligne_cat$provision_comptes_sociaux, total, nv, methode,
                  statut_methode, statut_le_plus_faible(statut), NA_character_)
  list(cellules = cel, dossiers = dossiers, echeanciers = echeanciers, indicateurs = indicateurs)
}

# Années de taux_par_annee employées par les facteurs de revalorisation du poste : années
# civiles qui coupent (survenance, A], (règlement, A] des prestations capital des dossiers et
# (A, horizon] des méthodes « règlement », restreintes aux années déclarées ; triées.
.annees_employees <- function(etats, calc, prestations, vue, a, taux_par_annee) {
  if (nrow(etats) == 0L) return(integer(0))
  debuts <- c(as.numeric(etats$date_entree_etat))
  fins <- rep(as.numeric(a), nrow(etats))
  k <- prestations[valeurs_vue(vue, "prestations", "type_prestation")[prestations] %in% "capital" &
                     as.character(valeurs_vue(vue, "prestations", "id_dossier")[prestations]) %in% etats$id_dossier]
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
