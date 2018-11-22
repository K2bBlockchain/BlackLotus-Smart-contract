pragma solidity 0.4.25;
/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // Gas optimization: this is cheaper than asserting 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (a == 0) {
      return 0;
    }

    c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    // uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return a / b;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }
}

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
 constructor() public {
    owner = msg.sender;
  }
  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }
  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) onlyOwner public {
    require(newOwner != address(0));
    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }
}

/**
 * @title EscrowVault
 * @dev This contract is used for storing funds while a crowdsale
 * is in progress. Supports refunding the money if whitelist fails,
 * and forwarding it if whitelist is successful.
 */
contract EscrowVault {
    
  using SafeMath for uint256;
  
 // Stages of the contract
 enum State { Active, Refunding, Success, Closed }
 State public state;
  
  //Backer's Object'
  struct BackerState{
      uint256 depositedAmount;
      uint256 votingPercentage;
      bool votingStatus;
  }
  
  //map to the Backer's object'
  mapping (address => BackerState) public backerState;
  //map to the voting percentage for Backer
  mapping (address => uint256) public votingPercentagePerBacker;
  address public owner;
  
  //Wallet summary
  uint256 public votingPercentage;
  uint256 public dayscalculation;
  uint256 public voteAcceptingPercentage =100;
  uint256 public projectBalance;
  uint256 public endtime;
  uint256 public requestAmount;
  address public maxPayee;
  uint256 public backersCount;
  uint256 public refundingCount;
  uint256 public amountTransfer;
  uint256 public raisedAmount;
  
  uint256 public time = block.timestamp;
  uint256 public fee;

  uint256 public closingTime;
  address public founder;
  
  //Backers list
  address[] public payees;
  
  //Backers vote acceptance list
  address[] public votingAccept;
  
  //Backers vote decline list
  address[] public votingDecline;
  
  //Events
  event Refunded(address indexed beneficiary, uint256 weiAmount);
  event paid(address indexed beneficiary, uint256 weiAmount);
  
   /**
    * @dev Create a wallet generation for Blacklotus
    * @param _closingtime uint256 The closing date to the project 
    * @param _founder address The founder of the project
    * @param _owner address The Owner of this project
    * @param _votingPercentage uint256 The minimum voting percentage of this project
    */
 constructor(uint256 _closingtime, address _founder,address _owner, uint256 _votingPercentage) public{
    state = State.Active;
    closingTime=_closingtime;
    dayscalculation = closingTime.add(12 weeks);
    founder=_founder;
    owner=_owner;
    votingPercentage=_votingPercentage;
 }
  
   /**
    * @dev Deposit the amount to the project and it will fallback to the deposit() function
    */    
  function () external payable {
      deposit(msg.sender);
  }
  
    /**
    * @dev Backer contributes/deposit the amount to the project stage is active
    * _beneficiary address The backer account
    */
  function deposit(address _beneficiary) public payable{
          require(state == State.Active);
          uint256 weiAmount=msg.value;
          uint256 value=1;
          BackerState storage contribState = backerState[msg.sender];
            if(contribState.depositedAmount == 0){
                payees.push(msg.sender);
               backersCount = backersCount.add(value);
          }
          contribState.votingStatus=true;
          contribState.depositedAmount = contribState.depositedAmount.add(weiAmount);
          projectBalance = projectBalance.add(weiAmount);
          raisedAmount = raisedAmount.add(weiAmount);

          emit paid(_beneficiary,weiAmount);
  }
  
  /**
    * @dev Founder can request amount (full or some part of wallet balance) from the project when stage is opened,
    * @param _amount uint256 The request amount from the project.
    * @param _endtime uint256 The request closing time 
    */
  function founderRequest(uint256 _endtime,uint256 _amount) public onlyFounder{
    // require(_endtime>time);
      require(_amount>0);
      require(address(this).balance>_amount);
      endtime=_endtime;
      requestAmount=_amount;
      
      for(uint i=0;i<payees.length;i++){
           BackerState storage contribState = backerState[payees[i]];
           uint256 depositedValue=contribState.depositedAmount;
         contribState.votingPercentage = uint256(SafeMath.mul(SafeMath.div(depositedValue, raisedAmount), 100));
         }
      
  }
  
   /**
    * @dev Backer can accept the vote request amount
    */
  function votingAccepting() public{
     // require(endtime>=time);
      require(requestAmount>0);
      BackerState storage contribState = backerState[msg.sender];
      require(contribState.votingStatus != false);
      //require(voting[msg.sender]!=false);
       uint256 depositedValue = contribState.depositedAmount;
       assert(depositedValue>0);
       contribState.votingStatus = true;
       votingAccept.push(msg.sender);
  }
  
   /**
    * @dev Backer can decline the vote request amount
    */
   function votingDeclining() public{
     // require(endtime>=time);
      require(requestAmount>0);
      BackerState storage contribState = backerState[msg.sender];
      require(contribState.votingStatus==true);
    //   require(voting[msg.sender]==true);
       uint256 depositedValue = contribState.depositedAmount;
       assert(depositedValue>0);
       contribState.votingStatus = false;
       votingDecline.push(msg.sender);
       uint256 votePercentageBacker = contribState.votingPercentage;
       voteAcceptingPercentage = voteAcceptingPercentage.sub(votePercentageBacker);
   }
  
   /**
    * @dev Founder can release the fund from wallet and amount send to the founder or backer
    */
  function enableRelease() public {
    // require(endtime<=time);
      fee = uint256(SafeMath.div(SafeMath.mul(2, 95), 100));
      projectBalance = projectBalance.sub(fee);
      owner.transfer(fee);
      uint256 maxAmount=0;
      for(uint i=0;i<payees.length;i++){
           BackerState storage contribState = backerState[payees[i]];
            uint256 depositedValue=contribState.depositedAmount;
            if(maxAmount<=depositedValue){
                maxPayee=payees[i];
                maxAmount=depositedValue;
            }
         }
         
         if(voteAcceptingPercentage > votingPercentage || backerState[maxPayee].votingStatus==true){
             state = State.Success;
             
         }
         
         if(votingAccept.length==0 || endtime >= time){
             state = State.Success;
         }
         
          if(voteAcceptingPercentage < votingPercentage || backerState[maxPayee].votingStatus==false){
             state = State.Refunding;
              delete votingAccept;
              delete votingDecline;
         }
             
         }
    
     /**
    * @dev Founder can release the fund from wallet ofter 90 days
    */ 
    function enableReleaseFor90Days() public {
      require(address(this).balance > 0);
      require(dayscalculation<=time);
      owner.transfer(address(this).balance);
      state = State.Closed;
     }
  
    /**
   * @dev Founder claim the request amount .
   */
  function beneficiaryWithdraw() public onlyFounder{
        require(founder==msg.sender);
        require(state == State.Success);
        
        assert(address(this).balance>=requestAmount);
        founder.transfer(requestAmount);
        projectBalance = projectBalance.sub(requestAmount);
        requestAmount = 0;
        state = State.Active;
     
        if(address(this).balance <= 0) {
            state = State.Closed;
        }
        delete votingAccept;
        delete votingDecline;
    
    }
    
     /**
   * @dev Backer can claim the amount from wallet when refund stage. .
   */
    function refund() public    {
        require(projectBalance>=0);
        require(state == State.Refunding);
        BackerState storage contribState = backerState[msg.sender];
        uint256 value=1;
        uint256 depositedValue = contribState.depositedAmount;
        amountTransfer = uint256(SafeMath.div(SafeMath.mul(address(this).balance, contribState.votingPercentage), 100));
        assert(depositedValue>0);
        msg.sender.transfer(amountTransfer);
        contribState.votingPercentage = 0;
        projectBalance = projectBalance.sub(amountTransfer);
        emit Refunded(msg.sender, depositedValue);
        contribState.depositedAmount = depositedValue.sub(depositedValue);
        refundingCount = refundingCount.add(value);
         if(refundingCount == backersCount) {
              state = State.Closed;
          }
  }
  
  /**
   * @dev Throws if called by any account other than the admin.
   */
  modifier onlyFounder() {
    require(msg.sender == founder);
    _;
  }
  
  /**
   * @dev Reverts if not in closingTime time range.
   */
  modifier hasClosed {
    // solium-disable-next-line security/no-block-members
    require( closingTime <= time);
    _;
  }

}

contract BlackLotus   {
    address public wallet;
    address public owner;
    
    constructor() public{
        owner=msg.sender;
    }
    
     /**
    * @dev Create a wallet generation for Blacklotus
    * @param _closingtime uint256 The closing date to the project 
    * @param _votingPercentage uint256 The minimum voting percentage of this project
    */
    function generateWallet(uint256 _closingtime, uint256 _votingPercentage) public{
        wallet = new EscrowVault(_closingtime,msg.sender,owner, _votingPercentage);
    }
    
}
