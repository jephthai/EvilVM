#!/bin/bash

echo $@
docker run --rm -v `pwd`:`pwd` -v ${ROOT}:/evilvm -w `pwd` -it evilvm /evilvm/build.rb "$@"
