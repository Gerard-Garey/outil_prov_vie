# Définition des jeux versionnés de la v1 (#19 ; ADR 0010, points 19 et 20 ; onzième série, (e)) :
# script de provenance -- loi vraie, graines, date d'extraction, nom, description, date de visa,
# déclarations et conventions de controler_base(). Sourcé par tests/test_reproductibilite.R et
# tests/unitaires/simulation.R.
# La session principale écrit les jeux versionnés après le visa du mainteneur (M188), sa date
# portée dans DATE_VISA_V1 (ou DATE_VISA_V1_03) ci-dessous, depuis la racine du dépôt, package
# provie installé (un seul jeu : remplacer names(JEUX_V1) par son nom) :
#   rm -rf inst/extdata/jeux/v1-modeste-01 inst/extdata/jeux/v1-modeste-02 inst/extdata/jeux/v1-modeste-03
#   Rscript -e 'library(provie); source("tests/jeux_v1.R"); for (j in names(JEUX_V1))
#     ecrire_jeu(simuler_jeu_v1(j), file.path("inst/extdata/jeux", j))'
# Un jeu versionné ne change jamais en place (ADR 0008) : modifier une définition ci-dessous fait
# échouer le test de reproductibilité ; un jeu d'une version antérieure est retiré par un commit
# donnees: et remplacé par un jeu <nn+1> (M189).
#
# Loi vraie : chaque valeur est un jugement d'expert déclaré (statut rappelé en commentaire,
# avec sa justification courte), sans calibration sur une référence, choisie pour un
# portefeuille modeste et des tests fonctionnels rapides ; aucune n'est une valeur par défaut
# du simulateur. Validée par actuary le 9 novembre 2026 (avis sur #19), avec ses limites :
# pas de 30 jours et non mois civil (L1), tous les arrêts déclarés même sous la franchise (L2),
# délais exponentiels sans queue (L3), volume de test fonctionnel et non statistique (L4),
# âge de fin de garantie décès jamais atteint (L5).

# Phrase d'usage des deux jeux (limites L2 à L4 d'actuary), portée par leur description.
.USAGE_V1 <- paste(
  "Usage : tests fonctionnels, sans port\u00e9e statistique (quelques sinistres) ; tous les arr\u00eats",
  "sont d\u00e9clar\u00e9s, m\u00eame sous la franchise ; d\u00e9lais de d\u00e9claration exponentiels (IBNR d\u00e9c\u00e8s",
  "quasi nul).")

# Chaîne marquée UTF-8 : paste() de littéraux \u rend une chaîne d'encodage « unknown » sous
# une locale C (mesure du 9 novembre 2026, R 4.3.3), qu'ecrire_liste() refuserait.
.u8 <- function(s) { Encoding(s) <- "UTF-8"; s }

# Table de mortalité par valeurs (M160) : loi de Makeham, mu(x) = a + b c^x, qx = 1 - exp(-mu).
.qx_makeham <- function(age, a, b, c) 1 - exp(-(a + b * c^age))
.ages_mortalite <- 18:110
.ages_incidence <- 18:70
.mois_incapacite <- 0:36

