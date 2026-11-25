#!/usr/bin/env bash
# Contrôle : commits de référence (ADR 0011, points 20 et 21 ; ADR 0010, point 26, annoté ;
# #67). Tourne dans le job « Contrôles du dépôt » de la CI, sur les commits de la PR, hors de
# la batterie unitaire (git peut manquer dans l'image du job « Tests (R 4.3.3) »).
# Tout commit non fusion de la plage qui touche tests/reference/ :
#   1. ne touche rien d'autre ;
#   2. porte les lignes « Run : », « Commit calculé : », « Image : », « Plateforme : »,
#      « Empreinte : » et « Visa : », remplies : aucune n'y garde un champ du squelette de
#      message_commit.txt (« < », « JJ/MM/AAAA », « #NN ») ;
#   3. a un unique parent, qui est le commit calculé nommé par « Commit calculé : » et par
#      tests/reference/provenance.txt (champ commit) à ce commit ;
#   4. a pour « Empreinte : » le MD5 de tests/reference/empreintes.md5 à ce commit.
# Une fusion est contrôlée par son diff combiné (git diff-tree --cc) : elle échoue si ce diff
# liste un fichier sous tests/reference/ (fichier absent des deux parents, ou résolu autrement
# que par l'un d'eux) ; une fusion propre (par exemple celle de main dans une branche de travail,
# qui apporte les références déjà fusionnées) passe, avec une ligne [INFO]. Les noms de fichiers
# sont lus par -z (aucune citation par git). Une plage que git ne résout pas est un [ECHEC] ;
# une plage vide est annoncée par une ligne [INFO], statut 0 (M790, #195).
# Limites connues (#140 ; chacune mesurée sur un dépôt temporaire) :
#   - le contenu des lignes n'est pas lu, hors les champs du squelette : « Image : n importe
#     quoi » passe (l'image n'est pas comparée à celle d'image_reference.R) et le visa n'est pas
#     vérifié ; un « < » dans une ligne est lu comme un champ du squelette (« Plateforme : R
#     version 4.3.3 <x86_64> » refusée à tort) ;
#   - « Empreinte : » est comparée au MD5 du fichier empreintes.md5 ; la concordance de ce
#     fichier avec les fichiers de référence n'est pas lue ici (un empreintes.md5 qui porte un
#     MD5 faux passe).
#   - fusions : le diff combiné ne liste pas un fichier que la fusion reprend tel quel d'un
#     parent. Une fusion qui garde l'arbre tests/reference/ d'un parent (git merge -s ours, ou
#     git rm, à la résolution, d'un fichier que seul l'autre parent a ajouté) passe donc en
#     [INFO] : main peut perdre des références sans [ECHEC]. Contrôle complet : issue #218.
#     Du côté sûr, le diff combiné liste, et la fusion est refusée, quand deux modifications
#     disjointes d'un même fichier de référence sont fusionnées automatiquement et quand la
#     résolution supprime un fichier présent dans les deux parents.
# Usage, depuis la racine du dépôt :
#   bash tests/controles/commit_reference.sh <base>..<tête>   (plage de commits à contrôler)
#   bash tests/controles/commit_reference.sh --temoins          (témoins négatifs, dépôt temporaire)
# Sortie : lignes [OK] / [INFO] / [ECHEC] <commit> ; statut 1 au moindre [ECHEC].
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
LIGNES_REQUISES=("Run :" "Commit calculé :" "Image :" "Plateforme :" "Empreinte :" "Visa :")

# Noms de fichiers modifiés (hors identifiant du commit), lus par -z : remplit le tableau NOMS.
# $@ : options de git diff-tree, puis le commit. Rend 1 si git échoue.
lire_noms() {
  local tmp
  tmp=$(mktemp)
  if ! git diff-tree --no-commit-id --name-only -r -z "$@" > "$tmp"; then
    rm -f "$tmp"; return 1
  fi
  NOMS=()
  mapfile -d '' -t NOMS < "$tmp"
  rm -f "$tmp"
}

