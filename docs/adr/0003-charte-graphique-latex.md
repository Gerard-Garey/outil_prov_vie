---
status: accepted
date: 2026-10-27
---

# Charte graphique LaTeX du mainteneur versionnée sous `docs/latex/charte_graphique.tex`, neutralisée, point de départ obligé de tout document LaTeX du projet

## Contexte

Le modèle de dépôt n'avait aucune règle de mise en forme pour les documents LaTeX qu'un projet dérivé produit (documentation de fond, notes techniques). Le 27 octobre 2026, le mainteneur a fourni sa charte graphique LaTeX, le fichier `charte_usp.tex`, écrit pour la documentation technique d'un outil de calibrage USP (Solvabilité II), et a demandé de l'intégrer au dossier `docs` du dépôt en la renommant.

La charte est un document LaTeX complet : un préambule qui fixe la mise en forme (palette, titres, en-têtes et pieds, encadrés, fiches, tableaux, page de garde) et un corps qui montre chaque élément une fois. Ses caractéristiques, relevées dans la version versionnée (`docs/latex/charte_graphique.tex`, 788 lignes à `6db61ca`) :

- moteur pdfLaTeX (en-tête, lignes 10-11) ;
- compatibilité annoncée avec des distributions anciennes (MiKTeX 2.9, TeX Live 2012 et suivantes), sans crochet du noyau récent : `atbegshi` tient lieu de `\AddToHook` (ligne 34), et le fichier ne contient ni `\AddToHook`, ni `\IfFormatAtLeastTF`, ni `\DocumentMetadata` (`grep`) ;
- treize packages retirés (en-tête, lignes 8-9) : babel-french, caption, csquotes, enumitem, float, mdframed, newtxtext, pdflscape, tikz, titlesec, tocloft, remplacés par du code de préambule, par d'autres packages (`tgtermes` et `txtt`, `framed`, `lscape`, `atbegshi`) ou, pour csquotes, par la saisie directe des guillemets ; dsfont et mathrsfs, retirés parce que non utilisés ; le tableau « Packages remplacés » du corps (section de ce nom, lignes 746-776) donne le remplacement de chacun.

Ce retrait de packages et la compatibilité ancienne viennent de la charte fournie : la neutralisation (décision, point 2) n'a pas touché à la mise en forme du préambule.

Mesures de compilation (TeX Live de la session cloud, `pdflatex -interaction=nonstopmode -halt-on-error`, trois passes) :

| Fichier | Code de sortie | Erreurs | `\headheight is too small` | Underfull hbox | Pages |
|---|---|---|---|---|---|
| `charte_usp.tex` (original), mesure de la session principale | 0 | 0 | 10 | 1 | 11 |
| `charte_graphique.tex` (neutralisée), mesure de la session principale | 0 | 0 | 10 | 0 | 11 |
| `charte_graphique.tex`, remesurée par `architect` (pdfTeX 1.40.25, TeX Live 2023/Debian) | 0 aux trois passes | 0 | 10 | 0 | 11 (184 286 octets) |

Les dix avertissements `\headheight is too small` sont attendus : le préambule laisse `\headheight` à 12 pt et laisse `fancyhdr` l'agrandir, comme dans le document source (commentaire des lignes 16-18). La compatibilité avec MiKTeX 2.9 et TeX Live 2012 n'a pas été mesurée : seule une TeX Live 2023 l'a été. L'original n'est pas versionné ; sa mesure n'a pas été refaite.

## Décision

Arrêtée par le mainteneur le 27 octobre 2026, par choix entre des options que la session principale lui a proposées :

