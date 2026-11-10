# Tests unitaires du module `lecture` (R/lecture.R). Exécuté par tests/test_unitaires.R : le
# package est installé et chargé, le harnais est sourcé, `racine` est défini.
# Les CSV de test sont écrits octet par octet (writeBin) et les chaînes non ASCII sont
# marquées UTF-8 (u8) : sous une locale C, un littéral \u00e9 d'un script sourcé n'est pas
# marqué (mesure du 8 novembre 2026, R 4.3.3), et ecrire_base() le refuserait (M105).

ns <- asNamespace("provie")
d <- dictionnaire()
u8 <- function(s) { Encoding(s) <- "UTF-8"; s }
refus_de <- function(expr) tryCatch({ expr; NULL }, refus_provie = function(e) e)
motif_de_refus <- function(expr) tryCatch({ expr; "aucun" }, refus_provie = function(e) e$motif)
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
         !any(c(".lire_table_csv", ".champs_entre_guillemets", ".texte_table_csv", ".champs_colonne",
                ".reels_csv") %in% getNamespaceExports("provie")))
verifier("la grammaire stricte n'est plus dans lecture (lire_texte_type() de dictionnaire)",
         !exists(".lire_colonne", envir = ns, inherits = FALSE) && is.function(ns$lire_texte_type))

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
                              type_organisme = "mutuelle", version_dictionnaire = "1.5",
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

section("lecture : valeur illisible dans son type, colonne rendue entière en texte exact (M144)")
# Colonne d'une valeur illisible : rendue en character, texte exact, les autres colonnes
# typées ; aucune interruption, aucune conversion.
en_texte <- function(r, table, colonne, attendu) {
  x <- r[[table]][[colonne]]
  identical(class(x), "character") && identical(x, attendu)
}
r <- lire_avec("contrats", list(date_effet = "2026-02-30"))
verifier("date inexistante (2026-02-30) : colonne date_effet rendue en texte exact, les autres typées",
         en_texte(r, "contrats", "date_effet", "2026-02-30") && identical(r$contrats$mois_echeance, 1L) &&
           identical(r$contrats$tacite_reconduction, TRUE))
for (v in c("2026/01/02", "26-01-02", "2026-1-2", "2026-01-02 ", "02/01/2026", "NA", "2026-13-01")) {
  verifier(paste0("date « ", v, " » : rendue en texte exact, pas lue NA ni convertie"),
           en_texte(lire_avec("contrats", list(date_effet = v)), "contrats", "date_effet", v))
}
r <- lire_avec("parametres", list(age_min = "abc"), lignes = 3L)
verifier("texte dans un entier : colonne entière en texte, trois lignes",
         en_texte(r, "parametres", "age_min", rep("abc", 3L)))
fichier <- paste0(paste(colonnes_de("parametres")$colonne, collapse = ","), "\n",
                  "\"g\",\"p\",,7,,1.5\n\"g\",\"p\",,x,,1.5\n\"g\",\"p\",,,,1.5\n")
r <- lire_base(dossier_avec(list(parametres.csv = fichier)))
verifier("une seule valeur illisible : la colonne entière reste en texte, valeurs lisibles comprises, champ vide NA",
         en_texte(r, "parametres", "age_min", c("7", "x", NA)) && identical(r$parametres$valeur, rep(1.5, 3L)))
for (v in c("1.5", "1.0", "1e3", " 1", "+1", "0x10", "NA", "2147483648", "-2147483648")) {
  verifier(paste0("entier « ", v, " » : rendu en texte exact, pas converti"),
           en_texte(lire_avec("parametres", list(age_min = v)), "parametres", "age_min", v))
}
for (v in c("0x10", "Inf", "NaN", "NA", ".5", "1e400", "1e-400", " 1")) {
  verifier(paste0("réel « ", v, " » : rendu en texte exact"),
           en_texte(lire_avec("parametres", list(valeur = v)), "parametres", "valeur", v))
}
verifier("réel « \"1,5\" » : rendu en texte exact (1,5)",
         en_texte(lire_avec("parametres", list(valeur = "\"1,5\"")), "parametres", "valeur", "1,5"))
