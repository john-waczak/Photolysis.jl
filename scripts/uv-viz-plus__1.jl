using DelimitedFiles
using CSV, DataFrames
using HTTP, JSON

datapath = "../data/uv-viz-plus/SpectraData/2019/spektren"

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


first_letter = [read(f, String)[1] for f ∈ data_files]


idx_bad = findall(.!(first_letter .== '*'))

unique_letters = unique(first_letter)


letters_dict = Dict()

for l ∈ unique_letters
    for i ∈ 1:length(first_letter)
        if first_letter[i] == l
            letters_dict[l] = i
        end
        continue
    end
end


for l ∈ readlines(data_files[letters_dict['*']])[1:3]
    println(l)
end





lines=readlines(data_files[1])[1:3]
lines=readlines(data_files[2])[1:3]
lines=readlines(data_files[3])[1:3]
lines=readlines(data_files[4])[1:3]


# https://pubchem.ncbi.nlm.nih.gov/docs/pug-rest-tutorial

# curl -X GET https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/name/thiophosgene/synonyms/JSON
# curl -X GET https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/cid/24386/synonyms/JSON
# curl -X GET https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/name/SOCl2/cids/JSON
# curl -X GET https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/name/Thionyl%20chloride/cids/JSON
# curl -X GET https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/cid/1,2,3,4,5/property/MolecularFormula,MolecularWeight,CanonicalSMILES/CSV


function get_info(fpath)
    lines = readlines(fpath)

    substance = ""
    other_names= ""
    formula=""
    cas_num=""
    cid = ""

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
        end
    end

    return substance, other_names, formula, cas_num, cid
end


info = get_info.(summary_files)


CIDs = ["" for _ ∈ 1:length(info)]
bad_info = []

for i ∈ 1:length(info)
    substance, other, formula, cas, cid = info[i]
    if cid == ""
        push!(bad_info, i)
        # if occursin(", ", substance)
        #     push!(bad_info, i)
        #     println("Substance:\t", substance)
        #     println("Other:\t", other)
        #     println("Formula:\t", formula)
        #     println("CAS:\t", cas)
        #     println("---")
        # end
    else
        CIDs[i] = cid
    end
end



sub, oth, _, _, _ = info[bad_info[end-2]]


function get_cid(name)
    name_url = replace(
        name,
        " " => "%20",
        "(" => "%28",
        ")" => "%29",
    )

    name_url
    response = HTTP.get("https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/name/$(name_url)/cids/JSON")
    string(JSON.parse(String(response.body))["IdentifierList"]["CID"][1])
end


for i ∈ bad_info
    substance, other, formula, cas, cid = info[i]
    println(i, "\t", info[i])

    try
        cid = get_cid(substance)
        println("\tThat worked!")
    catch e
        println("\t\tSubstance didn't work. Sitting on , and trying again")
    end

    if cid==""
        try
            sub = split(substance, ",")[1]
            cid = get_cid(sub)
            println("\tThat worked!")
        catch e
            println("\t\tSecond try also didn't work...")
        end
    end

    if cid==""
        try
            cid = get_cid(other)
            println("\tThat worked!")
        catch e
            println("\t\tOther didnt work...")
        end
    end

    if cid==""
        try
            cid = get_cid(formula)
            println("\tThat worked!")
        catch e
            println("\t\tFormula didn't work...")
        end
    end

    if cid != ""
        CIDs[i] = cid
    else
        println("\tNothing worked")
    end

    sleep(0.75)
end



println(read(summary_files[bad_info[1]], String))







