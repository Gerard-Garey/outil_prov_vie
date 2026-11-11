# Tests unitaires du module `simulation` (R/simulation.R) et des fonctions ecrire_jeu() et
# lire_jeu() du module `lecture` (#19). Exécuté par tests/test_unitaires.R : le package est
# installé et chargé, le harnais est sourcé, `racine` est défini. Les jeux sont ceux de
# tests/jeux_v1.R (définitions des jeux versionnés) ; la comparaison aux fichiers versionnés
# sous inst/extdata/jeux/ est dans tests/test_reproductibilite.R.

ns <- asNamespace("provie")
source(file.path(racine, "tests", "jeux_v1.R"), local = TRUE)
d <- dictionnaire()
motif_de <- function(expr) tryCatch({ expr; "aucun" }, refus_provie = function(e) e$motif,
                                    error = function(e) paste("autre :", conditionMessage(e)))
A <- DATE_EXTRACTION_V1
A0 <- as.Date("2024-12-31")

section("simulation : exports et catalogue")
verifier("simuler_base(), ecrire_jeu() et lire_jeu() sont exportés",
         all(c("simuler_base", "ecrire_jeu", "lire_jeu") %in% getNamespaceExports("provie")))
verifier("catalogue des défauts simulés : rangs 1..n, codes et paramètres du dictionnaire (§ 9)",
         identical(ns$DEFAUTS_SIMULES$rang, seq_len(nrow(ns$DEFAUTS_SIMULES))) &&
           all(sub("[a-z]$", "", ns$DEFAUTS_SIMULES$code) %in% sub("[a-z]$", "", d$defauts$code)) &&
           all(mapply(function(code, p) p == d$defauts$parametre_intensite[d$defauts$code == code],
                      ns$DEFAUTS_SIMULES$code, ns$DEFAUTS_SIMULES$parametre)) &&
           all(mapply(function(code, t) t %in% strsplit(d$defauts$tables[d$defauts$code == code], ";")[[1L]],
                      ns$DEFAUTS_SIMULES$code, ns$DEFAUTS_SIMULES$table)))

section("simulation : forme du jeu simulé (ADR 0010, point 19)")
set.seed(4242)
etat <- .Random.seed
j1 <- simuler_jeu_v1("v1-modeste-01")
verifier("simuler_base() restaure l'état du générateur de l'appelant", identical(.Random.seed, etat))
j2 <- simuler_jeu_v1("v1-modeste-02")
obligatoires <- d$tables$table[d$tables$obligatoire == "O"]
verifier("classe jeu_simule ; champs base, loi_vraie, verite, manifeste, declarations",
         inherits(j1, "jeu_simule") && identical(names(j1), c("base", "loi_vraie", "verite", "manifeste", "declarations")))
verifier("base : les tables obligatoires du dictionnaire, dans son ordre",
         identical(names(j1$base), obligatoires))
verifier("base : colonnes de chaque table dans l'ordre du dictionnaire",
         all(vapply(names(j1$base), function(t) identical(names(j1$base[[t]]), d$colonnes$colonne[d$colonnes$table == t]), NA)))
verifier("base : types conformes au dictionnaire (controler_types)", {
  controler_types(j1$base); controler_types(j2$base); TRUE
})
verifier("base : noms de lignes automatiques",
         all(vapply(c(j1$base, j2$base), function(df) identical(attr(df, "row.names"), seq_len(nrow(df))) ||
                      (nrow(df) == 0L), NA)))
verifier_egal("loi vraie portée telle quelle", j2$loi_vraie, loi_vraie_v1("v1-modeste-02"))
verifier_egal("verite : tables de ce que l'organisme ignore et registre",
              names(j1$verite), c("flux_futurs", "etats_vrais", "familles_vraies", "sinistres_non_declares", "defauts"))
verifier_egal("registre : colonnes du point 19", names(j2$verite$defauts),
              c("code", "parametre", "rang", "table", "cle", "colonne", "valeur_propre", "valeur_injectee"))
verifier("registre du jeu sans défaut : vide", nrow(j1$verite$defauts) == 0L)
verifier("registre de v1-modeste-02 : chaque défaut simulé au moins une fois",
         setequal(unique(j2$verite$defauts$code), ns$DEFAUTS_SIMULES$code))
verifier_egal("manifeste : champs dans l'ordre de l'ADR 0010, onzième série, (c)", names(j1$manifeste),
              c("nom", "version_dictionnaire", "version_provie", "version_simulateur", "graines", "date_extraction",
                "volumetrie", "description", "date_visa", "colonnes_verite"))
verifier("manifeste : version_simulateur = VERSION_SIMULATEUR (entier)",
         identical(j1$manifeste$version_simulateur, ns$VERSION_SIMULATEUR) && is.integer(ns$VERSION_SIMULATEUR))
verifier("schéma de la vérité : tables et types de SCHEMA_VERITE, copiés dans manifeste$colonnes_verite",
         identical(names(j2$verite), names(ns$SCHEMA_VERITE)) &&
           all(vapply(names(ns$SCHEMA_VERITE), function(t) {
             identical(names(j2$verite[[t]]), names(ns$SCHEMA_VERITE[[t]])) &&
               identical(unname(vapply(j2$verite[[t]], function(x) if (inherits(x, "Date")) "Date" else class(x), "")),
                         unname(ns$SCHEMA_VERITE[[t]]))
           }, NA)) &&
           identical(j2$manifeste$colonnes_verite, lapply(ns$SCHEMA_VERITE, as.list)) &&
           identical(names(ns$SCHEMA_VERITE$defauts), ns$COLONNES_REGISTRE))
ff <- j1$verite$flux_futurs
debut_arret <- tapply(as.numeric(j1$verite$etats_vrais$date_debut), j1$verite$etats_vrais$id_sinistre, min)
en_arret <- ff$id_sinistre %in% names(debut_arret)
verifier("flux_futurs : date_survenance égale au début de la trajectoire vraie de l'arrêt (etats_vrais)",
         all(as.numeric(ff$date_survenance[en_arret]) == debut_arret[ff$id_sinistre[en_arret]]))
apres <- ff$date_survenance > A
fin_etat <- j1$verite$etats_vrais[j1$verite$etats_vrais$etat == "eteint", , drop = FALSE]
verifier("flux_futurs : id_sinistre_origine NA pour un sinistre survenu, arrêt éteint à la survenance du décès sinon (R4)",
         all(is.na(ff$id_sinistre_origine[!apres])) && any(apres) && !anyNA(ff$id_sinistre_origine[apres]) &&
           all(mapply(function(o, d) any(fin_etat$id_sinistre == o & fin_etat$date_debut == d),
                      ff$id_sinistre_origine[apres], ff$date_survenance[apres])))
verifier("flux_futurs : décès survenus après l'extraction distingués (date_survenance > extraction, sinistre inconnu)",
         any(ff$date_survenance > A) && all(!ff$sinistre_connu[ff$date_survenance > A]) &&
           all(ff$code_garantie[ff$date_survenance > A] == "deces"))
# chaînes attendues marquées UTF-8 (sous une locale C, un littéral accentué du script ne l'est pas)
u8 <- function(x) { Encoding(x) <- "UTF-8"; x }
verifier_egal("format() : décomptes du jeu (nom, versions, visa, tables, registre par code, déclarations)",
              format(j2)[c(1L, 2L, 4L, 5L)],
              u8(c("jeu simulé v1-modeste-02 (extraction du 2025-12-31)",
                paste0("  dictionnaire 1.5, simulateur 1, provie ", j2$manifeste$version_provie, ", visa ",
                       if (is.na(j2$manifeste$date_visa)) "non renseigné" else format(j2$manifeste$date_visa)),
                paste0("  registre des défauts : ", nrow(j2$verite$defauts), " ligne(s) ; par code : D01b 4, D02a 4, ",
                       "D02b 3, D03a 11, D03b 6, D03c 11, D03g 1, D04b 4, D05 2, D06 3, D09 1, D13 4"),
                "  déclarations : declarations, conventions")))
verifier("format() : lignes de chaque table de la base",
         identical(format(j1)[3L], paste0("  base : ", paste(paste0(names(j1$base), " ", vapply(j1$base, nrow, 0L)),
                                                             collapse = ", "))))
sortie <- utils::capture.output(rendu <- withVisible(print(j1)))
verifier("print() imprime format() et rend le jeu, invisible",
         identical(sortie, utils::capture.output(cat(format(j1), sep = "\n"))) && identical(rendu$value, j1) &&
           !rendu$visible)
