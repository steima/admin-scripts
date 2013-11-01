#!/bin/sh                                                                                                                                                    

die() {
        echo >&2 "$@"
        exit 1
}

[ "$#" -eq 2 ] || die "usage: ${0} <local-file-name> <remote-file-name>"

SOURCE="${1}"
TARGET="${2}"



for h in hopper lovelace neumann ritchie touring zuse pausch weizenbaum ; do
        scp "${SOURCE}" "${h}:${TARGET}"
done
