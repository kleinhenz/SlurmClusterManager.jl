module SlurmClusterManager

# We don't do `using Foo`.
# We either do `using Foo: hello, world`, or we do `import Foo`.
# https://github.com/JuliaLang/julia/pull/42080

import Distributed

# Bring these names into scope because we are going to re-export them:
using Distributed: launch, manage

# We re-export Distributed.launch and Distributed.manage:
export launch, manage

# We also export SlurmManager:
export SlurmManager

# Bring some other names into scope, just for convenience:
using Distributed: ClusterManager, WorkerConfig, cluster_cookie

include("slurmmanager.jl")

end # module
