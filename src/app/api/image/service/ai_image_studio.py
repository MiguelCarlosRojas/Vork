#!/usr/bin/env python3
"""
ai_image_studio.py
Motor de Procesamiento de Imágenes y Eliminación / Modificación de Fondos con IA
Parte de Vork - Pilares 07 y 08
"""

import sys
import os
import json
import argparse
from io import BytesIO

try:
    from PIL import Image, ImageOps
except ImportError:
    print(json.dumps({"status": "error", "message": "Pillow (PIL) no está instalado."}))
    sys.exit(1)

def hex_to_rgb(hex_str):
    """Convierte cadena hex #RRGGBB a tupla (R, G, B)"""
    hex_str = hex_str.lstrip("#")
    if len(hex_str) == 3:
        hex_str = "".join([c * 2 for c in hex_str])
    if len(hex_str) != 6:
        return (255, 255, 255)
    return tuple(int(hex_str[i:i+2], 16) for i in (0, 2, 4))

def convert_image(input_path, output_path, target_format, quality=90, width=None, height=None, fit="contain"):
    """
    Convierte una imagen a cualquier formato estándar (PNG, JPG, WEBP, GIF, BMP, TIFF, ICO).
    Permite redimensionar y ajustar calidad.
    """
    if not os.path.exists(input_path):
        raise FileNotFoundError(f"Archivo no encontrado: {input_path}")

    with Image.open(input_path) as img:
        # Orientación EXIF automática si existe
        try:
            img = ImageOps.exif_transpose(img)
        except Exception:
            pass

        orig_w, orig_h = img.size
        new_w, new_h = orig_w, orig_h

        # Redimensionar si se solicita
        if width and height:
            new_w, new_h = int(width), int(height)
            img = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
        elif width:
            new_w = int(width)
            new_h = int((new_w / orig_w) * orig_h)
            img = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
        elif height:
            new_h = int(height)
            new_w = int((new_h / orig_h) * orig_w)
            img = img.resize((new_w, new_h), Image.Resampling.LANCZOS)

        norm_format = target_format.lower().replace(".", "").strip()
        save_kwargs = {}

        if norm_format in ("jpg", "jpeg"):
            # JPEG no soporta canal alfa (RGBA). Convertir a RGB sobre fondo blanco.
            if img.mode in ("RGBA", "LA", "P"):
                bg = Image.new("RGB", img.size, (255, 255, 255))
                if img.mode == "P":
                    img = img.convert("RGBA")
                bg.paste(img, mask=img.split()[-1] if img.mode == "RGBA" else None)
                img = bg
            elif img.mode != "RGB":
                img = img.convert("RGB")
            save_kwargs["quality"] = max(1, min(100, int(quality)))
            save_kwargs["optimize"] = True
            save_format = "JPEG"

        elif norm_format == "png":
            if img.mode not in ("RGBA", "RGB", "L"):
                img = img.convert("RGBA")
            save_kwargs["optimize"] = True
            save_format = "PNG"

        elif norm_format == "webp":
            if img.mode not in ("RGBA", "RGB"):
                img = img.convert("RGBA")
            save_kwargs["quality"] = max(1, min(100, int(quality)))
            save_kwargs["method"] = 6
            save_format = "WEBP"

        elif norm_format == "gif":
            img = img.convert("RGB").convert("P", palette=Image.Palette.ADAPTIVE)
            save_format = "GIF"

        elif norm_format == "bmp":
            if img.mode not in ("RGB", "L"):
                img = img.convert("RGB")
            save_format = "BMP"

        elif norm_format in ("tiff", "tif"):
            save_format = "TIFF"
            save_kwargs["compression"] = "tiff_deflate"

        elif norm_format == "ico":
            # Para favicon / ICO
            ico_sizes = [(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
            if img.mode != "RGBA":
                img = img.convert("RGBA")
            save_format = "ICO"
            save_kwargs["sizes"] = ico_sizes

        else:
            save_format = norm_format.upper()

        os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
        img.save(output_path, format=save_format, **save_kwargs)

        out_size = os.path.getsize(output_path)
        return {
            "status": "success",
            "format": norm_format,
            "width": new_w,
            "height": new_h,
            "orig_width": orig_w,
            "orig_height": orig_h,
            "size_bytes": out_size,
            "output_path": output_path
        }

def remove_background(input_path, output_path, mode="transparent", color=None, bg_image_path=None):
    """
    Elimina el fondo de una imagen usando rembg (U2-Net / IA local sin límites ni costo).
    Soporta los siguientes modos:
      - 'transparent': Guarda como PNG con canal alfa transparente.
      - 'color': Reemplaza el fondo con un color HEX especificado (ej: '#ffffff').
      - 'custom_bg': Compone el recorte sobre una imagen de fondo especificada.
    """
    if not os.path.exists(input_path):
        raise FileNotFoundError(f"Archivo de entrada no encontrado: {input_path}")

    try:
        from rembg import remove, new_session
    except ImportError:
        raise RuntimeError("La librería 'rembg' no está disponible en este entorno.")

    with Image.open(input_path) as img:
        try:
            img = ImageOps.exif_transpose(img)
        except Exception:
            pass

        orig_w, orig_h = img.size

        # Ejecutar segmentación de rembg
        # u2net es el modelo por defecto de alta fidelidad
        cutout = remove(img)

        # cutout es una imagen RGBA con el sujeto recortado y fondo transparente
        final_img = None

        if mode == "transparent":
            final_img = cutout
            save_format = "PNG"

        elif mode == "color":
            rgb_color = hex_to_rgb(color or "#FFFFFF")
            canvas = Image.new("RGBA", (orig_w, orig_h), (*rgb_color, 255))
            canvas.paste(cutout, mask=cutout.split()[3])
            final_img = canvas.convert("RGB")
            save_format = "JPEG"

        elif mode in ("custom_bg", "prompt"):
            if not bg_image_path or not os.path.exists(bg_image_path):
                raise ValueError(f"Imagen de fondo no encontrada: {bg_image_path}")

            with Image.open(bg_image_path) as bg:
                try:
                    bg = ImageOps.exif_transpose(bg)
                except Exception:
                    pass
                # Redimensionar y recortar el fondo para encajar exactamente con el tamaño del sujeto
                bg_fitted = ImageOps.fit(bg, (orig_w, orig_h), method=Image.Resampling.LANCZOS)
                if bg_fitted.mode != "RGBA":
                    bg_fitted = bg_fitted.convert("RGBA")
                
                # Pegar el sujeto recortado sobre el fondo generado o subido
                bg_fitted.paste(cutout, mask=cutout.split()[3])
                final_img = bg_fitted.convert("RGB")
                save_format = "PNG"

        else:
            final_img = cutout
            save_format = "PNG"

        os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
        if save_format == "JPEG":
            final_img.save(output_path, format="JPEG", quality=95, optimize=True)
        else:
            final_img.save(output_path, format="PNG", optimize=True)

        out_size = os.path.getsize(output_path)
        return {
            "status": "success",
            "mode": mode,
            "width": orig_w,
            "height": orig_h,
            "size_bytes": out_size,
            "format": save_format.lower(),
            "output_path": output_path
        }

def main():
    parser = argparse.ArgumentParser(description="Vork AI Image Studio CLI")
    subparsers = parser.add_subparsers(dest="action", required=True)

    # Subcomando convert
    convert_parser = subparsers.add_parser("convert")
    convert_parser.add_argument("--input", required=True, help="Ruta de imagen de entrada")
    convert_parser.add_argument("--output", required=True, help="Ruta de imagen de salida")
    convert_parser.add_argument("--format", required=True, help="Formato destino (png, jpg, webp, etc.)")
    convert_parser.add_argument("--quality", type=int, default=90, help="Calidad (1-100)")
    convert_parser.add_argument("--width", type=int, default=None, help="Ancho opcional")
    convert_parser.add_argument("--height", type=int, default=None, help="Alto opcional")

    # Subcomando remove-bg
    bg_parser = subparsers.add_parser("remove-bg")
    bg_parser.add_argument("--input", required=True, help="Ruta de imagen de entrada")
    bg_parser.add_argument("--output", required=True, help="Ruta de imagen de salida")
    bg_parser.add_argument("--mode", default="transparent", choices=["transparent", "color", "custom_bg", "prompt"])
    bg_parser.add_argument("--color", default="#FFFFFF", help="Color HEX para modo color")
    bg_parser.add_argument("--bg-image", default=None, help="Ruta a imagen de fondo para modo custom_bg/prompt")

    args = parser.parse_args()

    try:
        if args.action == "convert":
            res = convert_image(
                input_path=args.input,
                output_path=args.output,
                target_format=args.format,
                quality=args.quality,
                width=args.width,
                height=args.height
            )
            print(json.dumps(res))

        elif args.action == "remove-bg":
            res = remove_background(
                input_path=args.input,
                output_path=args.output,
                mode=args.mode,
                color=args.color,
                bg_image_path=args.bg_image
            )
            print(json.dumps(res))

    except Exception as e:
        err = {"status": "error", "message": str(e)}
        print(json.dumps(err), file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
