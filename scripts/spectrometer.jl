using Statistics
using DelimitedFiles, CSV, DataFrames
using CairoMakie
using MintsMakieRecipes
set_theme!(mints_theme)
update_theme!(
    figure_padding=30,
    Axis=(
        xticklabelsize=20,
        yticklabelsize=20,
        xlabelsize=22,
        ylabelsize=22,
        titlesize=25,
    ),
    Colorbar=(
        ticklabelsize=20,
        labelsize=22
    )
)



# https://www.oceaninsight.com/support/faqs/measurements/#:~:text=Absolute%20Irradiance,in%20both%20shape%20and%20magnitude.
# Absolute Irradiance:
# I = (S-Sd)Cp/(T*A*dLp)  (μJ/s/cm²/nm)
#
# S = raw spectrum (counts/pixel)
# Sd = dark spectrum (counts/pixel)
# Cp = calibration file (μJ/count)
# T = integration time (s)
# A = collection area (cm²)
# dLp = wavelength spread (nm)

h =  6.62607015*1e−34 # J⋅s (joule-hertz−1)
c = 299_792_458.0 # m/s
kb = 1.380649*1e−23 # J/K


calpath = "../data/calibration/HR4D3312/HR4D3312_cc_20220316_105010_OOIIrrad.CAL"
@assert ispath(calpath)

basepath = "../data/spectra/indoors/kitchen"
darkspath = joinpath(basepath, "darks")
lightspath = joinpath(basepath, "lights")

fs_dark = joinpath.(darkspath,readdir(darkspath))
fs_light = joinpath.(lightspath, readdir(lightspath))


function load_spec(fpath)
    lines = readlines(fpath)
    idx_start = findfirst(occursin.("Begin Spectral Data", lines)) + 1

    length(idx_start:length(lines))

    length(lines) - idx_start

    λs = zeros(length(lines) - idx_start + 1)
    Is = zeros(length(lines) - idx_start + 1)

    Threads.@threads for i ∈ idx_start:length(lines)
        λ, I = parse.(Float64, split(lines[i], "\t"))
        #I = (I == -0.0 || I < 0.0) ? 0.0 : I
        λs[i - idx_start + 1] = λ
        Is[i - idx_start + 1] = I
    end

    return λs, Is
end


function load_spectrum(fpaths)
    λs = []
    Is = []

    for fpath ∈ fpaths
        λ, I = load_spec(fpath)
        push!(λs, λ)
        push!(Is, I)
    end

    λout = mean(λs)
    Iout = mean(Is)
    #Iout[Iout .== -0.0 .|| Iout .< 0.0] .= 0.0

    return λout, Iout
end


λ_dark, S_dark = load_spec(fs_dark[1])

λ_dark, S_dark = load_spectrum(fs_dark)
λ_light, S_light = load_spectrum(fs_light)



fig, ax, l = lines(λ_light, S_light .- S_dark)
xlims!(ax, 200, 1000)
fig


function convert_to_photons(I, λ)
    E_photon = h*c/(λ * 1e-9)  # (J⋅s)⋅(m⋅s⁻¹)(m⁻¹) ⟶ J [per photon]
    Ĩ = I * 1e-6  # μJ⋅s⁻¹⋅cm⁻²⋅nm⁻¹  ⟶ J⋅s⁻¹⋅cm⁻²⋅nm⁻¹
    res = Ĩ/E_photon  # photons⋅s⁻¹⋅cm⁻²⋅nm⁻¹
end




λ_outside, I_outside= load_spectrum(outside_paths)
λ_kitchen, I_kitchen = load_spectrum(kitchen_paths)
λ_ap, I_ap= load_spectrum(ap_paths)


fig = Figure();
gl = GridLayout(fig[1,1]);
ax = Axis(gl[2,1], xlabel="λ (nm)", ylabel="Spectral Irradiance (μW⋅cm⁻²⋅nm⁻¹)", yscale=log10)
l1 = lines!(λ_outside, I_outside .+ eps(Float64), linewidth=3)
l2 = lines!(λ_ap, I_ap .+ eps(Float64), linewidth=3)
l3 = lines!(λ_kitchen, I_kitchen .+ eps(Float64), linewidth=3)
leg = Legend(gl[1,1], [l1, l2, l3], ["Outside (Sun)", "Office (Fluorescent)", "Kitchen (Incandescent)"], framevisible=false, orientation=:horizontal)
#colsize!(gl, 2, Relative(0.33))
xlims!(ax, 200, 1100)
ylims!(ax, 1e-3,nothing)
fig

