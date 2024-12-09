function is_interactive(job_id)
    output = read(`scontrol show job $job_id`, String)
    return occursin("BatchFlag=0", output) ? true : false
end


function get_slurm_version(; fail_on_error::Bool = true, verbose::Bool = false)
    # Run the srun --version command and capture the output
    try
        output = read(`srun --version`, String)
        
        # Extract the version number using a regular expression
        version_match = match(r"\b(\d+)\.(\d+)\.(\d+)\b", output)
        if version_match === nothing
            error("Could not extract SLURM version from: $output")
        end
        
        # Parse the version numbers
        major, minor, patch = parse.(Int, version_match.captures)

        return (major, minor, patch)

    catch e
        if fail_on_error
            error("Failed to determine SLURM version: $e")
        else
            if verbose
                @error("Failed to determine SLURM version: $e")
            end
            return nothing
        end
    end
end


