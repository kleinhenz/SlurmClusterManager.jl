#!/usr/bin/env julia

const directory_separator = Sys.iswindows() ? ';' : ':'
@info "" Base.active_project() Base.DEPOT_PATH=join(Base.DEPOT_PATH, directory_separator Base.LOAD_PATH=join(LOAD_PATH, directory_separator)
@info "" JULIA_PROJECT=get(ENV, "JULIA_PROJECT", "") JULIA_DEPOT_PATH=get(ENV, "JULIA_DEPOT_PATH", "") JULIA_LOAD_PATH=get(ENV, "JULIA_LOAD_PATH", "")

# We don't use `using Foo` here.
# We either use `using Foo: hello, world`, or we use `import Foo`.
# https://github.com/JuliaLang/julia/pull/42080
using Distributed: addprocs, workers, nworkers, remotecall_fetch
using SlurmClusterManager: SlurmManager

addprocs(SlurmManager())

# We intentionally do not use `@assert` here.
# In a future minor release of Julia, `@assert`s may be disabled by default.
const SLURM_NTASKS = parse(Int, ENV["SLURM_NTASKS"])
if nworkers() != SLURM_NTASKS
  msg = "Test failed: nworkers=$(nworkers()) does not match SLURM_NTASKS=$(SLURM_NTASKS)"
  error(msg)
end

const hosts = map(workers()) do id
  remotecall_fetch(() -> gethostname(), id)
end
sort!(hosts)
println("List of hosts: ", hosts)

# We don't use `@assert` here, for reason described above.
if hosts != ["c1", "c1", "c2", "c2"]
  msg = "Test failed: observed_hosts=$(hosts) does not match expected_hosts=[c1, c1, c2, c2]"
  error(msg)
end
