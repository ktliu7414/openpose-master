#include <thrust/device_ptr.h>
#include <thrust/scan.h>
#include <openpose/gpu/cuda.hpp>
#include <openpose/gpu/cuda.hu>
#include <openpose/net/nmsBase.hpp>

namespace op
{
    const auto THREADS_PER_BLOCK_1D = 16u;
    const auto THREADS_PER_BLOCK = 512u;

    template <typename T>
    __global__ void nmsRegisterKernel(
        int* kernelPtr, const T* const sourcePtr, const int w, const int h, const T threshold)
    {
        // get pixel location (x,y)
        const auto x = blockIdx.x * blockDim.x + threadIdx.x;
        const auto y = blockIdx.y * blockDim.y + threadIdx.y;
        const auto index = y*w + x;

        if (0 < x && x < (w-1) && 0 < y && y < (h-1))
        {
            const auto value = sourcePtr[index];
            if (value > threshold)
            {
                const auto topLeft     = sourcePtr[(y-1)*w + x-1];
                const auto top         = sourcePtr[(y-1)*w + x];
                const auto topRight    = sourcePtr[(y-1)*w + x+1];
                const auto left        = sourcePtr[    y*w + x-1];
                const auto right       = sourcePtr[    y*w + x+1];
                const auto bottomLeft  = sourcePtr[(y+1)*w + x-1];
                const auto bottom      = sourcePtr[(y+1)*w + x];
                const auto bottomRight = sourcePtr[(y+1)*w + x+1];

                if (value > topLeft && value > top && value > topRight
                    && value > left && value > right
                    && value > bottomLeft && value > bottom && value > bottomRight)
                    kernelPtr[index] = 1;
                else
                    kernelPtr[index] = 0;
            }
            else
                kernelPtr[index] = 0;
        }
        else if (x == 0 || x == (w-1) || y == 0 || y == (h-1))
            kernelPtr[index] = 0;
    }

    // Note: Shared memory made this function slower, from 1.2 ms to about 2 ms.
    template <typename T>
    __global__ void nmsRegisterAllKernel(
        int* kernelPtr, const T* const sourcePtr, const int w, const int h, const T threshold)
    {
        // get pixel location (x,y)
        const auto x = blockIdx.x * blockDim.x + threadIdx.x;
        const auto y = blockIdx.y * blockDim.y + threadIdx.y;
        const auto channel = blockIdx.z * blockDim.z + threadIdx.z;
        const auto channelOffset = channel * w*h;
        const auto index = y*w + x;

        auto* kernelPtrOffset = &kernelPtr[channelOffset];
        const T* const sourcePtrOffset = &sourcePtr[channelOffset];

        if (0 < x && x < (w-1) && 0 < y && y < (h-1))
        {
            const auto value = sourcePtrOffset[index];
            if (value > threshold)
            {
                const auto topLeft     = sourcePtrOffset[(y-1)*w + x-1];
                const auto top         = sourcePtrOffset[(y-1)*w + x];
                const auto topRight    = sourcePtrOffset[(y-1)*w + x+1];
                const auto left        = sourcePtrOffset[    y*w + x-1];
                const auto right       = sourcePtrOffset[    y*w + x+1];
                const auto bottomLeft  = sourcePtrOffset[(y+1)*w + x-1];
                const auto bottom      = sourcePtrOffset[(y+1)*w + x];
                const auto bottomRight = sourcePtrOffset[(y+1)*w + x+1];

                if (value > topLeft && value > top && value > topRight
                    && value > left && value > right
                    && value > bottomLeft && value > bottom && value > bottomRight)
                    kernelPtrOffset[index] = 1;
                else
                    kernelPtrOffset[index] = 0;
            }
            else
                kernelPtrOffset[index] = 0;
        }
        else if (x == 0 || x == (w-1) || y == 0 || y == (h-1))
            kernelPtrOffset[index] = 0;
    }

