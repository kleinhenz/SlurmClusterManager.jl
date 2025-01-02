#!/usr/bin/env julia

using Distributed, Test, SlurmClusterManager

# test that slurm is available
@test !(Sys.which("sinfo") === nothing)

SlurmClusterManager_dir = pkgdir(SlurmClusterManager)
script_file = joinpath(SlurmClusterManager_dir, "test", "test_inheritance", "script_inheritance.jl")

# submit job
# project should point to top level dir so that SlurmClusterManager is available to script.jl
project_path = @__DIR__
println("project_path = $project_path")
log_file = joinpath(@__DIR__, "test_inheritance.out")
jobid = read(`sbatch --export=ALL --time=0:02:00 --parsable -n 2 -N 2 -o $log_file --wrap="julia --project=$project_path $script_file"`, String) # test a minimal config in a different location without env settings

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

# print job output
output = read(log_file, String)
println("script output:")
println(output)

state = getjobstate(jobid) |> split
println("job state = $state")
# length should be two because creating the workers creates a job step
@test length(state) == 4 # job_id (script.jl), job_id.ba+ (batch), job_ed.ex+ (extern), jobid.0 (julia)

# check that everything exited without errors
@test all(state .== "COMPLETED")
