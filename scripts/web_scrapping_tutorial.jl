using HTTP
using Gumbo
using Cascadia


# --------- Example 1 ----------------------

# get HTML
url = "https://dabblingdoggo.github.io/mysite3/doggo/data.html"

r = HTTP.get(url)

h = parsehtml(String(r.body))  # only function we need from Gumbo

h.root[1] # the header
h.root[2] # the body

body = h.root[2]

body[1]
body[2]
body[3]
body[4]  # the table

body[4][1]

table = body[4][1][1]
nrows = length(table.children)

header = table[1]
ncols = length(header.children)

# column info
table[1][1]
table[1][2]
table[1][3]

# actual text
table[1][1][1].text


# pattern is table[row][col][1].text
matrix = Array{String}(undef, nrows, ncols)
for col ∈ 1:ncols, row ∈ 1:nrows
    matrix[row, col] = table[row][col][1].text
end

display(matrix)

# save to csv file
using DelimitedFiles
writedlm("client-list.csv", matrix, ",")



# --------- Example 2 ----------------------

url = "https://dabblingdoggo.github.io/mysite11/"
r = HTTP.get(url)
h = parsehtml(String(r.body))

body = h.root[2]

# find the table element
table = body[1][38][1]

# figure out nrows and ncols
nrows = length(table.children)

header = table[1]
ncols = length(header.children)

matrix = Array{String}(undef, nrows, ncols)
for col ∈ 1:ncols, row ∈ 1:nrows
    matrix[row, col] = table[row][col][1].text
end

display(matrix)

# save output
writedlm("worl-population.csv", matrix, ",")



# --------- Example 3 ----------------------
url = "https://dabblingdoggo.github.io/mysite3/doggo/about.html"

r = HTTP.get(url)

h = parsehtml(String(r.body))  # only function we need from Gumbo

h.root[1] # the header
h.root[2] # the body

body = h.root[2]

data = body[4]
nrows = length(data.children)

data[1]
data[2]
data[3]

data[1][1][1]
data[1][1][2][1].text  # the data we want

staff = String[]
for row ∈ 1:nrows
    push!(staff, data[row][1][2][1].text)
end
staff

staff2 = String["Name", "Title"]
for row ∈ 1:nrows
    s = split(staff[row], ",")
    push!(staff2, s[1], s[2])
end

staff2

matrix = permutedims(reshape(staff2, (2, nrows+1)))
writedlm("staff_gumbo.csv", matrix, ",")

]

# -------------- Example 4 ----------------------

# how about just selecting HTML elements instead of indexing
url = "https://dabblingdoggo.github.io/mysite3/doggo/about.html"
r = HTTP.get(url)
h = parsehtml(String(r.body))  # only function we need from Gumbo
body = h.root[2]

s = eachmatch(Selector(".label"), body)

s[1]
s[2]
s[3]

s[1][1].text

nrows = length(s)

staff = String[]
for row ∈ 1:nrows
    push!(staff, s[row][1].text)
end
staff

staff2 = String["Name", "Title"]
for row ∈ 1:nrows
    s = split(staff[row], ",")
    push!(staff2, s[1], s[2])
end

staff2

matrix = permutedims(reshape(staff2, (2, nrows+1)))
writedlm("staff_cascadia.csv", matrix, ",")



# -------------- Example 5 ----------------------
url = "https://en.wikipedia.org/wiki/ISO_3166-1"
r =  HTTP.get(url)
h = parsehtml(String(r.body))

body = h.root[2]

eachmatch(Selector("table"), body)

s = eachmatch(Selector(".wikitable.sortable"), body)

s[1]
s[2] # this is the one we want

table = s[2][2]
nrows = length(table.children)

table[1][1]
table[1][2]
table[1][3]

table[2][1][2][1].text

# pattern appears to be table[row][col][2][1].text


table[3][1][2][1][1].text
