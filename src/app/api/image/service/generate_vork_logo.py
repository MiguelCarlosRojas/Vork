import math
from PIL import Image, ImageDraw, ImageFilter, ImageColor

def create_vork_logo(output_png_path, size=512):
    # Render at 4x resolution for super-sampled anti-aliasing (2048 x 2048)
    canvas_size = 2048
    img = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    
    # 1. Base Squircle / Rounded Container
    # Center (1024, 1024), radius = 860
    center_x, center_y = 1024, 1024
    
    # Create background badge with rounded squircle
    badge_mask = Image.new('L', (canvas_size, canvas_size), 0)
    badge_draw = ImageDraw.Draw(badge_mask)
    margin = 140
    corner_radius = 420
    badge_rect = [margin, margin, canvas_size - margin, canvas_size - margin]
    badge_draw.rounded_rectangle(badge_rect, radius=corner_radius, fill=255)
    
    # Create background gradient (Deep Obsidian / Espresso to Warm Charcoal)
    badge = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(badge)
    
    # Radial dark obsidian background with subtle warm undertone
    for r in range(1100, 0, -4):
        t = r / 1100.0
        # Center color: #231b16 -> Outer color: #0d0a08
        red = int(13 + (35 - 13) * (1.0 - t))
        green = int(10 + (27 - 10) * (1.0 - t))
        blue = int(8 + (22 - 8) * (1.0 - t))
        b_draw.ellipse([center_x - r, center_y - r - 40, center_x + r, center_y + r - 40], fill=(red, green, blue, 255))
        
    # Apply mask
    badge.putalpha(badge_mask)
    img = Image.alpha_composite(img, badge)
    
    # 2. Outer Subtle Rim / Ambient Border (Gradient from #ff7a3d top-left to subtle violet #7c6cf0)
    rim = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    rim_draw = ImageDraw.Draw(rim)
    rim_draw.rounded_rectangle(badge_rect, radius=corner_radius, outline=(255, 122, 61, 160), width=16)
    img = Image.alpha_composite(img, rim)
    
    # 3. Soft Ambient Glow Behind Monogram
    glow = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(glow)
    g_draw.ellipse([center_x - 460, center_y - 200, center_x + 460, center_y + 540], fill=(255, 122, 61, 45))
    glow = glow.filter(ImageFilter.GaussianBlur(80))
    img = Image.alpha_composite(img, glow)
    
    # 4. Constructing the Vork "V" Monogram
    # Geometry coordinates:
    # Top-Left tip of Left Wing: (540, 560)
    # Bottom Vertex of V: (1024, 1530)
    # Top-Right tip of Right Wing: (1508, 560)
    
    # Left Wing (Cream / Pure Architecture #fcf9f5)
    # A sleek, dynamic polygon:
    left_wing = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    lw_draw = ImageDraw.Draw(left_wing)
    
    p1 = (540, 580)   # Top-outer left
    p2 = (740, 580)   # Top-inner left
    p3 = (1024, 1260) # Inner vertex
    p4 = (1024, 1520) # Bottom vertex
    p5 = (890, 1520)  # Bottom outer trim
    
    lw_draw.polygon([p1, p2, p3, p4, p5], fill=(244, 236, 225, 255))
    
    # Add subtle soft shadow from left wing to create depth
    shadow = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow)
    s_draw.polygon([p1, p2, p3, p4, p5], fill=(0, 0, 0, 160))
    shadow = shadow.filter(ImageFilter.GaussianBlur(30))
    img = Image.alpha_composite(img, shadow)
    img = Image.alpha_composite(img, left_wing)
    
    # Right Wing (Vork Radiant Coral/Orange #ff7a3d -> #ff9459)
    right_wing = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    rw_draw = ImageDraw.Draw(right_wing)
    
    q1 = (1024, 1180) # Upper inner junction (overlaps cleanly)
    q2 = (1508, 580)  # Top-outer right
    q3 = (1310, 580)  # Top-inner right
    q4 = (1024, 1420) # Mid descent
    q5 = (1024, 1520) # Bottom point
    
    # Draw right wing with dynamic gradient slices
    rw_draw.polygon([(1024, 1520), (1024, 1240), (1330, 580), (1508, 580)], fill=(255, 122, 61, 255))
    
    # Highlight facet on right wing for 3D metallic/crystal organic bevel
    rw_facet = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    rf_draw = ImageDraw.Draw(rw_facet)
    rf_draw.polygon([(1024, 1520), (1024, 1380), (1420, 580), (1508, 580)], fill=(255, 158, 107, 230))
    right_wing = Image.alpha_composite(right_wing, rw_facet)
    
    # Add shadow under right wing overlapping left wing
    rw_shadow = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    rws_draw = ImageDraw.Draw(rw_shadow)
    rws_draw.polygon([(1024, 1520), (1024, 1240), (1330, 580), (1508, 580)], fill=(0, 0, 0, 140))
    rw_shadow = rw_shadow.filter(ImageFilter.GaussianBlur(24))
    img = Image.alpha_composite(img, rw_shadow)
    img = Image.alpha_composite(img, right_wing)
    
    # 5. Orbital Spark / Multimodal Neural Node
    # Elegant circular node at top right indicating AI intelligence & connectivity
    spark = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    sp_draw = ImageDraw.Draw(spark)
    spark_x, spark_y = 1530, 500
    spark_radius = 56
    
    # Soft glow around spark
    sp_draw.ellipse([spark_x - spark_radius*2, spark_y - spark_radius*2, spark_x + spark_radius*2, spark_y + spark_radius*2], fill=(255, 122, 61, 90))
    spark = spark.filter(ImageFilter.GaussianBlur(16))
    
    # Solid core of spark
    sp_core = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    spc_draw = ImageDraw.Draw(sp_core)
    spc_draw.ellipse([spark_x - spark_radius, spark_y - spark_radius, spark_x + spark_radius, spark_y + spark_radius], fill=(255, 245, 235, 255))
    spc_draw.ellipse([spark_x - spark_radius + 12, spark_y - spark_radius + 12, spark_x + spark_radius - 12, spark_y + spark_radius - 12], fill=(255, 122, 61, 255))
    
    img = Image.alpha_composite(img, spark)
    img = Image.alpha_composite(img, sp_core)
    
    # 6. Downsample using Lanczos filter for pristine, ultra-sharp rendering
    final_img = img.resize((size, size), Image.Resampling.LANCZOS)
    final_img.save(output_png_path, format='PNG', optimize=True)
    print(f"Successfully generated Vork logo at {output_png_path} ({size}x{size})")

if __name__ == '__main__':
    create_vork_logo('src/web/img/logo.png', size=512)
