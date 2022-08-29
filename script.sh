
# This is the script for the cloud-init user-data file.
# Description:
#   This script will install the following packages:
#   To run, this shell script depends on command-line curl,openssl, and jq.
#
# References:
#   https://czak.pl/2015/09/15/s3-rest-api-with-curl.html
#   https://gist.github.com/adrianbartyczak/1a51c9fa2aae60d860ca0d70bbc686db
#

# API_LINK is an environment variable
# Extract the JSON values from the API response (input_file_path and input_text)
response=$(curl -s -X GET $API_LINK/items/$KEY_ID)
input_file_path=$(echo $response | jq -r '.Item.input_file_path')
input_text=$(echo $response | jq -r '.Item.input_text')

echo input_file_path: $input_file_path
echo input_text: $input_text

## bucket name it's the first part of the input_file_path (before the first /)
bucket=$(echo $input_file_path | cut -d'/' -f1)
## file name it's the second part of the input_file_path (after the first /)
file_name=$(echo $input_file_path | cut -d'/' -f2)

## destination path will be located in the /tmp folder
dest_path=/tmp/$file_name

# set -x
set -e

script="${0##*/}"
usage="USAGE: $script <bucket> <region> <source-file> <dest-path>

Example: $script dev.build.artifacts us-east-1 /jobs/dev-job/1/dist.zip ./dist.zip"

[ -z "$AWS_ACCESS_KEY_ID" -o -z "$AWS_SECRET_ACCESS_KEY" ] \
    && printf "ERROR: AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables must be defined.\n" && exit 1

[ ! type openssl 2>/dev/null ] && echo "openssl is required and must be installed" && exit 1
[ ! type curl 2>/dev/null ] && echo "curl is required and must be installed" && exit 1


AWS_SERVICE='s3'
AWS_REGION="${REGION}"
AWS_SERVICE_ENDPOINT_URL="${AWS_SERVICE}.${AWS_REGION}.amazonaws.com"
AWS_S3_BUCKET_NAME="${bucket}"
AWS_S3_PATH="$(echo ${file_name} | sed 's;^\([^/]\);/\1;')"
AWS_S3_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"

# Create an SHA-256 hash in hexadecimal.
# Usage:
#   hash_sha256 <string>
function hash_sha256 {
  printf "${1}" | openssl dgst -sha256 | sed 's/^.* //'
}

# Create an SHA-256 hmac in hexadecimal.
# Usage:
#   hmac_sha256 <key> <data>
function hmac_sha256 {
  printf "${2}" | openssl dgst -sha256 -mac HMAC -macopt "${1}" | sed 's/^.* //'
}

CURRENT_DATE_DAY="$(date -u '+%Y%m%d')"
CURRENT_DATE_ISO8601="${CURRENT_DATE_DAY}T$(date -u '+%H%M%S')Z"

HTTP_REQUEST_PAYLOAD_HASH="$(printf "" | openssl dgst -sha256 | sed 's/^.* //')"
HTTP_CANONICAL_REQUEST_URI="/${AWS_S3_BUCKET_NAME}${AWS_S3_PATH}"
HTTP_REQUEST_CONTENT_TYPE='application/octet-stream'

HTTP_CANONICAL_REQUEST_HEADERS="content-type:${HTTP_REQUEST_CONTENT_TYPE}
host:${AWS_SERVICE_ENDPOINT_URL}
x-amz-content-sha256:${HTTP_REQUEST_PAYLOAD_HASH}
x-amz-date:${CURRENT_DATE_ISO8601}"
# Note: The signed headers must match the canonical request headers.
HTTP_REQUEST_SIGNED_HEADERS="content-type;host;x-amz-content-sha256;x-amz-date"
HTTP_CANONICAL_REQUEST="GET
${HTTP_CANONICAL_REQUEST_URI}\n
${HTTP_CANONICAL_REQUEST_HEADERS}\n
${HTTP_REQUEST_SIGNED_HEADERS}
${HTTP_REQUEST_PAYLOAD_HASH}"

