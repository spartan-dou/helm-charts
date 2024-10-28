Pour installer un chart depuis ce dépôt, utilisez la commande suivante :

```bash
kubectl create ns esphome
```

```bash
helm install esphome esphome -f esphome/esphome.yaml --namespace esphome
```

```bash
helm upgrade esphome esphome -f esphome/esphome.yaml --namespace esphome
```
| Paramètre                       | Valeur                           | Description                                                                 |
|---------------------------------|----------------------------------|-----------------------------------------------------------------------------|
| `replicaCount`                  | 1                                | Le nombre de répliques à déployer                                           |
| `image.repository`              | ghcr.io/esphome/esphome          | Référentiel de l'image Docker                                               |
| `image.pullPolicy`              | IfNotPresent                     | Politique de pull de l'image                                                |
| `image.tag`                     | "2024.10.2"                      | Tag de l'image Docker                                                       |
| `podAnnotations`                | {}                               | Annotations à ajouter au pod                                                |
| `podLabels`                     | {}                               | Labels à ajouter au pod                                                     |
| `username`                      | admin                            | Nom d'utilisateur de l'application                                          |
| `password`                      | changeme                         | Mot de passe de l'application                                               |
| `timezone`                      | "Europe/Paris"                   | Fuseau horaire à utiliser                                                   |
| `service.type`                  | ClusterIP                        | Type de service Kubernetes                                                  |
| `service.port`                  | 6052                             | Port du service                                                             |
| `ingress.enabled`               | false                            | Activer ou non l'ingress                                                    |
| `livenessProbe`                 | httpGet path: / port: 6052       | Probe pour vérifier si le conteneur est en vie                              |
| `readinessProbe`                | httpGet path: / port: 6052       | Probe pour vérifier si le conteneur est prêt                                |
| `persistence.enabled`           | false                            | Activer la persistance des données                                          |
| `persistence.accessMode`        | ReadWriteOnce                    | Mode d'accès au volume                                                      |
| `persistence.size`              | 1Gi                              | Taille du volume                                                            |
| `persistence.existingClaim`     | false                            | Utiliser une PersistentVolumeClaim existante                                |
| `persistence.storageClass`      | ""                               | Classe de stockage utilisée pour le volume                                  |
