// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../Token/TAVA.sol";
import "../Utils/SafeMath.sol";
import "../Utils/Ownable.sol";

contract Vesting is SafeMath, Ownable{

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

    /*

    Mapping

    */

    mapping(address => VestingforAddress) public vestingMap;

    /* 

    Constructor 

    */

    constructor (Tava token){
        TavaToken = token;
    }


    /*

    Function 

    */
    
    function getStageAttributes (address receiving, uint8 index) public view returns ( uint256 time, uint256 amount) {
        if(vestingMap[receiving].stages[index].exists == true) return ( vestingMap[receiving].stages[index].time, vestingMap[receiving].stagesUnlockAmount);
    }

    function initVesting(
        address _receiver, 
        uint256 _initialbalance, 
        uint256 _startTime, 
        uint256 _duration, 
        uint256 _stageNum,
        bool _valid
        ) public onlyOwner {
        
       vestingforaddress.push();
       vestingID = vestingforaddress.length -1;
       vestingforaddress[vestingID].receiver=_receiver;
       vestingforaddress[vestingID].initialbalance=_initialbalance;
       vestingforaddress[vestingID].startTime=_startTime;
       vestingforaddress[vestingID].duration=_duration;
       vestingforaddress[vestingID].stageNum=_stageNum;
       vestingforaddress[vestingID].stagesUnlockAmount=div(_initialbalance,_stageNum);
       vestingforaddress[vestingID].tokensSent=0;
       vestingforaddress[vestingID].tokensToSend=0;
       vestingforaddress[vestingID].valid = true;

       uint256 __time=_startTime;

       vestingforaddress[vestingID].stages.push();
       vestingforaddress[vestingID].stages[0].time=__time;
       vestingforaddress[vestingID].stages[0].exists=true;

       for(uint8 i=1; i<_stageNum ;i++){
           vestingforaddress[vestingID].stages.push();
           __time+=_duration;
           vestingforaddress[vestingID].stages[i].time=__time;
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
        ) public onlyOwner{
        
        for(uint8 i=0 ; i<=vestingID ; i++){
            if(vestingforaddress[i].receiver == _receiver && vestingforaddress[i].tokensSent==0){
                require(vestingforaddress[i].tokensSent==0, "The vesting is already started");
                vestingMap[_receiver].initialbalance=_initialbalance;
                vestingMap[_receiver].startTime=_startTime;
                vestingMap[_receiver].duration=_duration;
                vestingMap[_receiver].stageNum=_stageNum;
                vestingMap[_receiver].stagesUnlockAmount=div(_initialbalance,_stageNum);
                vestingMap[_receiver].tokensToSend=0;
                vestingMap[_receiver].valid = _valid;

                uint256 __time=_startTime;

                vestingMap[_receiver].stages[0].time=_startTime;
                vestingMap[_receiver].stages[0].exists=true;
                
                for(uint8 j=1; j<_stageNum ;j++){
                    __time+=_duration;
                    vestingMap[_receiver].stages[j].time=__time;
                    vestingMap[_receiver].stages[j].exists=true;
            }
        }
        }
    }

    //cancel vesting 

    function cancelVesting(address _addr) public onlyOwner{
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

    function setAvailableTokensToTransfer(address receiving) public {
        vestingMap[receiving].tokensToSend=0;
        require (addressExist(receiving)==true, "msg.sender is not receiver");
        require(vestingMap[receiving].valid==true, "msg.sender is not receiver");
        for (uint8 i = 0; i < vestingMap[receiving].stageNum ; i++) {
            if(block.timestamp >= vestingMap[receiving].stages[i].time) {
                vestingMap[receiving].tokensToSend= add(vestingMap[receiving].tokensToSend,vestingMap[receiving].stagesUnlockAmount);
            }
        }
        vestingMap[receiving].tokensToSend = sub(vestingMap[receiving].tokensToSend,vestingMap[receiving].tokensSent);
    }

    function claimTokens(address receiving) public {
        require (addressExist(receiving)==true, "msg.sender is not receiver");
        require(vestingMap[receiving].valid==true, "msg.sender is not receiver");
        setAvailableTokensToTransfer(receiving);
        require(vestingMap[receiving].tokensToSend>0, "nothing to claim");

        TavaToken.transfer(receiving, vestingMap[receiving].tokensToSend);
        vestingMap[receiving].tokensSent = add(vestingMap[receiving].tokensSent, vestingMap[receiving].tokensToSend);
        vestingMap[receiving].tokensToSend = sub(vestingMap[receiving].tokensToSend,vestingMap[receiving].tokensSent);
        emit successfulVesting(receiving,vestingMap[receiving].tokensToSend, block.timestamp);
    } 


/* 기획서 5 - total allocation */
    function getinitialbalance(address receiving) public view returns(uint256){
        return vestingMap[receiving].initialbalance;
    }

/* 기획서 6 - total claimed to date */
    function getTotalclaimedtodate(address receiving) public view returns(uint256){
    return vestingMap[receiving].tokensSent;
    }

/* 기획서 7 - claimable now */
    function getAvailableTokensToTransfer(address receiving) public view returns (uint256){
        // need to execute setAvailableTokensToTransfer before executing this function 
        return vestingMap[receiving].tokensToSend;
    }

/* 기획서 8 - unvested -> getinitialbalance - totalclaimedtodate로 구하기 */

/* 기획서 10-1) next claim - next unlock date */
    function getnextunlockdate (address receiving) public view returns(uint256 nextunlockdate){
        for (uint8 i = 0; i < vestingMap[receiving].stages.length ; i++) {
            if(block.timestamp < vestingMap[receiving].stages[i].time){
                nextunlockdate = vestingMap[receiving].stages[i].time;
                break;
            }
        }
        return  nextunlockdate;
    }

/* 기획서 10-2) next claim - next unlock amount */
    function getnextunlockamount(address receiving) public view returns(uint256 nextunlockamount){
            for(uint8 i=0 ; i < vestingMap[receiving].stages.length ; i++){
              if(block.timestamp <  vestingMap[receiving].stages[i].time) {
                  nextunlockamount =  vestingMap[receiving].stagesUnlockAmount;
                  break;
              }
            }
        return  nextunlockamount;
    }
}