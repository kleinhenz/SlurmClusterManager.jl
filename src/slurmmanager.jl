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

@static if Base.VERSION >= v"1.9.0"
  # In Julia 1.9 and later, the no-argument method `Distributed.default_addprocs_params()`
  # includes :env, so we don't need to do anything.
  # See also: https://github.com/JuliaLang/julia/blob/v1.9.0/stdlib/Distributed/src/cluster.jl#L526-L541

  Distributed.default_addprocs_params(::SlurmManager) = Distributed.default_addprocs_params()
elseif v"1.6.0" <= Base.VERSION < v"1.9.0"
  # In Julia 1.6 through 1.8, the no-argument method `Distributed.default_addprocs_params()`
  # does not include :env. However, Julia does allow us to add a specialized method
  # `Distributed.default_addprocs_params(::SlurmManager)`, so we do so here.
  #
  # The ability to add the specialized `Distributed.default_addprocs_params(::SlurmManager)`
  # method was added to Julia in https://github.com/JuliaLang/julia/pull/38570
  #
  # See also: https://github.com/JuliaLang/julia/blob/v1.8.0/stdlib/Distributed/src/cluster.jl#L526-L540
  function Distributed.default_addprocs_params(::SlurmManager)
    our_stuff = Dict{Symbol,Any}(
      :env => [],
    )
    upstreams_stuff = Distributed.default_addprocs_params()
    total_stuff = merge(our_stuff, upstreams_stuff)
    return total_stuff
  end
elseif Base.VERSION < v"1.6.0"
  # In Julia 1.5 and earlier, Julia does not have the `addenv()` function.
  # I don't want to add a dependency on Compat.jl just for this one feature,
  # so we will just choose to not support `params[:env]` on Julia 1.5 and earlier.
end

function _new_environment_additions(params_env::Dict{String, String})
  env2 = Dict{String, String}()
  for (name, value) in pairs(params_env)
    # For each key-value mapping in `params[:env]`, we respect that mapping and we pass it
    # to the workers.
    env2[name] = value
  end
  return env2
end

function Distributed.launch(manager::SlurmManager, params::Dict, instances_arr::Array, c::Condition)
    try
        exehome = params[:dir]
        exename = params[:exename]
        exeflags = params[:exeflags]

        _srun_cmd_without_env = `srun -D $exehome $exename $exeflags --worker`

        @static if Base.VERSION >= v"1.6.0"
          env_arr = params[:env]
          # Pass the key-value pairs from `params[:env]` to the `srun` command:
          env2 = Dict{String,String}()
          for (name, value) in pairs(Dict{String,String}(env_arr))
            env2[name] = value
          end
          srun_cmd_with_env = addenv(_srun_cmd_without_env, env2)
        else
          # See discussion above for why we don't support this functionality on Julia 1.5 and earlier.
          if haskey(params, :env)
            @warn "SlurmClusterManager.jl does not support params[:env] on Julia 1.5 and earlier" Base.VERSION
          end
          srun_cmd_with_env = _srun_cmd_without_env
        end

        # Pass cookie as stdin to srun; srun forwards stdin to process
        # This way the cookie won't be visible in ps, top, etc on the compute node
        manager.srun_proc = open(srun_cmd_with_env, write=true, read=true)
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

          @debug "Worker $i ready on host $(config.host), port $(config.port)"

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

function Distributed.manage(manager::SlurmManager, id::Integer, config::WorkerConfig, op::Symbol)
    # This function needs to exist, but so far we don't do anything
end
