# Conventions de la documentation de fond

Ces conventions s'appliquent au document unique de la documentation de fond, `docs/latex/doc_outil_prov_vie.tex` (`docs/exigences.md`, E3.1 à E3.4). Le vocabulaire est celui de `CONTEXT.md`. Le rédacteur est `docwriter` (`CLAUDE.md`, règle 9).

## 1. Charte et compilation

- Le document part de la charte `docs/latex/charte_graphique.tex` : le **préambule est repris sans modification**, hors du seul bloc adaptable de la charte, borné par `% >>> À ADAPTER : métadonnées du document (page de garde, pied de page, PDF)` et `% <<< À ADAPTER` ; le corps d'exemple de la charte est remplacé par le contenu (ADR 0003 annoté). La comparaison du préambule avec celui de la charte est confiée à un script de contrôle (ADR 0010, point 26), à défaut duquel elle se fait par `diff`, blocs adaptables retirés.
- Valeurs du bloc adaptable : `\datedoc` est une **date figée**, jamais `\today` ; `\statutdoc` vaut `Projet` ou `Final` ; `\titredoc` (pied de page) et `pdftitle` portent le titre court ; `\datedroit` vaut `Sans objet` tant que le document ne cite aucun texte qui fait foi.
- On emploie les macros et environnements de la charte plutôt qu'une mise en forme ad hoc : `\partie`, `\section`, `\subsection`, `encadre`, `\reglement`, `\refl`, `fiche` (rubriques de la fiche méthode, `\Principe` à `\Referentiels` ; de la fiche modèle, `\Cadre` à `\LimitesModele`), `figureH`, `tableH`, `\code`, `\fsp`.
- **Compilation** : pdfLaTeX, trois passes, `-interaction=nonstopmode -halt-on-error`, hors du dépôt (les fichiers auxiliaires ne se versionnent pas). Attendus : code de sortie 0 aux trois passes, aucune ligne commençant par `! `, aucune référence indéfinie, aucun `Overfull`. Avertissements admis : `\headheight is too small` de `fancyhdr` (un par page, hérité de la charte, ADR 0003) et `statuts_sources.tex introuvable` (macro `\src` de la charte, inactive dans ce dépôt, voir § 5).

## 2. Plan du document

Ordre fixe, une partie (`\partie`) par bloc :

