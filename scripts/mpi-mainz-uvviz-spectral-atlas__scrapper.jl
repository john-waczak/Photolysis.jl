using HTTP
using Gumbo
using Cascadia
using DelimitedFiles
using CSV, DataFrames


# 0. Set up paths

outpath_base = "../data"
if !isdir(outpath_base)
    mkpath(outpath_base)
end

outpath_crosssections = joinpath(outpath_base, "cross-sections")
if !isdir(outpath_crosssections)
    mkpath(outpath_crosssections)
end

outpath_quantumyields = joinpath(outpath_base, "quantum-yields")
if !isdir(outpath_quantumyields)
    mkpath(outpath_quantumyields)
end



base_url = "https://uv-vis-spectral-atlas-mainz.org/uvvis/"
cross_sections_url = joinpath(base_url, "cross_sections/")
quantum_yields_url = joinpath(base_url, "quantum_yields/")



# 1. Cross Sections

function getcategories(text)
    h = parsehtml(text)
    body = h.root[2]
    s = eachmatch(Selector("table"), body)

    table = s[4][1]
    nrows = length(table.children)

    categories = String[]
    for i ∈ 1:nrows
        push!(categories, table[i][1][1][1].text)
    end

    categories_nospace = replace.(categories, " "=>"%20")
    return categories, categories_nospace
end


function hassubcategories(url)
    r = HTTP.get(url)
    text = String(r.body)
    return occursin("Subcategories:", text), text
end

function getsubcategories(text)
    h = parsehtml(text)
    body = h.root[2]
    s = eachmatch(Selector("table"), body)

    table = s[4][1]
    nrows = length(table.children)

    subcategories = String[]

    for i ∈ 1:nrows
        push!(subcategories, table[i][1][1][1].text)
    end

    subcategories_nospace = replace.(subcategories, " "=>"%20")
    return subcategories, subcategories_nospace
end



function hascasnumber(url)
    r = HTTP.get(url)
    text = String(r.body)
    return occursin("CAS RN", text), text
end

function getspecies(text)
    h = parsehtml(text)
    body = h.root[2]
    s = eachmatch(Selector("table"), body)
    table = s[4][1]

    nrows = length(table.children)

    formulae = String[]
    for i ∈ 2:nrows
        push!(formulae, table[i][1][1][1].text)
    end

    return formulae
end




# loop through Formula and generate a csv with links to each dataset
function hasdataset(url)
    r = HTTP.get(url)
    text = String(r.body)
    return occursin("Data Sets:", text), text
end


function getdatasets(text)
    h = parsehtml(text)
    body = h.root[2]
    s = eachmatch(Selector("table"), body)

    if occursin("graphical representations not available", text)
        table = s[5][1]
        nrows = length(table.children)

        datasets = String[]
        for i ∈ 2:nrows
            push!(datasets, table[i][1][1].attributes["href"])
        end
    else
        table = s[6][1]
        nrows = length(table.children)

        datasets = String[]
        for i ∈ 2:nrows
            push!(datasets, joinpath(base_url, table[i][1][1].attributes["href"]))
        end
    end

    return datasets
end


function getdatainfo(url)
    r = HTTP.get(url)
    text = String(r.body)
    h = parsehtml(text)
    body = h.root[2]
    s = eachmatch(Selector("table"), body)
    length(s)

    table = s[4][1]

    datafile = table[1][2][1].attributes["href"]
    datafileurl = replace("https://uv-vis-spectral-atlas-mainz.org/"*datafile, " "=>"%20")

    out_dict = Dict()

    out_dict[:download_url] = datafileurl
    out_dict[:name] = table[2][2][1].text
    out_dict[:formula] =  table[3][2][1].text


    splitname = split(replace(datafile, "/uvvis_data/cross_sections"=>"data/cross-sections"), "/")
    fname = joinpath(splitname[1:end-1]..., out_dict[:formula], splitname[end])
    fname = split(fname, ".")[1]*".csv"
    out_dict[:fname] = fname

    out_dict[:author_year] = table[4][2][1].text
    out_dict[:T] = parse(Float64, chop(table[5][2][1].text))
    out_dict[:citation] = table[7][2][1].text
    out_dict[:comments] = table[8][2][1].text
    return out_dict
end


function getdata(url, fname, outpath)
    tmp = download(url)

     df = CSV.File(tmp) |> DataFrame

    # figure out which columns actually have data
    datacols = [eltype(col) != Missing for col ∈ eachcol(df)]

    df = df[!, datacols]

    # alternative strategy for one line files
    if size(df) == (0,0)
        dlm = readdlm(tmp)
        df = DataFrame()
        df.λ = [dlm[1,1]]
        df.σ = [dlm[1,2]]
    end

    # check for weird edge case
    if typeof(df[1,1]) <: String
        if occursin("---", df[1,1])
            df = df[2:end, :]
        end
    end


    return_df = DataFrame()

    return_df.λ = df[!, 1]
    return_df.σ = df[!, 2]

    if ncol(df) > 2
        return_df.uncertainty = df[!,3]
        if any(ismissing.(df[!,3])) && ncol(df) >= 4
            # maybe it got misplaced to the left?
            idxs = ismissing.(df[!,3])
            return_df.uncertainty[idxs] = df[idxs, 4]
        end
    end

    CSV.write(joinpath(outpath, fname), return_df)
end





# generate list of categories
r = HTTP.get(cross_sections_url)
text = String(r.body)
categories, categories_nospace = getcategories(text)

# create subdirectories
for cat ∈ categories
    catpath = joinpath(outpath_crosssections, cat)
    if !isdir(catpath)
        mkpath(catpath)
    end
end


