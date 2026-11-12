# Tests unitaires du module `tables` (R/tables.R) et de lire_table() (module `lecture`) ;
# spécification de B2, § 3 et § 7.2, critères (2.1) à (2.5), cas X1 à X8 du § 7.4 (#65).
# Exécuté par tests/test_unitaires.R : le package est installé et chargé, le harnais est
# sourcé, `racine` est défini.
# Les CSV de test sont écrits octet par octet (writeBin), en ASCII.
#
# Table et série fictives déclarées (spécification de B2, § 3.6 ; décision du mainteneur du
# 10 novembre 2026 : aucune table réglementaire embarquée) :
#   - mortalite_fictive_b2 : table fictive, sans source ; format lx_age, statut fictive ;
#     âges 40 à 43, l_x = 100 000 ; 99 000 ; 97 020 ; 94 109,4 (q_40 = 0,01 ; q_41 = 0,02 ;
#     q_42 = 0,03) ;
#   - tme_fictive_b2 : série fictive, sans source ; format serie_tme_mensuelle, statut
#     fictive ; 3,00 % de 2023-01 à 2024-09 ; 3,20 % en 2024-10 ; 3,00 % de 2024-11 à
#     2025-09 ; 2,40 % en 2025-10 ; 3,00 % de 2025-11 à 2025-12 (36 mois).

ns <- asNamespace("provie")
refus_de <- function(expr) tryCatch({ expr; NULL }, refus_provie = function(e) e)
motif_de <- function(expr) {
  tryCatch({ expr; "aucun" }, refus_provie = function(e) e$motif,
           error = function(e) paste("autre :", conditionMessage(e)))
}
erreur_de <- function(expr) tryCatch({ expr; "aucune" }, refus_provie = function(e) "refus",
                                     error = function(e) "erreur")
fichier_csv <- function(lignes, fin = "\n") {
  chemin <- tempfile("table-", fileext = ".csv")
  writeBin(charToRaw(paste0(paste(lignes, collapse = fin), fin)), chemin)
  chemin
}

PROVENANCE_MORTALITE <- "table fictive, sans source (tests, spécification de B2, § 3.6)"
PROVENANCE_TME <- "série fictive, sans source (tests, spécification de B2, § 3.6)"
lignes_mortalite <- c("age,lx", "40,100000", "41,99000", "42,97020", "43,94109.4")
df_mortalite <- data.frame(age = 40:43, lx = c(100000, 99000, 97020, 94109.4))
mois_tme <- sprintf("%04d-%02d", rep(2023:2025, each = 12L), rep(1:12, 3L))
taux_tme <- rep(3, 36L)
taux_tme[mois_tme == "2024-10"] <- 3.2
taux_tme[mois_tme == "2025-10"] <- 2.4
df_tme <- data.frame(mois = mois_tme, taux_pourcent = taux_tme, stringsAsFactors = FALSE)

mortalite <- lire_table(fichier_csv(lignes_mortalite), "lx_age", "mortalite_fictive_b2", "fictive",
                        PROVENANCE_MORTALITE)
tme <- lire_table(fichier_csv(c("mois,taux_pourcent", paste(mois_tme, sprintf("%.2f", taux_tme), sep = ","))),
                  "serie_tme_mensuelle", "tme_fictive_b2", "fictive", PROVENANCE_TME)

# --- (2.1) Formats et lecture -----------------------------------------------------------

section("tables : formats et lecture de la table fictive (critère 2.1)")

ft <- formats_tables()
verifier("formats_tables() rend les deux formats du § 3.2, colonnes fixées",
         identical(names(ft), c("format", "nature", "colonnes", "types", "description", "conversion")) &&
           identical(ft$format, c("lx_age", "serie_tme_mensuelle")) && identical(ft$nature, c("mortalite", "taux")) &&
           identical(ft$colonnes, c("age;lx", "mois;taux_pourcent")) &&
           identical(ft$types, c("integer;numeric", "character;numeric")) &&
           identical(ft$conversion, c("convertir_lx_qx", "convertir_pourcent")))
verifier("chaque conversion de formats_tables() est une fonction nommée du module",
         all(vapply(ft$conversion, function(f) is.function(ns[[f]]), NA)))
verifier("lire_table() rend une table_provie de la forme de l'ADR 0010, point 15",
         inherits(mortalite, "table_provie") &&
           identical(names(mortalite), c("identifiant", "nature", "axes", "pas", "valeurs", "statut", "origine")) &&
           identical(mortalite$identifiant, "mortalite_fictive_b2") && identical(mortalite$nature, "mortalite") &&
           identical(mortalite$axes, list(age = 40:42)) && identical(mortalite$pas, "an") &&
           identical(mortalite$statut, "fictive") &&
           identical(names(mortalite$origine), c("format_natif", "provenance", "conversion", "empreinte")) &&
           identical(mortalite$origine$format_natif, "lx_age") &&
           identical(mortalite$origine$conversion, "convertir_lx_qx") &&
           identical(mortalite$origine$provenance, PROVENANCE_MORTALITE) &&
           grepl("^[0-9a-f]{32}$", mortalite$origine$empreinte))
q <- ns$probabilite(mortalite, age = 40:42)
cat("    mesure : probabilite(age = 40:42) =", sprintf("%.17g", q), "\n")
verifier("probabilite(t, age = 40:42) vaut 0,01 ; 0,02 ; 0,03 à 1e-15 près, aucun point hors axes",
         all(abs(as.vector(q) - c(0.01, 0.02, 0.03)) <= 1e-15) && identical(attr(q, "hors_axes"), integer(0)))
r <- ns$probabilite(mortalite, age = c(41L, 43L), hors_axes = "refus")
verifier("âge 43 hors axes, refus : NA, indice du point signalé",
         is.na(r[2L]) && abs(r[1L] - 0.02) <= 1e-15 && identical(attr(r, "hors_axes"), 2L))
