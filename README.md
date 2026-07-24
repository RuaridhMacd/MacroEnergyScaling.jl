# MacroEnergyScaling.jl

A package to rescale and improve the numerical stability of JuMP-based optimization models

## Instructions

This package rescales scalar-affine JuMP constraints. To use it, simply add the package to your project and call the `scale_constraints!(EP)` function with your model `EP`. The package will automatically rescale supported constraints and improve their numerical stability. The objective function is not rescaled. It supports JuMP caching models and direct models when the optimizer supports the required incremental constraint modifications.

The user can adjust the manner in which the model is rescaled by creating a `ScalingSettings` object and passing it to the `scale_constraints!(EP, settings)` function. The `ScalingSettings` object can be created by providing the preferred settings in a dictionary.

Some constraints will be rescaled using proxy variables, where a new variable will be created which is a multiple of the original variable. This adds additional constraints to the model. Existing constraints are updated in place, so their `ConstraintRef`s remain valid.

Note, this package does not reformulate the model, it only rescales it. Better performance and numerical stability can be achieved by reformulating the model. This can achieve the same re-scaled coefficients and right-hand sides but without the need for proxy variables and additional constraints.

Currently, MacroEnergyScaling supports scalar-affine `<=`, `>=`, `==`, and non-wide two-sided interval constraints. By default, it errors for a wide interval whose lower and upper bounds require different scaling multipliers. Set `scale_wideintervals = false` in `ScalingSettings` to skip wide intervals, or break them into two one-sided constraints. It also errors by default if the model contains other constraint types; set `scale_nonaffine = false` to skip them. Constraints are processed in JuMP's constraint-type order; when proxy variables are used, this can affect which proxies are reused and therefore the auxiliary formulation, without changing the feasible region.
