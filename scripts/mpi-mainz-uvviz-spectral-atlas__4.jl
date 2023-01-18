using HDF5
using CSV, DataFrames
using ProgressMeter

# Set up paths
basepath = "../data"
crosssections_path = joinpath(basepath, "cross-sections")
quantumyields_path = joinpath(basepath, "quantum-yields")

isdir(basepath)
isdir(crosssections_path)
isdir(quantumyields_path)


function get_summary_list(path)
    # generate list of summary files to parse:
    summary_list = String[]

    for (root, dirs, files) in walkdir(path)
        for f ∈ files
            if occursin("summary", f) && endswith(f, ".csv")
                push!(summary_list, joinpath(root, f))
            end
        end
    end

    return summary_list
end

σ_summaries = get_summary_list(crosssections_path)
ϕ_summaries = get_summary_list(quantumyields_path)


# now we need a function to generate a DataFrame with all data
function collate_summary(summary_path)
    summary_df = CSV.File(summary_path) |> DataFrame

    T₁ = []
    T₂ = []
    author_year = []
    comments = []
    name = []
    doi = []
    formula = []
    fname = []
    download_url = []

    # these will be updated with data from each individual file
    λ = []
    σ = []
    Δσ = []
    source_idx = []

    for i ∈ 1:nrow(summary_df)
        push!(T₁, summary_df.T1[i])
        push!(T₂, summary_df.T2[i])
        push!(author_year, summary_df.author_year[i])
        push!(comments, summary_df.comments[i])
        push!(name, summary_df.name[i])
        push!(doi, summary_df.doi[i])
        push!(formula, summary_df.formula[i])
        push!(fname, summary_df.fname[i])
        push!(download_url, summary_df.download_url[i])

        try
            df = CSV.File(joinpath("../", summary_df.fname[i])) |> DataFrame
            push!(λ, df.λ)
            push!(σ, df.σ)
            push!(Δσ, df.Δσ)
            push!(source_idx, [i for j ∈ 1:nrow(df)])
        catch e
            println("Couldn't load $(summary_df.fname[i])")
            println(e)
        end
    end

    # note that name and formula are the same for each row
    return Float64.(T₁), Float64.(T₂), author_year, comments, name[1], doi, formula[1], fname, download_url, vcat(λ...), vcat(σ...), vcat(Δσ...), vcat(source_idx...)
end



function collate_summary_ϕ(summary_path)
    summary_df = CSV.File(summary_path) |> DataFrame

    T₁ = []
    T₂ = []
    author_year = []
    comments = []
    name = []
    doi = []
    reaction = []
    fname = []
    download_url = []

    # these will be updated with data from each individual file
    λ = []
    Φ = []
    ΔΦ = []
    species = []
    source_idx = []

    for i ∈ 1:nrow(summary_df)
        push!(T₁, summary_df.T1[i])
        push!(T₂, summary_df.T2[i])
        push!(author_year, summary_df.author_year[i])
        push!(comments, summary_df.comments[i])
        push!(name, summary_df.name[i])
        push!(doi, summary_df.doi[i])
        push!(reaction, summary_df.reaction[i])
        push!(fname, summary_df.fname[i])
        push!(download_url, summary_df.download_url[i])

        try
            df = CSV.File(joinpath("../", summary_df.fname[i])) |> DataFrame
            push!(λ, df.λ)
            push!(Φ, df.Φ)
            push!(ΔΦ, df.ΔΦ)
            push!(species, df.species)
            push!(source_idx, [i for j ∈ 1:nrow(df)])
        catch e
            println("Couldn't load $(summary_df.fname[i])")
            println(e)
        end
    end

    # note that name and formula are the same for each row
    return Float64.(T₁), Float64.(T₂), author_year, comments, name[1], doi, reaction[1], fname, download_url, vcat(λ...), vcat(Φ...), vcat(ΔΦ...), vcat(species...), vcat(source_idx...)
end




function get_category_info(path)
    return split(path, "/")[4:end-2]
end



# create and open h5 file
h5_path = "../data/photolysis_data.h5"
fid = h5open(h5_path, "cw")

# create group for cross-sections
create_group(fid, "cross-sections")
create_group(fid, "quantum-yields")