r <- ns$probabilite(mortalite, age = c(43L, 39L), hors_axes = "derniere_valeur")
verifier("âge 43 hors axes, derniere_valeur : 0,03 (et âge 39 : 0,01), points signalés",
         abs(r[1L] - 0.03) <= 1e-15 && abs(r[2L] - 0.01) <= 1e-15 && identical(attr(r, "hors_axes"), 1:2))
verifier("point hors axes sans hors_axes déclaré : erreur (aucun défaut)",
         identical(erreur_de(ns$probabilite(mortalite, age = 43L)), "erreur"))
verifier("hors_axes hors de la liste : erreur",
         identical(erreur_de(ns$probabilite(mortalite, age = 40L, hors_axes = "zero")), "erreur"))
verifier("axe mal nommé : erreur", identical(erreur_de(ns$probabilite(mortalite, x = 40L)), "erreur"))
t0 <- ns$construire_table(data.frame(age = 40:43, lx = c(100, 50, 0, 0)), "lx_age", "t0", "fictive", "x")
verifier("un l_x nul rend hors axes cet âge et les suivants (q_41 = 1)",
         identical(t0$axes, list(age = 40:41)) && identical(as.vector(t0$valeurs), c(0.5, 1)))
verifier("série TME : axe date = 12 x année + mois - 1, valeur / 100, pas mensuel",
         identical(tme$nature, "taux") && identical(tme$pas, "mois") &&
           identical(tme$axes$date, 12L * rep(2023:2025, each = 12L) + rep(0:11, 3L)) &&
           abs(ns$probabilite(tme, date = 12L * 2024L + 9L) - 0.032) <= 1e-15)
sortie <- utils::capture.output(v <- withVisible(print(mortalite)))
verifier("format() et print() de table_provie : décomptes (trois lignes), print rend l'objet invisible",
         length(format(mortalite)) == 3L && grepl("age 3 point", format(mortalite)[2L], fixed = TRUE) &&
           identical(sortie, format(mortalite)) && !v$visible && identical(v$value, mortalite))

# --- (2.2) Empreinte du contenu ---------------------------------------------------------

section("tables : empreinte du contenu (critère 2.2)")

memoire <- ns$construire_table(df_mortalite, "lx_age", "mortalite_fictive_b2", "fictive", PROVENANCE_MORTALITE)
# Empreinte attendue, calculée par une seconde voie (constats T14 et T15 de l'audit) :
# outils::empreinte() des octets canoniques du nom puis des valeurs de chaque colonne, mesurée
# le 11 novembre 2026 (R 4.3.3) ; écrite en dur.
EMPREINTE_MORTALITE_FICTIVE <- "f369ecb1265f41af1a1f0a073c49f85a"
seconde_voie <- ns$empreinte(c(ns$ecrire_valeurs("age", "octets"), ns$ecrire_valeurs(40:43, "octets"),
                               ns$ecrire_valeurs("lx", "octets"),
                               ns$ecrire_valeurs(c(100000, 99000, 97020, 94109.4), "octets")))
verifier("empreinte de mortalite_fictive_b2 : valeur en dur, égale à la seconde voie",
         identical(mortalite$origine$empreinte, EMPREINTE_MORTALITE_FICTIVE) &&
           identical(seconde_voie, EMPREINTE_MORTALITE_FICTIVE))
verifier("même table lue d'un fichier et construite en mémoire : même origine$empreinte (et même objet)",
         identical(memoire$origine$empreinte, mortalite$origine$empreinte) && identical(memoire, mortalite))
autre_octet <- lire_table(fichier_csv(sub("94109.4", "94109.5", lignes_mortalite, fixed = TRUE)), "lx_age",
                          "mortalite_fictive_b2", "fictive", PROVENANCE_MORTALITE)
verifier("un octet changé dans une valeur change l'empreinte",
         !identical(autre_octet$origine$empreinte, mortalite$origine$empreinte))
mise_en_forme <- lire_table(fichier_csv(c("\"age\",\"lx\"", "\"40\",100000.0", "041,99000", "42,\"97020\"",
                                          "43,94109.40"), fin = "\r\n"),
                            "lx_age", "mortalite_fictive_b2", "fictive", PROVENANCE_MORTALITE)
verifier("une autre mise en forme du même contenu (guillemets, zéros, fins de ligne CRLF) : même empreinte",
         identical(mise_en_forme$origine$empreinte, mortalite$origine$empreinte))
verifier("l'empreinte ne dépend ni de l'identifiant, ni du statut, ni de la provenance",
         identical(ns$construire_table(df_mortalite, "lx_age", "autre", "experience", "autre")$origine$empreinte,
                   mortalite$origine$empreinte))
verifier("une espace ajoutée dans une valeur numérique est refusée (type_incompatible), sans conversion",
         identical(motif_de(lire_table(fichier_csv(sub("41,99000", "41, 99000", lignes_mortalite, fixed = TRUE)),
                                       "lx_age", "m", "fictive", "x")), "type_incompatible"))

# --- (2.3) Refus ------------------------------------------------------------------------

section("tables : refus (critère 2.3)")

verifier_refus("format hors liste (lire_table) : format_table_inconnu",
               lire_table(fichier_csv(lignes_mortalite), "lx_qx", "m", "fictive", "x"), "format_table_inconnu")
verifier_refus("format hors liste (construire_table) : format_table_inconnu",
               ns$construire_table(df_mortalite, "lx_qx", "m", "fictive", "x"), "format_table_inconnu")
r <- refus_de(lire_table(fichier_csv(c("age,lx", "40,100000", "42,99000")), "lx_age", "m", "fictive", "x"))
verifier("âges non consécutifs : format_table_inconnu, contrainte et ligne nommées",
         identical(r$motif, "format_table_inconnu") && grepl("entiers", conditionMessage(r), fixed = TRUE) &&
           grepl("ligne 2", conditionMessage(r), fixed = TRUE))
r <- refus_de(lire_table(fichier_csv(c("age,lx", "40,100000", "41,99000", "42,99500")), "lx_age", "m", "fictive", "x"))
verifier("l_x croissant : format_table_inconnu, ligne 3",
         identical(r$motif, "format_table_inconnu") && grepl("croissant", conditionMessage(r), fixed = TRUE) &&
           grepl("ligne 3", conditionMessage(r), fixed = TRUE))