LOI_VRAIE_V1 <- list(
  version = 1L,                                     # format de loi vraie lu par simuler_base()
  description = .u8(paste(
    "Portefeuille modeste de contrats collectifs obligatoires \u00e0 garanties li\u00e9es d\u00e9c\u00e8s, incapacit\u00e9",
    "et invalidit\u00e9 (#19) : cinq contrats de cent assur\u00e9s, huit ans d'historique.")),
  statut = .u8(paste(
    "Jugement d'expert d\u00e9clar\u00e9, sans calibration sur une r\u00e9f\u00e9rence ; valid\u00e9 par actuary le",
    "9 novembre 2026 (#19).")),
  portefeuille = list(
    # Statut de chaque valeur : jugement d'expert déclaré.
    type_organisme = "institution_prevoyance",      # organisme type des garanties collectives de prévoyance
    debut_historique = as.Date("2018-01-01"),       # huit ans d'historique avant l'extraction
    nombre_contrats = 5L,                           # volumétrie modeste (#19, critère 6)
    assures_par_contrat = 100L,                     # quelques centaines d'assurés au total
    decalage_effet_mois_max = 23L,                  # effets étalés sur deux ans après le début de l'historique
    part_affilies_effet = 0.7,                      # 70 % affiliés à l'effet, entrées ensuite uniformes
    age_entree_min = 20,                            # âge d'entrée uniforme de 20 à 58 ans
    age_entree_max = 58,
    part_femmes = 0.45,                             # population salariée mixte
    salaire_log_moyenne = log(32000),               # salaire médian de 32 000 euros
    salaire_log_ecart = 0.4,                        # dispersion log-normale modérée
    salaire_arrondi = 100,                          # salaire déclaré à 100 euros près
    taux_depart = 0.06,                             # départs de l'entreprise : 6 % par an
    age_retraite = 62L,                             # fin d'affiliation et de service à 62 ans
    part_conjoint = 0.55,                           # assurés ayant un conjoint
    ecart_age_conjoint_max = 5,                     # écart d'âge du conjoint uniforme de plus ou moins 5 ans
    delai_minimal_rearret_jours = 60L,              # pas de rechute modélisée : nouvel arrêt après 60 jours au moins
    arrets_max_par_assure = 4L),                    # borne de taille des tirages ; atteinte mesurée (aucun assuré)
  garanties = list(
    # Configuration des garanties liées (M160), jugement d'expert déclaré : garanties types.
    college = "ensemble",                           # un seul collège
    periodicite_cotisation = "annuelle",            # une émission et un encaissement par an
    deces = list(taux_capital = 2,                  # capital de 200 % du salaire, sans majoration familiale
                 age_fin_garantie = 67,             # jamais atteint (affiliation close à 62 ans, L5)
                 taux_cotisation = 0.004,           # 0,4 % du salaire
                 option_iad = FALSE,                # sans invalidité absolue et définitive
                 clause_type_beneficiaire = "conjoint_enfants_heritiers"),
    incapacite = list(franchise_jours = 90,         # franchise continue de 90 jours
                      taux_indemnite = 0.7,         # indemnité de 70 % du salaire, au jour sur 365
                      duree_max_jours = 1095,       # trois ans d'indemnisation au plus
                      delai_rechute_jours = 60,     # paramètre contractuel (rechute non simulée)
                      age_fin_service = 62,         # fin de service à la retraite
                      taux_cotisation = 0.006,      # 0,6 % du salaire
                      type_franchise = "continue", regle_complement = "forfaitaire",
                      periodicite_prestation = "mensuelle", terme_prestation = "echu"),
    invalidite = list(taux_rente = list(cat1 = 0.4, cat2 = 0.7, cat3 = 0.7),   # rente en % du salaire par catégorie
                      age_fin_service = 62,         # fin de service à la retraite
                      taux_cotisation = 0.008,      # 0,8 % du salaire
                      regle_complement = "forfaitaire",
                      periodicite_prestation = "trimestrielle", terme_prestation = "echu")),
  tables = list(
    # Tables de vérité par valeurs (M160), jugement d'expert déclaré, sans calibration.
    mortalite = list(age = .ages_mortalite,         # Makeham, pente ln 1,1 ; femmes b = 1e-5, hommes b = 2e-5
                     qx_femmes = .qx_makeham(.ages_mortalite, 0.0002, 0.00001, 1.1),
                     qx_hommes = .qx_makeham(.ages_mortalite, 0.0002, 0.00002, 1.1)),
    incidence_arret = list(age = .ages_incidence,   # incidence annuelle de 1,5 % à 18 ans, croissante avec l'âge
                           taux = 0.015 + 0.0003 * (.ages_incidence - 18)),
    maintien_incapacite = list(mois = .mois_incapacite,   # probabilités par pas de 30 jours d'ancienneté (L1)
                               reprise = 0.35 * exp(-.mois_incapacite / 4) + 0.03,   # reprises surtout précoces
                               deces = rep(0.002, length(.mois_incapacite)),         # mortalité en incapacité
                               passage = ifelse(.mois_incapacite >= 6L, 0.004, 0),   # passage après six mois
                               passage_au_terme = 0.7),     # au terme des trois ans : invalidité, sinon fin de droits
    invalidite = list(reprise_mensuelle = 0.002,    # par pas de 30 jours, sans effet de l'âge
                      deces_mensuel = 0.0015),
    categories = list(cat1 = 0.3, cat2 = 0.65, cat3 = 0.05),   # catégorie d'invalidité au passage
    sans_suite = list(part = 0.05,                  # 5 % des arrêts classés sans suite
                      duree_min_jours = 15, duree_max_jours = 60)),   # classement entre 15 et 60 jours
  cadences = list(
    # Délais moyens en jours (lois exponentielles discrétisées, sans queue lourde, L3), jugement
    # d'expert déclaré.
    declaration_deces = 40, declaration_arret = 20, saisie_sinistre = 5, instruction = 25, ouverture_dossier = 2,
    saisie_evenement = 7, saisie_famille = 3, reglement_capital = 15, reglement_prestation = 10,
    saisie_affiliation = 15, saisie_radiation = 30,
    emission_cotisation = 14,                       # émission au 14e jour de la période (délai fixe)
    encaissement_cotisation = 30),                  # encaissement 30 jours après l'émission (délai fixe)
  # Intensités des défauts (dictionnaire, § 9) : toutes déclarées, nulles ici ; chaque jeu
  # substitue les siennes (JEUX_V1).
  defauts = list(doublon_contenu = 0, date_ordre = 0, saisie_anterieure = 0, manquant_date_naissance = 0,
                 manquant_sexe = 0, manquant_salaire = 0, manquant_date_saisie = 0, orpheline = 0,
                 clos_sans_motif = 0, cloture_sans_justificatif = 0, montant_aberrant = 0,
                 instruction_absente = 0))

