# Tests unitaires du module `lecture` (R/lecture.R). Exécuté par tests/test_unitaires.R : le
# package est installé et chargé, le harnais est sourcé, `racine` est défini.
# Les CSV de test sont écrits octet par octet (writeBin) et les chaînes non ASCII sont
# marquées UTF-8 (u8) : sous une locale C, un littéral \u00e9 d'un script sourcé n'est pas
# marqué (mesure du 8 novembre 2026, R 4.3.3), et ecrire_base() le refuserait (M105).

ns <- asNamespace("provie")
d <- dictionnaire()
u8 <- function(s) { Encoding(s) <- "UTF-8"; s }
refus_de <- function(expr) tryCatch({ expr; NULL }, refus_provie = function(e) e)
ecrire_octets <- function(chemin, texte) writeBin(if (is.raw(texte)) texte else charToRaw(texte), chemin)
lire_octets <- function(chemin) readBin(chemin, "raw", n = file.info(chemin)$size)
# Dossier vide neuf, contenant les fichiers donnés (nom = texte ou octets), écrits octet par
# octet.
dossier_avec <- function(fichiers = list()) {
  dossier <- tempfile("base-")
  dir.create(dossier)
  for (nom in names(fichiers)) ecrire_octets(file.path(dossier, nom), fichiers[[nom]])
  dossier
}
colonnes_de <- function(table) d$colonnes[d$colonnes$table == table, , drop = FALSE]

# --- Exports ----------------------------------------------------------------------------

section("lecture : exports")
verifier("lire_base() et ecrire_base() sont exportés",
         all(c("lire_base", "ecrire_base") %in% getNamespaceExports("provie")))
verifier("les auxiliaires du module ne sont pas exportés",
         !any(c(".lire_table_csv", ".lire_colonne", ".texte_table_csv", ".champs_colonne",
                ".reels_csv") %in% getNamespaceExports("provie")))

# --- Base valide de référence -----------------------------------------------------------

# Quatre valeurs par type : extrêmes, manquant, chaînes à accents, guillemets, virgule, saut
# de ligne, barre oblique inverse, texte « NA » (une valeur, pas un manquant, § 1.6).
valeurs_de <- function(type) {
  switch(type,
         character = c(u8("\u00e9t\u00e9 \u00e0 l'\u00eele \u2014 \u00ab \u00e7a \u00bb"), NA,
                       "NA", "a,\"b\"\nc \\ d "),
         integer = c(1L, NA, -2147483647L, 2147483647L),
         numeric = c(0.1, NA, 1 / 3, -2.5e-300),
         Date = as.Date(c("2026-12-31", NA, "1901-01-01", "9999-12-31")),
         logical = c(TRUE, NA, FALSE, TRUE))
}
vide_de <- function(type, n) {
  switch(type, character = rep(NA_character_, n), integer = rep(NA_integer_, n),
         numeric = rep(NA_real_, n), logical = rep(NA, n), Date = as.Date(rep(NA_character_, n)))
}
table_de <- function(table, valeurs) {
  col <- colonnes_de(table)
  df <- as.data.frame(lapply(col$type, valeurs), stringsAsFactors = FALSE)
  names(df) <- col$colonne
  df
}
base <- lapply(d$tables$table, function(t) table_de(t, valeurs_de))
names(base) <- d$tables$table
base$extraction <- data.frame(date_extraction = as.Date("2026-12-31"),
                              debut_historique = as.Date("2017-01-01"),
                              type_organisme = "mutuelle", version_dictionnaire = "1.3",
                              devise = "EUR", stringsAsFactors = FALSE)
base$catastrophes <- table_de("catastrophes", function(type) vide_de(type, 0L))   # aucune ligne
base$victimes <- table_de("victimes", function(type) vide_de(type, 3L))           # colonnes vides
verifier("la base de référence est conforme à controler_types()", identical(controler_types(base), base))

# --- Aller-retour -----------------------------------------------------------------------

