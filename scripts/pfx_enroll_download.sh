#!/bin/bash
set -e

# ENV VARIABLES (pass these from Ansible)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
AUTH="${AUTH}"
KEYFACTOR_URL="${KEYFACTOR_URL:-https://fis.keyfactorpki.com}"
HTTPS_PROXY="${HTTPS_PROXY:-}"
TEMPLATE="${TEMPLATE:-WebServer(13Month-ClientandServerAuth)PROD}"

CHANGE_NUMBER="${CHANGE_NUMBER}"
CN_NAME="${CN_NAME}"
CA_NAME="${CA_NAME}"
PASSWORD="${PASSWORD}"

# Metadata passed via env vars (with defaults)
METADATA_EMAIL_CONTACT="${METADATA_EMAIL_CONTACT:-akshith.mg@fisglobal.com}"
METADATA_DEVICE_TYPE="${METADATA_DEVICE_TYPE:-Unix Server}"
METADATA_DATACENTER_LOCATION="${METADATA_DATACENTER_LOCATION:-M1DC & M2DC}"
METADATA_DESCRIPTION="${METADATA_DESCRIPTION:-THIS TEST CERTIFICATE ENROLLED FOR TESTING KEYFACTOR API}"
METADATA_NOTIFICATION="${METADATA_NOTIFICATION:-True}"
METADATA_FOLDER="${METADATA_FOLDER:-/apps/3270portal/}"
METADATA_SUB_FOLDER="${METADATA_SUB_FOLDER:-/apps/3270portal/}"
METADATA_APPLICATION_CONTACT_PRIMARY="${METADATA_APPLICATION_CONTACT_PRIMARY:-akshith.mg@fisglobal.com}"
METADATA_APPLICATION_CONTACT_SECONDARY="${METADATA_APPLICATION_CONTACT_SECONDARY:-akshith.mg@fisglobal.com}"
METADATA_PERMISSIONS="${METADATA_PERMISSIONS:-FIS-AU Venafi Access}"
METADATA_CONTACT="${METADATA_CONTACT:-FIS-AU Venafi Access}"
METADATA_ACME_REQUESTER="${METADATA_ACME_REQUESTER:-N/A}"

# Validate CHANGE_NUMBER format (example: CH12345)
if [[ ! "$CHANGE_NUMBER" =~ ^CH[0-9]+$ ]]; then
  echo -e "\e[31mERROR: Invalid CHANGE_NUMBER format. Must be like CH12345.\e[0m"
  exit 1
fi
echo -e "\e[32mCHANGE NUMBER '$CHANGE_NUMBER' accepted. Proceeding...\e[0m"

# Validate required variables
for var in CN_NAME CA_NAME PASSWORD AUTH; do
  if [ -z "${!var}" ]; then
    echo -e "\e[31mERROR: Required variable '$var' is missing.\e[0m"
    exit 1
  fi
done

echo -e "\e[32mUsing CN Name: $CN_NAME\e[0m"
echo -e "\e[32mUsing CA Name: $CA_NAME\e[0m"

# DNS and IP addresses are passed as comma-separated env vars
IFS=',' read -ra DNS_NAMES <<< "${DNS_NAMES:-}"
IFS=',' read -ra IP_ADDRESSES <<< "${IP_ADDRESSES:-}"

DNS_JSON=$(printf '"%s",' "${DNS_NAMES[@]}" | sed 's/,$//')
IP_JSON=$(printf '"%s",' "${IP_ADDRESSES[@]}" | sed 's/,$//')

echo -e "\e[32mBuilding payload.json...\e[0m"
cat > payload.json <<EOF
{
  "CustomFriendlyName": "$CN_NAME",
  "Subject": "CN=$CN_NAME, OU=AU Technology Services, O=Fidelity National Information Services, L=Melbourne, S=VIC, C=AU",
  "Template": "$TEMPLATE",
  "CertificateAuthority": "$CA_NAME",
  "Password": "$PASSWORD",
  "Timestamp": "$TIMESTAMP",
  "SANs": {
    "DNS": [ $DNS_JSON ],
    "IP": [ $IP_JSON ]
  },
  "Metadata": {
    "Email-Contact": "$METADATA_EMAIL_CONTACT",
    "Device-Type": "$METADATA_DEVICE_TYPE",
    "DataCenter-Location": "$METADATA_DATACENTER_LOCATION",
    "Description": "$METADATA_DESCRIPTION",
    "Notification": "$METADATA_NOTIFICATION",
    "Folder": "$METADATA_FOLDER",
    "Sub-Folder": "$METADATA_SUB_FOLDER",
    "Application-Contact-Primary": "$METADATA_APPLICATION_CONTACT_PRIMARY",
    "Application-Contact-Secondary": "$METADATA_APPLICATION_CONTACT_SECONDARY",
    "Permissions": "$METADATA_PERMISSIONS",
    "Contact": "$METADATA_CONTACT",
    "ACME_Requester": "$METADATA_ACME_REQUESTER"
  }
}
EOF

echo -e "\e[32mStarting PFX certificate enrollment...\e[0m"

RESPONSE=$(curl -s -X POST "$KEYFACTOR_URL/KeyfactorApi/Enrollment/PFX" \
  -H "Authorization: Basic $AUTH" \
  -H "Accept: application/json" \
  -H "x-certificateformat: PFX" \
  -H "X-Keyfactor-Requested-With: XMLHttpRequest" \
  -H "Content-Type: application/json" \
  ${HTTPS_PROXY:+-x $HTTPS_PROXY} \
  -d @payload.json)

echo -e "\e[32mEnrollment completed.\e[0m"
echo "$RESPONSE" > response.json

jq -r '{
  SerialNumber: .CertificateInformation.SerialNumber,
  KeyfactorId: .CertificateInformation.KeyfactorId,
  IssuerDN: .CertificateInformation.IssuerDN,
  Thumbprint: .CertificateInformation.Thumbprint,
  RequestDisposition: .CertificateInformation.RequestDisposition
}' response.json > certinfo.json

THUMBPRINT=$(jq -r '.Thumbprint' certinfo.json)

echo -e "\e[32mDownloading certificate from Keyfactor...\e[0m"

curl -s -X POST "$KEYFACTOR_URL/KeyfactorApi/Certificates/recover" \
  ${HTTPS_PROXY:+--proxy "$HTTPS_PROXY"} \
  -H "Authorization: Basic $AUTH" \
  -H "Content-Type: application/json" \
  -H "Accept: application/octet-stream" \
  -H "X-Keyfactor-Requested-With: APIClient" \
  -H "X-CertificateFormat: PFX" \
  -d "{\"Thumbprint\":\"$THUMBPRINT\",\"IncludeChain\":true,\"Password\":\"$PASSWORD\"}" \
  -o "temp_${CN_NAME}.pfx"

echo -e "\e[32mDownload complete. Formatting certificate...\e[0m"

jq -r '.PFX' temp_${CN_NAME}.pfx | base64 -d > ${CN_NAME}.pfx

echo -e "\e[32mFormatting complete.\e[0m"

# Backup JSON and response files
echo -e "\e[32mBacking up JSON & response files...\e[0m"
mkdir -p "$CHANGE_NUMBER"
mv certinfo.json response.json "$CHANGE_NUMBER"
tar -cf "${CHANGE_NUMBER}.tar" "$CHANGE_NUMBER"

echo -e "\e[32mBackup complete. All done!\e[0m"
