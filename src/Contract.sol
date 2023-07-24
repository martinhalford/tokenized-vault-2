// SPDX-License-Identifier: APACHE

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @title ExternalAsset
 * @dev This is a simple ERC20 contract that will be used to represent assets that
 * have been invested externally.
 */
contract ExternalAsset is ERC20, ERC20Burnable, Ownable {
    uint8 private _decimals;

    constructor(uint8 decimals_) ERC20("External Asset", "EXT") {
        _decimals = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burnFrom(
        address account,
        uint256 amount
    ) public override onlyOwner {
        _burn(account, amount);
    }
}

/**
 * @title TokenizedVault
 * @dev This contract is a concrete implementation of ERC4626.
 */
contract TokenizedVault is ERC4626, Ownable {
    string private _name;
    string private _symbol;
    ExternalAsset private _externalAsset;
    uint8 private _decimals;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes the underlying
     * asset with the value of {asset_}
     */
    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_
    ) ERC4626(asset_) ERC20(name_, symbol_) Ownable() {
        _name = name_;
        _symbol = symbol_;
        _decimals = asset_.decimals();
        _externalAsset = new ExternalAsset(_decimals);
        // Transfer ownership of _externalAsset to this contract
        // - so only this contract can mint/burn external assets.
        _externalAsset.transferOwnership(address(this));
    }

    /**
     * @dev Returns the name of the token.
     */
    function name()
        public
        view
        virtual
        override(ERC20, IERC20Metadata)
        returns (string memory)
    {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol()
        public
        view
        virtual
        override(ERC20, IERC20Metadata)
        returns (string memory)
    {
        return _symbol;
    }

    /**
     * @dev Returns the amount of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override(ERC4626) returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Returns the total amount of the external assets that is “managed” by Vault.
     */
    function totalExternalAssets() public view virtual returns (uint256) {
        return _totalExternalAssets;
    }

    /**
     * @dev Allows the owner of the contract to invest assets externally on behalf of an investor.
     */
    function investExternally(
        address from,
        address externalContract,
        uint256 amount
    ) public onlyOwner {
        IERC20 token = IERC20(asset());
        require(
            token.allowance(from, address(this)) >= amount,
            "Not enough allowance"
        );

        // Transfer the tokens from the specified account to the external contract
        require(
            token.transferFrom(from, externalContract, amount),
            "Transfer failed"
        );

        // Update external asset balance
        _totalExternalAssets += amount;
    }

    /**
     * @dev Allows the owner of the contract to redeem an external investment on behalf of an investor.
     * The amount to redeem can be more or less than the amount invested.
     * --- Screnario 1: The investor makes a profit.
     * If the amount to redeem is more than the amount invested then the investor has earned a profit.
     * In this case the investor will receive the amount invested plus the profit and the external asset amount will be set to zero.
     * The assumption is that the investor now has no more external assets.
     * --- Screnario 2: The investor makes a loss.
     * If the amount to redeem is less than the amount invested then the investor has lost money.
     * If this case the investor will receive the amount to be redeemed and only the amount to be redeemed of external asset tokens will be burned.
     * Any spare external asset tokens will remain in the vault for this investor.
     */
    function redeemExternalInvestment(
        address investor,
        address externalContract,
        uint256 amount
    ) public onlyOwner {
        require(amount > 0, "Amount must be greater than zero");

        IERC20 token = IERC20(asset());

        // Check allowance
        uint256 allowance = token.allowance(externalContract, address(this));
        require(allowance >= amount, "Transfer amount exceeds allowance");

        // Transfer the underlying asset tokens from the external contract to the investor
        require(
            token.transferFrom(externalContract, investor, amount),
            "Transfer failed"
        );

        // Update external asset balance
        // If the amount to redeem is more than the amount invested then the investor has earned a profit.
        // Therefore all external asset tokens will be "burned".
        if (_totalExternalAssets > amount) {
            _totalExternalAssets -= amount;
        } else {
            _totalExternalAssets = 0;
        }
    }

    // Used by owner of contract to set the external asset balance for testing purposes
    // and, on rare occassions, when the external asset balance needs to be adjusted.
    function setExternalAssetBalance(uint256 amount) public onlyOwner {
        require(amount > 0, "Amount must be greater than zero");
        _totalExternalAssets = amount;
    }
}
