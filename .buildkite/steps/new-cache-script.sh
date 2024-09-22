#!/bin/bash

set -euo pipefail

# Ensure NSC_CACHE_PATH is defined and is a directory
if [ -z "${NSC_CACHE_PATH:-}" ] || [ ! -d "${NSC_CACHE_PATH}" ]; then
  echo "Error: NSC_CACHE_PATH is either not set or not a valid directory."
  exit 1
fi

# Define CACHE_DIR at the top of the script
CACHE_DIR="${NSC_CACHE_PATH}/.build"

# Function to list the contents of the cache directory with size, path, and creation date
list_cache() {
  if [ -d "${CACHE_DIR}" ]; then
    echo "Listing contents of CACHE_DIR (${CACHE_DIR}):"
    sudo find "${CACHE_DIR}" -maxdepth 2 -type d -exec du -sh {} + 2>/dev/null | while read -r size path; do
      created_date=$(stat -c %w "$path" 2>/dev/null || echo "N/A") # Creation date, "N/A" if not available
      printf "%-10s  %-50s  %s\n" "$size" "$path" "$created_date"
    done
  else
    echo "No cache directory exists at ${CACHE_DIR}."
  fi
}

# Function to clear cache
clear_cache() {
  echo -e '--- \033[31m:swift: Clearing cache\033[0m' # Red for clearing cache
  list_cache # List cache contents before clearing
  echo "Clearing cache in ${CACHE_DIR}"
  sudo rm -rf "${CACHE_DIR}"
  echo "Cache cleared"
  list_cache # List cache contents after clearing
}

# Function to resolve dependencies using the cache (Green if cache exists, Cyan if cache is created)
resolve_dependencies_with_cache() {
  if [ -d "${CACHE_DIR}" ]; then
    echo -e '--- \033[32m:swift: Resolving Swift package dependencies (using existing cache)\033[0m'  # Green for existing cache
    list_cache # List cache contents before resolving dependencies
  else
    echo -e '--- \033[36m:swift: Resolving Swift package dependencies (creating cache)\033[0m'  # Cyan for cache creation
    mkdir -p "${CACHE_DIR}"
  fi
  echo "Resolving dependencies directly into cache directory: ${CACHE_DIR}"
  swift package resolve --build-path "${CACHE_DIR}"
  echo "Dependencies resolved and stored in ${CACHE_DIR}"
  list_cache # List cache contents after resolving dependencies
}

# Function to resolve dependencies without using the cache (Purple)
resolve_dependencies_without_cache() {
  echo -e '--- \033[35m:swift: Resolving Swift package dependencies (ignoring cache)\033[0m' # Purple for ignoring cache
  echo "Resolving dependencies directly into the default ./.build directory, ignoring the cache"
  swift package resolve # This resolves into the default ./.build directory, bypassing the cache
  echo "Dependencies resolved without using the cache"
}

# Main Execution
case "${1:-resolve}" in
  clear)
    clear_cache
    ;;
  resolve)
    resolve_dependencies_with_cache
    ;;
  ignore)
    resolve_dependencies_without_cache
    ;;
  *)
    echo "Unknown command: ${1:-resolve}. Use 'clear', 'resolve', or 'ignore'."
    exit 1
    ;;
esac
