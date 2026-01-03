extends CanvasLayer

@onready var notepad_btn = $NotepadBtn
@onready var notepad_ui = $NotepadUI

func _ready():
	notepad_btn.pressed.connect(_on_notepad_btn_clicked)
	
	# 把自己加入 "UI" 组，方便鸭子气泡调用
	add_to_group("UI")

func _on_notepad_btn_clicked():
	open_notepad()

# 供外部调用的接口
func open_notepad():
	notepad_ui.open()