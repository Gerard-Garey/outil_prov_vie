# Module `risque_en_cours` (ADR 0005 ; ADR 0010, points 1, 6 et 14 ; M118 ; spécification de
# B2, docs/specifications/b2-capital-deces-v1.md, § 5.5) : famille de calcul « risque en
# cours » du capital décès en comptes sociaux, P3 provision mathématique de la temporaire
# décès : contrats individuels (prospective_prime_pure, recommandée ; prospective_prime_declaree,
# alternative ; témoin retrospective, jamais restitué) et contrats collectifs
# (prorata_cotisation), contrôles tarif_vie et A132_1.
# N'appelle que les modules `engagement` (valeur_actuelle_probable(), duree_annees(), seule
# actualisation), `tables`, `garanties`, `donnees` et `outils` (graphe du point 1), et
# seulement leurs fonctions sans point. Lit la vue à l'arrêté (vue_a_date()), jamais la base
# brute. Ne parle pas (point 12). Code ASCII hors commentaires (M112).
# Convention de ce fichier : une fonction dont le nom commence par un point est un
# auxiliaire du module ; la concordance documentation <-> code ne recense que les autres.

# --- Constantes ------------------------------------------------------------------

.POSTE_P3 <- "provision_mathematique_temporaire_deces"
.REFERENTIEL_P3 <- "comptes_sociaux"
.MOIS_PAS <- c(an = 12L, mois = 1L)
# Natures de cotisation retenues par prorata_cotisation (signées ; spécification de B2, § 5.5).
.NATURES_PRORATA <- c("emission", "annulation", "regularisation")
# Comparaison de tarif_vie (taux retenu > taux du tarif), à 1e-12 près (même seuil que les
# indicateurs de `tables`, approximation numérique).
.TOLERANCE_TARIF_VIE <- 1e-12
.TAUX_DU_TARIF <- "taux_tarif"

# --- Contrats individuels -----------------------------------------------------------

# Survie depuis la date d'effet `e` (jours) aux dates `dates` (jours, au moins e, au plus la
# fin de couverture) : produit des (1 - q) des années d'assurance complètes, puis p(s) de la
# fraction s de l'année en cours (s = duree_annees(anniversaire k, date) / duree_annees(
# anniversaire k, anniversaire k + 1)) sous conventions$repartition_annee : `uniforme`, p(s) =
# 1 - s q ; `force_constante`, p(s) = (1 - q)^s (spécification de B2, § 2.6 et § 5.5). `q` :
# probabilités de décès des années d'assurance 0, 1... (âge à l'effet + k).
.survie_effet <- function(e, dates, q, conventions) {
  k_max <- length(q)
  an <- ajouter_mois(rep(e, k_max + 1L), 12L * (0:k_max))
  k <- findInterval(dates, an, rightmost.closed = TRUE)
  k[k > k_max] <- k_max
  debut <- an[k]
  fin <- an[k + 1L]
  d <- function(x) structure(x, class = "Date")
  s <- duree_annees(d(debut), d(dates), conventions) / duree_annees(d(debut), d(fin), conventions)
  qk <- q[k]
  cumul <- c(1, cumprod(1 - q))[k]
  p <- if (conventions$repartition_annee == "uniforme") 1 - s * qk else (1 - qk)^s
  cumul * p
}

# Échéancier d'un contrat individuel évalué à l'origine `o` (jours ; arrêté, ou date d'effet)
# jusqu'à la fin de couverture `fin` (spécification de B2, § 5.5) : bornes o, chaque date de
# pas postérieure à o et antérieure à fin, et fin ; flux capital_unique du capital `capital` à
# la fin du pas (`fin_pas`) ou en son milieu (`milieu_pas` : début + partie entière de la
# moitié des jours, au plus tôt le lendemain du début), pondéré par la probabilité de décès
# dans le pas sachant la survie à o ; flux prime_periodique (`prime`, négatif) à chaque
# échéance postérieure à o et antérieure à fin, pondéré par la survie (une échéance datée de
# o est passée) ; flux frais (`frais` par an) à chaque anniversaire postérieur à o et
# antérieur à fin. `e` : date d'effet (pas, anniversaires, échéances) ; `periode` : mois entre
# deux échéances (NA : prime unique).
.echeancier_contrat <- function(cle, e, o, fin, q, capital, prime, periode, frais, parametres, conventions) {
  pas <- .MOIS_PAS[[parametres$pas]]
  n_pas <- ceiling(as.numeric(fin - e) / 28 / pas) + 2L
  dates_pas <- ajouter_mois(rep(e, n_pas), pas * seq_len(n_pas))
  bornes <- sort(unique(c(o, dates_pas[dates_pas > o & dates_pas < fin], fin)))
  s0 <- .survie_effet(e, o, q, conventions)
  sb <- .survie_effet(e, bornes, q, conventions) / s0
  d1 <- bornes[-length(bornes)]
  d2 <- bornes[-1L]
  date_capital <- if (parametres$paiement_capital == "fin_pas") d2 else {
    m <- d1 + floor((d2 - d1) / 2)
    ifelse(m > d1, m, d2)
  }
  lignes <- list(data.frame(cle = cle, date = date_capital, type_flux = "capital_unique", flux = capital,
                            probabilite = sb[-length(sb)] - sb[-1L], stringsAsFactors = FALSE))
  if (!is.na(periode)) {
    n_e <- ceiling(as.numeric(fin - e) / 28 / periode) + 2L
    ech <- ajouter_mois(rep(e, n_e), periode * seq_len(n_e))
    ech <- ech[ech > o & ech < fin]
    if (length(ech)) {
      lignes[[2L]] <- data.frame(cle = cle, date = ech, type_flux = "prime_periodique", flux = -prime,
                                 probabilite = .survie_effet(e, ech, q, conventions) / s0, stringsAsFactors = FALSE)
    }
  }
  if (frais != 0) {
    an <- ajouter_mois(rep(e, n_pas), 12L * seq_len(n_pas))
    an <- an[an > o & an < fin]
    if (length(an)) {
      lignes[[length(lignes) + 1L]] <- data.frame(cle = cle, date = an, type_flux = "frais", flux = frais,
                                                  probabilite = .survie_effet(e, an, q, conventions) / s0,
                                                  stringsAsFactors = FALSE)
    }
  }
  res <- do.call(rbind, lignes)
  res$date <- structure(as.numeric(res$date), class = "Date")
  res$etat <- "actif"
  res[, c("cle", "date", "etat", "type_flux", "flux", "probabilite")]
}

