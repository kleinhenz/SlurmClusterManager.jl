module SlurmClusterManager

# Hello world

export SlurmManager, launch, manage

using Distributed
import Distributed: launch, manage

include("slurmmanager.jl")

end # module
