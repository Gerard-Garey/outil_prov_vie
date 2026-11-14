#!/usr/bin/env bash
# Contrôle : couloirs des branches parallèles (ADR 0012, points 5, 6, 9 et 23 ; #94 ; forme du
# couloir : docs/feuille-de-route.md, § 1.12, « Forme du couloir pour #94 », M359). Tourne dans
# le job « Contrôles du dépôt » de la CI (historique complet, sans R), hors de la batterie
# unitaire (git peut manquer dans l'image du job « Tests (R 4.3.3) »).
#
# Le couloir d'une branche est un bloc de code délimité de sa fiche (docs/feuille-de-route.md),
# dont la chaîne d'information est « couloir <nom de la branche> ». Lignes du bloc :
#   + <motif>              fichiers inclus
#   - <motif>              fichiers exclus (prime sur « + »)
#   = <chemin> : <Mnnn>    point de contact (ADR 0012, point 5) : fichier exact et décision M ;
#                          doit figurer dans les deux fiches
#   # ...                  commentaire ; ligne vide admise ; toute autre ligne : [ECHEC] de forme
# Motifs : chemins relatifs à la racine ; « * » = tout caractère sauf « / » ; « ** » = tout
# caractère, « / » compris ; un motif terminé par « / » vaut tout le sous-arbre ; aucune autre
# syntaxe (un motif qui en emploie une est une erreur de forme). Un fichier est admis s'il
# est dans le couloir (un « + » et aucun « - »), ou s'il est un recouvrement maîtrisé
# (constante RECOUVREMENTS_MAITRISES), ou s'il est un point de contact déclaré.
#
# Usage, depuis la racine du dépôt :
#   bash tests/controles/couloir.sh                       mode couloir, branche courante
#   bash tests/controles/couloir.sh --autre=<branche>     mode intersection (local, avant push)
#   bash tests/controles/couloir.sh --temoins             témoins négatifs, sans git
# Options : --branche=<nom> (branche courante ; à défaut GITHUB_HEAD_REF, puis
# `git rev-parse --abbrev-ref HEAD`), --base=<réf> (défaut origin/main), --fiche=<chemin>
# (défaut docs/feuille-de-route.md).
#   Mode couloir : `git diff --name-only --no-renames <base>...HEAD` ; échec pour tout fichier
#     hors couloir, hors recouvrements maîtrisés et hors points de contact. Une branche sans bloc
#     (branche unique, dont Bo2 ; branche détachée ou main) : [INFO] et statut 0.
#   Mode intersection : fichiers touchés par les deux branches (HEAD et origin/<autre>, chacune
#     contre <base>) ; échec si l'intersection contient autre chose que des recouvrements
#     maîtrisés ou des points de contact déclarés dans les deux fiches (remplace les deux
#     commandes de l'ADR 0012, point 23). Seul le mode couloir tourne sur la CI : l'intersection
#     dépend de l'état de l'autre branche au moment du push, que seule la session connaît.
# Sortie : lignes [OK] / [ECHEC] / [INFO] ; statut 0 (conforme), 1 (au moins un [ECHEC]),
# 2 (usage, fiche ou git illisible).
#
# Limites écrites :
#   - un recouvrement maîtrisé est admis au niveau du fichier : pour DESCRIPTION, le script ne
#     vérifie pas que seule la version change ; pour NAMESPACE et README.md, il ne vérifie pas
#     « ajouts seulement » ; pour la feuille de route, il ne vérifie pas que la branche n'écrit
#     que sa fiche et son bloc M (point 12) ;
#   - un point de contact est admis par son chemin : le script ne lit ni les lignes concernées
#     ni la décision M citée (« branche qui écrit en premier ») ;
#   - le script signale une sortie de couloir, il ne la tranche pas (point 9) ;
#   - les fiches des deux branches sont lues dans le fichier de la branche courante ; une fiche
#     de l'autre branche plus récente que ce fichier n'est pas vue ;
#   - l'intersection est un contrôle local avant push (motif : ci-dessus), pas un contrôle de CI ;
#   - une coquille dans la chaîne d'information (« couloirs <branche> », « couloir<branche> ») ne
#     fait pas un couloir : le bloc n'est pas lu, la branche est vue sans bloc ([INFO], statut 0) ;
#   - un chemin qui porte un guillemet, une barre oblique inverse ou un caractère de contrôle
#     est cité par git même avec core.quotePath=false : il ne correspond à aucun motif ;
#   - un bloc malformé n'est signalé que pour la branche contrôlée (et l'autre en mode
#     intersection), et toute chaîne d'information « couloir » mal formée, quelle que soit la
#     branche.
set -euo pipefail

