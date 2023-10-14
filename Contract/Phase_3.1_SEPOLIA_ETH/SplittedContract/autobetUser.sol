pragma solidity ^0.8.7;
// SPDX-License-Identifier: Unlicensed

contract autobetUser {

    uint256 public bregisterFee = 10;
    address public admin;
    uint256 public ownerId = 1;
    

mapping(address => OwnerData) public organisationbyaddr;
mapping(address => uint256) public amountEarned;
mapping(address => uint256) public commissionEarned;
mapping(uint256 => address) public organisationbyid;


//  constructor(address _tokenAddress);


modifier onlyowner() {
        require(organisationbyaddr[msg.sender].active, "Not a organisation");
        _;
    }

    constructor()
    {
        admin = msg.sender;
        organisationbyaddr[msg.sender] = OwnerData({
            id: ownerId,
            userAddress: msg.sender,
            referee: address(0),
            name: "Autobet",
            phoneno: "",
            dob: 0,
            resiAddress: "",
            email: "autobetlottery@gmail.com",
            active: true,
            minPrize: 0,
            maxPrize: 1 * 10 ** 30
        });
        amountEarned[msg.sender] = 0;
        commissionEarned[msg.sender] = 0;
        organisationbyid[ownerId++] = msg.sender;
    }

    function isCreator(address creatorAddress) public view returns (bool) {
    return organisationbyaddr[creatorAddress].active;
}

function getCreatorData(address creatorAddress) public view returns (OwnerData memory) {
    return organisationbyaddr[creatorAddress];
}

     struct OwnerData {
        bool active;
        address userAddress;
        address referee;
        string name;
        string phoneno;
        uint256 dob;
        string email;
        string resiAddress;
        uint256 id;
        uint256 maxPrize;
        uint256 minPrize;
    }

function addOrganisation(
        address _owner,
        address _referee,
        string memory _name,
        string memory _phoneno,
        uint256 _dob,
        string memory _email,
        string memory _resiAddress,
        uint256 _minPrize,
        uint256 _maxPrize
    ) external payable {
        assert(_owner != address(0));
        uint256 median = (_minPrize + (_maxPrize))/(2);
        uint256 fees = (median * bregisterFee)/(100);
        require(
            organisationbyaddr[_owner].userAddress == address(0),
            "Already registered"
        );
        require(fees == msg.value, "Register Fee not matching");
        organisationbyaddr[_owner] = OwnerData({
            id: ownerId,
            userAddress: _owner,
            name: _name,
            referee: _referee,
            resiAddress: _resiAddress,
            active: true,
            phoneno: _phoneno,
            dob: _dob,
            email: _email,
            minPrize: _minPrize,
            maxPrize: _maxPrize
        });
        amountEarned[_owner] = 0;
        commissionEarned[admin] += msg.value;
        organisationbyid[ownerId++] = _owner;
    }


}