    template <typename T>
    __global__ void writeResultKernel(
        T* output, const int length, const int* const kernelPtr, const T* const sourcePtr, const int width,
        const int height, const int maxPeaks, const T offsetX, const T offsetY)
    {
        __shared__ int local[THREADS_PER_BLOCK+1]; // one more
        const auto globalIdx = blockIdx.x * blockDim.x + threadIdx.x;

        if (globalIdx < length)
        {
            local[threadIdx.x] = kernelPtr[globalIdx];
            //last thread in the block but not globally last, load one more
            if (threadIdx.x == THREADS_PER_BLOCK - 1 && globalIdx != length - 1)
                local[threadIdx.x+1] = kernelPtr[globalIdx+1];

            __syncthreads();
            // See difference, except the globally last one
            if (globalIdx != length - 1)
            {
                // A[globalIdx] == A[globalIdx + 1] means no peak
                if (local[threadIdx.x] != local[threadIdx.x + 1])
                {
                    const auto peakIndex = kernelPtr[globalIdx]; //0-index
                    const auto peakLocX = (int)(globalIdx % width);
                    const auto peakLocY = (int)(globalIdx / width);

                    // Accurate peak location: considered neighboors
                    if (peakIndex < maxPeaks) // limitation
                    {
                        T xAcc = 0.f;
                        T yAcc = 0.f;
                        T scoreAcc = 0.f;
                        const auto dWidth = 3;
                        const auto dHeight = 3;
                        for (auto dy = -dHeight ; dy <= dHeight ; dy++)
                        {
                            const auto y = peakLocY + dy;
                            if (0 <= y && y < height) // Default height = 368
                            {
                                for (auto dx = -dWidth ; dx <= dWidth ; dx++)
                                {
                                    const auto x = peakLocX + dx;
                                    if (0 <= x && x < width) // Default width = 656
                                    {
                                        const auto score = sourcePtr[y * width + x];
                                        if (score > 0)
                                        {
                                            xAcc += x*score;
                                            yAcc += y*score;
                                            scoreAcc += score;
                                        }
                                    }
                                }
                            }
                        }

                        // Offset to keep Matlab format (empirically higher acc)
                        // Best results for 1 scale: x + 0, y + 0.5
                        // +0.5 to both to keep Matlab format
                        const auto outputIndex = (peakIndex + 1) * 3;
                        output[outputIndex] = xAcc / scoreAcc + offsetX;
                        output[outputIndex + 1] = yAcc / scoreAcc + offsetY;
                        output[outputIndex + 2] = sourcePtr[peakLocY*width + peakLocX];
                    }
                }
            }
            // If index 0 --> Assign number of peaks (truncated to the maximum possible number of peaks)
            else
                output[0] = (kernelPtr[globalIdx] < maxPeaks ? kernelPtr[globalIdx] : maxPeaks);
        }
    }

