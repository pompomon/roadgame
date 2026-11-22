"""The veto on a wide area, straights of 2-12 tiles, and the margin of 1 on the pier road
(SLIDE_PLAN.md X4a, X16, §6.5), with slide_model.py: 400 seeds each."""
import sys
sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__)))
import slide_model as m
m.AREAS["wide"] = dict(lo=2, hi=12, cross=0.3, side=0.2, decoy=0.15)
every = {a: 1.0 for a in m.AREAS}
print("wide back, no veto", m.run(m.PIER, 400, every, 1.0, veto=False, endless_area="wide"))
print("wide back, veto   ", m.run(m.PIER, 400, every, 1.0, veto=True, endless_area="wide"))
print("wide 0.5, veto    ", m.run(m.PIER, 400, every, 0.5, veto=True, endless_area="wide"))
print("wide fwd, no veto ", m.run(m.PIER, 400, every, 0.0, veto=False, endless_area="wide"))
m.MARGIN = 1
print("margin 1, pier, every, back, no veto", m.run(m.PIER, 400, every, 1.0, veto=False))
print("margin 1, pier, every, back, veto   ", m.run(m.PIER, 400, every, 1.0, veto=True))
