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

# Function to calculate cache size and file count
calculate_cache_stats() {
  if [ -d "${CACHE_DIR}" ]; then
    local size=$(du -sh "${CACHE_DIR}" | cut -f1)
    local file_count=$(find "${CACHE_DIR}" -type f | wc -l)
    echo "$size" "$file_count"
  else
    echo "0" "0"
  fi
}

# Function to record the start time of an operation
start_timer() {
  START_TIME=$(date +%s)
}

# Function to calculate and return the duration of an operation
get_duration() {
  local end_time=$(date +%s)
  local duration=$((end_time - START_TIME))
  echo "$duration"
}

# Function to update the cache metadata file and annotate with details
update_cache_metadata_and_annotate() {
  local action=$1  # Action can be 'created', 'used', 'cleared', 'ignored', or 'rebuilt'
  local duration=$2  # Duration of the core operation
  local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
  local build_number="${BUILDKITE_BUILD_NUMBER:-unknown}"
  local step_label="${BUILDKITE_LABEL:-unknown}"
  local step_id="${BUILDKITE_STEP_ID:-unknown}"

  # Get cache size and file count **before** the operation
  local before_size before_file_count
  read -r before_size before_file_count <<< "$(calculate_cache_stats)"

  echo "Cache before operation:"
  list_cache  # Listing cache contents before the operation

  # Perform the core operation
  eval "$3"  # The core operation is passed as a third argument (e.g., clear, resolve, etc.)

  # Get cache size and file count **after** the operation
  local after_size after_file_count
  read -r after_size after_file_count <<< "$(calculate_cache_stats)"

  echo "Cache after operation:"
  list_cache  # Listing cache contents after the operation

  # If the cache is created, store the source information
  if [ "$action" = "created" ]; then
    jq -n --arg timestamp "$timestamp" --arg build_number "$build_number" --arg step_label "$step_label" \
      '{created: {timestamp: $timestamp, build_number: $build_number, step_label: $step_label}}' > "$CACHE_METADATA"
  fi

  # Get the cache creation info from metadata (for annotations when cache is used)
  local cache_source_info
  if [ -f "$CACHE_METADATA" ]; then
    cache_source_info=$(jq -r '.created | "\(.step_label) (Build #\(.build_number) at \(.timestamp))"' "$CACHE_METADATA")
  else
    cache_source_info="Unknown source"
  fi

  # Annotate with cache stats, duration, and cache source info
  buildkite-agent annotate --style "success" --context "$step_id" \
    "**$step_label** - Cache $action<br>Duration: ${duration} seconds<br>Before: ${before_size} (${before_file_count} files)<br>After: ${after_size} (${after_file_count} files)<br>Source: $cache_source_info"
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
  start_timer  # Start the timer before the main operation
  echo -e '--- \033[31m:swift: Clearing cache\033[0m'
  local core_operation="sudo rm -rf \"${CACHE_DIR}\" && sudo rm -f \"${CACHE_METADATA}\""  # Define core clear operation
  update_cache_metadata_and_annotate "cleared" "$(get_duration)" "$core_operation"
}

# Function to resolve dependencies using the cache, updating metadata if necessary
resolve_dependencies_with_cache() {
  start_timer  # Start the timer before the main operation
  if [ -d "${CACHE_DIR}" ]; then
    echo -e '--- \033[32m:swift: Resolving Swift package dependencies (using existing cache)\033[0m'
    local core_operation="swift package resolve --build-path \"${CACHE_DIR}\""
  else
    echo -e '--- \033[36m:swift: Resolving Swift package dependencies (creating cache)\033[0m'
    mkdir -p "${CACHE_DIR}"
    local core_operation="swift package resolve --build-path \"${CACHE_DIR}\""
  fi
  update_cache_metadata_and_annotate "used" "$(get_duration)" "$core_operation"
}

# Function to resolve dependencies without using the cache (ignoring cache)
resolve_dependencies_without_cache() {
  start_timer  # Start the timer before the main operation
  echo -e '--- \033[35m:swift: Resolving Swift package dependencies (ignoring cache)\033[0m'
  local core_operation="swift package resolve"  # Define core resolve operation
  update_cache_metadata_and_annotate "ignored" "$(get_duration)" "$core_operation"
}

# Function to rebuild the cache by clearing and recreating it
rebuild_cache() {
  start_timer  # Start the timer before the main operation
  echo -e '--- \033[33m:swift: Rebuilding cache (clearing and resolving dependencies)\033[0m'
  local core_operation="sudo rm -rf \"${CACHE_DIR}\" && mkdir -p \"${CACHE_DIR}\" && swift package resolve --build-path \"${CACHE_DIR}\""
  update_cache_metadata_and_annotate "rebuilt" "$(get_duration)" "$core_operation"
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