    template <typename T>
    __global__ void writeResultAllKernel(
        T* output, const int length, const int* const kernelPtr, const T* const sourcePtr, const int width,
        const int height, const int maxPeaks, const T offsetX, const T offsetY, const int offsetTarget)
    {
        __shared__ int local[THREADS_PER_BLOCK+1]; // one more
        __shared__ int kernel0; // Offset for kernel
        const auto globalIdx = blockIdx.x * blockDim.x + threadIdx.x;
        const auto channel = blockIdx.y * blockDim.y + threadIdx.y;
        const auto channelOffsetSource = channel * width*height;
        const auto channelOffset = channel * offsetTarget;

        // We need to substract the peak at pixel 0 of the current channel for all values
        if (threadIdx.x == 0)
            kernel0 = kernelPtr[channelOffsetSource];
        __syncthreads();

        if (globalIdx < length)
        {
            auto* outputOffset = &output[channelOffset];
            const auto* const kernelPtrOffset = &kernelPtr[channelOffsetSource];
            const auto* const sourcePtrOffset = &sourcePtr[channelOffsetSource];
            local[threadIdx.x] = kernelPtrOffset[globalIdx] - kernel0;
            //last thread in the block but not globally last, load one more
            if (threadIdx.x == THREADS_PER_BLOCK - 1 && globalIdx != length - 1)
                local[threadIdx.x+1] = kernelPtrOffset[globalIdx+1] - kernel0;
            __syncthreads();

            // See difference, except the globally last one
            if (globalIdx != length - 1)
            {
                // A[globalIdx] == A[globalIdx + 1] means no peak
                if (local[threadIdx.x] != local[threadIdx.x + 1])
                {
                    const auto peakIndex = local[threadIdx.x]; //0-index
                    const auto peakLocX = (int)(globalIdx % width);
                    const auto peakLocY = (int)(globalIdx / width);

                    // Accurate peak location: considered neighboors
                    if (peakIndex < maxPeaks) // limitation
                    {
                        T xAcc = 0.f;
                        T yAcc = 0.f;
                        T scoreAcc = 0.f;
                        const auto dWidth = 3;
                        const auto dHeight = 3;
                        for (auto dy = -dHeight ; dy <= dHeight ; dy++)
                        {
                            const auto y = peakLocY + dy;
                            if (0 <= y && y < height) // Default height = 368
                            {
                                for (auto dx = -dWidth ; dx <= dWidth ; dx++)
                                {
                                    const auto x = peakLocX + dx;
                                    if (0 <= x && x < width) // Default width = 656
                                    {
                                        const auto score = sourcePtrOffset[y * width + x];
                                        if (score > 0)
                                        {
                                            xAcc += x*score;
                                            yAcc += y*score;
                                            scoreAcc += score;
                                        }
                                    }
                                }
                            }
                        }

                        // Offset to keep Matlab format (empirically higher acc)
                        // Best results for 1 scale: x + 0, y + 0.5
                        // +0.5 to both to keep Matlab format
                        const auto outputIndex = (peakIndex + 1) * 3;
                        outputOffset[outputIndex] = xAcc / scoreAcc + offsetX;
                        outputOffset[outputIndex + 1] = yAcc / scoreAcc + offsetY;
                        outputOffset[outputIndex + 2] = sourcePtrOffset[peakLocY*width + peakLocX];
                    }
                }
            }
            // If index 0 --> Assign number of peaks (truncated to the maximum possible number of peaks)
            else
                outputOffset[0] = (local[threadIdx.x] < maxPeaks ? local[threadIdx.x] : maxPeaks);
        }
    }

    // template <typename T>
    // __global__ void sortKernel(T* targetPtr, const int channels, const int offsetTarget)
    // {
    //     const auto globalIdx = blockIdx.x * blockDim.x + threadIdx.x;

    //     if (globalIdx < channels)
    //     {
    //         const auto totalOffset = globalIdx * offsetTarget;
    //         const int nonZeroElementsPlus1 = targetPtr[totalOffset]+1;
    //         for (auto i = 1 ; i < nonZeroElementsPlus1 ; i++)
    //         {
    //             // Find new maximum
    //             const auto iIndex = totalOffset+3*i;
    //             int maxIndex = i;
    //             T maxIndexValue = targetPtr[iIndex+2];
    //             for (auto j = i+1 ; j < nonZeroElementsPlus1 ; j++)
    //             {
    //                 if (maxIndexValue < targetPtr[totalOffset+3*j+2])
    //                 {
    //                     maxIndex = j;
    //                     maxIndexValue = targetPtr[totalOffset+3*j+2];
    //                 }
    //             }
    //             // Swap
    //             const auto jIndex = totalOffset+3*maxIndex;
    //             const T temp [3] = {targetPtr[iIndex],
    //                                 targetPtr[iIndex+1],
    //                                 targetPtr[iIndex+2]};
    //             targetPtr[iIndex] = targetPtr[jIndex];
    //             targetPtr[iIndex+1] = targetPtr[jIndex+1];
    //             targetPtr[iIndex+2] = targetPtr[jIndex+2];
    //             targetPtr[jIndex] = temp[0];
    //             targetPtr[jIndex+1] = temp[1];
    //             targetPtr[jIndex+2] = temp[2];
    //         }
    //     }
    // }

