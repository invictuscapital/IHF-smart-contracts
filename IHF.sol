pragma solidity ^0.4.18;

import "./StandardToken.sol";

contract IHF is StandardToken {
  using SafeMath for uint256;

  string public name = "Invictus Hyperion";
  string public symbol = "IHF";
  uint8 public decimals = 18;
  string public version = "1.0";

  uint256 public fundingEndBlock;

  // vesting fields
  address public vestingContract;
  bool private vestingSet = false;

  address public fundWallet1;
  address public fundWallet2;

  bool public tradeable = false;

  // maybe event for mint

  modifier isTradeable { // exempt vestingContract and fundWallet to allow dev allocations
      require(tradeable || msg.sender == fundWallet1 || msg.sender == vestingContract);
      _;
  }

  modifier onlyFundWallets {
      require(msg.sender == fundWallet1 || msg.sender == fundWallet2);
      _;
  }

  // constructor
  function IHF(address backupFundWallet, uint256 endBlockInput) public {
      require(backupFundWallet != address(0));
      require(block.number < endBlockInput);
      fundWallet1 = msg.sender;
      fundWallet2 = backupFundWallet;
      fundingEndBlock = endBlockInput;
  }

  function setVestingContract(address vestingContractInput) external onlyFundWallets {
      require(!vestingSet); // can only be called once
      require(vestingContractInput != address(0));
      vestingContract = vestingContractInput;
      vestingSet = true;
  }

  function allocateTokens(address participant, uint256 amountTokens) private {
      require(vestingSet);
      // 2.5% of total allocated for Invictus Capital & Team
      uint256 developmentAllocation = amountTokens.mul(25641025641025641).div(1000000000000000000);
      uint256 newTokens = amountTokens.add(developmentAllocation);
      // increase token supply, assign tokens to participant
      totalSupply_ = totalSupply_.add(newTokens);
      balances[participant] = balances[participant].add(amountTokens);
      balances[vestingContract] = balances[vestingContract].add(developmentAllocation);
      emit Transfer(address(0), participant, amountTokens);
      emit Transfer(address(0), vestingContract, developmentAllocation);
  }

  function batchAllocate(address[] participants, uint256[] values) external onlyFundWallets returns(uint256) {
      require(block.number < fundingEndBlock);
      uint256 i = 0;
      while (i < participants.length) {
        allocateTokens(participants[i], values[i]);
        i++;
      }
      return(i);
  }

  // @dev sets a users balance to zero, adjusts supply and dev allocation as well
  function adjustBalance(address participant) external onlyFundWallets {
      require(vestingSet);
      require(block.number < fundingEndBlock);
      uint256 amountTokens = balances[participant];
      uint256 developmentAllocation = amountTokens.mul(25641025641025641).div(1000000000000000000);
      uint256 removeTokens = amountTokens.add(developmentAllocation);
      totalSupply_ = totalSupply_.sub(removeTokens);
      balances[participant] = 0;
      balances[vestingContract] = balances[vestingContract].sub(developmentAllocation);
      emit Transfer(participant, address(0), amountTokens);
      emit Transfer(vestingContract, address(0), developmentAllocation);
  }

  function changeFundWallet1(address newFundWallet) external onlyFundWallets {
      require(newFundWallet != address(0));
      fundWallet1 = newFundWallet;
  }
  function changeFundWallet2(address newFundWallet) external onlyFundWallets {
      require(newFundWallet != address(0));
      fundWallet2 = newFundWallet;
  }

  function updateFundingEndBlock(uint256 newFundingEndBlock) external onlyFundWallets {
      require(block.number < fundingEndBlock);
      require(block.number < newFundingEndBlock);
      fundingEndBlock = newFundingEndBlock;
  }

  function enableTrading() external onlyFundWallets {
      require(block.number > fundingEndBlock);
      tradeable = true;
  }

  function() payable public {
      require(false); // throw
  }

  function claimTokens(address _token) external onlyFundWallets {
      require(_token != address(0));
      ERC20Basic token = ERC20Basic(_token);
      uint256 balance = token.balanceOf(this);
      token.transfer(fundWallet1, balance);
   }

   function removeEth() external onlyFundWallets {
      fundWallet1.transfer(address(this).balance);
    }

    function burn(uint256 _value) external onlyFundWallets {
      require(balances[msg.sender] >= _value);
      balances[msg.sender] = balances[msg.sender].sub(_value);
      balances[0x0] = balances[0x0].add(_value);
      totalSupply_ = totalSupply_.sub(_value);
      emit Transfer(msg.sender, 0x0, _value);
    }

   // prevent transfers until trading allowed
   function transfer(address _to, uint256 _value) isTradeable public returns (bool success) {
       return super.transfer(_to, _value);
   }
   function transferFrom(address _from, address _to, uint256 _value) isTradeable public returns (bool success) {
       return super.transferFrom(_from, _to, _value);
   }

}
