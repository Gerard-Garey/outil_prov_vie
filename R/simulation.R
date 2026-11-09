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
#
# Modèle (jugement d'expert déclaré dans la loi vraie, jamais une valeur par défaut) :
# assurés affiliés à des contrats collectifs obligatoires qui portent trois garanties liées
# (décès, incapacité, invalidité ; dictionnaire, § 3, T4) ; en activité, décès et arrêt de
# travail en risques concurrents, par pas de 30 jours, sous des taux annuels par âge ; un
# arrêt suit un modèle mensuel par ancienneté (reprise, décès, passage en invalidité), passe
# en invalidité ou s'éteint par fin de droits au terme de la durée maximale d'indemnisation,
# et prend fin à l'âge de fin de service ; l'invalidité suit des taux mensuels constants
# (reprise, décès) ; le décès d'un assuré en activité ou en arrêt ouvre un sinistre décès
# (maintien de la garantie décès pendant l'arrêt) ; un arrêt peut être classé sans suite.

# --- Constantes ------------------------------------------------------------------

# Flux du jeu propre, dans leur ordre de tirage, et graine des défauts (point 19) : noms
# exacts de l'argument `graines` de simuler_base().
FLUX_SIMULATION <- c("population", "famille", "sinistres", "information")
GRAINES_SIMULATION <- c(FLUX_SIMULATION, "defauts")

# Version du format de la loi vraie lue par simuler_base() (`loi_vraie$version`).
VERSION_LOI_VRAIE <- 1L

