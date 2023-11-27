
//token contract adres=0xb86854506dee0BB90a0d5FcDc7D8F609ba780fcF
const { expect } = require("chai");
function timeout(delay) {
    return new Promise( res => setTimeout(res, delay) );
  }
  

describe("Token contract", function () {
  it("Deployment should assign the total supply of tokens to the owner", async function () {
    const [owner] = await ethers.getSigners();
    const [mark] = await ethers.getSigners();
    console.log(owner.address);
    const AutobetToken = await ethers.getContractFactory("ERC20Token");
    const AutobetTokenAddress = '0x2301081Fd0eEE253a33D9d4FE621EDC710157C49'
    const userAddress = '0xF9dCB02ff6595E5a55bc4cd4412568827df63822'
    console.log("AutobetToken:",Autobet);
    const ownerBalance = await Autobet.balanceOf(owner.address);
    expect(await Autobet.totalSupply()).to.equal(ownerBalance); 
    const Autobetlottery = await ethers.getContractFactory("Autobet");
    const Autobetdeploy = await Autobetlottery.deploy(AutobetTokenAddress,userAddress);

    console.log("contract address:",Autobetdeploy.address,"owner address:", owner.address) 
  }).timeout(1000000);
});