# Motifs de noms de paquets Java, LUS LIGNE A LIGNE (jamais executes) par
# tests/controles/paquets_java.sh (#139, Q-33, M370) : ce fichier n'est pas un script, son
# extension est conservee pour l'exclusion nominative d'absence_java.R. Format : un motif par
# ligne (ERE bash, appliquee au nom complet du paquet, suffixe :arch retire) ; lignes vides et
# lignes commencant par # (apres espaces) admises ; \r final retire. Un motif n'a que des
# caracteres de [A-Za-z0-9._^$|()*+?{},[]-] (ni espace, ni guillemet, ni barre oblique) ; toute autre ligne (commande, ancien format
# MOTIFS=(...), ERE invalide) est une erreur de forme (statut 2) ; un fichier sans motif aussi.
# Noms de paquets Debian et Ubuntu :
#   *-java, *-java-* (libreoffice-java-common), java-* (java-common), *-jni, default-jre*,
#   default-jdk*, OpenJDK (^openjd) et OpenJFX (^openjf), temurin-*, zulu*, jarwrapper*, gcj-*.
# « openjade » n'est pas attrape (^openjd et ^openjf, et non ^openj).
# EXCLUSION DECLAREE de tests/controles/absence_java.R (EXCLUS, #120, M360) : ce fichier
# INTERDIT des noms de paquets d'environnements Java et n'en installe aucun ; absence_java.R
# prendrait un nom de JDK ecrit en clair pour une installation. La seule justification de
# l'exclusion est celle-ci : n'y mettre que des motifs. paquets_java.sh, lui, reste balaye.
# Un ajout de motif se fait ici, avec sa raison, et son temoin (tests/unitaires/controles.R).

-java$
-java-
^java-
-jni$
^default-j(re|dk)
^openjd
^openjf
^temurin-
^zulu
^jarwrapper
^gcj-
