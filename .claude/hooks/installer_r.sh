#!/usr/bin/env bash
###############################################################################
#  .claude/hooks/installer_r.sh  --  HOOK SessionStart DE CLAUDE CODE
#
#  Installe R 4.3.3 (paquet r-base-core du depot Ubuntu 24.04) dans une
#  session cloud. Le conteneur d'une session cloud ne contient pas R, sans
#  lequel ni le package provie ni les batteries de CLAUDE.md ne s'executent.
#
#  - Sessions cloud seulement (CLAUDE_CODE_REMOTE=true) : le poste du
#    mainteneur a son propre R 4.3.3.
#  - N'installe que si R 4.3.3 manque : le hook tourne a chaque demarrage,
#    reprise, /clear et compaction, et la session attend sa fin.
#  - R s'installe sans package CRAN : le moteur n'emploie que les packages
#    de priorite base (ADR 0004).
#  - Ce R sert au developpement et aux mesures ; la plateforme de reference
#    reste celle de la CI (ADR 0010).
#  - Le hook n'echoue jamais : sans reseau, la session demarre sans R et un
#    message le signale.
###############################################################################

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

VERSION_R="4.3.3"

version_installee() {
  # shellcheck disable=SC2016  # le $ appartient a l'expression R, pas au shell
  Rscript -e 'cat(paste(R.version$major, R.version$minor, sep = "."))' 2>/dev/null
}

if command -v Rscript >/dev/null 2>&1 && [ "$(version_installee)" = "$VERSION_R" ]; then
  exit 0
fi

if [ "$(id -u)" -eq 0 ]; then
  sudo_si_besoin=""
elif command -v sudo >/dev/null 2>&1; then
  sudo_si_besoin="sudo"
else
  echo "ATTENTION : R $VERSION_R absent et installation impossible (ni root ni sudo)." >&2
  exit 0
fi

echo "Installation de R $VERSION_R (r-base-core)..." >&2
# Un depot tiers injoignable ne fait qu'un avertissement d'apt-get update ;
# la disponibilite de r-base-core est controlee par l'installation elle-meme.
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
# 600 s d'attente + 60 s de reessais d'update + 600 s de travail propre.
# env transmet DEBIAN_FRONTEND a travers sudo.
if ! $sudo_si_besoin env DEBIAN_FRONTEND=noninteractive apt-get \
       -o DPkg::Lock::Timeout=600 install -y -qq \
       --no-install-recommends r-base-core >/dev/null 2>&1; then
  echo "ATTENTION : installation de r-base-core echouee ; R est absent de cette session." >&2
  exit 0
fi

installee="$(version_installee)"
if [ "$installee" = "$VERSION_R" ]; then
  echo "R $VERSION_R installe pour cette session."
else
  echo "ATTENTION : R ${installee:-introuvable} installe au lieu de R $VERSION_R (depot du systeme)."
fi

exit 0
