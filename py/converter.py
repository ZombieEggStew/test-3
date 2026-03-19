import ffmpeg
import os
import tempfile
import subprocess
import argparse
import json
import shutil


def write_progress(progress_file, value):
    if not progress_file:
        return
    try:
        with open(progress_file, 'w', encoding='utf-8') as f:
            f.write(str(value))
    except Exception as e:
        print(f"写入进度失败: {e}")


def copy_project_and_preview_files(source_dir, target_dir, new_video_name):
    source_dir_abs = os.path.abspath(source_dir)
    target_dir_abs = os.path.abspath(target_dir)

    if source_dir_abs == target_dir_abs:
        return

    os.makedirs(target_dir_abs, exist_ok=True)

    project_src = os.path.join(source_dir_abs, 'project.json')
    project_dst = os.path.join(target_dir_abs, 'project.json')
    if os.path.exists(project_src):
        try:
            with open(project_src, 'r', encoding='utf-8') as f:
                project_data = json.load(f)

            if isinstance(project_data, dict):
                project_data['file'] = new_video_name
                old_title = str(project_data.get('title', '')).strip()
                if old_title:
                    project_data['title'] = f"{old_title}_my_convert"
                else:
                    project_data['title'] = os.path.splitext(new_video_name)[0]

            with open(project_dst, 'w', encoding='utf-8') as f:
                json.dump(project_data, f, ensure_ascii=False, indent=2)
        except Exception as e:
            print(f"更新 project.json 失败，改为原样复制: {e}")
            shutil.copy2(project_src, project_dst)

    for name in os.listdir(source_dir_abs):
        if name.lower().startswith('preview.'):
            src_path = os.path.join(source_dir_abs, name)
            if os.path.isfile(src_path):
                shutil.copy2(src_path, os.path.join(target_dir_abs, name))

def get_bitrate(input_path):
    """获取原视频比特率（返回如 '4000k'）"""
    try:
        probe = ffmpeg.probe(input_path)
        for stream in probe['streams']:
            if stream['codec_type'] == 'video':
                # bit_rate 可能为 None
                bit_rate = stream.get('bit_rate')
                if bit_rate:
                    # 转为 k 单位
                    kbit = int(bit_rate) // 1000
                    return f"{kbit}k"
    except Exception as e:
        print(f"获取比特率失败: {e}")
    return None

