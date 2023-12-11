# https://pubchem.ncbi.nlm.nih.gov/docs/pug-rest-tutorial

# curl -X GET https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/name/thiophosgene/synonyms/JSON
# curl -X GET https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/cid/24386/synonyms/JSON
# curl -X GET https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/name/SOCl2/cids/JSON
# curl -X GET https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/name/Thionyl%20chloride/cids/JSON
# curl -X GET https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/cid/1,2,3,4,5/property/MolecularFormula,MolecularWeight,CanonicalSMILES/CSV



using DelimitedFiles
using CSV, DataFrames
using HTTP, JSON
using ProgressMeter


datapath = "../data/databases/uv-viz-plus"
@assert ispath(datapath)


txt_files = String[]

for (root, dirs, files) ∈ walkdir(datapath)
    for f ∈ files
        if endswith(f, ".txt")
            push!(txt_files, joinpath(root, f))
        end
    end
end


summary_files = [f for f ∈ txt_files if !occursin("s", split(f, "_")[end])]
data_files = [f for f ∈ txt_files if occursin("s", split(f, "_")[end])]

σ_files = [f for f ∈ data_files if occursin("sigma", read(f, String)) || occursin("cross section", read(f, String)) || occursin("Cross Section", read(f, String))]
@assert all(isfile.(σ_files))


# Read summary file to extract information about species name

function get_info(fpath)
    lines = readlines(fpath)

    substance = ""
    other_names= ""
    formula=""
    cas_num=""
    cid = ""
    title = ""
    source = ""
    authors = ""

    for line ∈ lines
        sline = split(line, "\t")
        for s ∈ sline
            if occursin("Substance:", s)
                substance = strip(split(s, "Substance:")[2], ' ')
            end

            if occursin("Other Names:", s)
                other_names = strip(split(s, "Other Names:")[2], ' ')
            end

            if occursin("Other names:", s)
                other_names = strip(split(s, "Other names:")[2], ' ')
            end

            if occursin("Formula:", s)
                formula = strip(split(s, "Formula:")[2], ' ')
            end

            if occursin("CAS-No.:", s)
                cas_num = strip(split(s, "CAS-No.:")[2], ' ')
            end

            if occursin("PubChem:", s)
                cid = strip(split((split(s, "PubChem:")[2]), "CID")[end], ' ')
            end

            if occursin("Title:", s)
                title = strip(split(s, "Title:")[2], ' ')
            end

            if occursin("Journal:", s)
                source = strip(split(s, "Journal:")[2], ' ')
            end

            if occursin("Journal/Source:", s)
                source = strip(split(s, "Journal/Source:")[2], ' ')
            end

            if occursin("Author:", s)
                authors = strip(split(s, "Authors:")[2], ' ')
            end

            if occursin("Authors:", s)
                authors= strip(split(s, "Authors:")[2], ' ')
            end
        end
    end

    return substance, other_names, formula, cas_num, cid, title, source, authors
end




info = get_info.(summary_files)


if ispath(joinpath(datapath, "summary.csv"))
    df_summary = CSV.read(joinpath(datapath, "summary.csv"), DataFrame)
    replace!(df_summary.CID, missing => "")
else
    df_summary = DataFrame()
    df_summary.summary_file = summary_files

    df_summary.CID = ["" for _ ∈ 1:nrow(df_summary)]
    df_summary.title = ["" for _ ∈ 1:nrow(df_summary)]
    df_summary.source = ["" for _ ∈ 1:nrow(df_summary)]
    df_summary.authors = ["" for _ ∈ 1:nrow(df_summary)]


    # the key is to get the PubChem CID which we can then use to extract all other
    # relevant information and synonyms
    for i ∈ 1:nrow(df_summary)
        substance, other, formula, cas, cid, title, source, authors = info[i]
        if cid != ""
            df_summary.CID[i] = cid
        end

        if title != ""
            df_summary.title[i] = title
        end

        if source != ""
            df_summary.source[i] = title
        end

        if authors != ""
            df_summary.authors[i] = title
        end
    end
