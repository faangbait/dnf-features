#!/usr/bin/env bash

set -e
source dev-container-features-test-lib

check "dnf base image is in use" dnf --version
check "Terraform 1.15.8 is installed" sh -c "terraform version -json | grep -q '\"terraform_version\": \"1.15.8\"'"
check "TFLint 0.64.0 is installed" sh -c "tflint --version | grep -q 'TFLint version 0.64.0'"
check "Terraform MCP Server 1.1.0 is installed" sh -c "terraform-mcp-server --version | grep -q '1.1.0'"

reportResults
