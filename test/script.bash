#!/usr/bin/env bash

set -euf -o pipefail

set -x

pwd

julia --code-coverage=user script.jl
