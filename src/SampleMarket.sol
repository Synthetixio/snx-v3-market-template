// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC165} from "@synthetixio/core-contracts/contracts/interfaces/IERC165.sol";
import {IMarket} from "@synthetixio/main/contracts/interfaces/external/IMarket.sol";
import {ISynthetixSystem} from "./external/ISynthetixSystem.sol";

contract SampleMarket is IMarket {
    ISynthetixSystem public synthetix;
    uint128 public marketId;

    event MarketRegistered(uint128 marketId);

    constructor(address _synthetix) {
        synthetix = ISynthetixSystem(_synthetix);
    }

    function initialize() external {
        // register market with synthetix core system which allows
        // pools to delegate collateral to this market
        marketId = synthetix.registerMarket(address(this));

        emit MarketRegistered(marketId);
    }

    function name(uint128 marketId) external view returns (string memory) {
        return "SampleMarket";
    }

    function reportedDebt(uint128 marketId) external view returns (uint256) {
        return 0;
    }

    function minimumCredit(uint128 marketId) external view returns (uint256) {
        return 0;
    }

    function getWithdrawableUsd() external view returns (uint256) {
        return synthetix.getWithdrawableMarketUsd(marketId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165) returns (bool) {
        return
            interfaceId == type(IMarket).interfaceId ||
            interfaceId == this.supportsInterface.selector;
    }
}
