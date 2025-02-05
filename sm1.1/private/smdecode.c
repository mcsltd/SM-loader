#include "mex.h"
#include "matrix.h"
#include <stdint.h>


// decode(int8_data_array, out_size, max_bytes_per_simple, uv_per_bit)
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    /* Check inputs/outputs */

    #ifndef MX_HAS_INTERLEAVED_COMPLEX
    mexErrMsgIdAndTxt("SMLOADER:decode", "This file must be built with -R2018a flag");
    #endif

    if (nrhs != 4)
        mexErrMsgIdAndTxt("SMLOADER:decode",
                          "Expected 4 inputs to decode (the data)");
    if (nlhs > 1)
        mexErrMsgIdAndTxt("SMLOADER:decode", "Expected one output for decode");

    if ( !mxIsInt8(prhs[0]) && !mxIsUint8(prhs[0]) ){
        mexErrMsgIdAndTxt(
            "SMLOADER:decode",
            "Expected the first argument to be a int8 or uint8 array");
    }

    int8_t *data = (int8_t*)mxGetInt8s(prhs[0]);
    int data_size = (int)mxGetNumberOfElements(prhs[0]);
    int frame_size = (int)mxGetScalar(prhs[1]);
    int MAX_BYTES = (int)mxGetScalar(prhs[2]);
    float uv_per_bit = (float)mxGetScalar(prhs[3]);

    //mexPrintf("The inputs: data_size=%d; frame_size=%d; max_bytes=%d; uv_per_bit = %f\n",
    //          data_size, frame_size,MAX_BYTES, uv_per_bit);

    plhs[0] = mxCreateNumericMatrix(1, frame_size, mxSINGLE_CLASS, mxREAL);
    float *samples = (float *)mxGetSingles(plhs[0]);
    
    int i = 0;
    int tick_counter = 0;
    int32_t val = 0;
    while (i < data_size && tick_counter < frame_size) {
        if (data[i] != INT8_MAX) {
            val = val + data[i];
            i += 1;
        } else {
            i += 1;
            if ( i+1 >= data_size) break;
            int16_t diff = *(int16_t*)&data[i];
            if (diff != INT16_MAX || MAX_BYTES == 2) {
                val = val + diff;
                i += 2;
            } else {
                i += 2;
                if (MAX_BYTES == 3) {
                    if (i+2 >= data_size) break;
                    int32_t diff = 0;
                    int8_t *pdiff = (int8_t*)&diff;
                    pdiff[0] = data[i];
                    pdiff[1] = data[i + 1];
                    pdiff[2] = data[i + 2];
                    diff >>= 8;
                    val = val + diff;
                    i += 3;
                }
                else {
                    if (i+3 >= data_size) break;
                    val = val + *(int32_t *)&data[i];
                    i += 4;
                }
            }
        }

        samples[tick_counter] = uv_per_bit * val;
        tick_counter++;
    }

    if (i < data_size) {
        mexWarnMsgIdAndTxt("SMLOADER:decode", "Unused data in frame found");
    }
    if (tick_counter != frame_size) {
        mexErrMsgIdAndTxt("SMLOADER:decode",
                          "Not enough data in frame. Frame is corrupted (%d decoded, i=%d)", tick_counter,i);
    }
}