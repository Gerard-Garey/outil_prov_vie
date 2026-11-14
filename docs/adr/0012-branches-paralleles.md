---
status: accepted
date: 2026-11-12
---

# Branches de travail parallèles : exception à la branche unique, ouverte à l'initiative exclusive du mainteneur, sous trois conditions vérifiées par `architect` (couloirs de fichiers disjoints, aucune dépendance logique, une seule porteuse des références), avec ordre de fusion et protocole de synchronisation

*Rédigé par `architect-approfondi` (Fable, accord explicite du mainteneur du 12 novembre 2026 ; consultation 1/3 de la branche qui suit B2), au point d'étape qui suit la fusion de B2 (`main` à `89d39a8`). ADR d'organisation. **Proposé : rien de ce qui suit ne s'applique avant l'acceptation du mainteneur** et l'amendement de `CLAUDE.md` (texte proposé en « Conséquences »).*

*Accepté par le mainteneur le 12 novembre 2026, en session, au point d'étape après B2, **option (a)** : au plus deux branches de code ouvertes à la fois (point 4), une seule porteuse des références (point 8), numéros M par blocs de cent (point 13) — branche principale `claude/deces-reliquats` **M295 à M399**, `claude/outillage-controles` **M400 à M499**, troisième branche (`claude/dictionnaire-1-6`, documents seuls) **M500 à M599** (`docs/feuille-de-route.md`, § 4, M295). Statut porté à `accepted` par `architect` à la vingt-septième série ; les règles s'appliquent à la fusion de la PR d'ouverture (M296), qui porte aussi l'amendement de `CLAUDE.md`.*

## Contexte

`CLAUDE.md`, « Git et GitHub », impose « une seule branche de travail à la fois » ; `CONTEXT.md` définit la branche de travail comme « l'unique branche `claude/…` en cours » ; le README le répète (l. 45). Aucun ADR, aucune décision M et aucune section de la feuille de route ne traitent de branches parallèles (*vérifié* : `grep -rn -i 'parall' docs/adr/*.md CLAUDE.md docs/agents/*.md README.md` ne rend que le package `parallel` de R). Le 12 novembre 2026, le mainteneur demande quelles branches peuvent avancer en même temps, avec cette définition : deux branches parallélisables ne se gênent pas l'une l'autre et peuvent avancer côte à côte.

Ce qui rend la question utile maintenant (mesures du 12 novembre 2026, `main` à `89d39a8`) :

- **41 issues ouvertes**, dont 9 nées de B2 (`mcp__github__list_issues`, `totalCount` 41). B2 a porté 9 issues et 62 décisions (M233 à M294) ; la ligne Bdr de la feuille de route en attend onze, à découper.
- **La batterie unitaire dure 10 min 19 s** dans le conteneur d'une session cloud (`time Rscript tests/test_unitaires.R` : 2055 OK, 3 ATTENDU). Chaque circuit `coder` → `audit` la relance plusieurs fois : le temps d'une branche est pour une bonne part un temps d'attente.
- Les issues ouvertes se rangent par module : le module `donnees` et le dictionnaire (`R/donnees.R`, 5 290 lignes) ; les familles de calcul du capital décès (`R/engagement.R`, `R/risque_en_cours.R`, `R/tables.R`) ; l'outillage (`tests/harnais.R`, `tests/controles/`, `tests/concordance_doc_moteur.R`). Ces trois ensembles de fichiers sont disjoints.

Ce que la règle de la branche unique protège, et qu'une exception doit continuer de protéger :

