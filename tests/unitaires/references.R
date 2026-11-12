# Tests de l'outillage des références de non-régression (tests/references.R ; ADR 0011, points 2
# à 10, 17, 20 et 23 ; #67) : comparateur feuille par feuille, visa requis, arbre écrit dans un
# dossier temporaire et ses contrôles, résumé du candidat, garde-fou du script de régénération.
# Aucune référence n'est produite : l'arbre des tests est écrit sous tempdir() et supprimé.
# Exécuté par tests/test_unitaires.R : le package est installé et chargé, le harnais est
# sourcé, `racine` est défini.

source(file.path(racine, "tests", "references.R"))
ns <- asNamespace("provie")
tb <- b2_tables()
r_c1 <- calculer_provisions(b2_base_construite_deces_01(), b2_plan_reference("recommandees", D("2025-12-31"), tb), par_identifiant(tb))
relu <- function(x) ns$lire_liste(ns$ecrire_liste(x))

section("comparateur feuille par feuille (ADR 0011, points 7 et 8)")
verifier_egal("tolérance mixte 1e-10 : écart relatif au-dessus de 1, absolu en dessous ; zéro sans singularité",
              comparer_feuilles(relu(list(x = c(1e8 * (1 + 0.9e-10), 0.5e-10, 1 + 2e-10, 100.009))),
                                relu(list(x = c(1e8, 0, 1, 100))))$cle,
              c("3", "4"))
verifier("r3 de l'ADR 0011 : 100,009 contre 100 est un écart (all.equal l'aurait admis)",
         nrow(comparer_feuilles(relu(list(x = c(1e8 * (1 + 1e-13), 100.009))), relu(list(x = c(1e8, 100))))) == 1L)
verifier_egal("différences de structure : NA contre valeur, NA contre NaN, Inf contre fini, entier contre réel, longueur, feuille absente ou nouvelle",
              comparer_feuilles(relu(list(a = c(NA, NaN, Inf), b = 1L, c = 1:2, d = 1)), relu(list(a = c(1, NA, 1), b = 1, c = 1:3, e = 1)))$nature,
              rep("structure", 7L))
verifier_egal("chaînes, logiques, dates : égalité exacte",
              nrow(comparer_feuilles(relu(list(s = "a", l = TRUE, d = D("2025-01-01"))), relu(list(s = "b", l = FALSE, d = D("2025-01-02"))))),
              3L)
lr <- liste_resultat(r_c1)
verifier("un résultat comparé à lui-même : aucun écart", nrow(comparer_feuilles(lr, lr, tables = list(provisions = CLES_PROVISIONS))) == 0L)
r_mod <- r_c1
k <- which(r_mod$provisions$poste == "total" & r_mod$provisions$segmentation == "ensemble")
r_mod$provisions$montant[k] <- r_mod$provisions$montant[k] + 1
r_mod$provisions <- r_mod$provisions[-1L, ]
ec <- comparer_feuilles(liste_resultat(r_mod), lr, tables = list(provisions = CLES_PROVISIONS, dossiers = CLES_DOSSIERS))
ec$visa <- visa_requis(ec)
verifier_egal("provisions alignées sur leurs clés : ligne retirée nommée par sa clé ; montant du total ensemble modifié : visa du mainteneur",
              ec[c("chemin", "cle", "nature", "visa")],
              data.frame(chemin = c("provisions", "provisions/montant"),
                         cle = c("deces|comptes_sociaux|capitaux_non_reclames|ensemble|ensemble", "deces|comptes_sociaux|total|ensemble|ensemble"),
                         nature = c("ligne_retiree", "valeur"), visa = c("actuary", "mainteneur"), stringsAsFactors = FALSE))
# Écarts de structure de provisions : visa du mainteneur (m1 de la revue finale) ; témoin : un
# écart de structure hors de provisions (dossiers) reste à actuary.
visa_de <- function(r_x, lr_ref = lr) {
  e <- comparer_feuilles(liste_resultat(r_x), lr_ref, tables = list(provisions = CLES_PROVISIONS, dossiers = CLES_DOSSIERS))
  e$visa <- visa_requis(e)
  e
}
r_ren <- r_c1
names(r_ren$provisions)[names(r_ren$provisions) == "statut_resultat"] <- "statut_resultat_x"
r_typ <- r_c1
r_typ$provisions$nombre_dossiers <- as.double(r_typ$provisions$nombre_dossiers)
lr_sans <- lr
lr_sans$provisions <- NULL
r_dos <- r_c1
r_dos$dossiers$montant <- as.character(r_dos$dossiers$montant)
e_ren <- visa_de(r_ren)
e_typ <- visa_de(r_typ)
e_abs <- visa_de(r_c1, lr_sans)
e_dos <- visa_de(r_dos)
verifier_egal("écart de structure de provisions : colonne renommée, type changé (entier contre réel), table absente de la référence : visa du mainteneur ; type changé dans dossiers : actuary",
              list(e_ren[c("chemin", "nature", "visa")], e_typ[c("chemin", "nature", "visa")], e_abs[c("chemin", "nature", "visa")],
                   unique(e_dos$visa)),
              list(data.frame(chemin = "provisions", nature = "structure", visa = "mainteneur", stringsAsFactors = FALSE),
                   data.frame(chemin = "provisions/nombre_dossiers", nature = "structure", visa = "mainteneur", stringsAsFactors = FALSE),
                   data.frame(chemin = "provisions", nature = "structure", visa = "mainteneur", stringsAsFactors = FALSE),
                   "actuary"))
