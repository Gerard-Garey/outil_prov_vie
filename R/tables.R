# Module `tables` (ADR 0009 ; ADR 0010, points 1, 13 et 15 ; spécification de B2,
# docs/specifications/b2-capital-deces-v1.md, § 3) : formats des tables en entrée,
# représentation commune `table_provie` et son accès unique probabilite(), conversions
# nommées depuis les formats natifs, résolution des tables par usage avec contrôle
# d'empreinte, indicateurs réglementaires R132_3_1 et A132_1 sur la série TME.
# Aucune table n'est embarquée en B2 (décision du mainteneur du 10 novembre 2026, § 3.1) :
# charger_table() n'existe pas encore, les tables arrivent par lecture::lire_table() ou
# construites en mémoire par construire_table().
# N'appelle que le module `outils` (graphe du point 1). Ne parle pas (point 12), hors des
# méthodes print.* et format.*. Code ASCII hors commentaires (M112).
# Convention de ce fichier : une fonction dont le nom commence par un point est un
# auxiliaire du module ; la concordance documentation <-> code ne recense que les autres.

# --- Constantes ------------------------------------------------------------------

# Statuts d'une table (ADR 0010, point 15, et annotation de la spécification de B2, § 3.3 :
# `fictive` pour une table de test, qui ne se présente jamais comme une table d'expérience)
# et comportements hors des axes (déclaration du plan, sans défaut) ; lus aussi par `plan`.
STATUTS_TABLE <- c("homologuee", "certifiee", "experience", "loi_anc", "fictive")
HORS_AXES <- c("refus", "derniere_valeur")
# Colonnes d'une ligne d'indicateur (ADR 0010, point 6, champ `indicateurs`), dans cet ordre.
COLONNES_INDICATEURS <- c("regle", "poste", "garantie", "valeur_regle", "valeur_retenue", "depassement",
                          "detail")
# Colonnes des lignes de fiche$parametres_retenus$tables (spécification de B2, § 3.4) : les
# mêmes que plan::COLONNES_TABLES_RETENUES, que `tables` ne peut pas lire (le test du
# module vérifie l'égalité).
.COLONNES_TABLES_RESOLUES <- c("usage", "garantie", "identifiant", "statut", "format_natif", "provenance",
                               "conversion", "empreinte")
# Paramètres des règles (spécification de B2, § 3.5 ; textes vérifiés en 0a) :
#   R132-3-1 : douze derniers mois disponibles au 1er novembre de l'année précédente ;
#   A132-1 : TME semestriel (six derniers mois disponibles) ; 75 % (prime unique, durée au
#   plus huit ans), sinon min(3,5 % ; 60 %) ; échelle d'A132-1-1 (erratum v1.0.2, contrôle
#   de conformité de regulatory du 11 novembre 2026) : plafond au pas de 0,25 point, sans
#   descendre en dessous de 0, inchangé tant que T - 0,10 point < référence < T + 0,35 point ;
#   à la sortie de cet intervalle, le nouveau plafond est le point de l'échelle
#   immédiatement inférieur au taux de référence mensuel ;
#   comparaisons de A132_1 et R132_3_1 à 1e-12 près (approximation numérique : très au-dessus
#   de l'erreur d'arrondi binaire, moins de 1e-15 sur des taux de l'ordre de 0,05, très
#   au-dessous de la résolution des taux, de l'ordre de 1e-5 ; aucun arrondi n'est prescrit par
#   A132-1, A132-1-1 ni R132-3-1, lecture de regulatory).
.MOIS_R132_3_1 <- 12L
.MOIS_A132_1 <- 6L
.PART_A132_1_UNIQUE_COURTE <- 0.75
.PART_A132_1_AUTRE <- 0.60
.PLAFOND_A132_1_AUTRE <- 0.035
.DUREE_A132_1_ANNEES <- 8L
.ECART_HAUT_A132_1_1 <- 0.0010
.ECART_BAS_A132_1_1 <- 0.0035
.PAS_ECHELLE_A132_1_1 <- 0.0025
.TOLERANCE_INDICATEURS <- 1e-12
.NATURES_PRIMES <- c("unique", "periodique")

# --- Formats admis ------------------------------------------------------------------

# Formats de tables admis en B2 (spécification de B2, § 3.2) : un data.frame (format,
# nature, colonnes et types joints par « ; », description, conversion : fonction nommée de
# `tables` qui convertit le format natif en table_provie).
formats_tables <- function() {
  data.frame(
    format = c("lx_age", "serie_tme_mensuelle"),
    nature = c("mortalite", "taux"),
    colonnes = c("age;lx", "mois;taux_pourcent"),
    types = c("integer;numeric", "character;numeric"),
    description = c(
      paste0("Table de mortalit\u00e9 en effectifs de survivants : \u00e2ges entiers cons\u00e9cutifs croissants ;",
             " lx fini, positif ou nul, non croissant, le premier strictement positif"),
      paste0("S\u00e9rie mensuelle de taux en pourcentage (mois AAAA-MM cons\u00e9cutifs croissants, sans",
             " doublon ; valeurs finies, n\u00e9gatives admises)")),
    conversion = c("convertir_lx_qx", "convertir_pourcent"),
    stringsAsFactors = FALSE)
}

.refus_format <- function(message, ...) refuser(message, "format_table_inconnu", module = "tables", ...)

# Ligne du format `format` dans formats_tables() ; refus format_table_inconnu hors liste.
.ligne_format <- function(format) {
  formats <- formats_tables()
  if (!(is.character(format) && length(format) == 1L && !is.na(format) && format %in% formats$format)) {
    .refus_format(paste0("format de table hors de la liste (", paste(formats$format, collapse = ", "), ")"),
                  recu = if (is.character(format) && length(format) == 1L) format else NA_character_)
  }
  ligne <- formats[formats$format == format, , drop = FALSE]
  list(format = format, nature = ligne$nature, colonnes = strsplit(ligne$colonnes, ";", fixed = TRUE)[[1L]],
       types = strsplit(ligne$types, ";", fixed = TRUE)[[1L]], conversion = ligne$conversion)
}

