# Module `outils` : services sans contenu métier (ADR 0010, point 1) -- refus classés,
# graine locale, empreinte, écriture canonique des valeurs, sérialisation d'une liste
# nommée en texte aplati lu sans évaluation, plateforme, constantes.
# N'appelle aucun autre module de provie. Le moteur ne parle pas (ADR 0010, point 12) :
# ni avertissement, ni message, ni sortie console, ni date du système.
# Code ASCII hors commentaires : les accents des chaines s'ecrivent en \uXXXX (une chaine
# litterale non ASCII installee sous une locale C donne des avertissements de traduction
# a l'execution sous une locale UTF-8 ; mesure du 7 novembre 2026, R 4.3.3).
# Convention de ce fichier : une fonction dont le nom commence par un point est un
# auxiliaire du module ; la concordance documentation <-> code ne recense que les autres.

# --- Constantes ------------------------------------------------------------------

VERSION_FICHE <- 1L                              # ADR 0007, point 3
VERSION_DICTIONNAIRE_ATTENDUE <- "1.3"           # ADR 0010, point 23 ; M97, M103
REPRESENTATION_CANONIQUE <- "provie-resultat-1"  # ADR 0010, point 22
VERSION_LISTE <- 1L                              # format du serialiseur (ADR 0010, point 18)

# Liste fermée des motifs de refus d'appel (ADR 0010, point 11).
MOTIFS_REFUS <- c(
  "plan_incomplet", "plan_invalide", "liste_invalide", "table_base_absente",
  "colonne_absente", "colonne_inconnue", "type_incompatible", "extraction_invalide",
  "arrete_posterieur_extraction", "declaration_manquante", "table_absente",
  "empreinte_discordante", "version_discordante", "lien_non_declare",
  "catalogue_invalide", "dictionnaire_invalide", "format_table_inconnu"
)

# --- Refus classés ---------------------------------------------------------------

# Lève un refus d'appel : condition classée c("refus_provie", "error", "condition"),
# interrompt l'appel sans rendre d'objet. `identifiants` est tronqué à dix éléments ;
# `nombre` est repris tel quel (NA par défaut) : c'est à l'appelant d'y porter le total.
refuser <- function(message, motif, module = NA_character_, table = NA_character_,
                    colonne = NA_character_, usage = NA_character_,
                    nombre = NA_integer_, identifiants = character(0),
                    attendu = NA_character_, recu = NA_character_) {
  if (!is.character(message) || length(message) != 1L || is.na(message)) {
    stop("refuser() : `message` doit \u00eatre une cha\u00eene unique", call. = FALSE)
  }
  if (!is.character(motif) || length(motif) != 1L || !(motif %in% MOTIFS_REFUS)) {
    stop("refuser() : `motif` hors de la liste ferm\u00e9e MOTIFS_REFUS", call. = FALSE)
  }
  for (champ in list(module, table, colonne, usage)) {
    if (!is.character(champ) || length(champ) != 1L) {
      stop("refuser() : `module`, `table`, `colonne` et `usage` doivent \u00eatre des cha\u00eenes uniques",
           call. = FALSE)
    }
  }
  if (!is.numeric(nombre) || length(nombre) != 1L ||
      (!is.na(nombre) && (nombre != trunc(nombre) || abs(nombre) > .Machine$integer.max))) {
    stop("refuser() : `nombre` doit \u00eatre un entier unique (ou NA)", call. = FALSE)
  }
  if (!is.atomic(attendu) || length(attendu) != 1L || !is.atomic(recu) || length(recu) != 1L) {
    stop("refuser() : `attendu` et `recu` doivent \u00eatre des valeurs atomiques uniques",
         call. = FALSE)
  }
  if (!is.atomic(identifiants)) {
    stop("refuser() : `identifiants` doit \u00eatre un vecteur atomique", call. = FALSE)
  }
  identifiants <- as.character(identifiants)
  if (length(identifiants) > 10L) identifiants <- identifiants[seq_len(10L)]
  condition <- structure(
    class = c("refus_provie", "error", "condition"),
    list(message = message, call = NULL, motif = motif, module = module,
         table = table, colonne = colonne, usage = usage,
         nombre = as.integer(nombre), identifiants = identifiants,
         attendu = attendu, recu = recu)
  )
  stop(condition)
}

