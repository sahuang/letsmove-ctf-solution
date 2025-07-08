module week2::challenge;

use sui::coin::{Self, Coin};
use std::string::{Self, String};
use sui::balance::Balance;
use sui::event;

use week2::pool::{Self, CreatePoolCap, Pool};
use week2::butt::{Self, BUTT, MintBUTT};
use week2::drop::{Self, DROP, MintDROP};
use week2::lp::LP;

const EAlreadyClaimed: u64 = 0; // Challenge already claimed
const ENotSolved: u64 = 1; // Challenge not solved
const EAlreadySolved: u64 = 2; // Challenge already solved

// PackageID: 0x33525141f7bb57e31ee2238412429f98f154d25a8a7be9b4911be89aa82112ed
// MintBUTT<BUTT> 0x06c6011f1b9f2002b491a3ba65df841d1ef6df63930f28a320e5968b7a735f5a
// MintDROP<DROP> 0x9ef3aff2b0d3614d570cb161d96d4bcb0f589d250870fd412bd670be5fb7ecfd
// CreatePoolCap<LP> 0x244a9119308d758f4c2969c78f15665ee683e29871d17da1f1797baacc26f7f5
public struct FlagEvent has copy, drop {
    sender: address,
    flag: String,
    github_id: String,
    success: bool
}

public struct Challenge<phantom LP, phantom BUTT, phantom DROP> has key, store {
    id: UID,
    pool: Pool<LP>,
    drop_balance: Balance<DROP>,
    claimed: bool,
    success: bool,
}

public fun get_pool(challenge: &Challenge<LP, BUTT, DROP>): &Pool<LP> {
    &challenge.pool
}

public fun get_pool_mut(challenge: &mut Challenge<LP, BUTT, DROP>): &mut Pool<LP> {
    &mut challenge.pool
}

public fun create_challenge(mint_butt: MintBUTT<BUTT>, mint_drop: MintDROP<DROP>, create_cap: CreatePoolCap<LP>, ctx: &mut TxContext): Challenge<LP, BUTT, DROP> {
    assert!(mint_butt.get_total_supply() == 0);
    assert!(mint_drop.get_total_supply() == 0);
    
    let coin_1 = butt::mint_for_pool<BUTT>(mint_butt, ctx);
    let mut coin_2 = drop::mint_for_pool<DROP>(mint_drop, ctx);
    
    let pool = pool::new(create_cap, coin_1, coin_2.split(10000000, ctx), 1000, vector[6,6], ctx);

    let challenge = Challenge<LP, BUTT, DROP> {
        id: object::new(ctx),
        pool: pool,
        drop_balance: coin::into_balance(coin_2),
        claimed: false,
        success: false,
    };
    challenge
}

public fun claim_drop(challenge: &mut Challenge<LP, BUTT, DROP>, ctx: &mut TxContext): Coin<DROP> {
    assert!(!challenge.claimed, EAlreadyClaimed);

    challenge.claimed = true;
    let airdrop = challenge.drop_balance.withdraw_all().into_coin(ctx);

    airdrop
}

public fun is_solved(challenge: &Challenge<LP, BUTT, DROP>): bool {
    let pool = &challenge.pool;
    let butt_balance = pool.balance_of<LP, BUTT>();
    let is_flashloan = pool.is_flashloan();

    butt_balance == 0 && is_flashloan == false
}

public fun get_flag(challenge: &mut Challenge<LP, BUTT, DROP>, github_id: String, ctx: &mut TxContext) {
    assert!(is_solved(challenge), ENotSolved);
    assert!(!challenge.success, EAlreadySolved);

    challenge.success = true;

    event::emit(FlagEvent {
        sender: ctx.sender(),
        flag: string::utf8(b"CTF{MoveCTF-Task2}"),
        github_id,
        success: true
    });
}