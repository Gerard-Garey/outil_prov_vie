# Module `garanties` (ADR 0010, points 1 et 16 ; spécification de B2,
# docs/specifications/b2-capital-deces-v1.md, § 4.1) : lecture et validation du catalogue
# des configurations de garanties (inst/extdata/garanties/). Une configuration est une
# donnée, jamais une fonction : aucun nom de fonction n'est lu dans un CSV.
# N'appelle que les modules `dictionnaire` et `outils` (graphe du point 1). Ne parle pas
# (point 12). Code ASCII hors commentaires (M112).
# Convention de ce fichier : une fonction dont le nom commence par un point est un
# auxiliaire du module ; la concordance documentation <-> code ne recense que les autres.

# --- Constantes ------------------------------------------------------------------

# Fichiers du catalogue et leurs colonnes, dans cet ordre (ADR 0010, point 16 ;
# lectures.csv : spécification de B2, § 4.1, annotation du point 16).
COLONNES_CATALOGUE <- list(
  garanties.csv = c("code_garantie", "famille_garanties", "jalon"),
  etats.csv = c("etat", "individu", "absorbant", "description"),
  transitions.csv = c("depuis", "vers", "usage", "pas", "axes", "decomposition"),
  flux.csv = c("code_garantie", "flux", "type_flux", "etat_payeur", "parametres"),
  usages_tables.csv = c("code_garantie", "usage", "nature", "axes"),
  postes.csv = c("code_garantie", "poste", "famille", "composantes", "regle_combinaison",
                 "provision_comptes_sociaux", "meilleure_estimation", "methodes", "temoins"),
  liens.csv = c("garantie", "garantie_liee", "lien"),
  lectures.csv = c("code_garantie", "poste", "table", "colonne")
)

# Listes fermées du catalogue. Types de flux de B2 (A2 du recensement ; spécification de B2,
# § 4.1) : la liste s'étend avec la branche qui implémente un nouveau type.
TYPES_FLUX <- c("capital_unique", "prime_periodique", "frais")
# Méthodes et témoins implémentés ou implémentés dans la branche (une ligne de méthode non
# implémentée n'est jamais au catalogue, spécification de B2, § 4.1) ; champs d'un poste à
# champs (préfixe `champ:` de `methodes` et `temoins`, A1 du recensement).
METHODES_CATALOGUE <- c("capital_dossier", "capital_dossier_reglement", "capital_revalorise",
                        "capital_revalorise_reglement", "prospective_prime_pure",
                        "prospective_prime_declaree", "prorata_cotisation", "retrospective")
CHAMPS_POSTE <- c("individuel", "collectif")
# Usage commun du plan, connu de `plan` et de `tables` sans ligne de catalogue (recensement,
# § 8.4) : réservé, il ne peut pas être un usage du catalogue.
USAGE_SERIE_TME <- "serie_tme"
.JALONS <- c("v1", "v2", "v3")
.INDIVIDUS <- c("assure", "beneficiaire")
.PAS <- c("an", "mois")
.AXES_TRANSITION <- c("age", "age_anciennete", "generation")
.NATURES_TABLE <- c("mortalite", "maintien", "passage", "incidence", "taux")
.AXES_TABLE <- c("age", "anciennete", "generation", "date", "maturite")
.FAMILLES_POSTE <- c("engagement", "triangle", "risque_en_cours", "projection", "regle_comptable",
                     "combinaison")
.LIENS <- c("maintien_garantie_deces", "passage", "double_effet")

# --- Lecture du catalogue ----------------------------------------------------------

# Rend le catalogue des garanties, lu et validé à chaque appel depuis
# inst/extdata/garanties/ du package installé : liste nommée `garanties`, `etats`,
# `transitions`, `flux`, `usages_tables`, `postes`, `liens`, `lectures` (un data.frame par
# CSV, colonnes de texte, sauf `etats$absorbant` et `postes$meilleure_estimation`, logiques).
# Refus `catalogue_invalide` si la forme lue n'est pas celle attendue (colonnes, listes
# fermées, codes et colonnes du dictionnaire, références internes).
catalogue_garanties <- function() {
  .lire_catalogue(system.file("extdata", "garanties", package = "provie"), dictionnaire())
}

.refus_catalogue <- function(message, ...) {
  refuser(paste0("catalogue des garanties : ", message), "catalogue_invalide", module = "garanties", ...)
}

