pragma solidity 0.5.6;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./StandardToken.sol";
import "./ITransferController.sol";

contract Q2 is Ownable, StandardToken {
    using SafeMath for uint256;

    string public name = "Q2";
    string public symbol = "Q2";
    uint8 public decimals = 18;

    // token used to buy quarters
    ERC20 public kusdt = ERC20(0xceE8FAF64bB97a73bb51E115Aa89C17FfA8dD167);

    ITransferController public transferController =
        ITransferController(0x99f2b1D5350D9Db28F8a7f4aeB08aB76bC7F9942);

    bool public whitelist = true;

    bool public everyoneAccept = false;

    // whitelist addresses
    mapping(address => bool) public whitelistedAddresses;

    // token creation cap
    uint256 public creationCap = 15000000000 * (10**18); // 15B
    uint256 public reservedFund = 10000000000 * (10**18); // 10B

    // stage info
    struct Stage {
        uint8 number;
        uint256 exchangeRate;
        uint256 startBlock;
        uint256 endBlock;
        uint256 cap;
    }

    // events
    event MintTokens(address indexed _to, uint256 _value);
    event StageStarted(uint8 _stage, uint256 _totalSupply, uint256 _balance);
    event StageEnded(uint8 _stage, uint256 _totalSupply, uint256 _balance);
    event WhitelistStatusChanged(address indexed _address, bool status);
    event WhitelistChanged(bool status);

    // kusdt wallet
    address payable public kusdtWallet;
    mapping(uint8 => Stage) stages;

    // current state info
    uint8 public currentStage;

    constructor(address payable _kusdtWallet) public {
        kusdtWallet = _kusdtWallet;

        // reserved tokens
        mintTokens(kusdtWallet, reservedFund);
    }

    function changeEveryoneAccept(bool everyoneTransfer) public onlyOwner {
        everyoneAccept = everyoneTransfer;
    }

    function mintTokens(address to, uint256 value) internal {
        require(value > 0);
        balances[to] = balances[to].add(value);
        totalSupply = totalSupply.add(value);
        require(totalSupply <= creationCap);

        // broadcast event
        emit MintTokens(to, value);
    }

    function changeControllerAddress(address _contollerAddress)
        public
        onlyOwner
    {
        transferController = ITransferController(_contollerAddress);
    }

    function() external payable {
        buyTokens();
    }

    /**
     * Change KUSDT Address if required so that we dont have to redeploy contract
     */
    function changeKUSDT(address kusdtAddress) public onlyOwner {
        require(address(0) != kusdtAddress);
        kusdt = ERC20(kusdtAddress);
    }

    function buyTokens() public payable {
        require(whitelist == false || whitelistedAddresses[msg.sender] == true);
        require(msg.value > 0);

        Stage memory stage = stages[currentStage];
        require(
            block.number >= stage.startBlock && block.number <= stage.endBlock
        );

        uint256 tokens = msg.value * stage.exchangeRate;
        require(totalSupply.add(tokens) <= stage.cap);

        mintTokens(msg.sender, tokens);
    }

    function buyTokensWithKUSDT(uint256 kusdtAmount) public {
        require(kusdtAmount > 0);
        require(kusdt.balanceOf(msg.sender) >= kusdtAmount);
        require(whitelist == false || whitelistedAddresses[msg.sender] == true);

        Stage memory stage = stages[currentStage];
        require(
            block.number >= stage.startBlock && block.number <= stage.endBlock
        );

        uint256 tokens = kusdtAmount * stage.exchangeRate;
        require(totalSupply.add(tokens) <= stage.cap);

        kusdt.transferFrom(msg.sender, address(this), kusdtAmount);
        mintTokens(msg.sender, tokens);
    }

    function startStage(
        uint256 _exchangeRate,
        uint256 _cap,
        uint256 _startBlock,
        uint256 _endBlock
    ) public onlyOwner {
        require(_exchangeRate > 0 && _cap > 0);
        require(_startBlock > block.number);
        require(_startBlock < _endBlock);

        // stop current stage if it's running
        Stage memory currentObj = stages[currentStage];
        if (currentObj.endBlock > 0) {
            // broadcast stage end event
            emit StageEnded(currentStage, totalSupply, address(this).balance);
        }

        // increment current stage
        currentStage = currentStage + 1;

        // create new stage object
        Stage memory s = Stage({
            number: currentStage,
            startBlock: _startBlock,
            endBlock: _endBlock,
            exchangeRate: _exchangeRate,
            cap: _cap + totalSupply
        });
        stages[currentStage] = s;

        // broadcast stage started event
        emit StageStarted(currentStage, totalSupply, address(this).balance);
    }

    function withdraw() public onlyOwner {
        kusdtWallet.transfer(address(this).balance);
        kusdt.transfer(kusdtWallet, kusdt.balanceOf(address(this)));
    }

    /**
     * Transfer tokens
     *
     * Send `_value` tokens to `_to` from your account
     *
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transfer(address _to, uint256 _value)
        public
        returns (bool success)
    {
        require(
            transferController.isWhiteListed(_to) ||
                isContract(_to) ||
                everyoneAccept
        );

        return super.transfer(_to, _value);
    }

    /**
     * Transfer tokens from other address
     *
     * Send `_value` tokens to `_to` in behalf of `_from`
     *
     * @param _from The address of the sender
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public returns (bool success) {
        require(
            transferController.isWhiteListed(_to) ||
                isContract(_to) ||
                everyoneAccept
        );
        require(_value <= allowed[_from][msg.sender]); // Check allowance
        allowed[_from][msg.sender] -= _value;
        return _transfer(_from, _to, _value);
    }

    function getCurrentStage()
        public
        view
        returns (
            uint8 number,
            uint256 exchangeRate,
            uint256 startBlock,
            uint256 endBlock,
            uint256 cap
        )
    {
        Stage memory currentObj = stages[currentStage];
        number = currentObj.number;
        exchangeRate = currentObj.exchangeRate;
        startBlock = currentObj.startBlock;
        endBlock = currentObj.endBlock;
        cap = currentObj.cap;
    }

    function isContract(address addr) public view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    function changeWhitelistStatus(address _address, bool status)
        public
        onlyOwner
    {
        whitelistedAddresses[_address] = status;
        emit WhitelistStatusChanged(_address, status);
    }

    function changeWhitelist(bool status) public onlyOwner {
        whitelist = status;
        emit WhitelistChanged(status);
    }
}
