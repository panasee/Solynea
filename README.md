# Solynea (SLN)

<p align="center"><img src="icon.png" width="180" alt="Solynea coin"></p>

A simple ERC-20 toy token for experiments and transfers between friends. No promised financial value or fiat peg. Deploy on your chosen compatible EVM network; standard wallets can receive and send SLN without a custom frontend.

## Contract

Built with OpenZeppelin Contracts **5.7.0**, Solidity **0.8.37**, and Foundry (tested with **1.8.4**).

- Default metadata: **Solynea / SLN / 18 decimals**; initial supply: **0**.
- Owner: unrestricted minting within `uint256`, global pause/unpause, and two-step ownership transfer.
- Holders: standard transfers, approvals, and burning their own tokens. `burnFrom` requires allowance, including for the owner.
- Pause blocks transfers, minting, and burning; approvals and reads remain available.
- No taxes, blacklists, proxy upgrades, swaps, or forced balance deductions.

Defaults live in [`src/TokenConfig.sol`](src/TokenConfig.sol). Deployment environment variables can override them. Amounts use smallest units: `1 SLN = 10^18`; use `cast to-wei 1000 ether` to encode 1000 SLN.

**Renouncing ownership is permanent. Renouncing while paused permanently freezes the token.** Tests are not a security audit.

## Setup and tests

Install [Foundry](https://getfoundry.sh/getting-started/installation) and Git. Python and Node.js are not required. From the repository root:

```sh
forge install OpenZeppelin/openzeppelin-contracts@v5.7.0 foundry-rs/forge-std@v1.17.0 --no-git --shallow
forge build
forge test
forge fmt --check
```

Dependencies are installed locally in `lib/` and ignored by Git. For local testing, run `anvil`, use its displayed RPC and chain ID, and sign with an Anvil test account.

## Deploy

[`script/DeploySolynea.s.sol`](script/DeploySolynea.s.sol) checks that `DEPLOY_CHAIN_ID` matches the RPC's chain ID, without a network allowlist. Each deployment is an independent token.

See [`.env.example`](.env.example) for configuration. Select an EVM version supported by your target network; the compiler default is `cancun`. Test before deploying to a public network.

PowerShell example (run from the repository root):

```powershell
$Forge = Join-Path $env:USERPROFILE '.foundry\bin\forge.exe'
$env:FOUNDRY_PROFILE = 'default'
$env:DEPLOY_CHAIN_ID = Read-Host 'Target chain ID'
$env:RPC_URL = Read-Host 'Target RPC URL'
$env:FOUNDRY_EVM_VERSION = Read-Host 'Supported EVM version'
$env:OWNER_ADDRESS = Read-Host 'Initial owner address'
$env:PRIVATE_KEY = [System.Net.NetworkCredential]::new(
    '', (Read-Host 'Deployment wallet private key' -AsSecureString)
).Password

# Simulate first. Only broadcast after checking the result.
& $Forge script script/DeploySolynea.s.sol:DeploySolynea --rpc-url target
# Run separately after a successful simulation:
& $Forge script script/DeploySolynea.s.sol:DeploySolynea --rpc-url target --broadcast
Remove-Item Env:PRIVATE_KEY
```

Fund the signing wallet with the target network's gas currency. If explicit fee settings are required, use values appropriate to that network.

## Verify and use

For an explorer supported by the Etherscan verifier, verify a recorded deployment locally:

```powershell
& '.\script\VerifyDeployment.ps1' -RecordPath (Read-Host 'Deployment record JSON path')
```

Use the deployment's original EVM version and compiler settings. The script reads the chain ID and constructor parameters from the record, checks source hashes and compiler settings, prompts for an **Etherscan API Key**, and updates the record only after success. No wallet private key or gas is needed. For other verifiers, use the appropriate `forge verify-contract` options.

In MetaMask, Rabby, or OKX Wallet, select the deployment network and import the **contract address**, symbol **SLN**, and **18** decimals. Send tokens to your friend's **wallet address**. Receiving is free; sending and other state changes require the network's gas currency.

Keep historical deployment records in `deployments/`, including the chain ID, contract address, transaction hash, constructor parameters, compiler settings, and source hashes. These records describe past deployments and do not configure future ones. Use the target network's block explorer to view balances and transfer history.

[Commemorative artwork](docs/assets/sln-wallet-flow-social-with-emblem.png)

## Secrets and license

Never commit private keys, seed phrases, API keys, `.env`, keystores, or raw deployment caches. Prefer process environment variables for deployment and encrypted Foundry keystores for repeated signing. `.gitignore` excludes local dependencies, build output, broadcasts, and caches; it does **not** prevent cloud synchronization.

Deployment records contain public wallet addresses and transaction hashes, which associate this repository with those wallets. The tests use a deliberately insecure public test key (`1`), never a production secret.

[MIT License](LICENSE).
