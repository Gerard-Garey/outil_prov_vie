# Module `calculer_provisions` (orchestration ; ADR 0006 ; ADR 0010, points 1, 4 à 7, 10 et 11 ;
# ADR 0011, point 4 ; spécification de B2, docs/specifications/b2-capital-deces-v1.md, § 6 et
# § 7.7) : point d'entrée unique calculer_provisions(donnees, plan, tables = list(),
# provenance = NULL), table des étapes ETAPES, restitution par segment et totaux, enjeu par
# poste, objet resultat_provie et rejeu d'une fiche (rejouer_fiche()). Aucun calcul de poste :
# les postes sont calculés par les familles (`engagement`, `risque_en_cours`) ; l'orchestration
# assemble leurs sorties, les somme par segment et par garantie, et écrit la fiche.
# Peut appeler tous les modules sauf `lecture` et `simulation` (graphe du point 1). Ne parle
# pas (point 12), hors des méthodes print.* et format.*. Aucun tirage en B2 : la graine du plan
# est consignée dans la fiche (point 21). Code ASCII hors commentaires (M112).
# Convention de ce fichier : une fonction dont le nom commence par un point est un
# auxiliaire du module ; la concordance documentation <-> code ne recense que les autres.

# --- Constantes ------------------------------------------------------------------

# Table des étapes (ADR 0010, point 4 ; spécification de B2, § 7.7) : calculer_provisions() la
# suit dans l'ordre, par une séquence d'appels explicite (aucun appel dynamique). Ordre entre
# familles fixé par `actuary` (§ 7.7) : aucun lien croisé en B2, `engagement` avant
# `risque_en_cours`.
ETAPES <- data.frame(
  etape = c("plan", "tables", "vue", "declarations", "arrets", "engagement", "risque_en_cours", "segments",
            "agregats", "enjeu", "fiche", "empreinte_resultat", "empreinte_code"),
  module = c("plan", "tables", "donnees", "calculer_provisions", "garanties", "engagement", "risque_en_cours",
             "donnees", "calculer_provisions", "calculer_provisions", "plan", "rapport", "rapport"),
  fonction = c("canoniser_plan", "resoudre_tables", "vue_a_date", ".controler_declarations", "postes_a_arreter",
               "calculer_engagement", "calculer_risque_en_cours", "segments_vue", ".agreger", ".enjeu_par_poste",
               "construire_fiche", "empreinte_resultat", "empreinte_code"),
  condition = c("toujours", "toujours", "toujours",
                "toujours ; refus declaration_manquante si declarations_requises n'est pas vide",
                "toujours", "chaque poste de la famille engagement au p\u00e9rim\u00e8tre",
                "chaque poste de la famille risque_en_cours au p\u00e9rim\u00e8tre",
                "toujours (vide sans segmentation d\u00e9clar\u00e9e)", "toujours", "toujours", "toujours", "toujours",
                "toujours"),
  stringsAsFactors = FALSE)

# Préfixe de motif_arret d'un total arrêté (spécification de B2, § 6.1) : « poste_arrete: »
# suivi des postes arrêtés de la garantie, triés, joints par « ; ».
PREFIXE_TOTAL_ARRETE <- "poste_arrete:"
# Poste des totaux par garantie et par référentiel (ADR 0010, point 7 (f)).
POSTE_TOTAL <- "total"

# Usages de tables lus par chaque poste (fiche$parametres_retenus$postes$usages_tables et
# tables exigées) : série TME par les trois postes du capital décès en comptes sociaux
# (indicateurs R132_3_1 de P1 et P2, A132_1 de P3, spécification de B2, § 3.5) ; table de
# mortalité du tarif par P3 individuel sous une méthode prospective (§ 2.3). `methodes` vide :
# toute méthode du champ.
.USAGES_POSTES <- data.frame(
  garantie = c("deces", "deces", "deces", "deces"),
  poste = c("sinistres_declares_non_regles", "capitaux_non_reclames", "provision_mathematique_temporaire_deces",
            "provision_mathematique_temporaire_deces"),
  champ = c("", "", "", "individuel"),
  methodes = c("", "", "", "prospective_prime_pure;prospective_prime_declaree"),
  usage = c("serie_tme", "serie_tme", "serie_tme", "mortalite_tarif"),
  stringsAsFactors = FALSE)
