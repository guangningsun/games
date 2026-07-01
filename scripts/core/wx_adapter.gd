extends Node
## WXAdapter —— 微信小游戏 API 适配层（autoload 单例）
##
## 在 PC/桌面平台：所有方法 mock 返回（不报错，可正常演示）
## 在微信小游戏平台：通过 JavaScriptBridge 调用 wx.*
##
## M4 状态：
## - ✅ 接口定义 + Mock 实现完成
## - ⏳ 真实微信 API 接入：需要导出后用微信开发者工具联调
##            （位置：scripts/core/wx_adapter.gd 的 _wx_* 方法）
##
## 调用方式：WXAdapter.share("title")，结果通过信号返回
## M5+ TODO：
##   - wx.login() 获取 openid/unionid
##   - wx.createRewardedVideoAd() 复活广告
##   - wx.shareAppMessage() 分享
##   - 微信云开发 / wx.setUserCloudStorage() 上传分数

signal login_completed(user_info: Dictionary)
signal share_completed(success: bool)
signal revive_started                          ## 广告开始播放
signal revive_completed(success: bool)         ## 广告关闭（success=true 表示看完）
signal rank_uploaded(rank: int)                ## 分数上传完成，返回新排名

const MOCK_LATENCY: float = 0.4  ## Mock 模拟网络延迟（秒）


## 平台检测：当前是否在微信小游戏环境
static func is_wechat() -> bool:
	# 微信小游戏导出后，OS.has_feature("wechat") 返回 true
	# 同时支持命令行参数 --wechat 用于本地测试
	return OS.has_feature("wechat") or "--wechat" in OS.get_cmdline_args()


# ============================================================
#                              接口
# ============================================================

## 登录（微信登录 / Mock）
func login() -> void:
	if is_wechat():
		_wx_login()
	else:
		_mock_call(func() -> void:
			login_completed.emit({"openid": "mock_user", "nickname": "Player"})
		)


## 分享给好友（微信 shareAppMessage / Mock）
func share(title: String = "来玩弹球砖块！", image_url: String = "") -> void:
	print("[WXAdapter] share: ", title)
	if is_wechat():
		_wx_share(title, image_url)
		# 微信分享不返回结果，用户主动关闭后即视为成功
		share_completed.emit(true)
	else:
		_mock_call(func() -> void: share_completed.emit(true))


## 请求复活（看激励视频广告 / Mock 直接同意）
func request_revive() -> void:
	print("[WXAdapter] request_revive()")
	revive_started.emit()
	if is_wechat():
		_wx_revive()
	else:
		_mock_call(func() -> void: revive_completed.emit(true))


## 上传分数到排行榜
func upload_score(score: int) -> void:
	print("[WXAdapter] upload_score: ", score)
	if is_wechat():
		_wx_upload_score(score)
	else:
		_mock_call(func() -> void: rank_uploaded.emit(0))


## 显示 Toast 提示
func show_toast(message: String) -> void:
	print("[WXAdapter] toast: ", message)
	if is_wechat():
		_wx_show_toast(message)
	# PC 平台仅 print


# ============================================================
#                       微信 API 实现（TODO）
# ============================================================

func _wx_login() -> void:
	# TODO: wx.login({success: function(res){ wxLoginCallback(res.code) }})
	push_warning("[WXAdapter] wx.login() not implemented yet - falling back to mock")
	login_completed.emit({"openid": "wx_user_placeholder", "nickname": "微信玩家"})


func _wx_share(title: String, image_url: String) -> void:
	# TODO: 通过 JavaScriptBridge.eval 调用
	#   wx.shareAppMessage({title: title, imageUrl: image_url})
	push_warning("[WXAdapter] wx.shareAppMessage() not implemented yet")


func _wx_revive() -> void:
	# TODO: 微信激励视频广告
	#   var ad = wx.createRewardedVideoAd({adUnitId: 'adunit-xxx'})
	#   ad.onLoad(() => ad.show())
	#   ad.onClose(res => { if (res.isEnded) godotBridge.wxReviveSuccess(); else godotBridge.wxReviveCancel(); })
	push_warning("[WXAdapter] wx.createRewardedVideoAd() not implemented yet")
	# 占位：暂时直接成功（M5 接入真实广告）
	revive_completed.emit(true)


func _wx_upload_score(score: int) -> void:
	# TODO: 微信云开发 / setUserCloudStorage
	#   wx.setUserCloudStorage({KVDataList: [{key:'high_score', value:''+score}], success:...})
	push_warning("[WXAdapter] wx.setUserCloudStorage() not implemented yet")
	rank_uploaded.emit(0)


func _wx_show_toast(message: String) -> void:
	# TODO: wx.showToast({title: message, icon: 'none', duration: 1500})
	push_warning("[WXAdapter] wx.showToast() not implemented yet")


# ============================================================
#                          Mock helpers
# ============================================================

## 模拟异步网络调用
func _mock_call(callback: Callable) -> void:
	await get_tree().create_timer(MOCK_LATENCY).timeout
	callback.call()