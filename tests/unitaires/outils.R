# Tests unitaires du module `outils` (R/outils.R). Exécuté par tests/test_unitaires.R :
# le package est installé et chargé, le harnais est sourcé, `racine` est défini.
# Les chaînes accentuées se construisent par intToUtf8() : un littéral \u dans un script
# lu sous une locale C n'est pas fiable (mesure du 7 novembre 2026, R 4.3.3).

outils <- asNamespace("provie")
refuser <- outils$refuser
avec_graine <- outils$avec_graine
empreinte <- outils$empreinte
ecrire_valeurs <- outils$ecrire_valeurs
ecrire_liste <- outils$ecrire_liste
lire_liste <- outils$lire_liste
decrire_plateforme <- outils$decrire_plateforme

e_aigu <- intToUtf8(233L)
chaine_riche <- intToUtf8(c(171L, 8364L, 233L, 187L))   # « € é »

# Motif du refus levé par `expr`, ou "aucun" / "autre" ; l'appel passe par le gestionnaire
# de classe, comme le feront les appelants.
motif_de <- function(expr) {
  tryCatch({ expr; "aucun" }, refus_provie = function(e) e$motif, error = function(e) "autre")
}

section("outils : constantes")
verifier_egal("VERSION_FICHE", outils$VERSION_FICHE, 1L)
verifier_egal("VERSION_DICTIONNAIRE_ATTENDUE", outils$VERSION_DICTIONNAIRE_ATTENDUE, "1.5")
verifier_egal("REPRESENTATION_CANONIQUE", outils$REPRESENTATION_CANONIQUE, "provie-resultat-1")
verifier_egal("VERSION_LISTE", outils$VERSION_LISTE, 1L)
verifier("MOTIFS_REFUS : dix-huit motifs distincts en minuscules et soulignés",
         length(outils$MOTIFS_REFUS) == 18L && !anyDuplicated(outils$MOTIFS_REFUS) &&
           all(grepl("^[a-z_]+$", outils$MOTIFS_REFUS)))
verifier("MOTIFS_REFUS contient les motifs de l'ADR 0010, point 11, et fichier_invalide (M141)",
         all(c("plan_incomplet", "plan_invalide", "liste_invalide", "fichier_invalide", "table_base_absente",
               "colonne_absente", "colonne_inconnue", "type_incompatible",
               "extraction_invalide", "arrete_posterieur_extraction",
               "declaration_manquante", "table_absente", "empreinte_discordante",
               "version_discordante", "lien_non_declare", "catalogue_invalide",
               "dictionnaire_invalide", "format_table_inconnu") %in% outils$MOTIFS_REFUS))

section("outils : refuser")
verifier_refus("refuser lève un refus de motif donné", refuser("message", "plan_invalide"),
               "plan_invalide")
condition <- tryCatch(refuser("manque la colonne x", "colonne_absente", module = "donnees",
                              table = "contrats", colonne = "x", usage = "u", nombre = 3L,
                              identifiants = as.character(1:25), attendu = "x", recu = "y"),
                      refus_provie = function(e) e)
verifier_egal("classe de la condition", class(condition),
              c("refus_provie", "error", "condition"))
verifier_egal("champs de la condition, dans l'ordre", names(condition),
              c("message", "call", "motif", "module", "table", "colonne", "usage", "nombre",
                "identifiants", "attendu", "recu"))
verifier_egal("conditionMessage", conditionMessage(condition), "manque la colonne x")
verifier_egal("identifiants tronqués à dix", condition$identifiants, as.character(1:10))
verifier_egal("nombre reste le total", condition$nombre, 3L)
verifier_egal("champs renseignés", unlist(condition[c("module", "table", "colonne", "usage",
                                                      "attendu", "recu")]),
              c(module = "donnees", table = "contrats", colonne = "x", usage = "u",
                attendu = "x", recu = "y"))
defauts <- tryCatch(refuser("m", "plan_incomplet"), refus_provie = function(e) e)
verifier("champs par défaut : NA et vide",
         is.na(defauts$module) && is.na(defauts$table) && is.na(defauts$colonne) &&
           is.na(defauts$usage) && is.na(defauts$nombre) && is.integer(defauts$nombre) &&
           identical(defauts$identifiants, character(0)))
verifier_egal("un refus est aussi une erreur",
              tryCatch(refuser("m", "plan_invalide"), error = function(e) "erreur"), "erreur")
verifier_egal("motif hors liste : erreur ordinaire, pas un refus",
              motif_de(refuser("m", "motif_inconnu")), "autre")
verifier_egal("message non chaîne : erreur ordinaire", motif_de(refuser(1, "plan_invalide")),
              "autre")

