// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 定義回傳用的結構體
struct CardDisplay {
    string uid;
    string idolGroup;
    string member;
    string cardNumber;
    uint256 listPrice;
    string photoURI;
    bool isSold;
}

struct PendingRequest {
    string uid;
    address buyer;
    uint256 amount;
    uint256 timestamp;
}

struct Trade {
    uint256 tradeId;
    uint256 tokenId;
    address seller;
    address buyer;
    uint256 price;
    uint256 timestamp;
    uint8 status; 
}

// CardManager 介面
interface ICardManager {
    function getCompanyCards() external view returns (CardDisplay[] memory);
    function getAvailableCards() external view returns (CardDisplay[] memory);
    function getPendingCardRequests()
        external
        view
        returns (PendingRequest[] memory);
    function getUserCards(
        address user
    ) external view returns (CardDisplay[] memory);

    function purchaseSpecificCard(
        string memory uid,
        address recipient
    ) external payable returns (string memory);
    function bindUID(string memory uid, address recipient) external;
    function getCardPrice() external view returns (uint256);
    function requestCard(string memory uid, address recipient) external;
    function approveTransfer(string memory uid) external;
    function rejectTransfer(string memory uid) external;
    function setCardPrice(
        uint256 newPrice,
        string memory idolGroup,
        string memory member,
        string memory cardNumber,
        uint256 listPrice,
        string memory photoURI,
        uint256 amount
    ) external returns (string memory);
    function listCardForResale(string memory uid, uint256 price) external;
    function getResaleCards() external view returns (CardDisplay[] memory);
    function getNFTHolder(string memory uid) external view returns (address);
    function purchaseResaleCard(
        string memory uid,
        address recipient
    ) external payable;
    function cancelResale(string memory uid) external;
}

// TradeManager 介面
interface ITradeManager {
    function createTrade(string memory uid, uint256 price) external;
    function buyerSign(uint256 tradeId) external payable;
    function sellerSign(uint256 tradeId) external;
    function finalize(uint256 tradeId) external;

    function getUserTrades(address user) external view returns (Trade[] memory);
    function getTradeAnalytics()
        external
        view
        returns (
            uint256 totalTrades,
            uint256 completedTrades,
            uint256 pendingTrades,
            uint256 totalVolume
        );
    function getAvailableTrades() external view returns (Trade[] memory);
    function getTrade(
        uint256 tradeId
    )
        external
        view
        returns (
            uint256 tokenId,
            address seller,
            address buyer,
            uint256 price,
            uint8 status,
            uint256 deadline
        );
    function getTradesByUID(
        string memory uid
    ) external view returns (Trade[] memory);
    function recordPrimaryTrade(
        string memory uid,
        uint256 tokenId,
        address buyer,
        uint256 price
    ) external;
    function recordSecondaryTrade(
        string memory uid,
        uint256 tokenId,
        address seller,
        address buyer,
        uint256 price
    ) external;
    function setUidToTokenId(string memory uid, uint256 tokenId) external;
    function uidToTokenId(string memory uid) external view returns (uint256);
}

