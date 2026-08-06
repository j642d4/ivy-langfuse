#!/bin/sh

# Run cleanup script before running migrations
# Check if DATABASE_URL is not set
if [ -z "$DATABASE_URL" ]; then
    # Check if all required variables are provided
    if [ -n "$DATABASE_HOST" ] && [ -n "$DATABASE_USERNAME" ] && [ -n "$DATABASE_PASSWORD" ]  && [ -n "$DATABASE_NAME" ]; then
        # Construct DATABASE_URL from the provided variables
        DATABASE_URL="postgresql://${DATABASE_USERNAME}:${DATABASE_PASSWORD}@${DATABASE_HOST}/${DATABASE_NAME}"
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
