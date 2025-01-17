#!/usr/bin/python

import Scenario

def count(roles,agents,proc):
    """
    Count the scenarios generated by the algorithm
    roles:  number of roles
    agents: number of agents (excluding the intruder)
    proc:   number of processes (or runs or threads or ...)
    """
    ss = Scenario.ScenarioSet(rolecount=roles,runcount=proc,agentcount=agents)
    return len(ss.list)

def show(roles,agents,proc):
    if agents > 2:
        raise Exception, "Sorry, list algorithm only works for 1 or 2 agents"
    n = count(roles,agents,proc)
    pp = roles*agents*pow(agents+1,roles-1)
    s = "roles %i\tproc %i\tagents %i\t%i\tPP(%i,%i) = %i" % (roles,proc,agents,n,roles,agents,pp)
    
    if agents == 2:
        cc = Scenario.countscenarios(roles,proc)
        s += "\t(Cas' formula: %i)" % (cc)
    print s

def main():
    for proc in range(1,8):
        for roles in range(1,4):
            for agents in range(1,3):
                # And display
                show(roles,agents,proc)

if __name__ == "__main__":
    main()


