
# summary_df

# using Plots

# tmp = download(summary_df.download_url[1])
# dlm = readdlm(tmp)
# p = plot(dlm[:,1], dlm[:,2],
#          label=summary_df.author_year[1],
#          title="CH₄ Absorption Cross Section",
#          ylabel = "σ [cm² molecule⁻¹]",
#          xlabel = "λ [nm]",
#          legend=false,
#          xlims=(500, 800),
#          yaxis=:log
#          )


# function plot_dlm(i, p)
#     tmp = download(summary_df.download_url[i])
#     dlm = readdlm(tmp)
#     nrows = size(dlm)[1]
#     if nrows < 2
#         scatter!(p,
#                  dlm[:,1], dlm[:,2],
#                  label=summary_df.author_year[i],
#                  markersize=3,
#                  msw=0.5,
#                  yaxis=:log
#                  )
#     else
#         plot!(p,
#               dlm[:,1], dlm[:,2],
#               label=summary_df.author_year[i],
#               yaxis=:log
#               )
#     end
# end

# for i ∈ 2:nrow(summary_df)
#     try
#         plot_dlm(i, p)
#     catch
#         println("didn't work...")
#     end
# end
# ylims!(p, 1e-28, 1e-23)
# p
# savefig("test.png")
# savefig("test.svg")

