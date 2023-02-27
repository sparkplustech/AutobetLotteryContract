pragma solidity 0.6.6;

import "https://raw.githubusercontent.com/smartcontractkit/chainlink/develop/evm-contracts/src/v0.6/ChainlinkClient.sol";
import {randomness_interface} from "./interfaces/randomness_interface.sol";
import {governance_interface} from "./interfaces/governance_interface.sol";

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
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
 
        return c;
    }
 
}

contract Autobet is ChainlinkClient {
    using SafeMath for uint256;
    bytes32 internal keyHash;
    uint256 internal fee;
    address public admin;
    uint256 public rolloverrate= 30;
    uint256 public randomResult;
    uint public lotteryId = 1;
    uint public ownerId =1;
    uint public drawid;
    uint256 public buytotal =0;
    uint256 public prizetotal =0;
    address private oracle;
    bytes32 private jobId;
    uint256 public volume;
    string public  url="https://min-api.cryptocompare.com/data/pricemultifull?fsyms=MATIC&tsyms=USD";


    governance_interface public governance;

    enum LotteryState {
        open,
        close,
        resultdone
    }
    
    struct Owners{
        uint id;
        address useraddress;
        string name;
        bool active;
        uint256 amountearned;
    }
    
    struct TicketsData {
        address user;
        uint[] numbers;
        uint date;
    }
    
    struct LotteryData {
        uint lotteryId; // Lottery Id.
        uint256 entryfee;  
        uint createdOn;
        uint picknumbers;//ticket need to be selected
        uint256 totalPrize; // Total wining price.
        uint startTime; // Start time of Lottery.
        uint endtime; // End time of lottery.
        uint capacity; // Total size of lottery.
        uint drawtime;
        uint salecount;
        uint[] lotteryWinners;
        LotteryState status;
        TicketsData[]  Tickets;
        address owner;
        uint ownerid;
        string ownername;
    }
    
    modifier onlyowner{
    require(organisations[msg.sender].active,"Not a organisation");
        _;
        
    }
    
    modifier onlyAdmin {
        require(admin == msg.sender, "not-a-admin");
        _;
    }
    
    // Mapping owner id => details of the owner.
    mapping (uint => Owners) public organisation; 
    mapping (address => Owners) public organisations; 
    
    // Mapping lottery id => details of the lottery.
    mapping (uint => LotteryData) public lottery;
    
    //Mapping  useraddress => amountspend
    mapping(address => uint) public amountspend;
    
    //Mapping  useraddress => amountwon
    mapping(address => uint) public amountwon;
    
    mapping(address => uint[]) private userlotterydata;
    
    mapping(address => uint[]) private orglotterydata;
    
    // Mapping of lottery id => user address => no of tickets
    mapping (uint => mapping (address => uint)) public lotteryTickets;
    
    event createdlottery(uint indexed lotteryId,uint entryfee,uint picknumbers,uint totalPrize, uint capacity, address indexed owner,uint startTime,uint indexed ownerid);
    
    event lotterybought(uint[]numbers, uint indexed lotteryId ,uint boughtOn, address indexed useraddress,uint drawOn,uint paid);
    
    event lotteryresuls(uint[]numbers, uint indexed lotteryId , uint drawOn, address[] useraddressdata);

    event prizedistributed(address useraddress,uint amount, uint indexed lotteryId , uint date);

    constructor(address _governance)  public
    {
        setPublicChainlinkToken();
        governance = governance_interface(_governance);
        admin = msg.sender;
        oracle = 0x7AFe1118Ea78C1eae84ca8feE5C65Bc76CcF879e;
        jobId = "6d1bfe27e7034b1d87b5270556b17277";
        fee = 0.1 * 10 ** 18; // 0.1 LINK
    }
    
    /** 
     * Requests randomness from a user-provided seed
     */
     
    function createLottery(uint256 entryfee,
        uint picknumbers,
        uint256 totalPrize,
        uint startTime,
        uint endtime,
        uint drawtime,
        uint capacity) public onlyowner payable {
        require(totalPrize > 0,"Low totalPrice");
        require(totalPrize==msg.value,"Amount not matching");
        require(startTime >= now,"Start time passed");
        require(startTime < endtime,"End time less than start time");
        lottery[lotteryId].lotteryId = lotteryId;
        lottery[lotteryId].entryfee = entryfee;
        lottery[lotteryId].createdOn = now;
        lottery[lotteryId].picknumbers = picknumbers;
        lottery[lotteryId].totalPrize = totalPrize;
        lottery[lotteryId].startTime = startTime;
        lottery[lotteryId].endtime = endtime;
        lottery[lotteryId].capacity = capacity;
        lottery[lotteryId].lotteryWinners = new uint[](0);
        lottery[lotteryId].status = LotteryState.open;
        lottery[lotteryId].owner = msg.sender;
        lottery[lotteryId].drawtime = drawtime;
        lottery[lotteryId].ownername = organisations[msg.sender].name;
        lottery[lotteryId].ownerid = organisations[msg.sender].id;
        lottery[lotteryId].salecount = 0;
        prizetotal += totalPrize;
        orglotterydata[msg.sender].push(lotteryId);
        emit createdlottery(lotteryId,entryfee,picknumbers,totalPrize,  capacity,  msg.sender, startTime, organisations[msg.sender].id);
        lotteryId++;
    }
    
  
    function addOrganisation(address _owner,string memory _name) public {
         assert(_owner != address(0));
         require(organisations[_owner].useraddress == address(0),"Already notregistered" );
         organisations[_owner] = Owners({id:ownerId, useraddress:_owner,name:_name, active:false, amountearned:0 });
         organisation[ownerId++] = Owners({id:ownerId, useraddress:_owner,name:_name, active:false, amountearned:0 });
        
    }
     
    function approveOraganisation(uint id)public onlyAdmin{
        organisation[id].active = true;
        organisations[organisation[id].useraddress].active= true;
    }
    function requestVolumeData() public returns (bytes32 requestId) 
    {
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);
        
        // Set the URL to perform the GET request on
        request.add("get",url);
        
        // Set the path to find the desired data in the API response, where the response format is:
        // {"RAW":
        //   {"MATIC":
        //    {"USD":
        //     {
        //      "VOLUME24HOUR": xxx.xxx,
        //     }
        //    }
        //   }
        //  }
        request.add("path", "RAW.MATIC.USD.VOLUME24HOUR");
        
        // Multiply the result by 1000000000000000000 to remove decimals
        int timesAmount = 10**18;
        request.addInt("times", timesAmount);
        
        // Sends the request
        return sendChainlinkRequestTo(oracle, request, fee);
    }
    
    /**
     * Receive the response in the form of uint256
     */ 
    function fulfill(bytes32 _requestId, uint256 _volume) public recordChainlinkFulfillment(_requestId)
    {
        volume = _volume;
    }
    
    function buyLottery(uint[] memory numbers, uint lotteryid)public payable {
        LotteryData storage LotteryDatas = lottery[lotteryid];
        require(msg.value == LotteryDatas.entryfee,"Entry Fee not meet");
        require(numbers.length == LotteryDatas.picknumbers,"slots size not meet");
        require(now < LotteryDatas.endtime,"Time passed to buy");
        require(noDuplicates(numbers),"Duplicate number");
        lotteryTickets[lotteryid][msg.sender] += 1;
        LotteryDatas.Tickets.push(TicketsData({user:msg.sender, numbers:numbers,date:now}));
        amountspend[msg.sender]+= msg.value;
        lottery[lotteryid].salecount= lottery[lotteryid].salecount+1;
        buytotal += LotteryDatas.entryfee; 
        organisation[LotteryDatas.ownerid].amountearned += msg.value;
        userlotterydata[msg.sender].push(lotteryid);
        emit lotterybought(numbers,lotteryid,now,msg.sender,LotteryDatas.drawtime,LotteryDatas.entryfee);
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
    
    function getWinnerNumbers(uint256 userProvidedSeed,uint256 lotteryid) public onlyowner returns (bytes32 requestId) {
        LotteryData storage LotteryDatas = lottery[lotteryid];
        require(LotteryDatas.status != LotteryState.resultdone,"Result Already done");
        require(LotteryDatas.owner == msg.sender,"Not owner of lottery");
        drawid= lotteryid;
        randomness_interface(governance.randomness()).getRandom(userProvidedSeed, lotteryid);
    }
    /**
     * Callback function used by VRF Coordinator
     */
    function fulfill_random(uint256 randomness)external {
        randomResult = randomness;
        getdraw(randomResult,drawid);
    }
    
    function getdraw(uint256 num,uint lotteryid)public payable{
        LotteryData storage LotteryDatas = lottery[lotteryid];
        uint count = 0;
        uint p = 0;
        uint256[] memory winner = new uint256[](LotteryDatas.picknumbers);
        address[] memory useraddressdata = new address[](LotteryDatas.Tickets.length );
        while(count< LotteryDatas.picknumbers){
            uint256 numbers = uint256(keccak256(abi.encodePacked(num,count,now)));
            numbers =numbers%LotteryDatas.capacity+1;
            if(count==0){
             winner[count]=numbers;
             count++;
            }
            else{
            bool matched = false;
            for(uint j=0;j<winner.length;j++){
            if(numbers == winner[j]){
            matched =true;
            break;
            }
            else
            matched =false;
            }
             if(!matched){
                winner[count]=numbers;
                count++;
             }
            }
         }
        LotteryDatas.status =LotteryState.resultdone;
        LotteryDatas.lotteryWinners=winner;
        emit lotteryresuls(winner,lotteryid,now,useraddressdata);
        requestVolumeData();
    }
    
    function rollover(uint lotteryid) public {
        LotteryData storage LotteryDatas = lottery[lotteryid];
        uint count = 0;
        uint p=0;
        uint256[] memory winner = new uint256[](LotteryDatas.picknumbers);
        address[] memory useraddressdata = new address[](LotteryDatas.Tickets.length );
         for (uint ticketid = 0; ticketid < LotteryDatas.Tickets.length; ticketid++) {
        count=0;
        for (uint numpos = 0; numpos < LotteryDatas.picknumbers; numpos++) {
            if(numpos==1&&count==0)
            break;
            for (uint winnumpos = 0; winnumpos < winner.length; winnumpos++) {
            if(winner[winnumpos]==LotteryDatas.Tickets[ticketid].numbers[numpos]){
             count=count+1;
             break;
             }
            }
            if(count==LotteryDatas.picknumbers)
            useraddressdata[p++] = LotteryDatas.Tickets[ticketid].user;
        }
        }
        count=0;
        for(uint userpos = 0; userpos < p; userpos++){
            if(useraddressdata[userpos]!= address(0)){
                count++;
            }
        }
        if(count!=0){
        uint amountoeach = LotteryDatas.totalPrize.div(count);
        for(uint userpos = 0; userpos < p; userpos++){
            address win=  useraddressdata[userpos];
            if(win!= address(0)){
           address(uint160(win)).transfer(amountoeach);
           amountwon[win]= amountwon[win]+amountoeach;
           emit prizedistributed(win,amountoeach,lotteryid,now);
            }
         }
        }
        else{
        uint256 totalsale =LotteryDatas.salecount.mul(LotteryDatas.entryfee);
        uint256 finalprize = LotteryDatas.totalPrize + (totalsale.mul(rolloverrate)).div(100);
        uint startTime = now;
        lottery[lotteryId].lotteryId = lotteryId;
        lottery[lotteryId].entryfee = LotteryDatas.entryfee;
        lottery[lotteryId].createdOn = startTime;
        lottery[lotteryId].picknumbers = LotteryDatas.picknumbers;
        lottery[lotteryId].totalPrize = finalprize;
        lottery[lotteryId].startTime = startTime;
        lottery[lotteryId].endtime =  (startTime + (LotteryDatas.endtime - LotteryDatas.startTime));
        lottery[lotteryId].capacity = LotteryDatas.capacity;
        lottery[lotteryId].lotteryWinners = new uint[](0);
        lottery[lotteryId].status = LotteryState.open;
        lottery[lotteryId].owner = LotteryDatas.owner;
        lottery[lotteryId].drawtime = (startTime + ( LotteryDatas.drawtime - LotteryDatas.startTime));
        lottery[lotteryId].ownername = LotteryDatas.ownername;
        lottery[lotteryId].ownerid = LotteryDatas.ownerid;
        lottery[lotteryId].salecount = 0;
        prizetotal += finalprize;
        orglotterydata[LotteryDatas.owner].push(lotteryId);
        emit createdlottery(lotteryId,LotteryDatas.entryfee,LotteryDatas.picknumbers,finalprize,LotteryDatas.capacity,LotteryDatas.owner,startTime,LotteryDatas.ownerid);
        lotteryId++;
        }
    }
    
    function noDuplicates(uint[] memory array) public pure returns (bool){
        for (uint i = 0; i < array.length - 1; i++) {
            for (uint j = i + 1; j < array.length; j++) {
                if (array[i] == array[j]) return false;
            }
        }
        return true;
    }
    
    function getUserlotteries(address useraddress) public view returns(uint[] memory lotteryids){
        uint[] memory lotteries = new uint[](userlotterydata[useraddress].length);
        for (uint i = 0; i < userlotterydata[useraddress].length; i++) {
            lotteries[i]= userlotterydata[useraddress][i];
        }
        return lotteries;
    }
    
    function getOrglotteries(address useraddress) public view returns(uint[] memory lotterids){
        uint[] memory lotteries = new uint[](orglotterydata[useraddress].length);
        for (uint i = 0; i < orglotterydata[useraddress].length; i++) {
            lotteries[i]= orglotterydata[useraddress][i];
        }
        return lotteries;
    }
    
    function withdrawcommission(uint _ownerid) public payable{
        uint256 totalamount = organisation[_ownerid].amountearned;
        address(uint160(organisation[_ownerid].useraddress)).transfer(totalamount);
        organisation[_ownerid].amountearned=0;
    }
    
    function withdrawLink() onlyAdmin external {
        randomness_interface(governance.randomness()).withdrawLink();

     }

    function withdrawETH()onlyAdmin public  payable{
        msg.sender.transfer(address(this).balance);
    }
    
    function transferAdmin(address newAdmin) public onlyAdmin {
        require(newAdmin != address(0));
        admin = newAdmin;
    }

}


//rinkby cA 0xFA5f4F9c5A72504091735453b528D09560E05547