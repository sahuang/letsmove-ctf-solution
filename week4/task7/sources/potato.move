module task7::potato {
    use sui::tx_context::{Self, TxContext};
    use task7::vault::{Self, Vault, get_owner ,get_balance,set_balance};
    use sui::event;
    use sui::clock;
    use sui::transfer;
    use sui::object::{Self, UID};

    const NO_MONEY: u64 = 1;
    const NO_PERMISSION: u64 = 2;

    struct Potato has key {
        id: UID,
        cooked: bool, 
    }

    struct Amount has copy, drop {
        amount: u64
    }


    public fun buy_potato(vault: &mut Vault, ctx: &mut TxContext){
        assert!(get_owner(vault) == tx_context::sender(ctx), NO_PERMISSION);
        assert!(get_balance(vault) >= 3, NO_MONEY);
        let balance = get_balance(vault);
        set_balance(vault, (balance-3));
        let potato = Potato{
            id: object::new(ctx),
            cooked: false,
        };
        transfer::transfer(potato, tx_context::sender(ctx));
    }

    public fun cook_potato(vault: &mut Vault, potato: &mut Potato, ctx: &mut TxContext){
        assert!(get_owner(vault) == tx_context::sender(ctx), NO_PERMISSION);
        assert!(get_balance(vault) >= 1, NO_MONEY);
        let balance = get_balance(vault);
        set_balance(vault, (balance-1));
        potato.cooked = true;
    }

    entry fun sell_potato(clock: &clock::Clock, vault: &mut Vault, potato: Potato, ctx: &mut TxContext){
        assert!(vault::get_owner(vault) == tx_context::sender(ctx), NO_PERMISSION);
        let current_timestamp = clock::timestamp_ms(clock);
        let d100 = current_timestamp % 3;
        let Potato{id, cooked} = potato;
        assert!(cooked, NO_PERMISSION);
        object::delete(id);
        if(d100 == 1){
            let balance = vault::get_balance(vault);
            set_balance(vault, (balance + 5));
            event::emit(Amount{amount: balance + 5});
        }else{
            let id = object::new(ctx);
            object::delete(id);
        }
    }
}
