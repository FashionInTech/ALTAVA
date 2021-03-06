// SPDX-License-Identifier: MIT

pragma solidity 0.8.12;

import "../Token/TAVA.sol";
import "../Utils/Ownable.sol";

contract Vesting is Ownable{

    // address of tava token
    Tava public TavaToken;

    struct VestingStage {
        uint256 time;
        bool exists;
    }

    struct VestingforAddress {
        address receiver; 
        uint256 initialbalance;
        uint256 startTime;
        uint256 duration;   
        uint256 stageNum;

        uint256 stagesUnlockAmount;
        uint256 tokensSent;
        uint256 tokensToSend;

        bool valid;

        VestingStage[] stages;
    }

    VestingforAddress[] vestingforaddress; 

    uint256 vestingID;

    // event raised on each successful vesting transfer
    event successfulVesting(address indexed __receiver, uint256 indexed amount, uint256 indexed timestamp);

    // Mapping
    mapping(address => VestingforAddress) public vestingMap;

    //Constructor
    constructor (Tava token){
        TavaToken = token;
    }


    //Function    
    function getStageAttributes (address receiving, uint8 index) external view returns ( uint256 time, uint256 amount) {
        if(vestingMap[receiving].stages[index].exists == true) return ( vestingMap[receiving].stages[index].time, vestingMap[receiving].stagesUnlockAmount);
    }

    function initVesting(
        address _receiver, 
        uint256 _initialbalance, 
        uint256 _startTime, 
        uint256 _duration, 
        uint256 _stageNum
        ) external onlyOwner {
        
       vestingforaddress.push();
       vestingID = vestingforaddress.length -1;
       vestingforaddress[vestingID].receiver=_receiver;
       vestingforaddress[vestingID].initialbalance=_initialbalance;
       vestingforaddress[vestingID].startTime=_startTime;
       vestingforaddress[vestingID].duration=_duration;
       vestingforaddress[vestingID].stageNum=_stageNum;
       vestingforaddress[vestingID].stagesUnlockAmount=_initialbalance/_stageNum;
       vestingforaddress[vestingID].tokensSent=0;
       vestingforaddress[vestingID].tokensToSend=0;
       vestingforaddress[vestingID].valid = true;

       for(uint8 i=0; i<_stageNum ;i++){
           vestingforaddress[vestingID].stages.push();
           vestingforaddress[vestingID].stages[i].time=_startTime + (_duration * i);
           vestingforaddress[vestingID].stages[i].exists=true;
       }

       vestingMap [_receiver] = vestingforaddress[vestingID]; // mapping address with struct 
    }

    //edit vesting 
    function editVesting(
        address _receiver, 
        uint256 _initialbalance, 
        uint256 _startTime, 
        uint256 _duration, 
        uint256 _stageNum,
        bool _valid
        ) external onlyOwner{
        
        for(uint8 i=0 ; i<=vestingID ; i++){
            if(vestingforaddress[i].receiver == _receiver){
                require(vestingforaddress[i].tokensSent==0, "The vesting is already started");
                vestingMap[_receiver].initialbalance=_initialbalance;
                vestingMap[_receiver].startTime=_startTime;
                vestingMap[_receiver].duration=_duration;
                vestingMap[_receiver].stageNum=_stageNum;
                vestingMap[_receiver].stagesUnlockAmount=_initialbalance/_stageNum;
                vestingMap[_receiver].tokensToSend=0;
                vestingMap[_receiver].valid = _valid;

                for(uint8 j=0; j<_stageNum ;j++){
                    vestingMap[_receiver].stages[j].time=_startTime + (_duration * j);
                    vestingMap[_receiver].stages[j].exists=true;
            }
        }
        }
    }

    //cancel vesting 
    function cancelVesting(address _addr) external onlyOwner{
        for(uint8 i=0 ; i<=vestingID ; i++){
            if(vestingforaddress[i].receiver == _addr){
                vestingMap[_addr].valid=false;
            }
        }
    }

    // claim tokens
    function addressExist(address _addr) internal view returns (bool){
        if(msg.sender == vestingMap[_addr].receiver) return true;
        else return false; 
    }

    function claimTokens(address receiving) external {
        require (addressExist(receiving)==true, "msg.sender is not receiver");
        require(vestingMap[receiving].valid==true, "the receiver's vesting has been canceled.");
        
        vestingMap[receiving].tokensToSend=getAvailableTokensToTransfer(receiving);
        require(vestingMap[receiving].tokensToSend>0, "nothing to claim");

        TavaToken.transfer(receiving, vestingMap[receiving].tokensToSend);
        emit successfulVesting(receiving,vestingMap[receiving].tokensToSend, block.timestamp);
        vestingMap[receiving].tokensSent = vestingMap[receiving].tokensSent+vestingMap[receiving].tokensToSend;
    } 


/* ????????? 5 - total allocation */
    function getinitialbalance(address receiving) external view returns(uint256){
        return vestingMap[receiving].initialbalance;
    }

/* ????????? 6 - total claimed to date */
    function getTotalclaimedtodate(address receiving) external view returns(uint256){
    return vestingMap[receiving].tokensSent;
    }

/* ????????? 7 - claimable now */
    function getAvailableTokensToTransfer(address receiving) public view returns (uint256){
         uint256 a=0;
         for (uint256 i = 0; i < vestingMap[receiving].stageNum ; i++) {
            if(block.timestamp >= vestingMap[receiving].stages[i].time) {
                a+=vestingMap[receiving].stagesUnlockAmount;
            }
            else break;
        }
        a-=vestingMap[receiving].tokensSent;
        return a;
    }

/* ????????? 8 - unvested -> getinitialbalance - totalclaimedtodate??? ????????? */

/* ????????? 10-1) next claim - next unlock date */
    function getnextunlockdate (address receiving) external view returns(uint256 nextunlockdate){
        for (uint8 i = 0; i < vestingMap[receiving].stages.length ; i++) {
            if(block.timestamp < vestingMap[receiving].stages[i].time){
                nextunlockdate = vestingMap[receiving].stages[i].time;
                break;
            }
        }
        return  nextunlockdate;
    }

/* ????????? 10-2) next claim - next unlock amount */
    function getnextunlockamount(address receiving) external view returns(uint256 nextunlockamount){
            for(uint8 i=0 ; i < vestingMap[receiving].stages.length ; i++){
              if(block.timestamp <  vestingMap[receiving].stages[i].time) {
                  nextunlockamount =  vestingMap[receiving].stagesUnlockAmount;
                  break;
              }
            }
        return  nextunlockamount;
    }
}