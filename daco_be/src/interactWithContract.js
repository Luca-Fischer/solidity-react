const { Web3 } = require("web3");
const contract = require("../build/contracts/SimpleStorage.json");

const web3 = new Web3("http://127.0.0.1:7545");

const abi = contract.abi;
const contractAddress = contract.networks["5777"].address;

const simpleStorage = new web3.eth.Contract(abi, contractAddress);

async function interact() {
  const accounts = await web3.eth.getAccounts();

  await simpleStorage.methods.set(150).send({ from: accounts[0] });

  const storedData = await simpleStorage.methods.get().call();

  console.log(`The stored value is: ${storedData}`);
}

interact().catch(console.error);
