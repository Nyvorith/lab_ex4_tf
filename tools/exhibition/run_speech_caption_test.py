from pathlib import Path
import csv
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='speech_caption_') as temporary:
    work = Path(temporary)
    lines = []
    for picture in range(4):
        text = (root / f'assets/exhibition/narration/AUDIO{picture+1}.txt').read_text(encoding='utf-8').strip()
        pcm = root / f'assets/exhibition/narration/tf_card/AUDIO{picture+1}.PCM'
        with (root / f'assets/exhibition/narration/timing/AUDIO{picture+1}.csv').open(encoding='utf-8') as handle:
            points = [(0, 0)] + [(int(row['sample_start']), max(0, min(int(row['character_start'])*16-288, len(text)*16-608))) for row in csv.DictReader(handle)]
        points.append((pcm.stat().st_size//2, points[-1][1]))
        probes = sorted(set(range(0, points[-1][0], 806)) | {max(0,t+d) for t,_ in points for d in (-1,0,1)})
        segment = 0
        for sample in probes:
            while segment < len(points)-2 and sample >= points[segment+1][0]:
                segment += 1
            start, first = points[segment]
            end, last = points[segment+1]
            expected = first + (last-first)*min(sample-start,end-start)//(end-start)
            lines.append(f'{picture} {sample} {expected} {len(text)}')
    oracle = work / 'oracle.txt'
    oracle.write_text('\n'.join(lines)+'\n')
    executable = work / 'speech.vvp'
    hdl = root / 'src/user_source/hdl_source/SD'
    subprocess.run(['D:/iverilog/bin/iverilog.exe', '-g2012', '-s', 'tb_speech_caption', '-o', str(executable),
                    str(root/'src/sim/tb_speech_caption.sv'), str(hdl/'narration_caption_timeline.v'),
                    str(hdl/'exhibit_caption_overlay.v'), str(hdl/'exhibit_caption_roms.v')], cwd=root, check=True)
    subprocess.run(['D:/iverilog/bin/vvp.exe', str(executable), '+oracle='+oracle.as_posix()], cwd=root, check=True)
