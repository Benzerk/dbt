# Spécificités Bash du projet

Les scripts de ce dépôt sont écrits pour **Bash**, et sont utilisés depuis Git Bash sous Windows. Ils s'appuient parfois sur des fonctionnalités propres à Bash : ils ne sont donc pas nécessairement compatibles avec `sh`, PowerShell ou d'autres shells.

## Sourcer ou exécuter un script

Un script exécuté démarre dans un processus séparé. Ses changements de variables d'environnement ne peuvent pas modifier le shell appelant. Les scripts se trouvent dans `scripts/` : depuis la racine du dépôt, lancer par exemple `bash ./scripts/install.sh`. Pour dbt, lancer `make.sh` par son chemin absolu depuis le projet cible, comme indiqué dans le [README](../../README.md#run-dbt).

À l'inverse, `source ./scripts/activate.sh` exécute le fichier dans le shell courant. C'est nécessaire pour que l'activation du virtualenv, les `export` de `config.sh` et les `unset` de `deactivate.sh` persistent après le retour du script. `config/config.sh`, `scripts/activate.sh` et `scripts/deactivate.sh` doivent donc être sourcés. Ces chemins relatifs supposent la racine du dépôt ; depuis un autre répertoire, utiliser leur chemin absolu.

Les scripts détectent ce contexte avec `${BASH_SOURCE[0]}` et `$0` : quand ils sont sourcés, le fichier courant diffère du programme lancé. Ils refusent le mauvais mode d'utilisation. Dans un script sourcé, `return` quitte le fichier sans fermer le shell ; dans un script exécuté, `exit` termine le processus.

## Retrouver le répertoire du script

Les scripts chargent la configuration avec une commande de la forme :

```bash
source "$(dirname -- "${BASH_SOURCE[0]}")/../config/config.sh"
```

`BASH_SOURCE[0]` désigne le fichier Bash courant, `dirname` en extrait le répertoire, et `$(...)` exécute cette commande puis insère son résultat. Depuis `scripts/`, `../config/config.sh` retrouve la configuration même si le script est lancé depuis un autre répertoire. Dans `config/config.sh`, `cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P` calcule ensuite un chemin absolu et physique pour la racine du dépôt, un niveau au-dessus de `config/`.

Les guillemets autour des expansions protègent les chemins contenant des espaces. `--` indique aux commandes comme `dirname` ou `cd` que les arguments suivants ne sont pas des options.

## Variables et expansions

- `export NAME=value` définit une variable et la transmet aux programmes lancés ensuite. `unset NAME` la supprime du shell courant.
- `${path%/}` retire un `/` final ; `${version//./}` remplace tous les points. Ce sont des expansions de paramètres Bash, utilisées ici pour construire les chemins de logs et du virtualenv.
- `${VIRTUAL_ENV:-}` fournit une chaîne vide si la variable n'est pas définie. Cela évite une erreur avec `set -u`.
- `$(commande)` capture la sortie standard d'une commande, par exemple `$(date ...)` pour horodater les logs ou `$(ssh-agent -s)` pour récupérer les variables de l'agent SSH.

Les variables ordinaires sont presque toujours entre guillemets, par exemple `"$local_root_dir"`, pour éviter le découpage sur les espaces et l'expansion des jokers. Les arguments sont transmis séparément plutôt qu'assemblés en une chaîne lorsque c'est possible.

## Tests et options

`[[ ... ]]` est le test Bash utilisé principalement dans les scripts ; il permet notamment de tester les chaînes, les chemins et des expressions composées avec `&&` ou `||`. Les formes `[ ... ]` présentes dans les scripts sont aussi des tests de shell, avec une syntaxe plus stricte : espaces autour des crochets et variables protégées par des guillemets.

Les options sont analysées avec une boucle `while` sur `"$#"` (le nombre d'arguments), un `case` sur `"$1"` (l'argument courant), puis `shift` ou `shift 2` pour consommer les arguments. Cette méthode conserve les valeurs comportant des espaces lorsqu'elles sont placées dans un seul argument, comme la sélection dbt.

`make.sh` construit des tableaux Bash pour les options facultatives, par exemple `vars_arg=(--vars "$dbt_vars")`, puis les développe avec `"${vars_arg[@]}"`. Un tableau vide n'ajoute aucun argument ; un tableau non vide transmet chaque élément comme un argument distinct, sans réinterpréter les espaces ou le JSON.

## Codes de retour, pipelines et arrêt sur erreur

Dans `install.sh` et `uninstall.sh`, `set -euo pipefail` active trois garde-fous : arrêt sur certaines commandes en échec (`-e`), erreur en cas de variable non définie (`-u`), et échec d'un pipeline si l'une de ses commandes échoue (`pipefail`). Ces options ne sont pas activées globalement dans les scripts sourcés, car elles modifieraient le comportement du shell de l'utilisateur.

`make.sh` envoie la sortie d'une commande dbt vers `tee` avec un pipeline : `"$@" 2>&1 | tee "$logs_filepath"`. `PIPESTATUS[0]` est un tableau Bash qui conserve le code de retour de la première commande du pipeline ; le script s'en sert pour détecter l'échec de dbt, même si `tee` a réussi.

## Commandes à connaître dans ce dépôt

- `source` charge un autre script dans le shell courant ; `eval` interprète une chaîne comme une commande. `eval "$(ssh-agent -s)"` applique ainsi au shell les affectations produites par `ssh-agent`.
- `read -r` lit une réponse sans traiter les antislashs ; `case` traite les réponses acceptées par le désinstalleur.
- `2>&1` redirige les erreurs vers la sortie standard, afin que `tee` journalise les deux.
- `"${array[@]}"` transmet les éléments d'un tableau comme arguments séparés ; `"$@"` fait de même pour les arguments reçus par une fonction.

Pour modifier les scripts, garder en tête leur contrat d'invocation (sourcé ou exécuté), citer les expansions de chemins et préserver les arguments sous forme de tableau ou de paramètres séparés.