.eclater_catalogue <- function(x) if (identical(x, "")) character(0) else strsplit(x, ";", fixed = TRUE)[[1L]]

# Lit et valide le catalogue du dossier donné (catalogue_garanties() lui passe celui du
# package ; les tests lui passent une copie altérée).
.lire_catalogue <- function(dossier, dico) {
  if (!is.character(dossier) || length(dossier) != 1L || is.na(dossier) || !nzchar(dossier) ||
      !dir.exists(dossier)) {
    .refus_catalogue("dossier inst/extdata/garanties introuvable")
  }
  lus <- lapply(names(COLONNES_CATALOGUE), function(f) .lire_csv_catalogue(file.path(dossier, f), f))
  names(lus) <- sub("\\.csv$", "", names(COLONNES_CATALOGUE))
  lus$etats$absorbant <- .logique_catalogue(lus$etats$absorbant, "etats.csv", "absorbant")
  lus$postes$meilleure_estimation <- .logique_catalogue(lus$postes$meilleure_estimation, "postes.csv",
                                                        "meilleure_estimation")
  .valider_catalogue(lus, dico)
  lus
}

.lire_csv_catalogue <- function(chemin, fichier) {
  if (!file.exists(chemin)) .refus_catalogue(paste0(fichier, " absent"))
  octets <- readBin(chemin, "raw", n = file.info(chemin)$size)
  texte <- rawToChar(octets)
  Encoding(texte) <- "UTF-8"
  if (!validUTF8(texte)) .refus_catalogue(paste0(fichier, " n'est pas en UTF-8"))
  df <- tryCatch(
    utils::read.csv(text = texte, colClasses = "character", na.strings = character(0),
                    encoding = "UTF-8", check.names = FALSE, stringsAsFactors = FALSE),
    error = function(e) .refus_catalogue(paste0(fichier, " illisible (", conditionMessage(e), ")")))
  if (!identical(names(df), COLONNES_CATALOGUE[[fichier]])) {
    .refus_catalogue(paste0("colonnes de ", fichier, " diff\u00e9rentes de celles attendues (",
                            paste(COLONNES_CATALOGUE[[fichier]], collapse = ", "), ")"))
  }
  df
}

.logique_catalogue <- function(x, fichier, colonne) {
  if (!all(x %in% c("TRUE", "FALSE"))) {
    .refus_catalogue(paste0(fichier, ", ", colonne, " : TRUE ou FALSE attendu"), colonne = colonne)
  }
  x == "TRUE"
}

