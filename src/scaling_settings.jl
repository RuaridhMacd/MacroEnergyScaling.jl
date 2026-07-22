@doc raw"""
    ScalingSettings

A structure to store the scaling settings for the scaling algorithm. The fields are:
    
- coeff_lb::Float64 = 1e-3: Lower bound for the scaling coefficients.
- coeff_ub::Float64 = 1e6: Upper bound for the scaling coefficients.
- min_coeff::Float64 = 1e-9: Minimum value for the scaling coefficients.
- rhs_lb::Float64 = 1e-3: Lower bound for the right-hand side scaling.
- rhs_ub::Float64 = 1e6: Upper bound for the right-hand side scaling.
- allow_recursion::Bool = true: Whether to allow recursion in the scaling algorithm.
- scale_nonaffine::Bool = true: Whether to error when non-scalar-affine constraints are encountered.
- proxy_var_ratio_ub::Float64 = 10.0: Upper bound for the ratio of proxy variables to variables.
- proxy_var_map::Dict{VariableRef, Vector{Tuple{VariableRef, Float64}}} = Dict{VariableRef, Vector{Tuple{VariableRef, Float64}}}(): A dictionary mapping variables to a vector of tuples of variables and scaling coefficients.
"""
@Base.kwdef mutable struct ScalingSettings
    coeff_lb::Float64 = 1e-3
    coeff_ub::Float64 = 1e6
    min_coeff::Float64 = 1e-9
    rhs_lb::Float64 = 1e-3
    rhs_ub::Float64 = 1e6
    allow_recursion::Bool = true
    scale_nonaffine::Bool = true
    proxy_var_ratio_ub::Float64 = 10.0  
    proxy_var_map::Dict{VariableRef, Vector{Tuple{VariableRef, Float64}}} = Dict{VariableRef, Vector{Tuple{VariableRef, Float64}}}()

    function ScalingSettings(coeff_lb, coeff_ub, min_coeff, rhs_lb, rhs_ub, allow_recursion, scale_nonaffine, proxy_var_ratio_ub, proxy_var_map)
        coeff_lb = convert(Float64, coeff_lb)
        coeff_ub = convert(Float64, coeff_ub)
        min_coeff = convert(Float64, min_coeff)
        rhs_lb = convert(Float64, rhs_lb)
        rhs_ub = convert(Float64, rhs_ub)
        allow_recursion = convert(Bool, allow_recursion)
        scale_nonaffine = convert(Bool, scale_nonaffine)
        proxy_var_ratio_ub = convert(Float64, proxy_var_ratio_ub)
        proxy_var_map = convert(Dict{VariableRef, Vector{Tuple{VariableRef, Float64}}}, proxy_var_map)
        validate_scaling_values(coeff_lb, coeff_ub, min_coeff, rhs_lb, rhs_ub, proxy_var_ratio_ub)
        return new(coeff_lb, coeff_ub, min_coeff, rhs_lb, rhs_ub, allow_recursion, scale_nonaffine, proxy_var_ratio_ub, proxy_var_map)
    end
end

function validate_scaling_values(coeff_lb::Float64, coeff_ub::Float64, min_coeff::Float64, rhs_lb::Float64, rhs_ub::Float64, proxy_var_ratio_ub::Float64)
    if !all(isfinite, (coeff_lb, coeff_ub, min_coeff, rhs_lb, rhs_ub, proxy_var_ratio_ub))
        throw(ArgumentError("Scaling settings must be finite."))
    elseif coeff_lb <= 0.0 || coeff_lb > coeff_ub
        throw(ArgumentError("coeff_lb must be positive and no greater than coeff_ub."))
    elseif rhs_lb <= 0.0 || rhs_lb > rhs_ub
        throw(ArgumentError("rhs_lb must be positive and no greater than rhs_ub."))
    elseif min_coeff < 0.0 || min_coeff > coeff_lb
        throw(ArgumentError("min_coeff must be nonnegative and no greater than coeff_lb."))
    elseif proxy_var_ratio_ub <= 1.0
        throw(ArgumentError("proxy_var_ratio_ub must be greater than 1."))
    end
    return nothing
end

function validate_scaling_settings(scaling_settings::ScalingSettings)
    validate_scaling_values(
        scaling_settings.coeff_lb,
        scaling_settings.coeff_ub,
        scaling_settings.min_coeff,
        scaling_settings.rhs_lb,
        scaling_settings.rhs_ub,
        scaling_settings.proxy_var_ratio_ub,
    )
    return nothing
end

@doc raw"""
    get_scaling_settings(settings::Dict)::ScalingSettings

Extracts the scaling settings from a dictionary and returns a `ScalingSettings` object.
"""
function get_scaling_settings(settings::Dict)::ScalingSettings
    scaling_settings = Dict{Symbol, Any}()
    for scaling_setting in [String(x) for x in fieldnames(ScalingSettings)]
        if haskey(settings, scaling_setting)
            scaling_settings[Symbol(scaling_setting)] = settings[scaling_setting]
        end
    end
    return ScalingSettings(; scaling_settings...)
end
