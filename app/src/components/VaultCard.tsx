import { useState } from 'react';
import Link from 'next/link';
import { useContractReads, useContractWrite } from 'wagmi';
import { toast } from 'react-hot-toast';
import { 
  CopyIcon, 
  TrendingUpIcon, 
  ClockIcon, 
  DollarSignIcon,
  PauseIcon,
  PlayIcon,
  ExternalLinkIcon
} from 'lucide-react';

import LoadingSpinner from '@/components/LoadingSpinner';
import { 
  MICRO_DCA_VAULT_ABI, 
  ERC20_ABI, 
  CONTRACT_ADDRESSES, 
  VAULT_FACTORY_ABI,
  type VaultInfo 
} from '@/lib/contracts';
import { formatTokenAmount, formatBps, getTimeUntilNext, formatAddress } from '@/lib/format';
import type { Address } from 'viem';

interface VaultCardProps {
  address: Address;
  showCopyButton?: boolean;
  isOwned?: boolean;
}

export default function VaultCard({ address, showCopyButton = false, isOwned = false }: VaultCardProps) {
  const [iscopying, setIscopying] = useState(false);

  // Read vault data
  const { data: vaultData, isLoading } = useContractReads({
    contracts: [
      {
        address,
        abi: MICRO_DCA_VAULT_ABI,
        functionName: 'getConfig',
      },
      {
        address,
        abi: MICRO_DCA_VAULT_ABI,
        functionName: 'baseToken',
      },
      {
        address,
        abi: MICRO_DCA_VAULT_ABI,
        functionName: 'quoteToken',
      },
      {
        address,
        abi: MICRO_DCA_VAULT_ABI,
        functionName: 'owner',
      },
      {
        address,
        abi: MICRO_DCA_VAULT_ABI,
        functionName: 'totalAssets',
      },
      {
        address,
        abi: MICRO_DCA_VAULT_ABI,
        functionName: 'totalFilledQuote',
      },
      {
        address,
        abi: MICRO_DCA_VAULT_ABI,
        functionName: 'totalFilledBase',
      },
      {
        address,
        abi: MICRO_DCA_VAULT_ABI,
        functionName: 'nextExecTime',
      },
    ],
    watch: true,
  });

  // Read token symbols if vault data is loaded
  const baseTokenAddress = vaultData?.[1]?.result as Address;
  const quoteTokenAddress = vaultData?.[2]?.result as Address;

  const { data: tokenData } = useContractReads({
    contracts: [
      {
        address: baseTokenAddress,
        abi: ERC20_ABI,
        functionName: 'symbol',
      },
      {
        address: quoteTokenAddress,
        abi: ERC20_ABI,
        functionName: 'symbol',
      },
    ],
    enabled: !!(baseTokenAddress && quoteTokenAddress),
  });

  // Copy vault mutation
  const { writeAsync: copyVault } = useContractWrite({
    address: CONTRACT_ADDRESSES.VAULT_FACTORY,
    abi: VAULT_FACTORY_ABI,
    functionName: 'copyVault',
  });

  const handleCopy = async () => {
    if (!copyVault) return;

    try {
      setIscopying(true);
      const tx = await copyVault({
        args: [address],
      });
      
      toast.success('Vault copied successfully!');
    } catch (error: any) {
      console.error('Copy failed:', error);
      toast.error(error?.message || 'Failed to copy vault');
    } finally {
      setIscopying(false);
    }
  };

  if (isLoading) {
    return (
      <div className="card">
        <div className="flex justify-center py-8">
          <LoadingSpinner />
        </div>
      </div>
    );
  }

  if (!vaultData || vaultData.some(d => d.status === 'failure')) {
    return (
      <div className="card">
        <div className="text-center py-8 text-gray-400">
          Failed to load vault data
        </div>
      </div>
    );
  }

  const config = vaultData[0]?.result as any;
  const owner = vaultData[3]?.result as Address;
  const totalAssets = vaultData[4]?.result as bigint;
  const totalFilledQuote = vaultData[5]?.result as bigint;
  const totalFilledBase = vaultData[6]?.result as bigint;
  const nextExecTime = vaultData[7]?.result as bigint;

  const baseSymbol = tokenData?.[0]?.result as string || 'BASE';
  const quoteSymbol = tokenData?.[1]?.result as string || 'QUOTE';

  const timeUntilNext = getTimeUntilNext(nextExecTime);
  const isPaused = config?.[5]; // paused flag

  return (
    <div className="card hover:shadow-xl transition-shadow duration-200">
      {/* Header */}
      <div className="flex justify-between items-start mb-4">
        <div>
          <h3 className="font-semibold text-lg mb-1">
            {quoteSymbol} → {baseSymbol}
          </h3>
          <p className="text-sm text-gray-400">
            by {formatAddress(owner)}
          </p>
        </div>
        
        <div className="flex items-center gap-2">
          {/* Status indicator */}
          <div className={`w-3 h-3 rounded-full ${
            isPaused 
              ? 'bg-red-500' 
              : timeUntilNext.isReady 
                ? 'bg-green-500 pulse' 
                : 'bg-yellow-500'
          }`} />
          
          {/* Copy button */}
          {showCopyButton && (
            <button
              onClick={handleCopy}
              disabled={isOwned || iscopying}
              className="p-2 text-gray-400 hover:text-white hover:bg-gray-700 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              title={isOwned ? "Can't copy own vault" : "Copy this strategy"}
            >
              {isOwned ? (
                <ExternalLinkIcon className="w-4 h-4" />
              ) : isLoading ? (
                <LoadingSpinner size="sm" />
              ) : (
                <CopyIcon className="w-4 h-4" />
              )}
            </button>
          )}
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 gap-4 mb-4">
        <div>
          <div className="text-sm text-gray-400">Total Assets</div>
          <div className="font-medium">
            {formatTokenAmount(totalAssets)} {quoteSymbol}
          </div>
        </div>
        <div>
          <div className="text-sm text-gray-400">Filled</div>
          <div className="font-medium">
            {formatTokenAmount(totalFilledQuote)} {quoteSymbol}
          </div>
        </div>
      </div>

      {/* Configuration */}
      <div className="space-y-2 mb-4 text-sm">
        <div className="flex justify-between">
          <span className="text-gray-400">Interval:</span>
          <span>{Number(config?.[0] || 0) / 60}m</span>
        </div>
        <div className="flex justify-between">
          <span className="text-gray-400">Max Slippage:</span>
          <span>{formatBps(config?.[1] || 0)}</span>
        </div>
        <div className="flex justify-between">
          <span className="text-gray-400">Per Cycle Cap:</span>
          <span>{formatTokenAmount(config?.[2] || 0n, 18, 0)} {quoteSymbol}</span>
        </div>
        <div className="flex justify-between">
          <span className="text-gray-400">Fee:</span>
          <span>{formatBps(config?.[3] || 0)}</span>
        </div>
      </div>

      {/* Status */}
      <div className="flex items-center justify-between text-sm mb-4">
        <div className="flex items-center gap-2">
          {isPaused ? (
            <>
              <PauseIcon className="w-4 h-4 text-red-400" />
              <span className="text-red-400">Paused</span>
            </>
          ) : timeUntilNext.isReady ? (
            <>
              <PlayIcon className="w-4 h-4 text-green-400" />
              <span className="text-green-400">Ready to Execute</span>
            </>
          ) : (
            <>
              <ClockIcon className="w-4 h-4 text-yellow-400" />
              <span className="text-yellow-400">Next: {timeUntilNext.formatted}</span>
            </>
          )}
        </div>
      </div>

      {/* Actions */}
      <div className="flex gap-2">
        <Link 
          href={`/vault/${address}`}
          className="btn-primary flex-1 text-center"
        >
          View Details
        </Link>
        
        {showCopyButton && !isOwned && (
          <button
            onClick={handleCopy}
            disabled={iscopying}
            className="btn-secondary px-4 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isLoading ? (
              <LoadingSpinner size="sm" />
            ) : (
              <CopyIcon className="w-4 h-4" />
            )}
          </button>
        )}
      </div>
    </div>
  );
}
