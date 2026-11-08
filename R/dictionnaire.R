# Module `dictionnaire` (ADR 0010, points 1, 2 et 23) : lecture et validation de la forme
# lisible par machine du dictionnaire de la base brute (sept CSV et dictionnaire.txt sous
# inst/extdata/dictionnaire/, transcription du texte visé
# docs/specifications/dictionnaire-base-v1.md, contrôlée par
# tests/controles/concordance_dictionnaire.R) ; contrôle des types d'une base.
# N'appelle que le module `outils`. Ne lit que ses propres fichiers, à la demande
# (system.file()), jamais un fichier de l'utilisateur. Le moteur ne parle pas (point 12).
# Code ASCII hors commentaires (M112) : les accents des chaînes s'écrivent en \uXXXX.
# Convention de ce fichier : une fonction dont le nom commence par un point est un
# auxiliaire du module ; la concordance documentation <-> code ne recense que les autres.
#
# Forme des champs multiples des CSV : valeurs jointes par « ; » (ADR 0010, point 23).
# Formes propres à types_evenements.csv, que l'ADR ne détaille pas :
#   - niveau : `sinistre`, `dossier`, `rente`, joints par « ; » ;
#   - garanties : codes de garantie ou natures de sinistre joints par « ; », ou `toutes` ;
#   - programmable : `oui`, `non`, ou `oui:<motif>;<motif>` (programmable pour ces motifs) ;
#   - automate du sinistre d'arrêt de travail (section 4 du texte) : etat_depuis vaut
#     `depart` pour un événement d'entrée, sinon les états de départ joints par « ; »
#     (`incapacite`, `invalidite`, `clos:reprise_travail` pour un état clos par ce motif) ;
#     etat_vers vaut l'état d'arrivée, `anterieur` pour la rechute (état antérieur à la
#     sortie), et pour la sortie `<etat>:<motif>,<motif>` joints par « ; » (état d'arrivée
#     selon le motif) ; les deux sont vides hors de l'automate.

# --- Constantes ------------------------------------------------------------------

TYPES_DICTIONNAIRE <- c("character", "integer", "numeric", "Date", "logical")   # section 1.2

# Valeurs de colonnes.csv, futur_admis (section 1.4 du texte) : TRUE (date future admise),
# FALSE (borne haute : la date d'extraction), programmable (date future admise pour un type
# d'événement programmable seulement : evenements.date_effet, renvoi à
# types_evenements.programmable, motif compris).
FUTUR_ADMIS_VALEURS <- c("TRUE", "FALSE", "programmable")

# Valeurs de controles.csv, portee (section 1.10 du texte, version 1.5) : colonne, table,
# colonne_table (colonne, ou table pour une colonne de clé), ligne (signalement).
PORTEES_CONTROLES <- c("colonne", "table", "colonne_table", "ligne")

FICHIERS_DICTIONNAIRE <- c("tables.csv", "colonnes.csv", "types_evenements.csv",
                           "parametres.csv", "defauts.csv", "filiation.csv", "controles.csv")

COLONNES_DICTIONNAIRE <- list(                                                  # point 23
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
  filiation.csv = c("table_de", "colonne_de", "table_v1", "colonne_v1", "statut", "motif"),
  # Version 1.5 : colonnes du tableau du texte (section 1.10), et non celles proposées par
  # l'annotation de la cinquième série de l'ADR, (e) (code, portee, description, section).
  controles.csv = c("code", "objet", "detection", "portee", "motif_refus_appel")
)

# --- Lecture du dictionnaire -----------------------------------------------------

# Rend le dictionnaire de la base, lu et validé à chaque appel depuis
# inst/extdata/dictionnaire/ du package installé : liste nommée `version`, `date_visa`,
# `tables`, `colonnes`, `types_evenements`, `parametres`, `defauts`, `filiation`, `controles` (un
# data.frame par CSV, colonnes de texte, sauf `types_evenements$ordre` entier ;
# `colonnes$futur_admis` vaut "TRUE", "FALSE" ou "programmable", FUTUR_ADMIS_VALEURS). Refus `dictionnaire_invalide` si la forme lue n'est pas
# celle attendue (version, empreintes, colonnes, références internes).
dictionnaire <- function() {
  .lire_dictionnaire(system.file("extdata", "dictionnaire", package = "provie"))
}

