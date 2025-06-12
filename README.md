# Process Flow

## 1. System Introduction
**NFT Card Trading System**: Uses Hardhat to deploy smart contracts, integrates with MetaMask wallet on the front-end, and conducts user authentication and transactions. The system determines whether the connected account is a seller or a buyer and directs them to the corresponding functional area.

## 2. Connect Wallet
![image-0](https://github.com/user-attachments/assets/5554d3eb-22d1-455a-8cc3-9ef8fdde702d)

After logging into the MetaMask extension, the user clicks the **Connect Wallet** button. When the screen displays **Connected to Wallet: Wallet Address**, it indicates that the connection is successful.
![image-1](https://github.com/user-attachments/assets/13608d3e-904f-4c3d-a2b1-ef1a730ab2ef)
Clicking the **Connected:...** MetaMask icon on the left allows the user to check the wallet balance.

## 3. Company Features
### Issue Cards
![image-2](https://github.com/user-attachments/assets/4556f483-08bf-4f6d-9196-4038fd195f02)

The company fills in the fields and the **Number of Issued Cards** to issue multiple idol card NFTs in bulk.

### My Cards
![image-3](https://github.com/user-attachments/assets/3f843b29-29d5-40d2-8160-63f575d08c9f)

View all issued cards and their statuses from the company.

### Past Transactions
![image-14](https://github.com/user-attachments/assets/1a7716da-d2df-45fd-9ba3-d0cf36a8d177)

View transaction details for all cards issued by the company, including time and status.

## 4. Customer Features
### Purchase Cards
![image-5](https://github.com/user-attachments/assets/af79ebae-9edb-4694-a888-0b765f0bf0be)

![image-8](https://github.com/user-attachments/assets/3736facd-7896-410a-bf2e-d0ef50af7d79)

Customers can view the company's initial card release and other cards resold by customers. After clicking **Buy**, the user confirms the transaction in their wallet, and upon success, ownership will transfer to the user.

### My Cards
![image](https://github.com/user-attachments/assets/4fba5e97-4dce-4946-99e4-a3474cac8f58)


View the cards that the user has purchased and owns.

#### View Details
![image-9](https://github.com/user-attachments/assets/bb527909-2aa0-460b-b682-c32fa383f424)

View the card's historical transaction records.

#### List Cards for Sale
![image-7](https://github.com/user-attachments/assets/71b231c8-d078-4930-a050-fb1d31e6fc47)


View cards listed for sale after creating a transaction.

Click **Cancel Listing** to return the card to the owned card area.

#### Create Transaction
![image-6](https://github.com/user-attachments/assets/519dd8e3-09a6-443d-805b-69f866f38804)


Create a transaction: resell owned cards to the resale market. Other users will see the seller's set price in the purchase area.

### Market Transactions
![image-10](https://github.com/user-attachments/assets/fa4d85b9-2497-4856-ae0d-77cbfa7c82ab)
![image-11](https://github.com/user-attachments/assets/27d33a88-9b56-4bb6-be5c-2311db9c16fe)


**My Sales**: View information and status of cards resold through created transactions.

**My Transaction Management**: View purchase and resale records.

### Past Transactions
![image-12](https://github.com/user-attachments/assets/efd0dda6-d8a2-41ac-a348-afdd7fdd8782)

View transaction history and the data associated with the cards owned.

***
# Environment 設置環境
## step 1 先把這兩個帳號綁到 metamask
Client
Account #18: 0xdD2FD4581271e230360230F9337D5c0430Bf44C0 (10000 ETH)
Private Key: 0xde9be858da4a475276426320d5e9262ecfc3ba460bfac56360bfa6c4c28b4ee0

Store(Company)
Account #19: 0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199 (10000 ETH)
Private Key: 0xdf57089febbacf7ba0bc227dafbffa9fc08a93fdc68e1e42411a14efcf23656e

## step 2
npm install --save-dev hardhat
npm install @nomicfoundation/hardhat-toolbox
npm install @openzeppelin/contracts
npx hardhat node #相當於 avail 的功能，執行在另外的 terminal
（如果出現 permission deny 則執行 rm -rf node_modules package-lock.json 然後重新執行） 
npx hardhat compile #先 compile (如果出現錯誤或是修改功能後要重新生成合約，可以先執行 npx hardhat clean)
npx hardhat run scripts/deploy.js --network localhost #部署合約

會出現：
🚀 使用帳號部署: 0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199 
這個可以在 hardhat.config.js module.exports 修改你希望的合約擁有者

📦 合約部署成功於: 0x5095d3313C76E8d29163e40a0223A5816a8037D8

👑 擁有者是: 0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199
這個可以在 hardhat.config.js module.exports 修改你希望的合約擁有者

## step 3
npx live-server #啟動介面 html
