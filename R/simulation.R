# Module `simulation` (ADR 0010, points 1, 19 et 21 ; ADR 0008, points 3 à 6) : simulateur de
# la base brute fictive, hors de la chaîne du moteur (aucun module du moteur ne l'appelle).
# Rend un objet en mémoire (`jeu_simule`) et n'écrit aucun fichier : l'écriture et la relecture
# d'un jeu sont dans le module `lecture` (ecrire_jeu(), lire_jeu()).
# N'appelle que les modules `dictionnaire` et `outils` (M160 : les arêtes vers `garanties` et
# `tables` du point 1 restent permises, non employées en Bd) : les tables de vérité passent par
# valeurs dans la loi vraie, et la configuration des garanties liées est un paramètre du
# portefeuille de la loi vraie (aucun catalogue de garanties ici). Ne parle pas (point 12).
# Code ASCII hors commentaires (M112) : les accents des chaînes s'écrivent en \uXXXX.
# Convention de ce fichier : une fonction dont le nom commence par un point est un
# auxiliaire du module ; la concordance documentation <-> code ne recense que les autres.
#
# Tirage (point 19) : le jeu propre est tiré en flux séparés, un par graine (`population`,
# `famille`, `sinistres`, `information`), chacun en un seul appel d'avec_graine() (seule voie
# vers l'aléa, point 21), dans cet ordre ; chaque flux tire des matrices d'uniformes de taille
# fixe par unité (contrat, assuré, arrêt, sinistre), transformées ensuite par inversion, de
# sorte que le tirage d'une unité ne dépend pas de ce qui arrive aux autres. Le flux
# `information` (délais de déclaration, de saisie, d'instruction et de règlement) ne change
# aucun tirage des flux qui le précèdent. Puis chaque défaut du catalogue DEFAUTS_SIMULES est
# injecté sous la graine `defauts + rang` (rang fixe dans le catalogue, non dans la liste des
# défauts actifs) : ses lignes éligibles et ses tirages ne lisent que le jeu propre, et deux
# défauts d'une même table touchent des colonnes distinctes ou des lignes éligibles
# disjointes ; activer ou désactiver un défaut ne change donc ni le jeu propre ni les autres
# défauts (E4.9).
# Format de loi vraie version 2 (spécification de B2, § 7.9.2 ; #69), additif : la version 1
# reste lue, sortie inchangée ; la version 2 ajoute deux flux, chacun sous sa graine et en un
# seul appel d'avec_graine(), tirés après `information` et avant les défauts : `individuels`
# (temporaires décès individuelles : souscription, tarif, résiliation, décès, délais
# d'information ; uniformes de taille fixe par contrat) et `suites_deces` (capitaux non
# réclamés et fixations différées ; trois uniformes par décès, collectif puis individuel,
# dans l'ordre d'assemblage), plus la majoration du conjoint et les périodes de cotisation à
# l'anniversaire du contrat collectif.
#
# Modèle (jugement d'expert déclaré dans la loi vraie, jamais une valeur par défaut) :
# assurés affiliés à des contrats collectifs obligatoires qui portent trois garanties liées
# (décès, incapacité, invalidité ; dictionnaire, § 3, T4) ; en activité, décès et arrêt de
# travail en risques concurrents, par pas de 30 jours, sous des taux annuels par âge ; un
# arrêt suit un modèle mensuel par ancienneté (reprise, décès, passage en invalidité), passe
# en invalidité ou s'éteint par fin de droits au terme de la durée maximale d'indemnisation,
# et prend fin à l'âge de fin de service ; l'invalidité suit des taux mensuels constants
# (reprise, décès) ; le décès d'un assuré en activité, en arrêt ou en invalidité ouvre un
# sinistre décès (maintien de la garantie décès pendant l'arrêt) ; un arrêt peut être classé
# sans suite.

# --- Constantes ------------------------------------------------------------------

# Flux du jeu propre, dans leur ordre de tirage, et graine des défauts (point 19) : noms
# exacts de l'argument `graines` de simuler_base().
FLUX_SIMULATION <- c("population", "famille", "sinistres", "information")
GRAINES_SIMULATION <- c(FLUX_SIMULATION, "defauts")
# Flux ajoutés par le format de loi vraie version 2, tirés après FLUX_SIMULATION, et noms
# exacts de l'argument `graines` pour une loi de version 2, dans l'ordre des tirages.
FLUX_SIMULATION_V2 <- c("individuels", "suites_deces")
GRAINES_SIMULATION_V2 <- c(FLUX_SIMULATION, FLUX_SIMULATION_V2, "defauts")

# Version courante du format de la loi vraie lue par simuler_base() (`loi_vraie$version`) ; la
# version 1 reste lue, sortie inchangée (spécification de B2, § 7.9.2).
VERSION_LOI_VRAIE <- 2L

# Version du simulateur, consignée au manifeste (ADR 0010, onzième série, (c)) et soumise au
# test d'identité des jeux versionnés. Règle d'incrément : toute modification de ce module qui
# change la sortie de simuler_base() pour une entrée admise, fût-ce sur un seul jeu, incrémente
# VERSION_SIMULATEUR, et son commit est un changement de résultat sur les jeux (tableau avant /
# après des volumétries et du registre) ; un refactorage sans effet garde la version. Un jeu
# d'une version antérieure est retiré par un commit donnees: et remplacé par un jeu <nn+1>
# (M189). La version garantit la sortie pour les jeux versionnés et pour toute entrée admise par
# la version courante. Exception délibérée à la règle d'incrément (M190) : les corrections de la
# revue finale ont refusé des entrées autrefois admises par les contrôles d'entrée, et la
# restriction de D01b aux encaissements antérieurs à l'extraction change la sortie des entrées
# encore admises dont un encaissement est daté de l'extraction ; elles sont admises sans
# incrément, aucun jeu n'ayant été publié hors de la branche et les jeux versionnés étant
# inchangés (décision du mainteneur, 9 novembre 2026).
VERSION_SIMULATEUR <- 1L

# Catalogue des défauts que le simulateur sait injecter (dictionnaire, § 9), dans l'ordre de
# leur rang : la graine d'un défaut est `graines$defauts + rang`. `parametre` : intensité
# `loi_vraie$defauts$<parametre>` (probabilité d'injection par ligne éligible, dans [0 ; 1],
# sans valeur par défaut) ; `table` : table touchée ; `eligibles` : lignes du jeu propre sur
# lesquelles le défaut peut être injecté. Les défauts du § 9 absents de ce catalogue ne sont
# pas simulés en Bd (#19) : leur paramètre est refusé dans la loi vraie.
# Sémantique des clés `defauts` du format de loi vraie version 1 (figée : les jeux versionnés en
# dépendent ; ajouter un sous-cas demande VERSION_LOI_VRAIE 2, la version 1 restant lue, réserve
# R2 d'actuary) -- seuls les sous-cas suivants sont simulés :
#   doublon_contenu : D01b sur les encaissements de cotisations seuls ;
#   date_ordre : D02a, début et fin de période permutés sur les indemnités journalières seules
#     (sans le sous-paramètre date_annee_erronee) ;
#   saisie_anterieure : D02b sur evenements seuls (types non programmables) ;
#   manquant_date_naissance, manquant_sexe : D03a, D03b sur assures seuls ;
#   manquant_salaire : D03c ; manquant_date_saisie : D03g sur prestations seules ;
#   orpheline : D04b sur les émissions de cotisations seules ;
#   clos_sans_motif : D05 sur les sorties sans suite ;
#   cloture_sans_justificatif : D06 sur les sorties (reprise du travail, décès) seules, sans les
#     sous-paramètres cloture_erronee et cloture_sans_prestation ;
#   montant_aberrant : D09, signe inversé seul (sans facteur ni capital incohérent) ;
#   instruction_absente : D13, date d'instruction seule effacée (famille et dossiers liés
#     conservés).
DEFAUTS_SIMULES <- data.frame(
  rang = 1:12,
  code = c("D01b", "D02a", "D02b", "D03a", "D03b", "D03c", "D03g", "D04b", "D05", "D06", "D09", "D13"),
  parametre = c("doublon_contenu", "date_ordre", "saisie_anterieure", "manquant_date_naissance", "manquant_sexe",
                "manquant_salaire", "manquant_date_saisie", "orpheline", "clos_sans_motif",
                "cloture_sans_justificatif", "montant_aberrant", "instruction_absente"),
  table = c("cotisations", "prestations", "evenements", "assures", "assures", "affiliations", "prestations",
            "cotisations", "evenements", "evenements", "prestations", "sinistres"),
  eligibles = c(
    "encaissements ant\u00e9rieurs \u00e0 l'extraction (copie sous un nouvel identifiant, mouvement dat\u00e9 apr\u00e8s l'original, au plus \u00e0 l'extraction)",
    "indemnit\u00e9s journali\u00e8res \u00e0 p\u00e9riode non r\u00e9duite \u00e0 un jour (d\u00e9but et fin permut\u00e9s)",
    "\u00e9v\u00e9nements d'un type non programmable (saisie avant la date d'effet)",
    "assur\u00e9s (date de naissance effac\u00e9e)",
    "assur\u00e9s (sexe effac\u00e9)",
    "affiliations (salaire de r\u00e9f\u00e9rence effac\u00e9)",
    "prestations (date de saisie effac\u00e9e)",
    "\u00e9missions (garantie souscrite remplac\u00e9e par un identifiant inconnu)",
    "sorties sans suite (motif effac\u00e9)",
    "sorties pour reprise du travail ou d\u00e9c\u00e8s (justificatif effac\u00e9)",
    "paiements (montant de signe invers\u00e9 ; seul sous-cas de D09 simul\u00e9)",
    "sinistres d\u00e9c\u00e8s dont le capital est r\u00e9gl\u00e9 (instruction effac\u00e9e)"),
  stringsAsFactors = FALSE)

# Colonnes du registre des défauts (point 19), dans cet ordre ; `rang` entier, les autres en
# texte (valeurs en écriture canonique d'ecrire_valeurs(), NA pour une valeur manquante ;
# ligne ajoutée : colonne et valeur propre NA, valeur injectée = identifiant de l'original).
COLONNES_REGISTRE <- c("code", "parametre", "rang", "table", "cle", "colonne", "valeur_propre", "valeur_injectee")

# Schéma de la vérité (ADR 0010, point 19 ; onzième série, (b)) : seule définition des tables de
# `verite`, de leurs colonnes et de leurs types (types du dictionnaire) ; simuler_base() en
# dérive manifeste$colonnes_verite, que lire_jeu() relit.
#   flux_futurs : prestations réglées après l'extraction ; date_survenance du sinistre (un décès
#     survenu après l'extraction, en arrêt ou en invalidité, maintien de la garantie décès, s'y
#     distingue par date_survenance > date d'extraction ; ses flux sont ceux d'un sinistre futur,
#     non d'un sinistre survenu) ; id_sinistre_origine : NA pour un flux d'un sinistre survenu au
#     plus tard à l'extraction, identifiant de l'arrêt de travail d'origine pour un décès survenu
#     après (réserve R4 d'actuary : valorisation dossier par dossier du maintien de la garantie
#     décès) ; sinistre_connu : sinistre saisi au plus tard à l'extraction ;
#   etats_vrais : trajectoire vraie de chaque arrêt de travail (états et dates) ;
#   familles_vraies : conjoints vrais ; id_membre si le conjoint est connu de la base ;
#   sinistres_non_declares : sinistres survenus au plus tard à l'extraction, saisis après ;
#   defauts : registre des défauts injectés (COLONNES_REGISTRE).
SCHEMA_VERITE <- list(
  flux_futurs = c(id_sinistre = "character", date_survenance = "Date", id_dossier = "character",
                  code_garantie = "character", type_prestation = "character", date_reglement = "Date",
                  debut_periode = "Date", fin_periode = "Date", montant = "numeric",
                  id_sinistre_origine = "character", sinistre_connu = "logical"),
  etats_vrais = c(id_sinistre = "character", etat = "character", categorie_invalidite = "character",
                  date_debut = "Date", date_fin = "Date"),
  familles_vraies = c(id_assure = "character", lien = "character", sexe = "character", date_naissance = "Date",
                      id_membre = "character"),
  sinistres_non_declares = c(id_sinistre = "character", id_assure = "character", nature_sinistre = "character",
                             date_survenance = "Date", date_declaration = "Date", date_saisie = "Date"),
  defauts = stats::setNames(ifelse(COLONNES_REGISTRE == "rang", "integer", "character"), COLONNES_REGISTRE))

# Identifiant de garantie souscrite inconnu, injecté par D04b (orpheline).
.ID_ORPHELIN <- "GS999"

# Âge le plus élevé lu par le simulateur (au-delà, le taux de la dernière ligne d'une table).
.AGE_LIMITE_SIMULATION <- 120L

# Pas du modèle (jours) et longueur d'un an (jours) pour les taux annuels.
.PAS_JOURS <- 30
.AN_JOURS <- 365.25

# --- Point d'entrée ----------------------------------------------------------------

