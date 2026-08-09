#!/usr/bin/env bash

set -e
source dev-container-features-test-lib

check "dnf base image is in use" dnf --version
check "AWS CLI v2 is installed" sh -c "aws --version 2>&1 | grep -q '^aws-cli/2\\.'"
check "AWS CLI completer is installed" test -x /usr/local/bin/aws_completer
check "bash completion is installed" test -f /etc/bash_completion.d/aws
check "zsh completion is installed" test -f /usr/local/share/zsh/site-functions/_aws

reportResults
