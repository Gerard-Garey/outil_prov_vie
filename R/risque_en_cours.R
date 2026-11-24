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

# --- Sélections communes aux deux champs -------------------------------------------

# Garanties souscrites deces de P3 (indices dans la vue) : retenues, d'identifiant renseigné
# (une garantie souscrite d'identifiant manquant ou vide n'est d'aucune population et une clé
# manquante ou vide ne s'apparie à rien : cle_renseignee(), apparier_cles(), #154, règles (ii)
# et (iii)), hors couverture exclue pour risque_en_cours (erratum v1.0.13 : garantie souscrite,
# ou contrat, exclu ; garanties_couverture_exclue(), seule implémentation, appelée ici seulement).
# Seule sélection, lue par provisions_individuelles(), provisions_collectives() et
# calculer_risque_en_cours() avant leurs filtres propres.
.gs_deces_p3 <- function(vue) {
  vv <- function(t, c1) valeurs_vue(vue, t, c1)
  gs <- which(vue$retenu$garanties_souscrites & vv("garanties_souscrites", "code_garantie") %in% "deces" &
                cle_renseignee(vv("garanties_souscrites", "id_garantie_souscrite")))
  gs[is.na(apparier_cles(vv("garanties_souscrites", "id_garantie_souscrite")[gs],
                         garanties_couverture_exclue(vue, "risque_en_cours")))]
}

# Cotisations que P3 peut lire (liste des lignes lues du § 5.8, désignée par l'erratum du projet
# de dictionnaire 1.6, § 11.5, #72) : logique sur les lignes de `cotisations`, faux pour une
# cotisation de nature connue hors de .NATURES_PRORATA ou de fin_periode connue au plus A (`a`,
# jours). Une valeur manquante, cachée (clés seules lisibles pour une cotisation hors de la vue,
# E17-3) ou refusée par un refus de portée ligne (lignes_refus_ligne_vue() de `donnees`) est
# inconnue : la cotisation est admise (lecture de Kleene) ; une colonne fin_periode de chaînes
# (refus type_incompatible, portée colonne : la vue la garde brute) n'est pas lue, ses valeurs
# sont inconnues (P3, qui la lit, est arrêté par le bilan). Seul filtre, lu par
# .lectures_contrats() (arrêt par unité et source S2 du champ (b)).
.cotisations_admises_p3 <- function(vue, a) {
  nature <- valeurs_vue(vue, "cotisations", "nature_mouvement")
  fin <- valeurs_vue(vue, "cotisations", "fin_periode")
  fin <- if (is.character(fin)) rep(NA_real_, length(fin)) else as.numeric(fin)
  nature[lignes_refus_ligne_vue(vue, "cotisations", "nature_mouvement")] <- NA
  fin[lignes_refus_ligne_vue(vue, "cotisations", "fin_periode")] <- NA
  !(!is.na(nature) & !(nature %in% .NATURES_PRORATA)) & !(!is.na(fin) & fin <= a)
}

# Colonnes de sinistres qui décident de la sortie d'un contrat de P3 champ (a) par un sinistre
# (garde du point 1 de #112 étendue, #90 ; spécification de B2, § 5.8, erratum v1.0.24) : lues
# par provisions_individuelles() (sortie restituée) et par .population_p3() (sortie observée).
.LUES_SINISTRE_P3 <- c("id_assure", "nature_sinistre", "date_survenance", "date_saisie")