# Recouvrements maîtrisés : liste fermée de l'ADR 0012, point 6 (même grammaire de motifs).
# Modifiée seulement avec une annotation de l'ADR.
RECOUVREMENTS_MAITRISES=(
  "docs/feuille-de-route.md"            # point 12 (et § 4, décisions M : point 13)
  "docs/adr/"                           # point 14
  "CONTEXT.md"                          # point 15
  "DESCRIPTION"                         # point 16 (la version)
  "docs/latex/doc_outil_prov_vie.tex"   # point 17
  "docs/latex/CONVENTIONS.md"           # point 17
  "NAMESPACE"                           # ajouts seulement
  "README.md"                           # ajouts seulement
)

# Le couloir lu : motifs inclus, exclus (un par ligne) et points de contact (chemins, un par
# ligne) ; NB_BLOCS : nombre de blocs trouvés pour la branche.
C_PLUS=""
C_MOINS=""
C_CONTACTS=""
A_CONTACTS=""
NB_BLOCS=0

# Motif valide : non vide, sans espace, relatif à la racine, sans autre syntaxe que « * »,
# « ** » et le « / » final.
motif_valide() {
  local m="$1"
  [ -n "$m" ] || return 1
  case "$m" in
    *[[:space:]]*|/*|.|..|./*|../*|*/./*|*/../*|*/.|*/..|*//*|*'***'*) return 1 ;;
    *'?'*|*'['*|*']'*|*'{'*|*'}'*|*'\'*|*'!'*|*'|'*|*'('*|*')'*|*'^'*|*'$'*|*'~'*) return 1 ;;
  esac
  return 0
}

# Expression régulière étendue ancrée d'un motif valide.
motif_vers_regex() {
  local m="$1" re="" c i n=${#1}
  for ((i = 0; i < n; i++)); do
    c="${m:i:1}"
    case "$c" in
      '*')
        if [ "${m:i+1:1}" = "*" ]; then re+='.*'; i=$((i + 1)); else re+='[^/]*'; fi ;;
      '.'|'+') re+="\\$c" ;;
      *) re+="$c" ;;
    esac
  done
  if [ "${m: -1}" = "/" ]; then re+='.*'; fi
  printf '^%s$' "$re"
}

# Le fichier $1 correspond-il au motif $2 ?
correspond() {
  local re
  re=$(motif_vers_regex "$2")
  [[ "$1" =~ $re ]]
}

# Le fichier $1 correspond-il à l'un des motifs de la liste $2 (un par ligne) ?
dans_motifs() {
  local p
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    if correspond "$1" "$p"; then return 0; fi
  done <<<"$2"
  return 1
}

recouvrement_maitrise() {
  local p
  for p in "${RECOUVREMENTS_MAITRISES[@]}"; do
    if correspond "$1" "$p"; then return 0; fi
  done
  return 1
}

dans_couloir() {
  dans_motifs "$1" "$C_PLUS" && ! dans_motifs "$1" "$C_MOINS"
}

# Le chemin $1 est-il dans la liste de chemins $2 (un par ligne) ?
dans_chemins() {
  [ -n "$2" ] && grep -qxF -- "$1" <<<"$2"
}

