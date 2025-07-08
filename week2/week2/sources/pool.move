module week2::pool;

use std::ascii;
use std::type_name::{Self, TypeName};
use sui::bag::{Self, Bag};
use sui::balance::{Supply, Balance};
use sui::coin::{Self, Coin, CoinMetadata, TreasuryCap};
use sui::package;

const FEE_PRECISION: u64 = 100_000;
const FLASHLOAN_FEE: u64 = 5_000; // 5% flashloan fee

const ETypeNotFoundInPool: u64 = 0;
const EFlashloanAlreadyInProgress: u64 = 1;
const ERepayAmountMismatch: u64 = 2;
const EPoolIdMismatch: u64 = 3;

// OTW
public struct POOL has drop {}

public struct CreatePoolCap<phantom LP> has key {
    id: UID,
    lp_treasury_cap: TreasuryCap<LP>,
    lp_coin_metadata: CoinMetadata<LP>,
}

public struct Pool<phantom L> has key, store {
    id: UID,
    creator: address,
    lp_supply: Supply<L>,
    balances: Bag,
    type_names: vector<ascii::String>,
    swap_fee: u64,
    coin_decimals: vector<u8>,
    lp_decimals: u8,
    flashloan: bool,
}

// Hot potato
public struct FlashReceipt {
    pool_id: ID,
    type_name: ascii::String,
    repay_amount: u64,
}

fun init(otw: POOL, ctx: &mut TxContext) {
    package::claim_and_keep(otw, ctx);
}

#[allow(lint(self_transfer))]
public fun create_lp_coin<LP: drop>(witness: LP, decimals: u8, ctx: &mut TxContext) {
    let (treasury_cap, coin_metadata) = coin::create_currency<LP>(
        witness,
        decimals,
        b"WLP",
        b"WLP",
        b"weird LP Coin",
        option::none(),
        ctx,
    );

    let createCap = CreatePoolCap<LP> {
        id: object::new(ctx),
        lp_treasury_cap: treasury_cap,
        lp_coin_metadata: coin_metadata,
    };

    transfer::share_object(createCap);
}

public fun new<LP, A, B>(
    create_cap: CreatePoolCap<LP>,
    coin_1: Coin<A>,
    coin_2: Coin<B>,
    swap_fee: u64,
    decimals: vector<u8>,
    ctx: &mut TxContext,
): Pool<LP> {
    let CreatePoolCap { id, lp_treasury_cap, lp_coin_metadata } = create_cap;
    id.delete();

    assert!(lp_treasury_cap.total_supply() == 0, 0);

    let lp_decimals = lp_coin_metadata.get_decimals();

    transfer::public_freeze_object(lp_coin_metadata);

    let type_names = vector[type_name::get<A>().into_string(), type_name::get<B>().into_string()];

    // init supply
    let mut balances = bag::new(ctx);
    balances.add(type_name::get<A>(), coin_1.into_balance());
    balances.add(type_name::get<B>(), coin_2.into_balance());

    Pool<LP> {
        id: object::new(ctx),
        lp_supply: coin::treasury_into_supply(lp_treasury_cap),
        balances: balances,
        type_names: type_names,
        creator: ctx.sender(),
        swap_fee: swap_fee,
        lp_decimals: lp_decimals,
        coin_decimals: decimals,
        flashloan: false,
    }
}

public fun deposit<LP, A>(pool: &mut Pool<LP>, coin: Coin<A>) {
    assert!(contains_type<LP, A>(pool) == true, ETypeNotFoundInPool);
    assert!(!pool.flashloan, EFlashloanAlreadyInProgress);
    deposit_internal(pool, coin);
}

public fun balance_of<LP, A>(pool: &Pool<LP>): u64 {
    pool.balances.borrow<TypeName, Balance<A>>(type_name::get<A>()).value()
}

public fun is_flashloan<LP>(pool: &Pool<LP>): bool {
    pool.flashloan
}

public fun contains_type<LP, A>(pool: &Pool<LP>): bool {
    let (type_exists, _) = pool.type_names.index_of(&type_name::get<A>().into_string());

    type_exists
}

public fun swap_a_to_b<LP, A, B>(
    pool: &mut Pool<LP>,
    coin_a: Coin<A>,
    ctx: &mut TxContext,
): Coin<B> {
    assert!(contains_type<LP, A>(pool), ETypeNotFoundInPool);
    assert!(contains_type<LP, B>(pool), ETypeNotFoundInPool);
    assert!(!pool.flashloan, EFlashloanAlreadyInProgress);

    let amount_out = coin_a.value() * balance_of<LP, B>(pool) / balance_of<LP, A>(pool);
    let fee = amount_out * pool.swap_fee / FEE_PRECISION;
    deposit<LP, A>(pool, coin_a);
    withdraw_internal(pool, amount_out - fee, ctx)
}

public fun flashloan<LP, A>(
    pool: &mut Pool<LP>,
    amount: u64,
    ctx: &mut TxContext,
): (Coin<A>, FlashReceipt) {
    assert!(contains_type<LP, A>(pool), ETypeNotFoundInPool);
    assert!(!pool.flashloan, EFlashloanAlreadyInProgress);

    pool.flashloan = true;

    let coin = withdraw_internal<LP, A>(pool, amount, ctx);
    let receipt = FlashReceipt {
        pool_id: object::id(pool),
        type_name: type_name::get<A>().into_string(),
        repay_amount: amount * (FEE_PRECISION + FLASHLOAN_FEE) / FEE_PRECISION,
    };

    (coin, receipt)
}

public fun repay_flashloan<LP, A>(pool: &mut Pool<LP>, receipt: FlashReceipt, coin: Coin<A>) {
    let FlashReceipt { pool_id: id, type_name: _, repay_amount: amount } = receipt;
    assert!(contains_type<LP, A>(pool), ETypeNotFoundInPool);
    assert!(object::id(pool) == id, EPoolIdMismatch);
    assert!(coin::value(&coin) == amount, ERepayAmountMismatch);
    deposit_internal<LP, A>(pool, coin);

    pool.flashloan = false;
}

fun deposit_internal<LP, A>(pool: &mut Pool<LP>, coin: Coin<A>) {
    if (pool.balances.contains(type_name::get<A>())) {
        pool.balances
            .borrow_mut<TypeName, Balance<A>>(type_name::get<A>())
            .join(coin.into_balance());
    } else {
        pool.balances.add(type_name::get<A>(), coin.into_balance());
    }
}

fun withdraw_internal<LP, A>(pool: &mut Pool<LP>, amount: u64, ctx: &mut TxContext): Coin<A> {
    assert!(contains_type<LP, A>(pool) == true, ETypeNotFoundInPool);

    pool.balances
        .borrow_mut<TypeName, Balance<A>>(type_name::get<A>())
        .split(amount)
        .into_coin(ctx)
}
