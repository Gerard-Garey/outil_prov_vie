# Références de non-régression (ADR 0011) : couples de référence, plans de référence, entrées
# des couples et comparateur feuille par feuille. Sourcé par tests/test_reproductibilite.R,
# tests/regenerer_references.R et tests/unitaires/base_construite.R : la batterie et le script
# de régénération lisent la même définition (ADR 0011, point 17). Le package est chargé ;
# `racine` est défini. Aucune référence n'est écrite ici : les références sont produites par la
# CI seule (workflow de régénération), commitées par la session principale après visa.

source(file.path(racine, "tests", "b2_bases.R"))

# --- Couples de référence (ADR 0011, point 11 ; M257, M258) ---------------------------------

# Un couple par ligne : nom, données (jeu versionné de inst/extdata/jeux/ ou base construite),
# plan de référence, arrêté, état (`a_produire` : déclaré avant sa première référence, rendu
# [ATTENDU] par la batterie, ADR 0011, point 25, M259 ; `produit` : référence commitée sous
# tests/reference/), issue. Le chemin du couple sous tests/reference/ est
# <donnees>/<plan>/<arrete>.
COUPLES_REFERENCE <- data.frame(
  couple = c("J1", "J2", "J3", "J4", "C1", "C2", "C3", "C4", "V1", "V2"),
  donnees = c("v1-modeste-01", "v1-modeste-01", "v1-modeste-02", "v1-modeste-02", rep("construite-deces-01", 4L),
              "v1-modeste-03", "v1-modeste-03"),
  plan = c(rep("recommandees", 6L), "alternatives", "alternatives", "recommandees", "recommandees"),
  arrete = c("2025-12-31", "2024-12-31", "2025-12-31", "2024-12-31", "2025-12-31", "2025-01-01", "2025-12-31",
             "2025-01-01", "2025-12-31", "2024-12-31"),
  etat = rep("produit", 10L),
  issue = rep("#67", 10L),
  stringsAsFactors = FALSE)
ETATS_COUPLE <- c("a_produire", "produit")
BASES_CONSTRUITES <- "construite-deces-01"
DOSSIER_REFERENCES <- file.path(racine, "tests", "reference")
VERSION_REFERENCES <- 1L
# Tolérance mixte (ADR 0011, point 8) : |x - r| <= EPS_REFERENCE x max(1, |r|) ; jugement
# d'expert, même seuil partout.
EPS_REFERENCE <- 1e-10
# Feuilles exclues de la comparaison (ADR 0011, point 6) : elles décrivent la machine ou le code
# qui exécute, non le résultat. Chemins sous fiche.txt ; « plateforme » couvre tout le noeud.
EXCLUSIONS_FICHE <- c("versions/provie", "versions/r", "plateforme", "empreintes/code", "empreintes/resultat")
# Clés d'alignement des lignes (invariant (d) de l'ADR 0010, point 7).
CLES_PROVISIONS <- c("garantie", "referentiel", "poste", "segmentation", "segment")
CLES_DOSSIERS <- c("garantie", "referentiel", "poste", "id_dossier")

chemin_couple <- function(i) {
  file.path(COUPLES_REFERENCE$donnees[i], COUPLES_REFERENCE$plan[i], COUPLES_REFERENCE$arrete[i])
}

# --- Plans de référence (ADR 0011, point 12) ---------------------------------------------------

