#!/usr/bin/env julia

using Distributed, SlurmClusterManager
addprocs(SlurmManager(verbose=true))

@assert nworkers() == parse(Int, ENV["SLURM_NTASKS"])

hosts = map(workers()) do id
  remotecall_fetch(() -> gethostname(), id)
end
sort!(hosts)

@everywhere println("Host $(myid()): $(gethostname())") # I created a separate test for assuring that the env is set properly but without withenv it's hard to test -- you need another locaiton that has Distributed installed

pathsep = Sys.iswindows() ? ";" : ":"
active_project = Base.ACTIVE_PROJECT[] # project is set in runtests_inheritance so it will have a value [returns path unlike `Base.active_project()`]

# Check the env variables on this worker (they may have been set by user configs)
julia_depot_path_orig = ("JULIA_DEPOT_PATH" in keys(ENV)) ? ENV["JULIA_DEPOT_PATH"] : nothing
julia_load_path_orig = ("JULIA_LOAD_PATH" in keys(ENV)) ? ENV["JULIA_LOAD_PATH"] : nothing
julia_project_orig = ("JULIA_PROJECT" in keys(ENV)) ? ENV["JULIA_PROJECT"] : nothing

# Recreate the values that are set in /src/slurmmanager.jl launch() function for a defined project but nothing in env argument to addprocs
julia_depot_path_new = join(DEPOT_PATH, pathsep)
julia_load_path_new = join(LOAD_PATH, pathsep)
julia_project_new = active_project

@info "Active Project: $active_project"


# Test we get what we expect. The original worker may have env variables unset, while the new workers have them set.
# We can't guarantee which is the original worker, so we check for both cases
@everywhere begin
  _julia_depot_path = ("JULIA_DEPOT_PATH" in keys(ENV)) ? ENV["JULIA_DEPOT_PATH"] : nothing
  _julia_load_path = ("JULIA_LOAD_PATH" in keys(ENV)) ? ENV["JULIA_LOAD_PATH"] : nothing
  _julia_project = ("JULIA_PROJECT" in keys(ENV)) ? ENV["JULIA_PROJECT"] : nothing
  _active_project = Base.ACTIVE_PROJECT[]

  if !(_julia_depot_path == $julia_depot_path_orig) && !(_julia_depot_path == $julia_depot_path_new) # check for both cases
    julia_depot_path_orig_interp = $julia_depot_path_orig # hack to get the variable because i can't figure out how to do the interpolation inside a string inside an @everywhere block
    julia_depot_path_new_interp = $julia_depot_path_new # hack to get the variable because i can't figure out how to do the interpolation inside a string inside an @everywhere block
    error("Expected ENV[\"JULIA_DEPOT_PATH\"] to match $julia_depot_path_orig_interp or $julia_depot_path_new_interp, but got $_julia_depot_path")
  end

  if !(_julia_load_path == $julia_load_path_orig) && !(_julia_load_path == $julia_load_path_new) # check for both cases
    julia_load_path_orig_interp = $julia_load_path_orig # hack to get the variable because i can't figure out how to do the interpolation inside a string inside an @everywhere block
    julia_load_path_new_interp = $julia_load_path_new # hack to get the variable because i can't figure out how to do the interpolation inside a string inside an @everywhere block
    error("Expected ENV[\"JULIA_LOAD_PATH\"] to match $julia_load_path_orig_interp or $julia_load_path_new_interp, but got $_julia_load_path")
  end

  # Check the env variable for JULIA_PROJECT is set
  if !(_julia_project == $julia_project_orig) && !(_julia_project == $julia_project_new) # check for both cases
    julia_project_orig_interp = $julia_project_orig # hack to get the variable because i can't figure out how to do the interpolation inside a string inside an @everywhere block
    julia_project_new_interp = $julia_project_new # hack to get the variable because i can't figure out how to do the interpolation inside a string inside an @everywhere block
    error("Expected ENV[\"JULIA_PROJECT\"] to match $julia_project_orig_interp or $julia_project_new_interp, but got $_julia_project")
  end

  # Check the active project is correctly set to what the env variable was set to
  if !(_active_project == $active_project) # This should be the same on all workers
    active_project_interp = $active_project # hack to get the variable because i can't figure out how to do the interpolation inside a string inside an @everywhere block
    active_toml = Base.active_project()
    error("Expected Base.ACTIVE_PROJECT[] to match $active_project_interp, but got $_active_project. [ Active toml from Base.active_project() = $active_toml ]")
  end

  @info "Host $(myid()): $(gethostname())\nJULIA_DEPOT_PATH: $_julia_depot_path\nJULIA_LOAD_PATH: $_julia_load_path\nJULIA_PROJECT: $_julia_project\nactive_project: $_active_project\n"
end
