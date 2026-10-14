# Deployment and upgrade

All rates use a scale of 1,000,000: `450000` is 45% APR and `150000` is 15% APR. `DELAY_DAYS=90` means 90 days, not three calendar months.

## Upgrade the Merlin mainnet proxy to V2

The existing proxy is `0x63B824D5D5003F49F6A06750b2cD4D8c5972478e`. Its owner is currently the contract `0x420d30c195bda7eb1f6b75d314d502d80484ba8e`, so a direct upgrade transaction from a private key cannot pass the owner check. Confirm the owner again before upgrading.

First, deploy the V2 implementation from a funded deployment account:

```sh
forge script script/DeployLogic.sol:DeployScript --rpc-url merlin_mainnet --broadcast --legacy
```

Set `PRIVATE_KEY` in the environment for that deployment. Then use the deployed address to generate calldata for an owner-contract transaction:

```sh
export PROXY_ADDRESS=0x63B824D5D5003F49F6A06750b2cD4D8c5972478e
export NEW_IMPLEMENTATION=<deployed_v2_implementation>
export DELAY_DAYS=90
export DELAY_APR=150000
forge script script/Upgrade.s.sol:Upgrade
```

Submit the printed calldata to the current owner contract for execution with `to` set to the proxy and `value` set to zero. The call upgrades the proxy and runs `initializeV2` atomically. It does not change the current staking APR. To change that APR later, the owner contract sends a separate `updateApr(150000)` call; existing stakes retain their recorded total rewards.

## Deploy a new V2 proxy

Set `PRIVATE_KEY`, `STAKE_TOKEN`, `REWARDS_SOURCE_ADDRESS`, `NDAYS`, `APR`, `STAKE_CAP`, `DELAY_DAYS`, and `DELAY_APR`, then run:

```sh
forge script script/DeployProxy.s.sol:DeployProxy --rpc-url merlin_mainnet --broadcast --legacy
```

The deployment script initializes both V1 and V2 configuration. The rewards source must hold enough staking tokens and approve the proxy to pay normal rewards and delay rewards.

## Verify on a fork

```sh
MERLIN_FORK_URL=<working_merlin_rpc> forge test --match-contract SingleFixedStakeV2ForkTest -vv
```
