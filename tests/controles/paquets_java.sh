#!/usr/bin/env bash
###############################################################################
#  tests/controles/paquets_java.sh  --  aucun paquet Java installe par une chaine
#  de documentation (CLAUDE.md, « Architecture » ; ADR 0004, point 6 ; issues #95, #120).
#
#  Controle des PAQUETS SYSTEME (apt, dpkg). Il complete absence_java.R, dont le
#  perimetre est les FICHIERS du depot (DESCRIPTION, fichiers suivis) et qui ne voit
#  aucun paquet systeme. Partage par le job « Documents LaTeX » de
#  .github/workflows/ci.yml et par le hook .claude/hooks/installer_latex.sh.
#
#  Usage :
#    bash tests/controles/paquets_java.sh --lister > liste.txt
#        paquets a l'etat « ii » (dpkg-query), un par ligne, tries (LC_ALL=C) ; statut 2 si
#        la liste est vide, statut non nul si dpkg-query echoue.
#    bash tests/controles/paquets_java.sh AVANT APRES
#        AVANT et APRES : listes de paquets, un nom par ligne (sortie de --lister, avant
#        puis apres l'installation ; le suffixe :arch et le \r final sont retires). Le
#        controle porte sur la DIFFERENCE (paquets presents dans APRES et absents de
#        AVANT), car l'image d'un runner contient deja des JDK : seule l'installation par
#        la chaine est en cause. Une liste APRES vide est refusee (statut 2) : une machine
#        sous dpkg n'a jamais zero paquet.
#  Sortie : [OK] / [ECHEC] <paquet> : motif ; avec GITHUB_ACTIONS=true, une annotation
#  ::error:: en plus. Statut 0 (aucun paquet Java installe), 1 (au moins un [ECHEC]),
#  2 (usage, fichier illisible, liste vide, fichier de motifs absent ou de forme invalide).
#
#  Motifs : tests/controles/paquets_java_motifs.txt (noms de paquets Debian et Ubuntu), LU
#  ligne a ligne et jamais execute (#139) : un motif (ERE bash) par ligne, lignes vides et
#  commentaires # admis. Toute ligne qui n'a pas la forme d'un motif (caracteres hors de la
#  forme d'un motif, commande a plusieurs mots, ERE invalide) et un fichier sans motif sont une
#  erreur de forme (statut 2) ; une commande d'un seul mot (reboot) a la forme d'un motif : elle
#  est lue comme un motif, jamais executee (#180). Le present fichier ne cite aucun nom Java : il
#  est balaye par absence_java.R ; le fichier de motifs, d'extension .txt, ne l'est pas.
#
#  Limite qui demeure : le controle se fait PAR NOM DE PAQUET. Un paquet Java d'un autre
#  nom (JDK d'un tiers, bibliotheque dont le nom ne dit rien de Java) passe au travers,
#  de meme que ce qui s'installe hors de dpkg (tlmgr, pip, R, archive decompressee) et ce
#  qui est deja present dans AVANT.
#
#  Bash et utilitaires POSIX (dpkg-query et awk pour --lister seulement).
###############################################################################

set -euo pipefail

if [ "${1:-}" = "--lister" ] && [ "$#" -eq 1 ]; then
  # shellcheck disable=SC2016  # ${...} appartient au format de dpkg-query, pas au shell
  liste="$(dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' | awk '$1=="ii"{print $2}' | LC_ALL=C sort)"
  if [ -z "$liste" ]; then
    echo "[ECHEC] aucun paquet installe releve par dpkg-query" >&2
    exit 2
  fi
  printf '%s\n' "$liste"
  exit 0
fi

if [ "$#" -ne 2 ]; then
  echo "[ECHEC] usage : paquets_java.sh --lister | paquets_java.sh AVANT APRES" >&2
  exit 2
fi
avant="$1"
apres="$2"
for f in "$avant" "$apres"; do
  if [ ! -r "$f" ]; then
    echo "[ECHEC] fichier illisible : $f" >&2
    exit 2
  fi
done

fichier_motifs="$(dirname "${BASH_SOURCE[0]}")/paquets_java_motifs.txt"
if [ ! -r "$fichier_motifs" ]; then
  echo "[ECHEC] fichier de motifs illisible : $fichier_motifs" >&2
  exit 2
fi
# Lecture sans execution : un motif par ligne (ERE bash), ni source ni eval. Forme d'un motif :
# caracteres de [A-Za-z0-9._^$|()*+?{},[]-] seulement, ERE compilable ; \r final retire.
LC_ALL=C
forme_motif='^[][A-Za-z0-9._^$|()*+?{},-]+$'
MOTIFS=()
numero=0
while IFS= read -r ligne || [ -n "$ligne" ]; do
  numero=$((numero + 1))
  ligne="${ligne%$'\r'}"
  if [[ "$ligne" =~ ^[[:space:]]*(#.*)?$ ]]; then
    continue
  fi
  rc=0
  [[ "$ligne" =~ $forme_motif ]] || rc=1
  if [ "$rc" -eq 0 ]; then
    [[ "" =~ $ligne ]] || rc=$?
    [ "$rc" -le 1 ] && rc=0
  fi
  if [ "$rc" -ne 0 ]; then
    echo "[ECHEC] $fichier_motifs, ligne $numero : ni commentaire ni motif valide (un motif ERE par ligne, sans espace)" >&2
    exit 2
  fi
  MOTIFS+=("$ligne")
done < "$fichier_motifs"
if [ "${#MOTIFS[@]}" -eq 0 ]; then
  echo "[ECHEC] $fichier_motifs : aucun motif" >&2
  exit 2
fi

# Noms nets : \r final et suffixe :arch retires, lignes vides ignorees, triees sans doublon.
noms() {
  { sed -e 's/\r$//' -e 's/:.*$//' "$1" | grep -v '^[[:space:]]*$' || true; } | LC_ALL=C sort -u
}
noms_apres="$(noms "$apres")"
if [ -z "$noms_apres" ]; then
  echo "[ECHEC] liste APRES vide : $apres" >&2
  exit 2
fi
installes="$(LC_ALL=C comm -13 <(noms "$avant") <(printf '%s\n' "$noms_apres"))"

n=0
n_echec=0
while IFS= read -r paquet; do
  if [ -z "$paquet" ]; then
    continue
  fi
  n=$((n + 1))
  for motif in "${MOTIFS[@]}"; do
    if [[ "$paquet" =~ $motif ]]; then
      echo "[ECHEC] $paquet : paquet Java installe par la chaine (motif $motif ; CLAUDE.md, « Architecture »)"
      if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
        echo "::error::paquet Java installe par la chaine : $paquet (CLAUDE.md, Architecture ; issues #95, #120)"
      fi
      n_echec=$((n_echec + 1))
      break
    fi
  done
done <<< "$installes"

if [ "$n_echec" -gt 0 ]; then
  exit 1
fi
echo "[OK] $n paquet(s) installe(s), aucun paquet Java (controle par nom de paquet)"
exit 0
