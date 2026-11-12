# Controle : frontiere calcul / affichage du package (ADR 0010, points 12, 21 et 26 ;
# M112 ; issue #12). Sur chaque fichier de R/ (parse avec srcref, getParseData : numeros de
# ligne ; commentaires et chaines exclus des recherches de noms, hors chaine en position
# d'appel) :
#   1. aucun element de Shiny : input$ et input[[, session$, output$, reactive*, eventReactive,
#      bindEvent, reactivePoll, reactiveTimer, debounce, throttle, observe*, isolate, render*,
#      req, validate, need, showNotification, update* (update suivi d'une majuscule), shiny:: ;
#      session$ et output$ ne sont refuses que si le nom n'est pas local (M400, ci-dessous) ;
#   2. aucun set.seed(), RNGkind(), RNGversion() (appeles ou simplement references :
#      `s <- set.seed`), aucun symbole .Random.seed ni chaine ".Random.seed" hors de
#      R/outils.R (la seule voie vers l'alea est outils::avec_graine, point 21) ; un nom
#      ecrit entre accents graves ou entre guillemets en position d'appel (`cat`("x"),
#      "cat"("x")) vaut le nom nu ;
#   3. le moteur ne parle pas (point 12, etendu par decision du mainteneur du 7 novembre
#      2026, puis M401 et M411) : aucun warning(), message(), cat(), print(), writeLines(),
#      writeChar(), packageStartupMessage(), print.default(), str(), show(), sink(), appel
#      direct d'une methode print.* (print.foo(x)), write(), write.table(), write.csv(),
#      write.csv2() et write.dcf() quand leur destination est la console (voir ci-dessous),
#      hors du corps des fonctions de premier niveau nommees print.* et format.* (appeles
#      ou references, hors variables locales et champs) ; aucune lecture de l'horloge,
#      Sys.time(), Sys.Date() ou date(), nulle part, y compris dans une methode format.*
#      (M402) ou print.* (M410) : un rendu qui lit l'horloge n'est pas reproductible, seules
#      les sorties console y restent admises. Destination
#      d'une ecriture, reconnue sur l'argument `file` (nomme `file`, ou deuxieme argument
#      sans nom, ou premier si `x` est nomme) : write() a pour defaut file = "data" (un
#      fichier, pas la console) : refuse seulement si `file` est la chaine vide ou un appel
#      de stdout() / stderr() ; write.table(), write.csv(), write.csv2() et write.dcf() ont
#      pour defaut file = "" (la console ; signatures de R 4.3.3 : write.csv et write.csv2
#      passent `...` a write.table) : refuses si `file` est absent, la chaine vide ou
#      stdout() / stderr(). Un `file` qui est une variable, ou un appel contenant `...`,
#      ne se decide pas statiquement : admis. Une reference sans appel a l'un de ces cinq
#      noms (`lapply(x, write)`) est refusee comme celles des autres noms ;
#   4. code ASCII (M112) : aucun octet non ASCII dans les jetons de code (chaines, noms).
#      Les commentaires accentues sont admis et ne sont pas controles (decision du
#      mainteneur du 10 novembre 2026, M236) ; un fichier que l'analyse ne lit pas (souvent
#      un caractere non ASCII hors commentaire) est signale "non analysable" ;
#   5. si app/ existe (absent en B1 : toleree) : aucun provie::: et aucun appel de calcul
#      de la liste CALCULS_APP (heuristique : sum, mean... ; le calcul est dans le
#      package, `app/` formate et trace des quantites du resultat).
# Variable locale (M400, qui etend M236-2 a ce script) : un symbole n'est pas une reference
# a la fonction interdite du meme nom s'il est (a) la cible d'une affectation (`print <- 1`,
# variable de for), (b) un argument formel d'une fonction qui le contient, ou (c) lu apres
# une affectation du meme nom, dans l'ordre du source, faite dans une fonction qui le contient
# (ou au premier niveau hors definition) ; l'affectation prend effet a la fin de son
# expression (`print <- print` : la lecture a droite est une reference). Une lecture qui
# precede l'affectation (`lapply(x, print); print <- 1`) est comptee, dans une boucle comme
# ailleurs. L'argument de local() est une portee a part : `local({ print <- 1 })` ne masque
# pas une lecture qui le suit. Limites documentees : une affectation conditionnelle masque
# les lectures qui la suivent (`if (x) print <- 1; lapply(x, print)` passe : l'ordre du
# source, conforme a la lettre de M400) ; `<<-` est traite comme `<-` ; assign() et `->`
# ne masquent rien ; with(), within(), eval() et evalq() ne sont pas des portees.
# Usage, depuis la racine du depot : Rscript tests/controles/frontiere_calcul_affichage.R
# Un argument facultatif designe une autre racine (copie du depot, pour les temoins).
# Sortie : lignes [OK] / [ECHEC] fichier:ligne ; statut 1 au moindre [ECHEC].
# Code ASCII, R de base seulement.