for (v in c("T", "true", "1", "NA")) {
  verifier(paste0("logique « ", v, " » : rendu en texte exact"),
           en_texte(lire_avec("contrats", list(tacite_reconduction = v)), "contrats", "tacite_reconduction", v))
}
verifier("logique « \"TRUE \" » : rendu en texte exact, espace conservée",
         en_texte(lire_avec("contrats", list(tacite_reconduction = "\"TRUE \"")), "contrats",
                  "tacite_reconduction", "TRUE "))
r <- lire_avec("contrats", list(date_effet = "x", mois_echeance = "y"))
e <- refus_de(controler_types(r))
verifier("appel isolé : lire_base() rend une base non conforme sans rien dire, controler_types() la refuse (deux écarts comptés)",
         !is.null(e) && e$motif == "type_incompatible" && e$nombre == 2L &&
           identical(e$identifiants, c("contrats.date_effet", "contrats.mois_echeance")))
verifier("appel isolé : aucun avertissement, message ni sortie à la lecture d'une base non conforme", {
  sortie <- utils::capture.output(r <- withCallingHandlers(
    lire_avec("contrats", list(date_effet = "x")),
    warning = function(w) stop("avertissement"), message = function(m) stop("message")))
  length(sortie) == 0L && identical(r$contrats$date_effet, "x")
})

section("lecture : chaîne vide entre guillemets rendue telle quelle (M150), retour chariot dans un champ (fichier_invalide)")
r <- lire_avec("contrats", list(nature_contrat = "\"\""), lignes = 2L)
verifier("\"\" dans une colonne character : rendu \"\" (chaîne vide), pas NA",
         identical(r$contrats$nature_contrat, c("", "")))
cas_vides <- list(c("contrats", "mois_echeance", "integer", "1"), c("parametres", "valeur", "numeric", "1.5"),
                  c("contrats", "date_effet", "Date", "2026-01-01"),
                  c("contrats", "tacite_reconduction", "logical", "TRUE"))
for (k in cas_vides) {
  fichier <- paste0(sub("\n.*$", "", csv_de(k[1L])), "\n",
                    sub("^[^\n]*\n", "", csv_de(k[1L], stats::setNames(list("\"\""), k[2L]))),
                    sub("^[^\n]*\n", "", csv_de(k[1L])),
                    sub("^[^\n]*\n", "", csv_de(k[1L], stats::setNames(list(""), k[2L]))))
  r <- lire_base(dossier_avec(stats::setNames(list(fichier), paste0(k[1L], ".csv"))))
  verifier(paste0("\"\" dans une colonne ", k[3L], " (", k[1L], ".", k[2L],
                  ") : colonne en texte exact, \"\" rétabli, champ vide NA"),
           en_texte(r, k[1L], k[2L], c("", k[4L], NA)))
}
r <- lire_avec("contrats", list(id_contrat = "\"\"\"\"", nature_contrat = "\"a\"\"b\"", gestionnaire = ""))
verifier("non-régression : \"\"\"\" (un guillemet) et \"a\"\"b\" admis, champ vide lu NA",
         identical(r$contrats$id_contrat, "\"") && identical(r$contrats$nature_contrat, "a\"b") &&
           identical(r$contrats$gestionnaire, NA_character_))
