# Motifs de noms de paquets Java, charges par `source` (donc executes) par
# tests/controles/paquets_java.sh : ne pas l'executer seul. Un motif par element du tableau
# MOTIFS : ERE bash, appliquee au nom complet du paquet (suffixe :arch retire). Noms de
# paquets Debian et Ubuntu :
#   *-java, *-java-* (libreoffice-java-common), java-* (java-common), *-jni, default-jre*,
#   default-jdk*, OpenJDK (^openjd) et OpenJFX (^openjf), temurin-*, zulu*, jarwrapper*, gcj-*.
# « openjade » n'est pas attrape (^openjd et ^openjf, et non ^openj).
# EXCLUSION DECLAREE de tests/controles/absence_java.R (EXCLUS, #120, M360) : ce fichier
# INTERDIT des noms de paquets d'environnements Java et n'en installe aucun ; absence_java.R
# prendrait un nom de JDK ecrit en clair pour une installation. La seule justification de
# l'exclusion est celle-ci : n'y mettre que des motifs. paquets_java.sh, lui, reste balaye.
# Un ajout de motif se fait ici, avec sa raison, et son temoin (tests/unitaires/controles.R).

MOTIFS=(
  '-java$'
  '-java-'
  '^java-'
  '-jni$'
  '^default-j(re|dk)'
  '^openjd'
  '^openjf'
  '^temurin-'
  '^zulu'
  '^jarwrapper'
  '^gcj-'
)