# Plans `recommandees` et `alternatives` de la base construite (spécification de B2, § 7.8.2,
# forme exacte ; `tables` : b2_tables(), indexées par usage).
b2_plan_reference <- function(nom, arrete, tables) {
  stopifnot(nom %in% c("recommandees", "alternatives"))
  alt <- nom == "alternatives"
  reconst <- list(taux_sans_suite = 0, probabilite_reconnaissance_iad = 1,
                  structure_familiale = list(taux_conjoint = 0.6, nombre_enfants = 1.2),
                  age_limite_enfant_majoration = 26L, liens_conjoint_majoration = c("concubin", "conjoint", "partenaire_pacs"))
  p1 <- reconst
  if (alt) p1$delai_reglement_jours <- 30L
  rv <- list(taux_par_annee = c(`2024` = 0.03, `2025` = 0.024), prorata = "simple")
  if (alt) { rv$taux_futur <- 0.024; rv$duree_sans_depot_annees <- 10L }
  list(
    version_plan = 1L, arrete = arrete,
    perimetre = list(garanties = "deces", referentiels = "comptes_sociaux",
                     segmentations = list(nature_contrat = list(regle = "nature_contrat"))),
    tables = list(
      mortalite_tarif = list(identifiant = "mortalite_fictive_b2", empreinte = tables$mortalite_tarif$origine$empreinte,
                             statut = "fictive", hors_axes = "refus"),
      serie_tme = list(identifiant = "tme_fictive_b2", empreinte = tables$serie_tme$origine$empreinte, statut = "fictive",
                       hors_axes = "refus", decalage_publication_mois = 1L)),
    taux = list(deces = list(provision_mathematique_temporaire_deces = list(comptes_sociaux = 0.02))),
    frais = list(deces = list(
      sinistres_declares_non_regles = list(comptes_sociaux = list(taux_chargement_psap = 0.01)),
      capitaux_non_reclames = list(comptes_sociaux = list(taux_chargement_psap = 0)),
      provision_mathematique_temporaire_deces = list(comptes_sociaux = list(
        taux_chargement_gestion = 0.001, taux_chargement_acquisition = 0.01, taux_chargement_cotisation = 0.05)))),
    revalorisation = list(capital_deces = rv),
    conventions = list(age = "revolu", instant_date = "fin_journee", repartition_annee = "uniforme",
                       fractionnement = "echeances_exactes", decompte_jours = "exact_exact"),
    postes = list(deces = list(
      sinistres_declares_non_regles = list(methode = if (alt) "capital_dossier_reglement" else "capital_dossier", parametres = p1),
      capitaux_non_reclames = list(methode = if (alt) "capital_revalorise_reglement" else "capital_revalorise",
                                   parametres = c(list(critere = "beneficiaire_non_identifie"), reconst)),
      provision_mathematique_temporaire_deces = list(
        individuel = list(methode = if (alt) "prospective_prime_declaree" else "prospective_prime_pure",
                          parametres = list(pas = "an", paiement_capital = "fin_pas", plancher = "par_contrat")),
        collectif = list(methode = "prorata_cotisation", parametres = list())))),
    donnees = list(seuils = list(
      d02c_age_min = list(assures_sinistre = 16, assures_affiliation = 16, famille = 0),
      d02c_age_max = list(assures_sinistre = 75, assures_affiliation = 70, famille = 110))),
    restitution = list(echeanciers = "tous", triangles = "aucun"), liens = list(), graine = 1L)
}

# Tables d'un couple, indexées par usage (forme des plans de référence).
tables_reference <- function(donnees) {
  if (donnees %in% BASES_CONSTRUITES) b2_tables() else b2_tables_v1_03()
}

# Tables indexées par identifiant (argument `tables` de calculer_provisions(), ADR 0010, point 5).
par_identifiant <- function(tables) {
  stats::setNames(unname(tables), vapply(tables, function(t) t$identifiant, ""))
}

# Seuil de D07 (b) des plans de référence (spécification `donnees` v1.6, § 8.12 ; M337, visa de
# principe du mainteneur du 13 novembre 2026) : d07b_mois = 6, déclaré dans les seuls plans des
# couples qui ont une unité en service à l'arrêté (J2, J4, V1, V2), dont le calcul est refusé
# sans lui (declaration_manquante) ; les autres plans sont inchangés.
SEUIL_D07B_REFERENCE <- 6L
COUPLES_D07B <- c("J2", "J4", "V1", "V2")

