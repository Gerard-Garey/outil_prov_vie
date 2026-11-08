# Controle : concordance de la forme lisible par machine du dictionnaire
# (inst/extdata/dictionnaire/) avec le texte vise docs/specifications/dictionnaire-base-v1.md
# (ADR 0010, points 23 et 26 ; M100, M117 ; issue #18). Le texte fait foi : une divergence
# est une erreur du CSV, sauf nouvelle version visee du texte.
#   1. le dossier contient exactement les six CSV et dictionnaire.txt ;
#   2. dictionnaire.txt : version egale a celle de l'en-tete du texte et a
#      VERSION_DICTIONNAIRE_ATTENDUE (R/outils.R), date de visa egale a celle de la ligne de
#      la version dans l'historique du texte, empreinte MD5 de chaque CSV ;
#   3. chaque CSV est compare au tableau correspondant du texte, ligne a ligne, champ a
#      champ et dans le meme ordre : tables.csv (section 2.1), colonnes.csv (section 3,
#      tableaux T1 a T20), types_evenements.csv (section 4 et automate), parametres.csv
#      (section 5), defauts.csv (section 9), filiation.csv (annexe A.1).
# Deux sortes de champs :
#   - transcrits ou derives par une regle fixe, ecrite ci-dessous, et recalcules ici :
#     compares a l'identique, ordre des valeurs compris. C'est le cas de tous les champs,
#     dont les modalites (codes de la liste en tete du domaine ; listes des sections 4 et 5),
#     l'unite (en tete du domaine ou \u00ab , en <unite> \u00bb), les motifs d'un type d'evenement
#     (\u00ab motifs : \u00bb, \u00ab `motif` facultatif : \u00bb, ou codes entre parentheses apres un etat),
#     l'automate (etat_depuis : puces de la section 4, dans leur ordre ; etat_vers : effet)
#     et la table v1 d'une colonne renommee (designee par la cible), sauf :
#   - les sous-parametres des defauts, transcrits a la main : chacun doit etre cite entre
#     accents graves dans la cellule d'intensite, dans l'ordre de la cellule, sans porter le
#     nom d'une table ni d'une modalite, et tout autre jeton de la cellule (hors le
#     parametre d'intensite) doit etre une table ou une modalite.
# Garde-fou des regles : dans le domaine d'une colonne character, tout jeton qui n'est pas
# une modalite de la colonne doit avoir un autre sens connu (table, colonne, reference,
# code de garantie, nature de sinistre, type d'evenement, modalite d'une autre colonne) ou
# figurer dans JETONS_ADMIS, chacun motive.
# Limites (mutations que le script ne peut pas detecter) :
#   - un sous-parametre oublie dont le nom est aussi une table ou une modalite ;
#   - les regles de derivation decrivent le texte de la version 1.4 : une version nouvelle
#     peut demander de les etendre (le script echoue alors sur la forme non reconnue ou sur
#     l'ecart, il ne valide pas en silence ce qu'il ne lit pas) ;
#   - le sens des cellules transcrites mot pour mot (domaine, effet, objet...) n'est pas
#     interprete : le moteur les lit comme texte.
# Usage, depuis la racine du depot : Rscript tests/controles/concordance_dictionnaire.R
# Un argument facultatif designe une autre racine (copie du depot, pour les temoins).
# Sortie : lignes [OK] / [ECHEC] fichier:ligne ; statut 1 au moindre [ECHEC].
# Code ASCII (caracteres non ASCII en \uXXXX), R de base seulement.

options(warn = 2)
.fichier_script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
.arguments <- commandArgs(trailingOnly = TRUE)
racine <- normalizePath(if (length(.arguments) >= 1L) .arguments[1L]
                        else file.path(dirname(.fichier_script), "..", ".."), mustWork = TRUE)
.n_echec <- 0L
rel <- function(chemin) if (startsWith(chemin, paste0(racine, "/"))) substring(chemin, nchar(racine) + 2L) else chemin
# Sortie en octets UTF-8, quelle que soit la locale (cat() ecrirait <U+00E9> sous une
# locale C).
ecrire <- function(texte) writeLines(enc2utf8(texte), useBytes = TRUE)
ok <- function(message) ecrire(paste0("[OK] ", message))
echec <- function(message, chemin = NA_character_, ligne = NA_integer_) {
  .n_echec <<- .n_echec + 1L
  position <- if (is.na(chemin)) "" else paste0(rel(chemin), if (is.na(ligne)) "" else paste0(":", ligne), " ")
  ecrire(paste0("[ECHEC] ", position, message))
}
fin <- function() quit(save = "no", status = if (.n_echec > 0L) 1L else 0L)

FLECHE <- "\u2192"
TIRET <- "\u2014"
FICHIERS_CSV <- c("tables.csv", "colonnes.csv", "types_evenements.csv", "parametres.csv",
                  "defauts.csv", "filiation.csv")
COLONNES_CSV <- list(
  tables.csv = c("numero", "table", "objet", "cle_primaire", "obligatoire", "visibilite"),
  colonnes.csv = c("table", "colonne", "type", "modalites", "domaine", "unite", "obligatoire",
                   "condition", "saisie", "colonne_saisie", "futur_admis", "reference",
                   "defauts"),
  types_evenements.csv = c("ordre", "type_evenement", "niveau", "garanties", "effet",
                           "colonnes_requises", "programmable", "etat_depuis", "etat_vers",
                           "motifs"),
  parametres.csv = c("code_garantie", "parametre", "unite", "dimension", "obligatoire",
                     "condition"),
  defauts.csv = c("code", "defaut", "tables", "colonnes", "detection", "traitements",
                  "parametre_intensite", "sous_parametres"),
  filiation.csv = c("table_de", "colonne_de", "table_v1", "colonne_v1", "statut", "motif")
)
# Jetons de domaine admis sans etre une modalite de leur colonne ni avoir un autre sens
# connu (liste fermee, chacun motive) :
#   - TRUE : valeur logique citee dans une condition (structure_cotisation_sante) ;
#   - ensemble : valeur ouverte particuliere du code opaque `college` (\u00ab ensemble s'il n'y a
#     pas de college \u00bb) ;
#   - interne : valeur ouverte particuliere du code opaque `gestionnaire`.
JETONS_ADMIS <- c("TRUE", "ensemble", "interne")
# Etiquettes des puces de l'automate (sans accents) et etat de depart correspondant ; deux
# vecteurs, une liste nommee non ASCII ne se traduisant pas sous une locale C.
PUCES_AUTOMATE <- c("Depart", "Depuis l'incapacite", "Depuis l'invalidite",
                    "Depuis \u00ab clos \u00bb par `reprise_travail`")
