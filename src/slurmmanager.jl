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

"""
  By default, workers inherit the environment variables from the master process [implmentation adapted directly from https://github.com/JuliaLang/julia/pull/43270/files]
"""
function launch(manager::SlurmManager, params::Dict, instances_arr::Array, c::Condition)
    try
        dir = params[:dir]
        exehome = params[:dir]
        exename = params[:exename]
        exeflags = params[:exeflags]

        # TODO: Maybe this belongs in base/initdefs.jl as a package_environment() function
        #       together with load_path() etc. Might be useful to have when spawning julia
        #       processes outside of Distributed.jl too.
        # JULIA_(LOAD|DEPOT)_PATH are used to populate (LOAD|DEPOT)_PATH on startup,
        # but since (LOAD|DEPOT)_PATH might have changed they are re-serialized here.
        # Users can opt-out of this by passing `env = ...` to addprocs(...).
        env = Dict{String,String}(params[:env])
        pathsep = Sys.iswindows() ? ";" : ":"
        if get(env, "JULIA_LOAD_PATH", nothing) === nothing
            env["JULIA_LOAD_PATH"] = join(LOAD_PATH, pathsep)
        end
        if get(env, "JULIA_DEPOT_PATH", nothing) === nothing
            env["JULIA_DEPOT_PATH"] = join(DEPOT_PATH, pathsep)
        end

        # is this necessary?
        if !params[:enable_threaded_blas] &&
          get(env, "OPENBLAS_NUM_THREADS", nothing) === nothing
           env["OPENBLAS_NUM_THREADS"] = "1"
        end

       # Set the active project on workers using JULIA_PROJECT.
       # Users can opt-out of this by (i) passing `env = ...` or (ii) passing
       # `--project=...` as `exeflags` to addprocs(...).
       project = Base.ACTIVE_PROJECT[]
       if project !== nothing && get(env, "JULIA_PROJECT", nothing) === nothing
           env["JULIA_PROJECT"] = project
       end

        # Pass cookie as stdin to srun; srun forwards stdin to process
        # This way the cookie won't be visible in ps, top, etc on the compute node
        srun_cmd = `srun -D $exehome $exename $exeflags --worker`
        manager.srun_proc = open(setenv(addenv(srun_cmd, env), dir=dir), write=true, read=true)
        write(manager.srun_proc, cluster_cookie())
        write(manager.srun_proc, "\n")

        t = @async for i in 1:manager.ntasks
          manager.verbose && @info "connecting to worker $i out of $(manager.ntasks)"

          line = readline(manager.srun_proc)
          m = match(r".*:(\d*)#(.*)", line)
          m === nothing && error("could not parse $line")

          config = WorkerConfig()
          config.port = parse(Int, m[1])
          config.host = strip(m[2])

          manager.verbose && @info "Worker $i ready on host $(config.host), port $(config.port)"

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

    catch e
        println("Error launching Slurm job:")
        rethrow(e)
    end
end

function manage(manager::SlurmManager, id::Integer, config::WorkerConfig, op::Symbol)
    # This function needs to exist, but so far we don't do anything
end
