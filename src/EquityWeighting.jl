using Mimi
include("load_parameters.jl")

@defcomp EquityWeighting begin
    region = Index()

    # Basic information
    y_year = Parameter(index=[time], unit="year")
    y_year_0 = Parameter(unit="year")

    # Impacts across all gases
    tc_totalcosts_co2 = Parameter(index=[time, region], unit="\$million")
    tc_totalcosts_ch4 = Parameter(index=[time, region], unit="\$million")
    tc_totalcosts_n2o = Parameter(index=[time, region], unit="\$million")
    tc_totalcosts_linear = Parameter(index=[time, region], unit="\$million")
    pop_population = Parameter(index=[time, region], unit="million person")

    tct_totalcosts_total = Variable(index=[time, region], unit="\$million")
    tct_percap_totalcosts_total = Variable(index=[time, region], unit="\$/person")

    # Consumption calculations
    gdp = Parameter(index=[time, region], unit="\$million")
    save_savingsrate = Parameter(unit="%")
    cons_consumption = Variable(index=[time, region], unit="\$million")

    cons_percap_consumption = Variable(index=[time, region], unit="\$") # Called "CONS_PER_CAP"
    # NOTE: Assumes that CONS_PER_CAP_FOCUS_0 = CONS_PER_CAP[1, 1]

    cons_percap_aftercosts = Variable(index=[time, region], unit="\$")

    # Calculation of weighted costs
    emuc_utilityconvexity = Parameter(unit="none")

    wtct_percap_weightedcosts = Variable(index=[time, region], unit="\$")

    # Calculation of adaptation costs
    ac_adaptationcosts_economic = Parameter(index=[time, region], unit="\$million")
    ac_adaptationcosts_noneconomic = Parameter(index=[time, region], unit="\$million")
    ac_adaptationcosts_sealevelrise = Parameter(index=[time, region], unit="\$million")

    act_adaptationcosts_total = Variable(index=[time, region], unit="\$million")
    act_percap_adaptationcosts = Variable(index=[time, region], unit="\$")

    eact_percap_weightedadaptationcosts = Variable(index=[time, region], unit="\$")
    wact_percap_partiallyweighted = Variable(index=[time, region], unit="\$")
    wact_partiallyweighted = Variable(index=[time, region], unit="\$million")

    # Amount of equity weighting variable (0, (0, 1), or 1)
    equity_proportion = Parameter(unit="fraction")

    pct_percap_partiallyweighted = Variable(index=[time, region], unit="\$/person")
    pct_partiallyweighted = Variable(index=[time, region], unit="\$million")
    pct_g_partiallyweighted_global = Variable(index=[time], unit="\$million")

    # Discount rates
    ptp_timepreference = Parameter(unit="%/year")
    grw_gdpgrowth = Parameter(index=[time, region], unit="%/year")
    popgrw_populationgrowth = Parameter(index=[time, region], unit="%/year")

    dr_discountrate = Variable(index=[time, region], unit="%/year")
    yp_yearsperiod = Variable(index=[time], unit="year") # defined differently from yagg
    dfc_consumptiondiscountrate = Variable(index=[time, region], unit="1/year")

    df_utilitydiscountrate = Variable(index=[time], unit="fraction")

    # Discounted costs
    pcdt_partiallyweighted_discounted = Variable(index=[time, region], unit="\$million")
    pcdt_g_partiallyweighted_discountedglobal = Variable(index=[time], unit="\$million")

    pcdat_partiallyweighted_discountedaggregated = Variable(index=[time, region], unit="\$million")
    tpc_totalaggregatedcosts = Variable(unit="\$million")

    wacdt_partiallyweighted_discounted = Variable(index=[time, region], unit="\$million")

    # Equity weighted impact totals
    isat_percap_dis = Parameter(index=[time, region], unit="\$")
    rcons_percap_dis = Variable(index=[time, region], unit="\$")

    wit_equityweightedimpact = Variable(index=[time, region], unit="\$")
    widt_equityweightedimpact_discounted = Variable(index=[time, region], unit="\$million")

    ylo_periodstart = Variable(index=[time], unit="year")
    yhi_periodend = Variable(index=[time], unit="year")
    yagg_periodspan = Variable(index=[time], unit="year")

    addt_equityweightedimpact_discountedaggregated = Variable(index=[time, region], unit="\$million")
    addt_gt_equityweightedimpact_discountedglobal = Variable(unit="\$million")

    civvalue_civilizationvalue = Parameter(unit="\$million") # Called "CIV_VALUE"
    td_totaldiscountedimpacts = Variable(unit="\$million")

    aact_equityweightedadaptation_discountedaggregated = Variable(index=[time, region], unit="\$million")
    tac_totaladaptationcosts = Variable(unit="\$million")

    # Final result: total effect of climate change
    te_totaleffect = Variable(unit="\$million")
