const { expect } = require('chai');
const { BigNumber } = require('ethers');

let AutobetToken = "";
let AutobetLottery = "";
const tokenaddress = "0x2301081Fd0eEE253a33D9d4FE621EDC710157C49";
const lotteryaddress = "0x88D647F17c252bcA1C1E56661434157b7c523422";
let lotteryCreateFee = 10;
let entryfee = '1000000000000000';
let totalPrize = '1000000000000000000';
function timeout(delay) {
  return new Promise(res => setTimeout(res, delay));
}

let owner = "", b1 = "", b2 = "", a = "", c = "", d = "";
var ownerbal = "", b1bal = "", b2bal = "", abal = "", cbal = "", dbal = "", tsupplybal = "", contractbal = "";
var ownernewbal = "", b1newbal = "", b2newbal = "", anewbal = "", cnewbal = "", dnewbal = "", tsupplybal = "", contractnewbal = "";

async function setbalances() {
  ownerbal = await AutobetToken.balanceOf(owner.address);
  const provider = waffle.provider;
  b1bal = await provider.getBalance(b1.address);
  b1bal = await AutobetToken.balanceOf(b1.address);
  contractbal = await AutobetToken.balanceOf(tokenaddress);
  tsupplybal = await AutobetToken.totalSupply();

  b2bal = await AutobetToken.balanceOf(b2.address);
  abal = await AutobetToken.balanceOf(a.address);
  cbal = await AutobetToken.balanceOf(c.address);
  dbal = await AutobetToken.balanceOf(d.address);
}

async function setNewBalances() {
  ownernewbal = await AutobetToken.balanceOf(owner.address);
  const provider = waffle.provider;
  b1newbal = await provider.getBalance(b1.address);
  //  b1newbal=await AutobetToken.balanceOf(b1.address);
  contractnewbal = await AutobetToken.balanceOf(lotteryaddress);
  tsupplynewbal = await AutobetToken.totalSupply();

  b2newbal = await AutobetToken.balanceOf(b2.address);
  anewbal = await AutobetToken.balanceOf(a.address);
  cnewbal = await AutobetToken.balanceOf(c.address);
  dnewbal = await AutobetToken.balanceOf(d.address);
}
describe("Set balances", function () {
  it("Setting up", async function () {
    Autobet = await ethers.getContractFactory("ERC20Token");
    AutobetToken = await Autobet.attach(tokenaddress);
    const AutobetABI = await ethers.getContractFactory("Autobet");
    AutobetLottery = await AutobetABI.attach(lotteryaddress);
    [owner, b1, b2, a, c, d] = await ethers.getSigners();
    await setbalances();

  }).timeout(100000);

  describe('createLottery with lottype=revolver', async function () {

    let lotteryId;
    let organisationbyaddr;
    const picknumbers = 1;
    const startTime = Math.floor(Date.now() / 1000) + 60; // Start in 1 minute
    const endtime = startTime + 3600; // End in 1 hour
    const drawtime = endtime + 600; // Draw 10 minutes after end time
    const capacity = 10;
    const partner = 1;
    const rolloverperct = 34;
    const lottype = 0; // Spinner
    value1= '1100000000000000000';
    const expectedValue = totalPrize + ((totalPrize * lotteryCreateFee) / (100))
    // console.log(msgValue,"value");

    // it('should revert if total prize is not within the allowed range', async function () {
    //   expect(await AutobetLottery.connect(b1).createLottery(entryfee, picknumbers, totalPrize, startTime, endtime, drawtime, capacity, partner, rolloverperct, lottype)).to.be.revertedWith('Not allowed winning amount')
    // }).timeout(300000);


    // it('should revert if total prize is not greater than zero', async function () {
    //   expect(await AutobetLottery.connect(b1).createLottery(entryfee, picknumbers,totalPrize, startTime, endtime, drawtime, capacity, partner, rolloverperct, lottype)).to.be.revertedWith('Low totalPrice');
    // }).timeout(100000);

    // it('should revert if sent value does not match total prize plus fee', async function () {
    //   expect(await AutobetLottery.connect(b1).createLottery(entryfee, picknumbers, totalPrize, startTime, endtime, drawtime, capacity, partner, rolloverperct, lottype)).to.be.revertedWith('Amount not matching');
    // }).timeout(100000);

    // it('should revert if pick numbers is greater than capacity', async function () {
    //   expect(await AutobetLottery.connect(b1).createLottery(entryfee, picknumbers, totalPrize, startTime, endtime, drawtime, capacity, partner, rolloverperct, lottype)).to.be.revertedWith('capacity is less');
    // }).timeout(100000);

    it('creates a new lottery if all parameters are valid', async function () {
      await setbalances();
      console.log(b1bal.toString(), "Owner balance before")
      let lotteryCreateFee = 10;
      let entryfee = '1000000000000000';
      let totalPrize = '1000000000000000000';
      result = await AutobetLottery.connect(b1).createLottery(entryfee,picknumbers,totalPrize, startTime, endtime, drawtime, capacity, partner, rolloverperct, lottype)
      timeout(10000);
  
      await setNewBalances();
      console.log(b1newbal.toString(), "Owner balance after")
      
      const minPlayers = (new BigNumber.from(totalPrize.toString())) / (new BigNumber.from(entryfee.toString())) + (new BigNumber.from(totalPrize.toString()) * (new BigNumber.from(10)) / (new BigNumber.from(entryfee.toString()) / (new BigNumber.from(100))));
      console.log(minPlayers, "minplayers")
      // expect(new BigNumber.from(minPlayers.toString())).to.be.equal(new BigNumber.from(totalPrize.toString()))/(new BigNumber.from(entryfee.toString()))+(new BigNumber.from(totalPrize.toString())*(new BigNumber.from(10)/(new BigNumber.from(entryfee)/(new BigNumber.from(100)))))

      commisionEarned = (new BigNumber.from(totalPrize.toString()) * (new BigNumber.from(lotteryCreateFee.toString()) / (100)));
      console.log(commisionEarned,"commision")
      expect(new BigNumber.from(ownernewbal.toString())).to.be.equal(commisionEarned.toString() + (new BigNumber.from(ownerbal.toString())))
    }).timeout(200000);

    lotteries = await AutobetLottery.connect(b1).getOrglotteries(b1.address);
    console.log(b1.address, 'owner')
    const lotteryIds = lotteries[0];
    const lotteryIdInt = parseInt(lotteryIds.toString(), 16);
    console.log(lotteryIdInt, 'lotteries')
    });

  });