verifier("manifeste : volumétrie = nombre de lignes de chaque table",
         identical(j2$manifeste$volumetrie, lapply(j2$base, nrow)))
verifier("manifeste : graines et date d'extraction consignées",
         identical(j1$manifeste$graines, GRAINES_V1) && identical(j1$manifeste$date_extraction, A))
verifier("volumétrie modeste : quelques centaines d'assurés, quelques dizaines de sinistres",
         nrow(j1$base$assures) >= 100L && nrow(j1$base$assures) <= 1000L &&
           nrow(j1$base$sinistres) >= 20L && nrow(j1$base$sinistres) <= 200L)
verifier("portefeuille à garanties liées : décès, incapacité, invalidité sur chaque contrat",
         all(vapply(split(j1$base$garanties_souscrites$code_garantie, j1$base$garanties_souscrites$id_contrat),
                    function(x) setequal(x, c("deces", "incapacite", "invalidite")), NA)) &&
           setequal(unique(j1$base$sinistres$nature_sinistre), c("deces", "arret_travail")))
verifier_egal("deux tirages de mêmes entrées : identiques", simuler_jeu_v1("v1-modeste-01"), j1)

section("simulation : flux séparés et défauts indépendants (E4.9)")
# Jeu propre reconstitué du jeu à défauts et de son registre (valeurs propres ; lignes
# ajoutées retirées) : identique au jeu sans défaut tiré aux mêmes graines.
reconstituer <- function(base, registre) {
  for (k in seq_len(nrow(registre))) {
    r <- registre[k, ]
    t <- base[[r$table]]
    i <- which(t[[1L]] == r$cle)
    if (is.na(r$colonne)) next
    x <- t[[r$colonne]]
    propre <- if (is.na(r$valeur_propre)) x[NA_integer_] else
      switch(class(x)[1L], Date = as.Date(r$valeur_propre), numeric = as.numeric(r$valeur_propre),
             integer = as.integer(r$valeur_propre), logical = r$valeur_propre == "T", r$valeur_propre)
    base[[r$table]][[r$colonne]][i] <- propre
  }
  ajoutees <- registre[is.na(registre$colonne), , drop = FALSE]
  for (t in unique(ajoutees$table)) {
    garder <- !(base[[t]][[1L]] %in% ajoutees$cle[ajoutees$table == t])
    base[[t]] <- base[[t]][garder, , drop = FALSE]
    rownames(base[[t]]) <- NULL
  }
  base
}
verifier_egal("jeu propre de v1-modeste-02 (base et registre) = base de v1-modeste-01",
              reconstituer(j2$base, j2$verite$defauts), j1$base)
verifier("tables de vérité du jeu propre inchangées par les défauts",
         identical(j1$verite[1:4], j2$verite[1:4]))
te <- d$types_evenements
complet <- ns$.injecter_defauts(j1$base, j2$loi_vraie$defauts, GRAINES_V1$defauts, A, te)
verifier_egal("injection sur le jeu propre = jeu simulé (base et registre)",
              complet, list(base = j2$base, registre = j2$verite$defauts))
# Chaque défaut désactivé : les autres défauts (registre) inchangés, et la base ne diffère que
# par les cellules et lignes du défaut retiré (reconstituées).
independants <- vapply(ns$DEFAUTS_SIMULES$parametre, function(p) {
  intensites <- j2$loi_vraie$defauts
  intensites[[p]] <- 0
  sans <- ns$.injecter_defauts(j1$base, intensites, GRAINES_V1$defauts, A, te)
  reg <- complet$registre
  du_defaut <- reg$parametre == p
  attendu <- reg[!du_defaut, , drop = FALSE]
  rownames(attendu) <- NULL
  identical(sans$registre, attendu) && identical(sans$base, reconstituer(complet$base, reg[du_defaut, , drop = FALSE]))
}, NA)
verifier("désactiver un défaut ne change ni le jeu propre ni les autres défauts (douze défauts)", all(independants))
seul <- vapply(ns$DEFAUTS_SIMULES$parametre, function(p) {
  intensites <- lapply(j2$loi_vraie$defauts, function(x) 0)
  intensites[[p]] <- j2$loi_vraie$defauts[[p]]
  r <- ns$.injecter_defauts(j1$base, intensites, GRAINES_V1$defauts, A, te)$registre
  attendu <- complet$registre[complet$registre$parametre == p, , drop = FALSE]
  rownames(attendu) <- NULL
  identical(r, attendu)
}, NA)
verifier("activer un défaut seul rend ses lignes du registre complet (douze défauts)", all(seul))
# A8 : un paramètre du flux information (cadence de saisie des événements) ne change pas les
# sorties des flux amont (population, famille, sinistres)
lv_cad <- loi_vraie_v1("v1-modeste-01")
lv_cad$cadences$saisie_evenement <- 21
cad <- simuler_base(lv_cad, GRAINES_V1, A, nom = "v1-modeste-98", description = "essai")
verifier("flux séparés : une autre cadence de saisie ne change ni trajectoires, ni familles, ni population, ni cotisations",
         identical(cad$verite$etats_vrais, j1$verite$etats_vrais) &&
           identical(cad$verite$familles_vraies[, 1:4], j1$verite$familles_vraies[, 1:4]) &&
           identical(cad$base$assures, j1$base$assures) && identical(cad$base$affiliations, j1$base$affiliations) &&
           identical(cad$base$cotisations, j1$base$cotisations) &&
           identical(cad$base$sinistres$date_survenance, j1$base$sinistres$date_survenance) &&
           !identical(cad$base$evenements$date_saisie, j1$base$evenements$date_saisie))
g_info <- GRAINES_V1
g_info$information <- 1L
autre <- simuler_base(loi_vraie_v1("v1-modeste-01"), g_info, A, nom = "v1-modeste-99", description = "essai")
verifier("flux séparés : une autre graine d'information ne change ni les trajectoires vraies ni les familles",
         identical(autre$verite$etats_vrais, j1$verite$etats_vrais) &&
           identical(autre$verite$familles_vraies[, 1:4], j1$verite$familles_vraies[, 1:4]) &&
           identical(autre$base$cotisations, j1$base$cotisations) &&
           !identical(autre$base$sinistres$date_saisie, j1$base$sinistres$date_saisie))

section("simulation : refus d'appel")
lv <- loi_vraie_v1("v1-modeste-01")
sim <- function(loi = lv, graines = GRAINES_V1, date = A, nom = "v1-modeste-01") {
  simuler_base(loi, graines, date, nom = nom, description = "essai")
}
verifier_egal("loi vraie sans argument : jeu_invalide", motif_de(simuler_base(lv, GRAINES_V1, A)), "jeu_invalide")
verifier_egal("graine manquante : jeu_invalide", motif_de(sim(graines = GRAINES_V1[-1])), "jeu_invalide")
verifier_egal("graine non entière : jeu_invalide",
              motif_de(sim(graines = replace(GRAINES_V1, "famille", list(1.5)))), "jeu_invalide")
verifier_egal("nom hors de la forme <jalon>-<volumetrie>-<nn> : jeu_invalide", motif_de(sim(nom = "jeu 1")),
              "jeu_invalide")
verifier_egal("date d'extraction non Date : jeu_invalide", motif_de(sim(date = "2025-12-31")), "jeu_invalide")
verifier_egal("loi vraie d'une autre version : jeu_invalide", motif_de(sim(loi = replace(lv, "version", list(2L)))),
              "jeu_invalide")
sans_cadence <- lv
sans_cadence$cadences$instruction <- NULL
verifier_egal("feuille de la loi vraie absente (aucune valeur par défaut) : jeu_invalide",
              motif_de(sim(loi = sans_cadence)), "jeu_invalide")
inconnu <- lv
inconnu$defauts$suite_impossible <- 0
verifier_egal("paramètre d'un défaut non simulé : jeu_invalide", motif_de(sim(loi = inconnu)), "jeu_invalide")
hors <- lv
hors$defauts$orpheline <- 1.5
verifier_egal("intensité hors de [0 ; 1] : jeu_invalide", motif_de(sim(loi = hors)), "jeu_invalide")
manque <- lv
manque$defauts$orpheline <- NULL
verifier_egal("intensité non déclarée : jeu_invalide", motif_de(sim(loi = manque)), "jeu_invalide")
verifier_egal("declarations d'une entrée inconnue : jeu_invalide",
              motif_de(simuler_base(lv, GRAINES_V1, A, nom = "v1-modeste-01", description = "essai",
                                    declarations = list(seuils = list()))), "jeu_invalide")
