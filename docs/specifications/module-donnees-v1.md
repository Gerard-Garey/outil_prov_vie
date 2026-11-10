# Spécification du module `donnees` — v1 (base entière et vue, enjeu des lignes écartées, conventions d'âge)

> *Rédigé par l'agent actuary (IA) le 8 novembre 2026 (issue #18, branche `claude/donnees-simulation`, PR #29), sur les questions 4.2 et 4.3 de l'avis d'`actuary-approfondi` sur la question 5d (portée d'un refus) et sur la question 4.5 (conventions d'âge, ADR 0010, cinquième série, (g)). Statut : version `1.4` **visée** par le mainteneur le 9 novembre 2026 (versions `1.3` et `1.1` visées auparavant, décisions de la `1.2` prises par lui, M194 et M195) ; version `1.1` visée le 8 novembre 2026 (errata E1 à E26) ; la version `1.0` l'a été le même jour (M151). Les décisions des visas sont intégrées par l'agent actuary (IA) (version `1.1` : le 9 novembre 2026), et la session principale contrôle leur transcription au versement.*
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
> - *`1.2` : 9 novembre 2026, issue #36, sur les décisions du mainteneur du même jour (M194 : `refus_induit` en dernier ; M195 : ordre complet des causes). § 3.1, priorité des causes : ordre en sept rangs, `refus_induit` en dernier, priorité de la cause directe (M185) conservée, places de `non_lisible`, `age_non_defini`, `parametre_non_defini` et `declaration_absente` fixées, `visibilite_non_determinee` exclue. Texte rédigé par l'agent actuary-approfondi (IA), versé par la session principale.*
> - *`1.3` : 9 novembre 2026, issue #33, sur le visa du mainteneur du même jour (M198 à M204) : M178 et M179 rouvertes, M169 précisée. § 2.2, colonne refusée et vue : portée ligne de tout refus de valeur identifié par ligne sur une colonne lue par la vue (visibilité non déterminée, aucun refus induit), portée table maintenue pour un défaut de forme ; § 2.5, critère 1 ; § 3.1, `origine` ; § 3.2, motif de refus et colonne `origine` de `vue$visibilite_non_determinee`, invariant de `provisoire` réécrit ; § 4.2, porteur non déterminé par un refus ; § 6, règle 3 ; § 7, point 6 (P18). Texte rédigé par l'agent actuary-approfondi (IA), forme de la colonne `origine` actée par l'agent architect (IA), versé par la session principale.*
> - *`1.4` : 9 novembre 2026, issue #33, compléments du visa d'`actuary` sur #33 et décision du mainteneur du 9 novembre 2026 sur l'enjeu à l'extraction (Q2). Ils portent sur la logique à trois valeurs de la règle P, la règle par colonne de la vue, la lecture existentielle de l'origine, les cas limites 1 à 3 et la liste fermée des colonnes de visibilité lues comme valeur par l'enjeu ; s'y ajoutent, au § 3.1, le cas X3 de #36 dans la phrase « Effet » et la liste fermée des causes directes. Aucune provision n'est modifiée. Texte rédigé par l'agent actuary-approfondi (IA), versé par la session principale ; **visée par le mainteneur le 9 novembre 2026** (la version précise M200 (b) : la règle P en logique de Kleene tranche une double lecture ; et la portée de M185). Précisions de forme après la revue finale (validation d'`actuary`, revue d'`audit`) : liste des défauts de forme alignée sur `.CODES_FORME`, domaine de la lecture existentielle, « colonnes de visibilité que lisent les composantes », renvois de lignes ; cas limite 3 étendu à toute table refusée en portée table, et portée de M185 précisée au § 3.1 (question Q1 de la revue finale) ; `nombre_dossiers` décrit tel que le code le calcule (§ 2.2 (c), § 4.4) ; cas limite 2 généralisé à toute colonne refusée d'une ligne à date de saisie connue absente.*
> - *`1.5` : 10 novembre 2026, issues #42, #43, #40 et #44 (branche `claude/donnees-trois-valeurs`), sur les décisions du mainteneur du même jour (M216 à M219). Une seule logique à trois valeurs (vrai, faux, inconnu ; Kleene) dans `controler_base()` : règle B par strates, recensement de ses règles qui lisent une colonne non clé refusable pour sa valeur et graphe de dépendance acyclique (#42, M217) ; visibilité à trois valeurs évaluée une seule fois pour la vue et pour les comptes, version valable de `famille` comprise, ligne de D02b ou de D03g invisible de façon déterminée (#43, M216 ; M167 et M171 rouvertes) ; règles V qui croisent des lignes, recensées, à trois valeurs, cause (γ) et sens élargi de `declaration_absente` (#40, M218) ; dossiers comptés sur les lignes visibles à l'arrêté, montants des composantes 1 à 4 compris (#44, M219). Aucune provision n'est modifiée ; les bilans des deux jeux versionnés ne changent pas (§ 2.6). Texte rédigé par l'agent actuary-approfondi (IA), versé par la session principale ; **visée par le mainteneur le 10 novembre 2026 (M222)**, avec confirmation des précisions P1 à P5 (date connue étendue à la date d'effet de l'hypothèse et à `date_fin` d'une partie de ligne ; ligne non déterminée hors de la population des règles V ; seul un refus rend une valeur inconnue ; auto-lecture brute en portée `colonne` ; version remplacée de `famille` invisible à l'extraction pour les comptes comme pour la vue).*
> - *`1.5.1` : 10 novembre 2026, erratum sur décision du mainteneur du même jour (question Q1 de #43) : une ligne de D03g sans déclaration dont la date d'effet (`sinistres.date_declaration`, `evenements.date_effet`) est refusée est inscrite sous D03g et sous le motif du refus (§ 2.2 (c), paragraphe « `sinistres.date_declaration` ») ; la conclusion contraire de la v1.5, antérieure à P1, est retirée.*
>
> *Les points du dictionnaire `1.6` relevés avec les errata (P6 à P17) ne sont pas intégrés (§ 7).*

**Références.**
- Les numéros de ligne sont ceux du dépôt à `da90d7e` pour les textes cités en version `1.0`. Les renvois au code ajoutés en version `1.1` (`R/donnees.R`) sont à `5c53ad4`. Les renvois au code ajoutés en version `1.5` (`R/donnees.R`) sont à `26c23c9`.
- Les décisions M167 à M178 (`docs/feuille-de-route.md`) sont étiquetées D1 à D12 dans la PR #29 ; ces étiquettes, ambiguës avec les codes de défaut, ne sont pas employées ici. L'ADR 0010, neuvième série, est cité par sa lettre.
- Le dictionnaire est cité dans sa version `1.5` (`docs/specifications/dictionnaire-base-v1.md`, abrégé « dict. »).
- L'ADR 0010 (`docs/adr/0010-forme-du-package-provie.md`) est abrégé « ADR 0010 ».
- Les codes `D..` sont ceux du § 9 du dictionnaire ; les codes de contrôle, ceux du § 1.10 (dict. :168-183), transcrits dans `controles.csv`.
- Mesures de la version `1.5` : R 4.3.3, package `provie` 0.1.0 installé depuis `26c23c9` (bibliothèque locale du scratchpad), base de référence de `tests/unitaires/donnees.R` (identique à l'octet au bloc `base_ref` du test, vérifié par `diff`). Les scripts de mesure (`recense.R`, `graphe.R`, `subst.R`, `m40*.R`, `m42*.R`, `m43*.R`, `m44*.R`, `jeux.R`, `jeu43.R`, `jeu44.R`) sont dans le scratchpad de la session ; ils ne sont pas versés au dépôt. Chaque sortie citée ci-dessous en vient.
- Statuts employés en version `1.5` : **résultat exact** (recensement, tri topologique, sorties mesurées), **jugement d'expert** (règles décidées par M216 à M219 et précisions de cette version), **constat de substitution** (effet attendu calculé par substitution des valeurs refusées sur le code à `26c23c9`, sans implémentation de la règle), **attendu** (effet dérivé à la main de la règle, non mesuré).
- Dans les critères de la version `1.5` (§ 2.5, § 4.6) : A0 = 2025-06-30, A = 2026-12-31 (extraction de la base de référence) ; jeux versionnés : arrêtés 2024-12-31 et 2025-12-31 (extraction).

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
  - **forme** (M170, M174, M177 ; ADR 0010, neuvième série, (e) ; `.lire_declarations()` et ses auxiliaires, `R/donnees.R:409-563`) :
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
  - **Règle B à trois valeurs, par strates** (v1.5 ; M217, décision du mainteneur du 10 novembre 2026 ; issue #42).
    - **B.1 Définitions**
      - Une **colonne clé** est une colonne de la clé primaire de sa table ou une colonne qui porte une référence (colonne `reference` de `colonnes.csv`, simple ou composite). Son refus est de portée table (dict. § 1.10 ; `.portee_effective()`, `R/donnees.R:772-779`).
      - Une colonne non clé est **refusable pour sa valeur** si une règle R de la règle B la contrôle avec une portée effective `colonne` (refus de valeur au sens du § 2.2, M199 : `manquant_obligatoire`, `hors_domaine`, `chaine_vide`, D02c sur une date, D09). Les colonnes de `evaluations_gestion` n'en sont jamais : toute anomalie de cette table la refuse en portée table (dict. § 7.5 ; `R/donnees.R:773`).
      - Une **règle concernée** est une règle R de la règle B dont le verdict lit une colonne non clé refusable pour sa valeur, autre que la colonne qu'elle contrôle.
      - **Auto-lecture.** Une règle de portée `colonne` lit la colonne qu'elle contrôle telle quelle : son refus et ceux des autres règles de la colonne portent sur la même cellule, et la ligne est refusée sur cette colonne dans tous les cas (seul le code peut différer). Une règle de portée `table` lit la colonne qu'elle contrôle comme toute colonne lue, dans le mécanisme ci-dessous : sans cela, le refus d'une cellule deviendrait le refus d'une table. Un seul cas au recensement : D10 (a) sur `prestations.type_prestation` (site 23).
    - **B.2 Recensement (résultat exact à `26c23c9`)**
      Méthode : instrumentation de `.regle()` pendant la règle B (avant `.refus_regle_b()`) sur la base de référence, toutes tables et toutes colonnes du dictionnaire présentes (`recense.R`). Sortie : **440** appels de `.regle()` en règle B ; **108** colonnes non clés refusables pour leur valeur ; **83** règles concernées, toutes de traitement R, sur **41** sites du code. Les colonnes lues sont celles de l'argument `lit` ; chaque fonction `f()` a été relue pour vérifier qu'elle ne lit pas d'autre colonne. Aucune règle de traitement X de la règle B (orphelines D04a, D04b `X`) ne lit de colonne non clé refusable.

      | Site | `R/donnees.R` | Code (règles) | Colonne contrôlée | Portée | Colonnes non clés refusables lues |
      |---|---|---|---|---|---|
      | 1 | :868-874 (appel :839) | D02c (1) | `evenements.date_effet` | colonne | `evenements.type_evenement`, `evenements.motif` |
      | 2 | :926 (`.regle_condition()`, :898-906) | `manquant_obligatoire`, `hors_domaine` (2) | `contrats.id_adherent` | table | `contrats.nature_contrat` |
      | 3 | :927 | idem (2) | `contrats.id_assure` | table | `contrats.nature_contrat` |
      | 4 | :928-933 | idem (2) | `contrats.date_terme` | colonne | `contrats.nature_contrat`, `garanties_souscrites.code_garantie` |
      | 5 | :935 | idem (2) | `contrats.motif_fin` | colonne | `contrats.date_fin` |
      | 6 | :936-937 | `hors_domaine` (1) | `contrats.date_saisie_fin` | colonne | `contrats.date_fin` |
      | 7 | :940-945 | `hors_domaine` (1) | `contrats.jour_echeance` | colonne | `contrats.mois_echeance` |
      | 8 | :947-961 (liste :949-956) | `manquant_obligatoire`, `hors_domaine` (24) | 12 colonnes de `garanties_souscrites` : `type_franchise`, `regle_complement`, `type_rente_conjoint`, `option_iad`, `periodicite_prestation`, `terme_prestation`, `conjoint_vise`, `versement_double_effet`, `non_remariage`, `prolongation_handicap`, `maintien_double_effet`, `clause_type_beneficiaire` | colonne | `garanties_souscrites.code_garantie` |
      | 9 | :965-969 | `hors_domaine` (1) | `garanties_souscrites.taux_technique_tarif` | colonne | `garanties_souscrites.code_garantie` |
      | 10 | :970-975 | `hors_domaine` (1) | `garanties_souscrites.college` | colonne | `contrats.nature_contrat` |
      | 11 | :990-993 | `hors_domaine` (1) | `parametres.parametre` | table | `garanties_souscrites.code_garantie` |
      | 12 | :994-997 | `manquant_obligatoire`, `hors_domaine` (2) | `parametres.categorie_invalidite` | table | `garanties_souscrites.code_garantie` |
      | 13 | :1014-1017 | idem (2) | `assures.date_situation_familiale` | colonne | `assures.situation_familiale`, `assures.nombre_enfants_charge` |
      | 14 | :1020-1024 | `hors_domaine` (1) | `affiliations.id_contrat` | table | `contrats.nature_contrat` |
      | 15 | :1026 | `manquant_obligatoire`, `hors_domaine` (2) | `affiliations.motif_fin` | colonne | `affiliations.date_fin` |
      | 16 | :1027-1028 | `hors_domaine` (1) | `affiliations.date_saisie_fin` | colonne | `affiliations.date_fin` |
      | 17 | :1030-1031 | `manquant_obligatoire`, `hors_domaine` (2) | `affiliations.date_designation` | colonne | `affiliations.designation` |
      | 18 | :1037-1038 | `hors_domaine` (1) | `famille.date_naissance` | colonne | `famille.situation` |
      | 19 | :1039-1040 | `hors_domaine` (1) | `famille.situation` | colonne | `famille.lien` |
      | 20 | :1054-1062 | D10a (1) | `dossiers.id_garantie_souscrite` | table | `garanties_souscrites.code_garantie`, `sinistres.nature_sinistre` |
      | 21 | :1063-1066 | D10a (1) | `rentes.id_dossier` | table | `garanties_souscrites.code_garantie` |
      | 22 | :1067-1070 | `manquant_obligatoire`, `hors_domaine` (2) | `rentes.id_membre` | table | `garanties_souscrites.code_garantie` |
      | 23 | :1072-1078 | D10a (1) | `prestations.type_prestation` | table | `garanties_souscrites.code_garantie` ; auto-lecture de `prestations.type_prestation` |
      | 24 | :1079-1080 | `manquant_obligatoire`, `hors_domaine` (2) | `prestations.id_rente` | table | `prestations.type_prestation` |
      | 25 | :1086-1089 | `hors_domaine` (2) | `prestations.debut_periode`, `prestations.fin_periode` | colonne | `prestations.type_prestation` |
      | 26 | :1090-1091 (`.regle_signe()`, :1204-1217) | D09, `hors_domaine` (2) | `prestations.montant` | colonne | `prestations.nature_mouvement` |
      | 27 | :1092-1094 | D09, `hors_domaine` (2) | `cotisations.montant` | colonne | `cotisations.nature_mouvement` |
      | 28 | :1098-1099 | `manquant_obligatoire`, `hors_domaine` (2) | `beneficiaires.id_membre` | table | `beneficiaires.qualite` |
      | 29 | :1109-1111 | idem (2) | `evenements.id_dossier` | table | `evenements.type_evenement` |
      | 30 | :1112-1118 | idem (2) | `evenements.id_rente` | table | `evenements.type_evenement`, `garanties_souscrites.code_garantie` |
      | 31 | :1131-1142 | `hors_domaine` (1) | `evenements.type_evenement` | colonne | `garanties_souscrites.code_garantie`, `sinistres.nature_sinistre` |
      | 32 | :1147-1148 | `hors_domaine` (1) | `evenements.categorie_invalidite` | colonne | `evenements.type_evenement` |
      | 33 | :1149 | `manquant_obligatoire`, `hors_domaine` (2) | `evenements.montant` | colonne | `evenements.type_evenement` |
      | 34 | :1152-1153 | idem (2) | `evenements.source_information` | colonne | `evenements.type_evenement` |
      | 35 | :1157-1159 | `hors_domaine` (1) | `evenements.motif` | colonne | `evenements.type_evenement` |
      | 36 | :1160-1166 | `manquant_obligatoire` (1) | `evenements.motif` | colonne | `evenements.type_evenement` |
      | 37 | :1169-1170 | `manquant_obligatoire`, `hors_domaine` (2) | `victimes.date_deces` | colonne | `victimes.statut_victime` |
      | 38 | :1188-1192 | `hors_domaine` (1) | `designations.id_affiliation` | table | `affiliations.designation` |
      | 39 | :1273-1283 (`.orphelines()`, :1260-1287) | D04b (1) | `affiliations.college` (référence composite) | table | `garanties_souscrites.college` |
      | 40 | :1233-1240 | `chevauchement` (1) | `garanties_souscrites`, colonne `NA` | table | `garanties_souscrites.code_garantie`, `.college`, `.date_effet`, `.date_fin` |
      | 41 | :1241-1249 | `chevauchement` (1) | `parametres`, colonne `NA` | table | `parametres.age_max` |

      Total : 58 règles de portée `colonne`, 25 de portée `table`, 83 règles.

      **Règles de la règle B hors du recensement, avec leur motif** (même mesure) :
      - `affiliations.structure_cotisation_sante` (:1032-1033) et `ayants_droit_sante.id_affiliation` (:1193-1197) lisent `affiliations.sante_organisme`, que n'atteint aucune règle R : non refusable ;
      - `parametres.age_max` (:1001-1004) et `parametres.valeur` (:1006-1010) lisent `parametres.age_min` et `parametres.parametre`, colonnes de la clé primaire composite de `parametres` ;
      - `famille.id_sinistre` (:1041-1045), `prestations.id_rente` (:1081-1085), `evenements.id_dossier` et `evenements.id_rente` (:1119-1128), D10 (h) (:1171-1175), D01a (:1228-1230) et les autres orphelines ne lisent que des colonnes clés ;
      - `evaluations_gestion.date_saisie` (:1179-1180) lit `evaluations_gestion.date_effet`, jamais refusée pour sa valeur (B.1 ci-dessus) ;
      - toutes les autres règles (génériques de `.regle_domaine()`, `.hors_bornes()`) ne lisent que la colonne qu'elles contrôlent.
    - **B.3 Graphe de dépendance, strates, acyclicité**
      - **Graphe.** Nœuds : colonnes non clés refusables pour leur valeur. Arête X → Y : une règle concernée de portée `colonne` contrôle Y et lit X (X ≠ Y). Une règle de portée `table` ne crée aucune arête : son refus n'est pas un refus de valeur, il est hors du mécanisme (M217, « clés hors mécanisme ») ; elle est un puits.
      - **Mesure** (`graphe.R`, résultat exact) : 39 arêtes, 49 nœuds ; le tri topologique de Kahn consomme toutes les arêtes (aucune arête restante) : **le graphe est acyclique**. Quatre colonnes ne sont lues que par des règles de portée `table` : `beneficiaires.qualite`, `garanties_souscrites.date_effet`, `garanties_souscrites.date_fin`, `parametres.age_max` ; elles sont en strate 0.
      - **Strates** (strate d'une colonne = longueur du plus long chemin qui y mène) :
        - **0** : toute colonne refusable sans arête entrante, dont les entrées du recensement `affiliations.date_fin`, `affiliations.designation`, `assures.nombre_enfants_charge`, `assures.situation_familiale`, `contrats.date_fin`, `contrats.mois_echeance`, `contrats.nature_contrat`, `cotisations.nature_mouvement`, `famille.lien`, `garanties_souscrites.code_garantie`, `prestations.nature_mouvement`, `prestations.type_prestation`, `sinistres.nature_sinistre`, `victimes.statut_victime`, et les quatre colonnes ci-dessus ;
        - **1** : `affiliations.date_designation`, `affiliations.date_saisie_fin`, `affiliations.motif_fin`, `assures.date_situation_familiale`, `contrats.date_saisie_fin`, `contrats.date_terme`, `contrats.jour_echeance`, `contrats.motif_fin`, `cotisations.montant`, `evenements.type_evenement`, `famille.situation`, les 12 colonnes du site 8, `garanties_souscrites.college`, `garanties_souscrites.taux_technique_tarif`, `prestations.debut_periode`, `prestations.fin_periode`, `prestations.montant`, `victimes.date_deces` ;
        - **2** : `evenements.categorie_invalidite`, `evenements.montant`, `evenements.motif`, `evenements.source_information`, `famille.date_naissance` ;
        - **3** : `evenements.date_effet` ;
        - **puits** : les 25 règles de portée `table`, évaluées après la strate 3 (la plus haute strate qu'elles lisent est 2).
      - **Démonstration lisible.** Chaque arête va d'une strate k à une strate strictement supérieure (liste ci-dessus) ; un cycle exigerait une arête descendante. Les seules arêtes entre tables sont `contrats.nature_contrat` → `garanties_souscrites.college`, `garanties_souscrites.code_garantie` → `contrats.date_terme`, et `garanties_souscrites.code_garantie`, `sinistres.nature_sinistre` → `evenements.type_evenement` ; aucune de leurs extrémités n'a d'arête sortante vers la table d'origine. Plus long chemin : `sinistres.nature_sinistre` (ou `garanties_souscrites.code_garantie`) → `evenements.type_evenement` → `evenements.motif` → `evenements.date_effet`.
      - **Constante interne.** Le graphe (ou les strates qui s'en déduisent) est une constante interne de `donnees` (M217). Deux tests : (i) **acyclicité** de la constante (tri topologique complet) ; (ii) **couverture** : pour chaque appel de `.regle()` en règle B, toute colonne non clé refusable de `lit`, autre que la colonne contrôlée, figure dans la constante comme entrée de la règle (recoupement mécanique de la constante avec le code, sur le modèle de `recense.R`). Un cycle trouvé arrête l'issue et revient au mainteneur (fiche de Bdk).
    - **B.4 Verdict à trois valeurs**
      - **Valeur inconnue.** Sur une ligne, une colonne lue est inconnue si sa valeur y est refusée pour sa valeur (verdict vrai d'une règle R de portée `colonne`) ; sa présence est alors inconnue aussi (v1.4, (b)). Une valeur manquante non refusée est connue absente. Pour une colonne d'une autre table, lue par jointure sur une clé, la valeur jointe est inconnue si la ligne jointe porte un refus de valeur sur cette colonne.
      - **Seul un refus rend une valeur inconnue (K1).** Une ligne que sa propre règle a écartée (verdict inconnu) n'est pas refusée : sa valeur est lue telle quelle par les strates suivantes et par les règles P et V.
      - **Lecture existentielle** (même lecture que la v1.4, (c), D2) : le verdict d'une règle sur une ligne est inconnu si deux affectations des valeurs inconnues qu'elle lit, chacune prise dans le domaine de sa colonne (dictionnaire : modalités, liste de `types_evenements` pour le type, bornes des dates et absence pour une colonne non obligatoire), sans égard aux autres colonnes de la ligne, lui donnent deux verdicts différents ; sinon, il vaut le verdict commun. Une valeur refusée parce qu'elle est incompatible avec une autre colonne (type d'événement incompatible avec la garantie, site 31) prend tout son domaine : la déduire de sa compatibilité reviendrait à l'imputer (D2).
      - **Formes** (conséquences de la lecture existentielle, pour guider l'implémentation ; la définition fait foi) :

      | Forme | Sites | Verdict à trois valeurs |
      |---|---|---|
      | Colonne conditionnelle (`.regle_condition()`) : exigence de Y = requise, interdite ou libre selon X | 2-6, 8, 12, 13, 15-17, 22, 24, 25, 28-30, 32-34, 37 | Exigence inconnue si deux valeurs du domaine de X donnent deux exigences différentes. `manquant_obligatoire` = requise ET Y absente : faux si Y est présente. `hors_domaine` = interdite ET Y présente : faux si Y est absente. « Libre » (aujourd'hui `NA` pour une entrée connue, par exemple un niveau `sinistre;dossier`) n'est pas « inconnu » : les deux verdicts y sont faux, inchangé |
      | Borne qui dépend d'une autre colonne | 1, 7, 9, 26, 27 | Exemple, site 1 : (date < 1901-01-01) OU (non programmable ET date > extraction). Vrai si la date est avant 1901 ; faux si elle est au plus l'extraction ; sinon, inconnu si le type, ou le motif quand le type est programmable selon le motif (`oui:<motifs>`), est inconnu |
      | Jointure ou appartenance | 4, 10, 11, 14, 20, 21, 23, 31, 38, 39 | « Il existe une ligne jointe telle que… » (site 4 : garantie décès du contrat ; site 39 : version de même (`id_contrat`, `college`)) : vrai si une ligne jointe connue satisfait ; faux si toutes les lignes jointes sont connues et ne satisfont pas ; inconnu sinon |
      | Chevauchement | 40, 41 | Vrai si la ligne recouvre une autre ligne de même groupe dont le groupe et l'intervalle sont connus ; faux si, pour toute autre ligne, le groupe ou l'intervalle sont connus disjoints quelle que soit la valeur des inconnues ; inconnu sinon. Une borne refusée vaut toute date du domaine, ou l'absence (intervalle ouvert) pour une colonne non obligatoire |
    - **B.5 Exécution, ligne partielle, cause**
      - **Ordre.** Strates 0, 1, 2, 3, puis les règles de portée `table`. Dans une strate, l'ordre des règles est celui du code. Les refus de valeur d'une colonne sont complets à la fin de sa strate. Un seul passage, sans point fixe : le graphe est acyclique (M217).
      - **Exécution.** Une ligne au verdict vrai est détectée, une ligne au verdict faux ne l'est pas, et une ligne au verdict inconnu est écartée de la détection. La détection reste qualifiée d'`exacte` sur les lignes au verdict déterminé.
      - **Ligne de `controles_non_executes`** (détection partielle, nombre minorant ; ADR 0010, huitième série, (e)). Une ligne par clé (`code`, `table`, `colonne`) de règle qui écarte au moins une ligne. Cause : le motif du premier refus de valeur qui touche une ligne écartée, dans l'ordre des colonnes lues (`lit`), puis des constats : refus sur la ligne écartée elle-même, ou, pour une colonne d'une autre table, sur la ligne jointe à une ligne écartée. Une ligne écartée sans refus qui l'explique est une erreur interne (arrêt « erreur interne de provie », comme pour la règle P, `R/donnees.R:748-749`). Rang de la cause : 3, cause directe (§ 3.1).
      - **Ce qui ne change pas.**
        - Clés : un refus de colonne clé reste de portée table ; il n'entre pas dans le mécanisme (M217).
        - Forme : une colonne lue illisible par sa forme bloque la règle entière, cause = défaut de forme, inchangé (`.regle()`, :687-711). Mesure, base de référence avec `famille.situation` de type logique, à A : `controles_non_executes` porte déjà des règles de la règle B bloquées, dont (`hors_domaine`, `famille`, `date_naissance`) et (`chaine_vide`, `famille`, `situation`), cause `type_incompatible` (`m42b.R`, cas de forme).
        - Refus de portée table en règle B : la règle B lit une table refusée en portée table comme aujourd'hui ; seuls les refus de valeur rendent une valeur inconnue. Le cas limite 3 (§ 2.2) régit les règles P et V et la vue, pas la règle B.
        - Les règles P, V, la vue et l'enjeu lisent les refus de valeur produits par la règle B (`.lignes_refusees()`, `.refus_valeur_de()`), sans autre changement que le contenu de ces refus.
      - **Motif** (jugement d'expert, M217). Une valeur refusée n'est pas lue (dict. § 1.10). La v1.4 l'applique aux règles P (M213) ; la règle B lisait encore la valeur brute : un type refusé y passait pour non programmable, et un refus de cellule devenait un refus de table, propagé par les refus induits (cas mesurés ci-dessous). K1 suit la lettre de M217 (« cause = motif du refus lu ») et garde une seule notion de valeur inconnue pour les règles B, P et V et pour la vue.
      - **Alternatives écartées.**
        - Un seul passage sur les refus « primaires » (hors domaine, manquant ; point 3 de l'issue #42) : un refus né d'une règle relationnelle (type incompatible avec la garantie, site 31) resterait lu comme valeur connue, contre le critère de l'issue.
        - Un point fixe sur les refus : inutile, puisque le graphe est acyclique ; l'opérateur est antitone (un refus de plus rend des valeurs inconnues, donc retire des refus), et l'itération pourrait osciller (M217).
        - **K2** : tenir pour inconnue la valeur d'une ligne écartée. Elle ne diffère de K1 que sur trois chaînes : `famille.lien` → `famille.situation` → `famille.date_naissance` ; `contrats.nature_contrat` → `garanties_souscrites.college` → (D04b sur `affiliations.college`, chevauchement de `garanties_souscrites`) ; `garanties_souscrites.code_garantie` ou `sinistres.nature_sinistre` → `evenements.type_evenement` → sites 29, 30, 32 à 36 et 1. Elle écarte plus de lignes. Elle crée aussi une valeur « de validité inconnue », sans motif de refus, que les règles P et V et la vue ne connaissent pas.
        - Auto-lecture dans le mécanisme pour toute règle : la cellule refusée par sa règle de domaine écarterait la règle relationnelle de même colonne. Une clé serait alors à la fois détectée et partielle pour une ligne refusée dans tous les cas.
      - **Effet** : aucune provision. Sur les bases des tests, des refus disparaissent (D02c induit, refus de portée table et leurs refus induits), et des lignes partielles de la règle B apparaissent dans `controles_non_executes` (§ 2.5 ci-dessous, critères B1 à B7). Les jeux versionnés ne changent pas (§ 2.6).
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
- **Colonne refusée et vue** (M169, M178 ; M199 à M204, décisions du mainteneur du 9 novembre 2026, issue #33 ; ADR 0010, neuvième série, (f), et quatorzième série) :
  - **Frontière.** Une *colonne lue par la vue* est une colonne de visibilité d'une ligne ou d'une partie de ligne (dict. § 6) ou une colonne lue par une règle P (D02b, D03g), dans la table ou dans sa parente ; les colonnes de clé en sont exclues (leur refus reste de portée table, dict. § 1.10).
    - L'exclusion des colonnes de clé vaut aussi pour une date qui entre dans une clé primaire composite (v1.4, Q11, C4). `famille.date_saisie`, qui entre dans la clé (`id_membre`, `date_saisie`), garde un refus de portée table (dict. § 1.10) et reste hors du mécanisme du refus de valeur : aucune ligne de `famille` n'est de visibilité non déterminée par un refus de sa date de saisie.
    - Un **refus de valeur identifié par ligne** (`manquant_obligatoire`, `hors_domaine`, `chaine_vide`, D02c date hors bornes, tout refus `R` de portée colonne dont le constat désigne des lignes) sur une colonne lue par la vue est de **portée ligne** pour la vue (M199).
    - Un **défaut de forme** (`colonne_absente`, `colonne_inconnue`, `type_incompatible` : `.CODES_FORME`) garde la **portée table** : à A < extraction, la règle P empêchée produit un refus induit de portée table, propagé aux filles par les clés étrangères (code `refus_induit`, origine « table.colonne ») (M178, inchangé).
  - **Mécanisme du refus de valeur.**
    - (a) `refus_tables` : la ligne du refus `R` de portée colonne est inchangée (règle B). Aucun refus induit ne naît d'un refus de valeur : les refus de valeur sont invariants en A.
    - (b) **Règle P, logique à trois valeurs** (M200, précisé en v1.4 ; D1, Q1).
      - **Valeurs inconnues.** Une valeur refusée pour sa valeur est inconnue, y compris sa présence : une valeur refusée comme manquante est inconnue au même titre qu'une valeur hors domaine. Une valeur manquante non refusée est connue absente.
      - **Verdict.** Le verdict d'une règle P sur une ligne vaut vrai, faux ou inconnu, selon la logique de Kleene : une conjonction est fausse dès qu'un terme est faux, vraie si tous les termes sont vrais, inconnue sinon.
        - D02b sur `evenements` : (type non programmable) ET (`date_saisie` < `date_effet`). « Type non programmable » est inconnu si le type est inconnu, ou si le type est programmable selon le motif (`oui:<motifs>`) et que le motif est inconnu.
        - Comparaison de deux dates x < y (D02b sur `evenements`, `sinistres`, `catastrophes`, fin de contrat, fille et parente) : fausse si l'une des dates est connue absente ; inconnue si l'une est inconnue et l'autre présente ou inconnue ; sinon, égale au résultat de la comparaison. La date d'une parente est inconnue si la ligne parente de même clé a une date inconnue.
        - D03g : date de saisie manquante, inconnue si la date de saisie est inconnue. Pour une partie de ligne : (`date_saisie_fin` manquante) ET (`date_fin` présente).
      - **Exécution.** À tout arrêté, une ligne au verdict vrai est détectée, une ligne au verdict faux ne l'est pas, et une ligne au verdict inconnu est écartée de la détection.
      - **Ligne de `controles_non_executes`** (détection partielle, nombre minorant ; ADR 0010, huitième série, (e)). Elle n'existe que si au moins une ligne de la table est écartée (Q1). Sa cause est le motif du premier refus de valeur qui touche une ligne écartée, dans l'ordre des colonnes lues : d'abord une colonne de la table, à défaut une colonne d'une autre table (date de la parente).
      - **Motif** (jugement d'expert). Une valeur refusée n'est pas lue (dict. § 1.10). Une ligne dont le verdict ne dépend pas de la valeur refusée a un verdict déterminé. L'écarter déclarerait partielle une détection exacte ; pour un verdict vrai, la ligne visée resterait même visible sans déclaration, ce que le § 3.2 écarte (principe de M187). La logique de Kleene ne dépend pas de l'ordre d'évaluation des termes.
      - **Alternative écartée** : écarter toute ligne dont une colonne lue porte une valeur refusée (lecture par colonne de la v1.3). Elle laisse visible à A, sans déclaration, un événement de type non programmable saisi avant une date d'effet postérieure à A dès que son motif, qui ne joue pas pour ce type, est refusé (cas « m6 » de #33).
      - **Effet** : aucune provision. Sur les bases des tests, des lignes partielles de D02b ou de D03g disparaissent (verdict faux déterminé), et un événement devient détecté par D02b.
    - (c) **Vue à A < extraction : visibilité à trois valeurs, évaluée une seule fois** (v1.4 ; Q5, D2, D4, Q7, Q8 ; v1.5 ; M216 ; M167 et M171 rouvertes).
      - **Statut d'une ligne à A.** Chaque ligne, et chaque partie de ligne (`.PARTIES_LIGNE`, `R/donnees.R:1453-1456`), a un statut à A : **visible**, **invisible** ou **non déterminé**. Une ligne est **invisible de façon déterminée** si elle n'est visible à A sous aucun des traitements que le dictionnaire admet pour les défauts qui la touchent (§ 9 : D02b `H` ; D03g `H` avec tout délai entier positif ou nul, ou `X` ; partie de ligne de D03g `H` seul, M175), et quelle que soit la valeur d'une valeur refusée (lecture existentielle, D2). Elle est **visible** si elle l'est sous le traitement déclaré et pour toute valeur des inconnues. Elle est **non déterminée** sinon. C'est le principe de M187, étendu par M216 à D02b, à D03g et à la parente invisible.
      - **Règle de calcul** (conjonction de Kleene) :
        1. *Dates propres* (`.DATES_VISIBILITE`, :1443-1449) : une date connue au plus A rend la condition vraie ; une date connue après A, ou connue absente, la rend fausse ; une date refusée pour sa valeur la rend inconnue.
        2. *D02b (verdict vrai)* : sous l'hypothèse déclarée pour les deux référentiels, la condition « date comparée ≤ A » s'ajoute : `evenements.date_effet`, `sinistres.date_declaration`, `catastrophes.date_evenement` ; aucune pour une fille, qui suit sa parente. Sans hypothèse, la ligne est invisible de façon déterminée si sa date de saisie, ou la date comparée, est connue après A, ou si sa parente est invisible ; elle est non déterminée sinon.
        3. *D03g, ligne entière (date de saisie manquante)* : sous l'exclusion déclarée, la ligne sort de la vue. Sous l'hypothèse déclarée, sa date retenue est max(date d'effet + délai, visibilité de la parente) (M171). Sans déclaration complète, ou si cette date ne se calcule pas, la ligne est invisible de façon déterminée si l'une de ces conditions tient, et non déterminée sinon :
           - une autre date propre est connue après A (`prestations.date_reglement`, seule seconde date de visibilité des tables de D03g) ;
           - la date d'effet de l'hypothèse est connue après A (`evenements.date_effet`, `sinistres.date_declaration`) : le délai est positif ou nul ;
           - la parente est invisible.
        4. *Partie de ligne* :
           - toute partie d'une ligne invisible est invisible ;
           - partie de D03g (`date_saisie_fin` manquante, `date_fin` présente) : sous l'hypothèse, connue à `date_fin` + délai (M175, inchangé) ; sans hypothèse, masquée de façon déterminée si `date_fin` est connue après A, non déterminée sinon ;
           - partie de D02b (fin de contrat saisie avant l'effet) : sous l'hypothèse, visible avec son contrat (règle 1) ; sans hypothèse, masquée de façon déterminée si `date_saisie_fin` est connue après A, non déterminée sinon ;
           - partie refusée pour sa valeur : tableau de la règle par colonne de la v1.4, inchangé.
        5. *Règle 1* : statut d'une fille = statut propre ET statut de sa parente ; une orpheline garde sa condition propre (inchangé). La parente d'une clé de `famille` (clé non unique, versions) a pour statut « le membre est visible » : visible si une version est visible, non déterminé si aucune ne l'est et qu'une version est non déterminée, invisible sinon.
        6. *Version valable de `famille`* (déplacée de #40 vers #43, M216) :
           - la version valable d'un membre est sa dernière saisie visible ;
           - elle est **déterminée** si aucune version de visibilité non déterminée n'a une date de saisie plus récente, ou inconnue ;
           - sinon, elle est **non déterminée**, et ses **candidates** sont la dernière version visible et chaque version non déterminée plus récente ou de saisie inconnue ;
           - une version visible plus ancienne que la version valable déterminée est invisible au sens des comptes (non valable).
        7. *`adherents`, `assures`* : visibles s'ils sont référencés par une ligne visible, non déterminés s'ils ne le sont que par des lignes non déterminées, invisibles sinon.
      - **Une seule évaluation.** Une seule fonction établit ce statut, par ligne. `.construire_vue()` et `.connus()` l'appellent, au lieu des deux calculs actuels (`R/donnees.R:1926-2020` et `:2736-2854`), qui divergent : Kleene dans les comptes, non dans la vue (`:2790-2797` contre `:1966-1976`). Trois écarts déclarés, et seulement ceux-là :
        - (i) une table refusée en portée table n'a aucune ligne dans la vue (aucune règle V ne la lit), mais les comptes lisent l'évaluation (§ 2.3, 2 : un refus R n'empêche pas de compter) ;
        - (ii) une ligne que l'exclusion déclarée de D03g sort de la vue a, pour les comptes, la visibilité de l'hypothèse avec un délai nul (§ 4.4, inchangé) ;
        - (iii) la variante `d03g` de l'enjeu des écarts de D03g (§ 4.4, inchangée), qui est un paramètre de la même fonction.
      - **Vue.** La vue retient les lignes visibles, et, pour `famille`, les versions valables déterminées. Un membre à version valable non déterminée est présent dans la vue (le membre est visible), mais sans version désignée : une règle V qui lit ses colonnes les lit sur chaque candidate (§ 2.2 (d)).
      - **À A = extraction** : tout est visible (règle 3), hors des versions de `famille` remplacées, invisibles au sens des comptes comme dans la vue. Ce point aligne les comptes sur la vue et sur le § 4.4 (« versions valables de `famille` »). Mesure, base de référence avec deux versions de ME1 (2025-02-01, 2025-03-01) et un `sexe` hors domaine sur la plus ancienne : à A, la vue ne retient pas l'ancienne version, mais `.connus()` la compte visible, et `nombre_visibles` = 1 ; à A0, `nombre_visibles` = 0 (`m43f.R`). Après : 0 aux deux arrêtés (point P5 au mainteneur).
      - **Inscription.** Une ligne de visibilité inconnue est de visibilité non déterminée. Elle est inscrite dans `vue$visibilite_non_determinee` avec `motif` = code du refus, `colonne` = `NA` (ligne entière) ou la colonne de la partie (M167), et `origine` = « table.colonne » (M202).
      - **Inscription dans `vue$visibilite_non_determinee`.**
        - Une ligne entière non déterminée est inscrite sous son motif : D02b, D03g, code du refus avec son origine, ou `parente_non_determinee` pour une ligne visible par elle-même dont seule la parente est non déterminée.
        - Une partie non déterminée d'une ligne visible est inscrite sous sa colonne.
        - Une ligne, ou une partie, invisible de façon déterminée n'est **jamais** inscrite, et ne rend pas la vue provisoire.
        - Une version de `famille` visible mais candidate n'est pas inscrite : sa visibilité est déterminée ; la version non déterminée qui en fait une candidate l'est.
      - **Déclarations** (lecture (b1) de M216) : une ligne de D02b ou de D03g invisible de façon déterminée garde sa ligne de `controles` (détection sur la base entière, règle P) et ses exigences dans `declarations_requises` (mêmes lignes, même `nombre_lignes`, y compris l'exclusion attendue d'une ligne dont la date ne se calcule pas, réserve Q5). M216 ne change que la vue, `provisoire`, les comptes et l'enjeu.
      - **Origine, lecture existentielle** (D2). La ligne est inscrite sous chaque colonne refusée dont la valeur peut changer son statut à A, les autres valeurs inconnues de la ligne prenant toute valeur du domaine de leur colonne (dictionnaire), sans égard aux autres colonnes de la ligne : déduire une valeur refusée de sa compatibilité avec le reste de la ligne reviendrait à l'imputer (avis d'`actuary` sur la question A de l'audit de #33). L'origine est toujours une colonne de la table de la ligne (Q8).
      - **Règle par colonne**, conséquence de ce qui précède (Q5, D4) :

        | Colonne refusée | Ligne (ou partie) de visibilité non déterminée |
        |---|---|
        | Colonne de visibilité de la ligne (dict. § 6), `date_saisie_fin`, `sinistres.date_instruction` | Toute ligne (ou partie) refusée |
        | `evenements.type_evenement`, `evenements.date_effet` | Ligne dont le verdict de D02b est inconnu ; sous l'hypothèse de D02b déclarée (visibilité = max(saisie, effet, parente)), seulement si en plus l'effet est postérieur à A ou inconnu |
        | `evenements.motif` | Comme la ligne précédente, et seulement si le type est inconnu ou programmable selon le motif (`oui:<motifs>`) |
        | `contrats.date_fin`, `affiliations.date_fin` | Partie dont la `date_saisie_fin` manque ou est inconnue ; sinon, la fin est connue (ou inconnue) à sa date de saisie |
        | `sinistres.date_declaration`, `catastrophes.date_evenement` | Toute ligne refusée |

        - **`sinistres.date_declaration`.** Son seul verdict de D02b déterminé est celui d'une ligne dont la date de saisie est connue absente, et cette ligne relève de D03g : sans déclaration, elle est non déterminée sous D03g et, puisque sa date d'effet peut la rendre invisible (P1), aussi sous le motif du refus (lecture existentielle, cas limite (1), critère 6 (b)) ; sous `H` de D03g, non déterminée sous le motif du refus (cas limite 2) ; hors de la vue sous `X`. `evenements.date_effet`, qui est aussi la date d'effet de D03g, suit la même règle. *(v1.5.1 : la conclusion de la v1.5, « les deux écritures donnent le même bilan », antérieure à P1, est retirée.)*
        - **`catastrophes.date_evenement`.** La date de saisie de `catastrophes` n'a pas de D03g : son absence est un refus, et le verdict de D02b est inconnu sur toute ligne refusée.
      - **Filles** (M167 rouverte). Les filles écartées par la règle 1 d'une parente **non déterminée** figurent sous `parente_non_determinee`, origine `NA`, sans exigence propre. Une fille d'une parente invisible de façon déterminée est elle-même invisible de façon déterminée et n'est pas inscrite.
      - **Partie de ligne.** Seule la partie est masquée ; la ligne reste dans la vue.
      - **Comptes** (Q7). Une valeur refusée n'étant pas lue, `nombre_visibles` d'un refus vaut `NA` dès qu'une ligne qui le porte est de visibilité non déterminée, quel qu'en soit le motif. En v1.5 (M216, M219), `nombre_visibles` lit la même évaluation. `nombre_dossiers` suit le § 4.4 (M219).
      - **Motif** (jugement d'expert, M216). Voici l'instruction d'`actuary-approfondi`, que M216 retient. La conjonction des conditions de visibilité est connue fausse, et aucun traitement admis ne rend la ligne visible : la déclarer non déterminée rendrait provisoire une vue dont le statut est connu, et laisserait la vue contredire les comptes, qui appliquent déjà Kleene. La date d'effet de l'hypothèse (points 2 et 3) en relève au même titre que la seconde date propre : sous tout délai positif ou nul, la date retenue la dépasse.
      - **Alternative écartée** : M167 et M171 dans leur lettre (toute ligne de D02b ou de D03g non résolue est non déterminée). C'est le comportement à `26c23c9` (cas V1, V3 à V6, V8 et V10 du § 2.5).
      - **Effet** : aucune provision. Des lignes sortent de `vue$visibilite_non_determinee` et `provisoire` peut passer à `FALSE` sur les bases des tests ; `controles` et `declarations_requises` sont inchangés ; les jeux versionnés ne changent pas (§ 2.6).
    - (d) **Règles V.**
      - **Inchangé** : la lecture d'une colonne par la vue ne bloque pas une règle V pour un refus de valeur, les lignes non déterminées étant hors de la vue ; une règle V qui lit la colonne refusée comme valeur reste bloquée, cause = motif (M169, M200).
      - **Population** (jugement d'expert, principe du § 3.2 visé par M151). La population d'une règle V est la vue : lignes visibles, et membres visibles de `famille`. Une ligne, ou un membre, de visibilité non déterminée est hors de la population : elle n'est ni détectée, ni la source d'une ligne de `controles_non_executes` pour son propre verdict. Elle est recensée une fois dans `vue$visibilite_non_determinee`, et la vue est provisoire.
      - **Verdict à trois valeurs** (M218, lecture (ii)). Le verdict d'une règle V sur une ligne de la population est inconnu si deux états des éléments non déterminés qu'il lit lui donnent deux verdicts différents. Ces états sont : chaque ligne non déterminée dans la vue ou hors de la vue ; chaque partie non déterminée connue ou non à A ; chaque candidate d'un membre de `famille` valable ou non. Les valeurs connues restent fixées (lecture existentielle, D2). Une ligne au verdict inconnu est écartée de la détection (compte minorant). La règle garde alors une ligne dans `controles_non_executes`, de cause (γ) (§ 3.1).
      - **Recensement** (résultat exact à `26c23c9` : 53 appels de `.regle_vue()`, 39 clés (`code`, `table`, `colonne`), `recv.R` ; colonnes lues relues dans le code). **18 clés exposées**, dont le verdict lit une autre ligne de la vue, une partie de ligne ou une version de `famille` :

        | Clé | `R/donnees.R` | Ce que le verdict lit hors de la ligne | Forme du verdict à trois valeurs |
        |---|---|---|---|
        | `somme_parts` / `beneficiaires` / `part` | :2193-2202 | parts des autres bénéficiaires du dossier | Inconnu si une sous-somme des parts des bénéficiaires non déterminés du dossier, ajoutée à celle des visibles, tombe à moins de la tolérance de 1 alors qu'une autre n'y tombe pas ; les parts étant positives, vrai déterminé si la somme des visibles dépasse 1 + tolérance |
        | D03a / `famille` / `date_naissance` (S, `X;H`) | :2223-2224 | version valable du membre | Verdict sur chaque candidate ; inconnu si elles diffèrent |
        | D03b / `famille` / `sexe` | :2227-2229 | idem | idem |
        | D02a / `famille` / `date_naissance` | :2306-2312 | idem (et sinistre parent, déterminé par la règle 1) | idem |
        | D02c / `famille` / `date_naissance` (S, X) | :2510-2519, :2551 | idem | idem |
        | D02a / `contrats` / `date_fin` | :2277-2278 | partie de ligne `date_fin` | Partie connue : comparaison ; partie non connue à A (déterminé) : faux ; partie non déterminée : inconnu si `date_effet` > `date_fin` (valeurs brutes), faux sinon |
        | D02a / `affiliations` / `date_fin` | :2285-2286 | partie de ligne `date_fin` | idem avec `date_debut` |
        | D01b (cinq tables, S et X) | :2345-2367 | autres lignes de même contenu (original) | Copie si une ligne de même contenu, visible, la précède (date de visibilité, puis clé) ; inconnu si aucune ligne visible ne la précède, mais qu'une ligne non déterminée de même contenu peut la précéder (ordre connu antérieur ou ordre inconnu) |
        | D06 / `evenements` / `justificatif` | :2386-2399 | prestations du dossier dans la vue | (a) sans justificatif : propre, déterminé ; (b) clôture `regle` (ou `depot_cdc`) sans prestation (ou sans prestation `capital`) du dossier : vrai si aucune prestation visible ou non déterminée, faux si une visible, inconnu sinon ; verdict (a) OU (b) |
        | D13 / `sinistres` / `date_instruction` | :2402-2413 | prestations `capital` visibles des dossiers `deces` du sinistre | Vrai si une telle prestation est visible ; faux si aucune n'est visible ni non déterminée ; inconnu sinon (instruction absente à A : partie masquée = absente, partie refusée = règle bloquée, M169) |
        | D10c / `dossiers` / `NA` | :2437-2464 | autres dossiers du sinistre ; versions `deces` de `garanties_souscrites` de même (contrat, collège) | « Sans dossier `deces` dans la vue » : vrai si aucun visible ni non déterminé, faux si un visible, inconnu sinon ; « décès souscrit » : vrai si une version visible en vigueur à la survenance, faux si aucune visible ni non déterminée, inconnu sinon ; conjonction |
        | D02c / `assures` / `date_naissance` (deux emplois, S et X) | :2498-2509, :2551 | sinistres, affiliations, contrats individuels qui citent l'assuré | Vrai si une ligne visible donne un âge hors bornes ; faux si aucune ligne visible ni non déterminée n'en donne ; inconnu sinon |
        | D07 / `rentes` / `NA` | :2655-2669 | événements de la rente, version valable de l'enfant, paramètres | « En service » : la classe (service, fin) du dernier événement retenu ≤ A est inconnue si un événement non déterminé (effet ≤ A ou inconnu) peut le suivre dans l'ordre du § 4.2 avec une autre classe ; enfant : sur chaque candidate ; conjonction |
        | D07 / `dossiers` / `NA` | :2672-2697 | événements de clôture ou de second décès, enfants de l'assuré (membres et versions) | « Candidat » inconnu si une clôture ou un second décès non déterminé (effet ≤ A ou inconnu) existe ; « chaque enfant à charge éteint » : faux si un enfant visible n'est pas éteint de façon déterminée (M187), inconnu si un enfant non déterminé, ou une candidate, peut être à charge non éteint ; conjonction |

      - **Clés non exposées** (21), avec leur motif :
        - verdict propre à la ligne : D03a et D03b sur `assures` ; D03c ; D03e ; D03f (deux tables) ; D02a sur `contrats.date_terme`, `contrats.date_debut_gestion`, `garanties_souscrites.date_fin`, `ayants_droit_sante`, `prestations`, `cotisations`, `sinistres.date_declaration` ; D02c sur `designations` et `ayants_droit_sante` ;
        - ligne parente ou référencée seulement (D03h : contrat ; D02a sur `sinistres.date_survenance` : assuré ; D02a sur `evenements.date_effet` : sinistre ; D10b : garantie souscrite et sinistre) : la parente d'une ligne de la vue y est, par la règle 1 ; une ligne référencée est visible dès qu'une ligne visible la cite ;
        - D02a sur `sinistres.date_instruction` : la partie `date_instruction` ne devient non déterminée que par un refus de sa propre valeur, et la règle, qui la lit comme valeur, est alors bloquée (M169) ;
        - **D05** (:2378-2383) : l'absence de prestation se lit sur la base entière (`.valeurs()`, et non `.valeurs_vue()`), en complément exact du `manquant_obligatoire` de la règle B (:1160-1166), qui lit la même base : le verdict ne dépend d'aucune visibilité. Motif écrit au code (:2374-2377), conservé.
      - **Motif** (jugement d'expert, M218). Une règle qui juge une absence (D10c, D06, D13, D07 (c), `somme_parts`, D01b) détecte à tort, ou manque en silence, quand la ligne qui manque est seulement non déterminée (M209 : D10c sur DO2). L'écarter, avec sa cause, dit que la détection est partielle sans affirmer ni nier l'anomalie. Une ligne au verdict qui ne dépend pas des éléments non déterminés garde son verdict (principe de M187).
      - **Alternative écartée** (point P2 au mainteneur) : la logique de Kleene stricte jusqu'à la propre ligne. Une ligne non déterminée dont le verdict propre serait vrai donnerait aussi une ligne de `controles_non_executes`. Elle redouble `vue$visibilite_non_determinee` dans chaque règle. Mesure : sur `v1-modeste-02` sans déclaration au 2024-12-31, elle ajouterait (D02a, `prestations`, `fin_periode`), cause `declaration_absente`. PR00027 (D03g) y est non déterminée, et détectée par D02a quand elle est visible : 2 détections avec les déclarations, 1 sans (`jeux.R`, `jeu43.R`).
      - **Effet** : aucune provision. À A = extraction, aucun changement (aucune ligne n'y est non déterminée, (g) ; règle I). Sur les bases des tests à A < extraction, des détections disparaissent et des lignes partielles apparaissent (critères W1 à W6) ; M209 est soldée (W1). Les jeux versionnés ne changent pas (§ 2.6).
    - (e) `vue$provisoire = TRUE` dès que `visibilite_non_determinee` n'est pas vide.
    - (f) `declarations_requises` : aucune ligne. C'est un refus `R` : aucune déclaration ne permet de poursuivre (dict. § 1.10). L'exclusion déclarée demandée par l'issue #33 est reportée au dictionnaire `1.6` (point 6 du § 7 ; M203).
    - (g) À A = extraction, seuls (a) et (b) s'appliquent au bilan des contrôles : la vue reste totale (règle 3) et aucune ligne n'est non déterminée. Pour l'enjeu à l'extraction, voir le § 4.2 (Q2).
  - **Cas limites** (1 à 3 remplacés en v1.4 ; D2, Q6, C1).
    - **(1)** Une ligne qui porte deux refus de valeur apparaît sous chaque (`motif`, `origine`) dont la valeur peut changer son statut à A. Sans hypothèse de D02b, une ligne de date de saisie refusée apparaît aussi sous son type refusé : pour une saisie antérieure à l'effet, le type peut la faire passer de non déterminée à visible. Sous l'hypothèse de D02b, avec un effet antérieur à A, elle n'apparaît que sous la date de saisie, puisque max(saisie, effet) ≤ A équivaut alors à saisie ≤ A.
    - **(2)** Refus de valeur et D03g sur la même ligne, la date de saisie étant connue absente. Le verdict de D02b est faux (date absente). Sans déclaration, la ligne est non déterminée sous D03g. Sous `H` de D03g, sa date (date d'effet + délai) n'est pas calculable : la ligne reste non déterminée sous le motif du refus ; les exigences attendues sont celles de D03g au § 3.2 (une ligne `exclusions` à `traitements_admis = "X"` par famille, soit quatre lignes), et non celles du refus, qui n'en a aucune ((f)) (Q6). Sous `X` de D03g, la ligne sort de la vue, et le refus reste dans `refus_tables`. Ce cas vaut pour toute colonne refusée d'une ligne dont la date de saisie est connue absente, et non seulement pour la date d'effet de D03g : sous `H` de D03g, une date de visibilité refusée (par exemple `prestations.date_reglement`) laisse la ligne non déterminée sous le motif du refus, la date de saisie retenue ne suffisant pas à déterminer sa visibilité (validation d'`actuary` sur `4350e67`).
    - **(3)** Table refusée en portée table et refus de valeur dans cette table : la portée table l'emporte, que le refus de portée table vienne d'un défaut de forme de la table (C1), d'une propagation (`refus_induit`) ou d'un autre refus de portée table (clé, D01a, D04b `R`). Une règle P, ou une règle V qui ne lit la colonne que pour la vue, a pour cause le refus de portée table (priorité du § 3.1). Pour une règle P empêchée par un défaut de forme, l'origine du refus induit est la colonne de forme. Une colonne refusée pour sa valeur n'est ni la cause ni l'origine, et aucune ligne de cette table n'est inscrite sous un refus de valeur. Une règle qui lit la colonne refusée **comme valeur** garde la cause directe (M169, M185). (Extension à la propagation : avis d'`actuary` sur la question Q1 de la revue finale d'`audit`, 9 novembre 2026.)
    - **(4)** Refus de valeur sur la parente : les filles passent sous `parente_non_determinee`, sans exigence propre.
    - **(5)** Une table refusée en portée table (clé, D01a, D04b `R`, `evaluations_gestion`, § 7.5) : inchangé.
  - Une règle V empêchée à la fois par une cause directe et par un refus induit garde la cause directe (règle générale de priorité au § 3.1).
  - **Motif** (jugement d'expert) : un refus de valeur désigne ses lignes (« la ligne en est l'unité de compte et d'identification », dict. § 1.10) ; la vue se construit sur les autres sans lire de valeur refusée ; le bilan des refus reste invariant en A (§ 2.3, 2). Un défaut de forme n'est lu sur aucune ligne (dict. § 1.2) : aucune visibilité n'est déterminable, et la portée table le dit en une ligne, avec son origine. Avec un taux de défaut p par ligne, indépendant, la probabilité qu'une table de n lignes en porte au moins un est 1 − (1 − p)^n : pour p = 10⁻⁴, 0,6 % à n = 60 (taille des jeux versionnés de #19), 9,5 % à n = 1 000, 86,5 % à n = 20 000 (résultat exact sous l'hypothèse d'indépendance ; p est une valeur d'illustration).
  - **Alternative écartée** : portée table pour tout refus (M178 dans sa forme de Bd), disproportionnée sur une base de taille réelle : une seule date d'effet de contrat manquante refuse 13 tables à A0 (mesure d'`actuary-approfondi` à `ca90614`).
  - **Effet** : aucune provision. Jeux versionnés identiques hors de la colonne `origine` (mesuré sur la seconde reprise de #33, deux jeux aux deux arrêtés).

**Ordre d'exécution.**
1. Interruptions (ADR 0010, cinquième série, (a) 1, :273).
2. Forme.
3. Domaine, par strates (règle B à trois valeurs), puis les règles de domaine de portée `table`.
4. Clés (dont D04b sur `affiliations.college` et les chevauchements, qui lisent les refus de valeur des strates), puis refus induits.
5. Détection de D02b et D03g.
6. Évaluation unique de la visibilité et construction de la vue (§ 2.2 (c)).
7. Règle V (§ 2.2 (d)).
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

1. **Invariance** : pour A1 ≠ A2 sur une même base, les lignes du bilan des règles B et P (détection) sont `identical()`, hors les refus induits nés d'une règle P empêchée par un défaut de forme (M178), seuls dépendants de l'arrêté, et hors `nombre_visibles` et `nombre_dossiers`.
   - les lignes de `controles_non_executes` nées de la règle B (détections partielles, M217) sont invariantes en A, comme ses constats.
2. **Identité** : à A = extraction, chaque compte de la règle V égale celui d'une détection directe sur la base entière, et D02b et D03g sont en `S`.
3. **Aucune exclusion par la vue** : toute orpheline injectée (registre de D04) figure au bilan à tout arrêté.
4. **Registre** : à A = extraction, détection exacte égale à l'injection (dict. :733). À A < extraction, pour les défauts intrinsèques à la ligne (D02a hors `famille`, D03a à D03f), les lignes détectées égalent les lignes injectées visibles à A.
5. **Refus sur ligne invisible** : un D09 de signe injecté sur une prestation de `date_saisie` > A figure dans `refus_tables` à A, avec `nombre_visibles = 0`.
6. **Substitution** (v1.4, R2). Pour toute ligne, ou partie de ligne, qui porte une valeur refusée lue par une règle P, on remplace la valeur refusée par des valeurs admises contrastées : type programmable et non programmable, motif qui rend le type programmable ou non, date antérieure et date postérieure à A ou à la date comparée, absence. Si le statut à A diffère entre les substitutions, la ligne est non déterminée sous un refus ; sinon, elle a ce statut. Le contrôle porte sur un corpus fini de cas qui couvre chaque colonne du tableau de (c), sans hypothèse et sous l'hypothèse de D02b. C'est une vérification, pas une preuve : la règle découle de (b) et (c).

   **Extension (v1.5)** (vérification, non preuve) :
   - (a) *Règle B* : pour chaque règle du recensement et chaque ligne qui lit une valeur refusée, on substitue à cette valeur chaque valeur du domaine de sa colonne, et l'absence pour une colonne non obligatoire. La ligne est écartée si et seulement si le verdict varie ; sinon, elle a le verdict commun. Les règles de la colonne substituée elle-même sont exclues de la comparaison (auto-lecture). Le corpus couvre chacune des 22 colonnes lues du tableau du § 2.2 ; il comprend un refus de strate 0 lu en strate 1 (`code_garantie`), une chaîne jusqu'à la strate 3 (`type_evenement`, `motif`, `date_effet`) et une jointure (`nature_contrat` lu par `garanties_souscrites.college`). Prototype : `subst.R`, sur le code à `26c23c9`.
   - (b) *Visibilité* : chaque ligne de D02b ou de D03g, et chaque partie, est rejouée sous chaque traitement admis : hypothèse avec un délai nul et avec un délai qui dépasse A − date d'effet, exclusion. Elle est invisible de façon déterminée si et seulement si elle n'est visible sous aucun d'eux, non déterminée si son statut diffère entre eux.
   - (c) *Règles V* : chaque élément non déterminé dont dépend une ligne est forcé dans la vue puis hors de la vue (pour `famille`, chaque candidate est tour à tour la version valable). La ligne est écartée si et seulement si le verdict varie.
   - (d) *Comptes de dossiers* : même substitution pour le statut de rattachement d'un dossier (§ 4.4).

**Critères de #42 (M217)** — mesures de la sortie actuelle à `26c23c9` (`m42.R`, `m42b.R`, `subst.R`) ; effet attendu par constat de substitution :

- **B1** (EV6 de type `zzz`, A0 et A) :
  - *actuel* : `refus_tables` porte `hors_domaine` sur `type_evenement` et un `D02c` induit sur `date_effet` (EV6) ; `vue$visibilite_non_determinee`, à A0, porte deux rangées (D02c, origine `evenements.date_effet` ; `hors_domaine`, origine `evenements.type_evenement`) ; les causes de D02a et de D02b sont `D02c` ;
  - *après* : plus de D02c ; à A0, une seule rangée non déterminée (`hors_domaine`, `evenements.type_evenement`) ; causes de D02a (règle bloquée, M169) et de D02b (règle P partielle) : `hors_domaine` ; six lignes partielles de la règle B, cause `hors_domaine` : (D02c, `evenements`, `date_effet`), (`hors_domaine`, `evenements`, `id_dossier`), (`hors_domaine`, `evenements`, `id_rente`), (`hors_domaine`, `evenements`, `motif`), (`manquant_obligatoire`, `evenements`, `montant`), (`manquant_obligatoire`, `evenements`, `source_information`).
- **B2** (EV5 de type `fixation_capital`, du domaine mais incompatible avec la rente d'éducation, A) :
  - *actuel* : `hors_domaine` sur `type_evenement` (colonne) et sur `id_rente` (portée table : `evenements` est refusée en portée table) ;
  - *après* : le type reste refusé (site 31, auto-lecture) ; le refus de `id_rente` disparaît, et avec lui le refus de portée table de `evenements` ; cinq lignes partielles, cause `hors_domaine` : `hors_domaine` sur `id_dossier`, `id_rente` et `montant`, `manquant_obligatoire` sur `motif` et `source_information`.
- **B3** (GS2 de `code_garantie` `zzz`, A) :
  - *actuel* : 14 rangées dans `refus_tables`, celle du code et 13 autres : `hors_domaine` sur `type_franchise`, `regle_complement`, `periodicite_prestation`, `terme_prestation` et `parametres.parametre` (portée table) ; D10a sur `dossiers` et sur `prestations` ; `hors_domaine` sur `evenements.type_evenement` ; cinq `refus_induit` (`beneficiaires`, `rentes`, `evenements`, `prestations`, `evaluations_gestion`) ;
  - *après* : une seule rangée, `hors_domaine` sur `garanties_souscrites.code_garantie` (GS2), sans refus induit ; lignes partielles, cause `hors_domaine`, notamment D10a sur `dossiers` (DO3) et sur `prestations` (PR1), `chevauchement` sur `garanties_souscrites` (GS1, GS2, GS3 écartées : GS2 peut appartenir au groupe de GS1 ou de GS3), `hors_domaine` sur `parametres.parametre`, les quatre colonnes conditionnelles déjà refusées et huit `manquant_obligatoire` du site 8, `hors_domaine` sur `evenements.type_evenement` (EV2) et `manquant_obligatoire` sur `evenements.id_rente` (EV2).
- **B4** (CT2 de `nature_contrat` `zzz`, A) :
  - *actuel* : 16 rangées, dont `contrats` refusée en portée table (`id_adherent`, `id_assure`) et 12 `refus_induit` ;
  - *après* : une seule rangée, `hors_domaine` sur `nature_contrat` ; lignes partielles `manquant_obligatoire` sur `id_adherent`, `hors_domaine` sur `id_assure` et sur `date_terme`, cause `hors_domaine`.
- **B5** (cas symétrique, EV3 `sortie` non programmable, effet 2027-03-01 > extraction, A) : *actuel* et *après* : D02c sur `date_effet` (EV3), inchangé.
- **B6** (EV6 de motif `zzz`, A ; chaîne jusqu'à la strate 3) : *actuel* : D02c sur `date_effet` et `hors_domaine` sur `motif` ; *après* : `hors_domaine` sur `motif` seul ; ligne partielle (D02c, `evenements`, `date_effet`), cause `hors_domaine`.
- **B7** (BE1 de `qualite` `zzz`, A0) : *actuel* : `hors_domaine` sur `qualite` et sur `id_membre` (portée table) ; *après* : `qualite` seule ; ligne partielle (`hors_domaine`, `beneficiaires`, `id_membre`), cause `hors_domaine`.
- **B8** : tests d'acyclicité et de couverture de la constante (B.2, B.3) ; invariance en A des lignes partielles (critère 1) ; batterie (a) du critère 6 ; tests de complexité de `controler_base()` (#45) toujours verts.

**Critères de #43 (M216)** (`m43*.R`) :
- **V1** (PR1 sans `date_saisie`, `date_reglement` 2026-12-01, A0, sans déclaration) :
  - *actuel* : PR1 dans `vue$visibilite_non_determinee` (D03g) ; `provisoire` = TRUE ; `.connus()` rend FALSE pour PR1 (divergence vue ↔ comptes) ; sept lignes requises (quatre `exclusions` `H;X`, deux `hypotheses` `H;X`, un seuil), `nombre_lignes` = 1 ;
  - *après* : PR1 invisible, non inscrite ; `provisoire` = FALSE ; `controles` et `declarations_requises` identiques ; `.connus()` = FALSE.
- **V2** (même base, `date_reglement` 2025-01-15 ≤ A0) : *actuel* et *après* : PR1 non déterminée (D03g), inchangé.
- **V3** (RE1 sans `date_saisie`, A = 2024-12-31, parente DO2 ouverte le 2025-02-02) : *actuel* : RE1 non déterminée (D03g) ; *après* : invisible, non inscrite ; exigences inchangées.
- **V4** (EV3 saisi le 2026-01-01 > A0, effet 2026-02-01, D02b sans hypothèse) : *actuel* : non déterminée (D02b) ; deux lignes `hypotheses` (`H`), `nombre_lignes` = 1 ; *après* : invisible, non inscrite ; `controles` (D02b, EV3) et exigences inchangés.
- **V5** (EV3 sans `date_saisie`, effet 2025-09-01 > A0, D03g sans déclaration) : *actuel* : non déterminée ; *après* : invisible (date d'effet de l'hypothèse ; point P1) ; exigences inchangées.
- **V6** (SI2 sans `date_saisie`, `date_declaration` 2025-09-01 > A0) : *actuel* : cinq rangées (SI2 sous D03g ; DO3, EV1 à EV3, PR1, EG1 sous `parente_non_determinee`), `provisoire` = TRUE ; *après* : aucune rangée, `provisoire` = FALSE (filles d'une parente invisible : M167 rouverte) ; exigences inchangées.
- **V7** (SI2 sans `date_saisie`, `date_declaration` 2024-03-05 ≤ A0) : *actuel* et *après* : cinq rangées, inchangé.
- **V8** (partie de ligne : CT2 de `date_fin` 2026-06-30, `date_saisie_fin` manquante, A0) : *actuel* : rangée (`contrats`, `date_saisie_fin`, D03g) ; *après* : partie masquée de façon déterminée, non inscrite ; deux `hypotheses` `H` et un seuil, inchangés.
- **V9** (même base, `date_fin` 2025-03-01 ≤ A0) : *actuel* et *après* : rangée inchangée.
- **V10** (CT2 d'effet 2025-12-01 > A0, même partie) : *actuel* : rangée de la partie ; *après* : ligne invisible, partie non inscrite.
- **V11** (`famille` : ME1 en deux versions, v1 saisie le 2025-02-01 sans `date_naissance`, v2 sans `date_saisie` (D03g) avec naissance, A0) :
  - *actuel* : la vue retient v1 comme version valable ; `.connus()` la rend non déterminée ;
  - *après* : version valable non déterminée, candidates v1 et v2, aucune version désignée dans la vue ; `.connus()` (v1) = NA ; v2 inscrite sous D03g, v1 non inscrite.
- **V12** (version remplacée, à A ; `m43f.R`) : `nombre_visibles` passe de 1 à 0 (point P5).
- **V13** : **test de concordance ligne à ligne**. Il porte sur toute table non refusée en portée table, hors lignes exclues par X de D03g. Ligne retenue par la vue ⟺ statut visible. Statut non déterminé ⟺ ligne inscrite dans `vue$visibilite_non_determinee`, ou version candidate d'un membre à version valable non déterminée, ou ligne de `adherents` ou `assures` citée seulement par des lignes non déterminées. Partie masquée ⟺ partie non connue à A ou non déterminée ; partie non déterminée ⟺ partie inscrite.
- **V14** : batterie (b) du critère 6.

**Critères de #40 (M218)** (`m40.R`, `m40b.R`, `m40c.R`) :
- **W1** (`d12$dossiers` : DO1 sans `date_ouverture`, A0 ; M209) :
  - *actuel* : D10c détecté sur DO2 ; aucune ligne D10c dans `controles_non_executes` ;
  - *après* : D10c non détecté ; ligne (D10c, `dossiers`, `NA`), cause `manquant_obligatoire` (motif de DO1). Le test `tests/unitaires/donnees.R:1724-1727`, qui attend « D10c s'exécute » sous ce refus, est à réécrire ;
  - à A : D10c absent, inchangé (`m40c.R`).
- **W2** (`somme_parts` : BE2 copie de BE1, parts 0,5, BE2 sans `date_saisie`, A0) :
  - *actuel* : `somme_parts` détecté sur BE1 ;
  - *après* : non détecté ; ligne (`somme_parts`, `beneficiaires`, `part`), cause `declaration_absente` ;
  - témoins inchangés : BE2 saisi le 2025-03-01, aucun `somme_parts` ; BE2 saisi le 2025-09-01 (invisible de façon déterminée), `somme_parts` sur BE1.
- **W3** (`famille`, base de V11) : *actuel* : deux constats D03a (S et `X;H`) sur ME1|2025-02-01 ; *après* : aucun ; ligne (D03a, `famille`, `date_naissance`), cause `declaration_absente`.
- **W4** (D06 : EV7 `cloture_dossier`, motif `regle`, sur DO1, effet 2025-03-15 ; PR2 sans `date_saisie` ; A0) :
  - *actuel* : D06 détecté sur EV7 ;
  - *après* : non détecté ; ligne (D06, `evenements`, `justificatif`), cause `declaration_absente` ;
  - témoin (PR2 saisi) : aucun D06, inchangé.
- **W5** (D13 : SI1 sans `date_instruction`, PR2 (capital de DO1 `deces`) sans `date_saisie`, A0) :
  - *actuel* : aucun D13, sans trace (minorant silencieux) ;
  - *après* : ligne (D13, `sinistres`, `date_instruction`), cause `declaration_absente` ;
  - témoin (PR2 saisi) : D13 sur SI1, inchangé.
- **W6** (D07 (c) : ME1 né le 1995-01-01, EV7 `fin_service` de RE1 d'effet 2025-03-01 sans `date_saisie`, A0, conventions `revolu` et `atteinte`) :
  - *actuel* : D07 détecté sur RE1 ;
  - *après* : non détecté ; ligne (D07, `rentes`, `NA`), cause `declaration_absente` ;
  - témoins : EV7 saisi le 2025-03-02, aucun D07 ; sans EV7, D07 sur RE1 ; inchangés.
- **W7** : à A = extraction, bilan identique (règle I) sur toutes les bases des tests.
- **W8** : ligne non déterminée et verdict propre (population) : aucune ligne de `controles_non_executes` pour PR00027 de `v1-modeste-02` sans déclaration au 2024-12-31 (point P2).
- **W9** : batterie (c) du critère 6 ; aucune cause nouvelle (test d'exhaustivité de `.RANGS_CAUSES` inchangé) ; invariant : toute cause `declaration_absente` d'une règle V a sa ligne dans `declarations_requises`.

### 2.6 Effet sur les jeux versionnés

Mesures à `26c23c9` (`jeux.R`, `jeu43.R`, `jeu44.R`, `mjeu.R`). Deux jeux, aux deux arrêtés de `tests/jeux_v1.R` (2024-12-31 et extraction 2025-12-31), avec `declarations.txt` (configuration des jeux) et, pour information, sans déclaration (conventions seules).

| Jeu, arrêté | Constat à `26c23c9` | #42 | #43 | #40 | #44 |
|---|---|---|---|---|---|
| `v1-modeste-01`, les deux arrêtés, avec ou sans déclaration | aucun refus, aucun constat, aucune ligne non déterminée (sans déclaration : D02c non exécuté, `declaration_absente`, six seuils requis) | nul (aucun refus) | nul | nul | nul |
| `v1-modeste-02`, 2024-12-31, avec déclaration | un refus, D09 sur `prestations.montant` (1 ligne, visible) ; aucune ligne non déterminée ; `provisoire` = FALSE | nul : `prestations.montant` n'est lue par aucune des 83 règles concernées (résultat exact) | nul (aucune ligne non déterminée) | nul (idem) | nul : toutes les lignes des constats R et X sont visibles ; `refus_tables` et `exclusions` identiques sous (i) et (ii) (prototype `jeu44.R`) ; aucun écart sur une table à composantes 1 à 4 |
| `v1-modeste-02`, 2024-12-31, sans déclaration | lignes non déterminées : EV00024, EV00044, EV00059 (D02b), PR00027 (D03g) ; toutes leurs dates, et celles de leurs parentes, sont au plus A | nul | nul : aucune n'est invisible de façon déterminée (même sous le point P1) | nul pour les lignes croisées : les détections des autres lignes sont identiques quand ces quatre lignes sont toutes visibles (avec déclaration) ou toutes hors de la vue (sans), et les règles qui pourraient les lire (D06, D13, D01b) sont monotones dans l'ensemble des lignes de la vue (jugement sur mesure) ; sous P2 strict : une ligne (D02a, `prestations`, `fin_periode`) de plus | nul (constats non visibles : D02b et D03g, traités `H`, sans compte de dossiers) |
| `v1-modeste-02`, extraction | idem 2024-12-31 avec déclaration (comptes à l'extraction) | nul | nul (vue totale) | nul (règle I) | nul (tout visible) |

**Effet attendu** : bilans de `controler_base()` identiques sur les deux jeux aux deux arrêtés, avec `declarations.txt`, après chacun des quatre commits. Les fichiers des jeux ne sont pas touchés (`empreintes.md5` inchangé, M189). Le résultat est exact pour #42 et #44 (mesure et recensement), et pour #43 (aucune ligne non déterminée avec déclaration). Pour #40 sans déclaration, il repose sur une mesure aux deux états extrêmes et sur un argument de monotonie. À remesurer à chaque commit (tableau avant / après).

## 3. Place des lignes du bilan et bilan sans déclaration

### 3.1 Place des lignes (ADR 0010, sixième série, (b), :299-304)

- **`refus_tables`** : tout refus `R`, défaut `D..` ou code de contrôle.
  - `portee` vaut `colonne` ou `table`, portée effective résolue par la règle du § 1.10 : `colonne_table` devient `table` pour une colonne de clé primaire ou une colonne qui porte une référence.
  - `colonne` est la colonne d'origine, `NA` pour `refus_induit` et `table_conditionnelle_absente`.
  - `origine` d'un `refus_induit` (M178 ; ADR 0010, neuvième série, (f) ; `.refus_p_empechee()`, `R/donnees.R:1471`) : tables visées refusées, et, pour un refus né d'une règle P empêchée par un défaut de forme, la colonne « table.colonne » qui l'empêche, jointes par « ; » (colonnes d'abord, en tri radix, puis tables dans l'ordre du dictionnaire).
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
- **`controles_non_executes`** : une ligne par clé (`code`, `table`, `colonne`) d'un contrôle non exécuté, ou exécuté en partie, avec sa cause (ADR 0010, huitième série, (a) et (e), et neuvième série, (c) ; M168, M178) :
  - `non_implemente` : contrôle prévu et pas encore écrit (report déclaré, M181, issue #34) ;
  - `non_lisible` : sous-cas qu'aucune colonne du dictionnaire ne permet de lire (D03h collectif, M168) ;
  - **cause directe** : motif du refus d'une colonne lue (écart de forme ou refus `R`) (M169). Liste fermée (v1.4) : codes de `controles.csv` et de `defauts.csv`, et sous-cas lettrés de D10 (`.TRAITEMENTS_SOUS_CAS_D10`, D10a à D10f et D10h ; la lettre g n'est attribuée à aucun sous-cas). Une cause qui n'est ni rangée (ci-dessous) ni motif de refus provoque l'arrêt « erreur interne de provie » ;
  - `age_non_defini` : âge non défini (§ 5.2) ;
  - `parametre_non_defini` : limite d'âge non déterminable (§ 5.3, M187) ;
  - `declaration_absente` : **déclaration du plan absente** (v1.5, sens élargi, M218). Deux cas :
    - (i) convention ou seuil du plan (§ 1, § 5) ;
    - (ii) **déclaration de traitement** d'un motif de la règle P : hypothèse de D02b ; hypothèse, exclusion ou délai de D03g. Son absence laisse de visibilité non déterminée une ligne, ou une partie, dont dépend le verdict d'une règle V (§ 2.2 (d)).

    Dans les deux cas, la déclaration manquante figure dans `declarations_requises` (§ 3.2) : c'est vrai de toute ligne non déterminée sous D02b ou D03g, y compris celle dont la date ne se calcule pas sous l'hypothèse, qui attend l'exclusion (réserve Q5). Le motif (c) de la priorité des causes reste donc exact. Le dictionnaire ne définit pas cette cause (`grep -c declaration_absente docs/specifications/dictionnaire-base-v1.md` : 0) : la définition est celle-ci.
  - `refus_induit` : contrôle empêché par un refus induit (règle B, ou règle P empêchée, M178).
  - Une composante de l'enjeu empêchée y figure aussi, sous le code de la composante (§ 4.3), avec la table et la colonne lues. `visibilite_non_determinee` n'est jamais une cause de cette table (§ 4.2).
  - Une clé présente à la fois dans `controles` et ici est une détection partielle : son nombre est un minorant.
  - **Cause d'une ligne de règle V écartée** (v1.5, cause (γ), M218). Pour chaque élément non déterminé dont l'état peut changer le verdict (lecture existentielle), sa cause est :
    - le motif du refus pour une ligne ou une partie non déterminée par un refus de valeur (`motif` de sa rangée de `vue$visibilite_non_determinee`) ;
    - `declaration_absente` pour D02b ou D03g ;
    - pour `parente_non_determinee`, la cause de l'ascendante la plus proche qui est non déterminée par elle-même (récursivement) ;
    - pour une candidate de `famille`, la cause de la version non déterminée.

    Entre plusieurs éléments, la priorité ci-dessous s'applique : une cause directe (rang 3) passe avant `declaration_absente` (rang 6). À rang égal, l'ordre de `vue$visibilite_non_determinee` (tri du bilan) départage. `visibilite_non_determinee` n'est toujours pas une cause de cette table. **Aucune cause nouvelle** (M218 ; ensemble et ordre de M195 inchangés).
  - **Lignes de la règle B** (v1.5, M217). Deux sortes de lignes de la règle B figurent dans `controles_non_executes` :
    - comme aujourd'hui, une règle bloquée par un défaut de forme d'une colonne lue (cause = défaut de forme ; mesure `m42b.R`, cas de forme) ;
    - **désormais**, une règle concernée qui écarte au moins une ligne : détection partielle, cause = motif du refus de valeur lu (rang 3), que la clé figure aussi dans `controles` (détection partielle au sens de l'ADR 0010, huitième série, (e)) ou non (aucune ligne détectée parmi les lignes au verdict déterminé : pas de zéro rassurant).

    La forme du bilan ne change pas. L'ADR 0010 est à annoter par `architect` pour consigner cette extension (point de la fiche de Bdk, « ADR », (2)), et le sens élargi de `declaration_absente` (point (1)).
  - **Priorité des causes** (M185 ; décisions du mainteneur du 9 novembre 2026, M194 et M195, issue #36). Quand plusieurs causes visent une même clé (plusieurs règles, emplois ou colonnes lues), la cause retenue est la première dans l'ordre suivant :
    1. `non_implemente` ;
    2. `non_lisible` ;
    3. cause directe ;
    4. `age_non_defini` ;
    5. `parametre_non_defini` ;
    6. `declaration_absente` ;
    7. `refus_induit`.

    À rang égal (deux causes directes), la première émise l'emporte : ordre d'exécution du § 2.2, puis, dans une règle, ordre des colonnes lues. `refus_induit` n'est donc retenu que si la clé n'a aucune autre cause. La priorité de la cause directe sur tout refus induit, règle B comprise (M185), est conservée ; elle départage des causes qui empêchent chacune la règle ; un refus de valeur sur une colonne lue seulement par la règle P ou pour la vue n'en est pas une (§ 2.2, cas limite 3).
  - **Motif** (jugement d'expert) : (a) l'ordre ne dépend pas de l'ordre d'exécution du code : réordonner deux règles ou deux emplois ne change pas le bilan ; (b) passent d'abord les causes que rien ne lève côté utilisateur (outil, puis dictionnaire), puis le défaut de l'extraction (refus `R`), puis la grandeur que la base ne détermine pas ; (c) les deux derniers rangs vont aux causes dont l'information reste au bilan quand elles ne sont pas retenues : `declaration_absente` est toujours reprise dans `declarations_requises` (§ 3.2), le refus d'origine d'un `refus_induit` dans `refus_tables`. Une cause directe, `age_non_defini` ou `parametre_non_defini` masquée serait perdue.
  - **Alternative écartée** : la première cause émise (ordre d'exécution), qui ferait dépendre une sortie du bilan de l'agencement du code.
  - **Effet** : aucune ligne sur les bases des tests ni sur les jeux versionnés à `ca90614` (mesure d'`actuary-approfondi`, 309 appels de `.bilan()` et deux jeux aux deux arrêtés) ; seule la clé (`D02c`, `assures`, `NA`) est touchée, sur des bases à défauts multiples (cas « #38 (a) » et « #38 (b) » de `tests/unitaires/donnees.R`, `d4d3abd`, en échec attendu jusqu'à #36). Le cas X3, ajouté par `7c16ff5`, est touché sur la même clé (`declaration_absente` et `manquant_obligatoire` émises ; `manquant_obligatoire` retenue, rang 3 < 6).

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
- À A < extraction, une ligne de D03g non résolue (déclaration incomplète, ou date non calculable sous `H`), ou de D02b dont l'hypothèse n'est pas déclarée, n'a pas de date de visibilité (M167, M171). Elle est **invisible de façon déterminée** si elle n'est visible sous aucun traitement admis (§ 2.2 (c), points 2 et 3 ; M216) ; elle est alors hors de la vue et n'est pas recensée. Elle est **de visibilité non déterminée** sinon. Ces dernières lignes sont :
  - tenues hors de la population des règles V (§ 2.2 (d)) ;
  - recensées dans `vue$visibilite_non_determinee` (`table` ; `colonne` : `NA` pour la ligne entière, sinon la partie de ligne ; `motif`, dont `parente_non_determinee` pour les filles écartées par la règle 1, et le code du refus pour une ligne non déterminée par un refus de valeur (§ 2.2) ; `origine` : « table.colonne » de la valeur refusée pour un motif de refus, toujours une colonne de la table de la ligne (v1.4, Q8), `NA` pour D02b, D03g et `parente_non_determinee` (M202) ; `nombre` ; `identifiants`). Regroupement par (`table`, `colonne`, `motif`, `origine`) ; tri existant, puis `origine` (ADR 0010, quatorzième série, (b)). Colonnes et regroupement inchangés en v1.5.

  Dans les deux cas, ses exigences dans `declarations_requises` sont inchangées (lecture (b1) de M216). Une partie de ligne suit la même règle (§ 2.2 (c), point 4). Une partie non déterminée laisse la ligne dans la vue ; une partie d'une ligne invisible n'est pas recensée.

  `vue$provisoire` vaut `TRUE` si ce sous-élément n'est pas vide, ou si une règle P a été empêchée par un défaut de forme sur une table lue par la vue (cette table et ses filles portent alors un refus induit de portée table, § 2.2, M178) : les comptes de la règle V sont alors provisoires. Invariant testé : `provisoire` ⇒ `visibilite_non_determinee` non vide, ou refus de portée table sur chaque table refusée par une règle P empêchée ; et chaque ligne de `visibilite_non_determinee` a sa justification : D02b ou D03g → une ligne de `declarations_requises` ; motif de refus → la ligne de `refus_tables` de même table, colonne (celle de l'`origine`) et motif ; `parente_non_determinee` → sa parente non déterminée.
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

- **Connus** = connus à A, sur la vue (§ 2, règle V). Une ligne invisible à A n'a aucun montant connu à A. Connus = connus à A, sur l'évaluation unique de la visibilité (§ 2.2 (c)).
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
  - Un porteur de visibilité non déterminée, ou une ligne qui entre dans sa valeur, donne `NA`, cause `visibilite_non_determinee`, hors de `controles_non_executes`. La cause l'emporte sur l'absence de porteur. Une ligne de visibilité non déterminée par un refus de valeur (§ 2.2) est un porteur de visibilité non déterminée (M201). Un dossier dont le rattachement à A est non déterminé (§ 4.4) est un porteur de visibilité non déterminée.
    - **À A = extraction** (v1.4 ; décision du mainteneur du 9 novembre 2026, Q2 ; D3), la vue est la base entière (règle 3).
      - Une composante qui ne lit une colonne de visibilité que pour la visibilité n'est pas empêchée par un refus de valeur de cette colonne : la ligne refusée est chiffrée telle quelle.
      - Une composante qui lit aussi la colonne comme valeur reste empêchée, avec `montant = NA` et `cause` = motif du refus (M169) ; l'empêchement porte sur toute la composante (M173, M176).
      - **Liste fermée des colonnes de visibilité lues comme valeur** (`.LUS_VALEUR_ENJEU`) : `evenements.date_saisie`, par les composantes 2 à 4 (départage, point 3). Les autres colonnes de visibilité que lisent les composantes ne servent qu'à la visibilité : `dossiers.date_ouverture`, `rentes.date_saisie`, `prestations.date_saisie` et `prestations.date_reglement`, `cotisations.date_mouvement`. La fenêtre des paiements est bornée par l'extraction (dict. :143), pas par la composante. La composante 8 lit `evenements.date_saisie` pour la visibilité seule.
    - **À A < extraction**, inchangé : la ligne refusée est de visibilité non déterminée, et chaque porteur qu'elle touche est sans valeur, cause `visibilite_non_determinee` (M201).
    - **Motif.** À l'extraction, aucune visibilité n'est à établir. Ne pas lire une colonne qui ne sert qu'à la visibilité aligne l'enjeu sur les règles V. Le départage, lui, lit la valeur refusée, ce que le dict. § 1.10 interdit.
    - **Effet** : aucune provision. Sur les bases des tests, des composantes empêchées à l'extraction deviennent chiffrées. Par exemple : un refus de `dossiers.date_ouverture` de DO1 donne 60000, 60000, 0, 0 ; un refus de `prestations.date_reglement` de PR2 donne 60000 ; un refus de `cotisations.date_mouvement` de CO1 donne 1000 et 0.
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

- **Rattachement à A** (v1.5, M219, lecture (ii) ; jugement d'expert). Pour un écart (refus ou exclusion) de lignes L d'une table, et pour chaque dossier d que le tableau ci-dessous rattache à une ligne de L (`.rattacher()`, `R/donnees.R:2919-2968`, inchangé), le statut de d est :

  s(d) = statut(d) ET (OU, sur les lignes ℓ de L rattachées à d, de statut(ℓ))

  en logique de Kleene, les statuts étant ceux de l'évaluation unique (§ 2.2 (c)). Pour un écart de D03g, c'est sa variante `d03g`, qui vaut pour la ligne comme pour le dossier. Le dossier est **rattaché à A** si s(d) est vrai, non rattaché si s(d) est faux, et de rattachement non déterminé sinon. Pour la table `dossiers`, ℓ = d.
- **`nombre_dossiers`** :
  - `NA` si le rattachement est illisible par sa forme (inchangé) ;
  - sinon `NA` si un dossier est de rattachement non déterminé : une ligne de visibilité non déterminée y est rattachée à un dossier qu'aucune ligne visible ne rattache déjà ;
  - sinon le nombre de dossiers rattachés à A ;
  - 0 pour une table sans dossier rattaché (`cotisations`, `evaluations_gestion`, `designations`, `ayants_droit_sante`).

  La même règle vaut dans `refus_tables` (par constat), dans `exclusions` (union des lignes d'une clé (`motif`, `famille`, `action`)), et dans `enjeu` (rangée par garantie et rangée `ensemble`).
- **Montants des composantes 1 à 4.** Ils se somment sur les dossiers rattachés à A. Un dossier de rattachement non déterminé est un porteur de visibilité non déterminée (M201) : `montant` = `NA`, `cause` = `visibilite_non_determinee`, hors de `controles_non_executes`. Un dossier non rattaché n'entre pas dans l'écart, et ne crée pas de rangée de garantie. Une composante empêchée par une colonne lue (cause = motif) reste empêchée, quel que soit le nombre de dossiers (M173, M176, inchangé).
- **Rangée `motif = ensemble`.** Le statut d'un dossier y est la disjonction de Kleene de ses statuts dans les écarts de la rangée. Aujourd'hui, la première occurrence l'emporte (`.rangees_enjeu()`, `R/donnees.R:3604`) ; c'était indifférent tant que le statut ne dépendait pas de l'écart.
- **`hypotheses_defaut`** n'a pas de colonne `nombre_dossiers` (`R/donnees.R:3884`, `.agreger_placement()` sans `dossiers = TRUE`) : le critère correspondant de l'issue #44 est retiré (M219).
- **Motif** (jugement d'expert, M219 ; recommandation de l'issue #44). L'enjeu mesure l'exposition connue à l'arrêté : un refus porté par une ligne inconnue à A ne touche aucun dossier à cette date.
- **Alternative écartée** : (i), dossiers rattachés connus quelle que soit la visibilité de la ligne (le code à `26c23c9`). Elle compte un dossier touché par une ligne invisible (PR2, EV5, BE1 ci-dessous).
- **Effet** : aucune provision. `nombre_dossiers` et les montants des composantes 1 à 4 changent à A < extraction sur les bases dont une ligne écartée est invisible ou non déterminée. Rien ne change à A = extraction, où tout est visible (hors version de `famille` remplacée, § 2.2 (c)). Les jeux versionnés ne changent pas (§ 2.6).

Les composantes 1 à 4 se somment sur ces dossiers ; les composantes 5 à 8 sur les lignes.

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
- `nombre_visibles` suit l'évaluation unique (§ 2.2 (c)) et vaut `NA` si une visibilité est indéterminée (v1.4, Q7). `nombre_dossiers` suit le rattachement à A ci-dessus (v1.5, M219).

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
| `nombre_dossiers` | dossiers rattachés à A (§ 4.4) |
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
4. Une composante qui lit une colonne refusée a `montant = NA`, `cause` renseignée, et figure dans `controles_non_executes`, sous le code de la composante, sauf, à A = extraction, une composante qui ne lit la colonne refusée que pour la visibilité (§ 4.2, Q2 ; v1.4).
5. Un dossier touché par D01b et D02a compte une fois dans la rangée `ensemble`.
6. Pour un dossier, `montant_en_vigueur` d'`etats_a_date()` égale la composante 2, 3 ou 4 correspondante.
7. `non_declaree` n'apparaît que si `declarations` ne couvre pas le motif.

**Critères ajoutés (#44)** (`m44.R`, `m44ii.R`, `m43.R` ; *après* : attendu pour l'enjeu, prototype pour les comptes de `refus_tables` (`m44ii.R`)) :
- **E1** (PR2 au montant négatif (D09), saisie le 2026-06-01, A0) :
  - *actuel* : `refus_tables`, `nombre_visibles` 0 et `nombre_dossiers` 1 ; `enjeu` : rangées `deces` et `ensemble`, `prestations_ecartees` `NA` (cause D09), `nombre_dossiers` 1 ;
  - *après* : `nombre_dossiers` 0 ; la rangée `deces` disparaît ; la rangée `ensemble` garde `NA`, cause D09, avec `nombre_dossiers` 0 ;
  - à A : `nombre_dossiers` 1, inchangé.
- **E2** (EV5 au montant négatif (D09), saisi le 2026-01-01, A0) :
  - *actuel* : `nombre_dossiers` 1 ; `paiements_cumules` 750 (rangées `rente_education` et `ensemble`), `nombre_valeurs` 1 ;
  - *après* : `nombre_dossiers` 0 ; la rangée `rente_education` disparaît ; `paiements_cumules` 0 et `nombre_valeurs` 0 ; les composantes empêchées par D09 restent `NA`, cause D09.
- **E3** (PR2 au montant négatif et `date_reglement` refusée (D02c), A0 : PR2 non déterminée) : *actuel* : `nombre_dossiers` 1 sur les deux rangées de `refus_tables` et dans `enjeu` ; *après* : `NA`.
- **E4** (BE1 de `qualite` `zzz`, saisi le 2026-01-01, A0 ; après #42, la rangée `id_membre` a disparu (B7)) :
  - *actuel* : `nombre_dossiers` 1 ; `paiements_cumules` 60000 et `capital_fixe` 60000 sur DO1 ;
  - *après* : `nombre_dossiers` 0 ; la rangée `deces` disparaît ; 0 et 0, `nombre_valeurs` 0.
- **E5** (DO1 sans `date_ouverture`, A0) : `NA` → `NA`, inchangé. **E6** (CO1 au montant négatif, sans dossier) : 0 → 0.
- **E7** (exclusion X de D03g de PR1, `date_reglement` 2026-12-01, A0) : *actuel* : `exclusions`, `nombre_dossiers` 1 ; `enjeu`, `nombre_dossiers` 1, montant 0 ; *après* : `nombre_dossiers` 0 aux deux, montant 0. Même effet sur l'enjeu `non_declaree` sans déclaration.
- **E8** (refus sur une version de `famille` remplacée, A0 ; `m43f.R`) : *actuel* : `nombre_dossiers` 2 ; *après* : 0.
- **E9** : rangée `ensemble` d'un dossier rattaché à A par un écart et non déterminé par un autre : rattaché (disjonction).
- **E10** : batterie (d) du critère 6.

Critère 4 du § 4.6 inchangé ; le critère 1 (recalcul indépendant par jointure sur le registre) se lit avec le rattachement à A.

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
3. **Visibilité non déterminée par un refus de valeur** (M204). Une ligne de `vue$visibilite_non_determinee` de motif `R` arrête, avec ce motif, les postes qui lisent sa table ou une descendante à l'arrêté ; aucune déclaration ne la lève (dict. § 1.10) avant un traitement `X` du dictionnaire `1.6` (§ 7, point 6). Limite assumée : en B2, aucun arrêt de ce type n'est levé tant qu'aucun traitement `X` n'existe. La forme de l'arrêt dans le bilan est à décider au plan de B2.

## 7. Points notés pour le dictionnaire `1.6`

1. **D07 (c)** : remplacer « a dépassé `age_limite` » (dict. :755) par un renvoi à la règle de limite déclarée (`conventions$limite_age`, § 5.3), et préciser au § 5 (dict. :640, :643) que la lecture de `age_limite` est cette règle.
2. **D10 (a)** : portée table de la table fille (`dossiers`, `rentes`, `prestations`), à écrire au § 1.10 ou au § 9 (dict. :758).
3. **Colonne `traitement` (`R`, `S`)** au tableau des codes du § 1.10 et dans `controles.csv` (proposition d'ADR 0010, sixième série, (a), :297), qui rend explicite le `S` de `somme_parts`.
4. **Question 4.9** : écrire au § 1.10 qu'aucune exclusion `X` d'une valeur illisible ou hors domaine n'est admise en v1 (dict. :154-155).
5. **Âge** : au § 1.5 (dict. :109), renvoyer aux conventions fermées de la présente spécification, sans les recopier.
6. **Traitement `X` des dates de visibilité manquantes** (point P18, M203) : soit étendre D03g aux dates de saisie de visibilité hors liste (`dossiers.date_ouverture`, `catastrophes.date_saisie`, `victimes.date_saisie`), soit créer un défaut « date d'effet de visibilité manquante » (`contrats.date_effet`, `garanties_souscrites.date_effet`, `prestations.date_reglement`, `cotisations.date_mouvement`) traité `X`. Les valeurs hors domaine restent `R` (question 4.9, M151). Ce point porte l'exigence X de l'issue #33, hors de la branche `claude/donnees-controles`.

Les points P6 à P17 du commentaire d'errata de la PR #29 complètent cette liste. Ils ne sont pas décidés, sauf P12 (code dédié au refus né d'une règle P empêchée, décidé par le mainteneur le 8 novembre 2026), et ne sont pas intégrés à la présente version. Le point P18 est le point 6 ci-dessus.
