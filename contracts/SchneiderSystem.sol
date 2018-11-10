/**
 * @author https://github.com/Dmitx
 */

pragma solidity ^0.4.24;

import "./token/ERC20/IERC20.sol";
import "./oraclize/oraclizeAPI_0.4.25.sol";
import "./math/SafeMath.sol";


/**
 * @title SchneiderSystem
 * @dev Main contract of Schneider System. 
 */
contract SchneiderSystem is usingOraclize {
    using SafeMath for uint256;


    // ** EVENTS **

    // Event for new oraclize query logging
    event NewOraclizeQuery(string description);

    // Event for verified logging
    event Verified(bytes32 myid, string price, bytes proof);


    // ** PUBLIC STATE VARIABLES **

    // token
    IERC20 public token;

    // Timestamp of start
    uint256 public startTime;

    // Timestamp of end
    uint256 public endTime;

    // energy meter reading
    uint256 public startKwh;
    uint256 public endKwh;

    // current period metrics
    uint256 public goalPeriodKwh;
    uint256 public prevPeriodKwh;

    // addresses
    address public customerAddr;
    address public schneiderAddr;

    // global state of system
    bool public isFinished;

    // Oraclize transaction gas limit
    uint256 public constant ORACLIZE_GAS_LIMIT = 150000;

    
    // ** CONSTRUCTOR **

    /**
    * @dev Constructor of SchneiderSystem Contract
    * @param _tokenAddr token address
    * @param _endTime end time of period
    * @param _prevPeriodKwh kWh for previous period
    * @param _goalPeriodKwh goal kWh for period
    * @param _customer  customer address
    * @param _schneider schneider address
    */
    constructor(
        address _tokenAddr,
        uint256 _endTime,
        uint256 _startKwh,
        uint256 _prevPeriodKwh,
        uint256 _goalPeriodKwh,
        address _customer,
        address _schneider
    ) 
        public 
        payable
    {
        require(_endTime > now, "endTime must be more then now date");
        require(_prevPeriodKwh > _goalPeriodKwh, "goal must be less then now prev period kWh");

        _setToken(_tokenAddr);
        startTime = now;
        endTime = _endTime;
        startKwh = _startKwh;
        prevPeriodKwh = _prevPeriodKwh;
        goalPeriodKwh = _goalPeriodKwh;

        customerAddr = _customer;
        schneiderAddr = _schneider;

        // set oraclize proof - TLSNotary
        oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);
    }


    // ** EXTERNAL PAYABLE FUNCTIONS **

    function() external payable {}


    // ** EXTERNAL FUNCTIONS **

    /**
    * @dev Withdrawal eth from contract
    * @param _amount eth
    */
    function withdrawEth(uint256 _amount) 
        external 
        // onlyOwner
    {
        require(_amount <= address(this).balance, "Not enough funds");
        require(now > endTime, "Now must be more then end date");
        msg.sender.transfer(_amount);
    }

    /**
    * @dev Verify energy meter
    */
    function verify() 
        external 
    { 
        require(now > endTime, "Now must be more then end date");
        _update();
    }


    // ** ORACLIZE CALLBACKS **

    function __callback(
        bytes32 myId,
        string result
    )
        public 
    {
        require(msg.sender == oraclize_cbAddress(), "Sender is not Oraclize address");
        _oraclizeCallback(myId, result, "NONE");
    }

    function __callback(
        bytes32 myId,
        string result,
        bytes proof
    )
        public 
    {
        require(msg.sender == oraclize_cbAddress(), "Sender is not Oraclize address");
        _oraclizeCallback(myId, result, proof);
    }

    
    // ** PUBLIC VIEW FUNCTIONS **

    /**
    * @return total tokens of this contract.
    */
    function contractTokenBalance()
        public 
        view 
        returns(uint256 amount) 
    {
        return token.balanceOf(this);
    }


    // ** PRIVATE HELPER FUNCTIONS **

    // Helper: oraclize query
    function _update() 
        internal 
    {   
        if (oraclize_getPrice("URL", ORACLIZE_GAS_LIMIT) > address(this).balance) {
            emit NewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        } else {
            emit NewOraclizeQuery("Oraclize query was sent, standing by for the answer..");
            oraclize_query("URL", "json(http://165.227.135.82:5000/energy_ticker/get_tick).value", ORACLIZE_GAS_LIMIT);
        }
    }

    //Helper: oraclize callback
    function _oraclizeCallback(
        bytes32 _queryId,
        string _result,
        bytes _proof
    )
        internal
    {
        // is finished yet
        require(!isFinished);
        isFinished = true;

        endKwh = parseInt(_result, 3); // kWh * 1e3

        uint256 deltaKwh = endKwh.sub(startKwh);

        if (deltaKwh < prevPeriodKwh && deltaKwh > goalPeriodKwh) {
            // withdrawal tokens to customer and schneider
            _transferTokens(customerAddr, contractTokenBalance().mul(prevPeriodKwh - deltaKwh).div(prevPeriodKwh - goalPeriodKwh));
            _transferTokens(schneiderAddr, contractTokenBalance());
        } else if (deltaKwh >= prevPeriodKwh) {
            // withdrawal all tokens to customer
            _transferTokens(customerAddr, contractTokenBalance());
        } else {
            // withdrawal all tokens to schneider
            _transferTokens(schneiderAddr, contractTokenBalance());
        }

        emit Verified(_queryId, _result, _proof);
    }

    // Helper: transfer tokens
    function _transferTokens(
        address _addr,
        uint256 _amount
    )
        internal
    {
        require(token.transfer(_addr, _amount), "tokens are not transferred");
    }

    // Helper: Set the address of Azbit Token
    function _setToken(address _tokenAddress) 
        internal 
    {
        token = IERC20(_tokenAddress);
        require(contractTokenBalance() >= 0, "The token being added is not ERC20 token");
    }

}