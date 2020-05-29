"""
ClusterManager for a Slurm allocation

Represents the resources available within a slurm allocation created by salloc/sbatch.
The environment variables `SLURM_JOBID` and `SLURM_NTASKS` must be defined to construct this object.
"""
mutable struct SlurmManager <: ClusterManager
  jobid::Int
  ntasks::Int
  verbose::Bool
  launch_timeout::Float64
  srun_proc::IO

  function SlurmManager(;verbose=false, launch_timeout=60.0)
    if !("SLURM_JOBID" in keys(ENV) && "SLURM_NTASKS" in keys(ENV))
      throw(ErrorException("SlurmManager must be constructed inside a slurm allocation environemnt. SLURM_JOBID and SLURM_NTASKS must be defined."))
    end

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
        manager.srun_proc = open(srun_cmd)

        t = @async for i in 1:manager.ntasks
          manager.verbose && println("connecting to worker $i out of $(manager.ntasks)")

          line = readline(manager.srun_proc)
          m = match(r".*:(\d*)#(.*)", line)
          m === nothing && error("could not parse $line")

          config = WorkerConfig()
          config.port = parse(Int, m[1])
          config.host = strip(m[2])

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
        @async while !eof(manager.srun_proc)
          line = readline(manager.srun_proc)
          println(line)
        end

        # wait to make sure that srun_proc exits before main program to avoid slurm complaining
        # avoids "Job step aborted: Waiting up to 32 seconds for job step to finish" message
        finalizer(manager) do manager
          wait(manager.srun_proc)
        end

    catch e
        println("Error launching Slurm job:")
        rethrow(e)
    end
end

function manage(manager::SlurmManager, id::Integer, config::WorkerConfig, op::Symbol)
    # This function needs to exist, but so far we don't do anything
end
