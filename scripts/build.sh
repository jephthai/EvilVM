#!/bin/bash

echo $@
docker run -v `pwd`:`pwd` -w `pwd` -it evilvm /evilvm/build.rb "$@"
