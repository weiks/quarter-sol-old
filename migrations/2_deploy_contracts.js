var Quarters = artifacts.require('./Quarters.sol')

module.exports = function(deployer) {
  deployer.deploy(Quarters, '0', 'Quarters', 'QRT', '1000', '900000')
}
