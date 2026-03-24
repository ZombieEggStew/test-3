import ffmpeg
import os
import subprocess
import argparse
import json
import shutil

# 自动将项目 bin 目录加入 PATH，以便 ffmpeg-python 能找到 ffmpeg.exe/ffprobe.exe
bin_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "bin"))
if os.path.exists(bin_dir):
    os.environ["PATH"] = bin_dir + os.pathsep + os.environ.get("PATH", "")


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
                # 删除指定的字段
                for field in ['contentrating', 'ratingsex', 'ratingviolenc']:
                    if field in project_data:
                        del project_data[field]
                
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

def get_video_stream(input_path):
    """获取视频流信息"""
    try: 
        probe = ffmpeg.probe(input_path)
        for stream in probe['streams']:
            if stream['codec_type'] == 'video':
                return stream
    except Exception as e:
        print(f"获取视频信息失败: {e}")
    return None

def test2(input_path, output_dir='', preset='p7', cq='21', maxrate='10M', vcodec='0', callback=None, progress_file=None):
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
    copy_project_and_preview_files(file_dir, target_dir, os.path.basename(output_file))

    # 获取视频信息并计算缩放
    stream = get_video_stream(input_path)
    vf_scale = "scale=1920:-2:flags=lanczos" # 默认值
    if stream:
        width = int(stream.get('width', 0))
        height = int(stream.get('height', 0))
        if width > 0 and height > 0:
            aspect_ratio = width / height
            target_ratio = 16.0 / 9.0
            if aspect_ratio >= target_ratio:
                vf_scale = "scale=1920:-2:flags=lanczos"
                print(f"检测到宽屏/标准比例 ({aspect_ratio:.2f} >= {target_ratio:.2f})，固定宽度 1920")
            else:
                vf_scale = "scale=-2:1080:flags=lanczos"
                print(f"检测到窄屏/竖屏比例 ({aspect_ratio:.2f} < {target_ratio:.2f})，固定高度 1080")

    print(f"质量:{preset}")

    print(f'CQ值:{cq}')
    print(f'maxrate:{maxrate}')

    maxrate_number = ''.join(ch for ch in str(maxrate) if ch.isdigit()) or '10'
    maxrate_value = f"{maxrate_number}M"
    bufsize_value = f"{int(maxrate_number) * 2}M"
    print(f"最大码率: {maxrate_value}")
    print(f"缓冲区: {bufsize_value}")
    # 构建 FFmpeg 命令参数列表
    cmd_0 = [
        'ffmpeg',
        '-i', input_path,           # 输入文件
        '-vf', vf_scale,  # 改进滤镜：使用 Lanczos 算法提升缩放画质
        '-vcodec', 'hevc_nvenc',    # 视频编码器：HEVC
        '-preset', preset,            # 预设：使用最高的 p7 预设（最慢，压缩率最高）
        '-rc:v', 'vbr',            # NVENC 码率控制模式
        '-cq:v', cq,               # 恒定质量：建议设置 24-28 以获得更小体积
        '-multipass', 'fullres',   # 启用全分辨率多路编码，大幅提升质量/压缩比
        '-rc-lookahead', '32',     # 启用码率控制展望 (0-32)，提升复杂场景画质
        '-spatial-aq', '1',        # 启用空间自适应量化
        '-aq-strength', '12',      # AQ 强度 (1-15)，增强平滑区域/边缘的细节保护
        '-temporal-aq', '1',       # 启用时间自适应量化
        '-bf', '3',                # 设置 B 帧数量，提升压缩率和画质
        '-pix_fmt', 'p010le',      # 像素格式：使用 10-bit 提升色深，减少断层
        '-acodec', 'copy',          # 音频流复制
        '-b:v', '0',                # 强制使用 CQ 模式控制码率
        '-maxrate', maxrate_value,  # 最大码率限制
        '-bufsize', bufsize_value,  # 缓冲区大小
        '-y',                       # 覆盖输出文件
        temp_file                   # 输出文件
    ]
    cmd_1 = [
        'ffmpeg',
        '-i', input_path,
        '-vf', vf_scale,  # 缩放到1080P
        '-c:v', 'h264_nvenc',  # H264硬件编码器
        '-preset', preset,    # 最慢预设，最高质量
        '-cq:v', cq,         # 恒定质量，低值=高画质
        '-multipass', 'fullres',  # 多路编码，提升质量
        '-spatial-aq', '1',   # 空间自适应量化
        '-temporal-aq', '1',  # 时间自适应量化
        '-rc-lookahead', '32', # 展望帧，提升复杂场景画质
        '-b:v', '0',          # 强制CQ模式
        '-maxrate', maxrate_value,    # 最大码率限制体积
        '-bufsize', bufsize_value,    # 缓冲区
        '-pix_fmt', 'yuv420p', # 像素格式
        '-c:a', 'copy',       # 复制音频
        '-y', temp_file
    ]
    cmd_2 = [
        'ffmpeg',
        '-i', input_path,
        '-vf', vf_scale,  # 缩放到1080P
        '-c:v', 'av1_nvenc',  # AV1硬件编码器
        '-preset', preset,    # 最慢预设，最高质量/压缩率
        '-cq:v', cq,        # 恒定质量，低值=高画质
        '-multipass', 'fullres',  # 多路编码，提升质量
        '-spatial-aq', '1',   # 空间自适应量化
        '-temporal-aq', '1',  # 时间自适应量化
        '-rc-lookahead', '32', # 展望帧，提升复杂场景画质
        '-b:v', '0',          # 强制CQ模式
        '-maxrate', maxrate_value,    # 最大码率限制体积
        '-bufsize', bufsize_value,    # 缓冲区
        '-pix_fmt', 'yuv420p10le',  # 10-bit像素格式，提升色深
        '-c:a', 'copy',       # 复制音频
        '-y', temp_file
    ]

    cmd_3 = [
        'ffmpeg',
        '-i', input_path,
        '-vf', vf_scale,  # 缩放到1080P
        '-c:v', 'h264_amf',  # H264硬件编码器
        '-usage', 'transcoding',  # 使用转码模式
        '-quality', 'quality',    # 最高质量
        '-crf', cq,         # 恒定质量，低值=高画质
        '-maxrate', maxrate_value,    # 最大码率限制体积
        '-bufsize', bufsize_value,    # 缓冲区
        '-pix_fmt', 'yuv420p', # 像素格式
        '-c:a', 'copy',       # 复制音频
        '-y', temp_file
    ]
    
    try:
        vcodec_int = int(vcodec)
        if vcodec_int == 0:
            cmd = cmd_0
        elif vcodec_int == 1:
            cmd = cmd_1
        elif vcodec_int == 2:
            cmd = cmd_2
        elif vcodec_int == 3:
            cmd = cmd_3
        else:
            cmd = cmd_0  # 默认

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
    parser.add_argument("--preset", default="p7", help="NVENC 预设")
    parser.add_argument("--cq", default="21", help="CQ 值")
    parser.add_argument("--maxrate", default="10M", help="最大码率")
    parser.add_argument("--progress-file", default="", help="进度输出文件路径")
    parser.add_argument("--vcodec", default="0", help="编码器索引: 0=hevc_nvenc, 1=h264_nvenc, 2=av1_nvenc")
    return parser.parse_args()


if __name__ == "__main__":
    args = _parse_args()

    if not os.path.exists(args.input):
        print(f"输入文件不存在: {args.input}")
        raise SystemExit(1)

    ok = test2(
        input_path=args.input,
        output_dir=args.output_dir,
        preset=args.preset,
        cq=args.cq,
        maxrate=args.maxrate,
        vcodec=args.vcodec,
        progress_file=args.progress_file,
    )
    raise SystemExit(0 if ok else 1)