verifier("declarations réduites aux conventions : admises (A1)",
         identical(simuler_base(lv, GRAINES_V1, A, nom = "v1-modeste-01", description = "essai",
                                declarations = list(conventions = list(age = "revolu")))$declarations,
                   list(conventions = list(age = "revolu"))))
verifier_egal("extraction avant le début de l'historique : jeu_invalide",
              motif_de(sim(date = as.Date("2017-12-31"))), "jeu_invalide")
# revue finale, m6 : contrôles d'entrée (erreurs non classées ou acceptation silencieuse avant) ;
# appels différés (fonctions), évalués un à un sous motif_de()
modifier <- function(chemin, valeur) {
  l <- lv
  l[[chemin]] <- valeur
  l
}
cas_m6 <- list(
  list("date d'extraction infinie", function() sim(date = structure(Inf, class = "Date"))),
  list("date d'extraction non entière", function() sim(date = A + 0.5)),
  list("cadence négative", function() sim(loi = modifier(c("cadences", "saisie_sinistre"), -30))),
  list("taux d'incidence négatif", function() sim(loi = modifier(c("tables", "incidence_arret", "taux"),
                                                                  -lv$tables$incidence_arret$taux))),
  list("taux de cotisation infini", function() sim(loi = modifier(c("garanties", "deces", "taux_cotisation"), Inf))),
  list("aucun contrat", function() sim(loi = modifier(c("portefeuille", "nombre_contrats"), 0L))),
  list("aucun assuré par contrat", function() sim(loi = modifier(c("portefeuille", "assures_par_contrat"), 0L))),
  list("âge d'entrée minimal supérieur au maximal",
       function() sim(loi = modifier(c("portefeuille", "age_entree_min"), 59))),
  list("âge d'entrée maximal non inférieur à l'âge de retraite",
       function() sim(loi = modifier(c("portefeuille", "age_entree_max"), 62))),
  list("arrondi du salaire nul", function() sim(loi = modifier(c("portefeuille", "salaire_arrondi"), 0))),
  list("clé inconnue dans la loi vraie", function() sim(loi = modifier(c("portefeuille", "coquille"), 1))),
  list("sous-liste vide inconnue dans la loi vraie", function() sim(loi = modifier("annexe", list()))))
for (k in cas_m6) verifier_egal(paste0(k[[1L]], " : jeu_invalide (revue finale, m6)"), motif_de(k[[2L]]()), "jeu_invalide")
# revue finale, C6 : effet du dernier contrat possible (début de l'historique + 23 mois, le
# 1er décembre 2019) postérieur à l'extraction : refus ; extraction à cette date : admise
verifier_egal("extraction avant l'effet du dernier contrat possible : jeu_invalide (revue finale, C6)",
              motif_de(sim(date = as.Date("2019-11-30"))), "jeu_invalide")
verifier("extraction à l'effet du dernier contrat possible : admise, aucun contrat d'effet postérieur",
         { j <- sim(date = as.Date("2019-12-01")); all(j$base$contrats$date_effet <= as.Date("2019-12-01")) })
# revue finale, C7 : uniformes d'invalidité (une par mois sur l'écart des âges plus un an) qui
# ne couvrent pas l'horizon en pas de 30 jours : refus (écart de 70 ans) ; 68 ans : admis
verifier_egal("écart de 70 ans entre âge d'entrée minimal et retraite : jeu_invalide (revue finale, C7)",
              motif_de(sim(loi = { l <- modifier(c("portefeuille", "age_entree_min"), 0)
                                   l$portefeuille$age_retraite <- 70L; l })), "jeu_invalide")
verifier("écart de 68 ans : admis",
         inherits(sim(loi = { l <- modifier(c("portefeuille", "age_entree_min"), 0)
                              l$portefeuille$age_retraite <- 68L; l }), "jeu_simule"))

section("simulation : tables vides et cas limites (revue finale, M2, C2 à C5, C10)")
# Types de la vérité conformes à SCHEMA_VERITE (simuler_base() le contrôle aussi) et de la base
# au dictionnaire, pour un jeu aux tables éventuellement vides.
types_ok <- function(j) {
  controler_types(j$base)
  all(vapply(names(ns$SCHEMA_VERITE), function(t) {
    identical(vapply(j$verite[[t]], ns$.type_colonne, ""), ns$SCHEMA_VERITE[[t]])
  }, NA))
}
debut <- lv$portefeuille$debut_historique
sans_decalage <- modifier(c("portefeuille", "decalage_effet_mois_max"), 0L)
for (k in c(1, 30, 180)) {
  j <- sim(loi = sans_decalage, date = debut + k)
  verifier(paste0("extraction au début de l'historique + ", k, " jours (effets au début) : jeu rendu, types conformes"),
           inherits(j, "jeu_simule") && types_ok(j))
}
j <- sim(loi = sans_decalage, date = debut + 1)
verifier("début de l'historique + 1 jour : aucun sinistre, événement, prestation ni cotisation (tables vides typées)",
         all(vapply(j$base[c("sinistres", "dossiers", "evenements", "prestations", "cotisations")], nrow, 0L) == 0L) &&
           nrow(j$verite$flux_futurs) == 0L && is.character(j$verite$flux_futurs$id_sinistre_origine))
nuls <- lv
nuls$tables$incidence_arret$taux[] <- 0
nuls$tables$mortalite$qx_femmes[] <- 0
nuls$tables$mortalite$qx_hommes[] <- 0
j <- sim(loi = nuls)
verifier("incidence et mortalité nulles : aucun sinistre, jeu rendu, types conformes (aucun flux futur)",
         nrow(j$base$sinistres) == 0L && nrow(j$verite$flux_futurs) == 0L && types_ok(j))
sans_cot <- lv
for (g in c("deces", "incapacite", "invalidite")) sans_cot$garanties[[g]]$taux_cotisation <- 0
j <- sim(loi = sans_cot)
verifier("taux de cotisation nuls : aucune cotisation émise, table vide typée",
         nrow(j$base$cotisations) == 0L && types_ok(j))
j <- sim(loi = modifier(c("portefeuille", "part_conjoint"), 0))
verifier("part_conjoint nulle : familles_vraies vide, id_membre en texte (revue finale, C3)",
         nrow(j$verite$familles_vraies) == 0L && is.character(j$verite$familles_vraies$id_membre) && types_ok(j))
certain <- lv
certain$tables$mortalite$qx_femmes[] <- 1
certain$tables$mortalite$qx_hommes[] <- 1
j <- sim(loi = certain)
verifier("qx = 1 : décès certain au premier pas d'activité, jeu rendu (revue finale, C5)",
         inherits(j, "jeu_simule") && all(j$base$sinistres$nature_sinistre == "deces") && types_ok(j))
# revue finale, C10 : encaissements datés de l'extraction (le 14 février : émission au 14e jour
# de la période annuelle, encaissement 30 jours après) non éligibles à D01b ; chaque copie est
# datée après son original
doublons <- lv
doublons$defauts$doublon_contenu <- 1
j <- sim(loi = doublons, date = as.Date("2021-02-14"))
co <- j$base$cotisations
reg <- j$verite$defauts[j$verite$defauts$code == "D01b", , drop = FALSE]
verifier("D01b : encaissements datés de l'extraction non copiés, chaque copie datée après l'original (revue finale, C10)",
         any(co$nature_mouvement == "encaissement" & co$date_mouvement == as.Date("2021-02-14")) && nrow(reg) > 0L &&
           !any(reg$valeur_injectee %in% co$id_cotisation[co$date_mouvement == as.Date("2021-02-14")]) &&
           all(co$date_mouvement[match(reg$cle, co$id_cotisation)] >
                 co$date_mouvement[match(reg$valeur_injectee, co$id_cotisation)]))

