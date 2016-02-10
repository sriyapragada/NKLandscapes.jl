# To run standalone from NKLandscapes.jl directory:  
#  julia -L "src/NKLandscapes.jl" test/fastnets.jl
import NKLandscapes
const NK = NKLandscapes
using FactCheck

n = 3    # n is arbitrary as long as n >= 3
k = 0    # k must be 0 for these tests to work
a = 2    # a must be 2 for some of the neutral nets functions to work

# Since k == 0, ls has a single minimum fitness neutral net and a single maximum fitness neutral net
# Works for either an NKq landscape or an NK landscape
type LandscapeProperties
  ls::NK.Landscape
  fa::Array{Float64,1}   # Array of fitnesses indexed by integer genotypes
  fl::Array{Int64,1}     # Array of fitness levels indexed by integer genotypes
  min_g::Array{Int64,1}  # A genotype of minimum fitness
end

function LandscapeProperties(ls::NK.Landscape)
  fa = NK.fitness_array(ls)
  fl = NK.fitness_levels_array(ls,ls.n,fa)
  min_g = NK.int_to_genotype(indmin(fa)-1,ls)
  LandscapeProperties(ls,fa,fl,min_g)
end

lsp_nk = LandscapeProperties(NK.NKLandscape(n,k))
lsp_nkq = LandscapeProperties(NK.NKqLandscape(n,k,a))
lsp_list = [lsp_nk,lsp_nkq]

facts("NKLandscapes.jl fast neighbors, walks, and neutral net tests") do
  context("NK.neighbors(...)") do
    for lsp in lsp_list
      fe_size = size(NK.fitter_or_equal_neighbors(lsp.min_g,lsp.ls))[2]
      @fact n --> fe_size "Expected number of fitter or equal neighbors to be N = $n"
      nn_size = size(NK.neutral_neighbors(lsp.min_g,lsp.ls))[2]
      fn_size = size(NK.fitter_neighbors(lsp.min_g,lsp.ls))[2]
      @fact n --> nn_size + fn_size "Expected number of neutral nbrs + number of fitter nbrs to be N = $n"
      fit_increment = 1.0/lsp.ls.n - eps()
      lb = 0.0
      frn_sum = 0
      for i = 0:lsp.ls.n
        ub = lb + fit_increment
        frn_size = size(NK.fitness_range_neighbors(lsp.min_g,lsp.ls,lb,ub))[2]
        frn_sum += frn_size
        lb = ub 
      end
      @fact n --> frn_sum "Expected sum of number of fitness range neighbors to be N = $n"
    end
  end

  context("NK.walks(...)") do
    for lsp in lsp_list
      max_fit = maximum(lsp.fa)
      rand_w = NK.random_adaptive_walk(lsp.min_g,lsp.ls)
      @fact max_fit --> roughly(rand_w.fitnesses[end]) 
        "Expected final fitness of random adaptive walk to be maximum fitness of landscape which is $max_fit"
      greedy_w = NK.greedy_adaptive_walk(lsp.min_g,lsp.ls)
      @fact max_fit --> roughly(greedy_w.fitnesses[end]) 
        "Expected final fitness of greedy adaptive walk to be maximum fitness of landscape which is $max_fit"
      reluct_w = NK.reluctant_adaptive_walk(lsp.min_g,lsp.ls)
      @fact max_fit --> roughly(reluct_w.fitnesses[end]) 
        "Expected final fitness of reluctant adaptive walk to be maximum fitness of landscape which is $max_fit"
      fit_neutral_w = NK.fitter_then_neutral_walk(lsp.min_g,lsp.ls)
      @fact max_fit --> roughly(fit_neutral_w.fitnesses[end]) 
        "Expected final fitness of fitter_then_neutral adaptive walk to be maximum fitness of landscape which is $max_fit"
    end
  end

  context("NK.neutral_nets(...)") do
    for lsp in lsp_list
      lnn = sort(NK.list_neutral_nets(lsp.ls,lsp.fl),lt=(x,y)->x[3]<y[3])  # neutral nets sorted by fitness
      if length(lnn) > 1
        @fact lnn[end][3] --> greater_than(lnn[end-1][3])  "Expected a single neutral net of maximum fitness"
      else  # All genotypes have the same fitness
        @fact lsp.ls.a^lsp.ls.n --> lnn[end][2]  "Expected a single neutral net with all genotypes"
      end
    end
  end
end