# Graines communes aux deux jeux : même jeu propre (E4.9), défauts seuls différents.
GRAINES_V1 <- list(population = 190101L, famille = 190102L, sinistres = 190103L, information = 190104L,
                   defauts = 190200L)
DATE_EXTRACTION_V1 <- as.Date("2025-12-31")
# Date du visa du mainteneur (M188) : visa donné le 9 novembre 2026, avec retouches (phrase
# d'usage, id_sinistre_origine) ; les jeux sont écrits à cette date (commande en tête de fichier).
DATE_VISA_V1 <- as.Date("2026-11-09")

# Déclarations communes, jugements de l'analyste pour le jeu (non de la loi vraie) : jeu de
# déclarations de controler_base() en Bd (réserve R3 d'actuary) ; un calcul sur ces jeux, en B2,
# fournira son propre plan.
.conventions_v1 <- list(age = "revolu",                                      # âge revolu (M154)
                        limite_age = list(regle = "depassement", age = "revolu"))   # requis par D07 (c) (M155)
.seuils_v1 <- list(
  # bornes de vraisemblance de l'âge (D02c) : larges, aucun âge du jeu propre ne les franchit
  d02c_age_min = list(assures_sinistre = 16, assures_affiliation = 16, famille = 0),
  d02c_age_max = list(assures_sinistre = 75, assures_affiliation = 70, famille = 110),
  # délais de D03g : moyennes des cadences de saisie de la loi vraie (déclaration de type oracle,
  # légitime pour un test de contrôle ; prestations : 0, la saisie est le règlement)
  d03g_delai_jours = list(contrats = 30, affiliations = 15, famille = 3, sinistres = 5, beneficiaires = 3,
                          rentes = 2, evenements = 7, prestations = 0))

# Déclarations de v1-modeste-02 : une par motif injecté qui attend une exclusion ou une
# hypothèse (declarations_requises vide aux deux arrêtés du test) ; listes nommées de listes
# nommées (forme sérialisable par ecrire_liste(), admise par controler_base()). Jugements de
# l'analyste : doublons (D01b) et orphelines (D04b) exclus pour les quatre familles ; D02a exclu
# pour la famille triangle et conservé ailleurs (proposition du dictionnaire, § 9) ; D02b et D03g
# en hypothèse de visibilité ; D03a, D03b, D03c en hypothèse nommée par une règle (valeur en
# clair, sans liste fermée en Bd, R3) ; D05, D06 et D13 signalés.
.exclusion <- function(motif, familles, action) {
  stats::setNames(lapply(familles, function(f) list(motif = motif, famille = f, action = action[[f]])),
                  paste(motif, familles, sep = "_"))
}
.hypothese <- function(motif, valeur) {
  stats::setNames(lapply(c("comptes_sociaux", "solvabilite_2"), function(r) {
    list(motif = motif, referentiel = r, poste = "tous", valeur = valeur)
  }), paste(motif, c("comptes_sociaux", "solvabilite_2"), sep = "_"))
}
.familles <- c("engagement", "triangle", "risque_en_cours", "regle_comptable")
.tout <- function(action) stats::setNames(as.list(rep(action, 4L)), .familles)
.declarations_v1_02 <- list(
  exclusions = c(.exclusion("D01b", .familles, .tout("exclure")),
                 .exclusion("D02a", .familles, list(engagement = "conserver", triangle = "exclure",
                                                    risque_en_cours = "conserver", regle_comptable = "conserver")),
                 .exclusion("D04b", .familles, .tout("exclure"))),
  hypotheses = c(.hypothese("D02b", "visibilite_max_saisie_effet_parente"),
                 .hypothese("D03a", "age_par_defaut_du_segment"),
                 .hypothese("D03b", "sexe_par_defaut_du_poste"),
                 .hypothese("D03c", "salaire_par_defaut_du_college"),
                 .hypothese("D03g", "date_effet_plus_delai"),
                 .hypothese("D05", "signalement"),
                 .hypothese("D06", "signalement"),
                 .hypothese("D13", "signalement")),
  seuils = .seuils_v1)

