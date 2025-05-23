# SingleFixedStake Contract Interaction Guide

This document provides the Foundry commands for interacting with the SingleFixedStake contract on Merlin Testnet.

## Prerequisites
- [Foundry](https://getfoundry.sh/) installed
- Configured access to Merlin Testnet RPC
- Testnet BTC for gas fees

## Command Reference

### 1. Approve merl

```bash
forge script script/testnet/CallStake.s.sol:CallStake \
  --sig "approve()" \
  --rpc-url merlin_testnet \
  --broadcast \
  --legacy
```
### 2. stake merl

```bash
forge script script/testnet/CallStake.s.sol:CallStake \
  --sig "stake()" \
  --rpc-url merlin_testnet \
  --broadcast \
  --legacy
```
### 3. unstake merl
```bash
forge script script/testnet/CallStake.s.sol:CallStake \
  --sig "unstake()" \
  --rpc-url merlin_testnet \
  --broadcast \
  --legacy
```
### 4. withdraw merl

```bash
forge script script/testnet/CallStake.s.sol:CallStake \
  --sig "withdraw()" \
  --rpc-url merlin_testnet \
  --broadcast \
  --legacy
```
### 5. get stake rewards

```bash
forge script script/testnet/CallStake.s.sol:CallStake \
  --sig "getStakeRewards()" \
  --rpc-url merlin_testnet \
  --broadcast \
  --legacy
```