section("lecture : aller-retour lire_base(ecrire_base(x, d))")
dossier <- tempfile("base-")
verifier("ecrire_base() rend le dossier, invisible",
         identical(withVisible(ecrire_base(base, dossier)), list(value = dossier, visible = FALSE)))
verifier_egal("un fichier <table>.csv par table, rien d'autre",
              sort(list.files(dossier, all.files = TRUE, no.. = TRUE), method = "radix"),
              sort(paste0(d$tables$table, ".csv"), method = "radix"))
relue <- lire_base(dossier)
verifier_egal("aller-retour identical sur une base complète (20 tables, cinq types)", relue, base)
verifier("aller-retour sous la locale courante (LC_CTYPE consigné)",
         identical(lire_base(ecrire_base(base, tempfile("base-"))), base))
cat("    locale de l'essai : LC_CTYPE =", Sys.getlocale("LC_CTYPE"), "; UTF-8 :",
    l10n_info()[["UTF-8"]], "\n")
verifier("chaînes non ASCII relues marquées UTF-8, octets UTF-8",
         identical(Encoding(relue$contrats$id_contrat[1L]), "UTF-8") &&
           identical(charToRaw(relue$contrats$id_contrat[1L]), charToRaw(base$contrats$id_contrat[1L])))
verifier("fichier écrit en UTF-8 sans marque d'ordre (é = c3 a9)", {
  o <- lire_octets(file.path(dossier, "contrats.csv"))
  !identical(o[1:3], as.raw(c(0xef, 0xbb, 0xbf))) &&
    length(grepRaw(as.raw(c(0xc3, 0xa9)), o, fixed = TRUE)) == 1L
})
verifier("le texte « NA » reste une valeur, le champ vide un manquant",
         identical(relue$contrats$id_contrat[2:3], c(NA, "NA")))
verifier_egal("table sans ligne : relue sans ligne, colonnes typées", relue$catastrophes, base$catastrophes)
b <- list(contrats = table_de("contrats", function(type) vide_de(type, 2L)),
          parametres = table_de("parametres", function(type) vide_de(type, 2L)))
r <- lire_base(ecrire_base(b, tempfile("base-")))
types_lus <- unlist(lapply(r, function(t) vapply(t, function(x) class(x)[1L], "")))
verifier("colonnes entièrement vides (cinq types) : relues dans le type déclaré, jamais logical",
         identical(r, b) && setequal(types_lus, c("character", "integer", "numeric", "Date", "logical")) &&
           identical(unname(types_lus), c(colonnes_de("contrats")$type, colonnes_de("parametres")$type)) &&
           is.double(r$contrats$date_effet))
verifier("Date relue stockée en double", is.double(relue$contrats$date_effet))
verifier_egal("réels écrits au plus court qui se relit à l'identique",
              ns$.champs_colonne(c(0.1, 1 / 3, -0, 1e300, NA), "t", "c"),
              c("0.1", "0.3333333333333333", "0", "1e+300", ""))

b <- base[c("extraction", "contrats", "parametres")]
verifier("tables absentes du dossier : absentes du résultat, les autres relues",
         identical(lire_base(ecrire_base(b, tempfile("base-"))), b))
b <- base[c("extraction", "contrats")]
b$contrats <- b$contrats[, rev(names(b$contrats))]
verifier("ordre des colonnes libre : relu dans l'ordre du fichier",
         identical(lire_base(ecrire_base(b, tempfile("base-"))), b))
b$contrats$date_fin <- NULL
verifier("colonne facultative absente : admise", identical(lire_base(ecrire_base(b, tempfile("base-"))), b))
b <- base["contrats"]
b$contrats$id_contrat <- c(rawToChar(as.raw(c(0x63, 0xe9))), "b", "c", "d")
Encoding(b$contrats$id_contrat) <- "latin1"
verifier("chaîne marquée latin1 : écrite en UTF-8, relue à l'identique (même texte)", {
  r <- lire_base(ecrire_base(b, tempfile("base-")))
  identical(r, b) && identical(charToRaw(r$contrats$id_contrat[1L]), as.raw(c(0x63, 0xc3, 0xa9)))
})
verifier("base vide : aucun fichier, relue vide",
         identical(lire_base(ecrire_base(list(), tempfile("base-"))), list()))

