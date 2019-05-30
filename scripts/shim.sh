#!/bin/bash

function usage() {
	echo
	echo " usage: evilvm shim [protocol]"
	echo
	echo " EvilVM is built with modular I/O layers, but the server"
	echo " only receives connections as TCP sockets.  To support other"
	echo " protocols, EvilVM uses a 'shim' architecture, where server"
	echo " processes handle connections via other technologies, and"
	echo " forward or proxy data to the server console."
	echo
	echo " Supported protocol shims:"
	echo
	echo "     http"
	echo

	exit 1
}

id=`docker ps | awk '$2=="evilvm"{print $1}'`

if [ -z "$id" ] ; then
    echo "Must run the main server first, before adding shims"
    exit 2
fi

echo "Found server docker instance: ${id}"

case $2 in
    "http")
	docker exec -it $id /evilvm/server/http-server.rb
    ;;
    *)
	usage
	;;
esac
