# Contre-vérification hors CI des cas P3 de la branche B2 par `lifecontingencies`
# (spécification de B2, docs/specifications/b2-capital-deces-v1.md, § 7.6, version 1.0.4 ;
# critère 3.11 ; #66 ; ADR 0004, point 5). Lancé à la main, sur ordre du mainteneur, jamais par
# la CI ni par les batteries ; `lifecontingencies` n'est pas une dépendance du package (1.6.3
# exige un R plus récent que 4.3.3 selon l'ADR 0004 : l'exécuter sur un poste muni d'un R
# récent).
# Usage, depuis la racine du dépôt : Rscript tests/contre_verification/b2_lifecontingencies.R
# Table fictive du § 3.6 (âges 40 à 43, l_x = 100 000 ; 99 000 ; 97 020 ; 94 109,4), taux 0,02 :
#   - Axn(x = 41, n = 2) x 100 000, contre T1 (prime unique, arrêté à l'anniversaire 1) ;
#   - Axn(x = 40, n = 3) x 100 000, contre A_effet du cas T3 ;
#   - axn(x = 40, n = 3) (paiement d'avance), contre ä_effet du cas T3.
# `Axn` et `axn` comptent des durées entières : leurs valeurs se comparent aux valeurs à
# durées entières (A_effet = 5 626,2297306466 ; ä_effet = 2,9031141869 ; T1 = 4 786,6205305652),
# non aux valeurs du code (A_effet = 5 626,2288966461 ; ä_effet = 2,9031139047), qui en
# diffèrent d'environ 1,5e-7 en relatif par l'effet du 29 février 2024 sur le découpage
# exact_exact du § 2.5 (durée de 2024-01-01 à 2025-01-01 : 365/366 + 1/365) ; T1 n'est pas
# touché. Le script imprime la version de R, celle du package, la date, chaque valeur, son
# écart à la valeur à durées entières et son écart à la valeur du code ; les valeurs sont
# ensuite écrites en dur dans les tests avec ces versions et cette date (régénération sur
# ordre du mainteneur, tableau avant / après).
if (!requireNamespace("lifecontingencies", quietly = TRUE)) {
  stop("lifecontingencies n'est pas installé : contre-vérification non exécutée", call. = FALSE)
}
suppressPackageStartupMessages(library(lifecontingencies))
at <- methods::new("actuarialtable", x = 40:43, lx = c(100000, 99000, 97020, 94109.4), interest = 0.02,
                   name = "mortalite_fictive_b2")
valeurs <- c(T1 = Axn(at, x = 41, n = 2) * 100000,
             A_effet = Axn(at, x = 40, n = 3) * 100000,
             a_effet = axn(at, x = 40, n = 3))
durees_entieres <- c(T1 = 4786.6205305652, A_effet = 5626.2297306466, a_effet = 2.9031141869)
code <- c(T1 = 4786.6205305652, A_effet = 5626.2288966461, a_effet = 2.9031139047)
cat("R :", R.version.string, "\n")
cat("lifecontingencies :", as.character(utils::packageVersion("lifecontingencies")), "\n")
cat("date :", format(Sys.Date()), "\n")
for (k in names(valeurs)) {
  cat(sprintf("%-8s %.10f  ecart aux durees entieres %.3e  ecart relatif au code %.3e\n", k, valeurs[[k]],
              valeurs[[k]] - durees_entieres[[k]], (valeurs[[k]] - code[[k]]) / code[[k]]))
}
