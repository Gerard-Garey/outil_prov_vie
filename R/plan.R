# Module `plan` (ADR 0007 ; ADR 0010, points 1, 6, 10, 13, 17 et 18 ; spécification de B2,
# docs/specifications/b2-capital-deces-v1.md, § 2) : validation du plan de calcul sans
# valeur par défaut, canonisation, sérialisation du plan et de la fiche de calcul en texte
# aplati (outils::ecrire_liste()), construction de la fiche et contrôles d'entrée du rejeu.
# Appelle `garanties` (catalogue), `donnees` (sous-schéma `donnees` du plan, listes fermées
# des référentiels et des conventions de limite d'âge), `tables` (listes fermées des
# statuts de table et du comportement hors des axes), `dictionnaire` et `outils` (graphe
# du point 1). Ne parle pas (point 12), hors des méthodes print.* et format.*. Code ASCII
# hors commentaires (M112).
# Convention de ce fichier : une fonction dont le nom commence par un point est un
# auxiliaire du module ; la concordance documentation <-> code ne recense que les autres.
#
# Un seul schéma sert à la validation et à la canonisation : chaque élément du schéma est
# un validateur function(x, chemin) qui refuse (plan_incomplet, plan_invalide) ou rend la
# valeur canonique. Règle d'exigence (spécification de B2, § 2.3) : une entrée est exigée si
# un lecteur du périmètre la lit ; exigée et absente : plan_incomplet, le message nomme le
# chemin ; présente et mal formée, ou inconnue du schéma : plan_invalide ; connue du schéma
# mais non lue par le périmètre : admise et canonisée.

# --- Constantes ------------------------------------------------------------------

VERSION_PLAN <- 1L
# Sections du plan, dans l'ordre canonique (ADR 0010, point 17).
SECTIONS_PLAN <- c("version_plan", "arrete", "perimetre", "tables", "taux", "frais", "revalorisation",
                   "conventions", "postes", "donnees", "restitution", "liens", "graine")
# Listes fermées du plan de B2 (spécification de B2, § 2.2 à § 2.7) ; celles des entrées de
# `tables` (STATUTS_TABLE, HORS_AXES) sont tenues par le module `tables`, qui les lit aussi.
REGLES_SEGMENTATION <- c("contrat", "adherent", "college", "gestionnaire", "nature_contrat",
                         "secteur_activite", "annee_survenance", "ligne_activite")
INSTANTS_DATE <- "fin_journee"
REPARTITIONS_ANNEE <- c("uniforme", "force_constante")
FRACTIONNEMENTS <- "echeances_exactes"
DECOMPTES_JOURS <- c("exact_exact", "exact_365")
PRORATAS_REVALORISATION <- c("simple", "compose")
# Champs de la fiche de calcul (ADR 0007, point 3 ; ADR 0010, point 6) et data.frame de ses
# paramètres retenus (ADR 0010, point 10), dans cet ordre.
CHAMPS_FICHE <- c("plan", "parametres_retenus", "empreintes", "versions", "plateforme", "graine")
PARAMETRES_RETENUS <- c("postes", "tables", "hypotheses_defaut", "exclusions", "plafonds",
                        "colonnes_ecrasees", "tables_absentes")
# Colonnes fixées des paramètres retenus `postes` (ADR 0010, point 10) et `tables`
# (spécification de B2, § 3.4) ; celles des cinq autres sont fixées en (4).
COLONNES_POSTES_RETENUS <- c("garantie", "referentiel", "poste", "famille", "methode", "statut_methode",
                             "parametres", "usages_tables")
COLONNES_TABLES_RETENUES <- c("usage", "garantie", "identifiant", "statut", "format_natif", "provenance",
                              "conversion", "empreinte")
# Générateur pseudo-aléatoire fixé par outils::avec_graine() (ADR 0010, point 21), consigné
# dans la fiche ; RNGkind() ne s'appelle pas hors d'`outils` (contrôle de frontière) : la
# concordance avec avec_graine() est vérifiée par le test du module.
.GENERATEUR_GRAINE <- c("Mersenne-Twister", "Inversion", "Rejection")
# Bornes du domaine des taux (taux technique retenu, revalorisation) ; valeur réservée du
# taux technique : taux du tarif de chaque contrat (spécification de B2, § 2.2).
.BORNES_TAUX <- c(-0.05, 0.20)
.TAUX_TARIF <- "taux_tarif"
# Garanties dont la présence au périmètre en comptes sociaux exige tables$serie_tme
# (indicateurs R132_3_1 et A132_1, M124, M128 ; spécification de B2, § 2.3).
.GARANTIES_SERIE_TME <- "deces"
.METHODES_PROSPECTIVES <- c("prospective_prime_pure", "prospective_prime_declaree")
.METHODES_REGLEMENT <- c("capital_dossier_reglement", "capital_revalorise_reglement")
.LIENS_CONJOINT <- c("conjoint", "partenaire_pacs", "concubin")
.CRITERES_NON_RECLAMES <- c("beneficiaire_non_identifie", "sans_evenement")

# --- Refus ---------------------------------------------------------------------------

.refus_incomplet <- function(chemin) {
  refuser(paste0("plan : entr\u00e9e exig\u00e9e absente : ", chemin, " (aucune valeur par d\u00e9faut)"),
          "plan_incomplet", module = "plan", attendu = chemin)
}

.refus_invalide <- function(chemin, raison) {
  refuser(paste0("plan : ", chemin, " : ", raison), "plan_invalide", module = "plan", attendu = chemin)
}

.sous_chemin <- function(chemin, nom) paste0(chemin, "$", nom)

# --- Validateurs (feuilles) ------------------------------------------------------------

# Valeur atomique sans attribut, de longueur 1 et renseignée.
.scalaire <- function(x) is.atomic(x) && is.null(attributes(x)) && length(x) == 1L && !is.na(x)

.v_chaine <- function(liste = NULL, raison = NULL) {
  function(x, chemin) {
    if (!(is.character(x) && .scalaire(x) && nzchar(x))) .refus_invalide(chemin, "cha\u00eene unique renseign\u00e9e attendue")
    if (!is.null(liste) && !(x %in% liste)) {
      .refus_invalide(chemin, if (!is.null(raison)) raison else
        paste0("valeur \u00ab ", x, " \u00bb hors de la liste ferm\u00e9e (", paste(liste, collapse = ", "), ")"))
    }
    x
  }
}