# --- Graine locale ---------------------------------------------------------------

# Évalue `expr` sous un générateur fixé (Mersenne-Twister, Inversion, Rejection) et la
# graine donnée, puis restaure l'état global (.Random.seed et genres), même en erreur.
# Seule voie vers l'aléa dans R/ (ADR 0010, point 21).
avec_graine <- function(graine, expr) {
  if (!is.numeric(graine) || length(graine) != 1L || !is.finite(graine) ||
      graine != trunc(graine) || abs(graine) > .Machine$integer.max) {
    stop("avec_graine() : `graine` doit \u00eatre un entier fini", call. = FALSE)
  }
  global <- globalenv()
  avait_graine <- exists(".Random.seed", envir = global, inherits = FALSE)
  ancienne_graine <- if (avait_graine) global[[".Random.seed"]] else NULL
  anciens_genres <- RNGkind()
  on.exit({
    # Le rétablissement d'un échantillonneur « Rounding » (celui de l'appelant) émet un
    # avertissement de R, qui n'a pas à sortir d'une restauration : lui seul est étouffé
    # (décision du mainteneur du 7 novembre 2026) ; tout autre avertissement remonte, donc
    # échoue sous warn = 2. Même alors, .Random.seed de l'appelant est rétabli (finally).
    tryCatch({
      if (identical(anciens_genres[3L], "Rounding")) {
        suppressWarnings(RNGkind(anciens_genres[1L], anciens_genres[2L], anciens_genres[3L]))
      } else {
        RNGkind(anciens_genres[1L], anciens_genres[2L], anciens_genres[3L])
      }
    }, finally = {
      if (avait_graine) {
        assign(".Random.seed", ancienne_graine, envir = global)
      } else if (exists(".Random.seed", envir = global, inherits = FALSE)) {
        rm(list = ".Random.seed", envir = global)
      }
    })
  }, add = TRUE)
  RNGkind("Mersenne-Twister", "Inversion", "Rejection")
  set.seed(as.integer(graine))
  expr
}

# --- Empreinte -------------------------------------------------------------------

# MD5 d'un vecteur d'octets, par tools::md5sum() sur un fichier temporaire (R 4.3.3
# n'offre pas le MD5 d'un vecteur raw). Rend 32 caractères hexadécimaux minuscules.
empreinte <- function(octets) {
  if (!is.raw(octets)) stop("empreinte() : `octets` doit \u00eatre un vecteur raw", call. = FALSE)
  chemin <- tempfile(pattern = "provie-empreinte-")
  on.exit(unlink(chemin), add = TRUE)
  writeBin(octets, chemin)
  unname(as.character(tools::md5sum(chemin)))
}

# --- Écriture canonique des valeurs ----------------------------------------------

