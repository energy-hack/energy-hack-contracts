var Token = artifacts.require("./SchneiderToken.sol");
var SchneiderSys = artifacts.require("./SchneiderSystem.sol");

const endTime =  Math.round((new Date().getTime() + 30000)/1000); // Now + 30 seconds;
const startKwh = 30007873709;
const prevPeriodKwh = 43368663;
const goalPeriodKwh = 24368663;
const customer = "0xB580f73DB43015A1211A394Eb175a81dF55bBe66";
const schneider = "0x42072709803c2ee3EB16Ac7039429Bd63b031296";
const mintValue = 1234567891234567800;

module.exports = function(deployer) {
  deployer.deploy(Token)
  .then(function() {
      return deployer.deploy(SchneiderSys,
        Token.address, endTime, startKwh, prevPeriodKwh, goalPeriodKwh, customer, schneider);
  }).then(function() {
      return Token.deployed();
  }).then(function(InstanceToken) {
      return InstanceToken.mint(SchneiderSys.address, mintValue);
  })
};
