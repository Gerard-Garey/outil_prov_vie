#!/usr/bin/env bash
###############################################################################
#  .claude/hooks/installer_latex.sh  --  HOOK SessionStart DE CLAUDE CODE
#
#  Installe TeX Live (paquets du depot Ubuntu 24.04) dans une session cloud.
#  Le conteneur d'une session cloud ne contient pas pdflatex, sans lequel la
#  documentation de fond (docs/latex/) ne se compile pas.
#
#  - Sessions cloud seulement (CLAUDE_CODE_REMOTE=true) : le poste du
#    mainteneur a sa propre distribution LaTeX.
#  - N'installe que si pdflatex manque : le hook tourne a chaque demarrage,
#    reprise, /clear et compaction, et la session attend sa fin.
#  - Paquets : la liste du job « Documents LaTeX » de .github/workflows/ci.yml
#    (etape « TeX Live et R »), a tenir alignee avec lui. Difference voulue :
#    le hook installe avec --no-install-recommends, la CI avec les paquets
#    recommandes. Motif : ils entrainent default-jre (recommande par
#    texlive-latex-extra), or CLAUDE.md interdit toute dependance a Java,
#    interdiction que le mainteneur etend a la chaine de documentation
#    (decision du 12/11/2026). Ce choix ne suffit pas : texlive-latex-extra
#    depend encore de libpdfbox-java et libcommons-logging-java. Le retrait
#    de Java de la chaine LaTeX (hook et CI) est l'objet de l'issue #95.
#    Les deux documents de docs/latex/ se compilent sans les recommandes
#    (mesure de l'audit du correctif #26).
#  - Le hook n'echoue jamais : sans reseau, la session demarre sans LaTeX et
#    un message le signale.
###############################################################################

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

PAQUETS="texlive-latex-base texlive-latex-extra texlive-fonts-recommended texlive-lang-french tex-gyre"

if command -v pdflatex >/dev/null 2>&1; then
  exit 0
fi

if [ "$(id -u)" -eq 0 ]; then
  sudo_si_besoin=""
elif command -v sudo >/dev/null 2>&1; then
  sudo_si_besoin="sudo"
else
  echo "ATTENTION : pdflatex absent et installation impossible (ni root ni sudo)." >&2
  exit 0
fi

echo "Installation de TeX Live ($PAQUETS)..." >&2
# Un depot tiers injoignable ne fait qu'un avertissement d'apt-get update ;
# la disponibilite des paquets est controlee par l'installation elle-meme.
# Les hooks d'un meme evenement SessionStart s'executent en parallele (R et
# TeX Live) : « apt-get update » prend /var/lib/apt/lists/lock, que
# DPkg::Lock::Timeout ne couvre pas (mesure) ; on le reessaie donc quelques fois.
for _ in 1 2 3 4 5 6; do
  $sudo_si_besoin apt-get update -qq >/dev/null 2>&1 && break
  sleep 10
done
# apt-get n'attend pas le verrou dpkg par defaut (« E: Could not get lock »,
# code 100) : DPkg::Lock::Timeout=600 fait attendre l'installation jusqu'a
# 600 s la fin de l'installation de l'autre hook. Delai du hook (settings.json) :
# 600 s d'attente + 60 s de reessais d'update + 900 s de travail propre.
# env transmet DEBIAN_FRONTEND a travers sudo.
# PAQUETS est volontairement non cite : une option par mot.
# shellcheck disable=SC2086
if ! $sudo_si_besoin env DEBIAN_FRONTEND=noninteractive apt-get \
       -o DPkg::Lock::Timeout=600 install -y -qq \
       --no-install-recommends $PAQUETS >/dev/null 2>&1; then
  echo "ATTENTION : installation de TeX Live echouee ; pdflatex est absent de cette session." >&2
  exit 0
fi

if command -v pdflatex >/dev/null 2>&1; then
  echo "TeX Live installe pour cette session."
else
  echo "ATTENTION : paquets TeX Live installes mais pdflatex introuvable."
fi

exit 0