JEUX_V1 <- list(
  `v1-modeste-01` = list(
    description = .u8(paste(
      "Jeu propre (aucun d\u00e9faut inject\u00e9) du portefeuille modeste \u00e0 garanties li\u00e9es d\u00e9c\u00e8s et arr\u00eat",
      "de travail ; m\u00eames graines que v1-modeste-02. declarations.txt : jeu de d\u00e9clarations de",
      "controler_base() en Bd (aucune d\u00e9claration requise \u00e0 l'extraction et au 31 d\u00e9cembre 2024).", .USAGE_V1)),
    defauts = list(),
    declarations = list(declarations = list(seuils = .seuils_v1), conventions = .conventions_v1)),
  `v1-modeste-02` = list(
    description = .u8(paste(
      "Jeu de contr\u00f4le, non de calcul : m\u00eame jeu propre que v1-modeste-01, avec douze d\u00e9fauts du",
      "dictionnaire, \u00a7 9 ; D09 refuse la colonne prestations.montant. Sous-cas simul\u00e9s (loi vraie,",
      "version 1) : doublon_contenu sur les encaissements de cotisations, date_ordre par permutation",
      "des p\u00e9riodes d'indemnit\u00e9s journali\u00e8res, saisie_anterieure sur evenements, manquants de date",
      "de naissance et de sexe sur assures, de salaire sur affiliations, de date de saisie sur",
      "prestations, orpheline sur les \u00e9missions de cotisations, clos_sans_motif sur les sorties sans",
      "suite, cloture_sans_justificatif sur les sorties, montant_aberrant par signe invers\u00e9 seul,",
      "instruction_absente par la date seule. declarations.txt : jeu de d\u00e9clarations de",
      "controler_base() en Bd.", .USAGE_V1)),
    # Intensités (jugement d'expert) : relevées pour qu'au moins une ligne de chaque défaut soit
    # injectée sous ces graines ; clos_sans_motif à 1 (deux sorties sans suite éligibles).
    defauts = list(doublon_contenu = 0.05, date_ordre = 0.1, saisie_anterieure = 0.02,
                   manquant_date_naissance = 0.02, manquant_sexe = 0.02, manquant_salaire = 0.02,
                   manquant_date_saisie = 0.02, orpheline = 0.03, clos_sans_motif = 1,
                   cloture_sans_justificatif = 0.1, montant_aberrant = 0.05, instruction_absente = 0.5),
    declarations = list(declarations = .declarations_v1_02, conventions = .conventions_v1)))