# Colonnes des paramètres retenus fixées en (4) (spécification de B2, § 2.8 : « celles des cinq
# autres sont fixées en (4) ») pour les deux qui n'ont pas de source dans le bilan en B2.
.COLONNES_PLAFONDS <- c("regle", "garantie", "poste", "valeur")
.COLONNES_COLONNES_ECRASEES <- c("table", "colonne")

# --- Point d'entrée --------------------------------------------------------------

# Calcule les provisions demandées par le plan `plan` sur la base `donnees` (liste nommée de
# data.frame, une table du dictionnaire par élément), avec les tables importées `tables` (liste
# nommée par identifiant d'objets table_provie) et la provenance des fichiers `provenance`
# (NULL ou liste nommée sérialisable, reprise dans la fiche). Suit ETAPES : plan validé et
# canonisé (le calcul lit le plan canonique, celui de la fiche) ; tables par usage, empreintes
# contrôlées ; vue à l'arrêté et bilan ; refus declaration_manquante si une déclaration est
# requise ; postes arrêtés par le bilan (postes_arretes des lignes de refus_tables) ; postes de
# la famille engagement, puis risque_en_cours ; segments ; cellules par segment et totaux ;
# enjeu par poste ; fiche ; empreintes du résultat et du code. Refus d'appel (refus_provie) :
# ceux du plan, des tables, de la vue et declaration_manquante ; un poste arrêté ne refuse rien
# (cellule `arrete`, ADR 0010, point 11). Rend un objet resultat_provie (CHAMPS_RESULTAT de
# `rapport`) : provisions et dossiers triés par leurs clés, échéanciers selon
# plan$restitution$echeanciers (NULL pour `aucun`), triangles et passage NULL en B2,
# indicateurs, bilan du module donnees complété, fiche de calcul.
calculer_provisions <- function(donnees, plan, tables = list(), provenance = NULL) {
  catalogue <- catalogue_garanties()
  # plan
  cp <- canoniser_plan(plan)
  garanties <- cp$perimetre$garanties
  postes_plan <- .postes_plan(cp, catalogue)
  # tables
  rt <- resoudre_tables(cp$tables, tables, .usages_exiges(postes_plan, cp, catalogue))
  # vue
  vue <- vue_a_date(donnees, cp$arrete, cp$donnees, cp$conventions)
  # declarations
  .controler_declarations(vue$bilan)
  # arrets
  arrets <- postes_a_arreter(catalogue, vue$bilan, cp$postes, parties_ligne())
  # engagement, puis risque_en_cours
  sorties <- vector("list", nrow(postes_plan))
  for (i in which(postes_plan$famille == "engagement")) {
    sorties[[i]] <- calculer_engagement(vue, cp, rt$tables, catalogue, postes_plan$garantie[i], postes_plan$poste[i])
  }
  for (i in which(postes_plan$famille == "risque_en_cours")) {
    sorties[[i]] <- calculer_risque_en_cours(vue, cp, rt$tables, catalogue, postes_plan$garantie[i],
                                             postes_plan$poste[i])
  }
  # segments
  segments <- segments_vue(vue, cp$perimetre$segmentations, garanties)
  # agregats
  provisions <- .agreger(postes_plan, sorties, segments, names(cp$perimetre$segmentations), cp, catalogue)
  # enjeu
  bilan <- vue$bilan
  bilan$refus_tables <- arrets$refus_tables
  bilan$enjeu <- .enjeu_par_poste(bilan$enjeu, postes_plan, catalogue, arrets$refus_tables)
  bilan$segments <- segments
  dossiers <- do.call(rbind, c(list(.dossiers_vides_cp()), lapply(sorties, function(s) s$dossiers)))
  dossiers <- dossiers[order(dossiers$garantie, dossiers$referentiel, dossiers$poste, dossiers$id_dossier,
                             method = "radix"), COLONNES_DOSSIERS, drop = FALSE]
  rownames(dossiers) <- NULL
  indicateurs <- do.call(rbind, c(list(.indicateurs_vides_cp()), lapply(sorties, function(s) s$indicateurs)))
  rownames(indicateurs) <- NULL
  # fiche
  identifiants <- vapply(rt$tables, function(t) t$identifiant, "", USE.NAMES = FALSE)
  tables_fiche <- stats::setNames(rt$tables, identifiants)[!duplicated(identifiants)]
  fiche <- construire_fiche(cp, donnees, .parametres_retenus(postes_plan, sorties, rt, bilan, cp), tables_fiche, provenance)
  resultat <- structure(list(
    provisions = provisions,
    dossiers = dossiers,
    echeanciers = .echeanciers_restitues(sorties, cp$restitution$echeanciers),
    triangles = NULL,
    passage = NULL,
    indicateurs = indicateurs,
    donnees = bilan,
    fiche = fiche), class = "resultat_provie")
  # empreinte_resultat, empreinte_code
  resultat$fiche$empreintes$resultat <- empreinte_resultat(resultat)
  resultat$fiche$empreintes$code <- empreinte_code()
  resultat
}