# Entier : un integer, ou un double entier (canonisé en integer) ; toute autre conversion
# est refusée.
.v_entier <- function(min = -.Machine$integer.max, max = .Machine$integer.max) {
  function(x, chemin) {
    if (!((is.integer(x) || is.double(x)) && .scalaire(x) && is.finite(x) && x == trunc(x) &&
          abs(x) <= .Machine$integer.max)) {
      .refus_invalide(chemin, "entier unique renseign\u00e9 attendu")
    }
    if (x < min || x > max) .refus_invalide(chemin, paste0("entier hors du domaine [", min, " ; ", max, "]"))
    as.integer(x)
  }
}

# Réel : un double fini (un integer n'est pas converti : refus).
.v_reel <- function(min = -Inf, max = Inf, max_exclu = FALSE) {
  function(x, chemin) {
    if (!(is.double(x) && .scalaire(x) && is.finite(x))) .refus_invalide(chemin, "r\u00e9el (double) unique et fini attendu")
    if (x < min || x > max || (max_exclu && x >= max)) {
      .refus_invalide(chemin, paste0("r\u00e9el hors du domaine [", min, " ; ", max, if (max_exclu) "[" else "]"))
    }
    x
  }
}

# Vecteur-ensemble : sous-ensemble non vide de `liste`, sans doublon (un doublon est
# refusé, jamais retiré) ; canonisé trié (sort radix).
.v_ensemble <- function(liste) {
  function(x, chemin) {
    if (!(is.character(x) && is.null(attributes(x)) && length(x) >= 1L && !anyNA(x))) {
      .refus_invalide(chemin, "vecteur de cha\u00eenes non vide attendu")
    }
    if (anyDuplicated(x)) .refus_invalide(chemin, paste0("doublon (", x[duplicated(x)][1L], ")"))
    if (!all(x %in% liste)) {
      .refus_invalide(chemin, paste0("valeur(s) hors de la liste ferm\u00e9e (", paste(liste, collapse = ", "), ") : ",
                                     paste(setdiff(x, liste), collapse = ", ")))
    }
    sort(x, method = "radix")
  }
}

.v_date <- function() {
  function(x, chemin) {
    if (!(identical(class(x), "Date") && identical(names(attributes(x)), "class") && is.double(x) &&
          length(x) == 1L && is.finite(unclass(x)) && unclass(x) == trunc(unclass(x)))) {
      .refus_invalide(chemin, "Date unique, finie, stock\u00e9e en double, attendue")
    }
    x
  }
}

.v_empreinte <- function() {
  function(x, chemin) {
    if (!(is.character(x) && .scalaire(x) && grepl("^[0-9a-f]{32}$", x))) {
      .refus_invalide(chemin, "empreinte MD5 attendue (32 caract\u00e8res hexad\u00e9cimaux minuscules)")
    }
    x
  }
}

# Taux technique retenu : double dans les bornes, ou la chaîne `taux_tarif`.
.v_taux_technique <- function() {
  reel <- .v_reel(.BORNES_TAUX[1L], .BORNES_TAUX[2L])
  function(x, chemin) {
    if (is.character(x) && .scalaire(x) && identical(x, .TAUX_TARIF)) return(x)
    if (is.character(x)) .refus_invalide(chemin, paste0("seule cha\u00eene admise : ", .TAUX_TARIF))
    reel(x, chemin)
  }
}

# Taux de revalorisation par année civile : double nommé (noms : années sur quatre
# chiffres) ou liste nommée de doubles ; canonisé en liste nommée triée par année
# (ecrire_liste() n'écrit pas un vecteur portant des noms).
.v_taux_par_annee <- function() {
  reel <- .v_reel(.BORNES_TAUX[1L], .BORNES_TAUX[2L])
  function(x, chemin) {
    if (is.double(x) && identical(names(attributes(x)), "names")) {
      x <- as.list(x)
    } else if (!(is.list(x) && !is.data.frame(x) && identical(names(attributes(x)), "names"))) {
      .refus_invalide(chemin, "double nomm\u00e9 (ou liste nomm\u00e9e de doubles), noms = ann\u00e9es civiles, attendu")
    }
    noms <- names(x)
    if (length(x) == 0L || anyNA(noms) || !all(grepl("^[0-9]{4}$", noms)) || anyDuplicated(noms)) {
      .refus_invalide(chemin, "au moins une ann\u00e9e ; noms = ann\u00e9es civiles distinctes sur quatre chiffres")
    }
    for (n in noms) reel(x[[n]], .sous_chemin(chemin, n))
    x[sort(noms, method = "radix")]
  }
}

# --- Validateurs (noeuds) --------------------------------------------------------------

.liste_nommee <- function(x) {
  is.list(x) && !is.data.frame(x) &&
    (is.null(attributes(x)) || identical(names(attributes(x)), "names")) &&
    (length(x) == 0L || (!is.null(names(x)) && !anyNA(names(x)) && all(nzchar(names(x))) && !anyDuplicated(names(x))))
}

# Noeud à clés fixes : `enfants` = liste nommée de validateurs, dans l'ordre canonique ;
# `exigees` = noms exigés. Rend la liste canonique (clés présentes, dans l'ordre du schéma ;
# list() si vide).
.v_noeud <- function(enfants, exigees = names(enfants)) {
  function(x, chemin) {
    if (!.liste_nommee(x)) .refus_invalide(chemin, "liste nomm\u00e9e attendue (noms renseign\u00e9s et distincts)")
    .parcourir(x, chemin, enfants, exigees, ordre = names(enfants))
  }
}

# Noeud à clés libres : `connues` (NULL : toute clé que `cle_valide` admet), `exigees`,
# `enfant(cle)` rend le validateur de la clé. Clés canonisées triées (sort radix).
.v_libre <- function(connues, exigees, enfant, cle_valide = NULL, raison_cle = NULL) {
  function(x, chemin) {
    if (!.liste_nommee(x)) .refus_invalide(chemin, "liste nomm\u00e9e attendue (noms renseign\u00e9s et distincts)")
    noms <- names(x)
    if (!is.null(cle_valide)) {
      mauvaises <- noms[!cle_valide(noms)]
      if (length(mauvaises) > 0L) .refus_invalide(.sous_chemin(chemin, mauvaises[1L]), raison_cle)
    }
    cles <- if (is.null(connues)) noms else connues
    enfants <- stats::setNames(lapply(cles, enfant), cles)
    .parcourir(x, chemin, enfants, exigees, ordre = sort(as.character(union(cles, exigees)), method = "radix"))
  }
}