1. **Les références de non-régression.** Toute régénération réécrit l'arbre entier (ADR 0011, point 22), dont `provenance.txt` (commit calculé, run) et `empreintes.md5` : deux branches qui régénèrent chacune de leur côté se contredisent sur ces deux fichiers à coup sûr, quel que soit leur code. Le commit de référence a pour unique parent le commit calculé (point 20).
2. **Le tableau avant / après et son visa.** Un tableau visé sur une branche décrit un écart à l'état de `main` au départ de la branche ; si une autre branche change entre-temps les mêmes grandeurs, le tableau visé ne décrit plus ce qui sera fusionné.
3. **Les écritures à fil unique** : numéros M et sections de `docs/feuille-de-route.md`, numéros d'ADR et annotations ajoutées en fin d'ADR, `CONTEXT.md`, version de `DESCRIPTION`, document LaTeX unique et ses décomptes contrôlés par la concordance.
4. **Un arbre de travail par agent qui écrit.** Constat de B2 (handoffs de la PR #61) : deux agents dans le même arbre se sont gênés (batteries qui prennent le diff de l'autre, bibliothèques et journaux écrasés dans le scratchpad).

Faits techniques *vérifiés* qui bornent la décision :

- `tests/controles/commit_reference.sh` contrôle la plage `origin/main..tête` **hors fusions** (`git rev-list --no-merges`) : les commits de référence d'une branche déjà fusionnée sortent de la plage des autres ; un commit de fusion de `main` n'est pas contrôlé.
- `tests/test_unitaires.R` exécute `tests/unitaires/*.R` par motif, un fichier par module : aucune liste partagée à tenir.
- `installer_provie()` (`tests/harnais.R`) installe le package dans une bibliothèque du `tempdir()` du processus : deux sessions sur deux clones ne partagent rien.
- `tests/controles/concordance_dictionnaire.R` lie le texte du dictionnaire à sa forme lisible par machine et à `VERSION_DICTIONNAIRE_ATTENDUE` : le texte visé du dictionnaire ne peut pas changer seul sur une branche.
- `fiche.txt` de chaque référence porte la version du dictionnaire (comparée) et `version_provie` (exclue des comparaisons, ADR 0011, point 6).
- Le ruleset de `main` exige une PR à jour avec `main` avant la fusion (handoff du 11 novembre 2026).

Précédent : le **correctif rapide** est déjà une branche partie de `main` pendant qu'une branche de travail est ouverte (PR #46, #57, #73, #86), sous trois conditions vérifiables. Le présent ADR étend la même logique (conditions vérifiables, écrites, contrôlées) à des branches au périmètre d'issues.

## Décision

*Proposée par `architect-approfondi` le 12 novembre 2026 ; **arrêtée par le mainteneur le 12 novembre 2026 (M295), sans modification du texte des points 1 à 24**.*

### A. Principe

1. **La branche de travail unique reste la règle.** Une branche parallèle est une exception, décidée branche par branche.
2. **Initiative exclusive du mainteneur.** Ni une session, ni un agent, ni un workflow ne propose ni n'ouvre de branche parallèle de sa propre initiative. Le mainteneur le demande ; `architect` instruit alors la demande (point 3) ; le mainteneur décide. Un point d'étape ne comporte une section « branches parallélisables » que si le mainteneur l'a demandée.
3. **Instruction par `architect` (fiche `-approfondi`, jugement).** Pour chaque paire de branches, `architect` vérifie les trois conditions de la partie B et les écrit dans la fiche de chaque branche (`docs/feuille-de-route.md`, § 1) : couloir, recouvrements maîtrisés, porteuse des références, ordre de fusion. L'avis vaut pour l'état de `main` (SHA cité) et pour les périmètres examinés ; il est refait si un périmètre change, et relu à chaque fusion.
4. **Au plus deux branches de code ouvertes à la fois.** Est « de code » une branche qui touche `R/`, `tests/`, `inst/` ou `app/`. Une **branche de documents seuls** (spécification d'`actuary`, lecture de `regulatory`, sous `docs/specifications/` ou `docs/recherche/`) peut s'y ajouter : elle ne compte pas dans ce plafond, mais elle suit les points 5 à 7 et le point 12. Au-delà, décision expresse du mainteneur, notée dans la feuille de route.

### B. Trois conditions, toutes requises

5. **Couloirs disjoints.** Chaque branche a un **couloir** : la liste fermée des fichiers et des modules qu'elle peut modifier, écrite dans sa fiche. Deux couloirs ne partagent aucun fichier, hors les **recouvrements maîtrisés** du point 6. Un recouvrement de plus se déclare comme **point de contact** : fichier, fonction ou lignes, branche qui écrit en premier, accord du mainteneur, mention dans les deux fiches.
6. **Recouvrements maîtrisés** (liste fermée), chacun avec sa règle :

   | Fichier | Règle |
   |---|---|
   | `docs/feuille-de-route.md` | point 12 |
   | § 4 de la feuille de route (décisions M) | point 13 |
   | `docs/adr/` | point 14 |
   | `CONTEXT.md` | point 15 |
   | `DESCRIPTION` (version) | point 16 |
   | `docs/latex/doc_outil_prov_vie.tex`, `docs/latex/CONVENTIONS.md` | point 17 |
   | `NAMESPACE`, `README.md` | ajouts seulement ; la branche fusionnée en second reprend les deux séries d'ajouts et relance la concordance (décompte des exports) |

7. **Aucune dépendance logique.** Aucune issue d'une branche n'a besoin du code de l'autre, ni d'une décision encore à prendre dans l'autre (spécification non visée, lecture d'un texte en cours, question au mainteneur). Un **contrat partagé** (`docs/agents/routage.md`, § 4.2) n'est modifié que par une branche à la fois ; l'autre le lit dans sa forme de `main`.
8. **Une seule porteuse des références.** Parmi les branches ouvertes, une seule, désignée à l'ouverture, peut commiter sous `tests/reference/` et modifier `tests/references.R` : la **porteuse des références**. Elle suit l'ADR 0011 sans changement. Toute autre branche a pour critère d'acceptation de chacune de ses issues « références inchangées » : batterie de reproductibilité verte sans régénération. Le rôle passe à une autre branche à la fusion de la porteuse, sur décision du mainteneur, notée dans la fiche.
9. **Une sortie de couloir est un point de décision.** Si une issue se révèle avoir besoin d'un fichier hors de son couloir, d'une décision de l'autre branche, ou change un couple de référence hors de la porteuse, la session s'arrête sur cette issue et pose la question au mainteneur, avec trois options : attendre la fusion de l'autre branche, déplacer l'issue, ou accorder un point de contact. Elle ne tranche pas seule.

### C. Ouverture

10. **L'organisation est sur `main` avant l'ouverture.** La fiche de chaque branche, son bloc de décisions (point 13) et ses numéros d'ADR réservés (point 14) sont fusionnés dans `main` avant qu'une seconde branche parte. Chaque branche part de `main`, a sa **PR brouillon** dès sa création, son périmètre fermé de trois à cinq issues, **sa session et son clone** : jamais deux branches dans un même arbre de travail.
11. **Une session connaît sa branche par son message d'ouverture.** Le mainteneur nomme la branche dans le brief de la session. La règle des sessions cloud (« tête de la seule PR brouillon ouverte ») ne vaut que s'il n'y a qu'une PR brouillon ; avec plusieurs et sans branche nommée, la session demande au mainteneur. Une session n'écrit jamais sur la branche d'une autre, ni dans sa PR, sauf pour le handoff que le mainteneur lui demande.

### D. Écritures partagées

12. **Feuille de route.** Une branche n'écrit que **sa fiche** (§ 1) et **son bloc de décisions** (§ 4). L'en-tête des mises à jour, le § 2 (branches suivantes), le § 3 (issues hors plan) et le § 5 ne sont écrits que par la branche désignée **principale** dans les fiches, ou à un point d'étape. Une branche parallèle date ses mises à jour dans sa fiche, et note dans sa PR ce qui relève des sections communes ; `architect` le consigne au point d'étape suivant.
13. **Décisions M : un bloc réservé par branche parallèle.** La branche principale poursuit la suite en cours. À l'ouverture d'une branche parallèle, `architect` lui réserve un bloc de cent numéros, à la centaine suivante, dans une sous-section propre du § 4 créée sur `main` (point 10). Un numéro est définitif dès qu'il est écrit : les messages de commit le citent. À la fusion, une ligne dit les numéros du bloc restés sans emploi. L'ordre du temps se lit dans la colonne de date.
14. **ADR.** Un numéro d'ADR se réserve dans la fiche de la branche, à l'ouverture ou à la première nécessité, par un commit qui passe par `main` (point 10) ; un numéro réservé et resté sans emploi est libéré à la fusion. Deux annotations ajoutées en fin d'un même ADR par deux branches se rangent dans l'ordre des fusions, sans qu'aucune soit réécrite.
15. **`CONTEXT.md`.** Chaque branche ajoute ses entrées. Si les deux touchent la même entrée, `architect` de la branche fusionnée en second la réconcilie après avoir fusionné `main`.
16. **Version.** Le relèvement du second chiffre (ADR 0010, point 24) reste le dernier commit `repo:` de chaque branche de code, **fait après la dernière fusion de `main` dans la branche** : la version de `main` à ce moment, plus un. Aucune branche ne relève la version tant qu'une autre doit fusionner avant elle.
17. **Documentation de fond.** Le passage unique de `docwriter` (règle 9) se fait **après la dernière fusion de `main`** dans la branche. Si l'autre branche est fusionnée après ce passage, la branche fusionne `main`, relance la concordance, et un commit `docs:` minimal remet les décomptes d'accord (troisième exception de la règle 9) ; il n'y a pas de second passage.

### E. Fusion et synchronisation

18. **Ordre de fusion écrit à l'ouverture**, révisable par le mainteneur. Par défaut : la branche qui ne porte pas les références d'abord, la plus courte d'abord.
19. **À la fusion d'une branche, chaque autre branche ouverte, avant tout nouveau commit de fond :**
    1. fusionne `main` (`git fetch origin main`, `git merge origin/main` ; commit de fusion, jamais de rebase : les SHA sont cités) ;
    2. résout les seuls recouvrements maîtrisés, selon leur règle ; un conflit sur un autre fichier est une sortie de couloir (point 9) ;
    3. relance les trois batteries et les scripts de contrôle ; un échec né de la fusion est un constat de la branche, traité en circuit 3, dans un commit propre ;
    4. met sa fiche à jour (SHA de `main` fusionné).
20. **Sortie du brouillon.** Une PR ne sort du brouillon qu'à jour avec `main`, après la revue finale complète (règle 10) sur `git diff main...HEAD` pris après la dernière fusion de `main`. Une fusion de `main` postérieure à la revue finale est revue sur son diff.
21. **Passage du rôle de porteuse.** À la fusion de la porteuse, la branche qui reçoit le rôle fusionne `main` : elle reçoit l'arbre `tests/reference/` de `main` sans conflit, puisqu'elle n'y a jamais écrit, et sa batterie de reproductibilité doit être verte avant son premier commit qui change un résultat.

### F. Traçabilité et contrôle

22. **Trace.** Le corps de chaque PR parallèle porte une ligne : « Branche parallèle (ADR 0012) : couloir …, porteuse des références : oui / non, fusion prévue : avant / après #NN ». La feuille de route porte la fiche de chaque branche et l'avis d'`architect`.
23. **Contrôle mécanique.** Avant chaque push, la session compare les fichiers touchés par les deux branches :

    ```
    git fetch origin main <autre-branche>
    comm -12 <(git diff --name-only origin/main...HEAD | sort) <(git diff --name-only origin/main...origin/<autre-branche> | sort)
    ```

    La sortie ne contient que des recouvrements maîtrisés ou des points de contact déclarés. Ce contrôle récurrent appelle un script (principe 7 des circuits) : issue proposée en « Conséquences ».
24. **Abandon.** Le mainteneur peut refermer l'exception à tout moment : la branche désignée attend la fusion de l'autre, puis reprend selon le point 19.

## Options écartées

- **Garder la branche unique sans exception.** Sûr, mais 41 issues ouvertes se rangent en ensembles de fichiers disjoints, et le temps d'une branche est surtout de l'attente (batterie de 10 min, visas). Écartée comme règle absolue ; elle reste la règle par défaut.
- **Parallélisme à l'initiative de la session ou d'`architect`.** Le coût d'une interférence (tableau visé devenu faux, référence régénérée deux fois) est porté par le mainteneur, qui vise : l'initiative lui revient.
- **Deux branches qui régénèrent, la seconde régénérant de nouveau après avoir fusionné `main`.** Faisable (le contrôle des commits de référence ignore les fusions), mais le tableau visé sur la seconde branche ne serait plus celui du run final dès que les deux effets se croisent, et une ligne inexpliquée pourrait venir de la rencontre des deux branches plutôt que d'un défaut. Écartée : une seule porteuse.
- **Branches empilées** (la seconde part de la première). La seconde hérite de tout le diff et de l'ordre de fusion de la première ; une reprise dans la première oblige à refusionner. Écartée, sauf correctif rapide (règle existante).
- **Branche d'intégration durable** entre `main` et les branches de travail. Elle déplacerait la CI de référence et le ruleset hors de `main`. Écartée.
- **Renuméroter les décisions M ou renommer les ADR à la fusion.** Les messages de commit, immuables, citent ces numéros. Écartée : numéros définitifs dès l'écriture, par blocs réservés.
- **`merge=union` dans `.gitattributes`** pour la feuille de route et les ADR. Résout les conflits d'ajout sans relecture : contraire à « rien n'est corrigé en silence ». Écartée.
- **Plusieurs agents en parallèle dans un même arbre, ou des `git worktree` d'une même session.** Constat de B2 : interférences des batteries et du scratchpad. Écartée : une session et un clone par branche.

## Conséquences

- **Effet sur les résultats** : aucun.
- **`CLAUDE.md`, « Git et GitHub »** (hors du périmètre d'écriture d'`architect` ; commit `claude:` de la session, après acceptation). Texte proposé :

  > - **Une seule branche de travail à la fois, par défaut**, au périmètre fermé d'issues fixé par le plan d'`architect` (trois à cinq issues), portée par une PR **ouverte en brouillon dès la création de la branche** : c'est la fiche de la branche. Ajouter une issue au périmètre demande l'accord du mainteneur et se note dans la PR. Toute session, locale ou cloud, se place sur sa branche de travail et y pousse.
  > - **Branches parallèles : à l'initiative exclusive du mainteneur** (ADR 0012). Ni une session ni un agent n'en propose ni n'en ouvre de lui-même. Sur sa demande, `architect` vérifie trois conditions et les écrit dans la fiche de chaque branche (`docs/feuille-de-route.md`) : couloirs de fichiers disjoints, hors recouvrements maîtrisés ; aucune dépendance de code ni de décision ; **une seule porteuse des références**, seule à commiter sous `tests/reference/`. Au plus deux branches de code ouvertes à la fois. Chaque branche a sa PR brouillon, sa session et son clone ; elle n'écrit que dans son couloir, sa fiche et son bloc de décisions M. Une sortie de couloir, ou un couple de référence modifié hors de la porteuse, est un point de décision : arrêt et question au mainteneur. Quand une branche est fusionnée, l'autre fusionne `main` avant tout nouveau commit de fond et relance les batteries ; le relèvement de version et le passage de `docwriter` viennent après la dernière fusion de `main`.

  Dans la règle des sessions cloud, remplacer la parenthèse d'identification par : « (celle que nomme le message d'ouverture du mainteneur ; à défaut, la tête de la seule PR brouillon ouverte vers `main` dont la branche commence par `claude/` ; s'il y en a plusieurs et qu'aucune n'est nommée, demander au mainteneur ; sinon `docs/feuille-de-route.md`) ».

  Dans « Changements de résultats et reproductibilité », compléter « par la session principale » par « de la branche porteuse des références (ADR 0012) ». Dans la règle 9, ajouter : « avec des branches parallèles, après la dernière fusion de `main` (ADR 0012, point 17) ».
- **`CONTEXT.md`** (à écrire par `architect` à l'acceptation, pas avant) : « Branche de travail » précisée (« la branche `claude/…` d'une session ; unique par défaut ») ; entrées nouvelles « Branche parallèle », « Branche principale », « Couloir », « Recouvrement maîtrisé », « Point de contact », « Porteuse des références », « Branche de documents seuls ».
- **Autres fichiers**, par la session : `README.md` (l. 45, même formule que `CLAUDE.md`) ; `.github/pull_request_template.md` (ligne du point 22). `docs/agents/routage.md` est inchangé : le plafond de trois consultations Fable se compte déjà par branche (§ 5.2). `.claude/workflows/circuit-technique.js` est inchangé : il travaille sur la branche courante de la session qui le lance.
- **Issue proposée** (création sur accord du mainteneur ; libellés `enhancement`, `needs-triage`) : « Scripts de contrôle : couloirs des branches parallèles (ADR 0012, point 23) » — un script de `tests/controles/` qui lit le couloir déclaré de la branche et échoue si `git diff --name-only origin/main...HEAD` en sort, avec un témoin négatif ; forme du fichier de couloir à fixer par `architect`. Résultats : aucun.
- **Première application proposée** (feuille de route, § 1.7 et § 1.8, vingt-sixième série) : `claude/deces-reliquats` (principale, porteuse des références) et `claude/outillage-controles` (parallèle).
- **Calibration** : au point d'étape qui suit la première paire fusionnée, `architect` relève les sorties de couloir, les conflits de fusion hors recouvrements maîtrisés et les constats nés des fusions de `main`, et propose de garder, de resserrer ou d'abandonner l'exception (annotation datée du présent ADR).
- **Ce que l'ADR ne règle pas** : plus de deux branches de code à la fois ; deux branches qui modifient la même famille de calcul ou le même contrat partagé (exclues par les points 5 et 7) ; le partage du temps de visa du mainteneur entre deux branches, qui reste sa décision.

Issues : aucune à ce jour (issue du script de contrôle proposée ci-dessus).

## Annotation du 12 novembre 2026 — acceptation et première application

*`architect`, vingt-septième série de la feuille de route.* Acceptation et première application, décisions du mainteneur du même jour (`docs/feuille-de-route.md`, § 4.1) :

- **M295** : ADR accepté, option (a), blocs M295 à M399, M400 à M499, M500 à M599 ; `CONTEXT.md` complété des entrées annoncées en « Conséquences ».
- **M296** : PR d'ouverture vers `main`, deux commits (`docs:` puis `claude:`) ; l'amendement de `CLAUDE.md` est appliqué par la session, sur le texte rendu par `architect` (reprise de celui des « Conséquences », complété de la règle du correctif rapide : `main` fusionnée dans chaque branche ouverte).
- **M297** : `claude/deces-reliquats`, principale et porteuse, **six issues** (#80, #88, #92, #91, #75, #87) : le plafond de trois à cinq issues de `CLAUDE.md` est dépassé par décision expresse du mainteneur ; l'ADR n'y change rien.
- **M298** : `claude/outillage-controles`, parallèle, non porteuse, session cloud séparée ; ordre de fusion Bo, puis Br (point 18).
- **M299** : première branche de documents seuls (point 4), `claude/dictionnaire-1-6`, ouverte après le visa de l'étape 0b de Br.
- **M301** : issue du script de contrôle des couloirs (point 23) accordée, créée par la session.

La calibration prévue en « Conséquences » se fait au point d'étape qui suit la fusion de Br.

## Annotation du 14 novembre 2026 — couloir lisible par machine, script `couloir.sh` (points 5 et 23 ; #94)

*Rédigée par `architect` (fiche de base, routine) le 14 novembre 2026, branche `claude/outillage-controles-2` (Bo2, PR #133, tête `67e1094`), à la fin de branche (`docs/feuille-de-route.md`, § 1.12), sur les commits de #94 (`253baab` `tests:`, `67e1094` `repo:`) et la décision du mainteneur **M359** (forme du couloir visée telle quelle, `docs/feuille-de-route.md`, § 1.12, « Forme du couloir pour #94 »). Elle réalise l'issue proposée en « Conséquences » (accordée par M301, créée sous le numéro #94). Les points ci-dessus ne sont pas réécrits. Constats *vérifiés* par `git show` des deux commits, par lecture à `67e1094` de l'en-tête de `tests/controles/couloir.sh` (l. 1 à 50) et de l'étape « Couloir de la branche » de `.github/workflows/ci.yml` (l. 86 à 101), et par exécution à `67e1094` : `bash tests/controles/couloir.sh --temoins` (« [OK] témoins : 55 cas … conformes ») et `bash tests/controles/couloir.sh` (« [INFO] aucun bloc « couloir claude/outillage-controles-2 » dans docs/feuille-de-route.md : branche sans couloir déclaré, rien à contrôler », statut 0).*

- **Point 5, « écrite dans sa fiche »** : lire « écrite dans sa fiche **sous la forme d'un bloc de code délimité par des accents graves, dont la chaîne d'information est `couloir <nom de la branche>`** » (forme de M359). Lignes du bloc : `+ <motif>` (inclus) ; `- <motif>` (exclu, prime sur `+`) ; `= <chemin> : <Mnnn>` (point de contact : fichier exact et décision M qui l'accorde, à écrire dans les deux fiches) ; `#` commentaire ; ligne vide ; toute autre ligne est un `[ECHEC]` de forme. Motifs relatifs à la racine ; `*` = tout caractère sauf `/`, `**` = tout caractère, `/` compris ; un motif terminé par `/` vaut le sous-arbre ; aucune autre syntaxe. Une seule source : la fiche, sans fichier séparé. Un bloc mal formé, non fermé, ou deux blocs pour une même branche sont des `[ECHEC]`. Le point de contact du bloc ne porte que le fichier et la décision M : la fonction ou les lignes, et la branche qui écrit en premier, restent écrites en prose dans les deux fiches (le script ne les lit pas).
- **Point 6** : la liste fermée des recouvrements maîtrisés est recopiée en constante du script (`RECOUVREMENTS_MAITRISES`, `tests/controles/couloir.sh`) : `docs/feuille-de-route.md`, `docs/adr/`, `CONTEXT.md`, `DESCRIPTION`, `docs/latex/doc_outil_prov_vie.tex`, `docs/latex/CONVENTIONS.md`, `NAMESPACE`, `README.md`. **Elle ne se modifie qu'avec une annotation du présent ADR**, et inversement.
- **Point 23, contrôle mécanique** : les deux commandes (`git fetch` puis `comm -12 …`) sont **remplacées** par `git fetch origin main <autre-branche>` puis **`bash tests/controles/couloir.sh --autre=<autre-branche>`**, lancé par la session **en local, avant chaque push** : intersection des fichiers touchés par `HEAD` et par `origin/<autre-branche>`, chacun contre `origin/main` ; échec si elle contient autre chose qu'un recouvrement maîtrisé ou un point de contact déclaré dans les deux fiches. L'intersection n'est pas lancée par la CI : elle dépend de l'état de l'autre branche au moment du push, que seule la session connaît.
- **Contrôle du couloir, ajouté** : `bash tests/controles/couloir.sh`, sans argument, lit le bloc de la branche courante (`--branche=`, à défaut `GITHUB_HEAD_REF`, puis `git rev-parse --abbrev-ref HEAD`) et échoue pour tout fichier de `git diff --name-only <base>...HEAD` hors couloir, hors recouvrements maîtrisés et hors points de contact. Il tourne **sur la CI**, dans le job « Contrôles du dépôt » (étape « Couloir de la branche », `67e1094` : témoins `--temoins` d'abord, puis le contrôle contre `origin/<branche de base de la PR>`), et **en local**. Une branche sans bloc (branche unique, dont Bo2 ; `main`) : `[INFO]`, statut 0. Une sortie de couloir détectée reste un point de décision (point 9) : le script la signale, il ne la tranche pas. Le cœur se teste sans `git` (`--temoins`, 55 cas, dont le témoin négatif d'un fichier hors couloir), joué aussi par `tests/unitaires/controles.R` (six vérifications, `253baab`).
- **Limites écrites** (en-tête de `couloir.sh`, l. 38 à 50 à `67e1094`), consignées pour un relecteur : (i) un recouvrement maîtrisé est admis au niveau du fichier, sans vérifier sa règle (version seule pour `DESCRIPTION`, ajouts seulement pour `NAMESPACE` et `README.md`, fiche et bloc M seulement pour la feuille de route, point 12) ; (ii) un point de contact est admis par son chemin, sans lecture des lignes ni de la décision M citée ; (iii) **les deux fiches sont lues dans le fichier de la branche courante** : une fiche de l'autre branche plus récente n'est pas vue ; (iv) l'intersection est un contrôle local, non de CI ; (v) **une coquille dans la chaîne d'information** (`couloirs <branche>`, `couloir<branche>`) ne fait pas un couloir : la branche est vue sans bloc (`[INFO]`, statut 0) ; (vi) un chemin qui porte un guillemet, une barre oblique inverse ou un caractère de contrôle, cité par `git`, ne correspond à aucun motif ; (vii) un bloc malformé n'est signalé que pour la branche contrôlée (et l'autre en mode intersection), plus toute chaîne d'information `couloir` mal formée, quelle que soit la branche. Les limites (iii) et (v) sont posées au mainteneur (`docs/feuille-de-route.md`, § 4.4) ; aucune n'est tranchée ici.
- **Circuit** (message de `253baab`) : audit léger conforme avec réserves (C1 à C5), une reprise, audit de la reprise conforme avec réserves (R1 corrigée par la session ; C2, coquille de la chaîne d'information non détectée, renvoyée à `architect` : limite (v)).
- **Première application** : aucune à ce jour. Bo2 est une branche unique et n'a pas de bloc ; l'exemple du § 1.12 (couloir de Bo transcrit) est sous la chaîne `text` et n'est pas lu. Le premier bloc réel s'écrira dans la fiche de la prochaine branche parallèle, à son ouverture (point 10).

**Effet sur les résultats** : aucun. Contrats partagés touchés : forme de la fiche de branche (bloc `couloir`) et liste des contrôles du job « Contrôles du dépôt ». `CONTEXT.md`, « Couloir », précisé. Issues : #94 ; PR #133 ; décisions M301, M359.