# Rejoue une fiche de calcul (ADR 0007, point 6 ; ADR 0010, point 5 ; spécification de B2,
# § 2.1) : contrôles d'entrée du rejeu (`plan`, dans cet ordre : version de la fiche, refus
# version_discordante ; versions de R et de provie, signalées sans refus ; empreintes des
# données reçues et des tables, refus empreinte_discordante ou table_absente), puis un appel de
# calculer_provisions() sur le plan canonique de la fiche, les tables `tables` (liste nommée
# par identifiant) et la provenance de la fiche. Rend list(resultat : objet resultat_provie,
# signalements : data.frame (grandeur, fiche, courant) des versions différentes).
rejouer_fiche <- function(donnees, fiche, tables = list()) {
  controle <- controler_rejeu(fiche, donnees, tables)
  resultat <- calculer_provisions(donnees, fiche$plan, tables, fiche$empreintes$fichiers)
  list(resultat = resultat, signalements = controle$signalements)
}

# Décomptes du résultat (aucune somme : une somme est une quantité de `rapport`).
format.resultat_provie <- function(x, ...) {
  p <- x$provisions
  n <- function(d) if (is.null(d)) 0L else nrow(d)
  arretees <- if (is.null(p)) 0L else sum(p$statut_calcul == "arrete")
  totaux <- if (is.null(p)) 0L else sum(p$poste == POSTE_TOTAL & p$segmentation == "ensemble")
  f <- x$fiche
  c(paste0("r\u00e9sultat de calcul (arr\u00eat\u00e9 ", if (inherits(f$plan$arrete, "Date")) format(f$plan$arrete) else
             "non renseign\u00e9", ", repr\u00e9sentation ", f$empreintes$representation, ")"),
    paste0("  provisions : ", n(p), " cellule(s), dont ", arretees, " arr\u00eat\u00e9e(s) ; ", totaux,
           " total(aux) par garantie et r\u00e9f\u00e9rentiel"),
    paste0("  dossiers : ", n(x$dossiers), " ligne(s) ; \u00e9ch\u00e9anciers : ",
           if (is.null(x$echeanciers)) "non restitu\u00e9s" else paste0(n(x$echeanciers), " ligne(s)"),
           " ; indicateurs : ", n(x$indicateurs), " ligne(s)"),
    paste0("  empreinte du r\u00e9sultat : ", f$empreintes$resultat))
}

print.resultat_provie <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

# --- Étapes de l'orchestration ---------------------------------------------------

# Postes du plan canonique, dans l'ordre du catalogue : data.frame (garantie, referentiel,
# poste, famille, provision, cle) ; un poste par garantie du périmètre, par référentiel du
# périmètre et par ligne de postes.csv de la garantie.
.postes_plan <- function(cp, catalogue) {
  lignes <- list()
  for (g in cp$perimetre$garanties) for (r in cp$perimetre$referentiels) {
    cat_g <- catalogue$postes[catalogue$postes$code_garantie == g, , drop = FALSE]
    if (nrow(cat_g) == 0L) next
    lignes[[length(lignes) + 1L]] <- data.frame(
      garantie = g, referentiel = r, poste = cat_g$poste, famille = cat_g$famille,
      provision = if (r == "comptes_sociaux") cat_g$provision_comptes_sociaux else rep("meilleure_estimation", nrow(cat_g)),
      stringsAsFactors = FALSE)
  }
  if (length(lignes) == 0L) {
    return(data.frame(garantie = character(0), referentiel = character(0), poste = character(0), famille = character(0),
                      provision = character(0), stringsAsFactors = FALSE))
  }
  res <- do.call(rbind, lignes)
  rownames(res) <- NULL
  res
}

