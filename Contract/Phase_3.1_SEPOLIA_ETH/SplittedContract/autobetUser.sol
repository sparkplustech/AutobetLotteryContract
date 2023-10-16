pragma solidity ^0.8.7;
// SPDX-License-Identifier: Unlicensed

contract autobetlottery2 {

    uint256 public bregisterFee = 10;
    address public admin;
    uint256 public ownerId = 1;
    uint256 public partnerId = 0;
    

mapping(address => OwnerData) public organisationbyaddr;
mapping(address => uint256) public amountEarned;
mapping(address => uint256) public registerationFees;
mapping(uint256 => address) public organisationbyid;
mapping(address => PartnerData) public partnerbyaddr;
mapping(uint256 => address) public partnerids;


//  constructor(address _tokenAddress);


modifier onlyowner() {
        require(organisationbyaddr[msg.sender].active, "Not a organisation");
        _;
    }

     struct PartnerData {
        string name;
        string logoHash;
        bool status;
        string websiteAdd;
        address partnerAddress;
        uint256 createdOn;
        uint256 partnerId;
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
        registerationFees[admin] += msg.value;
        organisationbyid[ownerId++] = _owner;
    }



}