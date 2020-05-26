#!/usr/bin/env julia

using Distributed, Test, SlurmClusterManager

# test that slurm is available
@test !(Sys.which("sinfo") === nothing)

# submit job
jobid = read(`sbatch --export=ALL --parsable -n 4 -o test.out script.jl`, String)
println("jobid = $jobid")

# get job state from jobid
getjobstate = jobid -> read(`sacct -j $jobid --format=state --noheader`, String)

# wait for job to complete
status = timedwait(60.0, pollint=1.0) do
  state = getjobstate(jobid)
  state == "" && return false
  state = first(split(state)) # don't care about jobsteps
  println("jobstate = $state")
  return state == "COMPLETED" || state == "FAILED"
end

# check that job finished running within timelimit (either completed or failed)
@test status == :ok

state = getjobstate(jobid) |> split
# length should be two because creating the workers creates a job step
@test length(state) == 2

# check that everything exited without errors
@test all(state .== "COMPLETED")

# print job output
read("test.out", String) |> print
