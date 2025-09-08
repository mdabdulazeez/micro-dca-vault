import { useState } from 'react';
import Head from 'next/head';
import { useRouter } from 'next/router';
import { useAccount, useContractWrite } from 'wagmi';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { toast } from 'react-hot-toast';
import { PlusIcon, ArrowLeftIcon } from 'lucide-react';

import Layout from '@/components/Layout';
import LoadingSpinner from '@/components/LoadingSpinner';
import { CONTRACT_ADDRESSES, VAULT_FACTORY_ABI } from '@/lib/contracts';
import { parseTokenAmount } from '@/lib/format';
import { isValidAddress } from '@/lib/format';

const createVaultSchema = z.object({
  baseToken: z.string().min(1, 'Base token address is required').refine(isValidAddress, 'Invalid address'),
  quoteToken: z.string().min(1, 'Quote token address is required').refine(isValidAddress, 'Invalid address'),
  intervalSeconds: z.number().min(1, 'Interval must be at least 1 second').max(86400, 'Interval must be less than 1 day'),
  maxSlippageBps: z.number().min(1, 'Slippage must be at least 0.01%').max(1000, 'Slippage must be less than 10%'),
  perCycleQuoteCap: z.string().min(1, 'Cap is required'),
  feeBps: z.number().min(0, 'Fee cannot be negative').max(1000, 'Fee must be less than 10%'),
  keeper: z.string().optional(),
});

type CreateVaultForm = z.infer<typeof createVaultSchema>;

