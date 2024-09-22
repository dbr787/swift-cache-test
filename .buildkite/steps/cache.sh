#!/bin/bash

set -euo pipefail

# Ensure NSC_CACHE_PATH is defined and is a directory
if [ -z "${NSC_CACHE_PATH:-}" ] || [ ! -d "${NSC_CACHE_PATH}" ]; then
  echo "Error: NSC_CACHE_PATH is either not set or not a valid directory."
  exit 1
fi

# Define CACHE_DIR and CACHE_METADATA (stored at the same level as CACHE_DIR)
CACHE_DIR="${NSC_CACHE_PATH}/.build"
CACHE_METADATA="${CACHE_DIR}.metadata"

# Function to update the cache metadata file
update_cache_metadata() {
  local action=$1  # Action can be 'created' or 'used'
  local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
  local build_number="${BUILDKITE_BUILD_NUMBER:-unknown}"
  local step_key="${BUILDKITE_STEP_KEY:-unknown}"

  # If metadata file doesn't exist, initialize it
  if [ ! -f "$CACHE_METADATA" ]; then
    echo "Initializing cache metadata."
    echo "{}" > "$CACHE_METADATA"
  fi

  # Create the JSON object for the event
  local metadata_entry=$(jq -n --arg timestamp "$timestamp" --arg build_number "$build_number" --arg step_key "$step_key" \
    '{timestamp: $timestamp, build_number: $build_number, step_key: $step_key}')

  case $action in
    created)
      jq --argjson created "$metadata_entry" '. + {created: $created}' "$CACHE_METADATA" > "${CACHE_METADATA}.tmp" && mv "${CACHE_METADATA}.tmp" "$CACHE_METADATA"
      ;;
    used)
      jq --argjson last_used "$metadata_entry" '. + {last_used: $last_used}' "$CACHE_METADATA" > "${CACHE_METADATA}.tmp" && mv "${CACHE_METADATA}.tmp" "$CACHE_METADATA"
      ;;
  esac
}

# Function to display the cache metadata (creation, last used)
show_cache_metadata() {
  if [ -f "$CACHE_METADATA" ]; then
    echo "Cache metadata:"
    jq '.' "$CACHE_METADATA"
  else
    echo "No cache metadata found. The cache might be new or never used."
  fi
}

# Function to list the contents of the cache directory with size, creation date, and modification date, sorted by path
list_cache() {
  if [ -d "${CACHE_DIR}" ]; then
    echo -e "\033[90mListing contents of CACHE_DIR (${CACHE_DIR}):"
    printf "\033[90m%-10s %-25s %-25s %-50s\n" "Size" "Created Date" "Modified Date" "Path"
    echo -e "\033[90m---------------------------------------------------------------------------------------------------------"

    # Collecting directory details into a temporary file for sorting
    temp_file=$(mktemp)

    sudo find "${CACHE_DIR}" -maxdepth 2 -type d -exec du -sh {} + 2>/dev/null | while read -r size path; do
      # Using stat for macOS to get the creation and modification dates
      created_date=$(stat -f "%SB" -t "%Y-%m-%d %H:%M:%S" "$path") || echo "N/A"
      modified_date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$path") || echo "N/A"

      # Print the size, creation date, modification date, and path into the temporary file
      printf "%-10s %-25s %-25s %-50s\n" "$size" "$created_date" "$modified_date" "$path" >> "$temp_file"
    done

    # Display the sorted output by path
    cat "$temp_file" | sort -k4
    rm -f "$temp_file"

    # Reset the color back to default
    echo -e "\033[0m"
  else
    echo "No cache directory exists at ${CACHE_DIR}"
  fi
}

# Function to clear the cache and delete the metadata file
clear_cache() {
  echo -e '--- \033[31m:swift: Clearing cache\033[0m'
  if [ -d "${CACHE_DIR}" ]; then
    show_cache_metadata  # Show cache metadata before clearing
    list_cache  # List cache contents before clearing
    echo "Clearing cache in ${CACHE_DIR}"
    sudo rm -rf "${CACHE_DIR}"

    # Delete the metadata file
    if [ -f "$CACHE_METADATA" ]; then
      echo "Deleting cache metadata file."
      sudo rm -f "$CACHE_METADATA"
    fi

    echo "Cache and metadata cleared."
    list_cache  # List cache contents after clearing
  else
    echo "No cache directory exists, nothing to clear."
  fi
}

# Function to resolve dependencies using the cache, updating metadata if necessary
resolve_dependencies_with_cache() {
  if [ -d "${CACHE_DIR}" ]; then
    echo -e '--- \033[32m:swift: Resolving Swift package dependencies (using existing cache)\033[0m'
    show_cache_metadata  # Show cache metadata before using the cache
    list_cache  # List cache contents before resolving dependencies
    update_cache_metadata "used"  # Update the last used time in the metadata
  else
    echo -e '--- \033[36m:swift: Resolving Swift package dependencies (creating cache)\033[0m'
    mkdir -p "${CACHE_DIR}"
    update_cache_metadata "created"  # Log the cache creation time
    show_cache_metadata  # Show the new cache metadata after creation
  fi

  echo "Resolving dependencies directly into cache directory: ${CACHE_DIR}"

  if ! swift package resolve --build-path "${CACHE_DIR}"; then
    echo "Error: Failed to resolve Swift package dependencies."
    exit 1
  fi

  list_cache  # List cache contents after resolving dependencies
}

# Function to resolve dependencies without using the cache (ignoring cache)
resolve_dependencies_without_cache() {
  echo -e '--- \033[35m:swift: Resolving Swift package dependencies (ignoring cache)\033[0m'
  echo "Resolving dependencies directly into the default ./.build directory, ignoring the cache"
  
  # Ignore cache and resolve directly to the default directory
  if ! swift package resolve; then
    echo "Error: Failed to resolve Swift package dependencies."
    exit 1
  fi
}

# Function to rebuild the cache by clearing and recreating it
rebuild_cache() {
  echo -e '--- \033[33m:swift: Rebuilding cache (clearing and resolving dependencies)\033[0m'
  clear_cache  # Clear the cache and delete metadata
  resolve_dependencies_with_cache  # Recreate the cache
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
  rebuild)
    rebuild_cache
    ;;
  *)
    echo "Unknown command: ${1:-resolve}. Use 'clear', 'resolve', 'ignore', or 'rebuild'."
    exit 1
    ;;
esac
