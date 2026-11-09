"""
AI Demucs v4 Neural Stem Separator (HT-Demucs ONNX)
Vork Engine - State-of-the-Art Source Separation
Pure Deep Neural Network Stem Extraction (Vocals vs Instrumental / Karaoke)
"""

import sys
import os
import time
import numpy as np
import demucs_onnx

def separate_stems(input_path, out_inst_path, out_voc_path, bitrate=320):
    start_time = time.time()
    print(f"[Demucs AI] Iniciando separacion neuronal profunda con Meta HT-Demucs v4...")
    print(f"[Demucs AI] Archivo de entrada: {input_path}")
    
    if not os.path.exists(input_path):
        raise FileNotFoundError(f"Archivo de audio no encontrado: {input_path}")

    # Cargar audio de entrada (con remuestreo a 44100 Hz y 2 canales estéreo)
    audio, sr = demucs_onnx.load_audio(input_path)
    print(f"[Demucs AI] Audio cargado: {audio.shape[1] / sr:.2f} segundos, {sr} Hz, {audio.shape[0]} canales.")

    # Ejecutar inferencia de la red neuronal HT-Demucs
    print("[Demucs AI] Ejecutando inferencia neuronal sobre tensores espectrales...")
    stems = demucs_onnx.separate(
        input_path,
        model="htdemucs",
        precision="fp32",
        verbose=False,
        progress=True
    )

    if "vocals" not in stems:
        raise ValueError("La red neuronal no devolvió el stem de voces.")

    # 1. Stem Vocal puro aislado por la red neuronal
    vocals = stems["vocals"]

    # 2. Stem Instrumental puro (Suma de Batería + Bajo + Otros Instrumentos)
    instrumental = stems["drums"] + stems["bass"] + stems["other"]

    # Normalización de picos a nivel alto (-0.17 dBFS / 0.98) para máximo volumen acústico sin distorsión
    max_inst = np.max(np.abs(instrumental))
    if max_inst > 0.001:
        instrumental = instrumental * (0.98 / max_inst)

    max_voc = np.max(np.abs(vocals))
    if max_voc > 0.001:
        vocals = vocals * (0.98 / max_voc)

    print(f"[Demucs AI] Guardando stem instrumental en: {out_inst_path}")
    if out_inst_path.lower().endswith(".mp3"):
        demucs_onnx.write_mp3(out_inst_path, instrumental, sr, bitrate_kbps=int(bitrate))
    else:
        demucs_onnx.write_wav(out_inst_path, instrumental, sr)

    print(f"[Demucs AI] Guardando stem vocal en: {out_voc_path}")
    if out_voc_path.lower().endswith(".mp3"):
        demucs_onnx.write_mp3(out_voc_path, vocals, sr, bitrate_kbps=int(bitrate))
    else:
        demucs_onnx.write_wav(out_voc_path, vocals, sr)

    elapsed = time.time() - start_time
    print(f"[Demucs AI] ¡Separacion completada con éxito en {elapsed:.2f} segundos!")

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Uso: python ai_demucs_separator.py <input> <out_instrumental> <out_vocals> [bitrate_kbps]")
        sys.exit(1)

    in_file = sys.argv[1]
    out_inst = sys.argv[2]
    out_voc = sys.argv[3]
    bitrate = int(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[4].isdigit() else 320

    try:
        separate_stems(in_file, out_inst, out_voc, bitrate)
        sys.exit(0)
    except Exception as e:
        print(f"Error en separador Demucs AI: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)
