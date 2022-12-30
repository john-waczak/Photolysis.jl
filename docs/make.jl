using Photolysis
using Documenter

DocMeta.setdocmeta!(Photolysis, :DocTestSetup, :(using Photolysis); recursive=true)

makedocs(;
    modules=[Photolysis],
    authors="John Waczak <john.louis.waczak@gmail.com>",
    repo="https://github.com/john-waczak/Photolysis.jl/blob/{commit}{path}#{line}",
    sitename="Photolysis.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://john-waczak.github.io/Photolysis.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/john-waczak/Photolysis.jl",
    devbranch="main",
)
