#!/bin/bash

# --- Valeurs par défaut ---
IMMICH_DIR=${IMMICH_DIR:-"./photos"}
IMMICH_URL=${IMMICH_URL:-"https://immich.app"}
IMMICH_API_KEY=${IMMICH_API_KEY:-""}
USER_EMAIL=${USER_EMAIL:-"admin@example.com"}
MAX_DIFF_SECONDS=${MAX_DIFF_SECONDS:-3456000}

# --- Analyse des arguments nommés ---
while [ $# -gt 0 ]; do
  case "$1" in
    -dir)
      IMMICH_DIR="$2"
      shift 2
      ;;
    -url)
      IMMICH_URL="$2"
      shift 2
      ;;
    -apiKey)
      IMMICH_API_KEY="$2"
      shift 2
      ;;
    -email)
      USER_EMAIL="$2"
      shift 2
      ;;
    -maxDiff)
      MAX_DIFF_SECONDS="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: ./script.sh -dir [chemin] -url [url] -apiKey [clé] -email [email]"
      exit 0
      ;;
    *)
      echo "❌ Argument inconnu : $1"
      exit 1
      ;;
  esac
done

GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}--- Droits API requis ---${NC}"
echo -e " ${GREEN}✔${NC} album.read"
echo -e " ${GREEN}✔${NC} album.create"
echo -e " ${GREEN}✔${NC} asset.read"
echo -e " ${GREEN}✔${NC} user.read"
echo "--------------------------"

# --- Vérifications de sécurité ---
if [ "$IMMICH_API_KEY" == "Votre_Clé_Par_Défaut" ]; then
    echo "❌ Erreur : La clé API n'est pas configurée."
    exit 1
fi

if ! command -v exiftool &> /dev/null || ! command -v jq &> /dev/null; then
    echo "Erreur : 'exiftool' ou 'jq' manquant."
    exit 1
fi

echo "--- Récupération des données initiales ---"

# Liste des albums existants (Nom|ID)
album_data=$(curl -s -X GET "$IMMICH_URL/api/album" \
    -H "accept: application/json" \
    -H "x-api-key: $IMMICH_API_KEY" | jq -r '.[] | "\(.albumName)|\(.id)"')

# Récupération de l'ID du destinataire du partage
user_id=$(curl -s -X GET "$IMMICH_URL/api/user" \
    -H "accept: application/json" \
    -H "x-api-key: $IMMICH_API_KEY" | \
    jq -r ".[] | select(.email == \"$USER_EMAIL\") | .id")

echo "--- Début du traitement récursif ---"

# On boucle sur les dossiers contenant des fichiers images
find "$IMMICH_DIR" -type d -not -path '*/.*' -print0 | while IFS= read -r -d '' current_folder; do
    
    # On ignore le dossier racine s'il est vide de photos directes
    folder_basename=$(basename "$current_folder")
    echo "📂 Dossier : $current_folder"

    # Extraction des métadonnées des photos du dossier EN COURS
    temp_list=$(find "$current_folder" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -print0 | \
        xargs -0 exiftool -T -DateTimeOriginal -n | grep -v "^-" | sort)

    if [ -z "$temp_list" ]; then
        echo "   ⏩ Pas de photos avec EXIF ici, on passe."
        continue
    fi

    oldest_raw=$(echo "$temp_list" | head -n 1)
    newest_raw=$(echo "$temp_list" | tail -n 1)

    # Nettoyage pour calcul timestamp (YYYY:MM:DD -> YYYY-MM-DD)
    old_fmt=$(echo "$oldest_raw" | sed 's/:/-/1;s/:/-/1')
    new_fmt=$(echo "$newest_raw" | sed 's/:/-/1;s/:/-/1')

    ts_old=$(date -d "$old_fmt" +%s)
    ts_new=$(date -d "$new_fmt" +%s)
    diff_seconds=$(( ts_new - ts_old ))

    if [ "$diff_seconds" -gt "$MAX_DIFF_SECONDS" ]; then
        echo "   ❌ Alerte : Écart de $((diff_seconds / 86400)) jours. Arrêt."
        continue
    fi

    # Gestion de l'Album
    # On cherche si l'album (nom du dossier) existe déjà
    target_album_id=$(echo "$album_data" | grep "^$folder_basename|" | cut -d'|' -f2)

    if [ -z "$target_album_id" ]; then
        echo "   🛠 Création de l'album : $folder_basename"
        target_album_id=$(curl -s -X POST "$IMMICH_URL/api/album" \
            -H "accept: application/json" \
            -H "x-api-key: $IMMICH_API_KEY" \
            -H "Content-Type: application/json" \
            -d "{\"albumName\": \"$folder_basename\"}" | jq -r '.id')
        
        # Partage si nouvel album
        if [ "$user_id" != "" ] && [ "$user_id" != "null" ]; then
            curl -s -X POST "$IMMICH_URL/api/album/$target_album_id/user/$user_id" \
                -H "accept: application/json" \
                -H "x-api-key: $IMMICH_API_KEY" \
                -H "Content-Type: application/json" \
                -d "{\"role\": \"editor\"}" > /dev/null
            echo "   👥 Partagé avec $USER_EMAIL"
        fi
    fi

    # Récupération des IDs d'assets sur Immich
    # On utilise le format YYYY-MM-DD pour l'API
    clean_date_oldest=$(echo "$old_fmt" | awk '{print $1}')
    clean_date_newest=$(echo "$new_fmt" | awk '{print $1}')

    response=$(curl -s -X GET "$IMMICH_URL/api/search/metadata?takenAfter=${clean_date_oldest}T00:00:00Z&takenBefore=${clean_date_newest}T23:59:59Z" \
        -H "accept: application/json" \
        -H "x-api-key: $IMMICH_API_KEY")

    photos_ids=$(echo "$response" | jq -r '.assets.items[].id // empty')
    
    if [ -z "$photos_ids" ]; then
        echo "   ⚠️ Aucune photo correspondante sur le serveur Immich."
        continue
    fi

    # Ajout groupé
    json_ids=$(echo "$photos_ids" | jq -R . | jq -s -c '{"ids": .}')

    curl -s -X PUT "$IMMICH_URL/api/album/$target_album_id/assets" \
        -H "x-api-key: $IMMICH_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$json_ids" > /dev/null

    echo "   ✅ Assets synchronisés dans l'album."

done

echo "--- Fin du traitement ---"