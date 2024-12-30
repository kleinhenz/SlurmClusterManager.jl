"""
ClusterManager for a Slurm allocation

Represents the resources available within a slurm allocation created by salloc/sbatch.\\
The environment variables `SLURM_JOB_ID` or `SLURM_JOBID` and `SLURM_NTASKS` must be defined to construct this object.
"""
mutable struct SlurmManager <: ClusterManager
  jobid::Int
  ntasks::Int
  verbose::Bool
  launch_timeout::Float64
  srun_post_exit_sleep::Float64
  srun_proc

  function SlurmManager(;verbose=false, launch_timeout=60.0, srun_post_exit_sleep=0.01)

    jobid =
    if "SLURM_JOB_ID" in keys(ENV)
        ENV["SLURM_JOB_ID"]
    elseif "SLURM_JOBID" in keys(ENV)
        ENV["SLURM_JOBID"]
    else
        error("""
              SlurmManager must be constructed inside a slurm allocation environemnt.
              SLURM_JOB_ID or SLURM_JOBID must be defined.
              """)
    end

    ntasks =
    if "SLURM_NTASKS" in keys(ENV)
      ENV["SLURM_NTASKS"]
    else
      error("""
            SlurmManager must be constructed inside a slurm environment with a specified number of tasks.
            SLURM_NTASKS must be defined.
            """)
    end

    jobid = parse(Int, jobid)
    ntasks = parse(Int, ntasks)

    new(jobid, ntasks, verbose, launch_timeout, srun_post_exit_sleep, nothing)
  end
end

function launch(manager::SlurmManager, params::Dict, instances_arr::Array, c::Condition)
    try
        exehome = params[:dir]
        exename = params[:exename]
        exeflags = params[:exeflags]

        # Pass cookie as stdin to srun; srun forwards stdin to process
        # This way the cookie won't be visible in ps, top, etc on the compute node
        srun_cmd = `srun -D $exehome $exename $exeflags --worker`
        manager.srun_proc = open(srun_cmd, write=true, read=true)
        write(manager.srun_proc, cluster_cookie())
        write(manager.srun_proc, "\n")

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
          # need to sleep briefly here to make sure that srun exit is recorded by slurm daemons
          # TODO find a way to wait on the condition directly instead of just sleeping
          sleep(manager.srun_post_exit_sleep)
        end

    catch ex
        @error "Error launching Slurm job" exception=ex
        rethrow(ex)
    end
end

function manage(manager::SlurmManager, id::Integer, config::WorkerConfig, op::Symbol)
    # This function needs to exist, but so far we don't do anything
end