.refus_dictionnaire <- function(message, ...) {
  refuser(paste0("dictionnaire de la base : ", message), "dictionnaire_invalide",
          module = "dictionnaire", ...)
}

.eclater <- function(x) if (identical(x, "")) character(0) else strsplit(x, ";", fixed = TRUE)[[1L]]

# Lit et valide le dictionnaire du dossier donné (dictionnaire() lui passe celui du package ;
# les tests lui passent une copie altérée).
.lire_dictionnaire <- function(dossier) {
  if (!is.character(dossier) || length(dossier) != 1L || is.na(dossier) || !nzchar(dossier) ||
      !dir.exists(dossier)) {
    .refus_dictionnaire("dossier inst/extdata/dictionnaire introuvable")
  }
  chemin_entete <- file.path(dossier, "dictionnaire.txt")
  if (!file.exists(chemin_entete)) .refus_dictionnaire("dictionnaire.txt absent")
  entete <- tryCatch(lire_liste(.lire_octets(chemin_entete)), refus_provie = function(e) {
    .refus_dictionnaire(paste0("dictionnaire.txt illisible (", conditionMessage(e), ")"))
  })
  .valider_entete(entete)
  lus <- lapply(FICHIERS_DICTIONNAIRE, function(f) {
    .lire_csv_dictionnaire(file.path(dossier, f), f, entete$empreintes[[f]])
  })
  names(lus) <- FICHIERS_DICTIONNAIRE
  dico <- list(version = entete$version, date_visa = entete$date_visa,
               tables = lus[["tables.csv"]], colonnes = lus[["colonnes.csv"]],
               types_evenements = lus[["types_evenements.csv"]],
               parametres = lus[["parametres.csv"]], defauts = lus[["defauts.csv"]],
               filiation = lus[["filiation.csv"]], controles = lus[["controles.csv"]])
  if (!all(dico$colonnes$futur_admis %in% FUTUR_ADMIS_VALEURS)) {
    .refus_dictionnaire("colonnes.csv, futur_admis : TRUE, FALSE ou programmable attendu")
  }
  dico$types_evenements$ordre <- .vers_ordre(dico$types_evenements$ordre)
  .valider_dictionnaire(dico)
  dico
}

.lire_octets <- function(chemin) readBin(chemin, "raw", n = file.info(chemin)$size)

.valider_entete <- function(entete) {
  if (!identical(names(entete), c("version", "date_visa", "empreintes"))) {
    .refus_dictionnaire("dictionnaire.txt doit porter version, date_visa et empreintes, dans cet ordre")
  }
  version <- entete$version
  if (!is.character(version) || length(version) != 1L || is.na(version)) {
    .refus_dictionnaire("version absente de dictionnaire.txt")
  }
  if (version != VERSION_DICTIONNAIRE_ATTENDUE) {
    .refus_dictionnaire(paste0("version ", version, " ; version attendue par le moteur : ",
                               VERSION_DICTIONNAIRE_ATTENDUE),
                        attendu = VERSION_DICTIONNAIRE_ATTENDUE, recu = version)
  }
  if (!inherits(entete$date_visa, "Date") || length(entete$date_visa) != 1L || is.na(entete$date_visa)) {
    .refus_dictionnaire("date_visa doit \u00eatre une date unique")
  }
  empreintes <- entete$empreintes
  if (!is.list(empreintes) || !identical(names(empreintes), FICHIERS_DICTIONNAIRE) ||
      !all(vapply(empreintes, function(e) {
        is.character(e) && length(e) == 1L && !is.na(e) && grepl("^[0-9a-f]{32}$", e)
      }, NA))) {
    .refus_dictionnaire("empreintes : une empreinte MD5 par CSV, dans l'ordre de l'ADR 0010, point 23")
  }
  invisible(NULL)
}