.parcourir <- function(x, chemin, enfants, exigees, ordre) {
  noms <- if (length(x) == 0L) character(0) else names(x)
  inconnues <- setdiff(noms, names(enfants))
  if (length(inconnues) > 0L) .refus_invalide(.sous_chemin(chemin, inconnues[1L]), "entr\u00e9e inconnue du sch\u00e9ma")
  manquantes <- setdiff(intersect(ordre, exigees), noms)
  if (length(manquantes) > 0L) .refus_incomplet(.sous_chemin(chemin, manquantes[1L]))
  presents <- ordre[ordre %in% noms]
  res <- lapply(presents, function(n) {
    if (is.null(x[[n]])) .refus_invalide(.sous_chemin(chemin, n), "valeur NULL")
    enfants[[n]](x[[n]], .sous_chemin(chemin, n))
  })
  if (length(res) == 0L) return(list())
  names(res) <- presents
  res
}

# Noeud qui doit être vide (list()).
.v_vide <- function(raison) {
  function(x, chemin) {
    if (!.liste_nommee(x)) .refus_invalide(chemin, "liste attendue")
    if (length(x) > 0L) .refus_invalide(.sous_chemin(chemin, names(x)[1L]), raison)
    list()
  }
}

# --- Validation et canonisation du plan --------------------------------------------------

# Rend le plan sous forme canonique (liste nommée, sans classe) après validation, ou
# refuse. `catalogue` : catalogue_garanties() ; `dico` : dictionnaire().
.canoniser <- function(plan, catalogue, dico) {
  attributs <- names(attributes(plan))
  if (!(is.list(plan) && !is.data.frame(plan) && all(attributs %in% c("names", "class")) &&
        (is.null(attr(plan, "class")) || identical(attr(plan, "class"), "plan_calcul")))) {
    .refus_invalide("plan", "liste nomm\u00e9e attendue (classe plan_calcul admise)")
  }
  x <- unclass(plan)
  if (!.liste_nommee(x)) .refus_invalide("plan", "liste nomm\u00e9e attendue (noms renseign\u00e9s et distincts)")
  inconnues <- setdiff(names(x), SECTIONS_PLAN)
  if (length(inconnues) > 0L) .refus_invalide(inconnues[1L], "section inconnue du plan (ADR 0010, point 17)")
  manquantes <- setdiff(SECTIONS_PLAN, names(x))
  if (length(manquantes) > 0L) .refus_incomplet(manquantes[1L])
  for (s in SECTIONS_PLAN) if (is.null(x[[s]])) .refus_invalide(s, "valeur NULL")

  res <- list()
  version <- .v_entier()(x[["version_plan"]], "version_plan")
  if (version != VERSION_PLAN) .refus_invalide("version_plan", paste0("version ", version, " ; version attendue : ", VERSION_PLAN))
  res$version_plan <- version
  res$arrete <- .v_date()(x[["arrete"]], "arrete")
  res$perimetre <- .v_perimetre(catalogue)(x[["perimetre"]], "perimetre")
  garanties <- res$perimetre$garanties
  referentiels <- res$perimetre$referentiels
  postes <- .v_postes(catalogue, garanties)(x[["postes"]], "postes")
  methodes <- .methodes_declarees(postes)
  res$tables <- .v_tables(catalogue, garanties, referentiels, methodes)(x[["tables"]], "tables")
  res$taux <- .v_taux(catalogue, garanties, methodes)(x[["taux"]], "taux")
  res$frais <- .v_frais(catalogue, garanties, methodes)(x[["frais"]], "frais")
  res$revalorisation <- .v_revalorisation(garanties, methodes)(x[["revalorisation"]], "revalorisation")
  res$conventions <- .v_conventions()(x[["conventions"]], "conventions")
  res$postes <- postes
  res$donnees <- .v_donnees(dico)(x[["donnees"]], "donnees")
  res$restitution <- .v_noeud(list(
    echeanciers = .v_echeanciers(),
    triangles = .v_chaine("aucun", "seule valeur admise avant B3 : aucun")))(x[["restitution"]], "restitution")
  res$liens <- .v_liens(catalogue, garanties)(x[["liens"]], "liens")
  res$graine <- .v_entier()(x[["graine"]], "graine")
  res
}

.v_perimetre <- function(catalogue) {
  function(x, chemin) {
    ref <- .v_ensemble(REFERENTIELS)
    noeud <- .v_noeud(list(
      garanties = .v_ensemble(catalogue$garanties$code_garantie),
      referentiels = function(v, ch) {
        v <- ref(v, ch)
        if ("solvabilite_2" %in% v) .refus_invalide(ch, "aucune m\u00e9thode de meilleure estimation avant B6")
        v
      },
      segmentations = function(v, ch) v))
    res <- noeud(x, chemin)
    res$segmentations <- .v_segmentations(res$garanties, catalogue)(x[["segmentations"]], .sous_chemin(chemin, "segmentations"))
    res
  }
}

.v_segmentations <- function(garanties, catalogue) {
  segmentation <- function(cle) {
    function(x, chemin) {
      if (!.liste_nommee(x)) .refus_invalide(chemin, "liste nomm\u00e9e attendue")
      if (is.null(x[["regle"]])) .refus_incomplet(.sous_chemin(chemin, "regle"))
      regle <- .v_chaine(REGLES_SEGMENTATION)(x[["regle"]], .sous_chemin(chemin, "regle"))
      enfants <- list(regle = .v_chaine(REGLES_SEGMENTATION))
      if (regle == "ligne_activite") {
        enfants$correspondance <- .v_libre(catalogue$garanties$code_garantie, garanties, function(g) .v_chaine())
      }
      .v_noeud(enfants)(x, chemin)
    }
  }
  .v_libre(NULL, character(0), segmentation,
           cle_valide = function(n) grepl("^[a-z0-9_]+$", n) & n != "ensemble",
           raison_cle = "nom de segmentation : [a-z0-9_]+, diff\u00e9rent de ensemble")
}