r <- refus_de(lire_table(fichier_csv(c("mois,taux_pourcent", "2024-01,3", "2024-02,3", "2024-02,3.1")),
                         "serie_tme_mensuelle", "s", "fictive", "x"))
verifier("mois en double : format_table_inconnu, ligne 3",
         identical(r$motif, "format_table_inconnu") && grepl("mois en double", conditionMessage(r), fixed = TRUE) &&
           grepl("ligne 3", conditionMessage(r), fixed = TRUE))
r <- refus_de(lire_table(fichier_csv(c("age,lx", "40,100000", "41,abc")), "lx_age", "m", "fictive", "x"))
verifier("colonne lx en texte (fichier) : type_incompatible, colonne et ligne nommées",
         identical(r$motif, "type_incompatible") && identical(r$colonne, "lx") && identical(r$identifiants, "2"))
verifier_refus("colonne lx en texte (mémoire) : type_incompatible",
               ns$construire_table(data.frame(age = 40:41, lx = c("100000", "99000"), stringsAsFactors = FALSE),
                                   "lx_age", "m", "fictive", "x"), "type_incompatible")
verifier_refus("colonne age en double (mémoire) : type_incompatible, sans conversion",
               ns$construire_table(data.frame(age = c(40, 41), lx = c(100000, 99000)), "lx_age", "m", "fictive", "x"),
               "type_incompatible")
verifier_refus("colonnes hors du format : format_table_inconnu",
               lire_table(fichier_csv(c("age,lx,sexe", "40,100000,F", "41,99000,F")), "lx_age", "m", "fictive", "x"),
               "format_table_inconnu")
verifier_refus("colonnes du format dans un autre ordre : format_table_inconnu",
               lire_table(fichier_csv(c("lx,age", "100000,40", "99000,41")), "lx_age", "m", "fictive", "x"),
               "format_table_inconnu")
verifier_refus("l_x manquant : format_table_inconnu",
               lire_table(fichier_csv(c("age,lx", "40,100000", "41,")), "lx_age", "m", "fictive", "x"),
               "format_table_inconnu")
verifier_refus("premier l_x nul : format_table_inconnu",
               ns$construire_table(data.frame(age = 40:41, lx = c(0, 0)), "lx_age", "m", "fictive", "x"),
               "format_table_inconnu")
verifier_refus("mois mal formé : format_table_inconnu",
               ns$construire_table(data.frame(mois = c("2024-13"), taux_pourcent = 3, stringsAsFactors = FALSE),
                                   "serie_tme_mensuelle", "s", "fictive", "x"), "format_table_inconnu")
verifier_refus("mois non consécutifs : format_table_inconnu",
               ns$construire_table(data.frame(mois = c("2024-01", "2024-03"), taux_pourcent = c(3, 3),
                                              stringsAsFactors = FALSE), "serie_tme_mensuelle", "s", "fictive", "x"),
               "format_table_inconnu")
verifier_refus("statut hors liste : liste_invalide",
               ns$construire_table(df_mortalite, "lx_age", "m", "reglementaire", "x"), "liste_invalide")
verifier_refus("provenance absente (chaîne vide) : liste_invalide",
               ns$construire_table(df_mortalite, "lx_age", "m", "fictive", ""), "liste_invalide")
verifier_refus("fichier introuvable : fichier_invalide",
               lire_table(file.path(tempdir(), "absent.csv"), "lx_age", "m", "fictive", "x"), "fichier_invalide")
verifier_refus("fichier mal formé (fin de ligne finale absente) : fichier_invalide",
               lire_table({ f <- tempfile(fileext = ".csv"); writeBin(charToRaw("age,lx\n40,1"), f); f },
                          "lx_age", "m", "fictive", "x"), "fichier_invalide")

# Résolution par usage (spécification de B2, § 3.4).
empreinte_m <- mortalite$origine$empreinte
empreinte_s <- tme$origine$empreinte
plan_tables <- list(
  mortalite_tarif = list(identifiant = "mortalite_fictive_b2", empreinte = empreinte_m, statut = "fictive",
                         hors_axes = "refus"),
  serie_tme = list(identifiant = "tme_fictive_b2", empreinte = empreinte_s, statut = "fictive", hors_axes = "refus",
                   decalage_publication_mois = 1L))
recues <- list(tme_fictive_b2 = tme, mortalite_fictive_b2 = mortalite)
usages <- data.frame(usage = c("serie_tme", "mortalite_tarif"), garantie = c("deces", "deces"),
                     nature = c("taux", "mortalite"), stringsAsFactors = FALSE)
res <- ns$resoudre_tables(plan_tables, recues, usages)
verifier("resoudre_tables() : tables par usage trié, objets reçus rendus tels quels",
         identical(names(res$tables), c("mortalite_tarif", "serie_tme")) &&
           identical(res$tables$mortalite_tarif, mortalite) && identical(res$tables$serie_tme, tme))
verifier("resoudre_tables() : lignes de parametres_retenus$tables aux colonnes de plan (COLONNES_TABLES_RETENUES)",
         identical(names(res$parametres), ns$COLONNES_TABLES_RETENUES) &&
           identical(res$parametres$usage, c("mortalite_tarif", "serie_tme")) &&
           identical(res$parametres$identifiant, c("mortalite_fictive_b2", "tme_fictive_b2")) &&
           identical(res$parametres$format_natif, c("lx_age", "serie_tme_mensuelle")) &&
           identical(res$parametres$conversion, c("convertir_lx_qx", "convertir_pourcent")) &&
           identical(res$parametres$provenance, c(PROVENANCE_MORTALITE, PROVENANCE_TME)) &&
           identical(res$parametres$empreinte, c(empreinte_m, empreinte_s)) &&
           identical(attr(res$parametres, "row.names"), 1:2))
verifier("resoudre_tables() : une entrée du plan non exigée n'est pas résolue",
         identical(names(ns$resoudre_tables(plan_tables, recues, usages[1L, ])$tables), "serie_tme"))
