pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";



interface KeeperCompatibleInterface {
 function checkUpkeep(bytes calldata) external  returns (bool upkeepNeeded, bytes memory ) ;
    
    function performUpkeep( bytes calldata ) external ;
}     

contract Autobet is VRFConsumerBase, KeeperCompatibleInterface {
    bytes32 internal keyHash;
    uint256 internal fee;
    address public admin;
    uint256 public randomResult;
    uint public lotteryId = 1;
    uint public ownerId =1;
    uint public drawid;
    uint256 public buytotal =0;
    uint256 public prizetotal =0;
    bool public callresult =true;
    uint winnerlotteryid;
     
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
        uint256 commissionearned;
    }
    
    struct TicketsData {
        address user;
        uint[] numbers;
        uint date;
    }
    
    struct LotteryData {
        uint lotteryId; 
        uint256 entryfee;  
        uint picknumbers;//ticket numbers need to be selected
        uint256 totalPrize; // Total wining price.
        uint startTime; // Start time of Lottery.
        uint endtime; // End time of lottery.
        uint capacity; // Total size of lottery.
        uint drawtime;
        uint winnerId;
        uint[] numberspicked;
        address lotteryWinner;
        LotteryState status;
        TicketsData[]  Tickets;
        address owner;
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
    
    event lotteryresuls(address useraddressdata, uint indexed lotteryId , uint drawOn);

    event prizedistributed(address useraddress,uint amount, uint indexed lotteryId , uint date);

    constructor() 
        VRFConsumerBase(
            0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B,
            0x01BE23585060835E02B77ef475b0Cc51aA1e0709  // LINK Token
        ) public
    {
        keyHash = 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311;
        fee = 0.1 * 10 ** 18; // 0.1 LINK
        admin = msg.sender;
    }
    
     
    function createLottery(uint256 entryfee,
        uint picknumbers,
        uint256 totalPrize,
        uint startTime,
        uint endtime,
        uint drawtime,
        uint capacity) public  payable {
        require(totalPrize > 0,"Low totalPrice");
        require(totalPrize==msg.value,"Amount not matching");
        require(startTime >= block.timestamp,"Start time passed");
        require(startTime < endtime,"End time less than start time");
        lottery[lotteryId].lotteryId = lotteryId;
        lottery[lotteryId].entryfee = entryfee;
        lottery[lotteryId].picknumbers = picknumbers;
        lottery[lotteryId].totalPrize = totalPrize;
        lottery[lotteryId].startTime = startTime;
        lottery[lotteryId].endtime = endtime;
        lottery[lotteryId].capacity = capacity;
        lottery[lotteryId].numberspicked = new uint[](capacity);
        lottery[lotteryId].lotteryWinner = address(0);
        lottery[lotteryId].status = LotteryState.open;
        lottery[lotteryId].drawtime = drawtime;
        prizetotal += totalPrize;
        orglotterydata[msg.sender].push(lotteryId);
        emit createdlottery(lotteryId,entryfee,picknumbers,totalPrize,  capacity,  msg.sender, startTime, organisations[msg.sender].id);
        lotteryId++;
    }
    
  
    function addOrganisation(address _owner,string memory _name) public {
        assert(_owner != address(0));
        require(organisations[_owner].useraddress == address(0),"Already notregistered" );
        organisations[_owner] = Owners({id:ownerId, useraddress:_owner,name:_name, active:false, amountearned:0, commissionearned:0 });
        organisation[ownerId++] = Owners({id:ownerId, useraddress:_owner,name:_name, active:false, amountearned:0 ,commissionearned:0});
        
    }
     
    function approveOraganisation(uint id)public onlyAdmin{
        organisation[id].active = true;
        organisations[organisation[id].useraddress].active= true;
    }
    
    function buyLottery(uint[] memory numbers, uint lotteryid)public payable {
        LotteryData storage LotteryDatas = lottery[lotteryid];
        require(msg.value == LotteryDatas.entryfee,"Entry Fee not meet");
        require(numbers.length == LotteryDatas.picknumbers,"slots size not meet");
        require(block.timestamp< LotteryDatas.endtime,"Time passed to buy");
        require(notIncludeded(numbers,lotteryid),"Number Already claimed");
        require(noDuplicates(numbers),"Duplicate number");
        lotteryTickets[lotteryid][msg.sender] += 1;
        LotteryDatas.Tickets.push(TicketsData({user:msg.sender, numbers:numbers,date:block.timestamp}));
        amountspend[msg.sender]+= msg.value;
        buytotal += LotteryDatas.entryfee; 
        organisations[LotteryDatas.owner].amountearned += msg.value;
        userlotterydata[msg.sender].push(lotteryid);
        emit lotterybought(numbers,lotteryid,block.timestamp,msg.sender,LotteryDatas.drawtime,LotteryDatas.entryfee);
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
    
    function getWinnerNumbers(uint256 userProvidedSeed,uint lotteryid) public onlyowner returns (bytes32 requestId) {
        require(callresult==true,"Result System busy");
        require(LINK.balanceOf(address(this)) > fee, "Not enough LINK - fill contract with faucet");
        LotteryData storage LotteryDatas = lottery[lotteryid];
        require(LotteryDatas.status != LotteryState.resultdone,"Result Already done");
        require(LotteryDatas.owner == msg.sender,"Not owner of lottery");
        drawid= lotteryid;
        callresult= false;
        return requestRandomness(keyHash, fee);
    }
    /**
     * Callback function used by VRF Coordinator
     */
   
    
    
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomResult = randomness;
      
    }
   
    uint public counter;
    uint bt= block.timestamp;
    function checkUpkeep(bytes calldata) external override returns (bool upkeepNeeded, bytes memory ) {
        upkeepNeeded =(block.timestamp >= bt+2);
        

    }
    
    function performUpkeep( bytes calldata ) external override {
        
      
        counter+1;
    }
     
    

    
    function notIncludeded(uint[] memory array,uint lotteryid) public view returns (bool){
       LotteryData storage LotteryDatas = lottery[lotteryid];
         uint[] memory  numberspicked = LotteryDatas.numberspicked;
        for (uint i = 0; i < array.length; i++) {
            for (uint j = 0; j < numberspicked.length; j++) {
                if (numberspicked[j] == array[i]) return false;
            }
        }
        return true;
    }
    
    function noDuplicates(uint[] memory array) internal pure returns (bool){
        for (uint i = 0; i < array.length - 1; i++) {
            for (uint j = i + 1; j < array.length; j++) {
                if (array[i] == array[j]) return false;
            }
        }
        return true;
    }
    
    function getUserlotteries(address useraddress) external view returns(uint[] memory lotteryids){
        uint[] memory lotteries = new uint[](userlotterydata[useraddress].length);
        for (uint i = 0; i < userlotterydata[useraddress].length; i++) {
            lotteries[i]= userlotterydata[useraddress][i];
        }
        return lotteries;
    }
    
    function getOrglotteries(address useraddress) external view returns(uint[] memory lotterids){
        uint[] memory lotteries = new uint[](orglotterydata[useraddress].length);
        for (uint i = 0; i < orglotterydata[useraddress].length; i++) {
            lotteries[i]= orglotterydata[useraddress][i];
        }
        return lotteries;
    }
    
    function withdrawcommission() external payable{
        uint256 totalamount = organisations[msg.sender].amountearned;
        payable (msg.sender).transfer(totalamount);
        organisations [msg.sender].commissionearned += totalamount;
        organisations[msg.sender].amountearned=0;
    }
    
    function withdrawLink() onlyAdmin external {
        require(LINK.transfer(msg.sender, LINK.balanceOf(address(this))), "Unable to transfer");
    }
    
    function withdrawETH()onlyAdmin external  payable{
        payable (msg.sender).transfer(address(this).balance);
    }
    
    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0));
        admin = newAdmin;
    }

}