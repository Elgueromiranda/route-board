# RouteBoard — Shuttle Dispatch & Arrival Board

A simulated shuttle dispatch application built with Ruby on Rails (API backend) and React/Vite (frontend). It features live SSE (Server-Sent Events) updates via Pollen and Redis, a dispatcher dashboard, and a public arrival board.

## Quick Start (Docker - Recommended)

The easiest way to run this application is using Docker. This method handles all dependencies (Ruby, Node, Redis, SQLite) automatically and works on macOS, Windows, and Linux. It also automatically seeds the database using `db/data.json`.

**Prerequisites:**
*   [Docker](https://docs.docker.com/get-docker/) and Docker Compose must be installed and running.

**Instructions:**
1. Open a terminal in the project root (where `docker-compose.yml` is located).
2. Build and start the containers:
   ```bash
   docker compose up --build

