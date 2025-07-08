module shopping::sui {
    use sui::coin::{Self, TreasuryCap, Coin};

    const DECIMALS: u8 = 9;
    const SYMBOL: vector<u8> = b"SUI";
    const NAME: vector<u8> = b"SUI Token";


    public struct SUI has drop {}

    public struct MintCap<phantom SUI> has key, store {
        id: UID,
        cap: TreasuryCap<SUI>
    }

    fun init(witness: SUI, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(
            witness,
            DECIMALS,
            SYMBOL,
            NAME,
            b"",
            option::none(),
            ctx,
        );

        let mint = MintCap<SUI> {
            id: object::new(ctx),
            cap: treasury
        };
        transfer::share_object(mint);
        transfer::public_freeze_object(metadata);
    }

    #[allow(lint(freezing_capability))]
    public(package) fun mint_prize<SUI>(mut mintcap: MintCap<SUI>, ctx: &mut TxContext): Coin<SUI> {
        let prize = mintcap.cap.mint(1, ctx);
        let MintCap<SUI> {
            id: id,
            cap: treasury
        } =  mintcap;
        object::delete(id);

        transfer::public_freeze_object(treasury);

        prize
    }
}