#!/usr/bin/env bash
set -euo pipefail

if [ -z "${HACKAGE_TOKEN:-}" ]; then
  echo "::error::Token is empty"
  exit 1
fi

if [ ! -f "${PACKAGE_PATH}" ]; then
  echo "::error::Package tarball not found at ${PACKAGE_PATH}"
  exit 1
fi

HACKAGE_AUTH_HEADER="Authorization: X-ApiKey ${HACKAGE_TOKEN}"
PACKAGE_NAME=$(basename "${PACKAGE_PATH%.*.*}")
ALREADY_PUBLISHED=false

if [ "${PUBLISH}" == "true" ]; then
  TARGET_URL="${HACKAGE_SERVER}/packages/upload"
  PACKAGE_URL="${HACKAGE_SERVER}/package/${PACKAGE_NAME}"

  echo "Publishing ${PACKAGE_NAME} to ${TARGET_URL}"

  PUBLISH_RESPONSE=$(curl -sS -w $'\n%{http_code}' -X POST --header "${HACKAGE_AUTH_HEADER}" "${TARGET_URL}" -F "package=@${PACKAGE_PATH}")
  PUBLISH_HTTP_CODE=$(tail -n1 <<< "${PUBLISH_RESPONSE}")
  PUBLISH_BODY=$(sed '$d' <<< "${PUBLISH_RESPONSE}")

  case "${PUBLISH_HTTP_CODE}" in
    2??)
      echo "Published ${PACKAGE_URL}"
      ;;
    403)
      echo "Publish attempt for ${PACKAGE_NAME} returned 403; checking whether it already exists on Hackage"
      EXISTENCE_HTTP_CODE=$(curl -sS -o /dev/null -w '%{http_code}' --header "${HACKAGE_AUTH_HEADER}" --anyauth -XGET "${PACKAGE_URL}")
      if [ "${EXISTENCE_HTTP_CODE}" == "200" ]; then
        echo "Package ${PACKAGE_NAME} was already published on Hackage. Original response: ${PUBLISH_BODY}"
        ALREADY_PUBLISHED=true
      else
        echo "::error::Publish of ${PACKAGE_NAME} failed with HTTP 403 and it does not appear to already exist (existence check returned ${EXISTENCE_HTTP_CODE}). Response: ${PUBLISH_BODY}"
        exit 1
      fi
      ;;
    *)
      echo "::error::Publish of ${PACKAGE_NAME} failed with HTTP ${PUBLISH_HTTP_CODE}. Response: ${PUBLISH_BODY}"
      exit 1
      ;;
  esac

  DOCS_URL="${PACKAGE_URL}/docs"
else
  TARGET_URL="${HACKAGE_SERVER}/packages/candidates"
  PACKAGE_URL="${HACKAGE_SERVER}/package/${PACKAGE_NAME}/candidate"
  DOCS_URL="${PACKAGE_URL}/docs"

  echo "Uploading candidate ${PACKAGE_NAME} to ${TARGET_URL}"
  curl -X POST -f --header "${HACKAGE_AUTH_HEADER}" "${TARGET_URL}" -F "package=@${PACKAGE_PATH}"
  echo "Uploaded ${PACKAGE_URL}"
fi

echo "already-published=${ALREADY_PUBLISHED}" >> "${GITHUB_OUTPUT}"

if [ -n "${DOC_PATH:-}" ] && [ -f "${DOC_PATH}" ]; then
  echo "Uploading documentation for ${PACKAGE_NAME} to ${DOCS_URL}"

  set +e
  DOC_RESPONSE=$(curl -sS -X PUT -f \
    -H 'Content-Type: application/x-tar' \
    -H 'Content-Encoding: gzip' \
    -H "${HACKAGE_AUTH_HEADER}" \
    --data-binary "@${DOC_PATH}" \
    "${DOCS_URL}")
  DOC_CURL_EXIT=$?
  set -e

  if [ "${DOC_CURL_EXIT}" -eq 56 ] && echo "${DOC_RESPONSE}" | grep -q "Successfully uploaded documentation"; then
    echo "Note: curl exited with 56 (chunked-encoding parse error) after Hackage confirmed the upload. This is a known Hackage response-truncation quirk, not an actual failure - treating as success."
  elif [ "${DOC_CURL_EXIT}" -ne 0 ]; then
    echo "${DOC_RESPONSE}"
    exit "${DOC_CURL_EXIT}"
  fi

  echo "Uploaded documentation to ${DOCS_URL}"
fi
