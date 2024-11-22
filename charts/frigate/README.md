# Frigate Helm Chart

## Introduction

Ce chart déploie Frigate, un logiciel de surveillance vidéo sur Kubernetes en utilisant Helm.

## Configuration

### Paramètres Globaux

| Nom             | Description                                     | Valeur par défaut  |
|-----------------|-------------------------------------------------|--------------------|
| `replicaCount`  | Nombre de réplicas pour la déploiement          | `1`                |
| `timezone`      | Fuseau horaire du conteneur                     | `Europe/Paris`     |

### Image

| Nom                | Description                                 | Valeur par défaut                      |
|--------------------|---------------------------------------------|----------------------------------------|
| `image.repository` | Référentiel d'image Docker                  | `ghcr.io/blakeblackshear/frigate`      |
| `image.pullPolicy` | Politique de récupération de l'image        | `IfNotPresent`                         |
| `image.tag`        | Tag de l'image Docker                       | `0.14.1`                               |
| `image.gpuTag`     | Tag de l'image Docker pour GPU              | `0.14.1-tensorrt`                      |

### Service

| Nom         | Description                           | Valeur par défaut |
|-------------|---------------------------------------|-------------------|
| `service.type` | Type de service Kubernetes         | `ClusterIP`       |
| `service.port` | Port du service Kubernetes         | `5000`            |

### Ingress

| Nom           | Description                         | Valeur par défaut |
|---------------|-------------------------------------|-------------------|
| `ingress.enabled` | Activer l'ingress               | `false`           |

### Service Account

| Nom                | Description                     | Valeur par défaut |
|--------------------|---------------------------------|-------------------|
| `serviceAccount.create` | Créer un service account   | `false`           |

### Coral

| Nom                | Description                     | Valeur par défaut |
|--------------------|---------------------------------|-------------------|
| `coral.enabled`    | Activer Coral TPU               | `false`           |
| `coral.hostPath`   | Chemin hôte pour Coral TPU      | `/dev/bus/usb`    |

### GPU

| Nom                | Description                     | Valeur par défaut |
|--------------------|---------------------------------|-------------------|
| `gpu.nvidia`       | Nombre de GPU Nvidia            | `0`               |

### Mémoire Partagée

| Nom                | Description                     | Valeur par défaut |
|--------------------|---------------------------------|-------------------|
| `shmSize`          | Taille de la mémoire partagée   | `1Gi`             |

### Tmpfs

| Nom                | Description                     | Valeur par défaut |
|--------------------|---------------------------------|-------------------|
| `tmpfs.enabled`    | Activer tmpfs                   | `true`            |
| `tmpfs.sizeLimit`  | Limite de taille tmpfs          | `1Gi`             |

### MQTT

| Nom                | Description                     | Valeur par défaut  |
|--------------------|---------------------------------|--------------------|
| `mqtt.enabled`     | Activer MQTT                    | `false`            |
| `mqtt.host`        | Hôte du serveur MQTT            | `mqtt.server.com`  |
| `mqtt.port`        | Port du serveur MQTT            | `1883`             |
| `mqtt.username`    | Nom d'utilisateur MQTT          | `test`             |
| `mqtt.password`    | Mot de passe MQTT               | `test`             |

### Persistence

| Nom                | Description                                      | Valeur par défaut |
|--------------------|--------------------------------------------------|-------------------|
| `persistence.config.enabled`    | Activer la persistance de la config  | `false`           |
| `persistence.config.accessMode` | Mode d'accès de la config            | `ReadWriteOnce`   |
| `persistence.config.size`       | Taille du volume de config           | `100Mi`           |
| `persistence.config.storageClass` | Classe de stockage de la config   | `""`              |
| `persistence.config.existingClaim` | Claim existant pour la config   | `false`           |
| `persistence.media.enabled`     | Activer la persistance des médias    | `false`           |
| `persistence.media.accessMode`  | Mode d'accès des médias              | `ReadWriteOnce`   |
| `persistence.media.size`        | Taille du volume des médias          | `10Gi`            |
| `persistence.media.storageClass` | Classe de stockage des médias      | `""`              |
| `persistence.media.existingClaim` | Claim existant pour les médias    | `false`           |
| `persistence.data.enabled`      | Activer la persistance des données   | `false`           |
| `persistence.data.accessMode`   | Mode d'accès des données             | `ReadWriteOnce`   |
| `persistence.data.size`         | Taille du volume des données         | `10Gi`            |
| `persistence.data.storageClass` | Classe de stockage des données      | `""`              |
| `persistence.data.existingClaim` | Claim existant pour les données    | `false`           |

### Probes

| Nom                       | Description                                     | Valeur par défaut |
|---------------------------|-------------------------------------------------|-------------------|
| `liveness.initialDelaySeconds` | Délai initial de la sonde de vivacité    | `60`              |
| `liveness.failureThreshold`    | Seuil d'échec de la sonde de vivacité    | `5`               |
| `liveness.timeoutSeconds`      | Timeout de la sonde de vivacité           | `10`              |
| `readiness.initialDelaySeconds` | Délai initial de la sonde de préparation | `60`              |
| `readiness.failureThreshold`    | Seuil d'échec de la sonde de préparation | `5`               |
| `readiness.timeoutSeconds`      | Timeout de la sonde de préparation       | `10`              |
| `startup.failureThreshold`      | Seuil d'échec de la sonde de démarrage    | `30`              |
| `startup.periodSeconds`         | Période de la sonde de démarrage          | `10`              |

