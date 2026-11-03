"""Generate a monochrome subset ROM and offline previews; no FPGA/TF writes.

Requires Pillow. Paths default to this repository, independent of working directory.
Glyph ID 0 is space; row bit 15 is the leftmost pixel. Texts are length-delimited.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, __version__ as pillow_version

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CATALOG = ROOT / "assets/exhibition/captions/catalog.json"
DEFAULT_OUTPUT = ROOT / "assets/exhibition/captions/generated"


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--font", type=Path, default=Path("C:/Windows/Fonts/msyh.ttc"))
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--rtl-output", type=Path, help="Also deploy the generated ROM module to this explicit path")
    parser.add_argument("--background-dir", type=Path, help="640x480 preview backgrounds; defaults to the catalog path")
    args = parser.parse_args()
    config = json.loads(args.catalog.read_text(encoding="utf-8"))
    if args.background_dir is None:
        args.background_dir = ROOT / config.get("preview_background_dir", "artifacts/exhibition_stage0_20261019/control_images")
    if config["cell_width"] != 16 or config["cell_height"] != 16:
        raise ValueError("This ROM layout requires 16x16 cells")
    captions = [dict(c) for c in config["captions"]]
    for caption in captions:
        if "text_file" in caption:
            caption["text"] = (ROOT / caption["text_file"]).read_text(encoding="utf-8").strip()
    glyph_limit = config.get("glyph_limit", 64)
    if not 1 <= glyph_limit <= 256:
        raise ValueError("Glyph limit must fit the 8-bit ID")
    if [c["picture"] for c in captions] != [f"PIC{i}.BMP" for i in range(1, 5)]:
        raise ValueError("Caption order must be PIC1..PIC4")
    stride = config["text_stride"]
    if stride != 128 or any(not 0 < len(c["text"]) <= 89 for c in captions):
        raise ValueError("Text length must be 1..89 for the 11-bit scroll cycle")
    label_lines = [c.get("artwork_label", ["", ""]) for c in captions]
    if any(len(lines) != 2 or any(len(line) > 16 for line in lines) for lines in label_lines):
        raise ValueError("Artwork label needs two lines of at most 16 cells")
    card_texts = [lines[0].ljust(16) + lines[1].ljust(16) + c.get("preview_lookpoint", "").ljust(32) for c, lines in zip(captions, label_lines)]
    if any(len(text) != 64 for text in card_texts):
        raise ValueError("Preview card text exceeds 16/16/32 cells")
    label_texts = ["".join(line.ljust(16) for line in lines) for lines in label_lines]
    chars = [" "]
    for char in "".join(c["text"] for c in captions) + config["extra_characters"] + "".join(label_texts) + "".join(card_texts):
        if char not in chars:
            chars.append(char)
    if len(chars) > glyph_limit:
        raise ValueError("Subset exceeds selected glyph storage/address budget")
    font = ImageFont.truetype(str(args.font), config["font_size_px"], index=0)
    bounds = [font.getbbox(c) for c in chars if c != " "]
    top, bottom = min(b[1] for b in bounds), max(b[3] for b in bounds)
    if bottom - top > 16:
        raise ValueError(f"Shared vertical bounds {top}..{bottom} do not fit")
    y_offset = (16 - (bottom - top)) // 2 - top
    masks = []
    for char in chars:
                                                                                 
        canvas = Image.new("L", (64, 64))
        bbox = font.getbbox(char)
        x_offset = (16 - (bbox[2] - bbox[0])) // 2 - bbox[0]
        ImageDraw.Draw(canvas).text((24 + x_offset, 24 + y_offset), char, font=font, fill=255)
        binary = canvas.point(lambda p: 255 if p >= 128 else 0)
        cell = binary.crop((24, 24, 40, 40))
        if sum(binary.tobytes()) != sum(cell.tobytes()):
            raise ValueError(f"Clipped glyph: {char!r}")
        if char != " " and not cell.getbbox():
            raise ValueError(f"Empty glyph: {char!r}")
        masks.append(cell)
    if masks[0].getbbox() is not None:
        raise ValueError("Space must be blank")
                                                                            
    if len({mask.tobytes() for mask in masks[1:]}) != len(masks) - 1:
        raise ValueError("Duplicate glyph bitmap: inspect unsupported font characters")
    ids = {c: i for i, c in enumerate(chars)}
    rows = []
    for mask in masks:
        for y in range(16):
            rows.append(sum((1 << (15 - x)) for x in range(16) if mask.getpixel((x, y))))
    glyph_depth = 1 << (len(rows) - 1).bit_length()
    rows += [0] * (glyph_depth - len(rows))
    card_ids = [ids[ch] for text in card_texts for ch in text]
    text_ids = []
    for index, caption in enumerate(captions):
        encoded = [ids[c] for c in caption["text"]]
        text_ids.extend(encoded + [0] * (96 - len(encoded)) + [ids[c] for c in label_texts[index]])
    out = args.output
    out.mkdir(parents=True, exist_ok=True)
    (out / "glyph_rows.hex").write_text("".join(f"{row:04x}\n" for row in rows), encoding="ascii")
    (out / "preview_card_ids.hex").write_text("".join(f"{gid:02x}\n" for gid in card_ids), encoding="ascii")
    (out / "text_ids.hex").write_text("".join(f"{gid:02x}\n" for gid in text_ids), encoding="ascii")
    write_json(out / "glyph_map.json", [{"id": i, "character": c, "unicode": f"U+{ord(c):04X}"} for i, c in enumerate(chars)])
    lengths = [len(c["text"]) for c in captions]
    header = [
              f"localparam integer CAPTION_GLYPH_COUNT = {len(chars)};",
              f"localparam integer CAPTION_GLYPH_ROW_DEPTH = {glyph_depth};",
              f"localparam integer CAPTION_TEXT_STRIDE = {stride};"]
    header += [f"localparam integer CAPTION_LENGTH_{i} = {n};" for i, n in enumerate(lengths)]
    (out / "caption_config.vh").write_text("\n".join(header) + "\n", encoding="ascii")
                                                                              
    rtl = [
           "module exhibit_caption_roms(input wire clk,",
           " input wire card_mode, input wire [7:0] card_addr,",
           " input wire [8:0] text_addr, output reg [7:0] text_id,",
           " input wire [11:0] glyph_addr, output reg [15:0] glyph_row,",
           " input wire [1:0] picture, output reg [6:0] text_length);",
           "always @(posedge clk) begin", " case (text_addr)"]
    rtl += [f" 9'd{i}: text_id <= 8'h{value:02x};" for i, value in enumerate(text_ids) if value]
    rtl += [" default: text_id <= 8'd0;", " endcase", " if (card_mode) begin", " case (card_addr)"]
    rtl += [f" 8'd{i}: text_id <= 8'h{value:02x};" for i, value in enumerate(card_ids) if value]
    rtl += [" default: text_id <= 8'd0;", " endcase", " end", " case (glyph_addr)"]
    rtl += [f" 12'd{i}: glyph_row <= 16'h{value:04x};" for i, value in enumerate(rows) if value]
    rtl += [" default: glyph_row <= 16'd0;", " endcase", "end", "always @* begin", " case (picture)"]
    rtl += [f" 2'd{i}: text_length = 7'd{length};" for i, length in enumerate(lengths)]
    rtl += [" endcase", "end", "endmodule"]
    (out / "exhibit_caption_roms.v").write_text("\n".join(rtl) + "\n", encoding="ascii")
    if args.rtl_output:
        args.rtl_output.write_text("\n".join(rtl) + "\n", encoding="ascii")

                                                                               
    disk_rows = [int(s, 16) for s in (out / "glyph_rows.hex").read_text().split()]
    disk_ids = [int(s, 16) for s in (out / "text_ids.hex").read_text().split()]
    decoded_masks = []
    for gid, expected in enumerate(masks):
        reconstructed = Image.new("L", (16, 16))
        for y in range(16):
            for x in range(16):
                reconstructed.putpixel((x, y), 255 if disk_rows[gid * 16 + y] & (0x8000 >> x) else 0)
        if reconstructed.tobytes() != expected.tobytes():
            raise AssertionError("ROM roundtrip changed orientation or pixels")
        decoded_masks.append(reconstructed)
    for i, caption in enumerate(captions):
        block = disk_ids[i * stride:(i + 1) * stride]
        if "".join(chars[gid] for gid in block[:lengths[i]]) != caption["text"] or any(block[lengths[i]:96]) or "".join(chars[gid] for gid in block[96:]) != label_texts[i]:
            raise AssertionError("Text ROM roundtrip or padding failed")
    if any(disk_rows[len(chars) * 16:]):
        raise AssertionError("Glyph padding must be blank")

    atlas = Image.new("RGB", (8 * 100, math.ceil(len(chars) / 8) * 92), "#18202a")
    draw = ImageDraw.Draw(atlas)
    for gid, mask in enumerate(decoded_masks):
        x, y = (gid % 8) * 100, (gid // 8) * 92
        draw.text((x + 6, y + 3), f"ID {gid:02d}", fill="white")
        enlarged = mask.resize((48, 48), Image.Resampling.NEAREST)
        atlas.paste("white", (x + 24, y + 26), enlarged)
        draw.rectangle((x + 23, y + 25, x + 72, y + 74), outline="#607080")
    atlas.save(out / "glyph_atlas.png")

    def strip_for(index):
        strip = Image.new("L", (lengths[index] * 16, 16))
        for pos in range(lengths[index]):
            strip.paste(decoded_masks[disk_ids[index * stride + pos]], (pos * 16, 0))
        return strip

    strips = [strip_for(i) for i in range(4)]
    long_preview = Image.new("RGB", (max(s.width for s in strips) + 32, 4 * 48), "#18202a")
    for i, strip in enumerate(strips):
        long_preview.paste("white", (16, i * 48 + 16), strip)
    long_preview.save(out / "all_captions.png")
    backgrounds = []
    for caption in captions:
        with Image.open(args.background_dir / caption["picture"]) as img:
            if img.size != (640, 480):
                raise ValueError("Offline control backgrounds must be 640x480")
            backgrounds.append(img.convert("RGB"))

    def frame(index, scroll):
        image = backgrounds[index].copy()
        band = image.crop((0, 432, 640, 480)).point([v >> 2 for v in range(256)] * 3)
        image.paste(band, (0, 432))
                                                                                 
        strip = strips[index]
        cycle = strip.width + 608
        window = Image.new("L", (608, 16))
        for copy in (-1, 0, 1):
            window.paste(strip, (-scroll % cycle + copy * cycle, 0))
        image.paste((240, 244, 248), (16, 448), window)
        return image

    for i in range(4):
        frame(i, 0).save(out / f"preview_pic{i + 1}.png")
    for i, lines in enumerate(label_lines):
        image = backgrounds[i].copy()
        panel = image.crop((352, 16, 624, 64)).point([v >> 1 for v in range(256)] * 3)
        image.paste(panel, (352, 16))
        for row, line in enumerate(lines):
            for col, char in enumerate(line):
                image.paste((240, 228, 200) if row == 0 else (224, 228, 232),
                            (360+col*16, 20+row*20), decoded_masks[ids[char]])
        image.save(out / f"artwork_label_pic{i+1}.png")
    if [int(v, 16) for v in (out / "preview_card_ids.hex").read_text().split()] != card_ids:
        raise AssertionError("Preview card text serialization changed")
    for focus in range(4):
        image = Image.new("RGB", (640, 480), "#101820")
        for i, background in enumerate(backgrounds):
            thumb = background.resize((64, 48), Image.Resampling.NEAREST).resize((192, 144), Image.Resampling.NEAREST)
            tx, ty = (384 if i % 2 else 64), (192 if i // 2 else 24)
            image.paste(thumb, (tx, ty))
            draw = ImageDraw.Draw(image)
            draw.rectangle((tx, ty, tx+191, ty+143), outline="#ffcc20" if i == focus else "#607080", width=3)
        ImageDraw.Draw(image).rectangle((48, 352, 591, 455), fill="#1c2a38")
        for row, (first, count, color) in enumerate([(0,16,(240,228,200)), (16,16,(184,200,216)), (32,32,(240,244,248))]):
            for col in range(count):
                gid = card_ids[focus*64+first+col]
                image.paste(color, (64+col*16, 364+row*24), decoded_masks[gid])
        image.save(out / f"preview_card_pic{focus+1}.png")
                                                                               
    cycle = strips[0].width + 608
    offsets = list(range(0, cycle, 16))
    animation = [frame(0, offset).quantize(colors=128) for offset in offsets]
    animation[0].save(out / "scroll_preview.gif", save_all=True, append_images=animation[1:], duration=200, loop=0, optimize=False)

    font_blocks = math.ceil(glyph_depth / 512)                                  
    text_blocks = math.ceil(len(text_ids) / 1024)                                  
    manifest = {
        "schema_version": 1,
        "content_status": config["content_status"],
        "catalog_sha256": sha256(args.catalog),
        "font": {"file": args.font.name, "collection_index": 0, "sha256": sha256(args.font), "size_px": config["font_size_px"], "pillow": pillow_version, "threshold": 128, "shared_y_offset": y_offset},
        "layout": {"cell": [16, 16], "row_address": "glyph_id * 16 + y", "leftmost_bit": 15, "text_address": "picture_index * 128 + character_index", "space_id": 0, "artwork_label_offsets": [96,112], "termination": "explicit length; ID 0 is space, not terminator"},
        "storage": {"glyphs": len(chars), "glyph_rows_padded": glyph_depth, "glyph_bits": glyph_depth * 16, "text_bytes": len(text_ids), "text_bits": len(text_ids) * 8, "total_bits": glyph_depth * 16 + len(text_ids) * 8, "estimated_bram9k": font_blocks + text_blocks, "estimate_only": "Actual inference, utilization and timing require TD synthesis"},
        "captions": [{**c, "picture_index": i, "length": lengths[i], "width_px": lengths[i] * 16} for i, c in enumerate(captions)],
        "preview": {"band_y": [432, 479], "text_y": 448, "viewport_x": [16, 623], "blank_gap_px": 608, "gif_step_px": 16, "gif_duration_ms": 200, "note": "Offline layout reference; GIF sampling speed is not FPGA frame timing"},
        "preview_card": {"characters": 256, "extra_text_bits": 2048, "glyphs_shared": True,
                         "panel": [48,352,544,104], "text_rows_y": [364,388,412],
                         "thumbnail_size": [192,144], "note": "Offline illustration; board verification pending"},
        "backgrounds": [{"file": c["picture"], "sha256": sha256(args.background_dir / c["picture"])} for c in captions],
        "checks": {"unclipped_glyphs": True, "nonempty_nonspace": True, "no_duplicate_nonspace_glyphs": True, "rom_pixel_roundtrip": True, "text_roundtrip_and_padding": True},
        "files": {p.name: sha256(p) for p in sorted(out.iterdir()) if p.is_file() and p.name != "manifest.json"},
    }
    write_json(out / "manifest.json", manifest)
    print(json.dumps({"output": str(out), "glyphs": len(chars), "lengths": lengths, **manifest["storage"], "checks": manifest["checks"]}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
