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
    using SafeMath for uint;
    bytes32 internal keyHash;
    uint internal fee;
    address public admin;
    uint public lotteryId = 1;
    uint public ownerId = 1;
    bytes32 public RID ;
    bool public callresult;
    uint public prizetotal = 0;
    uint winnerlotteryid;
    uint8 public boughtPercent = 5;
    uint8 public batch = 10;
        uint8 keepinterval= 120;

    address public tokenAddress;
    uint lastchecked= block.timestamp;
 
    enum LotteryState {
        open,
        close,
        resultdone
    }
    
    enum LotteryType{
        spinner,
        pick
    }
     address useraddress;
   uint amountearned;
        uint commissionearned;
   

    struct TicketsData {
        address user;
         uint date;
        uint[] numbers;
       
    }

    struct LotteryData {
        uint lotteryId;
        uint picknumbers;//ticket numbers need to be selected
        uint startTime; // Start time of Lottery.
        uint endtime; // End time of lottery.
        uint capacity; // Total size of lottery.
        uint drawtime;
        uint entryfee;
        uint totalPrize; // Total wining price.
        address lotteryWinner;
        address owner;
        LotteryState status;
        TicketsData[]  Tickets;
        LotteryType lotterytype;
     }

    modifier onlyowner{
         require(admin == msg.sender, "not-a-admin");
        _;
    }

    // Mapping lottery id => details of the lottery.
    mapping (uint => LotteryData) public lottery;

    //Mapping  useraddress => amountspend
    mapping(address => uint) public amountspend;

    //Mapping  useraddress => amountwon
    mapping(address => uint) public amountwon;
    
    mapping(address => uint) public tokenearned;
    mapping(address => uint) public tokenredeemed;

    mapping (bytes32 => uint) public requestIds;
    mapping (bytes32 => uint) public randomNumber;
    mapping (bytes32 => uint) public spinNumbers;
    mapping (bytes32 => address) public spinBuyer;

    mapping(address => uint[]) private userlotterydata;

    uint[] lotterylist;

    // Mapping of lottery id => user address => no of tickets
    mapping (uint => mapping (address => uint)) public lotteryTickets;
    mapping (string =>  bool) public TicketsList;

    event createdlottery(uint indexed lotteryId,uint entryfee,uint picknumbers,uint totalPrize, uint capacity,uint startTime);

    event lotterybought(uint[]numbers, uint indexed lotteryId ,uint boughtOn, address indexed useraddress,uint drawOn,uint paid);

    event lotteryresuls(address useraddressdata, uint indexed lotteryId , uint drawOn);

    event winnerPaid(address indexed useraddressdata ,uint indexed lotteryId,uint amountwon);
    
    event spinLotteryresult(address indexed useraddressdata, uint indexed lotteryId,uint selectedNum, uint winnerNum,uint date);

     constructor(address _tokenAddress)
        VRFConsumerBase(
            0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9,
            0xa36085F69e2889c224210F603D836748e7dC0088 // LINK Token
        ) public
    {
        keyHash = 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4;
        fee = 0.1 * 10 ** 18; // 0.1 LINK
        admin = msg.sender;
        tokenAddress=_tokenAddress;
    }
    
     function setInterval(uint8 intervalvalue) public
     {
         require(intervalvalue>=15,"value is too low");
         keepinterval=intervalvalue;
     }
     
     function setCallresult(bool intervalvalue) public
     {
         callresult=intervalvalue;
     }

  
    function createLottery(uint entryfee,
        uint picknumbers,
        uint totalPrize,
        uint startTime,
        uint endtime,
        uint drawtime,
        uint capacity,
        LotteryType lottype
        ) public onlyowner payable {
        require(totalPrize > 0,"Low totalPrice");
        require(totalPrize==msg.value,"Amount not matching");
        require(picknumbers<=capacity,"capacity is less");
        require(startTime >= block.timestamp,"Start time passed");
        require(startTime < endtime,"End time less than start time");
        lottery[lotteryId].lotteryId = lotteryId;
        lottery[lotteryId].entryfee = entryfee;
        lottery[lotteryId].picknumbers = picknumbers;
        lottery[lotteryId].totalPrize = totalPrize;
        lottery[lotteryId].startTime = startTime;
        lottery[lotteryId].endtime = endtime;
        lottery[lotteryId].capacity = capacity;
        lottery[lotteryId].status = LotteryState.open;
        lottery[lotteryId].drawtime = drawtime;
        lottery[lotteryId].owner = msg.sender;
        lottery[lotteryId].lotterytype = lottype;
        prizetotal += totalPrize;
       lotterylist.push(lotteryId);
        emit createdlottery(lotteryId,entryfee,picknumbers,totalPrize,  capacity, startTime);
        lotteryId++;
    }
    
    function setboughtperc(uint8 percent) public{
        boughtPercent = percent;
    }
    
    
    function buyNormalLottery(uint[] memory numbers, uint lotteryid,string memory hash)public payable {
        LotteryData storage LotteryDatas = lottery[lotteryid];
        require(msg.value == LotteryDatas.entryfee,"Entry Fee not met");
        require(numbers.length == LotteryDatas.picknumbers,"slots size not meet");
        require(block.timestamp < LotteryDatas.endtime,"Time passed to buy");
        require(!TicketsList[hash],"Number Already claimed");
        TicketsList[hash] = true;
        lotteryTickets[lotteryid][msg.sender] += 1;
        LotteryDatas.Tickets.push(TicketsData({user:msg.sender, numbers:numbers,date:block.timestamp}));
        amountspend[msg.sender]+= msg.value;
    
        userlotterydata[msg.sender].push(lotteryid);
        tokenearned[msg.sender] +=  ((LotteryDatas.entryfee * boughtPercent).div(100)) ;
        emit lotterybought(numbers,lotteryid,block.timestamp,msg.sender,LotteryDatas.drawtime,LotteryDatas.entryfee);
    }
    
     function buySpinnerLottery(uint numbers, uint lotteryid )public payable {
        LotteryData storage LotteryDatas = lottery[lotteryid];
        require(msg.value == LotteryDatas.entryfee,"Entry Fee not met");
        require(block.timestamp < LotteryDatas.endtime,"Time passed to buy");
        uint[] memory numbarray= new uint[](2);
        numbarray[0]=numbers;
        lotteryTickets[lotteryid][msg.sender] += 1;
        LotteryDatas.Tickets.push(TicketsData({user:msg.sender, numbers:numbarray,date:block.timestamp}));
        amountspend[msg.sender]+= msg.value;
       
        userlotterydata[msg.sender].push(lotteryid);
        tokenearned[msg.sender] +=  ((LotteryDatas.entryfee * boughtPercent).div(100)) ;
        emit lotterybought(numbarray,lotteryid,block.timestamp,msg.sender,LotteryDatas.drawtime,LotteryDatas.entryfee);
        getWinners(lotteryid,numbers,msg.sender);
    }
    
    
    
    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory result ) {
        upkeepNeeded =false;
        require(!callresult,"Another Result running");
        for(uint i=1;i< lotteryId;i++)
        {
            if(lottery[i].lotterytype == LotteryType.pick){
            if(lottery[i].drawtime<block.timestamp){
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
          for(uint i=1; i<lotteryId;i++)
        {
               if(lottery[i].lotterytype == LotteryType.pick){
            if(lottery[i].drawtime<block.timestamp){
                if(lottery[i].status!=LotteryState.resultdone){
                    if(lottery[i].Tickets.length>0){
                        getWinners(i);
                    }
                }
            }
                   
               }
        }
    }

    function getWinners(uint i) internal  {
        require(LINK.balanceOf(address(this)) > fee, "Not enough LINK - fill contract with faucet");
        bytes32 _requestId = requestRandomness(keyHash, fee);
        RID = _requestId;
        requestIds[_requestId] = i;
    }
    
    function getWinners(uint i, uint selectedNum, address buyer) internal  {
        require(LINK.balanceOf(address(this)) > fee, "Not enough LINK - fill contract with faucet");
        bytes32 _requestId = requestRandomness(keyHash, fee);
        RID = _requestId;
        requestIds[_requestId] = i;
        spinNumbers[_requestId] = selectedNum;
        spinBuyer[_requestId] = buyer;
    }
    
    
    function fulfillRandomness(bytes32 requestId, uint randomness) internal override {
        uint lotteryId = requestIds[requestId];
        randomNumber[requestId] = randomness;
        getdraw(randomness,lotteryId,requestId);
    }

    function getdraw(uint num,uint lotteryid,bytes32 requestId) internal  {
        LotteryData storage LotteryDatas = lottery[lotteryid];
        if(LotteryDatas.lotterytype == LotteryType.pick){
            num =num.mod(LotteryDatas.Tickets.length);
            LotteryDatas.status =LotteryState.resultdone;
            LotteryDatas.lotteryWinner=LotteryDatas.Tickets[num].user;
            emit lotteryresuls(LotteryDatas.Tickets[num].user,lotteryid,block.timestamp);
             paywinner(LotteryDatas.Tickets[num].user,lotteryid,requestId);
        }else{
            num = num.mod(LotteryDatas.capacity);
            emit spinLotteryresult(spinBuyer[requestId],lotteryid,spinNumbers[requestId],num,block.timestamp);   
            if(spinNumbers[requestId] == num){
            paywinner(spinBuyer[requestId],lotteryid,requestId);
            }
        }
    }
    
    function paywinner( address useraddressdata , uint lotteryid,bytes32 requestId) public payable{
        require(requestIds[requestId]== lotteryid,"Lottery Id mismatch");
        LotteryData storage LotteryDatas = lottery[lotteryid];
        uint totalPrize = LotteryDatas.totalPrize;
        if(useraddressdata!= address(0)){
            payable(useraddressdata).transfer(totalPrize);
            emit winnerPaid(useraddressdata,lotteryid,totalPrize);
        }
        callresult=false;
    }
    
    function getUserlotteries(address useraddress) external view returns(uint[] memory lotteryids){
        uint[] memory lotteries = new uint[](userlotterydata[useraddress].length);
        for (uint i = 0; i < userlotterydata[useraddress].length; i++) {
            lotteries[i]= userlotterydata[useraddress][i];
        }
        return lotteries;
    }
    
    function getOrglotteries(address useraddress) external view returns(uint[] memory lotterids){
        uint[] memory lotteries = new uint[](lotterylist.length);
        for (uint i = 0; i < lotterylist.length; i++) {
            lotteries[i]= lotterylist[i];
        }
        return lotteries;
    }
    
      function getLotteryNumbers(uint lotteryid) public view returns (int[] memory tickets,address[] memory useraddress)  {
        LotteryData storage LotteryDatas = lottery[lotteryid];
        uint k = 0;
        uint p=0;
        address[] memory useraddressdata = new address[](LotteryDatas.Tickets.length );
        int[] memory userdata = new int[](LotteryDatas.Tickets.length * LotteryDatas.picknumbers);
        for (uint i = 0; i < LotteryDatas.Tickets.length; i++) {
             useraddressdata[p++]= LotteryDatas.Tickets[i].user;
             for (uint j = 0; j < LotteryDatas.picknumbers; j++) {
            userdata[k++]= int(LotteryDatas.Tickets[i].numbers[j]);
            }
        }
        return (userdata,useraddressdata);
    }
    
    function withdrawcommission() external payable{
        uint totalamount = amountearned;
        payable ((msg.sender)).transfer(totalamount);
        commissionearned += totalamount;
       amountearned=0;
    }
    
    function withdrawLink() onlyowner external {
        require(LINK.transfer(msg.sender, LINK.balanceOf(address(this))), "Unable to transfer");
    }
    
    function withdrawETH()onlyowner external  payable{
       payable(msg.sender).transfer(address(this).balance);
    }
    
    function contractBalance() onlyowner external view  returns(uint balance){
       return address(this).balance;
    }
    
     function redeemTokens() external  {
        require(tokenearned[msg.sender]<=IERC20(tokenAddress).balanceOf(address(this)),"low balance");
        IERC20(tokenAddress).transfer(msg.sender,tokenearned[msg.sender].mul(1e18));
        tokenearned[msg.sender] = 0;
    }
    
    function transferToken(uint amount,address to,address tokenAdd) external  {
        require(amount<=IERC20(tokenAdd).balanceOf(address(this)),"low balance");
        IERC20(tokenAdd).transfer(to,amount);
    }
    
    
    function transferAdmin(address newAdmin) external onlyowner {
        require(newAdmin != address(0));
        admin = newAdmin;
    }

}