pragma solidity ^0.8.7;
// SPDX-License-Identifier: Unlicensed

import "@chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol";
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

interface IERC20 {
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

contract Autobet is
    AutomationCompatibleInterface,
    VRFV2WrapperConsumerBase,
    ConfirmedOwner
{
    using SafeMath for uint256;
    uint256 public RID;
    uint256 public lotteryId = 1;
    uint256 public ownerId = 1;
    uint256 public partnerId = 0;
    uint256 public bregisterFee = 10;
    uint256 public lotteryCreateFee = 10;
    uint256 public transferFeePerc = 10;
    uint256 public partnerRewardPerc = 10;
    uint256 public tokenEarnPercent = 5;
    address public tokenAddress;
    bytes32 hashresult;
    uint256 public lastNumber = 0;
    // address[] partners;
    address public admin;
    bool public callresult;

    enum LotteryState {
        open,
        close,
        resultdone,
        rollover
    }

    enum LotteryType {
        revolver,
        mine,
        mrl,
        missile
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

    struct TicketsData {
        address userAddress;
        uint256 boughtOn;
        uint256 lotteryId;
        uint256[] numbersPicked;
    }

    struct LotteryData {
        uint256 lotteryId;
        uint256 pickNumbers; //ticket numbers need to be selected
        uint256 capacity; // Total size of lottery.
        uint256 entryFee;
        uint256 totalPrize; // Total wining price.
        uint256 minPlayers;
        uint256 partnerId;
        uint256 rolloverperct;
        address lotteryWinner;
        address ownerAddress;
        LotteryState status;
        TicketsData[] Tickets;
        LotteryType lotteryType;
    }
    struct LotteryDate {
        uint256 lotteryId;
        uint256 startTime; // Start time of Lottery.
        uint256 endTime; // End time of lottery.
        uint256 drawTime;
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
    mapping(uint256 => LotteryData) public lottery;
    mapping(uint256 => LotteryDate) public lotteryDates;

    mapping(address => uint256) public amountspend;
    mapping(address => uint256) public refereeEarned;
    mapping(address => uint256) public amountwon;

    mapping(address => uint256) public tokenearned;
    mapping(address => uint256) public tokenredeemed;
    mapping(uint256 => uint256) public lotterySales;

    mapping(uint256 => uint256) public requestIds;
    mapping(uint256 => uint256) public randomNumber;
    mapping(uint256 => uint256) public spinNumbers;
    mapping(uint256 => address) public spinBuyer;

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

    event CreatedLottery(
        uint256 indexed lotteryId,
        uint256 entryfee,
        uint256 picknumbers,
        uint256 totalPrize,
        uint256 capacity,
        address indexed owner,
        uint256 startTime,
        uint256 indexed ownerid
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

    event SpinLotteryResult(
        address indexed useraddressdata,
        uint256 indexed lotteryId,
        uint256 selectedNum,
        uint256 winnerNum,
        uint256 date
    );

    event partneradded(
        uint256 partnerId,
        string _name,
        string _LogoHash,
        bool status,
        string _websiteAdd,
        address _PartnerAddress,
        uint256 _CreatedOn
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
            maxPrize: _minPrize
        });
        organisationbyaddr[admin].commissionEarned += msg.value;
        emit RegisterBookie(ownerId, _owner, _name, _referee);
    }

    function createLottery(
        uint256 entryfee,
        uint256 picknumbers,
        uint256 totalPrize,
        uint256 startTime,
        uint256 endtime,
        uint256 drawtime,
        uint256 capacity,
        uint256 partner,
        uint256 rolloverperct,
        LotteryType lottype
    ) public payable onlyowner {
        require(
            organisationbyaddr[msg.sender].minPrize <= totalPrize,
            "Not allowed winning amount"
        );
        require(
            organisationbyaddr[msg.sender].maxPrize >= totalPrize,
            "Not allowed winning amount"
        );
        require(totalPrize > 0, "Low totalPrice");
        require(
            totalPrize.add((totalPrize * lotteryCreateFee).div(100)) ==
                msg.value,
            "Amount not matching"
        );
        require(picknumbers <= capacity, "capacity is less");
        require(startTime >= block.timestamp, "Start time passed");
        require(startTime < endtime, "End time less than start time");
        require(
            rolloverperct <= 50,
            "Rollover percentage can't be more than 50"
        );
        if (lottype == LotteryType.revolver) {
            require(picknumbers == 1, "Only 1 number allowed");
        }
        if (lottype == LotteryType.mine) {
            require(picknumbers == 1, "Only 1 number allowed");
        }
        lottery[lotteryId].partnerId = partner;
        lottery[lotteryId].lotteryId = lotteryId;
        lottery[lotteryId].rolloverperct = rolloverperct;
        lottery[lotteryId].entryFee = entryfee;
        lottery[lotteryId].pickNumbers = picknumbers;
        lottery[lotteryId].totalPrize = totalPrize;
        lotteryDates[lotteryId].startTime = startTime;
        lotteryDates[lotteryId].endTime = endtime;
        lotteryDates[lotteryId].lotteryId = lotteryId;
        lotteryDates[lotteryId].drawTime = drawtime;
        lottery[lotteryId].capacity = capacity;
        lottery[lotteryId].status = LotteryState.open;
        lottery[lotteryId].ownerAddress = msg.sender;
        lottery[lotteryId].lotteryType = lottype;
        lottery[lotteryId].minPlayers =
            (totalPrize).div(entryfee) +
            (totalPrize).mul(10).div(entryfee).div(100);
        orglotterydata[msg.sender].push(lotteryId);
        organisationbyaddr[admin].commissionEarned += (totalPrize *
            lotteryCreateFee).div(100);
        if (organisationbyaddr[msg.sender].referee != address(0)) {
            refereeEarned[organisationbyaddr[msg.sender].referee] =
                refereeEarned[organisationbyaddr[msg.sender].referee] +
                totalPrize.div(100);
        }
        partnerlotterydata[partnerbyid[partner].partnerAddress].push(lotteryId);
        emit CreatedLottery(
            lotteryId,
            entryfee,
            picknumbers,
            totalPrize,
            capacity,
            msg.sender,
            startTime,
            organisationbyaddr[msg.sender].id
        );
        lotteryId++;
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
        require(LotteryDatas.lotteryWinner == address(0), "Winner done");
        uint256[] memory numbarray = new uint256[](1);
        numbarray[0] = numbers;
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

    function checkUpkeep(
        bytes calldata
    ) external view override returns (bool upkeepNeeded, bytes memory result) {
        upkeepNeeded = false;
        require(!callresult, "Another Result running");
        for (uint256 i = 1; i < lotteryId; i++) {
            if (lottery[i].lotteryType == LotteryType.mrl) {
                if (lottery[i].status != LotteryState.resultdone) {
                    if (lottery[i].minPlayers <= lotterySales[i]) {
                        if (lotteryDates[i].drawTime < block.timestamp) {
                            upkeepNeeded = true;
                            return (upkeepNeeded, "");
                        }
                    }
                }
            }
        }
    }

    function performUpkeep(bytes calldata) external override {
        require(!callresult, "required call true");
        callresult = true;
        for (uint256 i = 1; i < lotteryId; i++) {
            if (lottery[i].lotteryType == LotteryType.mrl) {
                if (lottery[i].status != LotteryState.resultdone) {
                    if (lottery[i].minPlayers <= lotterySales[i]) {
                        if (lotteryDates[i].drawTime < block.timestamp) {
                            getWinners(i);
                        }
                    }
                }
            }
        }
    }

    function getWinners(uint256 i) internal {
        uint256 _requestId = requestRandomness(
            callbackGasLimit,
            requestConfirmations,
            numWords
        );
        RID = _requestId;
        requestIds[_requestId] = i;
    }

    function getWinners(
        uint256 i,
        uint256 selectedNum,
        address buyer
    ) internal {
        uint256 _requestId = requestRandomness(
            callbackGasLimit,
            requestConfirmations,
            numWords
        );
        RID = _requestId;
        requestIds[_requestId] = i;
        spinNumbers[_requestId] = selectedNum;
        spinBuyer[_requestId] = buyer;
        s_requests[_requestId] = RequestStatus({
            paid: VRF_V2_WRAPPER.calculateRequestPrice(callbackGasLimit),
            randomWords: new uint256[](0),
            fulfilled: false
        });
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomness
    ) internal override {
        require(s_requests[_requestId].paid > 0, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomness;
        randomNumber[_requestId] = _randomness[0];
        getdraw(_randomness[_requestId], requestIds[_requestId], _requestId);
    }

    function getdraw(
        uint256 num,
        uint256 lotteryid,
        uint256 requestId
    ) internal {
        LotteryData storage LotteryDatas = lottery[lotteryid];
        LotteryDate storage LotteryDates = lotteryDates[lotteryid];
        if (LotteryDatas.lotteryType == LotteryType.mrl) {
            num = num.mod(LotteryDatas.Tickets.length);
            LotteryDatas.status = LotteryState.resultdone;
            LotteryDatas.lotteryWinner = LotteryDatas.Tickets[num].userAddress;
            emit LotteryResult(
                LotteryDatas.Tickets[num].userAddress,
                lotteryid,
                block.timestamp
            );
            paywinner(
                LotteryDatas.Tickets[num].userAddress,
                lotteryid,
                requestId
            );
        } else {
            num = num.mod(LotteryDatas.capacity);
            lastNumber = num;
            LotteryDatas.lotteryWinner = spinBuyer[requestId];
            emit SpinLotteryResult(
                spinBuyer[requestId],
                lotteryid,
                spinNumbers[requestId],
                num,
                block.timestamp
            );
            if (spinNumbers[requestId] == num) {
                LotteryDatas.status = LotteryState.resultdone;
                LotteryDatas.lotteryWinner = spinBuyer[requestId];
                paywinner(spinBuyer[requestId], lotteryid, requestId);
            } else {
                LotteryDatas.status = LotteryState.rollover;
                uint256 newTotalPrize = LotteryDatas
                    .totalPrize
                    .mul(LotteryDatas.rolloverperct)
                    .div(100) -
                    LotteryDatas.totalPrize.mul(lotteryCreateFee).div(100);
                lottery[lotteryId].partnerId = LotteryDatas.partnerId;
                lottery[lotteryId].lotteryId = lotteryId;
                lottery[lotteryId].entryFee = LotteryDatas.entryFee;
                lottery[lotteryId].pickNumbers = LotteryDatas.pickNumbers;
                lottery[lotteryId].totalPrize = newTotalPrize;
                lotteryDates[lotteryId].startTime = LotteryDates.startTime;
                lottery[lotteryId].rolloverperct = LotteryDatas.rolloverperct;
                lotteryDates[lotteryId].endTime = LotteryDates.endTime;
                lotteryDates[lotteryId].lotteryId = lotteryId;
                lotteryDates[lotteryId].drawTime = LotteryDates.drawTime;
                lottery[lotteryId].capacity = LotteryDatas.capacity;
                lottery[lotteryId].status = LotteryState.open;
                lottery[lotteryId].ownerAddress = LotteryDatas.ownerAddress;
                lottery[lotteryId].lotteryType = LotteryDatas.lotteryType;
                lottery[lotteryId].minPlayers = LotteryDatas.minPlayers;
                orglotterydata[LotteryDatas.ownerAddress].push(lotteryId);
                organisationbyaddr[admin].commissionEarned += newTotalPrize;
                emit CreatedLottery(
                    lotteryId,
                    LotteryDatas.entryFee,
                    LotteryDatas.pickNumbers,
                    newTotalPrize,
                    LotteryDatas.capacity,
                    LotteryDatas.ownerAddress,
                    LotteryDates.startTime,
                    organisationbyaddr[LotteryDatas.ownerAddress].id
                );
                lotteryId++;
            }
        }
    }

    function paywinner(
        address useraddressdata,
        uint256 lotteryid,
        uint256 requestId
    ) public payable {
        require(requestIds[requestId] == lotteryid, "Lottery Id mismatch");
        LotteryData storage LotteryDatas = lottery[lotteryid];
        if (useraddressdata != address(0)) {
            uint256 prizeAmt = LotteryDatas.totalPrize;
            uint256 subtAmt = prizeAmt.mul(transferFeePerc).div(100);
            uint256 finalAmount = prizeAmt.sub(subtAmt);
            payable(useraddressdata).transfer(finalAmount);
            organisationbyaddr[admin].commissionEarned += subtAmt;
            if (LotteryDatas.lotteryType == LotteryType.revolver) {
                uint256 partnerpay = prizeAmt.mul(partnerRewardPerc).div(100);
                payable(partnerbyid[LotteryDatas.partnerId].partnerAddress)
                    .transfer(partnerpay);
            }
            emit WinnerPaid(useraddressdata, lotteryid, finalAmount);
        }
        callresult = false;
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

    function getOrglotteries(
        address useraddress
    ) external view returns (uint256[] memory lotterids) {
        uint256[] memory lotteries = new uint256[](
            orglotterydata[useraddress].length
        );
        for (uint256 i = 0; i < orglotterydata[useraddress].length; i++) {
            lotteries[i] = orglotterydata[useraddress][i];
        }
        return lotteries;
    }

    function getLotteryNumbers(
        uint256 lotteryid
    )
        public
        view
        returns (uint256[] memory tickets, address[] memory useraddress)
    {
        LotteryData storage LotteryDatas = lottery[lotteryid];
        address[] memory useraddressdata = new address[](
            LotteryDatas.Tickets.length
        );
        uint256[] memory userdata = new uint256[](
            LotteryDatas.Tickets.length * LotteryDatas.pickNumbers
        );
        uint256 p = 0;
        uint256 k = 0;
        for (uint256 i = 0; i < LotteryDatas.Tickets.length; i++) {
            useraddressdata[p++] = LotteryDatas.Tickets[i].userAddress;
            for (uint256 j = 0; j < LotteryDatas.pickNumbers; j++) {
                userdata[k++] = uint256(
                    LotteryDatas.Tickets[i].numbersPicked[j]
                );
            }
        }
        return (userdata, useraddressdata);
    }

    function withdrawcommission() external payable {
        uint256 amountEarned = organisationbyaddr[msg.sender].amountEarned;
        uint256 subtAmt = amountEarned.mul(transferFeePerc).div(100);
        uint256 finalAmount = amountEarned.sub(subtAmt);
        payable((msg.sender)).transfer(finalAmount);
        organisationbyaddr[admin].commissionEarned += subtAmt;
        organisationbyaddr[msg.sender].commissionEarned += finalAmount;
        organisationbyaddr[msg.sender].amountEarned = 0;
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

    function updateFee(
        uint256 _lotteryCreateFee,
        uint256 _transferFeePerc,
        uint256 _tokenEarnPercent,
        uint256 _partnerRewardPerc
    ) external onlyAdmin {
        lotteryCreateFee = _lotteryCreateFee;
        transferFeePerc = _transferFeePerc;
        tokenEarnPercent = _tokenEarnPercent;
        partnerRewardPerc = _partnerRewardPerc;
    }

    function contractBalance()
        external
        view
        onlyAdmin
        returns (uint256 balance)
    {
        return address(this).balance;
    }

    function redeemTokens() external {
        require(
            tokenearned[msg.sender] <=
                IERC20(tokenAddress).balanceOf(address(this)),
            "low balance"
        );
        IERC20(tokenAddress).transfer(msg.sender, tokenearned[msg.sender]);
        tokenearned[msg.sender] = 0;
    }

    function transferToken(
        uint256 amount,
        address to,
        address tokenAdd
    ) external {
        require(
            amount <= IERC20(tokenAdd).balanceOf(address(this)),
            "low balance"
        );
        IERC20(tokenAdd).transfer(to, amount);
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0));
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
        emit partneradded(
            partnerId,
            _name,
            _logoHash,
            _status,
            _websiteAdd,
            _partnerAddress,
            _createdOn
        );
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
