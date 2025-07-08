module week2::butt;

use sui::coin::{Self, TreasuryCap, Coin};

public struct BUTT has drop {}

public struct MintBUTT<phantom BUTT> has key, store {
    id: UID,
    cap: TreasuryCap<BUTT>
}

fun init(witness: BUTT, ctx: &mut TxContext) {
    let (treasury, metadata) = coin::create_currency(
        witness,
        6,
        b"BUTT",
        b"BUTT",
        b"BUTT Coin",
        option::none(),
        ctx,
    );
    let mint = MintBUTT<BUTT> {
        id: object::new(ctx),
        cap: treasury
    };
    transfer::share_object(mint);
    transfer::public_freeze_object(metadata);
}

public fun get_total_supply(mint: &MintBUTT<BUTT>): u64 {
    mint.cap.total_supply()
}

public(package) fun mint_for_pool<BUTT>(mut mint: MintBUTT<BUTT>, ctx: &mut TxContext): Coin<BUTT> {
    let coin_butt = mint.cap.mint(1000, ctx);
    let MintBUTT<BUTT> {
        id: idb,
        cap: treasury
    } = mint;
    object::delete(idb);
    transfer::public_freeze_object(treasury);
    coin_butt
}

#[test_only]
public fun share_for_testing(witness: BUTT, ctx: &mut TxContext) {
    init(witness, ctx);
}