1. page de garde, page « Objet du document » (bandeau seul), sommaire ;
2. **Partie I, Présentation** : sections « Périmètre » et « Conventions » ;
3. **Partie II, Architecture** : sections « Package et point d'entrée » et « Quinze modules et leur graphe » (tableau des quinze modules, de leur rôle et des modules que chacun peut appeler, d'après l'ADR 0010, point 1) ;
4. **une partie par module**, dans l'ordre du tableau de l'ADR 0010, point 1 : `outils`, `dictionnaire`, `lecture`, `donnees`, `tables`, `garanties`, `engagement`, `triangle`, `risque_en_cours`, `regles_comptables`, `projection`, `plan`, `rapport`, `simulation`, `calculer_provisions` ; chacune ouvre par la section « Rôle et fonctions du module `<module>` » (rôle, modules qu'il peut appeler, tableau de fonctions), suivie des sections propres au module (fiches de méthode, catalogues) ; la partie `calculer_provisions` a en plus la section « Table des étapes » ;
5. **Partie « Tests »** : batteries, harnais, concordance entre la documentation et le code.

Les éléments d'E3.1 encore absents (partie « cadre par référentiel et par garantie », fiches de méthode, index et traçabilité, bibliographie) s'ajoutent à leur place quand leur contenu existe. `\partie` n'a pas de compteur : un renvoi se fait par `\ref` vers l'étiquette d'une section (`sec:<nom>`), jamais par un numéro de partie écrit à la main.

## 3. Convention de concordance

La batterie `tests/concordance_doc_moteur.R` (en-tête du script : il fait foi) lit les tableaux de fonctions du document et les compare au code. Elle lit le **source** ligne par ligne, d'où ces règles :

- **Marqueur.** Un tableau de fonctions est précédé d'une ligne de commentaire LaTeX seule sur sa ligne :

  ```
  % concordance-fonctions : <module>
  ```

  où `<module>` est l'un des quinze noms de l'ADR 0010, point 1 (écrit tel quel, `_` compris). Toutes les lignes qui suivent le marqueur sont lues, jusqu'à la première ligne qui contient `\end{tabular}`, `\end{longtable}` ou `\end{tabularx}` : le marqueur se place **juste avant** `\begin{tabular}`, sans texte entre les deux. Aucune autre ligne du document ne commence par `% concordance-fonctions`.
- **Première cellule.** Chaque ligne du tableau cite sa fonction dans sa première cellule par `\code{nom()}` ou `\code{nom}` (les `\_` sont acceptés). La première cellule est ce qui précède le premier `&` non échappé de la **ligne du source** ; tout `\code{…}` qu'elle contient est lu comme un nom de fonction. D'où : **une ligne de tableau par ligne du source** (une ligne coupée ferait lire comme fonction un `\code` d'une autre colonne), aucun `\code` dans la ligne d'en-tête ni dans la ligne « Aucune fonction. », aucune signature dans la première cellule (`\code{refuser()}`, jamais `\code{refuser(message, motif)}` : les arguments vont dans la colonne « Arguments »).
- **Un tableau par module**, jamais deux. Un module sans fonction garde son marqueur et un tableau à une seule ligne, `\multicolumn{3}{@{}l@{}}{Aucune fonction.}` : la batterie rend alors « 0 fonction(s) concordante(s) », et le tableau est prêt quand le module reçoit du code.
- **Fonctions recensées** : les fonctions de premier niveau de `R/<module>.R` dont le nom ne commence pas par un point (les auxiliaires à point ne sont pas citées) ; les constantes ne sont pas des fonctions. Chaque `export()` du `NAMESPACE` doit figurer dans un tableau.
- **Écarts relevés** : fonction du code absente du tableau, fonction citée absente du code, fonction citée deux fois, deux tableaux pour un module, module inconnu, module qui a des fonctions sans tableau, fichier de `R/` hors des quinze modules, export non cité. Avec `--strict` (CI), tout écart et l'absence du document font échouer la batterie ; sans `--strict`, les écarts sont des `[AVERT]` et le statut de sortie vaut 0.
- **Forme du tableau de fonctions** (identique pour les quinze modules) : trois colonnes, « Fonction » (`p{3.9cm}`), « Arguments » (`>{\raggedright\arraybackslash}p{3.0cm}`, « Aucun » s'il n'y en a pas), « Rôle » (`p{8.2cm}`, une phrase courte et juste, écrite d'après le code) ; en-tête `\rowcolor{tableheader}` en gras bleu, lignes alternées `\rowcolors{2}{tablerow}{white}`, dans un `center` en `\small`.
- **Table des étapes.** La section « Table des étapes » de la partie `calculer_provisions` reproduit le tableau constant `ETAPES` (colonnes `etape`, `module`, `fonction`, `condition` ; ADR 0010, point 4). Elle ne porte pas encore de marqueur : la batterie ne lit pas encore `ETAPES`, et la convention de lecture se fixera avec elle.

## 4. Rédaction

- Lecteur : un relecteur externe, sans accès au code. Phrases courtes ; tout raisonnement qui fonde une décision figure dans le document.
- Vocabulaire de `CONTEXT.md`, tel quel ; un sigle s'écrit en entier à sa première occurrence, puis en sigle.
- Noms du code (fonctions, modules, colonnes, fichiers) en `\code{…}` dans le texte et les tableaux ; dans les titres de partie et de section, le nom d'un module s'écrit en romain (`Module risque\_en\_cours`).
- Les cinq statuts épistémiques ne se confondent jamais : résultat exact, résultat asymptotique, approximation numérique, constat de simulation, jugement d'expert.
- **Aucun chiffre issu d'une exécution** (E3.4) : les résultats sont dans le rapport figé et la fiche de calcul. Une constante du code se cite d'après le code ; tout autre chiffre se mesure, commande et sortie citées dans le compte rendu.
- Le document décrit ce que fait le code ; un module sans code le dit (« Ce module n'a pas encore de fonction. »).
- Aucune référence fabriquée ; un fait de `docs/recherche/` au statut « incertain » ou « non trouvé » ne se cite pas.
- Typographie : `~:` avant le deux-points, `\fsp;`, `\fsp!`, `\fsp?` ; guillemets `«~…~»` ; pas de tiret cadratin dans le texte ; aucune cellule de tableau vide (« Aucun », « Sans objet ») ; `-{}-` pour un double tiret dans `\code` (`-{}-strict`).

## 5. Points ouverts

- **Citation des textes qui font foi.** La charte cite un texte par `\reglement` ou `\refl` suivis de `\src{ID}`, identifiant d'un registre des sources ; ce dépôt n'a pas de registre, et `\src` n'y imprime rien. La convention de citation (registre ou référence en clair, statut de vérification) se fixe avant la première citation, au plus tard avec la partie « cadre par référentiel et par garantie ».
- **PDF versionné** (E3.1) : emplacement et moment du dépôt du PDF compilé à fixer.
