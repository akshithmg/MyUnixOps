#!/bin/bash

# ENV VARIABLES passed from Ansible environment
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
AUTH="${auth}"
KEYFACTOR_URL="${keyfactor_url}"
HTTPS_PROXY="${https_proxy}"
TEMPLATE="${template}"

# PRE STEP START
if [[ ! "$change_number" =~ ^CH[0-9]+$ ]]; then
    echo -e "\e[32m-----------------------------------------------------------------------------------------\e[0m"
    echo -e "\e[32mPLEASE PROCEED ONLY IF YOU HAVE A VALID & APPROVED CHANGE NUMBER.\e[0m"
    echo -e "\e[32m-----------------------------------------------------------------------------------------\e[0m"
    echo -e "\e[31mEXITING THE SCRIPT EXECUTION.\e[0m"
    exit 1
fi

echo -e "\e[32m-----------------------------------------------------------------------------------------\e[0m"
echo -e "\e[32mCHANGE NUMBER '$change_number' ACCEPTED. PROCEEDING WITH THE SCRIPT.\e[0m"

# IMPLEMENTATION STEP START - ENROLLMENT AND DOWNLOAD

CN_NAME="${cn_name}"
CA_NAME="${ca_name}"
PASSWORD="${password}"

echo -e "\e[32mUSING CN Name: $CN_NAME\e[0m"
echo -e "\e[32mUSING CA Name: $CA_NAME\e[0m"

# Parse DNS and IP lists
IFS=',' read -ra DNS_NAMES <<< "${dns_names}"
IFS=',' read -ra IP_ADDRESSES <<< "${ip_addresses}"

DNS_JSON=$(printf '"%s",' "${DNS_NAMES[@]}" | sed 's/,$//')
IP_JSON=$(printf '"%s",' "${IP_ADDRESSES[@]}" | sed 's/,$//')

echo -e "\e[32m-----------------------------------------------------------------------------------------\e[0m"
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
  "Metadata": $metadata_json
}
EOF

echo -e "\e[32mSTARTING PFX CERTIFICATE ENROLLMENT.\e[0m"
echo -e "\e[32m-----------------------------------------------------------------------------------------\e[0m"

RESPONSE=$(curl -s -X POST "$KEYFACTOR_URL/KeyfactorApi/Enrollment/PFX" \
  -H "Authorization: Basic $AUTH" \
  -H "Accept: application/json" \
  -H "x-certificateformat: PFX" \
  -H "X-Keyfactor-Requested-With: XMLHttpRequest" \
  -H "Content-Type: application/json" \
  -x "$HTTPS_PROXY" \
  -d @payload.j
