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
VERSION_DICTIONNAIRE_ATTENDUE <- "1.5"           # ADR 0010, point 23 ; M117, M139, M146
REPRESENTATION_CANONIQUE <- "provie-resultat-1"  # ADR 0010, point 22
VERSION_LISTE <- 1L                              # format du serialiseur (ADR 0010, point 18)

# Liste fermée des motifs de refus d'appel (ADR 0010, point 11) ; fichier_invalide (M141) :
# refus de `lecture` qui tient au système de fichiers ou à la syntaxe d'un fichier ;
# jeu_invalide (ADR 0010, onzième série, (f)) : entrée de simuler_base() contraire à ses
# contrôles d'entrée ou à ses préconditions (argument qui ne définit pas un jeu simulé), ou
# objet passé à ecrire_jeu() qui n'a pas la forme d'un jeu_simule ou que lire_jeu() ne
# relirait pas identique.
MOTIFS_REFUS <- c(
  "plan_incomplet", "plan_invalide", "liste_invalide", "fichier_invalide", "table_base_absente",
  "colonne_absente", "colonne_inconnue", "type_incompatible", "extraction_invalide",
  "arrete_posterieur_extraction", "declaration_manquante", "table_absente",
  "empreinte_discordante", "version_discordante", "lien_non_declare",
  "catalogue_invalide", "dictionnaire_invalide", "format_table_inconnu", "jeu_invalide"
)

# --- Refus classés ---------------------------------------------------------------

