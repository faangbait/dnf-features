#!/usr/bin/env bash

set -e
source dev-container-features-test-lib

# Exercises the build-pin branch: an exact <version>-<build> is downloaded by
# URL and checked against the storage server's MD5 rather than the manifest.
# Assumes that build stays published; bump it if the object is ever removed.
check "Antigravity CLI is installed" sh -c "command -v agy"
check "Antigravity CLI is the pinned build's version" sh -c "agy --version | grep -qx '1\.5\.9'"

reportResults