r <- refus_de(ns$resoudre_tables(plan_tables["serie_tme"], recues, usages))
verifier("usage exigé sans entrée du plan : table_absente, usage nommé",
         identical(r$motif, "table_absente") && identical(r$usage, "mortalite_tarif"))
r <- refus_de(ns$resoudre_tables(plan_tables, recues["tme_fictive_b2"], usages))
verifier("entrée du plan sans table reçue sous l'identifiant : table_absente",
         identical(r$motif, "table_absente") && identical(r$usage, "mortalite_tarif") &&
           identical(r$attendu, "mortalite_fictive_b2"))
p <- plan_tables
p$serie_tme$empreinte <- strrep("0", 32L)
p$mortalite_tarif$empreinte <- strrep("1", 32L)
r <- refus_de(ns$resoudre_tables(p, recues, usages))
verifier("empreinte_discordante, à la première discordance dans l'ordre des usages triés",
         identical(r$motif, "empreinte_discordante") && identical(r$usage, "mortalite_tarif") &&
           identical(r$attendu, strrep("1", 32L)) && identical(r$recu, empreinte_m))
p <- plan_tables
p$serie_tme$statut <- "experience"
verifier_refus("statut déclaré différent du statut de la table : plan_invalide",
               ns$resoudre_tables(p, recues, usages), "plan_invalide")
p <- plan_tables
p$serie_tme <- list(identifiant = "mortalite_fictive_b2", empreinte = empreinte_m, statut = "fictive",
                    hors_axes = "refus", decalage_publication_mois = 1L)
r <- refus_de(ns$resoudre_tables(p, recues, usages))
verifier("nature de la table différente de celle de l'usage : plan_invalide",
         identical(r$motif, "plan_invalide") && identical(r$usage, "serie_tme"))
verifier_refus("objet reçu qui n'est pas une table_provie : liste_invalide",
               ns$resoudre_tables(plan_tables, list(tme_fictive_b2 = tme, mortalite_fictive_b2 = df_mortalite), usages),
               "liste_invalide")

# --- (2.4) Indicateurs ------------------------------------------------------------------

section("tables : indicateurs R132_3_1 et A132_1 (critère 2.4, cas X1 à X8)")

x1 <- ns$minimum_r132_3_1(tme, 2026, 1L)
x2 <- ns$minimum_r132_3_1(tme, 2026, 2L)
x3 <- ns$minimum_r132_3_1(tme, 2025, 1L)
x4 <- ns$minimum_r132_3_1(tme, 2024, 1L)
cat("    mesure : X1 =", sprintf("%.17g", x1), "; X2 =", sprintf("%.17g", x2), "; X3 =", sprintf("%.17g", x3),
    "; X4 =", x4, "\n")
verifier_egal("X1 : R132_3_1, année 2026, décalage 1 : 0,024", x1, 0.024)
verifier("X2 : R132_3_1, année 2026, décalage 2 : 0,03 à 1e-15", abs(x2 - 0.03) <= 1e-15)
verifier_egal("X3 : R132_3_1, année 2025, décalage 1 : 0,030166666666666665", x3, 0.030166666666666665)
l4 <- ns$indicateur_r132_3_1(tme, 2024, 1L, 0.03, "sinistres_declares_non_regles", "deces", "societe_assurance")
verifier("X4 : R132_3_1, année 2024 : fenêtre incomplète, NA, serie_incomplete",
         is.na(x4) && is.na(l4$valeur_regle) && is.na(l4$depassement) &&
           identical(l4$detail, "annee=2024;minimum;serie_incomplete"))
verifier("minimum_r132_3_1() vectorisée sur annee",
         identical(ns$minimum_r132_3_1(tme, c(2026, 2025, 2024), 1L), c(x1, x3, x4)))

# Recoupement par une seconde voie (spécification de B2, § 3.5) : fenêtre glissante.
valeurs <- taux_tme / 100
glissante <- as.vector(stats::filter(valeurs, rep(1 / 12, 12L), sides = 1L))
recoupe <- function(annee, decalage) {
  i <- match(12L * (annee - 1L) + 10L - decalage, tme$axes$date)
  min(glissante[i], valeurs[i])
}
ecarts <- c(abs(recoupe(2026, 1L) - x1), abs(recoupe(2026, 2L) - x2), abs(recoupe(2025, 1L) - x3),
            abs(recoupe(2025, 2L) - ns$minimum_r132_3_1(tme, 2025, 2L)))
cat("    mesure : écarts au recoupement par stats::filter() :", sprintf("%.3g", ecarts), "\n")
verifier("recoupement de minimum_r132_3_1() par stats::filter() à 1e-15 près", all(ecarts <= 1e-15))

negative <- ns$construire_table(data.frame(mois = sprintf("%04d-%02d", rep(2024:2025, each = 12L), rep(1:12, 2L)),
                                           taux_pourcent = rep(-0.10, 24L), stringsAsFactors = FALSE),
                                "serie_tme_mensuelle", "tme_negative", "fictive", "série fictive, sans source")
ln <- ns$indicateur_r132_3_1(negative, 2026, 1L, 0.01, "sinistres_declares_non_regles", "deces", "societe_assurance")
cat("    mesure : minimum sur série constante à -0,10 % =", sprintf("%.17g", ln$valeur_regle), "\n")
verifier("I4 : série constante à -0,10 % : -0,001 sans plancher, indicateur_negatif",
         abs(ln$valeur_regle - (-0.001)) <= 1e-15 && identical(ln$depassement, FALSE) &&
           identical(ln$detail, "annee=2026;minimum;indicateur_negatif"))

lr <- ns$indicateur_r132_3_1(tme, c(2025, 2026), 1L, c(`2025` = 0.03, `2026` = 0.024), "capitaux_non_reclames",
                             "deces", "institution_prevoyance")
