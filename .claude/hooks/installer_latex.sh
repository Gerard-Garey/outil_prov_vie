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
#  - N'installe que si pdflatex ou framed.sty manque : le hook tourne a chaque demarrage,
#    reprise, /clear et compaction, et la session attend sa fin.
#  - Paquets : la liste du job « Documents LaTeX » de .github/workflows/ci.yml
#    (etape « TeX Live et R »), a tenir alignee avec lui, installes avec
#    --no-install-recommends. Motif : CLAUDE.md interdit toute dependance a
#    Java, interdiction que le mainteneur etend a la chaine de documentation
#    (decision du 12/11/2026, issue #95). texlive-latex-extra n'est donc pas
#    installe : il depend de libpdfbox-java et libcommons-logging-java et
#    recommande default-jre. Il ne fournit aux documents de docs/latex/ que
#    framed.sty : on telecharge son .deb (apt-get download) et on n'en extrait
#    que ce fichier, place dans TEXMFLOCAL (/usr/local/share/texmf).
#  - Controle Java (issue #120) : la liste des paquets installes est relevee avant et
#    apres l'installation, et tests/controles/paquets_java.sh (partage avec le job
#    « Documents LaTeX ») refuse tout paquet Java de la difference. Un paquet Java
#    installe est signale par un message (le hook n'echoue jamais). Limites : controle
#    par nom de paquet (voir l'en-tete du script) ; la difference peut contenir les
#    paquets qu'installe en parallele le hook de R, ce qui ne fait que durcir le
#    controle ; sans installation (pdflatex et framed.sty deja la), aucun controle.
#  - Le hook n'echoue jamais : sans reseau, la session demarre sans LaTeX et
#    un message le signale.
###############################################################################

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

PAQUETS="texlive-latex-base texlive-latex-recommended texlive-fonts-recommended texlive-lang-french tex-gyre"

# Rien a faire si pdflatex et framed.sty sont deja la ; si une installation
# precedente a laisse pdflatex sans framed.sty, le hook reprend.
if command -v pdflatex >/dev/null 2>&1 && command -v kpsewhich >/dev/null 2>&1 \
   && [ -n "$(kpsewhich framed.sty 2>/dev/null)" ]; then
  exit 0
fi

if [ "$(id -u)" -eq 0 ]; then
  sudo_si_besoin=""
elif command -v sudo >/dev/null 2>&1; then
  sudo_si_besoin="sudo"
else
  echo "ATTENTION : pdflatex ou framed.sty absent et installation impossible (ni root ni sudo)." >&2
  exit 0
fi

# Controle Java : liste des paquets avant l'installation (vide si le script ou dpkg-query manque).
CONTROLE_JAVA="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)/tests/controles/paquets_java.sh"
paquets_avant=""
paquets_apres=""
# Fichiers temporaires retires a toute sortie (y compris l'exit 0 apres un echec d'apt-get).
trap 'rm -f "$paquets_avant" "$paquets_apres"' EXIT
if [ -f "$CONTROLE_JAVA" ] && command -v dpkg-query >/dev/null 2>&1; then
  paquets_avant="$(mktemp)" || paquets_avant=""
  if [ -n "$paquets_avant" ] && ! bash "$CONTROLE_JAVA" --lister > "$paquets_avant" 2>/dev/null; then
    rm -f "$paquets_avant"
    paquets_avant=""
  fi
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

# Controle Java : aucun paquet Java dans la difference avant / apres (framed.sty, ci-dessous,
# ne passe pas par dpkg). Signale seulement : le hook n'echoue jamais.
if [ -n "$paquets_avant" ]; then
  paquets_apres="$(mktemp)" || paquets_apres=""
  if [ -n "$paquets_apres" ] && bash "$CONTROLE_JAVA" --lister > "$paquets_apres" 2>/dev/null; then
    bash "$CONTROLE_JAVA" "$paquets_avant" "$paquets_apres" >&2 \
      || echo "ATTENTION : paquet Java installe par ce hook (CLAUDE.md, « Architecture » ; issue #120)." >&2
  fi
  rm -f "$paquets_avant" "$paquets_apres"
fi

# framed.sty seul, extrait du .deb de texlive-latex-extra (non installe : voir
# l'en-tete). Retourne non nul au premier echec ; l'appelant le signale et sort
# avec le code 0.
installer_framed() {
  local tmp f statut
  tmp="$(mktemp -d)" || return 1
  f=usr/share/texlive/texmf-dist/tex/latex/framed/framed.sty
  # Le .deb se telecharge dans tmp (apt-get download ecrit dans le repertoire courant).
  (cd "$tmp" && apt-get -o APT::Sandbox::User=root download texlive-latex-extra) >/dev/null 2>&1 \
    && dpkg-deb --fsys-tarfile "$tmp"/texlive-latex-extra_*.deb | tar -x -C "$tmp" "./$f" \
    && $sudo_si_besoin install -D -m 644 "$tmp/$f" /usr/local/share/texmf/tex/latex/framed/framed.sty \
    && $sudo_si_besoin mktexlsr /usr/local/share/texmf >/dev/null 2>&1
  statut=$?
  rm -rf "$tmp"
  return $statut
}

if ! installer_framed || [ -z "$(kpsewhich framed.sty 2>/dev/null)" ]; then
  echo "ATTENTION : framed.sty n'a pas pu etre installe ; les documents de docs/latex/ ne se compileront pas." >&2
  exit 0
fi

if command -v pdflatex >/dev/null 2>&1; then
  echo "TeX Live installe pour cette session."
else
  echo "ATTENTION : paquets TeX Live installes mais pdflatex introuvable."
fi

exit 0
