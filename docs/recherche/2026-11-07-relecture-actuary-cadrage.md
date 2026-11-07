# Relecture d'`actuary` du 7 novembre 2026 — cahier des charges et glossaire du cadrage

> Consignation, par la session principale, de la relecture de fond rendue par l'agent `actuary` (consultation de routine, fiche appelée par `expert`, statut `revue requise`) sur `docs/exigences.md` et la section « Domaine » de `CONTEXT.md` à l'état du commit `d606431`, puis de sa validation finale (« validé avec réserves », statut `partiel`) sur l'état `33361b5`. Les décisions du mainteneur qui en découlent sont M61 à M71 (`docs/feuille-de-route.md`, § 4) ; les précisions retenues ont été reportées (commit `57db584` et suivants). Ce document garde la trace des propositions et de leur sort ; il n'est pas une source.

## 1. Synthèse de la relecture

Six points de fond appelaient une décision avant le dictionnaire et le premier recensement, plus une réserve sur une décision du mainteneur :

1. E2.10 se contredisait avec E2.14 et E2.18 : la provision pour égalisation (v1), la PPB, la PRE, la PAF, la provision globale de gestion et la réserve de capitalisation (v2) sont des règles comptables appliquées à un historique ou à l'actif, hors des quatre familles → **M61** (catégorie « règle comptable », combinaison de deux familles, triangle en méthode alternative pour des sinistres déclarés).
2. PPNA, PREC et portabilité n'avaient pas de place → PPNA et PREC en v1 au titre des règles comptables (M61) ; la portabilité ne crée pas de poste (E1.5).
3. Le risque en cours de la meilleure estimation n'apparaissait que sous le double effet → poste pour chaque garantie (E2.14).
4. La liste des défauts mêlait défauts d'extraction et phénomènes réels du portefeuille (déclaration tardive, rupture de cadence) → **M69**.
5. Le triangle des charges supposait des provisions dossier par dossier à chaque arrêté passé, que l'outil doit recalculer en vue à une date → **M65** (nombres et paiements en référence en v1).
6. La provision vraie n'était pas définie → **M70** (espérance conditionnelle sous la loi vraie ; flux simulés pour la couverture ; puissance).

Réserve sur Q32 : l'engagement d'indemnités de fin de carrière est celui de l'employeur, l'organisme inscrit en général un fonds collectif → **M64** (qualification par `regulatory` avant tout calcul ; évaluation de l'engagement de l'employeur comme calcul pour compte).

## 2. Verdicts par exigence (relecture initiale)

