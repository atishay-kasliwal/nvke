#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

#
# Print the version every artifact built from a commit is published under: the
# nearest v* tag, described. The publish workflows resolve their version here
# rather than calling git describe themselves, so each one gets the same checks
# before it logs in to anything.
#
# Usage: release/hack/describe-version.sh [commit]   (default HEAD)
#
# Refuses, rather than prints:
#   - a version that is not a v* release, RC or beta version, its describe
#     suffix, or a bare commit. A tag name reaches make and the shell, so
#     nothing else may pass through.
#   - on a v* tag run, a version other than that tag. A beta re-run on a
#     commit released since describes to the release, and would overwrite it.
#   - on a component tag run (agent/v*, cli/v*, ...), a release version. A
#     component RC on a released commit would overwrite that release.
#
# GITHUB_REF is the ref that started the run; unset outside Actions, which
# skips the tag checks.

set -euo pipefail

commit="${1:-HEAD}"
version="$(git describe --tags --always --match 'v*' "${commit}")"

release_re='^v[0-9]+\.[0-9]+\.[0-9]+$'
version_re='^(v[0-9]+\.[0-9]+\.[0-9]+(-(beta|rc)\.[0-9]+)?(-[0-9]+-g[0-9a-f]+)?|[0-9a-f]{7,40})$'

if ! [[ "${version}" =~ ${version_re} ]]; then
  echo "::error::${commit} describes to '${version}', which is not a version this repository publishes" >&2
  exit 1
fi

ref="${GITHUB_REF:-}"
case "${ref}" in
  refs/tags/v*)
    if [[ "${version}" != "${ref#refs/tags/}" ]]; then
      echo "::error::${ref#refs/tags/} describes to ${version}; refusing to publish under another tag's version" >&2
      exit 1
    fi
    ;;
  refs/tags/*/v*)
    if [[ "${version}" =~ ${release_re} ]]; then
      echo "::error::${ref#refs/tags/} is on released commit ${version}; refusing to republish the release" >&2
      exit 1
    fi
    ;;
esac

echo "${version}"
