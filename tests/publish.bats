#!/usr/bin/env bats

setup() {
  export PATH="${BATS_TEST_DIRNAME}/stubs:${PATH}"
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/publish.sh"
  export SCRIPT
  GITHUB_OUTPUT="${BATS_TEST_TMPDIR}/github_output"
  export GITHUB_OUTPUT
  : > "${GITHUB_OUTPUT}"
  CALLS_LOG="${BATS_TEST_TMPDIR}/calls.log"
  export CALLS_LOG
  : > "${CALLS_LOG}"
  export HACKAGE_TOKEN="test-token"
  export HACKAGE_SERVER="https://hackage.example.test"
  PACKAGE_PATH="${BATS_TEST_TMPDIR}/foo-1.0.0.tar.gz"
  export PACKAGE_PATH
  touch "${PACKAGE_PATH}"
  export DOC_PATH=""
  export PUBLISH="true"
}

@test "fails when token is empty" {
  export HACKAGE_TOKEN=""
  run "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Token is empty"* ]]
}

@test "fails when package tarball is missing" {
  export PACKAGE_PATH="${BATS_TEST_TMPDIR}/does-not-exist.tar.gz"
  run "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}

@test "publishes successfully and reports already-published=false" {
  export MOCK_PUBLISH_CODE=200
  run "${SCRIPT}"
  [ "$status" -eq 0 ]
  grep -qx "already-published=false" "${GITHUB_OUTPUT}"
  grep -qx "publish" "${CALLS_LOG}"
  ! grep -qx "existence" "${CALLS_LOG}"
}

@test "treats 403 followed by existing package as idempotent success" {
  export MOCK_PUBLISH_CODE=403
  export MOCK_PUBLISH_BODY="This version of the package has already been uploaded."
  export MOCK_EXISTENCE_CODE=200
  run "${SCRIPT}"
  [ "$status" -eq 0 ]
  grep -qx "already-published=true" "${GITHUB_OUTPUT}"
  grep -qx "existence" "${CALLS_LOG}"
}

@test "fails when 403 is not due to an existing package" {
  export MOCK_PUBLISH_CODE=403
  export MOCK_EXISTENCE_CODE=404
  run "${SCRIPT}"
  [ "$status" -eq 1 ]
  grep -qx "existence" "${CALLS_LOG}"
}

@test "fails immediately on an unrelated error without checking existence" {
  export MOCK_PUBLISH_CODE=500
  run "${SCRIPT}"
  [ "$status" -eq 1 ]
  ! grep -qx "existence" "${CALLS_LOG}"
}

@test "candidate upload is unaffected by idempotency logic" {
  export PUBLISH="false"
  run "${SCRIPT}"
  [ "$status" -eq 0 ]
  grep -qx "already-published=false" "${GITHUB_OUTPUT}"
  grep -qx "candidate" "${CALLS_LOG}"
  ! grep -qx "existence" "${CALLS_LOG}"
}

@test "still uploads docs when package was already published" {
  export MOCK_PUBLISH_CODE=403
  export MOCK_EXISTENCE_CODE=200
  export DOC_PATH="${BATS_TEST_TMPDIR}/foo-1.0.0-docs.tar.gz"
  touch "${DOC_PATH}"
  run "${SCRIPT}"
  [ "$status" -eq 0 ]
  grep -qx "docs" "${CALLS_LOG}"
}

@test "uploads docs on a fresh publish" {
  export MOCK_PUBLISH_CODE=200
  export DOC_PATH="${BATS_TEST_TMPDIR}/foo-1.0.0-docs.tar.gz"
  touch "${DOC_PATH}"
  run "${SCRIPT}"
  [ "$status" -eq 0 ]
  grep -qx "docs" "${CALLS_LOG}"
}
