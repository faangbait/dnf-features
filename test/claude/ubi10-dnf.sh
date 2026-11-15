#!/usr/bin/env bash

set -e
source dev-container-features-test-lib

check "dnf base image is in use" dnf --version
check "Claude Code CLI is installed" sh -c "command -v claude"
check "Claude Code CLI runs" claude --version

reportResults
