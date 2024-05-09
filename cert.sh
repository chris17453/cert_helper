#!/bin/bash
# Author: Charles Watkins
# Organization: Watkins Labs
# Created: 2024-05-09
# Description: 
#    This script manages SSL certificates and Certificate Authorities (CAs).
#    It lists certificate authorities, deploys a CA to a remote server, installs a CA on
#    a remote server, creates SSL certificates, and deploys SSL certificates to servers.
#    The script prompts the user to choose an action from a menu or accepts the choice
#    as a command line argument.

# Error handling function
handle_error() {
    local error_code="$?"
    echo "Error occurred on line $1: $2"
    exit "$error_code"
}
trap 'handle_error $LINENO "$BASH_COMMAND"' ERR

# Variables
REMOTE_USER="root"                  
REMOTE_PATH="/root/" 
REMOTE_SSL_DIR="/etc/ssl/"                                    # where we are putting the cert on the server
DOMAIN="watkinslabs.com"                                      # The base domain name
CA_NAME="certs/CA/WatkinsLabsCA"
CA_KEY="$CA_NAME.key"                                         # Path to your CA's private key
CA_CERT="$CA_NAME.crt"                                        # Path to your CA's certificate
INTERMEDIATE_NAME="certs/CA/WatkinsLabsCA_-_Intermediate"
INTERMEDIATE_KEY="$INTERMEDIATE_NAME.key"                     # Path to your CA's intermediate private key
INTERMEDIATE_CSR="$INTERMEDIATE_NAME.csr"                     # Path to your CA's intermediate signing request
INTERMEDIATE_CERT="$INTERMEDIATE_NAME.crt"                    # Path to your CA's intermediate certificate
CA_BUNDLE="certs/CA/WatkinsLabsCA-All.pem"                    # Path to your CA's bundle file
TRUST_ANCHORS=/etc/pki/ca-trust/source/anchors/               # path to where the trust certs /ca's are stored
CONFIG_FILE="/etc/ssl/openssl.cnf"                            # OpenSSL configuration file if any specific configurations are needed
DAYS_VALID=3650                                               # Number of days the certificate is valid



# Function to create a new CA certificate and intermediate certificate
create_ca_cert() {

    read -p "Enter CA Organization Name: " CA_ORGANIZATION
    read -p "Enter CA Common Name: " CA_COMMON_NAME
    read -p "Enter Intermediate Organization Name: " INTERMEDIATE_ORGANIZATION
    read -p "Enter Intermediate Common Name: " INTERMEDIATE_COMMON_NAME

    # Generate CA private key
    openssl genrsa -out "$CA_KEY" 4096

    # Generate CA certificate
    openssl req -new -x509 -key "$CA_KEY" -out "$CA_CERT" -days 365 -subj "/O=${CA_ORGANIZATION}/CN=${CA_COMMON_NAME}"

    # Generate intermediate private key
    openssl genrsa -out "$INTERMEDIATE_KEY" 4096

    # Generate intermediate certificate signing request (CSR)
    openssl req -new -key "$INTERMEDIATE_KEY" -out "$INTERMEDIATE_CSR" -subj "/O=${INTERMEDIATE_ORGANIZATION}/CN=${INTERMEDIATE_COMMON_NAME}"

    # Sign the intermediate certificate with the CA
    openssl x509 -req -in "$INTERMEDIATE_CSR" -CA "$CA_CERT" -CAkey "$CA_KEY" -CAcreateserial -out "$INTERMEDIATE_CERT" -days 365 -sha256

    cat "$CA_CERT" "$INTERMEDIATE_CERT" > "$CA_BUNDLE"

    echo "New CA certificate and intermediate certificate have been created."
}



# Function to list certificate authorities
list_ca() {
    awk -v cmd='openssl x509 -noout -subject' '/BEGIN/{close(cmd)};{print | cmd}' < /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
}

# Function to copy files to remote server and run installation script

deploy_ca() {
    read -p "Enter remote host: " REMOTE_HOST
    scp $CA_BUNDLE "$REMOTE_USER@$REMOTE_HOST:$TRUST_ANCHORS"
    scp cert.sh "$REMOTE_USER@$REMOTE_HOST:/usr/bin/"
}

# Function to copy files to remote server and run installation script
install_ca() {
    read -p "Enter remote host: " REMOTE_HOST
    ssh "$REMOTE_USER@$REMOTE_HOST" "bash 'cert.sh' 4"
    echo "Installation script has been executed on the remote server."
}

install_ca_local() {
    update-ca-trust
}

