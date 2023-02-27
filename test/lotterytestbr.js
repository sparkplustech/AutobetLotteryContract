const { expect } = require("chai");
var chai = require('chai');
const BigNumber = require('bignumber.js');
const { ethers, waffle} = require("hardhat");
require("@nomiclabs/hardhat-web3");

chai.use(require('chai-bignumber')());
let AutobetToken="";
let AutobetLottery="";

const tokenaddress="0x157Bb9A4D329EDACC6F74aeed9b4f68a3Fcb8988";
const lotteryaddress="0x2202bF7A7D5Af636381D668765D2Ff183949f7ad";
function timeout(delay) {
    return new Promise( res => setTimeout(res, delay) );
  }

let owner="", b1="", b2="",a="",c="" ,d="" ;
var ownerbal="", b1bal="", b2bal="",abal="",cbal="",dbal="", tsupplybal="", contractbal="";
var ownernewbal="", b1newbal="", b2newbal="",anewbal="",cnewbal="",dnewbal="", tsupplybal="", contractnewbal="";

async function setbalances(){     
    ownerbal=await AutobetToken.balanceOf(owner.address);
    const provider = waffle.provider;
    b1bal = await provider.getBalance(b1.address);
   //b1bal=await AutobetToken.balanceOf(b1.address);
    contractbal= await AutobetToken.balanceOf(tokenaddress);
    tsupplybal= await AutobetToken.totalSupply();
    
    b2bal=await AutobetToken.balanceOf(b2.address);
    abal=await AutobetToken.balanceOf(a.address);
    cbal=await AutobetToken.balanceOf(c.address);
    dbal=await AutobetToken.balanceOf(d.address);
    }

    async function setNewBalances(){   
        ownernewbal=await AutobetToken.balanceOf(owner.address);
        const provider = waffle.provider;
        b1newbal = await provider.getBalance(b1.address);
       // b1newbal=await AutobetToken.balanceOf(b1.address);
        contractnewbal= await AutobetToken.balanceOf(lotteryaddress);
        tsupplynewbal= await AutobetToken.totalSupply();
        
        b2newbal=await AutobetToken.balanceOf(b2.address);
        anewbal=await AutobetToken.balanceOf(a.address);
        cnewbal=await AutobetToken.balanceOf(c.address);
        dnewbal=await AutobetToken.balanceOf(d.address);
      }
      describe("Set balances", function () {
        it("Setting up", async function () {
          Digifit = await ethers.getContractFactory("BEP20Token");
          AutobetToken= await Digifit.attach(tokenaddress);
          const AutobetABI = await ethers.getContractFactory("Autobet");
          AutobetLottery= await AutobetABI.attach(lotteryaddress);
          [owner, b1, b2,a,c ,d]=await ethers.getSigners();
         await setbalances();
  
        }).timeout(100000);

        describe("register bookies", function () {
            it("bookie b1 registers", async function () {
await setbalances();
console.log(b1bal.toString(),"before")
           result=   await AutobetLottery.connect(b1).addOrganisation(b1.address,"First lottery",1,3, {
                value: "200000000000000000"
            }); 

        //  await AutobetLottery.connect(b1).addOrganisation(b1.address,"First lottery",1,3);
                timeout(10000);
               await setNewBalances();
                median=(new BigNumber(1*10**18).plus(new BigNumber(3*10**18))).dividedBy(new BigNumber(2).multipliedBy(new BigNumber(10)).dividedBy(new BigNumber(100)));
             
                expect(new BigNumber(b1newbal.toString())).to.be.bignumber.equal(new BigNumber(b1bal.toString()).minus(new BigNumber(median.toString())));  
              }).timeout(100000);
    
            });
            it("bookie b2 registers", async function () {
              await setbalances();
              console.log(b2bal.toString(),"before")
                         result=   await AutobetLottery.connect(b2).addOrganisation(b2.address,"First lottery",1,3, {
                              value: "200000000000000000"
                          }); 
              
                      //  await AutobetLottery.connect(b2).addOrganisation(b2.address,"First lottery",1,3);
                              timeout(10000);
                             await setNewBalances();
                              median=(new BigNumber(1*10**18).plus(new BigNumber(3*10**18))).dividedBy(new BigNumber(2).multipliedBy(new BigNumber(10)).dividedBy(new BigNumber(100)));
                           
                              expect(new BigNumber(b2newbal.toString())).to.be.bignumber.equal(new BigNumber(b2bal.toString()).minus(new BigNumber(median.toString())));  
                            }).timeout(100000);
                  
                        
      });
    