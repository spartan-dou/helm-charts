#!/bin/sh

echo "before statring ..."


NEXTCLOUD_DATA_DIR={{ .Values.nextcloud.persistence.data.dir }}
UPDATE_APPS={{ .Values.nextcloud.apps.update }}

# whiteboard
echo "Check whiteboard is enabled ..."
{{- if .Values.whiteboard.enabled }}
echo "Installation de whiteboard"

while ! curl --output /dev/null --silent --fail http://{{ template "nextcloud.fullname" . }}-whiteboard:3002 && [ "$count" -lt 90 ];do
    echo "waiting for Whiteboard to become available..."
    sleep 5
done

if ! [ -d "/var/www/html/custom_apps/whiteboard" ]; then
    php /var/www/html/occ app:install whiteboard
elif [ "$(php /var/www/html/occ config:app:get whiteboard enabled)" != "yes" ]; then
    php /var/www/html/occ app:enable whiteboard
elif [ $UPDATE_APPS ]; then
    php /var/www/html/occ app:update whiteboard
fi

php /var/www/html/occ config:app:set whiteboard collabBackendUrl --value="https://{{ .Values.nextcloud.host }}/whiteboard"
php /var/www/html/occ config:app:set whiteboard jwt_secret_key --value="{{ .Values.whiteboard.secret }}"
{{- else }}
php /var/www/html/occ app:remove whiteboard
{{- end }}

# # OnlyOffice
echo "Check OnlyOffice is enabled ..."
{{- if .Values.onlyoffice.enabled }}
echo "Installation de OnlyOffice"
while ! curl --output /dev/null --silent --fail http://{{ template "nextcloud.fullname" . }}-onlyoffice && [ "$count" -lt 90 ];do
    echo "waiting for OnlyOffice to become available..."
    sleep 5
done
# done
if ! [ -d "/var/www/html/custom_apps/onlyoffice" ]; then
    php /var/www/html/occ app:install onlyoffice
elif [ "$(php /var/www/html/occ config:app:get onlyoffice enabled)" != "yes" ]; then
    php /var/www/html/occ app:enable onlyoffice
fi
if [ $UPDATE_APPS ]; then
php /var/www/html/occ app:update onlyoffice
fi
php /var/www/html/occ config:system:set onlyoffice jwt_secret --value="{{ .Values.onlyoffice.secret }}"
php /var/www/html/occ config:app:set onlyoffice jwt_secret --value="{{ .Values.onlyoffice.secret }}"
php /var/www/html/occ config:app:set onlyoffice DocumentServerUrl --value="https://{{ .Values.nextcloud.host }}/onlyoffice"
{{- else }}
php /var/www/html/occ app:remove onlyoffice
{{- end }}

# Collabora
echo "Check collabora is enabled ..."
{{- if .Values.collabora.enabled }}
echo "Installation de collabora"

while ! curl --output /dev/null --silent --fail http://{{ template "nextcloud.fullname" . }}-collabora && [ "$count" -lt 90 ];do
    echo "waiting for Collabora to become available..."
    sleep 5
done

if ! [ -d "/var/www/html/custom_apps/richdocuments" ]; then
    php /var/www/html/occ app:install richdocuments
elif [ "$(php /var/www/html/occ config:app:get richdocuments enabled)" != "yes" ]; then
    php /var/www/html/occ app:enable richdocuments
elif [ $UPDATE_APPS ]; then
    php /var/www/html/occ app:update richdocuments
fi

php /var/www/html/occ config:app:set richdocuments wopi_url --value="https://{{ .Values.nextcloud.host }}/collabora"

# Make collabora more save
COLLABORA_ALLOW_LIST="$(php /var/www/html/occ config:app:get richdocuments wopi_allowlist)"

if [ -n "$COLLABORA_ALLOW_LIST" ]; then
    PRIVATE_IP_RANGES='127.0.0.1/8,192.168.0.0/16,172.16.0.0/12,10.0.0.0/8,fd00::/8,::1'
    COLLABORA_ALLOW_LIST+=",$PRIVATE_IP_RANGES"
    COLLABORA_ALLOW_LIST+="{{ .Values.nextcloud.host }}"
fi
php /var/www/html/occ config:app:set richdocuments wopi_allowlist --value="$COLLABORA_ALLOW_LIST"

