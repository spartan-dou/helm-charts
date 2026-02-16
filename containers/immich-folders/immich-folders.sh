#!/bin/bash

# --- Valeurs par défaut ---
IMMICH_DIR=${IMMICH_DIR:-"./photos"}
IMMICH_URL=${IMMICH_URL:-"https://immich.app"}
IMMICH_API_KEY=${IMMICH_API_KEY:-""}
USER_EMAIL=${USER_EMAIL:-""}
MAX_DIFF_SECONDS=${MAX_DIFF_SECONDS:-3456000}
DRY_RUN=${DRY_RUN:-false}
DEBUG=${DEBUG:-false}

# --- Couleurs ---
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- Fonction de logging ---
log_debug() {
    if [ "$DEBUG" = true ]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

# --- Analyse des arguments ---
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) IMMICH_DIR="$2"; shift 2 ;;
    --url) IMMICH_URL="$2"; shift 2 ;;
    --apiKey) IMMICH_API_KEY="$2"; shift 2 ;;
    --email) USER_EMAIL="$2"; shift 2 ;;
    --maxDiff) MAX_DIFF_SECONDS="$2"; shift 2 ;;
    --dryRun) DRY_RUN=true; shift 1 ;;
    --debug) DEBUG=true; shift 1 ;;
    -h|--help)
      echo "Usage: ./immich-folders.sh --dir [chemin] --url [url] --apiKey [clé] [--email email] [--dryRun] [--debug]"
      exit 0
      ;;
    *) echo "❌ Argument inconnu : $1"; exit 1 ;;
  esac
done

if [ "$DEBUG" = true ]; then echo -e "${CYAN}${BOLD}🔧 MODE DEBUG ACTIVÉ${NC}"; fi
if [ "$DRY_RUN" = true ]; then echo -e "${YELLOW}${BOLD}⚠️ MODE DRY RUN ACTIVÉ${NC}\n"; fi

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}--- Droits API requis ---${NC}"
echo -e " ${GREEN}✔${NC} album.read / album.create / album.update / asset.read / user.read"
echo "--------------------------"

# --- Vérifications de sécurité ---
if [ -z "$IMMICH_API_KEY" ]; then
    echo "❌ Erreur : La clé API n'est pas configurée."
    exit 1
fi

log_debug "Vérification des outils : exiftool, jq..."
if ! command -v exiftool &> /dev/null || ! command -v jq &> /dev/null; then
    echo "Erreur : 'exiftool' ou 'jq' manquant."
    exit 1
fi

echo "--- Récupération des données initiales ---"

# On utilise -i dans curl si debug pour voir les headers, mais attention jq n'aime pas ça
# On va donc logger les réponses brutes
log_debug "Appel API : GET $IMMICH_URL/api/album"
album_raw=$(curl -s -X GET "$IMMICH_URL/api/album" -H "x-api-key: $IMMICH_API_KEY")
log_debug "Réponse API Album: $(echo "$album_raw" | head -c 100)..."

album_data=$(echo "$album_raw" | jq -r '.[] | "\(.albumName)|\(.id)"')

if [ -n "$USER_EMAIL" ]; then
    # Récupération de l'ID du destinataire du partage
    log_debug "Recherche de l'ID utilisateur pour : $USER_EMAIL"
    user_id=$(curl -s -X GET "$IMMICH_URL/api/user" -H "x-api-key: $IMMICH_API_KEY" | \
        jq -r ".[] | select(.email == \"$USER_EMAIL\") | .id")
    log_debug "User ID trouvé : ${user_id:-"AUCUN"}"
fi

echo "--- Début du traitement récursif ---"