# Lit le bloc donné en $2 (lignes « numéro<TAB>contenu »), de la fiche $1 ; remplit C_PLUS,
# C_MOINS, C_CONTACTS. Affiche un [ECHEC] par ligne mal formée ; rend 1 s'il y en a.
lire_bloc() {
  local fiche="$1" num contenu l m chemin statut=0
  C_PLUS=""; C_MOINS=""; C_CONTACTS=""
  while IFS=$'\t' read -r num contenu; do
    [ -n "$num" ] || continue
    l="$contenu"
    l="${l#"${l%%[![:space:]]*}"}"
    l="${l%"${l##*[![:space:]]}"}"
    case "$l" in
      ""|"#"*) continue ;;
    esac
    if [[ "$l" =~ ^([+-])[[:space:]]+(.+)$ ]]; then
      m="${BASH_REMATCH[2]}"
      if ! motif_valide "$m"; then
        echo "[ECHEC] $fiche:$num : motif invalide « $m » (chemin relatif à la racine, « * », « ** » et « / » final seulement)"
        statut=1
      elif [ "${BASH_REMATCH[1]}" = "+" ]; then
        C_PLUS+="$m"$'\n'
      else
        C_MOINS+="$m"$'\n'
      fi
    elif [[ "$l" =~ ^=[[:space:]]+([^[:space:]]+)[[:space:]]+:[[:space:]]+(M[0-9]+)$ ]]; then
      chemin="${BASH_REMATCH[1]}"
      if ! motif_valide "$chemin" || [[ "$chemin" == *'*'* ]] || [ "${chemin: -1}" = "/" ]; then
        echo "[ECHEC] $fiche:$num : point de contact invalide « $chemin » (fichier exact attendu)"
        statut=1
      else
        C_CONTACTS+="$chemin"$'\n'
      fi
    else
      echo "[ECHEC] $fiche:$num : ligne de forme inconnue « $l » (« + motif », « - motif », « = chemin : Mnnn », « # », ligne vide)"
      statut=1
    fi
  done <<<"$2"
  return "$statut"
}

# Cherche dans la fiche $1 le bloc de couloir de la branche $2 ; remplit NB_BLOCS et, par
# lire_bloc, C_PLUS, C_MOINS, C_CONTACTS. Rend 1 (avec des [ECHEC]) si un bloc est mal formé,
# non fermé, en double, ou si une chaîne d'information « couloir » est mal formée ; 0 sinon (y
# compris sans bloc). Les blocs d'une autre chaîne d'information (« text » : l'exemple du
# § 1.12) ne sont jamais lus comme couloir.
charger_couloir() {
  local fiche="$1" branche="$2" type num contenu bloc="" statut=0 lignes_ouv="" sortie_awk
  NB_BLOCS=0
  C_PLUS=""; C_MOINS=""; C_CONTACTS=""
  if [ ! -f "$fiche" ] || [ ! -r "$fiche" ]; then
    echo "[ECHEC] fiche illisible ou n'est pas un fichier : $fiche" >&2
    return 2
  fi
  sortie_awk=$(awk -v branche="$branche" '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    { sub(/\r$/, ""); ligne = $0 }
    !dedans {
      if (match(ligne, /^[ \t]*```+/)) {
        ouv = substr(ligne, 1, RLENGTH); sub(/^[ \t]*/, "", ouv); nb = length(ouv)
        info = trim(substr(ligne, RLENGTH + 1))
        dedans = 1; cible = 0
        if (info ~ /^couloir([ \t]|$)/) {
          reste = trim(substr(info, 8))
          if (reste == "" || reste ~ /[ \t]/) { print "MAL\t" NR "\t" info }
          else if (reste == branche) { cible = 1; print "OUV\t" NR "\t" }
        }
      }
      next
    }
    {
      if (match(ligne, /^[ \t]*```+[ \t]*$/)) {
        f = trim(ligne)
        if (length(f) >= nb) { if (cible) print "FER\t" NR "\t"; dedans = 0; cible = 0; next }
      }
      if (cible) print "LIG\t" NR "\t" ligne
    }
    END { if (dedans && cible) print "NONFERME\t" NR "\t" }
  ' "$fiche") || { echo "[ECHEC] lecture de $fiche par awk impossible" >&2; return 2; }
  while IFS=$'\t' read -r type num contenu; do
    case "$type" in
      MAL)
        echo "[ECHEC] $fiche:$num : chaîne d'information « $contenu » mal formée (« couloir <nom de la branche> » attendu)"
        statut=1 ;;
      OUV) NB_BLOCS=$((NB_BLOCS + 1)); lignes_ouv+="$num " ;;
      NONFERME)
        echo "[ECHEC] $fiche : bloc « couloir $branche » non fermé"
        statut=1 ;;
      LIG) bloc+="$num"$'\t'"$contenu"$'\n' ;;
    esac
  done <<<"$sortie_awk"
  if [ "$NB_BLOCS" -gt 1 ]; then
    echo "[ECHEC] $fiche : $NB_BLOCS blocs « couloir $branche » (lignes ${lignes_ouv% }) ; un seul bloc par branche"
    return 1
  fi
  if [ "$NB_BLOCS" -eq 1 ]; then
    lire_bloc "$fiche" "$bloc" || statut=1
  fi
  return "$statut"
}

