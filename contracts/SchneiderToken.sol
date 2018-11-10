/**
 * @author https://github.com/Dmitx
 */

pragma solidity ^0.4.24;

import "./token/ERC20/ERC20Mintable.sol";


/**
 * @title SchneiderToken
 * @dev ERC20 Mintable and Capped Token for EVEN project.
 */
contract SchneiderToken is ERC20Mintable {

    string public constant name = "Schneider Token";
    string public constant symbol = "SCH";
    uint8 public constant decimals = 18;

}