FROM jkleinh/slurm-cluster as base
MAINTAINER Joseph Kleinhenz <jkleinh@umich.edu>

RUN mkdir -p /home/docker/.local/opt/julia \
    && cd /home/docker/.local/opt/julia \
    && curl -L https://julialang-s3.julialang.org/bin/linux/x64/1.6/julia-1.6.0-linux-x86_64.tar.gz | tar xz --strip 1

ENV PATH="/home/docker/.local/opt/julia/bin:${PATH}"

COPY --chown=docker . SlurmClusterManager
ENV JULIA_PROJECT="/home/docker/SlurmClusterManager"

CMD /bin/bash -l
