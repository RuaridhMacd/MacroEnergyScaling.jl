using Test
using HiGHS
using JuMP
using MacroEnergyScaling

const MES = MacroEnergyScaling

function coefficient_values(con_ref)
    terms = JuMP.constraint_object(con_ref).func.terms
    return collect(values(terms))
end

include("direct_model_contract.jl")

@testset "MacroEnergyScaling" begin
    @testset "scaling settings validation" begin
        @test_throws ArgumentError MES.ScalingSettings(coeff_lb = 0.0)
        @test_throws ArgumentError MES.ScalingSettings(coeff_lb = 2.0, coeff_ub = 1.0)
        @test_throws ArgumentError MES.ScalingSettings(rhs_lb = 0.0)
        @test_throws ArgumentError MES.ScalingSettings(min_coeff = 1.0e-2)
        @test_throws ArgumentError MES.ScalingSettings(proxy_var_ratio_ub = 1.0)
        @test MES.ScalingSettings().scale_wideintervals

        settings = MES.ScalingSettings()
        settings.coeff_lb = 0.0
        @test_throws ArgumentError MES.scale_constraints!(Model(), settings)
    end

    @testset "in-place scaling" begin
        model = Model(HiGHS.Optimizer)
        @variable(model, x)
        con = @constraint(model, 1.0e8 * x <= 1.0e7)

        settings = MES.ScalingSettings()
        @test MES.scale_constraints!(model, settings) === nothing
        @test JuMP.is_valid(model, con)
        @test coefficient_values(con) == [1.0e6]
        @test JuMP.normalized_rhs(con) == 1.0e5
    end

    @testset "batched in-place scaling" begin
        model = Model(HiGHS.Optimizer)
        @variable(model, x[1:2])
        con = @constraint(model, 1.0e8 * x[1] + 1.0e8 * x[2] <= 1.0e7)

        @test MES.scale_constraints!(model) === nothing
        @test JuMP.is_valid(model, con)
        @test coefficient_values(con) == [1.0e6, 1.0e6]
        @test JuMP.normalized_rhs(con) == 1.0e5
    end

    test_direct_model_scaling(HiGHS.Optimizer)

    @testset "interval constraints" begin
        model = Model(HiGHS.Optimizer)
        @variable(model, x)
        con = @constraint(model, 1.0e-8 <= 1.0e-8 * x <= 1.0e-6)

        @test MES.scale_constraints!(model) === nothing
        @test JuMP.is_valid(model, con)
        @test coefficient_values(con) == [1.0e-3]
        interval = JuMP.constraint_object(con).set
        @test interval.lower ≈ 1.0e-3
        @test interval.upper ≈ 1.0e-1

        proxy_model = Model(HiGHS.Optimizer)
        @variable(proxy_model, x)
        @variable(proxy_model, y)
        proxy_con = @constraint(proxy_model, 1.0 <= 1.0e9 * x + 1.0e-9 * y <= 2.0)
        @test MES.scale_constraints!(proxy_model) === nothing
        @test JuMP.is_valid(proxy_model, proxy_con)
        @test JuMP.normalized_coefficient(proxy_con, x) == 0.0
        @test JuMP.normalized_coefficient(proxy_con, y) == 0.0

        wide_model = Model(HiGHS.Optimizer)
        @variable(wide_model, z)
        wide_con = @constraint(wide_model, 1.0e-9 <= 1.0 * z <= 1.0e9)
        expected_message = "Wide interval constraints where the LB and UB must be scaled differently constraints are not currently supported by MacroEnergyScaling. Set scale_wideintervals = false to skip these constraints or break them into two one-sided constraints."
        error = try
            MES.scale_constraints!(wide_model)
            nothing
        catch caught_error
            caught_error
        end
        @test error isa ErrorException
        @test startswith(sprint(showerror, error), expected_message)
        @test occursin(string(wide_con), sprint(showerror, error))
        @test JuMP.is_valid(wide_model, wide_con)
        @test JuMP.constraint_object(wide_con).set.lower == 1.0e-9
        @test MES.scale_constraints!(wide_model, MES.ScalingSettings(scale_wideintervals = false)) === nothing
        @test JuMP.constraint_object(wide_con).set.upper == 1.0e9
    end

    @testset "scaling inspection does not mutate a constraint expression" begin
        model = Model(HiGHS.Optimizer)
        @variable(model, x)
        con = @constraint(model, 2.0 * x <= 4.0)
        terms = JuMP.constraint_object(con).func.terms
        original_storage_length = length(terms.vals)

        MES.scale_constraints!(model)
        @test length(terms.vals) == original_storage_length
        @test length(terms.vals) == length(terms)
    end

    @testset "RHS boundary values are valid during rebuild" begin
        model = Model(HiGHS.Optimizer)
        @variable(model, x)
        # The coefficient forces the proxy/rebuild path while the RHS is exactly rhs_lb.
        @constraint(model, 1.0e9 * x <= 1.0e-3)

        @test_nowarn MES.scale_constraints!(model)
    end

    @testset "non-scalar-affine constraints" begin
        expected_message = "Non-scalar-affine constraints are not currently supported by MacroEnergyScaling. Set scale_nonaffine = false to skip these constraints"

        model = Model()
        @variable(model, x)
        @variable(model, y)
        affine_con = @constraint(model, 1.0e8 * x <= 1.0e7)
        quadratic_con = @constraint(model, y^2 <= 1.0)

        error = try
            MES.scale_constraints!(model)
            nothing
        catch caught_error
            caught_error
        end
        @test error isa ErrorException
        @test sprint(showerror, error) == expected_message
        @test JuMP.normalized_coefficient(affine_con, x) == 1.0e8
        @test_throws ArgumentError MES.scale_constraints!(ConstraintRef[affine_con, quadratic_con])
        @test JuMP.normalized_coefficient(affine_con, x) == 1.0e8

        settings = MES.ScalingSettings(scale_nonaffine = false)
        @test MES.scale_constraints!(model, settings) === nothing
        @test JuMP.normalized_coefficient(affine_con, x) == 1.0e6
        @test JuMP.is_valid(model, quadratic_con)
        @test_throws ErrorException MES.scale_constraints!([quadratic_con])
        @test MES.scale_constraints!([quadratic_con], settings) === nothing

        nonlinear_model = Model()
        @variable(nonlinear_model, z)
        @constraint(nonlinear_model, sin(z) <= 1.0)
        @test_throws ErrorException MES.scale_constraints!(nonlinear_model)
        @test_nowarn MES.scale_constraints!(nonlinear_model, MES.ScalingSettings(scale_nonaffine = false))
    end

    @testset "proxy scaling preserves an optimum" begin
        function mixed_scale_model()
            model = Model(HiGHS.Optimizer)
            @variable(model, x >= 0)
            @variable(model, y == 0)
            @constraint(model, 1.0e9 * x + 1.0e-9 * y >= 1.0)
            @objective(model, Min, x)
            return model, x
        end

        original, original_x = mixed_scale_model()
        optimize!(original)
        original_objective = objective_value(original)
        original_x_value = value(original_x)

        scaled, scaled_x = mixed_scale_model()
        MES.scale_constraints!(scaled)
        optimize!(scaled)

        @test isapprox(objective_value(scaled), original_objective; atol = 1e-12)
        @test isapprox(value(scaled_x), original_x_value; atol = 1e-12)
    end

    @testset "rebuilding preserves the original ConstraintRef" begin
        model = Model(HiGHS.Optimizer)
        @variable(model, x)
        @variable(model, y)
        # Coefficients on both sides of the allowed range require proxy variables.
        con = @constraint(model, 1.0e9 * x + 1.0e-9 * y <= 1.0)

        MES.scale_constraints!(model)

        @test JuMP.is_valid(model, con)
        @test JuMP.name(con) == ""
        @test JuMP.normalized_coefficient(con, x) == 0.0
        @test JuMP.normalized_coefficient(con, y) == 0.0
        @test JuMP.normalized_rhs(con) == 1.0
    end
end
