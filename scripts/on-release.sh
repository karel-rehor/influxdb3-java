#!/usr/bin/env bash

if [ -z "${CIRCLE_TAG}" ]
then
  echo "CIRCLE_TAG is not set. Exiting."
  exit 1
fi

if [[ ! "${CIRCLE_TAG}" =~ ^v[0-9]+(\.[0-9]+){2}(-(rc|beta)[0-9]+)?$ ]]
then
  printf "CIRCLE_TAG (%s) is invalid\n" "${CIRCLE_TAG}"
  exit 1
fi

printf "Starting release based on tag %s\n" "${CIRCLE_TAG}"

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PROJECT_DIR="$SCRIPT_DIR/.."
CHANGELOG_PATH="$PROJECT_DIR/CHANGELOG.md"
POM_XML_PATH="${PROJECT_DIR}/pom.xml"

CURRENT_BRANCH=$(git branch --show-current)

RELEASE_NUM=${CIRCLE_TAG}

RC_OR_BETA=false
IS_SNAPSHOT=false

set_release_number(){
    RELEASE_NUM=$(echo ${CIRCLE_TAG} | sed -r "s/-(rc|beta)[0-9]+//" | sed -r "s/^v//")
}

verify_rc_or_beta(){
  if [  -n "$(echo ${CIRCLE_TAG} | grep -E "rc|beta")" ]
  then
    RC_OR_BETA=true
  fi
}

verify_changelog() {

  CHANGELOG_RELEASE_HEADERS=$(sed -n '/^#.*[0-9].[0-9]*.[0-9].*/p' "${CHANGELOG_PATH}")

  mapfile -t HEADER_ARRAY <<< "$CHANGELOG_RELEASE_HEADERS"

  mapfile -td ' ' HEADER_LINE <<< "${HEADER_ARRAY[0]}"

  HEADER_TAG="${HEADER_LINE[1]}"
  HEADER_DATE="${HEADER_LINE[2]:1:-2}"

  if [ "$HEADER_TAG" != "$RELEASE_NUM"  ]; then
    printf "ERROR: Latest HEADER_TAG in CHANGELOG.md (%s) does not match release number (%s) from git tag (%s)\n" \
    "$HEADER_TAG" \
    "$RELEASE_NUM" \
    "$CIRCLE_TAG"
    printf "Please update the latest HEADER_TAG in CHANGELOG.md\n"
    exit 1
  else
    printf "CHANGELOG.md release number check: OK ✓\n"
  fi

  if [[ ! "$HEADER_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    printf "ERROR invalid commit date (%s) in last CHANGELOG.md entry\n" "$HEADER_DATE"
    printf "Please update the commit date in CHANGELOG.md\n"
    exit 1
  else
    printf "CHANGELOG.md release date check: OK ✓\n"
  fi
}

verify_version(){
  printf "verifying version\n"
  PROJECT_VERSION=$(xmllint --xpath "//*[local-name()='project']/*[local-name()='version']/text()" ${POM_XML_PATH}"")
  printf "DEBUG PROJECT_VERSION %s\n"  "${PROJECT_VERSION}"

  if [[  "${PROJECT_VERSION}" == *SNAPSHOT ]]
  then
    printf "Version in %s (%s) is a snapshot.\n" "${POM_XML_PATH}" "${PROJECT_VERSION}"
    printf "This script does not release snapshots.\n"
    exit 1
  fi

  if [ "${PROJECT_VERSION}" != "${RELEASE_NUM}" ]
  then
    printf "PROJECT_VERSION %s in pom.xml does not match tag %s" "${PROJECT_VERSION}" "${CIRCLE_TAG}"
    exit 1
  fi

  printf "pom.xml project version (%s) checks with release tag (%s): OK ✓\n" "${PROJECT_VERSION}" "${CIRCLE_TAG}"
  # TODO further checks

}

verify_rc_or_beta
set_release_number

verify_changelog
verify_version