{{- else }}
php /var/www/html/occ app:remove richdocuments
{{- end }}

# Fulltextsearch
{{- if .Values.fulltextsearch.enabled }}

while ! curl --output /dev/null --silent --fail http://{{ template "nextcloud.fullname" . }}-fulltextsearch:9200 && [ "$count" -lt 90 ];do
    echo "waiting for Fulltextsearch to become available..."
    sleep 5
done

if ! [ -d "/var/www/html/custom_apps/fulltextsearch" ]; then
    php /var/www/html/occ app:install fulltextsearch
elif [ "$(php /var/www/html/occ config:app:get fulltextsearch enabled)" != "yes" ]; then
    php /var/www/html/occ app:enable fulltextsearch
elif [ $UPDATE_APPS ]; then
    php /var/www/html/occ app:update fulltextsearch
fi

if ! [ -d "/var/www/html/custom_apps/fulltextsearch_elasticsearch" ]; then
    php /var/www/html/occ app:install fulltextsearch_elasticsearch
elif [ "$(php /var/www/html/occ config:app:get fulltextsearch_elasticsearch enabled)" != "yes" ]; then
    php /var/www/html/occ app:enable fulltextsearch_elasticsearch
elif [ $UPDATE_APPS ]; then
    php /var/www/html/occ app:update fulltextsearch_elasticsearch
fi

if ! [ -d "/var/www/html/custom_apps/files_fulltextsearch" ]; then
    php /var/www/html/occ app:install files_fulltextsearch
elif [ "$(php /var/www/html/occ config:app:get files_fulltextsearch enabled)" != "yes" ]; then
    php /var/www/html/occ app:enable files_fulltextsearch
elif [ $UPDATE_APPS ]; then
    php /var/www/html/occ app:update files_fulltextsearch
fi

php /var/www/html/occ fulltextsearch:configure '{"search_platform":"OCA\\FullTextSearch_Elasticsearch\\Platform\\ElasticSearchPlatform"}'

php /var/www/html/occ fulltextsearch_elasticsearch:configure "{\"elastic_host\":\"http://elastic:{{ .Values.fulltextsearch.password }}@{{ template "nextcloud.fullname" . }}-fulltextsearch:9200\",\"elastic_index\":\"nextcloud\"}"

    # Do the index
if ! [ -f "{{ .Values.nextcloud.persistence.data.dir }}/fts-index.done" ]; then
    echo "Waiting 10s before activating FTS..."
    sleep 10
    echo "Activating fulltextsearch..."
    if php /var/www/html/occ fulltextsearch:test && php /var/www/html/occ fulltextsearch:index "{\"errors\": \"reset\"}" --no-readline; then
        touch "{{ .Values.nextcloud.persistence.data.dir }}/fts-index.done"
    else
        echo "Fulltextsearch failed. Could not index."
    fi
fi

{{- else }}

if [ -d "/var/www/html/custom_apps/fulltextsearch" ]; then
    php /var/www/html/occ app:remove fulltextsearch
fi
if [ -d "/var/www/html/custom_apps/fulltextsearch_elasticsearch" ]; then
    php /var/www/html/occ app:remove fulltextsearch_elasticsearch
fi
if [ -d "/var/www/html/custom_apps/files_fulltextsearch" ]; then
    php /var/www/html/occ app:remove files_fulltextsearch
fi
{{- end }}

# Clamav
{{- if .Values.clamav.enabled }}

if [ "$count" -ge 90 ]; then
    echo "Clamav did not start in time. Skipping initialization and disabling files_antivirus app."
    php /var/www/html/occ app:disable files_antivirus
else
    if ! [ -d "/var/www/html/custom_apps/files_antivirus" ]; then
        php /var/www/html/occ app:install files_antivirus
    elif [ "$(php /var/www/html/occ config:app:get files_antivirus enabled)" != "yes" ]; then
        php /var/www/html/occ app:enable files_antivirus
    elif [ $UPDATE_APPS ]; then
        php /var/www/html/occ app:update files_antivirus
    fi
    php /var/www/html/occ config:app:set files_antivirus av_mode --value="daemon"
    php /var/www/html/occ config:app:set files_antivirus av_port --value="3310"
    php /var/www/html/occ config:app:set files_antivirus av_host --value="{{ template "nextcloud.fullname" . }}-clamav"
    php /var/www/html/occ config:app:set files_antivirus av_stream_max_length --value="{{ .Values.clamav.uploadLimit }}"
    php /var/www/html/occ config:app:set files_antivirus av_max_file_size --value="{{ .Values.clamav.uploadLimit }}"
