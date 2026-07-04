#!/usr/bin/env bash
# One-time: create the pocket-MDM CA + a device identity, and render the enrollment profile.
# Usage: make-ca.sh <server-url> <push-topic>
# Outputs into ~/.device-it/mdm/: ca.pem, ca.key, device.pem, device.key, device.p12, enroll.mobileconfig
set -euo pipefail

SERVER_URL="${1:?usage: make-ca.sh <server-url> <push-topic>}"
TOPIC="${2:?usage: make-ca.sh <server-url> <push-topic>}"
MDM_DIR="$HOME/.device-it/mdm"
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$MDM_DIR"
cd "$MDM_DIR"

if [[ ! -f ca.pem ]]; then
  openssl req -x509 -newkey rsa:2048 -keyout ca.key -out ca.pem -days 3650 -nodes \
    -subj "/CN=device-it pocket MDM CA/O=device-it" >/dev/null 2>&1
fi

if [[ ! -f device.p12 ]]; then
  openssl req -newkey rsa:2048 -keyout device.key -out device.csr -nodes \
    -subj "/CN=device-it device/O=device-it" >/dev/null 2>&1
  openssl x509 -req -in device.csr -CA ca.pem -CAkey ca.key -CAcreateserial \
    -out device.pem -days 1825 >/dev/null 2>&1
  P12_PASSWORD=$(openssl rand -hex 12)
  # -legacy keeps the p12 digestible by iOS profile installer across versions
  openssl pkcs12 -export -legacy -out device.p12 -inkey device.key -in device.pem \
    -password "pass:$P12_PASSWORD" 2>/dev/null || \
  openssl pkcs12 -export -out device.p12 -inkey device.key -in device.pem \
    -password "pass:$P12_PASSWORD"
  echo "$P12_PASSWORD" > p12-password.txt
  chmod 600 p12-password.txt device.key ca.key
  rm -f device.csr
fi

P12_PASSWORD=$(cat p12-password.txt)
P12_B64=$(base64 -i device.p12 | fold -w 68)

TPL="$SKILL_DIR/templates/enroll.mobileconfig.tpl"
python3 - "$TPL" "$MDM_DIR/enroll.mobileconfig" <<PY
import sys, uuid, socket
tpl = open(sys.argv[1]).read()
p12 = """$P12_B64"""
out = (tpl
  .replace('{{UUID_IDENTITY}}', str(uuid.uuid5(uuid.NAMESPACE_DNS, 'deviceit-identity')).upper())
  .replace('{{UUID_MDM}}', str(uuid.uuid5(uuid.NAMESPACE_DNS, 'deviceit-mdm')).upper())
  .replace('{{UUID_PROFILE}}', str(uuid.uuid5(uuid.NAMESPACE_DNS, 'deviceit-enroll')).upper())
  .replace('{{P12_PASSWORD}}', """$P12_PASSWORD""")
  .replace('{{P12_B64}}', p12.strip())
  .replace('{{SERVER_URL}}', """$SERVER_URL""".rstrip('/'))
  .replace('{{PUSH_TOPIC}}', """$TOPIC""")
  .replace('{{HOSTNAME}}', socket.gethostname()))
open(sys.argv[2], 'w').write(out)
PY

plutil -lint "$MDM_DIR/enroll.mobileconfig"
echo "ENROLL_PROFILE=$MDM_DIR/enroll.mobileconfig"
echo "CA=$MDM_DIR/ca.pem"
