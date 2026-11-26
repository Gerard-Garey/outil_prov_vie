# Controle : appariements du moteur sur des cles (#158, site 8 ; specification `donnees` v1.8,
# par. 2.2, B.4, "Cle vide", M396 : une cle manquante ou vide ne s'apparie a rien ; une seule
# implementation de la regle, cle_renseignee() et apparier_cles() de R/donnees.R).
# Recensement EXHAUSTIF, sans heuristique de noms : tout appel a match(), a is.element() et a
# l'operateur %in% de R/donnees.R, R/engagement.R et R/risque_en_cours.R (parse avec srcref,
# getParseData) est recense, sauf, par construction syntaxique seulement :
#   - un appel dont la table de recherche (operande de droite de %in%, deuxieme argument de
#     match()) n'est faite que de constantes (chaine, nombre, TRUE, FALSE, c() de constantes) ;
#   - un appel dont la table de recherche est un symbole de constante du package : en majuscules
#     (FAMILLES_CALCUL, .TABLES_D03G) ET affecte au premier niveau d'un fichier de R/ (une
#     variable locale en majuscules n'est pas une constante).
# Le propre match() d'apparier_cles() n'est pas recense (seule implementation de la regle).
# Tout autre appel doit figurer dans la liste blanche LISTE_BLANCHE ci-dessous, reperee par
# fichier, fonction de premier niveau et jetons de l'appel (commentaires exclus, un espace entre
# jetons), avec une categorie FERMEE :
#   code         valeur de modalite, de cause, de type, de statut ou de date, nombre (jamais une cle) ;
#   indice       rang de ligne ou code de groupe (.code_groupe()), non une valeur de cle ;
#   metadonnee   nom de table, de colonne, de controle, de famille ou ligne du dictionnaire ;
#   cle_garantie cle renseignee par construction, la justification cite la ligne de la garde ;
#   a_instruire  appariement brut d'une cle de la base dont la regle de la cle vide n'est pas
#                etablie : releve, non corrige, a soumettre a `actuary` (ne vaut pas conformite) ;
#                la justification renvoie a une issue (#N) ; chaque entree est imprimee en
#                [RELEVE] (fichier, ligne, fonction, justification), sans faire echouer le script.
# Echec pour tout appel hors liste, pour toute categorie hors de la liste fermee et pour toute
# entree de la liste sans appel correspondant (liste perimee).
# Limites : ne voient pas les egalites `==` et `!=` entre vecteurs, l'indexation par nom, split(),
# intersect(), setdiff() et union() (qui apparient par match() sans passer par ces deux formes) ni
# les fonctions passees en argument (`Map(match, ...)`) ni rowsum() (regroupement par cle) ; une
# variable locale qui porte le nom d'une constante du package est prise pour cette constante
# (aucun appel recense) ; la forme prefixe de l'operateur, `%in%`(x, table), n'est pas vue (mesure :
# une fonction d'essai ajoutee a R/donnees.R n'est pas inventoriee) ; une
# garantie de non-appariement d'une cle n'est donc pas une preuve : voir l'issue 163 ("deux
# lectures de parametre de garantie souscrite", titre de l'issue ouverte le 17 novembre 2026)
# pour les lectures de parametres de garantie souscrite par split(), et l'issue 164 pour
# rowsum(), la variable locale homonyme et la forme prefixe.
# Usage, depuis la racine du depot : Rscript tests/controles/appariements_cles.R
# Un argument facultatif designe une autre racine ; l'option --inventaire imprime les cles des
# appels recenses (une par ligne) sans controler. Sortie : lignes [OK] / [RELEVE] / [ECHEC] ;
# statut 1 au moindre [ECHEC]. Code ASCII, R de base seulement (utils pour getParseData).

options(warn = 2)
.fichier_script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
.arguments <- commandArgs(trailingOnly = TRUE)
.inventaire <- "--inventaire" %in% .arguments
.arguments <- setdiff(.arguments, "--inventaire")
racine <- normalizePath(if (length(.arguments) >= 1L) .arguments[1L]
                        else file.path(dirname(.fichier_script), "..", ".."), mustWork = TRUE)
.n_echec <- 0L
ok <- function(message) cat("[OK] ", message, "\n", sep = "")
echec <- function(message) {
  .n_echec <<- .n_echec + 1L
  cat("[ECHEC] ", message, "\n", sep = "")
}
fin <- function() quit(save = "no", status = if (.n_echec > 0L) 1L else 0L)

FICHIERS <- file.path("R", c("engagement.R", "risque_en_cours.R", "donnees.R"))
CATEGORIES <- c("code", "indice", "metadonnee", "cle_garantie", "a_instruire")

