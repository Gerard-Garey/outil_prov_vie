# Projet de dictionnaire de la base brute fictive : version `1.6`

> *Rédigé par l'agent actuary-approfondi (IA) le 12 novembre 2026, sur la branche de documents seuls `claude/dictionnaire-1-6` (PR #103 ; `docs/feuille-de-route.md`, § 1.10 ; ADR 0012, point 4 ; M299, M500). Squelette posé par la session de la branche le même jour. Lecture de l'art. 143-3 du règlement ANC 2015-11 par l'agent regulatory (IA) le 12 novembre 2026, reprise au § 6 ; lecture de la loi n° 89-1009, art. 2, 7, 7-1 et 10, par le même agent le même jour, reprise au § 1.2 et au § 9. Reprise du § 1.2 par l'agent actuary (IA) le même jour. Statut : **projet visé** par le mainteneur le 12 novembre 2026 (M516, `docs/feuille-de-route.md`, § 4.3), réponses Q1 à Q14 consignées en M501 à M514.*

## 0. Objet, portée, statut

Ce document est le **projet** de la version `1.6` du dictionnaire de la base brute fictive. Le texte visé reste `docs/specifications/dictionnaire-base-v1.md`, en version `1.5`, visée le 8 novembre 2026 (M146). La transcription du projet visé revient à la branche de code Bdr-b2 (`docs/feuille-de-route.md`, § 2). Elle porte sur trois emplacements : le texte du dictionnaire, sa forme lisible par machine (`inst/extdata/dictionnaire/`) et la constante `VERSION_DICTIONNAIRE_ATTENDUE`.

Le projet spécifie, **sans les fermer**, les issues #60, #72, #81, #83, #90 et #32 (point 2). Il fixe aussi la forme de la valeur de chaque hypothèse `H` du § 9, dont #99 a besoin.

Pour chaque point, il donne :

1. la règle proposée pour la `1.6` ;
2. le texte de la `1.5` qu'elle remplace (section et ligne) ;
3. le traitement déclaré de chaque défaut touché ;
4. l'effet attendu sur les dix couples de référence.

Cet effet est une **prévision** d'`actuary`, à remesurer par Bdr-b2 sur le code. Elle n'ouvre ici aucun visa de résultat.

**Numéros de ligne.** Ils renvoient à `docs/specifications/dictionnaire-base-v1.md` dans le dépôt à `d2aa8ca` (abrégé « dict. :NNN »). Chacun a été vérifié par `sed -n 'NNNp'`.

**Mesures.** Elles ont été prises dans les conditions suivantes :

- R 4.3.3 et `provie` 0.5.0, installé depuis la tête `d2aa8ca` de la branche dans une bibliothèque du scratchpad. Le code y est identique à `main` `7d53a05` : `git diff --stat 7d53a05 d2aa8ca` ne touche que deux fichiers de `docs/`.
- Les couples sont construits par `entrees_couple()` et `calculer_couple()` de `tests/references.R`.
- Les scripts ne sont pas versés au dépôt : `couples2.R`, `j34.R`, `j3b.R`, `masq.R` et `d03h.R`.

**Statut des affirmations.** « Mesuré » signifie qu'une commande a été exécutée et que sa sortie est citée. « Prévision » désigne un jugement d'expert sur un code qui n'existe pas encore.

**Couples de référence** (`COUPLES_REFERENCE`, `tests/references.R:18-28`) :

| Couple | Données | Plan | Arrêté | Extraction (mesurée) |
|---|---|---|---|---|
| J1 | `v1-modeste-01` | `recommandees` | 2025-12-31 | 2025-12-31 |
| J2 | `v1-modeste-01` | `recommandees` | 2024-12-31 | 2025-12-31 |
| J3 | `v1-modeste-02` | `recommandees` | 2025-12-31 | 2025-12-31 |
| J4 | `v1-modeste-02` | `recommandees` | 2024-12-31 | 2025-12-31 |
| C1 | `construite-deces-01` | `recommandees` | 2025-12-31 | 2026-03-31 |
| C2 | `construite-deces-01` | `recommandees` | 2025-01-01 | 2026-03-31 |
| C3 | `construite-deces-01` | `alternatives` | 2025-12-31 | 2026-03-31 |
| C4 | `construite-deces-01` | `alternatives` | 2025-01-01 | 2026-03-31 |
| V1 | `v1-modeste-03` | `recommandees` | 2025-12-31 | 2025-12-31 |
| V2 | `v1-modeste-03` | `recommandees` | 2024-12-31 | 2025-12-31 |

**État mesuré des couples** (`Rscript couples2.R`, cellules `deces`, `comptes_sociaux`, segment `ensemble`) :

| Couple | P1 (`sinistres_declares_non_regles`) | P2 (`capitaux_non_reclames`) | P3 (`provision_mathematique_temporaire_deces`) | Total | Bilan (hors `controles_non_executes`) |
|---|---|---|---|---|---|
| J1, J2 | 0 `exact` | 0 `exact` | 0 `exact` | 0 `exact` | vide |
| J3 | arrêté, motif `D09` | arrêté, motif `D09` | 0 `exact` | arrêté (`poste_arrete:capitaux_non_reclames;sinistres_declares_non_regles`) | `refus_tables` : 1 rangée (`prestations.montant`, D09, portée `colonne`, `PR00010`) ; 14 rangées de `controles` ; 12 d'`exclusions` ; 6 d'`hypotheses_defaut` ; 7 de `signalements` ; 94 d'`enjeu` |
| J4 | comme J3 | comme J3 | 0 `exact` | comme J3 | mêmes tables ; 10 rangées d'`hypotheses_defaut` (D02b et D03g placées à A < extraction) |
| C1 | 337 225,959 `jugement_expert` | 103 936,000 `exact` | 4 275,986 `approximation_numerique` | 445 437,945 | vide |
| C2 | 369 590,875 | 101 506,674 | 8 038,564 | 479 136,113 | vide |
| C3 | 337 891,172 | 127 666,837 | 4 373,431 | 469 931,440 | vide |
| C4 | 370 319,931 | 127 667,033 | 8 132,198 | 506 119,162 | vide |
| V1 | 541 440,1 `exact` | 552 375,5 `exact` | 559 589,7 | 1 653 405,3 | vide |
| V2 | 307 559,8 `exact` | 277 261,5 `exact` | 618 617,3 | 1 203 438,6 | vide |

Dans les dix couples, `controles_non_executes` porte la rangée `D03h garanties_souscrites NA non_lisible` (mesuré : 10 occurrences sur 10) et les rangées `non_implemente` du report de #34.

Ces montants sont recopiés de la sortie pour situer les couples. Les références font foi (`tests/reference/`) : la comparaison se fait par la batterie de reproductibilité, non par ce tableau.

## 1. #60 : points P6 à P18 de l'errata ; code du refus né d'une règle P empêchée (M182)

Les points P6 à P17 viennent du commentaire d'errata de la PR #29 (« B. Points pour le dictionnaire `1.6` »), lu le 12 novembre 2026. P18 est le point 6 du § 7 de la spécification du module `donnees` (`docs/specifications/module-donnees-v1.md:898`, M203).

Les points 1 à 4 du même § 7 (`module-donnees-v1.md:893-897`) sont aussi des points notés pour la `1.6`. Je les rattache à #60, hors de la lettre de l'issue ; c'est à confirmer (question Q12). Le point 5 relève du § 6 (#32).

### 1.1 P12 et M182 : code dédié au refus né d'une règle P empêchée

- **Règle.** Nouveau code de contrôle de structure **`vue_empechee`**, dans la liste fermée du § 1.10 et dans `controles.csv`.
  - *Objet* : à un arrêté antérieur à l'extraction, la table dont la vue ne se construit pas parce qu'une colonne lue par la vue est illisible par sa forme (`colonne_absente`, `colonne_inconnue`, `type_incompatible`). Une colonne lue par la vue est une colonne de visibilité de la ligne (§ 6) ou une colonne lue par une règle P (D02b, D03g).
  - *Origine enregistrée* : la colonne « table.colonne ».
  - *Détection* : exacte. *Portée* : table. *Traitement* : `R`.
  - *Propagation* : le refus se propage aux tables filles par `refus_induit`, d'origine la table refusée.
  - `refus_induit` reprend son seul sens du § 1.10 : table dont une clé étrangère vise une table refusée.
  - À un arrêté égal à l'extraction, la vue est totale : `vue_empechee` n'est jamais produit.