# Section `postes` : garantie -> poste -> list(methode, parametres) ; pour un poste à champs
# (préfixe `champ:` du catalogue), poste -> champ -> list(methode, parametres). Chaque poste
# du catalogue d'une garantie du périmètre est exigé (spécification de B2, § 2.3).
.v_postes <- function(catalogue, garanties) {
  .v_libre(catalogue$garanties$code_garantie, garanties, function(g) {
    lignes <- catalogue$postes[catalogue$postes$code_garantie == g, , drop = FALSE]
    exigees <- if (g %in% garanties) lignes$poste else character(0)
    .v_libre(lignes$poste, exigees, function(p) .v_poste(catalogue, lignes[lignes$poste == p, , drop = FALSE]))
  })
}

.v_poste <- function(catalogue, ligne) {
  methodes <- methodes_poste(ligne$methodes, ligne$poste, "methodes")
  temoins <- methodes_poste(ligne$temoins, ligne$poste, "temoins")
  tous_temoins <- unlist(lapply(catalogue$postes$temoins, function(t) methodes_poste(t, "", "temoins")$methode))
  champ <- function(nom_champ) {
    options <- methodes$methode[methodes$champ == nom_champ]
    function(x, chemin) {
      if (!.liste_nommee(x)) .refus_invalide(chemin, "liste nomm\u00e9e attendue (methode, parametres)")
      if (is.null(x[["methode"]])) .refus_incomplet(.sous_chemin(chemin, "methode"))
      m <- .v_chaine()(x[["methode"]], .sous_chemin(chemin, "methode"))
      if (m %in% c(temoins$methode, tous_temoins)) .refus_invalide(.sous_chemin(chemin, "methode"), "m\u00e9thode t\u00e9moin, non option")
      if (!(m %in% options)) {
        .refus_invalide(.sous_chemin(chemin, "methode"), paste0("m\u00e9thode hors des options du catalogue (",
                                                             paste(options, collapse = ", "), ")"))
      }
      .v_noeud(list(methode = .v_chaine(options),
                    parametres = .v_parametres(ligne$code_garantie, ligne$poste, nom_champ, m)))(x, chemin)
    }
  }
  champs <- unique(methodes$champ)
  if (identical(champs, "")) return(champ(""))
  .v_noeud(stats::setNames(lapply(champs, champ), champs))
}

# Paramètres d'un poste (spécification de B2, § 2.7) ; le schéma est celui de B2.
.v_parametres <- function(garantie, poste, champ, methode) {
  familiaux <- list(
    taux_sans_suite = .v_reel(0, 1),
    probabilite_reconnaissance_iad = .v_reel(0, 1),
    structure_familiale = .v_noeud(list(taux_conjoint = .v_reel(0, 1), nombre_enfants = .v_reel(0))),
    age_limite_enfant_majoration = .v_entier(0L, 30L),
    liens_conjoint_majoration = .v_ensemble(.LIENS_CONJOINT))
  cle <- paste(garantie, poste, champ, sep = "/")
  if (cle == "deces/sinistres_declares_non_regles/") {
    enfants <- c(familiaux, list(delai_reglement_jours = .v_entier(0L)))
    exigees <- c(names(familiaux), if (methode == "capital_dossier_reglement") "delai_reglement_jours")
    return(.v_noeud(enfants, exigees))
  }
  if (cle == "deces/capitaux_non_reclames/") {
    enfants <- c(list(critere = .v_ensemble(.CRITERES_NON_RECLAMES), mois_sans_evenement = .v_entier(1L)), familiaux)
    return(function(x, chemin) {
      critere <- if (.liste_nommee(x) && !is.null(x[["critere"]])) {
        .v_ensemble(.CRITERES_NON_RECLAMES)(x[["critere"]], .sous_chemin(chemin, "critere"))
      } else character(0)
      exigees <- c("critere", names(familiaux), if ("sans_evenement" %in% critere) "mois_sans_evenement")
      .v_noeud(enfants, exigees)(x, chemin)
    })
  }
  if (cle == "deces/provision_mathematique_temporaire_deces/individuel") {
    return(.v_noeud(list(pas = .v_chaine(c("an", "mois")), paiement_capital = .v_chaine(c("fin_pas", "milieu_pas")),
                         plancher = .v_chaine("par_contrat"))))
  }
  if (cle == "deces/provision_mathematique_temporaire_deces/collectif") {
    return(.v_vide("prorata_cotisation ne prend aucun param\u00e8tre"))
  }
  refuser(paste0("plan : poste ", cle, " sans sch\u00e9ma de param\u00e8tres dans le module plan"), "catalogue_invalide",
          module = "plan")
}

# Méthodes déclarées, par clé « garantie/poste » ou « garantie/poste/champ » (postes
# canoniques).
.methodes_declarees <- function(postes) {
  res <- character(0)
  for (g in names(postes)) for (p in names(postes[[g]])) {
    x <- postes[[g]][[p]]
    if (!is.null(x$methode)) {
      res[paste(g, p, sep = "/")] <- x$methode
    } else {
      for (ch in names(x)) res[paste(g, p, ch, sep = "/")] <- x[[ch]]$methode
    }
  }
  res
}

.methode <- function(methodes, cle) if (cle %in% names(methodes)) methodes[[cle]] else NA_character_

# Section `tables` : usage -> entrée (spécification de B2, § 2.2 et § 3.5).
.v_tables <- function(catalogue, garanties, referentiels, methodes) {
  exigees <- character(0)
  if ("comptes_sociaux" %in% referentiels && any(garanties %in% .GARANTIES_SERIE_TME)) exigees <- USAGE_SERIE_TME
  if (.methode(methodes, "deces/provision_mathematique_temporaire_deces/individuel") %in% .METHODES_PROSPECTIVES) {
    exigees <- c(exigees, "mortalite_tarif")
  }
  entree <- function(usage) {
    enfants <- list(identifiant = .v_chaine(), empreinte = .v_empreinte(), statut = .v_chaine(STATUTS_TABLE),
                    hors_axes = .v_chaine(HORS_AXES))
    if (usage == USAGE_SERIE_TME) enfants$decalage_publication_mois <- .v_entier(1L, 2L)
    .v_noeud(enfants)
  }
  .v_libre(sort(unique(c(catalogue$usages_tables$usage, USAGE_SERIE_TME)), method = "radix"), exigees, entree)
}

