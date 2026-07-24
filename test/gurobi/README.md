# Gurobi direct-model tests

This is an opt-in test environment for MacroEnergyScaling's direct-model
contract. It requires Gurobi.jl and a working Gurobi license; it is not part of
the normal `Pkg.test()` suite or public CI.

From the repository root, initialize the environment:

```sh
julia --project=test/gurobi -e 'using Pkg; Pkg.instantiate()'
```

Then run the tests:

```sh
julia --project=test/gurobi test/gurobi/runtests.jl
```

The test suite uses `direct_model(Gurobi.Optimizer())` and shares the same
solver-agnostic contract as the HiGHS direct-model tests. Other licensed solver
tests can follow this layout in sibling directories under `test/`.
