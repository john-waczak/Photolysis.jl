
"""
    function get_raw_data(h5_path, species)

Read HDF5 datafile and return relevant cross section data for `species`.
"""
function get_raw_data(h5_path, species)
    h5 = h5open(h5_path, "r")
    
    cross_sections = h5["cross-sections"]
    
    species in keys(cross_sections)
    
    data_full = cross_sections[species]
    
    λs = read(data_full, "λ")
    σs = read(data_full, "σ")
    T1s = read(data_full, "T1")
    T2s = read(data_full, "T2")
    source_idx = read(data_full, "source_idx")



    T_units = read_attribute(data_full, "T1_units")
    category= read_attribute(data_full, "category")
    formula= read_attribute(data_full, "formula")
    λ_units = read_attribute(data_full, "λ_units")
    σ_units = read_attribute(data_full, "σ_units")

    close(h5)
    
    return λs, σs, T1s, T2s, source_idx, T_units, category, formula, λ_units, σ_units

end

"""
    function data_to_df(λs, σs, T1s, T2s, source_idx; σ_lb=1e-25, σ_ub=1.0, T_lb=290.0, T_ub=305.0, λ_lb=200.0, λ_ub=1100.0)

Given  relevant cross section data, filter to reasonable range and return dataset in form of a DataFrame.
"""
function data_to_df(λs, σs, T1s, T2s, source_idx; σ_lb=1e-25, σ_ub=1.0, T_lb=290.0, T_ub=305.0, λ_lb=200.0, λ_ub=1100.0)
    Tout = [T1s[source_idx[i]] for i ∈ 1:size(source_idx, 1)]
    
    # we want T2 to be NaN
    idx = [ i for i  ∈ 1:size(source_idx,1) if isnan(T2s[source_idx[i]])]
    λout = λs[idx]
    σout = σs[idx]
    Tout = Tout[idx]
    source_out = source_idx[idx]

    # we want T between T_lb and T_ub
    idx2 = [i for i ∈ 1:size(λout,1) if (T_lb ≤ Tout[i] && Tout[i] ≤ T_ub)]
    λout = λout[idx2]
    σout = σout[idx2]
    Tout = Tout[idx2]
    source_out = source_out[idx2]

    # we want σ to not be NaN and greater than 0.
    idx3 = [i for i ∈ 1:size(σout,1) if !isnan(σout[i]) && (σout[i] > σ_lb) && (σout[i] ≤ σ_ub)]
    λout = λout[idx3]
    σout = σout[idx3]
    Tout = Tout[idx3]
    source_out = source_out[idx3]

    # we want λ to be between λ_lb and λ_ub
    idx4 = [i for i ∈ 1:size(λout,1) if (λ_lb ≤ λout[i] && λout[i] ≤ λ_ub)]
    λout = λout[idx4]
    σout = σout[idx4]
    Tout = Tout[idx4]
    source_out = source_out[idx4]
   
    # idxs = [i for i ∈ 1:size(source_idx, 1) if (T_lb < Temps[i] && Temps[i] < T_ub) && (!isnan(σs[i])) && (σs[i] ≥ 0.0) && (λ_lb ≤ λs[i] && λs[i] ≤ λ_ub) && isnan(T2s[source_idx[i]])]

    # 5. Create table with data containing the good values
    #data_table = Tables.columntable((; λ=λout, σ=σout, T=Tout, source_id=source_out))
    df =  DataFrame(λ=λout, σ=σout, T=Tout, source_id=source_out)
    return df
end



"""
    function representative_rand_sample(column::AbstractVector, nbins::Int, npoints::Int)

Given a column of data, return a set of `npoints` indices randomly sampled from `nbins`. 
"""
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





"""
    function predict_logσ(T, λs, mach, λ_bounds)

Given a fixed temperature `T` and wavelengths `λs`. Apply the fitted MLJ machine `mach` to predict `log10(σ)`. Fix value to `NaN` for wavelengths outside of `λ_bounds`.
"""
function predict_logσ(T, λs, mach, λ_bounds)
    λ_lb, λ_ub = λ_bounds
    
    Xout = copy(λs)
    Tout = T
    Xout[!, :T] = [Tout for _ ∈ 1:nrow(λs)]
    res = predict_mean(mach, Xout)
    
    idxs = [idx for idx ∈ 1:nrow(Xout) if (Xout.λ[idx] ≤ λ_lb) || (λ_ub ≤ Xout.λ[idx])]
    res[idxs] .= NaN 
    return res
end


"""
    function predict_logσ_wΔ(T, λs, mach, λ_bounds)

Given a fixed temperature `T` and wavelengths `λs`. Apply the fitted MLJ machine `mach` to predict the distribution of `log10(σ)`. Fix value to `NaN` for wavelengths outside of `λ_bounds`. Returns both logσ and Δlogσ i.e. the standard deviation. 
"""
function predict_logσ_wΔ(T, λs, mach, λ_bounds)
    λ_lb, λ_ub = λ_bounds
    
    Xout = copy(λs)
    Tout = T
    Xout[!, :T] = [Tout for _ ∈ 1:nrow(λs)]
    res = MLJ.predict(mach, Xout)

    logσ = mean.(res)
    Δlogσ = std.(res)

    idxs = [idx for idx ∈ 1:nrow(Xout) if (Xout.λ[idx] ≤ λ_lb) || (λ_ub ≤ Xout.λ[idx])]
    logσ[idxs] .= NaN 
    Δlogσ[idxs] .= NaN 
    return logσ, Δlogσ
    #return res
end
