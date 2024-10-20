// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25; 



enum PaymentType {
    Unknown,
    BasicPayment,
    Refund,
    Dividend,
    GroupPayment
}


contract GasContract {
    address public contractOwner;
    uint256 totalSupply = 0; // cannot be updated
    mapping(address => uint256) public balances;
    mapping(address => uint256) public whitelist;
    mapping(address => uint256) last_amount;
    mapping(address => bool) public is_administrator;
    address[5] public administrators;

    event AddedToWhitelist(address userAddress, uint256 tier);

    modifier onlyAdminOrOwner() {
        address senderOfTx = msg.sender;
        if (!is_administrator[senderOfTx]) {
            revert();
        } else {
            _;
        } 
    }

    modifier checkIfWhiteListed(address sender) {
        address senderOfTx = msg.sender;
        require(
            senderOfTx == sender
        );
        _;
    }

    event supplyChanged(address indexed, uint256 indexed);
    event Transfer(address recipient, uint256 amount);
    event PaymentUpdated(
        address admin,
        uint256 ID,
        uint256 amount,
        address recipient
    );
    event WhiteListTransfer(address indexed);

    constructor(address[] memory _admins, uint256 _totalSupply) {
        contractOwner = msg.sender;
        totalSupply = _totalSupply;
        for (uint8 ii = 0; ii < 5; ii++) {
            address _address = _admins[ii];
            if (_address == address(0))
                continue;
            administrators[ii] = _address;
            is_administrator[_address] = true;
            if (_address != msg.sender)
                continue;
            balances[_address] = _totalSupply;
        }
    }


    function checkForAdmin(address _user) public view returns (bool admin_) {
        return is_administrator[_user];
    }

    function balanceOf(address _user) public view returns (uint256 balance_) {
        return balances[_user];
    }


    function transfer(
        address _recipient,
        uint256 _amount,
        string calldata _name
    ) public  {
        require(
            balances[msg.sender] >= _amount
        );

        balances[msg.sender] -= _amount;
        balances[_recipient] += _amount;
        emit Transfer(_recipient, _amount);
    }


    function addToWhitelist(address _userAddrs, uint256 _tier)
        public
        onlyAdminOrOwner
    {
        require(
            _tier < 255
        );
        emit AddedToWhitelist(_userAddrs, _tier);
        whitelist[_userAddrs] = _tier > 3 ? 3 : _tier;

    }

    function whiteTransfer(
        address _recipient,
        uint256 _amount
    ) public checkIfWhiteListed(msg.sender) {
        address senderOfTx = msg.sender;
        require(
            _amount > 3 && balances[msg.sender] >= _amount
        );
        uint256 fee  = whitelist[senderOfTx];
        balances[senderOfTx] = balances[senderOfTx] + fee - _amount;
        balances[_recipient] = balances[_recipient] + _amount - fee;
        last_amount[senderOfTx] = _amount;        
        emit WhiteListTransfer(_recipient);
    }

    function getPaymentStatus(address sender) public view returns (bool, uint256) {
        return (true, last_amount[sender]);
    }

    receive() external payable {
        payable(msg.sender).transfer(msg.value);
    }


    fallback() external payable {
         payable(msg.sender).transfer(msg.value);
    }
}