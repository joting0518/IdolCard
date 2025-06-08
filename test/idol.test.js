const { expect } = require("chai");

describe("IdolCardSystem", function () {
  it("應該可以設定與取得卡片價格", async function () {
    const [owner] = await ethers.getSigners();
    const Idol = await ethers.getContractFactory("IdolCardSystem");
    const idol = await Idol.deploy(owner.address);
    await idol.waitForDeployment();

    await idol.setCardPrice(ethers.parseEther("0.02"), "Group", "Member", "001", 100, "uri");
    expect(await idol.getCardPrice()).to.equal(ethers.parseEther("0.02"));
  });
});
