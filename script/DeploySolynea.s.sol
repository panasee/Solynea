// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {Script, console2} from "forge-std/Script.sol";
import {Solynea} from "../src/Solynea.sol";
import {TokenConfig} from "../src/TokenConfig.sol";

/// @notice Deploy on the EVM network selected through environment variables.
contract DeploySolynea is Script {
    error ChainMismatch(uint256 expected, uint256 actual);
    error InvalidDecimals(uint256 decimals);
    error InvalidPrivateKey();

    function run() external returns (Solynea token) {
        uint256 expectedChain = vm.envUint("DEPLOY_CHAIN_ID");
        if (block.chainid != expectedChain) {
            revert ChainMismatch(expectedChain, block.chainid);
        }

        address initialOwner = vm.envAddress("OWNER_ADDRESS");
        string memory tokenName = vm.envOr("TOKEN_NAME", TokenConfig.NAME);
        string memory tokenSymbol = vm.envOr("TOKEN_SYMBOL", TokenConfig.SYMBOL);
        uint256 tokenDecimals = vm.envOr("TOKEN_DECIMALS", uint256(TokenConfig.DECIMALS));
        if (tokenDecimals > type(uint8).max) {
            revert InvalidDecimals(tokenDecimals);
        }
        uint256 initialSupply = vm.envOr("INITIAL_SUPPLY", TokenConfig.INITIAL_SUPPLY);
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        if (privateKey == 0) revert InvalidPrivateKey();

        vm.startBroadcast(privateKey);
        // Range checked above: ERC-20 decimals are uint8.
        // forge-lint: disable-next-line(unsafe-typecast)
        token = new Solynea(tokenName, tokenSymbol, uint8(tokenDecimals), initialOwner, initialSupply);
        vm.stopBroadcast();

        console2.log("Chain ID:", block.chainid);
        console2.log("Solynea contract:", address(token));
        console2.log("Owner:", token.owner());
        console2.log("Name:", token.name());
        console2.log("Symbol:", token.symbol());
        console2.log("Decimals:", token.decimals());
        console2.log("Initial supply (raw units):", token.totalSupply());
    }
}
