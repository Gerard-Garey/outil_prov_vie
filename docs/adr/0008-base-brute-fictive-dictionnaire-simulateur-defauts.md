---
status: accepted
date: 2026-11-07
---

# Base brute fictive : dictionnaire visé par le mainteneur, simulateur dans le package hors de la chaîne du moteur, loi vraie à part, défauts de données à liste fermée avec traitement, jeux versionnés modestes et jeux volumineux à empreinte, actif facultatif, aucune provision inscrite en entrée, vue à une date

*Rédigé par `architect-approfondi` sur Fable le 7 novembre 2026 (consultation 1/3 de la branche `claude/cadrage`, PR #6 ; `docs/agents/routage.md`, § 4.1.3 ; accord du mainteneur, Q15 et Q27). Il consigne les décisions du mainteneur Q5, Q6, Q17, Q18, Q19, Q22, Q23, Q30, A4 et G11 ; il ne les rediscute pas. Précédents : dictionnaire et générateur de la base brute fictive du provisionnement double effet de `docu_actu` (forme reprise, Q11 : aucun texte ni aucune donnée) ; ADR 0003 (point 9) et 0007 (annotation du 25 octobre 2026, format des jeux simulés) d'`outil_tables`.*

## Contexte

Le dépôt est public (Q11) et ne contient **aucune donnée réelle** (énoncé initial). L'outil recalcule pourtant à partir d'une extraction d'une vraie base de gestion : contrats, affiliations, sinistres, événements, prestations, cotisations (E1.1), et un triangle n'est jamais une donnée (ADR 0005, point 6). Il faut donc une base fictive qui ait la forme d'une extraction réelle — plusieurs tables reliées par identifiants, données brutes, cas de défaut (insistance du mainteneur, Q6) — et dont la vérité soit connue pour que les tests puissent juger les méthodes (Q23). `docu_actu` a réglé le problème pour la seule garantie double effet par un dictionnaire de douze tables et un générateur ; `outil_tables` par un simulateur du modèle multi-états exécuté en avant, à loi vraie et graine consignées, défauts injectés après le tirage du jeu propre (son ADR 0007, annotation du 25 octobre 2026).

Le mainteneur a tranché contre la recommandation initiale de la session (Q5) : la base est une base de gestion, et **les provisions inscrites par l'organisme n'en font pas partie** ; l'outil ne fait aucun rapprochement avec elles.

## Décision

Arrêtée par le mainteneur le 7 novembre 2026 (Q5 contre la recommandation ; Q6, Q17, Q18, Q19, Q22, Q23, Q30, A4 ; G5, G11, G19 pour les termes) :

1. **Base brute fictive** (`CONTEXT.md`, « Base brute fictive » ; jamais « jeu de test », « données d'exemple ») : une extraction à la **date d'extraction**, en plusieurs tables CSV reliées par identifiants, en données brutes **sans champ dérivé** (ni âge, ni ancienneté, ni provision par dossier, ni triangle). Tables de la v1 (Q17, A4, G5, G19) : contrats, adhérents, assurés, affiliations, garanties souscrites et leurs paramètres, famille et bénéficiaires, cotisations émises et encaissées par garantie et par période couverte, sinistres (une ligne par sinistre : survenance, déclaration, instruction), événements de sinistre (états successifs, reprises, clôtures, mises à jour reçues, **chacun avec sa date de saisie**), dossiers (un par sinistre et par garantie déclenchée), prestations payées avec leur période couverte (E2.1 relue par `actuary` le 7 novembre 2026), rentes en service (stock à la date d'extraction, sinistres antérieurs à la fenêtre d'historique compris), catastrophes et victimes ; une **évaluation de gestion par dossier** (estimation du gestionnaire), colonne facultative lue par les seuls diagnostics (dernière évaluation comparée à la provision recalculée) et, si le dictionnaire la date, par un triangle des évaluations de gestion distinct du triangle de charges, jamais par le calcul (décision du mainteneur du 7 novembre 2026, M68, contre la recommandation de la session ; distincte des provisions inscrites, Q5 ; forme tranchée par le dictionnaire). Extensions par tables : épargne (v2), **actif** (placements ligne à ligne à l'arrêté et flux de l'exercice, cantons en attribut, v2).
2. **Dictionnaire de la base** (« Dictionnaire de la base ») : spécification des tables (colonnes, types, domaines, clés, conventions, dates de saisie), **rédigée par `actuary-approfondi` et visée par le mainteneur**, première issue de la première branche de code, avant le simulateur (E2.2) ; un seul dictionnaire pour toutes les garanties de la v1, extensible par tables. [proposé] Deux formes tenues concordantes par un test : le texte de spécification versionné sous `docs/` et une forme lisible par machine dans le package (`inst/extdata/dictionnaire/`), que le module `donnees` lit pour ses contrôles et que le simulateur respecte.
3. **Simulateur dans le package, hors de la chaîne du moteur** (« Simulateur » ; jamais « générateur » seul, réservé au générateur de scénarios économiques, G11) : module `simulation` (ADR 0006), point d'entrée `simuler_base(...)` (nom proposé) à entrées explicites (loi vraie, paramètres du portefeuille, période d'historique, date d'extraction, graine) ; modèle multi-états exécuté en avant sur les mêmes états que le moteur, sans appeler les familles de calcul ni les contrôles du module `donnees` dont il sert à tester les attentes ; il tire d'abord le **jeu propre**, puis y **injecte les défauts** paramétrés sous une graine distincte, **sans changer les tirages du jeu propre** (E4.9). Dès la v1, il produit un portefeuille à **garanties liées** décès et arrêt de travail (Q19).
4. **Loi vraie à part** (« Loi vraie ») : tables, lois de maintien et de passage, cadences de déclaration et de règlement, fréquences, montants, intensités des défauts, sous lesquelles un jeu est tiré ; écrite à part du jeu (fichier ou attribut à côté, jamais une colonne de la base), **lue par les seuls tests** ; chaque jeu versionné la porte avec sa graine. Les batteries vérifient que l'outil retrouve la provision vraie dans des **bornes déclarées** : chaque vérification est un **constat de simulation** (nombre de jeux, niveau, région d'acceptation, fausse alarme), jamais un résultat exact (E2.23).
5. **Défauts de données à liste fermée, chacun avec son traitement** (E2.4 ; « Défaut de données », « Traitement » ; liste relue par `actuary` et visée le 7 novembre 2026, M69) : doublons ; dates incohérentes, dont une date de saisie antérieure à l'événement ; manquants (date de naissance, sexe, salaire, situation de famille, catégorie d'invalidité, période couverte) ; prestation sans sinistre ; sinistre clos sans prestation ni motif ; clôture sans justificatif ; extinction non enregistrée ; rechute enregistrée comme nouveau sinistre ; montants aberrants ; incohérence entre garanties. Les déclarations tardives et les ruptures de cadence ne sont pas des défauts mais des phénomènes du portefeuille, tirés avec la loi vraie et signalés par les diagnostics, sans traitement. Chaque défaut a son **intensité paramétrée** dans le simulateur et le **traitement** que le moteur lui applique : refus, exclusion déclarée par motif dans le plan et comptée, hypothèse par défaut documentée, ou signalement ; **aucune correction silencieuse** (E2.5). La liste est amendée par `actuary` avec le dictionnaire ; un défaut hors liste est un refus.
6. **Jeux versionnés modestes, jeux volumineux à empreinte** (« Jeu versionné », « Extraction », « Empreinte ») : les jeux de taille modeste sont versionnés sous `inst/extdata/jeux/` avec leur loi vraie et leur graine (tests, CI, références de non-régression) ; les jeux volumineux sont générés à la demande par leur graine, leur empreinte seule est versionnée ; volumétrie de la v1 : dizaines de milliers de contrats, quelques milliers de sinistres, dix ans d'historique ; les millions de lignes hors v1 (E2.3).
7. **Actif facultatif** (Q30) : les tables de l'actif sont une extension de la v2 ; un calcul comptable seul n'en a pas besoin ; les postes qui en dépendent ne sont calculés qu'en sa présence, et son absence est signalée dans la fiche, pas refusée.
8. **Aucune provision inscrite en entrée** (Q5) : la base ne porte pas les provisions de l'organisme et l'outil n'en fait aucun rapprochement ; les « options » sont le plan de calcul (ADR 0007).
9. **Vue à une date** (Q22 ; « Vue à une date », « Date de saisie ») : la date d'arrêté est déclarée, au plus égale à la date d'extraction ; le module `donnees` reconstitue, par les dates de saisie, la base telle que l'organisme la connaissait à l'arrêté, avant tout calcul ; c'est le support du réalisé / attendu (E2.22).
10. **Une ligne invalide n'est jamais modifiée** (E2.5) : refusée avec son motif, son nombre et ses premiers identifiants, ou exclue par une règle déclarée du plan, comptée et listée par motif dans le résultat ; les conversions de type relèvent de la couche de lecture, qui refuse sans convertir.