# --- Construction d'une table_provie -------------------------------------------------

# Construit une table_provie (ADR 0010, point 15) depuis le contenu lu d'une table au format
# natif `format` : `donnees`, data.frame aux colonnes du format, dans son ordre et dans ses
# types (aucune conversion de type) ; `identifiant`, chaîne ; `statut`, un élément de
# STATUTS_TABLE ; `provenance`, chaîne déclarée (source de la table, ou « table fictive, sans
# source »). Refus : liste_invalide (argument mal formé), format_table_inconnu (format hors
# liste, colonnes autres que celles du format, contrainte du format violée : le message
# nomme la contrainte et la première ligne), type_incompatible (colonne d'un autre type).
# origine$empreinte : MD5 de l'écriture canonique du contenu (ecrire_valeurs(forme =
# "octets") du nom puis des valeurs de chaque colonne du format, dans son ordre), indépendant
# de la mise en forme d'un fichier : une table lue d'un fichier et la même construite en
# mémoire ont la même empreinte (annotation de la spécification de B2, § 3.3).
construire_table <- function(donnees, format, identifiant, statut, provenance) {
  f <- .ligne_format(format)
  .controler_chaine_table(identifiant, "identifiant")
  .controler_chaine_table(provenance, "provenance")
  if (!(is.character(statut) && length(statut) == 1L && !is.na(statut) && statut %in% STATUTS_TABLE)) {
    refuser(paste0("table ", identifiant, " : `statut` hors de la liste (", paste(STATUTS_TABLE, collapse = ", "), ")"),
            "liste_invalide", module = "tables", usage = identifiant)
  }
  if (!is.data.frame(donnees)) {
    refuser(paste0("table ", identifiant, " : `donnees` doit \u00eatre un data.frame"), "liste_invalide",
            module = "tables", usage = identifiant)
  }
  if (!identical(names(donnees), f$colonnes)) {
    .refus_format(paste0("table ", identifiant, " (format ", f$format, ") : colonnes attendues, dans cet ordre : ",
                         paste(f$colonnes, collapse = ", "), " ; re\u00e7ues : ", paste(names(donnees), collapse = ", ")),
                  usage = identifiant)
  }
  for (k in seq_along(f$colonnes)) {
    x <- donnees[[k]]
    conforme <- is.null(attributes(x)) && switch(f$types[k],
      integer = is.integer(x), numeric = is.double(x), character = is.character(x))
    if (!conforme) {
      refuser(paste0("table ", identifiant, " (format ", f$format, ") : colonne ", f$colonnes[k], " de type ",
                     class(x)[1L], " ; type attendu : ", f$types[k], " (aucune conversion)"),
              "type_incompatible", module = "tables", colonne = f$colonnes[k], usage = identifiant,
              attendu = f$types[k], recu = class(x)[1L])
    }
  }
  converti <- switch(f$format,
    lx_age = {
      .controler_lx_age(donnees$age, donnees$lx, identifiant)
      convertir_lx_qx(donnees$age, donnees$lx)
    },
    serie_tme_mensuelle = {
      .controler_serie_mensuelle(donnees$mois, donnees$taux_pourcent, identifiant)
      convertir_pourcent(donnees$mois, donnees$taux_pourcent)
    })
  octets <- unlist(lapply(f$colonnes, function(k) {
    list(ecrire_valeurs(k, "octets"), ecrire_valeurs(donnees[[k]], "octets"))
  }), recursive = FALSE)
  structure(list(
    identifiant = identifiant,
    nature = f$nature,
    axes = converti$axes,
    pas = converti$pas,
    valeurs = converti$valeurs,
    statut = statut,
    origine = list(format_natif = f$format, provenance = provenance, conversion = f$conversion,
                   empreinte = empreinte(do.call(c, octets)))),
    class = "table_provie")
}

.controler_chaine_table <- function(x, nom) {
  if (!(is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x) && is.null(attributes(x)))) {
    refuser(paste0("table : `", nom, "` doit \u00eatre une cha\u00eene non vide"), "liste_invalide", module = "tables")
  }
  invisible(NULL)
}

# Contraintes du format lx_age (spécification de B2, § 3.2) ; refus à la première ligne
# (rang de la ligne de données) qui en viole une.
.controler_lx_age <- function(age, lx, identifiant) {
  refus <- function(contrainte, ligne) {
    .refus_format(paste0("table ", identifiant, " (format lx_age) : ", contrainte, ", ligne ", ligne),
                  usage = identifiant, identifiants = as.character(ligne))
  }
  n <- length(age)
  if (n < 2L) .refus_format(paste0("table ", identifiant, " (format lx_age) : au moins deux \u00e2ges attendus"),
                            usage = identifiant)
  if (anyNA(age)) refus("\u00e2ge manquant", which(is.na(age))[1L])
  if (age[1L] < 0L) refus("\u00e2ge n\u00e9gatif", 1L)
  saut <- which(diff(age) != 1L)
  if (length(saut) > 0L) refus("\u00e2ges entiers cons\u00e9cutifs croissants attendus", saut[1L] + 1L)
  if (any(!is.finite(lx))) refus("lx manquant ou non fini", which(!is.finite(lx))[1L])
  if (any(lx < 0)) refus("lx n\u00e9gatif", which(lx < 0)[1L])
  if (!(lx[1L] > 0)) refus("premier lx nul ; strictement positif attendu", 1L)
  hausse <- which(diff(lx) > 0)
  if (length(hausse) > 0L) refus("lx croissant ; non croissant attendu", hausse[1L] + 1L)
  invisible(NULL)
}