options(warn = 2)
.fichier_script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
.arguments <- commandArgs(trailingOnly = TRUE)
racine <- normalizePath(if (length(.arguments) >= 1L) .arguments[1L]
                        else file.path(dirname(.fichier_script), "..", ".."), mustWork = TRUE)
.n_echec <- 0L
rel <- function(chemin) if (startsWith(chemin, paste0(racine, "/"))) substring(chemin, nchar(racine) + 2L) else chemin
ok <- function(message) cat("[OK] ", message, "\n", sep = "")
echec <- function(message, chemin = NA_character_, ligne = NA_integer_) {
  .n_echec <<- .n_echec + 1L
  position <- if (is.na(chemin)) "" else paste0(rel(chemin), if (is.na(ligne)) "" else paste0(":", ligne), " ")
  cat("[ECHEC] ", position, message, "\n", sep = "")
}
fin <- function() quit(save = "no", status = if (.n_echec > 0L) 1L else 0L)

APPELS_SHINY <- paste0("^(reactive|reactiveVal|reactiveValues|reactiveValuesToList|observe|observeEvent|",
                       "isolate|eventReactive|bindEvent|reactivePoll|reactiveTimer|debounce|throttle|",
                       "req|validate|need|showNotification|render([A-Z_.].*)?|update[A-Z].*)$")
APPELS_ALEA <- c("set.seed", "RNGkind", "RNGversion")
APPELS_BAVARDS <- c("warning", "message", "cat", "print", "Sys.time", "Sys.Date", "date",
                    "writeLines", "writeChar", "packageStartupMessage",
                    "print.default", "str", "show", "sink")
HORLOGE <- c("Sys.time", "Sys.Date", "date")
ECRITURES <- c("write", "write.table", "write.csv", "write.csv2", "write.dcf")
# Defaut de l'argument `file` : write() ecrit dans le fichier "data", les autres sur la
# console (file = "" ; write.csv et write.csv2 le tiennent de write.table).
ECRITURE_DEFAUT_CONSOLE <- c(write = FALSE, write.table = TRUE, write.csv = TRUE,
                             write.csv2 = TRUE, write.dcf = TRUE)
CALCULS_APP <- c("sum", "mean", "median", "var", "sd", "cumsum", "cumprod", "prod",
                 "quantile", "weighted.mean", "aggregate", "tapply", "rowsum", "rowSums",
                 "colSums", "rowMeans", "colMeans", "lm", "glm", "optim", "optimize",
                 "uniroot", "integrate", "set.seed")

