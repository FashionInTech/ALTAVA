// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

// used in BasicVesting (for utils)

contract SafeMath {
     function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

     function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }
}