# Liste blanche : cle de l'appel = valeur de la categorie (suivie, pour cle_garantie et
# a_instruire, de " : justification").
LISTE_BLANCHE <- c(
  "R/engagement.R | duree_annees | length ( debut ) %in% c ( 1L , n )" =
    "indice",
  "R/engagement.R | duree_annees | length ( fin ) %in% c ( 1L , n )" =
    "indice",
  "R/engagement.R | facteur_revalorisation | length ( debut ) %in% c ( 1L , n )" =
    "indice",
  "R/engagement.R | facteur_revalorisation | length ( fin ) %in% c ( 1L , n )" =
    "indice",
  "R/engagement.R | valeur_actuelle_probable | colonnes %in% names ( echeancier )" =
    "metadonnee",
  "R/engagement.R | parametre_vue | valeurs_vue ( vue , \"parametres\" , \"parametre\" ) %in% nom" =
    "code",
  "R/engagement.R | hypothese_vue | x $ poste %in% c ( poste , \"tous\" )" =
    "code",
  "R/engagement.R | hypothese_vue | lignes %in% h [[ j ] ] $ lignes" =
    "indice",
  "R/engagement.R | hypothese_vue | x $ colonnes %in% colonnes" =
    "metadonnee",
  "R/engagement.R | .salaire_d03c | match ( college , cles )" =
    "code",
  "R/engagement.R | .reconstituer_capital | lien %in% parametres $ liens_conjoint_majoration" =
    "code",
  "R/engagement.R | statut_methode_catalogue | methode %in% m" =
    "code",
  "R/engagement.R | calculer_engagement | \"beneficiaire_non_identifie\" %in% p2 $ critere" =
    "code",
  "R/engagement.R | calculer_engagement | \"sans_evenement\" %in% p2 $ critere" =
    "code",
  "R/engagement.R | calculer_engagement | as.character ( y ) %in% names ( rv $ taux_par_annee )" =
    "code",
  "R/engagement.R | calculer_engagement | l $ table %in% tables" =
    "metadonnee",
  "R/engagement.R | calculer_engagement | l $ table %in% differees" =
    "metadonnee",
  "R/engagement.R | arret_refus_ligne | cle %in% pa $ candidats [[ i ] ]" =
    "metadonnee",
  "R/engagement.R | arret_refus_ligne | t %in% listees" =
    "metadonnee",
  "R/engagement.R | arret_refus_ligne | t %in% evaluees" =
    "metadonnee",
  "R/engagement.R | calculer_engagement | cle_poste %in% x" =
    "metadonnee",
  "R/engagement.R | arret_bilan_population | rt $ table %in% tables" =
    "metadonnee",
  "R/engagement.R | arret_bilan_population | nd $ table %in% tables" =
    "metadonnee",
  "R/risque_en_cours.R | calculer_risque_en_cours | cle_p3 %in% x" =
    "metadonnee",
  "R/risque_en_cours.R | .retrospective | a %in% dates_pas" =
    "code",
  "R/risque_en_cours.R | .retrospective | a %in% ajouter_mois ( rep ( e , n_pas ) , periode * seq_len ( n_pas ) )" =
    "indice",
  "R/risque_en_cours.R | provisions_collectives | match ( rownames ( s ) , ids )" =
    "cle_garantie : ids reunit contrat_g et hypothese : contrats apparies par apparier_cles() sur des garanties retenues par cle_renseignee() (gs, ct, i_gs)",
  "R/donnees.R | cles_lignes_hypothese | colonne %in% cles" =
    "metadonnee",
  "R/donnees.R | .inconnues_d03i | c1 %in% names ( ctx $ base [[ t ] ] )" =
    "metadonnee",
  "R/donnees.R | .appliquer_h_d03g | liens $ table_cible %in% cibles" =
    "metadonnee",
  "R/donnees.R | cles_lignes_hypothese | lignes %in% placees" =
    "indice",
  "R/donnees.R | .exclu_vue | liens $ table %in% intersect ( tables , .TABLES_CASCADE_EXCLUSION )" =
    "metadonnee",
  "R/donnees.R | .exclu_vue | liens $ table_cible %in% intersect ( tables , c ( \"sinistres\" , .TABLES_CASCADE_EXCLUSION ) )" =
    "metadonnee",
  "R/donnees.R | .exclu_vue | e $ table %in% tables" =
    "metadonnee",
  "R/donnees.R | etats_a_date | code %in% garanties" =
    "code",
  "R/donnees.R | etats_a_date | match ( type [ i ] , te $ type_evenement )" =
    "code",
  "R/donnees.R | segments_vue | vv ( \"garanties_souscrites\" , \"code_garantie\" ) %in% garanties" =
    "code",
  "R/donnees.R | .controler_extraction_base | x %in% modalites" =
    "code",
  "R/donnees.R | .lire_conventions | x %in% liste" =
    "code",
  "R/donnees.R | lire_declarations | names ( sa ) %in% names ( .EMPLOIS_D02C )" =
    "metadonnee",
  "R/donnees.R | lire_declarations | paste ( ex $ motif , ex $ famille ) %in% paste ( exceptions $ motif , exceptions $ famille )" =
    "metadonnee",
  "R/donnees.R | lire_declarations | ex $ motif %in% parents" =
    "code",
  "R/donnees.R | lire_declarations | hy $ motif %in% motifs_s" =
    "code",
  "R/donnees.R | lire_declarations | hy $ motif %in% parents" =
    "code",
  "R/donnees.R | lire_declarations | cle_s [ signalement ] %in% cle_s [ duplicated ( cle_s ) | duplicated ( cle_s , fromLast = TRUE ) ]" =
    "metadonnee",
  "R/donnees.R | .application_d03g | FAMILLES_CALCUL %in% ex $ famille [ ex $ motif == \"D03g\" ]" =
    "metadonnee",
  "R/donnees.R | .application_d03g | REFERENTIELS %in% hy $ referentiel [ hy $ motif == \"D03g\" ]" =
    "metadonnee",
  "R/donnees.R | .motif_admet | match ( motif , dico $ defauts $ code )" =
    "metadonnee",
  "R/donnees.R | .motif_admet | t %in% eclater_champ ( x )" =
    "code",
  "R/donnees.R | .contexte | dico $ tables $ table %in% names ( donnees )" =
    "metadonnee",
  "R/donnees.R | .valeurs | colonne %in% names ( df )" =
    "metadonnee",
  "R/donnees.R | .causes | colonne %in% names ( causes )" =
    "metadonnee",
  "R/donnees.R | .causes | colonne %in% names ( c1 )" =
    "metadonnee",
  "R/donnees.R | .regle | lit %in% admet" =
    "metadonnee",
  "R/donnees.R | .regle | lit [ i ] %in% names ( refusees )" =
    "metadonnee",
  "R/donnees.R | .regle | lit [ i ] %in% admet" =
    "metadonnee",
  "R/donnees.R | .regle | lit [ i ] %in% saute" =
    "metadonnee",
  "R/donnees.R | .regle | cause %in% z" =
    "code",
  "R/donnees.R | .portee_effective | colonne %in% cle" =
    "metadonnee",
  "R/donnees.R | .strates_regle_b | restants %in% vers [ reste ]" =
    "metadonnee",
  "R/donnees.R | .strates_regle_b | de %in% sources" =
    "metadonnee",
  "R/donnees.R | .index_jointure | match ( cle [ doubles ] , cle [ doubles ] )" =
    "cle_garantie : cle[doubles] exclut NA et \"\" par construction (ligne `doubles <- which(!is.na(cle) & !.chaine_vide(cle) & ...)`)",
  "R/donnees.R | .existe_kleene | match ( cle [ lignes_p ] , cle [ lignes_p ] )" =
    "cle_garantie : lignes_p <- which(possible & !is.na(cle)) apres cle <- .cle_manquante(cle) : cle[lignes_p] sans NA ni \"\"",
  "R/donnees.R | .chevauchements3 | x %in% gc $ domaine" =
    "code",
  "R/donnees.R | .chevauchements3 | match ( gc $ valeurs [ candidats ] , dom )" =
    "indice",
  "R/donnees.R | .chevauchements3 | ( seq_len ( taille ) - 1 ) %in% rang" =
    "indice",
  "R/donnees.R | .code_groupe | match ( x , unique ( x ) )" =
    "indice",
  "R/donnees.R | .code_groupe | match ( z , unique ( z ) )" =
    "indice",
  "R/donnees.R | .regle_forme | \"catastrophes\" %in% ctx $ tables" =
    "metadonnee",
  "R/donnees.R | .regle_forme | \"victimes\" %in% ctx $ tables" =
    "metadonnee",
  "R/donnees.R | .regle_domaine | tc %in% a_parcourir" =
    "metadonnee",
  "R/donnees.R | .regle_domaine | tc %in% soi" =
    "metadonnee",
  "R/donnees.R | .regles_generiques | colonne %in% names ( ctx $ base [[ table ] ] )" =
    "metadonnee",
  "R/donnees.R | .regles_generiques | x %in% modalites" =
    "code",
  "R/donnees.R | .programmable | match ( .valeurs ( ctx , \"evenements\" , \"type_evenement\" ) , te $ type_evenement )" =
    "code",
  "R/donnees.R | .programmable | motif [ i ] %in% eclater_champ ( substring ( prog [ i ] , 5L ) )" =
    "code",
  "R/donnees.R | .regles_propres | match ( x $ mois , 1 : 12 )" =
    "code",
  "R/donnees.R | .regles_propres | x $ code %in% garanties" =
    "code",
  "R/donnees.R | .regles_propres | match ( paste ( g , p ) , paste ( par $ code_garantie , par $ parametre ) )" =
    "indice",
  "R/donnees.R | .regles_propres | match ( p , par $ parametre [ par $ code_garantie == \"toutes\" ] )" =
    "indice",
  "R/donnees.R | .regles_propres | x $ p %in% par $ parametre" =
    "code",
  "R/donnees.R | .regles_propres | match ( unlist ( ids ) , u )" =
    "indice",
  "R/donnees.R | .regles_propres | match ( type , te $ type_evenement )" =
    "code",
  "R/donnees.R | .regles_propres | match ( x $ type , te $ type_evenement )" =
    "code",
  "R/donnees.R | .regles_propres | gg %in% eclater_champ ( liste )" =
    "code",
  "R/donnees.R | .regles_propres | colonne %in% eclater_champ ( r )" =
    "metadonnee",
  "R/donnees.R | .regles_propres | m %in% eclater_champ ( liste )" =
    "code",
  "R/donnees.R | .regle_signe | match ( nature , names ( regles ) )" =
    "metadonnee",
  "R/donnees.R | .regle_cles | match ( c1 , col $ colonne )" =
    "metadonnee",
  "R/donnees.R | .orphelines | valeurs_locales [[ m ] ] %in% domaine" =
    "metadonnee",
  "R/donnees.R | .orphelines | seq_along ( cible ) %in% l" =
    "indice",
  "R/donnees.R | .chevauchements | match ( groupe [ ok ] , unique ( groupe [ ok ] ) )" =
    "indice",
  "R/donnees.R | .refus_induits | t %in% ctx $ tables" =
    "metadonnee",
  "R/donnees.R | .refus_induits | u %in% refusees" =
    "metadonnee",
  "R/donnees.R | .refus_induits | u %in% origines [[ t ] ]" =
    "metadonnee",
  "R/donnees.R | .refus_induits | t %in% refusees" =
    "metadonnee",
  "R/donnees.R | .refus_induits | dico $ tables $ table %in% origines [[ t ] ]" =
    "metadonnee",
  "R/donnees.R | .refus_regle_b | t %in% vues" =
    "metadonnee",
  "R/donnees.R | .causes_enjeu | colonne %in% .DATES_VISIBILITE [[ table ] ]" =
    "metadonnee",
  "R/donnees.R | .causes_enjeu | colonne %in% names ( c1 )" =
    "metadonnee",
  "R/donnees.R | .causes_enjeu | ctx $ dico $ colonnes $ colonne %in% colonne" =
    "metadonnee",
  "R/donnees.R | .causes_enjeu | d $ colonne %in% ecart $ colonne" =
    "metadonnee",
  "R/donnees.R | .causes_enjeu | dr $ colonne %in% ecart $ colonne" =
    "metadonnee",
  "R/donnees.R | .refus_ligne_lus | m [ 2L ] %in% .DATES_VISIBILITE [[ m [ 1L ] ] ]" =
    "metadonnee",
  "R/donnees.R | .refus_ligne_lus | tc %in% valeur" =
    "metadonnee",
  "R/donnees.R | .refus_p_empechee | t %in% names ( empechees )" =
    "metadonnee",
  "R/donnees.R | .refus_p_empechee | t %in% ctx $ tables" =
    "metadonnee",
  "R/donnees.R | .refus_p_empechee | t %in% deja" =
    "metadonnee",
  "R/donnees.R | .refus_p_empechee | u %in% refusees" =
    "metadonnee",
  "R/donnees.R | .refus_p_empechee | u %in% origines [[ t ] ]" =
    "metadonnee",
  "R/donnees.R | .refus_p_empechee | t %in% refusees" =
    "metadonnee",
  "R/donnees.R | .refus_p_empechee | dico $ tables $ table %in% o" =
    "metadonnee",
  "R/donnees.R | .inconnu | seq_len ( NROW ( ctx $ base [[ table ] ] ) ) %in% .lignes_refusees ( ctx , table , colonne )" =
    "indice",
  "R/donnees.R | .programmable3 | match ( .valeurs ( ctx , \"evenements\" , \"type_evenement\" ) , te $ type_evenement )" =
    "code",
  "R/donnees.R | .h_d02b | REFERENTIELS %in% hyp $ referentiel [ hyp $ motif == \"D02b\" ]" =
    "metadonnee",
  "R/donnees.R | .regle_prealable | f [[ 4L ] ] %in% ctx $ tables" =
    "metadonnee",
  "R/donnees.R | .appliquer_h_d03g | liens $ table %in% ctx $ tables" =
    "metadonnee",
  "R/donnees.R | .appliquer_h_d03g | liens $ table_cible %in% ctx $ tables" =
    "metadonnee",
  "R/donnees.R | .appliquer_h_d03g | reste %in% .lignes_refusees ( ctx , t , effet [[ t ] ] )" =
    "indice",
  "R/donnees.R | .construire_vue | liens $ table %in% ctx $ tables" =
    "metadonnee",
  "R/donnees.R | .construire_vue | liens $ table_cible %in% ctx $ tables" =
    "metadonnee",
  "R/donnees.R | .construire_vue | \"famille\" %in% tables" =
    "metadonnee",
  "R/donnees.R | .construire_vue | liens $ table %in% asc" =
    "metadonnee",
  "R/donnees.R | .refus_vue | \"evenements\" %in% ctx $ tables" =
    "metadonnee",
  "R/donnees.R | .refus_vue | match ( .valeurs ( ctx , \"evenements\" , \"type_evenement\" ) , te $ type_evenement )" =
    "code",
  "R/donnees.R | .refus_vue | c1 %in% .DATES_VISIBILITE [[ t ] ]" =
    "metadonnee",
  "R/donnees.R | .valeurs_vue | colonne %in% p $ colonnes" =
    "metadonnee",
  "R/donnees.R | .verdict_vue | r0 [ autres ] %in% r0 [ i ]" =
    "code",
  "R/donnees.R | .verdict_vue | \"famille\" %in% names ( index0 )" =
    "metadonnee",
  "R/donnees.R | .cause_nd | liens $ table %in% ctx $ tables" =
    "metadonnee",
  "R/donnees.R | .cause_nd | liens $ table_cible %in% ctx $ tables" =
    "metadonnee",
  "R/donnees.R | .verdict_vue | r0 [ c1 ] %in% r0 [ i ]" =
    "code",
  "R/donnees.R | .somme_parts3 | match ( dossier , rownames ( somme ) )" =
    "a_instruire : somme_parts : beneficiaires.id_dossier \"\" regroupe par rowsum() (ok <- !is.na(dossier) seul) ; releve, #164",
  "R/donnees.R | .somme_parts3 | dossier %in% brut [ nd ]" =
    "a_instruire : somme_parts : id_dossier \"\" des beneficiaires non determines apparie a \"\" ; releve, #164",
  "R/donnees.R | .somme_parts3 | dossier %in% k" =
    "a_instruire : somme_parts, parts refusees (#105, G1) : meme appariement des dossiers que la regle v1.5.4 ; releve, #164",
  "R/donnees.R | .somme_parts3 | k %in% dossier [ refusees ]" =
    "a_instruire : somme_parts, parts refusees (#105, G1) : idem ; releve, #164",
  "R/donnees.R | .somme_parts3 | brut [ nd ] %in% k" =
    "a_instruire : somme_parts, parts refusees (#105, G1) : idem, beneficiaires non determines ; releve, #164",
  "R/donnees.R | .somme_parts3 | dossier [ refusees ] %in% k" =
    "a_instruire : somme_parts, parts refusees (#105, G1) : idem ; releve, #164",
  "R/donnees.R | .somme_parts3 | brut [ nd_inconnu ] %in% k" =
    "a_instruire : somme_parts, parts refusees (#105, G1) : idem, beneficiaires non determines ; releve, #164",
  "R/donnees.R | .somme_parts3 | dossier %in% dossiers_inconnus" =
    "a_instruire : somme_parts, parts refusees (#105, G1) : idem ; releve, #164",
  "R/donnees.R | .regle_v_parente_posterieure | liens $ table %in% ctx $ tables" =
    "metadonnee",
  "R/donnees.R | .regle_v_parente_posterieure | liens $ table_cible %in% ctx $ tables" =
    "metadonnee",
  "R/donnees.R | .regle_v_parente_posterieure | fx %in% k $ lignes" =
    "indice",
  "R/donnees.R | .regle_v_parente_posterieure | fx %in% couvertes" =
    "indice",
  "R/donnees.R | .regle_v_manquants | match ( x $ type , te $ type_evenement )" =
    "code",
  "R/donnees.R | .regle_v_ordre_dates | y %in% p $ colonnes" =
    "metadonnee",
  "R/donnees.R | .copies3 | match ( seq_len ( n ) , order ( as.numeric ( .valeurs ( ctx , table , date ) ) , cles , method = \"radix\" , na.last = TRUE ) )" =
    "indice",
  "R/donnees.R | .regle_v_doublons | match ( groupe , groupe )" =
    "indice",
  "R/donnees.R | .regle_v_doublons | match ( seq_along ( retenu ) , o2 )" =
    "indice",
  "R/donnees.R | .regle_v_doublons | match ( groupe [ rang [ l ] ] , as.integer ( names ( nd_groupe ) ) )" =
    "indice",
  "R/donnees.R | .ou3 | ligne [ garde ] %in% vrai" =
    "indice",
  "R/donnees.R | .ou3 | t [[ b ] ] %in% t [[ a ] ]" =
    "indice",
  "R/donnees.R | .age_assure3 | refs $ p %in% lignes_c" =
    "indice",
  "R/donnees.R | .age_assure3 | \"vrai\" %in% s1" =
    "code",
  "R/donnees.R | .age_assure3 | \"faux\" %in% s1" =
    "code",
  "R/donnees.R | .age_assure3 | c ( \"faux\" , \"indefini\" ) %in% s1" =
    "code",
  "R/donnees.R | .age_assure3 | \"indefini\" %in% s1" =
    "code",
  "R/donnees.R | .age_assure3 | match ( c ( o , y ) , ordre_issue )" =
    "code",
  "R/donnees.R | .verdict_d11c | groupe3 %in% groupe3 [ porteuses ]" =
    "indice",
  "R/donnees.R | .verdict_d11c | groupe3 %in% groupe3 [ l ]" =
    "indice",
  "R/donnees.R | .regle_v_garanties | sinistre %in% avec_deces [ ! is.na ( avec_deces ) ]" =
    "a_instruire : D10 : id_sinistre \"\" (valeur brute de .joindre()) apparie a \"\" ; releve, #164",
  "R/donnees.R | .regle_v_garanties | sub ( \"\\\\..*$\" , \"\" , lit_c ) %in% names ( ctx $ base )" =
    "metadonnee",
  "R/donnees.R | .garantie_en_vigueur3 | .valeurs_vue ( ctx , \"garanties_souscrites\" , \"code_garantie\" ) %in% code" =
    "code",
  "R/donnees.R | .garantie_en_vigueur3 | v ( \"code_garantie\" ) %in% code" =
    "code",
  "R/donnees.R | .colonne_partie | x %in% k $ lignes" =
    "indice",
  "R/donnees.R | .age_assure3 | match ( a , ordre_issue )" =
    "code",
  "R/donnees.R | .age_assure3 | match ( b , ordre_issue )" =
    "code",
  "R/donnees.R | .regle_v_limite_age | v ( \"evenements\" , \"type_evenement\" ) %in% types" =
    "code",
  "R/donnees.R | .regle_v_limite_age | \"famille\" %in% names ( ctx $ base )" =
    "metadonnee",
  "R/donnees.R | .regle_v_limite_age | cat %in% z" =
    "code",
  "R/donnees.R | .regle_v_limite_age | p $ i %in% incertain" =
    "indice",
  "R/donnees.R | .candidats_d07c | .joindre ( ctx , \"garanties_souscrites\" , \"id_garantie_souscrite\" , \"code_garantie\" , gs ) %in% code" =
    "code",
  "R/donnees.R | .parametre_garantie | .valeurs_vue ( ctx , \"parametres\" , \"parametre\" ) %in% nom" =
    "code",
  "R/donnees.R | .famille_en_jeu | \"famille\" %in% names ( ctx $ base )" =
    "metadonnee",
  "R/donnees.R | .famille_en_jeu | vis $ membre %in% vis $ membre [ st %in% TRUE ]" =
    "a_instruire : id_membre \"\" apparie a \"\" parmi les versions de famille ; releve, #164",
  "R/donnees.R | .peut_suivre | match ( x , te $ type_evenement )" =
    "code",
  "R/donnees.R | .statut_service | type [ k ] %in% types_unite" =
    "code",
  "R/donnees.R | .statut_service | type [ k ] %in% c ( types_unite , \"cloture_dossier\" )" =
    "code",
  "R/donnees.R | .service3 | st $ classe %in% classes" =
    "code",
  "R/donnees.R | .service3 | .classe_service ( type [ e ] ) %in% classes" =
    "code",
  "R/donnees.R | .versions_membre | p2 $ i %in% p1 $ i" =
    "indice",
  "R/donnees.R | .versions_membre | seq_along ( ids ) %in% c ( p1 $ i , p2 $ i )" =
    "indice",
  "R/donnees.R | .regle_v_extinctions | v ( \"famille\" , \"lien\" ) [ j ] %in% conjoints" =
    "code",
  "R/donnees.R | .regle_v_extinctions | seq_len ( nr ) %in% q1 $ i" =
    "indice",
  "R/donnees.R | .regle_v_rechutes | seq_len ( ns ) %in% p $ i [ candidate & ! is.na ( dl ) & ecart < dl ]" =
    "indice",
  "R/donnees.R | .regle_v_qualites | code %in% codes" =
    "code",
  "R/donnees.R | .regle_v_qualites | paste ( code , x $ qualite ) %in% compatibles" =
    "code",
  "R/donnees.R | .regle_v_couverture | sub ( \"\\\\..*$\" , \"\" , lit_c ) %in% names ( ctx $ base )" =
    "metadonnee",
  "R/donnees.R | .verdict_d11 | kd %in% kc [ cv $ certain ]" =
    "indice",
  "R/donnees.R | .verdict_d11 | kd %in% kc [ ! cv $ certain ]" =
    "indice",
  "R/donnees.R | .verdict_d11 | seq_len ( ns ) %in% cv $ i [ cv $ certain ]" =
    "indice",
  "R/donnees.R | .verdict_d11 | seq_len ( ns ) %in% cv $ i [ ! cv $ certain ]" =
    "indice",
  "R/donnees.R | .ecarter_maintien_d11 | tc %in% lit_m" =
    "metadonnee",
  "R/donnees.R | .ecarter_maintien_d11 | cause %in% z" =
    "code",
  "R/donnees.R | .pas_d12 | match ( type , te $ type_evenement )" =
    "code",
  "R/donnees.R | .pas_d12 | etat %in% eclater_champ ( te $ etat_depuis [ i ] )" =
    "code",
  "R/donnees.R | .pas_d12 | motif %in% strsplit ( sub ( \"^[^:]*:\" , \"\" , bloc ) , \",\" , fixed = TRUE ) [[ 1L ] ]" =
    "code",
  "R/donnees.R | .verdict_d12 | type %in% auto" =
    "code",
  "R/donnees.R | .verdict_d12 | match ( t , te $ type_evenement )" =
    "code",
  "R/donnees.R | .verdict_d12 | match ( auto , te $ type_evenement )" =
    "code",
  "R/donnees.R | .verdict_d12 | type [ g ] %in% t" =
    "code",
  "R/donnees.R | .verdict_d12 | match ( x , u )" =
    "indice",
  "R/donnees.R | .verdict_d12 | type %in% te $ type_evenement [ nzchar ( te $ motifs ) & ! is.na ( te $ motifs ) ]" =
    "code",
  "R/donnees.R | .verdict_d12 | match ( type , te $ type_evenement )" =
    "code",
  "R/donnees.R | .verdict_d12 | match ( tous , ordonner ( tous ) )" =
    "indice",
  "R/donnees.R | .verdict_d12 | lr %in% o $ echecs" =
    "indice",
  "R/donnees.R | .verdict_d14 | lien [ k ] %in% vise [[ k ] ]" =
    "code",
  "R/donnees.R | .visibilite_a | liens $ table %in% tables" =
    "metadonnee",
  "R/donnees.R | .visibilite_a | liens $ table_cible %in% tables" =
    "metadonnee",
  "R/donnees.R | .visibilite_a | \"famille\" %in% tables" =
    "metadonnee",
  "R/donnees.R | .visibilite_a | r [ 1L ] %in% tables" =
    "metadonnee",
  "R/donnees.R | .visibilite_a | t %in% tables" =
    "metadonnee",
  "R/donnees.R | .cause_colonnes | cause %in% x" =
    "code",
  "R/donnees.R | .ordre_dictionnaire | match ( t , dico $ tables $ table )" =
    "metadonnee",
  "R/donnees.R | .ordre_dictionnaire | match ( paste ( t , sub ( \"^[^.]*\\\\.\" , \"\" , lus ) ) , paste ( dico $ colonnes $ table , dico $ colonnes $ colonne ) )" =
    "metadonnee",
  "R/donnees.R | .paires | match ( y [ j ] , cles )" =
    "cle_garantie : y normalise par .cle_manquante() en tete, j <- which(!is.na(y)), cles <- unique(y[j])",
  "R/donnees.R | .paires | match ( x [ i ] , cles )" =
    "cle_garantie : x normalise par .cle_manquante() en tete, i <- which(!is.na(x)), cles sans NA",
  "R/donnees.R | .rattacher | seq_along ( x ) %in% p $ j" =
    "indice",
  "R/donnees.R | .dernier_evenement | match ( ev ( \"type_evenement\" ) , te $ type_evenement )" =
    "code",
  "R/donnees.R | .composantes_dossiers | type %in% c ( service , \"fin_service\" )" =
    "code",
  "R/donnees.R | .composantes_dossiers | type [ dernier ] %in% service" =
    "code",
  "R/donnees.R | .composantes_dossiers | seq_len ( nr ) %in% .paires ( v ( \"evenements\" , \"id_rente\" ) [ ki ] , id_rente ) $ j" =
    "indice",
  "R/donnees.R | .composantes_dossiers | type [ dernier_b ] %in% service" =
    "code",
  "R/donnees.R | .rattacher_composante | type [ l ] %in% x" =
    "code",
  "R/donnees.R | .placer | \"X\" %in% t" =
    "code",
  "R/donnees.R | .placer | ex $ famille %in% familles" =
    "metadonnee",
  "R/donnees.R | .placer | \"S\" %in% t" =
    "code",
  "R/donnees.R | .placer | \"H\" %in% t" =
    "code",
  "R/donnees.R | .placer | familles %in% e_k $ famille" =
    "metadonnee",
  "R/donnees.R | .placer | REFERENTIELS %in% c ( h_k $ referentiel , s_k $ referentiel )" =
    "metadonnee",
  "R/donnees.R | .placer | f %in% familles_declarees" =
    "metadonnee",
  "R/donnees.R | .ou_kleene | cle %in% cle [ x %in% TRUE ]" =
    "indice",
  "R/donnees.R | .ou_kleene | cle %in% cle [ is.na ( x ) ]" =
    "indice",
  "R/donnees.R | .statut_rattachement | p $ ligne %in% lignes" =
    "indice",
  "R/donnees.R | .enjeu_elementaire | tc %in% valeur" =
    "metadonnee",
  "R/donnees.R | .enjeu_elementaire | table %in% c ( .TABLES_DOSSIER , \"prestations\" )" =
    "metadonnee",
  "R/donnees.R | .enjeu_elementaire | paste ( ecart $ table , ecart $ colonne , sep = \".\" ) %in% cd $ lus_g" =
    "metadonnee",
  "R/donnees.R | .enjeu_elementaire | d %in% .divergences_d01a ( ctx , \"dossiers\" , lignes , c1 )" =
    "indice",
  "R/donnees.R | .enjeu_elementaire | v ( \"cotisations\" , \"nature_mouvement\" ) [ vus ] %in% natures" =
    "code",
  "R/donnees.R | .enjeu_elementaire | v ( \"cotisations\" , \"nature_mouvement\" ) [ indet ] %in% natures" =
    "code",
  "R/donnees.R | .enjeu_elementaire | el $ indice %in% touches" =
    "indice",
  "R/donnees.R | .enjeu_elementaire | match ( manque , dd $ dossier )" =
    "indice",
  "R/donnees.R | .enjeu_elementaire | c1 %in% .CLASSE_D01A [[ porteur ] ]" =
    "metadonnee",
  "R/donnees.R | .enjeu_elementaire | \"dossier\" %in% familles" =
    "metadonnee",
  "R/donnees.R | .enjeu_elementaire | paires $ ligne %in% rangs" =
    "indice",
  "R/donnees.R | .enjeu_elementaire | table %in% names ( .LUS_LIGNE_ENJEU )" =
    "metadonnee",
  "R/donnees.R | .enjeu_elementaire | d %in% g_refus" =
    "indice",
  "R/donnees.R | .enjeu_elementaire | dd $ dossier %in% g_refus" =
    "indice",
  "R/donnees.R | .enjeu_elementaire | match ( i , rl $ porteur )" =
    "indice",
  "R/donnees.R | .enjeu_elementaire | match ( vus , rl $ porteur )" =
    "indice",
  "R/donnees.R | .enjeu_elementaire | match ( indet , rl $ porteur )" =
    "indice",
  "R/donnees.R | .enjeu_elementaire | vus %in% rl $ porteur" =
    "indice",
  "R/donnees.R | .enjeu_elementaire | match ( s , rl $ porteur )" =
    "indice",
  "R/donnees.R | .enjeu_elementaire | indet %in% rl $ porteur" =
    "indice",
  "R/donnees.R | .enjeu_elementaire | match ( si , rl $ porteur )" =
    "indice",
  "R/donnees.R | .divergences_d01a | colonne %in% cle" =
    "metadonnee",
  "R/donnees.R | .divergences_d01a | k %in% k [ lignes ]" =
    "indice",
  "R/donnees.R | .divergences_d01a | k [ grp ] %in% as.integer ( names ( diverge ) [ diverge ] )" =
    "indice",
  "R/donnees.R | .rangees_enjeu | elements $ indice %in% rattache" =
    "indice",
  "R/donnees.R | .rangees_enjeu | match ( paste ( elements $ composante , elements $ unite ) , paste ( COMPOSANTES_ENJEU $ composante , COMPOSANTES_ENJEU $ unite ) )" =
    "metadonnee",
  "R/donnees.R | .rangees_enjeu | g %in% c ( .GARANTIES_CAPITAL , \"ensemble\" )" =
    "metadonnee",
  "R/donnees.R | .rangees_enjeu | g %in% c ( .GARANTIES_RENTE , \"ensemble\" )" =
    "metadonnee",
  "R/donnees.R | .rangees_enjeu | COMPOSANTES_ENJEU $ unite %in% presentes" =
    "metadonnee",
  "R/donnees.R | .rangees_enjeu | f %in% familles_cause" =
    "metadonnee",
  "R/donnees.R | .enjeu | match ( enjeu $ table , dico $ tables $ table )" =
    "metadonnee",
  "R/donnees.R | .enjeu | match ( paste ( enjeu $ table , enjeu $ colonne ) , paste ( dico $ colonnes $ table , dico $ colonnes $ colonne ) )" =
    "metadonnee",
  "R/donnees.R | .enjeu | match ( paste ( enjeu $ composante , enjeu $ unite ) , paste ( COMPOSANTES_ENJEU $ composante , COMPOSANTES_ENJEU $ unite ) )" =
    "metadonnee",
  "R/donnees.R | .enjeu | match ( enjeu $ famille , c ( FAMILLES_CALCUL , \"ensemble\" ) )" =
    "metadonnee",
  "R/donnees.R | .ordre_bilan | match ( table , dico $ tables $ table )" =
    "metadonnee",
  "R/donnees.R | .ordre_bilan | match ( paste ( table , colonne ) , paste ( dico $ colonnes $ table , dico $ colonnes $ colonne ) )" =
    "metadonnee",
  "R/donnees.R | .cle_causes | match ( causes , ordre )" =
    "metadonnee",
  "R/donnees.R | .bilan | CONTROLES_NON_IMPLEMENTES $ table %in% ctx $ tables" =
    "metadonnee",
  "R/donnees.R | .bilan | dico $ tables $ table %in% names ( ctx $ base )" =
    "metadonnee",
  "R/donnees.R | .bilan | \"catastrophes\" %in% names ( ctx $ base )" =
    "metadonnee",
  "R/donnees.R | .bilan | match ( requises $ rubrique , c ( RUBRIQUES_DECLARATIONS , \"conventions\" ) )" =
    "metadonnee",
  "R/donnees.R | .bilan | match ( requises $ cle , c ( FAMILLES_CALCUL , REFERENTIELS ) )" =
    "metadonnee"
)

