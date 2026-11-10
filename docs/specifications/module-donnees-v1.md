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
    - (c) **Vue à A < extraction** (v1.4 ; Q5, D2, D4, Q7, Q8).
      - **Calcul.** La visibilité d'une ligne, ou d'une partie de ligne, à A se calcule dans la même logique. Elle est inconnue si les valeurs inconnues que la ligne lit, directement ou par le verdict d'une règle P, peuvent lui donner deux statuts différents à A : visible, invisible, ou non déterminée par D02b ou D03g faute de déclaration.
      - **Exception déterminée.** Une ligne qu'une date connue rend invisible à A, ou dont la parente est invisible, est invisible de façon déterminée (principe de M187).
      - **Inscription.** Une ligne de visibilité inconnue est de visibilité non déterminée. Elle est inscrite dans `vue$visibilite_non_determinee` avec `motif` = code du refus, `colonne` = `NA` (ligne entière) ou la colonne de la partie (M167), et `origine` = « table.colonne » (M202).
      - **Origine, lecture existentielle** (D2). La ligne est inscrite sous chaque colonne refusée dont la valeur peut changer son statut à A, les autres valeurs inconnues de la ligne prenant toute valeur du domaine de leur colonne (dictionnaire), sans égard aux autres colonnes de la ligne : déduire une valeur refusée de sa compatibilité avec le reste de la ligne reviendrait à l'imputer (avis d'`actuary` sur la question A de l'audit de #33). L'origine est toujours une colonne de la table de la ligne (Q8).
      - **Règle par colonne**, conséquence de ce qui précède (Q5, D4) :

        | Colonne refusée | Ligne (ou partie) de visibilité non déterminée |
        |---|---|
        | Colonne de visibilité de la ligne (dict. § 6), `date_saisie_fin`, `sinistres.date_instruction` | Toute ligne (ou partie) refusée |
        | `evenements.type_evenement`, `evenements.date_effet` | Ligne dont le verdict de D02b est inconnu ; sous l'hypothèse de D02b déclarée (visibilité = max(saisie, effet, parente)), seulement si en plus l'effet est postérieur à A ou inconnu |
        | `evenements.motif` | Comme la ligne précédente, et seulement si le type est inconnu ou programmable selon le motif (`oui:<motifs>`) |
        | `contrats.date_fin`, `affiliations.date_fin` | Partie dont la `date_saisie_fin` manque ou est inconnue ; sinon, la fin est connue (ou inconnue) à sa date de saisie |
        | `sinistres.date_declaration`, `catastrophes.date_evenement` | Toute ligne refusée |

        - **`sinistres.date_declaration`.** Son seul verdict de D02b déterminé est celui d'une ligne dont la date de saisie est connue absente, et cette ligne relève de D03g : non déterminée sous D03g sans déclaration, non déterminée sous le motif du refus sous `H` de D03g (cas limite 2), hors de la vue sous `X`. Les deux écritures (« toute ligne refusée » et par verdict) donnent donc le même bilan. `evenements.date_effet`, qui est aussi la date d'effet de D03g, suit l'écriture par verdict, avec le même résultat.
        - **`catastrophes.date_evenement`.** La date de saisie de `catastrophes` n'a pas de D03g : son absence est un refus, et le verdict de D02b est inconnu sur toute ligne refusée.
      - **Filles.** Les filles écartées par la règle 1 figurent sous `parente_non_determinee`, origine `NA`, sans exigence propre (cas limite 4 ; Q8).
      - **Partie de ligne.** Seule la partie est masquée ; la ligne reste dans la vue.
      - **Comptes** (Q7). Une valeur refusée n'étant pas lue, `nombre_visibles` d'un refus vaut `NA` dès qu'une ligne qui le porte est de visibilité non déterminée, quel qu'en soit le motif ; `nombre_dossiers` compte les dossiers rattachés connus à A et ne vaut `NA` que si la visibilité de l'un d'eux est indéterminée (§ 4.4).
    - (d) Règles V : la lecture d'une colonne par la vue ne les bloque plus pour un refus de valeur ; les lignes non déterminées sont hors de la vue. Une règle V qui lit la colonne comme valeur reste bloquée, cause = motif (M169, inchangé sur ce point ; M200).
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