fl <- liste_fiche(r_c1$fiche)
fm <- r_c1$fiche
fm$versions$provie <- "9.9.9"
fm$plateforme$blas <- "autre"
fm$empreintes$code <- strrep("0", 32L)
fm$graine$valeur <- 2L
verifier_egal("fiche : exclusions (versions/provie, plateforme, empreintes/code) non comparées ; la graine l'est",
              comparer_feuilles(liste_fiche(fm), fl, exclusions = EXCLUSIONS_FICHE)$chemin, "graine/valeur")

section("arbre des références dans un dossier temporaire (ADR 0011, points 2, 5 et 23 (iv))")
tmp <- tempfile("arbre-")
chemins_t <- c("construite-deces-01/recommandees/2025-12-31", "x/y/2025-01-01")
prov <- list(version_references = VERSION_REFERENCES, commit = strrep("a", 40L), run = "1", tentative = "1",
             image = "rocker/r-ver:4.3.3@sha256:0", plateforme = ns$decrire_plateforme(), couples = chemins_t[1L])
e_arbre <- ecrire_arbre_references(stats::setNames(list(r_c1), chemins_t[1L]), tmp, prov)
verifier_egal("arbre écrit : provenance.txt, empreintes.md5, resultat.txt et fiche.txt ; empreinte de l'arbre = MD5 de empreintes.md5",
              list(sort(list.files(tmp, recursive = TRUE), method = "radix"), e_arbre),
              list(c("construite-deces-01/recommandees/2025-12-31/fiche.txt", "construite-deces-01/recommandees/2025-12-31/resultat.txt",
                     "empreintes.md5", "provenance.txt"), unname(as.character(tools::md5sum(file.path(tmp, "empreintes.md5"))))))
verifier_egal("controler_arbre() : arbre conforme (couple produit et couple a_produire sans répertoire)",
              controler_arbre(tmp, chemins_t, c(TRUE, FALSE)), c(bijection = TRUE, md5 = TRUE, provenance = TRUE))
verifier("resultat.txt de l'arbre : comparé au calcul, aucun écart ; son MD5 est fiche$empreintes$resultat",
         nrow(comparer_couple(r_c1, lire_fichier(file.path(tmp, chemins_t[1L], "resultat.txt")),
                              lire_fichier(file.path(tmp, chemins_t[1L], "fiche.txt")))) == 0L &&
           identical(unname(as.character(tools::md5sum(file.path(tmp, chemins_t[1L], "resultat.txt")))), r_c1$fiche$empreintes$resultat))
verifier_egal("témoins : couple produit sans répertoire ; répertoire sans couple ; fichier modifié après empreintes.md5",
              list(controler_arbre(tmp, chemins_t, c(TRUE, TRUE))[["bijection"]],
                   controler_arbre(tmp, chemins_t[2L], c(FALSE))[["bijection"]],
                   local({ cat("x", file = file.path(tmp, chemins_t[1L], "fiche.txt"), append = TRUE)
                           controler_arbre(tmp, chemins_t, c(TRUE, FALSE))[["md5"]] })),
              list(FALSE, FALSE, FALSE))
verifier("ecrire_arbre_references() refuse tests/reference/",
         inherits(tryCatch(ecrire_arbre_references(list(), file.path(DOSSIER_REFERENCES, "x"), prov), error = function(e) e), "error"))
unlink(tmp, recursive = TRUE)

section("résumé du candidat et message du commit de référence (ADR 0011, points 16 et 20)")
res_t <- stats::setNames(list(r_c1), chemins_t[1L])
lignes <- resume_candidat(res_t, stats::setNames(list(NULL), chemins_t[1L]), prov, e_arbre)
verifier("résumé : total deces de C1 (445 437,9451518568), couple sans « avant », empreinte de l'arbre",
         any(grepl("| construite-deces-01/recommandees/2025-12-31 | deces | comptes_sociaux | 445437.9451518568 | calcule |  |",
                   lignes, fixed = TRUE)) && any(grepl("premi\u00e8res r\u00e9f\u00e9rences", lignes, fixed = TRUE)) &&
           any(grepl(e_arbre, lignes, fixed = TRUE)))
m <- message_commit_candidat(res_t, stats::setNames(list(NULL), chemins_t[1L]), prov, e_arbre, character(0), "https://exemple/1")
verifier("message : lignes Run, Commit calculé, Image, Plateforme, Empreinte, Visa (contrôlées par commit_reference.sh)",
         all(vapply(c("^Run : ", "^Commit calcul\u00e9 : a{40} ", "^Image : ", "^Plateforme : ", paste0("^Empreinte : ", e_arbre, "$"),
                      "^Visa : ", "^Couples : 1 \\(ajout\u00e9s 1, retir\u00e9s 0, modifi\u00e9s 0, inchang\u00e9s 0\\)$"),
                    function(x) any(grepl(x, m)), NA)) && m[length(m)] == "premi\u00e8res r\u00e9f\u00e9rences : aucun avant")

section("script de régénération : garde-fou (ADR 0011, point 17)")
sortie <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
                                   c(shQuote(file.path(racine, "tests", "regenerer_references.R")), shQuote(tempfile())),
                                   stdout = TRUE, stderr = TRUE, env = c("GITHUB_ACTIONS=", "PROVIE_REGENERATION=")))
verifier("hors de GitHub Actions : refus, statut 1, rien d'écrit",
         identical(attr(sortie, "status"), 1L) && any(grepl("^\\[ECHEC\\] regenerer_references.R : hors du workflow", sortie)))
