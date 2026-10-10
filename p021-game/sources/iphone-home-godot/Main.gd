extends Control
# GAME-G016 / iPhone-inspired home screen built entirely in Godot CanvasItem.
# All app icons are non-functional mock-ups. No biometric or device APIs.
const W := 390.0
const H := 844.0
const SITE_URL := "https://kobitworks.github.io/autoai_poc/p021-game/games/iphone-home/"
const APPS := {
 "photos":["写真","#FFFFFF"],"camera":["カメラ","#EFF0F4"],"mail":["メール","#178AF5"],"clock":["時計","#F9FAFC"],
 "maps":["マップ","#FFFFFF"],"weather":["天気","#38A9FB"],"reminders":["リマインダー","#FFFFFF"],"notes":["メモ","#FFFFFF"],
 "stocks":["株価","#171A22"],"books":["ブック","#FF9E13"],"appstore":["App Store","#198DF8"],"podcasts":["ポッドキャスト","#9B59CF"],
 "tv":["TV","#19191E"],"health":["ヘルスケア","#FFFFFF"],"home":["ホーム","#FEA42B"],"wallet":["ウォレット","#171B29"],
 "facetime":["FaceTime","#37CD66"],"calendar":["カレンダー","#FFFFFF"],"files":["ファイル","#FFFFFF"],"contacts":["連絡先","#E6E7EC"],
 "shortcuts":["ショートカット","#3B59D9"],"find":["探す","#FFFFFF"],"calculator":["計算機","#1C1C20"],"translate":["翻訳","#FFFFFF"],
 "voice":["ボイスメモ","#FFFFFF"],"tips":["ヒント","#F9C53E"],"news":["ニュース","#FFFFFF"],"settings":["設定","#BBC0C9"],"qr":["サイトQR","#FFFFFF"],
 "phone":["電話","#39CE67"],"safari":["Safari","#FFFFFF"],"messages":["メッセージ","#38CE62"],"music":["ミュージック","#FF5269"],
 "freeform":["フリーボード","#FFFFFF"],"fitness":["フィットネス","#101116"],"measure":["計測","#171717"],"magnifier":["拡大鏡","#16191F"]
}
const PAGE_ONE := ["photos","camera","mail","clock","maps","weather","reminders","notes","stocks","books","appstore","podcasts","tv","health","home","wallet"]
const PAGE_TWO := ["facetime","calendar","files","contacts","shortcuts","find","calculator","translate","voice","tips","news","settings","qr","freeform","fitness","measure","magnifier","photos","clock","weather"]
const DOCK := ["phone","safari","messages","music"]

var app_textures: Dictionary = {}
var ui_font: Font
var wall: Texture2D
var qr_texture: Texture2D
var page: int = 0
var visual_page: float = 0.0
var selected: String = ""
var touching: bool = false
var pointer_start: Vector2 = Vector2.ZERO
var pointer_current: Vector2 = Vector2.ZERO
var press_seconds: float = 0.0
var editing: bool = false
var last_second: int = -1
var current_time: String = "9:41"

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_STOP
 # Clip outgoing home pages to the virtual phone canvas (iPad/Desktop letterboxing).
 clip_contents = true
 if ResourceLoader.exists("res://fonts/NotoSansJP.ttf"):
  ui_font = load("res://fonts/NotoSansJP.ttf")
 else:
  ui_font = ThemeDB.fallback_font
 if ResourceLoader.exists("res://assets/wallpaper.png"):
  wall = load("res://assets/wallpaper.png")
 if ResourceLoader.exists("res://assets/site-qr.png"):
  qr_texture = load("res://assets/site-qr.png")
 for key in APPS.keys():
  var p: String = "res://assets/icons/%s.png" % str(key)
  if ResourceLoader.exists(p):
   app_textures[key] = load(p)
 set_process(true)
 set_process_input(true)
 queue_redraw()

func _process(delta: float) -> void:
 visual_page = lerpf(visual_page, float(page), minf(1.0, delta * 11.0))
 if absf(visual_page - float(page)) < 0.003:
  visual_page = float(page)
 if touching:
  press_seconds += delta
  if press_seconds > 0.62 and pointer_start.distance_to(pointer_current) < 16.0 and selected == "":
   editing = true
   touching = false
 var t: Dictionary = Time.get_datetime_dict_from_system()
 var s: int = int(t.get("second", 0))
 if s != last_second:
  last_second = s
  current_time = "%02d:%02d" % [int(t.get("hour", 9)), int(t.get("minute", 41))]
 queue_redraw()