section("simulation : controler_base() accepte chaque jeu (critère 8)")
bilan_de <- function(j, arrete) {
  controler_base(j$base, arrete, j$declarations$declarations, j$declarations$conventions)
}
# Nombre de lignes injectées par (code, table) : identifiants distincts du registre.
injectees <- function(reg) {
  cles <- unique(reg[, c("code", "table", "cle")])
  tapply(cles$cle, paste(cles$code, cles$table), length)
}
for (arrete in list(A, A0)) {
  etiquette <- format(arrete)
  r1 <- bilan_de(j1, arrete)
  verifier(paste0("v1-modeste-01 à ", etiquette, " : aucun constat, aucune déclaration requise, vue définitive"),
           nrow(r1$controles) == 0L && nrow(r1$declarations_requises) == 0L && nrow(r1$refus_tables) == 0L &&
             !r1$vue$provisoire)
  verifier(paste0("v1-modeste-01 à ", etiquette, " : seuls non exécutés, les reports déclarés et D03h non lisible"),
           all(r1$controles_non_executes$cause %in% c("non_implemente", "non_lisible")))
  r2 <- bilan_de(j2, arrete)
  verifier(paste0("v1-modeste-02 à ", etiquette, " : jeu de contrôle, D09 refuse prestations.montant (seul refus)"),
           identical(r2$refus_tables[, c("table", "colonne", "motif")],
                     data.frame(table = "prestations", colonne = "montant", motif = "D09", stringsAsFactors = FALSE)))
  verifier(paste0("v1-modeste-02 à ", etiquette, " : aucune déclaration requise"), nrow(r2$declarations_requises) == 0L)
  reg <- j2$verite$defauts
  verifier(paste0("v1-modeste-02 à ", etiquette, " : chaque défaut injecté figure au bilan, aucun autre code"),
           setequal(paste(r2$controles$code, r2$controles$table), unique(paste(reg$code, reg$table))))
  # identifiants détectés : parmi les lignes injectées du même défaut
  inclus <- vapply(seq_len(nrow(r2$controles)), function(k) {
    ids <- strsplit(r2$controles$identifiants[k], ";", fixed = TRUE)[[1L]]
    all(ids %in% reg$cle[reg$code == r2$controles$code[k] & reg$table == r2$controles$table[k]])
  }, NA)
  verifier(paste0("v1-modeste-02 à ", etiquette, " : identifiants détectés parmi les lignes injectées"), all(inclus))
  n_inj <- injectees(reg)
  n_det <- tapply(r2$controles$nombre, paste(r2$controles$code, r2$controles$table), max)
  if (identical(arrete, A)) {
    verifier_egal("v1-modeste-02 à l'extraction : détection exacte = injection (spécification, § 2.5, critère 4)",
                  n_det[names(n_inj)], n_inj)
  } else {
    # règles B et P (base entière, indépendantes de l'arrêté) : exactes à tout arrêté ; règle V
    # (vue) : au plus les lignes injectées
    bp <- c("D02b prestations", "D02b evenements", "D03g prestations", "D04b cotisations", "D09 prestations")
    bp <- intersect(bp, names(n_inj))
    verifier_egal(paste0("v1-modeste-02 à ", etiquette, " : règles B et P exactes"), n_det[bp], n_inj[bp])
    verifier(paste0("v1-modeste-02 à ", etiquette, " : règle V, au plus les lignes injectées"),
             all(n_det[names(n_inj)] <= n_inj))
  }
}

# W8 (#40, précision P2) : sans déclaration au 2024-12-31, PR00027 (D03g) est non déterminée,
# hors de la population des règles V : aucune ligne de controles_non_executes pour son propre
# verdict (D02a sur prestations.fin_periode la détecte quand elle est visible) ; les autres
# lignes non exécutées sont celles du bilan avec déclarations, plus les seuils de D02c et la
# composante paiements_cumules de l'enjeu (inchangées à 325555f)
r_sans <- controler_base(j2$base, A0, conventions = j2$declarations$conventions)
r_avec <- bilan_de(j2, A0)
cles_ne <- function(r) with(r$controles_non_executes, paste(code, table, colonne, cause))
verifier_egal("W8 (#40) : v1-modeste-02 sans déclaration au 2024-12-31 : PR00027 non déterminée (D03g), aucune ligne (D02a, prestations) dans controles_non_executes ; lignes non exécutées = celles avec déclarations, plus D02c (declaration_absente) et paiements_cumules (D09, inchangé) ; D02a sur PR00039 seule",
              list(with(r_sans$vue$visibilite_non_determinee, identifiants[table == "prestations"]),
                   nrow(r_sans$controles_non_executes[r_sans$controles_non_executes$code == "D02a", ]),
                   setdiff(cles_ne(r_sans), cles_ne(r_avec)),
                   r_sans$controles$identifiants[r_sans$controles$code == "D02a"]),
              list("PR00027", 0L, c("D02c assures NA declaration_absente", "D02c famille NA declaration_absente",
                                    "paiements_cumules prestations montant D09"), "PR00039"))

section("lecture : ecrire_jeu() et lire_jeu() (ADR 0010, point 20)")
dossier <- tempfile("jeu-")
verifier("ecrire_jeu() rend le dossier, invisible", identical(withVisible(ecrire_jeu(j2, dossier))$visible, FALSE))
attendus <- c("base", "declarations.txt", "empreintes.md5", "loi_vraie.txt", "manifeste.txt", "verite")
verifier_egal("disposition : base/, verite/, loi_vraie.txt, manifeste.txt, empreintes.md5, declarations.txt",
              sort(list.files(dossier), method = "radix"), attendus)
verifier_egal("base/<table>.csv : une par table", sort(list.files(file.path(dossier, "base")), method = "radix"),
              sort(paste0(names(j2$base), ".csv"), method = "radix"))
verifier_egal("lire_jeu(ecrire_jeu(j)) identique à j", lire_jeu(dossier), j2)
md5 <- readLines(file.path(dossier, "empreintes.md5"))
fichiers <- substring(md5, 35L)
verifier("empreintes.md5 : une ligne « md5  chemin » par fichier, triées, MD5 exacts",
         all(grepl("^[0-9a-f]{32}  ", md5)) && identical(fichiers, sort(fichiers, method = "radix")) &&
           length(fichiers) == length(j2$base) + length(j2$verite) + 3L &&
           identical(substr(md5, 1L, 32L), unname(as.character(tools::md5sum(file.path(dossier, fichiers))))))
d1 <- tempfile("jeu-")
ecrire_jeu(j1, d1)
verifier_egal("jeu sans défaut : aller-retour identique", lire_jeu(d1), j1)
sans_dec <- j1
sans_dec$declarations <- NULL
d3 <- tempfile("jeu-")
ecrire_jeu(sans_dec, d3)
verifier("jeu sans déclarations : pas de declarations.txt, aller-retour identique",
         !file.exists(file.path(d3, "declarations.txt")) && identical(lire_jeu(d3), sans_dec))
verifier_egal("dossier non vide : fichier_invalide", motif_de(ecrire_jeu(j1, d1)), "fichier_invalide")
verifier_egal("objet qui n'est pas un jeu simulé : jeu_invalide", motif_de(ecrire_jeu(unclass(j1), tempfile())),
              "jeu_invalide")
mauvais <- j1
mauvais$manifeste$colonnes_verite$defauts$rang <- "character"
verifier_egal("types de verite non décrits par le manifeste : jeu_invalide", motif_de(ecrire_jeu(mauvais, tempfile())),
              "jeu_invalide")
vide <- j1
vide$verite$etats_vrais$etat[1L] <- ""
e <- tryCatch({ ecrire_jeu(vide, tempfile()); NULL }, refus_provie = function(e) e)
verifier("refus d'écriture d'une table de vérité : message préfixé « ecrire_jeu() : verite/<nom> » (audit m2)",
         !is.null(e) && startsWith(conditionMessage(e), "ecrire_jeu() : verite/etats_vrais : "))
copie <- function(source) {
  cible <- tempfile("jeu-")
  dir.create(cible)
  file.copy(list.files(source, full.names = TRUE), cible, recursive = TRUE)
  cible
}
altere <- copie(dossier)
x <- readBin(file.path(altere, "loi_vraie.txt"), "raw", n = file.info(file.path(altere, "loi_vraie.txt"))$size)
x[length(x) - 1L] <- as.raw(as.integer(x[length(x) - 1L]) %% 255L + 1L)
writeBin(x, file.path(altere, "loi_vraie.txt"))
verifier_egal("fichier altéré : empreinte_discordante", motif_de(lire_jeu(altere)), "empreinte_discordante")
intrus <- copie(dossier)
writeLines("x", file.path(intrus, "notes.txt"))
verifier_egal("fichier inconnu dans le jeu : fichier_invalide", motif_de(lire_jeu(intrus)), "fichier_invalide")
non_liste <- copie(dossier)
writeLines("x", file.path(non_liste, "verite", "autre.csv"))
verifier_egal("fichier de verite non listé dans empreintes.md5 : fichier_invalide", motif_de(lire_jeu(non_liste)),
              "fichier_invalide")