# Lit un CSV du dictionnaire depuis les octets dont l'empreinte vient d'être vérifiée.
.lire_csv_dictionnaire <- function(chemin, fichier, empreinte_attendue) {
  if (!file.exists(chemin)) .refus_dictionnaire(paste0(fichier, " absent"))
  octets <- .lire_octets(chemin)
  recue <- empreinte(octets)
  if (recue != empreinte_attendue) {
    .refus_dictionnaire(paste0("empreinte de ", fichier, " diff\u00e9rente de celle de dictionnaire.txt"),
                        attendu = empreinte_attendue, recu = recue)
  }
  texte <- rawToChar(octets)
  Encoding(texte) <- "UTF-8"
  if (!validUTF8(texte)) .refus_dictionnaire(paste0(fichier, " n'est pas en UTF-8"))
  df <- tryCatch(
    utils::read.csv(text = texte, colClasses = "character", na.strings = character(0),
                    encoding = "UTF-8", check.names = FALSE, stringsAsFactors = FALSE),
    error = function(e) .refus_dictionnaire(paste0(fichier, " illisible (", conditionMessage(e), ")")))
  if (!identical(names(df), COLONNES_DICTIONNAIRE[[fichier]])) {
    .refus_dictionnaire(paste0("colonnes de ", fichier, " diff\u00e9rentes de celles de l'ADR 0010, point 23"))
  }
  df
}

.vers_ordre <- function(x) {
  if (!identical(x, as.character(seq_along(x)))) {
    .refus_dictionnaire("types_evenements.csv, ordre : 1, 2, 3... attendu")
  }
  seq_along(x)
}

