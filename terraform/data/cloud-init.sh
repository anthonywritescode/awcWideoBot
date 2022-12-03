#!/usr/bin/env bash
set -euxo pipefail

: === install podman ===
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    fuse-overlayfs \
    jq \
    podman \
    slirp4netns \
    uidmap

: === set up user ===
username=runner
useradd \
    "$username" \
    --create-home \
    --home-dir "/home/$username" \
    --shell /usr/sbin/nologin
loginctl enable-linger runner

: === set up shells scripts ===
cat >/opt/worker.sh <<'EOF'
set -euo pipefail

oci-get-secret() {
    podman run --rm ghcr.io/oracle/oci-cli \
        secrets secret-bundle get-secret-bundle-by-name \
        --auth instance_principal \
        --vault-id VAULT_ID \
        --secret-name "$1"  |
    jq --raw-output '.data["secret-bundle-content"].content' |
    base64 -d
}

export DISCORD_BOT_CONFIG="$(oci-get-secret discord-bot-config)"
export DISCORD_BOT_TOKEN="$(oci-get-secret discord-bot-token)"

podman manifest inspect ghcr.io/anthonywritescode/awcwideobot > /run/user/$(id -u)/image-manifest

exec podman run \
    --rm \
    --pull=always \
    --name=discord-bot \
    --env DISCORD_BOT_CONFIG \
    --env DISCORD_BOT_TOKEN \
    ghcr.io/anthonywritescode/awcwideobot
EOF

cat >/opt/updater.sh <<'EOF'
set -euxo pipefail

manifest=/run/user/$(id -u)/image-manifest

while true; do
    if [ -f "$manifest" ] && ! diff -q <(podman manifest inspect ghcr.io/anthonywritescode/awcwideobot) "$manifest"; then
        podman stop discord-bot
    fi

    sleep 60
done
EOF

: === set up systemd units ===
cat >/etc/systemd/system/podman-placeholder.service <<EOF
[Unit]
Description = containers/podman#8759

[Service]
User = $username
Group = $username

Type = notify
NotifyAccess = all
ExecStart = bash -c 'podman ps && systemd-notify --ready && exec sleep infinity'

[Install]
WantedBy=multi-user.target
EOF

cat >/etc/systemd/system/worker.service <<EOF
[Unit]
Description = worker
Wants = podman-placeholder.service
After = podman-placeholder.service

[Service]
User = $username
Group = $username

ExecStart = bash /opt/worker.sh

KillSignal = SIGINT

Restart=on-failure
RestartSec=5s

WorkingDirectory = /opt/

[Install]
WantedBy=multi-user.target
EOF

cat >/etc/systemd/system/updater.service <<EOF
[Unit]
Description = updater
Wants = podman-placeholder.service
After = podman-placeholder.service

[Service]
User = $username
Group = $username

ExecStart = bash /opt/updater.sh

KillSignal = SIGINT

Restart=on-failure
RestartSec=5s

WorkingDirectory = /opt/

[Install]
WantedBy=multi-user.target
EOF

: === enable and start units
systemctl daemon-reload
systemctl enable --now podman-placeholder.service
systemctl enable --now worker.service
systemctl enable --now updater.service
