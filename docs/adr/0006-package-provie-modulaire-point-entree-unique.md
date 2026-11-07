---
status: accepted
date: 2026-11-07
---

# Package `provie` modulaire à point d'entrée unique `calculer_provisions(donnees, plan)`, application Shiny à part sous `app/`, graphe d'appels des modules contrôlé par script, en dérogation au « fichier unique » d'`outil_usp`

*Rédigé par `architect-approfondi` sur Fable le 7 novembre 2026 (consultation 1/3 de la branche `claude/cadrage`, PR #6 ; `docs/agents/routage.md`, § 4.1.3 ; accord du mainteneur, Q15 et Q27). Il consigne les décisions du mainteneur Q8, Q14 et A5 ; il ne les rediscute pas. Précédents : ADR 0004 d'`outil_tables` (même dérogation, mêmes motifs) et ADR 0007 d'`outil_tables` (package à la racine, application hors du package, graphe d'appels contrôlé par `tests/controles/graphe_modules.R`, `NAMESPACE` écrit à la main, *vérifié* le 7 novembre 2026 sur `C:\Personnel\Boulot\outil_tables`).*

## Contexte

`outil_usp` impose un moteur dans un fichier unique « pour permettre une revue indépendante », une fonction d'orchestration qui retourne un objet complet, une couche d'affichage sans calcul et un rapport figé construit sur l'objet retourné (son `docs/exigences.md`, § 4, lu lors du cadrage d'`outil_tables` ; ADR 0004 d'`outil_tables`, « Contexte »). La règle tient pour une chaîne de calibrage et un livrable. `outil_prov_vie` a quatre familles de calcul (ADR 0005), des services (dictionnaire et contrôles de la base, tables en entrée, plan et fiche de calcul, rapport), un simulateur, deux référentiels, une restitution par dossier, par poste et par segment, et des dizaines de méthodes à terme (E2.14 à E2.19) : un fichier unique de plusieurs milliers de lignes empêcherait la revue qu'il est censé permettre (localiser une méthode, tester un module seul, constater qu'une modification de `triangle` ne touche pas `engagement`).

`outil_tables` a tranché la même question le 14 octobre 2026 (package `tablexp` modulaire) et fixé la forme le 16 octobre 2026 (son ADR 0007) : package à la racine, `app/` hors du package parce que tout fichier de `R/` entre dans l'espace de noms (mesuré là-bas), graphe d'appels autorisés contrôlé par script en CI sans `codetools`, appels dynamiques interdits dans `R/`, `NAMESPACE` à la main (onze exports à ce jour, `NAMESPACE` d'`outil_tables`, *vérifié*). `CLAUDE.md`, « Architecture » (lignes 40 à 50, *vérifié*), reprend déjà ces invariants pour `provie`.

## Décision

Arrêtée par le mainteneur le 7 novembre 2026 (Q8, Q14, A5 ; A1 pour les domaines de commit ; recommandation de la session suivie) :

1. **Un package R, `provie`, à la racine du dépôt** (`DESCRIPTION`, `NAMESPACE`, `R/`, `inst/extdata/`, `tests/`), en dérogation au fichier unique d'`outil_usp`. Code en français sans accents (A5). Domaines de commit : `moteur:`, `app:`, `tests:`, `docs:`, `donnees:`, `claude:`, `repo:` (A1).
2. **Un module par famille de calcul ou par service, un fichier par module** (E4.1). Modules **proposés**, à confirmer par l'ADR de forme de la première branche de code (comme l'ADR 0007 d'`outil_tables` a confirmé son ADR 0004) :

   | Module | Fichier | Contenu | Peut appeler (proposition) |
   |---|---|---|---|
   | `outils` | `R/outils.R` | services sans contenu métier : graine locale, refus et signalements, écriture canonique des valeurs, constantes de plateforme | rien (packages `base` seulement) |
   | `donnees` | `R/donnees.R` | dictionnaire de la base, contrôles, traitements des défauts de données, vue à une date, exclusions déclarées | `outils` |
   | `tables` | `R/tables.R` | formats admis, conversion interne, tables embarquées, courbes EIOPA et série TME, plafonds réglementaires | `outils` |
   | `garanties` | `R/garanties.R` | catalogue des configurations de garanties (états, flux, lois par usage, postes, liens) ; **[proposé]** par `architect`, absent du brief | `outils` |
   | `engagement` | `R/engagement.R` | famille « engagement » : échéanciers, valeur actuelle probable sous modèle multi-états | `tables`, `garanties`, `donnees`, `outils` |
   | `triangle` | `R/triangle.R` | famille « triangle » : reconstitution, Chain Ladder, Bornhuetter-Ferguson, coût moyen × nombre, écart-type de Mack, diagnostics | `garanties`, `donnees`, `outils` |
   | `risque_en_cours` | `R/risque_en_cours.R` | famille « risque en cours » : limites du contrat, PPNA et PREC, PRC (hors v1) | `engagement` et amont |
   | `projection` | `R/projection.R` (v2) | famille « projection » : canton actif-passif, scénarios, générateur de scénarios minimal | `engagement` et amont |
   | `regles_comptables` | `R/regles_comptables.R` | catégorie « règle comptable » (ADR 0005, annotation du 7 novembre 2026) : provision pour égalisation, PPNA, PREC (v1) ; PPB, PRE, PAF, provision globale de gestion, réserve de capitalisation (v2) ; **visé par le mainteneur le 7 novembre 2026 (M61)** | `garanties`, `tables`, `donnees`, `outils` |
   | `plan` | `R/plan.R` | validation du plan de calcul, canonisation, assemblage de la fiche de calcul, sérialisation du plan et de la fiche (ADR 0007) | `tables`, `garanties`, `donnees`, `outils` |
   | `rapport` | `R/rapport.R` | quantités restituées, tableau de passage, comparaison de deux résultats, empreintes, rapport figé (octets HTML, sans calcul) | tous les modules ci-dessus |
   | `simulation` | `R/simulation.R` | simulateur de base brute fictive, loi vraie, injection des défauts ; **hors de la chaîne du moteur** | `garanties`, `tables`, `donnees`, `outils` ; **aucun module du moteur ne l'appelle** |
   | orchestration | `R/calculer_provisions.R` | point d'entrée, table étape → fonction de module, aucun calcul | tous les modules **sauf `simulation`** |

   Les tests appellent n'importe quel module (`provie:::` admis dans `tests/`).
3. **Graphe d'appels contrôlé par script en CI**, en R de base : pour chaque fichier de `R/`, `parse(keep.source = FALSE)`, table « fonction → module » des définitions de premier niveau, arêtes par `all.names()` du corps ; toute arête hors du tableau fait échouer le script, qui imprime module appelant, module appelé, fonction appelante et fonction appelée ; témoins testés (un module qui appelle `simulation` ; `triangle` qui appelle `engagement`). **Appels dynamiques interdits dans `R/`** (`do.call()` sur une chaîne, `match.fun()`, `get()`, `eval(parse())`, `provie::` et `provie:::` vers le package lui-même), parce qu'ils échappent au script (modèle : ADR 0007 d'`outil_tables`, points 2.2 et 2.3).
4. **Point d'entrée unique : `calculer_provisions(donnees, plan)`** (E4.1, E4.4). `donnees` est une **liste nommée de `data.frame`**, un par table de la base, nommés comme dans le dictionnaire (ADR 0008) ; `plan` est un plan de calcul (ADR 0007). La fonction valide le plan, applique les contrôles et la vue à une date, exécute les familles dans l'ordre que le plan et les liens déclarés imposent, assemble l'objet résultat et la fiche de calcul, et retourne un **objet complet** (provisions par dossier, par segment, par garantie, par poste et par référentiel ; triangles reconstitués et diagnostics ; tableau de passage ; contrôles de la base et exclusions par motif ; fiche de calcul ; empreintes), dans lequel l'application, le rapport figé et les tests lisent **sans recalculer**. Le moteur ne reçoit **jamais un fichier**. [proposé] Un quatrième argument nommé facultatif `provenance = NULL`, par lequel la couche de lecture transmet les noms et empreintes des fichiers lus (règle de l'ADR 0007 d'`outil_tables`, point 3.1), sans changer la signature à deux arguments.
5. **Autres points d'entrée**, de même forme (entrées explicites, objet complet) : le simulateur (`simuler_base()`, nom proposé ; ADR 0008), `valider_plan()`, l'export et l'import du plan et de la fiche, le rejeu et la comparaison de deux résultats (ADR 0007), le rapport figé. `NAMESPACE` écrit à la main, un `export()` par fonction, sans `exportPattern` ; sont exportés les points d'entrée et les fonctions que l'application appelle (contrôles de saisie à sens métier, E4.3) ; chaque export est cité dans la documentation (concordance, E3.3) et motivé dans le commit par son appelant hors package.
6. **Application Shiny à part, sous `app/`, hors du package** (Q14, A5) : `app/app.R` et `app/affichage.R`, lancée par `shiny::runApp("app")` ; n'appelle que des fonctions exportées de `provie`, jamais `provie:::` ; aucun calcul, aucune édition des données en ligne ; disposition d'`outil_usp` (zone principale, panneau de paramètres à droite, bouton unique « Relancer les calculs ») ; le plan s'édite, s'exporte et s'importe ; les onglets (E5.2) affichent l'objet retourné. Tout contrôle de saisie à sens métier existe aussi dans le package.
7. **Frontière calcul / affichage vérifiée par script en CI** : aucun symbole Shiny (`input$`, `reactive(`, `render`, `observe`) dans `R/` ; aucun `provie:::` ni aucune fonction de calcul dans `app/` ; aucun chiffre affiché qui ne vienne de l'objet retourné.
8. **Lecture des fichiers hors moteur** (E4.4) : CSV par R de base, xlsx par `openxlsx` facultatif ; la couche de lecture refuse un type incompatible sans le convertir et transmet au moteur des `data.frame` et la provenance des fichiers. [proposé] Elle vit dans le package, hors de la chaîne du moteur comme `simulation` (`R/lecture.R`, `lire_base(dossier)`), pour servir les tests et l'usage sans Shiny ; lecture à confirmer par l'ADR de forme.
9. **Ce qui remplace le fichier unique pour la revue indépendante** : le point d'entrée unique (un relecteur part d'une fonction et descend) ; le graphe d'appels contrôlé (point 3) ; la frontière contrôlée (point 7) ; le test de concordance documentation ↔ code dès la première branche de code (E3.3) ; la documentation LaTeX avec une partie par module et un tableau des fonctions par module (E3.1), index que le fichier unique donnait par simple lecture.

## Options écartées

- **Fichier unique `R/engine.R`** (`outil_usp`) : voir le contexte ; rend aussi les commits par issue illisibles (diffs entremêlés) et interdit la concordance par module.
- **Un package par famille**, ou **moteur et application dans deux dépôts** : surcoût d'outillage sans gain de revue ; la frontière est tenue par la structure du package et par script.
- **Application dans le package** (`DESCRIPTION` de type Shiny, `app.R` à la racine, `R/affichage.R`, forme d'`outil_usp`) : tout fichier de `R/` entre dans l'espace de noms (mesure d'`outil_tables`, son ADR 0007) ; l'application hors du package ne peut employer que les exports, ce que le script du point 7 vérifie.
- **Un module par garantie** (`deces.R`, `arret_travail.R`…) : contredit l'ADR 0005 (une garantie est une configuration) ; le catalogue des configurations remplace les modules par garantie.
- **Moteur recevant un chemin de fichier** : lierait le moteur au format et au système de fichiers, empêcherait les tests sur des `data.frame` construits et la séparation des empreintes (fichier lu, données reçues).
- **Points d'entrée par famille exposés à l'application** (lancer les triangles depuis un onglet, puis les engagements depuis un autre) : disperse l'état dans l'interface ; la fiche ne pourrait être reconstituée qu'en rejouant les clics ; contraire au bouton unique (Q14) et au plan exécuté d'un bloc (ADR 0007).
- **Calculs dans l'application** (totaux, écarts entre plans, empreintes « à l'affichage ») : un chiffre qui ne vient pas de l'objet retourné n'est ni reproductible ni dans le rapport figé.
- **Graphe d'appels laissé à la relecture** : un contrôle récurrent sans script en appelle un (`CLAUDE.md`, principe 7 des workflows).

## Conséquences

- **Fichiers** : `DESCRIPTION`, `NAMESPACE`, `R/` (modules du point 2), `app/app.R`, `app/affichage.R`, `tests/` (harnais sans `testthat`, comme `outil_usp` et `outil_tables` ; batteries de `CLAUDE.md`, « Commandes »), scripts de contrôle en CI (graphe, frontière, liste blanche, absence de Java, concordance), `docs/latex/doc_outil_prov_vie.tex` (une partie par module, tableaux de fonctions) ; `CLAUDE.md`, « Architecture » (déjà écrit en ce sens, *vérifié*) ; `docs/exigences.md`, E4.1, E4.3, E4.4, E4.8, E5.1 (déjà écrites) ; `README.md`, « Commandes » (déjà écrit).
- **Effet sur les résultats** : aucun (aucun code).
- **Contrats partagés** inscrits dans `docs/agents/routage.md`, § 4.2 : signature de `calculer_provisions()` et forme de l'objet retourné ; dictionnaire de la base ; format du plan et de la fiche de calcul ; formats de tables admis ; catalogue des configurations de garanties ; format des scénarios économiques (v2) ; format des jeux simulés. Toute issue qui en touche un est sensible.
- **Ce qui reste à faire** : l'**ADR de forme de la première branche de code** (comme l'ADR 0007 d'`outil_tables`) : liste définitive des modules et du graphe, classe et champs de l'objet retourné, noms des points d'entrée, règle des refus et des signalements, harnais de tests, arguments facultatifs du point 4 ; les scripts de contrôle ; la place de la couche de lecture (point 8).
- **Ce que l'ADR ne règle pas** : l'ordre d'exécution des familles quand des liens déclarés se croisent (le maintien de la garantie décès dépend des états de l'arrêt de travail ; le double effet, du décès) : la table étape → fonction de l'orchestration le fixe, sur spécification d'`actuary` ; la disposition détaillée des onglets (E5.2, « point de départ », tranchée sur pièces par le mainteneur) ; le module `projection` (v2).
- **Vocabulaire** : `CONTEXT.md`, « Plan de calcul », « Fiche de calcul », « Rejeu », « Rapport figé », « Simulateur ».

Issues : #4 (ADR de cadrage).

## Annotation du 7 novembre 2026 — validation finale d'`actuary`

Depuis la décision M61 (catégorie « règle comptable »), la PPNA et la PREC relèvent du seul module `regles_comptables` : la ligne `risque_en_cours` du tableau du point 2 se lit « famille « risque en cours » : limites du contrat, PRC (hors v1) », sans PPNA ni PREC (une méthode, une implémentation : point 3 de l'ADR 0005). La ligne `regles_comptables` comprend aussi, en v2, la provision pour frais d'acquisition reportés (ADR 0005, annotation visée, point (b) ; E2.10). Constat d'`actuary` à la revue finale de la PR #6 ; aucun effet sur les résultats.