ETATS_AUTOMATE <- c("depart", "incapacite", "invalidite", "clos:reprise_travail")

# --- Lecture du texte vise --------------------------------------------------------------

lire_texte <- function(chemin) {
  lignes <- readLines(chemin, encoding = "UTF-8", warn = FALSE)
  Encoding(lignes) <- "UTF-8"
  lignes
}

cellules <- function(ligne) {
  x <- sub("^\\|[ ]?", "", ligne)
  x <- sub("[ ]?\\|$", "", x)
  strsplit(x, " | ", fixed = TRUE)[[1L]]
}

# Premier tableau qui suit l'unique ligne de titre conforme a `motif` ; rend un data.frame
# de cellules (texte), avec l'attribut "lignes" : numero de ligne du texte de chaque rangee.
tableau_apres <- function(lignes, motif) {
  i <- grep(motif, lignes)
  if (length(i) != 1L) stop("titre introuvable ou ambigu : ", motif, call. = FALSE)
  j <- i + 1L
  while (j <= length(lignes) && !startsWith(lignes[j], "|")) {
    if (grepl("^#", lignes[j])) stop("aucun tableau sous le titre ", motif, call. = FALSE)
    j <- j + 1L
  }
  k <- j
  while (k <= length(lignes) && startsWith(lignes[k], "|")) k <- k + 1L
  bloc <- lignes[j:(k - 1L)]
  entete <- cellules(bloc[1L])
  if (length(bloc) < 3L || !grepl("^\\|(-+\\|)+$", bloc[2L])) {
    stop("tableau mal forme sous le titre ", motif, call. = FALSE)
  }
  rangees <- lapply(bloc[-(1:2)], cellules)
  if (any(lengths(rangees) != length(entete))) {
    stop("nombre de cellules irregulier sous le titre ", motif, call. = FALSE)
  }
  m <- matrix(unlist(rangees), ncol = length(entete), byrow = TRUE)
  df <- as.data.frame(m, stringsAsFactors = FALSE)
  names(df) <- paste0("c", seq_along(entete))
  attr(df, "lignes") <- (j + 2L):(k - 1L)
  df
}

# Jetons entre accents graves, dans l'ordre.
jetons <- function(x) {
  r <- regmatches(x, gregexpr("`[^`]+`", x))[[1L]]
  gsub("`", "", r, fixed = TRUE)
}
hors_parentheses <- function(x) {
  repeat {
    y <- gsub("\\([^()]*\\)", "", x)
    if (identical(y, x)) return(y)
    x <- y
  }
}
clauses <- function(x) strsplit(x, " ; ", fixed = TRUE)[[1L]]
joindre <- function(v) paste(v, collapse = ";")
eclater <- function(x) if (identical(x, "")) character(0) else strsplit(x, ";", fixed = TRUE)[[1L]]
vide_si_tiret <- function(x) ifelse(x == TIRET, "", x)
sans_accents <- function(x) chartr("\u00e9\u00e8\u00ea\u00e0\u00c9", "eeeaE", x)

# --- Derivations : ce que chaque CSV doit contenir, recalcule du texte ------------------

derive_tables <- function(lignes) {
  t <- tableau_apres(lignes, "^### 2\\.1 Tables")
  noms <- gsub("`", "", t$c2, fixed = TRUE)
  obligatoire <- t$c6
  si <- regmatches(obligatoire, regexec("^F \\(O si T([0-9]+)\\)$", obligatoire))
  for (i in seq_along(si)) {
    if (length(si[[i]]) == 2L) obligatoire[i] <- paste0("F_si:", noms[as.integer(si[[i]][2L])])
  }
  data.frame(
    numero = t$c1, table = noms, objet = t$c3,
    cle_primaire = vapply(vide_si_tiret(t$c4), function(x) joindre(jetons(x)), ""),
    obligatoire = obligatoire, visibilite = vide_si_tiret(t$c7),
    cles_etrangeres = vapply(vide_si_tiret(t$c5), function(x) joindre(unique(jetons(x))), ""),
    ligne_texte = attr(t, "lignes"), stringsAsFactors = FALSE, row.names = NULL)
}

# Automate du sinistre d'arret de travail (section 4) : liste de puces apres le titre.
derive_automate <- function(lignes) {
  i <- grep("^\\*\\*Automate du sinistre", lignes)
  if (length(i) != 1L) stop("automate introuvable", call. = FALSE)
  j <- i + 1L
  while (j <= length(lignes) && !startsWith(lignes[j], "- ")) j <- j + 1L
  k <- j
  while (k <= length(lignes) && startsWith(lignes[k], "- ")) k <- k + 1L
  puces <- lignes[j:(k - 1L)]
  etiquette <- sans_accents(ifelse(grepl("^- \\*\\*", puces),
                                   sub("^- \\*\\*(.*?)\\*\\* :.*$", "\\1", puces, perl = TRUE),
                                   sub("^- ", "", puces)))
  suite <- sub("^- \\*\\*.*?\\*\\* :", "", puces, perl = TRUE)
  list(etiquette = etiquette, suite = suite, lignes = j:(k - 1L))
}

# Motifs d'un type d'evenement, lus dans l'effet : codes entre parentheses apres un etat
# (\u00ab etat \u00bb (`motif`, ...)) ; sinon clause \u00ab motifs : \u00bb ou \u00ab `motif` facultatif : \u00bb.
motifs_de_effet <- function(effet) {
  g <- regmatches(effet, gregexpr("\u00ab [^\u00bb]+ \u00bb \\([^)]*\\)", effet))[[1L]]
  if (length(g)) return(joindre(unique(unlist(lapply(g, jetons)))))
  for (cl in clauses(hors_parentheses(effet))) {
    if (grepl("^(motifs|`motif` facultatif) : ", cl)) return(joindre(unique(jetons(sub("^.*? : ", "", cl, perl = TRUE)))))
  }
  ""
}