# Contrôle d'un commit ; affiche les [ECHEC] et rend 1 si le commit en a, 0 sinon (y compris
# s'il ne touche pas tests/reference/). Une fusion est contrôlée par son diff combiné.
controler_commit() {
  local c="$1" message parents parent calcule provenance empreinte md5 statut=0 n touche=0 autres=() refs=()
  if ! parents=$(git rev-list --parents -n 1 "$c" | wc -w); then
    echo "[ECHEC] $c : git rev-list a échoué"; return 1
  fi
  if [ "$parents" -gt 2 ]; then
    if ! lire_noms --cc "$c"; then echo "[ECHEC] $c : git diff-tree a échoué"; return 1; fi
    for n in "${NOMS[@]}"; do
      if [[ "$n" == tests/reference/* ]]; then touche=1; refs+=("$n"); fi
    done
    if [ "$touche" -eq 1 ]; then
      echo "[ECHEC] $c : le diff combiné d'une fusion liste un fichier de tests/reference/ (${refs[*]})"; return 1
    fi
    echo "[INFO] $c : fusion, diff combiné sans fichier de tests/reference/"
    return 0
  fi
  if ! lire_noms --root "$c"; then echo "[ECHEC] $c : git diff-tree a échoué"; return 1; fi
  for n in "${NOMS[@]}"; do
    if [[ "$n" == tests/reference/* ]]; then touche=1; else autres+=("$n"); fi
  done
  if [ "$touche" -eq 0 ]; then
    return 0
  fi
  if [ "${#autres[@]}" -gt 0 ]; then
    echo "[ECHEC] $c : un commit de référence ne touche que tests/reference/ (aussi : ${autres[*]})"; statut=1
  fi
  message=$(git log -1 --format=%B "$c")
  for l in "${LIGNES_REQUISES[@]}"; do
    if ! grep -q "^$l " <<<"$message"; then
      echo "[ECHEC] $c : ligne « $l » absente du message"; statut=1
    elif grep "^$l " <<<"$message" | grep -qE '<|JJ/MM/AAAA|#NN'; then
      echo "[ECHEC] $c : ligne « $l » non remplie (champ du squelette : <…>, JJ/MM/AAAA ou #NN)"; statut=1
    fi
  done
  parent=$(git rev-parse "$c^" 2>/dev/null || true)
  if [ "$parents" -ne 2 ]; then
    echo "[ECHEC] $c : un commit de référence a un unique parent ($((parents - 1)) parent(s))"; statut=1
  fi
  calcule=$(grep -m1 '^Commit calculé : ' <<<"$message" | grep -oE '[0-9a-f]{40}' | head -n1 || true)
  if [ -z "$calcule" ] || [ "$calcule" != "$parent" ]; then
    echo "[ECHEC] $c : « Commit calculé : » (${calcule:-absent}) n'est pas l'unique parent (${parent:-aucun})"; statut=1
  fi
  provenance=$(git show "$c:tests/reference/provenance.txt" 2>/dev/null | awk -F'\t' '$1 == "commit" { print $3 }' || true)
  if [ -z "$provenance" ] || [ "$provenance" != "$parent" ]; then
    echo "[ECHEC] $c : provenance.txt (commit ${provenance:-absent}) ne nomme pas le parent (${parent:-aucun})"; statut=1
  fi
  empreinte=$(grep -m1 '^Empreinte : ' <<<"$message" | grep -oE '[0-9a-f]{32}' | head -n1 || true)
  md5=$(git show "$c:tests/reference/empreintes.md5" 2>/dev/null | md5sum | cut -d' ' -f1 || true)
  if ! git cat-file -e "$c:tests/reference/empreintes.md5" 2>/dev/null || [ "$empreinte" != "$md5" ]; then
    echo "[ECHEC] $c : « Empreinte : » (${empreinte:-absente}) n'est pas le MD5 de tests/reference/empreintes.md5 ($md5)"; statut=1
  fi
  if [ "$statut" -eq 0 ]; then echo "[OK] $c : commit de référence conforme"; fi
  return "$statut"
}

controler_plage() {
  local plage="$1" n=0 echecs=0 c commits
  if ! commits=$(git rev-list --reverse "$plage"); then
    echo "[ECHEC] plage $plage : git rev-list a échoué"; return 1
  fi
  if [ -z "$commits" ]; then
    echo "[INFO] plage vide : aucun commit dans $plage, rien à contrôler"; return 0
  fi
  for c in $commits; do
    n=$((n + 1))
    controler_commit "$c" || echecs=$((echecs + 1))
  done
  if [ "$echecs" -gt 0 ]; then return 1; fi
  echo "[OK] $n commit(s) contrôlé(s) dans $plage : commits de référence conformes ou absents"
}

# Témoins négatifs (dépôt temporaire) : un commit de référence conforme passe ; un commit qui
# touche aussi un autre fichier, un commit dont l'empreinte est fausse, un commit dont le
# commit calculé n'est pas le parent, un commit sans ligne « Visa : » et deux commits dont la
# ligne « Visa : » garde un champ du squelette échouent. Puis, par le script lui-même (#195) : une
# plage inconnue échoue (statut 1) ; une plage vide est annoncée [INFO] (statut 0) ; un commit qui
# ne touche que tests/reference/é.txt ou tests/reference/a"b.txt (noms que git cite sans -z) est
# contrôlé, donc refusé faute de message ; une fusion qui ajoute tests/reference/evil.txt est
# refusée ; une fusion propre passe, annoncée [INFO].
temoins() {
  local d calc bon statut=0 sortie st
  d=$(mktemp -d)
  trap 'rm -rf "$d"' RETURN
  (
    cd "$d"
    git init -q
    git config user.name temoin
    git config user.email temoin@example.invalid
    echo a > a.txt
    git add a.txt
    git commit -q -m "base"
  )
  calc=$(git -C "$d" rev-parse HEAD)
  ecrire_arbre() {
    mkdir -p "$d/tests/reference"
    printf 'provie-liste 1\nversion_references\tinteger\t1\ncommit\tcharacter\t%s\n' "$1" > "$d/tests/reference/provenance.txt"
    (cd "$d/tests/reference" && md5sum provenance.txt > empreintes.md5)
  }
  message() {  # $1 commit calculé, $2 empreinte, $3 visa (vide : sans ligne)
    printf 'tests: références\n\nRun : https://example.invalid/1 (tentative 1)\nCommit calculé : %s (parent du présent commit)\nImage : rocker/r-ver:4.3.3@sha256:%064d\nPlateforme : R version 4.3.3\nEmpreinte : %s\n%s' \
      "$1" 0 "$2" "$3"
  }
  # conforme
  ecrire_arbre "$calc"
  git -C "$d" add tests/reference
  git -C "$d" commit -q -m "$(message "$calc" "$(md5sum < "$d/tests/reference/empreintes.md5" | cut -d' ' -f1)" "Visa : mainteneur")"
  bon=$(git -C "$d" rev-parse HEAD)
  if ! (cd "$d" && controler_commit "$bon" > /dev/null); then echo "[ECHEC] témoin : commit de référence conforme refusé"; statut=1; fi
  # touche un autre fichier
  git -C "$d" reset -q --hard "$calc"
  ecrire_arbre "$calc"
  echo b > "$d/a.txt"
  git -C "$d" add -A
  git -C "$d" commit -q -m "$(message "$calc" "$(md5sum < "$d/tests/reference/empreintes.md5" | cut -d' ' -f1)" "Visa : mainteneur")"
  if (cd "$d" && controler_commit "$(git rev-parse HEAD)" > /dev/null); then echo "[ECHEC] témoin : commit qui touche un autre fichier admis"; statut=1; fi
  # empreinte fausse
  git -C "$d" reset -q --hard "$calc"
  ecrire_arbre "$calc"
  git -C "$d" add -A
  git -C "$d" commit -q -m "$(message "$calc" "$(printf '%032d' 0)" "Visa : mainteneur")"
  if (cd "$d" && controler_commit "$(git rev-parse HEAD)" > /dev/null); then echo "[ECHEC] témoin : empreinte fausse admise"; statut=1; fi
  # commit calculé qui n'est pas le parent (intercalaire)
  git -C "$d" reset -q --hard "$calc"
  echo c > "$d/c.txt"
  git -C "$d" add -A
  git -C "$d" commit -q -m "intercalaire"
  ecrire_arbre "$calc"
  git -C "$d" add -A
  git -C "$d" commit -q -m "$(message "$calc" "$(md5sum < "$d/tests/reference/empreintes.md5" | cut -d' ' -f1)" "Visa : mainteneur")"
  if (cd "$d" && controler_commit "$(git rev-parse HEAD)" > /dev/null); then echo "[ECHEC] témoin : commit calculé non parent admis"; statut=1; fi
  # sans ligne Visa
  git -C "$d" reset -q --hard "$calc"
  ecrire_arbre "$calc"
  git -C "$d" add -A
  git -C "$d" commit -q -m "$(message "$calc" "$(md5sum < "$d/tests/reference/empreintes.md5" | cut -d' ' -f1)" "")"
  if (cd "$d" && controler_commit "$(git rev-parse HEAD)" > /dev/null); then echo "[ECHEC] témoin : commit sans ligne Visa admis"; statut=1; fi
  # ligne Visa du squelette, non remplie
  git -C "$d" reset -q --hard "$calc"
  ecrire_arbre "$calc"
  git -C "$d" add -A
  git -C "$d" commit -q -m "$(message "$calc" "$(md5sum < "$d/tests/reference/empreintes.md5" | cut -d' ' -f1)" \
    "Visa : <mainteneur | actuary>, JJ/MM/AAAA, <URL du commentaire de visa>")"
  if (cd "$d" && controler_commit "$(git rev-parse HEAD)" > /dev/null); then echo "[ECHEC] témoin : ligne Visa du squelette admise"; statut=1; fi
  # date seule non remplie
  git -C "$d" reset -q --hard "$calc"
  ecrire_arbre "$calc"
  git -C "$d" add -A
  git -C "$d" commit -q -m "$(message "$calc" "$(md5sum < "$d/tests/reference/empreintes.md5" | cut -d' ' -f1)" \
    "Visa : mainteneur, JJ/MM/AAAA, https://example.invalid/visa")"
  if (cd "$d" && controler_commit "$(git rev-parse HEAD)" > /dev/null); then echo "[ECHEC] témoin : date JJ/MM/AAAA admise"; statut=1; fi
  # lance le script sur une plage, dans le dépôt temporaire : sortie dans $sortie, statut dans $st
  lancer() {
    st=0
    sortie=$(cd "$d" && bash "$SCRIPT" "$1" 2>&1) || st=$?
  }
  # plage inconnue : échec, statut 1
  lancer "inconnu..HEAD"
  if [ "$st" -ne 1 ] || ! grep -q '^\[ECHEC\]' <<<"$sortie"; then echo "[ECHEC] témoin : plage inconnue admise (statut $st)"; statut=1; fi
  # plage vide : ligne [INFO], statut 0
  git -C "$d" reset -q --hard "$calc"
  lancer "HEAD..HEAD"
  if [ "$st" -ne 0 ] || ! grep -q '^\[INFO\] plage vide' <<<"$sortie"; then echo "[ECHEC] témoin : plage vide non annoncée par [INFO] (statut $st)"; statut=1; fi
  # noms que git cite sans -z : commit qui ne touche que tests/reference/<nom>, sans message de référence
  git -C "$d" config core.quotePath true
  local nom
  for nom in "é.txt" 'a"b.txt'; do
    git -C "$d" reset -q --hard "$calc"
    mkdir -p "$d/tests/reference"
    echo x > "$d/tests/reference/$nom"
    git -C "$d" add -A
    git -C "$d" commit -q -m "tests: nom cité"
    lancer "$calc..HEAD"
    if [ "$st" -ne 1 ] || ! grep -qF 'ligne « Run : » absente' <<<"$sortie"; then echo "[ECHEC] témoin : commit qui ne touche que tests/reference/$nom admis ou refusé pour un autre motif (statut $st)"; statut=1; fi
  done
  # fusion qui ajoute tests/reference/evil.txt : refusée
  git -C "$d" reset -q --hard "$calc"
  git -C "$d" checkout -q -b cote
  echo c > "$d/c.txt"; git -C "$d" add -A; git -C "$d" commit -q -m "cote"
  git -C "$d" checkout -q -
  echo b > "$d/b.txt"; git -C "$d" add -A; git -C "$d" commit -q -m "tronc"
  git -C "$d" merge -q --no-ff --no-commit cote > /dev/null 2>&1
  mkdir -p "$d/tests/reference"; echo x > "$d/tests/reference/evil.txt"
  git -C "$d" add -A
  git -C "$d" commit -q -m "fusion piégée"
  lancer "$calc..HEAD"
  if [ "$st" -ne 1 ] || ! grep -qF "le diff combiné d'une fusion liste un fichier de tests/reference/" <<<"$sortie"; then echo "[ECHEC] témoin : fusion qui ajoute tests/reference/evil.txt admise ou refusée pour un autre motif (statut $st)"; statut=1; fi
  # fusion propre qui apporte tests/reference/r2.txt par un parent : admise, annoncée [INFO]
  git -C "$d" reset -q --hard "$calc"
  git -C "$d" checkout -q -B cote2
  mkdir -p "$d/tests/reference"; echo x > "$d/tests/reference/r2.txt"
  git -C "$d" add -A; git -C "$d" commit -q -m "cote2"
  git -C "$d" checkout -q -
  echo b > "$d/b.txt"; git -C "$d" add -A; git -C "$d" commit -q -m "tronc"
  git -C "$d" merge -q --no-ff -m "fusion propre" cote2
  lancer "cote2..HEAD"
  if [ "$st" -ne 0 ] || ! grep -q '^\[INFO\] .*fusion' <<<"$sortie"; then echo "[ECHEC] témoin : fusion propre refusée ou non annoncée par [INFO] (statut $st)"; statut=1; fi
  if [ "$statut" -eq 0 ]; then
    echo "[OK] témoins : commit conforme admis ; autre fichier, empreinte fausse, commit calculé non parent, Visa absent, Visa du squelette, date non remplie, plage inconnue, noms cités, fusion piégée refusés ; plage vide et fusion propre annoncées [INFO]"
  fi
  return "$statut"
}

if [ "${1:-}" = "--temoins" ]; then
  temoins
elif [ $# -eq 1 ]; then
  controler_plage "$1"
else
  echo "[ECHEC] usage : bash tests/controles/commit_reference.sh <base>..<tête> | --temoins"; exit 1
fi
