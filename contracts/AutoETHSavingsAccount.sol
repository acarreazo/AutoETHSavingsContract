pragma solidity ^0.5.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be aplied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 */
contract ReentrancyGuard {
    // counter to allow mutex lock with only one SSTORE operation
    uint256 private _guardCounter;

    constructor () internal {
        // The counter starts at one to prevent changing it from zero to a non-zero
        // value, which is a more expensive operation.
        _guardCounter = 1;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _guardCounter += 1;
        uint256 localCounter = _guardCounter;
        _;
        require(localCounter == _guardCounter, "ReentrancyGuard: reentrant call");
    }
}

contract Ownable {

  address payable public owner;

  constructor() public {
    owner = msg.sender;
  }

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }
  
  
  function transferOwnership(address payable newOwner) external onlyOwner {
    require(newOwner != address(0));      
    owner = newOwner;
  }

}

library SafeMath {
    
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }


    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
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
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;

        return c;
    }

   
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}

interface CTokenInterface {
    function redeemUnderlying(uint redeemAmount) external returns (uint);
}


interface CETHInterface {
    function mint() external payable; // For ETH
}

interface ERC20Interface {
    function allowance(address, address) external view returns (uint);
    function balanceOf(address) external view returns (uint);
    function approve(address, uint) external;
    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
}


contract AutoETHSavingsAccount is Ownable, ReentrancyGuard{
    using SafeMath for uint;
    
    // state variables
    address payable private savingsAccount;
    uint public balance = address(this).balance;
    bool private stopped = false;
    
    //circuit breaker modifiers
    modifier stopInEmergency {if (!stopped) _;}
    modifier onlyInEmergency {if (stopped) _;}

    constructor () public {
    }
    
    function toggleContractActive() onlyOwner public {
    stopped = !stopped;
    }
    
    // this function lets you add and replace the old SavingsAccount in which the marginal savings will be deposited
    function addSavingsAccounts (address payable _address) onlyOwner public {
        savingsAccount = _address;
    }
    
    // this function lets you deposit ETH into this wallet
    function depositETH() payable public returns (uint) {
        balance += msg.value;
    }
    // fallback function let you / anyone send ETH to this wallet without the need to call any function
    function() external payable {
        balance += msg.value;
    }
    // Through this function you will be making a normal payment to any external address or a wallet address as in the normal situation    
    function payETH(address payable _to, uint _amount, uint _pettyAmount) stopInEmergency onlyOwner nonReentrant external returns (uint) {
        uint grossPayableAmount = SafeMath.add(_amount, _pettyAmount);
        require(balance > SafeMath.add(grossPayableAmount, 20000000000000000), "the balance held by the Contract is less than the amount required to be paid");
        balance = balance - _amount - _pettyAmount;
        savePettyCash(_pettyAmount);
        _to.transfer(_amount);
        }
        
    // Depositing the savings amount into the Savings Account   
    function savePettyCash(uint _pettyAmount) internal {
        savingsAccount.transfer(_pettyAmount);
    }
    
    function withdraw() onlyOwner onlyInEmergency public{
        owner.transfer(address(this).balance);
    }

}

contract DSMath {

    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, "math-not-safe");
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        z = x - y <= x ? x - y : 0;
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, "math-not-safe");
    }

    uint constant WAD = 10 ** 18;

    function wmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), WAD / 2) / WAD;
    }

    function wdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, WAD), y / 2) / y;
    }

}


contract Helpers is DSMath {

    /**
     * @dev get ethereum address for trade
     */
    function getAddressETH() public pure returns (address eth) {
        eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    }

  
    /**
     * @dev get Compound Comptroller Address
     */
    function getCETHAddress() public pure returns (address cEth) {
        cEth = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
    }


    /**
     * @dev setting allowance to compound for the "user proxy" if required
     */
    function setApproval(address erc20, uint srcAmt, address to) internal {
        ERC20Interface erc20Contract = ERC20Interface(erc20);
        uint tokenAllowance = erc20Contract.allowance(address(this), to);
        if (srcAmt > tokenAllowance) {
            erc20Contract.approve(to, 2**255);
        }
    }

}


contract CompoundResolver is Helpers {

		event LogMint(address erc20, address cErc20, uint tokenAmt, address owner);
		event LogRedeem(address erc20, address cErc20, uint tokenAmt, address owner);
		
		/**
		 * @dev Deposit ETH/ERC20 and mint Compound Tokens
		 */
		function mintCEth(uint tokenAmt) internal {
			CETHInterface cToken = CETHInterface(getCETHAddress());
			cToken.mint.value(tokenAmt)();
			emit LogMint(
				getAddressETH(),
				getCETHAddress(),
				tokenAmt,
				msg.sender
			);
		}

		/**
		 * @dev Redeem ETH/ERC20 and mint Compound Tokens
		 * @param tokenAmt Amount of token To Redeem
		 */
		function redeemEth(uint tokenAmt) internal {
			CTokenInterface cToken = CTokenInterface(getCETHAddress());
			setApproval(getCETHAddress(), 10**30, getCETHAddress());
			require(cToken.redeemUnderlying(tokenAmt) == 0, "something went wrong");
			emit LogRedeem(
				getAddressETH(),
				getCETHAddress(),
				tokenAmt,
				address(this)
			);
		}

   

	}

