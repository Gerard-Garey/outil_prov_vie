# Spécification de la branche B2 — capital décès en comptes sociaux (v1)

> *Rédigé par l'agent actuary-approfondi (IA) le 10 novembre 2026 (étape 0b de la branche `claude/capital-deces`, PR #61, tête `bcb5103`).*
>
> *Statut : **visa délégué par le mainteneur le 10/11/2026, à confirmer a posteriori**. La délégation vaut pour une spécification qui suit les décisions du mainteneur du 10 novembre 2026 : I4, I5 et I6 tranchées selon les recommandations de `regulatory` ; I1, I2 et I3 tranchées le 10/11/2026 (avis Fable d'`actuary-approfondi`, auquel la session s'est rangée), validation a posteriori du mainteneur ; échelle d'A132-1-1 établie par `regulatory` ; aucune table réglementaire embarquée en B2 ; issues (1) à (4) créées en `ready-for-agent` avec les corps du § 8.*
>
> *Version `1.0.1` : errata de rédaction d'`actuary` du 10/11/2026 (§ 2.3, lecteur indépendant des données ; § 2.7, paramètres de P2 ; « huit CSV » aux § 7.1 et § 8.1), sans effet sur le code ni sur les résultats. Version `1.0` (arbitrage de I1 à I3 intégré le même jour, avant tout commit). Résultats modifiés : aucun (aucun code). Nommage : convention de `docs/specifications/` (objet en minuscules, mots liés par des tirets, suffixe `-v1` du jalon ; la version du texte est dans l'en-tête).*

## 0. Objet, sources, lecture

### 0.1 Objet

