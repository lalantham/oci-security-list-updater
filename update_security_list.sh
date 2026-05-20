#!/bin/bash
# =============================================================================
# update_security_list.sh
# Dynamically updates OCI Security List ingress rules based on your current
# public IP. Preserves existing rules and avoids duplicates.
#
# Usage: ./update_security_list.sh
# =============================================================================

# ── Configuration ─────────────────────────────────────────────────────────────
OCI_CLI="/home/lalantha/Documents/Tools/OCI-CLI/bin/oci"
OCI_CONFIG="--config-file ~/.oci/config_lmlab --profile LMLAB"
SECURITY_LIST_OCID="ocid1.securitylist.oc1.ap-singapore-2.YOUR_SECURITY_LIST_OCID_HERE"
REGION="ap-singapore-2"
# ──────────────────────────────────────────────────────────────────────────────

# Step 1: Get current public IP and format as CIDR
MY_IP=$(curl -s ifconfig.me)
CIDR="$MY_IP/32"
echo "Detected public IP: $CIDR"

# Step 2: Fetch existing security list JSON
$OCI_CLI $OCI_CONFIG network security-list get \
  --security-list-id "$SECURITY_LIST_OCID" \
  --region "$REGION" \
  --output json > full_sl.json

# Step 3: Extract existing ingress and egress rules
EXIST_INGRESS=$(jq '.data.ingressSecurityRules' full_sl.json)
EXIST_EGRESS=$(jq '.data.egressSecurityRules' full_sl.json)

# Step 4: Define new ingress rules
# SSH (TCP 22) and DNS (UDP 53) from current IP only
CURRENT_IP_RULES=$(jq -n --arg cidr "$CIDR" '[
  { protocol: "6",  source: $cidr, sourceType: "CIDR_BLOCK", isStateless: false, tcpOptions: { destinationPortRange: { min: 22, max: 22 } } },
  { protocol: "17", source: $cidr, sourceType: "CIDR_BLOCK", isStateless: false, udpOptions: { destinationPortRange: { min: 53, max: 53 } } }
]')

# HTTP (TCP 80) and HTTPS (TCP 443) open to all
ANYWHERE_RULES=$(jq -n '[
  { protocol: "6", source: "0.0.0.0/0", sourceType: "CIDR_BLOCK", isStateless: false, tcpOptions: { destinationPortRange: { min: 80,  max: 80  } } },
  { protocol: "6", source: "0.0.0.0/0", sourceType: "CIDR_BLOCK", isStateless: false, tcpOptions: { destinationPortRange: { min: 443, max: 443 } } }
]')

# Step 5: Merge and deduplicate rules
merge_rules() {
  local EXISTING=$1
  local NEW=$2
  echo "$EXISTING $NEW" | jq -s 'add | unique_by([
    .protocol,
    .source,
    (.tcpOptions.destinationPortRange.min // 0),
    (.tcpOptions.destinationPortRange.max // 0),
    (.udpOptions.destinationPortRange.min // 0),
    (.udpOptions.destinationPortRange.max // 0)
  ])'
}

# Step 6: Merge existing + new ingress rules
MERGED_WITH_CURR_IP=$(merge_rules "$EXIST_INGRESS" "$CURRENT_IP_RULES")
FINAL_INGRESS_RULES=$(merge_rules "$MERGED_WITH_CURR_IP" "$ANYWHERE_RULES")

# Step 7: Extract metadata to preserve tags and display name
FREEFORM_TAGS=$(jq '.data.freeformTags' full_sl.json)
DEFINED_TAGS=$(jq '.data.definedTags' full_sl.json)
DISPLAY_NAME=$(jq -r '.data."display-name"' full_sl.json)

# Step 8: Save final ingress rules to file
echo "$FINAL_INGRESS_RULES" > security_list.json

# Step 9: Apply updated security list
$OCI_CLI $OCI_CONFIG network security-list update \
  --security-list-id "$SECURITY_LIST_OCID" \
  --region "$REGION" \
  --ingress-security-rules file://security_list.json \
  --egress-security-rules "$EXIST_EGRESS" \
  --freeform-tags "$FREEFORM_TAGS" \
  --defined-tags "$DEFINED_TAGS" \
  --display-name "$DISPLAY_NAME" \
  --force

echo "✅ Security list updated successfully."
