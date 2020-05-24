#!/usr/bin/env julia

using Distributed, Test, SlurmClusterManager

# test that slurm is available
@test !(Sys.which("sinfo") === nothing)

# submit job
jobid = read(`sbatch --export=ALL --parsable -n 4 -o test.out script.jl`, String)
println("jobid = $jobid")

# wait for job to complete
status = timedwait(60.0, pollint=1.0) do
  state = read(`sacct -j $jobid --format=state --noheader`, String)
  state == "" && return false
  state = first(split(state)) # don't care about jobsteps
  println("jobstate = $state")
  return state == "COMPLETED" || state == "FAILED"
end
@test status == :ok

output = readlines("test.out")
println(output)
