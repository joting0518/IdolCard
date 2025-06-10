

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
    uint8 status; // enum 用 uint8 替代，方便 interface 使用
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
    function modifyResaleStatus(string memory uid) external;
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

    // 卡片相關功能轉發
    function getCompanyCards() external view returns (CardDisplay[] memory) {
        return cardManager.getCompanyCards();
    }

    function getAvailableCards() external view returns (CardDisplay[] memory) {
        return cardManager.getAvailableCards();
    }

    function getPendingCardRequests()
        external
        view
        returns (PendingRequest[] memory)
    {
        return cardManager.getPendingCardRequests();
    }

    function getUserCards(
        address user
    ) external view returns (CardDisplay[] memory) {
        return cardManager.getUserCards(user);
    }

    function purchaseSpecificCard(
        string memory uid,
        address recipient
    ) external payable returns (string memory) {
        return
            cardManager.purchaseSpecificCard{value: msg.value}(uid, recipient);
    }

    function bindCardUID(string memory uid, address recipient) external {
        cardManager.bindUID(uid, recipient);
    }

    function getCardPrice() external view returns (uint256) {
        return cardManager.getCardPrice();
    }

    function requestCard(string memory uid, address recipient) external {
        cardManager.requestCard(uid, recipient);
    }

    function approveTransfer(string memory uid) external onlyOwner {
        cardManager.approveTransfer(uid);
    }

    function rejectTransfer(string memory uid) external onlyOwner {
        cardManager.rejectTransfer(uid);
    }

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

    // 交易相關功能轉發
    function createTrade(string memory uid, uint256 price) external {
        tradeManager.createTrade(uid, price);
    }

    function buyerSignTrade(uint256 tradeId) external payable {
        tradeManager.buyerSign{value: msg.value}(tradeId);
    }

    function sellerSignTrade(uint256 tradeId) external {
        tradeManager.sellerSign(tradeId);
    }

    function finalizeTrade(uint256 tradeId) external {
        tradeManager.finalize(tradeId);
    }

    function getUserTrades(
        address user
    ) external view returns (Trade[] memory) {
        return tradeManager.getUserTrades(user);
    }

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

    function getAvailableTrades() external view returns (Trade[] memory) {
        return tradeManager.getAvailableTrades();
    }

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

    function getTradesByUID(
        string memory uid
    ) public view returns (Trade[] memory) {
        return tradeManager.getTradesByUID(uid);
    }

    // 新增：調用 recordSecondaryTrade
    function recordSecondaryTrade(
        string memory uid,
        uint256 tokenId,
        address seller,
        address buyer,
        uint256 price
    ) external {
        tradeManager.recordSecondaryTrade(uid, tokenId, seller, buyer, price);
    }

    function recordPrimaryTrade(
        string memory uid,
        uint256 tokenId,
        address buyer,
        uint256 price
    ) external {
        return tradeManager.recordPrimaryTrade(uid, tokenId, buyer, price);
    }

    function setUidToTokenId(string memory uid, uint256 tokenId) external {
        return tradeManager.setUidToTokenId(uid, tokenId);
    }

    function uidToTokenId(string memory uid) external view returns (uint256) {
        return tradeManager.uidToTokenId(uid);
    }

    function listCardForResale(string memory uid, uint256 price) external {
        cardManager.listCardForResale(uid, price);
    }

    function purchaseResaleCard(
        string memory uid,
        address recipient
    ) external payable {
        cardManager.purchaseResaleCard{value: msg.value}(uid, recipient);
    }

    function getNFTHolder(string memory uid) external view returns (address) {
        return cardManager.getNFTHolder(uid);
    }
    
    function getResaleCards() external view returns (CardDisplay[] memory) {
        return cardManager.getResaleCards();
    }

    function cancelResale(string memory uid) external {
        cardManager.cancelResale(uid);
    }

}

