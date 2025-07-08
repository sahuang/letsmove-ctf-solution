module shopping::market {
    use sui::bag::{Self, Bag};
    use sui::balance::{Self, Balance};
    use std::string::String;
    use shopping::sui::SUI;

    const LABUBU_PRICE: u64 = 5_000_000_000;
    const DECIMALS: u8 = 9;

    public struct Market has key {
        id: UID,
        goods: Bag,
        balance: Balance<SUI>
    }

    public struct RestockCap has key {
        id: UID,
    }

    public struct Labubu has key, store {
        id: UID,
        name: String,
        price: u64,
        owner: address
    }
    
    fun init(ctx: &mut TxContext) {
        let restock_cap = RestockCap {
            id: object::new(ctx)
        };

        let mut market = Market {
            id: object::new(ctx),
            goods: bag::new(ctx),
            balance: balance::zero<SUI>()
        };

        let labubu = Labubu {
            id: object::new(ctx),
            name: b"Labubu".to_string(),
            price: LABUBU_PRICE / 10u64.pow(DECIMALS),
            owner: ctx.sender()
        };

        market.goods.add<String, vector<Labubu>>(b"Labubu".to_string(), vector::empty());
        market.goods.borrow_mut<String, vector<Labubu>>(b"Labubu".to_string()).push_back(labubu);

        transfer::transfer(restock_cap, ctx.sender());
        transfer::share_object(market);
    }

    public fun restock(_: &RestockCap, market: &mut Market, ctx: &mut TxContext) {
        let good = Labubu {
            id: object::new(ctx),
            name: b"Labubu".to_string(),
            price: LABUBU_PRICE / 10u64.pow(DECIMALS),
            owner: ctx.sender()
        };

        market.goods.borrow_mut<String, vector<Labubu>>(b"Labubu".to_string()).push_back(good);
    }

    public(package) fun get_labubu_price(market: &Market, i: u64): u64 {
        market.goods.borrow<String, vector<Labubu>>(b"Labubu".to_string()).borrow<Labubu>(i).price
    }

    public(package) fun get_labubu_owner(labubu: &Labubu): &address {
        &labubu.owner
    }

    public(package) fun transfer_labubu_owner(market: &mut Market, i: u64, ctx: &TxContext) {
        market.goods.borrow_mut<String, vector<Labubu>>(b"Labubu".to_string()).borrow_mut<Labubu>(i).owner = ctx.sender();
    }

    public(package) fun get_labubu(market: &mut Market, i: u64): Labubu {
        market.goods.borrow_mut<String, vector<Labubu>>(b"Labubu".to_string()).remove<Labubu>(i)
    }

    public(package) fun pay(market: &mut Market, balance: Balance<SUI>) {
        market.balance.join(balance);
    }
}