# --- Jeu v1-modeste-03 (#69 ; spécification de B2, § 7.9 ; ADR 0011, point 14) ------------
# Jeu propre du capital décès : loi vraie au format version 2 (§ 7.9.2), base LOI_VRAIE_V1 avec
# les substitutions et ajouts du § 7.9.3, chacun jugement d'expert déclaré ; intensités de test
# et mortalité relevée (volume de test, non réaliste). Les définitions de v1-modeste-01 et
# v1-modeste-02 ci-dessus restent inchangées.
LOI_VRAIE_V1_03 <- local({
  lv <- LOI_VRAIE_V1
  lv$version <- 2L                                  # format version 2 (§ 7.9.2)
  lv$description <- .u8(paste(
    "Portefeuille modeste du capital d\u00e9c\u00e8s (#69) : six contrats collectifs obligatoires de deux cent",
    "cinquante assur\u00e9s \u00e0 garanties li\u00e9es d\u00e9c\u00e8s, incapacit\u00e9 et invalidit\u00e9, et deux cents temporaires",
    "d\u00e9c\u00e8s individuelles ; dix ans d'historique."))
  lv$statut <- .u8(paste(
    "Jugement d'expert d\u00e9clar\u00e9, sans calibration sur une r\u00e9f\u00e9rence (sp\u00e9cification de B2, \u00a7 7.9.3) ;",
    "intensit\u00e9s des suites des d\u00e9c\u00e8s et mortalit\u00e9 relev\u00e9e : volume de test, non r\u00e9aliste."))
  # Portefeuille collectif (statut : jugement d'expert déclaré).
  lv$portefeuille$type_organisme <- "societe_assurance"    # temporaires individuelles (A132-1) ; diversité avec 01 et 02
  lv$portefeuille$debut_historique <- as.Date("2016-01-01")   # dix ans : accumulation des capitaux non réclamés
  lv$portefeuille$nombre_contrats <- 6L             # volume de test (m14)
  lv$portefeuille$assures_par_contrat <- 250L
  lv$portefeuille$age_entree_min <- 30              # population plus âgée : décès en nombre suffisant
  lv$portefeuille$age_entree_max <- 58
  # Mortalité de Makeham, b doublé par rapport à la v1 : volume de test, non réaliste.
  lv$tables$mortalite$qx_femmes <- .qx_makeham(.ages_mortalite, 0.0002, 0.00002, 1.1)
  lv$tables$mortalite$qx_hommes <- .qx_makeham(.ages_mortalite, 0.0002, 0.00004, 1.1)
  lv$garanties$periode_cotisation <- "anniversaire" # périodes de cotisation non civiles (P3 collectif)
  lv$garanties$deces$majoration_conjoint <- 0.25    # majoration du conjoint sous calcul, familles simulées
  lv$individuels <- list(
    nombre_contrats = 200L,
    derniere_souscription = as.Date("2025-06-01"),  # effets au premier du mois, de debut_historique à cette date
    age_souscription_min = 25, age_souscription_max = 60,
    part_femmes = 0.45, part_conjoint = 0.55, ecart_age_conjoint_max = 5,   # mêmes valeurs que le collectif
    part_prime_unique = 0.4,
    duree_prime_unique_min = 5L, duree_prime_unique_max = 10L,              # années entières
    duree_periodique_min = 10L, duree_periodique_max = 20L,
    part_trimestrielle = 0.5,                       # primes périodiques trimestrielles, sinon annuelles
    capitaux = c(50000, 100000, 150000, 200000, 300000),   # équiprobables
    age_fin_garantie = 70,                          # des contrats prennent fin par l'âge avant leur terme
    taux_resiliation = 0.04,                        # annuel, primes périodiques
    taux_tarif = list(annee = c(2016L, 2020L, 2023L), taux = c(0.015, 0.005, 0.015)),   # trois valeurs d'A132_1
    tarif = list(q0 = 0.0005, q2 = 0.00001, age_ref = 18, chargement = 0.25))       # formule de mortalite_fictive_v1_03
  lv$suites_deces <- list(part_non_reclames = 0.20, # intensités de test
                          part_fixation_differee = 0.50,
                          delai_fixation_differee = 1095)   # jours, moyenne
  # defauts : tous nuls (jeu propre, ADR 0011, point 14), repris de LOI_VRAIE_V1
  lv[c("version", "description", "statut", "portefeuille", "garanties", "individuels", "suites_deces", "tables",
       "cadences", "defauts")]
})

# Graines (convention de GRAINES_V1), dans l'ordre des tirages de la version 2, déclarées sans
# sélection (décision du mainteneur du 11 novembre 2026, option (d), erratum v1.0.11) : aucune
# n'est choisie d'après le résultat d'un critère V ; la recherche de graine suites_deces de la
# règle D3 (onze essais en échec sous 190306 à 190316, puis 190317 retenue à tort : son seul
# dossier de P1 capital_du était déjà payé) est abandonnée et consignée dans la description du
# jeu (.ESSAIS_V1_03).
GRAINES_V1_03 <- list(population = 190301L, famille = 190302L, sinistres = 190303L, information = 190304L,
                      individuels = 190305L, suites_deces = 190306L, defauts = 190400L)
# Date du visa du mainteneur (M188) : visa donné le 11 novembre 2026 ; le jeu est écrit à cette date.
DATE_VISA_V1_03 <- as.Date("2026-11-11")

