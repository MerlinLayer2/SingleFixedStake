# SingleFixedStake

Merlin ERC-20 fixed APR staking contract behind an OpenZeppelin UUPS proxy. The proxy holds staked principal; a separately funded and approved rewards source pays staking rewards and delay rewards.

## V2 withdrawal flow

- The owner can update the staking APR, delay length in days, and delay reward APR. Rates use a scale of 1,000,000 (`450000` = 45%). A staking position records its total reward when created, so later APR updates affect new positions only.
- Neither principal nor rewards can be claimed before the original lock ends. The first `unstake` after that date starts the principal delay; the first `withdraw` starts the reward delay. `unstakeAndWithdraw` starts each delay that has not yet started. Only the staker can start a delay.
- Each delay starts at its own request time and locks in the current delay length and APR. The principal delay reward is calculated on unpaid principal. The reward delay reward is calculated on unpaid original staking rewards. Later configuration changes do not affect delays already started.
- After its own delay ends, `unstake` pays principal plus its delay reward, and `withdraw` pays remaining staking rewards plus their delay reward. Calls made while a delay is pending return without payment or resetting its deadline. The two claims can finish at different times. `unstakeAndWithdraw` handles both sides and claims any that are ready.
- Positions created before V2 use their recorded `totalRewards` and previously paid amounts. Already returned principal or staking rewards do not start a new delay.

`calCurrentRewards` remains available as a preview of original staking rewards accrued so far; it does not make rewards claimable before the delay ends.

The V2 config is initialized through the proxy during upgrade. See [script/README.md](script/README.md) for upgrade and deployment commands. The existing Merlin mainnet proxy is `0x63B824D5D5003F49F6A06750b2cD4D8c5972478e`.

## Tests

```sh
forge test
MERLIN_FORK_URL=<working_merlin_rpc> forge test --match-contract SingleFixedStakeV2ForkTest -vv
```
