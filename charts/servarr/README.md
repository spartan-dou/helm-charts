

# Structure recommandée pour les repertoires:

data
├── torrents
│  ├── movies
│  ├── music
│  └── tv
└── media
    ├── movies
    ├── music
    └── tv

**RDTClient**
/data/torrents

**Sonarr**
/data/media/tv
/data/torrents/tv

**Radarr**
/data/media/movies
/date/torrents/movies

**Lidarr**
/data/media/music
/data/torrents/music

**Jellyfin**
/data/media

## Configuration Générale

| Clé                     | Valeur Par Défaut | Description                                    |
|-------------------------|-------------------|------------------------------------------------|
| `persistence.storageClass` | `""`              | Classe de stockage pour la persistance         |
| `ingress.enabled`       | `false`            | Activer l'ingress                              |
| `postgresql.enabled`    | `false`            | Activer PostgreSQL                             |
| `postgresql.storageClass` | `""`              | Classe de stockage pour PostgreSQL             |
| `postgresql.auth.username` | `admin`          | Nom d'utilisateur PostgreSQL                   |
| `postgresql.auth.password.admin` | `changeme` | Mot de passe pour l'admin                      |
| `postgresql.auth.password.radarr` | `changeme` | Mot de passe pour Radarr                       |
| `postgresql.auth.password.sonarr` | `changeme` | Mot de passe pour Sonarr                       |
| `postgresql.auth.password.prowlarr` | `changeme` | Mot de passe pour Prowlarr                     |
| `postgresql.auth.password.lidarr` | `changeme` | Mot de passe pour Lidarr                       |
| `serviceAccount.create` | `false`            | Créer un compte de service                     |

## Radarr

| Clé                    | Valeur Par Défaut             | Description                                    |
|------------------------|-------------------------------|------------------------------------------------|
| `radarr.enabled`       | `false`                       | Activer Radarr                                 |
| `radarr.replicaCount`  | `1`                           | Nombre de réplicas                             |
| `radarr.image`         | `lscr.io/linuxserver/radarr`  | Image de Radarr                                |
| `radarr.tag`           | `"5.9.1.9070-ls235"`          | Tag de l'image de Radarr                       |
| `radarr.env.PUID`      | `"1000"`                      | ID utilisateur (PUID)                          |
| `radarr.env.PGID`      | `"1000"`                      | ID groupe (PGID)                               |
| `radarr.env.UMASK`     | `"002"`                       | Umask                                          |
| `radarr.env.TZ`        | `"Europe/Paris"`              | Fuseau horaire                                 |
| `radarr.persistence.enabled` | `false`                | Activer la persistance                         |
| `radarr.persistence.path` | `/config`                 | Chemin de configuration                        |
| `radarr.persistence.size` | `1Gi`                     | Taille de la persistance                       |
| `radarr.data.path`     | `/data`                      | Chemin des données                             |
| `radarr.data.hostPath` | `/data`                      | Chemin d'hôte des données                      |
| `radarr.port`          | `7878`                       | Port de Radarr                                 |
| `radarr.service.type`  | `ClusterIP`                  | Type de service                                |
| `radarr.service.port`  | `7878`                       | Port de service                                |
| `radarr.livenessProbe.httpGet.path` | `/`            | Chemin HTTP de la liveness probe               |
| `radarr.livenessProbe.httpGet.port` | `7878`         | Port de la liveness probe                      |
| `radarr.livenessProbe.initialDelaySeconds` | `60`    | Délai initial de la liveness probe             |
| `radarr.livenessProbe.periodSeconds` | `30`          | Période de la liveness probe                   |
| `radarr.readinessProbe.httpGet.path` | `/`           | Chemin HTTP de la readiness probe              |
| `radarr.readinessProbe.httpGet.port` | `7878`        | Port de la readiness probe                     |
| `radarr.readinessProbe.initialDelaySeconds` | `30`   | Délai initial de la readiness probe            |
| `radarr.readinessProbe.periodSeconds` | `15`         | Période de la readiness probe                  |

## Sonarr