# Phrase d'usage et limites (spécification de B2, § 7.9.1 et § 7.9.5).
.USAGE_V1_03 <- paste(
  "Usage : tests fonctionnels et r\u00e9f\u00e9rences, sans port\u00e9e statistique ; revue sur mesure de I1 (#70).",
  "Limites : celles de v1-modeste-01 pour la part collective (pas de 30 jours, tous les arr\u00eats d\u00e9clar\u00e9s,",
  "d\u00e9lais exponentiels sans queue, volume de test, \u00e2ge de fin de garantie collectif jamais atteint) ;",
  "v\u00e9rit\u00e9 d'un capital non r\u00e9clam\u00e9 = d\u00e9p\u00f4t nominal, revalorisation l\u00e9gale non simul\u00e9e ;",
  "intensit\u00e9s des suites des d\u00e9c\u00e8s et mortalit\u00e9 relev\u00e9e, volume de test ; tarif individuel = formule",
  "d\u00e9clar\u00e9e sur la table fictive, non un tarif de march\u00e9 ; aucun d\u00e9faut inject\u00e9 ; aucun enfant ;",
  "capital pay\u00e9 au nominal par le simulateur, sans la revalorisation l\u00e9gale de la survenance au r\u00e8glement : un",
  "dossier pay\u00e9 de cl\u00f4ture non saisie \u00e0 l'arr\u00eat\u00e9 garde sous capital_dossier un solde \u00e9gal \u00e0 cette revalorisation,",
  "que la v\u00e9rit\u00e9 ne porte pas (\u00e9cart de mod\u00e8le, non une erreur du moteur).")

# Recherche de graine abandonnée (décision du mainteneur du 11 novembre 2026, option (d),
# erratum v1.0.11, qui remplace la règle D3 de l'erratum v1.0.8).
.ESSAIS_V1_03 <- paste(
  "Graines d\u00e9clar\u00e9es sans s\u00e9lection (d\u00e9cision du mainteneur du 11 novembre 2026, option (d), erratum",
  "v1.0.11), suites_deces 190306 comprise ; la recherche de graine de la r\u00e8gle D3 (onze essais en \u00e9chec du",
  "seul crit\u00e8re P1 capital_du, retir\u00e9 de V.3, sous 190306 \u00e0 190316, puis 190317 retenue \u00e0 tort : son",
  "seul dossier de P1 capital_du \u00e9tait d\u00e9j\u00e0 pay\u00e9) est abandonn\u00e9e.")

JEUX_V1$`v1-modeste-03` <- list(
  description = .u8(paste(
    "Jeu propre du capital d\u00e9c\u00e8s et des garanties li\u00e9es : six contrats collectifs (p\u00e9riodes de",
    "cotisation \u00e0 l'anniversaire, majoration du conjoint) et deux cents temporaires d\u00e9c\u00e8s individuelles",
    "\u00e0 prime unique ou p\u00e9riodique ; capitaux non r\u00e9clam\u00e9s et fixations diff\u00e9r\u00e9es, \u00e0 des intensit\u00e9s",
    "de test. declarations.txt : celles de v1-modeste-01.", .USAGE_V1_03, .ESSAIS_V1_03)),
  defauts = list(),
  declarations = list(declarations = list(seuils = .seuils_v1), conventions = .conventions_v1))

# Loi vraie, graines et date de visa d'un jeu : celles de la v1 (intensités de défauts du jeu
# substituées) ; celles de v1-modeste-03 pour ce jeu.
loi_vraie_v1 <- function(nom) {
  lv <- if (identical(nom, "v1-modeste-03")) LOI_VRAIE_V1_03 else LOI_VRAIE_V1
  for (p in names(JEUX_V1[[nom]]$defauts)) lv$defauts[[p]] <- JEUX_V1[[nom]]$defauts[[p]]
  lv
}
graines_v1 <- function(nom) if (identical(nom, "v1-modeste-03")) GRAINES_V1_03 else GRAINES_V1
date_visa_v1 <- function(nom) if (identical(nom, "v1-modeste-03")) DATE_VISA_V1_03 else DATE_VISA_V1

simuler_jeu_v1 <- function(nom, date_visa = date_visa_v1(nom)) {
  j <- JEUX_V1[[nom]]
  provie::simuler_base(loi_vraie_v1(nom), graines_v1(nom), DATE_EXTRACTION_V1, nom = nom, description = j$description,
                       declarations = j$declarations, date_visa = date_visa)
}
