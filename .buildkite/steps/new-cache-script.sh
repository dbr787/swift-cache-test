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

# Function to initialize or update the metadata file with creation, usage, clearing, or ignoring details
update_cache_metadata() {
  local action=$1  # Action can be 'created', 'used', 'cleared', or 'ignored'
  local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
  local build_number="${BUILDKITE_BUILD_NUMBER:-unknown}"
  local step_key="${BUILDKITE_STEP_KEY:-unknown}"

  # If metadata file doesn't exist, initialize it
  if [ ! -f "$CACHE_METADATA" ]; then
    echo "Initializing cache metadata."
    echo "{}" > "$CACHE_METADATA"
  fi

  # Ensure that the created event is always preserved in the metadata
  local metadata_entry=$(jq -n --arg timestamp "$timestamp" --arg build_number "$build_number" --arg step_key "$step_key" \
    '{timestamp: $timestamp, build_number: $build_number, step_key: $step_key}')

  case $action in
    created)
      jq --argjson created "$metadata_entry" '. + {created: $created, last_used: $created, last_cleared: null}' "$CACHE_METADATA" > "${CACHE_METADATA}.tmp" && mv "${CACHE_METADATA}.tmp" "$CACHE_METADATA"
      ;;
    used)
      # Ensure that "created" exists before updating "last_used"
      if ! jq -e '.created' "$CACHE_METADATA" > /dev/null; then
        echo "Error: Metadata missing 'created' information. Cache might not have been created properly."
        exit 1
      fi
      jq --argjson last_used "$metadata_entry" '. + {last_used: $last_used}' "$CACHE_METADATA" > "${CACHE_METADATA}.tmp" && mv "${CACHE_METADATA}.tmp" "$CACHE_METADATA"
      ;;
    cleared)
      jq --argjson last_cleared "$metadata_entry" '. + {last_cleared: $last_cleared}' "$CACHE_METADATA" > "${CACHE_METADATA}.tmp" && mv "${CACHE_METADATA}.tmp" "$CACHE_METADATA"
      ;;
    ignored)
      # Update only the "ignored" event without touching other fields
      jq --argjson last_ignored "$metadata_entry" '. + {last_ignored: $last_ignored}' "$CACHE_METADATA" > "${CACHE_METADATA}.tmp" && mv "${CACHE_METADATA}.tmp" "$CACHE_METADATA"
      ;;
  esac
}

# Function to display the cache metadata (creation, last used, last cleared, last ignored)
show_cache_metadata() {
  if [ -f "$CACHE_METADATA" ]; then
    echo "Cache metadata:"
    jq '.' "$CACHE_METADATA"
  else
    echo "No cache metadata found. The cache might be new or never used."
  fi
}

# Function to list the contents of the cache directory with size, creation date, and modification date
list_cache() {
  if [ -d "${CACHE_DIR}" ]; then
    echo -e "\033[90mListing contents of CACHE_DIR (${CACHE_DIR}):"
    printf "\033[90m%-6s %-21s %-21s %-50s\n" "Size" "Created Date" "Modified Date" "Path"
    echo -e "\033[90m----------------------------------------------------------------------------------------------------"

    # Collecting directory details into a temporary file for sorting
    temp_file=$(mktemp)
    
    sudo find "${CACHE_DIR}" -maxdepth 2 -type d -exec du -sh {} + 2>/dev/null | while read -r size path; do
      # Using stat for macOS to get the creation and modification dates
      created_date=$(stat -f "%SB" -t "%Y-%m-%d %H:%M:%S" "$path") || echo "N/A"
      modified_date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$path") || echo "N/A"
      
      # Print the size, creation date, modification date, and path
      echo -e "$size $created_date $modified_date $path"
    done | sort -h > "$temp_file"

    # Display the sorted output in gray
    cat "$temp_file"

    # Removing temporary file
    rm -f "$temp_file"

    # Reset the color back to default
    echo -e "\033[0m"
  else
    echo "No cache directory exists at ${CACHE_DIR}."
  fi
}

# Function to clear the cache and log the clearing time
clear_cache() {
  if [ -d "${CACHE_DIR}" ]; then
    echo -e '--- \033[31m:swift: Clearing cache\033[0m'
    show_cache_metadata  # Show cache metadata before clearing
    list_cache  # List cache contents before clearing
    echo "Clearing cache in ${CACHE_DIR}"
    sudo rm -rf "${CACHE_DIR}"
    echo "Cache cleared."
    update_cache_metadata "cleared"  # Log the cache clearing time
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
  swift package resolve --build-path "${CACHE_DIR}"

  echo "Dependencies resolved and stored in ${CACHE_DIR}"
  list_cache  # List cache contents after resolving dependencies
}

# Function to resolve dependencies without using the cache (ignoring cache)
resolve_dependencies_without_cache() {
  echo -e '--- \033[35m:swift: Resolving Swift package dependencies (ignoring cache)\033[0m'
  echo "Resolving dependencies directly into the default ./.build directory, ignoring the cache"
  
  # Ignore cache and resolve directly to the default directory
  swift package resolve  # This resolves into the default ./.build directory, bypassing the cache

  update_cache_metadata "ignored"  # Log that the cache was ignored without altering created/used fields
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
