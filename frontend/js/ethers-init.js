// js/ethers-init.js
export let contract, signer, provider, userAddress;

export async function initEthers(contractABI, contractAddress) {
  if (!window.ethereum) {
    throw new Error("請安裝 MetaMask");
  }

  await window.ethereum.request({ method: "eth_requestAccounts" });

  provider = new ethers.providers.Web3Provider(window.ethereum);
  signer = provider.getSigner();
  userAddress = await signer.getAddress();
  contract = new ethers.Contract(contractAddress, contractABI, signer);

  return { provider, signer, contract, userAddress };
}
