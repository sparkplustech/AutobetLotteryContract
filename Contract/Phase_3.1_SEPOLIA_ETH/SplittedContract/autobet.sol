pragma solidity ^0.8.7;
// SPDX-License-Identifier: Unlicensed
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol";
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

interface IABUser {
    function isCreator(address) external view returns (bool);

    function getMinPrize(
        address creatorAddress
    ) external view returns (uint256);

    function getMaxPrize(
        address creatorAddress
    ) external view returns (uint256);

    function getReferee(address creatorAddress) external view returns (address);

    function getRegistrationFees(address _user) external view returns (uint256);
}

contract Autobet is
    AutomationCompatibleInterface,
    VRFV2WrapperConsumerBase,
    ConfirmedOwner
{
    using SafeMath for uint256;
    uint256 public lotteryId = 1;
    // uint256 public ownerId = 1;
    uint256 public partnerId = 0;
    // uint256 public bregisterFee = 10;
    uint256 public lotteryCreateFee = 10;
    uint256 public transferFeePerc = 10;
    uint256 public minimumRollover = 100;
    uint256 public tokenEarnPercent = 5;
    uint256 public defaultRolloverday = 5;
    uint256 public totalSale = 0;
    address public tokenAddress;
    address public admin;
    string public lastresult;
    bool public callresult;
    address public autobetUseraddress;
    uint256 public totalWinners;
    uint256 public totalPartnerPay;
    uint256 public totalDraws;

    enum LotteryState {
        open,
        close,
        resultdone,
        rollover,
        blocked,
        rolloverOpen,
        creating
    }

    enum LotteryType {
        revolver,
        mine,
        mrl,
        missile
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
        uint256 partnershare;
        uint256 rolloverperct;
        uint256 deployedOn;
        address partnerAddress;
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
        uint256 rolloverdays;
        uint16 level;
    }

    struct RequestStatus {
        uint256 paid; // amount paid in link
        bool fulfilled; // whether the request has been successfully fulfilled
        bool draw;
        uint256[] randomWords;
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

    mapping(uint256 => RequestStatus) public s_requests;
    // mapping(uint256 => address) public organisationbyid;
    mapping(address => PartnerData) public partnerbyaddr;
    mapping(uint256 => address) public partnerids;
    // Mapping lottery id => details of the lottery.
    mapping(uint256 => LotteryData) public lottery;
    mapping(uint256 => LotteryDate) public lotteryDates;

    mapping(address => uint256) public amountspend;
    mapping(address => uint256) public refereeEarned;
    mapping(address => uint256) public amountwon;
    mapping(address => uint256) public amountEarned;
    mapping(address => uint256) public amountLocked;
    mapping(address => uint256) public commissionEarned;
    mapping(address => uint256) public totalLotteryCreationFees;
    mapping(address => uint256) public winnerTax;
    mapping(uint256 => uint256) public totalProfits;
    mapping(address => uint256) public totalWinnerAmount;

    mapping(address => uint256) public tokenearned;
    mapping(address => uint256) public tokenredeemed;
    mapping(uint256 => uint256) public lotterySales;

    mapping(uint256 => uint256) public requestIds;
    mapping(uint256 => uint256) public randomNumber;
    mapping(uint256 => uint256) public spinNumbers;
    mapping(uint256 => address) public spinBuyer;

    mapping(uint256 => uint256[]) public minelottery;

    mapping(uint256 => string) private missilecodes;

    mapping(address => uint256[]) private userlotterydata;
    mapping(address => uint256[]) private partnerlotterydata;

    mapping(address => uint256[]) private orglotterydata;

    // Mapping of lottery id => user address => no of tickets
    mapping(uint256 => mapping(address => uint256)) public lotteryTickets;
    mapping(string => address) public TicketsList;
    mapping(address => uint256) public partnerPayAmount;

    event LotteryCreated(
        address owner,
        uint256 lotteryId,
        uint256 entryfee,
        uint256 totalPrize,
        uint256 startTime,
        uint256 endtime,
        uint256 drawtime,
        address partner,
        uint256 types
    );

    event PartnerCreated(
        string name,
        string logoHash,
        bool status,
        string websiteAdd,
        address partnerAddress,
        uint256 createdOn
    );
    event LotteryBought(
        address creatorAddress,
        uint256[] numbers,
        uint256 indexed lotteryId,
        uint256 boughtOn,
        address indexed useraddress,
        uint256 paid
    );

    event LotteryResult(
        address useraddressdata,
        uint256 indexed lotteryId,
        uint256 drawOn,
        string number
    );

    event LotterySaleResult(
         address useraddressdata,
        uint256 indexed lotteryId,
        uint256 drawOn,
        uint256 number
    );

    event WinnerPaid(
        address creatorAddress,
        address indexed useraddressdata,
        uint256 indexed lotteryId,
        uint256 amountwon
    );

    event PartnerPaid(
        address ownerAddress,
        address indexed partneradddress,
        uint256 indexed lotteryId,
        uint256 amountpaid
    );

    event RolloverHappened(address creatorAddress,uint256 lotteryId, uint256 rolloverDays);

    event SpinLotteryResult(
        address indexed useraddressdata,
        uint256 indexed lotteryId,
        uint256 selectedNum,
        uint256 winnerNum,
        uint256 date
    );

    constructor(
        address _tokenAddress,
        address _autobetUseraddress
    )
        ConfirmedOwner(msg.sender)
        VRFV2WrapperConsumerBase(
            0x779877A7B0D9E8603169DdbD7836e478b4624789, // LINK Token
            0xab18414CD93297B0d12ac29E63Ca20f515b3DB46
        )
    {
        autobetUseraddress = _autobetUseraddress;
        admin = msg.sender;
        tokenAddress = _tokenAddress;

        amountEarned[msg.sender] = 0;
        commissionEarned[msg.sender] = 0;
        totalLotteryCreationFees[msg.sender] = 0;
    }

    function setCallresult(bool _callresult) external {
        callresult = _callresult;
    }

    function substring(
        string memory str,
        uint256 startIndex,
        uint256 endIndex
    ) public pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }

    function compareStrings(
        string memory a,
        string memory b
    ) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) ==
            keccak256(abi.encodePacked((b))));
    }

    function stringToUint(string memory s) public pure returns (uint256) {
        bytes memory b = bytes(s);
        uint256 result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            uint256 c = uint256(uint8(b[i]));
            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
            }
        }
        return result;
    }

    function createLottery(
        uint256 entryfee,
        uint256 picknumbers,
        uint256 totalPrize,
        uint256 startTime,
        uint256 endtime,
        uint256 drawtime,
        uint256 capacity,
        uint256 rolloverperct,
        uint256 rolloverday,
        uint256 partnershare,
        address partner,
        LotteryType lottype
    ) public payable {
        require(
            IABUser(autobetUseraddress).isCreator(msg.sender),
            "Not a registered creator"
        );

        require(
            IABUser(autobetUseraddress).getMinPrize(msg.sender) <= totalPrize,
            "Not allowed minimum winning amount"
        );
        require(
            IABUser(autobetUseraddress).getMaxPrize(msg.sender) >= totalPrize,
            "Not allowed maximum winning amount"
        );
        require(
            LINK.balanceOf(address(this)) >= 1,
            "Not enough LINK - fill contract with faucet"
        );

        require(totalPrize > 0, "Low totalPrice");
        require(
            msg.value == totalPrize.add((totalPrize * lotteryCreateFee) / 100),
            "Amount not matching"
        );
        require(picknumbers <= capacity, "capacity is less");
        require(startTime >= block.timestamp, "Start time passed");
        require(startTime < endtime, "End time less than start time");

        if (lottype == LotteryType.revolver || lottype == LotteryType.mine) {
            require(picknumbers == 1, "Only 1 number allowed");
        }

        if (lottype == LotteryType.missile) {
            require(picknumbers <= 10, " Only 10 combination allowed");
        }

        lotteryDates[lotteryId].level = 1;
        commonLotteryDetails(
            lotteryId,
            entryfee,
            picknumbers,
            totalPrize,
            startTime,
            endtime,
            drawtime,
            capacity,
            rolloverperct,
            partnershare,
            rolloverday,
            partner,
            msg.sender
        );
        lottery[lotteryId].lotteryType = lottype;
        lottery[lotteryId].minPlayers =
            (totalPrize).div(entryfee) +
            (totalPrize).mul(10).div(entryfee) /
            100;
        address referee = IABUser(autobetUseraddress).getReferee(msg.sender);
        if (referee != address(0)) {
            refereeEarned[referee] =
                refereeEarned[referee] +
                totalPrize.div(100);
        }
        if (lottype != LotteryType.missile) {
            lottery[lotteryId].status = LotteryState.open;
        } else {
            lottery[lotteryId].status = LotteryState.creating;
            storeRequestedId(lotteryId, false);
        }

        emit LotteryCreated(
            msg.sender,
            lotteryId,
            entryfee,
            totalPrize,
            startTime,
            endtime,
            drawtime,
            partner,
            uint(lottype)
        );
        lotteryId++;
    }

    function commonLotteryDetails(
        uint256 _lotteryId,
        uint256 entryfee,
        uint256 picknumbers,
        uint256 totalPrize,
        uint256 startTime,
        uint256 endtime,
        uint256 drawtime,
        uint256 capacity,
        uint256 rolloverperct,
        uint256 partnershare,
        uint256 rolloverday,
        address partnerAddress,
        address owner
    ) internal {
        lottery[_lotteryId].partnerAddress = partnerAddress;
        lottery[_lotteryId].lotteryId = _lotteryId;
        lottery[_lotteryId].rolloverperct = rolloverperct;
        lottery[_lotteryId].entryFee = entryfee;
        lottery[_lotteryId].pickNumbers = picknumbers;
        lottery[_lotteryId].totalPrize = totalPrize;
        lotteryDates[_lotteryId].startTime = startTime;
        lotteryDates[_lotteryId].endTime = endtime;
        lotteryDates[_lotteryId].lotteryId = _lotteryId;
        lotteryDates[_lotteryId].drawTime = drawtime;
        lotteryDates[_lotteryId].rolloverdays = rolloverday;
        lottery[_lotteryId].deployedOn = block.timestamp;
        lottery[_lotteryId].capacity = capacity;
        lottery[_lotteryId].ownerAddress = owner;
        lottery[_lotteryId].partnershare = partnershare;
        orglotterydata[owner].push(_lotteryId);
        partnerlotterydata[partnerAddress].push(_lotteryId);
        totalLotteryCreationFees[admin] += (totalPrize * lotteryCreateFee).div(100);
        commissionEarned[admin] += (totalPrize * lotteryCreateFee).div(100);
    }

    function buyNormalLottery(
        uint256[] memory numbers,
        uint256 lotteryid
    ) public payable {
        LotteryData storage LotteryDatas = lottery[lotteryid];
        LotteryDate storage LotteryDates = lotteryDates[lotteryid];
        require(msg.value == LotteryDatas.entryFee, "Entry Fee not met");
        require(
            numbers.length == LotteryDatas.pickNumbers,
            "slots size not meet"
        );
        string memory n = "";
        for (uint256 i = 0; i < numbers.length; i++) {
            n = string.concat(Strings.toString(numbers[i]), "-", n);
        }
        n = string.concat(n, Strings.toString(lotteryid));
        require(TicketsList[n] == address(0), "Already sold");
        TicketsList[n] = msg.sender;
        if (block.timestamp > LotteryDates.drawTime) {
            dorolloverMath(lotteryid);
        }
        doInternalMaths(lotteryid, msg.sender, msg.value, numbers);
        if (LotteryDatas.lotteryType == LotteryType.mine) {
            minelottery[lotteryid].push(numbers[0]);
        }
    }

    function buySpinnerLottery(
        uint256 numbers,
        uint256 lotteryid
    ) public payable {
        LotteryData storage LotteryDatas = lottery[lotteryid];
        require(msg.value == LotteryDatas.entryFee, "Entry Fee not met");
        require(
            (LotteryDatas.status == LotteryState.open ||
                LotteryDatas.status == LotteryState.rolloverOpen),
            "Other player playing"
        );
        uint256[] memory numbarray = new uint256[](1);
        numbarray[0] = numbers;
        LotteryDatas.status = LotteryState.blocked;
        doInternalMaths(lotteryid, msg.sender, msg.value, numbarray);
        getWinners(lotteryid, numbers, msg.sender);
    }

    function buyMissilelottery(
        string memory code,
        uint256 lotteryid
    ) public payable {
        LotteryData storage LotteryDatas = lottery[lotteryid];
        LotteryDate storage LotteryDates = lotteryDates[lotteryid];
        require(msg.value == LotteryDatas.entryFee, "Entry Fee not met");
        uint256[] memory numbarray = new uint256[](1);
        numbarray[0] = stringToUint(code);
        doInternalMaths(lotteryid, msg.sender, msg.value, numbarray);
        if (compareStrings(code, missilecodes[lotteryid])) {
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
            if (block.timestamp > LotteryDates.drawTime) {
                dorolloverMath(lotteryid);
            }
        }
    }

    function dorolloverMath(uint256 lotteryid) internal {
        LotteryData storage LotteryDatas = lottery[lotteryid];
        LotteryDate storage LotteryDates = lotteryDates[lotteryid];
        address lotteryOwner = LotteryDatas.ownerAddress;
        LotteryDates.level = LotteryDates.level + 1;
        LotteryDates.drawTime = LotteryDates.drawTime.add(
            LotteryDates.rolloverdays
        );
        LotteryDatas.status = LotteryState.rolloverOpen;
        LotteryDatas.totalPrize = LotteryDatas.totalPrize.add(
            totalProfits[lotteryid].mul(LotteryDatas.rolloverperct).div(100)
        );
        amountLocked[LotteryDatas.ownerAddress] -= totalProfits[lotteryid]
            .mul(LotteryDatas.rolloverperct)
            .div(100);

        emit RolloverHappened(lotteryOwner,lotteryid, LotteryDates.rolloverdays);
    }

    function doInternalMaths(
        uint256 lotteryid,
        address callerAdd,
        uint256 amt,
        uint256[] memory numbarray
    ) internal {
        LotteryData storage LotteryDatas = lottery[lotteryid];
        
        lotteryTickets[lotteryid][callerAdd] += 1;
        LotteryDatas.Tickets.push(
            TicketsData({
                lotteryId: lotteryid,
                userAddress: callerAdd,
                numbersPicked: numbarray,
                boughtOn: block.timestamp
            })
        );

        amountspend[callerAdd] += amt;
        totalSale = totalSale + 1;
        totalProfits[lotteryid] += amt;
        amountLocked[LotteryDatas.ownerAddress] += amt;
        userlotterydata[callerAdd].push(lotteryid);
        lotterySales[lotteryid]++;
        tokenearned[callerAdd] += (
            (LotteryDatas.entryFee * tokenEarnPercent).div(100)
        );
        address lotteryowner = LotteryDatas.ownerAddress;
        emit LotteryBought(
            lotteryowner,
            numbarray,
            lotteryid,
            block.timestamp,
            callerAdd,
            LotteryDatas.entryFee
        );
    }

    function getWinners(
        uint256 _lotteryId,
        uint256 selectedNum,
        address buyer
    ) internal {
        uint256 _requestId = storeRequestedId(_lotteryId, true);
        spinNumbers[_requestId] = selectedNum;
        spinBuyer[_requestId] = buyer;
        emit LotterySaleResult(spinBuyer[_requestId],_lotteryId,spinNumbers[_requestId],selectedNum);
    }

    function storeRequestedId(
        uint256 _lotteryId,
        bool _draw
    ) internal returns (uint256 id) {
        uint256 _requestId = requestRandomness(
            callbackGasLimit,
            requestConfirmations,
            numWords
        );
        requestIds[_requestId] = _lotteryId;
        s_requests[_requestId] = RequestStatus({
            paid: VRF_V2_WRAPPER.calculateRequestPrice(callbackGasLimit),
            randomWords: new uint256[](0),
            draw: _draw,
            fulfilled: false
        });
        return _requestId;
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomness
    ) internal override {
        require(s_requests[_requestId].paid > 0, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomness;
        randomNumber[_requestId] = _randomness[0];
        if (s_requests[_requestId].draw) {
            getdraw(
                randomNumber[_requestId],
                requestIds[_requestId],
                _requestId
            );
        } else {
            uint16 digits = NumberLength(_randomness[0]);
            uint256 random = (uint256(
                keccak256(abi.encodePacked(block.timestamp, msg.sender, digits))
            ) % digits) - lottery[requestIds[_requestId]].pickNumbers;
            string memory textTrim = substring(
                Strings.toString(_randomness[0]),
                random,
                random + lottery[requestIds[_requestId]].pickNumbers
            );
            lottery[requestIds[_requestId]].status = LotteryState.open;
            missilecodes[requestIds[_requestId]] = textTrim;
        }
    }

    function checkUpkeep(
        bytes calldata
    ) external view override returns (bool upkeepNeeded, bytes memory result) {
        upkeepNeeded = false;
        uint256 id = 0;
        require(
            LINK.balanceOf(address(this)) >= 1,
            "Not enough LINK - fill contract with faucet"
        );
        require(!callresult, "Another Result running");
        id = upKeepUtil();
        if (id != 0) {
            upkeepNeeded = true;
        }
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata) external override {
        require(!callresult, "required call true");
        callresult = true;
        uint256 id = upKeepUtil();
        storeRequestedId(id, true);
    }

    function upKeepUtil() internal view returns (uint256 id) {
        for (uint256 i = 1; i < lotteryId; i++) {
            if (lottery[i].lotteryType == LotteryType.mrl) {
                if (lottery[i].status != LotteryState.resultdone) {
                    if (lottery[i].minPlayers <= lotterySales[i]) {
                        if (lotteryDates[i].drawTime < block.timestamp) {
                            return i;
                        }
                    }
                }
            }
            if (
                lottery[i].lotteryType == LotteryType.mine &&
                lotterySales[i] == lottery[i].capacity &&
                lottery[i].status != LotteryState.resultdone
            ) {
                return i;
            }
        }
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
            getmrlwinner(
                lotteryid,
                num,
                LotteryDatas.capacity,
                LotteryDatas.pickNumbers,
                requestId
            );
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
        totalDraws++;
    }

    function getmrlwinner(
        uint256 lotteryid,
        uint256 random,
        uint256 capacity,
        uint256 pick,
        uint256 requestId
    ) internal {
        LotteryData storage LotteryDatas = lottery[lotteryid];
        string memory n = "";
        uint256 j = 0;
        uint16 digits = NumberLength(random);
        uint256 c = 0;
        uint256[] memory num = new uint256[](digits);
        while (j < pick) {
            uint256 random1 = (uint256(
                keccak256(
                    abi.encodePacked(block.timestamp + c, msg.sender, digits)
                )
            ) % digits);
            uint256 random2 = (uint256(
                keccak256(abi.encodePacked(block.timestamp + c, msg.sender, j))
            ) % 2);
            string memory textTrim = substring(
                Strings.toString(random),
                random1,
                random1 + random2 + 1
            );
            if (
                stringToUint(textTrim) > 0 &&
                stringToUint(textTrim) <= capacity &&
                num[stringToUint(textTrim)] == 0
            ) {
                n = string.concat(textTrim, "-", n);
                num[stringToUint(textTrim)] = 1;
                j++;
            }
            c++;
        }
        n = string.concat(n, Strings.toString(lotteryid));
        lastresult = n;
        if (TicketsList[n] != address(0)) {
            LotteryDatas.status = LotteryState.resultdone;
            LotteryDatas.lotteryWinner = TicketsList[n];
            emit LotteryResult(TicketsList[n], lotteryid, block.timestamp, n);
            paywinner(lotteryid, requestId);
        } else {
            dorolloverMath(lotteryid);
            callresult = false;
        }
    }

    function NumberLength(uint256 number) internal pure returns (uint16) {
        uint8 digits = 0;
        while (number != 0) {
            number /= 10;
            digits++;
        }
        return digits;
    }

    function createRevolverRollover(uint256 lotteryid) internal {
        LotteryData storage LotteryDatas = lottery[lotteryid];
        LotteryDate storage LotteryDates = lotteryDates[lotteryid];
        // address lotteryOwner = LotteryDatas.ownerAddress;
        uint256 newTotalPrize = LotteryDatas.totalPrize +
            LotteryDatas.entryFee.mul(LotteryDatas.rolloverperct).div(100);
        if (newTotalPrize >= minimumRollover) {
            commonLotteryDetails(
                lotteryId,
                LotteryDatas.entryFee,
                LotteryDatas.pickNumbers,
                newTotalPrize,
                LotteryDates.startTime,
                LotteryDates.endTime,
                LotteryDates.drawTime,
                LotteryDatas.capacity,
                LotteryDatas.rolloverperct,
                LotteryDatas.partnershare,
                LotteryDates.rolloverdays,
                LotteryDatas.partnerAddress,
                LotteryDatas.ownerAddress
            );
            LotteryDatas.status = LotteryState.rollover;
            lottery[lotteryId].status = LotteryState.rolloverOpen;
            lottery[lotteryId].lotteryType = LotteryDatas.lotteryType;
            lottery[lotteryId].minPlayers = LotteryDatas.minPlayers;
            lotteryDates[lotteryId].level = LotteryDates.level + 1;
            emit RolloverHappened(LotteryDatas.ownerAddress,lotteryid, LotteryDates.rolloverdays);
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
            totalWinnerAmount[admin] += finalAmount;
            address lotteryowner = LotteryDatas.ownerAddress;
            emit WinnerPaid(lotteryowner,useraddressdata, lotteryid, finalAmount);
            commissionEarned[admin] += subtAmt;
            winnerTax[admin] += subtAmt;
            totalWinners++;
            uint256 partnerpay = totalProfits[lotteryid]
                .mul(LotteryDatas.partnershare)
                .div(100);
            totalPartnerPay += partnerpay; // total partner pay
            partnerPayAmount[LotteryDatas.partnerAddress] += partnerpay; //partnerPay for each partner
            payable(LotteryDatas.partnerAddress).transfer(partnerpay);
            amountLocked[LotteryDatas.ownerAddress] -=
                totalProfits[lotteryid] -
                partnerpay;
            amountEarned[LotteryDatas.ownerAddress] +=
                totalProfits[lotteryid] -
                partnerpay;

            emit PartnerPaid(
                LotteryDatas.ownerAddress,
                LotteryDatas.partnerAddress,
                lotteryid,
                partnerpay
            );
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

    function totalCommissionEarned() public view returns (uint256) {
        uint256 totalCommission = commissionEarned[admin] +
            IABUser(autobetUseraddress).getRegistrationFees(msg.sender);
        return totalCommission;
    }

    function withdrawcommission() external payable {
        uint256 amount = amountEarned[msg.sender] ;
        uint256 subtAmt = amount.mul(transferFeePerc).div(100);
        uint256 finalAmount = amount.sub(subtAmt);
        payable(msg.sender).transfer(finalAmount);
        commissionEarned[admin] += subtAmt;
        commissionEarned[msg.sender] += finalAmount;
        amountEarned[msg.sender] = 0;
    }

    function withdrawAdmin() external payable onlyAdmin {
        uint256 amount = commissionEarned[admin] ;
        payable((msg.sender)).transfer(amount);
        commissionEarned[admin] = 0;
        winnerTax[admin]=0;
        totalLotteryCreationFees[admin]=0;

    }

    function withdrawrefereecommission() external payable {
        uint256 amount = refereeEarned[msg.sender];
        payable((msg.sender)).transfer(amount);
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
        uint256 _minroll,
        uint256 _rolloverday
    ) external onlyAdmin {
        lotteryCreateFee = _lotteryCreateFee;
        transferFeePerc = _transferFeePerc;
        tokenEarnPercent = _tokenEarnPercent;
        minimumRollover = _minroll;
        defaultRolloverday = _rolloverday;
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
    ) external onlyAdmin {
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

    function addEditPartnerDetails(
        string memory _name,
        string memory _logoHash,
        bool _status,
        string memory _websiteAdd,
        address _partnerAddress,
        uint256 _createdOn
    ) external {
        assert(_partnerAddress != address(0));
        if (partnerbyaddr[_partnerAddress].partnerAddress == address(0)) {
            partnerId++;
            partnerids[partnerId] = _partnerAddress;
            partnerbyaddr[_partnerAddress] = PartnerData({
                partnerId: partnerId,
                name: _name,
                logoHash: _logoHash,
                status: _status,
                websiteAdd: _websiteAdd,
                partnerAddress: _partnerAddress,
                createdOn: _createdOn
            });
        } else {
            partnerbyaddr[_partnerAddress] = PartnerData({
                partnerId: partnerbyaddr[_partnerAddress].partnerId,
                name: _name,
                logoHash: _logoHash,
                status: _status,
                websiteAdd: _websiteAdd,
                partnerAddress: _partnerAddress,
                createdOn: _createdOn
            });
        }
        emit PartnerCreated(
            _name,
            _logoHash,
            _status,
            _websiteAdd,
            _partnerAddress,
            block.timestamp
        );
    }
}