# Revue finale, M3 : le rétablissement des "" est linéaire au nombre de champs "" (une
# affectation par colonne). Travail plutôt qu'horloge (une durée dépend de la charge de la
# machine ; #45) : travail de .lire_table_csv (travail_de() de tests/harnais.R) aux seules
# affectations `[[<-`, taille de la table affectée comptée ; fichier de deux colonnes, "" sur
# chaque ligne. De 2 500 à 10 000 lignes, rapport 4 si une affectation par colonne ; 16 si
# une affectation par champ, qui recopie la table à chaque appel (version d'avant la revue
# finale ; mesuré). Borne 6.
assures_vides <- function(n, valeur = "\"\"") {
  dossier_avec(list(assures.csv = paste0("\"id_assure\",\"sexe\"\n",
                                         paste0("\"A", seq_len(n), "\",", valeur, "\n", collapse = ""))))
}
travail_lecture <- function(dossier) {
  travail_de(ns$.lire_table_csv, file.path(dossier, "assures.csv"), "assures",
             d$colonnes[d$colonnes$table == "assures", , drop = FALSE], ops = "[[<-")
}
r <- lire_base(assures_vides(80000L))
verifier("80 000 \"\" d'une colonne : tous rendus \"\"", identical(r$assures$sexe, rep("", 80000L)))
verifier("lire_base : travail de .lire_table_csv de 2 500 à 10 000 lignes à \"\" multiplié par moins de 6 (rétablissement linéaire : 4 ; une affectation par champ : 16)",
         travail_lecture(assures_vides(10000L)) / travail_lecture(assures_vides(2500L)) < 6)
crlf <- function(texte) gsub("\n", "\r\n", texte, fixed = TRUE)
r <- lire_base(dossier_avec(list(contrats.csv = crlf(csv_de("contrats", list(id_contrat = "\"\"", gestionnaire = "\"\""))))))
verifier("\"\" dans un fichier CRLF, en début et en fin de ligne : rendu \"\"",
         identical(r$contrats$id_contrat, "") && identical(r$contrats$gestionnaire, ""))
for (fichier in c("LF", "CRLF")) {
  texte <- csv_de("contrats", list(id_contrat = "\"A@B\""))
  if (fichier == "CRLF") texte <- crlf(texte)
  for (dans in c("\r\n", "\r")) {
    e <- refus_de(lire_base(dossier_avec(list(contrats.csv = sub("@", dans, texte, fixed = TRUE)))))
    verifier(sprintf("fichier %s : %s dans un champ entre guillemets : fichier_invalide, colonne et ligne",
                     fichier, if (dans == "\r") "CR isolé" else "CRLF"),
             !is.null(e) && e$motif == "fichier_invalide" && e$module == "lecture" && e$colonne == "id_contrat" &&
               identical(e$identifiants, "1") && grepl("texte exact", conditionMessage(e), fixed = TRUE))
  }
}
deux <- paste0(paste(colonnes_de("contrats")$colonne, collapse = ","), "\n",
               sub("^[^\n]*\n", "", csv_de("contrats", list(id_contrat = "\"A\r\nB\""))),
               sub("^[^\n]*\n", "", csv_de("contrats", list(id_contrat = "\"A\nB\""))))
e <- refus_de(lire_base(dossier_avec(list(contrats.csv = deux))))
verifier("collision d'identifiants \"A\\r\\nB\" et \"A\\nB\" : refusée (ligne 1), pas de faux doublon",
         !is.null(e) && e$motif == "fichier_invalide" && identical(e$identifiants, "1"))
e <- refus_de(lire_avec("contrats", list(id_contrat = "\"A\r\rB\"", gestionnaire = "\"C\rD\""), lignes = 2L))
verifier("retours chariot : comptés par champ (deux dans un même champ comptent un), lignes de données",
         !is.null(e) && e$nombre == 4L && identical(e$identifiants, c("1", "1", "2", "2")) &&
           e$colonne == "id_contrat")
verifier("\"A\\nB\" seul : admis, saut de ligne conservé",
         identical(lire_avec("contrats", list(id_contrat = "\"A\nB\""))$contrats$id_contrat, "A\nB"))
