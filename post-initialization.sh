#!/bin/bash

echo "Running post-initialization script as $USER."

export PATH=$PATH:~/.local/bin

if pip show jupyter &> /dev/null; then
    echo "Jupyter is installed with pip."
else
    echo "export PATH=$PATH:~/.local/bin" > ~/.bashrc 
    echo "Installing packages with pip"
    pip install jupyter --user
    # torch diffusers transformers accelerate --user
fi

echo "About to cd into $USER's home dir"
cd ~
echo "Starting jupyter notebook!"
jupyter notebook --ip $FLY_PRIVATE_IP --no-browser 

# sleep inf
