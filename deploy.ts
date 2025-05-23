import { ethers } from "hardhat";

async function main() {
  
  const [deployer] = await ethers.getSigners();
  const stablecoinAddress = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
  const investoraddress = "0xbA93A83d5158A07628c1B9cE7458db4F2bb33e7d";
  const teamaddress = "0xbA93A83d5158A07628c1B9cE7458db4F2bb33e7d";
  console.log("Deploying contracts with the account:", deployer.address);




  const VaultFactory = await ethers.getContractFactory("Vault");
  const vault = await VaultFactory.deploy(stablecoinAddress);
  await vault.waitForDeployment();
  console.log(`Vault deployed at: ${await vault.getAddress()}`);


  const MainProjectFactory = await ethers.getContractFactory("MainProject");
  const mainProject = await MainProjectFactory.deploy();
  await mainProject.waitForDeployment();
  console.log(`Main project deployed at: ${await mainProject.getAddress()}`);

  const GovernanceTokenFactory = await ethers.getContractFactory("GovernanceToken");
  const governanceToken = await GovernanceTokenFactory.deploy(teamaddress, investoraddress);
  await governanceToken.waitForDeployment();
  console.log(`GovernanceToken deployed at: ${await governanceToken.getAddress()}`);

}


main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