# Constantes de la table de recherche : chaines, nombres, TRUE, FALSE, c() de constantes
constantes_seules <- function(d) {
  if (nrow(d) == 0L) return(FALSE)
  all(d$token %in% c("STR_CONST", "NUM_CONST", "SYMBOL_FUNCTION_CALL", "'('", "')'", "','")) &&
    all(d$text[d$token == "SYMBOL_FUNCTION_CALL"] == "c") && any(d$token %in% c("STR_CONST", "NUM_CONST"))
}
# Noms affectes au premier niveau d'un fichier de R/ (`NOM <- ...`, `NOM = ...`) : les constantes du package
affectes_premier_niveau <- function(chemin) {
  pd <- utils::getParseData(parse(file = chemin, keep.source = TRUE, encoding = "UTF-8"))
  noms <- character(0)
  for (id in pd$id[pd$parent == 0L & pd$token != "COMMENT"]) {
    fils <- pd[pd$parent == id & pd$token != "COMMENT", ]
    fils <- fils[order(fils$line1, fils$col1), ]
    if (nrow(fils) >= 3L && fils$token[2L] %in% c("LEFT_ASSIGN", "EQ_ASSIGN") && fils$token[1L] == "expr") {
      g <- pd[pd$parent == fils$id[1L], ]
      if (nrow(g) == 1L && g$token == "SYMBOL") noms <- c(noms, g$text)
    }
  }
  unique(noms)
}
CONSTANTES_PACKAGE <- unique(unlist(lapply(list.files(file.path(racine, "R"), "\\.R$", full.names = TRUE),
                                           affectes_premier_niveau)))
