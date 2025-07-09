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