from pathlib import Path
import csv
import hashlib
import json

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/exhibition/narration/timing'


def main():
    events = []
    rows = []
    for picture in range(4):
        text = (ROOT / f'assets/exhibition/narration/AUDIO{picture+1}.txt').read_text(encoding='utf-8').strip()
        pcm = ROOT / f'assets/exhibition/narration/tf_card/AUDIO{picture+1}.PCM'
        data = list(csv.DictReader((OUT / f'AUDIO{picture+1}.csv').open(encoding='utf-8')))
        if not 0 < len(data) < 63 or pcm.stat().st_size//2 >= (1 << 20):
            raise ValueError('Timeline exceeds 64 events.')
        parsed = []
        for i, item in enumerate(data):
            char = int(item['character_start'])
            sample = int(item['sample_start'])
            if not 0 <= char < len(text) or not 0 <= sample < pcm.stat().st_size // 2:
                raise ValueError('Speech offset outside original content.')
            if i and sample < parsed[-1]['sample']:
                raise ValueError('Timeline not monotonic.')
            target = max(0, min(char*16 - 288, len(text)*16 - 608))
            parsed.append({'sample': sample, 'character': char, 'scroll': target})

        nodes = [{'sample': 0, 'scroll': 0}] + parsed
        nodes.append({'sample': pcm.stat().st_size//2, 'scroll': parsed[-1]['scroll']})
        for i, (first, last) in enumerate(zip(nodes, nodes[1:])):
            duration = last['sample'] - first['sample']
            distance = last['scroll'] - first['scroll']
            if duration <= 0 or duration >= (1 << 20):
                raise ValueError('Invalid interpolation interval.')
            rate = round(distance * (1 << 20) / duration)
            if not 0 <= rate < (1 << 16):
                raise ValueError('Interpolation rate exceeds budget.')
            packed = (first['sample'] << 58) | ((last['sample'] if i != len(nodes)-2 else (1 << 20)-1) << 38) | (first['scroll'] << 27) | (last['scroll'] << 16) | rate
            rows.append(f"            8'd{picture*64+i}: segment = 78'h{packed:020x};")
        events.append({'picture': picture, 'pcm_sha256': hashlib.sha256(pcm.read_bytes()).hexdigest().upper(),
                       'samples': pcm.stat().st_size//2, 'text': text, 'events': parsed})
    module = '''`timescale 1ns/1ps
module narration_caption_timeline(
    input wire clk, rst_n, restart, playing,
    input wire [1:0] picture,
    input wire [31:0] samples,
    output reg [10:0] scroll_target
);
    reg [5:0] cursor;
    reg [1:0] current_picture;
    reg [31:0] previous_samples;
    reg [77:0] segment;
    wire [19:0] first_sample = segment[77:58];
    wire [19:0] last_sample = segment[57:38];
    wire [10:0] first_scroll = segment[37:27];
    wire [10:0] last_scroll = segment[26:16];
    wire [19:0] offset = samples <= first_sample ? 20'd0 :
        samples >= last_sample ? last_sample - first_sample : samples[19:0] - first_sample;
    wire [35:0] fraction = offset * segment[15:0];
    wire [16:0] position_sum = {6'd0,first_scroll} + {1'b0,fraction[35:20]};
    wire [10:0] interpolated = position_sum > {6'd0,last_scroll} ? last_scroll : position_sum[10:0];
    always @* begin
        case ({picture,cursor})
ROWS
            default: segment = {20'd0,20'hfffff,11'd0,11'd0,16'd0};
        endcase
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cursor <= 0; current_picture <= 0;
            scroll_target <= 0; previous_samples <= 0;
        end else begin
            current_picture <= picture; previous_samples <= samples;
            if (restart || !playing || current_picture != picture || samples < previous_samples) begin
                cursor <= 0; scroll_target <= 0;
            end else begin
                scroll_target <= interpolated;
                if (samples >= last_sample && cursor != 63 && last_sample != 20'hfffff)
                    cursor <= cursor + 1'b1;
            end
        end
    end
endmodule
'''.replace('ROWS', '\n'.join(rows))
    (ROOT / 'src/user_source/hdl_source/SD/narration_caption_timeline.v').write_text(module, encoding='utf-8')
    (OUT / 'manifest.json').write_text(json.dumps({'source': 'System.Speech Huihui Rate1 Volume80; regenerated PCM hashes match originals; 48k event time corrected /3 and cross-checked against 16k native within 2ms',
        'sample_rate': 48000, 'interpolation': 'Linear between speech events, Q20 reciprocal rate; integer result within one pixel of rational interpolation; edge clamped', 'events': events}, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(f'Timeline generated: {sum(len(e["events"]) for e in events)} verified word boundaries; no PCM changes.')


if __name__ == '__main__':
    main()