# Jetons d'un fichier : data.frame ligne, token, texte, def (fonction de premier niveau
# qui le contient, NA hors definition), prec / suiv (jeton terminal voisin), non_ascii, local
# (symbole qui est une variable locale ou un argument de sa definition).
jetons_du_fichier <- function(chemin) {
  exprs <- parse(file = chemin, keep.source = TRUE, encoding = "UTF-8")
  pd <- getParseData(exprs)
  if (is.null(pd)) return(NULL)
  pd <- pd[order(pd$line1, pd$col1, -pd$line2, -pd$col2), ]
  hors_commentaire <- pd[pd$token != "COMMENT", ]
  haut <- hors_commentaire$id
  repeat {
    p <- hors_commentaire$parent[match(haut, hors_commentaire$id)]
    monte <- p > 0L
    if (!any(monte)) break
    haut[monte] <- p[monte]
  }
  hc <- hors_commentaire
  enfants <- split(seq_len(nrow(hc)), hc$parent)
  # Ligne (de hc) de la cible de l'expression i (`nom <- ...`), NA sinon.
  cible_de <- function(i) {
    fils <- enfants[[as.character(hc$id[i])]]
    if (length(fils) >= 3L && hc$token[fils[1L]] == "expr" &&
        hc$token[fils[2L]] %in% c("LEFT_ASSIGN", "EQ_ASSIGN")) {
      cible <- enfants[[as.character(hc$id[fils[1L]])]]
      if (length(cible) == 1L && hc$token[cible] %in% c("SYMBOL", "STR_CONST")) return(cible)
    }
    NA_integer_
  }
  nom_de <- function(i) gsub("[\"'`]", "", hc$text[i])
  nom_def <- rep(NA_character_, nrow(hc))
  for (i in which(hc$parent == 0L)) {
    cible <- cible_de(i)
    if (!is.na(cible)) nom_def[haut == hc$id[i]] <- nom_de(cible)
  }
  # Portee des variables locales (M400). Fonction englobante de chaque noeud (identifiant de
  # l'expression `function(...)` ou `\(...)` la plus proche, 0 hors de toute fonction).
  parent_de <- match(hc$parent, hc$id)
  id_fonctions <- hc$parent[hc$token %in% c("FUNCTION", "'\\\\'")]
  # L'argument de local() ouvre son propre environnement : il compte comme une portee.
  for (t in which(hc$token == "SYMBOL_FUNCTION_CALL" & gsub("[\"'`]", "", hc$text) == "local")) {
    appel <- parent_de[parent_de[t]]
    k <- if (is.na(appel)) integer(0) else enfants[[as.character(hc$id[appel])]]
    if (length(k) < 3L || hc$token[k[2L]] != "'('") next
    en_attente <- NA_character_
    for (q in k[-(1:2)]) {
      if (hc$token[q] == "SYMBOL_SUB") {
        en_attente <- hc$text[q]
      } else if (hc$token[q] == "expr") {
        if (is.na(en_attente) || en_attente == "expr") {
          id_fonctions <- c(id_fonctions, hc$id[q])
          break
        }
        en_attente <- NA_character_
      }
    }
  }
  fonction_de <- rep(NA_integer_, nrow(hc))
  courant <- hc$parent
  actif <- rep(TRUE, nrow(hc))
  repeat {
    trouve <- actif & courant %in% id_fonctions
    fonction_de[trouve] <- courant[trouve]
    racine_atteinte <- actif & !trouve & courant == 0L
    fonction_de[racine_atteinte] <- 0L
    actif <- actif & !trouve & !racine_atteinte
    if (!any(actif)) break
    courant[actif] <- hc$parent[match(courant[actif], hc$id)]
  }
  chaine_de <- function(f) {
    chaine <- integer(0)
    while (f != 0L) {
      chaine <- c(chaine, f)
      f <- fonction_de[match(f, hc$id)]
    }
    c(chaine, 0L)
  }
  # Registre des liaisons : nom, fonction qui le porte, position (ligne * 1e5 + colonne) a
  # partir de laquelle il est lie. Cibles d'affectation hors premier niveau (liees a la fin
  # de l'expression), variables de for (a la fin de la clause), arguments formels (des le
  # debut) ; `cibles` : lignes de hc des symboles qui sont eux-memes la cible.
  debut <- hc$line1 * 1e5 + hc$col1
  fin_expr <- hc$line2 * 1e5 + hc$col2
  reg_nom <- character(0)
  reg_fonction <- integer(0)
  reg_pos <- numeric(0)
  cibles <- integer(0)
  lier <- function(nom, fonction, pos) {
    reg_nom <<- c(reg_nom, nom)
    reg_fonction <<- c(reg_fonction, fonction)
    reg_pos <<- c(reg_pos, pos)
  }
  for (i in which(hc$token %in% c("expr", "expr_or_assign_or_help", "equal_assign") & hc$parent != 0L)) {
    cible <- cible_de(i)
    if (!is.na(cible)) {
      lier(nom_de(cible), if (hc$id[i] %in% id_fonctions) hc$id[i] else fonction_de[i], fin_expr[i])
      cibles <- c(cibles, cible)
    }
  }
  for (i in which(hc$token == "SYMBOL_FORMALS")) lier(nom_de(i), hc$parent[i], -Inf)
  for (k in enfants) {
    for (m in seq_len(length(k) - 1L)) {
      if (hc$token[k[m]] == "SYMBOL" && hc$token[k[m + 1L]] == "IN") {
        lier(nom_de(k[m]), fonction_de[k[m]], fin_expr[parent_de[k[m]]])
        cibles <- c(cibles, k[m])
      }
    }
  }
  terminaux <- which(hors_commentaire$terminal)
  # Une chaine en position d'appel ("f"(x) : son expression est suivie de `(`) est un appel ;
  # accents graves et guillemets sont retires des noms et des appels.
  appel_chaine <- rep(FALSE, length(terminaux))
  for (r in which(hc$token[terminaux] == "STR_CONST")) {
    e <- parent_de[terminaux[r]]
    g <- parent_de[e]
    if (!is.na(g)) {
      k <- enfants[[as.character(hc$id[g])]]
      m <- match(e, k)
      appel_chaine[r] <- !is.na(m) && m < length(k) && hc$token[k[m + 1L]] == "'('"
    }
  }
  token_eff <- ifelse(appel_chaine, "SYMBOL_FUNCTION_CALL", hc$token[terminaux])
  texte_eff <- ifelse(token_eff %in% c("SYMBOL_FUNCTION_CALL", "SYMBOL", "SYMBOL_PACKAGE"),
                      gsub("[\"'`]", "", hc$text[terminaux]), hc$text[terminaux])
  non_ascii_texte <- function(t) any(as.integer(charToRaw(enc2utf8(t))) > 127L)
  # Local au sens de M400 : cible, ou lie avant la lecture dans une fonction qui la contient.
  local <- rep(FALSE, length(terminaux))
  for (r in which(token_eff == "SYMBOL" & texte_eff %in% reg_nom)) {
    ligne_hc <- terminaux[r]
    if (ligne_hc %in% cibles) {
      local[r] <- TRUE
    } else {
      q <- which(reg_nom == texte_eff[r] & reg_pos < debut[ligne_hc])
      local[r] <- length(q) > 0L && any(reg_fonction[q] %in% chaine_de(fonction_de[ligne_hc]))
    }
  }
  # Destination des ecritures (M401, M411) : "console", "absent", "autre" (variable ou `...`),
  # NA hors des appels de write(), write.table(), write.csv(), write.csv2() et write.dcf().
  kind <- function(q) {
    ek <- enfants[[as.character(hc$id[q])]]
    if (length(ek) == 1L && hc$token[ek] == "STR_CONST") {
      return(if (gsub("[\"']", "", hc$text[ek]) == "") "console" else "autre")
    }
    if (length(ek) == 3L && hc$token[ek[1L]] == "expr" && hc$token[ek[2L]] == "'('" && hc$token[ek[3L]] == "')'") {
      nom_appele <- enfants[[as.character(hc$id[ek[1L]])]]
      # stdout(), stderr(), ou prefixes de base (`base::stdout()`, `base:::stdout()`).
      n_na <- length(nom_appele)
      nu <- n_na == 1L
      prefixe <- n_na == 3L && hc$token[nom_appele[1L]] == "SYMBOL_PACKAGE" && hc$text[nom_appele[1L]] == "base" &&
        hc$token[nom_appele[2L]] %in% c("NS_GET", "NS_GET_INT")
      if ((nu || prefixe) && hc$token[nom_appele[n_na]] == "SYMBOL_FUNCTION_CALL" &&
          hc$text[nom_appele[n_na]] %in% c("stdout", "stderr")) return("console")
    }
    if (length(ek) == 1L && hc$token[ek] == "SYMBOL" && hc$text[ek] == "...") return("inconnu")
    "autre"
  }
  # Argument `file` selon la correspondance de R : noms exacts, puis noms partiels (prefixe
  # unique parmi les formels restants), puis position, sur la signature de la fonction ;
  # write.csv et write.csv2 sont (...) passes a write.table.
  destination <- function(ligne_hc, fonction, defaut_console) {
    appel <- parent_de[parent_de[ligne_hc]]
    k <- if (is.na(appel)) integer(0) else enfants[[as.character(hc$id[appel])]]
    if (length(k) < 3L || hc$token[k[2L]] != "'('") return("autre")
    noms <- character(0)
    lignes <- integer(0)
    en_attente <- NA_character_
    for (q in k[-(1:2)]) {
      if (hc$token[q] %in% c("SYMBOL_SUB", "STR_CONST")) {
        en_attente <- nom_de(q)
      } else if (hc$token[q] == "expr") {
        noms <- c(noms, en_attente)
        lignes <- c(lignes, q)
        en_attente <- NA_character_
      } else if (hc$token[q] == "','") {
        en_attente <- NA_character_
      }
    }
    restant <- names(formals(get(if (fonction %in% c("write.csv", "write.csv2")) "write.table" else fonction)))
    affecte <- rep(NA_character_, length(noms))
    for (a in which(!is.na(noms) & noms %in% restant)) {
      if (noms[a] %in% restant) {
        affecte[a] <- noms[a]
        restant <- setdiff(restant, noms[a])
      }
    }
    for (a in which(!is.na(noms) & is.na(affecte))) {
      candidats <- restant[startsWith(restant, noms[a])]
      if (length(candidats) == 1L) {
        affecte[a] <- candidats
        restant <- setdiff(restant, candidats)
      }
    }
    nomme_file <- which(affecte %in% "file")
    if (length(nomme_file) > 0L) return(kind(lignes[nomme_file[1L]]))
    if (any(vapply(lignes, kind, "") == "inconnu")) return("autre")
    sans_nom <- lignes[is.na(noms)]
    rang <- match("file", restant)
    if (length(sans_nom) >= rang) kind(sans_nom[rang]) else if (defaut_console) "console" else "absent"
  }
  dest_ecriture <- rep(NA_character_, length(terminaux))
  for (r in which(token_eff == "SYMBOL_FUNCTION_CALL" & texte_eff %in% ECRITURES)) {
    dest_ecriture[r] <- destination(terminaux[r], texte_eff[r], ECRITURE_DEFAUT_CONSOLE[[texte_eff[r]]])
  }
  res <- data.frame(
    ligne = hors_commentaire$line1[terminaux], token = token_eff,
    texte = texte_eff, def = nom_def[terminaux],
    prec = c(NA_character_, hors_commentaire$token[terminaux][-length(terminaux)]),
    suiv = c(hors_commentaire$token[terminaux][-1L], NA_character_),
    non_ascii = vapply(hors_commentaire$text[terminaux], non_ascii_texte, logical(1), USE.NAMES = FALSE),
    local = local, ecriture = dest_ecriture,
    stringsAsFactors = FALSE)
  res
}

