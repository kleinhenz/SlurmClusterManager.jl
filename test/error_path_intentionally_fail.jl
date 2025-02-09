mktempdir() do tmpdir
  fake_bindir = joinpath(tmpdir, "bin")
  fake_srun = joinpath(tmpdir, "bin", "srun")
  mkpath(fake_bindir)
  open(fake_srun, "w") do io
    println(io, "#!/usr/bin/env bash")
    println(io, "set -euf -o pipefail")
    # println(io, "set -x")
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
      T_expected = TaskFailedException
    else
      T_expected = Base.IOError
    end
    
    mgr = SlurmClusterManager.SlurmManager()
    @test_throws T_expected Distributed.addprocs(mgr)
  end
end
