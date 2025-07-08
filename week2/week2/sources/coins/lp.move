module week2::lp;

use week2::pool;

public struct LP has drop {}

fun init(witness: LP, ctx: &mut TxContext) {
    pool::create_lp_coin<LP>(witness, 6, ctx);
}

#[test_only]
public fun share_for_testing(witness: LP, ctx: &mut TxContext) {
    init(witness, ctx);
}