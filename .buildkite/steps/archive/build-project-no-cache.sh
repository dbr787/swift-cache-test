#!/bin/bash

set -euo pipefail

echo -e '+++ \033[36m:swift: Building the Swift project (no cache)\033[0m'
swift build
