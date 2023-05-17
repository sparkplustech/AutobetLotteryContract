pragma solidity ^0.8.7;
// SPDX-License-Identifier: Unlicensed
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol";
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

contract AutobetUser is 
    AutomationCompatibleInterface,
    VRFV2WrapperConsumerBase,
    ConfirmedOwner
{
    
    using SafeMath for uint256;
    uint256 public lotteryId = 1;
    uint256 public ownerId = 1;
    uint256 public partnerId = 0;
    uint256 public bregisterFee = 10;
    uint256 public lotteryCreateFee = 10;
    uint256 public transferFeePerc = 10;
    uint256 public tokenEarnPercent = 5;
    uint256 public defaultRolloverday = 5;
    address public tokenAddress;
    address public admin;
    bool public callresult;

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
        uint256 amountEarned;
        uint256 commissionEarned;
        uint256 maxPrize;
        uint256 minPrize;
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

    struct RequestStatus {
        uint256 paid; // amount paid in link
        bool fulfilled; // whether the request has been successfully fulfilled
        uint256[] randomWords;
    }
    mapping(uint256 => RequestStatus) public s_requests;

    modifier onlyowner() {
        require(organisationbyaddr[msg.sender].active, "Not a organisation");
        _;
    }

    modifier onlyAdmin() {
        require(admin == msg.sender, "not-a-admin");
        _;
    }
    uint32 callbackGasLimit = 700000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFV2Wrapper.getConfig().maxNumWords.
    uint32 numWords = 1;

    mapping(uint256 => OwnerData) public organisationbyid;
    mapping(address => OwnerData) public organisationbyaddr;
    mapping(address => PartnerData) public partnerbyaddr;
    mapping(uint256 => PartnerData) public partnerbyid;
    // Mapping lottery id => details of the lottery.
    mapping(address => uint256) public amountspend;
    mapping(address => uint256) public refereeEarned;
    mapping(address => uint256) public amountwon;

    mapping(address => uint256) public tokenearned;
    mapping(address => uint256) public tokenredeemed;
    mapping(uint256 => uint256) public lotterySales;

    mapping(uint256 => uint256) public spinNumbers;
    mapping(uint256 => address) public spinBuyer;

    mapping(uint256 => uint256) private missilecodes;

    mapping(address => uint256[]) private userlotterydata;
    mapping(address => uint256[]) private partnerlotterydata;

    mapping(address => uint256[]) private orglotterydata;

    // Mapping of lottery id => user address => no of tickets
    mapping(uint256 => mapping(address => uint256)) public lotteryTickets;
    mapping(string => bool) public TicketsList;

    event RegisterBookie(
        uint256 indexed ownerId,
        address _owner,
        string _name,
        address _referee
    );

    event LotteryBought(
        uint256[] numbers,
        uint256 indexed lotteryId,
        uint256 boughtOn,
        address indexed useraddress,
        uint256 drawOn,
        uint256 paid
    );

    event LotteryResult(
        address useraddressdata,
        uint256 indexed lotteryId,
        uint256 drawOn
    );

    event WinnerPaid(
        address indexed useraddressdata,
        uint256 indexed lotteryId,
        uint256 amountwon
    );

    event PartnerPaid(
        address indexed partneradddress,
        uint256 indexed lotteryId,
        uint256 amountpaid
    );

    event SpinLotteryResult(
        address indexed useraddressdata,
        uint256 indexed lotteryId,
        uint256 selectedNum,
        uint256 winnerNum,
        uint256 date
    );

    constructor(
        address _tokenAddress
    )
        ConfirmedOwner(msg.sender)
        VRFV2WrapperConsumerBase(
            0x779877A7B0D9E8603169DdbD7836e478b4624789, // LINK Token
            0xab18414CD93297B0d12ac29E63Ca20f515b3DB46
        )
    {
        admin = msg.sender;
        tokenAddress = _tokenAddress;
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
            amountEarned: 0,
            commissionEarned: 0,
            minPrize: 0,
            maxPrize: 1 * 10 ** 30
        });
        organisationbyid[ownerId++] = OwnerData({
            id: ownerId,
            userAddress: msg.sender,
            referee: address(0),
            name: "Autobet",
            phoneno: "",
            dob: 0,
            resiAddress: "",
            email: "autobetlottery@gmail.com",
            active: true,
            amountEarned: 0,
            commissionEarned: 0,
            minPrize: 0,
            maxPrize: 1 * 10 ** 30
        });
    }

    function setCallresult(bool _callresult) external {
        callresult = _callresult;
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
        uint256 median = (_minPrize.add(_maxPrize)).div(2);
        uint256 fees = (median * bregisterFee).div(100);
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
            amountEarned: 0,
            commissionEarned: 0,
            minPrize: _minPrize,
            maxPrize: _maxPrize
        });
        organisationbyid[ownerId++] = OwnerData({
            id: ownerId,
            userAddress: _owner,
            name: _name,
            referee: _referee,
            resiAddress: _resiAddress,
            active: true,
            phoneno: _phoneno,
            dob: _dob,
            email: _email,
            amountEarned: 0,
            commissionEarned: 0,
            minPrize: _minPrize,
            maxPrize: _maxPrize
        });
        organisationbyaddr[admin].commissionEarned += msg.value;
        emit RegisterBookie(ownerId, _owner, _name, _referee);
    }

    function buyNormalLottery(
        uint256[] memory numbers,
        uint256 lotteryid,
        string memory hash
    ) public payable {
        LotteryData storage LotteryDatas = lottery[lotteryid];
        LotteryDate storage LotteryDates = lotteryDates[lotteryid];
        require(msg.value == LotteryDatas.entryFee, "Entry Fee not met");
        require(
            numbers.length == LotteryDatas.pickNumbers,
            "slots size not meet"
        );
        require(!TicketsList[hash], "Number Already claimed");

        if (LotteryDatas.minPlayers <= lotterySales[lotteryid]) {
            require(
                block.timestamp < LotteryDates.endTime,
                "Time passed to buy"
            );
        }
        if (
            block.timestamp > LotteryDates.endTime &&
            LotteryDatas.lotteryType == LotteryType.mrl
        ) {
            LotteryDates.drawTime = LotteryDates.drawTime.add(
                LotteryDatas.rolloverperct.mul(86400)
            );
            LotteryDates.endTime = LotteryDates.endTime.add(
                LotteryDatas.rolloverperct.mul(86400)
            );
        }

        TicketsList[hash] = true;
        lotteryTickets[lotteryid][msg.sender] += 1;
        LotteryDatas.Tickets.push(
            TicketsData({
                lotteryId: lotteryid,
                userAddress: msg.sender,
                numbersPicked: numbers,
                boughtOn: block.timestamp
            })
        );
        amountspend[msg.sender] += msg.value;
        organisationbyaddr[LotteryDatas.ownerAddress].amountEarned += msg.value;
        userlotterydata[msg.sender].push(lotteryid);
        lotterySales[lotteryid]++;
        tokenearned[msg.sender] += (
            (LotteryDatas.entryFee * tokenEarnPercent).div(100)
        );
        if (LotteryDatas.lotteryType == LotteryType.mine) {
            minelottery[lotteryid].push(numbers[0]);
        }

        emit LotteryBought(
            numbers,
            lotteryid,
            block.timestamp,
            msg.sender,
            LotteryDates.drawTime,
            LotteryDatas.entryFee
        );
    }

    function buySpinnerLottery(
        uint256 numbers,
        uint256 lotteryid
    ) public payable {
        LotteryData storage LotteryDatas = lottery[lotteryid];
        LotteryDate storage LotteryDates = lotteryDates[lotteryid];
        require(msg.value == LotteryDatas.entryFee, "Entry Fee not met");
        require(
            LotteryDatas.status == LotteryState.open,
            "Other player playing"
        );
        uint256[] memory numbarray = new uint256[](1);
        numbarray[0] = numbers;
        LotteryDatas.status = LotteryState.blocked;
        lotteryTickets[lotteryid][msg.sender] += 1;
        LotteryDatas.Tickets.push(
            TicketsData({
                lotteryId: lotteryid,
                userAddress: msg.sender,
                numbersPicked: numbarray,
                boughtOn: block.timestamp
            })
        );
        amountspend[msg.sender] += msg.value;
        organisationbyaddr[LotteryDatas.ownerAddress].amountEarned += msg.value;
        userlotterydata[msg.sender].push(lotteryid);
        lotterySales[lotteryid]++;
        tokenearned[msg.sender] += (
            (LotteryDatas.entryFee * tokenEarnPercent).div(100)
        );
        emit LotteryBought(
            numbarray,
            lotteryid,
            block.timestamp,
            msg.sender,
            LotteryDates.drawTime,
            LotteryDatas.entryFee
        );
        getWinners(lotteryid, numbers, msg.sender);
    }

    function buyMissilelottery(uint256 code, uint256 lotteryid) public payable {
        LotteryData storage LotteryDatas = lottery[lotteryid];
        LotteryDate storage LotteryDates = lotteryDates[lotteryid];
        require(msg.value == LotteryDatas.entryFee, "Entry Fee not met");
        uint256[] memory numbarray = new uint256[](1);
        numbarray[0] = code;
        lotteryTickets[lotteryid][msg.sender] += 1;
        LotteryDatas.Tickets.push(
            TicketsData({
                lotteryId: lotteryid,
                userAddress: msg.sender,
                numbersPicked: numbarray,
                boughtOn: block.timestamp
            })
        );
        amountspend[msg.sender] += msg.value;
        organisationbyaddr[LotteryDatas.ownerAddress].amountEarned += msg.value;
        userlotterydata[msg.sender].push(lotteryid);
        lotterySales[lotteryid]++;
        tokenearned[msg.sender] += (
            (LotteryDatas.entryFee * tokenEarnPercent).div(100)
        );
        emit LotteryBought(
            numbarray,
            lotteryid,
            block.timestamp,
            msg.sender,
            LotteryDates.drawTime,
            LotteryDatas.entryFee
        );
        if (code == missilecodes[lotteryid]) {
            requestIds[
                79605497052302279665647778512986110346654820553100948541933326299138325266895
            ] = lotteryid;
            LotteryDatas.status = LotteryState.resultdone;
            LotteryDatas.lotteryWinner = msg.sender;
            paywinner(
                lotteryid,
                79605497052302279665647778512986110346654820553100948541933326299138325266895
            );
        } else {
            if (block.timestamp > LotteryDates.endTime) {
                LotteryDates.level = LotteryDates.level + 1;
                LotteryDates.drawTime = LotteryDates.drawTime.add(
                    defaultRolloverday.mul(86400)
                );
                LotteryDates.endTime = LotteryDates.endTime.add(
                    defaultRolloverday.mul(86400)
                );
                uint256 totalSaleProfit = lotterySales[lotteryid] *
                    LotteryDatas.entryFee;
                LotteryDatas.totalPrize = LotteryDatas.totalPrize.add(
                    totalSaleProfit.mul(LotteryDatas.rolloverperct).div(100)
                );
                organisationbyaddr[LotteryDatas.ownerAddress]
                    .amountEarned -= totalSaleProfit
                    .mul(LotteryDatas.rolloverperct)
                    .div(100);
            }
        }
    }

    function updateMinMax(
        uint256 _minPrize,
        uint256 _maxPrize
    ) public payable onlyowner {
        require(_maxPrize > 0, "Cant be below zero");
        require(_minPrize > 0, "Cant be below zero");
        uint256 median = ((_minPrize.add(_maxPrize)).mul(10 ** 18)).div(2);
        uint256 fees = (median * bregisterFee).div(100);
        require(fees == msg.value, "Register Fee not matching");
        uint256 ids = organisationbyaddr[msg.sender].id;
        organisationbyaddr[msg.sender].minPrize = _minPrize;
        organisationbyaddr[msg.sender].maxPrize = _maxPrize;
        organisationbyid[ids].minPrize = _minPrize;
        organisationbyid[ids].maxPrize = _maxPrize;
        organisationbyaddr[admin].commissionEarned += msg.value;
    }

    function getUserlotteries(
        address useraddress
    ) external view returns (uint256[] memory lotteryids) {
        uint256[] memory lotteries = new uint256[](
            userlotterydata[useraddress].length
        );
        for (uint256 i = 0; i < userlotterydata[useraddress].length; i++) {
            lotteries[i] = userlotterydata[useraddress][i];
        }
        return lotteries;
    }

    function getPartnerlotteries(
        address partneraddress
    ) external view returns (uint256[] memory lotteryids) {
        uint256[] memory lotteries = new uint256[](
            partnerlotterydata[partneraddress].length
        );
        for (
            uint256 i = 0;
            i < partnerlotterydata[partneraddress].length;
            i++
        ) {
            lotteries[i] = partnerlotterydata[partneraddress][i];
        }
        return lotteries;
    }

    function setTokenAddress(address _tokenAddress) external onlyAdmin {
        tokenAddress = _tokenAddress;
    }


    function withdrawAdmin() external payable onlyAdmin {
        uint256 amountEarned = organisationbyaddr[admin].commissionEarned;
        payable((msg.sender)).transfer(amountEarned);
        organisationbyaddr[admin].commissionEarned = 0;
    }

    function withdrawrefereecommission() external payable {
        uint256 amountEarned = refereeEarned[msg.sender];
        payable((msg.sender)).transfer(amountEarned);
        refereeEarned[msg.sender] = 0;
    }

    function withdrawETH() external payable onlyAdmin {
        payable(msg.sender).transfer(address(this).balance);
    }

    function withdrawLink() external onlyAdmin {
        require(
            LINK.transfer(msg.sender, LINK.balanceOf(address(this))),
            "Unable to transfer"
        );
    }

    function transferToken(
        uint256 amount,
        address to,
        address tokenAdd
    ) external onlyAdmin {
        require(
            amount <= IERC20(tokenAdd).balanceOf(address(this)),
            "low balance"
        );
        IERC20(tokenAdd).transfer(to, amount);
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0));
        organisationbyaddr[newAdmin] = organisationbyaddr[msg.sender];
        admin = newAdmin;
    }

    function addPartnerDetails(
        string memory _name,
        string memory _logoHash,
        bool _status,
        string memory _websiteAdd,
        address _partnerAddress,
        uint256 _createdOn
    ) external {
        assert(_partnerAddress != address(0));
        require(
            partnerbyaddr[_partnerAddress].partnerAddress == address(0),
            "Already registered"
        );
        partnerId++;
        partnerbyaddr[_partnerAddress] = PartnerData({
            partnerId: partnerId,
            name: _name,
            logoHash: _logoHash,
            status: _status,
            websiteAdd: _websiteAdd,
            partnerAddress: _partnerAddress,
            createdOn: _createdOn
        });
        partnerbyid[partnerId] = PartnerData({
            partnerId: partnerId,
            name: _name,
            logoHash: _logoHash,
            status: _status,
            websiteAdd: _websiteAdd,
            partnerAddress: _partnerAddress,
            createdOn: _createdOn
        });
    }

    function EditPartnerDetails(
        string memory _name,
        string memory _logoHash,
        bool _status,
        string memory _websiteAdd,
        address _partnerAddress,
        uint256 _createdOn
    ) external {
        assert(_partnerAddress != address(0));
        require(
            partnerbyaddr[_partnerAddress].partnerAddress != address(0),
            "Not Already registered"
        );
        require(
            partnerbyaddr[_partnerAddress].partnerAddress == _partnerAddress,
            "Wrong address to update"
        );
        partnerbyaddr[_partnerAddress] = PartnerData({
            partnerId: partnerbyaddr[_partnerAddress].partnerId,
            name: _name,
            logoHash: _logoHash,
            status: _status,
            websiteAdd: _websiteAdd,
            partnerAddress: _partnerAddress,
            createdOn: _createdOn
        });
        partnerbyid[partnerbyaddr[_partnerAddress].partnerId] = PartnerData({
            partnerId: partnerbyaddr[_partnerAddress].partnerId,
            name: _name,
            logoHash: _logoHash,
            status: _status,
            websiteAdd: _websiteAdd,
            partnerAddress: _partnerAddress,
            createdOn: _createdOn
        });
    }
}