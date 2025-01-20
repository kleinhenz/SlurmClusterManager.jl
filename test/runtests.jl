const directory_separator = Sys.iswindows() ? ';' : ':'
@info "" Base.active_project() Base.DEPOT_PATH=join(Base.DEPOT_PATH, directory_separator) Base.LOAD_PATH=join(LOAD_PATH, directory_separator)
@info "" JULIA_PROJECT=get(ENV, "JULIA_PROJECT", "") JULIA_DEPOT_PATH=get(ENV, "JULIA_DEPOT_PATH", "") JULIA_LOAD_PATH=get(ENV, "JULIA_LOAD_PATH", "")

println(Base.stderr, "# BEGIN contents of project.toml: $(Base.active_project())")
read(Base.active_project(), String) |> println
println(Base.stderr, "# END contents of project.toml: $(Base.active_project())")

Base.flush(Base.stdout)
Base.flush(Base.stderr)

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
  # Make sure to propagate `JULIA_PROJECT=Base.active_project()`.
  # This ensures that SlurmClusterManager.jl, Distributed.jl, and Test.jl are available.
  project_path = Base.active_project()
  println("project_path = $project_path")
  jobid = withenv("JULIA_PROJECT"=>project_path) do
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