# Usages lus par un poste du plan (.USAGES_POSTES), identifiés par leur nom d'usage.
.usages_poste <- function(cp, garantie, poste) {
  u <- .USAGES_POSTES[.USAGES_POSTES$garantie == garantie & .USAGES_POSTES$poste == poste, , drop = FALSE]
  garde <- vapply(seq_len(nrow(u)), function(i) {
    if (!nzchar(u$methodes[i])) return(TRUE)
    m <- if (nzchar(u$champ[i])) cp$postes[[garantie]][[poste]][[u$champ[i]]]$methode else cp$postes[[garantie]][[poste]]$methode
    !is.null(m) && m %in% strsplit(u$methodes[i], ";", fixed = TRUE)[[1L]]
  }, NA)
  sort(unique(u$usage[garde]), method = "radix")
}

# Usages exigés par les postes du plan, pour resoudre_tables() : data.frame (usage, garantie,
# nature) ; nature de la série TME : `taux` ; autres usages : nature de usages_tables.csv.
.usages_exiges <- function(postes_plan, cp, catalogue) {
  lignes <- list()
  for (i in seq_len(nrow(postes_plan))) {
    g <- postes_plan$garantie[i]
    for (u in .usages_poste(cp, g, postes_plan$poste[i])) {
      nature <- if (u == USAGE_SERIE_TME) "taux" else
        catalogue$usages_tables$nature[catalogue$usages_tables$code_garantie == g & catalogue$usages_tables$usage == u]
      lignes[[length(lignes) + 1L]] <- data.frame(usage = u, garantie = g, nature = nature, stringsAsFactors = FALSE)
    }
  }
  if (length(lignes) == 0L) {
    return(data.frame(usage = character(0), garantie = character(0), nature = character(0), stringsAsFactors = FALSE))
  }
  res <- unique(do.call(rbind, lignes))
  rownames(res) <- NULL
  res
}

# Refus declaration_manquante si le bilan de la vue demande une déclaration (spécification
# `donnees`, § 6, point 2 ; ADR 0010, sixième série) : `declarations_requises` est toujours vide
# dans le résultat. Une action `non_declaree` dans l'enjeu sans déclaration requise est une
# erreur de programmation (spécification `donnees`, § 4.6, critère 7).
.controler_declarations <- function(bilan) {
  dr <- bilan$declarations_requises
  if (nrow(dr) > 0L) {
    premiere <- paste(vapply(names(dr), function(n) paste0(n, " = ", as.character(dr[[n]][1L])), ""), collapse = ", ")
    refuser(paste0("calculer_provisions() : d\u00e9claration requise par le bilan, absente du plan (", nrow(dr),
                   " ligne(s) de declarations_requises ; premi\u00e8re : ", premiere, ")"),
            "declaration_manquante", module = "calculer_provisions", nombre = nrow(dr),
            identifiants = unique(as.character(dr[[2L]])))
  }
  if (any(bilan$enjeu$action %in% "non_declaree")) {
    stop("erreur interne de provie : action non_declaree dans l'enjeu sans d\u00e9claration requise", call. = FALSE)
  }
  invisible(NULL)
}

.dossiers_vides_cp <- function() {
  data.frame(id_dossier = character(0), id_sinistre = character(0), garantie = character(0), referentiel = character(0),
             poste = character(0), etat = character(0), date_entree_etat = structure(numeric(0), class = "Date"),
             montant = numeric(0), methode = character(0), statut_resultat = character(0),
             hypotheses_defaut = character(0), stringsAsFactors = FALSE)
}

.indicateurs_vides_cp <- function() {
  data.frame(regle = character(0), poste = character(0), garantie = character(0), valeur_regle = numeric(0),
             valeur_retenue = numeric(0), depassement = logical(0), detail = character(0), stringsAsFactors = FALSE)
}

