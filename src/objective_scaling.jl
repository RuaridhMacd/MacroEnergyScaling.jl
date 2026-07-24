@doc raw"""
    scale_objective!(model::Model, scaling_settings::ScalingSettings=ScalingSettings())

Scale a scalar-affine objective using proxy variables while preserving the
objective value. Coefficients with absolute value below
`objective_min_coeff` are dropped before scaling.

For a fully scaled model, call `scale_objective!` before `scale_constraints!`
with the same `ScalingSettings` object.
"""
function scale_objective!(model::Model, scaling_settings::ScalingSettings=ScalingSettings())
    validate_scaling_settings(scaling_settings)
    if objective_sense(model) == MOI.FEASIBILITY_SENSE
        return nothing
    end
    objective = scalar_affine_objective(model)
    scaled_objective = AffExpr(objective.constant)
    objective_changed = false
    for (var, coeff) in objective.terms
        if abs(coeff) < scaling_settings.objective_min_coeff
            objective_changed = true
        elseif scaling_settings.objective_coeff_lb <= abs(coeff) <= scaling_settings.objective_coeff_ub
            add_to_expression!(scaled_objective, coeff, var)
        else
            scaled_var, scaled_coeff = update_objective_var_coeff_pair(var, coeff, scaling_settings)
            add_to_expression!(scaled_objective, scaled_coeff, scaled_var)
            objective_changed = true
        end
    end
    if objective_changed
        set_objective_function(model, scaled_objective)
    end
    return nothing
end

function scalar_affine_objective(model::Model)
    try
        return objective_function(model, AffExpr)
    catch caught_error
        if caught_error isa InexactError || caught_error isa ArgumentError
            error("Non-scalar-affine objectives are not currently supported by MacroEnergyScaling.")
        end
        rethrow()
    end
end

function update_objective_var_coeff_pair(var::VariableRef, coeff::Real, scaling_settings::ScalingSettings)
    multiplier = calc_coeff_multiplier(
        coeff,
        scaling_settings.objective_coeff_lb,
        scaling_settings.objective_coeff_ub,
    )
    proxy_var, multiplier = get_proxy_var(
        var,
        multiplier,
        scaling_settings.proxy_var_map,
        scaling_settings.proxy_var_ratio_ub,
    )
    new_coeff = coeff * multiplier
    new_coeff, multiplier = prune_coefficients(new_coeff, coeff, multiplier)
    if scaling_settings.objective_coeff_lb <= abs(new_coeff) <= scaling_settings.objective_coeff_ub
        return proxy_var, new_coeff
    elseif scaling_settings.allow_recursion
        return update_objective_var_coeff_pair(proxy_var, new_coeff, scaling_settings)
    end
    return proxy_var, new_coeff
end
