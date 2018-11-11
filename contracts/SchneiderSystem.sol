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

    // Event for verified energy logging
    event VerifiedEnergy(bytes32 myid, string kWh, bytes proof);


    // ** PUBLIC STATE VARIABLES **

    // token
    IERC20 public token;

    // timestamps
    uint256 public startTime;
    uint256 public endTime;

    // update interval in seconds
    uint256 public updateTime;

    // energy meter reading in kWh
    uint256 public startMeter;
    uint256 public endMeter;

    // current period metrics in kWh
    uint256 public promisedLoad;
    uint256 public curLoad;

    // addresses
    address public customerAddr;
    address public schneiderAddr;

    // Oraclize transaction gas limit
    uint256 public constant ORACLIZE_GAS_LIMIT = 250000;

    
    // ** CONSTRUCTOR **

    /**
    * @dev Constructor of SchneiderSystem Contract
    * @param _tokenAddr token address
    * @param _endTime end time of period
    * @param _updateTime update interval in seconds
    * @param _curLoad kWh for previous period
    * @param _customer  customer address
    * @param _schneider schneider address
    */
    constructor(
        address _tokenAddr,
        uint256 _endTime,
        uint256 _updateTime,
        uint256 _curLoad,
        address _customer,
        address _schneider
    ) 
        public 
        payable
    {
        require(_endTime > now, "endTime must be more then now date");

        _setToken(_tokenAddr);
        
        startTime = now;
        endTime = _endTime;
        updateTime = _updateTime;

        curLoad = _curLoad;
        promisedLoad = getPromisedLoad(_curLoad);

        customerAddr = _customer;
        schneiderAddr = _schneider;

        // set oraclize proof - TLSNotary
        oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);

        // initial update - upload of startMeter
        _update(0);
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
        _update(0);
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

    
    // ** PUBLIC PURE FUNCTIONS **

    /**
    * @return promised load in kWh.
    */
    function getPromisedLoad(uint256 _curLoad)
        public 
        pure 
        returns(uint256 load)
    {
        return _curLoad.mul(73).div(100);
    }


    // ** PRIVATE HELPER FUNCTIONS **

    // Helper: oraclize query
    function _update(uint256 _updateTime) 
        internal 
    {   
        if (oraclize_getPrice("URL", ORACLIZE_GAS_LIMIT) > address(this).balance) {
            emit NewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        } else {
            emit NewOraclizeQuery("Oraclize query was sent, standing by for the answer..");
            oraclize_query(_updateTime, "URL", "json(http://165.227.135.82:5000/energy_ticker/get_tick).value", ORACLIZE_GAS_LIMIT);
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
        require(endMeter == 0);

        // check start or end time callback
        if (startMeter == 0) {
            startMeter = parseInt(_result, 3); // kWh * 1e3
        } else if (now > endTime) {
            endMeter = parseInt(_result, 3); // kWh * 1e3
            _distributeTokens();
        }

        emit VerifiedEnergy(_queryId, _result, _proof);

        // next update
        _update(updateTime);
    }

    // Helper: token distribution
    function _distributeTokens()
        internal
    {
        uint256 deltaLoad = endMeter.sub(startMeter);

        if (deltaLoad < curLoad && deltaLoad > promisedLoad) {
            // withdrawal tokens to customer and schneider
            _transferTokens(customerAddr, contractTokenBalance().mul(curLoad - deltaLoad).div(curLoad - promisedLoad));
            _transferTokens(schneiderAddr, contractTokenBalance());
        } else if (deltaLoad >= curLoad) {
            // withdrawal all tokens to customer
            _transferTokens(customerAddr, contractTokenBalance());
        } else {
            // withdrawal all tokens to schneider
            _transferTokens(schneiderAddr, contractTokenBalance());
        }
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