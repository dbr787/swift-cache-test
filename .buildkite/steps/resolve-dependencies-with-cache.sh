#!/bin/bash

set -euo pipefail

# Log group for debugging steps
echo -e '+++ \033[34m:swift: Debug Information\033[0m'
echo "NSC_CACHE_PATH is set to: ${NSC_CACHE_PATH}"

echo "Listing contents of ${NSC_CACHE_PATH}:"
ls -l "${NSC_CACHE_PATH}"

echo "Cache size (ignoring permission errors):"
du -sh "${NSC_CACHE_PATH}" 2>/dev/null || true

# Log group for restoring cached dependencies
echo -e '+++ \033[35m:swift: Restoring cached dependencies\033[0m'
if [ -d "${NSC_CACHE_PATH}/build" ]; then
  echo "Found cached build directory at ${NSC_CACHE_PATH}/build."
  echo "Copying cached build directory to local ./.build..."
  cp -a "${NSC_CACHE_PATH}/build" ./.build 2>&1 | grep -v 'No such file or directory' || true
  echo "Restored cached build directory to ./.build."
else
  echo "No cached build directory found at ${NSC_CACHE_PATH}/build."
fi

# Log group for resolving dependencies
echo -e '+++ \033[36m:swift: Resolving Swift package dependencies\033[0m'
swift package resolve
echo "Swift package dependencies resolved."

# Log group for caching resolved dependencies
echo -e '+++ \033[32m:swift: Caching resolved dependencies\033[0m'
mkdir -p "${NSC_CACHE_PATH}/build"
echo "Caching the local ./.build directory to ${NSC_CACHE_PATH}/build..."
cp -a ./.build "${NSC_CACHE_PATH}/build" 2>&1 | grep -v 'No such file or directory' || true
echo "Cached the local ./.build directory to ${NSC_CACHE_PATH}/build."
