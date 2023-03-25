require("@nomiclabs/hardhat-waffle");

module.exports = {
  defaultNetwork: "goerli",
  networks: {
    hardhat: {
    },
    goerli: {
      url: "https://goerli.infura.io/v3/5686b17f6f234085b42a3c455e4244bd",

      //url: "https://rpc-mumbai.maticvigil.com/v1/381a5a8b197cd8cb5667c5d5c6837a2bf5d975b7",
      accounts: [
        `0x1a7ab01d299e0c0933cba7047392d46dcdb4af9749e1fdc6070e9fed5dc27c71`, //owner
        `0xb3e5ca7f7e519c2d8f0cbe3ee9814221b6ee7bb4605c8620904edd5aede548f5`, //mark
        `0xff59c41fbf36b188b258c0e25567a747b9a512dcf306e1f1aea4bd1dff1f3f10`,//a
        `0xe9c6cdd3c94ec8f1a3ecc03febb57d3f2257d20d7e69d7300df7591163801193`,//b
        `0x2b3b803df1545e5ac4fe982186bf59f7e98a4b766bad3b65608df041115c04f0`,//c
        `0x82c789e731b488bf95c57d9e4d2d3962d4e1ebfcedad2422d31460521abac128`//d
      ],
  gas: 3000000,
    }
  },
  solidity: {
    
    compilers:[
      {version: "0.8.7",settings: {
        optimizer: {
          enabled: true,
          runs: 1337,
          viaIR: true,
        }}},
      {version: "0.5.16"}
    ],
    settings: {
      optimizer: {
        enabled: true,
        runs: 1337,
      },
    },
  },
};