# Valeur actuelle au taux `taux` d'un échéancier évalué à l'origine `o` (jours) : par
# engagement::valeur_actuelle_probable(), seule actualisation du package ; un flux daté de
# l'origine (prime à l'effet) a un facteur 1 et une probabilité 1, ajouté sans actualisation.
.vap <- function(ech, taux, o, conventions) {
  if (nrow(ech) == 0L) return(list(total = 0, echeancier = ech))
  r <- valeur_actuelle_probable(ech, list(type = "taux", taux = taux, origine = structure(o, class = "Date")), conventions)
  list(total = sum(r$echeancier$valeur_actuelle), echeancier = r$echeancier)
}

# Contrats individuels de P3 (spécification de B2, § 5.5, champ (a)) : population, échéanciers
# et provisions par contrat. Rend list(contrats : data.frame (id_contrat, id_garantie_souscrite,
# capital, taux_tarif, taux_retenu, hypothese_d03h, extrapole (un point de mortalite_tarif lu
# hors des axes sous derniere_valeur, source S3 du § 5.8, #91), a_effet, a_double_effet (ä à l'effet),
# prime, valeur (avant plancher), montant (plancher nul par contrat), retro_avant_prime,
# retro_apres_prime (témoin rétrospectif, calculé seulement si `temoin` vaut TRUE ; NA sinon,
# ou si l'arrêté n'est pas une date de pas ou si la prime est unique),
# nature_primes, date_effet, date_terme, date_souscription), echeancier (flux à l'arrêté,
# taux retenu), arret (motif né de la famille : hors_axes, parametre_non_determine ; NA),
# identifiant (premier contrat en cause), hors_axes (lignes d'indicateur
# hors_axes_derniere_valeur de indicateur_hors_axes(), une par contrat extrapolé, dans l'ordre
# des contrats ; NULL sans extrapolation)). Sans point : lue par les tests du module (cas T1 à
# T6) et par calculer_risque_en_cours() (`temoin` = FALSE : le témoin n'est jamais restitué) ;
# non exportée. `temoin` : TRUE ou FALSE, exigé.
provisions_individuelles <- function(vue, plan, tables, temoin) {
  if (!(is.logical(temoin) && length(temoin) == 1L && !is.na(temoin))) {
    stop("erreur interne de provie : provisions_individuelles() : `temoin` doit valoir TRUE ou FALSE", call. = FALSE)
  }
  vv <- function(t, c1) valeurs_vue(vue, t, c1)
  a <- as.numeric(vue$bilan$vue$date_arrete)
  conventions <- plan$conventions
  declaration <- plan$postes$deces[[.POSTE_P3]]$individuel
  methode <- declaration$methode
  parametres <- declaration$parametres
  fr <- plan$frais$deces[[.POSTE_P3]][[.REFERENTIEL_P3]]
  taux_plan <- plan$taux$deces[[.POSTE_P3]][[.REFERENTIEL_P3]]
  exclu <- vue$exclu$risque_en_cours
  vide <- list(contrats = NULL, echeancier = NULL, arret = NA_character_, identifiant = NA_character_)
  # garanties souscrites deces retenues, version en vigueur à l'arrêté, de contrats individuels
  # couverture exclue (erratum v1.0.13) : garantie souscrite, ou contrat, exclu pour risque_en_cours
  # hors de la population (garanties_couverture_exclue(), seule implémentation), avant toute lecture
  gs <- which(vue$retenu$garanties_souscrites & vv("garanties_souscrites", "code_garantie") %in% "deces")
  gs <- gs[!(as.character(vv("garanties_souscrites", "id_garantie_souscrite"))[gs] %in%
               garanties_couverture_exclue(vue, "risque_en_cours"))]
  g_effet <- as.numeric(vv("garanties_souscrites", "date_effet"))[gs]
  g_fin <- as.numeric(vv("garanties_souscrites", "date_fin"))[gs]
  gs <- gs[g_effet <= a & (is.na(g_fin) | g_fin > a)]
  i_ct <- match(as.character(vv("garanties_souscrites", "id_contrat")[gs]), as.character(vv("contrats", "id_contrat")),
                incomparables = NA)
  garde <- !is.na(i_ct)
  garde[garde] <- vue$retenu$contrats[i_ct[garde]] &
    vv("contrats", "nature_contrat")[i_ct[garde]] %in% "individuel" &
    as.numeric(vv("contrats", "date_effet"))[i_ct[garde]] <= a
  gs <- gs[garde]
  i_ct <- i_ct[garde]
  if (length(gs) == 0L) return(vide)
  id_gs <- as.character(vv("garanties_souscrites", "id_garantie_souscrite")[gs])
  id_ct <- as.character(vv("contrats", "id_contrat")[i_ct])
  assure <- as.character(vv("contrats", "id_assure")[i_ct])
  # ligne de assures exclue pour risque_en_cours : date de naissance inconnue, traitée comme
  # manquante (erratum v1.0.10, #82)
  i_as <- match(assure, as.character(vv("assures", "id_assure")), incomparables = NA)
  naissance <- vv("assures", "date_naissance")[i_as]
  naissance[!is.na(i_as) & exclu$assures[i_as]] <- NA
  effet <- as.numeric(vv("contrats", "date_effet"))[i_ct]
  terme <- as.numeric(vv("contrats", "date_terme"))[i_ct]
  fin_ct <- as.numeric(vv("contrats", "date_fin"))[i_ct]
  # paramètres lus par P3 (erratum v1.0.9, #78) : une ligne retenue exclue pour risque_en_cours
  # rend le paramètre non déterminé (jamais 0 ni absent) ; age_fin_garantie exclu est inconnu
  # avant le calcul de la fin de couverture (lecture de Kleene : la sortie de la population ne
  # se décide que par date_terme ou date_fin)
  param <- function(nom) parametre_vue(vue, nom, id_gs, "risque_en_cours")
  capital <- param("capital_forfaitaire")
  age_fin <- param("age_fin_garantie")
  age_fin$valeur[age_fin$exclu] <- NA_real_
  prime_p <- param("prime_periodique")
  periodicite <- vv("garanties_souscrites", "periodicite_cotisation")[gs]
  # mois d'une période de cotisation : constante unique du module `donnees` (#92 mi3) ; `unique` :
  # prime unique, aucun flux de prime
  periode <- unname(MOIS_PERIODE_COTISATION[periodicite])
  date_age <- rep(Inf, length(gs))
  ok_age <- !is.na(age_fin$valeur) & !is.na(naissance)
  date_age[ok_age] <- as.numeric(date_atteinte_age(naissance[ok_age], as.integer(age_fin$valeur[ok_age]), conventions$age))
  fin_contractuelle <- pmin(ifelse(is.na(terme), Inf, terme), date_age)
  fin <- pmin(fin_contractuelle, ifelse(is.na(fin_ct), Inf, fin_ct))
  # couverture en cours ; aucun sinistre deces ou iad retenu, non exclu pour risque_en_cours, de
  # l'assuré survenu au plus l'arrêté. Lecture de Kleene stricte (erratum v1.0.10, #82, Q-82) :
  # un sinistre retenu exclu pour risque_en_cours a une nature et une date inconnues ; le
  # contrat de son assuré, sauf s'il sort de la population par une condition connue, arrête
  # le poste (parametre_non_determine)
  s_id <- as.character(vv("sinistres", "id_assure"))
  s <- which(vue$retenu$sinistres & !exclu$sinistres & vv("sinistres", "nature_sinistre") %in% c("deces", "iad") &
               as.numeric(vv("sinistres", "date_survenance")) <= a)
  sinistre <- assure %in% s_id[s]
  sinistre_inconnu <- !is.na(assure) & assure %in% s_id[vue$retenu$sinistres & exclu$sinistres]
  en_cours <- fin > a & !sinistre
  if (!any(en_cours)) return(vide)
  k <- which(en_cours)
  manque <- k[sinistre_inconnu[k] | is.na(capital$valeur[k]) | capital$ambigu[k] | capital$exclu[k] | is.na(age_fin$valeur[k]) |
                age_fin$ambigu[k] | is.na(naissance[k]) | is.infinite(fin[k]) |
                (methode == "prospective_prime_declaree" & !is.na(periode[k]) & (is.na(prime_p$valeur[k]) | prime_p$ambigu[k])) |
                (methode == "prospective_prime_declaree" & prime_p$exclu[k])]
  if (length(manque)) return(list(contrats = NULL, echeancier = NULL, arret = "parametre_non_determine",
                                  identifiant = id_ct[manque[1L]]))
  # taux du tarif ; hypothèse D03h déclarée s'il manque
  tarif <- vv("garanties_souscrites", "taux_technique_tarif")[gs]
  d03h <- rep(FALSE, length(gs))
  for (i in k[is.na(tarif[k])]) {
    h <- .hypothese_d03h(vue, gs[i])
    if (is.null(h)) {
      refuser(paste0("risque_en_cours : taux du tarif manquant pour la garantie souscrite ", id_gs[i],
                     " sans hypoth\u00e8se D03h d\u00e9clar\u00e9e (comptes_sociaux)"), "declaration_manquante",
              module = "risque_en_cours", table = "garanties_souscrites", colonne = "taux_technique_tarif",
              identifiants = id_gs[i])
    }
    tarif[i] <- h
    d03h[i] <- TRUE
  }
  # probabilités de décès par année d'assurance, âge à l'effet + k
  age0 <- calculer_age(naissance, structure(effet, class = "Date"), conventions$age)
  hors <- plan$tables$mortalite_tarif$hors_axes
  q_de <- list()
  # points lus hors des axes sous derniere_valeur (source S3, § 5.8, #91) : ligne d'indicateur
  # construite par indicateur_hors_axes() (`tables`, seule implémentation) ; contrat extrapolé
  extrapole <- rep(FALSE, length(gs))
  hors_axes <- list()
  for (i in k) {
    n_annees <- 0L
    while (ajouter_mois(effet[i], 12L * n_annees) < fin_contractuelle[i]) n_annees <- n_annees + 1L
    points <- list(age = age0[i] + seq_len(n_annees) - 1L)
    q <- probabilite(tables$mortalite_tarif, age = points$age, hors_axes = hors)
    if (length(attr(q, "hors_axes"))) {
      if (identical(hors, "refus")) return(list(contrats = NULL, echeancier = NULL, arret = "hors_axes",
                                                identifiant = id_ct[i]))
      extrapole[i] <- TRUE
      hors_axes[[length(hors_axes) + 1L]] <- indicateur_hors_axes(tables$mortalite_tarif, points, q, "mortalite_tarif",
                                                                  id_ct[i], .POSTE_P3, "deces")
    }
    q_de[[as.character(i)]] <- as.vector(q)
  }
  lignes <- list()
  echeancier <- list()
  for (i in k) {
    q <- q_de[[as.character(i)]]
    cle <- id_ct[i]
    taux_r <- if (identical(taux_plan, .TAUX_DU_TARIF)) tarif[i] else taux_plan
    unique_p <- is.na(periode[i])
    frais_g <- if (unique_p) fr$taux_chargement_gestion * capital$valeur[i] else 0
    a_effet <- NA_real_
    a_dbl <- NA_real_
    prime <- 0
    if (!unique_p) {
      # prime par équivalence à la date d'effet, table du tarif, taux du tarif
      ech_e <- .echeancier_contrat(cle, effet[i], effet[i], fin_contractuelle[i], q, capital$valeur[i], 1, periode[i], 0,
                                   parametres, conventions)
      a_effet <- .vap(ech_e[ech_e$type_flux == "capital_unique", , drop = FALSE], tarif[i], effet[i], conventions)$total
      a_dbl <- 1 - .vap(ech_e[ech_e$type_flux == "prime_periodique", , drop = FALSE], tarif[i], effet[i], conventions)$total
      prime <- if (methode == "prospective_prime_pure") {
        a_effet / a_dbl + fr$taux_chargement_acquisition * capital$valeur[i] / a_dbl
      } else {
        prime_p$valeur[i] * (1 - fr$taux_chargement_cotisation)
      }
    }
    ech <- .echeancier_contrat(cle, effet[i], a, fin[i], q, capital$valeur[i], prime, periode[i], frais_g, parametres,
                               conventions)
    v <- .vap(ech, taux_r, a, conventions)
    retro <- c(NA_real_, NA_real_)
    if (temoin) {
      retro <- .retrospective(cle, effet[i], a, fin[i], q, capital$valeur[i], prime, periode[i], frais_g,
                              if (unique_p) 0 else fr$taux_chargement_acquisition * capital$valeur[i] *
                                (methode == "prospective_prime_pure"),
                              taux_r, parametres, conventions)
    }
    lignes[[length(lignes) + 1L]] <- data.frame(
      id_contrat = cle, id_garantie_souscrite = id_gs[i], capital = capital$valeur[i], taux_tarif = tarif[i],
      taux_retenu = taux_r, hypothese_d03h = d03h[i], extrapole = extrapole[i], a_effet = a_effet,
      a_double_effet = a_dbl, prime = prime,
      valeur = v$total, montant = max(0, v$total), retro_avant_prime = retro[1L], retro_apres_prime = retro[2L],
      nature_primes = if (unique_p) "unique" else "periodique", date_effet = structure(effet[i], class = "Date"),
      date_terme = structure(terme[i], class = "Date"),
      date_souscription = structure(as.numeric(vv("garanties_souscrites", "date_effet"))[gs[i]], class = "Date"),
      stringsAsFactors = FALSE)
    echeancier[[length(echeancier) + 1L]] <- v$echeancier
  }
  list(contrats = do.call(rbind, lignes), echeancier = do.call(rbind, echeancier), arret = NA_character_,
       identifiant = NA_character_, hors_axes = do.call(rbind, hors_axes))
}