| Exigence | Verdict | Motif principal | Sort |
|---|---|---|---|
| E1.1 | à compléter | « provision » seul = comptes sociaux (G2) ; « par dossier » ne vaut que pour la famille « engagement » ; « organisme d'assurance vie ou mixte » exclut mutuelles et institutions de prévoyance ; tables manquantes dans la liste | reporté |
| E1.2 | à compléter | « indépendant » non porté par les articles 48 et 272 ; aucun texte n'impose le recalcul (rapport, § D) | reporté |
| E1.3, E1.6, E1.7, E1.8 | pertinent | — (E1.6 : listes mutualité et CSS à établir ; E1.7 : « boni ou mali » et « charge » renvoient à la provision recalculée) | glossaire aligné |
| E1.4 | à compléter | « date d'évaluation » écarté par le glossaire | reporté (« date d'arrêté ») |
| E1.5 | à compléter | portabilité sans poste ; invalidité absolue et définitive omise | reporté (recensement du capital décès) |
| E2.1 | à compléter | période couverte des prestations et cotisations, assiette, franchise, catégorie d'invalidité, prestations de la sécurité sociale, âge de fin de service | reporté |
| E2.2, E2.8, E2.16, E2.21, E2.26, E2.27, E4.5, E4.6 | pertinent | (E2.8 : millésime des lois de l'ANC à consigner dans la provenance ; E2.16 : mesure d'incertitude par méthode) | E2.16 complétée |
| E2.3 | à compléter | stock de rentes en service antérieur à la fenêtre d'historique ; triangles maigres à la volumétrie de la v1 (puissance des constats à mesurer) | reporté |
| E2.4 | à compléter | séparer défauts d'extraction et phénomènes du portefeuille ; défauts à ajouter (date de saisie antérieure, période couverte, rechute codée en nouveau sinistre, catégorie d'invalidité) ; « sinistre sans prestation » → « sinistre clos sans prestation ni motif » | reporté (M69) |
| E2.5 | à compléter | restituer l'enjeu des lignes refusées ou exclues ; erreur structurelle qui arrête un poste | reporté |
| E2.6 | à compléter | seuls les événements portent une date de saisie ; limite à déclarer | reporté |
| E2.7 | à compléter | loi d'incidence manquante ; 600-4 publie un effectif sur 10 000 entrants, conversion à documenter | reporté |
| E2.9 | à compléter | plusieurs plafonds coexistent ; correspondance poste → plafond par `regulatory` | reporté (puis M63 après la lecture de `regulatory`) |
| E2.10 | **fragile** | voir synthèse, points 1 à 3 | M61 |
| E2.11 | à compléter | modèle semi-markovien ; conjoint survivant et enfant à charge sont des personnes ouvertes par le décès ; retraite, rechute, invalidité absolue et définitive ; décomposition des sorties par cause = hypothèse déclarée | reporté |
| E2.12 | à compléter | période de développement déclarée (année, trimestre, mois) ; diagnostics à lister (facteurs individuels, résidus, tests de Mack) ; triangle des charges (synthèse, point 5) ; origine 0 | reporté (M65) |
| E2.13 | pertinent | « ligne d'activité déclarée » : une ligne d'activité s'affecte au sens de l'annexe I | reporté |
| E2.14 | à compléter | risque en cours de la meilleure estimation pour chaque garantie ; PPNA et PREC à classer ; frais de gestion transverses (ANC 143-11) ; tardifs d'incapacité avec leur passage futur ; rentes d'invalidité à constituer ; la provision pour égalisation n'existe pas en meilleure estimation | reporté |
| E2.15 | à compléter | rente d'éducation : poursuite d'études = hypothèse déclarée ; maintien de la garantie décès : formule explicite ; méthodes à soumettre au recensement (Cape Cod, Benktander, Poisson surdispersé et bootstrap, a priori de Bornhuetter-Ferguson par les décès attendus) ; statut de l'écart-type de Mack | reporté |
| E2.17 | à compléter | ordre de substitution du tableau de passage déclaré, effet croisé restitué ; ligne des hypothèses par défaut ; sortie de la provision pour égalisation ; absence de correction pour volatilité = écart de convention | reporté |
| E2.18 | à compléter | générateur de taux reproduisant la courbe initiale (Hull et White), univers risque neutre, volatilités déclarées = jugement d'expert ; provision mathématique en unités de compte et garanties plancher ; scénario équivalent certain | reporté |
| E2.19 | à compléter | épargne retraite en euros → famille « projection » ; indemnités de fin de carrière à qualifier | reporté (M64) |
| E2.20 | à compléter | « sans valeur par défaut » et « hypothèses par défaut » se télescopent → hypothèses par défaut déclarées dans le plan ; taux du tarif (ANC 142-3) ; dépassement : refus ou signalement ; hypothèses manquantes (incidence, poursuite d'études, structure familiale, décomposition des sorties, revalorisation légale) | reporté (M62, M71) |
| E2.22 | à compléter | même plan aux deux arrêtés ; flux attendus de l'exercice ; sorties observées et attendues par loi avec intervalle ; famille « triangle » | reporté |
| E2.23 | à compléter | provision vraie à définir ; loi vraie différente du modèle de la méthode ; puissance ; flux après l'arrêté | reporté (M70) |
| E2.24 | à compléter | « hypothèse ou méthode » : aligner le glossaire | reporté |
| E2.25 | à compléter | aléa de processus (l'erreur quadratique de prédiction de Mack est la somme de l'erreur d'estimation et de l'aléa de processus) | reporté |
| E2.28 à E2.31 | pertinent (`regulatory`) | capitaux décès : opération vie de R343-3 sans PSAP (rattachement à établir) ; art. 35 « à vérifier » | issue #14 ; levé par `regulatory` |
| E4.1 | à compléter | module des règles comptables | reporté (M61) |
| E4.9 | à compléter | loi vraie couvre le processus d'information ; flux après l'arrêté ; flux aléatoire distinct pour les défauts | reporté |

## 3. Glossaire : propositions et sort

Trente-trois propositions, dont une nouvelle entrée (« Provision vraie ») : Sinistre (rechute), État (états du sinistre distingués de ceux du dossier), Invalidité (entrée directe, catégorie, fin à la retraite), Invalidité en attente (part d'engagement, non un état), Provision d'invalidité en attente (définition), Maintien de la garantie décès (portée à établir), Capital non réclamé (champ et rattachement à établir), Provision pour frais de gestion des sinistres (requalifiée ensuite en chargement de gestion par `regulatory`), Meilleure estimation (brute de réassurance), Limites du contrat (familles « risque en cours » et « projection »), Tableau de passage (ordre de substitution), Famille de calcul (alignée sur E2.10), Modèle multi-états (semi-markovien, bénéficiaires), Loi de maintien (pas de décomposition des sorties), Loi de passage (effectif sur 10 000), Triangle de liquidation (période déclarée), Charge (recalculée par l'outil), Année de développement (origine 0), Exercice (entre deux arrêtés), Boni ou mali (même plan, vue à l'arrêté précédent), Réalisé / attendu (flux attendus, sorties par loi), Hypothèse par défaut (déclarée dans le plan), Taux technique (tarif, règle par poste), Frais (art. 31), Sensibilité (ou une méthode), Modèle de référence (multi-états semi-markovien), Statut (aléa de processus), Défaut de données (phénomènes exclus), Loi vraie (délais, flux après l'arrêté), Provision vraie (nouvelle), Constat de simulation (puissance), Valeur temps des options et garanties (équivalent certain), Scénario économique (risque neutre). **Toutes reportées** (commit `57db584`), sous réserve des décisions M61 à M71.

Références retrouvées par `actuary` : Mack (1993), ASTIN Bulletin 23(2), 213–225 ; Haberman et Pitacco (1999), *Actuarial Models for Disability Insurance*, Chapman & Hall/CRC ; Hull et White (1990), Review of Financial Studies 3(4), 573–592 ; Merz et Wüthrich (2008), CAS E-Forum (pour mémoire). Non relues ce jour : Bornhuetter et Ferguson (1972), England et Verrall (2002), Mack (1994). Hypothèses d'`actuary` (jugement d'expert, non vérifiées) : instabilité de l'écart-type de Mack sur des triangles maigres ; absence de décomposition des sorties par cause dans les lois de l'ANC ; pratique de place du provisionnement du maintien de la garantie décès pour tous les arrêts en cours ; fonds collectif pour les indemnités de fin de carrière.

## 4. Validation finale (état `33361b5`) : réserves et sort

| Réserve | Gravité | Constat | Sort |
|---|---|---|---|
| R1 | majeure | « Famille de calcul » rangeait encore PPNA et PREC dans « risque en cours » ; ADR 0006 les plaçait dans deux modules | corrigé (`CONTEXT.md` ; annotation de l'ADR 0006) |
| R2 | majeure | évaluation de gestion (M68) lue par les « triangles de charges » alors que la charge est recalculée par l'outil ; colonne non datée inutilisable en vue à une date | corrigé : triangle des évaluations de gestion distinct, forme tranchée par le dictionnaire (E2.1, ADR 0008, entrée « Évaluation de gestion ») |
| R3 | majeure | jalon de la PRC (M66) non reporté dans E2.15 et le glossaire | corrigé |
| R4 | majeure | PPNA et PREC face à la provision mathématique de la temporaire décès (opération vie, non-cumul de R343-3) | E2.14 précisée ; issue #14, point 7 |
| R5 | mineure | provision pour frais d'acquisition reportés dans l'annotation de l'ADR 0005 mais ni dans E2.10, ni dans le glossaire, ni dans M61 | corrigé (ajoutée partout) |
| R6 | mineure | tableau de passage sans ligne PPNA et PREC → limites du contrat ; méthodes de départ des règles comptables absentes | corrigé (E2.17, E2.15) |
| R7 | mineure | ADR 0009, point 2, « original conservé dans la fiche » contre M67 | annotation de l'ADR 0009 |
| R8 | mineure | « plafond réglementaire restitué » au singulier (E2.20) | corrigé |
| R9 | mineure | ADR 0008, point 4, sans la puissance | corrigé (section « Réglé après rédaction ») |

Points 7 et 8 proposés pour l'issue #14 (non-cumul PPNA/PREC et provision mathématique vie ; tableau complet poste → provision) : portés en commentaire de l'issue.
