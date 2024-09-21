#!/bin/bash

set -euo pipefail

# Default CLEAR_CACHE to false if not set
CLEAR_CACHE="${CLEAR_CACHE:-false}"

# Log group for debugging steps
echo -e '+++ \033[33m:swift: Debug Information\033[0m'

echo "NSC_CACHE_PATH is set to: ${NSC_CACHE_PATH}"
echo "CLEAR_CACHE is set to: ${CLEAR_CACHE}"

# Conditionally clear cache based on CLEAR_CACHE variable
if [ "${CLEAR_CACHE}" = "true" ]; then
  echo -e '+++ \033[31m:swift: Clearing existing cache as CLEAR_CACHE is set to true\033[0m'
  rm -rf "${NSC_CACHE_PATH}/."  # Remove everything, including hidden files
  echo "Cleared cache in ${NSC_CACHE_PATH}."
else
  echo "CLEAR_CACHE is set to false, skipping cache clearing."
fi

# List directories in cache
echo "Listing directories in ${NSC_CACHE_PATH}:"
find "${NSC_CACHE_PATH}" -maxdepth 3 -type d -exec du -sh {} + 2>/dev/null || true

# Log group for restoring cached dependencies
echo -e '+++ \033[35m:swift: Restoring cached dependencies\033[0m'
if [ "$(ls -A ${NSC_CACHE_PATH})" ]; then
  echo "Found cached build directory at '${NSC_CACHE_PATH}'"
  
  # Copy the contents of the cache to ./.build, not the directory itself
  echo "Copying cached build contents to local ./.build..."
  mkdir -p ./.build
  sudo cp -a "${NSC_CACHE_PATH}/." ./.build  # Copy contents, not the cache directory itself

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
  echo "No cached build directory found in ${NSC_CACHE_PATH}."
fi

# Log group for resolving dependencies
echo -e '+++ \033[36m:swift: Resolving Swift package dependencies\033[0m'
time swift package resolve
echo "Swift package dependencies resolved."

# Log group for caching resolved dependencies
echo -e '+++ \033[32m:swift: Caching resolved dependencies\033[0m'

# Cache the current .build directory in the NSC_CACHE_PATH directly
echo "Caching the local ./.build directory to ${NSC_CACHE_PATH}..."
sudo cp -a ./.build/. "${NSC_CACHE_PATH}"  # Copy the contents of .build to NSC_CACHE_PATH

# Log the size of the cached .build directory
echo "Listing directories in ${NSC_CACHE_PATH}:"
find "${NSC_CACHE_PATH}" -maxdepth 3 -type d -exec du -sh {} + 2>/dev/null || true

echo "Cached the local ./.build directory to ${NSC_CACHE_PATH}."