func _canvas_area() -> Dictionary:
 var real_size := size
 var landscape := real_size.x > real_size.y * 1.42 and real_size.y < 620.0
 var virtual := Vector2(844.0, 390.0) if landscape else Vector2(W, H)
 var area := Rect2(Vector2.ZERO, real_size)
 if not landscape and real_size.x >= 640.0 and real_size.y >= 690.0:
  var ph := minf(860.0, real_size.y - 36.0)
  var pw := ph * W / H
  area = Rect2((real_size - Vector2(pw, ph)) * 0.5, Vector2(pw, ph))
 var zoom := minf(area.size.x / virtual.x, area.size.y / virtual.y)
 var origin := area.position + (area.size - virtual * zoom) * 0.5
 return {"landscape":landscape,"virtual":virtual,"zoom":zoom,"origin":origin,"rect":Rect2(origin,virtual * zoom)}

func _draw() -> void:
 var d := _canvas_area()
 var landscape: bool = d["landscape"]
 var virtual: Vector2 = d["virtual"]
 var zoom: float = d["zoom"]
 var origin: Vector2 = d["origin"]
 draw_rect(Rect2(Vector2.ZERO,size), Color("#111428"))
 if not landscape and size.x >= 640.0:
  _rounded(Rect2(d["rect"].position - Vector2(7.0, 7.0),d["rect"].size + Vector2(14.0,14.0)), 42.0, Color(0.03,0.04,0.08,1.0))
 draw_set_transform(origin, 0.0, Vector2(zoom, zoom))
 if wall:
  draw_texture_rect(wall, Rect2(Vector2.ZERO,virtual), false)
 else:
  draw_rect(Rect2(Vector2.ZERO,virtual), Color("#6477B4"))
 if landscape:
  _draw_landscape()
 else:
  _draw_portrait()
 if selected == "qr":
  _draw_qr_dialog(landscape)
 elif selected != "":
  _draw_sheet(landscape)
 draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _rounded(r: Rect2, radius: float, color: Color) -> void:
 var rad := minf(radius, minf(r.size.x, r.size.y) * 0.5)
 var centers := [
  Vector2(r.end.x-rad,r.position.y+rad),
  Vector2(r.end.x-rad,r.end.y-rad),
  Vector2(r.position.x+rad,r.end.y-rad),
  Vector2(r.position.x+rad,r.position.y+rad)
 ]
 var starts := [-PI*0.5, 0.0, PI*0.5, PI]
 var poly := PackedVector2Array()
 for n in range(4):
  for j in range(9):
   var ang: float = starts[n] + float(j) * PI / 16.0
   poly.append(centers[n] + Vector2(cos(ang), sin(ang)) * rad)
 draw_colored_polygon(poly,color)

func _label(text: String, x: float, baseline: float, width: float, px: int, color: Color, centered: bool = true, outline: bool = false) -> void:
 if ui_font == null:
  return
 var align := HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
 var p := Vector2(x,baseline)
 if outline:
  draw_string_outline(ui_font,p,text,align,width,px,3,Color(0.13,0.18,0.35,0.45))
 draw_string(ui_font,p,text,align,width,px,color)

func _draw_status(landscape: bool) -> void:
 var wd := 844.0 if landscape else W
 _label(current_time, 28.0, 39.0, 82.0, 16, Color.WHITE, false, true)
 _rounded(Rect2(wd*0.5-51.0,12.0,102.0,31.0),16.0,Color("#101116"))
 draw_circle(Vector2(wd*0.5+27.0,27.0),4.8,Color("#151F35"))
 for i in range(4):
  var x: float = wd-83.0+float(i)*5.0
  draw_line(Vector2(x,38.0),Vector2(x,38.0-(5.0+float(i)*2.7)),Color.WHITE,2.8,true)
 draw_arc(Vector2(wd-49.0,26.0),9.0,PI*1.17,PI*1.83,15,Color.WHITE,2.5,true)
 draw_circle(Vector2(wd-49.0,34.0),1.8,Color.WHITE)
 _rounded(Rect2(wd-33.0,20.0,24.0,13.0),4.0,Color(1,1,1,0.95))
 _rounded(Rect2(wd-31.0,22.0,19.0,9.0),2.5,Color("#6F8BAD"))
 draw_rect(Rect2(wd-8.5,24.0,2.0,5.0),Color.WHITE)

