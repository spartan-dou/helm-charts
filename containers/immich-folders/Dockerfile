FROM alpine:3.24

# Outils requis par immich-folders.sh
RUN apk add --no-cache bash curl jq exiftool tzdata

WORKDIR /app
COPY immich-folders.sh .
RUN chmod +x immich-folders.sh

ENTRYPOINT ["/bin/bash", "/app/immich-folders.sh"]