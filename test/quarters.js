import assertThrows from "./helpers/assertThrows";

let Quarters = artifacts.require("./Quarters.sol");

contract("Quarters", function(accounts) {
  const initialSupply = web3.toWei("100"); // initialSupply = 100 quarters
  const initialPrice = web3.toWei("0.0003"); // initial price of quarter = 0.0001 ETH (10k quarters for $300)
  const firstTranche = web3.toWei(20000); // first tranche value -> 20000 quarters

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
});
