#[test_only]
module task8::test {
    use sui::test_scenario;
    use std::debug;


    use task8::vault::{
        initialize,
        Vault
    };

    use task8::ctfa::{
        init_for_testing as init_for_testing_ctfa, 
        CTFA,
        MintA
    };

    use task8::ctfb::{
        init_for_testing as init_for_testing_ctfb, 
        CTFB,
        MintB
    };


    #[test]
    fun test_swap() { 
        let dev = @0x1;
        let mut scenario_val = test_scenario::begin(dev);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, dev);
        {
            init_for_testing_ctfa(test_scenario::ctx(scenario));
            init_for_testing_ctfb(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, dev);
        {
            let minta = test_scenario::take_shared<MintA<CTFA>>(scenario);
            let mintb = test_scenario::take_shared<MintB<CTFB>>(scenario);
            initialize(minta, mintb, test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, dev);
        {
            let vault = test_scenario::take_shared<Vault<CTFA, CTFB>>(scenario);
            debug::print(&vault);
            test_scenario::return_shared(vault);

        };

        test_scenario::end(scenario_val);
    }
}