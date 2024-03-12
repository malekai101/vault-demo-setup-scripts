#!/bin/bash


# This script set a local Vault instance up to work with the code
# at https://github.com/malekai101/vault-sdk-dotnet
# and https://github.com/malekai101/vault-sdk-test

# Set the Vault environmental variables
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="root"

# Set the policy
vault policy write demotransit-decrypt - <<EOF
path "transit/decrypt/orders" {
  capabilities = [ "read", "create", "update" ]
}
EOF

vault policy write demotransit-encrypt - <<EOF
path "transit/encrypt/orders" {
  capabilities = [ "read", "create", "update" ]
}
EOF

# Set up the approle stuff

vault auth enable approle

vault write auth/approle/role/encrole token_ttl=1h token_max_ttl=4h token_policies="demotransit-encrypt"
NETROLE=$(vault read auth/approle/role/encrole/role-id -format=json | jq -r '.data.role_id')
NETSECRET=$(vault write -f auth/approle/role/encrole/secret-id -format=json | jq -r '.data.secret_id')

vault write auth/approle/role/decrole token_ttl=1h token_max_ttl=4h token_policies="demotransit-decrypt"
PYROLE=$(vault read auth/approle/role/decrole/role-id -format=json | jq -r '.data.role_id')
PYSECRET=$(vault write -f auth/approle/role/decrole/secret-id -format=json | jq -r '.data.secret_id')

# Set up the transit stuff

vault secrets enable transit
vault write -f transit/keys/orders

echo ""
echo ".NET"
echo "export ROLEID=\"$NETROLE\""
echo "export VAULTSECRET=\"$NETSECRET\""
echo "Command: dotnet run encrypt 'Bob Jackson' 'Engineer' '123-45-6789'"
echo ""
echo "Python"
echo "export PYROLEID=\"$PYROLE\""
echo "export PYVAULTSECRET=\"$PYSECRET\""
echo "Command: pipenv run python main.py decrypt '{\"Name\":\"Bob Jackson\",\"SSN\":\"string\",\"Job\":\"Engineer\"}'"
