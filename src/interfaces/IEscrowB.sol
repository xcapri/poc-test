// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface IEscrowB {
    function createLock(uint256 _value, uint256 _lockDuration) external returns (uint256);
}