export default function CreateVault() {
  const { isConnected } = useAccount();
  const router = useRouter();
  const [isCreating, setIsCreating] = useState(false);

  const {
    register,
    handleSubmit,
    watch,
    formState: { errors, isValid },
  } = useForm<CreateVaultForm>({
    resolver: zodResolver(createVaultSchema),
    defaultValues: {
      intervalSeconds: 60,
      maxSlippageBps: 50,
      perCycleQuoteCap: '100',
      feeBps: 10,
      keeper: '',
    },
  });

  const { writeAsync: createVault } = useContractWrite({
    address: CONTRACT_ADDRESSES.VAULT_FACTORY,
    abi: VAULT_FACTORY_ABI,
    functionName: 'createVault',
  });

  const onSubmit = async (data: CreateVaultForm) => {
    if (!createVault) {
      toast.error('Contract not available');
      return;
    }

    if (data.baseToken.toLowerCase() === data.quoteToken.toLowerCase()) {
      toast.error('Base and quote tokens must be different');
      return;
    }

    try {
      setIsCreating(true);
      
      const perCycleQuoteCapBigInt = parseTokenAmount(data.perCycleQuoteCap);
      const keeperAddress = data.keeper && isValidAddress(data.keeper) ? data.keeper : '0x0000000000000000000000000000000000000000';

      const tx = await createVault({
        args: [
          data.baseToken as `0x${string}`,
          data.quoteToken as `0x${string}`,
          BigInt(data.intervalSeconds),
          BigInt(data.maxSlippageBps),
          perCycleQuoteCapBigInt,
          BigInt(data.feeBps),
          keeperAddress as `0x${string}`,
        ],
      });

      toast.success('Vault created successfully!');
      
      // Redirect to home page after successful creation
      setTimeout(() => {
        router.push('/');
      }, 2000);
      
    } catch (error: any) {
      console.error('Creation failed:', error);
      toast.error(error?.message || 'Failed to create vault');
    } finally {
      setIsCreating(false);
    }
  };

  const watchedValues = watch();

  if (!isConnected) {
    return (
      <Layout>
        <Head>
          <title>Create Vault | Micro-DCA Vault</title>
        </Head>
        
        <div className="max-w-md mx-auto">
          <div className="card text-center">
            <h1 className="text-2xl font-bold mb-4">Connect Wallet</h1>
            <p className="text-gray-400 mb-6">
              Please connect your wallet to create a new DCA vault.
            </p>
            <button 
              onClick={() => router.push('/')}
              className="btn-secondary"
            >
              Go Back
            </button>
          </div>
        </div>
      </Layout>
    );
  }

  return (
    <>
      <Head>
        <title>Create Vault | Micro-DCA Vault</title>
        <meta name="description" content="Create a new automated DCA vault strategy" />
      </Head>

      <Layout>
        <div className="max-w-2xl mx-auto">
          {/* Header */}
          <div className="flex items-center gap-4 mb-8">
            <button
              onClick={() => router.back()}
              className="btn-secondary p-2"
            >
              <ArrowLeftIcon className="w-5 h-5" />
            </button>
            <div>
              <h1 className="text-3xl font-bold">Create DCA Vault</h1>
              <p className="text-gray-400 mt-1">
                Set up your automated dollar-cost averaging strategy
              </p>
            </div>
          </div>

          {/* Form */}
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
            <div className="card">
              <h2 className="text-xl font-semibold mb-6">Token Configuration</h2>
              
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {/* Base Token */}
                <div>
                  <label className="block text-sm font-medium mb-2">
                    Base Token Address
                    <span className="text-red-400">*</span>
                  </label>
                  <input
                    {...register('baseToken')}
                    type="text"
                    className="input w-full"
                    placeholder="0x..."
                  />
                  {errors.baseToken && (
                    <p className="text-red-400 text-sm mt-1">{errors.baseToken.message}</p>
                  )}
                  <p className="text-xs text-gray-400 mt-1">Token you want to buy (accumulate)</p>
                </div>

                {/* Quote Token */}
                <div>
                  <label className="block text-sm font-medium mb-2">
                    Quote Token Address
                    <span className="text-red-400">*</span>
                  </label>
                  <input
                    {...register('quoteToken')}
                    type="text"
                    className="input w-full"
                    placeholder="0x..."
                  />
                  {errors.quoteToken && (
                    <p className="text-red-400 text-sm mt-1">{errors.quoteToken.message}</p>
                  )}
                  <p className="text-xs text-gray-400 mt-1">Token you want to sell (spend)</p>
                </div>
              </div>
            </div>

            <div className="card">
              <h2 className="text-xl font-semibold mb-6">Strategy Parameters</h2>
              
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {/* Interval */}
                <div>
                  <label className="block text-sm font-medium mb-2">
                    Execution Interval (seconds)
                    <span className="text-red-400">*</span>
                  </label>
                  <input
                    {...register('intervalSeconds', { valueAsNumber: true })}
                    type="number"
                    min="1"
                    max="86400"
                    className="input w-full"
                  />
                  {errors.intervalSeconds && (
                    <p className="text-red-400 text-sm mt-1">{errors.intervalSeconds.message}</p>
                  )}
                  <p className="text-xs text-gray-400 mt-1">
                    {watchedValues.intervalSeconds >= 3600 
                      ? `${(watchedValues.intervalSeconds / 3600).toFixed(1)} hours`
                      : watchedValues.intervalSeconds >= 60
                        ? `${Math.floor(watchedValues.intervalSeconds / 60)} minutes`
                        : `${watchedValues.intervalSeconds} seconds`}
                  </p>
                </div>

                {/* Per Cycle Cap */}
                <div>
                  <label className="block text-sm font-medium mb-2">
                    Per-Cycle Cap (tokens)
                    <span className="text-red-400">*</span>
                  </label>
                  <input
                    {...register('perCycleQuoteCap')}
                    type="text"
                    className="input w-full"
                    placeholder="100"
                  />
                  {errors.perCycleQuoteCap && (
                    <p className="text-red-400 text-sm mt-1">{errors.perCycleQuoteCap.message}</p>
                  )}
                  <p className="text-xs text-gray-400 mt-1">Maximum tokens to swap per cycle</p>
                </div>

                {/* Max Slippage */}
                <div>
                  <label className="block text-sm font-medium mb-2">
                    Max Slippage (basis points)
                    <span className="text-red-400">*</span>
                  </label>
                  <input
                    {...register('maxSlippageBps', { valueAsNumber: true })}
                    type="number"
                    min="1"
                    max="1000"
                    className="input w-full"
                  />
                  {errors.maxSlippageBps && (
                    <p className="text-red-400 text-sm mt-1">{errors.maxSlippageBps.message}</p>
                  )}
                  <p className="text-xs text-gray-400 mt-1">
                    {(watchedValues.maxSlippageBps / 100).toFixed(2)}% maximum slippage
                  </p>
                </div>

                {/* Fee */}
                <div>
                  <label className="block text-sm font-medium mb-2">
                    Protocol Fee (basis points)
                  </label>
                  <input
                    {...register('feeBps', { valueAsNumber: true })}
                    type="number"
                    min="0"
                    max="1000"
                    className="input w-full"
                  />
                  {errors.feeBps && (
                    <p className="text-red-400 text-sm mt-1">{errors.feeBps.message}</p>
                  )}
                  <p className="text-xs text-gray-400 mt-1">
                    {(watchedValues.feeBps / 100).toFixed(2)}% fee on base token output
                  </p>
                </div>
              </div>
            </div>

            <div className="card">
              <h2 className="text-xl font-semibold mb-6">Access Control</h2>
              
              <div>
                <label className="block text-sm font-medium mb-2">
                  Keeper Address (optional)
                </label>
                <input
                  {...register('keeper')}
                  type="text"
                  className="input w-full"
                  placeholder="0x... (leave empty for permissionless execution)"
                />
                {errors.keeper && (
                  <p className="text-red-400 text-sm mt-1">{errors.keeper.message}</p>
                )}
                <p className="text-xs text-gray-400 mt-1">
                  If specified, only this address can execute cycles. Leave empty for permissionless execution.
                </p>
              </div>
            </div>

            {/* Summary */}
            <div className="card bg-gradient-to-r from-primary-500/10 to-purple-500/10 border-primary-500/20">
              <h2 className="text-xl font-semibold mb-4">Strategy Summary</h2>
              <div className="space-y-2 text-sm">
                <p>
                  <span className="text-gray-400">Strategy:</span> Buy base tokens with quote tokens
                </p>
                <p>
                  <span className="text-gray-400">Frequency:</span> Every {watchedValues.intervalSeconds} seconds
                </p>
                <p>
                  <span className="text-gray-400">Amount per cycle:</span> Up to {watchedValues.perCycleQuoteCap} quote tokens
                </p>
                <p>
                  <span className="text-gray-400">Slippage tolerance:</span> {(watchedValues.maxSlippageBps / 100).toFixed(2)}%
                </p>
                <p>
                  <span className="text-gray-400">Protocol fee:</span> {(watchedValues.feeBps / 100).toFixed(2)}%
                </p>
                <p>
                  <span className="text-gray-400">Execution:</span> {watchedValues.keeper ? 'Keeper restricted' : 'Permissionless'}
                </p>
              </div>
            </div>

            {/* Submit Button */}
            <button
              type="submit"
              disabled={!isValid || isCreating}
              className="btn-primary w-full py-4 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            >
              {isCreating ? (
                <>
                  <LoadingSpinner size="sm" />
                  Creating Vault...
                </>
              ) : (
                <>
                  <PlusIcon className="w-5 h-5" />
                  Create Vault
                </>
              )}
            </button>
          </form>
        </div>
      </Layout>
    </>
  );
}
