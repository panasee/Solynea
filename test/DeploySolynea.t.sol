// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DeploySolynea} from "../script/DeploySolynea.s.sol";
import {Solynea} from "../src/Solynea.sol";

contract DeploySolyneaTest is Test {
    DeploySolynea internal deploy;
    address internal owner = makeAddr("deploymentOwner");

    function setUp() public {
        deploy = new DeploySolynea();
    }

    function resetEnvironment() internal {
        vm.chainId(31337);
        vm.setEnv("DEPLOY_CHAIN_ID", "31337");
        vm.setEnv("OWNER_ADDRESS", vm.toString(owner));
        // Public, deliberately insecure TEST-ONLY key. Never use on any public chain.
        vm.setEnv("PRIVATE_KEY", "1");
        vm.setEnv("TOKEN_NAME", "Solynea");
        vm.setEnv("TOKEN_SYMBOL", "SLN");
        vm.setEnv("TOKEN_DECIMALS", "18");
        vm.setEnv("INITIAL_SUPPLY", "0");
    }

    // setEnv changes shared process state. Keep all environment scenarios in one
    // test so parallel Foundry test workers cannot overwrite each other's inputs.
    function test_DeploymentConfigurationAndValidation() public {
        resetEnvironment();
        localDeployment();
        resetEnvironment();
        arbitraryChainDeployment();
        resetEnvironment();
        deploymentOverrides();
        resetEnvironment();
        wrongRPCChainRejected();
        resetEnvironment();
        invalidDecimalsRejected();
        resetEnvironment();
        zeroOwnerRejected();
        resetEnvironment();
        zeroKeyRejected();
    }

    function localDeployment() internal {
        Solynea token = deploy.run();
        assertGt(address(token).code.length, 0);
        assertEq(token.owner(), owner);
        assertEq(token.name(), "Solynea");
        assertEq(token.symbol(), "SLN");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 0);
    }

    function arbitraryChainDeployment() internal {
        // Synthetic IDs, simulated locally without connecting to any network.
        uint256[2] memory chainIds = [uint256(123456789), 987654321];
        for (uint256 i = 0; i < chainIds.length; ++i) {
            resetEnvironment();
            vm.chainId(chainIds[i]);
            vm.setEnv("DEPLOY_CHAIN_ID", vm.toString(chainIds[i]));
            Solynea token = deploy.run();
            assertGt(address(token).code.length, 0);
            assertEq(token.owner(), owner);
            assertEq(token.name(), "Solynea");
            assertEq(token.symbol(), "SLN");
            assertEq(token.decimals(), 18);
            assertEq(token.totalSupply(), 0);

            // The selected target must reject an RPC connected to another chain.
            vm.chainId(31337);
            vm.expectRevert(abi.encodeWithSelector(DeploySolynea.ChainMismatch.selector, chainIds[i], 31337));
            deploy.run();
        }
    }

    function deploymentOverrides() internal {
        vm.setEnv("TOKEN_NAME", "Friends");
        vm.setEnv("TOKEN_SYMBOL", "FRN");
        vm.setEnv("TOKEN_DECIMALS", "6");
        vm.setEnv("INITIAL_SUPPLY", "25000000");
        Solynea token = deploy.run();
        assertEq(token.name(), "Friends");
        assertEq(token.symbol(), "FRN");
        assertEq(token.decimals(), 6);
        assertEq(token.balanceOf(owner), 25_000_000);
        assertEq(token.totalSupply(), 25_000_000);
    }

    function wrongRPCChainRejected() internal {
        vm.setEnv("DEPLOY_CHAIN_ID", "123456789");
        vm.expectRevert(abi.encodeWithSelector(DeploySolynea.ChainMismatch.selector, 123456789, 31337));
        deploy.run();
    }

    function invalidDecimalsRejected() internal {
        vm.setEnv("TOKEN_DECIMALS", "256");
        vm.expectRevert(abi.encodeWithSelector(DeploySolynea.InvalidDecimals.selector, 256));
        deploy.run();
    }

    function zeroOwnerRejected() internal {
        vm.setEnv("OWNER_ADDRESS", vm.toString(address(0)));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        deploy.run();
    }

    function zeroKeyRejected() internal {
        vm.setEnv("PRIVATE_KEY", "0");
        vm.expectRevert(DeploySolynea.InvalidPrivateKey.selector);
        deploy.run();
    }
}
