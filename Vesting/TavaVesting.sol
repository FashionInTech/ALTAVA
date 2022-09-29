// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.9;
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ITavaVesting.sol";

contract TavaVesting is ITavaVesting, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    address public tavaTokenAddress;
    uint256 public TotalTokensReceived = 0;
    uint256 public TotalTokensReceiveable = 0;
    uint256 constant tavaDecimal = 10 ** 18;
    
    mapping (address => VestingInfo[]) public vestingInfoToWallets;

    constructor(
        address _tavaTokenAddress
    ) {
        tavaTokenAddress = _tavaTokenAddress;
    }

    // modifier
    modifier notZeroAddress(address caller) {
        require(caller != address(0), "Cannot perform call function for address(0).");
        _;
    }

    // TAVA 잔액 조회
    function BalanceToAddress(address account) 
        external view returns(uint256)
    {
        return IERC20(tavaTokenAddress).balanceOf(account);
    }
    
    // public
    function TokensCurrentlyReceiveable(address _receiver, uint256 _vestingIdx) 
        public view override returns(uint256 _ReciveableTokens)
    {
        VestingCondition memory _vestingCondition = vestingInfoToWallets[_receiver][_vestingIdx].vestingCondition;
        uint256 _elapsedDays = getElapsedDays(_receiver, _vestingIdx);
        uint256 _totalAmount = vestingInfoToWallets[_receiver][_vestingIdx].totalAmount;
        if(_elapsedDays > _vestingCondition.unlockCnt){
            _elapsedDays = _vestingCondition.unlockCnt;
        }

        if(_elapsedDays == 0) {
            return 0;
        }

        uint256 _tokensPerStage = _totalAmount*(tavaDecimal)/(_vestingCondition.unlockCnt);
        uint256 receiveableTava = _tokensPerStage*(_elapsedDays);
        uint256 receivedTava = sentTavasToAdr(_receiver, _vestingIdx)*(tavaDecimal);

        if(receiveableTava < receivedTava){
            return 0;
        } else {
            return _ReciveableTokens = receiveableTava - receivedTava;
        }
    }

    function getElapsedDays(address _receiver, uint256 _vestingIdx) 
        public view override returns(uint256 _elapsedDays)
    {
        VestingCondition memory _vestingCondition = vestingInfoToWallets[_receiver][_vestingIdx].vestingCondition;
        uint256 _duration = _vestingCondition.duration;
        if(block.timestamp > _vestingCondition.startDt) {
            return (block.timestamp - _vestingCondition.startDt)/(_duration * 1 days);
        } else {
            return 0;
        }
    }
    
    function sentTavasToAdr(address _receiver, uint256 _vestingIdx) 
        public view override returns(uint256 _sentTavas)
    {
        return _sentTavas = vestingInfoToWallets[_receiver][_vestingIdx].tokensSent;
    }
    // public end


    /**
        정상적인경우 사용할 일 없으나 혹여 이슈로 인한 대응이 가능하도록 보상받는 ERC20 주소를 변경 할 수 있도록 함.
    */
    function setTavaAddress(address _tavaTokenAddress) 
        external onlyOwner
    {
        tavaTokenAddress = _tavaTokenAddress;
    }

    /**
        * _unlockedTokenAmount가  로 나누어 떨어지지 않으면, user는   전체를 받아가지 못_unlockCnt _unlockedTokenAmount함 
        
        -- 해당 부분이 어떤의미인지 알 수 없음. 나누어 떨어지지않아도 보상수령이 가능한 것을 확인함.
        -- decimal 을 곱해서 나누어 주면 소숫점문제로 적게 받는 부분을 최소화 하여 계산하게 됨.
        -- 나누어서 몫이 잘 떨어지는 부분은 확인되어서 문제가 없을 것으로 예상됨


        * _StartDt 값이 (실수로) 작은 값 또는 0이 입력되면, user는 의도보다 빠르게 token을 claim할 수 있음

        -- 테스트를 위하여 과거의 시간을 넣을 수 있도록 되어있는 상태
        -- 관리자가 프론트단에서 date picker 를통해 넣을 것이기 때문에 문제가 없을 것으로 예상됨
    */
    function setVesting(
        address _receiver, 
        uint256 _unlockedTokenAmount, 
        uint256 _duration,
        uint256 _unlockCnt,
        uint256 _startDt
    ) 
        external override onlyOwner notZeroAddress(_receiver)
    {
        require(_unlockedTokenAmount > 0, "setVesting_ERR01");
        require(_duration > 0, "setVesting_ERR02");
        require(_unlockCnt > 0, "setVesting_ERR03");
        VestingCondition memory _vestingCondition = VestingCondition(_duration, _unlockCnt, _startDt);
        vestingInfoToWallets[_receiver].push(VestingInfo(_vestingCondition, _unlockedTokenAmount, 0, true));

        uint256 AmountToReceived = _unlockedTokenAmount*(tavaDecimal);

        IERC20(tavaTokenAddress).transferFrom(_msgSender(), address(this), AmountToReceived);
        TotalTokensReceiveable += AmountToReceived;
        emit createdVesting(_receiver, (vestingInfoToWallets[_receiver].length -1), AmountToReceived, _duration, _unlockCnt, _startDt);

    }

    function cancelVesting(address _receiver, uint256 _vestingIdx) 
        external override onlyOwner
    {
        require(sentTavasToAdr(_receiver, _vestingIdx) == 0, "cancelVesting_ERR01");
        uint256 _elapsedDays = getElapsedDays(_receiver, _vestingIdx);
        require(_elapsedDays == 0, "cancelVesting_ERR02");

        uint256 TheAmountReceived = (vestingInfoToWallets[_receiver][_vestingIdx].totalAmount)*(tavaDecimal);

        require(TotalTokensReceiveable > TheAmountReceived, "cancelVesting_ERR03");
        TotalTokensReceiveable = TotalTokensReceiveable - TheAmountReceived;
        vestingInfoToWallets[_receiver][_vestingIdx].valid = false;
        emit canceledVesting(_receiver, _vestingIdx);
    }


    /**
        * approvalTava()의 작성 의도를 이해하기 힘듬

        -- IERC20(tavaTokenAddress).transferFrom(_msgSender(), address(this), AmountToReceived); 해당부분 L122 에서 함수 실행시 필수적으로 권한이 부여되어야함
        -- 관리자의 토큰을 프론트 플로우로 contract 에 전달하기 위하여 필요함
    */
    function approvalTava(uint256 _amount) 
        external override 
    {
        IERC20(tavaTokenAddress).approve(address(this), _amount*(tavaDecimal));
    }

    function claimVesting(uint256 _vestingIdx) 
        external override notZeroAddress(_msgSender()) nonReentrant returns(uint256 _TokenPayout)
    {
        require(vestingInfoToWallets[_msgSender()][_vestingIdx].valid, "claimVesting_ERR01");   // 취소된 베스팅인지 확인
        
        uint256 _elapsedDays = getElapsedDays(_msgSender(), _vestingIdx);
        
        require(_elapsedDays > 0, "claimVesting_ERR02"); // 경과시간이 duration 을 최초 1번 지난 경우 경과일(days 단위 표시)
        
        uint256 _tokensSent = sentTavasToAdr(_msgSender(), _vestingIdx); // 단위 ether
        uint256 _totalAmount = vestingInfoToWallets[_msgSender()][_vestingIdx].totalAmount; // 단위 ether
        
        require(_totalAmount > _tokensSent, "claimVesting_ERR03");
        
        uint256 _currentAmount = TokensCurrentlyReceiveable(_msgSender(), _vestingIdx); // 단위 wei
        
        require(_currentAmount > 0, "claimVesting_ERR04");

        IERC20(tavaTokenAddress).transfer(_msgSender(), _currentAmount);

        //uint256 _currentAmountToTava = _currentAmount/(tavaDecimal); // 단위 ether
        vestingInfoToWallets[_msgSender()][_vestingIdx].tokensSent += _currentAmount;
        TotalTokensReceived += _currentAmount;
        emit claimedVesting(_msgSender(), _vestingIdx, _currentAmount, block.timestamp);

        return _TokenPayout = _currentAmount;
    }

    function claimTava() 
        external override onlyOwner
    {
        uint256 _TavaBalance = IERC20(tavaTokenAddress).balanceOf(address(this));
        IERC20(tavaTokenAddress).transfer(owner(), _TavaBalance);
    }

    function claimTava(uint256 _amount) 
        external override onlyOwner
    {
        IERC20(tavaTokenAddress).transfer(owner(), _amount*(tavaDecimal));
    }
}