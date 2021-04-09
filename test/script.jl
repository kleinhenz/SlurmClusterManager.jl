#!/usr/bin/env julia

using Distributed, SlurmClusterManager
addprocs(SlurmManager())

@assert nworkers() == parse(Int, ENV["SLURM_NTASKS"])

hosts = map(workers()) do id
  remotecall_fetch(() -> gethostname(), id)
end
sort!(hosts)

@assert hosts == ["c1", "c1", "c2", "c2"]