# Population de P3 (spécification de B2, § 5.5 et § 5.8, erratum v1.0.23, V2 (ii), « Population
# de P3 » et « Code de garantie refusé » ; #72, #174) : contrats retenus qui portent une garantie
# souscrite de la sélection, dans l'ordre de la table contrats. Sélection : `gs` (indices dans la
# vue, rendus par .gs_deces_p3(), qu'appelle l'appelant) et les garanties de code refusé de
# garanties_code_refuse() (`engagement`, seule sélection, partagée avec P1 et P2), dans l'ordre
# de la table. `plan` : plan canonique (conventions$age ; méthode du champ (a)). Fonction à trois
# valeurs, lecture de Kleene : une valeur est connue si elle n'est ni refusée de portée ligne
# (lignes_refus_ligne_vue()), ni tenue pour inconnue par D02a sous H (dates_inconnues_vue()), ni
# portée par une ligne exclue pour risque_en_cours, ni ambiguë, ni dans une colonne de type
# incompatible (gardée brute par la vue, non lue) ; une inconnue ne retire jamais une unité.
# `individuel` : TRUE (champ (a)), FALSE (champ (b)) ou NA (nature refusée ou manquante).
# Champ (a), sortie connue (une suffit) : aucune version de la sélection n'est connue `deces` et
# en vigueur à A (date_effet au plus A, date_fin absente ou postérieure à A) ou d'âge de fin
# connu atteint au plus A (age_fin_garantie de la version, parametre_vue() : ni ambigu, ni exclu,
# ni refusé, entier de 0 à AGE_MAXIMUM ; date de naissance de l'assuré connue,
# date_atteinte_age()) ; date_terme connue au plus A ; date_fin connue au plus A dont la partie de
# fin ne porte aucune hypothèse de la vue (voie observée) ; sinistre observé de l'assuré (retenu,
# non exclu, deces ou iad et survenu au plus A, valeurs connues, sans hypothèse de la vue sur
# .LUES_SINISTRE_P3). Une sortie qu'une hypothèse de la vue décide (contrat restitué à 0,
# `sortis` de provisions_individuelles()) n'en est pas une : le contrat reste une unité. Champ
# (b) : contrat sorti si chacune des cotisations retenues de ses garanties de la sélection est
# connue non admise (nature connue hors de .NATURES_PRORATA, ou fin_periode connue au plus A), ou
# s'il n'en a aucune ; une cotisation est connue admise si sa nature est dans .NATURES_PRORATA et
# sa fin_periode connue postérieure à A, ou manquante (ou tenue pour inconnue) sous l'hypothèse
# D03f appliquée à la ligne (hypothese_vue() : règle H, contrat calculé ou restitué) ; sinon
# (valeur refusée ou inconnue, ligne exclue) inconnue. Une cotisation cachée (hors de la vue) n'a
# pas de clé lisible et n'est pas lue (aucune hypothèse de la vue ne porte sur cotisations en
# B2). `appartenance` = (individuel ET non sorti du champ (a)) OU (NON individuel ET non sorti
# du champ (b)), en logique de Kleene : FALSE (sorti, valeur connue : ni calculé, ni restitué, ne
# lit aucune ligne), TRUE (contrat de la population) ou NA (unité possible). Rend list(id_contrat,
# id_assure, individuel, appartenance : une valeur par contrat ; gs, id_garantie_souscrite,
# unite_gs (rang du contrat de chaque garantie, NA hors population), vigueur_gs (version connue
# `deces` en vigueur à A, Kleene) : une valeur par garantie de la sélection). Seule population de
# P3, lue par l'arrêt par unité (calculer_risque_en_cours()), par provisions_individuelles() et
# provisions_collectives() (contrats calculés : appartenance non FALSE, champ connu) et par la
# détection S2 des deux champs, à travers les lignes lues de .lectures_contrats().
.population_p3 <- function(vue, gs, plan) {
  vv <- function(t, c1) valeurs_vue(vue, t, c1)
  a <- as.numeric(vue$bilan$vue$date_arrete)
  exclu <- vue$exclu$risque_en_cours
  refusee <- function(t, c1) lignes_refus_ligne_vue(vue, t, c1)
  # date lue en Kleene : `x` (NA brut : absente), `inc` (refusée, tenue pour inconnue, ou colonne
  # de type incompatible, gardée brute par la vue : jamais convertie)
  date_k <- function(t, c1) {
    x <- vv(t, c1)
    inc <- refusee(t, c1) | dates_inconnues_vue(vue, t, c1)
    if (is.character(x)) return(list(x = rep(NA_real_, length(x)), inc = rep(TRUE, length(x))))
    list(x = as.numeric(x), inc = inc)
  }
  gs <- sort(unique(c(gs, garanties_code_refuse(vue, "risque_en_cours"))), method = "radix")
  gs_ct <- as.character(vv("garanties_souscrites", "id_contrat")[gs])
  ct <- which(vue$retenu$contrats & !is.na(apparier_cles(vv("contrats", "id_contrat"), gs_ct)))
  id_ct <- as.character(vv("contrats", "id_contrat")[ct])
  id_gs <- as.character(vv("garanties_souscrites", "id_garantie_souscrite")[gs])
  unite_gs <- apparier_cles(gs_ct, id_ct)
  nature <- vv("contrats", "nature_contrat")[ct]
  nature[refusee("contrats", "nature_contrat")[ct]] <- NA
  individuel <- ifelse(is.na(nature), NA, nature %in% "individuel")
  # champ (a) : version connue deces en vigueur à A ; âge de fin connu atteint au plus A
  deces <- ifelse(refusee("garanties_souscrites", "code_garantie")[gs], NA,
                  vv("garanties_souscrites", "code_garantie")[gs] %in% "deces")
  ge <- date_k("garanties_souscrites", "date_effet")
  gf <- date_k("garanties_souscrites", "date_fin")
  effet_ok <- ifelse(ge$inc[gs] | is.na(ge$x[gs]), NA, ge$x[gs] <= a)
  fin_ok <- ifelse(gf$inc[gs], NA, is.na(gf$x[gs]) | gf$x[gs] > a)
  vigueur <- deces & effet_ok & fin_ok
  assure <- as.character(vv("contrats", "id_assure")[ct])
  i_as <- apparier_cles(assure, vv("assures", "id_assure"))
  dn <- date_k("assures", "date_naissance")
  naissance <- dn$x[i_as]
  naissance[is.na(i_as) | dn$inc[i_as] %in% TRUE | exclu$assures[i_as] %in% TRUE] <- NA
  age <- parametre_vue(vue, "age_fin_garantie", id_gs, "risque_en_cours")
  age_connu <- !is.na(age$valeur) & !age$ambigu & !age$exclu & !age$refuse & is.finite(age$valeur) &
    age$valeur == trunc(age$valeur) & age$valeur >= 0 & age$valeur <= AGE_MAXIMUM
  ok_age <- age_connu & !is.na(unite_gs) & !is.na(naissance[unite_gs])
  atteint <- rep(NA, length(gs))
  atteint[ok_age] <- as.numeric(date_atteinte_age(structure(naissance[unite_gs[ok_age]], class = "Date"),
                                                  as.integer(age$valeur[ok_age]), plan$conventions$age)) <= a
  gs_sortie <- !vigueur | atteint
  terme <- date_k("contrats", "date_terme")
  terme_sortie <- ifelse(terme$inc[ct], NA, !is.na(terme$x[ct]) & terme$x[ct] <= a)
  # date_fin au plus A par la voie observée : la partie de fin ne porte aucune hypothèse de la vue
  # (même garde que provisions_individuelles()). Partie de ligne (spécification de B2, § 6.2,
  # erratum v1.0.5 : une colonne de la partie, inconnue ou refusée, rend inconnue toute la
  # partie) : une colonne de la partie de fin (parties_ligne()) refusée de portée ligne ou tenue
  # pour inconnue par D02a sous H, ou une partie de visibilité non déterminée (vue$parties), rend
  # la fin inconnue (une colonne de type incompatible arrête P3 au bilan ; date_fin de chaînes
  # n'est pas lue, date_k())
  fin_ligne <- Filter(function(q) q$table == "contrats", parties_ligne())[[1L]]$colonnes
  fin_s2 <- .lignes_sous_hypothese(vue, fin_ligne, "contrats", "id_contrat")[ct]
  fc <- date_k("contrats", "date_fin")
  partie_inc <- Reduce(`|`, lapply(fin_ligne, function(c1) refusee("contrats", c1) | dates_inconnues_vue(vue, "contrats", c1)))[ct]
  if (!is.null(vue$parties$contrats)) partie_inc <- partie_inc | is.na(vue$parties$contrats[ct])
  fin_sortie <- ifelse(fc$inc[ct] | partie_inc, NA, !is.na(fc$x[ct]) & fc$x[ct] <= a & !fin_s2)
  # sinistre de sortie de l'assuré : observé (TRUE), sous hypothèse de la vue (sans effet), inconnu
  s_ass <- as.character(vv("sinistres", "id_assure"))
  nat_s <- ifelse(refusee("sinistres", "nature_sinistre"), NA, vv("sinistres", "nature_sinistre") %in% c("deces", "iad"))
  sv <- date_k("sinistres", "date_survenance")
  sortie_s <- nat_s & ifelse(sv$inc | is.na(sv$x), NA, sv$x <= a)
  sortie_s[exclu$sinistres] <- NA
  ret_s <- vue$retenu$sinistres & cle_renseignee(s_ass)
  s_obs <- ret_s & sortie_s %in% TRUE & !.lignes_sous_hypothese(vue, .LUES_SINISTRE_P3, "sinistres", "id_sinistre")
  s_inc <- ret_s & is.na(sortie_s)
  sin_sortie <- ifelse(!is.na(apparier_cles(assure, s_ass[s_obs])), TRUE,
                       ifelse(!is.na(apparier_cles(assure, s_ass[s_inc])), NA, FALSE))
  sin_sortie[!cle_renseignee(assure)] <- NA
  sortie_a <- sin_sortie | terme_sortie | fin_sortie |
    vapply(seq_along(ct), function(j) all(gs_sortie[!is.na(unite_gs) & unite_gs == j]), NA)
  # champ (b) : cotisations retenues des garanties de la sélection, admises (Kleene)
  co_gs <- as.character(vv("cotisations", "id_garantie_souscrite"))
  i_co <- which(vue$retenu$cotisations & !is.na(apparier_cles(co_gs, id_gs)))
  u_co <- unite_gs[apparier_cles(co_gs[i_co], id_gs)]
  nat_c <- ifelse(refusee("cotisations", "nature_mouvement")[i_co], NA,
                  ifelse(is.na(vv("cotisations", "nature_mouvement")[i_co]), NA,
                         vv("cotisations", "nature_mouvement")[i_co] %in% .NATURES_PRORATA))
  fp <- date_k("cotisations", "fin_periode")
  fin_ref <- refusee("cotisations", "fin_periode")[i_co] | is.character(vv("cotisations", "fin_periode"))
  le_a <- ifelse(fp$inc[i_co] | is.na(fp$x[i_co]), NA, fp$x[i_co] <= a)
  regle_h <- !fin_ref & is.na(fp$x[i_co]) & !is.na(hypothese_vue(vue, "D03f", .REFERENTIEL_P3, "cotisations", i_co, .POSTE_P3))
  adm <- ifelse(nat_c %in% FALSE | le_a %in% TRUE, FALSE, ifelse(nat_c %in% TRUE & (le_a %in% FALSE | regle_h), TRUE, NA))
  adm[exclu$cotisations[i_co]] <- NA
  admise_b <- vapply(seq_along(ct), function(j) any(adm[!is.na(u_co) & u_co == j]), NA)
  list(id_contrat = id_ct, id_assure = assure, individuel = individuel,
       appartenance = (individuel & !sortie_a) | (!individuel & admise_b),
       gs = gs, id_garantie_souscrite = id_gs, unite_gs = unite_gs, vigueur_gs = vigueur)
}