# Contraintes du format serie_tme_mensuelle (spécification de B2, § 3.2).
.controler_serie_mensuelle <- function(mois, taux, identifiant) {
  refus <- function(contrainte, ligne) {
    .refus_format(paste0("table ", identifiant, " (format serie_tme_mensuelle) : ", contrainte, ", ligne ", ligne),
                  usage = identifiant, identifiants = as.character(ligne))
  }
  if (length(mois) < 1L) {
    .refus_format(paste0("table ", identifiant, " (format serie_tme_mensuelle) : au moins un mois attendu"),
                  usage = identifiant)
  }
  forme <- !is.na(mois) & grepl("^[0-9]{4}-(0[1-9]|1[0-2])$", mois)
  if (!all(forme)) refus("mois AAAA-MM attendu", which(!forme)[1L])
  rang <- .rang_mois(mois)
  double <- which(duplicated(rang))
  if (length(double) > 0L) refus("mois en double", double[1L])
  saut <- which(diff(rang) != 1L)
  if (length(saut) > 0L) refus("mois cons\u00e9cutifs croissants attendus", saut[1L] + 1L)
  if (any(!is.finite(taux))) refus("taux manquant ou non fini", which(!is.finite(taux))[1L])
  invisible(NULL)
}

# Rang d'un mois AAAA-MM sur l'axe `date` d'une série mensuelle : 12 x année + mois - 1
# (annotation de la spécification de B2, § 9, point 7).
.rang_mois <- function(mois) {
  12L * as.integer(substr(mois, 1L, 4L)) + as.integer(substr(mois, 6L, 7L)) - 1L
}

# Rang de l'axe `date` du mois d'une Date.
.rang_date <- function(date) {
  lt <- as.POSIXlt(date)
  12L * (lt$year + 1900L) + lt$mon
}

# --- Conversions nommées ------------------------------------------------------------

# Conversion du format lx_age (spécification de B2, § 3.2 ; résultat exact) :
# q_x = 1 - l_{x+1} / l_x pour chaque âge x sauf le dernier ; axe `age` = ces âges ; un l_x
# nul rend hors des axes cet âge et les suivants (q_x n'y est pas défini). `age` et `lx`
# contrôlés au préalable (.controler_lx_age()). Rend list(axes, pas, valeurs).
convertir_lx_qx <- function(age, lx) {
  definis <- sum(lx[-length(lx)] > 0)
  rangs <- seq_len(definis)
  list(axes = list(age = age[rangs]), pas = "an",
       valeurs = array(1 - lx[rangs + 1L] / lx[rangs], dim = definis))
}

# Conversion du format serie_tme_mensuelle (spécification de B2, § 3.2) : valeur / 100 ;
# axe `date` = 12 x année + mois - 1. Rend list(axes, pas, valeurs).
convertir_pourcent <- function(mois, taux_pourcent) {
  list(axes = list(date = .rang_mois(mois)), pas = "mois",
       valeurs = array(taux_pourcent / 100, dim = length(taux_pourcent)))
}

# --- Accès ----------------------------------------------------------------------------

# Seul accès aux valeurs d'une table_provie (ADR 0010, point 15), vectorisé : `...` porte un
# vecteur entier par axe de la table, nommé comme ses axes et dans leur ordre (mortalité :
# age ; série de taux : date, rang 12 x année + mois - 1), de même longueur. `hors_axes`,
# déclaration du plan (un élément de HORS_AXES), sans défaut : exigé dès qu'un point est hors
# des axes (une erreur sinon) ; `refus` rend NA en ce point, `derniere_valeur` la valeur du
# point de l'axe le plus proche. Rend un vecteur double portant l'attribut `hors_axes` :
# indices des points hors des axes (integer(0) si aucun), que l'appelant lit pour arrêter le
# poste (motif d'arrêt hors_axes, spécification de B2, § 6.2).
probabilite <- function(table, ..., hors_axes) {
  if (!inherits(table, "table_provie")) stop("probabilite() : `table` doit \u00eatre une table_provie", call. = FALSE)
  points <- list(...)
  if (!identical(names(points), names(table$axes))) {
    stop(paste0("probabilite() : axes attendus, dans cet ordre : ", paste(names(table$axes), collapse = ", ")),
         call. = FALSE)
  }
  n <- unique(lengths(points))
  if (length(n) != 1L) stop("probabilite() : axes de longueurs diff\u00e9rentes", call. = FALSE)
  rangs <- matrix(0L, nrow = n, ncol = length(points))
  dehors <- rep(FALSE, n)
  for (k in seq_along(points)) {
    x <- points[[k]]
    axe <- table$axes[[k]]
    if (!is.numeric(x) || !is.null(dim(x)) || any(!is.finite(x)) || any(x != trunc(x))) {
      stop(paste0("probabilite() : axe ", names(points)[k], " : entiers finis attendus"), call. = FALSE)
    }
    r <- x - axe[1L] + 1
    dehors <- dehors | r < 1 | r > length(axe)
    rangs[, k] <- as.integer(pmin(pmax(r, 1), length(axe)))
  }
  if (any(dehors) || !missing(hors_axes)) {
    if (missing(hors_axes)) {
      stop("probabilite() : point hors des axes et `hors_axes` non d\u00e9clar\u00e9 (aucun d\u00e9faut)", call. = FALSE)
    }
    if (!(is.character(hors_axes) && length(hors_axes) == 1L && !is.na(hors_axes) && hors_axes %in% HORS_AXES)) {
      stop(paste0("probabilite() : `hors_axes` hors de la liste (", paste(HORS_AXES, collapse = ", "), ")"),
           call. = FALSE)
    }
  }
  valeurs <- as.vector(table$valeurs[rangs])
  if (any(dehors) && identical(hors_axes, "refus")) valeurs[dehors] <- NA_real_
  attr(valeurs, "hors_axes") <- which(dehors)
  valeurs
}