# Valeur de l'hypothèse D03h appliquée à la ligne `ligne` de garanties_souscrites
# (vue$hypotheses : motif D03h, référentiel comptes_sociaux, poste P3 de préférence à `tous`),
# lue comme un taux décimal ; NULL sans hypothèse appliquée. Une valeur qui n'est pas un
# nombre décimal à point est un refus plan_invalide (aucune conversion silencieuse).
.hypothese_d03h <- function(vue, ligne) {
  h <- Filter(function(x) x$motif == "D03h" && x$referentiel == .REFERENTIEL_P3 && x$table == "garanties_souscrites" &&
                ligne %in% x$lignes && x$poste %in% c(.POSTE_P3, "tous"), vue$hypotheses)
  if (length(h) == 0L) return(NULL)
  postes <- vapply(h, `[[`, "", "poste")
  valeur <- h[[if (.POSTE_P3 %in% postes) match(.POSTE_P3, postes) else 1L]]$valeur
  if (!grepl("^-?[0-9]+(\\.[0-9]+)?([eE][-+]?[0-9]+)?$", valeur)) {
    refuser(paste0("plan : hypoth\u00e8se D03h (comptes_sociaux) : valeur \u00ab ", valeur,
                   " \u00bb, taux d\u00e9cimal attendu (taux du tarif retenu)"), "plan_invalide", module = "risque_en_cours",
            recu = valeur)
  }
  as.numeric(valeur)
}