# --- Lecture typée : fichiers écrits à la main -----------------------------------------------

# Ligne d'en-tête et ligne de données valides d'une table (une valeur par type), dont le
# champ de `colonne` est remplacé par `champ`.
champ_valide <- c(character = "\"x\"", integer = "1", numeric = "1.5", Date = "2026-01-01",
                  logical = "TRUE")
csv_de <- function(table, champs = list(), lignes = 1L) {
  col <- colonnes_de(table)
  ligne <- champ_valide[col$type]
  for (nom in names(champs)) ligne[col$colonne == nom] <- champs[[nom]]
  paste0(paste(c(paste(col$colonne, collapse = ","), rep(paste(ligne, collapse = ","), lignes)),
               collapse = "\n"), "\n")
}
lire_avec <- function(table, champs, ...) {
  fichiers <- list(csv_de(table, champs, ...))
  names(fichiers) <- paste0(table, ".csv")
  lire_base(dossier_avec(fichiers))
}

section("lecture : fichiers écrits à la main, valeurs lues dans le type du dictionnaire")
r <- lire_avec("contrats", list())
verifier("ligne valide : chaque colonne dans son type",
         identical(r$contrats$mois_echeance, 1L) && identical(r$contrats$date_effet, as.Date("2026-01-01")) &&
           identical(r$contrats$tacite_reconduction, TRUE) && identical(r$contrats$id_contrat, "x"))
r <- lire_avec("parametres", list(valeur = "1.5e-3", age_min = "-0"))
verifier("réel à exposant et entier « -0 » admis", identical(r$parametres$valeur, 1.5e-3) &&
           identical(r$parametres$age_min, 0L))
r <- lire_avec("contrats", list(mois_echeance = "", date_effet = "", tacite_reconduction = "",
                                id_contrat = ""), lignes = 2L)
verifier("colonnes vides d'un CSV écrit à la main : integer, Date, logical, character",
         identical(r$contrats$mois_echeance, c(NA_integer_, NA_integer_)) &&
           identical(r$contrats$date_effet, as.Date(c(NA_character_, NA_character_))) &&
           identical(r$contrats$tacite_reconduction, c(NA, NA)) &&
           identical(r$contrats$id_contrat, c(NA_character_, NA_character_)))
r <- lire_avec("contrats", list(id_contrat = "\"NA\"", nature_contrat = "NA", gestionnaire = " a b "))
verifier("« NA » entre guillemets ou nu : la valeur \"NA\" ; chaîne nue : espaces conservées",
         identical(r$contrats$id_contrat, "NA") && identical(r$contrats$nature_contrat, "NA") &&
           identical(r$contrats$gestionnaire, " a b "))
r <- lire_avec("parametres", list(age_min = "\"007\"", valeur = "007.50"))
verifier("tolérances déclarées : valeur entre guillemets dans un entier, zéros de tête",
         identical(r$parametres$age_min, 7L) && identical(r$parametres$valeur, 7.5))
r <- lire_avec("contrats", list(date_effet = "\"2026-01-01\"", tacite_reconduction = "\"FALSE\""))
verifier("tolérances déclarées : date et logique entre guillemets",
         identical(r$contrats$date_effet, as.Date("2026-01-01")) && identical(r$contrats$tacite_reconduction, FALSE))
r <- lire_avec("contrats", list(id_contrat = u8("\"\u00e9l\u00e8ve \u2014 \u00c9t\u00e9\"")))
verifier("accents UTF-8 d'un fichier écrit à la main : relus marqués UTF-8",
         identical(r$contrats$id_contrat, u8("\u00e9l\u00e8ve \u2014 \u00c9t\u00e9")) &&
           identical(Encoding(r$contrats$id_contrat), "UTF-8"))
