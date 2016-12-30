using Mimi

include("../src/SLRDamages.jl")

m = Model()
setindex(m, :region, ["EU", "USA", "OECD","USSR","China","SEAsia","Africa","LatAmerica"])
setindex(m, :time, 10)

slrdamages = addslrdamages(m)

#slrdamages[:rt_g_globaltemperature] = ones(10)
slrdamages[:y_year] = [2001.,2002.,2010.,2020.,2040.,2060.,2080.,2100.,2150.,2200.] #real value
setparameter(m, :SLRDamages, :y_year_0, 2000.) #real value
# TODO Replace with real numbers
setparameter(m, :SLRDamages, :s_sealevel, zeros(10))
setparameter(m, :SLRDamages, :WINCF_weightsfactor, zeros(8))
setparameter(m, :SLRDamages, :gdp_per_cap_after_costs, zeros(10, 8))
setparameter(m, :SLRDamages, :GDP_per_cap_focus_0_FocusRegionEU, float(30000))
setparameter(m, :SLRDamages, :impmax_maxSLRforadaptpolicySLR, ones(8))
setparameter(m, :SLRDamages, :cons_per_cap_AfterCosts, zeroes(10, 8))


##running Model
run(m)