# Etat d'arrivee d'un type de l'automate, lu dans l'effet : \u00ab etat \u00bb ; X -> Y ; sortie :
# \u00ab etat \u00bb (`motif`, ...) ; rechute : -> etat anterieur a la sortie.
etat_vers_de_effet <- function(type, effet_brut) {
  effet <- sans_accents(effet_brut)
  if (type == "sortie") {
    g <- regmatches(effet, gregexpr("\u00ab ([a-z]+) \u00bb \\(([^)]*)\\)", effet))[[1L]]
    return(joindre(vapply(g, function(x) {
      paste0(sub("^\u00ab ([a-z]+) \u00bb.*$", "\\1", x), ":", paste(jetons(x), collapse = ","))
    }, "", USE.NAMES = FALSE)))
  }
  if (type == "rechute") {
    return(if (grepl(paste0(FLECHE, " etat anterieur a la sortie"), effet, fixed = TRUE)) "anterieur" else "<non reconnu>")
  }
  if (grepl(FLECHE, effet, fixed = TRUE)) return(tolower(sub(paste0("^.*", FLECHE, " ([A-Za-z]+).*$"), "\\1", effet)))
  if (grepl("\u00ab ([a-z]+) \u00bb", effet)) return(sub("^.*\u00ab ([a-z]+) \u00bb.*$", "\\1", effet))
  "<non reconnu>"
}

derive_types_evenements <- function(lignes) {
  t <- tableau_apres(lignes, "^## 4\\. Types")
  types <- gsub("`", "", t$c1, fixed = TRUE)
  garanties <- character(nrow(t))
  for (i in seq_len(nrow(t))) {
    g <- t$c3[i]
    garanties[i] <- if (g == "m\u00eames garanties") garanties[i - 1L] else
      if (g == "toutes") "toutes" else joindre(jetons(g))
  }
  programmable <- vapply(t$c6, function(p) {
    if (p %in% c("oui", "non")) return(p)
    if (startsWith(p, "oui pour ")) return(paste0("oui:", joindre(jetons(p))))
    paste0("<non reconnu : ", p, ">")
  }, "")
  automate <- derive_automate(lignes)
  connues <- automate$etiquette %in% PUCES_AUTOMATE
  etat_depuis <- vapply(types, function(ty) {
    dans <- vapply(automate$suite[connues], function(s) ty %in% jetons(s), NA)
    joindre(ETATS_AUTOMATE[match(automate$etiquette[connues][dans], PUCES_AUTOMATE)])
  }, "")
  etat_vers <- vapply(seq_along(types), function(i) {
    if (etat_depuis[i] == "") "" else etat_vers_de_effet(types[i], t$c4[i])
  }, "")
  data.frame(
    ordre = as.character(seq_len(nrow(t))), type_evenement = types,
    niveau = vapply(t$c2, function(n) {
      joindre(regmatches(n, gregexpr("\\b(sinistre|dossier|rente)\\b", n))[[1L]])
    }, ""),
    garanties = garanties, effet = t$c4,
    colonnes_requises = vapply(vide_si_tiret(t$c5), function(x) joindre(jetons(x)), ""),
    programmable = programmable, etat_depuis = unname(etat_depuis), etat_vers = etat_vers,
    motifs = vapply(t$c4, motifs_de_effet, ""), ligne_texte = attr(t, "lignes"),
    stringsAsFactors = FALSE, row.names = NULL)
}

derive_parametres <- function(lignes) {
  t <- tableau_apres(lignes, "^## 5\\. Param")
  forme <- regmatches(t$c5, regexec("^(O|C|F)(?:( : |, )(.*))?$", t$c5, perl = TRUE))
  data.frame(
    code_garantie = gsub("`", "", t$c1, fixed = TRUE), parametre = gsub("`", "", t$c2, fixed = TRUE),
    unite = t$c3,
    dimension = vapply(vide_si_tiret(t$c4), function(x) joindre(jetons(x)), ""),
    obligatoire = vapply(forme, function(f) if (length(f) == 4L) f[2L] else "<non reconnu>", ""),
    condition = vapply(forme, function(f) if (length(f) == 4L) f[4L] else "", ""),
    separateur_conforme = vapply(forme, function(f) {
      length(f) == 4L && (f[3L] == "" || (f[2L] == "C") == (f[3L] == " : "))
    }, NA),
    ligne_texte = attr(t, "lignes"), stringsAsFactors = FALSE, row.names = NULL)
}

# Clauses du domaine qui disent la condition d'une colonne conditionnelle (C).
condition_du_domaine <- function(domaine) {
  cl <- clauses(domaine)
  paste(cl[grepl("^(requis|requise|manquant|manquante|m\u00eames) ", cl)], collapse = " ; ")
}

# Modalites d'une colonne character : listes des sections 4 et 5 quand le domaine y renvoie ;
# sinon, hors parentheses, les codes de la premiere clause et des clauses suivantes faites
# seulement d'une liste de codes ; aucune pour une colonne a reference (cle etrangere).
modalites_du_domaine <- function(domaine, type, reference, types, parametres) {
  if (type != "character" || reference != "") return("")
  if (startsWith(domaine, "Liste ferm\u00e9e du \u00a7 4")) return(joindre(types$type_evenement))
  if (startsWith(domaine, "Liste ferm\u00e9e du \u00a7 5")) return(joindre(unique(parametres$parametre)))
  if (startsWith(domaine, "Liste ferm\u00e9e par type (\u00a7 4)")) return(joindre(unique(unlist(lapply(types$motifs, eclater)))))
  cl <- trimws(clauses(hors_parentheses(domaine)))
  codes <- jetons(cl[1L])
  for (k in seq_along(cl)[-1L]) {
    if (!grepl("^`[^`]+`(\\s*, `[^`]+`)*$", cl[k])) break
    codes <- c(codes, jetons(cl[k]))
  }
  joindre(unique(codes))
}

