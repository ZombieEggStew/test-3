import os
import win32com.client

COMMON_KEYWORDS = [
    "帧宽度", "帧高度","数据速率", "总比特率","时长", 
]

def dump_all_columns(folder, item, max_index=300, show_empty=False):
    """
    列出 0..max_index-1 的列索引、列名与当前文件对应值（可见与空值）
    """
    rows = []
    for i in range(max_index):
        col_name = folder.GetDetailsOf(None, i)
        if not col_name and not show_empty:
            # 如果列名为空并且不显示空列，继续
            continue
        val = folder.GetDetailsOf(item, i)
        rows.append((i, col_name, val))
    return rows

def find_by_keywords(props_rows, keywords):
    """
    在列名中查找包含任一关键词的列，返回匹配的 (index, name, value) 列表
    """
    res = []
    low_keywords = [k.lower() for k in keywords]
    for idx, name, val in props_rows:
        if not name:
            continue
        lname = name.lower()
        if any(kw in lname for kw in low_keywords):
            res.append((idx, name, val))
    return res

def inspect_file(path, max_index=500, show_empty=False):
    path = os.path.abspath(path)
    folder_path, file_name = os.path.split(path)
    shell = win32com.client.Dispatch("Shell.Application")
    folder = shell.NameSpace(folder_path)
    if folder is None:
        raise FileNotFoundError(f"无法访问目录: {folder_path}")
    item = folder.ParseName(file_name)
    if item is None:
        raise FileNotFoundError(f"无法找到文件: {file_name} 在 {folder_path}")

    rows = dump_all_columns(folder, item, max_index=max_index, show_empty=show_empty)
    matches = find_by_keywords(rows, COMMON_KEYWORDS)
    return rows, matches

if __name__ == "__main__":
    video_path = r"D:\Steam\steamapps\common\wallpaper_engine\projects\myprojects\relozer202402 01-10_my_convert\relozer202402 01-10_my_convert.mp4"
    rows, matches = inspect_file(video_path, max_index=600, show_empty=False)

    print("==== 匹配到包含常见关键词的列（index, 列名, 值） ====")
    if matches:
        for idx, name, val in matches:
            print(f"{idx}: {name} -> {val}")
    else:
        print("未在列名中匹配到常见关键词（宽度/高度/比特率等）。")

    # print("\n==== 列表所有非空列（index, 列名, 值） ====")
    # for idx, name, val in rows:
    #     if val:  # 仅打印有值的列，若要查看空列请将此判断去掉或运行 show_empty=True
    #         print(f"{idx}: {name} -> {val}")