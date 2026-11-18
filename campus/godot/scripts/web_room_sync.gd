extends Node
## Only exchanges room state with the same-origin host page; no room passwords enter the game.
var game
var bridge:JavaScriptObject
var callback:JavaScriptObject
var active=false
var elapsed=0.0
var icon_elapsed=0.0
var bubbles={}
var own_nameplate:Label3D
const CHAT_DISTANCE=4.5
const NAME_HEIGHT=1.86
const CHAT_ICON_HEIGHT=2.22
const BUBBLE_HEIGHT=2.98

func _ready():
	if not OS.has_feature("web"):return
	JavaScriptBridge.eval("""
		window.CampusRoomBridge = (() => {
			let listener;
			const buttons = new Map();
			const clear = () => { for (const button of buttons.values()) button.remove(); buttons.clear(); };
			return {
				listen(cb) {
					listener = event => {
						if (event.origin !== window.location.origin || event.source !== window.parent) return;
						const data = event.data;
						if (data?.type === 'campus-room-active')
							cb('active', JSON.stringify({active:data.active===true,playerId:data.playerId,name:data.name}));
						if (data?.type === 'campus-room-peers' && Array.isArray(data.players))
							cb('peers', JSON.stringify(data.players.slice(0, 7)));
						if (data?.type === 'campus-room-bubble')
							cb('bubble', JSON.stringify({playerId:data.playerId,own:data.own,text:data.text,ms:data.ms}));
					};
					addEventListener('message', listener);
				},
				send(state) { window.parent.postMessage({type: 'campus-room-state', state: JSON.parse(state)}, window.location.origin); },
				icons(json) {
					const canvas = document.getElementById('canvas');
					if (!canvas) return;
					const rect = canvas.getBoundingClientRect(), seen = new Set();
					for (const row of JSON.parse(json)) {
						const {id,x,y} = row;
						seen.add(id);
						let button = buttons.get(id);
						if (!button) {
							button = document.createElement('button');
							button.type = 'button'; button.textContent = '💬';
							button.setAttribute('aria-label', '和玩家 ' + id + ' 聊天');
							button.title = '点击私聊（电脑端可先按 Esc 释放鼠标）';
							Object.assign(button.style,{position:'fixed',zIndex:'12',transform:'translate(-50%,-100%)',
								width:'38px',height:'38px',borderRadius:'50%',border:'1px solid #efe5b9',
								background:'#214a3e',color:'#fff7d7',fontSize:'19px',cursor:'pointer',touchAction:'manipulation'});
							button.addEventListener('click', () => {
								document.exitPointerLock?.();
								window.parent.postMessage({type:'campus-room-open-chat', playerId:id}, window.location.origin);
							});
							buttons.set(id, button); document.body.appendChild(button);
						}
						button.style.left = (rect.left + rect.width*x) + 'px';
						button.style.top = (rect.top + rect.height*y) + 'px';
					}
					for (const [id,button] of buttons) if (!seen.has(id)) { button.remove(); buttons.delete(id); }
				},
				dispose() { removeEventListener('message', listener); clear(); }
			};
		})()
	""",true)
	bridge=JavaScriptBridge.get_interface("CampusRoomBridge")
	if not bridge:return
	callback=JavaScriptBridge.create_callback(receive)
	bridge.listen(callback)

func receive(args:Array):
	if args.size()!=2:return
	if args[0]=="active":
		var status=JSON.parse_string(str(args[1]))
		if not status is Dictionary:return
		active=status.get("active",false)
		if active:
			var id=int(status.get("playerId",0))
			if id>0:
				own_nameplate=update_nameplate(game.player,id,status.get("name",""))
			send_state()
		else:
			if is_instance_valid(own_nameplate):own_nameplate.queue_free()
			own_nameplate=null
			apply_players([])
			if bridge:bridge.icons("[]")
			for id in bubbles.keys():drop_bubble(id)
	elif args[0]=="peers" and active:
		var players=JSON.parse_string(str(args[1]))
		if players is Array:apply_players(players)
	elif args[0]=="bubble" and active:
		var message=JSON.parse_string(str(args[1]))
		if message is Dictionary:show_bubble(message)