verifier("R132_3_1 : forme des lignes, depassement si le taux retenu est inférieur au minimum, mention I5",
         identical(names(lr), ns$COLONNES_INDICATEURS) && identical(lr$regle, c("R132_3_1", "R132_3_1")) &&
           identical(lr$poste, c("capitaux_non_reclames", "capitaux_non_reclames")) &&
           identical(lr$valeur_retenue, c(0.03, 0.024)) && identical(lr$depassement, c(TRUE, FALSE)) &&
           identical(lr$detail, c("annee=2025;minimum;ip_renvoi_L932-23_incertain",
                                  "annee=2026;minimum;ip_renvoi_L932-23_incertain")))

a132 <- function(date, nature, terme, tarif, effet = "2024-01-01", arrete = FALSE, serie = tme, decalage = 1L) {
  ns$indicateur_a132_1(serie, as.Date(date), nature, as.Date(rep(effet, length(nature))), as.Date(terme), decalage,
                       tarif, paste0("C", seq_along(nature)), "provision_mathematique_temporaire_deces", "deces",
                       "societe_assurance", arrete)
}
bornes_de <- function(l) sub("^.*;borne_basse=([^;]*);borne_haute=([^;]*);.*$", "\\1 \\2", l$detail)
mesurer <- function(nom, l) {
  cat("    mesure :", nom, "références", sprintf("%.17g", l$valeur_regle), "; bornes", bornes_de(l),
      "; dépassements", l$depassement, "\n")
}
# Séries de test propres des cas X9 à X12 (spécification de B2, § 7.4, version 1.0.2) : 3,00 %
# de 2023-01 à 2023-06, puis les valeurs du cas de 2023-07 à 2023-12 ; séries fictives, sans source.
serie_x <- function(second_semestre, id) {
  ns$construire_table(data.frame(mois = sprintf("2023-%02d", 1:12), taux_pourcent = c(rep(3, 6L), second_semestre),
                                 stringsAsFactors = FALSE), "serie_tme_mensuelle", id, "fictive",
                      "série fictive, sans source")
}

x5 <- a132("2024-01-01", c("unique", "periodique"), c("2027-01-01", "2027-01-01"), c(0.02, 0.02))
mesurer("X5", x5)
verifier("X5 : prime unique au plus 8 ans : référence 0,0225, bornes 0,02 et 0,0225, depassement FALSE (0,02 <= 0,02)",
         abs(x5$valeur_regle[1L] - 0.0225) <= 1e-15 && identical(x5$depassement[1L], FALSE) &&
           identical(bornes_de(x5)[1L], "0.02 0.0225"))
verifier("X5 : primes périodiques : référence 0,018, bornes 0,015 et 0,0175, depassement TRUE",
         abs(x5$valeur_regle[2L] - 0.018) <= 1e-15 && identical(x5$depassement[2L], TRUE) &&
           identical(bornes_de(x5)[2L], "0.015 0.0175"))
x6 <- a132("2025-01-01", c("unique", "unique", "periodique"), c("2027-01-01", "2032-01-02", "2027-01-01"),
           c(0.02, 0.02, 0.02))
mesurer("X6", x6)
verifier("X6 : 0,02275 (0,02 ; 0,0225), FALSE ; terme au 2032-01-02 (> 8 ans) 0,0182 (0,015 ; 0,0175), TRUE ; périodiques 0,0182, TRUE",
         all(abs(x6$valeur_regle - c(0.02275, 0.0182, 0.0182)) <= 1e-15) &&
           identical(x6$depassement, c(FALSE, TRUE, TRUE)) &&
           identical(bornes_de(x6), c("0.02 0.0225", "0.015 0.0175", "0.015 0.0175")))
x7 <- a132("2024-01-01", c("periodique", "unique"), c("2027-01-01", "2032-01-01"), c(0.01, 0.01))
mesurer("X7", x7)
verifier("X7 : périodiques, tarif 0,01 : 0,018, FALSE ; terme au 2032-01-01 (huit ans inclus) : 0,0225 (75 %), FALSE",
         abs(x7$valeur_regle[1L] - 0.018) <= 1e-15 && identical(x7$depassement, c(FALSE, FALSE)) &&
           abs(x7$valeur_regle[2L] - 0.0225) <= 1e-15)
x8 <- a132("2024-01-01", c("unique", "periodique"), c(NA, NA), c(0.02, 0.02))
mesurer("X8", x8)
verifier("X8a : date_terme absente, prime unique : valeur_regle NA, depassement NA, terme_absent",
         is.na(x8$valeur_regle[1L]) && is.na(x8$depassement[1L]) && grepl(";terme_absent", x8$detail[1L], fixed = TRUE))
verifier("X8b : date_terme absente, primes périodiques : 0,018 à 1e-15, depassement TRUE, terme_absent",
         abs(x8$valeur_regle[2L] - 0.018) <= 1e-15 && identical(x8$depassement[2L], TRUE) &&
           grepl(";terme_absent", x8$detail[2L], fixed = TRUE))
x9 <- a132("2024-01-01", rep("periodique", 4L), rep("2027-01-01", 4L), c(0.0205, 0.0200, 0.0175, 0.0170),
           serie = serie_x(c(rep(3.33, 5L), 3.35), "tme_x9"))
mesurer("X9", x9)
verifier("X9 : référence 0,02, bornes 0,0175 et 0,02 ; tarifs 2,05 % ; 2,00 % ; 1,75 % ; 1,70 % : TRUE, NA, FALSE, FALSE",
         all(abs(x9$valeur_regle - 0.02) <= 1e-15) && identical(x9$depassement, c(TRUE, NA, FALSE, FALSE)) &&
           all(bornes_de(x9) == "0.0175 0.02"))
x10 <- a132("2024-01-01", rep("periodique", 3L), rep("2027-01-01", 3L), c(0.0176, 0.0175, 0.0150),
            serie = serie_x(c(rep(3.08, 5L), 3.10), "tme_x10"))
mesurer("X10", x10)
verifier("X10 : référence 0,0185, bornes 0,0175 et 0,0175 (1,50 % exclu, borne ouverte) ; TRUE, FALSE, FALSE",
         all(abs(x10$valeur_regle - 0.0185) <= 1e-15) && identical(x10$depassement, c(TRUE, FALSE, FALSE)) &&
           all(bornes_de(x10) == "0.0175 0.0175"))
