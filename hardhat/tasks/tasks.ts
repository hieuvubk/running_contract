import { BigNumber, constants, ethers, utils } from 'ethers';
import { task } from 'hardhat/config';
import { TLSSocketOptions } from 'tls';
import sha256 from 'crypto-js/sha256';

task('contract:verify', 'verify contract')
  .addOptionalParam('address', 'address')
  .addOptionalParam('symbol', 'symbol')
  .setAction(async (taskArgs, hre) => {
    const address = taskArgs.address || '0x69Ba15A2C1027f6E6177FcF49d426D38816b8EaA';
    await hre.run('verify:verify', {
      address,
      constructorArguments: [],
    });
  });

task('contract:createOrder', 'verify contract')
  .addOptionalParam('address', 'address')
  .addOptionalParam('symbol', 'symbol')
  .setAction(async (taskArgs, hre) => {
    const { deployments, getNamedAccounts, web3 } = hre;
  const { deployer } = await getNamedAccounts();

  const Contract = await deployments.get('OrderStore');
  const instance = new web3.eth.Contract(Contract.abi, Contract.address);

  const data = {
      id: "1234",
      name: "abc",
  }
  const hash = sha256(data.name);
  console.log(hash.toString());

  const tx = await instance.methods.issue(data.id, '0xba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad').send({ from: deployer});

  console.log(`tx hash: ${tx.transactionHash}`);
  });

task('contract:updateStatus', 'Update order status')
  .addOptionalParam('address', 'address')
  .addOptionalParam('symbol', 'symbol')
  .setAction(async (taskArgs, hre) => {
    const { deployments, getNamedAccounts, web3 } = hre;
  const { deployer } = await getNamedAccounts();

  const Contract = await deployments.get('OrderStore');
  const instance = new web3.eth.Contract(Contract.abi, Contract.address);

  const data = {
      id: "1234",
      name: "abc",
  }
  const hash = sha256(data.name);
  console.log(hash.toString());

  enum OrderStatus {
    accepted, 
    call_ship,
    taked,
    warehouse,
    delivering,
    delivery_success,
    rejected,
    return_warehouse,
    return_shop,
    cancel,
    checking,
    checked,
    wait_deposit, 
    deposited 
  };

  const tx = await instance.methods.updateOrderStatus(data.id, OrderStatus.cancel).send({ from: deployer});

  console.log(`tx hash: ${tx.transactionHash}`);
  });

  task('contract:getOrder', 'Update order status')
  .addOptionalParam('address', 'address')
  .addOptionalParam('symbol', 'symbol')
  .setAction(async (taskArgs, hre) => {
    const { deployments, getNamedAccounts, web3 } = hre;
    const { deployer } = await getNamedAccounts();

    const Contract = await deployments.get('OrderStore');
    const instance = new web3.eth.Contract(Contract.abi, Contract.address);

    const data = {
        id: "1234",
        name: "abc",
    }
    const hash = sha256(data.name);
    console.log(hash.toString());

    const response = await instance.methods.getOrder(data.id).call();

    console.log(response);
  });

  task('contract:setSigner', 'Update order status')
  .addOptionalParam('address', 'address')
  .addOptionalParam('symbol', 'symbol')
  .setAction(async (taskArgs, hre) => {
    const { deployments, getNamedAccounts, web3 } = hre;
    const { deployer } = await getNamedAccounts();

    const Contract = await deployments.get('OrderStore');
    const instance = new web3.eth.Contract(Contract.abi, Contract.address);

    const tx = await instance.methods.setSigner('0xf29162ed5Ed4Da23656C5190aae71e61Bb074AeC').send({from: deployer});

    console.log(`tx hash: ${tx.transactionHash}`);
  });

  task('contract:setRole', 'Update order status')
  .addOptionalParam('address', 'address')
  .addOptionalParam('symbol', 'symbol')
  .setAction(async (taskArgs, hre) => {
    const { deployments, getNamedAccounts, web3 } = hre;
    const { deployer } = await getNamedAccounts();

    const Contract = await deployments.get('OrderStore');
    const instance = new web3.eth.Contract(Contract.abi, Contract.address);

    const tx = await instance.methods.setRole('0xf29162ed5Ed4Da23656C5190aae71e61Bb074AeC', '0x1f0426c2589e5c3ea5f5996e2a4371ca21edd86514b6679c9dd135d7c85b28bf').send({from: deployer});

    console.log(`tx hash: ${tx.transactionHash}`);
  });

  task('contract:consensus', 'Consensus')
  .addOptionalParam('address', 'address')
  .addOptionalParam('symbol', 'symbol')
  .setAction(async (taskArgs, hre) => {
    const { deployments, getNamedAccounts, web3 } = hre;
    const { deployer } = await getNamedAccounts();

    const Contract = await deployments.get('OrderStore');
    const instance = new web3.eth.Contract(Contract.abi, Contract.address);

    const data = {
      id: "10",
      name: "abc",
    }
    const hash = sha256(data.name);
    console.log(hash.toString());

    const tx = await instance.methods.submitTransaction(`0x${hash}`).send({from: deployer});

    console.log(`tx hash: ${tx.transactionHash}`);
  });