symbole_constante <- function(d) nrow(d) == 1L && d$token == "SYMBOL" && grepl("^[.]?[A-Z][A-Z0-9_]*$", d$text) &&
  d$text %in% CONSTANTES_PACKAGE

# Appels match(), is.element() et %in% d'un fichier : data.frame (ligne, fonction, texte), hors exclusions syntaxiques
recenser <- function(chemin) {
  exprs <- parse(file = chemin, keep.source = TRUE, encoding = "UTF-8")
  pd <- utils::getParseData(exprs)
  pd <- pd[order(pd$line1, pd$col1, -pd$line2, -pd$col2), ]
  term <- pd[pd$terminal & pd$token != "COMMENT", ]
  noeud <- function(id) pd[match(id, pd$id), ]
  jetons <- function(id) {
    r <- noeud(id)
    term[(term$line1 > r$line1 | (term$line1 == r$line1 & term$col1 >= r$col1)) &
         (term$line2 < r$line2 | (term$line2 == r$line2 & term$col2 <= r$col2)), ]
  }
  fonction_de <- function(id) {
    while (noeud(id)$parent != 0L) id <- noeud(id)$parent
    fils <- pd[pd$parent == id & pd$token != "COMMENT", ]
    fils <- fils[order(fils$line1, fils$col1), ]
    paste(jetons(fils$id[1L])$text, collapse = " ")
  }
  # arguments positionnels (expr non precedes de EQ_SUB) d'un appel, dans l'ordre
  arguments <- function(appel) {
    fils <- pd[pd$parent == appel & pd$token != "COMMENT", ]
    fils <- fils[order(fils$line1, fils$col1), ]
    precede_eq <- c(FALSE, fils$token[-nrow(fils)] == "EQ_SUB")
    fils$id[fils$token == "expr" & !precede_eq][-1L]
  }
  s <- pd[pd$token == "SPECIAL" & pd$text == "%in%", ]
  m <- pd[pd$token == "SYMBOL_FUNCTION_CALL" & pd$text %in% c("match", "is.element"), ]
  appels <- c(s$parent, vapply(m$id, function(i) noeud(noeud(i)$parent)$parent, 0L))
  droite <- c(vapply(s$id, function(i) {
    fils <- pd[pd$parent == noeud(i)$parent & pd$token == "expr", ]
    fils <- fils[order(fils$line1, fils$col1), ]
    fils$id[nrow(fils)]
  }, 0L), vapply(appels[length(s$id) + seq_along(m$id)], function(a) {
    ar <- arguments(a)
    if (length(ar) >= 2L) ar[2L] else NA_integer_
  }, 0L))
  res <- list()
  for (k in seq_along(appels)) {
    j <- jetons(appels[k])
    if (!is.na(droite[k])) {
      d <- jetons(droite[k])
      if (constantes_seules(d) || symbole_constante(d)) next
    }
    res[[length(res) + 1L]] <- data.frame(ligne = noeud(appels[k])$line1, fonction = fonction_de(appels[k]),
                                          texte = paste(j$text, collapse = " "), stringsAsFactors = FALSE)
  }
  if (length(res) == 0L) return(data.frame(ligne = integer(0), fonction = character(0), texte = character(0)))
  res <- do.call(rbind, res)
  # apparier_cles() est la seule implementation de la regle : son propre match() n'est pas recense
  res <- res[res$fonction != "apparier_cles", , drop = FALSE]
  res[order(res$ligne), , drop = FALSE]
}