x11 <- a132("2024-01-01", rep("periodique", 2L), rep("2027-01-01", 2L), c(0.0010, 0),
            serie = serie_x(c(rep(0.08, 5L), 0.10), "tme_x11"))
mesurer("X11", x11)
verifier("X11 : référence 0,0005, bornes 0 et 0 (T = 0) ; TRUE, FALSE",
         all(abs(x11$valeur_regle - 0.0005) <= 1e-15) && identical(x11$depassement, c(TRUE, FALSE)) &&
           all(bornes_de(x11) == "0 0"))
s12 <- serie_x(rep(-0.5, 6L), "tme_x12")
x12a <- a132("2024-01-01", rep("periodique", 2L), rep("2027-01-01", 2L), c(0, 0.0005), serie = s12)
x12b <- a132("2024-01-01", "unique", "2027-01-01", 0, serie = s12)
mesurer("X12a", x12a)
mesurer("X12b", x12b)
verifier("X12a : référence -0,003, bornes 0 et 0 (sans descendre en dessous de 0) ; FALSE, TRUE",
         all(abs(x12a$valeur_regle + 0.003) <= 1e-15) && identical(x12a$depassement, c(FALSE, TRUE)) &&
           all(bornes_de(x12a) == "0 0"))
verifier("X12b : prime unique au plus 8 ans : référence -0,00375, bornes 0 et 0, FALSE",
         abs(x12b$valeur_regle + 0.00375) <= 1e-15 && identical(x12b$depassement, FALSE) && bornes_de(x12b) == "0 0")
x13a <- a132("2024-01-01", "periodique", "2027-01-01", 0.015)
x13b <- a132("2025-01-01", "periodique", "2027-01-01", 0.0175)
mesurer("X13a", x13a)
mesurer("X13b", x13b)
verifier("X13a : tarif égal à la borne basse (0,015) : FALSE", identical(x13a$depassement, FALSE))
# X13 (b) (erratum v1.0.3) : tarif égal à la borne haute 0,0175 (bornes 0,015 et 0,0175, X6) :
# NA (dépassement si T = 1,50 %, aucun si T = 1,75 %).
verifier("X13b : tarif égal à la borne haute (0,0175) : NA",
         identical(bornes_de(x13b), "0.015 0.0175") && is.na(x13b$depassement))
# Bornes de la tolérance elle-même (constats T3 et T4 de l'audit) : un tarif qui dépasse la
# borne haute d'exactement 1e-12 n'est pas un dépassement certain ; un tarif qui dépasse la
# borne basse d'exactement 1e-12 reste un dépassement exclu.
p13 <- ns$plafond_a132_1(tme, as.Date("2025-01-01"), "periodique", TRUE, 1L)
x13t <- a132("2025-01-01", rep("periodique", 2L), rep("2027-01-01", 2L),
             c(p13$borne_haute + 1e-12, p13$borne_basse + 1e-12))
verifier("X13 : tarif = borne haute + 1e-12 : NA (pas TRUE) ; tarif = borne basse + 1e-12 : FALSE",
         identical(x13t$depassement, c(NA, FALSE)))
# Borne haute ouverte sur un point de l'échelle (mutant G5 de la revue) : prime unique de huit
# ans au plus, TME semestriel 2,8666... % (2,86 ; 2,86 ; 2,86 ; 2,87 ; 2,87 ; 2,88), référence
# 0,0215 : référence + 0,10 point = 0,0225, point de l'échelle exclu de l'intervalle ouvert ;
# bornes 0,02 et 0,02.
x14 <- a132("2024-01-01", "unique", "2027-01-01", 0.02, serie = serie_x(c(2.86, 2.86, 2.86, 2.87, 2.87, 2.88), "tme_x14"))
mesurer("X14", x14)
verifier("référence 0,0215 (réf. + 0,10 point sur 0,0225) : bornes 0,02 et 0,02, 0,0225 exclu",
         abs(x14$valeur_regle - 0.0215) <= 1e-15 && identical(bornes_de(x14), "0.02 0.02") &&
           identical(x14$depassement, FALSE))
x13c <- ns$indicateur_r132_3_1(tme, 2025, 1L, 0.030166666666666665, "sinistres_declares_non_regles", "deces",
                               "societe_assurance")
verifier("X13c : R132_3_1, taux retenu égal au minimum (0,030166666666666665) : FALSE",
         identical(x13c$depassement, FALSE))
verifier("R132_3_1 : taux retenu égal au minimum moins 5e-13 (dans la tolérance) : FALSE",
         identical(ns$indicateur_r132_3_1(tme, 2025, 1L, 0.030166666666666665 - 5e-13, "p", "deces",
                                          "societe_assurance")$depassement, FALSE))
verifier("R132_3_1 : taux retenu inférieur au minimum de plus de 1e-12 : TRUE",
         identical(ns$indicateur_r132_3_1(tme, 2025, 1L, 0.030166666666666665 - 2e-12, "p", "deces",
                                          "societe_assurance")$depassement, TRUE))
verifier("A132_1 : une seule ligne par contrat et par appel (sans tranche), forme des lignes, detail complet",
         nrow(x6) == 3L && identical(names(x6), ns$COLONNES_INDICATEURS) && identical(x6$regle, rep("A132_1", 3L)) &&
           identical(x6$valeur_retenue, c(0.02, 0.02, 0.02)) &&
           identical(x5$detail[1L], paste0("id_contrat=C1;date=2024-01-01;nature_primes=unique;borne_basse=0.02;",
                                           "borne_haute=0.0225;type_organisme=societe_assurance;",
                                           "delai_3_mois_non_pris_en_compte")))
verifier("A132_1 : delai_3_mois_non_pris_en_compte dans chaque detail",
         all(grepl(";delai_3_mois_non_pris_en_compte", c(x5$detail, x6$detail, x7$detail, x8$detail, x9$detail),
                   fixed = TRUE)))
