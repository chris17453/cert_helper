# SSL Certificate Management Script

## Author
- Charles Watkins
- Watkins Labs

## Description
This script manages SSL certificates and Certificate Authorities (CAs). It provides various functionalities such as listing certificate authorities, deploying a CA to a remote server, installing a CA on a remote server, creating SSL certificates, deploying SSL certificates to servers, and copying the public key to a remote host for passwordless access.

## Usage
To run the script, execute it in a terminal. You can either choose an action from the menu displayed or provide the choice as a command line argument.

```bash
./ssl_setup.sh [choice]
```

## Options
1. **List Certificate Authorities**: Lists the installed certificate authorities.
2. **Deploy CA to Remote Server**: Deploys the CA to a specified remote server.
3. **Install CA on Remote Server**: Installs the CA on a specified remote server.
4. **Install CA locally**: Installs the CA locally.
5. **Create SSL Certificate**: Creates an SSL certificate for a specified server.
6. **Deploy SSL Certificate to Server**: Deploys an SSL certificate to a specified server.
7. **Copy Public Key to Remote Host for Passwordless Access**: Copies the public key to a remote host for passwordless access.
8. **Create CA Certificate and Intermediate Certificate: Generates a new CA certificate and intermediate certificate.

## Dependencies
- OpenSSL
- scp
- ssh
- ssh-copy-id

## Variables
- REMOTE_USER: Remote server user.
- REMOTE_SSL_DIR: Directory on the remote server where SSL certificates are stored.
- DOMAIN: Base domain name.
- CA_KEY: Path to the CA's private key.
- CA_BUNDLE: Path to the CA's bundle file.
- CA_CERT: Path to the CA's certificate.
- TRUST_ANCHORS: Path to the directory where trust certificates / CAs are stored.
- CONFIG_FILE: Path to the OpenSSL configuration file.
- DAYS_VALID: Number of days the certificate is valid.

## License
This script is released under the [BSD 3 License](LICENSE).
