const hre = require("hardhat");

async function main() {
  const accounts = await hre.ethers.getSigners();
  const deployer = accounts[0];
  console.log("🚀 使用帳號部署:", deployer.address);

  const name = "IdolCard";
  const symbol = "IDOL";
  const ownerAddress = deployer.address;

  // 部署 CardManager
  const CardManager = await hre.ethers.getContractFactory("CardManager");
  const cardManager = await CardManager.deploy(name, symbol, ownerAddress);
  await cardManager.waitForDeployment();
  const cardManagerAddress = await cardManager.getAddress();
  console.log("📦 CardManager 部署成功於:", cardManagerAddress);

  // 部署 TradeManager
  const TradeManager = await hre.ethers.getContractFactory("TradeManager");
  const tradeManager = await TradeManager.deploy(name, symbol, deployer.address);
  await tradeManager.waitForDeployment();
  const tradeManagerAddress = await tradeManager.getAddress();
  console.log("📦 TradeManager 部署成功於:", tradeManagerAddress);

  // 部署主合約，傳入子合約地址
  const Idol = await hre.ethers.getContractFactory("IdolCardSystem");
  const idol = await Idol.deploy(cardManagerAddress, tradeManagerAddress);
  await idol.waitForDeployment();
  const idolAddress = await idol.getAddress();
  console.log("📦 IdolCardSystem 主合約部署成功於:", idolAddress);

  // 設定主合約地址到子合約（CardManager & TradeManager）
  // 先要連接部署者（signer）來呼叫子合約的 setMainContract 函數
  const cardManagerConnected = CardManager.attach(cardManagerAddress).connect(deployer);
  const tradeManagerConnected = TradeManager.attach(tradeManagerAddress).connect(deployer);

  // 呼叫設定函數
  let tx;

  tx = await cardManagerConnected.setMainContract(idolAddress);
  await tx.wait();
  console.log("✅ CardManager 設定 mainContract 地址完成");

  tx = await tradeManagerConnected.setMainContract(idolAddress);
  await tx.wait();
  console.log("✅ TradeManager 設定 mainContract 地址完成");

  console.log("👑 擁有者是:", await idol.owner());

  const fs = require('fs');
  const path = require('path');
  const addresses = {
    CardManager: cardManagerAddress,
    TradeManager: tradeManagerAddress,
    IdolCardSystem: idolAddress
  };
  const outputPath = path.join(__dirname, '../frontend/contract-addresses.json');
  fs.writeFileSync(outputPath, JSON.stringify(addresses, null, 2));
  console.log(`📁 合約地址已寫入 ${outputPath}`);
}


main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
