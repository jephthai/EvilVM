# create a working EvilVM image

FROM debian

WORKDIR /

RUN apt-get update
RUN apt-get install --no-install-recommends -y mingw-w64 
RUN apt-get install --no-install-recommends -y ruby ruby-sinatra ruby-sinatra-contrib thin pry
RUN apt-get install --no-install-recommends -y git bsdmainutils procps screen tmux
RUN apt-get install --no-install-recommends -y autoconf build-essential nasm curl xz-utils

COPY ./ /evilvm/

RUN cd /usr/local ; \
curl -L -s http://www.nasm.us/pub/nasm/releasebuilds/2.14.02/nasm-2.14.02.tar.xz | tar xJf - ; \
cd nasm-2.14.02/ ; \
./autogen.sh ; \
./configure ; \
make ; \
make install