// 主合約：IdolCardSystem.sol
contract IdolCardSystem {
    ICardManager public cardManager;
    ITradeManager public tradeManager;
    address public owner;

    constructor(address _cardManager, address _tradeManager) {
        cardManager = ICardManager(_cardManager);
        tradeManager = ITradeManager(_tradeManager);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    // 獲取公司發行的所有卡片清單
    function getCompanyCards() external view returns (CardDisplay[] memory) {
        return cardManager.getCompanyCards();
    }

    // 獲取所有可購買的一手卡片
    function getAvailableCards() external view returns (CardDisplay[] memory) {
        return cardManager.getAvailableCards();
    }

    // 獲取所有待審批的卡片綁定請求
    function getPendingCardRequests()
        external
        view
        returns (PendingRequest[] memory)
    {
        return cardManager.getPendingCardRequests();
    }

    // 獲取指定用戶擁有的所有卡片
    function getUserCards(
        address user
    ) external view returns (CardDisplay[] memory) {
        return cardManager.getUserCards(user);
    }

    // 購買指定UID的一手卡片
    function purchaseSpecificCard(
        string memory uid,
        address recipient
    ) external payable returns (string memory) {
        return
            cardManager.purchaseSpecificCard{value: msg.value}(uid, recipient);
    }

    // 綁定實體卡片UID到數位NFT
    function bindCardUID(string memory uid, address recipient) external {
        cardManager.bindUID(uid, recipient);
    }

    // 獲取當前卡片價格
    function getCardPrice() external view returns (uint256) {
        return cardManager.getCardPrice();
    }

    // 申請卡片綁定請求
    function requestCard(string memory uid, address recipient) external {
        cardManager.requestCard(uid, recipient);
    }

    // 管理員審批卡片綁定請求
    function approveTransfer(string memory uid) external onlyOwner {
        cardManager.approveTransfer(uid);
    }

    // 管理員拒絕卡片綁定請求
    function rejectTransfer(string memory uid) external onlyOwner {
        cardManager.rejectTransfer(uid);
    }

    // 設定卡片價格並批量發行卡片
    function setCardPrice(
        uint256 newPrice,
        string memory idolGroup,
        string memory member,
        string memory cardNumber,
        uint256 listPrice,
        string memory photoURI,
        uint256 amount
    ) external onlyOwner returns (string memory) {
        return
            cardManager.setCardPrice(
                newPrice,
                idolGroup,
                member,
                cardNumber,
                listPrice,
                photoURI,
                amount
            );
    }

    // 創建新的交易訂單
    function createTrade(string memory uid, uint256 price) external {
        tradeManager.createTrade(uid, price);
    }

    // 買家支付並簽署交易
    function buyerSignTrade(uint256 tradeId) external payable {
        tradeManager.buyerSign{value: msg.value}(tradeId);
    }

    // 賣家確認並轉移NFT
    function sellerSignTrade(uint256 tradeId) external {
        tradeManager.sellerSign(tradeId);
    }

    // 完成交易並釋放資金
    function finalizeTrade(uint256 tradeId) external {
        tradeManager.finalize(tradeId);
    }

    // 獲取用戶的所有交易記錄
    function getUserTrades(
        address user
    ) external view returns (Trade[] memory) {
        return tradeManager.getUserTrades(user);
    }

    // 獲取交易統計數據
    function getTradeAnalytics()
        external
        view
        returns (
            uint256 totalTrades,
            uint256 completedTrades,
            uint256 pendingTrades,
            uint256 totalVolume
        )
    {
        return tradeManager.getTradeAnalytics();
    }

    // 獲取所有可購買的交易訂單
    function getAvailableTrades() external view returns (Trade[] memory) {
        return tradeManager.getAvailableTrades();
    }

    // 獲取指定交易的詳細資訊
    function getTrade(
        uint256 tradeId
    )
        external
        view
        returns (
            uint256 tokenId,
            address seller,
            address buyer,
            uint256 price,
            uint8 status,
            uint256 deadline
        )
    {
        return tradeManager.getTrade(tradeId);
    }

    // 獲取指定UID的所有交易歷史
    function getTradesByUID(
        string memory uid
    ) public view returns (Trade[] memory) {
        return tradeManager.getTradesByUID(uid);
    }

    // 記錄二手交易到TradeManager
    function recordSecondaryTrade(
        string memory uid,
        uint256 tokenId,
        address seller,
        address buyer,
        uint256 price
    ) external {
        tradeManager.recordSecondaryTrade(uid, tokenId, seller, buyer, price);
    }

    // 記錄一手交易到TradeManager
    function recordPrimaryTrade(
        string memory uid,
        uint256 tokenId,
        address buyer,
        uint256 price
    ) external {
        return tradeManager.recordPrimaryTrade(uid, tokenId, buyer, price);
    }

    // 設定UID對應的TokenID
    function setUidToTokenId(string memory uid, uint256 tokenId) external {
        return tradeManager.setUidToTokenId(uid, tokenId);
    }

    // 獲取UID對應的TokenID
    function uidToTokenId(string memory uid) external view returns (uint256) {
        return tradeManager.uidToTokenId(uid);
    }

    // 將卡片上架到二手市場
    function listCardForResale(string memory uid, uint256 price) external {
        cardManager.listCardForResale(uid, price);
    }

    // 購買二手市場的卡片
    function purchaseResaleCard(
        string memory uid,
        address recipient
    ) external payable {
        cardManager.purchaseResaleCard{value: msg.value}(uid, recipient);
    }

    // 獲取指定UID卡片的當前持有者
    function getNFTHolder(string memory uid) external view returns (address) {
        return cardManager.getNFTHolder(uid);
    }
    
    // 獲取二手市場上架的所有卡片
    function getResaleCards() external view returns (CardDisplay[] memory) {
        return cardManager.getResaleCards();
    }

    // 取消二手市場上架
    function cancelResale(string memory uid) external {
        cardManager.cancelResale(uid);
    }
}