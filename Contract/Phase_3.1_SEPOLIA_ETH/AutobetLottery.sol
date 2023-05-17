pragma solidity ^0.8.7;
// SPDX-License-Identifier: Unlicensed
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol";
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

interface AutobetUser {
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

    function organisationbyid(
        uint256 id
    ) external view returns (OwnerData memory);

    function organisationbyaddr(
        address id
    ) external view returns (OwnerData memory);

    function refereeEarned(address id) external view returns (uint256);

    function partnerbyaddr(
        address id
    ) external view returns (PartnerData memory);

    function partnerbyid(uint256 id) external view returns (PartnerData memory);
}

contract AutobetLottery is
    AutobetUser,
    AutomationCompatibleInterface,
    VRFV2WrapperConsumerBase,
    ConfirmedOwner
{
    using SafeMath for uint256;
    uint256 public lotteryId = 1;
    uint256 public lotteryCreateFee = 10;
    uint256 public transferFeePerc = 10;
    uint256 public minimumRollover = 100;
    uint256 public tokenEarnPercent = 5;
    uint256 public defaultRolloverday = 5;
    address public tokenAddress;
    address public admin;
    bool public callresult;
    AutobetUser users;

    enum LotteryState {
        open,
        close,
        resultdone,
        rollover,
        blocked
    }

    enum LotteryType {
        revolver,
        mine,
        mrl,
        missile
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
        uint256 partnershare;
        uint256 rolloverperct;
        uint256 deployedOn;
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
        uint16 level;
    }

    struct RequestStatus {
        uint256 paid; // amount paid in link
        bool fulfilled; // whether the request has been successfully fulfilled
        uint256[] randomWords;
    }
    mapping(uint256 => RequestStatus) public s_requests;

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

    // Mapping lottery id => details of the lottery.
    mapping(uint256 => LotteryData) public lottery;
    mapping(uint256 => LotteryDate) public lotteryDates;

    mapping(uint256 => uint256) public lotterySales;

    mapping(uint256 => uint256) public requestIds;
    mapping(uint256 => uint256) public randomNumber;
    mapping(uint256 => uint256) public spinNumbers;
    mapping(uint256 => address) public spinBuyer;

    mapping(uint256 => uint256[]) public minelottery;

    mapping(uint256 => uint256) private missilecodes;

    // mapping(address => uint256[]) private userlotterydata;
    // mapping(address => uint256[]) private partnerlotterydata;

    // mapping(address => uint256[]) private orglotterydata;

    // Mapping of lottery id => user address => no of tickets
    mapping(uint256 => mapping(address => uint256)) public lotteryTickets;
    mapping(string => bool) public TicketsList;

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

    event LotteryResult(
        address useraddressdata,
        uint256 indexed lotteryId,
        uint256 drawOn
    );

    event SpinLotteryResult(
        address indexed useraddressdata,
        uint256 indexed lotteryId,
        uint256 selectedNum,
        uint256 winnerNum,
        uint256 date
    );
    event LotteryBought(
        uint256[] numbers,
        uint256 indexed lotteryId,
        uint256 boughtOn,
        address indexed useraddress,
        uint256 drawOn,
        uint256 paid
    );

    event PartnerPaid(
        address indexed partneradddress,
        uint256 indexed lotteryId,
        uint256 amountpaid
    );
    event WinnerPaid(
        address indexed useraddressdata,
        uint256 indexed lotteryId,
        uint256 amountwon
    );

    constructor(
        address _tokenAddress,
        address _userAddress
    )
        ConfirmedOwner(msg.sender)
        VRFV2WrapperConsumerBase(
            0x779877A7B0D9E8603169DdbD7836e478b4624789, // LINK Token
            0xab18414CD93297B0d12ac29E63Ca20f515b3DB46
        )
    {
        users = AutobetUser(_userAddress);
        admin = msg.sender;
        tokenAddress = _tokenAddress;
    }

    function setCallresult(bool _callresult) external {
        callresult = _callresult;
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
        uint256 partnershare,
        LotteryType lottype
    ) public payable {
        require(
            users.organisationbyaddr[msg.sender].minPrize <= totalPrize,
            "Not allowed winning amount"
        );
        require(
            users.organisationbyaddr[msg.sender].maxPrize >= totalPrize,
            "Not allowed winning amount"
        );
        require(totalPrize > 0, "Low totalPrice");
        require(
            partnershare > 0 && partnershare <= 100,
            "Share can be 1 to 100"
        );
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
            require(capacity > 5, "Capacity should be greater than 5");
            require(picknumbers == 1, "Only 1 number allowed");
        }
        if (lottype == LotteryType.mine) {
            require(picknumbers == 1, "Only 1 number allowed");
        }
        if (lottype == LotteryType.missile) {
            require(picknumbers <= 10, " Only 10 combination allowed");
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
        lottery[lotteryId].deployedOn = block.timestamp;
        lotteryDates[lotteryId].level = 1;
        if (lottype != LotteryType.missile) {
            lottery[lotteryId].capacity = capacity;
        } else {
            missilecodes[lotteryId] = capacity;
            capacity = 0;
        }
        lottery[lotteryId].status = LotteryState.open;
        lottery[lotteryId].ownerAddress = msg.sender;
        lottery[lotteryId].lotteryType = lottype;
        lottery[lotteryId].partnershare = partnershare;
        lottery[lotteryId].minPlayers =
            (totalPrize).div(entryfee) +
            (totalPrize).mul(10).div(entryfee).div(100);
        users.orglotterydata[msg.sender].push(lotteryId);
        users.organisationbyaddr[admin].commissionEarned += (totalPrize *
            lotteryCreateFee).div(100);
        if (users.organisationbyaddr[msg.sender].referee != address(0)) {
            users.refereeEarned[users.organisationbyaddr[msg.sender].referee] =
                users.refereeEarned[
                    users.organisationbyaddr[msg.sender].referee
                ] +
                totalPrize.div(100);
        }
        users
            .partnerlotterydata[users.partnerbyid[partner].partnerAddress]
            .push(lotteryId);
        emit CreatedLottery(
            lotteryId,
            entryfee,
            picknumbers,
            totalPrize,
            capacity,
            msg.sender,
            startTime,
            users.organisationbyaddr[msg.sender].id
        );
        lotteryId++;
    }

    function checkUpkeep(
        bytes calldata
    ) external view override returns (bool upkeepNeeded, bytes memory result) {
        upkeepNeeded = false;
        require(!callresult, "Another Result running");
        for (uint256 i = 1; i < lotteryId; i++) {
            if (
                lottery[i].lotteryType == LotteryType.mrl ||
                lottery[i].lotteryType == LotteryType.mine
            ) {
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
            if (
                lottery[i].lotteryType == LotteryType.mrl ||
                lottery[i].lotteryType == LotteryType.mine
            ) {
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
        requestIds[_requestId] = i;
        s_requests[_requestId] = RequestStatus({
            paid: VRF_V2_WRAPPER.calculateRequestPrice(callbackGasLimit),
            randomWords: new uint256[](0),
            fulfilled: false
        });
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
        getdraw(randomNumber[_requestId], requestIds[_requestId], _requestId);
    }

    function getdraw(
        uint256 num,
        uint256 lotteryid,
        uint256 requestId
    ) internal {
        LotteryData storage LotteryDatas = lottery[lotteryid];
        if (
            LotteryDatas.lotteryType == LotteryType.mrl ||
            LotteryDatas.lotteryType == LotteryType.mine
        ) {
            num = num.mod(LotteryDatas.Tickets.length);
            LotteryDatas.status = LotteryState.resultdone;
            LotteryDatas.lotteryWinner = LotteryDatas.Tickets[num].userAddress;
            emit LotteryResult(
                LotteryDatas.Tickets[num].userAddress,
                lotteryid,
                block.timestamp
            );
            paywinner(lotteryid, requestId);
        } else {
            num = num.mod(LotteryDatas.capacity);
            num = num.add(1);
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
                paywinner(lotteryid, requestId);
            } else {
                callresult = false;
                createRevolverRollover(lotteryid);
            }
        }
    }

    function createRevolverRollover(uint256 lotteryid) internal {
        LotteryData storage LotteryDatas = lottery[lotteryid];
        LotteryDate storage LotteryDates = lotteryDates[lotteryid];
        uint256 newTotalPrize = LotteryDatas.totalPrize +
            LotteryDatas.entryFee.mul(LotteryDatas.rolloverperct).div(100);
        if (newTotalPrize >= minimumRollover) {
            LotteryDatas.status = LotteryState.rollover;
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
            lottery[lotteryId].deployedOn = block.timestamp;
            lottery[lotteryId].partnershare = LotteryDatas.partnershare;
            lotteryDates[lotteryId].level = LotteryDates.level + 1;
            users.orglotterydata[LotteryDatas.ownerAddress].push(lotteryId);
            users.organisationbyaddr[admin].commissionEarned += newTotalPrize;
            emit CreatedLottery(
                lotteryId,
                LotteryDatas.entryFee,
                LotteryDatas.pickNumbers,
                newTotalPrize,
                LotteryDatas.capacity,
                LotteryDatas.ownerAddress,
                LotteryDates.startTime,
                users.organisationbyaddr[LotteryDatas.ownerAddress].id
            );
            lotteryId++;
        } else {
            LotteryDatas.status = LotteryState.close;
        }
    }

    function paywinner(uint256 lotteryid, uint256 requestId) public payable {
        require(requestIds[requestId] == lotteryid, "Lottery Id mismatch");
        LotteryData storage LotteryDatas = lottery[lotteryid];
        address useraddressdata = LotteryDatas.lotteryWinner;
        if (useraddressdata != address(0)) {
            uint256 prizeAmt = LotteryDatas.totalPrize;
            uint256 subtAmt = prizeAmt.mul(transferFeePerc).div(100);
            uint256 finalAmount = prizeAmt.sub(subtAmt);
            payable(useraddressdata).transfer(finalAmount);
            emit WinnerPaid(useraddressdata, lotteryid, finalAmount);
            users.organisationbyaddr[admin].commissionEarned += subtAmt;
            uint256 totalSaleProfit = lotterySales[lotteryid] *
                LotteryDatas.entryFee;
            uint256 partnerpay = totalSaleProfit
                .mul(LotteryDatas.partnershare)
                .div(100);
            payable(users.partnerbyid[LotteryDatas.partnerId].partnerAddress)
                .transfer(partnerpay);
            users
                .organisationbyaddr[LotteryDatas.ownerAddress]
                .amountEarned -= partnerpay;
            emit PartnerPaid(
                users.partnerbyid[LotteryDatas.partnerId].partnerAddress,
                lotteryid,
                partnerpay
            );
        }
        callresult = false;
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
            if (LotteryDatas.lotteryType != LotteryType.missile) {
                for (uint256 j = 0; j < LotteryDatas.pickNumbers; j++) {
                    userdata[k++] = uint256(
                        LotteryDatas.Tickets[i].numbersPicked[j]
                    );
                }
            } else {
                userdata[k++] = uint256(
                    LotteryDatas.Tickets[i].numbersPicked[0]
                );
            }
        }
        return (userdata, useraddressdata);
    }

    function getMineLotteryNumbers(
        uint256 lotteryid
    ) public view returns (uint256[] memory numbers) {
        uint256[] memory number = new uint256[](minelottery[lotteryid].length);
        uint256 p = 0;
        for (uint256 i = 0; i < minelottery[lotteryid].length; i++) {
            number[p++] = minelottery[lotteryid][i];
        }
        return (number);
    }

    function withdrawcommission() external payable {
        uint256 amountEarned = users
            .organisationbyaddr[msg.sender]
            .amountEarned;
        uint256 subtAmt = amountEarned.mul(transferFeePerc).div(100);
        uint256 finalAmount = amountEarned.sub(subtAmt);
        payable(msg.sender).transfer(finalAmount);
        users.organisationbyaddr[admin].commissionEarned += subtAmt;
        users.organisationbyaddr[msg.sender].commissionEarned += finalAmount;
        users.organisationbyaddr[msg.sender].amountEarned = 0;
    }

    function withdrawAdmin() external payable onlyAdmin {
        uint256 amountEarned = users.organisationbyaddr[admin].commissionEarned;
        payable((msg.sender)).transfer(amountEarned);
        users.organisationbyaddr[admin].commissionEarned = 0;
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
        uint256 _minroll
    ) external onlyAdmin {
        lotteryCreateFee = _lotteryCreateFee;
        transferFeePerc = _transferFeePerc;
        tokenEarnPercent = _tokenEarnPercent;
        minimumRollover = _minroll;
    }

    function updateMinrollover(
        uint256 _minroll,
        uint256 _rolloverday
    ) external onlyAdmin {
        minimumRollover = _minroll;
        defaultRolloverday = _rolloverday;
    }

    function redeemTokens() external {
        require(
            users.tokenearned[msg.sender] <=
                IERC20(tokenAddress).balanceOf(address(this)),
            "low balance"
        );
        IERC20(tokenAddress).transfer(
            msg.sender,
            users.tokenearned[msg.sender]
        );
        users.tokenearned[msg.sender] = 0;
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
        users.organisationbyaddr[newAdmin] = users.organisationbyaddr[
            msg.sender
        ];
        admin = newAdmin;
    }
}