# Tire une base brute fictive sous la loi vraie `loi_vraie` (liste nommée sérialisable par
# ecrire_liste(), version 1 ou VERSION_LOI_VRAIE ; forme décrite par .controler_loi_vraie()),
# avec les graines `graines` (liste nommée d'entiers, noms GRAINES_SIMULATION pour une loi de
# version 1, GRAINES_SIMULATION_V2 pour une loi de version 2), à la date
# d'extraction `date_extraction` (Date de longueur 1). `nom` (`<jalon>-<volumetrie>-<nn>`) et
# `description` (chaîne) vont au manifeste ; `date_visa` (Date, NA tant que le jeu n'est pas
# visé) aussi. `declarations` : liste nommée `declarations` et `conventions` (arguments de
# controler_base() qui conviennent au jeu), versionnée avec le jeu, ou NULL ; le simulateur la
# porte telle quelle, sans la lire.
# Rend un objet de classe `jeu_simule`, liste nommée :
#   base : liste nommée de data.frame, les tables obligatoires du dictionnaire dans son ordre,
#     colonnes dans l'ordre du dictionnaire (forme que rend lire_base()), les lignes saisies
#     au plus tard à la date d'extraction ;
#   loi_vraie : l'argument, inchangé ;
#   verite : liste nommée de data.frame, ce que l'organisme ignore -- flux_futurs,
#     etats_vrais, familles_vraies, sinistres_non_declares, defauts (registre,
#     COLONNES_REGISTRE) ;
#   manifeste : liste nommée, dans cet ordre (ADR 0010, onzième série, (c)) : nom,
#     version_dictionnaire, version_provie (version qui a produit le jeu, hors du test
#     d'identité), version_simulateur (VERSION_SIMULATEUR), graines, date_extraction,
#     volumetrie par table, description, date_visa, colonnes_verite (SCHEMA_VERITE, lu par
#     lire_jeu()) ;
#   declarations : l'argument (absent si NULL).
# Refus d'appel (jeu_invalide) : argument mal formé ou incomplet, loi vraie d'une autre
# version, clé inconnue de la loi vraie, valeur hors de son domaine (probabilité hors de
# [0 ; 1], taux, cadence ou âge négatif, nombre de contrats ou d'assurés par contrat inférieur
# à 1, âge d'entrée minimal supérieur au maximal ou maximal non inférieur à l'âge de retraite,
# arrondi du salaire nul, valeur non finie), paramètre de défaut inconnu ou hors de [0 ; 1],
# date d'extraction non entière ou non finie, antérieure ou égale au début de l'historique ou
# antérieure à l'effet du dernier contrat possible, horizon d'invalidité plus long que les
# uniformes tirées (.taille_invalidite()) ; en version 2, dernière souscription individuelle
# postérieure à l'extraction ou antérieure au début de l'historique, premier palier du taux
# du tarif postérieur à l'année du début de l'historique.
simuler_base <- function(loi_vraie, graines, date_extraction, nom, description, declarations = NULL,
                         date_visa = NULL) {
  if (missing(loi_vraie) || missing(graines) || missing(date_extraction) || missing(nom) || missing(description)) {
    .refus_simulation("simuler_base() : loi_vraie, graines, date_extraction, nom et description sont obligatoires")
  }
  .controler_loi_vraie(loi_vraie)
  v2 <- identical(loi_vraie$version, 2L)
  graines <- .controler_graines(graines, if (v2) GRAINES_SIMULATION_V2 else GRAINES_SIMULATION)
  if (!identical(class(date_extraction), "Date") || length(date_extraction) != 1L || !is.finite(date_extraction) ||
      as.numeric(date_extraction) != floor(as.numeric(date_extraction))) {
    .refus_simulation(paste0("simuler_base() : `date_extraction` doit \u00eatre une Date renseign\u00e9e de longueur 1, ",
                             "enti\u00e8re et finie"))
  }
  if (!.chaine(nom) || !grepl("^[a-z0-9]+-[a-z0-9]+-[0-9]{2}$", nom)) {
    .refus_simulation("simuler_base() : `nom` doit suivre la forme <jalon>-<volumetrie>-<nn> (ADR 0010, point 20)")
  }
  if (!.chaine(description)) .refus_simulation("simuler_base() : `description` doit \u00eatre une cha\u00eene renseign\u00e9e")
  if (is.null(date_visa)) date_visa <- structure(NA_real_, class = "Date")
  if (!identical(class(date_visa), "Date") || length(date_visa) != 1L) {
    .refus_simulation("simuler_base() : `date_visa` doit \u00eatre une Date de longueur 1 (NA tant que le jeu n'est pas vis\u00e9)")
  }
  if (!is.null(declarations) && (!is.list(declarations) || is.data.frame(declarations) || length(declarations) == 0L ||
                                 is.null(names(declarations)) || anyNA(names(declarations)) ||
                                 anyDuplicated(names(declarations)) ||
                                 !all(names(declarations) %in% c("declarations", "conventions")))) {
    .refus_simulation(paste0("simuler_base() : `declarations` doit \u00eatre NULL ou une liste nomm\u00e9e d'entr\u00e9es ",
                             "declarations et conventions (au plus une de chaque)"))
  }
  ext <- as.numeric(date_extraction)
  if (ext <= as.numeric(loi_vraie$portefeuille$debut_historique)) {
    .refus_simulation("simuler_base() : date d'extraction ant\u00e9rieure ou \u00e9gale au d\u00e9but de l'historique")
  }
  # Effet du dernier contrat possible (dernier décalage tiré) au plus tard à l'extraction :
  # sinon un contrat, ses affiliations et ses entrées seraient datés après l'extraction (revue
  # finale, C6). Précondition contrôlée plutôt que borne de l'effet : les tirages des jeux
  # admis ne changent pas.
  p <- loi_vraie$portefeuille
  if (.debut_mois(as.numeric(p$debut_historique), p$decalage_effet_mois_max) > ext) {
    .refus_simulation(paste0("simuler_base() : effet de contrat possible apr\u00e8s l'extraction (d\u00e9but de ",
                             "l'historique d\u00e9cal\u00e9 de decalage_effet_mois_max mois post\u00e9rieur \u00e0 la date ",
                             "d'extraction)"))
  }
  # Préconditions des contrats individuels (version 2) : effets de debut_historique à
  # derniere_souscription, au plus tard à l'extraction ; un palier de taux du tarif pour
  # l'année de chaque effet possible.
  if (v2) {
    x <- loi_vraie$individuels
    if (as.numeric(x$derniere_souscription) > ext) {
      .refus_simulation("simuler_base() : loi vraie, `individuels/derniere_souscription` post\u00e9rieure \u00e0 l'extraction")
    }
    if (x$taux_tarif$annee[1L] > as.POSIXlt(p$debut_historique)$year + 1900L) {
      .refus_simulation(paste0("simuler_base() : loi vraie, `individuels/taux_tarif/annee` : premier palier ",
                               "post\u00e9rieur \u00e0 l'ann\u00e9e du d\u00e9but de l'historique"))
    }
  }
  dico <- dictionnaire()

  pop <- avec_graine(graines$population, .tirer_population(loi_vraie, ext))
  fam <- avec_graine(graines$famille, .tirer_familles(loi_vraie, pop))
  sin <- avec_graine(graines$sinistres, .tirer_sinistres(loi_vraie, pop, ext))
  inf <- avec_graine(graines$information, .tirer_information(loi_vraie, pop, sin))
  ind <- NULL
  suites <- NULL
  if (v2) {
    ind <- avec_graine(graines$individuels, .tirer_individuels(loi_vraie, ext))
    n_deces <- length(sin$deces) + sum(!is.na(ind$deces))
    suites <- avec_graine(graines$suites_deces, matrix(runif(n_deces * 3L), nrow = n_deces, ncol = 3L, byrow = TRUE))
  }
  propre <- .assembler_jeu(loi_vraie, pop, fam, sin, inf, ext, dico, ind, suites)
  injection <- .injecter_defauts(propre$base, loi_vraie$defauts, graines$defauts, ext, dico$types_evenements)

  verite <- propre$verite
  verite$defauts <- injection$registre
  conforme <- identical(names(verite), names(SCHEMA_VERITE)) &&
    all(vapply(names(SCHEMA_VERITE), function(t) {
      identical(vapply(verite[[t]], .type_colonne, ""), SCHEMA_VERITE[[t]])
    }, NA))
  if (!conforme) stop("simulation : tables de v\u00e9rit\u00e9 non conformes \u00e0 SCHEMA_VERITE", call. = FALSE)
  base <- injection$base
  manifeste <- list(
    nom = nom,
    version_dictionnaire = dico$version,
    version_provie = as.character(utils::packageVersion("provie")),
    version_simulateur = VERSION_SIMULATEUR,
    graines = graines,
    date_extraction = date_extraction,
    volumetrie = lapply(base, nrow),
    description = description,
    date_visa = date_visa,
    colonnes_verite = lapply(SCHEMA_VERITE, as.list))
  jeu <- list(base = base, loi_vraie = loi_vraie, verite = verite, manifeste = manifeste)
  if (!is.null(declarations)) jeu$declarations <- declarations
  structure(jeu, class = "jeu_simule")
}

# --- Affichage (ADR 0010, point 13 ; onzième série, (h)) ---------------------------------

# Décrit un jeu simulé en lignes de texte, par des décomptes seuls (aucune somme) : nom, date
# d'extraction, versions du dictionnaire et du simulateur, date de visa, nombre de lignes de
# chaque table de la base, lignes du registre des défauts par code, présence de déclarations.
format.jeu_simule <- function(x, ...) {
  m <- x$manifeste
  reg <- x$verite$defauts
  par_code <- if (nrow(reg) == 0L) "aucun" else {
    n <- table(factor(reg$code, levels = unique(reg$code)))
    paste(paste0(names(n), " ", as.integer(n)), collapse = ", ")
  }
  c(paste0("jeu simul\u00e9 ", m$nom, " (extraction du ", format(m$date_extraction), ")"),
    paste0("  dictionnaire ", m$version_dictionnaire, ", simulateur ", m$version_simulateur, ", provie ",
           m$version_provie, ", visa ", if (is.na(m$date_visa)) "non renseign\u00e9" else format(m$date_visa)),
    paste0("  base : ", paste(paste0(names(x$base), " ", vapply(x$base, nrow, 0L)), collapse = ", ")),
    paste0("  registre des d\u00e9fauts : ", nrow(reg), " ligne(s) ; par code : ", par_code),
    paste0("  d\u00e9clarations : ", if (is.null(x$declarations)) "aucune" else paste(names(x$declarations), collapse = ", ")))
}

# Imprime format(x) et rend `x`, invisible.
print.jeu_simule <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

# --- Contrôle des entrées ------------------------------------------------------------

.refus_simulation <- function(message, ...) refuser(message, "jeu_invalide", module = "simulation", ...)

.chaine <- function(x) is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)

# Type du dictionnaire d'une colonne (character, integer, numeric, Date, logical).
.type_colonne <- function(x) {
  if (inherits(x, "Date")) "Date" else if (is.character(x)) "character" else if (is.integer(x)) "integer"
  else if (is.logical(x)) "logical" else "numeric"
}

# `noms` : noms exacts des graines selon la version de la loi vraie (GRAINES_SIMULATION ou
# GRAINES_SIMULATION_V2) ; rend les graines dans cet ordre.
.controler_graines <- function(graines, noms) {
  if (!is.list(graines) || is.data.frame(graines) || !setequal(names(graines), noms) ||
      length(graines) != length(noms) ||
      !all(vapply(graines, function(g) is.integer(g) && length(g) == 1L && !is.na(g), NA))) {
    .refus_simulation(paste0("simuler_base() : `graines` doit \u00eatre une liste nomm\u00e9e d'entiers renseign\u00e9s (",
                             paste(noms, collapse = ", "), ")"))
  }
  if (any(vapply(graines, function(g) abs(as.numeric(g)) > .Machine$integer.max - nrow(DEFAUTS_SIMULES), NA))) {
    .refus_simulation("simuler_base() : graine trop grande (graine des d\u00e9fauts + rang hors des entiers)")
  }
  graines[noms]
}

# Forme attendue de la loi vraie : chemins, type et longueur de chaque feuille (longueur NA :
# vecteur non vide quelconque). Toute feuille lue par le simulateur y figure ; aucune n'a de
# valeur par défaut.
.SCHEMA_LOI_VRAIE <- list(
  c("version", "integer", 1), c("description", "character", 1), c("statut", "character", 1),
  c("portefeuille/type_organisme", "character", 1), c("portefeuille/debut_historique", "Date", 1),
  c("portefeuille/nombre_contrats", "integer", 1), c("portefeuille/assures_par_contrat", "integer", 1),
  c("portefeuille/decalage_effet_mois_max", "integer", 1), c("portefeuille/part_affilies_effet", "double", 1),
  c("portefeuille/age_entree_min", "double", 1), c("portefeuille/age_entree_max", "double", 1),
  c("portefeuille/part_femmes", "double", 1), c("portefeuille/salaire_log_moyenne", "double", 1),
  c("portefeuille/salaire_log_ecart", "double", 1), c("portefeuille/salaire_arrondi", "double", 1),
  c("portefeuille/taux_depart", "double", 1), c("portefeuille/age_retraite", "integer", 1),
  c("portefeuille/part_conjoint", "double", 1), c("portefeuille/ecart_age_conjoint_max", "double", 1),
  c("portefeuille/delai_minimal_rearret_jours", "integer", 1), c("portefeuille/arrets_max_par_assure", "integer", 1),
  c("garanties/college", "character", 1), c("garanties/periodicite_cotisation", "character", 1),
  c("garanties/deces/taux_capital", "double", 1), c("garanties/deces/age_fin_garantie", "double", 1),
  c("garanties/deces/taux_cotisation", "double", 1), c("garanties/deces/option_iad", "logical", 1),
  c("garanties/deces/clause_type_beneficiaire", "character", 1),
  c("garanties/incapacite/franchise_jours", "double", 1), c("garanties/incapacite/taux_indemnite", "double", 1),
  c("garanties/incapacite/duree_max_jours", "double", 1), c("garanties/incapacite/delai_rechute_jours", "double", 1),
  c("garanties/incapacite/age_fin_service", "double", 1), c("garanties/incapacite/taux_cotisation", "double", 1),
  c("garanties/incapacite/type_franchise", "character", 1), c("garanties/incapacite/regle_complement", "character", 1),
  c("garanties/incapacite/periodicite_prestation", "character", 1),
  c("garanties/incapacite/terme_prestation", "character", 1),
  c("garanties/invalidite/taux_rente/cat1", "double", 1), c("garanties/invalidite/taux_rente/cat2", "double", 1),
  c("garanties/invalidite/taux_rente/cat3", "double", 1), c("garanties/invalidite/age_fin_service", "double", 1),
  c("garanties/invalidite/taux_cotisation", "double", 1), c("garanties/invalidite/regle_complement", "character", 1),
  c("garanties/invalidite/periodicite_prestation", "character", 1),
  c("garanties/invalidite/terme_prestation", "character", 1),
  c("tables/mortalite/age", "integer", NA), c("tables/mortalite/qx_femmes", "double", NA),
  c("tables/mortalite/qx_hommes", "double", NA),
  c("tables/incidence_arret/age", "integer", NA), c("tables/incidence_arret/taux", "double", NA),
  c("tables/maintien_incapacite/mois", "integer", NA), c("tables/maintien_incapacite/reprise", "double", NA),
  c("tables/maintien_incapacite/deces", "double", NA), c("tables/maintien_incapacite/passage", "double", NA),
  c("tables/maintien_incapacite/passage_au_terme", "double", 1),
  c("tables/invalidite/reprise_mensuelle", "double", 1), c("tables/invalidite/deces_mensuel", "double", 1),
  c("tables/categories/cat1", "double", 1), c("tables/categories/cat2", "double", 1),
  c("tables/categories/cat3", "double", 1),
  c("tables/sans_suite/part", "double", 1), c("tables/sans_suite/duree_min_jours", "double", 1),
  c("tables/sans_suite/duree_max_jours", "double", 1),
  c("cadences/declaration_deces", "double", 1), c("cadences/declaration_arret", "double", 1),
  c("cadences/saisie_sinistre", "double", 1), c("cadences/instruction", "double", 1),
  c("cadences/ouverture_dossier", "double", 1), c("cadences/saisie_evenement", "double", 1),
  c("cadences/saisie_famille", "double", 1), c("cadences/reglement_capital", "double", 1),
  c("cadences/reglement_prestation", "double", 1), c("cadences/saisie_affiliation", "double", 1),
  c("cadences/saisie_radiation", "double", 1), c("cadences/emission_cotisation", "double", 1),
  c("cadences/encaissement_cotisation", "double", 1))

