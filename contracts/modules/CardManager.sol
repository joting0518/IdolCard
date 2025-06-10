// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "../base/NFTBase.sol";
import "../utils/StringUtils.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract CardManager is NFTBase {
    address public mainContract;

    constructor(
        string memory name_,
        string memory symbol_,
        address initialOwner
    ) NFTBase(name_, symbol_, initialOwner) {}
    modifier onlyOwnerOrMainContract() {
        require(
            msg.sender == owner() || msg.sender == mainContract,
            "Only owner or main contract"
        );
        _;
    }

    // 部署後呼叫設定主合約地址
    function setMainContract(
        address _mainContract
    ) external onlyOwnerOrMainContract {
        mainContract = _mainContract;
    }

    using StringUtils for bytes32;
    struct CardInfo {
        string idolGroup;
        string member;
        string cardNumber;
        uint256 listPrice;
        string photoURI;
    }

    struct PendingTransfer {
        address buyer;
        uint256 amount;
        bool approved;
    }
    // 1. 獲取公司上架的所有卡片
    struct CardDisplay {
        string uid;
        string idolGroup;
        string member;
        string cardNumber;
        uint256 listPrice;
        string photoURI;
        bool isSold;
    }

    CardInfo public defaultCardInfo;

    mapping(string => uint256) private uidToTokenId;
    mapping(uint256 => string) private tokenIdToUID;
    mapping(string => bool) public cardUIDUsed;
    mapping(string => CardInfo) public uidToCardInfo;
    mapping(string => PendingTransfer) public pendingTransfers;
    mapping(string => uint256) public requestTimestamps;
    mapping(uint256 => CardInfo) public tokenIdToCardInfo;
    mapping(address => uint256) public prepaidAmount;
    // 新增：NFT 階段狀態，1=未購買，2=已購買未綁定，3=已購買已綁定
    mapping(uint256 => uint8) public phase;
    string[] public allCardUIDs;
    string[] public resaleCardUIDs;
    mapping(string => bool) public isResaleListed;

    event CardPurchased(address indexed buyer, uint256 amount, string uid);
    event CardRequested(address indexed buyer, string uid);
    event CardApproved(string uid, address indexed buyer, uint256 tokenId);
    event CardInfoUpdatedWithUID(
        string uid,
        string idolGroup,
        string member,
        string cardNumber,
        uint256 listPrice,
        string photoURI
    );
    event CardRequestRejected(string uid, address buyer);

    function setCardPrice(
        uint256 newPrice,
        string memory idolGroup,
        string memory member,
        string memory cardNumber,
        uint256 listPrice,
        string memory photoURI,
        uint256 amount
    ) external onlyOwnerOrMainContract returns (string[] memory) {
        require(amount > 0, "Amount must be greater than 0");
        cardPrice = newPrice;

        // 產生基礎 UID
        bytes32 hash = keccak256(
            abi.encodePacked(
                idolGroup,
                member,
                cardNumber,
                listPrice,
                photoURI,
                block.timestamp,
                block.number
            )
        );
        string memory baseUID = StringUtils.toHexString(hash);

        string[] memory generatedUIDs = new string[](amount);

        // 要發行 amount 張卡
        for (uint256 i = 0; i < amount; i++) {
            // 拼接流水編號
            string memory numberedUID = string(abi.encodePacked(baseUID, "-", Strings.toString(i + 1)));


            require(!cardUIDUsed[numberedUID], "UID already used");

            CardInfo memory newCardInfo = CardInfo(
                idolGroup,
                member,
                cardNumber,
                listPrice,
                photoURI
            );

            uidToCardInfo[numberedUID] = newCardInfo;
            cardUIDUsed[numberedUID] = true;
            allCardUIDs.push(numberedUID);

            generatedUIDs[i] = numberedUID;

            emit CardInfoUpdatedWithUID(
                numberedUID,
                idolGroup,
                member,
                cardNumber,
                listPrice,
                photoURI
            );
        }

        // 只設定最後一張卡作為 defaultCardInfo（你如果希望就留，不希望可移除）
        defaultCardInfo = CardInfo(
            idolGroup,
            member,
            cardNumber,
            listPrice,
            photoURI
        );

        return generatedUIDs; // 返回所有生成的UID，前端可以一次拿回來
    }
    function getCardPrice() external view returns (uint256) {
        return cardPrice;
    }
    function bindUID(string memory uid) external {
        require(!uidUsed[uid], "UID already bound");

        uint256 tokenId = uidToTokenId[uid];
        require(tokenId != 0, "Token not minted yet");
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        require(phase[tokenId] == 2, "Token not in bindable phase");

        uidUsed[uid] = true;
        tokenIdToUID[tokenId] = uid;
        phase[tokenId] = 3; // 設為已購買已綁定
    }

    function approveTransfer(
        string memory uid
    ) external onlyOwnerOrMainContract {
        require(
            pendingTransfers[uid].amount == cardPrice,
            "Payment not received"
        );
        require(pendingTransfers[uid].buyer != address(0), "No request");
        require(!pendingTransfers[uid].approved, "Already approved");
        require(!uidUsed[uid], "UID already bound");

        address buyer = pendingTransfers[uid].buyer;
        uint256 tokenId = nextTokenId;
        _safeMint(buyer, tokenId);

        // 設定卡片的 URI 和資訊
        if (bytes(defaultCardInfo.photoURI).length > 0) {
            _setTokenURI(tokenId, defaultCardInfo.photoURI);
        }

        // 將預設卡片資訊指派給新發行的代幣
        tokenIdToCardInfo[tokenId] = defaultCardInfo;

        uidUsed[uid] = true;
        uidToTokenId[uid] = tokenId;
        tokenIdToUID[tokenId] = uid;
        nextTokenId++;

        payable(owner()).transfer(cardPrice);
        pendingTransfers[uid].approved = true;

        emit CardApproved(uid, buyer, tokenId);
    }
    function rejectTransfer(
        string memory uid
    ) external onlyOwnerOrMainContract {
        require(pendingTransfers[uid].buyer != address(0), "No request exists");
        require(!pendingTransfers[uid].approved, "Already approved");

        address buyer = pendingTransfers[uid].buyer;
        uint256 amount = pendingTransfers[uid].amount;

        // 退還購買費用
        payable(buyer).transfer(amount);

        // 清除請求記錄
        delete pendingTransfers[uid];
        delete requestTimestamps[uid];

        emit CardRequestRejected(uid, buyer);
    }
    function getCardInfo(
        uint256 tokenId
    )
        external
        view
        returns (
            string memory idolGroup,
            string memory member,
            string memory cardNumber,
            uint256 listPrice,
            string memory photoURI
        )
    {
        CardInfo memory info = tokenIdToCardInfo[tokenId];
        return (
            info.idolGroup,
            info.member,
            info.cardNumber,
            info.listPrice,
            info.photoURI
        );
    }
    function getCompanyCards() external view returns (CardDisplay[] memory) {
        uint256 count = allCardUIDs.length;
        CardDisplay[] memory cards = new CardDisplay[](count);

        for (uint256 i = 0; i < count; i++) {
            string memory uid = allCardUIDs[i];
            CardInfo memory info = uidToCardInfo[uid];
            bool isSold = uidUsed[uid];

            cards[i] = CardDisplay({
                uid: uid,
                idolGroup: info.idolGroup,
                member: info.member,
                cardNumber: info.cardNumber,
                listPrice: info.listPrice,
                photoURI: info.photoURI,
                isSold: isSold
            });
        }

        return cards;
    }
    // 2. 獲取所有可購買的卡片
    function getAvailableCards() external view returns (CardDisplay[] memory) {
        uint256 availableCount = 0;

        for (uint256 i = 0; i < allCardUIDs.length; i++) {
            string memory uid = allCardUIDs[i];
            uint256 tokenId = uidToTokenId[uid];
            // 如果還沒鑄造 NFT (tokenId == 0)，該卡可買
            if (tokenId == 0) {
                availableCount++;
            }
        }

        CardDisplay[] memory availableCards = new CardDisplay[](availableCount);
        uint256 index = 0;

        for (uint256 i = 0; i < allCardUIDs.length; i++) {
            string memory uid = allCardUIDs[i];
            uint256 tokenId = uidToTokenId[uid];
            if (tokenId == 0) {
                CardInfo memory info = uidToCardInfo[uid];
                availableCards[index] = CardDisplay({
                    uid: uid,
                    idolGroup: info.idolGroup,
                    member: info.member,
                    cardNumber: info.cardNumber,
                    listPrice: info.listPrice,
                    photoURI: info.photoURI,
                    isSold: false
                });
                index++;
            }
        }
        return availableCards;
    }

    // 3. 購買特定卡片並返回UID
    function purchaseSpecificCard(
        string memory uid,
        address recipient
    ) external payable returns (string memory) {
        require(!uidUsed[uid], "Card already sold");
        require(cardUIDUsed[uid], "Card does not exist");

        CardInfo memory info = uidToCardInfo[uid];
        require(msg.value == info.listPrice, "Incorrect payment amount");

        // 使用呼叫者傳入的recipient作為NFT接收地址
        uint256 tokenId = nextTokenId;

        _safeMint(recipient, tokenId);

        if (bytes(info.photoURI).length > 0) {
            _setTokenURI(tokenId, info.photoURI);
        }

        tokenIdToCardInfo[tokenId] = info;

        uidToTokenId[uid] = tokenId;
        tokenIdToUID[tokenId] = uid; // 直接記錄 UID，完成綁定
        phase[tokenId] = 3; // 已購買已綁定階段
        uidUsed[uid] = true; // 設為已綁定，防止重複使用

        nextTokenId++;

        // 轉ETH給owner
        payable(owner()).transfer(msg.value);

        emit CardPurchased(recipient, msg.value, uid);
        emit CardApproved(uid, recipient, tokenId);

        return uid;
    }

    // 4. 獲取待處理的卡片綁定請求
    struct PendingRequest {
        string uid;
        address buyer;
        uint256 amount;
        uint256 timestamp;
    }

    function getPendingCardRequests()
        external
        view
        returns (PendingRequest[] memory)
    {
        uint256 pendingCount = 0;

        // 計算待處理請求數量
        for (uint256 i = 0; i < allCardUIDs.length; i++) {
            string memory uid = allCardUIDs[i];
            if (
                pendingTransfers[uid].buyer != address(0) &&
                !pendingTransfers[uid].approved &&
                !uidUsed[uid]
            ) {
                pendingCount++;
            }
        }

        PendingRequest[] memory requests = new PendingRequest[](pendingCount);
        uint256 index = 0;

        for (uint256 i = 0; i < allCardUIDs.length; i++) {
            string memory uid = allCardUIDs[i];
            if (
                pendingTransfers[uid].buyer != address(0) &&
                !pendingTransfers[uid].approved &&
                !uidUsed[uid]
            ) {
                requests[index] = PendingRequest({
                    uid: uid,
                    buyer: pendingTransfers[uid].buyer,
                    amount: pendingTransfers[uid].amount,
                    timestamp: requestTimestamps[uid]
                });

                index++;
            }
        }

        return requests;
    }
    // 6. 獲取用戶擁有的卡片
    function getUserCards(
        address user
    ) external view returns (CardDisplay[] memory) {
        uint256 balance = balanceOf(user);
        CardDisplay[] memory userCards = new CardDisplay[](balance);

        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(user, i);
            string memory uid = tokenIdToUID[tokenId];
            CardInfo memory info = tokenIdToCardInfo[tokenId];

            userCards[i] = CardDisplay({
                uid: uid,
                idolGroup: info.idolGroup,
                member: info.member,
                cardNumber: info.cardNumber,
                listPrice: info.listPrice,
                photoURI: info.photoURI,
                isSold: true
            });
        }

        return userCards;
    }

    // 新增7.用戶自己綁定UID，成功後phase變3且uidUsed設定true
    function bindUID(string memory uid, address recipient) external {
        require(!uidUsed[uid], "UID already bound");

        uint256 tokenId = uidToTokenId[uid];
        require(tokenId != 0, "Token not minted yet");
        require(ownerOf(tokenId) == recipient, "Not token owner");
        require(phase[tokenId] == 2, "Token not in bindable phase");

        uidUsed[uid] = true;
        tokenIdToUID[tokenId] = uid;
        phase[tokenId] = 3; // 設為已購買已綁定
    }
    //二手交易
    function listCardForResale(
        string memory uid,
        uint256 resalePrice
    ) external {
        require(!isResaleListed[uid], "Already listed");

        CardInfo storage card = uidToCardInfo[uid];

        require(bytes(card.idolGroup).length > 0, "Card info missing");
        require(card.listPrice > 0, "Invalid card");

        // 更新卡片價格
        card.listPrice = resalePrice;

        resaleCardUIDs.push(uid);
        isResaleListed[uid] = true;
    }
    function getResaleCards() external view returns (CardDisplay[] memory) {
        uint256 count = 0;

        // Count listed cards
        for (uint256 i = 0; i < resaleCardUIDs.length; i++) {
            if (isResaleListed[resaleCardUIDs[i]]) {
                count++;
            }
        }

        CardDisplay[] memory cards = new CardDisplay[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < resaleCardUIDs.length; i++) {
            string memory uid = resaleCardUIDs[i];
            if (isResaleListed[uid]) {
                uint256 tokenId = uidToTokenId[uid];
                CardInfo memory info = tokenIdToCardInfo[tokenId]; 
                cards[index] = CardDisplay({
                    uid: uid,
                    idolGroup: info.idolGroup,
                    member: info.member,
                    cardNumber: info.cardNumber,
                    listPrice: info.listPrice,
                    photoURI: info.photoURI,
                    isSold: false // 二手交易的卡片不再是已售出狀態
                });
                index++;
            }
        }

        return cards;
    }

    function getNFTHolder(string memory uid) external view returns (address) {
        uint256 tokenId = uidToTokenId[uid];
        require(tokenId != 0, "Token does not exist");
        return ownerOf(tokenId); // 返回當前的持有者
    }

    // 二手交易購買功能
    function purchaseResaleCard(
        string memory uid,
        address recipient
    ) external payable {
        require(isResaleListed[uid], "Card not for resale");

        uint256 tokenId = uidToTokenId[uid];
        address seller = ownerOf(tokenId); // 原持有者
        uint256 price = uidToCardInfo[uid].listPrice;

        require(msg.value == price, "Incorrect payment");

        // 安全轉移NFT
        _transfer(seller, recipient, tokenId);

        // 付款給賣家
        payable(seller).transfer(price);

        // 將卡片從二手市場移除
        isResaleListed[uid] = false;

        // 移除對應的 UID 條目
        for (uint256 i = 0; i < resaleCardUIDs.length; i++) {
            if (
                keccak256(abi.encodePacked(resaleCardUIDs[i])) ==
                keccak256(abi.encodePacked(uid))
            ) {
                // 刪除條目，將後面的項目前移
                resaleCardUIDs[i] = resaleCardUIDs[resaleCardUIDs.length - 1];
                resaleCardUIDs.pop();
                break;
            }
        }

        emit CardPurchased(recipient, price, uid);
    }
}