verifier("fins de ligne CRLF admises", {
  texte <- gsub("\n", "\r\n", csv_de("contrats"), fixed = TRUE)
  identical(lire_base(dossier_avec(list(contrats.csv = texte)))$contrats$mois_echeance, 1L)
})

section("lecture : type incompatible, sans conversion")
e <- refus_de(lire_avec("contrats", list(date_effet = "2026-02-30")))
verifier("date inexistante (2026-02-30) : type_incompatible, table, colonne, attendu, reçu",
         !is.null(e) && e$motif == "type_incompatible" && e$module == "lecture" &&
           e$table == "contrats" && e$colonne == "date_effet" && e$attendu == "Date" &&
           e$recu == "2026-02-30")
for (v in c("2026/01/02", "26-01-02", "2026-1-2", "2026-01-02 ", "02/01/2026", "NA", "2026-13-01")) {
  verifier_refus(paste0("date « ", v, " » refusée, pas lue NA"),
                 lire_avec("contrats", list(date_effet = v)), "type_incompatible")
}
e <- refus_de(lire_avec("parametres", list(age_min = "abc"), lignes = 3L))
verifier("texte dans un entier : type_incompatible, nombre et lignes de données",
         !is.null(e) && e$motif == "type_incompatible" && e$colonne == "age_min" &&
           e$attendu == "integer" && e$recu == "abc" && e$nombre == 3L &&
           identical(e$identifiants, c("1", "2", "3")))
for (v in c("1.5", "1.0", "1e3", " 1", "+1", "0x10", "NA", "2147483648", "-2147483648")) {
  verifier_refus(paste0("entier « ", v, " » refusé, pas converti"),
                 lire_avec("parametres", list(age_min = v)), "type_incompatible")
}
for (v in c("0x10", "Inf", "NaN", "NA", "\"1,5\"", ".5", "1e400", "1e-400", " 1")) {
  verifier_refus(paste0("réel « ", v, " » refusé"), lire_avec("parametres", list(valeur = v)),
                 "type_incompatible")
}
for (v in c("T", "true", "1", "NA", "\"TRUE \"")) {
  verifier_refus(paste0("logique « ", v, " » refusé"),
                 lire_avec("contrats", list(tacite_reconduction = v)), "type_incompatible")
}

section("lecture : chaîne vide entre guillemets et retour chariot dans un champ (type_incompatible)")
cas_vides <- list(c("contrats", "nature_contrat", "character"), c("contrats", "mois_echeance", "integer"),
                  c("parametres", "valeur", "numeric"), c("contrats", "date_effet", "Date"),
                  c("contrats", "tacite_reconduction", "logical"))
for (k in cas_vides) {
  champs <- list("\"\""); names(champs) <- k[2L]
  e <- refus_de(lire_avec(k[1L], champs, lignes = 2L))
  verifier(paste0("\"\" dans une colonne ", k[3L], " (", k[1L], ".", k[2L],
                  ") : type_incompatible, table, colonne, lignes 1 et 2, pas lu NA"),
           !is.null(e) && e$motif == "type_incompatible" && e$module == "lecture" &&
             e$table == k[1L] && e$colonne == k[2L] && e$attendu == k[3L] && e$recu == "\"\"" &&
             e$nombre == 2L && identical(e$identifiants, c("1", "2")) &&
             grepl("le champ vide est le seul marqueur de manquant", conditionMessage(e), fixed = TRUE))
}
r <- lire_avec("contrats", list(id_contrat = "\"\"\"\"", nature_contrat = "\"a\"\"b\"", gestionnaire = ""))
verifier("non-régression : \"\"\"\" (un guillemet) et \"a\"\"b\" admis, champ vide lu NA",
         identical(r$contrats$id_contrat, "\"") && identical(r$contrats$nature_contrat, "a\"b") &&
           identical(r$contrats$gestionnaire, NA_character_))
