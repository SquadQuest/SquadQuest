# Supabase Docker

This is a minimal Docker Compose setup for self-hosting Supabase. Follow the steps [here](https://supabase.com/docs/guides/hosting/docker) to get started.

## SquadQuest Quickstart

1. Copy the fake env vars:

    ```bash
    cp .env.example .env
    ```

1. Pull the latest images:

    ```bash
    docker compose pull
    ```

1. Start the services (in detached mode):

    ```bash
    docker compose up -d
    ```

1. Initialize SquadQuest database schema:

    ```bash
    ./squadquest-init.sh
    ```

1. Log in to the Supabase Dashboard with the default credentials from `.env.example`:

    <http://supabase:this_password_is_insecure_and_should_be_updated@localhost:8000/>

## Starting Fresh

1. Shut down all containers, deleting Docker-managed volumes:

    ```bash
    docker compose down -v
    ```

1. Delete mounted volume directories:

    ```bash
    rm -r volumes/{db/data,storage}
    ```