for (motif in outils$MOTIFS_REFUS) {
  verifier_refus(paste("refuser : un refus du motif", motif, "est attrapé par refus_provie"),
                 refuser("m", motif), motif)
  verifier_egal(paste("tryCatch(refus_provie = ) rend le motif", motif),
                tryCatch(refuser("m", motif), refus_provie = function(e) e$motif), motif)
}
verifier_egal("module de longueur 2 : erreur ordinaire",
              motif_de(refuser("m", "plan_invalide", module = c("a", "b"))), "autre")
verifier_egal("module non chaîne : erreur ordinaire",
              motif_de(refuser("m", "plan_invalide", module = 1)), "autre")
verifier_egal("table de longueur 0 : erreur ordinaire",
              motif_de(refuser("m", "plan_invalide", table = character(0))), "autre")
verifier_egal("colonne de longueur 2 : erreur ordinaire",
              motif_de(refuser("m", "plan_invalide", colonne = c("a", "b"))), "autre")
verifier_egal("usage de longueur 2 : erreur ordinaire",
              motif_de(refuser("m", "plan_invalide", usage = c("a", "b"))), "autre")
verifier_egal("nombre non entier (2.7) : erreur ordinaire",
              motif_de(refuser("m", "plan_invalide", nombre = 2.7)), "autre")
verifier_egal("nombre de longueur 2 : erreur ordinaire",
              motif_de(refuser("m", "plan_invalide", nombre = 1:2)), "autre")
verifier_egal("nombre chaîne : erreur ordinaire",
              motif_de(refuser("m", "plan_invalide", nombre = "3")), "autre")
verifier_egal("nombre hors des bornes entières : erreur ordinaire",
              motif_de(refuser("m", "plan_invalide", nombre = 2^31)), "autre")
verifier_egal("nombre réel entier (3) accepté et converti",
              tryCatch(refuser("m", "plan_invalide", nombre = 3), refus_provie = function(e) e$nombre), 3L)
verifier_egal("nombre NA logique accepté (NA entier)",
              tryCatch(refuser("m", "plan_invalide", nombre = NA), refus_provie = function(e) e$nombre),
              NA_integer_)
verifier_egal("nombre NA chaîne accepté (NA entier)",
              tryCatch(refuser("m", "plan_invalide", nombre = NA_character_),
                       refus_provie = function(e) e$nombre), NA_integer_)
verifier_egal("nombre NaN : erreur ordinaire",
              motif_de(refuser("m", "plan_invalide", nombre = NaN)), "autre")
verifier_egal("nombre infini : erreur ordinaire",
              motif_de(refuser("m", "plan_invalide", nombre = Inf)), "autre")
verifier_egal("attendu de longueur 2 : erreur ordinaire",
              motif_de(refuser("m", "plan_invalide", attendu = c("a", "b"))), "autre")
verifier_egal("recu de longueur 0 : erreur ordinaire",
              motif_de(refuser("m", "plan_invalide", recu = character(0))), "autre")
verifier_egal("identifiants liste : erreur ordinaire",
              motif_de(refuser("m", "plan_invalide", identifiants = list(1))), "autre")

section("outils : empreinte")
verifier_egal("MD5 de abc", empreinte(charToRaw("abc")), "900150983cd24fb0d6963f7d28e17f72")
verifier_egal("MD5 du vide", empreinte(raw(0)), "d41d8cd98f00b204e9800998ecf8427e")
verifier("empreinte : 32 hexadécimaux minuscules, sans nom",
         grepl("^[0-9a-f]{32}$", empreinte(as.raw(0:255))) && is.null(names(empreinte(raw(1)))))
verifier("empreinte déterministe et sensible à un octet",
         identical(empreinte(as.raw(0:255)), empreinte(as.raw(0:255))) &&
           !identical(empreinte(as.raw(0:255)), empreinte(as.raw(c(0:254, 0L)))))
verifier_egal("empreinte n'accepte que du raw", motif_de(empreinte("abc")), "autre")
set.seed(1)
graine_avant <- .Random.seed
invisible(empreinte(raw(10)))
verifier("empreinte ne touche pas à .Random.seed", identical(.Random.seed, graine_avant))
fichiers_avant <- list.files(tempdir())
invisible(empreinte(raw(10)))
verifier("empreinte ne laisse aucun fichier temporaire",
         identical(list.files(tempdir()), fichiers_avant))

section("outils : ecrire_valeurs")
verifier_egal("texte logical", ecrire_valeurs(c(TRUE, FALSE, NA)), c("T", "F", "NA"))
verifier_egal("texte integer", ecrire_valeurs(c(1L, -20L, NA)), c("1", "-20", "NA"))
verifier_egal("texte double %.17g", ecrire_valeurs(c(0.1, 1.5, 1e-300, 1e22)),
              c("0.10000000000000001", "1.5", "1e-300", "1e+22"))
verifier_egal("texte double : jetons des non-finis", ecrire_valeurs(c(NA, NaN, Inf, -Inf)),
              c("NA", "NaN", "Inf", "-Inf"))
