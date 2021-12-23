pragma solidity 0.5.6;

import "./Ownable.sol";
import "./StandardToken.sol";
import "./Q2.sol";
import "./MigrationTarget.sol";
import "./KlaySwap.sol";
import "./IPool.sol";

interface TokenRecipient {
    function receiveApproval(
        address _from,
        uint256 _value,
        address _token,
        bytes calldata _extraData
    ) external;
}

contract Quarters is KlaySwap, StandardToken {
    // Public variables of the token
    string public name = "Quarters";
    string public symbol = "Q";
    uint8 public decimals = 0; // no decimals, only integer quarters

    using SafeMath for uint256;

    uint16 public kusdtRate = 571; // Quarters/KUSDT
    uint256 public tranche = 40000; // Number of Quarters in initial tranche

    uint256 public MAX_BASISPOINTS = 10000; //Max Value

    uint256 public withDrawBasisPoints = 1500; // withDraw in Basis Points

    bool swapFromDex = false;

    // List of developers
    // address -> status
    mapping(address => bool) public developers;

    bool public pauseTransfer = false;

    uint256 public outstandingQuarters;

    // for now we are using six 0xef82b1c6a550e730d8283e1edd4977cd01faf435
    // once we create liquidity pool we will place actual q2 address
    address payable public q2;

    uint32 private royaltyBasisPoints = 1500; // royalties in Basis Points

    // token used to buy quarters
    // for mainnet 0xceE8FAF64bB97a73bb51E115Aa89C17FfA8dD167
    ERC20 public kusdt = ERC20(0xceE8FAF64bB97a73bb51E115Aa89C17FfA8dD167);

    // factory address for exchanging token from klayswap
    address public factory = 0xC6a2Ad8cC6e4A7E08FC37cC5954be07d499E7654;

    address public poolAddress = 0x82dF10Cf1B69D7659beA24416247EFc243c99185;

    // number of Quarters for next tranche
    uint8 public trancheNumerator = 2;
    uint8 public trancheDenominator = 1;

    // rewards related storage
    mapping(address => uint256) public rewards; // rewards earned, but not yet collected
    mapping(address => uint256) public trueBuy; // tranche rewards are set based on *actual* purchases of Quarters

    uint256 public rewardAmount = 40;

    uint8 public rewardNumerator = 1;
    uint8 public rewardDenominator = 4;

    // KUSDT rate changed
    event KUSDTRateChanged(uint16 currentRate, uint16 newRate);

    // This notifies clients about the amount burnt
    event Burn(address indexed from, uint256 value);

    event QuartersOrdered(
        address indexed sender,
        uint256 kusdtValue,
        uint256 tokens
    );
    event DeveloperStatusChanged(address indexed developer, bool status);
    event TrancheIncreased(
        uint256 _tranche,
        uint256 _kusdtPool,
        uint256 _outstandingQuarters
    );
    event MegaEarnings(
        address indexed developer,
        uint256 value,
        uint256 _baseRate,
        uint256 _tranche,
        uint256 _outstandingQuarters,
        uint256 _kusdtPool
    );
    event Withdraw(
        address indexed developer,
        uint256 value,
        uint256 _kusdtBaseRate,
        uint256 _tranche,
        uint256 _outstandingQuarters,
        uint256 _kusdtPool
    );
    event BaseRateChanged(
        uint256 _baseRate,
        uint256 _tranche,
        uint256 _outstandingQuarters,
        uint256 _kusdtPool,
        uint256 _totalSupply
    );
    event Reward(
        address indexed _address,
        uint256 value,
        uint256 _outstandingQuarters,
        uint256 _totalSupply
    );

    /**
     * developer modifier
     */
    modifier onlyActiveDeveloper() {
        require(developers[msg.sender] == true);
        _;
    }

    /**
     * Constructor function
     *
     * Initializes contract with initial supply tokens to the owner of the contract
     */
    constructor(address payable _q2, uint256 firstTranche) public {
        q2 = _q2;
        tranche = firstTranche; // number of Quarters to be sold before increasing price
    }

    function changeQ2(address payable _q2) public onlyOwner {
        q2 = _q2;
    }

    function setKusdtRate(uint16 rate) public onlyOwner {
        // Quarters token to be provided for 1 kusdt
        require(rate > 0);
        kusdtRate = rate;
        emit KUSDTRateChanged(kusdtRate, rate);
    }

    function changeSwapFromDex(bool newSwapFromDex) public onlyOwner {
        // Quarters token to be provided for 1 kusdt
        swapFromDex = newSwapFromDex;
    }

    /**
     * Adjust reward amount
     */
    function adjustReward(uint256 reward) public onlyOwner {
        rewardAmount = reward; // may be zero, no need to check value to 0
    }

    /**
     * Change PoolAddress
     */
    function changePoolAddress(address newPoolAddress) public onlyOwner {
        require(address(0) != poolAddress);
        poolAddress = newPoolAddress;
    }

    /**
     * Change KUSDT Address if required so that we dont have to redeploy contract
     */
    function changeKUSDT(address kusdtAddress) public onlyOwner {
        require(address(0) != kusdtAddress);
        kusdt = ERC20(kusdtAddress);
    }

    /**
     * adjust withDrawBasisPoints
     */
    function adjustWithdrawBasisPoints(uint256 _withDrawBasisPoints)
        public
        onlyOwner
    {
        require(_withDrawBasisPoints > 0);
        withDrawBasisPoints = _withDrawBasisPoints;
    }

    /**
     * adjust tranche for next cycle
     */
    function adjustNextTranche(uint8 numerator, uint8 denominator)
        public
        onlyOwner
    {
        require(numerator > 0 && denominator > 0);
        trancheNumerator = numerator;
        trancheDenominator = denominator;
    }

    function adjustTranche(uint256 tranche2) public onlyOwner {
        require(tranche2 > 0);
        tranche = tranche2;
    }

    /**
     * Adjust rewards for `_address`
     */
    function updatePlayerRewards(address _address) internal {
        require(_address != address(0));

        uint256 _reward = 0;
        if (rewards[_address] == 0) {
            _reward = rewardAmount;
        } else if (rewards[_address] < tranche) {
            _reward = (trueBuy[_address] * rewardNumerator) / rewardDenominator;
        }

        if (_reward > 0) {
            // update rewards record
            rewards[_address] = tranche;

            balances[_address] += _reward;
            allowed[_address][msg.sender] += _reward; // set allowance

            totalSupply += _reward;
            outstandingQuarters += _reward;

            // tranche size change
            _changeTrancheIfNeeded();

            emit Approval(_address, msg.sender, _reward);
            emit Reward(_address, _reward, outstandingQuarters, totalSupply);
        }
    }

    /**
     * Developer status
     */
    function setDeveloperStatus(address _address, bool status)
        public
        onlyOwner
    {
        developers[_address] = status;
        emit DeveloperStatusChanged(_address, status);
    }

    /**
     * Set allowance for other address and notify
     *
     * Allows `_spender` to spend no more than `_value` tokens in your behalf, and then ping the contract about it
     *
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     * @param _extraData some extra information to send to the approved contract
     */
    function approveAndCall(
        address _spender,
        uint256 _value,
        bytes memory _extraData
    ) public returns (bool success) {
        TokenRecipient spender = TokenRecipient(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(
                msg.sender,
                _value,
                address(this),
                _extraData
            );
            return true;
        }

        return false;
    }

    /**
     * Destroy tokens
     *
     * Remove `_value` tokens from the system irreversibly
     *
     * @param _value the amount of money to burn
     */
    function burn(uint256 _value) public returns (bool success) {
        require(balances[msg.sender] >= _value); // Check if the sender has enough
        balances[msg.sender] -= _value; // Subtract from the sender
        totalSupply -= _value; // Updates totalSupply
        outstandingQuarters -= _value; // Update outstanding quarters
        emit Burn(msg.sender, _value);

        return true;
    }

    /**
     * Destroy tokens from other account
     *
     * Remove `_value` tokens from the system irreversibly on behalf of `_from`.
     *
     * @param _from the address of the sender
     * @param _value the amount of money to burn
     */
    function burnFrom(address _from, uint256 _value)
        public
        returns (bool success)
    {
        require(balances[_from] >= _value); // Check if the targeted balance is enough
        require(_value <= allowed[_from][msg.sender]); // Check allowance
        balances[_from] -= _value; // Subtract from the targeted balance
        allowed[_from][msg.sender] -= _value; // Subtract from the sender's allowance
        totalSupply -= _value; // Update totalSupply
        outstandingQuarters -= _value; // Update outstanding quarters
        emit Burn(_from, _value);

        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public returns (bool success) {
        require(!pauseTransfer);
        return super.transferFrom(_from, _to, _value);
    }

    function transfer(address _to, uint256 _value)
        public
        returns (bool success)
    {
        require(!pauseTransfer);
        return super.transfer(_to, _value);
    }

    /**
     * Buy quarters by sending kusdt based upon kusdtRate to contract address default : 571
     * @param kusdtAmount total kusdt amount
     */

    function buy(uint256 kusdtAmount) public {
        require(kusdt.balanceOf(msg.sender) >= kusdtAmount);
        _buy(msg.sender, kusdtAmount);
    }

    /**
     * Buy quarters for specific address and take approval to spend by spender by sending kusdt based upon kusdtRate to contract address default : 571
     * @param buyer address to send quarters
     * @param kusdtAmount total kusdt amount to spend
     */

    function buyFor(address buyer, uint256 kusdtAmount) public payable {
        require(kusdt.balanceOf(msg.sender) >= kusdtAmount);
        uint256 _value = _buy(buyer, kusdtAmount);

        // allow donor (msg.sender) to spend buyer's tokens
        allowed[buyer][msg.sender] += _value;
        emit Approval(buyer, msg.sender, _value);
    }

    function _changeTrancheIfNeeded() internal {
        if (totalSupply >= tranche) {
            // change tranche size for next cycle
            tranche = (tranche * trancheNumerator) / trancheDenominator;

            // fire event for tranche change
            emit TrancheIncreased(
                tranche,
                address(this).balance,
                outstandingQuarters
            );
        }
    }

    // change royalties Basis Point only owner
    function changeRoyaltiesBasisPoints(uint32 _royaltyBasisPoints)
        public
        onlyOwner
    {
        royaltyBasisPoints = _royaltyBasisPoints;
    }

    // returns number of quarters buyer got
    function _buy(address buyer, uint256 kusdtAmount)
        internal
        returns (uint256)
    {
        require(buyer != address(0));

        kusdt.transferFrom(msg.sender, address(this), kusdtAmount);
        uint256 nq = kusdtAmount.mul(kusdtRate).div(10**6);
        require(nq != 0);
        if (nq > tranche) {
            nq = tranche;
        }

        balances[buyer] += nq;
        trueBuy[buyer] += nq;
        outstandingQuarters += nq;
        totalSupply += nq;

        // change tranche size
        _changeTrancheIfNeeded();

        // event for quarters order (invoice)
        emit QuartersOrdered(buyer, kusdtAmount, nq);

        uint256 Q2BurnAmount = kusdtAmount.mul(royaltyBasisPoints).div(
            MAX_BASISPOINTS
        );

        address[] memory path = new address[](1);
        path[0] = address(0);

        /**
         *
         * Exchanging from q2 from dex
         */

        if (swapFromDex) {
            exchangeKctPos(address(kusdt), Q2BurnAmount, q2, path);
        } else {
            /**
             * Approving PoolAddress to Spend Token
             */
            kusdt.approve(poolAddress, Q2BurnAmount);

            /**
             * Exchanging q2 with kusdt
             */
            IPool(poolAddress).exchangeQ2withKusdt(Q2BurnAmount);
        }

        Q2(q2)._burn(address(this), Q2(q2).balanceOf(address(this)));

        // return nq
        return nq;
    }

    /**
     * Transfer allowance from other address's allowance
     *
     * Send `_value` tokens to `_to` in behalf of `_from`
     *
     * @param _from The address of the sender
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transferAllowance(
        address _from,
        address _to,
        uint256 _value
    ) public returns (bool success) {
        updatePlayerRewards(_from);
        require(_value <= allowed[_from][msg.sender]); // Check allowance
        allowed[_from][msg.sender] -= _value;

        if (_transfer(_from, _to, _value)) {
            // allow msg.sender to spend _to's tokens
            allowed[_to][msg.sender] += _value;
            emit Approval(_to, msg.sender, _value);
            return true;
        }

        return false;
    }

    function withdraw(uint256 value) public onlyActiveDeveloper {
        require(balances[msg.sender] >= value);

        uint256 earnings = kusdt.balanceOf(address(this)).mul(value).div(
            totalSupply
        );

        balances[msg.sender] -= value;
        outstandingQuarters -= value; // update the outstanding Quarters

        uint256 kusdtPool = kusdt.balanceOf(address(this)) - earnings;

        // event for withdraw
        emit Withdraw(
            msg.sender,
            earnings,
            kusdtRate,
            tranche,
            outstandingQuarters,
            kusdtPool
        ); // with current base rate

        // earning for developers
        kusdt.transfer(msg.sender, earnings);
    }

    //
    // Migrations
    //

    // Target contract
    address public migrationTarget;
    bool public migrating = false;

    // Migrate event
    event Migrate(address indexed _from, uint256 _value);

    //
    // Migrate tokens to the new token contract.
    //
    function migrate() public {
        require(migrationTarget != address(0));
        uint256 _amount = balances[msg.sender];
        require(_amount > 0);
        balances[msg.sender] = 0;

        totalSupply = totalSupply - _amount;
        outstandingQuarters = outstandingQuarters - _amount;

        rewards[msg.sender] = 0;
        trueBuy[msg.sender] = 0;
        developers[msg.sender] = false;

        emit Migrate(msg.sender, _amount);
        MigrationTarget(migrationTarget).migrateFrom(
            msg.sender,
            _amount,
            rewards[msg.sender],
            trueBuy[msg.sender],
            developers[msg.sender]
        );
    }

    function emergencyExit() public onlyOwner {
        kusdt.transfer(msg.sender, kusdt.balanceOf(address(this)));
    }

    function changeTransferState() public onlyOwner {
        pauseTransfer = !pauseTransfer;
    }

    //
    // Set address of migration target contract
    // @param _target The address of the MigrationTarget contract
    //
    function setMigrationTarget(address _target) public onlyOwner {
        migrationTarget = _target;
    }
}
