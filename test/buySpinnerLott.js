const { expect } = require('chai');
const { BigNumber } = require('ethers');

let AutobetToken = "";
let AutobetLottery = "";
const tokenaddress = "0x5e1D9a8c8Bb2250b74dB7612C0f41670FC3d359C";
const lotteryaddress = "0x7f97005752E49820bC16c402386C8Dd425857f0E";
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

    describe("Buy spinner lottery", function () {

        it('creates a new lottery if all parameters are valid and buy the lottery', async function () {
            await setbalances();
            console.log(b1bal.toString(), "Owner balance before")
            let entryfee = '1000000000000000';
            let totalPrize = '1000000000000000000';
            const picknumbers = 1;
            const startTime = Math.floor(Date.now() / 1000) + 60; // Start in 1 minute
            const endtime = startTime + 3600; // End in 1 hour
            const drawtime = endtime + 600; // Draw 10 minutes after end time
            const capacity = 10;
            const partner = 1;
            const rolloverperct = 34;
            const lottype = 0; // Spinner
            value1 = '1100000000000000000';
            number = '1';
            result1 = await AutobetLottery.connect(b1).createLottery(entryfee, capacity, totalPrize, startTime, endtime, drawtime, capacity, partner, rolloverperct, lottype)
            timeout(10000);

            lotteries = await AutobetLottery.connect(b1).getOrglotteries(owner.address);
            console.log(owner.address, 'owner')
            const lotteryId = lotteries[0];
            const lotteryIdInt = parseInt(lotteryId.toString(), 16);
            console.log(lotteryIdInt, ':lotteryid')
            result = await AutobetLottery.connect(b1).buySpinnerLottery(number, lotteryIdInt, { value: entryfee })
            timeout(10000);
            await setNewBalances();
            console.log(b1newbal.toString(), "after");

        });
    });
});
