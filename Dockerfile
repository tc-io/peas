# Inspired by @jpetazzo's Docker in Docker: https://github.com/jpetazzo/dind

FROM ubuntu
MAINTAINER tom@tombh.co.uk
RUN echo deb http://archive.ubuntu.com/ubuntu precise universe > /etc/apt/sources.list.d/universe.list
RUN apt-get update -qq

# DinD deps
RUN apt-get install -qqy iptables ca-certificates lxc
ADD https://get.docker.io/builds/Linux/x86_64/docker-0.9.0 /usr/local/bin/docker
ADD ./wrapdocker /usr/local/bin/wrapdocker

# Peas deps
RUN apt-get install -qqy python-software-properties
RUN apt-add-repository ppa:brightbox/ruby-ng -y
RUN apt-get update
RUN apt-get install -qqy ruby2.1 ruby2.1-dev build-essential libssl-dev git mongodb redis-server
RUN docker pull progrium/buildstep
ADD ./ /home/peas
RUN cd /home/peas
RUN gem install bundler
RUN bundle install

# DinD magic
RUN chmod +x /usr/local/bin/docker /usr/local/bin/wrapdocker
VOLUME /var/lib/docker
CMD wrapdocker