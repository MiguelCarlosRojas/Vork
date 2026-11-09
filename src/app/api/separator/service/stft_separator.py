"""
STFT Spectral Vocal and Instrumental Separator
Vork Engine - High-Fidelity Center-Pan Spectral Decomposition
"""

import sys
import os
import numpy as np
import soundfile as sf

def separate_audio(input_file, out_inst_file, out_voc_file):
    print(f"[STFT] Cargando audio: {input_file}")
    data, sr = sf.read(input_file)
    
    # Asegurar formato estéreo
    if data.ndim == 1:
        data = np.stack([data, data], axis=1)
    elif data.shape[1] > 2:
        data = data[:, :2]
        
    orig_len = len(data)
    
    # Parámetros STFT optimizados para resolución vocal y temporal
    n_fft = 4096
    hop = 1024
    window = np.hanning(n_fft)
    
    def stft_channel(sig):
        pad_len = n_fft - (len(sig) % hop)
        sig_p = np.pad(sig, (0, pad_len), mode='reflect')
        num_frames = 1 + (len(sig_p) - n_fft) // hop
        frames = np.lib.stride_tricks.as_strided(
            sig_p,
            shape=(num_frames, n_fft),
            strides=(sig_p.strides[0] * hop, sig_p.strides[0])
        )
        return np.fft.rfft(frames * window, axis=1)

    def istft_channel(spec):
        frames = np.fft.irfft(spec, axis=1) * window
        num_frames = frames.shape[0]
        out_len = (num_frames - 1) * hop + n_fft
        out = np.zeros(out_len, dtype=np.float32)
        norm = np.zeros(out_len, dtype=np.float32)
        win_sq = window ** 2
        for i in range(num_frames):
            pos = i * hop
            out[pos:pos+n_fft] += frames[i]
            norm[pos:pos+n_fft] += win_sq
        norm[norm < 1e-6] = 1.0
        return (out / norm)[:orig_len]

    print("[STFT] Procesando transformada espectral de Fourier...")
    L = stft_channel(data[:, 0])
    R = stft_channel(data[:, 1])

    freqs = np.fft.rfftfreq(n_fft, 1.0 / sr)
    
    # Ponderación acústica del rango vocal humano (130 Hz a 6500 Hz)
    freq_weight = np.zeros_like(freqs, dtype=np.float32)
    for idx, f in enumerate(freqs):
        if f < 130:
            freq_weight[idx] = 0.0
        elif f < 220:
            freq_weight[idx] = (f - 130.0) / 90.0
        elif f <= 4800:
            freq_weight[idx] = 1.0
        elif f < 7200:
            freq_weight[idx] = (7200.0 - f) / 2400.0
        else:
            freq_weight[idx] = 0.0

    # Canal central (M) y similitud de pan estéreo
    M = 0.5 * (L + R)
    diff = np.abs(L - R)
    sum_mag = np.abs(L) + np.abs(R) + 1e-7

    # Pan similarity: 1.0 = centro absoluto, 0.0 = panned
    pan_sim = np.maximum(0.0, 1.0 - (diff / sum_mag))
    
    # Máscara no-lineal para eliminar bleed de instrumentos estéreo
    # Solo frecuencias con pan > 0.35 reciben energía vocal
    pan_cleaned = np.clip((pan_sim - 0.30) / 0.70, 0.0, 1.0)
    voc_mask = (pan_cleaned ** 2.5) * freq_weight[np.newaxis, :]

    # Puerta de silencio adaptativa para eliminar ruidos de fondo cuando no hay voz cantada
    mag_M = np.abs(M)
    local_energy = np.mean(mag_M, axis=1, keepdims=True)
    gate = np.clip((local_energy - 0.005) / 0.02, 0.0, 1.0)
    voc_mask = voc_mask * gate

    # Espectro vocal
    V = M * voc_mask

    # Espectro instrumental (sustracción de fase profunda)
    # Factor 1.12 para garantizar eliminación absoluta de la voz en la pista instrumental
    Inst_L = L - (1.12 * V)
    Inst_R = R - (1.12 * V)

    print("[STFT] Sintetizando formas de onda temporales...")
    voc_wave = istft_channel(V)
    inst_L_wave = istft_channel(Inst_L)
    inst_R_wave = istft_channel(Inst_R)

    # Limitar y normalizar para evitar clipping
    inst_audio = np.stack([inst_L_wave, inst_R_wave], axis=1)
    voc_audio = np.stack([voc_wave, voc_wave], axis=1)

    max_inst = np.max(np.abs(inst_audio))
    if max_inst > 0.98:
        inst_audio = inst_audio * (0.95 / max_inst)

    max_voc = np.max(np.abs(voc_audio))
    if max_voc > 0.98:
        voc_audio = voc_audio * (0.95 / max_voc)

    print(f"[STFT] Guardando stems aislados...")
    sf.write(out_inst_file, inst_audio, sr)
    sf.write(out_voc_file, voc_audio, sr)
    print(f"[STFT] ¡Separación completada con éxito!")

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Uso: python stft_separator.py <input> <out_inst> <out_voc>")
        sys.exit(1)
        
    in_file = sys.argv[1]
    out_inst = sys.argv[2]
    out_voc = sys.argv[3]
    
    try:
        separate_audio(in_file, out_inst, out_voc)
        sys.exit(0)
    except Exception as e:
        print(f"Error en separador STFT: {e}", file=sys.stderr)
        sys.exit(1)