| Clé                    | Valeur Par Défaut             | Description                                    |
|------------------------|-------------------------------|------------------------------------------------|
| `sonarr.enabled`       | `false`                       | Activer Sonarr                                 |
| `sonarr.replicaCount`  | `1`                           | Nombre de réplicas                             |
| `sonarr.image`         | `lscr.io/linuxserver/sonarr`  | Image de Sonarr                                |
| `sonarr.tag`           | `"4.0.9.2244-ls252"`          | Tag de l'image de Sonarr                       |
| `sonarr.env.PUID`      | `"1000"`                      | ID utilisateur (PUID)                          |
| `sonarr.env.PGID`      | `"1000"`                      | ID groupe (PGID)                               |
| `sonarr.env.UMASK`     | `"002"`                       | Umask                                          |
| `sonarr.env.TZ`        | `"Europe/Paris"`              | Fuseau horaire                                 |
| `sonarr.persistence.enabled` | `false`                | Activer la persistance                         |
| `sonarr.persistence.path` | `/config`                 | Chemin de configuration                        |
| `sonarr.persistence.size` | `1Gi`                     | Taille de la persistance                       |
| `sonarr.data.path`     | `/data`                      | Chemin des données                             |
| `sonarr.data.hostPath` | `/data`                      | Chemin d'hôte des données                      |
| `sonarr.port`          | `8989`                       | Port de Sonarr                                 |
| `sonarr.service.type`  | `ClusterIP`                  | Type de service                                |
| `sonarr.service.port`  | `8989`                       | Port de service                                |
| `sonarr.livenessProbe.httpGet.path` | `/`            | Chemin HTTP de la liveness probe               |
| `sonarr.livenessProbe.httpGet.port` | `8989`         | Port de la liveness probe                      |
| `sonarr.livenessProbe.initialDelaySeconds` | `60`    | Délai initial de la liveness probe             |
| `sonarr.livenessProbe.periodSeconds` | `30`          | Période de la liveness probe                   |
| `sonarr.readinessProbe.httpGet.path` | `/`           | Chemin HTTP de la readiness probe              |
| `sonarr.readinessProbe.httpGet.port` | `8989`        | Port de la readiness probe                     |
| `sonarr.readinessProbe.initialDelaySeconds` | `30`   | Délai initial de la readiness probe            |
| `sonarr.readinessProbe.periodSeconds` | `15`         | Période de la readiness probe                  |

## Prowlarr

| Clé                    | Valeur Par Défaut             | Description                                    |
|------------------------|-------------------------------|------------------------------------------------|
| `prowlarr.enabled`     | `false`                       | Activer Prowlarr                               |
| `prowlarr.replicaCount` | `1`                          | Nombre de réplicas                             |
| `prowlarr.image`       | `lscr.io/linuxserver/prowlarr` | Image de Prowlarr                             |
| `prowlarr.tag`         | `"1.23.1.4708-ls84"`          | Tag de l'image de Prowlarr                     |
| `prowlarr.env.PUID`    | `"1000"`                      | ID utilisateur (PUID)                          |
| `prowlarr.env.PGID`    | `"1000"`                      | ID groupe (PGID)                               |
| `prowlarr.env.UMASK`   | `"002"`                       | Umask                                          |
| `prowlarr.env.TZ`      | `"Europe/Paris"`              | Fuseau horaire                                 |
| `prowlarr.persistence.enabled` | `false`              | Activer la persistance                         |
| `prowlarr.persistence.path` | `/config`               | Chemin de configuration                        |
| `prowlarr.persistence.size` | `1Gi`                   | Taille de la persistance                       |
| `prowlarr.port`        | `9696`                       | Port de Prowlarr                               |
| `prowlarr.service.type` | `ClusterIP`                 | Type de service                                |
| `prowlarr.service.port` | `9696`                      | Port de service                                |
| `prowlarr.livenessProbe.httpGet.path` | `/`          | Chemin HTTP de la liveness probe               |
| `prowlarr.livenessProbe.httpGet.port` | `9696`       | Port de la liveness probe                      |
| `prowlarr.livenessProbe.initialDelaySeconds` | `60`  | Délai initial de la liveness probe             |
| `prowlarr.livenessProbe.periodSeconds` | `30`        | Période de la liveness probe                   |
| `prowlarr.readinessProbe.httpGet.path` | `/`         | Chemin HTTP de la readiness probe              |
| `prowlarr.readinessProbe.httpGet.port` | `9696`      | Port de la readiness probe                     |
| `prowlarr.readinessProbe.initialDelaySeconds` | `30` | Délai initial de la readiness probe            |
| `prowlarr.readinessProbe.periodSeconds` | `15`       | Période de la readiness probe                 |

## Lidarr