# Mode couloir : $1 fiche, $2 branche, $3 nom d'une fonction qui écrit les fichiers touchés
# (un par ligne). Statut 0 sans bloc ([INFO]), 1 au moindre [ECHEC].
lancer_couloir() {
  local fiche="$1" branche="$2" fournisseur="$3" liste f n=0 echecs=0 maitrises=0 contacts=0
  charger_couloir "$fiche" "$branche" || return $?
  if [ "$NB_BLOCS" -eq 0 ]; then
    echo "[INFO] aucun bloc « couloir $branche » dans $fiche : branche sans couloir déclaré, rien à contrôler"
    return 0
  fi
  liste=$("$fournisseur") || return 2
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    n=$((n + 1))
    if dans_chemins "$f" "$C_CONTACTS"; then
      contacts=$((contacts + 1))
    elif dans_couloir "$f"; then
      :
    elif recouvrement_maitrise "$f"; then
      maitrises=$((maitrises + 1))
    else
      echo "[ECHEC] $f : hors du couloir de $branche, hors recouvrements maîtrisés et hors points de contact (sortie de couloir : point de décision, ADR 0012, point 9)"
      echecs=$((echecs + 1))
    fi
  done <<<"$liste"
  if [ "$echecs" -gt 0 ]; then return 1; fi
  echo "[OK] $branche : $n fichier(s) touché(s), tous dans le couloir ($maitrises recouvrement(s) maîtrisé(s), $contacts point(s) de contact)"
}

# Mode intersection : $1 fiche, $2 branche courante, $3 autre branche, $4 et $5 : fonctions qui
# écrivent les fichiers touchés par la courante et par l'autre.
lancer_intersection() {
  local fiche="$1" branche="$2" autre="$3" liste_c liste_a inter f n=0 echecs=0 maitrises=0 contacts=0
  charger_couloir "$fiche" "$branche" || return $?
  if [ "$NB_BLOCS" -eq 0 ]; then
    echo "[INFO] aucun bloc « couloir $branche » dans $fiche : aucun point de contact déclaré par $branche"
  fi
  A_CONTACTS="$C_CONTACTS"
  charger_couloir "$fiche" "$autre" || return $?
  if [ "$NB_BLOCS" -eq 0 ]; then
    echo "[INFO] aucun bloc « couloir $autre » dans $fiche : aucun point de contact déclaré par $autre"
  fi
  # Ici C_CONTACTS : contacts de l'autre ; A_CONTACTS : contacts de la courante.
  liste_c=$("$4") || return 2
  liste_a=$("$5") || return 2
  inter=$(LC_ALL=C comm -12 <(LC_ALL=C sort -u <<<"$liste_c") <(LC_ALL=C sort -u <<<"$liste_a"))
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    n=$((n + 1))
    if recouvrement_maitrise "$f"; then
      maitrises=$((maitrises + 1))
    elif dans_chemins "$f" "$A_CONTACTS" && dans_chemins "$f" "$C_CONTACTS"; then
      contacts=$((contacts + 1))
    elif dans_chemins "$f" "$A_CONTACTS" || dans_chemins "$f" "$C_CONTACTS"; then
      echo "[ECHEC] $f : touché par $branche et $autre ; point de contact déclaré dans une seule des deux fiches"
      echecs=$((echecs + 1))
    else
      echo "[ECHEC] $f : touché par $branche et $autre, ni recouvrement maîtrisé ni point de contact déclaré dans les deux fiches"
      echecs=$((echecs + 1))
    fi
  done <<<"$inter"
  if [ "$echecs" -gt 0 ]; then return 1; fi
  echo "[OK] intersection de $branche et $autre : $n fichier(s) communs, tous admis ($maitrises recouvrement(s) maîtrisé(s), $contacts point(s) de contact)"
}

