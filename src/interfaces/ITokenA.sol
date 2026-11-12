// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface ITokenA {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}
