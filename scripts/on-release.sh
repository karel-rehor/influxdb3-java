#!/usr/bin/env bash

NEWEST_TAG=$(git describe --tags --abbrev=0)

printf "Starting release based on tag %s" "${NEWEST_TAG}"

