# Benchmarks

This directory contains microbenchmarks for the constraint-scaling paths. Model
construction happens in BenchmarkTools' `setup` phase, so timings measure only
`scale_constraints!`.

From the repository root, initialize the dedicated benchmark environment once:

```sh
/Users/rmacd/.juliaup/bin/julia --project=benchmark -e 'using Pkg; Pkg.instantiate()'
```

Then run the benchmark suite:

```sh
/Users/rmacd/.juliaup/bin/julia --project=benchmark benchmark/benchmarks.jl
```

Set `MES_BENCHMARK_CONSTRAINTS` to change the number of constraints per case.
BenchmarkTools reports elapsed time as well as allocations and allocated bytes.