verifier("\"A\\nB\" dans un fichier CRLF : admis (le saut de ligne du champ reste \\n)", {
  texte <- sub("@", "\n", crlf(csv_de("contrats", list(id_contrat = "\"A@B\""))), fixed = TRUE)
  identical(lire_base(dossier_avec(list(contrats.csv = texte)))$contrats$id_contrat, "A\nB")
})

section("lecture : guillemet non fermé (fichier_invalide, sans chemin temporaire)")
cas_guillemet <- list(
  list("dernier champ ouvert, fichier fini", "id_adherent,secteur_activite\n\"A1\",\"x\n", "ligne de donn"),
  list("guillemet final après une valeur", "id_adherent,secteur_activite\nA1,x\"\n", "ligne de donn"),
  list("deuxième ligne ouverte", "id_adherent,secteur_activite\n\"A1\",x\n\"A2,y\n", "ligne de donn\u00e9es 2"),
  list("en-tête ouvert", "\"id_adherent,secteur_activite\nA1,x\n", "en-t\u00eate"))
for (cas in cas_guillemet) {
  e <- refus_de(lire_base(dossier_avec(list(adherents.csv = cas[[2L]]))))
  verifier(paste0("guillemet non fermé (", cas[[1L]], ") : fichier_invalide, « guillemet non fermé », fichier et ligne, aucun chemin"),
           !is.null(e) && e$motif == "fichier_invalide" && e$table == "adherents" &&
             grepl(u8("guillemet non ferm\u00e9"), conditionMessage(e), fixed = TRUE) &&
             grepl("adherents.csv", conditionMessage(e), fixed = TRUE) &&
             grepl(u8(cas[[3L]]), conditionMessage(e), fixed = TRUE) &&
             !grepl(tempdir(), conditionMessage(e), fixed = TRUE) &&
             !grepl("readTableHeader", conditionMessage(e), fixed = TRUE))
}
verifier("guillemet doublé dans un champ entre guillemets : pas un guillemet non fermé",
         identical(lire_base(dossier_avec(list(adherents.csv = "id_adherent,secteur_activite\n\"A\"\"1\",x\n")))$adherents$id_adherent,
                   "A\"1"))

section("lecture : localisation juste d'un fichier_invalide (réserves C1 et C3)")
entete_c <- paste(colonnes_de("contrats")$colonne, collapse = ",")
ligne_de <- function(champs = list()) sub("^[^\n]*\n", "", csv_de("contrats", champs))
e <- refus_de(lire_base(dossier_avec(list(contrats.csv = paste0(
  entete_c, "\n", sub(",[^,]*\n$", "\n", ligne_de()), ligne_de(), ligne_de(list(id_contrat = "\"A\rB\"")))))))
verifier("C1 : ligne 1 trop courte et retour chariot en ligne 3 : refus de structure, sans colonne ni ligne",
         !is.null(e) && e$motif == "fichier_invalide" && is.na(e$colonne) && length(e$identifiants) == 0L &&
           grepl("mal form", conditionMessage(e), fixed = TRUE))
e <- refus_de(lire_base(dossier_avec(list(contrats.csv = paste0(
  entete_c, "\n", ligne_de(), "\n", ligne_de(list(id_contrat = "\"\"")))))))
verifier("C1 : ligne vide puis \"\" : refus de structure (ligne vide), pas une localisation de \"\"",
         !is.null(e) && e$motif == "fichier_invalide" && is.na(e$colonne) && length(e$identifiants) == 0L)
e <- refus_de(lire_base(dossier_avec(list(contrats.csv = paste0(
  entete_c, "\n", sub("\n$", ",\"\"\n", ligne_de()), sub("\n$", ",\"\"\n", ligne_de()))))))
verifier("C1 : \"\" dans un champ en trop de chaque ligne : refus de structure (en-tête plus court), pas de colonne NA",
         !is.null(e) && e$motif == "fichier_invalide" && is.na(e$colonne) &&
           grepl("un champ de moins", conditionMessage(e), fixed = TRUE))