verifier_egal("texte double : -0 s'écrit 0", ecrire_valeurs(c(-0, 0)), c("0", "0"))
verifier_egal("texte character : échappements",
              ecrire_valeurs(c("a\tb", "a\nb", "a\\b", "a\rb", "a\001b", "a\177b", NA, "")),
              c("a\\tb", "a\\nb", "a\\\\b", "a\\rb", "a\\x01b", "a\\x7fb", "\\N", ""))
verifier_egal("texte character : UTF-8 écrit tel quel", ecrire_valeurs(chaine_riche),
              chaine_riche)
verifier_egal("texte Date : ISO 8601", ecrire_valeurs(as.Date(c("2026-11-07", NA, "0999-01-31"))),
              c("2026-11-07", "NA", "0999-01-31"))
for (modele in list(logical(0), integer(0), double(0), character(0), as.Date(character(0)))) {
  verifier_egal(paste("vecteur vide", class(modele)[1L], ": texte = character(0)"),
                ecrire_valeurs(modele), character(0))
  verifier_egal(paste("vecteur vide", class(modele)[1L], ": octets = raw(0)"),
                ecrire_valeurs(modele, "octets"), raw(0))
}
verifier_egal("octets logical", ecrire_valeurs(c(FALSE, TRUE, NA), "octets"), as.raw(0:2))
verifier_egal("octets integer petit-boutiste", ecrire_valeurs(c(1L, NA), "octets"),
              as.raw(c(1, 0, 0, 0, 0, 0, 0, 0x80)))
verifier_egal("octets double : 1", ecrire_valeurs(1, "octets"),
              as.raw(c(0, 0, 0, 0, 0, 0, 0xf0, 0x3f)))
verifier_egal("octets double : NA, NaN, Inf, -Inf",
              ecrire_valeurs(c(NA, NaN, Inf, -Inf), "octets"),
              as.raw(c(0xa2, 7, 0, 0, 0, 0, 0xf0, 0x7f,
                       0, 0, 0, 0, 0, 0, 0xf8, 0x7f,
                       0, 0, 0, 0, 0, 0, 0xf0, 0x7f,
                       0, 0, 0, 0, 0, 0, 0xf0, 0xff)))
verifier_egal("octets double : -0 comme 0", ecrire_valeurs(-0, "octets"),
              ecrire_valeurs(0, "octets"))
verifier_egal("octets double : NaN de signe négatif ramené au motif fixe",
              ecrire_valeurs(0 / 0, "octets"), ecrire_valeurs(NaN, "octets"))
verifier_egal("octets character : longueur puis octets UTF-8, NA = 0xFFFFFFFF",
              ecrire_valeurs(c(e_aigu, NA, ""), "octets"),
              as.raw(c(2, 0, 0, 0, 0xc3, 0xa9, 0xff, 0xff, 0xff, 0xff, 0, 0, 0, 0)))
verifier_egal("octets Date : chaîne ISO", ecrire_valeurs(as.Date("2026-11-07"), "octets"),
              ecrire_valeurs("2026-11-07", "octets"))
verifier_egal("forme inconnue : erreur ordinaire", motif_de(ecrire_valeurs(1, "xml")), "autre")
verifier_egal("facteur refusé", motif_de(ecrire_valeurs(factor("a"))), "liste_invalide")
verifier_egal("liste imbriquée sans noms refusée", motif_de(ecrire_liste(list(a = list(1, 2)))),
              "liste_invalide")
verifier("liste imbriquée sans noms : le message désigne l'absence de noms, pas des attributs",
         grepl("noms", tryCatch(ecrire_liste(list(a = list(1, 2))), refus_provie = conditionMessage)) &&
           !grepl("attributs", tryCatch(ecrire_liste(list(a = list(1, 2))), refus_provie = conditionMessage)))
verifier("liste imbriquée avec attribut : le message désigne les attributs",
         grepl("attributs non admis", tryCatch(ecrire_liste(list(a = structure(list(b = 1), classe = "x"))),
                                               refus_provie = conditionMessage)))
verifier_egal("vecteur nommé refusé", motif_de(ecrire_valeurs(c(a = 1))), "liste_invalide")
verifier_egal("matrice refusée", motif_de(ecrire_valeurs(matrix(1:4, 2))), "liste_invalide")
verifier_egal("Date non finie refusée", motif_de(ecrire_valeurs(as.Date(Inf))), "liste_invalide")
verifier_egal("Date NaN refusée (texte)",
              motif_de(ecrire_valeurs(structure(NaN, class = "Date"))), "liste_invalide")
verifier_egal("Date NaN refusée (octets)",
              motif_de(ecrire_valeurs(structure(c(0, NaN), class = "Date"), "octets")), "liste_invalide")
verifier_egal("Date NaN refusée (liste)",
              motif_de(ecrire_liste(list(d = structure(NaN, class = "Date")))), "liste_invalide")
verifier_egal("Date fractionnaire refusée",
              motif_de(ecrire_valeurs(structure(0.5, class = "Date"))), "liste_invalide")
