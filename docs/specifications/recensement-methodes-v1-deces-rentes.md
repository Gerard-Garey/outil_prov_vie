# Recensement des méthodes — capital décès et rentes de conjoint et d'éducation (v1)

> *Rédigé par l'agent actuary-approfondi (IA) le 7 novembre 2026 (issue #20, branche `claude/socle-donnees`, PR #21). Révision 2 du même jour :*
> - *décisions du mainteneur sur les questions Q1 à Q12 (§ 2) ;*
> - *dictionnaire de la base en version `1.3` (commit `b31c5d6`) ;*
> - *intégration de la lecture de `regulatory` des points R1 à R10, partielle (R7 non traité ; R8 en partie ; la suite de ces deux lectures est en cours chez `regulatory`) ;*
> - *avis d'actuaire sur les décisions qui restent à soumettre (§ 14, circuit 2 : `regulatory` décrit, `actuary` éclaire, le mainteneur tranche).*
>
> *Révision 3 du même jour : décisions du mainteneur sur D1 à D7, Q5, Q13 et Q14 consignées (§ 2), toutes conformes aux recommandations ; rattachement des rentes à constituer fixé dans `postes.csv`.*
>
> *Statut : **soumis au visa du mainteneur** (E2.16) ; les branches B2 (capital décès), B3 (tardifs) et B4 (rentes) en partent. Le recensement des tardifs sera complété en B3 (`docs/feuille-de-route.md`, § 2, ligne B3).*
>
> *Résultats modifiés : aucun (aucun code).*

## 0. Objet, périmètre, lecture

### 0.1 Objet

E2.16 exige, avant l'implémentation d'un poste, l'inventaire des méthodes possibles. Pour chaque méthode, le présent document donne :

- son **statut** : recommandée, alternative, témoin, ou écartée avec son motif. Une méthode recommandée ou alternative est une **option** du plan. Une méthode « témoin » est écartée comme option, mais implémentée comme mesure de contrôle (E2.16, E2.23). Une méthode « écartée » n'est pas implémentée ;
- le **statut épistémique** du résultat et celui de sa **mesure d'incertitude** (E2.25) ;
- ses **conditions d'usage** ;
- les **données requises**, par renvoi aux tables et colonnes du dictionnaire de la base, version `1.3` (`docs/specifications/dictionnaire-base-v1.md`, ci-après « dictionnaire ») ;
- les **tables** et leurs usages ;
- les **textes** à l'appui ;
- les **packages de contre-vérification** hors CI (aucun ne dépend de Java).

Il propose aussi les lignes du catalogue des configurations de garanties de la v1 pour ces garanties : `etats.csv`, `transitions.csv` et `postes.csv` (ADR 0010, points 14 et 16), complétées de `flux.csv`, `usages_tables.csv` et `liens.csv`.

### 0.2 Postes couverts

| N° | Poste | Garantie (code du dictionnaire) | Branche |
|---|---|---|---|
| P1 | Sinistres déclarés non réglés | `deces` (invalidité absolue et définitive comprise, § 4) | B2 |
| P2 | Capitaux non réclamés et revalorisation légale | `deces` | B2 |
| P3 | Provision mathématique de la temporaire décès | `deces` | B2 |
| P4 | Tardifs du capital décès | `deces` | B3 |
| P5 | Rentes de conjoint et d'éducation en service | `rente_conjoint`, `rente_education` | B4 |
| P6 | Rentes à constituer | `rente_conjoint`, `rente_education` | B4 |
| P7 | Tardifs des rentes | `rente_conjoint`, `rente_education` | B4 |

**Hors du présent recensement**, sauf pour signaler un double compte possible ou une ligne du tableau de passage :
- le maintien de la garantie décès (B5 ; rattachement : M82) ;
- le double effet (B6 ; méthodes M1 à M9 du guide de `docu_actu`) ;
- le risque en cours dans les limites du contrat (B6) ;
- la provision pour égalisation du risque décès (R343-3, 8° ; B7).

### 0.3 Lecture

