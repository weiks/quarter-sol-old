var Quarters = artifacts.require('./Quarters.sol')
var Q2 = artifacts.require('./Q2.sol')

module.exports = async function(deployer) {
  let quartersAddress= null;
   await deployer.deploy(Q2,'0x8da17Bd0DFd4834E1c17819aDC3D392526c60C66').then(async (receipt)=>{
    await deployer.deploy(Quarters,receipt.address,1000000).then((rec)=>{
      quartersAddress= rec.address;
     })
   });
   console.log(quartersAddress);
}