# Écrit un vecteur atomique simple (logical, integer, double, character, Date) sous sa
# forme canonique (ADR 0007, point 5 ; ADR 0010, point 22).
#   forme "texte"  : un élément de chaîne par valeur -- logical T / F / NA ; integer %d ;
#                    double %.17g (NA, NaN, Inf, -Inf en jetons ; -0 écrit 0) ; Date ISO
#                    8601 sur quatre chiffres ; character échappé (voir .echapper), NA
#                    écrit \N.
#   forme "octets" : vecteur raw, sans étiquette de type -- logical un octet (0, 1, 2 pour
#                    NA) ; integer quatre octets petit-boutistes ; double huit octets
#                    IEEE 754 petit-boutistes, NA et NaN sur deux motifs fixes, -0 écrit 0 ;
#                    character longueur en octets UTF-8 (quatre octets, 0xFFFFFFFF pour NA)
#                    puis octets UTF-8 ; Date comme la chaîne ISO.
ecrire_valeurs <- function(x, forme = "texte") {
  if (!is.character(forme) || length(forme) != 1L || !(forme %in% c("texte", "octets"))) {
    stop("ecrire_valeurs() : `forme` doit valoir \"texte\" ou \"octets\"", call. = FALSE)
  }
  if (inherits(x, "Date")) {
    iso <- .dates_vers_iso(x)
    if (forme == "texte") {
      iso[is.na(iso)] <- "NA"
      return(iso)
    }
    x <- iso
  }
  if (!is.null(attributes(x)) || !(is.logical(x) || is.integer(x) || is.double(x) ||
                                   is.character(x))) {
    refuser("ecrire_valeurs() : seuls les vecteurs atomiques simples (logical, integer, double, character, Date) s'\u00e9crivent",
            "liste_invalide", module = "outils")
  }
  if (forme == "texte") return(.valeurs_texte(x))
  .valeurs_octets(x)
}

.valeurs_texte <- function(x) {
  if (is.logical(x)) {
    res <- c("F", "T")[as.integer(x) + 1L]
    res[is.na(x)] <- "NA"
    return(res)
  }
  if (is.integer(x)) return(sprintf("%d", x))
  if (is.double(x)) {
    x[which(x == 0)] <- 0   # -0 s'ecrit comme 0
    return(sprintf("%.17g", x))
  }
  .echapper(x)
}

.valeurs_octets <- function(x) {
  if (is.logical(x)) {
    codes <- as.integer(x)
    codes[is.na(x)] <- 2L
    return(as.raw(codes))
  }
  if (is.integer(x)) return(writeBin(x, raw(), size = 4L, endian = "little"))
  if (is.double(x)) {
    x[which(x == 0)] <- 0
    octets <- matrix(writeBin(replace(x, is.na(x), 0), raw(), size = 8L, endian = "little"),
                     nrow = 8L)
    # NaN : 0x7ff8000000000000 ; NA : 0x7ff00000000007a2 (petit-boutiste)
    octets[, which(is.nan(x))] <- as.raw(c(0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xf8, 0x7f))
    octets[, which(is.na(x) & !is.nan(x))] <-
      as.raw(c(0xa2, 0x07, 0x00, 0x00, 0x00, 0x00, 0xf0, 0x7f))
    return(as.vector(octets))
  }
  x <- .vers_utf8(x, "valeur")
  morceaux <- lapply(seq_along(x), function(i) {
    if (is.na(x[i])) return(writeBin(-1L, raw(), size = 4L, endian = "little"))
    brut <- charToRaw(x[i])
    c(writeBin(length(brut), raw(), size = 4L, endian = "little"), brut)
  })
  as.raw(unlist(morceaux))
}

