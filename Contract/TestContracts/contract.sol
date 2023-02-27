pragma solidity 0.6.6;

import "https://raw.githubusercontent.com/smartcontractkit/chainlink/master/evm-contracts/src/v0.6/VRFConsumerBase.sol";

contract Autobet is VRFConsumerBase {
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
    uint256 public callrollover;
    enum LotteryState {
        open,
        close,
        resultdone,
        prizedone,
        rolloverneeded,
        rolloverdone
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
        address[] winneraddress;
        LotteryState status;
        TicketsData[]  Tickets;
        address owner;
        uint ownerid;
        string ownername;
    }
     
    
    modifier onlyowner{
    require(organisationbyaddr[msg.sender].active,"Not a organisation");
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
    
    event needcreaterollover( uint indexed lotteryId);

    event winnerdone( uint indexed lotteryId);
    
   constructor(address linktoken) 
        VRFConsumerBase(
            0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B,
            linktoken  // LINK Token
        ) public 
    {
        keyHash = 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311;
        fee = 0.1 * 10 ** 18; // 0.1 LINK
        admin = msg.sender;
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
        require(totalPrize == msg.value,"Amount not matching");
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
        lottery[lotteryId].ownername = organisationbyaddr[msg.sender].name;
        lottery[lotteryId].ownerid = organisationbyaddr[msg.sender].id;
        lottery[lotteryId].salecount = 0;
        prizetotal += totalPrize;
        orglotterydata[msg.sender].push(lotteryId);
        emit createdlottery(lotteryId,entryfee,picknumbers,totalPrize,  capacity,  msg.sender, startTime, organisationbyaddr[msg.sender].id);
        lotteryId++;
    }
    
  
    function addOrganisation(address _owner,string memory _name) public {
         assert(_owner != address(0));
         require(organisationbyaddr[_owner].useraddress == address(0),"Already notregistered" );
         organisationbyaddr[_owner] = Owners({id:ownerId, useraddress:_owner,name:_name, active:false, amountearned:0 });
         organisation[ownerId++] = Owners({id:ownerId, useraddress:_owner,name:_name, active:false, amountearned:0 });
        
    }
     
    function approveOraganisation(uint id)public onlyAdmin{
        organisation[id].active = true;
        organisationbyaddr[organisation[id].useraddress].active= true;
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
    
    function getWinnerNumbers(uint256 userProvidedSeed,uint lotteryid) public onlyowner returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) > fee, "Not enough LINK - fill contract with faucet");
        LotteryData storage LotteryDatas = lottery[lotteryid];
        require(LotteryDatas.status != LotteryState.resultdone,"Result Already done");
        require(LotteryDatas.owner == msg.sender,"Not owner of lottery");
        drawid= lotteryid;
        return requestRandomness(keyHash, fee, userProvidedSeed);
    }
    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomResult = randomness;
         getdraw(randomness,drawid);
    }
    
    function getdraw(uint256 num,uint lotteryid)public {
        LotteryData storage LotteryDatas = lottery[lotteryid];
        uint count = 0;
        uint p = 0;
        uint c= 0;
        uint256[] memory winner = new uint256[](LotteryDatas.picknumbers);
        address[] memory useraddressdata = new address[](LotteryDatas.Tickets.length );
        address[] memory winneraddress = new address[](LotteryDatas.Tickets.length );
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
                winneraddress[c++] = useraddressdata[userpos];
            }
        }
        LotteryDatas.status =LotteryState.resultdone;
        LotteryDatas.lotteryWinners=winner;
        LotteryDatas.winneraddress = winneraddress;
        emit lotteryresuls(winner,lotteryid,now,useraddressdata);
         if(count!=0){
            LotteryDatas.status = LotteryState.prizedone;
         emit winnerdone(lotteryid);
         paywinner(p,useraddressdata, count,lotteryid);
         }
          else{
             LotteryDatas.status = LotteryState.rolloverneeded;
            emit needcreaterollover(lotteryid);
          }
        
    }
    
    function createrollover(uint lotteryid) onlyowner public {
        LotteryData storage LotteryDatas = lottery[lotteryid];
        uint256 totalsale =LotteryDatas.salecount.mul(LotteryDatas.entryfee);
        uint256 finalprize = LotteryDatas.totalPrize + (totalsale.mul(rolloverrate)).div(100);
        uint startTime = now;
        LotteryDatas.status= LotteryState.rolloverdone;
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
    
    function paywinner(uint p, address[] memory useraddressdata ,uint count,uint lotteryid) public payable{
         LotteryData storage LotteryDatas = lottery[lotteryid];
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
    
    function withdrawLink() external {
        require(LINK.transfer(msg.sender, LINK.balanceOf(address(this))), "Unable to transfer");
    }
    
    function withdrawETH()onlyAdmin public  payable{
        msg.sender.transfer(address(this).balance);
    }
    
    function transferAdmin(address newAdmin) public onlyAdmin {
        require(newAdmin != address(0));
        admin = newAdmin;
    }

}