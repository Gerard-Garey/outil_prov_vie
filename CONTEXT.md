# Glossaire

Vocabulaire à employer tel quel dans le code, la documentation, les issues et les comptes rendus d'agents. Un terme nouveau ou précisé est ajouté par `architect`.

## Domaine

**À ADAPTER** : un terme par entrée, sa définition, et les synonymes écartés.

- **<terme>** : <définition>. *Ne pas dire* : <synonyme écarté>.

## Organisation du travail

- **Branche de travail** : l'unique branche `claude/…` en cours, au périmètre fermé d'issues, portée par une PR brouillon vers `main`.
- **Correctif rapide** : modification hors périmètre qui laisse les résultats strictement identiques, touche un seul domaine de commit et pas la documentation de fond ; branche temporaire partie de `main`, PR directe.
- **Tableau avant / après** : pour un commit qui change un résultat, une ligne par grandeur modifiée (avant, après, écart, explication).
- **Visa** : approbation d'un tableau avant / après — par le mainteneur pour un résultat final ou un verdict, par `expert` sinon. Sans visa, rien n'est commité.
- **Surface d'impact documentaire** : liste, dans le commit proposé par `coder`, des endroits de la documentation que la modification oblige à rouvrir ; point de départ de `docwriter`.
- **Constat** : défaut du code relevé par un vérificateur, avec gravité (bloquant / majeur / mineur), `fichier:ligne` et mesure exécutée. Conduit à une reprise ou à un arrêt.
- **Question pour `expert`** : doute sur le fond, qui n'est pas un défaut du code ; ne relance pas `coder`.
- **Audit léger** : lecture du diff et des fonctions touchées avec leurs appelants et appelés.
- **Revue finale complète** : lecture de tout `git diff main...HEAD`, batteries complètes et scénarios adverses, avant la sortie du brouillon.
- **Mesure** : commande exécutée et sa sortie, qui fonde une affirmation sur le comportement du code.
- **Consultation** : un appel d'un agent de pilotage ou de fond par la session principale ; se termine par un bloc « Retour » (statut `complet`, `partiel` ou `revue requise`).
- **Routine / jugement** : les deux niveaux d'une consultation d'`architect` ou d'`expert` — fiche de base (Opus, effort `medium`) ou fiche `-approfondi` (Opus, effort `high`) ; voir `docs/agents/routage.md`. Vaut pour `architect` et `expert` seulement : `coder-approfondi` suit d'autres règles (entrée `coder` / `coder-approfondi`).
- **`coder` / `coder-approfondi`** : fiche de réalisation par défaut (Sonnet, effort `high`) et sa variante générée au même corps (Opus, effort `medium`), employée d'office en circuits 1 et 2, ailleurs sur accord du mainteneur au cas par cas ; ce choix n'est pas une escalade au sens de `docs/agents/routage.md` (§ 5) : ni dossier ni plafond chiffré (§ 10, ADR 0002).
- **Escalade** : passage d'une consultation à un niveau supérieur, hausse d'effort (routine → jugement) ou changement de modèle (Opus → Fable), sur un critère observable ; distincte de la **relance ciblée** (même agent, même fiche, retour incomplet) et de la demande d'information.
- **Question** (routage) : la question résiduelle d'une consultation, rattachée à une issue ou à une mission ; unité des plafonds de `docs/agents/routage.md` (§ 5.2) ; la reformuler ne remet pas ses plafonds à zéro.
- **Charte graphique** : `docs/latex/charte_graphique.tex`, préambule et corps d'exemple dont part tout document LaTeX du projet ; préambule repris sans modification hors passages marqués « À ADAPTER » (ADR 0003).
- **Dossier d'escalade** : question résiduelle, contraintes, conclusions établies, sources, tentatives, contradictions et preuve attendue, transmis à la consultation suivante pour éviter une nouvelle revue globale.