# Validation du catalogue lu : listes fermées, codes du dictionnaire, références internes.
.valider_catalogue <- function(catalogue, dico) {
  jeton <- function(x) grepl("^[a-z][a-z0-9_]*$", x)
  exiger <- function(condition, message, ...) if (!all(condition)) .refus_catalogue(message, ...)
  codes_dico <- .eclater_catalogue(dico$colonnes$modalites[dico$colonnes$table == "garanties_souscrites" &
                                                             dico$colonnes$colonne == "code_garantie"])

  g <- catalogue$garanties
  exiger(g$code_garantie %in% codes_dico,
         paste0("garanties.csv : code de garantie inconnu du dictionnaire (",
                paste(setdiff(g$code_garantie, codes_dico), collapse = ", "), ")"), colonne = "code_garantie")
  exiger(!anyDuplicated(g$code_garantie), "garanties.csv : code de garantie en double")
  exiger(jeton(g$famille_garanties), "garanties.csv : famille_garanties mal form\u00e9e")
  exiger(g$jalon %in% .JALONS, "garanties.csv : jalon hors liste (v1, v2, v3)")
  garanties <- g$code_garantie

  e <- catalogue$etats
  exiger(jeton(e$etat) & !duplicated(e$etat), "etats.csv : \u00e9tat mal form\u00e9 ou en double")
  exiger(e$individu %in% .INDIVIDUS, "etats.csv : individu hors liste (assure, beneficiaire)")
  exiger(nzchar(e$description), "etats.csv : description vide")

  u <- catalogue$usages_tables
  exiger(u$code_garantie %in% garanties, "usages_tables.csv : garantie absente de garanties.csv")
  exiger(jeton(u$usage) & u$usage != USAGE_SERIE_TME,
         paste0("usages_tables.csv : usage mal form\u00e9 ou r\u00e9serv\u00e9 (", USAGE_SERIE_TME, ")"))
  exiger(!anyDuplicated(u[, c("code_garantie", "usage")]), "usages_tables.csv : usage en double")
  exiger(u$nature %in% .NATURES_TABLE,
         paste0("usages_tables.csv : nature hors liste (", paste(.NATURES_TABLE, collapse = ", "), ")"))
  exiger(vapply(u$axes, function(a) length(.eclater_catalogue(a)) > 0L && all(.eclater_catalogue(a) %in% .AXES_TABLE),
                NA, USE.NAMES = FALSE),
         paste0("usages_tables.csv : axes hors liste (", paste(.AXES_TABLE, collapse = ", "), ")"))

  tr <- catalogue$transitions
  exiger(tr$depuis %in% e$etat & tr$vers %in% e$etat, "transitions.csv : \u00e9tat absent de etats.csv")
  exiger(tr$usage %in% u$usage, "transitions.csv : usage absent de usages_tables.csv")
  exiger(tr$pas %in% .PAS, "transitions.csv : pas hors liste (an, mois)")
  exiger(tr$axes %in% .AXES_TRANSITION,
         paste0("transitions.csv : axes hors liste (", paste(.AXES_TRANSITION, collapse = ", "), ")"))
  exiger(!anyDuplicated(tr[, c("depuis", "vers")]), "transitions.csv : transition en double")

  f <- catalogue$flux
  exiger(f$code_garantie %in% garanties, "flux.csv : garantie absente de garanties.csv")
  exiger(jeton(f$flux) & !duplicated(f[, c("code_garantie", "flux")]), "flux.csv : flux mal form\u00e9 ou en double")
  exiger(f$type_flux %in% TYPES_FLUX,
         paste0("flux.csv : type de flux hors liste (", paste(TYPES_FLUX, collapse = ", "), ")"),
         colonne = "type_flux")
  exiger(f$etat_payeur %in% e$etat, "flux.csv : \u00e9tat payeur absent de etats.csv")
  for (i in seq_len(nrow(f))) {
    admis <- dico$parametres$parametre[dico$parametres$code_garantie %in% c(f$code_garantie[i], "toutes")]
    inconnus <- setdiff(.eclater_catalogue(f$parametres[i]), admis)
    exiger(length(inconnus) == 0L,
           paste0("flux.csv : param\u00e8tre(s) inconnu(s) du dictionnaire pour ", f$code_garantie[i], " (",
                  paste(inconnus, collapse = ", "), ")"), colonne = "parametres")
  }

  p <- catalogue$postes
  exiger(p$code_garantie %in% garanties, "postes.csv : garantie absente de garanties.csv")
  exiger(jeton(p$poste) & !duplicated(p[, c("code_garantie", "poste")]), "postes.csv : poste mal form\u00e9 ou en double")
  exiger(p$famille %in% .FAMILLES_POSTE,
         paste0("postes.csv : famille hors liste (", paste(.FAMILLES_POSTE, collapse = ", "), ")"))
  exiger(jeton(p$provision_comptes_sociaux), "postes.csv : provision_comptes_sociaux mal form\u00e9e")
  exiger(p$famille != "combinaison" | (nzchar(p$composantes) & nzchar(p$regle_combinaison)),
         "postes.csv : un poste de la famille combinaison porte composantes et regle_combinaison")
  for (i in seq_len(nrow(p))) {
    methodes <- methodes_poste(p$methodes[i], p$poste[i], "methodes")
    temoins <- methodes_poste(p$temoins[i], p$poste[i], "temoins")
    exiger(nrow(methodes) > 0L, paste0("postes.csv : poste ", p$poste[i], " sans m\u00e9thode"))
    exiger(!any(paste(temoins$champ, temoins$methode) %in% paste(methodes$champ, methodes$methode)),
           paste0("postes.csv : poste ", p$poste[i], " : une m\u00e9thode est \u00e0 la fois option et t\u00e9moin"))
    champs <- unique(c(methodes$champ, temoins$champ))
    exiger(all(champs == "") || all(champs != ""),
           paste0("postes.csv : poste ", p$poste[i], " : m\u00e9thodes avec et sans champ m\u00eal\u00e9es"))
  }

  l <- catalogue$liens
  exiger(l$garantie %in% garanties & l$garantie_liee %in% garanties, "liens.csv : garantie absente de garanties.csv")
  exiger(l$lien %in% .LIENS, paste0("liens.csv : lien hors liste (", paste(.LIENS, collapse = ", "), ")"))

  r <- catalogue$lectures
  exiger(paste(r$code_garantie, r$poste) %in% paste(p$code_garantie, p$poste),
         "lectures.csv : poste absent de postes.csv")
  cles <- paste(dico$colonnes$table, dico$colonnes$colonne, sep = ".")
  inconnues <- setdiff(paste(r$table, r$colonne, sep = "."), cles)
  exiger(length(inconnues) == 0L,
         paste0("lectures.csv : colonne(s) absente(s) du dictionnaire (", paste(inconnues, collapse = ", "), ")"),
         colonne = "colonne", identifiants = inconnues)
  exiger(!anyDuplicated(r), "lectures.csv : ligne en double")
  exiger(paste(p$code_garantie, p$poste) %in% paste(r$code_garantie, r$poste),
         "lectures.csv : un poste de postes.csv n'a aucune colonne lue")
  invisible(NULL)
}