if (.inventaire) {
  for (f in FICHIERS) {
    r <- recenser(file.path(racine, f))
    if (nrow(r)) cat(paste(f, r$fonction, r$texte, sep = " | "), sep = "\n")
  }
  quit(save = "no", status = 0L)
}

# Temoins sur un fichier fictif : match(), is.element() et %in% recenses, y compris sans nom de cle (`x %in% y`),
# autour d'un appel a cle_renseignee() ou a apparier_cles() et avec un symbole en majuscules local ;
# non recenses : apparier_cles() seul, constantes, symbole de constante du package (FAMILLES_CALCUL)
temoin <- tempfile(fileext = ".R")
writeLines(c("f <- function(x) {",
             "  a <- match(x, vv(\"t\", \"id_dossier\"))",
             "  b <- !is.na(apparier_cles(x, vv(\"t\", \"id_dossier\")))",
             "  c1 <- vv(\"t\", \"id_dossier\") %in% c(\"deces\", \"iad\")",
             "  d <- match(.cle_manquante(x), y, incomparables = NA)  # commentaire",
             "  e <- gs_id %in% liste",
             "  g <- x[cle_renseignee(id_c)] %in% y",
             "  h <- dossier %in% payes",
             "  i <- x %in% FAMILLES_CALCUL",
             "  j <- match(x, table = y)",
             "  ID <- as.character(z)",
             "  k <- x %in% ID",
             "  l <- x %in% y[a | is.na(apparier_cles(y, NA))]",
             "  m <- is.element(x, y)",
             "}"), temoin)
