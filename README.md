# sfcc-user-requests-backend
A backend for SFCC user access requests, integrating a DynamoDB table with RESTful API endpoints and various helper lambdas.

Certificate Requirements

A self-signed certificate keypair is required for JWT tokenized login to Salesforce SFCC-CI (required for user administration). The current keypair is valid until June 13, 2022 (825 days is the maximum allowable expiry).

To create a new keypair, use the following command in the ecs/ directory:

`openssl req -newkey rsa:2048 -nodes -keyout key.pem -x509 -days 365 -out certificate.pem`

Copy / paste the base64 encoded output of the public key (certificate.pem) to the SalesForce Account Manager account page for the sfcc_csr_bulk_user account, and change the following values if necessary:

Token Endpoint Auth Method: private_key_jwt
Access Token Format: JWT