# Unités de calcul d'une sortie de famille : data.frame (id_dossier, id_contrat, champ,
# montant, statut_resultat) ; dossiers de la famille engagement (id_contrat lu dans les
# segments), contrats de la famille risque_en_cours (élément `contrats`).
.unites <- function(sortie, famille, segments) {
  if (famille == "engagement") {
    d <- sortie$dossiers
    lignes_d <- segments[!is.na(segments$id_dossier), , drop = FALSE]
    return(data.frame(id_dossier = d$id_dossier,
                      id_contrat = lignes_d$id_contrat[match(d$id_dossier, lignes_d$id_dossier)],
                      champ = rep("", nrow(d)), montant = d$montant, statut_resultat = d$statut_resultat,
                      stringsAsFactors = FALSE))
  }
  ct <- sortie$contrats
  data.frame(id_dossier = rep(NA_character_, nrow(ct)), id_contrat = ct$id_contrat, champ = ct$champ,
             montant = ct$montant, statut_resultat = ct$statut_resultat, stringsAsFactors = FALSE)
}

# Segment de chaque unité pour la segmentation `nom` : dossier par id_dossier, contrat par
# id_contrat (lignes de contrat des segments, id_dossier NA). Un segment indéterminé d'une
# unité valorisée est une erreur de programmation (les postes de B2 lisent la clé : un refus
# l'aurait arrêté).
.segment_unites <- function(unites, segments, nom) {
  s <- segments[segments$segmentation == nom, , drop = FALSE]
  sd <- s[!is.na(s$id_dossier), , drop = FALSE]
  sc <- s[is.na(s$id_dossier), , drop = FALSE]
  res <- ifelse(is.na(unites$id_dossier), sc$segment[match(unites$id_contrat, sc$id_contrat)],
                sd$segment[match(unites$id_dossier, sd$id_dossier)])
  if (anyNA(res)) {
    stop("erreur interne de provie : segment ind\u00e9termin\u00e9 d'une unit\u00e9 valoris\u00e9e (segmentation ", nom, ")",
         call. = FALSE)
  }
  as.character(res)
}

