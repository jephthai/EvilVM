# create a working EvilVM image

FROM debian

WORKDIR /

RUN apt-get update
RUN apt-get install --no-install-recommends -y mingw-w64 nasm
RUN apt-get install --no-install-recommends -y ruby ruby-sinatra ruby-sinatra-contrib thin pry
RUN apt-get install --no-install-recommends -y git bsdmainutils procps screen tmux

COPY ./ /evilvm/