# Références internes du dictionnaire : chaque nom cité existe là où il est cité.
.valider_dictionnaire <- function(dico) {
  tab <- dico$tables
  col <- dico$colonnes
  te <- dico$types_evenements
  par <- dico$parametres
  def <- dico$defauts
  fil <- dico$filiation
  echec <- function(fichier, i, message) {
    .refus_dictionnaire(sprintf("%s, ligne %d : %s", fichier, i + 1L, message))
  }
  noms_tables <- tab$table
  existe <- function(table, colonne) any(col$table == table & col$colonne == colonne)

  # tables.csv
  if (anyDuplicated(noms_tables) || !all(grepl("^[a-z_]+$", noms_tables)) ||
      !identical(tab$numero, paste0("T", seq_along(noms_tables)))) {
    .refus_dictionnaire("tables.csv : noms de tables distincts et num\u00e9ros T1, T2... attendus")
  }
  for (i in seq_len(nrow(tab))) {
    o <- tab$obligatoire[i]
    if (!(o %in% c("O", "F") || (startsWith(o, "F_si:") && substring(o, 6L) %in% noms_tables))) {
      echec("tables.csv", i, "obligatoire : O, F ou F_si:<table>")
    }
    for (c1 in .eclater(tab$cle_primaire[i])) {
      if (!existe(tab$table[i], c1)) echec("tables.csv", i, paste0("colonne de cl\u00e9 inconnue : ", c1))
    }
    if (!any(col$table == tab$table[i])) echec("tables.csv", i, "table sans colonne")
  }

  # colonnes.csv
  if (anyDuplicated(paste(col$table, col$colonne, sep = "."))) {
    .refus_dictionnaire("colonnes.csv : colonne d\u00e9crite deux fois")
  }
  codes_defauts <- def$code
  for (i in seq_len(nrow(col))) {
    if (!(col$table[i] %in% noms_tables)) echec("colonnes.csv", i, "table inconnue")
    if (!grepl("^[a-z_]+$", col$colonne[i])) echec("colonnes.csv", i, "nom de colonne mal form\u00e9")
    if (!(col$type[i] %in% TYPES_DICTIONNAIRE)) {
      echec("colonnes.csv", i, paste0("type hors des cinq types de la section 1.2 : ", col$type[i]))
    }
    if (!(col$obligatoire[i] %in% c("O", "C", "F"))) echec("colonnes.csv", i, "obligatoire : O, C ou F")
    if ((col$condition[i] != "") != (col$obligatoire[i] == "C")) {
      echec("colonnes.csv", i, "condition renseign\u00e9e si et seulement si la colonne est conditionnelle")
    }
    if (!(col$saisie[i] %in% c("", "S", "L", "V", "E", "P"))) echec("colonnes.csv", i, "saisie : S, L, V, E, P ou vide")
    if ((col$colonne_saisie[i] != "") != (col$saisie[i] == "P")) {
      echec("colonnes.csv", i, "colonne_saisie renseign\u00e9e si et seulement si la saisie est P")
    }
    if (col$colonne_saisie[i] != "" &&
        !any(col$table == col$table[i] & col$colonne == col$colonne_saisie[i] & col$saisie == "S")) {
      echec("colonnes.csv", i, "colonne_saisie : date de saisie (S) de la m\u00eame table attendue")
    }
    if (col$modalites[i] != "" && col$type[i] != "character") echec("colonnes.csv", i, "modalit\u00e9s d'une colonne non character")
    if (col$futur_admis[i] != "FALSE" && col$type[i] != "Date") echec("colonnes.csv", i, "futur admis pour une colonne non Date")
    if (col$futur_admis[i] == "programmable" && col$table[i] != "evenements") {
      echec("colonnes.csv", i, "futur admis programmable hors de la table evenements")
    }
    # reference : `table.colonne`, ou clé étrangère composite `table.c1;table.c2` (version
    # 1.4, affiliations.college) : toutes les colonnes visées dans une même table, autre que
    # la table de la ligne, chacune présente aussi dans la table de la ligne (colonne locale
    # de même nom), la colonne de la ligne parmi elles. Contrainte d'existence du n-uplet
    # dans la table cible, qui n'en fait pas une clé de cette table.
    ref <- col$reference[i]
    if (ref != "") {
      cibles <- strsplit(.eclater(ref), ".", fixed = TRUE)
      if (!grepl("^[a-z_]+\\.[a-z_]+(;[a-z_]+\\.[a-z_]+)*$", ref) ||
          !all(vapply(cibles, function(m) existe(m[1L], m[2L]), NA))) {
        echec("colonnes.csv", i, paste0("r\u00e9f\u00e9rence vers une colonne inconnue : ", ref))
      }
      if (length(cibles) > 1L) {
        if (length(unique(vapply(cibles, `[`, "", 1L))) != 1L) {
          echec("colonnes.csv", i, paste0("r\u00e9f\u00e9rence composite vers plusieurs tables : ", ref))
        }
        if (cibles[[1L]][1L] == col$table[i]) {
          echec("colonnes.csv", i, paste0("r\u00e9f\u00e9rence composite vers la table qui la porte : ", ref))
        }
        locales <- vapply(cibles, `[`, "", 2L)
        if (!(col$colonne[i] %in% locales)) {
          echec("colonnes.csv", i, paste0("r\u00e9f\u00e9rence composite dont le n-uplet ne contient pas la colonne de la ligne : ", ref))
        }
        if (anyDuplicated(locales)) {
          echec("colonnes.csv", i, paste0("r\u00e9f\u00e9rence composite qui cite deux fois une colonne : ", ref))
        }
        if (!all(vapply(locales, function(c1) existe(col$table[i], c1), NA))) {
          echec("colonnes.csv", i, paste0("r\u00e9f\u00e9rence composite dont une colonne locale manque : ", ref))
        }
      }
    }
    for (d in .eclater(col$defauts[i])) {
      if (!(d %in% codes_defauts || (grepl("[a-z]$", d) && sub("[a-z]$", "", d) %in% codes_defauts))) {
        echec("colonnes.csv", i, paste0("code de d\u00e9faut inconnu : ", d))
      }
    }
  }
  modalites_de <- function(table, colonne) .eclater(col$modalites[col$table == table & col$colonne == colonne])

  # types_evenements.csv
  codes_garantie <- modalites_de("garanties_souscrites", "code_garantie")
  natures <- modalites_de("sinistres", "nature_sinistre")
  if (anyDuplicated(te$type_evenement) ||
      !identical(te$type_evenement, modalites_de("evenements", "type_evenement"))) {
    .refus_dictionnaire("types_evenements.csv : types distincts, \u00e9gaux aux modalit\u00e9s de evenements.type_evenement")
  }
  motifs_evenements <- modalites_de("evenements", "motif")
  for (i in seq_len(nrow(te))) {
    if (!all(.eclater(te$niveau[i]) %in% c("sinistre", "dossier", "rente")) || te$niveau[i] == "") {
      echec("types_evenements.csv", i, "niveau : sinistre, dossier ou rente")
    }
    g <- .eclater(te$garanties[i])
    if (!(identical(g, "toutes") || (length(g) > 0L && all(g %in% c(codes_garantie, natures))))) {
      echec("types_evenements.csv", i, "garanties : codes de garantie, natures de sinistre ou toutes")
    }
    for (c1 in .eclater(te$colonnes_requises[i])) {
      if (!existe("evenements", c1)) echec("types_evenements.csv", i, paste0("colonne requise inconnue : ", c1))
    }
    m <- .eclater(te$motifs[i])
    if (!all(m %in% motifs_evenements)) echec("types_evenements.csv", i, "motif hors des modalit\u00e9s de evenements.motif")
    p <- te$programmable[i]
    if (!(p %in% c("oui", "non") ||
          (startsWith(p, "oui:") && all(.eclater(substring(p, 5L)) %in% m) && nchar(p) > 4L))) {
      echec("types_evenements.csv", i, "programmable : oui, non ou oui:<motifs du type>")
    }
    if ((te$etat_depuis[i] == "") != (te$etat_vers[i] == "")) {
      echec("types_evenements.csv", i, "etat_depuis et etat_vers renseign\u00e9s ensemble")
    }
  }
  if (!setequal(unique(unlist(lapply(te$motifs, .eclater))), motifs_evenements)) {
    .refus_dictionnaire("modalit\u00e9s de evenements.motif diff\u00e9rentes des motifs de types_evenements.csv")
  }

  # parametres.csv
  noms_parametres <- modalites_de("parametres", "parametre")
  if (anyDuplicated(paste(par$code_garantie, par$parametre))) {
    .refus_dictionnaire("parametres.csv : param\u00e8tre d\u00e9crit deux fois pour une garantie")
  }
  for (i in seq_len(nrow(par))) {
    if (!(par$code_garantie[i] %in% c(codes_garantie, "toutes"))) echec("parametres.csv", i, "code de garantie inconnu")
    if (!(par$parametre[i] %in% noms_parametres)) echec("parametres.csv", i, "param\u00e8tre hors des modalit\u00e9s de parametres.parametre")
    if (!(par$obligatoire[i] %in% c("O", "C", "F"))) echec("parametres.csv", i, "obligatoire : O, C ou F")
    for (c1 in .eclater(par$dimension[i])) {
      if (!existe("parametres", c1)) echec("parametres.csv", i, paste0("dimension inconnue : ", c1))
    }
  }

  # defauts.csv
  if (anyDuplicated(codes_defauts) || !all(grepl("^D[0-9]{2}[a-z]?$", codes_defauts))) {
    .refus_dictionnaire("defauts.csv : codes distincts de la forme D00 ou D00a attendus")
  }
  for (i in seq_len(nrow(def))) {
    if (!all(.eclater(def$tables[i]) %in% noms_tables)) echec("defauts.csv", i, "table inconnue")
    d <- .eclater(def$detection[i])
    if (length(d) == 0L || !all(d %in% c("exacte", "presomptive"))) echec("defauts.csv", i, "d\u00e9tection : exacte ou presomptive")
    tr <- .eclater(def$traitements[i])
    if (length(tr) == 0L || !all(tr %in% c("R", "X", "H", "S"))) echec("defauts.csv", i, "traitements : R, X, H ou S (section 1.10)")
    if (!grepl("^[a-z_]+$", def$parametre_intensite[i])) echec("defauts.csv", i, "param\u00e8tre d'intensit\u00e9 absent")
  }

  # filiation.csv
  for (i in seq_len(nrow(fil))) {
    if (!(fil$statut[i] %in% c("reprise", "renommee", "non_reprise"))) {
      echec("filiation.csv", i, "statut : reprise, renommee ou non_reprise")
    }
    if (!all(.eclater(fil$table_v1[i]) %in% noms_tables)) echec("filiation.csv", i, "table v1 inconnue")
    if (fil$statut[i] == "reprise" && !existe(fil$table_v1[i], fil$colonne_v1[i])) {
      echec("filiation.csv", i, "colonne reprise absente de sa table v1")
    }
  }

  # controles.csv (version 1.5, section 1.10) : codes distincts et bien formés (minuscules et
  # soulignés, donc disjoints des codes D.. de defauts.csv) ; motif de refus d'appel vide ou
  # élément de MOTIFS_REFUS.
  ctl <- dico$controles
  if (anyDuplicated(ctl$code) || !all(grepl("^[a-z_]+$", ctl$code))) {
    .refus_dictionnaire("controles.csv : codes distincts, en minuscules et soulign\u00e9s, attendus")
  }
  for (i in seq_len(nrow(ctl))) {
    if (!nzchar(ctl$objet[i])) echec("controles.csv", i, "objet absent")
    d <- .eclater(ctl$detection[i])
    if (length(d) == 0L || !all(d %in% c("exacte", "presomptive"))) echec("controles.csv", i, "d\u00e9tection : exacte ou presomptive")
    if (!(ctl$portee[i] %in% PORTEES_CONTROLES)) {
      echec("controles.csv", i, paste0("port\u00e9e hors de ", paste(PORTEES_CONTROLES, collapse = ", "), " : ", ctl$portee[i]))
    }
    if (ctl$motif_refus_appel[i] != "" && !(ctl$motif_refus_appel[i] %in% MOTIFS_REFUS)) {
      echec("controles.csv", i, paste0("motif de refus d'appel hors de MOTIFS_REFUS : ", ctl$motif_refus_appel[i]))
    }
  }
  invisible(NULL)
}