# Garde de la population de P3 (spécification de B2, § 5.8, erratum v1.0.23, V2 (ii)) : un
# contrat de champ non déterminé (`individuel` NA) qui reste une unité possible lit sa ligne de
# contrats, dont la nature refusée arrête le poste avant tout calcul (calculer_risque_en_cours()) :
# l'atteindre au calcul ou dans S2 est une erreur interne.
.controler_population_p3 <- function(pop, fonction) {
  if (any(is.na(pop$individuel) & !(pop$appartenance %in% FALSE))) {
    stop("erreur interne de provie : ", fonction, "() : contrat de P3 de champ non d\u00e9termin\u00e9 au calcul",
         call. = FALSE)
  }
  invisible(NULL)
}

# Constructeur des lignes lues par unité de P3 (liste des lignes lues du § 5.8 de la
# spécification de B2, erratum du projet de dictionnaire 1.6, § 11.5, #72, complétée par
# l'erratum v1.0.23, #174 ; seule construction de la famille, lue par l'arrêt par unité,
# arret_refus_ligne(), et par la détection S2 des deux champs, hypotheses_vue_unites()) : `pop`
# (.population_p3()), `a` (arrêté, jours), `methode` (méthode du champ (a) du plan). Unités : les
# contrats de `pop`, dans leur ordre ; seul un contrat d'appartenance TRUE ou NA (unité possible)
# lit des lignes. Lignes lues, éléments de lecture_unites(), dans cet ordre : la ligne de
# contrats du contrat ; champ (a) possible (`individuel` TRUE ou NA), la ligne de assures de son
# assuré et les lignes de sinistres de cet assuré ; champ (b) possible (`individuel` FALSE ou
# NA), les cotisations de ses garanties de la sélection qu'admet .cotisations_admises_p3()
# (natures emission, annulation, regularisation ; fin_periode connue au plus A retirée ; valeur
# refusée tenue pour inconnue, donc admise) ; les lignes de garanties_souscrites du contrat de
# code deces ou de code refusé, toutes versions ; champ (a) possible, les lignes de parametres
# des versions de la sélection en vigueur à A ou de dates non déterminées (`vigueur_gs` non
# FALSE) nommées capital_forfaitaire, age_fin_garantie et, sous prospective_prime_declaree,
# prime_periodique (un nom refusé de portée ligne est inconnu, donc admis) ; ces deux dernières
# de champ `s2` FALSE (lues par l'arrêt seulement, V3 (c)). Rend la liste `lectures`.
.lectures_contrats <- function(vue, pop, a, methode) {
  possible <- !(pop$appartenance %in% FALSE)
  ind <- pop$individuel
  u <- pop$unite_gs
  adm_gs <- valeurs_vue(vue, "garanties_souscrites", "code_garantie") %in% "deces" |
    lignes_refus_ligne_vue(vue, "garanties_souscrites", "code_garantie")
  nom <- valeurs_vue(vue, "parametres", "parametre")
  adm_par <- nom %in% c("capital_forfaitaire", "age_fin_garantie") |
    (identical(methode, "prospective_prime_declaree") & nom %in% "prime_periodique") |
    lignes_refus_ligne_vue(vue, "parametres", "parametre")
  list(lecture_unites("contrats", "id_contrat", pop$id_contrat, garde = possible),
       lecture_unites("assures", "id_assure", pop$id_assure, garde = possible & !(ind %in% FALSE)),
       lecture_unites("sinistres", "id_assure", pop$id_assure, garde = possible & !(ind %in% FALSE)),
       lecture_unites("cotisations", "id_garantie_souscrite", pop$id_garantie_souscrite, unite = u,
                      garde = !is.na(u) & possible[u] & !(ind[u] %in% TRUE), admises = .cotisations_admises_p3(vue, a)),
       lecture_unites("garanties_souscrites", "id_contrat", pop$id_contrat, garde = possible, admises = adm_gs, s2 = FALSE),
       lecture_unites("parametres", "id_garantie_souscrite", pop$id_garantie_souscrite, unite = u,
                      garde = !is.na(u) & possible[u] & !(ind[u] %in% FALSE) & !(pop$vigueur_gs %in% FALSE),
                      admises = adm_par, s2 = FALSE))
}

# Rang dans la population `pop` (.population_p3()) de chacun des contrats `ids` (apparier_cles()) :
# unité de .lectures_contrats() dont le contrat lit les codes S2. Un contrat hors de la population
# est une erreur interne.
.unites_p3 <- function(pop, ids) {
  u <- apparier_cles(ids, pop$id_contrat)
  if (anyNA(u)) {
    stop("erreur interne de provie : contrat de P3 hors de la population (.population_p3())", call. = FALSE)
  }
  u
}