# Témoin rétrospectif (spécification de B2, § 5.5 ; Norberg 1991, recensement § 12), aux mêmes
# bases que la prospective : valeur accumulée à l'arrêté des primes passées (échéances au plus
# l'arrêté, prime de l'échéance A comprise ou non) moins le coût du risque passé, les frais
# passés et le chargement d'acquisition à l'effet (`acquisition`), sachant la survie à
# l'arrêté. Défini quand l'arrêté est une date de pas (sinon NA : un pas à cheval sur l'arrêté
# n'a pas de part passée sans répartition du flux de capital). Rend c(avant_prime,
# apres_prime) ; jamais restitué dans les provisions. Prime unique (`periode` NA) : NA, sans
# objet (la prime unique n'est pas une donnée lue : le témoin vaudrait le coût du risque passé
# changé de signe, sans rapport avec la prospective ; #80).
.retrospective <- function(cle, e, a, fin, q, capital, prime, periode, frais, acquisition, taux, parametres, conventions) {
  if (is.na(periode)) return(c(NA_real_, NA_real_))
  pas <- .MOIS_PAS[[parametres$pas]]
  n_pas <- ceiling(as.numeric(a - e) / 28 / pas) + 2L
  dates_pas <- c(e, ajouter_mois(rep(e, n_pas), pas * seq_len(n_pas)))
  if (!(a %in% dates_pas)) return(c(NA_real_, NA_real_))
  if (a == e) return(c(-acquisition, prime - acquisition))
  ech <- .echeancier_contrat(cle, e, e, a, q, capital, prime, periode, frais, parametres, conventions)
  sa <- .survie_effet(e, a, q, conventions)
  # facteur d'actualisation de l'effet à l'arrêté, par la seule fonction d'actualisation
  unite <- data.frame(cle = cle, date = structure(a, class = "Date"), etat = "actif", type_flux = "frais", flux = 1,
                      probabilite = 1, stringsAsFactors = FALSE)
  va <- .vap(unite, taux, e, conventions)$total
  passe <- ech
  passe$flux <- -passe$flux   # primes reçues positives, capitaux et frais payés négatifs
  valeur0 <- .vap(passe, taux, e, conventions)$total + prime - acquisition
  prime_a <- if (!(a %in% ajouter_mois(rep(e, n_pas), periode * seq_len(n_pas)))) 0 else prime
  avant <- valeur0 / (va * sa)
  c(avant, avant + prime_a)
}

