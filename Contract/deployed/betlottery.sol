pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

interface KeeperCompatibleInterface {
    function checkUpkeep(bytes calldata) external  returns (bool upkeepNeeded, bytes memory ) ;
    function performUpkeep( bytes calldata ) external ;
}

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
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

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
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
 
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

  
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

contract Autobet is VRFConsumerBase, KeeperCompatibleInterface{
    using SafeMath for uint256;
    bytes32 internal keyHash;
    bytes32 public RID ;
    address public admin;
    uint256 public lotteryId = 1;
    uint256 public ownerId = 1;
    uint256 internal fee;
    uint256 public bregisterFee = 10000000000000000;
    uint256 public lotteryCreateFee;  
    uint256 public transferFeePerc = 10 ;   
    uint256 public tokenEarnPercent = 5;
    bool public callresult;
    address public tokenAddress;
    
    
    enum LotteryState {
        open,
        close,
        resultdone
    }
    
    enum LotteryType{
        spinner,
        pick
    }   
    
    struct OwnerData{
        bool active;
        address userAddress;
        string name;
        uint256 id;
        uint256 amountEarned;
        uint256 commissionEarned;
    }

    struct TicketsData {
        address userAddress;
        uint256 boughtOn;
        uint256[] numbersPicked;
       
    }

    struct LotteryData {
        uint256 lotteryId;
        uint256 pickNumbers;//ticket numbers need to be selected
        uint256 startTime; // Start time of Lottery.
        uint256 endTime; // End time of lottery.
        uint256 capacity; // Total size of lottery.
        uint256 drawTime;
        uint256 entryFee;
        uint256 totalPrize; // Total wining price.
        address lotteryWinner;
        address ownerAddress;
        LotteryState status;
        TicketsData[] Tickets;
        LotteryType lotteryType;
    }
     
    modifier onlyowner{
        require(organisationbyaddr[msg.sender].active,"Not a organisation");
        _;
    }

    modifier onlyAdmin {
        require(admin == msg.sender, "not-a-admin");
        _;
    }
    
    mapping (uint256 => OwnerData) public organisationbyid;
    mapping (address => OwnerData) public organisationbyaddr;
    // Mapping lottery id => details of the lottery.
    mapping (uint256 => LotteryData) public lottery;

    //Mapping  useraddress => amountspend
    mapping(address => uint256) public amountspend;

    //Mapping  useraddress => amountwon
    mapping(address => uint256) public amountwon;
    
    mapping(address => uint256) public tokenearned;
    mapping(address => uint256) public tokenredeemed;
    mapping (uint256 => uint256) public lotterySales;


    mapping (bytes32 => uint256) public requestIds;
    mapping (bytes32 => uint256) public randomNumber;
    mapping (bytes32 => uint256) public spinNumbers;
    mapping (bytes32 => address) public spinBuyer;

    mapping(address => uint256[]) private userlotterydata;

    mapping(address => uint256[]) private orglotterydata;

    // Mapping of lottery id => user address => no of tickets
    mapping (uint256 => mapping (address => uint256)) public lotteryTickets;
    mapping (string =>  bool) public TicketsList;

    event CreatedLottery(uint256 indexed lotteryId,uint256 entryfee,uint256 picknumbers,uint256 totalPrize, uint256 capacity, address indexed owner,uint256 startTime,uint256 indexed ownerid);

    event LotteryBought(uint256[]numbers, uint256 indexed lotteryId ,uint256 boughtOn, address indexed useraddress,uint256 drawOn,uint256 paid);

    event LotteryResult(address useraddressdata, uint256 indexed lotteryId , uint256 drawOn);

    event WinnerPaid(address indexed useraddressdata ,uint256 indexed lotteryId,uint256 amountwon);
    
    event SpinLotteryResult(address indexed useraddressdata, uint256 indexed lotteryId,uint256 selectedNum, uint256 winnerNum,uint256 date);

    constructor(address _tokenAddress)
        VRFConsumerBase(
           0x3d2341ADb2D31f1c5530cDC622016af293177AE0,
0xb0897686c545045aFc77CF20eC7A532E3120E0F1 // LINK Token
        ) public
    {
        keyHash = 0xf86195cf7690c55907b2b611ebb7343a6f649bff128701cc542f0569e2c549da;
        fee = 	0.0001 * 10 ** 18; // 0.1 LINK
        admin = msg.sender;
        tokenAddress=_tokenAddress;
        organisationbyaddr[msg.sender] = OwnerData({id:ownerId, userAddress:msg.sender,name:'Autobet', active:true, amountEarned:0, commissionEarned:0 });
        organisationbyid[ownerId++] = OwnerData({id:ownerId,  userAddress:msg.sender,name:'Autobet', active:true, amountEarned:0 ,commissionEarned:0});
    }
    
    function setCallresult(bool _callresult) external
    {
         callresult= _callresult;
    }

   function addOrganisation(address _owner,string memory _name) external payable {
        assert(_owner != address(0));
        require(organisationbyaddr[_owner].userAddress == address(0),"Already registered" );
        require(bregisterFee==msg.value,"Register Fee not matching");
        organisationbyaddr[_owner] = OwnerData({id:ownerId, userAddress:_owner,name:_name, active:true, amountEarned:0, commissionEarned:0 });
        organisationbyid[ownerId++] = OwnerData({id:ownerId, userAddress:_owner,name:_name, active:true, amountEarned:0 ,commissionEarned:0});
    }
     
   
    function createLottery(uint256 entryfee,
        uint256 picknumbers,
        uint256 totalPrize,
        uint256 startTime,
        uint256 endtime,
        uint256 drawtime,
        uint256 capacity,
        LotteryType lottype
        ) public onlyowner payable {
        require(totalPrize > 0,"Low totalPrice");
        require(totalPrize==msg.value,"Amount not matching");
        require(picknumbers<=capacity,"capacity is less");
        require(startTime >= block.timestamp,"Start time passed");
        require(startTime < endtime,"End time less than start time");
        lottery[lotteryId].lotteryId = lotteryId;
        lottery[lotteryId].entryFee = entryfee;
        lottery[lotteryId].pickNumbers = picknumbers;
        lottery[lotteryId].totalPrize = totalPrize;
        lottery[lotteryId].startTime = startTime;
        lottery[lotteryId].endTime = endtime;
        lottery[lotteryId].capacity = capacity;
        lottery[lotteryId].status = LotteryState.open;
        lottery[lotteryId].drawTime = drawtime;
        lottery[lotteryId].ownerAddress = msg.sender;
        lottery[lotteryId].lotteryType = lottype;
        orglotterydata[msg.sender].push(lotteryId);
        emit CreatedLottery(lotteryId,entryfee,picknumbers,totalPrize,  capacity,  msg.sender, startTime, organisationbyaddr[msg.sender].id);
        lotteryId++;
    }
    
    function buyNormalLottery(uint256[] memory numbers, uint256 lotteryid,string memory hash)public payable {
        LotteryData storage LotteryDatas = lottery[lotteryid];
        require(msg.value == LotteryDatas.entryFee,"Entry Fee not met");
        require(numbers.length == LotteryDatas.pickNumbers,"slots size not meet");
        require(block.timestamp < LotteryDatas.endTime,"Time passed to buy");
        require(!TicketsList[hash],"Number Already claimed");
        TicketsList[hash] = true;
        lotteryTickets[lotteryid][msg.sender] += 1;
        LotteryDatas.Tickets.push(TicketsData({userAddress:msg.sender, numbersPicked:numbers,boughtOn:block.timestamp}));
        amountspend[msg.sender]+= msg.value;
        organisationbyaddr[LotteryDatas.ownerAddress].amountEarned += msg.value;
        userlotterydata[msg.sender].push(lotteryid);
        lotterySales[lotteryid]++;
        tokenearned[msg.sender] +=  ((LotteryDatas.entryFee * tokenEarnPercent).div(100)) ;
        emit LotteryBought(numbers,lotteryid,block.timestamp,msg.sender,LotteryDatas.drawTime,LotteryDatas.entryFee);
    }
    
     function buySpinnerLottery(uint256 numbers, uint256 lotteryid )public payable {
        LotteryData storage LotteryDatas = lottery[lotteryid];
        require(msg.value == LotteryDatas.entryFee,"Entry Fee not met");
        require(block.timestamp < LotteryDatas.endTime,"Time passed to buy");
        require(LotteryDatas.status != LotteryState.resultdone,"Result done");
        uint256[] memory numbarray= new uint256[](1);
        numbarray[0]=numbers;
        lotteryTickets[lotteryid][msg.sender] += 1;
        LotteryDatas.Tickets.push(TicketsData({userAddress:msg.sender, numbersPicked:numbarray,boughtOn:block.timestamp}));
        amountspend[msg.sender]+= msg.value;
        organisationbyaddr[LotteryDatas.ownerAddress].amountEarned += msg.value;
        userlotterydata[msg.sender].push(lotteryid);
        lotterySales[lotteryid]++;
        tokenearned[msg.sender] +=  ((LotteryDatas.entryFee * tokenEarnPercent).div(100)) ;
        emit LotteryBought(numbarray,lotteryid,block.timestamp,msg.sender,LotteryDatas.drawTime,LotteryDatas.entryFee);
        getWinners(lotteryid,numbers,msg.sender);
    }
    
    
    
    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory result ) {
        upkeepNeeded =false;
        require(!callresult,"Another Result running");
        for(uint256 i=1;i< lotteryId;i++)
        {
            if(lottery[i].lotteryType == LotteryType.pick){
            if(lottery[i].drawTime<block.timestamp){
                if(lottery[i].status!=LotteryState.resultdone){
                    if(lottery[i].Tickets.length>0){
                        upkeepNeeded=true;
                        return(upkeepNeeded,"");
                    }
                }
            }
            }
        }
    }

    function performUpkeep( bytes calldata ) external override {
        require(!callresult,"required call true");
        callresult= true;
          for(uint256 i=1; i<lotteryId;i++)
        {
               if(lottery[i].lotteryType == LotteryType.pick){
            if(lottery[i].drawTime<block.timestamp){
                if(lottery[i].status!=LotteryState.resultdone){
                    if(lottery[i].Tickets.length>0){
                        getWinners(i);
                    }
                }
            }
                   
               }
        }
    }

    function getWinners(uint256 i) internal  {
        require(LINK.balanceOf(address(this)) > fee, "Not enough LINK - fill contract with faucet");
        bytes32 _requestId = requestRandomness(keyHash, fee);
        RID = _requestId;
        requestIds[_requestId] = i;
    }
    
    function getWinners(uint256 i, uint256 selectedNum, address buyer) internal  {
        require(LINK.balanceOf(address(this)) > fee, "Not enough LINK - fill contract with faucet");
        bytes32 _requestId = requestRandomness(keyHash, fee);
        RID = _requestId;
        requestIds[_requestId] = i;
        spinNumbers[_requestId] = selectedNum;
        spinBuyer[_requestId] = buyer;
    }
    
    
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomNumber[requestId] = randomness;
        getdraw(randomness,requestIds[requestId],requestId);
    }

    function getdraw(uint256 num,uint256 lotteryid,bytes32 requestId) internal  {
        LotteryData storage LotteryDatas = lottery[lotteryid];
        if(LotteryDatas.lotteryType == LotteryType.pick){
            num =num.mod(LotteryDatas.Tickets.length);
            LotteryDatas.status =LotteryState.resultdone;
            LotteryDatas.lotteryWinner=LotteryDatas.Tickets[num].userAddress;
            emit LotteryResult(LotteryDatas.Tickets[num].userAddress,lotteryid,block.timestamp);
             paywinner(LotteryDatas.Tickets[num].userAddress,lotteryid,requestId);
        }else{
            num = num.mod(LotteryDatas.capacity) + 1;
            emit SpinLotteryResult(spinBuyer[requestId],lotteryid,spinNumbers[requestId],num,block.timestamp);   
            if(spinNumbers[requestId] == num){
            LotteryDatas.status =LotteryState.resultdone;
            LotteryDatas.lotteryWinner=spinBuyer[requestId];
            paywinner(spinBuyer[requestId],lotteryid,requestId);
            }
        }
    }
 
    
    function paywinner( address useraddressdata , uint256 lotteryid,bytes32 requestId) public payable{
        require(requestIds[requestId]== lotteryid,"Lottery Id mismatch");
        LotteryData storage LotteryDatas = lottery[lotteryid];
        if(useraddressdata!= address(0)){
             uint256 prizeAmt = LotteryDatas.totalPrize;
          
            payable(useraddressdata).transfer(prizeAmt);
            emit WinnerPaid(useraddressdata, lotteryid, prizeAmt);
        }
        callresult=false;
    }
    
    function getUserlotteries(address useraddress) external view returns(uint256[] memory lotteryids){
        uint256[] memory lotteries = new uint256[](userlotterydata[useraddress].length);
        for (uint256 i = 0; i < userlotterydata[useraddress].length; i++) {
            lotteries[i]= userlotterydata[useraddress][i];
        }
        return lotteries;
    }
    
    function setTokenEarnPer(uint256 _tokenEarnPercent) onlyAdmin external{
        tokenEarnPercent = _tokenEarnPercent;
    }
    
    function setTokenAddress(address _tokenAddress) onlyAdmin external{
        tokenAddress = _tokenAddress;
    }
    
    
     function getOrglotteries(address useraddress) external view returns(uint[] memory lotterids){
        uint[] memory lotteries = new uint[](orglotterydata[useraddress].length);
        for (uint i = 0; i < orglotterydata[useraddress].length; i++) {
            lotteries[i]= orglotterydata[useraddress][i];
        }
        return lotteries;
    }
    
      function getLotteryNumbers(uint256 lotteryid) public view returns (uint256[] memory tickets,address[] memory useraddress)  {
        LotteryData storage LotteryDatas = lottery[lotteryid];
        address[] memory useraddressdata = new address[](LotteryDatas.Tickets.length );
        uint256[] memory userdata = new uint256[](LotteryDatas.Tickets.length * LotteryDatas.pickNumbers);
        uint256 p=0;
        uint256 k = 0;
        for (uint256 i = 0; i < LotteryDatas.Tickets.length; i++) {
             useraddressdata[p++]= LotteryDatas.Tickets[i].userAddress;
             for (uint256 j = 0; j < LotteryDatas.pickNumbers; j++) {
            userdata[k++]= uint256(LotteryDatas.Tickets[i].numbersPicked[j]);
            }
        }
        return (userdata,useraddressdata);
    }
    