1. **Emplacement et nom** : `docs/latex/charte_graphique.tex`.
2. **Contenu, « Neutraliser »** : mise en forme du préambule inchangée ; exemples propres à l'outil d'origine remplacés par des textes génériques ; passages propres au projet marqués « À ADAPTER » (dans le préambule : métadonnées du document, lignes 56-61, et intitulés des rubriques des fiches, ligne 319).
3. **Livraison** : branche partie de `main` (`claude/charte-latex`) et pull request (#7).
4. **Mentions** :
   - `README.md`, tableau « Contenu » : une ligne pour `docs/latex/charte_graphique.tex` ;
   - `CLAUDE.md`, section « Rigueur » : « tout document LaTeX du projet part de la charte `docs/latex/charte_graphique.tex` (préambule repris sans modification hors passages marqués « À ADAPTER », corps d'exemple remplacé par le contenu) et emploie ses macros et environnements plutôt qu'une mise en forme ad hoc ; il se compile avec pdfLaTeX » ;
   - fiche `docwriter` : même règle, avec la liste des macros et environnements de la charte et la sortie de compilation pdfLaTeX dans son compte rendu.
5. **Consignation et revue** : le même jour, sur proposition de la session, le mainteneur a demandé le présent ADR et jugé un `/code-review` non nécessaire pour cette PR, qui ne contient pas de code.
6. **Portée de la règle** : la rédaction initiale (« préambule repris sans modification ») interdisait de renseigner les passages « À ADAPTER » du préambule (métadonnées, lignes 56-61 ; titre PDF, ligne 64 ; intitulés des rubriques, ligne 319). Le mainteneur a retenu le 27 octobre 2026, sur proposition de la session, « préambule repris sans modification hors passages marqués « À ADAPTER » », dans `CLAUDE.md`, la fiche `docwriter`, le README et `CONTEXT.md`.
7. **Suites** : le même jour, le mainteneur a fait ouvrir #8 (compilation de la charte en CI) et #9 (script de contrôle du préambule recopié), et a laissé ouverte la question du versionnement des PDF.

## Options écartées

Les raisons ci-dessous sont celles que la session a exposées au moment du choix, sauf mention contraire ; le mainteneur n'a pas motivé ses choix au-delà de l'option retenue.

- **`docs/charte_graphique.tex`** (racine de `docs/`) : un sous-dossier dédié accueille les autres fichiers LaTeX du projet.
- **`docs/modele_document.tex`** : même emplacement à la racine de `docs/`, donc même raison pour l'emplacement ; pour le nom, aucune raison consignée.
- **Copie à l'identique** de `charte_usp.tex` : le dépôt est un modèle générique, dont les projets dérivés ne portent pas sur le calibrage USP ; les exemples de l'outil d'origine y auraient été hors sujet, d'où la neutralisation.
- **Séparation en un `.sty`** chargé par `\usepackage{charte}`, plus un document d'exemple : écartée par le mainteneur, sans raison consignée. Conséquence de ce choix, relevée par `architect` (Conséquences) : le préambule est recopié dans chaque document au lieu d'être partagé.
- **Push sur la branche cloud assignée, PR ouverte par le mainteneur** : écartée par le mainteneur, sans raison consignée ; l'option retenue suit la règle de `CLAUDE.md` (« Git et GitHub » : toute modification passe par une branche et une pull request).

## Conséquences

- Fichiers : `docs/latex/charte_graphique.tex` (nouveau) et `README.md` (commit `dc32cb5`, `docs:`) ; `CLAUDE.md` et `.claude/agents/docwriter.md` (commit `6db61ca`, `claude:`) ; le présent ADR.
- Effet sur les résultats : aucun (aucun code ni aucune référence touchés).
- Fichiers produits par la compilation : `.aux`, `.log`, `.out` et `.toc`, les seuls auxiliaires que produit la charte (mesure ci-dessus), sont déjà ignorés (`.gitignore`, section « LaTeX : fichiers auxiliaires », depuis `fdb3fd4`) ; le PDF ne l'est pas. Versionner ou non les PDF des documents du projet n'est pas décidé.
- Ce qui reste à faire :
  - **compilation en CI** (#8) : aucun job ne compile la charte ni un document qui en part (`.github/workflows/ci.yml`, job « Contrôles du dépôt », plafonné à cinq minutes) ; une régression du préambule ne serait vue qu'à la compilation locale ;
  - **contrôle du préambule recopié** (#9) : la règle « préambule repris sans modification » n'a pas de script de contrôle, alors qu'un contrôle récurrent en appelle un (`CLAUDE.md`, principe 7 des workflows) ; un tel script comparerait le préambule de chaque document LaTeX du projet à celui de la charte ;
  - **`docwriter`** : chemin, format et conventions de la documentation de fond restent « À ADAPTER » dans sa fiche (ligne 9) ; la règle LaTeX ne s'applique que si un projet dérivé choisit LaTeX.
- Ce que l'ADR ne règle pas :
  - **versionnement des PDF** : laissé ouvert par le mainteneur ; chaque projet dérivé le tranche ;
  - **propagation** : le préambule étant recopié, une évolution de la charte n'atteint pas les documents existants ; leur mise à jour reste manuelle ;
  - **compatibilité ancienne** : annoncée par la charte, non mesurée sur MiKTeX 2.9 ni sur TeX Live 2012.

Issues : #8, #9 (suites ; PR #7, branche `claude/charte-latex`, ouverte à la demande du mainteneur hors branche de travail).
