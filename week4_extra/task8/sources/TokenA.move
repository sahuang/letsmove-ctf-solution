module task8::ctfa {
    use sui::coin::{Self, Coin, TreasuryCap};



    public struct CTFA has drop {}

    public struct MintA<phantom CTFA> has key, store{
        id: UID,
        cap: TreasuryCap<CTFA>
    }

    fun init(witness: CTFA, ctx: &mut TxContext){
        // Get a treasury cap for the coin and give it to the transaction sender
        let (treasury_cap, metadata) = coin::create_currency<CTFA>(witness, 1, b"CTF", b"CTF", b"Token for move ctf", option::none(), ctx);
        let mint = MintA<CTFA> {
            id: object::new(ctx),
            cap:treasury_cap
        };
        transfer::share_object(mint);
        transfer::public_freeze_object(metadata);
    }

    public(package) fun mint_for_vault<CTFA>(mut mint: MintA<CTFA>, ctx: &mut TxContext): Coin<CTFA> {
        let coinb = coin::mint<CTFA>(&mut mint.cap, 100, ctx);
        coin::mint_and_transfer(&mut mint.cap, 10, tx_context::sender(ctx), ctx);
        let MintA<CTFA> {
            id: ida,
            cap: capa
        } = mint;
        object::delete(ida);
        transfer::public_freeze_object(capa);
        coinb
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(CTFA{}, ctx); 
    }

}