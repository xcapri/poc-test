// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface IVaultA {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function claimYield() external returns (uint256);
    function claimableYield(address) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}