σ_data = fid["cross-sections"]

# now loop through cross sections and update hdf5 file
σ_fails = String[]

for σ_summary ∈ σ_summaries
    println(σ_summary)
    try
        # get the data
        categories = get_category_info(σ_summary)
        T1, T2, author_year, comments, name, doi, formula, fname, download_url, λ, σ, Δσ, source_idx = collate_summary(σ_summary)

        # create a subgroup
        molecule = create_group(σ_data, formula)
        # create datasets
        molecule["T1"] = T1
        molecule["T2"] = T2
        molecule["λ"] = λ
        molecule["σ"] = σ
        molecule["Δσ"] = Δσ
        molecule["source_idx"] = source_idx

        # create attributes
        attributes(molecule)["formula"] = formula
        attributes(molecule)["λ_units"] = "nm"
        attributes(molecule)["σ_units"] = "cm^2"
        attributes(molecule)["Δσ_units"] = "cm^2"
        attributes(molecule)["T1_units"] = "K"
        attributes(molecule)["T2_units"] = "K"

        if length(categories) == 1
            attributes(molecule)["category"] = categories[1]
        else
            attributes(molecule)["category"] = categories[1]
            attributes(molecule)["sub-category"] = categories[2]
        end


        source_info = create_group(molecule, "source_info")
        for i ∈ 1:length(author_year)
            sc = create_group(source_info, "$(i)")
            attributes(sc)["author(year)"] = author_year[i]

            if ismissing(doi[i])
                attributes(sc)["doi"] = ""
            else
                attributes(sc)["doi"] = doi[i]
            end

            attributes(sc)["download_url"] = download_url[i]

            if ismissing(comments[i])
                attributes(sc)["comments"] = ""
            else
                attributes(sc)["comments"] = comments[i]
            end
        end
    catch e
        println("FAILED: ", σ_summary)
        println(e)
        push!(σ_fails, σ_summary)
    end

end


ϕ_data = fid["quantum-yields"]
ϕ_fails = String[]

# ϕ_summary = ϕ_summaries[3]

for ϕ_summary ∈ ϕ_summaries
    println(ϕ_summary)
    try
        # get the data
        categories = get_category_info(ϕ_summary)
        T1, T2, author_year, comments, name, doi, reaction, fname, download_url, λ, Φ, ΔΦ, species, source_idx = collate_summary_ϕ(ϕ_summary)
        # create a subgroup
        reaction_name = reaction

        reaction = create_group(ϕ_data, replace(reaction, "→"=>" to ", "+"=>" and " ))

        # create datasets
        reaction["T1"] = T1
        reaction["T2"] = T2
        reaction["λ"] = λ
        reaction["Φ"] = Φ
        reaction["ΔΦ"] = ΔΦ

        species_list = unique(species)
        species_id = [findfirst(spec .== species_list) for spec ∈ species]

        reaction["species"] = species_id
        reaction["source_idx"] = source_idx

        # create attributes
        attributes(reaction)["reaction"] = reaction_name
        attributes(reaction)["λ_units"] = "nm"
        attributes(reaction)["Φ_units"] = ""
        attributes(reaction)["ΔΦ_units"] = ""
        attributes(reaction)["T1_units"] = "K"
        attributes(reaction)["T2_units"] = "K"

        if length(categories) == 1
            attributes(reaction)["category"] = categories[1]
        else
            attributes(reaction)["category"] = categories[1]
            attributes(reaction)["sub-category"] = categories[2]
        end


        source_info = create_group(reaction, "source_info")
        for i ∈ 1:length(author_year)
            sc = create_group(source_info, "$(i)")
            attributes(sc)["author(year)"] = author_year[i]

            if ismissing(doi[i])
                attributes(sc)["doi"] = ""
            else
                attributes(sc)["doi"] = doi[i]
            end

            attributes(sc)["download_url"] = download_url[i]

            if ismissing(comments[i])
                attributes(sc)["comments"] = ""
            else
                attributes(sc)["comments"] = comments[i]
            end
        end
    catch e
        println("FAILED: ", ϕ_summary)
        println(e)
        push!(ϕ_fails, ϕ_summary)
    end

end

# close h5 file
close(fid)

σ_fails
ϕ_fails

