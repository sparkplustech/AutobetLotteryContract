pragma solidity ^0.8.7;

interface IERC20{
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

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

contract AutobetPresale {
    using SafeMath for uint256;
	uint256 public PRESALE_CAP;
	uint256 public EXCHANGE_RATE;
	address public owner;   
	address public tokenaddress;
	uint256 public raised;
    uint256 public totalraised;
	bool public saleactive;
    IERC20 public betToken;

	modifier onlyOwner () {
	require(msg.sender == owner);
	_;
	}
	
	modifier whenActive () {
	require(saleactive == true);
	_;
	}
 
    event bought(address indexed to,uint256 tokens, uint256 amt, uint256 exchangerate);
 
   constructor(IERC20 _tokenaddr,bool _salastatus, uint256 _rate, uint256 _cap) public {
  	owner = msg.sender;
 	betToken = _tokenaddr;
 	saleactive= _salastatus;
    EXCHANGE_RATE=_rate;
    PRESALE_CAP = _cap;
   }
 
    function buyToken() public  payable whenActive{
        uint256 convamt = msg.value.mul(EXCHANGE_RATE);
        require(raised+convamt<=PRESALE_CAP,"Cap reached");
        require(gettokenBalance()>=convamt,"Less Amount in ontract" );
        raised+=convamt;
        totalraised += convamt;
        betToken.transfer(msg.sender,convamt);
        emit bought(msg.sender,convamt,msg.value,EXCHANGE_RATE);
    }
	
     function gettokenBalance() public view returns (uint bal){
        return betToken.balanceOf(address(this));
    }
    
    function transferTokens(address to,uint amount) external onlyOwner {
        require( amount<=betToken.balanceOf(address(this)),"low balance");
        betToken.transfer(to,amount.mul(1e18) );
    }
    
    function transferEth(uint256 amount,address to)onlyOwner external  payable{
         payable(to).transfer(amount);
 	}
	
	function stageChange(uint256 _rate, uint256 _cap, bool _isAcitve)public onlyOwner {
    		EXCHANGE_RATE=_rate;
    		PRESALE_CAP = _cap;
    		saleactive = _isAcitve;
            raised=0;
	}
	
	function setExchangeRate(uint256 _rate) public onlyOwner {
    	EXCHANGE_RATE=_rate;
	}
	
	function setIsActive(bool _isAcitve) public onlyOwner {
        saleactive=_isAcitve;
    }
 
	function setTokenaddress(address _taddress) public onlyOwner {
    	tokenaddress=_taddress;
	}
   
	function setPresaleCap(uint256 cap) public onlyOwner {
    	PRESALE_CAP=cap;
	}

}