func apply_players(players:Array):
	var seen={}
	for peer in players:
		if not peer is Dictionary or not peer.has("id") or not peer.has("state"):continue
		var id=int(peer.id)
		var state=peer.state
		if id<=0 or not state is Array or state.size()!=7:continue
		seen[id]=true
		game._on_peer_state(id,state)
		update_nameplate(game.remote_peers[id],id,peer.get("name",""))
	for id in game.remote_peers.keys():
		if not seen.has(id):
			drop_bubble(id)
			game.drop_remote_peer(id)

func update_nameplate(speaker:Node3D,id:int,display_name:String)->Label3D:
	var label:=speaker.get_node_or_null("RoomNameplate") as Label3D
	if not label:
		label=Label3D.new()
		label.name="RoomNameplate"
		label.font=preload("res://scripts/campus_font.gd").get_font()
		label.font_size=28
		label.outline_size=8
		label.pixel_size=.0042
		label.modulate=Color("e8f6e5")
		label.outline_modulate=Color("142b23")
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		label.vertical_alignment=VERTICAL_ALIGNMENT_BOTTOM
		label.visibility_range_end=35.0
		label.position=Vector3(0,NAME_HEIGHT,0)
		label.visible=speaker!=game.player or game.player.avatar.visible
		speaker.add_child(label)
	var caption:=display_name.left(16) if not display_name.is_empty() else "玩家 %d" % id
	if label.text!=caption:label.text=caption
	return label

func drop_bubble(id:int):
	if not bubbles.has(id):return
	var label=bubbles[id].label
	if is_instance_valid(label):label.queue_free()
	bubbles.erase(id)

func show_bubble(message:Dictionary):
	var id=int(message.get("playerId",0))
	var lifetime=clampi(int(message.get("ms",0)),0,4500)
	var content=str(message.get("text","")).left(120)
	if id<=0 or lifetime<=0 or content.is_empty():return
	var speaker=game.player if message.get("own",false) else game.remote_peers.get(id)
	if not is_instance_valid(speaker):return
	drop_bubble(id)
	var label=Label3D.new()
	label.name="RoomChatBubble"
	label.text=content
	label.font=preload("res://scripts/campus_font.gd").get_font()
	label.font_size=26;label.outline_size=9;label.pixel_size=.0045
	label.modulate=Color("fff8dc");label.outline_modulate=Color("18362b")
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.vertical_alignment=VERTICAL_ALIGNMENT_BOTTOM
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.width=440
	label.position=Vector3(0,BUBBLE_HEIGHT,0)
	speaker.add_child(label)
	bubbles[id]={"label":label,"until":Time.get_ticks_msec()+lifetime}

func update_icons():
	if not bridge:return
	var icons=[]
	var camera=get_viewport().get_camera_3d()
	if camera and not game.player.free_camera and not game.hero_interactions.modal_active and not game.campus_agent.panel_open:
		var rect=get_viewport().get_visible_rect()
		var space=game.get_world_3d().direct_space_state
		for id in game.remote_peers:
			var player=game.remote_peers[id]
			if not is_instance_valid(player) or player.global_position.distance_squared_to(game.player.global_position)>CHAT_DISTANCE*CHAT_DISTANCE:continue
			var anchor:Vector3=player.global_position+Vector3.UP*CHAT_ICON_HEIGHT
			if camera.is_position_behind(anchor):continue
			var point=camera.unproject_position(anchor)
			if not rect.has_point(point):continue
			var head:Vector3=player.global_position+Vector3.UP*NAME_HEIGHT
			var ray=PhysicsRayQueryParameters3D.create(camera.global_position,head,1,[game.player.get_rid()])
			if not space.intersect_ray(ray).is_empty():continue
			var xy=(point-rect.position)/rect.size
			icons.append({"id":id,"x":xy.x,"y":xy.y})
	bridge.icons(JSON.stringify(icons))

func send_state():
	if bridge and game.game_ready:bridge.send(JSON.stringify(game.local_net_state()))

func _process(delta):
	if not active:return
	var now=Time.get_ticks_msec()
	for id in bubbles.keys():
		if now>=bubbles[id].until:drop_bubble(id)
	icon_elapsed+=delta
	if icon_elapsed>=.1:
		icon_elapsed=0
		if is_instance_valid(own_nameplate):own_nameplate.visible=game.player.avatar.visible
		update_icons()
	elapsed+=delta
	if elapsed>=.2:
		elapsed=0
		send_state()

func _exit_tree():
	if bridge:bridge.dispose()