# Feuilles ajoutées par le format version 2 (spécification de B2, § 7.9.3), toutes
# obligatoires en version 2 et refusées en version 1 (clé inconnue) ; même forme que
# .SCHEMA_LOI_VRAIE. Sémantique : garanties/periode_cotisation (`civile`, comportement de la
# version 1, ou `anniversaire` : périodes annuelles commençant à l'effet du contrat collectif) ;
# garanties/deces/majoration_conjoint (fraction du salaire ajoutée au taux du capital si
# l'assuré a un conjoint) ; individuels/* (temporaires décès individuelles, .tirer_individuels())
# ; suites_deces/* (capitaux non réclamés et fixations différées, .assembler_jeu()).
.SCHEMA_LOI_VRAIE_V2 <- list(
  c("garanties/periode_cotisation", "character", 1), c("garanties/deces/majoration_conjoint", "double", 1),
  c("individuels/nombre_contrats", "integer", 1), c("individuels/derniere_souscription", "Date", 1),
  c("individuels/age_souscription_min", "double", 1), c("individuels/age_souscription_max", "double", 1),
  c("individuels/part_femmes", "double", 1), c("individuels/part_conjoint", "double", 1),
  c("individuels/ecart_age_conjoint_max", "double", 1), c("individuels/part_prime_unique", "double", 1),
  c("individuels/duree_prime_unique_min", "integer", 1), c("individuels/duree_prime_unique_max", "integer", 1),
  c("individuels/duree_periodique_min", "integer", 1), c("individuels/duree_periodique_max", "integer", 1),
  c("individuels/part_trimestrielle", "double", 1), c("individuels/capitaux", "double", NA),
  c("individuels/age_fin_garantie", "double", 1), c("individuels/taux_resiliation", "double", 1),
  c("individuels/taux_tarif/annee", "integer", NA), c("individuels/taux_tarif/taux", "double", NA),
  c("individuels/tarif/q0", "double", 1), c("individuels/tarif/q2", "double", 1),
  c("individuels/tarif/age_ref", "double", 1), c("individuels/tarif/chargement", "double", 1),
  c("suites_deces/part_non_reclames", "double", 1), c("suites_deces/part_fixation_differee", "double", 1),
  c("suites_deces/delai_fixation_differee", "double", 1))

# Périodes de cotisation admises en version 2 (garanties/periode_cotisation).
.PERIODES_COTISATION <- c("civile", "anniversaire")

# Schéma de la loi vraie de la version `version` (1 ou 2).
.schema_loi_vraie <- function(version) {
  if (identical(version, 2L)) c(.SCHEMA_LOI_VRAIE, .SCHEMA_LOI_VRAIE_V2) else .SCHEMA_LOI_VRAIE
}

.feuille <- function(x, chemin) {
  for (nom in strsplit(chemin, "/", fixed = TRUE)[[1L]]) {
    if (!is.list(x) || is.null(names(x)) || !(nom %in% names(x))) return(NULL)
    x <- x[[nom]]
  }
  x
}

.controler_loi_vraie <- function(lv) {
  if (!is.list(lv) || is.data.frame(lv) || is.null(names(lv))) {
    .refus_simulation("simuler_base() : `loi_vraie` doit \u00eatre une liste nomm\u00e9e")
  }
  if (!identical(lv$version, 1L) && !identical(lv$version, VERSION_LOI_VRAIE)) {
    .refus_simulation(paste0("simuler_base() : loi vraie de version 1 ou ", VERSION_LOI_VRAIE, " attendue (`version`)"))
  }
  schema <- .schema_loi_vraie(lv$version)
  for (s in schema) {
    x <- .feuille(lv, s[1L])
    ok <- !is.null(x) && is.atomic(x) &&
      (if (s[2L] == "Date") identical(names(attributes(x)), "class") && identical(class(x), "Date") && is.double(x)
       else typeof(x) == s[2L] && is.null(attributes(x))) &&
      length(x) > 0L && (is.na(s[3L]) || length(x) == as.integer(s[3L])) && !anyNA(x) &&
      (!(s[2L] %in% c("double", "Date")) || all(is.finite(x))) && (s[2L] != "Date" || all(as.numeric(x) == floor(as.numeric(x))))
    if (!ok) {
      .refus_simulation(paste0("simuler_base() : loi vraie, `", s[1L], "` absent ou mal form\u00e9 (", s[2L],
                               if (!is.na(s[3L])) paste0(" de longueur ", s[3L]) else ", vecteur non vide",
                               ", sans manquant ni valeur non finie)"))
    }
  }
  # Domaine des valeurs numériques (revue finale, m6) : taux, cadences, âges, durées et
  # montants positifs ou nuls, sauf la moyenne du logarithme du salaire ; volumétrie d'au moins
  # un contrat de un assuré ; arrondi du salaire strictement positif ; âges d'entrée ordonnés.
  for (s in schema) {
    if (!(s[2L] %in% c("double", "integer")) || s[1L] == "portefeuille/salaire_log_moyenne") next
    if (any(.feuille(lv, s[1L]) < 0)) .refus_simulation(paste0("simuler_base() : loi vraie, `", s[1L], "` n\u00e9gatif"))
  }
  pf <- lv$portefeuille
  if (pf$nombre_contrats < 1L || pf$assures_par_contrat < 1L) {
    .refus_simulation("simuler_base() : loi vraie, nombre_contrats et assures_par_contrat : au moins 1")
  }
  if (pf$salaire_arrondi <= 0) .refus_simulation("simuler_base() : loi vraie, `portefeuille/salaire_arrondi` nul")
  if (pf$age_entree_min > pf$age_entree_max || pf$age_entree_max >= pf$age_retraite) {
    .refus_simulation(paste0("simuler_base() : loi vraie, \u00e2ges d'entr\u00e9e : age_entree_min <= age_entree_max ",
                             "< age_retraite"))
  }
  # Uniformes d'invalidité (revue finale, C7) : .taille_invalidite() pas de 30 jours doivent
  # couvrir le plus long séjour possible en invalidité, de l'entrée au plus jeune âge à la
  # retraite (au plus (age_retraite - age_entree_min) * 365,25 + 2 jours : années civiles et
  # arrondis des dates) ; sinon la trajectoire s'arrêterait faute d'uniformes, sans transition
  # jusqu'à la retraite. Taille gardée (elle fixe les tirages des jeux versionnés) ; vrai tant
  # que age_retraite - age_entree_min <= 68 ans environ.
  if ((pf$age_retraite - pf$age_entree_min) * .AN_JOURS + 2 > .taille_invalidite(pf) * .PAS_JOURS) {
    .refus_simulation(paste0("simuler_base() : loi vraie, \u00e9cart entre age_retraite et age_entree_min trop grand ",
                             "pour les uniformes d'invalidit\u00e9 du simulateur"))
  }
  probas <- c("portefeuille/part_affilies_effet", "portefeuille/part_femmes", "portefeuille/part_conjoint",
              "tables/maintien_incapacite/passage_au_terme", "tables/invalidite/reprise_mensuelle",
              "tables/invalidite/deces_mensuel", "tables/sans_suite/part", "tables/mortalite/qx_femmes",
              "tables/mortalite/qx_hommes", "tables/maintien_incapacite/reprise", "tables/maintien_incapacite/deces",
              "tables/maintien_incapacite/passage",
              if (identical(lv$version, 2L)) c("individuels/part_femmes", "individuels/part_conjoint",
                                               "individuels/part_prime_unique", "individuels/part_trimestrielle",
                                               "suites_deces/part_non_reclames", "suites_deces/part_fixation_differee"))
  for (p in probas) {
    x <- .feuille(lv, p)
    if (any(x < 0 | x > 1)) .refus_simulation(paste0("simuler_base() : loi vraie, `", p, "` hors de [0 ; 1]"))
  }
  m <- lv$tables$maintien_incapacite
  if (length(unique(c(length(m$mois), length(m$reprise), length(m$deces), length(m$passage)))) != 1L ||
      !identical(m$mois, seq.int(0L, length(m$mois) - 1L)) || any(m$reprise + m$deces + m$passage > 1)) {
    .refus_simulation("simuler_base() : loi vraie, maintien_incapacite : mois 0, 1, ... et probabilit\u00e9s de somme au plus 1")
  }
  if (length(m$mois) * .PAS_JOURS < lv$garanties$incapacite$duree_max_jours) {
    .refus_simulation("simuler_base() : loi vraie, maintien_incapacite plus court que la dur\u00e9e maximale d'indemnisation")
  }
  for (t in c("mortalite", "incidence_arret")) {
    a <- lv$tables[[t]]$age
    if (any(diff(a) != 1L) || any(lengths(lv$tables[[t]]) != length(a))) {
      .refus_simulation(paste0("simuler_base() : loi vraie, table ", t, " : \u00e2ges cons\u00e9cutifs et colonnes de m\u00eame longueur"))
    }
  }
  cat <- unlist(lv$tables$categories)
  if (abs(sum(cat) - 1) > 1e-12 || any(cat < 0)) {
    .refus_simulation("simuler_base() : loi vraie, categories : probabilit\u00e9s de somme 1")
  }
  d <- lv$defauts
  if (!is.list(d) || is.data.frame(d) || is.null(names(d)) || !setequal(names(d), DEFAUTS_SIMULES$parametre) ||
      length(d) != nrow(DEFAUTS_SIMULES) ||
      !all(vapply(d, function(x) is.double(x) && is.null(attributes(x)) && length(x) == 1L && !is.na(x) && x >= 0 && x <= 1, NA))) {
    .refus_simulation(paste0("simuler_base() : loi vraie, `defauts` : une intensit\u00e9 dans [0 ; 1] par d\u00e9faut simul\u00e9, ",
                             "sans valeur par d\u00e9faut (", paste(DEFAUTS_SIMULES$parametre, collapse = ", "), ")"))
  }
  if (identical(lv$version, 2L)) .controler_loi_vraie_v2(lv)
  # Clés inconnues (revue finale, m6) : toute feuille de la loi vraie est lue par le simulateur ;
  # une clé de la version 2 dans une loi de version 1 est inconnue.
  admises <- c(vapply(schema, `[`, "", 1L), paste0("defauts/", DEFAUTS_SIMULES$parametre))
  inconnues <- setdiff(.chemins_feuilles(lv), admises)
  if (length(inconnues) > 0L) {
    .refus_simulation(paste0("simuler_base() : loi vraie, cl\u00e9(s) inconnue(s) ou mal nomm\u00e9e(s) : ",
                             paste(inconnues, collapse = ", ")))
  }
  invisible(NULL)
}

# Domaines propres aux clés de la version 2 (spécification de B2, § 7.9.2, critère J.2), après
# les contrôles de forme, de signe et de probabilité communs : période de cotisation en liste
# fermée ; âges de souscription ordonnés, l'âge maximal augmenté du décalage de naissance tiré
# (au plus 27 jours, .tirer_individuels()) sous l'âge de fin de garantie ; durées entières d'au
# moins un an, min <= max ; paliers du taux du tarif de même longueur, années strictement
# croissantes ; dernière souscription au plus tôt au début de l'historique.
.controler_loi_vraie_v2 <- function(lv) {
  x <- lv$individuels
  if (!(lv$garanties$periode_cotisation %in% .PERIODES_COTISATION)) {
    .refus_simulation(paste0("simuler_base() : loi vraie, `garanties/periode_cotisation` hors de ",
                             paste(.PERIODES_COTISATION, collapse = ", ")))
  }
  if (x$age_souscription_min > x$age_souscription_max || x$age_souscription_max + 28 / .AN_JOURS >= x$age_fin_garantie) {
    .refus_simulation(paste0("simuler_base() : loi vraie, individuels : age_souscription_min <= age_souscription_max ",
                             "et age_souscription_max + 28 / 365,25 < age_fin_garantie"))
  }
  if (x$duree_prime_unique_min < 1L || x$duree_prime_unique_min > x$duree_prime_unique_max ||
      x$duree_periodique_min < 1L || x$duree_periodique_min > x$duree_periodique_max) {
    .refus_simulation("simuler_base() : loi vraie, individuels : dur\u00e9es d'au moins un an, min <= max")
  }
  tt <- x$taux_tarif
  if (length(tt$annee) != length(tt$taux) || any(diff(tt$annee) <= 0L)) {
    .refus_simulation(paste0("simuler_base() : loi vraie, `individuels/taux_tarif` : annee et taux de m\u00eame ",
                             "longueur, ann\u00e9es strictement croissantes"))
  }
  if (as.numeric(x$derniere_souscription) < as.numeric(lv$portefeuille$debut_historique)) {
    .refus_simulation(paste0("simuler_base() : loi vraie, `individuels/derniere_souscription` ant\u00e9rieure au ",
                             "d\u00e9but de l'historique"))
  }
  invisible(NULL)
}

