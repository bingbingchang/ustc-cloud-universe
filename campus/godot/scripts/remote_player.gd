extends Node3D
## 远端玩家代理：复用项目自己的学生 avatar（player_avatar.gd）来显示别人。
## 关键点是 player_avatar.gd 已经暴露了和本地玩家完全一致的接口
## animate(speed,vertical,grounded,dt)，所以远端角色不需要新做动画，
## 直接拿复制过来的速度/朝向喂给同一个 animate 即可，走路姿势和本地玩家一致。
##
## 挂载位置有约束：player_avatar.gd 的 _ready() 里会调用
## get_parent().get_parent().style(model)，所以本节点必须直接挂在校园根节点下。
const LERP_RATE=14.0

var avatar:Node3D
var target_position:=Vector3.ZERO
var target_yaw:=0.0
var net_speed:=0.0
var net_vertical:=0.0
var net_grounded:=true
var has_target=false
var last_seen:=0.0

func _ready():
	name="RemotePeer"
	avatar=preload("res://scripts/player_avatar.gd").new()
	avatar.name="RemoteAvatar"
	add_child(avatar)
	set_process(false)

func apply_state(state:Array)->void:
	if state.size()<7:return
	target_position=Vector3(state[0],state[1],state[2])
	target_yaw=state[3]
	net_speed=state[4]
	net_vertical=state[5]
	net_grounded=bool(state[6])
	last_seen=float(Time.get_ticks_msec())/1000.0
	if not has_target:
		# 第一帧直接落位，避免从原点滑过去。
		global_position=target_position
		if avatar:avatar.rotation.y=target_yaw
		has_target=true
		set_process(true)

func stale(now:float,timeout:=2.0)->bool:
	return has_target and now-last_seen>timeout

func telemetry()->Dictionary:
	# 自检用：插值是否真的收敛、收到的速度是否非零。
	return {"seen":has_target,"gap_m":snappedf(global_position.distance_to(target_position),0.01),
		"speed":snappedf(net_speed,0.01),"yaw":snappedf(target_yaw,0.001),"grounded":net_grounded}

func _process(dt):
	if not has_target:return
	var t=clampf(dt*LERP_RATE,0.0,1.0)
	global_position=global_position.lerp(target_position,t)
	if avatar:
		avatar.rotation.y=lerp_angle(avatar.rotation.y,target_yaw,t)
		avatar.animate(net_speed,net_vertical,net_grounded,dt)