verifier_egal("année à cinq chiffres refusée",
              motif_de(ecrire_valeurs(as.Date("9999-12-31") + 1)), "liste_invalide")
verifier_egal("Date de l'an 999 : aller-retour par la liste",
              lire_liste(ecrire_liste(list(d = as.Date("0999-01-31"))))$d, as.Date("0999-01-31"))

section("outils : ecrire_liste / lire_liste")
liste_riche <- list(
  entier = 1:3, reel = c(0.1, -0, 1e-300, 1e22, NA, NaN, Inf, -Inf),
  logique = c(TRUE, NA, FALSE), texte = c(e_aigu, "a\tb\nc\\d", NA, "", chaine_riche),
  date = as.Date(c("2026-11-07", NA)), vide_c = character(0), vide_d = double(0),
  vide_i = integer(0), vide_l = logical(0), liste_vide = list(), rien = NULL,
  noeud = list(a = 1.5, b = list(c = "x", d = list(e = TRUE))),
  `nom/avec\ttab` = 7L)
names(liste_riche)[length(liste_riche)] <- paste0("n/", e_aigu, "\t", "\\")
octets <- ecrire_liste(liste_riche)
verifier("ecrire_liste rend du raw", is.raw(octets))
verifier_egal("aller-retour identical (liste riche)", lire_liste(octets), liste_riche)
verifier_egal("seconde écriture : mêmes octets", ecrire_liste(lire_liste(octets)), octets)
verifier_egal("liste vide : aller-retour", lire_liste(ecrire_liste(list())), list())
verifier_egal("écriture d'une petite liste",
              rawToChar(ecrire_liste(list(a = 0.1, b = list(c = 1:2, d = "x\ty"), e = NULL))),
              paste0("provie-liste 1\n", "a\tdouble\t0.10000000000000001\n",
                     "b/c\tinteger\t1\t2\n", "b/d\tcharacter\tx\\ty\n", "e\tnull\n"))
verifier_egal("nom contenant « / » : échappé dans le chemin",
              strsplit(rawToChar(ecrire_liste(setNames(list(1L), "a/b"))), "\n")[[1L]][2L],
              "a\\x2fb\tinteger\t1")
verifier("aller-retour de decrire_plateforme()",
         identical(lire_liste(ecrire_liste(decrire_plateforme())), decrire_plateforme()))
# Sys.info() peut rendre NULL (documenté par R) ; extSoftVersion() peut omettre un composant
plateforme_avec <- function(sys_info, logiciels = NULL) {
  f <- decrire_plateforme
  environment(f) <- list2env(
    c(list(Sys.info = function() sys_info),
      if (!is.null(logiciels)) list(extSoftVersion = function() logiciels)),
    parent = asNamespace("provie"))
  f()
}
p_nul <- plateforme_avec(NULL)
verifier_egal("Sys.info() NULL : systeme, version_systeme et machine valent NA_character_",
              p_nul[c("systeme", "version_systeme", "machine")],
              list(systeme = NA_character_, version_systeme = NA_character_, machine = NA_character_))
verifier_egal("Sys.info() NULL : les autres champs et l'ordre sont inchangés",
              names(p_nul), names(decrire_plateforme()))
verifier_egal("Sys.info() NULL : sérialisable, aller-retour identique", lire_liste(ecrire_liste(p_nul)), p_nul)
verifier_egal("Sys.info() partiel : champ présent conservé, absents NA",
              plateforme_avec(c(sysname = "Linux"))[c("systeme", "version_systeme", "machine")],
              list(systeme = "Linux", version_systeme = NA_character_, machine = NA_character_))
verifier_egal("extSoftVersion() sans BLAS ni ICU : NA_character_",
              plateforme_avec(NULL, c(PCRE = "10.42"))[c("blas", "pcre", "icu")],
              list(blas = NA_character_, pcre = "10.42", icu = NA_character_))
verifier("decrire_plateforme() : tous les champs sont des chaînes de longueur 1",
         all(vapply(decrire_plateforme(), function(v) is.character(v) && length(v) == 1L, NA)))
verifier_egal("liste sans nom refusée", motif_de(ecrire_liste(list(1, 2))), "liste_invalide")
verifier_egal("noms en double refusés", motif_de(ecrire_liste(list(a = 1, a = 2))),
              "liste_invalide")
verifier_egal("nom vide refusé", motif_de(ecrire_liste(setNames(list(1, 2), c("a", "")))),
              "liste_invalide")
verifier_egal("nom manquant refusé", motif_de(ecrire_liste(setNames(list(1, 2), c("a", NA)))),
              "liste_invalide")
verifier_egal("non-liste refusée", motif_de(ecrire_liste(1:3)), "liste_invalide")
verifier_egal("data.frame refusé", motif_de(ecrire_liste(list(d = data.frame(a = 1)))),
              "liste_invalide")
verifier_egal("attribut sur une liste refusé",
              motif_de(ecrire_liste(structure(list(a = 1), classe = "x"))), "liste_invalide")
