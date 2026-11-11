#!/bin/sh
#
# Usage: control-dock.sh [-h] [-s]
#   -h: Hide the dock (turn autohide on)
#   -s: Show the dock (turn autohide off)

set_autohide() {
    osascript -e "tell application \"System Events\" to tell dock preferences to set autohide to $1"
}

usage() {
    echo "Usage: $0 [-h] [-s]"
    echo "  -h: Hide the dock"
    echo "  -s: Show the dock"
}

if [ $# -eq 0 ]; then
    usage
    exit 1
fi

while getopts "hs" opt; do
    case $opt in
        h) set_autohide true ;;
        s) set_autohide false ;;
        *)
            usage >&2
            exit 1
            ;;
    esac
done
