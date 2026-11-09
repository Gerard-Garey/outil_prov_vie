# Spécification du module `donnees` — v1 (base entière et vue, enjeu des lignes écartées, conventions d'âge)

> *Rédigé par l'agent actuary (IA) le 8 novembre 2026 (issue #18, branche `claude/donnees-simulation`, PR #29), sur les questions 4.2 et 4.3 de l'avis d'`actuary-approfondi` sur la question 5d (portée d'un refus) et sur la question 4.5 (conventions d'âge, ADR 0010, cinquième série, (g)). Statut : version `1.1` **visée** par le mainteneur le 8 novembre 2026 (errata E1 à E26) ; la version `1.0` l'a été le même jour (M151). Les décisions des visas sont intégrées par l'agent actuary (IA) (version `1.1` : le 9 novembre 2026), et la session principale contrôle leur transcription au versement.*
>
> *Historique des versions :*
> - *`0.1` : proposition du 8 novembre 2026 (questions 4.2 et 4.3), rendue à la session principale, non versée ;*
> - *`0.2` : même jour ; signature à date d'arrêté obligatoire et bilan sans déclaration (M147, M148), conventions d'âge (question 4.5) ;*
> - *`0.3` : même jour ; correction de la convention `naissance_31_decembre`, qui était fausse d'un an, et de la portée de l'art. 143-3 du règlement ANC 2015-11, sur la lecture de `regulatory` du 8 novembre 2026 ;*
> - *`1.0` : visée par le mainteneur le 8 novembre 2026 (M151), avec les décisions suivantes :*
>   - *table longue `enjeu`, avec `action = non_declaree` sans déclaration et liste fermée des composantes ;*
>   - *quatrième argument `conventions` de `controler_base()` (M147 rouverte) ;*
>   - *conventions d'âge, avec l'égalité du 1er juillet bissextile et le 29 février ;*
>   - *règle de limite d'âge de D07 (c) ;*
>   - *visibilité non déterminée ;*
>   - *questions 4.6 et 4.9 ;*
>   - *place des lignes du bilan selon l'ADR 0010, sixième série, (b).*
> - *`1.1` : visée par le mainteneur le 8 novembre 2026 (errata E1 à E26, visés en bloc), transcrite par l'agent actuary (IA) le 9 novembre 2026. Les errata sont ceux du commentaire « Errata de la spécification du module `donnees` (v1.0 → v1.1) » de la PR #29, rédigé par l'agent architect à `0fa93d4` et complété par la session principale (E24 à E26). Ils portent :*
>   - *les décisions M167 à M178 de la feuille de route et les formes de l'ADR 0010, neuvième série ;*
>   - *le report déclaré des contrôles non écrits à la fermeture de #18 (issue #34) ;*
>   - *D02c pour un âge, D07 (c) et l'enjeu sous lien de garantie non résolu, écrits dans `000f7fc` ;*
>   - *la priorité de la cause directe sur tout `refus_induit`, règle B comprise (décision du mainteneur du 8 novembre 2026).*
>
> *Les points du dictionnaire `1.6` relevés avec les errata (P6 à P17) ne sont pas intégrés (§ 7).*

**Références.**
- Les numéros de ligne sont ceux du dépôt à `da90d7e` pour les textes cités en version `1.0`. Les renvois au code ajoutés en version `1.1` (`R/donnees.R`) sont à `5c53ad4`.
- Les décisions M167 à M178 (`docs/feuille-de-route.md`) sont étiquetées D1 à D12 dans la PR #29 ; ces étiquettes, ambiguës avec les codes de défaut, ne sont pas employées ici. L'ADR 0010, neuvième série, est cité par sa lettre.
- Le dictionnaire est cité dans sa version `1.5` (`docs/specifications/dictionnaire-base-v1.md`, abrégé « dict. »).
- L'ADR 0010 (`docs/adr/0010-forme-du-package-provie.md`) est abrégé « ADR 0010 ».
- Les codes `D..` sont ceux du § 9 du dictionnaire ; les codes de contrôle, ceux du § 1.10 (dict. :168-183), transcrits dans `controles.csv`.

**Objet.** La présente spécification fixe, pour le lot (c) `donnees` de #18 :
- ce qui s'évalue sur la base entière et ce qui s'évalue sur la vue à l'arrêté (§ 2) ;
- le bilan sans déclaration (§ 3) ;
- l'enjeu des lignes refusées ou exclues (§ 4) ;
- les conventions d'âge (§ 5) ;
- deux règles de B2 (§ 6).

Elle ne fixe pas la forme interne du code (`architect`), ni les méthodes des postes (recensements).

**Cadre décidé.**
- M143, option B (`docs/feuille-de-route.md`, décisions) : un refus `R` porte sur une table ou une colonne.
- M144 (lecture L2) et M145 (D09, lecture (a)).
- M146 : dictionnaire `1.5` visé.
- M147, rouverte au visa : signature, § 1.
- M148 : bilan sans déclaration.
- M149 : `controles.csv`.
- M150 : lectures (i) et (ii) de M144.
- Forme du bilan : ADR 0010, point 9 (:73), complété par les annotations des cinquième (:278-281) et sixième séries (:299-310).
- Version `1.1` : M167 à M180 et ADR 0010, neuvième série (formes du bilan et des déclarations) ; report déclaré des contrôles non écrits (issue #34) et priorité de la cause directe sur tout refus induit, décisions du mainteneur du 8 novembre 2026 (M181, M185) ; ADR 0010, dixième série.

## 1. Signature

`controler_base(donnees, arrete, declarations, conventions)` :
- **`arrete`** : `Date` de longueur 1, obligatoire, sans valeur par défaut (M147) :
  - absent : `plan_incomplet` ;
  - mal formé : `plan_invalide` ;
  - postérieur à `extraction.date_extraction` : `arrete_posterieur_extraction` ;
- **`declarations`** : le sous-schéma `donnees` du plan (ADR 0010, point 17, :90). Omis, il se lit « aucune déclaration fournie » (M148) ;
  - **forme** (M170, M174, M177 ; ADR 0010, neuvième série, (e) ; `.lire_declarations()` et ses auxiliaires, `R/donnees.R:407-563`) :
    - rubriques `exclusions` (`motif`, `famille`, `action`) et `hypotheses` (`motif`, `referentiel`, `poste`, `valeur`), en `data.frame` ou en liste de listes nommées, chaînes renseignées ;
    - `seuils` (liste nommée) ;
    - `evaluations_gestion` (`diagnostics`) ;
  - **refus `plan_invalide`** pour :
    - un motif qui n'admet pas le traitement déclaré ;
    - D10 déclaré sans sous-cas, ou un traitement que le sous-cas n'admet pas ;
    - une exclusion de D03a ou de D12 pour la famille `triangle` ;
    - D03g avec une action autre que `exclure` ;
    - D02b ou D03g avec un poste autre que `tous`, des valeurs différentes entre référentiels, ou un signalement déclaré ;
    - un signalement déclaré hors de la liste D05, D06, D07 (sous-cas (a) et (c)), D08, D10 (f), D13, D14, ou qui n'est pas la seule ligne de son (motif, référentiel) ;
    - un motif à traitement unique (D02a, D03a, D03c, D03f) déclaré à la fois en exclusion et en hypothèse (D03g excepté, M177) ;
- **`conventions`** : la section `conventions` du plan (M151, quatrième argument ; ADR 0010, sixième série, (d), :312). Omise, elle a l'effet de M148 :
  - D02c (âge invraisemblable) et D07 (c) vont dans `controles_non_executes`, avec `cause = "declaration_absente"` ;
  - ils vont aussi dans `declarations_requises`, rubrique `conventions` (§ 3).
  - Les sous-éléments lus sont `age` et `limite_age` (§ 5).

## 2. Base entière ou vue à une date (question 4.2)

### 2.1 Ce que fixent les textes

| Fait | Source | Statut |
|---|---|---|
| La vue à A retient les lignes visibles et la partie de ligne connue à A ; les valeurs `E` sont celles de l'extraction | dict. :662-680 (§ 6) ; E2.6, `docs/exigences.md:25` | texte |
| Une ligne fille n'est visible que si sa parente l'est | dict. :684 (§ 6, règle 1) | texte |
| La vue à `date_extraction` est la base entière (contrôle d'identité) | dict. :686 (§ 6, règle 3) | texte |
| `donnees` reconstitue la vue « avant tout calcul » | ADR 0008, point 9, `docs/adr/0008-base-brute-fictive-dictionnaire-simulateur-defauts.md:28` | texte |
| Les bornes de date se rapportent à la date d'extraction, jamais à l'arrêté | dict. :82-84 ; D02c, dict. :742 | texte |
| `R` : « l'extraction est à reprendre » | dict. :154 | texte |
| D02b et D03g ont un traitement qui dépend de l'arrêté | dict. :741, :749 | texte |
| D07 (b) : « aucune prestation depuis plus de N mois » | dict. :755 | texte (A, seule lecture cohérente avec la vue) |
| Le réalisé / attendu recalcule à partir de la vue à l'arrêté précédent | E2.22, `docs/exigences.md:56` | texte |
| Partage des contrôles entre base et vue | aucun texte | jugement d'expert (§ 2.3), visé (M151) |

### 2.2 Règles

- **Règle B (base entière, indépendante de A).** Elle couvre :
  - les contrôles de structure (codes `colonne_absente`, `colonne_inconnue`, `type_incompatible`) ;
  - le domaine des valeurs (`manquant_obligatoire`, `hors_domaine`, `chaine_vide`, D02c pour une date hors domaine) ;
  - les clés (D01a, D04a, D04b), `chevauchement`, `table_conditionnelle_absente` et `refus_induit` ;
  - tout défaut traité `R` (D09 pour le signe, D10 (a) et (h)).
- **Règle P (préalables de la vue).** D02b et D03g sont détectés sur la base entière, après la règle B, puisqu'une fille « saisie avant sa parente » suppose des clés résolues. Leur traitement s'applique à la construction de la vue.
  - **D03g à A < extraction** (M171, M175, M177 ; jugement d'expert) :
    - sous `H` (déclaré pour les deux référentiels, délai par table dans `seuils$d03g_delai_jours`, commun aux deux référentiels, sans valeur par défaut), visibilité d'une ligne entière = max(date d'effet + délai, visibilité de la parente). La date d'effet est celle que compare D02b (`evenements.date_effet`, `sinistres.date_declaration`, `catastrophes.date_evenement`, visibilité de la parente pour les tables filles) ;
    - pour une partie de ligne (`contrats.date_saisie_fin`, `affiliations.date_saisie_fin`), fin connue à `date_fin` + délai ;
    - sous `X` (`exclure` seul, quatre familles), toutes les lignes entières de D03g sortent de la vue avec leur cascade ; une partie de ligne n'est résolue que par `H` ;
    - `X` et `H` peuvent être déclarés ensemble : `X` exclut les lignes entières, `H` résout les parties ;
    - sans `X`, une ligne entière dont la date ne se calcule pas sous `H` reste non déterminée et attend `X`.
- **Règle V (vue).** Les défauts traités `X`, `H` ou `S`, hors D02b et D03g, sont détectés, traités et chiffrés sur la vue à A :
  - lignes visibles ;
  - partie de ligne connue à A ;
  - ligne valable de `famille`.

  Le code `somme_parts` relève aussi de la règle V.
- **Règle I (identité).** À A = `date_extraction`, les comptes de la règle V égalent ceux d'une détection sur la base entière, et D02b et D03g sont en `S` (dict. :686).
- **Colonne refusée, règle P empêchée** (M169, M178 ; ADR 0010, neuvième série, (f)) :
  - un refus `R` de valeur sur une colonne ordinaire rend la colonne inutilisable pour les règles P et V (le contrôle qui la lit va dans `controles_non_executes`, cause = motif du refus) ;
  - à A < extraction, une règle P empêchée sur une table lue par la vue (colonne lue refusée ou illisible, valeur manquante comprise) produit un refus induit de portée table, propagé aux filles par les clés étrangères (code `refus_induit`, origine `table.colonne`) ;
  - une règle V empêchée à la fois par une cause directe et par ce refus induit garde la cause directe (règle générale de priorité au § 3.1).

**Ordre d'exécution.**
1. Interruptions (ADR 0010, cinquième série, (a) 1, :273).
2. Forme.
3. Domaine.
4. Clés et refus induits.
5. Détection de D02b et D03g.
6. Construction de la vue.
7. Règle V.
8. Enjeu (§ 4).

Chaque étape suppose les précédentes : une clé mal typée ne se joint pas, et la vue suppose des clés résolues.

### 2.3 Motifs

1. **Ce qui découle du texte.**
   - La structure, les types et le domaine ne citent pas l'arrêté (dict. :82-84).
   - D01a et D04 précèdent la vue. La règle 1 du § 6 (dict. :684) suppose des clés résolues. Une ligne orpheline, sans parente visible, serait écartée par la vue elle-même : ce serait une exclusion silencieuse, contraire à dict. :150.
   - D02b et D03g modifient la visibilité. D07 (b) se mesure à A.
2. **Jugement d'expert, visé : la base entière pour les refus `R` qui ne portent pas sur une clé.**
   - **Motif.**
     - `R` qualifie l'extraction (dict. :154).
     - Une même base rend le même bilan de refus à tout arrêté. Sinon, le réalisé / attendu comparerait deux calculs dont l'un arrête un poste que l'autre calcule.
     - Une valeur hors domaine sur une ligne postérieure à A signale un défaut du processus d'extraction.
   - **Alternative écartée** : les évaluer sur la vue.
   - **Effet** : des postes sont arrêtés pour une ligne invisible à A ; c'est le sens prudent. L'effet chiffré se mesure en B2, sur un jeu simulé avec D09 `part_signe_inverse` > 0, aux deux arrêtés du réalisé / attendu.
   - **Restitution** : colonne `nombre_visibles` après `nombre` dans `refus_tables` (ADR 0010, sixième série, (b) 5 (ii), :304).
3. **Jugement d'expert, visé : la vue pour les traitements `X`, `H` et `S`.**
   - **Motif** : leur traitement agit sur le calcul à A, et plusieurs changent de nature avec A :
     - D01b : la copie est saisie après l'original (dict. :739) ;
     - D02a sur `famille` : corrections (dict. :407) ;
     - D02a sur une fin de contrat : `date_fin` connue à `date_saisie_fin` (dict. :668) ;
     - D03d : « périmée » (dict. :746) ;
     - D07 (a) et (c) ;
     - D11 : affiliation rétroactive (dict. :392) ;
     - D12 : préfixe valide à A ;
     - D13 : `date_instruction` en `V` (dict. :435).
   - **Alternative écartée** : détecter sur la base entière puis restreindre à la vue. Elle est fausse pour D01b, D02a (`famille`), D07, D11, D12 et D13.
   - **Effet** : aucun à A = extraction.

### 2.4 Liste par défaut et par code

| Défaut ou code | Détection | Traitement et enjeu | Source | Statut du partage |
|---|---|---|---|---|
| `colonne_absente`, `colonne_inconnue`, `type_incompatible` | base | base (`R`) | dict. :168-183 ; M143 | texte |
| `manquant_obligatoire`, `hors_domaine`, `chaine_vide` | base | base (`R`) | dict. :114-121, :168-183 | texte |
| `chevauchement` | base | base (`R`, table) | dict. :319, :361 | texte |
| `table_conditionnelle_absente`, `refus_induit` | base | base (`R`, table) | dict. :161-166, :212 | texte |
| `somme_parts` | vue | vue (`S`) | dict. :462 | jugement |
| D01a | base | base (`R`, table) | dict. :738 | texte (dict. :684) |
| D01b | vue | vue ; traitement `S` + `X` (deux constats de même clé : signalé dans tous les cas, exclusion déclarable) | dict. :739 | jugement |
| D02a | vue | vue | dict. :740 | jugement |
| D02b | base (règle P) | construction de la vue ; `S` à A = extraction | dict. :741 | texte |
| D02c, date hors domaine | base | base (`R`, colonne) | dict. :742 | texte |
| D02c, âge invraisemblable | vue | vue (S + X) | dict. :742 ; § 5 | jugement ; détection intrinsèque à la ligne (§ 5.4) |
| D03a à D03f, D03h | vue | vue | dict. :743-748, :750 | jugement |
| D03d | vue | vue | dict. :746 | texte (« périmée ») et jugement |
| D03g | base (règle P) | construction de la vue ; `S` à A = extraction, `H` ou `X` sinon | dict. :749 | texte |
| D04a, D04b (`X`) | base | lignes orphelines dont la condition propre de visibilité tient à A | dict. :751-752 | texte pour la détection ; jugement pour la visibilité, visé |
| D04b (`R`) | base | base (`R`, table) | dict. :752 | texte |
| D05, D06, D08 | vue | vue | dict. :753, :754, :756 | jugement |
| D07 (a), (b), (c) | vue | vue ; (a) et (b) reportés (note ci-dessous) | dict. :755 | texte pour (b) ; jugement pour (a) et (c) |
| D09, signe | base | base (`R`, colonne, M145) | dict. :757 | jugement (§ 2.3, 2) |
| D09, seuils, capital incohérent | vue | vue ; reporté (note ci-dessous) | dict. :757 | jugement |
| D10 (a), (h) | base | base (`R`) ; portée de D10 (a) : table de la table fille (`dossiers`, `rentes`, `prestations`), visée, texte en `1.6` | dict. :758 | jugement |
| D10 (b) à (f) | vue | vue | dict. :758 | jugement |
| D11 à D14 | vue | vue | dict. :759-762 | jugement |

**D03h et D03a** (M168) :
- D03h sur un contrat collectif (maintien de la garantie décès, illisible) : non exécuté, cause `non_lisible`, tant que le dictionnaire n'a pas de colonne « porte le maintien » (`1.6`) ;
- D03a : deux constats de même clé, `S` (famille `triangle`, écrit dès la détection) et `X;H` (autres familles).

**Contrôles reportés à la fermeture de #18** (cause `non_implemente`, issue #34 ; M172, M181) : D03d, D07 (a) et (b), D08, D09 aux seuils, D10 (d) à (f), D11, D12, D14.
- D09 : rapport au salaire et multiple de la médiane du segment en B2, avec la segmentation ; capital incohérent en B3, par la reconstitution du capital (M172).

**Pas d'exclusion `X` d'une valeur illisible ou hors domaine en v1** (question 4.9, M151) : ces anomalies restent des refus `R`.

### 2.5 Critères d'acceptation

1. **Invariance** : pour A1 ≠ A2 sur une même base, les lignes du bilan des règles B et P (détection) sont `identical()`.
2. **Identité** : à A = extraction, chaque compte de la règle V égale celui d'une détection directe sur la base entière, et D02b et D03g sont en `S`.
3. **Aucune exclusion par la vue** : toute orpheline injectée (registre de D04) figure au bilan à tout arrêté.
4. **Registre** : à A = extraction, détection exacte égale à l'injection (dict. :733). À A < extraction, pour les défauts intrinsèques à la ligne (D02a hors `famille`, D03a à D03f), les lignes détectées égalent les lignes injectées visibles à A.
5. **Refus sur ligne invisible** : un D09 de signe injecté sur une prestation de `date_saisie` > A figure dans `refus_tables` à A, avec `nombre_visibles = 0`.

## 3. Place des lignes du bilan et bilan sans déclaration

### 3.1 Place des lignes (ADR 0010, sixième série, (b), :299-304)

- **`refus_tables`** : tout refus `R`, défaut `D..` ou code de contrôle.
  - `portee` vaut `colonne` ou `table`, portée effective résolue par la règle du § 1.10 : `colonne_table` devient `table` pour une colonne de clé primaire ou une colonne qui porte une référence.
  - `colonne` est la colonne d'origine, `NA` pour `refus_induit` et `table_conditionnelle_absente`.
  - `origine` d'un `refus_induit` (M178 ; ADR 0010, neuvième série, (f) ; `.refus_p_empechee()`, `R/donnees.R:1375-1409`) : tables visées refusées, et, pour un refus né d'une règle P empêchée, la colonne « table.colonne » qui l'empêche, jointes par « ; » (colonnes d'abord, en tri radix, puis tables dans l'ordre du dictionnaire).
  - Une table facultative refusée porte le code de sa cause (M146) ; elle ne figure pas dans `tables_absentes`, et aucune variante « sans » ne la remplace.
- **`signalements`** : toute anomalie traitée `S` :
  - `somme_parts` ;
  - D02b et D03g à A = extraction ;
  - D09 présomptif ;
  - la part `S` d'un traitement `S` + `H`, etc. ;
  - un constat à choix dont le signalement est déclaré pour au moins un référentiel (valeur réservée `signalement` de `hypotheses`, M170) ;
  - la part `S` de D03a et de D12 pour la famille `triangle`, écrite dès la détection.

  `signalements` n'a ni colonne de référentiel ni colonne de famille : la portée d'un signalement se lit dans les déclarations du plan (référentiel) ou dans le § 9 du dictionnaire (famille) (ADR 0010, neuvième série, (a) et (g)).

  En Bd, un code de portée `ligne` est traité en `S` (ADR 0010, sixième série, (a), :297).
- **`exclusions`** : traitements `X` déclarés (`exclure`, `conserver`). L'action `conserver` reste dans `exclusions`.
  - Un constat couvert n'est placé que dans un élément par famille ou par référentiel.
  - Les couples D03a × `triangle` et D12 × `triangle` sont hors du critère de couverture (`S`).
  - Une exclusion des orphelines D04a et D04b ne compte que les lignes dont la visibilité propre tient à A (§ 2.4).
- **`controles`** : toute détection. Chaque ligne se retrouve dans exactement un élément de traitement ou dans `declarations_requises` (invariant testé).
- **`controles_non_executes`** : un contrôle empêché par un refus (`cause` = son motif) ou par une déclaration absente (`cause = "declaration_absente"`) ; ou pas encore écrit (`non_implemente`) ; ou illisible (`non_lisible`, D03h collectif) ; ou empêché par le refus induit d'une règle P empêchée (`refus_induit`), s'il n'a pas de cause directe (ADR 0010, huitième série, (a) et (e), et neuvième série, (c) ; M168, M178).
  - Une composante de l'enjeu empêchée y figure aussi, sous le code de la composante (§ 4.3), avec la table et la colonne lues.
  - Une clé (code, table, colonne) présente à la fois dans `controles` et ici est une détection partielle : son nombre est un minorant.
  - **Priorité des causes** (décision du mainteneur du 8 novembre 2026) : la cause directe (refus d'une colonne lue) passe avant **tout** `refus_induit`, règle B comprise.

### 3.2 Bilan sans déclaration (M148)

Sans déclaration, `controler_base()` exécute toutes les détections et remplit `declarations_requises` (ADR 0010, sixième série, (b) 4, :303) :
- `exclusions` : par motif `X` détecté et par famille de calcul (dict. :155) ;
- `hypotheses` : par motif `H` et par référentiel (dict. :156) ;
- `seuils` : `d03g_delai_jours` (par table de D03g) et `d02c_age_min`, `d02c_age_max` (par emploi, § 5.4) (M171, M172 ; ADR 0010, neuvième série, (b)) :
  - une ligne `seuils` existe si et seulement si le contrôle qui lit le seuil est écrit et que le seuil est absent ; les seuils de D09 et le nombre de mois de D07 (b) viendront avec leurs contrôles (M172, issue #34) ;
  - clé : « nom$table » ou « nom$emploi » ; `traitements_admis = NA` ;
  - `nombre_lignes = NA` pour une ligne dont le seuil conditionne la détection elle-même (D02c) ; c'est le nombre de lignes en attente pour D03g ;
- `conventions` : `age` pour D02c et `limite_age` pour D07 (c) (§ 5), clés `age`, `limite_age$regle` et `limite_age$age` ; pour cette rubrique, `traitements_admis` porte la liste fermée des valeurs admises, jointe par « ; » (`atteinte;depassement`, `revolu;millesime`, liste des conventions d'âge) (ADR 0010, dixième série, (c)) ;
- pour D03g à A < extraction (M175, M177 ; ADR 0010, neuvième série, (h)) : `H;X` pour une ligne entière, `H` pour une partie de ligne ; d'où, par référentiel, jusqu'à deux lignes `hypotheses`. Sous `H` appliqué, une ligne entière dont la date ne se calcule pas par elle-même reçoit une ligne `exclusions` à `traitements_admis = "X"` par famille. Une ligne qui suit sa parente non déterminée ne reçoit pas d'exigence propre.

**Visibilité non déterminée (M151).**
- À A < extraction, une ligne de D03g non résolue (déclaration incomplète, ou date non calculable sous `H`), ou de D02b dont le `H` n'est pas déclaré, n'a pas de date de visibilité (M167, M171). Ces lignes sont :
  - tenues hors de la vue pour les détections de la règle V ;
  - recensées dans `vue$visibilite_non_determinee` (`table` ; `colonne` : `NA` pour la ligne entière, sinon la partie de ligne ; `motif`, dont `parente_non_determinee` pour les filles écartées par la règle 1 ; `nombre` ; `identifiants`).

  Une partie de ligne non déterminée laisse la ligne dans la vue.

  `vue$provisoire` vaut `TRUE` si ce sous-élément n'est pas vide, ou si une règle P a été empêchée sur une table lue par la vue (cette table et ses filles portent alors un refus induit de portée table, § 2.2, M178) : les comptes de la règle V sont alors provisoires. Invariant testé : `provisoire` ⇒ `declarations_requises` non vide, ou refus de portée table sur chaque table rendue provisoire.
- Aucune provision n'en dépend : le calcul de B2 refuse par `declaration_manquante`.
- **Alternative écartée** : tenir ces lignes pour visibles. Ce serait une hypothèse par défaut non déclarée, contraire à E2.20 (`docs/exigences.md:51`) et à l'option écartée d'ADR 0010, cinquième série, (f) (:285).

**Enjeu sans déclaration** : l'enjeu de chaque motif `X` détecté est calculé avec `action = non_declaree` (M151 ; ADR 0010, sixième série, (c) 3, :309), pour montrer l'exposition avant le choix. Cette modalité n'apparaît jamais dans `resultat_provie` (B2).

## 4. Enjeu des lignes refusées ou exclues (question 4.3)

### 4.1 Ce que fixent les textes

| Fait | Source | Statut |
|---|---|---|
| Enjeu des lignes **refusées ou exclues**, par motif et par poste, nombre de dossiers et derniers montants connus ; « une ligne écartée sous-évaluant mécaniquement la provision » | E2.5, `docs/exigences.md:24` | texte |
| `X` : enjeu par motif et par poste | dict. :155 | texte |
| L'enjeu couvre la cascade | dict. :159 | texte |
| ADR 0008, point 10, **ne parle pas** d'enjeu | `docs/adr/0008-…:29` | texte (l'avis 5d, § 1.3, disait le contraire : inexact) |
| `evaluations_gestion` : lue par les diagnostics (a) et (b) seuls | dict. :692-694 (§ 7.2) ; E2.1, `docs/exigences.md:20` ; M68 | texte |
| Aucune modification des données | dict. :150 | texte |
| Unités : capital en €, rente en € par an, indemnité journalière en € par jour, salaire en € par an | dict. :99-103 | texte |
| Prestations extraites : celles réglées dans la fenêtre | dict. :143 | texte |
| Montant en vigueur reconstitué des événements | dict. :230 ; dict. :490 | texte |
| États à une date et enjeu : module `donnees` | ADR 0010, point 1, :36 | texte |
| Forme : table longue `enjeu` | ADR 0010, sixième série, (c) 1, :307 ; M151 | décision |
| Définition des composantes, rattachement, agrégation | aucun texte | jugement d'expert, visé (M151) |

**Statut de l'enjeu.** C'est un **résultat exact** (comptes et sommes à A), un indicateur d'exposition, et **non une estimation de la sous-évaluation**. Celle-ci se mesure en comparant deux plans qui ne diffèrent que par l'action (`exclure` contre `conserver`). Le rapport figé le dit.

### 4.2 « Connus » et « derniers »

- **Connus** = connus à A, sur la vue (§ 2, règle V). Une ligne invisible à A n'a aucun montant connu à A.
- **Derniers** : pour une grandeur qui évolue, la dernière valeur connue à A. Ordre de départage :
  1. `date_effet` ≤ A ;
  2. ordre des types à date égale (dict. :594) ;
  3. `date_saisie` ;
  4. `id_evenement` en tri radix (départage reproductible).

  Une modification programmable de date d'effet postérieure à A n'est pas en vigueur.
- **Une seule implémentation** : cette reconstitution est la fonction interne de `donnees` qu'appellent `etats_a_date()` et l'enjeu (ADR 0010, sixième série, (c) 4, :310). `engagement` la lit par `etats_a_date()` sans la réécrire.
- **Aucune correction** : les montants sont pris tels quels (dict. :150).
  - Une composante qui lit une colonne de valeur refusée, ou une forme illisible, vaut `montant = NA`, avec `cause` égal au motif du refus (M173, M176).
  - Le refus qui constitue l'écart ne bloque pas son propre enjeu, ni le refus induit issu du même écart : la cascade est chiffrée. La clé étrangère de l'écart (D04a, D04b, D10 (a), (h)) est comprise : le lien reste non résolu, et la composante se calcule sur ce qui est connu sans la parente. Un autre refus direct bloque.
  - Sous D01a, une composante n'est `NA` (cause `D01a`) que pour un identifiant dont les doubles divergent sur une colonne qu'elle lit. Un identifiant ne compte qu'une fois dans les sommes par dossier.
  - Un porteur de visibilité non déterminée, ou une ligne qui entre dans sa valeur, donne `NA`, cause `visibilite_non_determinee`, hors de `controles_non_executes`. La cause l'emporte sur l'absence de porteur.
  - Hors ce dernier cas, une composante empêchée figure aussi dans `controles_non_executes`, sous le code de la composante (§ 3.1).

### 4.3 Liste fermée des composantes (M151)

Huit composantes, dix couples (`composante`, `unite`). Codes d'unité : `euro`, `euro_par_an`, `euro_par_jour` (ADR 0010, sixième série, (c) 1, :307). **Aucune agrégation ne mêle deux couples**, et aucune conversion entre unités n'est faite : elle exigerait une convention de jours ou d'annuités, hors du plan (E2.20).

| N° | `composante` | `unite` | Porteur | Définition à A |
|---|---|---|---|---|
| 1 | `paiements_cumules` | `euro` | dossier | Somme signée de `prestations.montant` (paiements et régularisations) des prestations du dossier visibles à A (dict. :677). Paiements depuis `debut_historique` seulement (dict. :143) |
| 2 | `capital_fixe` | `euro` | dossier `deces` ou `double_effet` | `montant` du dernier `fixation_capital` connu à A (dict. :604), revalorisation exclue |
| 3 | `rente_annuelle_en_vigueur` | `euro_par_an` | dossier `rente_conjoint`, `rente_education`, `invalidite` | Somme, sur les rentes du dossier, du montant du dernier `ouverture_service` ou `modification_montant` de la rente (dict. :606-607), si, parmi ses événements de service et de `fin_service` de date d'effet ≤ A connus à A, le dernier dans l'ordre du § 4.2 est un service ; sans valeur sinon (une réouverture après `fin_service` rallume la rente) ; une suspension ne l'annule pas |
| 4 | `ij_en_vigueur` | `euro_par_jour` | dossier `incapacite` | Montant du dernier `ouverture_service` ou `modification_montant` du dossier `incapacite`, si, parmi ses événements de service et d'extinction (`fin_service` du dossier, `sortie` du sinistre) de date d'effet ≤ A connus à A, le dernier dans l'ordre du § 4.2 est un service ; sans valeur sinon (une `rechute` suivie d'une nouvelle ouverture rallume l'indemnité) |
| 5 | `prestations_ecartees` | `euro` | ligne de `prestations` | Somme signée des montants des prestations refusées ou exclues **seules**, orphelines (D04a) comprises |
| 6 | `cotisations_emises_nettes` | `euro` | ligne de `cotisations` | Somme signée des montants `emission`, `annulation`, `regularisation` (dict. :520) |
| 7 | `cotisations_encaissees` | `euro` | ligne de `cotisations` | Somme des montants `encaissement` |
| 8 | `montant_evenement` | `euro` | ligne de `evenements` refusée ou exclue seule | `montant` d'un `fixation_capital` |
| 8 | `montant_evenement` | `euro_par_an` | idem | `montant` d'un `ouverture_service` ou d'un `modification_montant` dont `id_rente` est renseigné (unité lue sur l'événement, dict. :490, :606, sans lire la garantie) |
| 8 | `montant_evenement` | `euro_par_jour` | idem | `montant` d'un `ouverture_service` ou d'un `modification_montant` dont `id_rente` n'est pas renseigné (idem) |

**Non retenus** (jugements d'expert, visés) :
- `evaluations_gestion.montant_restant` : jamais (dict. :692-694, texte). Ce montant changerait le bilan, donc l'empreinte (ADR 0010, point 22, :98), selon que T18 est présente ou non.
- Capital reconstitué des paramètres : c'est un calcul, non un montant connu. `capital_fixe` n'a alors pas de valeur et ne compte pas dans `nombre_valeurs`.
- « Capital fixé non réglé » : il exige une règle de revalorisation (dict. :604, :509), qui appartient à la famille « engagement ».
- `montant_securite_sociale`.
- Nombre de sinistres pour la famille « triangle » : absent de la forme décidée ; à rouvrir en B4 si le recensement des tardifs le demande.

### 4.4 Rattachement par table

`nombre_dossiers` compte les dossiers rattachés distincts. Les composantes 1 à 4 se somment sur ces dossiers ; les composantes 5 à 8 sur les lignes.

| Table de la ligne refusée ou exclue | Dossiers rattachés | Composantes |
|---|---|---|
| `extraction` | interruption (M143) | — |
| `adherents` | dossiers dont la garantie souscrite appartient à un contrat de l'adhérent | 1 à 4 |
| `contrats` | dossiers dont la garantie souscrite appartient au contrat | 1 à 4 |
| `garanties_souscrites`, `parametres` | dossiers de la garantie souscrite | 1 à 4 |
| `assures` | dossiers des sinistres de l'assuré | 1 à 4 |
| `affiliations` | dossiers des sinistres du même assuré sous le même contrat ; pas de cascade (dict. :159) | 1 à 4 |
| `famille` | dossiers du sinistre d'instruction et dossiers qui citent le membre (`beneficiaires`, `rentes`) | 1 à 4 |
| `sinistres` | dossiers du sinistre (cascade, dict. :159) | 1 à 4 |
| `dossiers`, `beneficiaires`, `rentes` | le dossier | 1 à 4 |
| `evenements` | `id_dossier`, sinon dossiers du sinistre | 1 à 4, et 8 pour un événement refusé ou exclu seul qui porte un montant |
| `prestations` | `id_dossier` s'il existe ; 0 pour une orpheline | 5 seulement (la ligne écartée est la prestation) |
| `cotisations` | aucun ; `garantie` = `code_garantie` de la garantie souscrite si elle existe, sinon `non_rattache` | 6 et 7 |
| `catastrophes`, `victimes` | dossiers des sinistres déclarés des victimes | 1 à 4 |
| `evaluations_gestion`, `designations`, `ayants_droit_sante` | aucun | aucune ligne dans `enjeu` ; nombre de lignes dans `refus_tables` ou `exclusions` |

**Garantie non rattachée.** Quand la garantie d'un dossier est `non_rattache` faute de lien (D10 (a) ou D04 sur `dossiers.id_garantie_souscrite`), les composantes 2 à 4 restent applicables et se calculent sur les événements du dossier ; elles valent 0 sans événement de ce type, et `NA` avec cause si elles ne se calculent pas sans la parente (écrit dans `000f7fc`).

**Par traitement** :
- **`R`** (`action = refus`, `famille = ensemble`) :
  - l'enjeu porte sur les lignes qui portent le défaut, non sur la table entière ;
  - un refus induit n'a pas d'enjeu propre ;
  - les lignes invisibles à A comptent dans `nombre` et n'ont aucun montant.
- **`X`** : enjeu sous `exclure`, `conserver` ou `non_declaree`. Pour `conserver`, il se lit comme l'exposition des lignes gardées.
- **`H` et `S`** : aucun enjeu au sens d'E2.5. L'effet d'une hypothèse par défaut est chiffré dans la fiche (E2.20 ; dict. :156).

**Visibilité et comptes de l'enjeu** :
- pour les lignes de l'écart D03g (sous `exclure` comme sous `non_declaree`), visibilité pour l'enjeu = max(date que compare D02b, visibilité de la parente) ≤ A (délai 0), en plus des autres dates de la vue ; les parties de ligne restent masquées ;
- les enjeux par écart ne s'additionnent pas ;
- `nombre_visibles` et `nombre_dossiers` suivent la vue, règle 1 comprise (versions valables de `famille`), et valent `NA` si une visibilité est indéterminée.

### 4.5 Table `enjeu` et agrégation

Colonnes (M151 ; ADR 0010, sixième série, (c) 1, :307) :

| Colonne | Contenu |
|---|---|
| `table` | table du motif ; `NA` dans la rangée `motif = ensemble` (ADR 0010, neuvième série, (d)) |
| `colonne` | colonne du motif, ou `NA` ; `NA` dans la rangée `motif = ensemble` |
| `motif` | code `D..` ou code de contrôle ; `ensemble` pour la rangée tous motifs |
| `famille` | famille de calcul ; `ensemble` pour un refus |
| `action` | `exclure`, `conserver`, `non_declaree`, `refus` |
| `garantie` | `code_garantie` ; `non_rattache` ; `ensemble` |
| `poste` | `ensemble` en Bd ; postes ajoutés en B2 par l'orchestration avec la table de couverture |
| `composante` | § 4.3 |
| `unite` | § 4.3 |
| `montant` | double, jamais arrondi |
| `nombre_dossiers` | dossiers rattachés distincts |
| `nombre_valeurs` | dossiers ou lignes qui portent une valeur de la composante |
| `cause` | `NA`, ou motif du refus qui empêche la composante, `D01a` ou `visibilite_non_determinee` (§ 4.2) ; `montant` vaut alors `NA` |

**Agrégation.**
1. **Niveau élémentaire** (motif, famille, action, dossier ou ligne) : interne à `donnees`, dans une seule fonction non exportée (ADR 0010, :307).
2. **Rangées** : par motif × famille × action × garantie, et par garantie `ensemble`. La jointure se fait avec `exclusions` par (`motif`, `famille`, `action`) et avec `refus_tables` par (`table`, `colonne`, `motif`).
3. **Par poste** (E2.5) : en B2.
4. **Rangée `motif = ensemble`**, par famille et par action :
   - elle compte des dossiers distincts ;
   - ses montants se somment sur ces dossiers distincts ;
   - ce n'est pas la somme des rangées par motif.
5. **Invariants testés** :
   - aucune agrégation entre couples (`composante`, `unite`) ;
   - `montant` vaut `NA` si et seulement si `cause` est renseignée ;
   - la rangée `ensemble` est au plus égale à la somme des rangées par motif ;
   - tri selon l'ADR.

### 4.6 Critères d'acceptation

1. L'enjeu de chaque exclusion égale un recalcul indépendant par jointure sur le registre des défauts (ADR 0010, point 19, :95) : nombres et sommes égaux à l'identique.
2. Le bilan, `enjeu` compris, est identique au bit près avec ou sans T18 (dict. :695, étendu au bilan).
3. À A = extraction, l'enjeu de la cascade d'un sinistre exclu égale la somme des composantes de ses dossiers.
4. Une composante qui lit une colonne refusée a `montant = NA`, `cause` renseignée, et figure dans `controles_non_executes`, sous le code de la composante.
5. Un dossier touché par D01b et D02a compte une fois dans la rangée `ensemble`.
6. Pour un dossier, `montant_en_vigueur` d'`etats_a_date()` égale la composante 2, 3 ou 4 correspondante.
7. `non_declaree` n'apparaît que si `declarations` ne couvre pas le motif.

## 5. Conventions d'âge (question 4.5)

### 5.1 Ce que fixent les textes

- L'âge se calcule à partir des dates (dict. :110). Sa lecture est une convention du plan, jamais une règle du dictionnaire (dict. :109). C'est la section `conventions` (ADR 0010, point 17, :90).
- `calculer_age(date_naissance, date, convention)` est logée dans `outils`, seule fonction d'âge du package (ADR 0010, cinquième série, (g), :286).
- **Art. 143-3 du règlement ANC 2015-11**, lu par `regulatory` le 8 novembre 2026 sur le rendu graphique du recueil ANC « Secteur de l'assurance », version en vigueur au 1er janvier 2025 (p. 21-22 imprimées) : « Pour le calcul de la provision mathématique des rentes mentionné à l'article 143-2 du présent règlement, la date de naissance du rentier est reportée au 31 décembre le plus voisin. »
  - L'art. 143-2 vise les rentes d'incapacité et d'invalidité des risques du 3° de L310-1. L'art. 143-12 (risques du 2°) n'y renvoie pas. **Aucun poste de la v1 n'en relève** : en v1, le report est une convention retenue **par analogie** (jugement d'expert, M151).
  - Lecture de `regulatory`, non relue sur le fac-similé par `actuary`.

### 5.2 Liste fermée (M151)

| Convention | Définition, pour une naissance N et une date D ≥ N | Emploi en v1 |
|---|---|---|
| `revolu` | Nombre d'anniversaires de N atteints au plus tard à D : année(D) − année(N), moins 1 si (mois, jour) de D précède (mois, jour) de N | tous emplois |
| `millesime` | année(D) − année(N) | tous emplois |
| `plus_proche` | `revolu`, plus 1 si l'anniversaire suivant est plus proche de D que le précédent ; à égalité, l'âge supérieur | interdite pour D07 (c) |
| `naissance_31_decembre` | `revolu` avec N reportée au 31 décembre le plus voisin : celui de l'année précédant N si N tombe au plus tard le 1er juillet, celui de l'année de N sinon. Au 31 décembre, l'âge vaut année(D) − année(N reportée) | par analogie (§ 5.1) ; **interdite pour D07 (c)** ; **déconseillée pour D02c** |

**Règles communes (M151).**
- **Égalité au 1er juillet d'une année bissextile** (183 jours de chaque côté) : 31 décembre précédent. La règle tient en une date du calendrier, identique en toute année. Pour une rente viagère, c'est la variante la moins prudente ; elle ne touche que ces naissances.
- **29 février** : âge atteint le 1er mars en année non bissextile.
- L'âge est **entier**, en années.
- **D < N** : âge `NA`, contrôle dans `controles_non_executes`, cause `age_non_defini` (cas d'un défaut D02a ou D02c). Enfant `a_naitre` : âge non défini.
- **Fonction inverse** : `date_atteinte_age(date_naissance, age, convention)` donne la première date où l'âge vaut `age`. Elle est logée avec `calculer_age()`.

**Valeurs de test** (`Rscript age_final.R` sur la définition ci-dessus, R 4.3.3 du conteneur cloud, 8 novembre 2026), âge au 31/12/2026 avec `naissance_31_decembre` :
- 1970-03-15 → 57 ;
- 1970-06-30 → 57 ;
- 1970-07-01 → 57 ;
- 1970-07-02 → 56 ;
- 1972-07-01 → 55 (égalité tranchée au 31/12/1971) ;
- 1972-07-02 → 54 ;
- 1970-10-15 → 56.

Avec `revolu`, pour une naissance le 2000-02-29 : âge 0 le 2001-02-28 et 1 le 2001-03-01.

### 5.3 Limite d'âge (D07 (c), M151)

- `conventions$limite_age` porte deux éléments, sans défaut :
  - `regle` : `atteinte` (la charge cesse à l'anniversaire de `age_limite`) ou `depassement` (à l'anniversaire suivant) ;
  - `age` : `revolu` ou `millesime`, appliqué à la naissance réelle de l'enfant.
- La même déclaration est lue par la famille « engagement » (rente d'éducation, double effet ; dict. :640, :643), en B3.
- Le second élément (`age`) est une forme **validée** (M164).
  - Motif : une clause « jusqu'au 26e anniversaire » se lit en `revolu`, une clause « jusqu'au 31 décembre de l'année des 26 ans » en `millesime`.
  - Il ne peut pas reprendre `conventions$age`, qui peut valoir `naissance_31_decembre` pour les rentes.
- Le texte du dictionnaire est à mettre en accord en `1.6` (§ 7).

**Détection de D07 (c)** (écrite dans `000f7fc`) :
- constat sur `rentes` (rente d'éducation en service ; enfant = `rentes.id_membre`) et sur `dossiers` (`double_effet` ni clos ni de **second décès retenu à A** ; enfants = famille de l'assuré du sinistre, ligne valable à A), `colonne = NA` ;
- « à charge » = lien `enfant`, non décédé à A ;
- détection si **chaque** enfant à charge a atteint sa limite ;
- prolongation pour études pour `situation` ∈ {`scolarise`, `apprenti`} (décision du mainteneur, jugement d'expert) ; `age_limite_etudes` absent : pas de prolongation ;
- limite non déterminable (paramètre absent ou à plusieurs valeurs, palier compris) pour un enfant dont elle décide : non exécuté, cause `parametre_non_defini` ; sur `dossiers`, la ligne n'est émise que si l'indétermination peut changer le résultat, c'est-à-dire si aucun enfant à charge du dossier n'est non éteint de façon déterminée (limite déterminée non atteinte, prolongation pour handicap, naissance manquante relevée par D03a) (M187, avis d'`actuary` du 9 novembre 2026) ;
- sans `conventions$limite_age` : non exécuté (`declaration_absente`), et deux lignes requises, `limite_age$regle` et `limite_age$age`.

### 5.4 Emplois dans `donnees`

| Contrôle | Personne | Date de référence | Convention |
|---|---|---|---|
| D02c, assuré au sinistre | `assures.date_naissance` | `sinistres.date_survenance` | `conventions$age` |
| D02c, assuré à l'affiliation | `assures.date_naissance` | `affiliations.date_debut` ; contrat individuel : `contrats.date_effet` | idem |
| D02c, membre de la famille | `famille.date_naissance` (ligne valable à A, hors `a_naitre`) | survenance du sinistre d'instruction ; sans sinistre : `famille.date_saisie` | idem |
| D02c, désigné ou ayant droit | `designations.date_naissance`, `ayants_droit_sante.date_naissance` | `date_saisie` de la ligne | idem |
| D07 (c), chaque enfant à charge (§ 5.3) | `famille.date_naissance` (ligne valable à A, `lien = enfant`, non décédé à A ; rente d'éducation : `rentes.id_membre`) | A ; extinction reconstituée par `date_atteinte_age()` | `conventions$limite_age` |

- **D02c et la vue.** Les dates de référence de D02c sont des dates de la ligne : la détection est intrinsèque à la ligne et reste en règle V, puisque son traitement s'applique à A.
- **Bornes de vraisemblance** : une paire par emploi, déclarée dans `seuils$d02c_age_min` et `seuils$d02c_age_max` (dict. :742 ; ADR 0010, huitième série, (b), et neuvième série, (b)) :
  - listes nommées par emploi : `assures_sinistre`, `assures_affiliation`, `famille`, `designations`, `ayants_droit_sante` ;
  - âges entiers, sans valeur par défaut, communs aux deux référentiels ;
  - un emploi dont la table est présente et dont une borne manque n'est pas exécuté (`controles_non_executes`, `colonne = NA`, cause `declaration_absente`) et figure dans `declarations_requises` (rubrique `seuils`) (écrit dans `000f7fc`).

### 5.5 Tables des art. 600-2 et 600-3 (pour B3, M151)

- **Âge `revolu` à la date d'entrée dans l'état**, constant pendant le maintien. C'est un jugement d'expert déclaré : les textes, d'après `regulatory` et le rapport (`docs/recherche/2026-11-07-cadre-provisionnement-vie.md:33-34`), disent « âge à l'entrée en invalidité » et « âge à l'arrêt de travail » sans préciser la lecture.
- Dates d'entrée :
  - 600-3 : `sinistres.date_survenance`, premier jour d'arrêt, avant franchise (dict. :433) ;
  - 600-2 : date d'effet de `entree_invalidite` ou `passage_invalidite` (dict. :599-600).
- Ancienneté en années ou mois révolus.
- **Alternatives** : `plus_proche` ; interpolation entre âges (choix de méthode de B3).
- **Effet** : à mesurer en B3 par constat de simulation.
- Aucune publication de place retrouvée sur ce point.

**Hors du lot `donnees`** : `age_fin_service`, `age_fin_garantie`, `age_terme`, `age_limite_conjoint`, paliers `age_min` et `age_max` (B3, même fonction).

## 6. Règles pour B2 (M151)

1. **Total arrêté (question 4.6).** La cellule totale d'une garantie (`poste = "total"`, ADR 0010, point 7 (f)) dont un poste est arrêté est arrêtée elle aussi, avec la liste des postes manquants. Elle n'est jamais la somme des postes calculés, qui sous-évaluerait en silence. Grandeur sous visa (A3).
2. **Déclarations requises dans le calcul.** `declarations_requises` est toujours vide dans `resultat_provie` ; une ligne non vide y est un refus `declaration_manquante` (ADR 0010, sixième série, (b) 4, :303).

## 7. Points notés pour le dictionnaire `1.6`

1. **D07 (c)** : remplacer « a dépassé `age_limite` » (dict. :755) par un renvoi à la règle de limite déclarée (`conventions$limite_age`, § 5.3), et préciser au § 5 (dict. :640, :643) que la lecture de `age_limite` est cette règle.
2. **D10 (a)** : portée table de la table fille (`dossiers`, `rentes`, `prestations`), à écrire au § 1.10 ou au § 9 (dict. :758).
3. **Colonne `traitement` (`R`, `S`)** au tableau des codes du § 1.10 et dans `controles.csv` (proposition d'ADR 0010, sixième série, (a), :297), qui rend explicite le `S` de `somme_parts`.
4. **Question 4.9** : écrire au § 1.10 qu'aucune exclusion `X` d'une valeur illisible ou hors domaine n'est admise en v1 (dict. :154-155).
5. **Âge** : au § 1.5 (dict. :109), renvoyer aux conventions fermées de la présente spécification, sans les recopier.

Les points P6 à P17 du commentaire d'errata de la PR #29 complètent cette liste. Ils ne sont pas décidés, sauf P12 (code dédié au refus né d'une règle P empêchée, décidé par le mainteneur le 8 novembre 2026), et ne sont pas intégrés à la présente version.
