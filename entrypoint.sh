#!/bin/bash

USERNAME=$1

echo "Inside entrypoint script."
chown $USERNAME:$USERNAME /home/$USERNAME
nvidia-smi # This seems to initialize the driver so that non-root user can use the GPU

echo "About to run post-initialization script as $USERNAME."
su -c "bash ./post-initialization.sh" $USERNAME