# Section `taux` (B2 : taux technique retenu de P3, comptes sociaux).
.v_taux <- function(catalogue, garanties, methodes) {
  exige <- "deces" %in% garanties &&
    .methode(methodes, "deces/provision_mathematique_temporaire_deces/individuel") %in% .METHODES_PROSPECTIVES
  .v_libre(intersect("deces", catalogue$garanties$code_garantie), if (exige) "deces" else character(0), function(g) {
    .v_noeud(list(provision_mathematique_temporaire_deces = .v_noeud(list(comptes_sociaux = .v_taux_technique()))),
             if (exige) "provision_mathematique_temporaire_deces" else character(0))
  })
}

# Section `frais` (spécification de B2, § 2.4) ; postes triés comme dans `postes` (§ 2.8).
.v_frais <- function(catalogue, garanties, methodes) {
  au_perimetre <- "deces" %in% garanties
  ind <- .methode(methodes, "deces/provision_mathematique_temporaire_deces/individuel")
  col <- .methode(methodes, "deces/provision_mathematique_temporaire_deces/collectif")
  psap <- function() .v_noeud(list(comptes_sociaux = .v_noeud(list(taux_chargement_psap = .v_reel(0)))))
  p3_exigees <- c(if (ind %in% .METHODES_PROSPECTIVES) "taux_chargement_gestion",
                  if (identical(ind, "prospective_prime_pure")) "taux_chargement_acquisition",
                  if (identical(ind, "prospective_prime_declaree") || identical(col, "prorata_cotisation")) "taux_chargement_cotisation")
  p3 <- .v_noeud(list(comptes_sociaux = .v_noeud(list(
    taux_chargement_gestion = .v_reel(0), taux_chargement_acquisition = .v_reel(0, 1),
    taux_chargement_cotisation = .v_reel(0, 1, max_exclu = TRUE)), p3_exigees)))
  enfants <- list(sinistres_declares_non_regles = psap(), capitaux_non_reclames = psap(),
                  provision_mathematique_temporaire_deces = p3)
  exigees <- if (au_perimetre) names(enfants) else character(0)
  .v_libre(intersect("deces", catalogue$garanties$code_garantie), if (au_perimetre) "deces" else character(0),
           function(g) .v_libre(names(enfants), exigees, function(poste) enfants[[poste]]))
}

# Section `revalorisation` (spécification de B2, § 2.5).
.v_revalorisation <- function(garanties, methodes) {
  p1 <- .methode(methodes, "deces/sinistres_declares_non_regles")
  p2 <- .methode(methodes, "deces/capitaux_non_reclames")
  exige <- "deces" %in% garanties
  exigees <- c("taux_par_annee", "prorata",
               if (any(c(p1, p2) %in% .METHODES_REGLEMENT)) "taux_futur",
               if (identical(p2, "capital_revalorise_reglement")) "duree_sans_depot_annees")
  capital <- .v_noeud(list(taux_par_annee = .v_taux_par_annee(), prorata = .v_chaine(PRORATAS_REVALORISATION),
                           taux_futur = .v_reel(.BORNES_TAUX[1L], .BORNES_TAUX[2L]),
                           duree_sans_depot_annees = .v_entier(1L)), exigees)
  .v_noeud(list(capital_deces = capital), if (exige) "capital_deces" else character(0))
}

# Section `conventions` (spécification de B2, § 2.6) : `limite_age` n'est exigée par aucune
# garantie de B2 (aucun lecteur au catalogue) ; elle est admise et canonisée.
.v_conventions <- function() {
  .v_noeud(list(
    age = .v_chaine(CONVENTIONS_AGE), instant_date = .v_chaine(INSTANTS_DATE),
    repartition_annee = .v_chaine(REPARTITIONS_ANNEE), fractionnement = .v_chaine(FRACTIONNEMENTS),
    decompte_jours = .v_chaine(DECOMPTES_JOURS),
    limite_age = .v_noeud(list(regle = .v_chaine(REGLES_LIMITE_AGE), age = .v_chaine(CONVENTIONS_LIMITE_AGE)))),
    c("age", "instant_date", "repartition_annee", "fractionnement", "decompte_jours"))
}

# Sous-schéma `donnees` (ADR 0010, point 17), validé par la fonction de `donnees` qui le lit
# (lire_declarations()), sans en changer la forme ; un seuil inconnu est une entrée inconnue
# du schéma (spécification de B2, § 2.3). Canonisation : rubriques dans l'ordre de
# RUBRIQUES_DECLARATIONS ; `exclusions` et `hypotheses` en liste de listes nommées (noms
# "1", "2"...), lignes triées par leurs colonnes ; seuils triés par nom, valeurs entières.
.v_donnees <- function(dico) {
  function(x, chemin) {
    if (!.liste_nommee(x)) .refus_invalide(chemin, "liste nomm\u00e9e attendue (sous-sch\u00e9ma donnees)")
    lu <- tryCatch(lire_declarations(x, dico), refus_provie = function(e) {
      refuser(paste0("plan : ", chemin, " : ", sub("^controler_base\\(\\) : ", "", conditionMessage(e))),
              e$motif, module = "plan", attendu = chemin)
    })
    seuils_connus <- c(SEUIL_DELAI_D03G, SEUILS_AGE_D02C)
    if (!is.null(x[["seuils"]])) {
      inconnus <- setdiff(names(x[["seuils"]]), seuils_connus)
      if (length(inconnus) > 0L) .refus_invalide(.sous_chemin(.sous_chemin(chemin, "seuils"), inconnus[1L]), "entr\u00e9e inconnue du sch\u00e9ma")
    }
    res <- list()
    for (r in RUBRIQUES_DECLARATIONS[RUBRIQUES_DECLARATIONS %in% names(x)]) {
      res[[r]] <- switch(r,
        exclusions = .lignes_canoniques(lu$exclusions),
        hypotheses = .lignes_canoniques(lu$hypotheses),
        seuils = .seuils_canoniques(x[["seuils"]], .sous_chemin(chemin, "seuils")),
        evaluations_gestion = list(diagnostics = x[["evaluations_gestion"]][["diagnostics"]]))
    }
    if (length(res) == 0L) list() else res
  }
}

