FROM ruby:4.0.7-slim

WORKDIR /app

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential libsqlite3-dev nodejs npm curl && \
    rm -rf /var/lib/apt/lists/*

COPY route_board/Gemfile route_board/Gemfile.lock ./
RUN bundle install

COPY route_board/ ./

EXPOSE 3000