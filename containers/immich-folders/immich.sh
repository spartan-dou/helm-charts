#!/bin/bash

IMMICH_DIR="dir"

IMMICH_URL="https://immich.app/"

IMMICH_API_KEY="Votre clé API Immich ici"

USR_EMAIL="Votre nom d'utilisateur ici"

MAX_DIFF_SECONDS=3456000

echo "--- droits nécéssaires ---"
echo "album.read"
echo "album.create"
echo "asset.read"
echo "user.read"

echo "--- Vérification de la variable : $IMMICH_DIR ---"

# Vérification de l'outil exiftool
if ! command -v exiftool &> /dev/null; then
    echo "Erreur : 'exiftool' n'est pas installé. apt install libimage-exiftool-perl"
    exit 1
fi

if [ -d "$IMMICH_DIR" ]; then
    echo "Succès : Répertoire trouvé -> $IMMICH_DIR"
    echo "Contenu du dossier :"
    ls -F "$IMMICH_DIR"
else
    echo "Erreur : Le chemin '$IMMICH_DIR' n'existe pas ou n'est pas un dossier."
    exit 1
fi

echo "--- Récupération des albums ---"

album_list=$(curl -s -X GET "$IMMICH_URL/api/albums" \
    -H "accept: application/json" \
    -H "x-api-key: $IMMICH_API_KEY" | jq -r '.[] | "\(.albumName)|\(.id)"')


echo "--- Récupération de l'id du user à partager ---"
user_id=$(curl -s -X GET "$IMMICH_URL/api/user" \
    -H "accept: application/json" \
    -H "x-api-key: $IMMICH_API_KEY" | \
    jq -r ".[] | select(.email == \"$USER_EMAIL\") | .id")

echo "--- Début du traitement récursif ---"

find "$IMMICH_DIR" -type d -not -path '*/.*' -print0 | while IFS= read -r -d '' folder_name; do
    
    echo "Traitement du dossier : $folder_name"
    
    echo "Analyse des photos dans : $IMMICH_DIR..."

    temp_list=$(find "$IMMICH_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -print0 | \
        xargs -0 exiftool -T -DateTimeOriginal -FileName -n | \
        grep -v "^-" | \
        sort)

    if [ -z "$temp_list" ]; then
        echo "Aucune métadonnée photo trouvée."
        exit 1
    fi

    oldest_raw=$(echo "$temp_list" | head -n 1)
    newest_raw=$(echo "$temp_list" | tail -n 1)

    echo "---"

    
    echo "Plus ancienne** | $(echo "$oldest_raw" | awk '{print $1}') | $(echo "$oldest_raw" | awk '{$1=$2=""; print $0}' | sed 's/^[ \t]*//')"
    echo "Plus récente** | $(echo "$newest_raw" | awk '{print $1}') | $(echo "$newest_raw" | awk '{$1=$2=""; print $0}' | sed 's/^[ \t]*//')"

    echo "---"

    old_fmt=$(echo "$oldest_raw" | sed 's/:/-/1;s/:/-/1')
    new_fmt=$(echo "$newest_raw" | sed 's/:/-/1;s/:/-/1')

    ts_old=$(date -d "$old_fmt" +%s)
    ts_new=$(date -d "$new_fmt" +%s)

    diff_seconds=$(( ts_new - ts_old ))
    diff_days=$(( diff_seconds / 86400 ))

    echo "--- Analyse de l'écart ---"
    echo "Écart    : $diff_days jours"

    if [ "$diff_seconds" -gt "$MAX_DIFF_SECONDS" ]; then
        echo "❌ Alerte : L'écart dépasse 40 jours ($diff_days jours)."
        exit 1
    fi

    target_album_id=$(echo "$album_data" | grep "^$folder_name|" | cut -d'|' -f2)

    if [ -n "$target_album_id" ]; then
        echo "✅ Album trouvé : $folder_name (ID: $target_album_id)"
    else
        echo "❌ L'album '$folder_name' n'a pas été trouvé sur Immich. Création en cours..."
        target_album_id=$(curl -s -X POST "$IMMICH_URL/api/album" \
            -H "accept: application/json" \
            -H "x-api-key: $IMMICH_API_KEY" \
            -H "Content-Type: application/json" \
            -d "{\"albumName\": \"$folder_name\"}" | jq -r '.id')
        
        if [ "$user_id" != "null" ]; then
            
            curl -s -X POST "$IMMICH_URL/api/album/$target_album_id/user/$user_id" \
                -H "accept: application/json" \
                -H "x-api-key: $IMMICH_API_KEY" \
                -H "Content-Type: application/json" \
                -d "{
                    \"role\": \"editor\"
                    }"
            echo "✅ Partage activé pour l'utilisateur $user_id"
        fi
    fi

    echo "Récupération des photos à mettre dans l'album '$folder_name' (ID: $target_album_id)..."

    clean_date_oldest=$(echo "$oldest_raw" | awk '{print $1}' | sed 's/:/-/g')
    clean_date_newest=$(echo "$newest_raw" | awk '{print $1}' | sed 's/:/-/g')

    response=$(curl -s -X GET "$IMMICH_URL/api/search/metadata?withStacked=true&takenAfter=$clean_date_oldest&takenBefore=$clean_date_newest" \
        -H "accept: application/json" \
        -H "x-api-key: $IMMICH_API_KEY")

    photos=$(echo "$response" | jq -r '.assets.items[].id')
    
    if [ -z "$photos" ] || [ "$photos" = "null" ]; then
        echo "❌ Aucune photo trouvée entre ces deux dates."
        exit 1
    fi

    echo "--- Début du traitement des photos trouvées ---"

    json_ids=$(echo "$photos" | jq -R . | jq -s -c .)

    curl -s -X PUT "$IMMICH_URL/api/album/$target_album_id/assets" \
        -H "x-api-key: $IMMICH_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"ids\": $json_ids}"

    echo "✅ Tous les assets ont été ajoutés à l'album."
    
done

echo "--- Fin du traitement ---"