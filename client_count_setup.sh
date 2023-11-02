#! /usr/bin/env bash

set -e
readonly NSCAP=10

##########################################################################################
# This is a setup script to test client counts.  It builds namespaces, adds auth methods, 
# and builds tokens to create clients.  The number of client per auth method is random
# betwen 1 and 9.  A token is created 50% of the time.
#
# To run it you need Vault in your path and an running Enterprise instance of Vault.  Only
# use a lab instance because this script will add sorts of stuff.  You need VAULT_ADDR and 
# VAULT_TOKEN defined.  It won't work on HCP because the admin namespace is not included
# in the commands. 
##########################################################################################

prep() {
    # Input is namespace width and namespace depth.  Capping each at 10 for now.

    if [[ -z $(echo $VAULT_ADDR) ]]; then
        echo "The Vault address must be set."
        exit 1
    fi

    if [[ -z $(echo $VAULT_TOKEN) ]]; then
        echo "The Vault token must be set."
        exit 1
    fi

    if [[ -n $1 ]]; then
        if [[ $1 -gt $NSCAP ]]; then
            NSWIDTH=$NSCAP 
        else
            NSWIDTH=$1
        fi
    else
        echo "Namespace width not supplied"
        NSWIDTH=5
    fi
    echo "Namespace width set to $NSWIDTH"


    if [[ -n $2 ]]; then
        if [[ $2 -gt $NSCAP ]]; then
            NSDEPTH=$NSCAP 
        else
            NSDEPTH=$2
        fi
    else
        echo "Namespace depth not supplied"
        NSDEPTH=5
    fi
    echo "Namespace depth set to $NSDEPTH"
}

get_name() {
    local name=$(curl -sS https://random-word-api.vercel.app/api | jq ".[0]" 2>/dev/null)
    echo "$name" | tr -d '"'
}

get_names() {
    local names=($(curl -Ss https://random-word-api.vercel.app/api?words=$1 | jq -r ".[]" | tr '\n' ' ' 2>/dev/null))
    echo "${names[@]}"
}

# One input, namespace name
add_userpass_user() {
    USERS=($(get_names $(echo $((1 + $RANDOM%8)))))
    for USER in "${USERS[@]}"; do
        # create users and login to create a client
        VAULT_NAMESPACE=$1 vault write auth/userpass/users/$USER password="password" policies="default,secret-reader" > /dev/null 2>&1
        TOKEN=$(VAULT_NAMESPACE=$1 vault login -method=userpass -token-only username="$USER" password="password" 2> /dev/null)
        VAULT_NAMESPACE=$1 VAULT_TOKEN=$TOKEN vault kv get secrets/test-secret > /dev/null 2>&1
    done
}

# One input, namespace name
add_approle_user() {
    USERS=($(get_names $(echo $((1 + $RANDOM%8)))))
    for USER in "${USERS[@]}"; do
        VAULT_NAMESPACE=$1 vault write auth/approle/role/$USER policies="default,secret-reader" > /dev/null 2>&1
        ROLEID=$(VAULT_NAMESPACE=$1 vault read -field=role_id auth/approle/role/$USER/role-id 2> /dev/null)
        SECRETID=$(VAULT_NAMESPACE=$1 vault write -f -field=secret_id auth/approle/role/$USER/secret-id 2> /dev/null)
        TOKEN=$(VAULT_NAMESPACE=$1 vault write -field=token auth/approle/login role_id=$ROLEID secret_id=$SECRETID 2> /dev/null)
        VAULT_NAMESPACE=$1 VAULT_TOKEN=$TOKEN vault kv get secrets/test-secret > /dev/null 2>&1
    done
}

# One input, namespace name
add_token_clients() {
    # 50-50 chance we create a non-entity client
    TOKEN_COUNT=$(echo $((1 + $RANDOM%9)))
    if [[ $(($TOKEN_COUNT % 2)) -eq 0 ]]; then
        TOKEN=$(VAULT_NAMESPACE=$1 vault token create -field=token -policy="default" -policy="secret-reader" 2> /dev/null)
        VAULT_NAMESPACE=$1 VAULT_TOKEN=$TOKEN vault kv get secrets/test-secret > /dev/null 2>&1
    fi
}

# One input, namespace name
populate_ns() {
    # create the secret mount
    VAULT_NAMESPACE=$1 vault secrets enable -path=secrets kv-v2 > /dev/null 2>&1
    # create the policy 
    VAULT_NAMESPACE=$1 vault policy write secret-reader - <<- EOH > /dev/null 2>&1
    path "secrets/data/test-secret" {
        capabilities = ["create", "read", "update", "patch", "delete", "list"]
    }
EOH
    # add the secret
    VAULT_NAMESPACE=$1 vault kv put -mount=secrets test-secret foo=a bar=b > /dev/null 2>&1

    # create userpass mount
    VAULT_NAMESPACE=$1 vault auth enable userpass >/dev/null 2>&1
    add_userpass_user $1
    # create approle mount 
    VAULT_NAMESPACE=$1 vault auth enable approle >/dev/null 2>&1
    add_approle_user $1
    # create some non-entity clients
    add_token_clients $1
}


prep $1 $2

# Build the namespace list
TOPLVLNS=($(get_names $NSWIDTH))

for i in "${TOPLVLNS[@]}"; do
  # build and populate the top level namespaces
  vault namespace create "$i" >/dev/null 2>&1
  echo "Created namespace $i"
  populate_ns "$i"
  echo "Namespace $i is provisioned."
  # build and populate child namespaces
  CHILDNS=($(get_names $NSDEPTH))
  for j in "${CHILDNS[@]}"; do
    VAULT_NAMESPACE=$i vault namespace create "$j" >/dev/null 2>&1
    echo "Created namespace $i/$j"
    populate_ns "$i/$j"
    echo "Namespace $i/$j is provisioned."
  done
done

exit 0

