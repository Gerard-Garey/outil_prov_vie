# CLAUDE.md

Ce fichier guide Claude Code (claude.ai/code) dans ce dépôt.

## Contexte

`outil_prov_vie` **recalcule, à une date d'arrêté déclarée, les provisions** des garanties d'assurance vie et de prévoyance assurables en France par un organisme d'assurance (société d'assurance, mutuelle, institution de prévoyance) (v1 : décès et arrêt de travail, garanties liées ; v2 : épargne en euros et en unités de compte, avec l'actif facultatif et la projection actif-passif sous scénarios économiques ; v3 : retraite, préretraite et indemnités de fin de carrière), à partir d'une **base de gestion** (contrats, affiliations, sinistres, événements, dossiers, prestations, rentes en service, cotisations), sous **deux référentiels** : comptes sociaux et meilleure estimation Solvabilité II, avec le tableau de passage. C'est un outil de **validation actuarielle** (second regard de la fonction actuarielle, revue externe), jamais un calcul de production : les provisions inscrites par l'organisme ne sont pas une entrée, et l'outil ne rend aucun verdict de suffisance ; les « options » sont un plan de calcul déclaré, dont les variantes se comparent. Ce qui prime : la rigueur (chaque chiffre a sa provenance et son statut), la traçabilité documentation ↔ code ↔ résultats, et la reproductibilité (un calcul se rejoue à l'identique à partir de sa fiche de calcul). Le dépôt ne contient **aucune donnée réelle** : la base brute fictive est tirée par le simulateur du package sous une loi vraie et une graine, avec des défauts de données paramétrés. Les **tables sont toujours des entrées** (réglementaires ou d'expérience, dans leur format natif ou celui d'`outil_tables`) ; un **triangle n'est jamais une entrée**, il est reconstitué de la base sinistres. IFRS 17 et le SCR sont hors périmètre. Contraintes fortes : R 4.3.3, moteur en R base, package `provie` modulaire à point d'entrée unique, application Shiny à part, une méthode = une implémentation pour toutes les garanties.

Textes qui font foi, par référentiel (détail et statuts : `docs/exigences.md` § 2.8 ; faits sourcés : `docs/recherche/2026-11-07-cadre-provisionnement-vie.md`) : comptes sociaux — Code des assurances R343-3 et R343-7 (listes des provisions), A132-1 (taux technique), A132-10 à A132-17 (participation aux bénéfices), A132-18 à A132-19 et annexes (tables homologuées), règlement ANC 2015-11 (art. 142-x, 143-x, dont **143-12 : lois de maintien des articles 600-2 à 600-4**, 600-5), loi Évin art. 7 et 7-1, CSS L911-8 ; **A331-22 n'est plus en vigueur depuis 2016 et A335-1 est abrogé : ne jamais les citer comme textes en vigueur** ; les « tables BCAC » ne sont pas une source ; Solvabilité II — directive 2009/138/CE art. 48 et 76 à 86, règlement délégué (UE) 2015/35 art. 17 à 42 (18 limites du contrat, 22 hypothèses, 23 décisions de gestion futures, 26 comportement des preneurs, 37 à 39 marge de risque), 55, 272 et annexe I, directive (UE) 2025/2 et règlement délégué (UE) 2026/269 (coût du capital de 4,75 % au 30 janvier 2027), orientations EIOPA, notice ACPR. Les tables homologuées se lisent sur le fac-similé du JO, jamais par extraction de texte. Les décisions du mainteneur sont dans `docs/cadrage/2026-11-07-entretien-cadrage.md` (Q1 à Q35, A1 à A9, G1 à G22) et `docs/feuille-de-route.md` § 4.

Le dépôt de référence est `https://github.com/Gerard-Garey/outil_prov_vie` (public, licence PolyForm Noncommercial 1.0.0), utilisé depuis le poste local et depuis des sessions cloud. `docs/exigences.md` contient le cahier des charges : le lire avant toute évolution de fond ou de l'interface.

## Commandes

Les commandes courantes (lancer, tester, compiler) sont dans `README.md` : s'y reporter plutôt que de les recopier ici.

