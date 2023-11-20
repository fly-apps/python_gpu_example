FROM ubuntu:22.04
RUN apt update -q && apt install -y python3 python3-pip git git-lfs nano && \
    apt clean && rm -f /var/lib/apt/lists/*_*

ENV PYTHON_USER="pythonuser"

SHELL ["/bin/bash", "-c"]

# Create unprivileged user with a home dir and using bash
RUN useradd -ms /bin/bash $PYTHON_USER
RUN mkdir /app && chown $PYTHON_USER:$PYTHON_USER /app
WORKDIR /app

COPY --chmod=0755 ./entrypoint.sh ./entrypoint.sh
COPY --chown=$PYTHON_USER:$PYTHON_USER --chmod=0755 ./post-initialization.sh ./post-initialization.sh

# CMD ["sleep", "inf"]
CMD ["/bin/bash", "-c", "./entrypoint.sh $PYTHON_USER"]
