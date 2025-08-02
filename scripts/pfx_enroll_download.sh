#!/bin/bash

# Use environment variables (set by Ansible)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
AUTH="${auth:?Must set auth env var}"
KEYFACTOR_URL="${keyfactor_url:?Must set keyfactor_url env var}"
HTTPS_PROXY="${https_proxy:?Must set https_proxy env var}"
TEMPLATE="${template:-WebServer(13Month-ClientandServerAuth)PROD}"
CHANGE_NUMBER="${change_number:?Must set change_number env var}"
CN_NAME="${cn_name:?Must set cn_name env var}"
CA_NAME="${ca_name:?Must set ca_name env var}"
PASSWORD="${password:?Must set password env var}"
METADATA_JSON="${metadata_json:?Must set metadata_json env var}"
DNS_NAMES_JSON="${dns_names_json:?Must set dns_names_json env var}"
IP_ADDRESSES_JSON="${ip_addresses_json:?Must set ip_addresses_json env var}"

# Validate CHANGE_NUMBER format (example CHxxxx)
if [[ ! "$CHANGE_NUMBER" =~ ^CH[0-9]+$ ]]; then
  echo -e "\e[31mInvalid change number format: $CHANGE_NUMBER\e[0m"
  exit 1
fi

echo -e "\e[32mChange Number '$CHANGE_NUMBER' accepted. Proceeding...\e[0m"

# Prepare payload.json dynamically
cat > payload.json <<EOF
{
  "CustomFriendlyName": "$CN_NAME",
  "Subject": "CN=$CN_NAME, OU=AU Technology Services, O=Fidelity National Information Services, L=Melbourne, S=VIC, C=AU",
  "Template": "$TEMPLATE",
  "CertificateAuthority": "$CA_NAME",
  "Password": "$PASSWORD",
  "Timestamp": "$TIMESTAMP",
  "SANs": {
    "DNS": $DNS_NAMES_JSON,
    "IP": $IP_ADDRESSES_JSON
  },
  "Metadata": $METADATA_JSON
}
EOF

echo -e "\e[32mStarting PFX certificate enrollment...\e[0m"

RESPONSE=$(curl -s -X POST "$KEYFACTOR_URL/KeyfactorApi/Enrollment/PFX" \
  -H "Authorization: Basic $AUTH" \
  -H "Accept: application/json" \
  -H "x-certificateformat: PFX" \
  -H "X-Keyfactor-Requested-With: XMLHttpRequest" \
  -H "Content-Type: application/json" \
  -x "$HTTPS_PROXY" \
  -d @payload.json)

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
  --proxy "$HTTPS_PROXY" \
  -H "Authorization: Basic $AUTH" \
  -H "Content-Type: application/json" \
  -H "Accept: application/octet-stream" \
  -H "X-Keyfactor-Requested-With: APIClient" \
  -H "X-CertificateFormat: PFX" \
  -d "{\"Thumbprint\":\"$THUMBPRINT\",\"IncludeChain\":true,\"Password\":\"$PASSWORD\"}" \
  -o "temp_$CN_NAME.pfx"

jq -r '.PFX' "temp_$CN_NAME.pfx" | base64 -d > "$CN_NAME.pfx"

echo -e "\e[32mBacking up JSON and data files...\e[0m"
mkdir -p "$CHANGE_NUMBER"
mv certinfo.json response.json "$CHANGE_NUMBER"
tar -cf "${CHANGE_NUMBER}.tar" "$CHANGE_NUMBER"

echo -e "\e[32mCertificate enrollment and backup complete.\e[0m"
