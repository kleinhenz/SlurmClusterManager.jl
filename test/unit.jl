@testset "get_slurm_ntasks_int()" begin
  x = withenv("SLURM_NTASKS" => "12") do
    SlurmClusterManager.get_slurm_ntasks_int()
  end
  @test x == 12

  withenv("SLURM_NTASKS" => nothing) do
    @test_throws ErrorException SlurmClusterManager.get_slurm_ntasks_int()
  end
end

@testset "get_slurm_jobid_int()" begin
  x = withenv("SLURM_JOB_ID" => "34", "SLURM_JOBID" => nothing) do
    SlurmClusterManager.get_slurm_jobid_int()
  end
  @test x == 34

  x = withenv("SLURM_JOB_ID" => nothing, "SLURM_JOBID" => "56") do
    SlurmClusterManager.get_slurm_jobid_int()
  end
  @test x == 56
  
  withenv("SLURM_JOB_ID" => nothing, "SLURM_JOBID" => nothing) do
    @test_throws ErrorException SlurmClusterManager.get_slurm_jobid_int()
  end
end

@testset "warn_if_unexpected_params()" begin
  if Base.VERSION >= v"1.6"
    # This test is not relevant for Julia 1.6+
  else
    params = Dict(:env => ["foo" => "bar"])
    SlurmClusterManager.warn_if_unexpected_params(params)
    @test_logs(
      (:warn, "The user provided the `env` kwarg, but SlurmClusterManager.jl's support for the `env` kwarg requires Julia 1.6 or later"),
      SlurmClusterManager.warn_if_unexpected_params(params),
    )
  end
end