# Create the signature.
# Usage:
#   create_signature
function create_signature {
  stringToSign="AWS4-HMAC-SHA256\n${CURRENT_DATE_ISO8601}\n${CURRENT_DATE_DAY}/${AWS_REGION}/${AWS_SERVICE}/aws4_request\n$(hash_sha256 "${HTTP_CANONICAL_REQUEST}")"
  dateKey=$(hmac_sha256 key:"AWS4${AWS_SECRET_ACCESS_KEY}" "${CURRENT_DATE_DAY}")
  regionKey=$(hmac_sha256 hexkey:"${dateKey}" "${AWS_REGION}")
  serviceKey=$(hmac_sha256 hexkey:"${regionKey}" "${AWS_SERVICE}")
  signingKey=$(hmac_sha256 hexkey:"${serviceKey}" "aws4_request")

  printf "${stringToSign}" | openssl dgst -sha256 -mac HMAC -macopt hexkey:"${signingKey}" | sed 's/(stdin)= //'
}

SIGNATURE="$(create_signature)"
HTTP_REQUEST_AUTHORIZATION_HEADER="\
AWS4-HMAC-SHA256 Credential=${AWS_ACCESS_KEY_ID}/${CURRENT_DATE_DAY}/\
${AWS_REGION}/${AWS_SERVICE}/aws4_request, \
SignedHeaders=${HTTP_REQUEST_SIGNED_HEADERS}, Signature=${SIGNATURE}"

[ -d $dest_path ] && OUT_FILE="$dest_path/$(basename $AWS_S3_PATH)" || OUT_FILE=$dest_path
echo "Downloading https://${AWS_SERVICE_ENDPOINT_URL}${HTTP_CANONICAL_REQUEST_URI} to $OUT_FILE"

curl "https://${AWS_SERVICE_ENDPOINT_URL}${HTTP_CANONICAL_REQUEST_URI}" \
    -H "Authorization: ${HTTP_REQUEST_AUTHORIZATION_HEADER}" \
    -H "content-type: ${HTTP_REQUEST_CONTENT_TYPE}" \
    -H "x-amz-content-sha256: ${HTTP_REQUEST_PAYLOAD_HASH}" \
    -H "x-amz-date: ${CURRENT_DATE_ISO8601}" \
    -f -S -o ${OUT_FILE}

# This will append the input text to the file
echo ":" $input_text >> $dest_path

# Display the new file

cat $dest_path

# Updating the DynamoDB table with the new file trough gateway API (PATCH)
# We will add a new key pair  to the item named 'output_file_path': input_file_path

curl -X PATCH \
  $API_LINK/items/$KEY_ID \
  -H 'Content-Type: application/json' \
  -H 'cache-control: no-cache' \
  -d '{
    "output_file_path": "'$input_file_path'"
    }'


# Updating th S3 bucket with the new file
contentType="application/x-compressed-tar"
dateValue=`date -R`
filepath="/${bucket}/${file_name}"
signature_string="PUT\n\n${contentType}\n${dateValue}\n${filepath}"
signature_hash=`echo -en ${signature_string} | openssl sha1 -hmac ${AWS_SECRET_ACCESS_KEY} -binary | base64`

echo "curl -X PUT -T $dest_path https://${bucket}.s3.amazonaws.com/${file_name} -H \"Host: ${bucket}.s3.amazonaws.com\" -H \"Date: ${dateValue}\" -H \"Content-Type: ${contentType}\" -H \"Authorization: AWS ${AWS_ACCESS_KEY_ID}:${signature_hash}\""
curl -X PUT -T "${dest_path}" \
  -H "Host: ${bucket}.s3.amazonaws.com" \
  -H "Date: ${dateValue}" \
  -H "Content-Type: ${contentType}" \
  -H "Authorization: AWS ${AWS_ACCESS_KEY_ID}:${signature_hash}" \
  https://${bucket}.s3.amazonaws.com/${file_name}

echo "Done"















