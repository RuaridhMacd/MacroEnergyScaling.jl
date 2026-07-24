using Test
using Gurobi
using JuMP
using MacroEnergyScaling

include(joinpath(@__DIR__, "..", "direct_model_contract.jl"))

test_direct_model_scaling(Gurobi.Optimizer)
