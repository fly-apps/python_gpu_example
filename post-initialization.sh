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
# If you want to get project Python deps using requirements.txt, uncomment this and 
# adjust the Dockerfile to copy the file into the image
# cp /requirements.txt .

# The following only installs pip packages if Jupyter isn't yet installed; 
# essentially on first boot.
if pip show jupyter &> /dev/null; then
    echo "Jupyter is installed with pip."
else
    echo "Installing packages with pip"
    # Uncomment to use requirements.txt. You can also install more packages
    # after deployment. This Python venv lives on the persistent Fly Volume.
    # pip install -r requirements.txt

    # Install from scratch without a requirements.txt; some examples:
    pip install jupyter 
    # pip install numpy torch # numpy isn't getting installed as a dep of torch so do it explicitly
    # pip install diffusers transformers accelerate # HuggingFace libs for specific projects
fi

echo "Starting Jupyter notebook server!"
jupyter notebook --ip $FLY_PRIVATE_IP --no-browser

# If you don't want Jupyter, use the `sleep inf` command instead, and 
# `fly ssh console` into the Machine to interact with it.
# sleep inf