# --- Sources git (modes réels seulement) ---------------------------------------------------
BASE="origin/main"

fichiers_touches() {  # $1 : tête
  # core.quotePath=false : un chemin non ASCII sort tel quel, non entre guillemets (octal).
  git -c core.quotePath=false diff --name-only --no-renames "$BASE...$1" || {
    echo "[ECHEC] git diff --name-only $BASE...$1 impossible (base ou branche absente : git fetch origin main <branche>)" >&2
    return 2
  }
}
fichiers_courante() { fichiers_touches HEAD; }
fichiers_autre() {
  if git rev-parse --verify -q "origin/$AUTRE^{commit}" > /dev/null; then
    fichiers_touches "origin/$AUTRE"
  else
    fichiers_touches "$AUTRE"
  fi
}

# --- Témoins -------------------------------------------------------------------------------
LISTE_TEMOIN=""
LISTE_TEMOIN_AUTRE=""
liste_temoin() { printf '%s\n' "$LISTE_TEMOIN"; }
liste_temoin_autre() { printf '%s\n' "$LISTE_TEMOIN_AUTRE"; }

# Témoins négatifs, sans git : fiches et listes de fichiers construites. Un fichier hors couloir,
# un fichier exclu, un motif hors grammaire, un bloc en double ou non fermé, un point de contact
# déclaré d'un seul côté échouent ; les cas licites passent ; l'exemple « text » du § 1.12 n'est
# pas un couloir.
temoins() {
  local d fiche sortie statut l echecs=0 n=0
  d=$(mktemp -d)
  trap 'rm -rf "$d"' RETURN
  fiche="$d/fiche.md"
  # attendre <nom> <statut attendu> <sous-chaîne attendue de la sortie ou vide> <commande...>
  attendre() {
    local nom="$1" attendu="$2" motif="$3"
    shift 3
    n=$((n + 1))
    statut=0
    sortie=$("$@" 2>&1) || statut=$?
    if [ "$statut" -ne "$attendu" ]; then
      echo "[ECHEC] témoin « $nom » : statut $statut au lieu de $attendu ($(tr '\n' '|' <<<"$sortie"))"
      echecs=$((echecs + 1))
    elif [ -n "$motif" ] && ! grep -qF -- "$motif" <<<"$sortie"; then
      echo "[ECHEC] témoin « $nom » : « $motif » absent de la sortie ($(tr '\n' '|' <<<"$sortie"))"
      echecs=$((echecs + 1))
    fi
  }
  # fiche_avec <lignes du bloc> : fiche à un bloc « couloir br/a », indenté comme dans une liste.
  fiche_avec() {
    {
      echo "# Fiche"
      echo "  - Couloir :"
      echo "    \`\`\`couloir br/a"
      printf '%s\n' "$@" | sed 's/^/    /'
      echo "    \`\`\`"
    } > "$fiche"
  }
  COULOIR_TYPE=(
    "+ R/engagement.R"
    "+ tests/unitaires/"
    "+ tests/controles/*.R"
    "- tests/unitaires/exclu.R"
    "# commentaire"
    ""
    "= tests/references.R : M404"
  )
  fiche_avec "${COULOIR_TYPE[@]}"
  LISTE_TEMOIN=$'R/engagement.R\ntests/unitaires/a/b.R\ntests/controles/x.R'
  attendre "fichiers du couloir admis" 0 "[OK] br/a : 3 fichier(s)" lancer_couloir "$fiche" br/a liste_temoin
  LISTE_TEMOIN=$'R/engagement.R\nR/calcul.R'
  attendre "fichier hors couloir refusé (témoin négatif)" 1 "[ECHEC] R/calcul.R : hors du couloir de br/a" lancer_couloir "$fiche" br/a liste_temoin
  LISTE_TEMOIN=$'tests/unitaires/exclu.R'
  attendre "exclusion prime sur inclusion" 1 "[ECHEC] tests/unitaires/exclu.R" lancer_couloir "$fiche" br/a liste_temoin
  LISTE_TEMOIN=$'tests/controles/sous/x.R'
  attendre "« * » ne franchit pas « / »" 1 "[ECHEC] tests/controles/sous/x.R" lancer_couloir "$fiche" br/a liste_temoin
  LISTE_TEMOIN=$'tests/controles/xR'
  attendre "« . » du motif est littéral" 1 "[ECHEC] tests/controles/xR" lancer_couloir "$fiche" br/a liste_temoin
  LISTE_TEMOIN=$'tests/references.R'
  attendre "point de contact admis" 0 "1 point(s) de contact" lancer_couloir "$fiche" br/a liste_temoin
  LISTE_TEMOIN=$'tests/references.Rx\ntests/reference'
  attendre "point de contact : chemin exact seulement" 1 "[ECHEC] tests/references.Rx" lancer_couloir "$fiche" br/a liste_temoin
  LISTE_TEMOIN=$'tests/reference'
  attendre "point de contact : un préfixe du chemin n'est pas le chemin" 1 "[ECHEC] tests/reference :" lancer_couloir "$fiche" br/a liste_temoin
  LISTE_TEMOIN=$'DESCRIPTION\ndocs/adr/0013-x.md\nCONTEXT.md\nREADME.md\nNAMESPACE\ndocs/feuille-de-route.md\ndocs/latex/CONVENTIONS.md\ndocs/latex/doc_outil_prov_vie.tex'
  attendre "recouvrements maîtrisés admis hors couloir" 0 "8 recouvrement(s)" lancer_couloir "$fiche" br/a liste_temoin
  LISTE_TEMOIN=$'docs/latex/autre.tex\ndocs/adr'
  attendre "recouvrement : liste fermée (autre fichier de docs/latex/ refusé)" 1 "[ECHEC] docs/latex/autre.tex" lancer_couloir "$fiche" br/a liste_temoin
  LISTE_TEMOIN=$'R/engagement.R'
  attendre "branche sans bloc : [INFO], statut 0" 0 "[INFO] aucun bloc « couloir br/b »" lancer_couloir "$fiche" br/b liste_temoin
  LISTE_TEMOIN=$'R/hors.R'
  attendre "branche sans bloc : aucun fichier contrôlé, statut 0" 0 "" lancer_couloir "$fiche" br/b liste_temoin
  # Grammaire : « ** », sous-arbre, CRLF.
  fiche_avec "+ docs/**.md" "+ app/" "+ a+b.R"
  LISTE_TEMOIN=$'docs/x/y/z.md\napp/a/b.R\na+b.R'
  attendre "« ** » franchit « / », « / » final = sous-arbre, « + » littéral" 0 "[OK] br/a : 3 fichier(s)" lancer_couloir "$fiche" br/a liste_temoin
  LISTE_TEMOIN=$'docs/x.txt\naab.R\napp'
  attendre "motifs : extension, « + » littéral, sous-arbre sans le dossier lui-même" 1 "[ECHEC] app :" lancer_couloir "$fiche" br/a liste_temoin
  fiche_avec "+ R/a.R"
  while IFS= read -r l; do printf '%s\r\n' "$l"; done < "$fiche" > "$fiche.crlf" && mv "$fiche.crlf" "$fiche"
  LISTE_TEMOIN=$'R/a.R'
  attendre "fiche en fins de ligne CRLF" 0 "[OK] br/a" lancer_couloir "$fiche" br/a liste_temoin
  # Formes refusées.
  LISTE_TEMOIN=$'R/a.R'
  local cas
  for cas in "R/a.R" "? R/a.R" "+R/a.R" "+" "+ R/a b.R" "+ R/[ab].R" "+ R/?.R" "+ R/{a,b}.R" "+ ***" "+ /R/a.R" "+ ../a.R" "+ R//a.R" \
             "+ R/!a.R" "+ .." "+ ." "+ ./R/a.R" "+ R/./a.R" "+ R/." "= R/a.R" "= R/a.R : 404" "= R/*.R : M404" "= R/ : M404" "= R/a.R : M404 : M405"; do
    fiche_avec "+ R/a.R" "$cas"
    attendre "forme refusée : « $cas »" 1 "[ECHEC] $fiche:" lancer_couloir "$fiche" br/a liste_temoin
  done
  attendre "fiche absente : statut 2" 2 "fiche illisible" lancer_couloir "$d/absente.md" br/a liste_temoin
  attendre "fiche qui est un dossier : statut 2" 2 "fiche illisible" lancer_couloir "$d" br/a liste_temoin
  # Blocs : double, non fermé, chaîne d'information mal formée, exemple « text ».
  {
    printf '%s\n' '```couloir br/a' '+ R/a.R' '```' '' '```couloir br/a' '+ R/b.R' '```'
  } > "$fiche"
  attendre "deux blocs pour la même branche" 1 "2 blocs « couloir br/a »" lancer_couloir "$fiche" br/a liste_temoin
  printf '%s\n' '```couloir br/a' '+ R/a.R' > "$fiche"
  attendre "bloc non fermé" 1 "non fermé" lancer_couloir "$fiche" br/a liste_temoin
  printf '%s\n' '```couloir' '+ R/a.R' '```' > "$fiche"
  attendre "chaîne d'information sans nom de branche" 1 "mal formée" lancer_couloir "$fiche" br/a liste_temoin
  printf '%s\n' '```couloir br/a br/b' '+ R/a.R' '```' > "$fiche"
  attendre "chaîne d'information à deux noms" 1 "mal formée" lancer_couloir "$fiche" br/a liste_temoin
  printf '%s\n' '````markdown' '```' '```couloir br/a' '+ R/a.R' '```' '````' > "$fiche"
  attendre "clôture plus courte que l'ouverture : ne ferme pas le bloc, le couloir imbriqué n'est pas lu" 0 "[INFO] aucun bloc" lancer_couloir "$fiche" br/a liste_temoin
  printf '%s\n' '```text' '+ R/a.R' '```' > "$fiche"
  attendre "l'exemple sous la chaîne « text » n'est pas un couloir" 0 "[INFO] aucun bloc" lancer_couloir "$fiche" br/a liste_temoin
  printf '%s\n' '````markdown' '```couloir br/a' '+ R/a.R' '```' '````' > "$fiche"
  attendre "bloc imbriqué dans un bloc plus long : non lu" 0 "[INFO] aucun bloc" lancer_couloir "$fiche" br/a liste_temoin
  printf '%s\n' '```couloir br/b' '+ R/b.R' '```' '```couloir br/a' '+ R/a.R' '```' > "$fiche"
  LISTE_TEMOIN=$'R/a.R'
  attendre "deux branches, un bloc chacune : la branche demandée seule est lue" 0 "[OK] br/a : 1 fichier(s)" lancer_couloir "$fiche" br/a liste_temoin
  LISTE_TEMOIN=$'R/b.R'
  attendre "deux branches : le couloir de l'autre ne vaut pas" 1 "[ECHEC] R/b.R" lancer_couloir "$fiche" br/a liste_temoin
  # Intersection.
  printf '%s\n' '```couloir br/a' '+ R/a.R' '= tests/references.R : M404' '= R/commun.R : M410' '```' \
                '```couloir br/b' '+ R/b.R' '= tests/references.R : M404' '```' > "$fiche"
  LISTE_TEMOIN=$'R/a.R\nDESCRIPTION\ntests/references.R'
  LISTE_TEMOIN_AUTRE=$'R/b.R\nDESCRIPTION\ntests/references.R\nCONTEXT.md'
  attendre "intersection : recouvrement maîtrisé et point de contact des deux fiches admis" 0 "[OK] intersection de br/a et br/b : 2 fichier(s)" \
    lancer_intersection "$fiche" br/a br/b liste_temoin liste_temoin_autre
  LISTE_TEMOIN=$'R/a.R\nR/x.R'
  LISTE_TEMOIN_AUTRE=$'R/b.R\nR/x.R'
  attendre "intersection : fichier commun hors recouvrement et hors contact refusé (témoin négatif)" 1 "[ECHEC] R/x.R : touché par br/a et br/b, ni recouvrement" \
    lancer_intersection "$fiche" br/a br/b liste_temoin liste_temoin_autre
  LISTE_TEMOIN=$'R/commun.R'
  LISTE_TEMOIN_AUTRE=$'R/commun.R'
  attendre "intersection : point de contact déclaré d'un seul côté refusé" 1 "dans une seule des deux fiches" \
    lancer_intersection "$fiche" br/a br/b liste_temoin liste_temoin_autre
  LISTE_TEMOIN=$'R/a.R'
  LISTE_TEMOIN_AUTRE=$'R/b.R'
  attendre "intersection vide : statut 0" 0 "0 fichier(s) communs" lancer_intersection "$fiche" br/a br/b liste_temoin liste_temoin_autre
  LISTE_TEMOIN=$'R/a.R'
  attendre "intersection avec une branche sans bloc : [INFO], aucun contact" 0 "[INFO] aucun bloc « couloir br/z »" \
    lancer_intersection "$fiche" br/a br/z liste_temoin liste_temoin_autre
  LISTE_TEMOIN=$'tests/references.R'
  LISTE_TEMOIN_AUTRE=$'tests/references.R'
  attendre "intersection avec une branche sans bloc : un contact d'un seul côté refusé" 1 "dans une seule des deux fiches" \
    lancer_intersection "$fiche" br/a br/z liste_temoin liste_temoin_autre
  if [ "$echecs" -eq 0 ]; then
    echo "[OK] témoins : $n cas (couloir, exclusion, recouvrements maîtrisés, points de contact, grammaire, formes refusées, blocs en double ou non fermés, exemple « text », intersection) conformes"
    return 0
  fi
  echo "[ECHEC] témoins : $echecs cas sur $n non conformes"
  return 1
}

