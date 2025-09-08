import { useState } from 'react';
import Head from 'next/head';
import Link from 'next/link';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { useAccount, useContractRead } from 'wagmi';
import { PlusIcon, CopyIcon, TrendingUpIcon, ActivityIcon } from 'lucide-react';

import Layout from '@/components/Layout';
import VaultCard from '@/components/VaultCard';
import LoadingSpinner from '@/components/LoadingSpinner';
import { CONTRACT_ADDRESSES, VAULT_FACTORY_ABI } from '@/lib/contracts';

const VAULTS_PER_PAGE = 12;

export default function Home() {
  const { isConnected } = useAccount();
  const [currentPage, setCurrentPage] = useState(0);

  // Fetch vaults with pagination
  const { data: vaultData, isLoading } = useContractRead({
    address: CONTRACT_ADDRESSES.VAULT_FACTORY,
    abi: VAULT_FACTORY_ABI,
    functionName: 'getVaultsPaginated',
    args: [BigInt(currentPage * VAULTS_PER_PAGE), BigInt(VAULTS_PER_PAGE)],
    enabled: isConnected && CONTRACT_ADDRESSES.VAULT_FACTORY !== '0x',
    watch: true,
  });

  const vaults = vaultData?.[0] || [];
  const totalVaults = Number(vaultData?.[1] || 0);
  const totalPages = Math.ceil(totalVaults / VAULTS_PER_PAGE);

  return (
    <>
      <Head>
        <title>Micro-DCA Vault | Automated Dollar-Cost Averaging</title>
        <meta
          name="description"
          content="Create and copy automated DCA strategies on Somnia. Social trading meets decentralized finance."
        />
      </Head>

      <Layout>
        {/* Hero Section */}
        <div className="text-center py-12 px-4">
          <h1 className="text-4xl md:text-6xl font-bold mb-6 bg-gradient-to-r from-primary-400 to-purple-400 bg-clip-text text-transparent">
            Micro-DCA Vault
          </h1>
          <p className="text-xl text-gray-300 mb-8 max-w-3xl mx-auto">
            Automate your dollar-cost averaging strategy on Somnia. Create vaults that execute tiny periodic swaps, 
            or copy successful strategies from other traders.
          </p>

          <div className="flex flex-col sm:flex-row gap-4 justify-center items-center">
            {isConnected ? (
              <>
                <Link href="/create" className="btn-primary flex items-center gap-2">
                  <PlusIcon className="w-5 h-5" />
                  Create Vault
                </Link>
                <Link href="/portfolio" className="btn-secondary flex items-center gap-2">
                  <ActivityIcon className="w-5 h-5" />
                  My Portfolio
                </Link>
              </>
            ) : (
              <div className="flex flex-col items-center gap-4">
                <ConnectButton />
                <p className="text-sm text-gray-400">Connect your wallet to get started</p>
              </div>
            )}
          </div>
        </div>

        {/* Stats Section */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-12">
          <div className="card text-center">
            <div className="text-3xl font-bold text-primary-400 mb-2">
              {totalVaults.toLocaleString()}
            </div>
            <div className="text-gray-300">Total Vaults</div>
          </div>
          <div className="card text-center">
            <div className="text-3xl font-bold text-green-400 mb-2">$2.1M</div>
            <div className="text-gray-300">Total Volume</div>
          </div>
          <div className="card text-center">
            <div className="text-3xl font-bold text-yellow-400 mb-2">15.2%</div>
            <div className="text-gray-300">Avg. Performance</div>
          </div>
        </div>

        {/* Vaults Section */}
        <div className="mb-8">
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center mb-6">
            <h2 className="text-2xl font-bold mb-4 sm:mb-0 flex items-center gap-2">
              <TrendingUpIcon className="w-6 h-6 text-primary-400" />
              Active Vaults
            </h2>
            
            {isConnected && (
              <div className="flex gap-2">
                <Link href="/create" className="btn-outline flex items-center gap-2">
                  <PlusIcon className="w-4 h-4" />
                  Create New
                </Link>
              </div>
            )}
          </div>

          {!isConnected ? (
            <div className="card text-center py-12">
              <h3 className="text-lg font-medium mb-2">Connect Your Wallet</h3>
              <p className="text-gray-400 mb-6">
                Connect your wallet to view and interact with vaults
              </p>
              <ConnectButton />
            </div>
          ) : isLoading ? (
            <div className="flex justify-center py-12">
              <LoadingSpinner />
            </div>
          ) : vaults.length === 0 ? (
            <div className="card text-center py-12">
              <h3 className="text-lg font-medium mb-2">No Vaults Found</h3>
              <p className="text-gray-400 mb-6">
                Be the first to create a vault and start your DCA strategy
              </p>
              <Link href="/create" className="btn-primary inline-flex items-center gap-2">
                <PlusIcon className="w-4 h-4" />
                Create First Vault
              </Link>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {vaults.map((vaultAddress) => (
                <VaultCard 
                  key={vaultAddress} 
                  address={vaultAddress}
                  showCopyButton={true}
                />
              ))}
            </div>
          )}

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="flex justify-center gap-2 mt-8">
              <button
                onClick={() => setCurrentPage(Math.max(0, currentPage - 1))}
                disabled={currentPage === 0}
                className="btn-secondary disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Previous
              </button>
              
              <div className="flex gap-1">
                {Array.from({ length: Math.min(5, totalPages) }, (_, i) => {
                  const page = currentPage < 3 
                    ? i 
                    : currentPage > totalPages - 3 
                      ? totalPages - 5 + i 
                      : currentPage - 2 + i;
                  
                  if (page < 0 || page >= totalPages) return null;
                  
                  return (
                    <button
                      key={page}
                      onClick={() => setCurrentPage(page)}
                      className={`px-3 py-2 rounded ${
                        page === currentPage 
                          ? 'bg-primary-500 text-white' 
                          : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
                      }`}
                    >
                      {page + 1}
                    </button>
                  );
                })}
              </div>
              
              <button
                onClick={() => setCurrentPage(Math.min(totalPages - 1, currentPage + 1))}
                disabled={currentPage === totalPages - 1}
                className="btn-secondary disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Next
              </button>
            </div>
          )}
        </div>

        {/* Features Section */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mt-16">
          <div className="card">
            <div className="w-12 h-12 bg-primary-500 rounded-lg flex items-center justify-center mb-4">
              <ActivityIcon className="w-6 h-6" />
            </div>
            <h3 className="text-lg font-semibold mb-2">Automated DCA</h3>
            <p className="text-gray-400">
              Set up periodic swaps that execute automatically, eliminating emotional trading decisions.
            </p>
          </div>
          
          <div className="card">
            <div className="w-12 h-12 bg-green-500 rounded-lg flex items-center justify-center mb-4">
              <CopyIcon className="w-6 h-6" />
            </div>
            <h3 className="text-lg font-semibold mb-2">Social Copy</h3>
            <p className="text-gray-400">
              Copy successful strategies from other traders with one click. Learn from the best performers.
            </p>
          </div>
          
          <div className="card">
            <div className="w-12 h-12 bg-purple-500 rounded-lg flex items-center justify-center mb-4">
              <TrendingUpIcon className="w-6 h-6" />
            </div>
            <h3 className="text-lg font-semibold mb-2">ERC-4626 Compliant</h3>
            <p className="text-gray-400">
              Built on standard vault interfaces for maximum composability and integration potential.
            </p>
          </div>
        </div>
      </Layout>
    </>
  );
}
