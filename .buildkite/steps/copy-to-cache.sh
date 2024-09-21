#!/bin/bash

set -euo pipefail

# Log group for debugging steps
echo -e '+++ \033[33m:swift: Debug Information\033[0m'
echo "NSC_CACHE_PATH is set to: ${NSC_CACHE_PATH}"

# List directories in cache
echo "Listing directories in ${NSC_CACHE_PATH}:"
find "${NSC_CACHE_PATH}" -maxdepth 3 -type d -exec du -sh {} + 2>/dev/null || true

# TEMP: Clear the existing cache to resolve recursive .build issue
echo -e '+++ \033[31m:swift: Clearing existing cache to resolve recursive .build issue\033[0m'
rm -rf "${NSC_CACHE_PATH}/build"
echo "Cleared cache at ${NSC_CACHE_PATH}/build."

# Log group for restoring cached dependencies
echo -e '+++ \033[35m:swift: Restoring cached dependencies\033[0m'
if [ -d "${NSC_CACHE_PATH}/build" ]; then
  echo "Found cached build directory at '${NSC_CACHE_PATH}/build'"
  
  # Copy the contents of the cache to ./.build, not the cache directory itself
  echo "Copying cached build directory contents to local ./.build..."
  mkdir -p ./.build
  cp -a "${NSC_CACHE_PATH}/build/." ./.build  # Copy the contents, not the directory itself

  # Check if .build was restored successfully
  if [ -d ./.build ] && [ "$(ls -A ./.build)" ]; then
    echo "Successfully restored .build directory from cache."
    
    # List the contents and sizes of the restored .build directory
    echo "Listing directories in restored .build (max depth 3):"
    find "./.build" -maxdepth 3 -type d -exec du -sh {} + 2>/dev/null || true
    
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

# Cache the current .build directory
mkdir -p "${NSC_CACHE_PATH}/build"
echo "Caching the local ./.build directory to ${NSC_CACHE_PATH}/build..."
sudo cp -a ./.build/. "${NSC_CACHE_PATH}/build"  # Copy the contents, not the directory itself

# Log the size of the cached .build directory
echo "Listing directories in ${NSC_CACHE_PATH}:"
find "${NSC_CACHE_PATH}" -maxdepth 3 -type d -exec du -sh {} + 2>/dev/null || true

echo "Cached the local ./.build directory to ${NSC_CACHE_PATH}/build."
