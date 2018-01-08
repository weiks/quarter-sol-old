var Quarters = artifacts.require('./Quarters.sol')
var Q2 = artifacts.require('./Q2.sol')

module.exports = function(deployer) {
  deployer.deploy(Quarters, '0', 'Quarters', 'QRT', '100', '100000')
  deployer.deploy(Q2, web3.eth.accounts[0]).then(async () => {
    const q2 = await Q2.deployed()
    await q2.startStage(
      1000,
      web3.toWei(10000),
      web3.eth.blockNumber + 2,
      web3.eth.blockNumber + 5
    )
    await q2.buyTokens({value: web3.toWei(1)})
    await q2.buyTokens({value: web3.toWei(1)})
    await q2.buyTokens({value: web3.toWei(1)})
    await q2.disburse({value: web3.toWei(1)})
    // await q2.updateAccount()
  })
}
