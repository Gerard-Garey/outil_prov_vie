# outil_prov_vie — recalcul des provisions vie et prévoyance

Outil de **validation actuarielle** qui recalcule, à une date d'arrêté déclarée, les provisions des garanties d'assurance vie et de prévoyance assurables en France (v1 : décès et arrêt de travail ; v2 : épargne en euros et en unités de compte ; v3 : retraite, préretraite et indemnités de fin de carrière) à partir d'une base de gestion, sous deux référentiels — comptes sociaux et meilleure estimation Solvabilité II — avec le tableau de passage, la fiche de calcul et le rapport figé. Package R `provie` (moteur, R de base) et application Shiny locale. Le dépôt ne contient **aucune donnée réelle** : la base brute fictive est tirée par le simulateur du package. IFRS 17 et le SCR sont hors périmètre.

Issu du dépôt modèle `Gerard-Garey/Modele_vibe_code` (organisation Claude Code : sous-agents, circuits, règles Git, traçabilité). Règles : `CLAUDE.md` ; cahier des charges : `docs/exigences.md` ; vocabulaire : `CONTEXT.md` ; décisions : `docs/cadrage/`, `docs/adr/` et `docs/feuille-de-route.md` (§ 4).

**État** : cadrage fait (entretiens du 7 novembre 2026) ; aucun code encore. Les deux premières branches de code portent sur les données (dictionnaire de la base, simulateur) puis sur le capital décès (M66).

## Contenu

| Chemin | Rôle |
|---|---|
| `CLAUDE.md` | Règles lues par Claude Code à chaque session : contexte, textes qui font foi, Git et GitHub, architecture, changements de résultats, rigueur, sous-agents, circuits, workflows |
| `docs/exigences.md` | Cahier des charges numéroté (`E<section>.<n>`), issu des entretiens de cadrage |
| `docs/cadrage/2026-11-07-entretien-cadrage.md` | Décisions du mainteneur au cadrage (Q1 à Q35, A1 à A9) et au glossaire (G1 à G22) |
| `docs/recherche/2026-11-07-cadre-provisionnement-vie.md` | Rapport de recherche : textes qui font foi, tables et licences, outillage R, validation actuarielle (statuts vérifié / incertain / non trouvé) |
| `CONTEXT.md` | Glossaire du domaine (personnes, garanties et sinistres, provisions par référentiel, familles de calcul, triangles, tables, hypothèses, plan et méthodes, données, validation, épargne) et de l'organisation |
| `docs/adr/` | Décisions consignées (gabarit `0000-gabarit.md`) |
| `docs/feuille-de-route.md` | Branche de travail en cours, branches suivantes, décisions M du mainteneur |
| `docs/latex/charte_graphique.tex` | Charte graphique des documents LaTeX (pdfLaTeX), reprise de `docu_actu` (ADR 0003 annoté) ; la documentation de fond sera `docs/latex/doc_outil_prov_vie.tex` |
| `.claude/agents/` | Sept sous-agents : `architect` (pilotage), `actuary` et `regulatory` (fond), `coder`, `docwriter` (réalisation), `audit`, `app-review` (vérification) ; variantes `-approfondi` générées par `.claude/outils/fiches_jumelles.sh` |
| `docs/agents/routage.md` | Politique de routage du modèle et de l'effort (ADR 0001, ADR 0002) |
| `.claude/workflows/circuit-technique.js` | Circuit `coder` → batteries → `audit` léger, une reprise au plus, sans commit ni push |
| `.claude/hooks/`, `.claude/settings.json`, `.claude/outils/` | Hooks (plugins, journal des sous-agents), permissions, bilan du journal |
| `.github/` | Modèles d'issue et de PR, CI (« Contrôles du dépôt »), Dependabot, ruleset de `main`, script des libellés |
| `LICENSE` | PolyForm Noncommercial 1.0.0 (préambule bilingue ; les tables et données publiques embarquées gardent leur propre licence, dite dans leur fichier de provenance) |

## Commandes

