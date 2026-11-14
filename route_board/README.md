# RouteBoard

## Development

Pollen uses Redis Pub/Sub and a persisted stream record. Start Redis in its own terminal:

```sh
redis-server
```

From `route_board/`, install dependencies and prepare the database:

```sh
bundle install
bin/rails db:prepare
```

Start Rails with Pollen enabled:

```sh
START_POLLEN=true bin/rails s
```

From `route-board/`, start the frontend separately:

```sh
npm run dev
```

Pollen runs inside the Rails server process; there is no `bundle exec pollen` command. To use a non-default Redis URL locally, set `REDIS_URL` before starting Rails. Production reads `redis_url` from Rails credentials and enables Pollen through the deployment environment.

## Database

Pollen's migration adds the persisted stream table. Apply migrations with `bin/rails db:prepare` after deploying schema changes.

## Tests

Run the Rails tests with `bin/rails test` from `route_board/`.
