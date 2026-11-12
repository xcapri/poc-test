// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
/// Oracle stand-in for local fork tests.
/// Returns a settable price in the shape the consumer expects.
contract MockOracle {
    int256 public answer;
    uint8 public constant dec = 18;
    uint80 public roundId = 13159024;
    constructor() {}
    function set(int256 a) external { answer = a; roundId += 1; }
    function decimals() external pure returns (uint8) { return 18; }
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (roundId, answer, block.timestamp, block.timestamp, roundId);
    }
}