# Unite d'une colonne numerique : en tete du domaine (\u00ab \u20ac \u00bb, \u00ab \u20ac par an \u00bb), ou
# \u00ab , en <unite> \u00bb.
unite_du_domaine <- function(domaine, type) {
  if (!(type %in% c("numeric", "integer"))) return("")
  m <- regmatches(domaine, regexec("^(\u20ac( par [a-z]+)?)( |,|$)", domaine))[[1L]]
  if (length(m)) return(m[2L])
  m <- regmatches(domaine, regexec(", en ([a-z]+)( |;|$)", domaine))[[1L]]
  if (length(m)) return(m[2L])
  ""
}

# futur_admis : TRUE si le domaine dit \u00ab futur admis \u00bb ; programmable si la borne
# \u00ab <= extraction \u00bb ne vaut pas pour un type programmable (renvoi a
# types_evenements.programmable) ; FALSE sinon.
futur_admis_du_domaine <- function(domaine) {
  if (grepl("futur admis", domaine, fixed = TRUE)) return("TRUE")
  if (grepl("\u2264 extraction sauf pour un type programmable", domaine, fixed = TRUE)) return("programmable")
  "FALSE"
}

derive_colonnes <- function(lignes, tables, types, parametres) {
  morceaux <- list()
  pk1 <- vapply(tables$cle_primaire, function(x) if (identical(x, "")) "" else eclater(x)[1L], "")
  names(pk1) <- tables$table
  for (k in seq_len(nrow(tables))) {
    titre <- sprintf("^### T%d\\. `%s`", k, tables$table[k])
    t <- tableau_apres(lignes, titre)
    saisie <- colonne_saisie <- rep("", nrow(t))
    for (i in seq_len(nrow(t))) {
      s <- t$c5[i]
      if (s == TIRET) next
      if (grepl("^[SLVE]( \\(.*\\))?$", s)) {
        saisie[i] <- substr(s, 1L, 1L)
      } else if (grepl("^P\\(`[a-z_]+`\\)$", s)) {
        saisie[i] <- "P"
        colonne_saisie[i] <- gsub("^P\\(`|`\\)$", "", s)
      } else {
        saisie[i] <- paste0("<non reconnu : ", s, ">")
      }
    }
    domaine <- t$c3
    reference <- vapply(seq_along(domaine), function(i) {
      d <- domaine[i]
      # Cle etrangere composite (version 1.4) : \u00ab -> (`t.c1`, `t.c2`) \u00bb donne t.c1;t.c2.
      composite <- regmatches(d, regexec(paste0(FLECHE, " \\((`[a-z_]+\\.[a-z_]+`(, `[a-z_]+\\.[a-z_]+`)+)\\)"), d))[[1L]]
      if (length(composite)) return(joindre(jetons(composite[2L])))
      vers <- regmatches(d, regexec(paste0(FLECHE, " `([a-z_]+)`"), d))[[1L]]
      if (length(vers) == 2L) return(paste0(vers[2L], ".", pk1[[vers[2L]]]))
      dans <- regmatches(d, regexec("existe dans `([a-z_]+)`", d))[[1L]]
      if (length(dans) == 2L) return(paste0(dans[2L], ".", gsub("`", "", t$c1[i], fixed = TRUE)))
      ""
    }, "")
    morceaux[[k]] <- data.frame(
      table = tables$table[k], colonne = gsub("`", "", t$c1, fixed = TRUE), type = t$c2,
      modalites = vapply(seq_along(domaine), function(i) {
        modalites_du_domaine(domaine[i], t$c2[i], reference[i], types, parametres)
      }, ""),
      domaine = domaine,
      unite = vapply(seq_along(domaine), function(i) unite_du_domaine(domaine[i], t$c2[i]), ""),
      obligatoire = t$c4,
      condition = ifelse(t$c4 == "C", vapply(domaine, condition_du_domaine, ""), ""),
      saisie = saisie, colonne_saisie = colonne_saisie,
      futur_admis = vapply(domaine, futur_admis_du_domaine, ""),
      reference = reference,
      defauts = vapply(vide_si_tiret(t$c6), function(x) gsub(", ", ";", x, fixed = TRUE), ""),
      ligne_texte = attr(t, "lignes"), stringsAsFactors = FALSE, row.names = NULL)
  }
  do.call(rbind, morceaux)
}

# Un code de defaut d'une colonne (section 3) designe-t-il le defaut `code` (section 9) ?
code_designe <- function(code_colonne, code) {
  code_colonne == code | (!grepl("[a-z]$", code) & sub("[a-z]$", "", code_colonne) == code)
}

