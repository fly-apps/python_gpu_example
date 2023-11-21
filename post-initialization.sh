#!/bin/bash

PROJECT_DIR="project"
VENV_DIR="$PROJECT_DIR-venv"

echo "Running post-initialization script as $USER."
echo "Entering $USER's home dir"
cd ~
echo "Creating venv dir for $PROJECT_DIR if it doesn't exist"
mkdir -p $VENV_DIR 
echo "Creating venv in $VENV_DIR if it doesn't exist"

if [ ! -f "$VENV_DIR/pyvenv.cfg" ]; then
    echo "No 'pyvenv.cfg' file found in $VENV_DIR; creating a venv"
    python3 -m venv $VENV_DIR
fi

echo "Activating venv in $VENV_DIR"
source $VENV_DIR/bin/activate

echo "Creating dir $PROJECT_DIR if it doesn't exist"
mkdir -p $PROJECT_DIR && cd $PROJECT_DIR
cp /requirements.txt .

if pip show jupyter &> /dev/null; then
    echo "Jupyter is installed with pip."
else
    echo "Installing packages with pip"
    # Adapt the pip packages to match your project's needs. You can also install more 
    # after deployment. This Python venv lives on the persistent Fly Volume.
    pip install -r requirements.txt

    # Or install from scratch without a requirements.txt; some examples:
    # pip install jupyter 
    # pip install numpy torch # numpy isn't getting installed as a dep of torch so do it explicitly
    # pip install diffusers transformers accelerate # HuggingFace libs for specific projects
fi

echo "Starting Jupyter notebook server!"
jupyter notebook --ip $FLY_PRIVATE_IP --no-browser

# If you don't want Jupyter, use the `sleep inf` command instead, and 
# `fly ssh console` into the Machine to interact with it.
# sleep inf