# loop through each category and look for subcategories
urllist = String[]
failure_list = String[]

for i ∈ 1:length(categories)
    url = joinpath(cross_sections_url, categories_nospace[i])
    hassubcat, text = hassubcategories(url);
    if hassubcat
        println(categories[i], " has subcategories!")
        subcats, subcats_nospace = getsubcategories(text)

        for j ∈ 1:length(subcats)
            subcatpath = joinpath(outpath_crosssections, categories[i], subcats[j])
            if !isdir(subcatpath)
                mkpath(subcatpath)
            end

            subcaturl = joinpath(url, subcats_nospace[j])
            hascas, text = hascasnumber(subcaturl);
            formulae = getspecies(text)

            for formula ∈ formulae
                formulapath = joinpath(outpath_crosssections, categories[i], subcats[j], formula)
                if !isdir(formulapath)
                    mkpath(formulapath)
                end

                formulaurl = joinpath(subcaturl, formula*".spc")
                push!(urllist, formulaurl)

                # for each formula, grab all datasets and generate csv with links.
                try
                    hasdata, text = hasdataset(formulaurl)
                    if hasdata
                        datasets = getdatasets(text)

                        summary_dict = Dict(
                            :T => Float64[],
                            :author_year => String[],
                            :download_url => String[],
                            :comments => String[],
                            :formula => String[],
                            :name => String[],
                            :citation => String[],
                            :fname => String[],
                        )

                        for dataset ∈ datasets
                            println("\t working on $(dataset)")
                            try
                                info = getdatainfo(replace(dataset, " "=>"%20"))

                                push!(summary_dict[:T], info[:T])
                                push!(summary_dict[:author_year], info[:author_year])
                                push!(summary_dict[:download_url], info[:download_url])
                                push!(summary_dict[:comments], info[:comments])
                                push!(summary_dict[:formula], info[:formula])
                                push!(summary_dict[:name], info[:name])
                                push!(summary_dict[:citation], info[:citation])
                                push!(summary_dict[:fname], info[:fname])

                                getdata(info[:download_url], info[:fname], "../")
                            catch
                                println("FAILURE: $(dataset)")
                                push!(failure_list, dataset)
                            end
                        end

                        CSV.write(joinpath(formulapath, "summary.csv"), summary_dict)
                    end
                catch
                    println("FAILURE: Couldn't read $(formulaurl)")
                end

            end

        end
    else
        hascas, text = hascasnumber(url);
        formulae = getspecies(text)

        for formula ∈ formulae
            formulapath = joinpath(outpath_crosssections, categories[i], formula)
            if !isdir(formulapath)
                mkpath(formulapath)
            end

            formulaurl = joinpath(url, formula*".spc")
            push!(urllist, formulaurl)

            try
                # for each formula, grab all datasets and generate csv with links.
                hasdata, text = hasdataset(formulaurl)
                if hasdata
                    datasets = getdatasets(text)
                    summary_dict = Dict(
                        :T => Float64[],
                        :author_year => String[],
                        :download_url => String[],
                        :comments => String[],
                        :formula => String[],
                        :name => String[],
                        :citation => String[],
                        :fname => String[],
                    )


                    for dataset ∈ datasets
                        println("\t working on $(dataset)")
                        try
                            info = getdatainfo(replace(dataset, " "=>"%20"))


                            push!(summary_dict[:T], info[:T])
                            push!(summary_dict[:author_year], info[:author_year])
                            push!(summary_dict[:download_url], info[:download_url])
                            push!(summary_dict[:comments], info[:comments])
                            push!(summary_dict[:formula], info[:formula])
                            push!(summary_dict[:name], info[:name])
                            push!(summary_dict[:citation], info[:citation])
                            push!(summary_dict[:fname], info[:fname])

                            getdata(info[:download_url], info[:fname], "../")
                        catch
                            println("FAILURE: $(dataset)")
                            push!(failure_list, dataset)
                        end
                    end

                    CSV.write(joinpath(formulapath, "summary.csv"), summary_dict)
                end

            catch
                println("FAILURE: Couldn't read $(formulaurl)")
            end

        end
    end
end

# save file with urls
writedlm("../data/cross_section_urls.csv", urllist, ",")
writedlm("failed_urls.csv", failure_list, ",")

ch4_path = "/home/jwaczak/gitrepos/ActivePure/Photolysis.jl/data/cross-sections/Alkanes+alkyl radicals/Alkanes/CH4"
summary_df = CSV.File(joinpath(ch4_path, "summary.csv")) |> DataFrame

summary_df

using Plots

tmp = download(summary_df.download_url[1])
dlm = readdlm(tmp)
p = plot(dlm[:,1], dlm[:,2],
         label=summary_df.author_year[1],
         title="CH₄ Absorption Cross Section",
         ylabel = "σ [cm² molecule⁻¹]",
         xlabel = "λ [nm]",
         legend=false,
         xlims=(500, 800),
         yaxis=:log
         )


function plot_dlm(i, p)
    tmp = download(summary_df.download_url[i])
    dlm = readdlm(tmp)
    nrows = size(dlm)[1]
    if nrows < 2
        scatter!(p,
                 dlm[:,1], dlm[:,2],
                 label=summary_df.author_year[i],
                 markersize=3,
                 msw=0.5,
                 yaxis=:log
                 )
    else
        plot!(p,
              dlm[:,1], dlm[:,2],
              label=summary_df.author_year[i],
              yaxis=:log
              )
    end
end

for i ∈ 2:nrow(summary_df)
    try
        plot_dlm(i, p)
    catch
        println("didn't work...")
    end
end
ylims!(p, 1e-28, 1e-23)
p
savefig("test.png")
savefig("test.svg")

