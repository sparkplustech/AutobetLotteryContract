pragma solidity 0.6.6;

import "./vrf/VRFConsumerBase.sol";
import {lottery_interface} from "./interfaces/lottery_interface.sol";
import {governance_interface} from "./interfaces/governance_interface.sol";

contract RandomNumberConsumer is VRFConsumerBase {
    
    bytes32 internal keyHash;
    uint256 internal fee;
    address public admin;
    mapping (uint => uint) public randomNumber;
    mapping (bytes32 => uint) public requestIds;
    governance_interface public governance;
    uint256 public most_recent_random;
    /**
     * Constructor inherits VRFConsumerBase
     * 
     * Network: Rinkby
     * Chainlink VRF Coordinator address: 0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B
     * LINK token address:                0x01BE23585060835E02B77ef475b0Cc51aA1e0709
     * Key Hash: 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311
     */
    constructor(address _governance) 
        VRFConsumerBase(
            0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B, // VRF Coordinator
            0x01BE23585060835E02B77ef475b0Cc51aA1e0709  // LINK Token
        ) public
    {
        keyHash = 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311;
        fee = 0.1 * 10 ** 18; // 0.1 LINK
        governance = governance_interface(_governance);
        admin= msg.sender;
    }

    /** 
     * Requests randomness from a user-provided seed
     */
     
    function getRandom(uint256 userProvidedSeed, uint256 lotteryId) public {
        require(LINK.balanceOf(address(this)) > fee, "Not enough LINK - fill contract with faucet");
        bytes32 _requestId = requestRandomness(keyHash, fee, userProvidedSeed);
        requestIds[_requestId] = lotteryId;
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function withdrawLink() external {
        require(msg.sender==admin,"Not admin");
        require(LINK.transfer(msg.sender, LINK.balanceOf(address(this))), "Unable to transfer");
    }
    
    function fulfillRandomness(bytes32 requestId, uint256 randomness) external override {
        require(msg.sender == vrfCoordinator, "Fulillment only permitted by Coordinator");
        most_recent_random = randomness;
        uint lotteryId = requestIds[requestId];
        randomNumber[lotteryId] = randomness;
        lottery_interface(governance.lottery()).fulfill_random(randomness);
    }
}
//rinkby contract address 0x63D896c0831905913EA42490A9883d83ffACF592