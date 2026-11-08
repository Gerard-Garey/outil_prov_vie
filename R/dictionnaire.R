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

# Points de code tenus pour des blancs (objet absent de controles.csv) : tabulation à retour
# chariot, espace, U+0085, U+00A0, U+1680, U+2000 à U+200B, U+2028, U+2029, U+202F, U+205F,
# U+3000, U+FEFF.
.BLANCS_UNICODE <- c(9:13, 32L, 0x85L, 0xA0L, 0x1680L, 0x2000:0x200B, 0x2028L, 0x2029L,
                     0x202FL, 0x205FL, 0x3000L, 0xFEFFL)

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
    # dans la table cible, qui n'en fait pas une clé de cette table. Une référence simple ne
    # vise pas la colonne qui la porte (réserve m3 de l'audit de #31).
    ref <- col$reference[i]
    if (ref != "") {
      cibles <- strsplit(.eclater(ref), ".", fixed = TRUE)
      if (!grepl("^[a-z_]+\\.[a-z_]+(;[a-z_]+\\.[a-z_]+)*$", ref) ||
          !all(vapply(cibles, function(m) existe(m[1L], m[2L]), NA))) {
        echec("colonnes.csv", i, paste0("r\u00e9f\u00e9rence vers une colonne inconnue : ", ref))
      }
      if (length(cibles) == 1L && cibles[[1L]][1L] == col$table[i] && cibles[[1L]][2L] == col$colonne[i]) {
        echec("colonnes.csv", i, paste0("r\u00e9f\u00e9rence vers la colonne qui la porte : ", ref))
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

  # controles.csv (version 1.5, section 1.10) : au moins un code ; codes distincts et bien
  # formés (minuscules et soulignés, donc disjoints des codes D.. de defauts.csv) ; objet
  # renseigné (pas seulement des blancs, Unicode compris) ; détection sans
  # valeur répétée ; motif de refus d'appel vide ou élément de MOTIFS_REFUS. Lien de même nom entre un code et le refus
  # d'appel (ADR 0010, sixième série, (a) ; réserve m2 de l'audit de #31) : un code qui est
  # aussi un élément de MOTIFS_REFUS porte ce motif en motif_refus_appel, et un motif de
  # refus d'appel renseigné est celui du code ; l'intersection des codes avec MOTIFS_REFUS
  # est donc exactement l'ensemble des motifs de refus d'appel renseignés.
  ctl <- dico$controles
  if (nrow(ctl) == 0L) .refus_dictionnaire("controles.csv : aucun code")
  if (anyDuplicated(ctl$code) || !all(grepl("^[a-z_]+$", ctl$code))) {
    .refus_dictionnaire("controles.csv : codes distincts, en minuscules et soulign\u00e9s, attendus")
  }
  for (i in seq_len(nrow(ctl))) {
    # blancs Unicode compris (BLANCS_UNICODE : séparateurs Zs, Zl, Zp, contrôles d'espacement,
    # espace sans chasse U+200B et marque U+FEFF), par points de code, indépendamment de la
    # locale : réserve m-b de l'audit
    if (all(utf8ToInt(enc2utf8(ctl$objet[i])) %in% .BLANCS_UNICODE)) {
      echec("controles.csv", i, "objet absent")
    }
    d <- .eclater(ctl$detection[i])
    if (length(d) == 0L || !all(d %in% c("exacte", "presomptive")) || anyDuplicated(d)) {
      echec("controles.csv", i, "d\u00e9tection : exacte ou presomptive, sans r\u00e9p\u00e9tition")
    }
    if (!(ctl$portee[i] %in% PORTEES_CONTROLES)) {
      echec("controles.csv", i, paste0("port\u00e9e hors de ", paste(PORTEES_CONTROLES, collapse = ", "), " : ", ctl$portee[i]))
    }
    motif <- ctl$motif_refus_appel[i]
    if (motif != "" && !(motif %in% MOTIFS_REFUS)) {
      echec("controles.csv", i, paste0("motif de refus d'appel hors de MOTIFS_REFUS : ", motif))
    }
    if ((ctl$code[i] %in% MOTIFS_REFUS || motif != "") && motif != ctl$code[i]) {
      echec("controles.csv", i, paste0("motif de refus d'appel diff\u00e9rent du code (", ctl$code[i],
                                       ") : un code qui est un motif de refus d'appel porte ce motif, et lui seul"))
    }
  }
  invisible(NULL)
}

# --- Contrôle des types d'une base -----------------------------------------------

# Porte stricte (ADR 0010, cinquième série, (a) 2 et 3) : contrôle, sans rien convertir,
# qu'une base (liste nommée de data.frame, une par table du dictionnaire, toutes
# facultatives ici) a la forme du dictionnaire, et lève un refus d'appel au premier des
# trois temps qui échoue :
#   1. structure (liste_invalide) : liste nommée aux noms renseignés et distincts, tables
#      connues du dictionnaire, chaque table un data.frame aux noms de colonnes renseignés
#      et distincts ;
#   2. table extraction : version du dictionnaire attendue (controler_version_extraction),
#      puis une ligne exactement (extraction_invalide) ;
#   3. écarts de forme de toutes les tables présentes, relevés par constater_forme()
#      (colonne inconnue, colonne O ou C absente, type R) : tous sont relevés avant le
#      refus, nommés dans le message et comptés dans `nombre` ; le motif (colonne_inconnue,
#      colonne_absente ou type_incompatible), la table, la colonne, `attendu` et `recu` sont
#      ceux du premier écart (tables dans l'ordre du dictionnaire, puis ordre de
#      constater_forme()) ; `identifiants` porte <table>.<colonne> des écarts (dix au plus).
# Rend `donnees` inchangée, invisible. Une table obligatoire absente n'est pas refusée
# ici : c'est le contrôle de la base entière (module `donnees`) ; une feuille seule peut
# ainsi être contrôlée.
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
  tables <- dico$tables$table[dico$tables$table %in% noms]
  for (table in tables) .controler_structure_table(donnees[[table]], table)
  if ("extraction" %in% tables) {
    controler_version_extraction(donnees[["extraction"]])
    .controler_extraction(donnees[["extraction"]])
  }
  constats <- lapply(tables, function(table) constater_forme(donnees[[table]], table, dico))
  constats <- do.call(rbind, c(list(.constats_forme()), constats))
  if (nrow(constats) > 0L) {
    refuser(paste0("controler_types() : ", nrow(constats), " \u00e9cart(s) de forme (aucune conversion) : ",
                   paste(constats$message, collapse = " ; ")),
            constats$code[1L], module = "dictionnaire", table = constats$table[1L],
            colonne = constats$colonne[1L], nombre = nrow(constats),
            identifiants = paste(constats$table, constats$colonne, sep = "."),
            attendu = constats$attendu[1L], recu = constats$recu[1L])
  }
  invisible(donnees)
}

