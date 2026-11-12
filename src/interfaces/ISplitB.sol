// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface ISplitB {
    error AlreadyNudged();
    function nudge() external;
    function updatePeriod() external returns (uint256);
    function needle() external view returns (uint256);
}