# --- Contrôle des types d'une base -----------------------------------------------

# Contrôle, sans rien convertir, qu'une base (liste nommée de data.frame, une par table du
# dictionnaire, toutes facultatives ici) a la forme du dictionnaire : tables connues,
# colonnes connues (colonne_inconnue), colonnes O et C présentes (colonne_absente), type R
# exact de chaque colonne présente parmi les cinq de la section 1.2 (type_incompatible) ;
# pour la table extraction, la version du dictionnaire attendue, lue en premier quand la
# colonne est présente et de type character, puis une ligne exactement (extraction_invalide). Les tables sont examinées dans l'ordre du dictionnaire, les
# colonnes aussi ; le premier écart lève le refus. Rend `donnees` inchangée, invisible.
# Une table obligatoire absente n'est pas refusée ici : c'est le contrôle de la base entière
# (module `donnees`) ; une feuille seule peut ainsi être contrôlée.
controler_types <- function(donnees) {
  dico <- dictionnaire()
  if (!is.list(donnees) || is.data.frame(donnees) || !is.null(attr(donnees, "dim"))) {
    refuser("controler_types() : `donnees` doit \u00eatre une liste nomm\u00e9e de data.frame (une par table)",
            "liste_invalide", module = "dictionnaire")
  }
  noms <- names(donnees)
  if (length(donnees) > 0L && (is.null(noms) || anyNA(noms) || any(!nzchar(noms)) || anyDuplicated(noms))) {
    refuser("controler_types() : les tables de la liste doivent avoir des noms renseign\u00e9s et distincts",
            "liste_invalide", module = "dictionnaire")
  }
  inconnues <- setdiff(noms, dico$tables$table)
  if (length(inconnues) > 0L) {
    refuser(paste0("controler_types() : table(s) inconnue(s) du dictionnaire : ", paste(inconnues, collapse = ", ")),
            "liste_invalide", module = "dictionnaire", table = inconnues[1L], nombre = length(inconnues))
  }
  for (table in dico$tables$table[dico$tables$table %in% noms]) {
    donnee <- donnees[[table]]
    if (!is.data.frame(donnee)) {
      refuser(paste0("controler_types() : la table ", table, " n'est pas un data.frame"),
              "liste_invalide", module = "dictionnaire", table = table)
    }
    if (table == "extraction") .controler_version_extraction(donnee)
    .controler_types_table(donnee, table, dico$colonnes[dico$colonnes$table == table, , drop = FALSE])
    if (table == "extraction") .controler_extraction(donnee)
  }
  invisible(donnees)
}

