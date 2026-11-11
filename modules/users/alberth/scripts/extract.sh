#!/bin/sh
#
# Usage: extract.sh <file>
# Description: extracts archived files / mounts disk images
# Note: .dmg/hdiutil is macOS-specific.
#
# credit: http://nparikh.org/notes/zshrc.txt

if [ $# -ne 1 ]; then
    echo "Usage: $0 <file>" >&2
    exit 1
fi

if [ ! -f "$1" ]; then
    echo "'$1' is not a valid file" >&2
    exit 1
fi

case $1 in
    *.tar.bz2)  tar -jxvf "$1"                ;;
    *.tar.gz)   tar -zxvf "$1"                ;;
    *.bz2)      bunzip2 "$1"                  ;;
    *.dmg)      hdiutil mount "$1"            ;;
    *.gz)       gunzip "$1"                   ;;
    *.tar)      tar -xvf "$1"                 ;;
    *.tbz2)     tar -jxvf "$1"                ;;
    *.tgz)      tar -zxvf "$1"                ;;
    *.zip)      unzip "$1"                    ;;
    *.ZIP)      unzip "$1"                    ;;
    *.pax)      pax -r <"$1"                  ;;
    *.pax.Z)    uncompress -c "$1" | pax -r   ;;
    *.rar)      unrar x "$1"                  ;;
    *.Z)        uncompress "$1"               ;;
    *)
        echo "'$1' cannot be extracted/mounted via extract" >&2
        exit 1
        ;;
esac
