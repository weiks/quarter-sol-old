import assertThrows from "./helpers/assertThrows";

let Quarters = artifacts.require("./Quarters.sol");

const BigNumber = web3.BigNumber;

contract("Quarters", function(accounts) {
  const initialSupply = 100; // initialSupply = 100 quarters
  const initialPrice = 1000; // initial price of quarter (300k quarters for 1 ETH at USD 300)
  const firstTranche = 900000; // first tranche value -> 900k quarters

  describe("initialization", async function() {
    let contract; // contract with account 0
    let contract1; // contract with account 1

    // runs before test cases
    before(async function() {
      contract = await Quarters.new(
        initialSupply,
        "Quarters",
        "Q1",
        initialPrice,
        firstTranche,
        { from: accounts[0] } // `from` key is important to change transaction creator
      );
      contract1 = await Quarters.new(
        initialSupply,
        "Quarters",
        "Q2",
        initialPrice,
        firstTranche,
        { from: accounts[1] }
      );
    });

    it("should create quarter contract with proper ownership", async function() {
      let contractOwner = await contract.owner();
      assert.equal(contractOwner, accounts[0]);

      // check for second contract
      contractOwner = await contract1.owner();
      assert.equal(contractOwner, accounts[1]);
    });

    it("should create quarter contract with proper values", async function() {
      let [totalSupply, name, symbol, price, tranche] = await Promise.all([
        contract.totalSupply(),
        contract.name(),
        contract.symbol(),
        contract.price(),
        contract.tranche()
      ]);
      assert.equal(totalSupply.eq(initialSupply), true);
      assert.equal(name, "Quarters");
      assert.equal(symbol, "Q1");
      assert.equal(price.eq(initialPrice), true);
      assert.equal(tranche.eq(firstTranche), true);

      // check for second contract
      [totalSupply, name, symbol, price, tranche] = await Promise.all([
        contract1.totalSupply(),
        contract1.name(),
        contract1.symbol(),
        contract1.price(),
        contract1.tranche()
      ]);
      assert.equal(totalSupply.eq(initialSupply), true);
      assert.equal(name, "Quarters");
      assert.equal(symbol, "Q2");
      assert.equal(price.eq(initialPrice), true);
      assert.equal(tranche.eq(firstTranche), true);
    });
  });

  describe("eth price", async function() {
    let contract; // contract with account 0

    // runs before test cases
    before(async function() {
      contract = await Quarters.new(
        initialSupply,
        "Quarters",
        "Q",
        initialPrice,
        firstTranche,
        { from: accounts[0] } // `from` key is important to change transaction creator
      );
    });

    it("should not allow others to change eth price", async function() {
      assertThrows(contract.setEthRate(350, { from: accounts[1] }));
      assertThrows(contract.setEthRate(400, { from: accounts[2] }));
    });

    it("should allow only owner to change eth price", async function() {
      let currentRate = await contract.ethRate();

      let receipt = await contract.setEthRate(350, { from: accounts[0] });
      assert.equal(receipt.logs.length, 1);
      let log = receipt.logs[0];
      assert.equal(log.event, "EthRateChanged");
      assert.equal(log.args.currentRate.toNumber(), currentRate.toNumber());
      assert.equal(log.args.newRate.toNumber(), 350);

      currentRate = await contract.ethRate();
      assert.equal(currentRate, 350); // check if rate changed successfully

      // try changing rate to 400
      receipt = await contract.setEthRate(400, { from: accounts[0] });
      assert.equal(receipt.logs.length, 1);
      log = receipt.logs[0];
      assert.equal(log.event, "EthRateChanged");
      assert.equal(log.args.currentRate.toNumber(), currentRate.toNumber());
      assert.equal(log.args.newRate.toNumber(), 400);

      currentRate = await contract.ethRate();
      assert.equal(currentRate, 400); // check if rate changed successfully
    });

    it("should allow not allow anyone to set eth price to 0", async function() {
      assertThrows(contract.setEthRate(0, { from: accounts[0] })); // try with owner
      assertThrows(contract.setEthRate(0, { from: accounts[1] }));
    });
  });

  describe("transfer ownership", async function() {
    let contract; // contract with account 0

    // runs before test cases
    before(async function() {
      contract = await Quarters.new(
        initialSupply,
        "Quarters",
        "Q",
        initialPrice,
        firstTranche,
        { from: accounts[0] } // `from` key is important to change transaction creator
      );
    });

    it("should allow to transfer ownership", async function() {
      let owner = await contract.owner();
      assert.equal(owner, accounts[0]);

      // check if eth price can not be set by accounts[1]
      assertThrows(contract.setEthRate(350, { from: accounts[1] }));

      // change transfer ownership
      let receipt = await contract.transferOwnership(accounts[1]);
      assert.equal(receipt.logs.length, 1);
      assert.equal(receipt.logs[0].event, "OwnershipChanged");
      assert.equal(receipt.logs[0].args.newOwner, accounts[1]);
      assert.equal(receipt.logs[0].args.oldOwner, accounts[0]);

      owner = await contract.owner();
      assert.equal(owner, accounts[1]);

      // check if eth price can not be set by accounts[0]
      assertThrows(contract.setEthRate(350, { from: accounts[0] }));

      // check rate if it's not changed
      let newRate = await contract.ethRate();
      assert.equal(newRate.eq(300), true);

      // check if eth price can be set by accounts[1]
      receipt = await contract.setEthRate(350, { from: accounts[1] });
      assert.equal(receipt.logs.length, 1);
      assert.equal(receipt.logs[0].event, "EthRateChanged");
    });

    it("should not allow to transfer ownership from any account except owner", async function() {
      let owner = await contract.owner();
      assert.equal(owner, accounts[1]);

      // try to change transfer ownership
      assertThrows(
        contract.transferOwnership(accounts[2], { from: accounts[3] })
      );

      owner = await contract.owner();
      assert.equal(owner, accounts[1]);

      // try to change transfer ownership
      assertThrows(
        contract.transferOwnership(accounts[2], { from: accounts[2] })
      );

      owner = await contract.owner();
      assert.equal(owner, accounts[1]);
    });
  });

  describe("developers", async function() {
    let contract; // contract with account 0

    // runs before test cases
    before(async function() {
      contract = await Quarters.new(
        initialSupply,
        "Quarters",
        "Q",
        initialPrice,
        firstTranche,
        { from: accounts[0] } // `from` key is important to change transaction creator
      );
    });

    it("should not allow others to change eth price", async function() {
      assertThrows(
        contract.setDeveloperStatus(accounts[6], true, { from: accounts[1] })
      );
      assertThrows(
        contract.setDeveloperStatus(accounts[7], true, { from: accounts[2] })
      );
    });

    it("should allow only owner to change developer status", async function() {
      // let's take accounts 6,7 & 8 as developers
      let isDeveloper = await contract.developers(accounts[6]);
      assert.equal(isDeveloper, false);

      isDeveloper = await contract.developers(accounts[7]);
      assert.equal(isDeveloper, false);

      // add accounts[6] as developer
      let receipt = await contract.setDeveloperStatus(accounts[6], true, {
        from: accounts[0]
      });
      assert.equal(receipt.logs.length, 1);
      let log = receipt.logs[0];
      assert.equal(log.event, "DeveloperStatusChanged");
      assert.equal(log.args.developer, accounts[6]);
      assert.equal(log.args.status, true);
      isDeveloper = await contract.developers(accounts[6]);
      assert.equal(isDeveloper, true);

      // add accounts[7] as developer
      receipt = await contract.setDeveloperStatus(accounts[7], true, {
        from: accounts[0]
      });
      assert.equal(receipt.logs.length, 1);
      log = receipt.logs[0];
      assert.equal(log.event, "DeveloperStatusChanged");
      assert.equal(log.args.developer, accounts[7]);
      assert.equal(log.args.status, true);
      isDeveloper = await contract.developers(accounts[7]);
      assert.equal(isDeveloper, true);
    });
  });

  //
  // Buy tokens
  //
  describe("buy", async function() {
    let contract; // contract with account 0
    let ethRate = 300;

    // runs before test cases
    before(async function() {
      contract = await Quarters.new(
        initialSupply,
        "Quarters",
        "Q",
        initialPrice,
        firstTranche,
        { from: accounts[0] } // `from` key is important to change transaction creator
      );

      // set eth price to 300 dollars
      await contract.setEthRate(ethRate, { from: accounts[0] });
    });

    // case 1
    describe("no of quarters < tranche size", async function() {
      it("should get equivalent tokens for ethers and owner", async function() {
        // fetch current owner's balance
        let currentOwnerBalance = await web3.eth.getBalance(accounts[0]);
        let etherValue = web3.toWei(1); // 1 ether -> should get 300k tokens
        let expectedQuarters = web3.fromWei(
          new BigNumber(etherValue).mul(ethRate).mul(initialPrice)
        );
        let expectedOwnerEarnings = new BigNumber(etherValue).div(10);

        let receipt = await contract.sendTransaction({
          from: accounts[2],
          value: etherValue
        }); // directly without any method call

        assert.equal(receipt.logs.length, 1);
        let log = receipt.logs[0];
        assert.equal(log.event, "QuartersOrdered");
        assert.equal(log.args.sender, accounts[2]);
        assert.equal(log.args.ethValue.eq(etherValue), true);
        assert.equal(log.args.tokens.eq(expectedQuarters), true);

        // check quarter balance of sender
        let senderBalance = await contract.balanceOf(accounts[2]);
        assert.equal(expectedQuarters.eq(senderBalance), true);

        // check balance of sender
        let ownerETHBalance = await web3.eth.getBalance(accounts[0]);
        assert.equal(
          ownerETHBalance.minus(currentOwnerBalance).eq(expectedOwnerEarnings),
          true
        );
      });

      it("should set proper totalSupply, price, tranche", async function() {
        let senderBalance = await contract.balanceOf(accounts[2]);
        let newTotalSupply = new BigNumber(initialSupply).plus(senderBalance);

        let [totalSupply, price, tranche] = await Promise.all([
          contract.totalSupply(),
          contract.price(),
          contract.tranche()
        ]);
        assert.equal(totalSupply.eq(newTotalSupply), true);
        assert.equal(price.eq(initialPrice), true);
        assert.equal(tranche.eq(firstTranche), true);
      });
    });

    // case 2
    describe("no of quarters >= tranche size", async function() {
      it("1. same as tranche: should get tokens size of tranche for ethers and owner gets cut", async function() {
        // fetch current owner's balance
        let currentOwnerBalance = await web3.eth.getBalance(accounts[0]);
        let [
          currentTotalSupply,
          currentPrice,
          currentTranche
        ] = await Promise.all([
          contract.totalSupply(),
          contract.price(),
          contract.tranche()
        ]);

        let etherValue = web3.toWei(3); // 3 ether -> should get 900k tokens
        let expectedQuarters = web3.fromWei(
          new BigNumber(etherValue).mul(ethRate).mul(initialPrice)
        );
        let expectedOwnerEarnings = new BigNumber(etherValue).div(10);

        let receipt = await contract.buy({
          from: accounts[3],
          value: etherValue
        }); // buy method

        assert.equal(receipt.logs.length, 2);
        let log = receipt.logs[0];
        assert.equal(log.event, "TrancheIncreased");

        let expectedTrache = new BigNumber(currentTranche).mul(2);
        assert.equal(log.args._tranche.eq(expectedTrache), true);
        assert.equal(log.args._price.toNumber(), 666, true);

        log = receipt.logs[1];
        assert.equal(log.event, "QuartersOrdered");
        assert.equal(log.args.sender, accounts[3]);
        assert.equal(log.args.ethValue.eq(etherValue), true);
        assert.equal(log.args.tokens.eq(expectedQuarters), true);

        // check quarter balance of sender
        let senderBalance = await contract.balanceOf(accounts[3]);
        assert.equal(expectedQuarters.eq(senderBalance), true);

        // check balance of sender
        let ownerETHBalance = await web3.eth.getBalance(accounts[0]);
        assert.equal(
          ownerETHBalance.minus(currentOwnerBalance).eq(expectedOwnerEarnings),
          true
        );

        // check totalSupply, price and tranche
        let [totalSupply, price, tranche] = await Promise.all([
          contract.totalSupply(),
          contract.price(),
          contract.tranche()
        ]);
        assert.equal(
          totalSupply.eq(currentTotalSupply.add(expectedQuarters)),
          true
        ); // new totalSupply = totalSupply + nq (expectedQuarters)
        assert.equal(price.toNumber(), 666, true); // new price = price * 2 / 3
        assert.equal(tranche.eq(currentTranche.mul(2)), true); // new tranche = tranche * 2 / 1
      });

      it("2. more than tranche: should get tokens size of tranche for ethers and owner gets cut", async function() {
        // fetch current owner's balance
        let currentOwnerBalance = await web3.eth.getBalance(accounts[0]);
        let [
          currentTotalSupply,
          currentPrice,
          currentTranche
        ] = await Promise.all([
          contract.totalSupply(),
          contract.price(),
          contract.tranche()
        ]);

        let etherValue = web3.toWei(10); // 10 ether -> should get 1,998,000 quarters but will get 1,800,000 quarters
        let expectedQuarters = currentTranche;
        let expectedOwnerEarnings = new BigNumber(etherValue).div(10);

        let receipt = await contract.buy({
          from: accounts[4],
          value: etherValue
        }); // buy method

        assert.equal(receipt.logs.length, 2);
        let log = receipt.logs[0];
        assert.equal(log.event, "TrancheIncreased");

        let expectedTrache = new BigNumber(currentTranche).mul(2);
        assert.equal(log.args._tranche.eq(expectedTrache), true);
        assert.equal(log.args._price.toNumber(), 444, true);

        log = receipt.logs[1];
        assert.equal(log.event, "QuartersOrdered");
        assert.equal(log.args.sender, accounts[4]);
        assert.equal(log.args.ethValue.eq(etherValue), true);
        assert.equal(log.args.tokens.eq(expectedQuarters), true);

        // check quarter balance of sender
        let senderBalance = await contract.balanceOf(accounts[4]);
        assert.equal(expectedQuarters.eq(senderBalance), true);

        // check balance of sender
        let ownerETHBalance = await web3.eth.getBalance(accounts[0]);
        assert.equal(
          ownerETHBalance.minus(currentOwnerBalance).eq(expectedOwnerEarnings),
          true
        );

        // check totalSupply, price and tranche
        let [totalSupply, price, tranche] = await Promise.all([
          contract.totalSupply(),
          contract.price(),
          contract.tranche()
        ]);
        assert.equal(
          totalSupply.eq(currentTotalSupply.add(expectedQuarters)),
          true
        ); // new totalSupply = totalSupply + nq (expectedQuarters)
        assert.equal(price.toNumber(), 444, true); // new price = price * 2 / 3
        assert.equal(tranche.eq(currentTranche.mul(2)), true); // new tranche = tranche * 2 / 1
        assert.equal(tranche.eq(3600000), true); // around 3600k

        console.log(
          web3.fromWei(await web3.eth.getBalance(contract.address)).toString()
        );
        console.log(web3.fromWei(await contract.getBaseRate()).toString());
        console.log((await contract.outstandingQuarters()).toString());
      });
    });
  });

  //
  // Withdraw
  //
  describe("withdraw", async function() {
    let contract; // contract with account 0
    let ethRate = 300;

    // runs before test cases
    before(async function() {
      contract = await Quarters.new(
        initialSupply,
        "Quarters",
        "Q",
        initialPrice,
        firstTranche,
        { from: accounts[0] } // `from` key is important to change transaction creator
      );

      // set eth price to 300 dollars
      await contract.setEthRate(ethRate, { from: accounts[0] });

      // buy quarters
      await contract.buy({ from: accounts[2], value: web3.toWei(1) }); // 1 ether
      await contract.buy({ from: accounts[3], value: web3.toWei(3) }); // 3 ethers
      await contract.buy({ from: accounts[4], value: web3.toWei(10) }); // 10 ethers
    });

    it("should not allow non-developer to withdraw", async function() {
      assertThrows(contract.withdraw(web3.toWei(100), { from: accounts[6] })); // 100 tokens
      assertThrows(contract.withdraw(web3.toWei(500), { from: accounts[7] })); // 500 tokens
    });

    it("should not allow developer to withdraw with no balance", async function() {
      // make accounts[6] developer
      await contract.setDeveloperStatus(accounts[6], true, {
        from: accounts[0]
      });

      assertThrows(contract.withdraw(web3.toWei(100), { from: accounts[6] })); // 100 tokens
    });

    it("should have proper buying rate for types of devleopers", async function() {});

    // developers
    describe("developers", async function() {
      before(async function() {});
    });
  });
});