# Cellules restituées (ADR 0010, points 6 et 7 ; spécification de B2, § 6.1 et § 7.7) :
#   - par poste du plan, la cellule `ensemble` de la famille (niveau `calcul`) ;
#   - par segmentation déclarée et par segment où le poste a au moins une unité (dossier ou
#     contrat) : cellule de niveau `calcul`, somme des unités du segment (sum(sort())),
#     nombre de dossiers du segment, statut le plus faible de ses unités ; pour un poste à
#     champs (P3), méthode et statut de méthode des seuls champs présents dans le segment ; un
#     poste arrêté a une cellule `arrete` (montant et nombre NA, motif du poste) par segment
#     restitué pour un autre poste de la garantie et du référentiel ;
#   - par garantie, référentiel, segmentation (`ensemble` comprise) et segment : la cellule
#     `total` de niveau `agregat` (invariant (f)), somme des cellules `calcul` des postes
#     (sum(sort())), nombre de dossiers sommé, statut le plus faible ; arrêtée dès qu'un poste
#     de la garantie et du référentiel est arrêté (montant et nombre NA, motif
#     « poste_arrete: » et postes arrêtés triés joints par « ; »), jamais la somme des postes
#     calculés (§ 6.1). Famille, provision, méthode et statut de méthode d'un total : NA.
# Rend le data.frame `provisions` (COLONNES_CELLULES), trié par garantie, référentiel, poste,
# segmentation, segment (sort radix).
.agreger <- function(postes_plan, sorties, segments, noms_segmentations, cp, catalogue) {
  cellules <- list()
  ajouter <- function(x) cellules[[length(cellules) + 1L]] <<- x
  for (i in seq_len(nrow(postes_plan))) {
    cel <- sorties[[i]]$cellules[COLONNES_CELLULES]
    attr(cel, "identifiant_arret") <- NULL
    rownames(cel) <- NULL
    ajouter(cel)
  }
  segment_cellule <- function(cel, segmentation, segment, montant, nombre, methode, statut_methode, statut_resultat) {
    cel$segmentation <- segmentation
    cel$segment <- segment
    cel$montant <- as.double(montant)
    cel$nombre_dossiers <- as.integer(nombre)
    cel$methode <- methode
    cel$statut_methode <- statut_methode
    cel$statut_resultat <- statut_resultat
    cel
  }
  cles_gr <- unique(postes_plan[c("garantie", "referentiel")])
  for (k in seq_len(nrow(cles_gr))) {
    g <- cles_gr$garantie[k]
    r <- cles_gr$referentiel[k]
    idx <- which(postes_plan$garantie == g & postes_plan$referentiel == r)
    ens <- lapply(idx, function(i) cellules[[i]])
    arretes <- vapply(ens, function(x) x$statut_calcul == "arrete", NA)
    for (nom in noms_segmentations) {
      vus <- character(0)
      par_poste <- list()
      for (j in seq_along(idx)) {
        if (arretes[j]) next
        i <- idx[j]
        u <- .unites(sorties[[i]], postes_plan$famille[i], segments)
        if (nrow(u) == 0L) next
        seg <- .segment_unites(u, segments, nom)
        par_poste[[j]] <- list(u = u, seg = seg)
        vus <- c(vus, seg)
      }
      vus <- sort(unique(vus), method = "radix")
      for (j in seq_along(idx)) {
        i <- idx[j]
        cel <- ens[[j]]
        if (arretes[j]) {
          for (s in vus) ajouter(segment_cellule(cel, nom, s, NA_real_, NA_integer_, cel$methode, cel$statut_methode,
                                                 NA_character_))
          next
        }
        if (j > length(par_poste) || is.null(par_poste[[j]])) next
        u <- par_poste[[j]]$u
        seg <- par_poste[[j]]$seg
        for (s in sort(unique(seg), method = "radix")) {
          us <- u[seg == s, , drop = FALSE]
          methode <- cel$methode
          statut_methode <- cel$statut_methode
          champs <- intersect(CHAMPS_POSTE, us$champ)
          if (length(champs) > 0L) {
            decl <- cp$postes[[g]][[postes_plan$poste[i]]]
            m <- vapply(champs, function(ch) decl[[ch]]$methode, "", USE.NAMES = FALSE)
            methode <- paste(paste0(champs, ":", m), collapse = ";")
            st <- vapply(seq_along(champs), function(h) {
              statut_methode_catalogue(catalogue, g, postes_plan$poste[i], champs[h], m[h])
            }, "")
            statut_methode <- if (all(st == "recommandee")) "recommandee" else "alternative"
          }
          ajouter(segment_cellule(cel, nom, s, .somme_montants(us$montant), sum(!is.na(us$id_dossier)), methode, statut_methode,
                                  statut_le_plus_faible(us$statut_resultat)))
        }
      }
    }
    # totaux
    tout <- do.call(rbind, cellules)
    calc <- tout[tout$garantie == g & tout$referentiel == r & tout$niveau == "calcul", , drop = FALSE]
    motif_total <- if (any(arretes)) {
      paste0(PREFIXE_TOTAL_ARRETE, paste(sort(postes_plan$poste[idx][arretes], method = "radix"), collapse = ";"))
    } else NA_character_
    for (nom in c("ensemble", noms_segmentations)) {
      cs <- calc[calc$segmentation == nom, , drop = FALSE]
      for (s in sort(unique(cs$segment), method = "radix")) {
        c1 <- cs[cs$segment == s, , drop = FALSE]
        arrete <- !is.na(motif_total)
        ajouter(data.frame(
          garantie = g, referentiel = r, poste = POSTE_TOTAL, famille = NA_character_, provision = NA_character_,
          segmentation = nom, segment = s, niveau = "agregat",
          montant = if (arrete) NA_real_ else .somme_montants(c1$montant),
          nombre_dossiers = if (arrete) NA_integer_ else as.integer(sum(c1$nombre_dossiers)),
          methode = NA_character_, statut_methode = NA_character_,
          statut_resultat = if (arrete) NA_character_ else statut_le_plus_faible(c1$statut_resultat),
          statut_calcul = if (arrete) "arrete" else "calcule", motif_arret = motif_total,
          stringsAsFactors = FALSE)[COLONNES_CELLULES])
      }
    }
  }
  res <- if (length(cellules) == 0L) NULL else do.call(rbind, cellules)
  if (is.null(res)) return(NULL)
  res <- res[order(res$garantie, res$referentiel, res$poste, res$segmentation, res$segment, method = "radix"), ,
             drop = FALSE]
  rownames(res) <- NULL
  res
}