t <- recenser(temoin)
unlink(temoin)
if (identical(t$ligne, c(2L, 5L, 6L, 7L, 8L, 10L, 12L, 13L, 14L)) && all(t$fonction == "f")) {
  ok("temoins du recensement : match(), is.element() et %in% recenses, noms de cle ou non, y compris autour de cle_renseignee() ou d'apparier_cles() et avec un symbole en majuscules local ; apparier_cles() seul, constantes et symbole de constante du package non recenses")
} else {
  echec(paste0("temoins du recensement : lignes recensees ", paste(t$ligne, collapse = ", "), " au lieu de 2, 5, 6, 7, 8, 10, 12, 13, 14"))
}

categorie_de <- function(v) sub(" : .*$", "", v)
if (!all(categorie_de(LISTE_BLANCHE) %in% CATEGORIES)) {
  echec(paste0("categorie hors de la liste fermee (", paste(CATEGORIES, collapse = ", "), ") : ",
               paste(names(LISTE_BLANCHE)[!(categorie_de(LISTE_BLANCHE) %in% CATEGORIES)], collapse = " ; ")))
}
sans_justification <- names(LISTE_BLANCHE)[categorie_de(LISTE_BLANCHE) %in% c("cle_garantie", "a_instruire") &
                                           !grepl(" : .+", LISTE_BLANCHE)]