# Tables d'un defaut, reunion de : tables citees dans la cellule \u00ab Tables et colonnes \u00bb
# (entre accents graves, seules ou en prefixe `table.colonne`, ou nommees sans accents
# graves, hors `extraction`, dont le mot nu designe la date d'extraction : \u00ab <= extraction \u00bb) ;
# `evenements` si la cellule cite un type d'evenement ; toutes les tables a cle primaire si
# la cellule dit \u00ab toute table \u00bb ; tables dont une colonne porte le code (section 3).
# Traitements : codes en gras des cellules \u00ab Tables et colonnes \u00bb, \u00ab Detection \u00bb et
# \u00ab Traitement \u00bb (D04b les ecrit dans la premiere, D09 le R dans la deuxieme).
derive_defauts <- function(lignes, tables, colonnes, types) {
  t <- tableau_apres(lignes, "^## 9\\. D")
  code <- sub(" .*$", "", gsub("*", "", t$c1, fixed = TRUE))
  codes_colonnes <- strsplit(colonnes$defauts, ";", fixed = TRUE)
  tables_de <- vapply(seq_len(nrow(t)), function(i) {
    cellule <- t$c3[i]
    citees <- sub("\\..*$", "", jetons(cellule))
    nues <- tables$table[vapply(tables$table, function(n) {
      n != "extraction" && grepl(paste0("(^|[^a-z_])", n, "([^a-z_]|$)"), cellule)
    }, NA)]
    evenements <- if (any(jetons(cellule) %in% types$type_evenement)) "evenements" else character(0)
    toutes <- if (grepl("toute table", cellule, fixed = TRUE)) tables$table[tables$cle_primaire != ""] else character(0)
    par_colonnes <- colonnes$table[vapply(codes_colonnes, function(cc) any(code_designe(cc, code[i])), NA)]
    retenues <- unique(c(citees, nues, evenements, toutes, par_colonnes))
    joindre(tables$table[tables$table %in% retenues])
  }, "")
  traitements <- vapply(seq_len(nrow(t)), function(i) {
    texte <- paste(t$c3[i], t$c4[i], t$c5[i])
    gras <- gsub("*", "", regmatches(texte, gregexpr("\\*\\*[RXHS]\\*\\*", texte))[[1L]], fixed = TRUE)
    joindre(c("R", "X", "H", "S")[c("R", "X", "H", "S") %in% gras])
  }, "")
  detection <- vapply(t$c4, function(d) {
    joindre(c(if (grepl("exacte", d, fixed = TRUE)) "exacte",
              if (grepl("pr\u00e9somptive", d, fixed = TRUE)) "presomptive"))
  }, "")
  data.frame(
    code = code, defaut = t$c2, tables = tables_de, colonnes = t$c3, detection = detection,
    traitements = traitements,
    parametre_intensite = vapply(t$c6, function(x) { j <- jetons(x); if (length(j)) j[1L] else "" }, ""),
    cellule_intensite = t$c6, ligne_texte = attr(t, "lignes"),
    stringsAsFactors = FALSE, row.names = NULL)
}

# Colonnes renommees d'une cellule de l'annexe A.1 : liste de (sources, cible), la cible
# etant le texte qui suit la fleche jusqu'a la clause suivante (clause de renommage, ou
# remarque "; cle (...)" sur la cle, qui ne cree pas de ligne : les colonnes de la cle
# ont chacune la leur).
renommees <- function(cellule) {
  motif <- paste0("(?:^|; )((?:`[a-z_]+`(?: \\([^()]*\\))?(?:, | \\+ )?)+) ", FLECHE, " ")
  m <- gregexpr(motif, cellule, perl = TRUE)[[1L]]
  if (m[1L] == -1L) return(list())
  debut_lhs <- attr(m, "capture.start")[, 1L]
  long_lhs <- attr(m, "capture.length")[, 1L]
  fin_match <- as.integer(m) + attr(m, "match.length")
  cles <- as.integer(gregexpr("; cl\u00e9 \\(", cellule, perl = TRUE)[[1L]])
  bornes <- sort(c(as.integer(m), cles[cles > 0L]))
  lapply(seq_along(m), function(i) {
    lhs <- substr(cellule, debut_lhs[i], debut_lhs[i] + long_lhs[i] - 1L)
    suivantes <- bornes[bornes > as.integer(m)[i]]
    fin_cible <- if (length(suivantes)) suivantes[1L] - 1L else nchar(cellule)
    cible <- sub(" +$", "", substr(cellule, fin_match[i], fin_cible))
    list(sources = jetons(hors_parentheses(lhs)), cible = cible)
  })
}

# Table(s) v1 designee(s) par la cible d'une colonne renommee, parmi les tables admises de
# la rangee, dans l'ordre de la cible : cible reconstituee (\u00ab reconstitue \u00bb, \u00ab etat
# reconstitue \u00bb) -> aucune ; paire (`garantie`, `parametre`) -> parametres ; sinon, hors
# parentheses, chaque jeton `table.colonne` ou `table`, `type_evenement` ou
# `type_evenement.colonne` (-> evenements), `colonne` d'une table admise (la premiere qui la
# porte), et les mots \u00ab prestation \u00bb (-> prestations), \u00ab evenement \u00bb (-> evenements),
# \u00ab garantie souscrite \u00bb (-> garanties_souscrites), \u00ab affiliation \u00bb (-> affiliations). Une
# table designee hors des tables admises n'est pas retenue.
table_designee <- function(cible, admises, colonnes, noms_tables, types_evenement, codes_garantie, noms_parametres) {
  if (grepl("^(\u00e9tat )?reconstitu\u00e9", cible)) return("")
  paire <- regmatches(cible, regexec("^\\(`([a-z_]+)`, `([a-z_]+)`\\)$", cible))[[1L]]
  if (length(paire) == 3L && paire[2L] %in% codes_garantie && paire[3L] %in% noms_parametres) {
    designees <- "parametres"
  } else {
    texte <- hors_parentheses(cible)
    m <- regmatches(texte, gregexpr("`[^`]+`|prestation|\u00e9v\u00e9nement|garantie souscrite|affiliation", texte))[[1L]]
    designees <- vapply(m, function(x) {
      if (x == "prestation") return("prestations")
      if (x == "\u00e9v\u00e9nement") return("evenements")
      if (x == "garantie souscrite") return("garanties_souscrites")
      if (x == "affiliation") return("affiliations")
      j <- gsub("`", "", x, fixed = TRUE)
      prefixe <- sub("\\..*$", "", j)
      if (grepl(".", j, fixed = TRUE)) {
        if (prefixe %in% noms_tables) return(prefixe)
        if (prefixe %in% types_evenement) return("evenements")
        return("")
      }
      if (j %in% noms_tables) return(j)
      if (j %in% types_evenement) return("evenements")
      dans <- admises[vapply(admises, function(a) any(colonnes$table == a & colonnes$colonne == j), NA)]
      if (length(dans)) dans[1L] else ""
    }, "", USE.NAMES = FALSE)
  }
  joindre(unique(designees[designees %in% admises]))
}

