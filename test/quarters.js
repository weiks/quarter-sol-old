import assertThrows from "./helpers/assertThrows";
import assertRevert from "./helpers/assertRevert";

let Quarters = artifacts.require("./Quarters.sol");
let Q2 = artifacts.require("./Q2.sol")

const BigNumber = web3.BigNumber;

const ethRate = 4000;
const firstTranche = 40000;

contract("Quarters", function(accounts) {
  describe("initialization", async function() {
    let contract; // contract with account 0
    let contract1; // contract with account 1

    // runs before test cases
    before(async function() {
      const q2 = await Q2.new(accounts[0])

      contract = await Quarters.new(
        q2.address,
        firstTranche,
        { from: accounts[0] } // `from` key is important to change transaction creator
      );
      contract1 = await Quarters.new(
        q2.address,
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
      let [tranche] = await Promise.all([
        contract.tranche()
      ]);
      assert.equal(tranche.eq(firstTranche), true);

      // check for second contract
      [tranche] = await Promise.all([
        contract1.tranche()
      ]);
      assert.equal(tranche.eq(firstTranche), true);
    });
  });

  describe("eth price", async function() {
    let contract; // contract with account 0

    // runs before test cases
    before(async function() {
      const q2 = await Q2.new(accounts[0])
      contract = await Quarters.new(
        q2.address,
        firstTranche,
        { from: accounts[0] } // `from` key is important to change transaction creator
      );
    });

    it("should not allow others to change eth price", async function() {
      assertRevert(contract.setEthRate(350, { from: accounts[1] }));
      assertRevert(contract.setEthRate(400, { from: accounts[2] }));
    });

    it("should allow only owner to change eth price", async function() {
      let currentRate = await contract.ethRate();

      let receipt = await contract.setEthRate(2000, { from: accounts[0] });
      assert.equal(receipt.logs.length, 1);
      let log = receipt.logs[0];
      assert.equal(log.event, "EthRateChanged");
      assert.equal(log.args.currentRate.toNumber(), currentRate.toNumber());
      assert.equal(log.args.newRate.toNumber(), 2000);

      currentRate = await contract.ethRate();
      assert.equal(currentRate, 2000); // check if rate changed successfully

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
      assertRevert(contract.setEthRate(0, { from: accounts[0] })); // try with owner
      assertRevert(contract.setEthRate(0, { from: accounts[1] }));
    });
  });

  describe("transfer ownership", async function() {
    let contract; // contract with account 0

    // runs before test cases
    before(async function() {
      const q2 = await Q2.new(accounts[0])
      contract = await Quarters.new(
        q2.address,
        firstTranche,
        { from: accounts[0] } // `from` key is important to change transaction creator
      );
    });

    it("should allow to transfer ownership", async function() {
      let owner = await contract.owner();
      assert.equal(owner, accounts[0]);

      // check if eth price can not be set by accounts[1]
      assertRevert(contract.setEthRate(1200, { from: accounts[1] }));

      // change transfer ownership
      let receipt = await contract.transferOwnership(accounts[1]);
      assert.equal(receipt.logs.length, 1);
      assert.equal(receipt.logs[0].event, "OwnershipChanged");
      assert.equal(receipt.logs[0].args.newOwner, accounts[1]);
      assert.equal(receipt.logs[0].args.oldOwner, accounts[0]);

      owner = await contract.owner();
      assert.equal(owner, accounts[1]);

      // check if eth price can not be set by accounts[0]
      assertRevert(contract.setEthRate(1200, { from: accounts[0] }));

      // check rate if it's not changed
      let newRate = await contract.ethRate();
      assert.equal(newRate.eq(4000), true);

      // check if eth price can be set by accounts[1]
      receipt = await contract.setEthRate(1000, { from: accounts[1] });
      assert.equal(receipt.logs.length, 1);
      assert.equal(receipt.logs[0].event, "EthRateChanged");
    });

    it("should not allow to transfer ownership from any account except owner", async function() {
      let owner = await contract.owner();
      assert.equal(owner, accounts[1]);

      // try to change transfer ownership
      assertRevert(
        contract.transferOwnership(accounts[2], { from: accounts[3] })
      );

      owner = await contract.owner();
      assert.equal(owner, accounts[1]);

      // try to change transfer ownership
      assertRevert(
        contract.transferOwnership(accounts[2], { from: accounts[2] })
      );

      owner = await contract.owner();
      assert.equal(owner, accounts[1]);
    });
  });

  describe("approved", async function() {
    let contract; // contract with account 0

    // runs before test cases
    before(async function() {
      const q2 = await Q2.new(accounts[0])
      contract = await Quarters.new(
        q2.address,
        firstTranche,
        { from: accounts[0] } // `from` key is important to change transaction creator
      );

      const etherValue = web3.toWei(5);
      await contract.sendTransaction({from: accounts[1], value: etherValue});
      await contract.sendTransaction({from: accounts[2], value: etherValue});
      await contract.sendTransaction({from: accounts[7], value: etherValue});
    });

    it("should not allow others to change eth price", async function() {
      assertRevert(
        contract.setApprovedStatus(accounts[6], true, { from: accounts[1] })
      );
      assertRevert(
        contract.setApprovedStatus(accounts[7], true, { from: accounts[2] })
      );
    });

    it("should allow only owner to change approved status", async function() {
      // let's take accounts 6,7 & 8 as approved
      let isApproved = await contract.approved(accounts[6]);
      assert.equal(isApproved, false);

      isApproved = await contract.approved(accounts[7]);
      assert.equal(isApproved, false);

      // add accounts[6] as approved
      let receipt = await contract.setApprovedStatus(accounts[6], true, {
        from: accounts[0]
      });
      assert.equal(receipt.logs.length, 1);
      let log = receipt.logs[0];
      assert.equal(log.event, "ApprovedStatusChanged");
      assert.equal(log.args._address, accounts[6]);
      assert.equal(log.args.status, true);
      isApproved = await contract.approved(accounts[6]);
      assert.equal(isApproved, true);

      // add accounts[7] as approved
      receipt = await contract.setApprovedStatus(accounts[7], true, {
        from: accounts[0]
      });
      assert.equal(receipt.logs.length, 1);
      log = receipt.logs[0];
      assert.equal(log.event, "ApprovedStatusChanged");
      assert.equal(log.args._address, accounts[7]);
      assert.equal(log.args.status, true);
      isApproved = await contract.approved(accounts[7]);
      assert.equal(isApproved, true);
    });

    it("should allow only approved accounts to transfer", async function() {
      let senderBalance = (await contract.balanceOf(accounts[1])).toNumber();
      assert.equal(await contract.approved(accounts[1]), false);

      let receiverBalance = (await contract.balanceOf(accounts[2])).toNumber();
      assert.equal(await contract.approved(accounts[2]), false);

      assertRevert(contract.transfer(accounts[2], 5, {from: accounts[1]}));
      assertRevert(contract.transfer(accounts[1], 5, {from: accounts[2]}));

      senderBalance = (await contract.balanceOf(accounts[7])).toNumber();
      assert.equal(await contract.approved(accounts[7]), true);

      contract.transfer(accounts[2], 5, {from: accounts[7]});
      assert.equal((await contract.balanceOf(accounts[7])).toNumber(), senderBalance - 5)
      assert.equal((await contract.balanceOf(accounts[2])).toNumber(), receiverBalance + 5)

      senderBalance = (await contract.balanceOf(accounts[2])).toNumber();
      receiverBalance = (await contract.balanceOf(accounts[7])).toNumber();

      contract.transfer(accounts[7], 5, {from: accounts[2]});
      assert.equal((await contract.balanceOf(accounts[7])).toNumber(), senderBalance - 5)
      assert.equal((await contract.balanceOf(accounts[2])).toNumber(), receiverBalance + 5)
    });
  });

  //
  // Buy tokens
  //
  describe("buy", async function() {
    let contract; // contract with account 0
    let q2 = null

    // runs before test cases
    before(async function() {
      q2 = await Q2.new(accounts[0])
      contract = await Quarters.new(
        q2.address,
        firstTranche,
        { from: accounts[0] } // `from` key is important to change transaction creator
      );

      // set eth price to 1000 dollars
      await contract.setEthRate(ethRate, { from: accounts[0] });
    });

    // case 1
    describe("no of quarters < tranche size", async function() {
      it("should get equivalent tokens for ethers", async function() {
        // fetch current owner's balance
        let currentOwnerBalance = await web3.eth.getBalance(q2.address);
        let etherValue = web3.toWei(1);
        let expectedQuarters = web3.fromWei(
          new BigNumber(etherValue).mul(ethRate)
        );
        let expectedOwnerEarnings = new BigNumber(etherValue).mul(15).div(100);

        let receipt = await contract.sendTransaction({
          from: accounts[2],
          value: etherValue
        }); // directly without any method call

        assert.equal(receipt.logs.length, 2);
        let log = receipt.logs[0];
        assert.equal(log.event, "QuartersOrdered");
        assert.equal(log.args.sender, accounts[2]);
        assert.equal(log.args.ethValue.eq(etherValue), true);
        assert.equal(log.args.tokens.eq(expectedQuarters), true);

        // check quarter balance of sender
        let senderBalance = await contract.balanceOf(accounts[2]);
        assert.equal(expectedQuarters.eq(senderBalance), true);

        // check balance of sender
        let ownerETHBalance = await web3.eth.getBalance(q2.address);
        assert.equal(
          ownerETHBalance.minus(currentOwnerBalance).eq(expectedOwnerEarnings),
          true
        );
      });

      it("should set proper totalSupply, tranche", async function() {
        let senderBalance = await contract.balanceOf(accounts[2]);
        let newTotalSupply = new BigNumber(0).plus(senderBalance);

        let [totalSupply, tranche] = await Promise.all([
          contract.totalSupply(),
          contract.tranche()
        ]);
        assert.equal(totalSupply.eq(newTotalSupply), true);
        assert.equal(tranche.eq(firstTranche), true);
      });
    });

    // case 2
    describe("no of quarters >= tranche size", async function() {
      it("1. same as tranche: should get tokens size of tranche for ethers and owner gets cut", async function() {
        // fetch current owner's balance
        let currentOwnerBalance = await web3.eth.getBalance(q2.address);
        let [
          currentTotalSupply,
          currentTranche
        ] = await Promise.all([
          contract.totalSupply(),
          contract.tranche()
        ]);

        let etherValue = web3.toWei(10); // 10 ether -> should get 40k tokens
        let expectedQuarters = web3.fromWei(
          new BigNumber(etherValue).mul(ethRate)
        );
        let expectedOwnerEarnings = new BigNumber(etherValue).mul(15).div(100);

        let receipt = await contract.buy({
          from: accounts[3],
          value: etherValue
        }); // buy method

        assert.equal(receipt.logs.length, 3);
        let log = receipt.logs[0];
        assert.equal(log.event, "TrancheIncreased");

        let expectedTrache = new BigNumber(currentTranche).mul(2);
        assert.equal(log.args._tranche.eq(expectedTrache), true);

        log = receipt.logs[1];
        assert.equal(log.event, "QuartersOrdered");
        assert.equal(log.args.sender, accounts[3]);
        assert.equal(log.args.ethValue.eq(etherValue), true);
        assert.equal(log.args.tokens.eq(expectedQuarters), true);

        // check quarter balance of sender
        let senderBalance = await contract.balanceOf(accounts[3]);
        assert.equal(expectedQuarters.eq(senderBalance), true);

        // check balance of sender
        let ownerETHBalance = await web3.eth.getBalance(q2.address);
        assert.equal(
          ownerETHBalance.minus(currentOwnerBalance).eq(expectedOwnerEarnings),
          true
        );

        // check totalSupply and tranche
        let [totalSupply, tranche] = await Promise.all([
          contract.totalSupply(),
          contract.tranche()
        ]);
        assert.equal(
          totalSupply.eq(currentTotalSupply.add(expectedQuarters)),
          true
        ); // new totalSupply = totalSupply + nq (expectedQuarters)
      });

      it("2. more than tranche: should get tokens size of tranche for ethers and owner gets cut", async function() {
        // fetch current owner's balance
        let currentOwnerBalance = await web3.eth.getBalance(q2.address);
        let [
          currentTotalSupply,
          currentTranche
        ] = await Promise.all([
          contract.totalSupply(),
          contract.tranche()
        ]);

        let etherValue = web3.toWei(21);
        let expectedQuarters = currentTranche;
        let expectedOwnerEarnings = new BigNumber(etherValue).mul(15).div(100);

        let receipt = await contract.buy({
          from: accounts[4],
          value: etherValue
        }); // buy method

        assert.equal(receipt.logs.length, 3);
        let log = receipt.logs[0];
        assert.equal(log.event, "TrancheIncreased");

        let expectedTrache = new BigNumber(currentTranche).mul(2);
        assert.equal(log.args._tranche.eq(expectedTrache), true);

        log = receipt.logs[1];
        assert.equal(log.event, "QuartersOrdered");
        assert.equal(log.args.sender, accounts[4]);
        assert.equal(log.args.ethValue.eq(etherValue), true);
        assert.equal(log.args.tokens.eq(expectedQuarters), true);

        // check quarter balance of sender
        let senderBalance = await contract.balanceOf(accounts[4]);
        assert.equal(expectedQuarters.eq(senderBalance), true);

        // check balance of sender
        let ownerETHBalance = await web3.eth.getBalance(q2.address);
        assert.equal(
          ownerETHBalance.minus(currentOwnerBalance).eq(expectedOwnerEarnings),
          true
        );

        // check totalSupply, price and tranche
        let [totalSupply, tranche] = await Promise.all([
          contract.totalSupply(),
          contract.tranche()
        ]);
        assert.equal(
          totalSupply.eq(currentTotalSupply.add(expectedQuarters)),
          true
        );
        assert.equal(tranche.eq(currentTranche.mul(2)), true); // new tranche = tranche * 2 / 1
        assert.equal(tranche.eq(160000), true);

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

    // runs before test cases
    before(async function() {
      const q2 = await Q2.new(accounts[0])
      contract = await Quarters.new(
        q2.address,
        firstTranche,
        { from: accounts[0] } // `from` key is important to change transaction creator
      );

      await contract.setEthRate(ethRate, { from: accounts[0] });

      // buy quarters
      await contract.buy({ from: accounts[2], value: web3.toWei(1) }); // 1 ether
      await contract.buy({ from: accounts[3], value: web3.toWei(3) }); // 3 ethers
      await contract.buy({ from: accounts[4], value: web3.toWei(10) }); // 10 ethers
    });

    it("should not allow non-approved to withdraw", async function() {
      assertRevert(contract.withdraw(web3.toWei(100), { from: accounts[6] })); // 100 tokens
      assertRevert(contract.withdraw(web3.toWei(500), { from: accounts[7] })); // 500 tokens
    });

    it("should not allow approved to withdraw with no balance", async function() {
      // make accounts[6] approved
      await contract.setApprovedStatus(accounts[6], true, {
        from: accounts[0]
      });

      assertRevert(contract.withdraw(web3.toWei(100), { from: accounts[6] })); // 100 tokens
    });

    it("should have proper buying rate for types of devleopers", async function() {});

    // developers
    describe("developers", async function() {
      before(async function() {});
    });
  });
});
