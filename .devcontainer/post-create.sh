#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

git config --local submodule.recurse true
git config --local pull.rebase true
git submodule update --init --recursive
rokit install --no-trust-check