# --- Tables par usage ---------------------------------------------------------------

# Résout les tables des usages exigés (spécification de B2, § 3.4). `plan_tables` : section
# `tables` du plan validé (usage -> identifiant, empreinte, statut, hors_axes...) ;
# `tables_recues` : argument `tables` de calculer_provisions(), liste nommée par identifiant ;
# `usages_exiges` : data.frame (usage, garantie, nature) des usages lus par le périmètre,
# construit par l'appelant depuis le catalogue (usage commun serie_tme compris, nature taux),
# `tables` ne lisant pas le catalogue (graphe du point 1). Pour chaque usage, dans l'ordre
# trié (radix), refus : table_absente (usage sans entrée du plan, ou identifiant sans table
# reçue) ; liste_invalide (objet reçu qui n'est pas une table_provie) ;
# empreinte_discordante (empreinte du plan différente de origine$empreinte) ; plan_invalide
# (statut déclaré différent de celui de la table, ou nature de la table différente de celle
# de l'usage). Rend list(tables : liste nommée usage -> table_provie, triée ; parametres :
# data.frame des lignes de fiche$parametres_retenus$tables, une par ligne d'usages_exiges,
# triées par usage puis garantie).
resoudre_tables <- function(plan_tables, tables_recues, usages_exiges) {
  if (!is.data.frame(usages_exiges) || !identical(names(usages_exiges), c("usage", "garantie", "nature")) ||
      !all(vapply(usages_exiges, is.character, NA)) || anyNA(usages_exiges)) {
    stop("resoudre_tables() : `usages_exiges` doit \u00eatre un data.frame (usage, garantie, nature) de texte renseign\u00e9",
         call. = FALSE)
  }
  if (!is.list(plan_tables) || (length(plan_tables) > 0L && is.null(names(plan_tables)))) {
    stop("resoudre_tables() : `plan_tables` doit \u00eatre une liste nomm\u00e9e", call. = FALSE)
  }
  if (!is.list(tables_recues) || is.data.frame(tables_recues) ||
      (length(tables_recues) > 0L && (is.null(names(tables_recues)) || anyNA(names(tables_recues))))) {
    refuser("tables : `tables` doit \u00eatre une liste nomm\u00e9e par identifiant", "liste_invalide", module = "tables")
  }
  usages_exiges <- usages_exiges[order(usages_exiges$usage, usages_exiges$garantie, method = "radix"), , drop = FALSE]
  usages <- unique(usages_exiges$usage)
  resolues <- list()
  for (u in usages) {
    entree <- if (u %in% names(plan_tables)) plan_tables[[u]] else NULL
    if (is.null(entree)) {
      refuser(paste0("tables : usage ", u, " exig\u00e9 sans entr\u00e9e dans plan$tables"), "table_absente",
              module = "tables", usage = u)
    }
    id <- entree$identifiant
    if (!(id %in% names(tables_recues))) {
      refuser(paste0("tables : usage ", u, " : aucune table re\u00e7ue sous l'identifiant ", id), "table_absente",
              module = "tables", usage = u, attendu = id)
    }
    t <- tables_recues[[id]]
    if (!inherits(t, "table_provie")) {
      refuser(paste0("tables : usage ", u, " : la table ", id, " re\u00e7ue n'est pas une table_provie"), "liste_invalide",
              module = "tables", usage = u)
    }
    recue <- t$origine$empreinte
    if (!identical(entree$empreinte, recue)) {
      refuser(paste0("tables : usage ", u, " : empreinte de la table ", id, " diff\u00e9rente de celle du plan"),
              "empreinte_discordante", module = "tables", usage = u, attendu = entree$empreinte,
              recu = if (is.character(recue) && length(recue) == 1L) recue else NA_character_)
    }
    if (!identical(entree$statut, t$statut)) {
      refuser(paste0("plan : tables$", u, "$statut (", entree$statut, ") diff\u00e9rent du statut de la table ", id,
                     " (", t$statut, ")"), "plan_invalide", module = "tables", usage = u,
              attendu = paste0("tables$", u, "$statut"), recu = entree$statut)
    }
    natures <- unique(usages_exiges$nature[usages_exiges$usage == u])
    if (!identical(natures, t$nature)) {
      refuser(paste0("plan : tables$", u, " : la table ", id, " est de nature ", t$nature, " ; nature de l'usage : ",
                     paste(natures, collapse = ", ")), "plan_invalide", module = "tables", usage = u,
              attendu = paste0("tables$", u, "$identifiant"), recu = id)
    }
    resolues[[u]] <- t
  }
  t_ligne <- resolues[usages_exiges$usage]
  parametres <- data.frame(
    usage = usages_exiges$usage,
    garantie = usages_exiges$garantie,
    identifiant = vapply(t_ligne, function(t) t$identifiant, "", USE.NAMES = FALSE),
    statut = vapply(t_ligne, function(t) t$statut, "", USE.NAMES = FALSE),
    format_natif = vapply(t_ligne, function(t) t$origine$format_natif, "", USE.NAMES = FALSE),
    provenance = vapply(t_ligne, function(t) t$origine$provenance, "", USE.NAMES = FALSE),
    conversion = vapply(t_ligne, function(t) t$origine$conversion, "", USE.NAMES = FALSE),
    empreinte = vapply(t_ligne, function(t) t$origine$empreinte, "", USE.NAMES = FALSE),
    stringsAsFactors = FALSE)
  rownames(parametres) <- NULL
  list(tables = resolues, parametres = parametres)
}