multi <- ligne_de(list(id_contrat = "\"a,\nb\nc\"", nature_contrat = "\"x,\ny\""))
e <- refus_de(lire_base(dossier_avec(list(contrats.csv = paste0(
  entete_c, "\n", multi, ligne_de(), ligne_de(list(gestionnaire = "\"u\rv\"")))))))
verifier("C3 : après un champ sur plusieurs lignes à virgules, retour chariot en ligne de données 3, colonne gestionnaire",
         !is.null(e) && e$motif == "fichier_invalide" && e$colonne == "gestionnaire" && identical(e$identifiants, "3"))
r <- lire_base(dossier_avec(list(contrats.csv = paste0(
  entete_c, "\n", multi, ligne_de(list(gestionnaire = "\"\"")), ligne_de()))))
verifier("C3 : après un champ sur plusieurs lignes, \"\" rétabli à sa ligne (2) et dans sa colonne",
         identical(r$contrats$gestionnaire, c("x", "", "x")) && identical(r$contrats$id_contrat[1L], "a,\nb\nc") &&
           identical(r$contrats$nature_contrat[1L], "x,\ny"))
r <- lire_base(dossier_avec(list(contrats.csv = paste0(entete_c, "\r\n", sub("\n$", "\r\n", multi),
                                                       crlf(ligne_de(list(gestionnaire = "\"\"")))))))
verifier("C3 : même cas, fins de ligne CRLF hors des champs : \"\" rétabli en ligne 2",
         identical(r$contrats$gestionnaire, c("x", "")))

section("lecture : tables, colonnes et version")
e <- refus_de(lire_avec("contrats", list()))
verifier("table extraction absente du dossier : lue sans elle (contrôle de la base entière : donnees)", is.null(e))
csv_inconnue <- sub("\n", ",inconnue\n", csv_de("contrats"), fixed = TRUE)
csv_inconnue <- sub("\n$", ",\"v\"\n", csv_inconnue)
r <- lire_base(dossier_avec(list(contrats.csv = csv_inconnue)))
verifier("colonne inconnue du dictionnaire : rendue en texte, les autres typées (plus de controler_types sur le résultat)",
         identical(r$contrats$inconnue, "v") && identical(r$contrats$mois_echeance, 1L))
col <- colonnes_de("contrats")
garde <- col$colonne != "id_contrat"
csv_sans <- paste0(paste(col$colonne[garde], collapse = ","), "\n",
                   paste(champ_valide[col$type[garde]], collapse = ","), "\n")
r <- lire_base(dossier_avec(list(contrats.csv = csv_sans)))
verifier("colonne obligatoire absente : table rendue sans elle (le contrôle des types ou de la base la refuse)",
         identical(names(r$contrats), col$colonne[garde]) &&
           identical(motif_de_refus(controler_types(r)), "colonne_absente"))
e <- refus_de(lire_avec("extraction", list(version_dictionnaire = "\"1.2\"", date_extraction = "31/12/2026")))
verifier("version 1.2 : extraction_invalide, avant le type des autres colonnes",
         !is.null(e) && e$motif == "extraction_invalide" && identical(e$recu, "1.2"))
e <- refus_de(lire_avec("extraction", list(version_dictionnaire = "\"1.4\"")))
verifier("version 1.4, version précédente : extraction_invalide, attendu 1.5, reçu 1.4",
         !is.null(e) && e$motif == "extraction_invalide" && identical(e$attendu, "1.5") &&
           identical(e$recu, "1.4"))
verifier_refus("table extraction de deux lignes : extraction_invalide",
               lire_avec("extraction", list(version_dictionnaire = "\"1.5\""), lignes = 2L),
               "extraction_invalide")
