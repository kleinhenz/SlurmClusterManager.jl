"""
ClusterManager for a Slurm allocation

Represents the resources available within a slurm allocation created by salloc/sbatch.
The environment variables `SLURM_JOBID` and `SLURM_NTASKS` must be defined to construct this object.
"""
struct SlurmManager <: ClusterManager 
  jobid::Int
  ntasks::Int
  verbose::Bool
  launch_timeout::Float64

  function SlurmManager(;verbose=false, launch_timeout=60.0)
    @assert "SLURM_JOBID" in keys(ENV)
    @assert "SLURM_NTASKS" in keys(ENV)

    jobid = parse(Int, ENV["SLURM_JOBID"])
    ntasks = parse(Int, ENV["SLURM_NTASKS"])

    new(jobid, ntasks, verbose, launch_timeout)
  end
end

function launch(manager::SlurmManager, params::Dict, instances_arr::Array, c::Condition)
    try
        exehome = params[:dir]
        exename = params[:exename]
        exeflags = params[:exeflags]

        srun_cmd = `srun -D $exehome $exename $exeflags --worker=$(cluster_cookie())`
        srun_proc = open(srun_cmd)

        t = @async for i in 1:manager.ntasks
          manager.verbose && println("connecting to worker $i out of $(manager.ntasks)")

          line = readline(srun_proc)
          m = match(r".*:(\d*)#(.*)", line)
          m === nothing && error("could not parse $line")

          config = WorkerConfig()
          config.port = parse(Int, m[1])
          config.host = strip(m[2])

          # Keep a reference to the proc, so it's properly closed once the last worker exits.
          config.userdata = srun_proc
          push!(instances_arr, config)
          notify(c)
        end

        # workers must be launched before timeout otherwise interrupt
        status = timedwait(() -> istaskdone(t), manager.launch_timeout)
        if status !== :ok
          @async Base.throwto(t, ErrorException("launch_timeout exceeded"))
        end
        wait(t)

        # redirect output
        @async while !eof(srun_proc)
          line = readline(srun_proc)
          println(line)
        end

    catch e
        println("Error launching Slurm job:")
        rethrow(e)
    end
end

function manage(manager::SlurmManager, id::Integer, config::WorkerConfig, op::Symbol)
    # This function needs to exist, but so far we don't do anything
end
