#!/bin/sh

# Run cleanup script before running migrations
# Check if DATABASE_URL is not set
if [ -z "$DATABASE_URL" ]; then
    # Check if all required variables are provided
    if [ -n "$DATABASE_HOST" ] && [ -n "$DATABASE_USERNAME" ] && [ -n "$DATABASE_PASSWORD" ]  && [ -n "$DATABASE_NAME" ]; then
        # Append DATABASE_PORT only when it is explicitly set, so existing
        # deployments that embed the port in DATABASE_HOST keep working.
        db_host_with_port="${DATABASE_HOST}"
        if [ -n "$DATABASE_PORT" ]; then
            case "$DATABASE_PORT" in
                *[!0-9]*)
                    # e.g. Kubernetes service links can inject DATABASE_PORT=tcp://ip:port
                    echo "Warning: ignoring non-numeric DATABASE_PORT '${DATABASE_PORT}'"
                    ;;
                *)
                    case "${DATABASE_HOST##*\]}" in
                        *:*) echo "Info: DATABASE_HOST already contains a port; ignoring DATABASE_PORT." ;;
                        *)   db_host_with_port="${DATABASE_HOST}:${DATABASE_PORT}" ;;
                    esac
                    ;;
            esac
        fi
        # Construct DATABASE_URL from the provided variables
        DATABASE_URL="postgresql://${DATABASE_USERNAME}:${DATABASE_PASSWORD}@${db_host_with_port}/${DATABASE_NAME}"
        export DATABASE_URL
    else
        echo "Error: Required database environment variables are not set. Provide a postgres url for DATABASE_URL."
        exit 1
    fi
    if [ -n "$DATABASE_ARGS" ]; then
      # Append ARGS to DATABASE_URL
    	DATABASE_URL="${DATABASE_URL}?$DATABASE_ARGS"
    	export DATABASE_URL
    fi
fi

# See web/entrypoint.sh for the full explanation: Docker/ECS sets HOSTNAME to the
# container's own hostname (the task ENI's private DNS name in awsvpc mode), which
# the shell re-populates at startup regardless of what the task definition's
# environment list specifies. If the worker's HTTP server (health check on 3030)
# also binds to process.env.HOSTNAME, it ends up reachable only on that specific
# private IP, never on localhost — forcing it back to 0.0.0.0 here is the one
# point an external override can't be clobbered.
export HOSTNAME=0.0.0.0

# Run the command passed to the docker image on start
exec "$@"
