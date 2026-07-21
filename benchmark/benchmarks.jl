using BenchmarkTools
using JuMP
using MacroEnergyScaling

const MES = MacroEnergyScaling

function build_in_range_model(n::Integer)
    model = Model()
    @variable(model, x[1:n])
    for i in 1:n
        @constraint(model, 2.0 * x[i] <= 4.0)
    end
    return model
end

function build_in_place_scaling_model(n::Integer)
    model = Model()
    @variable(model, x[1:n])
    for i in 1:n
        @constraint(model, 1.0e8 * x[i] <= 1.0e7)
    end
    return model
end

function build_proxy_scaling_model(n::Integer)
    model = Model()
    @variable(model, x[1:n])
    @variable(model, y[1:n])
    for i in 1:n
        @constraint(model, 1.0e9 * x[i] + 1.0e-9 * y[i] <= 1.0)
    end
    return model
end

function scaling_benchmarks(n::Integer=100)
    suite = BenchmarkGroup()
    suite["already in range"] = @benchmarkable MES.scale_constraints!(model, settings) setup=(model = build_in_range_model($n); settings = MES.ScalingSettings()) evals=1
    suite["in-place scaling"] = @benchmarkable MES.scale_constraints!(model, settings) setup=(model = build_in_place_scaling_model($n); settings = MES.ScalingSettings()) evals=1
    suite["proxy scaling"] = @benchmarkable MES.scale_constraints!(model, settings) setup=(model = build_proxy_scaling_model($n); settings = MES.ScalingSettings()) evals=1
    return suite
end

if abspath(PROGRAM_FILE) == @__FILE__
    n = parse(Int, get(ENV, "MES_BENCHMARK_CONSTRAINTS", "100"))
    results = run(scaling_benchmarks(n); verbose=true)
    for (name, trial) in results
        println("\n$(name)")
        show(stdout, MIME("text/plain"), trial)
        println()
    end
end