crlf <- function(texte) gsub("\n", "\r\n", texte, fixed = TRUE)
for (fichier in c("LF", "CRLF")) {
  texte <- csv_de("contrats", list(id_contrat = "\"A@B\""))
  if (fichier == "CRLF") texte <- crlf(texte)
  for (dans in c("\r\n", "\r")) {
    e <- refus_de(lire_base(dossier_avec(list(contrats.csv = sub("@", dans, texte, fixed = TRUE)))))
    verifier(sprintf("fichier %s : %s dans un champ entre guillemets : type_incompatible, colonne et ligne",
                     fichier, if (dans == "\r") "CR isolé" else "CRLF"),
             !is.null(e) && e$motif == "type_incompatible" && e$colonne == "id_contrat" &&
               identical(e$identifiants, "1"))
  }
}
deux <- paste0(paste(colonnes_de("contrats")$colonne, collapse = ","), "\n",
               sub("^[^\n]*\n", "", csv_de("contrats", list(id_contrat = "\"A\r\nB\""))),
               sub("^[^\n]*\n", "", csv_de("contrats", list(id_contrat = "\"A\nB\""))))
e <- refus_de(lire_base(dossier_avec(list(contrats.csv = deux))))
verifier("collision d'identifiants \"A\\r\\nB\" et \"A\\nB\" : refusée (ligne 1), pas de faux doublon",
         !is.null(e) && e$motif == "type_incompatible" && identical(e$identifiants, "1"))
verifier("\"A\\nB\" seul : admis, saut de ligne conservé",
         identical(lire_avec("contrats", list(id_contrat = "\"A\nB\""))$contrats$id_contrat, "A\nB"))
verifier("\"A\\nB\" dans un fichier CRLF : admis (le saut de ligne du champ reste \\n)", {
  texte <- sub("@", "\n", crlf(csv_de("contrats", list(id_contrat = "\"A@B\""))), fixed = TRUE)
  identical(lire_base(dossier_avec(list(contrats.csv = texte)))$contrats$id_contrat, "A\nB")
})
verifier_refus("\"\" dans l'en-tête : liste_invalide (fichier mal formé)",
               lire_base(dossier_avec(list(contrats.csv = sub("^id_contrat", "\"\"", csv_de("contrats"))))),
               "liste_invalide")

section("lecture : tables, colonnes et version")
e <- refus_de(lire_avec("contrats", list()))
verifier("table extraction absente du dossier : lue sans elle (contrôle de la base entière : donnees)", is.null(e))
csv_inconnue <- sub("\n", ",inconnue\n", csv_de("contrats"), fixed = TRUE)
csv_inconnue <- sub("\n$", ",\"v\"\n", csv_inconnue)
e <- refus_de(lire_base(dossier_avec(list(contrats.csv = csv_inconnue))))
verifier("colonne inconnue du dictionnaire : colonne_inconnue (controler_types sur le résultat)",
         !is.null(e) && e$motif == "colonne_inconnue" && e$colonne == "inconnue")
col <- colonnes_de("contrats")
garde <- col$colonne != "id_contrat"
csv_sans <- paste0(paste(col$colonne[garde], collapse = ","), "\n",
                   paste(champ_valide[col$type[garde]], collapse = ","), "\n")
verifier_refus("colonne obligatoire absente : colonne_absente",
               lire_base(dossier_avec(list(contrats.csv = csv_sans))), "colonne_absente")
e <- refus_de(lire_avec("extraction", list(version_dictionnaire = "\"1.2\"", date_extraction = "31/12/2026")))
verifier("version 1.2 : extraction_invalide, avant le type des autres colonnes",
         !is.null(e) && e$motif == "extraction_invalide" && identical(e$recu, "1.2"))
verifier_refus("table extraction de deux lignes : extraction_invalide",
               lire_avec("extraction", list(version_dictionnaire = "\"1.3\""), lignes = 2L),
               "extraction_invalide")

section("lecture : dossier et fichiers")
e <- refus_de(lire_base(dossier_avec(list(contrats.csv = csv_de("contrats"), contrat.csv = "a\n"))))
verifier("fichier inconnu du dictionnaire (contrat.csv) : liste_invalide, fichier nommé",
         !is.null(e) && e$motif == "liste_invalide" && identical(e$identifiants, "contrat.csv"))
