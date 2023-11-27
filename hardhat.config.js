require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");

module.exports = {
  defaultNetwork: "sepolia",
  paths: {
    sources: './Contract/Phase_3.1_SEPOLIA_ETH/SplittedContract',
  },
  networks: {
    sepolia: {
      url: "https://sepolia.infura.io/v3/5686b17f6f234085b42a3c455e4244bd",

      //url: "https://rpc-mumbai.maticvigil.com/v1/381a5a8b197cd8cb5667c5d5c6837a2bf5d975b7",
      accounts: [
        `ff59c41fbf36b188b258c0e25567a747b9a512dcf306e1f1aea4bd1dff1f3f10`, //owner
        `5c6cda40a3c3f6bd25edac19e33af3545ab1f36bd9233172074a48781f3d97a1`, //mark
        `b3c60f8c2948fa049baa700be9c861a6df538a7f7b6d58d5b48469f787b9e17e`,//a
        `88a2fb3261a22b02c1571f3db37a7c304ebc7b36d75f1c17e1614e4af7cdbbb0`,//b
        `452493a9cb54609355a5eb8a57ba3a0e2b68ac0e768078e1055bf0568632847a`,//c
        `487a11a481e75bc81dc23a29146e3343433540fb49481b64ddfa9c293b1c2d5d`//d
      ],
  gas: 3000000,
    }
  },
  etherscan: {
    apiKey:{
      sepolia:"5686b17f6f234085b42a3c455e4244bd",
  } 
},
  solidity: {
    
    compilers:[
      {version: "0.8.22",settings: {
        optimizer: {
          enabled: true,
          runs: 200,
          
        }}},
      {version: "0.5.16"}
    ],
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
};