verifier_egal("fonction refusée", motif_de(ecrire_liste(list(f = mean))), "liste_invalide")
verifier_egal("vecteur nommé refusé", motif_de(ecrire_liste(list(v = c(a = 1)))),
              "liste_invalide")
verifier_egal("facteur refusé", motif_de(ecrire_liste(list(v = factor("a")))), "liste_invalide")

entete <- "provie-liste 1\n"
brut <- function(texte) charToRaw(texte)
verifier_egal("liste vide nommée refusée en tête",
              motif_de(ecrire_liste(setNames(list(), character(0)))), "liste_invalide")
verifier_egal("liste vide nommée refusée en feuille",
              motif_de(ecrire_liste(list(a = setNames(list(), character(0))))), "liste_invalide")
verifier_egal("Date vide : aller-retour par la liste",
              lire_liste(ecrire_liste(list(d = as.Date(character(0)))))$d, as.Date(character(0)))

section("outils : lire_liste refuse ce qui n'a pas la forme")
verifier_egal("non raw", motif_de(lire_liste("a")), "liste_invalide")
verifier_egal("octet nul", motif_de(lire_liste(as.raw(c(0x61, 0)))), "liste_invalide")
verifier_egal("vide", motif_de(lire_liste(raw(0))), "liste_invalide")
verifier_egal("sans fin de ligne finale", motif_de(lire_liste(brut("provie-liste 1\na\tinteger\t1"))),
              "liste_invalide")
verifier_egal("en-tête absent", motif_de(lire_liste(brut("a\tinteger\t1\n"))), "liste_invalide")
verifier_egal("version 2 : version_discordante",
              motif_de(lire_liste(brut("provie-liste 2\n"))), "version_discordante")
verifier_egal("UTF-8 invalide", motif_de(lire_liste(c(brut(entete), as.raw(c(0x61, 0xff)),
                                                      brut("\ttexte\n")))), "liste_invalide")
verifier_egal("seul l'en-tête : liste vide", lire_liste(brut(entete)), list())
verifier_egal("type inconnu", motif_de(lire_liste(brut(paste0(entete, "a\tcomplexe\t1\n")))),
              "liste_invalide")
verifier_egal("ligne sans type", motif_de(lire_liste(brut(paste0(entete, "a\n")))),
              "liste_invalide")
verifier_egal("ligne vide", motif_de(lire_liste(brut(paste0(entete, "\n")))), "liste_invalide")
verifier_egal("chemin avec segment vide", motif_de(lire_liste(brut(paste0(entete, "a//b\tnull\n")))),
              "liste_invalide")
verifier_egal("réel mal formé", motif_de(lire_liste(brut(paste0(entete, "a\tdouble\t1,5\n")))),
              "liste_invalide")
verifier_egal("réel : évaluation refusée",
              motif_de(lire_liste(brut(paste0(entete, "a\tdouble\tstop(1)\n")))), "liste_invalide")
verifier_egal("entier hors bornes",
              motif_de(lire_liste(brut(paste0(entete, "a\tinteger\t2147483648\n")))),
              "liste_invalide")
verifier_egal("logique mal formé", motif_de(lire_liste(brut(paste0(entete, "a\tlogical\tTRUE\n")))),
              "liste_invalide")
verifier_egal("date inexistante",
              motif_de(lire_liste(brut(paste0(entete, "a\tdate\t2026-02-30\n")))), "liste_invalide")
verifier_egal("date mal formée", motif_de(lire_liste(brut(paste0(entete, "a\tdate\t7/11/2026\n")))),
              "liste_invalide")
verifier_egal("échappement inconnu", motif_de(lire_liste(brut(paste0(entete, "a\tcharacter\ta\\qb\n")))),
              "liste_invalide")
verifier_egal("échappement \\x00", motif_de(lire_liste(brut(paste0(entete, "a\tcharacter\ta\\x00b\n")))),
              "liste_invalide")
verifier_egal("valeur sur une feuille null",
              motif_de(lire_liste(brut(paste0(entete, "a\tnull\t1\n")))), "liste_invalide")
verifier_egal("chemin dupliqué",
              motif_de(lire_liste(brut(paste0(entete, "a\tinteger\t1\na\tinteger\t2\n")))),
              "liste_invalide")
verifier_egal("feuille sous une feuille",
              motif_de(lire_liste(brut(paste0(entete, "a\tinteger\t1\na/b\tinteger\t2\n")))),
              "liste_invalide")
verifier_egal("feuille liste vide sous une feuille",
              motif_de(lire_liste(brut(paste0(entete, "a\tliste\na/b\tinteger\t2\n")))),
              "liste_invalide")
