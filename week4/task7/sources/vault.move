module task7::vault {
    use sui::transfer;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::event;

    friend task7::potato;
    const NO_PERMISSION: u64 = 2;
    
    struct Vault has key {
        id: UID,
        owner: address,
        balance: u64, 
    }
    
    public fun init_vault(ctx: &mut TxContext){
        let vault = Vault{
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            balance: 100,
        };
        transfer::transfer(vault, tx_context::sender(ctx));
    }

    struct Flag has copy, drop {
        user: address,
        flag: bool,
    }

    public entry fun get_flag(vault: &mut Vault, ctx: &mut TxContext){
        assert!(vault.owner == tx_context::sender(ctx), NO_PERMISSION);
        if(vault.balance >= 200){
           event::emit (Flag {
            user: tx_context::sender(ctx),
            flag: true,
        }); 
        }
    }

    public(friend) fun get_balance(vault: &Vault): u64{
        vault.balance
    }
    public(friend) fun get_owner(vault: &Vault): address{
        vault.owner
    }
    public(friend) fun set_balance(vault: &mut Vault, balance:u64){
        vault.balance = balance;
    } 

}