# Entrées du couple i : list(base, plan, tables) ; plan des jeux : plan_reference_jeu()
# (tests/b2_bases.R, spécification de B2, § 7.9.6), seul plan `recommandees` des jeux.
entrees_couple <- function(i) {
  donnees <- COUPLES_REFERENCE$donnees[i]
  nom_plan <- COUPLES_REFERENCE$plan[i]
  arrete <- as.Date(COUPLES_REFERENCE$arrete[i])
  tables <- tables_reference(donnees)
  if (donnees %in% BASES_CONSTRUITES) {
    base <- switch(donnees, "construite-deces-01" = b2_base_construite_deces_01())
    plan <- b2_plan_reference(nom_plan, arrete, tables)
  } else {
    stopifnot(nom_plan == "recommandees")
    jeu <- lire_jeu(file.path(racine, "inst", "extdata", "jeux", donnees))
    base <- jeu$base
    plan <- plan_reference_jeu(jeu, arrete, tables)
  }
  if (COUPLES_REFERENCE$couple[i] %in% COUPLES_D07B) plan$donnees$seuils$d07b_mois <- SEUIL_D07B_REFERENCE
  list(base = base, plan = plan, tables = par_identifiant(tables))
}

calculer_couple <- function(e) calculer_provisions(e$base, e$plan, e$tables)

# Listes comparées (ADR 0011, point 3) : la représentation du résultat et la fiche, telles que
# relues de leur texte (types canoniques du sérialiseur).
liste_resultat <- function(resultat) asNamespace("provie")$lire_liste(ecrire_liste_resultat(resultat))
liste_fiche <- function(fiche) asNamespace("provie")$lire_liste(ecrire_fiche(fiche))
ecrire_liste_resultat <- function(resultat) {
  ns <- asNamespace("provie")
  ns$ecrire_liste(ns$representation_resultat(resultat))
}
lire_fichier <- function(chemin) readBin(chemin, "raw", n = file.info(chemin)$size)

# --- Comparateur (ADR 0011, points 7 à 10) ------------------------------------------------------

# Le comparateur (comparer_feuilles et ses fonctions) est défini dans tests/harnais.R (#79).

# Visa requis par un écart (ADR 0011, point 10) : `mainteneur` pour montant, statut_calcul ou
# motif_arret d'une cellule total / agregat / ensemble de provisions, pour l'apparition ou la
# disparition d'une telle cellule, et pour tout écart de structure de provisions (colonne
# renommée ou retirée, table absente, type changé, NA contre valeur : la provision totale peut
# changer sans que la cellule total soit nommée) ; `actuary` sinon.
visa_requis <- function(ecarts) {
  if (nrow(ecarts) == 0L) return(character(0))
  total <- grepl("\\|total\\|ensemble\\|ensemble$", ecarts$cle)
  colonne <- sub("^provisions/?", "", ecarts$chemin)
  provisions <- startsWith(ecarts$chemin, "provisions")
  ifelse(provisions & (ecarts$nature == "structure" |
                         (total & (colonne %in% c("montant", "statut_calcul", "motif_arret") |
                                     ecarts$nature %in% c("ligne_ajoutee", "ligne_retiree")))),
         "mainteneur", "actuary")
}

# Écarts d'un couple à sa référence : résultat (provisions et dossiers alignés sur leurs clés)
# et fiche (hors EXCLUSIONS_FICHE) ; colonne `visa`.
comparer_couple <- function(resultat, octets_resultat, octets_fiche) {
  lire <- asNamespace("provie")$lire_liste
  e1 <- comparer_feuilles(liste_resultat(resultat), lire(octets_resultat),
                          tables = list(provisions = CLES_PROVISIONS, dossiers = CLES_DOSSIERS))
  e2 <- comparer_feuilles(liste_fiche(resultat$fiche), lire(octets_fiche), exclusions = EXCLUSIONS_FICHE)
  if (nrow(e2) > 0L) e2$chemin <- paste0("fiche/", e2$chemin)
  e <- rbind(e1, e2)
  e$visa <- visa_requis(e)
  e
}

