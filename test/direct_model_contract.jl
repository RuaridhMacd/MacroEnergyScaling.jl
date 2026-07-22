function test_direct_model_scaling(optimizer_factory)
    @testset "direct-model scaling" begin
        model = direct_model(optimizer_factory())
        @variable(model, x)
        con = @constraint(model, 1.0e8 * x <= 1.0e7)

        @test MacroEnergyScaling.scale_constraints!(model) === nothing
        @test JuMP.is_valid(model, con)
        @test collect(values(JuMP.constraint_object(con).func.terms)) == [1.0e6]
        @test JuMP.normalized_rhs(con) == 1.0e5

        function direct_mixed_scale_model()
            model = direct_model(optimizer_factory())
            @variable(model, x >= 0)
            @variable(model, y == 0)
            con = @constraint(model, 1.0e9 * x + 1.0e-9 * y >= 1.0)
            @objective(model, Min, 1.0 * x)
            return model, x, con
        end

        original, original_x, _ = direct_mixed_scale_model()
        optimize!(original)
        original_objective = objective_value(original)
        original_x_value = value(original_x)

        scaled, scaled_x, scaled_con = direct_mixed_scale_model()
        MacroEnergyScaling.scale_constraints!(scaled)
        @test JuMP.is_valid(scaled, scaled_con)
        optimize!(scaled)

        @test isapprox(objective_value(scaled), original_objective; atol = 1e-12)
        @test isapprox(value(scaled_x), original_x_value; atol = 1e-12)
    end
    return nothing
end
