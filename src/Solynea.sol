// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @notice A standard ERC-20 for friends, with explicit owner minting and global pause.
/// @dev Amounts are always in smallest units. Pause blocks transfers, minting and burning.
contract Solynea is ERC20, ERC20Burnable, ERC20Pausable, Ownable2Step {
    uint8 private immutable _tokenDecimals;

    /// @param initialSupply Raw units credited to initialOwner, not a whole-token count.
    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimals,
        address initialOwner,
        uint256 initialSupply
    ) ERC20(tokenName, tokenSymbol) Ownable(initialOwner) {
        _tokenDecimals = tokenDecimals;
        if (initialSupply > 0) {
            _mint(initialOwner, initialSupply);
        }
    }

    function decimals() public view override returns (uint8) {
        return _tokenDecimals;
    }

    /// @notice The owner may create any amount that fits the uint256 total supply.
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Pausable) {
        super._update(from, to, value);
    }
}