# Function to create SSL certificates
create_ssl_cert() {
    read -p "Enter server IP or DNS sub domain: " SERVER_NAME
    SERVER_NAME="$SERVER_NAME.$DOMAIN"
    CERT_DIR="./certs/${SERVER_NAME}"
    mkdir -p "$CERT_DIR"

    # Declare an associative array to hold the subject fields
    declare -A subject_fields

    # Extract the subject line, clean it up, and convert it into key-value pairs
    while IFS='=' read -r key value; do
        # Remove leading and trailing spaces from key and value
        key=$(echo "$key" | sed 's/^\s*//;s/\s*$//')
        value=$(echo "$value" | sed 's/^\s*//;s/\s*$//')
        
        # Add to associative array
        subject_fields["$key"]="$value"
    done < <(openssl x509 -in "$INTERMEDIATE_CERT" -noout -subject |  sed 's/subject=//g' | sed 's/ *= */=/g' | tr ',' '\n')

    # Print all keys and values to verify
    for key in "${!subject_fields[@]}"; do
        echo "$key,${subject_fields[$key]}"
    done

    COUNTRY=${subject_fields['C']}
    STATE=${subject_fields['ST']}
    CITY=${subject_fields['L']}
    ORGANIZATION=${subject_fields['O']}
    DEPARTMENT=${subject_fields['OU']}
    EMAIL=${subject_fields['emailAddress']}

    # Generate a private key for the server
    openssl genrsa -out "${CERT_DIR}/${SERVER_NAME}.key" 2048

    # Create a Certificate Signing Request (CSR)
    openssl req -new -key "${CERT_DIR}/${SERVER_NAME}.key" -out "${CERT_DIR}/${SERVER_NAME}.csr" \
        -subj "/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORGANIZATION}/OU=${DEPARTMENT}/CN=${SERVER_NAME}/emailAddress=${EMAIL}"

    # Sign the CSR with your CA to get the SSL certificate
    openssl x509 -req -in "${CERT_DIR}/${SERVER_NAME}.csr" -CA "$INTERMEDIATE_CERT" -CAkey "$INTERMEDIATE_KEY" -CAcreateserial \
        -out "${CERT_DIR}/${SERVER_NAME}.crt" -days $DAYS_VALID -sha256 -extfile "${CONFIG_FILE}" -extensions v3_req

    # Verify the SSL certificate
    VERIFY_OUTPUT=$(openssl verify -CAfile "$CA_BUNDLE" "$INTERMEDIATE_CERT" "${CERT_DIR}/${SERVER_NAME}.crt")
    if echo "$VERIFY_OUTPUT" | grep -q "OK$"; then
        echo "SSL Certificate for ${SERVER_NAME} has been created and verified successfully."
    else
        echo "Error: SSL Certificate verification for ${SERVER_NAME} failed."
        echo "Details: $VERIFY_OUTPUT"
        exit 1  # Exit script with an error status
    fi
}

# Function to deploy SSL certificates to a server
deploy_ssl_cert() {
    read -p "Enter remote host: " REMOTE_HOST
    read -p "Enter server IP or DNS sub domain: " SERVER_NAME
    SERVER_NAME="$SERVER_NAME.$DOMAIN"
    CERT_DIR="./certs/${SERVER_NAME}"

    # Copy certificate files to the remote server
    scp "${CERT_DIR}/${SERVER_NAME}.crt" "${CERT_DIR}/${SERVER_NAME}.key" "$REMOTE_USER@$REMOTE_HOST:${REMOTE_SSL_DIR}/${SERVER_NAME}/"
    echo "SSL Certificate for ${SERVER_NAME} has been deployed to the server."
}


# Function to copy public key to the remote host for passwordless access
copy_public_key() {
    read -p "Enter remote host: " REMOTE_HOST
    ssh-copy-id "$REMOTE_USER@$REMOTE_HOST"
    echo "Public key has been copied to the remote host for passwordless access."
}

# Main function
main() {
    if [[ -z "$1" ]]; then
       echo "SSL Certificate Management Menu:"
       echo "1. List Certificate Authorities"
       echo "2. Deploy CA to Remote Server"
       echo "3. Install CA on Remote Server"
       echo "4. Install CA locally/Update CA Trust"
       echo "5. Create SSL Certificate"
       echo "6. Deploy SSL Certificate to Server"
       echo "7. Copy Public key to Remote Server"
       echo "8. Create CA and Intermediate CA"
       read -p "Enter choice: " choice
    else
        choice=$1
    fi


    case $choice in
        1) list_ca ;;
        2) deploy_ca ;;
        3) install_ca ;;
        4) install_ca_local ;;
        5) create_ssl_cert ;;
        6) deploy_ssl_cert ;;
        7) copy_public_key ;;
        8) create_ca_cert ;;
        *) 
            echo "Invalid choice. Exiting."s
            exit 1 ;;

    esac
}

main "$@"