Plateforme : R 4.3.3 (poste du mainteneur et CI Ubuntu ; les paquets binaires Windows de la série 4.3 sont figés depuis avril 2025, voir le rapport de recherche § C.2). Les batteries et l'application sont créées par les premières branches de code ; les commandes ci-dessous sont celles prévues par `CLAUDE.md` et le cahier des charges.

```bash
Rscript tests/test_unitaires.R                       # batterie unitaire (à créer)
Rscript tests/test_reproductibilite.R                # références de non-régression (à créer ; références produites par la CI seule)
Rscript tests/concordance_doc_moteur.R --strict      # concordance documentation ↔ code (à créer)
Rscript -e 'shiny::runApp("app")'                    # application Shiny locale (à créer)
bash .claude/outils/fiches_jumelles.sh               # régénère les fiches -approfondi après modification d'une fiche de base
bash .claude/outils/fiches_jumelles.sh --verifier    # contrôle des fiches (aussi en CI)
bash .claude/outils/bilan_journal.sh                 # modèle d'IA servi par agent (journal local)
bash .github/creer_labels.sh Gerard-Garey/outil_prov_vie   # libellés d'issues (fait le 7 novembre 2026)
```

## Façon de travailler

- **Une branche de travail à la fois**, au périmètre fermé d'issues, PR brouillon dès la création ; fusion par le mainteneur, par commit de fusion, CI verte.
- **Ceux qui écrivent ne vérifient pas, ceux qui vérifient n'écrivent pas** ; un agent n'entre dans le circuit que si la modification touche son domaine.
- **Toute affirmation sur le code s'adosse à une mesure** exécutée ; tout changement de résultat a son tableau avant / après et son visa (mainteneur pour une provision totale ou un verdict, `actuary` sinon).
- **Audit léger en cours, revue finale complète avant la sortie du brouillon** ; documentation écrite une seule fois, en fin de branche.
- **Les issues ne sont créées qu'avec l'accord du mainteneur** ; les workflows ne commitent, ne poussent et ne créent rien.
- **Avant d'implémenter un poste**, `actuary-approfondi` établit le recensement des méthodes possibles, visé par le mainteneur ; les hypothèses sont toujours déclarées dans le plan, sans valeur par défaut ; rien n'est corrigé en silence dans les données.

Détail : `CLAUDE.md`.

## Routage du modèle et de l'effort

`architect`, `actuary` et `regulatory` tournent sur Opus : effort `medium` pour la routine et `high` pour le jugement (fiches `-approfondi`), Fable réservé à une liste fermée de cas ou à l'accord du mainteneur, avec des plafonds d'escalade (`docs/agents/routage.md`, ADR 0001). `coder` sur Sonnet en effort `high`, `coder-approfondi` sur Opus en effort `medium` (d'office pour les évolutions de fond et les corrections de conformité, ailleurs sur accord) ; `audit` et `docwriter` sur Opus en effort `medium`, la revue finale complète d'`audit` en effort `high` ; `app-review` sur Sonnet en effort `high` (§ 10, ADR 0002). Les critères seront réévalués après les premières consultations réelles, puis à chaque point d'étape d'`architect`.

## Sécurité du dépôt

Dépôt **public**. Réglages appliqués le 7 novembre 2026 par la session de cadrage (`gh api`, décision Q11) : fusion par **commit de fusion seulement** (squash et rebase désactivés), wiki désactivé ; **secret scanning** et **push protection** activés ; alertes et correctifs de sécurité Dependabot activés ; Actions limitées à celles de GitHub, jeton des workflows en lecture seule ; ruleset **« Protection main »** (`.github/ruleset-main.json`) : suppression et force-push interdits, PR obligatoire avec fils résolus, contrôle requis « Contrôles du dépôt » à jour avec `main`, sans contournement. La branche `claude/socle-donnees` (PR #21) ajoute au fichier du ruleset deux contrôles requis, « Tests (R 4.3.3) » (batteries dans `rocker/r-ver:4.3.3` épinglé par digest) et « Documents LaTeX » ; le mainteneur réapplique le ruleset (`gh api`) **après la fusion** de cette PR, pour ne pas bloquer un correctif rapide parti de `main`.