Batteries de vérification, lancées depuis la racine du dépôt par `coder`, `audit`, le workflow `circuit-technique` (liste `BATTERIES` de `.claude/workflows/circuit-technique.js`, identique à ce bloc, dans le même ordre) et, dès qu'il existe, le job « Tests (R 4.3.3) » de la CI (contrôle requis du ruleset de `main`). Les scripts sont créés par la première branche de code (décision A2 du cadrage) ; jusque-là, seul le job « Contrôles du dépôt » tourne :

```
Rscript tests/test_unitaires.R
Rscript tests/test_reproductibilite.R
Rscript tests/concordance_doc_moteur.R --strict
```

Règles des tests : un défaut connu est codé en échec attendu, avec renvoi à l'issue ; un succès inattendu fait échouer la batterie, et la marque est alors retirée pour en faire un test ordinaire. Pour vérifier un point isolé, appeler directement la fonction concernée du package plutôt que tout le programme. Les contre-vérifications par les packages avancés (`ChainLadder`, `actuar`, `lifecontingencies`, `msm`, `markovchain`… ; aucun package qui dépende de Java) sont des valeurs écrites en dur dans les tests, produites par un script **hors CI** qui consigne la version de R et celle des packages ; régénération sur ordre du mainteneur, avec tableau avant / après.

## Git et GitHub