e <- refus_de(lire_avec("extraction", list(version_dictionnaire = "\"1.5\"", date_extraction = "31/12/2026")))
verifier("extraction : date illisible, refus d'appel type_incompatible (seule table contrôlée strictement à la lecture)",
         !is.null(e) && e$motif == "type_incompatible" && e$table == "extraction" && e$colonne == "date_extraction")
e <- refus_de(lire_avec("extraction", list(version_dictionnaire = "\"\"")))
verifier("extraction : version \"\" (chaîne vide) : extraction_invalide, reçu \"\"",
         !is.null(e) && e$motif == "extraction_invalide" && identical(e$recu, ""))
csv_ext <- sub("\n", ",inconnue\n", csv_de("extraction", list(version_dictionnaire = "\"1.5\"")), fixed = TRUE)
csv_ext <- sub("\n$", ",\"v\"\n", csv_ext)
verifier_refus("extraction : colonne inconnue : colonne_inconnue (refus d'appel)",
               lire_base(dossier_avec(list(extraction.csv = csv_ext))), "colonne_inconnue")
e <- refus_de(lire_base(dossier_avec(list(extraction.csv = csv_de("extraction", list(version_dictionnaire = "\"1.5\"",
                                                                                     date_extraction = "x")),
                                          contrats.csv = sub("\"x\"", "\"x", csv_de("contrats"))))))
verifier("extraction contrôlée une fois tous les fichiers lus : un fichier mal formé est refusé d'abord",
         !is.null(e) && e$motif == "fichier_invalide" && e$table == "contrats")

section("lecture : dossier et fichiers")
e <- refus_de(lire_base(dossier_avec(list(contrats.csv = csv_de("contrats"), contrat.csv = "a\n"))))
verifier("fichier inconnu du dictionnaire (contrat.csv) : fichier_invalide, fichier nommé",
         !is.null(e) && e$motif == "fichier_invalide" && identical(e$identifiants, "contrat.csv"))
verifier_refus("fichier d'une autre extension (notes.txt) : fichier_invalide",
               lire_base(dossier_avec(list(notes.txt = "x\n"))), "fichier_invalide")
verifier_refus("fichier caché : fichier_invalide", lire_base(dossier_avec(list(.cache = "x\n"))), "fichier_invalide")
x <- dossier_avec(); dir.create(file.path(x, "contrats.csv"))
verifier_refus("dossier nommé <table>.csv : fichier_invalide", lire_base(x), "fichier_invalide")
verifier_refus("dossier introuvable : fichier_invalide", lire_base(file.path(tempdir(), "absent-xyz")),
               "fichier_invalide")
x <- tempfile("fichier-"); ecrire_octets(x, "x\n")
e <- refus_de(lire_base(x))
verifier("chemin d'un fichier : fichier_invalide, « n'est pas un dossier » (pas « introuvable »)",
         !is.null(e) && e$motif == "fichier_invalide" && grepl("n'est pas un dossier", conditionMessage(e), fixed = TRUE))
csv_virgule <- sub("^id_contrat", "\"id,contrat\"", csv_de("contrats"))
r <- lire_base(dossier_avec(list(contrats.csv = csv_virgule)))
verifier("nom d'en-tête entre guillemets avec une virgule : colonne « id,contrat » (en-tête bien lu), pas fichier mal formé",
         identical(names(r$contrats)[1L], "id,contrat") && identical(r$contrats[[1L]], "x"))
csv_guillemet <- sub("^id_contrat", "\"id\"\"contrat\"", csv_de("contrats"))
r <- lire_base(dossier_avec(list(contrats.csv = csv_guillemet)))
verifier("nom d'en-tête avec un guillemet doublé : colonne « id\"contrat »",
         identical(names(r$contrats)[1L], "id\"contrat"))
verifier_refus("chemin qui n'est pas une chaîne unique : fichier_invalide", lire_base(c("a", "b")),
               "fichier_invalide")
verifier("dossier vide : base vide", identical(lire_base(dossier_avec()), list()))

