import os
import sys
import json
import subprocess

# 指定嵌入式 python 路径
python_exe = os.path.abspath(os.path.join(os.path.dirname(__file__), "python_embed", "python.exe"))
script_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "video_dedup.py"))

test_v1 = os.path.abspath(os.path.join(os.path.dirname(__file__), "test_1.mp4"))
test_v2 = os.path.abspath(os.path.join(os.path.dirname(__file__), "test_3.mp4"))

def run_cmd(args):
    print(f"\n执行命令: {' '.join(args)}")
    result = subprocess.run(args, capture_output=True, text=True, encoding='utf-8')
    if result.returncode != 0:
        print(f"错误 (退出码 {result.returncode}):")
        print(result.stderr)
        return None
    return result.stdout.strip()

def test_dedup():
    if not os.path.exists(python_exe):
        print(f"找不到 Python 解释器: {python_exe}")
        return

    if not os.path.exists(test_v1) or not os.path.exists(test_v2):
        print("错误: 请确保 test_1.mp4 和 test_3.mp4 存在于 py 目录下")
        print(f"路径1: {test_v1} (存在: {os.path.exists(test_v1)})")
        print(f"路径2: {test_v2} (存在: {os.path.exists(test_v2)})")
        return

    print("--- 步骤 1: 提取 test_1.mp4 哈希 ---")
    out1 = run_cmd([python_exe, script_path, "--action", "get_hash", "--file1", test_v1])
    if not out1: return
    h1_data = json.loads(out1)
    h1_list = h1_data.get("hashes", [])
    print(f"成功提取 {len(h1_list)} 个哈希点")

    print("\n--- 步骤 2: 提取 test_3.mp4 哈希 ---")
    out2 = run_cmd([python_exe, script_path, "--action", "get_hash", "--file1", test_v2])
    if not out2: return
    h2_data = json.loads(out2)
    h2_list = h2_data.get("hashes", [])
    print(f"成功提取 {len(h2_list)} 个哈希点")

    print("\n--- 步骤 3: 比较两个视频 ---")
    out3 = run_cmd([
        python_exe, script_path, 
        "--action", "compare", 
        "--hashes1", json.dumps(h1_list), 
        "--hashes2", json.dumps(h2_list)
    ])
    if out3:
        sim_data = json.loads(out3)
        print(f"\n结果: 相似度为 {sim_data.get('similarity', 0) * 100:.2f}%")

if __name__ == "__main__":
    test_dedup()