.lignes_canoniques <- function(df) {
  if (nrow(df) == 0L) return(list())
  df <- df[do.call(order, c(unname(as.list(df)), list(method = "radix"))), , drop = FALSE]
  lignes <- lapply(seq_len(nrow(df)), function(i) {
    stats::setNames(lapply(names(df), function(n) df[[n]][i]), names(df))
  })
  names(lignes) <- as.character(seq_along(lignes))
  lignes
}

# Seuils canoniques : noms triés à deux niveaux, valeurs en integer ; un seuil au-delà des
# entiers de R (.Machine$integer.max) est refusé (as.integer() rendrait NA en silence).
.seuils_canoniques <- function(seuils, chemin) {
  if (length(seuils) == 0L) return(list())
  noms <- sort(names(seuils), method = "radix")
  stats::setNames(lapply(noms, function(n) {
    s <- seuils[[n]]
    if (length(s) == 0L) return(list())
    cles <- sort(names(s), method = "radix")
    stats::setNames(lapply(cles, function(k) {
      if (abs(s[[k]]) > .Machine$integer.max) {
        .refus_invalide(.sous_chemin(.sous_chemin(chemin, n), k), "seuil au-del\u00e0 des entiers de R (.Machine$integer.max)")
      }
      as.integer(s[[k]])
    }), cles)
  }), noms)
}

.v_echeanciers <- function() {
  function(x, chemin) {
    if (!(is.character(x) && is.null(attributes(x)) && length(x) >= 1L && !anyNA(x) && all(nzchar(x)))) {
      .refus_invalide(chemin, "tous, aucun, ou vecteur non vide d'identifiants attendu")
    }
    if (length(x) > 1L && any(x %in% c("tous", "aucun"))) {
      .refus_invalide(chemin, "tous et aucun ne se m\u00ealent pas \u00e0 des identifiants")
    }
    if (anyDuplicated(x)) .refus_invalide(chemin, paste0("identifiant en double (", x[duplicated(x)][1L], ")"))
    sort(x, method = "radix")
  }
}

# Section `liens` : vide en B2 ; un lien du catalogue entre deux garanties du périmètre
# devrait y figurer (refus lien_non_declare).
.v_liens <- function(catalogue, garanties) {
  vide <- .v_vide("aucun lien en B2 (forme d'un lien fix\u00e9e avec la premi\u00e8re garantie li\u00e9e)")
  function(x, chemin) {
    res <- vide(x, chemin)
    l <- catalogue$liens
    requis <- l[l$garantie %in% garanties & l$garantie_liee %in% garanties, , drop = FALSE]
    if (nrow(requis) > 0L) {
      refuser(paste0("plan : liens : lien du catalogue non d\u00e9clar\u00e9 (", requis$garantie[1L], " -> ",
                     requis$garantie_liee[1L], ", ", requis$lien[1L], ")"),
              "lien_non_declare", module = "plan", nombre = nrow(requis))
    }
    res
  }
}

# --- Fonctions du plan -------------------------------------------------------------------

# Valide le plan (règle d'exigence, sans valeur par défaut) et le rend, inchangé, avec la
# classe plan_calcul ; refus plan_incomplet (le message nomme le chemin manquant) ou
# plan_invalide.
valider_plan <- function(plan) {
  .canoniser(plan, catalogue_garanties(), dictionnaire())
  if (is.null(attr(plan, "class"))) class(plan) <- "plan_calcul"
  plan
}

# Rend le plan sous forme canonique (après validation) : sections dans l'ordre du point 17,
# clés fixes dans l'ordre du schéma, clés libres et vecteurs-ensembles triés (sort radix),
# types canoniques ; classe plan_calcul. Deux plans de même sens donnent le même objet.
canoniser_plan <- function(plan) {
  structure(.canoniser(plan, catalogue_garanties(), dictionnaire()), class = "plan_calcul")
}

# Octets du plan canonique (ecrire_liste()) ; le fichier est écrit par l'appelant.
ecrire_plan <- function(plan) {
  ecrire_liste(unclass(canoniser_plan(plan)))
}

# Relit des octets écrits par ecrire_plan(), sans évaluation et sans valider (la validation
# est celle de calculer_provisions()) ; rend un objet de classe plan_calcul.
lire_plan <- function(octets) {
  structure(lire_liste(octets), class = "plan_calcul")
}

# Décomptes du plan (aucune somme).
format.plan_calcul <- function(x, ...) {
  p <- unclass(x)
  texte <- function(v) if (is.null(v) || length(v) == 0L) "aucun" else paste(as.character(v), collapse = ", ")
  methodes <- tryCatch(.methodes_declarees(p$postes), error = function(e) character(0))
  c(paste0("plan de calcul (version ", texte(p$version_plan), ", arr\u00eat\u00e9 ",
           if (inherits(p$arrete, "Date")) format(p$arrete) else "non renseign\u00e9", ")"),
    paste0("  garanties : ", texte(p$perimetre$garanties), " ; r\u00e9f\u00e9rentiels : ", texte(p$perimetre$referentiels),
           " ; segmentations : ", length(p$perimetre$segmentations)),
    paste0("  tables par usage : ", length(p$tables), " (", texte(names(p$tables)), ")"),
    paste0("  m\u00e9thodes d\u00e9clar\u00e9es : ", length(methodes), if (length(methodes) > 0L)
      paste0(" (", paste(paste0(names(methodes), " = ", methodes), collapse = " ; "), ")") else ""),
    paste0("  graine : ", texte(p$graine)))
}

print.plan_calcul <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

# --- Fiche de calcul ---------------------------------------------------------------------

