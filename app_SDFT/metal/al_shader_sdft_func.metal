//
//  al_shader_sdft_func.metal
//  xaoc_sdft
//
//  Created by Adam Łuczak on 17/08/2023.
//

#include <metal_stdlib>
using namespace metal;

half4 colorFromValue(float value)
{
    // Zakładamy, że wartość jest już znormalizowana do zakresu [0, 1]
    
    half r = clamp((half)(4.0f * (value - 0.25f)), 0.0h, 1.0h);
    half g = clamp((half)(4.0f * value), 0.0h, 1.0h);
    half b = clamp((half)(4.0f * (0.25f - value)), 0.0h, 1.0h);

    return half4(r, g, b, 1.0h);  // RGB + pełna przezroczystość
}

kernel void al_shader_sdft_func(    device              float          *sdft_real       [[buffer(0)]],
                                    device              float          *sdft_imag       [[buffer(1)]],
                                    device              float          *magOrg          [[buffer(2)]],
                                    device              float          *magOut          [[buffer(3)]],
                                    device              float          *audio_channnel  [[buffer(4)]],
                                    device              float          *audio_buffer    [[buffer(5)]],
                                
                                    device              simd_float3    *colors          [[buffer(6)]],

                                    texture2d<half ,    access::write> outMask          [[texture(0)]],

                                    const uint tid [[ thread_position_in_threadgroup ]],
                                    const uint gid [[ threadgroup_position_in_grid ]]    )
{
    const float min_dB      = -100.0f;
    const float max_dB      = 0.0f;
    const float _PI         = 3.1415926535897932385;
    
    uint        begin       = tid<<2;
    
    for(uint j = 0;j<2048;j++)
    {
        uint    pos         = begin;
        float   sample      = audio_channnel[j];
        float   old         = audio_buffer[j];
        uint    mod         = j & 63;
        
        for(uint i = 0;i<4;i++)
        {
            float re        = sdft_real[pos];
            float im        = sdft_imag[pos];
            
            // czynnik korekcji fazy zalezny od pos
            float fs_re     =  cos(float(pos) * ((2.0 * _PI) / 2048.0) );
            float fs_im     = -sin(float(pos) * ((2.0 * _PI) / 2048.0) );
            
            float re_re     = re * fs_re;
            float re_im     = re * fs_im;
            float im_re     = im * fs_re;
            float im_im     = im * fs_im;
            
            float new_re    = re_re - im_im + (sample - old)/2048;
            float new_im    = re_im + im_re;
            
            sdft_real[pos]  = new_re;
            sdft_imag[pos]  = new_im;
            pos++;
        }

        if(mod == 63)
        {
            uint row = 31 - j/64;
            
            for(uint i = 0;i<4;i++)
            {
                float re        = sdft_real[pos];
                float im        = sdft_imag[pos];

                float magSq     = sqrt(re * re + im * im);
                float magdB     = - INFINITY;
                
                if(magSq > 0.0f)
                {
                    magdB = 20.0f * log10(magSq);
                }
                
                magOrg[pos] = magdB;
                
                // Znormalizuj wartość magnitudy do zakresu [0, 1]
                float normalizedMag = (magdB - min_dB) / (max_dB - min_dB);
                normalizedMag = clamp(normalizedMag, 0.0f, 1.0f);  // Upewnij się, że wartość jest w zakresie [0, 1]
                
                // Przelicz na kolor
                
                uint index              = uint(normalizedMag*1024);
                simd_float3 colorValue  = colors[index];
                
                half4 color = half4(half(colorValue.x), half(colorValue.y), half(colorValue.z), 1.0h);

                // Zapisz kolor do tekstury
                if(pos<1024)
                {
                    outMask.write(color, uint2(pos, row));
                }
                
                pos++;
            }
        }
    }
}


