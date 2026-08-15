#!/bin/sh
set -eu

echo "Waiting for services..."
until curl -sf "http://sonarr:8989/ping" >/dev/null; do sleep 3; done
until curl -sf "http://radarr:7878/ping" >/dev/null; do sleep 3; done
until curl -sf "http://prowlarr:9696/ping" >/dev/null; do sleep 3; done
until curl -sf "http://qbittorrent:8080/api/v2/app/version" >/dev/null; do sleep 3; done
until curl -sf "http://jellyfin:8096/health" >/dev/null; do sleep 3; done
until curl -sf "http://jellyseerr:5055/api/v1/status" >/dev/null; do sleep 3; done

add_download_client() {
  app_url=$1
  api_key=$2
  curl -sf -X POST "${app_url}/api/v3/downloadclient" \
    -H "X-Api-Key: ${api_key}" -H "Content-Type: application/json" \
    -d '{
      "enable": true,
      "protocol": "torrent",
      "implementation": "QBittorrent",
      "configContract": "QBittorrentSettings",
      "name": "qBittorrent",
      "fields": [
        {"name":"host","value":"qbittorrent"},
        {"name":"port","value":8080},
        {"name":"category","value":"'"$3"'"}
      ]
    }' >/dev/null || echo "download client already exists on ${app_url}"
}

add_root_folder() {
  curl -sf -X POST "${1}/api/v3/rootfolder" \
    -H "X-Api-Key: ${2}" -H "Content-Type: application/json" \
    -d "{\"path\":\"${3}\"}" >/dev/null || echo "root folder already exists on ${1}"
}

add_prowlarr_app() {
  curl -sf -X POST "http://prowlarr:9696/api/v1/applications" \
    -H "X-Api-Key: ${PROWLARR_API_KEY}" -H "Content-Type: application/json" \
    -d '{
      "name": "'"$1"'",
      "implementation": "'"$2"'",
      "configContract": "'"$2"'Settings",
      "syncLevel": "fullSync",
      "fields": [
        {"name":"prowlarrUrl","value":"http://prowlarr:9696"},
        {"name":"baseUrl","value":"'"$3"'"},
        {"name":"apiKey","value":"'"$4"'"}
      ]
    }' >/dev/null || echo "$1 already registered in Prowlarr"
}

echo "Wiring Sonarr..."
add_download_client "http://sonarr:8989" "${SONARR_API_KEY}" "tv-sonarr"
add_root_folder "http://sonarr:8989" "${SONARR_API_KEY}" "/tv"

echo "Wiring Radarr..."
add_download_client "http://radarr:7878" "${RADARR_API_KEY}" "movies-radarr"
add_root_folder "http://radarr:7878" "${RADARR_API_KEY}" "/movies"

echo "Wiring Prowlarr <-> Sonarr/Radarr..."
add_prowlarr_app "Sonarr" "Sonarr" "http://sonarr:8989" "${SONARR_API_KEY}"
add_prowlarr_app "Radarr" "Radarr" "http://radarr:7878" "${RADARR_API_KEY}"

echo "Wiring Jellyseerr <-> Jellyfin/Sonarr/Radarr..."
JSR_COOKIE=/tmp/jsr.txt
curl -sc "$JSR_COOKIE" -X POST "http://jellyseerr:5055/api/v1/auth/jellyfin" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${JELLYFIN_ADMIN_USER}\",\"password\":\"${JELLYFIN_ADMIN_PASSWORD}\"}" >/dev/null \
  || echo "Jellyseerr already linked to Jellyfin"

curl -sb "$JSR_COOKIE" -X POST "http://jellyseerr:5055/api/v1/settings/radarr" \
  -H "Content-Type: application/json" \
  -d '{
    "name":"Radarr","hostname":"radarr","port":7878,"apiKey":"'"${RADARR_API_KEY}"'",
    "useSsl":false,"baseUrl":"","activeProfileId":1,"activeDirectory":"/movies",
    "is4k":false,"isDefault":true,"minimumAvailability":"released"
  }' >/dev/null || echo "Radarr already registered in Jellyseerr"

curl -sb "$JSR_COOKIE" -X POST "http://jellyseerr:5055/api/v1/settings/sonarr" \
  -H "Content-Type: application/json" \
  -d '{
    "name":"Sonarr","hostname":"sonarr","port":8989,"apiKey":"'"${SONARR_API_KEY}"'",
    "useSsl":false,"baseUrl":"","activeProfileId":1,"activeDirectory":"/tv",
    "isDefault":true
  }' >/dev/null || echo "Sonarr already registered in Jellyseerr"

echo "Auto-wiring done."