# Totaux par garantie et par référentiel d'un résultat (cellules total / agregat / ensemble,
# invariant (f)) : data.frame (garantie, referentiel, montant, statut_calcul, motif_arret).
totaux_resultat <- function(resultat) {
  p <- resultat$provisions
  t <- p[p$poste == "total" & p$niveau == "agregat" & p$segmentation == "ensemble",
         c("garantie", "referentiel", "montant", "statut_calcul", "motif_arret"), drop = FALSE]
  rownames(t) <- NULL
  t
}

# Couverture des méthodes (ADR 0011, point 15 ; spécification de B2, § 7.8.5) : pour chaque
# méthode recommandée ou alternative du catalogue (témoins exclus) d'une garantie au moins
# déclarée par un couple, les couples dont une cellule de niveau `calcul`, `calcule`, de
# montant non nul porte cette méthode seule (pour un poste à champs, la méthode du champ seule,
# « champ:méthode », cellule d'un segment qui ne contient que ce champ). Rend un data.frame
# (garantie, poste, methode, couples : noms joints par « , », vide si aucun).
couverture_methodes <- function(resultats) {
  cat_g <- catalogue_garanties()
  garanties <- unique(unlist(lapply(resultats, function(r) unique(r$provisions$garantie))))
  lignes <- list()
  for (i in which(cat_g$postes$code_garantie %in% garanties)) {
    l <- cat_g$postes[i, ]
    m <- asNamespace("provie")$methodes_poste(l$methodes, l$poste, "methodes")
    jetons <- ifelse(nzchar(m$champ), paste0(m$champ, ":", m$methode), m$methode)
    for (j in jetons) {
      couples <- names(resultats)[vapply(resultats, function(r) {
        p <- r$provisions
        c1 <- p[p$garantie == l$code_garantie & p$poste == l$poste & p$niveau == "calcul" & p$statut_calcul == "calcule" &
                  !is.na(p$montant) & p$montant != 0, , drop = FALSE]
        any(c1$methode == j)
      }, NA)]
      lignes[[length(lignes) + 1L]] <- data.frame(garantie = l$code_garantie, poste = l$poste, methode = j,
                                                  couples = paste(couples, collapse = ","), stringsAsFactors = FALSE)
    }
  }
  do.call(rbind, lignes)
}

# --- Arbre des références (ADR 0011, points 2 et 5) --------------------------------------------

# Écrit l'arbre des références dans `dossier` : pour chaque résultat de `resultats` (liste nommée
# par chemin de couple), <chemin>/resultat.txt (ecrire_liste() de la représentation) et
# <chemin>/fiche.txt (ecrire_fiche()) ; provenance.txt (ecrire_liste(provenance)) ;
# empreintes.md5 (une ligne par autre fichier, triés, format de md5sum -c). Rend l'empreinte de
# l'arbre (MD5 de empreintes.md5). Appelée par tests/regenerer_references.R (candidat) et par les
# tests du comparateur (dossier temporaire) ; jamais sur tests/reference/.
ecrire_arbre_references <- function(resultats, dossier, provenance) {
  if (startsWith(paste0(normalizePath(dossier, mustWork = FALSE), "/"), paste0(DOSSIER_REFERENCES, "/"))) {
    stop("ecrire_arbre_references() : jamais sous tests/reference/", call. = FALSE)
  }
  ecrire <- function(octets, chemin) {
    dir.create(dirname(chemin), recursive = TRUE, showWarnings = FALSE)
    con <- file(chemin, "wb")
    on.exit(close(con))
    writeBin(octets, con)
  }
  for (chemin in names(resultats)) {
    ecrire(ecrire_liste_resultat(resultats[[chemin]]), file.path(dossier, chemin, "resultat.txt"))
    ecrire(ecrire_fiche(resultats[[chemin]]$fiche), file.path(dossier, chemin, "fiche.txt"))
  }
  ecrire(asNamespace("provie")$ecrire_liste(provenance), file.path(dossier, "provenance.txt"))
  fichiers <- sort(setdiff(list.files(dossier, recursive = TRUE), "empreintes.md5"), method = "radix")
  md5 <- paste0(unname(as.character(tools::md5sum(file.path(dossier, fichiers)))), "  ", fichiers)
  ecrire(charToRaw(paste0(paste(md5, collapse = "\n"), "\n")), file.path(dossier, "empreintes.md5"))
  unname(as.character(tools::md5sum(file.path(dossier, "empreintes.md5"))))
}