xa <- a132("2025-12-31", "unique", "2027-01-01", 0.02, arrete = TRUE)
verifier("A132_1 à l'arrêté : approximation_arrete dans detail",
         grepl(";delai_3_mois_non_pris_en_compte;approximation_arrete$", xa$detail))
xs <- a132("2023-03-01", "unique", "2027-01-01", 0.02)
verifier("A132_1 sur une fenêtre incomplète : NA, serie_incomplete, aucun refus",
         is.na(xs$valeur_regle) && is.na(xs$depassement) && grepl(";serie_incomplete$", xs$detail))
verifier("plafond_a132_1() : TME semestriel et branches (X5, X6)",
         isTRUE(all.equal(ns$plafond_a132_1(tme, as.Date(c("2024-01-01", "2025-01-01")), "unique", TRUE, 1L)$taux_reference,
                          c(0.0225, 0.02275), tolerance = 1e-14)))
# Mois disponibles et décalage de publication (constats T10 et T11 de l'audit) : au
# 2025-04-01, fenêtre octobre 2024 - mars 2025 (décalage 1) ou septembre 2024 - février 2025
# (décalage 2), toutes deux avec 3,20 % ; au 2025-05-01, novembre 2024 - avril 2025 (3,00 %)
# ou octobre 2024 - mars 2025 (avec 3,20 %).
tme_sem <- function(date, decalage) ns$plafond_a132_1(tme, as.Date(date), "periodique", TRUE, decalage)$tme_semestriel
t_fen <- c(tme_sem("2025-04-01", 1L), tme_sem("2025-04-01", 2L), tme_sem("2025-05-01", 1L), tme_sem("2025-05-01", 2L))
cat("    mesure : TME semestriel aux 2025-04-01 et 2025-05-01, décalages 1 et 2 :", sprintf("%.17g", t_fen), "\n")
verifier("plafond_a132_1() : fenêtre de six mois et décalage (0,030333... ; 0,030333... ; 0,03 ; 0,030333...)",
         all(abs(t_fen - c(0.030333333333333334, 0.030333333333333334, 0.03, 0.030333333333333334)) <= 1e-15))
s_haute <- ns$construire_table(data.frame(mois = sprintf("2023-%02d", 1:12), taux_pourcent = rep(6, 12L),
                                          stringsAsFactors = FALSE), "serie_tme_mensuelle", "tme_haute", "fictive",
                               "série fictive, sans source")
p_haute <- ns$plafond_a132_1(s_haute, as.Date(c("2024-01-01", "2024-01-01")), c("periodique", "unique"), c(TRUE, FALSE), 1L)
# Lecture (a) de #88 (décision du mainteneur du 12 novembre 2026) : échelle d'A132-1-1 sur le
# taux de référence mensuel (60 % du TME non plafonné), puis plafond de 3,5 % sur les deux
# bornes ; taux_reference = min(3,5 % ; 60 %) (option (a2)). Valeurs attendues calculées à la
# main, sans plafond_a132_1() (énumération des points k x 0,0025 de l'ouvert ]réf - 0,0035 ;
# réf + 0,0010[ à 1e-12, puis min(0,035 ; .)) : TME 6 % -> réf. 0,036, point 0,035 seul
# (0,0325 = réf. - 0,0035 exclu), bornes 0,035 et 0,035 (lecture (b) : 0,0325 et 0,035).
verifier("plafond de 3,5 % : TME semestriel 6 %, primes périodiques et prime unique longue : 0,035, bornes 0,035 et 0,035",
         identical(p_haute$taux_reference, c(0.035, 0.035)) && all(abs(p_haute$borne_haute - 0.035) <= 1e-15) &&
           all(abs(p_haute$borne_basse - 0.035) <= 1e-15) && identical(p_haute$reference_plafonnee_3_5, c(TRUE, TRUE)))
# Seuil de divergence des lectures (a) et (b) : TME 5,99 % -> réf. 0,03594, points 0,0325 et
# 0,035, bornes 0,0325 et 0,035 (identiques sous (b)) ; plafond de 3,5 % appliqué au taux de
# référence restitué (0,03594 > 0,035), sans effet sur les bornes.
p_seuil <- ns$plafond_a132_1(serie_x(rep(5.99, 6L), "tme_599"), as.Date("2024-01-01"), "periodique", NA, 1L)
cat("    mesure : TME 5,99 % :", sprintf("%.17g", unlist(p_seuil[1:4])), p_seuil$reference_plafonnee_3_5, "\n")
verifier("plafond de 3,5 % : TME 5,99 % (juste sous 6 %) : 0,035, bornes 0,0325 et 0,035, reference_plafonnee_3_5",
         abs(p_seuil$tme_semestriel - 0.0599) <= 1e-15 && identical(p_seuil$taux_reference, 0.035) &&
           abs(p_seuil$borne_basse - 0.0325) <= 1e-15 && abs(p_seuil$borne_haute - 0.035) <= 1e-15 &&
           identical(p_seuil$reference_plafonnee_3_5, TRUE))
# Réserve M1 de l'audit de #88 : la mention exige un dépassement de 3,5 % de plus de 1e-12,
# pmin() plafonne sans tolérance. Série constante 5,8333333333417 % : 60 % du TME dépasse
# 3,5 % d'environ 5e-14, taux_reference ramené à 3,5 %, mention FALSE (écart assumé, égalité
# à 1e-12) ; série constante 5,8333333342 % : dépassement d'environ 5,2e-12, mention TRUE.
s_m1 <- function(x, id) {
  ns$construire_table(data.frame(mois = sprintf("2023-%02d", 1:12), taux_pourcent = rep(x, 12L),
                                 stringsAsFactors = FALSE), "serie_tme_mensuelle", id, "fictive",
                      "série fictive, sans source")
}
p_m1 <- ns$plafond_a132_1(s_m1(5.8333333333417, "tme_m1_sous"), as.Date("2024-01-01"), "periodique", NA, 1L)
p_m1b <- ns$plafond_a132_1(s_m1(5.8333333342, "tme_m1_sur"), as.Date("2024-01-01"), "periodique", NA, 1L)
cat("    mesure : M1 : écarts à 3,5 %", sprintf("%.3g", 0.6 * c(p_m1$tme_semestriel, p_m1b$tme_semestriel) - 0.035),
    "; mentions", p_m1$reference_plafonnee_3_5, p_m1b$reference_plafonnee_3_5, "\n")