# Somme des montants d'un poste calculé ou de ses cellules (sum(sort()), ordre fixé) : un
# montant NA y est une erreur de programmation (un poste calculé n'a que des montants finis ;
# sort() écarterait le NA en silence).
.somme_montants <- function(x) {
  if (anyNA(x)) stop("erreur interne de provie : montant NA dans un poste calcul\u00e9", call. = FALSE)
  sum(sort(x))
}

# Enjeu par poste (spécification `donnees`, § 4.5, point 3 ; spécification de B2, § 6.4, point 7,
# erratum v1.0.13, et § 7.7) : chaque rangée de l'enjeu du bilan de poste `ensemble`, d'une
# garantie du plan et d'une table renseignée (motif autre que `ensemble`) est suivie d'une copie
# par poste de cette garantie au périmètre (ordre du catalogue), selon son action ; la copie
# porte le code du poste, les autres colonnes inchangées (sans partage entre postes) :
#   - `refus` : postes de la même garantie nommés dans `postes_arretes` des lignes de
#     `refus_tables` (complété par postes_a_arreter()) de mêmes `table`, `colonne` et `motif`
#     (prédicat de l'arrêt, § 6.2, parties de ligne comprises) ;
#   - `exclure` : postes dont la famille est celle de la rangée (toute famille pour la famille
#     `ensemble`) qui lisent une colonne quelconque de la table de la rangée (lectures.csv) :
#     l'exclusion écarte la ligne entière ;
#   - `conserver` (et toute autre action) : postes de la famille de la rangée (toute famille
#     pour `ensemble`) qui lisent la table de la rangée et, quand elle est renseignée, sa colonne.
.enjeu_par_poste <- function(enjeu, postes_plan, catalogue, refus_tables) {
  if (nrow(enjeu) == 0L) return(enjeu)
  lec <- catalogue$lectures
  pp <- unique(postes_plan[c("garantie", "poste", "famille")])
  idx <- integer(0)
  poste <- character(0)
  for (i in seq_len(nrow(enjeu))) {
    idx <- c(idx, i)
    poste <- c(poste, enjeu$poste[i])
    if (!identical(enjeu$poste[i], "ensemble") || is.na(enjeu$table[i]) || !(enjeu$garantie[i] %in% pp$garantie)) next
    if (identical(enjeu$action[i], "refus")) {
      j_rt <- which(refus_tables$table == enjeu$table[i] & refus_tables$motif == enjeu$motif[i] &
                      (refus_tables$colonne %in% enjeu$colonne[i]))
      arretes <- unlist(strsplit(refus_tables$postes_arretes[j_rt][!is.na(refus_tables$postes_arretes[j_rt])], ";",
                                 fixed = TRUE), use.names = FALSE)
    }
    for (j in which(pp$garantie == enjeu$garantie[i])) {
      lit <- if (identical(enjeu$action[i], "refus")) {
        paste(pp$garantie[j], pp$poste[j], sep = "/") %in% arretes
      } else {
        regle_table <- identical(enjeu$action[i], "exclure")
        enjeu$famille[i] %in% c(pp$famille[j], "ensemble") &&
          any(lec$code_garantie == pp$garantie[j] & lec$poste == pp$poste[j] & lec$table == enjeu$table[i] &
                (regle_table | is.na(enjeu$colonne[i]) | lec$colonne %in% enjeu$colonne[i]))
      }
      if (lit) {
        idx <- c(idx, i)
        poste <- c(poste, pp$poste[j])
      }
    }
  }
  res <- enjeu[idx, , drop = FALSE]
  res$poste <- poste
  rownames(res) <- NULL
  res
}