# Empreinte de chaque table de la base (ADR 0010, point 22 ; spécification de B2, § 2.8) :
# MD5 de l'écriture en octets (ecrire_valeurs(forme = "octets")) du nombre de lignes, puis,
# pour chaque colonne (colonnes du dictionnaire dans son ordre, puis les autres triées), de
# son nom et de ses valeurs, les lignes triées par clé primaire (sort radix, stable).
# Liste nommée, tables dans l'ordre du dictionnaire puis les autres triées.
.empreintes_base <- function(donnees, dico) {
  if (!.liste_nommee(donnees) || !all(vapply(donnees, is.data.frame, NA))) {
    refuser("fiche de calcul : `donnees` doit \u00eatre une liste nomm\u00e9e de data.frame", "liste_invalide", module = "plan")
  }
  noms <- as.character(names(donnees))
  ordre <- c(dico$tables$table[dico$tables$table %in% noms],
             sort(setdiff(noms, dico$tables$table), method = "radix"))
  res <- lapply(ordre, function(t) {
    df <- donnees[[t]]
    col_dico <- dico$colonnes$colonne[dico$colonnes$table == t]
    colonnes <- c(col_dico[col_dico %in% names(df)], sort(setdiff(names(df), col_dico), method = "radix"))
    cle <- eclater_champ(dico$tables$cle_primaire[match(t, dico$tables$table)])
    cle <- cle[cle %in% names(df)]
    if (length(cle) > 0L && nrow(df) > 1L) {
      df <- df[do.call(order, c(unname(lapply(cle, function(k) unclass(df[[k]]))), list(method = "radix"))), , drop = FALSE]
    }
    octets <- c(list(ecrire_valeurs(as.integer(nrow(df)), "octets")),
                unlist(lapply(colonnes, function(k) {
                  list(ecrire_valeurs(k, "octets"), ecrire_valeurs(unname(df[[k]]), "octets"))
                }), recursive = FALSE))
    empreinte(do.call(c, octets))
  })
  if (length(res) == 0L) return(list())
  stats::setNames(res, ordre)
}

# data.frame <-> liste de colonnes (forme sérialisable par ecrire_liste()). La relecture
# construit des noms de lignes automatiques : un data.frame passé par .df_canonique() est
# identique à sa relecture.
.df_vers_liste <- function(df) {
  if (ncol(df) == 0L) return(list())
  stats::setNames(lapply(names(df), function(n) df[[n]]), names(df))
}

.liste_vers_df <- function(l) {
  n <- if (length(l) == 0L) 0L else length(l[[1L]])
  structure(l, class = "data.frame", row.names = .set_row_names(n))
}

.df_canonique <- function(df, nom, colonnes = NULL) {
  refus <- function(raison) {
    refuser(paste0("fiche de calcul : parametres_retenus$", nom, " : ", raison), "liste_invalide", module = "plan")
  }
  if (!is.data.frame(df) || ncol(df) == 0L) refus("data.frame d'au moins une colonne attendu")
  if (anyNA(names(df)) || any(!nzchar(names(df))) || anyDuplicated(names(df))) refus("noms de colonnes renseign\u00e9s et distincts attendus")
  if (!is.null(colonnes) && !identical(names(df), colonnes)) refus(paste0("colonnes attendues : ", paste(colonnes, collapse = ", ")))
  simple <- vapply(df, function(v) {
    (is.logical(v) || is.integer(v) || is.double(v) || is.character(v)) &&
      (is.null(attributes(v)) || (identical(attributes(v), list(class = "Date")) && is.double(v)))
  }, NA)
  if (!all(simple)) refus("colonnes atomiques simples attendues (logical, integer, double, character, Date)")
  .liste_vers_df(.df_vers_liste(df))
}

# Construit la fiche de calcul (ADR 0007, point 3 ; ADR 0010, points 6 et 10 ; spécification
# de B2, § 2.8). `plan` : plan valide (canonisé ici) ; `donnees` : base reçue ;
# `parametres_retenus` : liste nommée des sept data.frame de PARAMETRES_RETENUS ; `tables` :
# tables reçues, nommées par identifiant (empreinte lue dans x$origine$empreinte) ;
# `provenance` : argument de calculer_provisions(), repris tel quel (NULL ou liste nommée
# sérialisable). Les empreintes du résultat et du code sont remplies en (4) : NA ici.
construire_fiche <- function(plan, donnees, parametres_retenus, tables = list(), provenance = NULL) {
  dico <- dictionnaire()
  plan <- canoniser_plan(plan)
  if (!.liste_nommee(parametres_retenus) || !identical(names(parametres_retenus), PARAMETRES_RETENUS)) {
    refuser(paste0("fiche de calcul : parametres_retenus doit porter, dans cet ordre : ",
                   paste(PARAMETRES_RETENUS, collapse = ", ")), "liste_invalide", module = "plan")
  }
  pr <- stats::setNames(lapply(PARAMETRES_RETENUS, function(n) {
    .df_canonique(parametres_retenus[[n]], n,
                  switch(n, postes = COLONNES_POSTES_RETENUS, tables = COLONNES_TABLES_RETENUES, NULL))
  }), PARAMETRES_RETENUS)
  if (!.liste_nommee(tables)) {
    refuser("fiche de calcul : `tables` doit \u00eatre une liste nomm\u00e9e par identifiant", "liste_invalide", module = "plan")
  }
  ids <- sort(as.character(names(tables)), method = "radix")
  empreintes_tables <- lapply(ids, function(id) {
    e <- .empreinte_table(tables[[id]])
    if (!(is.character(e) && .scalaire(e) && grepl("^[0-9a-f]{32}$", e))) {
      refuser(paste0("fiche de calcul : table ", id, " sans empreinte (origine$empreinte)"), "liste_invalide",
              module = "plan", usage = id)
    }
    e
  })
  if (!is.null(provenance)) ecrire_liste(provenance)   # refus liste_invalide si non sérialisable
  fiche <- list(
    plan = plan,
    parametres_retenus = pr,
    empreintes = list(
      donnees = .empreintes_base(donnees, dico),
      fichiers = provenance,
      tables = if (length(ids) == 0L) list() else stats::setNames(empreintes_tables, ids),
      resultat = NA_character_,
      code = NA_character_,
      representation = REPRESENTATION_CANONIQUE),
    versions = .versions_courantes(dico),
    plateforme = decrire_plateforme(),
    graine = list(valeur = plan$graine, generateur = .GENERATEUR_GRAINE))
  structure(fiche, class = "fiche_calcul")
}

# Empreinte de l'original d'une table reçue (table_provie : x$origine$empreinte, ADR 0010,
# point 15) ; NA si l'objet n'en porte pas.
.empreinte_table <- function(x) {
  e <- if (is.list(x) && is.list(x[["origine"]])) x[["origine"]][["empreinte"]] else NULL
  if (is.character(e) && length(e) == 1L) e else NA_character_
}

.versions_courantes <- function(dico) {
  list(r = paste(R.version$major, R.version$minor, sep = "."),
       provie = as.character(utils::packageVersion("provie")),
       fiche = VERSION_FICHE,
       dictionnaire = dico$version)
}

