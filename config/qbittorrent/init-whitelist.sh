#!/usr/bin/with-contenv bash
mkdir -p /config/qBittorrent
CONF=/config/qBittorrent/qBittorrent.conf
touch "$CONF"

set_pref() {
  key=$1
  value=$2
  if grep -q "^${key}=" "$CONF"; then
    sed -i "s#^${key}=.*#${key}=${value}#" "$CONF"
  else
    if ! grep -q "^\[Preferences\]" "$CONF"; then
      printf '[Preferences]\n' >> "$CONF"
    fi
    sed -i "/^\[Preferences\]/a ${key}=${value}" "$CONF"
  fi
}

set_pref "WebUI\\\\AuthSubnetWhitelistEnabled" "true"
set_pref "WebUI\\\\AuthSubnetWhitelist" "172.16.0.0/12, 192.168.0.0/16"
set_pref "WebUI\\\\CSRFProtection" "false"
set_pref "WebUI\\\\HostHeaderValidation" "false"
