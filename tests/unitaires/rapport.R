# Tests unitaires du module `rapport` (R/rapport.R) : représentation du résultat, empreinte du
# résultat et empreinte du code (ADR 0010, point 22, annoté ; ADR 0011, points 3 et 4 ;
# spécification de B2, § 2.8 ; #67).
# Exécuté par tests/test_unitaires.R : le package est installé et chargé, le harnais est
# sourcé, `racine` est défini.

source(file.path(racine, "tests", "references.R"))
ns <- asNamespace("provie")
tb <- b2_tables()
r <- calculer_provisions(b2_base_construite_deces_01(), b2_plan_reference("recommandees", D("2025-12-31"), tb), par_identifiant(tb))

section("rapport : representation_resultat()")
rep <- ns$representation_resultat(r)
verifier_egal("champs hors fiche, dans l'ordre de l'ADR 0010, point 6 ; champs absents NULL",
              list(names(rep), is.null(rep$triangles), is.null(rep$passage), "triangles" %in% names(rep)),
              list(c("provisions", "dossiers", "echeanciers", "triangles", "passage", "indicateurs", "donnees"), TRUE, TRUE, TRUE))
verifier_egal("un data.frame y est la liste nommée de ses colonnes, sans classe ni noms de lignes",
              rep$provisions, stats::setNames(lapply(names(r$provisions), function(n) r$provisions[[n]]), names(r$provisions)))
verifier("bilan : data.frame imbriqués réduits à leurs colonnes (vue$visibilite_non_determinee), vecteurs sans noms",
         is.null(attributes(rep$donnees$vue$visibilite_non_determinee)$class) && is.list(rep$donnees$vue$visibilite_non_determinee) &&
           identical(names(rep$donnees$segments), names(r$donnees$segments)))
verifier("aller-retour ecrire_liste() / lire_liste() de la représentation : identique",
         identical(ns$lire_liste(ns$ecrire_liste(rep)), rep))
verifier("data.frame sans colonne : liste vide ; NULL : NULL ; vecteur nommé : noms retirés",
         identical(ns$.representer(data.frame()), list()) && is.null(ns$.representer(NULL)) &&
           identical(ns$.representer(c(a = 1, b = 2)), c(1, 2)))
verifier("objet qui n'est pas un resultat_provie : erreur de programmation (stop), non un refus classé",
         identical(tryCatch(ns$representation_resultat(list()), refus_provie = function(e) "refus", error = function(e) "stop"), "stop"))

section("rapport : empreintes du résultat et du code")
verifier("empreinte_resultat() = MD5 des octets de ecrire_liste(representation_resultat()) = fiche$empreintes$resultat",
         identical(ns$empreinte_resultat(r), ns$empreinte(ns$ecrire_liste(rep))) &&
           identical(ns$empreinte_resultat(r), r$fiche$empreintes$resultat))
r2 <- r
r2$provisions$montant[1L] <- r2$provisions$montant[1L] + 1e-9
verifier("empreinte du résultat : un montant changé de 1e-9 change l'empreinte ; la fiche n'y entre pas",
         !identical(ns$empreinte_resultat(r2), ns$empreinte_resultat(r)) &&
           identical(ns$empreinte_resultat(within(unclass(r), fiche$graine$valeur <- 2L) |> structure(class = "resultat_provie")),
                     ns$empreinte_resultat(r)))
verifier("empreinte_code() : 32 hexadécimaux, stable d'un appel à l'autre, égale à fiche$empreintes$code",
         grepl("^[0-9a-f]{32}$", ns$empreinte_code()) && identical(ns$empreinte_code(), ns$empreinte_code()) &&
           identical(ns$empreinte_code(), r$fiche$empreintes$code))