La présente spécification permet à `coder-approfondi` de coder sans question de fond les issues (1) module `plan`, (2) module `tables` et (3) familles « engagement » et « risque en cours » du capital décès (avec `etats_a_date()`, #51 et #54), et cadre l'issue (4) (`calculer_provisions()`, objet `resultat_provie`, références). Elle part du recensement visé de #20 (`docs/specifications/recensement-methodes-v1-deces-rentes.md`, révision 4, M131), qu'elle ne rediscute pas, et de la lecture de `regulatory` de l'étape 0a.

**Périmètre de B2** (postes du recensement, § 0.2) : P1 sinistres déclarés non réglés, P2 capitaux non réclamés, P3 provision mathématique de la temporaire décès, garantie `deces` seule, **comptes sociaux seuls**. Hors B2 : P4 tardifs (B3), rentes P5 à P7 (B4), maintien de la garantie décès (B5), double effet et limites du contrat (B6), meilleure estimation (B6 ; ce que B2 en porte déjà : § 5.7).

### 0.2 Sources lues

- `CLAUDE.md`, `docs/exigences.md` (E1 à E5), `CONTEXT.md`, `docs/feuille-de-route.md` § 1.6 et § 4 (M62, M67, M71, M81 à M86, M118, M121 à M129, M131, M233 à M244).
- ADR 0005, 0007, 0009, 0010 (points 1 à 18 ; annotations des septième, dixième, quatorzième, quinzième, dix-huitième, dix-neuvième et vingt et unième séries).
- Recensement de #20 (révision 4) ; dictionnaire de la base `1.5` ; spécification du module `donnees` `1.5.5` (§ 3.2, § 4.5, § 6).
- Issues #20, #27, #51, #54 (lues par `mcp__github__issue_read` le 10 novembre 2026).
- Rapport partiel de `regulatory-approfondi` de l'étape 0a (résumé de la session ; scratchpad de la session, `0a-regulatory.md`).
- Avis d'`actuary-approfondi` sur Fable sur I1 à I3, avec l'échelle d'A132-1-1 établie par `regulatory` (scratchpad de la session, `avis-fable-I1-I3.md`, 10 novembre 2026).
- Code à `bcb5103` : `NAMESPACE`, `R/outils.R`, `R/donnees.R` (`controler_base()`, `.lire_conventions()`, `.visibilite_a()`, `.valeurs_vue()`, `.PARTIES_LIGNE`).

### 0.3 Mesures (R 4.3.3, `provie` installé depuis `bcb5103` dans une bibliothèque du scratchpad)

| N° | Mesure | Commande | Sortie |
|---|---|---|---|
| m1 | #51 : statut de la partie `sinistres.date_instruction` illisible par sa forme, à A0 = 2025-06-30, sur la base de référence de `tests/unitaires/donnees.R` (SI1 : `"2025/02/01"` ; SI2 : absente) | script `mesure51.R` (lignes 18 à 106 du test, puis `.visibilite_a(ctx, "vue")`) | `parties$sinistres : FALSE FALSE` (illisible et absente indistinctes) ; témoin sur la base de référence : `TRUE FALSE` ; `refus_tables` : `sinistres date_instruction type_incompatible colonne 1 SI1` |
| m2 | #54 : `.valeurs_vue(ctx, "sinistres", "date_instruction")` sur la même base | même script | `WARNING: NAs introduced by coercion` |
| m3 | Dixième série, (d) : exigence de `conventions$limite_age` sur les jeux versionnés, sans cette entrée | script `mesure_la.R` (`controler_base()` avec `declarations.txt` du jeu, `limite_age` retirée) | chaque jeu, aux deux arrêtés : 2 lignes de `declarations_requises` (contre 0 avec l'entrée), 2 lignes D07 `declaration_absente` ; aucun dossier `rente_education` ni `double_effet` dans les jeux |
| m4 | Dossiers `deces` des jeux versionnés à 2024-12-31 et 2025-12-31 | `grep -E "DO006[0145]"` sur `evenements.csv` et `prestations.csv` des deux jeux | quatre dossiers, tous `fixation_capital`, payés et clos (`cloture_dossier` motif `regle`), dernière saisie le 2024-10-09 |
| m5 | Cotisations non échues à ces arrêtés | `awk` sur `cotisations.csv` des deux jeux | aucune émission dont la période dépasse un arrêté et saisie avant lui ; émissions annuelles en janvier, périodes civiles |
| m6 | Refus de `v1-modeste-02` | `mesure_la.R` | une ligne : `prestations montant D09 colonne 1` (PR00010, indemnité journalière de signe inversé, `verite/defauts.csv`) |
| m7 | Cas à valeurs en dur du § 7 | scripts `cas.R`, `cas2.R` (revalorisation, convention de fin de journée) et trois `Rscript -e` | valeurs du § 7.4 ; `lifecontingencies` **non installé** dans le conteneur (`requireNamespace` : `FALSE`) |

Les scripts sont dans le scratchpad de la session, non versés.

### 0.4 Lecture

- Statuts épistémiques (E2.25) : **exact**, **asymptotique**, **approximation numérique**, **constat de simulation**, **jugement d'expert** ; plus, pour les décisions de cette spécification, **décision de forme** (révisable par `architect`) et **règle visée** (texte déjà visé, appliqué tel quel).
- « Partie » renvoie à une partie de ligne au sens du dictionnaire, § 6. « Vue » est la vue à l'arrêté.
- Les numéros de lignes du code sont à `bcb5103` ; le code est cité par nom de fonction.
- **Aucune valeur par défaut** : toute entrée du plan citée ici est obligatoire quand elle est lue (règle d'exigence du § 2.3) ; « la documentation propose » désigne une valeur que la documentation de fond suggère, jamais une valeur appliquée en l'absence de déclaration.

## 1. Questions d'interprétation I1 à I6

Les six questions sont tranchées. I4, I5 et I6 l'ont été par le mainteneur le 10 novembre 2026, sur les recommandations de `regulatory`. I1, I2 et I3 ont été **tranchées le 10/11/2026 (avis Fable), validation a posteriori du mainteneur** : la session s'est rangée à l'avis d'`actuary-approfondi` sur Fable, conformément à la décision du mainteneur (scratchpad de la session, `avis-fable-I1-I3.md`). Les marques « tranché le 10/11/2026 (avis Fable) » du texte renvoient à cet arbitrage.

### 1.1 I1 — Revalorisation légale dans la PSAP vie — tranché le 10/11/2026 (avis Fable), validation a posteriori du mainteneur

**Lectures** (`regulatory`, 0a) : (a) revalorisation **acquise** à l'arrêté seule (M122) ; (b) revalorisation **jusqu'au règlement attendu** (analogie avec R343-7, 4°, et ANC 141-1).

**Décision** : **(a) recommandée** sur P1 et P2 ; **(b) alternative ouverte sur P1 comme sur P2**, au statut de **point prudent** (majorant) ; choix = jugement d'expert déclaré dans le plan, le texte ne tranchant pas.

**Appuis cités par l'avis, à établir par `regulatory` avant toute citation dans la documentation** : directive 91/674/CEE, art. 60, § 2, a) (vie : « somme due aux bénéficiaires, augmentée des frais de règlement ») ; ANC 336-4 et 336-8 (intérêts techniques inclus dans la PSAP, charge de l'exercice). L'avis relève aussi qu'**aucune règle de non-actualisation ne s'applique à la PSAP vie** (l'interdiction de l'escompte vise la non-vie, art. 60, § 1, g, de la même directive) : la fiche de méthode écrit que « non actualisé » est une **convention du plan de comptes**, non une règle tirée d'un texte pour la vie.

**M122 amendée (proposition de l'avis, à consigner par `architect`)** : « Capitaux décès de la PSAP vie (P1, P2, coût des tardifs) : en comptes sociaux, revalorisation acquise à l'arrêté, méthode recommandée ; revalorisation jusqu'au règlement attendu ou au dépôt, non actualisée, méthode alternative ouverte sur chaque poste, au statut de point prudent ; choix = jugement d'expert déclaré dans le plan, le texte ne tranchant pas. » « À revoir sur mesure en B2 » est remplacé par une sensibilité sur un jeu qui porte des capitaux non réclamés (IP2, § 10.3). Le recensement de #20 passe en révision 5 (alternative de P1, méthode écartée).

**Méthodes** (§ 5.3, § 5.4) :

| Poste | Méthode | Statut | Horizon de la revalorisation |
|---|---|---|---|
| P1 | `capital_dossier` | recommandée | arrêté |
| P1 | `capital_dossier_reglement` | alternative, point prudent | arrêté + `delai_reglement_jours` (règlement attendu) ; même fonction que P2 |
| P2 | `capital_revalorise` | recommandée | arrêté |
| P2 | `capital_revalorise_reglement` | alternative, point prudent, « borne supérieure de la lecture (b) » | dépôt à la Caisse des dépôts et consignations, dix ans après la connaissance du décès (L132-27-2, I, vérifié en 0a) ; `duree_sans_depot_annees` sans dépôt légal |
| P1, P2 | (b) actualisée à un taux prudent déclaré | **écartée** (E2.16), sans témoin | motif proposé par la présente spécification, à confirmer par la révision 5 du recensement : à taux d'actualisation égal au taux de revalorisation, elle redonne (a) (recoupement du § 7.3, critère 3.13) ; elle n'en diffère que par un taux d'actualisation pour lequel aucune règle de taux n'est établie en PSAP vie |

**Plan** : méthode de chaque poste obligatoire, sans valeur par défaut ; `taux_par_annee` et `prorata` obligatoires ; si une méthode « règlement » est déclarée : `taux_futur` ; avec `capital_revalorise_reglement`, `duree_sans_depot_annees` ; avec `capital_dossier_reglement`, `delai_reglement_jours`. **Année N+1** : le minimum légal de l'année suivant l'arrêté (`R132_3_1` de N+1) est calculable à l'arrêté du 31/12/N ; `taux_par_annee` porte les années postérieures à l'arrêté que le plan veut fixer, et `taux_futur` ne sert qu'au-delà de la dernière année déclarée. **Sensibilité** = second plan qui ne diffère que par la méthode (E2.24). **Plan mixte** ((a) sur un poste, (b) sur l'autre) : admis, avec signalement (§ 5.4).

**Statut** : jugement d'expert (le choix) ; résultat exact sous les taux déclarés (chaque montant). Témoins de simulation (B3, B10) : provision vraie définie par horizon.

**Effet sur une provision totale** : nul pour les plans qui déclarent (a), comme les plans de référence ; un plan qui déclare (b) augmente la PSAP vie de Σ solde revalorisé à l'arrêté × (facteur futur − 1). Cas en dur (§ 7.4) : P2 de 100 000 €, (a) 103 936,00 € ; (b) 127 666,84 € (+22,8 %) ; P1 avec un délai de 30 jours, 104 141,02 € (+0,20 %). Nul sur les jeux versionnés (aucun dossier ouvert, m4).

### 1.2 I2 — A132-1, « au-delà de huit ans » — tranché le 10/11/2026 (avis Fable), validation a posteriori du mainteneur

**Décision : lecture (i)**, contrats de plus de huit ans (E2.9). La recommandation (ii) de la première version de la présente spécification est retirée.

**Règle** (`plafond_a132_1()`, § 3.5) : **une seule ligne `A132_1` par contrat**, sans paramètre de tranche. Prime unique et durée ≤ 8 ans (de la date d'effet au terme, huit ans inclus : terme au plus égal au huitième anniversaire de la date d'effet) : 75 % du TME semestriel ; sinon (prime unique de plus de huit ans, ou primes périodiques) : min(3,5 % ; 60 % du TME semestriel), le plafond de 3,5 % ne jouant que dans cette branche. `date_terme` absente : `valeur_regle = NA`, `depassement = NA`, mention `terme_absent` dans `detail`, sans hypothèse par défaut. Proposition pour `docs/exigences.md`, E2.9 : retirer « à confronter au texte mot à mot (issue #13) » (texte hors du domaine d'`actuary`, à reporter par la session).

**Statut** : interprétation tranchée ; indicateur au statut d'approximation (série assimilée, M124). **Effet sur une provision totale** : nul (indicateur signalé, M62).

### 1.3 I3 — Collectif décès annuel reconduit — tranché le 10/11/2026 (avis Fable), validation a posteriori du mainteneur

**Décision : (b)**, primes périodiques ou fractionnées : min(3,5 % ; 60 %). **En B2 : rien** (P3 collectif par `prorata_cotisation`, sans taux ; aucun indicateur `A132_1` pour un collectif). Pour B4 et B5 : `nature_primes` déduite de `garanties_souscrites.periodicite_cotisation` (`unique` → `"unique"`, toute autre valeur → `"periodique"`) ; colonne absente ou valeur manquante → indicateur `NA`. Règle par organisme : A132-1 (entreprise d'assurance), CSS A932-3-1 (institution de prévoyance) ; mutuelle : aucun équivalent trouvé, hypothèse déclarée (statut incertain). En B2, `plafond_a132_1()` porte déjà l'argument `nature_primes` et le type d'organisme dans `detail`.

**Effet sur une provision totale** : nul.

### 1.4 I4 — `R132_3_1` négatif [décidée par le mainteneur]

Décision du mainteneur du 10 novembre 2026 (recommandation de `regulatory` retenue) : l'indicateur est **restitué tel que calculé, même négatif, et signalé** ; le taux retenu reste déclaré. Effet sur le code : aucun plancher dans `minimum_r132_3_1()` ; la ligne d'indicateur porte `detail` contenant `indicateur_negatif` (§ 3.5). Effet sur une provision : nul.

### 1.5 I5 — Institutions de prévoyance [décidée par le mainteneur]

Décision du mainteneur du 10 novembre 2026 : R132-3-1 s'applique aux institutions de prévoyance **par le renvoi de L932-23**, en **hypothèse déclarée au statut incertain** (cohérent avec M133). Effet sur le code : quand `extraction.type_organisme` vaut `institution_prevoyance`, chaque ligne `R132_3_1` porte dans `detail` la mention `ip_renvoi_L932-23_incertain` ; la fiche l'inscrit parmi les paramètres retenus (`plafonds`). Effet sur une provision : nul.

### 1.6 I6 — Collectif à tacite reconduction, préavis échu [décidée par le mainteneur]

Décision du mainteneur du 10 novembre 2026 : l'année N+1 entre dans les limites du contrat en Solvabilité II, sous réserve des clauses de préavis portées par contrat (`contrats.preavis_mois`, `mois_echeance`, `jour_echeance`, `tacite_reconduction`). **Effet en B2 : aucun** (limites du contrat en B6) ; règle consignée pour B6.

## 2. Module `plan` et catalogue des garanties — issue (1)

### 2.1 Ce que (1) livre

- `R/plan.R` : `valider_plan()`, `canoniser_plan()`, `ecrire_plan()`, `lire_plan()`, fiche de calcul (`construire_fiche()`, interne ; `ecrire_fiche()`, `lire_fiche()`), contrôles du rejeu (`.controler_rejeu()`, interne), classes `plan_calcul` et `fiche_calcul` avec `print` et `format`.
- `R/garanties.R` et le catalogue `inst/extdata/garanties/*.csv` (§ 4.1) : `catalogue_garanties()`. **Décision de forme** : le catalogue entre dès (1), et non en (3), parce que `valider_plan()` en a besoin pour contrôler garanties, postes, méthodes et usages de tables (ADR 0010, point 1 : `plan` peut appeler `garanties`).
- `rejouer_fiche()` est **exporté en (4)**, quand `calculer_provisions()` existe ; (1) livre et teste ses contrôles d'entrée (ordre des refus : version de la fiche, versions de R et de `provie` signalées, empreintes des données reçues, empreintes des tables).

### 2.2 Schéma du plan de la v1, contenu fixé en B2

Le plan est une liste nommée, sections dans l'ordre canonique de l'ADR 0010, point 17. Toute section est présente ; une section sans contenu en B2 vaut `list()` et doit être écrite ainsi. Types : `Date` (classe `Date`, double), `integer`, `double`, `character`, `logical` ; un `double` entier est admis là où un `integer` est attendu et canonisé en `integer` ; toute autre conversion est un refus `plan_invalide`.

| Section | Contenu en B2 | Domaine | Lu par |
|---|---|---|---|
| `version_plan` | entier | `1L` | `plan` |
| `arrete` | date | une `Date` finie ; au plus la date d'extraction (contrôlée à l'exécution par `controler_base()`, refus `arrete_posterieur_extraction`) | tous |
| `perimetre$garanties` | vecteur de codes | sous-ensemble non vide, sans doublon, des garanties du catalogue ; **B2 : `deces` seul** | tous |
| `perimetre$referentiels` | vecteur | sous-ensemble non vide de `comptes_sociaux`, `solvabilite_2` ; **B2 : `solvabilite_2` est refusé** (`plan_invalide`, message : « aucune méthode de meilleure estimation avant B6 ») | tous |
| `perimetre$segmentations` | liste nommée, éventuellement `list()` | nom libre (ASCII, `[a-z0-9_]+`, différent de `ensemble`) → `list(regle = <règle>)` ; règle dans `contrat`, `adherent`, `college`, `gestionnaire`, `nature_contrat`, `secteur_activite`, `annee_survenance`, `ligne_activite` ; pour `ligne_activite`, `correspondance` : liste nommée garantie → code de ligne d'activité (`character`), couvrant chaque garantie du périmètre | `donnees` (segments, (4)) |
| `tables` | liste nommée par **usage** | usage du catalogue (`usages_tables.csv`) ou usage commun `serie_tme` ; chaque entrée : `identifiant` (`character`), `empreinte` (`character`, 32 hexadécimaux : **obligatoire en B2**, aucune table n'étant embarquée), `statut` (`homologuee`, `certifiee`, `experience`, `loi_anc`, `fictive`), `hors_axes` (`refus`, `derniere_valeur`) | `tables`, familles |
| `taux` | liste garantie → poste → référentiel | `double` dans [−0,05 ; 0,20] **ou** la chaîne `taux_tarif` (taux du tarif de chaque contrat, hypothèse D03h appliquée s'il manque) ; B2 : `taux$deces$provision_mathematique_temporaire_deces$comptes_sociaux` | `risque_en_cours` |
| `frais` | liste garantie → poste → référentiel → entrées du poste | voir § 2.4 | familles |
| `revalorisation` | `capital_deces` | voir § 2.5 | `engagement` |
| `conventions` | entrées | voir § 2.6 | `donnees`, familles |
| `postes` | liste garantie → poste → `list(methode, parametres)` ; pour P3, par champ (`individuel`, `collectif`) | voir § 2.7 | familles |
| `donnees` | sous-schéma de l'ADR 0010, point 17 | **inchangé** (`exclusions`, `hypotheses`, `seuils`, `evaluations_gestion`) ; `valider_plan()` le valide par la fonction de `donnees` qui le lit déjà (`.lire_declarations()`), sans en changer la forme | `donnees` |
| `restitution` | `echeanciers`, `triangles` | `echeanciers` : `"tous"`, `"aucun"` ou vecteur non vide d'identifiants (dossiers ou contrats) ; `triangles` : `"aucun"` (seule valeur admise avant B3) | (4) |
| `liens` | `list()` ou liste de liens | B2 : `list()` ; un lien du catalogue (`liens.csv`) entre deux garanties du périmètre doit y figurer, sinon refus `lien_non_declare` (sans objet en B2 : `deces` seule) | (4) |
| `graine` | entier | un `integer` fini (consigné ; aucun tirage en B2) | (4) |

### 2.3 Règle d'exigence (sans valeur par défaut)

Une entrée est **exigée** si un lecteur du périmètre la lit ; exigée et absente : refus `plan_incomplet` qui nomme le chemin manquant (par exemple `postes$deces$capitaux_non_reclames$parametres$critere`) ; présente et mal formée : `plan_invalide` ; présente et non lue (entrée inconnue du schéma) : `plan_invalide`. Une entrée connue du schéma mais non lue par le périmètre (par exemple `conventions$limite_age` en B2) est **admise** et canonisée.

Le lecteur s'entend de la méthode déclarée d'un poste du périmètre, indépendamment des données : `valider_plan()` ne voit pas la base. Les mentions de données de la colonne « Lecteur » du § 2.4 (prime unique, primes périodiques) désignent le flux qui lit l'entrée, non une condition d'exigence. Seules les exigences qui dépendent des données (couverture de `taux_par_annee`, § 2.5) sont contrôlées à l'exécution (erratum v1.0.1).

Exigences propres à B2 :
- chaque poste du catalogue pour une garantie du périmètre est déclaré dans `postes` (B2 : les trois postes de `deces`). **Motif** : un total qui omettrait un poste du catalogue sous-évaluerait en silence (même motif que le total arrêté, § 6.1). Les postes absents du catalogue (P4 tardifs en B2) ne sont pas dans le total : limite restituée par la fiche (`parametres_retenus$postes`) et par la documentation de fond (§ 10.2, point d'attention A2) ;
- `tables$serie_tme` exigée dès que `deces` est au périmètre en comptes sociaux (indicateurs `R132_3_1`, M128 ; `A132_1`, M124) ;
- `tables$mortalite_tarif` exigée si P3 `individuel` déclare `prospective_prime_pure` ou `prospective_prime_declaree` ;
- `taux$deces$provision_mathematique_temporaire_deces$comptes_sociaux` exigé si P3 `individuel` déclare une méthode prospective ;
- `revalorisation$capital_deces` (`taux_par_annee`, `prorata`) exigée dès que P1 ou P2 est au périmètre ; `taux_futur` exigé si une méthode « règlement » est déclarée (`capital_dossier_reglement` ou `capital_revalorise_reglement`) ; `duree_sans_depot_annees` exigée avec `capital_revalorise_reglement` ; `delai_reglement_jours` (paramètre de P1) exigé avec `capital_dossier_reglement` (I1, tranché le 10/11/2026, avis Fable).

### 2.4 Section `frais` (B2)

| Chemin | Domaine | Lecteur | Motif |
|---|---|---|---|
| `frais$deces$sinistres_declares_non_regles$comptes_sociaux$taux_chargement_psap` | `double` ≥ 0 | P1 | chargement de gestion de la PSAP vie, flux de frais du poste (Q10 ; ANC 143-11 par analogie, hypothèse déclarée) |
| `frais$deces$capitaux_non_reclames$comptes_sociaux$taux_chargement_psap` | `double` ≥ 0 | P2 | idem |
| `frais$deces$provision_mathematique_temporaire_deces$comptes_sociaux$taux_chargement_gestion` | `double` ≥ 0 : fraction annuelle du capital | P3 individuel, prime unique | frais futurs de gestion (R343-3, 1°, 2e phrase, vérifié au recensement) |
| `...$taux_chargement_acquisition` | `double` dans [0 ; 1] : fraction du capital | P3 individuel, primes périodiques | zillmérisation (A343-1-1, 1er alinéa, vérifié au recensement ; aucun plafond codé, texte du plafond non établi) |
| `...$taux_chargement_cotisation` | `double` dans [0 ; 1[ | P3 `prorata_cotisation` et `prospective_prime_declaree` | cotisation nette d'un chargement déclaré |

La documentation propose 0 pour les chargements d'acquisition et de gestion de P3 (jugement d'expert prudent, provision plus forte ; recensement § 3.3) ; ce n'est jamais une valeur appliquée sans déclaration.

### 2.5 Section `revalorisation` (B2)

`revalorisation$capital_deces` :

| Entrée | Domaine | Lecture |
|---|---|---|
| `taux_par_annee` | `double` nommé, noms = années civiles sur quatre chiffres, valeurs dans [−0,05 ; 0,20] | taux de revalorisation **retenu** par année civile (M128 : déclaré ; un taux inférieur à `R132_3_1` est signalé, M62) ; il doit couvrir chaque année civile de la date de décès la plus ancienne des dossiers de P1 et P2 à l'année de l'arrêté (une année manquante à l'exécution est un refus `plan_incomplet` qui nomme l'année et le premier dossier) ; il **peut** porter des années postérieures à l'arrêté (N+1 : le minimum `R132_3_1` de N+1 est calculable à l'arrêté du 31/12/N), employées par les méthodes « règlement » avant `taux_futur` |
| `prorata` | `simple`, `compose` | composition dans l'année civile : `simple` : 1 + r_y · j / J_y ; `compose` : (1 + r_y)^(j / J_y) ; d'une année à l'autre, produit (capitalisation au 31 décembre) |
| `taux_futur` | `double` dans [−0,05 ; 0,20] | exigé si une méthode « règlement » est déclarée ; taux constant des années postérieures à la dernière année de `taux_par_annee` |
| `duree_sans_depot_annees` | `integer` ≥ 1 (années, horizon à l'anniversaire de A) | exigé avec `capital_revalorise_reglement` : horizon des dossiers sans dépôt légal (décès antérieur au 1er janvier 2015 d'une temporaire décès, L132-27-2, I, vérifié en 0a) |

Les dates étant prises en fin de journée (§ 2.6), la part de l'année civile y dans l'intervalle (début, fin] vaut j_y = min(fin ; 31/12/y) − max(début ; 31/12/(y − 1)) jours quand elle est positive ; J_y = longueur de l'année y (`exact_exact`) ou 365 (`exact_365`). La revalorisation d'avant la connaissance du décès suit les mêmes taux (R132-3-1, 3° : clause contractuelle si elle revalorise net de frais, sinon le 2° dès le décès) : **limite** de B2, le dictionnaire ne portant aucune clause contractuelle de revalorisation du capital décès ; elle est écrite dans la fiche de méthode.

### 2.6 Section `conventions` (contenu fixé en B2)

| Entrée | Domaine B2 | Exigée | Lecture |
|---|---|---|---|
| `age` | `CONVENTIONS_AGE` (`revolu`, `millesime`, `plus_proche`, `naissance_31_decembre`) | toujours (D02c lit l'âge de tout assuré ; P3) | `outils::calculer_age()` |
| `instant_date` | `fin_journee` (seule valeur en B2) | toujours | l'arrêté est l'instant de fin de la journée A, et toute date de la base et du calcul est prise au même instant de sa journée : un fait daté de A est passé, un anniversaire daté de A coïncide avec l'arrêté, et la durée entre deux dates est leur différence en jours (la vue du dictionnaire, § 6, lit « ≤ A ») ; une période [début, fin] bornes incluses couvre fin − début + 1 jours, dont fin − A postérieurs à l'arrêté. **Motif de la valeur unique** : la vue est fixée par le dictionnaire en « ≤ A » ; une convention `debut_journee` contredirait la vue. La liste reste fermée et extensible |
| `repartition_annee` | `uniforme`, `force_constante` | toujours | probabilité de décès sur une fraction d'année d'âge (P3) : `uniforme` : _s q_{x+t} = s · q_x / (1 − t · q_x) ; `force_constante` : _s p_{x+t} = (1 − q_x)^s ; formules dans la fiche de méthode ; B3 la lira pour la date moyenne de décès |
| `fractionnement` | `echeances_exactes` (seule valeur en B2) | toujours | une prime fractionnée est un flux à chaque échéance, pondéré par la survie à cette date (aucune approximation de type Woolhouse) |
| `decompte_jours` | `exact_exact`, `exact_365` | toujours | durée en années entre deux dates : `exact_exact` : somme sur les années civiles y des j_y / J_y (découpage du § 2.5) ; `exact_365` : jours / 365 ; lue par la revalorisation et l'actualisation (le même découpage pour les deux rend exact le recoupement du critère 3.13) |
| `limite_age` | `list(regle, age)` de la septième série | **non exigée en B2 par `valider_plan()`** (aucune garantie `rente_education` ni `double_effet` au catalogue de B2) ; exigée par `controler_base()` selon le § 6.3 | D07 (c) ; familles en B4 et B6 |

`decompte_jours` est une entrée **nouvelle** : `ENTREES_CONVENTIONS` (`R/donnees.R`) l'admet, sans contrôle de valeur dans `donnees` (même régime que `instant_date` aujourd'hui) ; c'est `valider_plan()` qui contrôle les valeurs de toutes les entrées.

### 2.7 Section `postes` (B2)

`postes$deces` porte exactement les trois postes du catalogue de B2 :

| Poste | Forme | Méthodes admises (options) | Paramètres |
|---|---|---|---|
| `sinistres_declares_non_regles` | `list(methode, parametres)` | `capital_dossier` (recommandée) ; `capital_dossier_reglement` (alternative, point prudent) | `taux_sans_suite` (`double` dans [0 ; 1], dossiers à l'état `ouvert` de sinistre `deces`) ; `probabilite_reconnaissance_iad` (`double` dans [0 ; 1], dossiers `ouvert` de sinistre `iad`) ; `structure_familiale` : `list(taux_conjoint = [0 ; 1], nombre_enfants = double ≥ 0)` ; `age_limite_enfant_majoration` (`integer` 0 à 30) ; `liens_conjoint_majoration` (sous-ensemble non vide de `conjoint`, `partenaire_pacs`, `concubin`). `delai_reglement_jours` (`integer` ≥ 0, exigé avec `capital_dossier_reglement`). La documentation propose, en comptes sociaux, `taux_sans_suite = 0` et `probabilite_reconnaissance_iad = 1` (Q6) |
| `capitaux_non_reclames` | `list(methode, parametres)` | `capital_revalorise` (recommandée) ; `capital_revalorise_reglement` (alternative, point prudent, borne supérieure de la lecture (b)) | `critere` : sous-ensemble non vide de `beneficiaire_non_identifie`, `sans_evenement` (réunion) ; `mois_sans_evenement` (`integer` ≥ 1, exigé avec `sans_evenement`) ; mêmes paramètres de reconstitution du capital et de facteur d'issue que P1 (`taux_sans_suite`, `probabilite_reconnaissance_iad`, `structure_familiale`, `age_limite_enfant_majoration`, `liens_conjoint_majoration`), sans `delai_reglement_jours` (un capital non fixé se reconstitue de même ; erratum v1.0.1) |
| `provision_mathematique_temporaire_deces` | `list(individuel = list(methode, parametres), collectif = list(methode, parametres))` | individuel : `prospective_prime_pure`, `prospective_prime_declaree` ; collectif : `prorata_cotisation` | individuel : `pas` (`an`, `mois`), `paiement_capital` (`fin_pas`, `milieu_pas`), `plancher` (`par_contrat`) ; collectif : `list()` |

Les témoins (`retrospective`, `chain_ladder_*`) ne sont **jamais** des options : un plan qui les déclare est refusé (`plan_invalide`, message : « méthode témoin, non option »).

### 2.8 Canonisation, sérialisation, fiche

- **Canonisation** (`canoniser_plan()`, après validation) : sections dans l'ordre du point 17 ; clés fixes du schéma dans l'ordre des tableaux ci-dessus ; clés libres (usages, années de `taux_par_annee`, noms de segmentations, garanties, postes) triées par `sort(method = "radix")` ; vecteurs-ensembles (`garanties`, `referentiels`, `critere`, `liens_conjoint_majoration`) triés, sans doublon (un doublon est `plan_invalide`, jamais retiré en silence) ; types canoniques. Deux plans de même sens donnent des octets `ecrire_plan()` identiques.
- **Sérialisation** : `ecrire_plan(plan)` = `ecrire_liste(canoniser_plan(valider_plan(plan)))` ; `lire_plan(octets)` = `lire_liste()` puis classe `plan_calcul`, **sans** valider (la validation est celle de `calculer_provisions()`), aller-retour `identical` et **octet pour octet** (`ecrire_plan(lire_plan(o))` identique à `o`).
- **Fiche** (`fiche_calcul`, ADR 0007, point 3 ; ADR 0010, points 6 et 10) : `plan` (canonique), `parametres_retenus` (liste de `data.frame` : `postes`, `tables`, `hypotheses_defaut`, `exclusions`, `plafonds`, `colonnes_ecrasees`, `tables_absentes`), `empreintes` (`donnees` : une empreinte par table de la base, MD5 de `ecrire_valeurs(…, "octets")` des colonnes dans l'ordre du dictionnaire, noms compris ; `fichiers` : reprise de l'argument `provenance` ; `tables` : empreinte de l'original de chaque table lue ; `resultat` et `code` : remplis en (4) ; `representation` = `REPRESENTATION_CANONIQUE`), `versions` (`r`, `provie`, `fiche` = `VERSION_FICHE` = 1, `dictionnaire`), `plateforme` (`decrire_plateforme()`), `graine` (valeur et `RNGkind` fixé par `avec_graine()`). `ecrire_fiche()` / `lire_fiche()` : même règle d'aller-retour octet pour octet. En (1), `construire_fiche()` se teste avec `parametres_retenus` vides de forme fixe et des empreintes calculées sur une base de test.
- **Empreinte du code** (remplie en (4)) : MD5 de `ecrire_liste()` de la liste, triée par nom, des fonctions de l'espace de noms de `provie`, chacune `paste(deparse(f), collapse = "\n")` ; témoin d'identité sur une même plateforme, jamais un critère de rejeu chez un tiers (ADR 0007, point 9).

### 2.9 Exports de (1)

`valider_plan()`, `canoniser_plan()`, `ecrire_plan()`, `lire_plan()`, `ecrire_fiche()`, `lire_fiche()`, `catalogue_garanties()` ; `S3method(print|format, plan_calcul|fiche_calcul)`. Appelants hors du package : l'application (onglet Plan : validation, export, import ; onglet Rapport : fiche) et l'utilisateur sans Shiny (ADR 0010, point 13).

## 3. Module `tables` — issue (2)

### 3.1 Ce qui est embarqué : rien

Décision du mainteneur du 10 novembre 2026, sur la lecture de 0a : **aucune table réglementaire n'est embarquée en B2** (les valeurs des tables homologuées n'ont pas été lues sur le fac-similé du JO ; la licence de la série TME n'est pas établie, #10). Conséquences :
- pas de répertoire `inst/extdata/tables/` ni `inst/extdata/taux/` en B2, pas de commit `donnees:` de table, pas de fichier de provenance de table embarquée ;
- `charger_table()` (ADR 0010, point 13) **n'est pas exporté en B2** : il n'aurait aucun appelant. Il entre avec la première table embarquée (issue de transcription contre-vérifiée, créée par la session, § 10.3) ;
- les tests et les jeux emploient une **table de mortalité fictive déclarée** et une **série TME fictive déclarée** (§ 3.6), au statut `fictive`.

### 3.2 Formats admis en B2

`formats_tables()` (exporté) rend un `data.frame` (`format`, `nature`, `colonnes`, `types`, `description`, `conversion`) :

| `format` | `nature` | Colonnes (types) | Contraintes | Conversion (fonction nommée de `tables`) |
|---|---|---|---|---|
| `lx_age` | `mortalite` | `age` (`integer`), `lx` (`numeric`) | âges entiers consécutifs croissants ; `lx` fini ≥ 0, non croissant, premier > 0 | `convertir_lx_qx()` : q_x = 1 − l_{x+1} / l_x pour chaque âge x sauf le dernier ; axe `age` = tous les âges sauf le dernier ; un l_x nul rend les âges suivants hors axes (résultat exact) |
| `serie_tme_mensuelle` | `taux` | `mois` (`character`, `AAAA-MM`), `taux_pourcent` (`numeric`) | mois consécutifs croissants, sans doublon ; valeurs finies (négatives admises) | `convertir_pourcent()` : valeur / 100 ; axe `date` = entier 12 × année + mois − 1 |

Un contenu qui ne respecte pas son format est un refus `format_table_inconnu` (message : contrainte violée, première ligne) ; un format hors de la liste, le même motif. **Hors B2** : le format à en-tête de métadonnées d'`outil_tables`, dont la spécification n'est pas dans le dépôt (ADR 0007, point 5 : inventaire sur le poste du mainteneur) ; issue proposée (§ 10.3, IP3). Le format natif de l'export Webstat n'est pas établi : `serie_tme_mensuelle` est un format de l'outil, déclaré, et la mise en forme d'un export Webstat est hors moteur.

### 3.3 Représentation `table_provie`

Celle de l'ADR 0010, point 15, avec deux précisions (annotations, § 9) :
- `statut` admet `fictive` en plus de `homologuee`, `certifiee`, `experience`, `loi_anc` : une table de test ne doit jamais se présenter comme une table d'expérience ;
- `origine$empreinte` est le MD5 de l'**écriture canonique du contenu lu** (`ecrire_valeurs(…, "octets")` des colonnes du format, dans leur ordre, noms compris), indépendant de la mise en forme du fichier ; l'empreinte du **fichier** va dans l'argument `provenance` de `calculer_provisions()` (couche de lecture). Une même table lue d'un fichier ou construite en mémoire a donc la même empreinte.

Fonctions de `tables` : `construire_table(donnees, format, identifiant, statut, provenance)` (interne, appelée par `lire_table()` et par les tests) ; `probabilite(table, ..., hors_axes)` vectorisée (mortalité : `age` → q_x ; taux : `date` → valeur), `hors_axes` = déclaration du plan : `refus` rend `NA` et l'indice des points hors axes à l'appelant, qui arrête le poste (motif d'arrêt `hors_axes`, § 6.2) ; `derniere_valeur` prend la valeur de l'axe la plus proche ; `S3method(print|format, table_provie)` (décomptes seulement).

`lire_table(chemin, format, identifiant, statut, provenance)` (module `lecture`, exporté) lit le CSV en texte, contrôle colonnes et types contre `formats_tables()`, refuse sans convertir (`fichier_invalide`, `type_incompatible`, `format_table_inconnu`), puis appelle `tables::construire_table()`. **Arête nouvelle du graphe** : `lecture` → `tables` (annotation, § 9 ; motif : la conversion depuis un format natif est une fonction de `tables`, et `lecture` doit connaître les colonnes du format ; l'arête reste hors de la chaîne du moteur).

### 3.4 Tables par usage et contrôle d'empreinte

À l'exécution ((4), mais la fonction est livrée et testée en (2)) : `tables::resoudre_tables(plan_tables, tables_recues, usages_exiges)` rend, pour chaque usage exigé, l'objet `table_provie` ; refus `table_absente` (usage exigé sans entrée du plan, ou entrée sans table reçue sous cet identifiant) ; refus `empreinte_discordante` (empreinte du plan ≠ `origine$empreinte`, première discordance dans l'ordre des usages triés) ; refus `plan_invalide` si le `statut` déclaré par le plan diffère de celui de la table, ou si sa `nature` n'est pas celle de l'usage (`usages_tables.csv`). Les lignes de `fiche$parametres_retenus$tables` (`usage`, `garantie`, `identifiant`, `statut`, `format_natif`, `provenance`, `conversion`, `empreinte`) en sortent.

### 3.5 Indicateurs : `R132_3_1`, `A132_1`, `tarif_vie`

Toute date « disponible à une date D » suit une déclaration du plan, `tables$serie_tme$decalage_publication_mois` (`integer`, 1 ou 2) : le dernier mois disponible à la date D est le mois de D moins ce décalage. **Motif** : le calendrier de publication de la série n'est pas établi (manque de 0a) ; c'est une hypothèse déclarée, à statut d'approximation, sans valeur par défaut. *(Cette entrée s'ajoute à l'entrée de l'usage `serie_tme` : `identifiant`, `empreinte`, `statut`, `hors_axes`, `decalage_publication_mois`.)*

| Règle | Fonction de `tables` | Définition | Statut | Émis en B2 par |
|---|---|---|---|---|
| `R132_3_1` | `minimum_r132_3_1(serie, annee, decalage)` | pour l'année civile N : min(moyenne arithmétique des douze derniers mois disponibles au 1er novembre N − 1 ; dernier mois disponible à cette date) (R132-3-1, vérifié en 0a : « le moins élevé ») ; **aucun plancher** (I4) ; `NA` si un mois manque | exact sous la série ; l'assimilation de la série Banque de France au « taux moyen des emprunts de l'État » est une hypothèse déclarée (approximation) | `engagement` (P1, P2) : une ligne par année civile de `taux_par_annee` employée, années postérieures à l'arrêté comprises (N+1) |
| `A132_1` | `plafond_a132_1(serie, date, nature_primes, duree_au_plus_8_ans, decalage)` | **taux de référence** : TME semestriel = moyenne des six derniers mois disponibles à la date ; `nature_primes = "unique"` et `duree_au_plus_8_ans = TRUE` : 75 % ; sinon : min(3,5 % ; 60 %) (A132-1, vérifié en 0a ; I2 lecture (i) et I3 lecture (b), tranchés le 10/11/2026, avis Fable) ; une seule ligne par contrat ; **échelle d'A132-1-1** (établie par `regulatory`) : le plafond en vigueur T ne change pas tant que T − 0,10 point < référence < T + 0,35 point ; sans historique, T ∈ ]max(référence − 0,35 point ; 0) ; référence + 0,10 point[ ; d'où `depassement` à **trois valeurs** pour un taux du tarif τ : `TRUE` si τ ≥ référence + 0,10 point (dépassement certain) ; `FALSE` si τ ≤ max(référence − 0,35 point ; 0) (dépassement exclu) ; `NA` entre les deux. **Délai de trois mois** d'A132-1-1 : **non pris en compte** (à confirmer par `regulatory`), mention `delai_3_mois_non_pris_en_compte` dans `detail` | approximation (série assimilée au taux du texte ; historique du plafond inconnu, d'où l'encadrement) | `risque_en_cours` (P3 individuel) : à la date d'effet de la version de garantie (souscription, M124) et à l'arrêté (`detail` contient `approximation_arrete`) |
| `tarif_vie` | — (contrôle dans `risque_en_cours`) | taux retenu de P3 > taux du tarif du contrat (ANC 142-3, vérifié au recensement) ; taux du tarif manquant : hypothèse D03h déclarée (M86) | exact | `risque_en_cours` (P3 individuel, méthode prospective) : une ligne par contrat |

Forme des lignes (ADR 0010, point 6, champ `indicateurs`) : `regle`, `poste`, `garantie`, `valeur_regle`, `valeur_retenue`, `depassement`, `detail`. Pour `R132_3_1`, `depassement` vaut `TRUE` quand le taux **retenu est inférieur** au minimum (règle de sens inverse, écrite dans `detail` : `annee=AAAA;minimum`) ; `detail` ajoute `indicateur_negatif` (I4) et `ip_renvoi_L932-23_incertain` (I5) le cas échéant. Pour `A132_1`, `valeur_regle` est le taux de référence, `valeur_retenue` le taux du tarif du contrat (hypothèse D03h appliquée s'il manque) et `detail` = `id_contrat=…;date=AAAA-MM-JJ;nature_primes=…;borne_basse=…;borne_haute=…;type_organisme=…;delai_3_mois_non_pris_en_compte` ; `date_terme` absente : `valeur_regle = NA`, `depassement = NA`, `detail` contient `terme_absent`, sans hypothèse par défaut (I2). Un indicateur incalculable (série incomplète) a `valeur_regle = NA`, `depassement = NA` et `detail` contient `serie_incomplete` ; il n'arrête aucun poste.

**Recoupement en CI** : `minimum_r132_3_1()` recalculé par une seconde voie dans le test (fenêtre glissante par `stats::filter(x, rep(1/12, 12), sides = 1)`), égalité à 1e-15 près (recensement, § 7).

### 3.6 Table et série fictives déclarées (tests, jeux)

- **Table de mortalité fictive** `mortalite_fictive_b2` (format `lx_age`, statut `fictive`) : âges 40 à 43, l_x = 100 000 ; 99 000 ; 97 020 ; 94 109,4, soit q_40 = 0,01, q_41 = 0,02, q_42 = 0,03 (exact, à l'arrondi binaire près : mesure m7, `q41 = 0.020000000000000018`). Écrite dans le fichier de test, avec sa déclaration « table fictive, sans source ».
- **Série TME fictive** `tme_fictive_b2` (format `serie_tme_mensuelle`, statut `fictive`) : 3,00 % de 2023-01 à 2024-09 ; 3,20 % en 2024-10 ; 3,00 % de 2024-11 à 2025-09 ; 2,40 % en 2025-10 ; 3,00 % de 2025-11 à 2025-12 (36 mois). Écrite dans le fichier de test. Valeurs attendues : § 7.4, cas X1 à X6.
- Le **fichier de provenance** d'une table embarquée (source, URL, date de consultation, licence, empreintes du fichier source et de la table transcrite, méthode de transcription, contre-vérification ; ADR 0009, point 3) n'est pas produit en B2 ; sa forme, alignée sur celle d'`outil_tables` (manque de 0a), est fixée par l'issue de transcription.

### 3.7 Exports de (2)

`lire_table()`, `formats_tables()` ; `S3method(print|format, table_provie)`. Appelants : l'utilisateur sans Shiny et l'application (import d'une table) ; les tests.

## 4. États, transitions, catalogue et `etats_a_date()`

### 4.1 Catalogue de B2 (`inst/extdata/garanties/`, livré en (1))

Le catalogue de B2 ne porte **que la garantie `deces`** et ses trois postes : chaque garantie entre avec sa branche (test de suppression de l'ADR 0005, point 2 ; une ligne de méthode non implémentée n'est jamais au catalogue). Il reprend les lignes du recensement (§ 8) restreintes à B2.

`garanties.csv` :
```csv
code_garantie,famille_garanties,jalon
deces,deces,v1
```

`etats.csv` (états du modèle multi-états lus en B2) :
```csv
etat,individu,absorbant,description
actif,assure,FALSE,Assuré couvert et vivant
deces,assure,TRUE,Assuré décédé (fait générateur du capital décès)
iad,assure,TRUE,Invalidité absolue et définitive : capital versé par anticipation ; couverture décès éteinte
```
`sorti` (meilleure estimation seulement) entre en B6 ; les états des bénéficiaires, en B4.

`transitions.csv` :
```csv
depuis,vers,usage,pas,axes,decomposition
actif,deces,mortalite_tarif,an,age,sans table incidence_iad : invalidité absolue et définitive comprise dans la mortalité (jugement d'expert déclaré, recensement § 3.3)
```
`actif → iad` (`incidence_iad`, facultative) n'entre pas en B2 : aucune méthode de B2 ne la lit et le dictionnaire ne porte pas de table d'incidence ; elle entrera avec la première méthode qui la lit (B6, limites du contrat).

`flux.csv` :
```csv
code_garantie,flux,type_flux,etat_payeur,parametres
deces,capital,capital_unique,deces,taux_capital;capital_forfaitaire;majoration_conjoint;majoration_enfant;age_fin_garantie
deces,capital_iad,capital_unique,iad,taux_capital;capital_forfaitaire;majoration_conjoint;majoration_enfant
deces,prime,prime_periodique,actif,prime_periodique;taux_cotisation;cotisation_forfaitaire
deces,frais,frais,actif,
```
Types de flux de B2 (liste fermée, A2 du recensement) : `capital_unique`, `prime_periodique`, `frais`. La revalorisation légale n'est pas un flux : c'est un facteur appliqué au flux `capital` (§ 5.4).

`usages_tables.csv` :
```csv
code_garantie,usage,nature,axes
deces,mortalite_tarif,mortalite,age
```
`serie_tme` est un usage commun du plan (nature `taux`, axe `date`), connu de `plan` et de `tables` sans ligne de catalogue (recensement, § 8.4).

`postes.csv` :
```csv
code_garantie,poste,famille,composantes,regle_combinaison,provision_comptes_sociaux,meilleure_estimation,methodes,temoins
deces,sinistres_declares_non_regles,engagement,,,psap_vie,TRUE,capital_dossier;capital_dossier_reglement,
deces,capitaux_non_reclames,engagement,,,psap_vie,TRUE,capital_revalorise;capital_revalorise_reglement,
deces,provision_mathematique_temporaire_deces,risque_en_cours,,,provision_mathematique_vie,FALSE,individuel:prospective_prime_pure;individuel:prospective_prime_declaree;collectif:prorata_cotisation,individuel:retrospective
```
Lecture de `methodes` : la première méthode de chaque champ est la **recommandée**, les suivantes sont **alternatives** (I1, tranché le 10/11/2026, avis Fable : `capital_dossier` et `capital_revalorise` recommandées, les méthodes « règlement » alternatives au statut de point prudent ; la méthode écartée « (b) actualisée à un taux prudent » n'a pas de ligne, n'étant ni option ni témoin) ; le préfixe `champ:` suit la forme du préfixe de composante (A1 du recensement). Les témoins `chain_ladder_charges_recalculees` et `chain_ladder_paiements` de P1 entrent en B3 avec la famille « triangle » (ils n'ont pas d'implémentation en B2) ; `retrospective` est implémenté en B2 comme témoin (recoupement exact, § 5.5).

`liens.csv` : en-tête seul en B2 (`garantie,garantie_liee,lien`).

**`lectures.csv`** (nouveau, annotation § 9) : la table de couverture lisible par machine, une ligne par (`code_garantie`, `poste`, `table`, `colonne`) que le poste lit, transcrite du dictionnaire, § 8, restreinte à ce que B2 lit réellement (§ 5). Elle sert à l'arrêt de poste (§ 6.2), à `postes_arretes` et à l'enjeu par poste ((4)). Contenu de B2 :

| Poste | Colonnes lues |
|---|---|
| `sinistres_declares_non_regles` | `extraction.type_organisme` ; `sinistres` : `id_sinistre`, `id_assure`, `nature_sinistre`, `date_survenance`, `date_declaration`, `date_instruction`, `date_saisie` ; `dossiers` : `id_dossier`, `id_sinistre`, `id_garantie_souscrite`, `date_ouverture` ; `evenements` : `id_evenement`, `id_sinistre`, `id_dossier`, `type_evenement`, `date_effet`, `date_saisie`, `montant`, `motif` ; `prestations` : `id_prestation`, `id_dossier`, `type_prestation`, `nature_mouvement`, `date_reglement`, `montant`, `date_saisie` ; `beneficiaires` : `id_beneficiaire`, `id_dossier`, `qualite`, `date_saisie` ; `garanties_souscrites` : `id_garantie_souscrite`, `id_contrat`, `code_garantie`, `date_effet`, `type_assiette` ; `parametres` : `id_garantie_souscrite`, `parametre`, `valeur` ; `contrats` : `id_contrat`, `nature_contrat` ; `affiliations` : `id_affiliation`, `id_assure`, `id_contrat`, `date_debut`, `date_fin`, `date_saisie`, `salaire_reference` ; `famille` : `id_membre`, `id_sinistre`, `lien`, `date_naissance`, `situation`, `date_deces`, `date_saisie` |
| `capitaux_non_reclames` | les colonnes de la ligne précédente, plus `sinistres.canal_declaration` |
| `provision_mathematique_temporaire_deces` | `contrats` : `id_contrat`, `nature_contrat`, `id_assure`, `date_effet`, `date_terme`, `date_fin`, `motif_fin`, `date_saisie_fin` ; `garanties_souscrites` : `id_garantie_souscrite`, `id_contrat`, `code_garantie`, `date_effet`, `date_fin`, `periodicite_cotisation`, `taux_technique_tarif` ; `parametres` : `id_garantie_souscrite`, `parametre`, `valeur` ; `assures` : `id_assure`, `date_naissance` ; `sinistres` : `id_sinistre`, `id_assure`, `nature_sinistre`, `date_survenance`, `date_saisie` ; `cotisations` : `id_cotisation`, `id_garantie_souscrite`, `nature_mouvement`, `debut_periode`, `fin_periode`, `date_mouvement`, `montant` |

Écarts assumés au dictionnaire, § 8 (qui n'est pas une règle de calcul) : P1 et P2 ne lisent pas `assures.situation_familiale` ni `assures.nombre_enfants_charge` (la famille d'un sinistre non instruit suit la structure familiale du plan, recensement § 3.1, et D03d n'est implémenté qu'en Bdr, M235) ; P3 ne lit pas `assures.sexe` (une seule table `mortalite_tarif` par plan en B2, limite restituée : les tarifs unisexes et sexués d'un même portefeuille ne se distinguent pas) ; P1 et P2 ne lisent pas `prestations.dont_revalorisation` (le solde se calcule par le § 5.4, la part de revalorisation d'un paiement n'y change rien).

### 4.2 Sortie de `etats_a_date()`

Fonction du module `donnees` (ADR 0010, point 14). **Décision de forme** (annotation, § 9) : elle lit l'objet de vue que construit `donnees` une seule fois, et non la base brute :

- `vue_a_date(donnees, arrete, declarations, conventions)` (interne à `donnees`) rend une liste `vue_provie` : `bilan` (la liste que rend `controler_base()`, **identique à l'octet**, `controler_base()` devenant `vue_a_date(...)$bilan`) ; `retenu` (par table, logique) ; `parties` (par table à partie, logique de Kleene, `.visibilite_a(ctx, "vue")$parties`) ; `exclu` (par famille de calcul puis par table, logique : lignes exclues par une déclaration `X` d'action `exclure` pour cette famille, cascade du dictionnaire, § 1.10, comprise) ; `hypotheses` (déclarations `H` appliquées, avec leurs lignes : D03h et les autres motifs qui entrent dans un calcul) ; l'environnement interne nécessaire à `valeurs_vue()` ;
- `valeurs_vue(vue, table, colonne)` (interne) : `.valeurs_vue()` sur cette vue ;
- `etats_a_date(vue, garanties)` rend un `data.frame`, une ligne par **dossier retenu à l'arrêté** dont la garantie souscrite a un `code_garantie` de `garanties` (B2 : `deces` seule ; tout autre code est une erreur de programmation, `stop()` interne et test) ; colonnes, dans cet ordre :

| Colonne | Contenu (B2) |
|---|---|
| `id_sinistre`, `id_dossier` | clés |
| `etat` | état du sinistre (`etats.csv`) : `deces` pour `nature_sinistre = deces`, `iad` pour `iad` |
| `date_entree_etat` | `sinistres.date_survenance` |
| `categorie_invalidite` | `NA` (B5) |
| `montant_en_vigueur` | montant du dernier `fixation_capital` retenu du dossier (date d'effet, puis ordre du § 4 du dictionnaire, puis date de saisie, puis `id_evenement`) ; `NA` sans fixation |
| `etat_dossier` | `ouvert`, `capital_du`, `clos` (automate ci-dessous) |
| `date_etat_dossier` | date d'effet de l'événement qui a fixé `etat_dossier` ; `date_ouverture` pour `ouvert` initial |
| `motif_cloture` | motif du `cloture_dossier` en vigueur si `clos`, `NA` sinon |
| `instruit` | logique de Kleene : `TRUE` instruit à l'arrêté ; `FALSE` non instruit de façon déterminée ; `NA` inconnu (lecture de la partie, § 4.3) |

**Automate du dossier `deces`** (événements retenus du dossier, dans l'ordre ci-dessus) : départ `ouvert` ; `fixation_capital` : `ouvert` → `capital_du` (montant mis à jour ; sur un dossier `clos`, le montant est mis à jour et l'état reste `clos`) ; `cloture_dossier` : → `clos` (motif) ; `reouverture_dossier` : `clos` → état d'avant la clôture ; `demande_mise_a_jour`, `mise_a_jour` : sans effet. Un événement de type incompatible avec le dossier relève de D10 (a), refusé par `donnees` : la famille ne le voit pas. L'état « réglé » de `CONTEXT.md` n'est pas un état de l'automate : un dossier `capital_du` entièrement payé a un solde nul (§ 5.4).

### 4.3 Lecture des parties de ligne : #51 et #54 (M234)

**Confirmation demandée par M234 : « illisible » vaut « inconnu », et non « absente ».** Résultat de jugement, motivé :
1. Le dictionnaire, § 1.4, fixe le sens d'un **manquant** colonne par colonne ; pour `sinistres.date_instruction`, un manquant signifie « non instruit » (sens « non survenue »). Un champ **illisible par sa forme** n'est pas un manquant (§ 1.6 : seul le champ vide l'est) : une valeur a été écrite, que l'outil ne sait pas lire. L'information « instruit avant A » n'est ni vraie ni fausse : elle est inconnue, ce qu'exprime le `NA` de Kleene de la spécification `donnees` v1.5 (M216).
2. Lire l'illisible comme absent serait une **correction silencieuse** (E2.4, E2.5) : pour un capital non fixé, P1 basculerait sur la structure familiale par défaut alors que la famille a été constatée à l'instruction ; pour un dossier double effet (B6), un sinistre instruit deviendrait un dossier potentiel (D13).
3. Mesure m1 : aujourd'hui, `parties$sinistres` vaut `FALSE` pour l'illisible comme pour l'absente ; la distinction n'existe pas dans le code.

**Règle (issue (3), part #51)** : dans `.visibilite_a()`, une partie dont la date est **illisible par sa forme** (refus de portée colonne, cause de forme) vaut `NA` dans `parties`, **dans les deux modes** (arrêté antérieur et arrêté égal à l'extraction) ; la date n'est pas convertie. À l'arrêté égal à l'extraction, la visibilité est totale (dictionnaire, § 6, règle 3) mais la valeur reste inconnue : la logique de Kleene le dit sans exception de mode. Une partie absente (champ vide) garde sa valeur actuelle (`FALSE` à A < extraction ; `TRUE` à l'extraction, le contenu « vide » étant connu).

**Règle (issue (3), part #54)** : `.valeurs_vue()` ne recalcule plus le masque ; pour une colonne de partie, à A < extraction, elle masque `!(vue$parties[[table]] %in% TRUE)` ; elle n'appelle jamais `as.numeric()` sur une date illisible. Le masque est inchangé ailleurs (concordance V13 existante : elle doit rester verte).

**Ce que #51 implique pour #54, et pour tout lecteur** : `.valeurs_vue()` rend `NA` pour une partie masquée, qu'elle soit inconnue ou absente : **son `NA` veut dire « hors de la vue », non « absente »**. Un lecteur qui a besoin de la distinction (B2 : `instruit`) lit `parties` (Kleene), jamais la valeur masquée seule. Construction de `instruit` dans `etats_a_date()` : `NA` si `parties` vaut `NA` ; sinon `parties & !is.na(date_instruction lue)` (à A < extraction, `parties` vrai implique une date lue ; à l'extraction, `parties` vrai et date vide donne `FALSE`).

**Conséquence pour les postes** : une partie à `NA` vient d'un refus (de forme : portée colonne ; de valeur : visibilité non déterminée de motif R). Dans les deux cas, P1 et P2, qui lisent `sinistres.date_instruction`, sont **arrêtés** (§ 6.2, règles (ii) et (iii)) ; P3 ne la lit pas. D'où un **invariant testé** : aucun dossier valorisé (ligne de `dossiers` à montant fini) n'a `instruit = NA`.

**Effet attendu sur le bilan** : aucun (aucun compte du bilan ne lit les parties ; m1 : refus de portée colonne inchangé). Tableau avant / après du bilan exigé par le critère (3.8).

## 5. Familles « engagement » et « risque en cours » du capital décès — issue (3)

### 5.1 Fonctions et graphe

| Module | Fonction | Rôle |
|---|---|---|
| `engagement` | `valeur_actuelle_probable(echeancier, actualisation, conventions)` | **la seule** fonction de valeur actuelle probable du package (ADR 0010, point 14 ; une méthode, une implémentation, ADR 0005, point 3) ; appelée par P1, P2 (engagement) et P3 (`risque_en_cours`) |
| `engagement` | `facteur_revalorisation(debut, fin, taux_par_annee, prorata, conventions)` | facteur de revalorisation légale, vectorisé ; **seule** implémentation, que reprendra `cout_moyen_capital` en B3 |
| `engagement` | `capital_deces_dossier(...)`, `.reconstituer_capital(...)` | capital dû ou reconstitué, solde, partition P1 / P2 |
| `engagement` | `calculer_engagement(vue, plan, tables, catalogue, garantie, poste)` | point d'appel d'un poste de la famille par l'orchestration ; rend `list(cellules, dossiers, echeanciers, indicateurs)` aux formes de l'ADR 0010, point 6 ; `switch(methode, ...)` à branches explicites |
| `risque_en_cours` | `calculer_risque_en_cours(vue, plan, tables, catalogue, garantie, poste)` | idem pour P3 ; appelle `engagement::valeur_actuelle_probable()` |
| `garanties` | `postes_a_arreter(catalogue, bilan, postes)` | règles d'arrêt du § 6.2 (données du bilan passées en argument : aucune arête `garanties` → `donnees`) |

Arêtes du graphe : celles de l'ADR 0010, point 1. **Annotation** : la colonne « Branche » de `risque_en_cours` passe de B6 à B2 (M118). `engagement` n'appelle jamais `risque_en_cours`.

### 5.2 `valeur_actuelle_probable()`

- **`echeancier`** : `data.frame` long, colonnes `cle` (identifiant du dossier ou du contrat), `date` (`Date`), `etat`, `type_flux` (`capital_unique`, `prime_periodique`, `frais`), `flux` (montant en euros, **signé** : engagement de l'organisme positif, prime de l'assuré négative), `probabilite` (dans [0 ; 1]). Aucune ligne de date ≤ arrêté (refus interne : erreur de programmation).
- **`actualisation`** : `list(type = "aucune")` (PSAP vie des comptes sociaux, valeur nominale) ou `list(type = "taux", taux = <double>, origine = <Date>)` ; en B6, `list(type = "courbe", table = <table_provie de nature taux>, origine = <Date>)` s'ajoute sans changer la signature.
- **Calcul** : facteur `v(date) = (1 + taux)^(−t)`, t = durée de `origine` à `date` selon `conventions$decompte_jours` ; `valeur_actuelle = flux × probabilite × v` ; rend l'échéancier complété des colonnes `actualisation` et `valeur_actuelle`, et la somme par `cle`. Sans actualisation, `v = 1`.
- **Statut** : exact (somme finie).

### 5.3 P1 — sinistres déclarés non réglés (`capital_dossier`, `capital_dossier_reglement`, comptes sociaux)

**Population** : lignes de `etats_a_date(vue, "deces")` ; dossiers non exclus pour la famille « engagement » (`vue$exclu$engagement`) ; `etat_dossier` ≠ `clos` ; **hors P2** (§ 5.4) ; solde > 0.

**Capital** :
- `capital_du` : `montant_en_vigueur` (exact) ;
- `ouvert` (sans fixation) : capital reconstitué = assiette × `taux_capital` + majorations, ou `capital_forfaitaire` si présent (paramètres de la version de garantie souscrite du dossier ; une version absente ou plusieurs versions en vigueur à la survenance relèvent de D10 (b), traité par `donnees`) ; assiette = `salaire_reference` de l'affiliation (`id_assure` du sinistre, `id_contrat` de la garantie) retenue dont [`date_debut` ; `date_fin`] contient la date de survenance ; si aucune, ou plusieurs, le poste est **arrêté** (motif `affiliation_non_determinee`, § 6.2) : D11 n'est implémenté qu'en Bdr (`CONTROLES_NON_IMPLEMENTES`), et aucune affiliation ne se choisit en silence ;
- majorations : si `instruit` vaut `TRUE`, famille retenue rattachée au sinistre : un conjoint (lien dans `liens_conjoint_majoration`, vivant à la survenance : `date_deces` manquante ou postérieure) ouvre `majoration_conjoint` ; chaque enfant vivant à la survenance d'âge (`conventions$age`) inférieur à `age_limite_enfant_majoration`, ou `situation` = `a_naitre` ou `handicape`, ouvre `majoration_enfant` (résultat exact) ; si `instruit` vaut `FALSE`, `structure_familiale` du plan : assiette × (`majoration_conjoint` × `taux_conjoint` + `majoration_enfant` × `nombre_enfants`) (espérance exacte sous l'hypothèse ; statut **jugement d'expert**) ; une majoration absente des paramètres vaut 0 (paramètre facultatif, dictionnaire § 5, sens de l'absence écrit) ;
- facteur d'issue : `ouvert` de sinistre `deces` : × (1 − `taux_sans_suite`) ; `ouvert` de sinistre `iad` : × `probabilite_reconnaissance_iad` ; `capital_du` : × 1.

**Solde revalorisé à l'arrêté** (même formule pour P2) :
`solde = capital × F(date_survenance, A) − Σ_j P_j × F(date_reglement_j, A)`,
F = `facteur_revalorisation()` (§ 5.4 ; dates en fin de journée), P_j = prestations `capital` retenues du dossier (paiements et régularisations, signées). Un solde ≤ 0 donne une provision nulle et le dossier n'entre pas dans `dossiers`.

**Frais** : flux `frais` = `taux_chargement_psap` × solde (Q10).

**Échéancier** (`capital_dossier`) : deux lignes par dossier, datées du lendemain de l'arrêté (A + 1, première date postérieure), `type_flux` `capital_unique` (solde) et `frais`, `probabilite` = facteur d'issue, `actualisation = list(type = "aucune")`. Provision du dossier = `valeur_actuelle_probable()`. **`capital_dossier_reglement`** (alternative, point prudent) : même population et même solde, revalorisation prolongée jusqu'au règlement attendu, A + `delai_reglement_jours` (§ 5.4).

**Statut du dossier** : `exact` si capital fixé et facteur d'issue égal à 1 ; `jugement_expert` si capital reconstitué sous `structure_familiale`, si un facteur d'issue < 1 s'applique, ou si une hypothèse `H` entre dans le montant (A4 du recensement). `hypotheses_defaut` : codes `D..` appliqués au dossier, joints par « ; ».

### 5.4 P2 — capitaux non réclamés ; revalorisation légale ; méthodes « règlement » (I1, tranché le 10/11/2026, avis Fable)

**Population de P2** : dossiers de la population de P1 avant partition qui remplissent le **critère** du plan : `beneficiaire_non_identifie` (au moins un bénéficiaire retenu du dossier de qualité `non_identifie`) ; `sans_evenement` (aucun événement retenu du dossier de date d'effet postérieure à A − `mois_sans_evenement` mois, `date_ouverture` comprise comme événement) ; réunion des critères déclarés. Les décès inconnus de l'organisme sont des tardifs (B3 ; Q4). Un dossier `clos` de motif `depot_cdc` est hors du poste (dépôt libératoire, L132-27-2, I, vérifié en 0a).

**Méthodes** (une seule fonction, `capital_deces_dossier(..., horizon)`, pour les quatre ; `switch` à branches explicites) :

| Méthode | Poste | `horizon` | Montant |
|---|---|---|---|
| `capital_dossier` | P1 | `arrete` | solde revalorisé à l'arrêté (§ 5.3), frais compris |
| `capital_revalorise` | P2 | `arrete` | idem |
| `capital_dossier_reglement` | P1 | `reglement` | solde revalorisé à l'arrêté × F(A, A + `delai_reglement_jours`) |
| `capital_revalorise_reglement` | P2 | `depot` | solde revalorisé à l'arrêté × F(A, H), H = date de connaissance (`sinistres.date_declaration`) + 10 ans (anniversaire ; un 29 février donne le 1er mars) pour un dossier à dépôt légal ; H = A + `duree_sans_depot_annees` ans (anniversaire) sinon (temporaire décès dont le décès est antérieur au 1er janvier 2015) ; si H ≤ A (dépôt dû et non saisi à l'arrêté), F = 1 et `detail` du dossier le dit (aucune correction) |

Dans les méthodes « règlement », F emploie `taux_par_annee` pour les années qu'il déclare (N+1 compris) et `taux_futur` au-delà de la dernière année déclarée ; non actualisé ; échéancier : flux `capital_unique` et `frais` datés de l'horizon (A + 1 pour `arrete`) ; frais = `taux_chargement_psap` × montant. **Statut** : exact sous les taux déclarés pour `arrete` ; **jugement d'expert** (date de règlement, taux futur) pour `reglement` et `depot`.

**`facteur_revalorisation(debut, fin, taux_par_annee, prorata, conventions, taux_futur = <déclaré ou absent>)`** : produit, sur les années civiles y qui coupent l'intervalle (début, fin] (dates en fin de journée), de 1 + r_y · j_y / J_y (`simple`) ou (1 + r_y)^(j_y / J_y) (`compose`), avec j_y = min(fin ; 31/12/y) − max(début ; 31/12/(y − 1)) jours et J_y du § 2.5 ; r_y = `taux_par_annee[y]`, ou `taux_futur` pour une année postérieure à la dernière année déclarée et postérieure à l'arrêté ; une année antérieure ou égale à l'année de l'arrêté absente de `taux_par_annee` est un refus `plan_incomplet`. P1 et P2 l'appellent avec `fin` = A pour le solde. Statut : exact sous les taux déclarés. Seule implémentation (reprise par `cout_moyen_capital` en B3).

**Plan mixte** : un plan qui déclare une méthode `arrete` sur l'un de P1 et P2 et une méthode « règlement » sur l'autre est **admis, avec signalement** : une ligne d'`indicateurs` `regle = "methode_revalorisation_mixte"`, `poste = "ensemble"`, `garantie = "deces"`, `valeur_regle = NA`, `valeur_retenue = NA`, `depassement = TRUE`, `detail = "sinistres_declares_non_regles=<méthode>;capitaux_non_reclames=<méthode>"` (forme : annotation, § 9).

**Indicateurs** : pour chaque année civile de `taux_par_annee` employée (N+1 et suivantes comprises), une ligne `R132_3_1` (§ 3.5).

**Recoupement exact** (critère 3.13) : `capital_revalorise_reglement` en `prorata = "compose"`, sans année de `taux_par_annee` postérieure à l'arrêté, actualisée de A à H au taux `taux_futur` par `valeur_actuelle_probable()` (même découpage des durées), redonne `capital_revalorise` en `compose` (cas R7 du § 7.4 : écart nul à la précision machine).

**Statut et effet** : § 1.1. Fiche de méthode : « non actualisé » est une convention du plan de comptes, non une règle d'un texte pour la vie ; le choix entre `arrete` et `reglement` est un jugement d'expert déclaré dans le plan.

### 5.5 P3 — provision mathématique de la temporaire décès (famille « risque en cours », M118)

**Champ (a), contrats individuels** : garanties souscrites `deces` retenues de contrats `individuel`, de version en vigueur à l'arrêté ; couverture en cours à l'arrêté : date d'effet du contrat ≤ A, fin de couverture > A, fin de couverture = min(`contrats.date_terme`, `date_atteinte_age(date_naissance, age_fin_garantie, conventions$age)`, `contrats.date_fin` si la partie de fin est connue à l'arrêté) ; aucun sinistre `deces` ou `iad` retenu de l'assuré survenu au plus l'arrêté (sinon le contrat relève de P1). Capital : `capital_forfaitaire` (dictionnaire, § 5 : contrat individuel).

**Échéancier** (`pas` = `an` : années d'assurance, anniversaires de la date d'effet ; `mois` : mois d'assurance) : bornes t_0 = A, puis chaque date de pas postérieure à A, et la fin de couverture ; âge de l'année d'assurance k = âge à la date d'effet (`conventions$age`) + k, sans recalcul depuis la date de naissance ; quand A n'est pas une date de pas, la fraction écoulée s = durée(date de pas précédente, A) / durée(date de pas précédente, date de pas suivante) (`conventions$decompte_jours`) et la probabilité de décès entre A et la date de pas suivante = 1 − p(1) / p(s) sous `conventions$repartition_annee` ; probabilités de survie et de décès par la table `mortalite_tarif`, âge à la date d'effet par `conventions$age` puis âge + k aux anniversaires, fractions d'âge par `conventions$repartition_annee` ; flux `capital_unique` au terme du pas (`fin_pas`) ou en son milieu (`milieu_pas` : début + partie entière de la moitié des jours) pondéré par la probabilité de décès dans le pas ; flux `prime_periodique` (négatif) à chaque échéance de prime postérieure à l'arrêté (échéances : date d'effet + k périodes de `periodicite_cotisation` ; une échéance datée de A est passée) pondéré par la survie à l'échéance ; prime unique : aucun flux de prime ; flux `frais` (prime unique) = `taux_chargement_gestion` × capital à chaque anniversaire postérieur à l'arrêté et antérieur à la fin de couverture, pondéré par la survie.

**`prospective_prime_pure`** (recommandée, individuels) : prime pure recalculée **par équivalence à la date d'effet**, avec la table `mortalite_tarif` et le **taux du tarif** du contrat (`taux_technique_tarif`, hypothèse D03h appliquée s'il manque) : P = A_effet / ä_effet (A : valeur actuelle des capitaux, ä : des échéances de prime unitaires, toutes deux à l'effet) ; zillmérisation (primes périodiques) : P_z = P + `taux_chargement_acquisition` × capital / ä_effet ; provision = VAP(capitaux + frais) − VAP(primes P_z), actualisée au **taux retenu** (`taux$…` : valeur déclarée ou `taux_tarif`) ; **plancher nul par contrat** (A343-1-1, 2e alinéa ; « par contrat », interprétation forte retenue au recensement).

**`prospective_prime_declaree`** (alternative) : même calcul, prime = `prime_periodique` × (1 − `taux_chargement_cotisation`).

**`retrospective`** (témoin, non option) : valeur accumulée des primes passées (échéances ≤ A, prime de l'échéance A comprise) moins le coût du risque, aux mêmes bases ; égale à la prospective sous les mêmes bases (Norberg 1991, recensement § 12) : **recoupement exact** testé (cas R2, § 7.4), jamais restitué dans `provisions`.

**Champ (b), contrats collectifs (`prorata_cotisation`)** : garanties `deces` de contrats collectifs ; provision = Σ, sur les cotisations retenues de nature `emission`, `annulation`, `regularisation` (signées) dont `fin_periode` > A, de `montant` × (1 − `taux_chargement_cotisation`) × (`fin_periode` − A) / (`fin_periode` − `debut_periode` + 1) (Q3 ; dictionnaire § 1.4). **Statut** : approximation au sens du recensement (égalité si le risque est uniforme sur la période et la prime pure), restitué `approximation_numerique` faute d'un statut plus juste dans la liste fermée (point noté pour `architect`, § 9).

**Indicateurs** : `tarif_vie` et `A132_1` (§ 3.5) pour chaque contrat individuel valorisé par une méthode prospective ; pour `A132_1`, `nature_primes` = `"unique"` si `periodicite_cotisation` vaut `unique`, `"periodique"` sinon, et `duree_au_plus_8_ans` = (`contrats.date_terme` ≤ huitième anniversaire de `contrats.date_effet`) ; `date_terme` absente : ligne `NA` (`terme_absent`), sans hypothèse par défaut (I2, I3, tranchés le 10/11/2026, avis Fable).

**Restitution** : P3 n'a pas de dossier ; il n'écrit pas dans `dossiers` ; ses échéanciers portent `cle` = `id_contrat` (annotation, § 9) ; il se restitue par segment (segmentation `contrat` comprise ; pour une segmentation `annee_survenance`, segment `hors_survenance`).

### 5.6 Hypothèses par défaut lues en B2

| Motif | Poste | Effet |
|---|---|---|
| D03h (`H`, taux du tarif manquant, M86) | P3 individuel | taux du tarif = valeur déclarée (la documentation propose 0 %) pour la prime pure, le contrôle `tarif_vie` et `taux_tarif` ; `hypotheses_defaut` du contrat et décompte dans `fiche$parametres_retenus$hypotheses_defaut` |
| D02b, D03g (`H`) | tous | vue seulement (`donnees`) |
| D01b, D02a, D04b, D10 (b) … (`X`) | selon la famille déclarée | lignes exclues de la famille avec cascade (`vue$exclu`) ; enjeu par poste en (4) |

Toute autre hypothèse déclarée dans `plan$donnees$hypotheses` pour un motif qu'aucun poste de B2 ne lit est sans effet sur les montants et reste au bilan.

### 5.7 Meilleure estimation : ce que B2 porte, ce qui attend B6

**Porté par B2** (sans calcul de meilleure estimation) : la colonne `referentiel` partout ; `valeur_actuelle_probable()` accepte une actualisation par courbe sans changer de signature ; les échéanciers sont datés à la date de paiement attendue ; `postes.csv` porte `meilleure_estimation` (`TRUE` pour P1 et P2, `FALSE` pour P3) ; `facteur_revalorisation()` sert aussi la revalorisation à courir.

**Attend B6** : `solvabilite_2` au périmètre ; courbe EIOPA (import) ; taux de sans-suite et de reconnaissance centraux ; loi de réclamation et dépôt (P2) ; frais de l'art. 31 ; limites du contrat (dont I6) en remplacement de P3 ; tableau de passage.

## 6. Arrêts de poste, total arrêté, `conventions$limite_age`

### 6.1 Total arrêté (règle visée : spécification `donnees`, § 6, point 1)

La cellule `poste = "total"`, `niveau = "agregat"` d'une garantie × référentiel × segmentation × segment dont **un** poste est arrêté est arrêtée : `montant = NA`, `statut_calcul = "arrete"`, `motif_arret = "poste_arrete:<poste>;<poste>"` (postes arrêtés de la garantie, triés). Elle n'est **jamais** la somme des postes calculés. Les cellules des postes calculés restent restituées. Décision de forme de la chaîne de `motif_arret` (pas de colonne nouvelle) : annotation, § 9.

### 6.2 Arrêt de poste (M239 ; ADR 0010, point 11 (b))

`garanties::postes_a_arreter(catalogue, bilan, postes)` applique, pour chaque poste du plan, dans cet ordre, à partir de `lectures.csv` et des descendances du dictionnaire (clés étrangères de `colonnes.csv`) :

| Règle | Source du bilan | Postes arrêtés | `motif_arret` |
|---|---|---|---|
| (i) | ligne de `refus_tables` de portée `table` (refus induit compris) sur la table T | postes qui lisent une colonne de T | `motif` de la ligne |
| (ii) | ligne de `refus_tables` de portée `colonne` sur (T, c) | postes qui lisent (T, c) | `motif` de la ligne |
| (iii) (M204, M239) | ligne de `vue$visibilite_non_determinee` dont le `motif` est un motif de refus (`manquant_obligatoire`, `hors_domaine`, `chaine_vide`, `D02c`, ou tout motif `R`) sur la table T | postes qui lisent T **ou une descendante de T** | `motif` de la ligne |

La ligne de `refus_tables` qui porte `postes_arretes` est, pour (i) et (ii), la ligne elle-même ; pour (iii), la ligne de `refus_tables` de même `table`, de `colonne` égale à celle de l'`origine` et de même `motif` (son existence est un invariant de la spécification `donnees`, § 3.2). **Aucune colonne nouvelle** (M239). `postes_arretes` = `<garantie>/<poste>` joints par « ; », triés ; `NA` si la ligne n'arrête aucun poste du périmètre (elle reste au bilan, ADR 0010, point 11 (b)). Plusieurs règles sur un poste : `motif_arret` = motif de la première ligne dans l'ordre du bilan (`refus_tables`, puis `vue$visibilite_non_determinee`). Une cellule arrêtée : `montant = NA`, `statut_calcul = "arrete"`, `nombre_dossiers = NA`.

Deux motifs d'arrêt naissent dans une famille, hors du bilan : `hors_axes` (table lue hors de ses axes sous `hors_axes = "refus"`, § 3.3) et `affiliation_non_determinee` (§ 5.3). Ils n'ont pas de ligne de `refus_tables` ; la cellule porte le motif, et `fiche$parametres_retenus$postes` le premier identifiant en cause dans `parametres` (annotation, § 9).

Ce qui n'arrête rien : une ligne `D02b` ou `D03g` de visibilité non déterminée (elle exige une déclaration : sans elle, refus `declaration_manquante` en (4), spécification `donnees`, § 6, point 2) ; `parente_non_determinee` (la parente porte la règle (iii), sa descendance couvre la fille) ; une table facultative absente.

**Conséquence mesurée sur les jeux** (m6) : `v1-modeste-02` porte un refus D09 de portée colonne sur `prestations.montant` (une indemnité journalière) ; P1 et P2 lisent `prestations.montant` : ils sont **arrêtés** aux deux arrêtés, et le total `deces` aussi. C'est l'application de la règle visée (dictionnaire, § 1.10 : portée colonne d'un refus sur une colonne ordinaire), non une décision nouvelle ; voir le point d'attention A3 (§ 10.2).

### 6.3 `conventions$limite_age` conditionnée (dixième série, (d))

Deux niveaux, chacun « seulement si cela peut changer le résultat » (principe de M187) :
1. **`controler_base()`** (`.regle_v_limite_age()`) : la convention n'est exigée (lignes `declarations_requises` `limite_age$regle` et `limite_age$age`, et lignes `declaration_absente` de D07 dans `controles_non_executes`) que s'il existe **au moins une ligne candidate** de D07 (c) dans la vue (retenue ou de visibilité non déterminée) : une rente dont le dossier relève d'une garantie souscrite `rente_education`, ou un dossier `double_effet`. Si le code de garantie d'une ligne n'est pas lisible (refus de la jointure), la ligne compte comme candidate (sens prudent : la déclaration est demandée). Sans ligne candidate : D07 (c) est exécuté à vide, sans exigence.
2. **`valider_plan()`** : exigée si une garantie du périmètre a un lecteur de `limite_age` (B4 : `rente_education` ; B6 : `double_effet`) ; jamais en B2.

**Motif du niveau 1** : le bilan fait partie du résultat ; une déclaration qui ne peut changer aucune ligne du bilan ni aucune provision ne doit pas bloquer le calcul (règle 2 du § 6 de la spécification `donnees` : refus `declaration_manquante`). Mesure m3 : sur les deux jeux, aux deux arrêtés, l'exigence actuelle naît sans ligne candidate.

**Effet attendu** : bilan inchangé sur les jeux versionnés (ils déclarent la convention, `declarations.txt`) ; sur les bases des tests sans ligne candidate et sans la convention, deux lignes de `declarations_requises` et les lignes D07 `declaration_absente` disparaissent. **Commit `moteur:` distinct, en tête de (3)** (règle du § 1.6 de la feuille de route), avec son tableau avant / après et le visa d'`actuary` (aucune provision).

## 7. Critères d'acceptation et cas à valeurs en dur

### 7.1 Issue (1) — `plan` et catalogue

1. (1.1) `catalogue_garanties()` lit les huit CSV du § 4.1, valide listes fermées et codes du dictionnaire ; refus `catalogue_invalide` sur un témoin (code de garantie inconnu ; type de flux hors liste ; méthode d'un champ inconnu ; `lectures.csv` qui cite une colonne absente du dictionnaire).
2. (1.2) Plan minimal valide de B2 (§ 7.5) : `valider_plan()` le rend sans erreur, classe `plan_calcul`.
3. (1.3) `plan_incomplet` : un témoin par entrée exigée du § 2.3 et du § 2.6 (dont `conventions$decompte_jours`, `revalorisation$capital_deces$prorata`, `tables$serie_tme`, `tables$mortalite_tarif` avec une méthode prospective, `revalorisation$capital_deces$taux_futur` avec chaque méthode « règlement », `duree_sans_depot_annees` avec `capital_revalorise_reglement`, `delai_reglement_jours` avec `capital_dossier_reglement`), le message nomme le chemin.
4. (1.4) `plan_invalide` : `solvabilite_2` au périmètre ; méthode témoin (`retrospective`) déclarée ; doublon dans `perimetre$garanties` ; entrée inconnue ; `instant_date = "debut_journee"` ; `triangles = "tous"` ; `double` non entier pour `graine` ; `taux` hors bornes.
5. (1.5) Canonisation : deux plans de même sens (sections et clés libres permutées, `graine = 7` contre `7L`) donnent des octets `ecrire_plan()` identiques.
6. (1.6) Aller-retour : `identical(lire_plan(ecrire_plan(p)), canoniser_plan(valider_plan(p)))` et `identical(ecrire_plan(lire_plan(o)), o)` ; même règle pour la fiche (`construire_fiche()` sur la base de référence des tests).
7. (1.7) `VERSION_FICHE` = 1 dans la fiche ; contrôles du rejeu : version de fiche différente → `version_discordante` ; empreinte d'une table de la base modifiée → `empreinte_discordante`, première dans l'ordre du dictionnaire.
8. (1.8) Sous-schéma `donnees` inchangé : les `declarations.txt` des deux jeux, placés dans `plan$donnees` et `plan$conventions` (avec les entrées nouvelles de B2), passent `valider_plan()` ; `controler_base()` rend le même bilan qu'avec les arguments simples (`identical`).
9. (1.9) Exports du § 2.9, un `export()` par ligne, motivés dans le commit ; aucune arête hors de l'ADR 0010, point 1 (`graphe_modules.R` vert).

**Résultats** : aucun.

### 7.2 Issue (2) — `tables`

1. (2.1) `formats_tables()` rend les deux formats du § 3.2 ; `lire_table()` d'un CSV de la table fictive rend un `table_provie` dont `probabilite(t, age = 40:42)` vaut q = 0,01 ; 0,02 ; 0,03 à 1e-15 près ; âge 43 hors axes : `refus` → `NA` signalé, `derniere_valeur` → 0,03.
2. (2.2) Même table lue d'un fichier et construite en mémoire : même `origine$empreinte` ; un octet changé dans une valeur change l'empreinte, un espace ajouté dans le fichier ne la change pas.
3. (2.3) Refus : `format_table_inconnu` (format hors liste ; âges non consécutifs ; l_x croissant ; mois en double) ; `type_incompatible` (colonne `lx` en texte) ; `table_absente` (usage exigé sans table) ; `empreinte_discordante` ; `plan_invalide` (statut déclaré ≠ statut de la table ; nature ≠ celle de l'usage).
4. (2.4) Indicateurs sur `tme_fictive_b2` : cas X1 à X8 du § 7.4 (dont une seule ligne `A132_1` par contrat, `depassement` à trois valeurs, `terme_absent`, `delai_3_mois_non_pris_en_compte` dans `detail`) ; recoupement de `minimum_r132_3_1()` par `stats::filter()` à 1e-15 près ; cas négatif (I4) : série constante à −0,10 % → −0,001, sans plancher.
5. (2.5) Aucun fichier sous `inst/extdata/tables/` ni `inst/extdata/taux/` ; `charger_table()` absent du `NAMESPACE`.

**Résultats** : aucun.

### 7.3 Issue (3) — engagement, risque en cours, `etats_a_date()`, #51, #54

1. (3.1) Commit `moteur:` de tête (§ 6.3) : `limite_age` conditionnée ; tableau avant / après du bilan sur les bases des tests et les deux jeux aux deux arrêtés ; jeux inchangés.
2. (3.2) `vue_a_date()$bilan` **identique** à `controler_base()` sur toutes les bases des tests et les deux jeux aux deux arrêtés (`identical`).
3. (3.3) #51 : base m1 à A0 → `parties$sinistres` = `NA FALSE` ; à l'extraction → `NA TRUE` ; témoin (base de référence) inchangé `TRUE FALSE` ; **test qui verrouille la partie illisible**.
4. (3.4) #54 : `.valeurs_vue(ctx, "sinistres", "date_instruction")` sur la base m1 ne produit aucun avertissement sous `options(warn = 2)` ; V13 (concordance) reste vert.
5. (3.5) `etats_a_date()` : sur des bases construites, les quatre transitions de l'automate (fixation, clôture, réouverture vers `capital_du`, réouverture vers `ouvert`), `instruit` à trois valeurs, `motif_cloture = "depot_cdc"` ; sur les jeux, quatre lignes `deces`, toutes `clos` à 2024-12-31 et 2025-12-31 (m4).
6. (3.6) Cas R1 à R7 et T1 à T7 du § 7.4, valeurs en dur, tolérance relative 1e-10.
7. (3.7) **Une seule** définition de `valeur_actuelle_probable()` et de `facteur_revalorisation()` dans `R/` (test par recherche des définitions dans les sources) ; P1, P2 et P3 n'actualisent et ne revalorisent que par elles (revue d'`audit` sur le diff ; aucun test de motif fragile).
8. (3.8) `postes_a_arreter()` : règles (i) à (iii) sur des bases construites ; (iii) sur une base où `dossiers.date_ouverture` manque à A0 (cas du critère 1 de #33 dans `tests/unitaires/donnees.R`) : P1 et P2 arrêtés de motif `manquant_obligatoire`, `postes_arretes` sur la ligne `dossiers date_ouverture manquant_obligatoire` ; P3 non arrêté ; sur `v1-modeste-02` : P1 et P2 arrêtés de motif `D09`.
9. (3.9) Invariant : aucun dossier valorisé n'a `instruit = NA`.
10. (3.10) **Bilan existant inchangé** hors du commit (3.1) (tableau avant / après sur les bases des tests et les deux jeux, aux deux arrêtés).
11. (3.11) Contre-vérification `lifecontingencies` (§ 7.6) : valeurs en dur de T1 et des valeurs actuelles A_effet et ä_effet, avec la version de R et du package consignées ; script hors CI.
12. (3.12) Plan mixte (`capital_dossier` sur P1, `capital_revalorise_reglement` sur P2, et l'inverse) : calcul effectué, une ligne `methode_revalorisation_mixte` dans `indicateurs` (§ 5.4) ; plan homogène : aucune ligne.
13. (3.13) Recoupement exact (I1) : cas R7, écart inférieur à 1e-9 en valeur absolue.
14. (3.14) Refus `plan_incomplet` : `capital_dossier_reglement` sans `delai_reglement_jours` ; méthode « règlement » sans `taux_futur` ; `capital_revalorise_reglement` sans `duree_sans_depot_annees` ; année antérieure ou égale à celle de l'arrêté absente de `taux_par_annee`.

**Résultats** : provisions nouvelles (pas d'« avant ») ; aucun total sous visa avant (4).

### 7.4 Cas à valeurs en dur (mesure m7)

Table fictive du § 3.6 ; série fictive du § 3.6 ; `decompte_jours = exact_exact` sauf mention ; `instant_date = fin_journee`.

**Indicateurs** (`decalage_publication_mois` entre parenthèses) :

| Cas | Calcul | Valeur |
|---|---|---|
| X1 | `R132_3_1`, année 2026 (1) | 0,024 |
| X2 | `R132_3_1`, année 2026 (2) | 0,03 (à 1e-15) |
| X3 | `R132_3_1`, année 2025 (1) | 0,030166666666666665 |
| X4 | `R132_3_1`, année 2024 (1) : fenêtre incomplète | `NA`, `serie_incomplete` |
| X5 | `A132_1` au 2024-01-01 (1), taux du tarif 0,02 : prime unique ≤ 8 ans ; primes périodiques | référence 0,0225, bornes ]0,019 ; 0,0235[, `depassement = NA` ; référence 0,018, bornes ]0,0145 ; 0,019[, `depassement = TRUE` |
| X6 | `A132_1` au 2025-01-01 (1), taux du tarif 0,02 : prime unique ≤ 8 ans ; prime unique, terme au 2032-01-02 (> 8 ans) ; primes périodiques | 0,02275, `NA` ; 0,0182, `TRUE` ; 0,0182, `TRUE` |
| X7 | `A132_1` au 2024-01-01 (1), primes périodiques, taux du tarif 0,01 ; idem, terme au 2032-01-01 (huit ans inclus) en prime unique | 0,018, `FALSE` (0,01 ≤ 0,0145) ; 0,0225 (branche à 75 %) |
| X8 | `A132_1`, `date_terme` absente | `valeur_regle = NA`, `depassement = NA`, `terme_absent` |


**P1, P2** (dates en fin de journée : 183 jours de 2024 sur 366, 365 jours de 2025) : capital 100 000 €, décès le 2024-07-01, connu le 2024-09-01, arrêté 2025-12-31, `taux_par_annee` = 2024 : 0,03 ; 2025 : 0,024 ; `taux_chargement_psap` = 0 sauf mention.

| Cas | Données | Valeur |
|---|---|---|
| R1 | capital fixé, `capital_dossier`, `prorata = simple` | facteur 1,03936 (= 1,015 × 1,024) ; provision 103 936,0000000000 |
| R2 | idem, `prorata = compose` | 103 924,6496265443 |
| R3 | R1 avec un paiement partiel de 40 000 € le 2025-03-01 (305 jours de revalorisation) | 63 133,8082191781 |
| R4 | R1 en P2, `capital_revalorise_reglement`, `taux_futur` = 0,024, H = 2034-09-01 | 127 666,8365965362 (écart à R1 : 23 730,8365965363) |
| R4b | R4 avec `taux_par_annee["2026"]` = 0,03 (N+1 déclarée) | 128 414,8844672191 |
| R6 | R1 en `capital_dossier_reglement`, `delai_reglement_jours` = 30, `taux_par_annee["2026"]` = 0,024 | 104 141,0244383562 |
| R7 | recoupement : R2 en `capital_revalorise_reglement` (`compose`, sans année postérieure à 2025, `taux_futur` 0,024) = 127 644,9602960881, actualisée sur 8,668493150684931 ans à 2,4 % | 103 924,6496265443 = R2 (écart nul) |
| R5 | capital non fixé : salaire 30 000 €, `taux_capital` 2, `majoration_conjoint` 0,5, `majoration_enfant` 0,25, `age_limite_enfant_majoration` 26, `taux_chargement_psap` 0,01 ; (a) instruit, conjoint vivant et deux enfants de 10 et 27 ans ; (b) non instruit, `structure_familiale` (0,6 ; 1,2) | (a) capital 82 500 €, provision avant revalorisation 83 325 € ; (b) 78 000 €, 78 780 € (statut `jugement_expert`) ; la provision finale applique le facteur de R1 |

**P3** : contrat individuel, effet 2024-01-01, terme 2027-01-01, assuré né le 1984-01-01 (âge révolu 40 à l'effet), `age_fin_garantie` 70, `capital_forfaitaire` 100 000 €, `taux_technique_tarif` 0,02, taux retenu 0,02, `pas = an`, `paiement_capital = fin_pas`, arrêté 2025-01-01 (un anniversaire).

| Cas | Données | Valeur |
|---|---|---|
| T1 | prime unique, `taux_chargement_gestion` 0 | 4 786,6205305652 |
| T2 | T1 avec `taux_chargement_gestion` 0,001 | 4 882,6989619377 |
| T3 | primes annuelles, `prospective_prime_pure`, `taux_chargement_acquisition` 0,01 | prime pure 1 937,9980836196 ; A_effet 5 626,2297306466 ; ä_effet 2,9031141869 ; P_z 2 282,4557713431 ; provision 2 593,6728286865 |
| T4 | T3 avec `taux_chargement_acquisition` 0 ; recoupement `retrospective` | 2 924,6223717934 ; rétrospective avant la prime de l'échéance A : 986,6242881738, plus la prime 1 937,9980836196 = 2 924,6223717934 |
| T5 | `prospective_prime_declaree`, `prime_periodique` 2 300 €, `taux_chargement_cotisation` 0,05 | 2 687,3068050750 |
| T6 | T3 avec `taux_chargement_acquisition` 0,03, arrêté 2024-01-01 (date d'effet ; prime de l'effet passée) | valeur avant plancher −28,6288532099 ; provision **0** (plancher par contrat) |
| T7 | `prorata_cotisation` : émission 1 200 € du 2025-07-01 au 2026-06-30, `taux_chargement_cotisation` 0,10, arrêté 2025-12-31 | 535,5616438356 (181 jours sur 365) |

### 7.5 Plan minimal de B2 (forme des tests)

```r
plan <- list(
  version_plan = 1L, arrete = as.Date("2025-12-31"),
  perimetre = list(garanties = "deces", referentiels = "comptes_sociaux", segmentations = list()),
  tables = list(
    mortalite_tarif = list(identifiant = "mortalite_fictive_b2", empreinte = "<md5>", statut = "fictive", hors_axes = "refus"),
    serie_tme = list(identifiant = "tme_fictive_b2", empreinte = "<md5>", statut = "fictive", hors_axes = "refus",
                     decalage_publication_mois = 1L)),
  taux = list(deces = list(provision_mathematique_temporaire_deces = list(comptes_sociaux = 0.02))),
  frais = list(deces = list(
    sinistres_declares_non_regles = list(comptes_sociaux = list(taux_chargement_psap = 0)),
    capitaux_non_reclames = list(comptes_sociaux = list(taux_chargement_psap = 0)),
    provision_mathematique_temporaire_deces = list(comptes_sociaux = list(
      taux_chargement_gestion = 0, taux_chargement_acquisition = 0, taux_chargement_cotisation = 0)))),
  revalorisation = list(capital_deces = list(taux_par_annee = c(`2024` = 0.03, `2025` = 0.024), prorata = "simple")),
  conventions = list(age = "revolu", instant_date = "fin_journee", repartition_annee = "uniforme",
                     fractionnement = "echeances_exactes", decompte_jours = "exact_exact"),
  postes = list(deces = list(
    sinistres_declares_non_regles = list(methode = "capital_dossier", parametres = list(
      taux_sans_suite = 0, probabilite_reconnaissance_iad = 1,
      structure_familiale = list(taux_conjoint = 1, nombre_enfants = 2),
      age_limite_enfant_majoration = 26L, liens_conjoint_majoration = c("conjoint", "partenaire_pacs", "concubin"))),
    capitaux_non_reclames = list(methode = "capital_revalorise", parametres = list(
      critere = "beneficiaire_non_identifie", taux_sans_suite = 0, probabilite_reconnaissance_iad = 1,
      structure_familiale = list(taux_conjoint = 1, nombre_enfants = 2),
      age_limite_enfant_majoration = 26L, liens_conjoint_majoration = c("conjoint", "partenaire_pacs", "concubin"))),
    provision_mathematique_temporaire_deces = list(
      individuel = list(methode = "prospective_prime_pure", parametres = list(pas = "an", paiement_capital = "fin_pas", plancher = "par_contrat")),
      collectif = list(methode = "prorata_cotisation", parametres = list()))))),
  donnees = list(), restitution = list(echeanciers = "aucun", triangles = "aucun"), liens = list(), graine = 1L)
```
Les valeurs familiales ci-dessus sont des valeurs de test, non des valeurs proposées.

### 7.6 Contre-vérification hors CI (`lifecontingencies`)

Script `tests/contre_verification/b2_lifecontingencies.R`, hors CI, lancé sur ordre du mainteneur, qui consigne `R.version.string` et `packageVersion("lifecontingencies")` (1.6.3 lue au recensement, § 7 ; **non installé** dans le conteneur de cette consultation, m7) : table `new("lifetable", x = 40:43, lx = c(100000, 99000, 97020, 94109.4))`, `actuarialtable` au taux 0,02 ; `Axn(…, x = 41, n = 2) × 100 000` contre T1 ; `Axn(…, x = 40, n = 3) × 100 000` contre A_effet ; `axn(…, x = 40, n = 3)` (paiement d'avance) contre ä_effet. Les valeurs qu'il imprime sont écrites en dur dans `tests/unitaires/engagement.R` avec la version et la date ; d'ici là, les valeurs du § 7.4 sont des **recoupements** par un calcul indépendant en R de base (m7), non des contre-vérifications.

### 7.7 Cadrage de l'issue (4)

- Signature à quatre arguments (ADR 0010, point 5) ; ordre des étapes dans `ETAPES` : validation du plan → `resoudre_tables()` → `vue_a_date()` → refus `declaration_manquante` si `declarations_requises` non vide → `postes_a_arreter()` → P1 et P2 (`engagement`) → P3 (`risque_en_cours`) → agrégats et totaux (§ 6.1) → enjeu par poste (spécification `donnees`, § 4.5, point 3, par `lectures.csv`) → fiche → empreinte du résultat. **Ordre entre familles** (ADR 0010, point 4, fixé par `actuary`) : aucun lien croisé en B2 ; `engagement` avant `risque_en_cours`.
- Invariants du point 7 (a) à (f) testés ; `non_declaree` jamais dans le résultat ; `declarations_requises` vide.
- Restitution garantie × référentiel × poste × segmentation × segment, et par dossier (P1, P2) ; `statut_resultat` d'une cellule = le plus faible de ses dossiers ou contrats (`jugement_expert` > `approximation_numerique` > `exact`).
- Refus d'appel et arrêt de poste distingués (scénarios adverses de la fiche de B2).
- **Visa du mainteneur sur les premiers totaux** : sur les jeux versionnés, le total `deces` vaut **0 €** dans `v1-modeste-01` aux deux arrêtés (m4, m5) et est **arrêté** dans `v1-modeste-02` (m6). Voir A1 (§ 10.2).
- Références selon l'ADR 0011 (0c), par la session, sur la CI seule, après visa.

## 8. Corps proposés des issues (1) à (4)

Libellés : `ready-for-agent` (décision du mainteneur du 10 novembre 2026). Chaque corps renvoie à la présente spécification (`docs/specifications/b2-capital-deces-v1.md`, version `1.0`).

### 8.1 Issue (1)

**Titre** : `plan : schéma du plan de la v1, canonisation, fiche de calcul et catalogue des garanties (B2, issue 1)`

**Corps** :
> *Rédigé par l'agent actuary (IA).*
>
> **Objet.** Module `plan` (`valider_plan()`, `canoniser_plan()`, `ecrire_plan()`, `lire_plan()`, fiche de calcul, contrôles du rejeu) et module `garanties` avec le catalogue de B2 (`catalogue_garanties()`, huit CSV dont `lectures.csv`), selon la spécification de B2, § 2 et § 4.1.
>
> **Comportement attendu.** Schéma de la v1 au contenu fixé en B2 (§ 2.2 à § 2.7), sans valeur par défaut (règle d'exigence, § 2.3) ; canonisation et sérialisation par `ecrire_liste()`, aller-retour octet pour octet (§ 2.8) ; `VERSION_FICHE` 1 ; sous-schéma `donnees` inchangé (ADR 0010, point 17).
>
> **Critères d'acceptation** : spécification de B2, § 7.1, critères (1.1) à (1.9).
>
> **Hors périmètre.** `rejouer_fiche()` exporté (issue 4) ; empreintes du résultat et du code (issue 4) ; toute méthode de calcul.
>
> **Agents.** `coder-approfondi` (circuit 1), `audit` léger, `actuary` valide. Dépend de #27.
>
> **Résultats** : aucun (aucune provision calculée).

### 8.2 Issue (2)

**Titre** : `tables : formats lx_age et série TME, table_provie, tables par usage, indicateurs R132_3_1 et A132_1, sans table embarquée (B2, issue 2)`

**Corps** :
> *Rédigé par l'agent actuary (IA).*
>
> **Objet.** Module `tables` et `lire_table()` (module `lecture`), selon la spécification de B2, § 3 : formats admis (§ 3.2), représentation `table_provie` (§ 3.3), résolution des tables par usage avec contrôle d'empreinte (§ 3.4), indicateurs `R132_3_1`, `A132_1` et contrôle `tarif_vie` (§ 3.5).
>
> **Décision du mainteneur du 10 novembre 2026** : aucune table réglementaire embarquée en B2 ; tests sur une table de mortalité fictive et une série TME fictive déclarées (§ 3.6). `charger_table()` n'est pas exporté en B2.
>
> **I2 et I3, tranchés le 10/11/2026 (avis Fable), validation a posteriori du mainteneur** : une seule ligne `A132_1` par contrat, sans tranche (lecture (i)) ; primes périodiques pour un collectif reconduit (lecture (b), sans effet en B2) ; `depassement` à trois valeurs selon l'échelle d'A132-1-1 établie par `regulatory`, délai de trois mois non pris en compte (§ 3.5).
>
> **Critères d'acceptation** : spécification de B2, § 7.2, critères (2.1) à (2.5) ; cas X1 à X8 du § 7.4.
>
> **Hors périmètre.** Format d'`outil_tables` (issue séparée) ; courbes EIOPA (B6) ; formats ANC 600-2 à 600-4 (B5) ; transcription d'une table homologuée (issue séparée).
>
> **Agents.** `coder-approfondi` (circuit 1), `audit` léger, `regulatory` contrôle la conformité (R132-3-1, A132-1), `actuary` valide. Annotation d'ADR : arête `lecture` → `tables`, statut `fictive`, empreinte du contenu (§ 9).
>
> **Résultats** : aucun.

### 8.3 Issue (3)

**Titre** : `engagement et risque_en_cours : capital décès en comptes sociaux (P1, P2, P3), etats_a_date(), parties de ligne illisibles (#51, #54), arrêt de poste (B2, issue 3)`

**Corps** :
> *Rédigé par l'agent actuary (IA).*
>
> **Objet.** Selon la spécification de B2, § 4.2 à § 6 : `vue_a_date()` et `etats_a_date()` (module `donnees`) ; famille « engagement » (P1 `capital_dossier` et `capital_dossier_reglement`, P2 `capital_revalorise` et `capital_revalorise_reglement`, `facteur_revalorisation()`, la seule `valeur_actuelle_probable()`) ; famille « risque en cours » (P3 : `prospective_prime_pure`, `prospective_prime_declaree`, `prorata_cotisation`, témoin `retrospective`) ; `postes_a_arreter()` (M239) ; `conventions$limite_age` conditionnée (commit `moteur:` distinct en tête, § 6.3).
>
> **#51 et #54** (M234) : partie de ligne illisible par sa forme marquée `NA` dans `.visibilite_a()$parties` ; `.valeurs_vue()` lit ce masque sans convertir une date illisible ; test qui verrouille la partie illisible (§ 4.3). « Illisible » vaut « inconnu » : confirmé par la spécification, § 4.3. #51 et #54 sont fermées après la fusion par un commentaire qui renvoie à la présente issue.
>
> **I1, tranché le 10/11/2026 (avis Fable), validation a posteriori du mainteneur** : revalorisation acquise à l'arrêté recommandée (`capital_dossier`, `capital_revalorise`) ; méthodes « règlement » alternatives au statut de point prudent sur P1 (`capital_dossier_reglement`) comme sur P2 (`capital_revalorise_reglement`) ; paramètres obligatoires, année N+1, plan mixte signalé, recoupement exact (§ 1.1, § 5.4).
>
> **Critères d'acceptation** : spécification de B2, § 7.3, critères (3.1) à (3.14) ; cas R1 à R7 et T1 à T7 du § 7.4 ; contre-vérification `lifecontingencies` hors CI (§ 7.6).
>
> **Bilan existant inchangé** hors du commit (3.1) : tableau avant / après sur les bases des tests et les deux jeux, aux deux arrêtés.
>
> **Hors périmètre.** `calculer_provisions()` et agrégats (issue 4) ; tardifs (B3) ; meilleure estimation (B6).
>
> **Agents.** `coder-approfondi` (circuit 1), `audit` léger, `regulatory` sur la revalorisation, `actuary` valide.
>
> **Résultats** : provisions nouvelles, sans « avant » ; changement du bilan limité au commit (3.1), visa d'`actuary`.

### 8.4 Issue (4)

**Titre** : `calculer_provisions() : point d'entrée, objet resultat_provie, totaux et premières références (B2, issue 4)`

**Corps** :
> *Rédigé par l'agent actuary (IA).*
>
> **Objet.** Point d'entrée `calculer_provisions(donnees, plan, tables = list(), provenance = NULL)`, table `ETAPES`, objet `resultat_provie`, `rejouer_fiche()`, et workflow de régénération des références (commit `repo:`), selon la spécification de B2, § 7.7, et l'ADR 0011.
>
> **Comportement attendu.** Étapes et ordre du § 7.7 ; invariants de l'ADR 0010, point 7 ; total arrêté (§ 6.1) ; `declarations_requises` vide (sinon `declaration_manquante`) ; arrêt de poste (§ 6.2) et refus d'appel distingués ; enjeu par poste ; fiche complète (empreintes du résultat et du code) ; aucune dépendance à Shiny.
>
> **Critères d'acceptation.** Invariants (a) à (f) testés ; rejeu identique sur les deux jeux aux deux arrêtés ; scénarios adverses de la fiche de B2 ; **visa du mainteneur sur les premiers totaux** (par garantie et par référentiel), au vu du point d'attention A1 de la spécification (§ 10.2) ; références produites par la CI seule après le visa.
>
> **Hors périmètre.** Rapport figé, comparaison de deux plans (B7, B8) ; meilleure estimation (B6).
>
> **Agents.** `coder-approfondi` (circuit 1), `audit` léger, `actuary` valide ; dépend de (1), (2), (3) et de l'ADR 0011.
>
> **Résultats** : premiers totaux, sous visa du mainteneur.

### 8.5 Issue de transcription des tables homologuées (hors périmètre de B2)

**Titre** : `tables : transcription contre-vérifiée sur fac-similé du JO des tables de mortalité du capital décès, fichier de provenance et charger_table()`

**Libellés** : `needs-triage` (hors du périmètre fermé de B2, M244 ; branche à fixer par `architect`).

**Corps** :
> *Rédigé par l'agent actuary (IA).*
>
> **Constat.** B2 n'embarque aucune table réglementaire (décision du mainteneur du 10 novembre 2026) : les valeurs des tables homologuées n'ont pas été lues sur le fac-similé du JO (lecture de `regulatory` du 10 novembre 2026 ; annexe à A132-18 au JORF n° 0301 du 29/12/2015, texte n° 35, statut incertain, PDF inaccessible), et un dépôt public n'embarque une table qu'avec une transcription contre-vérifiée (ADR 0009, point 3). Spécification de B2, § 3.1.
>
> **À faire.**
> 1. `regulatory` établit, sur le fac-similé du JO (jamais par extraction de texte), la source de chaque table du capital décès : tables de A132-18 applicables aux « autres contrats » (TH 00-02, TF 00-02, décalages d'âge) et table unique 2024 (annexe de A132-18-1) ; licence etalab de Légifrance ; la mention de CONTEXT.md sur TD/TV 88-90 « (A132-18) », non sourcée, est vérifiée ou corrigée.
> 2. Transcription en format `lx_age`, **double saisie indépendante** comparée par script, puis contre-vérification contre `outil_tables` quand il embarque la même table (empreinte identique attendue).
> 3. Fichier de provenance par table (source, URL, date de consultation, licence, empreinte du fichier source et de la table transcrite, méthode de transcription, contre-vérification), aligné sur celui d'`outil_tables`.
> 4. `charger_table()` exporté (ADR 0010, point 13), un commit `donnees:` par table, annotation de l'ADR 0009 (passage d'« importée » à « embarquée »).
>
> **Critères d'acceptation.** Écart nul entre les deux saisies ; empreintes consignées ; `charger_table()` rend un `table_provie` de statut `homologuee` dont l'empreinte égale celle du fichier de provenance ; refus `table_absente` pour un identifiant inconnu.
>
> **Agents.** `regulatory` (source, licence), `coder`, `audit`, `actuary` valide la conversion.
>
> **Résultats.** Aucun sur les références de B2, qui n'emploient que des tables fictives ou importées ; tout plan qui passera d'une table importée à la table embarquée changera ses résultats (tableau avant / après).

## 9. Annotations d'ADR appelées (pour `architect`)

ADR 0010 :
1. **Point 11 (b)** : arrêt de poste né d'une visibilité non déterminée de motif R (M239) : règle (iii) du § 6.2, ligne de `refus_tables` porteuse de `postes_arretes` (même table, colonne de l'`origine`, même motif), sans colonne nouvelle ; motifs d'arrêt nés d'une famille (`hors_axes`, `affiliation_non_determinee`) sans ligne de bilan ; `motif_arret` du total `poste_arrete:<postes>` (§ 6.1).
2. **Dix-neuvième série, (b)** : règle de lecture d'une partie illisible : `NA` dans `.visibilite_a()$parties` dans les deux modes ; `NA` de `.valeurs_vue()` = « hors de la vue » ; un lecteur qui doit distinguer lit `parties` (§ 4.3).
3. **Dixième série, (d)** : exigence de `conventions$limite_age` à deux niveaux (§ 6.3).
4. **Point 1** : colonne « Branche » de `risque_en_cours` B6 → B2 (M118) ; `garanties` livré en issue (1) ; arête nouvelle `lecture` → `tables` (§ 3.3).
5. **Point 13** : `charger_table()` reporté à la première table embarquée ; `rejouer_fiche()` en issue (4) ; exports de B2 aux § 2.9 et § 3.7.
6. **Point 14** : `etats_a_date(vue, garanties)` sur l'objet `vue_a_date()` (et non `(base, date)`), colonnes ajoutées `etat_dossier`, `date_etat_dossier`, `motif_cloture`, `instruit` ; colonnes d'échéancier `cle` et `type_flux` ; `calculer_age()` dans `outils` (déjà annoté, septième série, (c)).
7. **Point 15** : statut `fictive` ; `origine$empreinte` = MD5 du contenu canonique ; axe `date` d'une série mensuelle = 12 × année + mois − 1.
8. **Point 16** : fichier `lectures.csv` du catalogue (§ 4.1) ; préfixe `champ:` dans `methodes` et `temoins` ; lecture « première méthode du champ = recommandée ».
9. **Point 17** : contenu des sections fixé (§ 2.2 à § 2.7) ; entrée nouvelle `conventions$decompte_jours` et domaines de `instant_date`, `repartition_annee`, `fractionnement` ; `tables$serie_tme$decalage_publication_mois`.
10. **Point 6, champ `indicateurs`** : valeur de `regle` `methode_revalorisation_mixte` (plan mixte, § 5.4) ; `depassement` de `A132_1` à trois valeurs (`NA` = dépassement indéterminé faute d'historique du plafond, échelle d'A132-1-1) ; `valeur_regle` de `A132_1` = taux de référence, bornes dans `detail`.
11. **Point 6, `statut_resultat`** : liste fermée : point noté (pas de statut pour une approximation de modèle ; `prorata_cotisation` restitué `approximation_numerique`, § 5.5) ; à trancher si la confusion avec une approximation numérique est jugée gênante.

Hors ADR, pour la session et `architect` : M122 amendée (texte au § 1.1) ; décision de I1 à I3 à numéroter (M) avec la mention « avis Fable, validation a posteriori du mainteneur » ; recensement de #20 en révision 5 (alternative `capital_dossier_reglement` de P1, méthode écartée « (b) actualisée à un taux prudent », I2 en lecture (i)) ; `docs/exigences.md`, E2.9 : retrait de « à confronter au texte mot à mot (issue #13) » (I2) ; consultation Fable comptée dans la PR de B2 (1/3).

ADR 0009 : annotation du point 3 (aucune table embarquée en B2, décision du mainteneur du 10 novembre 2026) et du point 5 (série TME importée, licence non trouvée, 0a).

## 10. Questions, points d'attention, issues proposées

### 10.1 Questions au mainteneur

| N° | Question | Recommandation | État |
|---|---|---|---|
| I1 | Revalorisation dans la PSAP vie : acquise ou jusqu'au règlement | (a) recommandée ; (b) alternative, point prudent, sur P1 et P2 (§ 1.1) | tranchée le 10/11/2026 (avis Fable), validation a posteriori du mainteneur |
| I2 | A132-1, « au-delà de huit ans » | lecture (i), une ligne par contrat (§ 1.2) ; sans effet sur une provision | tranchée le 10/11/2026 (avis Fable), validation a posteriori du mainteneur |
| I3 | Collectif décès annuel reconduit | lecture (b), primes périodiques (§ 1.3) ; sans effet en B2 | tranchée le 10/11/2026 (avis Fable), validation a posteriori du mainteneur |
| I4 à I6 | — | — | décidées le 10/11/2026 (§ 1.4 à § 1.6) |

**Questions bloquantes : aucune.** Aucune question de fond nouvelle n'est relevée hors I1 à I6, toutes tranchées. **Questions non bloquantes** (validation a posteriori) : le motif proposé pour la méthode écartée de I1 (§ 1.1), à confirmer par la révision 5 du recensement ; le délai de trois mois d'A132-1-1, non pris en compte, à confirmer par `regulatory` ; les appuis de l'avis Fable (directive 91/674/CEE, art. 60 ; ANC 336-4 et 336-8), à établir par `regulatory` avant citation dans la documentation. Les choix ci-dessous sont des décisions de la spécification, au statut écrit, couvertes par le visa délégué ; le mainteneur peut les rouvrir a posteriori :
- D-1 : la famille d'un sinistre non instruit suit `structure_familiale` du plan, sans lire `assures.situation_familiale` (recensement § 3.1 ; D03d en Bdr, M235) — jugement d'expert ;
- D-2 : une seule table `mortalite_tarif` par plan en B2 (pas de table par sexe) — limite restituée ;
- D-3 : `instant_date` et `fractionnement` à une seule valeur en B2 — motif au § 2.6 ;
- D-4 : `decalage_publication_mois` déclaré (calendrier de publication non établi) — hypothèse déclarée ;
- D-5 : arrêt de P1 et P2 sans affiliation couvrant la survenance (`affiliation_non_determinee`) en attendant D11 — sens prudent, aucune correction silencieuse.

### 10.2 Points d'attention (non bloquants pour (1) à (3) ; à voir avant (4))

- **A1 — premiers totaux sans contenu.** Sur les deux jeux versionnés, aux deux arrêtés de M240, P1, P2 et P3 sont nuls dans `v1-modeste-01` (dossiers `deces` tous clos le 2024-10-09 au plus tard, cotisations à périodes civiles : m4, m5), et P1, P2 et le total sont arrêtés dans `v1-modeste-02` (m6). Les premières références ne vérifieraient donc aucune valeur non nulle du capital décès. Recommandation : (i) ajouter aux références de l'ADR 0011 un plan de référence sur une base construite des tests (cas du § 7.4 réunis) ; (ii) créer un jeu versionné qui porte des contrats individuels temporaires et des dossiers ouverts à l'arrêté (IP1). À trancher par le mainteneur avec l'ADR 0011 (M240).
- **A2 — total sans tardifs.** Le total `deces` de B2 est la somme de P1, P2 et P3 ; P4 (tardifs) entre en B3. La fiche le dit par la liste des postes ; la documentation de fond et le futur rapport figé doivent le dire en clair.
- **A3 — portée colonne d'un refus de valeur hors de la vue.** Une seule indemnité journalière de signe inversé arrête P1 et P2 du capital décès (`v1-modeste-02`, m6), parce que le refus D09 sur `prestations.montant` est de portée colonne (dictionnaire, § 1.10, règle visée). Une portée restreinte aux lignes que le poste lit relèverait du dictionnaire `1.6` (IP4).

### 10.3 Issues proposées (création sur accord du mainteneur)

**IP1** — titre : `simulation : jeu versionné du capital décès avec contrats individuels temporaires et dossiers ouverts à l'arrêté` ; libellés : `needs-triage` ; corps :
> *Rédigé par l'agent actuary (IA).*
>
> Les jeux `v1-modeste-01` et `v1-modeste-02` n'ont aucun dossier `deces` ouvert aux arrêtés 2024-12-31 et 2025-12-31, ni contrat individuel, ni cotisation non échue (spécification de B2, § 0.3, mesures m4 et m5) : les références de B2 ne vérifient aucun montant non nul du capital décès. Proposition : un jeu (ou une extension de la loi vraie) avec contrats individuels temporaires à prime unique et périodique (taux du tarif, `capital_forfaitaire`, `prime_periodique`, `date_terme`), capitaux non réclamés (`non_identifie`), dossiers non fixés à l'arrêté, cotisations collectives à périodes non civiles. Il permettrait aussi la revue sur mesure de M122 / I1. Résultats : nouvelles références, sous visa.

**IP2** — titre : `I1 : sensibilité de la revalorisation des capitaux non réclamés sur un jeu qui en porte (M122 amendée)` ; libellés : `needs-triage` ; corps :
> *Rédigé par l'agent actuary (IA).*
>
> M122, amendée par l'arbitrage de I1 du 10 novembre 2026 (avis Fable), remplace « à revoir sur mesure en B2 » par une sensibilité sur un jeu qui porte des capitaux non réclamés ; aucune n'est possible sur les jeux versionnés (aucun dossier de P2). À faire sur le jeu d'IP1 : second plan qui ne diffère que par la méthode (`capital_revalorise_reglement` contre `capital_revalorise`, et `capital_dossier_reglement` contre `capital_dossier`), écart par ancienneté depuis la connaissance du décès, restitué au mainteneur. Dépend d'IP1.

**IP3** — titre : `tables : format d'outil_tables (en-tête de métadonnées) en entrée` ; libellés : `needs-triage` ; corps :
> *Rédigé par l'agent actuary (IA).*
>
> L'ADR 0009 (point 2) admet le format d'`outil_tables` ; sa spécification n'est pas dans le dépôt, et B2 ne lit que `lx_age` et `serie_tme_mensuelle` (spécification de B2, § 3.2). À faire : relevé du format sur le poste du mainteneur, lecteur et conversion vers `table_provie`, fichier de provenance aligné. Résultats : aucun.

**IP4** — titre : `dictionnaire 1.6 : portée d'un refus de valeur sur une colonne hors de la vue (arrêt des seuls postes qui lisent la ligne)` ; libellés : `needs-triage` ; corps :
> *Rédigé par l'agent actuary (IA).*
>
> Un refus de valeur identifié par ligne sur une colonne ordinaire (D09 de signe sur `prestations.montant`) est de portée colonne (dictionnaire, § 1.10) et arrête tout poste qui lit la colonne, même si la ligne refusée relève d'une autre garantie (`v1-modeste-02` : une indemnité journalière arrête P1 et P2 du capital décès ; spécification de B2, § 6.2). M199 a donné la portée ligne aux seules colonnes lues par la vue. À examiner pour la `1.6` : portée ligne avec arrêt des postes dont la population contient la ligne. Effet : des postes et des totaux aujourd'hui arrêtés deviendraient calculés ; tableau avant / après et visa du mainteneur.

L'issue de transcription contre-vérifiée des tables homologuées sur fac-similé est créée par la session (décision du mainteneur du 10 novembre 2026) ; elle porte aussi le fichier de provenance et `charger_table()`.