# Méthodes ou témoins d'un poste (`methodes` ou `temoins` de postes.csv) : data.frame
# (champ, methode), champ "" sans préfixe ; refus si un champ ou une méthode est inconnu.
# Sans point : appelée aussi par `plan` (ADR 0010, quatrième série, (c)), non exportée.
methodes_poste <- function(x, poste, colonne) {
  entrees <- .eclater_catalogue(x)
  champ <- sub(":.*$", "", entrees)
  champ[!grepl(":", entrees, fixed = TRUE)] <- ""
  methode <- sub("^[^:]*:", "", entrees)
  if (!all(champ %in% c("", CHAMPS_POSTE))) {
    .refus_catalogue(paste0("postes.csv, ", colonne, " du poste ", poste, " : champ inconnu (",
                            paste(setdiff(champ, c("", CHAMPS_POSTE)), collapse = ", "), ")"), colonne = colonne)
  }
  if (!all(methode %in% METHODES_CATALOGUE)) {
    .refus_catalogue(paste0("postes.csv, ", colonne, " du poste ", poste, " : m\u00e9thode inconnue (",
                            paste(setdiff(methode, METHODES_CATALOGUE), collapse = ", "), ")"), colonne = colonne)
  }
  if (anyDuplicated(entrees)) {
    .refus_catalogue(paste0("postes.csv, ", colonne, " du poste ", poste, " : m\u00e9thode en double"), colonne = colonne)
  }
  data.frame(champ = champ, methode = methode, stringsAsFactors = FALSE)
}

# --- Arrêt de poste -------------------------------------------------------------------

# Motifs de vue$visibilite_non_determinee qui ne sont pas des motifs de refus (spécification de
# B2, § 6.2 : ils n'arrêtent rien) ; sous-cas de D10 traités R (dictionnaire, § 9).
.MOTIFS_ND_SANS_ARRET <- c("D02b", "D03g", "parente_non_determinee")
.SOUS_CAS_D10_R <- c("D10a", "D10h")