derive_filiation <- function(lignes, tables, colonnes, types, parametres) {
  t <- tableau_apres(lignes, "^### A\\.1 ")
  garder <- grepl("^T[0-9]+ `", t$c1)
  codes_garantie <- eclater(colonnes$modalites[colonnes$table == "garanties_souscrites" & colonnes$colonne == "code_garantie"])
  rangees <- list()
  for (i in which(garder)) {
    table_de <- sub("\\.csv$", "", jetons(t$c1[i])[1L])
    admises <- jetons(hors_parentheses(t$c2[i]))
    admises <- admises[admises %in% tables$table]
    reprises <- jetons(hors_parentheses(clauses(t$c3[i])[1L]))
    for (col in reprises) {
      dans <- admises[vapply(admises, function(a) any(colonnes$table == a & colonnes$colonne == col), NA)]
      rangees[[length(rangees) + 1L]] <- c(table_de, col, if (length(dans)) dans[1L] else "<aucune>",
                                           col, "reprise", "", attr(t, "lignes")[i])
    }
    for (r in renommees(t$c4[i])) {
      cible_table <- table_designee(r$cible, admises, colonnes, tables$table, types$type_evenement,
                                    codes_garantie, unique(parametres$parametre))
      for (col in r$sources) {
        rangees[[length(rangees) + 1L]] <- c(table_de, col, cible_table, r$cible, "renommee", "",
                                             attr(t, "lignes")[i])
      }
    }
    if (!startsWith(t$c5[i], "aucune")) {
      for (cl in clauses(t$c5[i])) {
        lhs <- sub(" : .*$", "", cl)
        motif <- sub("^.*? : ", "", cl, perl = TRUE)
        for (col in jetons(hors_parentheses(lhs))) {
          rangees[[length(rangees) + 1L]] <- c(table_de, col, "", "", "non_reprise", motif, attr(t, "lignes")[i])
        }
      }
    }
  }
  m <- matrix(unlist(rangees), ncol = 7L, byrow = TRUE)
  df <- as.data.frame(m, stringsAsFactors = FALSE)
  names(df) <- c("table_de", "colonne_de", "table_v1", "colonne_v1", "statut", "motif", "ligne_texte")
  df$ligne_texte <- as.integer(df$ligne_texte)
  attr(df, "ignorees") <- t$c1[!garder]
  attr(df, "ignorees_lignes") <- attr(t, "lignes")[!garder]
  df
}

# --- Fin des fonctions de derivation ----------------------------------------------------

lire_csv <- function(chemin) {
  utils::read.csv(chemin, colClasses = "character", na.strings = character(0),
                  encoding = "UTF-8", check.names = FALSE, stringsAsFactors = FALSE)
}

# Compare le CSV et la derivation sur les champs donnes ; un [ECHEC] par cellule differente.
comparer <- function(nom, csv, attendu, champs, chemin_csv, chemin_texte) {
  avant <- .n_echec
  if (nrow(csv) != nrow(attendu)) {
    echec(sprintf("%s : %d lignes, %d dans le texte", nom, nrow(csv), nrow(attendu)), chemin_csv)
    return(invisible(FALSE))
  }
  for (champ in champs) {
    diff <- which(csv[[champ]] != attendu[[champ]])
    for (i in diff) {
      echec(sprintf("%s, champ `%s` : \u00ab %s \u00bb au lieu de \u00ab %s \u00bb (texte, ligne %d)",
                    nom, champ, csv[[champ]][i], attendu[[champ]][i], attendu$ligne_texte[i]),
            chemin_csv, i + 1L)
    }
  }
  if (.n_echec == avant) {
    ok(sprintf("%s : %d lignes concordantes avec %s (champs %s)", nom, nrow(csv), rel(chemin_texte),
               paste(champs, collapse = ", ")))
  }
  invisible(.n_echec == avant)
}

# --- Execution ---------------------------------------------------------------------------

chemin_texte <- file.path(racine, "docs", "specifications", "dictionnaire-base-v1.md")
dossier <- file.path(racine, "inst", "extdata", "dictionnaire")
chemin <- function(f) file.path(dossier, f)
if (!file.exists(chemin_texte)) {
  echec("texte vis\u00e9 absent", chemin_texte)
  fin()
}
if (!dir.exists(dossier)) {
  echec("dossier de la forme lisible par machine absent", dossier)
  fin()
}
lignes <- lire_texte(chemin_texte)

# 1. Fichiers presents
presents <- sort(list.files(dossier, all.files = TRUE, no.. = TRUE), method = "radix")
attendus <- sort(c(FICHIERS_CSV, "dictionnaire.txt"), method = "radix")
if (!identical(presents, attendus)) {
  echec(sprintf("fichiers : %s ; attendus : %s", paste(presents, collapse = ", "),
                paste(attendus, collapse = ", ")), dossier)
  fin()
}
ok("dossier inst/extdata/dictionnaire : six CSV et dictionnaire.txt, rien d'autre")

csv <- list()
for (f in FICHIERS_CSV) {
  csv[[f]] <- lire_csv(chemin(f))
  if (!identical(names(csv[[f]]), COLONNES_CSV[[f]])) {
    echec(sprintf("en-t\u00eate de %s : %s ; attendu : %s", f, paste(names(csv[[f]]), collapse = ","),
                  paste(COLONNES_CSV[[f]], collapse = ",")), chemin(f), 1L)
    fin()
  }
}
ok("en-t\u00eates des six CSV conformes \u00e0 l'ADR 0010, point 23")

# 2. dictionnaire.txt (texte de lire_liste(), lu ici sans le package : une ligne par
# feuille, champs separes par une tabulation)
ligne_version <- grep("^Version du dictionnaire : `", lignes)
version_texte <- if (length(ligne_version) == 1L) jetons(lignes[ligne_version])[1L] else NA_character_
texte_liste <- readLines(chemin("dictionnaire.txt"), encoding = "UTF-8", warn = FALSE)
champs_liste <- strsplit(texte_liste[-1L], "\t", fixed = TRUE)
chemins_liste <- vapply(champs_liste, `[`, "", 1L)
valeur_liste <- function(chemin_feuille, type) {
  i <- match(chemin_feuille, chemins_liste)
  if (is.na(i) || !identical(champs_liste[[i]][2L], type)) return(NA_character_)
  champs_liste[[i]][-(1:2)]
}
constante <- NA_character_
for (e in parse(file.path(racine, "R", "outils.R"), keep.source = FALSE)) {
  if (is.call(e) && identical(e[[1L]], as.name("<-")) &&
      identical(e[[2L]], as.name("VERSION_DICTIONNAIRE_ATTENDUE")) && is.character(e[[3L]])) {
    constante <- e[[3L]]
  }
}
version_liste <- valeur_liste("version", "character")
if (identical(texte_liste[1L], "provie-liste 1") && identical(version_liste, version_texte) &&
    identical(constante, version_texte)) {
  ok(sprintf("version %s : en-t\u00eate du texte, dictionnaire.txt et VERSION_DICTIONNAIRE_ATTENDUE", version_texte))
} else {
  echec(sprintf("version : texte %s, dictionnaire.txt %s, R/outils.R %s", version_texte,
                paste(version_liste, collapse = " "), constante), chemin("dictionnaire.txt"))
}
MOIS <- c("janvier", "f\u00e9vrier", "mars", "avril", "mai", "juin", "juillet", "ao\u00fbt",
          "septembre", "octobre", "novembre", "d\u00e9cembre")