function withdrawcommission() external payable{
        payable ((msg.sender)).transfer( organisationbyaddr[msg.sender].amountEarned);
        organisationbyaddr[msg.sender].commissionEarned +=  organisationbyaddr[msg.sender].amountEarned;

        organisationbyaddr[msg.sender].amountEarned=0;

    }
    
    function withdrawLink() onlyAdmin external {
        require(LINK.transfer(msg.sender, LINK.balanceOf(address(this))), "Unable to transfer");
    }
    
    function withdrawETH()onlyAdmin external  payable{
       payable(msg.sender).transfer(address(this).balance);
    }
    
   
    function updateFee(uint256 _registerFee, uint256 _lotteryCreateFee, uint256 _transferFeePerc, uint256 _tokenEarnPercent) onlyAdmin external{
        bregisterFee = _registerFee;
        lotteryCreateFee = _lotteryCreateFee;
        transferFeePerc = _transferFeePerc;
        tokenEarnPercent = _tokenEarnPercent;
    }

    
      function redeemTokens() external  {
        require(tokenearned[msg.sender]<=IERC20(tokenAddress).balanceOf(address(this)),"low balance");
        IERC20(tokenAddress).transfer(msg.sender,tokenearned[msg.sender]);
        tokenearned[msg.sender] = 0;
    }
    
    function transferToken(uint256 amount,address to,address tokenAdd) external  {
        require(amount<=IERC20(tokenAdd).balanceOf(address(this)),"low balance");
        IERC20(tokenAdd).transfer(to,amount);
    }
    
    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0));
        admin = newAdmin;
    }

}