// SPDX-License-Identifier: APACHE
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/Contract.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
}

contract TokenizedVaultTest is Test {
    TokenizedVault _vault;
    IERC20 _asset;
    address _mockExternalContract;

    function setUp() public {
        // Set up the _asset and mock external contract.
        // The _asset and _mockExternalContract would ideally be mock tokens that we have control over.
        // For this example, we'll just use a new instance of the MockERC20 contract and address(2).
        _asset = new MockERC20("Mock Token", "MCK");
        _mockExternalContract = address(2);

        // Set up the _vault with the _asset, name, and symbol.
        _vault = new TokenizedVault(_asset, "Vault", "VAULT");
    }
}