verifier_refus("fichier d'une autre extension (notes.txt) : liste_invalide",
               lire_base(dossier_avec(list(notes.txt = "x\n"))), "liste_invalide")
verifier_refus("fichier caché : liste_invalide", lire_base(dossier_avec(list(.cache = "x\n"))), "liste_invalide")
x <- dossier_avec(); dir.create(file.path(x, "contrats.csv"))
verifier_refus("dossier nommé <table>.csv : liste_invalide", lire_base(x), "liste_invalide")
verifier_refus("dossier introuvable : liste_invalide", lire_base(file.path(tempdir(), "absent-xyz")),
               "liste_invalide")
x <- tempfile("fichier-"); ecrire_octets(x, "x\n")
e <- refus_de(lire_base(x))
verifier("chemin d'un fichier : liste_invalide, « n'est pas un dossier » (pas « introuvable »)",
         !is.null(e) && e$motif == "liste_invalide" && grepl("n'est pas un dossier", conditionMessage(e), fixed = TRUE))
csv_virgule <- sub("^id_contrat", "\"id,contrat\"", csv_de("contrats"))
e <- refus_de(lire_base(dossier_avec(list(contrats.csv = csv_virgule))))
verifier("nom d'en-tête entre guillemets avec une virgule : colonne_inconnue (en-tête bien lu), pas fichier mal formé",
         !is.null(e) && e$motif == "colonne_inconnue" && identical(e$colonne, "id,contrat"))
csv_guillemet <- sub("^id_contrat", "\"id\"\"contrat\"", csv_de("contrats"))
e <- refus_de(lire_base(dossier_avec(list(contrats.csv = csv_guillemet))))
verifier("nom d'en-tête avec un guillemet doublé : colonne_inconnue",
         !is.null(e) && e$motif == "colonne_inconnue" && identical(e$colonne, "id\"contrat"))
verifier_refus("chemin qui n'est pas une chaîne unique : liste_invalide", lire_base(c("a", "b")),
               "liste_invalide")
verifier("dossier vide : base vide", identical(lire_base(dossier_avec()), list()))

section("lecture : fichiers mal formés, refusés (liste_invalide)")
valide <- csv_de("contrats")
mal_formes <- list(
  "fichier vide" = "",
  "fin de ligne finale absente" = sub("\n$", "", valide),
  "marque d'ordre UTF-8" = paste0(rawToChar(as.raw(c(0xef, 0xbb, 0xbf))), valide),
  "contenu latin1 (é = e9)" = local({
    o <- charToRaw(valide)
    k <- grepRaw("\"x\"", o, fixed = TRUE)
    c(o[seq_len(k)], as.raw(0xe9), o[(k + 1L):length(o)])   # octets construits : sub() sur une
  }),                                                        # chaîne invalide avertit sous UTF-8
  "retour chariot isolé hors guillemets" = sub("\"x\"", "a\rb", valide),
  "ligne de données trop courte" = sub(",[^,]*\n$", "\n", valide),
  "ligne de données trop longue (première colonne lue en noms de lignes)" = sub("\n$", ",1\n", valide),
  "ligne vide entre deux lignes" = paste0(valide, "\n", sub("^[^\n]*\n", "", valide)),
  "guillemet non fermé" = sub("\"x\"", "\"x", valide),
  "texte après le guillemet fermant (\"ab\"cd, que read.csv() lirait abcd)" = sub("\"x\"", "\"ab\"cd", valide),
  "guillemets ouverts au milieu d'un champ (ab\"cd\")" = sub("\"x\"", "ab\"cd\"", valide)
)
for (cas in names(mal_formes)) {
  verifier_refus(cas, lire_base(dossier_avec(list(contrats.csv = mal_formes[[cas]]))), "liste_invalide")
}

# --- Écriture : refus avant toute écriture ---------------------------------------------------

