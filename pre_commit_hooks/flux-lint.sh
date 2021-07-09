#!/usr/bin/env bash
# Copyright 2020 The Flux authors. All rights reserved.
# SPDX-FileCopyrightText: 2020 The Flux authors.
#
# SPDX-License-Identifier: Apache-2.0

# This script downloads the Flux OpenAPI schemas, then it validates the
# Flux custom resources and the kustomize overlays using kubeval.
# This script is meant to be run locally and in CI before the changes
# are merged on the main branch that's synced by Flux.

# This script is meant to be run locally and in CI to validate the Kubernetes
# manifests (including Flux custom resources) before changes are merged into
# the branch synced by Flux in-cluster.

# Prerequisites
# - yq v4.6
# - kustomize v4.1
# - kubeval v0.15

set -o errexit
set -o pipefail
set -o nounset

if ! command which curl &>/dev/null; then
  >&2 echo 'curl command not found'
  exit 1
fi

if ! command which yq &>/dev/null; then
  >&2 echo 'yq command not found'
  exit 1
fi

if ! command which kubeval &>/dev/null; then
  >&2 echo 'kubeval command not found'
  exit 1
fi

if ! command which kustomize &>/dev/null; then
  >&2 echo 'kustomize command not found'
  exit 1
fi

SCHEMA_FOLDER=/tmp/flux-crd-schemas/master-standalone-strict
SCHEMA_URL=https://github.com/fluxcd/flux2/releases/latest/download/crd-schemas.tar.gz
if [ ! -d "${SCHEMA_FOLDER}" ]; then
    # Download Flux OpenAPI schemas
    mkdir -p "${SCHEMA_FOLDER}"
    curl -sL "${SCHEMA_URL}" | tar zxf - -C "${SCHEMA_FOLDER}"
fi

KUBEVAL_FLAGS=(--additional-schema-locations=file:///tmp/flux-crd-schemas)

STRICT=${STRICT:=1}
if [[ ${STRICT} -eq 1 ]]; then
    KUBEVAL_FLAGS+=("--strict")
fi

IGNORE_MISSING=${IGNORE_MISSING:=1}
if [[ ${IGNORE_MISSING} -eq 1 ]]; then
    KUBEVAL_FLAGS+=("--ignore-missing-schemas")
fi

for FILE in "$@"; do
    if [[ "${FILE}" =~ ^clusters.* ]]; then
        kubeval "${FILE}" "${KUBEVAL_FLAGS[@]}" | grep -v "^PASS -"
    fi
done

# Mirror kustomize-controller build options
KUSTOMIZE_FLAGS=(--load-restrictor=LoadRestrictionsNone --reorder=legacy)
KUSTOMIZE_CONFIG="kustomization.yaml"

for FILE in "$@"; do
    if [[ "${FILE}" =~ ^.*${KUSTOMIZE_CONFIG} ]]; then
        BUILD_FOLDER=$(mktemp -d)
        kustomize build "${FILE%${KUSTOMIZE_CONFIG}}" "${KUSTOMIZE_FLAGS[@]}" -o ${BUILD_FOLDER}
        for FILE in ${BUILD_FOLDER}/*.yaml; do
            # Ignore encrypted files
            yq e "del(.sops)" "${FILE}" > ${FILE}.yq.yaml
            kubeval "${FILE}.yq.yaml" "${KUBEVAL_FLAGS[@]}" | grep -v "^PASS -"
        done
        rm -rf "${BUILD_FOLDER}"
    fi
done

exit 0