# On boucle sur les dossiers contenant des fichiers images
find "$IMMICH_DIR" -type d -not -path '*/.*' -print0 | while IFS= read -r -d '' current_folder; do
    
    # On ignore le dossier racine s'il est vide de photos directes
    folder_basename=$(basename "$current_folder")
    echo "📂 Dossier : $current_folder"

    # Extraction des métadonnées des photos du dossier EN COURS
    log_debug "Exécution exiftool dans $current_folder"
    temp_list=$(find "$current_folder" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -print0 | \
        xargs -0 exiftool -T -DateTimeOriginal -n | grep -v "^-" | sort)

    if [ -z "$temp_list" ]; then
        echo "   ⏩ Pas de photos avec EXIF ici, on passe."
        continue
    fi

    oldest_raw=$(echo "$temp_list" | head -n 1)
    newest_raw=$(echo "$temp_list" | tail -n 1)
    log_debug "Dates brutes : Old=$oldest_raw | New=$newest_raw"

    old_fmt=$(echo "$oldest_raw" | sed 's/:/-/1;s/:/-/1')
    new_fmt=$(echo "$newest_raw" | sed 's/:/-/1;s/:/-/1')

    ts_old=$(date -d "$old_fmt" +%s)
    ts_new=$(date -d "$new_fmt" +%s)
    diff_seconds=$(( ts_new - ts_old ))
    log_debug "Calcul écart : $diff_seconds secondes ($((diff_seconds / 86400)) jours)"

    if [ "$diff_seconds" -gt "$MAX_DIFF_SECONDS" ]; then
        echo "   ❌ Alerte : Écart de $((diff_seconds / 86400)) jours. Arrêt pour ce dossier."
        continue
    fi

    # Gestion de l'Album
    # On cherche si l'album (nom du dossier) existe déjà
    target_album_id=$(echo "$album_data" | grep "^$folder_basename|" | cut -d'|' -f2)

    if [ -z "$target_album_id" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "   [DRY-RUN] 🛠 Création de l'album : $folder_basename"
            target_album_id="ID-FICTIF"
        else
            echo "   🛠 Création de l'album : $folder_basename"
            payload="{\"albumName\": \"$folder_basename\"}"
            log_debug "Payload POST Album : $payload"
            target_album_id=$(curl -s -X POST "$IMMICH_URL/api/album" \
                -H "x-api-key: $IMMICH_API_KEY" \
                -H "Content-Type: application/json" \
                -d "$payload" | jq -r '.id')
            
            # Partage si nouvel album
            if [ -n "$user_id" ] && [ "$user_id" != "null" ]; then
                log_debug "Partage de l'album $target_album_id avec $user_id"
                curl -s -X POST "$IMMICH_URL/api/album/$target_album_id/user/$user_id" \
                    -H "x-api-key: $IMMICH_API_KEY" \
                    -H "Content-Type: application/json" \
                    -d "{\"role\": \"editor\"}" > /dev/null
                echo "   👥 Partagé avec $USER_EMAIL"
            fi
        fi
    fi

    # Recherche des assets
    clean_date_oldest=$(echo "$old_fmt" | awk '{print $1}')
    clean_date_newest=$(echo "$new_fmt" | awk '{print $1}')
    
    search_url="$IMMICH_URL/api/search/metadata?takenAfter=${clean_date_oldest}T00:00:00Z&takenBefore=${clean_date_newest}T23:59:59Z"
    log_debug "Recherche assets : $search_url"

    response=$(curl -s -X GET "$search_url" -H "x-api-key: $IMMICH_API_KEY")
    photos_ids=$(echo "$response" | jq -r '.assets.items[].id // empty')
    
    if [ -z "$photos_ids" ]; then
        echo "   ⚠️ Aucune photo trouvée sur Immich pour ces dates."
        continue
    fi

    count=$(echo "$photos_ids" | wc -l)
    
    if [ "$DRY_RUN" = true ]; then
        echo "   [DRY-RUN] 🚀 $count assets à ajouter."
    else
        json_ids=$(echo "$photos_ids" | jq -R . | jq -s -c '{"ids": .}')
        log_debug "Payload PUT Assets (extrait) : $(echo "$json_ids" | head -c 50)..."
        curl -s -X PUT "$IMMICH_URL/api/album/$target_album_id/assets" \
            -H "x-api-key: $IMMICH_API_KEY" \
            -H "Content-Type: application/json" \
            -d "$json_ids" > /dev/null
        echo "   ✅ $count assets synchronisés."
    fi

done

echo -e "\n--- Fin du traitement ---"