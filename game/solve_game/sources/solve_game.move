module solve_game::solve{
    use game::challenge::{mint_cap};
    use sui::transfer::public_transfer;

    #[allow(lint(share_owned))]
    public entry fun create(ctx: &mut TxContext) {
        let admincap = mint_cap(ctx);
        public_transfer(admincap, ctx.sender());
    }

    // admincap: 0x24fef3b6ab93173fed76abe82a1cefa24b242fe63912cc124f4f373de6a84453
    // player: 0x5bd9d1de47bca34fb6f7fd333395a45b7ac61fa785ea4e9e2bd4642d68b5e735
    /*
    sui client call --package 0xe796e6aff74e8bebb6e7bb61f9addfe524a2852d0f5da828d59a05f465bfc7ca  --module solve --function create --gas-budget 100000000
    sui client call --package 0x2e5ba180f53d8aa73de26e03435abe6ac8f182a383ce8a99f4aaca8a76fc7979 --module challenge --function create_player --gas-budget 100000000
    sui client call --package 0x2e5ba180f53d8aa73de26e03435abe6ac8f182a383ce8a99f4aaca8a76fc7979 --module challenge --function receive_rewards --args 0x24fef3b6ab93173fed76abe82a1cefa24b242fe63912cc124f4f373de6a84453 0x5bd9d1de47bca34fb6f7fd333395a45b7ac61fa785ea4e9e2bd4642d68b5e735  --gas-budget 100000000
    */
}