verifier_egal("dossier introuvable : fichier_invalide", motif_de(lire_jeu(tempfile())), "fichier_invalide")
# audit m1 : table de base/ retirée, empreintes recalculées : refus (manifeste$volumetrie)
reecrire_md5 <- function(dossier) {
  f <- sort(c(intersect(list.files(dossier), c("declarations.txt", "loi_vraie.txt", "manifeste.txt")),
              file.path("base", list.files(file.path(dossier, "base"))),
              file.path("verite", list.files(file.path(dossier, "verite")))), method = "radix")
  writeLines(paste0(unname(as.character(tools::md5sum(file.path(dossier, f)))), "  ", f), file.path(dossier, "empreintes.md5"))
}
sans_table <- copie(dossier)
unlink(file.path(sans_table, "base", "rentes.csv"))
reecrire_md5(sans_table)
verifier_egal("table de base/ retirée (empreintes recalculées) : fichier_invalide (audit m1)",
              motif_de(lire_jeu(sans_table)), "fichier_invalide")
ligne_en_moins <- copie(dossier)
x <- readLines(file.path(ligne_en_moins, "base", "cotisations.csv"))
writeLines(x[-length(x)], file.path(ligne_en_moins, "base", "cotisations.csv"))
reecrire_md5(ligne_en_moins)
verifier_egal("ligne retirée d'une table de base/ (empreintes recalculées) : fichier_invalide (audit m1)",
              motif_de(lire_jeu(ligne_en_moins)), "fichier_invalide")
# réserve m3 : volumétrie non entière dans le manifeste (empreintes recalculées) : refus propre,
# sans avertissement (options(warn = 2) des batteries)
vol_reel <- copie(dossier)
mf <- readLines(file.path(vol_reel, "manifeste.txt"), encoding = "UTF-8")
i_vol <- grep("^volumetrie/rentes\t", mf)
mf[i_vol] <- sub("\tinteger\t", "\tdouble\t", mf[i_vol])
writeBin(charToRaw(paste0(paste(mf, collapse = "\n"), "\n")), file.path(vol_reel, "manifeste.txt"))
reecrire_md5(vol_reel)
verifier_egal("volumétrie de type double dans le manifeste : fichier_invalide, sans avertissement (audit m3)",
              motif_de(lire_jeu(vol_reel)), "fichier_invalide")
verifier("témoin : empreintes recalculées sur un jeu intact, relu identique",
         { intact <- copie(dossier); reecrire_md5(intact); identical(lire_jeu(intact), j2) })
# revue finale, m3 : fichier caché dans verite/, listé dans empreintes.md5 : refusé, comme dans base/
reecrire_md5_tous <- function(dossier) {
  f <- sort(c(intersect(list.files(dossier), c("declarations.txt", "loi_vraie.txt", "manifeste.txt")),
              file.path("base", list.files(file.path(dossier, "base"), all.files = TRUE, no.. = TRUE)),
              file.path("verite", list.files(file.path(dossier, "verite"), all.files = TRUE, no.. = TRUE))),
            method = "radix")
  writeLines(paste0(unname(as.character(tools::md5sum(file.path(dossier, f)))), "  ", f), file.path(dossier, "empreintes.md5"))
}
for (cache in c(".cache.csv", ".cache")) {
  cache_verite <- copie(dossier)
  writeLines("x", file.path(cache_verite, "verite", cache))
  reecrire_md5_tous(cache_verite)
  verifier_egal(paste0("fichier caché verite/", cache, " (empreintes recalculées) : fichier_invalide (revue finale, m3)"),
                motif_de(lire_jeu(cache_verite)), "fichier_invalide")
}
cache_base <- copie(dossier)
writeLines("x", file.path(cache_base, "base", ".cache"))
reecrire_md5_tous(cache_base)
verifier_egal("témoin : fichier caché base/.cache (empreintes recalculées) : fichier_invalide",
              motif_de(lire_jeu(cache_base)), "fichier_invalide")
# revue finale, m4 : refus d'ecrire_base() (chaîne vide) avant la création du dossier
chaine_vide <- j1
chaine_vide$base$contrats$gestionnaire[1L] <- ""
d4 <- tempfile("jeu-")
verifier("chaîne vide dans la base : refusée, aucun dossier créé (revue finale, m4)",
         motif_de(ecrire_jeu(chaine_vide, d4)) == "liste_invalide" && !file.exists(d4))
# revue finale, m5 : jeux que lire_jeu() ne relirait pas identiques, refusés avant écriture
vol_faux <- j1
vol_faux$manifeste$volumetrie$contrats <- 99L
ordre_faux <- j1
ordre_faux$base <- rev(ordre_faux$base)
dec_null <- unclass(j1)
dec_null["declarations"] <- list(NULL)
class(dec_null) <- "jeu_simule"
for (k in list(list("volumétrie incohérente", vol_faux), list("tables hors de l'ordre du dictionnaire", ordre_faux),
               list("declarations NULL explicite", dec_null))) {
  d5 <- tempfile("jeu-")
  verifier(paste0("ecrire_jeu() : ", k[[1L]], " : jeu_invalide, aucun dossier créé (revue finale, m5)"),
           motif_de(ecrire_jeu(k[[2L]], d5)) == "jeu_invalide" && !file.exists(d5))
}
# audit des corrections finales, n2 : table (base ou verite) à noms de lignes non automatiques ou
# à attribut que lire_jeu() ne relit pas : jeu_invalide avant toute écriture, message qui nomme
# la table (et la colonne) ; le dossier de destination, existant et vide, le reste
rn_base <- j2
rownames(rn_base$base$contrats) <- paste0("r", seq_len(nrow(rn_base$base$contrats)))
rn_verite <- j2
rn_verite$verite$etats_vrais <- rn_verite$verite$etats_vrais[rev(seq_len(nrow(rn_verite$verite$etats_vrais))), ]
at_base <- j2
attr(at_base$base$contrats$id_contrat, "note") <- "a"
at_verite <- j2
attr(at_verite$verite$etats_vrais$etat, "note") <- "a"
at_table <- j2
attr(at_table$base$contrats, "note") <- "a"
for (k in list(list("noms de lignes de la base", rn_base, "base/contrats"),
               list("noms de lignes de la vérité", rn_verite, "verite/etats_vrais"),
               list("attribut de colonne de la base", at_base, "base/contrats, colonne id_contrat"),
               list("attribut de colonne de la vérité", at_verite, "verite/etats_vrais, colonne etat"),
               list("attribut de table de la base", at_table, "base/contrats"))) {
  d6 <- tempfile("jeu-")
  dir.create(d6)
  e <- tryCatch({ ecrire_jeu(k[[2L]], d6); NULL }, refus_provie = function(e) e)
  verifier(paste0("ecrire_jeu() : ", k[[1L]], " : jeu_invalide nommant la table, aucun fichier écrit (audit n2)"),
           !is.null(e) && identical(e$motif, "jeu_invalide") && grepl(paste0("table ", k[[3L]]), conditionMessage(e), fixed = TRUE) &&
             length(list.files(d6, all.files = TRUE, no.. = TRUE)) == 0L)
}
sans_nom <- j2
attr(sans_nom$base$contrats, "row.names") <- seq_len(nrow(sans_nom$base$contrats))
d7 <- tempfile("jeu-")
verifier("témoin : noms de lignes 1..n posés explicitement (identiques à la relecture) : écrit, relu identique",
         { ecrire_jeu(sans_nom, d7); identical(lire_jeu(d7), j2) })
# audit des corrections finales, m1 : attribut du jeu, de la liste base ou de la liste verite, ou
# classe étendue : jeu_invalide avant toute écriture, message qui nomme l'élément, dossier
# existant resté vide
at_liste_base <- j2
attr(at_liste_base$base, "note") <- "x"
at_liste_verite <- j2
attr(at_liste_verite$verite, "note") <- "x"
at_jeu <- j2
attr(at_jeu, "note") <- "x"
classe_etendue <- j2
class(classe_etendue) <- c("autre", "jeu_simule")
for (k in list(list("attribut de la liste base", at_liste_base, "liste base"),
               list("attribut de la liste verite", at_liste_verite, "liste verite"),
               list("attribut du jeu", at_jeu, "attribut du jeu"),
               list("classe du jeu étendue", classe_etendue, "classe jeu_simule seule"))) {
  d8 <- tempfile("jeu-")
  dir.create(d8)
  e <- tryCatch({ ecrire_jeu(k[[2L]], d8); NULL }, refus_provie = function(e) e)
  verifier(paste0("ecrire_jeu() : ", k[[1L]], " : jeu_invalide nommant l'élément, aucun fichier écrit (audit m1)"),
           !is.null(e) && identical(e$motif, "jeu_invalide") && grepl(k[[3L]], conditionMessage(e), fixed = TRUE) &&
             length(list.files(d8, all.files = TRUE, no.. = TRUE)) == 0L)
}
# attribut de loi_vraie, de manifeste ou de declarations : déjà refusé par ecrire_liste(), avant écriture
for (champ in c("loi_vraie", "manifeste", "declarations")) {
  porte <- j2
  attr(porte[[champ]], "note") <- "x"
  d9 <- tempfile("jeu-")
  verifier(paste0("ecrire_jeu() : attribut de ", champ, " : liste_invalide (ecrire_liste()), aucun dossier créé (audit m1)"),
           motif_de(ecrire_jeu(porte, d9)) == "liste_invalide" && !file.exists(d9))
}