func _draw_widget(shift: float) -> void:
 _rounded(Rect2(18.0+shift,96.0,171.0,163.0),24.0,Color(0.09,0.40,0.84,0.72))
 _rounded(Rect2(201.0+shift,96.0,171.0,163.0),24.0,Color(1,1,1,0.79))
 _label("東京",33.0+shift,123.0,120.0,14,Color.WHITE,false)
 _label("23°",31.0+shift,181.0,130.0,58,Color.WHITE,false)
 _label("晴れ",33.0+shift,211.0,100.0,14,Color.WHITE,false)
 _label("最高 25°  最低 17°",33.0+shift,240.0,147.0,10,Color.WHITE,false)
 draw_circle(Vector2(159.0+shift,128.0),12.0,Color("#FFD06B"))
 _label("土曜日",218.0+shift,126.0,130.0,13,Color("#E34A51"),false)
 _label("10",213.0+shift,199.0,135.0,66,Color("#2C3452"),false)
 _label("予定はありません",217.0+shift,238.0,147.0,11,Color("#858B9B"),false)

func _draw_icon(key: String, x: float, y: float, s: float, label: bool = true, landscape: bool = false) -> void:
 var spec: Array = APPS.get(key, ["アプリ","#FFFFFF"])
 var bg := Color(str(spec[1]))
 var r := Rect2(x,y,s,s)
 _rounded(Rect2(x+1.5,y+3.5,s,s), s*0.235, Color(0.08,0.08,0.24,0.14))
 _rounded(r,s*0.235,bg)
 if app_textures.has(key):
  var gap := s*0.12
  draw_texture_rect(app_textures[key],Rect2(x+gap,y+gap,s-gap*2.0,s-gap*2.0),false)
 if editing:
  draw_circle(Vector2(x+3.0,y+4.0),10.0,Color("#EA4D51"))
  _label("−",x-7.0,y+9.0,20.0,15,Color.WHITE)
 if label:
  _label(str(spec[0]),x-16.0,y+s+18.0,s+32.0,11 if landscape else 12,Color.WHITE,true,true)

func _draw_portrait() -> void:
 _draw_status(false)
 _draw_widget(-visual_page * W)
 for idx in range(PAGE_ONE.size()):
  var x: float = 22.0 + float(idx % 4) * 93.0 - visual_page * W
  var y: float = 284.0 + float(idx / 4) * 95.5
  _draw_icon(PAGE_ONE[idx],x,y,63.0)
 for idx in range(PAGE_TWO.size()):
  var x: float = 22.0 + float(idx % 4) * 93.0 + (1.0-visual_page)*W
  var y: float = 106.0 + float(idx / 4) * 109.0
  _draw_icon(PAGE_TWO[idx],x,y,63.0)
 _draw_pages(690.0, 704.0)
 _rounded(Rect2(13.0,730.0,364.0,96.0),32.0,Color(0.93,0.94,1.0,0.35))
 for idx in range(4):
  _draw_icon(DOCK[idx],35.0+float(idx)*89.0,745.0,64.0,false)
 _rounded(Rect2(132.0,833.0,126.0,4.5),2.3,Color(0.05,0.09,0.23,0.74))
 if editing:
  _rounded(Rect2(313.0,48.0,63.0,31.0),15.0,Color(1,1,1,0.8))
  _label("完了",315.0,68.0,59.0,12,Color("#2B3F5D"))

func _draw_landscape() -> void:
 _draw_status(true)
 var all_apps: Array = PAGE_ONE if page == 0 else PAGE_TWO
 for idx in range(mini(16,all_apps.size())):
  var x: float = 29.0 + float(idx % 8)*102.0
  var y: float = 67.0 + float(idx / 8)*100.0
  _draw_icon(str(all_apps[idx]),x,y,59.0,true,true)
 _draw_pages(398.0,266.0)
 _rounded(Rect2(220.0,280.0,404.0,84.0),28.0,Color(0.94,0.95,1.0,0.35))
 for idx in range(4):
  _draw_icon(DOCK[idx],246.0+float(idx)*91.0,294.0,55.0,false,true)
 _rounded(Rect2(365.0,380.0,114.0,4.0),2.0,Color(0.04,0.05,0.20,0.7))
 if editing:
  _rounded(Rect2(755.0,38.0,65.0,28.0),14.0,Color(1,1,1,0.8))
  _label("完了",759.0,57.0,57.0,12,Color("#2B3F5D"))

