import tkinter as tk
from tkinterdnd2 import DND_FILES, TkinterDnD
from tkinter import Listbox, Scrollbar
import converter
import my_file
from tkinter import ttk
import threading

# 创建支持拖放的窗口
root = TkinterDnD.Tk()
root.title('文件拖放界面')
root.geometry('300x600')  # 增加窗口高度以容纳列表框
file_objects = []
# 设置窗口始终在最上层
root.attributes('-topmost', True)


def validate_numeric_input(new_value):
    """仅允许输入数字，允许空字符串用于删除。"""
    return new_value.isdigit() or new_value == ""

def clear_list():
    file_objects.clear()
    file_listbox.delete(0, 'end')
    label.config(text="拖放文件到这里")
    status_label.config(text="准备开始...",fg='black')
    progress_bar['value'] = 0
    progress_label.config(text="0%")

def drop(event):
    # 获取拖放的文件路径
    files = root.tk.splitlist(event.data)
    for file in files:
        file_obj = my_file.my_file(file)
        file_objects.append(file_obj)
        file_listbox.insert('end',file_obj.get_name())
        label.config(text=f"已添加: {file_obj.get_name()}")
    return files

def start_conversion():
    """开始转换的线程函数"""
    def conversion_thread():
        try:
            maxrate_value = maxrate_var.get().strip() or "10"  # 默认值为10
            maxrate = f"{maxrate_value}M"
            for file in file_objects[:]:
            # 更新状态
                status_label.config(text="转换中...")
                
                # 执行转换
                success = converter.test2(
                    input_path=file.get_path(),
                    width=1920 if file_combo3.get() == '横屏' else 1080,
                    preset=file_combo1.get(),
                    cq=file_combo2.get(),
                    maxrate=maxrate,
                    callback=update_progress
                )
                
                if success:
                    status_label.config(text="转换完成!", fg="green")
                    del file_objects[0]
                    file_listbox.delete(0)

                else:
                    status_label.config(text="转换失败!", fg="red")

            clear_list()
                
        except Exception as e:
            status_label.config(text=f"错误: {str(e)}", fg="red")
    
    # 在单独线程中运行转换
    thread = threading.Thread(target=conversion_thread)
    thread.daemon = True
    thread.start()

def update_progress(progress):
    """更新进度条的回调函数"""
    if progress == -1:
        # 错误状态
        progress_bar['value'] = 0
        progress_label.config(text="转换出错!")
    else:
        progress_bar['value'] = progress
        progress_label.config(text=f"{progress:.1f}%")
    
    # 安全地更新UI（必须在主线程中）

# 创建标签用于显示提示
label = tk.Label(root, text="拖放文件到这里", 
                 bg='lightblue', relief='solid', 
                 width=50, height=10)
label.pack(padx=10, pady=10)

# 创建列表框用于显示已拖入的文件
frame = tk.Frame(root)
frame.pack(padx=10, pady=5, fill='both', expand=True)

scrollbar = Scrollbar(frame)
scrollbar.pack(side='right', fill='y')

file_listbox = Listbox(frame, yscrollcommand=scrollbar.set, height=3)
file_listbox.pack(side='left', fill='both', expand=True)

scrollbar.config(command=file_listbox.yview)

# 注册拖放事件
label.drop_target_register(DND_FILES)
label.dnd_bind('<<Drop>>', drop)

combo_frame = tk.Frame(root)
combo_frame.pack(pady=5,padx=5)

combo_label1 = tk.Label(combo_frame, text="质量:")
combo_label1.pack(side='left', padx=(0, 5))

# 创建下拉菜单选项
options1 = ["p1", "p5","7p"]

# 创建下拉菜单（Combobox）
file_combo1 = ttk.Combobox(combo_frame, values=options1, state="readonly", width=2)
file_combo1.pack(side='left', padx=(0, 10))
file_combo1.set("p7")  # 设置默认显示文本

combo_label2 = tk.Label(combo_frame, text="cq:")
combo_label2.pack(side='left', padx=(0, 5))

# 创建下拉菜单选项
options2 = ['18','21','24','28']

# 创建下拉菜单（Combobox）
file_combo2 = ttk.Combobox(combo_frame, values=options2, state="readonly", width=2)
file_combo2.pack(side='left')
file_combo2.set("21")  # 设置默认显示文本

# 创建下拉菜单选项
options3 = ['横屏','竖屏']

# 创建下拉菜单（Combobox）
file_combo3 = ttk.Combobox(combo_frame, values=options3, state="readonly", width=4)
file_combo3.pack(side='left',padx=(10,0))
file_combo3.set("横屏")  # 设置默认显示文本




progress_bar = ttk.Progressbar(
        root, 
        orient="horizontal", 
        length=350, 
        mode="determinate"
    )
progress_bar.pack(pady=5)

progress_label = tk.Label(root, text="0%")
progress_label.pack()
    
# 状态标签
status_label = tk.Label(root, text="准备开始...")
status_label.pack(pady=5)

button_frame = tk.Frame(root)
button_frame.pack(pady=5)

convert_files_button = tk.Button(button_frame, text="转换文件", command=start_conversion)
convert_files_button.pack(side='left', padx=5)

clear_button = tk.Button(button_frame, text="清空列表", command=clear_list)
clear_button.pack(side='left', padx=5)

maxrate_frame = tk.Frame(root)
maxrate_frame.pack(pady=(0, 10))

maxrate_label = tk.Label(maxrate_frame, text="maxrate:")
maxrate_label.pack(side='left', padx=(0, 5))

maxrate_var = tk.StringVar(value="10")
vcmd = (root.register(validate_numeric_input), '%P')
maxrate_entry = tk.Entry(maxrate_frame, textvariable=maxrate_var, width=6, validate='key', validatecommand=vcmd)
maxrate_entry.pack(side='left')

maxrate_unit_label = tk.Label(maxrate_frame, text="M")
maxrate_unit_label.pack(side='left', padx=(4, 0))

# 运行主循环
root.mainloop()