.dates_vers_iso <- function(x) {
  if (!identical(attributes(x), list(class = "Date")) || !is.double(x)) {
    refuser("ecrire_valeurs() : une Date doit \u00eatre un double portant le seul attribut de classe",
            "liste_invalide", module = "outils")
  }
  fini <- is.finite(x)
  if (any(!fini & !is.na(x)) || any(x[fini] != trunc(x[fini]))) {
    refuser("ecrire_valeurs() : une Date doit \u00eatre finie et enti\u00e8re (jours)",
            "liste_invalide", module = "outils")
  }
  # l'annee est completee a quatre chiffres : format() rend 999 pour l'an 999
  iso <- rep(NA_character_, length(x))
  iso[!is.na(x)] <- sprintf("%04d-%s", as.integer(format(x[!is.na(x)], "%Y")),
                            format(x[!is.na(x)], "%m-%d"))
  if (any(!is.na(iso) & !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", iso))) {
    refuser("ecrire_valeurs() : une Date doit tenir sur quatre chiffres d'ann\u00e9e",
            "liste_invalide", module = "outils")
  }
  iso
}

# Rend les chaines de `x` en UTF-8, ou refuse (liste_invalide), sans jamais corriger :
#   - ASCII : telle quelle ;
#   - marquee UTF-8 : validee ; marquee latin1 : traduite ;
#   - marquee "bytes" : refusee ;
#   - non marquee et non ASCII : refusee si la locale native n'est pas UTF-8 (R ne sait
#     pas dire quel est son encodage ; enc2utf8() ecrirait alors <c3><a9> a la place des
#     octets, mesure du 7 novembre 2026, R 4.3.3) ; sinon validee comme UTF-8.
.vers_utf8 <- function(x, quoi) {
  refus <- function(raison) {
    refuser(paste0("cha\u00eene de ", quoi, " : ", raison), "liste_invalide", module = "outils")
  }
  vivantes <- which(!is.na(x))
  non_ascii <- vivantes[!grepl("^[\\x01-\\x7f]*$", x[vivantes], perl = TRUE, useBytes = TRUE)]
  if (length(non_ascii) == 0L) return(x)
  marque <- Encoding(x)[non_ascii]
  if (any(marque == "bytes")) refus("encodage \u00ab bytes \u00bb non admis")
  if (any(marque == "unknown") && !isTRUE(l10n_info()[["UTF-8"]])) {
    refus("cha\u00eene non ASCII sans encodage d\u00e9clar\u00e9 sous une locale non UTF-8 (marquer la cha\u00eene en UTF-8)")
  }
  a_traduire <- non_ascii[marque == "latin1"]
  if (length(a_traduire) > 0L) x[a_traduire] <- enc2utf8(x[a_traduire])
  if (!all(validUTF8(x[non_ascii]))) refus("UTF-8 invalide")
  marques <- Encoding(x)
  marques[non_ascii] <- "UTF-8"
  Encoding(x) <- marques
  x
}

# Échappe des chaînes : barre oblique inverse (\\), tabulation (\t), saut de ligne (\n),
# retour chariot (\r), autres caractères de contrôle et DEL (\xNN), plus les codes de
# `codes_extra` ; NA devient \N. Le reste est écrit en UTF-8 tel quel.
.echapper <- function(x, codes_extra = integer(0)) {
  x <- .vers_utf8(x, "texte")
  res <- vapply(seq_along(x), function(i) {
    s <- x[i]
    if (is.na(s)) return("\\N")
    codes <- utf8ToInt(s)
    speciaux <- codes < 32L | codes == 127L | codes == 92L | codes %in% codes_extra
    if (!any(speciaux)) return(s)
    caracteres <- intToUtf8(codes, multiple = TRUE)
    caracteres[speciaux] <- vapply(codes[speciaux], .echappement_code, "")
    paste(caracteres, collapse = "")
  }, "")
  Encoding(res) <- "UTF-8"
  res
}

.echappement_code <- function(k) {
  if (k == 92L) return("\\\\")
  if (k == 9L) return("\\t")
  if (k == 10L) return("\\n")
  if (k == 13L) return("\\r")
  sprintf("\\x%02x", k)
}

# Inverse de .echapper pour une chaîne (le jeton \N est traité par l'appelant).
.desechapper <- function(s) {
  if (!grepl("\\", s, fixed = TRUE)) return(s)
  position <- gregexpr("\\\\(?:x[0-9a-f]{2}|[\\\\tnr])", s, perl = TRUE)
  entre <- regmatches(s, position, invert = TRUE)[[1L]]
  if (any(grepl("\\", entre, fixed = TRUE))) {
    refuser(paste0("liste : s\u00e9quence d'\u00e9chappement inconnue dans \u00ab ", s, " \u00bb"),
            "liste_invalide", module = "outils")
  }
  jetons <- regmatches(s, position)[[1L]]
  valeurs <- vapply(jetons, function(j) {
    if (j == "\\\\") return("\\")
    if (j == "\\t") return("\t")
    if (j == "\\n") return("\n")
    if (j == "\\r") return("\r")
    k <- strtoi(substr(j, 3L, 4L), 16L)
    if (k == 0L) {
      refuser("liste : l'octet nul ne s'\u00e9crit pas", "liste_invalide", module = "outils")
    }
    intToUtf8(k)
  }, "", USE.NAMES = FALSE)
  res <- paste(c(rbind(entre, c(valeurs, ""))), collapse = "")
  Encoding(res) <- "UTF-8"
  res
}

# --- Sérialisation d'une liste nommée --------------------------------------------

# Format (version VERSION_LISTE) : texte UTF-8, fins de ligne \n, terminé par un \n.
#   ligne 1 : « provie-liste 1 »
#   ensuite, une ligne par feuille, champs séparés par une tabulation :
#     chemin  type  valeur...
#   chemin : noms des ancêtres et de la feuille, échappés (.echapper, avec « / »), joints
#            par « / » ; type : null, liste (liste vide), logical, integer, double,
#            character, date ; une valeur par élément (aucune pour un vecteur vide).
# Lecture stricte : seul le texte canonique est accepté.
# Une feuille est NULL, une liste vide ou un vecteur atomique simple. Les noms d'une liste
# sont tous renseignés et distincts ; aucun autre attribut n'est admis.

# Écrit une liste nommée en octets (raw) ; le fichier est écrit par l'appelant.
ecrire_liste <- function(x) {
  if (!is.list(x) || !is.null(attributes(x)) && !identical(names(attributes(x)), "names")) {
    refuser("ecrire_liste() : l'argument doit \u00eatre une liste nomm\u00e9e sans autre attribut",
            "liste_invalide", module = "outils")
  }
  if (length(x) == 0L && !is.null(attributes(x))) {
    refuser("ecrire_liste() : une liste vide ne porte aucun attribut (ni names)", "liste_invalide",
            module = "outils")
  }
  lignes <- if (length(x) == 0L) character(0) else .lignes_noeud(x, "", "")
  texte <- paste0(paste(c(paste("provie-liste", VERSION_LISTE), lignes), collapse = "\n"), "\n")
  Encoding(texte) <- "UTF-8"
  charToRaw(texte)
}

.lignes_noeud <- function(x, prefixe, ou) {
  noms <- names(x)
  if (is.null(noms) || anyNA(noms) || any(!nzchar(noms)) || anyDuplicated(noms)) {
    refuser(paste0("ecrire_liste() : les \u00e9l\u00e9ments de la liste \u00ab ", ou,
                   " \u00bb doivent avoir des noms renseign\u00e9s et distincts"),
            "liste_invalide", module = "outils")
  }
  segments <- .echapper(noms, codes_extra = 47L)
  chemins <- if (nzchar(prefixe)) paste0(prefixe, "/", segments) else segments
  unlist(lapply(seq_along(x), function(i) {
    el <- x[[i]]
    if (is.list(el) && length(el) > 0L) {
      if (!identical(names(attributes(el)), "names")) {
        refuser(paste0("ecrire_liste() : attributs non admis en \u00ab ", chemins[i], " \u00bb"),
                "liste_invalide", module = "outils")
      }
      return(.lignes_noeud(el, chemins[i], chemins[i]))
    }
    .ligne_feuille(el, chemins[i])
  }), use.names = FALSE)
}

.ligne_feuille <- function(el, chemin) {
  if (is.null(el)) return(paste(chemin, "null", sep = "\t"))
  if (is.list(el)) {
    if (length(el) > 0L || !is.null(attributes(el))) {
      refuser(paste0("ecrire_liste() : liste vide attendue en \u00ab ", chemin, " \u00bb"),
              "liste_invalide", module = "outils")
    }
    return(paste(chemin, "liste", sep = "\t"))
  }
  type <- if (inherits(el, "Date")) "date" else if (is.logical(el)) "logical" else
    if (is.integer(el)) "integer" else if (is.double(el)) "double" else
    if (is.character(el)) "character" else NA_character_
  if (is.na(type)) {
    refuser(paste0("ecrire_liste() : type non admis en \u00ab ", chemin, " \u00bb"),
            "liste_invalide", module = "outils")
  }
  # ecrire_valeurs() refuse tout attribut autre que la classe d'une Date
  valeurs <- ecrire_valeurs(el, "texte")
  paste(c(chemin, type, valeurs), collapse = "\t")
}

# Relit des octets écrits par ecrire_liste(), sans évaluation de code ; aller-retour
# `identical`. Refuse (liste_invalide, version_discordante) tout ce qui n'a pas la forme.
lire_liste <- function(octets) {
  if (!is.raw(octets)) {
    refuser("lire_liste() : l'argument doit \u00eatre un vecteur raw", "liste_invalide",
            module = "outils")
  }
  if (any(octets == as.raw(0L))) {
    refuser("lire_liste() : octet nul dans le contenu", "liste_invalide", module = "outils")
  }
  texte <- rawToChar(octets)
  Encoding(texte) <- "UTF-8"
  if (!validUTF8(texte)) {
    refuser("lire_liste() : contenu non UTF-8", "liste_invalide", module = "outils")
  }
  if (!grepl("\n$", texte)) {
    refuser("lire_liste() : contenu tronqu\u00e9 (pas de fin de ligne finale)", "liste_invalide",
            module = "outils")
  }
  lignes <- strsplit(paste0(sub("\n$", "", texte), "\n"), "\n", fixed = TRUE)[[1L]]
  entete <- lignes[1L]
  if (!identical(entete, paste("provie-liste", VERSION_LISTE))) {
    if (grepl("^provie-liste [0-9]+$", entete)) {
      refuser("lire_liste() : version du format de liste non prise en charge",
              "version_discordante", module = "outils",
              attendu = as.character(VERSION_LISTE), recu = sub("^provie-liste ", "", entete))
    }
    refuser("lire_liste() : en-t\u00eate \u00ab provie-liste \u00bb absent", "liste_invalide", module = "outils")
  }
  lignes <- lignes[-1L]
  champs <- lapply(lignes, function(l) strsplit(paste0(l, "\t"), "\t", fixed = TRUE)[[1L]])
  if (any(lengths(champs) < 2L) || any(vapply(champs, function(f) !nzchar(f[1L]), NA))) {
    refuser("lire_liste() : ligne sans chemin ou sans type", "liste_invalide", module = "outils")
  }
  chemins <- vapply(champs, function(f) f[1L], "")
  if (!all(grepl("^[^/]+(/[^/]+)*$", chemins))) {
    refuser("lire_liste() : chemin mal form\u00e9", "liste_invalide", module = "outils")
  }
  segments <- strsplit(chemins, "/", fixed = TRUE)
  ancetres <- unlist(lapply(segments, function(s) {
    vapply(seq_len(length(s) - 1L), function(j) paste(s[seq_len(j)], collapse = "/"), "")
  }))
  if (anyDuplicated(chemins) || any(chemins %in% ancetres)) {
    refuser("lire_liste() : chemins dupliqu\u00e9s ou feuille plac\u00e9e sous une autre feuille",
            "liste_invalide", module = "outils")
  }
  resultat <- list()
  for (i in seq_along(champs)) {
    noms <- vapply(segments[[i]], .desechapper, "", USE.NAMES = FALSE)
    resultat <- .inserer(resultat, noms, .lire_feuille(champs[[i]], chemins[i]))
  }
  # lecture stricte : tout texte non canonique est refuse (1.50, \xe9 pour un caractere
  # imprimable, ordre ou entrelacement des chemins...) ; on a donc toujours
  # ecrire_liste(lire_liste(octets)) == octets
  if (!identical(ecrire_liste(resultat), octets)) {
    refuser("lire_liste() : texte non canonique (r\u00e9\u00e9criture diff\u00e9rente de l'entr\u00e9e)",
            "liste_invalide", module = "outils")
  }
  resultat
}

.inserer <- function(noeud, noms, valeur) {
  nom <- noms[1L]
  if (length(noms) == 1L) {
    noeud[nom] <- list(valeur)
    return(noeud)
  }
  enfant <- if (nom %in% names(noeud)) noeud[[nom]] else list()
  noeud[nom] <- list(.inserer(enfant, noms[-1L], valeur))
  noeud
}

.lire_feuille <- function(f, chemin) {
  type <- f[2L]
  valeurs <- f[-(1:2)]
  mal_forme <- function(raison) {
    refuser(paste0("lire_liste() : ", raison, " en \u00ab ", chemin, " \u00bb"), "liste_invalide",
            module = "outils")
  }
  if (type == "null" || type == "liste") {
    if (length(valeurs) > 0L) mal_forme("valeur inattendue")
    return(if (type == "null") NULL else list())
  }
  if (type == "logical") {
    if (!all(valeurs %in% c("T", "F", "NA"))) mal_forme("jeton logique inconnu")
    res <- valeurs == "T"
    res[valeurs == "NA"] <- NA
    return(res)
  }
  if (type == "integer") {
    if (!all(valeurs == "NA" | grepl("^-?[0-9]+$", valeurs))) mal_forme("entier mal form\u00e9")
    nombres <- as.numeric(replace(valeurs, valeurs == "NA", NA_character_))
    if (any(!is.na(nombres) & abs(nombres) > .Machine$integer.max)) {
      mal_forme("entier hors des bornes")
    }
    return(as.integer(nombres))
  }
  if (type == "double") {
    if (!all(valeurs %in% c("NA", "NaN", "Inf", "-Inf") |
             grepl("^-?[0-9]+(\\.[0-9]+)?(e[+-][0-9]+)?$", valeurs))) {
      mal_forme("r\u00e9el mal form\u00e9")
    }
    return(as.numeric(replace(valeurs, valeurs == "NA", NA_character_)))
  }
  if (type == "character") {
    res <- vapply(valeurs, function(v) if (identical(v, "\\N")) NA_character_ else .desechapper(v),
                  "", USE.NAMES = FALSE)
    return(res)
  }
  if (type == "date") {
    if (!all(valeurs == "NA" | grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", valeurs))) {
      mal_forme("date mal form\u00e9e")
    }
    texte_iso <- valeurs
    texte_iso[valeurs == "NA"] <- NA_character_
    jours <- as.Date(texte_iso, format = "%Y-%m-%d")
    if (any(is.na(jours) != (valeurs == "NA"))) mal_forme("date inexistante")
    return(jours)
  }
  mal_forme("type inconnu")
}

# --- Plateforme ------------------------------------------------------------------

# Description de la plateforme d'exécution, pour la fiche de calcul : liste nommée de
# chaînes, sérialisable par ecrire_liste(). Aucune date, aucun nom d'utilisateur.
decrire_plateforme <- function() {
  logiciels <- extSoftVersion()
  systeme <- Sys.info()
  list(
    r = R.version.string,
    plateforme = R.version$platform,
    systeme = unname(systeme[["sysname"]]),
    version_systeme = unname(systeme[["release"]]),
    machine = unname(systeme[["machine"]]),
    boutisme = .Platform$endian,
    blas = unname(logiciels[["BLAS"]]),
    lapack = La_library(),
    lapack_version = La_version(),
    pcre = unname(logiciels[["PCRE"]]),
    icu = unname(logiciels[["ICU"]])
  )
}