for (n in sans_justification) echec(paste0("categorie cle_garantie ou a_instruire sans justification : ", n))
sans_renvoi <- names(LISTE_BLANCHE)[categorie_de(LISTE_BLANCHE) == "a_instruire" & !grepl("#[0-9]+", LISTE_BLANCHE)]
for (n in sans_renvoi) echec(paste0("categorie a_instruire sans renvoi a une issue (#N) dans la justification : ", n))

trouves <- character(0)
for (f in FICHIERS) {
  chemin <- file.path(racine, f)
  r <- tryCatch(recenser(chemin), error = function(e) e)
  if (inherits(r, "error")) {
    echec(paste0(f, " non analysable : ", conditionMessage(r)))
    next
  }
  cles <- if (nrow(r)) paste(f, r$fonction, r$texte, sep = " | ") else character(0)
  trouves <- c(trouves, cles)
  inconnu <- !(cles %in% names(LISTE_BLANCHE))
  for (i in which(inconnu)) {
    echec(paste0(f, ":", r$ligne[i], " appariement hors de la liste blanche (apparier_cles() ou cle_renseignee(), ",
                 "ou entree de LISTE_BLANCHE) : ", r$fonction[i], " : ", r$texte[i]))
  }
  # releve : une ligne par entree a_instruire (fichier, ligne, fonction, justification), sans echec
  for (i in which(!inconnu & categorie_de(LISTE_BLANCHE[match(cles, names(LISTE_BLANCHE))]) == "a_instruire")) {
    cat("[RELEVE] ", f, ":", r$ligne[i], " ", r$fonction[i], " : ",
        sub("^a_instruire : ", "", LISTE_BLANCHE[[match(cles[i], names(LISTE_BLANCHE))]]), "\n", sep = "")
  }
  if (!any(inconnu)) ok(paste0(f, " : chaque match() et %in% passe par apparier_cles() ou figure dans la liste blanche"))
}
perimes <- setdiff(names(LISTE_BLANCHE), trouves)
for (p in perimes) echec(paste0("entree de la liste blanche sans appel correspondant : ", p))
if (length(perimes) == 0L) {
  n <- table(factor(categorie_de(LISTE_BLANCHE), levels = CATEGORIES))
  ok(paste0("liste blanche a jour : ", length(LISTE_BLANCHE), " entrees, chacune retrouvee dans le code (",
            paste(names(n), n, sep = " ", collapse = ", "), ")"))
}
fin()