# Échéanciers restitués (ADR 0010, point 6) selon plan$restitution$echeanciers : NULL pour
# `aucun` ; toutes les lignes pour `tous` ; sinon les lignes dont la clé (dossier ou contrat)
# est déclarée. Triés par référentiel, poste, clé, date, type de flux (sort radix, stable).
.echeanciers_restitues <- function(sorties, restitution) {
  if (identical(restitution, "aucun")) return(NULL)
  e <- do.call(rbind, lapply(sorties, function(s) s$echeanciers[COLONNES_ECHEANCIERS]))
  if (is.null(e)) return(NULL)
  if (!identical(restitution, "tous")) e <- e[e$cle %in% restitution, , drop = FALSE]
  e <- e[order(e$referentiel, e$poste, e$cle, as.numeric(e$date), e$type_flux, method = "radix"), , drop = FALSE]
  rownames(e) <- NULL
  e
}

# Texte canonique d'une liste (ecrire_liste(), relu par lire_liste()), en chaîne UTF-8.
.texte_liste <- function(x) {
  t <- rawToChar(ecrire_liste(x))
  Encoding(t) <- "UTF-8"
  t
}

# Paramètres retenus de la fiche (ADR 0010, point 10 ; spécification de B2, § 2.8) :
#   postes : une ligne par poste du plan (garantie, referentiel, poste, famille, methode,
#     statut_methode de la cellule `ensemble` ; parametres : texte canonique de
#     list(declaration = déclaration du poste au plan, identifiant_arret = premier dossier ou
#     contrat en cause d'un arrêt né de la famille, NULL sinon) ; usages_tables : identifiants
#     des tables lues, triés, joints par « ; »), puis une ligne `total` par garantie et
#     référentiel (famille, méthode et statut NA ; parametres : texte canonique de
#     list(postes = postes sommés)) ;
#   tables : lignes de resoudre_tables() ;
#   hypotheses_defaut, exclusions : ceux du bilan ;
#   plafonds : aucun plafond appliqué en B2 (regle, garantie, poste, valeur) ;
#   colonnes_ecrasees : aucune en B2 (table, colonne) ;
#   tables_absentes : tables facultatives absentes (table).
.parametres_retenus <- function(postes_plan, sorties, rt, bilan, cp) {
  ident <- stats::setNames(rt$parametres$identifiant, rt$parametres$usage)
  lignes <- lapply(seq_len(nrow(postes_plan)), function(i) {
    cel <- sorties[[i]]$cellules
    g <- postes_plan$garantie[i]
    p <- postes_plan$poste[i]
    id_arret <- attr(cel, "identifiant_arret")
    usages <- .usages_poste(cp, g, p)
    data.frame(garantie = g, referentiel = postes_plan$referentiel[i], poste = p, famille = postes_plan$famille[i],
               methode = cel$methode, statut_methode = cel$statut_methode,
               parametres = .texte_liste(list(declaration = cp$postes[[g]][[p]],
                                              identifiant_arret = if (is.null(id_arret) || is.na(id_arret)) NULL else id_arret)),
               usages_tables = paste(sort(unique(unname(ident[usages])), method = "radix"), collapse = ";"),
               stringsAsFactors = FALSE)
  })
  cles_gr <- unique(postes_plan[c("garantie", "referentiel")])
  for (k in seq_len(nrow(cles_gr))) {
    sommes <- postes_plan$poste[postes_plan$garantie == cles_gr$garantie[k] & postes_plan$referentiel == cles_gr$referentiel[k]]
    lignes[[length(lignes) + 1L]] <- data.frame(
      garantie = cles_gr$garantie[k], referentiel = cles_gr$referentiel[k], poste = POSTE_TOTAL, famille = NA_character_,
      methode = NA_character_, statut_methode = NA_character_, parametres = .texte_liste(list(postes = sommes)),
      usages_tables = "", stringsAsFactors = FALSE)
  }
  postes <- do.call(rbind, lignes)
  rownames(postes) <- NULL
  vide <- function(colonnes) {
    stats::setNames(as.data.frame(lapply(colonnes, function(x) character(0)), stringsAsFactors = FALSE), colonnes)
  }
  plafonds <- vide(.COLONNES_PLAFONDS)
  plafonds$valeur <- numeric(0)
  list(postes = postes, tables = rt$parametres, hypotheses_defaut = bilan$hypotheses_defaut,
       exclusions = bilan$exclusions, plafonds = plafonds, colonnes_ecrasees = vide(.COLONNES_COLONNES_ECRASEES),
       tables_absentes = data.frame(table = as.character(bilan$tables_absentes), stringsAsFactors = FALSE))
}