verifier("reference_plafonnee_3_5 : FALSE si 60 % du TME dépasse 3,5 % de moins de 1e-12 (référence 0,035, bornes 0,0325 et 0,035)",
         0.6 * p_m1$tme_semestriel > 0.035 && 0.6 * p_m1$tme_semestriel - 0.035 <= 1e-12 &&
           identical(p_m1$taux_reference, 0.035) && identical(p_m1$reference_plafonnee_3_5, FALSE) &&
           abs(p_m1$borne_basse - 0.0325) <= 1e-15 && abs(p_m1$borne_haute - 0.035) <= 1e-15)
verifier("reference_plafonnee_3_5 : TRUE si 60 % du TME dépasse 3,5 % de plus de 1e-12",
         0.6 * p_m1b$tme_semestriel - 0.035 > 1e-12 && identical(p_m1b$taux_reference, 0.035) &&
           identical(p_m1b$reference_plafonnee_3_5, TRUE))
# TME 7 % -> réf. 0,042, points 0,04 et 0,0425, bornes plafonnées 0,035 et 0,035 (lecture (b) :
# 0,0325 et 0,035) ; tarifs 3,40 % ; 3,50 % ; 3,51 % : FALSE (NA sous (b)), FALSE, TRUE. La
# branche 75 % n'est pas plafonnée : prime unique de huit ans au plus, réf. 0,0525, points
# 0,05 et 0,0525 (0,055 = réf. + 0,0025, hors de l'ouvert), bornes 0,05 et 0,0525.
x7p <- a132("2024-01-01", rep("periodique", 3L), rep("2034-01-01", 3L), c(0.034, 0.035, 0.0351),
            serie = serie_x(rep(7, 6L), "tme_7"))
x7u <- a132("2024-01-01", "unique", "2027-01-01", 0.05, serie = serie_x(rep(7, 6L), "tme_7"))
mesurer("X7p (TME 7 %)", x7p)
mesurer("X7u (TME 7 %, 75 %)", x7u)
verifier("plafond de 3,5 % : TME 7 %, primes périodiques : 0,035, bornes 0,035 et 0,035 ; FALSE, FALSE, TRUE",
         all(abs(x7p$valeur_regle - 0.035) <= 1e-15) && all(bornes_de(x7p) == "0.035 0.035") &&
           identical(x7p$depassement, c(FALSE, FALSE, TRUE)))
verifier("TME 7 %, prime unique de huit ans au plus (75 %) : 0,0525, bornes 0,05 et 0,0525, non plafonnée",
         abs(x7u$valeur_regle - 0.0525) <= 1e-15 && identical(bornes_de(x7u), "0.05 0.0525") &&
           identical(x7u$depassement, FALSE))
# Mention reference_plafonnee_3_5 dans detail : présente au-dessus de 3,5 % (TME 7 %, primes
# périodiques), absente sous 3,5 % (TME 5,5 % : réf. 0,033, bornes 0,03 et 0,0325) et dans
# la branche 75 % (TME 7 %).
x55 <- a132("2024-01-01", "periodique", "2034-01-01", 0.03, serie = serie_x(rep(5.5, 6L), "tme_55"))
mesurer("X55 (TME 5,5 %)", x55)
verifier("detail : reference_plafonnee_3_5 à TME 7 % en primes périodiques, après delai_3_mois_non_pris_en_compte",
         all(grepl(";delai_3_mois_non_pris_en_compte;reference_plafonnee_3_5$", x7p$detail)))
verifier("detail : pas de reference_plafonnee_3_5 à TME 5,5 % (réf. 0,033, bornes 0,03 et 0,0325) ni en branche 75 %",
         abs(x55$valeur_regle - 0.033) <= 1e-15 && identical(bornes_de(x55), "0.03 0.0325") &&
           !grepl("reference_plafonnee_3_5", x55$detail, fixed = TRUE) &&
           !grepl("reference_plafonnee_3_5", x7u$detail, fixed = TRUE))

# --- (2.5) Aucune table embarquée -----------------------------------------------------------

section("tables : aucune table embarquée (critère 2.5)")

verifier("aucun fichier sous inst/extdata/tables/ ni inst/extdata/taux/ (dépôt et package installé)",
         length(list.files(file.path(racine, "inst", "extdata", c("tables", "taux")), recursive = TRUE, all.files = TRUE)) == 0L &&
           !dir.exists(file.path(racine, "inst", "extdata", "tables")) &&
           !dir.exists(file.path(racine, "inst", "extdata", "taux")) &&
           identical(system.file("extdata", "tables", package = "provie"), "") &&
           identical(system.file("extdata", "taux", package = "provie"), ""))
espace <- readLines(file.path(racine, "NAMESPACE"))
verifier("charger_table() absent du NAMESPACE et du package",
         !any(grepl("charger_table", espace[!grepl("^#", espace)], fixed = TRUE)) &&
           !("charger_table" %in% getNamespaceExports("provie")) && !exists("charger_table", envir = ns, inherits = FALSE))
verifier("exports du § 3.7 : lire_table() et formats_tables() ; le reste du module n'est pas exporté",
         all(c("lire_table", "formats_tables") %in% getNamespaceExports("provie")) &&
           !any(c("construire_table", "probabilite", "resoudre_tables", "minimum_r132_3_1", "plafond_a132_1",
                  "indicateur_r132_3_1", "indicateur_a132_1", "convertir_lx_qx", "convertir_pourcent") %in%
                  getNamespaceExports("provie")))
verifier("statuts et hors_axes du plan : listes tenues par tables (STATUTS_TABLE, HORS_AXES)",
         identical(ns$STATUTS_TABLE, c("homologuee", "certifiee", "experience", "loi_anc", "fictive")) &&
           identical(ns$HORS_AXES, c("refus", "derniere_valeur")))
