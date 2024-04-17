#!/bin/bash

#
# This script sets up a few kmip mounts on an existing Vault Enterprise
# server.  It is used to test KMIP client count utilities.
#

prep() {
    # making sure are set to talk to vault.

    if [[ -z $(echo $VAULT_ADDR) ]]; then
        echo "The Vault address must be set."
        exit 1
    fi

    if [[ -z $(echo $VAULT_TOKEN) ]]; then
        echo "The Vault token must be set."
        exit 1
    fi

    # The script can still fail if not KMIP license but I don't know how to check that.
    if [[ $(vault status -format=json | jq -r ".version") =~ .*ent.* ]]; then
        if [[ $(vault read /sys/license/status -format=json | jq '.data.autoloaded.features | any(index("KMIP")) ') == "true" ]]; then
            echo "Vault Enterprise with KMIP"
        else
            echo "Vault Enterprise but no KMIP license"
            exit 1
        fi
    else
        echo "Could not connect or Vault is not Enterprise."
        exit 1
    fi
}

prepare_kmip() {
    # This is static for now.  We just need a few mounts to test.

    # Prepare the first mount in root namespace
    vault secrets enable kmip >/dev/null 2>&1
    vault write kmip/config listen_addrs=0.0.0.0:5696 server_hostnames=0.0.0.0 >/dev/null 2>&1
    vault write -f kmip/scope/toddy >/dev/null 2>&1
    vault write kmip/scope/toddy/role/joe operation_all=true >/dev/null 2>&1
    vault write -format=json kmip/scope/toddy/role/joe/credential/generate format=pem >/dev/null 2>&1
    vault write kmip/scope/toddy/role/jed operation_all=true >/dev/null 2>&1
    vault write -format=json kmip/scope/toddy/role/jed/credential/generate format=pem >/dev/null 2>&1
    vault write -f kmip/scope/lemons >/dev/null 2>&1
    vault write kmip/scope/lemons/role/meyer operation_all=true >/dev/null 2>&1
    vault write -format=json kmip/scope/lemons/role/meyer/credential/generate format=pem >/dev/null 2>&1
    # Scope with a role but no keys 
    vault write -f kmip/scope/oranges >/dev/null 2>&1
    vault write kmip/scope/oranges/role/mandarin operation_all=true >/dev/null 2>&1
    # Scope with no roles
    vault write -f kmip/scope/apples >/dev/null 2>&1

    # Alternate mount path in root namespace
    vault secrets enable -path=olympia kmip >/dev/null 2>&1
    vault write olympia/config listen_addrs=0.0.0.0:5697 server_hostnames=0.0.0.0 >/dev/null 2>&1
    vault write -f olympia/scope/upper >/dev/null 2>&1
    vault write olympia/scope/upper/role/zeus operation_all=true >/dev/null 2>&1
    vault write -format=json olympia/scope/upper/role/zeus/credential/generate format=pem >/dev/null 2>&1

    # A new namespace
    vault namespace create doors >/dev/null 2>&1
    VAULT_NAMESPACE=doors vault secrets enable kmip >/dev/null 2>&1
    VAULT_NAMESPACE=doors vault write -f kmip/scope/band >/dev/null 2>&1
    VAULT_NAMESPACE=doors vault write kmip/config listen_addrs=0.0.0.0:5699 server_hostnames=0.0.0.0 >/dev/null 2>&1
    VAULT_NAMESPACE=doors vault write -f kmip/scope/band >/dev/null 2>&1
    VAULT_NAMESPACE=doors vault write kmip/scope/band/role/jim operation_all=true >/dev/null 2>&1
    VAULT_NAMESPACE=doors vault write -format=json kmip/scope/band/role/jim/credential/generate format=pem >/dev/null 2>&1
    VAULT_NAMESPACE=doors vault write kmip/scope/band/role/ray operation_all=true >/dev/null 2>&1
    VAULT_NAMESPACE=doors vault write -format=json kmip/scope/band/role/ray/credential/generate format=pem >/dev/null 2>&1

}

main() {
    prep
    prepare_kmip
    echo "KMIP loaded"
}

main