- **Remplace.**
  - dict. :180 (`refus_induit` : « Table dont une clé étrangère vise une table refusée ; l'origine est enregistrée ») : texte inchangé, mais il ne couvre plus le refus né d'une règle P.
  - Ajout d'une rangée au tableau du § 1.10 (dict. :170-181), après `refus_induit`.
  - Dans la spécification du module `donnees`, l'emploi de `refus_induit` avec une origine « table.colonne » (`module-donnees-v1.md:231`, `:525`) est à aligner par Bdr-b2 ; ce fichier est hors de la présente branche.
- **Traitement.** Refus `R` de portée table. Aucune déclaration ne le lève. Il arrête les postes qui lisent la table et ses filles. Dans la priorité des causes (`module-donnees-v1.md:576`), `vue_empechee` prend le rang de `refus_induit` quand il est la seule cause. C'est un jugement d'expert : la cause n'est pas une donnée de la ligne mais l'impossibilité de construire la vue.
- **Effet attendu.** Aucun couple, mesuré : `refus_tables` ne porte aucune rangée `refus_induit` dans les dix couples. Sa seule rangée est la rangée D09 de J3 et de J4.

### 1.2 P6 : colonne `maintien_deces` (D03h exécutable sur un contrat collectif)

- **Règle.** Nouvelle colonne de T4 `garanties_souscrites` :
  - `maintien_deces`, `logical`, Obl. `C`, Saisie `E`, Défauts `—` ;
  - domaine : « la garantie `deces` de ce contrat collectif comporte une clause de maintien de la garantie décès en cas d'incapacité de travail ou d'invalidité, imposée par la loi n° 89-1009, art. 7-1 (salariés garantis collectivement dans les conditions de son art. 2, régime couvrant les risques décès, incapacité de travail et invalidité, en un ou plusieurs contrats, chez cet organisme d'assurance ou un autre) ou stipulée par le contrat ; requise pour `deces` d'un contrat collectif, manquante ailleurs ».

  Règle `C` (dict. :121) : un manquant sur la garantie `deces` d'un contrat collectif est un refus `manquant_obligatoire` ; une valeur présente ailleurs (contrat individuel, autre garantie) est un refus `hors_domaine`.

  D03h devient exécutable sur un contrat collectif. Il vise la garantie `deces` d'un contrat collectif à `maintien_deces` = `TRUE` et à `taux_technique_tarif` manquant. La rangée `D03h … non_lisible` disparaît.

  Sur la garantie `deces` d'un contrat collectif à `maintien_deces` = `FALSE`, `taux_technique_tarif` est hors condition. Une valeur présente y est donc `hors_domaine` (dict. :121), comme pour l'arrêt de travail. Le code l'admet aujourd'hui, faute de colonne (`R/donnees.R:1681-1683`) : Bdr-b2 retire cette admission.

  La colonne déclare l'existence de la clause, non sa portée. Le point ouvert P9 du dictionnaire (dict. :815 ; #14, point 4 ; distinct du point P9 de l'errata, § 1.4) reste ouvert, hors de la présente branche. Il porte sur la portée du maintien et de sa provision : « Cet engagement » de l'art. 7-1, al. 2, vise-t-il tout le maintien ou le seul engagement postérieur à la résiliation ? Il ne conditionne pas la colonne : sous l'une ou l'autre lecture, la clause existe ou non au contrat, et D03h se lit de même.
- **Remplace.**
  - dict. :337 (`taux_technique_tarif`) : « pour la garantie `deces` d'un contrat collectif qui porte le maintien de la garantie décès (portée du maintien : P9) » devient « pour la garantie `deces` d'un contrat collectif dont `maintien_deces` vaut `TRUE` » ;
  - ajout d'une ligne à T4 après dict. :344 (`clause_type_beneficiaire`) ;
  - § 8, ligne « Maintien de la garantie décès » (dict. :709) : ajout de `garanties_souscrites.maintien_deces`, lue comme condition d'existence de l'engagement de maintien ; la mention « portée : P9 » y demeure ;
  - § 11, P9 (dict. :815), colonne « État » : ajout de « l'existence de la clause est une donnée de la base (`garanties_souscrites.maintien_deces`, version `1.6`) ; sa portée reste ouverte » ;
  - dict. :315 : inchangé ;
  - annexe A : sans objet, la colonne est propre à la v1.
- **Traitement.**
  - D03h inchangé : `H`, taux du tarif retenu égal à la valeur déclarée (§ 7).
  - `maintien_deces` manquant sous sa condition : refus `R` `manquant_obligatoire`, de portée ligne pour le calcul (§ 2, M507). Aucune déclaration ne le lève.
  - Jugement d'expert. Motif : l'existence de la clause est un fait contractuel. Aucune hypothèse par défaut ne vaut dans les deux référentiels : `TRUE` serait prudent en comptes sociaux, et la meilleure estimation n'a pas de valeur centrale fondée sans le contrat. Alternative écartée : un défaut nouveau traité `H`, sans intensité au simulateur ni poste qui le lise en `1.6`. Effet chiffré de l'écart : nul sur les dix couples, aucune base n'ayant de manquant (simulateur sans défaut sur la colonne).
- **Condition levée.** Lecture de `regulatory` du 12 novembre 2026 : loi n° 89-1009, art. 2, 7, 7-1 et 10. Statut `revue requise`, lecture indirecte de Légifrance (§ 9). Elle conclut :
  - l'art. 7-1, al. 1, 1re phrase, n'impose la clause qu'aux salariés garantis collectivement dans les conditions de l'art. 2, quand le régime couvre les risques décès, incapacité de travail et invalidité ;
  - une garantie `deces` collective sans clause est donc conforme, et une clause peut aussi être stipulée sans obligation : la colonne déclarée est fondée ;
  - une règle déduite de la présence de `incapacite` ou d'`invalidite` au même contrat ne serait pas conforme comme règle unique. Le texte admet « un ou de plusieurs contrats », donc un autre organisme d'assurance, et une clause stipulée est invisible dans la base.

  Point d'arrêt A1 levé (§ 10.1 ; M502).
- **Effet attendu.**
  - Prévision, fondée sur une mesure : les quatre bases portent toutes leurs garanties `deces` collectives avec `taux_technique_tarif` manquant. Mesuré par `Rscript d03h.R` : `v1-modeste-01` 5 sur 5, `v1-modeste-02` 5 sur 5, `construite-deces-01` 1 sur 1, `v1-modeste-03` 6 sur 6.
  - Avec `maintien_deces` = `FALSE` dans les quatre bases (M502), D03h n'est détecté nulle part : aucune provision ni aucun verdict ne change. Dans les dix couples, la rangée `D03h … non_lisible` de `controles_non_executes` disparaît et l'empreinte `empreintes/donnees/garanties_souscrites` de la fiche change. Visa : `actuary`.
  - Réserve sur la loi vraie (constat mesuré, sans effet en `1.6`) :
    - dans les trois jeux, chaque contrat collectif qui porte `deces` porte aussi `incapacite` et `invalidite` (5 sur 5, 5 sur 5, 6 sur 6), et aucun n'est résilié ; la base construite ne porte que `deces` (`GSC1`) ;
    - le simulateur ouvre un sinistre décès quand l'assuré meurt pendant son arrêt (`R/simulation.R:697-701`) ; la vérité des jeux contient 2, 2 et 1 flux de décès futurs issus d'un arrêt (`verite/flux_futurs.csv`, `id_sinistre_origine` renseigné) ;
    - sous la lecture « tous les arrêts » du point ouvert P9, ces flux relèvent du maintien et contredisent `FALSE` ; sous la lecture « après résiliation seulement », ils relèvent de la garantie en vigueur ;
    - aucun poste ne valorise le maintien en `1.6`, d'où l'absence d'effet ; à régler avant ce poste (§ 10.3, Q14).
  - Contrôle de cohérence (facultatif, suggéré par `regulatory`, hors de la règle) : signaler sans refuser une garantie `deces` collective à `FALSE` quand le même contrat porte `incapacite` et `invalidite`. Il n'est pas intégré à la règle : décision au mainteneur (§ 10.3, Q13).

### 1.3 P7 et P8 : grammaire des traitements de `defauts.csv` ; sous-cas de D10

- **Règle proposée.** `defauts.csv` reçoit deux colonnes (forme de l'ADR 0010, point 23, à annoter par `architect`) et une ligne par sous-cas lettré.
  - `signalement` : nature du `S` de la ligne. Valeurs :
    - `aucun` ;
    - `alternatif` (`S` déclarable par référentiel, valeur réservée `signalement` de `hypotheses`) ;
    - `cumulatif` (`S` automatique, en plus de `X` ou de `H`) ;
    - `famille:<famille>` (`S` réservé à une famille de calcul qui ne lit pas la colonne) ;
    - `extraction` (`S` à l'arrêté égal à l'extraction seulement).
  - `parent` : code du défaut parent pour un sous-cas (`D10` pour `D10a`…), vide sinon.
  - Lignes des sous-cas `D10a`, `D10b`, `D10c`, `D10d`, `D10e`, `D10f`, `D10h`, avec leurs traitements :

    | Sous-cas | `traitements` | `signalement` |
    |---|---|---|
    | `D10a` | `R` | `aucun` |
    | `D10b` | `S;X` | `cumulatif` |
    | `D10c` | `S` | `aucun` |
    | `D10d` | `S` | `aucun` |
    | `D10e` | `X` | `aucun` |
    | `D10f` | `H;S` | `alternatif` |
    | `D10h` | `R` | `aucun` |

  - La ligne `D10` reste, en défaut parent. Les listes du code `.MOTIFS_SIGNALEMENT`, `.EXCEPTIONS_FAMILLE` et `.TRAITEMENTS_SOUS_CAS_D10` (`R/donnees.R:139`, `:155`, `:159`) s'en dérivent, ce qui supprime trois listes tenues à la main.
  - Valeurs de `signalement` par code :
    - `alternatif` : D05, D06, D07, D08, D13, D14 ;
    - `cumulatif` : D01b, D02c, D09 ;
    - `famille:triangle` : D03a, D12 ;
    - `extraction` : D02b, D03g ;
    - `aucun` : les autres.
  - D07, D02c et D09 ont des sous-cas de traitements différents mais ne sont pas lettrés. Ils gardent une ligne, dont la colonne `traitements` s'écrit pour le code entier : D07 `X;H;S` alternatif, D02c `R;X;S` cumulatif. Leur lettrage n'est pas proposé (jugement : aucun code du bilan ne les distingue aujourd'hui).
  - « Colonnes lues par règle » (« LUES » dans P8) : **non** reprises au dictionnaire. Elles décrivent l'implémentation d'une règle, non la base ; leur concordance relève d'un script (règle 7 des workflows).
- **Remplace.**
  - dict. :797 (description de `defauts.csv`) ;
  - dict. :736-762 (tableau du § 9) : ajout d'une colonne « Signalement », et pour D10 une ligne par sous-cas à la place de la cellule unique (dict. :758) ;
  - les lettres et la phrase sur (g) sont conservées.
- **Traitement.** Inchangé. C'est un changement de forme, sans changement de traitement admis (vérifié contre `.TRAITEMENTS_SOUS_CAS_D10`, `R/donnees.R:159-160`).
- **Effet attendu.** Prévision : aucune cellule de résultat, si les listes dérivées égalent les listes actuelles (critère d'acceptation : égalité testée). L'empreinte de `defauts.csv` change (`dictionnaire.txt`), mais la fiche n'en porte pas : seule `versions/dictionnaire` y figure (`fiche.txt:118`).

### 1.4 P9, P10, P11, P15 : alignements du texte sur les décisions D4, D9, D11 et sur E23

| Point | Règle (texte proposé) | Remplace | Traitement |
|---|---|---|---|
| P9 | § 1.10, ligne `S`, colonne « Déclaration du plan » : « Aucune, sauf pour un motif à signalement `alternatif` (§ 9), où le signalement se déclare par référentiel sous la valeur réservée `signalement` de `hypotheses`, seule ligne de son couple (motif, référentiel) » | dict. :157 (« Aucune. ») | inchangé (D4) |
| P10 | § 9, D03g : « pour un arrêté antérieur : **H** (ligne entière et partie de ligne : visibilité = max(date d'effet + délai, visibilité de la parente), délai par table dans `seuils$d03g_delai_jours`) ; **X** (`exclure` seul, quatre familles) pour les seules lignes entières ; `X` et `H` déclarables ensemble (`X` pour les lignes entières, `H` pour les parties de ligne) ; une partie de ligne n'admet que `H` » | dict. :749, cellule « Traitement » | inchangé (D9, D11) |
| P11 | § 9, D02b et D03g : « `H` déclaré au poste `tous`, avec la même valeur pour les deux référentiels ; `S` jamais déclarable (signalement automatique à l'extraction) » | dict. :741 et :749 | inchangé |
| P15 | § 9, D01b : « **S** + **X** par table et par famille : deux constats de même clé, le signalement dans tous les cas, l'exclusion déclarable » | dict. :739 (« **X** par table et par famille ; signalé dans tous les cas ») | inchangé (E23) |

- **Effet attendu.** Aucun : texte aligné sur le comportement du code en vigueur. Les bilans de J3 et de J4 portent déjà D01b en `controles` (deux rangées) et en `signalements` (mesuré).

### 1.5 P13 : noms des seuils au § 9

- **Règle.** Ajout d'une règle commune au § 9 : « Seuils déclarés (`plan$donnees$seuils`), sans valeur par défaut, communs aux deux référentiels :
  - `d03g_delai_jours`, liste nommée par table de D03g (jours, entier ≥ 0) ;
  - `d02c_age_min` et `d02c_age_max`, listes nommées par emploi : `assures_sinistre`, `assures_affiliation`, `famille`, `designations`, `ayants_droit_sante` (années, entiers). »
  
  Les seuils de D09 et le nombre de mois de D07 (b) viendront avec leurs contrôles (#34).
- **Remplace.** Ajout après dict. :734. Dans D02c (dict. :742), « bornes de vraisemblance **déclarées dans le plan** » devient un renvoi aux noms de seuils. Dans D03g (dict. :749), « délai déclaré » devient un renvoi à `d03g_delai_jours`.
- **Traitement.** Inchangé.
- **Effet attendu.** Aucun. Les noms sont ceux du code et des plans de référence (`tests/references.R:85-86`, `tests/jeux_v1.R:134-140`).

### 1.6 P14 : D04a « ou dossier sans sinistre »

- **Règle.** D04a ne couvre que la prestation dont `prestations.id_dossier` manque ou vise un dossier absent. Un dossier sans sinistre relève de D04b, en `R` sur `dossiers` : clé étrangère orpheline, refus de portée table.
- **Remplace.** dict. :751, « ou dossier sans sinistre » retiré. Dans `defauts.csv`, `D04a.tables` passe de `dossiers;prestations` à `prestations` (mesuré par lecture du CSV).
- **Traitement.** Inchangé dans les faits : `R` par D04b, comme le code le fait déjà (avis d'`actuary` de (ii-a) cité par P14).
- **Effet attendu.** Aucun : aucun couple ne porte D04a (bilans mesurés).

### 1.7 P16 et § 7, point 1 : D07

- **Règle.**
  - D07 (c) : « rente d'éducation en service, ou dossier `double_effet` ni clos ni de second décès retenu à A, dont **chaque** enfant à charge a atteint sa limite selon la règle déclarée `conventions$limite_age` (règle `atteinte` ou `depassement`, âge `revolu` ou `millesime`) appliquée à `age_limite`, ou à `age_limite_etudes` si `situation` ∈ {`scolarise`, `apprenti`}, hors `prolongation_handicap` avec `situation` = `handicape` ».
  - § 5 : la lecture de `age_limite` (`rente_education`, `double_effet`) est la règle `conventions$limite_age`.
  - `defauts.csv`, `D07.tables` devient `evenements;rentes;dossiers`.
- **Remplace.** dict. :755 (« dont le plus jeune enfant à charge a dépassé `age_limite` (ou `age_limite_etudes` s'il est justifié) ») ; dict. :640 et :643, colonne « Unité », avec ajout du renvoi.
- **Traitement.** Inchangé : (a) `H` ou `S` ; (b) `S` ou `X` ; (c) `H` ou `S`.
- **Effet attendu.** Aucun : D07 n'est pas implémenté (rangée `non_implemente`, mesurée dans les dix couples).

### 1.8 P17 et § 7, point 3 : colonne `traitement` de `controles.csv`

- **Règle.** Une colonne « Traitement » au tableau des codes du § 1.10 et dans `controles.csv` : `R` pour tous les codes, `S` pour `somme_parts`, `R` pour `vue_empechee` (§ 1.1) et `S` pour `parente_posterieure` (§ 4).
- **Remplace.** dict. :170-181 (en-tête et rangées) ; dict. :799.
- **Effet attendu.** Aucun sur un résultat. Changement de forme de `controles.csv`, à annoter dans l'ADR 0010.

### 1.9 P18 (§ 7, point 6 ; M203) : traitement `X` des dates de visibilité manquantes

- **Règle proposée**, combinaison des deux options du § 7.
  - **(a) D03g étendu** aux dates qui valent date de saisie : `dossiers.date_ouverture`, `catastrophes.date_saisie`, `victimes.date_saisie`. Traitements : ceux de D03g (S à l'extraction ; H ou X avant). Sous `H`, la date d'effet d'une ligne fille est la visibilité de sa parente : pour un dossier, son sinistre ; pour une victime, sa catastrophe. Pour `catastrophes`, la date d'effet est `date_evenement`, comparée par D02b. Le délai est déclaré par table dans `d03g_delai_jours`.
  - **(b) Défaut nouveau D03i** « Date d'effet de visibilité manquante » :
    - colonnes : `contrats.date_effet`, `garanties_souscrites.date_effet`, `prestations.date_reglement`, `cotisations.date_mouvement` ;
    - détection : exacte ;
    - traitement : **X** par famille (`exclure` ou `conserver`) **à tout arrêté**, puisque la date est aussi une valeur lue par les postes, et pas seulement une date de visibilité ;
    - sous `conserver`, à A < extraction, la ligne est de visibilité non déterminée (règle 3 du § 6 de la spécification du module `donnees`, `module-donnees-v1.md:889`). À A = extraction, la ligne est visible et sa date est inconnue des postes, qui suivent la lecture de Kleene ;
    - intensité : `manquant_date_effet`.
  - Les valeurs hors domaine de ces colonnes restent `R` (question 4.9, M151 ; § 1.10 ci-dessous).
- **Remplace.**
  - dict. :749 (D03g, liste des tables) ;
  - ajout d'une ligne D03i après dict. :750 ;
  - colonne « Défauts » de dict. :303 (`contrats.date_effet` : `D02a, D02c`, plus `D03i`), :327, :452, :505, :523, :532, :547 ;
  - « Écarts à la liste d'E2.4 », dict. :764-771 : une ligne pour D03i.
- **Motif** (jugement d'expert). Les trois dates de saisie ont la sémantique de D03g, avec la même règle `H`. Les quatre dates d'effet sont des faits, lus par les postes (effet du contrat, version en vigueur, date de règlement, date du mouvement). Une hypothèse de date y serait un modèle que rien ne fonde. L'exclusion déclarée est le seul traitement qui ne fabrique pas de valeur.
- **Alternative écartée.** Un seul défaut pour les sept colonnes : il mêlerait une règle `H` admissible et une règle `H` sans fondement.
- **Effet attendu.** Aucun couple, mesuré : aucun `manquant_obligatoire` dans les bilans. La loi vraie des jeux doit déclarer l'intensité nouvelle (sans valeur par défaut), donc `loi_vraie.txt` des jeux change, mais les jeux sont de toute façon retirés en `1.6` (§ 8).

### 1.10 Points 2 et 4 du § 7 de la spécification du module `donnees` (rattachés à #60, à confirmer : Q12)

- **D10 (a), portée** (point 2). Ajout au § 1.10, portée d'un refus `R` (après dict. :163) : « D10 (a) et D10 (h) : portée **table** de la table fille qui porte l'incompatibilité (`dossiers`, `rentes`, `prestations`, `victimes`) ». Effet : aucun. Aucun couple ne porte D10.
- **Question 4.9** (point 4). Ajout au § 1.10, ligne `X` (dict. :155) : « Aucune exclusion `X` d'une valeur illisible ou hors domaine n'est admise en v1 : ces valeurs relèvent de `R`. D03i et D03g portent sur des **manquants**. » Effet : aucun.

### 1.11 Version

- **Règle.** La version `1.6` remplace la `1.5` à trois endroits :
  - l'en-tête (dict. :3-11, ligne d'historique `1.6`) ;
  - la ligne de version (dict. :13 : « Version du dictionnaire : `1.5` ») ;
  - le domaine de `extraction.version_dictionnaire` (dict. :282 : « `1.5` (version d'un autre dictionnaire : refus) »).
  
  `VERSION_DICTIONNAIRE_ATTENDUE` (`R/outils.R:15`) passe à `"1.6"` (Bdr-b2).
- **Effet attendu** (mesuré pour la présence des feuilles) : les dix fiches portent `versions/dictionnaire = 1.5` (`fiche.txt:118` de C1), feuille hors des exclusions de comparaison (`EXCLUSIONS_FICHE`, `tests/references.R:37`). Les données portent `extraction.version_dictionnaire`, donc `empreintes/donnees/extraction` change dans les dix fiches. Il faut régénérer tous les couples et renommer les jeux et la base construite (ADR 0011, point 22).

## 2. #72 : portée d'un refus de valeur hors de la vue

- **Constat** (mesuré, `Rscript j34.R`). Dans J3 et J4, la seule rangée de `refus_tables` est `prestations.montant`, motif D09, portée `colonne`, sur la ligne `PR00010`. Cette ligne est une `indemnite_journaliere` de −487,92 € du dossier `DO0014`, garantie `GS005`, `incapacite`. Elle arrête P1 et P2 du capital décès, qui ne lisent aucune prestation d'un dossier `incapacite`.
- **Règle proposée (option (i), recommandée).** Un refus de valeur identifié par ligne est de **portée ligne** pour le calcul comme pour la vue, quelle que soit la colonne :
  - codes concernés : `manquant_obligatoire`, `hors_domaine`, `chaine_vide`, D02c (date hors bornes), D09 (signe), tout refus `R` de colonne ordinaire dont le constat désigne des lignes ;
  - la valeur refusée est inconnue sur sa seule ligne ;
  - un poste est arrêté, avec le motif du refus et l'identifiant de l'unité, si et seulement si deux conditions sont réunies :
    - (1) il lit la colonne (`lectures.csv`) ;
    - (2) au moins une ligne refusée est lue pour une de ses unités (rattachée par des clés connues ; liste des lignes lues par unité : spécification de B2, § 5.8), ou son rattachement à une unité n'est pas déterminé (lecture de Kleene : rattachement qui dépend d'une valeur inconnue) ;
  - sinon le poste est calculé, et le refus reste au bilan ;
  - dans `refus_tables`, `portee` vaut `ligne` et `postes_arretes` liste les seuls postes arrêtés (vide si aucun) ;
  - une composante de l'enjeu n'est `NA` (cause = motif du refus) que si elle lit une **valeur** refusée, et non plus dès qu'elle lit la **colonne** ;
  - les règles B et V qui lisent la colonne restent non exécutées, cause = motif du refus (E3 inchangé).
  
  Restent de portée colonne ou table :
  - les défauts de forme (`type_incompatible`, `colonne_absente`, `colonne_inconnue`), dont le constat ne désigne pas de lignes ;
  - les colonnes de clé (portée table, inchangée) ;
  - `vue_empechee` (§ 1.1).
- **Option (ii) (variante).** Les mêmes règles, et en plus les règles V qui lisent la colonne s'exécutent sur les lignes lisibles en logique de Kleene, comme la vue depuis M200. C'est plus cohérent, mais cela change le contenu du bilan de J3 et de J4 : les rangées `D01b prestations` et `prestations_ecartees` de `controles_non_executes`, de cause `D09`, deviendraient des détections ou des non-détections. Le code de `.regle()` est à étendre. Je la renvoie à une issue (Q7).
- **Remplace.**
  - dict. :162 (« refus sur une colonne ordinaire (type, domaine, manquant `O` hors du § 9, valeur `C` hors condition) : portée **colonne** ; seuls les postes qui lisent la colonne sont arrêtés ») ;
  - dict. :154, colonne « Sans déclaration » (« Arrêt des postes qui lisent la table ou la colonne ») ;
  - dict. :174-177, colonne « Portée » : `ligne, ou table pour une colonne de clé` pour `manquant_obligatoire`, `hors_domaine`, `chaine_vide` ; `colonne, ou table pour une colonne de clé` gardé pour `type_incompatible` ; dans `controles.csv`, une nouvelle modalité `ligne_table` ;
  - D09 (dict. :757 : « refus **R** (la ligne est comptée et identifiée ; les postes qui lisent la colonne sont arrêtés) ») : « … les postes dont une unité lit la ligne sont arrêtés ».
- **Traitement.** Refus `R` inchangé : l'extraction reste à reprendre, et aucune déclaration ne le lève. Seule change la portée de l'arrêt. Statut : jugement d'expert. Motif : arrêter un poste dont aucune unité ne lit la valeur refusée affiche un arrêt sans cause dans ce poste. Lire la valeur dans un poste qui en dépend est impossible : l'arrêt s'y maintient.
- **Hors de la lettre de #72, signalé.** La règle 3 du § 6 de la spécification du module `donnees` (`module-donnees-v1.md:889`) arrête « les postes qui lisent sa table ou une descendante ». La même restriction aux unités qui lisent la ligne en serait le pendant pour la vue. Hors couloir (spécification du module `donnees`) : Q7.
- **Effet attendu.**
  - J3 et J4, prévision appuyée sur une mesure substitutive (`Rscript j34.R`). Avec le signe de `PR00010` rétabli, toutes choses égales par ailleurs, P1 = 0 `exact` (0 dossier), P2 = 0 `exact` (0 dossier), P3 = 0 `exact` et le total = 0 `exact`, aux deux arrêtés. Sous la règle, la ligne `PR00010` n'est lue par aucune unité de P1 ou de P2. Ces postes n'ont aucun dossier, et `prestations.montant` n'est pas une colonne de la vue. La prévision est donc le passage de P1, P2 et du total **d'arrêté (`D09`) à 0 `exact`**. Changement de total : **visa du mainteneur** (ADR 0011, point 22).
  - Toujours dans J3 et J4 : la rangée de `refus_tables` change (`portee` `ligne`, `postes_arretes` vide). Sur les 94 rangées d'`enjeu` de J3, 20 ont la cause `D09` (mesuré, `Rscript j3b.R` : 8 du motif D02a, 10 de `ensemble`, 2 de D09, toutes de composante `prestations_ecartees`). Les lignes D02a (`PR00027;PR00039`) ne sont pas `PR00010`. Les 8 rangées D02a et une partie des rangées `ensemble` deviendraient calculées, et les 2 rangées D09 restent `NA` : prévision, à mesurer.
  - J1, J2, C1 à C4, V1, V2 : aucun changement. Aucun refus de valeur n'y figure (mesuré).

## 3. #81 : D11 étendu au collège

- **Préalable.** D11 n'est pas implémenté. Il figure en `non_implemente` dans les dix couples (mesuré) et appartient à #34, dans Bdr-b1, qui fusionne avant Bdr-b2 (§ 2 de la feuille de route). Le projet écrit les sous-cas ; leur code vient après celui de D11 dans Bdr-b1.
- **Règle.** D11 en trois sous-cas lettrés, sur le modèle de D10 (lignes `D11a` à `D11c` de `defauts.csv`, parent `D11`, § 1.3) :
  - **D11a** : sinistre hors période de couverture. Survenance hors de toute affiliation de l'assuré au contrat de la garantie du dossier, ou hors de la couverture d'un contrat individuel. C'est le texte actuel.
  - **D11b** : dossier dont la garantie souscrite porte le couple (`id_contrat`, `college`) alors qu'aucune affiliation de l'assuré à ce contrat **dans ce collège** ne couvre la survenance, et qu'une affiliation au même contrat dans un autre collège la couvre. Table : `dossiers`.
  - **D11c** : deux affiliations d'un même assuré au même contrat, dans deux collèges distincts, dont les périodes de couverture (bornes incluses, § 1.4) se chevauchent. Table : `affiliations`.
  
  La détection est exacte, hors portabilité et hors maintien de la garantie décès, comme aujourd'hui. Intensité : `hors_couverture`, sous-paramètres `college_errone` (D11b) et `affiliations_simultanees` (D11c).
- **Remplace.** dict. :759 (une ligne D11) : trois lignes. Colonne « Défauts » de dict. :387 (`affiliations.college` : `D04b` devient `D04b, D11`) et de dict. :451 (`dossiers.id_garantie_souscrite`, ajout de `D11`).
- **Traitement.** Les trois sous-cas sont traités en **S** + **X** par famille, comme D11 aujourd'hui (dict. :759). Le signalement est automatique, l'exclusion déclarable.
  - Motif D11b : le capital reconstitué lit l'affiliation du collège du dossier, et sans elle P1 s'arrête (`affiliation_non_determinee`, spécification de B2, erratum v1.0.10). L'exclusion permet de chiffrer un enjeu plutôt que d'arrêter.
  - Motif D11c : une affiliation simultanée à deux collèges ne bloque pas P1 si le collège du dossier est déterminé. Le signalement suffit, et l'exclusion reste possible.
  - Jugement d'expert.
- **Effet attendu.** Aucune cellule de provision, mesuré (`Rscript masq.R`, `Rscript j3b.R`) : les dix couples ne connaissent que le collège `ensemble`, et aucun assuré n'y a deux affiliations chevauchantes au même contrat. Une cellule de bilan change selon l'état laissé par Bdr-b1 : la rangée `D11 sinistres date_survenance non_implemente` devient `D11a` (ou disparaît si Bdr-b1 l'a implémentée), et `D11b` et `D11c` s'exécutent sans détection. Prévision.

## 4. #83 : D10b à l'arrêté

- **Règle.**
  - **(1) Règle 1 du § 6, exception pour un parent daté par un attribut `E`.** Une ligne de `dossiers` dont la visibilité propre (`date_ouverture` ≤ A, sinistre visible) tient à A n'est pas masquée par sa garantie souscrite invisible (`date_effet` > A). D10b est évalué sur cette ligne, la garantie souscrite étant lue à sa valeur extraite (`E`, § 1.8). Le traitement de D10b s'applique : `S` + `X`, déclaration exigée.
    - Sous `exclure` : le dossier sort de la famille, avec enjeu.
    - Sous `conserver` : le dossier reste dans la vue, mais sa garantie souscrite, invisible à A, n'est pas lue par les familles. Un poste qui lit ses colonnes est arrêté (`parametre_non_determine`, identifiant du dossier), jamais calculé sur une version invisible à A. C'est l'option (a), recommandée.
  - **(2) Autres lignes masquées.** Ce sont les lignes visibles par elles-mêmes et masquées par la règle 1 parce qu'une ascendante, dont la visibilité est une date d'effet (`contrats.date_effet`, `garanties_souscrites.date_effet`), est postérieure à A : affiliations, versions de garanties, paramètres, cotisations.
    - Elles relèvent du nouveau code de contrôle **`parente_posterieure`** : détection exacte, portée ligne, traitement `S`, sans effet sur la vue.
    - Motif : l'anticipation est souvent un phénomène (affiliation ou cotisation émise avant l'effet du contrat). Le signalement suffit à écarter la correction silencieuse.
  - **(3) D02b étendu** à la paire `prestations` → `dossiers` (`date_saisie` et `date_reglement` de la prestation face à `date_ouverture` du dossier) et à la paire `prestations` → `rentes`. Une prestation saisie ou réglée avant l'ouverture de son dossier est une fille saisie avant sa parente, déjà l'objet de D02b (dict. :741), mais la paire manque à la liste du code (`R/donnees.R:2580-2591`, mesuré par lecture).
- **Remplace.**
  - dict. :684 (« 1. Une ligne fille n'est visible que si sa ligne parente l'est. Une fille saisie avant sa parente relève du défaut D02b, avec son traitement ») : ajout de l'exception (1) et du renvoi au code `parente_posterieure` ;
  - dict. :758 (D10 (b) : « version de garantie hors vigueur à la survenance : **S** + **X** ») : ajout de « évalué aussi sur un dossier visible à A dont la garantie souscrite ne l'est pas (§ 6, règle 1) » ;
  - dict. :741 (D02b, tables) : ajout de `prestations` ;
  - § 1.10 : une rangée pour `parente_posterieure`.
- **Traitement.** D10b `S` + `X` (inchangé) ; `parente_posterieure` `S` ; D02b `H` ou `S` (inchangé).
- **Option (b), écartée.** Sous `conserver`, lire la garantie souscrite à sa valeur extraite pour le calcul. Elle est cohérente avec le calcul à l'extraction, où la version hors vigueur est lue. Je l'écarte parce qu'à A la version n'a pas d'existence connue : sa date d'effet est postérieure. La lire emploierait une information de l'extraction qui n'était pas connue à A. Effet de l'alternative : P1 calculé au lieu d'être arrêté, sur le cas de #83.
- **Effet attendu.** Aucun couple, mesuré (`Rscript masq.R`) : 0 dossier masqué par sa garantie souscrite, 0 version masquée par son contrat, 0 affiliation, 0 cotisation et 0 prestation masquées par leur parente, dans les dix couples. Critère de l'issue : le test en échec attendu (`tests/unitaires/calculer_provisions.R:662-671`) passe, et sa marque est retirée.

## 5. #90 : D02a sous `H`, avec la conclusion de Br

### 5.1 Règle générale

- **Règle.** Sous `H`, chaque date rejetée est **tenue pour inconnue** dans la vue, et non pour « manquante » au sens de sa colonne : jamais pour une fin ouverte, un fait non survenu ou une instruction pendante (§ 1.4). Les autres valeurs de la ligne restent lues. Le traitement qui s'enchaîne est, dans l'ordre :
  - (1) la règle écrite pour la relation (§ 5.2) ;
  - (2) sinon, le traitement **déclaré** du défaut de manquant de la colonne, s'il existe : D03a pour une date de naissance, D03f pour une période ;
  - (3) sinon, la valeur reste inconnue : lecture de Kleene par les familles. Une condition connue décide si elle le peut ; sinon le poste est arrêté (`parametre_non_determine`, ou motif propre à la famille).
  
  La conclusion de Br est reprise sans changement :
  - **les deux bornes** de la période (`debut_periode`, `fin_periode`) de `cotisations` et de `prestations` sont tenues pour manquantes ;
  - D03f s'enchaîne : `H`, règle du dictionnaire aux deux bornes ; `conserver`, arrêt `parametre_non_determine` ; `X`, exclusion. C'est la spécification de B2, erratum v1.0.16, § 5.5, et le commentaire 6824784958 de #90.
- **Où.** Dans la vue (`donnees`), une seule implémentation pour toutes les garanties :
  - la vue expose les dates rejetées comme inconnues ;
  - les lignes rejetées sont placées dans `vue$hypotheses` (motif D02a), ce qui rend applicable la règle S2 de statut (spécification de B2, § 5.8) ;
  - aucune famille ne redétecte D02a ;
  - **la visibilité n'est pas modifiée**, et se calcule sur les dates brutes. Jugement d'expert : D02a dit qu'une date est fausse, non que la ligne était inconnue à A. Alternative écartée : la visibilité non déterminée, qui rendrait la vue provisoire et arrêterait les postes de la table et de ses descendantes (règle 3 du § 6 de la spécification du module `donnees`).
- **Déclaration exigée.** Une ligne dont une date est tenue pour inconnue sous D02a `H` exige la déclaration du défaut de manquant qui s'enchaîne (D03a, D03f), comme une ligne de ce défaut. L'exigence va dans `declarations_requises`, avec D02a pour origine. Les comptes de détection de D03a et de D03f restent ceux de leurs manquants propres : la détection exacte égale toujours le registre du simulateur.

### 5.2 Dates rejetées, par relation (réponse aux questions 1 et 3 de #90)

| N° | Relation de D02a (code : `.regle_v_ordre_dates()`, `R/donnees.R:3256`) | Colonne du constat | Dates tenues pour inconnues | Traitement qui s'enchaîne | Motif |
|---|---|---|---|---|---|
| R1 | `contrats` : `date_effet` > `date_fin` | `date_fin` | les deux | Kleene (aucun défaut de manquant) | règle générale |
| R2 | `contrats` : `date_effet` > `date_terme` | `date_terme` | les deux | Kleene | règle générale |
| R3 | `contrats` : `date_effet` > `date_debut_gestion` | `date_debut_gestion` | les deux | Kleene | règle générale (alternative à Q10 : la seule `date_debut_gestion`) |
| R4 | `garanties_souscrites` : `date_effet` > `date_fin` | `date_fin` | les deux | Kleene | règle générale |
| R5 | `affiliations` : `date_debut` > `date_fin` | `date_fin` | les deux | Kleene | règle générale |
| R6 | `ayants_droit_sante` : `debut_couverture` > `fin_couverture` | `fin_couverture` | les deux | Kleene | règle générale |
| R7 | `prestations`, `cotisations` : `debut_periode` > `fin_periode` (longueur ≤ 0) | `fin_periode` | les deux bornes | D03f | conclusion de Br (règle écrite) |
| R8 | `assures.date_naissance` > `sinistres.date_survenance` | `sinistres.date_survenance` | les deux ; la naissance de l'assuré est inconnue dans toutes ses lectures, car c'est un fait de la personne à source unique (§ 2.2, point 7) | D03a pour la naissance ; Kleene pour la survenance | règle générale |
| R9 | `sinistres` : `date_survenance` > `date_declaration` | `date_declaration` | les deux | Kleene | règle générale |
| R10 | `sinistres` : `date_declaration` > `date_instruction` | `date_instruction` | les deux ; l'instruction inconnue ne vaut pas « non instruit » | Kleene | règle générale |
| R11 | `famille.date_naissance` > survenance du sinistre rattaché (hors `a_naitre`) | `famille.date_naissance` | la seule naissance du membre (**règle écrite**) | D03a | la survenance est la référence de l'instruction, partagée par tous les membres ; la naissance d'un enfant après la survenance est le cas posthume |
| R12 | `evenements` : premier état (`entree_incapacite`, `entree_invalidite`) daté autrement que la survenance | `evenements.date_effet` | la seule date de l'événement (**règle écrite**) | Kleene | T13 définit cette date comme égale à `date_survenance` (dict. :598-599) : la survenance est la source de définition |
| R13 | `evenements` : `mise_a_jour` hors de [survenance, extraction] | `evenements.date_effet` | la seule date de l'événement (**règle écrite**, déjà au § 9) | dernière information valide précédente, à défaut instruction, à défaut survenance | dict. :740, inchangé |

Un `a_naitre` n'est jamais rejeté. Statut du tableau : jugement d'expert, à viser.

### 5.3 Constat connexe : enfant posthume déclaré né (faux positif de R11)

- **Constat.** T8 prévoit qu'un enfant à naître déclaré né reçoive une ligne corrigée de même `id_membre` (dict. :407). Cette ligne porte une naissance postérieure à la survenance et une `situation` autre que `a_naitre`. R11 la détecte en D02a, alors que les données sont justes.
- **Règle proposée.** R11 exclut, en plus de `a_naitre`, la ligne d'un membre dont une version antérieure de même `id_membre` porte `situation` = `a_naitre`.
- **Remplace.** dict. :740 (« hors `situation` = `a_naitre` »).
- **Effet attendu.** Aucun : il n'y a aucun membre `a_naitre` dans les dix couples (mesuré, `Rscript masq.R`).

### 5.4 Texte remplacé, traitement, effet

- **Remplace.** dict. :740, cellule « Traitement » de D02a (« ou **H** : date rejetée tenue pour manquante, puis traitement du manquant (D03a ; pour une mise à jour, dernière information valide précédente, à défaut instruction, à défaut survenance) ; un `a_naitre` n'est jamais rejeté »). Elle devient un renvoi au tableau des relations, porté par une **annexe B nouvelle** du dictionnaire (« D02a sous `H` : dates rejetées par relation »), pour garder régulier le tableau du § 9.
- **Traitement.** D02a reste `X` par famille ou `H`, traitement unique (`.MOTIFS_TRAITEMENT_UNIQUE`). La valeur de `H` est `regle` (§ 7).
- **Effet attendu.**
  - Aucun couple, mesuré : D02a n'est déclarée en `H` dans aucun plan de référence. Les plans de J3 et de J4 la déclarent en `exclusions` (`conserver` pour `engagement`, `risque_en_cours`, `regle_comptable` ; `exclure` pour `triangle`), et C1 à C4, V1, V2, J1, J2 ne portent aucun constat D02a.
  - Le critère de #90 (`tests/unitaires/calculer_provisions.R:646-660`) passe. Sous la règle R9, P2 du cas (h) est arrêté : la survenance et la déclaration sont inconnues, et la reconstitution du capital et sa revalorisation lisent la survenance. `!isTRUE(all.equal(NA, 126906.73…))` est vrai, et la marque d'échec attendu est retirée. Prévision ; le montant n'est pas mesuré.

## 6. #32, point 2 : portée de l'art. 143-3 du règlement ANC 2015-11

- **Lecture de `regulatory`** (12 novembre 2026, statut complet, deux lectures). Elle porte sur le recueil ANC « Secteur de l'assurance », version en vigueur au 1er janvier 2025 : c'est une consolidation, non le JO. SHA-256 `0d7fb3c86e6293e57c4141bf859f926056ba6617bed4794830c83839e9319766` (2 023 712 octets), lue sur le rendu graphique, pages PDF 22 et 23.
  - Texte de l'art. 143-3 (vérifié) : « Pour le calcul de la provision mathématique des rentes mentionné à l'article 143-2 du présent règlement, la date de naissance du rentier est reportée au 31 décembre le plus voisin. Il est tenu compte du fractionnement des rentes et de la non-coïncidence de leur entrée en jouissance avec la date de l'inventaire. »
  - Art. 143-2 (vérifié) : provisions techniques des rentes d'incapacité et d'invalidité issues de contrats couvrant des risques du 3° de l'art. L310-1.
  - Art. 143-12 (vérifié) : il ne renvoie pas à l'art. 143-3.
  - « 31 décembre le plus voisin » n'apparaît qu'à l'art. 143-3 dans le recueil.
  - Verdict sur dict. :109 : **écart, portée trop large**.
- **Texte remplacé.** dict. :109 : « Leur lecture (âge révolu, millésime) est une **convention du plan**, jamais une règle du dictionnaire. Exemple de convention possible pour les rentiers : la date de naissance reportée au 31 décembre le plus voisin (ANC 143-3, rapport de recherche, statut « vérifié ») ». S'y ajoute le point 5 du § 7 de la spécification du module `donnees` (`module-donnees-v1.md:897`) : renvoyer aux conventions fermées sans les recopier.
- **Règle retenue, lecture A** (recommandée par `regulatory`, retenue par le mainteneur le 12 novembre 2026, M501) : « Leur lecture est une **convention du plan** (`conventions$age`, liste fermée de la spécification du module `donnees`, § 5.2), jamais une règle du dictionnaire. Exemple de convention possible pour les rentiers : la date de naissance reportée au 31 décembre le plus voisin. L'art. 143-3 du règlement ANC 2015-11 prescrit ce report pour le seul calcul de la provision mathématique des rentes mentionné à l'art. 143-2 (rentes d'incapacité et d'invalidité issues de contrats couvrant des risques du 3° de l'art. L310-1 du code des assurances). Aucun poste de la v1 n'en relève : son emploi en v1 est une convention retenue par analogie (jugement d'expert, M151). Lecture de `regulatory` sur le recueil ANC « Secteur de l'assurance », version en vigueur au 1er janvier 2025 (SHA-256 `0d7fb3c8…9319766`), 12 novembre 2026. »
  - Le rapport de recherche n'est plus cité. Sa ligne 28 ne dit rien de la limitation (point 1 de #32, hors de la branche).
- **Lecture B** (variante de `regulatory`). Le report vaudrait pour toute provision mathématique des rentes des opérations autres que vie (art. 143-1, R343-7), dans le calcul de l'art. 143-2. Les rentes vie (art. 142-3, 142-4) seraient hors champ. Pour les rentes d'invalidité du 2° (art. 143-12), le rattachement au poste resterait à établir. La phrase serait la même, sauf que « pour le seul calcul … mentionné à l'art. 143-2 » deviendrait « pour la provision mathématique des rentes des opérations autres que vie, dans le calcul mentionné à l'art. 143-2 ».
- **Éclairage d'`actuary`** (pour Q1).
  - (1) La grammaire de A rattache « mentionné » à « calcul », et A est la seule lecture qui n'étend pas un texte d'exception. Elle laisse le choix de la convention au plan, ce qui est l'intention du dictionnaire (dict. :109, « jamais une règle du dictionnaire »).
  - (2) Sous B, pour la v1, les rentes d'invalidité en cours sont rattachées à la PSAP (M83, #14 ; dict. :718) et non à la provision mathématique des rentes. Les rentes de conjoint et d'éducation ont une lecture vie (M84, dict. :710), hors du champ de B. Sous B comme sous A, aucun poste de la v1, **dans ses rattachements actuels**, n'entre dans le champ du report.
  - (3) Mon avis sur le rattachement des rentes d'invalidité du 2° : leur provision est, par nature, une valeur actuelle probable de rentes en service, que les praticiens appellent souvent « provision mathématique des rentes d'invalidité ». Le règlement en fixe les lois à l'art. 143-12, sans renvoyer à l'art. 143-3. Le silence de l'art. 143-12 plaide pour ne pas leur appliquer le report, même sous B. Rouvrir M83 pour ce seul motif n'est pas justifié. C'est un jugement d'expert : je n'ai retrouvé aucune publication de place qui tranche.
  - (4) Sous A comme sous B, M151 et M154 restent valables, et aucun résultat ne change.
- **Traitement des défauts.** Sans objet.
- **Effet attendu.** Aucun. Le texte est seul en cause, `conventions$age` est déjà une déclaration du plan (`tests/references.R:73`), et la constante d'âge du code est inchangée (`R/outils.R:548-553`, cité par `regulatory`).

## 7. Forme de la valeur de chaque hypothèse `H` (§ 9), pour #99

- **Règle commune**, ajoutée aux règles du § 9 après dict. :734 :
  - la `valeur` d'une ligne de `hypotheses` a la forme écrite pour son motif ;
  - `valider_plan()` la contrôle pour toute ligne déclarée, lue ou non, et refuse une autre forme (`plan_invalide`) ;
  - un contenu qui dépend des données, comme un collège absent de la liste de D03c, reste contrôlé à la lecture (`plan_incomplet`), comme dans la spécification de B2 (§ 5.9) ;
  - deux valeurs réservées : `signalement` (motif à signalement `alternatif`, § 1.3) et `regle` (la règle écrite au § 9 s'applique ; ses paramètres, s'il en a, sont déclarés ailleurs dans le plan : `seuils`, paramètres du poste) ;
  - **liste par clé** : `<cle>=<valeur>` joints par « ; », sans espace ; clés distinctes (clé en double : `plan_invalide`) ; ordre libre ;
  - **décimal** : nombre décimal à point, selon l'expression de `.hypothese_d03h()` (`R/risque_en_cours.R:284`) : `^-?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$`.

| Motif | Forme de `valeur` | Lue en v1 par | Source de la forme | Remplace (dict.) |
|---|---|---|---|---|
| D02a | `regle` (§ 5) | la vue, après #90 | ce projet | :740 |
| D02b | `regle` | la vue | ce projet (P11 : même valeur aux deux référentiels, poste `tous`) | :741 |
| D03a | `regle` ; les paramètres (âge par défaut par segment, écart d'âge du conjoint, loi de l'âge du plus jeune enfant) se déclarent dans les paramètres du poste, forme fixée avec #100 (B4) | aucun poste en B2 (spécification de B2, § 5.9, IP6) | ce projet (Q11) | :743 |
| D03b | liste par clé ; clés `assure`, `conjoint` (`lien` ∈ {`conjoint`, `partenaire_pacs`, `concubin`}), `enfant`, `autre` ; valeurs `F`, `M`, et pour `conjoint` aussi `oppose_assure` ou `identique_assure` | aucun en B2 | ce projet (Q11) | :744 |
| D03c | liste par clé `<college>=<montant>`, montant décimal ≥ 0, en euros par an | P1, P2 (Br, #75) | décision E16-1 du mainteneur du 12/11/2026 (spécification de B2, erratum v1.0.16, § 5.9) | :745 |
| D03d | `regle` (structure familiale par défaut : paramètres du poste, comme `structure_familiale` du plan de B2) | aucun en B2 | ce projet | :746 |
| D03e | `cat1`, `cat2` ou `cat3` | aucun en B2 | ce projet | :747 |
| D03f | `regle` | P3 collectif (Br, #92) | spécification de B2, erratum v1.0.16, § 5.5 (#92 Q1) | :748 |
| D03g | `regle` (délai : `seuils$d03g_delai_jours`) | la vue | ce projet | :749 |
| D03h | décimal, dans [−0,05 ; 0,10] (bornes de contrôle de la colonne, dict. :337, jugement d'expert P12) | P3 individuel (B2) | conclusion de #90 (taux décimal) ; bornes proposées par ce projet (Q11) | :750 |
| D05 | liste par clé : `motif` ∈ {`sans_suite`, `refus`} ; `decompte` ∈ {`compte`, `non_compte`} | aucun en B2 | ce projet | :753 |
| D06, D07, D08, D09, D10 (f), D14 | `regle` | aucun en B2 | ce projet | :754, :755, :756, :757, :758, :762 |
| D13 | décimal dans [0 ; 1] (probabilité d'ouverture) | aucun en B2 | ce projet | :761 |

- **Domaine du collège** (conséquence de D03c). T4 `college` (dict. :326) : « code opaque **sans « ; » ni « = »** ». Sinon un collège ne s'écrit pas dans la liste de D03c. Un code qui en contient est hors domaine, donc refusé. Effet : aucun, les dix couples ne connaissent que `ensemble` (mesuré).
- **Traitement des défauts.** Inchangé. Seule la forme de la valeur est fixée.
- **Effet attendu** (mesuré pour les valeurs actuelles, prévision pour la suite).
  - Le jeu `v1-modeste-02` déclare des valeurs textuelles hors forme (`inst/extdata/jeux/v1-modeste-02/declarations.txt`, produit par `tests/jeux_v1.R:166-173`) : `visibilite_max_saisie_effet_parente` (D02b), `age_par_defaut_du_segment` (D03a), `sexe_par_defaut_du_poste` (D03b), `salaire_par_defaut_du_college` (D03c), `date_effet_plus_delai` (D03g). Sous `valider_plan()`, J3 et J4 seraient refusés (`plan_invalide`) : **ses déclarations sont à aligner** par Bdr-b2, et l'ADR 0011, point 13, fait fixer ces valeurs par `actuary`.
  - Une fois les déclarations alignées, aucune provision de J3 ni de J4 ne change, puisque P1 et P2 n'ont aucun dossier (§ 2). Les cellules `valeur` d'`hypotheses_defaut` changent : 6 rangées dans J3, 10 dans J4 (mesuré). La section `donnees` de la fiche change aussi.
  - J1, J2, C1 à C4, V1, V2 : aucune hypothèse `H` déclarée (mesuré), donc aucun changement.

## 8. Effet attendu sur les dix couples de référence (récapitulatif)

Comparaison aux références en vigueur (`main` `7d53a05`). Tout est **prévision**, à remesurer par Bdr-b2, sauf mention « mesuré ». Le changement de version (§ 1.11) touche les dix couples : régénération unique de l'arbre (ADR 0011, point 22), jeux et base construite renommés.

| Couple | Fiche | Provisions | Bilan | Visa |
|---|---|---|---|---|
| J1, J2 | `versions/dictionnaire`, `empreintes/donnees/extraction`, `empreintes/donnees/garanties_souscrites` (P6) | inchangées (0 `exact`) ; P6 avec `maintien_deces` = `FALSE` (M502) : D03h non détecté | rangée `D03h non_lisible` retirée (P6 ; mesurée présente) ; rangées `D11…` selon § 3 | `actuary` |
| J3, J4 | idem, plus la section `donnees` du plan (valeurs `H` alignées, § 7) | **P1, P2, total : d'arrêté (`D09`) à 0 `exact`** (#72 ; mesure substitutive) ; P3 0 `exact` inchangé | `refus_tables` : `portee` `ligne`, `postes_arretes` vide ; `enjeu` : rangées de cause `D09` en partie calculées (8 D02a, part des 10 `ensemble`) ; `hypotheses_defaut$valeur` (6 et 10 rangées) ; `D03h`, `D11` comme J1 | **mainteneur** (total) |
| C1 à C4 | idem J1 | inchangées (mesuré : bilans vides, aucun D02a, aucun dossier masqué, collège `ensemble` seul) ; P6 : `GSC1` à `maintien_deces` = `FALSE` | `D03h`, `D11` comme J1 | `actuary` |
| V1, V2 | idem J1 | inchangées (mêmes mesures) ; P6 avec `FALSE` | `D03h`, `D11` comme J1 | `actuary` |

Les points sans effet sur aucun couple, chacun fondé sur la mesure citée dans sa section : P7 à P18 hors P6 (§ 1), #81 (cellules de provision), #83, #90, #32.

## 9. Lectures de textes

| Texte | Point | État | Qui |
|---|---|---|---|
| Règlement ANC 2015-11, art. 143-3, 143-2, 143-1, 143-12 (recueil ANC 2025, SHA-256 `0d7fb3c8…9319766`) | § 6 (#32) | **lu** par `regulatory` le 12/11/2026, deux lectures (A, B) ; choix au mainteneur (Q1) | mainteneur |
| Art. 142-3 et 142-4 du même règlement (rentes vie) | § 6, lecture B | lus sur extraction ; rendu non relu par `regulatory` | `regulatory`, si B est retenue |
| Art. L310-1, 2° et 3°, du code des assurances | § 6 | libellé **incertain** (lecture indirecte) : ne pas le citer mot pour mot | `regulatory` |
| Intitulés des art. 600-2 à 600-4 du règlement ANC 2015-11 | § 6 (contexte) | incertains : non cités | `regulatory` |
| Numéro et date du JO du règlement 2015-11 ; version Légifrance | § 6 | non trouvés | `regulatory` |
| Loi n° 89-1009, art. 2, 7, 7-1 et 10 (maintien de la garantie décès) | § 1.2 (P6) | **lu** par `regulatory` le 12/11/2026, statut `revue requise` : lecture indirecte de Légifrance par fragments (lecture directe empêchée), concordante avec `docs/recherche/2026-11-07-lectures-regulatory-cadrage.md:24`, qui signale une différence de rédaction de l'al. 1 de l'art. 7-1 avec le JO papier ; relecture directe recommandée avant toute citation mot pour mot. Établi pour P6 : clause imposée par l'art. 7-1, al. 1, 1re phrase, dans les conditions de l'art. 2, ou stipulée ; art. 10 sans effet sur P6. Interprétations ouvertes : **I1**, « décès, incapacité de travail et invalidité » cumulatif, ou décès et l'un des deux risques ; **I2**, portabilité (CSS L911-8) couverte ou non par le renvoi de l'art. 2, al. 3 ; **I3**, portée de « Cet engagement » (al. 2), soit le point ouvert P9 du dictionnaire (dict. :815 ; #14, point 4), hors de la présente branche | `regulatory` (relecture directe ; I1 à I3 sur #14, point 4) ; mainteneur (I1 à I3) |
| A132-1 du code des assurances | § 7 (D03h) | **non cité** : les bornes proposées pour D03h sont celles de la colonne (jugement d'expert P12, dict. :818), non un plafond réglementaire ; à lire seulement si le mainteneur veut lier la borne haute au plafond d'A132-1 | `regulatory`, sur demande |
| CSS L911-8 (portabilité) | § 3 (D11, hors portabilité) | déjà cité au dictionnaire (dict. :388) ; aucun ajout | — |

## 10. Points ouverts et éléments pour les sections communes de la feuille de route

### 10.1 Points d'arrêt (ADR 0012, point 9)

- **A1 : P6 (§ 1.2), levé.** Le mainteneur a retenu l'option (c) (M502, 12/11/2026). `regulatory` a lu la loi n° 89-1009, art. 2, 7, 7-1 et 10, le même jour (§ 9, statut `revue requise`, lecture indirecte). La lecture établit que la clause de maintien n'est pas obligatoire pour tout contrat collectif décès : la colonne `maintien_deces` est fondée. P6 est écrit au § 1.2, avec `maintien_deces` = `FALSE` dans les quatre bases existantes. Le point ouvert P9 du dictionnaire (portée du maintien, I3 ; dict. :815 ; #14, point 4) reste hors de la présente branche et ne conditionne pas la colonne.
- **A2 : valeurs admises d'hypothèses lues par Br** (D03f, D03c, D03h). Le projet reprend D03f `regle` et D03c `<college>=<montant>` à la lettre de l'erratum v1.0.16 (`d266559`, visé, sur `claude/deces-reliquats`, pas encore sur `main`). Il ajoute deux contraintes nouvelles : les **bornes** de D03h et le **domaine** de `college` (sans « ; » ni « = »). Br lit la forme de `main` (ADR 0012, point 7). Ces contraintes vivent dans `valider_plan()` (`R/plan.R`, Bdr-b2), hors du couloir de Br, et `.hypothese_d03h()` (`R/risque_en_cours.R`, couloir de Br) reste une garde à la lecture. Aucun fichier commun, donc aucun point de contact demandé. Le contrôle de concordance se fait à la fusion de Br : la forme de l'erratum sur `main` doit égaler celle du § 7.
- **A3 : décisions ouvertes dans Br et Bo.** #88 (0a) n'a aucun lien avec le dictionnaire. La question de #75 et #92 Q1 sont tranchées par E16-1 et par l'erratum v1.0.16 (visés le 12/11/2026), qui ne sont pas sur `main` : le projet s'y range. #62 (Bo) n'a aucun lien. Bdr-b2 modifiera `tests/controles/concordance_dictionnaire.R` (couloir de Bo) pour les colonnes nouvelles des CSV : après la fusion de Bo, ce n'est pas un recouvrement.
- **A4 : deux lectures de l'art. 143-3** (§ 6). `regulatory` les a décrites, `actuary` éclaire, le mainteneur tranche (Q1).

### 10.2 Éléments pour les sections communes (consignés par Br ou au point d'étape)

- **§ 2, ligne Bdr-b2.**
  - Dépendances à ajouter : fusion de Br (forme de D03c et D03f sur `main`) ; Bdr-b1 avant le code de #81 (D11 écrit par #34) ; #100 (B4) pour les paramètres de D03a sous `regle`, si Q11 est retenue ; P6 (§ 1.2) : colonne `maintien_deces` au simulateur, à `FALSE` dans les quatre bases (M502), et retrait de l'admission d'un `taux_technique_tarif` présent sur un décès collectif (`R/donnees.R:1681-1683`).
  - Bdr-b2 aligne aussi la spécification du module `donnees` (`vue_empechee`, #72, #83, #90), le simulateur (intensités nouvelles : `manquant_date_effet`, `college_errone`, `affiliations_simultanees`) et les déclarations des jeux (§ 7).
  - Ampleur : elle dépasse l'évaluation initiale. À l'appréciation d'`architect` au plan de Bdr-b2, avec un découpage possible en deux commits par issue.
- **ADR 0010.** Annotations à rédiger par `architect` :
  - point 23 : colonnes nouvelles de `defauts.csv` (`signalement`, `parent`) et de `controles.csv` (`traitement`), et lignes de sous-cas ;
  - point 9 : codes de bilan nouveaux `vue_empechee` et `parente_posterieure`, modalité de portée `ligne`.
- **`CONTEXT.md`.** Termes proposés pour `architect` : « valeur réservée » (`signalement`, `regle`), « date rejetée » (D02a sous `H`, tenue pour inconnue), « vue empêchée ».
- **`CONTEXT.md`, ligne 37** (constat hors couloir, signalé par `regulatory`). La définition du maintien de la garantie décès retient implicitement l'une des deux lectures du point ouvert P9 du dictionnaire (I3), par les mots « après la résiliation ou le non-renouvellement du contrat collectif ». À reformuler par `architect` après la décision sur #14, point 4. La même définition laisse déjà la portée « à établir ».
- **§ 3.** #32 : le point 2 est spécifié ici ; le point 1 (rapport de recherche, ligne 28) et la ligne 296 du recensement restent hors plan. #72 option (ii) et l'extension de la règle 3 du § 6 de la spécification du module `donnees` : issue proposée si Q7 retient le renvoi (corps ci-dessous).
- **Issue proposée** (création sur accord du mainteneur), si Q7 retient (i) :
  - titre : `donnees : règles V et arrêts de vue en portée ligne sous un refus de valeur (suite de #72)` ;
  - libellés : `enhancement`, `needs-triage` ;
  - corps :
    > *Rédigé par l'agent actuary-approfondi (IA).*
    >
    > Le projet de dictionnaire `1.6` (§ 2, option (i)) donne la portée ligne aux refus de valeur pour l'arrêt des postes. Deux suites sont laissées hors de #72 : (1) exécuter en logique de Kleene les règles V qui lisent une colonne refusée pour sa valeur, au lieu de les rendre non exécutées (dans J3 et J4, `D01b prestations` et `prestations_ecartees`, cause `D09`) ; (2) restreindre la règle 3 du § 6 de la spécification du module `donnees` (visibilité non déterminée par un refus de valeur) aux postes dont une unité lit la ligne. Effet : contenu du bilan de J3 et de J4 ; aucune provision attendue.

### 10.3 Questions au mainteneur

1. **Q1 (#32).** Lecture A ou lecture B de l'art. 143-3 ? Recommandation : A (§ 6). Sous B, je recommande de ne pas appliquer le report aux rentes d'invalidité du 2° (art. 143-12 muet ; M83 maintenu).
2. **Q2 (P6).** Option (a), (b) ou (c) de A1 ? Et, si la colonne est retenue, `maintien_deces` = `FALSE` dans les quatre bases existantes ?
3. **Q3 (P7, P8).** Colonnes `signalement` et `parent`, et lignes de sous-cas de D10 dans `defauts.csv` (recommandé) ; colonnes « lues par règle » laissées au code (recommandé) ?
4. **Q4 (P12).** Le nom `vue_empechee` pour le code dédié ?
5. **Q5 (P14).** Retirer « ou dossier sans sinistre » de D04a (recommandé) ?
6. **Q6 (P18).** D03g étendu aux trois dates de saisie, plus un défaut nouveau D03i (`X`) pour les quatre dates d'effet (recommandé) ? Ou une seule des deux options du § 7 ?
7. **Q7 (#72).** Option (i), portée ligne pour le calcul et l'enjeu, règles V inchangées, avec l'issue proposée pour la suite (recommandé) ? Ou option (ii) dans Bdr-b2 ?
8. **Q8 (#81).** Sous-cas lettrés D11a à D11c, traités `S` + `X` par famille (recommandé) ? Ou D11 inchangé, plus D11b et D11c ?
9. **Q9 (#83).** Sous D10b `conserver`, l'arrêt du poste (option (a), recommandée) ou le calcul sur la version invisible (option (b)) ? Le code `parente_posterieure` (`S`) ? D02b étendu à `prestations` ?
10. **Q10 (#90).** Le tableau des relations du § 5.2 : règle générale « toutes les dates », avec trois règles écrites (R11, R12, R13) ? La date rejetée « tenue pour inconnue » et non « manquante » ? La visibilité inchangée ? L'exception de l'enfant posthume ? Alternative pour R3 : la seule `date_debut_gestion`.
11. **Q11 (#99).** Les formes du § 7, en particulier :
    - D03h borné à [−0,05 ; 0,10] ;
    - D03a en `regle`, ses paramètres fixés avec #100 ;
    - la forme de D03b ;
    - la forme de D05 ;
    - le domaine de `college` sans « ; » ni « = ».
12. **Q12 (#60).** Rattacher à #60 les points 1 à 4 du § 7 de la spécification du module `donnees` (§ 1.7, § 1.8 et § 1.10 du projet ; recommandé) ?
13. **Q13 (P6, contrôle de cohérence facultatif).** Faut-il signaler une garantie `deces` collective à `maintien_deces` = `FALSE` quand le même contrat porte `incapacite` et `invalidite` ?
    - (a) en `1.6`, un code de contrôle nouveau (§ 1.10) : traitement `S` seul, détection présomptive, portée ligne, aucune déclaration ; effet prévu : 5 signalements par couple pour J1 à J4, 6 pour V1 et V2, 0 pour C1 à C4, tous de faux positifs par construction (M502) ;
    - (b) pas en `1.6` : le contrôle est renvoyé au recensement du poste « maintien de la garantie décès », où il prend son objet, par une issue (**recommandé**) ;
    - (c) aucun contrôle.

    Motif de (b) : la détection repose sur la lecture I1 et sur une condition de l'art. 2 que la base ne permet pas de lire, et elle n'a d'effet utile que lorsqu'un poste valorise le maintien.
14. **Q14 (P6, loi vraie).** Les trois jeux portent `incapacite` et `invalidite` sur tous leurs contrats collectifs qui portent `deces`. Leur vérité contient 2, 2 et 1 décès futurs issus d'un arrêt (mesuré), que la lecture « tous les arrêts » du point ouvert P9 rattache au maintien. Avec `FALSE` (M502), ce rattachement est incohérent, sans effet en `1.6`.
    - (a) garder `FALSE` en `1.6` et exiger, à la spécification du poste « maintien de la garantie décès », une base à `maintien_deces` = `TRUE` avec `taux_technique_tarif` renseigné (**recommandé** : M502 inchangée) ;
    - (b) passer dès Bdr-b2 les contrats collectifs des jeux régénérés à `TRUE`, `taux_technique_tarif` renseigné ; cela rouvre M502 et demande une mesure de l'effet sur P3 et sur l'indicateur A132-1 ;
    - (c) faire produire au simulateur des décès issus d'un arrêt seulement sous `TRUE` (pertinent sous la seule lecture « tous les arrêts »).

### 10.4 Réponses du mainteneur (12 novembre 2026)

*Consignées par la session de la branche (`docs/feuille-de-route.md`, § 4.3, M501 à M512).* Le mainteneur a retenu la recommandation sur chacune des questions Q1 à Q12 :

| Question | Réponse | Décision |
|---|---|---|
| Q1 (#32) | lecture A de l'art. 143-3 | M501 |
| Q2 (P6, A1) | option (c) : lecture de la loi n° 89-1009, art. 7 et 7-1, par `regulatory` dans la présente branche ; `maintien_deces` = `FALSE` dans les quatre bases existantes | M502 |
| Q3 (P7, P8) | colonnes `signalement` et `parent`, sous-cas de D10 dans `defauts.csv` ; colonnes lues laissées au code | M503 |
| Q4 (P12) | `vue_empechee` | M504 |
| Q5 (P14) | « ou dossier sans sinistre » retiré de D04a | M505 |
| Q6 (P18) | D03g étendu et D03i | M506 |
| Q7 (#72) | option (i) ; issue de suite **#105** créée | M507 |
| Q8 (#81) | D11a à D11c | M508 |
| Q9 (#83) | option (a) ; `parente_posterieure` ; D02b étendu à `prestations` | M509 |
| Q10 (#90) | tableau du § 5.2 tel quel (R3 : les deux dates) | M510 |
| Q11 (#99) | formes du § 7, bornes de D03h comprises | M511 |
| Q12 (#60) | points 1 à 4 du § 7 de la spécification du module `donnees` rattachés | M512 |

La lecture de `regulatory` du 12 novembre 2026 (loi n° 89-1009, art. 2, 7, 7-1 et 10) est reprise au § 1.2 et au § 9, et le § 1.2 est rédigé sous la forme retenue par M502. Réponses du mainteneur du même jour : **Q13, option (b)** (contrôle renvoyé au recensement du poste « maintien de la garantie décès », issue **#106** ; M513) ; **Q14, option (a)** (`FALSE` en `1.6`, base à `TRUE` exigée à la spécification de ce poste ; M514). Commentaire de `regulatory` déposé sur #14, point 4 (M515).

**Visa.** Projet visé par le mainteneur le 12 novembre 2026 (M516).
