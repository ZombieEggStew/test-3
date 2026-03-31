import cv2
import imagehash
from PIL import Image
import argparse
import json
import os
import sys
import subprocess
import numpy as np

def get_audio_hash(video_path):
    """
    通过 FFmpeg 提取音频采样并生成简单的音频哈希（指纹）。
    """
    if not os.path.exists(video_path):
        return None

    # 使用 ffmpeg 提取低采样率的音频 PCM 数据 (1000Hz, 单声道)
    # 这样可以快速获得音频的包络特征
    cmd = [
        'ffmpeg', '-i', video_path,
        '-vn', '-ac', '1', '-ar', '1000',
        '-f', 's16le', '-acodec', 'pcm_s16le',
        '-t', '60', # 只取前60秒避免大文件过慢
        '-'
    ]
    
    try:
        # 即使没有环境变量，也可以尝试根据 Godot 传入的路径寻找 ffmpeg，这里假设系统路径可用
        process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        out, _ = process.communicate()
        
        if len(out) < 100: # 音频太短或提取失败
            return None
            
        # 将字节转为 numpy 数组并计算特征
        audio_data = np.frombuffer(out, dtype=np.int16)
        
        # 简单的哈希：计算每秒音频的 RMS 能量作为特征序列
        chunk_size = 1000 # 对应 1 秒
        rms_values = []
        for i in range(0, len(audio_data), chunk_size):
            chunk = audio_data[i:i+chunk_size]
            if len(chunk) == 0: break
            rms = np.sqrt(np.mean(chunk.astype(np.float32)**2))
            rms_values.append(int(rms))
            
        return rms_values
    except Exception as e:
        return None

def compare_audio_hashes(h1, h2):
    """
    比较两个音频能量序列的相似度。
    """
    if not h1 or not h2: return 0.0
    
    # 对齐长度
    min_len = min(len(h1), len(h2))
    if min_len < 3: return 0.0
    
    v1 = np.array(h1[:min_len], dtype=np.float32)
    v2 = np.array(h2[:min_len], dtype=np.float32)
    
    # 归一化能量
    norm1 = np.linalg.norm(v1)
    norm2 = np.linalg.norm(v2)
    if norm1 == 0 or norm2 == 0: return 0.0
    
    v1 = v1 / norm1
    v2 = v2 / norm2
    
    # 计算余弦相似度
    similarity = np.dot(v1, v2)
    return float(similarity)

def get_video_hash(video_path, sample_rate=0.5, max_frames=20):
    """
    通过提取视频关键帧并生成感知哈希来获取视频的‘指纹’。
    sample_rate: 每秒提取多少帧。降低到 0.5 (每2秒一帧)
    max_frames: 最大采样帧数，降低到 20 帧足以识别视频
    """
    if not os.path.exists(video_path):
        return None

    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        return None

    fps = cap.get(cv2.CAP_PROP_FPS)
    if fps <= 0: fps = 24
    
    # 优化：使用 set(CAP_PROP_POS_FRAMES) 快速跳帧，而不是逐帧 read()
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    duration = total_frames / fps
    
    # 计算需要采样的帧索引
    num_samples = min(max_frames, int(duration * sample_rate))
    if num_samples < 3: num_samples = min(total_frames, 5) # 至少取样几帧
    
    indices = [int(i * (total_frames - 1) / (num_samples - 1)) for i in range(num_samples)]
    
    hashes = []
    for idx in indices:
        cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
        ret, frame = cap.read()
        if not ret:
            continue
        
        # 优化：在生成哈希前先缩小尺寸，大幅提升速度
        small_frame = cv2.resize(frame, (64, 64))
        cv2_im = cv2.cvtColor(small_frame, cv2.COLOR_BGR2RGB)
        pil_im = Image.fromarray(cv2_im)
        h = imagehash.phash(pil_im)
        hashes.append(str(h))

    cap.release()
    return hashes if hashes else None

def compare_hashes(hash_list1, hash_list2, threshold=10):
    """
    比较两组哈希值的相似度。
    threshold: 汉明距离阈值，越小越严格（0-64）。
    """
    if not hash_list1 or not hash_list2:
        return 0.0

    matches = 0
    # 简单的线性匹配增强版：检查 list1 中的帧是否在 list2 中有足够近的匹配
    # 实际应用中可以使用更复杂的序列匹配算法
    h2_objs = [imagehash.hex_to_hash(h) for h in hash_list2]
    
    for h1_str in hash_list1:
        h1 = imagehash.hex_to_hash(h1_str)
        for h2 in h2_objs:
            if h1 - h2 < threshold:
                matches += 1
                break
                
    similarity = matches / len(hash_list1)
    return similarity

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--action", choices=["get_hash", "compare", "get_audio_hash", "compare_audio"], required=True)
    parser.add_argument("--file1", type=str)
    parser.add_argument("--file2", type=str)
    parser.add_argument("--hashes1", type=str) # JSON string
    parser.add_argument("--hashes2", type=str) # JSON string
    
    args = parser.parse_args()

    if args.action == "get_hash":
        v_hash = get_video_hash(args.file1)
        print(json.dumps({"hashes": v_hash}))
    
    elif args.action == "get_audio_hash":
        a_hash = get_audio_hash(args.file1)
        print(json.dumps({"audio_hashes": a_hash}))
        
    elif args.action == "compare":
        h1 = json.loads(args.hashes1) if args.hashes1 else []
        h2 = json.loads(args.hashes2) if args.hashes2 else []
        sim = compare_hashes(h1, h2)
        print(json.dumps({"similarity": sim}))
        
    elif args.action == "compare_audio":
        h1 = json.loads(args.hashes1) if args.hashes1 else []
        h2 = json.loads(args.hashes2) if args.hashes2 else []
        sim = compare_audio_hashes(h1, h2)
        print(json.dumps({"similarity": sim}))
