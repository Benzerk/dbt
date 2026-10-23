# Architecture et décisions (ADR)

[English version](../en/architecture.md)

## Périmètre

Ce dépôt fournit des scripts locaux pour préparer un environnement Python et piloter dbt avec Snowflake depuis Git Bash sous Windows. Il ne décrit pas l'architecture des modèles de données du projet dbt exécuté.

La configuration partagée est chargée par les scripts qui en ont besoin. L'utilisateur active son environnement dans le shell courant, puis lance `make.sh` depuis le répertoire du projet dbt cible. Les chemins du virtualenv, du certificat et des logs sont calculés à partir du dépôt des scripts ; le répertoire de travail reste celui de l'appelant.

## Convention de suivi

Les ADR ci-dessous sont des constats rétrospectifs du code au 2026-10-23, et non la preuve d'une validation historique. Les contextes et conséquences expliquent le fonctionnement actuel ; les motivations d'origine restent à confirmer. Les alternatives mentionnées sont des pistes de comparaison, pas des options dont l'évaluation passée serait attestée.

Pour une nouvelle décision, ajouter un identifiant séquentiel et utiliser le modèle en fin de fichier. Statuts possibles : **proposé**, **accepté**, **rejeté**, **remplacé**, ou **constaté** pour l'existant sans validation historique connue. Si une décision est remplacée, conserver son contenu et ajouter un lien vers son successeur.

## ADR-001 : utiliser Bash et séparer sourcing et exécution

- Statut : constaté.
- Date de documentation : 2026-10-23.
- Références : [activate.sh](../../activate.sh), [deactivate.sh](../../deactivate.sh), [make.sh](../../make.sh).

### Contexte

Le poste cible utilise Git Bash sous Windows. L'activation Python et les variables d'environnement doivent persister dans le shell de l'utilisateur, contrairement aux opérations d'installation ou de traitement dbt.

### Décision observée

Utiliser Bash. Sourcer `config.sh`, `activate.sh` et `deactivate.sh` ; exécuter `install.sh`, `make.sh` et `uninstall.sh` dans des processus distincts. Les scripts refusent le mauvais mode d'invocation.

### Conséquences et alternatives

L'environnement activé reste disponible pour les commandes suivantes. En contrepartie, les scripts sourcés modifient le shell courant et cette solution n'est pas directement portable vers PowerShell ou `sh`. Alternatives possibles : scripts PowerShell natifs ou outil de lancement dédié. Les idiomes Bash sont détaillés dans les guides [français](bash-specifics.md) et [anglais](../en/bash-specifics.md).

## ADR-002 : centraliser la configuration locale

- Statut : constaté.
- Date de documentation : 2026-10-23.
- Référence : [config.sh](../../config.sh).

### Contexte

Plusieurs scripts utilisent les mêmes chemins, la même version Python et les paramètres réseau du poste.

### Décision observée

Regrouper ces valeurs dans `config.sh`. Calculer les chemins depuis le fichier de configuration plutôt que depuis le répertoire courant. Exporter les paramètres de proxy, de certificat, de pip et l'identifiant de connexion Snowflake vers les processus enfants.

### Conséquences et alternatives

Les chemins restent cohérents quel que soit le répertoire d'appel. La configuration reste spécifique au poste et les exports écrasent les valeurs déjà présentes. Elle ne constitue pas un gestionnaire de secrets : ne pas y ajouter de mot de passe, jeton ou clé privée. Alternatives possibles : fichier local non versionné ou valeurs fournies par l'environnement.

## ADR-003 : orchestrer dbt avec des modes explicites

- Statut : constaté.
- Date de documentation : 2026-10-23.
- Référence : [make.sh](../../make.sh).

### Contexte

Les commandes nécessaires diffèrent entre une reconstruction complète, une exécution courante avec tests et une exécution sans tests.

### Décision observée

Centraliser l'enchaînement dans `make.sh`. Le mode par défaut `rebuild` effectue nettoyage, mise à jour des dépendances, parsing, compilation, exécution avec `--full-refresh`, puis tests. `build` lance `dbt run` puis `dbt test` ; `run` ne lance pas les tests. Ces deux derniers modes excluent les modèles matérialisés en vues. Le mode `build` du script n'est donc pas la commande `dbt build`.

L'option `--strict` renforce les contrôles sans changer le mode choisi. La sélection est transmise à la compilation, à l'exécution et aux tests concernés ; les variables JSON ne sont transmises qu'à `dbt run`.

### Conséquences et alternatives

