"use client";

import { useState } from "react";
import { openContractCall, showConnect } from "@stacks/connect";
import { STACKS_MAINNET } from "@stacks/network";
import { AnchorMode, PostConditionMode, principalCV, uintCV } from "@stacks/transactions";

const CONTRACT_ADDRESS = "SP3E0DQAHTXJHH5YT9TZCSBW013YXZB25QFDVXXWY";
const CONTRACT_NAME = "multisig";

export default function Multisig() {
  const [address, setAddress] = useState<string | null>(null);
  const [txId, setTxId] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [recipient, setRecipient] = useState("");
  const [amount, setAmount] = useState("");
  const [signTxId, setSignTxId] = useState("");

  const connectWallet = () => {
    showConnect({
      appDetails: { name: "Stacks Multisig", icon: "/logo.png" },
      onFinish: () => {
        const userData = JSON.parse(localStorage.getItem("blockstack-session") || "{}");
        setAddress(userData?.userData?.profile?.stxAddress?.mainnet || null);
      },
      userSession: undefined,
    });
  };

  const submitTx = async () => {
    if (!recipient || !amount) return;
    setLoading(true);
    try {
      await openContractCall({
        network: STACKS_MAINNET,
        anchorMode: AnchorMode.Any,
        contractAddress: CONTRACT_ADDRESS,
        contractName: CONTRACT_NAME,
        functionName: "submit-transaction",
        functionArgs: [principalCV(recipient), uintCV(Math.floor(Number(amount) * 1000000))],
        postConditionMode: PostConditionMode.Allow,
        onFinish: (data) => {
          setTxId(data.txId);
          setLoading(false);
        },
        onCancel: () => setLoading(false),
      });
    } catch (error) {
      console.error(error);
      setLoading(false);
    }
  };

  const signTransaction = async () => {
    if (!signTxId) return;
    setLoading(true);
    try {
      await openContractCall({
        network: STACKS_MAINNET,
        anchorMode: AnchorMode.Any,
        contractAddress: CONTRACT_ADDRESS,
        contractName: CONTRACT_NAME,
        functionName: "sign-transaction",
        functionArgs: [uintCV(parseInt(signTxId))],
        postConditionMode: PostConditionMode.Allow,
        onFinish: (data) => {
          setTxId(data.txId);
          setLoading(false);
        },
        onCancel: () => setLoading(false),
      });
    } catch (error) {
      console.error(error);
      setLoading(false);
    }
  };

  return (
    <main className="min-h-screen bg-gradient-to-br from-gray-800 to-gray-900 text-white p-8">
      <div className="max-w-xl mx-auto">
        <h1 className="text-4xl font-bold mb-2 text-center">🔐 Multisig Wallet</h1>
        <p className="text-center text-gray-400 mb-8">Secure multi-signature transactions on Stacks</p>

        {!address ? (
          <button onClick={connectWallet} className="w-full bg-blue-600 hover:bg-blue-700 py-3 rounded-lg font-semibold">
            Connect Wallet
          </button>
        ) : (
          <div className="space-y-6">
            <div className="bg-white/10 p-4 rounded-lg">
              <p className="text-sm text-gray-400">Connected</p>
              <p className="font-mono">{address.slice(0, 12)}...{address.slice(-6)}</p>
            </div>

            <div className="bg-white/10 p-6 rounded-lg space-y-4">
              <h2 className="text-xl font-bold">Submit Transaction</h2>
              <input
                type="text"
                value={recipient}
                onChange={(e) => setRecipient(e.target.value)}
                placeholder="Recipient address"
                className="w-full bg-white/10 border border-white/20 rounded px-4 py-2"
              />
              <input
                type="number"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                placeholder="Amount (STX)"
                className="w-full bg-white/10 border border-white/20 rounded px-4 py-2"
              />
              <button
                onClick={submitTx}
                disabled={loading}
                className="w-full bg-green-600 hover:bg-green-700 py-3 rounded-lg disabled:opacity-50"
              >
                {loading ? "Submitting..." : "Submit Transaction"}
              </button>
            </div>

            <div className="bg-white/10 p-6 rounded-lg space-y-4">
              <h2 className="text-xl font-bold">Sign Transaction</h2>
              <input
                type="number"
                value={signTxId}
                onChange={(e) => setSignTxId(e.target.value)}
                placeholder="Transaction ID"
                className="w-full bg-white/10 border border-white/20 rounded px-4 py-2"
              />
              <button
                onClick={signTransaction}
                disabled={loading}
                className="w-full bg-purple-600 hover:bg-purple-700 py-3 rounded-lg disabled:opacity-50"
              >
                {loading ? "Signing..." : "Sign Transaction"}
              </button>
            </div>

            {txId && (
              <div className="bg-green-500/20 border border-green-500 p-4 rounded-lg">
                <p className="font-semibold">Transaction Submitted!</p>
                <a href={`https://explorer.hiro.so/txid/${txId}?chain=mainnet`} target="_blank" className="text-blue-400 underline text-sm break-all">
                  {txId}
                </a>
              </div>
            )}
          </div>
        )}
      </div>
    </main>
  );
}