fi
{{- else }}
php /var/www/html/occ app:remove files_antivirus
{{- end }}

# Imaginary
{{- if .Values.imaginary.enabled }}
php /var/www/html/occ config:system:set enabledPreviewProviders 0 --value="OC\\Preview\\Imaginary"
php /var/www/html/occ config:system:set preview_imaginary_url --value="https://{{ .Values.nextcloud.host }}/imaginary"
php /var/www/html/occ config:system:set preview_imaginary_key --value="{{ .Values.imaginary.secret }}"
{{- else }}
if [ -n "$(php /var/www/html/occ config:system:get preview_imaginary_url)" ]; then
    php /var/www/html/occ config:system:delete enabledPreviewProviders 0
    php /var/www/html/occ config:system:delete preview_imaginary_url
    php /var/www/html/occ config:system:delete enabledPreviewProviders 20
    php /var/www/html/occ config:system:delete enabledPreviewProviders 21
    php /var/www/html/occ config:system:delete enabledPreviewProviders 22
fi
{{- end }}

# # Apply log settings
# echo "Applying default settings..."
php /var/www/html/occ config:system:set loglevel --value="2" --type=integer
php /var/www/html/occ config:system:set log_type --value="file"
php /var/www/html/occ config:system:set logfile --value="{{ .Values.nextcloud.persistence.data.dir }}/nextcloud.log"
php /var/www/html/occ config:system:set log_rotate_size --value="10485760" --type=integer
php /var/www/html/occ app:enable admin_audit
php /var/www/html/occ config:app:set admin_audit logfile --value="{{ .Values.nextcloud.persistence.data.dir }}/audit.log"
php /var/www/html/occ config:system:set log.condition apps 0 --value="admin_audit"

# # Apply preview settings
# echo "Applying preview settings..."
php /var/www/html/occ config:system:set preview_max_x --value="2048" --type=integer
php /var/www/html/occ config:system:set preview_max_y --value="2048" --type=integer
php /var/www/html/occ config:system:set jpeg_quality --value="60" --type=integer
php /var/www/html/occ config:app:set preview jpeg_quality --value="60"
php /var/www/html/occ config:system:delete enabledPreviewProviders
php /var/www/html/occ config:system:set enabledPreviewProviders 1 --value="OC\\Preview\\Image"
php /var/www/html/occ config:system:set enabledPreviewProviders 2 --value="OC\\Preview\\MarkDown"
php /var/www/html/occ config:system:set enabledPreviewProviders 3 --value="OC\\Preview\\MP3"
php /var/www/html/occ config:system:set enabledPreviewProviders 4 --value="OC\\Preview\\TXT"
php /var/www/html/occ config:system:set enabledPreviewProviders 5 --value="OC\\Preview\\OpenDocument"
php /var/www/html/occ config:system:set enabledPreviewProviders 6 --value="OC\\Preview\\Movie"
php /var/www/html/occ config:system:set enabledPreviewProviders 7 --value="OC\\Preview\\Krita"
php /var/www/html/occ config:system:set enabledPreviewProviders 8 --value="OC\Preview\HEIC"
php /var/www/html/occ config:system:set enabledPreviewProviders 9 --value="OC\Preview\MSOfficeDoc"
php /var/www/html/occ config:system:set enabledPreviewProviders 10 --value="OC\Preview\PDF"
php /var/www/html/occ config:system:set enabledPreviewProviders 11 --value="OC\Preview\Photoshop"
php /var/www/html/occ config:system:set enabledPreviewProviders 12 --value="OC\Preview\SVG"
php /var/www/html/occ config:system:set enabledPreviewProviders 13 --value="OC\Preview\TIFF"
php /var/www/html/occ config:system:set enabledPreviewProviders 14 --value="OC\Preview\BMP"
php /var/www/html/occ config:system:set enabledPreviewProviders 15 --value="OC\Preview\GIF"
php /var/www/html/occ config:system:set enabledPreviewProviders 16 --value="OC\Preview\JPEG"
php /var/www/html/occ config:system:set enabledPreviewProviders 17 --value="OC\Preview\PNG"
php /var/www/html/occ config:system:set enable_previews --value=true --type=boolean

