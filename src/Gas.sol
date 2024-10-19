// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0; 

import "./Ownable.sol";

contract Constants {
    uint8 public tradeFlag = 1;
    uint8 public basicFlag = 0;
    uint8 public dividendFlag = 1;
    uint8 public tradePercent = 12;
    }

struct InternalState {
    uint32 paymentCounter;
    uint32 tradeMode;
    uint32 isReady;
}
enum PaymentType {
    Unknown,
    BasicPayment,
    Refund,
    Dividend,
    GroupPayment
}

contract GasContract is Ownable, Constants {
    address[5] public administrators;
    InternalState internalState;
    address contractOwner;
    uint256 totalSupply = 0; // cannot be updated
    mapping(address => uint256) public balances;
    mapping(address => mapping(uint256 => Payment))  public payments;
    mapping(address => uint256) public whitelist;
    PaymentType constant defaultPayment = PaymentType.Unknown;
    History[] public paymentHistory; // when a payment was updated
    struct Payment {
        PaymentType paymentType;
        bool adminUpdated;
        uint256 paymentID;
        address recipient;
        address admin; // administrators address
        uint256 amount;
    }
    struct History {
        uint256 lastUpdate;
        address updatedBy;
        uint256 blockNumber;
    }
    mapping(address => uint32) public isOddWhitelistUser;
    
    mapping(address => uint256) whiteListStruct;

    event AddedToWhitelist(address userAddress, uint256 tier);

    modifier onlyAdminOrOwner() {
        address senderOfTx = msg.sender;
        if (checkForAdmin(senderOfTx)) {
            _;
        } else if (senderOfTx == contractOwner) {
            _;
        } else {
            revert();
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
            if (_address != msg.sender)
                continue;

            balances[_address] = _totalSupply;
        }
    }

    function getPaymentHistory()
        public
        payable
        returns (History[] memory paymentHistory_)
    {
        return paymentHistory;
    }

    function checkForAdmin(address _user) public view returns (bool admin_) {
        bool admin = false;
        for (uint256 ii = 0; ii < administrators.length; ii++) {
            if (administrators[ii] == _user) {
                admin = true;
            }
        }
        return admin;
    }

    function balanceOf(address _user) public view returns (uint256 balance_) {
        return balances[_user];
    }

    function getTradingMode() public view returns (bool mode_) {
        return (tradeFlag == 1 || dividendFlag == 1);
    }


    function addHistory(address _updateAddress, bool _tradeMode)
        public
        returns (bool status_, bool tradeMode_)
    {
        History memory history;
        history.blockNumber = block.number;
        history.lastUpdate = block.timestamp;
        history.updatedBy = _updateAddress;
        paymentHistory.push(history);
        bool[] memory status = new bool[](Constants.tradePercent);
        for (uint256 i = 0; i < Constants.tradePercent; i++) {
            status[i] = true;
        }
        return ((status[0] == true), _tradeMode);
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
        Payment memory payment;
        payment.paymentID = ++internalState.paymentCounter;
        payment.admin = address(0);
        payment.adminUpdated = false;
        payment.paymentType = PaymentType.BasicPayment;
        payment.recipient = _recipient;
        payment.amount = _amount;
        payments[msg.sender][payment.paymentID] = payment;
    }

    function updatePayment(
        address _user,
        uint256 _ID,
        uint256 _amount,
        PaymentType _type
    ) public onlyAdminOrOwner {
        require(
            _ID > 0
        );
        require(
            _amount > 0
        );
        require(
            _user != address(0)
        );

        address senderOfTx = msg.sender;

        payments[_user][_ID].amount = _amount;
        payments[_user][_ID].paymentType = _type;
        payments[_user][_ID].adminUpdated = true;
        payments[_user][_ID].admin = senderOfTx;
        bool tradingMode = getTradingMode();
        addHistory(_user, tradingMode);
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
            _amount > 3
        );
        require(
            balances[msg.sender] >= _amount
        );
        uint256 fee  = whitelist[senderOfTx];
        balances[senderOfTx] = balances[senderOfTx] + fee - _amount;
        balances[_recipient] = balances[_recipient] + _amount - fee;
        whiteListStruct[senderOfTx] = _amount;        
        emit WhiteListTransfer(_recipient);
    }

    function getPaymentStatus(address sender) public view returns (bool, uint256) {
        return (true, whiteListStruct[sender]);
    }

    receive() external payable {
        payable(msg.sender).transfer(msg.value);
    }


    fallback() external payable {
         payable(msg.sender).transfer(msg.value);
    }
}