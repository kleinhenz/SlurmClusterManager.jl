#!/usr/bin/env julia

using Test, Distributed, SlurmClusterManager
addprocs(SlurmManager())

@test nworkers() == parse(Int, ENV["SLURM_NTASKS"])

hosts = map(workers()) do id
  remotecall_fetch(() -> gethostname(), id)
end
sort!(hosts)

@test hosts == ["c1", "c1", "c2", "c2"]