.controler_types_table <- function(donnee, table, colonnes) {
  noms <- names(donnee)
  if (anyNA(noms) || any(!nzchar(noms)) || anyDuplicated(noms)) {
    refuser(paste0("table ", table, " : noms de colonnes renseign\u00e9s et distincts attendus"),
            "liste_invalide", module = "dictionnaire", table = table)
  }
  inconnues <- setdiff(noms, colonnes$colonne)
  if (length(inconnues) > 0L) {
    refuser(paste0("table ", table, " : colonne(s) inconnue(s) du dictionnaire : ",
                   paste(inconnues, collapse = ", ")),
            "colonne_inconnue", module = "dictionnaire", table = table, colonne = inconnues[1L],
            nombre = length(inconnues))
  }
  requises <- colonnes$colonne[colonnes$obligatoire %in% c("O", "C")]
  absentes <- setdiff(requises, noms)
  if (length(absentes) > 0L) {
    refuser(paste0("table ", table, " : colonne(s) obligatoire(s) ou conditionnelle(s) absente(s) : ",
                   paste(absentes, collapse = ", ")),
            "colonne_absente", module = "dictionnaire", table = table, colonne = absentes[1L],
            nombre = length(absentes))
  }
  for (i in which(colonnes$colonne %in% noms)) {
    x <- donnee[[colonnes$colonne[i]]]
    type <- colonnes$type[i]
    if (!.type_conforme(x, type)) {
      recu <- paste(class(x), collapse = ",")
      if (inherits(x, "Date")) recu <- paste0(recu, " (", typeof(x), ")")
      explication <- if (type == "Date" && identical(class(x), "Date") && !is.double(x)) {
        paste0(" ; une Date stock\u00e9e en entier (typeof integer) n'a pas la repr\u00e9sentation canonique",
               " d'une Date stock\u00e9e en double (typeof double, forme de la lecture CSV) : les",
               " empreintes et la reproductibilit\u00e9 au bit pr\u00e8s en d\u00e9pendent ; corriger par",
               " x <- as.Date(as.numeric(x)), ou construire les dates par as.Date() sur des",
               " cha\u00eenes AAAA-MM-JJ")
      } else ""
      refuser(paste0("table ", table, ", colonne ", colonnes$colonne[i], " : type ", type,
                     " attendu, ", recu, " re\u00e7u (aucune conversion)", explication),
              "type_incompatible", module = "dictionnaire", table = table,
              colonne = colonnes$colonne[i], attendu = type, recu = recu)
    }
  }
  invisible(NULL)
}