# Lève un refus d'appel : condition classée c("refus_provie", "error", "condition"),
# interrompt l'appel sans rendre d'objet. `identifiants` est tronqué à dix éléments ;
# `nombre` est converti en entier (NA par défaut) : c'est à l'appelant d'y porter le total.
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
  # NA de tout type atomique accepté ; NaN, infini, non entier et hors bornes refusés
  nombre_na <- is.atomic(nombre) && length(nombre) == 1L && is.na(nombre) && !is.nan(nombre)
  if (!nombre_na && (!is.numeric(nombre) || length(nombre) != 1L || is.nan(nombre) ||
                     nombre != trunc(nombre) || abs(nombre) > .Machine$integer.max)) {
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
    # échoue sous warn = 2. Deux temps, pour que l'étouffement ne couvre que l'échantillonneur
    # (un avertissement du générateur de normales, « Buggy Kinderman-Ramage », qui s'y
    # ajouterait n'est pas étouffé). Même alors, .Random.seed de l'appelant est rétabli (finally).
    tryCatch({
      if (identical(anciens_genres[3L], "Rounding")) {
        suppressWarnings(RNGkind(sample.kind = anciens_genres[3L]))
      } else {
        RNGkind(sample.kind = anciens_genres[3L])
      }
      RNGkind(anciens_genres[1L], anciens_genres[2L])
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
  if (any(!fini & !is.na(x)) || any(is.nan(x)) || any(x[fini] != trunc(x[fini]))) {
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
      # une liste sans aucun attribut passe : l'absence de noms est refusee a l'appel suivant
      if (!is.null(attributes(el)) && !identical(names(attributes(el)), "names")) {
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
  # Les controles portent sur les noms decodes : deux ecritures d'un meme nom (a, \x61)
  # designent le meme noeud. Une cle de chemin prefixe chaque nom de sa longueur en octets :
  # un nom decode peut contenir « / » ou tout autre separateur.
  noms_chemins <- lapply(strsplit(chemins, "/", fixed = TRUE), function(s) {
    vapply(s, .desechapper, "", USE.NAMES = FALSE)
  })
  cle <- function(noms) paste(nchar(noms, "bytes"), noms, sep = ":", collapse = "|")
  cles <- vapply(noms_chemins, cle, "")
  ancetres <- unlist(lapply(noms_chemins, function(noms) {
    vapply(seq_len(length(noms) - 1L), function(j) cle(noms[seq_len(j)]), "")
  }))
  if (anyDuplicated(cles) || any(cles %in% ancetres)) {
    refuser("lire_liste() : chemins dupliqu\u00e9s ou feuille plac\u00e9e sous une autre feuille",
            "liste_invalide", module = "outils")
  }
  feuilles <- lapply(seq_along(champs), function(i) .lire_feuille(champs[[i]], chemins[i]))
  resultat <- if (length(feuilles) == 0L) list() else .assembler(noms_chemins, feuilles, 1L)
  # lecture stricte : tout texte non canonique est refuse (1.50, \xe9 pour un caractere
  # imprimable, ordre ou entrelacement des chemins...) ; on a donc toujours
  # ecrire_liste(lire_liste(octets)) == octets
  if (!identical(ecrire_liste(resultat), octets)) {
    refuser("lire_liste() : texte non canonique (r\u00e9\u00e9criture diff\u00e9rente de l'entr\u00e9e)",
            "liste_invalide", module = "outils")
  }
  resultat
}

# Assemble un niveau en une fois : les chemins (noms décodés) se regroupent par segment de
# rang `niveau`, dans l'ordre de première apparition, puis chaque groupe se construit
# récursivement. Temps proportionnel à (nombre de feuilles x profondeur) ; l'insertion
# feuille par feuille recopiait le noeud parent à chaque appel (temps quadratique, #25).
# Les contrôles amont garantissent qu'un segment désigne soit une feuille unique, soit un
# noeud ; l'ordre d'apparition et l'entrelacement non canoniques sont refusés par la
# réécriture de lire_liste().
.assembler <- function(noms, feuilles, niveau) {
  segments <- vapply(noms, function(s) s[niveau], "", USE.NAMES = FALSE)
  ordre <- unique(segments)
  groupes <- split(seq_along(noms), factor(segments, levels = ordre))
  res <- vector("list", length(ordre))
  for (k in seq_along(ordre)) {
    indices <- groupes[[k]]
    res[k] <- list(if (length(noms[[indices[1L]]]) == niveau) {
      feuilles[[indices[1L]]]
    } else {
      .assembler(noms[indices], feuilles[indices], niveau + 1L)
    })
  }
  names(res) <- ordre
  res
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
  # Sys.info() peut rendre NULL (documente par R) et extSoftVersion() peut omettre un
  # composant : un champ indisponible vaut NA_character_
  champ <- function(vecteur, nom) {
    if (is.character(vecteur) && nom %in% names(vecteur)) unname(vecteur[[nom]]) else NA_character_
  }
  list(
    r = R.version.string,
    plateforme = R.version$platform,
    systeme = champ(systeme, "sysname"),
    version_systeme = champ(systeme, "release"),
    machine = champ(systeme, "machine"),
    boutisme = .Platform$endian,
    blas = champ(logiciels, "BLAS"),
    lapack = La_library(),
    lapack_version = La_version(),
    pcre = champ(logiciels, "PCRE"),
    icu = champ(logiciels, "ICU")
  )
}

# --- Conventions d'âge -------------------------------------------------------------

# Liste fermée des conventions de lecture de l'âge (M154 ; spécification du module
# `donnees`, docs/specifications/module-donnees-v1.md, § 5.2). Le choix est une déclaration
# du plan (conventions$age), sans valeur par défaut ; `naissance_31_decembre` est une
# convention retenue par analogie (jugement d'expert), jamais présentée comme exigée par
# l'art. 143-3 du règlement ANC 2015-11.
CONVENTIONS_AGE <- c("revolu", "millesime", "plus_proche", "naissance_31_decembre")

# Âge entier, en années, de personnes nées à `date_naissance` à la date `date`, selon
# `convention` (un élément de CONVENTIONS_AGE ; refus plan_invalide sinon) :
#   revolu : nombre d'anniversaires atteints au plus tard à `date` ; né un 29 février,
#     l'anniversaire d'une année non bissextile est le 1er mars ;
#   millesime : année(date) - année(naissance) ;
#   plus_proche : revolu, plus 1 si l'anniversaire suivant est plus proche de `date` que le
#     précédent (en jours) ; à égalité, l'âge supérieur ;
#   naissance_31_decembre : revolu sur la naissance reportée au 31 décembre le plus voisin
#     (celui de l'année précédente si la naissance tombe au plus tard le 1er juillet, celui
#     de l'année de naissance sinon) ; entre la naissance et un 31 décembre reporté
#     postérieur, l'âge vaut 0 (la formule rendrait -1 : choix signalé à `actuary`).
# Vectorisée : `date_naissance` et `date` de même longueur, ou l'une de longueur 1. Rend un
# entier ; NA si une date manque ou si `date` précède la naissance.
calculer_age <- function(date_naissance, date, convention) {
  .controler_convention_age(convention, "calculer_age")
  .controler_dates_age(date_naissance, "date_naissance", "calculer_age")
  .controler_dates_age(date, "date", "calculer_age")
  n <- .longueur_commune(length(date_naissance), length(date), "calculer_age")
  naissance <- rep_len(as.numeric(date_naissance), n)
  jour <- rep_len(as.numeric(date), n)
  age <- rep(NA_integer_, n)
  ok <- !is.na(naissance) & !is.na(jour) & jour >= naissance
  if (!any(ok)) return(age)
  nai <- .composantes_date(naissance[ok])
  d <- .composantes_date(jour[ok])
  if (convention == "naissance_31_decembre") {
    report <- nai$annee - as.integer(nai$mois * 100L + nai$jour <= 701L)
    nai <- list(annee = report, mois = rep(12L, length(report)), jour = rep(31L, length(report)))
  }
  millesime <- d$annee - nai$annee
  revolu <- millesime - as.integer(d$mois * 100L + d$jour < nai$mois * 100L + nai$jour)
  res <- switch(convention,
    revolu = revolu,
    millesime = millesime,
    naissance_31_decembre = pmax(revolu, 0L),
    plus_proche = {
      precedent <- .anniversaire(nai, revolu)
      suivant <- .anniversaire(nai, revolu + 1L)
      revolu + as.integer(suivant - jour[ok] <= jour[ok] - precedent)
    })
  age[ok] <- as.integer(res)
  age
}

# Âge le plus élevé admis par date_atteinte_age() (borne de programmation : au-delà, refus par
# erreur, jamais un NA silencieux ; réserve m4).
AGE_MAXIMUM <- 200L

# Fonction inverse de calculer_age() : première date, au plus tôt la naissance, à laquelle
# l'âge selon `convention` vaut `age` (entier de 0 à AGE_MAXIMUM, ou NA ; au-delà : erreur) ; calculer_age(n, date_atteinte_age(n,
# a, c), c) vaut a. Vectorisée comme calculer_age() ; rend une Date (stockée en double),
# NA si la naissance ou l'âge manque.
date_atteinte_age <- function(date_naissance, age, convention) {
  .controler_convention_age(convention, "date_atteinte_age")
  .controler_dates_age(date_naissance, "date_naissance", "date_atteinte_age")
  if (is.logical(age) && all(is.na(age))) age <- as.integer(age)   # NA logique : âge manquant
  if (!is.numeric(age) || !is.null(dim(age)) ||
      any(!is.na(age) & (!is.finite(age) | age < 0 | age != trunc(age) | age > AGE_MAXIMUM))) {
    stop(paste0("date_atteinte_age() : `age` doit \u00eatre un vecteur d'entiers de 0 \u00e0 ", AGE_MAXIMUM,
                " (ou NA)"), call. = FALSE)
  }
  n <- .longueur_commune(length(date_naissance), length(age), "date_atteinte_age")
  naissance <- rep_len(as.numeric(date_naissance), n)
  a <- rep_len(as.integer(age), n)
  res <- rep(NA_real_, n)
  ok <- !is.na(naissance) & !is.na(a)
  if (any(ok)) {
    nai <- .composantes_date(naissance[ok])
    ak <- a[ok]
    jours <- switch(convention,
      revolu = .anniversaire(nai, ak),
      millesime = .jour_de(nai$annee + ak, 1L, 1L),
      naissance_31_decembre = {
        report <- nai$annee - as.integer(nai$mois * 100L + nai$jour <= 701L)
        # âge 0 dès la naissance (calculer_age() le borne à 0 avant le 31 décembre reporté)
        ifelse(ak == 0L, naissance[ok], .jour_de(report + ak, 12L, 31L))
      },
      plus_proche = {
        precedent <- .anniversaire(nai, pmax(ak - 1L, 0L))
        suivant <- .anniversaire(nai, ak)
        precedent + ceiling((suivant - precedent) / 2)
      })
    res[ok] <- pmax(jours, naissance[ok])
  }
  structure(res, class = "Date")
}

.controler_convention_age <- function(convention, fonction) {
  if (!is.character(convention) || length(convention) != 1L || is.na(convention) ||
      !(convention %in% CONVENTIONS_AGE)) {
    refuser(paste0(fonction, "() : convention d'\u00e2ge hors de la liste ferm\u00e9e (",
                   paste(CONVENTIONS_AGE, collapse = ", "), ")"),
            "plan_invalide", module = "outils",
            recu = if (is.character(convention) && length(convention) == 1L) convention else NA_character_)
  }
  invisible(NULL)
}

.controler_dates_age <- function(x, nom, fonction) {
  if (!identical(class(x), "Date") || !is.null(dim(x))) {
    stop(paste0(fonction, "() : `", nom, "` doit \u00eatre un vecteur de classe Date"), call. = FALSE)
  }
  v <- as.numeric(x)
  if (any(!is.na(v) & (!is.finite(v) | v != trunc(v)))) {
    stop(paste0(fonction, "() : `", nom, "` doit porter des dates enti\u00e8res et finies"), call. = FALSE)
  }
  invisible(NULL)
}

.longueur_commune <- function(n1, n2, fonction) {
  if (n1 == n2 || n2 == 1L) return(n1)
  if (n1 == 1L) return(n2)
  stop(paste0(fonction, "() : longueurs incompatibles (", n1, " et ", n2, ")"), call. = FALSE)
}

# Année, mois, jour (entiers) de dates données en nombre de jours depuis 1970-01-01.
.composantes_date <- function(jours) {
  lt <- as.POSIXlt(structure(jours, class = "Date"))
  list(annee = lt$year + 1900L, mois = lt$mon + 1L, jour = lt$mday)
}

# Nombre de jours (depuis 1970-01-01) de la date annee-mois-jour ; un quantième absent du
# mois (29 février d'une année non bissextile, 31 d'un mois de trente jours) est lu premier
# jour du mois suivant. Seule arithmétique de quantième du package (ajouter_mois(),
# anniversaires de date_atteinte_age()).
.jour_de <- function(annee, mois, jour) {
  n <- max(length(annee), length(mois), length(jour))
  annee <- rep_len(as.integer(annee), n)
  mois <- rep_len(as.integer(mois), n)
  jour <- rep_len(as.integer(jour), n)
  premier <- .jour_premier_janvier(annee) + .CUMUL_MOIS[mois] + (mois > 2L & .bissextile(annee))
  longueur <- .JOURS_MOIS[mois] + (mois == 2L & .bissextile(annee))
  ifelse(jour > longueur, premier + longueur, premier + jour - 1)
}

# Calendrier grégorien proleptique, par arithmétique sur les entiers (sans chaîne ni
# as.Date ; constat D de l'audit de #66) : longueur des mois d'une année commune, jours
# écoulés avant chaque mois, année bissextile.
.JOURS_MOIS <- c(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
.CUMUL_MOIS <- c(0, cumsum(.JOURS_MOIS)[-12L])
.bissextile <- function(annee) (annee %% 4L == 0L & annee %% 100L != 0L) | annee %% 400L == 0L

# Nombre de jours depuis 1970-01-01 du 1er janvier de `annee` (entiers, vectorisé ; NA pour
# NA), par décompte des années bissextiles.
.jour_premier_janvier <- function(annee) {
  y <- as.integer(annee) - 1L
  bis <- function(x) x %/% 4L - x %/% 100L + x %/% 400L
  as.numeric(365 * (y - 1969L) + bis(y) - bis(1969L))
}

# Date `k` mois après `d` (Date ou nombre de jours depuis 1970-01-01 ; vectorisé, `d` et `k`
# de même longueur ou l'un de longueur 1 ; `k` entier, négatif pour reculer) : même quantième,
# un quantième absent du mois visé donnant le premier jour du mois suivant (.jour_de(), comme
# l'anniversaire d'un 29 février de date_atteinte_age()). Rend des nombres de jours. Sans
# point : lue par `engagement` (critère sans_evenement ; 1er janvier des années civiles du
# découpage des durées, ajouter_mois(0, 12 (y - 1970))) et `risque_en_cours` (pas, échéances,
# anniversaires) ; non exportée.
ajouter_mois <- function(d, k) {
  n <- .longueur_commune(length(d), length(k), "ajouter_mois")
  c0 <- .composantes_date(rep_len(as.numeric(d), n))
  m <- c0$annee * 12L + c0$mois - 1L + rep_len(as.integer(k), n)
  .jour_de(m %/% 12L, m %% 12L + 1L, c0$jour)
}

# Anniversaire d'ordre `age` d'une naissance (composantes) : en nombre de jours.
.anniversaire <- function(nai, age) .jour_de(nai$annee + age, nai$mois, nai$jour)