section("lecture : ecrire_base(), refus")
b <- base["contrats"]
verifier_refus("type incompatible (integer reçu en numeric) : type_incompatible, par controler_types()",
               { b$contrats$mois_echeance <- as.numeric(b$contrats$mois_echeance)
                 ecrire_base(b, tempfile("base-")) }, "type_incompatible")
x <- tempfile("base-")
b <- base["contrats"]; b$contrats$id_contrat[1L] <- ""
e <- refus_de(ecrire_base(b, x))
verifier("chaîne vide \"\" : liste_invalide (elle serait relue NA), colonne nommée",
         !is.null(e) && e$motif == "liste_invalide" && e$colonne == "id_contrat" && e$nombre == 1L)
verifier("refus avant toute écriture : dossier non créé", !file.exists(x))
b <- base["contrats"]; b$contrats$id_contrat[1L] <- "a\rb"
verifier_refus("chaîne contenant un retour chariot : liste_invalide", ecrire_base(b, tempfile("base-")),
               "liste_invalide")
for (v in c(Inf, -Inf, NaN)) {
  b <- base["parametres"]; b$parametres$valeur[1L] <- v
  verifier_refus(paste0("réel ", v, " : liste_invalide"), ecrire_base(b, tempfile("base-")), "liste_invalide")
}
b <- base["contrats"]; b$contrats$date_effet[1L] <- as.Date("2026-01-01") + 0.5
e <- refus_de(ecrire_base(b, tempfile("base-")))
verifier("date non entière : liste_invalide, relevé au nom de lecture avec table et colonne",
         !is.null(e) && e$motif == "liste_invalide" && e$module == "lecture" && e$table == "contrats" &&
           e$colonne == "date_effet")
b <- base["contrats"]; b$contrats$date_effet[1L] <- as.Date("9999-12-31") + 1
e <- refus_de(ecrire_base(b, tempfile("base-")))
verifier("date hors de quatre chiffres d'année : liste_invalide, module lecture, table et colonne",
         !is.null(e) && e$motif == "liste_invalide" && e$module == "lecture" && e$table == "contrats" &&
           e$colonne == "date_effet")
b <- base["contrats"]; b$contrats$id_contrat[1L] <- rawToChar(as.raw(c(0x63, 0xe9)))
Encoding(b$contrats$id_contrat) <- "bytes"
e <- refus_de(ecrire_base(b, tempfile("base-")))
verifier("chaîne d'encodage « bytes » : liste_invalide, module lecture, table et colonne",
         !is.null(e) && e$motif == "liste_invalide" && e$module == "lecture" && e$table == "contrats" &&
           e$colonne == "id_contrat")
b <- base["contrats"]
b$contrats$id_contrat[1L] <- rawToChar(as.raw(c(0x63, 0xc3, 0xa9)))   # non marquée
if (isTRUE(l10n_info()[["UTF-8"]])) {
  verifier("chaîne non marquée sous une locale UTF-8 : écrite et relue",
           identical(lire_base(ecrire_base(b, tempfile("base-")))$contrats$id_contrat[1L], u8("c\u00e9")))
} else {
  e <- refus_de(ecrire_base(b, tempfile("base-")))
  verifier("chaîne non marquée non ASCII sous une locale non UTF-8 : liste_invalide (M105), module lecture, colonne",
           !is.null(e) && e$motif == "liste_invalide" && e$module == "lecture" && e$colonne == "id_contrat")
}
x <- dossier_avec(list(ancien.txt = "x\n"))
verifier_refus("dossier existant non vide : liste_invalide", ecrire_base(base["contrats"], x), "liste_invalide")
x <- tempfile("fichier-"); ecrire_octets(x, "x\n")
verifier_refus("chemin d'un fichier : liste_invalide", ecrire_base(base["contrats"], x), "liste_invalide")
verifier_refus("parent du dossier absent : liste_invalide",
               ecrire_base(base["contrats"], file.path(tempfile("absent-"), "base")), "liste_invalide")
x <- dossier_avec()
verifier("dossier existant vide : admis", identical(lire_base(ecrire_base(base["contrats"], x)), base["contrats"]))