- **Statut épistémique** (E2.25) : exact, asymptotique, approximation, constat de simulation, jugement d'expert. Le statut du **montant** et celui de sa **mesure d'incertitude** sont donnés séparément.
- **Textes** :
  - « **vérifié (`regulatory`, 07/11)** » renvoie à la lecture de `regulatory` du 7 novembre 2026 sur #20, faite sur la consolidation LEGI de la DILA et sur le recueil ANC au 1er janvier 2025 (consolidation), avec l'empreinte de chaque article ;
  - « **établi (#14)** » renvoie aux commentaires de l'issue #14 ;
  - « **interprétation** » signale deux lectures, que le mainteneur tranche (§ 14) ;
  - « **à établir par `regulatory`** » signale un texte non encore lu.
  
  Aucun numéro d'article n'est cité sans lecture consignée.
- **Références de méthode** : statut au § 12.
- **Codes** : minuscules sans accents (E4.1). Le sigle « PM » n'est jamais employé (`CONTEXT.md`, G18).

## 1. Synthèse

| Poste | Comptes sociaux : rattachement | Méthode recommandée | Alternatives | Témoins | Statut du montant | Incertitude (statut) |
|---|---|---|---|---|---|---|
| P1 Déclarés non réglés | PSAP vie, compte 32 (M81) | `capital_dossier`, revalorisation acquise depuis le décès comprise (R132-3-1) | — | `chain_ladder_charges_recalculees`, `chain_ladder_paiements` | exact (capital fixé, taux de revalorisation déclaré) ; jugement d'expert (capital reconstitué, sans-suite en meilleure estimation) | sensibilités (différences exactes) |
| P2 Capitaux non réclamés | PSAP vie (extension de M81, D2 décidée) | `capital_revalorise` (revalorisation acquise, Q5 décidée) | `capital_revalorise_reglement` (en sensibilité) | — | exact sous le taux ; jugement d'expert en meilleure estimation | sensibilités |
| P3 Provision mathématique de la temporaire décès | provision mathématique vie (R343-3, 1°) ; famille « risque en cours » (Q2) | `prospective_prime_pure` (zillmérisée, plancher nul : A343-1-1) | `prospective_prime_declaree` ; `prorata_cotisation` (temporaire annuelle ; collectifs, Q3) | `retrospective` | exact sous les bases ; approximation (`prorata_cotisation`) | aléa de processus exact ; sensibilités |
| P4 Tardifs du capital décès | PSAP vie, sous-compte des tardifs (ANC 333-4, vérifié) | nombre : `chain_ladder_nombres` ou `bornhuetter_ferguson_nombres` ; coût : `cout_moyen_capital`, revalorisation légale courue depuis le décès comprise ; `victimes_recensees` (Q12) | `cape_cod_nombres`, `benktander_nombres`, `chain_ladder_charges_recalculees` | `chain_ladder_paiements`, `bootstrap_poisson_surdisperse` | exact (estimateur Chain Ladder) ; jugement d'expert (a priori, coût) | Mack (approximation) ; produit (approximation) |
| P5 Rentes en service | provision mathématique vie (M84), frais futurs de gestion compris (R343-3, 1°) ; arrérages échus non payés : PSAP vie (D1 décidée) | `vap_rente` | — (hypothèses) | `vap_monte_carlo` | exact sous les hypothèses | aléa de processus exact ; sensibilités |
| P6 Rentes à constituer | PSAP vie jusqu'à la liquidation ; provision mathématique vie dès `ouverture_service` (D1 décidée) | `vap_rente_reconstituee` ; `ouverture_ponderee` | `approche_par_tete` (différée à B6, Q9) | — | exact ; jugement d'expert | sensibilités |
| P7 Tardifs des rentes | PSAP vie, sous-compte des tardifs (ANC 333-4, vérifié) | nombre : `deces_tardifs_taux_ouverture` ; coût : `vap_moyenne_ouverture` | `vap_sinistre_type` ; `bornhuetter_ferguson_nombres` | `chain_ladder_dossiers_rentes` | comme P4 | comme P4 |

**Écartées sans témoin** :
- Merz-Wüthrich ;
- provision forfaitaire ;
- modèles linéaires généralisés à effets calendaires ;
- modèles individuels de délais ;
- copules entre conjoints ;
- provision pour risques croissants (PRC) sur la temporaire décès, exclue par le texte : R343-7, 5° (vérifié) ; item (2) de la branche `claude/prc` retiré (D5 décidée).

## 2. Données d'entrée du recensement

**Décisions antérieures**, prises telles quelles :
- M81 : PSAP vie (compte 32) pour les capitaux décès déclarés non réglés, à la valeur nominale, revalorisation acquise comprise.
- M84 : rentes de conjoint et d'éducation en lecture vie.
- M85 : indicateur A132-1 dès la v1 pour les rentes vie.
- M86 et défaut D03h : taux du tarif requis ; 0 % s'il manque.
- #14, point 7 (établi) : ni PPNA ni PREC en vie, et non-cumul de R343-3.
- E2.15.
- ADR 0005 (combinaison de deux familles ; une méthode, une implémentation).
- ADR 0010, points 14 à 16.

**Décisions du mainteneur du 7 novembre 2026 sur la révision 1** (transmises par la session principale) :

| Question | Décision |
|---|---|
| Q1 | `iad` et `option_iad` conservés, sans poste propre (§ 4) |
| Q2 | Provision mathématique de la temporaire en famille « risque en cours », module `risque_en_cours` créé dès B2 |
| Q3 | Fraction non échue des cotisations décès collectives payées d'avance couverte par la provision mathématique, au prorata |
| Q4 | Partage P1 / P2 par le critère déclaré ; décès inconnus de l'organisme dans les tardifs |
| Q6 | Taux de sans-suite et de reconnaissance de l'IAD nuls en comptes sociaux, centraux en meilleure estimation |
| Q7 | Origine de la survie des rentes en option du plan |
| Q8 | Tardifs des rentes par décès tardifs × taux d'ouverture × valeur actuelle moyenne à l'ouverture, lien `ouverture_rente` |
| Q9 | Approche par tête différée à B6 |
| Q10 | Chargement de gestion de la PSAP vie restitué comme flux de frais de chaque poste |
| Q11 | Facteur de queue déclaré, jugement d'expert |
| Q12 | Composante `victimes_recensees` dans les tardifs du capital décès |
| Q5, Q13 | Tranchées avec D2 et D5 (tableau suivant) |

**Décisions du mainteneur du 7 novembre 2026 sur la révision 2** (transmises par la session principale ; toutes conformes aux recommandations du § 14 ; numéros M121 à M128 attribués par `architect` dans `docs/feuille-de-route.md`, § 4) :

| Décision | Contenu | N° |
|---|---|---|
| D1 (R1) | Lecture mixte : rentes non liquidées (sans `ouverture_service`, dossiers potentiels compris) en **PSAP vie** ; **provision mathématique vie** dès `ouverture_service` ; **arrérages échus non payés en PSAP vie** ; rentes à constituer valorisées avec les mêmes taux, tables et frais que la provision mathématique (bases alignées, hypothèse déclarée) | M121 |
| D2 (R2) et Q5 | Capitaux non réclamés en **PSAP vie** (extension de M81) ; en comptes sociaux, **revalorisation acquise seule** ; `capital_revalorise_reglement` restitué en sensibilité ; choix à revoir sur mesure en B2 | M122 |
| D3 (R3) | **ANC 142-4** (tables de rentiers en vigueur à chaque inventaire) appliqué à la rente de conjoint temporaire | M123 |
| D4 (R4) | **Reconduction annuelle = souscription** ; taux de la version de garantie en vigueur à la survenance ; indicateur M85 à l'arrêté étiqueté « approximation », plus une ligne du même indicateur à la date d'effet de la version | M124 |
| D5 (R6) et Q13 | **Item (2) de la branche `claude/prc` retiré** ; la question des garanties complémentaires d'invalidité des contrats vie (R321-5) reste ouverte pour cette branche | M125 |
| D6 (R8) | Revalorisation des rentes des contrats résiliés : **hypothèse déclarée par segment**, montant figé sauf clause contractuelle de revalorisation par l'organisme résilié ; **provisoire** jusqu'à la relecture de la loi n° 89-1009, art. 7, en entier | M126 |
| D7 (R9) | **IAD = opération vie** (paiement anticipé du capital décès, sans prime distincte), en **PSAP vie** avec le capital décès | M127 |
| Q14 | Indicateur **`R132_3_1`** (minimum de revalorisation légale par année civile, depuis la série TME) restitué par le module `tables` ; taux retenu déclaré, un taux inférieur signalé (M62) | M128 |

**Lecture de `regulatory` du 7 novembre 2026 (#20)** : intégrée poste par poste ci-dessous. Lignes de registre proposées par `regulatory` : à reporter par la session principale.

## 3. Recensement poste par poste

### 3.1 P1 — Sinistres déclarés non réglés (capital décès)

**Rattachement.**
- Comptes sociaux : PSAP vie (M81).
- Solvabilité II : meilleure estimation ; ligne d'activité : lecture de `regulatory` en cours (R7).

**Périmètre.** En vue à la date d'arrêté :
- dossier `deces` ouvert, de sinistre `deces` ou `iad`, non clos ou rouvert ;
- capital dû diminué des paiements `capital` déjà faits.

Les capitaux exigibles et non réclamés sont un sous-ensemble, restitué à part (P2 ; critère de Q4 décidé).

| Méthode | Statut | Ce qu'elle calcule | Conditions d'usage | Statut ; incertitude |
|---|---|---|---|---|
| `capital_dossier` | **recommandée** (deux référentiels) | Capital : `fixation_capital` s'il existe ; sinon capital contractuel reconstitué (`taux_capital` × `salaire_reference`, majorations familiales, ou `capital_forfaitaire`). Moins les paiements `capital`. Plus la **revalorisation acquise à l'arrêté** : de la date du décès à celle de sa connaissance, la clause contractuelle si elle revalorise net de frais, sinon le taux légal ; de la connaissance du décès à l'arrêté, au moins le taux légal (R132-3-1, 1° à 3°, vérifié). Comptes sociaux : valeur nominale, taux de sans-suite nul (Q6). Meilleure estimation : flux à la date de paiement attendue, revalorisation à courir comprise, × (1 − taux de sans-suite), actualisés, plus les frais (règlement délégué, art. 31). | Tout dossier connu. Famille non instruite : majorations selon la structure familiale par défaut (E2.20). Taux de revalorisation légale : voir l'encadré « Revalorisation légale » ci-dessous. | **Exact** pour un capital fixé sous le taux déclaré ; **jugement d'expert** pour un capital reconstitué sous hypothèse par défaut, et pour le sans-suite et le délai en meilleure estimation. Sensibilités (différences exactes). |
| `chain_ladder_charges_recalculees` | **témoin** | Chain Ladder sur les charges recalculées (M65) : insuffisance des provisions dossier par dossier (IBNER). | Volume. | Écartée comme option : les montants connus seraient remplacés par une moyenne. |
| `chain_ladder_paiements` | **témoin** | Charge ultime totale (déclarés et tardifs), comparée à P1 + P4. | Cadence de règlement stable. | Même motif. |
| Évaluation de gestion (T18) | **hors méthode** | Diagnostic seulement (M68). | — | Jamais lue par le calcul. |

**Revalorisation légale** (vaut pour P1, P2, P4) :
- R132-3-1 (vérifié) fixe un **minimum par année civile, net de frais** : le moins élevé de deux taux, (a) la moyenne sur douze mois du taux moyen des emprunts de l'État au 1er novembre de l'année précédente, (b) le dernier taux moyen disponible à cette date.
- Ce minimum se calcule depuis la série TME, sous l'hypothèse que la série TME de la Banque de France est le « taux moyen des emprunts de l'État » du texte. Cette hypothèse est à déclarer, comme pour A132-1 (R4).
- Le module `tables` restitue ce minimum en **indicateur** par année civile (règle `R132_3_1`, Q14 décidée) ; le plan déclare le taux retenu ; un taux inférieur au minimum est signalé, non refusé (M62).
- Pour les mutuelles, R223-9 (vérifié) donne la même règle. Pour les institutions de prévoyance, CSS L932-23 renvoie aux articles législatifs du Code des assurances (vérifié), mais le décret de taux applicable est **non trouvé** (incertain) : le taux reste déclaré.

**Données requises.** Dictionnaire, § 8, ligne « Capital décès : sinistres déclarés non réglés ». La date du décès est `sinistres.date_survenance` ; la date de connaissance est `sinistres.date_declaration`.

Défauts lus : D03c, D09 (dont le capital incohérent), D05, D06, D10 (a) et (b), D11, D13.

**Tables.**
- Comptes sociaux : série TME (indicateur `R132_3_1`).
- Meilleure estimation : courbe des taux sans risque.

**Textes.**
- PSAP vie, compte 32 (ANC 333-4, vérifié ; M81).
- Aucun texte de calcul de la PSAP vie (vérifié, R10). L'emploi d'ANC 143-10 (dossier par dossier) et 143-11 (chargement) est une hypothèse déclarée par analogie ; l'obligation est celle de 141-1, « suffisantes pour le règlement intégral ».
- L132-5, 3e alinéa (revalorisation du décès jusqu'à la réception des pièces ou au dépôt) et R132-3-1 (taux, point de départ), tous deux vérifiés.
- Mutuelles : L223-19-1, R223-9 (vérifiés). Institutions de prévoyance : CSS L932-23 (vérifié) ; décret de taux non trouvé.
- Application aux contrats **collectifs** des entreprises d'assurance : **incertain** (aucun texte lu ne les exclut ni ne les nomme). Le plan déclare la revalorisation par segment.

**Limites.**
- Pas de majoration accidentelle dans le dictionnaire v1 : un capital non fixé d'une telle garantie est sous-estimé, limite à restituer.
- Chargement de gestion : flux de frais de chaque poste (Q10).

### 3.2 P2 — Capitaux non réclamés et revalorisation légale

**Rattachement.**
- Comptes sociaux : **PSAP vie** (D2 décidée ; lecture (a) de `regulatory` : compte 32, montant liquidé, ANC 223-1).
- Solvabilité II : meilleure estimation.

**Champ** (Q4 décidé) : décès **connus**, capital exigible non réglé, et critère du plan (bénéficiaire `non_identifie`, ou aucune réclamation depuis N mois déclarés). Les décès inconnus de l'organisme sont des tardifs (P4) ; la frontière est compatible avec le texte (lecture de `regulatory`, R2, point 5).

| Méthode | Statut | Ce qu'elle calcule | Conditions d'usage | Statut ; incertitude |
|---|---|---|---|---|
| `capital_revalorise` | **recommandée** | Comptes sociaux : capital dû + revalorisation **acquise** depuis le décès jusqu'à l'arrêté (R132-3-1 ; voir P1). Meilleure estimation : flux jusqu'à la réception des pièces (loi de réclamation déclarée) ou jusqu'au **dépôt à la Caisse des dépôts et consignations**, dix ans après la prise de connaissance du décès, dans le mois suivant (L132-27-2, I, 1er alinéa, vérifié) ; revalorisation à courir comprise ; actualisés. | Le dépôt est **libératoire** (L132-27-2, I, 6e alinéa, vérifié) : le poste s'éteint au dépôt (`cloture_dossier` motif `depot_cdc`, prestation `capital` datée du dépôt). Pas de dépôt pour une temporaire décès dont le décès est antérieur au 1er janvier 2015 (même alinéa) : le dossier reste provisionné sans terme légal. Mutuelles : L223-25-4 et R223-11 (date de connaissance = obtention de l'acte de décès), vérifiés. | Comptes sociaux : **exact** sous le taux déclaré. Meilleure estimation : **jugement d'expert** (loi de réclamation). Sensibilités. |
| `capital_revalorise_reglement` | **alternative** (comptes sociaux), restituée en sensibilité (Q5 décidée ; à revoir sur mesure en B2) | Capital + revalorisation **à courir jusqu'au règlement attendu ou au dépôt**, non actualisée. Point prudent. | Le texte fixe un minimum par année civile, non une règle de provisionnement (lecture de `regulatory`, R2, point 6) : c'est un jugement d'expert. | **Jugement d'expert** (date de règlement). |

**Données requises.** Dictionnaire, § 8, ligne « Capitaux non réclamés ». La date de prise de connaissance est `sinistres.date_declaration`. Pour un décès identifié par la recherche de l'organisme (`canal_declaration = recherche_organisme`), la date de déclaration vaut date de prise de connaissance : c'est une convention à déclarer.

**Textes** (corrigés par rapport à la révision 1) :
- L132-5, **3e alinéa** (revalorisation du décès jusqu'à la réception des pièces ou au dépôt) ;
- L132-5, 4e et dernier alinéa (plancher de taux fixé par décret) ;
- R132-3-1 (taux) ;
- **L132-27-2** (dépôt à la Caisse des dépôts et consignations ; version en vigueur depuis le 24/05/2019, loi n° 2019-486, art. 71). La citation « loi n° 2014-617, art. 13 » est retirée (numéro non relu ce jour) ;
- mutuelles : L223-19-1, R223-9, L223-25-4, R223-11 ;
- institutions de prévoyance : CSS L932-23 (renvoi), décret de taux non trouvé.

Tous sont vérifiés (`regulatory`, 07/11), sauf le décret de taux des institutions de prévoyance.

### 3.3 P3 — Provision mathématique de la temporaire décès

**Rattachement.**
- Comptes sociaux : provision mathématique vie (R343-3, 1°, vérifié), au taux retenu ≤ taux du tarif, avec les tables de l'époque du tarif ou, par faculté, les tables en vigueur à l'inventaire (ANC 142-3, vérifié).
- Solvabilité II : pas de poste propre. Ligne du tableau de passage « provision mathématique de la temporaire → limites du contrat » (B6) ; `meilleure_estimation = FALSE`.
- **Famille « risque en cours »** (Q2 décidée) : module `risque_en_cours` dès B2, qui appelle la fonction commune `valeur_actuelle_probable()`. Restitution par contrat.

**Champ.**
- (a) Contrats **individuels** temporaires décès, à prime unique ou périodique.
- (b) Fraction **non échue** de la couverture des contrats **collectifs** décès payée d'avance (Q3 décidée).

| Méthode | Statut | Ce qu'elle calcule | Conditions d'usage | Statut ; incertitude |
|---|---|---|---|---|
| `prospective_prime_pure` | **recommandée** (individuels) | Valeur actuelle probable du capital (et, pour une **prime unique**, des frais futurs de gestion au montant des chargements de gestion tarifaires, puisque toute la couverture est postérieure au paiement des primes : R343-3, 1°, 2e phrase, vérifié). Moins la valeur actuelle probable des primes futures de l'assuré : prime pure recalculée par équivalence à la date d'effet, avec la table et le taux du tarif, **augmentée des chargements d'acquisition** pour un contrat à primes périodiques (zillmérisation : A343-1-1, 1er alinéa, vérifié). **Plancher nul par contrat** (A343-1-1, 2e alinéa ; « par contrat » est une interprétation forte, non littérale, selon `regulatory`). Échéancier daté. | Table du tarif déclarée par usage (`mortalite_tarif`). `taux_technique_tarif` (sinon D03h). Taux de chargement d'acquisition et de chargement de gestion tarifaires déclarés dans le plan (le dictionnaire ne les porte pas). Les déclarer à 0 est un jugement d'expert prudent (provision plus forte) ; l'effet est chiffré par sensibilité. | **Exact** sous les bases. Aléa de processus exact (variance de la valeur actuelle) ; sensibilités à la table, au taux et aux chargements. |
| `prospective_prime_declaree` | **alternative** | Même calcul, avec la prime payée diminuée d'un taux de chargement déclaré. | Table du tarif inconnue ou tarif non actuariel. | **Jugement d'expert** (chargement). |
| `prorata_cotisation` | **alternative** ; méthode du champ (b) | Cotisation émise nette d'un chargement déclaré, au prorata de la période couverte postérieure à l'arrêté. | Couverture d'une période au plus, prime de risque de la période. Pour les contrats collectifs en cas de décès résiliables annuellement, A132-18 admet un tarif établi « avec une méthode forfaitaire si celle-ci est justifiable » (vérifié) : la provision au prorata en est la contrepartie. | **Approximation** de la provision d'une temporaire d'une période (égalité si le risque est uniforme sur la période et la prime pure). |
| `retrospective` | **témoin** | Accumulation des primes passées moins le coût du risque ; égale à la prospective sous les mêmes bases (Norberg 1991). | — | Égalité **exacte** : recoupement de l'implémentation. |

**Provision pour risques croissants : écartée par le texte.** R343-7, 5° (vérifié) la prévoit « pour les opérations d'assurance contre les risques de maladie et d'invalidité ». R343-3 (vie) n'en a pas et interdit le cumul. La croissance du risque d'une temporaire à prime nivelée est portée par la provision mathématique. L'item (2) de la branche `claude/prc` était donc non conforme : il est retiré (D5 décidée).

**Invalidité absolue et définitive** : sans table d'incidence, l'IAD est comprise dans la mortalité (jugement d'expert : l'effet porte sur la date de versement, non sur le montant). Avec une table `incidence_iad`, c'est une transition `actif` → `iad`.

**Données requises.** Dictionnaire, § 8, ligne « Provision mathématique de la temporaire décès ». Pour le champ (b), en plus : `cotisations` (`debut_periode`, `fin_periode`, `montant`, `nature_mouvement` ; D03f) et `garanties_souscrites` (`nature_contrat` collectif).

**Tables.** `mortalite_tarif` ; `incidence_iad` (facultative). Contrôle `tarif_vie` (M62, M63).

**Textes.**
- R343-3, 1° (mot à mot, frais) ; A343-1-1 ; ANC 142-2 et 142-3 ; A132-18 (méthode forfaitaire des collectifs en cas de décès) ; R343-7, 5°. Tous vérifiés (`regulatory`, 07/11).
- Sens de « souscription » pour la reconduction : reconduction annuelle = souscription (D4 décidée).

### 3.4 P4 — Tardifs du capital décès

**Rattachement.**
- Comptes sociaux : PSAP vie, **sous-compte des tardifs** du compte 32 (ANC 333-4, vérifié). Aucun texte de calcul : l'analogie avec ANC 143-10 est une hypothèse déclarée (R10, vérifié).
- Solvabilité II : meilleure estimation.

**Définition.** Décès (et IAD) survenus avant l'arrêté et non déclarés à l'arrêté. Un décès déclaré non instruit relève de P1 et, pour ses rentes, de P6. Le poste combine deux familles : nombre (« triangle ») × coût moyen (« engagement »), plus la composante catastrophe (Q12).

**Composante « nombre »** (triangle des nombres, période déclarée) :

| Méthode | Statut | Ce qu'elle calcule | Conditions d'usage | Statut ; incertitude |
|---|---|---|---|---|
| `chain_ladder_nombres` | **recommandée** (cadence stable, survenance développée) | Tardifs = nombre ultime − nombre déclaré ; modèle de Mack (1993). | Cadence stable, segment homogène (gestionnaire, `date_debut_gestion`). Aucun seuil de volume : la puissance se mesure (E2.3). Facteur de queue déclaré (Q11). | Montant **exact** (estimateur) ; erreur quadratique de prédiction de Mack : **approximation** sous le modèle (E2.15). |
| `bornhuetter_ferguson_nombres` | **recommandée** (survenances récentes, faible volume) | A priori × (1 − 1 / facteur jusqu'à l'ultime) (Bornhuetter et Ferguson 1972, p. 187). A priori : décès attendus sur l'effectif couvert reconstitué des affiliations (table `mortalite_attendue`), ou a priori déclaré. Les IAD ne sont pas couvertes par un a priori de mortalité (§ 4). | Effectif couvert reconstitué fiable ; les assurés couverts sans affiliation en cours (maintien après résiliation) manquent : limite restituée. | Montant : **jugement d'expert** (a priori). Mesure : sensibilité à l'a priori en v1 ; formule de Mack (2008) en alternative de B3 (approximation sous son modèle). |
| `cape_cod_nombres` | **alternative** | Stanard-Bühlmann : taux de décès par unité d'effectif couvert estimé sur le triangle (Gluck 1997, éq. 5.1, p. 491), puis Bornhuetter-Ferguson. | Taux de décès constant entre survenances, après ajustement de la structure d'âge. | Montant **exact** sous l'hypothèse d'un taux commun ; pas de mesure d'incertitude en v1. |
| `benktander_nombres` | **alternative** | Bornhuetter-Ferguson itéré, crédibilité égale à la part développée (Mack 2000, p. 334-335). | Celles de Bornhuetter-Ferguson. | **Jugement d'expert** (a priori) ; erreur quadratique plus faible dans le modèle simple de Mack (2000) : constat dans ce modèle, non garantie. |
| `bootstrap_poisson_surdisperse` | **témoin** | Loi simulée de la provision (England et Verrall 2002). Le modèle de Poisson surdispersé reproduit Chain Ladder (England et Verrall 2001, p. 11 ; Dahms 2021, th. 5.3). | Graine ; nombre de réplications. | Écarté comme option : aucun quantile n'est restitué. **Constat de simulation** ; l'erreur de simulation est distincte de l'erreur d'estimation. |
| `chain_ladder_paiements` | **témoin** | Charge ultime totale. | — | Mêle les délais ; remplace des capitaux connus par une moyenne. |
| Merz-Wüthrich ; provision forfaitaire ; modèles linéaires généralisés à effets calendaires ; modèles individuels de délais | **écartées** | — | — | Horizon d'un an hors périmètre (E1.4) ; la provision forfaitaire ne suit pas la cadence ; triangles maigres (E2.3). À rouvrir en B3 si les diagnostics le demandent. |

**Composante « coût moyen »** (révisée : la revalorisation légale court dès le décès, R132-3-1, 1° et 3°, vérifié) :

| Méthode | Statut | Ce qu'elle calcule | Conditions | Statut |
|---|---|---|---|---|
| `cout_moyen_capital` | **recommandée** | Capital moyen des dossiers déclarés des dernières survenances du segment, ramené au niveau de l'arrêté (revalorisation des salaires déclarée). Il est multiplié par le **facteur de revalorisation légale courue de la date de décès à l'arrêté** (comptes sociaux, comme la revalorisation acquise de P1, Q5 décidée), ou jusqu'au règlement attendu (meilleure estimation). La date de décès d'un tardif n'est pas connue : on retient, par période de survenance, une date moyenne de décès sous une répartition dans la période déclarée (convention), pondérée par la cadence. | Segment homogène ; capitaux atypiques revus comme sinistres graves. | Montant **exact** pour la moyenne. Facteur de revalorisation : **approximation** (date de décès moyenne). Produit nombre × coût : **approximation** (indépendance supposée). |
| `chain_ladder_charges_recalculees` | **alternative** | Montant des tardifs sans coût moyen ; la charge recalculée doit comprendre la revalorisation acquise à chaque date du triangle. | Triangle de charges recalculées (M65). | Exact (calcul) ; Mack. |

**Composante « événement catastrophe »** (Q12 décidée) : `victimes_recensees`, **recommandée** si T16 et T17 sont présentes. Victimes `decedee` sans `id_sinistre`, assurées couvertes, au capital contractuel reconstitué, revalorisation légale depuis `victimes.date_deces` comprise. Leurs sinistres sont neutralisés dans le triangle. Statut : **exact** sous la liste.

**Données requises.** Dictionnaire, § 8, ligne « Capital décès : tardifs ». Défauts lus : D01b, D02a, D02b, D03g, D11, D10 (h).

**Tables.** `mortalite_attendue` ; série TME (revalorisation) ; courbe des taux sans risque (meilleure estimation).

### 3.5 P5 — Rentes de conjoint et d'éducation en service

**Rattachement.**
- Comptes sociaux : provision mathématique vie (M84) ; taux retenu ≤ taux du tarif ; indicateur A132-1 (M85) à l'arrêté, étiqueté « approximation », plus une ligne à la date d'effet de la version de garantie en vigueur à la survenance (D4 décidée).
- Les **frais futurs de gestion** sont inclus : la provision mathématique d'un contrat « faisant intervenir une table de survie ou de mortalité » les comprend « au-delà de la durée de paiement des primes », au montant des chargements de gestion tarifaires (R343-3, 1°, vérifié). Une rente servie après le décès est tout entière au-delà du paiement des primes.
- Arrérages échus non payés : **PSAP vie** (D1 décidée), restitués à part.
- Solvabilité II : meilleure estimation.

**Modèle de référence** : modèle multi-états des bénéficiaires (E2.11 ; Dickson, Hardy et Waters 2020, chap. 8 ; Norberg 1991).

| Méthode | Statut | Ce qu'elle calcule | Conditions d'usage | Statut ; incertitude |
|---|---|---|---|---|
| `vap_rente` | **recommandée** (deux référentiels ; une implémentation, partagée avec l'invalidité en B5) | Valeur actuelle probable de l'échéancier daté des arrérages futurs et des frais futurs de gestion, à partir de la fin de la dernière période payée, au montant en vigueur reconstitué des événements. **Conjoint** : rente viagère ou temporaire (`age_terme`), mortalité, remariage si `non_remariage`. **Éducation** : jusqu'à `age_limite`, prolongée selon la poursuite d'études ; viagère si `prolongation_handicap` et `situation = handicape` ; paliers d'âge. Fractionnement exact. Rente suspendue : provisionnée en comptes sociaux, probabilité de reprise en meilleure estimation. Revalorisation future : hypothèse déclarée ; pour les contrats résiliés, par segment, montant figé sauf clause (D6 décidée, provisoire). | Hypothèses déclarées sans défaut : table par usage (§ 14, D3) ; remariage ; poursuite d'études (service certain jusqu'à `age_limite_etudes` pour un enfant scolarisé ou apprenti à la dernière information : point prudent, E2.15) ; origine de la survie en option du plan (Q7 décidée) ; taux de chargement de gestion tarifaire (absent du dictionnaire : déclaré). | **Exact** sous les hypothèses. Aléa de processus exact ; erreur de modèle par sensibilités. Aucune erreur d'estimation propre (tables en entrée). |
| `vap_monte_carlo` | **témoin** | Simulation des trajectoires, contrôle du calcul exact. | Graine. | **Constat de simulation** ; l'écart est une erreur de simulation. |
| Coût moyen × nombre ; table d'expérience construite par l'outil ; copules | **écartées** | — | — | Données dossier par dossier disponibles ; tables toujours en entrée (ADR 0009) ; la dépendance entre conjoints ne joue plus après le premier décès. |

**Données requises.** Dictionnaire, § 8, ligne « Rentes de conjoint et d'éducation en service ». Défauts lus : D03a, D03b, D03h, D06, D07 (a) et (c), D10 (f).

**Tables.**

| Usage | Contenu |
|---|---|
| `mortalite_conjoint_cs` | Rente viagère et rente temporaire (D3 décidée) : **tables de A132-18 en vigueur à chaque inventaire** (ANC 142-4, vérifié, qui prime sur 142-3). Mutuelles : A223-8 ; institutions de prévoyance : A932-3-11 (non lus). |
| `mortalite_conjoint_be` | Table de meilleure estimation. |
| `mortalite_enfant_be` | Mortalité des enfants en meilleure estimation ; en comptes sociaux, service certain. |
| `mortalite_handicape` | Facultative. |
| `poursuite_etudes` | Poursuite des études. |
| `remariage` | Facultative. |
| `tme` | Indicateurs A132-1 et R132-3-1. |
| `courbe_be` | Courbe des taux sans risque. |

La table unique de A132-18-1 est une faculté de **tarif** pour les contrats de L911-1 du Code de la sécurité sociale. Son contenu n'est pas lu (fac-similé du JO) et sa reprise en provision est une interprétation (R3).

**Textes.** R343-3, 1° ; ANC 142-3, 142-4 ; A132-18 ; A132-18-1 (texte, sans la table), tous vérifiés. Loi n° 89-1009, art. 7 (non relu en entier ce jour) et CSS L912-3 (vérifié) pour la revalorisation après résiliation (D6 décidée, provisoire ; relecture de l'art. 7 : lecture de `regulatory` en cours). ANC 143-3 (date de naissance reportée au 31 décembre le plus voisin) est rangé au chapitre des opérations autres que vie : son emploi pour une rente vie est une convention du plan.

### 3.6 P6 — Rentes à constituer

**Rattachement.**
- Comptes sociaux (D1 décidée, lecture mixte) : **PSAP vie** (compte 32) pour les trois situations ci-dessous, par analogie avec R343-7, 4° (« capitaux constitutifs des rentes non encore mises à la charge de l'entreprise », vérifié, autres opérations) et ANC 223-1 ; la rente passe en **provision mathématique vie** (P5) à son `ouverture_service`. Bases alignées : taux ≤ taux du tarif, tables de 142-4, frais au niveau des chargements de gestion tarifaires (hypothèse déclarée).
- Solvabilité II : meilleure estimation.

**Trois situations**, chacune restituée à part :
1. rente créée sans `ouverture_service` ;
2. dossier de rente sans ligne `rentes` ;
3. décès (ou IAD) déclaré, garantie de rente souscrite, instruction pendante ou absente (D13).

| Méthode | Statut | Ce qu'elle calcule | Conditions d'usage | Statut ; incertitude |
|---|---|---|---|---|
| `vap_rente_reconstituee` | **recommandée** (situations 1 et 2, famille instruite) | `vap_rente` au montant reconstitué (`taux_rente` × `salaire_reference`, palier), droits ouverts à la date contractuelle (hypothèse déclarée), arrérages échus depuis compris, frais alignés sur la provision mathématique (D1). | Famille instruite. | **Exact** sous les hypothèses ; sensibilités. |
| `ouverture_ponderee` | **recommandée** (situation 3 ; situation 2 sans famille) | Probabilité d'ouverture × valeur actuelle probable sous la structure familiale par défaut (E2.20), à l'âge et au salaire du décédé ; taux mesurés par diagnostic sur les sinistres instruits (constat empirique). Même structure que le double effet (une seule hypothèse du plan). | Situation familiale déclarée si récente (seuil déclaré), sinon structure par défaut. Lien `ouverture_rente` (Q8 décidée). | **Jugement d'expert** ; sensibilité. |
| `approche_par_tete` | **alternative**, implémentée en B6 (Q9 décidée) | Probabilité d'ouverture propre au décédé, tirée de l'information de famille des vivants (T19, T20, situation déclarée). | Conditions de P18. | Jugement d'expert ; erreur d'estimation du calibrage. |

**Frontières.** Avec P7 : un décès non déclaré relève de P7, un décès déclaré non instruit de P6. Avec le double effet (B6) : dossiers distincts d'un même sinistre, même structure familiale par défaut.

**Données, tables, textes.** Ceux de P5, plus `sinistres.date_instruction`, les garanties de rente souscrites et `assures` (situation déclarée). Défauts : D13, D03c, D03d. Aucun défaut « dossier de rente non ouvert » n'existe en v1 : un contrôle de signalement est à proposer avec le module `donnees` en B4.

### 3.7 P7 — Tardifs des rentes

**Rattachement.**
- Comptes sociaux : **PSAP vie, sous-compte des tardifs** (ANC 333-4 : existence du compte vérifiée, aucun texte de calcul).
- Solvabilité II : meilleure estimation.

| Méthode | Statut | Ce qu'elle calcule | Conditions d'usage | Statut ; incertitude |
|---|---|---|---|---|
| `deces_tardifs_taux_ouverture` (nombre) | **recommandée** (Q8 décidée) | Décès tardifs du triangle des décès (méthodes de P4, même implémentation), restreints aux contrats qui ont souscrit la rente, × taux d'ouverture mesuré sur les sinistres instruits récents, ou déclaré. | Lien `ouverture_rente`. | Comme P4 ; produit en **approximation**. |
| `vap_moyenne_ouverture` (coût) | **recommandée** | Valeur actuelle probable moyenne à l'ouverture des dossiers récents, recalculée avec le plan courant, ramenée à l'arrêté, arrérages courus depuis le décès compris. | Volume ; segment homogène. | **Exact** (moyenne) ; erreur d'estimation. |
| `vap_sinistre_type` (coût) | **alternative** | Sinistre type sous la structure familiale par défaut. | Faible volume. | **Jugement d'expert**. |
| `bornhuetter_ferguson_nombres` (nombre) | **alternative** | Comme P4, sur le triangle des décès. | Survenances récentes. | Jugement d'expert. |
| `chain_ladder_dossiers_rentes` | **témoin** | Triangle des dossiers de rente (décès × ouverture). | — | Mêle les délais de déclaration et d'instruction ; compte deux fois les décès non instruits de P6. |

## 4. Invalidité absolue et définitive (Q1 décidée)

`iad` et `option_iad` sont conservés, sans poste propre ; aucune nouvelle version du dictionnaire.

1. IAD déclarée et reconnue, non réglée : P1, `capital_dossier`.
2. IAD **en cours de reconnaissance** : même poste, avec une probabilité de reconnaissance déclarée (jugement d'expert ; aucun texte de calcul : `regulatory`, R9). Comptes sociaux : 1 (Q6) ; meilleure estimation : taux central.
3. Tardifs : dans le triangle de P4, avec une segmentation `nature_sinistre` en option si les cadences diffèrent. L'a priori de mortalité de Bornhuetter-Ferguson ne couvre pas les IAD.
4. Rentes ouvertes par une IAD : P5 à P7.
5. Frontière avec le maintien de la garantie décès : B5.

Classement : opération vie, PSAP vie (D7 décidée).

## 5. Meilleure estimation et tableau de passage

Mêmes méthodes, hypothèses différentes. Lignes propres à ces postes, dans un ordre de substitution déclaré (E2.17) :

| Ligne | Postes | Comptes sociaux | Meilleure estimation |
|---|---|---|---|
| Table de mortalité | P3, P5 à P7 | table du tarif (P3) ; tables de 142-4 (rentes viagères) | table réaliste |
| Taux | P3, P5 à P7 ; actualisation de P1, P2, P4 | taux ≤ taux du tarif ; capitaux non actualisés | courbe des taux sans risque, sans correction pour volatilité |
| Revalorisation légale | P1, P2, P4 | acquise à l'arrêté (Q5 décidée ; revalorisation à courir en sensibilité) | jusqu'au règlement ou au dépôt |
| Revalorisation des rentes | P5 à P7 | garantie par le contrat ; contrats résiliés : figée sauf clause (D6, provisoire) | attendue |
| Sans-suite, reconnaissance de l'IAD | P1, § 4 | 0 (Q6) | central |
| Poursuite d'études, remariage, origine de la survie | P5 à P7 | points prudents | centraux |
| Hypothèses par défaut | tous | prudentes | centrales |
| Frais | tous | chargement déclaré (PSAP vie) ; chargements de gestion tarifaires (provision mathématique, R343-3, 1°) | frais de l'art. 31 du règlement délégué |
| Provision mathématique de la temporaire → limites du contrat | P3 | provision mathématique | risque en cours (B6) |

## 6. Témoins et constats de simulation (E2.23)

| Poste | Provision vraie | Test |
|---|---|---|
| P1, P2 | Capital × probabilité vraie de règlement, revalorisation vraie depuis le décès | Biais. Un jeu dont la loi vraie égale les hypothèses du plan est un **recoupement**, non un constat. |
| P3 | Valeur actuelle probable sous la loi vraie | Couverture des flux futurs simulés ; erreur de modèle sous une loi vraie différente. |
| P4, P7 | Nombre attendu de décès non déclarés (intensité et délais du simulateur) × coût vrai, revalorisation depuis la date vraie du décès | **Constat de simulation** (nombre de jeux, niveau, région d'acceptation, fausse alarme, puissance) ; couverture de Mack ; témoin bootstrap. La date moyenne de décès de `cout_moyen_capital` se mesure contre les dates vraies. |
| P5, P6 | Valeur actuelle probable sous la loi vraie, sachant l'état vrai à l'arrêté | Biais ; témoin `vap_monte_carlo` ; enjeu de D07. |

Les jeux de mesure de l'erreur de modèle sont tirés sous une loi vraie différente des tables du plan : un jeu tiré sous le modèle exact de la méthode rend le test tautologique.

## 7. Contre-vérification hors CI et recoupements en CI

| Package (version lue le 7 novembre 2026) | Fonctions | Contre-vérifie | Java |
|---|---|---|---|
| `ChainLadder` 0.2.21 | `MackChainLadder`, `chainladder`, `ata`, `BootChainLadder`, `glmReserve` | P4, P7 ; témoin bootstrap | aucune dépendance à `rJava` (`Imports` relus : Matrix, actuar, methods, stats, lattice, grid, tweedie, utils, systemfit, statmod, cplm, ggplot2, MASS) |
| `lifecontingencies` 1.6.3 | `axn` (`k`, `m`, `payment`), `Axn`, `Exn` | P3, P5, P6 sur des cas à une tête | non (Rcpp) |

Bornhuetter-Ferguson, Cape Cod et Benktander se contre-vérifient par leurs formules fermées, à partir des facteurs de `chainladder()`. Aucune fonction de Bornhuetter-Ferguson n'a été repérée dans la partie lue de la documentation, et `ClarkCapeCod` est une autre méthode.

Recoupements en CI :
- `stats::glm(family = quasipoisson)` reproduit Chain Ladder ;
- égalité prospective / rétrospective (P3) ;
- minimum de R132-3-1 recalculé depuis la série TME par une seconde voie.

## 8. Proposition de catalogue de la v1 pour ces garanties

Formes de l'ADR 0010, points 14 et 16. Les points A1 à A5 (§ 11) sont pour `architect`.

### 8.1 `etats.csv`

```csv
etat,individu,absorbant,description
actif,assure,FALSE,Assuré couvert et vivant
deces,assure,TRUE,Assuré décédé (fait générateur du capital décès et des rentes)
iad,assure,TRUE,Invalidité absolue et définitive reconnue : capital versé par anticipation, couverture décès éteinte
sorti,assure,TRUE,Couverture terminée sans sinistre (terme, résiliation, rachat) ; meilleure estimation seulement
conjoint_survivant,beneficiaire,FALSE,Conjoint survivant bénéficiaire d'une rente de conjoint
conjoint_decede,beneficiaire,TRUE,Conjoint survivant décédé
conjoint_remarie,beneficiaire,TRUE,Conjoint survivant remarié (si non_remariage)
enfant_a_charge,beneficiaire,FALSE,Enfant à charge avant l'âge limite
enfant_etudes,beneficiaire,FALSE,Enfant poursuivant des études ou un apprentissage entre age_limite et age_limite_etudes
enfant_handicape,beneficiaire,FALSE,Enfant handicapé à charge sans limite d'âge (prolongation_handicap)
enfant_fin_charge,beneficiaire,TRUE,Fin de la charge (âge limite atteint, fin d'études)
enfant_decede,beneficiaire,TRUE,Enfant décédé
```

Les fins déterministes (âge limite, `age_terme`, `age_fin_garantie`) bornent un flux et ne sont pas des transitions (A2).

### 8.2 `transitions.csv`

```csv
depuis,vers,usage,pas,axes,decomposition
actif,deces,mortalite_tarif,an,age,
actif,deces,mortalite_attendue,an,age,
actif,deces,mortalite_assure_be,an,age,
actif,iad,incidence_iad,an,age,facultative ; sans table : IAD comprise dans la mortalité (jugement d'expert déclaré)
actif,sorti,resiliation_be,an,age_anciennete,meilleure estimation seulement ; ancienneté du contrat
conjoint_survivant,conjoint_decede,mortalite_conjoint_cs,an,generation,
conjoint_survivant,conjoint_decede,mortalite_conjoint_be,an,generation,
conjoint_survivant,conjoint_remarie,remariage,an,age_anciennete,facultative ; déclaration « aucun » admise ; ancienneté de veuvage
enfant_a_charge,enfant_decede,mortalite_enfant_be,an,age,comptes sociaux : service certain (aucune table)
enfant_a_charge,enfant_etudes,poursuite_etudes,an,age,appliquée à l'âge limite aux enfants scolarisés ou apprentis à la dernière information
enfant_etudes,enfant_fin_charge,poursuite_etudes,an,age,sortie d'études hors décès = 1 − maintien − probabilité de décès (hypothèse déclarée)
enfant_etudes,enfant_decede,mortalite_enfant_be,an,age,
enfant_handicape,enfant_decede,mortalite_handicape,an,age,facultative
```

### 8.3 `flux.csv`

Les frais sont un flux de chaque poste (Q10 décidée) ; leur type est à fixer par `architect` (A2).

```csv
code_garantie,flux,type_flux,etat_payeur,parametres
deces,capital,capital_unique,deces,taux_capital;capital_forfaitaire;majoration_conjoint;majoration_enfant;age_fin_garantie
deces,capital_iad,capital_unique,iad,taux_capital;capital_forfaitaire;majoration_conjoint;majoration_enfant
deces,prime,prime_periodique,actif,prime_periodique;taux_cotisation;cotisation_forfaitaire
rente_conjoint,arrerage,rente_periodique,conjoint_survivant,taux_rente;age_terme
rente_education,arrerage,rente_periodique,enfant_a_charge;enfant_etudes;enfant_handicape,taux_rente;age_limite;age_limite_etudes
```

### 8.4 `usages_tables.csv`

```csv
code_garantie,usage,nature,axes
deces,mortalite_tarif,mortalite,age
deces,mortalite_attendue,mortalite,age
deces,mortalite_assure_be,mortalite,age
deces,incidence_iad,incidence,age
deces,resiliation_be,incidence,age_anciennete
rente_conjoint,mortalite_conjoint_cs,mortalite,generation
rente_conjoint,mortalite_conjoint_be,mortalite,generation
rente_conjoint,remariage,incidence,age_anciennete
rente_education,mortalite_enfant_be,mortalite,age
rente_education,poursuite_etudes,maintien,age
rente_education,mortalite_handicape,mortalite,age
```

La série TME et la courbe des taux sans risque (nature `taux`) sont des usages communs du plan. Elles servent aux indicateurs A132-1 et R132-3-1 et à l'actualisation en meilleure estimation.

### 8.5 `postes.csv`

Révision 3 : tous les rattachements sont fixés (lecture de `regulatory` ; décisions D1, D2 et D7). Les rentes à constituer sont en `psap_vie` (D1) ; leur passage en provision mathématique vie à l'`ouverture_service` les fait sortir du poste vers `rentes_en_service`.

```csv
code_garantie,poste,famille,composantes,regle_combinaison,provision_comptes_sociaux,meilleure_estimation,methodes,temoins
deces,sinistres_declares_non_regles,engagement,,,psap_vie,TRUE,capital_dossier,chain_ladder_charges_recalculees;chain_ladder_paiements
deces,capitaux_non_reclames,engagement,,,psap_vie,TRUE,capital_revalorise;capital_revalorise_reglement,
deces,provision_mathematique_temporaire_deces,risque_en_cours,,,provision_mathematique_vie,FALSE,prospective_prime_pure;prospective_prime_declaree;prorata_cotisation,retrospective
deces,tardifs,combinaison,nombre:triangle;cout_moyen:engagement;catastrophe:engagement,somme(produit(nombre;cout_moyen);catastrophe),psap_vie,TRUE,nombre:chain_ladder_nombres;nombre:bornhuetter_ferguson_nombres;nombre:cape_cod_nombres;nombre:benktander_nombres;cout_moyen:cout_moyen_capital;cout_moyen:chain_ladder_charges_recalculees;catastrophe:victimes_recensees,bootstrap_poisson_surdisperse;chain_ladder_paiements
rente_conjoint,rentes_en_service,engagement,,,provision_mathematique_vie,TRUE,vap_rente,vap_monte_carlo
rente_education,rentes_en_service,engagement,,,provision_mathematique_vie,TRUE,vap_rente,vap_monte_carlo
rente_conjoint,rentes_a_constituer,engagement,,,psap_vie,TRUE,vap_rente_reconstituee;ouverture_ponderee,
rente_education,rentes_a_constituer,engagement,,,psap_vie,TRUE,vap_rente_reconstituee;ouverture_ponderee,
rente_conjoint,tardifs,combinaison,nombre:triangle;cout_moyen:engagement,produit,psap_vie,TRUE,nombre:deces_tardifs_taux_ouverture;nombre:bornhuetter_ferguson_nombres;cout_moyen:vap_moyenne_ouverture;cout_moyen:vap_sinistre_type,chain_ladder_dossiers_rentes
rente_education,tardifs,combinaison,nombre:triangle;cout_moyen:engagement,produit,psap_vie,TRUE,nombre:deces_tardifs_taux_ouverture;nombre:bornhuetter_ferguson_nombres;cout_moyen:vap_moyenne_ouverture;cout_moyen:vap_sinistre_type,chain_ladder_dossiers_rentes
```

Remarques :
- **`capitaux_non_reclames` en `psap_vie`** : D2 décidée.
- **Arrérages échus non payés** : composante `arrerages_echus` de `rentes_en_service`, rattachée à `psap_vie` (D1 décidée) alors que le poste est en `provision_mathematique_vie` ; restituée à part (forme : A1).
- **Invalidité absolue et définitive** : dans les postes `deces`, en `psap_vie` (D7 décidée).
- **`approche_par_tete`** : inscrite en B6 (Q9 décidée).
- **`limites_contrat`** (meilleure estimation) : recensé en B6.

### 8.6 `liens.csv`

```csv
garantie,garantie_liee,lien
rente_conjoint,deces,ouverture_rente
rente_education,deces,ouverture_rente
```

Le type de lien `ouverture_rente` est nouveau (Q8 décidée ; A1).

## 9. Questions au mainteneur

Toutes les questions des révisions 1 et 2 sont tranchées le 7 novembre 2026 (§ 2) : Q1 à Q14, D1 à D7. **Aucune question ouverte**, hormis le visa du recensement lui-même.

Restent liés à des lectures : D6 est provisoire jusqu'à la relecture de la loi n° 89-1009, art. 7 ; Q5 est à revoir sur mesure en B2 ; Q14 étend E2.9 et l'ADR 0009, point 6 (report par `architect`).

## 10. Points pour `regulatory` (après la lecture du 7 novembre 2026)

| Point | État |
|---|---|
| R1 | **Lu** ; tranché (D1) |
| R2 | **Lu** ; citations corrigées au § 3.2. Reste : le décret de taux des institutions de prévoyance (non trouvé, copie du CSS incomplète) ; l'application aux contrats collectifs des entreprises d'assurance (incertain) ; le texte de la loi n° 2014-617, art. 13 (non relu) |
| R3 | **Lu** ; tranché (D3). Reste : A223-8 et A932-3-11 ; la table annexée à A132-18-1 (fac-similé du JO) ; quelles tables de A132-18, a), sont « applicables aux contrats de rente viagère » |
| R4 | **Lu** ; tranché (D4) |
| R5 | **Lu**, vérifié (intégré au § 3.3 et au § 3.5) |
| R6 | **Lu**, vérifié ; tranché (D5) ; issue proposée par `regulatory` |
| R7 | **Lecture de `regulatory` en cours** : annexe I, art. 18 et 26 du règlement délégué (EUR-Lex) |
| R8 | **Lu en partie** (CSS L912-3 vérifié) ; tranché à titre provisoire (D6) ; relecture de la loi n° 89-1009, art. 7 : **lecture de `regulatory` en cours** |
| R9 | **Lu** ; tranché (D7) |
| R10 | **Lu**, vérifié : analogie déclarée, non obligatoire |

## 11. Points pour `architect` (contrats partagés)

- **A1** — Catalogue : lien `ouverture_rente` (Q8 décidée) ; colonne `methodes` préfixée par la composante ; `regle_combinaison` en somme de produits ; composante `arrerages_echus` d'un poste en `engagement` avec une provision de rattachement différente de celle du poste (D1).
- **A2** — Fins déterministes hors des transitions ; types de flux `prime_periodique` et `frais` (Q10 décidée).
- **A3** — Nature d'une loi de résiliation ou de rachat ; table de rentiers déclarée par génération ou par âge pour un même usage.
- **A4** — Règle du `statut_resultat` d'une cellule aux dossiers de statuts différents. Proposition : « jugement d'expert » dès qu'une hypothèse par défaut ou de jugement entre dans le montant.
- **A5** — Feuille de route et décisions : module `risque_en_cours` dès B2 (Q2) ; item (2) de la branche `claude/prc` retiré (D5) ; indicateur `R132_3_1` (Q14) ; numérotation M des décisions du § 2 ; annotations d'E2.9, de l'ADR 0009 (point 6) et de l'ADR 0010 (catalogue, indicateurs) à proposer.

## 12. Références de méthode

Statuts de vérification :
- « vérifié ce jour » : PDF lu par cette consultation, empreinte donnée ;
- « vérifié (registre de `docu_actu`) » : lecture consignée, non relue ce jour ;
- « notice » : données bibliographiques et résumé seulement.

| Référence | Soutient | Statut |
|---|---|---|
| Mack, T., « Distribution-free Calculation of the Standard Error of Chain Ladder Reserve Estimates », *ASTIN Bulletin* 23(2), 1993, p. 213-225 | Hypothèses (1) à (3) ; th. 3, p. 217 ; corollaire, p. 220 | vérifié (registre de `docu_actu`, `PLACE-MACK-1993`) |
| Bornhuetter, R. L., Ferguson, R. E., « The Actuary and IBNR », *Proceedings of the CAS* LIX, 1972, p. 181-195 | Facteur appliqué à l'a priori (p. 187) | vérifié (registre de `docu_actu`, `PLACE-BF-1972`) |
| Mack, T., « Credible Claims Reserves: The Benktander Method », *ASTIN Bulletin* 30(2), 2000, p. 333-347 | Définition (p. 334-335) ; résumé (p. 333) | vérifié ce jour (SHA-256 `8e9e86f6dd4ed6a4…cfb508086`) |
| Mack, T., « The Prediction Error of Bornhuetter/Ferguson », *ASTIN Bulletin* 38(1), 2008, p. 87-103, DOI 10.2143/AST.38.1.2030404 | Erreur de prédiction ; incertitude sur la cadence et l'a priori (p. 87) | vérifié ce jour (SHA-256 `e5cbbb4e0dde834b…c3c587`) |
| Gluck, S. M., « Balancing Development and Trend in Loss Reserve Analysis », *Proceedings of the CAS* LXXXIV, 1997, p. 482-532 | Cape Cod, éq. (5.1), p. 491 | vérifié ce jour (SHA-256 `98aa10a8d79b378d…4a9da1c`) |
| England, P. D., Verrall, R. J., *Proceedings of the CAS* LXXXVIII, 2001, p. 1-38 | Poisson surdispersé et Chain Ladder (p. 11) | vérifié (registre de `docu_actu`) |
| Dahms, R., *Stochastic Reserving*, ETH Zurich, 2021 | Condition d'égalité (th. 5.3) | vérifié (registre de `docu_actu`) ; support de cours |
| England, P. D., Verrall, R. J., *British Actuarial Journal* 8(3), 2002, p. 443-518 | Bootstrap | notice |
| Merz, M., Wüthrich, M. V., *CAS E-Forum*, automne 2008 | Horizon d'un an | notice |
| Norberg, R., *Scandinavian Actuarial Journal* 1991(1), p. 3-24 | Provisions prospective et rétrospective | notice (résumé) |
| Dickson, Hardy et Waters, *Actuarial Mathematics for Life Contingent Risks*, 3e éd., 2020, chap. 8 | Modèle multi-états | vérifié (registre de `docu_actu`, table des matières) |
| Haberman, S., Pitacco, E., *Actuarial Models for Disability Insurance*, 1999 | Modèle semi-markovien (B5) | retrouvé à la relecture de cadrage, non relu |

Les textes qui font foi cités sont ceux de la lecture de `regulatory` du 7 novembre 2026 (empreintes LEGI et du recueil ANC dans sa lecture). Les lignes de registre correspondantes sont proposées par `regulatory`.

## 13. Observation hors périmètre (soldée)

L'incohérence de version du dictionnaire relevée en révision 1 (§ 0 : `1.2` ; T1 : domaine `1.1`) est corrigée par la version `1.3` (commit `b31c5d6`, vérifié par `git show b31c5d6`, lignes 11 et 253 du texte). D'après le message de ce commit, la constante `VERSION_DICTIONNAIRE_ATTENDUE` du moteur suit dans un commit `moteur:` après l'audit de T2 : elle vaut encore `"1.2"` dans `R/outils.R`.

## 14. Avis d'actuaire sur les décisions à soumettre (circuit 2)

`regulatory` a décrit les lectures ; le présent avis éclaire l'interprétation ; le mainteneur a tranché le 7 novembre 2026, **conformément à chaque recommandation ci-dessous** (§ 2 ; numéros M121 à M128). L'avis est conservé comme motivation des décisions. « Effet sur un total » : effet sur la provision totale par garantie et par référentiel (grandeur sous visa, A3). Aucun chiffre n'est avancé : les effets sont à mesurer sur le jeu simulé en B2 et en B4.

### D1 — Rentes à constituer (R1) et arrérages échus non payés

- **Recommandé : lecture mixte.** PSAP vie (compte 32) pour toute rente non liquidée (pas d'`ouverture_service` : situations 1 à 3 de P6, dossiers potentiels compris), provision mathématique vie dès la liquidation. Dans la base, la liquidation est l'`ouverture_service`, ce qui donne une frontière observable sans hypothèse.
- **Pourquoi** : c'est la seule lecture qui suive à la fois la décision M81 (capitaux en PSAP vie), le plan de comptes, ANC 223-1 et ANC 142-4 (qui vise les rentes « liquidées » au titre des provisions mathématiques). Elle sépare l'engagement dont le montant reste à déterminer de celui dont il est fixé.
- **Arrérages échus non payés** : **PSAP vie** (montants dus et déterminés, à l'image d'un capital liquidé, ANC 223-1), restitués en composante.
- **Alternative** : (b) tout en provision mathématique vie, plus simple (une seule règle pour les rentes) mais au prix d'étendre « rentes mises à la charge » aux rentes non liquidées. Pour les arrérages : les laisser dans la provision mathématique de la rente.
- **Effet sur un total** : **nul sur le montant** si les rentes à constituer sont valorisées avec les mêmes taux, tables et frais que la provision mathématique, ce que je recommande de déclarer : la PSAP vie n'a pas de règle de taux, et l'aligner sur 142-3 et 142-4 évite un écart artificiel. Le choix change la répartition entre postes du bilan. Il ne change le total que si la règle de frais diffère : chargement de PSAP (hypothèse déclarée, Q10) d'un côté, chargements de gestion tarifaires (R343-3, 1°) de l'autre. L'écart est alors la différence de ces deux hypothèses, nul si elles sont déclarées égales. Arrérages : reclassement, effet nul.

### D2 — Extension de M81 aux capitaux non réclamés (R2) et Q5

- **Rattachement, recommandé : PSAP vie (a)**, cohérent avec M81 et ANC 223-1. **Alternative** : provision mathématique vie (b). **Effet** : nul (même montant).
- **Q5, recommandé : revalorisation acquise seule en comptes sociaux** (`capital_revalorise`), avec `capital_revalorise_reglement` en alternative et en sensibilité restituée.
- **Motif** : le texte fixe un minimum de revalorisation par année civile, non une règle de provisionnement (lecture de `regulatory`). La PSAP vie n'est pas actualisée ; le taux légal est le moins élevé de deux mesures du TME ; ne pas provisionner la revalorisation à courir revient à supposer qu'elle est financée par les produits des actifs qui représentent la provision, au moins égaux au TME en espérance. C'est un jugement d'expert, cohérent avec la non-actualisation, à documenter avec son effet chiffré.
- **Limite** : un capital non réclamé peut rester provisionné jusqu'à dix ans avant le dépôt (L132-27-2), et sans terme pour une temporaire décès dont le décès est antérieur au 1er janvier 2015. Sur ces durées, l'écart n'est plus marginal. Si la sensibilité montre un écart significatif sur le jeu de référence, je recommanderais de revenir à l'alternative pour les dossiers les plus anciens. Ce point est à revoir en B2 sur mesure.
- **Effet sur un total** : l'alternative augmente la PSAP vie d'environ capital × ((1 + r)^d − 1), r étant le taux retenu et d la durée restante attendue jusqu'au règlement ou au dépôt. C'est à mesurer.

### D3 — ANC 142-4 et rentes temporaires (R3)

- **Recommandé : (a), appliquer 142-4** (tables de rentiers en vigueur à chaque inventaire) à la rente de conjoint temporaire, par cohérence avec A132-18, qui range les rentes temporaires parmi les rentes viagères pour le tarif. La rente d'éducation handicapée (viagère) relève de 142-4 sans débat. Pour la rente d'éducation ordinaire, le point prudent des comptes sociaux (service certain, E2.15) rend la question sans objet.
- **Alternative** : (b), tables de 142-3 (époque du tarif, ou faculté de l'inventaire).
- **Effet sur un total** : rente d'éducation ordinaire, nul. Rente de conjoint temporaire jusqu'à un âge de terme, faible : la mortalité avant l'âge de terme pèse peu dans sa valeur actuelle (raisonnement de structure, à vérifier par sensibilité). Rente viagère de conjoint : déjà sous 142-4, sans changement. Le sens de l'effet de (a) face à (b) est une hausse si les tables de rentiers en vigueur ont une mortalité plus faible que celles du tarif.

### D4 — Sens de « souscription » (R4) et indicateur M85

- **Recommandé : (a)**, chaque reconduction annuelle d'un contrat collectif vaut souscription (le tarif est refixé). Pour une rente, le taux pertinent est celui de la **version de garantie en vigueur à la survenance du décès** (`garanties_souscrites`, version par `date_effet`), puisque l'engagement naît sous ce tarif.
- **Indicateur M85** : restitué à la date d'arrêté comme décidé, étiqueté **« approximation »** pour deux raisons : la série TME de la Banque de France est assimilée au « taux moyen » du texte (A132-1 prend le plus élevé des taux d'émission et de marché secondaire, A132-1-1 la moyenne des deux) ; et la date d'arrêté n'est pas la date de souscription. Je recommande d'y ajouter, en ligne distincte, le même indicateur à la date d'effet de la version en vigueur à la survenance (lecture (a)), qui est celui que le texte vise.
- **Alternative** : (b) date d'effet initiale du contrat ; ou l'indicateur à l'arrêté seul, comme M85.
- **Effet sur un total** : nul. C'est un indicateur, et un dépassement est signalé, non refusé (M62).

### D5 — R6 / Q13 : item 2 de la branche `claude/prc`

- **Recommandé : retirer l'item 2.** La provision mathématique de la temporaire décès à prime nivelée est déjà le poste P3 de B2 : le « reformuler en provision mathématique » le ferait doublon. La branche `claude/prc` garde la PRC des garanties de maladie et d'invalidité (R343-7, 5°). La question d'une garantie complémentaire d'invalidité attachée à un contrat vie (R321-5) y reste ouverte, comme le propose `regulatory`.
- **Alternative** : reformuler l'item en « garanties complémentaires d'invalidité des contrats vie », si le mainteneur veut les couvrir dans cette branche.
- **Effet sur un total** : nul sur la v1. La version de la feuille de route aurait ajouté une provision en double sur le décès individuel, contraire à R343-3.
- L'issue proposée par `regulatory` (titre, libellé `needs-triage`, corps) est reprise telle quelle, sur accord du mainteneur.

### D6 — Revalorisation des rentes après résiliation (R8)

- **Recommandé : hypothèse déclarée par segment de contrats résiliés.** En comptes sociaux, **montant figé** (lecture (a)) sauf clause contractuelle qui garantit la revalorisation par l'organisme résilié, auquel cas elle est provisionnée (lecture (b), au taux garanti). Le dictionnaire ne porte pas cette clause : le plan la déclare par segment (`contrats` résiliés, `motif_fin`). La documentation propose « figé » comme valeur et dit l'alternative et son effet (jugement d'expert).
- **Motif** : L912-3 met la poursuite de la revalorisation à la charge de l'acte fondateur du régime, qui l'organise, en général auprès du nouvel organisme. L'art. 7 de la loi n° 89-1009, tel que lu au cadrage, garantit un plancher (la dernière prestation), pas une revalorisation.
- **Réserve** : lecture provisoire. L'art. 7 est à relire en entier par `regulatory` avant visa.
- **Alternative** : revalorisation future provisionnée pour toutes les rentes de contrats résiliés (point prudent).
- **Effet sur un total** : l'alternative augmente la provision mathématique des rentes des contrats résiliés de la valeur actuelle de la revalorisation future. Cet effet est sensible pour une rente viagère de conjoint (longue durée) et faible pour une rente d'éducation. À mesurer en B4.

### D7 — Classement de l'IAD (R9)

- **Recommandé : (a).** Une IAD qui verse **par anticipation le capital décès**, sans prime distincte et en éteignant la garantie décès, fait partie de l'engagement vie (branche 20, R343-3). Elle est provisionnée avec le capital décès (P1, P4) en PSAP vie, et ses rentes de conjoint et d'éducation suivent P5 à P7.
- **Alternative** : (b) garantie complémentaire d'invalidité à prime distincte (R321-5), provisionnée selon R343-7. Le dictionnaire v1 ne peut pas la représenter (IAD = `option_iad` de la garantie `deces`, sans cotisation propre) : elle demanderait une nouvelle version du dictionnaire et un poste propre, hors v1.
- **Effet sur un total** : nul sur le montant (même capital). (b) changerait le rattachement et la règle de frais (chargement de 143-11) et ouvrirait une PRC possible.
