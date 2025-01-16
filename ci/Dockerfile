FROM ghcr.io/kleinhenz/docker-slurm-cluster@sha256:ed26ab967e84c955f75499d50ef7a4f844e48d7812de5ef6b64423728d9d10c2 as base
MAINTAINER Joseph Kleinhenz <jkleinh@umich.edu>

ARG JULIA_VERSION=1.11.2

RUN mkdir -p /home/docker/.local/opt/julia \
    && cd /home/docker/.local/opt/julia \
    && folder="$(echo ${JULIA_VERSION} | cut -d. -f1-2)" \
    && curl -L https://julialang-s3.julialang.org/bin/linux/x64/${folder}/julia-${JULIA_VERSION}-linux-x86_64.tar.gz | tar xz --strip 1 \
    && /home/docker/.local/opt/julia/bin/julia --version

ENV PATH="/home/docker/.local/opt/julia/bin:${PATH}"

COPY --chown=docker . SlurmClusterManager

CMD /bin/bash -l