end


function get_cid(name)
    name_url = replace(
        name,
        " " => "%20",
        "(" => "%28",
        ")" => "%29",
        ";" => "%3B",
    )

    name_url
    response = HTTP.get("https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/name/$(name_url)/cids/JSON")
    string(JSON.parse(String(response.body))["IdentifierList"]["CID"][1])
end


@showprogress for i ∈ 1:nrow(df_summary)
    if df_summary.CID[i] == ""
        substance, other, formula, cas, cid, title, source, authors = info[i]
        try
            cid = get_cid(substance)
            df_summary.CID[i] = cid
            continue
        catch e
            nothing
        end

        try
            sub = split(substance, ",")[1]
            cid = get_cid(sub)
            df_summary.CID[i] = cid
            continue
        catch e
            nothing
        end

        try
            cid = get_cid(other)
            df_summary.CID[i] = cid
            continue
        catch e
            nothing
        end

        try
            cid = get_cid(formula)
            df_summary.CID[i] = cid
            continue
        catch e
            nothing
        end

        sleep(1)
    end

    CSV.write(joinpath(datapath, "summary.csv"), df_summary)
 end


idx_bad = findall(df_summary.CID .== "")
# info[idx_bad[4]]
# println(read(df_summary.summary_file[idx_bad[4]], String))

# df_summary.CID[idx_bad[1]] = get_cid("Potassium cobalticyanide")  # 1
# df_summary.CID[idx_bad[4]] = "158055828"  # 4



# add datafiles that correspond with each summary file
dfiles = []
@showprogress for i ∈ 1:nrow(df_summary)
    # i = 1
    # i = nrow(df_summary) - 2

    summary_file = df_summary.summary_file[i]

    # get the number
    fnumber = split(split(summary_file, "_")[end], ".")[1]

    # form search string
    basestring = join(split(summary_file, "_")[1:end-1],"_")*"_s"*fnumber

    # find matching datafiles
    matches = [f for f ∈ data_files if occursin(basestring, f)]

    push!(dfiles, matches)
end

df_summary.data_files = dfiles
CSV.write(joinpath(datapath, "summary.csv"), df_summary)



# now let's loop over the datafiles and check if any have "sigma", "Cross Section", or "cross section" inside them
df_summary.has_cross_section = [false for _ ∈ 1:nrow(df_summary)]

for i ∈ 1:nrow(df_summary)
    if length(df_summary.data_files[i]) != 0
        for f ∈ df_summary.data_files[i]
            contents = read(f, String)
            if occursin("sigma", contents) || occursin("Cross Section", contents) || occursin("cross section", contents) || occursin("cross-section", contents)
                df_summary.has_cross_section[i] = true
                continue
            end
        end
    end
end


# println(read(df_summary[bad_idx[1],:summary_file], String))
sum(df_summary.has_cross_section)


df_σ = df_summary[df_summary.has_cross_section .== true,:]


idx_bad = findall(df_σ.CID .== "")

df_σ.summary_file[idx_bad[3]]

# filter to only those for which we have CIDs
df_σ = df_σ[df_σ.CID .!= "", :]


CSV.write(joinpath(datapath, "cross-section_summary.csv"), df_σ)








first_letter = [read(f, String)[1] for f ∈ data_files]

idx_bad = findall(.!(first_letter .== '*'))

unique_letters = unique(first_letter)


letters_dict = Dict()

for l ∈ unique_letters
    letters_dict[l] = findall(first_letter .== l)
end

for (letter, idxs) ∈ letters_dict
    println("------")
    println("Starting letter: ", letter)
    lines = readlines(data_files[letters_dict[letter][1]])
    for i ∈ 1:min(3, length(lines))
        println("\t", lines[i])
    end
    println("\n")
end





