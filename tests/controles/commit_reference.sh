#!/usr/bin/env bash
# Contrôle : commits de référence (ADR 0011, points 20 et 21 ; ADR 0010, point 26, annoté ;
# #67). Tourne dans le job « Contrôles du dépôt » de la CI, sur les commits de la PR, hors de
# la batterie unitaire (git peut manquer dans l'image du job « Tests (R 4.3.3) »).
# Tout commit (hors fusions) de la plage qui touche tests/reference/ :
#   1. ne touche rien d'autre ;
#   2. porte les lignes « Run : », « Commit calculé : », « Image : », « Plateforme : »,
#      « Empreinte : » et « Visa : », remplies : aucune n'y garde un champ du squelette de
#      message_commit.txt (« < », « JJ/MM/AAAA », « #NN ») ;
#   3. a un unique parent, qui est le commit calculé nommé par « Commit calculé : » et par
#      tests/reference/provenance.txt (champ commit) à ce commit ;
#   4. a pour « Empreinte : » le MD5 de tests/reference/empreintes.md5 à ce commit.
# Usage, depuis la racine du dépôt :
#   bash tests/controles/commit_reference.sh <base>..<tête>   (plage de commits à contrôler)
#   bash tests/controles/commit_reference.sh --temoins          (témoins négatifs, dépôt temporaire)
# Sortie : lignes [OK] / [ECHEC] <commit> ; statut 1 au moindre [ECHEC].
set -euo pipefail

LIGNES_REQUISES=("Run :" "Commit calculé :" "Image :" "Plateforme :" "Empreinte :" "Visa :")

# Contrôle d'un commit ; affiche les [ECHEC] et rend 1 si le commit en a, 0 sinon (y compris
# s'il ne touche pas tests/reference/).
controler_commit() {
  local c="$1" fichiers autres message parents parent calcule provenance empreinte md5 statut=0
  fichiers=$(git diff-tree --no-commit-id --name-only -r --root "$c")
  if ! grep -q '^tests/reference/' <<<"$fichiers"; then
    return 0
  fi
  autres=$(grep -v '^tests/reference/' <<<"$fichiers" || true)
  if [ -n "$autres" ]; then
    echo "[ECHEC] $c : un commit de référence ne touche que tests/reference/ (aussi : $(tr '\n' ' ' <<<"$autres"))"; statut=1
  fi
  message=$(git log -1 --format=%B "$c")
  for l in "${LIGNES_REQUISES[@]}"; do
    if ! grep -q "^$l " <<<"$message"; then
      echo "[ECHEC] $c : ligne « $l » absente du message"; statut=1
    elif grep "^$l " <<<"$message" | grep -qE '<|JJ/MM/AAAA|#NN'; then
      echo "[ECHEC] $c : ligne « $l » non remplie (champ du squelette : <…>, JJ/MM/AAAA ou #NN)"; statut=1
    fi
  done
  parents=$(git rev-list --parents -n 1 "$c" | wc -w)
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
  local plage="$1" n=0 echecs=0 c
  for c in $(git rev-list --no-merges --reverse "$plage"); do
    n=$((n + 1))
    controler_commit "$c" || echecs=$((echecs + 1))
  done
  if [ "$echecs" -gt 0 ]; then return 1; fi
  echo "[OK] $n commit(s) contrôlé(s) dans $plage : commits de référence conformes ou absents"
}

# Témoins négatifs (dépôt temporaire) : un commit de référence conforme passe ; un commit qui
# touche aussi un autre fichier, un commit dont l'empreinte est fausse, un commit dont le
# commit calculé n'est pas le parent, un commit sans ligne « Visa : » et deux commits dont la
# ligne « Visa : » garde un champ du squelette échouent.
temoins() {
  local d calc bon statut=0
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
  if [ "$statut" -eq 0 ]; then
    echo "[OK] témoins : commit conforme admis ; autre fichier, empreinte fausse, commit calculé non parent, Visa absent, Visa du squelette, date non remplie refusés"
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
