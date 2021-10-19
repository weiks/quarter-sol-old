const { assert } = require('chai');
const truffleAssert = require('truffle-assertions');

let Quarters = artifacts.require("./Quarters.sol");
let Q2 = artifacts.require("./Q2.sol")
let kusdt = artifacts.require("./MockToken.sol");

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
      let tranche = await contract.tranche();
      assert.equal(tranche.words[0], firstTranche);

      // check for second contract
      tranche = await contract1.tranche();
      assert.equal(tranche.words[0], firstTranche);
    });
  })

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

    it("should not allow others to change kusdt rate", async function() {
      await truffleAssert.reverts(contract.setKusdtRate(350, { from: accounts[1] }));
      await truffleAssert.reverts(contract.setKusdtRate(400, { from: accounts[1] }));  
    });

    it("should allow only owner to change kusdt rate", async function() {

      let receipt = await contract.setKusdtRate(2000, { from: accounts[0] });
      assert.equal(receipt.logs.length, 1);
      let log = receipt.logs[0];
      assert.equal(log.event, "KUSDTRateChanged");
      assert.equal(log.args.newRate.toNumber(), 2000);

      let currentRate = await contract.kusdtRate();
      assert.equal(currentRate, 2000); // check if rate changed successfully

      //try changing rate to 400
      receipt = await contract.setKusdtRate(400, { from: accounts[0] });
      assert.equal(receipt.logs.length, 1);
      log = receipt.logs[0];
      assert.equal(log.event, "KUSDTRateChanged");
      assert.equal(log.args.newRate.toNumber(), 400);

      currentRate = await contract.kusdtRate();
      assert.equal(currentRate, 400); // check if rate changed successfully
    });

    it("should allow not allow anyone to set kusdtrate to 0", async function() {
      truffleAssert.reverts(contract.setKusdtRate(0, { from: accounts[0] })); // try with owner
      truffleAssert.reverts(contract.setKusdtRate(0, { from: accounts[1] }));
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
      truffleAssert.reverts(contract.setKusdtRate(1200, { from: accounts[1] }));

       // change transfer ownership
       let receipt = await contract.transferOwnership(accounts[1]);
       assert.equal(receipt.logs.length, 1);
       assert.equal(receipt.logs[0].event, "OwnershipChanged");
       assert.equal(receipt.logs[0].args.newOwner, accounts[1]);
       assert.equal(receipt.logs[0].args.oldOwner, accounts[0]);

      owner = await contract.owner();
      assert.equal(owner, accounts[1]);

      // check if eth price can not be set by accounts[0]
      truffleAssert.reverts(contract.setKusdtRate(1200, { from: accounts[0] }));

       // check rate if it's not changed
       let newRate = await contract.kusdtRate();
       assert.equal(newRate, 571);

       // check if eth price can be set by accounts[1]
       receipt = await contract.setKusdtRate(1000, { from: accounts[1] });
       assert.equal(receipt.logs.length, 1);
       assert.equal(receipt.logs[0].event, "KUSDTRateChanged");
    });

    it("should not allow to transfer ownership from any account except owner", async function() {
      let owner = await contract.owner();
       assert.equal(owner, accounts[1]);

      // try to change transfer ownership
      truffleAssert.reverts(
        contract.transferOwnership(accounts[2], { from: accounts[3] })
      );

      owner = await contract.owner();
      assert.equal(owner, accounts[1]);
    });
  });

  describe("developers", async function() {
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

    it("should not allow others to change developer status", async function() {
      truffleAssert.reverts(
        contract.setDeveloperStatus(accounts[6], true, { from: accounts[1] })
      );
      truffleAssert.reverts(
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
    let q2;
    let usdt;

    // runs before test cases
    before(async function() {
      usdt = await kusdt.new(accounts[0]);
      q2 = await Q2.new(accounts[0]);
      contract = await Quarters.new(
        q2.address,
        firstTranche,
        { from: accounts[0] } // `from` key is important to change transaction creator
      );

    });
    
      it("should get quarters based on usdt", async function() {

        let kusdtRate = (await contract.kusdtRate()).words[0];
        let royaltyPercentage = 15;
        
        //changing address of erc20
        contract.changeKUSDT(usdt.address,{from:accounts[0]});

        //mint usdt to buy quarters
       let receipt = await usdt.mint(accounts[0],1000000,{from:accounts[0]});
       assert.equal(receipt.logs[0].event, "Transfer");
       assert.equal((await usdt.balanceOf(accounts[0])).words[0],1000000);

        //approving to spend usdt to contract in behalf of user
        receipt = await usdt.approve(contract.address,1000000,{from:accounts[0]});
        assert.equal(receipt.logs[0].event, "Approval");
        receipt = await usdt.allowance(accounts[0],contract.address);
        assert(receipt.words[0],1000000);

        //quarters ordered and contract will spend usdt in behalf of user
        receipt= await contract.buy(1000000,{from:accounts[0]});
        assert.equal(receipt.logs.length, 3);
        let logs = receipt.logs;
        assert.equal(logs[0].event,'Transfer');
        assert.equal(logs[1].event,'QuartersOrdered');
        
        //expected total supply 
        let expectedTotalSupply = parseInt((10e6*kusdtRate)/10e6)+parseInt((10e6*kusdtRate*royaltyPercentage)/10e8);
        assert.equal((await contract.totalSupply()).words[0],expectedTotalSupply);
        assert.equal((await contract.balanceOf(accounts[0])).words[0],parseInt((10e6*kusdtRate)/10e6));
       });

      it("should get quarters based on kusdtRate buy sending usdt on buyer address", async function() {

        let kusdtRate = (await contract.kusdtRate()).words[0];

         //changing address of kusdt
        contract.changeKUSDT(usdt.address,{from:accounts[0]});

        //mint usdt to buy quarters
        await usdt.mint(accounts[0],1000000,{from:accounts[0]});
        assert(await usdt.balanceOf(accounts[0]),1000000);

       //changing address of kusdt
        await usdt.approve(contract.address,1000000,{from:accounts[0]});
        let receipt = await usdt.allowance(accounts[0],contract.address);
        assert(receipt.words[0],1000000);

        receipt= await contract.buyFor(accounts[1],1000000,{from:accounts[0]});
        assert.equal(receipt.logs.length, 4);
        let logs = receipt.logs;
        assert.equal(logs[0].event,'Transfer');
        assert.equal(logs[1].event,'QuartersOrdered');
        assert((await contract.balanceOf(accounts[1])).words[0],parseInt((10e6*kusdtRate)/10e6));
      });
    });

  describe("withdraw", async function() {
      let contract; // contract with account 0
      let q2;
      let usdt;
  
      // runs before test cases
      before(async function() {
        usdt = await kusdt.new(accounts[0]);
        q2 = await Q2.new(accounts[0]);
        contract = await Quarters.new(
          q2.address,
          firstTranche,
          { from: accounts[0] } // `from` key is important to change transaction creator
        );
  
      });
      
        it("withdraw kusdt by burning quarters", async function() {
  
          let kusdtRate = (await contract.kusdtRate()).words[0];
          let royaltyPercentage = 15;
          
          //changing address of erc20
          contract.changeKUSDT(usdt.address,{from:accounts[0]});
  
          //mint usdt to buy quarters
         let receipt = await usdt.mint(accounts[0],1000000,{from:accounts[0]});
         assert.equal(receipt.logs[0].event, "Transfer");
         assert.equal((await usdt.balanceOf(accounts[0])).words[0],1000000);
  
          //approving to spend usdt to contract in behalf of user
          receipt = await usdt.approve(contract.address,1000000,{from:accounts[0]});
          assert.equal(receipt.logs[0].event, "Approval");
          receipt = await usdt.allowance(accounts[0],contract.address);
          assert(receipt.words[0],1000000);
  
          //quarters ordered and contract will spend usdt in behalf of user
          receipt= await contract.buy(1000000,{from:accounts[0]});
          assert.equal(receipt.logs.length, 3);
          let logs = receipt.logs;
          assert.equal(logs[0].event,'Transfer');
          assert.equal(logs[1].event,'QuartersOrdered');
          
          //expected total supply 
          let expectedTotalSupply = parseInt((10e6*kusdtRate)/10e6)+parseInt((10e6*kusdtRate*royaltyPercentage)/10e8);
          assert.equal((await contract.totalSupply()).words[0],expectedTotalSupply);
          assert.equal((await contract.balanceOf(accounts[0])).words[0],parseInt((10e6*kusdtRate)/10e6));

          //set as developer to 
         receipt = await contract.setDeveloperStatus(accounts[0],true,{from:accounts[0]});
         assert.equal(receipt.logs[0].event,'DeveloperStatusChanged');
        receipt = await contract.withdraw(10);
        assert.equal(receipt.logs[0].event,'Withdraw');
        assert.equal(receipt.logs[1].event,'BaseRateChanged');
        assert.equal(receipt.logs[2].event,'Transfer');

        //set q2 as developer so that we can call withdraw method 
        receipt = await contract.setDeveloperStatus(q2.address,true,{from:accounts[0]});
        assert.equal(receipt.logs[0].event,'DeveloperStatusChanged');

        //updating quarters on q2
        await q2.setQuarters(contract.address,{from: accounts[0]});
        await q2.changeKUSDT(usdt.address,{from:accounts[0]});

        //withdraw royalties
        receipt = await q2.withdrawRoyalty();
        assert.equal(receipt.logs[0].event,'Transfer');
        });
    });
});