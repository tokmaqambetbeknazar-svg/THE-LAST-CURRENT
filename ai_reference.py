"""Reproducible Python reference for THE LAST CURRENT's AI Fundamentals algorithms.

Run: python ai_reference.py
No external packages required. Input values are labeled assumptions, not real sensor data.
"""
from __future__ import annotations
import heapq
import math
from dataclasses import dataclass
from typing import Dict, Set, Tuple

Position = Tuple[int, int]
GRID_SIZE = 19
CELL_SIZE = 14.0
ORIGIN = -126.0
SENSITIVITY = 0.84
FALSE_ALARM_RATE = 0.17

ISLANDS = [(-94, -86), (94, -86), (94, 86), (-94, 86)]
DOCKS = [(-70, -60), (70, -60), (70, 60), (-70, 60)]
REEFS = [((-2, -18), 15.0), ((9, 31), 16.0), ((-38, 16), 11.0), ((38, -5), 13.0), ((-5, -81), 10.0), ((7, 91), 9.0)]
STORMS = [(26, 15), (-30, 46)]


def posterior(prior: float, alert: bool, sensitivity: float=SENSITIVITY,
              false_alarm: float=FALSE_ALARM_RATE) -> dict:
    """P(danger | signal) with an imperfect binary sensor."""
    if not (0 <= prior <= 1 and 0 <= sensitivity <= 1 and 0 <= false_alarm <= 1):
        raise ValueError('Probabilities must be in [0,1].')
    ld = sensitivity if alert else 1 - sensitivity
    ls = false_alarm if alert else 1 - false_alarm
    numerator = ld * prior
    denominator = numerator + ls * (1 - prior)
    if denominator <= 0:
        raise ValueError('Impossible observation under this model.')
    return dict(prior=prior, signal='ALERT' if alert else 'CLEAR',
                likelihood_danger=ld, likelihood_safe=ls,
                numerator=numerator, denominator=denominator,
                posterior=numerator/denominator)


def mdp_one_step(risk: float, supplies: float=70.0) -> dict:
    """2-state, 2-action one-step MDP expected reward comparison."""
    safe_reward = 11.0 - (4.0 if supplies < 20 else 0.0)
    danger_reward = -23.0
    wait_reward = -3.0
    # Both actions share this one-decision weather transition matrix.
    transition = ((1.0, 0.0), (0.0, 1.0))
    belief = (1.0 - risk, risk)
    next_calm, next_danger = (sum(belief[i] * transition[i][j] for i in range(2))
                              for j in range(2))
    sail = next_calm * safe_reward + next_danger * danger_reward
    return dict(risk=risk, expected_sail=sail, expected_anchor=wait_reward,
                action='SAIL' if sail >= wait_reward else 'ANCHOR')


def h(a: Position, b: Position):
    return abs(a[0]-b[0])+abs(a[1]-b[1])


def astar(start: Position, goal: Position, blocked: Set[Position],
          costs: Dict[Position, float], size: int=GRID_SIZE) -> dict:
    """Weighted four-neighbor A* with admissible Manhattan heuristic."""
    frontier=[(float(h(start,goal)),0.0,start)]
    g={start:0.0}
    parent={}
    expanded=set()
    visits=[]
    while frontier:
        _, old_g, cur=heapq.heappop(frontier)
        if cur in expanded or old_g > g[cur]+1e-8:
            continue
        expanded.add(cur)
        visits.append(cur)
        if cur==goal:
            route=[cur]
            while cur!=start:
                cur=parent[cur]
                route.append(cur)
            return dict(reachable=True,path=list(reversed(route)),cost=g[goal],
                        expanded=len(expanded),visited=visits)
        for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)):
            nxt=(cur[0]+dx,cur[1]+dy)
            if not(0<=nxt[0]<size and 0<=nxt[1]<size) or nxt in blocked:
                continue
            candidate=g[cur]+max(1.0,costs.get(nxt,1.0))
            if candidate+1e-8<g.get(nxt,math.inf):
                g[nxt]=candidate
                parent[nxt]=cur
                heapq.heappush(frontier,(candidate+h(nxt,goal),candidate,nxt))
    return dict(reachable=False,path=[],cost=math.inf,expanded=len(expanded),visited=visits)


def to_cell(world: Tuple[float,float]) -> Position:
    return tuple(max(0,min(GRID_SIZE-1,round((v-ORIGIN)/CELL_SIZE))) for v in world)


def cell_world(cell: Position)->Position:
    return (ORIGIN+cell[0]*CELL_SIZE,ORIGIN+cell[1]*CELL_SIZE)


def game_map(start: Position, goal: Position, beliefs=(.3,.3)):
    blocked=set()
    costs={}
    reefs=[(p,r+5.0) for p,r in REEFS] + [(p,31.0) for p in ISLANDS]
    for x in range(GRID_SIZE):
        for y in range(GRID_SIZE):
            cell=(x,y)
            pos=cell_world(cell)
            if any(math.dist(pos,center)<radius for center,radius in reefs):
                blocked.add(cell)
            for storm, belief in zip(STORMS,beliefs):
                distance=math.dist(pos,storm)
                if distance < 46:
                    costs[cell]=costs.get(cell,1.0)+(46-distance)/46*7*belief
    s,g=to_cell(start),to_cell(goal)
    blocked.discard(s); blocked.discard(g)
    return s,g,blocked,costs


def demo() -> None:
    print('THE LAST CURRENT — reproducible academic demo (hypothetical data)')
    print('1) Bayes: prior=0.30, sensitivity=0.84, false-positive=0.17')
    alert=posterior(0.30,True)
    clear=posterior(0.30,False)
    print('   ALERT: numerator={numerator:.4f}, denominator={denominator:.4f}, posterior={posterior:.4%}'.format(**alert))
    print('   CLEAR: numerator={numerator:.4f}, denominator={denominator:.4f}, posterior={posterior:.4%}'.format(**clear))
    print('2) A*: start=Haven, destination=Coral Bazaar')
    for label, risk in [('prior',.3),('alert posterior',alert['posterior'])]:
        s,g,w,c=game_map(DOCKS[0],DOCKS[1],(risk,.3))
        route=astar(s,g,w,c)
        print('   {} -> {} steps, cost {:.2f}, expanded {} cells, reachable {}'.format(label, len(route['path'])-1,route['cost'],route['expanded'],route['reachable']))
    # A second pair of ports crosses the storm belt, so the risk-weighted route changes.
    s,g,w,c=game_map(DOCKS[2],DOCKS[3],(.05,.05))
    low=astar(s,g,w,c)
    s,g,w,c=game_map(DOCKS[2],DOCKS[3],(.95,.95))
    high=astar(s,g,w,c)
    print('   Ember->Whisper: low risk cost {:.2f}, high risk cost {:.2f}, route changed {}'.format(low['cost'], high['cost'], low['path'] != high['path']))
    print('3) One-step MDP: R(sail|calm)=11; R(sail|storm)=-23; R(anchor)=-3')
    for name,p in [('clear',clear['posterior']),('alert',alert['posterior'])]:
        mdp=mdp_one_step(p)
        print('   {} risk {:.2%}: E[sail]={:.3f}; E[anchor]={:.3f}; choose {}'.format(name,p,mdp['expected_sail'],mdp['expected_anchor'],mdp['action']))

if __name__=='__main__':
    demo()
