module shopping::challenge {
    use sui::balance::{Self, Balance};
    use sui::event;
    use shopping::sui::{Self, SUI, MintCap};
    use shopping::market::{Self, Market, Labubu};

    const EALREADYCLAIMED: u64 = 0;
    const EPAYPRICE: u64 = 1;
    const ENOTENOUGHBALANCE: u64 = 2;
    const EOWNER: u64 = 3;

    public struct Card has key {
        id: UID,
        owner: address,
        balance: Balance<SUI>,
        claimed: bool
    }

    public struct FlagEvent has copy, drop {
        owner: address,
        flag: bool
    }

    public entry fun open_card(ctx: &mut TxContext) {
        let card = Card {
            id: object::new(ctx),
            owner: ctx.sender(),
            balance: balance::zero<SUI>(),
            claimed: false
        };

        transfer::transfer(card, ctx.sender());
        
    }

    public entry fun buy(amt: u64, card: &mut Card, market: &mut Market, i: u64, ctx: &mut TxContext) {
        assert!(!(amt < market.get_labubu_price(i)), EPAYPRICE);

        let split_amt = amt << 30;
        
        assert!(((card.balance.value() << 30) - split_amt) >= 0, ENOTENOUGHBALANCE);

        market.pay(card.balance.split(split_amt >> 30));
        
        market::transfer_labubu_owner(market, i, ctx);
        transfer::public_transfer(market::get_labubu(market, i), ctx.sender());
    }

    public entry fun get_flag(labubu: &Labubu, card: &Card, ctx: &mut TxContext) {
        assert!(labubu.get_labubu_owner() == card.owner, EOWNER);

        event::emit(FlagEvent {
            owner: ctx.sender(),
            flag: true
        });

    }

    public entry fun claim(card: &mut Card, mintCap: MintCap<SUI>, ctx: &mut TxContext) {
        assert!(card.claimed == false, EALREADYCLAIMED);
        let prizeCoin = sui::mint_prize<SUI>(mintCap, ctx);
        card.balance.join(prizeCoin.into_balance());

        card.claimed = true;
    }

}