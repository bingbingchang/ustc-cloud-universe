extends Node
## 最简多人会话层：持有 ENet peer，转发角色状态与聊天。
## 完全是 opt-in 的：不带 --net-* 参数时本节点根本不会被创建，单机路径零影响。
##
## 拓扑为星形（ENet server 为 1 号 peer）：
##   客户端 --state--> 主机 --state--> 其余客户端
##   客户端 --chat---> 主机 --chat--> 其余客户端
##
## 状态用 unreliable 发（丢包无所谓，下一帧就会覆盖）；
## 聊天用 reliable 发（不能丢字）。
signal peer_state(id:int,state:Array)
signal peer_left(id:int)
signal peer_joined(id:int)
signal chat_message(sender_name:String,text:String)
signal connected_ok()
signal session_ended(reason:String)

const DEFAULT_PORT=45888
const MAX_PEERS=16
const SEND_HZ=20.0

var peer:ENetMultiplayerPeer
var hosting=false
var local_name="同学"
var ready_to_send=false
var _accumulator=0.0
var _state_provider:Callable

func setup(host_mode:bool,address:String="127.0.0.1",port:int=DEFAULT_PORT,player_name:String="同学")->bool:
	local_name=player_name
	peer=ENetMultiplayerPeer.new()
	var err:int
	if host_mode:
		err=peer.create_server(port,MAX_PEERS)
	else:
		err=peer.create_client(address,port)
	if err!=OK:
		push_error("NET create failed host=%s err=%d" % [str(host_mode),err])
		peer=null
		return false
	hosting=host_mode
	ready_to_send=host_mode
	multiplayer.multiplayer_peer=peer
	multiplayer.peer_connected.connect(func(id:int):peer_joined.emit(id))
	multiplayer.peer_disconnected.connect(func(id:int):peer_left.emit(id))
	multiplayer.connected_to_server.connect(func():
		ready_to_send=true
		connected_ok.emit())
	multiplayer.connection_failed.connect(func():
		ready_to_send=false
		session_ended.emit("连接失败：检查地址与端口，以及主机端是否已启动")
		close())
	multiplayer.server_disconnected.connect(func():
		ready_to_send=false
		session_ended.emit("与主机断开")
		close())
	print("NET_READY mode=%s name=%s port=%d peer_id=%d" % ["host" if hosting else "client",local_name,port,multiplayer.get_unique_id()])
	return true

func local_id()->int:
	return multiplayer.get_unique_id()

func remote_peer_ids()->Array:
	var out=[]
	for id in multiplayer.get_peers():out.append(id)
	return out

func set_state_provider(callback:Callable)->void:
	_state_provider=callback

func alive()->bool:
	return peer!=null and multiplayer.multiplayer_peer!=null

func close()->void:
	ready_to_send=false
	if peer:
		peer.close()
	multiplayer.multiplayer_peer=null
	peer=null
	print("NET_CLOSED")

func send_chat(text:String)->void:
	var body=text.strip_edges()
	if body=="" or not alive():return
	if hosting:push_chat.rpc(local_name,body)
	elif ready_to_send:push_chat.rpc_id(1,local_name,body)
	else:return
	chat_message.emit(local_name,body)

func _process(dt):
	if not alive() or not ready_to_send:return
	_accumulator+=dt
	if _accumulator<1.0/SEND_HZ:return
	_accumulator=0.0
	if not _state_provider.is_valid():return
	var state:Array=_state_provider.call()
	if hosting:push_state.rpc(local_id(),state)
	else:push_state.rpc_id(1,local_id(),state)

@rpc("any_peer","call_remote","unreliable")
func push_state(id:int,state:Array)->void:
	if id==local_id():return
	var sender=multiplayer.get_remote_sender_id()
	peer_state.emit(id,state)
	# 主机收到客户端状态后转发给其余客户端（ENet 是星形，客户端之间不能直连）。
	if hosting and sender!=0:
		for other in multiplayer.get_peers():
			if other!=sender:push_state.rpc_id(other,id,state)

@rpc("any_peer","call_remote","reliable")
func push_chat(sender_name:String,text:String)->void:
	var sender=multiplayer.get_remote_sender_id()
	chat_message.emit(sender_name,text)
	if hosting and sender!=0:
		for other in multiplayer.get_peers():
			if other!=sender:push_chat.rpc_id(other,sender_name,text)
