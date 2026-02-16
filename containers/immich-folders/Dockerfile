FROM alpine:latest

# Installation des outils
RUN apk add --no-cache bash curl jq exiftool tzdata

WORKDIR /app
COPY immich-folders.sh .
RUN chmod +x immich-folders.sh

# On utilise CMD pour que le script se lance par défaut au démarrage
# Cela permet aux variables d'environnement (ENV) d'être lues automatiquement
CMD ["/bin/bash", "/app/immich-folders.sh"]