section("lecture : fichiers mal formés, refusés (fichier_invalide)")
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
  verifier_refus(cas, lire_base(dossier_avec(list(contrats.csv = mal_formes[[cas]]))), "fichier_invalide")
}

section("lecture : en-tête (réserve C2 : message juste, texte exact des noms)")
message_de <- function(texte) {
  e <- refus_de(lire_base(dossier_avec(list(contrats.csv = texte))))
  if (is.null(e)) "aucun" else paste(e$motif, conditionMessage(e))
}
verifier("première ligne vide : fichier_invalide, « première ligne vide », pas « un champ de moins »",
         grepl("^fichier_invalide .*re ligne vide ; l'en-t", message_de(paste0("\n", valide))) &&
           !grepl("un champ de moins", message_de(paste0("\n", valide)), fixed = TRUE))
verifier("en-tête d'un champ de moins : « un champ de moins que les lignes de données »",
         grepl("^fichier_invalide .*un champ de moins", message_de(sub("^id_contrat,", "", valide))))
r <- lire_base(dossier_avec(list(contrats.csv = sub("^id_contrat,nature_contrat", "id_contrat , nature_contrat", valide))))
verifier("espaces autour d'un nom : noms rendus au texte exact de l'en-tête (« id_contrat  », «  nature_contrat »), pas de refus",
         identical(names(r$contrats)[1:2], c("id_contrat ", " nature_contrat")) &&
           identical(r$contrats[["id_contrat "]], "x"))
verifier("nom de colonne vide dans l'en-tête : fichier_invalide",
         grepl("^fichier_invalide .*nom de colonne vide", message_de(sub("^id_contrat", "", valide))))
verifier("\"\" dans l'en-tête : fichier_invalide (nom de colonne vide)",
         grepl("^fichier_invalide .*nom de colonne vide", message_de(sub("^id_contrat", "\"\"", valide))))
verifier("nom de colonne en double : fichier_invalide, nom cité",
         grepl("^fichier_invalide .*en double : id_contrat",
               message_de(sub("^id_contrat,nature_contrat", "id_contrat,id_contrat", valide))))
verifier("retour chariot dans un nom entre guillemets : fichier_invalide (en-tête)",
         grepl("^fichier_invalide .*en-t", message_de(sub("^id_contrat", "\"id\rcontrat\"", valide))))

# --- Écriture : refus avant toute écriture ---------------------------------------------------

section("lecture : ecrire_base(), refus")
b <- base["contrats"]
verifier_refus("type incompatible (integer reçu en numeric) : type_incompatible, par controler_types()",
               { b$contrats$mois_echeance <- as.numeric(b$contrats$mois_echeance)
                 ecrire_base(b, tempfile("base-")) }, "type_incompatible")
x <- tempfile("base-")
b <- base["contrats"]; b$contrats$id_contrat[1L] <- ""
e <- refus_de(ecrire_base(b, x))
verifier("chaîne vide \"\" : liste_invalide (hors domaine, une base écrite est conforme), colonne nommée",
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
verifier_refus("dossier existant non vide : fichier_invalide", ecrire_base(base["contrats"], x), "fichier_invalide")
x <- tempfile("fichier-"); ecrire_octets(x, "x\n")
verifier_refus("chemin d'un fichier : fichier_invalide", ecrire_base(base["contrats"], x), "fichier_invalide")
verifier_refus("parent du dossier absent : fichier_invalide",
               ecrire_base(base["contrats"], file.path(tempfile("absent-"), "base")), "fichier_invalide")
verifier_refus("chemin qui n'est pas une chaîne unique : fichier_invalide", ecrire_base(base["contrats"], NA_character_),
               "fichier_invalide")
x <- dossier_avec()
verifier("dossier existant vide : admis", identical(lire_base(ecrire_base(base["contrats"], x)), base["contrats"]))