# --- Contrats collectifs --------------------------------------------------------------

# Contrats collectifs de P3 (spécification de B2, § 5.5, champ (b), prorata_cotisation) : par
# contrat, somme sur les cotisations retenues (non exclues) de nature emission, annulation ou
# regularisation des garanties souscrites deces retenues de contrats collectifs, de fin de
# période postérieure à l'arrêté, de montant x (1 - taux_chargement_cotisation) x nombre de
# jours de la période postérieurs à l'arrêté / (fin - début + 1) ; jours postérieurs = fin -
# A, au plus fin - début + 1 (prorata plafonné à 1 : période entièrement postérieure à
# l'arrêté ; convention instant_date, § 2.6). Statut : approximation (restituée
# approximation_numerique, § 5.5).
# Ordre d'évaluation d'une cotisation (erratum v1.0.16, #92) : (1) fin_periode connue et au
# plus A : hors du calcul, quels que soient debut_periode et les traitements déclarés de D03f
# et de D02a (l'hypothèse D03f n'est pas lue pour la ligne, décision E16-2) ; (2) borne
# manquante : traitement déclaré de D03f ; (3) bornes connues, fin postérieure à A, période
# inversée ou de longueur nulle (fin - début + 1 <= 0, D02a, sous conserver comme sous H) :
# prorata non déterminé, arrêt parametre_non_determine (lecture de Kleene, MA1) ; (4) prorata.
# Période couverte manquante (D03f, erratum v1.0.15) : `exclure` pour risque_en_cours : ligne
# hors du calcul (vue$exclu) ; hypothèse H (comptes_sociaux, poste P3 ou `tous`) appliquée à la
# ligne : les deux bornes sont celles de periode_cotisation_regle() (`donnees`), contrat sous
# hypothèse, restitué même quand la règle rend la cotisation échue (unité de montant nul, § 5.8,
# #92 mi1) ; valeur déclarée `regle` seule admise, toute autre valeur est un refus plan_invalide,
# levé après les arrêts du poste quand une cotisation lit l'hypothèse (#92 Q1, comme pour
# D03h) ; règle non applicable (périodicité `unique` ou non lisible, mouvement manquant) :
# arrêt parametre_non_determine ; sans hypothèse (conserver) : lecture de Kleene stricte, arrêt
# parametre_non_determine. Identifiant en cause : premier contrat (ordre des lignes de
# cotisations de la vue). Aucun NA n'entre dans une somme : une part NA résiduelle est une
# erreur interne. Rend un data.frame (id_contrat, montant), contrats triés, d'attributs
# `arret` (motif ou NA), `identifiant` (contrat en cause ou NA) et `hypothese_d03f` (contrats
# dont une cotisation est lue sous l'hypothèse D03f). Sans point : lue par les tests du
# module (cas T7) et par calculer_risque_en_cours() ; non exportée.
provisions_collectives <- function(vue, plan) {
  vv <- function(t, c1) valeurs_vue(vue, t, c1)
  a <- as.numeric(vue$bilan$vue$date_arrete)
  exclu <- vue$exclu$risque_en_cours
  taux_c <- plan$frais$deces[[.POSTE_P3]][[.REFERENTIEL_P3]]$taux_chargement_cotisation
  resultat <- function(id_contrat, montant, arret = NA_character_, identifiant = NA_character_,
                       hypothese = character(0)) {
    structure(data.frame(id_contrat = id_contrat, montant = montant, stringsAsFactors = FALSE),
              arret = arret, identifiant = identifiant, hypothese_d03f = hypothese)
  }
  # couverture exclue (erratum v1.0.13) : garantie souscrite, ou contrat, exclu pour risque_en_cours
  # hors du champ (garanties_couverture_exclue(), seule implémentation), avant toute lecture du contrat
  gs <- which(vue$retenu$garanties_souscrites & vv("garanties_souscrites", "code_garantie") %in% "deces")
  gs <- gs[!(as.character(vv("garanties_souscrites", "id_garantie_souscrite"))[gs] %in%
               garanties_couverture_exclue(vue, "risque_en_cours"))]
  ct <- which(vue$retenu$contrats & as.character(vv("contrats", "id_contrat")) %in%
                as.character(vv("garanties_souscrites", "id_contrat"))[gs])
  ct <- ct[!(vv("contrats", "nature_contrat")[ct] %in% "individuel")]
  gs <- gs[as.character(vv("garanties_souscrites", "id_contrat"))[gs] %in% as.character(vv("contrats", "id_contrat")[ct])]
  co <- which(vue$retenu$cotisations & !exclu$cotisations & vv("cotisations", "nature_mouvement") %in% .NATURES_PRORATA &
                as.character(vv("cotisations", "id_garantie_souscrite")) %in%
                as.character(vv("garanties_souscrites", "id_garantie_souscrite")[gs]))
  i_gs <- match(as.character(vv("cotisations", "id_garantie_souscrite")[co]),
                as.character(vv("garanties_souscrites", "id_garantie_souscrite")))
  contrat <- as.character(vv("garanties_souscrites", "id_contrat"))[i_gs]
  debut <- as.numeric(vv("cotisations", "debut_periode"))[co]
  fin <- as.numeric(vv("cotisations", "fin_periode"))[co]
  # (1) fin_periode connue et au plus A : hors du calcul, avant toute hypothèse
  echue_connue <- !is.na(fin) & fin <= a
  # (2) période couverte manquante (D03f) : hypothèse H appliquée aux deux bornes, sinon Kleene
  manque <- (is.na(debut) | is.na(fin)) & !echue_connue
  h_d03f <- Filter(function(x) x$motif == "D03f" && x$referentiel == .REFERENTIEL_P3 &&
                     x$table == "cotisations" && x$poste %in% c(.POSTE_P3, "tous"), vue$hypotheses)
  sous_h <- manque & co %in% unlist(lapply(h_d03f, function(x) x$lignes))
  if (any(sous_h)) {
    regle <- periode_cotisation_regle(vv("cotisations", "date_mouvement")[co[sous_h]],
                                      vv("garanties_souscrites", "periodicite_cotisation")[i_gs[sous_h]])
    debut[sous_h] <- as.numeric(regle$debut)
    fin[sous_h] <- as.numeric(regle$fin)
  }
  inconnue <- (is.na(debut) | is.na(fin)) & !echue_connue
  # (3) bornes connues, fin postérieure à A, période inversée ou de longueur nulle (D02a)
  inversee <- !inconnue & !echue_connue & fin - debut + 1 <= 0
  non_determine <- inconnue | inversee
  if (any(non_determine)) {
    return(resultat(character(0), numeric(0), "parametre_non_determine", contrat[which(non_determine)[1L]]))
  }
  if (any(sous_h)) .valeur_d03f(h_d03f, co[sous_h])
  hypothese <- sort(unique(contrat[sous_h]), method = "radix")
  # (4) prorata des cotisations de fin postérieure à A (bornes connues, ou par la règle H)
  garde <- fin > a
  part <- vv("cotisations", "montant")[co[garde]] * (1 - taux_c) *
    pmin(fin[garde] - a, fin[garde] - debut[garde] + 1) / (fin[garde] - debut[garde] + 1)
  contrat_g <- contrat[garde]
  if (anyNA(part) || anyNA(contrat_g)) {
    stop("erreur interne de provie : part NA dans provisions_collectives() (prorata_cotisation)", call. = FALSE)
  }
  # contrat sous l'hypothèse sans cotisation de fin postérieure à A : unité de montant nul (§ 5.8)
  ids <- sort(unique(c(contrat_g, hypothese)), method = "radix")
  if (length(ids) == 0L) return(resultat(character(0), numeric(0)))
  montant <- rep(0, length(ids))
  if (length(part)) {
    o <- order(contrat_g, part, method = "radix")
    s <- rowsum(part[o], contrat_g[o], reorder = TRUE)
    montant[match(rownames(s), ids)] <- unname(s[, 1L])
  }
  resultat(ids, montant, hypothese = hypothese)
}