# --- Indicateurs réglementaires -----------------------------------------------------

# Contrôles communs des fonctions d'indicateur (erreurs de programmation : les entrées
# viennent du plan validé et de la base contrôlée).
.controler_serie <- function(serie, fonction) {
  if (!inherits(serie, "table_provie") || !identical(serie$nature, "taux") || !identical(names(serie$axes), "date") ||
      !identical(serie$pas, "mois")) {
    stop(paste0(fonction, "() : `serie` doit \u00eatre une table_provie de nature taux, axe date, pas mensuel"),
         call. = FALSE)
  }
  invisible(NULL)
}

.controler_decalage <- function(decalage, fonction) {
  if (!(is.numeric(decalage) && length(decalage) == 1L && decalage %in% c(1, 2))) {
    stop(paste0(fonction, "() : `decalage` (tables$serie_tme$decalage_publication_mois) doit valoir 1 ou 2"),
         call. = FALSE)
  }
  invisible(NULL)
}

# Moyenne des `nombre` derniers mois disponibles dont le dernier est de rang `dernier`, et
# valeur du dernier mois ; NA si un mois manque (aucune valeur supposée).
.fenetre_serie <- function(serie, dernier, nombre) {
  rangs <- as.vector(outer(seq.int(1L - nombre, 0L), dernier, "+"))
  v <- matrix(probabilite(serie, date = rangs, hors_axes = "refus"), nrow = nombre)
  list(moyenne = colSums(v) / nombre, dernier = v[nombre, ])
}

# Minimum de R132-3-1 pour les années civiles `annee` (spécification de B2, § 3.5 ;
# R132-3-1, « le moins élevé », vérifié en 0a) : min(moyenne arithmétique des douze derniers
# mois disponibles au 1er novembre de l'année précédente ; dernier mois disponible à cette
# date), le dernier mois disponible à une date D étant le mois de D moins `decalage`
# (tables$serie_tme$decalage_publication_mois, hypothèse déclarée). Aucun plancher (I4 :
# un minimum négatif est rendu tel quel). NA si un mois de la fenêtre manque. Vectorisée
# sur `annee` ; rend un double.
minimum_r132_3_1 <- function(serie, annee, decalage) {
  .controler_serie(serie, "minimum_r132_3_1")
  .controler_decalage(decalage, "minimum_r132_3_1")
  if (!is.numeric(annee) || length(annee) < 1L || any(!is.finite(annee)) || any(annee != trunc(annee))) {
    stop("minimum_r132_3_1() : `annee` doit porter des ann\u00e9es enti\u00e8res", call. = FALSE)
  }
  # 1er novembre N - 1 : rang 12 (N - 1) + 10 ; dernier mois disponible : ce rang moins le décalage
  dernier <- as.integer(12L * (annee - 1L) + 10L - decalage)
  f <- .fenetre_serie(serie, dernier, .MOIS_R132_3_1)
  pmin(f$moyenne, f$dernier)
}