def test2(input_path, output_dir='', width=1920, preset='p7', cq='21', maxrate='10M', callback=None, progress_file=None):
    file_dir = os.path.dirname(os.path.abspath(input_path))
    print(f"文件目录: {file_dir}")
    file_name = os.path.basename(input_path)
    print(f"文件名: {file_name}")
    file_stem, file_ext = os.path.splitext(file_name)
    target_dir = output_dir.strip() if output_dir else file_dir
    os.makedirs(target_dir, exist_ok=True)
    output_file = os.path.join(target_dir, f"{file_stem}_my_convert{file_ext}")
    print(f"输出文件路径: {output_file}")
    temp_file = os.path.join(target_dir, f"temp_convert2_{file_name}")
    print(f"临时文件路径: {temp_file}")
    backup_path = os.path.join(file_dir, f"{file_name}.bak")
    print(f"备份文件路径: {backup_path}")

    print(f"质量:{preset}")

    print(f'CQ值:{cq}')
    print(f'maxrate:{maxrate}')

    maxrate_number = ''.join(ch for ch in str(maxrate) if ch.isdigit()) or '10'
    maxrate_value = f"{maxrate_number}M"
    bufsize_value = f"{int(maxrate_number) * 2}M"
    print(f"最大码率: {maxrate_value}")
    print(f"缓冲区: {bufsize_value}")
    # 构建 FFmpeg 命令参数列表
    cmd = [
        'ffmpeg',
        '-i', input_path,           # 输入文件
        '-vf', f'scale={width}:-2:flags=spline',  # 视频滤镜：缩放
        '-vcodec', 'h264_nvenc',    # 视频编码器
        '-preset', preset,              # 编码预设
        '-rc:v', 'vbr',            # NVENC 码率控制模式
        '-cq:v', cq,               # NVENC 恒定质量
        '-profile', 'high',         # 编码档次
        '-tune', 'hq',              # 调优设置
        '-movflags', '+faststart',  # MP4优化
        '-pix_fmt', 'yuv420p',      # 像素格式
        '-acodec', 'copy',          # 音频流复制
        '-b:v', '0',                # 视频码率（CRF模式）
        # '-b:v', bitrate if bitrate else '0',
        '-maxrate', maxrate_value,  # 最大码率
        '-bufsize', bufsize_value,  # 缓冲区大小
        '-y',                       # 覆盖输出文件（相当于overwrite_output）
        temp_file                   # 输出文件
    ]
    
    try:
        total_seconds = 0.0
        write_progress(progress_file, 0)

        # 执行 FFmpeg 命令
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            universal_newlines=True,   # 以文本模式处理输出
            bufsize=1,                 # 行缓冲
            encoding='utf-8'           # 指定编码
        )

        while True:
            output = process.stdout.readline()
            if output == '' and process.poll() is not None:
                if callback:
                    callback(100)
                write_progress(progress_file, 100)
                break
            if output:
                output = output.strip()
                if(output.startswith('Duration')):
                    duration = output.split('Duration:')[1].split(',')[0].strip()
                    print(f"总时长: {duration}")
                    h,m,s = duration.split(':')
                    total_seconds = int(h) * 3600 + int(m) * 60 + float(s)
                if(output.startswith("frame")):
                    t = output.split("time=")[-1].split(" ")[0].strip()
                    print(t)
                    if t != 'N/A' and total_seconds > 0:
                        h,m,s = t.split(':')
                        current_seconds = int(h) * 3600 + int(m) * 60 + float(s)
                        progress = (current_seconds / total_seconds) * 100

                        if callback:
                            callback(progress)
                        write_progress(progress_file, round(progress, 2))
                        # print(f"转换进度: {progress:.2f}%")


            # 检查临时文件是否创建成功

        if not os.path.exists(temp_file):
            print("错误: 临时文件创建失败")
            write_progress(progress_file, -1)
            return False

        os.replace(temp_file, output_file)
        copy_project_and_preview_files(file_dir, target_dir, os.path.basename(output_file))
        print(f"✓ 转换完成: {output_file}")
        write_progress(progress_file, 100)
        return True
        
    except ffmpeg.Error as e:
        print(f"转换失败: {e.stderr.decode()}")
        write_progress(progress_file, -1)
        # 清理临时文件
        if os.path.exists(temp_file):
            os.remove(temp_file)
        return False
    except Exception as e:
        print(f"文件操作错误: {e}")
        write_progress(progress_file, -1)
        # 恢复备份文件（如果存在）
        if os.path.exists(backup_path) and not os.path.exists(input_path):
            os.rename(backup_path, input_path)
        return False

def _parse_args():
    parser = argparse.ArgumentParser(description="视频转换入口")
    parser.add_argument("--input", required=True, help="输入文件路径")
    parser.add_argument("--output-dir", default="", help="输出目录路径")
    parser.add_argument("--width", type=int, default=1920, help="缩放目标宽度")
    parser.add_argument("--preset", default="p7", help="NVENC 预设")
    parser.add_argument("--cq", default="21", help="CQ 值")
    parser.add_argument("--maxrate", default="10M", help="最大码率")
    parser.add_argument("--progress-file", default="", help="进度输出文件路径")
    return parser.parse_args()


if __name__ == "__main__":
    args = _parse_args()

    if not os.path.exists(args.input):
        print(f"输入文件不存在: {args.input}")
        raise SystemExit(1)

    ok = test2(
        input_path=args.input,
        output_dir=args.output_dir,
        width=args.width,
        preset=args.preset,
        cq=args.cq,
        maxrate=args.maxrate,
        progress_file=args.progress_file,
    )
    raise SystemExit(0 if ok else 1)