section("simulation : loi vraie version 2 et jeu v1-modeste-03 (#69 ; spécification de B2, § 7.9.2 et § 7.9.7, J.1 à J.5)")
lv3 <- LOI_VRAIE_V1_03
G3 <- GRAINES_V1_03
sim3 <- function(loi = lv3, graines = G3, date = A) simuler_base(loi, graines, date, nom = "v1-modeste-03", description = "essai")
avec <- function(l, chemin, valeur) { l[[strsplit(chemin, "/", fixed = TRUE)[[1L]]]] <- valeur; l }
# J.1 : version du simulateur inchangée, version 1 lue (identité des jeux 01 et 02 :
# tests/test_reproductibilite.R)
verifier("J.1 : VERSION_SIMULATEUR vaut 1, VERSION_LOI_VRAIE vaut 2 ; une loi de version 1 est lue",
         identical(ns$VERSION_SIMULATEUR, 1L) && identical(ns$VERSION_LOI_VRAIE, 2L) && inherits(j1, "jeu_simule") &&
           identical(j1$loi_vraie$version, 1L))
# J.2 : contrôles de la version 2, un témoin par refus
chemins_v2 <- vapply(ns$.SCHEMA_LOI_VRAIE_V2, `[`, "", 1L)
absente <- vapply(chemins_v2, function(ch) {
  l <- lv3
  parties <- strsplit(ch, "/", fixed = TRUE)[[1L]]
  l[[parties]] <- NULL
  motif_de(sim3(loi = l)) == "jeu_invalide"
}, NA)
verifier(paste0("J.2 : chaque clé nouvelle est exigée (", length(chemins_v2), " clés, aucune valeur par défaut) : jeu_invalide"),
         all(absente))
cas_j2 <- list(
  list("version 3", function() sim3(loi = avec(lv3, "version", 3L))),
  list("individuels/part_femmes > 1", function() sim3(loi = avec(lv3, "individuels/part_femmes", 1.5))),
  list("individuels/part_conjoint > 1", function() sim3(loi = avec(lv3, "individuels/part_conjoint", 1.01))),
  list("individuels/part_prime_unique > 1", function() sim3(loi = avec(lv3, "individuels/part_prime_unique", 2))),
  list("individuels/part_trimestrielle > 1", function() sim3(loi = avec(lv3, "individuels/part_trimestrielle", 1.2))),
  list("suites_deces/part_non_reclames > 1", function() sim3(loi = avec(lv3, "suites_deces/part_non_reclames", 1.1))),
  list("suites_deces/part_fixation_differee négative", function() sim3(loi = avec(lv3, "suites_deces/part_fixation_differee", -0.1))),
  list("individuels/taux_resiliation négatif", function() sim3(loi = avec(lv3, "individuels/taux_resiliation", -0.04))),
  list("individuels/nombre_contrats non entier", function() sim3(loi = avec(lv3, "individuels/nombre_contrats", 200))),
  list("durées de prime unique min > max", function() sim3(loi = avec(lv3, "individuels/duree_prime_unique_min", 11L))),
  list("durées périodiques min > max", function() sim3(loi = avec(lv3, "individuels/duree_periodique_max", 9L))),
  list("durée minimale nulle", function() sim3(loi = avec(lv3, "individuels/duree_prime_unique_min", 0L))),
  list("âges de souscription min > max", function() sim3(loi = avec(lv3, "individuels/age_souscription_min", 61))),
  list("âge de souscription maximal non inférieur à l'âge de fin de garantie",
       function() sim3(loi = avec(lv3, "individuels/age_fin_garantie", 60))),
  list("âge de souscription maximal à moins de 28 jours de l'âge de fin de garantie (décalage de naissance tiré)",
       function() sim3(loi = avec(lv3, "individuels/age_souscription_max", 70 - 27 / 365.25))),
  list("capitaux contenant NA", function() sim3(loi = avec(lv3, "individuels/capitaux", c(50000, NA, 300000)))),
  list("paliers du taux du tarif non croissants",
       function() sim3(loi = avec(lv3, "individuels/taux_tarif/annee", c(2016L, 2023L, 2020L)))),
  list("paliers du taux du tarif de longueurs différentes",
       function() sim3(loi = avec(lv3, "individuels/taux_tarif/taux", c(0.015, 0.005)))),
  list("premier palier postérieur à l'année du début de l'historique",
       function() sim3(loi = avec(lv3, "individuels/taux_tarif/annee", c(2017L, 2020L, 2023L)))),
  list("periode_cotisation hors liste fermée", function() sim3(loi = avec(lv3, "garanties/periode_cotisation", "mensuelle"))),
  list("dernière souscription postérieure à l'extraction",
       function() sim3(loi = avec(lv3, "individuels/derniere_souscription", as.Date("2026-01-01")))),
  list("dernière souscription antérieure au début de l'historique",
       function() sim3(loi = avec(lv3, "individuels/derniere_souscription", as.Date("2015-12-01")))),
  list("clé nouvelle (garanties/periode_cotisation) dans une loi de version 1",
       function() sim(loi = avec(lv, "garanties/periode_cotisation", "civile"))),
  list("section nouvelle (suites_deces) dans une loi de version 1", function() sim(loi = c(lv, list(suites_deces = lv3$suites_deces)))),
  list("graines de la version 1 pour une loi de version 2", function() sim3(graines = GRAINES_V1)),
  list("graines de la version 2 pour une loi de version 1", function() sim(graines = G3)))
for (k in cas_j2) verifier_egal(paste0("J.2 : ", k[[1L]], " : jeu_invalide"), motif_de(k[[2L]]()), "jeu_invalide")
verifier("J.2 : témoin : periode_cotisation civile, aucun contrat individuel, parts des suites nulles : admis",
         inherits(sim3(loi = { l <- avec(lv3, "garanties/periode_cotisation", "civile")
                               l <- avec(l, "individuels/nombre_contrats", 0L)
                               avec(l, "suites_deces/part_non_reclames", 0) }), "jeu_simule"))

j3 <- simuler_jeu_v1("v1-modeste-03")
b3 <- j3$base
# J.3 : indépendance des flux. Lignes collectives (préfixes CT, GS, AS) comparées hors des
# identifiants en numérotation commune (sinistres, événements, prestations, cotisations) ; un
# sinistre y est désigné par (assuré, survenance, nature).
collectif <- function(b) {
  cle_sin <- function(id) {
    s <- b$sinistres[match(id, b$sinistres$id_sinistre), ]
    paste(s$id_assure, s$date_survenance, s$nature_sinistre)
  }
  tri <- function(df) { df <- df[do.call(order, c(unname(lapply(df, as.character)), method = "radix")), , drop = FALSE]
                        rownames(df) <- NULL; df }
  s <- b$sinistres[startsWith(b$sinistres$id_assure, "AS"), ]
  ds <- b$dossiers[b$dossiers$id_sinistre %in% s$id_sinistre, ]
  ev <- b$evenements[b$evenements$id_sinistre %in% s$id_sinistre, setdiff(names(b$evenements), "id_evenement")]
  ev$id_sinistre <- cle_sin(ev$id_sinistre)
  pr <- b$prestations[b$prestations$id_dossier %in% ds$id_dossier, setdiff(names(b$prestations), "id_prestation")]
  ds$id_sinistre <- cle_sin(ds$id_sinistre)
  s$cle <- cle_sin(s$id_sinistre)
  fa <- b$famille[startsWith(b$famille$id_assure, "AS"), ]
  fa$id_sinistre <- cle_sin(fa$id_sinistre)
  list(contrats = b$contrats[startsWith(b$contrats$id_contrat, "CT"), ],
       garanties = b$garanties_souscrites[startsWith(b$garanties_souscrites$id_garantie_souscrite, "GS"), ],
       parametres = b$parametres[startsWith(b$parametres$id_garantie_souscrite, "GS"), ],
       assures = b$assures[startsWith(b$assures$id_assure, "AS"), ], affiliations = b$affiliations,
       famille = tri(fa),
       sinistres = tri(s[, setdiff(names(s), "id_sinistre")]), dossiers = tri(ds), evenements = tri(ev), prestations = tri(pr),
       beneficiaires = b$beneficiaires[b$beneficiaires$id_dossier %in% ds$id_dossier, ],
       cotisations = tri(b$cotisations[startsWith(b$cotisations$id_garantie_souscrite, "GS"),
                                       setdiff(names(b$cotisations), "id_cotisation")]))
}
g_ind <- G3
g_ind$individuels <- 1L
autre_ind <- sim3(graines = g_ind)
etats_sans_id <- function(j) {
  e <- j$verite$etats_vrais[, -1L]
  e <- e[do.call(order, c(unname(lapply(e, as.character)), method = "radix")), ]
  rownames(e) <- NULL
  e
}
verifier("J.3 : une autre graine individuels ne change aucune ligne collective (hors identifiants en numérotation commune), ni etats_vrais",
         identical(collectif(autre_ind$base), collectif(b3)) && identical(etats_sans_id(autre_ind), etats_sans_id(j3)) &&
           !identical(autre_ind$base$contrats, b3$contrats))
