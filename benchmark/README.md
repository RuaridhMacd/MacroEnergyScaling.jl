# Benchmarks

This directory contains microbenchmarks for the constraint-scaling paths. Model
construction happens in BenchmarkTools' `setup` phase, so timings measure only
`scale_constraints!`. The suite includes caching-model and HiGHS direct-model
cases, plus dense in-place and proxy-scaling cases.

From the repository root, initialize the dedicated benchmark environment once:

```sh
julia --project=benchmark -e 'using Pkg; Pkg.instantiate()'
```

Then run the benchmark suite:

```sh
julia --project=benchmark benchmark/benchmarks.jl
```

Set `MES_BENCHMARK_CONSTRAINTS` to change the number of constraints per case.
Set `MES_BENCHMARK_DENSE_TERMS` to change the number of terms in each dense
constraint (default: 50). BenchmarkTools reports elapsed time as well as
allocations and allocated bytes.