# deux écritures d'un même nom (a, \x61) désignent le même noeud : refus liste_invalide,
# jamais une erreur ordinaire d'insertion (contrôle des ancêtres sur les noms décodés)
for (feuille in c("null", "liste", "integer\t1", "double\t1.5", "logical\tT", "character\tx",
                  "date\t2020-01-01")) {
  verifier_egal(paste0("alias : feuille ", sub("\t.*$", "", feuille), " sous un alias de son nom"),
                motif_de(lire_liste(brut(paste0(entete, "a\t", feuille, "\n\\x61/b\tnull\n")))),
                "liste_invalide")
  verifier_egal(paste0("alias : feuille ", sub("\t.*$", "", feuille), ", alias sous le nom en clair"),
                motif_de(lire_liste(brut(paste0(entete, "\\x61\t", feuille, "\na/b\tnull\n")))),
                "liste_invalide")
}
verifier_egal("alias : doublon par alias",
              motif_de(lire_liste(brut(paste0(entete, "a\tinteger\t1\n\\x61\tinteger\t2\n")))),
              "liste_invalide")
verifier_egal("alias : doublon par alias en profondeur",
              motif_de(lire_liste(brut(paste0(entete, "x/a\tinteger\t1\nx/\\x61\tinteger\t2\n")))),
              "liste_invalide")
verifier_egal("alias : ancêtre d'une Date, en profondeur",
              motif_de(lire_liste(brut(paste0(entete, "x/a\tdate\t2020-01-01\nx/\\x61/b\tnull\n")))),
              "liste_invalide")
verifier_egal("un nom contenant « / » n'est pas l'ancêtre d'un chemin",
              names(lire_liste(brut(paste0(entete, "a\\x2fb\tinteger\t1\na\tinteger\t2\n")))),
              c("a/b", "a"))
verifier_egal("lecture sans évaluation : un nom qui ressemble à du code reste un nom",
              names(lire_liste(brut(paste0(entete, "system('x')\tinteger\t1\n")))), "system('x')")

section("outils : lire_liste est stricte (texte non canonique refusé)")
verifier_egal("\\xe9 pour un caractère imprimable",
              motif_de(lire_liste(brut(paste0(entete, "a\tcharacter\t\\xe9\n")))), "liste_invalide")
verifier_egal("1.50 au lieu de 1.5", motif_de(lire_liste(brut(paste0(entete, "a\tdouble\t1.50\n")))),
              "liste_invalide")
verifier_egal("0.1 au lieu de 0.10000000000000001",
              motif_de(lire_liste(brut(paste0(entete, "a\tdouble\t0.1\n")))), "liste_invalide")
verifier_egal("entier 01", motif_de(lire_liste(brut(paste0(entete, "a\tinteger\t01\n")))),
              "liste_invalide")
verifier_egal("entier -0", motif_de(lire_liste(brut(paste0(entete, "a\tinteger\t-0\n")))),
              "liste_invalide")
verifier_egal("réel -0 (canonique : 0)", motif_de(lire_liste(brut(paste0(entete, "a\tdouble\t-0\n")))),
              "liste_invalide")
verifier_egal("chemins entrelacés (a/x, b, a/z)",
              motif_de(lire_liste(brut(paste0(entete, "a/x\tinteger\t1\nb\tinteger\t2\na/z\tinteger\t3\n")))),
              "liste_invalide")
verifier_egal("nom échappé \\x41 pour un caractère imprimable",
              motif_de(lire_liste(brut(paste0(entete, "\\x41\tinteger\t1\n")))), "liste_invalide")
verifier_egal("retour chariot en fin de ligne", motif_de(lire_liste(brut(paste0(entete, "a\tinteger\t1\r\n")))),
              "liste_invalide")
verifier_egal("tabulation finale en trop", motif_de(lire_liste(brut(paste0(entete, "a\tnull\t\n")))),
              "liste_invalide")
verifier_egal("la forme canonique du même contenu passe",
              names(lire_liste(brut(paste0(entete, "a\tdouble\t1.5\nb\tcharacter\tx\n")))), c("a", "b"))
verifier("ecrire_liste(lire_liste(o)) == o sur plusieurs textes canoniques",
         all(vapply(list(liste_riche, list(a = 1L), list(), list(x = list(y = NULL))),
                    function(l) identical(ecrire_liste(lire_liste(ecrire_liste(l))), ecrire_liste(l)), NA)))

section("outils : avec_graine")
verifier_egal("valeurs sous la graine 42 (Mersenne-Twister, Inversion, Rejection)",
              avec_graine(42L, runif(3)),
              c(0.914806043496355, 0.937075413297862, 0.286139534786344), tolerance = 1e-14)
verifier_egal("deux appels identiques", avec_graine(7L, rnorm(5)), avec_graine(7L, rnorm(5)))
verifier("graines différentes, tirages différents",
         !identical(avec_graine(1L, runif(3)), avec_graine(2L, runif(3))))
