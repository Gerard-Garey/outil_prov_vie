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