# Structure d'une table (refus d'appel liste_invalide) : un data.frame aux noms de colonnes
# renseignés et distincts.
.controler_structure_table <- function(donnee, table) {
  if (!is.data.frame(donnee)) {
    refuser(paste0("controler_types() : la table ", table, " n'est pas un data.frame"),
            "liste_invalide", module = "dictionnaire", table = table)
  }
  noms <- names(donnee)
  if (anyNA(noms) || any(!nzchar(noms)) || anyDuplicated(noms)) {
    refuser(paste0("table ", table, " : noms de colonnes renseign\u00e9s et distincts attendus"),
            "liste_invalide", module = "dictionnaire", table = table)
  }
  invisible(NULL)
}

# Écarts de forme, sans constat : data.frame vide de la forme que rend constater_forme().
.constats_forme <- function(table = character(0), colonne = character(0), code = character(0),
                            attendu = character(0), recu = character(0), nombre = integer(0),
                            lignes = list(), message = character(0)) {
  constats <- data.frame(table = table, colonne = colonne, code = code, attendu = attendu, recu = recu,
                         nombre = nombre, stringsAsFactors = FALSE)
  constats$lignes <- lignes
  constats$message <- message
  constats
}

# Relève, sans s'interrompre, les écarts de forme d'une table contre le dictionnaire `dico`
# (objet rendu par dictionnaire()) ; seam de la règle de forme, appelé par controler_types()
# (porte stricte) et, avec le lot `donnees`, par controler_base() (bilan) (ADR 0010,
# cinquième série, (a) 3). Ne convertit rien. Refuse (liste_invalide) seulement ce qui n'est
# pas une table du dictionnaire : table inconnue, objet qui n'est pas un data.frame, noms de
# colonnes non renseignés ou non distincts (structure des arguments, (a) 1).
# Rend un data.frame, une ligne par écart : d'abord les colonnes inconnues (ordre de la
# table), puis les colonnes du dictionnaire dans leur ordre (absente, ou type) ; colonnes :
#   table, colonne ;
#   code : colonne_inconnue, colonne_absente (colonne O ou C) ou type_incompatible, codes
#     de controles.csv ;
#   attendu : type déclaré (NA hors type_incompatible) ; recu : classe R reçue, et typeof
#     pour une Date (NA hors type_incompatible) ;
#   nombre, lignes : lignes de la table concernées, et leurs numéros (liste) ; pour
#     type_incompatible, les valeurs illisibles dans le type déclaré (lire_texte_type())
#     d'une colonne character restée en texte, sinon toutes les lignes (la colonne entière
#     a un autre type, ou toutes ses valeurs se lisent mais n'ont pas été converties) ;
#     NA et aucune ligne pour une colonne absente ou inconnue ;
#   message : l'écart en clair.
constater_forme <- function(donnee, table, dico) {
  if (!is.character(table) || length(table) != 1L || is.na(table) || !(table %in% dico$tables$table)) {
    refuser("constater_forme() : `table` doit \u00eatre le nom d'une table du dictionnaire",
            "liste_invalide", module = "dictionnaire")
  }
  .controler_structure_table(donnee, table)
  colonnes <- dico$colonnes[dico$colonnes$table == table, , drop = FALSE]
  noms <- names(donnee)
  n <- nrow(donnee)
  ecarts <- list()
  ajouter <- function(colonne, code, message, attendu = NA_character_, recu = NA_character_,
                      lignes = NULL) {
    ecarts[[length(ecarts) + 1L]] <<- .constats_forme(
      table, colonne, code, attendu, recu,
      if (is.null(lignes)) NA_integer_ else length(lignes),
      list(if (is.null(lignes)) integer(0) else lignes), paste0("table ", table, ", colonne ", colonne, " : ", message))
  }
  for (colonne in setdiff(noms, colonnes$colonne)) {
    ajouter(colonne, "colonne_inconnue", "colonne inconnue du dictionnaire")
  }
  for (i in seq_len(nrow(colonnes))) {
    colonne <- colonnes$colonne[i]
    type <- colonnes$type[i]
    if (!(colonne %in% noms)) {
      if (colonnes$obligatoire[i] %in% c("O", "C")) {
        ajouter(colonne, "colonne_absente", "colonne obligatoire ou conditionnelle absente")
      }
      next
    }
    x <- donnee[[colonne]]
    if (.type_conforme(x, type)) next
    recu <- paste(class(x), collapse = ",")
    if (inherits(x, "Date")) recu <- paste0(recu, " (", typeof(x), ")")
    lignes <- seq_len(n)
    precision <- ""
    if (type != "character" && identical(class(x), "character") && is.null(dim(x))) {
      lu <- lire_texte_type(x, type)
      if (length(lu$illisibles) > 0L) {
        lignes <- lu$illisibles
        precision <- paste0(" ; ", length(lignes), " valeur(s) illisible(s) dans le type ", type,
                            lu$precision, ", premi\u00e8re \u00ab ", x[lignes[1L]], " \u00bb (ligne ",
                            lignes[1L], ")")
      } else {
        precision <- paste0(" ; toutes les valeurs se lisent dans le type ", type, ", la colonne n'est pas convertie")
      }
    } else if (type == "Date" && identical(class(x), "Date") && !is.double(x)) {
      precision <- paste0(" ; une Date stock\u00e9e en entier (typeof integer) n'a pas la repr\u00e9sentation canonique",
                          " d'une Date stock\u00e9e en double (typeof double, forme de la lecture CSV) : les",
                          " empreintes et la reproductibilit\u00e9 au bit pr\u00e8s en d\u00e9pendent ; corriger par",
                          " x <- as.Date(as.numeric(x)), ou construire les dates par as.Date() sur des",
                          " cha\u00eenes AAAA-MM-JJ")
    }
    ajouter(colonne, "type_incompatible", paste0("type ", type, " attendu, ", recu, " re\u00e7u", precision),
            attendu = type, recu = recu, lignes = lignes)
  }
  constats <- do.call(rbind, c(list(.constats_forme()), ecarts))
  rownames(constats) <- NULL
  constats
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

# Grammaire stricte d'une colonne de texte (NA : champ vide) dans un type du dictionnaire
# (section 1.2) ; une valeur qui n'est pas exactement l'écriture du type est illisible,
# jamais convertie :
#   logical : TRUE ou FALSE ;
#   integer : entier décimal sans point ni exposant, dans les bornes des entiers de R ;
#   numeric : nombre décimal à point, exposant facultatif, fini, sans soupassement (une
#     valeur non nulle écrite ne se lit pas 0) ;
#   Date : AAAA-MM-JJ, date existante ;
#   character : toute chaîne, "" comprise (une chaîne vide n'est pas un manquant, § 1.6 ;
#     elle est illisible dans tout autre type).
# Rend une liste : `valeurs`, la colonne dans son type (Date stockée en double) si toutes
# ses valeurs se lisent, NULL sinon ; `illisibles`, numéros des valeurs illisibles,
# croissants ; `precision`, règle que la première valeur illisible ne suit pas ("" sans
# valeur illisible). Ne refuse rien. Appelée par `lecture` (lire_base) et par
# constater_forme() (ADR 0010, cinquième série, (a) 3).
lire_texte_type <- function(x, type) {
  if (!identical(class(x), "character") || !is.null(dim(x))) {
    stop("lire_texte_type() : `x` doit \u00eatre un vecteur character", call. = FALSE)
  }
  if (!is.character(type) || length(type) != 1L || !(type %in% TYPES_DICTIONNAIRE)) {
    stop("lire_texte_type() : `type` hors des cinq types du dictionnaire", call. = FALSE)
  }
  presents <- !is.na(x)
  raison <- character(length(x))
  marquer <- function(ecarts, precision) raison[ecarts & !nzchar(raison)] <<- precision
  if (type == "logical") {
    marquer(presents & !(x %in% c("TRUE", "FALSE")), " (TRUE ou FALSE)")
  } else if (type == "integer") {
    forme <- presents & grepl("^-?[0-9]+$", x)
    marquer(presents & !forme, " (entier d\u00e9cimal sans point ni exposant)")
    bornes <- rep(TRUE, length(x))
    bornes[forme] <- abs(as.numeric(x[forme])) <= .Machine$integer.max
    marquer(!bornes, " (hors des bornes des entiers de R)")
  } else if (type == "numeric") {
    forme <- presents & grepl("^-?[0-9]+(\\.[0-9]+)?([eE][-+]?[0-9]+)?$", x)
    marquer(presents & !forme, " (nombre d\u00e9cimal \u00e0 point, exposant facultatif)")
    nombres <- as.numeric(x[forme])
    # un dépassement rendrait Inf, un soupassement 0 : aucun des deux n'est la valeur écrite
    etendue <- rep(TRUE, length(x))
    etendue[forme] <- is.finite(nombres) & !(nombres == 0 & grepl("[1-9]", sub("[eE].*$", "", x[forme])))
    marquer(!etendue, " (hors de l'\u00e9tendue des r\u00e9els double pr\u00e9cision)")
  } else if (type == "Date") {
    forme <- presents & grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", x)
    marquer(presents & !forme, " (AAAA-MM-JJ)")
    existe <- rep(TRUE, length(x))
    existe[forme] <- !is.na(as.Date(x[forme], format = "%Y-%m-%d"))
    marquer(!existe, " (date inexistante)")
  }
  illisibles <- which(nzchar(raison))
  if (length(illisibles) > 0L) {
    return(list(valeurs = NULL, illisibles = illisibles, precision = raison[illisibles[1L]]))
  }
  valeurs <- switch(type,
                    character = x,
                    logical = x == "TRUE",
                    integer = as.integer(as.numeric(x)),
                    numeric = as.numeric(x),
                    Date = as.Date(x, format = "%Y-%m-%d"))
  list(valeurs = valeurs, illisibles = integer(0), precision = "")
}

# Table extraction : version du dictionnaire égale à VERSION_DICTIONNAIRE_ATTENDUE (ADR 0010,
# point 23 et annotations ; M117), contrôlée avant les autres colonnes de la table quand
# version_dictionnaire est présente et de type character : une base d'une autre version est
# refusée pour sa version (extraction_invalide), non pour une colonne inconnue de la version
# attendue ; absente ou d'un autre type, le contrôle des colonnes la refuse (colonne_absente,
# type_incompatible). Sans point (ADR 0010, quatrième série, (c)) : appelée hors de son
# module, par `lecture` (lire_base, avant la lecture typée des autres colonnes) ; rend
# NULL, invisible.
controler_version_extraction <- function(donnee) {
  if (!("version_dictionnaire" %in% names(donnee))) return(invisible(NULL))
  versions <- donnee[["version_dictionnaire"]]
  if (!.type_conforme(versions, "character")) return(invisible(NULL))
  ecarts <- which(is.na(versions) | versions != VERSION_DICTIONNAIRE_ATTENDUE)
  if (length(ecarts) > 0L) {
    version <- versions[ecarts[1L]]
    cite <- if (is.na(version)) "manquante" else paste0("\u00ab ", version, " \u00bb")   # "" compris (m-a)
    refuser(paste0("table extraction : version du dictionnaire ", cite,
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
