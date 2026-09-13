"""Run with Python + lupa: python -m unittest discover -s tests -v."""
import json
from pathlib import Path
import unittest

from lupa.lua54 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
LUA = ROOT / 'src/Mods/MIR/ScriptExtender/Lua'


class PowerTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('''
            stats = {}
            MIR = {Config={powerEnabled=true, powerOverrides={}}, CurrentAct=1}
            Ext = {Stats={Get=function(n) return stats[n] end},
                RegisterConsoleCommand=function() end}
            Osi = {GetHostCharacter=function() return 'host' end,
                GetLevel=function() return 5 end}
            function assess(boosts, rarity)
                stats.item = {Boosts=boosts}
                return MIR.Power.Assess({stat='item',template='uuid',category='weapon',rarity=rarity or 'Common'})
            end
        ''')
        self.lua.execute((LUA / 'Server/Power.lua').read_text(encoding='utf-8'))

    def test_common_extra_action_is_endgame(self):
        p = self.lua.eval("assess('ActionResource(ActionPoint,1,0)')")
        self.assertEqual((p.minLevel, p.minAct), (10, 3))

    def test_damage_and_enchantment_add(self):
        p = self.lua.eval("assess('WeaponEnchantment(1);DamageBonus(1d4,Fire)')")
        self.assertEqual(p.score, 6.75)

    def test_rarity_is_floor(self):
        self.assertEqual(self.lua.eval("assess('', 'Legendary').tier"), 5)

    def test_unknown_and_nested_effects_are_flagged(self):
        for expression in ['CustomEffect(1)', 'IF(HasStatus(X)):AC(5)', 'DamageBonus(LevelMapValue(X),Fire)']:
            p = self.lua.globals().assess(expression)
            self.assertEqual(p.confidence, 'low')
            self.assertGreaterEqual(p.minLevel, 8)

    def test_inheritance_and_passive_cycle(self):
        self.lua.execute('''
            stats.parent={Boosts='AC(2)'}
            stats.child={Using='parent',PassivesOnEquip='p;p'}
            stats.p={Boosts='SpellSaveDC(1)',Passives='p'}
            result=MIR.Power.Assess({stat='child',template='id',category='ring',rarity='Common'})
        ''')
        self.assertEqual(self.lua.globals().result.score, 9)

    def test_override_replaces_inherited_boost(self):
        self.lua.execute("stats.parent={Boosts='AC(5)'}; stats.child={Using='parent',Boosts='AC(1)'}")
        self.assertEqual(self.lua.eval("MIR.Power.Assess({stat='child',category='ring'}).score"), 3)

    def test_spell_reference_and_missing_reference(self):
        self.lua.execute("stats.Fireball={Level=3}")
        self.assertGreaterEqual(self.lua.eval("assess('UnlockSpell(Fireball)').score"), 12)
        self.assertEqual(self.lua.eval("assess('UnlockSpell(Missing)').confidence"), 'low')

    def test_gate_requires_both_act_and_level(self):
        self.lua.execute("entry={power=assess('ActionResource(ActionPoint,1,0)')}")
        for context in ['{level=12,act=1}', '{level=5,act=3}', '{}', 'nil']:
            self.assertFalse(self.lua.eval(f'MIR.Power.Allowed(entry,{context})'))
        self.assertTrue(self.lua.eval('MIR.Power.Allowed(entry,{level=10,act=3})'))

    def test_strict_unknown_disable_exempt_and_manual_override(self):
        self.lua.execute("entry={power=assess('Unknown(1)')}; MIR.Config.powerStrictUnknown=true")
        self.assertFalse(self.lua.eval('MIR.Power.Allowed(entry,{level=12,act=3})'))
        self.lua.execute('MIR.Config.powerEnabled=false')
        self.assertTrue(self.lua.eval('MIR.Power.Allowed(entry,{})'))
        self.lua.execute('MIR.Config.powerEnabled=true')
        self.assertTrue(self.lua.eval("MIR.Power.Allowed({power=MIR.Power.Assess({category='scroll'})},{})"))
        self.lua.execute("MIR.Config.powerOverrides.uuid={minLevel=4,minAct=1,exclude=true}")
        p = self.lua.eval("assess('')")
        self.assertEqual(p.minLevel, 4)
        self.assertTrue(p.excluded)

    def test_real_draw_pipeline_never_selects_blocked_item(self):
        main = (LUA / 'Server/Main.lua').read_text(encoding='utf-8')
        # Exercise the production selector and every per-entry selection stage,
        # with only unrelated category settings and campaign APIs stubbed.
        helpers = main[main.index('local function entryAllowedFor'):main.index('-- v1.0.1 (Alan', main.index('local function entryAllowedFor'))]
        helpers += main[main.index('local function sliceHasAllowed'):main.index('-- v1.0: the per-category include veto')]
        draw = main[main.index('local function weightedPick'):main.index('-- v1.0: when a roll succeeds')]
        self.lua.execute('''
            MIR.TierName={'Common','Uncommon','Rare','VeryRare','Legendary'}
            MIR.Config.categoryWeights={weapon=1}
            MIR.Config.rarityWindow={enabled=false}
            function categoryEnabled() return true end
            function tierRangeFor(_,lo,hi) return lo,hi end
            function effectiveRarityWindow() return 1,5 end
            weak={stat='weak',managed=true,power=assess('WeaponEnchantment(1)')}
            strong={stat='strong',managed=true,power=assess('ActionResource(ActionPoint,1,0)')}
            MIR.Catalog={pool={weapon={Common={weak,strong}}}}
        ''' + helpers + draw + '\nDrawForTest=drawOne')
        for _ in range(100):
            self.assertEqual(self.lua.eval("DrawForTest({class='treasure'}).stat"), 'weak')
        self.lua.execute('MIR.Catalog.pool.weapon.Common={strong}')
        self.assertEqual(self.lua.eval("DrawForTest({class='treasure'})"), (None, 'power'))
        self.lua.execute('MIR.Config.powerEnabled=false')
        self.assertEqual(self.lua.eval("DrawForTest({class='treasure'}).stat"), 'strong')

    def test_all_lua_syntax_and_blueprint_ids(self):
        compile_lua = self.lua.eval('function(s) local f,e=load(s); return f~=nil,e end')
        for path in LUA.rglob('*.lua'):
            ok, error = compile_lua(path.read_text(encoding='utf-8-sig'))
            self.assertTrue(ok, f'{path}: {error}')
        blueprint = json.loads((ROOT / 'src/Mods/MIR/MCM_blueprint.json').read_text(encoding='utf-8'))
        ids = [s['Id'] for tab in blueprint['Tabs'] for s in tab.get('Settings', [])]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertIn('mir_power_enabled', ids)
        self.assertIn('mir_power_strict', ids)


if __name__ == '__main__':
    unittest.main()
