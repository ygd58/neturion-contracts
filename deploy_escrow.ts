import { createWalletClient, createPublicClient, http } from "viem"
import { privateKeyToAccount } from "viem/accounts"
import { readFileSync } from "fs"

const ARC = {
  id: 5042002,
  name: "Arc Testnet",
  nativeCurrency: { name: "USDC", symbol: "USDC", decimals: 18 },
  rpcUrls: { default: { http: ["https://rpc.testnet.arc.network"] } },
} as const

const account = privateKeyToAccount("0xcc5605712d06d025229c6d26e6f982fbff4d7fd063a436e7f21d9a1d58a4ce6c")
const publicClient = createPublicClient({ chain: ARC, transport: http() })
const walletClient = createWalletClient({ account, chain: ARC, transport: http() })

const artifact = JSON.parse(readFileSync("artifacts/contracts/NeturionEscrow.sol/NeturionEscrow.json", "utf8"))

const USDC = "0x3600000000000000000000000000000000000000"
const PLATFORM = account.address

async function main() {
  console.log("Deploying NeturionEscrow...")
  console.log("Deployer:", account.address)
  console.log("USDC:", USDC)
  console.log("Platform:", PLATFORM)

  const hash = await walletClient.deployContract({
    abi: artifact.abi,
    bytecode: artifact.bytecode,
    args: [USDC, PLATFORM],
  })

  console.log("TX:", hash)
  const receipt = await publicClient.waitForTransactionReceipt({ hash })
  console.log("NeturionEscrow deployed at:", receipt.contractAddress)
  console.log("Block:", receipt.blockNumber.toString())
}

main().catch(console.error)
