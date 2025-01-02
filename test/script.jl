#!/usr/bin/env julia

# We don't use `using Foo` here.
# We either use `using Foo: hello, world`, or we use `import Foo`.
# https://github.com/JuliaLang/julia/pull/42080
using Distributed: addprocs, workers, nworkers, remotecall_fetch, @everywhere
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

const is_ci = parse(Bool, strip(get(ENV, "CI", "false")))

if is_ci
  # We don't use `@assert` here, for reason described above.
  if hosts != ["c1", "c1", "c2", "c2"]
    msg = "Test failed: observed_hosts=$(hosts) does not match expected_hosts=[c1, c1, c2, c2]"
    error(msg)
  end
else
  # The specific hostnames of c1 and c2 are specific to the CI setup.
  # We don't expect people to have the same hostnames if they run the test suite locally.
  @warn "This is not CI, so we will skip the hostname test"
end

@everywhere import Distributed
@everywhere println("Host $(Distributed.myid()): $(gethostname())") # workers report in
