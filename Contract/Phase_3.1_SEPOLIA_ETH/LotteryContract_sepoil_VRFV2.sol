pragma solidity ^0.8.7;
// SPDX-License-Identifier: Unlicensed
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol";
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Autobet is
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
    uint256 public minimumRollover = 100;
    uint256 public tokenEarnPercent = 5;
    uint256 public defaultRolloverday = 5;
    uint256 public totalSale = 0;
    address public tokenAddress;
    address public admin;
    bool public callresult;

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
        bool draw;
        uint256[] randomWords;
    }

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

    mapping(uint256 => RequestStatus) public s_requests;
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

    mapping(uint256 => uint256[]) public minelottery;

    mapping(uint256 => string) private missilecodes;

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

    function substring(
        string memory str,
        uint256 startIndex,
        uint256 endIndex
    ) public pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint i = startIndex; i < endIndex; i++) {
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

    function stringToUint(string memory s) public pure returns (uint) {
        bytes memory b = bytes(s);
        uint result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            uint256 c = uint256(uint8(b[i]));
            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
            }
        }
        return result;
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
    ) public payable onlyowner {
        require(
            organisationbyaddr[msg.sender].minPrize <= totalPrize,
            "Not allowed winning amount"
        );
        require(
            organisationbyaddr[msg.sender].maxPrize >= totalPrize,
            "Not allowed winning amount"
        );
        require(
            LINK.balanceOf(address(this)) >= 1,
            "Not enough LINK - fill contract with faucet"
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
            partner,
            rolloverperct,
            partnershare,
            msg.sender
        );
        lottery[lotteryId].lotteryType = lottype;
        lottery[lotteryId].minPlayers =
            (totalPrize).div(entryfee) +
            (totalPrize).mul(10).div(entryfee).div(100);

        if (organisationbyaddr[msg.sender].referee != address(0)) {
            refereeEarned[organisationbyaddr[msg.sender].referee] =
                refereeEarned[organisationbyaddr[msg.sender].referee] +
                totalPrize.div(100);
        }
        if (lottype != LotteryType.missile) {
            lottery[lotteryId].status = LotteryState.open;
        } else {
            lottery[lotteryId].status = LotteryState.creating;
            storeRequestedId(lotteryId, false);
        }

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
        uint256 partner,
        uint256 rolloverperct,
        uint256 partnershare,
        address owner
    ) internal {
        lottery[_lotteryId].partnerId = partner;
        lottery[_lotteryId].lotteryId = _lotteryId;
        lottery[_lotteryId].rolloverperct = rolloverperct;
        lottery[_lotteryId].entryFee = entryfee;
        lottery[_lotteryId].pickNumbers = picknumbers;
        lottery[_lotteryId].totalPrize = totalPrize;
        lotteryDates[_lotteryId].startTime = startTime;
        lotteryDates[_lotteryId].endTime = endtime;
        lotteryDates[_lotteryId].lotteryId = _lotteryId;
        lotteryDates[_lotteryId].drawTime = drawtime;
        lottery[_lotteryId].deployedOn = block.timestamp;
        lottery[_lotteryId].capacity = capacity;
        lottery[_lotteryId].ownerAddress = owner;
        lottery[_lotteryId].partnershare = partnershare;
        orglotterydata[owner].push(_lotteryId);
        partnerlotterydata[partnerbyid[partner].partnerAddress].push(
            _lotteryId
        );
        organisationbyaddr[admin].commissionEarned += (totalPrize *
            lotteryCreateFee).div(100);
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
        if (
            LotteryDatas.minPlayers <= lotterySales[lotteryid] &&
            LotteryDatas.lotteryType == LotteryType.mrl
        ) {
            require(
                block.timestamp < LotteryDates.endTime,
                "Time passed to buy"
            );
        }
        if (block.timestamp > LotteryDates.endTime) {
            LotteryDates.drawTime = LotteryDates.drawTime.add(
                LotteryDatas.rolloverperct.mul(86400)
            );
            LotteryDatas.status = LotteryState.rolloverOpen;
            LotteryDates.endTime = LotteryDates.endTime.add(
                LotteryDatas.rolloverperct.mul(86400)
            );
        }
        TicketsList[hash] = true;
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
            if (block.timestamp > LotteryDates.endTime) {
                LotteryDates.level = LotteryDates.level + 1;
                LotteryDates.drawTime = LotteryDates.drawTime.add(
                    defaultRolloverday.mul(86400)
                );
                LotteryDates.endTime = LotteryDates.endTime.add(
                    defaultRolloverday.mul(86400)
                );
                LotteryDatas.status = LotteryState.rolloverOpen;
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
        organisationbyaddr[LotteryDatas.ownerAddress].amountEarned += amt;
        userlotterydata[callerAdd].push(lotteryid);
        lotterySales[lotteryid]++;
        tokenearned[callerAdd] += (
            (LotteryDatas.entryFee * tokenEarnPercent).div(100)
        );
        emit LotteryBought(
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
            uint8 digits = 0;
            uint256 number = _randomness[0];
            while (number != 0) {
                number /= 10;
                digits++;
            }
            uint random = (uint(
                keccak256(abi.encodePacked(block.timestamp, msg.sender, digits))
            ) % digits) - lottery[requestIds[_requestId]].pickNumbers;
            string memory numString = Strings.toString(_randomness[0]);
            string memory textTrim = substring(
                numString,
                random,
                random + lottery[requestIds[_requestId]].pickNumbers
            );
            lottery[requestIds[_requestId]].status = LotteryState.open;
            missilecodes[requestIds[_requestId]] = textTrim;
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
            if (lottery[i].lotteryType == LotteryType.mine) {
                if (
                    lotterySales[i] == lottery[i].capacity &&
                    lotteryDates[i].drawTime < block.timestamp
                ) {
                    return i;
                }
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
            commonLotteryDetails(
                lotteryId,
                LotteryDatas.entryFee,
                LotteryDatas.pickNumbers,
                newTotalPrize,
                LotteryDates.startTime,
                LotteryDates.endTime,
                LotteryDates.drawTime,
                LotteryDatas.capacity,
                LotteryDatas.partnerId,
                LotteryDatas.rolloverperct,
                LotteryDatas.partnershare,
                LotteryDatas.ownerAddress
            );
            LotteryDatas.status = LotteryState.rollover;
            lottery[lotteryId].status = LotteryState.rolloverOpen;
            lottery[lotteryId].lotteryType = LotteryDatas.lotteryType;
            lottery[lotteryId].minPlayers = LotteryDatas.minPlayers;
            lotteryDates[lotteryId].level = LotteryDates.level + 1;
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
            organisationbyaddr[admin].commissionEarned += subtAmt;
            uint256 totalSaleProfit = lotterySales[lotteryid] *
                LotteryDatas.entryFee;
            uint256 partnerpay = totalSaleProfit
                .mul(LotteryDatas.partnershare)
                .div(100);
            payable(partnerbyid[LotteryDatas.partnerId].partnerAddress)
                .transfer(partnerpay);
            organisationbyaddr[LotteryDatas.ownerAddress]
                .amountEarned -= partnerpay;
            emit PartnerPaid(
                partnerbyid[LotteryDatas.partnerId].partnerAddress,
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

    function withdrawcommission() external payable {
        uint256 amountEarned = organisationbyaddr[msg.sender].amountEarned;
        uint256 subtAmt = amountEarned.mul(transferFeePerc).div(100);
        uint256 finalAmount = amountEarned.sub(subtAmt);
        payable(msg.sender).transfer(finalAmount);
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
        organisationbyaddr[newAdmin] = organisationbyaddr[msg.sender];
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
            partnerbyid[
                partnerbyaddr[_partnerAddress].partnerId
            ] = PartnerData({
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
}
