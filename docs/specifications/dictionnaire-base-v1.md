# Dictionnaire de la base brute fictive — v1 (décès, arrêt de travail, garanties liées)

> *Rédigé par l'agent actuary-approfondi (IA) le 7 novembre 2026 (issue #16, branche `claude/socle-donnees`). Statut : **proposé**, soumis au visa du mainteneur (E2.2, M17). Aucun code des modules `donnees` et `simulation` n'est écrit avant ce visa. Visa : — (date à porter).*

Version du dictionnaire : `1.0`. C'est la valeur attendue dans `extraction.version_dictionnaire`.

## 0. Objet, portée, statut

Ce dictionnaire spécifie la base brute fictive de la v1. Il couvre le décès (capital décès collectif et individuel, rentes de conjoint et d'éducation, double effet, capitaux non réclamés) et l'arrêt de travail (incapacité, invalidité, passage, invalidité en attente, maintien de la garantie décès, portabilité). Il fixe :

- les tables, les colonnes, leurs types R, leurs domaines, les clés et les conventions (E2.1, E2.2) ;
- les dates de saisie et la vue à une date (E2.6) ;
- la forme de l'évaluation de gestion par dossier (M68) ;
- la liste amendée des défauts de données, avec le traitement du moteur et le paramètre d'intensité du simulateur (E2.4, M69).

C'est un **contrat partagé** (`docs/agents/routage.md`, § 4.2). Le simulateur le produit, le module `donnees` le contrôle, les familles de calcul et les règles comptables le lisent. Toute modification passe par une nouvelle version visée.

**Ce qu'il ne fixe pas :**

- les méthodes (recensement des méthodes, E2.16) ;
- la loi vraie et le format des jeux simulés (issue « module `simulation` » de B1 et ADR de forme) ;
- les hypothèses du plan de calcul (E2.20) ;
- le rattachement des postes aux provisions et la règle de taux par poste (#14) ;
- les textes non établis (#13).

La base ne porte **aucune provision inscrite** (Q5 ; ADR 0008, point 8). Elle ne contient **aucun champ dérivé** : ni âge, ni ancienneté, ni état courant d'un sinistre ou d'un dossier, ni montant en vigueur, ni triangle (ADR 0008, options écartées).

**Sources.**
- Exigences : E1.5, E2.1 à E2.6, E2.14, E2.20, E4.4, E4.9.
- ADR 0005 et 0008 ; `CONTEXT.md`.
- Entretien de cadrage : Q5, Q6, Q17, Q18, Q22, Q30, A4, G5, G19.
- Décisions du mainteneur : M17, M33, M63, M68, M69, M71.
- Issue #14.

Le dictionnaire double effet de `docu_actu` (douze tables, M17) n'a pas pu être relu pour cette rédaction (dépôt privé, accès refusé à la session) : voir § 11, P13.

## 1. Conventions

### 1.1 Noms

Les noms de tables et de colonnes sont en minuscules, sans accents, avec des mots séparés par `_` (E4.1, A5). La liste de `data.frame` passée à `calculer_provisions()` est nommée par les noms de tables du § 2 (E4.4). Il y a un fichier CSV par table, nommé `<table>.csv`.

### 1.2 Types, fichiers, colonnes

**Types.** Cinq types R : `character`, `integer`, `numeric`, `Date`, `logical`. Une colonne d'un autre type est refusée par la couche de lecture, sans conversion (E2.5, E4.4). Le module `donnees` contrôle les types une seconde fois, parce que le moteur peut recevoir des `data.frame` construits sans la couche de lecture.

**Format CSV :**
- UTF-8 sans marque d'ordre ;
- séparateur de champs : virgule ; séparateur décimal : point ;
- guillemets doubles pour les chaînes ;
- en-tête égal aux noms des colonnes ;
- `Date` au format `AAAA-MM-JJ` ; `logical` en `TRUE` / `FALSE`.

**Règles sur les colonnes :**
- Une colonne obligatoire (`O`) ou conditionnelle (`C`) absente entraîne le refus de la table.
- Une colonne facultative (`F`) peut être absente ; c'est l'équivalent d'une colonne entièrement manquante.
- Une colonne inconnue du dictionnaire est refusée (proposition, § 11, P7).
- L'ordre des colonnes est libre. L'ordre des lignes ne porte aucune information et le moteur ne s'en sert pas.

### 1.3 Identifiants

- Les identifiants sont des `character` **opaques** : le moteur n'interprète ni leur forme ni leur ordre.
- Ils sont uniques dans leur table et jamais réutilisés.
- Le simulateur emploie des préfixes pour la lecture humaine, sans valeur de contrôle : `AD` adhérent, `CT` contrat, `GS` garantie souscrite, `AS` assuré, `AF` affiliation, `ME` membre de la famille, `SI` sinistre, `DO` dossier, `BE` bénéficiaire, `RE` rente, `EV` événement, `PR` prestation, `CO` cotisation, `CA` catastrophe, `VI` victime, `EG` évaluation de gestion.
- Une clé étrangère non manquante doit exister dans la table qu'elle référence ; sinon, c'est le défaut D04.
- Dans une clé composite, un manquant compte comme une valeur : deux lignes qui ne diffèrent que par deux manquants sont en double.

### 1.4 Dates

- Type `Date`, sans heure. L'instant d'une date dans l'année et le calcul des durées sont des **conventions du plan** (E2.20).
- Les périodes (`debut_*`, `fin_*`) ont leurs **bornes incluses** : du 1er janvier au 31 mars s'écrit `2026-01-01` / `2026-03-31`. Leur durée en jours vaut fin − début + 1.
- **Borne basse** de toute date : le `1901-01-01` inclus. Ce jugement d'expert écarte les sentinelles usuelles `1900-01-01` et `1899-12-30`.
- **Borne haute** : `extraction.date_extraction`, sauf pour les colonnes marquées **« futur admis »** : fins de période couverte, termes et fins contractuels, dates d'effet des événements programmables (§ 4).
- **Aucune date de saisie n'est postérieure à la date d'extraction** (`CONTEXT.md`, « Date d'extraction »).
- Le sens d'un manquant est fixé colonne par colonne :
  - **ouverte** : la fin n'est pas survenue ;
  - **non survenue** : par exemple un sinistre non encore instruit ;
  - **inconnue** : c'est alors un défaut de données.

  Une date sentinelle de fin ouverte (`9999-12-31`) est hors domaine.

### 1.5 Montants, taux, âges, durées

**Montants.**
- En euros (`numeric`), non arrondis par le moteur.
- Il s'agit du montant à la charge de l'organisme d'assurance, brut de réassurance (E1.6), avant les prélèvements sociaux et fiscaux retenus à la source.
- Ils sont positifs, sauf mention contraire (régularisations et annulations signées).

**Unités.**
- capital : € ;
- rente : € par an (montant annuel ; l'arrérage en est la part de la périodicité) ;
- indemnité journalière : € par jour calendaire ;
- salaire de référence : € par an.

**Taux.** En fraction décimale, jamais en pour cent : `1.5` vaut 150 % de l'assiette, `0.0175` vaut 1,75 %.

**Âges et durées des paramètres.**
- Ce sont des nombres entiers : en années pour les âges, en jours ou en mois selon le nom du paramètre.
- Leur lecture (âge révolu, millésime) est une **convention du plan**, jamais une règle du dictionnaire. Exemple de convention possible pour les rentiers : la date de naissance reportée au 31 décembre le plus voisin (ANC 143-3, rapport de recherche, statut « vérifié »).
- La base ne contient aucun âge ni aucune ancienneté : ils se calculent à partir des dates.

### 1.6 Manquants

- En R, un manquant est `NA`. En CSV, **le champ vide est le seul marqueur** de manquant.
- Aucune valeur sentinelle n'en tient lieu (`0`, `-`, `inconnu`, `NULL`) : une sentinelle est une valeur, contrôlée contre le domaine.
- Dans un `data.frame` reçu directement, la chaîne `""` n'est pas un manquant : elle est hors domaine.

### 1.7 Caractère obligatoire (colonne « Obl. »)

- **`O` (obligatoire)** : un manquant est un défaut de la liste si la colonne y figure (§ 9), un refus sinon.
- **`C` (conditionnelle)** : la colonne est obligatoire sous la condition écrite dans le domaine et doit être manquante hors de cette condition. Une valeur présente hors condition est hors domaine, donc refusée.
- **`F` (facultative)** : un manquant est sans effet sur les contrôles, et la colonne peut être absente.

### 1.8 Statut de saisie (colonne « Saisie », E2.6)

| Code | Signification | Effet en vue à une date A |
|---|---|---|
| `S` | Date de saisie : date à laquelle l'information entre dans la base. | Gouverne la visibilité de la ligne, ou de la partie de ligne qu'elle date. |
| `L` | Valeur figée à la saisie de la ligne ; jamais modifiée ensuite (une modification est une nouvelle ligne : événement, régularisation). | Connue dès que la ligne est visible. |
| `V` | Date qui vaut date de saisie de sa propre information (émission, mouvement, instruction). | Connue à A si et seulement si elle est ≤ A. |
| `E` | Valeur écrasée à l'extraction (attribut d'un contrat, d'un assuré, d'un membre de la famille). | La vue à une date retient la valeur extraite ; cette limite est restituée dans le rapport figé (E2.6). |
| `P(x)` | Valeur rattachée à la date de saisie `x` de la même ligne. | Connue à A si `x` ≤ A. |

### 1.9 Contenu de l'extraction

La **fenêtre d'historique** va de `extraction.debut_historique` à `extraction.date_extraction` ; elle couvre dix ans en v1 (E2.3). L'extraction contient :

1. les contrats en vigueur à un moment de la fenêtre, leurs adhérents, et leurs garanties souscrites et paramètres pour toutes les versions qui chevauchent la fenêtre ;
2. les affiliations en cours à un moment de la fenêtre, ainsi que, pour chaque sinistre extrait, l'affiliation en cours à sa survenance ; et les assurés de ces affiliations, des contrats individuels et des sinistres ;
3. tout sinistre déclaré dans la fenêtre, et tout sinistre déclaré avant dont un dossier n'est pas clos au début de la fenêtre (le **stock** : rentes en service, arrêts en cours, capitaux dus, survenances antérieures à la fenêtre comprises, E2.3). Chaque sinistre extrait vient **avec tous ses événements depuis la survenance**, parce que l'ancienneté dans l'état entre dans la loi de maintien. Il vient aussi avec ses dossiers, ses rentes, ses bénéficiaires et les membres de la famille connus ;
4. les prestations réglées dans la fenêtre, et seulement celles-là : les triangles de paiements ne couvrent donc que les années de survenance de la fenêtre ;
5. les mouvements de cotisations datés dans la fenêtre ;
6. les catastrophes survenues dans la fenêtre et leurs victimes (tables facultatives) ; les évaluations de gestion saisies dans la fenêtre (table facultative).

### 1.10 Traitements

Chaque contrôle et chaque défaut a un traitement unique, pris parmi quatre (E2.4, E2.5, E2.20, M71). **Aucune correction silencieuse** : le moteur ne modifie jamais une donnée.

| Code | Traitement | Déclaration du plan | Sans déclaration |
|---|---|---|---|
| `R` | **Refus strict** : l'extraction est à reprendre. | Aucune ne permet de poursuivre. | Arrêt des postes qui lisent la table ou la colonne (E2.5), avec le motif, le nombre de lignes et les dix premiers identifiants. |
| `X` | **Exclusion déclarée** : lignes écartées, comptées, listées par motif. L'**enjeu** est restitué par motif et par poste : nombre de dossiers et derniers montants connus (E2.5). | Par motif **et par famille de calcul** (engagement, triangle, risque en cours, règle comptable) : `exclure` ou `conserver` (`conserver` vaut signalement). | Refus qui nomme la règle manquante. |
| `H` | **Hypothèse par défaut** : valeur ou règle appliquée dans le calcul seulement, données intactes, comptée par motif. C'est un jugement d'expert documenté dans la fiche de calcul (motif, alternative écartée, effet chiffré). | Par motif et **par référentiel** : prudente en comptes sociaux, centrale en meilleure estimation (E2.20, M71). | Refus qui nomme l'hypothèse manquante. |
| `S` | **Signalement** : compté et listé dans le résultat, sans effet sur le calcul. | Aucune. | — |

**Exclusions en cascade.** Exclure un sinistre exclut, dans la même famille de calcul, ses dossiers, rentes, bénéficiaires, événements, prestations et évaluations. L'enjeu restitué couvre toute la cascade. Une anomalie qui n'a pas de traitement dans la liste du § 9 est un refus (ADR 0008, point 5).

## 2. Vue d'ensemble

### 2.1 Tables

| N° | Table | Objet | Clé primaire | Clés étrangères | Table | Visibilité en vue à une date |
|---|---|---|---|---|---|---|
| T1 | `extraction` | Métadonnées de l'extraction (une ligne) | — | — | O | — |
| T2 | `adherents` | Adhérents des contrats collectifs | `id_adherent` | — | O | E |
| T3 | `contrats` | Contrats collectifs et individuels | `id_contrat` | `id_adherent`, `id_assure` | O | E, fin en `S` |
| T4 | `garanties_souscrites` | Garanties d'un contrat, par collège et par version | `id_garantie_souscrite` | `id_contrat` | O | E |
| T5 | `parametres` | Paramètres numériques des garanties souscrites (format long) | (`id_garantie_souscrite`, `parametre`, `categorie_invalidite`, `age_min`) | `id_garantie_souscrite` | O | E |
| T6 | `assures` | Assurés | `id_assure` | — | O | E |
| T7 | `affiliations` | Liens datés d'un assuré à un contrat collectif | `id_affiliation` | `id_assure`, `id_contrat`, (`id_contrat`, `college`) | O | S |
| T8 | `famille` | Conjoints et enfants connus d'un assuré | `id_membre` | `id_assure` | O | S |
| T9 | `sinistres` | Une ligne par sinistre | `id_sinistre` | `id_assure` | O | S |
| T10 | `dossiers` | Un dossier par sinistre et par garantie déclenchée (G19) | `id_dossier` | `id_sinistre`, `id_garantie_souscrite` | O | S |
| T11 | `beneficiaires` | Bénéficiaires d'un dossier et leur part | `id_beneficiaire` | `id_dossier`, `id_membre` | O | S |
| T12 | `rentes` | Une ligne par rente (dossier × bénéficiaire) : en service, à constituer ou terminée | `id_rente` | `id_dossier`, `id_membre` | O | S |
| T13 | `evenements` | Journal daté des états des sinistres et des dossiers, et des montants de service | `id_evenement` | `id_sinistre`, `id_dossier`, `id_rente` | O | S |
| T14 | `prestations` | Paiements datés, avec leur période couverte | `id_prestation` | `id_dossier`, `id_rente` | O | S et V |
| T15 | `cotisations` | Mouvements de cotisations par garantie souscrite et période couverte | `id_cotisation` | `id_garantie_souscrite` | O | V |
| T16 | `catastrophes` | Événements à victimes multiples | `id_catastrophe` | — | F | S |
| T17 | `victimes` | Victimes recensées d'une catastrophe, déclarées ou non | `id_victime` | `id_catastrophe`, `id_assure`, `id_sinistre` | F (O si T16) | S |
| T18 | `evaluations_gestion` | Évaluations de gestion par dossier (M68) | `id_evaluation` | `id_dossier` | F | S |

**Liens entre tables :**
- `adherents` 1–n `contrats` 1–n `garanties_souscrites` 1–n `parametres` ;
- `contrats` 1–n `affiliations` n–1 `assures` ; un contrat individuel n–1 `assures` ;
- `assures` 1–n `famille` ;
- `assures` 1–n `sinistres` 1–n `dossiers` n–1 `garanties_souscrites` ;
- `dossiers` 1–n `beneficiaires` n–1 `famille` ; `dossiers` 1–n `rentes` n–1 `famille` ;
- `sinistres` 1–n `evenements`, chaque événement étant rattaché, selon son niveau, au dossier et à la rente ;
- `dossiers` 1–n `prestations` ; `garanties_souscrites` 1–n `cotisations` ;
- `catastrophes` 1–n `victimes` ; `dossiers` 1–n `evaluations_gestion`.

### 2.2 Écarts à la liste d'E2.1 (à viser)

1. **`extraction` est une table nouvelle.** La base porte elle-même sa date d'extraction, contre laquelle se contrôlent la date d'arrêté du plan et l'absence d'information postérieure.
2. **« Garanties souscrites et leurs paramètres » devient `garanties_souscrites` + `parametres`.** Les paramètres numériques passent en format long : paliers par âge de la rente d'éducation, taux par catégorie d'invalidité. Ce format s'étend aux jalons suivants sans ajouter de colonne, et garde le typage parce que toutes les valeurs y sont `numeric`.
3. **« Famille et bénéficiaires » devient `famille` (les personnes) + `beneficiaires` (le lien entre un dossier et une personne, avec sa part).** Un même enfant peut être bénéficiaire de plusieurs dossiers : rente d'éducation, double effet.
4. **« Rentes en service » devient `rentes`.** Une table d'état à l'extraction serait un champ dérivé, écrasé, et inutilisable en vue à une date. L'état « en service » à une date se reconstitue des événements : `ouverture_service`, `suspension`, `fin_service` (§ 4). Le montant en vigueur se reconstitue de `ouverture_service` et `modification_montant`. Une rente créée sans ouverture de service est une rente à constituer. Le stock à la date d'extraction (E2.3) s'y trouve, survenances antérieures à la fenêtre comprises.
5. **L'« évaluation de gestion par dossier, colonne facultative » devient une table facultative datée, `evaluations_gestion`** (§ 7). Une colonne non datée ne permettrait ni la vue à une date ni le triangle des évaluations de gestion (relecture d'`actuary` du 7 novembre 2026, R2).

Si le mainteneur vise ces écarts, E2.1, l'ADR 0008 (point 1) et l'entrée « Évaluation de gestion » de `CONTEXT.md` sont à mettre en accord (§ 11, P1).

### 2.3 Couverture des données exigées par E2.1

| Donnée exigée | Où |
|---|---|
| Contrats, nature du contrat (E1.6) | `contrats.nature_contrat` |
| Adhérents, assurés, affiliations | T2, T6, T7 |
| Garanties souscrites et paramètres | T4, T5 |
| Famille et bénéficiaires | T8, T11 |
| Cotisations émises et encaissées par garantie et par période (A4, M33) | T15 (`nature_mouvement`, période couverte) |
| Sinistres : survenance, déclaration, instruction | T9 |
| Événements avec leur date de saisie | T13 |
| Dossiers, un par sinistre et par garantie déclenchée | T10 |
| Prestations payées avec leur période couverte | T14 |
| Rentes en service (stock à l'extraction) | T12 et T13 |
| Catastrophes et victimes | T16, T17 |
| Évaluation de gestion (M68) | T18 |
| Assiette (salaire de référence) | `garanties_souscrites.type_assiette`, `affiliations.salaire_reference` |
| Franchise | `parametres.franchise_jours`, `garanties_souscrites.type_franchise` |
| Catégorie d'invalidité | `evenements.categorie_invalidite` |
| Prestations de la sécurité sociale ou règle de complément | `evenements.montant_securite_sociale`, `garanties_souscrites.regle_complement` |
| Âge de fin de service des rentes | `parametres.age_fin_service`, et `fin_service` programmable (motif `retraite`) |
| Taux du tarif par contrat (M63) | `garanties_souscrites.taux_technique_tarif` |
| Portabilité (E1.5) | `affiliations.type_affiliation = "portabilite"` |

## 3. Tables

Lecture des colonnes : Obl. et Saisie, voir § 1.7 et § 1.8 ; « Défauts » renvoie aux codes du § 9.

### T1. `extraction`

Une ligne exactement ; tout autre nombre de lignes est un refus (R).

| Colonne | Type | Domaine | Obl. | Saisie | Défauts |
|---|---|---|---|---|---|
| `date_extraction` | Date | Date d'extraction ; ≥ toute date de saisie de la base | O | — | — |
| `debut_historique` | Date | < `date_extraction` | O | — | — |
| `type_organisme` | character | `societe_assurance`, `mutuelle`, `institution_prevoyance` | O | — | — |
| `version_dictionnaire` | character | `1.0` (version d'un autre dictionnaire : refus) | O | — | — |
| `devise` | character | `EUR` | O | — | — |

### T2. `adherents`

L'adhérent est l'entreprise ou la personne morale adhérente à un contrat collectif.

| Colonne | Type | Domaine | Obl. | Saisie | Défauts |
|---|---|---|---|---|---|
| `id_adherent` | character | Identifiant | O | L | D01a |
| `secteur_activite` | character | Code opaque de secteur, pour la segmentation | F | E | — |

### T3. `contrats`

| Colonne | Type | Domaine | Obl. | Saisie | Défauts |
|---|---|---|---|---|---|
| `id_contrat` | character | Identifiant | O | L | D01a |
| `nature_contrat` | character | `collectif_obligatoire`, `collectif_facultatif`, `individuel` | O | E | — |
| `id_adherent` | character | → `adherents` ; requis si collectif, manquant si individuel | C | E | D04b |
| `id_assure` | character | → `assures` ; requis si individuel (en v1, le souscripteur est l'assuré : P11), manquant si collectif | C | E | D04b |
| `date_effet` | Date | Date d'effet du contrat | O | E | D02a, D02c |
| `date_terme` | Date | Terme contractuel ; requis pour la garantie `deces` d'un contrat individuel temporaire ; futur admis | C | E | D02a |
| `date_fin` | Date | Fin effective (résiliation, non-renouvellement, terme, décès) ; manquant = en cours ; futur admis (résiliation notifiée pour une échéance à venir) | F | P(`date_saisie_fin`) | D02a |
| `motif_fin` | character | `resiliation_adherent`, `resiliation_organisme`, `non_renouvellement`, `terme`, `deces_assure`, `autre` ; requis si `date_fin` | C | P(`date_saisie_fin`) | — |
| `date_saisie_fin` | Date | Date de saisie de la fin (notification) ; requise si `date_fin` | C | S | D02b, D03g |
| `mois_echeance` | integer | 1 à 12 ; mois de l'échéance principale | O | E | — |
| `jour_echeance` | integer | 1 à 31, valide avec `mois_echeance` | O | E | — |
| `preavis_mois` | integer | 0 à 24 ; préavis de résiliation avant l'échéance, en mois | O | E | — |
| `tacite_reconduction` | logical | — | O | E | — |

La résiliation et ses dates servent au maintien de la garantie décès (loi n° 89-1009, art. 7-1 ; sa portée est le point 4 de #14). L'échéance, le préavis et la tacite reconduction servent aux limites du contrat.

### T4. `garanties_souscrites`

Une ligne par contrat, garantie, collège et version de paramètres ; les versions d'une même garantie et d'un même collège ne se chevauchent pas.

| Colonne | Type | Domaine | Obl. | Saisie | Défauts |
|---|---|---|---|---|---|
| `id_garantie_souscrite` | character | Identifiant | O | L | D01a |
| `id_contrat` | character | → `contrats` | O | E | D04b |
| `code_garantie` | character | `deces`, `rente_conjoint`, `rente_education`, `double_effet`, `incapacite`, `invalidite` | O | E | D10a |
| `college` | character | Code opaque du collège de personnel ; `ensemble` s'il n'y a pas de collège (toujours `ensemble` pour un contrat individuel) | O | E | D04b |
| `date_effet` | Date | Début de la version | O | E | D02a |
| `date_fin` | Date | Fin de la version ; manquant = en vigueur ; futur admis | F | E | D02a |
| `type_assiette` | character | `salaire_reference` (taux appliqués à `affiliations.salaire_reference`), `forfait`, `capital_deces` (double effet) | O | E | — |
| `type_franchise` | character | `continue`, `discontinue` ; requis pour `incapacite` | C | E | — |
| `regle_complement` | character | `deduction_securite_sociale`, `forfaitaire` ; requis pour `incapacite` et `invalidite` | C | E | — |
| `type_rente_conjoint` | character | `viagere`, `temporaire` ; requis pour `rente_conjoint` | C | E | — |
| `option_iad` | logical | Versement anticipé du capital en cas d'invalidité absolue et définitive ; requis pour `deces` (P5) | C | E | — |
| `periodicite_prestation` | character | `annuelle`, `semestrielle`, `trimestrielle`, `mensuelle` ; requis pour `incapacite`, `invalidite`, `rente_conjoint`, `rente_education` | C | E | — |
| `terme_prestation` | character | `echu`, `a_echoir` ; mêmes garanties | C | E | — |
| `periodicite_cotisation` | character | `unique`, `annuelle`, `semestrielle`, `trimestrielle`, `mensuelle` | O | E | — |
| `taux_technique_tarif` | numeric | Taux du tarif, en fraction ; bornes de contrôle [−0,05 ; 0,10] (jugement d'expert) ; requis si un poste de la garantie est une provision mathématique vie (garantie `deces` des contrats individuels en v1 ; rattachement : #14) | C | E | — |
| `table_tarif` | character | Identifiant de la table du tarif ; informatif, lu par le signalement seulement | F | E | — |

Le moteur contrôle que le taux retenu pour la provision mathématique vie ne dépasse pas `taux_technique_tarif` et le signale sans refuser (E2.9, M62, M63).

### T5. `parametres`

Paramètres numériques des garanties souscrites, en format long ; la liste fermée des paramètres est au § 5.

| Colonne | Type | Domaine | Obl. | Saisie | Défauts |
|---|---|---|---|---|---|
| `id_garantie_souscrite` | character | → `garanties_souscrites` | O | E | D04b |
| `parametre` | character | Liste fermée du § 5, compatible avec `code_garantie` | O | E | — |
| `categorie_invalidite` | character | `cat1`, `cat2`, `cat3` ; requis pour les paramètres à dimension catégorie (§ 5), manquant sinon | C | E | — |
| `age_min` | integer | 0 à 120 ; borne basse incluse d'un palier d'âge du bénéficiaire ; manquant = sans palier | F | E | — |
| `age_max` | integer | 0 à 120, ≥ `age_min` ; borne haute incluse ; requis si `age_min` | C | E | — |
| `valeur` | numeric | Fini, ≥ 0 ; unité au § 5 ; entier pour les âges et les durées | O | E | D09 |

Les paliers d'un même paramètre ne se chevauchent pas. Une clé en double est le défaut D01a.

### T6. `assures`

| Colonne | Type | Domaine | Obl. | Saisie | Défauts |
|---|---|---|---|---|---|
| `id_assure` | character | Identifiant | O | L | D01a |
| `sexe` | character | `F`, `M` | O | E | D03b |
| `date_naissance` | Date | ≥ 1901-01-01, ≤ extraction | O | E | D02c, D03a |
| `situation_familiale` | character | `celibataire`, `marie`, `pacse`, `concubin`, `divorce`, `separe`, `veuf` ; pour un assuré décédé, valeur au décès (convention : le système ne met plus à jour un assuré radié, P14) | O | E | D03d |
| `nombre_enfants_charge` | integer | 0 à 20 ; déclaré à l'affiliation | F | E | — |

La base ne porte pas de date de décès dans `assures` : le décès d'un assuré est un sinistre (G5).

### T7. `affiliations`

Le lien daté d'un assuré à un contrat collectif ; un assuré peut avoir plusieurs affiliations successives. Un contrat individuel n'a pas d'affiliation : sa couverture va de `contrats.date_effet` au plus tôt de `date_fin` et `date_terme`.

| Colonne | Type | Domaine | Obl. | Saisie | Défauts |
|---|---|---|---|---|---|
| `id_affiliation` | character | Identifiant | O | L | D01a |
| `id_assure` | character | → `assures` | O | L | D04b |
| `id_contrat` | character | → `contrats`, nature collective | O | L | D04b |
| `college` | character | (`id_contrat`, `college`) existe dans `garanties_souscrites` | O | E | D04b |
| `type_affiliation` | character | `cotisant` ; `portabilite` (couverture gratuite, douze mois au plus, CSS L911-8) | O | L | — |
| `date_debut` | Date | Début de couverture | O | L | D02a |
| `date_fin` | Date | Fin de couverture ; manquant = en cours ; futur admis | F | P(`date_saisie_fin`) | D02a |
| `motif_fin` | character | `depart_entreprise`, `rupture_contrat_travail`, `retraite`, `deces`, `resiliation_contrat`, `fin_portabilite`, `renonciation`, `autre` ; requis si `date_fin` | C | P(`date_saisie_fin`) | — |
| `date_saisie` | Date | Saisie de l'affiliation ; ≥ ... sans contrainte d'ordre avec `date_debut` (affiliation rétroactive admise) | O | S | D03g |
| `date_saisie_fin` | Date | Saisie de la fin ; requise si `date_fin` (une radiation peut être saisie après la fin : c'est un phénomène, pas un défaut) | C | S | D03g |
| `salaire_reference` | numeric | € par an, ≥ 0 ; assiette commune à toutes les garanties de l'affiliation en v1 (P4) | O | E | D03c, D09 |
| `annee_salaire` | integer | Année de référence du salaire | F | E | — |

### T8. `famille`

Conjoints et enfants d'un assuré connus de l'organisme d'assurance. En prévoyance collective, la famille d'un assuré vivant est en général inconnue ; elle est renseignée à l'instruction d'un sinistre décès. Les postes qui en ont besoin sans la trouver s'appuient sur la structure familiale par défaut, une hypothèse du plan (E2.20).

| Colonne | Type | Domaine | Obl. | Saisie | Défauts |
|---|---|---|---|---|---|
| `id_membre` | character | Identifiant | O | L | D01a |
| `id_assure` | character | → `assures` | O | L | D04b |
| `lien` | character | `conjoint`, `partenaire_pacs`, `concubin`, `enfant`, `autre` | O | L | — |
| `sexe` | character | `F`, `M` | O | E | D03b |
| `date_naissance` | Date | ≥ 1901-01-01 ; ≤ extraction (un enfant à naître n'a pas de ligne avant sa naissance) | O | E | D02c, D03a |
| `handicap` | logical | Enfant à charge sans limite d'âge selon le contrat | F | E | — |
| `date_saisie` | Date | — | O | S | D02b, D03g |

### T9. `sinistres`

Une ligne par sinistre. Un arrêt de travail est un seul sinistre ; le décès de l'assuré est un sinistre distinct (G5).

| Colonne | Type | Domaine | Obl. | Saisie | Défauts |
|---|---|---|---|---|---|
| `id_sinistre` | character | Identifiant | O | L | D01a |
| `id_assure` | character | → `assures` | O | L | D04b |
| `nature_sinistre` | character | `deces`, `arret_travail`, `iad` (invalidité absolue et définitive, à confirmer par le recensement du capital décès : P5) | O | L | D10a |
| `date_survenance` | Date | Fait générateur. Pour un arrêt de travail, c'est le premier jour d'arrêt, **avant franchise** : la garantie incapacité se déclenche à la fin de la franchise, et un arrêt encore en franchise est un tardif de la garantie. | O | E (une rectification écrase) | D02a, D02c, D11 |
| `date_declaration` | Date | Date à laquelle l'organisme d'assurance apprend le sinistre ; ≥ `date_survenance` | O | L | D02a, D02b |
| `date_instruction` | Date | Date à laquelle la situation est établie ; manquant = non instruit ; ≥ `date_declaration` | F | V | D02a |
| `canal_declaration` | character | `beneficiaire`, `adherent`, `assure`, `recherche_organisme` (décès identifié par l'organisme lui-même ; champ des capitaux non réclamés : #14, point 5), `autre` | O | L | — |
| `cause` | character | `maladie`, `accident`, `accident_travail`, `maladie_professionnelle` | F | E | — |
| `date_saisie` | Date | Création de la ligne ; ≥ `date_declaration` | O | S | D02b, D03g |

Le rattachement d'un sinistre à une catastrophe se lit dans `victimes.id_sinistre`, qui en est la seule source.

### T10. `dossiers`

Un dossier par sinistre et par garantie déclenchée (G19) : la paire (`id_sinistre`, `id_garantie_souscrite`) est unique, faute de quoi c'est le défaut D01b. L'**état du dossier** (ouvert, capital dû, réglé, clos) se reconstitue des événements du § 4 ; il n'est pas une colonne.

| Colonne | Type | Domaine | Obl. | Saisie | Défauts |
|---|---|---|---|---|---|
| `id_dossier` | character | Identifiant | O | L | D01a |
| `id_sinistre` | character | → `sinistres` | O | L | D04b |
| `id_garantie_souscrite` | character | → `garanties_souscrites`. Code garantie compatible avec la nature du sinistre : `deces`, `double_effet`, `rente_conjoint` et `rente_education` avec `deces` ou `iad` ; `incapacite` et `invalidite` avec `arret_travail`. Version en vigueur à la survenance. | O | L | D10a, D10b |
| `date_ouverture` | Date | Vaut date de saisie du dossier ; ≥ `sinistres.date_saisie` | O | S | D02b |

### T11. `beneficiaires`

| Colonne | Type | Domaine | Obl. | Saisie | Défauts |
|---|---|---|---|---|---|
| `id_beneficiaire` | character | Identifiant | O | L | D01a |
| `id_dossier` | character | → `dossiers` | O | L | D04b |
| `id_membre` | character | → `famille` ; requis si `qualite` vaut `conjoint_survivant` ou `enfant_a_charge` | C | L | D04b |
| `qualite` | character | `conjoint_survivant`, `enfant_a_charge`, `designe`, `heritiers`, `non_identifie` ; compatible avec la garantie du dossier | O | L | D10e |
| `part` | numeric | ]0 ; 1] ; la somme par dossier vaut 1 (contrôle : signalement) | O | L | — |
| `date_saisie` | Date | — | O | S | D02b, D03g |

### T12. `rentes`

Une ligne par rente : dossier `rente_conjoint`, `rente_education` ou `invalidite` × bénéficiaire. Le service et le montant viennent des événements (§ 4).

| Colonne | Type | Domaine | Obl. | Saisie | Défauts |
|---|---|---|---|---|---|
| `id_rente` | character | Identifiant | O | L | D01a |
| `id_dossier` | character | → `dossiers` dont la garantie est une rente | O | L | D04b, D10a |
| `id_membre` | character | → `famille` ; requis pour `rente_conjoint` et `rente_education` ; manquant pour `invalidite`, dont le bénéficiaire est l'assuré | C | L | D04b |
| `date_saisie` | Date | — | O | S | D02b, D03g |

### T13. `evenements`

Journal des faits datés qui changent l'état d'un sinistre ou d'un dossier, ou l'information de l'organisme d'assurance. Chaque événement porte sa date de saisie (E2.1, E2.6). La liste fermée des types est au § 4.

| Colonne | Type | Domaine | Obl. | Saisie | Défauts |
|---|---|---|---|---|---|
| `id_evenement` | character | Identifiant | O | L | D01a |
| `id_sinistre` | character | → `sinistres` | O | L | D04b |
| `id_dossier` | character | → `dossiers` du même sinistre ; requis pour les types de niveau dossier ou rente, manquant pour le niveau sinistre (§ 4) | C | L | D04b |
| `id_rente` | character | → `rentes` du même dossier ; requis pour les types de niveau rente | C | L | D04b |
| `type_evenement` | character | Liste fermée du § 4 | O | L | D12 |
| `date_effet` | Date | Date du fait ; ≤ extraction sauf pour un type programmable (§ 4) | O | L | D02a, D02c |
| `date_saisie` | Date | ≥ `date_effet` sauf pour un type programmable ; ≤ extraction | O | S | D02b, D03g |
| `categorie_invalidite` | character | `cat1`, `cat2`, `cat3` (catégorie de la sécurité sociale) ; requise pour `entree_invalidite`, `passage_invalidite` et `changement_categorie` | C | L | D03e |
| `montant` | numeric | ≥ 0 ; requis pour `fixation_capital` (€), `ouverture_service` et `modification_montant` (€ par jour pour l'incapacité, € par an pour une rente) | C | L | D09 |
| `montant_securite_sociale` | numeric | ≥ 0, même unité que `montant` ; prestation de la sécurité sociale prise en compte | F | L | — |
| `motif` | character | Liste fermée par type (§ 4) ; requis pour `sortie`, `fin_service` et `cloture_dossier` | C | L | D05 |
| `justificatif` | character | `certificat_medical`, `notification_securite_sociale`, `acte_deces`, `certificat_scolarite`, `attestation_employeur`, `autre` ; manquant = sans justificatif | F | L | D06 |

### T14. `prestations`

| Colonne | Type | Domaine | Obl. | Saisie | Défauts |
|---|---|---|---|---|---|
| `id_prestation` | character | Identifiant | O | L | D01a |
| `id_dossier` | character | → `dossiers` | O | L | D04a |
| `id_rente` | character | → `rentes` du même dossier ; requis pour `arrerage` | C | L | D04a |
| `type_prestation` | character | `indemnite_journaliere` (dossier `incapacite`), `arrerage` (rente), `capital` (dossier `deces` ou `double_effet`) | O | L | D10a |
| `nature_mouvement` | character | `paiement`, `regularisation` (récupération d'indu ou complément) | O | L | — |
| `date_reglement` | Date | Date du paiement ; ≤ extraction | O | V | D02c |
| `debut_periode` | Date | Période couverte ; requise pour `indemnite_journaliere` et `arrerage`, manquante pour `capital` | C | L | D02a, D03f |
| `fin_periode` | Date | ≥ `debut_periode` ; futur admis (terme à échoir) ; mêmes conditions | C | L | D02a, D03f |
| `montant` | numeric | € ; > 0 pour un `paiement`, ≠ 0 pour une `regularisation` | O | L | D09 |
| `dont_revalorisation` | numeric | € ; part du montant au titre d'une revalorisation (capital non réclamé : revalorisation légale, dont le texte et le taux sont à établir, #14 point 5) | F | L | — |
| `date_saisie` | Date | ≤ extraction | O | S | D03g |

### T15. `cotisations`

Mouvements de cotisations par garantie souscrite et période couverte (A4). Une émission, une annulation, une régularisation ou un encaissement fait chacun une ligne : la table ne fait que s'allonger, aucune ligne n'est écrasée.

| Colonne | Type | Domaine | Obl. | Saisie | Défauts |
|---|---|---|---|---|---|
| `id_cotisation` | character | Identifiant | O | L | D01a |
| `id_garantie_souscrite` | character | → `garanties_souscrites` (version en vigueur sur la période) | O | L | D04b |
| `nature_mouvement` | character | `emission`, `annulation`, `regularisation`, `encaissement` | O | L | — |
| `debut_periode` | Date | Période couverte | O | L | D02a, D03f |
| `fin_periode` | Date | ≥ `debut_periode` ; futur admis (base de la PPNA, ANC 143-5) | O | L | D02a, D03f |
| `date_mouvement` | Date | Date d'émission, d'annulation, de régularisation ou d'encaissement ; ≤ extraction | O | V | D02c |
| `montant` | numeric | € ; > 0 pour `emission`, < 0 pour `annulation`, ≠ 0 pour `regularisation` et `encaissement` | O | L | D09 |

### T16. `catastrophes` (facultative)

| Colonne | Type | Domaine | Obl. | Saisie | Défauts |
|---|---|---|---|---|---|
| `id_catastrophe` | character | Identifiant | O | L | D01a |
| `nature_catastrophe` | character | `accident_collectif`, `catastrophe_naturelle`, `attentat`, `autre` | O | L | — |
| `date_evenement` | Date | ≤ extraction | O | L | D02c |
| `date_saisie` | Date | ≥ `date_evenement` | O | S | D02b |

### T17. `victimes` (facultative ; obligatoire si `catastrophes` est présente)

Victimes recensées d'une catastrophe, y compris celles dont le sinistre n'est pas encore déclaré : c'est la donnée du poste « événement catastrophe » du double effet.

| Colonne | Type | Domaine | Obl. | Saisie | Défauts |
|---|---|---|---|---|---|
| `id_victime` | character | Identifiant | O | L | D01a |
| `id_catastrophe` | character | → `catastrophes` | O | L | D04b |
| `id_assure` | character | → `assures` ; manquant = victime non identifiée comme assuré | F | L | — |
| `statut_victime` | character | `decedee`, `blessee`, `disparue` | O | L | — |
| `id_sinistre` | character | → `sinistres` du même assuré ; manquant = non déclaré | F | L | D10h |
| `date_saisie` | Date | — | O | S | D02b |

### T18. `evaluations_gestion` (facultative)

Forme et règles : § 7.

| Colonne | Type | Domaine | Obl. | Saisie | Défauts |
|---|---|---|---|---|---|
| `id_evaluation` | character | Identifiant | O | L | D01a |
| `id_dossier` | character | → `dossiers` | O | L | D04b |
| `montant_restant` | numeric | € ≥ 0 ; coût restant à payer estimé par le gestionnaire à `date_effet`, paiements déjà effectués exclus | O | L | — |
| `date_effet` | Date | Date à laquelle porte l'évaluation ; ≤ extraction | O | L | — |
| `date_saisie` | Date | ≥ `date_effet` | O | S | — |

## 4. Types d'événements (liste fermée)

À date d'effet égale, les événements d'un même sinistre s'appliquent dans l'ordre de ce tableau. Un type **programmable** peut avoir une date d'effet postérieure à sa date de saisie et à la date d'extraction : c'est un fait prévu, dont la saisie est antérieure.

| Type | Niveau | Garanties ou nature | Effet | Colonnes requises | Programmable |
|---|---|---|---|---|---|
| `entree_incapacite` | sinistre | `arret_travail` | État initial « incapacité » ; `date_effet` = `date_survenance` | — | non |
| `entree_invalidite` | sinistre | `arret_travail` | État initial « invalidité » (entrée directe) ; `date_effet` = `date_survenance` | `categorie_invalidite` | non |
| `passage_invalidite` | sinistre | `arret_travail` | Incapacité → invalidité | `categorie_invalidite` | non |
| `changement_categorie` | sinistre | `arret_travail` | Invalidité → invalidité, nouvelle catégorie | `categorie_invalidite` | non |
| `sortie` | sinistre | `arret_travail` | Incapacité ou invalidité vers : « clos » (`reprise_travail`, `fin_droits`, `sans_suite`, `refus`), « éteint » (`deces`) ou « retraite » (`retraite`) ; justificatif attendu pour `reprise_travail` et `deces` | `motif` | oui pour `retraite` |
| `rechute` | sinistre | `arret_travail` | Clos (`reprise_travail`) → état antérieur à la sortie, catégorie comprise, dans le délai `delai_rechute_jours` | — | non |
| `fixation_capital` | dossier | `deces`, `double_effet` | Ouvert → capital dû ; `montant` = capital dû, revalorisation exclue | `montant` | non |
| `second_deces` | dossier | `double_effet` | Décès du conjoint survivant (fait générateur du capital double effet) | — | non |
| `ouverture_service` | dossier (`incapacite`) ou rente | `incapacite`, `invalidite`, `rente_conjoint`, `rente_education` | Début du service au montant indiqué | `montant` ; `id_rente` pour une rente | non |
| `modification_montant` | dossier (`incapacite`) ou rente | mêmes garanties | Montant en vigueur à compter de `date_effet` (revalorisation, recalcul, palier d'âge) | `montant` | oui |
| `suspension` | dossier (`incapacite`) ou rente | mêmes garanties | Service suspendu ; `motif` facultatif : `justificatif_manquant`, `autre` | — | non |
| `reprise_service` | dossier (`incapacite`) ou rente | mêmes garanties | Fin de la suspension | — | non |
| `fin_service` | dossier (`incapacite`) ou rente | mêmes garanties | Fin du service ; motifs : `deces_beneficiaire`, `age_limite`, `fin_etudes`, `retraite`, `passage_invalidite`, `reprise_travail`, `fin_droits`, `autre` ; justificatif attendu pour `deces_beneficiaire` | `motif` | oui pour `age_limite`, `fin_etudes`, `retraite` |
| `mise_a_jour` | sinistre ou dossier | toutes | Information reçue sans changement d'état (pièce, situation de famille) | `justificatif` | non |
| `cloture_dossier` | dossier | toutes | → clos ; motifs : `regle`, `sans_suite`, `refus`, `prescription`, `depot_cdc` (dépôt à la Caisse des dépôts et consignations, loi n° 2014-617, art. 13, rapport de recherche « vérifié » ; délai et effet sur la provision : #14, point 5), `autre` | `motif` | non |
| `reouverture_dossier` | dossier | toutes | Clos → ouvert | — | non |

**Automate du sinistre d'arrêt de travail.** Il sert à la détection de D12.

- **Départ** : `entree_incapacite` ou `entree_invalidite`, et un seul événement d'entrée.
- **Depuis l'incapacité** : `passage_invalidite` ou `sortie`.
- **Depuis l'invalidité** : `changement_categorie` ou `sortie`.
- **Depuis « clos » par `reprise_travail`** : `rechute`.
- **États absorbants** : « éteint » et « retraite ».
- Toute autre suite est une suite d'états impossible (D12).

Un sinistre décès ou IAD n'a pas d'événement de niveau sinistre ; ses états sont ceux de ses dossiers.

## 5. Paramètres des garanties (liste fermée)

| `code_garantie` | `parametre` | Unité | Dimension | Obl. |
|---|---|---|---|---|
| `deces` | `taux_capital` | fraction de l'assiette | — | C : obligatoire sauf si `capital_forfaitaire` |
| `deces` | `capital_forfaitaire` | € | — | C : contrat individuel ou garantie forfaitaire |
| `deces` | `majoration_conjoint` | fraction de l'assiette | — | F |
| `deces` | `majoration_enfant` | fraction de l'assiette par enfant à charge | — | F |
| `deces` | `age_fin_garantie` | années | — | O |
| `deces` | `prime_periodique` | € par échéance | — | C : contrat individuel à cotisation périodique |
| `rente_conjoint` | `taux_rente` | fraction de l'assiette, par an | — | O |
| `rente_conjoint` | `age_terme` | années (âge du conjoint survivant) | — | C : `type_rente_conjoint` = `temporaire` |
| `rente_education` | `taux_rente` | fraction de l'assiette, par an et par enfant | paliers `age_min`/`age_max` | O |
| `rente_education` | `age_limite` | années | — | O |
| `rente_education` | `age_limite_etudes` | années | — | F |
| `double_effet` | `taux_capital` | fraction du capital décès | — | O |
| `double_effet` | `age_limite` | années (enfant à charge) | — | F |
| `incapacite` | `franchise_jours` | jours | — | O |
| `incapacite` | `taux_indemnite` | fraction du salaire de référence, ramené au jour selon la convention du plan | — | O |
| `incapacite` | `duree_max_jours` | jours | — | O |
| `incapacite` | `delai_rechute_jours` | jours | — | O |
| `incapacite` | `age_fin_service` | années | — | O |
| `invalidite` | `taux_rente` | fraction de l'assiette, par an | `categorie_invalidite` | O, une ligne par catégorie couverte |
| `invalidite` | `age_fin_service` | années | — | O |
| toutes | `taux_cotisation` | fraction de l'assiette, par an | — | F |
| toutes | `cotisation_forfaitaire` | € par an et par assuré | — | F |

Les âges de fin de service sont des valeurs contractuelles. Quand la date réelle de fin est connue de la gestion (départ en retraite), elle figure comme `fin_service` ou `sortie` programmable, de motif `retraite`.

## 6. Vue à une date (E2.6)

La vue à l'arrêté A (A ≤ `date_extraction`) retient :

| Table | Ligne visible à A si… | Partie de ligne connue à A si… | Valeurs écrasées (limite restituée) |
|---|---|---|---|
| `extraction` | — | — | — |
| `adherents` | elle est référencée par un contrat visible | — | `secteur_activite` |
| `contrats` | `date_effet` ≤ A | fin : `date_saisie_fin` ≤ A | tout sauf `date_fin` et `motif_fin` |
| `garanties_souscrites`, `parametres` | `date_effet` de la version ≤ A | — | toutes |
| `assures` | il est référencé par une ligne visible | — | toutes |
| `affiliations` | `date_saisie` ≤ A | fin : `date_saisie_fin` ≤ A | `college`, `salaire_reference`, `annee_salaire` |
| `famille` | `date_saisie` ≤ A | — | `sexe`, `date_naissance`, `handicap` |
| `sinistres` | `date_saisie` ≤ A | instruction : `date_instruction` ≤ A | `date_survenance`, `cause` |
| `dossiers` | `date_ouverture` ≤ A | — | — |
| `beneficiaires`, `rentes` | `date_saisie` ≤ A | — | — |
| `evenements` | `date_saisie` ≤ A | — | — |
| `prestations` | `date_saisie` ≤ A et `date_reglement` ≤ A | — | — |
| `cotisations` | `date_mouvement` ≤ A | — | — |
| `catastrophes`, `victimes`, `evaluations_gestion` | `date_saisie` ≤ A | — | — |

**Règles :**

1. Une ligne fille n'est visible que si sa ligne parente l'est. Une fille saisie avant sa parente relève du défaut D02b, avec son traitement.
2. Un événement dont la date d'effet est ≤ A mais la date de saisie > A est **inconnu à A**. C'est ce qui produit les extinctions apprises après l'arrêté, les IBNER et le boni ou mali du réalisé / attendu (E2.22).
3. **Contrôle d'identité** : la vue à `date_extraction` est la base entière, sans aucune ligne écartée par la vue.
4. Le rapport figé restitue, pour toute vue antérieure à l'extraction, la liste des colonnes écrasées ci-dessus (E2.6).

## 7. Évaluation de gestion par dossier (M68)

1. **Forme.** Table facultative `evaluations_gestion` (T18). Une ligne par évaluation successive d'un dossier, avec trois éléments : le montant restant à payer, la date d'effet et la date de saisie (M68 : « si le dictionnaire la date »). Une colonne unique de `dossiers` serait écrasée : elle ne permettrait ni la vue à une date ni le triangle des évaluations de gestion.
2. **Lecteurs.** Les diagnostics seulement, jamais le calcul (M68) :
   - **(a) comparaison par dossier** : dernière évaluation saisie ≤ A face à la provision recalculée par l'outil à A ;
   - **(b) triangle des évaluations de gestion** : à la date de chaque cellule, paiements cumulés plus dernière évaluation saisie à cette date. Il est distinct du triangle de charges, qui porte les provisions recalculées par l'outil (E2.12, M65). Il est restitué comme diagnostic, jamais comme triangle d'une méthode.
3. **Critère d'acceptation** (test à écrire avec le module `donnees`) : toutes les provisions sont identiques au bit près avec ou sans la table ; seuls les diagnostics changent.
4. **Absence de la table** : les diagnostics (a) et (b) ne sont pas produits, et la fiche de calcul le signale. Ce n'est pas un refus.
5. **Pas de défaut injecté** dans cette table en v1 : elle n'entre pas dans le calcul. Ses incohérences (montant négatif, saisie antérieure à l'effet) sont des refus de la table seule ; elles n'arrêtent aucun poste.

## 8. Table de couverture (postes de la v1 → tables et colonnes lues)

La famille de calcul et le rattachement de chaque poste sont ceux d'E2.14 et E2.15. Le rattachement aux provisions est établi par #14.

| Poste (E2.14) | Tables et colonnes lues |
|---|---|
| Capital décès : sinistres déclarés non réglés | `sinistres` (nature, survenance, déclaration, instruction) ; `dossiers` (`deces`) ; `evenements` (`fixation_capital`, `cloture_dossier`, `reouverture_dossier`) ; `prestations` (`capital`) ; `beneficiaires`. Si le capital n'est pas fixé : `parametres` (`taux_capital`, majorations, `capital_forfaitaire`), `affiliations.salaire_reference`, `assures.situation_familiale`, `assures.nombre_enfants_charge`, `famille` |
| Capital décès : tardifs | `sinistres` (survenance, déclaration, `date_saisie`), `dossiers`, `prestations` (`date_reglement`, `montant`) ; a priori de Bornhuetter-Ferguson par décès attendus : `affiliations` (dates, type), `assures` (`date_naissance`, `sexe`), `contrats` |
| Capitaux non réclamés | `dossiers`, `evenements` (`fixation_capital`, `cloture_dossier` motif `depot_cdc`), `beneficiaires` (`non_identifie`), `prestations.dont_revalorisation`, `sinistres` (`date_declaration`, `canal_declaration`) |
| Provision mathématique de la temporaire décès | `contrats` (individuel, `date_effet`, `date_terme`, `date_fin`), `garanties_souscrites` (`taux_technique_tarif`, `periodicite_cotisation`), `parametres` (`capital_forfaitaire`, `prime_periodique`, `age_fin_garantie`), `assures` (`date_naissance`, `sexe`), `cotisations` |
| Maintien de la garantie décès | `sinistres` (`arret_travail`) et `evenements` (états), `contrats` (`date_fin`, `motif_fin`, `date_saisie_fin`), `parametres` (`deces` : `taux_capital`, majorations, `age_fin_garantie`), `affiliations.salaire_reference`, `assures` |
| Rentes de conjoint et d'éducation en service | `rentes`, `evenements` (`ouverture_service`, `modification_montant`, `suspension`, `reprise_service`, `fin_service`), `famille` (`date_naissance`, `sexe`, `handicap`), `garanties_souscrites` (`type_rente_conjoint`, `periodicite_prestation`, `terme_prestation`), `parametres` (`age_terme`, `age_limite`, `age_limite_etudes`, paliers), `prestations` (`fin_periode` : payé jusqu'au) |
| Rentes à constituer | `rentes` sans `ouverture_service`, `dossiers`, `sinistres`, `famille`, `beneficiaires`, `parametres.taux_rente`, `affiliations.salaire_reference` |
| Tardifs des rentes | Comme les tardifs du capital décès, sur les dossiers de rente ; coût moyen tiré de la famille « engagement » |
| Double effet (engagements en cours, dossiers potentiels, premiers décès tardifs, capitaux dus, événement catastrophe) | `sinistres` (`deces`), `dossiers` (`double_effet`), `evenements` (`second_deces`, `fixation_capital`), `famille` (conjoint, enfants), `parametres` (`double_effet`), `catastrophes`, `victimes` ; limites du contrat : `contrats`, `affiliations` |
| Incapacité : indemnités journalières en cours | `sinistres`, `evenements` (`entree_incapacite`, `rechute`, `sortie`, `ouverture_service`, `modification_montant`, `fin_service`), `dossiers` (`incapacite`), `parametres` (`franchise_jours`, `duree_max_jours`, `age_fin_service`, `taux_indemnite`), `garanties_souscrites` (`type_franchise`, `regle_complement`), `assures.date_naissance`, `prestations.fin_periode` |
| Provision d'invalidité en attente | Comme la ligne précédente, plus `parametres` (`invalidite` : `taux_rente` par catégorie, `age_fin_service`) et `affiliations.salaire_reference` |
| Incapacité : tardifs (passage futur compris) | `sinistres` (`arret_travail`), `dossiers`, `prestations` ; coût moyen tiré de la famille « engagement » |
| Invalidité : rentes en cours | `evenements` (`entree_invalidite`, `passage_invalidite`, `changement_categorie`, `ouverture_service`, `modification_montant`, `fin_service`, `sortie`), `rentes`, `parametres.age_fin_service`, `assures` |
| Invalidité : rentes à constituer des invalidités reconnues | `evenements` (`passage_invalidite` ou `entree_invalidite` sans `ouverture_service` sur la rente), `parametres.taux_rente`, `affiliations.salaire_reference` |
| Chargement de gestion de la PSAP | Aucune donnée propre (frais : hypothèse du plan) ; assiette = postes de la PSAP |
| Risque en cours dans les limites du contrat | `contrats` (`mois_echeance`, `jour_echeance`, `preavis_mois`, `tacite_reconduction`, `date_fin`), `affiliations` (en cours, portabilité comprise), `assures`, `garanties_souscrites`, `parametres` (`taux_cotisation`, `cotisation_forfaitaire`), `cotisations` |
| Provision pour égalisation | `contrats` (nature collective), `garanties_souscrites`, `cotisations` (acquises par exercice), `prestations`, provisions recalculées par l'outil |
| PPNA | `cotisations` (`nature_mouvement`, `debut_periode`, `fin_periode`, `montant`), `garanties_souscrites` (rattachement à la provision mathématique ou non : #14, point 7) |
| PREC | `cotisations`, `prestations`, `sinistres` (exercice de survenance) |
| Diagnostics (hors calcul) | `evaluations_gestion` (§ 7) ; cadences : `sinistres`, `prestations` |

## 9. Défauts de données (liste amendée, E2.4, M69)

**Règles communes :**
- **Injection** : le simulateur injecte chaque défaut **après** le tirage du jeu propre, par un flux aléatoire distinct, sans changer les tirages du jeu propre (E4.9).
- **Intensité** : la probabilité d'injection par unité éligible, dans [0 ; 1], où 0 signifie défaut absent. Elle est déclarée sans valeur par défaut dans la loi vraie, sous `defauts$<parametre>`.
- **Registre** : le simulateur tient un registre des défauts injectés (code, table, identifiants, colonne, valeur propre, valeur injectée). Ce registre fait partie de la loi vraie et n'est lu que par les tests.
- **Détection exacte** : le test exige que le nombre de lignes détectées égale le nombre de lignes injectées.
- **Détection présomptive** : le test est un constat de simulation (taux de détection, fausses alarmes mesurées sur le jeu propre, nombre de jeux, niveau) (E2.23).

| Code | Défaut | Tables et colonnes | Détection | Traitement | Intensité (simulateur) |
|---|---|---|---|---|---|
| **D01a** | Doublon d'identifiant | Clé primaire de toute table | exacte | **R** | `doublon_cle` : lignes de `sinistres`, `dossiers`, `evenements`, `prestations` dupliquées à l'identique |
| **D01b** | Doublon de contenu (identifiants distincts, mêmes valeurs) | `sinistres` (`id_assure`, `nature_sinistre`, `date_survenance`) ; `dossiers` (`id_sinistre`, `id_garantie_souscrite`) ; `evenements` (sinistre, dossier, rente, type, `date_effet`) ; `prestations` (dossier, rente, type, nature, `date_reglement`, période, montant) ; `cotisations` (garantie, nature, période, montant) | exacte sur ces colonnes | **X** par table et par famille ; signalé dans tous les cas | `doublon_contenu` : ligne recopiée sous un nouvel identifiant, saisie tirée après l'original |
| **D02a** | Ordre des dates violé | `date_naissance` > `date_survenance` ; `date_survenance` > `date_declaration` > `date_instruction` ; `debut_periode` > `fin_periode` ; `date_debut` > `date_fin` (affiliations, contrats, versions) ; date du premier état ≠ `date_survenance` | exacte | **X** par famille ; la documentation propose « exclure » pour la famille « triangle » et « conserver » pour « engagement » quand la date en cause n'y est pas lue | `date_ordre` : deux dates d'une ligne permutées |
| **D02b** | Date de saisie antérieure à l'événement | `evenements.date_saisie` < `date_effet` (types non programmables) ; `sinistres.date_saisie` < `date_declaration` ; ligne fille saisie avant sa parente | exacte | **H** : en vue à une date, date de visibilité retenue = max(date de saisie, date d'effet, visibilité de la parente). **S** à l'arrêté égal à l'extraction (sans effet). | `saisie_anterieure` : date de saisie tirée avant la date d'effet |
| **D02c** | Date hors bornes | Toute date : < 1901-01-01, ou > extraction hors futur admis ; âge hors des bornes de vraisemblance **déclarées dans le plan** | exacte | **R** pour une date hors domaine ; **S** + **X** par famille pour un âge invraisemblable | `date_hors_bornes` (sous-paramètres : part de sentinelles, part d'âges invraisemblables) |
| **D03a** | Date de naissance manquante | `assures`, `famille` | exacte | **H** : âge par défaut à la survenance ou à l'affiliation, par segment, ou **X** par famille ; **S** pour la famille « triangle », qui ne lit pas la colonne | `manquant_date_naissance` |
| **D03b** | Sexe manquant | `assures`, `famille` | exacte | **H** : sexe par défaut, **par poste** et par référentiel. Le point prudent dépend du poste : la mortalité basse prolonge une rente et réduit un capital décès attendu. | `manquant_sexe` |
| **D03c** | Salaire manquant | `affiliations.salaire_reference` | exacte | **H** : salaire de référence par défaut, par collège, ou **X** par famille | `manquant_salaire` |
| **D03d** | Situation de famille manquante | `assures.situation_familiale` | exacte | **H** : structure familiale par défaut (taux de conjoint, écart d'âge, nombre d'enfants, E2.20) | `manquant_situation_familiale` |
| **D03e** | Catégorie d'invalidité manquante | `evenements.categorie_invalidite` (types qui l'exigent) | exacte | **H** : catégorie par défaut | `manquant_categorie_invalidite` |
| **D03f** | Période couverte manquante | `prestations` (indemnités journalières, arrérages), `cotisations` | exacte | **H** : règle déclarée (prestation : période de la périodicité contractuelle qui finit à `date_reglement` ; cotisation : période de la périodicité qui commence au premier jour du mois du mouvement), ou **X** par famille | `manquant_periode_couverte` |
| **D03g** *(ajout)* | Date de saisie manquante | `evenements`, `prestations`, `sinistres`, `affiliations`, `famille`, `beneficiaires`, `rentes`, `contrats.date_saisie_fin` | exacte | **S** si l'arrêté égale l'extraction (tout est visible) ; pour un arrêté antérieur, **H** (date de visibilité = date d'effet + délai déclaré) ou **X** | `manquant_date_saisie` |
| **D04a** | Prestation sans sinistre | `prestations.id_dossier` manquant ou absent de `dossiers`, ou dossier sans sinistre | exacte | **X** par famille ; enjeu = montants | `prestation_orpheline` |
| **D04b** *(extension)* | Autre ligne orpheline | `evenements`, `beneficiaires`, `rentes`, `cotisations`, `victimes` : **X** ; `dossiers`, `sinistres`, `affiliations`, `famille`, `garanties_souscrites`, `parametres`, `contrats` : **R** ; (`id_contrat`, `college`) sans garantie souscrite : **R** | exacte | selon la table | `orpheline` (tables tirées : `evenements`, `rentes`, `cotisations`) |
| **D05** | Sinistre clos sans prestation ni motif | `sortie` ou `cloture_dossier` au `motif` manquant, sans prestation sur aucun dossier du sinistre | exacte | **H** : motif retenu déclaré (`sans_suite`) et règle de décompte déclarée (compté ou non dans le triangle des nombres) ; **S** | `clos_sans_motif` : motif effacé d'une clôture sans suite vraie |
| **D06** | Clôture sans justificatif | `sortie` (`reprise_travail`, `deces`), `fin_service` (`deces_beneficiaire`) au `justificatif` manquant | exacte pour l'absence ; le caractère erroné d'une clôture n'est pas observable | **S** (clôture retenue) ou **H** (clôture non retenue : dossier valorisé comme ouvert, point prudent des comptes sociaux) | `cloture_sans_justificatif` (justificatif effacé d'une clôture vraie) ; `cloture_erronee` (clôture sans justificatif ajoutée à un dossier vraiment ouvert) |
| **D07** | Extinction non enregistrée | Absence de `sortie` ou de `fin_service` | (a) **exacte** : sinistre décès de l'assuré, ou `second_deces` ou `fin_service` (`deces_beneficiaire`) sur un autre dossier du même bénéficiaire, alors que le service continue ; (b) **présomptive** : aucune prestation depuis plus de N mois (N déclaré) | (a) **H** (extinction retenue à la date du décès connu) ou **S** ; (b) **S** ou **X** par famille | `extinction_non_enregistree` (événement de sortie supprimé, prestations arrêtées à la date vraie) ; sous-paramètre `deces_connu_ailleurs` |
| **D08** | Rechute enregistrée comme nouveau sinistre | `sinistres`, `evenements`, `dossiers` | présomptive : nouveau sinistre `arret_travail` du même assuré dont la survenance suit une `sortie` (`reprise_travail`) de moins de `delai_rechute_jours` | **H** : rattachement déclaré (ancienneté depuis la survenance initiale, sinistre compté une fois) ; ou **S** (conservé distinct) | `rechute_nouveau_sinistre` |
| **D09** | Montant aberrant | `prestations.montant`, `evenements.montant`, `cotisations.montant`, `affiliations.salaire_reference`, `parametres.valeur` | exacte pour un signe contraire au domaine (refus de la ligne, **R**) ; présomptive pour un écart aux seuils **déclarés dans le plan** (rapport au plafond contractuel ou au salaire, multiple de la médiane du segment) | **S** ; **X** par famille ; jamais de correction (aucune division par 100) | `montant_aberrant` ; sous-paramètres `facteur` (ex. 100, centimes saisis en euros) et `part_signe_inverse` |
| **D10** | Incohérence entre garanties | `dossiers`, `garanties_souscrites`, `evenements`, `beneficiaires`, `victimes` | exacte | (a) garantie ou type de prestation incompatible avec la nature du sinistre : **R** ; (b) version de garantie hors vigueur à la survenance : **S** + **X** ; (c) dossier de rente ou de double effet sans dossier `deces` du même sinistre alors que la garantie décès est souscrite : **S** ; (d) `passage_invalidite` sans garantie `invalidite` souscrite : **S** ; (e) qualité du bénéficiaire incompatible avec la garantie : **X** ; (f) décès du conjoint saisi sur un dossier et pas sur l'autre (`second_deces` sans `fin_service` de la rente de conjoint, ou l'inverse) : **H** (extinction retenue) ou **S** ; (h) victime dont le sinistre est d'un autre assuré : **R** | `incoherence_garanties`, sous-paramètres par sous-cas |
| **D11** *(ajout)* | Sinistre hors période de couverture | `sinistres.date_survenance` face aux affiliations de l'assuré et à `contrats` | exacte, hors portabilité et hors maintien de la garantie décès | **S** ; **X** par famille | `hors_couverture` |
| **D12** *(ajout)* | Suite d'états impossible | `evenements` (automate du § 4) | exacte | **X** par sinistre, pour la famille « engagement » ; **S** pour la famille « triangle », qui ne lit pas les états | `suite_impossible` : événement d'état permuté ou dupliqué |

**Écarts à la liste d'E2.4 (à viser) :**
- D03g ajoute la date de saisie manquante aux manquants : elle conditionne la vue à une date.
- D04 étend « prestation sans sinistre » à toute ligne orpheline.
- D11 et D12 sont nouveaux.
- Aucun défaut d'E2.4 n'est retiré.
- La relecture de D01 et D02 en sous-cas ne change pas la liste.

**Phénomènes du portefeuille.** Ce ne sont pas des défauts. Ils sont tirés avec la loi vraie, ne reçoivent aucun traitement, et les diagnostics les signalent (M69) :
- déclarations tardives, y compris les décès identifiés par la recherche de l'organisme ;
- ruptures de cadence de déclaration, de saisie et de règlement ;
- radiations et affiliations saisies avec retard ;
- régularisations de prestations et de cotisations ;
- revalorisations ;
- suspensions de service ;
- rechutes correctement saisies ;
- sinistres sans suite motivés ;
- résiliations de contrats (maintien de la garantie décès) ;
- portabilité ;
- catastrophes avec victimes non encore déclarées.

## 10. Forme lisible par machine (ADR 0008, point 2, proposé)

Sous `inst/extdata/dictionnaire/` :
- `tables.csv` : table, objet, clé primaire, clés étrangères, caractère obligatoire ;
- `colonnes.csv` : table, colonne, type, valeurs admises ou bornes, unité, Obl., saisie, colonne de date de saisie de rattachement, futur admis, codes de défauts ;
- `types_evenements.csv` : le § 4, avec l'automate des transitions ;
- `parametres.csv` : le § 5 ;
- `defauts.csv` : le § 9, avec code, traitements admis, paramètre d'intensité et nature de la détection.

Un test de concordance compare ces fichiers aux tableaux du présent texte, que le module `donnees` lit et que le simulateur respecte. Les tableaux de ce texte gardent donc une forme régulière.

## 11. Points ouverts (à trancher par le mainteneur)

| N° | Point | Recommandation | Qui |
|---|---|---|---|
| P1 | Écarts à la liste des tables d'E2.1 et de l'ADR 0008 (§ 2.2) ; « colonne facultative » devient « table facultative » (M68) | Viser ; mettre E2.1, l'ADR 0008 (annotation) et `CONTEXT.md` (« Évaluation de gestion ») en accord | Mainteneur ; `architect` pour l'ADR et `CONTEXT.md` |
| P2 | Dates de saisie des affiliations, des prestations, des bénéficiaires et des rentes (ADR 0008 laissait la question au dictionnaire) | Les porter, comme proposé : sans elles, la population couverte et les paiements à un arrêté antérieur ne se reconstituent pas | Mainteneur |
| P3 | Montants de service portés par le journal des événements plutôt que par une table d'état | Viser (§ 2.2, point 4) | Mainteneur |
| P4 | Une seule assiette par affiliation en v1 (`salaire_reference`), commune à toutes les garanties | Viser pour la v1 ; une assiette par garantie (tranches distinctes) se traitera par une nouvelle version | Mainteneur |
| P5 | Nature de sinistre `iad` et `option_iad` | Conserver en attente du recensement des méthodes du capital décès (E1.5 ; B1, issue 5) | Recensement, puis mainteneur |
| P6 | Rentes d'accident du travail et de maladie professionnelle (taux d'incapacité permanente) | Hors v1 ; catégories `cat1` à `cat3` seulement | Mainteneur |
| P7 | Colonne inconnue du dictionnaire | Refus (contrat strict) plutôt qu'une colonne ignorée avec signalement | Mainteneur |
| P8 | Capitaux non réclamés : champ (décès non connus de l'organisme), délai et effet du dépôt à la Caisse des dépôts et consignations, taux de revalorisation légale | Le dictionnaire fournit `canal_declaration`, `depot_cdc` et `dont_revalorisation`, sans règle | `regulatory` (#14, point 5 ; #13) |
| P9 | Portée du maintien de la garantie décès (tous les arrêts, ou après résiliation seulement) | Les deux lectures se calculent sur ce dictionnaire | `regulatory` (#14, point 4) |
| P10 | Non-cumul de la PPNA et de la PREC avec la provision mathématique vie | Le dictionnaire fournit `code_garantie` et `nature_contrat` ; la règle relève de #14 | `regulatory`, `actuary` (#14, point 7) |
| P11 | Contrat individuel : souscripteur = assuré en v1 | Viser ; un souscripteur distinct, hors v1 | Mainteneur |
| P12 | Bornes de contrôle (`taux_technique_tarif` dans [−0,05 ; 0,10], dates ≥ 1901-01-01) | Viser comme jugement d'expert ; les bornes d'âge restent déclarées dans le plan | Mainteneur |
| P13 | Filiation avec les douze tables du dictionnaire double effet de `docu_actu` (M17), non relu | Faire établir la correspondance table à table par la session, avec accès au dépôt, avant le visa | Session principale |
| P14 | `situation_familiale` écrasée : valeur au décès pour un assuré décédé | Viser la convention ; la limite est restituée dans le rapport figé | Mainteneur |
| P15 | Historique antérieur à la fenêtre tronqué (événements du stock perdus à une migration) | Pas de défaut en v1 : l'extraction exige l'historique complet du stock (§ 1.9) ; un défaut « premier état manquant » pourra être ajouté par une nouvelle version | Mainteneur |
| P16 | Exclusion déclarée par famille de calcul (et non globale) | Viser : une date de déclaration incohérente rend un triangle faux, sans toucher la valeur actuelle probable d'une rente en service | Mainteneur |
| P17 | Base à plusieurs dates d'extraction pour le réalisé / attendu (ADR 0008, question non réglée) | Le dictionnaire suffit à une extraction unique vue à deux dates ; à trancher avec B10 | Mainteneur, B10 |