verifier_egal("valeur de l'expression rendue", avec_graine(1L, "ok"), "ok")
verifier_egal("graine réelle entière acceptée", avec_graine(5, runif(1)), avec_graine(5L, runif(1)))
verifier_egal("graine non entière : erreur ordinaire", motif_de(avec_graine(1.5, 1)), "autre")
verifier_egal("graine NA : erreur ordinaire", motif_de(avec_graine(NA, 1)), "autre")
verifier_egal("graine multiple : erreur ordinaire", motif_de(avec_graine(1:2, 1)), "autre")

set.seed(123)
etat_avant <- .Random.seed
genres_avant <- RNGkind()
invisible(avec_graine(99L, runif(10)))
verifier("état global restauré : .Random.seed identique", identical(.Random.seed, etat_avant))
verifier_egal("état global restauré : genres identiques", RNGkind(), genres_avant)
tirage_suivant <- runif(2)
set.seed(123)
verifier_egal("le tirage suivant est celui qu'on aurait eu sans l'appel", tirage_suivant, runif(2))

invisible(tryCatch(avec_graine(99L, { runif(3); stop("boum") }), error = function(e) NULL))
set.seed(123)
etat_avant <- .Random.seed
invisible(tryCatch(avec_graine(99L, { runif(3); stop("boum") }), error = function(e) NULL))
verifier("état global restauré même en erreur", identical(.Random.seed, etat_avant))

RNGkind("Wichmann-Hill", "Inversion", "Rejection")
set.seed(5)
etat_avant <- .Random.seed
invisible(avec_graine(99L, runif(3)))
verifier_egal("genre d'un appelant différent restauré", RNGkind()[1L], "Wichmann-Hill")
verifier("état d'un appelant différent restauré", identical(.Random.seed, etat_avant))
RNGkind("Mersenne-Twister", "Inversion", "Rejection")

# Appelant sous l'echantillonneur "Rounding" : le retablir emet un avertissement de R, seul
# etouffe (decision du mainteneur du 7 novembre 2026). Installer "Rounding" exige
# suppressWarnings() sous warn = 2.
suppressWarnings(RNGkind("Mersenne-Twister", "Inversion", "Rounding"))
set.seed(5)
etat_avant <- .Random.seed
genres_avant <- RNGkind()
verifier("restauration depuis Rounding : aucune erreur sous warn = 2",
         is.numeric(avec_graine(99L, runif(3))))
verifier_egal("restauration depuis Rounding : genres exacts", RNGkind(), genres_avant)
verifier("restauration depuis Rounding : .Random.seed exact", identical(.Random.seed, etat_avant))
verifier("restauration depuis Rounding en erreur : aucune erreur de restauration, etat exact",
         {
           r <- tryCatch(avec_graine(99L, stop("boum")), error = function(e) conditionMessage(e))
           identical(r, "boum") && identical(RNGkind(), genres_avant) && identical(.Random.seed, etat_avant)
         })
RNGkind("Mersenne-Twister", "Inversion", "Rejection")

# Appelant sous un autre genre qui avertit au retablissement ("Buggy Kinderman-Ramage") : seul
# "Rounding" est etouffe (decision du mainteneur du 7 novembre 2026), donc l'avertissement
# REMONTE (erreur sous warn = 2) ; .Random.seed de l'appelant est neanmoins retabli.
suppressWarnings(RNGkind(normal.kind = "Buggy Kinderman-Ramage"))
set.seed(5)
etat_avant <- .Random.seed
genres_avant <- RNGkind()
message_restauration <- tryCatch({ avec_graine(99L, runif(2)); "aucune erreur" },
                                 error = function(e) conditionMessage(e))
verifier("restauration depuis un genre autre que Rounding : l'avertissement remonte (erreur sous warn = 2)",
         grepl("Kinderman-Ramage", message_restauration, fixed = TRUE))
verifier("restauration en echec : .Random.seed de l'appelant tout de meme retabli",
         identical(.Random.seed, etat_avant))
verifier_egal("restauration en echec : genres de l'appelant retablis", RNGkind(), genres_avant)
suppressWarnings(RNGkind("Mersenne-Twister", "Inversion", "Rejection"))

rm(".Random.seed", envir = globalenv())
invisible(avec_graine(99L, runif(3)))
verifier("sans graine préalable : aucune graine laissée", !exists(".Random.seed", envir = globalenv()))

exterieur <- avec_graine(1L, {
  a <- runif(1)
  invisible(avec_graine(2L, runif(1)))
  c(a, runif(1))
})
verifier_egal("appels imbriqués : l'extérieur reprend sa suite", exterieur,
              avec_graine(1L, runif(2)))

