var Quarters = artifacts.require('./Quarters.sol')

module.exports = function(deployer) {
  deployer.deploy(Quarters, '1000000000', 'Quarters', 'QRT', '1000', '900000')
}
