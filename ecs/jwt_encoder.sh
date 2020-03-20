#!/usr/bin/env bash
#
# JWT Encoder Bash Script
#

SIGNATURE_FILE="key.pem"

# The public key functions as the secret for the signature.
# secret='SOME SECRET'

# Static header fields.
header='{
    "alg": "RS256"
}'

payload='{
    "iss": "9ea5c0b3-3dad-4338-a762-c7d760ec7d88",
	"aud": "account.demandware.com",
	"sub": "sfcc_csr_bulk_user"
}'

# Use jq to set`exp`
# fields on the payload using the current time.
# `exp` is now + 180 seconds (3 min).
payload=$(
	echo "${payload}" | jq --arg time_str "$(date +%s)" \
	'
	($time_str | tonumber) as $time_num
	| .exp=($time_num + 180)
	'
)

base64_encode()
{
	declare input=${1:-$(</dev/stdin)}
	# Use `tr` to URL encode the output from base64.
	printf '%s' "${input}" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n'
}

json() {
	declare input=${1:-$(</dev/stdin)}
	printf '%s' "${input}" | jq -c .
}

# Not used - the public key signs the cert
# hmacsha256_sign()
# {
#	declare input=${1:-$(</dev/stdin)}
#	printf '%s' "${input}" | openssl dgst -binary -sha256 -hmac "${secret}"
# }

header_base64=$(echo "${header}" | json | base64_encode)
payload_base64=$(echo "${payload}" | json | base64_encode)

header_payload=$(echo "${header_base64}.${payload_base64}")
#signature=$(echo "${header_payload}" | hmacsha256_sign | base64_encode)
rawSignature=`echo $(cat $SIGNATURE_FILE)`
prefix="-----BEGIN PRIVATE KEY-----"
suffix="-----END PRIVATE KEY-----"
noPrefix=${rawSignature#"$prefix"}
spaceySignature=${noPrefix%"$suffix"}
signature=`echo "${spaceySignature// /}"`
signature_base64=$(echo "${signature}" | base64_encode)

echo "${header_payload}.${signature_base64}"