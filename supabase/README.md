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

## Debugging functions

1. Uncomment the following line in `docker-compose.yml` under the `functions` service:

    ```yaml
    --inspect-wait=0.0.0.0:9229
    ```

1. Apply changes to `docker-compose.yml` to running services:

    ```bash
    docker compose up -d
    ```

1. Run the `Attach to Deno` launch task in VSCode and set some breakpoints in your editor!

 ### Viewing logs

 You can also see `console.log` and `console.error` output by following logs for the `functions` service:

 ```bash
 docker compose logs -f functions
 ```
