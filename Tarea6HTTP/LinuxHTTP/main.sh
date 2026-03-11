#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/apache.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/nginx.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/tomcat.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/menu.sh"

main() {
  linux_require_root
  linux_check_dependencies
  linux_main_menu
}

main "$@"