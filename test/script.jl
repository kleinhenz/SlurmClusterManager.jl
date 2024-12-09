#!/usr/bin/env julia

using Distributed, SlurmClusterManager
addprocs(SlurmManager(verbose=true))

@assert nworkers() == parse(Int, ENV["SLURM_NTASKS"])

hosts = map(workers()) do id
  remotecall_fetch(() -> gethostname(), id)
end
sort!(hosts)

@everywhere println("Host $(myid()): $(gethostname())") # workers report in
