FROM ruby:2.4.10-buster

RUN apt-get update && apt-get install -y \
  qt5-default libqt5webkit5-dev gstreamer1.0-plugins-base gstreamer1.0-tools gstreamer1.0-x

WORKDIR /firehose/
COPY . /firehose/
RUN gem update --system 3.2.3
RUN gem install bundler:2.3.6
RUN bundle

EXPOSE 7474
CMD bundle exec firehose server
