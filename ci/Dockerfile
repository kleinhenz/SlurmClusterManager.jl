FROM jkleinh/slurm-cluster as base
MAINTAINER Joseph Kleinhenz <jkleinh@umich.edu>

ARG JULIA_VERSION=1.6.0

RUN mkdir -p /home/docker/.local/opt/julia \
    && cd /home/docker/.local/opt/julia \
    && folder="$(echo ${JULIA_VERSION} | cut -d. -f1-2)" \
    && curl -L https://julialang-s3.julialang.org/bin/linux/x64/${folder}/julia-${JULIA_VERSION}-linux-x86_64.tar.gz | tar xz --strip 1 \
    && /home/docker/.local/opt/julia/bin/julia --version

ENV PATH="/home/docker/.local/opt/julia/bin:${PATH}"

COPY --chown=docker . SlurmClusterManager

CMD /bin/bash -l