# Contrôles de l'arbre `dossier` (ADR 0011, point 23 (iv)) : `chemins` des couples déclarés,
# `produits` (logique) ceux dont la référence est commitée. Rend un vecteur logique nommé :
# bijection (aucun répertoire sans couple déclaré, chaque couple produit a le sien, aucun autre
# fichier), md5 (empreintes.md5 : une ligne par autre fichier, MD5 exacts), provenance
# (provenance.txt bien formé : champs dans l'ordre, version, commit sur 40 hexadécimaux,
# couples = répertoires).
controler_arbre <- function(dossier, chemins, produits) {
  fichiers <- sort(list.files(dossier, recursive = TRUE), method = "radix")
  repertoires <- unique(dirname(fichiers[basename(fichiers) %in% c("resultat.txt", "fiche.txt")]))
  bijection <- all(repertoires %in% chemins) && all(chemins[produits] %in% repertoires) &&
    all(fichiers %in% c("provenance.txt", "empreintes.md5", file.path(rep(chemins, each = 2L), c("resultat.txt", "fiche.txt"))))
  f_md5 <- file.path(dossier, "empreintes.md5")
  md5 <- if (file.exists(f_md5)) readLines(f_md5) else character(0)
  listes <- substring(md5, 35L)
  ok_md5 <- length(md5) > 0L && all(grepl("^[0-9a-f]{32}  ", md5)) && identical(listes, setdiff(fichiers, "empreintes.md5")) &&
    identical(substr(md5, 1L, 32L), unname(as.character(tools::md5sum(file.path(dossier, listes)))))
  f_prov <- file.path(dossier, "provenance.txt")
  prov <- if (file.exists(f_prov)) tryCatch(asNamespace("provie")$lire_liste(lire_fichier(f_prov)), error = function(e) NULL) else NULL
  ok_prov <- is.list(prov) && identical(names(prov), c("version_references", "commit", "run", "tentative", "image", "plateforme",
                                                        "couples")) &&
    identical(prov$version_references, VERSION_REFERENCES) && grepl("^[0-9a-f]{40}$", prov$commit) &&
    setequal(prov$couples, repertoires)
  c(bijection = bijection, md5 = ok_md5, provenance = ok_prov)
}

# --- Résumé du candidat et message du commit de référence (ADR 0011, points 16 et 20) ----------

