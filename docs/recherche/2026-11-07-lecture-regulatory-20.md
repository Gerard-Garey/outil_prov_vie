> *Rédigé par l'agent regulatory (IA), le 7 novembre 2026 (issue #20, branche `claude/socle-donnees`, PR #21).* Lecture des points R1 à R10 du § 10 du recensement non visé d'`actuary-approfondi`. Statut : **partiel** (R7 non traité ; R8 traité en partie).

# Sources lues et méthode

- **Droit français : consolidation LEGI de la DILA** (Légifrance renvoie 403). Lue sur une copie locale des archives LEGI (archive globale du 13/07/2025, tronquée, et incréments quotidiens du 13/07/2025 au 06/11/2026), faite par une session antérieure dans `/tmp/claude-0/-home-user-outil-prov-vie/a4980bda-…/scratchpad/legi/`.
  - **Contrôle d'intégrité ce jour** : l'incrément `LEGI_20260711-213130.tar.gz` a été retéléchargé de `https://echanges.dila.gouv.fr/OPENDATA/LEGI/` (SHA-256 de l'archive `49b5f2e7…82464491`). Les fichiers de R343-7 (`LEGIARTI000049684158`, SHA-256 `95302caf…a482d460f`) et de R343-3 (`LEGIARTI000039739686`, `4b02b526…c207b080`) sont identiques octet pour octet à la copie locale.
  - **Fraîcheur** : l'incrément du 07/11/2026 (`LEGI_20261107-210930`, SHA-256 `61143b31…5eb5861846524a494752f7cc940ae38b1829`) a été téléchargé. Il ne touche ni le Code des assurances (`LEGITEXT000006073984`), ni le CSS (`LEGITEXT000006073189`), ni le Code de la mutualité (`LEGITEXT000006074067`).
  - **Version retenue** : pour chaque article, celle dont l'intervalle [DATE_DEBUT ; DATE_FIN[ contient le 07/11/2026. L'empreinte du fichier XML est donnée ci-dessous.
  - **Statut au sens d'ADR 0015** : « consolidation officielle lue, datée et à empreinte contrôlée ». Seuls R343-3 et R343-7 ont une empreinte recoupée par retéléchargement ; pour les autres articles, l'empreinte est celle de la copie locale. Le JO du texte modificateur n'est pas relevé (« à établir »).
  - **Limite** : l'extraction du CSS est incomplète (archive globale tronquée). Un article du CSS absent de la copie est **non trouvé**, pas inexistant.
- **Normes comptables : recueil ANC « Assurance », version en vigueur au 1er janvier 2025.** C'est une consolidation, citée comme telle. Copie locale, SHA-256 `0d7fb3c86e6293e57c4141bf859f926056ba6617bed4794830c83839e9319766` (identique à la lecture du cadrage). Texte extrait par `pdftotext -layout` ; la couleur (noir : texte du règlement, bleu : doctrine) a été contrôlée en rendu graphique pour la page 38 (art. 223-1). Aucune version du recueil au 1er janvier 2026 n'a été recherchée ce jour (« à établir »).
- **Droit de l'Union** : EUR-Lex non consulté ce jour (R7).

## Empreintes des articles lus (fichiers XML LEGI, version en vigueur au 07/11/2026)

| Article | Identifiant LEGI | En vigueur depuis | Texte modificateur (LEGI) | SHA-256 (16 premiers) |
|---|---|---|---|---|
| CA R343-3 | LEGIARTI000039739686 | 01/01/2020 | décret n° 2019-1437 du 23/12/2019, art. 2 | 4b02b526a9d95535 |
| CA R343-7 | LEGIARTI000049684158 | 10/06/2024 | décret n° 2024-523 du 07/06/2024, art. 1 | 95302caf0339e169 |
| CA L132-5 | LEGIARTI000029098941 | 01/01/2016 | loi n° 2014-617 du 13/06/2014, art. 3 | 16ca6f24520fd742 |
| CA R132-3-1 | LEGIARTI000031116526 | 01/01/2016 | décret n° 2015-1092 du 28/08/2015, art. 2 (création) | c0adeb9942cad885 |
| CA L132-27-2 | LEGIARTI000038611080 | 24/05/2019 | loi n° 2019-486 du 22/05/2019, art. 71 (V) | 3113e30f3c447043 |
| CA A132-1 | LEGIARTI000035514601 | 07/09/2017 | arrêté du 14/08/2017, art. 1 | d802eae2f10f0ebe |
| CA A132-1-1 | LEGIARTI000039801948 | 01/01/2020 | arrêté du 26/12/2019, art. 4 | a738fddd4d0cc0ca |
| CA A132-18 | LEGIARTI000035514715 | 07/09/2017 | arrêté du 14/08/2017, art. 1 | f812fd8796466f86 |
| CA A132-18-1 | LEGIARTI000050653202 | 23/11/2024 | arrêté du 18/11/2024, art. 1 (création) | bea1216983a5c6e8 |
| CA A343-1-1 | LEGIARTI000031771151 | 01/01/2016 | arrêté du 28/12/2015, art. 2 (création) | 3149bab17fb85bbd |
| CA R321-1 | LEGIARTI000027888550 | 28/07/2013 | à établir | a550d2d651ed45e3 |
| CA R321-5 | LEGIARTI000019749371 | 10/11/2008 | à établir | e1fef7abf3b28255 |
| CA L310-1 | LEGIARTI000034386700 | 08/04/2017 | ordonnance n° 2017-484 du 06/04/2017, art. 1 | e2e6b5552505d4a2 |
| Mutualité L223-19-1 | LEGIARTI000029098962 | 01/01/2016 | loi n° 2014-617 (NOTA : art. 4, II) | fd402e45712f9b2c |
| Mutualité R223-9 | LEGIARTI000031116592 | 01/01/2016 | décret n° 2015-1092, art. 3 (création) | af17e2a77712e68b |
| Mutualité L223-25-4 | LEGIARTI000038611073 | 24/05/2019 | à établir (loi n° 2019-486 probable, non relevé) | 12c5d731ce5adb75 |
| Mutualité R223-11 | LEGIARTI000031116614 | 01/01/2016 | décret n° 2015-1092, art. 3 | 2fa9ff30a00c301b |
| CSS L932-23 | LEGIARTI000048252309 | 24/10/2024 | loi n° 2023-973 (NOTA : art. 35, V) | 705bfb4a49b8dbf4 |
| CSS L912-3 | LEGIARTI000006745479 | 24/06/2006 | à établir | e9ecf94253f9a1a1 |

ANC (recueil au 01/01/2025, consolidation) : art. 141-1, 142-2, 142-3, 142-4 (PDF p. 19), 143-9, 143-10, 143-11, 223-1 (2e alinéa, PDF p. 38, texte noir), 333-4, et la liste des comptes (comptes 32, 33, 600x).

---

# R1 — Rattachement des rentes à constituer, des arrérages échus non payés et des tardifs des rentes (priorité)

**Statut** : textes **vérifiés** (consolidations ci-dessus) ; **rattachement non établi par un texte : interprétation** (deux lectures), sauf le compte des tardifs vie (vérifié).

**Textes lus**
- R343-3 (vie), liste en tête : « Les provisions techniques correspondant aux opérations d'assurance sur la vie, d'assurance nuptialité-natalité et de capitalisation, sont les suivantes : » — onze catégories, **aucune provision pour sinistres à payer**. Dernier alinéa sauf un : « Un engagement ne peut être provisionné qu'au titre d'une seule des catégories mentionnées au présent article. »
- R343-7, 4° (autres opérations) : « Provision pour sinistres à payer : valeur estimative des dépenses en principal et en frais, tant internes qu'externes, nécessaires au règlement de tous les sinistres survenus et non payés, y compris les capitaux constitutifs des rentes non encore mises à la charge de l'entreprise. » Le 1° : « Provision mathématique des rentes : valeur actuelle des engagements de l'entreprise en ce qui concerne les rentes et accessoires de rentes mis à sa charge ».
- ANC 333-4 : « Les provisions pour sinistres tardifs sont portées à des sous-comptes distincts des comptes 320 « Provisions pour sinistre à payer Vie – Affaires directes », 321 […], 324 […] ».
- ANC 223-1, 2e alinéa (texte réglementaire, noir, PDF p. 38, dans le chapitre des contrats en unités de compte) : « les engagements nés de tels contrats qui ne sont pas libellés en unités de compte (garanties annexes, sinistres ou rachats dont le montant a été liquidé en euros, etc.) sont enregistrés aux comptes « Provisions d'assurances Vie » ou « Provisions pour sinistre à payer Vie ». »
- ANC 142-4 : « Les provisions mathématiques de tous les contrats individuels et collectifs de rentes viagères en cours de service au 1er janvier 2007 ou liquidées à compter de cette même date, sont calculées en appliquant […] les tables de mortalité appropriées mentionnées aux articles A.132-18 du code des assurances, A.223-8 du code de la mutualité et A.932-3-11 du code de la sécurité sociale […] ».
- Liste des comptes ANC : 32 « Provisions pour sinistres à payer Vie » ; 6000/6001 « Sinistres et capitaux échus » ; 6001/6002 « Versements périodiques de rentes » (selon la catégorie d'organisme).

**Lecture**
1. **Tardifs des rentes** (décès survenus non déclarés, pour leurs rentes) : le plan de comptes prévoit un sous-compte des tardifs du compte 32 (vie). Le rattachement à la **PSAP vie, sous-compte des tardifs**, suit le plan de comptes ; c'est la proposition du recensement. **Vérifié** quant à l'existence du compte ; aucun texte de calcul (voir R10).
2. **Rentes à constituer** (décès déclaré, rente non encore mise en service) : aucun texte vie ne les vise expressément. La formule « capitaux constitutifs des rentes non encore mises à la charge de l'entreprise » n'existe qu'à R343-7, 4°, pour les autres opérations.
   - **Lecture (a) — PSAP vie, compte 32** : analogie avec R343-7, 4° ; le sinistre est survenu et la prestation n'est pas liquidée ; ANC 223-1 range en compte 32 des « sinistres […] dont le montant a été liquidé ».
   - **Lecture (b) — provision mathématique vie, R343-3, 1°** : l'engagement est viager, né du décès, et R343-3 ne connaît pas d'autre catégorie ; ANC 142-3 (taux et tables de la provision mathématique) s'applique alors directement.
   - **Effet** : le montant ne change pas si taux et tables sont les mêmes. Le choix fixe les règles de taux et de tables contre lesquelles le contrôle se fait (142-3 et 142-4 sont écrits pour les provisions mathématiques), le chargement de gestion et le poste du bilan.
   - **Avis motivé**, non tranché : (a) suit le plan de comptes et la décision M81 (capitaux déclarés non réglés). Mais 142-4 vise les rentes « liquidées », et une rente liquidée non encore servie tombe dans (b). Une lecture mixte est défendable : (a) jusqu'à la liquidation, (b) dès la liquidation. Choix du mainteneur, après avis d'`actuary`.
3. **Arrérages échus non payés** des rentes en service (périodes antérieures à l'arrêté non couvertes par un paiement) : aucun texte exprès. Ce sont des montants dus et déterminés. ANC 223-1 (montant « liquidé en euros » → compte 32) et la structure du compte 6001/6002 (« versements périodiques de rentes ») font pencher pour la **PSAP vie (compte 32)** ; la provision mathématique (R343-3, 1°, « valeurs actuelles des engagements ») porte les arrérages futurs. Lecture alternative : les garder dans la provision mathématique de la rente (prestation non encore versée). **Interprétation** ; avis : PSAP vie. Le montant est le même, il change seulement de poste.

---

# R2 — Capitaux non réclamés (priorité)

**Statut** : **vérifié** pour le Code des assurances et le Code de la mutualité (consolidation LEGI) ; **incertain** pour les institutions de prévoyance (décret de taux non trouvé dans la copie, incomplète, du CSS) ; l'extension de M81 est une **interprétation**.

**Textes lus**
- **L132-5, 3e alinéa** (et non « dernier ») : « Le contrat d'assurance comportant des valeurs de rachat et le contrat d'assurance sur la vie ne comportant pas de valeur de rachat dont les bénéficiaires sont des personnes physiques précisent les conditions dans lesquelles, en cas de décès, la revalorisation du capital garanti intervient à compter du décès de l'assuré jusqu'à la réception des pièces mentionnées à l'article L. 132-23-1 ou, le cas échéant, jusqu'au dépôt de ce capital à la Caisse des dépôts et consignations en application de l'article L. 132-27-2. »
- **L132-5, 4e et dernier alinéa** : « […] la revalorisation, mentionnée au troisième alinéa du présent article, de la part du capital garanti en cas de décès dont la valeur en euros a été arrêtée ne peut être inférieure à un taux fixé par décret en Conseil d'Etat. » NOTA : « Conformément au II de l'article 3 de la loi n° 2014-617 du 13 juin 2014, le dernier alinéa du présent article, dans sa rédaction résultant de ladite loi, s'applique à tous les faits générateurs postérieurs à l'entrée en vigueur de la loi. »
- **R132-3-1** (taux, point de départ, terme) :
  - « 1° Le capital en euros garanti en cas de décès produit de plein droit intérêt dès la date du décès de l'assuré ;
  - 2° A compter de la date de connaissance du décès, le capital en euros garanti en cas de décès produit de plein droit intérêt, net de frais, pour chaque année civile, au minimum à un taux égal au moins élevé des deux taux suivants : a) La moyenne sur les douze derniers mois du taux moyen des emprunts de l'Etat français, calculée au 1er novembre de l'année précédente ; b) Le dernier taux moyen des emprunts de l'Etat français disponible au 1er novembre de l'année précédente ;
  - 3° Entre la date du décès et la date de connaissance du décès, lorsque les clauses contractuelles prévoient une revalorisation du capital en euros garanti en cas de décès, celles-ci s'appliquent, dès lors qu'elles entraînent une revalorisation du capital nette de frais ; à défaut, le 2° du présent article s'applique dès la date du décès de l'assuré. »
- **L132-27-2, I, 1er alinéa** : « Les sommes dues au titre des contrats d'assurance sur la vie […] qui ne font pas l'objet d'une demande de versement des prestations ou du capital sont déposées à la Caisse des dépôts et consignations à l'issue d'un délai de dix ans à compter de la date de prise de connaissance par l'assureur du décès de l'assuré ou de l'échéance du contrat. Le dépôt intervient dans le mois suivant l'expiration de ce délai. […] Les sommes dues au titre d'un contrat d'assurance temporaire en cas de décès ne font pas l'objet de ce dépôt lorsque le décès de l'assuré est intervenu antérieurement au 1er janvier 2015. » I, 6e alinéa : « Le dépôt des sommes à la Caisse des dépôts et consignations en application du présent I est libératoire de toute obligation pour l'assureur et le souscripteur, à l'exception des obligations en matière de conservation d'informations […] ».
- **Mutuelles** : L223-19-1 (même règle, « du membre participant », « jusqu'au dépôt […] en application de l'article L. 223-25-4 ») ; R223-9 (même taux, même rédaction des 1° à 3°) ; L223-25-4, I (dépôt à dix ans, même rédaction, temporaire décès compris) ; R223-11 (date de prise de connaissance du décès = obtention de l'acte de décès, notamment après consultation du RNIPP, L223-10-2).
- **Institutions de prévoyance** : CSS L932-23, 1er alinéa : « les dispositions du chapitre Ier, des sections 1 et 1 bis du chapitre II, du chapitre IV du titre III et du chapitre IV du titre IV du livre Ier du code des assurances sont applicables aux règlements et contrats des institutions de prévoyance lorsqu'elles réalisent des opérations d'assurance sur la vie et de capitalisation » (sauf une liste d'articles qui ne comprend ni L132-5 ni L132-27-2). L132-5 et L132-27-2 sont en « Section I : Dispositions générales » du chapitre II (contexte LEGI lu). Le **décret de taux** applicable aux IP (équivalent de R132-3-1) est **non trouvé** dans la copie du CSS.

**Lecture**
1. **Corrections de citation** à porter au recensement :
   - la revalorisation (point de départ et terme) est au **3e alinéa** de L132-5 ; le « dernier alinéa » ne porte que le plancher de taux ;
   - le dépôt à la CDC se cite **L132-27-2** (version du 24/05/2019, loi n° 2019-486, art. 71) plutôt que « loi n° 2014-617, art. 13 », dont le numéro d'article n'a pas été lu ce jour (non vérifié) ;
   - le taux est fixé par **R132-3-1** (décret n° 2015-1092), pas par la loi.
2. **Taux** : par année civile, au minimum le moins élevé des deux taux (moyenne sur douze mois du TME au 1er novembre N-1, dernier TME disponible au 1er novembre N-1), **net de frais**. Point de départ : le décès (contractuel entre le décès et sa connaissance s'il est net de frais, sinon le taux légal dès le décès). Terme : réception des pièces (L132-23-1), ou dépôt à la CDC, qui est libératoire.
3. **Délai de dépôt** : dix ans après la prise de connaissance du décès, dépôt dans le mois suivant. Décès antérieurs au 01/01/2015 sur une temporaire décès : pas de dépôt.
4. **Champ** : le texte vise le contrat sur la vie sans valeur de rachat « dont les bénéficiaires sont des personnes physiques ». L132-27-2 nomme la temporaire décès ; les garanties décès en relèvent donc.
   - Contrats **collectifs** de prévoyance : aucun texte lu ne les exclut, mais aucun ne les nomme. **Incertain** pour les entreprises d'assurance (L132-5 est une disposition générale du chapitre II) ; IP couvertes par renvoi (L932-23) ; mutuelles par leurs propres articles.
5. **Décès inconnus identifiés plus tard** :
   - le délai de dépôt ne court qu'à compter de la **prise de connaissance** ;
   - la revalorisation légale court **dès le décès** (R132-3-1, 1° et 3°).
   - Conséquence pour la frontière P2 / P4 : un décès tardif (P4) identifié après l'arrêté porte une revalorisation due depuis la date du décès. Le coût d'un tardif comprend donc la revalorisation courue entre le décès et le règlement. C'est à porter à `actuary` (coût moyen des tardifs, P4). La frontière Q4 du recensement (inconnus = tardifs) reste compatible avec le texte.
6. **Extension de M81** (PSAP vie aux capitaux exigibles non réclamés) : aucun texte ne fixe le poste. Même raisonnement que l'interprétation 1 de #14 : (a) PSAP vie, compte 32 (montant liquidé, ANC 223-1) ; (b) provision mathématique, R343-3, 1°. **Interprétation** ; avis : (a), cohérent avec M81. Le montant est identique (capital et revalorisation acquise). Q5 (revalorisation acquise seule, ou à courir) n'est pas tranchée par le texte, qui fixe un minimum par année civile et non une règle de provisionnement : jugement d'expert, à déclarer.

---

# R3 — Tables des rentes de conjoint et d'éducation en comptes sociaux

**Statut** : 142-3, 142-4, A132-18 et A132-18-1 **vérifiés** (texte) ; la table annexée à A132-18-1 n'a **pas été lue** (fac-similé requis) ; A223-8 (mutualité) et A932-3-11 (CSS) **non lus** ; application aux rentes temporaires : **interprétation**.

**Textes lus**
- ANC 142-3 : provisions mathématiques « calculées d'après des taux d'intérêt au plus égaux à ceux retenus pour l'établissement du tarif et, s'ils comportent un élément viager et sous réserve de l'article 142-4 du présent règlement, d'après les tables en vigueur à l'époque de l'application du tarif […] » ; 2e alinéa : faculté d'appliquer à chaque inventaire les tables appropriées en vigueur à la date de l'inventaire.
- ANC 142-4 : extrait au point R1 (rentes viagères « en cours de service au 1er janvier 2007 ou liquidées à compter de cette même date » : tables de A132-18, A223-8, A932-3-11 « applicables aux contrats de rente viagère souscrits à compter de cette même date », à chaque inventaire).
- A132-18 : « Pour les contrats de rentes viagères, en ce compris celles revêtant un caractère temporaire, et à l'exception des contrats relevant du chapitre III du titre IV du livre Ier, le tarif déterminé en utilisant les tables mentionnées au b ne peut être inférieur à celui qui résulterait de l'utilisation des tables appropriées mentionnées au a. » Et : « Pour les contrats collectifs en cas de décès résiliables annuellement, le tarif peut être établi d'après les tables mentionnées au a avec une méthode forfaitaire si celle-ci est justifiable. »
- A132-18-1 : « Par dérogation au quatrième alinéa de l'article A. 132-18, les tarifs des contrats conclus dans les conditions prévues à l'article L. 911-1 du code de la sécurité sociale peuvent être établis d'après une table unique pour tous les assurés ci-annexée. »

**Lecture**
- 142-4 impose, à chaque inventaire, les tables de rentiers en vigueur pour les rentes viagères **en service ou liquidées**, et prime sur 142-3 (« sous réserve de l'article 142-4 »). Il vaut pour la rente de conjoint viagère.
- **Rente temporaire** (conjoint temporaire, éducation) :
  - **(a)** 142-4 s'applique : A132-18 assimile les rentes temporaires aux rentes viagères pour le tarif (« en ce compris celles revêtant un caractère temporaire ») ;
  - **(b)** 142-4 ne vise que les « rentes viagères » et la rente temporaire relève de 142-3 (tables de l'époque du tarif, ou faculté du 2e alinéa).
  - Avis : (a), par cohérence avec A132-18. Choix du mainteneur.
- Pour une rente d'éducation, l'élément viager (survie de l'enfant jusqu'à l'âge limite) pèse peu : l'écart entre (a) et (b) se mesure par sensibilité (`actuary`).
- A132-18-1 ouvre une table unique (non genrée) aux contrats de L911-1 CSS. Son contenu ne se lit que sur le fac-similé du JO (arrêté du 18/11/2024, JO à établir) : **non lu**. A132-18-1 dit « peuvent être établis » : c'est une faculté de tarif. Sa reprise en provision passe par 142-3 et 142-4 : interprétation, non tranchée.

---

# R4 — A132-1 et A132-1-1 (« souscription », « taux moyen » face au TME)

**Statut** : textes **vérifiés** ; sens de « souscription » et égalité avec le TME : **interprétation**.

**Textes lus**
- A132-1, 1er alinéa : « un taux au plus égal à 75 % du taux moyen des emprunts de l'Etat français calculé sur une base semestrielle sans pouvoir dépasser, au-delà de huit ans, le plus bas des deux taux suivants : 3,5 % ou 60 % du taux moyen indiqué ci-dessus. Pour les contrats à primes périodiques ou à capital variable, quelle que soit leur durée, ce taux ne peut excéder le plus bas des deux taux suivants : 3,5 % ou 60 % du taux moyen indiqué ci-dessus. »
- A132-1, 4e alinéa : « Le taux moyen des emprunts d'Etat à retenir est le plus élevé des deux taux suivants : taux à l'émission et taux de rendement sur le marché secondaire. »
- A132-1, dernier alinéa : « Les règles définies au présent article sont à appliquer en fonction des taux en vigueur au moment de la souscription et ne sont pas applicables aux opérations de prévoyance collective visées au chapitre Ier du titre IV du livre IV du code des assurances. Dans le cas de versements non programmés aux termes du contrat, ces règles sont à apprécier au moment de chaque versement. » Le chapitre Ier du titre IV du livre IV s'intitule (LEGI) « Dispositions relatives à certaines opérations de prévoyance collective et d'assurance. »
- A132-1-1 : « le taux moyen des emprunts d'Etat sur base semestrielle est déterminé en effectuant la moyenne arithmétique sur les six derniers mois des taux observés sur les marchés primaire et secondaire. Le résultat de la multiplication par 60 % ou 75 % de cette moyenne est dénommé " taux de référence mensuel ". » Suivent l'échelle au pas de 0,25 point, les seuils de −0,1 et de +0,35 point, et le délai de trois mois.

**Lecture**
- **« Souscription »** : non définie. Pour une reconduction annuelle d'un contrat collectif :
  - **(a)** chaque reconduction est une souscription : taux en vigueur à la date de reconduction ;
  - **(b)** la date d'effet initiale.
  - Pour la liquidation d'une rente, la règle des « versements non programmés » ne s'applique pas littéralement (un décès n'est pas un versement).
  - Avis : (a) pour la reconduction (le tarif est refixé), sans texte qui le dise. Non tranché.
- **Exclusion** : elle ne vise que les opérations de L441 (régimes collectifs en points), pas la prévoyance collective en général. Les garanties décès et rentes de L911-1 restent sous A132-1.
- **« Taux moyen » face au TME** : A132-1 (4e alinéa) prend le **plus élevé** des taux d'émission et de marché secondaire ; A132-1-1 prend la **moyenne** des taux observés sur les deux marchés. Les deux formules ne coïncident pas mot à mot, et aucune ne nomme le « TME » publié par la Banque de France. L'égalité avec la série TME est une **hypothèse**, à déclarer comme telle. L'indicateur A132-1 (M85) est une approximation, et le moteur doit l'étiqueter ainsi.

---

# R5 — R343-3, 1° (frais) ; A343-1-1

**Statut** : **vérifié** (mot à mot).

- R343-3, 1° : « Provision mathématique : différence entre les valeurs actuelles des engagements respectivement pris par l'assureur et par les assurés. Pour des contrats faisant intervenir une table de survie ou de mortalité, les montants des provisions mathématiques doivent inclure une estimation des frais futurs de gestion qui seront supportés par l'assureur pendant la période de couverture au-delà de la durée de paiement des primes ou de la date du prélèvement du capital constitutif ; l'estimation de ces frais est égale au montant des chargements de gestion prévus dans les conditions tarifaires de la prime ou du capital constitutif et destinés à couvrir les frais de gestion ; »
- A343-1-1 (texte intégral en vigueur) : « Les provisions mathématiques des contrats d'assurance sur la vie, de capitalisation et d'assurance nuptialité-natalité, à primes périodiques, doivent être calculées en prenant en compte les chargements destinés aux frais d'acquisition dans l'engagement du payeur de primes. La provision résultant du calcul précédent ne peut être négative, ni inférieure à la valeur de rachat du contrat, ni inférieure à la provision correspondant au capital réduit. »

**Lecture**
- Les frais futurs à inclure sont ceux de la période **au-delà de la durée de paiement des primes**, au montant des **chargements de gestion tarifaires**. Pendant le paiement des primes, le texte ne les impose pas.
- A343-1-1 impose la zillmérisation (chargements d'acquisition dans l'engagement de l'assuré) pour les contrats à primes périodiques, et un plancher de zéro.
- Le texte ne dit ni « prime pure » ni « prime d'inventaire », ni « par contrat ». Le plancher porte sur « la provision » d'un contrat (« la valeur de rachat du contrat »), ce qui appuie une **lecture contrat par contrat** : interprétation forte, mais pas littérale.

---

# R6 — PRC (R343-7, 5°) et temporaire décès à prime nivelée (priorité)

**Statut** : **vérifié**.

**Textes lus**
- R343-7, 5° : « Provision pour risques croissants : provision pouvant être exigée pour les opérations d'assurance contre les risques de maladie et d'invalidité et égale à la différence des valeurs actuelles des engagements respectivement pris par l'assureur et par les assurés ; ». R343-7 porte sur « les autres opérations d'assurance » (en tête).
- R343-3 (vie) : aucune PRC parmi ses onze catégories ; 1° (provision mathématique, cité en R5) ; non-cumul : « Un engagement ne peut être provisionné qu'au titre d'une seule des catégories mentionnées au présent article. »
- R321-1, branche 20 « Vie-Décès » : « Toute opération comportant des engagements dont l'exécution dépend de la durée de la vie humaine autre que les activités visées aux branches 22,23 et 26. »

**Lecture**
- La temporaire décès relève de la branche 20 ; ses provisions sont celles de R343-3. La **PRC n'existe pas** pour une opération vie : elle n'est prévue qu'à R343-7, pour la maladie et l'invalidité.
- La croissance du risque avec l'âge d'une temporaire décès à prime nivelée est portée par la **provision mathématique** de R343-3, 1° (différence des valeurs actuelles). Une PRC en plus serait à la fois hors liste et un double provisionnement contraire à la règle de non-cumul de R343-3.
- **Écart à la feuille de route** : l'item (2) de la branche `claude/prc` (« PRC des garanties à prime constante et risque croissant — capital décès individuel à prime nivelée ») n'est pas conforme au texte pour le décès. Il est à reformuler en provision mathématique de la temporaire décès (R343-3, 1°), ou à retirer.
- **Réserve** : une garantie complémentaire d'invalidité attachée à un contrat vie (R321-1, alinéa après la branche 22 ; R321-5) pourrait relever de R343-7, donc d'une PRC. C'est une interprétation non tranchée (voir R9). Elle ne concerne pas le capital décès lui-même.

---

# R7 — Solvabilité II : annexe I, art. 18 et 26 du règlement délégué 2015/35

**Statut** : **non traité ce jour** (EUR-Lex non consulté dans cette consultation).

Reprendre sur EUR-Lex, version française, texte d'origine (JO L 12 du 17.1.2015) et consolidation, avec les modifications du RD 2026/269 (art. 18 § 3 modifié au 30/01/2027, d'après la lecture du cadrage). Points :
- lignes d'activité de l'annexe I pour le capital décès, l'IAD et les rentes de conjoint et d'éducation, dont le cas des « rentes découlant des contrats d'assurance non-vie » ;
- art. 18 (limites du contrat d'une temporaire individuelle à prime garantie) ;
- art. 26 (comportement des preneurs).

---

# R8 — Loi n° 89-1009, art. 7, et revalorisation des rentes après résiliation

**Statut** : art. 7 **non relu ce jour** (lecture du cadrage seulement : « à un niveau au moins égal à celui de la dernière prestation due ou payée avant la résiliation ou le non-renouvellement ») ; CSS L912-3 **vérifié**.

- CSS L912-3, 1er alinéa : la convention, l'accord ou la décision unilatérale de L911-1 qui couvrent sous forme de rentes le décès, l'incapacité ou l'invalidité « organisent également, en cas de changement d'organisme d'assurance […], la poursuite de la revalorisation des rentes en cours de service ». 2e alinéa : en cas de maintien de la garantie décès, « la revalorisation des bases de calcul des différentes prestations relatives à la couverture du risque décès est au moins égale à celle déterminée par le contrat de l'organisme assureur […] qui a fait l'objet d'une résiliation ».
- **Lecture (provisoire)** : l'art. 7, tel que lu au cadrage, garantit un niveau plancher (la dernière prestation), pas une revalorisation future. L912-3 met la **poursuite de la revalorisation** à la charge de l'acte fondateur du régime, qui l'organise, sans désigner l'organisme qui la porte.
  - **(a)** L'organisme résilié ne doit que le montant figé : sa provision en comptes sociaux ne porte pas de revalorisation future, sauf clause contractuelle.
  - **(b)** La revalorisation est due par l'organisme résilié si le contrat la garantit.
  - Le texte renvoie au contrat. C'est une hypothèse contractuelle déclarée, pas une obligation légale propre à l'assureur. **Incertain** tant que l'art. 7 n'est pas relu en entier sur la consolidation.

---

# R9 — Classement de l'IAD ; provision d'une IAD déclarée non reconnue

**Statut** : textes **vérifiés** (R321-1, R321-5) ; classement : **interprétation** ; provision d'une IAD non reconnue : **non trouvé** (aucun texte).

- R321-1, après la branche 22 : « Les branches mentionnées aux 20,21 et 22 comportent la pratique d'assurances complémentaires au risque principal, notamment celles ayant pour objet des garanties en cas de décès accidentel ou d'invalidité. »
- R321-5 : les entreprises agréées en branches 20 et 22 « peuvent être autorisées à réaliser directement, à titre d'assurance accessoire faisant partie d'un contrat d'assurance sur la vie et moyennant paiement d'une prime ou cotisation distincte, des assurances complémentaires contre les risques d'atteintes corporelles incluant l'incapacité de travail professionnelle, de décès accidentel ou d'invalidité à la suite d'accident ou de maladie. »
- **Lecture** :
  - **(a)** l'IAD qui verse **par anticipation le capital décès** (même capital, éteignant la garantie décès) fait partie de l'engagement vie : branche 20, provisions de R343-3 ;
  - **(b)** l'IAD est une garantie complémentaire d'invalidité : branche 20 par R321-1 si elle est accessoire d'un contrat vie, mais avec, pour R321-5, une prime distincte et un risque d'atteinte corporelle, ce qui ouvre la question d'un provisionnement selon R343-7.
  - Avis : (a) quand l'IAD n'est qu'une modalité de paiement anticipé du capital, sans prime distincte. Choix du mainteneur.
- Pour une IAD déclarée non reconnue, aucun texte de calcul : rattachement au même poste que le capital décès déclaré non réglé (M81, PSAP vie), avec une probabilité de reconnaissance déclarée (jugement d'expert).

---

# R10 — ANC 143-10 et 143-11 par analogie pour la PSAP vie

**Statut** : **vérifié** (consolidation ANC).

- 143-9 à 143-11 sont dans la « Section 4- Provision pour sinistres à payer » du **chapitre III** (provisions des autres opérations). 143-9 : « La provision pour sinistres à payer est définie à l'article R.343-7 du code des assurances. » 143-10 : « La provision pour sinistres à payer est calculée exercice par exercice. […] l'évaluation des sinistres connus est effectuée dossier par dossier, le coût d'un dossier comprenant toutes les charges externes individualisables ; elle est augmentée d'une estimation du coût des sinistres survenus mais non déclarés. » 143-11 : « […] complétée, à titre de chargement, par une évaluation des charges de gestion qui, compte tenu des éléments déjà inclus dans les provisions, est suffisante pour liquider tous les sinistres. »
- Le **chapitre II** (vie, art. 142-1 à 142-11) ne contient aucune section sur la PSAP. Le compte 32 et ses sous-comptes (tardifs, frais de gestion des sinistres, ANC 333-4) existent sans règle d'évaluation propre. Seule s'applique l'obligation générale de 141-1 : « Les provisions techniques des entreprises d'assurance doivent être suffisantes pour le règlement intégral de leurs engagements […] ».
- **Lecture confirmée** : l'emploi de 143-10 (dossier par dossier, plus les tardifs) et de 143-11 (chargement) pour la PSAP vie est une **hypothèse déclarée par analogie**, pas une obligation. Le plan de comptes (sous-comptes tardifs et frais de gestion du compte 32) la rend naturelle, et 141-1 en impose le résultat (suffisance), non la méthode.

---

# Lignes proposées pour le registre (à reporter par la session principale)

Colonnes : identifiant ; affirmation ; source précise ; JO et page ; nature ; version citée et texte modificateur ; organismes ; référentiel ; statut ; date de vérification ; URL.

1. `CA-R343-7-4` ; la PSAP des autres opérations comprend « les capitaux constitutifs des rentes non encore mises à la charge de l'entreprise » ; CA R343-7, 4° ; JO à établir ; texte qui fait foi ; en vigueur depuis le 10/06/2024, décret n° 2024-523 du 07/06/2024, art. 1 ; entreprises d'assurance ; comptes sociaux ; vérifié (consolidation LEGI, SHA-256 du XML `95302caf…`) ; 07/11/2026 ; https://www.legifrance.gouv.fr/codes/article_lc/LEGIARTI000049684158
2. `CA-R343-7-5` ; la PRC n'est prévue que pour les opérations contre les risques de maladie et d'invalidité ; R343-7, 5° ; mêmes version, statut et date ; URL idem.
3. `CA-R343-3-NONCUMUL` ; « Un engagement ne peut être provisionné qu'au titre d'une seule des catégories » ; R343-3, avant-dernier alinéa ; décret n° 2019-1437, art. 2, en vigueur depuis le 01/01/2020 ; entreprises d'assurance ; comptes sociaux ; vérifié (consolidation, `4b02b526…`) ; 07/11/2026 ; https://www.legifrance.gouv.fr/codes/article_lc/LEGIARTI000039739686
4. `CA-R343-3-1-FRAIS` ; frais futurs de gestion au-delà de la durée de paiement des primes, au montant des chargements de gestion tarifaires ; R343-3, 1°, 2e phrase ; même version ; vérifié ; 07/11/2026.
5. `CA-A343-1-1` ; zillmérisation des contrats à primes périodiques ; provision ni négative, ni inférieure à la valeur de rachat, ni à la provision du capital réduit ; A343-1-1, alinéas 1 et 2 ; arrêté du 28/12/2015, art. 2, en vigueur depuis le 01/01/2016 ; vérifié (`3149bab1…`) ; 07/11/2026 ; https://www.legifrance.gouv.fr/codes/article_lc/LEGIARTI000031771151
6. `CA-L132-5-AL3` ; revalorisation du capital décès du décès jusqu'à la réception des pièces ou au dépôt à la CDC ; L132-5, 3e alinéa ; loi n° 2014-617, art. 3, en vigueur depuis le 01/01/2016 ; entreprises d'assurance (IP par CSS L932-23) ; comptes sociaux ; vérifié (`16ca6f24…`) ; 07/11/2026 ; https://www.legifrance.gouv.fr/codes/article_lc/LEGIARTI000029098941
7. `CA-R132-3-1` ; taux minimal de revalorisation (moins élevé des deux taux TME au 1er novembre N-1), point de départ ; R132-3-1, 2e alinéa, 1° à 3° ; décret n° 2015-1092, art. 2 ; entreprises d'assurance ; vérifié (`c0adeb99…`) ; 07/11/2026 ; https://www.legifrance.gouv.fr/codes/article_lc/LEGIARTI000031116526
8. `CA-L132-27-2` ; dépôt à la CDC dix ans après la prise de connaissance du décès, libératoire ; temporaire décès exclue pour les décès antérieurs au 01/01/2015 ; L132-27-2, I, alinéas 1 et 6 ; loi n° 2019-486, art. 71 (V), en vigueur depuis le 24/05/2019 ; entreprises d'assurance, IP ; vérifié (`3113e30f…`) ; 07/11/2026 ; https://www.legifrance.gouv.fr/codes/article_lc/LEGIARTI000038611080
9. `MUT-L223-19-1`, `MUT-R223-9`, `MUT-L223-25-4` ; équivalents pour les mutuelles ; vérifiés (empreintes au tableau) ; 07/11/2026.
10. `CSS-L932-23` ; application aux IP des sections 1 et 1 bis du chapitre II du titre III du livre Ier du Code des assurances ; L932-23, 1er alinéa ; loi n° 2023-973, en vigueur depuis le 24/10/2024 ; IP ; vérifié (`705bfb4a…`) ; 07/11/2026.
11. `CSS-L912-3` ; poursuite de la revalorisation des rentes organisée par l'acte de L911-1 en cas de changement d'organisme ; L912-3 ; en vigueur depuis le 24/06/2006 ; texte modificateur à établir ; tous organismes ; vérifié (`e9ecf942…`) ; 07/11/2026.
12. `CA-R321-1-COMPL` et `CA-R321-5` ; garanties complémentaires (décès accidentel, invalidité) des branches 20 à 22 ; vérifiés ; 07/11/2026.
13. `CA-A132-1`, `CA-A132-1-1`, `CA-A132-18`, `CA-A132-18-1` ; extraits ci-dessus ; vérifiés (texte ; la table annexée à A132-18-1 n'est **pas** lue) ; 07/11/2026.
14. `ANC-142-4`, `ANC-142-3`, `ANC-143-10`, `ANC-143-11`, `ANC-223-1-AL2`, `ANC-333-4`, `ANC-141-1` ; extraits ci-dessus ; nature : texte qui fait foi lu sur une consolidation (recueil ANC au 01/01/2025, SHA-256 `0d7fb3c8…9319766`) ; règlement ANC n° 2015-11 et JO à établir ; statut **vérifié (consolidation)** ; 07/11/2026 ; URL du recueil sur anc.gouv.fr à établir.
15. **Incertain** : décret de taux de revalorisation applicable aux IP (équivalent CSS de R132-3-1) — non trouvé dans la copie, incomplète, du CSS.

# Issue proposée (écart à la feuille de route)

- **Titre** : Feuille de route : retirer la PRC du capital décès individuel à prime nivelée (R343-7, 5° ; R343-3)
- **Libellés** : `needs-triage`
- **Corps** :
  > *Rédigé par l'agent regulatory (IA).*
  >
  > La branche `claude/prc`, item (2), prévoit une « PRC des garanties à prime constante et risque croissant — capital décès individuel à prime nivelée ».
  >
  > - R343-7, 5° (en vigueur depuis le 10/06/2024) réserve la PRC aux « opérations d'assurance contre les risques de maladie et d'invalidité ».
  > - La temporaire décès relève de la branche 20 (R321-1) et de R343-3, qui ne connaît pas de PRC et interdit de provisionner un engagement « au titre [de plus] d'une seule des catégories ». La croissance du risque y est portée par la provision mathématique (R343-3, 1°).
  >
  > Proposition : reformuler l'item en « provision mathématique de la temporaire décès à prime nivelée » ou le retirer ; laisser ouverte la question des garanties complémentaires d'invalidité (R321-5).
  >
  > Renvois : #20 (recensement, § 3.3, Q13, R6), #14.

---

# Complément du 7 novembre 2026 (deuxième passe)

> *Rédigé par l'agent regulatory (IA).* Ajout demandé par la session principale. Les sections précédentes ne sont pas modifiées ; les points ci-dessous les complètent et, quand c'est dit, les précisent.

## Sources de la deuxième passe

- **Règlement délégué (UE) 2015/35, texte d'origine** : JO L 12 du 17.1.2015, p. 1, version française. Téléchargé du dépôt CELLAR (`https://publications.europa.eu/resource/celex/32015R0035`, XHTML, en-tête Accept-Language: fra), SHA-256 `3ee43535c674aacec08d4f27262c24119c284ae9e135429e59fa1b45d666d620`. EUR-Lex renvoie une page de connexion à l'outil.
- **Règlement délégué 2015/35, version consolidée en vigueur au 07/11/2026** : `02015R0035-20241114`, version française, téléchargée de CELLAR, SHA-256 `111bbd6d52a7b5ad82515b01b00d5ea3520202aaacd06b993b78a22740fec5bb`.
  - Liste des consolidations obtenue par la requête SPARQL de CELLAR : …20220802, 20241114, 20270130. La version du 30/01/2027 (RD 2026/269) n'est pas encore applicable.
  - La consolidation porte la mention « seulement un outil de documentation » ; elle se cite comme telle, et le texte qui fait foi est celui du JO (origine et actes modificateurs).
- **Code de la mutualité A223-8 et CSS A932-3-11** : consolidation LEGI, copie locale (voir la méthode de la première passe).

## R7 — Solvabilité II (statut : **vérifié** sur le JO d'origine et sur la consolidation au 14/11/2024)

**Art. 55 (lignes d'activité)**. Inchangé depuis l'origine (comparaison du texte d'origine et de la consolidation : identiques).
- § 2 : « L'assignation d'un engagement d'assurance ou de réassurance à une ligne d'activité reflète la nature des risques relatifs à cet engagement. La forme juridique de l'engagement n'est pas nécessairement déterminante pour la nature du risque. »
- § 3 : « les engagements d'assurance santé exercés sur une base technique similaire à celle de l'assurance vie sont assignés aux lignes d'activité de l'assurance vie, et les engagements d'assurance santé exercés sur une base technique similaire à celle de l'assurance non-vie sont assignés aux lignes d'activité de l'assurance non-vie. »
- § 5 : « Lorsqu'un contrat d'assurance ou de réassurance couvre des risques qui relèvent pour certains de l'assurance vie et pour d'autres de l'assurance non-vie, les engagements d'assurance ou de réassurance sont scindés en une partie vie et une partie non-vie. »
- §§ 6 et 7 : scission entre lignes d'activité, et entre santé et autres, « dans la mesure du possible » ou « autant que possible ».

**Annexe I, D. Engagements d'assurance vie** (consolidation au 14/11/2024) :
- « (29) Assurance santé — Engagements d'assurance santé dans les cas où l'activité sous-jacente est exercée sur une base technique similaire à celle de l'assurance vie, autres que les engagements visés à la ligne d'activité 33. »
  - Attention : le JO d'origine (version française) porte « **n'est pas** exercée ». La ligne 29 est marquée ▼M3 dans la consolidation, c'est-à-dire **remplacée par le RD (UE) 2017/669**. **Ne jamais citer la ligne 29 d'après le texte d'origine.**
- « (32) Autre assurance vie — Engagements d'assurance vie autres que les engagements visés aux lignes d'activité 29 à 31, 33 et 34. »
- « (33) Rentes découlant des contrats d'assurance non-vie et liées aux engagements d'assurance santé » ; « (34) Rentes découlant des contrats d'assurance non-vie et liées aux engagements d'assurance autres que les engagements d'assurance santé ».
- Lignes non-vie (2) « Assurance de protection du revenu » : sur une base technique non similaire à celle de l'assurance vie.

**Lecture (lignes d'activité)**
- **Capital décès, collectif et individuel** : engagement vie, sans participation aux bénéfices ni unités de compte → **ligne 32 « Autre assurance vie »**. Avec participation aux bénéfices contractuelle → ligne 30. C'est un point de fait du contrat, à déclarer.
- **Rentes de conjoint et d'éducation** : elles découlent d'une garantie décès, donc d'un **contrat vie**. Les lignes 33 et 34 ne visent que les rentes « découlant des contrats d'assurance non-vie » : elles ne s'appliquent pas. → **ligne 32** (ou 30 si participation). Si la rente est garantie par un contrat non-vie (par exemple une rente accident), ligne 34. **Avis : ligne 32** pour le périmètre v1 ; la nature du contrat porteur est une donnée de la garantie.
- **IAD** :
  - **(a)** paiement anticipé du capital décès : partie de l'engagement vie, ligne 32 ;
  - **(b)** garantie d'invalidité : engagement santé. Sur une base technique vie, ligne 29 ; sur une base non-vie, ligne 2 ; avec scission du contrat (§ 5 et § 7).
  - Le § 2 (« la forme juridique […] n'est pas nécessairement déterminante ») permet (b) même si le contrat est vie. Deux lectures, à porter avec R9 au mainteneur. Avis : (a) quand la prestation est le capital décès lui-même, sans prime distincte.

**Art. 18 (limites du contrat)**, version en vigueur au 07/11/2026 : § 3 inchangé depuis l'origine ; §§ 5 et 6 **remplacés par le RD (UE) 2019/981** (▼M6 ; JO L 161 du 18.6.2019, p. 1).
- § 3 : « Les engagements relatifs à une couverture d'assurance ou de réassurance fournie par l'entreprise d'assurance ou de réassurance après l'une des dates suivantes ne font pas partie du contrat, à moins que l'entreprise ne puisse contraindre le preneur à payer la prime pour ces engagements: (a) la date future à laquelle l'entreprise d'assurance ou de réassurance a un droit unilatéral de résilier le contrat; (b) la date future à laquelle l'entreprise d'assurance ou de réassurance a un droit unilatéral de rejeter les primes à recevoir au titre du contrat; (c) la date future à laquelle l'entreprise d'assurance ou de réassurance a un droit unilatéral de modifier les primes ou les prestations à payer au titre du contrat, de manière à ce que les primes reflètent pleinement les risques. »
- § 3, 3e alinéa : « Toutefois, dans le cas d'engagements d'assurance vie pour lesquels une évaluation individuelle du risque inhérent aux engagements relatifs à la personne assurée par le contrat est effectuée à l'établissement du contrat et ne peut pas être répétée avant de modifier les primes ou les prestations, les entreprises d'assurance et de réassurance évaluent au niveau du contrat si les primes reflètent pleinement le risque, aux fins du point c). » Ce 3e alinéa est modifié au 30/01/2027 par le RD 2026/269 (lecture du cadrage ; non relu ce jour).
- § 5 (en vigueur) : « Les engagements qui ne se rapportent pas aux primes déjà payées ne font pas partie d'un contrat d'assurance ou de réassurance si toutes les conditions suivantes sont remplies: a) le contrat ne prévoit pas d'indemnisation en cas de réalisation d'un événement incertain spécifié affectant la personne assurée; b) le contrat ne prévoit pas de garantie financière des prestations; c) l'entreprise ne peut pas contraindre le preneur à payer la prime future pour ces engagements. »
- § 7 : les primes ne reflètent pleinement les risques « que s'il n'existe aucune circonstance dans laquelle le montant des prestations et des dépenses à payer en vertu du portefeuille dépasse le montant des primes à acquérir ».

**Lecture (temporaire individuelle à prime garantie)** :
- L'assureur n'a, par hypothèse, ni droit de résilier, ni droit de rejeter les primes, ni droit de les modifier : aucune date du § 3 n'est atteinte avant le terme. **La limite du contrat est le terme** ; les primes futures (que l'assuré peut cesser de payer) entrent dans la meilleure estimation, et la résiliation par l'assuré se traite par l'art. 26.
- Le § 5 ne s'applique pas : la temporaire prévoit une indemnisation en cas d'événement incertain affectant l'assuré (condition a non remplie).
- **Collectif annuel résiliable** : l'assureur peut résilier ou refixer le tarif à l'échéance (§ 3, a ou c). La limite est la prochaine échéance, sous réserve du § 7. C'est une lecture du texte appliqué au contrat type, à confirmer contrat par contrat (point de fait).

**Art. 26 (comportement des preneurs)**, inchangé depuis l'origine :
- « Lorsqu'elles déterminent la probabilité de l'exercice, par les preneurs, de leurs options contractuelles, y compris les droits de cessation et de rachat, les entreprises d'assurance et de réassurance procèdent à une analyse du comportement passé des preneurs et à une évaluation prospective de leur comportement attendu. » Éléments a) à d) : profitabilité de l'exercice, situations économiques, décisions de gestion, toute autre circonstance.
- « La probabilité n'est considérée comme indépendante des éléments visés aux points a) à d) que lorsqu'il existe des données empiriques à l'appui d'une telle hypothèse. »
- **Lecture** : la loi de résiliation (cessation du paiement des primes) de la temporaire est une hypothèse **obligatoire** en meilleure estimation. Une loi constante, indépendante de a) à d), n'est admise qu'avec des données empiriques à l'appui. Pour le projet : hypothèse déclarée dans le plan, avec sa justification (jugement d'expert) ; le moteur ne peut pas l'imposer.

## R3 (complément) — A223-8 (mutualité) et A932-3-11 (CSS) (statut : **vérifié**, consolidation LEGI)

| Article | Identifiant LEGI | En vigueur depuis | SHA-256 (16 premiers) |
|---|---|---|---|
| Mutualité A223-8 | LEGIARTI000031797465 | 01/01/2016 | 38a9b48ad476b80d |
| CSS A932-3-11 | LEGIARTI000031796423 | 01/01/2016 | 1070314f14706c52 |

- A223-8, avant-dernier alinéa : « Pour les opérations de rentes viagères, en ce compris celles revêtant un caractère temporaire, et à l'exception des contrats relevant du chapitre II bis du titre II du livre II, **les tarifs et les provisions techniques** déterminés en utilisant les tables mentionnées au b ne peuvent être inférieurs à ceux qui résulteraient de l'utilisation des tables appropriées mentionnées au a. »
- A932-3-11, avant-dernier alinéa : « Pour les rentes viagères, en ce compris celles revêtant un caractère temporaire, et à l'exception des contrats relevant de la section 9 du II du titre III du livre IX, **les tarifs et les provisions techniques** déterminés en utilisant les tables mentionnées au b ne peuvent être inférieurs à ceux qui résulteraient de l'utilisation des tables par sexe appropriées mentionnées au a. »
- Mêmes structures qu'A132-18 : tables homologuées a ou d'expérience certifiées b ; table unique = la plus prudente ; méthode forfaitaire pour les opérations collectives en cas de décès résiliables annuellement.
- Un **A223-8-1** est en vigueur dans le Code de la mutualité (équivalent probable d'A132-18-1) : non lu ce jour. Aucun A932-3-11-1 n'a été trouvé dans la copie, incomplète, du CSS.

**Effet sur R3** :
- Pour les mutuelles et les IP, le texte étend expressément aux **provisions techniques** le plancher des tables a pour les rentes viagères, **temporaires comprises**. Le Code des assurances (A132-18) ne le dit que des tarifs.
- Cela renforce la lecture (a) de R3 (rentes temporaires traitées comme les rentes viagères pour les tables), sans la rendre littérale pour les entreprises d'assurance.
- Écart de rédaction à signaler : A223-8 et A932-3-11 visent « les tarifs et les provisions techniques », A132-18 « le tarif » seulement.

## Source complémentaire : archive globale LEGI

- Téléchargée ce jour : `https://echanges.dila.gouv.fr/OPENDATA/LEGI/Freemium_legi_global_20250713-140000.tar.gz`, 1 171 027 316 octets, SHA-256 `f862b4a2238e11ec3c48ec70f3b1c68bac0bb1985907841666b98608653d4eca`, extraction complète sans erreur (tar=0).
- Extraits : la loi n° 89-1009 (JORFTEXT000000709057), la loi n° 2014-617 (JORFTEXT000029095362) et le CSS (LEGITEXT000006073189). Les incréments jusqu'au 06/11/2026 (copie locale) et l'incrément du 07/11/2026 ont été appliqués.
- Le CSS extrait de l'archive globale compte **33 374 fichiers d'articles, autant que la copie locale** : la copie locale du CSS était donc complète pour la partie codifiée. La réserve « CSS incomplet » de la première passe est levée.

## R8 (complément) — Loi n° 89-1009, art. 7, texte intégral (statut : **vérifié**, consolidation LEGI)

LEGIARTI000006756606, en vigueur depuis le 10/08/1994 (texte modificateur non relevé : à établir), SHA-256 `e310f124cb6f39d4321662eda73521eeea38e0c7660ea5822eb64d28fc78e35d`.

> « Lorsque des assurés ou des adhérents sont garantis collectivement contre les risques portant atteinte à l'intégrité physique de la personne ou liés à la maternité, le risque décès ou les risques d'incapacité ou d'invalidité, la résiliation ou le non-renouvellement du contrat ou de la convention est sans effet sur le versement des prestations immédiates ou différées, acquises ou nées durant son exécution. Le versement des prestations de toute nature se poursuit à un niveau au moins égal à celui de la dernière prestation due ou payée avant la résiliation ou le non-renouvellement, sans préjudice des révisions prévues dans le contrat ou la convention. De telles révisions ne peuvent être prévues à raison de la seule résiliation ou du seul non-renouvellement.
>
> L'engagement doit être couvert à tout moment, pour tous les contrats ou conventions souscrits, par des provisions réprésentées par des actifs équivalents. »

NOTA (LEGI) : « Loi 89-1009 du 31 décembre 1989 art. 10 : les dispositions de l'article 7 sont d'ordre public […] » ; « art. 29 VII : dérogation au second alinéa de l'article 7. » (L'art. 29 n'a pas été lu.)

**Lecture** (précise la section R8 de la première passe) :
- Le texte garantit un **plancher** : la dernière prestation due ou payée. Il réserve les « révisions prévues dans le contrat », qui peuvent jouer à la hausse comme à la baisse, et interdit qu'une révision soit motivée par la seule résiliation.
- Il **n'impose pas** de revalorisation future à l'organisme résilié. Il ne l'exclut pas si le contrat la prévoit. CSS L912-3 (première passe) renvoie la poursuite de la revalorisation à l'acte fondateur du régime en cas de changement d'organisme.
- **(a)** L'organisme résilié provisionne la rente au dernier montant, plus les seules revalorisations contractuellement garanties par son contrat.
- **(b)** Il provisionne en plus une revalorisation future attendue (meilleure estimation), au titre des « révisions prévues dans le contrat » quand elles sont discrétionnaires.
- **Avis** : en comptes sociaux, (a) : le texte n'oblige qu'à ce qui est prévu au contrat, et le plancher suffit au minimum légal. En meilleure estimation, la revalorisation attendue relève des décisions de gestion futures et du comportement attendu (RD art. 23, 26) : hypothèse déclarée. Le texte ne tranche pas ; choix du mainteneur.
- Le 2e alinéa (« couvert à tout moment […] par des provisions ») ne désigne aucune catégorie de provision (même constat que pour l'art. 7-1 sur #14).

## R2 (complément) — Loi n° 2014-617, art. 13 : numéro **non conforme** à l'objet cité (statut : **vérifié**)

- Art. 13 lu (LEGIARTI000031096910, en vigueur depuis le 01/01/2016, modifié par la loi n° 2015-990 du 06/08/2015, art. 140, SHA-256 `bde281059e0203fbdb66fb1a4e774328292f7e45d369f2f4947ed427fda8815e`). C'est une **disposition transitoire**, applicable à la date d'entrée en vigueur de la loi.
  - IV : transfert à l'État des sommes d'assurance vie non réclamées depuis au moins trente ans.
  - V : dépôt à la CDC, « dans l'année qui suit la date d'entrée en vigueur de la présente loi », des sommes non réclamées depuis dix à trente ans, « dans les conditions prévues à l'article L. 132-27-2 du code des assurances ou à l'article L. 223-25-4 du code de la mutualité ».
- La règle permanente du dépôt à dix ans est **L132-27-2**, créé par la loi n° 2014-617, **art. 3** (lien LEGI de la version LEGIARTI000029096777), modifié par la loi n° 2019-486, art. 71 (V). Pour les mutuelles, L223-25-4 est créé par l'art. 4.
- **Constat (écart)** : le recensement (§ 10, R2) cite « loi n° 2014-617, art. 13 » pour le délai et l'effet du dépôt à la CDC. Il faut citer **L132-27-2** (et L223-25-4) ; l'art. 13 n'est qu'une mesure de reprise du stock au 01/01/2016, sans effet sur un calcul à une date d'arrêté de 2026.

## R2 (complément) — Décret de taux applicable aux institutions de prévoyance (statut : **non trouvé**, et lecture **incertaine**)

- Aucun article du CSS (partie codifiée complète, recherche « revalorisation du capital », « connaissance du décès », « emprunts de l'Etat » + « décès », renvoi à R. 132-3-1) ne fixe le taux de revalorisation du capital décès pour les IP.
- Le décret n° 2015-1092 a créé R132-3-1 (art. 2) et R223-9 (art. 3) ; aucun article du CSS n'en porte le lien dans LEGI. Son éventuelle disposition non codifiée n'a pas été lue (texte JORF non consulté).
- Le Code des assurances nomme les IP dans R132-5-5 (conservation d'informations, VI), pas dans R132-3-1.
- **Deux lectures** :
  - **(a)** L932-23 rend L132-5 applicable aux IP, et le « décret en Conseil d'Etat » auquel L132-5 renvoie est R132-3-1, qui s'applique donc aux IP par ce renvoi ;
  - **(b)** L932-23 ne vise que les « dispositions » du Code des assurances qu'il énumère. R132-3-1 n'est pas étendu, et le plancher n'est pas fixé pour les IP faute de décret propre.
- **Avis** : (a), qui donne un sens au renvoi législatif. Pour le moteur : la règle de R132-3-1 comme hypothèse déclarée pour les IP, avec la mention du statut incertain. À lire pour lever le doute : le texte JORF du décret n° 2015-1092 (articles non codifiés).

## Lignes proposées pour le registre (ajouts)

16. `RD-2015-35-ANNEXE-I` ; lignes d'activité 29 à 34 (texte ci-dessus) ; RD 2015/35, annexe I, D ; JO L 12 du 17.1.2015, p. 1 ; ligne 29 remplacée par le RD 2017/669 (JO à relever) ; texte qui fait foi ; version consolidée 02015R0035-20241114 lue (outil de documentation), texte d'origine lu ; tous organismes (Solvabilité II) ; Solvabilité II ; vérifié ; 07/11/2026 ; https://eur-lex.europa.eu/legal-content/FR/TXT/?uri=CELEX:02015R0035-20241114
17. `RD-2015-35-ART-18` ; limites du contrat, §§ 3, 5, 7 ; §§ 5 et 6 remplacés par le RD (UE) 2019/981 (JO L 161 du 18.6.2019, p. 1) ; même statut ; 07/11/2026.
18. `RD-2015-35-ART-26` ; comportement des preneurs ; inchangé depuis l'origine ; vérifié ; 07/11/2026.
19. `RD-2015-35-ART-55` ; lignes d'activité, §§ 2, 3, 5 ; inchangé ; vérifié ; 07/11/2026.
20. `LOI-89-1009-ART-7` ; plancher de la dernière prestation, révisions contractuelles réservées, provisions ; art. 7, alinéas 1 et 2 ; en vigueur depuis le 10/08/1994 ; texte modificateur à établir ; tous organismes ; comptes sociaux ; vérifié (consolidation LEGI, `e310f124…`) ; 07/11/2026 ; https://www.legifrance.gouv.fr/loda/article_lc/LEGIARTI000006756606
21. `LOI-2014-617-ART-13` ; dispositions transitoires (stock au 01/01/2016) ; ne pas citer pour la règle permanente ; vérifié (`bde28105…`) ; 07/11/2026.
22. `MUT-A223-8`, `CSS-A932-3-11` ; plancher des tables a pour les « tarifs et provisions techniques » des rentes viagères, temporaires comprises ; vérifiés ; 07/11/2026.
23. **Incertain** : `CSS-IP-TAUX-REVALO` (taux de revalorisation légale du capital décès pour les IP) ; non trouvé dans le CSS ; lecture (a) proposée.

## Reste après la deuxième passe

- A223-8-1 (mutualité) non lu.
- Texte JORF du décret n° 2015-1092 (dispositions non codifiées) non lu.
- Art. 29 VII de la loi n° 89-1009 (dérogation au 2e alinéa de l'art. 7) non lu.
- RD 2017/669 (acte modificateur de la ligne 29) : référence JO à relever.
- La consolidation de l'Union lue est un outil de documentation ; pour une citation littérale, relire l'acte modificateur au JO (RD 2019/981 pour l'art. 18 ; RD 2017/669 pour la ligne 29).
