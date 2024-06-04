#!/bin/bash

# Name of the Docker image to use
IMAGE="ubuntu:latest"

# Name of the container
CONTAINER_NAME="setup-script-test"

# Path to your setup script
SETUP_SCRIPT_PATH="./setup.sh"

# Check if the setup script exists
if [ ! -f "$SETUP_SCRIPT_PATH" ]; then
    echo "Setup script not found at $SETUP_SCRIPT_PATH"
    exit 1
fi

# Pull the latest Ubuntu image
docker pull $IMAGE

# Run the Docker container with the setup script and environment variables
docker run --rm --name $CONTAINER_NAME \
    -v "$PWD:/usr/src/app" \
    -w /usr/src/app \
    -e ALERT_EMAIL="$ALERT_EMAIL" \
    -e LARAVEL_REPO_URL="$LARAVEL_REPO_URL" \
    -e DOMAIN_NAME="$DOMAIN_NAME" \
    -e SKIP_INPUT="$SKIP_INPUT" \
    -e SSH_KEY_PRIVATE="$SSH_KEY_PRIVATE" \
    -e SSH_KEY_PUBLIC="$SSH_KEY_PUBLIC" \
    -i -t \
    $IMAGE bash -c "
    apt-get update -y && \
    apt-get -y install sudo adduser && \
    chmod +x $SETUP_SCRIPT_PATH && \
    $SETUP_SCRIPT_PATH
"

# Check the exit status of the Docker run command
if [ $? -eq 0 ]; then
    echo "Setup script executed successfully."
else
    echo "Setup script execution failed."
    exit 1
fi
