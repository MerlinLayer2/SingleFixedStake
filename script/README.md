
# Script Usage Guide

This is a script for deploying and upgrading the RazzManager contract. Below are detailed instructions for each command.

## 1. Deploy Proxy Contract
- Function: Deploy the proxy contract for RazzManager contract.

```bash
forge script script/DeployProxy.s.sol:DeployProxy \
    --rpc-url merlin_testnet \
    --broadcast \
    --legacy # --verify
    
    forge script script/DeployProxy.s.sol:DeployProxy \
    --rpc-url merlin_mainnet \
    --broadcast \
    --legacy --verify
```
#### Environment Variables Setup (in .env)
- export PRIVATE_KEY=your_private_key
- export RPC_URL=your_RPC_URL


## 2. Upgrade Proxy Contract
- Function: Upgrade the logic contract of RazzManager.

```bash
forge script script/Upgrade.s.sol:Upgrade \
    --rpc-url merlin_testnet \
    --broadcast \
    --legacy # --verify
```

#### 设置代理合约地址
- export PROXY_ADDRESS=deployed_proxy_contract_address
- Function: Set the deployed proxy contract address in environment variables, replace PROXY_ADDRESS with the actual deployed proxy contract address.


## 3. Deploy Logic Contract Only
```bash
- Function: Deploy only the logic contract of RazzManager, without involving the proxy contract.

forge script script/DeployLogic.sol:DeployScript \
    --rpc-url=merlin_testnet \
    --broadcast \
    --legacy # --verify
    
    forge script script/DeployLogic.sol:DeployScript \
    --rpc-url=merlin_mainnet \
    --broadcast \
    --legacy --verify
```

## Usage Instructions
1. Ensure forge is installed and Merlin testnet RPC address is properly configured.
2. Execute the above commands in sequence to deploy and upgrade the RazzManager contract.
3. After each command execution, transaction details can be viewed through the blockchain explorer.