// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface IDebtA {
    function accrueInterest() external;
    function getAccruedInterest() external view returns (uint256);
}