save(joinpath(fig_path, "spectral-irradiance.png"), fig)
save(joinpath(fig_path, "spectral-irradiance.svg"), fig)
save(joinpath(fig_path, "spectral-irradiance.pdf"), fig)


# now let's convert to the appropriate units...
λ_outside
I_outside



F_outside = convert_to_photons.(I_outside, λ_outside)
F_kitchen = convert_to_photons.(I_kitchen, λ_kitchen)
F_ap = convert_to_photons.(I_ap, λ_ap)


top_lines = readlines(top_path)[2:204]
solar_dat = zeros(203, 3)


# grab David's solar spectra at top of atmosphere

for i ∈ 1:length(top_lines)
    split_line = [parse(Float64, d) for d ∈ split(top_lines[i], " ") if d != ""]
    solar_dat[i, 1] = split_line[2]
    solar_dat[i, 2] = split_line[3]
    solar_dat[i, 3] = split_line[4]
    println(split_line)
end

λ_top = solar_dat[:,1]
F_top = solar_dat[:,3]

lines(λ_top, F_top)

fig = Figure();
gl = GridLayout(fig[1,1]);
ax = Axis(gl[2,1], xlabel="λ (nm)", ylabel="Spectral Flux Density\n(photons⋅s⁻¹⋅cm⁻²⋅nm⁻¹)", yscale=log10)
l1 = lines!(ax, λ_outside, F_outside .+ eps(Float64), linewidth=3)
l2 = lines!(ax, λ_ap, F_ap .+ eps(Float64), linewidth=3)
l3 = lines!(ax, λ_kitchen, F_kitchen .+ eps(Float64), linewidth=3)
l4 = lines!(ax, λ_top, F_top .+ eps(Float64), linewidth=3)
leg = Legend(gl[1,1], [l1, l2, l3, l4], ["Outside (Sun)", "Office (Fluorescent)", "Kitchen (Incandescent)", "Top of Atmosphere"], framevisible=false, orientation=:horizontal)
#colsize!(gl, 2, Relative(0.33))
xlims!(ax, 200, 1100)
ylims!(ax, 1e10,nothing)


fig

save(joinpath(fig_path, "spectral-flux-density.png"), fig)
save(joinpath(fig_path, "spectral-flux-density.svg"), fig)
save(joinpath(fig_path, "spectral-flux-density.pdf"), fig)


xlims!(200, 400)
ylims!(1e10, 1e16)
fig

save(joinpath(fig_path, "spectral-flux-density__zoomed.png"), fig)
save(joinpath(fig_path, "spectral-flux-density__zoomed.svg"), fig)
save(joinpath(fig_path, "spectral-flux-density__zoomed.pdf"), fig)




fig = Figure();
ax = Axis(fig[1,1], xlabel="λ (nm)", ylabel="Spectral Irradiance (μW⋅cm⁻²⋅nm⁻¹)", title="Solar Irradiance Spectrum at Ground")
l1 = lines!(λ_outside, F_outside, linewidth=3)
#colsize!(gl, 2, Relative(0.33))
xlims!(ax, 200, 1100)
fig

save(joinpath(fig_path, "solar-irradiance-ground.png"), fig)
save(joinpath(fig_path, "solar-irradiance-ground.pdf"), fig)
save(joinpath(fig_path, "solar-irradiance-ground.svg"), fig)



fig = Figure();
ax = Axis(fig[1,1], xlabel="λ (nm)", ylabel="Spectral Flux Density\n(photons⋅s⁻¹⋅cm⁻²⋅nm⁻¹)", title="Solar Flux at Ground")
l1 = lines!(λ_outside, F_outside, linewidth=3)
xlims!(ax, 200, 1100)
fig


save(joinpath(fig_path, "solar-flux-ground.png"), fig)
save(joinpath(fig_path, "solar-flux-ground.pdf"), fig)
save(joinpath(fig_path, "solar-flux-ground.svg"), fig)


fig

# we could try to grab the solar zenith angle to label plot...