# Taux de référence d'A132-1 aux dates `date` (spécification de B2, § 3.5, version 1.0.2 ;
# A132-1 vérifié en 0a ; I2 lecture (i), I3 lecture (b)) : TME semestriel = moyenne des six
# derniers mois disponibles à la date (mois de la date moins `decalage`) ; 75 % de ce taux si
# `nature_primes` vaut "unique" et `duree_au_plus_8_ans` vaut TRUE, sinon min(3,5 % ; 60 %).
# Approximation (A4) : la série unique déclarée est assimilée au taux d'A132-1, alinéa 4 (le
# plus élevé du taux d'émission et du taux de rendement sur le marché secondaire), et à celui
# d'A132-1-1 (moyenne arithmétique sur les six derniers mois des taux observés sur les marchés
# primaire et secondaire) ; les deux lectures décrites par regulatory le
# 11 novembre 2026, (alpha) moyenne sur six mois du maximum mensuel, (beta) moyenne des
# marchés primaire et secondaire, ne sont pas tranchées.
# Échelle d'A132-1-1 (établie par regulatory) : le plafond en vigueur T reste inchangé tant
# que T - 0,10 point < référence < T + 0,35 point ; à la sortie de cet intervalle, le nouveau
# T est le point de l'échelle immédiatement inférieur au taux de référence mensuel. Tout
# point de l'ouvert ci-dessous peut donc être en vigueur : sans historique du plafond, T est
# l'un des multiples k x 0,25 point (k entier >= 0) de l'intervalle ouvert
# ]référence - 0,35 point ; référence + 0,10 point[, appartenance testée à 1e-12 près, et
# T = 0 si aucun n'y figure ; borne_basse et borne_haute = plus petit et plus grand de ces
# points (0 et 0 si aucun). Plafond de 3,5 % (#88, lecture (a), décision du mainteneur du
# 12 novembre 2026) : hors de la branche 75 %, l'échelle s'applique au taux de référence
# mensuel d'A132-1-1, 60 % du TME semestriel non plafonné, puis le plafond de 3,5 % d'A132-1
# s'applique aux deux bornes ; taux_reference reste min(3,5 % ; 60 %) (option (a2)), et
# reference_plafonnee_3_5 vaut TRUE quand 60 % du TME dépasse 3,5 % de plus de 1e-12 (FALSE
# dans la branche 75 %) : la mention décrit la convention (a2), taux_reference à 3,5 % au
# lieu de 60 % du TME, et ne dit pas que le plafond réglementaire change. Écart assumé avec
# pmin(), sans tolérance : si 60 % du TME est dans ]3,5 % ; 3,5 % + 1e-12], taux_reference
# est ramené à 3,5 % et la mention vaut FALSE ; taux_reference et 60 % du TME diffèrent alors
# d'au plus 1e-12, égaux à la tolérance des comparaisons de la règle, et les bornes ne
# changent pas. Délai de trois mois d'A132-1-1 : délai de grâce (lecture de regulatory), non
# pris en compte ; un dépassement signalé peut être un faux positif pour un
# contrat souscrit dans les trois mois qui suivent une baisse du plafond.
# `nature_primes` ("unique", "periodique" ou NA) et `duree_au_plus_8_ans` (logique, NA si le
# terme manque) : longueur de `date`, ou 1. Rend un data.frame (tme_semestriel,
# taux_reference : 75 % du TME dans la branche 75 %, sinon taux de référence mensuel
# plafonné à 3,5 % ; borne_basse, borne_haute, reference_plafonnee_3_5), une ligne par date ;
# taux_reference, bornes et reference_plafonnee_3_5 NA si un mois manque, si nature_primes
# manque, ou en prime unique si la durée manque (en primes périodiques, la branche
# min(3,5 % ; 60 %) ne dépend pas de la durée : erratum v1.0.2, écart E3 de regulatory).
plafond_a132_1 <- function(serie, date, nature_primes, duree_au_plus_8_ans, decalage) {
  .controler_serie(serie, "plafond_a132_1")
  .controler_decalage(decalage, "plafond_a132_1")
  if (!identical(class(date), "Date") || length(date) < 1L || anyNA(date)) {
    stop("plafond_a132_1() : `date` doit \u00eatre un vecteur de Date renseign\u00e9", call. = FALSE)
  }
  n <- length(date)
  if (!is.character(nature_primes) || !(length(nature_primes) %in% c(1L, n)) ||
      !all(is.na(nature_primes) | nature_primes %in% .NATURES_PRIMES)) {
    stop("plafond_a132_1() : `nature_primes` doit valoir \"unique\", \"periodique\" ou NA", call. = FALSE)
  }
  if (!is.logical(duree_au_plus_8_ans) || !(length(duree_au_plus_8_ans) %in% c(1L, n))) {
    stop("plafond_a132_1() : `duree_au_plus_8_ans` doit \u00eatre un vecteur logique", call. = FALSE)
  }
  nature_primes <- rep_len(nature_primes, n)
  duree_au_plus_8_ans <- rep_len(duree_au_plus_8_ans, n)
  tme <- .fenetre_serie(serie, .rang_date(date) - as.integer(decalage), .MOIS_A132_1)$moyenne
  connue <- !is.na(nature_primes) & (nature_primes == "periodique" | !is.na(duree_au_plus_8_ans))
  courte <- connue & nature_primes == "unique" & duree_au_plus_8_ans %in% TRUE
  autre <- connue & !courte
  mensuel <- rep(NA_real_, n)
  mensuel[courte] <- .PART_A132_1_UNIQUE_COURTE * tme[courte]
  mensuel[autre] <- .PART_A132_1_AUTRE * tme[autre]
  bornes <- .bornes_echelle_a132_1_1(mensuel)
  reference <- mensuel
  reference[autre] <- pmin(.PLAFOND_A132_1_AUTRE, mensuel[autre])
  bornes$basse[autre] <- pmin(.PLAFOND_A132_1_AUTRE, bornes$basse[autre])
  bornes$haute[autre] <- pmin(.PLAFOND_A132_1_AUTRE, bornes$haute[autre])
  plafonne <- rep(NA, n)
  plafonne[courte & !is.na(tme)] <- FALSE
  plafonne[autre] <- mensuel[autre] > .PLAFOND_A132_1_AUTRE + .TOLERANCE_INDICATEURS
  data.frame(tme_semestriel = tme, taux_reference = reference, borne_basse = bornes$basse, borne_haute = bornes$haute,
             reference_plafonnee_3_5 = plafonne)
}

# Points extrêmes de l'échelle d'A132-1-1 dans ]référence - 0,35 point ; référence + 0,10
# point[ : k_min = plus petit k >= 0 tel que k x pas > bas + tolérance, k_max = plus grand k
# tel que k x pas < haut - tolérance ; 0 et 0 si k_max < k_min ; NA si la référence manque.
.bornes_echelle_a132_1_1 <- function(reference) {
  bas <- reference - .ECART_BAS_A132_1_1
  haut <- reference + .ECART_HAUT_A132_1_1
  k_min <- pmax(0, floor((bas + .TOLERANCE_INDICATEURS) / .PAS_ECHELLE_A132_1_1) + 1)
  k_max <- ceiling((haut - .TOLERANCE_INDICATEURS) / .PAS_ECHELLE_A132_1_1) - 1
  vide <- !is.na(reference) & k_max < k_min
  basse <- k_min * .PAS_ECHELLE_A132_1_1
  haute <- k_max * .PAS_ECHELLE_A132_1_1
  basse[vide] <- 0
  haute[vide] <- 0
  list(basse = basse, haute = haute)
}

# Lignes d'indicateurs (ADR 0010, point 6, champ `indicateurs`), colonnes COLONNES_INDICATEURS.
.lignes_indicateurs <- function(regle, poste, garantie, valeur_regle, valeur_retenue, depassement, detail) {
  n <- length(detail)
  res <- data.frame(regle = rep_len(regle, n), poste = rep_len(poste, n), garantie = rep_len(garantie, n),
             valeur_regle = as.double(valeur_regle), valeur_retenue = as.double(valeur_retenue),
             depassement = as.logical(depassement), detail = detail, stringsAsFactors = FALSE)
  res[COLONNES_INDICATEURS]
}

