from PIL import Image, ImageSequence
import os
import sys
import json

def split_gif(gif_path, output_dir):
    """
    将 GIF 拆分为帧序列并保存在 output_dir 中
    """
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    try:
        with Image.open(gif_path) as im:
            frames_info = []
            for i, frame in enumerate(ImageSequence.Iterator(im)):
                # 获取每一帧的持续时间 (ms)
                duration = frame.info.get('duration', 100) / 1000.0 # 转为秒
                frame_filename = f"frame_{i:03d}.png"
                frame_path = os.path.join(output_dir, frame_filename)
                
                # 保存为 RGBA 格式以保留透明度
                frame.convert("RGBA").save(frame_path)
                
                frames_info.append({
                    "file": frame_filename,
                    "duration": duration
                })
            
            # 保存元数据以便 Godot 读取
            with open(os.path.join(output_dir, "metadata.json"), "w") as f:
                json.dump(frames_info, f)
            
            print(f"SUCCESS: {len(frames_info)} frames extracted to {output_dir}")
    except Exception as e:
        print(f"ERROR: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python split_gif.py <gif_path> <output_dir>")
        sys.exit(1)
    
    split_gif(sys.argv[1], sys.argv[2])
