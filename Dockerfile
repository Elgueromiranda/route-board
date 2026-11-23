FROM ruby:4.0.7-slim

WORKDIR /app

# Changed libsqlite3-dev to libpq-dev for PostgreSQL support
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential libpq-dev nodejs npm curl && \
    rm -rf /var/lib/apt/lists/*

COPY route_board/Gemfile route_board/Gemfile.lock ./
RUN bundle install

COPY route_board/ ./

EXPOSE 3000
