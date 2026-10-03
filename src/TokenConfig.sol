// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

/// @notice Defaults for new deployments. Changing these does not alter deployed tokens.
library TokenConfig {
    string internal constant NAME = "Solynea";
    string internal constant SYMBOL = "SLN";
    uint8 internal constant DECIMALS = 18;
    uint256 internal constant INITIAL_SUPPLY = 0;
}
