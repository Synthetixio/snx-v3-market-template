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

![alt text](https://github.com/Synthetixio/snx-v3-market-template/blob/main/pool-market.png)

Let's talk about the responsibilities of the Core system and the markets that interact with it.

#### Core system

Exposed functions (in `IMarketManagerModule.sol`):

```
function depositMarketUsd(
    uint128 marketId,
    address target,
    uint256 amount
) external returns (uint256 feeAmount);

function withdrawMarketUsd(
    uint128 marketId,
    address target,
    uint256 amount
) external returns (uint256 feeAmount);

function getWithdrawableMarketUsd(
    uint128 marketId
) external view returns (uint256 withdrawableD18);
```

The market can call `getWithdrawableMarketUsd` with it's internally stored marketId and get exactly how much collateral (denominated in USD) is available for the market, based on LPs delegating to a pool, and the pool's configuration for the market.

When the market deposits USD into the core system using `depositMarketUsd`, the core system adds credit capacity which is available to both the LPs and markets. The market's withdrawable amount goes up, but the credit also becomes available to LPs. If LPs had any debt, it would become lower due to this new available credit and LPs can mint this new credit to realize any gains, which then lowers the withdrawable amount for the market.

The core system is responsible for distributing debt/credit to LPs based on the pool configuration, when they entered/exited the pool and other markets the pool delegates to.

The market implements a function called `minimumCredit` and if this value is non-zero, the core system is also responsible for ensuring this amount is available to withdraw by the market (via `withdrawMarketUsd`). The system does this by ensuring LPs cannot exit the pool if a minimum amount of credit is required by the markets its backing.

#### Market

The goal of a good market that will attract LPs is to deposit more USD than it withdraws.

The market is responsible for implementing/communicating the following to the core system:

```
function reportedDebt(uint128 marketId) external view returns (uint256);

function minimumCredit(uint128 marketId) external view returns (uint256);
```

`reportedDebt` allows the market to let the core system know it's accrued debt and the debt is distributed to the responsible parties. Generally, the debt is unrealized profits the market actors have accrued. Not reporting the debt would show LPs have more credit than they really do, which could cause issues down the line. In the end, it's up to the market to determine how to leverage this mechanism so it continues to stay solvent.

Another responsibility of the market is to force the core system to keep a specified amount of minimum credit available for it to withdraw. This can be very important to ensure market solvency and in case of large losses quickly, the available funds exist. With this information, the core system will force LPs delegating to this market to stay in the system.

The market can also deposit different collateral types, as long as the council has accepted them as a supported collateral type. This collateral differs from the collateral that is used to LP and can be beneficial to the market if it's dealing with collateral that's not USD.

Note that `reportedDebt` cannot be negative. If debt is negative, then there's credit and that credit should always be deposited into the core system instead of reducing debt. The core system accounting will ensure the impact is similar, but the market cannot just _say_ it has credit, without depositing the credit to the core system.

```
function depositMarketCollateral(
    uint128 marketId,
    address collateralType,
    uint256 tokenAmount
) public;

function withdrawMarketCollateral(
    uint128 marketId,
    address collateralType,
    uint256 tokenAmount
) public;
```

These functions will allow you to deposit/withdraw the collateral of the market's choosing.

**Note: When collateral is deposited, the market's withdrawable amount goes up by the collateral's USD value, and the opposite when withdrawn.**

And that's it. The responsibility falls on the market to adjust

### Example: Insurance Market

Let's build a small insurance market. main insurance features:

- collects premiums
- pays out claims

Let's assume market's insurance cap on value is $1M. So max liability is $1M. If all participates were to claim at the same time, we'd be on the hook for $1M, so let's set minimumCredit to $1M. This value could also be dynamic based on the value of assets that's being insured and can be part of a more complex market implementation.

```
uint256 max_liability = 1_000_000 ether

function minimumCredit(uint128 marketId) external view returns (uint256) {
  return max_liability
}
```

The market can decide if it wants to be leveraged here if it has historical data showing no more than $200k has ever been claimed at any given time. And this value can be changed based on that data.

Assuming there's some account mechanism, let's create a function to collect premiums. When collecting premiums, the market will deposit the USD directly into the core system as credit. The market could take a % of this as fees here to be profitable.

```
uint256 feePercentage = 0.1 ether; // 10%
function collectPremium(uint256 accountId, uint256 usdAmount) external {
  // 1. insurance account accounting
  accounts[accountId].debt -= usdAmount;

  // 2. collect fees
  uint256 fees = usdAmount.mulDecimal(feePercentage);
  USD.transferFrom(msg.sender, address(this), fees);

  synthetix.depositMarketUsd(marketId, msg.sender, usdAmount - fees);
}
```

And if an account is eligible for a claim, calling the following function will withdraw from the core system and send to account owner:

```
function claim(uint256 accountId, uint256 claimAmount) external {
  // perform checks to ensure eligibility
  // accounting

  // if all checks pass, withdraw from core system
  synthetix.withdrawMarketUsd(marketId, msg.sender, claimAmount);
}
```

`reportedDebt` can go many different ways. Some considerations:

- If the likelihood of any of the policies requiring claims is high, based on the % likelihood, reporting some % of the total claim value would provide an accurate representation of the state of the market to the LPs backing the market.
- Failing to report any debt while market expecting claims could result in potential insolvency, especially if minimumCredit is leveraged and not requiring full coverage of assets under management.
- Failing to report debt accurately also creates a false ROI for the LPs which makes the market not as trustworthy to the LPs and they may start exiting which limits the market's scalability.
- As an example, for the v3 perps market, all unrealized gains for traders are reported as debt to the core system.

This is a very simple example but hopefully provided a better idea of how to interact with the core system and to mitigate risk at the market level.

### FAQs/More Resources

1. Why would I build the market on Synthetix vs. building it as a standalone protocol?

- Synthetix solves the cold start liquidity problem but allows LPs to discover new markets that are both profitable for market participants and Synthetix LPs. Instead of worrying about accruing liquidity to back market, the focus can remain on building a profitable market, and convincing the Spartan council of this.

2. After I create my market, how would I actually get collateral delegated to this market?

- Write a SIP, explain why your market will perform well, and convince the SC to allow delegation of funds. Permissionless markets will be a thing in the future, but not yet.

3. What are some other resources for understanding v3?

- https://docs.synthetix.io/v/v3/for-derivatives-market-builders/build-on-v3
- More FAQs: https://docs.synthetix.io/v/v3/for-derivatives-market-builders/build-on-v3-faq
- More integration details: https://docs.synthetix.io/v/v3/for-derivatives-market-builders/integrating-synthetix

Would recommend reading through the docs there as well. Also hit us up on discord, #dev-portal if you have further q's.