# --- R/ ------------------------------------------------------------------------------------
dossier_r <- file.path(racine, "R")
if (!dir.exists(dossier_r)) {
  echec("dossier R/ absent", dossier_r)
  fin()
}
fichiers <- sort(list.files(dossier_r, pattern = "\\.R$", recursive = TRUE, full.names = TRUE,
                            all.files = TRUE), method = "radix")
avant <- .n_echec
for (chemin in fichiers) {
  j <- tryCatch(jetons_du_fichier(chemin), error = function(e) conditionMessage(e))
  if (is.character(j)) {
    echec(paste0("fichier non analysable : ", gsub("[^ -~]", "?", j), " (caractere non ASCII hors commentaire ? M112)"), chemin)
    next
  }
  if (is.null(j)) next
  est_outils <- basename(chemin) == "outils.R"
  for (r in seq_len(nrow(j))) {
    texte <- j$texte[r]
    champ <- !is.na(j$prec[r]) && j$prec[r] %in% c("'$'", "'@'")
    appel <- j$token[r] == "SYMBOL_FUNCTION_CALL" && !champ
    # session$ et output$ : exemptes quand le nom est local (affecte ou argument formel de la
    # definition : `output <- list(); output$x <- 1`), refuses sinon ; input$ et input[[ toujours.
    if (j$token[r] == "SYMBOL" && texte %in% c("input", "session", "output") && !champ &&
        (texte == "input" || !j$local[r]) &&
        (identical(j$suiv[r], "'$'") || (texte == "input" && identical(j$suiv[r], "LBB")))) {
      echec(sprintf("Shiny dans le package : %s%s (ADR 0010, point 26)", texte,
                    if (identical(j$suiv[r], "LBB")) "[[" else "$"), chemin, j$ligne[r])
    }
    if (appel && grepl(APPELS_SHINY, texte)) {
      echec(sprintf("Shiny dans le package : %s() (ADR 0010, point 26)", texte), chemin, j$ligne[r])
    }
    if (j$token[r] == "SYMBOL_PACKAGE" && texte == "shiny") {
      echec("Shiny dans le package : shiny:: (ADR 0010, point 26)", chemin, j$ligne[r])
    }
    # Symboles non appeles (alias `s <- set.seed`, `lapply(x, print)`) : comptes comme des
    # appels, sauf variables locales ou arguments de leur definition, et champs `x$nom`.
    nu <- j$token[r] == "SYMBOL" && !champ && !j$local[r]
    if (!est_outils && ((appel && texte %in% APPELS_ALEA) || (nu && texte %in% APPELS_ALEA) ||
                        (j$token[r] == "SYMBOL" && !champ && texte == ".Random.seed") ||
                        (j$token[r] == "STR_CONST" && gsub("[\"']", "", texte) == ".Random.seed"))) {
      echec(sprintf("alea hors de R/outils.R : %s (ADR 0010, point 21 : seule voie, outils::avec_graine)",
                    gsub("[\"']", "", texte)), chemin, j$ligne[r])
    }
    # Sorties console et horloge (point 12). Les methodes print.* et format.* sont exemptees
    # des sorties ; l'horloge n'est admise nulle part (M402, M410).
    ecriture <- !is.na(j$ecriture[r]) && j$ecriture[r] == "console"
    bavard <- ((appel || nu) && texte %in% APPELS_BAVARDS) ||
      (appel && grepl("^print\\.", texte)) || ecriture || (nu && texte %in% ECRITURES)
    if (bavard) {
      en_print <- !is.na(j$def[r]) && grepl("^print\\.", j$def[r])
      en_format <- !is.na(j$def[r]) && grepl("^format\\.", j$def[r])
      forme <- if (appel) "()" else " (reference sans appel)"
      if (texte %in% HORLOGE) {
        if (en_print || en_format) {
          echec(sprintf("lecture de l'horloge dans une methode %s : %s%s ; le rendu doit etre reproductible (ADR 0010, point 12 ; M402, M410)",
                        if (en_format) "format.*" else "print.*", texte, forme), chemin, j$ligne[r])
        } else {
          echec(sprintf("le moteur ne parle pas et ne lit pas l'horloge : %s%s (ADR 0010, point 12)",
                        texte, forme), chemin, j$ligne[r])
        }
      } else if (!en_print && !en_format) {
        echec(sprintf("le moteur ne parle pas : %s%s%s hors d'une methode print.* ou format.* (ADR 0010, point 12)",
                      texte, forme, if (ecriture) " vers la console" else ""), chemin, j$ligne[r])
      }
    }
    if (j$non_ascii[r]) {
      echec(sprintf("caractere non ASCII dans le code (jeton %s) : ecrire \\uXXXX (M112)", j$token[r]),
            chemin, j$ligne[r])
    }
  }
}
if (.n_echec == avant) {
  ok(sprintf("R/ : %d fichier(s) sans Shiny, sans alea hors outils, sans sortie console ni date du systeme, code ASCII",
             length(fichiers)))
}

