#!/usr/bin/env bash

set -e
source dev-container-features-test-lib

check "microdnf base image is in use" sh -c "command -v microdnf"
check "Claude Code CLI is installed" sh -c "command -v claude"
check "Claude Code CLI runs" claude --version

reportResults
