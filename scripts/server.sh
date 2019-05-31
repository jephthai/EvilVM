#!/bin/bash

function usage() {
    echo
    echo " usage: evilvm server run"
    echo
    echo " This script runs the server console for EvilVM. When run"
    echo " without arguments, you will see this text.  When given the"
    echo " 'run' command, the server will run in the foreground and"
    echo " receive inbound connections on port 1919."
    echo
    exit 1
}

case $2 in
    "run")
	docker run -p 1919:1919 -p 1920:1920 -v `pwd`:`pwd` -v `pwd`:/evilvm -w `pwd` -it evilvm /evilvm/server/server.rb "$@"
	;;
    *)
	usage
	;;
esac

