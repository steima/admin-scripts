#!/bin/bash                                                                                                                                                  

die() { 
        echo >&2 "$@"
        exit 1
}

TMPFILE=$(mktemp)
URL="https://www.spamhaus.org/drop/drop.txt"
CHAIN="spamhaus-drop"

curl -s "${URL}" > "${TMPFILE}"

iptables -F "${CHAIN}"
iptables -I "${CHAIN}" -j RETURN

LINES=$(cat ${TMPFILE} | wc -l)

cat "${TMPFILE}" | while read LINE ; do
	IP=$(echo "${LINE}" | sed 's/ ;.*//g') 
	iptables -I "${CHAIN}" -p tcp -s "${IP}" -j REJECT --reject-with tcp-reset
done

echo "Blocked ${LINES} IP address ranges in chain ${CHAIN}"

rm "${TMPFILE}"
