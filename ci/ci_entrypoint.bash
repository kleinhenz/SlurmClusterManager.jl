#!/usr/bin/env bash

set -euf -o pipefail

set -x

pwd

ls -la .

ls -la ./SlurmClusterManager

julia --project=./SlurmClusterManager -e 'import Pkg; Pkg.instantiate()'

julia --project=./SlurmClusterManager -e 'import Pkg; Pkg.status()'

julia --project=./SlurmClusterManager -e 'import Pkg; Pkg.test(; coverage=true)'

find . -type f -name '*.cov'
