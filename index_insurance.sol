// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Creating the DroughtInsurance contract
contract DroughtInsurance {

  // Farmer struct to store farmer's information
  struct Farmer {
    string firstName;
    string lastName;
    uint region; // The region code of the farmer
    }

  // Defining the variables
  uint public premium; // Premium amount in wei (1 ether = 10^18 wei)
  uint public payout; // Payout amount in wei
  int public indexThreshold; // The threshold index value for drought
  int private index;
  address public creator; // smart contract deployer
  Farmer private newFarmer; // A new Farmer struct instance
  uint private timeOfYearBeginning;
  uint private secondsPerYear;
  uint private secondsSinceYearBeginning;
  address[] private currentInsured; // array of current Insured for iteration over mapping
  address[] private futureInsured;  // array of future Insured for iteration over mapping

  // Mapping: map Farmer to available, claimable amount (aka obligation)
  mapping (address => uint) private farmerToObligation;
  // Mapping for future obligations
  mapping (address => uint) private farmerToFutureObligation;
  // Mapping: Farmer to registration
  mapping (address => Farmer) private farmerToRegistration;
  // Mapping: see if a farmer has already registered (much more efficient than iteration over array)
  mapping (address => bool) private farmerRegistered;

  // Initializing the contract and setting the variables
  constructor(uint _premium, uint _payout, int _indexThreshold) {
    premium = 1000000000000000000 * _premium; // 1000000000000000000 Wei = 1 Ether
    payout = 1000000000000000000 * _payout;
    indexThreshold = _indexThreshold;
    creator = msg.sender;
    secondsPerYear = 31536000;
    timeOfYearBeginning = block.timestamp - (block.timestamp % secondsPerYear);
  }

    // Setting Premium in case of risk increase/decrease (only SC owner should be able to do it)
  function setPremium(uint newPremium) public {
    require(msg.sender == creator, "Only risk assessor owner can set premium.");
    premium = newPremium;
  }

  // Setting Payout in case of risk increase/decrease (only SC owner should be able to do it)
  function setPayout(uint newPayout) public {
    require(msg.sender == creator, "Only risk assessor can set payout.");
    payout = newPayout;
  }

  // farmer registration, adds farmer structure to mapping with claimable amount (aka obligation)
  function register(string memory _firstName, string memory _lastName, uint _region) public {
    require(farmerRegistered[msg.sender] == false, "You have already registered.");
    newFarmer = Farmer(_firstName, _lastName, _region);
    farmerToRegistration[msg.sender] = newFarmer;
    farmerToObligation[msg.sender] = 0;
    farmerRegistered[msg.sender] = true;
  }

  // this function checks and enforces the time constraints and will be called anytime another function is called
  function resetYear() private {
    secondsSinceYearBeginning = block.timestamp - timeOfYearBeginning;
    if (secondsSinceYearBeginning > secondsPerYear) {
      secondsSinceYearBeginning += secondsPerYear;
      for (uint i=0; i < currentInsured.length ; i++){
        farmerToObligation[currentInsured[i]] = 0;
      }
      delete currentInsured;
      for (uint i=0; i < futureInsured.length ; i++) {
        farmerToObligation[futureInsured[i]] = farmerToFutureObligation[futureInsured[i]];
        farmerToFutureObligation[futureInsured[i]] = 0;
        currentInsured.push(futureInsured[i]);
      }
      delete futureInsured;
    }
  }

  // Creating the function to buy insurance the year before
  function buyInsurance() public payable {
    // resetYear(); // checks time constraint transits obligations
    require(farmerRegistered[msg.sender] == true, "You need to register first.");
    require(farmerToFutureObligation[msg.sender] == 0, "You have already bought an insurance.");
    require(msg.value == premium, "Incorrect premium amount."); // amount in wei
    farmerToFutureObligation[msg.sender] = payout; // payout == claimable amount (aka obligation)
    farmerToObligation[msg.sender] = payout; // THIS ONE IS USED FOR PRESENTATION PURPOSE ONLY
    futureInsured.push(msg.sender);
  }

  // Creating the function to check if a drought has occurred
  // serves as pseudo-oracle and for presentation purposes
  function checkDrought(uint region) private returns(bool) {
    if (region == 2) {
        index = -2;
    } else {
        index = 1;
    }
    if (index < indexThreshold) {
      return true;
    } else {
      return false;
    }
  }

  // Claim
  // I believe the claimer should pay the oracle fees to avoid excessive claiming and subsequent
  function claim(uint amount) public {
    // resetYear(); // check time constraint
    require(farmerToObligation[msg.sender] >= amount, "Your open balance is too low.");

    // Checking if a drought has occurred
    bool isDrought = checkDrought(farmerToRegistration[msg.sender].region);

    // Paying out the insurance if a drought has occurred
    require(isDrought == true, "Your region was not affected by a drought.");
    payable(msg.sender).transfer(1000000000000000000 * amount); // send claimed amount in ether
    farmerToObligation[msg.sender] -= amount; // reduce obligation by amount claimed
  }
}