# Type R exact : la classe est celle du type, sans dimension ; une Date est stockée en
# double (forme d'ecrire_valeurs() et de la lecture CSV).
.type_conforme <- function(x, type) {
  if (!is.null(dim(x))) return(FALSE)
  switch(type,
         character = identical(class(x), "character"),
         integer = identical(class(x), "integer"),
         numeric = identical(class(x), "numeric"),
         logical = identical(class(x), "logical"),
         Date = identical(class(x), "Date") && is.double(x),
         FALSE)
}

# Table extraction : version du dictionnaire égale à VERSION_DICTIONNAIRE_ATTENDUE (ADR 0010,
# point 23 et annotations ; M117), contrôlée avant les autres colonnes de la table quand
# version_dictionnaire est présente et de type character : une base d'une autre version est
# refusée pour sa version (extraction_invalide), non pour une colonne inconnue de la version attendue ;
# absente ou d'un autre type, le contrôle des colonnes la refuse (colonne_absente,
# type_incompatible).
.controler_version_extraction <- function(donnee) {
  if (!("version_dictionnaire" %in% names(donnee))) return(invisible(NULL))
  versions <- donnee[["version_dictionnaire"]]
  if (!.type_conforme(versions, "character")) return(invisible(NULL))
  ecarts <- which(is.na(versions) | versions != VERSION_DICTIONNAIRE_ATTENDUE)
  if (length(ecarts) > 0L) {
    version <- versions[ecarts[1L]]
    refuser(paste0("table extraction : version du dictionnaire ", if (is.na(version)) "manquante" else version,
                   " ; version attendue : ", VERSION_DICTIONNAIRE_ATTENDUE),
            "extraction_invalide", module = "dictionnaire", table = "extraction",
            colonne = "version_dictionnaire", attendu = VERSION_DICTIONNAIRE_ATTENDUE, recu = version)
  }
  invisible(NULL)
}

# Table extraction : une ligne exactement (section 3, T1).
.controler_extraction <- function(donnee) {
  n <- nrow(donnee)
  if (n != 1L) {
    refuser(paste0("table extraction : une ligne exactement attendue, ", n, " re\u00e7ue(s)"),
            "extraction_invalide", module = "dictionnaire", table = "extraction",
            nombre = n, attendu = "1", recu = as.character(n))
  }
  invisible(NULL)
}