ligne_histo <- grep(paste0("^> - \\*`", gsub(".", "\\.", version_texte, fixed = TRUE), "` : vis"), lignes)
date_visa <- NA_character_
if (length(ligne_histo) == 1L) {
  d <- regmatches(lignes[ligne_histo], regexec("le ([0-9]{1,2}) ([^ ]+) ([0-9]{4})", lignes[ligne_histo]))[[1L]]
  if (length(d) == 4L && d[3L] %in% MOIS) {
    date_visa <- sprintf("%s-%02d-%02d", d[4L], match(d[3L], MOIS), as.integer(d[2L]))
  }
}
if (!is.na(date_visa) && identical(valeur_liste("date_visa", "date"), date_visa)) {
  ok(sprintf("date de visa %s : historique du texte (ligne %d) et dictionnaire.txt", date_visa, ligne_histo))
} else {
  echec(sprintf("date de visa : texte %s, dictionnaire.txt %s", date_visa,
                paste(valeur_liste("date_visa", "date"), collapse = " ")), chemin("dictionnaire.txt"))
}
avant <- .n_echec
attendus_liste <- c("version", "date_visa", paste0("empreintes/", FICHIERS_CSV))
if (!identical(chemins_liste, attendus_liste)) {
  echec(sprintf("champs de dictionnaire.txt : %s ; attendus : %s", paste(chemins_liste, collapse = ", "),
                paste(attendus_liste, collapse = ", ")), chemin("dictionnaire.txt"))
}
for (f in FICHIERS_CSV) {
  md5 <- unname(as.character(tools::md5sum(chemin(f))))
  inscrite <- valeur_liste(paste0("empreintes/", f), "character")
  if (!identical(inscrite, md5)) {
    echec(sprintf("empreinte de %s : %s inscrite, %s mesur\u00e9e", f, paste(inscrite, collapse = " "), md5),
          chemin("dictionnaire.txt"))
  }
}
if (.n_echec == avant) ok("dictionnaire.txt : champs version, date_visa et empreintes MD5 des six CSV, dans l'ordre, empreintes concordantes")

# 3. Tableaux, tous les champs
tables_t <- derive_tables(lignes)
comparer("tables.csv", csv$tables.csv, tables_t, COLONNES_CSV$tables.csv, chemin("tables.csv"), chemin_texte)

types_t <- derive_types_evenements(lignes)
te <- csv$types_evenements.csv
comparer("types_evenements.csv", te, types_t, COLONNES_CSV$types_evenements.csv,
         chemin("types_evenements.csv"), chemin_texte)

parametres_t <- derive_parametres(lignes)
for (i in which(!parametres_t$separateur_conforme)) {
  echec("colonne Obl. du param\u00e8tre : forme non reconnue", chemin_texte, parametres_t$ligne_texte[i])
}
comparer("parametres.csv", csv$parametres.csv, parametres_t, COLONNES_CSV$parametres.csv,
         chemin("parametres.csv"), chemin_texte)

colonnes_t <- derive_colonnes(lignes, tables_t, types_t, parametres_t)
cc <- csv$colonnes.csv
comparer("colonnes.csv", cc, colonnes_t, COLONNES_CSV$colonnes.csv, chemin("colonnes.csv"), chemin_texte)

defauts_t <- derive_defauts(lignes, tables_t, colonnes_t, types_t)
de <- csv$defauts.csv
comparer("defauts.csv", de, defauts_t,
         c("code", "defaut", "tables", "colonnes", "detection", "traitements", "parametre_intensite"),
         chemin("defauts.csv"), chemin_texte)

filiation_t <- derive_filiation(lignes, tables_t, colonnes_t, types_t, parametres_t)
fi <- csv$filiation.csv
comparer("filiation.csv", fi, filiation_t, COLONNES_CSV$filiation.csv, chemin("filiation.csv"), chemin_texte)
ignorees <- attr(filiation_t, "ignorees")
if (identical(ignorees, "Fichiers `diagnostic-`")) {
  ok(sprintf("annexe A.1 : la rang\u00e9e \u00ab Fichiers `diagnostic-` \u00bb (ligne %d, fichiers de v\u00e9rit\u00e9 du simulateur, hors base) n'a pas de ligne dans filiation.csv",
             attr(filiation_t, "ignorees_lignes")))
} else {
  echec(sprintf("annexe A.1 : rang\u00e9es sans table du dictionnaire double effet : %s", paste(ignorees, collapse = " ; ")),
        chemin_texte)
}
if (anyDuplicated(paste(fi$table_de, fi$colonne_de))) {
  echec("filiation.csv : colonne du dictionnaire double effet en double", chemin("filiation.csv"))
}

# --- Coherence des regles avec le texte -------------------------------------------------

