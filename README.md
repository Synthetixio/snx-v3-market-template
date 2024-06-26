## SNX v3 Market Template

This template uses [Cannon](https://usecannon.com) and [Forge](https://book.getfoundry.sh/) to bootstrap a Synthetix v3 market.

### Prerequisites

- Install cannon: `npm i -g @usecannon/cli`
- Install and run `yarn`
- Run `npx cannon plugin add cannon-plugin-router` to install router.

### Get Started

- Fork this repo.
- Rename `SampleMarket` to your market name.
- Rename `cannonfile.toml` package name.
- Run `forge build` to build the package.
- Run `cannon build` to bootstrap and environment with Synthetix deployed and market registered. **Note: Use `--keep-alive` option to interact with built package**

### Bootstrapped environment

When you run cannon build, the following steps are executes for you to setup your market properly with the Synthetix v3 core system.

- Clone the latest release of Synthetix v3.
- Clone a mintable ERC-20 to use as collateral.
- Register a new oracle with a fixed price for collateral.
- Configure collateral on the core system.
- Create a new pool (which will be used to delegate collateral to the sample market).
- Create a new user account and mint collateral to deposit.
- Deposit into core system and delegate to the created pool.
- Deploy and initialize the SampleMarket contract.
- Delegate all collateral in pool to the SampleMarket.

### Core System Interactions

![alt text](https://github.com/Synthetixio/snx-v3-market-template/blob/main/core-market.png)
