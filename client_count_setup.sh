#! /usr/bin/env bash

set -e
readonly NSCAP=50
readonly USERCOUNT=3

##########################################################################################
# This is a setup script to test client counts.  It builds namespaces, adds auth methods, 
# and builds tokens to create clients.
##########################################################################################
prep() {
    # Input is namespace width and namespace depth.  Capping each at 50 for now.

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
    #local name=$(curl -sS https://random-word-api.herokuapp.com/word | jq ".[0]" 2>/dev/null) 
    local name=$(curl -sS https://random-word-api.vercel.app/api | jq ".[0]" 2>/dev/null)
    echo "$name" | tr -d '"'
}

get_names() {
    #local names=($(curl -Ss https://random-word-api.herokuapp.com/word\?number=$1 | jq -r ".[]" | tr '\n' ' ' 2>/dev/null))
    local names=($(curl -Ss https://random-word-api.vercel.app/api?words=$1 | jq -r ".[]" | tr '\n' ' ' 2>/dev/null))
    echo "${names[@]}"
}

# One input, namespace name
add_userpass_user() {
    echo ""
}

# One input, namespace name
add_approle_user() {
    echo ""
}

# One input, namespace name
populate_auth() {
    # create userpass mount
    VAULT_NAMESPACE=$1 vault auth enable userpass >/dev/null 2>&1
    # create approle mount 
    VAULT_NAMESPACE=$1 vault auth enable approle >/dev/null 2>&1
}


prep $1 $2

#Build the namespace list - old
#TOPLVLNS=()
#for ((i = 0 ; i < $NSWIDTH ; i++)); do
#  TOPLVLNS[$i]=$(get_name)
#done

# Build the namespace list
TOPLVLNS=($(get_names $NSWIDTH))

for i in "${TOPLVLNS[@]}"; do
  vault namespace create "$i" >/dev/null 2>&1
  echo "Created namespace $i"
  populate_auth "$i"
  # build and populate child namespaces
  CHILDNS=($(get_names $NSDEPTH))
  for j in "${CHILDNS[@]}"; do
    VAULT_NAMESPACE=$i vault namespace create "$j" >/dev/null 2>&1
    echo "Created namespace $i/$j"
    populate_auth "$i/$j"
  done
done

# Build the namespaces
#result=$(get_name)
#echo "The name is $result".


#curl -sS https://random-word-api.herokuapp.com/word | jq ".[0]"

# Build the auth methods and users for the namespaces

