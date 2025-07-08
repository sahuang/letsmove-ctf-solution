# Let's Move CTF

In this repo I will share my learnings and solutions to practice challenges in [HOH Let's Move CTF Bootcamp](https://github.com/hoh-zone/lets-ctf).

The course can be found on [BiliBili](https://space.bilibili.com/29742457/lists/5656070?type=season) and [Web Tutorial (Chinese)](https://lets-ctf.vercel.app/).

## Preface

Follow the official documentation to install [Sui Client CLI](https://docs.sui.io/references/cli/client) and have wallets ready for use on [Testnet](https://suiscan.xyz/testnet/home).

The 4-week learning mainly focused on these areas:
- General knowledge of Sui Move, syntax, how to deploy a contract etc.
- Basic interaction with Sui blockchain on Testnet
- Identify basic vulnerabilities in smart contracts and write solver contracts to interact and claim flag
- Vulnerabilities about Sui Move **Generics** (e.g. `<phantom T>`)
- Vulnerabilities about **resource management** and **ownership**
- Vulnerabilities about **access control** (e.g. `TxContext`)
- Vulnerabilities about **logic** bugs
- Use [**PTB**](https://docs.sui.io/guides/developer/sui-101/building-ptb) (Programmable Transaction Blocks) to interact with Sui Move
- Chaining vulnerabilities to solve challenges: scenarios and defense