# Lignes de `table` de la vue (sinistres ou contrats, de clé `cle`) qui portent une hypothèse de
# la vue (S2) sur l'une des colonnes `lues` (hypotheses_vue_unites(), chaque ligne rattachée à
# elle-même par sa clé) : logique sur les lignes de la table. Unités : les lignes de la table,
# non des contrats ; seule exception aux constructeurs des lignes lues par unité, lue par
# provisions_individuelles() et .population_p3() (voie de sortie observée, erratum v1.0.19,
# réserve R6 : lignes de sinistres sur .LUES_SINISTRE_P3 ; partie de fin de la ligne de
# contrats, table "contrats", clé id_contrat, pour .population_p3()).
.lignes_sous_hypothese <- function(vue, lues, table, cle) {
  ids <- as.character(valeurs_vue(vue, table, cle))
  nzchar(hypotheses_vue_unites(vue, .REFERENTIEL_P3, .POSTE_P3, "risque_en_cours", length(ids),
                               list(lecture_unites(table, cle, ids, lues = lues))))
}

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
# capital, taux_tarif, taux_retenu, hypothese_d03h, hypotheses_vue (codes des hypothèses de la
# vue appliquées aux lignes lues pour le contrat, source S2 du § 5.8, #87 ; "" sans hypothèse),
# extrapole (un point de mortalite_tarif lu hors des axes sous derniere_valeur, source S3 du
# § 5.8, #91), a_effet, a_double_effet (ä à l'effet), prime, valeur (avant plancher), montant
# (plancher nul par contrat), retro_avant_prime,
# retro_apres_prime (témoin rétrospectif, calculé seulement si `temoin` vaut TRUE ; NA sinon,
# ou si l'arrêté n'est pas une date de pas ou si la prime est unique),
# nature_primes, date_effet, date_terme, date_souscription), echeancier (flux à l'arrêté,
# taux retenu), arret (motif né de la famille : hors_axes, parametre_non_determine ; NA),
# identifiant (contrat en cause : le plus petit des contrats en cause à l'étape qui décide, tri
# radix, indépendant de l'ordre des lignes, spécification de B2, § 6.2, « Identifiant publié »,
# #176), hors_axes (lignes d'indicateur
# hors_axes_derniere_valeur de indicateur_hors_axes(), une par contrat extrapolé, dans l'ordre
# des contrats ; NULL sans extrapolation), sortis (contrats sortis de la population par un
# sinistre ou par leur date_fin au plus A, dont une ligne qui décide de la sortie porte une
# hypothèse de la vue, source S2 du § 5.8 : unités restituées à 0, errata v1.0.17 et v1.0.18 ;
# triés), refus_d03h (garantie souscrite d'un contrat valorisé au taux du tarif manquant sans
# hypothèse D03h de P3 ou de `tous` appliquée, la plus petite (tri radix), quand aucun arrêt du
# champ n'est né : refus de lecture R2 différé, levé par calculer_risque_en_cours(), § 6.2,
# erratum v1.0.21, #108 ; aucun contrat n'est alors valorisé ; NA sinon)). Sans point :
# lue par les tests du module (cas T1 à T6) et par calculer_risque_en_cours() (`temoin` =
# FALSE : le témoin n'est jamais restitué) ; non exportée. `temoin` : TRUE ou FALSE, exigé.
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
  vide <- list(contrats = NULL, echeancier = NULL, arret = NA_character_, identifiant = NA_character_,
               hors_axes = NULL, sortis = character(0), refus_d03h = NA_character_)
  # garanties souscrites deces retenues, version en vigueur à l'arrêté, de contrats individuels
  # (.gs_deces_p3() : couverture exclue hors de la population, avant toute lecture ; `gs_p3` : la
  # sélection entière, lue par .population_p3()). Population de P3 (.population_p3(), seule
  # population, V2 (ii), #174) : seuls les contrats d'appartenance non FALSE, de champ (a)
  # connu, sont lus ; un contrat de champ non déterminé est une erreur interne
  gs_p3 <- .gs_deces_p3(vue)
  gs <- gs_p3
  pop <- .population_p3(vue, gs_p3, plan)
  .controler_population_p3(pop, "provisions_individuelles")
  # dates tenues pour inconnues par D02a sous H (dates_inconnues_vue(), `donnees` ; spécification
  # `donnees` v1.9, § 9.4, #90) : version de garantie (R4) ou contrat (R1 à R3) dont la mise en
  # vigueur ou la fin n'est pas connue ; gardés dans la population, ils arrêtent le poste
  # (parametre_non_determine), sauf sortie par une condition connue (sinistre de l'assuré)
  inconnue <- function(t, c1) dates_inconnues_vue(vue, t, c1)
  g_inconnue <- (inconnue("garanties_souscrites", "date_effet") | inconnue("garanties_souscrites", "date_fin"))[gs]
  g_effet <- as.numeric(vv("garanties_souscrites", "date_effet"))[gs]
  g_fin <- as.numeric(vv("garanties_souscrites", "date_fin"))[gs]
  gs <- gs[g_inconnue | (g_effet <= a & (is.na(g_fin) | g_fin > a))]
  i_ct <- apparier_cles(vv("garanties_souscrites", "id_contrat")[gs], vv("contrats", "id_contrat"))
  garde <- !is.na(i_ct)
  j_pop <- apparier_cles(vv("contrats", "id_contrat")[i_ct[garde]], pop$id_contrat)
  garde[garde] <- !is.na(j_pop) & !(pop$appartenance[j_pop] %in% FALSE) & pop$individuel[j_pop] %in% TRUE &
    (as.numeric(vv("contrats", "date_effet"))[i_ct[garde]] <= a | inconnue("contrats", "date_effet")[i_ct[garde]])
  gs <- gs[garde]
  i_ct <- i_ct[garde]
  if (length(gs) == 0L) return(vide)
  date_inconnue <- (inconnue("garanties_souscrites", "date_effet") | inconnue("garanties_souscrites", "date_fin"))[gs] |
    (inconnue("contrats", "date_effet") | inconnue("contrats", "date_terme") | inconnue("contrats", "date_fin"))[i_ct]
  id_gs <- as.character(vv("garanties_souscrites", "id_garantie_souscrite")[gs])
  id_ct <- as.character(vv("contrats", "id_contrat")[i_ct])
  assure <- as.character(vv("contrats", "id_assure")[i_ct])
  # ligne de assures exclue pour risque_en_cours : date de naissance inconnue, traitée comme
  # manquante (erratum v1.0.10, #82)
  i_as <- apparier_cles(assure, vv("assures", "id_assure"))
  naissance <- vv("assures", "date_naissance")[i_as]
  naissance[!is.na(i_as) & exclu$assures[i_as]] <- NA
  effet <- as.numeric(vv("contrats", "date_effet"))[i_ct]
  terme <- as.numeric(vv("contrats", "date_terme"))[i_ct]
  fin_ct <- as.numeric(vv("contrats", "date_fin"))[i_ct]
  # paramètres lus par P3 (erratum v1.0.9, #78) : une ligne retenue exclue pour risque_en_cours
  # rend le paramètre non déterminé (jamais 0 ni absent) ; age_fin_garantie exclu est inconnu
  # avant le calcul de la fin de couverture (lecture de Kleene : un âge de fin inconnu ne fait
  # sortir aucun contrat ; la sortie connue de la population, par l'âge de fin connu et atteint,
  # le terme, la date_fin observée, un sinistre observé ou l'absence de version deces en vigueur,
  # est évaluée par .population_p3(), V2 (ii))
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
  # assuré du contrat et du sinistre : une clé manquante ou vide ne s'apparie à rien (#154, règle (iii))
  sinistre <- !is.na(apparier_cles(assure, s_id[s]))
  # sinistre retenu, non exclu, deces ou iad, de survenance tenue pour inconnue (D02a sous H, R8 et
  # R9) : peut être survenu au plus A, inconnu comme un sinistre exclu
  s_survenance <- vue$retenu$sinistres & !exclu$sinistres & vv("sinistres", "nature_sinistre") %in% c("deces", "iad") &
    inconnue("sinistres", "date_survenance")
  sinistre_inconnu <- !is.na(apparier_cles(assure, s_id[(vue$retenu$sinistres & exclu$sinistres) | s_survenance]))
  # hypothèses de la vue appliquées aux lignes lues pour le contrat (source S2, § 5.8, #87), sur
  # la population avant la sortie par un sinistre : la ligne de contrats du contrat, celle de
  # assures de son assuré, celles de sinistres de cet assuré, visibles ou non à A (statut).
  # Contrat restitué à 0 (`sortis`, errata v1.0.17 et v1.0.18) seulement si une ligne qui
  # décide de sa sortie porte S2 (constat M1, réserves R1, R4, R5 ; décision E18-2) : sorti par
  # un sinistre, une ligne de sinistres de l'assuré retenue, non exclue, deces ou iad, survenue
  # au plus A (un sinistre caché ne décide pas) ; sorti par sa fin de couverture date_fin au
  # plus A (fin contractuelle postérieure à A), la ligne de contrats (partie de fin)
  par_fin <- fin_contractuelle > a & !is.na(fin_ct) & fin_ct <= a
  cand <- which(fin > a | par_fin)
  s_decide <- vue$retenu$sinistres & (vv("sinistres", "nature_sinistre") %in% c("deces", "iad") &
                                        as.numeric(vv("sinistres", "date_survenance")) <= a) %in% TRUE
  # liste des lignes lues par unité de P3 (.lectures_contrats(), seule construction, celle de
  # l'arrêt par unité), lue entière aux contrats candidats (champ (a) connu : contrats, assures,
  # sinistres ; garanties_souscrites et parametres, de champ s2 FALSE, non lues par S2)
  lect <- .lectures_contrats(vue, pop, a, methode)
  u_cand <- .unites_p3(pop, id_ct[cand])
  s2_cand <- function(lect) {
    res <- rep("", length(gs))
    res[cand] <- hypotheses_vue_unites(vue, .REFERENTIEL_P3, .POSTE_P3, "risque_en_cours", length(pop$id_contrat), lect)[u_cand]
    res
  }
  s2 <- s2_cand(lect)
  # sortie par un sinistre : seules les hypothèses qui portent sur une colonne lue pour l'établir
  # (assuré, nature, survenance, date de saisie : .LUES_SINISTRE_P3) en décident (garde du point 1
  # de #112 étendue, #90 : D02a de R10, sur la déclaration et l'instruction, n'en décide pas ; D02b
  # et D03g portent date_saisie ; sous R8 et R9 la survenance est tenue pour inconnue, la sortie
  # n'est pas établie)
  lues_sin <- .LUES_SINISTRE_P3
  decide_sin <- nzchar(s2_cand(lapply(Filter(function(l) l$table == "sinistres", lect),
                                      function(l) { l$admises <- s_decide; l$lues <- lues_sin; l })))
  # partie de fin du contrat : seules les hypothèses qui portent sur l'une de ses colonnes en
  # décident (garde du point 1 de #112, M661 ; spécification `donnees` v1.9, § 9.4 : D02a sur
  # date_terme, R2, ou date_debut_gestion, R3, n'en décide pas ; sur date_fin, R1, oui)
  fin_ligne <- Filter(function(q) q$table == "contrats", parties_ligne())[[1L]]$colonnes
  decide_fin <- nzchar(s2_cand(lapply(Filter(function(l) l$table == "contrats", lect),
                                      function(l) { l$lues <- fin_ligne; l })))
  # voie de sortie observée (erratum v1.0.19, réserve R6) : un sinistre de l'assuré retenu, non
  # exclu, deces ou iad, survenu au plus A, dont la ligne ne porte aucune hypothèse de la vue,
  # ou une date_fin au plus A dont la partie de fin n'en porte pas, établit la sortie sans
  # hypothèse : pas de restitution
  s_place <- .lignes_sous_hypothese(vue, lues_sin, "sinistres", "id_sinistre")
  sinistre_obs <- !is.na(apparier_cles(assure, s_id[s_decide & !exclu$sinistres & !s_place]))
  fin_obs <- par_fin & !decide_fin
  vide$sortis <- sort(unique(id_ct[((fin > a & sinistre & decide_sin) | (par_fin & decide_fin)) & !sinistre_obs & !fin_obs]),
                      method = "radix")
  en_cours <- fin > a & !sinistre
  if (!any(en_cours)) return(vide)
  k <- which(en_cours)
  manque <- k[sinistre_inconnu[k] | date_inconnue[k] | is.na(capital$valeur[k]) | capital$ambigu[k] | capital$exclu[k] | is.na(age_fin$valeur[k]) |
                age_fin$ambigu[k] | is.na(naissance[k]) | is.infinite(fin[k]) |
                (methode == "prospective_prime_declaree" & !is.na(periode[k]) & (is.na(prime_p$valeur[k]) | prime_p$ambigu[k])) |
                (methode == "prospective_prime_declaree" & prime_p$exclu[k])]
  if (length(manque)) return(list(contrats = NULL, echeancier = NULL, arret = "parametre_non_determine",
                                  identifiant = sort(id_ct[manque], method = "radix")[1L], hors_axes = NULL,
                                  sortis = vide$sortis, refus_d03h = NA_character_))
  # taux du tarif ; hypothèse D03h déclarée s'il manque. Sans hypothèse D03h de P3 ou de `tous`
  # appliquée à la ligne (refus de lecture R2, spécification de B2, § 6.2, erratum v1.0.21,
  # #108) : refus declaration_manquante différé, non levé ici ; la plus petite garantie souscrite
  # en cause (tri radix, § 6.2, « Identifiant publié », #176) est rendue dans `refus_d03h`, après
  # les arrêts hors_axes du champ, et calculer_risque_en_cours() le lève après tous les arrêts du
  # poste, les deux champs compris
  tarif <- vv("garanties_souscrites", "taux_technique_tarif")[gs]
  d03h <- rep(FALSE, length(gs))
  sans_d03h <- character(0)
  for (i in k[is.na(tarif[k])]) {
    h <- .hypothese_d03h(vue, gs[i])
    if (is.null(h)) {
      sans_d03h <- c(sans_d03h, id_gs[i])
      next
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
  # sous hors_axes = refus, tous les contrats lus hors des axes sont recensés avant l'arrêt : le
  # contrat publié est le plus petit (tri radix, § 6.2, « Identifiant publié », #176)
  contrats_hors <- character(0)
  for (i in k) {
    n_annees <- 0L
    while (ajouter_mois(effet[i], 12L * n_annees) < fin_contractuelle[i]) n_annees <- n_annees + 1L
    points <- list(age = age0[i] + seq_len(n_annees) - 1L)
    q <- probabilite(tables$mortalite_tarif, age = points$age, hors_axes = hors)
    if (length(attr(q, "hors_axes"))) {
      if (identical(hors, "refus")) {
        contrats_hors <- c(contrats_hors, id_ct[i])
        next
      }
      extrapole[i] <- TRUE
      hors_axes[[length(hors_axes) + 1L]] <- indicateur_hors_axes(tables$mortalite_tarif, points, q, "mortalite_tarif",
                                                                  id_ct[i], .POSTE_P3, "deces")
    }
    q_de[[as.character(i)]] <- as.vector(q)
  }
  if (length(contrats_hors)) {
    return(list(contrats = NULL, echeancier = NULL, arret = "hors_axes",
                identifiant = sort(contrats_hors, method = "radix")[1L], hors_axes = NULL, sortis = vide$sortis,
                refus_d03h = NA_character_))
  }
  # refus de lecture R2 de D03h en attente (aucun arrêt du champ) : aucun contrat valorisé
  if (length(sans_d03h)) {
    return(list(contrats = NULL, echeancier = NULL, arret = NA_character_, identifiant = NA_character_,
                hors_axes = NULL, sortis = vide$sortis, refus_d03h = sort(sans_d03h, method = "radix")[1L]))
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
      taux_retenu = taux_r, hypothese_d03h = d03h[i], hypotheses_vue = s2[i], extrapole = extrapole[i],
      a_effet = a_effet,
      a_double_effet = a_dbl, prime = prime,
      valeur = v$total, montant = max(0, v$total), retro_avant_prime = retro[1L], retro_apres_prime = retro[2L],
      nature_primes = if (unique_p) "unique" else "periodique", date_effet = structure(effet[i], class = "Date"),
      date_terme = structure(terme[i], class = "Date"),
      date_souscription = structure(as.numeric(vv("garanties_souscrites", "date_effet"))[gs[i]], class = "Date"),
      stringsAsFactors = FALSE)
    echeancier[[length(echeancier) + 1L]] <- v$echeancier
  }
  list(contrats = do.call(rbind, lignes), echeancier = do.call(rbind, echeancier), arret = NA_character_,
       identifiant = NA_character_, hors_axes = do.call(rbind, hors_axes), sortis = vide$sortis,
       refus_d03h = NA_character_)
}

