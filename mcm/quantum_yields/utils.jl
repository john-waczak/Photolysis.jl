function relevant_rxns(h5_path, species)
    h5 = h5open(h5_path, "r")

    quantum_yields = h5["quantum-yields"]
    rxns = keys(quantum_yields)

    res = []
    for rxn ∈ rxns 
        if occursin(species, rxn)
            push!(res, rxn)
        end
    end
    
    close(h5)
    
    return res
end



function get_raw_data(h5_path, rxn)
    h5 = h5open(h5_path, "r")
    
    quantum_yields = h5["quantum-yields"]
    
    rxn in keys(quantum_yields)
    data_full = quantum_yields[rxn]


    λs = read(data_full, "λ")
    Φs = read(data_full, "Φ")
    T1s = read(data_full, "T1")
    T2s = read(data_full, "T2")
    species = read(data_full, "species")
    source_idx = read(data_full, "source_idx")

    T_units = read_attribute(data_full, "T1_units")
    category= read_attribute(data_full, "category")
    reaction= read_attribute(data_full, "reaction")
    λ_units = read_attribute(data_full, "λ_units")
    Φ_units = read_attribute(data_full, "Φ_units")

    close(h5)

    return λs, Φs, T1s, T2s, species, source_idx, T_units, category, reaction, λ_units, Φ_units

end


function data_to_df(λs, Φs, T1s, T2s, source_idx, species, species_to_use; T_lb=290.0, T_ub=305.0, λ_lb=200.0, λ_ub=1100.0)
    Tout = [T1s[source_idx[i]] for i ∈ 1:size(source_idx, 1)]

    data_idxs = [idx for idx ∈ 1:size(species,1) if species[idx] == species_to_use]
    λs = λs[data_idxs]
    Φs = Φs[data_idxs]
    Tout = Tout[data_idxs]
    source_idx =  source_idx[data_idxs]
    
    # we want T2 to be NaN
    idx = [ i for i  ∈ 1:size(source_idx,1) if isnan(T2s[source_idx[i]])]
    λout = λs[idx]
    Φout = Φs[idx]
    Tout = Tout[idx]
    source_out = source_idx[idx]

    # we want T between T_lb and T_ub
    idx2 = [i for i ∈ 1:size(λout,1) if (T_lb ≤ Tout[i] && Tout[i] ≤ T_ub)]
    λout = λout[idx2]
    Φout = Φout[idx2]
    Tout = Tout[idx2]
    source_out = source_out[idx2]

    # we want λ to be between λ_lb and λ_ub
    idx4 = [i for i ∈ 1:size(λout,1) if (λ_lb ≤ λout[i] && λout[i] ≤ λ_ub)]
    λout = λout[idx4]
    Φout = Φout[idx4]
    Tout = Tout[idx4]
    source_out = source_out[idx4]

    # we want qy to be <= 1.0
    idx5 = [i for i ∈ 1:size(λout,1) if Φout[i] ≤ 1.0]
    λout = λout[idx5]
    Φout = Φout[idx5]
    Tout = Tout[idx5]
    source_out = source_out[idx5]
 
    
    df =  DataFrame(λ=λout, Φ=Φout, T=Tout, source_id=source_out)
    return df
end



function representative_rand_sample(column::AbstractVector, nbins::Int, npoints::Int)
    n_per_bin = floor(Int, npoints/nbins)
    hist = fit(Histogram, column, nbins=nbins)
    bin_edges = hist.edges[1]
    
    idx_out = []
    
    # loop over each bin
    for i ∈ 1:size(bin_edges, 1)-1
        bin_idxs = findall(ξ -> bin_edges[i] < ξ && ξ < bin_edges[i+1], column)
        n_to_sample = minimum([n_per_bin, size(bin_idxs, 1)])
        idx_res = sample(bin_idxs, n_to_sample, replace=false)
        push!(idx_out, idx_res)  # sample without replacement
    end

    return unique(vcat(idx_out...))
end





function predict_Φ(T, λs, mach, λ_bounds)
    λ_lb, λ_ub = λ_bounds
    
    Xout = copy(λs)
    Tout = T
    Xout[!, :T] = [Tout for _ ∈ 1:nrow(λs)]
    res = predict_mean(mach, Xout)
    
    idxs = [idx for idx ∈ 1:nrow(Xout) if (Xout.λ[idx] ≤ λ_lb) || (λ_ub ≤ Xout.λ[idx])]
    res[idxs] .= 0.0
    
    # update for any prediction above 1.0 or below 0.0
    idx_one = [idx for idx ∈ 1:size(res,1) if res[idx] > 1.0]
    res[idx_one] .= 1.0

    idx_zero = [idx for idx ∈ 1:size(res,1) if res[idx] < 0.0]
    res[idx_zero] .= 0.0
 
    return res
end


function predict_Φ_wΔ(T, λs, mach, λ_bounds)
    λ_lb, λ_ub = λ_bounds
    
    Xout = copy(λs)
    Tout = T
    Xout[!, :T] = [Tout for _ ∈ 1:nrow(λs)]
    res = MLJ.predict(mach, Xout)

    Φ = mean.(res)
    ΔΦ  = std.(res)

    idxs = [idx for idx ∈ 1:nrow(Xout) if (Xout.λ[idx] ≤ λ_lb) || (λ_ub ≤ Xout.λ[idx])]
    Φ[idxs] .= 0.0
    ΔΦ[idxs] .= 0.0
    
    # update for any prediction above 1.0 or below 0.0
    idx_one = [idx for idx ∈ 1:size(Φ,1) if Φ[idx] > 1.0]
    Φ[idx_one] .= 1.0

    idx_zero = [idx for idx ∈ 1:size(Φ,1) if Φ[idx] < 0.0]
    Φ[idx_zero] .= 0.0
 
    return Φ, ΔΦ
    #return res
end



using StatsBase
function filter_outliers(df::DataFrame, column::AbstractVector; frac=1.5)
    IQR = iqr(column)
    iq_0, iq_25, iq_50, iq_75, iq_100 = nquantile(column, 4)
    idxs = [idx for idx ∈ 1:size(column,1) if column[idx] > iq_25 - frac * IQR && column[idx] < iq_75 + frac * IQR]
    return df[idxs, :]
end
 