# --- app/ (facultatif) -------------------------------------------------------------------------
dossier_app <- file.path(racine, "app")
if (!dir.exists(dossier_app)) {
  ok("app/ absent : frontiere de l'application non verifiee (toleree avant la branche de l'application)")
} else {
  fichiers_app <- sort(list.files(dossier_app, pattern = "\\.R$", recursive = TRUE,
                                  full.names = TRUE, all.files = TRUE), method = "radix")
  avant <- .n_echec
  for (chemin in fichiers_app) {
    j <- tryCatch(jetons_du_fichier(chemin), error = function(e) conditionMessage(e))
    if (is.character(j)) {
      echec(paste0("fichier non analysable : ", gsub("[^ -~]", "?", j), " (caractere non ASCII hors commentaire ? M112)"), chemin)
      next
    }
    if (is.null(j)) next
    for (r in seq_len(nrow(j))) {
      champ <- !is.na(j$prec[r]) && j$prec[r] %in% c("'$'", "'@'")
      if (j$token[r] == "SYMBOL_PACKAGE" && j$texte[r] == "provie" && identical(j$suiv[r], "NS_GET_INT")) {
        echec("provie::: dans l'application : seules les fonctions exportees sont appelables", chemin, j$ligne[r])
      }
      if (j$token[r] == "SYMBOL_FUNCTION_CALL" && !champ && j$texte[r] %in% CALCULS_APP) {
        echec(sprintf("calcul dans l'application : %s() ; le calcul est dans le package, l'application formate", j$texte[r]),
              chemin, j$ligne[r])
      }
    }
  }
  if (.n_echec == avant) ok(sprintf("app/ : %d fichier(s) sans provie::: ni appel de calcul", length(fichiers_app)))
}

fin()
