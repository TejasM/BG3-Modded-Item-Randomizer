from pathlib import Path
import unittest
from lupa.lua54 import LuaRuntime

LUA = Path(__file__).resolve().parents[1] / 'src/Mods/MIR/ScriptExtender/Lua'


class AccessTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('''
            ModuleUUID='mod'; vars={}; listeners={}; commands={}
            owner={gear='vendor'}; templates={gear='template',vendor='vendorRoot',camp='campRoot'}
            roots={campRoot={Name='CONT_PlayerCampChest_A'}}
            entities={gear=true,vendor=true,camp=true,vault=true}
            entry={stat='gear',template='template',managed=true,base=false,power={minLevel=8,minAct=2}}
            level=3; act=1; failMove=false; moves=0
            MIR={Config={enabled=true,powerEnabled=true,suppressConvenience=true,gateMerchants=true},
                Catalog={built=true,byTemplate={template=entry}},Log=function() end,
                MarkConsoleOverride=function() end,Power={}}
            MIR.Power.Context=function() return {level=level,act=act} end
            MIR.Power.Allowed=function(e,c)
                return not MIR.Config.powerEnabled or (c.level>=e.power.minLevel and c.act>=e.power.minAct)
            end
            Ext={Vars={GetModVariables=function() return vars end},
                Entity={Get=function(i) return entities[i] end},
                Template={GetTemplate=function(i) return nil end,GetRootTemplate=function(i) return roots[i] end},
                Osiris={RegisterListener=function(n,a,t,f) listeners[n]=f end},
                RegisterConsoleCommand=function(n,f) commands[n]=f end}
            Osi={GetStackAmount=function() return 1,1 end, GetTemplate=function(i) return templates[i] end,
                IsInInventoryOf=function(i,h) return owner[i]==h and 1 or 0 end,
                GetPosition=function() return 0,0,0 end,
                CreateAt=function() return 'vault' end,
                IsContainer=function() return 1 end,
                SetOnStage=function() end,
                GetInventoryOwner=function(i) return owner[i] end,
                IsPlayer=function(i) return i=='player' and 1 or 0 end,
                ToInventory=function(i,h)
                    if failMove then error('move failed') end
                    moves=moves+1; owner[i]=h
                    if listeners.AddedTo then listeners.AddedTo(i,h,'Regular') end
                end,
                IterateInventory=function(h,event,done)
                    for i,o in pairs(owner) do if o==h then listeners.EntityEvent(i,event) end end
                    listeners.EntityEvent(h,done)
                end}
        ''')
        self.lua.execute((LUA / 'Server/Access.lua').read_text(encoding='utf-8'))

    def test_generated_merchant_stock_is_held_and_restored_same_instance(self):
        self.lua.execute("listeners.AddedTo('gear','vendor','TradeTreasure')")
        self.assertEqual(self.lua.eval('owner.gear'), 'vault')
        self.lua.execute("level=8; act=2; MIR.Access.Scan('vendor','merchant')")
        self.assertEqual(self.lua.eval('owner.gear'), 'vendor')
        self.assertIsNone(self.lua.eval('vars.AccessState.held.gear'))
        self.assertEqual(self.lua.eval('moves'), 2)

    def test_generated_camp_stock_is_suppressed_even_at_endgame(self):
        self.lua.execute("owner.gear='camp'; level=12; act=3; listeners.AddedTo('gear','camp','Treasure')")
        self.assertEqual(self.lua.eval('owner.gear'), 'vault')
        self.lua.execute("MIR.Access.Scan('camp','convenience')")
        self.assertEqual(self.lua.eval('owner.gear'), 'vault')

    def test_player_deposit_and_sale_are_protected(self):
        self.lua.execute("listeners.AddedTo('gear','player','Regular'); owner.gear='camp'; listeners.AddedTo('gear','camp','Regular')")
        self.assertEqual(self.lua.eval('owner.gear'), 'camp')
        self.lua.execute("owner.gear='vendor'; listeners.AddedTo('gear','vendor','Regular'); MIR.Access.Scan('vendor','merchant')")
        self.assertEqual(self.lua.eval('owner.gear'), 'vendor')

    def test_ambiguous_existing_and_script_stock_left_alone(self):
        self.lua.execute("MIR.Access.Scan('vendor','merchant'); listeners.AddedTo('gear','vendor','Regular')")
        self.assertEqual(self.lua.eval('moves'), 0)

    def test_vanilla_authored_and_cosmetics_untouched(self):
        for condition in ['entry.base=true', 'entry.managed=false', 'entry.power.exempt=true']:
            self.setUp()
            self.lua.execute(condition + "; listeners.AddedTo('gear','vendor','TradeTreasure')")
            self.assertEqual(self.lua.eval('moves'), 0)

    def test_toggle_off_restores(self):
        self.lua.execute("listeners.AddedTo('gear','vendor','TradeTreasure'); MIR.Config.gateMerchants=false; MIR.Access.Scan('vendor','merchant')")
        self.assertEqual(self.lua.eval('owner.gear'), 'vendor')

    def test_no_double_hold_on_repeated_events(self):
        self.lua.execute("listeners.AddedTo('gear','vendor','TradeTreasure'); listeners.AddedTo('gear','vault','Regular')")
        self.assertEqual(self.lua.eval('moves'), 1)

    def test_state_survives_module_reload(self):
        self.lua.execute("listeners.AddedTo('gear','vendor','TradeTreasure')")
        self.lua.execute((LUA / 'Server/Access.lua').read_text(encoding='utf-8'))
        self.lua.execute("level=10; act=3; MIR.Access.Release('vendor')")
        self.assertEqual(self.lua.eval('owner.gear'), 'vendor')

    def test_failed_hold_keeps_recoverable_intent(self):
        self.lua.execute("failMove=true; listeners.AddedTo('gear','vendor','TradeTreasure')")
        self.assertIsNotNone(self.lua.eval('vars.AccessState.held.gear'))
        self.assertEqual(self.lua.eval('owner.gear'), 'vendor')
        self.lua.execute("failMove=false; MIR.Access.Release('vendor')")
        self.assertEqual(self.lua.eval('owner.gear'), 'vault')

    def test_failed_restore_keeps_record(self):
        self.lua.execute("listeners.AddedTo('gear','vendor','TradeTreasure'); failMove=true; level=12; act=3; MIR.Access.Release('vendor')")
        self.assertIsNotNone(self.lua.eval('vars.AccessState.held.gear'))
        self.assertEqual(self.lua.eval('owner.gear'), 'vault')

    def test_unloaded_holder_not_discarded(self):
        self.lua.execute("listeners.AddedTo('gear','vendor','TradeTreasure'); entities.vendor=nil; MIR.Access.Release(nil,true)")
        self.assertIsNotNone(self.lua.eval('vars.AccessState.held.gear'))

    def test_restore_command_disables_gates_and_preserves_item(self):
        self.lua.execute("listeners.AddedTo('gear','vendor','TradeTreasure'); commands.mir_access(nil,'restore')")
        self.assertEqual(self.lua.eval('owner.gear'), 'vendor')
        self.assertFalse(self.lua.eval('MIR.Config.gateMerchants'))

    def test_generic_storage_name_is_not_convenience(self):
        self.lua.execute("roots.campRoot.Name='Ancient_Quest_Storage'")
        self.assertFalse(self.lua.eval("MIR.Access.Convenience('camp')"))

    def test_trade_listener_uses_bg3_four_argument_event(self):
        self.lua.execute("listeners.AddedTo('gear','vendor','TradeTreasure'); level=12; act=3; listeners.RequestTrade('player','vendor',0,'')")
        self.assertEqual(self.lua.eval('owner.gear'), 'vendor')

    def test_stackable_items_cannot_merge_and_lose_identity(self):
        self.lua.execute("Osi.GetStackAmount=function() return 2,20 end; listeners.AddedTo('gear','vendor','TradeTreasure')")
        self.assertEqual(self.lua.eval('moves'), 0)


class SourceTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('''
            ModuleUUID='mod'
            roots={vendor={Name='Trader',TemplateType='character',TradeTreasures={'Store'}}}
            tables={Store={SubTables={{Categories={{TreasureCategory='Gear'}}}}}}
            categories={Gear={Items={{Name='I_Sword'}}}}
            MIR={Config={},Log=function() end}
            Ext={Utils={MonotonicTime=function() return 0 end,Print=function() end},
                Vars={GetModVariables=function() return {} end},
                Template={GetAllRootTemplates=function() return roots end},
                Stats={TreasureTable={GetLegacy=function(n) return tables[n] end},
                    TreasureCategory={GetLegacy=function(n) return categories[n] end}}}
        ''')
        self.lua.execute((LUA / 'Server/TreasureIndex.lua').read_text(encoding='utf-8'))

    def test_merchant_only_source_qualifies(self):
        self.lua.execute('MIR.BuildTreasureIndex()')
        self.assertEqual(self.lua.eval("MIR.DeliverySource('Sword','SwordTemplate')"), 'merchant')

    def test_authored_placement_wins_over_shared_merchant_table(self):
        self.lua.execute("roots.boss={Name='Boss',TemplateType='character',Treasures={'Store'}}; MIR.BuildTreasureIndex()")
        self.assertIsNone(self.lua.eval("MIR.DeliverySource('Sword','SwordTemplate')"))

    def test_unknown_source_never_qualifies(self):
        self.lua.execute('MIR.BuildTreasureIndex()')
        self.assertIsNone(self.lua.eval("MIR.DeliverySource('Unknown','UnknownTemplate')"))

    def test_incomplete_source_resolution_disables_management(self):
        self.lua.execute("categories.Gear=nil; MIR.BuildTreasureIndex()")
        self.assertIsNone(self.lua.eval("MIR.DeliverySource('Sword','SwordTemplate')"))

    def test_tutorial_table_qualifies_without_root_reference(self):
        self.lua.execute("roots={}; tables.TUT_Chest_Potions=tables.Store; MIR.BuildTreasureIndex()")
        self.assertEqual(self.lua.eval("MIR.DeliverySource('Sword','SwordTemplate')"), 'convenience')


if __name__ == '__main__':
    unittest.main()
