const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  const Idol = await hre.ethers.getContractFactory("IdolCardSystem");
  const idol = await Idol.deploy(deployer.address);
  await idol.waitForDeployment();

  await idol.setCardPrice(100, "A", "B", "001", 100, "someURI");
  const price = await idol.getCardPrice();
  console.log("🧾 現在卡片價格為:", price.toString());
}

main().catch((err) => console.error(err));