# Postes arrêtés par le bilan (M239 ; ADR 0010, point 11 (b), annoté ; spécification de B2,
# § 6.2). `catalogue` : catalogue_garanties() (lectures.csv : colonnes lues par poste) ;
# `bilan` : bilan de controler_base() (refus_tables, vue$visibilite_non_determinee), passé en
# argument (aucune arête garanties -> donnees) ; `postes` : section `postes` du plan (garantie
# -> poste -> ...) ; `parties` : parties de ligne, liste de list(table, colonnes)
# (donnees::parties_ligne(), passée en argument pour la même raison). Une colonne d'une partie
# de ligne vaut pour toute la partie (erratum v1.0.5). Règles, dans cet ordre :
#   (i) ligne de refus_tables de portée table (refus induit compris) sur T : postes qui lisent
#       une colonne de T ;
#   (ii) ligne de refus_tables de portée colonne sur (T, c) : postes qui lisent (T, c) ; si c
#       est une colonne d'une partie de ligne de T, postes qui lisent une colonne de la partie ;
#   (iii) ligne de vue$visibilite_non_determinee de motif de refus (motif R : code de
#       controles.csv de portée autre que ligne, défaut traité R, sous-cas D10a ou D10h ; ni
#       D02b, ni D03g, ni parente_non_determinee) sur T : ligne entière (colonne NA), postes
#       qui lisent T ou une table descendante de T (clés étrangères simples de colonnes.csv) ;
#       partie de ligne (colonne renseignée), postes qui lisent une colonne de la partie de T
#       qui contient `colonne` (§ 4.3 : une partie inconnue n'arrête que ses lecteurs ; la
#       ligne et ses descendantes restent visibles). La ligne de refus_tables qui porte
#       postes_arretes est celle de même table, de colonne celle de l'origine et de même motif.
# Rend list(postes : data.frame (garantie, poste, motif_arret), une ligne par poste du plan,
# motif_arret = motif de la première ligne qui l'arrête dans l'ordre du bilan (refus_tables,
# puis visibilite_non_determinee), NA si le poste n'est pas arrêté ; refus_tables :
# refus_tables du bilan, `postes_arretes` rempli : « garantie/poste » joints par « ; », triés,
# NA si la ligne n'arrête aucun poste du plan).
postes_a_arreter <- function(catalogue, bilan, postes, parties) {
  dico <- dictionnaire()
  g <- rep(names(postes), lengths(postes))
  p <- unlist(lapply(postes, names), use.names = FALSE)
  if (is.null(p)) p <- character(0)
  cles <- paste(g, p, sep = "/")
  lec <- catalogue$lectures
  lec_cle <- paste(lec$code_garantie, lec$poste, sep = "/")
  lit_table <- function(tables) unique(lec_cle[lec$table %in% tables])
  # colonnes de la partie de ligne de `t` qui contient `c1` ; c1 seule hors de toute partie
  colonnes_partie <- function(t, c1) {
    for (q in parties) if (identical(q$table, t) && c1 %in% q$colonnes) return(q$colonnes)
    c1
  }
  lit_colonne <- function(t, c1) unique(lec_cle[lec$table == t & lec$colonne %in% colonnes_partie(t, c1)])
  # tables descendantes : clés étrangères simples (fille -> parente), jusqu'au point fixe
  col <- dico$colonnes
  ref <- col[nzchar(col$reference) & !grepl(";", col$reference, fixed = TRUE), , drop = FALSE]
  ref_parente <- sub("\\..*$", "", ref$reference)
  descendance <- function(t) {
    res <- t
    repeat {
      nouvelles <- setdiff(unique(ref$table[ref_parente %in% res]), res)
      if (length(nouvelles) == 0L) return(res)
      res <- c(res, nouvelles)
    }
  }
  motif_r <- function(m) {
    !(m %in% .MOTIFS_ND_SANS_ARRET) &&
      (m %in% dico$controles$code[dico$controles$portee != "ligne"] || m %in% .SOUS_CAS_D10_R ||
         (m %in% dico$defauts$code && "R" %in% .eclater_catalogue(dico$defauts$traitements[dico$defauts$code == m])))
  }
  rt <- bilan$refus_tables
  nd <- bilan$vue$visibilite_non_determinee
  motif <- stats::setNames(rep(NA_character_, length(cles)), cles)
  porte <- vector("list", nrow(rt))
  arreter <- function(touches, m, ligne_rt) {
    touches <- intersect(touches, cles)
    nouveaux <- touches[is.na(motif[touches])]
    motif[nouveaux] <<- m
    if (!is.na(ligne_rt)) porte[[ligne_rt]] <<- c(porte[[ligne_rt]], touches)
  }
  for (i in seq_len(nrow(rt))) {
    touches <- if (rt$portee[i] == "table" || is.na(rt$colonne[i])) lit_table(rt$table[i]) else
      lit_colonne(rt$table[i], rt$colonne[i])
    arreter(touches, rt$motif[i], i)
  }
  for (i in seq_len(nrow(nd))) {
    if (!motif_r(nd$motif[i])) next
    t <- nd$table[i]
    touches <- if (is.na(nd$colonne[i])) lit_table(descendance(t)) else lit_colonne(t, nd$colonne[i])
    colonne_origine <- if (is.na(nd$origine[i])) NA_character_ else sub("^[^.]*\\.", "", nd$origine[i])
    j <- which(rt$table == t & rt$colonne %in% colonne_origine & rt$motif == nd$motif[i])[1L]
    arreter(touches, nd$motif[i], j)
  }
  rt$postes_arretes <- vapply(porte, function(x) {
    if (length(x) == 0L) NA_character_ else paste(sort(unique(x), method = "radix"), collapse = ";")
  }, "")
  list(postes = data.frame(garantie = g, poste = p, motif_arret = unname(motif), stringsAsFactors = FALSE),
       refus_tables = rt)
}
