#!/bin/bash

set -euo pipefail

echo "NSC_CACHE_PATH is set to: ${NSC_CACHE_PATH}"

echo "Listing contents of ${NSC_CACHE_PATH}:"
ls -l "${NSC_CACHE_PATH}"

echo "Cache size (ignoring permission errors):"
du -sh "${NSC_CACHE_PATH}" 2>/dev/null || true

echo -e '+++ \033[35m:swift: Restoring cached build artifacts\033[0m'
if [ -d "${NSC_CACHE_PATH}/build" ]; then
  cp -a "${NSC_CACHE_PATH}/build" ./.build 2>&1 | grep -v 'No such file or directory' || true
fi

echo -e '+++ \033[36m:swift: Building the Swift project\033[0m'
swift build

echo -e '+++ \033[32m:swift: Caching build artifacts\033[0m'
mkdir -p "${NSC_CACHE_PATH}/build"
cp -a ./.build "${NSC_CACHE_PATH}/build" 2>&1 | grep -v 'No such file or directory' || true