Les séquences sont explicites et réutilisables, mais la reconstruction par défaut peut être coûteuse et `deps --upgrade` peut faire évoluer les dépendances dbt. Exclure les vues suppose qu'elles sont déjà disponibles et à jour. Alternatives possibles : commandes manuelles ou orchestration fondée sur `dbt build`, avec des différences de comportement à évaluer.

## ADR-004 : journaliser chaque opération dbt et arrêter sur son échec

- Statut : constaté.
- Date de documentation : 2026-10-23.
- Références : [make.sh](../../make.sh), [activate.sh](../../activate.sh), [deactivate.sh](../../deactivate.sh).

### Contexte

Une exécution comporte plusieurs commandes ; il faut suivre leur sortie en direct et pouvoir retrouver celle qui a échoué.

### Décision observée

La fonction `run_dbt_operation` duplique les sorties standard et d'erreur vers le terminal et un fichier horodaté avec `tee`. Elle vérifie immédiatement le code de retour de dbt via `PIPESTATUS[0]`, attend une confirmation clavier puis termine le script en cas d'échec.

### Conséquences et alternatives

Les traces sont disponibles par opération, sans masquer un échec dbt derrière le succès de `tee`. L'échec de `tee` lui-même n'est pas contrôlé. L'attente clavier destine ce flux à un usage interactif plutôt qu'à une CI sans adaptation. Les fichiers de logs sont supprimés lors de l'activation et de la désactivation : ce n'est pas un archivage durable. Alternative possible : journalisation et codes de sortie adaptés à un ordonnanceur ou à une CI.

## ADR-005 : vérifier la connexion Snowflake avant les traitements

- Statut : constaté.
- Date de documentation : 2026-10-23.
- Références : [make.sh](../../make.sh), [README](../../README.md).

### Contexte

Les traitements dépendent d'une connexion Snowflake valide. L'authentification Snowflake est distincte de celle de dbt Platform et des opérations SSH vers GitHub.

### Décision observée

Exécuter `dbt debug` en premier dans tous les modes. Pour le SSO navigateur, l'utilisateur configure `authenticator: externalbrowser` dans la sortie active de son profil dbt. Le script ne crée pas ce profil et ne remplace pas cette étape par `dbt login`.

### Conséquences et alternatives

Une erreur de connexion interrompt le flux avant les traitements suivants. Le SSO peut nécessiter une interaction avec le navigateur ; cette méthode n'est pas une stratégie d'authentification automatisée pour la CI. Alternative possible : un mécanisme non interactif approuvé pour l'environnement cible.

## ADR-006 : figer chardet à 5.2.0 pour éviter un warning Requests

- Statut : constaté.
- Date de documentation : 2026-10-23.
- Références : [requirements.txt](../../requirements.txt), [Requests #7284](https://github.com/psf/requests/issues/7284).

### Contexte

Requests peut utiliser `chardet` comme dépendance optionnelle de détection d'encodage lorsqu'il est installé. L'issue #7284 décrit un `RequestsDependencyWarning` à l'import de Requests avec une version de `chardet` hors de la plage prise en charge. Dans le cas rapporté, Requests 2.32.5 attend une version de `chardet` inférieure à 6 ; cette contrainte ne doit pas être généralisée à toutes les versions futures de Requests.

### Décision observée

Figer explicitement `chardet==5.2.0` dans `requirements.txt` afin d'éviter ce warning dans l'environnement du projet, plutôt que de masquer les avertissements. Le commentaire de la dépendance référence l'issue pour conserver la justification du verrouillage.

### Conséquences et alternatives

La version installée de `chardet` est déterministe, mais ses mises à jour ne sont plus automatiques. Réévaluer ce verrouillage lors des mises à jour de Requests ou des dépendances et vérifier l'absence de ce warning dans l'environnement réinstallé avant de le retirer. L'issue explique le problème d'origine ; elle ne prouve pas à elle seule que le contournement reste nécessaire avec chaque nouvelle version de Requests.

Alternatives possibles : utiliser une combinaison de versions compatible plus récente, ou retirer `chardet` et laisser Requests utiliser `charset-normalizer` si aucune autre dépendance ne nécessite `chardet`. Masquer globalement les warnings empêcherait de voir d'autres incompatibilités et n'est pas la solution retenue.

## Modèle pour une nouvelle décision

```markdown
## ADR-NNN : titre de la décision

- Statut : proposé.
- Date : AAAA-MM-JJ.
- Références : liens vers le code, une issue ou une pull request.

### Contexte

Problème, contraintes et critères de choix.

### Décision

Solution retenue et périmètre.

### Conséquences et alternatives

Bénéfices, coûts, risques et options écartées avec leurs raisons.
```