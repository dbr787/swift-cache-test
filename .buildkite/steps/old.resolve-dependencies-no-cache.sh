#!/bin/bash

set -euo pipefail

echo -e '+++ \033[36m:swift: Resolving Swift package dependencies (no cache)\033[0m'
swift package resolve
