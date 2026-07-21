using Test
using HiGHS
using JuMP
using MacroEnergyScaling

const MES = MacroEnergyScaling

function coefficient_values(con_ref)
    terms = JuMP.constraint_object(con_ref).func.terms
    return collect(values(terms))
end

@testset "MacroEnergyScaling" begin
    @testset "in-place scaling" begin
        model = Model(HiGHS.Optimizer)
        @variable(model, x)
        con = @constraint(model, 1.0e8 * x <= 1.0e7)

        settings = MES.ScalingSettings(count_actions = true)
        @test MES.scale_constraints!(model, settings) == 1
        @test JuMP.is_valid(model, con)
        @test coefficient_values(con) == [1.0e6]
        @test JuMP.normalized_rhs(con) == 1.0e5
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
    end
end