func _draw_pages(cx: float, y: float) -> void:
 for i in range(2):
  var a := 0.95 if i == page else 0.34
  draw_circle(Vector2(cx-9.0+float(i)*17.0,y),3.7 if i == page else 3.2,Color(1,1,1,a))


func _qr_dialog_rect(landscape: bool) -> Rect2:
 return Rect2(160.0,24.0,524.0,338.0) if landscape else Rect2(24.0,162.0,342.0,512.0)

func _qr_close_rect(landscape: bool) -> Rect2:
 return Rect2(445.0,270.0,206.0,52.0) if landscape else Rect2(54.0,607.0,282.0,52.0)

func _draw_qr_dialog(landscape: bool) -> void:
 # A real, locally bundled QR PNG. The QR payload points to the public Godot PWA.
 var v := Vector2(844.0,390.0) if landscape else Vector2(W,H)
 draw_rect(Rect2(Vector2.ZERO,v),Color(0.02,0.04,0.11,0.72))
 var panel := _qr_dialog_rect(landscape)
 _rounded(Rect2(panel.position+Vector2(0.0,7.0),panel.size),32.0,Color(0,0,0,0.16))
 _rounded(panel,32.0,Color("#F9FAFC"))
 if landscape:
  _rounded(Rect2(179.0,54.0,266.0,266.0),19.0,Color.WHITE)
  if qr_texture != null:
   draw_texture_rect(qr_texture,Rect2(191.0,66.0,242.0,242.0),false)
  _label("このサイトのQRコード",452.0,92.0,210.0,17,Color("#212633"))
  _label("スマートフォンで読み取ると",452.0,131.0,206.0,12,Color("#5B6474"))
  _label("ゲームを直接開けます",452.0,152.0,206.0,12,Color("#5B6474"))
  _label("kobitworks.github.io",452.0,193.0,206.0,13,Color("#2778CD"))
  _label("/autoai_poc/p021-game/",452.0,215.0,206.0,10,Color("#657081"))
  _label("games/iphone-home/",452.0,233.0,206.0,10,Color("#657081"))
 else:
  _label("このサイトのQRコード",46.0,213.0,298.0,20,Color("#212633"))
  _label("スマートフォンで読み取って開く",46.0,238.0,298.0,12,Color("#687181"))
  _rounded(Rect2(54.0,255.0,282.0,282.0),21.0,Color.WHITE)
  if qr_texture != null:
   draw_texture_rect(qr_texture,Rect2(67.0,268.0,256.0,256.0),false)
  _label("kobitworks.github.io",46.0,566.0,298.0,15,Color("#247ACF"))
  _label("/autoai_poc/p021-game/games/iphone-home/",36.0,586.0,318.0,10,Color("#657081"))
 var close_rect := _qr_close_rect(landscape)
 _rounded(close_rect,16.0,Color("#147AFF"))
 _label("閉じる",close_rect.position.x,close_rect.position.y+33.0,close_rect.size.x,16,Color.WHITE)
 if not landscape:
  _rounded(Rect2(132.0,833.0,126.0,4.5),2.3,Color.WHITE)

func _draw_sheet(landscape: bool) -> void:
 var v := Vector2(844.0,390.0) if landscape else Vector2(W,H)
 draw_rect(Rect2(Vector2.ZERO,v),Color(0.08,0.12,0.27,0.68))
 var rect := Rect2(250.0,38.0,344.0,314.0) if landscape else Rect2(26.0,263.0,338.0,298.0)
 _rounded(rect,32.0,Color("#F7F8FC"))
 var spec: Array = APPS.get(selected,["アプリ","#FFFFFF"])
 var icon_x: float = rect.position.x+(rect.size.x-75.0)*0.5
 var icon_y: float = rect.position.y+34.0
 _draw_icon(selected,icon_x,icon_y,75.0,false)
 _label(str(spec[0]),rect.position.x+22.0,icon_y+115.0,rect.size.x-44.0,21,Color("#202536"))
 if selected == "settings":
  _label("画面再現PoC / 非公式デモ",rect.position.x+20.0,icon_y+144.0,rect.size.x-40.0,12,Color("#566174"))
  _label("Icons by Icons8  ↗",rect.position.x+20.0,icon_y+179.0,rect.size.x-40.0,16,Color("#1175CE"))
 else:
  _label("このアイコンはデモ表示です",rect.position.x+20.0,icon_y+157.0,rect.size.x-40.0,13,Color("#657080"))
 _rounded(Rect2(rect.position.x+26.0,rect.end.y-68.0,rect.size.x-52.0,44.0),15.0,Color("#187AFF"))
 _label("ホーム画面に戻る",rect.position.x+26.0,rect.end.y-40.0,rect.size.x-52.0,13,Color.WHITE)
 if not landscape:
  _rounded(Rect2(132.0,833.0,126.0,4.5),2.3,Color.WHITE)