# Chemins des feuilles d'une liste nommée (`a/b/c`) ; une liste vide, non nommée ou aux noms
# vides, manquants ou en double rend un chemin terminé par `?`, jamais admis.
.chemins_feuilles <- function(x, chemin = character(0)) {
  if (!is.list(x) || is.data.frame(x)) return(paste(chemin, collapse = "/"))
  noms <- names(x)
  if (length(x) == 0L || is.null(noms) || anyNA(noms) || any(!nzchar(noms)) || anyDuplicated(noms)) {
    return(paste(c(chemin, "?"), collapse = "/"))
  }
  unlist(lapply(noms, function(nm) .chemins_feuilles(x[[nm]], c(chemin, nm))), use.names = FALSE)
}

# Nombre d'uniformes d'invalidité par arrêt (pas de 30 jours) : taille fixée par le format des
# tirages des jeux versionnés (une par mois, sur l'écart entre l'âge de retraite et l'âge
# d'entrée minimal, plus un an) ; sa suffisance est contrôlée par .controler_loi_vraie().
.taille_invalidite <- function(p) ceiling((p$age_retraite - p$age_entree_min + 1) * 12)

# --- Outils de dates et de tirage -----------------------------------------------------

.date <- function(x) structure(as.numeric(x), class = "Date")

# Premier jour du mois, `k` mois après le mois de la date `d` (nombre de jours).
.debut_mois <- function(d, k = 0L) {
  lt <- as.POSIXlt(.date(d))
  m <- lt$year * 12L + lt$mon + as.integer(k)
  as.numeric(as.Date(sprintf("%04d-%02d-01", m %/% 12L + 1900L, m %% 12L + 1L)))
}

# Délai entier en jours (loi exponentielle de moyenne `moyenne`, discrétisée vers le bas), par
# inversion d'uniformes.
.delai <- function(u, moyenne) floor(-moyenne * log1p(-u))

# Valeur d'une table par âge (âge borné aux extrémités de la table).
.par_age <- function(table, colonne, age) {
  a <- table$age
  table[[colonne]][pmin(pmax(age, a[1L]), a[length(a)]) - a[1L] + 1L]
}


# --- Flux population ------------------------------------------------------------------

# Contrats, assurés et affiliations (hors fins liées à un sinistre, ajoutées par l'assemblage).
# Uniformes : une par contrat (décalage d'effet) ; sept par assuré (affilié à l'effet, date
# d'entrée, âge, sexe, salaire, départ, jour de naissance).
.tirer_population <- function(lv, ext) {
  p <- lv$portefeuille
  nc <- p$nombre_contrats
  na <- p$assures_par_contrat
  n <- nc * na
  u_c <- runif(nc)
  u <- matrix(runif(n * 7L), nrow = n, ncol = 7L, byrow = TRUE)
  debut <- as.numeric(p$debut_historique)
  effet_c <- .debut_mois(debut, floor(u_c * (p$decalage_effet_mois_max + 1L)))
  contrat <- rep(seq_len(nc), each = na)
  effet <- effet_c[contrat]
  a_l_effet <- u[, 1L] < p$part_affilies_effet
  entree <- ifelse(a_l_effet, effet, effet + floor(u[, 2L] * (ext - effet)))
  age <- p$age_entree_min + u[, 3L] * (p$age_entree_max - p$age_entree_min)
  naissance <- entree - floor(age * .AN_JOURS) - floor(u[, 7L] * 28)
  sexe <- ifelse(u[, 4L] < p$part_femmes, "F", "M")
  salaire <- round(exp(p$salaire_log_moyenne + p$salaire_log_ecart * stats::qnorm(u[, 5L])) / p$salaire_arrondi) *
    p$salaire_arrondi
  depart <- entree + floor(-log1p(-u[, 6L]) / p$taux_depart * .AN_JOURS)
  retraite <- as.numeric(date_atteinte_age(.date(naissance), rep(p$age_retraite, n), "revolu"))
  list(nc = nc, n = n, effet_contrat = effet_c, contrat = contrat, entree = entree, naissance = naissance,
       sexe = sexe, salaire = salaire, depart = depart, retraite = retraite,
       fin_naturelle = pmin(depart, retraite), motif_naturel = ifelse(depart < retraite, "depart_entreprise", "retraite"))
}

# --- Flux famille ---------------------------------------------------------------------

# Familles vraies : un conjoint par assuré avec la probabilité `part_conjoint`, de sexe opposé,
# né à un écart uniforme de plus ou moins `ecart_age_conjoint_max` ans. Trois uniformes par
# assuré.
.tirer_familles <- function(lv, pop) {
  p <- lv$portefeuille
  u <- matrix(runif(pop$n * 3L), nrow = pop$n, ncol = 3L, byrow = TRUE)
  conjoint <- u[, 1L] < p$part_conjoint
  ecart <- floor((2 * u[, 2L] - 1) * p$ecart_age_conjoint_max * .AN_JOURS)
  list(conjoint = conjoint, sexe = ifelse(pop$sexe == "F", "M", "F"), naissance = pop$naissance + ecart)
}

# --- Flux sinistres -------------------------------------------------------------------

# Trajectoires vraies : pour chaque assuré, phase d'activité jusqu'à sa fin naturelle
# d'affiliation ou l'extraction (décès ou arrêt, par pas de 30 jours), puis trajectoire
# complète de chaque arrêt survenu (jusqu'à son extinction, au-delà de l'extraction comprise).
# Uniformes par assuré : deux par pas d'activité (pas en nombre fixe, ceux de l'historique
# entier) ; par arrêt possible (`arrets_max_par_assure`) : sans suite, durée sans suite,
# catégorie, passage au terme, puis un par mois d'incapacité et un par mois d'invalidité
# (jusqu'à l'âge de retraite au plus tard).
.tirer_sinistres <- function(lv, pop, ext) {
  p <- lv$portefeuille
  t <- lv$tables
  n_pas <- ceiling((ext - min(pop$entree)) / .PAS_JOURS) + p$arrets_max_par_assure + 2L
  u_act <- array(runif(pop$n * n_pas * 2L), dim = c(2L, n_pas, pop$n))
  m_inc <- length(t$maintien_incapacite$mois)
  m_inv <- .taille_invalidite(p)
  largeur <- 4L + m_inc + m_inv
  k_max <- p$arrets_max_par_assure
  u_arr <- array(runif(pop$n * k_max * largeur), dim = c(largeur, k_max, pop$n))
  # anniversaires de chaque assuré (âges 0 à AGE_LIMITE_SIMULATION, convention revolu) et
  # taux par âge entier, calculés une fois : l'âge à une date est le nombre d'anniversaires
  # atteints, moins un
  ages <- 0:.AGE_LIMITE_SIMULATION
  anniv <- matrix(as.numeric(date_atteinte_age(.date(rep(pop$naissance, each = length(ages))),
                                               rep(ages, pop$n), "revolu")),
                  nrow = length(ages), ncol = pop$n)
  mu <- list(F = -log1p(-.par_age(t$mortalite, "qx_femmes", ages)), M = -log1p(-.par_age(t$mortalite, "qx_hommes", ages)))
  incidence <- .par_age(t$incidence_arret, "taux", ages)
  arrets <- list()
  deces <- list()
  for (i in seq_len(pop$n)) {
    mu_i <- mu[[pop$sexe[i]]]
    tps <- pop$entree[i]
    fin_act <- min(pop$fin_naturelle[i], ext)
    k <- 0L
    j <- 0L
    while (tps < fin_act) {
      j <- j + 1L
      fin_pas <- min(tps + .PAS_JOURS, fin_act)
      duree <- fin_pas - tps
      a <- findInterval(tps, anniv[, i])   # âge revolu + 1 : rang dans `ages`
      m_a <- mu_i[a]
      la <- if (k < k_max) incidence[a] else 0
      p_tot <- 1 - exp(-(m_a + la) * duree / .AN_JOURS)
      # qx = 1 (mu infini) : décès certain dans le pas, limite de m_a / (m_a + la) (revue
      # finale, C5 ; Inf / Inf rendrait NaN)
      p_dc <- if (is.infinite(m_a)) p_tot else if (m_a + la > 0) p_tot * m_a / (m_a + la) else 0
      u1 <- u_act[1L, j, i]
      jour <- tps + floor(u_act[2L, j, i] * duree)
      if (u1 < p_dc) {
        deces[[length(deces) + 1L]] <- list(assure = i, date = jour, origine = NA_integer_)
        break
      }
      if (u1 < p_tot) {
        k <- k + 1L
        tr <- .trajectoire_arret(u_arr[, k, i], jour, pop$retraite[i], lv, m_inc)
        tr$assure <- i
        tr$rang <- k
        arrets[[length(arrets) + 1L]] <- tr
        if (tr$fin_etat == "eteint") {
          deces[[length(deces) + 1L]] <- list(assure = i, date = tr$fin, origine = length(arrets))
          break
        }
        # retour en activité après une reprise ou un classement sans suite ; sinon (fin de
        # droits, retraite) l'assuré ne revient pas dans le portefeuille actif
        if (!(tr$motif_fin %in% c("reprise_travail", "sans_suite"))) break
        tps <- tr$fin + p$delai_minimal_rearret_jours
        next
      }
      tps <- fin_pas
    }
  }
  list(arrets = arrets, deces = deces)
}

# Trajectoire d'un arrêt survenu à `s`, pour un assuré atteignant l'âge de retraite à `r` :
# phases (etat, categorie, debut, fin), date et état de fin (clos, eteint, retraite), motif de
# la sortie. `u` : uniformes de l'arrêt (largeur fixe).
.trajectoire_arret <- function(u, s, r, lv, m_inc) {
  t <- lv$tables
  g <- lv$garanties
  mi <- t$maintien_incapacite
  phases <- list()
  fin <- function(date, etat, motif) list(debut = s, phases = phases, fin = date, fin_etat = etat, motif_fin = motif)
  if (u[1L] < t$sans_suite$part) {
    d <- s + t$sans_suite$duree_min_jours + floor(u[2L] * (t$sans_suite$duree_max_jours - t$sans_suite$duree_min_jours + 1))
    phases[[1L]] <- list(etat = "incapacite", categorie = NA_character_, debut = s, fin = d)
    return(fin(d, "clos", "sans_suite"))
  }
  cats <- unlist(t$categories)
  categorie <- names(cats)[findInterval(u[3L], cumsum(cats)) + 1L]
  terme <- s + g$incapacite$duree_max_jours
  passage <- NA_real_
  m <- 0L
  while (is.na(passage)) {
    debut_pas <- s + m * .PAS_JOURS
    if (debut_pas >= terme) {
      if (u[4L] < mi$passage_au_terme) { passage <- terme; break }
      phases[[1L]] <- list(etat = "incapacite", categorie = NA_character_, debut = s, fin = terme)
      return(fin(terme, "clos", "fin_droits"))
    }
    if (debut_pas >= r) {
      phases[[1L]] <- list(etat = "incapacite", categorie = NA_character_, debut = s, fin = r)
      return(fin(r, "retraite", "retraite"))
    }
    v <- u[5L + m]
    bornes <- cumsum(c(mi$reprise[m + 1L], mi$deces[m + 1L], mi$passage[m + 1L]))
    k <- findInterval(v, bornes) + 1L
    if (k <= 3L) {
      bas <- c(0, bornes)[k]
      date <- min(debut_pas + floor((v - bas) / (bornes[k] - bas) * .PAS_JOURS), terme, r)
      if (k == 3L) { passage <- date; break }
      phases[[1L]] <- list(etat = "incapacite", categorie = NA_character_, debut = s, fin = date)
      return(fin(date, if (k == 1L) "clos" else "eteint", if (k == 1L) "reprise_travail" else "deces"))
    }
    m <- m + 1L
  }
  phases[[1L]] <- list(etat = "incapacite", categorie = NA_character_, debut = s, fin = passage)
  if (passage >= r) return(fin(r, "retraite", "retraite"))
  pr <- t$invalidite$reprise_mensuelle
  pd <- t$invalidite$deces_mensuel
  for (j in seq_len(length(u) - 4L - m_inc)) {
    debut_pas <- passage + (j - 1L) * .PAS_JOURS
    if (debut_pas >= r) break
    v <- u[4L + m_inc + j]
    if (v < pr + pd) {
      date <- min(debut_pas + floor(v / (pr + pd) * .PAS_JOURS), r)
      phases[[2L]] <- list(etat = "invalidite", categorie = categorie, debut = passage, fin = date)
      return(fin(date, if (v < pr) "clos" else "eteint", if (v < pr) "reprise_travail" else "deces"))
    }
  }
  phases[[2L]] <- list(etat = "invalidite", categorie = categorie, debut = passage, fin = r)
  fin(r, "retraite", "retraite")
}

# --- Flux information -----------------------------------------------------------------