1. **Invariance** : pour A1 ≠ A2 sur une même base, les lignes du bilan des règles B et P (détection) sont `identical()`, hors les refus induits nés d'une règle P empêchée par un défaut de forme (M178), seuls dépendants de l'arrêté, et hors `nombre_visibles` et `nombre_dossiers`.
2. **Identité** : à A = extraction, chaque compte de la règle V égale celui d'une détection directe sur la base entière, et D02b et D03g sont en `S`.
3. **Aucune exclusion par la vue** : toute orpheline injectée (registre de D04) figure au bilan à tout arrêté.
4. **Registre** : à A = extraction, détection exacte égale à l'injection (dict. :733). À A < extraction, pour les défauts intrinsèques à la ligne (D02a hors `famille`, D03a à D03f), les lignes détectées égalent les lignes injectées visibles à A.
5. **Refus sur ligne invisible** : un D09 de signe injecté sur une prestation de `date_saisie` > A figure dans `refus_tables` à A, avec `nombre_visibles = 0`.
6. **Substitution** (v1.4, R2). Pour toute ligne, ou partie de ligne, qui porte une valeur refusée lue par une règle P, on remplace la valeur refusée par des valeurs admises contrastées : type programmable et non programmable, motif qui rend le type programmable ou non, date antérieure et date postérieure à A ou à la date comparée, absence. Si le statut à A diffère entre les substitutions, la ligne est non déterminée sous un refus ; sinon, elle a ce statut. Le contrôle porte sur un corpus fini de cas qui couvre chaque colonne du tableau de (c), sans hypothèse et sous l'hypothèse de D02b. C'est une vérification, pas une preuve : la règle découle de (b) et (c).

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
  - `declaration_absente` : convention ou seuil du plan absent ; la déclaration manquante figure aussi dans `declarations_requises` (§ 3.2) ;
  - `refus_induit` : contrôle empêché par un refus induit (règle B, ou règle P empêchée, M178).
  - Une composante de l'enjeu empêchée y figure aussi, sous le code de la composante (§ 4.3), avec la table et la colonne lues. `visibilite_non_determinee` n'est jamais une cause de cette table (§ 4.2).
  - Une clé présente à la fois dans `controles` et ici est une détection partielle : son nombre est un minorant.
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
- À A < extraction, une ligne de D03g non résolue (déclaration incomplète, ou date non calculable sous `H`), ou de D02b dont le `H` n'est pas déclaré, n'a pas de date de visibilité (M167, M171). Ces lignes sont :
  - tenues hors de la vue pour les détections de la règle V ;
  - recensées dans `vue$visibilite_non_determinee` (`table` ; `colonne` : `NA` pour la ligne entière, sinon la partie de ligne ; `motif`, dont `parente_non_determinee` pour les filles écartées par la règle 1, et le code du refus pour une ligne non déterminée par un refus de valeur (§ 2.2) ; `origine` : « table.colonne » de la valeur refusée pour un motif de refus, toujours une colonne de la table de la ligne (v1.4, Q8), `NA` pour D02b, D03g et `parente_non_determinee` (M202) ; `nombre` ; `identifiants`). Regroupement par (`table`, `colonne`, `motif`, `origine`) ; tri existant, puis `origine` (ADR 0010, quatorzième série, (b)).

  Une partie de ligne non déterminée laisse la ligne dans la vue.

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
  - Un porteur de visibilité non déterminée, ou une ligne qui entre dans sa valeur, donne `NA`, cause `visibilite_non_determinee`, hors de `controles_non_executes`. La cause l'emporte sur l'absence de porteur. Une ligne de visibilité non déterminée par un refus de valeur (§ 2.2) est un porteur de visibilité non déterminée (M201).
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
- `nombre_visibles` suit la vue, règle 1 comprise (versions valables de `famille`), et vaut `NA` si une visibilité est indéterminée, y compris pour un refus de valeur dont une ligne est de visibilité non déterminée (la valeur refusée n'est pas lue ; v1.4, Q7). `nombre_dossiers` compte les dossiers rattachés connus à A et ne vaut `NA` que si la visibilité de l'un d'eux est indéterminée (v1.4 ; définition à trancher : issue #44, dossiers rattachés connus ou dossiers des lignes visibles).

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
4. Une composante qui lit une colonne refusée a `montant = NA`, `cause` renseignée, et figure dans `controles_non_executes`, sous le code de la composante, sauf, à A = extraction, une composante qui ne lit la colonne refusée que pour la visibilité (§ 4.2, Q2 ; v1.4).
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
3. **Visibilité non déterminée par un refus de valeur** (M204). Une ligne de `vue$visibilite_non_determinee` de motif `R` arrête, avec ce motif, les postes qui lisent sa table ou une descendante à l'arrêté ; aucune déclaration ne la lève (dict. § 1.10) avant un traitement `X` du dictionnaire `1.6` (§ 7, point 6). Limite assumée : en B2, aucun arrêt de ce type n'est levé tant qu'aucun traitement `X` n'existe. La forme de l'arrêt dans le bilan est à décider au plan de B2.

## 7. Points notés pour le dictionnaire `1.6`

1. **D07 (c)** : remplacer « a dépassé `age_limite` » (dict. :755) par un renvoi à la règle de limite déclarée (`conventions$limite_age`, § 5.3), et préciser au § 5 (dict. :640, :643) que la lecture de `age_limite` est cette règle.
2. **D10 (a)** : portée table de la table fille (`dossiers`, `rentes`, `prestations`), à écrire au § 1.10 ou au § 9 (dict. :758).
3. **Colonne `traitement` (`R`, `S`)** au tableau des codes du § 1.10 et dans `controles.csv` (proposition d'ADR 0010, sixième série, (a), :297), qui rend explicite le `S` de `somme_parts`.
4. **Question 4.9** : écrire au § 1.10 qu'aucune exclusion `X` d'une valeur illisible ou hors domaine n'est admise en v1 (dict. :154-155).
5. **Âge** : au § 1.5 (dict. :109), renvoyer aux conventions fermées de la présente spécification, sans les recopier.
6. **Traitement `X` des dates de visibilité manquantes** (point P18, M203) : soit étendre D03g aux dates de saisie de visibilité hors liste (`dossiers.date_ouverture`, `catastrophes.date_saisie`, `victimes.date_saisie`), soit créer un défaut « date d'effet de visibilité manquante » (`contrats.date_effet`, `garanties_souscrites.date_effet`, `prestations.date_reglement`, `cotisations.date_mouvement`) traité `X`. Les valeurs hors domaine restent `R` (question 4.9, M151). Ce point porte l'exigence X de l'issue #33, hors de la branche `claude/donnees-controles`.

Les points P6 à P17 du commentaire d'errata de la PR #29 complètent cette liste. Ils ne sont pas décidés, sauf P12 (code dédié au refus né d'une règle P empêchée, décidé par le mainteneur le 8 novembre 2026), et ne sont pas intégrés à la présente version. Le point P18 est le point 6 ci-dessus.