# Valeur de l'hypothèse D03h appliquée à la ligne `ligne` de garanties_souscrites
# (hypothese_vue() de `engagement`, seule sélection : motif D03h, référentiel comptes_sociaux,
# poste P3 de préférence à `tous`), lue comme un taux décimal ; NULL sans hypothèse appliquée.
# La forme de la valeur (décimal dans [-0,05 ; 0,10]) est contrôlée au plan par
# lire_declarations() (`donnees`, erratum v1.0.21, § 2.3, #99) : une valeur qui n'est pas un
# nombre fini ici est une erreur interne.
.hypothese_d03h <- function(vue, ligne) {
  valeur <- hypothese_vue(vue, "D03h", .REFERENTIEL_P3, "garanties_souscrites", ligne, .POSTE_P3)
  if (is.na(valeur)) return(NULL)
  taux <- suppressWarnings(as.numeric(valeur))
  if (!is.finite(taux)) {
    stop("erreur interne de provie : hypoth\u00e8se D03h de valeur \u00ab ", valeur,
         " \u00bb, hors de la forme contr\u00f4l\u00e9e au plan (lire_declarations())", call. = FALSE)
  }
  taux
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
# plus A : hors du calcul, quels que soient debut_periode et le traitement déclaré de D03f
# (l'hypothèse D03f n'est pas lue pour la ligne, décision E16-2) ; (2) borne manquante, ou
# tenue pour inconnue (D02a sous H, R7 : les deux bornes sont inconnues dans la vue et D03f
# s'enchaîne, #90) : traitement déclaré de D03f ; (3) bornes connues, fin postérieure à A,
# période inversée ou de longueur nulle (fin - début + 1 <= 0, D02a sous conserver) : prorata
# non déterminé, arrêt parametre_non_determine (lecture de Kleene, MA1) ; (4) prorata.
# Période couverte manquante (D03f, erratum v1.0.15) : `exclure` pour risque_en_cours : ligne
# hors du calcul (vue$exclu) ; hypothèse H (comptes_sociaux, poste P3 ou `tous`) appliquée à la
# ligne : les deux bornes sont celles de periode_cotisation_regle() (`donnees`), contrat sous
# hypothèse, restitué même quand la règle rend la cotisation échue (unité de montant nul, § 5.8,
# #92 mi1) ; valeur déclarée `regle` seule admise, contrôlée au plan par lire_declarations()
# (`donnees`, erratum v1.0.21, § 2.3, #99 ; une autre valeur ici est une erreur interne) ;
# règle non applicable (périodicité `unique` ou non lisible, mouvement manquant) : arrêt
# parametre_non_determine ; sans hypothèse (conserver) : lecture de Kleene stricte, arrêt
# parametre_non_determine ; sans hypothèse de P3 ou de `tous`, mais avec une hypothèse D03f de
# comptes_sociaux appliquée à la ligne pour un autre poste : refus de lecture R2
# (declaration_manquante, § 6.2, erratum v1.0.21, #108), différé : si aucun arrêt n'est né dans
# le champ, la plus petite cotisation en cause est rendue dans l'attribut `refus_d03f`, sans
# contrat, et calculer_risque_en_cours() lève le refus. Identifiant en cause d'un arrêt :
# plus petit contrat en cause (tri radix, indépendant de l'ordre des lignes de cotisations,
# § 6.2, « Identifiant publié », #176). Aucun NA n'entre dans une
# somme : une part NA résiduelle est une erreur interne. Rend un data.frame (id_contrat,
# montant), contrats triés, d'attributs
# `arret` (motif ou NA), `identifiant` (contrat en cause ou NA), `refus_d03f` (cotisation en
# cause d'un refus R2 en attente, ou NA), `colonne_d03f` (sa borne manquante, fin_periode si
# les deux manquent, ou NA) et `hypothese` (contrats du
# champ sous une valeur S1 ou S2 du § 5.8 : une cotisation lue sous l'hypothèse D03f, ou une
# hypothèse de la vue, D02b ou D03g, appliquée à la ligne de contrats du contrat ou à une de
# ses cotisations lues, #87). Sans point : lue par les tests du
# module (cas T7) et par calculer_risque_en_cours() ; non exportée.
provisions_collectives <- function(vue, plan) {
  vv <- function(t, c1) valeurs_vue(vue, t, c1)
  a <- as.numeric(vue$bilan$vue$date_arrete)
  exclu <- vue$exclu$risque_en_cours
  taux_c <- plan$frais$deces[[.POSTE_P3]][[.REFERENTIEL_P3]]$taux_chargement_cotisation
  resultat <- function(id_contrat, montant, arret = NA_character_, identifiant = NA_character_,
                       hypothese = character(0), refus_d03f = NA_character_, colonne_d03f = NA_character_) {
    structure(data.frame(id_contrat = id_contrat, montant = montant, stringsAsFactors = FALSE),
              arret = arret, identifiant = identifiant, hypothese = hypothese, refus_d03f = refus_d03f,
              colonne_d03f = colonne_d03f)
  }
  # garanties souscrites deces (.gs_deces_p3() : couverture exclue hors du champ, avant toute
  # lecture du contrat ; `gs_p3` : la sélection entière, lue par .population_p3())
  gs_p3 <- .gs_deces_p3(vue)
  gs <- gs_p3
  # contrats du champ (b) : population de P3 (.population_p3(), seule population, V2 (ii), #174),
  # appartenance non FALSE, champ (b) connu ; un contrat de champ non déterminé est une erreur
  # interne (sa nature refusée arrête le poste avant le calcul)
  pop <- .population_p3(vue, gs_p3, plan)
  .controler_population_p3(pop, "provisions_collectives")
  ct <- which(vue$retenu$contrats & !is.na(apparier_cles(vv("contrats", "id_contrat"),
                                                         vv("garanties_souscrites", "id_contrat")[gs])))
  ct <- ct[!is.na(apparier_cles(vv("contrats", "id_contrat")[ct],
                                pop$id_contrat[!(pop$appartenance %in% FALSE) & pop$individuel %in% FALSE]))]
  gs <- gs[!is.na(apparier_cles(vv("garanties_souscrites", "id_contrat")[gs], vv("contrats", "id_contrat")[ct]))]
  co <- which(vue$retenu$cotisations & !exclu$cotisations & vv("cotisations", "nature_mouvement") %in% .NATURES_PRORATA &
                !is.na(apparier_cles(vv("cotisations", "id_garantie_souscrite"),
                                     vv("garanties_souscrites", "id_garantie_souscrite")[gs])))
  i_gs <- apparier_cles(vv("cotisations", "id_garantie_souscrite")[co], vv("garanties_souscrites", "id_garantie_souscrite"))
  contrat <- as.character(vv("garanties_souscrites", "id_contrat"))[i_gs]
  debut <- as.numeric(vv("cotisations", "debut_periode"))[co]
  fin <- as.numeric(vv("cotisations", "fin_periode"))[co]
  # (1) fin_periode connue et au plus A : hors du calcul, avant toute hypothèse
  echue_connue <- !is.na(fin) & fin <= a
  # (2) période couverte manquante (D03f) : hypothèse H appliquée aux deux bornes, sinon Kleene
  manque <- (is.na(debut) | is.na(fin)) & !echue_connue
  # valeur de D03f par cotisation retenue (hypothese_vue() de `engagement`, seule sélection :
  # poste P3 de préférence à `tous`) ; NA sans hypothèse appliquée à la ligne
  h_d03f <- hypothese_vue(vue, "D03f", .REFERENTIEL_P3, "cotisations", co, .POSTE_P3)
  sous_h <- manque & !is.na(h_d03f)
  # sans hypothèse D03f de P3 ou de `tous`, avec une hypothèse D03f de comptes_sociaux appliquée à
  # la ligne pour un autre poste : ni règle ni lecture de Kleene ; refus de lecture R2
  # (declaration_manquante, § 5.5 et § 6.2, erratum v1.0.21, #108), différé après les arrêts
  autre_poste <- manque & is.na(h_d03f) &
    !is.na(hypothese_vue(vue, "D03f", .REFERENTIEL_P3, "cotisations", co, .POSTE_P3, autre_poste = TRUE))
  if (any(sous_h)) {
    regle <- periode_cotisation_regle(vv("cotisations", "date_mouvement")[co[sous_h]],
                                      vv("garanties_souscrites", "periodicite_cotisation")[i_gs[sous_h]])
    debut[sous_h] <- as.numeric(regle$debut)
    fin[sous_h] <- as.numeric(regle$fin)
  }
  inconnue <- (is.na(debut) | is.na(fin)) & !echue_connue & !autre_poste
  # (3) bornes connues, fin postérieure à A, période inversée ou de longueur nulle (D02a)
  inversee <- !inconnue & !autre_poste & !echue_connue & fin - debut + 1 <= 0
  non_determine <- inconnue | inversee
  if (any(non_determine)) {
    return(resultat(character(0), numeric(0), "parametre_non_determine", sort(contrat[non_determine], method = "radix")[1L]))
  }
  # refus R2 en attente (aucun arrêt du champ) : plus petite cotisation en cause (tri radix,
  # § 6.2, « Identifiant publié »), levé par calculer_risque_en_cours() ; aucun contrat valorisé.
  # Colonne publiée : la borne manquante de cette cotisation ; si les deux manquent,
  # fin_periode, borne qui fait naître le refus (une cotisation n'arrive ici que si sa fin
  # n'est pas connue au plus tard à A : § 5.5, ordre d'évaluation, puce (1) ; avis d'actuary)
  if (any(autre_poste)) {
    id_co <- as.character(vv("cotisations", "id_cotisation"))[co[autre_poste]]
    j <- which(autre_poste)[order(id_co, method = "radix")[1L]]
    colonne <- if (is.na(fin[j])) "fin_periode" else "debut_periode"
    return(resultat(character(0), numeric(0), refus_d03f = id_co[order(id_co, method = "radix")[1L]],
                    colonne_d03f = colonne))
  }
  # forme de D03f (`regle` seule) contrôlée au plan par lire_declarations() (`donnees`, erratum
  # v1.0.21, § 2.3, #99) : une autre valeur ici est une erreur interne
  if (!all(h_d03f[sous_h] == "regle")) {
    stop("erreur interne de provie : hypoth\u00e8se D03f de valeur autre que regle, hors de la forme contr\u00f4l\u00e9e ",
         "au plan (lire_declarations())", call. = FALSE)
  }
  # contrats sous une valeur S1 (D03f) ou S2 (hypothèse de la vue appliquée à la ligne de
  # contrats du contrat ou à une cotisation lue) du § 5.8 : ensemble du statut (#87, #92 mi1) ;
  # l'unité de montant nul n'en retient que les contrats à cotisation lue sous D03f (plus bas)
  # cotisations du champ visibles ou non (E17-3) : garantie souscrite deces d'un contrat du
  # champ ; une cotisation visible de nature hors du prorata ou de fin_periode connue au plus A
  # n'est pas lue (clés seules lisibles pour une cotisation cachée)
  # liste des lignes lues par unité de P3 (.lectures_contrats(), seule construction, celle de
  # l'arrêt par unité), lue entière aux contrats du champ (champ (b) connu : contrats, cotisations ;
  # garanties_souscrites et parametres, de champ s2 FALSE, non lues par S2)
  id_champ <- sort(unique(as.character(vv("contrats", "id_contrat"))[ct]), method = "radix")
  s2 <- hypotheses_vue_unites(vue, .REFERENTIEL_P3, .POSTE_P3, "risque_en_cours", length(pop$id_contrat),
                              .lectures_contrats(vue, pop, a, plan$postes$deces[[.POSTE_P3]]$individuel$methode))[
                                .unites_p3(pop, id_champ)]
  hypothese <- id_champ[nzchar(joindre_codes(c("", "D03f")[1L + !is.na(apparier_cles(id_champ, contrat[sous_h]))], s2))]
  # (4) prorata des cotisations de fin postérieure à A (bornes connues, ou par la règle H)
  garde <- fin > a
  part <- vv("cotisations", "montant")[co[garde]] * (1 - taux_c) *
    pmin(fin[garde] - a, fin[garde] - debut[garde] + 1) / (fin[garde] - debut[garde] + 1)
  contrat_g <- contrat[garde]
  if (anyNA(part) || anyNA(contrat_g)) {
    stop("erreur interne de provie : part NA dans provisions_collectives() (prorata_cotisation)", call. = FALSE)
  }
  # contrat dont une cotisation est lue sous D03f H (S1) sans cotisation de fin postérieure à A :
  # unité de montant nul (§ 5.8). Un contrat dont seule la ligne de `contrats` porte S2 (D03g sur
  # sa partie de fin) ne décide pas de sa sortie dans ce champ, qui ne lit pas cette partie : sans
  # cotisation de fin postérieure à A, il n'est pas restitué ; vivant, il garde le statut de
  # `hypothese`. Aucune hypothèse de la vue ne s'applique à une ligne de `cotisations` en B2
  # (D02b et D03g n'admettent pas cette table, defauts.csv, lignes 5 et 13) : la restitution
  # d'un contrat par S2 d'une cotisation n'est pas codée.
  ids <- sort(unique(c(contrat_g, intersect(hypothese, contrat[sous_h]))), method = "radix")
  if (length(ids) == 0L) return(resultat(character(0), numeric(0)))
  montant <- rep(0, length(ids))
  if (length(part)) {
    o <- order(contrat_g, part, method = "radix")
    s <- rowsum(part[o], contrat_g[o], reorder = TRUE)
    montant[match(rownames(s), ids)] <- unname(s[, 1L])
  }
  resultat(ids, montant, hypothese = hypothese)
}

# --- Point d'appel de la famille -----------------------------------------------------

# Point d'appel de P3 par l'orchestration (spécification de B2, § 5.1 et § 5.5) : mêmes
# arguments que engagement::calculer_engagement() (`tables` : mortalite_tarif si une méthode
# prospective est déclarée, serie_tme pour A132_1). Rend list(cellules, dossiers (vide : P3
# n'a pas de dossier), echeanciers (contrats individuels, cle = id_contrat, flux à l'arrêté au
# taux retenu, avant plancher ; contrat sorti restitué : deux lignes de flux 0, erratum
# v1.0.18), indicateurs (par contrat individuel valorisé : tarif_vie, taux
# retenu > taux du tarif, et deux lignes A132_1, à la date d'effet de la version de garantie
# et à l'arrêté ; puis une ligne hors_axes_derniere_valeur par contrat extrapolé, § 5.8),
# contrats (id_contrat, champ `individuel` ou `collectif`, montant après plancher,
# statut_resultat ; un contrat par champ, triés ; vide pour un poste arrêté : unités de la
# restitution par segment, #67)). Une seule cellule pour le poste (champs individuel et collectif réunis) :
# méthode « individuel:<méthode>;collectif:<méthode> », statut_methode `alternative` si l'une
# l'est, statut_resultat le plus faible des contrats (jugement_expert si D03h entre dans le
# montant, une hypothèse de la vue appliquée à une ligne lue, S2, #87, ou un point de
# mortalite_tarif lu hors des axes sous derniere_valeur, S3, #91 ; approximation_numerique pour
# un contrat collectif, jugement_expert sous l'hypothèse D03f ou une hypothèse de la vue),
# nombre_dossiers 0. Poste arrêté (bilan, ou hors_axes,
# parametre_non_determine, dont la période couverte non déterminée d'une cotisation du champ
# (b) ; ligne de portée ligne de refus_tables dont une ligne refusée est lue pour un contrat,
# arret_refus_ligne(), #72, lignes en cause dans l'attribut `refus_ligne`) : cellule `arrete`,
# contrat en cause dans l'attribut `identifiant_arret` (le plus petit, tri radix, indépendant de
# l'ordre des lignes, § 6.2, « Identifiant publié », #176). Refus
# de lecture R2 (declaration_manquante : D03h du champ (a), D03f du champ (b) ; § 6.2, erratum
# v1.0.21, #108) : levés seulement si aucun arrêt n'est né, les deux champs compris, le champ
# (a) avant le champ (b). Un montant NA dans le total est une erreur interne.
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
  pa_tout <- postes_a_arreter(catalogue, vue$bilan, plan$postes, parties_ligne())
  pa <- pa_tout$postes
  # population et lignes lues par unité, construites avant tout retour (.population_p3(),
  # .lectures_contrats() : seule construction de la famille, lue par l'arrêt par unité et par la
  # détection S2 des deux champs)
  pop <- .population_p3(vue, .gs_deces_p3(vue), plan)
  lect3 <- .lectures_contrats(vue, pop, as.numeric(vue$bilan$vue$date_arrete), m_ind)
  motif_bilan <- pa$motif_arret[pa$garantie == garantie & pa$poste == poste]
  if (length(motif_bilan) == 1L && !is.na(motif_bilan)) return(arreter(motif_bilan, NA_character_))
  # arrêt par les lignes de portée ligne de refus_tables (#72 ; arret_refus_ligne(), condition
  # (2)), avant toute lecture des valeurs des contrats. Unités : les contrats de la population
  # (.population_p3() : contrats retenus d'une garantie souscrite de la sélection, deces ou de code
  # refusé ; seuls ceux d'appartenance TRUE ou NA lisent des lignes ; lecture de Kleene : une
  # valeur refusée est inconnue et ne fait sortir aucun contrat) ; lignes lues du § 5.8, erratum
  # v1.0.23 : .lectures_contrats()
  ar <- arret_refus_ligne(vue, pa_tout, paste(garantie, poste, sep = "/"), "risque_en_cours", length(pop$id_contrat), lect3,
                          pop$id_contrat, unique(vapply(lect3, `[[`, "", "table")))
  if (length(ar$lignes)) {
    res <- arreter(ar$motif, ar$identifiant)
    attr(res$cellules, "refus_ligne") <- ar$lignes
    return(res)
  }
  ind <- provisions_individuelles(vue, plan, tables, FALSE)
  if (!is.na(ind$arret)) return(arreter(ind$arret, ind$identifiant))
  col <- provisions_collectives(vue, plan)
  if (!is.na(attr(col, "arret"))) return(arreter(attr(col, "arret"), attr(col, "identifiant")))
  # refus de lecture R2 (spécification de B2, § 6.2, erratum v1.0.21, #108), levés une fois tous
  # les arrêts du poste écartés, les deux champs compris ; champ (a) avant champ (b)
  if (!is.na(ind$refus_d03h)) {
    refuser(paste0("risque_en_cours : taux du tarif manquant pour la garantie souscrite ", ind$refus_d03h,
                   " sans hypoth\u00e8se D03h d\u00e9clar\u00e9e (comptes_sociaux)"),
            "declaration_manquante", module = "risque_en_cours", table = "garanties_souscrites",
            colonne = "taux_technique_tarif", identifiants = ind$refus_d03h)
  }
  if (!is.na(attr(col, "refus_d03f"))) {
    refuser(paste0("risque_en_cours : p\u00e9riode couverte manquante de la cotisation ", attr(col, "refus_d03f"),
                   " sans hypoth\u00e8se D03f d\u00e9clar\u00e9e pour ", poste, " ou tous (comptes_sociaux), ",
                   "hypoth\u00e8se d\u00e9clar\u00e9e pour un autre poste seulement"),
            "declaration_manquante", module = "risque_en_cours", table = "cotisations",
            colonne = attr(col, "colonne_d03f"), identifiants = attr(col, "refus_d03f"))
  }
  ct <- ind$contrats
  # statut d'un contrat collectif : jugement_expert sous une valeur S1 (D03f, erratum v1.0.15) ou
  # S2 (hypothèse de la vue, #87) du § 5.8 (codes réunis par joindre_codes() dans
  # provisions_collectives())
  statut_col <- ifelse(!is.na(apparier_cles(col$id_contrat, attr(col, "hypothese"))), "jugement_expert", "approximation_numerique")
  # statut d'un contrat individuel (règle unique du § 5.8, erratum v1.0.16) : jugement_expert si
  # une valeur fournie par le plan entre dans son montant, hypothèse D03h (S1), hypothèse de la
  # vue (S2, #87 ; codes réunis par joindre_codes()) ou point de mortalite_tarif lu hors des axes
  # sous derniere_valeur (S3, #91)
  statut_ind <- if (!is.null(ct)) {
    ifelse(nzchar(joindre_codes(c("", "D03h")[1L + ct$hypothese_d03h], ct$hypotheses_vue)) | ct$extrapole,
           "jugement_expert", "exact")
  }
  # contrats individuels sortis par un sinistre sous une hypothèse de la vue (S2) : unités à 0
  sortis <- ind$sortis
  statuts <- c(statut_ind, rep("jugement_expert", length(sortis)), statut_col)
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
  # contrat sorti restitué : deux lignes (capital_unique, frais) de flux 0, probabilité 1, au
  # lendemain de l'arrêté, valeur nominale (§ 5.3 ; erratum v1.0.18, réserve R2), après les
  # lignes des contrats valorisés
  if (length(sortis)) {
    n_s <- length(sortis)
    e0 <- valeur_actuelle_probable(data.frame(cle = rep(sortis, each = 2L),
                                              date = structure(rep(as.numeric(vue$bilan$vue$date_arrete) + 1, 2L * n_s),
                                                               class = "Date"),
                                              etat = "actif", type_flux = rep(c("capital_unique", "frais"), n_s),
                                              flux = 0, probabilite = 1, stringsAsFactors = FALSE),
                                   list(type = "aucune"), plan$conventions)$echeancier
    e0 <- data.frame(cle = e0$cle, referentiel = rep(.REFERENTIEL_P3, nrow(e0)), poste = rep(poste, nrow(e0)),
                     date = e0$date, etat = e0$etat, type_flux = e0$type_flux, flux = e0$flux,
                     probabilite = e0$probabilite, actualisation = e0$actualisation,
                     valeur_actuelle = e0$valeur_actuelle, stringsAsFactors = FALSE)
    echeanciers <- rbind(echeanciers, e0[COLONNES_ECHEANCIERS])
    rownames(echeanciers) <- NULL
  }
  # contrats valorisés, par champ (restitution par segment, #67) : montant après plancher
  contrats <- rbind(contrats_vides,
                    if (!is.null(ct)) data.frame(id_contrat = ct$id_contrat, champ = rep("individuel", nrow(ct)),
                                                 montant = ct$montant,
                                                 statut_resultat = statut_ind,
                                                 stringsAsFactors = FALSE),
                    if (length(sortis)) data.frame(id_contrat = sortis, champ = rep("individuel", length(sortis)),
                                                   montant = rep(0, length(sortis)),
                                                   statut_resultat = rep("jugement_expert", length(sortis)),
                                                   stringsAsFactors = FALSE),
                    if (nrow(col)) data.frame(id_contrat = col$id_contrat, champ = rep("collectif", nrow(col)),
                                              montant = col$montant, statut_resultat = statut_col,
                                              stringsAsFactors = FALSE))
  contrats <- contrats[order(contrats$id_contrat, contrats$champ, method = "radix"), , drop = FALSE]
  rownames(contrats) <- NULL
  list(cellules = cellule(total, statut_le_plus_faible(statuts), NA_character_), dossiers = dossiers, echeanciers = echeanciers,
       indicateurs = indicateurs, contrats = contrats)
}
