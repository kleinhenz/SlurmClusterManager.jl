FROM ghcr.io/kleinhenz/docker-slurm-cluster@sha256:c62b169970eaab879898a7df5950f888b0417147e06f8c0e32fd15087b22d9f2

ARG JULIA_VERSION=1.11.2

RUN mkdir -p /home/docker/.local/opt/julia \
    && cd /home/docker/.local/opt/julia \
    && folder="$(echo ${JULIA_VERSION} | cut -d. -f1-2)" \
    && curl -L https://julialang-s3.julialang.org/bin/linux/x64/${folder}/julia-${JULIA_VERSION}-linux-x86_64.tar.gz | tar xz --strip 1 \
    && /home/docker/.local/opt/julia/bin/julia --version

ENV PATH="/home/docker/.local/opt/julia/bin:${PATH}"

COPY --chown=docker . SlurmClusterManager

CMD /bin/bash -l
