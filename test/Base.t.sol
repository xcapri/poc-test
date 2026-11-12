// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "forge-std/Test.sol";
import "../src/mocks/MockOracle.sol";
import "../src/mocks/MockToken.sol";

/// Read-only fork pinned at a fixed block. RPC comes from the RPC_URL environment variable. Nothing is broadcast.
abstract contract Base is Test {
    uint256 constant PIN = 13159121;
    address constant ORACLE = 0x7b7c000000000000000000000000000000000015;
    address constant NTV = 0x7b7C000000000000000000000000000000000000;
    int256 constant PINNED_PRICE = 74585572980000000000000;
    MockOracle oracle; MockToken ntv;
    function _fork() internal {
        vm.createSelectFork(vm.envString("RPC_URL"), PIN);
        MockOracle o = new MockOracle(); vm.etch(ORACLE, address(o).code); oracle = MockOracle(ORACLE); oracle.set(PINNED_PRICE);
        MockToken b = new MockToken(); vm.etch(NTV, address(b).code); ntv = MockToken(NTV);
    }
}
