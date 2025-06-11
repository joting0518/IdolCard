// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../base/NFTBase.sol";

contract TradeManager is NFTBase {
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

    enum TradeStatus {
        Created,
        BuyerSigned,
        SellerSigned,
        RefundRequested,
        Refunded,
        Completed
    }

    struct Trade {
        uint256 tradeId;
        uint256 tokenId;
        address payable seller;
        address payable buyer;
        uint256 price;
        uint256 timestamp;
        TradeStatus status;
    }

    uint256 public tradeCounter;
    mapping(uint256 => Trade) public trades;
    mapping(uint256 => uint256) public tokenToTrade;
    mapping(string => uint256) public uidToTokenId;
    mapping(string => uint256[]) internal uidToTradeIds;

    event TradeCreated(uint256 tradeId, uint256 tokenId, address seller, uint256 price);
    event BuyerSigned(uint256 tradeId, address buyer);
    event SellerSigned(uint256 tradeId);
    event RefundRequested(uint256 tradeId);
    event Refunded(uint256 tradeId);
    event TradeCompleted(uint256 tradeId);

    // 創建新的交易訂單，將NFT上架銷售
    function createTrade(string memory uid, uint256 price) external {
        require(uidUsed[uid], "UID not bound");
        uint256 tokenId = uidToTokenId[uid];
        require(ownerOf(tokenId) == msg.sender, "You are not the owner");

        uint256 tradeId = ++tradeCounter;
        trades[tradeId] = Trade({
            tradeId: tradeId,
            tokenId: tokenId,
            seller: payable(msg.sender),
            buyer: payable(address(0)),
            price: price,
            timestamp: 0,
            status: TradeStatus.Created
        });

        tokenToTrade[tokenId] = tradeId;
        uidToTokenId[uid] = tokenId;
        emit TradeCreated(tradeId, tokenId, msg.sender, price);
    }

    // 設定UID的使用狀態
    function setUidUsed(
        string memory uid,
        bool used
    ) external onlyOwnerOrMainContract {
        uidUsed[uid] = used;
    }

    // 買家支付ETH並簽署購買意願
    function buyerSign(uint256 tradeId) external payable {
        Trade storage t = trades[tradeId];
        require(t.status == TradeStatus.Created, "Trade not available");
        require(msg.value == t.price, "Incorrect ETH");

        t.buyer = payable(msg.sender);
        t.status = TradeStatus.BuyerSigned;
        t.timestamp = block.timestamp;

        emit BuyerSigned(tradeId, msg.sender);
    }

    // 賣家確認交易並轉移NFT給買家
    function sellerSign(uint256 tradeId) external {
        Trade storage t = trades[tradeId];
        require(msg.sender == t.seller, "Only seller");
        require(t.status == TradeStatus.BuyerSigned, "Buyer not signed");

        safeTransferFrom(address(this), t.buyer, t.tokenId);
        t.status = TradeStatus.SellerSigned;

        emit SellerSigned(tradeId);
    }

    // 買家申請退款
    function requestRefund(uint256 tradeId) external {
        Trade storage t = trades[tradeId];
        require(msg.sender == t.buyer, "Only buyer");
        require(t.status == TradeStatus.SellerSigned, "Not refundable");

        t.status = TradeStatus.RefundRequested;
        emit RefundRequested(tradeId);
    }

    // 賣家確認退款並收回NFT
    function confirmRefund(uint256 tradeId) external {
        Trade storage t = trades[tradeId];
        require(msg.sender == t.seller, "Only seller");
        require(t.status == TradeStatus.RefundRequested, "No refund requested");

        safeTransferFrom(t.buyer, t.seller, t.tokenId);
        t.buyer.transfer(t.price);
        t.status = TradeStatus.Refunded;

        emit Refunded(tradeId);
    }

    // 完成交易，將ETH轉給賣家
    function finalize(uint256 tradeId) external {
        Trade storage t = trades[tradeId];
        require(
            msg.sender == t.buyer || block.timestamp >= t.timestamp + 3 days,
            "Only buyer or after 72h"
        );
        require(t.status == TradeStatus.SellerSigned, "Not finalized");

        t.seller.transfer(t.price);
        t.status = TradeStatus.Completed;

        emit TradeCompleted(tradeId);
    }

    // 獲取指定用戶相關的所有交易記錄
    function getUserTrades(
        address user
    ) external view returns (Trade[] memory) {
        uint256 count = 0;
        for (uint256 i = 1; i <= tradeCounter; i++) {
            if (trades[i].seller == user || trades[i].buyer == user) count++;
        }

        Trade[] memory result = new Trade[](count);
        uint256 index = 0;
        for (uint256 i = 1; i <= tradeCounter; i++) {
            if (trades[i].seller == user || trades[i].buyer == user) {
                result[index++] = trades[i];
            }
        }
        return result;
    }

    // 獲取交易統計數據（總數、完成數、進行中、總交易額）
    function getTradeAnalytics()
        external
        view
        onlyOwnerOrMainContract
        returns (
            uint256 totalTrades,
            uint256 completedTrades,
            uint256 pendingTrades,
            uint256 totalVolume
        )
    {
        uint256 _completed = 0;
        uint256 _pending = 0;
        uint256 _volume = 0;

        for (uint256 i = 1; i <= tradeCounter; i++) {
            Trade memory t = trades[i];
            if (t.status == TradeStatus.Completed) {
                _completed++;
                _volume += t.price;
            } else if (
                t.status == TradeStatus.Created ||
                t.status == TradeStatus.BuyerSigned ||
                t.status == TradeStatus.SellerSigned
            ) {
                _pending++;
            }
        }

        return (tradeCounter, _completed, _pending, _volume);
    }

    // 獲取所有可購買的交易訂單
    function getAvailableTrades() external view returns (Trade[] memory) {
        uint count = 0;
        for (uint i = 1; i <= tradeCounter; i++) {
            if (trades[i].status == TradeStatus.Created) count++;
        }

        Trade[] memory result = new Trade[](count);
        uint index = 0;
        for (uint i = 1; i <= tradeCounter; i++) {
            if (trades[i].status == TradeStatus.Created) {
                result[index++] = trades[i];
            }
        }
        return result;
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
            TradeStatus status,
            uint256 deadline
        )
    {
        Trade memory t = trades[tradeId];
        return (
            t.tokenId,
            t.seller,
            t.buyer,
            t.price,
            t.status,
            t.timestamp + 3 days
        );
    }

    // 記錄一手交易（公司銷售給用戶）
    function recordPrimaryTrade(
        string memory uid,
        uint256 tokenId,
        address buyer,
        uint256 price
    ) external {
        uint256 tradeId = ++tradeCounter;

        trades[tradeId] = Trade({
            tradeId: tradeId,
            tokenId: tokenId,
            seller: payable(owner()),
            buyer: payable(buyer),
            price: price,
            timestamp: block.timestamp,
            status: TradeStatus.Completed
        });

        tokenToTrade[tokenId] = tradeId;
        uidToTokenId[uid] = tokenId;
        uidUsed[uid] = true;
        uidToTradeIds[uid].push(tradeId);

        emit TradeCompleted(tradeId);
    }

    // 記錄二手交易（用戶之間的交易）
    function recordSecondaryTrade(
        string memory uid,
        uint256 tokenId,
        address seller,
        address buyer,
        uint256 price
    ) external {
        uint256 tradeId = ++tradeCounter;

        trades[tradeId] = Trade({
            tradeId: tradeId,
            tokenId: tokenId,
            seller: payable(seller), 
            buyer: payable(buyer),
            price: price,
            timestamp: block.timestamp,
            status: TradeStatus.Completed
        });

        tokenToTrade[tokenId] = tradeId;
        uidToTokenId[uid] = tokenId;
        uidUsed[uid] = true;
        uidToTradeIds[uid].push(tradeId);

        emit TradeCompleted(tradeId);
    }

    // 獲取指定UID的所有交易歷史記錄
    function getTradesByUID(
        string memory uid
    ) public view returns (Trade[] memory) {
        uint256[] memory ids = uidToTradeIds[uid];
        if (ids.length == 0) {
            return new Trade[](0);
        }

        Trade[] memory result = new Trade[](ids.length);

        for (uint256 i = 0; i < ids.length; i++) {
            result[i] = trades[ids[i]];
        }

        return result;
    }

    // 設定UID對應的TokenID
    function setUidToTokenId(
        string memory uid,
        uint256 tokenId
    ) external onlyOwnerOrMainContract {
        uidToTokenId[uid] = tokenId;
    }
}