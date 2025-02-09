# SlurmClusterManager.jl

![Build Status](https://github.com/JuliaParallel/SlurmClusterManager.jl/actions/workflows/ci.yml/badge.svg)

This package provides support for using Julia within the Slurm cluster environment.
The code is adapted from [ClusterManagers.jl](https://github.com/JuliaParallel/ClusterManagers.jl) with some modifications.

## Usage

This script uses all resources from a Slurm allocation as julia workers and prints the id and hostname on each one.

```jl
#!/usr/bin/env julia

using Distributed, SlurmClusterManager
addprocs(SlurmManager())
@everywhere println("hello from $(myid()):$(gethostname())")
```

If the code is saved in `script.jl` it can be queued and executed on two nodes using 64 workers per node by running

```
sbatch -N 2 --ntasks-per-node=64 script.jl
```

## Differences from `ClusterManagers.jl`

* Only supports Slurm (see this [issue](https://github.com/JuliaParallel/ClusterManagers.jl/issues/58) for some background).
* Requires that `SlurmManager` be created inside a Slurm allocation created by sbatch/salloc.
  Specifically `SLURM_JOBID` and `SLURM_NTASKS` must be defined in order to construct `SlurmManager`.
  This matches typical HPC workflows where resources are requested using sbatch and then used by the application code.
  In contrast `ClusterManagers.jl` will  *dynamically* request resources when run outside of an existing Slurm allocation.
  I found that this was basically never what I wanted since this leaves the manager process running on a login node,
  and makes the script wait until resources are granted which is better handled by the actual Slurm queueing system.
* Does not take any Slurm arguments. All Slurm arguments are inherited from the external Slurm allocation created by sbatch/salloc.
* Output from workers is redirected to the manager process instead of requiring a separate output file for every task.