section("outils : chaînes d'encodage inconnu sous la locale C (refus, pas de corruption)")
# Sous LC_ALL=C, une chaîne non ASCII non marquée est refusée (liste_invalide) ; la même chaîne
# marquée UTF-8 passe et son empreinte est celle qu'on obtient sous la locale du processus.
script_c <- tempfile(fileext = ".R")
writeLines(c(
  "options(warn = 2)", "library(provie)", "o <- asNamespace('provie')",
  "motif <- function(expr) tryCatch({ expr; 'aucun' }, refus_provie = function(e) e$motif, error = function(e) 'autre')",
  "z <- rawToChar(as.raw(c(0x63, 0xc3, 0xa9)))",
  "cat('natif_utf8=', l10n_info()[['UTF-8']], '\n', sep = '')",
  "cat('encodage=', Encoding(z), '\n', sep = '')",
  "cat('liste=', motif(o$ecrire_liste(list(a = z))), '\n', sep = '')",
  "cat('nom=', motif(o$ecrire_liste(setNames(list(1L), z))), '\n', sep = '')",
  "cat('texte=', motif(o$ecrire_valeurs(z)), '\n', sep = '')",
  "cat('octets=', motif(o$ecrire_valeurs(z, 'octets')), '\n', sep = '')",
  "Encoding(z) <- 'UTF-8'",
  "cat('marquee=', motif(o$ecrire_liste(list(a = z))), '\n', sep = '')",
  "x <- list(a = z, b = 1.5)",
  "cat('aller_retour=', identical(o$lire_liste(o$ecrire_liste(x)), x), '\n', sep = '')",
  "cat('empreinte=', o$empreinte(o$ecrire_liste(x)), '\n', sep = '')",
  "cat('empreinte_octets=', o$empreinte(o$ecrire_valeurs(z, 'octets')), '\n', sep = '')"
), script_c)
sortie_c <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"), shQuote(script_c),
                                     stdout = TRUE, stderr = TRUE,
                                     env = c("LC_ALL=C", paste0("R_LIBS=", .libPaths()[1L]))))
unlink(script_c)
lire_sortie <- function(cle) sub(paste0("^", cle, "="), "", grep(paste0("^", cle, "="), sortie_c, value = TRUE))
verifier_egal("le sous-processus tourne bien sous une locale non UTF-8", lire_sortie("natif_utf8"), "FALSE")
verifier_egal("chaîne non marquée non ASCII : encodage unknown", lire_sortie("encodage"), "unknown")
verifier_egal("ecrire_liste (valeur) refuse sous LC_ALL=C", lire_sortie("liste"), "liste_invalide")
verifier_egal("ecrire_liste (nom) refuse sous LC_ALL=C", lire_sortie("nom"), "liste_invalide")
verifier_egal("ecrire_valeurs texte refuse sous LC_ALL=C", lire_sortie("texte"), "liste_invalide")
verifier_egal("ecrire_valeurs octets refuse sous LC_ALL=C", lire_sortie("octets"), "liste_invalide")
verifier_egal("la même chaîne marquée UTF-8 passe sous LC_ALL=C", lire_sortie("marquee"), "aucun")
verifier_egal("aller-retour identical sous LC_ALL=C", lire_sortie("aller_retour"), "TRUE")
z_ici <- intToUtf8(c(99L, 233L))
verifier_egal("empreinte de la liste identique sous LC_ALL=C et sous la locale courante",
              lire_sortie("empreinte"), empreinte(ecrire_liste(list(a = z_ici, b = 1.5))))
verifier_egal("empreinte des octets de la chaîne identique sous LC_ALL=C et sous la locale courante",
              lire_sortie("empreinte_octets"), empreinte(ecrire_valeurs(z_ici, "octets")))
z_l1 <- rawToChar(as.raw(c(0x63, 0xe9))); Encoding(z_l1) <- "latin1"
verifier_egal("chaîne marquée latin1 : traduite, même écriture que l'UTF-8",
              ecrire_valeurs(z_l1, "octets"), ecrire_valeurs(z_ici, "octets"))
z_bytes <- rawToChar(as.raw(c(0x63, 0xe9))); Encoding(z_bytes) <- "bytes"
verifier_egal("chaîne marquée bytes refusée", motif_de(ecrire_valeurs(z_bytes)), "liste_invalide")
z_invalide <- rawToChar(as.raw(c(0x63, 0xff))); Encoding(z_invalide) <- "UTF-8"
verifier_egal("UTF-8 invalide refusé", motif_de(ecrire_valeurs(z_invalide)), "liste_invalide")

section("outils : decrire_plateforme")
plateforme <- decrire_plateforme()
verifier("liste nommée de chaînes uniques",
         is.list(plateforme) && !is.null(names(plateforme)) &&
           all(vapply(plateforme, function(v) is.character(v) && length(v) == 1L, NA)))
verifier("champs attendus", all(c("r", "plateforme", "systeme", "version_systeme", "machine",
                                  "boutisme", "blas", "lapack", "lapack_version", "pcre",
                                  "icu") %in% names(plateforme)))
verifier_egal("version de R", plateforme$r, R.version.string)
verifier("aucun champ de date ni d'horodatage",
         !any(grepl("date|heure|temps|time", names(plateforme), ignore.case = TRUE)))
verifier_egal("deux appels identiques", decrire_plateforme(), plateforme)
