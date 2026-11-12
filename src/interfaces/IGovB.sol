// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface IGovB {
    function propose(uint256 tokenId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) external returns (uint256);
    function castVote(uint256 proposalId, uint256 tokenId, uint8 support) external returns (uint256);
    function execute(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash) external payable returns (uint256);
}