| Clé                    | Valeur Par Défaut             | Description                                    |
|------------------------|-------------------------------|------------------------------------------------|
| `lidarr.enabled`       | `false`                       | Activer Lidarr                                 |
| `lidarr.replicaCount`  | `1`                           | Nombre de réplicas                             |
| `lidarr.image`         | `lscr.io/linuxserver/lidarr`  | Image de Lidarr                                |
| `lidarr.tag`           | `"2.6.4.4402-ls13"`           | Tag de l'image de Lidarr                       |
| `lidarr.env.PUID`      | `"1000"`                      | ID utilisateur (PUID)                          |
| `lidarr.env.PGID`      | `"1000"`                      | ID groupe (PGID)                               |
| `lidarr.env.UMASK`     | `"002"`                       | Umask                                          |
| `lidarr.env.TZ`        | `"Europe/Paris"`              | Fuseau horaire                                 |
| `lidarr.persistence.enabled` | `false`                | Activer la persistance                         |
| `lidarr.persistence.path` | `/config`                 | Chemin de configuration                        |
| `lidarr.persistence.size` | `1Gi`                     | Taille de la persistance                       |
| `lidarr.port`          | `8686`                       | Port de Lidarr                                 |
| `lidarr.service.type`  | `ClusterIP`                  | Type de service                                |
| `lidarr.service.port`  | `8686`                       | Port de service                                |
| `lidarr.livenessProbe.httpGet.path` | `/`            | Chemin HTTP de la liveness probe               |
| `lidarr.livenessProbe.httpGet.port` | `8686`         | Port de la liveness probe                      |
| `lidarr.livenessProbe.initialDelaySeconds` | `60`    | Délai initial de la liveness probe             |
| `lidarr.livenessProbe.periodSeconds` | `30`          | Période de la liveness probe                   |
| `lidarr.readinessProbe.httpGet.path` | `/`           | Chemin HTTP de la readiness probe              |
| `lidarr.readinessProbe.httpGet.port` | `8686`        | Port de la readiness probe                     |
| `lidarr.readinessProbe.initialDelaySeconds` | `30`   | Délai initial de la readiness probe            |
| `lidarr.readinessProbe.periodSeconds` | `15`         | Période de la readiness probe                  |

## Recyclarr

| Clé                    | Valeur Par Défaut             | Description                                    |
|------------------------|-------------------------------|------------------------------------------------|
| `recyclarr.enabled`    | `false`                       | Activer Recyclarr                              |
| `recyclarr.image`      | `ghcr.io/recyclarr/recyclarr` | Image de Recyclarr                             |
| `recyclarr.tag`        | `"7.2"`                       | Tag de l'image de Recyclarr                    |
| `recyclarr.cron`       | `"@daily"`                    | Planification cron                             |
| `recyclarr.env.PUID`   | `"1000"`                      | ID utilisateur (PUID)                          |
| `recyclarr.env.PGID`   | `"1000"`                      | ID groupe (PGID)                               |
| `recyclarr.env.UMASK`  | `"002"`                       | Umask                                          |
| `recyclarr.env.TZ`     | `"Europe/Paris"`              | Fuseau horaire                                 |
| `recyclarr.persistence.enabled` | `false`             | Activer la persistance                         |
| `recyclarr.persistence.path` | `/config`              | Chemin de configuration                        |
| `recyclarr.persistence.size` | `1Gi`                  | Taille de la persistance                       |

## FlareSolverr

| Clé                    | Valeur Par Défaut             | Description                                    |
|------------------------|-------------------------------|------------------------------------------------|
| `flaresolverr.enabled` | `false`                       | Activer FlareSolverr                           |
| `flaresolverr.replicaCount` | `1`                      | Nombre de réplicas                             |
| `flaresolverr.image`   | `ghcr.io/flaresolverr/flaresolverr` | Image de FlareSolverr                     |
| `flaresolverr.tag`     | `"v3.3.21"`                   | Tag de l'image de FlareSolverr                 |
| `flaresolverr.env.TZ`  | `"Europe/Paris"`              | Fuseau horaire                                 |
| `flaresolverr.env.PROMETHEUS_ENABLED` | `true`        | Activer Prometheus                             |
| `flaresolverr.env.PROMETHEUS_PORT` | `8192`          | Port Prometheus                                |
| `flaresolverr.port`    | `8191`                       | Port de FlareSolverr                           |
| `flaresolverr.service.type` | `ClusterIP`             | Type de service                                |
| `flaresolverr.service.port` | `8191`                  | Port de service                                |
| `flaresolverr.livenessProbe.httpGet.path` | `/`       | Chemin HTTP de la liveness probe               |
| `flaresolverr.livenessProbe.httpGet.port` | `8191`    | Port de la liveness probe                      |
| `flaresolverr.livenessProbe.initialDelaySeconds` | `60` | Délai initial de la liveness probe      |
| `flaresolverr.livenessProbe.periodSeconds` | `30`     | Période de la liveness probe                   |
| `flaresolverr.readinessProbe.httpGet.path` | `/`      | Chemin HTTP de la readiness probe              |
| `flaresolverr.readinessProbe.httpGet.port` | `8191`   | Port de la readiness probe                     |
| `flaresolverr.readinessProbe.initialDelaySeconds` | `30` | Délai initial de la readiness probe    |
| `flaresolverr.readinessProbe.periodSeconds` | `15`    | Période de la readiness probe                  |