# Octets de la fiche (ecrire_liste()) ; le fichier est écrit par l'appelant.
ecrire_fiche <- function(fiche) {
  if (!inherits(fiche, "fiche_calcul") || !identical(names(fiche), CHAMPS_FICHE)) {
    refuser(paste0("ecrire_fiche() : objet fiche_calcul attendu (champs ", paste(CHAMPS_FICHE, collapse = ", "), ")"),
            "liste_invalide", module = "plan")
  }
  x <- unclass(fiche)
  x$plan <- unclass(x$plan)
  x$parametres_retenus <- lapply(x$parametres_retenus, .df_vers_liste)
  ecrire_liste(x)
}

# Relit des octets écrits par ecrire_fiche(), sans évaluation ; rend un objet fiche_calcul
# (plan de classe plan_calcul, paramètres retenus en data.frame). La version de la fiche est
# contrôlée par le rejeu (version_discordante), pas ici.
lire_fiche <- function(octets) {
  x <- lire_liste(octets)
  if (!identical(names(x), CHAMPS_FICHE) || !.liste_nommee(x$plan) || !.liste_nommee(x$parametres_retenus) ||
      !identical(names(x$parametres_retenus), PARAMETRES_RETENUS) ||
      !all(vapply(x$parametres_retenus, function(l) is.list(l) && length(l) > 0L &&
                    length(unique(lengths(l))) == 1L, NA))) {
    refuser(paste0("lire_fiche() : la liste lue n'a pas la forme d'une fiche de calcul (",
                   paste(CHAMPS_FICHE, collapse = ", "), ")"), "liste_invalide", module = "plan")
  }
  x$plan <- structure(x$plan, class = "plan_calcul")
  x$parametres_retenus <- lapply(x$parametres_retenus, .liste_vers_df)
  structure(x, class = "fiche_calcul")
}

# Décomptes de la fiche (aucune somme).
format.fiche_calcul <- function(x, ...) {
  f <- unclass(x)
  v <- f$versions
  c(paste0("fiche de calcul (version ", v$fiche, ") : R ", v$r, ", provie ", v$provie, ", dictionnaire ", v$dictionnaire),
    paste0("  plan : arr\u00eat\u00e9 ", if (inherits(f$plan$arrete, "Date")) format(f$plan$arrete) else "non renseign\u00e9",
           ", graine ", paste(f$graine$valeur, collapse = ", ")),
    paste0("  param\u00e8tres retenus : ", paste(paste0(names(f$parametres_retenus), " ",
                                                    vapply(f$parametres_retenus, nrow, 0L)), collapse = ", ")),
    paste0("  empreintes : ", length(f$empreintes$donnees), " table(s) de la base, ", length(f$empreintes$tables),
           " table(s) re\u00e7ue(s)"),
    paste0("  plateforme : ", f$plateforme$plateforme))
}

print.fiche_calcul <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

# Contrôles d'entrée du rejeu (ADR 0007, point 6 ; spécification de B2, § 2.1), dans cet
# ordre : version de la fiche (refus version_discordante) ; versions de R et de provie
# (signalées, sans refus) ; empreintes des données reçues (refus empreinte_discordante, à la
# première table discordante dans l'ordre du dictionnaire, table manquante ou en trop
# comprise) ; empreintes des tables (refus table_absente, empreinte_discordante). Rend
# list(signalements = data.frame(grandeur, fiche, courant)).
.controler_rejeu <- function(fiche, donnees, tables = list()) {
  if (!inherits(fiche, "fiche_calcul") || !identical(names(fiche), CHAMPS_FICHE)) {
    refuser("rejeu : objet fiche_calcul attendu", "liste_invalide", module = "plan")
  }
  dico <- dictionnaire()
  v <- fiche$versions
  if (!identical(v$fiche, VERSION_FICHE)) {
    refuser(paste0("rejeu : version de fiche ", paste(v$fiche, collapse = ", "), " ; version attendue : ", VERSION_FICHE),
            "version_discordante", module = "plan", attendu = as.character(VERSION_FICHE),
            recu = paste(v$fiche, collapse = ", "))
  }
  courantes <- .versions_courantes(dico)
  grandeurs <- c("r", "provie")
  differentes <- grandeurs[!vapply(grandeurs, function(g) identical(v[[g]], courantes[[g]]), NA)]
  signalements <- data.frame(grandeur = differentes,
                             fiche = vapply(differentes, function(g) paste(v[[g]], collapse = ", "), "", USE.NAMES = FALSE),
                             courant = vapply(differentes, function(g) courantes[[g]], "", USE.NAMES = FALSE),
                             stringsAsFactors = FALSE)
  attendues <- fiche$empreintes$donnees
  recues <- .empreintes_base(donnees, dico)
  noms <- as.character(union(names(attendues), names(recues)))
  noms <- c(dico$tables$table[dico$tables$table %in% noms], sort(setdiff(noms, dico$tables$table), method = "radix"))
  for (t in noms) {
    a <- if (t %in% names(attendues)) attendues[[t]] else NA_character_
    r <- if (t %in% names(recues)) recues[[t]] else NA_character_
    if (!identical(a, r)) {
      refuser(paste0("rejeu : empreinte de la table ", t, " de la base diff\u00e9rente de celle de la fiche",
                     if (is.na(a)) " (table absente de la fiche)" else if (is.na(r)) " (table absente des donn\u00e9es)" else ""),
              "empreinte_discordante", module = "plan", table = t, attendu = a, recu = r)
    }
  }
  for (id in names(fiche$empreintes$tables)) {
    if (is.null(tables[[id]])) {
      refuser(paste0("rejeu : table ", id, " de la fiche non re\u00e7ue"), "table_absente", module = "plan", usage = id)
    }
    e <- .empreinte_table(tables[[id]])
    if (!identical(e, fiche$empreintes$tables[[id]])) {
      refuser(paste0("rejeu : empreinte de la table ", id, " diff\u00e9rente de celle de la fiche"), "empreinte_discordante",
              module = "plan", usage = id, attendu = fiche$empreintes$tables[[id]],
              recu = if (is.character(e) && length(e) == 1L) e else NA_character_)
    }
  }
  list(signalements = signalements)
}
