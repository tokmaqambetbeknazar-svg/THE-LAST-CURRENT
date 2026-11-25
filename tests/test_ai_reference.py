import math
import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import ai_reference as ai

class TestAI(unittest.TestCase):
    def test_bayes_positive(self):
        expected=.84*.30/(.84*.30+.17*.70)
        self.assertAlmostEqual(ai.posterior(.30,True)['posterior'],expected)
    def test_bayes_clear(self):
        self.assertLess(ai.posterior(.3,False)['posterior'],.3)
    def test_bayes_alert(self):
        self.assertGreater(ai.posterior(.3,True)['posterior'],.3)
    def test_bayes_invalid(self):
        with self.assertRaises(ValueError):ai.posterior(-0.1,True)
    def test_bayes_extremes(self):
        self.assertEqual(ai.posterior(0.0,True)['posterior'],0.0)
        self.assertEqual(ai.posterior(1.0,True)['posterior'],1.0)
    def test_mdp_calm(self):
        self.assertEqual(ai.mdp_one_step(.1)['action'],'SAIL')
    def test_mdp_danger(self):
        self.assertEqual(ai.mdp_one_step(.8)['action'],'ANCHOR')
    def test_mdp_rewards(self):
        self.assertAlmostEqual(ai.mdp_one_step(.5)['expected_sail'],-6.0)
    def test_mdp_low_supplies(self):
        self.assertLess(ai.mdp_one_step(.2,10)['expected_sail'],ai.mdp_one_step(.2,70)['expected_sail'])
    def test_a_star_empty_map(self):
        result=ai.astar((0,0),(4,4),set(),{},5)
        self.assertTrue(result['reachable']); self.assertEqual(len(result['path'])-1,8)
    def test_a_star_blocked(self):
        result=ai.astar((0,0),(2,2),{(1,0),(0,1)},{},3)
        self.assertFalse(result['reachable'])
    def test_a_star_expensive_shortcut(self):
        result=ai.astar((0,0),(4,0),set(),{(2,0):100.0},5)
        self.assertTrue(result['reachable']);self.assertEqual(result['cost'],6.0)
    def test_a_star_route_cells(self):
        res=ai.astar((0,0),(3,3),{(1,0)},{},4)
        self.assertEqual(res['path'][0],(0,0)); self.assertEqual(res['path'][-1],(3,3))
        for a,b in zip(res['path'],res['path'][1:]):self.assertEqual(ai.h(a,b),1)
    def test_game_all_port_pairs_reachable(self):
        for a in range(4):
            for b in range(4):
                if a==b:continue
                start,goal,w,c=ai.game_map(ai.DOCKS[a],ai.DOCKS[b],(.3,.3))
                res=ai.astar(start,goal,w,c)
                self.assertTrue(res['reachable'],(a,b))
    def test_storm_risk_changes_cost(self):
        s,g,w,c=ai.game_map(ai.DOCKS[0],ai.DOCKS[2],(.1,.1))
        a=ai.astar(s,g,w,c)
        s,g,w,c=ai.game_map(ai.DOCKS[0],ai.DOCKS[2],(.9,.9))
        b=ai.astar(s,g,w,c)
        self.assertLessEqual(a['cost'],b['cost']+1e-8)

if __name__=='__main__':unittest.main()