.controler_libelles <- function(fonction, ...) {
  for (x in list(...)) {
    if (!(is.character(x) && length(x) == 1L && !is.na(x))) {
      stop(paste0(fonction, "() : `poste`, `garantie` et `type_organisme` doivent \u00eatre des cha\u00eenes uniques"),
           call. = FALSE)
    }
  }
  invisible(NULL)
}

# Réel écrit dans `detail` : 15 chiffres significatifs, NA écrit NA.
.reel_detail <- function(x) ifelse(is.na(x), "NA", sprintf("%.15g", x))

# Lignes d'indicateur R132_3_1 (spécification de B2, § 3.5), une par année : `annee`, années
# civiles des taux de revalorisation employés ; `taux_retenu`, taux retenus de ces années
# (plan$revalorisation$capital_deces$taux_par_annee), même longueur ; `type_organisme`,
# extraction.type_organisme. valeur_regle = minimum_r132_3_1() ; valeur_retenue = taux
# retenu ; depassement = TRUE si le taux retenu est inférieur au minimum de plus de 1e-12
# (règle de sens inverse ; FALSE à l'égalité, R132-3-1 admettant un taux égal au minimum ;
# erratum v1.0.2), NA si le minimum est incalculable. detail : « annee=AAAA;minimum », puis
# « ;indicateur_negatif » (minimum négatif, I4), « ;ip_renvoi_L932-23_incertain »
# (institution de prévoyance, I5), « ;serie_incomplete » (minimum NA ; aucun poste arrêté).
indicateur_r132_3_1 <- function(serie, annee, decalage, taux_retenu, poste, garantie, type_organisme) {
  .controler_libelles("indicateur_r132_3_1", poste, garantie, type_organisme)
  minimum <- minimum_r132_3_1(serie, annee, decalage)
  if (!is.double(taux_retenu) || length(taux_retenu) != length(annee) || anyNA(taux_retenu)) {
    stop("indicateur_r132_3_1() : `taux_retenu` doit \u00eatre un double renseign\u00e9 de la longueur de `annee`",
         call. = FALSE)
  }
  detail <- paste0("annee=", sprintf("%d", as.integer(annee)), ";minimum",
                   ifelse(!is.na(minimum) & minimum < 0, ";indicateur_negatif", ""),
                   if (type_organisme == "institution_prevoyance") ";ip_renvoi_L932-23_incertain" else "",
                   ifelse(is.na(minimum), ";serie_incomplete", ""))
  .lignes_indicateurs("R132_3_1", poste, garantie, minimum, unname(taux_retenu), taux_retenu < minimum - .TOLERANCE_INDICATEURS, detail)
}

# Lignes d'indicateur A132_1 (spécification de B2, § 3.5, version 1.0.2 ; I2 lecture (i) :
# une ligne par contrat et par appel, c'est-à-dire par date d'évaluation -- souscription, ou
# arrêté --, sans tranche) : `id_contrat`, `nature_primes`
# ("unique" ou "periodique"), `date_effet`, `date_terme` (NA admis : terme absent),
# `taux_tarif` (taux du tarif du contrat, hypothèse D03h déjà appliquée par l'appelant s'il
# manquait) ; `date` : date de l'indicateur (souscription, ou arrêté avec
# `approximation_arrete` = TRUE), longueur 1 ou celle des contrats. La durée est au plus de
# huit ans si le terme est au plus le huitième anniversaire de la date d'effet (huit ans
# inclus ; un 29 février donne le 1er mars). valeur_regle = taux de référence de
# plafond_a132_1() ; valeur_retenue = taux du tarif ; depassement à trois valeurs (échelle
# d'A132-1-1, comparaisons à 1e-12 près) : TRUE si taux du tarif > borne haute (dépassement
# certain), FALSE s'il est <= borne basse (dépassement exclu ; un taux égal au plafond n'est
# pas un dépassement), NA entre les deux ou si la référence manque. Délai de trois mois
# (délai de grâce) non pris en compte : TRUE peut être un faux positif. detail :
# « id_contrat=...;date=AAAA-MM-JJ;nature_primes=...;borne_basse=...;borne_haute=...;
# type_organisme=...;delai_3_mois_non_pris_en_compte », puis « ;approximation_arrete »,
# « ;reference_plafonnee_3_5 » (60 % du TME au-dessus de 3,5 %, #88), « ;terme_absent » (en
# prime unique, référence NA, sans hypothèse par défaut ; en primes périodiques, ligne
# calculée), « ;serie_incomplete ».
indicateur_a132_1 <- function(serie, date, nature_primes, date_effet, date_terme, decalage, taux_tarif, id_contrat,
                              poste, garantie, type_organisme, approximation_arrete) {
  .controler_libelles("indicateur_a132_1", poste, garantie, type_organisme)
  n <- length(id_contrat)
  if (!is.character(id_contrat) || n < 1L || anyNA(id_contrat)) {
    stop("indicateur_a132_1() : `id_contrat` doit \u00eatre un vecteur character renseign\u00e9", call. = FALSE)
  }
  if (!identical(class(date_effet), "Date") || length(date_effet) != n || anyNA(date_effet) ||
      !identical(class(date_terme), "Date") || length(date_terme) != n) {
    stop("indicateur_a132_1() : `date_effet` (renseign\u00e9e) et `date_terme` doivent \u00eatre des Date d'un \u00e9l\u00e9ment par contrat",
         call. = FALSE)
  }
  if (!is.double(taux_tarif) || length(taux_tarif) != n || anyNA(taux_tarif)) {
    stop("indicateur_a132_1() : `taux_tarif` doit \u00eatre un double renseign\u00e9 par contrat (hypoth\u00e8se D03h appliqu\u00e9e)",
         call. = FALSE)
  }
  if (!(is.logical(approximation_arrete) && length(approximation_arrete) == 1L && !is.na(approximation_arrete))) {
    stop("indicateur_a132_1() : `approximation_arrete` doit \u00eatre TRUE ou FALSE", call. = FALSE)
  }
  if (!(length(date) %in% c(1L, n))) stop("indicateur_a132_1() : `date` de longueur 1 ou du nombre de contrats", call. = FALSE)
  if (!(length(nature_primes) %in% c(1L, n))) {
    stop("indicateur_a132_1() : `nature_primes` de longueur 1 ou du nombre de contrats", call. = FALSE)
  }
  date <- date[rep_len(seq_along(date), n)]
  nature_primes <- rep_len(nature_primes, n)
  courte <- date_terme <= date_atteinte_age(date_effet, .DUREE_A132_1_ANNEES, "revolu")
  p <- plafond_a132_1(serie, date, rep_len(nature_primes, n), courte, decalage)
  depassement <- ifelse(taux_tarif > p$borne_haute + .TOLERANCE_INDICATEURS, TRUE,
                        ifelse(taux_tarif <= p$borne_basse + .TOLERANCE_INDICATEURS, FALSE, NA))
  detail <- paste0("id_contrat=", id_contrat, ";date=", ecrire_valeurs(date, "texte"),
                   ";nature_primes=", ifelse(is.na(nature_primes), "NA", nature_primes),
                   ";borne_basse=", .reel_detail(p$borne_basse), ";borne_haute=", .reel_detail(p$borne_haute),
                   ";type_organisme=", type_organisme, ";delai_3_mois_non_pris_en_compte",
                   if (approximation_arrete) ";approximation_arrete" else "",
                   ifelse(p$reference_plafonnee_3_5 %in% TRUE, ";reference_plafonnee_3_5", ""),
                   ifelse(is.na(date_terme), ";terme_absent", ""),
                   ifelse(is.na(p$tme_semestriel), ";serie_incomplete", ""))
  .lignes_indicateurs("A132_1", poste, garantie, p$taux_reference, taux_tarif, depassement, detail)
}