g_sd <- G3
g_sd$suites_deces <- 1L
autre_sd <- sim3(graines = g_sd)
hors_suites <- function(b) {
  dd <- b$dossiers$id_dossier[b$dossiers$id_sinistre %in% b$sinistres$id_sinistre[b$sinistres$nature_sinistre == "deces"]]
  ev <- b$evenements[!(b$evenements$id_dossier %in% dd & b$evenements$type_evenement %in% c("fixation_capital", "cloture_dossier")),
                     setdiff(names(b$evenements), "id_evenement")]
  pr <- b$prestations[b$prestations$type_prestation != "capital", setdiff(names(b$prestations), "id_prestation")]
  rownames(ev) <- NULL
  rownames(pr) <- NULL
  c(b[c("extraction", "adherents", "contrats", "garanties_souscrites", "parametres", "assures", "affiliations", "famille",
        "sinistres", "dossiers", "rentes", "cotisations")],
    list(evenements = ev, prestations = pr, beneficiaires = b$beneficiaires[, c("id_beneficiaire", "id_dossier")]))
}
verifier(paste0("J.3 : une autre graine suites_deces ne change que les qualités de bénéficiaires, les fixations, les ",
                "prestations capital et les clôtures des décès (et la vérité de leurs flux)"),
         identical(hors_suites(autre_sd$base), hors_suites(b3)) &&
           identical(autre_sd$verite[c("etats_vrais", "familles_vraies", "sinistres_non_declares")],
                     j3$verite[c("etats_vrais", "familles_vraies", "sinistres_non_declares")]) &&
           !identical(autre_sd$base$beneficiaires, b3$beneficiaires))
# J.4 : additivité, loi de v1-modeste-01 en version 2 aux valeurs neutres
neutre <- loi_vraie_v1("v1-modeste-01")
neutre$version <- 2L
neutre$garanties$periode_cotisation <- "civile"
neutre$garanties$deces$majoration_conjoint <- 0
neutre$individuels <- lv3$individuels
neutre$individuels$nombre_contrats <- 0L
neutre$individuels$derniere_souscription <- neutre$portefeuille$debut_historique
neutre$individuels$taux_tarif$annee <- c(2018L, 2020L, 2023L)
neutre$suites_deces <- list(part_non_reclames = 0, part_fixation_differee = 0, delai_fixation_differee = 1095)
g_neutre <- c(GRAINES_V1[c("population", "famille", "sinistres", "information")], list(individuels = 1L, suites_deces = 2L),
              GRAINES_V1["defauts"])
jn <- simuler_base(neutre, g_neutre, A, nom = "v1-modeste-01", description = j1$manifeste$description)
verifier("J.4 : loi de v1-modeste-01 en version 2 aux valeurs neutres : base et vérité identical à celles de v1-modeste-01",
         identical(jn$base, j1$base) && identical(jn$verite, j1$verite))
# J.5 : deux appels identiques ; aller-retour exact
verifier_egal("J.5 : deux tirages de v1-modeste-03 : identiques", simuler_jeu_v1("v1-modeste-03"), j3)
d3b <- tempfile("jeu-")
verifier_egal("J.5 : lire_jeu(ecrire_jeu(v1-modeste-03)) identique", lire_jeu(ecrire_jeu(j3, d3b)), j3)
# B1 (audit) : description du jeu, de sa loi vraie et statut sans octet écrit en clair (`<c3>`),
# signe d'un paste() de chaînes d'encodages mêlés sous une locale C
octets_clairs <- function(x) grepl("<[0-9a-f]{2}>", x)
verifier("descriptions des jeux, de leurs lois vraies et statuts : aucun motif <xx> (octet écrit en clair)",
         !any(vapply(names(JEUX_V1), function(n) {
           j <- if (n == "v1-modeste-03") j3 else if (n == "v1-modeste-01") j1 else j2
           any(octets_clairs(c(j$manifeste$description, j$loi_vraie$description, j$loi_vraie$statut)))
         }, NA)))
verifier("v1-modeste-03 : contrats individuels à prime unique, annuelle et trimestrielle ; majoration du conjoint ; capitaux non réclamés",
         setequal(b3$garanties_souscrites$periodicite_cotisation[startsWith(b3$garanties_souscrites$id_garantie_souscrite, "GI")],
                  c("unique", "annuelle", "trimestrielle")) &&
           any(b3$parametres$parametre == "majoration_conjoint") && any(b3$beneficiaires$qualite == "non_identifie"))

section("jeu v1-modeste-03 : critères de visa V.1 à V.7 (spécification de B2, § 7.9.7 ; M188)")
source(file.path(racine, "tests", "b2_bases.R"), local = TRUE)
tb3 <- b2_tables_v1_03()
verifier_egal("tables fictives des plans des jeux : empreintes du § 3.6 (m15)",
              c(tb3$mortalite_tarif$origine$empreinte, tb3$serie_tme$origine$empreinte),
              c("4eb68f9af5835cad25255f14232f5df0", "a5b4c1cf5cf86afc6ac166504fe808d7"))