# Lignes Markdown du résumé du run : provenance, plateforme, empreinte de l'arbre, provisions
# totales par garantie et par référentiel de chaque couple (`resultats`, liste nommée par chemin),
# tableau avant / après contre l'arbre commité (`ecarts` : même noms, data.frame de
# comparer_couple() ou NULL pour un couple sans « avant »).
resume_candidat <- function(resultats, ecarts, provenance, empreinte_arbre) {
  fmt <- function(x) ifelse(is.na(x), "NA", sprintf("%.10f", x))
  pl <- provenance$plateforme
  lignes <- c("## Candidat de r\u00e9f\u00e9rences de non-r\u00e9gression (ADR 0011)", "",
              paste0("- Commit calcul\u00e9 : `", provenance$commit, "`"),
              paste0("- Run : ", provenance$run, " (tentative ", provenance$tentative, ")"),
              paste0("- Image : `", provenance$image, "`"),
              paste0("- Plateforme : ", pl$r, ", ", pl$plateforme, ", BLAS ", pl$blas, ", LAPACK ", pl$lapack_version),
              paste0("- Empreinte de l'arbre (MD5 de empreintes.md5) : `", empreinte_arbre, "`"),
              paste0("- Couples : ", length(resultats)), "",
              "### Provisions totales par garantie et par r\u00e9f\u00e9rentiel", "",
              "| Couple | Garantie | R\u00e9f\u00e9rentiel | Montant | Statut | Motif d'arr\u00eat |", "|---|---|---|---|---|---|")
  for (chemin in names(resultats)) {
    t <- totaux_resultat(resultats[[chemin]])
    lignes <- c(lignes, sprintf("| %s | %s | %s | %s | %s | %s |", rep(chemin, nrow(t)), t$garantie, t$referentiel, fmt(t$montant),
                                t$statut_calcul, ifelse(is.na(t$motif_arret), "", t$motif_arret)))
  }
  lignes <- c(lignes, "", "### Tableau avant / apr\u00e8s contre l'arbre commit\u00e9 (ADR 0011, point 10)", "")
  sans_avant <- names(resultats)[vapply(names(resultats), function(n) is.null(ecarts[[n]]), NA)]
  modifies <- character(0)
  for (chemin in setdiff(names(resultats), sans_avant)) {
    ec <- ecarts[[chemin]]
    if (nrow(ec) == 0L) next
    lignes <- c(lignes, paste0("#### ", chemin), "", "| Chemin | Cl\u00e9 | R\u00e9f\u00e9rence | Obtenu | \u00c9cart | Nature | Visa requis |",
                "|---|---|---|---|---|---|---|",
                sprintf("| %s | %s | %s | %s | %s | %s | %s |", ec$chemin, ec$cle, ec$reference, ec$obtenu, ec$ecart, ec$nature,
                        ec$visa), "")
    modifies <- c(modifies, chemin)
  }
  if (length(sans_avant)) lignes <- c(lignes, paste0("Couples sans \u00ab avant \u00bb (premi\u00e8res r\u00e9f\u00e9rences) : ", paste(sans_avant, collapse = ", ")), "")
  if (length(modifies) == 0L && length(sans_avant) < length(resultats)) lignes <- c(lignes, "Aucun \u00e9cart sur les couples commit\u00e9s.", "")
  lignes
}

# Squelette du message du commit de référence (ADR 0011, point 20) ; `commites` : chemins des
# couples de l'arbre commité ; `url_run` : URL du run.
message_commit_candidat <- function(resultats, ecarts, provenance, empreinte_arbre, commites, url_run) {
  pl <- provenance$plateforme
  sans_avant <- names(resultats)[vapply(names(resultats), function(n) is.null(ecarts[[n]]), NA)]
  modifies <- names(resultats)[vapply(names(resultats), function(n) !is.null(ecarts[[n]]) && nrow(ecarts[[n]]) > 0L, NA)]
  c("tests: r\u00e9f\u00e9rences de non-r\u00e9gression r\u00e9g\u00e9n\u00e9r\u00e9es par la CI (#NN)", "",
    paste0("Run : ", url_run, " (tentative ", provenance$tentative, ")"),
    paste0("Commit calcul\u00e9 : ", provenance$commit, " (parent du pr\u00e9sent commit)"),
    paste0("Image : ", provenance$image),
    paste0("Plateforme : ", pl$r, ", ", pl$plateforme, ", BLAS ", pl$blas, ", LAPACK ", pl$lapack_version),
    paste0("Empreinte : ", empreinte_arbre),
    sprintf("Couples : %d (ajout\u00e9s %d, retir\u00e9s %d, modifi\u00e9s %d, inchang\u00e9s %d)", length(resultats), length(sans_avant),
            length(setdiff(commites, names(resultats))), length(modifies), length(resultats) - length(sans_avant) - length(modifies)),
    "Visa : <mainteneur | actuary>, JJ/MM/AAAA, <URL du commentaire de visa>", "",
    if (length(sans_avant) == length(resultats)) "premi\u00e8res r\u00e9f\u00e9rences : aucun avant" else
      "<tableau avant / apr\u00e8s des provisions totales et des verdicts : rapport/resume.md>")
}
