#!/usr/bin/env julia

using Distributed, SlurmClusterManager
addprocs(SlurmManager())
@everywhere println("hello from $(myid()):$(gethostname())")