## Options écartées

- **Provisions inscrites en entrée et rapprochement** (recommandation initiale de la session, Q5, Q12) : écartée par le mainteneur ; l'outil est un second recalcul, pas un contrôle de cohérence des comptes.
- **Triangles ou champs dérivés dans la base** (âge, ancienneté, charge estimée, triangle) : un champ dérivé fige une convention hors du plan et échappe à la vue à une date ; tout se reconstitue.
- **Une base par garantie** : interdit le calcul « une ou plusieurs garanties à la fois » (E1.8) et les liens déclarés (maintien de la garantie décès, passage, double effet) ; une seule base, un seul dictionnaire.
- **Données réelles anonymisées** : exclues par l'énoncé initial et par le dépôt public ; aucune vérité connue pour les tests.
- **Générateur sous forme de script hors package** (forme de `docu_actu`) : hors des batteries, hors de la liste blanche, non versionné avec le code qu'il teste ; le simulateur est un module du package, hors de la chaîne du moteur.
- **Simulateur qui appelle les familles de calcul** : ne prouverait rien sur elles ; même règle qu'`outil_tables` (son ADR 0007, options écartées).
- **Correction automatique des défauts** (dates inversées remises à l'endroit, doublons dédoublonnés) : interdite ; toute exclusion est une règle déclarée, comptée et relue.
- **Jeux volumineux versionnés** : taille du dépôt, diffs illisibles ; la graine et l'empreinte suffisent à les régénérer et à les identifier.
- **Défauts tirés en même temps que le jeu propre** : un changement d'intensité changerait le jeu propre ; l'injection après tirage garde le jeu propre comme référence (E4.9).

## Conséquences

- **Fichiers** : modules `donnees` et `simulation` de `provie` ; `inst/extdata/dictionnaire/` et `inst/extdata/jeux/` (formes proposées) ; spécification du dictionnaire sous `docs/` ; `tests/` (constats de simulation, traitements des défauts testés comme des résultats : message, décompte) ; `docs/exigences.md`, E2.1 à E2.6, E4.4, E4.9 (déjà écrites) ; `CONTEXT.md`, section « Données, simulateur et défauts » et « Dates » (déjà écrites, G6, G11) ; fiche `actuary` (dictionnaire et défauts, déjà écrite). Commits `donnees:` pour les jeux versionnés et leur loi vraie.
- **Effet sur les résultats** : aucun (aucun code). Règle durable : un jeu versionné ne change jamais en place ; un jeu corrigé est un nouveau jeu, les références qui en dépendent sont régénérées après visa.
- **Ce qui reste à faire** : le dictionnaire (première issue de la première branche de code, visa du mainteneur) ; la liste finale des défauts et de leurs traitements (`actuary`, avec le dictionnaire) ; la forme des jeux simulés et de la loi vraie (contrat partagé, `docs/agents/routage.md`, § 4.2 ; ADR de forme de la première branche de code) ; les tables qui portent une date de saisie (événements au moins ; prestations et affiliations à trancher par le dictionnaire) ; l'extension du dictionnaire à l'actif et à l'épargne (v2).
- **Réglé après rédaction, le 7 novembre 2026** : l'évaluation de gestion par dossier entre dans la base en colonne facultative, lue par les seuls diagnostics et triangles de charges (M68, point 1) ; la **provision vraie** d'un jeu est l'espérance conditionnelle, sous la loi vraie, des flux futurs sachant l'information à l'arrêté (tests de biais), les flux simulés après l'arrêté servant aux tests de couverture, et chaque constat de simulation écrit aussi la puissance contre une alternative déclarée, ce qui complète le point 4 (M70, E2.23) ; les triangles de référence de la v1 sont ceux des nombres et des paiements (M65, E2.12).
- **Ce que l'ADR ne règle pas** : la manière de calculer cette espérance conditionnelle pour chaque famille (par simulation répétée des flux futurs d'un même jeu, ou en forme fermée quand la loi vraie le permet), à spécifier par `actuary` avec les premiers tests ; la génération d'une base à plusieurs dates d'extraction pour le réalisé / attendu (une extraction tardive vue à deux dates suffit-elle ?), à trancher avec la branche de validation.
- **Vocabulaire** : `CONTEXT.md`, « Base brute fictive », « Dictionnaire de la base », « Simulateur », « Loi vraie », « Jeu propre », « Défaut de données », « Traitement », « Jeu versionné », « Extraction », « Empreinte », « Vue à une date », « Date de saisie », « Constat de simulation », « Témoin ».

