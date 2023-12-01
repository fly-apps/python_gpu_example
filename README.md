# A GPU-enabled Python development Machine

The goal: a CUDA-enabled Python template environment on a Fly GPU Machine, for working with ML models.

We'll start with a minimal Ubuntu Linux, add a non-root user, and set up a Python virtual environment for a project, with NVIDIA libraries and Jupyter Notebook installed. 

_Fly GPUs are only available to vetted orgs right now; join the waitlist_

## Deployment to Fly.io
### Create a Fly App
 `fly apps create <app-name>`
### Clone the example repo:
`git clone git@github.com:fly-apps/python_gpu_example.git && cd python_gpu_example`
### Edit `fly.toml` as desired
* At the least, change `app` to match the name of the app you just created
* Edit `primary_region` if wanted -- make sure to choose a region in which GPU Machines are available. Check the [docs](https://fly.io/docs/gpus/gpu-quickstart/) for GPU regions.
* Optionally, change the NONROOT_USER `build.arg` -- if you do, also edit the `destination` of the volume mount in `mounts` to match
* Optionally, tweak `swap_size_mb` 

### Deploy
 `fly deploy`
 
 The `fly deploy` command launches the app, provisioning initial resources on first run. In this case, it creates one Fly Machine VM and one Fly Volume. When an app is configured to use a volume, `fly deploy` does not create a redundant or standby Machine.

## Using the Machine

### Jupyter notebook

The easiest way to visit a private Fly App with the browser is with `fly proxy` command, which proxies a local port to a Machine.

Run `fly logs` to find a line like 

```
http://127.0.0.1:8888/tree?token=c5fe8a87d8c00dd16637f0d4a1d8df7e3590c6a6064bbb6b
```

from Jupyter. Visit that link in the browser and you can start up a notebook.


### Terminal

Connect to the Machine using `fly ssh console`. To activate the configured venv, do the following:

```
# su pythonuser
$ cd ~/project/
$ source ~/project-venv/bin/activate 
```

Then you can install new pip packages to the persistent volume, download models, and run the Python REPL or execute scripts.

To deactivate the venv, type `deactivate`. To drop back to the root user, hit <kbd>CTRL-D</kbd>.

As the root user, you can use apt to manage system-wide software. Anything you install with apt is installed to the Machine's root file system, which means it disappears when the Machine next shuts down, so if you find yourself doing this, remember to add them to the Dockerfile, ready to be built into the image on the next deployment.

## Fly.io-specific things
Fly Launch doesn't have a scanner that will set this up just how we want, so the prep looks a lot like preparing a Docker container. We're configuring and running a Fly Machine instead, of course
* We'll use `fly deploy` to launch the Machine using configuration stored in the Fly Launch app config file, `fly.toml`
* Persistent storage is provided by a Fly Volume attached to the Machine
* Fly GPU Machines come configured to use their GPU hardware, with NVIDIA drivers installed. You can launch a vanilla Ubuntu image and run nvidia-smi with no further setup
* This project makes use of Fly.io IPv6 private networking. It could also be configured with a Fly Proxy service so it's available via a public Anycast or private Flycast IP address

## General considerations
There's no one right way to set up a project like this. Here are some of the considerations that went into the example:

### Data storage
Machine learning tends to involve large quantities of data. We're working with a few constraints:
* Large Docker images (many gigabytes) can be very unwieldy to push and pull, particularly over large geographical distances.
* The root file system of a Fly Machine is ephemeral -- it's reset from its Docker image on every restart. It's also limited to 50GB on GPU-enabled Machines.
* Fly Volumes are limited to 500GB, and are attached to a physical server. The Machine must run on the same hardware as the volume it mounts.

We want to shut down GPU Machines when they're not needed, either manually with `fly machine stop`, or using the Fly Proxy autostop and autostart features, so it's not desirable to download many GB of models or libraries whenever the Machine restarts. 

The compromise we use here is to generate a sub-1GB Docker image and store the project's pip packages and any downloaded data on the Fly Volume. This keeps all pip dependencies together in one venv for easy coordination and flexibility. With a well-established workload, you might make a different calculation; maybe all the projects deps actually fit in a manageable Docker image, and you can dispense with the volume storage, or some packages can we installed system-wide with apt, leaving less to manage with pip.

### Compute
The GPUs available at this time are a100-sxm4-80gb and a100-pcie-40gb, and you can use one GPU per Machine. We're not currently looking at model training on a massive scale; with careful design we can certainly do some reasonable inference. Here we're looking at running models manually so we'll stick with a single Machine, but an obvious use for Fly GPU Machines is as a "stateless" service for an app whose front end and any other components run on cheaper CPU-only Machines. This allows for horizontal scaling and traffic-based capacity scaling by starting and stopping Machines.

At this time, Fly GPU Machines are provisioned with the `performance-8x` CPU config and 32GB RAM by default. Playing very crudely with a language model, I found it easy to out-of-memory kill my Jupyter (Python) kernel with 32GB of RAM. If you need more RAM and fastest performance, scale up with `fly scale memory`, but losing work is annoying, so it's worth enabling swap.

## Specifics

### App configuration
The example `fly.toml` file does the following:

* Sets the name of the app to deploy to 
* Sets the app's primary region, where `fly deploy` will put the initial Machine. Deployment will fail if this region doesn't have GPUs available (or is out of capacity).
* Specifies Machine resources (most crucially a GPU) using a preset (`a100-40gb`)
* Configures swap
* Sets a build argument that the Dockerfile uses to set the name of the non-root user
* Configures a volume mount. `fly deploy` provisions a new volume on first run (or when there's no Machine or Volume present on the app). You can specify the size for the initial volume here if desired

### The Docker image

Ready-made Docker images exist for many ML-related projects. There is a CUDA-enabled Jupyter Docker image, but it's kind of a black box and it's not maintained by the Jupyter folks, though they link to it. 

Here we'll go step by step from a small Ubuntu image, installing and configuring a Python development environment that can use the GPU's CUDA capabilities, kind of like we would with a normal computer.

Here's a summary of what the Dockerfile does;

* Uses Ubuntu 22.04 as a base image, as it's compatible with the NVIDIA drivers on Fly Machines
* Installs system-wide packages with the apt package manager: python3, python3-pip, python3-venv, python3-wheel, git, nano (substitute your favourite terminal-compatible text editor here)
* Adds a non-root user to own the Python venv and run things. Gets the name for this user from a `[build.arg]` set in `fly.toml`
* Copies the scripts for root and the user to run at startup
* CMD invokes the first script with the non-root user name as argument

### Entrypoint script
When this Machine boots, it runs the script `entrypoint.sh` as root. 

This script gives the non-root user (whose username is set to `pythonuser` via a build argument in `fly.toml`) ownership of the non-root user's home directory to that user. This is necessary, because we're mounting a Fly Volume over that point in the Machine file system.

Then it runs `nvidia-smi` to make sure the GPU drivers are loaded and the device is ready for the non-root user to use.

Then it runs the next script (`post-initialization.sh`) as the non-root (`pythonuser`) user.

You could instead have it run `sleep inf` here, and `fly ssh console` into the Machine after deployment to finish setting up the environment on the persistent volume.

### Post-initialization script
This script, `post-initialization.sh`, runs as the non-root user. It activates a virtual environment for the project and runs Jupyter from a project directory. It also puts some things on the persistent home directory, if they're absent. More specifically, it does this:

* Ensures there's a dir called `~/project` with a Python virtual environment created
* Activates this venv
* Uses the presence or absence of the `jupyter` pip package as a proxy for whether it's the first run or not (if there was a venv, then it's not the first run, but it checks anyway). If Jupyter isn't installed, it installs it. Tailor this to whatever pip packages you want. If you want to run Jupyter on boot, `jupyter` is the only package you absolutely need here. You can install more pip packages persistently straight from the Jupyter notebook interface.
* Starts a Jupyter server on the Machine's private IPv6 address so it's only accessible using Fly.io private networking--i.e. over a WireGuard connection (including user-mode WireGuard with the `fly proxy` command)
  
This example project is meant to be a transparent template you can build on. Tailor this script to install different packages, use different directories, install from `requirements.txt`, or even skip Jupyter and use the `sleep inf` command to keep the Machine running so you can `fly ssh console` in and just work from the terminal or the Python REPL.

## Files

https://github.com/fly-apps/python_gpu_example.git
