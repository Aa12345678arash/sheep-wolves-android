extends Node
class_name WolfDuskOnlineRoomClient

signal request_finished(kind: String, success: bool, payload: Dictionary)
signal room_connected(snapshot: Dictionary)
signal room_message(payload: Dictionary)
signal room_disconnected(code: int, reason: String)
signal client_error(code: String)

const PROTOCOL_VERSION := 1
const RULESET_ID := "wolf-dusk-25x25-56edges-v1"
const RECONNECT_DELAY := 2.0
const HEARTBEAT_INTERVAL := 12.0

var service_base_url: String = ""
var room_code: String = ""
var player_token: String = ""
var player_side: String = ""
var invite_url: String = ""
var next_action_sequence: int = 1

var _http: HTTPRequest
var _socket := WebSocketPeer.new()
var _pending_kind := ""
var _reconnect_enabled := false
var _reconnect_elapsed := 0.0
var _heartbeat_elapsed := 0.0
var _was_open := false
var _authenticated := false
var _auth_sent := false
var _initial_snapshot_received := false

func _ready() -> void:
	service_base_url = str(ProjectSettings.get_setting("application/config/wolf_dusk_online_service_url", "")).trim_suffix("/")
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

func configure_service(base_url: String) -> void:
	service_base_url = base_url.strip_edges().trim_suffix("/")

func is_configured() -> bool:
	return service_base_url.begins_with("https://") or service_base_url.begins_with("http://")

func create_room(display_name: String) -> Error:
	if not is_configured():
		client_error.emit("online_service_not_configured")
		return ERR_UNCONFIGURED
	if _pending_kind != "":
		return ERR_BUSY
	_pending_kind = "create"
	return _post("/api/rooms", {
		"displayName": _clean_name(display_name),
		"protocolVersion": PROTOCOL_VERSION,
		"rulesetId": RULESET_ID
	})

func join_room(code: String, display_name: String) -> Error:
	if not is_configured():
		client_error.emit("online_service_not_configured")
		return ERR_UNCONFIGURED
	if _pending_kind != "":
		return ERR_BUSY
	room_code = code.strip_edges()
	if room_code.length() != 16:
		client_error.emit("invalid_room_code")
		return ERR_INVALID_PARAMETER
	_pending_kind = "join"
	return _post("/api/rooms/%s/join" % room_code, {
		"displayName": _clean_name(display_name),
		"protocolVersion": PROTOCOL_VERSION,
		"rulesetId": RULESET_ID
	})

func _post(path: String, data: Dictionary) -> Error:
	var headers := PackedStringArray(["Content-Type: application/json"])
	var error := _http.request(service_base_url + path, headers, HTTPClient.METHOD_POST, JSON.stringify(data))
	if error != OK:
		var kind := _pending_kind
		_pending_kind = ""
		request_finished.emit(kind, false, {"error":"http_request_start_failed","code":error})
	return error

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var kind := _pending_kind
	_pending_kind = ""
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	var payload: Dictionary = parsed if parsed is Dictionary else {"error":"invalid_server_response"}
	var success := result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300
	if success:
		room_code = str(payload.get("roomCode", room_code))
		player_token = str(payload.get("playerToken", ""))
		player_side = str(payload.get("side", ""))
		invite_url = str(payload.get("inviteUrl", ""))
		request_finished.emit(kind, true, payload)
	else:
		request_finished.emit(kind, false, payload)

func connect_room() -> Error:
	if room_code.is_empty() or player_token.is_empty() or not is_configured():
		client_error.emit("room_credentials_missing")
		return ERR_UNCONFIGURED
	_socket = WebSocketPeer.new()
	var ws_base := service_base_url.replace("https://", "wss://").replace("http://", "ws://")
	var url := "%s/api/rooms/%s/ws" % [ws_base, room_code]
	var error := _socket.connect_to_url(url)
	if error != OK:
		client_error.emit("websocket_connect_start_failed")
		return error
	_reconnect_enabled = true
	_reconnect_elapsed = 0.0
	_heartbeat_elapsed = 0.0
	_was_open = false
	_authenticated = false
	_auth_sent = false
	_initial_snapshot_received = false
	return OK

func set_ready() -> Error:
	if not _authenticated:
		return ERR_UNAVAILABLE
	return _send({"type":"ready"})

func send_action(action: Dictionary) -> Error:
	if not _authenticated:
		return ERR_UNAVAILABLE
	if action.is_empty():
		return ERR_INVALID_PARAMETER
	var packet := {"seq":next_action_sequence,"action":action}
	var error := _send(packet)
	if error == OK:
		next_action_sequence += 1
	return error

func _send(packet: Dictionary) -> Error:
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN or not _authenticated:
		return ERR_UNAVAILABLE
	return _socket.send_text(JSON.stringify(packet))

func close_room() -> void:
	_reconnect_enabled = false
	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN or _socket.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
		_socket.close(1000,"client_closed")
	room_code = ""
	player_token = ""
	player_side = ""
	invite_url = ""
	next_action_sequence = 1

func _process(delta: float) -> void:
	var state := _socket.get_ready_state()
	if state == WebSocketPeer.STATE_CONNECTING or state == WebSocketPeer.STATE_OPEN:
		_socket.poll()
		state = _socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		_reconnect_elapsed = 0.0
		if not _was_open:
			_was_open = true
		if not _auth_sent:
			var auth_error := _socket.send_text(JSON.stringify({"type":"auth","token":player_token}))
			if auth_error == OK:
				_auth_sent = true
		_heartbeat_elapsed += delta
		if _heartbeat_elapsed >= HEARTBEAT_INTERVAL:
			_heartbeat_elapsed = 0.0
			_send({"type":"ping"})
		while _socket.get_available_packet_count() > 0:
			_handle_packet(_socket.get_packet().get_string_from_utf8())
	elif state == WebSocketPeer.STATE_CLOSED:
		if _was_open:
			_was_open = false
			room_disconnected.emit(_socket.get_close_code(),_socket.get_close_reason())
		if _reconnect_enabled and not room_code.is_empty() and not player_token.is_empty():
			_reconnect_elapsed += delta
			if _reconnect_elapsed >= RECONNECT_DELAY:
				_reconnect_elapsed = 0.0
				_socket = WebSocketPeer.new()
				var ws_base := service_base_url.replace("https://","wss://").replace("http://","ws://")
				var url := "%s/api/rooms/%s/ws" % [ws_base,room_code]
				_authenticated = false
				_auth_sent = false
				var error := _socket.connect_to_url(url)
				if error != OK:
					client_error.emit("websocket_reconnect_start_failed")

func _handle_packet(raw: String) -> void:
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		client_error.emit("invalid_websocket_message")
		return
	var payload: Dictionary = parsed
	if payload.get("type","") == "snapshot":
		_authenticated = true
		next_action_sequence = maxi(1,int(payload.get("nextActionSeq",next_action_sequence)))
		if not _initial_snapshot_received:
			_initial_snapshot_received = true
			room_connected.emit(payload)
	elif payload.get("type","") == "error" and payload.has("expected"):
		next_action_sequence = maxi(1,int(payload.expected))
	room_message.emit(payload)

func _clean_name(value: String) -> String:
	var result := value.strip_edges()
	if result.length() > 24:
		result = result.substr(0,24)
	return result
