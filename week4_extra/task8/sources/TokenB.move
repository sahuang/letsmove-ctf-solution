module task8::ctfb {
    use sui::coin::{Self, Coin, TreasuryCap};



    public struct CTFB has drop {}

    public struct MintB<phantom CTFB> has key, store {
        id: UID,
        cap: TreasuryCap<CTFB>
    }

    fun init(witness: CTFB, ctx: &mut TxContext) {
        // Get a treasury cap for the coin and give it to the transaction sender
        let (treasury_cap, metadata) = coin::create_currency<CTFB>(witness, 1, b"CTF", b"CTF", b"Token for move ctf", option::none(), ctx);
        let mint = MintB<CTFB> {
            id: object::new(ctx),
            cap:treasury_cap
        };
        transfer::share_object(mint);
        transfer::public_freeze_object(metadata);
    }

    public(package) fun mint_for_vault<CTFB>(mut mint: MintB<CTFB>, ctx: &mut TxContext): Coin<CTFB> {
        let coinb = coin::mint<CTFB>(&mut mint.cap, 100, ctx);
        coin::mint_and_transfer(&mut mint.cap, 10, tx_context::sender(ctx), ctx);
        let MintB<CTFB> {
            id: idb,
            cap: capb
        } = mint;
        object::delete(idb);
        transfer::public_freeze_object(capb);
        coinb
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(CTFB{}, ctx); 
    }
}