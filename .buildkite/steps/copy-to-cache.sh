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
  
  # Check if NSC_CACHE_PATH exists before trying to clear
  if [ -d "${NSC_CACHE_PATH}" ]; then
    # Remove all contents (including hidden files) except for `.` and `..`
    rm -rf "${NSC_CACHE_PATH}/"[!.]* "${NSC_CACHE_PATH}/."* 2>/dev/null || true
    echo "Cleared cache in ${NSC_CACHE_PATH}."
  else
    echo "Cache path ${NSC_CACHE_PATH} does not exist, nothing to clear."
  fi
else
  echo "CLEAR_CACHE is set to false, skipping cache clearing."
fi

# List directories in cache
echo "Listing directories in ${NSC_CACHE_PATH}:"
if [ -d "${NSC_CACHE_PATH}" ]; then
  find "${NSC_CACHE_PATH}" -maxdepth 3 -type d -exec du -sh {} + 2>/dev/null || true
else
  echo "Cache path ${NSC_CACHE_PATH} does not exist, nothing to list."
fi

# Log group for restoring cached dependencies
echo -e '+++ \033[35m:swift: Restoring cached dependencies\033[0m'
# Only proceed if cache directory exists and is NOT empty
if [ -d "${NSC_CACHE_PATH}" ] && [ "$(ls -A ${NSC_CACHE_PATH})" ]; then
  echo "Found non-empty cached build directory at '${NSC_CACHE_PATH}'"
  
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
  echo "No non-empty cached build directory found in ${NSC_CACHE_PATH}."
fi

# Log group for resolving dependencies
echo -e '+++ \033[36m:swift: Resolving Swift package dependencies\033[0m'
time swift package resolve
echo "Swift package dependencies resolved."

# Log group for caching resolved dependencies
echo -e '+++ \033[32m:swift: Caching resolved dependencies\033[0m'

# Cache the current .build directory in the NSC_CACHE_PATH directly
if [ -d ./.build ] && [ "$(ls -A ./.build)" ]; then
  echo "Caching the local ./.build directory to ${NSC_CACHE_PATH}..."
  sudo cp -a ./.build/. "${NSC_CACHE_PATH}"  # Copy the contents of .build to NSC_CACHE_PATH
  echo "Cached the local ./.build directory to ${NSC_CACHE_PATH}."
else
  echo "No local .build directory found to cache."
fi

# Log the size of the cached .build directory
echo "Listing directories in ${NSC_CACHE_PATH}:"
if [ -d "${NSC_CACHE_PATH}" ]; then
  find "${NSC_CACHE_PATH}" -maxdepth 3 -type d -exec du -sh {} + 2>/dev/null || true
else
  echo "Cache path ${NSC_CACHE_PATH} does not exist, nothing to list."
fi
