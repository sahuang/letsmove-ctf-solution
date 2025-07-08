module week2::drop;

use sui::coin::{Self, TreasuryCap, Coin};

public struct DROP has drop {}

public struct MintDROP<phantom DROP> has key, store {
    id: UID,
    cap: TreasuryCap<DROP>
}

fun init(witness: DROP, ctx: &mut TxContext) {
    let (treasury, metadata) = coin::create_currency(
        witness,
        6,
        b"DROP",
        b"DROP",
        b"DROP Coin",
        option::none(),
        ctx,
    );
    let mint = MintDROP<DROP> {
        id: object::new(ctx),
        cap: treasury
    };
    transfer::share_object(mint);
    transfer::public_freeze_object(metadata);
}

public fun get_total_supply(mint: &MintDROP<DROP>): u64 {
    mint.cap.total_supply()
}

public(package) fun mint_for_pool<BUTT>(mut mint: MintDROP<BUTT>, ctx: &mut TxContext): Coin<BUTT> {
    let coin_drop = mint.cap.mint(10001100, ctx);
    let MintDROP<BUTT> {
        id: idb,
        cap: treasury
    } = mint;
    object::delete(idb);
    transfer::public_freeze_object(treasury);
    coin_drop
}

#[test_only]
public fun share_for_testing(witness: DROP, ctx: &mut TxContext) {
    init(witness, ctx);
}