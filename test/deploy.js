
//token contract adres=0xb86854506dee0BB90a0d5FcDc7D8F609ba780fcF
const { expect } = require("chai");
function timeout(delay) {
    return new Promise( res => setTimeout(res, delay) );
  }

describe("Token contract", function () {
  it("Deployment should assign the total supply of tokens to the owner", async function () {
    const [owner] = await ethers.getSigners();
    // const [mark] = await ethers.getSigners();

    const AutobetToken = await ethers.getContractFactory("BEP20Token");
    const Autobet = await AutobetToken.deploy();
    const ownerBalance = await Autobet.balanceOf(owner.address);
    expect(await Autobet.totalSupply()).to.equal(ownerBalance);
    console.log(Autobet.address, owner.address) 
    const Autobetlottery = await ethers.getContractFactory("Autobet");
    const Autobetdeploy = await Autobetlottery.deploy(Autobet.address);

    console.log(Autobetdeploy.address, owner.address) 
  }).timeout(1000000);
});