#!/usr/bin/env bash
# SPDX-FileCopyrightText: Magenta ApS
#
# SPDX-License-Identifier: MPL-2.0

set -o errexit
set -o pipefail
set -o nounset

if ! command which yq &>/dev/null; then
  >&2 echo 'yq command not found'
  exit 1
fi

for FILE in "$@"; do
    yq -e e 'true' "${FILE}" > /dev/null
done
