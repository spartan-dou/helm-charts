# Helm Chart Values

Ce fichier décrit les valeurs configurables pour ce chart Helm.

## Configuration

| Clé                               | Valeur Par Défaut          | Description                                                                                               |
|-----------------------------------|----------------------------|-----------------------------------------------------------------------------------------------------------|
| `replicaCount`                    | `1`                        | Nombre de réplicas                                                                                        |

## Image

| Clé                               | Valeur Par Défaut                        | Description                                                                                               |
|-----------------------------------|------------------------------------------|-----------------------------------------------------------------------------------------------------------|
| `image.repository`                | `ghcr.io/jellyfin/jellyfin`              | Répertoire de l'image Docker                                                                              |
| `image.tag`                       | `"10.9.11"`                              | Tag de l'image Docker                                                                                     |
| `image.pullPolicy`                | `IfNotPresent`                           | Politique de récupération de l'image Docker                                                               |

## DLNA

| Clé                               | Valeur Par Défaut          | Description                                                                                               |
|-----------------------------------|----------------------------|-----------------------------------------------------------------------------------------------------------|
| `enableDLNA`                      | `false`                    | Activer le DLNA (peut nécessiter `hostNetwork: true` dans le déploiement)                                 |

## GPU

| Clé                               | Valeur Par Défaut          | Description                                                                                               |
|-----------------------------------|----------------------------|-----------------------------------------------------------------------------------------------------------|
| `gpu.nvidia`                      | `0`                        | Nombre de GPU NVIDIA à allouer                                                                            |

## Service

| Clé                               | Valeur Par Défaut          | Description                                                                                               |
|-----------------------------------|----------------------------|-----------------------------------------------------------------------------------------------------------|
| `service.type`                    | `ClusterIP`                | Type de service (ClusterIP, NodePort, LoadBalancer)                                                       |
| `service.port`                    | `8096`                     | Port exposé par le service                                                                                |


## Persistence

| Clé                               | Valeur Par Défaut          | Description                                                                                               |
|-----------------------------------|----------------------------|-----------------------------------------------------------------------------------------------------------|
| `persistence.config.enabled`      | `false`                    | Activer la persistance pour la configuration                                                              |
| `persistence.config.accessMode`   | `ReadWriteOnce`            | Mode d'accès pour la persistance de la configuration                                                      |
| `persistence.config.size`         | `1Gi`                      | Taille de la persistance pour la configuration                                                            |
| `persistence.config.existingClaim`| `false`                    | Utiliser un PersistentVolumeClaim existant pour la configuration                                          |
| `persistence.config.storageClass` | `""`                       | Classe de stockage pour la persistance de la configuration                                                |
| `persistence.media.enabled`       | `false`                    | Activer la persistance pour les médias                                                                    |
| `persistence.media.path`          | `/data/media`              | Chemin pour les médias                                                                                    |

## Ingress

| Clé                               | Valeur Par Défaut          | Description                                                                                               |
|-----------------------------------|----------------------------|-----------------------------------------------------------------------------------------------------------|
| `ingress.enabled`                 | `false`                    | Activer l'ingress                                                                                         |

## Liveness Probe

| Clé                               | Valeur Par Défaut          | Description                                                                                               |
|-----------------------------------|----------------------------|-----------------------------------------------------------------------------------------------------------|
| `livenessProbe.httpGet.path`      | `/health`                  | Chemin HTTP pour la liveness probe                                                                        |
| `livenessProbe.httpGet.port`      | `8096`                     | Port pour la liveness probe                                                                               |
| `livenessProbe.initialDelaySeconds`| `60`                      | Délai initial pour la liveness probe                                                                      |
| `livenessProbe.periodSeconds`     | `30`                       | Intervalle de temps entre les vérifications de la liveness probe                                          |

## Readiness Probe

| Clé                               | Valeur Par Défaut          | Description                                                                                               |
|-----------------------------------|----------------------------|-----------------------------------------------------------------------------------------------------------|
| `readinessProbe.httpGet.path`     | `/health`                  | Chemin HTTP pour la readiness probe                                                                       |
| `readinessProbe.httpGet.port`     | `8096`                     | Port pour la readiness probe                                                                              |
| `readinessProbe.initialDelaySeconds`| `30`                     | Délai initial pour la readiness probe                                                                     |
| `readinessProbe.periodSeconds`    | `15`                       | Intervalle de temps entre les vérifications de la readiness probe                                         |
