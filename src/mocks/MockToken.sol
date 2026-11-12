// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
/// Ledger-based ERC20 stand-in for a native-token precompile.
/// On the live chain the precompile is an ERC20 view over native balances; here we keep an
/// internal ledger seeded by tests via `seed`, which is enough to exercise contract logic
/// that calls transfer/transferFrom/approve on it. NOT a model of precompile internals.
contract MockToken {
    string public name = "Native"; string public symbol = "NTV"; uint8 public decimals = 18;
    mapping(address=>uint256) public balanceOf; mapping(address=>mapping(address=>uint256)) public allowance;
    uint256 public totalSupply;
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function mint(address a, uint256 v) external { balanceOf[a] += v; totalSupply += v; emit Transfer(address(0), a, v); }
    function burn(address a, uint256 v) external { balanceOf[a] -= v; totalSupply -= v; }
    function seed(address a, uint256 v) external { totalSupply = totalSupply - balanceOf[a] + v; balanceOf[a] = v; }
    function approve(address s, uint256 v) external returns (bool) { allowance[msg.sender][s] = v; emit Approval(msg.sender, s, v); return true; }
    function transfer(address to, uint256 v) external returns (bool) { _move(msg.sender, to, v); return true; }
    function transferFrom(address f, address to, uint256 v) external returns (bool) {
        uint256 al = allowance[f][msg.sender]; require(al >= v, "allowance"); if (al != type(uint256).max) allowance[f][msg.sender] = al - v;
        _move(f, to, v); return true; }
    function _move(address f, address to, uint256 v) internal { require(balanceOf[f] >= v, "balance"); balanceOf[f] -= v; balanceOf[to] += v; emit Transfer(f, to, v); }
}