    template <typename T>
    void nmsGpu(T* targetPtr, int* kernelPtr, const T* const sourcePtr, const T threshold,
                const std::array<int, 4>& targetSize, const std::array<int, 4>& sourceSize, const Point<T>& offset)
    {
        try
        {
            //Forward_cpu(bottom, top);
            const auto num = sourceSize[0];
            const auto height = sourceSize[2];
            const auto width = sourceSize[3];
            const auto channels = targetSize[1];
            const auto maxPeaks = targetSize[2]-1;
            const auto imageOffset = height * width;
            const auto offsetTarget = (maxPeaks+1)*targetSize[3];

            const dim3 threadsPerBlock2D{THREADS_PER_BLOCK_1D, THREADS_PER_BLOCK_1D};
            const dim3 numBlocks2D{getNumberCudaBlocks(width, threadsPerBlock2D.x),
                                   getNumberCudaBlocks(height, threadsPerBlock2D.y)};
            const dim3 threadsPerBlock1D{THREADS_PER_BLOCK};
            const dim3 numBlocks1D{getNumberCudaBlocks(imageOffset, threadsPerBlock1D.x)};
            // const dim3 threadsPerBlockSort{128};
            // const dim3 numBlocksSort{getNumberCudaBlocks(channels, threadsPerBlockSort.x)};
            // log("num_b: " + std::to_string(sourceSize[0]));       // = 1
            // log("channel_b: " + std::to_string(sourceSize[1]));   // = 57 = 18 body parts + bkg + 19x2 PAFs
            // log("height_b: " + std::to_string(sourceSize[2]));    // = 368 = height
            // log("width_b: " + std::to_string(sourceSize[3]));     // = 656 = width
            // log("num_t: " + std::to_string(targetSize[0]));       // = 1
            // log("channel_t: " + std::to_string(targetSize[1]));   // = 18 = numberParts
            // log("height_t: " + std::to_string(targetSize[2]));    // = 128 = maxPeople + 1
            // log("width_t: " + std::to_string(targetSize[3]));     // = 3 = [x, y, score]
            // log("");

            // // const auto REPS = 1;
            // const auto REPS = 1000;
            // double timeNormalize1 = 0.;
            // double timeNormalize2 = 0.;
            // OP_CUDA_PROFILE_INIT(REPS);
            // // Option a)
            // for (auto n = 0; n < num; n++)
            // {
            //     for (auto c = 0; c < channels; c++)
            //     {
            //         // log("channel: " + std::to_string(c));
            //         const auto offsetChannel = (n * channels + c);
            //         auto* kernelPtrOffsetted = kernelPtr + offsetChannel * imageOffset;
            //         const auto* const sourcePtrOffsetted = sourcePtr + offsetChannel * imageOffset;
            //         auto* targetPtrOffsetted = targetPtr + offsetChannel * offsetTarget;

            //         // This returns kernelPtrOffsetted, a binary array with 0s & 1s. 1s in the local maximum
            //         // positions (size = size(sourcePtrOffsetted))
            //         // Example result: [0,0,0,0,1,0,0,0,0,1,0,0,0,0]
            //         nmsRegisterKernel<<<numBlocks2D, threadsPerBlock2D>>>(
            //             kernelPtrOffsetted, sourcePtrOffsetted, width, height, threshold);

            //         // This modifies kernelPtrOffsetted, now it indicates the local maximum indexes
            //         // Format: 0,0,0,1,1,1,1,2,2,2,... First maximum at index 2, second at 6, etc...
            //         // Example result: [0,0,0,0,0,1,1,1,1,1,2,2,2,2]
            //         auto kernelThrustPtr = thrust::device_pointer_cast(kernelPtrOffsetted);
            //         thrust::exclusive_scan(kernelThrustPtr, kernelThrustPtr + imageOffset, kernelThrustPtr);

            //         // This returns targetPtrOffsetted, with the NMS applied over it
            //         writeResultKernel<<<numBlocks1D, threadsPerBlock1D>>>(
            //             targetPtrOffsetted, imageOffset, kernelPtrOffsetted, sourcePtrOffsetted, width, height,
            //             maxPeaks, offset.x, offset.y);
            //     }
            //     // // Sort based on score
            //     // // Commented because it doesn't change accuracy
            //     // // TODO: If finally used, implement for CPU/CL versions
            //     // sortKernel<<<numBlocksSort, threadsPerBlockSort>>>(targetPtr, channels, offsetTarget);
            // }
            // OP_CUDA_PROFILE_END(timeNormalize1, 1e3, REPS);
            // OP_CUDA_PROFILE_INIT(REPS);

            // Option b)
            // This returns kernelPtr, a binary array with 0s & 1s. 1s in the local maximum
            // positions (size = size(sourcePtrOffsetted))
            // Example result: [0,0,0,0,1,0,0,0,0,1,0,0,0,0]
            // time = 1.24 ms
            const dim3 threadsPerBlockRegister{THREADS_PER_BLOCK_1D, THREADS_PER_BLOCK_1D, 1};
            const dim3 numBlocksRegister{getNumberCudaBlocks(width, threadsPerBlockRegister.x),
                                         getNumberCudaBlocks(height, threadsPerBlockRegister.y),
                                         getNumberCudaBlocks(num * channels, threadsPerBlockRegister.z)};
            nmsRegisterAllKernel<<<numBlocksRegister, threadsPerBlockRegister>>>(
                kernelPtr, sourcePtr, width, height, threshold);
            // This modifies kernelPtrOffsetted, now it indicates the local maximum indexes
            // Format: 0,0,0,1,1,1,1,2,2,2,... First maximum at index 2, second at 6, etc...
            // Example result: [0,0,0,0,0,1,1,1,1,1,2,2,2,2]
            // time = 2.71 ms
            auto kernelThrustPtr = thrust::device_pointer_cast(kernelPtr);
            thrust::exclusive_scan(kernelThrustPtr, kernelThrustPtr + num*channels*imageOffset, kernelThrustPtr);
            // This returns targetPtrOffsetted, with the NMS applied over it
            // time = 1.10 ms
            const dim3 threadsPerBlockWrite{THREADS_PER_BLOCK, 1};
            const dim3 numBlocksWrite{getNumberCudaBlocks(imageOffset, threadsPerBlockWrite.x),
                                      getNumberCudaBlocks(num * channels, threadsPerBlockWrite.z)};
            writeResultAllKernel<<<numBlocksWrite, threadsPerBlockWrite>>>(
                targetPtr, imageOffset, kernelPtr, sourcePtr, width, height,
                maxPeaks, offset.x, offset.y, offsetTarget);

            // // Profiling code
            // OP_CUDA_PROFILE_END(timeNormalize2, 1e3, REPS);
            // log("  NMS1(or)=" + std::to_string(timeNormalize1) + "ms");
            // log("  NMS2(1k)=" + std::to_string(timeNormalize2) + "ms");

            // Sanity check
            cudaCheck(__LINE__, __FUNCTION__, __FILE__);
        }
        catch (const std::exception& e)
        {
            error(e.what(), __LINE__, __FUNCTION__, __FILE__);
        }
    }

    template void nmsGpu(
        float* targetPtr, int* kernelPtr, const float* const sourcePtr, const float threshold,
        const std::array<int, 4>& targetSize, const std::array<int, 4>& sourceSize, const Point<float>& offset);
    template void nmsGpu(
        double* targetPtr, int* kernelPtr, const double* const sourcePtr, const double threshold,
        const std::array<int, 4>& targetSize, const std::array<int, 4>& sourceSize, const Point<double>& offset);
}
