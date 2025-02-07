# We don't use `using Foo` here.
# We either use `using Foo: hello, world`, or we use `import Foo`.
# https://github.com/JuliaLang/julia/pull/42080
using Distributed: addprocs, workers, nworkers, remotecall_fetch, @everywhere
using SlurmClusterManager: SlurmManager

addprocs(SlurmManager())

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

# To run tests outside of CI, set e.g.
# `export JULIA_SLURMCLUSTERMANAGER_IS_CI=false`
# in your Bash session before you launch the Slurm job.
function is_ci()
  name = "JULIA_SLURMCLUSTERMANAGER_IS_CI"

  # We intentionally default to true.
  # This allows things to work in our CI (which is inside of Docker).
  default_value = "true"

  value_str = strip(get(ENV, name, default_value))
  value_b = parse(Bool, value_str)
  return value_b
end

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

# We intentionally do not use `@assert` here.
# In a future minor release of Julia, `@assert`s may be disabled by default.
const SLURM_NTASKS = parse(Int, strip(ENV["SLURM_NTASKS"]))
if nworkers() != SLURM_NTASKS
  msg = "Test failed: nworkers=$(nworkers()) does not match SLURM_NTASKS=$(SLURM_NTASKS)"
  error(msg)
end
if length(workers()) != SLURM_NTASKS
  msg = "Test failed: length(workers())=$(length(workers())) does not match SLURM_NTASKS=$(SLURM_NTASKS)"
  error(msg)
end

const hosts = map(workers()) do id
  remotecall_fetch(() -> gethostname(), id)
end
sort!(hosts)
println("List of hosts: ", hosts)

if is_ci()
  @info "This is CI, so we will perform the hostname test"

  # We don't use `@assert` here, for reason described above.
  if hosts != ["c1", "c1", "c2", "c2"]
    msg = "Test failed: observed_hosts=$(hosts) does not match expected_hosts=[c1, c1, c2, c2]"
    error(msg)
  end
else
  @warn "This is not CI, so we will skip the hostname test"
end

@everywhere import Distributed

# Workers report in:
@everywhere println("Host $(Distributed.myid()): $(gethostname())")