# Délais d'information, en jours (cadences de la loi vraie) : deux par assuré (saisie de
# l'affiliation, saisie de la radiation) ; seize par sinistre, sinistres pris dans l'ordre des
# arrêts puis des décès (ordre du flux sinistres) : déclaration, saisie du sinistre,
# instruction, ouverture du dossier principal, ouverture du dossier d'invalidité, saisie de la
# famille, règlement du capital, règlement des prestations périodiques, puis huit délais de
# saisie d'événements (entrée, ouverture de service, passage, ouverture de service
# d'invalidité, sortie, fin de service d'incapacité, fin de service d'invalidité, clôture ou
# fixation du capital).
.tirer_information <- function(lv, pop, sin) {
  cad <- lv$cadences
  u_a <- matrix(runif(pop$n * 2L), nrow = pop$n, ncol = 2L, byrow = TRUE)
  ns <- length(sin$arrets) + length(sin$deces)
  u_s <- matrix(runif(ns * 16L), nrow = ns, ncol = 16L, byrow = TRUE)
  nature <- c(rep("arret_travail", length(sin$arrets)), rep("deces", length(sin$deces)))
  moy_decl <- ifelse(nature == "deces", cad$declaration_deces, cad$declaration_arret)
  list(
    saisie_affiliation = .delai(u_a[, 1L], cad$saisie_affiliation),
    saisie_radiation = .delai(u_a[, 2L], cad$saisie_radiation),
    declaration = .delai(u_s[, 1L], moy_decl),
    saisie_sinistre = .delai(u_s[, 2L], cad$saisie_sinistre),
    instruction = .delai(u_s[, 3L], cad$instruction),
    ouverture = .delai(u_s[, 4L], cad$ouverture_dossier),
    ouverture_inv = .delai(u_s[, 5L], cad$ouverture_dossier),
    saisie_famille = .delai(u_s[, 6L], cad$saisie_famille),
    reglement_capital = .delai(u_s[, 7L], cad$reglement_capital),
    reglement_prestation = .delai(u_s[, 8L], cad$reglement_prestation),
    saisie_evenement = matrix(.delai(u_s[, 9:16, drop = FALSE], cad$saisie_evenement), nrow = ns))
}

# --- Flux individuels (loi vraie version 2) -----------------------------------------------

# Colonnes des uniformes d'un contrat individuel (largeur fixe, spécification de B2, § 7.9.4) :
# souscription (effet, âge, jour de naissance, sexe, conjoint, écart d'âge du conjoint, prime
# unique, fractionnement trimestriel, durée, capital, résiliation), seize délais d'information
# du sinistre éventuel (mêmes rubriques et même ordre que .tirer_information()), saisie de la
# fin du contrat, puis deux par pas de 30 jours de la trajectoire (décès, jour dans le pas).
.U_SOUSCRIPTION <- 11L
.U_INFORMATION <- .U_SOUSCRIPTION + 1:16
.U_SAISIE_FIN <- .U_SOUSCRIPTION + 17L

# Temporaires décès individuelles (spécification de B2, § 7.9.4) : souscription, tarif
# commercial déclaré, fin de garantie (terme, âge de fin de garantie, résiliation des primes
# périodiques à la première échéance qui suit strictement la notification), décès seul par pas
# de 30 jours jusqu'au plus tôt de la fin de garantie et de l'extraction (table de mortalité du
# sexe, comme au collectif), délais d'information. Uniformes de taille fixe par contrat (le
# nombre de pas couvre l'historique entier). Rend une liste de vecteurs par contrat (deces : date
# du décès, NA sans décès au plus tard à l'extraction ; fin_garantie et motif_fin : fin hors
# décès ; information : délais, mêmes champs que .tirer_information(), plus saisie_fin).
.tirer_individuels <- function(lv, ext) {
  p <- lv$portefeuille
  x <- lv$individuels
  cad <- lv$cadences
  n <- x$nombre_contrats
  debut <- as.numeric(p$debut_historique)
  n_pas <- ceiling((ext - debut) / .PAS_JOURS) + 2L
  largeur <- .U_SAISIE_FIN + 2L * n_pas
  u <- matrix(runif(n * largeur), nrow = n, ncol = largeur, byrow = TRUE)
  if (n == 0L) return(list(n = 0L, deces = numeric(0)))
  lt <- as.POSIXlt(.date(c(debut, as.numeric(x$derniere_souscription))))
  mois <- (lt$year[2L] - lt$year[1L]) * 12L + lt$mon[2L] - lt$mon[1L]
  effet <- .debut_mois(debut, floor(u[, 1L] * (mois + 1)))
  age <- x$age_souscription_min + u[, 2L] * (x$age_souscription_max - x$age_souscription_min)
  naissance <- effet - floor(age * .AN_JOURS) - floor(u[, 3L] * 28)
  sexe <- ifelse(u[, 4L] < x$part_femmes, "F", "M")
  conjoint <- u[, 5L] < x$part_conjoint
  ecart <- floor((2 * u[, 6L] - 1) * x$ecart_age_conjoint_max * .AN_JOURS)
  unique_p <- u[, 7L] < x$part_prime_unique
  periodicite <- ifelse(unique_p, "unique", ifelse(u[, 8L] < x$part_trimestrielle, "trimestrielle", "annuelle"))
  dmin <- ifelse(unique_p, x$duree_prime_unique_min, x$duree_periodique_min)
  dmax <- ifelse(unique_p, x$duree_prime_unique_max, x$duree_periodique_max)
  duree <- as.integer(dmin + floor(u[, 9L] * (dmax - dmin + 1)))
  terme <- .debut_mois(effet, 12L * duree)
  capital <- x$capitaux[floor(u[, 10L] * length(x$capitaux)) + 1L]
  # taux du tarif : dernier palier dont l'année est au plus celle de l'effet
  taux_tarif <- x$taux_tarif$taux[findInterval(as.POSIXlt(.date(effet))$year + 1900L, x$taux_tarif$annee)]
  # tarif commercial : q_t(x) au milieu de la durée, chargé ; prime par échéance ou unique
  xt <- calculer_age(.date(naissance), .date(effet), "revolu") + duree / 2
  taux_annuel <- (x$tarif$q0 + x$tarif$q2 * (xt - x$tarif$age_ref)^2) * (1 + x$tarif$chargement)
  par_an <- ifelse(periodicite == "trimestrielle", 4, 1)
  prime <- ifelse(unique_p, round(capital * taux_annuel * duree, 2), round(capital * taux_annuel / par_an, 2))
  date_age <- as.numeric(date_atteinte_age(.date(naissance), rep(x$age_fin_garantie, n), "revolu"))
  fin_contractuelle <- pmin(terme, date_age)
  # résiliation (primes périodiques) : notification exponentielle, fin à la première échéance
  # qui suit strictement la notification, si elle précède la fin contractuelle
  notification <- if (x$taux_resiliation > 0) effet + floor(-log1p(-u[, 11L]) / x$taux_resiliation * .AN_JOURS) else
    rep(Inf, n)
  periode <- ifelse(periodicite == "trimestrielle", 3L, 12L)
  fin_garantie <- fin_contractuelle
  motif_fin <- rep("terme", n)
  for (i in which(!unique_p & notification < fin_contractuelle)) {
    k <- 0L
    repeat {
      e <- .debut_mois(effet[i], periode[i] * k)
      if (e > notification[i]) break
      k <- k + 1L
    }
    if (e < fin_contractuelle[i]) {
      fin_garantie[i] <- e
      motif_fin[i] <- "resiliation_adherent"
    }
  }
  # décès : pas de 30 jours, de l'effet au plus tôt de la fin de garantie et de l'extraction
  ages <- 0:.AGE_LIMITE_SIMULATION
  anniv <- matrix(as.numeric(date_atteinte_age(.date(rep(naissance, each = length(ages))), rep(ages, n), "revolu")),
                  nrow = length(ages), ncol = n)
  t <- lv$tables
  mu <- list(F = -log1p(-.par_age(t$mortalite, "qx_femmes", ages)), M = -log1p(-.par_age(t$mortalite, "qx_hommes", ages)))
  deces <- rep(NA_real_, n)
  for (i in seq_len(n)) {
    mu_i <- mu[[sexe[i]]]
    tps <- effet[i]
    fin_act <- min(fin_garantie[i], ext)
    j <- 0L
    while (tps < fin_act) {
      j <- j + 1L
      fin_pas <- min(tps + .PAS_JOURS, fin_act)
      d <- fin_pas - tps
      m_a <- mu_i[findInterval(tps, anniv[, i])]
      p_dc <- if (is.infinite(m_a)) 1 else 1 - exp(-m_a * d / .AN_JOURS)
      if (u[i, .U_SAISIE_FIN + 2L * j - 1L] < p_dc) {
        deces[i] <- tps + floor(u[i, .U_SAISIE_FIN + 2L * j] * d)
        break
      }
      tps <- fin_pas
    }
  }
  ui <- u[, .U_INFORMATION, drop = FALSE]
  information <- list(
    declaration = .delai(ui[, 1L], cad$declaration_deces),
    saisie_sinistre = .delai(ui[, 2L], cad$saisie_sinistre),
    instruction = .delai(ui[, 3L], cad$instruction),
    ouverture = .delai(ui[, 4L], cad$ouverture_dossier),
    ouverture_inv = .delai(ui[, 5L], cad$ouverture_dossier),
    saisie_famille = .delai(ui[, 6L], cad$saisie_famille),
    reglement_capital = .delai(ui[, 7L], cad$reglement_capital),
    reglement_prestation = .delai(ui[, 8L], cad$reglement_prestation),
    saisie_evenement = matrix(.delai(ui[, 9:16, drop = FALSE], cad$saisie_evenement), nrow = n),
    saisie_fin = .delai(u[, .U_SAISIE_FIN], cad$saisie_radiation))
  list(n = n, effet = effet, naissance = naissance, sexe = sexe, conjoint = conjoint,
       sexe_conjoint = ifelse(sexe == "F", "M", "F"), naissance_conjoint = naissance + ecart,
       periodicite = periodicite, periode = ifelse(unique_p, NA_integer_, periode), duree = duree, terme = terme,
       capital = capital, taux_tarif = taux_tarif, prime = prime, age_fin_garantie = x$age_fin_garantie,
       fin_garantie = fin_garantie, motif_fin = motif_fin, deces = deces, information = information)
}

# --- Assemblage du jeu propre -----------------------------------------------------------

# Table `table` du dictionnaire à partir de colonnes nommées (valeurs ou NA du type) ; colonnes
# dans l'ordre du dictionnaire, noms de lignes automatiques.
.table <- function(dico, table, valeurs, n) {
  col <- dico$colonnes[dico$colonnes$table == table, , drop = FALSE]
  df <- lapply(seq_len(nrow(col)), function(i) {
    x <- valeurs[[col$colonne[i]]]
    type <- col$type[i]
    if (is.null(x)) x <- switch(type, character = rep(NA_character_, n), integer = rep(NA_integer_, n),
                                numeric = rep(NA_real_, n), logical = rep(NA, n), Date = rep(NA_real_, n))
    x <- rep_len(x, n)
    switch(type, character = as.character(x), integer = as.integer(x), numeric = as.numeric(x),
           logical = as.logical(x), Date = .date(x))
  })
  names(df) <- col$colonne
  df <- as.data.frame(df, stringsAsFactors = FALSE, optional = TRUE)
  names(df) <- col$colonne
  rownames(df) <- NULL
  df
}

# Colonnes d'une liste de lignes (listes nommées de même forme) ; liste vide : colonnes vides
# des types `vide` (vecteur nommé de types, dates en numeric), et non NULL (revue finale, M2).
.rbind_listes <- function(l, vide) {
  if (length(l) == 0L) return(lapply(vide, vector, length = 0L))
  noms <- names(l[[1L]])
  stats::setNames(lapply(noms, function(nm) do.call(c, lapply(l, `[[`, nm))), noms)
}

# `oui` là où `test` est vrai, NA sinon, toujours en texte (ifelse() rend un logique sur un
# vecteur vide ; revue finale, C2 et C3).
.si_texte <- function(test, oui) {
  x <- rep(NA_character_, length(test))
  x[test] <- oui[test]
  x
}

.ids <- function(prefixe, n, chiffres) sprintf(paste0("%s%0", chiffres, "d"), prefixe, seq_len(n))