# Ligne d'indicateur hors_axes_derniere_valeur (spécification de B2, erratum v1.0.16, § 5.8,
# source S3 ; #91) : seule construction de cette ligne, appelée par toute famille qui lit une
# table sous hors_axes = "derniere_valeur" (en B2 : provisions_individuelles(), usage
# mortalite_tarif) ; une famille ne la construit jamais elle-même. `table` : la table lue
# (table_provie, à un axe : seule forme de B2) ; `points` : liste nommée des points passés à
# probabilite() pour l'unité ; `valeurs` : rendu de probabilite() sur ces points (attribut
# hors_axes : indices des points hors des axes) ; `usage`, `id_contrat` (unité), `poste`,
# `garantie` : chaînes uniques. Rend zéro ligne si aucun point n'est hors des axes ; sinon une
# ligne : valeur_regle NA, valeur_retenue = nombre de points lus hors des axes (double),
# depassement TRUE (signal), detail « usage=...;identifiant=<identifiant de la table>;
# id_contrat=...;axe=<axe>;valeurs=<valeurs hors des axes, distinctes, croissantes, jointes par
# ,> ».
indicateur_hors_axes <- function(table, points, valeurs, usage, id_contrat, poste, garantie) {
  if (!inherits(table, "table_provie")) stop("indicateur_hors_axes() : `table` doit \u00eatre une table_provie", call. = FALSE)
  for (x in list(usage, id_contrat, poste, garantie)) {
    if (!(is.character(x) && length(x) == 1L && !is.na(x))) {
      stop("indicateur_hors_axes() : `usage`, `id_contrat`, `poste` et `garantie` doivent \u00eatre des cha\u00eenes uniques",
           call. = FALSE)
    }
  }
  if (length(table$axes) != 1L) {
    stop("indicateur_hors_axes() : table \u00e0 un axe attendue (forme de la ligne pour plusieurs axes non fix\u00e9e)",
         call. = FALSE)
  }
  if (!(is.list(points) && identical(names(points), names(table$axes)))) {
    stop(paste0("indicateur_hors_axes() : `points` : liste nomm\u00e9e des axes de la table (", names(table$axes), ")"),
         call. = FALSE)
  }
  dehors <- attr(valeurs, "hors_axes")
  if (!is.integer(dehors) || length(valeurs) != length(points[[1L]])) {
    stop("indicateur_hors_axes() : `valeurs` doit \u00eatre le rendu de probabilite() sur `points` (attribut hors_axes)",
         call. = FALSE)
  }
  if (length(dehors) == 0L) return(.lignes_indicateurs(character(0), character(0), character(0), numeric(0), numeric(0),
                                                       logical(0), character(0)))
  detail <- paste0("usage=", usage, ";identifiant=", table$identifiant, ";id_contrat=", id_contrat,
                   ";axe=", names(table$axes), ";valeurs=",
                   paste(.reel_detail(sort(unique(points[[1L]][dehors]))), collapse = ","))
  .lignes_indicateurs("hors_axes_derniere_valeur", poste, garantie, NA_real_, length(dehors), TRUE, detail)
}

# --- Méthodes de la classe table_provie (décomptes seuls) ------------------------------

format.table_provie <- function(x, ...) {
  t <- unclass(x)
  c(paste0("table ", t$identifiant, " (", t$nature, ", statut ", t$statut, ", pas ", t$pas, ")"),
    paste0("  axes : ", paste(paste0(names(t$axes), " ", vapply(t$axes, length, 0L), " point(s)"), collapse = ", ")),
    paste0("  origine : format ", t$origine$format_natif, ", conversion ", t$origine$conversion,
           ", empreinte ", t$origine$empreinte))
}

print.table_provie <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}