# Version du simulateur, consignée au manifeste (ADR 0010, onzième série, (c)) et soumise au
# test d'identité des jeux versionnés. Règle d'incrément : toute modification de ce module qui
# change la sortie de simuler_base() pour une entrée admise, fût-ce sur un seul jeu, incrémente
# VERSION_SIMULATEUR, et son commit est un changement de résultat sur les jeux (tableau avant /
# après des volumétries et du registre) ; un refactorage sans effet garde la version. Un jeu
# d'une version antérieure est retiré par un commit donnees: et remplacé par un jeu <nn+1>
# (M189).
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
    "encaissements (copie sous un nouvel identifiant, mouvement dat\u00e9 apr\u00e8s l'original)",
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
# ecrire_liste(), version VERSION_LOI_VRAIE ; forme décrite par .controler_loi_vraie()), avec
# les graines `graines` (liste nommée d'entiers, noms GRAINES_SIMULATION), à la date
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
# version, paramètre de défaut inconnu ou hors de [0 ; 1], date d'extraction antérieure au
# début de l'historique.
simuler_base <- function(loi_vraie, graines, date_extraction, nom, description, declarations = NULL,
                         date_visa = NULL) {
  if (missing(loi_vraie) || missing(graines) || missing(date_extraction) || missing(nom) || missing(description)) {
    .refus_simulation("simuler_base() : loi_vraie, graines, date_extraction, nom et description sont obligatoires")
  }
  .controler_loi_vraie(loi_vraie)
  graines <- .controler_graines(graines)
  if (!identical(class(date_extraction), "Date") || length(date_extraction) != 1L || is.na(date_extraction)) {
    .refus_simulation("simuler_base() : `date_extraction` doit \u00eatre une Date renseign\u00e9e de longueur 1")
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
  dico <- dictionnaire()

  pop <- avec_graine(graines$population, .tirer_population(loi_vraie, ext))
  fam <- avec_graine(graines$famille, .tirer_familles(loi_vraie, pop))
  sin <- avec_graine(graines$sinistres, .tirer_sinistres(loi_vraie, pop, ext))
  inf <- avec_graine(graines$information, .tirer_information(loi_vraie, pop, sin))
  propre <- .assembler_jeu(loi_vraie, pop, fam, sin, inf, ext, dico)
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

.controler_graines <- function(graines) {
  if (!is.list(graines) || is.data.frame(graines) || !setequal(names(graines), GRAINES_SIMULATION) ||
      length(graines) != length(GRAINES_SIMULATION) ||
      !all(vapply(graines, function(g) is.integer(g) && length(g) == 1L && !is.na(g), NA))) {
    .refus_simulation(paste0("simuler_base() : `graines` doit \u00eatre une liste nomm\u00e9e d'entiers renseign\u00e9s (",
                             paste(GRAINES_SIMULATION, collapse = ", "), ")"))
  }
  if (any(vapply(graines, function(g) abs(as.numeric(g)) > .Machine$integer.max - nrow(DEFAUTS_SIMULES), NA))) {
    .refus_simulation("simuler_base() : graine trop grande (graine des d\u00e9fauts + rang hors des entiers)")
  }
  graines[GRAINES_SIMULATION]
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
  if (!identical(lv$version, VERSION_LOI_VRAIE)) {
    .refus_simulation(paste0("simuler_base() : loi vraie de version ", VERSION_LOI_VRAIE, " attendue (`version`)"))
  }
  for (s in .SCHEMA_LOI_VRAIE) {
    x <- .feuille(lv, s[1L])
    ok <- !is.null(x) && is.atomic(x) &&
      (if (s[2L] == "Date") identical(names(attributes(x)), "class") && identical(class(x), "Date") && is.double(x)
       else typeof(x) == s[2L] && is.null(attributes(x))) &&
      length(x) > 0L && (is.na(s[3L]) || length(x) == as.integer(s[3L])) && !anyNA(x)
    if (!ok) {
      .refus_simulation(paste0("simuler_base() : loi vraie, `", s[1L], "` absent ou mal form\u00e9 (", s[2L],
                               if (!is.na(s[3L])) paste0(" de longueur ", s[3L]) else ", vecteur non vide",
                               ", sans manquant)"))
    }
  }
  probas <- c("portefeuille/part_affilies_effet", "portefeuille/part_femmes", "portefeuille/part_conjoint",
              "tables/maintien_incapacite/passage_au_terme", "tables/invalidite/reprise_mensuelle",
              "tables/invalidite/deces_mensuel", "tables/sans_suite/part", "tables/mortalite/qx_femmes",
              "tables/mortalite/qx_hommes", "tables/maintien_incapacite/reprise", "tables/maintien_incapacite/deces",
              "tables/maintien_incapacite/passage")
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
  invisible(NULL)
}

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
  m_inv <- ceiling((p$age_retraite - p$age_entree_min + 1) * 12)
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
      p_dc <- if (m_a + la > 0) p_tot * m_a / (m_a + la) else 0
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

.rbind_listes <- function(l) {
  if (length(l) == 0L) return(NULL)
  noms <- names(l[[1L]])
  stats::setNames(lapply(noms, function(nm) do.call(c, lapply(l, `[[`, nm))), noms)
}

.ids <- function(prefixe, n, chiffres) sprintf(paste0("%s%0", chiffres, "d"), prefixe, seq_len(n))

# Assemble la base vraie (toutes les lignes, saisies avant ou après l'extraction), puis garde
# les lignes connues à l'extraction ; rend la base propre et les tables de vérité (sans le
# registre des défauts).
.assembler_jeu <- function(lv, pop, fam, sin, inf, ext, dico) {
  g <- lv$garanties
  p <- lv$portefeuille
  nc <- pop$nc
  id_contrat <- .ids("CT", nc, 2L)
  id_assure <- .ids("AS", pop$n, 4L)
  codes <- c("deces", "incapacite", "invalidite")
  id_gs <- matrix(.ids("GS", nc * 3L, 3L), nrow = nc, ncol = 3L, byrow = TRUE, dimnames = list(NULL, codes))

  # --- sinistres : arrêts (ordre du flux) puis décès
  na <- length(sin$arrets)
  nd <- length(sin$deces)
  ns <- na + nd
  s_assure <- c(vapply(sin$arrets, `[[`, 0L, "assure"), vapply(sin$deces, `[[`, 0L, "assure"))
  s_surv <- c(vapply(sin$arrets, `[[`, 0, "debut"), vapply(sin$deces, `[[`, 0, "date"))
  s_nature <- c(rep("arret_travail", na), rep("deces", nd))
  # arrêt d'origine d'un décès en arrêt ou en invalidité (rang dans les arrêts, NA sinon)
  s_origine <- c(rep(NA_integer_, na), vapply(sin$deces, function(d) as.integer(d$origine), 0L))
  ordre <- order(s_surv, s_assure, s_nature, method = "radix")
  id_sin <- character(ns)
  id_sin[ordre] <- .ids("SI", ns, 4L)
  s_decl <- s_surv + inf$declaration
  s_saisie <- s_decl + inf$saisie_sinistre
  s_instr <- s_saisie + inf$instruction
  s_contrat <- pop$contrat[s_assure]
  s_salaire <- pop$salaire[s_assure]
  sans_suite <- c(vapply(sin$arrets, function(a) a$motif_fin == "sans_suite", NA), rep(FALSE, nd))
  # instruction d'un arrêt sans suite : sa décision de classement (date de la sortie)
  fin_arret <- c(vapply(sin$arrets, `[[`, 0, "fin"), rep(NA_real_, nd))
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
      d_id <- nouveau_dossier()
      ouv <- s_saisie[k] + inf$ouverture[k]
      dos <- ajouter(dos, list(id_dossier = d_id, id_sinistre = sid, id_garantie_souscrite = id_gs[c_k, "deces"],
                               date_ouverture = ouv))
      capital <- round(g$deces$taux_capital * s_salaire[k], 2)
      fix <- max(s_instr[k], ouv)
      eve <- ajouter(eve, ev(sid, d_id, NA_character_, "fixation_capital", fix, fix + se[8L], montant = capital))
      regl <- fix + inf$reglement_capital[k]
      pre <- ajouter(pre, pr(d_id, NA_character_, "capital", regl, NA_real_, NA_real_, capital))
      eve <- ajouter(eve, ev(sid, d_id, NA_character_, "cloture_dossier", regl, regl + se[5L], motif = "regle"))
      fam_saisie <- s_instr[k] + inf$saisie_famille[k]
      if (fam$conjoint[i]) {
        m_id <- sprintf("ME%04d", i)
        fml <- ajouter(fml, list(id_membre = m_id, id_assure = id_assure[i], lien = "conjoint", sexe = fam$sexe[i],
                                 date_naissance = fam$naissance[i], id_sinistre = sid, date_saisie = fam_saisie))
        ben <- ajouter(ben, list(id_dossier = d_id, id_membre = m_id, qualite = "conjoint_survivant", part = 1,
                                 date_saisie = max(ouv, fam_saisie)))
      } else {
        ben <- ajouter(ben, list(id_dossier = d_id, id_membre = NA_character_, qualite = "heritiers", part = 1,
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
  D <- .rbind_listes(dos); R <- .rbind_listes(ren); E <- .rbind_listes(eve); P <- .rbind_listes(pre)
  Fm <- .rbind_listes(fml); B <- .rbind_listes(ben); Et <- .rbind_listes(etats)
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
  gar_dossier <- function(d) codes[(match(D$id_garantie_souscrite[match(d, D$id_dossier)], id_gs) - 1L) %/% nc + 1L]
  sin_dossier <- D$id_sinistre[match(P$id_dossier, D$id_dossier)]
  k_futur <- match(sin_dossier[futur], id_sin)
  flux_futurs <- data.frame(id_sinistre = sin_dossier[futur],
                            date_survenance = .date(s_surv[k_futur]),
                            id_dossier = P$id_dossier[futur],
                            code_garantie = gar_dossier(P$id_dossier[futur]),
                            type_prestation = P$type_prestation[futur], date_reglement = .date(P$date_reglement[futur]),
                            debut_periode = .date(P$debut_periode[futur]), fin_periode = .date(P$fin_periode[futur]),
                            montant = P$montant[futur],
                            id_sinistre_origine = ifelse(s_surv[k_futur] > ext, id_sin[s_origine[k_futur]],
                                                         NA_character_),
                            sinistre_connu = s_vis[k_futur], stringsAsFactors = FALSE)
  nd_ <- !s_vis & s_surv <= ext
  o_nd <- order(id_sin[nd_], method = "radix")
  sinistres_non_declares <- data.frame(id_sinistre = id_sin[nd_][o_nd], id_assure = id_assure[s_assure[nd_]][o_nd],
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
                                id_membre = ifelse(sprintf("ME%04d", which(fam$conjoint)) %in% Fm$id_membre[vis(Fm$date_saisie)],
                                                   sprintf("ME%04d", which(fam$conjoint)), NA_character_),
                                stringsAsFactors = FALSE)

  # --- base connue à l'extraction
  af_saisie <- pop$entree + inf$saisie_affiliation
  af_vis <- vis(af_saisie)
  fin_connue <- vis(fin_aff + inf$saisie_radiation) & vis(fin_aff)
  sel_af <- which(af_vis)
  # assurés connus : par une affiliation ou par un sinistre saisis au plus tard à l'extraction
  sel_as <- which(af_vis | seq_len(pop$n) %in% s_assure[s_vis])
  extraction <- .table(dico, "extraction", list(date_extraction = ext, debut_historique = p$debut_historique,
                                                 type_organisme = p$type_organisme, version_dictionnaire = dico$version,
                                                 devise = "EUR"), 1L)
  adherents <- .table(dico, "adherents", list(id_adherent = .ids("AD", nc, 2L)), nc)
  contrats <- .table(dico, "contrats", list(
    id_contrat = id_contrat, nature_contrat = "collectif_obligatoire", id_adherent = .ids("AD", nc, 2L),
    date_effet = pop$effet_contrat, mois_echeance = 1L, jour_echeance = 1L, preavis_mois = 2L,
    tacite_reconduction = TRUE, gestionnaire = "interne", date_debut_gestion = pop$effet_contrat), nc)
  gs_code <- rep(codes, nc)
  gs_contrat <- rep(seq_len(nc), each = 3L)
  inc <- gs_code == "incapacite"
  inv <- gs_code == "invalidite"
  dc <- gs_code == "deces"
  per <- ifelse(inc, g$incapacite$periodicite_prestation, ifelse(inv, g$invalidite$periodicite_prestation, NA))
  garanties_souscrites <- .table(dico, "garanties_souscrites", list(
    id_garantie_souscrite = as.vector(t(id_gs)), id_contrat = id_contrat[gs_contrat], code_garantie = gs_code,
    college = g$college, date_effet = pop$effet_contrat[gs_contrat], type_assiette = "salaire_reference",
    type_franchise = ifelse(inc, g$incapacite$type_franchise, NA),
    regle_complement = ifelse(inc, g$incapacite$regle_complement, ifelse(inv, g$invalidite$regle_complement, NA)),
    option_iad = ifelse(dc, g$deces$option_iad, NA), periodicite_prestation = per,
    terme_prestation = ifelse(inc, g$incapacite$terme_prestation, ifelse(inv, g$invalidite$terme_prestation, NA)),
    periodicite_cotisation = g$periodicite_cotisation,
    clause_type_beneficiaire = ifelse(dc, g$deces$clause_type_beneficiaire, NA)), nc * 3L)
  par_gs <- list(
    deces = list(c("taux_capital", g$deces$taux_capital), c("age_fin_garantie", g$deces$age_fin_garantie),
                 c("taux_cotisation", g$deces$taux_cotisation)),
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
  lp <- .rbind_listes(lp)
  parametres <- .table(dico, "parametres", lp, length(lp$valeur))
  assures <- .table(dico, "assures", list(
    id_assure = id_assure[sel_as], sexe = pop$sexe[sel_as], date_naissance = pop$naissance[sel_as],
    situation_familiale = ifelse(fam$conjoint[sel_as], "marie", "celibataire"),
    date_situation_familiale = pop$entree[sel_as]), length(sel_as))
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
    id_sinistre = id_sin[ks], id_assure = id_assure[s_assure[ks]], nature_sinistre = s_nature[ks],
    date_survenance = s_surv[ks], date_declaration = s_decl[ks],
    date_instruction = ifelse(instr_connue, s_instr[ks], NA),
    canal_declaration = ifelse(s_nature[ks] == "deces", "beneficiaire", "assure"), gestionnaire = "interne",
    date_saisie = s_saisie[ks]), length(ks))
  sel <- function(L, garder) lapply(L, `[`, which(garder))
  Dv <- sel(D, vis(D$date_ouverture))
  dossiers <- .table(dico, "dossiers", Dv, length(Dv$id_dossier))
  Fv <- sel(Fm, if (is.null(Fm)) logical(0) else vis(Fm$date_saisie))
  famille <- .table(dico, "famille", Fv, length(Fv$id_membre))
  Bv <- sel(B, vis(B$date_saisie))
  beneficiaires <- .table(dico, "beneficiaires", Bv, length(Bv$id_dossier))
  Rv <- sel(R, if (is.null(R)) logical(0) else vis(R$date_saisie))
  rentes <- .table(dico, "rentes", Rv, length(Rv$id_rente))
  Ev <- sel(E, vis(E$date_saisie) & vis(E$date_effet))
  evenements <- .table(dico, "evenements", Ev, length(Ev$id_evenement))
  Pv <- sel(P, vis(P$date_saisie) & vis(P$date_reglement))
  Pv$nature_mouvement <- rep("paiement", length(Pv$id_prestation))
  prestations <- .table(dico, "prestations", Pv, length(Pv$id_prestation))
  cotisations <- .cotisations(lv, pop, fin_aff, id_gs, codes, ext, dico)

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
# l'année civile commencée à l'effet du contrat, assiette = somme des salaires des assurés
# affiliés au début de la période, au prorata des jours de la période ; mouvements datés au
# plus tard à l'extraction.
.cotisations <- function(lv, pop, fin_aff, id_gs, codes, ext, dico) {
  g <- lv$garanties
  cad <- lv$cadences
  l <- list()
  annee_ext <- as.POSIXlt(.date(ext))$year + 1900L
  for (c_k in seq_len(pop$nc)) {
    effet <- pop$effet_contrat[c_k]
    a0 <- as.POSIXlt(.date(effet))$year + 1900L
    for (a in a0:annee_ext) {
      debut <- max(effet, as.numeric(as.Date(sprintf("%04d-01-01", a))))
      fin <- as.numeric(as.Date(sprintf("%04d-12-31", a)))
      membres <- pop$contrat == c_k & pop$entree <= debut & fin_aff > debut
      assiette <- sum(pop$salaire[membres]) * (fin - debut + 1) / 365
      emission <- debut + cad$emission_cotisation
      encaissement <- emission + cad$encaissement_cotisation
      for (code in codes) {
        montant <- round(g[[code]]$taux_cotisation * assiette, 2)
        if (montant <= 0) next
        for (k in 1:2) {
          date <- if (k == 1L) emission else encaissement
          if (date > ext) next
          l[[length(l) + 1L]] <- list(id_garantie_souscrite = id_gs[c_k, code],
                                      nature_mouvement = if (k == 1L) "emission" else "encaissement",
                                      debut_periode = debut, fin_periode = fin, date_mouvement = date, montant = montant)
        }
      }
    }
  }
  l <- .rbind_listes(l)
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
    res <- .defaut(def$code, propre, which(.eligibles(def$code, propre, te) & u$choix < intensite), u$valeur, ext)
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
  reg <- .rbind_listes(registre)
  if (is.null(reg)) reg <- stats::setNames(rep(list(character(0)), length(COLONNES_REGISTRE)), COLONNES_REGISTRE)
  reg$rang <- as.integer(reg$rang)
  registre <- as.data.frame(reg[COLONNES_REGISTRE], stringsAsFactors = FALSE)
  list(base = base, registre = registre)
}

# Valeur d'une cellule en écriture canonique (ecrire_valeurs()), NA si manquante.
.texte_valeur <- function(x) if (is.na(x)) NA_character_ else ecrire_valeurs(x, "texte")

# Lignes éligibles d'un défaut dans le jeu propre (catalogue DEFAUTS_SIMULES, colonne
# `eligibles`) ; `te` : types d'événements du dictionnaire.
.eligibles <- function(code, b, te) {
  ev <- b$evenements
  switch(code,
    D01b = b$cotisations$nature_mouvement == "encaissement",
    D02a = b$prestations$type_prestation == "indemnite_journaliere" &
      as.numeric(b$prestations$debut_periode) < as.numeric(b$prestations$fin_periode),
    D02b = {
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
