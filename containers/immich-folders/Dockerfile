FROM alpine:3.23

# Installation des outils (exiv2 est beaucoup plus léger)
RUN apk add --no-cache bash curl jq exiftool tzdata && \
    rm -rf /var/cache/apk/*

WORKDIR /app
COPY immich-folders.sh .
RUN chmod +x immich-folders.sh

ENTRYPOINT ["/bin/bash", "/app/immich-folders.sh"]