# Cles etrangeres du tableau 2.1 = colonnes porteuses d'une reference.
avant <- .n_echec
for (i in seq_len(nrow(tables_t))) {
  fk_texte <- sort(eclater(tables_t$cles_etrangeres[i]), method = "radix")
  fk_csv <- sort(cc$colonne[cc$table == tables_t$table[i] & cc$reference != ""], method = "radix")
  if (!identical(fk_texte, fk_csv)) {
    echec(sprintf("table %s : cl\u00e9s \u00e9trang\u00e8res du texte (%s) et colonnes \u00e0 r\u00e9f\u00e9rence de colonnes.csv (%s)",
                  tables_t$table[i], paste(fk_texte, collapse = ","), paste(fk_csv, collapse = ",")),
          chemin_texte, tables_t$ligne_texte[i])
  }
}
if (.n_echec == avant) ok("cl\u00e9s \u00e9trang\u00e8res de la section 2.1 = colonnes \u00e0 r\u00e9f\u00e9rence de colonnes.csv")

# Garde-fou des modalites : jetons du domaine d'une colonne character hors de ses modalites.
noms_tables <- tables_t$table
noms_colonnes <- unique(cc$colonne)
toutes_modalites <- unique(unlist(lapply(cc$modalites, eclater)))
autre_sens <- function(j) {
  j %in% c(noms_tables, noms_colonnes, toutes_modalites, te$type_evenement, JETONS_ADMIS) ||
    (grepl("^[a-z_]+\\.[a-z_]+$", j) && sub("\\..*$", "", j) %in% noms_tables)
}
avant <- .n_echec
for (i in which(cc$type == "character")) {
  autres <- setdiff(jetons(cc$domaine[i]), eclater(cc$modalites[i]))
  inconnus <- autres[!vapply(autres, autre_sens, NA)]
  if (length(inconnus)) {
    echec(sprintf("%s.%s : jetons du domaine hors des modalit\u00e9s et sans autre sens connu : %s",
                  cc$table[i], cc$colonne[i], paste(inconnus, collapse = ", ")), chemin("colonnes.csv"), i + 1L)
  }
}
if (.n_echec == avant) {
  ok(sprintf("modalit\u00e9s : %d colonnes \u00e0 liste ferm\u00e9e ; dans les %d colonnes character, chaque jeton du domaine hors modalit\u00e9s a un autre sens connu",
             sum(cc$modalites != ""), sum(cc$type == "character")))
}

# Motifs : la colonne motif est attendue pour un type si et seulement s'il a des motifs.
avant <- .n_echec
for (i in seq_len(nrow(te))) {
  attendu_motif <- "motif" %in% eclater(te$colonnes_requises[i]) || grepl("`motif` facultatif", te$effet[i], fixed = TRUE)
  if (attendu_motif != (te$motifs[i] != "")) {
    echec(sprintf("%s : motifs %s alors que la colonne motif %s", te$type_evenement[i],
                  if (te$motifs[i] != "") "renseign\u00e9s" else "vides", if (attendu_motif) "est attendue" else "n'est pas attendue"),
          chemin("types_evenements.csv"), i + 1L)
  }
}
# Automate : puces reconnues, etats absorbants sans transition sortante.
automate <- derive_automate(lignes)
for (k in seq_along(automate$etiquette)) {
  e <- automate$etiquette[k]
  if (e == "Etats absorbants") {
    if (!grepl("\u00ab \u00e9teint \u00bb", automate$suite[k], fixed = TRUE) || !grepl("\u00ab retraite \u00bb", automate$suite[k], fixed = TRUE) ||
        any(unlist(lapply(te$etat_depuis, eclater)) %in% c("eteint", "retraite"))) {
      echec("automate : \u00e9tats absorbants", chemin_texte, automate$lignes[k])
    }
  } else if (!(e %in% PUCES_AUTOMATE) && !startsWith(e, "Toute autre suite")) {
    echec(sprintf("automate : puce non reconnue \u00ab %s \u00bb", e), chemin_texte, automate$lignes[k])
  }
}
if (!setequal(unique(unlist(lapply(te$etat_depuis, eclater))), ETATS_AUTOMATE)) {
  echec("automate : les quatre \u00e9tats de d\u00e9part des puces ne sont pas tous employ\u00e9s", chemin("types_evenements.csv"))
}
if (.n_echec == avant) {
  ok("types_evenements.csv : colonne motif attendue si et seulement si le type a des motifs ; puces de l'automate reconnues, \u00e9tats absorbants sans sortie")
}

# Sous-parametres des defauts (seul champ transcrit a la main).
avant <- .n_echec
for (i in seq_len(nrow(de))) {
  sp <- eclater(de$sous_parametres[i])
  cellule <- defauts_t$cellule_intensite[i]
  j <- jetons(cellule)
  absents <- sp[!(sp %in% j)]
  if (length(absents)) {
    echec(sprintf("%s : sous-param\u00e8tres absents de la cellule d'intensit\u00e9 : %s", de$code[i], paste(absents, collapse = ", ")),
          chemin("defauts.csv"), i + 1L)
  } else if (!identical(sp, j[j %in% sp][!duplicated(j[j %in% sp])])) {
    echec(sprintf("%s : sous-param\u00e8tres hors de l'ordre de la cellule d'intensit\u00e9", de$code[i]), chemin("defauts.csv"), i + 1L)
  }
  # Un sous-parametre ne porte pas le nom d'une table ni d'une modalite : sans cette regle,
  # un jeton de la cellule qui designe une table (tables tirees de D04b) ou une modalite
  # pourrait etre ajoute aux sous-parametres sans ecart (reserve R1 de l'audit, M138).
  confondus <- sp[sp %in% c(noms_tables, toutes_modalites)]
  if (length(confondus)) {
    echec(sprintf("%s : sous-param\u00e8tres qui portent le nom d'une table ou d'une modalit\u00e9 : %s", de$code[i],
                  paste(confondus, collapse = ", ")), chemin("defauts.csv"), i + 1L)
  }
  autres <- setdiff(j[-1L], c(sp, noms_tables, toutes_modalites))
  if (length(autres)) {
    echec(sprintf("%s : jetons de la cellule d'intensit\u00e9 non retenus : %s", de$code[i], paste(autres, collapse = ", ")),
          chemin("defauts.csv"), i + 1L)
  }
}
if (.n_echec == avant) ok("defauts.csv : sous-param\u00e8tres nomm\u00e9s dans la cellule d'intensit\u00e9, dans son ordre, aucun jeton oubli\u00e9, aucun nom de table ni de modalit\u00e9")

fin()
