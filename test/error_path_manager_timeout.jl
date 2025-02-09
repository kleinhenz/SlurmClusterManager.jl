mktempdir() do tmpdir
  fake_bindir = joinpath(tmpdir, "bin")
  fake_srun = joinpath(tmpdir, "bin", "srun")
  mkpath(fake_bindir)
  open(fake_srun, "w") do io
    println(io, "#!/usr/bin/env bash")
    println(io, "set -euf -o pipefail")
    # println(io, "set -x")

    # we only print this to stderr; don't print to stdout, or we won't hit the desired error path
    # (we'll hit a different error path instead, not the one we want to test)
    println(io, "echo [stderr] fake-srun: sleeping for 15 seconds... >&2")

    # Bash sleep for 15-seconds:
    println(io, "sleep 15")

    println(io, "echo [stdout] fake-srun: INTENTIONALLY ERROR-ING")
    println(io, "echo [stderr] fake-srun: INTENTIONALLY ERROR-ING >&2")
    println(io, "exit 1")
  end
  chmod(fake_srun, 0o700) # chmod +x
  directory_separator = Sys.iswindows() ? ';' : ':'
  new_env = Dict{String, String}()
  new_env["SLURM_NTASKS"] = "8"
  new_env["SLURM_JOB_ID"] = "1234"
  if haskey(ENV, "PATH")
    old_path = ENV["PATH"]
    new_env["PATH"] = fake_bindir * directory_separator * old_path
  else
    new_env["PATH"] = fake_bindir
  end

  @info "with old PATH" Sys.which("srun")
  withenv(new_env...) do
    @info "with new PATH" Sys.which("srun")

    if Base.VERSION >= v"1.2-"
      expected_outer_ex_T = TaskFailedException
      expected_inner_ex_INSTANCE = ErrorException("launch_timeout exceeded")
    else
      expected_outer_ex_T = ErrorException
      expected_inner_ex_INSTANCE = ErrorException("launch_timeout exceeded")
    end

    mgr = SlurmClusterManager.SlurmManager(; launch_timeout = 2.0)
    test_result = @test_throws expected_outer_ex_T Distributed.addprocs(mgr)

    cfg = ConfigForTestingTaskFailedException(;
      expected_outer_ex_T=expected_outer_ex_T,
      expected_inner_ex_INSTANCE=expected_inner_ex_INSTANCE,
    )
    test_task_failed_exception(test_result, cfg)
  end
end
