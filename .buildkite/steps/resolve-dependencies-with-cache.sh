#!/bin/bash

set -euo pipefail

# Log group for debugging steps
echo -e '+++ \033[33m:swift: Debug Information\033[0m'
echo "NSC_CACHE_PATH is set to: ${NSC_CACHE_PATH}"

echo "Listing directories in ${NSC_CACHE_PATH}:"
find "${NSC_CACHE_PATH}" -maxdepth 1 -type d -exec du -sh {} + 2>/dev/null || true

echo "Cache size (ignoring permission errors):"
du -sh "${NSC_CACHE_PATH}" 2>/dev/null || true

echo "Detailed cache size (1 level deep):"
du -sh "${NSC_CACHE_PATH}"/* 2>/dev/null || true

# Optionally show a tree view (if `tree` command is available)
if command -v tree &> /dev/null; then
  echo "Tree view of cache directory (1 level deep):"
  tree -L 1 "${NSC_CACHE_PATH}" 2>/dev/null || true
else
  echo "tree command is not available; skipping tree view."
fi

# Log group for restoring cached dependencies
echo -e '+++ \033[35m:swift: Restoring cached dependencies\033[0m'
if [ -d "${NSC_CACHE_PATH}/build" ]; then
  echo "Found cached build directory at ${NSC_CACHE_PATH}/build."
  echo "Copying cached build directory to local ./.build..."
  cp -a "${NSC_CACHE_PATH}/build" ./.build 2>&1 | grep -v 'No such file or directory' || true

  # Check if .build was restored successfully
  if [ -d ./.build ] && [ "$(ls -A ./.build)" ]; then
    echo "Successfully restored .build directory from cache."
  else
    echo "Warning: Restored .build directory is empty."
  fi

else
  echo "No cached build directory found at ${NSC_CACHE_PATH}/build."
fi

# Log group for resolving dependencies
echo -e '+++ \033[36m:swift: Resolving Swift package dependencies\033[0m'
time swift package resolve
echo "Swift package dependencies resolved."

# Log group for caching resolved dependencies
echo -e '+++ \033[32m:swift: Caching resolved dependencies\033[0m'
mkdir -p "${NSC_CACHE_PATH}/build"
echo "Caching the local ./.build directory to ${NSC_CACHE_PATH}/build..."
cp -a ./.build "${NSC_CACHE_PATH}/build" 2>&1 | grep -v 'No such file or directory' || true

# Log the size of the cached .build directory
echo "Size of cached .build directory:"
du -sh "${NSC_CACHE_PATH}/build" 2>/dev/null || true

echo "Cached the local ./.build directory to ${NSC_CACHE_PATH}/build."
