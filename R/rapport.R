# Module `rapport` (ADR 0010, points 1, 6 et 22 ; ADR 0011, points 3 et 4 ; spécification de
# B2, docs/specifications/b2-capital-deces-v1.md, § 2.8 et § 7.7) : représentation canonique
# du résultat, empreinte du résultat et empreinte du code. B2 (#67) n'y met que ce qui sert
# l'objet resultat_provie et les références de non-régression ; les quantités restituées, le
# tableau de passage, la comparaison de deux résultats et le rapport figé viennent en B7 et B8.
# N'appelle que le module `outils` (graphe du point 1 : tous les modules sauf `lecture`,
# `simulation` et `calculer_provisions`). Ne parle pas (point 12). Code ASCII hors
# commentaires (M112).
# Convention de ce fichier : une fonction dont le nom commence par un point est un
# auxiliaire du module ; la concordance documentation <-> code ne recense que les autres.

# --- Constantes ------------------------------------------------------------------

# Champs de l'objet resultat_provie (ADR 0010, point 6), dans cet ordre, aucun autre ; ceux de
# la représentation du résultat (ADR 0011, point 4) : tous sauf `fiche`.
CHAMPS_RESULTAT <- c("provisions", "dossiers", "echeanciers", "triangles", "passage", "indicateurs", "donnees",
                     "fiche")

# --- Représentation et empreintes --------------------------------------------------

# Représentation du résultat (ADR 0011, point 4 ; ADR 0010, point 22, annoté) : liste nommée
# des champs de l'objet hors `fiche`, dans l'ordre de CHAMPS_RESULTAT ; un data.frame y est la
# liste nommée de ses colonnes, dans leur ordre, sans classe ni noms de lignes (liste vide pour
# un data.frame sans colonne) ; une liste y est parcourue de même ; un champ absent y est NULL ;
# les noms portés par un vecteur atomique sont retirés (ecrire_liste() ne les écrit pas). Seule
# fonction de parcours : l'empreinte du résultat (empreinte_resultat()) et la référence
# resultat.txt (ecrire_liste() de cette liste) en sortent. Sans point : appelée par
# l'orchestration et par les tests (références) ; non exportée.
representation_resultat <- function(resultat) {
  if (!inherits(resultat, "resultat_provie") || !identical(names(resultat), CHAMPS_RESULTAT)) {
    stop("representation_resultat() : objet resultat_provie attendu (champs ", paste(CHAMPS_RESULTAT, collapse = ", "),
         ")", call. = FALSE)
  }
  champs <- setdiff(CHAMPS_RESULTAT, "fiche")
  res <- lapply(champs, function(n) .representer(resultat[[n]]))
  names(res) <- champs
  res
}

.representer <- function(x) {
  if (is.null(x)) return(NULL)
  if (is.data.frame(x)) {
    if (ncol(x) == 0L) return(list())
    res <- lapply(seq_len(ncol(x)), function(j) .representer(x[[j]]))
    names(res) <- names(x)
    return(res)
  }
  if (is.list(x)) {
    if (length(x) == 0L) return(list())
    res <- lapply(seq_along(x), function(j) .representer(x[[j]]))
    names(res) <- names(x)
    return(res)
  }
  names(x) <- NULL
  x
}

# Empreinte du résultat (ADR 0010, point 22 ; ADR 0011, point 4) : MD5 des octets que
# ecrire_liste() écrit pour representation_resultat(resultat), les mêmes que ceux de la
# référence resultat.txt ; le nom de cette représentation est REPRESENTATION_CANONIQUE
# (`outils`), consigné dans fiche$empreintes$representation. Témoin d'identité sur une même
# machine (ADR 0007, point 9). Sans point : appelée par l'orchestration et par les tests ;
# non exportée.
empreinte_resultat <- function(resultat) {
  empreinte(ecrire_liste(representation_resultat(resultat)))
}

# Objets de l'espace de noms hors de l'empreinte du code (spécification de B2, § 2.8) : le
# premier porte le chemin d'installation, le second double des fonctions déjà comptées.
.HORS_EMPREINTE_CODE <- c(".__NAMESPACE__.", ".__S3MethodsTable__.")

# Empreinte du code (spécification de B2, § 2.8 et § 6.4, point 8, erratum v1.0.13) : MD5 des
# octets de serialize(x, NULL, version = 2), où x est la liste, triée par nom (sort radix, ordre
# des octets), des objets de l'espace de noms de provie (all.names = TRUE), hors
# .HORS_EMPREINTE_CODE ; une fonction y est réduite à list(formals(f), body(f)) sans
# références de source (.sans_source()) : arguments et corps, sans environnement ; tout autre
# objet (constantes de règles, tables internes, .packageName) y entre tel quel : modifier une
# constante change l'empreinte. En version 2 de la sérialisation, une chaîne non ASCII
# (marquée UTF-8 : le code est ASCII, échappements \u hors commentaires, M112) s'écrit en
# octets UTF-8 avec sa marque, et l'en-tête ne porte pas l'encodage natif : l'empreinte ne
# dépend pas de la locale, alors que deparse() écrit les chaînes non ASCII selon la locale.
# L'en-tête porte la version de R qui écrit (octets 7 à 10) : l'empreinte dépend de la version
# de R (consignée dans fiche$versions$r). L'espace de noms est celui où la fonction est définie
# (topenv()), parcouru par eapply(), sans accès par un nom. Témoin d'identité sur une même
# plateforme, jamais un critère de rejeu chez un tiers (ADR 0007, point 9). Exclue des
# comparaisons aux références (ADR 0011, point 6). Sans point : appelée par l'orchestration ;
# non exportée.
empreinte_code <- function() {
  objets <- eapply(topenv(), function(x) {
    if (is.function(x)) list(.sans_source(formals(x)), .sans_source(body(x))) else x
  }, all.names = TRUE)
  noms <- sort(setdiff(names(objets), .HORS_EMPREINTE_CODE), method = "radix")
  empreinte(serialize(objets[noms], NULL, version = 2L))
}

# Expression sans références de source (package installé avec keep.source) : attributs srcref,
# srcfile et wholeSrcref retirés, et quatrième élément (srcref) de chaque appel `function`
# littéral, récursivement dans les appels et les listes d'arguments ; utils::removeSource()
# laisse ce quatrième élément (R 4.3.3, mesuré).
.sans_source <- function(x) {
  if (is.null(x) || !(is.call(x) || is.pairlist(x))) return(x)
  if (is.call(x) && identical(x[[1L]], as.name("function")) && length(x) == 4L) x[[4L]] <- NULL
  for (i in seq_along(x)) if (is.call(x[[i]]) || (is.pairlist(x[[i]]) && !is.null(x[[i]]))) x[[i]] <- .sans_source(x[[i]])
  for (a in c("srcref", "srcfile", "wholeSrcref")) attr(x, a) <- NULL
  x
}