# # Apply other settings
# echo "Applying other settings..."
php /var/www/html/occ config:system:set trashbin_retention_obligation --value="auto, 30"
php /var/www/html/occ config:system:set versions_retention_obligation --value="auto, 30"
# php /var/www/html/occ config:system:set share_folder --value="/Shared"

php /var/www/html/occ db:add-missing-columns
php /var/www/html/occ db:add-missing-primary-keys
yes | php /var/www/html/occ db:convert-filecache-bigint
php /var/www/html/occ maintenance:repair --include-expensive
php /var/www/html/occ db:add-missing-indices

php /var/www/html/occ config:system:set default_phone_region --value="{{ .Values.nextcloud.phoneRegion }}"
php /var/www/html/occ config:system:set default_language --value="{{ .Values.nextcloud.defaultLanguage }}" 
php /var/www/html/occ config:system:set default_locale --value="{{ .Values.nextcloud.defaultLocale }}"

php /var/www/html/occ config:system:set maintenance_window_start --type=integer --value=1

# Install some apps by default
{{- range .Values.nextcloud.apps.install }}
echo "apps : {{ . }}"
if [ -z "$(find /var/www/html/apps -type d -maxdepth 1 -mindepth 1 -name "$app" )" ]; then
    # If not shipped, install and enable the app
    php /var/www/html/occ app:install {{ . }}
    echo "installed {{ . }}"
else
    # If shipped, enable the app
    php /var/www/html/occ app:enable {{ . }}
fi
{{- end }}

count=1
{{- range .Values.nextcloud.trustedDomains }}
php occ config:system:set trusted_domains $count --value={{ . }}
count=$((count + 1))
{{- end }}
php occ config:system:set  overwrite.cli.url -value=https://{{ .Values.nextcloud.host }}
# # Facerognition
{{- if .Values.facerecognition.enabled }}
echo "Installation de facerecognition"
if ! [ -d "/var/www/html/custom_apps/facerecognition" ]; then
    php /var/www/html/occ app:install facerecognition
elif [ "$(php /var/www/html/occ config:app:get facerecognition enabled)" != "yes" ]; then
    php /var/www/html/occ app:enable facerecognition
elif [ $UPDATE_APPS ]; then
    php /var/www/html/occ app:update facerecognition
fi

php /var/www/html/occ config:system:set facerecognition.external_model_url --value {{ template "nextcloud.fullname" . }}-facerecognition:5000
php /var/www/html/occ config:system:set facerecognition.external_model_api_key --value {{ .Values.facerecognition.secret }}
php /var/www/html/occ face:setup -m 5
php /var/www/html/occ face:setup -M 1G
php /var/www/html/occ config:app:set facerecognition analysis_image_area --value 4320000
php /var/www/html/occ config:system:set enabledFaceRecognitionMimetype 0 --value image/jpeg
php /var/www/html/occ config:system:set enabledFaceRecognitionMimetype 1 --value image/png
php /var/www/html/occ config:system:set enabledFaceRecognitionMimetype 2 --value image/heic
php /var/www/html/occ config:system:set enabledFaceRecognitionMimetype 3 --value image/tiff
php /var/www/html/occ config:system:set enabledFaceRecognitionMimetype 4 --value image/webp
php /var/www/html/occ face:background_job --defer-clustering &

{{- else }}
php /var/www/html/occ app:remove facerecognition
{{- end }}


# # Memories
{{- if .Values.memories.enabled }}
echo "Installation de Memories"
if ! [ -d "/var/www/html/custom_apps/memories" ]; then
    php /var/www/html/occ app:install memories
elif [ "$(php /var/www/html/occ config:app:get memories enabled)" != "yes" ]; then
    php /var/www/html/occ app:enable memories
    
elif [ $UPDATE_APPS ]; then
    php /var/www/html/occ app:update memories
fi

php /var/www/html/occ config:system:set memories.vod.external --value true --type bool
php /var/www/html/occ config:system:set memories.vod.connect --value {{ template "nextcloud.fullname" . }}-memories:47788
{{- else }}
php /var/www/html/occ app:remove memories
{{- end }}


echo "before statring end"