func _coord_in_virtual(p: Vector2) -> Vector2:
 var d := _canvas_area()
 return (p - d["origin"]) / float(d["zoom"])

func _hit_icon(p: Vector2) -> String:
 var d := _canvas_area()
 if d["landscape"]:
  if p.y >= 294.0 and p.y < 363.0:
   for idx in range(4):
    if Rect2(241.0+float(idx)*91.0,290.0,69.0,70.0).has_point(p):
     return DOCK[idx]
  var list: Array = PAGE_ONE if page == 0 else PAGE_TWO
  for idx in range(mini(16,list.size())):
   if Rect2(25.0+float(idx%8)*102.0,61.0+float(idx/8)*100.0,72.0,83.0).has_point(p):
    return str(list[idx])
 else:
  if p.y >= 740.0 and p.y < 823.0:
   for idx in range(4):
    if Rect2(30.0+float(idx)*89.0,740.0,75.0,75.0).has_point(p):
     return DOCK[idx]
  var list: Array = PAGE_ONE if page == 0 else PAGE_TWO
  for idx in range(list.size()):
   var col: int = idx%4
   var row: int = idx/4
   var iy: float = 280.0+float(row)*95.5 if page == 0 else 101.0+float(row)*109.0
   if Rect2(17.0+float(col)*93.0,iy,74.0,79.0).has_point(p):
    return str(list[idx])
 return ""

func _handle_release(pos: Vector2) -> void:
 if not touching:
  return
 touching = false
 var a := _coord_in_virtual(pointer_start)
 var b := _coord_in_virtual(pos)
 var dist := b-a
 var d := _canvas_area()
 if selected != "":
  if selected == "qr":
   var qr_panel := _qr_dialog_rect(bool(d["landscape"]))
   if _qr_close_rect(bool(d["landscape"])).has_point(b) or not qr_panel.has_point(b) or dist.y < -95.0:
    selected = ""
   return
  var r := Rect2(250.0,38.0,344.0,314.0) if d["landscape"] else Rect2(26.0,263.0,338.0,298.0)
  if selected == "settings":
   if Rect2(r.position.x+20.0,r.position.y+190.0,r.size.x-40.0,49.0).has_point(b):
    OS.shell_open("https://icons8.com/")
    return
  if dist.y < -95.0 or Rect2(r.position.x+26.0,r.end.y-68.0,r.size.x-52.0,44.0).has_point(b) or not r.has_point(b):
   selected = ""
  return
 if editing:
  if (d["landscape"] and b.x > 735.0 and b.y < 75.0) or (not d["landscape"] and b.x > 294.0 and b.y < 89.0):
   editing = false
  return
 if absf(dist.x) > 52.0 and absf(dist.x) > absf(dist.y)*1.2:
  page = clampi(page + (-1 if dist.x > 0.0 else 1),0,1)
  return
 if dist.length() > 24.0:
  return
 var clicked := _hit_icon(b)
 if clicked != "":
  selected = clicked

func _input(event: InputEvent) -> void:
 if event is InputEventScreenTouch:
  if event.pressed:
   pointer_start = event.position
   pointer_current = event.position
   press_seconds = 0.0
   touching = true
  else:
   _handle_release(event.position)
 elif event is InputEventScreenDrag:
  pointer_current = event.position
 elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
  if event.pressed:
   pointer_start = event.position
   pointer_current = event.position
   press_seconds = 0.0
   touching = true
  else:
   _handle_release(event.position)
 elif event is InputEventMouseMotion and touching:
  pointer_current = event.position
 elif event is InputEventKey and event.pressed:
  if event.keycode == KEY_ESCAPE:
   selected = ""
   editing = false
  elif event.keycode == KEY_LEFT:
   page = mini(1,page+1)
  elif event.keycode == KEY_RIGHT:
   page = maxi(0,page-1)
