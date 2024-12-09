#!/usr/bin/env julia

using Distributed, Test, SlurmClusterManager

# test that slurm is available
@test !(Sys.which("sinfo") === nothing)

# NOTE: If in an interactive allocation (not sure how to check and avoid), the sbatch command below will fail on recent slurm versions. See [https://support.schedmd.com/show_bug.cgi?id=14298]
include("runtests_helpers.jl")
job_id = "SLURM_JOB_ID" in keys(ENV) ? ENV["SLURM_JOB_ID"] : nothing
if !isnothing(job_id) && is_interactive(job_id)
    slurm_version = get_slurm_version(;fail_on_error = false, verbose = true)
    if slurm_version >= (22, 5, 0)
      @warn("Slurm_version = $(join(slurm_version, ".")) | Modern Slurm (≥22.05.0) does not allow running sbatch jobs that contain srun, mpirun, mpiexec commands if those jobs are submitted from within an interactive srun job. Run from a non-interactive session. Skipping tests...")
      # @test false # force test to fail [leave off by default in case this is part of a larger test suite/CI pipeline]
      exit(0)
    end
end

# submit job
# project should point to top level dir so that SlurmClusterManager is available to script.jl
project_path = abspath(joinpath(@__DIR__, ".."))
println("project_path = $project_path")
# Test workers with JULIA_PROJECT set in env
jobid = withenv("JULIA_PROJECT"=>project_path) do
  read(`sbatch --export=ALL --time=0:02:00 --parsable -n 2 -N 2 -o test.out script.jl`, String) # test a minimal config.
end
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
output = read("test.out", String)
println("script output:")
println(output)

state = getjobstate(jobid) |> split
# length should be two because creating the workers creates a job step
@test length(state) == 4 # job_id (script.jl), job_id.ba+ (batch), job_ed.ex+ (extern), jobid.0 (julia)

# check that everything exited without errors
@test all(state .== "COMPLETED")

# Test workers automatically inheriting environment
include("test_inheritance/runtests_inheritance.jl") # Test workers properly inherit environment by default