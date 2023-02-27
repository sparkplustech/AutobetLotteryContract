pragma solidity ^0.6.6;

contract Governance {
    uint256 public one_time;
    address public lottery;
    address public randomness;
    constructor() public {
        one_time = 1;
    }
    function init(address _lottery, address _randomness) public {
        require(_randomness != address(0), "governance/no-randomnesss-address");
        require(_lottery != address(0), "no-lottery-address-given");
        one_time = one_time + 1;
        randomness = _randomness;
        lottery = _lottery;
    }
}
//rinkby contract address 0x7B4Cf3A11404C17E5e85381162E2acA73D43b97a