# Assemble la base vraie (toutes les lignes, saisies avant ou après l'extraction), puis garde
# les lignes connues à l'extraction ; rend la base propre et les tables de vérité (sans le
# registre des défauts). Version 2 (`ind` : flux individuels, NULL en version 1 ; `suites` :
# matrice des uniformes des suites des décès, NULL en version 1) : les décès individuels
# suivent les décès collectifs dans les sinistres (assuré d'indice pop$n + rang du contrat) ;
# identifiants des tables partagées en numérotation commune.
.assembler_jeu <- function(lv, pop, fam, sin, inf, ext, dico, ind = NULL, suites = NULL) {
  g <- lv$garanties
  p <- lv$portefeuille
  nc <- pop$nc
  v2 <- identical(lv$version, 2L)
  sd <- lv$suites_deces
  mc <- if (v2) g$deces$majoration_conjoint else 0
  anniversaire <- v2 && g$periode_cotisation == "anniversaire"
  ni <- if (is.null(ind)) 0L else ind$n
  id_contrat <- .ids("CT", nc, 2L)
  id_assure <- .ids("AS", pop$n, 4L)
  id_ci <- .ids("CI", ni, 3L)
  id_gi <- .ids("GI", ni, 3L)
  id_ai <- .ids("AI", ni, 4L)
  id_assure_tout <- c(id_assure, id_ai)
  codes <- c("deces", "incapacite", "invalidite")
  id_gs <- matrix(.ids("GS", nc * 3L, 3L), nrow = nc, ncol = 3L, byrow = TRUE, dimnames = list(NULL, codes))

  # --- sinistres : arrêts (ordre du flux) puis décès collectifs, puis décès individuels
  # (ordre des contrats)
  na <- length(sin$arrets)
  nd <- length(sin$deces)
  k_ind <- if (ni) which(!is.na(ind$deces)) else integer(0)
  ndi <- length(k_ind)
  ns <- na + nd + ndi
  s_assure <- c(vapply(sin$arrets, `[[`, 0L, "assure"), vapply(sin$deces, `[[`, 0L, "assure"), pop$n + k_ind)
  s_surv <- c(vapply(sin$arrets, `[[`, 0, "debut"), vapply(sin$deces, `[[`, 0, "date"), ind$deces[k_ind])
  s_nature <- c(rep("arret_travail", na), rep("deces", nd + ndi))
  # arrêt d'origine d'un décès en arrêt ou en invalidité (rang dans les arrêts, NA sinon)
  s_origine <- c(rep(NA_integer_, na), vapply(sin$deces, function(d) as.integer(d$origine), 0L), rep(NA_integer_, ndi))
  # contrat individuel du décès (rang), NA pour un sinistre collectif
  s_ind <- c(rep(NA_integer_, na + nd), k_ind)
  if (ndi) {
    ii <- ind$information
    for (nm in setdiff(names(inf), "saisie_evenement")) inf[[nm]] <- c(inf[[nm]], ii[[nm]][k_ind])
    inf$saisie_evenement <- rbind(inf$saisie_evenement, ii$saisie_evenement[k_ind, , drop = FALSE])
  }
  ordre <- order(s_surv, s_assure, s_nature, method = "radix")
  id_sin <- character(ns)
  id_sin[ordre] <- .ids("SI", ns, 4L)
  s_decl <- s_surv + inf$declaration
  s_saisie <- s_decl + inf$saisie_sinistre
  s_instr <- s_saisie + inf$instruction
  s_contrat <- pop$contrat[s_assure]
  s_salaire <- pop$salaire[s_assure]
  sans_suite <- c(vapply(sin$arrets, function(a) a$motif_fin == "sans_suite", NA), rep(FALSE, nd + ndi))
  # instruction d'un arrêt sans suite : sa décision de classement (date de la sortie)
  fin_arret <- c(vapply(sin$arrets, `[[`, 0, "fin"), rep(NA_real_, nd + ndi))
  s_instr[sans_suite] <- pmax(s_saisie[sans_suite], fin_arret[sans_suite])

  # fin d'affiliation : décès survenu pendant l'affiliation (en activité ou en arrêt)
  fin_aff <- pop$fin_naturelle
  motif_aff <- pop$motif_naturel
  for (d in sin$deces) {
    if (d$date < fin_aff[d$assure]) {
      fin_aff[d$assure] <- d$date
      motif_aff[d$assure] <- "deces"
    }
  }

  # --- lignes vraies : dossiers, rentes, événements, prestations, famille, bénéficiaires
  dos <- list(); ren <- list(); eve <- list(); pre <- list(); fml <- list(); ben <- list(); etats <- list()
  depots <- list()
  ajouter <- function(l, x) { l[[length(l) + 1L]] <- x; l }
  ev <- function(sinistre, dossier, rente, type, effet, saisie, montant = NA_real_, motif = NA_character_,
                 justificatif = NA_character_, categorie = NA_character_) {
    list(id_sinistre = sinistre, id_dossier = dossier, id_rente = rente, type_evenement = type, date_effet = effet,
         date_saisie = saisie, montant = montant, motif = motif, justificatif = justificatif,
         categorie_invalidite = categorie)
  }
  pr <- function(dossier, rente, type, reglement, debut, fin, montant) {
    list(id_dossier = dossier, id_rente = rente, type_prestation = type, date_reglement = reglement,
         debut_periode = debut, fin_periode = fin, montant = montant)
  }
  n_dos <- 0L
  nouveau_dossier <- function() { n_dos <<- n_dos + 1L; sprintf("DO%04d", n_dos) }
  n_ren <- 0L
  for (k in seq_len(ns)) {
    i <- s_assure[k]
    se <- inf$saisie_evenement[k, ]
    sid <- id_sin[k]
    c_k <- s_contrat[k]
    if (s_nature[k] == "deces") {
      j <- s_ind[k]
      collectif <- is.na(j)
      d_id <- nouveau_dossier()
      ouv <- s_saisie[k] + inf$ouverture[k]
      dos <- ajouter(dos, list(id_dossier = d_id, id_sinistre = sid,
                               id_garantie_souscrite = if (collectif) id_gs[c_k, "deces"] else id_gi[j],
                               date_ouverture = ouv))
      conjoint <- if (collectif) fam$conjoint[i] else ind$conjoint[j]
      # capital : taux du capital (majoré du conjoint en version 2) x salaire ; capital
      # forfaitaire d'un contrat individuel
      capital <- if (collectif) round((g$deces$taux_capital + mc * conjoint) * s_salaire[k], 2) else ind$capital[j]
      fix <- max(s_instr[k], ouv)
      # suites du décès (version 2) : non réclamé, fixation différée
      non_reclame <- FALSE
      if (v2) {
        u_s <- suites[k - na, ]
        non_reclame <- u_s[1L] < sd$part_non_reclames
        if (u_s[2L] < sd$part_fixation_differee) fix <- fix + .delai(u_s[3L], sd$delai_fixation_differee)
      }
      eve <- ajouter(eve, ev(sid, d_id, NA_character_, "fixation_capital", fix, fix + se[8L], montant = capital))
      if (non_reclame) {
        # aucune prestation ni clôture ; vérité : dépôt du capital fixé, nominal, à la
        # déclaration + 10 ans (anniversaire)
        depots <- ajouter(depots, list(k = k, id_dossier = d_id, montant = capital,
                                       date = as.numeric(date_atteinte_age(.date(s_decl[k]), 10L, "revolu"))))
      } else {
        regl <- fix + inf$reglement_capital[k]
        pre <- ajouter(pre, pr(d_id, NA_character_, "capital", regl, NA_real_, NA_real_, capital))
        eve <- ajouter(eve, ev(sid, d_id, NA_character_, "cloture_dossier", regl, regl + se[5L], motif = "regle"))
      }
      fam_saisie <- s_instr[k] + inf$saisie_famille[k]
      if (conjoint) {
        m_id <- if (collectif) sprintf("ME%04d", i) else sprintf("MI%04d", j)
        fml <- ajouter(fml, list(id_membre = m_id, id_assure = id_assure_tout[i], lien = "conjoint",
                                 sexe = if (collectif) fam$sexe[i] else ind$sexe_conjoint[j],
                                 date_naissance = if (collectif) fam$naissance[i] else ind$naissance_conjoint[j],
                                 id_sinistre = sid, date_saisie = fam_saisie))
        if (!non_reclame) {
          ben <- ajouter(ben, list(id_dossier = d_id, id_membre = m_id, qualite = "conjoint_survivant", part = 1,
                                   date_saisie = max(ouv, fam_saisie)))
        }
      } else if (!non_reclame) {
        ben <- ajouter(ben, list(id_dossier = d_id, id_membre = NA_character_, qualite = "heritiers", part = 1,
                                 date_saisie = max(ouv, s_instr[k])))
      }
      if (non_reclame) {
        ben <- ajouter(ben, list(id_dossier = d_id, id_membre = NA_character_, qualite = "non_identifie", part = 1,
                                 date_saisie = max(ouv, s_instr[k])))
      }
      next
    }
    a <- sin$arrets[[k]]
    for (ph in a$phases) {
      etats <- ajouter(etats, list(id_sinistre = sid, etat = ph$etat, categorie_invalidite = ph$categorie,
                                   date_debut = ph$debut, date_fin = ph$fin))
    }
    etats <- ajouter(etats, list(id_sinistre = sid, etat = a$fin_etat, categorie_invalidite = NA_character_,
                                 date_debut = a$fin, date_fin = NA_real_))
    eve <- ajouter(eve, ev(sid, NA_character_, NA_character_, "entree_incapacite", a$debut,
                           max(a$debut, s_saisie[k]) + se[1L]))
    d_inc <- nouveau_dossier()
    ouv <- s_saisie[k] + inf$ouverture[k]
    dos <- ajouter(dos, list(id_dossier = d_inc, id_sinistre = sid, id_garantie_souscrite = id_gs[c_k, "incapacite"],
                             date_ouverture = ouv))
    fin_inc <- a$phases[[1L]]$fin
    debut_ij <- a$debut + g$incapacite$franchise_jours
    ij <- round(g$incapacite$taux_indemnite * s_salaire[k] / 365, 2)
    service <- fin_inc > debut_ij && a$motif_fin != "sans_suite"
    passage <- length(a$phases) == 2L
    motif_sortie <- a$motif_fin
    if (service) {
      eve <- ajouter(eve, ev(sid, d_inc, NA_character_, "ouverture_service", debut_ij, max(debut_ij, ouv) + se[2L],
                             montant = ij))
      # indemnités journalières mensuelles à terme échu, du lendemain de la franchise à la
      # veille de la fin de l'incapacité
      m0 <- .debut_mois(debut_ij)
      repeat {
        debut_p <- max(m0, debut_ij)
        fin_p <- min(.debut_mois(m0, 1L) - 1, fin_inc - 1)
        if (debut_p > fin_p) break
        regl <- max(fin_p, ouv) + inf$reglement_prestation[k]
        pre <- ajouter(pre, pr(d_inc, NA_character_, "indemnite_journaliere", regl, debut_p, fin_p,
                               round(ij * (fin_p - debut_p + 1), 2)))
        m0 <- .debut_mois(m0, 1L)
        if (m0 > fin_inc - 1) break
      }
      motif_fs <- if (passage) "passage_invalidite" else if (motif_sortie == "deces") "deces_beneficiaire" else motif_sortie
      eve <- ajouter(eve, ev(sid, d_inc, NA_character_, "fin_service", fin_inc, max(fin_inc, ouv) + se[6L],
                             motif = motif_fs,
                             justificatif = if (motif_fs == "deces_beneficiaire") "acte_deces" else NA_character_))
    }
    if (passage) {
      ph <- a$phases[[2L]]
      eve <- ajouter(eve, ev(sid, NA_character_, NA_character_, "passage_invalidite", ph$debut,
                             max(ph$debut, s_saisie[k]) + se[3L], categorie = ph$categorie))
      d_inv <- nouveau_dossier()
      ouv_inv <- max(ph$debut, s_saisie[k]) + inf$ouverture_inv[k]
      dos <- ajouter(dos, list(id_dossier = d_inv, id_sinistre = sid, id_garantie_souscrite = id_gs[c_k, "invalidite"],
                               date_ouverture = ouv_inv))
      n_ren <- n_ren + 1L
      r_id <- sprintf("RE%03d", n_ren)
      ren <- ajouter(ren, list(id_rente = r_id, id_dossier = d_inv, date_saisie = ouv_inv))
      rente <- round(g$invalidite$taux_rente[[ph$categorie]] * s_salaire[k], 2)
      eve <- ajouter(eve, ev(sid, d_inv, r_id, "ouverture_service", ph$debut, max(ph$debut, ouv_inv) + se[4L],
                             montant = rente))
      # arrérages trimestriels à terme échu, au prorata des jours
      q0 <- .debut_mois(ph$debut, -((as.POSIXlt(.date(ph$debut))$mon) %% 3L))
      repeat {
        debut_p <- max(q0, ph$debut)
        fin_p <- min(.debut_mois(q0, 3L) - 1, ph$fin - 1)
        if (debut_p > fin_p) break
        regl <- max(fin_p, ouv_inv) + inf$reglement_prestation[k]
        pre <- ajouter(pre, pr(d_inv, r_id, "arrerage", regl, debut_p, fin_p,
                               round(rente * (fin_p - debut_p + 1) / 365, 2)))
        q0 <- .debut_mois(q0, 3L)
        if (q0 > ph$fin - 1) break
      }
      motif_fs <- if (motif_sortie == "deces") "deces_beneficiaire" else motif_sortie
      eve <- ajouter(eve, ev(sid, d_inv, r_id, "fin_service", ph$fin, max(ph$fin, ouv_inv) + se[7L], motif = motif_fs,
                             justificatif = if (motif_fs == "deces_beneficiaire") "acte_deces" else NA_character_))
    }
    justif <- switch(motif_sortie, reprise_travail = "certificat_medical", deces = "acte_deces", NA_character_)
    eve <- ajouter(eve, ev(sid, NA_character_, NA_character_, "sortie", a$fin, max(a$fin, s_saisie[k]) + se[5L],
                           motif = motif_sortie, justificatif = justif))
  }

  # --- tables vraies en colonnes
  ch <- "character"
  nu <- "numeric"
  D <- .rbind_listes(dos, c(id_dossier = ch, id_sinistre = ch, id_garantie_souscrite = ch, date_ouverture = nu))
  R <- .rbind_listes(ren, c(id_rente = ch, id_dossier = ch, date_saisie = nu))
  E <- .rbind_listes(eve, c(id_sinistre = ch, id_dossier = ch, id_rente = ch, type_evenement = ch, date_effet = nu,
                            date_saisie = nu, montant = nu, motif = ch, justificatif = ch, categorie_invalidite = ch))
  P <- .rbind_listes(pre, c(id_dossier = ch, id_rente = ch, type_prestation = ch, date_reglement = nu,
                            debut_periode = nu, fin_periode = nu, montant = nu))
  Fm <- .rbind_listes(fml, c(id_membre = ch, id_assure = ch, lien = ch, sexe = ch, date_naissance = nu,
                             id_sinistre = ch, date_saisie = nu))
  B <- .rbind_listes(ben, c(id_dossier = ch, id_membre = ch, qualite = ch, part = nu, date_saisie = nu))
  Et <- .rbind_listes(etats, c(id_sinistre = ch, etat = ch, categorie_invalidite = ch, date_debut = nu, date_fin = nu))
  vis <- function(x) !is.na(x) & x <= ext
  # sinistres et dossiers connus ; un enfant n'est saisi qu'après sa parente (construction)
  s_vis <- vis(s_saisie)
  # événements : identifiants dans l'ordre (date d'effet, sinistre, saisie), sur la base vraie
  oe <- order(E$date_effet, E$id_sinistre, E$date_saisie, E$type_evenement, method = "radix")
  E <- lapply(E, `[`, oe)
  E$id_evenement <- .ids("EV", length(E$date_effet), 5L)
  op <- order(P$date_reglement, P$id_dossier, P$debut_periode, method = "radix")
  P <- lapply(P, `[`, op)
  P$id_prestation <- .ids("PR", length(P$date_reglement), 5L)
  P$date_saisie <- P$date_reglement
  B$id_beneficiaire <- .ids("BE", length(B$id_dossier), 3L)

  # --- flux futurs (prestations réglées après l'extraction) et sinistres non déclarés
  futur <- !vis(P$date_reglement)
  gar_dossier <- function(d) {
    gs <- D$id_garantie_souscrite[match(d, D$id_dossier)]
    code <- codes[(match(gs, id_gs) - 1L) %/% nc + 1L]
    code[gs %in% id_gi] <- "deces"
    code
  }
  sin_dossier <- D$id_sinistre[match(P$id_dossier, D$id_dossier)]
  k_futur <- match(sin_dossier[futur], id_sin)
  flux_futurs <- data.frame(id_sinistre = sin_dossier[futur],
                            date_survenance = .date(s_surv[k_futur]),
                            id_dossier = P$id_dossier[futur],
                            code_garantie = gar_dossier(P$id_dossier[futur]),
                            type_prestation = P$type_prestation[futur], date_reglement = .date(P$date_reglement[futur]),
                            debut_periode = .date(P$debut_periode[futur]), fin_periode = .date(P$fin_periode[futur]),
                            montant = P$montant[futur],
                            id_sinistre_origine = .si_texte(s_surv[k_futur] > ext, id_sin[s_origine[k_futur]]),
                            sinistre_connu = s_vis[k_futur], stringsAsFactors = FALSE)
  # capitaux non réclamés (version 2) : dépôt postérieur à l'extraction, ligne capital au
  # montant nominal fixé ; flux_futurs reste trié comme les prestations (règlement, dossier,
  # début de période)
  depots <- Filter(function(x) x$date > ext, depots)
  if (length(depots)) {
    kd <- vapply(depots, `[[`, 0L, "k")
    dd <- vapply(depots, `[[`, "", "id_dossier")
    flux_futurs <- rbind(flux_futurs, data.frame(
      id_sinistre = id_sin[kd], date_survenance = .date(s_surv[kd]), id_dossier = dd, code_garantie = gar_dossier(dd),
      type_prestation = "capital", date_reglement = .date(vapply(depots, `[[`, 0, "date")),
      debut_periode = .date(rep(NA_real_, length(kd))), fin_periode = .date(rep(NA_real_, length(kd))),
      montant = vapply(depots, `[[`, 0, "montant"), id_sinistre_origine = .si_texte(s_surv[kd] > ext, id_sin[s_origine[kd]]),
      sinistre_connu = s_vis[kd], stringsAsFactors = FALSE))
    flux_futurs <- flux_futurs[order(as.numeric(flux_futurs$date_reglement), flux_futurs$id_dossier,
                                     as.numeric(flux_futurs$debut_periode), method = "radix"), , drop = FALSE]
  }
  nd_ <- !s_vis & s_surv <= ext
  o_nd <- order(id_sin[nd_], method = "radix")
  sinistres_non_declares <- data.frame(id_sinistre = id_sin[nd_][o_nd], id_assure = id_assure_tout[s_assure[nd_]][o_nd],
                                       nature_sinistre = s_nature[nd_][o_nd],
                                       date_survenance = .date(s_surv[nd_][o_nd]),
                                       date_declaration = .date(s_decl[nd_][o_nd]),
                                       date_saisie = .date(s_saisie[nd_][o_nd]), stringsAsFactors = FALSE)
  o_et <- order(Et$id_sinistre, Et$date_debut, is.na(Et$date_fin), method = "radix")
  etats_vrais <- data.frame(id_sinistre = Et$id_sinistre[o_et], etat = Et$etat[o_et],
                            categorie_invalidite = Et$categorie_invalidite[o_et],
                            date_debut = .date(Et$date_debut[o_et]), date_fin = .date(Et$date_fin[o_et]),
                            stringsAsFactors = FALSE)
  familles_vraies <- data.frame(id_assure = id_assure[fam$conjoint], lien = rep("conjoint", sum(fam$conjoint)),
                                sexe = fam$sexe[fam$conjoint], date_naissance = .date(fam$naissance[fam$conjoint]),
                                id_membre = .si_texte(sprintf("ME%04d", which(fam$conjoint)) %in%
                                                        Fm$id_membre[vis(Fm$date_saisie)],
                                                      sprintf("ME%04d", which(fam$conjoint))),
                                stringsAsFactors = FALSE)
  if (ni && any(ind$conjoint)) {
    cj <- which(ind$conjoint)
    m_cj <- sprintf("MI%04d", cj)
    familles_vraies <- rbind(familles_vraies, data.frame(
      id_assure = id_ai[cj], lien = "conjoint", sexe = ind$sexe_conjoint[cj], date_naissance = .date(ind$naissance_conjoint[cj]),
      id_membre = .si_texte(m_cj %in% Fm$id_membre[vis(Fm$date_saisie)], m_cj), stringsAsFactors = FALSE))
  }

  # --- base connue à l'extraction
  af_saisie <- pop$entree + inf$saisie_affiliation
  af_vis <- vis(af_saisie)
  fin_connue <- vis(fin_aff + inf$saisie_radiation) & vis(fin_aff)
  sel_af <- which(af_vis)
  # assurés connus : par une affiliation ou par un sinistre saisis au plus tard à l'extraction
  sel_as <- which(af_vis | seq_len(pop$n) %in% s_assure[s_vis])
  # contrats individuels : fin (décès, sinon fin de garantie) et saisie de la fin (saisie du
  # sinistre pour un décès), connues à l'extraction seulement si toutes deux y sont au plus
  i_fin <- i_motif <- i_saisie_fin <- numeric(0)
  if (ni) {
    k_dc <- match(seq_len(ni), s_ind)
    dc <- !is.na(k_dc)
    i_fin <- ifelse(dc, ind$deces, ind$fin_garantie)
    i_motif <- ifelse(dc, "deces_assure", ind$motif_fin)
    i_saisie_fin <- ifelse(dc, s_saisie[k_dc], i_fin + ind$information$saisie_fin)
    i_connue <- vis(i_fin) & vis(i_saisie_fin)
    i_fin[!i_connue] <- NA
    i_motif[!i_connue] <- NA
    i_saisie_fin[!i_connue] <- NA
  }
  mois_effet <- function(d) as.POSIXlt(.date(d))$mon + 1L
  extraction <- .table(dico, "extraction", list(date_extraction = ext, debut_historique = p$debut_historique,
                                                 type_organisme = p$type_organisme, version_dictionnaire = dico$version,
                                                 devise = "EUR"), 1L)
  adherents <- .table(dico, "adherents", list(id_adherent = .ids("AD", nc, 2L)), nc)
  contrats <- .table(dico, "contrats", list(
    id_contrat = c(id_contrat, id_ci), nature_contrat = rep(c("collectif_obligatoire", "individuel"), c(nc, ni)),
    id_adherent = c(.ids("AD", nc, 2L), rep(NA_character_, ni)), id_assure = c(rep(NA_character_, nc), id_ai),
    date_effet = c(pop$effet_contrat, ind$effet), date_terme = c(rep(NA_real_, nc), ind$terme),
    date_fin = c(rep(NA_real_, nc), i_fin), motif_fin = c(rep(NA_character_, nc), i_motif),
    date_saisie_fin = c(rep(NA_real_, nc), i_saisie_fin),
    mois_echeance = c(if (anniversaire) mois_effet(pop$effet_contrat) else rep(1L, nc), mois_effet(ind$effet)),
    jour_echeance = 1L, preavis_mois = 2L, tacite_reconduction = rep(c(TRUE, FALSE), c(nc, ni)),
    gestionnaire = "interne", date_debut_gestion = c(pop$effet_contrat, ind$effet)), nc + ni)
  gs_code <- rep(codes, nc)
  gs_contrat <- rep(seq_len(nc), each = 3L)
  inc <- gs_code == "incapacite"
  inv <- gs_code == "invalidite"
  dc <- gs_code == "deces"
  per <- ifelse(inc, g$incapacite$periodicite_prestation, ifelse(inv, g$invalidite$periodicite_prestation, NA))
  sans <- rep(NA, ni)
  garanties_souscrites <- .table(dico, "garanties_souscrites", list(
    id_garantie_souscrite = c(as.vector(t(id_gs)), id_gi), id_contrat = c(id_contrat[gs_contrat], id_ci),
    code_garantie = c(gs_code, rep("deces", ni)),
    college = g$college, date_effet = c(pop$effet_contrat[gs_contrat], ind$effet),
    type_assiette = rep(c("salaire_reference", "forfait"), c(nc * 3L, ni)),
    type_franchise = c(ifelse(inc, g$incapacite$type_franchise, NA), sans),
    regle_complement = c(ifelse(inc, g$incapacite$regle_complement, ifelse(inv, g$invalidite$regle_complement, NA)), sans),
    option_iad = c(ifelse(dc, g$deces$option_iad, NA), rep(FALSE, ni)), periodicite_prestation = c(per, sans),
    terme_prestation = c(ifelse(inc, g$incapacite$terme_prestation, ifelse(inv, g$invalidite$terme_prestation, NA)), sans),
    periodicite_cotisation = c(rep(g$periodicite_cotisation, nc * 3L), ind$periodicite),
    taux_technique_tarif = c(rep(NA_real_, nc * 3L), ind$taux_tarif),
    clause_type_beneficiaire = c(ifelse(dc, g$deces$clause_type_beneficiaire, NA),
                                 rep("conjoint_enfants_heritiers", ni))), nc * 3L + ni)
  par_gs <- list(
    deces = c(list(c("taux_capital", g$deces$taux_capital), c("age_fin_garantie", g$deces$age_fin_garantie),
                   c("taux_cotisation", g$deces$taux_cotisation)),
              if (mc > 0) list(c("majoration_conjoint", mc))),
    incapacite = list(c("franchise_jours", g$incapacite$franchise_jours), c("taux_indemnite", g$incapacite$taux_indemnite),
                      c("duree_max_jours", g$incapacite$duree_max_jours),
                      c("delai_rechute_jours", g$incapacite$delai_rechute_jours),
                      c("age_fin_service", g$incapacite$age_fin_service),
                      c("taux_cotisation", g$incapacite$taux_cotisation)),
    invalidite = list(c("taux_rente", g$invalidite$taux_rente$cat1, "cat1"),
                      c("taux_rente", g$invalidite$taux_rente$cat2, "cat2"),
                      c("taux_rente", g$invalidite$taux_rente$cat3, "cat3"),
                      c("age_fin_service", g$invalidite$age_fin_service),
                      c("taux_cotisation", g$invalidite$taux_cotisation)))
  lp <- list()
  for (c_k in seq_len(nc)) for (code in codes) for (x in par_gs[[code]]) {
    lp[[length(lp) + 1L]] <- list(id_garantie_souscrite = id_gs[c_k, code], parametre = x[1L],
                                  categorie_invalidite = if (length(x) == 3L) x[3L] else NA_character_,
                                  valeur = as.numeric(x[2L]))
  }
  # contrats individuels : capital forfaitaire, âge de fin de garantie, prime par échéance
  for (j in seq_len(ni)) {
    noms <- c("capital_forfaitaire", "age_fin_garantie", if (!is.na(ind$periode[j])) "prime_periodique")
    valeurs <- c(ind$capital[j], ind$age_fin_garantie, if (!is.na(ind$periode[j])) ind$prime[j])
    for (m in seq_along(noms)) {
      lp[[length(lp) + 1L]] <- list(id_garantie_souscrite = id_gi[j], parametre = noms[m],
                                    categorie_invalidite = NA_character_, valeur = valeurs[m])
    }
  }
  lp <- .rbind_listes(lp, c(id_garantie_souscrite = "character", parametre = "character",
                           categorie_invalidite = "character", valeur = "numeric"))
  parametres <- .table(dico, "parametres", lp, length(lp$valeur))
  assures <- .table(dico, "assures", list(
    id_assure = c(id_assure[sel_as], id_ai), sexe = c(pop$sexe[sel_as], ind$sexe),
    date_naissance = c(pop$naissance[sel_as], ind$naissance),
    situation_familiale = c(ifelse(fam$conjoint[sel_as], "marie", "celibataire"),
                            ifelse(ind$conjoint, "marie", "celibataire")),
    date_situation_familiale = c(pop$entree[sel_as], ind$effet)), length(sel_as) + ni)
  affiliations <- .table(dico, "affiliations", list(
    id_affiliation = .ids("AF", pop$n, 4L)[sel_af], id_assure = id_assure[sel_af],
    id_contrat = id_contrat[pop$contrat[sel_af]], college = g$college, type_affiliation = "cotisant",
    date_debut = pop$entree[sel_af],
    date_fin = ifelse(fin_connue, fin_aff, NA)[sel_af], motif_fin = ifelse(fin_connue, motif_aff, NA)[sel_af],
    date_saisie = af_saisie[sel_af],
    date_saisie_fin = ifelse(fin_connue, fin_aff + inf$saisie_radiation, NA)[sel_af],
    salaire_reference = pop$salaire[sel_af]), length(sel_af))
  ks <- which(s_vis)
  ks <- ks[order(id_sin[ks], method = "radix")]
  instr_connue <- vis(s_instr[ks])
  sinistres <- .table(dico, "sinistres", list(
    id_sinistre = id_sin[ks], id_assure = id_assure_tout[s_assure[ks]], nature_sinistre = s_nature[ks],
    date_survenance = s_surv[ks], date_declaration = s_decl[ks],
    date_instruction = ifelse(instr_connue, s_instr[ks], NA),
    canal_declaration = ifelse(s_nature[ks] == "deces", "beneficiaire", "assure"), gestionnaire = "interne",
    date_saisie = s_saisie[ks]), length(ks))
  sel <- function(L, garder) lapply(L, `[`, which(garder))
  Dv <- sel(D, vis(D$date_ouverture))
  dossiers <- .table(dico, "dossiers", Dv, length(Dv$id_dossier))
  Fv <- sel(Fm, vis(Fm$date_saisie))
  famille <- .table(dico, "famille", Fv, length(Fv$id_membre))
  Bv <- sel(B, vis(B$date_saisie))
  beneficiaires <- .table(dico, "beneficiaires", Bv, length(Bv$id_dossier))
  Rv <- sel(R, vis(R$date_saisie))
  rentes <- .table(dico, "rentes", Rv, length(Rv$id_rente))
  Ev <- sel(E, vis(E$date_saisie) & vis(E$date_effet))
  evenements <- .table(dico, "evenements", Ev, length(Ev$id_evenement))
  Pv <- sel(P, vis(P$date_saisie) & vis(P$date_reglement))
  Pv$nature_mouvement <- rep("paiement", length(Pv$id_prestation))
  prestations <- .table(dico, "prestations", Pv, length(Pv$id_prestation))
  cotisations <- .cotisations(lv, pop, fin_aff, id_gs, codes, ext, dico, ind, id_gi, s_ind)

  base <- list(extraction = extraction, adherents = adherents, contrats = contrats,
               garanties_souscrites = garanties_souscrites, parametres = parametres, assures = assures,
               affiliations = affiliations, famille = famille, sinistres = sinistres, dossiers = dossiers,
               beneficiaires = beneficiaires, rentes = rentes, evenements = evenements, prestations = prestations,
               cotisations = cotisations)
  rownames(flux_futurs) <- NULL
  list(base = base, verite = list(flux_futurs = flux_futurs, etats_vrais = etats_vrais,
                                  familles_vraies = familles_vraies, sinistres_non_declares = sinistres_non_declares))
}