# --- Point d'entrée ------------------------------------------------------------------------
FICHE="docs/feuille-de-route.md"
BRANCHE=""
AUTRE=""
MODE="couloir"
for arg in "$@"; do
  case "$arg" in
    --temoins) MODE="temoins" ;;
    --branche=?*) BRANCHE="${arg#--branche=}" ;;
    --autre=?*) AUTRE="${arg#--autre=}" ;;
    --base=?*) BASE="${arg#--base=}" ;;
    --fiche=?*) FICHE="${arg#--fiche=}" ;;
    *)
      echo "[ECHEC] usage : bash tests/controles/couloir.sh [--branche=<nom>] [--autre=<branche>] [--base=<réf>] [--fiche=<chemin>] | --temoins" >&2
      exit 2 ;;
  esac
done

if [ "$MODE" = "temoins" ]; then
  temoins
  exit $?
fi
if [ ! -f "$FICHE" ] || [ ! -r "$FICHE" ]; then
  echo "[ECHEC] fiche illisible ou n'est pas un fichier : $FICHE (à lancer depuis la racine du dépôt)" >&2
  exit 2
fi
if [ -z "$BRANCHE" ]; then
  BRANCHE="${GITHUB_HEAD_REF:-}"
fi
if [ -z "$BRANCHE" ]; then
  BRANCHE=$(git rev-parse --abbrev-ref HEAD) || { echo "[ECHEC] branche courante illisible (git rev-parse)" >&2; exit 2; }
fi
statut=0
if [ -n "$AUTRE" ]; then
  lancer_intersection "$FICHE" "$BRANCHE" "$AUTRE" fichiers_courante fichiers_autre || statut=$?
else
  lancer_couloir "$FICHE" "$BRANCHE" fichiers_courante || statut=$?
fi
exit "$statut"