# Valeur de l'hypothèse D03f appliquée aux lignes `lignes` de cotisations (`h` : hypothèses
# D03f de vue$hypotheses retenues pour P3 ; poste P3 de préférence à `tous`, comme pour D03h) :
# `regle` seule admise (#92 Q1, erratum v1.0.16) ; toute autre valeur est un refus
# plan_invalide (aucune valeur ignorée en silence). Ne rend rien.
.valeur_d03f <- function(h, lignes) {
  for (l in lignes) {
    hl <- Filter(function(x) l %in% x$lignes, h)
    postes <- vapply(hl, `[[`, "", "poste")
    valeur <- hl[[if (.POSTE_P3 %in% postes) match(.POSTE_P3, postes) else 1L]]$valeur
    if (!identical(valeur, "regle")) {
      refuser(paste0("plan : hypoth\u00e8se D03f (comptes_sociaux) : valeur \u00ab ", valeur,
                     " \u00bb, seule la valeur \u00ab regle \u00bb est admise (r\u00e8gle du dictionnaire)"),
              "plan_invalide", module = "risque_en_cours", recu = valeur)
    }
  }
  invisible(NULL)
}

# --- Point d'appel de la famille -----------------------------------------------------

# Point d'appel de P3 par l'orchestration (spécification de B2, § 5.1 et § 5.5) : mêmes
# arguments que engagement::calculer_engagement() (`tables` : mortalite_tarif si une méthode
# prospective est déclarée, serie_tme pour A132_1). Rend list(cellules, dossiers (vide : P3
# n'a pas de dossier), echeanciers (contrats individuels, cle = id_contrat, flux à l'arrêté au
# taux retenu, avant plancher), indicateurs (par contrat individuel valorisé : tarif_vie, taux
# retenu > taux du tarif, et deux lignes A132_1, à la date d'effet de la version de garantie
# et à l'arrêté ; puis une ligne hors_axes_derniere_valeur par contrat extrapolé, § 5.8),
# contrats (id_contrat, champ `individuel` ou `collectif`, montant après plancher,
# statut_resultat ; un contrat par champ, triés ; vide pour un poste arrêté : unités de la
# restitution par segment, #67)). Une seule cellule pour le poste (champs individuel et collectif réunis) :
# méthode « individuel:<méthode>;collectif:<méthode> », statut_methode `alternative` si l'une
# l'est, statut_resultat le plus faible des contrats (jugement_expert si D03h entre dans le
# montant, ou un point de mortalite_tarif lu hors des axes sous derniere_valeur, S3, #91 ;
# approximation_numerique pour un contrat collectif, jugement_expert sous
# l'hypothèse D03f), nombre_dossiers 0. Poste arrêté (bilan, ou hors_axes,
# parametre_non_determine, dont la période couverte non déterminée d'une cotisation du champ
# (b)) : cellule `arrete`, premier contrat en cause dans l'attribut `identifiant_arret`. Un
# montant NA dans le total est une erreur interne.
calculer_risque_en_cours <- function(vue, plan, tables, catalogue, garantie, poste) {
  if (!identical(garantie, "deces") || !identical(poste, .POSTE_P3)) {
    stop("erreur interne de provie : calculer_risque_en_cours() ne calcule que P3 de la garantie deces", call. = FALSE)
  }
  if (!inherits(vue, "vue_provie")) stop("calculer_risque_en_cours() : `vue` doit \u00eatre un objet vue_provie", call. = FALSE)
  declaration <- plan$postes[[garantie]][[poste]]
  m_ind <- declaration$individuel$methode
  m_col <- declaration$collectif$methode
  methode <- paste0("individuel:", m_ind, ";collectif:", m_col)
  st <- c(statut_methode_catalogue(catalogue, garantie, poste, "individuel", m_ind),
          statut_methode_catalogue(catalogue, garantie, poste, "collectif", m_col))
  statut_methode <- if (all(st == "recommandee")) "recommandee" else "alternative"
  ligne_cat <- catalogue$postes[catalogue$postes$code_garantie == garantie & catalogue$postes$poste == poste, , drop = FALSE]
  vide_ind <- data.frame(regle = character(0), poste = character(0), garantie = character(0), valeur_regle = numeric(0),
                         valeur_retenue = numeric(0), depassement = logical(0), detail = character(0),
                         stringsAsFactors = FALSE)
  dossiers <- data.frame(id_dossier = character(0), id_sinistre = character(0), garantie = character(0),
                         referentiel = character(0), poste = character(0), etat = character(0),
                         date_entree_etat = structure(numeric(0), class = "Date"), montant = numeric(0),
                         methode = character(0), statut_resultat = character(0), hypotheses_defaut = character(0),
                         stringsAsFactors = FALSE)
  echeancier_vide <- data.frame(cle = character(0), referentiel = character(0), poste = character(0),
                                date = structure(numeric(0), class = "Date"), etat = character(0),
                                type_flux = character(0), flux = numeric(0), probabilite = numeric(0),
                                actualisation = numeric(0), valeur_actuelle = numeric(0), stringsAsFactors = FALSE)
  cellule <- function(montant, statut_resultat, motif) {
    res <- data.frame(garantie = garantie, referentiel = .REFERENTIEL_P3, poste = poste, famille = ligne_cat$famille,
                      provision = ligne_cat$provision_comptes_sociaux, segmentation = "ensemble", segment = "ensemble",
                      niveau = "calcul", montant = as.double(montant), nombre_dossiers = if (is.na(motif)) 0L else NA_integer_,
                      methode = methode, statut_methode = statut_methode, statut_resultat = statut_resultat,
                      statut_calcul = if (is.na(motif)) "calcule" else "arrete", motif_arret = motif, stringsAsFactors = FALSE)
    res[COLONNES_CELLULES]
  }
  contrats_vides <- data.frame(id_contrat = character(0), champ = character(0), montant = numeric(0),
                               statut_resultat = character(0), stringsAsFactors = FALSE)
  arreter <- function(motif, identifiant) {
    cel <- cellule(NA_real_, NA_character_, motif)
    attr(cel, "identifiant_arret") <- identifiant
    list(cellules = cel, dossiers = dossiers, echeanciers = echeancier_vide, indicateurs = vide_ind,
         contrats = contrats_vides)
  }
  pa <- postes_a_arreter(catalogue, vue$bilan, plan$postes, parties_ligne())$postes
  motif_bilan <- pa$motif_arret[pa$garantie == garantie & pa$poste == poste]
  if (length(motif_bilan) == 1L && !is.na(motif_bilan)) return(arreter(motif_bilan, NA_character_))
  ind <- provisions_individuelles(vue, plan, tables, FALSE)
  if (!is.na(ind$arret)) return(arreter(ind$arret, ind$identifiant))
  col <- provisions_collectives(vue, plan)
  if (!is.na(attr(col, "arret"))) return(arreter(attr(col, "arret"), attr(col, "identifiant")))
  ct <- ind$contrats
  # statut d'un contrat collectif : jugement_expert sous l'hypothèse D03f (erratum v1.0.15)
  statut_col <- ifelse(col$id_contrat %in% attr(col, "hypothese_d03f"), "jugement_expert", "approximation_numerique")
  # statut d'un contrat individuel (règle unique du § 5.8, erratum v1.0.16) : jugement_expert si
  # une valeur fournie par le plan entre dans son montant, hypothèse D03h (S1) ou point de
  # mortalite_tarif lu hors des axes sous derniere_valeur (S3, #91)
  statut_ind <- if (!is.null(ct)) ifelse(ct$hypothese_d03h | ct$extrapole, "jugement_expert", "exact")
  statuts <- c(statut_ind, statut_col)
  montants <- c(if (!is.null(ct)) ct$montant, col$montant)
  if (anyNA(montants)) stop("erreur interne de provie : montant NA dans le total de P3", call. = FALSE)
  total <- sum(sort(montants))
  indicateurs <- vide_ind
  echeanciers <- echeancier_vide
  if (!is.null(ct)) {
    type_organisme <- valeurs_vue(vue, "extraction", "type_organisme")
    tarif_vie <- data.frame(regle = "tarif_vie", poste = poste, garantie = garantie, valeur_regle = ct$taux_tarif,
                            valeur_retenue = ct$taux_retenu,
                            depassement = ct$taux_retenu > ct$taux_tarif + .TOLERANCE_TARIF_VIE,
                            detail = paste0("id_contrat=", ct$id_contrat, ifelse(ct$hypothese_d03h, ";hypothese_D03h", "")),
                            stringsAsFactors = FALSE)
    st <- plan$tables$serie_tme
    a132 <- function(date, approx) {
      indicateur_a132_1(tables$serie_tme, date, ct$nature_primes, ct$date_effet, ct$date_terme,
                        st$decalage_publication_mois, ct$taux_tarif, ct$id_contrat, poste, garantie, type_organisme, approx)
    }
    # lignes hors_axes_derniere_valeur (S3, § 5.8) après les lignes A132_1, dans l'ordre des contrats
    indicateurs <- rbind(tarif_vie, a132(ct$date_souscription, FALSE), a132(vue$bilan$vue$date_arrete, TRUE),
                         ind$hors_axes)
    rownames(indicateurs) <- NULL
    e <- ind$echeancier
    echeanciers <- data.frame(cle = e$cle, referentiel = rep(.REFERENTIEL_P3, nrow(e)), poste = rep(poste, nrow(e)),
                              date = e$date, etat = e$etat, type_flux = e$type_flux, flux = e$flux,
                              probabilite = e$probabilite, actualisation = e$actualisation,
                              valeur_actuelle = e$valeur_actuelle, stringsAsFactors = FALSE)[COLONNES_ECHEANCIERS]
  }
  # contrats valorisés, par champ (restitution par segment, #67) : montant après plancher
  contrats <- rbind(contrats_vides,
                    if (!is.null(ct)) data.frame(id_contrat = ct$id_contrat, champ = rep("individuel", nrow(ct)),
                                                 montant = ct$montant,
                                                 statut_resultat = statut_ind,
                                                 stringsAsFactors = FALSE),
                    if (nrow(col)) data.frame(id_contrat = col$id_contrat, champ = rep("collectif", nrow(col)),
                                              montant = col$montant, statut_resultat = statut_col,
                                              stringsAsFactors = FALSE))
  contrats <- contrats[order(contrats$id_contrat, contrats$champ, method = "radix"), , drop = FALSE]
  rownames(contrats) <- NULL
  list(cellules = cellule(total, statut_le_plus_faible(statuts), NA_character_), dossiers = dossiers, echeanciers = echeanciers,
       indicateurs = indicateurs, contrats = contrats)
}