# Cotisations annuelles de chaque garantie souscrite : émission (au début de la période plus
# le délai d'émission) et encaissement (délai d'encaissement après l'émission), période de
# l'année civile commencée à l'effet du contrat (version 2, periode_cotisation `anniversaire` :
# période d'un an commençant à l'effet du contrat ou à l'un de ses anniversaires), assiette =
# somme des salaires des assurés affiliés au début de la période, au prorata des jours de la
# période ; mouvements datés au plus tard à l'extraction. Contrats individuels (version 2 ;
# `ind`, `id_gi`, `s_ind` : rang du contrat individuel de chaque sinistre) : prime unique, une
# émission à l'effet plus le délai d'émission, période de l'effet à la veille du terme ; primes
# périodiques, une émission par échéance antérieure à la fin du contrat (décès, sinon fin de
# garantie), période de l'échéance à la veille de la suivante.
.cotisations <- function(lv, pop, fin_aff, id_gs, codes, ext, dico, ind = NULL, id_gi = character(0),
                         s_ind = integer(0)) {
  g <- lv$garanties
  cad <- lv$cadences
  l <- list()
  mouvements <- function(gs, debut, fin, montant) {
    emission <- debut + cad$emission_cotisation
    encaissement <- emission + cad$encaissement_cotisation
    for (k in 1:2) {
      date <- if (k == 1L) emission else encaissement
      if (date > ext) next
      l[[length(l) + 1L]] <<- list(id_garantie_souscrite = gs, nature_mouvement = if (k == 1L) "emission" else "encaissement",
                                   debut_periode = debut, fin_periode = fin, date_mouvement = date, montant = montant)
    }
  }
  anniversaire <- identical(lv$version, 2L) && g$periode_cotisation == "anniversaire"
  annee_ext <- as.POSIXlt(.date(ext))$year + 1900L
  for (c_k in seq_len(pop$nc)) {
    effet <- pop$effet_contrat[c_k]
    if (anniversaire) {
      debuts <- numeric(0)
      repeat {
        d <- .debut_mois(effet, 12L * length(debuts))
        if (d > ext) break
        debuts <- c(debuts, d)
      }
      fins <- .debut_mois(effet, 12L * seq_along(debuts)) - 1
    } else {
      a0 <- as.POSIXlt(.date(effet))$year + 1900L
      debuts <- vapply(a0:annee_ext, function(a) max(effet, as.numeric(as.Date(sprintf("%04d-01-01", a)))), 0)
      fins <- vapply(a0:annee_ext, function(a) as.numeric(as.Date(sprintf("%04d-12-31", a))), 0)
    }
    for (q in seq_along(debuts)) {
      debut <- debuts[q]
      fin <- fins[q]
      membres <- pop$contrat == c_k & pop$entree <= debut & fin_aff > debut
      assiette <- sum(pop$salaire[membres]) * (fin - debut + 1) / 365
      for (code in codes) {
        montant <- round(g[[code]]$taux_cotisation * assiette, 2)
        if (montant <= 0) next
        mouvements(id_gs[c_k, code], debut, fin, montant)
      }
    }
  }
  for (j in seq_len(if (is.null(ind)) 0L else ind$n)) {
    if (is.na(ind$periode[j])) {
      mouvements(id_gi[j], ind$effet[j], ind$terme[j] - 1, ind$prime[j])
      next
    }
    fin_j <- if (j %in% s_ind) ind$deces[j] else ind$fin_garantie[j]
    k <- 0L
    repeat {
      e <- .debut_mois(ind$effet[j], ind$periode[j] * k)
      if (e >= fin_j || e > ext) break
      mouvements(id_gi[j], e, .debut_mois(ind$effet[j], ind$periode[j] * (k + 1L)) - 1, ind$prime[j])
      k <- k + 1L
    }
  }
  l <- .rbind_listes(l, c(id_garantie_souscrite = "character", nature_mouvement = "character",
                         debut_periode = "numeric", fin_periode = "numeric", date_mouvement = "numeric",
                         montant = "numeric"))
  o <- order(l$date_mouvement, l$id_garantie_souscrite, l$nature_mouvement, method = "radix")
  l <- lapply(l, `[`, o)
  l$id_cotisation <- .ids("CO", length(o), 4L)
  .table(dico, "cotisations", l, length(o))
}