- **Aucun push direct sur `main`** : chaque modification passe par une branche et une pull request, fusionnée par le mainteneur (**commit de fusion**, jamais squash ni rebase : les SHA sont cités dans les ADR, les issues et les PR) une fois la CI verte. Seule exception : instruction explicite du mainteneur pour un push donné. Le ruleset de `main` l'impose (voir `README.md`, « Sécurité du dépôt »).
- **Une seule branche de travail à la fois**, au périmètre fermé d'issues fixé par le plan d'`architect` (trois à cinq issues), portée par une PR **ouverte en brouillon dès la création de la branche** : c'est la fiche de la branche. Ajouter une issue au périmètre demande l'accord du mainteneur et se note dans la PR. Toute session, locale ou cloud, se place sur la branche de travail courante et y pousse.
- **Session cloud : la branche de travail l'emporte sur la branche assignée.** La consigne de démarrage (« Develop on branch `claude/<nom-aléatoire>` ») est écartée par la règle précédente, sans autre autorisation. Avant toute écriture : identifier la branche de travail (tête de la seule PR brouillon ouverte vers `main` dont la branche commence par `claude/`, sinon `docs/feuille-de-route.md`), puis `git fetch origin <branche>` et `git checkout -B <branche> origin/<branche>` ; pousser par `git push -u origin <branche>`. Supprimer la branche assignée (`git branch -D`, et `git push origin --delete` si elle a été poussée). Si aucune branche de travail n'est ouverte, demander au mainteneur.
- **Corps de PR : un `Closes #N` par ligne**, un par issue du périmètre (« Closes #41, #40 » ne lie que le premier numéro). Après la fusion, vérifier que chaque issue annoncée est fermée.
- **Handoff en commentaire de PR** : quand le mainteneur demande un handoff (passation à une autre session), la session le rédige en commentaire de la PR en cours (celle de la branche de travail, ou du correctif rapide), jamais dans un fichier du dépôt, et donne le lien du commentaire dans sa réponse. Sans PR ouverte, demander au mainteneur où le déposer.
- **Un commit par issue qui change un résultat**, avec son tableau avant / après et son visa (« Changements de résultats » ci-dessous).
- **Un problème hors périmètre devient une issue**, pas une branche, sauf **correctif rapide** — trois conditions vérifiables : résultats strictement identiques, un seul domaine de commit, aucune modification de la documentation de fond. Il suit une branche temporaire partie de `main`, PR directe vers `main` ; `main` est ensuite fusionnée dans la branche de travail.
- **Création d'issue sur accord du mainteneur** : agents et sessions rédigent l'issue proposée (titre, libellés, corps) dans leur compte rendu ; elle n'est créée qu'une fois approuvée, sauf autorisation explicite du brief. Le corps d'une issue rédigée par un agent commence par `> *Rédigé par l'agent <nom> (IA).*`.
- **Messages de commit en français**, avec accents, préfixés par le domaine et renvoyant à l'issue (`#3`) quand elle existe. Domaines : `moteur:` (package `provie`), `app:` (`app/`), `tests:`, `docs:` (`docs/`, README, `CONTEXT.md`, documentation LaTeX), `donnees:` (jeux simulés, tables de référence et fichiers de provenance), `claude:` (`CLAUDE.md`, `.claude/`), `repo:` (`.github/`, `.gitignore`, `DESCRIPTION`, licence).
- **Auteur des commits faits par Claude** (sessions, sous-agents, workflows ; poste local comme cloud) : `Claude <noreply@anthropic.com>` (`git config user.name Claude` et `git config user.email noreply@anthropic.com` dans le dépôt), jamais l'identité du mainteneur ; le pied de message garde `Co-Authored-By` et, en session cloud, `Claude-Session`.

## Architecture (contrainte impérative)

Décidée au cadrage (`docs/exigences.md` § 4 fait foi ; ADR de cadrage à la suite de 0003).

- **Package `provie`** (`R/`) : **toute** la logique quantitative — lecture du dictionnaire et contrôles de la base, traitement des défauts, tables en entrée et leurs formats, les quatre **familles de calcul** (engagement, triangle, risque en cours, projection en v2) et la catégorie **règle comptable** (provision pour égalisation, PPNA, PREC, puis les postes de l'actif en v2), plan de calcul et fiche de calcul, quantités du rapport et empreintes, rendu du rapport figé (octets HTML, sans calcul), simulateur (hors de la chaîne du moteur) —, dans un module par famille ou par service, avec un **point d'entrée unique** `calculer_provisions(donnees, plan, tables = list(), provenance = NULL)` (ADR 0010) qui exécute un plan de calcul d'un bloc et retourne un objet complet. Le moteur reçoit une **liste de `data.frame` (les tables de la base), un plan et, en arguments facultatifs, les tables importées et la provenance, jamais un fichier**. Une garantie est une **configuration** des familles et des règles, jamais un moteur à part ; une méthode applicable à deux garanties n'a qu'une implémentation. Dépendances : **packages de priorité `base` seulement** ; exception par ADR propre à chaque méthode ; **aucune dépendance à Java**, directe ou indirecte, dans tout le projet ; R pur, mesuré, avant tout code compilé, par ADR. Utilisable sans Shiny : aucun `input$`, `reactive()`, `render*()`.
- **Lecture des fichiers** (CSV en R base, xlsx par `openxlsx` optionnel sans dépendance du calcul) : couche mince hors moteur, qui refuse un type incompatible sans le convertir.
- **`app/affichage.R`** : formatage, tables HTML de l'affichage interactif, tracés à partir des quantités du résultat uniquement. Aucun calcul.
- **`app/app.R`** : interface Shiny locale, hors du package (lancée par `shiny::runApp("app")` ; n'appelle que des fonctions exportées de `provie`, jamais `provie:::`) ; zone principale, panneau de paramètres à droite ; édition du plan, appel de `calculer_provisions()` **uniquement** sur clic du bouton « Relancer les calculs », stockage du résultat, affichage. Aucun calcul, aucune édition des données en ligne. Tout contrôle de saisie ayant un sens métier existe aussi dans le package.
- **Données** : jeux simulés (loi vraie et graine consignées), tables de référence embarquées avec leur fichier de provenance, courbes EIOPA et série TME, sous `inst/extdata/` ; références de non-régression sous `tests/reference/`.

Si un résultat peut être calculé indépendamment de l'interface, il va dans le package.

## Changements de résultats et reproductibilité

- À données, plan et graine identiques, le programme produit des résultats identiques au bit près sur une même machine ; toute source d'aléa passe par une graine locale explicite sous un générateur pseudo-aléatoire fixé, consignée dans le résultat.
- Toute modification qui change un résultat est **identifiée, quantifiée et expliquée** : un **tableau avant / après** (grandeur, avant, après, écart, explication), une ligne par grandeur modifiée, chaque ligne expliquée par la modification ; une ligne inexpliquée est une régression à corriger, pas une référence à régénérer.
- **Visa** : tout changement d'une **provision totale** (par garantie et par référentiel) ou d'un **verdict de validation** (réalisé / attendu, témoin) est soumis au mainteneur ; les autres changements sont validés par `actuary`. Sans visa, rien n'est commité.
- Les références de non-régression ne sont régénérées qu'après visa, par la session principale (jamais par un agent ni un workflow), **sur la CI seule** (workflow de régénération, Ubuntu, R 4.3.3, bibliothèques fixées, plateforme consignée dans le message du commit de référence) ; aucune régénération sur un poste, celui du mainteneur compris. Comparaison aux références valeur par valeur, à tolérance.

## Rigueur

- **Une affirmation sur le comportement du code s'adosse à une mesure exécutée** (commande et sortie), citée dans le compte rendu. Une explication plausible non vérifiée est la façon la plus sûre d'introduire une erreur qui survit aux relectures.
- **Un chiffre ne se recopie pas, il se remesure** ; un chiffre qui vient d'une source (texte, table, publication) se vérifie contre cette source, citée.
- Ne fabriquer aucune référence, aucun numéro d'article, aucune valeur de table ni résultat ; si la source ne permet pas de conclure, l'écrire. Un fait du rapport de recherche au statut « incertain » ou « non trouvé » n'est pas une source : `regulatory` l'établit avant toute citation.
- Faire évoluer les livrables existants plutôt que les réécrire ; ne jamais remplacer silencieusement une méthode ni réintroduire une formule déjà corrigée.
- Cinq statuts ne se confondent jamais : résultat exact, asymptotique, approximation numérique, constat de simulation, jugement d'expert ; l'erreur de simulation (nombre de réplications), l'erreur d'estimation (volume de données) , l'erreur de modèle et l'aléa de processus se distinguent. Toute hypothèse est déclarée dans le plan, sans valeur par défaut ; les hypothèses par défaut des données dégradées sont des jugements d'expert documentés. Rien n'est corrigé en silence dans les données : chaque défaut a son traitement déclaré (refus, exclusion, hypothèse par défaut, signalement) (`docs/exigences.md` § 2).

Le vocabulaire du projet est défini dans `CONTEXT.md` : l'employer tel quel dans le code, la documentation et les issues.

**Documents LaTeX** : tout document LaTeX du projet part de la charte `docs/latex/charte_graphique.tex` (celle de `docu_actu` dans sa version courante, ADR 0003 annoté ; préambule repris sans modification hors passages bornés par « >>> À ADAPTER » et « <<< À ADAPTER », corps d'exemple remplacé par le contenu) et emploie ses macros et environnements plutôt qu'une mise en forme ad hoc ; il se compile avec pdfLaTeX. La documentation de fond est le document unique `docs/latex/doc_outil_prov_vie.tex`, à la forme d'`outil_tables` (parties par module, tableaux de fonctions, concordance doc ↔ code), conventions dans `docs/latex/CONVENTIONS.md` (`docs/exigences.md` § 3).

## Sous-agents

Sept sous-agents de projet (`.claude/agents/` ; onze fiches : `architect`, `actuary` et `regulatory` ont une variante `-approfondi`, `coder` sa variante Opus `coder-approfondi`), orchestrés par la session principale. Règle de séparation : **ceux qui écrivent ne vérifient pas, ceux qui vérifient n'écrivent pas**.

| Famille | Agent | Écrit | Question |
|---|---|---|---|
| Pilotage | `architect` | `docs/adr/`, `CONTEXT.md`, `docs/feuille-de-route.md` | Dans quel ordre, avec quels agents, sous quelle forme ? |
| Fond | `actuary` | rien (avis, recensements, spécifications, plans, issues proposées) | Est-ce juste actuariellement, dans les conditions du projet ? |
| Fond | `regulatory` | rien (lectures de textes, matrice de conformité, provenances, issues proposées) | Est-ce exactement ce que prescrivent les textes ? |
| Réalisation | `coder` | code du package et de l'application, tests (pas `docs/latex/`) ; surface d'impact documentaire dans le commit proposé | Comment l'implémenter ? |
| Réalisation | `docwriter` | `docs/latex/` | Documentation juste, rigoureuse, conforme à `docs/latex/CONVENTIONS.md`, concordante avec le code ? |
| Vérification | `audit` | rien (rapport) | Code correct et reproductible ? |
| Vérification | `app-review` | rien (rapport) | Interface conforme à `docs/exigences.md` § 5 ? |

**Routage du modèle et de l'effort** (`docs/agents/routage.md`, ADR 0001) — `architect`, `actuary` et `regulatory` existent en deux fiches au même corps : la fiche de base (Opus, effort `medium`, routine) et la fiche `-approfondi` (Opus, effort `high`, jugement), générée par `bash .claude/outils/fiches_jumelles.sh` et contrôlée par la CI ; ne jamais modifier une fiche `-approfondi` à la main. La session principale choisit la fiche selon la matrice de `docs/agents/routage.md` (§ 3) et ne passe `model: "fable"` à l'appel que dans les cas du § 4.1 (échec documenté d'Opus `high`, désaccord entre agents, rédaction d'un ADR d'architecture) ou sur accord du mainteneur ; au plus une relance ciblée, une hausse d'effort et une consultation Fable par question, trois consultations Fable par branche sans nouvel accord ; un modèle indisponible arrête le circuit (aucun remplacement silencieux). Les agents signalent les critères rencontrés dans leur bloc « Retour », ils ne décident pas de leur escalade ; la session note chaque escalade, relance ciblée ou arrêt d'une ligne dans la PR de la branche de travail.

**Modèle et effort des agents de réalisation et de vérification** (`docs/agents/routage.md`, § 10, ADR 0002) — fixés par leur fiche : `coder` Sonnet, effort `high` ; `coder-approfondi` (même corps, générée par `fiches_jumelles.sh`) Opus, effort `medium` ; `audit` et `docwriter` Opus, effort `medium` ; `app-review` Sonnet, effort `high`. En circuits 1 et 2 (évolution de fond, correction de conformité), la session appelle `coder-approfondi` d'office, reprises comprises. Ailleurs — tâche de codage longue ou complexe, issue de circuit 3 finie en `arrete` parce que `coder` n'a pas corrigé les constats après la reprise —, elle le **propose** au mainteneur et ne l'emploie qu'avec son accord, au cas par cas, sans plafond chiffré (dans le workflow `circuit-technique`, option `--approfondi`). L'effort `high` pour `coder-approfondi` (paramètre `effort` de l'appel ; `--approfondi=high`) demande aussi son accord. La revue finale complète d'`audit` (règle 10) est appelée avec `effort: "high"`. Chaque emploi de `coder-approfondi` hors circuits 1 et 2, et chaque passage de `coder-approfondi` à l'effort `high`, est noté d'une ligne dans la PR.

**Déclencheurs** — un agent n'entre dans le circuit que si la modification touche son domaine : plusieurs issues ou forme du package → `architect` en amont ; poste, méthode, hypothèse, dictionnaire de la base, défaut de données, critère de validation → `actuary` (recensement ou spécification en amont, validation en aval) ; texte qui fait foi, provision et son rattachement, table embarquée ou sa provenance, plafond réglementaire → `regulatory` (lecture du texte en amont, contrôle de conformité en aval) ; `R/` du package ou `tests/` → `audit` ; `app/` → `app-review` ; fond de `docs/latex/` → `docwriter`, en dernier, une seule fois par branche (règle 9).

**Circuits types** (chacun se termine par un ou plusieurs commits de la session principale sur la branche de travail) :

1. **Évolution de fond** : `actuary` spécifie (recensement des méthodes ou spécification visés par le mainteneur) → `coder` → `audit` (+ `app-review` si l'interface change) → `docwriter` (en fin de branche) → `actuary` valide.
2. **Correction de conformité** (écart à un texte qui fait foi, à une table ou à un plafond réglementaire) : `regulatory` établit la lecture du texte → `actuary` éclaire l'interprétation → le mainteneur tranche si une provision totale ou un verdict change → `coder` → `audit` → `regulatory` contrôle la conformité → `docwriter`.
3. **Correction technique** : `coder` → `audit` (workflow `circuit-technique`).
4. **Documentation seule** : `docwriter` (+ `actuary` ou `regulatory` si le fond change).

Un constat bloquant ou majeur d'un vérificateur renvoie à l'étape de réalisation. Quand une source admet deux lectures, `regulatory` les décrit, `actuary` éclaire l'interprétation, le mainteneur tranche.

**Workflows** (`.claude/workflows/`). Un workflow met en œuvre un circuit type et en fixe les appels d'agents, les sorties structurées et les conditions d'arrêt. Huit principes :

1. lancement **sur commande explicite du mainteneur** uniquement ;
2. **aucune écriture dans l'historique ni l'état partagé** par le workflow ou ses agents : ni `git commit`, ni `git push`, ni régénération de référence, ni création d'issue — interdiction portée par les consignes et les fiches, les permissions de `.claude/settings.json` ne l'imposant pas : la session principale vérifie `git status` et `git log` après chaque workflow ;
3. **arrêt avec les rapports à tout point de décision** (question de fond, visa du mainteneur, contradiction entre vérificateurs) ;
4. **au plus une reprise** `coder` → `audit` ;
5. **vérificateurs ciblés sur le diff** (audit léger) ;
6. **constats structurés** : gravité (bloquant / majeur / mineur), `fichier:ligne`, mesure exécutée ; un constat sans emplacement ni mesure n'est pas recevable ;
7. **tout contrôle mécanique est un script**, jamais un agent : un agent lit la sortie d'un script, il ne refait pas le décompte ; un contrôle récurrent sans script en appelle un (issue) ;
8. **effort réduit** pour les étapes mécaniques ; aucun `model` fixé dans un workflow : un agent lancé avec `agentType` prend le modèle de sa fiche, les autres celui de la session (ordre documenté par Claude Code, pas encore mesuré dans un workflow : le confirmer par le modèle servi, `bash .claude/outils/bilan_journal.sh`, au premier passage).

Un **constat** (défaut du code) conduit à la reprise ou à l'arrêt ; une **question de fond** (doute de `coder`, question de l'audit, pour `actuary` ou `regulatory`) ne relance pas `coder`. Trois statuts de fin : `termine`, `termine avec questions` (les seules remontées sont des questions : la session principale les porte à `actuary` ou `regulatory` avant tout commit), `arrete` ; une batterie en échec à la dernière vérification finit toujours par `arrete`.

**Règle 9 — un seul passage de `docwriter` par branche** : `docwriter` intervient une fois, en fin de branche, sur l'état final du code, avec **un commit `docs:` par issue** ; `coder` ne modifie pas la documentation de fond et liste dans chaque commit proposé la **surface d'impact documentaire** (sections, tableaux, décomptes, fonctions citées), dont `docwriter` part ; `actuary` (et `regulatory` pour les textes) valide le diff de la documentation une fois, en fin de branche. Exceptions : commit `docs:` préparatoire qui protège la suite, branche où le document porte la décision et précède le code, écart de concordance qui ferait échouer la CI (commit `docs:` minimal, aussitôt).

**Règle 10 — audit léger en cours, revue finale complète avant la sortie du brouillon** : pendant l'implémentation, `audit` (et `app-review`) se limitent au diff et aux fonctions touchées avec leurs appelants et appelés ; avant la sortie du brouillon, revue finale complète du `git diff main...HEAD` entier (fonctions touchées avec appelants et appelés, batteries complètes, scénarios adverses, cohérence code ↔ tests ↔ documentation) par les vérificateurs que désignent les déclencheurs, plus `/code-review` ; toute correction postérieure est revue à son tour, sur son diff. La relecture intégrale hors diff est réservée aux jalons de livraison.

**Revues périodiques**, hors de tout changement : `architect` (point d'étape et feuille de route, après chaque série de PR fusionnées) ; `actuary` et `regulatory` (revue de fond avant livraison) ; `app-review` et `docwriter` (relecture intégrale avant démonstration ou livraison).

## Décisions et vocabulaire

- **ADR** (`docs/adr/NNNN-titre-court.md`, gabarit `docs/adr/0000-gabarit.md`) : toute décision d'architecture ou d'organisation, et toute piste rejetée pour une raison qu'un futur relecteur devrait connaître. Rédigés par `architect` ; une décision du mainteneur y est datée. Une proposition qui contredit un ADR le signale explicitement et dit pourquoi le rouvrir.
- **`CONTEXT.md`** : glossaire du domaine et de l'organisation.
- **`docs/feuille-de-route.md`** : périmètre de la branche de travail en cours et des suivantes, décisions du mainteneur numérotées (M1, M2…).

## Agent skills

### Issue tracker

Issues et specs dans les GitHub Issues du dépôt : outils `mcp__github__*` en session cloud, CLI `gh` sur le poste local. Voir `docs/agents/issue-tracker.md`.

### Triage labels

Les cinq libellés canoniques (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). Voir `docs/agents/triage-labels.md`.

### Domain docs

Mono-contexte : un `CONTEXT.md` et `docs/adr/` à la racine. Voir `docs/agents/domain.md`.