cat_g3 <- catalogue_garanties()
P1 <- "sinistres_declares_non_regles"
P2 <- "capitaux_non_reclames"
P3 <- "provision_mathematique_temporaire_deces"
calcul3 <- list()
for (arrete in list(A0, A)) {
  et_a <- format(arrete)
  bil <- controler_base(b3, arrete, j3$declarations$declarations, j3$declarations$conventions)
  verifier(paste0("V.1 à ", et_a, " : declarations_requises, refus_tables et visibilités non déterminées vides ; registre vide"),
           nrow(bil$declarations_requises) == 0L && nrow(bil$refus_tables) == 0L &&
             nrow(bil$vue$visibilite_non_determinee) == 0L && nrow(j3$verite$defauts) == 0L)
  plan <- valider_plan(plan_reference_jeu(j3, arrete, tb3))
  vue <- ns$vue_a_date(b3, arrete, plan$donnees, plan$conventions)
  r1 <- ns$calculer_engagement(vue, plan, tb3, cat_g3, "deces", P1)
  r2 <- ns$calculer_engagement(vue, plan, tb3, cat_g3, "deces", P2)
  r3 <- ns$calculer_risque_en_cours(vue, plan, tb3, cat_g3, "deces", P3)
  cel <- rbind(r1$cellules, r2$cellules, r3$cellules)
  verifier(paste0("V.2 à ", et_a, " : P1, P2 et P3 calculés, de montant > 0"),
           identical(cel$statut_calcul, rep("calcule", 3L)) && all(cel$montant > 0))
  et <- ns$etats_a_date(vue, "deces", "engagement")
  e1 <- et[match(r1$dossiers$id_dossier, et$id_dossier), ]
  gs1 <- b3$dossiers$id_garantie_souscrite[match(e1$id_dossier, b3$dossiers$id_dossier)]
  ind <- ns$provisions_individuelles(vue, plan, tb3, FALSE)$contrats
  nat <- b3$garanties_souscrites$periodicite_cotisation[match(ind$id_garantie_souscrite, b3$garanties_souscrites$id_garantie_souscrite)]
  co <- b3$cotisations[b3$cotisations$nature_mouvement == "emission" & b3$cotisations$date_mouvement <= arrete &
                         b3$cotisations$fin_periode > arrete &
                         b3$cotisations$id_garantie_souscrite %in%
                           b3$garanties_souscrites$id_garantie_souscrite[b3$garanties_souscrites$code_garantie == "deces" &
                                                                           startsWith(b3$garanties_souscrites$id_contrat, "CT")], ]
  non_civile <- format(co$debut_periode, "%m-%d") != "01-01" | format(co$fin_periode, "%m-%d") != "12-31"
  # V.3 sans la clause P1 capital_du (erratum v1.0.11) ; indicateur non bloquant à la place :
  # dossiers de P1 capital_du payés (prestation capital réglée au plus l'arrêté) et non payés
  du <- e1$id_dossier[e1$etat_dossier == "capital_du"]
  paye_du <- du %in% b3$prestations$id_dossier[b3$prestations$type_prestation == "capital" &
                                                 b3$prestations$date_reglement <= arrete]
  cat(sprintf("    [INDICATEUR] v1-modeste-03 à %s : dossiers de P1 capital_du payés / non payés : %d / %d\n", et_a,
              sum(paye_du), sum(!paye_du)))
  verifier(paste0("V.3 à ", et_a, " : >= 1 dossier de P2 ; >= 1 dossier de P1 ouvert ",
                  "d'un contrat collectif ; P3 individuel : chaque nature valorisée ; P3 collectif > 0, d'une période non civile"),
           nrow(r2$dossiers) >= 1L && any(e1$etat_dossier == "ouvert" & startsWith(gs1, "GS")) &&
             all(c("unique", "annuelle", "trimestrielle") %in% nat) &&
             sum(ns$provisions_collectives(vue, plan)$montant) > 0 && any(non_civile))
  # V.4 : affiliation visible à l'arrêté (saisie, et fin si sa saisie l'est) couvrant la survenance
  ouv <- et[et$etat_dossier == "ouvert", ]
  ct_o <- b3$garanties_souscrites$id_contrat[match(b3$dossiers$id_garantie_souscrite[match(ouv$id_dossier, b3$dossiers$id_dossier)],
                                                   b3$garanties_souscrites$id_garantie_souscrite)]
  col <- startsWith(ct_o, "CT")
  af <- b3$affiliations[b3$affiliations$date_saisie <= arrete, ]
  af_fin <- ifelse(!is.na(af$date_saisie_fin) & af$date_saisie_fin <= arrete, as.numeric(af$date_fin), Inf)
  as_o <- b3$sinistres$id_assure[match(ouv$id_sinistre, b3$sinistres$id_sinistre)]
  couvre <- mapply(function(a, ct, s) sum(af$id_assure == a & af$id_contrat == ct & af$date_debut <= s & af_fin >= as.numeric(s)),
                   as_o[col], ct_o[col], ouv$date_entree_etat[col])
  verifier(paste0("V.4 à ", et_a, " : chaque dossier collectif ouvert a une affiliation qui couvre sa survenance"),
           any(col) && all(couvre == 1L))
  # V.5 : capital_du sans paiement à l'arrêté : montant fixé = vérité (règlement futur ou dépôt,
  # ou règlement de la base entre l'arrêté et l'extraction)
  cd <- et[et$etat_dossier == "capital_du", ]
  cap <- b3$prestations[b3$prestations$type_prestation == "capital", ]
  cd <- cd[!(cd$id_dossier %in% cap$id_dossier[cap$date_reglement <= arrete]), ]
  vrai <- j3$verite$flux_futurs$montant[match(cd$id_dossier, j3$verite$flux_futurs$id_dossier)]
  vrai[is.na(vrai)] <- cap$montant[match(cd$id_dossier[is.na(vrai)], cap$id_dossier)]
  verifier(paste0("V.5 à ", et_a, " : dossiers capital_du sans paiement : montant fixé = montant de vérité"),
           nrow(cd) >= 1L && identical(cd$montant_en_vigueur, vrai))
  # V.6 : contrat individuel en cours à l'arrêté hors décès, exclu de P3 par un décès connu ;
  # contrat individuel de fin connue
  ci <- b3$contrats[b3$contrats$nature_contrat == "individuel", ]
  fin_age <- ns$date_atteinte_age(b3$assures$date_naissance[match(ci$id_assure, b3$assures$id_assure)], 70L, "revolu")
  morts <- b3$sinistres$id_assure[b3$sinistres$date_saisie <= arrete & b3$sinistres$date_survenance <= arrete]
  exclus <- ci$id_contrat[ci$id_assure %in% morts & pmin(as.numeric(ci$date_terme), as.numeric(fin_age)) > arrete]
  verifier(paste0("V.6 à ", et_a, " : >= 1 contrat individuel exclu de P3 par un décès ; >= 1 contrat de fin connue"),
           length(exclus) >= 1L && !any(exclus %in% ind$id_contrat) &&
             any(!is.na(ci$date_fin) & ci$date_saisie_fin <= arrete & ci$date_fin <= arrete))
  calcul3[[et_a]] <- list(r2 = r2, et = et)
}
# V.7 : P2 au 2025-12-31 recalculé par une voie indépendante : capital fixé (dernier
# fixation_capital) ou, pour un dossier ouvert, capital reconstitué (forfaitaire ; sinon taux du
# capital x salaire de l'affiliation + majoration du conjoint si la famille rattachée au sinistre
# en porte un, sinistre instruit) x F(survenance, A) (prorata simple par année civile, jours
# exacts, taux_par_annee du plan) x 1,01 (chargement)
taux3 <- c(`2016` = 0.02, `2017` = 0.02, `2018` = 0.02, `2019` = 0.02, `2020` = 0.02, `2021` = 0.01, `2022` = 0.01,
           `2023` = 0.0167, `2024` = 0.03, `2025` = 0.03)
facteur3 <- function(s, a) {
  f <- 1
  for (y in as.integer(format(s, "%Y")):as.integer(format(a, "%Y"))) {
    fin_an <- as.numeric(as.Date(sprintf("%d-12-31", y)))
    jours_an <- fin_an - as.numeric(as.Date(sprintf("%d-12-31", y - 1L)))
    part <- min(as.numeric(a), fin_an) - max(as.numeric(s), fin_an - jours_an)
    if (part > 0) f <- f * (1 + taux3[[as.character(y)]] * part / jours_an)
  }
  f
}
d2 <- calcul3[[format(A)]]$r2$dossiers
param3 <- function(gs, nom) { k <- b3$parametres$id_garantie_souscrite == gs & b3$parametres$parametre == nom
                               if (any(k)) b3$parametres$valeur[k] else 0 }
capital3 <- vapply(d2$id_dossier, function(d) {
  fx <- b3$evenements[b3$evenements$id_dossier %in% d & b3$evenements$type_evenement == "fixation_capital", ]
  if (nrow(fx)) return(fx$montant[order(fx$date_effet, decreasing = TRUE)[1L]])
  gs <- b3$dossiers$id_garantie_souscrite[b3$dossiers$id_dossier == d]
  if (param3(gs, "capital_forfaitaire") > 0) return(param3(gs, "capital_forfaitaire"))
  s <- b3$sinistres[b3$sinistres$id_sinistre == b3$dossiers$id_sinistre[b3$dossiers$id_dossier == d], ]
  ct <- b3$garanties_souscrites$id_contrat[b3$garanties_souscrites$id_garantie_souscrite == gs]
  af <- b3$affiliations[b3$affiliations$id_assure == s$id_assure & b3$affiliations$id_contrat == ct, ]
  conjoint <- if (!is.na(s$date_instruction)) any(b3$famille$id_sinistre %in% s$id_sinistre & b3$famille$lien == "conjoint") else 0.55
  af$salaire_reference * (param3(gs, "taux_capital") + param3(gs, "majoration_conjoint") * conjoint)
}, 0)
attendu3 <- capital3 * mapply(facteur3, d2$date_entree_etat, A) * 1.01
verifier("V.7 : chaque dossier de P2 au 2025-12-31 = capital x F(survenance, A) x 1,01, recalculé par une voie indépendante (1e-10 relatif)",
         nrow(d2) >= 1L && isTRUE(all.equal(unname(d2$montant), unname(attendu3), tolerance = 1e-10)) &&
           max(abs(d2$montant / attendu3 - 1)) < 1e-10)
