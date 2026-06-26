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
EXAMPLES_POM_XML_PATH="${PROJECT_DIR}/examples/pom.xml"

CURRENT_BRANCH=$(git branch --show-current)

RELEASE_NUM=""
NEXT_RELEASE_NUM=""

RC_OR_BETA=false
IS_SNAPSHOT=false

FAILURE_BOILERPLATE="Please delete the tag ${CIRCLE_TAG} and the related release, and start again."

setup(){
  ADDITIONAL_INSTALLS=""
  if ! [ -x "$(command -v xmllint)" ]
  then
    ADDITIONAL_INSTALLS="${ADDITIONAL_INSTALLS} libxml2-utils"
  else
    printf "have xmllint\n"
  fi

  if [ -n "${ADDITIONAL_INSTALLS}" ]
  then
    printf "This script requires the following unavailable libraries: %s\n" "${ADDITIONAL_INSTALLS}"
    printf "Please install them and then continue.\n"
    printf "%s\n" "${FAILURE_BOILERPLATE}"
    exit 1
  else
    printf "Additional requirements already satisfied.\n"
  fi
}

set_release_number(){
    RELEASE_NUM=$(echo ${CIRCLE_TAG} | sed -r "s/-(rc|beta)[0-9]+//" | sed -r "s/^v//")
}

verify_rc_or_beta(){
  if [  -n "$(echo ${CIRCLE_TAG} | grep -E "rc|beta")" ]
  then
    RC_OR_BETA=true
  fi
}

set_next_release_number(){
  if [ -z $RELEASE_NUM ]
  then
    printf "Current release number not yet acquired.  Cannot calculate next release.  Exiting."
    printf "%s\n" "${FAILURE_BOILERPLATE}"
    exit 1
  fi

  IFS="." read -r -a RELEASE_PARTS <<< "${RELEASE_NUM}"

  NEW_MAJ=$((RELEASE_PARTS[0]))
  NEW_MIN=$((1 + RELEASE_PARTS[1]))
  NEW_INCR=0

  NEXT_RELEASE_NUM="$((NEW_MAJ)).$((NEW_MIN)).$((NEW_INCR))"
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
    printf "%s" "${FAILURE_BOILERPLATE}"
    exit 1
  else
    printf "CHANGELOG.md release number check: OK ✓\n"
  fi

  if [[ ! "$HEADER_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    printf "ERROR invalid commit date (%s) in last CHANGELOG.md entry\n" "$HEADER_DATE"
    printf "Please update the commit date in CHANGELOG.md\n"
    printf "%s\n" "${FAILURE_BOILERPLATE}"
    exit 1
  else
    printf "CHANGELOG.md release date check: OK ✓\n"
  fi
}

verify_version(){
  printf "verifying version\n"
  PROJECT_VERSION=$(xmllint --xpath "//*[local-name()='project']/*[local-name()='version']/text()" ${POM_XML_PATH}"")
  printf "Project version from pom.xml is %s\n"  "${PROJECT_VERSION}"

  if [[  "${PROJECT_VERSION}" == *SNAPSHOT ]]
  then
    printf "Version in %s (%s) is a snapshot.\n" "${POM_XML_PATH}" "${PROJECT_VERSION}"
    printf "This script does not release snapshots.\n"
    printf "%s\n" "${FAILURE_BOILERPLATE}"
    exit 1
  fi

  if [ "${PROJECT_VERSION}" != "${RELEASE_NUM}" ]
  then
    printf "PROJECT_VERSION %s in pom.xml does not match tag %s" "${PROJECT_VERSION}" "${CIRCLE_TAG}"
    printf "%s\n" "${FAILURE_BOILERPLATE}"
    exit 1
  fi

  printf "pom.xml project version (%s) checks with release tag (%s): OK ✓\n" "${PROJECT_VERSION}" "${CIRCLE_TAG}"
  # TODO further checks

}

publish_to_maven(){
  printf "Publish to maven\n"
  printf "   ### TODO ###\n"
}

update_pom_version(){
  printf "Updating version in %s" "${1}"

  xmllint --shell "${1}" << HERE
cd //*[local-name()='project']/*[local-name()='version']
cat .
set ${NEXT_RELEASE_NUM}-SNAPSHOT
cat .
save
bye
HERE
}

prepare_next_version(){
  if [ $RC_OR_BETA == true ]
  then
    printf "This tag release is a release candidate or beta version. Tag value is %s\n" "${CIRCLE_TAG}"
    printf "updating version for next release cycle skipped.\n"
    return
  fi
  printf "Preparing next version %s\n" "${NEXT_RELEASE_NUM}"

  ## Update CHANGELOG.md
  sed -i "1i ## ${NEXT_RELEASE_NUM} [unreleased]\n" $CHANGELOG_PATH

  ## Update POMs
  update_pom_version "${POM_XML_PATH}"

  update_pom_version "${EXAMPLES_POM_XML_PATH}"

  echo "DEBUG xmllint --shell result: " $?

}

store_artifacts(){
  mkdir /tmp/artifacts
  cp "${POM_XML_PATH}" /tmp/artifacts
  cp "${EXAMPLES_POM_XML_PATH}" /tmp/artifacts/examples_pom.xml
  cp "${CHANGELOG_PATH}" /tmp/artifacts
}

test_latest(){
  printf "Testing Latest\n"
  printf "DEBUG RC_OR_BETA %s\n" "${RC_OR_BETA}"
  printf "DEBUG NEXT_RELEASE_NUM %s\n" "${NEXT_RELEASE_NUM}"
}



setup
verify_rc_or_beta
set_release_number

verify_changelog
verify_version

publish_to_maven

set_next_release_number
prepare_next_version

# TODO these are verification steps to be removed before release
store_artifacts
test_latest