end

function run_timestep(s::EquityWeighting, tt::Int64)
    v = s.Variables
    p = s.Parameters
    d = s.Dimensions

    if tt == 1
        v.tpc_totalaggregatedcosts = 0
        v.addt_gt_equityweightedimpact_discountedglobal = 0
        v.tac_totaladaptationcosts = 0
        v.te_totaleffect = 0
    end

    v.df_utilitydiscountrate[tt] = (1 + p.ptp_timepreference / 100)^(-(p.y_year[tt] - p.y_year_0))

    # Analysis period ranges, from Hope (2006)
    if tt == 1
        v.ylo_periodstart[tt] = p.y_year_0
    else
        v.ylo_periodstart[tt] = (p.y_year[tt] + p.y_year[tt-1]) / 2
    end

    if tt == length(p.y_year)
        v.yhi_periodend[tt] = p.y_year[tt]
    else
        v.yhi_periodend[tt] = (p.y_year[tt] + p.y_year[tt+1]) / 2
    end

    v.yagg_periodspan[tt] = v.yhi_periodend[tt] - v.ylo_periodstart[tt]

    for rr in d.region
        ## Consumption calculations
        v.cons_consumption[tt, rr] = p.gdp[tt, rr] * (1 - p.save_savingsrate / 100)
        v.cons_percap_consumption[tt, rr] = v.cons_consumption[tt, rr] / p.pop_population[tt, rr]
        # Check wth Chris Hope that CONS_PER_CAP in documentation should be CONS_PER_CAP(i,r)

        ## Gas Costs Accounting

        # Sum over all gases (Page 23 of Hope 2009)
        v.tct_totalcosts_total[tt, rr] = p.tc_totalcosts_co2[tt, rr] + p.tc_totalcosts_ch4[tt, rr] + p.tc_totalcosts_n2o[tt, rr] + p.tc_totalcosts_linear[tt, rr]
        v.tct_percap_totalcosts_total[tt, rr] = v.tct_totalcosts_total[tt, rr] / p.pop_population[tt, rr]

        # Weighted costs (Page 23 of Hope 2009)
        v.wtct_percap_weightedcosts[tt, rr] = ((v.cons_percap_consumption[1, 1]^p.emuc_utilityconvexity) / (1 - p.emuc_utilityconvexity)) * (v.cons_percap_consumption[tt, rr]^(1 - p.emuc_utilityconvexity) - (v.cons_percap_consumption[tt, rr] - v.tct_percap_totalcosts_total[tt, rr])^(1 - p.emuc_utilityconvexity))

        ## Adaptation Costs Accounting
        v.act_adaptationcosts_total[tt, rr] = p.ac_adaptationcosts_economic[tt, rr] + p.ac_adaptationcosts_noneconomic[tt, rr] + p.ac_adaptationcosts_sealevelrise[tt, rr]
        v.act_percap_adaptationcosts[tt, rr] = v.act_adaptationcosts_total[tt, rr] / p.pop_population[tt, rr]

        # Add these into consumption
        v.cons_percap_aftercosts[tt, rr] = v.cons_percap_consumption[tt, rr] - v.tct_percap_totalcosts_total[tt, rr] - v.act_percap_adaptationcosts[tt, rr] # Check with Chris Hope: add or subtract adaptationcosts?
        v.rcons_percap_dis[tt, rr] = v.cons_percap_consumption[tt, rr] - p.isat_percap_dis[tt, rr]

        v.eact_percap_weightedadaptationcosts[tt, rr] = ((v.cons_percap_consumption[1, 1]^p.emuc_utilityconvexity) / (1 - p.emuc_utilityconvexity)) * (v.cons_percap_consumption[tt, rr]^(1 - p.emuc_utilityconvexity) - (v.cons_percap_consumption[tt, rr] - v.act_percap_adaptationcosts[tt, rr])^(1 - p.emuc_utilityconvexity))

        # Do partial weighting
        if p.equity_proportion == 0
            v.pct_percap_partiallyweighted[tt, rr] = v.tct_percap_totalcosts_total[tt, rr]
            v.wact_percap_partiallyweighted[tt, rr] = v.act_percap_adaptationcosts[tt, rr]
        else
            v.pct_percap_partiallyweighted[tt, rr] = (1 - p.equity_proportion) * v.tct_percap_totalcosts_total[tt, rr] + p.equity_proportion * v.wtct_percap_weightedcosts[tt, rr]
            v.wact_percap_partiallyweighted[tt, rr] = (1 - p.equity_proportion) * v.act_percap_adaptationcosts[tt, rr] + p.equity_proportion * v.eact_percap_weightedadaptationcosts[tt, rr]
        end

        v.pct_partiallyweighted[tt, rr] = v.pct_percap_partiallyweighted[tt, rr] * p.pop_population[tt, rr]
        v.wact_partiallyweighted[tt, rr] = v.wact_percap_partiallyweighted[tt, rr] * p.pop_population[tt, rr]

        # Discount rate calculations
        v.dr_discountrate[tt, rr] = p.ptp_timepreference + p.emuc_utilityconvexity * (p.grw_gdpgrowth[tt, rr] - p.popgrw_populationgrowth[tt, rr])
        if tt == 1
            v.yp_yearsperiod[1] = p.y_year[1] - p.y_year_0
        else
            v.yp_yearsperiod[tt] = p.y_year[tt] - p.y_year[tt-1]
        end

        if tt == 1
            v.dfc_consumptiondiscountrate[1, rr] = (1 + v.dr_discountrate[1, rr] / 100)^(-v.yp_yearsperiod[1])
        else
            v.dfc_consumptiondiscountrate[tt, rr] = v.dfc_consumptiondiscountrate[tt - 1, rr] * (1 + v.dr_discountrate[tt, rr] / 100)^(-v.yp_yearsperiod[tt])
        end

        # Discounted costs
        if p.equity_proportion == 0
            v.pcdt_partiallyweighted_discounted[tt, rr] = v.pct_partiallyweighted[tt, rr] * v.dfc_consumptiondiscountrate[tt, rr]
            v.wacdt_partiallyweighted_discounted[tt, rr] = v.act_adaptationcosts_total[tt, rr] * v.dfc_consumptiondiscountrate[tt, rr]
        else
            v.pcdt_partiallyweighted_discounted[tt, rr] = v.pct_partiallyweighted[tt, rr] * v.df_utilitydiscountrate[tt]
            v.wacdt_partiallyweighted_discounted[tt, rr] = v.wact_partiallyweighted[tt, rr] * v.df_utilitydiscountrate[tt]
        end

        v.pcdat_partiallyweighted_discountedaggregated[tt, rr] = v.pcdt_partiallyweighted_discounted[tt, rr] * v.yagg_periodspan[rr]

        ## Equity weighted impacts (end of page 28, Hope 2009)
        v.wit_equityweightedimpact[tt, rr] = ((v.cons_percap_consumption[1, 1]^p.emuc_utilityconvexity) / (1 - p.emuc_utilityconvexity)) * (v.cons_percap_aftercosts[tt, rr]^(1 - p.emuc_utilityconvexity) - v.rcons_percap_dis[tt, rr]^(1 - p.emuc_utilityconvexity)) * p.pop_population[tt, rr]

        v.widt_equityweightedimpact_discounted[tt, rr] = v.wit_equityweightedimpact[tt, rr] * v.df_utilitydiscountrate[tt]

        v.addt_equityweightedimpact_discountedaggregated[tt, rr] = v.widt_equityweightedimpact_discounted[tt, rr] * v.yagg_periodspan[tt]
        v.aact_equityweightedadaptation_discountedaggregated[tt, rr] = v.wacdt_partiallyweighted_discounted[tt, rr] * v.yagg_periodspan[tt]
    end

    v.pct_g_partiallyweighted_global[tt] = sum(v.pct_partiallyweighted[tt, :])
    v.pcdt_g_partiallyweighted_discountedglobal[tt] = sum(v.pcdt_partiallyweighted_discounted[tt, :])
    v.tpc_totalaggregatedcosts = v.tpc_totalaggregatedcosts + sum(v.pcdat_partiallyweighted_discountedaggregated[tt, :])

    v.addt_gt_equityweightedimpact_discountedglobal = v.addt_gt_equityweightedimpact_discountedglobal + sum(v.addt_equityweightedimpact_discountedaggregated[tt, :])

    v.tac_totaladaptationcosts = v.tac_totaladaptationcosts + sum(v.aact_equityweightedadaptation_discountedaggregated[tt, :])

    v.td_totaldiscountedimpacts = min(v.addt_gt_equityweightedimpact_discountedglobal, p.civvalue_civilizationvalue)

    # Total effect of climate change
    v.te_totaleffect = min(v.td_totaldiscountedimpacts + v.tpc_totalaggregatedcosts + v.tac_totaladaptationcosts, p.civvalue_civilizationvalue)
end

function addequityweighting(model::Model)
    equityweighting = addcomponent(model, EquityWeighting)

    equityweighting[:ptp_timepreference] = 1.033333 # <0.1,1, 2>
    equityweighting[:save_savingsrate] = 15.00
    equityweighting[:equity_proportion] = 1.0
    equityweighting[:emuc_utilityconvexity] = 1.166667
    equityweighting[:civvalue_civilizationvalue] = 5.3e10

    return equityweighting
end