## Rdtclient

| Clé                    | Valeur Par Défaut              | Description                                    |
|------------------------|--------------------------------|------------------------------------------------|
| `rdtclient.enabled`    | `false`                        | Activer Rdtclient                              |
| `rdtclient.replicaCount` | `1`                          | Nombre de réplicas                             |
| `rdtclient.image`      | `rogerfar/rdtclient`           | Image de Rdtclient                             |
| `rdtclient.tag`        | `"2.0"`                        | Tag de l'image de Rdtclient                    |
| `rdtclient.env.PUID`   | `"1000"`                       | ID utilisateur (PUID)                          |
| `rdtclient.env.PGID`   | `"1000"`                       | ID groupe (PGID)                               |
| `rdtclient.env.UMASK`  | `"002"`                        | Umask                                          |
| `rdtclient.env.TZ`     | `"Europe/Paris"`               | Fuseau horaire                                 |
| `rdtclient.persistence.enabled` | `false`              | Activer la persistance                         |
| `rdtclient.persistence.size` | `1Gi`                   | Taille de la persistance                       |
| `rdtclient.data.path`  | `/downloads`                   | Chemin des données                             |
| `rdtclient.data.hostPath` | `/data/torrents`            | Chemin d'hôte des données                      |
| `rdtclient.port`       | `6500`                         | Port de Rdtclient                              |
| `rdtclient.service.type` | `ClusterIP`                  | Type de service                                |
| `rdtclient.service.port` | `6500`                       | Port de service                                |
| `rdtclient.livenessProbe.httpGet.path` | `/`           | Chemin HTTP de la liveness probe               |
| `rdtclient.livenessProbe.httpGet.port` | `6500`        | Port de la liveness probe                      |
| `rdtclient.livenessProbe.initialDelaySeconds` | `60`   | Délai initial de la liveness probe             |
| `rdtclient.livenessProbe.periodSeconds` | `30`         | Période de la liveness probe                   |
| `rdtclient.readinessProbe.httpGet.path` | `/`          | Chemin HTTP de la readiness probe              |
| `rdtclient.readinessProbe.httpGet.port` | `6500`       | Port de la readiness probe                     |
| `rdtclient.readinessProbe.initialDelaySeconds` | `30`  | Délai initial de la readiness probe            |
| `rdtclient.readinessProbe.periodSeconds` | `15`        | Période de la readiness probe                  |

## Addons - Code Server

| Clé                     | Valeur Par Défaut              | Description                                    |
|-------------------------|--------------------------------|------------------------------------------------|
| `addons.codeserver.enabled` | `false`                   | Activer Code Server                            |
| `addons.codeserver.persistence.enabled` | `false`      | Activer la persistance pour Code Server        |
| `addons.codeserver.persistence.size` | `1Gi`           | Taille de la persistance pour Code Server      |
| `addons.codeserver.image` | `lscr.io/linuxserver/code-server` | Image de Code Server                      |
| `addons.codeserver.tag` | `"4.92.2"`                     | Tag de l'image de Code Server                  |
| `addons.codeserver.env.PUID` | `"1000"`                  | ID utilisateur (PUID)                          |
| `addons.codeserver.env.PGID` | `"1000"`                  | ID groupe (PGID)                               |
| `addons.codeserver.env.UMASK` | `"002"`                  | Umask                                          |
| `addons.codeserver.env.TZ` | `"Europe/Paris"`            | Fuseau horaire                                 |
| `addons.codeserver.port` | `8443`                        | Port de Code Server                            |
| `addons.codeserver.service.type` | `ClusterIP`          | Type de service                                |
| `addons.codeserver.service.port` | `8443`               | Port de service                                |
| `addons.codeserver.ingress.enabled` | `false`           | Activer l'ingress pour Code Server             |
