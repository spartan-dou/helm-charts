#!/bin/bash

# --- Valeurs par défaut ---
IMMICH_DIR=${IMMICH_DIR:-"./photos"}
IMMICH_URL=${IMMICH_URL:-"https://immich.app"}
IMMICH_API_KEY=${IMMICH_API_KEY:-""}
USER_EMAIL=${USER_EMAIL:-""}
MAX_DIFF_SECONDS=${MAX_DIFF_SECONDS:-3456000}
DRY_RUN=${DRY_RUN:-false}
DEBUG=${DEBUG:-false}

# Fichier temporaire pour stocker le récapitulatif (plus fiable que les variables dans une boucle pipe)
RECAP_FILE=$(mktemp)

# --- Couleurs ---
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

param_curl="-sS"
# --- Fonction de logging ---
log_debug() {
    if [ "$DEBUG" = true ]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
        param_curl="-sS"
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

echo -e "${BOLD}--- Droits API requis ---${NC}"
echo -e " ${GREEN}✔${NC} album.read / album.create / albumUser.create / albumUser.update / albumUser.delete /  albumAsset.create / asset.read / user.read"
echo "--------------------------"

# --- Vérifications de sécurité ---
if [ -z "$IMMICH_API_KEY" ]; then
    echo "❌ Erreur : La clé API n'est pas configurée."
    exit 1
fi

log_debug "Vérification des outils : exiftool, jq..."
if ! command -v exiftool &> /dev/null || ! command -v jq &> /dev/null || ! command -v iconv &> /dev/null; then
    echo "❌ Erreur : 'exiftool' ou 'jq' ou 'iconv' manquant."
    exit 1
fi

echo "--- Récupération des données initiales ---"

# On utilise -i dans curl si debug pour voir les headers, mais attention jq n'aime pas ça
# On va donc logger les réponses brutes
log_debug "Appel API : GET $IMMICH_URL/api/albums"
album_raw=$(curl $param_curl -X GET "$IMMICH_URL/api/albums" -H "x-api-key: $IMMICH_API_KEY")
log_debug "Réponse API Albums: $(echo "$album_raw" | head -c 1000)..."

album_data=$(echo "$album_raw" | jq -r '.[] | "\(.albumName)|\(.id)"')

if [ -n "$USER_EMAIL" ]; then
    # Récupération de l'ID du destinataire du partage
    log_debug "Recherche de l'ID utilisateur pour : $USER_EMAIL"
    user_raw=$(curl $param_curl -X GET "$IMMICH_URL/api/users" -H "x-api-key: $IMMICH_API_KEY")
    log_debug "Réponse API User: $(echo "$user_raw" | head -c 1000)..."
    user_id=$(echo "$user_raw" | jq -r ".[] | select(.email == \"$USER_EMAIL\") | .id")
    log_debug "User ID trouvé : ${user_id:-"AUCUN"}"
fi

echo "--- Début du traitement récursif ---"

# Utilisation d'une substitution de processus < <(...) pour éviter le subshell du pipe
# et permettre de modifier des variables si nécessaire (bien qu'on utilise un fichier ici)
while IFS= read -r -d '' current_folder; do
    
    # On ignore le dossier racine s'il est vide de photos directes
    folder_basename=$(basename "$current_folder")
    echo "📂 Dossier : $current_folder"

    # --- Filtre .NOIMMICH ---
    if [ -f "$current_folder/.NOIMMICH" ]; then
        echo "    🚫 Dossier ignoré (présence de .NOIMMICH)"
        echo -e "${folder_basename}|Fichier .NOIMMICH présent" >> "$RECAP_FILE"
        continue
    fi

    # Extraction des métadonnées (Photos + Vidéos)
    log_debug "Exécution exiftool pour photos et vidéos dans $current_folder"
    
    temp_list=$(find "$current_folder" -maxdepth 1 -type f \( \
        -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.tif" -o \
        -iname "*.mp4" -o -iname "*.mov" -o -iname "*.avi" -o -iname "*.mkv" \
        \) -print0 | xargs -0 exiftool -fast2 -T -DateTimeOriginal -n 2>/dev/null | grep -v "^-" | sort)

    if [ -z "$temp_list" ]; then
        echo "    ⏩ Pas de photos avec EXIF ici, on passe."
        continue
    fi

    oldest_raw=$(echo "$temp_list" | head -n 1)
    newest_raw=$(echo "$temp_list" | tail -n 1)

    old_fmt=$(echo "$oldest_raw" | sed 's/:/-/1;s/:/-/1')
    new_fmt=$(echo "$newest_raw" | sed 's/:/-/1;s/:/-/1')

    ts_old=$(date -d "$old_fmt" +%s)
    ts_new=$(date -d "$new_fmt" +%s)
    diff_seconds=$(( ts_new - ts_old ))

    if [ "$diff_seconds" -gt "$MAX_DIFF_SECONDS" ]; then
        echo "    ❌ Alerte : Écart trop important."
        echo -e "${folder_basename}|Écart temporel trop grand ($((diff_seconds / 86400)) jours)" >> "$RECAP_FILE"
        continue
    fi

    # Nettoyage du nom pour l'album (enlève la date YYYY.MM.DD au début si elle existe)
    album_name=$(echo "$folder_basename" | sed -E 's/^[0-9]{4}\.[0-9]{2}\.[0-9]{2} //')

    # --- RECHERCHE DE L'ID (Le fameux grep -i) ---
    # On cherche le nom de l'album dans la liste, sans tenir compte de la casse
    target_album_id=$(echo "$album_data" | grep -i "^$album_name|" | cut -d'|' -f2)

    log_debug "Recherche d'album : $album_name -> ID trouvé : ${target_album_id:-"AUCUN"}"

    if [ -z "$target_album_id" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "    [DRY-RUN] 🛠 Création de l'album : $album_name"
            target_album_id="ID-FICTIF"
        else
            echo "    🛠 Création de l'album : $album_name"
            payload="{\"albumName\": \"$album_name\"}"

            response_album=$(curl $param_curl -X POST "$IMMICH_URL/api/albums" \
                -H "x-api-key: $IMMICH_API_KEY" \
                -H "Content-Type: application/json" \
                -d "$payload")

            log_debug "Réponse API Création Album: $(echo "$response_album" | head -c 1000)..."

            target_album_id=$(echo "$response_album" | jq -r '.id // empty')

            # --- MISE À JOUR DE LA LISTE DE DÉPART ---
            if [ -n "$target_album_id" ] && [ "$target_album_id" != "null" ]; then
                # On ajoute le nouvel album à la variable locale pour les prochaines itérations
                album_data+=$'\n'"$album_name|$target_album_id"
                log_debug "Album ajouté à la base locale : $album_name ($target_album_id)"
            fi
        fi
    fi

    # Gestion du Partage
    if [ -n "$user_id" ] && [ "$user_id" != "null" ] && [ "$target_album_id" != "ID-FICTIF" ]; then
        
        if [ ! -f "$current_folder/.NOIMMICHSHARE" ]; then
            log_debug "Tentative de partage de l'album $target_album_id avec $user_id"
            
            share_payload="{\"albumUsers\": [{\"role\": \"editor\", \"userId\": \"$user_id\"}]}"
            
            response_share=$(curl $param_curl -w "%{http_code}" -X PUT "$IMMICH_URL/api/albums/$target_album_id/users" \
                -H "x-api-key: $IMMICH_API_KEY" \
                -H "Content-Type: application/json" \
                -d "$share_payload")

            echo "    👥 Partagé avec $USER_EMAIL"
            log_debug "Réponse API Partage (Ajout): $response_share"

        else
            log_debug "Retrait du partage pour l'album $target_album_id"
            
            response_share=$(curl $param_curl -w "%{http_code}" -X DELETE "$IMMICH_URL/api/albums/$target_album_id/user/$user_id" \
                -H "x-api-key: $IMMICH_API_KEY")

            echo "    🗑️ Partage retiré (ou déjà absent) pour $USER_EMAIL"
            log_debug "Réponse API Partage (Suppression): $response_share"
        fi
    fi

    # Recherche des assets
    clean_date_oldest=$(echo "$old_fmt" | awk '{print $1}')
    clean_date_newest=$(echo "$new_fmt" | awk '{print $1}')
    
    search_payload=$(jq -n \
        --arg after "${clean_date_oldest}T00:00:00.000Z" \
        --arg before "${clean_date_newest}T23:59:59.999Z" \
        '{takenAfter: $after, takenBefore: $before}')

    log_debug "Recherche assets via POST sur $IMMICH_URL/api/search/metadata"
    log_debug "Payload recherche : $search_payload"

    response=$(curl $param_curl -X POST "$IMMICH_URL/api/search/metadata" \
        -H "x-api-key: $IMMICH_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$search_payload")

    log_debug "Réponse API Search: $(echo "$response" | head -c 1000)..."
    # Extraction des IDs
    photos_ids=$(echo "$response" | jq -r '.assets.items[].id // empty')
    
    if [ -z "$photos_ids" ]; then
        echo "    ⚠️ Aucune photo trouvée sur Immich pour ces dates."
        echo -e "${folder_basename}|Photos présentes localement mais introuvables sur Immich" >> "$RECAP_FILE"
        continue
    fi

    count=$(echo "$photos_ids" | wc -l)
    
    if [ "$DRY_RUN" = true ]; then
        echo "    [DRY-RUN] 🚀 $count assets à ajouter."
    else
        json_ids=$(echo "$photos_ids" | jq -R . | jq -s -c '{"ids": .}')
        log_debug "Payload PUT Assets (extrait) : $(echo "$json_ids" | head -c 1000)..."
        
        response_assets=$(curl $param_curl -X PUT "$IMMICH_URL/api/albums/$target_album_id/assets" \
            -H "x-api-key: $IMMICH_API_KEY" \
            -H "Content-Type: application/json" \
            -d "$json_ids")
        
        log_debug "Réponse API Ajout Assets: $(echo "$response_assets" | head -c 1000)..."
        
        echo "    ✅ $count assets synchronisés."
    fi

done < <(find "$IMMICH_DIR" -type d -not -path '*/.*' -print0)

# --- Affichage du Récapitulatif Final ---
echo -e "\n${BOLD}===========================================${NC}"
echo -e "${BOLD}         RÉCAPITULATIF DES ALERTES         ${NC}"
echo -e "${BOLD}===========================================${NC}"

if [ ! -s "$RECAP_FILE" ]; then
    echo -e "${GREEN}✨ Tous les dossiers ont été traités avec succès !${NC}"
else
    echo -e "${YELLOW}Les dossiers suivants ont été ignorés :${NC}\n"
    printf "${BOLD}%-30s | %-s${NC}\n" "DOSSIER" "RAISON"
    echo "-----------------------------------------------------------"
    while IFS='|' read -r dossier raison; do
        printf "${CYAN}%-30s${NC} | ${RED}%-s${NC}\n" "$dossier" "$raison"
    done < "$RECAP_FILE"
fi
echo -e "${BOLD}===========================================${NC}"

# Nettoyage
rm -f "$RECAP_FILE"

echo -e "\n--- Fin du traitement ---"