Issues : #4 (ADR de cadrage).

## Annotation du 7 novembre 2026 — dictionnaire de la base v1 visé (#16)

*Rédigée par `architect` le 7 novembre 2026 (branche `claude/socle-donnees`, PR #21). Elle consigne, sans rouvrir la décision, les écarts que le dictionnaire de la base v1 (`docs/specifications/dictionnaire-base-v1.md`, version `1.0`) apporte au point 1 et au point 5. Le dictionnaire a été visé globalement par le mainteneur le 7 novembre 2026, commit `df4ceaa` ; les commits précédents sont `ec7162c` (rédaction, `actuary-approfondi`) et `73c3364` (filiation avec le double effet de `docu_actu`, avis P13). Décisions du mainteneur : M73 à M77 de `docs/feuille-de-route.md`, § 4. En cas d'écart entre le présent ADR et le dictionnaire visé, le dictionnaire fait foi pour la liste des tables, des colonnes et des défauts. L'ADR reste la référence pour les principes (points 2 à 10).*

**Point 1, liste des tables : écarts visés** (dictionnaire, § 2.1 et § 2.2 ; P1 visé pour les écarts 1 à 5, écarts 6 et 7 visés avec le dictionnaire) :

1. **`extraction`**, table nouvelle d'une ligne. Elle porte la date d'extraction et la version du dictionnaire, contre lesquelles se contrôlent l'arrêté du plan et l'absence d'information postérieure.
2. **« Garanties souscrites et leurs paramètres »** devient `garanties_souscrites` et `parametres`. `parametres` est en format long, de clé composite (`id_garantie_souscrite`, `parametre`, `categorie_invalidite`, `age_min`), et toutes ses valeurs sont `numeric`.
3. **« Famille et bénéficiaires »** devient `famille`, qui porte les personnes, et `beneficiaires`, qui porte le lien entre un dossier et une personne avec sa part. **La clé de `famille` est composite, (`id_membre`, `date_saisie`)** : un membre est constaté à l'instruction d'un sinistre et rattaché à ce sinistre. Une correction ajoute une ligne complète de même `id_membre`. La ligne valable à un arrêté A est la dernière saisie au plus tard à A. La table est donc historisée et lisible en vue à une date (dictionnaire, T8).
4. **« Rentes en service »** devient `rentes` : une ligne par rente, en service, à constituer ou terminée. L'état « en service » à une date et le montant en vigueur se reconstituent du journal des événements (`ouverture_service`, `suspension`, `reprise_service`, `fin_service`, `modification_montant`). Une table d'état à l'extraction serait un champ dérivé, au sens des options écartées ci-dessus (P3 visé). Le stock à la date d'extraction, survenances antérieures à la fenêtre comprises, reste exigé (point 6 et E2.3).
5. **Évaluation de gestion** : la « colonne facultative » du point 1 et du paragraphe « Réglé après rédaction » devient la **table facultative datée `evaluations_gestion`** (T18). Chaque ligne est une évaluation successive d'un dossier : montant restant, date d'effet, date de saisie. Ses lecteurs sont inchangés (M68) : la comparaison par dossier et le **triangle des évaluations de gestion**, ce dernier **distinct du triangle de charges** qui porte les provisions recalculées par l'outil (M65). La mention « triangles de charges » du paragraphe « Réglé après rédaction » se lit dans ce sens (dictionnaire, § 7). Critère d'acceptation : toutes les provisions sont identiques au bit près avec ou sans la table.
6. **Tables facultatives T19 `designations` et T20 `ayants_droit_sante`**, reprises du double effet sur décision du mainteneur (option (a) de l'avis P13, M75). Elles portent l'information de famille des assurés vivants : bénéficiaires nommés d'une désignation nominative, et périodes de couverture des ayants droit du contrat frais de santé couplé. Seule l'approche par tête les lit, et toute méthode qui les lit fonctionne sans elles. Leurs conditions d'usage, qui touchent aux données de santé, sont un point ouvert confié à `regulatory` (dictionnaire, § 11, P18) : aucun poste ne les exige avant cette lecture.
7. **Conventions de filiation avec le double effet** (annexe A du dictionnaire) :
   - un contrat de branche s'écrit, en v1, comme un contrat par adhérent ;
   - le sexe et la date de naissance du décédé ont une seule source, `assures` ;
   - la modalité `H` devient `M` ;
   - les pourcentages deviennent des fractions.

Il en résulte **vingt tables**, dont cinq facultatives : T16 à T20, T17 étant obligatoire en présence de T16. Les **dates de saisie** sont portées par les affiliations, les prestations, les bénéficiaires, les rentes, la famille et les sinistres, en plus des événements. Ce point était laissé au dictionnaire par « Ce qui reste à faire » (P2 visé).

**Information de famille des assurés** (P14, reformulé par la correction M2 de l'avis P13). `assures.situation_familiale` et `nombre_enfants_charge` sont la dernière valeur déclarée, **datée** par `date_situation_familiale`, et **facultatives**. Pour un assuré décédé ou radié, c'est la valeur déclarée avant la radiation. Leur absence ou leur péremption est un phénomène du portefeuille. Elle ne devient le défaut D03d que pour un poste qui les requiert. La limite est restituée dans le rapport figé.

**Point 5, liste des défauts** (dictionnaire, § 9, « liste amendée ») : les défauts sont codés D01a à D14 et aucun défaut d'E2.4 n'est retiré. Les ajouts et extensions sont les suivants :

- **D03g**, date de saisie manquante ;
- **D04b**, extension de « prestation sans sinistre » à toute ligne orpheline ;
- **D11**, sinistre hors période de couverture ;
- **D12**, suite d'états impossible ;
- **D13**, instruction absente ;
- **D14**, dossier double effet non ouvert.

D13 et D14 viennent du dictionnaire double effet. D02a, D03a, D06, D07 et D09 sont étendus aux cas du double effet. D03d se lit désormais « situation de famille absente ou périmée, requise par un poste ».

La liste des phénomènes du portefeuille, qui ne sont pas des défauts, s'étend aux suivants :

- information de famille absente ou périmée ;
- désignation non mise à jour ;
- instruction pendante à l'extraction ;
- couverture partielle des ayants droit santé ;
- radiations saisies avec retard ;
- régularisations.

Le principe du point 5 est inchangé : liste fermée, intensité paramétrée, traitement déclaré, exclusion par famille de calcul (P16 visé), un défaut hors liste étant un refus.

**Autres points visés avec le dictionnaire, sans effet sur le présent ADR** :

- une assiette unique par affiliation en v1 (P4) ;
- une colonne inconnue du dictionnaire est refusée (P7, application du point 10) ;
- souscripteur = assuré pour un contrat individuel en v1 (P11) ;
- bornes de contrôle retenues comme jugement d'expert (P12) ;
- historique du stock exigé complet, sans défaut « premier état manquant » en v1 (P15).

**Restent ouverts** :

- la forme lisible par machine (point 2, toujours `[proposé]` ; dictionnaire, § 10), qui relève de l'ADR de forme de #17 ;
- la base à plusieurs dates d'extraction (P17, avec B10) ;
- P5, P6, P8 à P10 (#13, #14) ;
- P18.

**Effet sur les résultats** : aucun, puisqu'aucun code n'existe. Le dictionnaire est un contrat partagé (`docs/agents/routage.md`, § 4.2) : toute modification passe par une nouvelle version visée. Issues : #16 ; #14 et #13 pour les points renvoyés.

## Annotation du 7 novembre 2026 — forme lisible par machine et forme des jeux (ADR 0010)

*Rédigée par `architect` le 7 novembre 2026 (branche `claude/socle-donnees`, PR #21) après l'acceptation de l'ADR 0010 par le mainteneur (décisions M87 à M96 de `docs/feuille-de-route.md`, § 4). Le texte ci-dessus n'est pas réécrit ; en cas d'écart, l'ADR 0010 fait foi pour les points qui suivent.*

- **Point 2, forme lisible par machine** : la mention `[proposé]` est levée. Six fichiers CSV sous `inst/extdata/dictionnaire/` (`tables.csv`, `colonnes.csv`, `types_evenements.csv`, `parametres.csv`, `defauts.csv`, `filiation.csv`) et `dictionnaire.txt` (version, date de visa, empreinte de chaque CSV) transcrivent le texte visé, qui reste la spécification ; `tests/controles/concordance_dictionnaire.R` compare chaque CSV au tableau correspondant du texte (ADR 0010, point 23). Ces fichiers sont lus par le module **`dictionnaire`**, et non par `donnees` comme le disait le point 2 (ADR 0010, point 1 ; M88). Le premier tiret des « Restent ouverts » de l'annotation précédente est soldé.
- **Point 3** : le simulateur appelle `dictionnaire`, jamais `donnees` ; la règle « sans appeler les contrôles du module `donnees` » est désormais contrôlée par le script du graphe (ADR 0010, point 1).
- **Points 4 et 6, forme des jeux** : un jeu simulé est un objet `jeu_simule` (`base`, `loi_vraie`, `verite` avec le **registre des défauts**, `manifeste`) ; un jeu versionné est un dossier `inst/extdata/jeux/<jalon>-<volumetrie>-<nn>/` (`base/`, `loi_vraie.txt`, `verite/`, `manifeste.txt`, `empreintes.md5`), écrit par `ecrire_jeu()` du module `lecture`, le simulateur n'écrivant aucun fichier (ADR 0010, points 19 et 20). La loi vraie est sérialisée sans évaluation (`lire_liste()`), et non par `dput()`. Le **jeu propre n'est pas versionné** : il se reconstitue de la base et des valeurs propres du registre, et se régénère à la graine (M94).
- **Point 5, liste des défauts** : le dictionnaire, amendé le 7 novembre 2026 (commit `eb82c24`, décision T1 sur #14, M86), ajoute **D03h**, taux du tarif manquant, traité par hypothèse par défaut de 0 % (jugement d'expert, déclaré et signalé). Le principe du point 5 est inchangé.

**Effet sur les résultats** : aucun (aucun code). Issues : #17, #18, #19, #14.

## Annotation du 7 novembre 2026 — toute modification du dictionnaire fait une nouvelle version (P18, version 1.2)

*Rédigée par `architect` le 7 novembre 2026 (branche `claude/socle-donnees`, PR #21), sur décision du mainteneur du même jour (M103 de `docs/feuille-de-route.md`, § 4). Le texte ci-dessus n'est pas réécrit.*

- **Règle précisée** : **toute modification du dictionnaire de la base, même de texte seul, fait une nouvelle version visée** (version portée dans l'en-tête, l'historique des versions, `VERSION_DICTIONNAIRE_ATTENDUE` et `dictionnaire.txt`). La règle « toute modification passe par une nouvelle version visée » de la première annotation ne distinguait pas le texte de la structure ; le mainteneur l'a appliquée à un changement de texte seul. Motif : le numéro de version est la seule marque qu'un jeu, une fiche de calcul ou une revue externe puisse citer pour dire quel texte il a suivi ; une version qui couvre deux textes différents casserait cette traçabilité.
- **Version `1.2`** (commit `f6b30ea`) : le point ouvert **P18** (conditions d'emploi des données du contrat frais de santé couplé) est soldé par la lecture de `regulatory` du 7 novembre 2026 : quatre conditions cumulatives (même responsable du traitement ; finalité compatible ; aucune donnée de santé ; minimisation, pseudonymisation et information), que l'organisme d'assurance apprécie avec son délégué à la protection des données, l'outil ne les vérifiant pas. Décisions du mainteneur : **lecture A** — le lien, le sexe, la date de naissance et les dates de couverture ne sont pas des données de santé (M101) ; **obligation légale de constituer les provisions citée à l'appui de la compatibilité de finalité**, et non comme condition distincte, écart de formulation assumé avec M132 (1) de `docu_actu` (M102). Aucune table, colonne ni défaut ne change. Le dernier tiret des « Restent ouverts » de la première annotation (P18) est soldé.
- **Hors P18** : le cadre des données de sinistres d'arrêt de travail (données concernant la santé, art. 9 du règlement (UE) 2016/679) relève de l'issue **#23**, hors du périmètre de B1.

**Effet sur les résultats** : aucun (texte seul ; aucune provision calculée dans B1). Issues : #16, #23, #17.
