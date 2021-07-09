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

# Download Flux OpenAPI schemas
mkdir -p /tmp/flux-crd-schemas/master-standalone-strict
curl -sL https://github.com/fluxcd/flux2/releases/latest/download/crd-schemas.tar.gz | tar zxf - -C /tmp/flux-crd-schemas/master-standalone-strict

# Mirror kustomize-controller build options
KUSTOMIZE_FLAGS=(--load-restrictor=LoadRestrictionsNone --reorder=legacy)
KUSTOMIZE_CONFIG="kustomization.yaml"

for FILE in "$@"; do
    if [[ $FILE == "clusters*" ]]; then
        kubeval "${FILE}" --strict --ignore-missing-schemas --additional-schema-locations=file:///tmp/flux-crd-schemas
        if [[ ${PIPESTATUS[0]} != 0 ]]; then
            echo "Invalid: ${FILE}"
            exit 1
        fi
    fi
done

for FILE in "$@"; do
    if [[ $FILE == "*${KUSTOMIZE_CONFIG}" ]]; then
        kustomize build ${FILE} "${KUSTOMIZE_FLAGS[@]}" | kubeval --strict --ignore-missing-schemas --additional-schema-locations=file:///tmp/flux-crd-schemas
        if [[ ${PIPESTATUS[0]} != 0 ]]; then
            echo "Invalid: ${FILE}"
            exit 1
        fi
    fi
done
