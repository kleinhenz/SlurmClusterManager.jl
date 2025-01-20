# We don't use `using Foo` here.
# We either use `using Foo: hello, world`, or we use `import Foo`.
# https://github.com/JuliaLang/julia/pull/42080
import SlurmClusterManager
import Distributed
import Test

# Bring some names into scope, just for convenience:
using Test: @testset, @test

const original_JULIA_DEBUG = strip(get(ENV, "JULIA_DEBUG", ""))
if isempty(original_JULIA_DEBUG)
  ENV["JULIA_DEBUG"] = "SlurmClusterManager"
else
  ENV["JULIA_DEBUG"] = original_JULIA_DEBUG * ",SlurmClusterManager"
end

@testset "SlurmClusterManager.jl" begin
  # test that slurm is available
  @test !(Sys.which("sinfo") === nothing)
  
  # submit job
  # project should point to top level dir so that SlurmClusterManager is available to script.jl
  #
  # Use `sbatch` to submit the Slurm job.
  # Make sure to propagate `JULIA_PROJECT=SlurmClusterManager/Project.toml`.
  # This ensures that SlurmClusterManager.jl and Distributed.jl are available.
  #
  # We also append SlurmClusterManager/test` to `JULIA_LOAD_PATH`.
  # This ensures that Test.jl is available.
  # project_path = Base.active_project()

  directory_separator = Sys.iswindows() ? ';' : ':'
  SlurmClusterManagerROOTDIR_testdir = @__DIR__                                                 # ./SlurmClusterManager.jl/test
  SlurmClusterManagerROOTDIR = dirname(SlurmClusterManagerROOTDIR_testdir)                      # ./SlurmClusterManager.jl
  SlurmClusterManagerROOTDIR_projecttoml = joinpath(SlurmClusterManagerROOTDIR, "Project.toml") # ./SlurmClusterManager.jl/Project.toml
  
  JULIA_PROJECT = abspath(SlurmClusterManagerROOTDIR_projecttoml)                               # ./SlurmClusterManager.jl/Project.toml
  JULIA_LOAD_PATH = abspath(SlurmClusterManagerROOTDIR_testdir)                                 # ./SlurmClusterManager.jl/test

  @info "" JULIA_PROJECT JULIA_LOAD_PATH

  jobid = withenv("JULIA_PROJECT" => JULIA_PROJECT, "JULIA_LOAD_PATH" => JULIA_LOAD_PATH) do
    strip(read(`sbatch --export=ALL --parsable -n 4 -o test.out script.jl`, String))
  end
  println("jobid = $jobid")
  
  # get job state from jobid
  getjobstate = jobid -> begin
    cmd = Cmd(`scontrol show jobid=$jobid`, ignorestatus=true)
    info = read(cmd, String)
    state = match(r"JobState=(\S*)", info)
    return state === nothing ? nothing : state.captures[1]
  end
  
  # wait for job to complete
  status = timedwait(60.0, pollint=1.0) do
    state = getjobstate(jobid)
    state == nothing && return false
    println("jobstate = $state")
    return state == "COMPLETED" || state == "FAILED"
  end
  
  state = getjobstate(jobid)
  
  # check that job finished running within timelimit (either completed or failed)
  @test status == :ok
  @test state == "COMPLETED"
  
  # print job output
  output = read("test.out", String)
  println("script output:")
  println(output)

end # testset "SlurmClusterManager.jl"
