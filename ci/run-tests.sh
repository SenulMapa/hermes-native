#!/usr/bin/env bash
# Run the fast logic tests on the macOS host. HermesAPI is pure Foundation/
# Security, so `swift test` runs without a simulator (no slow runtime download).
# Full iOS compilation of every target/package is verified by the Archive step.
set -euo pipefail

echo "::group::HermesAPI package tests (host)"
swift test --package-path Packages/HermesAPI
echo "::endgroup::"