# --- Injection des défauts ------------------------------------------------------------------

# Injecte, dans l'ordre du catalogue DEFAUTS_SIMULES, chaque défaut d'intensité non nulle sous
# la graine `graine + rang` : une uniforme par ligne de la table (taille fixe), la ligne
# éligible étant touchée si son uniforme est inférieure à l'intensité, et une seconde
# uniforme par ligne pour une valeur tirée. Les lignes éligibles et les valeurs propres sont
# lues sur le jeu propre ; les modifications de cellules s'appliquent ensuite, puis les lignes
# ajoutées (à la fin de leur table, dans l'ordre des rangs). Rend la base et le registre.
.injecter_defauts <- function(propre, intensites, graine, ext, te) {
  base <- propre
  registre <- list()
  cellules <- list()
  ajouts <- list()
  for (r in seq_len(nrow(DEFAUTS_SIMULES))) {
    def <- DEFAUTS_SIMULES[r, ]
    intensite <- intensites[[def$parametre]]
    if (intensite == 0) next
    t <- propre[[def$table]]
    n <- nrow(t)
    u <- avec_graine(graine + def$rang, list(choix = runif(n), valeur = runif(n)))
    res <- .defaut(def$code, propre, which(.eligibles(def$code, propre, te, ext) & u$choix < intensite), u$valeur, ext)
    for (m in res$cellules) {
      registre[[length(registre) + 1L]] <- list(code = def$code, parametre = def$parametre, rang = def$rang,
                                                table = def$table, cle = t[[1L]][m$ligne], colonne = m$colonne,
                                                valeur_propre = .texte_valeur(t[[m$colonne]][m$ligne]),
                                                valeur_injectee = .texte_valeur(m$valeur))
      cellules[[length(cellules) + 1L]] <- c(m, table = def$table)
    }
    for (a in res$ajouts) {
      registre[[length(registre) + 1L]] <- list(code = def$code, parametre = def$parametre, rang = def$rang,
                                                table = def$table, cle = a$ligne[[1L]], colonne = NA_character_,
                                                valeur_propre = NA_character_, valeur_injectee = a$original)
      ajouts[[length(ajouts) + 1L]] <- list(table = def$table, ligne = a$ligne)
    }
  }
  cles <- vapply(cellules, function(m) paste(m$table, m$ligne, m$colonne, sep = "\r"), "")
  if (anyDuplicated(cles)) stop("simulation : deux d\u00e9fauts sur une m\u00eame cellule (catalogue incoh\u00e9rent)", call. = FALSE)
  for (m in cellules) base[[m$table]][[m$colonne]][m$ligne] <- m$valeur
  for (a in ajouts) {
    base[[a$table]] <- rbind(base[[a$table]], a$ligne)
    rownames(base[[a$table]]) <- NULL
  }
  reg <- .rbind_listes(registre, stats::setNames(rep("character", length(COLONNES_REGISTRE)), COLONNES_REGISTRE))
  reg$rang <- as.integer(reg$rang)
  registre <- as.data.frame(reg[COLONNES_REGISTRE], stringsAsFactors = FALSE)
  list(base = base, registre = registre)
}

# Valeur d'une cellule en écriture canonique (ecrire_valeurs()), NA si manquante.
.texte_valeur <- function(x) if (is.na(x)) NA_character_ else ecrire_valeurs(x, "texte")

# Lignes éligibles d'un défaut dans le jeu propre (catalogue DEFAUTS_SIMULES, colonne
# `eligibles`) ; `te` : types d'événements du dictionnaire ; `ext` : date d'extraction.
# D01b : un encaissement daté de l'extraction n'est pas éligible, sa copie (bornée à
# l'extraction) aurait sa date (revue finale, C10).
.eligibles <- function(code, b, te, ext) {
  ev <- b$evenements
  switch(code,
    D01b = b$cotisations$nature_mouvement == "encaissement" & as.numeric(b$cotisations$date_mouvement) < ext,
    D02a = b$prestations$type_prestation == "indemnite_journaliere" &
      as.numeric(b$prestations$debut_periode) < as.numeric(b$prestations$fin_periode),
    D02b = if (nrow(ev) == 0L) logical(0) else {
      prog <- te$programmable[match(ev$type_evenement, te$type_evenement)]
      motifs_prog <- ifelse(startsWith(prog, "oui:"), substring(prog, 5L), "")
      !(prog == "oui" | mapply(function(m, l) !is.na(m) && m %in% strsplit(l, ";", fixed = TRUE)[[1L]],
                               ev$motif, motifs_prog))
    },
    D03a = !is.na(b$assures$date_naissance),
    D03b = !is.na(b$assures$sexe),
    D03c = !is.na(b$affiliations$salaire_reference),
    D03g = !is.na(b$prestations$date_saisie),
    D04b = b$cotisations$nature_mouvement == "emission",
    D05 = ev$type_evenement == "sortie" & ev$motif %in% "sans_suite",
    D06 = ev$type_evenement == "sortie" & ev$motif %in% c("reprise_travail", "deces") & !is.na(ev$justificatif),
    D09 = b$prestations$nature_mouvement == "paiement" & b$prestations$montant > 0,
    D13 = {
      p <- b$prestations
      d <- b$dossiers
      gs <- b$garanties_souscrites
      code_d <- gs$code_garantie[match(d$id_garantie_souscrite, gs$id_garantie_souscrite)]
      payes <- d$id_sinistre[d$id_dossier %in% p$id_dossier[p$type_prestation == "capital"] & code_d == "deces"]
      b$sinistres$nature_sinistre == "deces" & !is.na(b$sinistres$date_instruction) & b$sinistres$id_sinistre %in% payes
    })
}

# Modifications d'un défaut sur les lignes `lignes` de sa table du jeu propre `b` ; `v` :
# uniformes de valeur (une par ligne de la table). Rend `cellules` (ligne, colonne, valeur) et
# `ajouts` (ligne : data.frame d'une ligne ; original : identifiant copié).
.defaut <- function(code, b, lignes, v, ext) {
  cel <- function(colonne, valeurs) lapply(seq_along(lignes), function(j) {
    list(ligne = lignes[j], colonne = colonne, valeur = valeurs[[j]])
  })
  na_de <- function(x) x[NA_integer_]
  if (length(lignes) == 0L) return(list(cellules = list(), ajouts = list()))   # table vide (revue finale, M2)
  switch(code,
    D01b = {
      t <- b$cotisations
      max_num <- max(as.integer(substring(t$id_cotisation, 3L)))
      ajouts <- lapply(seq_along(lignes), function(j) {
        i <- lignes[j]
        copie <- t[i, , drop = FALSE]
        copie$id_cotisation <- sprintf("CO%04d", max_num + j)
        copie$date_mouvement <- .date(min(as.numeric(t$date_mouvement[i]) + 1 + floor(v[i] * 30), ext))
        rownames(copie) <- NULL
        list(ligne = copie, original = t$id_cotisation[i])
      })
      list(cellules = list(), ajouts = ajouts)
    },
    D02a = {
      t <- b$prestations
      list(cellules = c(cel("debut_periode", as.list(t$fin_periode[lignes])),
                        cel("fin_periode", as.list(t$debut_periode[lignes]))), ajouts = list())
    },
    D02b = {
      t <- b$evenements
      list(cellules = cel("date_saisie", lapply(lignes, function(i) .date(as.numeric(t$date_effet[i]) - 1 - floor(v[i] * 30)))),
           ajouts = list())
    },
    D03a = list(cellules = cel("date_naissance", rep(list(na_de(b$assures$date_naissance)), length(lignes))), ajouts = list()),
    D03b = list(cellules = cel("sexe", rep(list(NA_character_), length(lignes))), ajouts = list()),
    D03c = list(cellules = cel("salaire_reference", rep(list(NA_real_), length(lignes))), ajouts = list()),
    D03g = list(cellules = cel("date_saisie", rep(list(na_de(b$prestations$date_saisie)), length(lignes))), ajouts = list()),
    D04b = list(cellules = cel("id_garantie_souscrite", rep(list(.ID_ORPHELIN), length(lignes))), ajouts = list()),
    D05 = list(cellules = cel("motif", rep(list(NA_character_), length(lignes))), ajouts = list()),
    D06 = list(cellules = cel("justificatif", rep(list(NA_character_), length(lignes))), ajouts = list()),
    D09 = list(cellules = cel("montant", as.list(-b$prestations$montant[lignes])), ajouts = list()),
    D13 = list(cellules = cel("date_instruction", rep(list(na_de(b$sinistres$date_instruction)), length(lignes))),
               ajouts = list()))
}
