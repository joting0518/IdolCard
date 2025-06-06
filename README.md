# step 1 先把這兩個帳號綁到 metamask
Client
Account #18: 0xdD2FD4581271e230360230F9337D5c0430Bf44C0 (10000 ETH)
Private Key: 0xde9be858da4a475276426320d5e9262ecfc3ba460bfac56360bfa6c4c28b4ee0

Store(Company)
Account #19: 0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199 (10000 ETH)
Private Key: 0xdf57089febbacf7ba0bc227dafbffa9fc08a93fdc68e1e42411a14efcf23656e

# step 2
npm install --save-dev hardhat
npm install @nomicfoundation/hardhat-toolbox
npx hardhat node #相當於 avail 的功能，執行在另外的 terminal
（如果出現 permission deny 則執行 rm -rf node_modules package-lock.json 然後重新執行） 
npx hardhat compile #先 compile (如果出現錯誤或是修改功能後要重新生成合約，可以先執行 npx hardhat clean)
npx hardhat run scripts/deploy.js --network localhost #部署合約

會出現：
🚀 使用帳號部署: 0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199 
這個可以在 hardhat.config.js module.exports 修改你希望的合約擁有者

📦 合約部署成功於: 0x5095d3313C76E8d29163e40a0223A5816a8037D8
記得放到 idol-card-ui.html const contractAddress = "";

👑 擁有者是: 0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199
這個可以在 hardhat.config.js module.exports 修改你希望的合約擁有者

# step 3
npx live-server #啟動介面 html

